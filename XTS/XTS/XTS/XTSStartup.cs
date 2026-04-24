using System;
using System.IO;
using System.Text.Json;
using System.Collections.Generic;
using NLog;
using XTS.XModels;
using XTS.XModels.DB;
using XTS.XChannels.GG;
using XTS.XChannels.GMK;
using XTS.XChannels.XSim;
using XTS.XServices.TelegramService;
using XTS.XServices;

namespace XTS;

/// <summary>
/// XTG 엔진의 초기화 및 구동을 담당하는 스타트업 클래스
/// </summary>
public class XTSStartup
{
    private static readonly Logger nlog = LogManager.GetCurrentClassLogger();

    /// <summary>
    /// 설정 파일을 로드하여 XParameter 및 서비스들을 초기화합니다.
    /// </summary>
    /// <param name="configPath">XConfig JSON 파일 경로 (기본값: _config/config.json)</param>
    /// <returns>초기화된 XParameter 객체</returns>
    public static XParameter Initialize(string configPath = "_config/XTS.json")
    {
        nlog.Trace($"[Startup] Initializing XTS System with config: {configPath}");

        // 1. 설정 파일 관리 (존재 확인 및 자동 생성)
        EnsureConfigFile(configPath);

        // 2. 설정 로드
        XConfig? config = null;
        try
        {
            string json = File.ReadAllText(configPath);
            config = JsonSerializer.Deserialize<XConfig>(json);
        }
        catch (Exception ex)
        {
            nlog.Error(ex, $"[Startup] Failed to load config from {configPath}");
        }

        if (config == null)
        {
            nlog.Fatal("[Startup] Config object is null. Initialization aborted.");
            throw new InvalidOperationException("Config load failed.");
        }

        // 3. XParameter 생성 및 설정 주입
        var param = new XParameter
        {
            Config = config
        };

        // 4. 서비스 및 채널 초기화
        ConfigureServices(param, config);

        nlog.Trace("[Startup] XTG System initialization completed.");
        return param;
    }

    private static void ConfigureServices(XParameter param, XConfig config)
    {
        nlog.Trace("[Startup] Configuring Services and Channels from Config (Dynamic)...");

        // 1. 설정된 모든 채널 등록 및 인터프리터 동적 매핑
        foreach (var entry in config.Channels)
        {
            var info = entry.Value;
            if (info.CNO == 0)
            {
                param.RegisterChannel(info);
                continue;
            }

            // Plugin.ClassName이 설정되어 있으면 리플렉션으로 인스턴스 생성
            if (!string.IsNullOrEmpty(info.Plugin.ClassName))
            {
                try
                {
                    // 클래스명이 정규화되지 않은 경우(점이 없는 경우)에만 기본 네임스페이스 결합
                    string fullTypeName = info.Plugin.ClassName.Contains(".") 
                        ? info.Plugin.ClassName 
                        : FindFullTypeName(info.Plugin.ClassName);

                    Type? type = Type.GetType(fullTypeName);
                    if (type == null)
                    {
                        // AssemblyName이 지정되어 있다면 해당 어셈블리에서 찾기 시도
                        if (!string.IsNullOrEmpty(info.Plugin.AssemblyName))
                        {
                            fullTypeName = $"{fullTypeName}, {info.Plugin.AssemblyName}";
                            type = Type.GetType(fullTypeName);
                        }
                    }

                    if (type != null)
                    {
                        var interpreter = Activator.CreateInstance(type, param, info) as XObject;
                        if (interpreter != null)
                        {
                            param.Add(interpreter);
                            nlog.Trace($"[Startup] Dynamically loaded interpreter: {fullTypeName} for CNO {info.CNO}");
                        }
                    }
                    else
                    {
                        nlog.Error($"[Startup] Could not find type: {fullTypeName}");
                    }
                }
                catch (Exception ex)
                {
                    nlog.Error(ex, $"[Startup] Failed to instantiate interpreter for {info.Name} (CNO: {info.CNO})");
                }
            }
            else
            {
                nlog.Warn($"[Startup] No ClassName defined for CNO {info.CNO} ({info.Name}). Skipping interpreter registration.");
            }

            param.RegisterChannel(info);
        }

        // 2. 핵심 서비스 인프라 등록
        var db = new XpoSqliteService(param);
        param.Add(db);
        param.Add(new XGatewayService(param));
        param.Add(new XSyncWorker(param));
        param.Add(new XTelegram(param));
        
        nlog.Trace("[Startup] Starting all services...");
        param.StartAll();

        // 3. 설정파일(JSON) 기반으로 DB 캐시(Options/Profiles) 초기화
        LoadOptionsFromConfig(param, config);
    }

