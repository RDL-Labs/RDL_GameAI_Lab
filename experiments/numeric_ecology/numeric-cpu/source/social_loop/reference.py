"""A1 calls production functions, not an alternate Python model."""
from copy import deepcopy
from types import SimpleNamespace
from runtime import goal_difference as goal, aid_method_pressure as aid, social_sleep as social
from runtime.harvest_sleep import accept_rest_result
from runtime.layered_body import step
from runtime.lw_time import DAY_US, SLEEP_REST_US
from integrations.lightweight.minimal_communication import CommunicationWorld, respond

IDS=('npc_a','npc_b','npc_c')


def sleeper(day,start,rest=0):
    cycle=dict(day=day,status='pending',rest_us=rest,records=[],source='night',result=None,
               relation_materials=dict(records=[],window={}),relation_review=None)
    return SimpleNamespace(sleep_receipt_intake=True,results={},decisions={},
                           learning=dict(sleep=dict(cycle=cycle,completed=[])),model=None)


def receipt(a,now,phase='night',status='waited',pose=True,kind='wait',accepted=True):
    p=dict(observation_id=f'o:{now}',capture_us=now,pose_ref='pose',body_revision=0)
    c=dict(operation_id=f'op:{now}',kind=kind)
    r=dict(executed_us=now+1_000_000,status=status,after_pose_ref='pose' if pose else 'other',after_revision=0)
    a.results={c['operation_id']:r if accepted else None}
    a.decisions={p['observation_id']:dict(day_cycle=dict(phase=phase))}
    a.sleep_rest_credit=lambda p,r,current:r['executed_us']-p['capture_us']
    consumed=accept_rest_result(a,p,c,r)
    duplicate=accept_rest_result(a,p,c,r)
    assert duplicate is False
    return consumed


def scenario(spec):
    w=CommunicationWorld(capacity=256);w.objects=[];w.contact_distance=1.25
    for i,actor in enumerate(IDS):
        w.agents[actor].update(x=i*.4,z=0.,inventory=0 if i==0 else 12)
        w.bodies[actor]['reserve']=50.
    w.hearing['npc_b']=spec['hearing']
    states={a:None for a in IDS};pressure=aid.update(None,{},'npc_a',threshold=3)
    rows=[];nights=[]
    for day in range(3):
        w.bodies['npc_a']['reserve']=max(0.,w.bodies['npc_a']['reserve']-20)
        for attempt in range(2):
            now=day*DAY_US+attempt*6_000_000
            w.seconds=now/1e6
            obs=w.observe_communication('npc_a')
            s=states['npc_a'] or dict(records={},pending=None,model={},cycles=[])
            targets=[o['ref'] for o in obs['others'] if o['holding_food']]
            target,selection=aid.select(targets,s['model'],pressure)
            row=dict(day=day,attempt=attempt,selection=selection)
            if target is None:
                rows.append(row);continue
            op=f'request:{day}:{attempt}';mid='npc_a:'+op
            r=w.communicate('npc_a',op,'request',target)
            assert w.communicate('npc_a',op,'request',target)==r
            s=deepcopy(s);s['pending']=dict(message_id=mid,target=target,deadline=now+5_000_000,
                request_observation_id=f'ob:{day}:{attempt}',operation_id=op)
            w.seconds=(now+1_000_000)/1e6
            decision=respond(w.observe_communication(target),share=target!='npc_b')
            reply=w.communicate(target,f'reply:{day}:{attempt}',**decision)
            # If no response is heard, expire the original window without inventing refusal.
            capture=now+(2_000_000 if decision['action']!='wait' else 5_000_000)
            w.seconds=capture/1e6
            p=dict(agent_id='npc_a',capture_us=capture,observation_id=f'end:{day}:{attempt}',
                   social=w.observe_communication('npc_a'))
            s=social.ingest(s,p,{op:r});pressure=aid.update(pressure,s['records'],'npc_a',threshold=3)
            states['npc_a']=s
            if w.agents['npc_a']['inventory']:
                w.communicate('npc_a',f'eat:{day}:{attempt}','eat')
            row.update(request=r,response=reply,state=deepcopy(s),pressure=deepcopy(pressure),
                       inventory={a:w.agents[a]['inventory'] for a in IDS})
            rows.append(row)
        start=day*DAY_US+14_400_000_000
        day_night={}
        for actor in IDS:
            a=sleeper(day,start)
            for sec in range(spec['rest_seconds']):
                phase='safety' if spec['interrupt'] and sec==100 else 'night'
                w.bodies[actor],_=step(w.bodies[actor],'rest',load=w.agents[actor]['inventory'])
                receipt(a,start+sec*1_000_000,phase)
            cycle=a.learning['sleep']['cycle']
            states[actor]=states[actor] or dict(records={},pending=None,model={},cycles=[])
            if spec['adopt']:
                states[actor]=social.consolidate(states[actor],dict(cycle,formation_us=start),actor)
                assert social.consolidate(states[actor],dict(cycle,formation_us=start),actor)==states[actor]
            day_night[actor]=dict(sleep=a.learning['sleep'],social=deepcopy(states[actor]))
        nights.append(day_night)
        assert sum(a['inventory'] for a in w.agents.values())+w.consumed==24
    return dict(rows=rows,nights=nights,states=states,pressure=pressure,
                inventory={a:w.agents[a]['inventory'] for a in IDS},bodies=w.bodies,consumed=w.consumed)


