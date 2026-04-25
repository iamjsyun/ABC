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
