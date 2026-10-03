"""Territory only versus territory plus a fixed moving hazard, two seeds."""
import argparse,json
from collections import Counter
from math import hypot
from pathlib import Path
from .timed_harvest import run
from .finite_territory_comparison import stock_audit
from .audit_moving_hazard import ROOT


def main(execute=False,days=5,regrowth_days=None):
    reports={}
    for seed in (20261001,20261002):
        for dynamic in (False,True):
            key=f'{seed}_{"patrol" if dynamic else "territory"}';suffix=f'_{days}d_regrow{regrowth_days}' if regrowth_days is not None or days!=5 else '';path=ROOT/f'{key}{suffix}.jsonl'
            if execute:
                run(path,days=days,regrowth_days=regrowth_days,skyline_subrays=True,stop_after_returns=None,seed=seed,
                    goal_difference_mode='enabled',food_goal_mode='enabled',lateral_side='left',
                    orientation_mode='enabled',reposition_mode='enabled',return_completion_mode='enabled',
                    nested_model_mode='enabled',directional_route_mode='enabled',relation_field_mode='enabled',
                    hazard_mode='enabled',hazard_scenario='territorial',warning_review_mode='enabled',
                    territory_resource_layout='three_inside',selection_mode='continuous',dynamic_hazard=dynamic)
            report,_=stock_audit(path);counts=Counter();old=None;distance=0;agents={}
            for line in path.open(encoding='utf8'):
                x=json.loads(line)
                if x['type']=='patrol_world':
                    if old:
                        step=hypot(x['position']['x']-old['position']['x'],x['position']['z']-old['position']['z'])
                        assert step<=1.5*(x['capture_us']-old['capture_us'])/1e6+1e-8
                        distance+=step
                    counts['patrol_blocked']+=int(x['blocked']);old=x
                if x['type']!='decision':continue
                p=x['packet'];aid=p['agent_id'];s=x['continuous_selection']
                assert s['candidates'] and s['selected'] in {c['model'] for c in s['candidates']}
                a=agents.setdefault(aid,Counter());a[x['command']['kind']]+=1
                a['two_visible']+=int(len(p['hazard']['features'])==2)
                a['safety_decisions']+=int(x['activity_phase']=='safety')
                counts['two_visible']+=int(len(p['hazard']['features'])==2)
            if dynamic:assert old and distance>0
            report['patrol_audit']=dict(distance=round(distance,3),counts=dict(counts),agents={a:dict(v) for a,v in agents.items()})
            reports[key]=report
            print(key,report['summary']['pickups'],sum(a['unloaded'] for a in report['summary']['agents'].values()),report['patrol_audit'],flush=True)
    Path(f'tests/fixtures/lightweight_patrol_comparison{suffix}.json').write_text(json.dumps(reports,indent=2),encoding='utf8')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',action='store_true');p.add_argument('--days',type=int,default=5);p.add_argument('--regrowth-days',type=int);a=p.parse_args();main(a.run,a.days,a.regrowth_days)
