"""Finite contact communication and possession; no negotiation or exploration hook."""
from copy import deepcopy
import json
from pathlib import Path
from runtime.layered_body import step
from .voice_rescue import RescueWorld


class CommunicationWorld(RescueWorld):
    def __init__(self):
        super().__init__('contact-communication')
        self.inbox={a:[] for a in self.agents};self.hearing={a:True for a in self.agents}
        self.communication_receipts={};self.consumed=0;self.answered=set()

    def contact(self,aid,target):
        return target in {c['ref'] for c in super().observe_rescue(aid)['near']}

    def observe_communication(self,aid):
        contacts=super().observe_rescue(aid)['near']
        return dict(self_id=aid,body=deepcopy(self.bodies[aid]),inventory=self.agents[aid]['inventory'],
                    others=[dict(ref=c['ref'],holding_food=self.agents[c['ref']]['inventory']>0) for c in contacts],
                    messages=deepcopy([m for m in self.inbox[aid] if 0<=self.seconds-m['time']<3]))

    def communicate(self,aid,op,action,target=None,reply_to=None):
        with self.rescue_lock:
            request=(action,target,reply_to);key=(aid,op)
            if key in self.communication_receipts:
                old,r=self.communication_receipts[key]
                if old!=request:raise ValueError('communication_conflict')
                return deepcopy(r)
            if aid not in self.agents or not isinstance(op,str) or not op:raise ValueError('identity')
            if len(self.communication_receipts)>=64:raise ValueError('capacity')
            if action not in ('request','give','refuse','reach','warn','withdraw','eat','wait'):raise ValueError('action')
            if target is not None and (target==aid or target not in self.agents):raise ValueError('target')
            status='unavailable';a=self.agents[aid]
            messages=self.observe_communication(aid)['messages']
            antecedent=next((m for m in messages if m['id']==reply_to and m['sender']==target),None)
            contact=target is not None and self.contact(aid,target)
            kind=None
            if action in ('wait','withdraw'):status=action
            elif action=='eat':
                self.bodies[aid],result=step(self.bodies[aid],'eat',food_available=a['inventory']>0)
                a['inventory']-=result['food_consumed'];self.consumed+=result['food_consumed'];status=result['status']
            elif contact:
                if action in ('request','reach'):kind=action;status='expressed'
                elif action in ('give','refuse') and antecedent and antecedent['kind']=='request' and (aid,reply_to) not in self.answered:
                    if action=='refuse':kind='refuse';status='expressed'
                    elif a['inventory']>0:
                        a['inventory']-=1;self.agents[target]['inventory']+=1;kind='given';status='transferred'
                elif action=='warn' and antecedent and antecedent['kind']=='reach':kind='warn';status='expressed'
            if kind in ('given','refuse'):self.answered.add((aid,reply_to))
            # Speech needs reception; reaching and giving are visible contact actions.
            if kind and (kind in ('reach','given') or self.hearing[target]):
                self.inbox[target]=[m for m in self.inbox[target] if self.seconds-m['time']<3]
                self.inbox[target].append(dict(id=f'{aid}:{op}',sender=aid,kind=kind,reply_to=reply_to,time=self.seconds))
            r=dict(agent=aid,operation=op,action=action,status=status,time=self.seconds)
            self.communication_receipts[key]=(request,deepcopy(r))
            return r


def respond(observation,share=True,heed_warning=True):
    """Initial response abilities. Parameters are fixture tendencies, not learned traits."""
    for m in reversed(observation['messages']):
        if m['kind']=='warn':return dict(action='withdraw' if heed_warning else 'reach',target=m['sender'],reply_to=m['id'])
        if m['kind']=='reach':return dict(action='warn',target=m['sender'],reply_to=m['id'])
        if m['kind']=='request':return dict(action='give' if share and observation['inventory'] else 'refuse',target=m['sender'],reply_to=m['id'])
    return dict(action='wait')


def scenario(mode):
    if mode not in ('give','refuse','unheard','warn_stop','warn_continue'):raise ValueError('mode')
    w=CommunicationWorld();w.objects=[]
    for i,a in enumerate(w.agents.values()):a.update(x=i*.4,z=0.,inventory=0)
    w.agents['npc_b']['inventory']=1
    w.bodies['npc_a']['reserve']=50.
    w.hearing['npc_b']=mode!='unheard'
    records=[]
    def act(aid,op,decision):
        before=w.observe_communication(aid);r=w.communicate(aid,op,**decision)
        records.append(dict(observation=before,decision=decision,result=r))
    act('npc_a','start',dict(action='reach' if mode.startswith('warn') else 'request',target='npc_b'))
    w.seconds=1
    act('npc_b','response',respond(w.observe_communication('npc_b'),share=mode!='refuse'))
    w.seconds=2
    received=w.observe_communication('npc_a')
    if mode.startswith('warn'):decision=respond(received,heed_warning=mode=='warn_stop')
    elif received['inventory']:decision=dict(action='eat')
    else:decision=dict(action='wait')
    act('npc_a','next',decision)
    return dict(records=records,requester_messages=received['messages'],
                inventory={a:b['inventory'] for a,b in w.agents.items()},consumed=w.consumed,
                requester_reserve=w.bodies['npc_a']['reserve'])


def experiment():return {mode:scenario(mode) for mode in ('give','refuse','unheard','warn_stop','warn_continue')}


if __name__=='__main__':
    report=experiment()
    Path('tests/fixtures/minimal_communication.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print({k:[r['decision']['action'] for r in v['records']] for k,v in report.items()})
