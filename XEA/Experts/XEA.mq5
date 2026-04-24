//+------------------------------------------------------------------+
//|                                                          XEA.mq5 |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 10:50:00 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Gemini CLI"
#property link      "https://github.com/iamjsyun/ABC"
#property version   "1.00"
#property strict

// Library
#include "../include/CXMessageHub.mqh"
#include "../include/CXDefine.mqh"
#include "../include/CXLogEntry.mqh"

#include "..\include\CXConfig.mqh"
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

    // 2. 외부 설정 파일 로드
    CXParam xp;
    CXConfig* config = new CXConfig("xea.json"); // MQL5\Files\xea.json
    if(config == NULL || config.TicketProcessors.Total() == 0) { // 파일 로드 실패 또는 내용이 비었을 경우
        Print("Failed to load or parse xea.json. Aborting.");
        return INIT_FAILED;
    }

    // 3. 설정에 따라 프로세서 동적 주입 (Dependency Injection)
    CXDBService* dbSvc = g_ea_service.GetDBService(&xp); // DB 서비스 포인터 가져오기

    // Ticket Processors 주입 (핵심 로직은 제외하고 기타 프로세서만 주입)
    for(int i=0; i<config.TicketProcessors.Total(); i++) {
        string name = config.TicketProcessors.At(i);
        // CXTrailingEntryManager 주입 로직 제거 (CXEAService 내부에서 직접 구동)
    }

    // Position Processors 주입
    for(int i=0; i<config.PositionProcessors.Total(); i++) {
        string name = config.PositionProcessors.At(i);
        // CXPositionManager 주입 로직 제거 (CXEAService 내부에서 직접 구동)
        if(name == "CXTrailingExitManager") {
            CXParam p_add; p_add.payload = new CXTrailingExitManager();
            dbSvc.AddPositionProcessor(&p_add);
        }
    }

    delete config;

    // 4. 타이머 시작
    EventSetTimer(1);
    LOG_INFO("[SYS]", "ABC System Initialized (External DI).");
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
