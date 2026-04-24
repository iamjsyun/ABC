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
   string GetIP(CXParam* xp=NULL) const { return m_ip; }
   int GetPort(CXParam* xp=NULL) const { return m_port; }

   void Update(CXParam* xp) {
      datetime now = TimeLocal();
      if(now <= m_last_check_time) return;
      m_last_check_time = now;

      if(m_state == STATE_CONNECTED) {
         // Check physical connection status with retry logic
         if(!SocketIsConnected(m_handle)) {
            m_fail_count++;
            if(m_fail_count >= 3) {
               Print("[CXSocket] Connection lost detected (SocketIsConnected failed 3 times).");
               Disconnect(xp); 
               return; 
            }
         } else {
            m_fail_count = 0;
         }

         // Periodic Heartbeat
         if(now - m_last_send_time >= HEARTBEAT_INTERVAL) {
            xp.Set("data", "{\"type\":\"HEARTBEAT\"}\n");
            if(!this.Send(xp)) {
               // Log and retry later, don't disconnect immediately unless Send() detects fatal error
               Print("[CXSocket] Heartbeat send failed, will retry next time.");
               m_last_send_time = now; 
            }
         }
      }
      
      if(m_state == STATE_DISCONNECTED && m_ip != "") {
         if(now >= m_next_reconnect_time) {
            xp.Set("ip", m_ip); xp.Set("port", (string)m_port); xp.Set("timeout", (string)m_timeout_ms);
            Connect(xp);
         }
      }
   }

   bool Connect(CXParam* xp) {
      m_ip = xp.Get("ip"); m_port = (int)StringToInteger(xp.Get("port")); m_timeout_ms = (int)StringToInteger(xp.Get("timeout", "3000"));
      this.Disconnect(xp);
      m_handle = SocketCreate(SOCKET_DEFAULT);
      if(m_handle == INVALID_HANDLE) { SetNextReconnectTime(xp); return false; }
      m_state = STATE_CONNECTING;
      if(!SocketConnect(m_handle, m_ip, m_port, m_timeout_ms)) { Disconnect(xp); SetNextReconnectTime(xp); return false; }
      m_state = STATE_CONNECTED; m_reconnect_attempt = 0; m_fail_count = 0;
      m_last_send_time = TimeLocal(); m_last_recv_time = TimeLocal();
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
      if(sent > 0) {
         m_last_send_time = TimeLocal(); 
         return true;
      }
      
      int err = GetLastError();
      // Only disconnect if it's a fatal error (Socket closed)
      if(err == ERR_NET_SOCKET_CLOSED || err == 5270 || err == 5273) {
         PrintFormat("[CXSocket] Send error %d. Disconnecting.", err);
         Disconnect(xp);
      }
      return false;
   }

   // 疫꿸퀡????뤿뻿 ??λ땾: JSON ??뤿뻿 獄쎻뫗???????
   string Receive(CXParam* xp) {
      return Receive_Json(xp);
   }

   // 野꺜筌앹빖留?JSON ??뤿뻿 嚥≪뮇彛?
   string Receive_Json(CXParam* xp) {
      if(!this.IsConnected(xp)) return "";

      uint len = SocketIsReadable(m_handle);
      if(len > 0) {
         uchar buffer[];
         ArrayResize(buffer, len);
         int rev = SocketRead(m_handle, buffer, len, 10);

         if(rev > 0) {
            m_recv_buffer += CharArrayToString(buffer, 0, rev, CP_UTF8);
            m_last_recv_time = TimeLocal();
            if(StringLen(m_recv_buffer) > (int)MAX_BUFFER_SIZE) {
               Print("[CXSocket] Buffer Overflow! Clearing buffer.");
               m_recv_buffer = "";
            }
         }
         else if(rev < 0) {
            int err = GetLastError();
            if(err != ERR_NET_SOCKET_CLOSED) PrintFormat("[CXSocket] Read error: %d", err);
            this.Disconnect(xp);
            return "";
         }
      }

      int pos = StringFind(m_recv_buffer, "\n");
      if(pos < 0) {
         if(StringLen(m_recv_buffer) > 0 && (TimeLocal() - m_last_recv_time > 10)) {
            Print("[CXSocket] Incomplete packet timeout. Clearing buffer.");
            m_recv_buffer = "";
         }
         return "";
      }

      string line = StringSubstr(m_recv_buffer, 0, pos);
      m_recv_buffer = StringSubstr(m_recv_buffer, pos + 1);

      StringTrimLeft(line);
      StringTrimRight(line);

      int lineLen = StringLen(line);
      if(lineLen <= 2) return (m_recv_buffer != "") ? this.Receive_Json(xp) : "";

      // JSON ?類ㅻ뻼 筌ｋ똾寃?({ } 嚥?揶쏅Ŋ?????덈뮉筌왖)
      if(StringSubstr(line, 0, 1) == "{" && StringSubstr(line, lineLen - 1, 1) == "}") {
         return line;
      }

      // ?醫륁뒞??? ??? ??깆뵥?? 嚥≪뮄?뉒몴???ｋ┛????쇱벉 ??깆뵥 野꺜??
      PrintFormat("[CXSocket] Dropping invalid line: %s", line);
      return (m_recv_buffer != "") ? this.Receive_Json(xp) : "";
   }

   // 疫꿸퀣?????λ떄 CSV/揶쏆뮉六?疫꿸퀡而???뤿뻿 嚥≪뮇彛?(野꺜筌앹빘???醫?)
   string Receive_CSV(CXParam* xp) {
      if(!this.IsConnected(xp)) return "";
      uint len = SocketIsReadable(m_handle);
      if(len > 0) {
         uchar buffer[]; ArrayResize(buffer, len);
         int rev = SocketRead(m_handle, buffer, len, 10);
         if(rev > 0) {
            m_recv_buffer += CharArrayToString(buffer, 0, rev, CP_UTF8);
            m_last_recv_time = TimeLocal();
            if(StringLen(m_recv_buffer) > (int)MAX_BUFFER_SIZE) m_recv_buffer = "";
         } else if(rev < 0) { Disconnect(xp); return ""; }
      }
      
      int pos = StringFind(m_recv_buffer,"\n");
      if(pos < 0) return "";
      string line = StringSubstr(m_recv_buffer, 0, pos);
      m_recv_buffer = StringSubstr(m_recv_buffer, pos + 1);
      StringTrimLeft(line); StringTrimRight(line);
      return (StringLen(line) <= 2) ? "" : line;
   }

private:
   void SetNextReconnectTime(CXParam* xp) {
      m_reconnect_attempt++;
      int delay = (int)MathMin(60, 3 * MathPow(2, MathMin(4, m_reconnect_attempt - 1)));
      m_next_reconnect_time = TimeLocal() + delay;
   }
};

#endif


