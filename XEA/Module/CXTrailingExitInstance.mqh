//+------------------------------------------------------------------+
//|                                         CXTrailingExitInstance.mqh|
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 15:00:00 |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_EXIT_INSTANCE_MQH
#define CX_TRAILING_EXIT_INSTANCE_MQH

#include "..\include\CXParam.mqh"
#include <Trade\Trade.mqh>
#include <Object.mqh>

// [Module] 개별 트레일링 청산 실행기 (cno 단위)
class CXTrailingExitInstance : public CObject
{
private:
    ulong           m_cno;
    double          m_ts_start;    // 활성화 수익 (pts)
    double          m_ts_step;     // 반락 폭 (pts)
    double          m_ts_limit;    // 유지 거리 (pts)
    
    double          m_highest;     // 매수 포지션 최고점
    double          m_lowest;      // 매도 포지션 최저점
    bool            m_is_active;   // 활성화 여부
    CTrade          m_trade;

public:
    CXTrailingExitInstance(ulong cno) : m_cno(cno), m_ts_start(500), m_ts_step(100), m_ts_limit(300) 
    {
        m_trade.SetExpertMagicNumber((int)cno);
        CXParam xp; Reset(&xp);
    }

    void Reset(CXParam* xp) { m_highest = 0; m_lowest = 0; m_is_active = false; }
    ulong Cno(CXParam* xp=NULL) const { return m_cno; }

    void Process(CXParam* xp)
    {
        ulong ticket = xp.ticket;
        if(!PositionSelectByTicket(ticket)) return;

        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

        // 1. 활성화 체크 (수익이 ts_start 이상일 때)
        if(!m_is_active)
        {
            double profit_pts = (type == POSITION_TYPE_BUY) ? (current_price - open_price) / point : (open_price - current_price) / point;
            if(profit_pts >= m_ts_start) {
                m_is_active = true;
                PrintFormat("[Trailing-Exit-%d] Activated. Profit: %.1f pts", m_cno, profit_pts);
            }
            else return;
        }

        // 2. 최고점/최저점 갱신 및 청산 트리거
        if(type == POSITION_TYPE_BUY)
        {
            if(m_highest == 0 || current_price > m_highest) m_highest = current_price;
            
            // 최고점 대비 ts_step 이상 반락 시 청산
            if(current_price <= m_highest - (m_ts_step * point)) {
                PrintFormat("[Trailing-Exit-%d] Buy Close Triggered. Pullback from %.5f", m_cno, m_highest);
                m_trade.SetExpertMagicNumber((int)m_cno);
                m_trade.PositionClose(ticket);
                Reset(xp);
            }
        }
        else // SELL Position
        {
            if(m_lowest == 0 || current_price < m_lowest) m_lowest = current_price;
            
            // 최저점 대비 ts_step 이상 반등 시 청산
            if(current_price >= m_lowest + (m_ts_step * point)) {
                PrintFormat("[Trailing-Exit-%d] Sell Close Triggered. Bounce from %.5f", m_cno, m_lowest);
                m_trade.SetExpertMagicNumber((int)m_cno);
                m_trade.PositionClose(ticket);
                Reset(xp);
            }
        }
    }
};

#endif
