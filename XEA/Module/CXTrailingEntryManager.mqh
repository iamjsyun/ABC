//+------------------------------------------------------------------+
//|                                     CXTrailingEntryManager.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-25 09:50:00 |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_ENTRY_MANAGER_MQH
#define CX_TRAILING_ENTRY_MANAGER_MQH

#include "CXTrailingInstance.mqh"
#include <Arrays\ArrayObj.mqh>
#include "..\Library\ICXProcessor.mqh"

// [Module] Trailing Entry Manager - 터미널 대기 오더 실시간 모니터링 및 인스턴스 관리
class CXTrailingEntryManager : public ICXTicketProcessor
{
private:
    CArrayObj       m_instances;

    // cno에 해당하는 인스턴스 찾기 또는 생성
    CXTrailingInstance* FindInstance(ulong cno)
    {
        for(int i=0; i<m_instances.Total(); i++)
        {
            CXTrailingInstance* inst = (CXTrailingInstance*)m_instances.At(i);
            if(inst != NULL && inst.Cno() == cno) return inst;
        }
        
        // 없으면 신규 생성
        CXTrailingInstance* new_inst = new CXTrailingInstance(cno);
        m_instances.Add(new_inst);
        return new_inst;
    }

public:
    // 인터페이스 구현
    virtual void ProcessTicket(ulong ticket, CXDatabase* db)
    {
        // 이미 OrderSelect된 상태로 넘어옴
        ulong cno = OrderGetInteger(ORDER_MAGIC);
        if(cno == 0) return;

        // 해당 매직(cno) 인스턴스에 처리 위임
        CXTrailingInstance* inst = FindInstance(cno);
        if(inst != NULL) inst.Process(ticket);
    }
};

#endif
