//+------------------------------------------------------------------+
//|                                         CXTrailingInstance.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 13:00:00 |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_INSTANCE_MQH
#define CX_TRAILING_INSTANCE_MQH

#include "..\Library\CXDefine.mqh"
#include <Trade\Trade.mqh>
#include <Object.mqh>

// [Module] 개별 트레일링 실행기 (cno 단위 인스턴스)
class CXTrailingInstance : public CObject
{
private:
    ulong           m_cno;
    double          m_te_start;
    double          m_te_step;
    double          m_te_limit;
    double          m_initial_price; // 오더 접수 시점의 시장가
    bool            m_is_active;     // 트레일링 활성화 여부
    double          m_local_low;
    double          m_local_high;
    CTrade          m_trade;

public:
    CXTrailingInstance(ulong cno) : m_cno(cno), m_te_start(500), m_te_step(100), m_te_limit(1000) 
    {
        m_trade.SetExpertMagicNumber(cno);
        m_initial_price = 0;
        m_is_active     = false;
        m_local_low     = 0;
        m_local_high    = 0;
    }

    void SetParams(double start, double step, double limit) 
    { 
        m_te_start = start; 
        m_te_step  = step; 
        m_te_limit = limit; 
    }
    
    ulong Cno() const { return m_cno; }

    void Process(ulong ticket)
    {
        if(!OrderSelect(ticket)) return;
        
        string symbol = OrderGetString(ORDER_SYMBOL);
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double current_price = (type == ORDER_TYPE_BUY_LIMIT) ? current_ask : current_bid;

        // 1. 최초 시장가 기록
        if(m_initial_price == 0) m_initial_price = current_price;

        // 2. 활성화 체크 (te_start 감시)
        if(!m_is_active)
        {
            double travel = MathAbs(current_price - m_initial_price);
            if(travel >= m_te_start * point)
            {
                m_is_active = true;
                PrintFormat("[Trailing-%d] TE_START Triggered. Activation distance: %.1f pts", m_cno, travel / point);
            }
            else return; // 활성화 전까지는 아무것도 하지 않음
        }

        // 3. 활성화 이후 로직 (추격 및 반등 시장가 진입)
        UpdateExtremums(type, current_ask, current_bid);
        
        if(CheckMarketEntry(ticket, type, current_ask, current_bid, point)) return;

        HandleTrailing(ticket, type, current_price, OrderGetDouble(ORDER_PRICE_OPEN), point);
    }

private:
    // 기존 도망가기 로직 (te_limit 적용)
    void HandleTrailing(ulong ticket, ENUM_ORDER_TYPE type, double current, double order_p, double point)
    {
        double step_price  = m_te_step * point;
        double limit_price = m_te_limit * point;

        if(type == ORDER_TYPE_BUY_LIMIT) {
            double target = current - limit_price;
            if(order_p - target >= step_price) ModifyOrder(ticket, target, OrderGetString(ORDER_SYMBOL));
        } else {
            double target = current + limit_price;
            if(target - order_p >= step_price) ModifyOrder(ticket, target, OrderGetString(ORDER_SYMBOL));
        }
    }

    // 바닥/천장 추적
    void UpdateExtremums(ENUM_ORDER_TYPE type, double ask, double bid)
    {
        if(type == ORDER_TYPE_BUY_LIMIT) {
            if(m_local_low == 0 || ask < m_local_low) m_local_low = ask;
        } else {
            if(m_local_high == 0 || bid > m_local_high) m_local_high = bid;
        }
    }

    // 반등 시 시장가 전환 체크
    bool CheckMarketEntry(ulong ticket, ENUM_ORDER_TYPE type, double ask, double bid, double point)
    {
        double step_price = m_te_step * point;

        if(type == ORDER_TYPE_BUY_LIMIT && m_local_low > 0) {
            // [Buy Market Trigger] 최저점 대비 te_step 이상 반등 시
            if(ask >= m_local_low + step_price) {
                ExecuteMarketConversion(ticket, "BUY");
                return true;
            }
        } 
        else if(type == ORDER_TYPE_SELL_LIMIT && m_local_high > 0) {
            // [Sell Market Trigger] 최고점 대비 te_step 이상 반락 시
            if(bid <= m_local_high - step_price) {
                ExecuteMarketConversion(ticket, "SELL");
                return true;
            }
        }
        return false;
    }

    // 대기 오더 취소 후 시장가 진입
    void ExecuteMarketConversion(ulong ticket, string dir)
    {
        PrintFormat("[Trailing-%d] Bounce Detected! Converting to Market: %s", m_cno, dir);
        
        // 1. 대기 오더 취소
        if(m_trade.OrderDelete(ticket)) {
            // 2. 시장가 진입 메시지 발행 (MessageHub 활용 권장이나 여기선 직접 실행 예시)
            // CXPacket 생성 및 MSG_MARKET_ORDER_REQ 전송 로직...
            m_local_low = 0; m_local_high = 0; // 초기화
        }
    }

private:
    void ModifyOrder(ulong ticket, double new_price, string symbol)
    {
        // 가격 정규화 (Digits 소수점 맞춤)
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        new_price = NormalizeDouble(new_price, digits);
        
        double sl = OrderGetDouble(ORDER_SL);
        double tp = OrderGetDouble(ORDER_TP);

        if(m_trade.OrderModify(ticket, new_price, sl, tp, ORDER_TIME_GTC, 0))
        {
            PrintFormat("[Trailing-%d] Order %d Modified to %.5f (Step: %.1f pts)", m_cno, ticket, new_price, m_te_step);
        }
    }
};

#endif
