using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using XTS.XModels;

namespace XTS.XChannels.GMK;

public class GMK : XInterpreterBase
{
    public GMK(XParameter param, XChannelInfo info) : base(param, info) 
    {        
    }

    protected override List<XSignal> Interpret(XDataObject xdo)
    {
        var signals = new List<XSignal>();
        string rawText = xdo.Text ?? string.Empty;

        // [필수 조건 검사]
        string cmd = XCode.NONE;

        // 1. 청산 조건 체크
        bool isExit = rawText.Contains("차 청산") && rawText.Contains("진입가") && 
                     rawText.Contains("청산가") && rawText.Contains("실현손익") && rawText.Contains("시간");
        
        // 2. 진입 조건 체크
        bool isEntry = rawText.Contains("차 진입") && rawText.Contains("진입가") && 
                      rawText.Contains("포지션") && rawText.Contains("시간");

        if (isExit) cmd = XCode.CLOSE;
        else if (isEntry) cmd = XCode.OPEN;

        if (cmd == XCode.NONE) return signals;

        // GMK 파싱 로직 시작
        var signal = CreateBaseSignal(xdo);
        signal.cmd = cmd;

        string[] lines = rawText.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.RemoveEmptyEntries);
        foreach (var line in lines)
        {
            if (line.Contains("매수") || line.Contains("BUY") || line.Contains("롱")) signal.dir = 1;
            else if (line.Contains("매도") || line.Contains("SELL") || line.Contains("숏")) signal.dir = 2;

            // 가격 파싱
            var priceMatch = Regex.Match(line, @"(?:진입가|청산가|가격)[:\s]*([\d,.]+)");
            if (priceMatch.Success && double.TryParse(priceMatch.Groups[1].Value.Replace(",", ""), out double p)) signal.price_signal = p;

            // 수량 파싱 (0.25랏 등 직접 파싱 지원)
            var lotMatch = Regex.Match(line, @"(?:수량|비중|포지션)[:\s]*(?:BUY|SELL)?\s*([\d,.]+)\s*(?:랏|LOT)?", RegexOptions.IgnoreCase);
            if (lotMatch.Success && double.TryParse(lotMatch.Groups[1].Value, out double l)) signal.lot = l;
            
            // 회차 파싱
            var snoMatch = Regex.Match(line, @"(\d+)\s*(?:차|회차)");
            if (snoMatch.Success && int.TryParse(snoMatch.Groups[1].Value, out int s)) signal.sno = s;
        }

        signals.Add(signal);

        return signals;
    }
}
