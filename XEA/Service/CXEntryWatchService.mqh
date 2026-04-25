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

// [Service] 진입 신호 감시 전담 서비스
class CXEntryWatchService : public ICXService
{
private:
    CXDatabase*     m_db; 

public:
    CXEntryWatchService() : m_db(NULL) {}

    void SetDatabase(CXDatabase* db) { m_db = db; }

    virtual void OnTimer(CXParam* xp)
    {
        if(xp == NULL || m_db == NULL) return;
        ProcessScan(xp);
    }

private:
    void ProcessScan(CXParam* xp)
    {
        if(MQLInfoInteger(MQL_TESTER)) {
            MqlDateTime dt;
            TimeCurrent(dt);
            if(dt.hour < 9 || (dt.hour == 9 && dt.min == 0)) return; 
        }

        string sql = StringFormat(
            "SELECT sid, symbol, dir, type, price_signal, lot, tp, sl, te_start, te_step, te_limit, te_interval, offset, msg_id, magic, cno "
            "FROM entry_signals "
            "WHERE ea_status = 0 AND xa_status = 1 "
            "AND (tag NOT LIKE 'Waiting Market%%' OR %I64d - strftime('%%s', updated) >= 60)", 
            (long)xp.time
        );
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
            ::DatabaseColumnDouble(_req, 10, se.te_limit);
            ::DatabaseColumnInteger(_req, 11, se.te_interval);
            ::DatabaseColumnDouble(_req, 12, se.offset);
            ::DatabaseColumnInteger(_req, 13, se.msg_id);
            ::DatabaseColumnLong(_req, 14, se.magic);
            long _cno; ::DatabaseColumnLong(_req, 15, _cno);
            p.magic = (ulong)_cno;

            p.sid = se.sid; p.symbol = se.symbol;
            p.dir = (se.dir == 1) ? "BUY" : "SELL";
            p.type = (se.type == 1) ? "MARKET" : "LIMIT";
            p.price = se.price_signal;
            
            ArrayResize(p.lots, 1); p.lots[0] = se.lot;
            ArrayResize(p.tps, 1);  p.tps[0] = se.tp;
            ArrayResize(p.sls, 1);  p.sls[0] = se.sl;
            ArrayResize(p.offsets, 1); p.offsets[0] = se.offset;
            
            CXMessageHub::Default(&p).Send(&p);
            
            string update_sql = StringFormat("UPDATE entry_signals SET ea_status = 1, updated = datetime(%I64d, 'unixepoch') WHERE sid = '%s'", (long)xp.time, se.sid);
            xp.Set("sql", update_sql);
            m_db.Execute(xp);
        }
        ::DatabaseFinalize(_req);
    }
};

#endif
