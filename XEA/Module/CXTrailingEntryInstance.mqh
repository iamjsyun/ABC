//+------------------------------------------------------------------+
//|                                         CXTrailingInstance.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_ENTRY_INSTANCE_MQH
#define CX_TRAILING_ENTRY_INSTANCE_MQH

#include "..\include\CXParam.mqh"
#include "..\include\CXDatabase.mqh"
#include "..\include\CXPriceTracker.mqh"
#include <Trade\Trade.mqh>
#include <Object.mqh>

// [Module] 개별 트레일링 실행기 (SID 단위 인스턴스)
class CXTrailingEntryInstance : public CObject
{
private:
    string          m_sid;           
    ulong           m_magic;         
    bool            m_is_found;      
    double          m_te_start;
    double          m_te_step;
    double          m_te_limit;
    int             m_te_interval_sec;   
    datetime        m_last_interval_time; 
    
    bool            m_is_active;     
    CXPriceTracker  m_tracker; // 공통 가격 트래커
    CTrade          m_trade;

public:
    CXTrailingEntryInstance(string sid, ulong magic) : m_sid(sid), m_magic(magic), m_is_found(true), 
                                                       m_te_start(500), m_te_step(100), m_te_limit(1000),
                                                       m_te_interval_sec(60), m_last_interval_time(0) 
    {
        m_trade.SetExpertMagicNumber((int)m_magic);
        m_is_active = false;
    }

    void SetFound(CXParam* xp) { m_is_found = (xp.Get("found") == "true"); }
    bool IsFound() const { return m_is_found; }

    void SetParams(CXParam* xp) 
    { 
        m_te_start        = xp.tb_start; 
        m_te_step         = xp.tb_step; 
        m_te_limit        = xp.tb_limit; 
        m_te_interval_sec = xp.tb_interval; 

        if(xp.trace != NULL) {
            xp.trace.LogLevel(L2_ENTRY, "Trailing Entry Configured");
            xp.trace.LogDetail(L2_ENTRY, "CONFIG", StringFormat("te_start:%.1f, te_step:%.1f, te_limit:%.1f, interval:%d", 
                                m_te_start, m_te_step, m_te_limit, m_te_interval_sec));
        }
    }
    
    string Sid() const { return m_sid; }

    void Process(CXParam* xp)
    {
        ulong ticket = xp.ticket;
        CXDatabase* db = xp.db;
        if(!OrderSelect(ticket)) return;
        
        string symbol = OrderGetString(ORDER_SYMBOL);
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double current_price = (type == ORDER_TYPE_BUY_LIMIT) ? current_ask : current_bid;

        // 트래커 초기화
        if(m_tracker.Highest() == 0) m_tracker.Reset(current_price, point);

        // 1. 활성화 체크 (te_startpts 이상 변동 시)
        if(!m_is_active)
        {
            if(m_tracker.GetTravelFromStart(current_price) >= m_te_start)
            {
                m_is_active = true;
                m_last_interval_time = TimeCurrent(); 
                LOG_SIGNAL("[TRACKER-START]", StringFormat("TE_START Triggered for %s", m_sid), m_sid);
            }
        }

        if(!m_is_active) return;

        // 2. 최고점/최저점 업데이트
        m_tracker.Update(current_price);
        
        // 3. 실시간 상태 DB 동기화 (Query Builder 활용)
        if(db != NULL) {
            xp.QB_Reset().Table("entry_signals").Where("sid", m_sid);
            xp.SetVal("price", DoubleToString(current_price, 5), false);
            xp.SetVal("ea_status", "5", false);
            xp.SetTime("updated", xp.time);
            xp.Set("sql", xp.BuildUpdate());
            db.Execute(xp);
        }

        // 4. 시장가 전환 체크 (Bounce)
        xp.Set("point", (string)point);
        if(CheckMarketEntry(xp, type, current_ask, current_bid)) return;

        // 5. 간격 유지 체크
        bool is_time_elapsed = (m_te_interval_sec > 0 && TimeCurrent() - m_last_interval_time >= m_te_interval_sec);
        if(is_time_elapsed) {
            LOG_SIGNAL("[TRACKER-HIT]", "Time Interval Elapsed. Forcing gap.", m_sid);
            ForceGapMaintenance(xp, type, current_price, point);
            m_last_interval_time = TimeCurrent(); 
        } else {
            HandleTrailing(xp, type, current_price, point);
        }
    }

private:
    void ForceGapMaintenance(CXParam* xp, ENUM_ORDER_TYPE type, double current, double point)
    {
        double limit_price = m_te_limit * point;
        double target = (type == ORDER_TYPE_BUY_LIMIT) ? current - limit_price : current + limit_price;
        xp.Set("new_price", (string)target); xp.Set("symbol", OrderGetString(ORDER_SYMBOL));
        ModifyOrder(xp);
    }

    void HandleTrailing(CXParam* xp, ENUM_ORDER_TYPE type, double current, double point)
    {
        double order_p = OrderGetDouble(ORDER_PRICE_OPEN);
        double step_price  = m_te_step * point;
        double limit_price = m_te_limit * point;

        if(type == ORDER_TYPE_BUY_LIMIT) {
            double target = current - limit_price;
            if(order_p - target >= step_price) {
                xp.Set("new_price", (string)target); xp.Set("symbol", OrderGetString(ORDER_SYMBOL));
                ModifyOrder(xp);
            }
        } else {
            double target = current + limit_price;
            if(target - order_p >= step_price) {
                xp.Set("new_price", (string)target); xp.Set("symbol", OrderGetString(ORDER_SYMBOL));
                ModifyOrder(xp);
            }
        }
    }

    bool CheckMarketEntry(CXParam* xp, ENUM_ORDER_TYPE type, double ask, double bid)
    {
        if(type == ORDER_TYPE_BUY_LIMIT) {
            if(m_tracker.GetBounce(ask) >= m_te_step) {
                ExecuteMarketConversion(xp, "BUY"); return true;
            }
        } else {
            if(m_tracker.GetPullback(bid) >= m_te_step) {
                ExecuteMarketConversion(xp, "SELL"); return true;
            }
        }
        return false;
    }

    void ExecuteMarketConversion(CXParam* xp, string dr)
    {
        LOG_SIGNAL("[TRACKER-HIT]", StringFormat("Bounce/Pullback Detected! Converting: %s", dr), m_sid);
        if(m_trade.OrderDelete(xp.ticket)) {
            // 시장가 진입 로직 수행...
        }
    }

    void ModifyOrder(CXParam* xp)
    {
        double new_price = StringToDouble(xp.Get("new_price"));
        int digits = (int)SymbolInfoInteger(OrderGetString(ORDER_SYMBOL), SYMBOL_DIGITS);
        new_price = NormalizeDouble(new_price, digits);
        m_trade.OrderModify(xp.ticket, new_price, OrderGetDouble(ORDER_SL), OrderGetDouble(ORDER_TP), ORDER_TIME_GTC, 0);
    }
};

#endif
