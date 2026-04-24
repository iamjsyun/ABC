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
        string searchKey = """ + key + """;
        int pos = StringFind(m_json_content, searchKey);
        if(pos < 0) return;

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
            StringReplace(v, "'", ""); // " 문자를 작은따옴표로 대체
            if(v != "") target_list.Add(v);
        }
    }

public:
    CArrayString TicketProcessors;
    CArrayString PositionProcessors;

    // 생성 시 파일 로드 및 파싱
    CXConfig(string file_path)
    {
        int handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_COMMON);
        if(handle != INVALID_HANDLE)
        {
            while(!FileIsEnding(handle))
            {
                m_json_content += FileReadString(handle);
            }
            FileClose(handle);

            // 파싱 실행
            GetJsonArray("TicketProcessors", &TicketProcessors);
            GetJsonArray("PositionProcessors", &PositionProcessors);
        }
        else
        {
            PrintFormat("[Config] Error: Failed to open %s", file_path);
        }
    }
};

#endif
