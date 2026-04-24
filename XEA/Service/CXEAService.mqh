//+------------------------------------------------------------------+
//|                                              CXEAService.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 10:30:00 |
//+------------------------------------------------------------------+
#ifndef CX_EA_SERVICE_MQH
#define CX_EA_SERVICE_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include "..\include\ICXReceiver.mqh"
#include <Trade\Trade.mqh>

// Corrected include for CXDBService.mqh, assuming it's in the same Service directory.
#include "CXDBService.mqh"
#include "CXLogService.mqh"
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
    CXLimitOrderManager*    m_limit_manager;
    CXStopOrderManager*     m_stop_manager;
    CXMarketOrderManager*   m_market_manager;
    CXCloseManager*         m_close_manager;
    CXTrailingEntryManager* m_trailing_manager; 
    CXPositionManager*      m_position_manager; // [New] 직접 관리

public:
    CXEAService() 
    {
        // 1. 모든 서비스 및 모듈 생성
        m_log_service      = new CXLogService();
        m_db_service       = new CXDBService();
        m_limit_manager    = new CXLimitOrderManager();
        m_stop_manager     = new CXStopOrderManager();
        m_market_manager   = new CXMarketOrderManager();
        m_close_manager    = new CXCloseManager();
        m_trailing_manager = new CXTrailingEntryManager();
        m_position_manager = new CXPositionManager(); // 인스턴스 생성

        // 2. 핵심 이벤트 구독
        CXParam p; p.receiver = &this;
        p.msg_id = MSG_ENTRY_SIGNAL; CXMessageHub::Default(&p).Register(&p);
        p.msg_id = MSG_EXIT_SIGNAL;  CXMessageHub::Default(&p).Register(&p);
    }

    ~CXEAService()
    {
        // 생성된 모든 객체 해제
        delete m_log_service;
        delete m_db_service;
        delete m_limit_manager;
        delete m_stop_manager;
        delete m_market_manager;
        delete m_close_manager;
        delete m_trailing_manager;
        delete m_position_manager;
    }

    // 외부 주입을 위한 Getter
    CXDBService* GetDBService(CXParam* xp) { return m_db_service; }

    // OnTimer는 외부(XEA.mq5)에서 호출됨
    void OnTimer(CXParam* xp)
    {
        if(xp == NULL) return;
        xp.db = m_db_service.GetDB(xp);

        // 1. 트레일링 진입 관리 (독립 루프)
        if(CheckPointer(m_trailing_manager) == POINTER_DYNAMIC)
            m_trailing_manager.OnUpdate(xp);

        // 2. 포지션 실시간 감시 (독립 루프)
        if(CheckPointer(m_position_manager) == POINTER_DYNAMIC)
            m_position_manager.OnUpdate(xp);

        // 3. DB 서비스 및 기타 프로세서 업데이트
        if(CheckPointer(m_db_service) == POINTER_DYNAMIC)
            m_db_service.OnTimer(xp);
    }

    // [New] 통합 히스토리 기록 메서드
    void RecordHistory(CXParam* xp)
    {
        if(xp == NULL || m_db_service == NULL) return;
        CXParam* packet = dynamic_cast<CXParam*>(xp.payload);
        if(packet == NULL) return;
        
        CXDatabase* db = m_db_service.GetDB(xp);
        if(db == NULL) return;

        string status = xp.Get("status");
        string message = xp.Get("message");

        string sql = StringFormat(
            "INSERT OR REPLACE INTO trade_history (sid, gid, time, status, message, symbol, dir, lot, price, sl, tp) "
            "VALUES ('%s', '%s', %I64d, '%s', '%s', '%s', '%s', %.2f, %.5f, %.5f, %.5f)",
            packet.sid, packet.gid, (long)TimeCurrent(), status, message, 
            packet.symbol, packet.dir, packet.lots[0], packet.price, packet.sls[0], packet.tps[0]
        );
        xp.Set("sql", sql);
        db.Execute(xp);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL) return;
        CXParam* packet = dynamic_cast<CXParam*>(xp.payload);
        if(packet == NULL) return;

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
        CXParam* packet = dynamic_cast<CXParam*>(xp.payload);
        if(packet == NULL) return;

        // Populate domain object signal_entry
        if(xp.signal_entry == NULL) xp.signal_entry = new CXSignalEntry();
        CXSignalEntry* se = xp.signal_entry;
        
        se.sid     = packet.sid;
        se.symbol  = packet.symbol;
        se.magic   = (long)packet.magic;
        se.sno     = (int)packet.sno;
        se.gno     = (int)packet.gno;
        se.dir     = (int)packet.dir;
        se.type    = (int)packet.type;
        se.price   = packet.price;
        se.lot     = (ArraySize(packet.lots) > 0) ? packet.lots[0] : 0.01;
        se.sl      = (ArraySize(packet.sls) > 0) ? packet.sls[0] : 0;
        se.tp      = (ArraySize(packet.tps) > 0) ? packet.tps[0] : 0;
        se.offset  = (ArraySize(packet.offsets) > 0) ? packet.offsets[0] : 0;
        se.created = (datetime)packet.time;

        if(se.type == 1) { // MARKET
            xp.msg_id = MSG_MARKET_ORDER_REQ;
            CXMessageHub::Default(xp).Send(xp);
        } else if(se.type == 3 || se.type == 5) { // STOP or STOP_P
            xp.msg_id = MSG_STOP_ORDER_REQ;
            CXMessageHub::Default(xp).Send(xp);
        } else { // LIMIT or LIMIT_P (2, 4)
            xp.msg_id = MSG_LIMIT_ORDER_REQ;
            CXMessageHub::Default(xp).Send(xp);
        }
    }

    void HandleExitSignal(CXParam* xp)
    {
        CXParam* packet = dynamic_cast<CXParam*>(xp.payload);
        if(packet == NULL) return;
        
        // Populate domain object signal_exit
        if(xp.signal_exit == NULL) xp.signal_exit = new CXSignalExit();
        CXSignalExit* sx = xp.signal_exit;

        sx.sid     = packet.sid;
        sx.gid     = packet.gid;
        sx.magic   = packet.magic;
        sx.sno     = packet.sno;
        sx.gno     = packet.gno;
        sx.dir     = packet.dir;
        sx.time    = packet.time;

        Print("[XEA-SVC] Close Dispatch: ", sx.gid);
        xp.msg_id = MSG_CLOSE_REQ;
        CXMessageHub::Default(xp).Send(xp);
    }
};

#endif

