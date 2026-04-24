//+------------------------------------------------------------------+
//|                                     CXEntrySignalWatcher.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 11:00:00 |
//+------------------------------------------------------------------+
#ifndef CX_ENTRY_SIGNAL_WATCHER_MQH
#define CX_ENTRY_SIGNAL_WATCHER_MQH

#include "..\Library\CXMessageHub.mqh"
#include "..\Library\CXDefine.mqh"
#include "..\Library\CXPacket.mqh"

#include "..\Library\CXDatabase.mqh"

// [Module] 진입 신호 감시자 - 초고속 큐 방식
class CXEntrySignalWatcher : public ICXReceiver
{
private:
    CXDatabase*     m_db;

public:
    CXEntrySignalWatcher() : m_db(NULL)
    {
        // 처리 완료 피드백 구독
        CXMessageHub::Default().Register(MSG_ENTRY_CONFIRMED, &this);
    }

    void Run(CXDatabase* db)
    {
        m_db = db;
        // 1. 조건 없는 SELECT
        int req = db.Prepare("SELECT time, symbol, cno, sno, gno, dir, type, sl, tp, price, lot FROM entry_signals");
        if(req == INVALID_HANDLE) return;
        
        while(DatabaseRead(req))
        {
            CXPacket* packet = new CXPacket();
            // ... (기존 데이터 추출 로직 동일) ...
            packet.cmd = CMD_OPEN;
            packet.Validate();
            
            CXMessageHub::Default().Send(MSG_ENTRY_SIGNAL, packet);
        }
        DatabaseFinalize(req);
    }

    // [Feedback] 처리 완료 메시지 수신 시 DB에서 제거
    virtual void OnReceiveMessage(int msg_id, CObject* message)
    {
        if(msg_id != MSG_ENTRY_CONFIRMED || m_db == NULL) return;
        
        CXPacket* packet = dynamic_cast<CXPacket*>(message);
        if(packet == NULL) return;

        // SID를 구성하는 핵심 정보를 조건으로 신호 삭제 (Zero-Condition 전략에 따라 정확히 일치하는 레코드 제거)
        string sql = StringFormat("DELETE FROM entry_signals WHERE time=%I64d AND cno=%I64u AND sno=%I64u AND gno=%I64u", 
                                  (long)packet.time, packet.cno, packet.sno, packet.gno);
        
        if(m_db.Execute(sql))
            Print("[Entry-Watcher] Signal Removed from DB: ", packet.pid);
    }
};

#endif
