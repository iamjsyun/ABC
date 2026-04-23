//+------------------------------------------------------------------+
//|                                              CXParam.mqh         |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-17 18:00:00 |
//+------------------------------------------------------------------+
#ifndef CX_PARAM_MQH
#define CX_PARAM_MQH

#include <Object.mqh>
#include <Arrays/ArrayString.mqh>

// [v11.x] Enhanced Data Bus for Strategies
class CXParam : public CObject
{
public:
    // Core Identity Fields
    string sid;
    string symbol;
    int    direction;       // 1: Buy, 2: Sell
    double ref_price;       // Reference price (e.g., G0 or Prev Price)
    double offset_pts;      // Current grid's required offset
    
    // [New] Strategy Interaction Fields
    int    strategy_no;     // From CXGridLevel
    string strategy_args;   // Comma-separated arguments (e.g., "14,30,70")
    double calculated_lot;  // Strategy can overwrite lot size
    
    // [v5.8] Tracker Payloader Fields
    ulong  ticket;          // Terminal Order/Deal Ticket
    int    tb_limit;        // Entry distance (pts)
    int    tb_start;        // Tracking activation threshold (pts)
    int    tb_step;         // Rebound check interval (pts)
    double target_price;    // Actual Order/Execution Price
    double sl_pts;          // Stop Loss (pts)
    double tp_pts;          // Take Profit (pts)
    
    // Extensible Data Storage
    CArrayString keys;
    CArrayString values;

    CXParam() : strategy_no(0), strategy_args(""), calculated_lot(0) {}
    ~CXParam() {}

    void Set(string key, string val) {
        int idx = FindKey(key);
        if(idx >= 0) values.Update(idx, val);
        else { keys.Add(key); values.Add(val); }
    }

    string Get(string key, string def_val = "") {
        int idx = FindKey(key);
        return (idx >= 0) ? values.At(idx) : def_val;
    }

    bool Has(string key) { return FindKey(key) >= 0; }
    void Remove(string key) {
        int idx = FindKey(key);
        if(idx >= 0) { keys.Delete(idx); values.Delete(idx); }
    }

    void Clear() { keys.Clear(); values.Clear(); strategy_args = ""; }

private:
    int FindKey(string key) {
        for(int i=0; i<keys.Total(); i++) {
            if(keys.At(i) == key) return i;
        }
        return -1;
    }
};

#endif
