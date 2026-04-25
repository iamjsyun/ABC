//+------------------------------------------------------------------+
//|                                     CXExitSignalWatcher.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
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

        // 1. 대기 중인 청산 신호 SELECT (ea_status = 0 AND xa_status = 1)
        xp.Set("sql", "SELECT sid, magic, sno, gno, dir FROM exit_signals WHERE ea_status = 0 AND xa_status = 1");
        int req = m_db.Prepare(xp);
        if(req == INVALID_HANDLE) return;
        
        while(DatabaseRead(req))
        {
            CXParam p; 
            p.msg_id = MSG_EXIT_SIGNAL;
            p.signal_exit = new CXSignalExit(); 
            
            CXSignalExit* sx = p.signal_exit;
            
            DatabaseColumnText(req, 0, sx.sid);
            long c; DatabaseColumnLong(req, 1, c); sx.magic = (ulong)c;
            long s; DatabaseColumnLong(req, 2, s); sx.sno = (ulong)s;
            long g; DatabaseColumnLong(req, 3, g); sx.gno = (ulong)g;
            DatabaseColumnText(req, 4, sx.dir);

            p.sid = sx.sid;
            p.magic = sx.magic;
            p.sno = sx.sno;
            p.gno = sx.gno;
            p.Validate();   // GID 생성
            sx.gid = p.gid;
            
            LOG_SIGNAL("[EXIT-SCAN]", StringFormat("Exit signal detected: %s", sx.gid), sx.gid);
            
            CXMessageHub::Default(&p).Send(&p);
            
            // 상태 업데이트 (SID 기준)
            string update_sql = StringFormat("UPDATE exit_signals SET ea_status = 1, updated = DATETIME('now') WHERE sid = '%s'", sx.sid);
            xp.Set("sql", update_sql);
            if(m_db.Execute(xp)) {
                LOG_SIGNAL("[EXIT-SCAN]", "Status updated to EXECUTING(1) in DB", sx.gid);
            }
        }
        DatabaseFinalize(req);
    }

    // [Feedback] 처리 완료 메시지 수신 시 DB에서 제거
    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_EXIT_CONFIRMED || m_db == NULL) return;
        
        string sql = StringFormat("DELETE FROM exit_signals WHERE sid='%s'", xp.sid);
        
        xp.Set("sql", sql);
        if(m_db.Execute(xp)) {
            LOG_SIGNAL("[EXIT-OK]", "Exit signal processed and removed from DB", xp.gid);
        }
    }
};

#endif
