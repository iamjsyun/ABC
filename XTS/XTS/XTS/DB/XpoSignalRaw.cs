using System;
using DevExpress.Xpo;

namespace XTS.XModels.DB;

/// <summary>
/// 해석기(Interpreter)가 추출한 순수 신호 정보 및 원본 텍스트 저장
/// (XpoTgMessage와의 연관성 없이 독립적으로 원본 데이터 보존)
/// </summary>
[Persistent("server_signals_raw")]
public class XpoSignalRaw : XPLiteObject
{
    public XpoSignalRaw(Session session) : base(session) { }

    [Key(true)]
    public int Oid { get; set; }

    [Persistent("symbol"), Size(20)]
    public string symbol { get; set; } = null!;

    [Persistent("dir")]
    public int dir { get; set; } // 1: BUY, -1: SELL

    [Persistent("type")]
    public int type { get; set; } // 0: Market, 1: Limit...

    [Persistent("price")]
    public double price { get; set; }

    [Persistent("lot")]
    public double lot { get; set; } // 해석기가 읽은 원본 랏

    [Persistent("sno")]
    public int sno { get; set; }

    [Persistent("raw_text"), Size(SizeAttribute.Unlimited)]
    public string raw_text { get; set; } = null!; // 신호를 추출한 원본 텍스트 전체

    [Persistent("created_at")]
    public DateTime created_at { get; set; } = DateTime.Now;
}
