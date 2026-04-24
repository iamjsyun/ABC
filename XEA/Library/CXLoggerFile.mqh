//+------------------------------------------------------------------+
//|                                              CXLoggerFile.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//|                          [v1.0] Local File Logging (UTF-8)       |
//+------------------------------------------------------------------+
#ifndef CX_LOGGER_FILE_MQH
#define CX_LOGGER_FILE_MQH

#include "CXLogEntry.mqh"

class CXLoggerFile {
private:
    string m_filename;
    bool   m_enabled;

public:
    CXLoggerFile() : m_enabled(true) {
        m_filename = StringFormat("AXGS_%s.log", TimeToString(TimeCurrent(), TIME_DATE));
    }

    void SetEnabled(bool flag) { m_enabled = flag; }

    void SetPrefix(string prefix) {
        m_filename = StringFormat("%s_%s.log", prefix, TimeToString(TimeCurrent(), TIME_DATE));
    }

    void Reset() {
        if(FileIsExist(m_filename, FILE_COMMON)) {
            if(FileDelete(m_filename, FILE_COMMON)) {
                Print(">>> [Log System] Existing log file reset: " + m_filename);
            }
        }
    }

    void Write(CXLogEntry &entry) {
        if(!m_enabled) return;

        string timeStr = TimeToString(entry.time, TIME_DATE|TIME_SECONDS);
        string logMsg = StringFormat("[%s] [%s] %s %s", 
                                     timeStr, 
                                     entry.GetLevelString(), 
                                     (entry.sid != "" ? "[" + entry.sid + "]" : ""), 
                                     entry.msg);

        int handle = FileOpen(m_filename, FILE_WRITE|FILE_READ|FILE_BIN|FILE_COMMON);
        if(handle != INVALID_HANDLE) {
            FileSeek(handle, 0, SEEK_END);
            uchar array[];
            string fileLine = logMsg + "\r\n";
            StringToCharArray(fileLine, array, 0, WHOLE_ARRAY, CP_UTF8);
            FileWriteArray(handle, array, 0, ArraySize(array)-1);
            FileClose(handle);
        }
    }
};

#endif