def boundaries():
    out={};s=goal.initial('a',threshold=2)
    snapshots=[]
    for n,(confirmed,comparable) in enumerate(((False,True),(False,False),(False,True),(True,True))):
        s=goal.finish(goal.begin(s,str(n),{'observation_id':str(n)}),str(n),confirmed,comparable,'end'+str(n))
        assert goal.finish(s,str(n),confirmed,comparable,'end'+str(n))==s
        snapshots.append(deepcopy(s))
    out['goal_sequence']=snapshots
    errors={}
    cases={'conflict':lambda:goal.finish(s,'3',False,True,'end3'),
           'reopen':lambda:goal.begin(s,'3',{}),
           'threshold':lambda:goal.initial('a',threshold=0),
           'bool_threshold':lambda:goal.initial('a',threshold=True),
           'parent':lambda:goal.initial('a',parent_goal_id='a'),
           'evidence':lambda:goal.finish(s,'3',1,True,'end3'),
           'active':lambda:goal.begin(goal.begin(goal.initial('a'),'x',{}),'y',{}),
           'binding':lambda:goal.finish(goal.initial('a'),'missing',False,True,'end')}
    for key,fn in cases.items():
        try:fn();raise AssertionError(key)
        except ValueError as e:errors[key]=str(e)
    out['errors']=errors
    t=goal.begin(goal.initial('a'),'safety',{});t['trial']['interrupted_by_safety']=True
    out['safety_goal']=goal.finish(t,'safety',False,True,'end')
    out['sleep']={}
    start=17_278_000_000
    for name,kw in [('last',{}),('safety',dict(phase='safety')),('failed',dict(status='blocked')),
                    ('pose',dict(pose=False)),('day',{})]:
        a=sleeper(0,start,SLEEP_REST_US-1_000_000)
        receipt(a,start if name!='day' else DAY_US,**kw)
        out['sleep'][name]=a.learning
    a=sleeper(0,start)
    try:receipt(a,start,accepted=False);raise AssertionError('acceptance')
    except ValueError as e:out['errors']['sleep_acceptance']=str(e)
    # Input ownership, completed-cycle replay, future records and unexecuted request.
    state=dict(records={str(i):dict(agent_id='a',target='b',message_id=str(i),tick=t,outcome=o)
                        for i,(t,o) in enumerate(((1,'given'),(2,'refuse'),(9,'given'),(1,'request_not_executed')))},
               model={},pending=None,cycles=[])
    before=deepcopy(state)
    out['social_cutoff']=social.consolidate(state,dict(status='completed',day=0,formation_us=2),'a')
    assert state==before
    try:social.consolidate(state,dict(status='completed',day=0,formation_us=2),'other')
    except ValueError as e:out['errors']['social_agent']=str(e)
    pending=dict(records={},model={},cycles=[],pending=dict(message_id='m',target='b',deadline=5,operation_id='op'))
    p=dict(capture_us=5,agent_id='a',observation_id='end',social=dict(messages=[]))
    out['unexecuted']=social.ingest(pending,p,{})
    assert pending['pending'] is not None
    return out


SPECS=[dict(name=name,adopt=name!='shadow',hearing=name!='unheard',
            rest_seconds=100 if name=='short' else 2880,interrupt=name=='interrupt')
       for name in ('enabled','shadow','unheard','short','interrupt')]
