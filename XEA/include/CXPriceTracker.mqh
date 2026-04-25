//+------------------------------------------------------------------+
//|                                             CXPriceTracker.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_PRICE_TRACKER_MQH
#define CX_PRICE_TRACKER_MQH

#include <Object.mqh>

// [Utility] 고점, 저점 및 반전 거리를 정밀하게 추적하는 컴포넌트
class CXPriceTracker : public CObject
{
private:
    double          m_initial_price;
    double          m_highest;
    double          m_lowest;
    double          m_point;

public:
    CXPriceTracker() : m_initial_price(0), m_highest(0), m_lowest(0), m_point(0.00001) {}

    void Reset(double current_price, double point)
    {
        m_initial_price = current_price;
        m_highest = current_price;
        m_lowest = current_price;
        m_point = (point > 0) ? point : 0.00001;
    }

    // 새로운 가격 업데이트 및 고/저점 갱신
    void Update(double current_price)
    {
        if(m_highest == 0 || current_price > m_highest) m_highest = current_price;
        if(m_lowest == 0 || current_price < m_lowest) m_lowest = current_price;
    }

    // 기준가 대비 변동 거리 (Points)
    double GetTravelFromStart(double current_price) const
    {
        return MathAbs(current_price - m_initial_price) / m_point;
    }

    // 고점 대비 하락 거리 (Points)
    double GetPullback(double current_price) const
    {
        if(m_highest == 0) return 0;
        return (m_highest - current_price) / m_point;
    }

    // 저점 대비 상승 거리 (Points)
    double GetBounce(double current_price) const
    {
        if(m_lowest == 0) return 0;
        return (current_price - m_lowest) / m_point;
    }

    double Highest() const { return m_highest; }
    double Lowest()  const { return m_lowest; }
};

#endif
