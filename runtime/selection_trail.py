"""Local parent/context/method trails: actual use and whole-episode success."""
from copy import deepcopy
import json
from .experience_bundle import context


def key(p,phase,c):
    return json.dumps([p['agent_id']+':food-sufficiency',context(p),phase,c['model'],c['action']],sort_keys=True)


def apply(agent,p,s,phase):
    trace=dict(status='protected',changed=False,contributions=[])
    if phase not in ('exploration','return') or s['gate']!='method_reselection':return trace
    state=agent.learning.get('selection_trail') or {}
    if state and state['binding']!=[p['run_id'],p['agent_id']]:raise ValueError('trail_binding')
    order=lambda c:(-c['score'],c['last_selected'],c['model'])
    baseline=min(s['candidates'],key=order)['model']
    for c in s['candidates']:
        if not c.get('record_trial',True):continue
        edge=key(p,phase,c);stored=state.get('edges',{}).get(edge,{})
        delta=min(1.,stored.get('uses',0)*.02)+min(1.,stored.get('success_credit',0)*.125)
        c['score']+=delta
        trace['contributions'].append(dict(edge=edge,candidate=c['model'],delta=delta))
    selected=min(s['candidates'],key=order)['model']
    trace.update(status='eligible',baseline=baseline,selected=selected,changed=baseline!=selected)
    return trace


def review(previous,agent,p,hunger):
    s=deepcopy(previous) if previous else dict(binding=[p['run_id'],p['agent_id']],edges={},episode=None,completed=[],cursor=None)
    if s['binding']!=[p['run_id'],p['agent_id']]:raise ValueError('trail_binding')
    old=next(reversed(agent.observations.values()),None)
    if old and s['cursor']!=old['observation_id']:
        ident=old['observation_id'];d=agent.decisions[ident];cs=d.get('continuous_selection') or {}
        trace=cs.get('selection_trail') or {};command=agent.commands.get(ident)
        result=agent.results.get(command['operation_id']) if command else None
        chosen=next((c for c in cs.get('candidates',[]) if c['model']==cs.get('selected')),None)
        eligible=(trace.get('status')=='eligible' and command and result and chosen
            and chosen.get('record_trial',True) and result['status'] not in ('stale','expired')
            and result['executed_us']<p['capture_us'] and [command['kind'],command['amount']]==chosen['action'])
        if eligible:
            edge=key(old,d['day_cycle']['phase'],chosen)
            if edge in s['edges'] or len(s['edges'])<512:
                e=s['edges'].setdefault(edge,dict(uses=0,success_credit=0,successes=0))
                e['uses']+=1;e['last_operation']=command['operation_id']
                if old['social']['body']['reserve']<=80:
                    if s['episode'] is None:s['episode']=dict(start=ident,edges={},max_H=0)
                    ep=s['episode'];H=d['hunger']['H'];ep['max_H']=max(ep['max_H'],H)
                    entry=ep['edges'].setdefault(edge,dict(first_operation=command['operation_id'],uses=0,bundle_refs=[]))
                    entry['uses']+=1
                    refs={ref for c in (cs.get('experience_bundle') or {}).get('contributions',[]) for ref in c['model_refs']}
                    entry['bundle_refs']=sorted(set(entry['bundle_refs'])|refs)
            else:s['capacity_reached']=True
        s['cursor']=ident
    # No elapsed-time failure: hold until observed parent sufficiency.
    if s['episode'] and p['social']['body']['reserve']>80:
        ep=s['episode'];total=1+min(8,ep['max_H']);share=total/len(ep['edges'])
        for edge in ep['edges']:
            e=s['edges'][edge];e['successes']+=1;e['success_credit']=min(8.,e['success_credit']+share)
        ep.update(confirmed_by=p['observation_id'],confirmed_us=p['capture_us'],credit=total)
        s['completed'].append(ep);s['episode']=None
    return s
