//+------------------------------------------------------------------+
//|                                                CXPosition.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_POSITION_MQH
#define CX_POSITION_MQH

#include <Object.mqh>

class CXPosition : public CObject
{
public:
    ulong     ticket;
    ulong     magic;
    string    symbol;
    string    type;
    double    volume;
    double    price_open;
    double    sl;
    double    tp;
    string    comment;
    double    profit;
    double    swap;

    CXPosition() : ticket(0), magic(0), volume(0), price_open(0), sl(0), tp(0), profit(0), swap(0) {}
};

#endif
