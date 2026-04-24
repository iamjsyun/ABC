using DevExpress.Mvvm;
using System.Collections.Concurrent;
using XTS.XModels;
using XTS.XModels.DB;
using NLog;
using System;
using System.Linq;
using System.Collections.Generic;

namespace XTS.XServices;

public class XGatewayService : XChannelObject
{
    public ConcurrentDictionary<string, XDataObject> PendingSignals { get; } = new();
    
    public event Action<XDataObject>? SignalAddedOrUpdated;
    public event Action<string>? SignalRemoved;

    public XGatewayService(XParameter param) : base(param, new XChannelInfo(0, 0, "GATEWAY_HUB", "SYSTEM"))
    {
    }

    public override void Start()
    {
        // 1. 텔레그램 원본 수신 구독
        messenger.Register<XDataObject>(this, "TG_RAW_RECEIVE", true, OnRawMessageReceived);
        
        // 2. 해석 완료된 시그널 구독
        messenger.Register<XDataObject>(this, "SIGNAL_INTERPRETED", true, OnSignalInterpreted);

        nlog.Trace("[Gateway] Service Started. Subscribed to 'TG_RAW_RECEIVE', 'SIGNAL_INTERPRETED'.");
    }

    /// <summary>
    /// EA로부터 신호 상태 업데이트 수신 시 호출 (현재는 로깅 외 기능 없음)
    /// </summary>
    private void OnSignalEaUpdate(XSignal eaSignal)
    {
        // XTG는 더 이상 가격을 갱신하지 않음. 모든 가격 제어는 EA가 수행.
    }

    public override void Stop()
    {
        messenger.Unregister(this);
        nlog.Trace("[Gateway] Service Stopped.");
    }

    /// <summary>
    /// 중앙 라우팅: 수신된 원본 메시지를 분석하여 저장 및 해석 요청 분기
    /// </summary>
    private void OnRawMessageReceived(XDataObject xdo)
    {
        if (xdo == null) return;

        nlog.Info($"[SIGNAL:STEP-1:RAW] New message {{ MsgId={xdo.MsgId}, CID={xdo.CID}, TextLen={xdo.Text?.Length ?? 0} }}");

        // A. 모든 메시지는 DB 로그 기록 요청 (중앙화)
        messenger.Send(xdo, "DB_SAVE_MSG");

        // B. TRADE 채널 메시지인 경우 해석기로 전달
        var info = param.GetChannel(xdo.CID);
        if (info != null)
        {
            if (info.Type.ToUpper() == "TRADE")
            {
                nlog.Info($"[SIGNAL:STEP-1:ROUTE] Routing to interpreter {{ CNO={info.CNO}, Name=\"{info.Name}\", MsgId={xdo.MsgId} }}");
                messenger.Send(xdo, "MSG_TO_INTERPRET");
            }
            else
            {
                nlog.Debug($"[SIGNAL:STEP-1:SKIP] Non-TRADE channel {{ CNO={info.CNO}, Type=\"{info.Type}\", MsgId={xdo.MsgId} }}");
            }
        }
        else
        {
            nlog.Warn($"[SIGNAL:STEP-1:DROP] Unknown channel {{ CID={xdo.CID}, MsgId={xdo.MsgId} }}");
        }
    }

