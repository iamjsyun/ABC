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
    static CXMessageHub* Default()
    {
        if(m_instance == NULL) m_instance = new CXMessageHub();
        return m_instance;
    }

    // 메시지 구독 등록
    void Register(int msg_id, ICXReceiver* receiver)
    {
        if(receiver == NULL) return;
        
        // 중복 체크
        for(int i=0; i<m_subscriptions.Total(); i++)
        {
            CSubscription* sub = (CSubscription*)m_subscriptions.At(i);
            if(sub.msg_id == msg_id && sub.receiver == receiver) return;
        }
        
        m_subscriptions.Add(new CSubscription(msg_id, receiver));
    }

    // 메시지 구독 해제
    void Unregister(int msg_id, ICXReceiver* receiver)
    {
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
    void Send(int msg_id, CObject* message)
    {
        for(int i=0; i<m_subscriptions.Total(); i++)
        {
            CSubscription* sub = (CSubscription*)m_subscriptions.At(i);
            if(sub.msg_id == msg_id && sub.receiver != NULL)
            {
                sub.receiver.OnReceiveMessage(msg_id, message);
            }
        }
    }

    // 정적 인스턴스 해제 (프로그램 종료 시 호출 권장)
    static void Release()
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
