//+------------------------------------------------------------------+
//|                                     CXPositionMonitor.mqh        |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 11:50:00 |
//+------------------------------------------------------------------+
#ifndef CX_POSITION_MONITOR_MQH
#define CX_POSITION_MONITOR_MQH

#include "..\Library\CXMessageHub.mqh"
#include "..\Library\CXDefine.mqh"

#include "..\Library\ICXProcessor.mqh"

// [Module] Position Sync - 포지션 TP/SL 변화를 DB에 업데이트
class CXPositionMonitor : public ICXPositionProcessor
{
public:
    virtual void ProcessPosition(ulong ticket, CXDatabase* db)
    {
        // 이미 PositionSelectByTicket된 상태로 넘어옴
        double current_sl = PositionGetDouble(POSITION_SL);
        double current_tp = PositionGetDouble(POSITION_TP);
        string sid = PositionGetString(POSITION_COMMENT);
        
        // TP/SL 동기화 로직 (필요 시 DB 업데이트 실행)
    }
};

#endif
