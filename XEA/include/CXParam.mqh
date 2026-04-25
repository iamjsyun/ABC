//+------------------------------------------------------------------+
//|                                              CXParam.mqh         |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_PARAM_MQH
#define CX_PARAM_MQH

#include <Object.mqh>
#include <Arrays/ArrayString.mqh>

// Domain Specific Object Headers
#include "CXSignalEntry.mqh"
#include "CXSignalExit.mqh"
#include "CXOrder.mqh"
#include "CXPosition.mqh"
#include "CXLogEntry.mqh"

// Forward declarations
class ICXReceiver;
class CXDatabase;
class CXTradeTrace;

// [v18.3] 모든 기능이 복구된 최종 통합 페이로더
class CXParam : public CObject
{
private:
   bool      m_isPriceCalculated;
   string    m_qb_table;
   string    m_qb_where;
   CArrayString m_qb_keys;
   CArrayString m_qb_vals;
   
   CArrayString m_keys;
   CArrayString m_vals;

public:
    string sid, symbol;
    ulong  magic;
    int    direction;
    double ref_price, offset_pts;
    int    strategy_no;
    string strategy_args;
    double calculated_lot;
    ulong  ticket;
    int    tb_limit, tb_start, tb_step, tb_interval;
    int    ts_start, ts_step;
    double target_price, sl_pts, tp_pts;

    ulong     sno, gno;
    double    swap, price, tp_price, sl_price;
    double    tps[], sls[], offsets[], lots[];
    datetime  time;
    string    cmd, dir, type, pid, gid, tag, kind, comment;
    string    sids_arr[];

    int           msg_id;
    ICXReceiver*  receiver;
    CObject*      payload;
    CXDatabase*   db;

    CXSignalEntry*  signal_entry;
    CXSignalExit*   signal_exit;
    CXOrder*        order;
    CXPosition*     pos;
    CXTradeTrace*   trace;
    CXLogEntry*     log_entry;

    CXParam() { Clear(); }
    ~CXParam() { QB_Reset(); m_keys.Clear(); m_vals.Clear(); }

    void Clear() {
      magic=0; ticket=0; sno=0; gno=0; swap=0; price=0; tp_price=0; sl_price=0;
      strategy_no=0; strategy_args=""; calculated_lot=0;
      ArrayResize(tps, 1); tps[0] = 0; ArrayResize(sls, 1); sls[0] = 0;
      ArrayResize(offsets, 1); offsets[0] = 0; ArrayResize(lots, 1); lots[0] = 0.01;
      ArrayResize(sids_arr, 0);
      cmd="NONE"; dir="NONE"; type="NONE"; symbol=_Symbol;
      pid=""; sid=""; gid=""; tag=""; kind="SIM"; comment="";
      time=TimeCurrent(); m_isPriceCalculated = false;
      db = NULL; receiver = NULL; payload = NULL;
      signal_entry = NULL; signal_exit = NULL; order = NULL; pos = NULL; trace = NULL; log_entry = NULL;
      QB_Reset(); m_keys.Clear(); m_vals.Clear();
    }

    // --- [ Fluent Query Builder ] ---
    CXParam* QB_Reset() { m_qb_table = ""; m_qb_where = ""; m_qb_keys.Clear(); m_qb_vals.Clear(); return GetPointer(this); }
    CXParam* Table(string table) { m_qb_table = table; return GetPointer(this); }
    CXParam* Where(string col, string val, bool is_str = true) {
        if(m_qb_where != "") m_qb_where += " AND ";
        m_qb_where += is_str ? StringFormat("%s = '%s'", col, val) : StringFormat("%s = %s", col, val);
        return GetPointer(this);
    }
    CXParam* SetVal(string col, string val, bool is_str = true) {
        m_qb_keys.Add(col);
        m_qb_vals.Add(is_str ? StringFormat("'%s'", val) : val);
        return GetPointer(this);
    }
    CXParam* SetTime(string col, datetime t) {
        m_qb_keys.Add(col);
        m_qb_vals.Add(StringFormat("datetime(%I64d, 'unixepoch')", (long)t));
        return GetPointer(this);
    }
    string BuildUpdate() {
        if(m_qb_table == "" || m_qb_keys.Total() == 0) return "";
        string sets = "";
        for(int i=0; i<m_qb_keys.Total(); i++) {
            if(i > 0) sets += ", ";
            sets += StringFormat("%s = %s", m_qb_keys.At(i), m_qb_vals.At(i));
        }
        string sql = StringFormat("UPDATE %s SET %s", m_qb_table, sets);
        if(m_qb_where != "") sql += " WHERE " + m_qb_where;
        return sql;
    }

    // --- [ Dynamic Properties ] ---
    void Set(string key, string val) {
        int idx = -1;
        for(int i=0; i<m_keys.Total(); i++) { if(m_keys.At(i) == key) { idx = i; break; } }
        if(idx >= 0) m_vals.Update(idx, val);
        else { m_keys.Add(key); m_vals.Add(val); }
    }
    string Get(string key, string def="") {
        for(int i=0; i<m_keys.Total(); i++) { if(m_keys.At(i) == key) return m_vals.At(i); }
        return def;
    }

    // --- [ Utilities ] ---
    double GetTp(int i=0) { int n = ArraySize(tps); return (n>0) ? tps[i < n ? i : n-1] : 0; }
    double GetSl(int i=0) { int n = ArraySize(sls); return (n>0) ? sls[i < n ? i : n-1] : 0; }
    double GetOffset(int i=0) { int n = ArraySize(offsets); return (n>0) ? offsets[i < n ? i : n-1] : 0; }
    
    void Validate() {
      MqlDateTime dt; TimeToStruct(time, dt);
      string dStr = StringFormat("%02d%02d%02d%02d", dt.year % 100, dt.mon, dt.day, dt.hour);
      if(gid == "") gid = StringFormat("%04I64u-%s-%02I64u-%02I64u", magic, dStr, sno % 100, gno % 100);
      if(sid == "") sid = gid + "-" + ((dir=="BUY"||dir=="B")?"B":"S") + "-" + ((type=="MARKET")?"1":"2");
    }
    
    void CalculatePrices(MqlTick &tick) {
       if(m_isPriceCalculated) return;
       bool isBuy = (dir == "BUY" || dir == "B");
       bool isMarket = (type == "MARKET");
       double curTpPts = GetTp((int)gno); double curSlPts = GetSl((int)gno); double curOffPts = GetOffset((int)gno);
       double point = SymbolInfoDouble(symbol, SYMBOL_POINT); if(point <= 0) point = _Point;
       if(isMarket) curOffPts = 0;
       double basePrice = (price > 0) ? price : (isBuy ? tick.ask : tick.bid);
       if(price <= 0 && curOffPts > 0) basePrice = isBuy ? tick.ask - (curOffPts * point) : tick.bid + (curOffPts * point);
       if(curTpPts > 0) tp_price = isBuy ? (basePrice + curTpPts * point) : (basePrice - curTpPts * point); else tp_price = 0;
       if(curSlPts > 0) sl_price = isBuy ? (basePrice - curSlPts * point) : (basePrice + curSlPts * point); else sl_price = 0;
       price = NormalizeDouble(basePrice, _Digits); tp_price = NormalizeDouble(tp_price, _Digits); sl_price = NormalizeDouble(sl_price, _Digits);
       m_isPriceCalculated = true;
    }
};

#endif
