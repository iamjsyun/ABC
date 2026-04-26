//+------------------------------------------------------------------+
//|                                     CXMarketOrderManager.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_MARKET_ORDER_MANAGER_MQH
#define CX_MARKET_ORDER_MANAGER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include <Trade\Trade.mqh>

// [Module] Market Order Manager - 시장가 진입 전담
class CXMarketOrderManager : public ICXReceiver
{
private:
    CTrade          m_trade;

public:
    CXMarketOrderManager() 
    {
        CXParam xp;
        xp.msg_id = MSG_MARKET_ORDER_REQ;
        xp.receiver = (ICXReceiver*)GetPointer(this);
        CXMessageHub::Default(&xp).Register(&xp);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_MARKET_ORDER_REQ) return;
        CXSignalEntry* se = xp.signal_entry;
        if(se == NULL) return;

        if(xp.order == NULL) xp.order = new CXOrder();
        CXOrder* ord = xp.order;
        ord.magic = se.magic; ord.symbol = se.symbol; ord.volume = se.lot; ord.comment = se.sid;

        ExecuteMarketOrder(xp);
    }

private:
    void ExecuteMarketOrder(CXParam* xp)
    {
        CXOrder* ord = xp.order;
        CXSignalEntry* se = xp.signal_entry;
        if(ord == NULL || se == NULL || xp.db == NULL) return;

        // [Transaction Step 1] 주문 시도 전 상태 기록
        xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
        xp.SetVal("ea_status", "1", false);
        xp.SetVal("tag", "Sending Market Order...", true);
        xp.SetTime("updated", xp.time);
        xp.db.Execute(xp);

        m_trade.SetExpertMagicNumber((int)ord.magic);
        bool success = false;
        if(se.dir == 1) success = m_trade.Buy(ord.volume, ord.symbol, 0, ord.sl, ord.tp, ord.comment);
        else success = m_trade.Sell(ord.volume, ord.symbol, 0, ord.sl, ord.tp, ord.comment);

        if(success)
        {
            // [v3.0] 상태 전이: EXECUTING(1) -> VERIFYING(7)
            xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
            xp.SetVal("ea_status", "7", false); // EA_VERIFYING
            xp.SetVal("tag", "[STEP-1->7] Market Order Sent. Verifying...", true);
            xp.SetTime("updated", TimeCurrent());
            xp.db.Execute(xp);

            // [Transaction Step 2] 성공 후 피드백
            xp.msg_id = MSG_ENTRY_CONFIRMED;
            xp.sid = ord.comment;
            xp.ticket = m_trade.ResultOrder();
            CXMessageHub::Default(xp).Send(xp);
        }
        else
        {
            // [Transaction Step 3] 실패 처리
            uint ret_code = m_trade.ResultRetcode();
            string ret_desc = m_trade.ResultRetcodeDescription();
            xp.QB_Reset().Table("entry_signals").Where("sid", ord.comment);
            xp.SetVal("ea_status", "9", false).SetVal("tag", "Market Fail: " + ret_desc, true);
            xp.db.Execute(xp);
        }
    }
};

#endif
