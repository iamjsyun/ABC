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

    void Run(CXParam* xp)
    {
        if(xp == NULL || xp.db == NULL) return;
        m_db = xp.db;

        // XEA 명칭 기준: entry_signals 테이블, te_ 필드 사용
        xp.Set("sql", "SELECT sid, symbol, dir, type, price_signal, lot, tp, sl, te_start, te_step, te_limit, te_interval, offset, msg_id, magic FROM entry_signals WHERE ea_status = 0 AND xa_status = 1");
        int req = m_db.Prepare(xp);
        if(req == INVALID_HANDLE) return;
        
        while(DatabaseRead(req))
        {
            CXParam p; 
            p.msg_id = MSG_ENTRY_SIGNAL;
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
            
            CXMessageHub::Default(&p).Send(&p);
            
            string update_sql = StringFormat("UPDATE entry_signals SET ea_status = 1, updated = DATETIME('now') WHERE sid = '%s'", se.sid);
            xp.Set("sql", update_sql);
            m_db.Execute(xp);
        }
        DatabaseFinalize(req);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_ENTRY_CONFIRMED || m_db == NULL) return;
        
        string sql = StringFormat("UPDATE entry_signals SET ea_status = 2, ticket = %I64d, updated = DATETIME('now') WHERE sid = '%s'", 
                                  xp.ticket, xp.sid);
        
        xp.Set("sql", sql);
        if(m_db.Execute(xp))
            Print("[SCAN-HIT] Signal Active: ", xp.sid);
    }
};

#endif
