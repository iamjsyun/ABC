//+------------------------------------------------------------------+
//|                                             CXSignalEntry.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//| Last Modified: 2026-04-24 18:10:00                               |
//+------------------------------------------------------------------+
#ifndef CX_SIGNAL_ENTRY_MQH
#define CX_SIGNAL_ENTRY_MQH

#include <Object.mqh>

/**
 * @class CXSignalEntry
 * @brief XEA 스키마 기준 도메인 객체 (Source of Truth)
 */
class CXSignalEntry : public CObject
{
public:
    string    sid;
    int       msg_id;
    int       xa_status;
    int       ea_status;
    
    string    symbol;
    int       dir;
    int       type;
    
    double    price_signal;
    double    offset;
    double    lot;
    
    //-- XEA Standard Trailing Parameters (te_ prefix)
    double    te_start;      // Trailing Entry Start
    double    te_step;       // Trailing Entry Step
    double    te_limit;      // Trailing Entry Limit
    int       te_interval;   // Check Interval
    
    double    tp;
    double    sl;
    int       ts_start;
    int       ts_step;
    int       close_type;
    
    double    trail_price;
    double    price_limit;
    double    price;
    double    price_open;
    double    price_close;
    double    price_tp;
    double    price_sl;
    
    long      ticket;
    long      magic;
    string    comment;
    string    tag;
    
    datetime  created;
    datetime  updated;

    int       cno;
    int       sno;
    int       gno;

    CXSignalEntry() : sid(""), msg_id(0), xa_status(0), ea_status(0),
                      symbol(""), dir(0), type(0),
                      price_signal(0), offset(0), lot(0),
                      te_start(500), te_step(100), te_limit(1000), te_interval(60),
                      tp(0), sl(0), ts_start(0), ts_step(0), close_type(0),
                      trail_price(0), price_limit(0), price(0), 
                      price_open(0), price_close(0), price_tp(0), price_sl(0),
                      ticket(0), magic(0), comment(""), tag(""),
                      created(0), updated(0),
                      cno(0), sno(0), gno(0) {}
};

#endif
