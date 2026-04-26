//+------------------------------------------------------------------+
//|                                              CXLogService.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_LOG_SERVICE_MQH
#define CX_LOG_SERVICE_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include "..\include\CXLoggerFile.mqh"
#include "..\include\CXLoggerUI.mqh"
#include "..\include\ICXReceiver.mqh"
#include "..\include\ICXProcessor.mqh"

// [Service] Logging Service - 파일 및 UI 로그 출력 전담
class CXLogService : public ICXService
{
private:
    CXLoggerFile*   m_file_logger;

public:
    CXLogService()
    {
        m_file_logger = new CXLoggerFile();
        
        // 로그 이벤트 구독
        CXParam p;
        p.msg_id = MSG_LOG_EVENT;
        p.receiver = (ICXReceiver*)GetPointer(this);
        CXMessageHub::Default().Register(&p);
    }

    ~CXLogService()
    {
        delete m_file_logger;
    }

    virtual void OnTimer(CXParam* xp) {}

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_LOG_EVENT) return;

        CXLogEntry* entry = xp.log_entry;
        if(entry == NULL) return;

        m_file_logger.Write(entry);
        string uiMsg = StringFormat("[%s] %s %s", entry.tag, entry.msg, entry.sid != "" ? "["+entry.sid+"]" : "");
        XLoggerUI.P(0).b().Output(uiMsg);
        PrintFormat("[%s] %s %s", entry.tag, entry.msg, entry.sid != "" ? "["+entry.sid+"]" : "");

        xp.log_entry = NULL;
        if(CheckPointer(entry) == POINTER_DYNAMIC) delete entry;
    }
};

#endif
