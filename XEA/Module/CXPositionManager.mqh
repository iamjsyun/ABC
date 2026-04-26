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

    // [New] 터미널 자산 정보를 직접 스캔하여 포지션 진입 확정
    void VerifyPosition(CXParam* xp)
    {
        if(xp == NULL || xp.db == NULL || xp.ticket == 0) return;

        // 1. 터미널 포지션 선택 (Ticket 기준)
        if(PositionSelectByTicket(xp.ticket))
        {
            string sid = PositionGetString(POSITION_COMMENT);
            double price_open = PositionGetDouble(POSITION_PRICE_OPEN);
            double lot = PositionGetDouble(POSITION_VOLUME);
            
            // [Verification] SID 확인
            if(sid != "")
            {
                // [Action] 자산 확인 완료 -> DB에서 진입 신호 즉시 제거 (Fire & Forget)
                xp.QB_Reset().Table("entry_signals").Where("sid", sid);
                string delete_sql = StringFormat("DELETE FROM entry_signals WHERE sid = '%s'", sid);
                xp.Set("sql", delete_sql);
                xp.db.Execute(xp);

                // 로그 출력 (추적성 확보)
                Print(StringFormat("[%s] [INFO] [%s] [SIGNAL-REMOVED] [STEP-7->REMOVE] Terminal asset confirmed. Signal record deleted from DB. Ticket:%I64u", 
                      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), sid, xp.ticket));
            }
        }
    }
};

#endif
