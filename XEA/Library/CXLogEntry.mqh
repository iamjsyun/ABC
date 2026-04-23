//+------------------------------------------------------------------+
//|                                                   CXLogEntry.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_LOG_ENTRY_MQH
#define CX_LOG_ENTRY_MQH

#include <Object.mqh>

enum ENUM_LOG_LEVEL {
    LOG_LEVEL_TRACE,
    LOG_LEVEL_DEBUG,
    LOG_LEVEL_INFO,
    LOG_LEVEL_WARN,
    LOG_LEVEL_ERROR,
    LOG_LEVEL_FATAL
};

class CXLogEntry : public CObject {
public:
    datetime        Time;
    ENUM_LOG_LEVEL  Level;
    string          Gid;
    string          Message;
    
    // UI 전용 필드
    int             PanelIdx;
    string          Area;
    int             RowIdx;

    CXLogEntry(ENUM_LOG_LEVEL level, string gid, string msg) {
        Time = TimeCurrent();
        Level = level;
        Gid = gid;
        Message = msg;
        PanelIdx = 0;
        Area = "Default";
        RowIdx = 0;
    }

    // JSON 특수 문자 이스케이프 처리
    string EscapeJson(string txt) {
        string t = txt;
        StringReplace(t, "\\", "\\\\");
        StringReplace(t, "\"", "\\\"");
        StringReplace(t, "\n", "\\n");
        StringReplace(t, "\r", "\\r");
        StringReplace(t, "\t", "\\t");
        return t;
    }

    string ToJson() {
        return StringFormat("{\"time\":\"%s\",\"level\":\"%s\",\"gid\":\"%s\",\"msg\":\"%s\",\"panel\":%d,\"area\":\"%s\",\"row\":%d}\n", 
                            TimeToString(Time, TIME_DATE|TIME_SECONDS), 
                            GetLevelString(), 
                            Gid, 
                            EscapeJson(Message),
                            PanelIdx,
                            Area,
                            RowIdx);
    }
    
    string GetLevelString() {
        switch(this.Level) {
            case LOG_LEVEL_TRACE: return "TRACE";
            case LOG_LEVEL_DEBUG: return "DEBUG";
            case LOG_LEVEL_INFO:  return "INFO";
            case LOG_LEVEL_WARN:  return "WARN";
            case LOG_LEVEL_ERROR: return "ERROR";
            case LOG_LEVEL_FATAL: return "FATAL";
            default:              return "INFO";
        }
    }
};

#endif
