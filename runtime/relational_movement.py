"""Finite angular-relation field in the current body frame; no world map."""
from copy import deepcopy
from math import atan2,degrees,radians,sin,cos,fsum
from .landmark_day_cycle import clusters
from .terrain_resource_exploration import terrain_input

RULE='angular-relation-movement-field-v2'
WEIGHT_RULE='experience-relative-route-weight-v1'


def route_strength(node):
    # Unused time is not negative evidence. Even weakened routes remain proposals.
    return (1.+.25*node['support'])/(1.+node['H'])


def weight_candidates(candidates):
    total=fsum(c['score'] for c in candidates)
    for c in candidates:
        c['share']=c['score']/total
        c['field_weight']=min(1.,c['score']/3.)*c['share']
    return candidates


def wrap(x):return (x+180)%360-180


def scene(p):
    f=p['landmarks']
    if f['coverage']!='complete' or f['output_limited']:return None
    out=[]
    for color in sorted({x['color'] for x in f['features']}):
        fs=[x for x in f['features'] if x['color']==color];cs=clusters(fs)
        if len(cs)!=1:continue
        lo,hi=cs[0];bands={x['range_band'] for x in fs}
        if len(bands)!=1:continue
        out.append(dict(color=color,angle=(lo+hi)/2,range_band=next(iter(bands))))
    return out[:5]


def relation(p,target):
    current=scene(p)
    if current is None:return dict(status='unavailable',pairs=[])
    old={x['color']:x for x in target.get('scene',[])}
    now={x['color']:x for x in current};common=sorted(set(old)&set(now))
    if len(common)<2:return dict(status='insufficient_landmarks',pairs=[])
    pairs=[]
    for i,a in enumerate(common):
        for b in common[i+1:]:
            expected=wrap(old[b]['angle']-old[a]['angle']);actual=wrap(now[b]['angle']-now[a]['angle'])
            pairs.append(dict(colors=[a,b],expected=expected,actual=actual,error=wrap(expected-actual)))
    return dict(status='comparable',pairs=pairs,current=current,aligned=all(abs(x['error'])<=7.5 for x in pairs))


def compose(p,target,terrain,weight=1.,goal_angle=None):
    """Approximate one-step bearing changes, using declared range-band proxies."""
    rel=relation(p,target) if target else dict(status='no_route',pairs=[])
    trace=dict(rule=RULE,source=p['observation_id'],pose_ref=p['pose_ref'],relation=rel,samples=[])
    current={x['color']:x for x in rel.get('current',[])}
    for row in terrain['directional_samples']:
        angle=row['direction_deg'];out=dict(direction=angle,status=row['status'])
        if row['status']!='scored':trace['samples'].append(out);continue
        cost=0.
        if rel['status']=='comparable':
            vf,vr=cos(radians(angle)),sin(radians(angle));pred={}
            for color,x in current.items():
                dist={'near':4.,'mid':12.,'far':24.}[x['range_band']];t=radians(x['angle'])
                pred[color]=degrees(atan2(dist*sin(t)-vr,dist*cos(t)-vf))
            changes=[]
            for pair in rel['pairs']:
                a,b=pair['colors'];error=wrap(pair['expected']-wrap(pred[b]-pred[a]))
                changes.append(max(-1.,min(1.,(error**2-pair['error']**2)/900)))
            cost=weight*sum(changes)/len(changes)
        goal=0. if goal_angle is None else -.75*cos(radians(wrap(angle-goal_angle)))
        base=row['total'];out.update(base=base,relation=cost,goal=goal,total=base+cost+goal)
        trace['samples'].append(out)
    return trace


