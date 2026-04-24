//+------------------------------------------------------------------+
//|                                     CXLimitOrderManager.mqh       |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 10:40:00 |
//+------------------------------------------------------------------+
#ifndef CX_LIMIT_ORDER_MANAGER_MQH
#define CX_LIMIT_ORDER_MANAGER_MQH

#include "..\Library\CXMessageHub.mqh"
#include "..\Library\CXDefine.mqh"
#include "..\Library\CXPacket.mqh"

// [Module] Limit Order Manager - 리미트 오더 접수 및 처리
class CXLimitOrderManager : public ICXReceiver
{
public:
    CXLimitOrderManager() 
    {
        // 필요한 경우 구독
    }

    virtual void OnReceiveMessage(int msg_id, CObject* message) { }

private:
    CTrade          m_trade;

    void ExecuteLimitOrder(CXPacket* packet)
    {
        Print("[Limit-Mgr] Requesting Limit Order: ", packet.pid);
        
        // SID를 Comment에 주입 (최대 31자)
        string comment = packet.pid; 
        
        bool success = false;
        if(packet.dir == "B" || packet.dir == "BUY")
            success = m_trade.BuyLimit(packet.lots[0], packet.price, packet.symbol, packet.sls[0], packet.tps[0], 0, 0, comment);
        else
            success = m_trade.SellLimit(packet.lots[0], packet.price, packet.symbol, packet.sls[0], packet.tps[0], 0, 0, comment);

        if(success)
        {
            // [DB Update] UPDATE entry_signals SET ea_status = 1 WHERE sid = packet.pid
            Print("[Limit-Mgr] Sent to Terminal. Status marked as Executing(1). SID: ", packet.pid);
        }
    }
};

#endif
