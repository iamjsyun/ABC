using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using DevExpress.Mvvm;
using XTS.XModels.DB;

namespace XTS.XModels;

public static class XSignalExtensions
{
    /// <summary>
    /// 시그널 리스트 조회 (DB에서 해당 채널의 최신 시그널을 가져옴)
    /// </summary>
    public static List<XSignal> Select(this List<XSignal>? signals, XParameter param, int cno = 0, int count = 20)
    {
        var db = param.GetService<XpoSqliteService>();
        if (db == null) return new List<XSignal>();

        var result = db.GetSignalsByCno(cno, count);
        
        if (signals != null)
        {
            signals.Clear();
            signals.AddRange(result);
            return signals;
        }

        return result;
    }

    /// <summary>
    /// 새로운 시그널 리스트를 시스템에 주입 및 결과 검증
    /// </summary>
    public static async Task Insert(this List<XSignal> signals, XParameter param)
    {
        if (signals == null || signals.Count == 0) return;
        var db = param.GetService<XpoSqliteService>();

        foreach (var s in signals)
        {
            param.nlog.Info($"[XSignal:Insert:Start] Attempting to insert SID Pattern: {s.sid ?? "New"}");
            
            if (s.Validate())
            {
                var xdo = new XDataObject 
                { 
                    Signal = s, 
                    CMD = "INJECT_ADD",
                    CNO = s.cno,
                    Timestamp = DateTime.Now
                };
                param.messenger.Send(xdo, "SIGNAL_INTERPRETED");
                param.nlog.Debug($"[XSignal:Insert:Sent] Message sent to Gateway. SID: {s.sid}");

                if (db != null) await VerifyOperation(db, param, s.sid ?? string.Empty, "INSERT");
            }
            else
            {
                param.nlog.Error($"[XSignal:Insert:Fail] Validation failed for signal in CNO:{s.cno}");
            }
        }
    }

    /// <summary>
    /// 기존 시그널 정보 수정 및 결과 검증
    /// </summary>
    public static async Task Update(this List<XSignal> signals, XParameter param)
    {
        if (signals == null || signals.Count == 0) return;
        var db = param.GetService<XpoSqliteService>();

        foreach (var s in signals)
        {
            param.nlog.Info($"[XSignal:Update:Start] Attempting to update SID: {s.sid}");
            
            s.updated = DateTime.Now;
            var xdo = new XDataObject 
            { 
                Signal = s, 
                CMD = "INJECT_MODIFY",
                CNO = s.cno,
                Timestamp = DateTime.Now
            };
            param.messenger.Send(xdo, "DB_SAVE_SIGNAL");
            param.nlog.Debug($"[XSignal:Update:Sent] Message sent to DB Hub. SID: {s.sid}");

            if (db != null) await VerifyOperation(db, param, s.sid ?? string.Empty, "UPDATE");
        }
    }

    /// <summary>
    /// 시그널 삭제 및 결과 검증
    /// </summary>
    public static async Task Delete(this List<XSignal> signals, XParameter param)
    {
        if (signals == null || signals.Count == 0) return;
        var db = param.GetService<XpoSqliteService>();

        foreach (var s in signals)
        {
            param.nlog.Info($"[XSignal:Delete:Start] Attempting to delete SID: {s.sid}");
            
            var xdo = new XDataObject 
            { 
                Signal = s, 
                CMD = "INJECT_DELETE",
                CNO = s.cno,
                Timestamp = DateTime.Now
            };
            param.messenger.Send(xdo, "db_hub_delete_row");
            param.nlog.Debug($"[XSignal:Delete:Sent] Message sent to DB Hub. SID: {s.sid}");

            if (db != null) await VerifyOperation(db, param, s.sid ?? string.Empty, "DELETE");
        }
    }

    /// <summary>
    /// DB 반영 여부를 폴링 방식으로 검증
    /// </summary>
    private static async Task VerifyOperation(XpoSqliteService db, XParameter param, string sid, string opType)
    {
        const int maxRetries = 5;
        const int delayMs = 200;

        param.nlog.Debug($"[XSignal:Verify:Wait] Polling DB for {opType} verification... SID: {sid}");

        for (int i = 1; i <= maxRetries; i++)
        {
            await Task.Delay(delayMs);
            var current = db.GetSignalBySid(sid);

            bool success = opType switch
            {
                "INSERT" or "UPDATE" => current != null,
                "DELETE" => current == null,
                _ => false
            };

            if (success)
            {
                param.nlog.Info($"[XSignal:Verify:Success] {opType} confirmed in DB at attempt {i}. SID: {sid}");
                return;
            }
            param.nlog.Trace($"[XSignal:Verify:Retry] {opType} not yet reflected ({i}/{maxRetries}). SID: {sid}");
        }

        param.nlog.Warn($"[XSignal:Verify:Timeout] {opType} verification timed out after {maxRetries * delayMs}ms. SID: {sid}");
    }
}
