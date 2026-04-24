//+------------------------------------------------------------------+
//|                                             CXRemoteLogger.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//|                    [v1.0] Remote Log Sender (log4net XML Format) |
//+------------------------------------------------------------------+
#ifndef CX_REMOTE_LOGGER_MQH
#define CX_REMOTE_LOGGER_MQH

#include <Arrays/ArrayObj.mqh>
#include "CXLogEntry.mqh"
#include "CXSocket.mqh"

// --- [ Remote Logger: log4net XML 포맷 지원 ] ---
class CXRemoteLogger : public CObject {
private:
    CXSocket     m_socket;
    CArrayObj    m_queue;
    bool         m_enabled;
    const int    MAX_QUEUE_SIZE;

public:
    CXRemoteLogger() : m_enabled(false), MAX_QUEUE_SIZE(1000) {}
    
    void Setup(string ip, int port) { 
        m_socket.SetTarget(ip, port); 
        m_enabled = true; 
    }
    
    void OnTimer() {
        if(!m_enabled) return;
        m_socket.Update();
        
        if(m_queue.Total() > 0 && m_socket.IsConnected()) {
            string batch = ""; 
            for(int i = 0; i < m_queue.Total(); i++) {
                CXLogEntry* entry = (CXLogEntry*)m_queue.At(i);
                if(entry != NULL) batch += ToLog4NetXml(entry);
            }
            if(m_socket.Send(batch)) m_queue.Clear();
        }
    }
    
    void QueueLog(CXLogEntry* entry) {
        if(!m_enabled) return;
        if(m_queue.Total() >= MAX_QUEUE_SIZE) m_queue.Detach(0);
        
        CXLogEntry* copy = new CXLogEntry(entry.Level, entry.Gid, entry.Message);
        copy.Time = entry.Time;
        m_queue.Add(copy);
    }

private:
    // log4viewer(log4net XML) 호환 포맷 생성
    string ToLog4NetXml(CXLogEntry* e) {
        string timestamp = TimeToString(e.Time, TIME_DATE|TIME_SECONDS);
        string levelStr = e.GetLevelString();
        
        // XML 특수문자 이스케이프
        string msg = e.Message;
        StringReplace(msg, "&", "&amp;");
        StringReplace(msg, "<", "&lt;");
        StringReplace(msg, ">", "&gt;");

        string xml = "<event logger=\"AXGS\" ";
        xml += "timestamp=\"" + timestamp + "\" ";
        xml += "level=\"" + levelStr + "\" thread=\"0\">\r\n";
        xml += "  <message>" + msg + "</message>\r\n";
        if(e.Gid != "") {
            xml += "  <properties>\r\n";
            xml += "    <data name=\"GID\" value=\"" + e.Gid + "\" />\r\n";
            xml += "  </properties>\r\n";
        }
        xml += "</event>\r\n";
        return xml;
    }
};

#endif
