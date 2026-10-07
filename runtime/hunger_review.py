"""Local food-sufficiency M_B: five-second comparisons, not canonical admission."""
from copy import deepcopy
from math import isfinite
from .goal_difference import initial, begin, finish


def update(previous, agent, now, reserve, observation):
    if type(reserve) not in (int,float) or not isfinite(reserve) or not 0<=reserve<=100:
        raise ValueError('hunger_reserve')
    if type(now) is not int or now<0:raise ValueError('hunger_time')
    s=deepcopy(previous) if previous else dict(goal=initial(agent+':food-sufficiency',
        'reserve-above-80-after-five-seconds-v1','reserve_sufficient',2),last_us=now,due=None)
    if s['goal']['goal_id']!=agent+':food-sufficiency' or now<s['last_us']:
        raise ValueError('hunger_binding')
    if s['due'] is not None and now>=s['due']:
        ident=s['goal']['trial']['trial_id']
        s['goal']=finish(s['goal'],ident,reserve>80,True,observation)
        s['due']=None
    if s['due'] is None and reserve<=80:
        s['goal']=begin(s['goal'],observation,dict(observation=observation,reserve=reserve,capture_us=now))
        s['due']=now+5_000_000
    s['last_us']=now
    s['intensity']=0 if reserve>80 else .05+.95*(80-reserve)/80
    return s


def select(state, proposed):
    """Rank an already feasible food action against the existing activity."""
    strength=state['intensity']
    pressure=min(1.,state['goal']['H']/state['goal']['threshold']) if strength else 0.
    score=.2+strength+pressure
    return dict(rule='hunger-method-contribution-v1',intensity=strength,H=state['goal']['H'],
        threshold=state['goal']['threshold'],food_score=score,existing_score=.5,
        selected=proposed if strength and score>.5 else 'existing_activity')
