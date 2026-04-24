//+------------------------------------------------------------------+
//|                                              CXMessageHub.mqh    |
//|                                  Copyright 2026, Gemini CLI      |
//|                                  Last Modified: 2026-04-24 10:15:00 |
//+------------------------------------------------------------------+
#ifndef CX_MESSAGE_HUB_MQH
#define CX_MESSAGE_HUB_MQH

#include <Arrays\ArrayObj.mqh>
#include "ICXReceiver.mqh"

// 구독자 정보를 저장하기 위한 래퍼 클래스
class CSubscription : public CObject
{
public:
    int             msg_id;
    ICXReceiver*    receiver;

    CSubscription(int _id, ICXReceiver* _rcv) : msg_id(_id), receiver(_rcv) {}
};

// [Mediator] Central Message Hub (Singleton)
class CXMessageHub
{
private:
    static CXMessageHub* m_instance;
    CArrayObj           m_subscriptions;

    CXMessageHub() {}
    ~CXMessageHub() { m_subscriptions.Clear(); }

public:
    static CXMessageHub* Default(CXParam* xp)
    {
        if(m_instance == NULL) m_instance = new CXMessageHub();
        return m_instance;
    }

    // 메시지 구독 등록
    void Register(CXParam* xp)
    {
        if(xp == NULL || xp.receiver == NULL) return;
        int msg_id = xp.msg_id;
        ICXReceiver* receiver = xp.receiver;
        
        // 중복 체크
        for(int i=0; i<m_subscriptions.Total(); i++)
        {
            CSubscription* sub = (CSubscription*)m_subscriptions.At(i);
            if(sub.msg_id == msg_id && sub.receiver == receiver) return;
        }
        
        m_subscriptions.Add(new CSubscription(msg_id, receiver));
    }

    // 메시지 구독 해제
    void Unregister(CXParam* xp)
    {
        if(xp == NULL) return;
        int msg_id = xp.msg_id;
        ICXReceiver* receiver = xp.receiver;

        for(int i=0; i<m_subscriptions.Total(); i++)
        {
            CSubscription* sub = (CSubscription*)m_subscriptions.At(i);
            if(sub.msg_id == msg_id && sub.receiver == receiver)
            {
                m_subscriptions.Delete(i);
                return;
            }
        }
    }

    // 메시지 전송
    void Send(CXParam* xp)
    {
        if(xp == NULL) return;
        int msg_id = xp.msg_id;

        for(int i=0; i<m_subscriptions.Total(); i++)
        {
            CSubscription* sub = (CSubscription*)m_subscriptions.At(i);
            if(sub.msg_id == msg_id && sub.receiver != NULL)
            {
                sub.receiver.OnReceiveMessage(xp);
            }
        }
    }

    // 정적 인스턴스 해제 (프로그램 종료 시 호출 권장)
    static void Release(CXParam* xp)
    {
        if(m_instance != NULL)
        {
            delete m_instance;
            m_instance = NULL;
        }
    }
};

// 정적 변수 초기화
CXMessageHub* CXMessageHub::m_instance = NULL;

#endif
