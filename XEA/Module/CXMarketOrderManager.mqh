//+------------------------------------------------------------------+
//|                                     CXMarketOrderManager.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 11:30:00 |
//+------------------------------------------------------------------+
#ifndef CX_MARKET_ORDER_MANAGER_MQH
#define CX_MARKET_ORDER_MANAGER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include <Trade\Trade.mqh>

// [Module] Market Order Manager - 시장가 주문 실행 전담
class CXMarketOrderManager : public ICXReceiver
{
private:
    CTrade          m_trade;

public:
    CXMarketOrderManager()
    {
        // 시장가 주문 요청 이벤트 구독
        CXParam xp;
        xp.msg_id = MSG_MARKET_ORDER_REQ;
        xp.receiver = &this;
        CXMessageHub::Default(&xp).Register(&xp);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp.msg_id != MSG_MARKET_ORDER_REQ) return;
        
        CXSignalEntry* se = xp.signal_entry;
        if(se == NULL) return;

        // Populate order from signal_entry
        if(xp.order == NULL) xp.order = new CXOrder();
        CXOrder* ord = xp.order;

        ord.magic      = se.magic;
        ord.symbol     = se.symbol;
        ord.sl         = se.sl;
        ord.tp         = se.tp;
        ord.volume     = se.lot;
        ord.comment    = se.sid;
        ord.type       = (string)se.type;

        ExecuteMarketOrder(xp);
    }

private:
    void ExecuteMarketOrder(CXParam* xp)
    {
        CXOrder* ord = xp.order;
        CXSignalEntry* se = xp.signal_entry;
        if(ord == NULL || se == NULL) return;

        LOG_SIGNAL("[ENTRY-MARKET]", StringFormat("Executing Market Order: %s (Vol: %.2f)", ord.comment, ord.volume), ord.comment);
        
        // [Trace] L3_ORDER 기록
        if(xp.trace != NULL) {
            xp.trace.LogLevel(L3_ORDER, "Executing Market Order Request");
            xp.trace.LogDetail(L3_ORDER, "REQ", StringFormat("Dir:%s, Vol:%.2f, SL:%.1f, TP:%.1f", 
                               (se.dir == 1 ? "BUY" : "SELL"), ord.volume, ord.sl, ord.tp));
        }

        m_trade.SetExpertMagicNumber((int)ord.magic);
        
        bool success = false;
        
        if(se.dir == 1)
            success = m_trade.Buy(ord.volume, ord.symbol, 0, ord.sl, ord.tp, ord.comment);
        else
            success = m_trade.Sell(ord.volume, ord.symbol, 0, ord.sl, ord.tp, ord.comment);

        if(success)
        {
            // 처리 완료 알림 발신
            xp.msg_id = MSG_ENTRY_CONFIRMED;
            xp.sid = ord.comment;
            xp.ticket = m_trade.ResultOrder();
            CXMessageHub::Default(xp).Send(xp);
            LOG_SIGNAL("[ENTRY-OK]", StringFormat("Market Order Success. Ticket: %I64d", xp.ticket), ord.comment);

            if(xp.trace != NULL) {
                xp.trace.LogDetail(L3_ORDER, "RES", StringFormat("Order Success. Ticket: #%I64u", xp.ticket));
            }
        }
        else
        {
            LOG_SIGNAL("[ENTRY-ERR]", StringFormat("Market Order Failed. Code: %d, Desc: %s", 
                                                 m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()), ord.comment);
            if(xp.trace != NULL) {
                xp.trace.LogDetail(L3_ORDER, "FAIL", StringFormat("Code: %d, Desc: %s", 
                                   m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()));
            }
        }
    }
};

#endif
