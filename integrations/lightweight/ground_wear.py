"""Shared World ground history; no route or destination knowledge."""
from math import floor,hypot,ceil
from copy import deepcopy


class GroundWear:
    def __init__(self):
        self.cells={};self.operations={}

    def factor(self,x,z):
        wear=self.cells.get(f'{floor(x)},{floor(z)}',{}).get('distance',0.)
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
            cell=self.cells.setdefault(key,dict(distance=0.,agents={}))
            cell['distance']+=distance/n
            cell['agents'][agent]=cell['agents'].get(agent,0.)+distance/n

    def snapshot(self):
        return dict(rule='world-ground-wear-v1',cell_size=1.,road_distance=10.,
            operations=len(self.operations),cells=deepcopy(self.cells))
