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

// [Service] 청산 신호 감시 및 터미널 자산 동기화 서비스
class CXExitWatchService : public ICXService
{
private:
    CXDatabase*     m_db; 

    string LogHeader(string level, string sid, string tag) {
        return StringFormat("[%s] [%s] [%s] [%s] ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), level, sid, tag);
    }

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
        
        // 1. 새로운 청산 신호 스캔 및 전송
        ProcessScan(xp);
        
        // 2. 터미널 자산과 DB 상태 동기화 (청산 감시 Watchdog)
        SyncTerminalAssets(xp);
    }

private:
    // [Action] 신규 청산 신호 인지 및 Manager에게 전송
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
            
            // 로그 기록 및 메시지 전송
            Print(LogHeader("INFO", p.sid, "SCAN-HIT"), "Exit Signal Detected.");
            CXMessageHub::Default(&p).Send(&p);
            
            // 상태를 Executing(1)로 변경
            string update_sql = StringFormat("UPDATE exit_signals SET ea_status = 1, updated = datetime(%I64d, 'unixepoch') WHERE sid = '%s'", (long)xp.time, sx.sid);
            xp.Set("sql", update_sql);
            m_db.Execute(xp);
        }
        ::DatabaseFinalize(_req);
    }

    // [Watchdog] 터미널에 포지션이 없는데 DB가 Active(2) 이상인 경우 청산 완료 처리
    void SyncTerminalAssets(CXParam* xp)
    {
        // DB에서 Active(2) 또는 Liquidating(8) 상태인 진입 신호들 조회
        xp.Set("sql", "SELECT sid, ea_status FROM entry_signals WHERE ea_status IN (2, 6, 8)");
        int _req = m_db.Prepare(xp);
        if(_req == INVALID_HANDLE) return;
        
        while(::DatabaseRead(_req))
        {
            string sid; ::DatabaseColumnText(_req, 0, sid);
            int current_status; ::DatabaseColumnInteger(_req, 1, current_status);
            bool found = false;
            
            // 터미널에서 해당 SID의 포지션 찾기
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
                if(PositionGetTicket(i) > 0 && PositionGetString(POSITION_COMMENT) == sid)
                {
                    found = true;
                    break;
                }
            }
            
            // 터미널에 없으면 청산된 것임
            if(!found)
            {
                string step_tag = (current_status == 8) ? "[STEP-8->4] Closed Verified" : "[STEP-2->4] Closed from Terminal";
                Print(LogHeader("INFO", sid, "EXIT-VERIFIED"), StringFormat("%s. Marking as Closed.", step_tag));
                
                // entry_signals 상태 업데이트: Closed(4)
                string update_sql = StringFormat(
                    "UPDATE entry_signals SET ea_status = 4, tag = '%s', updated = datetime(%I64d, 'unixepoch') WHERE sid = '%s'", 
                    step_tag, (long)TimeCurrent(), sid);
                
                // 루프 내에서 DB 실행을 위해 임시 저장
                CXParam p; p.db = m_db; p.Set("sql", update_sql);
                m_db.Execute(&p);
            }
        }
        ::DatabaseFinalize(_req);
    }

public:
    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_EXIT_CONFIRMED || m_db == NULL) return;
        
        Print(LogHeader("INFO", xp.sid, "EXIT-OK"), "Exit confirmation received. Cleaning up signals.");
        
        string sql = StringFormat("DELETE FROM exit_signals WHERE sid='%s'", xp.sid);
        xp.Set("sql", sql);
        m_db.Execute(xp);
    }
};

#endif
