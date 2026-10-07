"""Finite own-provision constraint on giving; no prohibition or new evidence."""
from math import isfinite


def evaluate(observation, hunger):
    band=observation['food_band'];reserve=observation['body']['reserve']
    if band not in ('none','low','some','many'):raise ValueError('retention_band')
    if type(reserve) not in (int,float) or not isfinite(reserve) or not 0<=reserve<=100:
        raise ValueError('retention_reserve')
    goal=hunger['goal']
    if goal['goal_id']!=observation['self_id']+':food-sufficiency':raise ValueError('retention_owner')
    scarcity={'none':0.,'low':1.,'some':.4,'many':0.}[band]
    need=max(0.,(80-reserve)/80)
    pressure=min(1.,goal['H']/goal['threshold']) if reserve<=80 else 0.
    cost=scarcity*(1+2*need+pressure)
    return dict(rule='own-food-retention-v1',band=band,reserve=reserve,H=goal['H'],
                scarcity=scarcity,need=need,pressure=pressure,cost=cost)
