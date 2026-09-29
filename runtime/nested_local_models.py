"""Finite nested local model arbitration; not canonical T1/model admission.

Each local model predicts one operational result under a frozen question.
Only its own evaluated result updates its residual. Parent H is sourced, not summed.
"""
from copy import deepcopy
from .incomplete_reposition import review as reposition

RULE='nested-local-mb-selection-v1'
FAILURES=('landmark_no_candidate_after_scan','landmark_goal_budget','landmark_operation_budget',
 'acquisition_incomplete','return_search_no_candidate_after_scan','return_search_acquisition_incomplete',
 'return_approach_blocked','return_approach_budget','return_search_goal_budget',
 'return_search_operation_budget','return_search_ambiguous','return_search_blocked','return_reposition_continue')

def view(p):
    # Relative appearance only; no World pose string as a novelty signal.
    return (p['ground']['coverage'],tuple((x['color'],x['status']) for x in p['ground']['cells']),
        tuple(sorted((x['color'],tuple(x['azimuth']),x['range_band']) for x in p['landmarks']['features'])),
        tuple(sorted((x['appearance'],round(x['distance'],1)) for x in p['food']['visible'])))

def local_model(d):
    phase=d['day_cycle']['phase'];family='home' if phase=='return' else 'food'
    reason=d['reason'];kind=d['action'][0]
    if kind=='pickup':name,question='work','acquired'
    elif reason=='return_unload_attempt':name,question='work','unloaded_or_arrived'
    elif reason.startswith('incomplete_reposition_'):name,question='reposition','view_or_position_changed'
    elif kind=='move':name,question='approach','moved'
    else:name,question='survey','view_changed'
    return family+'/'+name,question

def update(old,p,previous,result,receipts):
    s=deepcopy(old) if old else dict(rule=RULE,binding=[p['run_id'],p['agent_id']],nodes={},events=[])
    if s['binding']!=[p['run_id'],p['agent_id']]:raise ValueError('nested_model_binding')
    trial=s.pop('trial',None)
    if not trial:return s
    linked=bool(previous and result and result['after_pose_ref']==p['pose_ref'] and result['after_revision']==p['body_revision'] and result['executed_us']<p['capture_us'])
    value=None
    if linked and result['status'] not in ('stale','expired'):
        q=trial['question'];changed=view(p)!=view(previous)
        value={'acquired':bool(result['acquired']), 'moved':result['status']=='moved',
          'view_changed':changed,'view_or_position_changed':changed or result['status']=='moved',
          'unloaded':result['operation_id'] in receipts,
          'arrived':p.get('dock',{}).get('in_reach',False) and result['status']=='waited' }[q]
    node=s['nodes'][trial['model']];before=node['H']
    if value is not None:node['H']=0 if value else min(32,before+1)
    s['events']=(s['events']+[dict(model=trial['model'],question=trial['question'],source=trial['source'],
        result_source=p['observation_id'],F=1,F_prime=None if value is None else int(value),
        E=None if value is None else int(not value),H_before=before,H_after=node['H'],status='defer' if value is None else 'compared')])[-32:]
    return s

def review(agent,p,d):
    d=deepcopy(d)
    previous=next(reversed(agent.observations.values())) if agent.observations else None
    last=agent.decisions.get(previous['observation_id'],{}) if previous else {}
    command=agent.commands.get(previous['observation_id']) if previous else None
    result=agent.results.get(command['operation_id']) if command else None
    s=update(last.get('nested_models'),p,previous,result,agent.unload_receipts)
    phase=d['day_cycle']['phase']
    s['selection']=dict(applied=False,reason='priority',candidates=[])
    if phase not in ('exploration','return'):
        d['nested_models']=s;return d
    family='home' if phase=='return' else 'food'
    parent=d['day_cycle']['goal_difference' if family=='home' else 'food_goal']
    s['parent']=dict(goal_id=parent['goal_id'],H=parent['H'],threshold=parent['threshold'],authority='existing-goal-model')
    model,question=local_model(d)
    node=s['nodes'].setdefault(model,dict(H=0,threshold=2,parent=family))
    if d['action'][0]=='wait' and d['reason'] in FAILURES:
        pressure=node['H']/node['threshold']+parent['H']/parent['threshold']
        # Fixed score contributions, not a claim of learned optimal policy.
        recovery_node=s['nodes'].get(family+'/reposition',dict(H=0,threshold=2))
        recovery_cost=recovery_node['H']/recovery_node['threshold']
        recovery=pressure-1-recovery_cost
        s['selection']=dict(applied=False,reason='retain_current',candidates=[
          dict(model=model,score=1),dict(model=family+'/reposition',score=recovery)],
          contributions=dict(local_H=node['H']/node['threshold'],parent_H=parent['H']/parent['threshold'],switch_cost=1,recovery_H=recovery_cost))
        if recovery>1:
            key='return_reposition' if family=='home' else 'reposition'
            proposal=reposition(agent,p,d,key=key,phase=phase,reasons=FAILURES,landmarks=True)
            s['selection'].update(reason=proposal[key]['reason'],applied=proposal[key]['applied'])
            d=proposal
    model,question=local_model(d)
    if question=='unloaded_or_arrived':question='unloaded' if agent.carried_count()>0 else 'arrived'
    s['nodes'].setdefault(model,dict(H=0,threshold=2,parent=family))
    # Confirmed arrival/delivery waiting and planned night/orientation are not
    # failed survey trials. The parent goal keeps its own completion evidence.
    if d['reason'] not in ('return_delivery_confirmed','return_home_like_observed'):
        s['trial']=dict(model=model,question=question,source=p['observation_id'],F=1)
    s['active_model']=model
    d['nested_models']=s
    return d