def review(agent,p,d):
    d=deepcopy(d);previous=next(reversed(agent.observations.values())) if agent.observations else None
    last=agent.decisions.get(previous['observation_id'],{}) if previous else {}
    old=last.get('relation_field',{});s=d['directional_routes'];day=p['capture_us']//64000000;phase=d['day_cycle']['phase']
    f=dict(rule=RULE,day=day,phase=phase,owner=None,operations=old.get('operations',0) if old.get('day')==day else 0,
        applied=False,pending_step=False,reason='priority',candidates=[])
    d['relation_field']=f
    if phase not in ('exploration','return') or d['action'][0]=='pickup':return d
    cmd=agent.commands.get(previous['observation_id']) if previous else None;r=agent.results.get(cmd['operation_id']) if cmd else None
    linked=bool(r and r['after_pose_ref']==p['pose_ref'] and r['after_revision']==p['body_revision'] and r['executed_us']<p['capture_us'] and r['status'] not in ('stale','expired'))
    if not linked:f['reason']='body_unlinked';return d
    pending=old.get('pending_step') and old.get('day')==day and old.get('phase')==phase and cmd['kind']=='turn' and r['status']=='turned' and abs(r['yaw']-cmd['amount'])<.01
    # Finish a previously granted recovery turn-step before another owner proposes.
    if any(last.get(k,{}).get('pending_step') and last[k].get('day')==day for k in ('reposition','return_reposition')):
        f['reason']='recovery_handoff';return d
    allowed=d['reason'].startswith(('landmark_','neighborhood_','observed_material_terrain_','return_search_')) or d['reason'] in ('food_goal_rescan','acquisition_incomplete','return_dock_approach','return_approach_blocked')
    if not allowed:return d
    goal='home' if phase=='return' else 'food';owner=old.get('owner') if old.get('day')==day and old.get('phase')==phase else None
    target=None
    for key,n in s['routes'].items():
        if n['goal']!=goal or key in s['failed']:continue
        cursor=s['cursors'].get(key,0)
        while cursor<len(n['points']):
            rel=relation(p,n['points'][cursor])
            if rel.get('aligned'):cursor+=1
            else:break
        s['cursors'][key]=cursor
        if cursor>=len(n['points']):continue
        rel=relation(p,n['points'][cursor]);score=route_strength(n)
        if rel['status']=='comparable':f['candidates'].append(dict(route=key,score=score,cursor=cursor))
    weight_candidates(f['candidates'])
    f['weight_rule']=WEIGHT_RULE
    eligible={x['route']:x for x in f['candidates']}
    if owner not in eligible:owner=None
    if owner is None and eligible:owner=sorted(eligible,key=lambda k:(-eligible[k]['score'],k))[0]
    if owner:
        node=s['routes'][owner];target=node['points'][eligible[owner]['cursor']]
    goal_angle=None
    if goal=='home':
        dock=p.get('dock',{})
        if dock.get('in_reach'):return d
        if dock.get('visible'):goal_angle=dock['relative_angle']
        else:
            home=d['day_cycle'].get('home_memory')
            if home and p['skyline']['coverage']=='complete':
                xs=clusters([x for x in p['skyline']['features'] if x['color']==home['color']])
                if len(xs)==1:goal_angle=sum(xs[0])/2
        if goal_angle is not None:owner=None;target=None
    has_food=goal=='food' and bool(p['food']['visible'])
    if has_food:owner=None;target=None
    f['owner']=owner
    if not target and goal_angle is None and not has_food and not pending:f['reason']='no_comparable_relation';return d
    if f['operations']>=48:f['reason']='operation_budget';return d
    terrain=agent._calculate_current_terrain(terrain_input(p,agent.teaching['appearance'],d.get('blocked_targets',[])),p)
    # Existing terrain validation / incomplete acquisition are hard constraints.
    if terrain['status']!='complete':f['reason']='terrain_'+terrain['status'];return d
    trace=compose(p,target,terrain,eligible[owner]['field_weight'] if owner else 0.,goal_angle)
    f['field']=trace
    rows=[x for x in trace['samples'] if x['status']=='scored']
    if not rows:f['reason']='no_scored_direction';return d
    pending=old.get('pending_step') and old.get('day')==day and old.get('phase')==phase and cmd['kind']=='turn' and r['status']=='turned' and abs(r['yaw']-cmd['amount'])<.01
    forward=next((x for x in rows if x['direction']==0),None)
    if pending and forward:angle=0;f['reason']='confirmed_turn_step'
    else:
        minimum=min(x['total'] for x in rows);best=[x for x in rows if x['total']<=minimum+1e-9]
        if any(x['direction']==0 for x in best):angle=0
        elif len(best)==1:angle=best[0]['direction']
        else:f['reason']='balanced';return d
        f['reason']='composed_minimum'
    # Retain the stricter adapter step-height boundary (0.5).
    sample=next(x for x in p['movement_surface']['ground']['samples'] if x['direction_deg']==angle)
    if sample['status']!='sampled' or abs(sample['height_delta'])>.5:f['reason']='step_unavailable';return d
    action=['move',1] if angle==0 else ['turn',angle]
    f.update(applied=True,pending_step=angle!=0,operations=f['operations']+1)
    s.update(applied=bool(owner),active=owner,reason='relation_field')
    if owner:s['operations']+=1
    d.update(action=action,target='',reason='relation_field',terrain_gate='relation_field',movement_terrain=terrain)
    return d
