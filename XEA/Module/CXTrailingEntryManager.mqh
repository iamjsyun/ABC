//+------------------------------------------------------------------+
//|                                     CXTrailingEntryManager.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-25 09:50:00 |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_ENTRY_MANAGER_MQH
#define CX_TRAILING_ENTRY_MANAGER_MQH

#include "CXTrailingEntryInstance.mqh"
#include <Arrays\ArrayObj.mqh>
#include "..\include\ICXProcessor.mqh"

// [Module] Trailing Entry Manager - 터미널 대기 오더 실시간 모니터링 및 인스턴스 관리
class CXTrailingEntryManager : public ICXTicketProcessor
{
private:
    CArrayObj       m_instances;

    // sid에 해당하는 인스턴스 찾기 또는 생성
    CXTrailingEntryInstance* FindInstance(CXParam* xp)
    {
        string sid = xp.sid;
        ulong magic = xp.magic;

        for(int i=0; i<m_instances.Total(); i++)
        {
            CXTrailingEntryInstance* inst = (CXTrailingEntryInstance*)m_instances.At(i);
            if(inst != NULL && inst.Sid() == sid) return inst;
        }
        
        // 없으면 신규 생성 (sid와 magic 전달)
        CXTrailingEntryInstance* new_inst = new CXTrailingEntryInstance(sid, magic);
        m_instances.Add(new_inst);
        return new_inst;
    }

public:
    // [Refactored] 직접 터미널 오더 스캔 및 배분
    virtual void OnUpdate(CXParam* xp)
    {
        CXDatabase* db = xp.db;

        // 1. 모든 인스턴스를 '미발견' 상태로 초기화
        CXParam p_not_found; p_not_found.Set("found", "false");
        for(int i = 0; i < m_instances.Total(); i++) {
            CXTrailingEntryInstance* inst = (CXTrailingEntryInstance*)m_instances.At(i);
            if(inst != NULL) inst.SetFound(&p_not_found);
        }

        // 2. 터미널 오더 스캔 (진실의 근원)
        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);
            if(!OrderSelect(ticket)) continue;

            // 로컬 파라미터 준비
            CXParam p;
            p.sid = OrderGetString(ORDER_COMMENT);
            p.magic = OrderGetInteger(ORDER_MAGIC);
            p.ticket = ticket;
            p.db = db;
            p.Set("found", "true");
            
            if(p.sid == "") continue;

            // 해당 SID 인스턴스 찾기 또는 즉시 생성
            CXTrailingEntryInstance* inst = FindInstance(&p);
            if(inst != NULL) {
                inst.SetFound(&p);    // 터미널에 존재함을 표시
                inst.Process(&p);     // 파라미터 전달 방식 변경
            }
        }

        // 3. 터미널에서 사라진 오더의 인스턴스 제거 (GC)
        for(int i = m_instances.Total() - 1; i >= 0; i--) {
            CXTrailingEntryInstance* inst = (CXTrailingEntryInstance*)m_instances.At(i);
            if(inst != NULL && !inst.IsFound()) {
                PrintFormat("[Trailing-Mgr] Order for SID %s no longer exists in terminal. Removing instance.", inst.Sid());
                m_instances.Delete(i);
            }
        }
    }
};

#endif
