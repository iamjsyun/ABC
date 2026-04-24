//+------------------------------------------------------------------+
//|                                            CXIndicator.mqh       |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_INDICATOR_MQH
#define CX_INDICATOR_MQH

#include "CXParam.mqh"

class CXIndicator
{
private:
    int m_h_adx;
    int m_h_ema20;
    int m_h_ema50;

public:
    CXIndicator() : m_h_adx(INVALID_HANDLE), m_h_ema20(INVALID_HANDLE), m_h_ema50(INVALID_HANDLE) {}
    ~CXIndicator() { CXParam xp; Release(&xp); }

    void Init(CXParam* xp)
    {
        string symbol = xp.symbol;
        m_h_adx   = iADX(symbol, PERIOD_M1, 14);
        m_h_ema20 = iMA(symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
        m_h_ema50 = iMA(symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
    }

    void Release(CXParam* xp)
    {
        if(m_h_adx != INVALID_HANDLE)   IndicatorRelease(m_h_adx);
        if(m_h_ema20 != INVALID_HANDLE) IndicatorRelease(m_h_ema20);
        if(m_h_ema50 != INVALID_HANDLE) IndicatorRelease(m_h_ema50);
        m_h_adx = m_h_ema20 = m_h_ema50 = INVALID_HANDLE;
    }

    // ADX & DI 분석 (M1)
    double GetADX(CXParam* xp)
    {
        double buf[1];
        if(CopyBuffer(m_h_adx, 0, 0, 1, buf) <= 0) return 0;
        double main = buf[0];
        CopyBuffer(m_h_adx, 1, 0, 1, buf); xp.Set("di_plus", DoubleToString(buf[0], 2));
        CopyBuffer(m_h_adx, 2, 0, 1, buf); xp.Set("di_minus", DoubleToString(buf[0], 2));
        return main;
    }

    // HTF 추세 분석 (H1 EMA Stack)
    // 1: Strong Bullish, -1: Strong Bearish, 0: Neutral
    int GetHTFTrend(CXParam* xp)
    {
        string symbol = xp.symbol;
        double p[1], e20[1], e50[1];
        if(CopyClose(symbol, PERIOD_H1, 0, 1, p) <= 0) return 0;
        if(CopyBuffer(m_h_ema20, 0, 0, 1, e20) <= 0) return 0;
        if(CopyBuffer(m_h_ema50, 0, 0, 1, e50) <= 0) return 0;

        if(p[0] > e20[0] && e20[0] > e50[0]) return 1;  // Bullish
        if(p[0] < e20[0] && e20[0] < e50[0]) return -1; // Bearish
        return 0;
    }
};

#endif
