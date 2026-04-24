//+------------------------------------------------------------------+
//|                                             CXDefine.mqh         |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_DEFINE_MQH
#define CX_DEFINE_MQH

// --- [ Direction ] ---
#define DIR_BUY           1
#define DIR_SELL          2

// --- [ Order Type (otype/type) ] ---
#define TYPE_CLOSE        0
#define TYPE_MARKET       1
#define TYPE_LIMIT_M      2
#define TYPE_STOP         3
#define TYPE_LIMIT_P      4
#define TYPE_SHADOW       4

// --- [ EA Status (Feedback) ] ---
#define EA_READY          0
#define EA_EXECUTING      1
#define EA_ACTIVE         2
#define EA_PENDING        3
#define EA_CLOSED         4
#define EA_TRAILING       5
#define EA_ERROR          9

// --- [ XA Status (Lifecycle) ] ---
#define XA_RAW            0
#define XA_PARSED         1
#define XA_LIQUIDATION    2
#define XA_WAITING        3
#define XA_ACCEPTED       4
#define XA_REVOKE_REQ     5
#define XA_TERMINATED     6
#define XA_DROPPED        9

// --- [ Message Hub Events ] ---
#define MSG_MARKET_ORDER_REQ   1000   // 시장가 오더 접수 (추가)
#define MSG_LIMIT_ORDER_REQ    1001   // 리미트 오더 접수
#define MSG_STOP_ORDER_REQ     1005   // 스탑 오더 접수 (추가)
#define MSG_TRAILING_ENTRY_EVT 1002   // 트레일링 진입 관리
#define MSG_CLOSE_REQ          1003   // 청산 관리자 요청
#define MSG_TRAILING_CLOSE_EVT 1004   // 트레일링 청산 관리

#define MSG_ENTRY_SIGNAL       2001   // 진입 신호 감지
#define MSG_EXIT_SIGNAL        2002   // 청산 신호 감지
#define MSG_ENTRY_CONFIRMED    2005   // 진입 처리 완료 알림 (추가)
#define MSG_EXIT_CONFIRMED     2006   // 청산 처리 완료 알림 (추가)
#define MSG_PENDING_UPDATE     2003   // 대기 오더 상태 업데이트
#define MSG_POSITION_UPDATE    2004   // 포지션 상태 업데이트

#define MSG_LOG_EVENT          9001   // 로깅 이벤트

#endif
