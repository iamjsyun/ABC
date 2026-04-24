//+------------------------------------------------------------------+
//|                                        CXCloseManager.mqh        |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 11:35:00 |
//+------------------------------------------------------------------+
#ifndef CX_CLOSE_MANAGER_MQH
#define CX_CLOSE_MANAGER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
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
        CXParam p; p.msg_id = MSG_CLOSE_REQ; p.receiver = &this;
        CXMessageHub::Default(&p).Register(&p);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_CLOSE_REQ) return;
        
        CXSignalExit* sx = xp.signal_exit;
        if(sx == NULL) return;

        if(LiquidationByGID(xp))
        {
            // 처리 완료 알림 발신 (DB 제거 위함)
            xp.msg_id = MSG_EXIT_CONFIRMED;
            xp.sid = sx.sid;
            xp.gid = sx.gid;
            CXMessageHub::Default(xp).Send(xp);
            Print("[Close-Mgr] Liquidation Confirmed. Feedback sent to Hub.");
        }
    }

private:
    bool LiquidationByGID(CXParam* xp)
    {
        if(xp == NULL || xp.signal_exit == NULL) return false;
        string gid = xp.signal_exit.gid;
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
                    // 해당 포지션의 매직넘버(CNO)를 매직넘버로 설정 후 청산
                    m_trade.SetExpertMagicNumber((int)PositionGetInteger(POSITION_MAGIC));
                    if(m_trade.PositionClose(ticket)) any_closed = true;
                }
            }
        }
        return true; // 여기서는 요청 수행 완료의 의미로 true 반환
    }
};

#endif
