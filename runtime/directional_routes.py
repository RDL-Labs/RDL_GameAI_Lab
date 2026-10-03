"""Finite directional route hypotheses; reverse order is a proposal, not proof."""
from copy import deepcopy
from hashlib import sha256
from .landmark_day_cycle import clusters, DAY_US

RULE='directional-landmark-routes-v1'
MAX_ROUTES=16
MAX_POINTS=8


def patches(p,color):
    if p['landmarks']['coverage']!='complete':return None
    fs=[f for f in p['landmarks']['features'] if f['color']==color]
    return [dict(angle=(lo+hi)/2,near=any(f['range_band']=='near' and lo<=sum(f['azimuth'])/2<=hi for f in fs)) for lo,hi in clusters(fs)]


def record(trail,p,result):
    if trail['overflow'] or p['landmarks']['coverage']!='complete':return
    fs=[f for f in p['landmarks']['features'] if abs(sum(f['azimuth'])/2)<=45]
    colors=sorted(set(f['color'] for f in fs))
    choices=[]
    for color in colors:
        xs=patches(p,color)
        if xs and len(xs)==1:choices.append((abs(xs[0]['angle']),color))
    if not choices:return
    choices.sort()
    if len(choices)>1 and choices[0][0]==choices[1][0]:return
    color=choices[0][1]
    if trail['points'] and trail['points'][-1]['color']==color:return
    if len(trail['points'])>=MAX_POINTS:trail['overflow']=True;return
    from .relational_movement import scene
    trail['points'].append(dict(color=color,scene=scene(p) or [],source=p['observation_id'],capture_us=p['capture_us'],pose_ref=p['pose_ref'],result=result['operation_id']))


def admit(routes,goal,points,receipt,*,relational=False):
    """Credit the actually observed directional sequence, once per delivery."""
    if not points:return []
    added=[]
    for target,seq,reverse in [(goal,points,False),('home' if goal=='food' else 'food',list(reversed(points)),True)]:
        signature=[target,[p['color'] for p in seq]]
        if relational:
            signature.append([[(a['color'],b['color'],round((b['angle']-a['angle'])/15)) for i,a in enumerate(p.get('scene',[])) for b in p.get('scene',[])[i+1:]] for p in seq])
        key=sha256(repr(signature).encode()).hexdigest()[:16]
        if key not in routes:
            if len(routes)>=MAX_ROUTES:continue
            routes[key]=dict(goal=target,points=deepcopy(seq),support=0,H=0,receipts=[],proposals=[])
        node=routes[key]
        if reverse:
            if receipt not in node['proposals']:node['proposals']=(node['proposals']+[receipt])[-32:]
        elif receipt not in node['receipts']:
            node['receipts']=(node['receipts']+[receipt])[-32:]
            node['support']=min(8,node['support']+1);node['H']=0
        added.append(dict(route=key,reverse_proposal=reverse,support=node['support']))
    return added


