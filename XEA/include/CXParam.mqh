//+------------------------------------------------------------------+
//|                                              CXParam.mqh         |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_PARAM_MQH
#define CX_PARAM_MQH

#include <Object.mqh>
#include <Arrays/ArrayString.mqh>
#include <Arrays/ArrayObj.mqh>

// Domain Specific Object Headers
#include "CXSignalEntry.mqh"
#include "CXSignalExit.mqh"
#include "CXOrder.mqh"
#include "CXPosition.mqh"
#include "CXTradeTrace.mqh"
#include "CXLogEntry.mqh"

// Forward declarations
class ICXReceiver;
class CXDatabase;

//+------------------------------------------------------------------+
//| CManagedSet: Group management for GIDs (CSV format)              |
//+------------------------------------------------------------------+
class CManagedSet : public CObject {
public:
    CArrayString gids;
    string       tag;
    datetime     startTime;

    CManagedSet(string _tag="") : tag(_tag), startTime(TimeCurrent()) {}
    
    string ToCsv() {
        string gids_str = "";
        for(int i=0; i<gids.Total(); i++) {
            if(i > 0) gids_str += ";";
            gids_str += gids.At(i);
        }
        return StringFormat("%s,%I64d,%s", tag, (long)startTime, gids_str);
    }

    bool FromCsv(string csv) {
        string pts[];
        if(StringSplit(csv, ',', pts) < 2) return false;
        tag = pts[0];
        startTime = (datetime)StringToInteger(pts[1]);
        gids.Clear();
        if(ArraySize(pts) > 2) {
            string g_arr[];
            int count = StringSplit(pts[2], ';', g_arr);
            for(int i=0; i<count; i++) gids.Add(g_arr[i]);
        }
        return true;
    }
};

//--- CMD Constants (Merged from CXPacket)
#define CMD_NONE "NONE"
#define CMD_OPEN "OPEN"
#define CMD_OPEN_GRID "GRID"
#define CMD_CLOSE "CLOSE"
#define CMD_CLOSE_STAGED "CLOSE_STAGED"
#define CMD_CLOSE_FORCE "CLOSE_FORCE"
#define CMD_CLOSE_BY_MAGIC "CLOSE_BY_MAGIC"
#define CMD_CLOSE_BY_MAGIC_SNO "CLOSE_BY_MAGIC_SNO"
#define CMD_CLOSE_BY_TICKET "CLOSE_BY_TICKET"

#define ORDER_MARKET "MARKET"
#define ORDER_LIMIT "LIMIT"
#define ORDER_STOP "STOP"

#define POSITION_BUY "BUY"
#define POSITION_SELL "SELL"

// [v14.0] Unified Parameter & Data Packet with Domain Composition
class CXParam : public CObject
{
private:
   bool      m_isPriceCalculated;

   string GetJsonValue(string json, string key) {
      string searchKey = "\"" + key + "\"";
      int foundPos = StringFind(json, searchKey);
      if(foundPos < 0) return "";
      int colonPos = StringFind(json, ":", foundPos + StringLen(searchKey));
      if(colonPos < 0) return "";
      int start = colonPos + 1;
      while(start < StringLen(json) && (StringGetCharacter(json, start) <= 32)) start++;
      if(StringGetCharacter(json, start) == '\"') {
         int end = StringFind(json, "\"", start + 1);
         if(end > start) return StringSubstr(json, start + 1, end - start - 1);
      } else {
         int end = start;
         while(end < StringLen(json)) {
            ushort c = StringGetCharacter(json, end);
            if(c == ',' || c == '}' || c == ']' || c <= 32) break;
            end++;
         }
         string val = StringSubstr(json, start, end - start);
         return (val == "null") ? "" : val;
      }
      return "";
   }

   void GetJsonArray(string json, string key, double &outArr[]) {
      ArrayResize(outArr, 0);
      string searchKey = "\"" + key + "\"";
      int foundPos = StringFind(json, searchKey);
      if(foundPos < 0) return; 
      int startBracket = StringFind(json, "[", foundPos);
      int endBracket = StringFind(json, "]", startBracket);
      if(startBracket < 0 || endBracket < 0) return;
      string inner = StringSubstr(json, startBracket + 1, endBracket - startBracket - 1);
      string pts[]; int count = StringSplit(inner, ',', pts);
      for(int i=0; i<count; i++) {
         string v = pts[i]; StringTrimLeft(v); StringTrimRight(v);
         if(v != "" && v != "null") {
            int oldSize = ArraySize(outArr); ArrayResize(outArr, oldSize + 1);
            outArr[oldSize] = StringToDouble(v);
         }
      }
   }

public:
    // Core Identity Fields
    string sid;
    string symbol;
    ulong  magic;           // Magic Number (CNO/Expert Magic)
    int    direction;       // 1: Buy, 2: Sell
    double ref_price;       // Reference price
    double offset_pts;      
    
