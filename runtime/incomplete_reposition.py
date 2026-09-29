"""Bounded incomplete-view repositioning from current individual surface samples.

Local residual, not canonical E/H, no goal coordinates or global heat field.
"""
from copy import deepcopy
from hashlib import sha256

RULE='incomplete-view-release-v1'

def review(agent,p,d,*,key='reposition',phase='exploration',reasons=('acquisition_incomplete',),landmarks=False):
    d=deepcopy(d)
    previous=next(reversed(agent.observations.values())) if agent.observations else None
    last=agent.decisions.get(previous['observation_id'],{}) if previous else {}
    old=last.get(key,{})
    day=p['capture_us']//64000000
    dt=max(0,p['capture_us']-old.get('capture_us',p['capture_us']))/1000000
    residual=max(0,old.get('residual',0)-dt*.5)
    state=dict(rule=RULE,day=day,capture_us=p['capture_us'],residual=residual,
        operations=old.get('operations',0) if old.get('day')==day else 0,
        pending_step=False,applied=False,reason='priority',baseline_reason=d['reason'],eligible=[])
    d[key]=state
    if d['day_cycle']['phase']!=phase or d['reason'] not in reasons or d['action'][0]!='wait':return d
    command=agent.commands.get(previous['observation_id']) if previous else None
    result=agent.results.get(command['operation_id']) if command else None
    linked=bool(result and result['after_pose_ref']==p['pose_ref'] and result['after_revision']==p['body_revision'] and result['executed_us']<p['capture_us'])
    if not linked:state['reason']='body_unlinked';return d
    state['residual']=min(8,residual+1)
    state['reason']='accumulating'
    if state['operations']>=16:state['reason']='daily_operation_budget';return d
    surface=p['movement_surface']['ground']
    if surface['output_limited']:state['reason']='surface_limited';return d
    allowed=sorted(s['direction_deg'] for s in surface['samples'] if s['status']=='sampled' and abs(s['height_delta'])<=.5)
    state['eligible']=allowed
    if not allowed:state['reason']='no_observed_step';return d
    pending=(old.get('pending_step') and old.get('day')==day and command['kind']=='turn' and result['status']=='turned' and abs(result['yaw']-command['amount'])<.01)
    if pending and 0 in allowed:
        action=['move',1];reason='confirmed_turn_step'
    elif state['residual']<2:return d
    else:
        # First release keeps the nearest headings; sustained repetition opens
        # the full currently observed set. No unknown direction is promoted.
        choices=[a for a in allowed if abs(a)<=45] if state['residual']<4 else allowed
        if not choices:choices=allowed
        if landmarks and state['residual']<4 and p['landmarks']['coverage']=='complete':
            features=p['landmarks']['features']
            if features:
                center=sum(features[0]['azimuth'])/2
                choices=sorted(choices,key=lambda a:abs(a-center))[:1]
                state['candidate_source']=dict(observation=p['observation_id'],feature=features[0]['ref'])
        seed_key=[p['run_id'],p['agent_id'],day,state['operations'],RULE,key]
        # Preserve the original exploration draw sequence.
        if key=='reposition':seed_key=seed_key[:-1]
        index=int(sha256(repr(seed_key).encode()).hexdigest()[:8],16)%len(choices)
        angle=choices[index]
        action=['move',1] if angle==0 else ['turn',angle]
        reason='observed_step' if angle==0 else 'alternate_heading'
        state['pending_step']=angle!=0
    state.update(operations=state['operations']+1,applied=True,reason=reason,source=p['observation_id'])
    d.update(action=action,target='',reason='incomplete_reposition_'+reason,terrain_gate='bounded_reposition')
    return d
