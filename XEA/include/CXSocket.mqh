//+------------------------------------------------------------------+
//|                                                      CXSocket.mqh |
//|                                Copyright 2026, Gemini Adaptive  |
//+------------------------------------------------------------------+
#ifndef __X_SOCKET_MQH__
#define __X_SOCKET_MQH__

#ifndef ERR_NET_SOCKET_CLOSED
#define ERR_NET_SOCKET_CLOSED 5273
#endif

#include "CXParam.mqh"

enum ENUM_SOCKET_STATE { STATE_DISCONNECTED, STATE_CONNECTING, STATE_CONNECTED };

// [Utility] TCP 소켓 통신 라이브러리 (JSON 제거 버전)
class CXSocket {
private:
   int               m_handle;
   ENUM_SOCKET_STATE m_state;
   string            m_ip;
   int               m_port;
   int               m_timeout_ms;
   datetime          m_last_check_time, m_next_reconnect_time; 
   datetime          m_last_send_time, m_last_recv_time;      
   int               m_reconnect_attempt;   
   int               m_fail_count;          
   string            m_recv_buffer;
   const int         HEARTBEAT_INTERVAL;    
   const uint        MAX_BUFFER_SIZE;       

public:
   CXSocket() : m_handle(INVALID_HANDLE), m_state(STATE_DISCONNECTED), m_timeout_ms(3000),
                m_last_check_time(0), m_next_reconnect_time(0), m_last_send_time(0), m_last_recv_time(0),
                m_reconnect_attempt(0), m_fail_count(0), HEARTBEAT_INTERVAL(20), MAX_BUFFER_SIZE(1048576) {}

   virtual ~CXSocket() { CXParam xp; Disconnect(&xp); }

   void SetTarget(CXParam* xp) { m_ip = xp.Get("ip"); m_port = (int)StringToInteger(xp.Get("port")); m_timeout_ms = (int)StringToInteger(xp.Get("timeout", "3000")); }
   ENUM_SOCKET_STATE GetState(CXParam* xp=NULL) const { return m_state; }
   bool IsConnected(CXParam* xp=NULL) { return (m_state == STATE_CONNECTED && m_handle != INVALID_HANDLE); }

   void Update(CXParam* xp) {
      datetime now = TimeLocal();
      if(now <= m_last_check_time) return;
      m_last_check_time = now;

      if(m_state == STATE_CONNECTED) {
         if(!SocketIsConnected(m_handle)) {
            m_fail_count++;
            if(m_fail_count >= 3) { Disconnect(xp); return; }
         } else m_fail_count = 0;
      }
      
      if(m_state == STATE_DISCONNECTED && m_ip != "") {
         if(now >= m_next_reconnect_time) { Connect(xp); }
      }
   }

   bool Connect(CXParam* xp) {
      this.Disconnect(xp);
      m_handle = SocketCreate(SOCKET_DEFAULT);
      if(m_handle == INVALID_HANDLE) { SetNextReconnectTime(xp); return false; }
      m_state = STATE_CONNECTING;
      if(!SocketConnect(m_handle, m_ip, m_port, m_timeout_ms)) { Disconnect(xp); SetNextReconnectTime(xp); return false; }
      m_state = STATE_CONNECTED; m_reconnect_attempt = 0; m_fail_count = 0;
      return true;
   }

   void Disconnect(CXParam* xp) {
      if(m_handle != INVALID_HANDLE) { SocketClose(m_handle); m_handle = INVALID_HANDLE; }
      m_state = STATE_DISCONNECTED; m_recv_buffer = "";
   }

   bool Send(CXParam* xp) {
      if(!this.IsConnected(xp)) return false;
      string data = xp.Get("data");
      uchar buf[];
      int sz = StringToCharArray(data, buf, 0, -1, CP_UTF8);
      if(sz <= 1) return false;
      int sent = SocketSend(m_handle, buf, sz - 1);
      return (sent > 0);
   }

   // 데이터 수신 (라인 단위 텍스트 방식)
   string Receive(CXParam* xp) {
      if(!this.IsConnected(xp)) return "";
      uint len = SocketIsReadable(m_handle);
      if(len > 0) {
         uchar buffer[]; ArrayResize(buffer, len);
         int rev = SocketRead(m_handle, buffer, len, 10);
         if(rev > 0) {
            m_recv_buffer += CharArrayToString(buffer, 0, rev, CP_UTF8);
            m_last_recv_time = TimeLocal();
         }
      }
      
      int pos = StringFind(m_recv_buffer,"\n");
      if(pos < 0) return "";
      string line = StringSubstr(m_recv_buffer, 0, pos);
      m_recv_buffer = StringSubstr(m_recv_buffer, pos + 1);
      StringTrimLeft(line); StringTrimRight(line);
      return line;
   }

private:
   void SetNextReconnectTime(CXParam* xp) {
      m_reconnect_attempt++;
      m_next_reconnect_time = TimeLocal() + 10;
   }
};

#endif
