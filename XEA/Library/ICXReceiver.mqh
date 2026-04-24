//+------------------------------------------------------------------+
//|                                              ICXReceiver.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 10:00:00 |
//+------------------------------------------------------------------+
#ifndef ICX_RECEIVER_MQH
#define ICX_RECEIVER_MQH

#include <Object.mqh>

// [Interface] Message Receiver
// 모든 메시지 수신 클래스는 이 인터페이스를 상속받아야 함
class ICXReceiver
{
public:
    virtual void OnReceiveMessage(int msg_id, CObject* message) = 0;
};

#endif
