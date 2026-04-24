using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using XTS.XModels;

namespace XTS.XChannels.GG;

public class GlobalGold : XInterpreterBase
{
    public GlobalGold(XParameter param, XChannelInfo info) : base(param, info) 
    {
        
    }

    protected override List<XSignal> Interpret(XDataObject xdo)
    {
        var signals = new List<XSignal>();
        string rawText = xdo.Text ?? string.Empty;

        // [필수 조건 검사]
        string cmd = XCode.NONE;

        // 1. 진입 조건 체크 (5개 필수 문구)
        bool isEntry = rawText.Contains("현시점 정보공유드립니다") && 
                      rawText.Contains("분석회차") && 
                      rawText.Contains("시장관점") && 
                      rawText.Contains("개인기준 포지션") && 
                      rawText.Contains("참고가격");

        // 2. 청산 조건 체크 (3개 필수 문구)
        bool isExit = rawText.Contains("정리시점 공유") && 
                     rawText.Contains("회차") && 
                     rawText.Contains("시장가정리");

        if (isEntry) cmd = XCode.OPEN;
        else if (isExit) cmd = XCode.CLOSE;

        // 필수 조건 미충족 시 즉시 반환
        if (cmd == XCode.NONE) return signals;

        // 기본 정보 파싱
        int dirVal = 0; 
        double price = 0;
        double lot = 0.1; // 기본값
        var snos = new HashSet<int>();

        string[] lines = rawText.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.RemoveEmptyEntries);
        foreach (var line in lines)
        {
            if (line.Contains("BUY") || line.Contains("롱") || line.Contains("매수")) dirVal = XCode.BUY;
            else if (line.Contains("SELL") || line.Contains("숏") || line.Contains("매도")) dirVal = XCode.SELL;

            // 가격 파싱
            var priceMatch = Regex.Match(line, @"(?:참고가격|Price|가격)[:\s]*([\d,.]+)");
            if (priceMatch.Success && double.TryParse(priceMatch.Groups[1].Value.Replace(",", ""), out double p)) price = p;

            // 수량 파싱
            if (line.Contains("개인기준 포지션"))
            {
                var lotMatch = Regex.Match(line, @"(\d+(\.\d+)?)");
                if (lotMatch.Success && double.TryParse(lotMatch.Groups[1].Value, out double l)) lot = l;
            }

            // 회차 추출
            var snoMatches = Regex.Matches(line, @"(?:분석회차|회차|No\.?)[:\s]*(\d+)");
            foreach (Match m in snoMatches)
            {
                if (int.TryParse(m.Groups[1].Value, out int s)) snos.Add(s);
            }
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
