"""World-owned moving fixture and bounded forward visual observation."""
from runtime.lw_time import DAY_US
from math import hypot,atan2,degrees
from runtime.moving_hazard_safety import RULE,KEYS


def position(now,scenario='crossing'):
    t=now/1e6%64
    if scenario=='route_crossing' and now<DAY_US:return None
    start=56 if scenario=='night' else 2
    if not start<=t<start+8:return None
    u=t-start
    if scenario=='route_crossing':return dict(x=-28+2*u,z=-2.,radius=.5)
    return dict(x=-8+2*u,z=5.,radius=.5) if scenario!='persistent' else dict(x=0.,z=5.,radius=.5)


def sample(world,p,scenario='crossing',object_state=None):
    obj=object_state if object_state is not None else position(p['capture_us'],scenario);fs=[]
    if obj:
        f,r=world.relative(p['agent_id'],obj);distance=hypot(f,r)
        if f>=0 and distance<=12 and world.visible(p['agent_id'],obj):
            angle=degrees(atan2(r,f));center=round(angle/15)*15
            fs=[dict(appearance='violet_warning' if obj.get('display')=='warning' else 'violet_hazard',azimuth=[max(-90,center-7.5),min(90,center+7.5)],range_band='near' if distance<=4 else 'watch' if distance<=8 else 'far')]
    occluded=any(world.cast(p['agent_id'],angle,4) for angle in range(-90,91,15))
    return dict(rule=RULE,source={k:p[k] for k in KEYS},coverage='partial' if occluded else 'complete',features=fs)
