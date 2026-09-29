"""Finite purpose-conditioned appraisal, not collision or model mutation."""
from copy import deepcopy
from math import fsum,isclose


def approach_field(terrain, packet):
    out=deepcopy(terrain)
    targets=[i['ref'] for i in packet['food']['visible'] if i['appearance']=='brown_capped_ovoid' and i['forward']>=0]
    active=out['status']=='complete' and packet['food']['coverage']=='complete' and bool(targets)
    out['approach_field']=dict(rule='visible-food-approach-v1',phase='approach' if active else 'unchanged',
        source=packet['observation_id'],target_refs=targets,obstacle_scale=.1 if active else 1.,applied=active)
    if not active:return out
    for row in out['directional_samples']:
        if row['status']!='scored':continue
        row['obstacle_before_approach']=row['obstacle']
        row['obstacle']=row['obstacle']*.1
        row['total']=fsum((row['physical'],row['food'],row['obstacle'],row.get('model_field_cost',0.)))
    scored=[r for r in out['directional_samples'] if r['status']=='scored']
    out['minimum_height']=min(r['total'] for r in scored)
    out['minimum_directions']=[r['direction_deg'] for r in scored if isclose(r['total'],out['minimum_height'],rel_tol=0,abs_tol=1e-9)]
    return out
