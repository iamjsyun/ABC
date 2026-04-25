//+------------------------------------------------------------------+
//|                                              CXLogService.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 12:05:00 |
//+------------------------------------------------------------------+
#ifndef CX_LOG_SERVICE_MQH
#define CX_LOG_SERVICE_MQH

#include "..\include\ICXReceiver.mqh"
#include "..\include\CXLogEntry.mqh"
#include "..\include\CXLoggerFile.mqh"
#include "..\include\CXLoggerUI.mqh"

// [Service] Log Service - 로그 분배기
class CXLogService : public ICXReceiver
{
private:
    CXLoggerFile*   m_file_logger;

public:
    CXLogService()
    {
        m_file_logger = new CXLoggerFile();
        m_file_logger.Reset(); // 기동 시 초기화
        
        // UI 초기화 (채널 4개, 빌드)
        XLoggerUI.Init(4).Build();
        
        // 로그 이벤트 구독
        CXParam p;
        p.msg_id = MSG_LOG_EVENT;
        p.receiver = &this;
        CXMessageHub::Default(&p).Register(&p);
    }

    ~CXLogService()
    {
        delete m_file_logger;
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp == NULL || xp.msg_id != MSG_LOG_EVENT) return;
        
        CXLogEntry* entry = dynamic_cast<CXLogEntry*>(xp.payload);
        if(entry == NULL) return;

        // 1. 파일 기록
        m_file_logger.Write(entry);
        
        // 2. UI 표시 (B존에 스크롤 로그 표시)
        string uiMsg = StringFormat("[%s] %s %s", entry.tag, entry.msg, entry.sid != "" ? "["+entry.sid+"]" : "");
        XLoggerUI.P(0).b().Output(uiMsg);

        // 3. 터미널 출력
        PrintFormat("[%s] %s %s", entry.tag, entry.msg, entry.sid != "" ? "["+entry.sid+"]" : "");

        delete entry;
    }
};

#endif
