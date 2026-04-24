using System;
using DevExpress.Xpo;

namespace XTS.XModels.DB;

[Persistent("channel_options")]
public class XpoChannelOption : XPLiteObject
{
    public XpoChannelOption(Session session) : base(session) { }

    [Key(false)]
    public int cno
    {
        get => GetPropertyValue<int>(nameof(cno));
        set => SetPropertyValue(nameof(cno), value);
    }

    [Size(100)]
    public string name
    {
        get => GetPropertyValue<string>(nameof(name))!;
        set => SetPropertyValue(nameof(name), value);
    }

    public bool is_buy_active
    {
        get => GetPropertyValue<bool>(nameof(is_buy_active));
        set => SetPropertyValue(nameof(is_buy_active), value);
    }

    public bool is_sell_active
    {
        get => GetPropertyValue<bool>(nameof(is_sell_active));
        set => SetPropertyValue(nameof(is_sell_active), value);
    }

    public double buy_entry_offset
    {
        get => GetPropertyValue<double>(nameof(buy_entry_offset));
        set => SetPropertyValue(nameof(buy_entry_offset), value);
    }

    public double sell_entry_offset
    {
        get => GetPropertyValue<double>(nameof(sell_entry_offset));
        set => SetPropertyValue(nameof(sell_entry_offset), value);
    }

    public double tp_points
    {
        get => GetPropertyValue<double>(nameof(tp_points));
        set => SetPropertyValue(nameof(tp_points), value);
    }

    public double sl_points
    {
        get => GetPropertyValue<double>(nameof(sl_points));
        set => SetPropertyValue(nameof(sl_points), value);
    }

    public double default_volume
    {
        get => GetPropertyValue<double>(nameof(default_volume));
        set => SetPropertyValue(nameof(default_volume), value);
    }

    public int lot_strategy
    {
        get => GetPropertyValue<int>(nameof(lot_strategy));
        set => SetPropertyValue(nameof(lot_strategy), value);
    }

    public double lot_value
    {
        get => GetPropertyValue<double>(nameof(lot_value));
        set => SetPropertyValue(nameof(lot_value), value);
    }

    public double lot_rate
    {
        get => GetPropertyValue<double>(nameof(lot_rate));
        set => SetPropertyValue(nameof(lot_rate), value);
    }

    public int grid_count
    {
        get => GetPropertyValue<int>(nameof(grid_count));
        set => SetPropertyValue(nameof(grid_count), value);
    }

    public double grid_step
    {
        get => GetPropertyValue<double>(nameof(grid_step));
        set => SetPropertyValue(nameof(grid_step), value);
    }

    public int ts_trigger
    {
        get => GetPropertyValue<int>(nameof(ts_trigger));
        set => SetPropertyValue(nameof(ts_trigger), value);
    }

    public int ts_step
    {
        get => GetPropertyValue<int>(nameof(ts_step));
        set => SetPropertyValue(nameof(ts_step), value);
    }

    public int gap_min
    {
        get => GetPropertyValue<int>(nameof(gap_min));
        set => SetPropertyValue(nameof(gap_min), value);
    }

    public int type
    {
        get => GetPropertyValue<int>(nameof(type));
        set => SetPropertyValue(nameof(type), value);
    }

    public DateTime at_updated
    {
        get => GetPropertyValue<DateTime>(nameof(at_updated));
        set => SetPropertyValue(nameof(at_updated), value);
    }
}
