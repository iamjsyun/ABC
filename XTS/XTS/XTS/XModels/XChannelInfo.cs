namespace XTS.XModels;

using System.Collections.Generic;

public class XChannelInfo
{
    public long CID { get; set; }
    public string Name { get; set; } = string.Empty;
    public int CNO { get; set; }
    public string Type { get; set; } = "TRADE"; // TRADE, YOUTUBE_VISION, INFO
    public string RunMode { get; set; } = "Simulation";
    public bool IsDebugLogging { get; set; } = false;
    public string? SimulationMapping { get; set; }
    public XPluginConfig Plugin { get; set; } = new();
    public XTradingOptions? TradingOptions { get; set; }
    public XVisionOptions? VisionOptions { get; set; }

    public XChannelInfo() { }

    public XChannelInfo(long cid, int cno, string name = "", string type = "TRADE")
    {
        this.CID = cid;
        this.CNO = cno;
        this.Name = name;
        this.Type = type;
    }

    public List<double> DefaultTps { get; set; } = new();
    public List<double> DefaultSls { get; set; } = new();
    public List<double> DefaultOffsets { get; set; } = new();
    public List<double> DefaultLots { get; set; } = new();
}

public class XPluginConfig
{
    public string AssemblyName { get; set; } = string.Empty;
    public string ClassName { get; set; } = string.Empty;
}

public class XTradingOptions
{
    public bool IsActive { get; set; } = true;
    public int GridCount { get; set; } = 5;
    public List<string> BuyProfiles { get; set; } = new();
    public List<string> SellProfiles { get; set; } = new();

    public List<XGridProfile> GetProfiles(int cno, int dir)
    {
        var result = new List<XGridProfile>();
        var source = (dir == 1) ? BuyProfiles : SellProfiles;
        if (source == null) return result;

        foreach (var str in source)
        {
            if (string.IsNullOrWhiteSpace(str)) continue;
            var parts = str.Split(',');
            // 신규 포맷: {GNO},{Type},{Lot},{limit offset},{ts start},{ts step},{tp},{sl} (총 8개 필드)
            if (parts.Length < 8) continue;

            try
            {
                result.Add(new XGridProfile
                {
                    cno = cno,
                    dir = dir,
                    gno = int.Parse(parts[0].Trim()),
                    type = int.Parse(parts[1].Trim()), 
                    lot = double.Parse(parts[2].Trim()),
                    offset = double.Parse(parts[3].Trim()),
                    ts_trigger = int.Parse(parts[4].Trim()),
                    ts_step = int.Parse(parts[5].Trim()),
                    tp = double.Parse(parts[6].Trim()),
                    sl = double.Parse(parts[7].Trim()),
                    gap_min = 200 // 기본값 유지 또는 추후 확장 가능
                });
            }
            catch { /* skip invalid format */ }
        }
        return result;
    }
}

public class XVisionOptions
{
    public int CaptureIntervalMs { get; set; } = 1000;
    public Dictionary<string, int[]> RoiRegions { get; set; } = new();
}
