//+------------------------------------------------------------------+
//|                                                   CXLoggerUI.mqh |
//|                                  Copyright 2026, Gemini CLI      |
//|                            [v16.0] Fluent API & Multi-Zone Panel |
//+------------------------------------------------------------------+
#ifndef CX_LOGGER_UI_MQH
#define CX_LOGGER_UI_MQH

#include "CXLogEntry.mqh"

// --- [ Zone Type 정의 ] ---
enum ENUM_ZONE_TYPE { ZONE_A, ZONE_B, ZONE_C };

// 전방 선언
class CXLoggerUI;

// --- [ Output Context: p0.a(0).Output(...) 지원용 ] ---
class CXOutputContext {
private:
    int             m_p_idx;
    ENUM_ZONE_TYPE  m_z_type;
    int             m_line;
public:
    CXOutputContext() : m_p_idx(-1), m_z_type(ZONE_A), m_line(0) {}
    void Set(int p, ENUM_ZONE_TYPE z, int l=0) { m_p_idx=p; m_z_type=z; m_line=l; }
    void Output(string msg, color clr = clrNONE);
    
    // 로그 레벨별 전용 메서드 (색상만 적용, 접두어 제거)
    void Trace(string msg)   { Output(msg, clrWheat); }
    void Debug(string msg)   { Output(msg, clrWhite); }
    void Info(string msg)    { Output(msg, clrGold); }
    void Warning(string msg) { Output(msg, clrPink); }
    void Error(string msg)   { Output(msg, clrOrangeRed); }
    void Fatal(string msg)   { Output(msg, clrRed); }
};

// --- [ Panel Proxy: p0, p1, p2 접근용 ] ---
class CXPanelProxy {
private:
    int             m_idx;
    CXOutputContext m_ctx;
public:
    void SetIndex(int i) { m_idx = i; }
    CXOutputContext* a(int line) { m_ctx.Set(m_idx, ZONE_A, line); return GetPointer(m_ctx); }
    CXOutputContext* b()         { m_ctx.Set(m_idx, ZONE_B);       return GetPointer(m_ctx); }
    CXOutputContext* c()         { m_ctx.Set(m_idx, ZONE_C);       return GetPointer(m_ctx); }
};

// --- [ Zone Config & Data ] ---
class CXZone {
private:
    int            m_filled_rows; // 현재 채워진 행 수 (ZONE_B 전용)

public:
    ENUM_ZONE_TYPE type;
    string         font_name;
    int            font_size;
    color          default_color;
    int            max_rows;
    
    string         lines[];
    color          line_colors[];
    int            y_offset;

    CXZone() : font_name("Consolas"), font_size(11), default_color(clrGold), max_rows(1), y_offset(0), m_filled_rows(0) {}

    void InitData() {
        m_filled_rows = 0;
        ArrayResize(lines, max_rows);
        ArrayResize(line_colors, max_rows);
        for(int i=0; i<max_rows; i++) {
            lines[i] = "";
            line_colors[i] = clrNONE;
        }
    }

    void Update(int line, string msg, color clr) {
        if(type == ZONE_B) { // Scrolling Logic
            if(m_filled_rows < max_rows) {
                // 1. 처음에는 순차적으로 채움 (0, 1, 2...)
                lines[m_filled_rows] = msg;
                line_colors[m_filled_rows] = clr;
                m_filled_rows++;
            } else {
                // 2. 꽉 찬 이후부터 스크롤업 (오래된 로그 상단으로 밀어내기)
                for(int i=0; i<max_rows-1; i++) {
                    lines[i] = lines[i+1];
                    line_colors[i] = line_colors[i+1];
                }
                lines[max_rows-1] = msg;
                line_colors[max_rows-1] = clr;
            }
        } else { // Static Logic (A, C)
            if(line >= 0 && line < max_rows) {
                lines[line] = msg;
                line_colors[line] = clr;
            }
        }
    }
};

// --- [ View Panel ] ---
class CXViewPanel {
public:
    int     index;
    CXZone  zoneA, zoneB, zoneC;
    int     x_base, y_base;

    CXViewPanel() : x_base(20), y_base(30) {
        zoneA.type = ZONE_A; zoneA.max_rows = 10;
        zoneB.type = ZONE_B; zoneB.max_rows = 30;
        zoneC.type = ZONE_C; zoneC.max_rows = 1;
    }

    void CalculateLayout(int x, int y) {
        x_base = x; y_base = y;
        zoneA.InitData();
        zoneB.InitData();
        zoneC.InitData();

        int line_h = zoneA.font_size + 5;
        zoneA.y_offset = 0;
        zoneB.y_offset = zoneA.y_offset + (zoneA.max_rows * line_h) + 15;
        
        line_h = zoneB.font_size + 5;
        zoneC.y_offset = zoneB.y_offset + (zoneB.max_rows * line_h) + 15;
    }
};

// --- [ Main UI Controller ] ---
class CXLoggerUI {
private:
    CXViewPanel*    m_panels[];
    int             m_count;
    int             m_curr_p;
    ENUM_ZONE_TYPE  m_curr_z;

    CXLoggerUI() : m_count(0), m_curr_p(0), m_curr_z(ZONE_A) {
        ChartSetInteger(0, CHART_SHOW_GRID, false);
    }

public:
    CXPanelProxy p0, p1, p2, p3; // 편의를 위한 고정 멤버

    static CXLoggerUI* GetInstance() {
        static CXLoggerUI instance;
        return GetPointer(instance);
    }

