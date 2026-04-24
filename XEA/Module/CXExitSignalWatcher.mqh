//+------------------------------------------------------------------+
//|                                     CXExitSignalWatcher.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 11:05:00 |
//+------------------------------------------------------------------+
#ifndef CX_EXIT_SIGNAL_WATCHER_MQH
#define CX_EXIT_SIGNAL_WATCHER_MQH

#include "..\Library\CXMessageHub.mqh"
#include "..\Library\CXDefine.mqh"
#include "..\Library\CXPacket.mqh"

// [Module] 청산 신호 감시자 - 초고속 큐 방식
class CXExitSignalWatcher : public ICXReceiver
{
private:
    CXDatabase*     m_db;

public:
    CXExitSignalWatcher() : m_db(NULL)
    {
        // 처리 완료 피드백 구독
        CXMessageHub::Default().Register(MSG_EXIT_CONFIRMED, &this);
    }

    void Run(CXDatabase* db)
    {
        m_db = db;
        // 1. 조건 없는 SELECT
        int req = db.Prepare("SELECT time, cno, sno, gno, dir FROM exit_signals");
        if(req == INVALID_HANDLE) return;
        
        while(DatabaseRead(req))
        {
            CXPacket* packet = new CXPacket();
            
            long t; DatabaseColumnLong(req, 0, t); packet.time = (datetime)t;
            long c; DatabaseColumnLong(req, 1, c); packet.cno = (ulong)c;
            long s; DatabaseColumnLong(req, 2, s); packet.sno = (ulong)s;
            long g; DatabaseColumnLong(req, 3, g); packet.gno = (ulong)g;
            DatabaseColumnText(req, 4, packet.dir);
            
            packet.cmd = CMD_CLOSE;
            packet.Validate();
            
            CXMessageHub::Default().Send(MSG_EXIT_SIGNAL, packet);
        }
        DatabaseFinalize(req);
    }

    // [Feedback] 처리 완료 메시지 수신 시 DB에서 제거
    virtual void OnReceiveMessage(int msg_id, CObject* message)
    {
        if(msg_id != MSG_EXIT_CONFIRMED || m_db == NULL) return;
        
        CXPacket* packet = dynamic_cast<CXPacket*>(message);
        if(packet == NULL) return;

        // SID 구성 정보를 조건으로 청산 신호 삭제
        string sql = StringFormat("DELETE FROM exit_signals WHERE time=%I64d AND cno=%I64u AND sno=%I64u AND gno=%I64u", 
                                  (long)packet.time, packet.cno, packet.sno, packet.gno);
        
        if(m_db.Execute(sql))
            Print("[Exit-Watcher] Exit Signal Removed from DB: ", packet.gid);
    }
};

#endif
