//+------------------------------------------------------------------+
//|                                              CXDatabase.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 12:30:00 |
//+------------------------------------------------------------------+
#ifndef CX_DATABASE_MQH
#define CX_DATABASE_MQH

#include "CXParam.mqh"

// [Utility] SQLite Database Wrapper
class CXDatabase : public CObject
{
private:
    int             m_handle;
    string          m_db_name;

public:
    CXDatabase() : m_handle(INVALID_HANDLE), m_db_name("AXGS.db") {}
    ~CXDatabase() { CXParam xp; Close(&xp); }

    // 데이터베이스 열기 (MT5 Common Folder 사용)
    bool Open(CXParam* xp)
    {
        if(m_handle != INVALID_HANDLE) return true;
        
        m_handle = DatabaseOpen(m_db_name, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON);
        if(m_handle == INVALID_HANDLE)
        {
            PrintFormat("[DB-Err] Failed to open %s. Error: %d", m_db_name, GetLastError());
            return false;
        }
        return true;
    }

    void Close(CXParam* xp)
    {
        if(m_handle != INVALID_HANDLE)
        {
            DatabaseClose(m_handle);
            m_handle = INVALID_HANDLE;
        }
    }

    // 결과가 없는 쿼리 실행 (INSERT, UPDATE, DELETE)
    bool Execute(CXParam* xp)
    {
        if(!Open(xp)) return false;
        string sql = xp.Get("sql");
        if(!DatabaseExecute(m_handle, sql))
        {
            PrintFormat("[DB-Err] Execute Failed: %s. SQL: %s", GetLastError(), sql);
            return false;
        }
        return true;
    }

    // 결과가 있는 쿼리 준비
    int Prepare(CXParam* xp)
    {
        if(!Open(xp)) return INVALID_HANDLE;
        string sql = xp.Get("sql");
        int request = DatabasePrepare(m_handle, sql);
        if(request == INVALID_HANDLE)
        {
            PrintFormat("[DB-Err] Prepare Failed: %s. SQL: %s", GetLastError(), sql);
        }
        return request;
    }

    // 테이블 존재 확인 및 생성 (초기화용 - v15.1 Standard)
    void CheckSchema(CXParam* xp)
    {
        // 1. entry_signals 테이블 마이그레이션 체크
        xp.Set("sql", "SELECT sid, magic FROM entry_signals LIMIT 1");
        int req = Prepare(xp);
        if(req == INVALID_HANDLE) {
            Print("[DB-MIG] entry_signals schema mismatch. Recreating table...");
            xp.Set("sql", "DROP TABLE IF EXISTS entry_signals"); Execute(xp);
        } else {
            DatabaseFinalize(req);
        }

        // 테이블 생성 (v15.1)
        xp.Set("sql", "CREATE TABLE IF NOT EXISTS entry_signals ("
                "sid TEXT PRIMARY KEY, msg_id INTEGER, xa_status INTEGER DEFAULT 1, ea_status INTEGER DEFAULT 0, "
                "symbol TEXT, dir INTEGER, type INTEGER, price_signal REAL, offset REAL DEFAULT 100, "
                "te_start REAL DEFAULT 500, te_step REAL DEFAULT 100, te_limit REAL DEFAULT 1000, te_interval INTEGER DEFAULT 60, "
                "tp REAL, sl REAL, ts_start INTEGER, ts_step INTEGER, close_type INTEGER, "
                "trail_price REAL, price_limit REAL, price REAL, price_open REAL, price_close REAL, "
                "price_tp REAL, price_sl REAL, lot REAL, ticket INTEGER, magic INTEGER, comment TEXT, tag TEXT, "
                "created DATETIME DEFAULT (DATETIME('now')), updated DATETIME DEFAULT (DATETIME('now')))");
        Execute(xp);
                
        // 2. exit_signals 테이블
        xp.Set("sql", "CREATE TABLE IF NOT EXISTS exit_signals ("
                "time INTEGER, cno INTEGER, sno INTEGER, gno INTEGER, dir TEXT, ea_status INTEGER DEFAULT 0)");
        Execute(xp);

        // 3. trade_history 테이블
        xp.Set("sql", "CREATE TABLE IF NOT EXISTS trade_history ("
                "sid TEXT PRIMARY KEY, gid TEXT, time INTEGER, status TEXT, message TEXT, "
                "symbol TEXT, dir TEXT, lot REAL, price REAL, sl REAL, tp REAL)");
        Execute(xp);
    }

    int GetHandle(CXParam* xp) { return m_handle; }
};

#endif
