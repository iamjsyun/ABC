# ABC Project Rules (v2.9)

## 1. Project Overview
- **XTS (C#):** Signal Server & Terminal UI (WPF/App) - **핵심 통합 대상**
- **XEA (MQL5):** Expert Advisor & Indicators for MT5
- **Architecture:** Hub Architecture via SQLite (`server_signals` table) and Shared Data.
- **Project Status:** XTG 프로젝트와 완전히 분리됨. XTS와의 통합 운영을 최우선으로 함.
- Git Repository: `https://github.com/iamjsyun/ABC.git` (Branch: `master`)

## 2. Identifier Standards (Mandatory)
### SID (Signal ID) - 23 Characters (v2.9)
- **Format:** `{CNO(4)}-{yyMMddHH(8)}-{SNO(2)}-{GNO(2)}-{DIR(1)}-{TYPE(1)}`
- **Example:** `1001-26042409-01-00-B-1` (Channel-DateHour-SNO-GNO-Direction-Type)
- **Usage:** MUST be injected into MT5 'Comment' field (Max 31 chars) for DB synchronization.

### GID (Group ID) - 19 Characters
- **Format:** `{CNO(4)}-{yyMMddHH(8)}-{SNO(2)}-{GNO(2)}`
- **Rule:** Identifies a grid group. GNO 00 is Master, 01+ are grid entries.

### Abbreviations
- **te:** Trailing Entry (트레일링진입)
- **ts:** Trailing Stop (트레일링스탑)

## 3. Engineering & Build Standards
- **Build Logs:** All build results MUST be stored in `_log/` (e.g., `_log/build_xts.log`, `_log/build_xte.log`).
- **MQL5 Path:** Priority 1: `D:\Program Files\XM Global MT5\MetaEditor64.exe`, Priority 2: `C:\Program Files\XM Global MT5\MetaEditor64.exe`.
- **XTS Build:** Use `dotnet build` or `msbuild`.
- **WPF Standards:** Use `dxmvvm` with `DXEvent` (`@sender`, `@args`).
- **Git:** Exclude `_log/`, `_temp/`, `.ex5`, and `.log` files from tracking.

## 4. Operational & Logic Rules
### [State Management]
- **Order Type (type):** 0(CLOSE), 1(Market), 2(Limit_M), 3(Stop), 4(Limit_P)
- **ea_status (Feedback):** v3.0 규격 준수 (0:Ready, 1:Executing, 3:Placed, 7:Verifying, 2:Active, 4:Closed, 9:Error 등)
- **xa_status (Lifecycle):** 1(Parsed), 2(Liquidation), 6(Terminated) - 최초 인지용

### [Decision Logic]
- **Close:** IF (type == 0 || MSG_CLOSE_REQ received) -> Immediate liquidation of the GID position.
- **Entry:** IF (type > 0 && ea_status == 0 && xa_status == 1) -> Execute entry sequence.

### [Status Sovereignty]
- **xa_status:** ONLY used by EA for initial signal detection (xa_status == 1). Once an order is executing, EA ignores xa_status.
- **ea_status:** The primary lifecycle owner for EA. All stage transitions (1 to 9) are driven by ea_status.

### [Field & Value Standards]
- **Volume:** Use `lot` field ONLY (Avoid `vol` or `volume`).
- **Values:** `sl`, `tp`, `offset` MUST be in **Points (pts)**, never absolute prices.
- **Sync:** Positions without a matching GID in DB must be corrected via `StartupSync`.

## 5. Logging & Path Standards
### [Log Standardization v1.2]
- **Format:** `[YYYY.MM.DD HH:mm:ss] [Level] [SID] [Tag] Message`
- **Mandatory Tags:** `[SCAN-HIT]`, `[ENTRY-OK]`, `[GRID-WAIT]`, `[SL-CORRECT]`, `[TP-CORRECT]`.
- **CTrade Errors:** Always include `ResultRetcode()` and `ResultRetcodeDescription()`.

### [Path Standardization]
- **Database:** `AXGS.db`은 MT5 Common Data Folder (`Common/Files`)에서 관리.
- **EA Logs:** `AXGS_YYYY.MM.DD.log` 형식으로 Common Data Folder에 저장.
- **Design Docs:** `DOCS\ABC_Design.md` 파일을 통해 XTS와 설계를 공유함. (프로젝트 루트의 DOCS 폴더 사용)

## 6. Development Workflow
### [Initial Setup for New PC]
1. **Clone Repository:** `git clone https://github.com/iamjsyun/ABC.git`
2. **Setup Symbolic Links:** Run `.\Scripts\setup_links.ps1` in PowerShell. (This maps `%AppData%` dynamically to your local PC environment).
3. **Register Gemini Memory:** Ensure Git and MetaEditor paths are set as per Section 3.

### [Coding Standards]
- **MQL5 Pointer Access:** MQL5에서는 포인터 참조 시 `->` 연산자를 사용하지 않고, 반드시 `.` (점) 연산자를 사용한다. (예: `xp.Get()` 포인터 타입이라도 `.` 사용)
- **Payloader:** 매개변수 관리를 위해 별도의 구조체나 클래스를 생성하지 않고, 반드시 `CXParam` 또는 `CXPacket`을 확장하여 페이로더(Payloader)로 활용한다.
- **Parameter Standard:** 프로젝트 내 모든 함수의 파라미터는 `CXParam* xp` 1개만을 사용하는 것을 원칙으로 한다. 필요한 인자(Argument)는 호출 전 `CXParam` 객체에 담아서 전달하며, 수신부에서 이를 추출하여 사용한다.
- **Modifications:** Execute ONLY upon explicit user Directive. Stop and wait after completion.
- **Documentation Preservation:** `DOCS\ABC_Design.md`에 추가된 'Detailed Trade Lifecycle Case Study' 및 'CXTrailingEntryManager, CXTrailingEntryInstance 동작 구조 사례'의 내용은 원문을 그대로 유지하며, 사용자의 명시적인 수정 요청이 있을 때까지 절대 변경하지 않는다.

### [Building Components]
- **XEA Build:** Use the `.\Scripts\build_xea.ps1` script. This command compiles the MQL5 Expert Advisor.
- **XTS Build:** Use the `.\Scripts\build_xts.ps1` script. This command builds the C# application.
