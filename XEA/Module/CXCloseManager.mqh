//+------------------------------------------------------------------+
//|                                        CXCloseManager.mqh        |
//|                                  Copyright 2026, Gemini CLI      |
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
        CXParam xp;
        xp.msg_id = MSG_CLOSE_REQ;
        xp.receiver = GetPointer(this);
        CXMessageHub::Default().Register(&xp);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_CLOSE_REQ) return;
        
        CXSignalExit* sx = xp.signal_exit;
        if(sx == NULL) return;

        // [Trace] L6_EXIT 기록 시작
        if(xp.trace != NULL) {
            xp.trace.LogLevel(L6_EXIT, "Liquidation Process Started", "GID: " + sx.gid);
            xp.trace.LogDetail(L6_EXIT, "SCAN", "Checking active positions for GID...");
        }

        if(LiquidationByGID(xp))
        {
            // 처리 완료 알림 발신 (DB 제거 위함)
            xp.msg_id = MSG_EXIT_CONFIRMED;
            xp.sid = sx.sid;
            xp.gid = sx.gid;
            CXMessageHub::Default().Send(xp);
            LOG_SIGNAL("[EXIT-OK]", StringFormat("Liquidation Request processed for GID: %s", sx.gid), sx.sid);

            if(xp.trace != NULL) {
                xp.trace.LogSummary("Liquidation Successful. GID: " + sx.gid);
            }
        }
    }

private:
    bool LiquidationByGID(CXParam* xp)
    {
        if(xp == NULL || xp.signal_exit == NULL) return false;
        string gid = xp.signal_exit.gid;
        string sid = xp.signal_exit.sid;
        LOG_SIGNAL("[EXIT-CLOSE]", StringFormat("Starting Liquidation for GID: %s", gid), sid);
        bool any_closed = false;
        
        for(int i=PositionsTotal()-1; i>=0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                string comment = PositionGetString(POSITION_COMMENT);
                if(StringFind(comment, gid) >= 0)
                {
                    double closePrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                    double profit = PositionGetDouble(POSITION_PROFIT);

                    // [v3.0] 청산 시도 상태 기록 (EA_CLOSING)
                    string pos_sid = PositionGetString(POSITION_COMMENT);
                    xp.QB_Reset().Table("entry_signals").Where("sid", pos_sid);
                    xp.SetVal("ea_status", "6", false); // EA_CLOSING
                    xp.SetVal("tag", "[STEP-2->6] Initiating Liquidation", true);
                    xp.SetTime("updated", TimeCurrent());
                    xp.db.Execute(xp);

                    // 해당 포지션의 매직넘버(CNO)를 매직넘버로 설정 후 청산
                    m_trade.SetExpertMagicNumber((int)PositionGetInteger(POSITION_MAGIC));
                    if(m_trade.PositionClose(ticket)) {
                        any_closed = true;
                        LOG_SIGNAL("[EXIT-CLOSE]", StringFormat("Closed Ticket: %I64d", ticket), sid);
                        
                        if(xp.trace != NULL) {
                            xp.trace.LogDetail(L6_EXIT, "WINNER", StringFormat("Manual/Signal Close Ticket #%I64u", ticket));
                            xp.trace.LogDetail(L6_EXIT, "DATA", StringFormat("Price:%.5f, Profit:%.2f", closePrice, profit));
                        }
                    }
                }
            }
        }
        return true; 
    }
};

#endif
