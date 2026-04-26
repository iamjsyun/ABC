//+------------------------------------------------------------------+
//|                                              CXDatabase.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
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
    CXDatabase() : m_handle(INVALID_HANDLE), m_db_name("ABC.db") {}
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

    // 결과가 없는 쿼리 실행 (INSERT, UPDATE, DELETE) - [v3.2] Retry 로직 추가
    bool Execute(CXParam* xp)
    {
        if(!Open(xp)) return false;
        string sql = xp.Get("sql");
        if(sql == "") return false;

        bool success = false;
        int  retry_count = 0;
        int  max_retries = 10;

        while(retry_count < max_retries)
        {
            ResetLastError();
            if(DatabaseExecute(m_handle, sql))
            {
                success = true;
                break;
            }

            int err = GetLastError();
            // 에러 코드 5105(ERR_DATABASE_EXECUTE) 발생 시 SQLite 에러 확인
            // 실제 SQLite BUSY 에러인 경우 재시도
            if(err == 5105 || err == 5101) 
            {
                retry_count++;
                Sleep(50 * retry_count); // 지수 백오프와 유사한 대기 (50ms, 100ms, 150ms...)
                continue;
            }
            
            PrintFormat("[DB-Err] Execute Failed: %d. SQL: %s", err, sql);
            break;
        }

        return success;
    }

    // 결과가 있는 쿼리 준비 - [v3.2] Retry 로직 추가
    int Prepare(CXParam* xp)
    {
        if(!Open(xp)) return INVALID_HANDLE;
        string sql = xp.Get("sql");
        if(sql == "") return INVALID_HANDLE;

        int request = INVALID_HANDLE;
        int retry_count = 0;
        int max_retries = 10;

        while(retry_count < max_retries)
        {
            ResetLastError();
            request = DatabasePrepare(m_handle, sql);
            if(request != INVALID_HANDLE) break;

            int err = GetLastError();
            if(err == 5105 || err == 5101)
            {
                retry_count++;
                Sleep(50 * retry_count);
                continue;
            }
            
            PrintFormat("[DB-Err] Prepare Failed: %d. SQL: %s", err, sql);
            break;
        }
        
        return request;
    }

    // 테이블 존재 확인 및 생성 (초기화용 - v16.3 Standard)
    void CheckSchema(CXParam* xp)
    {
        // 1. entry_signals 테이블 스키마 정합성 체크 (cno 컬럼 존재 확인)
        xp.Set("sql", "SELECT cno FROM entry_signals LIMIT 1");
        int req = Prepare(xp);
        if(req == INVALID_HANDLE) {
            Print("[DB-MIG] entry_signals schema mismatch (missing cno). Recreating table...");
            xp.Set("sql", "DROP TABLE IF EXISTS entry_signals"); Execute(xp);
        } else {
            ::DatabaseFinalize(req); // 글로벌 네임스페이스 사용
        }

        // ... (중략)
                
        // 2. exit_signals 테이블 스키마 정합성 체크
        xp.Set("sql", "SELECT cno FROM exit_signals LIMIT 1");
        req = Prepare(xp);
        if(req == INVALID_HANDLE) {
            Print("[DB-MIG] exit_signals schema mismatch (missing cno). Recreating table...");
            xp.Set("sql", "DROP TABLE IF EXISTS exit_signals"); Execute(xp);
        } else {
            ::DatabaseFinalize(req); // 글로벌 네임스페이스 사용
        }

        // 3. trade_history 테이블
        xp.Set("sql", "CREATE TABLE IF NOT EXISTS trade_history ("
                "sid TEXT PRIMARY KEY, gid TEXT, time INTEGER, status TEXT, message TEXT, "
                "symbol TEXT, dir TEXT, lot REAL, price REAL, sl REAL, tp REAL)");
        Execute(xp);
    }

    int GetHandle(CXParam* xp) { return m_handle; }
};

#endif
