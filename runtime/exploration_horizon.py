"""Opt-in cross-day acquisition pressure; local experimental M_B, not Core admission."""
from copy import deepcopy
RULE='cross-day-exploration-horizon-v1'
WINDOW=8

def update(old,p,last,result,linked):
    s=deepcopy(old) if old else dict(rule=RULE,binding=[p['run_id'],p['agent_id']],H=0,threshold=2,count=0,charged=None,events=[])
    if s['binding']!=[p['run_id'],p['agent_id']]:raise ValueError('horizon_binding')
    if linked and result and result['operation_id']!=s['charged']:
        s['charged']=result['operation_id']
        if result.get('acquired'):
            before=s['H'];s.update(H=0,count=0)
            s['events']=(s['events']+[dict(source=result['operation_id'],H_before=before,H_after=0,E=0,reason='acquired')])[-16:]
        elif last.get('day_cycle',{}).get('phase')=='exploration' and result['status'] in ('moved','turned','waited','blocked'):
            s['count']+=1
            if s['count']==WINDOW:
                before=s['H'];s.update(H=min(32,before+1),count=0)
                s['events']=(s['events']+[dict(source=result['operation_id'],H_before=before,H_after=s['H'],E=1,reason='eight_exploration_effects_without_acquisition')])[-16:]
    return s

def proposals(p,state,safe):
    if state['H']<state['threshold']:return []
    pressure=min(4,state['H']/state['threshold']);out={}
    # Use fresh observed angular patches, not World positions or remembered bearings.
    for f in p['landmarks']['features']:
        if f['range_band'] not in ('mid','far') or f['azimuth'][1]-f['azimuth'][0]>45:continue
        center=sum(f['azimuth'])/2
        if not safe:continue
        angle=min(safe,key=lambda a:abs(a-center))
        if abs(angle-center)>22.5:continue
        score=2+pressure*(1 if f['range_band']=='far' else .35)
        if angle not in out or score>out[angle]['score']:
            out[angle]=dict(angle=angle,score=score,range_band=f['range_band'],source=f['ref'])
    return list(out.values())
