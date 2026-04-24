using System;
using DevExpress.Xpo;

namespace XTS.XModels.DB;

[Persistent("tg_message")]
public class XpoTgMessage : XPObject
{
    public XpoTgMessage() : base() { }
    public XpoTgMessage(Session session) : base(session) { }

    [Persistent("cid")]
    public long CID { get; set; }

    [Persistent("time")]
    public DateTime Time { get; set; }

    [Persistent("cno")]
    public int CNO { get; set; }

    [Persistent("text"), Size(SizeAttribute.Unlimited)]
    public string Text { get; set; } = string.Empty;

    [Persistent("status")]
    public int Status { get; set; } // 0: New, 1: Processed, 2: Failed, 3: PermanentlyFailed

    [Persistent("retry_count")]
    public int RetryCount { get; set; }

    [Persistent("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}
