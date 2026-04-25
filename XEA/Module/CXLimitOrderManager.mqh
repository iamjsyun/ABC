//+------------------------------------------------------------------+
//|                                     CXLimitOrderManager.mqh       |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 10:40:00 |
//+------------------------------------------------------------------+
#ifndef CX_LIMIT_ORDER_MANAGER_MQH
#define CX_LIMIT_ORDER_MANAGER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"

// [Module] Limit Order Manager - 리미트 오더 접수 및 처리
class CXLimitOrderManager : public ICXReceiver
{
public:
    CXLimitOrderManager() 
    {
        // 리미트 오더 요청 구독
        CXParam xp;
        xp.msg_id = MSG_LIMIT_ORDER_REQ;
        xp.receiver = &this;
        CXMessageHub::Default(&xp).Register(&xp);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp.msg_id != MSG_LIMIT_ORDER_REQ) return;

        CXSignalEntry* se = xp.signal_entry;
        if(se == NULL) return;

        // 실행을 위해 CXOrder 객체 생성 및 데이터 할당
        xp.order = new CXOrder();
        CXOrder* ord = xp.order;

        ord.magic      = se.magic;
        ord.symbol     = se.symbol;
        ord.price_open = se.price;
        ord.sl         = se.sl;
        ord.tp         = se.tp;
        ord.volume     = se.lot;
        ord.comment    = se.sid;
        ord.type       = (string)se.type;

        ExecuteLimitOrder(xp);
    }

private:
    CTrade          m_trade;

    void ExecuteLimitOrder(CXParam* xp)
    {
        CXOrder* ord = xp.order;
        CXSignalEntry* se = xp.signal_entry;
        if(ord == NULL || se == NULL) return;

        // [Refined Strategy] Type과 Price를 함께 평가하여 가격 결정
        if(se.price <= 0) {
            MqlTick tick;
            if(SymbolInfoTick(se.symbol, tick)) {
                double point = SymbolInfoDouble(se.symbol, SYMBOL_POINT);
                // offset이 있으면 우선 사용, 없으면 te_start 사용
                double distance = (se.offset > 0) ? se.offset : se.te_start;
                
                if(se.dir == 1) se.price = tick.ask - (distance * point);
                else se.price = tick.bid + (distance * point);
                
                ord.price_open = se.price;
                LOG_SIGNAL("[ENTRY-LIMIT]", StringFormat("Auto-calculated Price (Dist: %.1f): %.5f", distance, se.price), ord.comment);
            }
        }

        LOG_SIGNAL("[ENTRY-LIMIT]", StringFormat("Requesting Limit Order: %.5f (Vol: %.2f)", ord.price_open, ord.volume), ord.comment);
        
        m_trade.SetExpertMagicNumber((int)ord.magic);
        
        bool success = false;
        
        if(se.dir == 1)
            success = m_trade.BuyLimit(ord.volume, ord.price_open, ord.symbol, ord.sl, ord.tp, ORDER_TIME_GTC, 0, ord.comment);
        else
            success = m_trade.SellLimit(ord.volume, ord.price_open, ord.symbol, ord.sl, ord.tp, ORDER_TIME_GTC, 0, ord.comment);

        if(success)
        {
            // 피드백 신호 전송
            xp.msg_id = MSG_ENTRY_CONFIRMED;
            xp.sid = ord.comment; // Watcher가 식별할 수 있도록 SID 설정
            xp.ticket = m_trade.ResultOrder();
            CXMessageHub::Default(xp).Send(xp);
            LOG_SIGNAL("[ENTRY-OK]", StringFormat("Limit Order Sent. Ticket: %I64d", xp.ticket), ord.comment);
        }
        else
        {
            LOG_SIGNAL("[ENTRY-ERR]", StringFormat("Limit Order Failed. Code: %d, Desc: %s", 
                                                 m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()), ord.comment);
        }
    }
};

#endif
