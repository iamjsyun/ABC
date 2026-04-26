//+------------------------------------------------------------------+
//|                                     CXEntryWatchService.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_ENTRY_WATCH_SERVICE_MQH
#define CX_ENTRY_WATCH_SERVICE_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include "..\include\CXDatabase.mqh"
#include "..\include\CXSignalEntry.mqh"
#include "..\include\ICXProcessor.mqh"

// [Service] 진입 신호 감시 및 터미널 자산 동기화 서비스
class CXEntryWatchService : public ICXService
{
private:
    CXDatabase*     m_db; 

    string LogHeader(string level, string sid, string tag) {
        return StringFormat("[%s] [%s] [%s] [%s] ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), level, sid, tag);
    }

public:
    CXEntryWatchService() : m_db(NULL) {}

    void SetDatabase(CXDatabase* db) { m_db = db; }

    virtual void OnTimer(CXParam* xp)
    {
        if(xp == NULL || m_db == NULL) return;
        
        // 1. 새로운 진입 신호 스캔 및 전송
        ProcessScan(xp);
        
        // 2. 터미널 자산과 DB 상태 동기화 (Watchdog)
        SyncTerminalAssets(xp);
    }

private:
    // [Action] 신규 신호 인지 및 Manager에게 전송
    void ProcessScan(CXParam* xp)
    {
        if(MQLInfoInteger(MQL_TESTER)) {
            MqlDateTime dt;
            TimeCurrent(dt);
            if(dt.hour < 9 || (dt.hour == 9 && dt.min == 0)) return; 
        }

        string sql = "SELECT sid, symbol, dir, type, price_signal, lot, tp, sl, te_start, te_step, magic FROM entry_signals "
                     "WHERE ea_status = 0 AND xa_status = 1";
        xp.Set("sql", sql);
        
        int _req = m_db.Prepare(xp);
        if(_req == INVALID_HANDLE) return;
        
        while(::DatabaseRead(_req))
        {
            CXParam p; 
            p.msg_id = MSG_ENTRY_SIGNAL;
            p.db = m_db;
            p.time = xp.time; 
            p.signal_entry = new CXSignalEntry(); 
            CXSignalEntry* se = p.signal_entry;
            
            ::DatabaseColumnText(_req, 0, se.sid);
            ::DatabaseColumnText(_req, 1, se.symbol);
            ::DatabaseColumnInteger(_req, 2, se.dir);
            ::DatabaseColumnInteger(_req, 3, se.type);
            ::DatabaseColumnDouble(_req, 4, se.price_signal);
            ::DatabaseColumnDouble(_req, 5, se.lot);
            ::DatabaseColumnDouble(_req, 6, se.tp);
            ::DatabaseColumnDouble(_req, 7, se.sl);
            ::DatabaseColumnDouble(_req, 8, se.te_start);
            ::DatabaseColumnDouble(_req, 9, se.te_step);
            ::DatabaseColumnLong(_req, 10, (long&)se.magic);

            p.sid = se.sid; p.symbol = se.symbol; p.magic = se.magic;
            p.dir = (se.dir == 1) ? "BUY" : "SELL";
            p.type = (se.type == 1) ? "MARKET" : (se.type == 3 ? "STOP" : "LIMIT");
            
            ArrayResize(p.lots, 1); p.lots[0] = se.lot;
            ArrayResize(p.tps, 1);  p.tps[0] = se.tp;
            ArrayResize(p.sls, 1);  p.sls[0] = se.sl;
            
            // 로그 기록 및 메시지 전송
            Print(LogHeader("INFO", p.sid, "SCAN-HIT"), StringFormat("New Signal Detected. Sym:%s, Type:%s", p.symbol, p.type));
            CXMessageHub::Default(&p).Send(&p);
            
            // 상태를 Executing(1)로 변경하여 중복 발송 방지
            string update_sql = StringFormat("UPDATE entry_signals SET ea_status = 1, tag = 'Signal Sent', updated = datetime(%I64d, 'unixepoch') WHERE sid = '%s'", (long)xp.time, se.sid);
            xp.Set("sql", update_sql);
            m_db.Execute(xp);
        }
        ::DatabaseFinalize(_req);
    }

    // [Watchdog] 터미널에 이미 포지션이 있는데 DB가 Active(2)가 아닌 경우 동기화
    void SyncTerminalAssets(CXParam* xp)
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;

            string sid = PositionGetString(POSITION_COMMENT);
            if(sid == "") continue;

            // 터미널에는 있는데 DB 상태가 2(Active)가 아닌 경우 찾기
            string sql = StringFormat("SELECT ea_status FROM entry_signals WHERE sid = '%s' AND ea_status < 2", sid);
            xp.Set("sql", sql);
            
            int _req = m_db.Prepare(xp);
            if(_req != INVALID_HANDLE)
            {
                if(::DatabaseRead(_req))
                {
                    // 불일치 발견 -> Active(2)로 강제 동기화
                    Print(LogHeader("WARN", sid, "SYNC-CORRECT"), StringFormat("Position found in terminal but DB status is NOT Active. Syncing... Ticket:%I64u", ticket));
                    
                    string update_sql = StringFormat(
                        "UPDATE entry_signals SET ea_status = 2, tag = '[SYNC] Verified from Terminal', updated = datetime(%I64d, 'unixepoch') WHERE sid = '%s'", 
                        (long)TimeCurrent(), sid);
                    
                    ::DatabaseFinalize(_req); // Update 실행 전 핸들 해제
                    xp.Set("sql", update_sql);
                    m_db.Execute(xp);
                }
                else ::DatabaseFinalize(_req);
            }
        }
    }
};

#endif
