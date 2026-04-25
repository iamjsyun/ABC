//+------------------------------------------------------------------+
//|                                      CXExitWatchService.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_EXIT_WATCH_SERVICE_MQH
#define CX_EXIT_WATCH_SERVICE_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include "..\include\CXDatabase.mqh"
#include "..\include\CXSignalExit.mqh"
#include "..\include\ICXReceiver.mqh"
#include "..\include\ICXProcessor.mqh"

// [Service] 청산 신호 감시 전담 서비스
class CXExitWatchService : public ICXService
{
private:
    CXDatabase*     m_db; 

public:
    CXExitWatchService() : m_db(NULL)
    {
        CXParam p; p.msg_id = MSG_EXIT_CONFIRMED; p.receiver = (ICXReceiver*)GetPointer(this);
        CXMessageHub::Default(&p).Register(&p);
    }

    void SetDatabase(CXDatabase* db) { m_db = db; }

    virtual void OnTimer(CXParam* xp)
    {
        if(xp == NULL || m_db == NULL) return;
        ProcessScan(xp);
    }

private:
    void ProcessScan(CXParam* xp)
    {
        xp.Set("sql", "SELECT sid, magic, sno, gno, dir FROM exit_signals WHERE ea_status = 0 AND xa_status = 1");
        int _req = m_db.Prepare(xp);
        if(_req == INVALID_HANDLE) return;
        
        while(::DatabaseRead(_req))
        {
            CXParam p; 
            p.msg_id = MSG_EXIT_SIGNAL;
            p.db = m_db;
            p.time = xp.time;
            p.signal_exit = new CXSignalExit(); 
            
            CXSignalExit* sx = p.signal_exit;
            
            ::DatabaseColumnText(_req, 0, sx.sid);
            long _m; ::DatabaseColumnLong(_req, 1, _m); sx.magic = (ulong)_m;
            long _s; ::DatabaseColumnLong(_req, 2, _s); sx.sno = (ulong)_s;
            long _g; ::DatabaseColumnLong(_req, 3, _g); sx.gno = (ulong)_g;
            ::DatabaseColumnText(_req, 4, sx.dir);

            p.sid = sx.sid; p.magic = sx.magic; p.sno = sx.sno; p.gno = sx.gno;
            p.Validate();   
            sx.gid = p.gid;
            
            CXMessageHub::Default(&p).Send(&p);
            
            string update_sql = StringFormat("UPDATE exit_signals SET ea_status = 1, updated = datetime(%I64d, 'unixepoch') WHERE sid = '%s'", (long)xp.time, sx.sid);
            xp.Set("sql", update_sql);
            m_db.Execute(xp);
        }
        ::DatabaseFinalize(_req);
    }

public:
    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_EXIT_CONFIRMED || m_db == NULL) return;
        string sql = StringFormat("DELETE FROM exit_signals WHERE sid='%s'", xp.sid);
        xp.Set("sql", sql);
        m_db.Execute(xp);
    }
};

#endif
