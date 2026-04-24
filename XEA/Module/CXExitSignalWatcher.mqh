//+------------------------------------------------------------------+
//|                                     CXExitSignalWatcher.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 11:05:00 |
//+------------------------------------------------------------------+
#ifndef CX_EXIT_SIGNAL_WATCHER_MQH
#define CX_EXIT_SIGNAL_WATCHER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"

#include "..\include\CXDatabase.mqh"

// [Module] 청산 신호 감시자 - 초고속 큐 방식
class CXExitSignalWatcher : public ICXReceiver
{
private:
    CXDatabase*     m_db;

public:
    CXExitSignalWatcher() : m_db(NULL)
    {
        // 처리 완료 피드백 구독
        CXParam p; p.msg_id = MSG_EXIT_CONFIRMED; p.receiver = &this;
        CXMessageHub::Default(&p).Register(&p);
    }

    // 주기적 실행
    void Run(CXParam* xp)
    {
        if(xp == NULL || xp.db == NULL) return;
        m_db = xp.db;

        // 1. 대기 중인 청산 신호 SELECT (ea_status = 0)
        xp.Set("sql", "SELECT time, cno, sno, gno, dir FROM exit_signals WHERE ea_status = 0");
        int req = m_db.Prepare(xp);
        if(req == INVALID_HANDLE) return;
        
        while(DatabaseRead(req))
        {
            CXParam p; // 메시지 봉투 (스택 할당)
            p.msg_id = MSG_EXIT_SIGNAL;
            p.signal_exit = new CXSignalExit(); // 전문 도메인 객체 생성
            
            CXSignalExit* sx = p.signal_exit;
            
            long t; DatabaseColumnLong(req, 0, t); sx.time = (datetime)t;
            long c; DatabaseColumnLong(req, 1, c); sx.magic = (ulong)c;
            long s; DatabaseColumnLong(req, 2, s); sx.sno = (ulong)s;
            long g; DatabaseColumnLong(req, 3, g); sx.gno = (ulong)g;
            DatabaseColumnText(req, 4, sx.dir);

            p.magic = sx.magic;
            p.time = sx.time;
            p.sno = sx.sno;
            p.gno = sx.gno;
            p.Validate();   // GID 생성
            sx.sid = p.sid;
            sx.gid = p.gid;
            
            // 메시지 전송
            CXMessageHub::Default(&p).Send(&p);
            
            // 상태 업데이트
            string update_sql = StringFormat("UPDATE exit_signals SET ea_status = 1 WHERE time = %I64d AND cno = %I64u", (long)sx.time, sx.magic);
            xp.Set("sql", update_sql);
            m_db.Execute(xp);
        }
        DatabaseFinalize(req);
    }

    // [Feedback] 처리 완료 메시지 수신 시 DB에서 제거
    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_EXIT_CONFIRMED || m_db == NULL) return;
        
        string sql = StringFormat("DELETE FROM exit_signals WHERE time=%I64d AND cno=%I64u AND sno=%I64u AND gno=%I64u", 
                                  (long)xp.time, xp.magic, xp.sno, xp.gno);
        
        xp.Set("sql", sql);
        if(m_db.Execute(xp))
            Print("[Exit-Watcher] Exit Signal Removed from DB: ", xp.gid);
    }
};

#endif
