using System;
using System.IO;
using System.Linq;
using System.Windows;
using NLog;
using DevExpress.Xpo;
using DevExpress.Xpo.DB;
using DevExpress.Data.Filtering;
using DevExpress.Xpo.Metadata;
using DevExpress.Mvvm;
using XTS.XModels;
using XTS.XModels.DB;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Threading;
using System.Threading.Tasks;

namespace XTS.XModels.DB;

public class XpoSqliteServiceBase : XChannelObject
{
    protected IDataLayer _dataLayer = null!;
    protected string _dbPath = string.Empty;
    private readonly object _initLock = new object();

    public XpoSqliteServiceBase(XParameter param, XChannelInfo info) : base(param, info) { }

    protected System.Threading.CancellationTokenSource? _dbLoopCancelSource;

    public override void Start()
    {
        InitializeXpo();
        nlog.Trace("XpoSqliteServiceBase Started. XPO initialized.");
    }

    public override void Stop()
    {
        _dbLoopCancelSource?.Cancel();
        messenger.Unregister(this);
        _dataLayer?.Dispose();
        nlog.Trace("XpoSqliteServiceBase Stopped.");
    }

    public IDataLayer GetLayer()
    {
        if (_dataLayer == null) InitializeXpo();
        return _dataLayer!;
    }

    protected void InitializeXpo()
    {
        if (_dataLayer != null) return;
        lock (_initLock)
        {
            if (_dataLayer != null) return;
            try
            {
                _dbPath = param.Config?.SystemSettings?.Paths?.ProdDbFullpath ?? string.Empty;

                if (string.IsNullOrEmpty(_dbPath))
                {
                    string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
                    string commonPath = Path.Combine(appData, @"MetaQuotes\Terminal\Common\Files");
                    _dbPath = Path.Combine(commonPath, "ABC.db");
                }

                string? dbDir = Path.GetDirectoryName(_dbPath);
                if (!string.IsNullOrEmpty(dbDir) && !Directory.Exists(dbDir)) Directory.CreateDirectory(dbDir);
                if (!File.Exists(_dbPath)) File.WriteAllBytes(_dbPath, Array.Empty<byte>());

                string connStr = SQLiteConnectionProvider.GetConnectionString(_dbPath);
                XPDictionary dict = new ReflectionDictionary();
                dict.CollectClassInfos(typeof(XpoSignal).Assembly); 

                IDataStore store = XpoDefault.GetConnectionProvider(connStr, AutoCreateOption.DatabaseAndSchema);
                _dataLayer = new ThreadSafeDataLayer(dict, store);
                XpoDefault.DataLayer = _dataLayer;
                _dataLayer.UpdateSchema(false, dict.CollectClassInfos(typeof(XpoSignal).Assembly));

                using (var session = new Session(_dataLayer))
                {
                    session.ExecuteNonQuery("PRAGMA busy_timeout = 5000;"); 
                    session.ExecuteNonQuery("PRAGMA synchronous=FULL;"); 
                }

                using (var uow = new UnitOfWork(_dataLayer))
                {
                    uow.CreateObjectTypeRecords();
                    int count = (int)uow.Evaluate<XpoSignal>(CriteriaOperator.Parse("Count()"), null);
                    nlog?.Info($"[DB HUB] XPO Initialized OK. DB Path: {_dbPath} | Total Records: {count}");
                }
            }
            catch (Exception ex) 
            { 
                string detailedError = ex.Message;
                if (ex.InnerException != null) detailedError += " | Inner: " + ex.InnerException.Message;
                nlog?.Fatal(ex, $"[DB HUB] XPO INIT FAILED! Path: {_dbPath} | Error: {detailedError}"); 
            }
        }
    }
}

public class XpoSqliteService : XpoSqliteServiceBase
{
    private readonly ConcurrentQueue<XDataObject> _signalQueue = new();
    private readonly ConcurrentQueue<XDataObject> _messageQueue = new();
    private readonly ConcurrentDictionary<int, XChannelOption> _optionCache = new();
    private readonly ConcurrentDictionary<(int cno, int dir, int gno), XGridProfile> _gridProfileCache = new();

    public XpoSqliteService(XParameter param) : this(param, new XChannelInfo(0, 0, "DB_HUB", "SYSTEM")) { }
    public XpoSqliteService(XParameter param, XChannelInfo info) : base(param, info) { }

    public override void Start()
    {
        base.Start(); 
        messenger.Register<XDataObject>(this, "DB_SAVE_SIGNAL", true, xdo => _signalQueue.Enqueue(xdo));
        messenger.Register<XDataObject>(this, "DB_SAVE_MSG", true, xdo => _messageQueue.Enqueue(xdo));
        messenger.Register<XDataObject>(this, "db_hub_delete_row", true, OnDeleteRowRequested);

        _dbLoopCancelSource = new System.Threading.CancellationTokenSource();
        Task.Run(ProcessSignalQueue, _dbLoopCancelSource.Token);
        Task.Run(ProcessMessageQueue, _dbLoopCancelSource.Token);
        nlog.Trace("XpoSqliteService Loop Started.");
    }

