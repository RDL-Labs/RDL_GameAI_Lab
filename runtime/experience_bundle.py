"""Bounded, unvalidated conjunctions reactivated from own unmet-goal episodes."""
from copy import deepcopy
from hashlib import sha256
import json


def context(p):
    return [p['social']['food_band'],p['food']['coverage'],bool(p['food']['visible']),
            p.get('hazard',{}).get('coverage'),bool(p.get('hazard',{}).get('features')),
            p['social']['body']['reserve']<=80,p['social']['body']['strain']>=.8]


def form(agent,p,hunger):
    old=agent.learning.get('experience_bundles')
    s=deepcopy(old) if old else dict(binding=[p['run_id'],p['agent_id']],bundles=[],used=[],last_comparison=None)
    if s['binding']!=[p['run_id'],p['agent_id']]:raise ValueError('bundle_binding')
    records=hunger['goal']['records'];latest=next(reversed(records),None)
    if latest is None or latest==s['last_comparison']:return s
    s['last_comparison']=latest
    if hunger['goal']['H']<hunger['goal']['threshold']:return s
    if len(s['bundles'])>=32:s['formation_status']='capacity_reached';return s
    sources=[]
    for observation in list(agent.observations.values())[-8:]:
        ident=observation['observation_id'];command=agent.commands.get(ident)
        result=agent.results.get(command['operation_id']) if command else None
        if not result or result['operation_id'] in s['used']:continue
        if observation['agent_id']!=p['agent_id']:raise ValueError('bundle_source_owner')
        if not (0<p['capture_us']-observation['capture_us']<=10_000_000):continue
        if result['executed_us']>=p['capture_us'] or result['status'] in ('stale','expired'):continue
        decision=agent.decisions[ident]
        sources.append(dict(operation=result['operation_id'],observation=ident,context=context(observation),
            action=command['kind'],outcome=result['status'],phase=decision['day_cycle']['phase'],
            method=(decision.get('continuous_selection') or {}).get('selected'),
            social_intent=deepcopy(decision.get('social_intent')),
            reserve=observation['social']['body']['reserve'],result_observed_by=p['observation_id']))
    if not sources:return s
    payload=dict(binding=s['binding'],formed_us=p['capture_us'],trigger=p['observation_id'],
        goal=hunger['goal']['model_ref'],comparison=latest,H=hunger['goal']['H'],sources=sources)
    payload['model_ref']='experience-conjunction-v1:'+sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()[:24]
    s['bundles'].append(payload);s['used'].extend(x['operation'] for x in sources)
    s['formation_status']='formed_unvalidated'
    return s


def apply(agent,p,selection,phase):
    state=agent.learning.get('experience_bundles')
    trace=dict(status='no_model',contributions=[],changed=False)
    if not state:return trace
    if state['binding']!=[p['run_id'],p['agent_id']]:raise ValueError('bundle_binding')
    if phase not in ('exploration','return') or selection['gate']!='method_reselection':
        trace['status']='protected';return trace
    key=lambda c:(-c['score'],c['last_selected'],c['model'])
    baseline=min(selection['candidates'],key=key)['model']
    current=context(p);matches=[]
    for bundle in state['bundles']:
        if bundle['formed_us']>=p['capture_us']:continue
        for source in bundle['sources']:
            if source['context']==current and source['phase']==phase:
                matches.append((bundle['model_ref'],source))
    for candidate in selection['candidates']:
        if not candidate.get('record_trial',True):continue
        evidence=[(ref,s) for ref,s in matches if s['action']==candidate['action'][0]]
        if not evidence:continue
        # Frequency within the recalled set, not independent causal confirmation.
        delta=-.75*len(evidence)/len(matches)
        trace['contributions'].append(dict(candidate=candidate['model'],delta=delta,
            model_refs=sorted({ref for ref,s in evidence}),sources=[s['operation'] for ref,s in evidence]))
        if agent.experience_bundle_mode=='enabled':candidate['score']+=delta
    selected=min(selection['candidates'],key=key)['model']
    trace.update(status='matched' if matches else 'no_match',baseline=baseline,selected=selected,
        changed=baseline!=selected,mode=agent.experience_bundle_mode)
    return trace
