using System;
using DevExpress.Mvvm;
using DevExpress.Xpo;
using XTS.XModels.DB;

#pragma warning disable IDE1006 // Naming Styles

namespace XTS.XModels;

public class XSignalObject : BindableBase       
{
    private string _sid = string.Empty;
    public string sid { get => _sid; set => SetProperty(ref _sid, value, nameof(sid)); }

    public int msg_id { get; set; }
    public int raw_id { get; set; }

    private string _symbol = string.Empty;
    public string symbol { get => _symbol; set => SetProperty(ref _symbol, value, nameof(symbol)); }

    private int _dir;
    public int dir { get => _dir; set => SetProperty(ref _dir, value, nameof(dir)); }

    private int _type;
    public int type { get => _type; set => SetProperty(ref _type, value, nameof(type)); }

    private double _price_signal;
    public double price_signal { get => _price_signal; set => SetProperty(ref _price_signal, value, nameof(price_signal)); }

    private double _offset;
    public double offset { get => _offset; set => SetProperty(ref _offset, value, nameof(offset)); }

    //-- XEA Standard: te_ prefix
    private double _te_start;
    public double te_start { get => _te_start; set => SetProperty(ref _te_start, value, nameof(te_start)); }

    private double _te_step;
    public double te_step { get => _te_step; set => SetProperty(ref _te_step, value, nameof(te_step)); }

    private double _te_limit;
    public double te_limit { get => _te_limit; set => SetProperty(ref _te_limit, value, nameof(te_limit)); }

    private int _te_interval;
    public int te_interval { get => _te_interval; set => SetProperty(ref _te_interval, value, nameof(te_interval)); }

    private double _tp;
    public double tp { get => _tp; set => SetProperty(ref _tp, value, nameof(tp)); }

    private double _sl;
    public double sl { get => _sl; set => SetProperty(ref _sl, value, nameof(sl)); }

    private int _ts_start;
    public int ts_start { get => _ts_start; set => SetProperty(ref _ts_start, value, nameof(ts_start)); }

    private int _ts_step;
    public int ts_step { get => _ts_step; set => SetProperty(ref _ts_step, value, nameof(ts_step)); }

    private int _close_type;
    public int close_type { get => _close_type; set => SetProperty(ref _close_type, value, nameof(close_type)); }

    private double _trail_price;
    public double trail_price { get => _trail_price; set => SetProperty(ref _trail_price, value, nameof(trail_price)); }

    private double _price_limit;
    public double price_limit { get => _price_limit; set => SetProperty(ref _price_limit, value, nameof(price_limit)); }

    private double _price;
    public double price { get => _price; set => SetProperty(ref _price, value, nameof(price)); }

    private double _price_open;
    public double price_open { get => _price_open; set => SetProperty(ref _price_open, value, nameof(price_open)); }

    private double _price_close;
    public double price_close { get => _price_close; set => SetProperty(ref _price_close, value, nameof(price_close)); }

    private double _price_tp;
    public double price_tp { get => _price_tp; set => SetProperty(ref _price_tp, value, nameof(price_tp)); }

    private double _price_sl;
    public double price_sl { get => _price_sl; set => SetProperty(ref _price_sl, value, nameof(price_sl)); }

    private double _lot;
    public double lot { get => _lot; set => SetProperty(ref _lot, value, nameof(lot)); }

    private long _ticket;
    public long ticket { get => _ticket; set => SetProperty(ref _ticket, value, nameof(ticket)); }

    private long _magic;
    public long magic { get => _magic; set => SetProperty(ref _magic, value, nameof(magic)); }

    private string _comment = string.Empty;
    public string comment { get => _comment; set => SetProperty(ref _comment, value, nameof(comment)); }

    private string _tag = string.Empty;
    public string tag { get => _tag; set => SetProperty(ref _tag, value, nameof(tag)); }

    private DateTime _created;
    public DateTime created { get => _created; set => SetProperty(ref _created, value, nameof(created)); }

    private DateTime _updated;
    public DateTime updated { get => _updated; set => SetProperty(ref _updated, value, nameof(updated)); }

    // Logic fields
    public int cno { get; set; }
    public int sno { get; set; }
    public int gno { get; set; }
    public string cmd { get; set; } = string.Empty;
    public string? sid_date { get; set; }
    public string args { get; set; } = string.Empty;
}

