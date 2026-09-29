"""Finite observed-landmark search with the home purpose retained.

No Food selection, World map, reverse path, or learned route authority.
"""
from copy import deepcopy
from types import SimpleNamespace
from .landmark_day_cycle import home_review, DAY_US
from .landmark_exploration import LandmarkExplorationDay, initial_state
from .exploration_series import digest

MAX_SEARCH_OPERATIONS=32


def review(agent,packet,memory,state,linked,result):
    s=deepcopy(state)
    search=s.setdefault('search',dict(landmark=initial_state(),operations=0,mode='homing',purpose='find-home-appearance'))
    if not linked or memory is None:
        return home_review(packet,memory,s,linked,result)
    if s['outcome'] not in (None,'not_observed','ambiguous','blocked'):
        return ['wait',0],s
    # While searching, recheck home at each actual new observation. A search
    # collision is handled by the landmark controller, not attributed to home.
    probe=deepcopy(s);probe['outcome']=None
    action,h=home_review(packet,memory,probe,linked,result if search['mode']=='homing' else None)
    prefer_search=s.get('method')=='landmark_first' and search['operations']<8 and h['outcome']!='home_like_observed'
    if not prefer_search and h['diagnostic']=='appearance_candidate' and h['outcome'] in (None,'home_like_observed'):
        search['mode']='homing';search['landmark']['stage']='suspended'
        h['search']=search
        return action,h
    if not prefer_search and search['mode']=='homing' and h['outcome'] not in ('not_observed','ambiguous','blocked'):
        return action,h
    search['mode']='searching'
    s['outcome']=None
    s['diagnostic']='searching_home'
    if search['operations']>=MAX_SEARCH_OPERATIONS:
        s['outcome']='search_operation_budget';return ['wait',0],s
    view=SimpleNamespace(observations=agent.observations,results=agent.results,
        decisions={'last':dict(landmark=search['landmark'])},
        seed=int(digest([agent.seed,packet['capture_us']//DAY_US,'home-search-attempt'])[:8],16))
    action,landmark=LandmarkExplorationDay._subgoal(view,packet)
    search['landmark']=landmark
    s['diagnostic']='search_'+(landmark['outcome'] or landmark['stage'])
    if action[0] in ('move','turn'):search['operations']+=1
    # Keep cumulative goal/scan/operation budgets across home/search switches.
    return action,s
