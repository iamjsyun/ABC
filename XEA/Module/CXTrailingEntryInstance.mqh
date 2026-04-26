//+------------------------------------------------------------------+
//|                                     CXTrailingEntryInstance.mqh  |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_ENTRY_INSTANCE_MQH
#define CX_TRAILING_ENTRY_INSTANCE_MQH

#include "..\include\CXParam.mqh"
#include "..\include\CXDatabase.mqh"
#include "..\include\CXPriceTracker.mqh"
#include "..\include\CXLoggerUI.mqh"
#include <Trade\Trade.mqh>
#include <Object.mqh>

// [Module] 추적형 지정가 진입 실행기 (Trailing Limit Entry)
class CXTrailingEntryInstance : public CObject
{
private:
    string          m_sid;           
    ulong           m_magic;         
    bool            m_is_found;      
    double          m_te_start;      // 현재가와 Limit 오더 사이의 유지 거리 (pts)
    double          m_te_step;       // 추적 이동 단위 및 반등 진입 기준 (pts)
    double          m_te_limit;      // 최대 유리 이동 폭 (도달 시 즉시 진입) (pts)
    int             m_te_interval_sec;   
    datetime        m_last_interval_time; 
    
    bool            m_is_active;     
    CXPriceTracker  m_tracker;       // 최고/최저 및 시작가 추적기
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
    }
    
    string Sid() const { return m_sid; }

    void Process(CXParam* xp)
    {
        ulong ticket = xp.ticket;
        if(!OrderSelect(ticket)) return;
        
        string symbol = OrderGetString(ORDER_SYMBOL);
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double current_price = (type == ORDER_TYPE_BUY_LIMIT) ? current_ask : current_bid;

        // 1. 트래커 초기화 (최초 1회 시작가 고정)
        if(m_tracker.Highest() == 0) m_tracker.Reset(current_price, point);

        // 2. 최고점/최저점 실시간 업데이트
        m_tracker.Update(current_price);
        
        // 3. te_limit 도달 체크 (유리한 방향으로의 총 이동 거리)
        double total_travel = m_tracker.GetTravelFromStart(current_price);
        if(total_travel >= m_te_limit) {
            Print(LogHeader("INFO", "TRACKER-HIT"), StringFormat("te_limit reached (%.1f pts). Forcing Market Entry.", total_travel));
            ExecuteMarketConversion(xp, type, symbol, current_price);
            return;
        }

        // 4. te_step 반등 체크 (최고/최저점 대비 되돌림)
        double bounce = (type == ORDER_TYPE_BUY_LIMIT) ? m_tracker.GetBounce(current_ask) : m_tracker.GetPullback(current_bid);
        if(bounce >= m_te_step) {
            Print(LogHeader("INFO", "TRACKER-HIT"), StringFormat("Rebound detected (%.1f pts >= te_step). Entering Market.", bounce));
            ExecuteMarketConversion(xp, type, symbol, current_price);
            return;
        }

        // 5. 유리한 방향으로 이동 시 쫓아가기 (Chase)
        HandleChasing(xp, type, current_price, point);

        // [UI Log] p0 a 영역에 실시간 TE 정보 출력 (row_offset 1 사용)
        double order_p = OrderGetDouble(ORDER_PRICE_OPEN);
        double next_p = order_p + (m_te_step * point * (type == ORDER_TYPE_BUY_LIMIT ? 1 : -1));
        double bound_p = order_p + (m_te_limit * point * (type == ORDER_TYPE_BUY_LIMIT ? 1 : -1));
        string ui_msg = StringFormat("대기오더:%I64u, TE활성:true, Price:%.5f, Base:%.5f, Next:%.5f, Bound:%.5f",
                                     ticket, current_price, order_p, next_p, bound_p);
        XLoggerUI.LogSID(m_sid, 1, ui_msg);
    }

private:
    // [Action] 유리한 가격 변화 시 Limit 오더 수정
    void HandleChasing(CXParam* xp, ENUM_ORDER_TYPE type, double current, double point)
    {
        double order_p = OrderGetDouble(ORDER_PRICE_OPEN);
        double step_price = m_te_step * point;
        
        // 타겟 가격: 현재가 대비 te_start 거리 유지
        double target = (type == ORDER_TYPE_BUY_LIMIT) ? current - (m_te_start * point) : current + (m_te_start * point);
        
        bool should_move = false;
        if(type == ORDER_TYPE_BUY_LIMIT) {
            // 매수: 가격 하락 시 오더 하향 조정
            if(order_p > target + step_price) should_move = true;
        } else {
            // 매도: 가격 상승 시 오더 상향 조정
            if(order_p < target - step_price) should_move = true;
        }

        if(should_move) {
            Print(LogHeader("INFO", "TRACKER-HIT"), StringFormat("Chasing favorable move. Modify Limit: %.5f -> %.5f", order_p, target));
            ModifyOrder(xp, target);
        }
    }

    // [Action] 대기 오더 삭제 후 시장가 즉시 진입
    void ExecuteMarketConversion(CXParam* xp, ENUM_ORDER_TYPE type, string symbol, double price)
    {
        double vol = OrderGetDouble(ORDER_VOLUME_INITIAL);
        double sl = OrderGetDouble(ORDER_SL);
        double tp = OrderGetDouble(ORDER_TP);

        if(m_trade.OrderDelete(xp.ticket)) {
            bool success = false;
            if(type == ORDER_TYPE_BUY_LIMIT) success = m_trade.Buy(vol, symbol, 0, sl, tp, m_sid);
            else success = m_trade.Sell(vol, symbol, 0, sl, tp, m_sid);

            if(success) {
                Print(LogHeader("INFO", "ENTRY-OK"), StringFormat("Trailing Entry Success. Deal Ticket:%I64u", m_trade.ResultDeal()));
                UpdateEAStatus(xp, "2", "Trailing Entry OK");
                
                // [UI Log] 체결 시 UI 로그 소거
                XLoggerUI.ClearSID(m_sid);
            }
        }
    }

    void ModifyOrder(CXParam* xp, double new_price)
    {
        int digits = (int)SymbolInfoInteger(OrderGetString(ORDER_SYMBOL), SYMBOL_DIGITS);
        new_price = NormalizeDouble(new_price, digits);
        m_trade.OrderModify(xp.ticket, new_price, OrderGetDouble(ORDER_SL), OrderGetDouble(ORDER_TP), ORDER_TIME_GTC, 0);
    }

    void UpdateEAStatus(CXParam* xp, string status, string tag)
    {
        if(xp.db == NULL) return;
        xp.QB_Reset().Table("entry_signals").Where("sid", m_sid);
        xp.SetVal("ea_status", status, false).SetVal("tag", tag, true);
        xp.db.Execute(xp);
    }
};

#endif
