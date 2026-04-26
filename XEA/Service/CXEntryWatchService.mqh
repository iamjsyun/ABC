//+------------------------------------------------------------------+
//|                                     CXEntryWatchService.mqh      |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_ENTRY_WATCH_SERVICE_MQH
#define CX_ENTRY_WATCH_SERVICE_MQH

#include "..\include\CXMessageHub.mqh"
#include "..\include\CXDefine.mqh"
#include "..\include\CXParam.mqh"
#include "..\include\CXDatabase.mqh"
#include "..\include\CXSignalEntry.mqh"
#include "..\include\ICXProcessor.mqh"

// [Service] 진입 신호 감시 및 터미널 자산 동기화 서비스
class CXEntryWatchService : public ICXService
{
private:
    CXDatabase*     m_db; 
    datetime        m_last_scan_time; // [v3.8] 마지막 스캔 시간 추적

    string LogHeader(string level, string sid, string tag) {
        return StringFormat("[%s] [%s] [%s] [%s] ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), level, sid, tag);
    }

public:
    CXEntryWatchService() : m_db(NULL), m_last_scan_time(0) {}

    void SetDatabase(CXDatabase* db) { m_db = db; }

    virtual void OnTimer(CXParam* xp)
    {
        if(xp == NULL || m_db == NULL) return;

        // [v3.8] 동적 재시도 주기 결정 (백테스트 전용)
        if(MQLInfoInteger(MQL_TESTER)) 
        {
            MqlDateTime dt; TimeCurrent(dt);
            int interval = (dt.hour < 9) ? 600 : 5; // 09:00 이전 10분(600초), 이후 5초

            if(TimeCurrent() - m_last_scan_time < interval) return;
            m_last_scan_time = TimeCurrent();
        }

        // 1. 새로운 진입 신호 스캔 및 전송
        ProcessScan(xp);

        // 2. 터미널 자산과 DB 상태 동기화 (Watchdog)
        SyncTerminalAssets(xp);
    }

private:
    // [Action] 신규 신호 인지 및 Manager에게 전송
    void ProcessScan(CXParam* xp)
    {
        // [v3.9] ea_status = 0 (Ready) 뿐만 아니라, 1 (Executing) 상태로 5분 이상 정체된 신호도 다시 스캔 대상에 포함
        string sql = "SELECT sid, symbol, dir, type, price_signal, lot, tp, sl, te_start, te_step, magic FROM entry_signals "
                     "WHERE (ea_status = 0 OR (ea_status = 1 AND updated < datetime('now', '-1 minute'))) AND xa_status = 1";
        xp.Set("sql", sql);
        
        int _req = m_db.Prepare(xp);
        if(_req == INVALID_HANDLE) return;
        
        while(::DatabaseRead(_req))
        {
            CXParam* p = CXParam::Acquire(); 
            p.msg_id = MSG_ENTRY_SIGNAL;
            p.db = m_db;
            p.time = xp.time; 
            p.signal_entry = new CXSignalEntry(); 
            CXSignalEntry* se = p.signal_entry;
            
            ::DatabaseColumnText(_req, 0, se.sid);
            ::DatabaseColumnText(_req, 1, se.symbol);
            ::DatabaseColumnInteger(_req, 2, se.dir);
            ::DatabaseColumnInteger(_req, 3, se.type);
            ::DatabaseColumnDouble(_req, 4, se.price_signal);
            ::DatabaseColumnDouble(_req, 5, se.lot);
            ::DatabaseColumnDouble(_req, 6, se.tp);
            ::DatabaseColumnDouble(_req, 7, se.sl);
            ::DatabaseColumnDouble(_req, 8, se.te_start);
            ::DatabaseColumnDouble(_req, 9, se.te_step);
            ::DatabaseColumnLong(_req, 10, (long&)se.magic);

            p.sid = se.sid; p.symbol = se.symbol; p.magic = se.magic;
            p.dir = (se.dir == 1) ? "BUY" : "SELL";
            
            // [v3.4] 모든 신호를 내부적으로 LIMIT으로 명명 (LimitManager가 처리하므로)
            p.type = "LIMIT"; 
            
            ArrayResize(p.lots, 1); p.lots[0] = se.lot;
            ArrayResize(p.tps, 1);  p.tps[0] = se.tp;
            ArrayResize(p.sls, 1);  p.sls[0] = se.sl;
            
            // 로그 기록 및 메시지 전송
            Print(LogHeader("INFO", p.sid, "SCAN-HIT"), StringFormat("New Signal Detected. Sym:%s, Type:%s", p.symbol, p.type));
            CXMessageHub::Default().Send(p);
            
            // 상태를 Executing(1)로 변경하여 중복 발송 방지
            string update_sql = StringFormat("UPDATE entry_signals SET ea_status = 1, tag = 'Signal Sent', updated = datetime(%I64d, 'unixepoch') WHERE sid = '%s'", (long)xp.time, se.sid);
            xp.Set("sql", update_sql);
            m_db.Execute(xp);

            CXParam::Release(p);
        }
        ::DatabaseFinalize(_req);
    }

    // [Watchdog] 터미널에 포지션 또는 대기 오더가 이미 존재하면 DB 신호 제거
    void SyncTerminalAssets(CXParam* xp)
    {
        // 1. 터미널 포지션 스캔
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            string sid = PositionGetString(POSITION_COMMENT);
            if(sid != "") RemoveSignalIfConfirmed(xp, sid, "Position", ticket);
        }

        // 2. 터미널 대기 오더 스캔 (추가)
        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);
            if(!OrderSelect(ticket)) continue;
            string sid = OrderGetString(ORDER_COMMENT);
            if(sid != "") RemoveSignalIfConfirmed(xp, sid, "Pending Order", ticket);
        }
    }

private:
    // [Action] 터미널 자산/오더 확인 시 DB 제거
    void RemoveSignalIfConfirmed(CXParam* xp, string sid, string type, ulong ticket)
    {
        string sql = StringFormat("SELECT sid FROM entry_signals WHERE sid = '%s'", sid);
        xp.Set("sql", sql);
        
        int _req = m_db.Prepare(xp);
        if(_req != INVALID_HANDLE)
        {
            if(::DatabaseRead(_req))
            {
                Print(LogHeader("INFO", sid, "SIGNAL-REMOVED"), StringFormat("[WATCHDOG] %s confirmed in terminal. Cleaning up signal. Ticket:%I64u", type, ticket));
                
                ::DatabaseFinalize(_req);
                string delete_sql = StringFormat("DELETE FROM entry_signals WHERE sid = '%s'", sid);
                xp.Set("sql", delete_sql);
                m_db.Execute(xp);
            }
            else ::DatabaseFinalize(_req);
        }
    }
};

#endif
