"""Finite observed candidate costs; not a global map or a Newtonian solver."""
from runtime.layered_body import step, capabilities
from math import isfinite


def evaluate(body, load, samples):
    capabilities(body,load)
    if not isinstance(samples,list) or not 1<=len(samples)<=5:raise ValueError('energy_budget')
    rows=[];seen=set()
    for s in samples:
        if set(s)!={'ref','action','clear','resistance','goal_cost'}:raise ValueError('energy_fields')
        if not isinstance(s['ref'],str) or not s['ref'] or s['ref'] in seen:raise ValueError('energy_reference')
        seen.add(s['ref'])
        if s['action'] not in ('walk','climb','detour'):raise ValueError('energy_action')
        goal=s['goal_cost']
        if type(goal) not in (int,float) or not isfinite(goal) or not 0<=goal<=10:raise ValueError('energy_goal')
        if s['clear'] is not None and type(s['clear']) is not bool:raise ValueError('energy_clear')
        row=dict(s,status='unknown',cost=None,expected_delta=None)
        if s['clear'] is not None and s['resistance'] is not None:
            after,r=step(body,'walk' if s['action']=='detour' else s['action'],load=load,
                         resistance=s['resistance'],unobstructed=s['clear'])
            row['status']=r['status'];row['expected_delta']=r['delta']
            if r['status']=='performed':
                # Explicit initial valuation: relative reserve/instant effort + strain.
                row['cost']=goal-r['delta']['reserve']/max(body['reserve'],.001)-r['delta']['burst']/max(body['burst'],.001)+r['delta']['strain']
        rows.append(row)
    feasible=[r for r in rows if r['cost'] is not None]
    chosen=min(feasible,key=lambda r:(r['cost'],r['ref'])) if feasible else None
    return dict(rule='finite-energy-field-v1',rows=rows,selected=chosen['ref'] if chosen else None,
                action=chosen['action'] if chosen else 'rest',status='selected' if chosen else 'no_feasible_observed_move')