    // Strategy & Tracker Fields
    int    strategy_no;     
    string strategy_args;   
    double calculated_lot;  
    ulong  ticket;          
    int    tb_limit;        
    int    tb_start;        
    int    tb_step;         
    int    tb_interval;     // [New] Time interval for gap maintenance (sec)
    double target_price;    
    double sl_pts;          
    double tp_pts;          

    // Fields Merged from CXPacket
    ulong     sno, gno;
    double    swap, price, tp_price, sl_price;
    double    tps[], sls[], offsets[], lots[];
    datetime  time;
    string    cmd, dir, type;
    string    pid, gid, tag, kind, comment;
    string    sids_arr[];

    // Message Hub Fields
    int           msg_id;
    ICXReceiver*  receiver;
    CObject*      payload;

    // Database Object Pointer
    CXDatabase*  db;

    // [v14.0] Domain-Specific Object Pointers (Composition Strategy)
    CXSignalEntry*  signal_entry;
    CXSignalExit*   signal_exit;
    CXOrder*        order;
    CXPosition*     pos;
    CXTradeTrace*   trace;  // [New] SID별 트레이스 객체
    CXLogEntry*     log_entry; // [New] 로그 엔트리

    CXParam() {
        db = NULL;
        msg_id = 0;
        receiver = NULL;
        payload = NULL;
        
        signal_entry = NULL;
        signal_exit  = NULL;
        order        = NULL;
        pos          = NULL;
        trace        = NULL;
        log_entry    = NULL;
        
        Clear();
    }
    
    ~CXParam() {
        // [Safety] 소유권이 불분명한 객체들은 여기서 삭제하지 않음 (이중 해제 방지)
        // 단, 내부 할당된 메모리만 정리
        keys.Clear();
        values.Clear();
    }

    void Clear() {
      magic=0; ticket=0; sno=0; gno=0; swap=0; price=0; tp_price=0; sl_price=0;
      strategy_no=0; strategy_args=""; calculated_lot=0;
      ArrayResize(tps, 1); tps[0] = 0;
      ArrayResize(sls, 1); sls[0] = 0;
      ArrayResize(offsets, 1); offsets[0] = 0;
      ArrayResize(lots, 1); lots[0] = 0.01;
      ArrayResize(sids_arr, 0);
      cmd=CMD_NONE; dir=CMD_NONE; type=CMD_NONE; symbol=_Symbol;
      pid=""; sid=""; gid=""; tag=""; kind="SIM"; comment="";
      time=TimeCurrent(); m_isPriceCalculated = false;
      keys.Clear(); values.Clear();
      
      // 포인터만 초기화 (소유권은 관리자에게 있음)
      signal_entry = NULL;
      signal_exit  = NULL;
      order        = NULL;
      pos          = NULL;
      log_entry    = NULL;
      trace        = NULL;
    }

    bool FromJson(string json) {
      if(StringLen(json) < 10) return false;
      this.Clear();
      cmd = GetJsonValue(json, "cmd"); if(cmd == "") cmd = GetJsonValue(json, "command");
      if(cmd == "") return false; StringToUpper(cmd);
      dir = GetJsonValue(json, "dir"); StringToUpper(dir);
      type = GetJsonValue(json, "type"); StringToUpper(type);
      symbol = GetJsonValue(json, "symbol"); if(symbol == "") symbol = _Symbol;
      magic = (ulong)StringToInteger(GetJsonValue(json, "magic"));
      sno = (ulong)StringToInteger(GetJsonValue(json, "sno"));
      gno = (ulong)StringToInteger(GetJsonValue(json, "gno"));
      price = StringToDouble(GetJsonValue(json, "price"));
      GetJsonArray(json, "lots", lots);
      if(ArraySize(lots) == 0) {
          string lotVal = GetJsonValue(json, "lot");
          if(lotVal != "") { ArrayResize(lots, 1); lots[0] = StringToDouble(lotVal); }
          else { ArrayResize(lots, 1); lots[0] = 0.01; }
      }
      GetJsonArray(json, "tps", tps); GetJsonArray(json, "sls", sls); GetJsonArray(json, "offsets", offsets);
      string tStr = GetJsonValue(json, "time");
      if(StringFind(tStr, "-") > 0) {
         StringReplace(tStr, "T", " "); int dotPos = StringFind(tStr, ".");
         if(dotPos > 0) tStr = StringSubstr(tStr, 0, dotPos);
         time = StringToTime(tStr);
      } else time = (datetime)StringToInteger(tStr);
      if(time <= 0) time = TimeCurrent();
      pid = GetJsonValue(json, "pid"); if(pid == "") pid = GetJsonValue(json, "sid");
      sid = pid;
      gid = GetJsonValue(json, "gid");
      Validate();
      return true;
   }

