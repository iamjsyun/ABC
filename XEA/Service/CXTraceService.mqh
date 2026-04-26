//+------------------------------------------------------------------+
//|                                             CXTraceService.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_TRACE_SERVICE_MQH
#define CX_TRACE_SERVICE_MQH

#include <Arrays\ArrayObj.mqh>
#include "..\include\CXTradeTrace.mqh"
#include "..\include\ICXProcessor.mqh"

// [Service] 전체 SID의 트레이스 인스턴스들을 관리하는 서비스
class CXTraceService : public ICXService
{
private:
    CArrayObj m_traces;

public:
    CXTraceService() {}
    ~CXTraceService() { m_traces.Clear(); }

    virtual void OnTimer(CXParam* xp) {}

    // 새로운 트레이스 생성 또는 기존 것 반환
    CXTradeTrace* GetTrace(string sid)
    {
        if(sid == "") return NULL;

        // 현재는 생성 팩토리 역할 수행 (필요 시 검색 로직 확장)
        CXTradeTrace* newTrace = new CXTradeTrace(sid);
        m_traces.Add(newTrace);
        return newTrace;
    }

    void ReleaseTrace(string sid)
    {
        // 종료된 SID의 트레이스 객체 해제 로직 (필요 시 구현)
    }
};

#endif
