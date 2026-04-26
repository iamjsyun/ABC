//+------------------------------------------------------------------+
//|                                              CXEAService.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_EA_SERVICE_MQH
#define CX_EA_SERVICE_MQH

#include "..\include\ICXReceiver.mqh"
#include "..\include\ICXProcessor.mqh"
#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include <Arrays\ArrayObj.mqh>

#include "CXDBService.mqh"
#include "CXLogService.mqh"
#include "CXTraceService.mqh"
#include "CXEntryWatchService.mqh"
#include "CXExitWatchService.mqh"
#include "CXTrailingEntryService.mqh"
#include "CXTrailingExitService.mqh"

#include "..\Module\CXLimitOrderManager.mqh"
#include "..\Module\CXStopOrderManager.mqh"
#include "..\Module\CXMarketOrderManager.mqh"
#include "..\Module\CXCloseManager.mqh"
#include "..\Module\CXPositionManager.mqh"

// [Service] XEA Facade - Orchestrator
class CXEAService : public ICXReceiver
{
public:
    CXDBService*            db_service;
    CXLogService*           log_service;
    CXTraceService*         trace_service;
    CXEntryWatchService*    entry_watch_service;
    CXExitWatchService*     exit_watch_service;
    CXTrailingEntryService* trailing_entry_service;
    CXTrailingExitService*  trailing_exit_service;
    
    CXLimitOrderManager*    limit_manager;
    CXStopOrderManager*     stop_manager;
    CXMarketOrderManager*   market_manager;
    CXCloseManager*         close_manager;
    CXPositionManager*      position_manager; 

private:
    CArrayObj               m_services; 

public:
    CXEAService() 
    {
        db_service       = new CXDBService(); m_services.Add(db_service);
        log_service      = new CXLogService(); m_services.Add(log_service);
        trace_service    = new CXTraceService(); m_services.Add(trace_service);
        
        entry_watch_service = new CXEntryWatchService();
        entry_watch_service.SetDatabase(db_service.GetDB());
        m_services.Add(entry_watch_service);
        
        exit_watch_service = new CXExitWatchService();
        exit_watch_service.SetDatabase(db_service.GetDB());
        m_services.Add(exit_watch_service);

        trailing_entry_service = new CXTrailingEntryService(); m_services.Add(trailing_entry_service);
        trailing_exit_service  = new CXTrailingExitService(); m_services.Add(trailing_exit_service);
        
        limit_manager    = new CXLimitOrderManager();
        stop_manager     = new CXStopOrderManager();
        market_manager   = new CXMarketOrderManager();
        close_manager    = new CXCloseManager();
        position_manager = new CXPositionManager(); 

        CXParam p; p.receiver = (ICXReceiver*)GetPointer(this);
        p.msg_id = MSG_ENTRY_SIGNAL; CXMessageHub::Default().Register(&p);
        p.msg_id = MSG_EXIT_SIGNAL;  CXMessageHub::Default().Register(&p);
    }

    ~CXEAService()
    {
        m_services.Clear(); 
        if(CheckPointer(limit_manager) == POINTER_DYNAMIC) delete limit_manager;
        if(CheckPointer(stop_manager) == POINTER_DYNAMIC) delete stop_manager;
        if(CheckPointer(market_manager) == POINTER_DYNAMIC) delete market_manager;
        if(CheckPointer(close_manager) == POINTER_DYNAMIC) delete close_manager;
        if(CheckPointer(position_manager) == POINTER_DYNAMIC) delete position_manager;
    }

    void OnTimer(CXParam* xp)
    {
        if(xp == NULL || CheckPointer(db_service) == POINTER_INVALID) return;
        xp.db = db_service.GetDB();

        for(int i=0; i<m_services.Total(); i++) {
            ICXService* svc = (ICXService*)m_services.At(i);
            if(CheckPointer(svc) != POINTER_INVALID) svc.OnTimer(xp);
        }
        
        if(CheckPointer(position_manager) != POINTER_INVALID) position_manager.OnUpdate(xp);
    }

