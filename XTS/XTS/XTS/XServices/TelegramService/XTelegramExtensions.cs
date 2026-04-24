// Last Modified: 2026-03-06 13:05:00
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using TL;

namespace XTS.XServices.TelegramService;

public static class XTelegramExtensions
{
    public static async Task ExportChannelHistoryAsync(this XTelegram xTelegram, long channelId, int messageCount)
    {
        var client = XTelegram.Client;
        var logger = xTelegram.nlog;

        if (client == null || client.Disconnected)
        {
            logger.Error("텔레그램 클라이언트가 연결되어 있지 않습니다.");
            return;
        }

        try
        {
            var dialogsBase = await client.Messages_GetDialogs();
            Dictionary<long, ChatBase> allChats;

            if (dialogsBase is Messages_Dialogs dialogs) allChats = dialogs.chats;
            else if (dialogsBase is Messages_DialogsSlice slice) allChats = slice.chats;
            else allChats = new Dictionary<long, ChatBase>();

            var targetChat = allChats.Values.FirstOrDefault(x => x.ID == channelId);

            if (targetChat == null)
            {
                logger.Error($"ID: {channelId} 채널을 찾을 수 없습니다.");
                return;
            }

            logger.Info($"{targetChat.Title} ({channelId}) 데이터 수집 시작...");

            List<TL.Message> allMessages = new List<TL.Message>();
            int offsetId = 0;
            int remaining = messageCount;

            while (remaining > 0)
            {
                int limit = Math.Min(remaining, 100);
                var history = await client.Messages_GetHistory(targetChat, offset_id: offsetId, limit: limit);

                IList<MessageBase> msgs;
                if (history is Messages_ChannelMessages cm) msgs = cm.messages;
                else if (history is Messages_Messages m) msgs = m.messages;
                else break;

                if (msgs == null || msgs.Count == 0) break;

                var pageMessages = msgs.OfType<TL.Message>().ToList();
                if (pageMessages.Count > 0)
                {
                    allMessages.AddRange(pageMessages);
                    offsetId = pageMessages.Last().ID;
                    remaining -= pageMessages.Count;
                }
                else break;

                await Task.Delay(200);
            }

            if (allMessages.Count > 0)
            {
                var lines = allMessages
                    .OrderBy(m => m.Date)
                    .Select(m => 
                        $"==================================================" + Environment.NewLine +
                        $"[MSG_ID: {m.ID}] [TIME: {m.Date.ToLocalTime():yyyy-MM-dd HH:mm:ss}]" + Environment.NewLine +
                        $"--------------------------------------------------" + Environment.NewLine +
                        $"{m.message}" + Environment.NewLine +
                        $"==================================================" + Environment.NewLine + Environment.NewLine)
                    .Where(txt => !string.IsNullOrWhiteSpace(txt))
                    .ToList();

                string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
                string logPath = Path.Combine(baseDirectory, "_export");
                if (!Directory.Exists(logPath))
                {
                    Directory.CreateDirectory(logPath);
                    logger.Info($"_export 폴더를 생성했습니다: {logPath}");
                }
                string fileName = $"export_{channelId}.txt";
                string fullPath = Path.Combine(logPath, fileName);
                await File.WriteAllLinesAsync(fullPath, lines);
                logger.Info($"저장 완료: {fullPath} (총 {lines.Count}라인)");
            }
            else
            {
                logger.Warn("추출된 메시지가 없습니다.");
            }
        }
        catch (Exception ex)
        {
            logger.Error(ex, "Export 중 치명적 오류 발생");
        }
    }

    public static async Task<List<TL.Message>> GetMessagesByUsername(this XTelegram xTelegram, string username, int targetCount = 1000)
    {
        var resultList = new List<TL.Message>();
        var client = XTelegram.Client;
        var logger = xTelegram.nlog;
        long actualChannelId = 0;
        int offsetId = 0;

        if (client == null || client.Disconnected)
        {
            logger.Error("텔레그램 클라이언트가 연결되어 있지 않습니다.");
            return resultList;
        }

        try
        {
            var resolved = await client.Contacts_ResolveUsername(username);

            if (resolved.peer is PeerChannel peerChannel &&
                resolved.chats.TryGetValue(peerChannel.channel_id, out var chatBase) &&
                chatBase is TL.Channel channel)
            {
                actualChannelId = channel.id;
                var inputPeer = new InputPeerChannel(channel.id, channel.access_hash);

                while (resultList.Count < targetCount)
                {
                    int limit = Math.Min(100, targetCount - resultList.Count);
                    var history = await client.Messages_GetHistory(inputPeer, limit: limit, offset_id: offsetId);

                    if (history is Messages_ChannelMessages channelMessages && channelMessages.messages.Length > 0)
                    {
                        var batch = channelMessages.messages.OfType<TL.Message>().ToList();
                        if (batch.Count == 0) break;

                        resultList.AddRange(batch);
                        offsetId = batch.Last().id;
                        await Task.Delay(100);
                    }
                    else break;
                }
            }

            if (resultList.Count > 0 && actualChannelId != 0)
            {
                var lines = resultList
                             .OrderBy(m => m.Date)
                             .Select(m => $"[{m.Date.ToLocalTime():yyyy-MM-dd HH:mm:ss}]{Environment.NewLine}{m.message}{Environment.NewLine}")
                             .Where(txt => !string.IsNullOrWhiteSpace(txt))
                             .ToList();

                string historyPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "History");
                if (!Directory.Exists(historyPath)) Directory.CreateDirectory(historyPath);

                string fileName = $"History_{actualChannelId}_{DateTime.Now:yyyyMMdd_HHmmss}.txt";
                string fullPath = Path.Combine(historyPath, fileName);

                await File.WriteAllLinesAsync(fullPath, lines);
                logger.Info($"저장 완료: {fullPath} (총 {resultList.Count}개)");
            }
        }
        catch (Exception ex)
        {
            logger.Error(ex, $"[TelegramExtensions] 오류: {ex.Message}");
            throw;
        }

        return resultList;
    }
}
