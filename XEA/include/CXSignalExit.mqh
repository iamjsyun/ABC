//+------------------------------------------------------------------+
//|                                              CXSignalExit.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_SIGNAL_EXIT_MQH
#define CX_SIGNAL_EXIT_MQH

#include <Object.mqh>

class CXSignalExit : public CObject
{
public:
    string    sid;
    string    gid;
    ulong     magic;
    ulong     sno;
    ulong     gno;
    string    dir;
    datetime  time;

    CXSignalExit() : magic(0), sno(0), gno(0), time(0) {}
};

#endif
