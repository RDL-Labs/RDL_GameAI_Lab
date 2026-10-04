"""Energy cost contribution to existing finite method candidates."""
from .energy_field import evaluate
from .layered_body import capabilities

ANGLES=(-90,-45,0,45,90)


def validate_energy(b):
    e=b['energy']
    if set(e)!={'load','climb_resistance','samples'}:raise ValueError('energy_fields')
    capabilities(b['state'],e['load'],e['climb_resistance'])
    if len(e['samples'])!=5:raise ValueError('energy_samples')
    for angle,s in zip(ANGLES,e['samples']):
        if set(s)!={'angle','clear','resistance'} or s['angle']!=angle:raise ValueError('energy_angles')
    evaluate(b['state'],e['load'],[dict(ref=str(s['angle']),action='walk',clear=s['clear'],
             resistance=s['resistance'],goal_cost=0.) for s in e['samples']])


def apply(p,candidates):
    b=p['locomotor'];e=b['energy'];validate_energy(b)
    field=evaluate(b['state'],e['load'],[dict(ref=str(s['angle']),action='walk',clear=s['clear'],
                   resistance=s['resistance'],goal_cost=0.) for s in e['samples']])
    baseline=min(candidates,key=lambda c:(-c['score'],c['last_selected'],c['model']))['model']
    rows={int(r['ref']):r for r in field['rows']};contributions=[];retained=[]
    for c in candidates:
        angle=0 if c['action'][0]=='move' else c['action'][1] if c['question']=='rotation_then_step' else None
        row=rows.get(angle)
        if row is None:
            retained.append(c);continue
        contributions.append(dict(model=c['model'],angle=angle,status=row['status'],cost=row['cost'],score_before=c['score']))
        if row['cost'] is not None:
            c['score']-=row['cost'];retained.append(c)
    # This wait is not a trial of any rejected movement method.
    if not retained:
        retained=[dict(model='energy/no_feasible_move',action=['wait',0],
                       question=None,score=0.,last_selected=0,record_trial=False)]
    candidates[:]=retained
    selected=min(candidates,key=lambda c:(-c['score'],c['last_selected'],c['model']))['model']
    return dict(rule='energy-candidate-connection-v1',field=field,contributions=contributions,
                baseline=baseline,selected=selected,changed=baseline!=selected)
