//+------------------------------------------------------------------+
//|                                     CXLimitOrderManager.mqh       |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_LIMIT_ORDER_MANAGER_MQH
#define CX_LIMIT_ORDER_MANAGER_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include <Trade\Trade.mqh>

// [Module] Limit Order Manager - 리미트 오더 접수 및 처리
class CXLimitOrderManager : public ICXReceiver
{
private:
    CTrade          m_trade;

public:
    CXLimitOrderManager() 
    {
        // 리미트 오더 요청 구독
        CXParam xp;
        xp.msg_id = MSG_LIMIT_ORDER_REQ;
        xp.receiver = &this;
        CXMessageHub::Default(&xp).Register(&xp);
    }

    virtual void OnReceiveMessage(CXParam* xp)
    {
        if(xp.msg_id != MSG_LIMIT_ORDER_REQ) return;

        CXSignalEntry* se = xp.signal_entry;
        if(se == NULL) return;

        // 실행을 위해 CXOrder 객체 생성 및 데이터 할당
        xp.order = new CXOrder();
        CXOrder* ord = xp.order;

        ord.magic      = se.magic;
        ord.symbol     = se.symbol;
        ord.price_open = se.price;
        ord.sl         = se.sl;
        ord.tp         = se.tp;
        ord.volume     = se.lot;
        ord.comment    = se.sid;
        ord.type       = (string)se.type;

        ExecuteLimitOrder(xp);
    }

private:
    void ExecuteLimitOrder(CXParam* xp)
    {
        CXOrder* ord = xp.order;
        CXSignalEntry* se = xp.signal_entry;
        if(ord == NULL || se == NULL) {
            Print("[XEA-ORD] Error: Order or SignalEntry is NULL");
            return;
        }

        PrintFormat("[XEA-ORD] >>> Start Order Process for SID: %s", ord.comment);

        MqlTick tick;
        if(!SymbolInfoTick(se.symbol, tick)) {
            string err_msg = StringFormat("SymbolInfoTick Failed for '%s'.", se.symbol);
            Print("[XEA-ORD] FATAL: ", err_msg); 
            if(xp.trace != NULL) xp.trace.LogLevel(L3_ORDER, "FAIL", err_msg);
            return;
        }

        // [Fix] 포인트 기반 SL/TP/Price 계산
        xp.CalculatePrices(tick);
        
        int symDigits = (int)SymbolInfoInteger(se.symbol, SYMBOL_DIGITS);
        ord.price_open = NormalizeDouble(xp.price, symDigits);
        ord.sl = (xp.sl_price > 0) ? NormalizeDouble(xp.sl_price, symDigits) : 0;
        ord.tp = (xp.tp_price > 0) ? NormalizeDouble(xp.tp_price, symDigits) : 0;

        PrintFormat("[XEA-ORD] REQ: %s %s | P:%.5f, V:%.2f, SL:%.5f, TP:%.5f", 
                    se.symbol, (se.dir == 1 ? "BUY_LIMIT" : "SELL_LIMIT"), ord.price_open, ord.volume, ord.sl, ord.tp);
        
        m_trade.SetExpertMagicNumber((int)ord.magic);
        
        bool success = false;
        ResetLastError();

        if(se.dir == 1)
            success = m_trade.BuyLimit(ord.volume, ord.price_open, se.symbol, ord.sl, ord.tp, ORDER_TIME_GTC, 0, ord.comment);
        else
            success = m_trade.SellLimit(ord.volume, ord.price_open, se.symbol, ord.sl, ord.tp, ORDER_TIME_GTC, 0, ord.comment);

        if(success)
        {
            xp.msg_id = MSG_ENTRY_CONFIRMED;
            xp.sid = ord.comment;
            xp.ticket = m_trade.ResultOrder();
            CXMessageHub::Default(xp).Send(xp);
            PrintFormat("[XEA-ORD] SUCCESS! Ticket: #%I64d", xp.ticket);
        }
        else
        {
            uint ret_code = m_trade.ResultRetcode();
            string ret_desc = m_trade.ResultRetcodeDescription();
            PrintFormat("[XEA-ORD] FAILED! RetCode: %u, Desc: %s, LastErr: %d", ret_code, ret_desc, GetLastError());
            
            // [Fix] 실패 상태 DB 반영 (ea_status=9)
            if(xp.db != NULL) {
                string sql = StringFormat("UPDATE entry_signals SET ea_status = 9, updated = DATETIME('now'), tag = 'Order Failed: %s' WHERE sid = '%s'", 
                                          ret_desc, ord.comment);
                xp.Set("sql", sql);
                xp.db.Execute(xp);
            }

            if(xp.trace != NULL) {
                xp.trace.LogLevel(L3_ORDER, "FAIL", StringFormat("RetCode:%d, Desc:%s", ret_code, ret_desc));
            }
        }
    }
};

#endif