    public XChannelOption? GetOption(int cno)
    {
        if (_optionCache.TryGetValue(cno, out var opt)) return opt;
        using (var uow = new UnitOfWork(_dataLayer))
        {
            var xpo = uow.GetObjectByKey<XpoChannelOption>(cno);
            if (xpo != null)
            {
                var option = new XChannelOption
                {
                    cno = xpo.cno,
                    name = xpo.name,
                    is_buy_active = xpo.is_buy_active,
                    is_sell_active = xpo.is_sell_active,
                    buy_entry_offset = xpo.buy_entry_offset,
                    sell_entry_offset = xpo.sell_entry_offset,
                    tp_points = xpo.tp_points,
                    sl_points = xpo.sl_points,
                    default_volume = xpo.default_volume,
                    lot_strategy = xpo.lot_strategy,
                    lot_value = xpo.lot_value,
                    lot_rate = xpo.lot_rate,
                    grid_count = xpo.grid_count,
                    grid_step = xpo.grid_step,
                    ts_trigger = xpo.ts_trigger,
                    ts_step = xpo.ts_step,
                    gap_min = xpo.gap_min,
                    type = xpo.type,
                    at_updated = xpo.at_updated
                };
                _optionCache[cno] = option;
                return option;
            }
        }
        return null;
    }

    public void SetOption(XChannelOption opt)
    {
        if (opt == null) return;
        _optionCache[opt.cno] = opt;
        try
        {
            using (var uow = new UnitOfWork(_dataLayer))
            {
                var xpo = uow.GetObjectByKey<XpoChannelOption>(opt.cno) ?? new XpoChannelOption(uow) { cno = opt.cno };
                xpo.name = opt.name;
                xpo.is_buy_active = opt.is_buy_active;
                xpo.is_sell_active = opt.is_sell_active;
                xpo.buy_entry_offset = opt.buy_entry_offset;
                xpo.sell_entry_offset = opt.sell_entry_offset;
                xpo.tp_points = opt.tp_points;
                xpo.sl_points = opt.sl_points;
                xpo.default_volume = opt.default_volume;
                xpo.lot_strategy = opt.lot_strategy;
                xpo.lot_value = opt.lot_value;
                xpo.lot_rate = opt.lot_rate;
                xpo.grid_count = opt.grid_count;
                xpo.grid_step = opt.grid_step;
                xpo.ts_trigger = opt.ts_trigger;
                xpo.ts_step = opt.ts_step;
                xpo.gap_min = opt.gap_min;
                xpo.type = opt.type;
                xpo.at_updated = DateTime.Now;
                uow.CommitChanges();
            }
        }
        catch (Exception ex) { nlog.Error(ex, $"[DB:Option] Failed to save option for CNO:{opt.cno}"); }
    }

    public XGridProfile? GetGridProfile(int cno, int dir, int gno)
    {
        if (_gridProfileCache.TryGetValue((cno, dir, gno), out var profile)) return profile;
        using (var uow = new UnitOfWork(_dataLayer))
        {
            var xpo = uow.FindObject<XpoGridProfile>(CriteriaOperator.Parse("cno = ? AND dir = ? AND gno = ?", cno, dir, gno));
            if (xpo != null)
            {
                var p = new XGridProfile
                {
                    cno = xpo.cno,
                    dir = xpo.dir,
                    gno = xpo.gno,
                    type = xpo.type,
                    offset = xpo.offset,
                    lot = xpo.lot,
                    tp = xpo.tp,
                    sl = xpo.sl,
                    ts_trigger = xpo.ts_trigger,
                    ts_step = xpo.ts_step,
                    gap_min = xpo.gap_min
                };
                _gridProfileCache[(cno, dir, gno)] = p;
                return p;
            }
        }
        return null;
    }

    public void SetGridProfile(XGridProfile profile)
    {
        if (profile == null) return;
        _gridProfileCache[(profile.cno, profile.dir, profile.gno)] = profile;
        try
        {
            using (var uow = new UnitOfWork(_dataLayer))
            {
                var xpo = uow.FindObject<XpoGridProfile>(CriteriaOperator.Parse("cno = ? AND dir = ? AND gno = ?", profile.cno, profile.dir, profile.gno))
                          ?? new XpoGridProfile(uow);
                xpo.cno = profile.cno;
                xpo.dir = profile.dir;
                xpo.gno = profile.gno;
                xpo.type = profile.type;
                xpo.offset = profile.offset;
                xpo.lot = profile.lot;
                xpo.tp = profile.tp;
                xpo.sl = profile.sl;
                xpo.ts_trigger = profile.ts_trigger;
                xpo.ts_step = profile.ts_step;
                xpo.gap_min = profile.gap_min;
                uow.CommitChanges();
            }
        }
        catch (Exception ex) { nlog.Error(ex, $"[DB:Profile] Failed to save profile for CNO:{profile.cno} GNO:{profile.gno}"); }
    }

