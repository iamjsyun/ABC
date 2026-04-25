//+------------------------------------------------------------------+
//|                                     CXEntrySignalWatcher.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//| Last Modified: 2026-04-24 18:12:00                               |
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
        CXParam p; p.msg_id = MSG_ENTRY_CONFIRMED; p.receiver = &this;
        CXMessageHub::Default(&p).Register(&p);
    }

    // [New] 기동 시 정체된 신호 복구
    void StartupSync(CXParam* xp)
    {
        if(xp == NULL || xp.db == NULL) return;
        LOG_INFO("[SYNC]", "Syncing stuck signals (ea_status=1 -> 0)...");
        xp.Set("sql", "UPDATE entry_signals SET ea_status = 0 WHERE ea_status = 1");
        xp.db.Execute(xp);
    }

    void Run(CXParam* xp)
    {
        if(xp == NULL || xp.db == NULL) return;
        m_db = xp.db;

        // [Scan] 현재 대기 중인 신호 개수 확인
        xp.Set("sql", "SELECT COUNT(*) FROM entry_signals WHERE ea_status = 0 AND xa_status = 1");
        int count_req = m_db.Prepare(xp);
        int total = -1;
        if(count_req != INVALID_HANDLE) {
            if(DatabaseRead(count_req)) {
                DatabaseColumnInteger(count_req, 0, total);
            }
            DatabaseFinalize(count_req);
        } else {
            LOG_ERROR("[SCAN-ERR]", "Failed to prepare count query for entry_signals.");
            return;
        }

        // 신호가 없을 때도 로그 기록 (상태 확인용)
        if(total == 0) {
            // 매초 기록하면 파일이 너무 커지므로, 60초마다 또는 처음 1회 생존 보고
            static datetime last_scan_log = 0;
            if(TimeCurrent() - last_scan_log >= 60) {
                LOG_INFO("[SCAN-IDLE]", "Scanning entry_signals... 0 signals found (Waiting for XTS).");
                last_scan_log = TimeCurrent();
            }
            return; 
        }

        LOG_INFO("[SCAN-HIT]", StringFormat("Detected %d pending signals. Starting processing...", total));

        // XEA 명칭 기준: entry_signals 테이블, te_ 필드 사용
        xp.Set("sql", "SELECT sid, symbol, dir, type, price_signal, lot, tp, sl, te_start, te_step, te_limit, te_interval, offset, msg_id, magic FROM entry_signals WHERE ea_status = 0 AND xa_status = 1");
        int req = m_db.Prepare(xp);
        if(req == INVALID_HANDLE) return;
        
        while(DatabaseRead(req))
        {
            CXParam p; 
            p.msg_id = MSG_ENTRY_SIGNAL;
            p.db = m_db; // [Critical Fix] DB 포인터 전달
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

            p.sid = se.sid;
            p.symbol = se.symbol;
            p.magic = se.magic;
            
            // [Fix] CXParam의 문자열 필드 및 배열 보완 (CalculatePrices 연동용)
            p.dir = (se.dir == 1) ? "BUY" : "SELL";
            p.type = (se.type == 1) ? "MARKET" : "LIMIT";
            p.price = se.price_signal;
            
            ArrayResize(p.lots, 1); p.lots[0] = se.lot;
            ArrayResize(p.tps, 1);  p.tps[0] = se.tp;
            ArrayResize(p.sls, 1);  p.sls[0] = se.sl;
            ArrayResize(p.offsets, 1); p.offsets[0] = se.offset;
            
            LOG_SIGNAL("[SCAN-HIT]", StringFormat("New entry signal detected: %s (%s)", se.sid, se.symbol), se.sid);
            
            CXMessageHub::Default(&p).Send(&p);
            
            string update_sql = StringFormat("UPDATE entry_signals SET ea_status = 1, updated = DATETIME('now') WHERE sid = '%s'", se.sid);
            xp.Set("sql", update_sql);
            if(m_db.Execute(xp)) {
                LOG_SIGNAL("[SCAN-HIT]", "Status updated to EXECUTING(1) in DB", se.sid);
            }
        }
        DatabaseFinalize(req);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_ENTRY_CONFIRMED || m_db == NULL) return;
        
        string sql = StringFormat("UPDATE entry_signals SET ea_status = 2, ticket = %I64d, updated = DATETIME('now') WHERE sid = '%s'", 
                                  xp.ticket, xp.sid);
        
        xp.Set("sql", sql);
        if(m_db.Execute(xp)) {
            LOG_SIGNAL("[ENTRY-OK]", StringFormat("Signal Activated. Ticket: %I64d", xp.ticket), xp.sid);
        }
    }
};

#endif
