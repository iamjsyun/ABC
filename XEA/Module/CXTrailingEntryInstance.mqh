//+------------------------------------------------------------------+
//|                                     CXTrailingEntryInstance.mqh  |
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
    CXPriceTracker  m_tracker; 
    CTrade          m_trade;

    string LogHeader(string level, string tag) {
        return StringFormat("[%s] [%s] [%s] [%s] ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), level, m_sid, tag);
    }

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

        // 1. 활성화 체크 (REACH_BOUNDARY)
        if(!m_is_active)
        {
            if(m_tracker.GetTravelFromStart(current_price) >= m_te_start)
            {
                m_is_active = true;
                m_last_interval_time = TimeCurrent(); 
                
                // [v1.2 로그] 트레일링 활성화 상세 기록
                Print(LogHeader("INFO", "TRACKER-START"), StringFormat("Activated. TriggerDist:%.1f pts, StartPrice:%.5f, CurrPrice:%.5f", 
                      m_te_start, m_tracker.Highest(), current_price));

                UpdateEAStatus(xp, "5", "Trailing Active");
            }
        }

        if(!m_is_active) return;

        // 2. 최고점/최저점 업데이트
        m_tracker.Update(current_price);
        
        // 3. 실시간 상태 DB 동기화
        if(db != NULL) {
            xp.QB_Reset().Table("entry_signals").Where("sid", m_sid);
            xp.SetVal("price", DoubleToString(current_price, 5), false);
            xp.SetVal("ea_status", "5", false);
            xp.SetTime("updated", xp.time);
            xp.Set("sql", xp.BuildUpdate());
            db.Execute(xp);
        }

        // 4. 시장가 전환 체크 (MARKET_ENTRY_REV / Bounce)
        if(CheckMarketEntry(xp, type, symbol)) return;

        // 5. 간격 유지 및 이동 (MOVE_BOUNDARY / CHECK_STEP)
        HandleMovement(xp, type, current_price, point);
    }

private:
    void UpdateEAStatus(CXParam* xp, string status, string tag)
    {
        if(xp.db == NULL) return;
        xp.QB_Reset().Table("entry_signals").Where("sid", m_sid);
        xp.SetVal("ea_status", status, false).SetVal("tag", tag, true);
        xp.SetTime("updated", xp.time);
        xp.Set("sql", xp.BuildUpdate());
        xp.db.Execute(xp);
    }

    void HandleMovement(CXParam* xp, ENUM_ORDER_TYPE type, double current, double point)
    {
        double order_p = OrderGetDouble(ORDER_PRICE_OPEN);
        double step_price  = m_te_step * point;
        double limit_pts   = m_te_limit;
        double target = (type == ORDER_TYPE_BUY_LIMIT) ? current - (limit_pts * point) : current + (limit_pts * point);
        
        bool is_step_moved = false;
        if(type == ORDER_TYPE_BUY_LIMIT) {
            if(order_p - target >= step_price) is_step_moved = true;
        } else {
            if(target - order_p >= step_price) is_step_moved = true;
        }

        bool is_time_elapsed = (m_te_interval_sec > 0 && TimeCurrent() - m_last_interval_time >= m_te_interval_sec);

        if(is_step_moved || is_time_elapsed) {
            string reason = is_time_elapsed ? "INTERVAL" : "STEP";
            
            // [v1.2 로그] 이동 상세 기록 (Old -> New)
            Print(LogHeader("INFO", "TRACKER-HIT"), StringFormat("%s Move. Price:%.5f -> %.5f (Gap:%.1f pts)", 
                  reason, order_p, target, MathAbs(current - target)/point));
            
            ModifyOrder(xp, target);
            if(is_time_elapsed) m_last_interval_time = TimeCurrent(); 
        }
    }

    bool CheckMarketEntry(CXParam* xp, ENUM_ORDER_TYPE type, string symbol)
    {
        double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double bounce = (type == ORDER_TYPE_BUY_LIMIT) ? m_tracker.GetBounce(current_ask) : m_tracker.GetPullback(current_bid);

        if(bounce >= m_te_step) {
            double price = (type == ORDER_TYPE_BUY_LIMIT) ? current_ask : current_bid;
            
            // [v1.2 로그] 반전 감지 기록
            Print(LogHeader("INFO", "TRACKER-HIT"), StringFormat("Bounce Detected:%.1f pts. Converting to Market.", bounce));
            
            ExecuteMarketConversion(xp, type, symbol, price);
            return true;
        }
        return false;
    }

    void ExecuteMarketConversion(CXParam* xp, ENUM_ORDER_TYPE type, string symbol, double price)
    {
        double vol = OrderGetDouble(ORDER_VOLUME_INITIAL);
        double sl = OrderGetDouble(ORDER_SL);
        double tp = OrderGetDouble(ORDER_TP);

        // 1. 기존 대기 오더 삭제
        if(m_trade.OrderDelete(xp.ticket)) 
        {
            // 2. 시장가 즉시 진입
            bool success = false;
            if(type == ORDER_TYPE_BUY_LIMIT) success = m_trade.Buy(vol, symbol, price, sl, tp, m_sid);
            else success = m_trade.Sell(vol, symbol, price, sl, tp, m_sid);

            if(success) {
                // [v1.2 로그] 시장가 체결 성공
                Print(LogHeader("INFO", "ENTRY-OK"), StringFormat("Market Entry Success. Ticket:%d, Price:%.5f, Vol:%.2f", 
                      m_trade.ResultDeal(), price, vol));
                UpdateEAStatus(xp, "2", "Market Entered (TE)"); // 2: Active
            } else {
                Print(LogHeader("ERROR", "ENTRY-ERR"), StringFormat("Market Entry Failed. Code:%d, Desc:%s", 
                      m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()));
                UpdateEAStatus(xp, "9", "Conversion Error: " + m_trade.ResultRetcodeDescription());
            }
        }
    }

    void ModifyOrder(CXParam* xp, double new_price)
    {
        int digits = (int)SymbolInfoInteger(OrderGetString(ORDER_SYMBOL), SYMBOL_DIGITS);
        new_price = NormalizeDouble(new_price, digits);
        m_trade.OrderModify(xp.ticket, new_price, OrderGetDouble(ORDER_SL), OrderGetDouble(ORDER_TP), ORDER_TIME_GTC, 0);
    }
};

#endif
