//+------------------------------------------------------------------+
//|                                             CXTradeTrace.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_TRADE_TRACE_MQH
#define CX_TRADE_TRACE_MQH

#include <Object.mqh>
#include "CXDefine.mqh"

// [Domain] 개별 SID의 전 생애주기를 트리뷰 형식으로 기록하는 클래스
class CXTradeTrace : public CObject
{
private:
    string  m_sid;
    int     m_handle;
    bool    m_is_tester;
    string  m_date_folder;

public:
    CXTradeTrace(string sid) : m_sid(sid), m_handle(INVALID_HANDLE)
    {
        m_is_tester = MQLInfoInteger(MQL_TESTER);
        m_date_folder = TimeToString(TimeLocal(), TIME_DATE);
        StringReplace(m_date_folder, ".", ""); // YYYYMMDD 형식
        
        OpenTraceFile();
    }

    ~CXTradeTrace()
    {
        if(m_handle != INVALID_HANDLE)
        {
            FileClose(m_handle);
            m_handle = INVALID_HANDLE;
        }
    }

    // 단계별 메인 로그 기록 (L1~L6)
    void LogLevel(ENUM_TRACE_LEVEL level, string title, string message = "")
    {
        if(m_handle == INVALID_HANDLE) return;

        string indent = GetIndent(level);
        string timeStr = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
        
        string logLine = StringFormat("[%s] %s [L%d] %s", timeStr, indent, (int)level, title);
        if(message != "") logLine += " | " + message;

        FileWrite(m_handle, logLine);
        FileFlush(m_handle); // 즉시 기록 (안정성 확보)
    }

    // 데이터 변동 이력 기록 (Market Price 포함)
    void LogVariable(ENUM_TRACE_LEVEL level, string var_name, double old_val, double new_val, double mkt_price = 0)
    {
        if(m_handle == INVALID_HANDLE) return;

        string indent = GetIndent(level) + "   ├─ ";
        string logLine;
        
        if(mkt_price > 0)
            logLine = StringFormat("[HIST] Mkt: %.5f -> %s: %.5f -> %.5f", mkt_price, var_name, old_val, new_val);
        else
            logLine = StringFormat("[DATA] %s: %.5f -> %.5f", var_name, old_val, new_val);

        FileWrite(m_handle, indent + logLine);
        FileFlush(m_handle);
    }

    // 상세 데이터 또는 속성 기록 (L1~L6 하위)
    void LogDetail(ENUM_TRACE_LEVEL level, string tag, string message)
    {
        if(m_handle == INVALID_HANDLE) return;

        string indent = GetIndent(level) + "   ├─ ";
        FileWrite(m_handle, indent + "[" + tag + "] " + message);
        FileFlush(m_handle);
    }

    // 최종 요약 및 파일 종료
    void LogSummary(string summary)
    {
        if(m_handle == INVALID_HANDLE) return;

        FileWrite(m_handle, "--------------------------------------------------------------------------------");
        FileWrite(m_handle, "[SUMMARY] " + summary);
        FileWrite(m_handle, "================================================================================");
        
        FileClose(m_handle);
        m_handle = INVALID_HANDLE;
    }

private:
    void OpenTraceFile()
    {
        // 경로 예시: ABC_Trace/20260425/1001-26042510-01-00-B-1.log
        string filePath = StringFormat("ABC_Trace\\%s\\%s.log", m_date_folder, m_sid);
        
        // FILE_COMMON을 사용하여 XTS 접근 허용 및 라이브/백테스트 통합 관리
        m_handle = FileOpen(filePath, FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI | FILE_SHARE_READ);
        
        if(m_handle != INVALID_HANDLE)
        {
            FileWrite(m_handle, "================================================================================");
            FileWrite(m_handle, "[TRACE] START - SID: " + m_sid);
            FileWrite(m_handle, "--------------------------------------------------------------------------------");
        }
        else
        {
            PrintFormat("[Trace] Error: Failed to open trace file %s. Error: %d", filePath, GetLastError());
        }
    }

    string GetIndent(ENUM_TRACE_LEVEL level)
    {
        string indent = "";
        for(int i = 1; i < (int)level; i++) indent += "   ";
        return indent + "└─ ";
    }
};

#endif
