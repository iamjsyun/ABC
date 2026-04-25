//+------------------------------------------------------------------+
//|                                     CXEntrySignalWatcher.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_ENTRY_SIGNAL_WATCHER_MQH
#define CX_ENTRY_SIGNAL_WATCHER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include "..\include\CXDatabase.mqh"
#include "..\include\CXSignalEntry.mqh"

/**
 * @class CXEntrySignalWatcher
 * @brief XEA 스키마 기준(entry_signals) 진입 신호 감시자
 */
class CXEntrySignalWatcher : public ICXReceiver
{
private:
    CXDatabase*     m_db;

public:
    CXEntrySignalWatcher() : m_db(NULL)
    {
        CXParam p; p.msg_id = MSG_ENTRY_CONFIRMED; p.receiver = GetPointer(this);
        CXMessageHub::Default(&p).Register(&p);
    }

    // 기동 시 정체되거나 에러난 신호 복구
    void StartupSync(CXParam* xp)
    {
        if(xp == NULL || xp.db == NULL) return;
        LOG_INFO("[SYNC]", "Syncing signals (ea_status=1,9 -> 0) for retry...");
        xp.Set("sql", "UPDATE entry_signals SET ea_status = 0 WHERE ea_status IN (1, 9)");
        xp.db.Execute(xp);
    }

    void Run(CXParam* xp)
    {
        if(xp == NULL || xp.db == NULL) return;
        m_db = xp.db;

        // [Fix] 백테스트 시간 제어 (오전 09:01:00 정각부터 처리 시작)
        if(MQLInfoInteger(MQL_TESTER)) {
            MqlDateTime dt;
            TimeCurrent(dt);
            if(dt.hour < 9 || (dt.hour == 9 && dt.min == 0)) {
                static datetime last_wait_log = 0;
                if(TimeCurrent() - last_wait_log >= 3600) {
                    PrintFormat("[XEA-WAIT] Backtest time is %02d:%02d. Waiting for 09:01...", dt.hour, dt.min);
                    last_wait_log = TimeCurrent();
                }
                return; 
            }
        }

        // [Fix] 백테스트 가상 시간(xp.time)을 기반으로 1분 재시도 주기 계산 (cno, magic 모두 조회)
        string sql = StringFormat(
            "SELECT sid, symbol, dir, type, price_signal, lot, tp, sl, te_start, te_step, te_limit, te_interval, offset, msg_id, magic, cno "
            "FROM entry_signals "
            "WHERE ea_status = 0 AND xa_status = 1 "
            "AND (tag NOT LIKE 'Waiting Market%%' OR %I64d - strftime('%%s', updated) >= 60)", 
            (long)xp.time
        );
        xp.Set("sql", sql);
        
        int req = m_db.Prepare(xp);
        if(req == INVALID_HANDLE) return;
        
        bool found = false;
        while(DatabaseRead(req))
        {
            found = true;
            CXParam p; 
            p.msg_id = MSG_ENTRY_SIGNAL;
            p.db = m_db;
            p.time = xp.time; 
            p.signal_entry = new CXSignalEntry(); 
            
            CXSignalEntry* se = p.signal_entry;
            
            DatabaseColumnText(req, 0, se.sid);
            DatabaseColumnText(req, 1, se.symbol);
            DatabaseColumnInteger(req, 2, se.dir);
            DatabaseColumnInteger(req, 3, se.type);
            DatabaseColumnDouble(req, 4, se.price_signal);
            DatabaseColumnDouble(req, 5, se.lot);
            DatabaseColumnDouble(req, 6, se.tp);
            DatabaseColumnDouble(req, 7, se.sl);
            DatabaseColumnDouble(req, 8, se.te_start);
            DatabaseColumnDouble(req, 9, se.te_step);
            DatabaseColumnDouble(req, 10, se.te_limit);
            DatabaseColumnInteger(req, 11, se.te_interval);
            DatabaseColumnDouble(req, 12, se.offset);
            DatabaseColumnInteger(req, 13, se.msg_id);
            DatabaseColumnLong(req, 14, se.magic);
            
            // cno 필드도 읽어서 보관
            long cno_val; DatabaseColumnLong(req, 15, cno_val);
            p.magic = (ulong)cno_val; // XEA 내부 로직 연동을 위해 magic에 cno 값 우선 할당

            p.sid = se.sid;
            p.symbol = se.symbol;
            p.dir = (se.dir == 1) ? "BUY" : "SELL";
            p.type = (se.type == 1) ? "MARKET" : "LIMIT";
            p.price = se.price_signal;
            
            ArrayResize(p.lots, 1); p.lots[0] = se.lot;
            ArrayResize(p.tps, 1);  p.tps[0] = se.tp;
            ArrayResize(p.sls, 1);  p.sls[0] = se.sl;
            ArrayResize(p.offsets, 1); p.offsets[0] = se.offset;
            
            LOG_SIGNAL("[SCAN-HIT]", StringFormat("New entry signal detected: %s", se.sid), se.sid);
            
            CXMessageHub::Default(&p).Send(&p);
            
            string update_sql = StringFormat("UPDATE entry_signals SET ea_status = 1, updated = datetime(%I64d, 'unixepoch') WHERE sid = '%s'", (long)xp.time, se.sid);
            xp.Set("sql", update_sql);
            m_db.Execute(xp);
        }
        DatabaseFinalize(req);

        // 신호가 없을 때의 로그 (1분 주기)
        if(!found) {
            static datetime last_scan_idle = 0;
            if(TimeCurrent() - last_scan_idle >= 60) {
                LOG_INFO("[SCAN-IDLE]", "Scanning entry_signals... 0 signals found.");
                last_scan_idle = TimeCurrent();
            }
        }
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_ENTRY_CONFIRMED || m_db == NULL) return;
        
        string sql = StringFormat("UPDATE entry_signals SET ea_status = 2, ticket = %I64d, updated = datetime(%I64d, 'unixepoch') WHERE sid = '%s'", 
                                  xp.ticket, (long)xp.time, xp.sid);
        
        xp.Set("sql", sql);
        if(m_db.Execute(xp)) {
            LOG_SIGNAL("[ENTRY-OK]", StringFormat("Signal Activated. Ticket: %I64d", xp.ticket), xp.sid);
        }
    }
};

#endif
