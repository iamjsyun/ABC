using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using DevExpress.Mvvm;
using TL;
using XTS.XModels;

namespace XTS.XServices.TelegramService;

public class XTelegram : XTelegramBase
{
    public XTelegram(XParameter param) : base(param) 
    {
    }
   
    public override void Start()
    {
        base.Start();
        nlog?.Trace("[XTelegram] Service class specific Start completed.");
    }

    public override void ProcessSignal(XDataObject xdo)
    {
        if (xdo == null || xdo.CID != this.CID) return;
        nlog?.Info($"[SIGNAL_PROCESS] CID:{CID} Received Signal Context: {xdo.Text}");
    }

    protected override Task HandleUpdate(UpdatesBase updates)
    {
        if (updates == null) return Task.CompletedTask;

        // [진단 로그] 모든 업데이트 진입 기록
        if (updates.UpdateList.Length > 0)
        {
            nlog.Debug($"[TG:H_UPDATE] Received {updates.UpdateList.Length} updates. Type: {updates.GetType().Name}");
        }

        foreach (var update in updates.UpdateList)
        {
            TL.Message? msg = null;

            // 1. 업데이트 타입별 메시지 추출
            if (update is UpdateNewChannelMessage uncm && uncm.message is TL.Message m1) msg = m1;
            else if (update is UpdateNewMessage unm && unm.message is TL.Message m2) msg = m2;

            if (msg == null)
            {
                // 메시지가 포함되지 않은 일반 업데이트 (UserTyping 등)
                continue;
            }
            
            // 2. Peer 정보 분석 및 ID 추출
            long rawId = msg.peer_id.ID;
            long peerId = rawId;

            // 텔레그램 API 특성에 따른 ID 보정 (정규화된 매칭 시도)
            if (!param.Channels.ContainsKey(peerId))
            {
                // 1. 단순 접두사 보정 시도
                long channelId = -1000000000000L - rawId;
                if (param.Channels.ContainsKey(channelId)) peerId = channelId;
                else if (param.Channels.ContainsKey(-rawId)) peerId = -rawId;
                else
                {
                    // 2. [강력한 매칭] 절대값 하위 10자리(또는 전체)가 일치하는 채널 검색
                    // (3778889507와 같은 ID와 -1003778889507와 같은 CID 매칭 보장)
                    var matchedInfo = param.Channels.Values.FirstOrDefault(c => 
                        c.CID == rawId || 
                        Math.Abs(c.CID % 10000000000L) == Math.Abs(rawId % 10000000000L));
                    
                    if (matchedInfo != null)
                    {
                        peerId = matchedInfo.CID;
                        nlog.Info($"[SIGNAL:STEP-0:MATCH] PeerID {rawId} fuzzy-matched to Registered CID {peerId} ({matchedInfo.Name})");
                    }
                }
            }

            string summary = msg.message.Replace("\n", " ");
            if (summary.Length > 50) summary = summary.Substring(0, 50) + "...";

            nlog.Info($"[SIGNAL:STEP-0:RECEIVE] TG Update Detected. MsgId:{msg.id} | RawPeer:{rawId} | Text:{summary}");

            // 3. 채널 등록 여부 확인
            var info = param.GetChannel(peerId);
            if (info == null)
            {
                nlog.Warn($"[SIGNAL:STEP-0:FILTER] Dropping Msg from unregistered PeerID:{peerId}. MsgId:{msg.id}");
                continue;
            }
            
            // 4. 채팅 세부 정보 획득
            string channelTitle = "Unknown";
            if (updates.Chats.TryGetValue(rawId, out var chat)) channelTitle = chat.Title ?? "Unknown";

            nlog.Info($"[SIGNAL:STEP-0:ACCEPT] CID:{peerId} | CNO:{info.CNO} | Name:{info.Name} | MsgId:{msg.id}");

            // 5. 데이터 객체 생성 및 전송
            XDataObject xdo = new XDataObject()
            {
                Sender = this.GetType().Name,
                CID = peerId,
                Text = msg.message,
                CName = channelTitle,
                CNO = info.CNO,
                Timestamp = msg.date,
                MsgId = msg.id
            };

            try
            {
                messenger.Send(xdo, "TG_RAW_RECEIVE");
                nlog.Debug($"[SIGNAL:STEP-0:DISPATCH] Dispatched MsgId:{msg.id} to Gateway Service.");
            }
            catch (Exception ex)
            {
                nlog.Error(ex, $"[TG:DISPATCH] Dispatch Error. MsgId:{msg.id}");
            }
        }

        return Task.CompletedTask;
    }
}
