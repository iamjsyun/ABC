//+------------------------------------------------------------------+
//|                                     CXLimitOrderManager.mqh       |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_LIMIT_ORDER_MANAGER_MQH
#define CX_LIMIT_ORDER_MANAGER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
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
        CXMessageHub::Default(&xp).Register(&xp);
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
        if(!SymbolInfoTick(se.symbol, tick)) return;

        xp.CalculatePrices(tick);
        int symDigits = (int)SymbolInfoInteger(se.symbol, SYMBOL_DIGITS);
        ord.price_open = NormalizeDouble(xp.price, symDigits);
        ord.sl = (xp.sl_price > 0) ? NormalizeDouble(xp.sl_price, symDigits) : 0;
        ord.tp = (xp.tp_price > 0) ? NormalizeDouble(xp.tp_price, symDigits) : 0;

        // [Transaction Step 1] 주문 시도 전 상태 기록 (ea_status=1: Executing)
        xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
        xp.SetVal("ea_status", "1", false);
        xp.SetVal("tag", "Sending Order...", true);
        xp.SetTime("updated", xp.time);
        xp.Set("sql", xp.BuildUpdate());
        xp.db.Execute(xp);

        m_trade.SetExpertMagicNumber((int)ord.magic);
        bool success = false;
        if(se.dir == 1) success = m_trade.BuyLimit(ord.volume, ord.price_open, se.symbol, ord.sl, ord.tp, ORDER_TIME_GTC, 0, ord.comment);
        else success = m_trade.SellLimit(ord.volume, ord.price_open, se.symbol, ord.sl, ord.tp, ORDER_TIME_GTC, 0, ord.comment);

        if(success)
        {
            // [v3.0] 상태 전이: EXECUTING(1) -> PLACED(3)
            xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
            xp.SetVal("ea_status", "3", false); // EA_PLACED
            xp.SetVal("tag", "[STEP-1->3] Order Placed on Server", true);
            xp.SetTime("updated", TimeCurrent());
            xp.db.Execute(xp);

            // [v1.2 로그] 대기 오더 생성 성공 상세 기록
            Print(LogHeader("INFO", ord.comment, "ENTRY-OK"), StringFormat("Limit Order Placed. Ticket:%I64u, Price:%.5f, SL:%.5f, TP:%.5f", 
                  m_trade.ResultOrder(), ord.price_open, ord.sl, ord.tp));

            xp.msg_id = MSG_ENTRY_CONFIRMED;
            xp.sid = ord.comment;
            xp.ticket = m_trade.ResultOrder();
            CXMessageHub::Default(xp).Send(xp);
        }
        else
        {
            uint ret_code = m_trade.ResultRetcode();
            string ret_desc = m_trade.ResultRetcodeDescription();
            
            // [v1.2 로그] 에러 로그 표준화
            Print(LogHeader("ERROR", ord.comment, "ENTRY-ERR"), StringFormat("Code:%d, Desc:%s", ret_code, ret_desc));

            xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
            if(ret_code == 10018 || ret_code == 10031) {
                xp.SetVal("ea_status", "0", false).SetVal("tag", "Waiting Market: " + ret_desc, true);
            } else {
                xp.SetVal("ea_status", "9", false).SetVal("tag", "Fatal: " + ret_desc, true);
            }
            xp.SetTime("updated", xp.time);
            xp.Set("sql", xp.BuildUpdate());
            xp.db.Execute(xp);
        }
    }
};

#endif
