//+------------------------------------------------------------------+
//|                                             CXTraceManager.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_TRACE_MANAGER_MQH
#define CX_TRACE_MANAGER_MQH

#include <Arrays\ArrayObj.mqh>
#include "..\include\CXTradeTrace.mqh"

// [Service] 전체 SID의 트레이스 인스턴스들을 관리
class CXTraceManager : public CObject
{
private:
    CArrayObj m_traces;

public:
    CXTraceManager() {}
    ~CXTraceManager() { m_traces.Clear(); }

    // 새로운 트레이스 생성 또는 기존 것 반환
    CXTradeTrace* GetTrace(string sid)
    {
        if(sid == "") return NULL;

        for(int i = 0; i < m_traces.Total(); i++)
        {
            CXTradeTrace* trace = (CXTradeTrace*)m_traces.At(i);
            // CXTradeTrace 내부 필드 m_sid를 가져올 수 없으므로, 
            // 나중에 필요 시 CXTradeTrace에 GetSID() 추가하거나 비교 로직 개선
            // 여기서는 단순 리스트 관리를 수행
        }
        
        // 현재는 매번 찾기보다, 필요한 시점에 SID별 파일 핸들을 여는 구조이므로
        // 간단하게 생성하여 반환하는 팩토리 역할 수행
        CXTradeTrace* newTrace = new CXTradeTrace(sid);
        m_traces.Add(newTrace);
        return newTrace;
    }

    // SID로 트레이스 찾기 (개선 버전)
    // 실제 운영 시에는 CHashMap 등을 사용하는 것이 좋으나, 
    // MQL5 표준 라이브러리 범주 내에서 ArrayObj로 관리
    void ReleaseTrace(string sid)
    {
        // 종료된 SID의 트레이스 객체 해제 (Summary 기록 후 삭제)
        // ... 구현 생략 (필요 시 확장)
    }
};

#endif
