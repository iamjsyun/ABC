using DevExpress.Mvvm;
using NLog;
using System;
using System.Collections.Generic;
using System.Linq;

namespace XTS.XModels;

public class XParameter
{
    public NLog.ILogger nlog { get; set; }
    public IMessenger messenger { get; set; } = Messenger.Default;
    public XConfig Config { get; set; } = new();

    private List<XObject> _services = new List<XObject>(); 
    public Dictionary<long, XChannelInfo> Channels = new Dictionary<long, XChannelInfo>();    
    public Dictionary<int, XChannelOption> ChannelOptions = new Dictionary<int, XChannelOption>();    

    public XParameter()
    {
        // 1. 기본 로거 먼저 할당 (초기화 도중 로그 출력 대비)
        nlog = LogManager.GetCurrentClassLogger();
        
        Console.WriteLine("[DIAGNOSTIC] XParameter constructor: Attempting to load NLog config...");
        try
        {
            LogManager.ThrowExceptions = true;
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string configPath = System.IO.Path.Combine(baseDir, "NLog.config");
            Console.WriteLine($"[DIAGNOSTIC] Looking for NLog.config at: {configPath}");

            if (System.IO.File.Exists(configPath))
            {
                Console.WriteLine("[DIAGNOSTIC] NLog.config found. Loading...");
                // 2. XmlLoggingConfiguration을 사용하여 명시적으로 설정 로드
                var config = new NLog.Config.XmlLoggingConfiguration(configPath);
                LogManager.Configuration = config;
                Console.WriteLine("[DIAGNOSTIC] LogManager.Configuration set.");

                // Reconfig is important for existing loggers
                LogManager.ReconfigExistingLoggers();
                Console.WriteLine("[DIAGNOSTIC] Loggers reconfigured.");

                if (LogManager.Configuration.AllTargets.Count == 0) {
                     Console.WriteLine("[DIAGNOSTIC] WARNING: NLog config loaded, but 0 targets found.");
                } else {
                     Console.WriteLine($"[DIAGNOSTIC] NLog targets loaded: {LogManager.Configuration.AllTargets.Count}");
                }

                nlog.Info($"[XParameter] NLog system initialized successfully. Path: {configPath}");
            }
            else
            {
                Console.WriteLine($"[DIAGNOSTIC] FATAL: NLog.config not found at: {configPath}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[DIAGNOSTIC] FATAL: Exception during NLog Load: {ex.ToString()}");
        }
    }

    public void Add(XObject service)
    {
        service.messenger = this.messenger; // 메신저 주입
        _services.Add(service);
        nlog?.Trace($"[ServiceRegistered] {service.GetType().Name}");
    }

    public void StartAll()
    {
        nlog?.Trace($"[ServicesStarting] Attempting to start {_services.Count} services...");
        foreach (var service in _services)
        {
            try
            {
                nlog?.Trace($"[Service:Start:Begin] {service.GetType().Name} (cid: {service.CID})");
                service.Start();
                nlog?.Trace($"[Service:Start:End] {service.GetType().Name} - SUCCESS");
            }
            catch (Exception ex)
            {
                nlog?.Error(ex, $"[Service:Start:Error] {service.GetType().Name} - FAILED");
            }
        }
        nlog?.Trace("[ServicesStarted] All registered services have been processed.");
    }

    public void StopAll()
    {
        foreach (var service in _services)
        {
            service.Stop();
        }
        nlog?.Trace("[ServicesStopped] All registered services have been stopped.");
    }

    public T? GetService<T>() where T : XObject
    {
        return _services.OfType<T>().FirstOrDefault();
    }

    public void RegisterChannel(XChannelInfo info)
    {
        if (info == null) return;
        if (!Channels.ContainsKey(info.CID)) Channels.Add(info.CID, info);

      
        
        nlog?.Trace($"[ChannelRegistered] ID:{info.CID} | CNO:{info.CNO} | Name:{info.Name} | Type:{info.Type}");
    }





    public XChannelInfo? GetChannel(long channelId)
    {
        return Channels.TryGetValue(channelId, out var info) ? info : null;
    }

    public XChannelInfo? GetChannelByCno(int cno)
    {
        return Channels.Values.FirstOrDefault(c => c.CNO == cno);
    }
}