    ~CXLoggerUI() {
        for(int i=0; i<ArraySize(m_panels); i++) 
            if(CheckPointer(m_panels[i]) == POINTER_DYNAMIC) delete m_panels[i];
    }

    // 범용 패널 접근용 프록시 (내부 임시 객체 활용)
    CXPanelProxy* P(int idx) {
        static CXPanelProxy tempProxy;
        tempProxy.SetIndex(idx);
        return GetPointer(tempProxy);
    }

    // Fluent API: 초기화
    CXLoggerUI* Init(int n) {
        Clear();
        m_count = n;
        ArrayResize(m_panels, n);
        for(int i=0; i<n; i++) {
            m_panels[i] = new CXViewPanel();
            m_panels[i].index = i;
        }
        p0.SetIndex(0); p1.SetIndex(1); p2.SetIndex(2); p3.SetIndex(3);
        return GetPointer(this);
    }

    CXLoggerUI* Panel(int i) { m_curr_p = i; return GetPointer(this); }
    CXLoggerUI* A() { m_curr_z = ZONE_A; return GetPointer(this); }
    CXLoggerUI* B() { m_curr_z = ZONE_B; return GetPointer(this); }
    CXLoggerUI* C() { m_curr_z = ZONE_C; return GetPointer(this); }

    CXLoggerUI* MaxRows(int r) {
        if(m_curr_p < m_count) {
            if(m_curr_z == ZONE_A) m_panels[m_curr_p].zoneA.max_rows = r;
            else if(m_curr_z == ZONE_B) m_panels[m_curr_p].zoneB.max_rows = r;
        }
        return GetPointer(this);
    }

    CXLoggerUI* Color(color c) {
        if(m_curr_p < m_count) {
            if(m_curr_z == ZONE_A) m_panels[m_curr_p].zoneA.default_color = c;
            else if(m_curr_z == ZONE_B) m_panels[m_curr_p].zoneB.default_color = c;
            else if(m_curr_z == ZONE_C) m_panels[m_curr_p].zoneC.default_color = c;
        }
        return GetPointer(this);
    }

    CXLoggerUI* Font(string name, int size) {
        if(m_curr_p < m_count) {
            CXZone* z = (m_curr_z == ZONE_A) ? GetPointer(m_panels[m_curr_p].zoneA) :
                        (m_curr_z == ZONE_B) ? GetPointer(m_panels[m_curr_p].zoneB) :
                                              GetPointer(m_panels[m_curr_p].zoneC);
            z.font_name = name; z.font_size = size;
        }
        return GetPointer(this);
    }

    void Build() {
        int x_start = 20;
        int panel_w = 350; 
        for(int i=0; i<m_count; i++) {
            m_panels[i].CalculateLayout(x_start + (i * panel_w), 30);
        }
    }

    string GetConfigSummary() {
        string s = "--- [CXLoggerUI Configuration Summary] ---\n";
        s += StringFormat("Total Panels: %d\n", m_count);
        for(int i=0; i<m_count; i++) {
            CXViewPanel* p = m_panels[i];
            s += StringFormat(" Panel %d:\n", i);
            s += StringFormat("  - Zone A: %2d rows, Color: 0x%06X\n", p.zoneA.max_rows, p.zoneA.default_color);
            s += StringFormat("  - Zone B: %2d rows, Color: 0x%06X\n", p.zoneB.max_rows, p.zoneB.default_color);
            s += StringFormat("  - Zone C: %2d rows, Color: 0x%06X\n", p.zoneC.max_rows, p.zoneC.default_color);
            s += StringFormat("  - Font  : %s (%d pt)\n", p.zoneA.font_name, p.zoneA.font_size);
        }
        s += "------------------------------------------";
        return s;
    }

    // 내부 출력 로직
    void OutputInternal(int p, ENUM_ZONE_TYPE z, int l, string msg, color clr) {
        if(p < 0 || p >= m_count) return;
        CXZone* zone = (z == ZONE_A) ? GetPointer(m_panels[p].zoneA) :
                       (z == ZONE_B) ? GetPointer(m_panels[p].zoneB) :
                                       GetPointer(m_panels[p].zoneC);
        
        zone.Update(l, msg, clr);
        RenderZone(p, zone);
    }

    void RenderZone(int p_idx, CXZone* zone) {
        CXViewPanel* p = m_panels[p_idx];
        string prefix = StringFormat("AXGS_P%d_Z%d_", p_idx, (int)zone.type);
        int line_h = zone.font_size + 5;

        for(int i=0; i<zone.max_rows; i++) {
            if(zone.lines[i] == "") continue;
            string name = prefix + IntegerToString(i);
            color clr = (zone.line_colors[i] == clrNONE) ? zone.default_color : zone.line_colors[i];
            CreateLabel(name, p.x_base, p.y_base + zone.y_offset + (i * line_h), zone.lines[i], clr, zone.font_name, zone.font_size);
        }
    }

    void CreateLabel(string name, int x, int y, string text, color clr, string font, int size) {
        if(ObjectFind(0, name) < 0) {
            ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        }
        ObjectSetString(0, name, OBJPROP_FONT, font);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    }

    void Clear() {
        ObjectsDeleteAll(0, "AXGS_");
    }
};

// CXOutputContext 구현 (CXLoggerUI 참조 필요)
void CXOutputContext::Output(string msg, color clr = clrNONE) {
    CXLoggerUI::GetInstance().OutputInternal(m_p_idx, m_z_type, m_line, msg, clr);
}

#define XLoggerUI (*CXLoggerUI::GetInstance())

#endif
