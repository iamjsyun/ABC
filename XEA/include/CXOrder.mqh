//+------------------------------------------------------------------+
//|                                                   CXOrder.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_ORDER_MQH
#define CX_ORDER_MQH

#include <Object.mqh>

class CXOrder : public CObject
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

    CXOrder() : ticket(0), magic(0), volume(0), price_open(0), sl(0), tp(0) {}
};

#endif
