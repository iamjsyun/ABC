namespace XTS.XModels;

using System;

public class XChannelOption
{
    public int cno { get; set; }
    public string name { get; set; } = string.Empty;
    public bool is_buy_active { get; set; } = true;
    public bool is_sell_active { get; set; } = true;
    public double buy_entry_offset { get; set; }
    public double sell_entry_offset { get; set; }
    public double tp_points { get; set; }
    public double sl_points { get; set; }
    public double default_volume { get; set; }
    public int lot_strategy { get; set; }
    public double lot_value { get; set; }
    public double lot_rate { get; set; }
    public int grid_count { get; set; }
    public double grid_step { get; set; }
    public int ts_trigger { get; set; } = 500;
    public int ts_step { get; set; } = 100;
    public int gap_min { get; set; } = 200;
    public int type { get; set; }
    public DateTime at_updated { get; set; }
}
