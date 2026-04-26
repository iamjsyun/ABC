//+------------------------------------------------------------------+
//|                                       CXStopOrderManager.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 16:30:00 |
//+------------------------------------------------------------------+
#ifndef CX_STOP_ORDER_MANAGER_MQH
#define CX_STOP_ORDER_MANAGER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include <Trade\Trade.mqh>

// [Module] Stop Order Manager - 스탑 오더 접수 및 처리
class CXStopOrderManager : public ICXReceiver
{
private:
    CTrade          m_trade;

public:
    CXStopOrderManager() 
    {
        // 스탑 오더 요청 구독
        CXParam xp;
        xp.msg_id = MSG_STOP_ORDER_REQ;
        xp.receiver = &this;
        CXMessageHub::Default(&xp).Register(&xp);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp.msg_id != MSG_STOP_ORDER_REQ) return;
        
        CXSignalEntry* se = xp.signal_entry;
        if(se == NULL) return;

        // Populate order from signal_entry
        if(xp.order == NULL) xp.order = new CXOrder();
        CXOrder* ord = xp.order;

        ord.magic      = se.magic;
        ord.symbol     = se.symbol;
        ord.price_open = se.price;
        ord.sl         = se.sl;
        ord.tp         = se.tp;
        ord.volume     = se.lot;
        ord.comment    = se.sid;
        ord.type       = (string)se.type;

        ExecuteStopOrder(xp);
    }

private:
    void ExecuteStopOrder(CXParam* xp)
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
                
                // Stop 오더는 Buy의 경우 시장가보다 위, Sell의 경우 시장가보다 아래
                if(se.dir == 1) se.price = tick.ask + (distance * point);
                else se.price = tick.bid - (distance * point);
                
                ord.price_open = se.price;
                LOG_SIGNAL("[ENTRY-STOP]", StringFormat("Auto-calculated Price (Dist: %.1f): %.5f", distance, se.price), ord.comment);
            }
        }

        LOG_SIGNAL("[ENTRY-STOP]", StringFormat("Requesting Stop Order: %.5f (Vol: %.2f)", ord.price_open, ord.volume), ord.comment);
        
        m_trade.SetExpertMagicNumber((int)ord.magic);
        
        bool success = false;
        
        if(se.dir == 1)
            success = m_trade.BuyStop(ord.volume, ord.price_open, ord.symbol, ord.sl, ord.tp, ORDER_TIME_GTC, 0, ord.comment);
        else
            success = m_trade.SellStop(ord.volume, ord.price_open, ord.symbol, ord.sl, ord.tp, ORDER_TIME_GTC, 0, ord.comment);

        if(success)
        {
            // [v3.0] 상태 전이: EXECUTING(1) -> PLACED(3)
            xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
            xp.SetVal("ea_status", "3", false); // EA_PLACED
            xp.SetVal("tag", "[STEP-1->3] Stop Order Placed on Server", true);
            xp.SetTime("updated", TimeCurrent());
            xp.db.Execute(xp);

            // 피드백 신호 전송
            xp.msg_id = MSG_ENTRY_CONFIRMED;
            xp.sid = ord.comment;
            xp.ticket = m_trade.ResultOrder();
            CXMessageHub::Default(xp).Send(xp);
            LOG_SIGNAL("[ENTRY-OK]", StringFormat("Stop Order Sent. Ticket: %I64d", xp.ticket), ord.comment);
        }
        else
        {
            LOG_SIGNAL("[ENTRY-ERR]", StringFormat("Stop Order Failed. Code: %d, Desc: %s", 
                                                 m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()), ord.comment);
        }
    }
};

#endif
