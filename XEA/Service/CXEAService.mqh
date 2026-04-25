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
        p.msg_id = MSG_ENTRY_SIGNAL; CXMessageHub::Default(&p).Register(&p);
        p.msg_id = MSG_EXIT_SIGNAL;  CXMessageHub::Default(&p).Register(&p);
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

        CXSignalEntry* se = xp.signal_entry;
        if(se.type == 1)      xp.msg_id = MSG_MARKET_ORDER_REQ;
        else if(se.type == 3 || se.type == 5) xp.msg_id = MSG_STOP_ORDER_REQ;
        else xp.msg_id = MSG_LIMIT_ORDER_REQ; 
        
        CXMessageHub::Default(xp).Send(xp);
    }

    void HandleExitSignal(CXParam* xp)
    {
        if(xp == NULL || xp.signal_exit == NULL) return;
        xp.trace = trace_service.GetTrace(xp.sid);
        xp.msg_id = MSG_CLOSE_REQ;
        CXMessageHub::Default(xp).Send(xp);
    }
};

#endif
