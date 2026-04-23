# ABC Project Rules (v2.9)

## 1. Project Overview
- **XTS (C#):** Signal Server & Terminal UI (WPF/App)
- **XTE (MQL5):** Expert Advisor & Indicators for MT5
- **Architecture:** Hub Architecture via SQLite (`server_signals` table) and Shared Data.

## 2. Identifier Standards (Mandatory)
### SID (Signal ID) - 23 Characters (v2.9)
- **Format:** `{CNO(4)}-{yyMMddHH(8)}-{SNO(2)}-{GNO(2)}-{DIR(1)}-{TYPE(1)}`
- **Example:** `1001-26042409-01-00-B-1` (Channel-DateHour-SNO-GNO-Direction-Type)
- **Usage:** MUST be injected into MT5 'Comment' field (Max 31 chars) for DB synchronization.

### GID (Group ID) - 19 Characters
- **Format:** `{CNO(4)}-{yyMMddHH(8)}-{SNO(2)}-{GNO(2)}`
- **Rule:** Identifies a grid group. GNO 00 is Master, 01+ are grid entries.

## 3. Engineering & Build Standards
- **Build Logs:** All build results MUST be stored in `_log/` (e.g., `_log/build_xts.log`, `_log/build_xte.log`).
- **MQL5 Path:** Priority 1: `D:\Program Files\XM Global MT5\MetaEditor64.exe`, Priority 2: `C:\Program Files\XM Global MT5\MetaEditor64.exe`.
- **XTS Build:** Use `dotnet build` or `msbuild`.
- **WPF Standards:** Use `dxmvvm` with `DXEvent` (`@sender`, `@args`).
- **Git:** Exclude `_log/`, `_temp/`, `.ex5`, and `.log` files from tracking.

## 4. Operational & Logic Rules
### [State Management]
- **otype (Order Type):** 0(CLOSE), 1(Market), 2(Limit_M), 4(Limit_P)
- **ea_status (Feedback):** 0(Ready), 1(Executing), 2(Active), 4(Closed), 5(Trailing), 9(Error)
- **xa_status (Lifecycle):** 1(Accepted), 2(Liquidation), 6(Terminated)

### [Decision Logic]
- **Close:** IF (otype == 0 || xa_status == 2) -> Immediate liquidation of the GID position.
- **Entry:** IF (otype > 0 && xa_status == 1) -> Execute entry sequence.

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
- **Database:** `AXGS.db` is managed in MT5 Common Data Folder (`Common/Files`).
- **EA Logs:** Saved as `AXGS_YYYY.MM.DD.log` in the Common Data Folder.

## 6. Development Workflow
- **Payloader:** Use `CXParam` or `CXPacket` instead of custom structures for parameter management.
- **Modifications:** Execute ONLY upon explicit user Directive. Stop and wait after completion.
