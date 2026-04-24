using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using DevExpress.Mvvm;
using DevExpress.Data.Filtering;
using DevExpress.Xpo;
using XTS.XModels;
using XTS.XModels.DB;

namespace XTS.XServices;

/// <summary>
/// XSyncWorker: 누락된 메시지를 주기적으로 스캔하여 재해석 및 주입을 보장하는 백그라운드 서비스
/// </summary>
public class XSyncWorker : XObject
{
    private Timer? _syncTimer;
    private bool _isBusy = false;
    private readonly int _intervalSeconds = 10;
    private readonly int _lookbackMinutes = 60;
    private readonly int _maxRetryCount = 5;

    public XSyncWorker(XParameter param) : base(param)
    {
    }

    public override void Start()
    {
        _syncTimer = new Timer(OnSyncTimerCallback, null, TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(_intervalSeconds));
        nlog?.Trace($"[SyncWorker] Started. Interval: {_intervalSeconds}s, Lookback: {_lookbackMinutes}m");
    }

    public override void Stop()
    {
        _syncTimer?.Dispose();
        nlog?.Trace("[SyncWorker] Stopped.");
    }

    private void OnSyncTimerCallback(object? state)
    {
        if (_isBusy) return;
        _isBusy = true;

        try
        {
            ProcessSync().Wait();
        }
        catch (Exception ex)
        {
            nlog?.Error(ex, "[SyncWorker] Error during sync process.");
        }
        finally
        {
            _isBusy = false;
        }
    }

    private async Task ProcessSync()
    {
        var dbService = param.GetService<XpoSqliteService>();
        if (dbService == null) return;

        // 0. Trade 채널 필터링 (XConfig에서 Type이 TRADE인 CNO 목록 추출)
        var tradeCnos = param.Config.Channels.Values
            .Where(c => c.Type.Equals("TRADE", StringComparison.OrdinalIgnoreCase))
            .Select(c => c.CNO)
            .ToList();

        if (tradeCnos.Count == 0)
        {
            nlog?.Trace("[SyncWorker] No TRADE channels found in configuration. Skipping sync.");
            return;
        }

        var layer = dbService.GetLayer();
        if (layer == null) return;

        using (var uow = new UnitOfWork(layer))
        {
            // 1. 미처리(Status 0) 또는 실패(Status 2) 메시지 조회 + Trade 채널 필터링
            var lookbackTime = DateTime.Now.AddMinutes(-_lookbackMinutes);
            var criteria = CriteriaOperator.And(
                new InOperator("CNO", tradeCnos),
                CriteriaOperator.Parse("Status IN (0, 2) AND Time > ? AND RetryCount < ?", lookbackTime, _maxRetryCount)
            );
            var messages = new XPCollection<XpoTgMessage>(uow, criteria);

            if (messages.Count == 0) return;

            nlog?.Info($"[SyncWorker] Found {messages.Count} unprocessed/failed messages for TRADE channels. Starting recovery...");

            foreach (var msg in messages)
            {
                // 2. 이미 시그널이 존재하는지 이중 확인 (데이터 무결성)
                var existingSignal = uow.FindObject<XpoSignal>(CriteriaOperator.Parse("msg_id = ?", msg.Oid));
                if (existingSignal != null)
                {
                    nlog?.Warn($"[SyncWorker] Message {msg.Oid} already has a signal {existingSignal.sid}. Updating status to Processed.");
                    msg.Status = 1;
                    continue;
                }

                // 3. 재해석 트리거
                nlog?.Info($"[SyncWorker] Retrying interpretation for MsgId:{msg.Oid} | CNO:{msg.CNO}");
                
                var xdo = new XDataObject
                {
                    CID = msg.CID,
                    CNO = msg.CNO,
                    Text = msg.Text,
                    Timestamp = msg.Time,
                    MsgId = msg.Oid,
                    CMD = "RECOVERY_SYNC" // 동기화에 의한 복구임을 명시
                };

                // 메시지를 인터프리터로 전달
                messenger.Send(xdo, "MSG_TO_INTERPRET");
                
                // 4. 상태 업데이트
                msg.RetryCount++;
                if (msg.RetryCount >= _maxRetryCount)
                {
                    msg.Status = 3; // PermanentlyFailed
                    nlog?.Error($"[SyncWorker] MsgId:{msg.Oid} reached max retry count. Marked as PermanentlyFailed.");
                }
                else
                {
                    msg.Status = 2; // Failed (but waiting for next loop or interpretation result)
                }
            }

            uow.CommitChanges();
        }
    }
}
