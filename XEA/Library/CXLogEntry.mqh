//+------------------------------------------------------------------+
//|                                              CXLogEntry.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 12:00:00 |
//+------------------------------------------------------------------+
#ifndef CX_LOG_ENTRY_MQH
#define CX_LOG_ENTRY_MQH

#include <Object.mqh>
#include "CXMessageHub.mqh"
#include "CXDefine.mqh"

// 로그 레벨 정의
enum ENUM_LOG_LEVEL { LOG_LVL_DEBUG, LOG_LVL_INFO, LOG_LVL_WARN, LOG_LVL_ERROR };

// [Data] 로그 전용 페이로더
class CXLogEntry : public CObject
{
public:
    ENUM_LOG_LEVEL  level;
    string          tag;      // [SCAN-HIT], [ENTRY-OK] 등
    string          msg;
    string          sid;      // Signal ID
    datetime        time;

    CXLogEntry(ENUM_LOG_LEVEL _lvl, string _tag, string _msg, string _sid="") 
        : level(_lvl), tag(_tag), msg(_msg), sid(_sid), time(TimeCurrent()) {}

    string GetLevelString() {
        switch(level) {
            case LOG_LVL_DEBUG: return "DEBUG";
            case LOG_LVL_INFO:  return "INFO";
            case LOG_LVL_WARN:  return "WARN";
            case LOG_LVL_ERROR: return "ERROR";
        }
        return "UNKNOWN";
    }
};

// --- [ Global Logging Macros ] ---
// 모든 클래스에서 include 후 즉시 사용 가능
#define LOG_DEBUG(tag, msg)      CXMessageHub::Default().Send(MSG_LOG_EVENT, new CXLogEntry(LOG_LVL_DEBUG, tag, msg))
#define LOG_INFO(tag, msg)       CXMessageHub::Default().Send(MSG_LOG_EVENT, new CXLogEntry(LOG_LVL_INFO, tag, msg))
#define LOG_WARN(tag, msg)       CXMessageHub::Default().Send(MSG_LOG_EVENT, new CXLogEntry(LOG_LVL_WARN, tag, msg))
#define LOG_ERROR(tag, msg)      CXMessageHub::Default().Send(MSG_LOG_EVENT, new CXLogEntry(LOG_LVL_ERROR, tag, msg))
#define LOG_SIGNAL(tag, msg, sid) CXMessageHub::Default().Send(MSG_LOG_EVENT, new CXLogEntry(LOG_LVL_INFO, tag, msg, sid))

#endif
