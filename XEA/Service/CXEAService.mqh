//+------------------------------------------------------------------+
//|                                              CXEAService.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 10:30:00 |
//+------------------------------------------------------------------+
#ifndef CX_EA_SERVICE_MQH
#define CX_EA_SERVICE_MQH

#include "..\Library\CXMessageHub.mqh"
#include "..\Library\CXDefine.mqh"
#include "..\Library\CXPacket.mqh"
#include "..\Library\ICXReceiver.mqh"
#include "..\Library\CXPacket.mqh"
#include <Trade\Trade.mqh>

#include "CXDBService.mqh"
#include "CXLogService.mqh"
#include "..\Module\CXLimitOrderManager.mqh"
#include "..\Module\CXMarketOrderManager.mqh"
#include "..\Module\CXCloseManager.mqh"

// [Service] XEA Facade - 모든 하위 서비스 및 모듈의 Life-cycle을 관리
class CXEAService : public ICXReceiver
{
private:
    CXDBService*            m_db_service;
    CXLogService*           m_log_service;
    CXLimitOrderManager*    m_limit_manager;
    CXMarketOrderManager*   m_market_manager;
    CXCloseManager*         m_close_manager;

public:
    CXEAService() 
    {
        // 1. 모든 서비스 및 모듈 생성
        m_log_service    = new CXLogService();
        m_db_service     = new CXDBService();
        m_limit_manager  = new CXLimitOrderManager();
        m_market_manager = new CXMarketOrderManager();
        m_close_manager  = new CXCloseManager();

        // 2. 핵심 이벤트 구독
        CXMessageHub::Default().Register(MSG_ENTRY_SIGNAL, &this);
        CXMessageHub::Default().Register(MSG_EXIT_SIGNAL, &this);
    }

    ~CXEAService()
    {
        // 생성된 모든 객체 해제
        delete m_log_service;
        delete m_db_service;
        delete m_limit_manager;
        delete m_market_manager;
        delete m_close_manager;
    }

    // 외부 주입을 위한 Getter
    CXDBService* GetDBService() { return m_db_service; }

    // OnTimer는 외부(XEA.mq5)에서 호출됨
    void OnTimer()
    {
        // DB 서비스 폴링 위임
        if(CheckPointer(m_db_service) == POINTER_DYNAMIC)
            m_db_service.OnTimer();
    }

    virtual void OnReceiveMessage(int msg_id, CObject* message)
    {
        CXPacket* packet = dynamic_cast<CXPacket*>(message);
        if(packet == NULL) return;

        switch(msg_id)
        {
            case MSG_ENTRY_SIGNAL:
                HandleEntrySignal(packet);
                break;
            case MSG_EXIT_SIGNAL:
                HandleExitSignal(packet);
                break;
        }
    }

private:
    void HandleEntrySignal(CXPacket* packet)
    {
        if(packet.type == "MARKET" || packet.type == "1") {
            CXMessageHub::Default().Send(MSG_MARKET_ORDER_REQ, packet);
        } else {
            CXMessageHub::Default().Send(MSG_LIMIT_ORDER_REQ, packet);
        }
    }

    void HandleExitSignal(CXPacket* packet)
    {
        Print("[XEA-SVC] Close Dispatch: ", packet.gid);
        CXMessageHub::Default().Send(MSG_CLOSE_REQ, packet);
    }
};

#endif
