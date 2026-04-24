# ABC Project - XEA 아키텍처 설계서 (v15.1)
**Last Modified: 2026-04-24 18:15:00**

## 1. 아키텍처 개요
본 시스템은 **XTS (C#)**와 **XEA (MQL5)**가 `AXGS.db` (SQLite)를 허브로 사용하는 **Hub Architecture**를 채택하고 있습니다. 모든 신호 처리와 상태 동기화는 데이터베이스를 통해 이루어지며, 본 설계서는 **XEA (MQL5)의 스키마 명칭을 표준(Source of Truth)**으로 정의합니다.

## 2. 최종 클래스 참조 관계도 (Unified CXParam 적용)
(중략: 기존 다이어그램 유지)

## 3. SQLite 데이터베이스 스키마 (v15.1 - XEA Standard)

### 3.1 `entry_signals` 테이블 (Active Signals)
신호 서버(XTS)에서 생성되어 EA(XEA)가 실행해야 할 활성 신호를 관리합니다. XEA의 `CXSignalEntry` 및 XTS의 `XpoSignal.cs`와 1:1 대응합니다.

| Field | Type | Description | XEA Mapping |
| :--- | :--- | :--- | :--- |
| **sid** | TEXT(50) | **Primary Key.** Signal ID (v2.9 규격 준수) | sid |
| **msg_id** | INTEGER | 텔레그램 메시지 ID 등 원본 식별자 | msg_id |
| **xa_status** | INTEGER | Lifecycle Status (1:Accepted, 2:Liquidation, 6:Terminated) | xa_status |
| **ea_status** | INTEGER | Feedback Status (0:Ready, 1:Executing, 2:Active, 4:Closed, 5:Trailing, 9:Error) | ea_status |
| **symbol** | TEXT(20) | 거래 종목 (예: EURUSD, GOLD) | symbol |
| **dir** | INTEGER | 방향 (1: Buy, -1: Sell) | dir |
| **type** | INTEGER | 주문 타입 (1: Market, 2: Limit_M, 4: Limit_P) | type |
| **price_signal** | REAL | 원본 신호 가격 | price_signal |
| **offset** | REAL | 진입 허용 오차 (Points) | offset |
| **te_start** | REAL | Trailing Entry 시작 조건 (Points) | te_start |
| **te_step** | REAL | Trailing Entry 이동 간격 (Points) | te_step |
| **te_limit** | REAL | Trailing Entry 최대 한도 (Points) | te_limit |
| **te_interval** | INTEGER | Trailing Entry 체크 주기 (Seconds) | te_interval |
| **tp** | REAL | Take Profit 목표 (Points) | tp |
| **sl** | REAL | Stop Loss 목표 (Points) | sl |
| **ts_start** | INTEGER | Trailing Stop 시작 조건 (Points) | ts_start |
| **ts_step** | INTEGER | Trailing Stop 이동 간격 (Points) | ts_step |
| **close_type** | INTEGER | 청산 방식 (0: Immediate, 1: Signal) | close_type |
| **trail_price** | REAL | 현재 진행 중인 트레일링 가격 | trail_price |
| **price_limit** | REAL | EA가 진입을 위해 설정한 대기 가격 ($P_{start}$) | price_limit |
| **price** | REAL | 최종 진입 목표 가격 ($P_{final}$) | price |
| **price_open** | REAL | 실제 체결 가격 | price_open |
| **price_close** | REAL | 실제 청산 가격 | price_close |
| **price_tp** | REAL | 실제 TP 적용 가격 | price_tp |
| **price_sl** | REAL | 실제 SL 적용 가격 | price_sl |
| **lot** | REAL | 거래 수량 (Volume) | lot |
| **ticket** | INTEGER | MT5 Position/Order Ticket | ticket |
| **magic** | INTEGER | EA Magic Number | magic |
| **comment** | TEXT(255) | SID가 주입된 MT5 Comment | comment |
| **tag** | TEXT(100) | 사용자 정의 태그 | tag |
| **created** | DATETIME | 신호 생성 일시 | created |
| **updated** | DATETIME | 신호 최종 갱신 일시 | updated |

### 3.2 `signal_history` 테이블 (Archived Signals)
종료된 신호를 보관하며 `archived_at` 필드가 추가된 구조입니다.

## 4. 핵심 설계 원칙 (v15.1)

    subgraph "Core Engine (Singleton/Facade)"
        EA[XEA.mq5] -- "Calls OnTimer" --> FACADE[CXEAService]
        FACADE -- "Owns" --> SVC_DB[CXDBService]
        FACADE -- "Directly Runs" --> MGR_T_ENT[CXTrailingEntryManager]
        FACADE -- "Directly Runs" --> MGR_POS[CXPositionManager]
    end

    subgraph "Unified Data Bus"
        XP((CXParam))
        XP -- "Contains" --> SE[CXSignalEntry]
        XP -- "Contains" --> SX[CXSignalExit]
        XP -- "Contains" --> ORD[CXOrder]
        XP -- "Contains" --> POS[CXPosition]
    end

    subgraph "Order Execution Modules"
        FACADE -- "Routes via Hub" --> HUB((CXMessageHub))
        HUB -- "Dispatches to" --> EXEC_LIMIT[CXLimitOrderManager]
        HUB -- "Dispatches to" --> EXEC_STOP[CXStopOrderManager]
        HUB -- "Dispatches to" --> EXEC_MARKET[CXMarketOrderManager]
        HUB -- "Dispatches to" --> EXEC_CLOSE[CXCloseManager]
    end

    subgraph "Signal Watchers"
        SVC_DB -- "Manages" --> WATCH_ENT[CXEntrySignalWatcher]
        SVC_DB -- "Manages" --> WATCH_EXT[CXExitSignalWatcher]
    end

    %% All functions use XP
    FACADE -. "Always passes CXParam*" .-> XP
    WATCH_ENT -. "Always passes CXParam*" .-> XP
    MGR_T_ENT -. "Always passes CXParam*" .-> XP
```

## 3. 핵심 설계 원칙 (v14.0)

### 3.1 Single Parameter Standard (CXParam)
- **원칙:** 프로젝트 내 모든 비즈니스 로직 함수는 `CXParam* xp` 단 하나의 파라미터만을 사용합니다.
- **구조:** `CXParam`은 단순한 변수 전달을 넘어, 전문 도메인 객체(`CXSignalEntry`, `CXSignalExit`, `CXOrder`, `CXPosition`)를 포함하는 **복합 페이로드(Composition Payload)** 역할을 수행합니다.
- **효과:** 함수 시그니처의 변경 없이 데이터 구조를 확장할 수 있으며, 호출 규격이 통일되어 유지보수가 용이합니다.

### 3.2 도메인 주권 및 독자 구동 (Domain Sovereignty)
- **핵심 엔진:** `CXTrailingEntryManager`와 `CXPositionManager`는 더 이상 `CXDBService`에 종속된 프로세서가 아닙니다. `CXEAService`에서 직접 소유하며 독자적인 스캔 루프를 가집니다.
- **터미널 중심:** DB 상태와 무관하게 **터미널(Orders/Positions)**을 진실의 근원으로 삼아 실시간 로직을 수행하며, 필요한 정보만 DB에 선택적으로 동기화합니다.

### 3.3 CXPacket 통합
- 기존의 데이터 전송 객체인 `CXPacket`은 `CXParam`으로 완전히 흡수 통합되었습니다. JSON 파싱 및 가격 계산 로직은 이제 `CXParam` 내부에서 수행됩니다.

## 4. 데이터 흐름 및 트레이딩 로직

### 4.1 데이터 흐름
1. **신호 감지**: `CXEntrySignalWatcher`가 DB 스캔 → `CXSignalEntry` 생성 → `MessageHub` 전송.
2. **실행**: `CXEAService` 수신 후 전담 `Manager`에게 라우팅 → `CXParam`을 통한 인자 전달 → 터미널 주문.
3. **피드백**: 주문 성공 시 `MSG_ENTRY_CONFIRMED` 발행 → `Watcher`가 수신하여 DB 레코드 즉시 삭제.

### 4.2 전문 도메인 객체
- **CXSignalEntry**: 진입 신호(SID, Price, Lot 등) 전문 관리.
- **CXSignalExit**: 청산 신호 전문 관리.
- **CXOrder**: 터미널 대기 오더 상태 전문 관리.
- **CXPosition**: 터미널 보유 포지션 상태 전문 관리.

---

# ABC Project Detailed Trade Lifecycle Case Study

이 섹션의 내용은 원문을 그대로 유지하며, 명시적인 요청이 있을 때까지 변경하지 않는다.

### [Case Study: EURUSD 트레일링 진입 및 청산 흐름]

#### 1단계: 진입 신호 발생 및 감지 (Entry Detection)
*   **상황:** 외부(XTS 서버)에서 SQLite entry_signals 테이블에 EURUSD Buy Limit 신호를 주입합니다. (SID: 1001-26042409-01-00-B-1)
*   **흐름:** 
    1.  CXEntrySignalWatcher가 1초마다 DB를 스캔하다가 해당 레코드를 발견합니다.
    2.  감시자는 CXPacket을 생성하여 메시지 허브로 MSG_ENTRY_SIGNAL을 발신합니다.
    3.  CXEAService가 이를 수신하여 오더 타입에 따라 CXLimitOrderManager에게 전달합니다.

#### 2단계: 대기 오더 접수 및 피드백 (Terminal Order & Feedback)
*   **흐름:** 
    1.  CXLimitOrderManager가 MT5 터미널에 Buy Limit 주문을 전송합니다. 주문 시 Comment 필드에 SID를 주입합니다.
    2.  주문 성공 시, 허브로 MSG_ENTRY_CONFIRMED 신호를 보냅니다.
    3.  **동기화:** 이 신호를 받은 CXEntrySignalWatcher는 DB의 entry_signals 테이블에서 해당 레코드를 **삭제**하여 중복 진입을 방지합니다.
    4.  동시에 CXEAService는 trade_history 테이블에 **'Executing'** 상태로 첫 이력을 기록합니다.

#### 3단계: 트레일링 진입 관리 (Trailing Entry)
*   **흐름:**
    1.  CXTrailingEntryManager가 터미널의 대기 오더를 감지하고 CXTrailingInstance를 생성합니다.
    2.  **실시간 갱신:** 인스턴스는 현재 Ask 가격을 추적하며 DB(entry_signals)의 가격 필드를 업데이트하고 ea_status를 **5(Trailing)**로 변경합니다. (UI에서 "트레일링 중"으로 표시됨)
    3.  가격이 내려가면 대기 오더 가격을 아래로 쫓아가고, 저점 대비 설정된 te_step만큼 반등하면 대기 오더를 취소하고 **시장가(Market)로 즉시 진입**합니다.

#### 4단계: 포지션 감시 및 청산 신호 (Position & Exit Monitoring)
*   **상황:** 포지션이 체결되어 Active 상태가 되었습니다.
*   **흐름:**
    1.  CXPositionMonitor가 포지션을 실시간 감시하며, CXEAService는 히스토리 상태를 **'Active'**로 갱신합니다.
    2.  이후 DB exit_signals 테이블에 해당 GID(1001-26042409-01-00)에 대한 청산 신호가 들어옵니다.
    3.  CXExitSignalWatcher가 이를 감지하여 MSG_EXIT_SIGNAL을 허브로 발신합니다.

#### 5단계: 청산 실행 및 기록 삭제 (Liquidation & Cleanup)
*   **흐름:**
    1.  CXEAService가 청산 요청을 수신하여 CXCloseManager에게 전달합니다.
    2.  CXCloseManager는 해당 GID가 포함된 모든 포지션을 터미널에서 종료(Close)합니다.
    3.  청산 성공 후 MSG_EXIT_CONFIRMED 신호를 허브로 보냅니다.
    4.  **최종 정리:** CXExitSignalWatcher는 이 신호를 수신하여 DB의 exit_signals 레코드를 삭제합니다.
    5.  CXEAService는 trade_history에 **'Closed'** 상태와 최종 손익 정보를 기록하며 전체 사이클을 마칩니다.

# CXTrailingEntryManager, CXTrailingEntryInstance 동작 구조 사례

이 섹션의 내용은 원문을 그대로 유지하며, 명시적인 요청이 있을 때까지 변경하지 않는다.

CXTrailingEntryManager와 CXTrailingEntryInstance는 **"대기 오더를 시장 가격에 맞춰 유리하게 이동시키다가, 최적의 시점에 시장가로 진입시키는 로직"**을 담당합니다.

### [사례: EURUSD 매수(Buy Limit) 트레일링 진입]

**1. 설정 값 (예시)**
*   **시그널 ID(SID):** 1001-26042409-01-00-B-1
*   **매직넘버(CNO):** 1001
*   **TE_START (활성화 거리):** 500 pts (시장가가 주문 시점보다 500 pts 유리하게 움직이면 작동 시작)
*   **TE_LIMIT (유지 거리):** 1000 pts (시장가와 대기 오더 사이의 간격 유지)
*   **TE_STEP (반등 폭):** 100 pts (최저점 대비 100 pts 반등 시 시장가 진입)

---

### 단계별 동작 흐름

#### 1단계: 매니저의 인스턴스 생성 (Manager's Role)
*   **상황:** MT5 터미널에 EURUSD Buy Limit 대기 주문이 깔려 있습니다. (코멘트에 SID 기록됨)
*   **동작:** CXTrailingEntryManager가 1초마다 터미널의 모든 대기 오더를 스캔합니다.
*   **인스턴스화:** 
    1.  주문 코멘트에서 sid(1001-...-1)를 추출합니다.
    2.  해당 sid를 키로 하는 CXTrailingEntryInstance가 있는지 목록에서 찾습니다.
    3.  **처음 발견했다면**, 새로운 CXTrailingEntryInstance 객체를 생성하여 관리 목록에 추가합니다.

#### 2단계: 트레일링 활성화 감시 (Instance's Role - Activation)
*   **상황:** 주문 시점 시장가 1.08500, 대기 오더 1.07500.
*   **동작:** 시장가가 1.08500에서 1.08450으로 **500 pts(TE_START)**만큼 하락(매수 입장에서 유리)합니다.
*   **결과:** 인스턴스가 m_is_active = true 상태가 되며 본격적인 가격 추격을 시작합니다.

#### 3단계: 가격 추격 및 DB 업데이트 (Trailing & Sync)
*   **상황:** 시장가가 1.08400으로 더 떨어집니다.
*   **동작:** 
    1.  **가격 이동:** 시장가와 대기 오더 사이를 **1000 pts(TE_LIMIT)**로 유지하기 위해, 대기 오더를 1.07500에서 1.07400으로 아래로 수정(OrderModify)합니다.
    2.  **DB 동기화:** SQLite entry_signals 테이블의 해당 레코드를 찾아 현재가(1.08400)를 업데이트하고 상태를 ea_status = 5(Trailing)로 변경합니다. (XTS UI에서 실시간 확인 가능)

#### 4단계: 바닥 감지 및 시장가 진입 (Rebound & Execution)
*   **상황:** 시장가가 계속 하락하여 **최저점 1.08000**을 찍고, 다시 **1.08010으로 100 pts(TE_STEP)**만큼 반등합니다.
*   **동작:** 
    1.  **반등 감지:** 인스턴스가 m_local_low(1.08000) 대비 현재가(1.08010)가 te_step만큼 오른 것을 확인합니다.
    2.  **시장가 전환:** 
        - 기존에 계속 쫓아가던 Buy Limit 대기 오더를 삭제(OrderDelete)합니다.
        - 그 즉시 시장가 매수(Buy Market) 주문을 실행하여 진입을 완료합니다.

---

### [요약]

1.  **CXTrailingEntryManager (관리자):**
    *   터미널을 감시하며 새로운 대기 오더가 생기면 전용 처리기(Instance)를 배정합니다.
    *   **SID**를 기준으로 중복 생성을 방지하고 생명주기를 관리합니다.

2.  **CXTrailingEntryInstance (実行器):**
    *   배정받은 특정 주문(sid)에 대해서만 집요하게 가격을 추적합니다.
    *   시장가가 유리한 방향으로 흐르면 **대기 오더를 이동**시켜 더 좋은 진입가를 확보합니다.
    *   시장가가 되돌아올 때(반등 시) **시장가로 즉시 진입**시켜 체결 확률을 높입니다.
    *   진행 상황을 **SQLite DB에 실시간 기록**하여 UI와의 정합성을 유지합니다.
