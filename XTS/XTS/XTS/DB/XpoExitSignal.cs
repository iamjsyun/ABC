using System;
using DevExpress.Xpo;
using XTS.XModels;

namespace XTS.XModels.DB;

/**
 * [XTS Model] 청산 신호 테이블 (v16.1)
 * Table: exit_signals
 * Restoration: xa_status, ea_status
 */
[Persistent("exit_signals")]
public class XpoExitSignal : XPLiteObject
{
    public XpoExitSignal(Session session) : base(session) 
    { 
        if (Session.IsNewObject(this))
        {
            this.xa_status = 1;
            this.ea_status = 0;
        }
    }

    [Key(false), Size(50)]
    public string sid
    {
        get => GetPropertyValue<string>(nameof(sid))!;
        set => SetPropertyValue(nameof(sid), value);
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
    public int sno { get; set; }
    public int gno { get; set; }
}
