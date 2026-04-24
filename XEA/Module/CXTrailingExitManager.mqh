//+------------------------------------------------------------------+
//|                                     CXTrailingExitManager.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-25 09:55:00 |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_EXIT_MANAGER_MQH
#define CX_TRAILING_EXIT_MANAGER_MQH

#include "CXTrailingExitInstance.mqh"
#include <Arrays\ArrayObj.mqh>
#include "..\Library\ICXProcessor.mqh"

// [Module] Trailing Exit Manager - 포지션 모니터링 및 채널별 청산 배분
class CXTrailingExitManager : public ICXPositionProcessor
{
private:
    CArrayObj       m_instances;

    // cno에 해당하는 인스턴스 찾기 또는 생성
    CXTrailingExitInstance* FindInstance(ulong cno)
    {
        for(int i=0; i<m_instances.Total(); i++)
        {
            CXTrailingExitInstance* inst = (CXTrailingExitInstance*)m_instances.At(i);
            if(inst != NULL && inst.Cno() == cno) return inst;
        }
        
        // 없으면 신규 생성
        CXTrailingExitInstance* new_inst = new CXTrailingExitInstance(cno);
        m_instances.Add(new_inst);
        return new_inst;
    }

public:
    // 인터페이스 구현
    virtual void ProcessPosition(ulong ticket, CXDatabase* db)
    {
        if(!PositionSelectByTicket(ticket)) return;
        
        ulong cno = PositionGetInteger(POSITION_MAGIC);
        if(cno == 0) return;

        CXTrailingExitInstance* inst = FindInstance(cno);
        if(inst != NULL) inst.Process(ticket);
    }
};

#endif