public class XSignal : XSignalObject
{
    public bool Validate()
    {
        if (created == DateTime.MinValue) created = DateTime.Now;
        updated = DateTime.Now;

        if (cno <= 0 || string.IsNullOrEmpty(symbol)) return false;
        symbol = symbol.ToUpper().Trim();

        if (price_signal < 0) return false;

        string dateStr = !string.IsNullOrEmpty(sid_date) ? sid_date : created.ToString("yyMMddHH");

        if (string.IsNullOrEmpty(sid) || sid.Contains("--"))
        {
            sid = string.Format("{0:D4}-{1}-{2:D2}-{3:D2}-{4}-{5}",
                cno, dateStr, sno, gno, Math.Abs(dir), type);
        }

        if (string.IsNullOrEmpty(comment))
        {
            comment = sid;
        }

        return true;
    }

    public XpoSignal ToXpoSignal(UnitOfWork uow)
    {
        var xpo = new XpoSignal(uow)
        {
            sid = this.sid,
            msg_id = this.msg_id,
            symbol = this.symbol,
            dir = this.dir,
            type = this.type,
            price_signal = this.price_signal,
            offset = this.offset,
            te_start = this.te_start,
            te_step = this.te_step,
            te_limit = this.te_limit,
            te_interval = this.te_interval,
            tp = this.tp,
            sl = this.sl,
            ts_start = this.ts_start,
            ts_step = this.ts_step,
            close_type = this.close_type,
            trail_price = this.trail_price,
            price_limit = this.price_limit,
            price = this.price,
            price_open = this.price_open,
            price_close = this.price_close,
            price_tp = this.price_tp,
            price_sl = this.price_sl,
            lot = this.lot,
            ticket = this.ticket,
            magic = this.magic,
            comment = this.comment,
            tag = this.tag,
            created = this.created,
            updated = this.updated
        };
        return xpo;
    }

    public static XSignal FromXpoSignal(XpoSignal xpo)
    {
        var s = new XSignal
        {
            sid = xpo.sid,
            msg_id = xpo.msg_id,
            symbol = xpo.symbol,
            dir = xpo.dir,
            type = xpo.type,
            price_signal = xpo.price_signal,
            offset = xpo.offset,
            te_start = xpo.te_start,
            te_step = xpo.te_step,
            te_limit = xpo.te_limit,
            te_interval = xpo.te_interval,
            tp = xpo.tp,
            sl = xpo.sl,
            ts_start = xpo.ts_start,
            ts_step = xpo.ts_step,
            close_type = xpo.close_type,
            trail_price = xpo.trail_price,
            price_limit = xpo.price_limit,
            price = xpo.price,
            price_open = xpo.price_open,
            price_close = xpo.price_close,
            price_tp = xpo.price_tp,
            price_sl = xpo.price_sl,
            lot = xpo.lot,
            ticket = xpo.ticket,
            magic = xpo.magic,
            comment = xpo.comment,
            tag = xpo.tag,
            created = xpo.created,
            updated = xpo.updated
        };

        try {
            if (!string.IsNullOrEmpty(xpo.sid))
            {
                var parts = xpo.sid.Split('-', '+');
                if (parts.Length >= 4) {
                    if (int.TryParse(parts[0], out int c)) s.cno = c;
                    if (int.TryParse(parts[2], out int sn)) s.sno = sn;
                    if (int.TryParse(parts[3], out int gn)) s.gno = gn;
                }
            }
        } catch {}

        return s;
    }

    public XSignal Clone()
    {
        return new XSignal
        {
            sid = this.sid,
            msg_id = this.msg_id,
            symbol = this.symbol,
            dir = this.dir,
            type = this.type,
            price_signal = this.price_signal,
            offset = this.offset,
            te_start = this.te_start,
            te_step = this.te_step,
            te_limit = this.te_limit,
            te_interval = this.te_interval,
            tp = this.tp,
            sl = this.sl,
            ts_start = this.ts_start,
            ts_step = this.ts_step,
            close_type = this.close_type,
            trail_price = this.trail_price,
            price_limit = this.price_limit,
            price = this.price,
            price_open = this.price_open,
            price_close = this.price_close,
            price_tp = this.price_tp,
            price_sl = this.price_sl,
            lot = this.lot,
            ticket = this.ticket,
            magic = this.magic,
            comment = this.comment,
            tag = this.tag,
            created = this.created,
            updated = this.updated,
            cno = this.cno,
            sno = this.sno,
            gno = this.gno,
            cmd = this.cmd,
            args = this.args
        };
    }
}
