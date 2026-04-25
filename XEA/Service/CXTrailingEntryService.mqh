//+------------------------------------------------------------------+
//|                                     CXTrailingEntryService.mqh   |
//|                                  Copyright 2026, Gemini CLI      |
//+------------------------------------------------------------------+
#ifndef CX_TRAILING_ENTRY_SERVICE_MQH
#define CX_TRAILING_ENTRY_SERVICE_MQH

#include "..\include\ICXProcessor.mqh"
#include "..\Module\CXTrailingEntryInstance.mqh"
#include "..\include\CXDatabase.mqh"

// [Service] 트레일링 진입 관리 서비스
class CXTrailingEntryService : public ICXService
{
private:
    CArrayObj   m_instances;

public:
    CXTrailingEntryService() {}
    ~CXTrailingEntryService() { m_instances.Clear(); }

    virtual void OnTimer(CXParam* xp) { OnUpdate(xp); }

    virtual void OnUpdate(CXParam* xp)
    {
        if(xp == NULL) return;
        xp.Set("found", "false");
        for(int i=0; i<m_instances.Total(); i++) {
            CXTrailingEntryInstance* inst = (CXTrailingEntryInstance*)m_instances.At(i);
            inst.SetFound(xp);
        }

        for(int i=::OrdersTotal()-1; i>=0; i--)
        {
            ulong ticket = ::OrderGetTicket(i);
            if(::OrderSelect(ticket))
            {
                string sid = ::OrderGetString(ORDER_COMMENT);
                if(sid == "" || StringFind(sid, "-") < 0) continue;

                CXTrailingEntryInstance* inst = FindInstance(sid);
                if(inst == NULL) inst = CreateInstance(xp, sid, ticket);

                if(inst != NULL)
                {
                    xp.ticket = ticket;
                    xp.Set("found", "true"); inst.SetFound(xp);
                    inst.Process(xp);
                }
            }
        }

        for(int i=m_instances.Total()-1; i>=0; i--)
        {
            CXTrailingEntryInstance* inst = (CXTrailingEntryInstance*)m_instances.At(i);
            if(!inst.IsFound()) m_instances.Delete(i);
        }
    }

private:
    CXTrailingEntryInstance* FindInstance(string sid)
    {
        for(int i=0; i<m_instances.Total(); i++)
        {
            CXTrailingEntryInstance* inst = (CXTrailingEntryInstance*)m_instances.At(i);
            if(inst.Sid() == sid) return inst;
        }
        return NULL;
    }

    CXTrailingEntryInstance* CreateInstance(CXParam* xp, string sid, ulong ticket)
    {
        if(xp.db == NULL) return NULL;
        ulong _magic = ::OrderGetInteger(ORDER_MAGIC);
        
        xp.QB_Reset().Table("entry_signals").Where("sid", sid);
        int _req = xp.db.Prepare(xp);
        if(_req == INVALID_HANDLE) return NULL;

        CXTrailingEntryInstance* inst = NULL;
        if(::DatabaseRead(_req))
        {
            inst = new CXTrailingEntryInstance(sid, _magic);
            double v_start, v_step, v_limit; int v_interval;
            ::DatabaseColumnDouble(_req, 8, v_start);
            ::DatabaseColumnDouble(_req, 9, v_step);
            ::DatabaseColumnDouble(_req, 10, v_limit);
            ::DatabaseColumnInteger(_req, 11, v_interval);
            
            CXParam p_load;
            p_load.tb_start = (int)v_start; p_load.tb_step = (int)v_step;
            p_load.tb_limit = (int)v_limit; p_load.tb_interval = v_interval;
            p_load.trace = xp.trace;
            inst.SetParams(&p_load);
            m_instances.Add(inst);
        }
        ::DatabaseFinalize(_req);
        return inst;
    }
};

#endif
