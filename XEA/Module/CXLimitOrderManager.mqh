//+------------------------------------------------------------------+
//|                                     CXLimitOrderManager.mqh       |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_LIMIT_ORDER_MANAGER_MQH
#define CX_LIMIT_ORDER_MANAGER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include "..\include\CXLoggerUI.mqh"
#include <Trade\Trade.mqh>

// [Module] Limit Order Manager - 트랜잭션 보장형 주문 실행기
class CXLimitOrderManager : public ICXReceiver
{
private:
    CTrade          m_trade;

    string LogHeader(string level, string sid, string tag) {
        return StringFormat("[%s] [%s] [%s] [%s] ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), level, sid, tag);
    }

public:
    CXLimitOrderManager() 
    {
        CXParam xp;
        xp.msg_id = MSG_LIMIT_ORDER_REQ;
        xp.receiver = GetPointer(this);
        CXMessageHub::Default().Register(&xp);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_LIMIT_ORDER_REQ) return;
        CXSignalEntry* se = xp.signal_entry;
        if(se == NULL) return;

        // [v1.2 로그] 스캔 히트 및 요청 상세 기록
        Print(LogHeader("INFO", se.sid, "SCAN-HIT"), StringFormat("Limit Order Request. Sym:%s, Dir:%d, Lot:%.2f", se.symbol, se.dir, se.lot));

        if(xp.order == NULL) xp.order = new CXOrder();
        CXOrder* ord = xp.order;
        ord.magic = se.magic; ord.symbol = se.symbol; ord.volume = se.lot; ord.comment = se.sid;

        ExecuteLimitOrder(xp);
    }

private:
    void ExecuteLimitOrder(CXParam* xp)
    {
        CXOrder* ord = xp.order;
        CXSignalEntry* se = xp.signal_entry;
        if(ord == NULL || se == NULL || xp.db == NULL) return;

        MqlTick tick;
        if(!SymbolInfoTick(se.symbol, tick)) {
            // [v3.7] 틱 데이터가 없으면(시장 미개장 등) 상태를 0으로 복구하여 재시도 유도
            xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
            xp.SetVal("ea_status", "0", false).SetVal("tag", "Waiting for first tick...", true);
            xp.db.Execute(xp);
            return;
        }

        double point = SymbolInfoDouble(se.symbol, SYMBOL_POINT);
        int symDigits = (int)SymbolInfoInteger(se.symbol, SYMBOL_DIGITS);
        
        // [v3.6] 현재가 기준 te_start 거리에 Limit 오더 가격 설정 (Stop 오더 미사용)
        double distance = (se.te_start > 0) ? se.te_start : 100.0; // 기본값 100pts
        if(se.dir == 1) // BUY Limit (현재가 아래)
            ord.price_open = tick.ask - (distance * point);
        else // SELL Limit (현재가 위)
            ord.price_open = tick.bid + (distance * point);

        ord.price_open = NormalizeDouble(ord.price_open, symDigits);
        ord.sl = (se.sl > 0) ? (se.dir == 1 ? ord.price_open - se.sl * point : ord.price_open + se.sl * point) : 0;
        ord.tp = (se.tp > 0) ? (se.dir == 1 ? ord.price_open + se.tp * point : ord.price_open - se.tp * point) : 0;
        
        ord.sl = NormalizeDouble(ord.sl, symDigits);
        ord.tp = NormalizeDouble(ord.tp, symDigits);

        // [Transaction Step 1] 상태 기록
        xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
        xp.SetVal("ea_status", "1", false).SetVal("tag", "Sending Limit Order (TE-Start)...", true);
        xp.db.Execute(xp);

        m_trade.SetExpertMagicNumber((int)ord.magic);
        bool success = false;
        
        if(se.dir == 1) 
            success = m_trade.BuyLimit(ord.volume, ord.price_open, se.symbol, ord.sl, ord.tp, ORDER_TIME_GTC, 0, ord.comment);
        else 
            success = m_trade.SellLimit(ord.volume, ord.price_open, se.symbol, ord.sl, ord.tp, ORDER_TIME_GTC, 0, ord.comment);

        if(success)
        {
            xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
            xp.SetVal("ea_status", "3", false).SetVal("tag", "[STEP-1->3] Limit Order Placed (TE Active)", true);
            xp.db.Execute(xp);

            Print(LogHeader("INFO", ord.comment, "ENTRY-OK"), StringFormat("Limit Order Placed at te_start: %.5f", ord.price_open));

            // [UI Log] p0 a 영역에 대기오더 및 TE 정보 출력 (Next, Bound 등은 Instance에서 업데이트되므로 초기값 출력)
            double cur_price = (se.dir == 1) ? tick.ask : tick.bid;
            double next_p = ord.price_open + (se.te_step * point * (se.dir == 1 ? 1 : -1));
            double bound_p = ord.price_open + (se.te_limit * point * (se.dir == 1 ? 1 : -1));
            string ui_msg = StringFormat("대기오더:%I64u, TE활성:true, Price:%.5f, Base:%.5f, Next:%.5f, Bound:%.5f",
                                         m_trade.ResultOrder(), cur_price, ord.price_open, next_p, bound_p);
            XLoggerUI.LogSID(ord.comment, 1, ui_msg);

            xp.msg_id = MSG_ENTRY_CONFIRMED;
            xp.sid = ord.comment;
            xp.ticket = m_trade.ResultOrder();
            CXMessageHub::Default().Send(xp);
        }
        else
        {
            uint ret_code = m_trade.ResultRetcode();
            string ret_desc = m_trade.ResultRetcodeDescription();
            
            // [v1.2 로그] 에러 로그 표준화
            Print(LogHeader("ERROR", ord.comment, "ENTRY-ERR"), StringFormat("Code:%d, Desc:%s", ret_code, ret_desc));

            xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
            // [v3.9] 시장 폐장(10018), 틱 부재, 제제(10017) 등 재시도가 필요한 에러 상황 처리
            if(ret_code == 10018 || ret_code == 10017 || ret_code == 10031 || ret_code == 4752) {
                xp.SetVal("ea_status", "0", false).SetVal("tag", "Market Closed/No Tick. Waiting Open...", true);
            } else {
                xp.SetVal("ea_status", "9", false).SetVal("tag", "Fatal: " + ret_desc, true);
            }
            xp.SetTime("updated", TimeCurrent());
            xp.db.Execute(xp);
        }
    }
};

#endif
