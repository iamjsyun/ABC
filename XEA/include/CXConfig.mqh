//+------------------------------------------------------------------+
//|                                                   CXConfig.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_CONFIG_MQH
#define CX_CONFIG_MQH

#include <Object.mqh>
#include <Arrays\ArrayString.mqh>

class CXConfig : public CObject
{
private:
    string m_json_content;

    // JSON 배열 파싱 유틸리티
    void GetJsonArray(string key, CArrayString* target_list)
    {
        target_list.Clear();
        // 키 찾기 (쌍따옴표 포함 또는 미포함 모두 고려)
        string searchKey = "\"" + key + "\"";
        int pos = StringFind(m_json_content, searchKey);
        if(pos < 0) {
            pos = StringFind(m_json_content, key); // 쌍따옴표 없이 다시 시도
            if(pos < 0) return;
        }

        int startBracket = StringFind(m_json_content, "[", pos);
        int endBracket = StringFind(m_json_content, "]", startBracket);
        if(startBracket < 0 || endBracket < 0) return;

        string inner = StringSubstr(m_json_content, startBracket + 1, endBracket - startBracket - 1);
        string parts[];
        int count = StringSplit(inner, ',', parts);
        for(int i=0; i<count; i++)
        {
            string v = parts[i];
            StringTrimLeft(v);
            StringTrimRight(v);
            StringReplace(v, "\"", ""); // Remove double quotes
            StringReplace(v, "\r", ""); // Remove CR
            StringReplace(v, "\n", ""); // Remove NL
            if(v != "") target_list.Add(v);
        }
    }

public:
    CArrayString TicketProcessors;
    CArrayString PositionProcessors;

    // 생성 시 파일 로드 및 파싱
    CXConfig(string file_path)
    {
        ResetLastError();
        int handle = FileOpen(file_path, FILE_READ | FILE_BIN | FILE_COMMON | FILE_SHARE_READ);
        if(handle != INVALID_HANDLE)
        {
            ulong size = FileSize(handle);
            if(size > 0)
            {
                uchar buffer[];
                ArrayResize(buffer, (int)size);
                FileReadArray(handle, buffer);
                m_json_content = CharArrayToString(buffer, 0, WHOLE_ARRAY, CP_UTF8);
                
                // BOM 제거 (UTF-8 BOM: 0xEF, 0xBB, 0xBF)
                if(size >= 3 && buffer[0] == 0xEF && buffer[1] == 0xBB && buffer[2] == 0xBF)
                {
                    m_json_content = CharArrayToString(buffer, 3, WHOLE_ARRAY, CP_UTF8);
                }
            }
            FileClose(handle);

            // 파싱 실행
            if(m_json_content != "")
            {
                // 디버그용 출력
                PrintFormat("[Config] Loaded Content: %s", m_json_content);
                GetJsonArray("TicketProcessors", &TicketProcessors);
                GetJsonArray("PositionProcessors", &PositionProcessors);
            }
            else {
                PrintFormat("[Config] Warning: %s is empty", file_path);
            }
        }
        else
        {
            PrintFormat("[Config] Error: Failed to open %s (Common). ErrorCode: %d", file_path, GetLastError());
        }
    }
};

#endif
