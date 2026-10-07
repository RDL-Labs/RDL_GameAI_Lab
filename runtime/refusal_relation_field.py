"""Experimental use of own explicit-refusal traces, not inferred hostile intent."""
from copy import deepcopy
from hashlib import sha256
from math import exp,isfinite


def compile_field(records,pressure,owner):
    if pressure['parent']['goal_id']!=owner+':obtain-aid':raise ValueError('field_owner')
    if len(records)>192:raise ValueError('field_capacity')
    relations={}
    for ident,r in records.items():
        if r['agent_id']!=owner:raise ValueError('field_source_owner')
        if r['outcome']!='refuse':continue
        target=r['target'];evidence=pressure['methods'][target]['records'][ident]
        if evidence['E']!=1 or evidence['evidence']['source']!=r['source_observation_id']:
            raise ValueError('field_pressure_source')
        node=relations.setdefault(target,dict(sources=[],H_samples=[],weight=0.))
        node['sources'].append(ident);node['H_samples'].append(evidence['H_after'])
        node['weight']=min(2.,.6*max(node['H_samples']))
    return dict(rule='explicit-refusal-relation-field-v1',owner=owner,relations=relations,
                authority='experimental local M_B use rule; reverse cooperation is not an observed fact')


def choose(field,observation,other,question,seed,*,enabled=True,affiliation=0.,retention=None):
    if observation['self_id']!=field['owner']:raise ValueError('choice_owner')
    if question not in ('request_again','respond'):raise ValueError('choice_question')
    if not isfinite(affiliation) or not 0<=affiliation<=2:raise ValueError('affiliation')
    retention_cost=retention['cost'] if retention else 0.
    if not isfinite(retention_cost) or not 0<=retention_cost<=4:raise ValueError('retention_cost')
    contacts={c['ref']:c for c in observation['others']}
    if other not in contacts:raise ValueError('unobserved_partner')
    trace=field['relations'].get(other,dict(weight=0.,sources=[]))
    weight=trace['weight'] if enabled else 0.
    if question=='request_again':
        candidates=[dict(action='wait',score=0.)]
        if contacts[other]['holding_food']:candidates.append(dict(action='request',target=other,score=1.-weight))
    else:
        request=next((m for m in reversed(observation['messages']) if m['sender']==other and m['kind']=='request'),None)
        if request is None:raise ValueError('no_request')
        candidates=[dict(action='refuse',target=other,reply_to=request['id'],score=0.)]
        if observation['inventory']>0:
            # Current bodily need and prior affiliation compete with the trace.
            need=max(0.,(80-observation['body']['reserve'])/40)
            candidates.append(dict(action='give',target=other,reply_to=request['id'],score=1.+affiliation-need-weight-retention_cost))
    total=sum(exp(c['score']) for c in candidates)
    u=int.from_bytes(sha256(str(seed).encode()).digest()[:8],'big')/2**64
    cumulative=0.;selected=candidates[-1]
    for c in candidates:
        c['probability']=exp(c['score'])/total;cumulative+=c['probability']
        if u<cumulative:
            selected=c
            break
    # Populate probabilities also after the selected interval.
    for c in candidates:c['probability']=exp(c['score'])/total
    return {k:v for k,v in selected.items() if k not in ('score','probability')},dict(
        question=question,seed=seed,draw=u,weight=weight,sources=deepcopy(trace['sources']),
        candidates=candidates,selected=selected['action'],enabled=enabled,retention=deepcopy(retention))
