"""Fixed World patrol, independent of explorer goals and Runtime policy."""
from copy import deepcopy
from math import cos,sin,radians
from .world import segment_hit
from .moving_hazard import sample
from runtime.moving_hazard_safety import MULTI_RULE


class PatrolHazard:
    def __init__(self):
        self.body=dict(x=-12.,z=-8.,radius=.5)
        self.heading=0;self.last_us=None;self.last=None

    def advance(self,now,objects=()):
        if self.last_us is not None and now<self.last_us:raise ValueError('patrol_clock')
        if now==self.last_us:return deepcopy(self.last)
        dt=0 if self.last_us is None else (now-self.last_us)/1e6
        if dt>.25:raise ValueError('patrol_step')
        if self.last_us is not None and now//12000000!=self.last_us//12000000:self.heading=(self.heading+90)%360
        before=(self.body['x'],self.body['z']);a=radians(self.heading)
        after=(before[0]+1.5*dt*cos(a),before[1]+1.5*dt*sin(a))
        blocked=any(o.get('solid') and segment_hit(before,after,o,.5) for o in objects) if dt else False
        if blocked:self.heading=(self.heading+90)%360
        else:self.body.update(x=after[0],z=after[1])
        self.last_us=now
        self.last=dict(capture_us=now,position=deepcopy(self.body),heading=self.heading,blocked=blocked)
        return deepcopy(self.last)


def sample_pair(world,p,objects):
    if len(objects)>2:raise ValueError('hazard_capacity')
    views=[sample(world,p,object_state=o) for o in objects]
    if not views:raise ValueError('hazard_objects_required')
    out=deepcopy(views[0]);out['rule']=MULTI_RULE
    out['coverage']='partial' if any(v['coverage']=='partial' for v in views) else 'complete'
    out['features']=sorted([f for v in views for f in v['features']],key=lambda f:(f['range_band'],f['azimuth'],f['appearance']))
    return out