def review(agent,p,d,*,propose_only=False):
    d=deepcopy(d);previous=next(reversed(agent.observations.values())) if agent.observations else None
    last=agent.decisions.get(previous['observation_id'],{}) if previous else {}
    s=deepcopy(last.get('directional_routes')) if last.get('directional_routes') else dict(rule=RULE,binding=[p['run_id'],p['agent_id']],routes={},trip=None,day=-1,at_home=False,outbound=dict(points=[],overflow=False))
    if s['binding']!=[p['run_id'],p['agent_id']]:raise ValueError('directional_route_binding')
    day=p['capture_us']//DAY_US;phase=d['day_cycle']['phase'];goal='home' if phase=='return' else 'food'
    cmd=agent.commands.get(previous['observation_id']) if previous else None
    result=agent.results.get(cmd['operation_id']) if cmd else None
    linked=bool(result and result['after_pose_ref']==p['pose_ref'] and result['after_revision']==p['body_revision'] and result['executed_us']<p['capture_us'] and result['status'] not in ('expired','stale'))
    s.update(applied=False,candidates=[],reason='priority',admissions=[],comparison=None)
    def fail(key,reason):
        if key in s['routes'] and key not in s.get('failed',[]):
            comparable=s.get('trial_complete',False)
            if comparable:s['routes'][key]['H']=min(32,s['routes'][key]['H']+1)
            s.setdefault('failed',[]).append(key)
            s['comparison']=dict(route=key,E=1 if comparable else None,reason=reason,source=p['observation_id'])
    if phase=='safety':
        if linked and last.get('directional_routes',{}).get('applied') and result['status']=='blocked':
            fail(s.get('active'),'actual_blocked_before_safety')
        s['active']=None;s['trial_complete']=False
        s['outbound']['overflow']=True
        if s['trip']:
            if s['trip']['outbound']:s['trip']['outbound']['overflow']=True
            s['trip']['inbound']['overflow']=True
    active=s.get('active')
    if active in s['routes']:
        target=s['routes'][active]['goal']
        s['trial_complete']=s.get('trial_complete',True) and p['food' if target=='food' else 'skyline']['coverage']=='complete'
        ended=(target=='food' and phase!='exploration' and s['trip'] is None) or (target=='home' and phase=='night' and s['trip'] is not None)
        if ended:fail(active,'leg_ended_without_result')
    if linked and result['status']=='moved':
        if last.get('day_cycle',{}).get('phase')=='exploration' and s['at_home'] and s['trip'] is None:record(s['outbound'],previous,result)
        if last.get('day_cycle',{}).get('phase')=='return' and s['trip'] is not None:record(s['trip']['inbound'],previous,result)
    if linked and result.get('acquired') and s['trip'] is None:
        s['trip']=dict(pickup=result['operation_id'],outbound=deepcopy(s['outbound']) if s['at_home'] else None,inbound=dict(points=[],overflow=False))
        s['at_home']=False
        if s.get('active') in s['routes'] and s['routes'][s['active']]['goal']=='food':s['active']=None
    # Only an actual unload grants support; a visible tower or nearby dock does not.
    if linked and result['operation_id'] in agent.unload_receipts and s['trip']:
        receipt=agent.unload_receipts[result['operation_id']]
        if s['trip']['pickup'] in receipt['pickups']:
            for target,trail in [('food',s['trip']['outbound']),('home',s['trip']['inbound'])]:
                if trail and not trail['overflow']:s['admissions']+=admit(s['routes'],target,trail['points'],result['operation_id'],relational=propose_only)
            s['trip']=None;s['active']=None;s['at_home']=True;s['outbound']=dict(points=[],overflow=False)
    if s['day']!=day:
        dc=last.get('day_cycle',{})
        home=bool(dc.get('return_state',{}).get('outcome')=='home_like_observed' or any(r['executed_us']//DAY_US==day-1 for r in agent.unload_receipts.values()))
        if s['day']==-1:home=bool(d['day_cycle'].get('home_memory'))
        if home and s['trip'] is None:s['at_home']=True;s['outbound']=dict(points=[],overflow=False)
        s.update(day=day,operations=0,cursors={},failed=[],active=None,trial_complete=True)
    d['directional_routes']=s
    if phase not in ('exploration','return') or not linked:return d
    # Direct goals always outrank a detour; this is a current observation gate.
    home_memory=d['day_cycle'].get('home_memory')
    tower=bool(home_memory and p['skyline']['coverage']=='complete' and len(clusters([f for f in p['skyline']['features'] if f['color']==home_memory['color']]))==1)
    direct=(p.get('dock',{}).get('visible') or tower) if goal=='home' else bool(p['food']['visible'])
    direct_feasible=direct and d['reason'] not in ('return_approach_blocked','return_approach_budget')
    if direct:s['candidates'].append(dict(kind='current_goal',score=100,feasible=direct_feasible))
    if last.get('directional_routes',{}).get('applied') and result['status']=='blocked':
        key=s.get('active')
        if key in s['routes'] and key not in s['failed']:
            fail(key,'actual_blocked')
    if propose_only:return d
    for key,node in s['routes'].items():
        if node['goal']!=goal or key in s['failed'] or node['H']>=2:continue
        cursor=s['cursors'].get(key,0)
        while cursor<len(node['points']):
            xs=patches(p,node['points'][cursor]['color'])
            if xs is not None and len(xs)==1 and xs[0]['near']:cursor+=1
            else:break
        s['cursors'][key]=cursor
        if cursor==len(node['points']):continue
        xs=patches(p,node['points'][cursor]['color'])
        status='unavailable' if xs is None else 'absent' if not xs else 'ambiguous' if len(xs)>1 else 'visible'
        score=1+node['support']*.25-node['H']*.5
        s['candidates'].append(dict(kind='route',route=key,goal=goal,support=node['support'],reverse_only=node['support']==0,score=score,status=status,cursor=cursor))
    if direct_feasible:s['reason']='current_goal_priority';return d
    if goal=='food' and not s['at_home']:s['reason']='origin_unconfirmed';return d
    allowed=(d['reason'].startswith(('landmark_','neighborhood_')) or d['reason'] in ('food_goal_rescan','acquisition_incomplete')) if goal=='food' else (d['reason'].startswith('return_search_') or d['reason'] in ('return_approach_blocked','return_approach_budget'))
    if not allowed or d['action'][0]=='pickup':return d
    if not getattr(agent,'continuous_selection',False) and s['operations']>=48:
        fail(s.get('active'),'operation_budget');s['reason']='operation_budget';return d
    eligible=[c for c in s['candidates'] if c.get('status')=='visible']
    if not eligible:s['reason']='no_visible_route';return d
    # Deterministic tie, support is a bounded selection gradient, not new geometry.
    choice=sorted(eligible,key=lambda c:(-c['score'],c['route']))[0];key=choice['route']
    node=s['routes'][key];target=patches(p,node['points'][choice['cursor']]['color'])[0];angle=target['angle']
    if abs(angle)>7.5:action=['turn',max(-45,min(45,round(angle/5)*5))]
    else:
        ground=p['movement_surface']['ground']
        if ground['output_limited'] or not any(x['direction_deg']==0 and x['status']=='sampled' and abs(x['height_delta'])<=.5 for x in ground['samples']):
            s['reason']='step_unavailable';return d
        action=['move',1]
    s['trial_complete']=s.get('trial_complete',True) and p['food' if goal=='food' else 'skyline']['coverage']=='complete'
    s.update(applied=True,active=key,operations=s['operations']+1,reason='visible_route_selected')
    d.update(action=action,target='',reason='directional_route',terrain_gate='directional_route')
    return d
