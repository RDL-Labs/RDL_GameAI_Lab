"""Local dock observation and result-confirmed homing, finite recovery."""
from copy import deepcopy
from math import atan2, degrees, hypot
from .home_search import review as legacy_review
from .landmark_day_cycle import clusters

BIND=('run_id','agent_id','observation_id','capture_us','pose_ref')

def sample(world,p):
    aid=p['agent_id'];target=dict(x=0.,z=6.)
    forward,right=world.relative(aid,target);distance=hypot(forward,right)
    seen=distance<=6 and forward>=0 and world.visible(aid,target)
    return dict(model='local-dock-v1',source={k:p[k] for k in BIND},coverage='complete',
        visible=seen,relative_angle=round(degrees(atan2(right,forward))/5)*5 if seen else None,
        in_reach=seen and distance<=1.25)

def validate(p):
    x=p['dock']
    if set(x)!={'model','source','coverage','visible','relative_angle','in_reach'} or x['model']!='local-dock-v1' or x['source']!={k:p[k] for k in BIND}:raise ValueError('dock_binding')
    if x['coverage']!='complete' or type(x['visible']) is not bool or type(x['in_reach']) is not bool:raise ValueError('dock_status')
    if not x['visible']:
        if x['relative_angle'] is not None or x['in_reach']:raise ValueError('dock_absent')
    elif type(x['relative_angle']) not in (int,float) or not -90<=x['relative_angle']<=90:raise ValueError('dock_angle')

def review(agent,p,memory,state,linked,result):
    s=deepcopy(state)
    if not linked:return ['wait',0],dict(s,outcome='body_correspondence_unavailable')
    # Actual accepted unload receipt, not a near-looking landmark, ends the task.
    day=p['capture_us']//64000000
    if agent.carried_count()==0 and any(r['executed_us']//64000000==day for r in agent.unload_receipts.values()):
        return ['wait',0],dict(s,outcome='delivery_confirmed')
    s['outcome']=None
    dock=p['dock']
    previous=next(reversed(agent.observations.values())) if getattr(agent,'observations',None) else None
    last=agent.decisions.get(previous['observation_id'],{}) if previous else {}
    if dock['in_reach'] and agent.carried_count()==0 and result and result['status']=='waited':
        return ['wait',0],dict(s,outcome='home_like_observed',diagnostic='local_arrival_confirmed')
    pending=last.get('return_reposition',{})
    if pending.get('pending_step') and pending.get('day')==day and not dock['in_reach']:
        return ['wait',0],dict(s,diagnostic='reposition_continue',outcome=None)
    angle=None
    if dock['visible']:
        if dock['in_reach']:
            return ['wait',0],dict(s,diagnostic='unload_attempt',outcome=None)
        angle=dock['relative_angle']
    elif memory and p['skyline']['coverage']=='complete':
        patches=clusters([f for f in p['skyline']['features'] if f['color']==memory['color']])
        if len(patches)==1:angle=sum(patches[0])/2
    if angle is None:
        action,s=legacy_review(agent,p,memory,s,linked,result)
        return action,s
    if s['operations']>=64:return ['wait',0],dict(s,diagnostic='approach_budget',outcome=None)
    s['operations']+=1
    if abs(angle)>7.5:
        return ['turn',max(-45,min(45,round(angle/5)*5))],dict(s,diagnostic='dock_approach',outcome=None)
    forward=next(x for x in p['movement_surface']['ground']['samples'] if x['direction_deg']==0)
    if forward['status']=='sampled' and abs(forward['height_delta'])<=.5:
        return ['move',1],dict(s,diagnostic='dock_approach',outcome=None)
    return ['wait',0],dict(s,diagnostic='approach_blocked',outcome=None)
