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

// 전역 Facade 객체
CXEAService* g_ea_service = NULL;

// CXParam 정적 멤버 정의 (Object Pooling)
CArrayObj* CXParam::m_pool = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // 1. Facade 서비스 생성
    g_ea_service = new CXEAService();
    if(CheckPointer(g_ea_service) == POINTER_INVALID) {
        Print("[XEA] Fatal: Failed to create CXEAService object.");
        return INIT_FAILED;
    }

    // 2. 타이머 시작 (1초 주기)
    EventSetTimer(1);
    
    Print("[XEA] System Bootstrapped. Waiting for first tick/timer...");
    LOG_INFO("[SYS]", "ABC System Initialized (Static Registration).");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(CheckPointer(g_ea_service) == POINTER_DYNAMIC)
        delete g_ea_service;

    // 객체 풀 자원 및 허브 해제
    CXMessageHub::Release();
    CXParam::DestroyPool();
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
        // [v3.1] Object Pooling 적용
        CXParam* xp = CXParam::Acquire();
        g_ea_service.OnTimer(xp);
        CXParam::Release(xp);
    }
}

//+------------------------------------------------------------------+
//| Trade Transaction function                                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
    if(CheckPointer(g_ea_service) == POINTER_DYNAMIC)
    {
        // [v3.1] Object Pooling 적용
        CXParam* xp = CXParam::Acquire();
        g_ea_service.OnTradeTransaction(xp, trans, request, result);
        CXParam::Release(xp);
    }
}
