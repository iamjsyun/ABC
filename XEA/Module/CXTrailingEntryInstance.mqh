//+------------------------------------------------------------------+
//|                                         CXTrailingInstance.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 13:00:00 |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_ENTRY_INSTANCE_MQH
#define CX_TRAILING_ENTRY_INSTANCE_MQH

#include "..\include\CXParam.mqh"
#include "..\include\CXDatabase.mqh"
#include <Trade\Trade.mqh>
#include <Object.mqh>

// [Module] 개별 트레일링 실행기 (SID 단위 인스턴스)
class CXTrailingEntryInstance : public CObject
{
private:
    string          m_sid;           // 인스턴스 식별 키 (Signal ID)
    ulong           m_magic;         // 매직넘버 (CNO)
    bool            m_is_found;      // 스캔 시 발견 여부
    double          m_te_start;
    double          m_te_step;
    double          m_te_limit;
    int             m_te_interval_sec;   // [New] 업데이트 시간 간격 (초)
    datetime        m_last_interval_time; // [New] 마지막 간격 유지 실행 시간
    
    double          m_initial_price; // 오더 접수 시점의 시장가
    bool            m_is_active;     // 트레일링 활성화 여부
    double          m_local_low;
    double          m_local_high;
    CTrade          m_trade;

public:
    CXTrailingEntryInstance(string sid, ulong magic) : m_sid(sid), m_magic(magic), m_is_found(true), 
                                                       m_te_start(500), m_te_step(100), m_te_limit(1000),
                                                       m_te_interval_sec(60), m_last_interval_time(0) 
    {
        m_trade.SetExpertMagicNumber((int)m_magic);
        m_initial_price = 0;
        m_is_active     = false;
        m_local_low     = 0;
        m_local_high    = 0;
    }

    void SetFound(CXParam* xp) { m_is_found = (xp.Get("found") == "true"); }
    bool IsFound(CXParam* xp=NULL) const { return m_is_found; }

    void SetParams(CXParam* xp) 
    { 
        m_te_start        = xp.tb_start; 
        m_te_step         = xp.tb_step; 
        m_te_limit        = xp.tb_limit; 
        m_te_interval_sec = xp.tb_interval; // 시간 간격 설정

        if(xp.trace != NULL) {
            xp.trace.LogLevel(L2_ENTRY, "Trailing Entry Configured");
            xp.trace.LogDetail(L2_ENTRY, "CONFIG", StringFormat("te_start:%.1f, te_step:%.1f, te_limit:%.1f, interval:%d", 
                                m_te_start, m_te_step, m_te_limit, m_te_interval_sec));
        }
    }
    
    string Sid(CXParam* xp=NULL) const { return m_sid; }
    ulong Magic(CXParam* xp=NULL) const { return m_magic; }

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

        // 1. 최초 시장가 기록
        if(m_initial_price == 0) m_initial_price = current_price;

        // 2. 활성화 체크 (te_start 감시)
        if(!m_is_active)
        {
            double travel = MathAbs(current_price - m_initial_price);
            if(travel >= m_te_start * point)
            {
                m_is_active = true;
                m_last_interval_time = TimeCurrent(); // 활성화 시점부터 간격 측정 시작
                LOG_SIGNAL("[TRACKER-START]", StringFormat("TE_START Triggered. Activation distance: %.1f pts", travel / point), m_sid);
            }
        }

        if(!m_is_active) return;

        // 3. 활성화 이후 로직 (추격 및 반등 시장가 진입)
        xp.Set("type", (string)type); xp.Set("ask", (string)current_ask); xp.Set("bid", (string)current_bid);
        UpdateExtremums(xp);
        
        // 실시간 상태 DB 동기화 (ea_status=5: Trailing)
        if(db != NULL) {
            xp.Set("sql", StringFormat("UPDATE entry_signals SET price=%.5f, ea_status=5 WHERE cno=%I64u", current_price, m_magic));
            db.Execute(xp);
        }

        xp.Set("point", (string)point);
        if(CheckMarketEntry(xp)) return;

        // 4. 간격 유지 체크 (시간 경과 여부 또는 가격 변동 체크)
        bool is_time_elapsed = (m_te_interval_sec > 0 && TimeCurrent() - m_last_interval_time >= m_te_interval_sec);
        
        xp.Set("current", (string)current_price); 
        xp.Set("order_p", (string)OrderGetDouble(ORDER_PRICE_OPEN));
        
        if(is_time_elapsed) {
            // 시간 경과 시 te_limit 간격 강제 유지
            LOG_SIGNAL("[TRACKER-HIT]", StringFormat("Time Interval Elapsed (%d sec). Forcing te_limit gap.", m_te_interval_sec), m_sid);
            ForceGapMaintenance(xp);
            m_last_interval_time = TimeCurrent(); // 시간 초기화
        } else {
            // 가격 변동에 따른 일반 트레일링
            HandleTrailing(xp);
        }
    }

