"""World-owned fixed territorial response; policy and body execution are separate."""
from copy import deepcopy
from math import hypot
from .world import segment_hit

RULE='fixed-territorial-response-v1'


def resource_layout(world,layout='original'):
    """Experimenter placement only; keep shared stock and total site count."""
    if layout not in ('original','three_inside'):raise ValueError('territory_resource_layout')
    if layout=='three_inside':
        for index,x,z in ((1,-18.,-2.),(3,-20.,2.)):
            world.resources[index].update(x=x,z=z)


class TerritorialHazard:
    def __init__(self,center=(-20.,-2.),home=(-20.,-14.),radius=8.,leash=12.):
        self.center=center;self.home=home;self.radius=radius;self.leash=leash
        self.body=dict(x=home[0],z=home[1],radius=.5)
        self.mode='idle';self.target=None;self.last_us=None;self.last=None

    def decide(self,agents):
        """Fixed World detector, NOT the explorer's observation or learned model."""
        inside={a:b for a,b in agents.items() if hypot(b['x']-self.center[0],b['z']-self.center[1])<=self.radius}
        if self.mode=='returning':return dict(mode='returning',target=None,goal=self.home)
        if self.target and self.target not in inside:return dict(mode='returning',target=None,goal=self.home)
        target=self.target
        if not target and inside:
            target=min(inside,key=lambda a:(hypot(inside[a]['x']-self.body['x'],inside[a]['z']-self.body['z']),a))
        if not target:return dict(mode='idle',target=None,goal=self.home)
        b=inside[target];goal=(b['x'],b['z'])
        if hypot(self.body['x']-self.home[0],self.body['z']-self.home[1])>=self.leash:
            return dict(mode='returning',target=None,goal=self.home)
        mode='warning' if hypot(b['x']-self.body['x'],b['z']-self.body['z'])<=3 else 'approaching'
        return dict(mode=mode,target=target,goal=goal)

    def execute(self,intent,dt,objects):
        """Bounded straight motion, collision stop, and visual display only."""
        self.mode=intent['mode'];self.target=intent['target'];blocked=False
        if self.mode in ('approaching','returning'):
            before=(self.body['x'],self.body['z']);gx,gz=intent['goal'];dx,dz=gx-before[0],gz-before[1];distance=hypot(dx,dz)
            travel=min(2*dt,max(0,distance-(3 if self.mode=='approaching' else 0)))
            after=(before[0]+dx*travel/distance,before[1]+dz*travel/distance) if distance else before
            if self.mode=='approaching' and hypot(after[0]-self.home[0],after[1]-self.home[1])>self.leash:
                self.mode='returning';self.target=None
            elif travel and any(o.get('solid') and segment_hit(before,after,o,self.body['radius']) for o in objects):blocked=True
            else:self.body.update(x=after[0],z=after[1])
            if self.mode=='returning' and hypot(self.body['x']-self.home[0],self.body['z']-self.home[1])<1e-8:self.mode='idle'
        return blocked

    def advance(self,now,agents,objects=()):
        if self.last_us is not None and now<self.last_us:raise ValueError('territory_clock')
        if now==self.last_us:return deepcopy(self.last)
        dt=0 if self.last_us is None else (now-self.last_us)/1e6
        if dt>.25:raise ValueError('territory_step_budget')
        intent=self.decide(agents);blocked=self.execute(intent,dt,objects)
        self.last_us=now
        self.last=dict(rule=RULE,capture_us=now,mode=self.mode,target=self.target,blocked=blocked,
            position=dict(self.body,display='warning' if self.mode=='warning' else 'ordinary'))
        return deepcopy(self.last)
