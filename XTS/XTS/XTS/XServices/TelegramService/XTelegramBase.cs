using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Timers;
using System.Windows;
using TL;
using WTelegram;
using XTS.XModels;

namespace XTS.XServices.TelegramService;

public class XTelegramBase : XChannelObject, IDisposable
{
    // public event Action<XDataObject, string>? OnDataEgress;

    private Client? _client;
    public static Client? Client { get; private set; }

    private readonly System.Timers.Timer _timer;
    private readonly SemaphoreSlim _loginLock = new SemaphoreSlim(1, 1);
    private bool _isDisposed = false;
    private readonly object _syncRoot = new object();

    public int Interval { get; set; } = 30000;
    public bool Auto { get; set; } = true;


    public string? TgApiId { get; set; } = "9150286";
    public string? TgApiHash { get; set; } = "bf8036c4b7390a0abc2d3977874f18d0";
    public string? TgPhoneNumber { get; set; } = "+821071697000";
    public string? TgVerificationCode { get; set; }

    public XTelegramBase(XParameter param) : base(param, new XChannelInfo(0, 0, "Telegram Service", "SYSTEM"))
    {
        _timer = new System.Timers.Timer();
        _timer.Elapsed += OnTimerElapsed;
    }

 

    protected virtual void RegisterMessenger()
    {
    }

    public override void ProcessSignal(XDataObject xdo)
    {
        if (xdo == null || xdo.CID != this.CID) return;
    }

    private async void OnTimerElapsed(object? sender, ElapsedEventArgs e)
    {
        if (_client == null || _isDisposed) return;
        try
        {
            if (_client.Disconnected)
            {
                if (Auto)
                {
                    nlog.Warn("[TG:STATUS] Client disconnected. Attempting auto-login...");
                    await _client.LoginUserIfNeeded();
                }
            }
            else 
            {
                nlog.Trace("[TG:STATUS] Client is active. Sending keep-alive ping.");
                await _client.Ping(DateTime.Now.Ticks);
            }
        }
        catch (Exception ex) { nlog?.Error(ex, "[TG:TIMER] Error during status check/ping"); }
    }

    public override void Start()
    {
        nlog.Info("[TG:START] Telegram Service Start requested.");
        _ = StartClientAsync();
    }

    public override void Stop()
    {
        nlog.Info("[TG:STOP] Telegram Service Stop requested.");
        Dispose();
    }

    public void Dispose()
    {
        if (_isDisposed) return;
        lock (_syncRoot)
        {
            if (_isDisposed) return;
            _isDisposed = true;
            _timer?.Stop();
            _timer?.Dispose();
            _client?.Dispose();
            nlog?.Info($"[TG:DISPOSE] {GetType().Name} Disposed (CID: {CID})");
        }
    }

    private async Task StartClientAsync()
    {
        if (string.IsNullOrEmpty(TgApiId)) 
        { 
            nlog?.Fatal("[TG:INIT] TgApiId is not set. Aborting startup."); 
            return; 
        }

        nlog.Info($"[TG:INIT] Initializing WTelegram Client (Phone: {TgPhoneNumber})");

        await _loginLock.WaitAsync();
        try
        {
            if (_client != null && !_client.Disconnected) 
            {
                nlog.Info("[TG:INIT] Client is already connected.");
                return;
            }
            
            _client ??= new Client(what => what switch
            {
                "api_id" => TgApiId,
                "api_hash" => TgApiHash,
                "phone_number" => TgPhoneNumber,        
                "verification_code" => TgVerificationCode ?? Microsoft.VisualBasic.Interaction.InputBox("Enter Telegram verification code:", "XTG Login", ""),
                _ => null
            });

            // [중요] 로그인 시도 전에 이벤트 핸들러를 먼저 등록해야 초기 업데이트를 놓치지 않음
            _client.OnUpdates -= HandleUpdate;
            _client.OnUpdates += HandleUpdate;
            nlog.Debug("[TG:EVENT] Update handler registered before login.");
            
            nlog.Info("[TG:LOGIN] Attempting to login...");
            var status = await _client.LoginUserIfNeeded();
            
            if (_client.Disconnected)
            {
                nlog.Error($"[TG:LOGIN] Login failed. Client state: Disconnected. Status: {status}");
                return;
            }

            nlog.Info($"[TG:LOGIN] Success. Logged in as: {_client.User}");

            _timer.Interval = Interval;
            _timer.Start();
            nlog.Debug($"[TG:TIMER] Auto-reconnect timer started.");

            Client = _client;
        }
        catch (Exception ex) 
        { 
            nlog?.Fatal(ex, "[TG:FATAL] Exception during StartClientAsync"); 
            MessageBox.Show($"Telegram 로그인 실패:\n{ex.Message}", "Login Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally { _loginLock.Release(); }
    }

    protected virtual Task HandleUpdate(UpdatesBase updates)
    {
        nlog.Trace($"[TG:BASE_UPDATE] Base HandleUpdate reached. Type: {updates?.GetType().Name}");
        return Task.CompletedTask;
    }
}
