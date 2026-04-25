using System;
using DevExpress.Xpo;
using XTS.XModels;

namespace XTS.XModels.DB;

/**
 * [XTS Model] XEA 스키마 명칭 준수 (v16.1)
 * Table: entry_signals
 * Restoration: xa_status, ea_status (Crucial for XEA Watcher)
 */
[Persistent("entry_signals")]
public class XpoSignal : XPLiteObject
{
    public XpoSignal(Session session) : base(session) 
    { 
        // Default values for new signals
        if (Session.IsNewObject(this))
        {
            this.xa_status = 1; // Accepted
            this.ea_status = 0; // Ready
        }
    }

    [Key(false), Size(50)]
    public string sid
    {
        get => GetPropertyValue<string>(nameof(sid))!;
        set => SetPropertyValue(nameof(sid), value);
    }

    public int msg_id
    {
        get => GetPropertyValue<int>(nameof(msg_id));
        set => SetPropertyValue(nameof(msg_id), value);
    }

    [Size(20)]
    public string symbol
    {
        get => GetPropertyValue<string>(nameof(symbol))!;
        set => SetPropertyValue(nameof(symbol), value);
    }

    public int dir
    {
        get => GetPropertyValue<int>(nameof(dir));
        set => SetPropertyValue(nameof(dir), value);
    }

    public int type
    {
        get => GetPropertyValue<int>(nameof(type));
        set => SetPropertyValue(nameof(type), value);
    }

    public double price_signal
    {
        get => GetPropertyValue<double>(nameof(price_signal));
        set => SetPropertyValue(nameof(price_signal), value);
    }

    public double offset
    {
        get => GetPropertyValue<double>(nameof(offset));
        set => SetPropertyValue(nameof(offset), value);
    }

    public double te_start
    {
        get => GetPropertyValue<double>(nameof(te_start));
        set => SetPropertyValue(nameof(te_start), value);
    }

    public double te_step
    {
        get => GetPropertyValue<double>(nameof(te_step));
        set => SetPropertyValue(nameof(te_step), value);
    }

    public double te_limit
    {
        get => GetPropertyValue<double>(nameof(te_limit));
        set => SetPropertyValue(nameof(te_limit), value);
    }

    public int te_interval
    {
        get => GetPropertyValue<int>(nameof(te_interval));
        set => SetPropertyValue(nameof(te_interval), value);
    }

    public double tp
    {
        get => GetPropertyValue<double>(nameof(tp));
        set => SetPropertyValue(nameof(tp), value);
    }

    public double sl
    {
        get => GetPropertyValue<double>(nameof(sl));
        set => SetPropertyValue(nameof(sl), value);
    }

    public int ts_start
    {
        get => GetPropertyValue<int>(nameof(ts_start));
        set => SetPropertyValue(nameof(ts_start), value);
    }

    public int ts_step
    {
        get => GetPropertyValue<int>(nameof(ts_step));
        set => SetPropertyValue(nameof(ts_step), value);
    }

    public int close_type
    {
        get => GetPropertyValue<int>(nameof(close_type));
        set => SetPropertyValue(nameof(close_type), value);
    }

    public int xa_status
    {
        get => GetPropertyValue<int>(nameof(xa_status));
        set => SetPropertyValue(nameof(xa_status), value);
    }

    public int ea_status
    {
        get => GetPropertyValue<int>(nameof(ea_status));
        set => SetPropertyValue(nameof(ea_status), value);
    }

    public double trail_price
    {
        get => GetPropertyValue<double>(nameof(trail_price));
        set => SetPropertyValue(nameof(trail_price), value);
    }

    public double price_limit
    {
        get => GetPropertyValue<double>(nameof(price_limit));
        set => SetPropertyValue(nameof(price_limit), value);
    }

    public double price
    {
        get => GetPropertyValue<double>(nameof(price));
        set => SetPropertyValue(nameof(price), value);
    }

    public double price_open
    {
        get => GetPropertyValue<double>(nameof(price_open));
        set => SetPropertyValue(nameof(price_open), value);
    }

    public double price_close
    {
        get => GetPropertyValue<double>(nameof(price_close));
        set => SetPropertyValue(nameof(price_close), value);
    }

    public double price_tp
    {
        get => GetPropertyValue<double>(nameof(price_tp));
        set => SetPropertyValue(nameof(price_tp), value);
    }

    public double price_sl
    {
        get => GetPropertyValue<double>(nameof(price_sl));
        set => SetPropertyValue(nameof(price_sl), value);
    }

    public double lot
    {
        get => GetPropertyValue<double>(nameof(lot));
        set => SetPropertyValue(nameof(lot), value);
    }

    public long ticket
    {
        get => GetPropertyValue<long>(nameof(ticket));
        set => SetPropertyValue(nameof(ticket), value);
    }

    public long magic
    {
        get => GetPropertyValue<long>(nameof(magic));
        set => SetPropertyValue(nameof(magic), value);
    }

    [Size(255)]
    public string comment
    {
        get => GetPropertyValue<string>(nameof(comment))!;
        set => SetPropertyValue(nameof(comment), value);
    }

    [Size(100)]
    public string tag
    {
        get => GetPropertyValue<string>(nameof(tag))!;
        set => SetPropertyValue(nameof(tag), value);
    }

    public DateTime created
    {
        get => GetPropertyValue<DateTime>(nameof(created));
        set => SetPropertyValue(nameof(created), value);
    }

    public DateTime updated
    {
        get => GetPropertyValue<DateTime>(nameof(updated));
        set => SetPropertyValue(nameof(updated), value);
    }

    [NonPersistent] public int cno { get; set; }
    [NonPersistent] public int sno { get; set; }
    [NonPersistent] public int gno { get; set; }
    [NonPersistent] public string args { get; set; } = string.Empty;
}
