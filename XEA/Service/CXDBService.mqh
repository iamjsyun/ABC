//+------------------------------------------------------------------+
//|                                              CXDBService.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_DB_SERVICE_MQH
#define CX_DB_SERVICE_MQH

#include "..\include\ICXProcessor.mqh"
#include <Arrays\ArrayObj.mqh>
#include "..\include\CXDatabase.mqh"

// [Service] DB Infrastructure Service - SQLite 관리 전담
class CXDBService : public ICXService
{
private:
    CXDatabase*             m_db;
    CArrayObj               m_ticket_procs;   
    CArrayObj               m_position_procs; 

public:
    CXDBService()
    {
        m_db = new CXDatabase();
        CXParam xp;
        m_db.Open(&xp);
        m_db.CheckSchema(&xp);
    }

    ~CXDBService()
    {
        delete m_db;
    }

    // 자원 접근자
    CXDatabase* GetDB() { return m_db; }

    // 인터페이스 구현
    virtual void OnTimer(CXParam* xp)
    {
        if(xp == NULL) return;
        xp.db = m_db;

        for(int i = 0; i < m_ticket_procs.Total(); i++) {
            ICXTicketProcessor* p = (ICXTicketProcessor*)m_ticket_procs.At(i);
            if(p != NULL) p.OnUpdate(xp);
        }
        
        for(int i = 0; i < m_position_procs.Total(); i++) {
            ICXPositionProcessor* p = (ICXPositionProcessor*)m_position_procs.At(i);
            if(p != NULL) p.OnUpdate(xp);
        }
    }
};

#endif
