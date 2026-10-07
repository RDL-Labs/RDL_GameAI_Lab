"""Shared World ground history; no route or destination knowledge."""
from math import floor,hypot,ceil
from copy import deepcopy


class GroundWear:
    def __init__(self):
        self.cells={};self.operations={};self.now_us=0;self.recovery_enabled=False

    def advance(self,now_us):
        if type(now_us) is not int or now_us<self.now_us:raise ValueError('ground_clock')
        if self.recovery_enabled:
            for cell in self.cells.values():
                start=max(self.now_us,cell['last_walk_us']+64_000_000)
                elapsed=max(0,now_us-start)
                cell['wear']=max(0.,cell['wear']-2*elapsed/64_000_000)
        self.now_us=now_us

    def factor(self,x,z):
        wear=self.cells.get(f'{floor(x)},{floor(z)}',{}).get('wear',0.)
        return 1-.5*min(1.,wear/10.)

    def walk(self,operation,agent,start,end):
        source=[agent,list(start),list(end)]
        if operation in self.operations:
            if self.operations[operation]!=source:raise ValueError('ground_wear_conflict')
            return
        distance=hypot(end[0]-start[0],end[1]-start[1])
        if not distance:return
        self.operations[operation]=source
        n=max(1,ceil(distance/.1))
        for i in range(n):
            t=(i+.5)/n;x=start[0]+t*(end[0]-start[0]);z=start[1]+t*(end[1]-start[1])
            key=f'{floor(x)},{floor(z)}'
            cell=self.cells.setdefault(key,dict(distance=0.,wear=0.,last_walk_us=self.now_us,agents={}))
            cell['distance']+=distance/n
            cell['wear']+=distance/n;cell['last_walk_us']=self.now_us
            cell['agents'][agent]=cell['agents'].get(agent,0.)+distance/n

    def snapshot(self):
        return dict(rule='world-ground-recovery-v1' if self.recovery_enabled else 'world-ground-wear-v1',
            recovery_enabled=self.recovery_enabled,now_us=self.now_us,grace_us=64_000_000,
            recovery_per_day=2,cell_size=1.,road_distance=10.,
            operations=len(self.operations),cells=deepcopy(self.cells))
