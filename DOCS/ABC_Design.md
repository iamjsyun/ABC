# ABC Project - XEA 아키텍처 설계서 (v16.0)
**Last Modified: 2026-04-25 10:45:00**

## 1. 아키텍처 개요
본 시스템은 **XTS (C#)**와 **XEA (MQL5)**가 `ABC.db` (SQLite)를 허브로 사용하는 **Hub Architecture**를 채택하고 있습니다. 모든 신호 처리와 상태 동기화는 데이터베이스를 통해 이루어지며, 본 설계서는 **XEA (MQL5)의 스키마 명칭을 표준(Source of Truth)**으로 정의합니다.

## 2. 최종 클래스 참조 관계도 (Unified CXParam 적용)
(중략: 기존 다이어그램 유지)

## 3. SQLite 데이터베이스 스키마 (v15.1 - XEA Standard)

### 3.1 `entry_signals` 테이블 (Active Signals)
신호 서버(XTS)에서 생성되어 EA(XEA)가 실행해야 할 활성 신호를 관리합니다. XEA의 `CXSignalEntry` 및 XTS의 `XpoSignal.cs`와 1:1 대응합니다.

| Field | Type | Description | XEA Mapping |
| :--- | :--- | :--- | :--- |
| **sid** | TEXT(50) | **Primary Key.** Signal ID (v2.9 규격 준수) | sid |
| **msg_id** | INTEGER | 텔레그램 메시지 ID 등 원본 식별자 | msg_id |
| **xa_status** | INTEGER | Lifecycle Status (1:Parsed, 2:Liquidation, 6:Terminated) <br> **EA 역할:** 최초 신호 인지(1) 용도로만 사용. 주문 시작 후 무시. | xa_status |
| **ea_status** | INTEGER | Feedback Status (v3.0 규격 준수 - 0:Ready ~ 4:Closed) <br> **EA 역할:** 실행 및 자산 동기화의 유일한 기준(Sovereignty). | ea_status |
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

## 4. 핵심 설계 원칙 (v16.0)

### 4.1 Single Parameter Standard (CXParam)
- **원칙:** 모든 비즈니스 로직 함수는 `CXParam* xp` 단 하나의 파라미터만을 사용. 필요한 모든 도메인 객체를 포함하는 페이로더로 활용.

### 4.2 도메인 주권 및 독자 구동 (Domain Sovereignty)
- **핵심 엔진:** `CXTrailingEntryManager`와 `CXPositionManager`는 `CXEAService`에서 직접 소유하며 독립 스캔 루프를 가짐.

### 4.3 정적 전략 등록 (Static Strategy Registration)
- **변경 사항:** `xea.json`을 통한 동적 주입 방식을 폐기하고, EA 기동 시 `CXDBService` 생성자에서 모든 표준 프로세서(`CXTrailingExitManager` 등)를 상시 등록하여 가동함.

## 5. 백테스트 통합 전략 검증 트레이스 시스템 (CXTradeTrace)

### 5.1 설계 철학
- **Strict Dependency Hierarchy:** 상위 단계의 성공 없이 하위 단계는 존재할 수 없는 계층 구조(L1~L6) 채택.
- **Winner-Take-All:** 청산 시 경합하는 여러 전략 중 실제로 실행된 전략의 판단 근거를 최우선으로 기록.
- **SID Independence:** 각 신호(SID)별로 독립된 로그 파일을 생성하여 병렬 실행 시 데이터 간섭 차단.

### 5.2 계층 구조 (Tree-View Format)
| 레벨 | 명칭 | 설명 |
| :--- | :--- | :--- |
| **L1** | **SIGNAL** | 신호 인지 및 초기 파라미터 기록 |
| **L2** | **ENTRY** | 진입 트레일링(te) 과정 및 조건 감시 |
| **L3** | **ORDER** | 터미널 주문 전송 및 서버 응답 결과 |
| **L4** | **POSITION** | 체결 확인 및 포지션 활성화 정보 |
| **L5** | **MGMT** | 포지션 유지 중 트레일링 스탑(ts) 및 수정 이력 |
| **L6** | **EXIT** | 청산 경합 결과(Winner) 및 최종 손익 |

### 5.3 핵심 추적 데이터 (Variable History)
다음 파라미터의 변동 발생 시 **[시장가] -> [이전값] -> [새값]** 이력을 상시 포함한다.
- **진입 관련:** `te_start`, `te_step`, `te_limit`
- **관리 관련:** `ts_start`, `ts_step`, `tp`, `sl`

### 5.4 파일 시스템 전략
- **경로:** `MQL5/Files/ABC_Trace/{YYYYMMDD}/{SID}.log`
- **형식:** 인덴트(`└─`, `├─`)를 활용한 트리뷰 텍스트 형식.
- **특징:** 특정 SID의 생애주기를 단일 파일 내에서 타임라인 순으로 완벽하게 복원.

---

# ABC Project Detailed Trade Lifecycle Case Study
(이 섹션의 내용은 원문을 그대로 유지함)

# CXTrailingEntryManager, CXTrailingEntryInstance 동작 구조 사례
(이 섹션의 내용은 원문을 그대로 유지함)

---

# [전략 검토] ea_status 상태 전이 고도화 (v3.0)

  1. 상태 세분화 로드맵 (Proposed States)

  기존 상태에 검증(Verifying)과 청산진행(Closing) 단계를 추가하여 10단계 내외로 확장합니다.

  ┌──────┬────────────────┬─────────────┬──────────────────────────────────────────────────┐
  │ 코드 │ 상수명         │ 의미        │ 상세설명                                         │
  ├──────┼────────────────┼─────────────┼──────────────────────────────────────────────────┤
  │ 0    │ EA_READY       │ 대기        │ 신호 감시 중인 초기 상태                         │
  │ 1    │ EA_EXECUTING   │ 주문 송신   │ CTrade 호출 직전~직후 (티켓 획득 전)             │
  │ 3    │ EA_PLACED      │ 오더 안착   │ 대기 오더(Limit/Stop)가 서버에 성공적으로 등록됨 │
  │ 7    │ EA_VERIFYING   │ 진입 검증   │ DEAL_ADD 감지 후 터미널 자산 스캔 중             │
  │ 2    │ EA_ACTIVE      │ 활성 포지션 │ 터미널 검증 완료, 정상 운용 중                   │
  │ 5    │ EA_TRAILING    │ 관리 중     │ Trailing Stop 등 사후 관리가 적용 중인 상태      │
  │ 6    │ EA_CLOSING     │ 청산 시도   │ 청산 주문 송신 중 (Executing Exit)               │
  │ 8    │ EA_LIQUIDATING │ 청산 검증   │ 청산 Deal 감지 후 포지션 소멸 확인 중            │
  │ 4    │ EA_CLOSED      │ 최종 종료   │ 모든 자산 정리가 확인된 완결 상태                │
  │ 9    │ EA_ERROR       │ 오류        │ 각 단계에서 발생한 치명적 결함                   │
  └──────┴────────────────┴─────────────┴──────────────────────────────────────────────────┘
  ---

  2. 단계별 세부 전이 로직 분석

  2.1 진입 단계 (Entry Phase)
   - EA_EXECUTING (1) → EA_PLACED (3): 시장가(Market)가 아닌 대기오더(Limit/Stop)의 경우, 주문은 성공했지만 아직 포지션이 아니므로 PLACED 상태에서 체결을 기다려야
     합니다.
   - EA_PLACED (3) → EA_VERIFYING (7): OnTradeTransaction에서 해당 오더의 DEAL_ADD가 감지되는 순간입니다. 이때 터미널 스캔을 시작합니다.
   - EA_VERIFYING (7) → EA_ACTIVE (2): PositionSelectByTicket으로 실제 자산이 확인되면 비로소 ACTIVE가 됩니다.

  2.2 청산 단계 (Exit Phase) - 신규 추가
   - EA_ACTIVE (2) → EA_CLOSING (6): 청산 신호가 발생하여 m_trade.PositionClose를 호출하는 단계입니다.
   - EA_CLOSING (6) → EA_LIQUIDATING (8): 청산 Deal이 발생하여 터미널에서 포지션이 사라지는지 감시하는 단계입니다.
   - EA_LIQUIDATING (8) → EA_CLOSED (4): 터미널 스캔 결과 해당 SID의 포지션이 완전히 사라졌음이 확인되면 최종 CLOSED 처리합니다.

  ---

  3. 기대 효과 (Expected Benefits)

   1. 정밀한 사후 분석: "주문은 나갔는데(1) 서버에 안착이 안 됐는지", "체결은 됐는데(7) 자산 정보가 꼬였는지"를 DB만 보고도 즉시 판단 가능합니다.
   2. 안전한 재시작 (Crash Recovery): EA가 비정상 종료 후 재시작될 때, EA_VERIFYING 상태인 건들은 즉시 터미널 스캔을 시도하여 상태를 복구할 수 있습니다.
   3. 로그 일관성: CXLogService와 연동하여 각 상태 전이마다 표준화된 태그([STEP-1->3], [STEP-7->2])를 남김으로써 디버깅 효율이 비약적으로 향상됩니다.



✦ ABC 시스템의 신호 서버(XTS) 신호 주입부터 터미널(XEA) 최종 청산 및 데이터 정리까지의 전 과정을 구체적인 사례(SID: 1001-26042409-01-00-B-2, GOLD Buy Limit)를 통해
  단계별로 추적합니다.

  본 시나리오는 최근 고도화된 v3.0 상태 전이 규격 및 실자산 기반 검증 로직을 반영하고 있습니다.

  ---

  [시나리오 사례] GOLD 2350.50 Buy Limit (지정가 매수) 주문

  1단계: 신호 주입 및 인지 (XTS → DB)
   1. [XTS] 신호 발생: 텔레그램이나 UI를 통해 GOLD 매수 지정가 신호가 접수됨.
   2. [XTS] DB 주입: entry_signals 테이블에 레코드 삽입.
       * xa_status = 1 (Parsed), ea_status = 0 (Ready)
       * type = 2 (Limit), price_signal = 2350.50
   3. [XEA] 신호 스캔: CXEntryWatchService가 타이머 루프에서 해당 신호 인지.
       * Log: [INFO] [1001...-B-2] [SCAN-HIT] New Signal Detected. Sym:GOLD, Type:LIMIT
   4. [XEA] 매니저 전달: CXMessageHub를 통해 CXLimitOrderManager로 신호 전달.
       * Status Update: ea_status = 1 (Executing)

  2단계: 주문 안착 및 명령 소거 (Order Placement)
   5. [XEA] 주문 송신: m_trade.BuyLimit() 호출.
   6. [XEA] 서버 안착 확인: OnTradeTransaction에서 TRADE_TRANSACTION_ORDER_ADD 이벤트 수신.
       * Action (v3.0): 대기 오더가 터미널에 정상 등록되었으므로, 지시서(Task)로서의 역할 완료로 판단하고 DB에서 즉시 제거.
       * Log: [INFO] [1001...-B-2] [SIGNAL-REMOVED] [STEP-1->REMOVE] Pending Order confirmed on server. Ticket:882731

  3단계: 체결 및 자산 검증 (Deal & Verification)
   7. [MT5] 체결 발생: 가격이 2350.50에 도달하여 대기 오더가 포지션으로 전환됨.
   8. [XEA] 체결 감지: OnTradeTransaction에서 TRADE_TRANSACTION_DEAL_ADD (Entry IN) 이벤트 수신.
   9. [XEA] 자산 재확인: CXPositionManager::VerifyPosition이 실행되어 터미널 포지션 리스트를 직접 스캔.
       * 해당 티켓의 Comment가 1001...-B-2와 일치하는지 최종 확인.
       * Log: [INFO] [1001...-B-2] [SIGNAL-REMOVED] [STEP-7->REMOVE] Terminal asset confirmed. (Redundant Check)

  4단계: 포지션 관리 및 청산 트리거 (Management & Exit)
   10. [XEA] 실시간 관리: CXTrailingExitService가 포지션을 감시하며 수익 구간에 따라 SL(손절가)을 상향 조정.
   11. [XTS] 청산 명령: 신호 서버에서 "수익 확정" 판단하에 exit_signals 테이블에 청산 요청 주입.
       * xa_status = 1, ea_status = 0
   12. [XEA] 청산 신호 인지: CXExitWatchService가 이를 인지하여 CXCloseManager로 전달.
       * Status Update: ea_status = 6 (Closing)
       * Log: [INFO] [1001...-B-2] [EXIT-CLOSE] [STEP-2->6] Initiating Liquidation.

  5단계: 최종 소멸 및 데이터 완결 (Finalization)
   13. [XEA] 청산 실행: m_trade.PositionClose(ticket) 호출.
   14. [XEA] 청산 Deal 확인: OnTradeTransaction에서 TRADE_TRANSACTION_DEAL_ADD (Entry OUT) 감지.
       * Status Update: ea_status = 8 (Liquidating)
   15. [XEA] 최종 수문장 검증: CXExitWatchService가 터미널 스캔 결과 해당 SID의 포지션이 완전히 사라졌음을 확인.
       * Final Status: ea_status = 4 (Closed)
       * Log: [INFO] [1001...-B-2] [EXIT-VERIFIED] [STEP-8->4] Closed Verified. Marking as Closed.
   16. [XTS] 데이터 이관: XTS 서버가 ea_status = 4인 레코드를 감지하여 signal_history로 이동시키고 DB에서 최종 삭제.

  ---

  [핵심 요약: 상태 변화 추적]

  ┌──────┬───────┬───────────┬──────────────────────┬─────────────────────┐
  │ 단계 │ Actor │ 주요 액션 │ ea_status (Feedback) │ DB 상태             │
  ├──────┼───────┼───────────┼──────────────────────┼─────────────────────┤
  │ 준비 │ XTS   │ 신호 주입 │ 0 (Ready)            │ 레코드 존재         │
  │ 송신 │ XEA   │ 주문 요청 │ 1 (Executing)        │ 업데이트            │
  │ 안착 │ XEA   │ 오더 확인 │ REMOVE               │ 삭제 (Task 완료)    │
  │ 운용 │ XEA   │ 자산 관리 │ 2 (Active)           │ (터미널에만 존재)   │
  │ 청산 │ XEA   │ 청산 요청 │ 6 (Closing)          │ exit_signals 생성   │
  │ 검증 │ XEA   │ 소멸 확인 │ 8 (Liquidating)      │ 업데이트            │
  │ 완료 │ XEA   │ 종료 보고 │ 4 (Closed)           │ XTS가 히스토리 이관 │
  └──────┴───────┴───────────┴──────────────────────┴─────────────────────┘

  [이 설계의 강력한 점]
   1. 가벼운 DB: entry_signals는 주문이 터미널에 전달되는 순간 삭제되므로, DB는 항상 수 초 내외의 짧은 명령들만 유지합니다.
   2. 이중 보장: 이벤트(OnTransaction)가 실패하더라도 타이머(Watchdog)가 자산을 발견하면 즉시 DB를 정리하므로 중복 주문 위험이 0%에 가깝습니다.
   3. 명확한 증거: 로그에 남는 [STEP-X->Y] 태그를 통해 사후에 어떤 단계에서 지연이 있었는지 정밀 분석이 가능합니다.

---

## 6. 실시간 대시보드 UI 시스템 (Panel 0, Area A)

### 6.1 설계 개요
- **출력 위치:** Panel 0 (메인 패널), Area A (정적 대시보드 존).
- **관리 단위:** **1 SID = 1 유닛 (2개 행)**.
- **관리 방식:** `CXLoggerUI` 클래스 내 `m_sid_map`을 통한 동적 행 할당 및 소거.
- **특징:** 변경된 정보만 실시간 업데이트하며, 거래 종료 시 해당 영역을 즉시 비워 가독성 유지.

### 6.2 레이아웃 구조 (Visual Layout)
Area A는 2줄을 하나의 블록으로 사용하여 여러 SID를 수직으로 나열합니다.

| 행 (Row) | 유닛 | 출력 내용 (Content) | 비고 |
| :--- | :--- | :--- | :--- |
| **0** | **Unit 1** | `진입 신호 {SID}, Start:{pts}, Step:{pts}, Limit:{pts}` | 헤더 (고정) |
| **1** | **Unit 1** | `대기오더:{Ticket}, TE활성:{bool}, Price:{현재가}, Base:{오더가}, Next:{이동가}, Bound:{한계가}` | 상세 (실시간) |
| **2** | **Unit 2** | `진입 신호 {SID-2}, Start:{pts}, Step:{pts}, Limit:{pts}` | 헤더 |
| **3** | **Unit 2** | `대기오더:{Ticket-2}, TE활성:{bool}, ...` | 상세 |

### 6.3 상세 동작 프로세스
1. **할당 (Assignment):** `CXEntryWatchService`가 새로운 신호를 인지할 때 `m_sid_map`에서 비어있는 인덱스를 찾아 SID를 등록하고 헤더(행 0)를 출력합니다.
2. **업데이트 (Update):** `CXLimitOrderManager` 및 `CXTrailingEntryInstance`가 가격 변동이나 주문 상태 변경 시 해당 유닛의 상세 정보(행 1)를 갱신합니다.
3. **소거 (Clearing):** 오더가 체결되어 ACTIVE가 되거나 사용자가 삭제/취소 시, 해당 유닛의 모든 행을 공백(`""`)으로 출력하고 매핑을 해제합니다.

### 6.4 구체적 시나리오 사례 (Case Study)
- **상황 A (신규 진입):** SID-A 발생 시 Row 0, 1에 정보 표시.
- **상황 B (다중 진입):** SID-B 추가 발생 시 Row 2, 3에 정보 표시.
- **상황 C (체결/종료):** SID-A 체결 시 Row 0, 1은 공백 처리되어 사라지고 SID-B 정보만 화면에 유지됨. 다음 신호 발생 시 비어있는 Row 0, 1을 우선 재사용.