    private static void LoadOptionsFromConfig(XParameter param, XConfig config)
    {
        var db = param.GetService<XpoSqliteService>();
        if (db == null) return;

        nlog.Info("[Startup] Synchronizing ChannelOptions and GridProfiles from Config to DB (Overwrite Mode)...");

        foreach (var entry in config.Channels)
        {
            var info = entry.Value;
            if (info.TradingOptions == null) continue;

            // [고도화] 무조건 덮어쓰기 (Sync)
            nlog.Info($"[Startup] Syncing Option for CNO:{info.CNO} ({info.Name}) | IsActive:{info.TradingOptions.IsActive}");
            var tOpt = info.TradingOptions;
            var channelOpt = new XChannelOption
            {
                cno = info.CNO,
                name = info.Name,
                is_buy_active = tOpt.IsActive,
                is_sell_active = tOpt.IsActive,
                grid_count = tOpt.GridCount
            };
            db.SetOption(channelOpt);

            // 프로필도 항상 덮어쓰기
            var buyProfiles = tOpt.GetProfiles(info.CNO, 1);
            foreach (var profile in buyProfiles) db.SetGridProfile(profile);

            var sellProfiles = tOpt.GetProfiles(info.CNO, 2);
            foreach (var profile in sellProfiles) db.SetGridProfile(profile);
        }
    }

    /// <summary>
    /// 클래스명만으로 전체 타입 경로를 유추합니다. (GG.GlobalGold, GMK.GMK 등)
    /// </summary>
    private static string FindFullTypeName(string className)
    {
        // 명시적인 매핑 규칙 또는 검색 로직 (확장 가능)
        if (className == "GlobalGold") return "XTS.XChannels.GG.GlobalGold";
        if (className == "GMK") return "XTS.XChannels.GMK.GMK";
        if (className == "XHANA") return "XTS.XChannels.XSim.XHANA";
        if (className == "XDUNA") return "XTS.XChannels.XSim.XDUNA";
        
        return $"XTS.XChannels.{className}";
    }

    private static void EnsureConfigFile(string configPath)
    {
        if (File.Exists(configPath)) return;

        nlog.Warn($"[Startup] Config file not found. Creating default config: {configPath}");
        
        try
        {
            string? dir = Path.GetDirectoryName(configPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            var channels = new Dictionary<string, XChannelInfo>();

            // Helper with ClassName metadata
            XChannelInfo CreateTradeChannel(long id, int cno, string name, string className, string? mapping = null)
            {
                // [신규 포맷] GNO, Type, Lot, Offset, TsStart, TsStep, TP, SL (8개 필드)
                var gridSettings = new List<string> {
                    "0,1,0.1,500,100,600,500,0"
                };

                return new XChannelInfo(id, cno, name, "TRADE")
                {
                    RunMode = "Simulation",
                    SimulationMapping = mapping ?? $"{cno},{id}", // 기본값은 자기 자신으로 매핑
                    Plugin = new XPluginConfig { ClassName = className },
                    TradingOptions = new XTradingOptions
                    {
                        IsActive = true,
                        GridCount = 1,
                        BuyProfiles = new List<string>(gridSettings),
                        SellProfiles = new List<string>(gridSettings)
                    }
                };
            }

            // TRADE Channels (HANA는 GLOBAL GOLD로 매핑되도록 설정)
            channels["-1002242096395"] = CreateTradeChannel(-1002242096395, 1001, "GLOBAL GOLD", "GlobalGold");
            channels["-1001658145217"] = CreateTradeChannel(-1001658145217, 4001, "GMK", "GMK");
            channels["-1003778889507"] = CreateTradeChannel(-1003778889507, 3001, "HANA", "XHANA", "1001,-1002242096395");
            channels["-1001956555184"] = CreateTradeChannel(-1001956555184, 2001, "DUNA", "XDUNA");

            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string commonPath = Path.Combine(appData, @"MetaQuotes\Terminal\Common\Files");

            var defaultConfig = new XConfig
            {
                Version = "1.0.0",
                SystemSettings = new XSystemSettings
                {
                    Paths = new XPathSettings
                    {
                        ProdDbFullpath = Path.Combine(commonPath, "ABC.db"),
                        TestDbFullpath = Path.Combine(commonPath, "ABC_TEST.db"),
                        LogRootDir = "_log"
                    },
                    Logging = new XLoggingSettings
                    {
                        GlobalLogLevel = "Trace",
                        EnableAllChannelLogs = true
                    }
                },
                Channels = channels
            };

            try
            {
                var options = new JsonSerializerOptions { WriteIndented = true };
                string defaultJson = JsonSerializer.Serialize(defaultConfig, options);
                File.WriteAllText(configPath, defaultJson);
                nlog.Info("[Startup] Default config file created with new Buy/Sell settings structure.");
            }
            catch (Exception ex)
            {
                nlog.Error(ex, "[Startup] Failed to create default config file.");
            }
        }
        catch (Exception ex)
        {
            nlog.Error(ex, $"[Startup] Directory creation or config preparation failed for: {configPath}");
        }
    }
}
