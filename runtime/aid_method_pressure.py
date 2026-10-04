"""Same-day goal/method pressure, separate from nightly social expectations."""
from copy import deepcopy
from .goal_difference import initial,begin,finish


def update(previous,records,agent,threshold=2):
    s=deepcopy(previous) if previous else dict(parent=initial(agent+':obtain-aid',
        'received-aid-within-request-window-v1','aid_received',threshold),methods={})
    if s['parent']['goal_id']!=agent+':obtain-aid':raise ValueError('aid_pressure_binding')
    for ident,r in records.items():
        if r['agent_id']!=agent:raise ValueError('aid_pressure_agent')
        if ident in s['parent']['records']:continue
        target=r['target']
        if target not in s['methods']:
            s['methods'][target]=initial(agent+':request:'+target,'received-aid-within-request-window-v1',
                                        'aid_received',threshold,s['parent']['goal_id'])
        source=dict(observation_id=r['request_observation_id'])
        confirmed=r['outcome']=='given';comparable=r['outcome']!='request_not_executed'
        for key in ('parent',target):
            state=s['parent'] if key=='parent' else s['methods'][key]
            state=finish(begin(state,ident,source),ident,confirmed,comparable,r['source_observation_id'])
            if key=='parent':s['parent']=state
            else:s['methods'][key]=state
    return s


def select(targets,model,pressure):
    candidates=[]
    for target in sorted(set(targets)):
        state=pressure['methods'].get(target)
        H=state['H'] if state else 0;theta=state['threshold'] if state else pressure['parent']['threshold']
        penalty=min(2,H/theta) if H>=theta else 0
        candidates.append(dict(target=target,H=H,threshold=theta,
            score=model.get(target,{}).get('expectation',.5)-penalty))
    if pressure['parent']['H']>=pressure['parent']['threshold']:
        candidates.append(dict(target=None,score=.25,reason='reconsider_existing_activity'))
    chosen=min(candidates,key=lambda c:(-c['score'],c['target'] or '')) if candidates else None
    return (chosen['target'] if chosen else None),dict(candidates=candidates,selected=deepcopy(chosen))
