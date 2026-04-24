using System;
using DevExpress.Xpo;

namespace XTS.XModels.DB;

[Persistent("tg_signal")]
public class XpoTgSignal : XPObject
{
    public XpoTgSignal() : base() { }
    public XpoTgSignal(Session session) : base(session) { }

    [Persistent("sid"), Size(14), Indexed(Unique = true)]
    public string SID { get; set; } = string.Empty;

    [Persistent("cid")]
    public long CID { get; set; } = 0;

    [Persistent("cno")]
    public int CNO { get; set; }

    [Persistent("symbol"), Size(16)]
    public string Symbol { get; set; } = string.Empty;

    [Persistent("direction")]
    public int Direction { get; set; } // 1: Buy, 2: Sell

    [Persistent("entry_price")]
    public double EntryPrice { get; set; }

    [Persistent("lot")]
    public double Lot { get; set; }

    [Persistent("tp"), Size(64)]
    public string TP { get; set; } = string.Empty; // 복수 TP 저장용 (예: "2150.5|2160.0")

    [Persistent("sl")]
    public double SL { get; set; }

    [Persistent("exit_price")]
    public double ExitPrice { get; set; }

    [Persistent("exit_time")]
    public DateTime ExitTime { get; set; }

    [Persistent("msg_id")]
    public int MsgId { get; set; } // Oid of XpoTgMessage

    [Persistent("status")]
    public int Status { get; set; } // 0: Pending, 1: Active, 3: Closed, 9: Error

    [Persistent("raw_message"), Size(SizeAttribute.Unlimited)]
    public string RawMessage { get; set; } = string.Empty;

    [Persistent("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.Now;

    [Persistent("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.Now;

    protected override void OnSaving()
    {
        UpdatedAt = DateTime.Now;
        base.OnSaving();
    }
}
