//+------------------------------------------------------------------+
//|                                     CXPendingOrderWatcher.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 14:10:00 |
//+------------------------------------------------------------------+
#ifndef CX_PENDING_ORDER_WATCHER_MQH
#define CX_PENDING_ORDER_WATCHER_MQH

#include "..\Library\CXMessageHub.mqh"
#include "..\Library\CXDefine.mqh"
#include "..\Library\ICXProcessor.mqh"

// [Module] Pending Order Watcher - DB 신호 접수 확인 및 제거 전담
class CXPendingOrderWatcher : public ICXTicketProcessor
{
public:
    // 인터페이스 구현
    virtual void ProcessTicket(ulong ticket, CXDatabase* db)
    {
        // 이미 OrderSelect된 상태로 넘어옴
        string sid = OrderGetString(ORDER_COMMENT);
        if(sid == "") return;
        
        // ... (기존 로직 동일) ...

        // 1. 해당 SID를 가진 신호가 DB에 있다면 제거 (처리 완료 피드백)
        CXPacket packet;
        if(packet.ParseSID(sid)) 
        {
            string sql = StringFormat("DELETE FROM entry_signals WHERE time=%I64d AND cno=%I64u AND sno=%I64u AND gno=%I64u", 
                                      (long)packet.time, packet.cno, packet.sno, packet.gno);
            
            if(db.Execute(sql))
                Print("[Pending-Watcher] Order Confirmed. Signal Removed: ", sid);
        }
    }
};

#endif
