//+------------------------------------------------------------------+
//|                                              ICXReceiver.mqh     |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef ICX_RECEIVER_MQH
#define ICX_RECEIVER_MQH

#include <Object.mqh>
#include "CXParam.mqh"

// [Interface] Message Receiver 
// CArrayObj 호환을 위해 CObject 상속 필수
class ICXReceiver : public CObject
{
public:
    virtual void OnReceiveMessage(CXParam* xp) = 0;
};

#endif
