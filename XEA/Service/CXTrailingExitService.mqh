//+------------------------------------------------------------------+
//|                                      CXTrailingExitService.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_EXIT_SERVICE_MQH
#define CX_TRAILING_EXIT_SERVICE_MQH

#include <Arrays\ArrayObj.mqh>
#include "..\include\CXParam.mqh"
#include "..\include\ICXProcessor.mqh"
#include "..\Module\CXTrailingExitInstance.mqh"
#include "..\include\CXDatabase.mqh"

// [Service] 트레일링 청산(Trailing Stop) 관리 서비스
class CXTrailingExitService : public ICXService
{
private:
    CArrayObj   m_instances;

public:
    CXTrailingExitService() {}
    ~CXTrailingExitService() { m_instances.Clear(); }

    virtual void OnTimer(CXParam* xp) { OnUpdate(xp); }

    virtual void OnUpdate(CXParam* xp)
    {
        if(xp == NULL) return;
        for(int i=0; i<m_instances.Total(); i++) {
            CXTrailingExitInstance* inst = (CXTrailingExitInstance*)m_instances.At(i);
            inst.SetFound(false);
        }

        for(int i=::PositionsTotal()-1; i>=0; i--)
        {
            ulong ticket = ::PositionGetTicket(i);
            if(::PositionSelectByTicket(ticket))
            {
                string sid = ::PositionGetString(POSITION_COMMENT);
                if(sid == "" || StringFind(sid, "-") < 0) continue;

                CXTrailingExitInstance* inst = FindInstance(sid);
                if(inst == NULL) inst = CreateInstance(xp, sid, ticket);

                if(inst != NULL)
                {
                    xp.ticket = ticket;
                    inst.SetFound(true);
                    inst.Process(xp);
                }
            }
        }

        for(int i=m_instances.Total()-1; i>=0; i--)
        {
            CXTrailingExitInstance* inst = (CXTrailingExitInstance*)m_instances.At(i);
            if(!inst.IsFound()) m_instances.Delete(i);
        }
    }

private:
    CXTrailingExitInstance* FindInstance(string sid)
    {
        for(int i=0; i<m_instances.Total(); i++)
        {
            CXTrailingExitInstance* inst = (CXTrailingExitInstance*)m_instances.At(i);
            if(inst.Sid() == sid) return inst;
        }
        return NULL;
    }

    CXTrailingExitInstance* CreateInstance(CXParam* xp, string sid, ulong ticket)
    {
        if(xp.db == NULL) return NULL;
        ulong _magic = ::PositionGetInteger(POSITION_MAGIC);
        
        xp.QB_Reset().Table("entry_signals").Where("sid", sid);
        int _req = xp.db.Prepare(xp);
        if(_req == INVALID_HANDLE) return NULL;

        CXTrailingExitInstance* inst = NULL;
        if(::DatabaseRead(_req))
        {
            inst = new CXTrailingExitInstance(sid, _magic);
            int v_ts_start, v_ts_step;
            ::DatabaseColumnInteger(_req, 15, v_ts_start); 
            ::DatabaseColumnInteger(_req, 16, v_ts_step);  
            
            CXParam p_load;
            p_load.ts_start = v_ts_start; p_load.ts_step = v_ts_step;
            inst.SetParams(&p_load);
            m_instances.Add(inst);
        }
        ::DatabaseFinalize(_req);
        return inst;
    }
};

#endif