   void Validate() {
      MqlDateTime dt_struct; TimeToStruct(time, dt_struct);
      string dStr = StringFormat("%02d%02d%02d%02d", dt_struct.year % 100, dt_struct.mon, dt_struct.day, dt_struct.hour);
      if(gid == "") gid = StringFormat("%04I64u-%s-%02I64u-%02I64u", magic, dStr, sno % 100, gno % 100);
      if(pid == "") {
         string d = (dir == POSITION_BUY || dir == "BUY" || dir == "B") ? "B" : "S";
         string t = (type == ORDER_MARKET || type == "M" || type == "MARKET") ? "1" : "2";
         pid = StringFormat("%s-%s-%s", gid, d, t);
      }
      sid = pid;
      if(comment == "") comment = pid;
   }

   bool ParseSID(string _sid) {
      if(_sid == "") return false;
      string pts[]; int count = StringSplit(_sid, '-', pts);
      if(count < 4) return false;
      this.magic = (ulong)StringToInteger(pts[0]);
      this.sno = (ulong)StringToInteger(pts[2]);
      this.gno = (ulong)StringToInteger(pts[3]);
      if(count >= 5) this.dir = pts[4];
      if(count >= 6) this.type = (pts[5] == "1") ? "MARKET" : "LIMIT";
      this.pid = _sid; this.sid = _sid;
      this.gid = StringFormat("%s-%s-%s-%s", pts[0], pts[1], pts[2], pts[3]);
      return true;
   }

   double GetTp(int i=0) { int n = ArraySize(tps); if(n <= 0) return 0; double v = tps[i < n ? i : n-1]; return (v < 0) ? 0 : v; }
   double GetSl(int i=0) { int n = ArraySize(sls); if(n <= 0) return 0; double v = sls[i < n ? i : n-1]; return (v < 0) ? 0 : v; }
   double GetOffset(int i=0) { int n = ArraySize(offsets); if(n <= 0) return 0; return offsets[i < n ? i : n-1]; }
   double GetStepLot(int i=0) { int n = ArraySize(lots); if(n <= 0) return 0.01; return lots[i < n ? i : n-1]; }

   void CalculatePrices(MqlTick &tick) {
       if(m_isPriceCalculated) return;
       bool isBuy = (dir == POSITION_BUY || dir == "BUY" || dir == "B");
       bool isMarket = (type == ORDER_MARKET || type == "MARKET" || type == "M");
       
       double curTpPts = GetTp((int)gno); 
       double curSlPts = GetSl((int)gno); 
       double curOffPts = GetOffset((int)gno);
       double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
       if(point <= 0) point = _Point;

       if(isMarket) curOffPts = 0;
       
       double basePrice = (price > 0) ? price : (isBuy ? tick.ask : tick.bid);
       
       // [Debug Log] 계산 시작 알림
       PrintFormat("[XEA-CALC] SID:%s, Dir:%s, Type:%s, MktAsk:%.5f, MktBid:%.5f", sid, dir, type, tick.ask, tick.bid);
       PrintFormat("[XEA-CALC] In: price:%.5f, offset:%.1f, tp:%.1f, sl:%.1f, pt:%.6f", price, curOffPts, curTpPts, curSlPts, point);

       if(price <= 0 && curOffPts > 0) {
          if(isBuy) basePrice = tick.ask - (curOffPts * point); 
          else basePrice = tick.bid + (curOffPts * point);
       }

       if(curTpPts > 0) tp_price = isBuy ? (basePrice + curTpPts * point) : (basePrice - curTpPts * point); else tp_price = 0;
       if(curSlPts > 0) sl_price = isBuy ? (basePrice - curSlPts * point) : (basePrice + curSlPts * point); else sl_price = 0;
       
       price = NormalizeDouble(basePrice, _Digits); 
       tp_price = NormalizeDouble(tp_price, _Digits); 
       sl_price = NormalizeDouble(sl_price, _Digits);
       
       PrintFormat("[XEA-CALC] Out: FinalPrice:%.5f, FinalTP:%.5f, FinalSL:%.5f", price, tp_price, sl_price);
       
       m_isPriceCalculated = true;
   }

   bool IsValid(string &outError) {
      if(magic <= 0) { outError = "No Magic"; return false; }
      if(cmd == "" || cmd == CMD_NONE) { outError = "No Cmd"; return false; }
      return true;
   }

   static string GetGroupPrefixFromComment(string comm) {
      string pts[]; int count = StringSplit(comm, '-', pts);
      if(count >= 3) return StringFormat("%s-%s-%s", pts[0], pts[1], pts[2]);
      return "";
   }
   
   void ResetPriceCalculation() { m_isPriceCalculated = false; }

    void Set(string key, string val) {
        int idx = FindKey(key);
        if(idx >= 0) values.Update(idx, val);
        else { keys.Add(key); values.Add(val); }
    }

    string Get(string key, string def_val = "") {
        int idx = FindKey(key);
        return (idx >= 0) ? values.At(idx) : def_val;
    }

    CArrayString keys;
    CArrayString values;

private:
    int FindKey(string key) {
        for(int i=0; i<keys.Total(); i++) { if(keys.At(i) == key) return i; }
        return -1;
    }
};

#endif
