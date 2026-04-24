//+------------------------------------------------------------------+
//|                                     CXMarketOrderManager.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 11:30:00 |
//+------------------------------------------------------------------+
#ifndef CX_MARKET_ORDER_MANAGER_MQH
#define CX_MARKET_ORDER_MANAGER_MQH

#include "..\Library\CXMessageHub.mqh"
#include "..\Library\CXDefine.mqh"
#include "..\Library\CXPacket.mqh"
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
        CXMessageHub::Default().Register(MSG_MARKET_ORDER_REQ, &this);
    }

    virtual void OnReceiveMessage(int msg_id, CObject* message)
    {
        if(msg_id != MSG_MARKET_ORDER_REQ) return;
        
        CXPacket* packet = dynamic_cast<CXPacket*>(message);
        if(packet == NULL) return;

        ExecuteMarketOrder(packet);
    }

private:
    void ExecuteMarketOrder(CXPacket* packet)
    {
        Print("[Market-Mgr] Executing Market Order: ", packet.pid);
        
        bool success = false;
        if(packet.dir == "B" || packet.dir == "BUY")
            success = m_trade.Buy(packet.lots[0], packet.symbol, 0, packet.sls[0], packet.tps[0], packet.comment);
        else
            success = m_trade.Sell(packet.lots[0], packet.symbol, 0, packet.sls[0], packet.tps[0], packet.comment);

        if(success)
        {
            // 처리 완료 알림 발신 (DB 제거 위함)
            CXMessageHub::Default().Send(MSG_ENTRY_CONFIRMED, packet);
            Print("[Market-Mgr] Order Confirmed. Feedback sent to Hub.");
        }
        else
        {
            Print("[Market-Mgr] Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
        }
    }
};

#endif
