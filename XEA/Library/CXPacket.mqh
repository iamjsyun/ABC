//+------------------------------------------------------------------+
//|                                                      CXPacket.mqh |
//|                                  Copyright 2026, Gemini Adaptive |
//+------------------------------------------------------------------+
#ifndef __CXPacket_MQH__
#define __CXPacket_MQH__

#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayString.mqh>

//+------------------------------------------------------------------+
//| CManagedSet: ?온??筌뤴뫀諭??類ｋ궖???????????(CSV 疫꿸퀡而?
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

//--- 筌뤿굝議???怨몃땾
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

class CXPacket : public CObject {
private:
   bool      m_isPriceCalculated;

   string GetJsonValue(string json, string key) {
      string searchKey = "\"" + key + "\"";
      int pos = StringFind(json, searchKey);
      if(pos < 0) return "";
      int colonPos = StringFind(json, ":", pos + StringLen(searchKey));
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
      int pos = StringFind(json, searchKey);
      if(pos < 0) return; 
      int startBracket = StringFind(json, "[", pos);
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
   ulong     cno;      // Channel Number (추가)
   ulong     magic, ticket, sno, gno;
   double    swap, price, tp_price, sl_price;
   double    tps[], sls[], offsets[], lots[];
   datetime  time;
   string    cmd, dir, type, symbol;
   string    pid, gid, tag, kind, comment;
   string    sids[];

   CXPacket() { Clear(); }
   void Clear() {
      magic=0; ticket=0; sno=0; gno=0; swap=0; price=0; tp_price=0; sl_price=0;
      ArrayResize(tps, 1); tps[0] = 0;
      ArrayResize(sls, 1); sls[0] = 0;
      ArrayResize(offsets, 1); offsets[0] = 0;
      ArrayResize(lots, 1); lots[0] = 0.01;
      ArrayResize(sids, 0);
      cmd=CMD_NONE; dir=CMD_NONE; type=CMD_NONE; symbol=_Symbol;
      pid=""; gid=""; tag=""; kind="SIM"; comment="";
      time=TimeCurrent(); m_isPriceCalculated = false;
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
      
      // Step 1: Check for "lots" array
      GetJsonArray(json, "lots", lots);
      // Step 2: If "lots" array is empty, check for single "lot" value
      if(ArraySize(lots) == 0) {
          string lotVal = GetJsonValue(json, "lot");
          if(lotVal != "") {
              ArrayResize(lots, 1);
              lots[0] = StringToDouble(lotVal);
          } else {
              ArrayResize(lots, 1);
              lots[0] = 0.01;
          }
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
      gid = GetJsonValue(json, "gid");
      Validate();
      return true;
   }

   void Validate() {
      MqlDateTime dt_struct; TimeToStruct(time, dt_struct);
      // v2.9 표준: CNO(4)-yyMMddHH(8)-SNO(2)-GNO(2)
      string dStr = StringFormat("%02d%02d%02d%02d", dt_struct.year % 100, dt_struct.mon, dt_struct.day, dt_struct.hour);
      
      if(gid == "") {
         gid = StringFormat("%04I64u-%s-%02I64u-%02I64u", cno > 0 ? cno : magic, dStr, sno % 100, gno % 100);
      }
      
      if(pid == "") {
         string d = (dir == POSITION_BUY || dir == "BUY" || dir == "B") ? "B" : "S";
         string t = (type == ORDER_MARKET || type == "M" || type == "MARKET") ? "1" : "2";
         pid = StringFormat("%s-%s-%s", gid, d, t);
      }
      if(comment == "") comment = pid;
   }

   // SID 파싱하여 필드 복원
   bool ParseSID(string sid) {
      if(sid == "") return false;
      string pts[];
      int count = StringSplit(sid, '-', pts);
      if(count < 4) return false;
      
      this.cno = (ulong)StringToInteger(pts[0]);
      // pts[1]은 날짜시간 문자열 (yyMMddHH)
      this.sno = (ulong)StringToInteger(pts[2]);
      this.gno = (ulong)StringToInteger(pts[3]);
      
      if(count >= 5) this.dir = pts[4];
      if(count >= 6) this.type = (pts[5] == "1") ? "MARKET" : "LIMIT";
      
      this.pid = sid;
      // GID 재구성
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
       
       // ??뽰삢揶쎛(MARKET)??野껋럩???袁⑹삺揶쎛 筌앸맩??筌욊쑴????嚥?筌욊쑴????쎈늄???뱽 ?얜똻???(筌왖?類? LIMIT?????춸 ?怨몄뒠)
       if(isMarket) curOffPts = 0;
       
       double basePrice = (price > 0) ? price : (isBuy ? tick.ask : tick.bid);
       
       // ??쎈늄???뵠 ??쇱젟??뤿선 ??뉙? ??뺤쒔 筌왖?類?(price)揶쎛 ??용뮉 野껋럩???袁⑹삺揶쎛 疫꿸퀣? ??쎈늄???怨몄뒠??뤿연 筌욊쑴??첎? ?④쑴沅?
       if(price <= 0 && curOffPts > 0) {
          if(isBuy) basePrice = tick.ask - (curOffPts * _Point); 
          else basePrice = tick.bid + (curOffPts * _Point);
       }
       
       // TP/SL ?④쑴沅?
       if(curTpPts > 0) tp_price = isBuy ? (basePrice + curTpPts * _Point) : (basePrice - curTpPts * _Point); else tp_price = 0;
       if(curSlPts > 0) sl_price = isBuy ? (basePrice - curSlPts * _Point) : (basePrice + curSlPts * _Point); else sl_price = 0;
       
       price = NormalizeDouble(basePrice, _Digits); 
       tp_price = NormalizeDouble(tp_price, _Digits); 
       sl_price = NormalizeDouble(sl_price, _Digits);
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
};

#endif


