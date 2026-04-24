//+------------------------------------------------------------------+
//|                                              ICXProcessor.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef ICX_PROCESSOR_MQH
#define ICX_PROCESSOR_MQH

#include <Object.mqh>
#include "CXDatabase.mqh"

#include "CXParam.mqh"

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
