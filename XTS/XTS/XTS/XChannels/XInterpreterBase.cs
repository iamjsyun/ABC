using System;
using System.Collections.Generic;
using DevExpress.Mvvm;
using NLog;
using XTS.XModels;

namespace XTS.XChannels;

/// <summary>
/// 텔레그램 채널 해석기를 위한 공통 베이스 클래스
/// </summary>
public abstract class XInterpreterBase : XChannelObject, IDisposable
{
    protected bool _isInitialized = false;
    protected readonly object _syncRoot = new object();
    protected ulong Magic { get; set; } = 0;

    protected XInterpreterBase(XParameter param, XChannelInfo info) : base(param, info) { Magic = (ulong)info.CNO; }

    public override void Start()
    {
        EnsureInitialized();
        nlog.Trace($"[INTERPRETER:START] {GetType().Name} (CNO:{Info.CNO}, Magic:{Magic})");
    }

    public override void Stop() => Dispose();

    public virtual void Dispose()
    {
        lock (_syncRoot)
        {
            if (_isInitialized)
            {
                messenger.Unregister(this);
                _isInitialized = false;
            }
        }
    }

    private void EnsureInitialized()
    {
        if (_isInitialized) return;
        lock (_syncRoot)
        {
            if (_isInitialized) return;
            messenger.Register<XDataObject>(this, "MSG_TO_INTERPRET", OnMessageReceived);
            _isInitialized = true;
        }
    }

    private void OnMessageReceived(XDataObject xdo)
    {
        // 자신의 CNO와 일치하는 메시지만 처리
        if (xdo == null || xdo.CNO != this.Info.CNO) return;
        if (string.IsNullOrWhiteSpace(xdo.Text)) return;

        try
        {
            nlog.Info($"[SIGNAL:STEP-2:PARSE] Interpreter {GetType().Name} started. MsgId:{xdo.MsgId} | CNO:{Info.CNO} | TextLen:{xdo.Text.Length}");
            
            // 구체적인 해석 로직 실행 (하위 클래스에서 구현)
            var signals = Interpret(xdo);

            if (signals != null && signals.Count > 0)
            {
                nlog.Info($"[SIGNAL:STEP-2:PARSE] Success. Extracted {signals.Count} base signals from MsgId:{xdo.MsgId}");
                foreach (var signal in signals)
                {
                    if (signal.Validate())
                    {
                        XDataObject resultXdo = new XDataObject
                        {
                            Sender = this.GetType().Name,
                            CID = xdo.CID,
                            CName = xdo.CName,
                            Text = xdo.Text,
                            MsgId = xdo.MsgId, 
                            Signal = signal,
                            CNO = Info.CNO,
                            CMD = signal.cmd == XCode.CLOSE ? "CLOSE" : "NEW"
                        };

                        nlog.Info($"[SIGNAL:STEP-2:RESULT] Dispatching SID:{signal.sid} | CMD:{resultXdo.CMD} | Price:{signal.price_signal}");
                        messenger.Send(resultXdo, "SIGNAL_INTERPRETED");
                    }
                    else
                    {
                        nlog.Warn($"[SIGNAL:STEP-2:FAIL] Validation failed for SID:{signal.sid} | Reason:{signal.comment}");
                    }
                }
            }
            else
            {
                nlog.Warn($"[SIGNAL:STEP-2:FAIL] No valid signals extracted from MsgId:{xdo.MsgId}. Check interpreter logic.");
            }
        }
        catch (Exception ex)
        {
            nlog.Error(ex, $"[SIGNAL:STEP-2:ERROR] Exception in {GetType().Name} for MsgId:{xdo.MsgId}");
        }
    }

    /// <summary>
    /// 실제 메시지에서 시그널 리스트를 추출하는 추상 메서드
    /// </summary>
    protected abstract List<XSignal> Interpret(XDataObject xdo);

    /// <summary>
    /// 기본 시그널 객체 생성 (공통 속성 미리 설정)
    /// </summary>
    protected XSignal CreateBaseSignal(XDataObject xdo, string symbol = "GOLD#")
    {
        return new XSignal
        {
            msg_id = xdo.MsgId,
            symbol = symbol,
            created = DateTime.Now,
            magic = (long)Magic,
            cno = Info.CNO,
            cmd = XCode.OPEN
        };
    }
}
