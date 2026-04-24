using System;

namespace XTS.XModels;

public static class XCode
{
    public const string NONE = "NONE";
    public const string TRADE = "TRADE";
    public const string OPEN = "TRADE"; // OPEN is an alias for TRADE
    public const string CLOSE = "CLOSE";
    public const string GRID = "GRID";
    public const int BUY = 1;
    public const int SELL = 2; // v7.5 Standard: 1=BUY, 2=SELL
    public const string GROUP_CLOSE = "GROUP_CLOSE";
    public const string INFO = "INFO";
    // --- 그리드 체계 (G0 ~ G4) ---
    public const int GNO_MASTER = 0;    // G0: 첫 번째 그리드이자 마스터 포지션
    public const int GNO_MAX = 4;       // 최대 G4까지 지원

    // --- 진입 타입 체계 (v7.5 표준) ---
    public const int TYPE_CLOSE = 0;    // 청산 (Liquidation)
    public const int TYPE_MARKET = 1;   // Type 1: 즉시 시장가 진입 (Market)
    public const int TYPE_LIMIT_M = 2;  // Type 2: 현재가 기준 고정 리미트 (Market + Offset)
    public const int TYPE_TRAIL_M = 3;  // Type 3: 현재가 기준 트레일링 진입 (Market + Offset + Trailing)
    public const int TYPE_LIMIT_P = 4;  // Type 4: 지정가 기준 고정 리미트 (Price + Offset)
    public const int TYPE_TRAIL_P = 5;  // Type 5: 지정가 기준 트레일링 진입 (Price + Offset + Trailing)


    /// <summary>
    /// EA(MQL5)에서 관리하는 신호의 실행 생애주기 상태 코드 (Lifecycle v2.1)
    /// </summary>
    public enum EaStatus
    {
        Ready = 0,      // 신규 신호 감지 (Entry)
        Sending = 1,    // 주문 송신 중 (In-Flight)
        Active = 2,     // 체결 및 포지션 유지 (Monitoring)
        Closing = 3,    // 청산 요청 중 (Exiting)
        Closed = 4,     // 정상 종료 (Success)
        Failed = 5,     // 실행 실패 (Error)
        Cancelled = 6,  // 취소됨 (User/Sys)
        Orphaned = 7,   // 유령 자산 역주입 (Reverse)
        Reconciled = 8, // 강제 동기화 종료 (Sync)
        Archived = 10   // 히스토리 이관 완료 (History)
    }

    /// <summary>
    /// App/Server에서 관리하는 신호의 제어 및 분석 상태 코드 (v5.0 표준)
    /// </summary>
    public enum XaStatus
    {
        Raw = 0,        // 메시지 수신 (Raw Text)
        Parsed = 1,     // 분석 완료 (Interpreter)
        Liquidation = 2,// 청산/취소 요청 (Exit/Cancel) - EA가 감지하여 즉시 청산
        Waiting = 3,    // 승인 대기 (Manual Mode)
        Accepted = 4,   // 실행 승인 (Entry Accepted) - EA가 감지하여 진입
        Revoke_Req = 5, // 취소 요청 (User Revoke)
        Terminated = 6, // 강제 종료 완료 (Force Exit Done)
        Dropped = 9     // 제외/무시 (Ignored)
    }
}
