//+------------------------------------------------------------------+
//|                                              ICXProcessor.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef ICX_PROCESSOR_MQH
#define ICX_PROCESSOR_MQH

#include <Object.mqh>
#include "CXDatabase.mqh"

// [Interface] 대기 오더 처리 표준
class ICXTicketProcessor : public CObject
{
public:
    virtual void ProcessTicket(ulong ticket, CXDatabase* db) = 0;
};

// [Interface] 보유 포지션 처리 표준
class ICXPositionProcessor : public CObject
{
public:
    virtual void ProcessPosition(ulong ticket, CXDatabase* db) = 0;
};

#endif
