//+------------------------------------------------------------------+
//|                                        CXCloseManager.mqh        |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 11:35:00 |
//+------------------------------------------------------------------+
#ifndef CX_CLOSE_MANAGER_MQH
#define CX_CLOSE_MANAGER_MQH

#include "..\Library\CXMessageHub.mqh"
#include "..\Library\CXDefine.mqh"
#include "..\Library\CXPacket.mqh"
#include <Trade\Trade.mqh>

// [Module] Close Manager - 청산 로직 전담
class CXCloseManager : public ICXReceiver
{
private:
    CTrade          m_trade;

public:
    CXCloseManager()
    {
        // 청산 요청 구독
        CXMessageHub::Default().Register(MSG_CLOSE_REQ, &this);
    }

    virtual void OnReceiveMessage(int msg_id, CObject* message)
    {
        if(msg_id != MSG_CLOSE_REQ) return;
        
        CXPacket* packet = dynamic_cast<CXPacket*>(message);
        if(packet == NULL) return;

        if(LiquidationByGID(packet.gid))
        {
            // 처리 완료 알림 발신 (DB 제거 위함)
            CXMessageHub::Default().Send(MSG_EXIT_CONFIRMED, packet);
            Print("[Close-Mgr] Liquidation Confirmed. Feedback sent to Hub.");
        }
    }

private:
    bool LiquidationByGID(string gid)
    {
        Print("[Close-Mgr] Liquidating Group: ", gid);
        bool any_closed = false;
        
        for(int i=PositionsTotal()-1; i>=0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                string comment = PositionGetString(POSITION_COMMENT);
                if(StringFind(comment, gid) >= 0)
                {
                    if(m_trade.PositionClose(ticket)) any_closed = true;
                }
            }
        }
        return true; // 여기서는 요청 수행 완료의 의미로 true 반환
    }
};

#endif
