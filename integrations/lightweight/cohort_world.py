"""Experimenter-only environmental transfer; never transfers agent learning."""
from copy import deepcopy


def checkpoint(world,regrowth,territory,patrol,next_us):
    result=deepcopy(dict(rule='cohort-world-v1',next_us=next_us,
        objects=world.objects,resources=world.resources,stock=getattr(world,'stock',0),
        ground=world.ground_wear.snapshot() if world.ground_wear_enabled else None,
        regrowth=vars(regrowth) if regrowth else None,
        territory=vars(territory) if territory else None,patrol=vars(patrol) if patrol else None))
    if result['ground']:
        for cell in result['ground']['cells'].values():
            cell['agents']={(a if '/' in a else world.run_id+'/'+a):v for a,v in cell['agents'].items()}
    return result


def restore(world,regrowth,territory,patrol,state,reset_wear=False):
    if state is None:
        if reset_wear:raise ValueError('reset_requires_checkpoint')
        return 0
    s=deepcopy(state)
    if s['rule']!='cohort-world-v1':raise ValueError('checkpoint_rule')
    world.objects=s['objects'];world.resources=s['resources'];world.stock=s['stock']
    for obj,key in ((regrowth,'regrowth'),(territory,'territory'),(patrol,'patrol')):
        if (obj is None)!=(s[key] is None):raise ValueError('checkpoint_configuration')
        if obj is not None:obj.__dict__.update(s[key])
    # The old cohort leaves. The territorial actor cannot keep targeting its IDs.
    if territory and territory.target:
        territory.target=None;territory.mode='returning'
    g=s['ground']
    if bool(g)!=world.ground_wear_enabled:raise ValueError('checkpoint_ground')
    if g:
        if g['recovery_enabled']!=world.ground_wear.recovery_enabled:raise ValueError('checkpoint_recovery')
        world.ground_wear.cells=g['cells'];world.ground_wear.now_us=g['now_us']
        if reset_wear:
            for cell in world.ground_wear.cells.values():cell['wear']=0.
    return s['next_us']