    public async Task<int> SaveRawSignal(XSignal signal, string rawText)
    {
        try
        {
            using (var uow = new UnitOfWork(_dataLayer))
            {
                var raw = new XpoSignalRaw(uow)
                {
                    symbol = signal.symbol,
                    dir = signal.dir,
                    type = signal.type,
                    price = signal.price_signal,
                    lot = signal.lot,
                    sno = signal.sno,
                    raw_text = rawText ?? string.Empty,
                    created_at = DateTime.Now
                };
                await uow.CommitChangesAsync();
                return raw.Oid;
            }
        }
        catch (Exception ex)
        {
            nlog.Error(ex, $"[DB:Raw] Error saving raw signal for SID Pattern: {signal.sid}");
            return 0;
        }
    }

    private async Task ProcessSignalQueue()
    {
        while (_dbLoopCancelSource != null && !_dbLoopCancelSource.IsCancellationRequested)
        {
            try
            {
                if (!_signalQueue.IsEmpty)
                {
                    using var uow = new UnitOfWork(_dataLayer);
                    var processedSignals = new List<XDataObject>();
                    var seenSidsInBatch = new HashSet<string>();

                    while (_signalQueue.TryDequeue(out var xdo))
                    {
                        if (xdo.Signal != null && !string.IsNullOrEmpty(xdo.Signal.sid))
                        {
                            if (seenSidsInBatch.Contains(xdo.Signal.sid)) 
                            {
                                nlog.Debug($"[DB:SIGNAL] Skipping duplicate SID in same batch: {xdo.Signal.sid}");
                                continue;
                            }
                            seenSidsInBatch.Add(xdo.Signal.sid);
                        }
                        if (xdo.CMD == "GROUP_CLOSE") OnGroupCloseInternal(uow, xdo);
                        else OnNewSignalInternal(uow, xdo);
                        processedSignals.Add(xdo);
                    }

                    if (processedSignals.Count > 0)
                    {
                        try
                        {
                            uow.CommitChanges();
                            nlog.Info($"[DB:SIGNAL] Committed {processedSignals.Count} operations.");
                        }
                        catch (Exception ex)
                        {
                            nlog.Error(ex, $"[DB:SIGNAL] COMMIT FAILED!");
                            throw;
                        }
                    }
                }
            }
            catch (Exception ex) { nlog.Error(ex, "[DB:SIGNAL] Processing error."); }
            await Task.Delay(500);
        }
    }

    private async Task ProcessMessageQueue()
    {
        while (_dbLoopCancelSource != null && !_dbLoopCancelSource.IsCancellationRequested)
        {
            try
            {
                if (!_messageQueue.IsEmpty)
                {
                    using (var uow = new UnitOfWork(_dataLayer))
                    {
                        while (_messageQueue.TryDequeue(out var xdo))
                        {
                            _ = new XpoTgMessage(uow)
                            {
                                CID = xdo.CID,
                                Time = xdo.Timestamp == DateTime.MinValue ? DateTime.Now : xdo.Timestamp,
                                CNO = xdo.CNO,
                                Text = xdo.Text ?? string.Empty,
                                Status = 0
                            };
                        }
                        uow.CommitChanges();
                    }
                }
            }
            catch (Exception ex) { nlog.Error(ex, "[DB:MESSAGE] Error."); }
            await Task.Delay(1000);
        }
    }

    private void OnNewSignalInternal(UnitOfWork uow, XDataObject xdo)
    {
        if (xdo?.Signal == null) return;

        var existingBySid = uow.GetObjectByKey<XpoSignal>(xdo.Signal.sid);
        if (existingBySid != null)
        {
            existingBySid.msg_id = xdo.Signal.msg_id;
            existingBySid.price_signal = xdo.Signal.price_signal;
            existingBySid.price_limit = xdo.Signal.price_limit;
            existingBySid.price = xdo.Signal.price;
            existingBySid.offset = xdo.Signal.offset;
            existingBySid.lot = xdo.Signal.lot;
            existingBySid.sl = xdo.Signal.sl;
            existingBySid.tp = xdo.Signal.tp;
            
            // XEA 기준 명칭 (te_)
            existingBySid.te_start = xdo.Signal.te_start;
            existingBySid.te_step = xdo.Signal.te_step;
            existingBySid.te_limit = xdo.Signal.te_limit;
            existingBySid.te_interval = xdo.Signal.te_interval;
            existingBySid.ts_start = xdo.Signal.ts_start;
            existingBySid.ts_step = xdo.Signal.ts_step;

            existingBySid.price_open = xdo.Signal.price_open;
            existingBySid.price_close = xdo.Signal.price_close;
            existingBySid.price_tp = xdo.Signal.price_tp;
            existingBySid.price_sl = xdo.Signal.price_sl;
            existingBySid.updated = DateTime.Now;

            nlog.Info($"[DB:SIGNAL] Updated entry_signals SID:{xdo.Signal.sid}");
            return;
        }

        var newXpo = xdo.Signal.ToXpoSignal(uow);
        newXpo.msg_id = xdo.MsgId;
        nlog.Info($"[DB:SIGNAL] Created entry_signals SID:{xdo.Signal.sid}");
    }

