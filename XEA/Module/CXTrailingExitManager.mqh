//+------------------------------------------------------------------+
//|                                     CXTrailingExitManager.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-25 09:55:00 |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_EXIT_MANAGER_MQH
#define CX_TRAILING_EXIT_MANAGER_MQH

#include "CXTrailingExitInstance.mqh"
#include <Arrays\ArrayObj.mqh>
#include "..\include\ICXProcessor.mqh"

// [Module] Trailing Exit Manager - 포지션 모니터링 및 채널별 청산 배분
class CXTrailingExitManager : public ICXPositionProcessor
{
private:
    CArrayObj       m_instances;

    // cno에 해당하는 인스턴스 찾기 또는 생성
    CXTrailingExitInstance* FindInstance(CXParam* xp)
    {
        ulong cno = xp.magic;
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
    // [Refactored] 직접 터미널 포지션 스캔 및 배분
    virtual void OnUpdate(CXParam* xp)
    {
        CXDatabase* db = xp.db;

        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;

            // 로컬 파라미터 준비
            CXParam p;
            p.magic = PositionGetInteger(POSITION_MAGIC);
            p.ticket = ticket;
            p.db = db;

            if(p.magic == 0) continue;

            CXTrailingExitInstance* inst = FindInstance(&p);
            if(inst != NULL) inst.Process(&p); 
        }
    }
};

#endif