    /// <summary>
    /// 해석 완료된 시그널 처리
    /// </summary>
    private async void OnSignalInterpreted(XDataObject xdo)
    {
        if (xdo?.Signal == null) return;

        var sMaster = xdo.Signal;
        nlog.Info($"[SIGNAL:STEP-3:HUB] Interpreter result {{ SID=\"{sMaster.sid}\", CNO={sMaster.cno}, SNO={sMaster.sno}, MsgId={xdo.MsgId} }}");

        // [SIMULATION MAPPING]
        var channelInfo = param.GetChannelByCno(sMaster.cno);
        int mappedCno = xdo.CNO;
        long mappedCid = xdo.CID;

        if (channelInfo?.RunMode == "Simulation" && !string.IsNullOrEmpty(channelInfo.SimulationMapping))
        {
            var parts = channelInfo.SimulationMapping.Split(',');
            if (parts.Length == 2 && int.TryParse(parts[0].Trim(), out int newCno) && long.TryParse(parts[1].Trim(), out long newCid))
            {
                nlog.Info($"[SIGNAL:STEP-3:MAP] Simulation Triggered {{ FromCNO={channelInfo.CNO}, ToCNO={newCno}, ToCID={newCid} }}");
                
                // 1. 매핑된 채널 정보 주입
                sMaster.cno = newCno;
                mappedCno = newCno;
                mappedCid = newCid;

                // 2. 추적을 위한 태그 삽입 및 SID 재생성
                sMaster.tag = $"MappedFrom:{channelInfo.Name}({channelInfo.CNO})";
                string oldSid = sMaster.sid;
                sMaster.sid = string.Empty;
                sMaster.comment = string.Empty;
                sMaster.Validate(); // 새 CNO 기준으로 SID/GID 재생성

                nlog.Info($"[SIGNAL:STEP-3:MAP] SID Remapped {{ Old=\"{oldSid}\", New=\"{sMaster.sid}\", Comment=\"{sMaster.comment}\" }}");
            }
            else
            {
                nlog.Warn($"[SIGNAL:STEP-3:MAP] Invalid SimulationMapping format {{ CNO={sMaster.cno}, Value=\"{channelInfo.SimulationMapping}\" }}");
            }
        }

        var dbService = param.GetService<XpoSqliteService>();
        if (dbService != null)
        {
            // 1. 순수 원본 신호 정보 및 원본 텍스트 저장 (추적용)
            int rawId = await dbService.SaveRawSignal(sMaster, xdo.Text ?? string.Empty);
            sMaster.raw_id = rawId;
            nlog.Info($"[SIGNAL:STEP-3:RAW_SAVE] Record saved {{ RawId={rawId} }}");
        }

        // 2. [옵션 적용] CNO별 설정에 따라 시그널 변환
        nlog.Info($"[SIGNAL:STEP-4:OPT] Applying options {{ SID=\"{sMaster.sid}\", CNO={sMaster.cno} }}");
        var processedSignal = ApplyChannelOptions(xdo);
        
        if (processedSignal == null)
        {
            nlog.Warn($"[SIGNAL:STEP-4:DROP] Signal dropped by option filtering {{ SID=\"{sMaster.sid}\" }}");
            return;
        }

        nlog.Info($"[SIGNAL:STEP-5:DISPATCH] Dispatching signal {{ SID=\"{processedSignal.sid}\" }}");

        // 3. 생성된 신호(마스터) 처리
        {
            var s = processedSignal;
            // [단일 주입 구조] 신호를 즉시 실행 가능 상태로 설정
            s.updated = DateTime.Now;

            if (s.cmd == XCode.CLOSE)
            {
                nlog.Info($"[SIGNAL:STEP-5:CLOSE] Liquidation request {{ SID=\"{s.sid}\" }}");
                ProcessCloseCommand(s, xdo.MsgId);
                return;
            }

            // 대기열 등록 및 DB 저장 요청
            var signalXdo = new XDataObject 
            { 
                Signal = s, 
                MsgId = xdo.MsgId, 
                Text = xdo.Text,
                CID = mappedCid,
                CNO = mappedCno
            };

            PendingSignals.AddOrUpdate(s.sid, signalXdo, (key, existingVal) => {
                nlog.Info($"[SIGNAL:STEP-5:QUEUE] Updated in gateway queue {{ SID=\"{key}\" }}");
                return signalXdo;
            });
            
            nlog.Info($"[SIGNAL:STEP-5:INJECT] INJECTING {{ SID=\"{s.sid}\", Type={s.type}, Price={s.price_signal}, Lot={s.lot} }}");
            
            // DB 저장 및 EA 전송
            messenger.Send(signalXdo, "DB_SAVE_SIGNAL");
            messenger.Send(signalXdo, "channel_signal_dispatch");

            SignalAddedOrUpdated?.Invoke(signalXdo);
        }
    }

    private void ProcessCloseCommand(XSignal signal, int msgId)
    {
        if (PendingSignals.TryRemove(signal.sid, out var pending))
        {
            nlog.Info($"[SIGNAL:STEP-5:CANCEL] Revoking pending signal {{ SID=\"{signal.sid}\" }}");
            SignalRemoved?.Invoke(signal.sid);
        }
        else
        {
            nlog.Info($"[SIGNAL:STEP-5:LIQUIDATE] Routing CLOSE to DB {{ SID=\"{signal.sid}\" }}");
            var closeXdo = new XDataObject 
            { 
                Signal = signal, 
                CMD = "GROUP_CLOSE",
                MsgId = msgId 
            };
            messenger.Send(closeXdo, "DB_SAVE_SIGNAL");
        }
    }