    void OnTradeTransaction(CXParam* xp, const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
    {
        if(xp == NULL || CheckPointer(db_service) == POINTER_INVALID) return;
        xp.db = db_service.GetDB();

        // 1. 체결(Deal) 발생 시 상태 전이 및 검증 프로세스 시작
        if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
        {
            HandleDealAdd(xp, trans);
        }
        // 2. 대기 오더 서버 등록 완료 시 즉시 제거 (추가)
        else if(trans.type == TRADE_TRANSACTION_ORDER_ADD)
        {
            HandleOrderAdd(xp, trans);
        }
    }

private:
    void HandleDealAdd(CXParam* xp, const MqlTradeTransaction& trans)
    {
        ulong deal_ticket = trans.deal;
        if(HistoryDealSelect(deal_ticket))
        {
            long entry_type = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
            string sid = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
            
            if(sid != "")
            {
                if(entry_type == DEAL_ENTRY_IN) // [진입]
                {
                    xp.ticket = trans.position;
                    position_manager.VerifyPosition(xp);
                }
                else if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_OUT_BY) // [청산]
                {
                    xp.QB_Reset().Table("entry_signals").Where("sid", sid);
                    xp.SetVal("ea_status", "8", false); // EA_LIQUIDATING
                    xp.SetVal("tag", "[STEP-6->8] Deal OUT Detected. Finalizing...", true);
                    xp.SetTime("updated", TimeCurrent());
                    xp.db.Execute(xp);
                }
            }
        }
    }

    void HandleOrderAdd(CXParam* xp, const MqlTradeTransaction& trans)
    {
        ulong ticket = trans.order;
        if(OrderSelect(ticket))
        {
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(type != ORDER_TYPE_BUY && type != ORDER_TYPE_SELL) 
            {
                string sid = OrderGetString(ORDER_COMMENT);
                if(sid != "")
                {
                    // [v3.5] 트레일링 진입 여부 확인
                    bool needs_trailing = false;
                    xp.QB_Reset().Table("entry_signals").Where("sid", sid);
                    int _req = xp.db.Prepare(xp);
                    if(_req != INVALID_HANDLE) {
                        if(::DatabaseRead(_req)) {
                            double te_start; ::DatabaseColumnDouble(_req, 8, te_start);
                            if(te_start > 0) needs_trailing = true;
                        }
                        ::DatabaseFinalize(_req);
                    }

                    if(needs_trailing) {
                        Print(StringFormat("[%s] [INFO] [%s] [SIGNAL-KEEP] Trailing required. Deferring deletion until position open.", 
                              TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), sid));
                        
                        xp.QB_Reset().Table("entry_signals").Where("sid", sid);
                        xp.SetVal("ea_status", "3", false).SetVal("tag", "Trailing Entry Active", true);
                        xp.db.Execute(xp);
                    }
                    else {
                        Print(StringFormat("[%s] [INFO] [%s] [SIGNAL-REMOVED] [STEP-1->REMOVE] No trailing. Cleaning up signal.", 
                              TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), sid));

                        string delete_sql = StringFormat("DELETE FROM entry_signals WHERE sid = '%s'", sid);
                        xp.Set("sql", delete_sql);
                        xp.db.Execute(xp);
                    }
                }
            }
        }
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL) return;
        if(xp.msg_id == MSG_ENTRY_SIGNAL) HandleEntrySignal(xp);
        else if(xp.msg_id == MSG_EXIT_SIGNAL) HandleExitSignal(xp);
    }

private:
    void HandleEntrySignal(CXParam* xp)
    {
        if(xp == NULL || xp.signal_entry == NULL) return;
        xp.trace = trace_service.GetTrace(xp.sid);
        if(xp.trace != NULL) xp.trace.LogLevel(L1_SIGNAL, "Signal Detected");

        // [v3.4] 모든 진입 신호를 Limit Order Manager로 통합 라우팅
        xp.msg_id = MSG_LIMIT_ORDER_REQ; 
        
        CXMessageHub::Default().Send(xp);
    }

    void HandleExitSignal(CXParam* xp)
    {
        if(xp == NULL || xp.signal_exit == NULL) return;
        xp.trace = trace_service.GetTrace(xp.sid);
        xp.msg_id = MSG_CLOSE_REQ;
        CXMessageHub::Default().Send(xp);
    }
};

#endif
