using System;
using System.Collections.Generic;

namespace XTS.XModels;

/// <summary>
/// XTG 시스템 전체 설정을 관리하는 루트 클래스
/// </summary>
public class XConfig
{
    public string Version { get; set; } = "1.0.0";
    public XSystemSettings SystemSettings { get; set; } = new();
    public Dictionary<string, XChannelInfo> Channels { get; set; } = new();
}

public class XSystemSettings
{
    public XPathSettings Paths { get; set; } = new();
    public XLoggingSettings Logging { get; set; } = new();
}

public class XPathSettings
{
    public string ProdDbFullpath { get; set; } = string.Empty;
    public string TestDbFullpath { get; set; } = string.Empty;
    public string PluginDir { get; set; } = "_plugins";
    public string LogRootDir { get; set; } = "_log";
}

public class XLoggingSettings
{
    public string GlobalLogLevel { get; set; } = "Trace";
    public string ChannelLogSubDir { get; set; } = "channels";
    public bool EnableAllChannelLogs { get; set; } = false;
}