    private void OnGroupCloseInternal(UnitOfWork uow, XDataObject xdo)
    {
        if (xdo?.Signal == null) return;

        // [v16.0] xa_status, ea_status 제거됨
        var exitXpo = new XpoExitSignal(uow)
        {
            sid = xdo.Signal.sid,
            symbol = xdo.Signal.symbol,
            dir = xdo.Signal.dir,
            lot = xdo.Signal.lot,
            ticket = xdo.Signal.ticket,
            comment = xdo.Signal.comment ?? xdo.Signal.sid,
            created = DateTime.Now,
            updated = DateTime.Now,
            cno = xdo.Signal.cno
        };

        nlog.Info($"[DB:CLOSE] Inserted into exit_signals | SID:{xdo.Signal.sid}");
    }

    public XSignal? GetSignalBySid(string sid)
    {
        if (string.IsNullOrEmpty(sid)) return null;
        try
        {
            using (var uow = new UnitOfWork(_dataLayer))
            {
                var xpo = uow.FindObject<XpoSignal>(CriteriaOperator.Parse("sid = ?", sid));
                if (xpo != null) return XSignal.FromXpoSignal(xpo);
            }
        }
        catch (Exception ex) { nlog.Error(ex, $"[DB HUB] Error SID: {sid}"); }
        return null;
    }

    public List<XSignal> GetSignalsByCno(int cno, int count = 20)
    {
        var result = new List<XSignal>();
        try
        {
            using (var uow = new UnitOfWork(_dataLayer))
            {
                CriteriaOperator? criteria = cno > 0 ? CriteriaOperator.Parse("StartsWith(sid, ?)", string.Format("{0:D4}-", cno)) : null;
                var collection = new XPCollection<XpoSignal>(uow, criteria, new SortProperty("created", SortingDirection.Descending));
                if (count > 0) collection.TopReturnedObjects = count;
                foreach (var xpo in collection)
                {
                    var signal = XSignal.FromXpoSignal(xpo);
                    if (signal != null) result.Add(signal);
                }
            }
        }
        catch (Exception ex) { nlog.Error(ex, $"[DB:GetSignalsByCno] Error CNO:{cno}"); }
        return result;
    }

    public void DeleteSignalsByCno(int cno)
    {
        try
        {
            using var session = new Session(_dataLayer);
            string sql = cno > 0 
                ? $"DELETE FROM server_signals WHERE sid LIKE '{cno:D4}-%'" 
                : "DELETE FROM server_signals"; // cno가 0이면 전체 삭제
            
            session.ExecuteNonQuery(sql);
            nlog.Info($"[DB:Delete] Executed: {sql}");
        }
        catch (Exception ex) { nlog.Error(ex, $"[DB:Delete] Error deleting signals for CNO:{cno}"); }
    }

    public void DeleteSignal(string signalId)
    {
        if (string.IsNullOrEmpty(signalId)) return;
        try
        {
            using (var uow = new UnitOfWork(_dataLayer))
            {
                var signalToDelete = uow.GetObjectByKey<XpoSignal>(signalId);
                if (signalToDelete != null)
                {
                    signalToDelete.Delete();
                    uow.CommitChanges();
                }
            }
        }
        catch (Exception ex) { nlog.Error(ex, $"[DB HUB] Error deleting: {signalId}"); }
    }

    public long GetMaxSignalId(int cno)
    {
        try
        {
            using var session = new Session(_dataLayer);
            var result = session.ExecuteScalar($"SELECT MAX(updated) FROM server_signals WHERE sid LIKE '{cno:D4}-%'");
            if (result != null && DateTime.TryParse(result.ToString(), out DateTime dt)) return dt.Ticks;
        }
        catch (Exception ex) { nlog.Error(ex); }
        return 0;
    }

    private void OnDeleteRowRequested(XDataObject xdo)
    {
        if (xdo?.Signal == null) return;
        DeleteSignal(xdo.Signal.sid);
    }
}
