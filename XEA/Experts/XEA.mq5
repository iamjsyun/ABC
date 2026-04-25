//+------------------------------------------------------------------+
//|                                                          XEA.mq5 |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini CLI"
#property link      "https://github.com/iamjsyun/ABC"
#property version   "1.00"
#property strict

// Library
#include "../include/CXMessageHub.mqh"
#include "../include/CXDefine.mqh"
#include "../include/CXLogEntry.mqh"

#include "..\Service\CXEAService.mqh"

// 의존성 주입을 위한 모듈 헤더
#include "..\Module\CXTrailingEntryManager.mqh"
#include "..\Module\CXPositionManager.mqh"
#include "..\Module\CXTrailingExitManager.mqh"

// 전역 Facade 객체
CXEAService* g_ea_service;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // 1. Facade 서비스 생성
    g_ea_service = new CXEAService();
    if(g_ea_service == NULL) {
        Print("[XEA] Fatal: Failed to create CXEAService object.");
        return INIT_FAILED;
    }

    // 2. [New] DB 동기화 실행 (기존 정체된 신호 ea_status=1 -> 0 복구)
    CXParam xp;
    CXDBService* dbSvc = g_ea_service.GetDBService(&xp);
    if(dbSvc != NULL) {
        xp.db = dbSvc.GetDB(&xp);
        // DB 서비스가 소유한 Watcher를 통해 싱크 (CXDBService::OnTimer 내부에서 수행되나 OnInit 시점에 강제 수행)
        dbSvc.OnTimer(&xp); 
    }

    // 3. 타이머 시작
    EventSetTimer(1);
    LOG_INFO("[SYS]", "ABC System Initialized (Static Registration).");
    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    delete g_ea_service;

    CXParam xp;
    CXMessageHub::Release(&xp);
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 모든 로직은 OnTimer에서 처리
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(CheckPointer(g_ea_service) == POINTER_DYNAMIC)
    {
        CXParam xp;
        g_ea_service.OnTimer(&xp);
    }
}
