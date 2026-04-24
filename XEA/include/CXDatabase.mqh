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

    // 테이블 존재 확인 및 생성 (초기화용)
    void CheckSchema(CXParam* xp)
    {
        xp.Set("sql", "CREATE TABLE IF NOT EXISTS entry_signals ("
                "time INTEGER, symbol TEXT, cno INTEGER, sno INTEGER, gno INTEGER, "
                "dir TEXT, type TEXT, sl REAL, tp REAL, price REAL, lot REAL, "
                "te_start REAL DEFAULT 500, te_step REAL DEFAULT 100, te_limit REAL DEFAULT 1000, te_interval INTEGER DEFAULT 60, "
                "ea_status INTEGER DEFAULT 0)");
        Execute(xp);
                
        xp.Set("sql", "CREATE TABLE IF NOT EXISTS exit_signals ("
                "time INTEGER, cno INTEGER, sno INTEGER, gno INTEGER, dir TEXT, ea_status INTEGER DEFAULT 0)");
        Execute(xp);

        // [New] trade_history table for lifecycle tracking
        xp.Set("sql", "CREATE TABLE IF NOT EXISTS trade_history ("
                "sid TEXT PRIMARY KEY, gid TEXT, time INTEGER, status TEXT, message TEXT, "
                "symbol TEXT, dir TEXT, lot REAL, price REAL, sl REAL, tp REAL)");
        Execute(xp);
    }

    int GetHandle(CXParam* xp) { return m_handle; }
};

#endif
