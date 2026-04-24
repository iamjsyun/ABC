//+------------------------------------------------------------------+
//|                                     CXPositionMonitor.mqh        |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 11:50:00 |
//+------------------------------------------------------------------+
#ifndef CX_POSITION_MANAGER_MQH
#define CX_POSITION_MANAGER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"

#include "..\include\ICXProcessor.mqh"

// [Module] Position Manager - 포지션 TP/SL 변화를 DB에 업데이트 및 관리
class CXPositionManager : public ICXPositionProcessor
{
public:
    // [Refactored] 직접 터미널 포지션 스캔 및 동기화
    virtual void OnUpdate(CXParam* xp)
    {
        CXDatabase* db = xp.db;

        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;

            double current_sl = PositionGetDouble(POSITION_SL);
            double current_tp = PositionGetDouble(POSITION_TP);
            string sid = PositionGetString(POSITION_COMMENT);
            
            // TODO: TP/SL 동기화 로직 (필요 시 DB 업데이트 실행)
        }
    }
};

#endif
