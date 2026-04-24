//+------------------------------------------------------------------+
//|                                              CXDBService.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-25 09:30:00 |
//+------------------------------------------------------------------+
#ifndef CX_DB_SERVICE_MQH
#define CX_DB_SERVICE_MQH

#include "..\Library\ICXProcessor.mqh"
#include <Arrays\ArrayObj.mqh>

// Include Watcher and Manager headers
#include "..\Module\CXEntrySignalWatcher.mqh"
#include "..\Module\CXExitSignalWatcher.mqh"
#include "..\Module\CXPendingOrderWatcher.mqh"
#include "..\Module\CXTrailingEntryManager.mqh"
#include "..\Module\CXPositionMonitor.mqh"
#include "..\Module\CXTrailingExitManager.mqh"

#include "..\Library\CXDatabase.mqh"

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
        m_db.Open();
        m_db.CheckSchema();
        
        m_entry_watcher = new CXEntrySignalWatcher();
        m_exit_watcher  = new CXExitSignalWatcher();
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
    void AddTicketProcessor(ICXTicketProcessor* p) { m_ticket_procs.Add(p); }
    void AddPositionProcessor(ICXPositionProcessor* p) { m_position_procs.Add(p); }

    void OnTimer()
    {
        // 1. DB 신호 감시 (SELECT)
        m_entry_watcher.Run(m_db);
        m_exit_watcher.Run(m_db);
        
        // 2. 터미널 오더 단일 스캔 및 배분
        for(int i=OrdersTotal()-1; i>=0; i--) {
            ulong ticket = OrderGetTicket(i);
            if(OrderSelect(ticket)) {
                for(int j=0; j<m_ticket_procs.Total(); j++) {
                    ICXTicketProcessor* p = (ICXTicketProcessor*)m_ticket_procs.At(j);
                    if(p != NULL) p.ProcessTicket(ticket, m_db);
                }
            }
        }
        
        // 3. 터미널 포지션 단일 스캔 및 배분
        for(int i=PositionsTotal()-1; i>=0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket)) {
                for(int j=0; j<m_position_procs.Total(); j++) {
                    ICXPositionProcessor* p = (ICXPositionProcessor*)m_position_procs.At(j);
                    if(p != NULL) p.ProcessPosition(ticket, m_db);
                }
            }
        }
    }
};

#endif
