//+------------------------------------------------------------------+
//|                                              CXDBService.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_DB_SERVICE_MQH
#define CX_DB_SERVICE_MQH

#include "..\include\ICXProcessor.mqh"
#include <Arrays\ArrayObj.mqh>

// Include Watcher and Manager headers
#include "..\Module\CXEntrySignalWatcher.mqh"
#include "..\Module\CXExitSignalWatcher.mqh"
#include "..\Module\CXTrailingEntryManager.mqh"
#include "..\Module\CXPositionManager.mqh"
#include "..\Module\CXTrailingExitManager.mqh"

#include "..\include\CXDatabase.mqh"

// [Service] DB Service - 프로세서들을 관리하고 주기적으로 실행
class CXDBService
{
private:
    CXDatabase*             m_db;
    CArrayObj               m_ticket_procs;   // ICXTicketProcessor 리스트
    CArrayObj               m_position_procs; // ICXPositionProcessor 리스트
    
    // Watcher들은 스캔 루프 외에서 독립 실행되므로 별도 소유
    CXEntrySignalWatcher*   m_entry_watcher;
    CXExitSignalWatcher*    m_exit_watcher;

public:
    CXDBService()
    {
        m_db = new CXDatabase();
        CXParam xp;
        m_db.Open(&xp);
        m_db.CheckSchema(&xp);
        
        m_entry_watcher = new CXEntrySignalWatcher();
        m_exit_watcher  = new CXExitSignalWatcher();

        // [Startup Sync] 정체된 신호 복구 (ea_status: 1 -> 0)
        xp.db = m_db;
        m_entry_watcher.StartupSync(&xp);

        // [Static Registration] 모든 전략 프로세서를 상시 등록
        m_position_procs.Add(new CXTrailingExitManager());
    }

    ~CXDBService()
    {
        delete m_db;
        delete m_entry_watcher;
        delete m_exit_watcher;
        
        // 등록된 프로세서들 삭제
        for(int i = m_ticket_procs.Total() - 1; i >= 0; i--) 
        {
            ICXTicketProcessor* p = (ICXTicketProcessor*)m_ticket_procs.At(i);
            if(p != NULL) delete p;
        }
        m_ticket_procs.Clear();

        for(int i = m_position_procs.Total() - 1; i >= 0; i--) 
        {
            ICXPositionProcessor* p = (ICXPositionProcessor*)m_position_procs.At(i);
            if(p != NULL) delete p;
        }
        m_position_procs.Clear();
    }

    // 프로세서 등록 인터페이스
    void AddTicketProcessor(CXParam* xp) { m_ticket_procs.Add(xp.payload); }
    void AddPositionProcessor(CXParam* xp) { m_position_procs.Add(xp.payload); }

    // [New] DB 객체 접근자
    CXDatabase* GetDB(CXParam* xp) { return m_db; }

    void OnTimer(CXParam* xp)
    {
        if(xp == NULL) return;
        xp.db = m_db;

        // 1. DB 신호 감시 (SELECT)
        m_entry_watcher.Run(xp);
        m_exit_watcher.Run(xp);
        
        // 2. 대기 오더 도메인 업데이트 (매니저가 직접 스캔)
        for(int i = 0; i < m_ticket_procs.Total(); i++) {
            ICXTicketProcessor* p = (ICXTicketProcessor*)m_ticket_procs.At(i);
            if(p != NULL) p.OnUpdate(xp);
        }
        
        // 3. 포지션 도메인 업데이트 (매니저가 직접 스캔)
        for(int i = 0; i < m_position_procs.Total(); i++) {
            ICXPositionProcessor* p = (ICXPositionProcessor*)m_position_procs.At(i);
            if(p != NULL) p.OnUpdate(xp);
        }
    }
};

#endif
