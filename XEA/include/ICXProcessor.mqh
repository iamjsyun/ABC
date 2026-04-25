//+------------------------------------------------------------------+
//|                                              ICXProcessor.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef ICX_PROCESSOR_MQH
#define ICX_PROCESSOR_MQH

#include <Object.mqh>
#include "ICXReceiver.mqh"

// Forward declaration
class CXParam;

// [Interface] 서비스 생명주기 표준 (메시지 수신 기능 포함)
class ICXService : public ICXReceiver
{
public:
    virtual void OnTimer(CXParam* xp) = 0;
    virtual void OnReceiveMessage(CXParam* xp) {} // 기본 구현 제공
};

// [Interface] 대기 오더 도메인 처리 표준
class ICXTicketProcessor : public CObject
{
public:
    virtual void OnUpdate(CXParam* xp) = 0;
};

// [Interface] 보유 포지션 도메인 처리 표준
class ICXPositionProcessor : public CObject
{
public:
    virtual void OnUpdate(CXParam* xp) = 0;
};

#endif