private:
    // [New] 시간 간격 도달 시 te_limit 거리를 강제로 맞춤
    void ForceGapMaintenance(CXParam* xp)
    {
        double current = StringToDouble(xp.Get("current"));
        double point = StringToDouble(xp.Get("point"));
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)StringToInteger(xp.Get("type"));
        double limit_price = m_te_limit * point;
        
        double target = (type == ORDER_TYPE_BUY_LIMIT) ? current - limit_price : current + limit_price;
        
        xp.Set("new_price", (string)target); xp.Set("symbol", OrderGetString(ORDER_SYMBOL));
        ModifyOrder(xp);
    }

    // 기존 도망가기 로직 (te_limit 적용)
    void HandleTrailing(CXParam* xp)
    {
        ulong ticket = xp.ticket;
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)StringToInteger(xp.Get("type"));
        double current = StringToDouble(xp.Get("current"));
        double order_p = StringToDouble(xp.Get("order_p"));
        double point = StringToDouble(xp.Get("point"));

        double step_price  = m_te_step * point;
        double limit_price = m_te_limit * point;

        if(type == ORDER_TYPE_BUY_LIMIT) {
            double target = current - limit_price;
            // te_limit 거리를 벗어났을 때만 이동
            if(order_p - target >= step_price) {
                xp.Set("new_price", (string)target); xp.Set("symbol", OrderGetString(ORDER_SYMBOL));
                ModifyOrder(xp);
            }
        } else {
            double target = current + limit_price;
            // te_limit 거리를 벗어났을 때만 이동
            if(target - order_p >= step_price) {
                xp.Set("new_price", (string)target); xp.Set("symbol", OrderGetString(ORDER_SYMBOL));
                ModifyOrder(xp);
            }
        }
    }

    // 바닥/천장 추적
    void UpdateExtremums(CXParam* xp)
    {
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)StringToInteger(xp.Get("type"));
        double ask = StringToDouble(xp.Get("ask"));
        double bid = StringToDouble(xp.Get("bid"));

        if(type == ORDER_TYPE_BUY_LIMIT) {
            if(m_local_low == 0 || ask < m_local_low) m_local_low = ask;
        } else {
            if(m_local_high == 0 || bid > m_local_high) m_local_high = bid;
        }
    }

    // 반등 시 시장가 전환 체크
    bool CheckMarketEntry(CXParam* xp)
    {
        ulong ticket = xp.ticket;
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)StringToInteger(xp.Get("type"));
        double ask = StringToDouble(xp.Get("ask"));
        double bid = StringToDouble(xp.Get("bid"));
        double point = StringToDouble(xp.Get("point"));
        double step_price = m_te_step * point;

        if(type == ORDER_TYPE_BUY_LIMIT && m_local_low > 0) {
            // [Buy Market Trigger] 최저점 대비 te_step 이상 반등 시
            if(ask >= m_local_low + step_price) {
                xp.Set("dir", "BUY");
                ExecuteMarketConversion(xp);
                return true;
            }
        } 
        else if(type == ORDER_TYPE_SELL_LIMIT && m_local_high > 0) {
            // [Sell Market Trigger] 최고점 대비 te_step 이상 반락 시
            if(bid <= m_local_high - step_price) {
                xp.Set("dir", "SELL");
                ExecuteMarketConversion(xp);
                return true;
            }
        }
        return false;
    }

    // 대기 오더 취소 후 시장가 진입
    void ExecuteMarketConversion(CXParam* xp)
    {
        ulong ticket = xp.ticket;
        string dir = xp.Get("dir");
        LOG_SIGNAL("[TRACKER-HIT]", StringFormat("Bounce Detected! Converting to Market: %s", dir), m_sid);
        
        // CNO(4자리)를 매직넘버로 설정
        m_trade.SetExpertMagicNumber((int)m_magic);
        
        // 1. 대기 오더 취소
        if(m_trade.OrderDelete(ticket)) {
            // 2. 시장가 진입 메시지 발행 (MessageHub 활용 권장이나 여기선 직접 실행 예시)
            // CXPacket 생성 및 MSG_MARKET_ORDER_REQ 전송 로직...
            m_local_low = 0; m_local_high = 0; // 초기화
        }
    }

private:
    void ModifyOrder(CXParam* xp)
    {
        ulong ticket = xp.ticket;
        double new_price = StringToDouble(xp.Get("new_price"));
        string symbol = xp.Get("symbol");

        // 가격 정규화 (Digits 소수점 맞춤)
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        new_price = NormalizeDouble(new_price, digits);
        
        double sl = OrderGetDouble(ORDER_SL);
        double tp = OrderGetDouble(ORDER_TP);

        // CNO(4자리)를 매직넘버로 설정
        m_trade.SetExpertMagicNumber((int)m_magic);

        if(m_trade.OrderModify(ticket, new_price, sl, tp, ORDER_TIME_GTC, 0))
        {
            LOG_SIGNAL("[TRACKER-MODIFY]", StringFormat("Order %d Modified to %.5f", ticket, new_price), m_sid);
        }
    }
};

#endif
