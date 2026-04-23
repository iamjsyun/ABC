//+------------------------------------------------------------------+
//|                                             CXDefine.mqh         |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_DEFINE_MQH
#define CX_DEFINE_MQH

// --- [ Direction ] ---
#define DIR_BUY           1
#define DIR_SELL          2

// --- [ Order Type (otype/type) ] ---
#define TYPE_CLOSE        0
#define TYPE_MARKET       1
#define TYPE_LIMIT_M      2
#define TYPE_STOP         3
#define TYPE_LIMIT_P      4
#define TYPE_SHADOW       4

// --- [ EA Status (Feedback) ] ---
#define EA_READY          0
#define EA_EXECUTING      1
#define EA_ACTIVE         2
#define EA_PENDING        3
#define EA_CLOSED         4
#define EA_TRAILING       5
#define EA_ERROR          9

// --- [ XA Status (Lifecycle) ] ---
#define XA_RAW            0
#define XA_PARSED         1
#define XA_LIQUIDATION    2
#define XA_WAITING        3
#define XA_ACCEPTED       4
#define XA_REVOKE_REQ     5
#define XA_TERMINATED     6
#define XA_DROPPED        9

#endif
