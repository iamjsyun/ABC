using System;
using System.Collections.Generic;

namespace XTS.XModels;



public class XDataObject
{
    public string? CMD { get; set; } 
    public object? Payload { get; set; }
    public long CID { get; set; }
    public string? CName { get; set; }
    public string? Text { get; set; }
    public string? Sender { get; set; }
    public int CNO { get; set; }
    public int MsgId { get; set; } // Oid from DB
    public DateTime Timestamp { get; set; } = DateTime.Now;

    public bool Simulation { get; set; } = false;
    public XSignal? Signal { get; set; }

    public T? GetSignal<T>() where T : class
    {
        if (Signal == null) return null;
        return Signal as T;
    }
}
