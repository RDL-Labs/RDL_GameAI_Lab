"""Small four-layer body approximation; not ATP kinetics or physiology."""
from copy import deepcopy
from math import isfinite

RULE = 'layered-body-v1'
ACTIONS = {'walk', 'run', 'climb', 'rest', 'eat'}


def initial():
    return dict(rule=RULE, burst=10., strain=0., reserve=100., damage=0.)


def validate(s):
    if s.get('rule') != RULE:
        raise ValueError('body_rule')
    for name, maximum in (('burst',10),('strain',1),('reserve',100),('damage',1)):
        x=s.get(name)
        if type(x) not in (int,float) or not isfinite(x) or not 0<=x<=maximum:
            raise ValueError('body_state')


def capabilities(s):
    validate(s)
    integrity=1-s['damage']
    return dict(walk_distance=.5*integrity,run_distance=1.5*integrity,
        climb_distance=1.*integrity,climb_height=.6*integrity,
        burst_capacity=10*integrity,
        can_walk=s['reserve']>=.1 and s['strain']<1 and integrity>0,
        can_run=s['reserve']>=.5 and s['burst']>=3 and s['strain']<=.8 and integrity>0,
        can_climb=s['reserve']>=.4 and s['burst']>=4 and s['strain']<=.8 and integrity>0)


def step(s, action, *, unobstructed=True, food_available=False):
    """One second, one body action. Caller owns geometry and food inventory."""
    validate(s)
    if action not in ACTIONS or type(unobstructed) is not bool or type(food_available) is not bool:
        raise ValueError('body_action')
    out=deepcopy(s);cap=capabilities(s);distance=0.;ate=False
    if action in ('walk','run','climb'):
        if not cap['can_'+action]:status='body_limited'
        elif not unobstructed:
            status='blocked';out['reserve']=max(0,out['reserve']-.05)
        else:
            status='performed';distance=cap[action+'_distance']
            burst,energy,strain={'walk':(0,.1,.03),'run':(3,.5,.18),'climb':(4,.4,.15)}[action]
            out['burst']-=burst;out['reserve']-=energy;out['strain']=min(1,out['strain']+strain)
    elif action=='eat':
        status='ate' if food_available else 'no_food'
        if food_available:out['reserve']=min(100,out['reserve']+20);ate=True
    else:
        status='rested'
        # Recovery draws on reserves; depleted bodies cannot refill by waiting.
        recovery=min(1,s['reserve']/20)*(1-s['damage'])
        out['burst']=min(cap['burst_capacity'],out['burst']+2*recovery)
        out['strain']=max(0,out['strain']-.15*recovery)
        out['reserve']=max(0,out['reserve']-.05*recovery)
    out['burst']=min(out['burst'],cap['burst_capacity'])
    validate(out)
    return out,dict(action=action,status=status,seconds=1,distance=distance,
        food_consumed=int(ate),delta={k:out[k]-s[k] for k in ('burst','strain','reserve','damage')})
