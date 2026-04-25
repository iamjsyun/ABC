using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Data;
using DevExpress.Mvvm;
using DevExpress.Mvvm.DataAnnotations;
using XTS.XModels;
using XTS.XModels.DB;
using XTS.XServices;

namespace XTS.WPF.UI
{
    public class DirToTextConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value is int dir)
            {
                return dir == 1 ? "BUY" : (dir == 2 ? "SELL" : dir.ToString());
            }
            return value?.ToString() ?? string.Empty;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            string str = value?.ToString()?.ToUpper() ?? string.Empty;
            if (str == "BUY") return 1;
            if (str == "SELL") return 2;
            return 0;
        }
    }

    public class SignalViewModel : ViewModelBase
    {
        private readonly XParameter? _param;
        private readonly XpoSqliteService? _db;
        private readonly XGatewayService? _gateway;
        private readonly System.Windows.Threading.DispatcherTimer _timer;

        public SignalViewModel()
        {
            if (App.Param == null)
            {
                _timer = new System.Windows.Threading.DispatcherTimer();
                return;
            }

            _param = App.Param;
            _db = _param.GetService<XpoSqliteService>();
            _gateway = _param.GetService<XGatewayService>();

            InitData();

            _timer = new System.Windows.Threading.DispatcherTimer();
            _timer.Interval = TimeSpan.FromSeconds(1);
            _timer.Tick += (s, e) => RefreshSilent();
            _timer.Start();
        }

        private void RefreshSilent()
        {
            if (_db == null) return;
            var list = _db.GetSignalsByCno(0, 100);

            App.Current.Dispatcher.Invoke(() => {
                var selectedSid = SelectedSignal?.sid;
                if (Signals.Count != list.Count || IsDataChanged(list))
                {
                    Signals.Clear();
                    foreach (var s in list) Signals.Add(s);
                    if (!string.IsNullOrEmpty(selectedSid))
                        SelectedSignal = Signals.FirstOrDefault(x => x.sid == selectedSid);
                }
            });
        }

        private bool IsDataChanged(List<XSignal> newList)
        {
            if (Signals.Count != newList.Count) return true;
            for (int i = 0; i < Signals.Count; i++)
            {
                if (Signals[i].updated != newList[i].updated) return true;
            }
            return false;
        }

        private void InitData()
        {
            if (_param == null) return;
            Channels = new ObservableCollection<XChannelInfo>(_param.Config.Channels.Values);
            SelectedCno = Channels.FirstOrDefault()?.CNO ?? 0;
            CbeDate = DateTime.Now.ToString("yyMMdd");
            CbeHour = DateTime.Now.ToString("HH");
            SnoList = Enumerable.Range(1, 50).Select(i => i.ToString("D2")).ToList();
            GnoList = Enumerable.Range(0, 21).Select(i => i.ToString("D2")).ToList();
            HourList = Enumerable.Range(0, 24).Select(i => i.ToString("D2")).ToList();
            DirList = new List<object> { new { Name = "BUY", Value = 1 }, new { Name = "SELL", Value = 2 } };
            TypeList = new List<object> { 
                new { Name = "MARKET", Value = 1 }, 
                new { Name = "LIMIT_M", Value = 2 }, 
                new { Name = "LIMIT_P", Value = 4 } 
            };
            Default();
            Refresh();
        }

        #region Properties
        public virtual ObservableCollection<XChannelInfo> Channels { get; set; } = null!;
        public virtual int SelectedCno { get; set; }
        public virtual string CbeDate { get; set; } = string.Empty;
        public virtual string CbeHour { get; set; } = string.Empty;
        public virtual List<string> SnoList { get; set; } = null!;
        public virtual string SelectedSno { get; set; } = string.Empty;
        public virtual List<string> GnoList { get; set; } = null!;
        public virtual string SelectedGno { get; set; } = string.Empty;
        public virtual List<string> HourList { get; set; } = null!;
        public virtual List<object> DirList { get; set; } = null!;
        public virtual int SelectedDir { get; set; }
        public virtual List<object> TypeList { get; set; } = null!;
        public virtual int SelectedType { get; set; }
        public virtual string Symbol { get; set; } = string.Empty;
        public virtual double Price { get; set; }
        public virtual double PriceLimit { get; set; }
        public virtual double PriceFinal { get; set; }
        public virtual double Lot { get; set; }
        public virtual double Tp { get; set; }
        public virtual double Sl { get; set; }
        public virtual double Offset { get; set; }
        public virtual double TeStart { get; set; }
        public virtual double TeStep { get; set; }
        public virtual double TeLimit { get; set; }
        public virtual int TeInterval { get; set; }
        public virtual int TsStart { get; set; }
        public virtual int TsStep { get; set; }
        public virtual int XaStatus { get; set; }
        public virtual int EaStatus { get; set; }
        public virtual ObservableCollection<XSignal> Signals { get; set; } = new();
        public virtual XSignal? SelectedSignal { get; set; }
        protected void OnSelectedSignalChanged()
        {
            if (SelectedSignal == null) return;
            var s = SelectedSignal;
            SelectedCno = s.cno;
            Symbol = s.symbol ?? string.Empty;
            SelectedDir = s.dir;
            SelectedType = s.type;
            Price = s.price_signal;
            PriceLimit = s.price_limit;
            PriceFinal = s.price;
            Lot = s.lot;
            Tp = s.tp;
            Sl = s.sl;
            Offset = s.offset;
            TeStart = s.te_start;
            TeStep = s.te_step;
            TeLimit = s.te_limit;
            TeInterval = s.te_interval;
            TsStart = s.ts_start;
            TsStep = s.ts_step;
            XaStatus = s.xa_status;
            EaStatus = s.ea_status;
            SelectedSno = s.sno.ToString("D2");
            SelectedGno = s.gno.ToString("D2");
            if (!string.IsNullOrEmpty(s.sid_date) && s.sid_date.Length >= 8) {
                CbeDate = s.sid_date.Substring(0, 6);
                CbeHour = s.sid_date.Substring(6, 2);
            }
        }
        #endregion

        [Command]
        public void Insert()
        {
            if (_param == null || string.IsNullOrEmpty(Symbol)) return;
            var s = CreateSignalFromFields();
            if (s.Validate()) {
                _param.nlog.Trace($"[UI:Insert] Generated SID: {s.sid}");
                SendSignalToDb(s, "DB_SAVE_SIGNAL");
                Task.Delay(1000).ContinueWith(_ => Refresh());
            } else {
                _param.nlog.Warn("[UI:Insert] Signal validation failed.");
            }
        }

        [Command]
        public void Update()
        {
            if (_param == null || string.IsNullOrEmpty(Symbol)) return;
            var s = CreateSignalFromFields();
            if (SelectedSignal != null) {
                s.sid = SelectedSignal.sid;
                s.created = SelectedSignal.created;
            } else {
                s.Validate();
            }
            SendSignalToDb(s, "DB_SAVE_SIGNAL");
            Task.Delay(1000).ContinueWith(_ => Refresh());
        }

        private XSignal CreateSignalFromFields()
        {
            return new XSignal {
                cno = SelectedCno,
                symbol = Symbol,
                dir = SelectedDir,
                type = SelectedType,
                price_signal = Price,
                price_limit = PriceLimit,
                price = PriceFinal,
                lot = Lot,
                tp = Tp,
                sl = Sl,
                offset = Offset,
                te_start = TeStart,
                te_step = TeStep,
                te_limit = TeLimit,
                te_interval = TeInterval,
                ts_start = TsStart,
                ts_step = TsStep,
                xa_status = XaStatus,
                ea_status = EaStatus,
                sno = int.Parse(SelectedSno),
                gno = int.Parse(SelectedGno),
                sid_date = CbeDate + CbeHour,
                created = DateTime.Now,
                updated = DateTime.Now
            };
        }

        private void SendSignalToDb(XSignal s, string cmdTag)
        {
            if (_param == null) return;
            var xdo = new XDataObject {
                Signal = s,
                CNO = s.cno,
                CID = _param.GetChannelByCno(s.cno)?.CID ?? 0,
                CMD = cmdTag == "DB_SAVE_SIGNAL" ? "NEW_SIGNAL" : "GROUP_CLOSE"
            };
            _param.messenger.Send(xdo, "DB_SAVE_SIGNAL");
            if (cmdTag == "DB_SAVE_SIGNAL") _param.messenger.Send(xdo, "channel_signal_dispatch");
        }

        [Command]
        public void Close()
        {
            if (_param == null || SelectedSignal == null) return;
            var s = SelectedSignal;
            _param.nlog.Info($"[UI:Close] Injecting liquidation signal into exit_signals for SID: {s.sid}");
            var closeSignal = s.Clone();
            closeSignal.cmd = XCode.CLOSE;
            closeSignal.updated = DateTime.Now;
            SendSignalToDb(closeSignal, "GROUP_CLOSE");
            Task.Delay(500).ContinueWith(_ => Refresh());
        }

        [Command]
        public void Search() { Refresh(); }

        [Command]
        public void Delete()
        {
            if (_db == null || _param == null) return;
            string targetSid = SelectedSignal?.sid ?? string.Empty;
            if (string.IsNullOrEmpty(targetSid)) {
                var s = CreateSignalFromFields();
                s.Validate();
                targetSid = s.sid;
            }
            _db.DeleteSignal(targetSid);
            Refresh();
            ClearFields();
        }

        [Command]
        public void Default()
        {
            SelectedCno = Channels?.FirstOrDefault()?.CNO ?? 0;
            SelectedSno = SnoList?.FirstOrDefault() ?? "01";
            SelectedGno = GnoList?.FirstOrDefault() ?? "00";
            SelectedDir = 1;
            SelectedType = 4;
            CbeDate = DateTime.Now.ToString("yyMMdd");
            CbeHour = DateTime.Now.ToString("HH");
            Symbol = "GOLD#";
            Lot = 0.01;
            Price = 0.0;
            Tp = 400;
            Sl = 0;
            TsStart = 300;
            TsStep = 50;
            Offset = 400;
            TeStart = 200;
            TeStep = 50;
            TeLimit = 500;
            TeInterval = 60;
            XaStatus = 1;
            EaStatus = 0;
            SelectedSignal = null;
        }

        private void ClearFields() { Default(); }

        [Command]
        public void ClearTable()
        {
            if (_db == null || _param == null) return;
            _db.DeleteSignalsByCno(0);
            Refresh();
            ClearFields();
        }

        [Command]
        public void Refresh()
        {
            if (_db == null || _param == null) return;
            var list = _db.GetSignalsByCno(0, 100);
            App.Current.Dispatcher.Invoke(() => {
                Signals.Clear();
                foreach (var s in list) Signals.Add(s);
            });
        }
    }
}
