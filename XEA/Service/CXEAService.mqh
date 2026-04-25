//+------------------------------------------------------------------+
//|                                              CXEAService.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_EA_SERVICE_MQH
#define CX_EA_SERVICE_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include "..\include\ICXReceiver.mqh"
#include <Trade\Trade.mqh>

#include "CXDBService.mqh"
#include "CXLogService.mqh"
#include "CXTraceManager.mqh"
#include "..\Module\CXLimitOrderManager.mqh"
#include "..\Module\CXStopOrderManager.mqh"
#include "..\Module\CXMarketOrderManager.mqh"
#include "..\Module\CXCloseManager.mqh"
#include "..\Module\CXTrailingEntryManager.mqh"
#include "..\Module\CXPositionManager.mqh"

// [Service] XEA Facade - 모든 하위 서비스 및 모듈의 Life-cycle을 관리
class CXEAService : public ICXReceiver
{
private:
    CXDBService*            m_db_service;
    CXLogService*           m_log_service;
    CXTraceManager*         m_trace_manager;
    CXLimitOrderManager*    m_limit_manager;
    CXStopOrderManager*     m_stop_manager;
    CXMarketOrderManager*   m_market_manager;
    CXCloseManager*         m_close_manager;
    CXTrailingEntryManager* m_trailing_manager; 
    CXPositionManager*      m_position_manager; 

public:
    CXEAService() 
    {
        m_log_service      = new CXLogService();
        m_db_service       = new CXDBService();
        m_trace_manager    = new CXTraceManager();
        m_limit_manager    = new CXLimitOrderManager();
        m_stop_manager     = new CXStopOrderManager();
        m_market_manager   = new CXMarketOrderManager();
        m_close_manager    = new CXCloseManager();
        m_trailing_manager = new CXTrailingEntryManager();
        m_position_manager = new CXPositionManager(); 

        // 이벤트 구독
        CXParam p; p.receiver = &this;
        p.msg_id = MSG_ENTRY_SIGNAL; CXMessageHub::Default(&p).Register(&p);
        p.msg_id = MSG_EXIT_SIGNAL;  CXMessageHub::Default(&p).Register(&p);
    }

    ~CXEAService()
    {
        delete m_log_service;
        delete m_db_service;
        delete m_trace_manager;
        delete m_limit_manager;
        delete m_stop_manager;
        delete m_market_manager;
        delete m_close_manager;
        delete m_trailing_manager;
        delete m_position_manager;
    }

    CXDBService* GetDBService(CXParam* xp) { return m_db_service; }

    void OnTimer(CXParam* xp)
    {
        if(xp == NULL) return;
        xp.db = m_db_service.GetDB(xp);

        if(CheckPointer(m_trailing_manager) == POINTER_DYNAMIC)
            m_trailing_manager.OnUpdate(xp);

        if(CheckPointer(m_position_manager) == POINTER_DYNAMIC)
            m_position_manager.OnUpdate(xp);

        if(CheckPointer(m_db_service) == POINTER_DYNAMIC)
            m_db_service.OnTimer(xp);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL) return;

        switch(xp.msg_id)
        {
            case MSG_ENTRY_SIGNAL:
                HandleEntrySignal(xp);
                break;
            case MSG_EXIT_SIGNAL:
                HandleExitSignal(xp);
                break;
        }
    }

private:
    void HandleEntrySignal(CXParam* xp)
    {
        if(xp == NULL || xp.signal_entry == NULL) return;

        // [Trace] SID별 트레이스 시작 (L1)
        xp.trace = m_trace_manager.GetTrace(xp.sid);
        if(xp.trace != NULL) {
            xp.trace.LogLevel(L1_SIGNAL, "Signal Received from Watcher");
            xp.trace.LogDetail(L1_SIGNAL, "SID", xp.sid);
            xp.trace.LogDetail(L1_SIGNAL, "Type", (string)xp.signal_entry.type);
        }

        CXSignalEntry* se = xp.signal_entry;
        
        // 주문 타입에 따른 메시지 분기 (xp 자체를 재사용하여 데이터 전달)
        if(se.type == 1)      xp.msg_id = MSG_MARKET_ORDER_REQ;
        else if(se.type == 3 || se.type == 5) xp.msg_id = MSG_STOP_ORDER_REQ;
        else xp.msg_id = MSG_LIMIT_ORDER_REQ; // 2, 4 (Limit, Limit_P)
        
        PrintFormat("[XEA-SVC] Dispatching Entry Request: %s (Type:%d)", xp.sid, se.type);
        CXMessageHub::Default(xp).Send(xp);
    }

    void HandleExitSignal(CXParam* xp)
    {
        if(xp == NULL || xp.signal_exit == NULL) return;

        // [Trace] SID별 트레이스 연결 (L6)
        xp.trace = m_trace_manager.GetTrace(xp.sid);
        if(xp.trace != NULL) {
            xp.trace.LogLevel(L6_EXIT, "Exit Signal Received");
        }

        PrintFormat("[XEA-SVC] Dispatching Exit Request: %s", xp.sid);
        xp.msg_id = MSG_CLOSE_REQ;
        CXMessageHub::Default(xp).Send(xp);
    }
};

#endif
