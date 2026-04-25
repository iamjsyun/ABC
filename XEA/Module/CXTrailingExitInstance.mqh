//+------------------------------------------------------------------+
//|                                         CXTrailingExitInstance.mqh|
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_EXIT_INSTANCE_MQH
#define CX_TRAILING_EXIT_INSTANCE_MQH

#include "..\include\CXParam.mqh"
#include <Trade\Trade.mqh>
#include <Object.mqh>

// [Module] 개별 트레일링 청산 실행기 (SID 단위)
class CXTrailingExitInstance : public CObject
{
private:
    string          m_sid;
    ulong           m_magic;
    double          m_ts_start;    
    double          m_ts_step;     
    
    double          m_highest;     
    double          m_lowest;      
    bool            m_is_active;   
    bool            m_is_found;
    CTrade          m_trade;

public:
    CXTrailingExitInstance(string sid, ulong magic) : m_sid(sid), m_magic(magic), m_ts_start(500), m_ts_step(100) 
    {
        m_trade.SetExpertMagicNumber((int)magic);
        m_highest = 0; m_lowest = 0; m_is_active = false; m_is_found = true;
    }

    void SetParams(CXParam* xp) { m_ts_start = (double)xp.ts_start; m_ts_step = (double)xp.ts_step; }
    void SetFound(bool found) { m_is_found = found; }
    bool IsFound() const { return m_is_found; }
    string Sid() const { return m_sid; }

    void Process(CXParam* xp)
    {
        ulong ticket = xp.ticket;
        if(!PositionSelectByTicket(ticket)) return;

        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

        if(!m_is_active)
        {
            double profit_pts = (type == POSITION_TYPE_BUY) ? (current_price - open_price) / point : (open_price - current_price) / point;
            if(profit_pts >= m_ts_start) {
                m_is_active = true;
                LOG_SIGNAL("[TS-START]", StringFormat("Trailing Stop Activated for %s", m_sid), m_sid);
            }
            else return;
        }

        if(type == POSITION_TYPE_BUY)
        {
            if(m_highest == 0 || current_price > m_highest) m_highest = current_price;
            if(current_price <= m_highest - (m_ts_step * point)) {
                LOG_SIGNAL("[TS-HIT]", StringFormat("Buy Close by TS. Highest: %.5f", m_highest), m_sid);
                m_trade.PositionClose(ticket);
            }
        }
        else 
        {
            if(m_lowest == 0 || current_price < m_lowest) m_lowest = current_price;
            if(current_price >= m_lowest + (m_ts_step * point)) {
                LOG_SIGNAL("[TS-HIT]", StringFormat("Sell Close by TS. Lowest: %.5f", m_lowest), m_sid);
                m_trade.PositionClose(ticket);
            }
        }
    }
};

#endif
