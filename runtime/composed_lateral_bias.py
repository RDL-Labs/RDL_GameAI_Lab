"""Bounded handedness on an already appraised terrain; no lost model terms."""
from copy import deepcopy
from math import isclose


def apply(terrain,side):
    if side not in ('left','right'):raise ValueError('lateral_side')
    out=deepcopy(terrain)
    rows={r['direction_deg']:r for r in out['directional_samples']}
    eligible=set()
    if out['status']=='complete' and 0 not in out['minimum_directions']:
        for angle in (45,90):
            left,right=rows[-angle],rows[angle]
            if left['status']!='scored' or right['status']!='scored':continue
            if not {-angle,angle}.intersection(out['minimum_directions']):continue
            if any(abs(left.get(k,0)-right.get(k,0))>.10+1e-9 for k in ('physical','food','obstacle','model_field_cost','total')):continue
            eligible.update((-angle,angle))
    prior=list(out['minimum_directions']) if out['minimum_directions'] is not None else None
    for angle,row in rows.items():
        cost=0.
        if angle in eligible:cost=-.05 if (angle<0)==(side=='left') else .05
        row['lateral_cost']=cost if row['status']=='scored' else None
        if row['status']=='scored':row['total']+=cost
    if eligible:
        minimum=min(r['total'] for r in rows.values() if r['status']=='scored')
        out['minimum_height']=minimum
        out['minimum_directions']=[a for a,r in rows.items() if r['status']=='scored' and isclose(r['total'],minimum,abs_tol=1e-9,rel_tol=0)]
    out['lateral']=dict(rule='composed-lateral-near-tie-v1',side=side,height=.05,width=.10,
        eligible=sorted(eligible),applied=bool(eligible),before_minima=prior,after_minima=out['minimum_directions'])
    return out
