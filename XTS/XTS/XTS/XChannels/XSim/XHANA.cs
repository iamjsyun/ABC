using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using XTS.XModels;

namespace XTS.XChannels.XSim;

public class XHANA : XInterpreterBase
{
    public XHANA(XParameter param, XChannelInfo info) : base(param, info) 
    {        
    }

    protected override List<XSignal> Interpret(XDataObject xdo)
    {
        var signals = new List<XSignal>();
        string rawText = xdo.Text ?? string.Empty;

        nlog.Info($"[XHANA:PARSE] Parsing started for MsgId:{xdo.MsgId}. TextLen:{rawText.Length}");

        // [필수 조건 검사]
        string cmd = XCode.NONE;
        bool isEntry = rawText.Contains("현시점 정보공유드립니다") && 
                      rawText.Contains("분석회차") && 
                      rawText.Contains("시장관점") && 
                      rawText.Contains("개인기준 포지션") && 
                      rawText.Contains("참고가격");

        bool isExit = rawText.Contains("정리시점 공유") && 
                     rawText.Contains("회차") && 
                     rawText.Contains("시장가정리");

        if (isEntry) {
            cmd = XCode.OPEN;
            nlog.Info($"[XHANA:PARSE] Detected OPEN command.");
        }
        else if (isExit) {
            cmd = XCode.CLOSE;
            nlog.Info($"[XHANA:PARSE] Detected CLOSE command.");
        }

        if (cmd == XCode.NONE) {
            nlog.Warn($"[XHANA:PARSE] No command detected in text. Dropping MsgId:{xdo.MsgId}");
            return signals;
        }

        // 세부 파싱 로직
        int dirVal = 0;
        double price = 0;
        double lot = 0.1;
        var snos = new HashSet<int>();

        string[] lines = rawText.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.RemoveEmptyEntries);
        foreach (var line in lines)
        {
            // 방향 추출
            if (line.Contains("매수") || line.Contains("BUY") || line.Contains("롱") || line.Contains("Long")) dirVal = XCode.BUY;
            else if (line.Contains("매도") || line.Contains("SELL") || line.Contains("숏") || line.Contains("Short")) dirVal = XCode.SELL;

            // 가격 추출
            var priceMatch = Regex.Match(line, @"(?:참고가격|Price|가격)[:\s]*([\d,.]+)");
            if (priceMatch.Success && double.TryParse(priceMatch.Groups[1].Value.Replace(",", ""), out double p)) price = p;

            // 랏(수량) 추출
            if (line.Contains("포지션"))
            {
                var lotMatch = Regex.Match(line, @"([\d,.]+)");
                if (lotMatch.Success && double.TryParse(lotMatch.Groups[1].Value, out double l)) lot = l;
            }

            // 회차 추출
            var snoMatch = Regex.Match(line, @"(?:분석회차|회차|No\.?)[:\s]*(\d+)");
            if (snoMatch.Success && int.TryParse(snoMatch.Groups[1].Value, out int s))
            {
                snos.Add(s);
            }
        }

        if (snos.Count == 0)
        {
            var globalSnoMatch = Regex.Match(rawText, @"(?:분석회차|회차|No\.?)[:\s]*(\d+)");
            if (globalSnoMatch.Success && int.TryParse(globalSnoMatch.Groups[1].Value, out int s)) snos.Add(s);
        }

        if (snos.Count == 0) snos.Add(1);

        foreach (var sno in snos)
        {
            var signal = CreateBaseSignal(xdo);
            signal.cmd = cmd;
            signal.dir = dirVal;
            signal.price_signal = price;
            signal.lot = lot;
            signal.sno = sno;
            signals.Add(signal);
        }

        return signals;
    }
}