    private XSignal? ApplyChannelOptions(XDataObject xdo)
    {
        var s = xdo.Signal;
        if (s == null) return null;

        try
        {
            var dbService = param.GetService<XpoSqliteService>();
            var channelInfo = param.GetChannelByCno(s.cno);

            var opt = dbService?.GetOption(s.cno);
            if (opt == null && (channelInfo == null || channelInfo.TradingOptions == null))
            {
                nlog.Debug($"[Gateway:Option] No option or channel trading info found for CNO:{s.cno}. Using original signal.");
                s.Validate();
                return s;
            }

            // 활성화 여부 체크
            if (opt != null)
            {
                bool isActive = (s.dir == 1) ? opt.is_buy_active : opt.is_sell_active;
                if (!isActive)
                {
                    nlog.Info($"[Gateway:Option] Channel CNO:{s.cno} {(s.dir == 1 ? "BUY" : "SELL")} is INACTIVE in DB. Skipping signal.");
                    return null;
                }
            }
            else if (channelInfo?.TradingOptions != null)
            {
                if (!channelInfo.TradingOptions.IsActive)
                {
                    nlog.Info($"[Gateway:Config] Channel CNO:{s.cno} is INACTIVE in config. Skipping signal.");
                    return null;
                }
            }

            if (s.cmd == XCode.CLOSE)
            {
                s.Validate();
                return s;
            }

            // 기본값 설정
            double point = 0.01; // Gold standard
            double basePrice = s.price_signal;
            double currentOffset = 500;
            int currentTbStart = 500;
            int currentTbStep = 100;
            int currentTbLimit = 200;
            int currentTsStart = 500;
            int currentTsStep = 100;

            // G0(Master) 정보 가져오기
            var profileFromDb = dbService?.GetGridProfile(s.cno, s.dir, 0);
            var profileFromConfig = channelInfo?.TradingOptions?.GetProfiles(s.cno, s.dir).FirstOrDefault(p => p.gno == 0);

            if (profileFromConfig != null) {
                s.lot = profileFromConfig.lot; s.tp = profileFromConfig.tp; s.sl = profileFromConfig.sl;
                s.type = profileFromConfig.type;
                currentOffset = profileFromConfig.offset;
                currentTbStart = profileFromConfig.ts_trigger;
                currentTbStep = profileFromConfig.ts_step;
                currentTbLimit = profileFromConfig.gap_min;
            }
            else if (profileFromDb != null) {
                s.lot = profileFromDb.lot; s.tp = profileFromDb.tp; s.sl = profileFromDb.sl;
                s.type = profileFromDb.type;
                currentOffset = profileFromDb.offset;
                currentTbStart = profileFromDb.ts_trigger;
                currentTbStep = profileFromDb.ts_step;
                currentTbLimit = profileFromDb.gap_min;
            }
            else if (opt != null) {
                s.lot = opt.lot_value; s.tp = opt.tp_points; s.sl = opt.sl_points;
                s.type = XCode.TYPE_MARKET; 
                currentOffset = (s.dir == 1) ? opt.buy_entry_offset : opt.sell_entry_offset;
                currentTbStart = opt.ts_trigger;
                currentTbStep = opt.ts_step;
                currentTbLimit = opt.gap_min;
            }

            s.gno = 0;

            // 신규 규격 필드 주입
            s.price_signal = basePrice;
            s.offset = currentOffset;
            s.te_start = currentTbStart;
            s.te_step = currentTbStep;
            s.te_limit = currentTbLimit;
            s.ts_start = (int)currentTsStart;
            s.ts_step = (int)currentTsStep;

            // UI/참고용 가격 계산 (기준가 + 오프셋)
            if (s.dir == 1) s.price_signal = Math.Round(basePrice - (s.offset * point), 2);
            else if (s.dir == 2) s.price_signal = Math.Round(basePrice + (s.offset * point), 2);

            // [사용자 요청] 전략 매개변수(Args) 생성: GNO;Type;Lot;Offset;TeStart;TeStep;TeLimit
            s.args = $"{s.gno};{s.type};{s.lot:F2};{(int)s.offset};{s.te_start};{s.te_step};{s.te_limit}";

            s.Validate();
            return s;
        }
        catch (Exception ex)
        {
            nlog.Error(ex, $"[Gateway:Option] Error applying options for CNO:{s.cno}");
            s.Validate();
            return s; 
        }
    }

    public XDataObject? GetNextSignal()
    {
        if (PendingSignals.IsEmpty) return null;

        var firstKey = PendingSignals.Keys.FirstOrDefault();
        if (firstKey != null && PendingSignals.TryRemove(firstKey, out var xdo))
        {
            nlog.Info($"[Gateway] Dequeued SID:{xdo.Signal?.sid}. Remaining: {PendingSignals.Count}");
            SignalRemoved?.Invoke(firstKey);
            return xdo;
        }
        return null;
    }
}
