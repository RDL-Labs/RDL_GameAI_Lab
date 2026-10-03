"""Finite shared resources overlapping one territory; World-only stock audit."""
import argparse
import json
from collections import Counter
from math import hypot
from pathlib import Path
from hashlib import sha256
from .timed_harvest import run
from .audit_territorial_hazard import inspect,ROOT


def stock_audit(path):
    result,commands=inspect(path)
    manifest=result['manifest'];config=result['territory_config'];resources=manifest['resources']
    assert manifest['stock_mode']=='finite' and not manifest['inexhaustible_after_model']
    overlap=[i for i,r in enumerate(resources) if hypot(r['x']-config['center'][0],r['z']-config['center'][1])<=config['radius']]
    assert overlap and len(overlap)<len(resources)
    initial=[r['stock'] for r in resources];stock=initial[:];events=[];depleted=[];activity=Counter();daily=Counter()
    group_time=None;group_stock=None
    for line in path.open(encoding='utf8'):
        r=json.loads(line)
        assert r['type']!='stock_mode_transition'
        if r['type']!='completed':continue
        now=r['result']['executed_us'];new=r['stock']
        # Scheduler publishes each completion after advancing the whole due batch.
        if group_time is not None and now!=group_time:assert stock==group_stock
        group_time=now;group_stock=new
        acquired=int(r['result']['acquired'])
        assert len(new)==len(stock) and all(x>=0 for x in new)
        if acquired:
            aid=r['result']['agent_id'];run_id=r['result']['run_id']
            ids=[i for i in range(len(resources)) if r['command']['target_ref']=='seen:'+sha256(f'{run_id}:{aid}:{i}'.encode()).hexdigest()[:24]]
            assert len(ids)==1
            i=ids[0];assert stock[i]>0;stock[i]-=1
            events.append(dict(resource=i,inside_territory=i in overlap,agent=aid,capture_us=now,remaining=stock[i]))
            daily[str(now//64000000+1)]+=1
            if stock[i]==0:depleted.append(dict(resource=i,capture_us=now))
        if depleted:activity[r['result']['status']]+=1
    assert stock==group_stock
    assert stock==result['summary']['stock'] and sum(initial)-sum(stock)==result['summary']['pickups']
    assert sum(a['carried']+a['unloaded'] for a in result['summary']['agents'].values())==len(events)
    result['finite_resources']=dict(initial=initial,overlapping_resources=overlap,pickups=events,depletions=depleted,
        daily_pickups=dict(daily),activity_after_first_depletion=dict(activity))
    return result,commands


def main(execute=False):
    reports={};baseline=None
    for mode in ('disabled','shadow','enabled'):
        path=ROOT/f'territory_finite_{mode}.jsonl'
        if execute:
            run(path,days=5,skyline_subrays=True,inexhaustible=False,stop_after_returns=None,
                mb_field_mode='enabled',goal_difference_mode='enabled',food_goal_mode='enabled',
                seed=20261001,lateral_side='left',orientation_mode='enabled',reposition_mode='enabled',
                return_completion_mode='enabled',nested_model_mode='enabled',directional_route_mode='enabled',
                relation_field_mode='enabled',hazard_mode=mode,hazard_scenario='territorial')
        r,c=stock_audit(path);reports[mode]=r
        if mode=='disabled':baseline=c
        if mode=='shadow':assert c==baseline
        print(mode,r['summary']['pickups'],r['summary']['stock'],r['finite_resources']['daily_pickups'],r['final_modes'],flush=True)
    Path('tests/fixtures/lightweight_finite_territory.json').write_text(json.dumps(reports,indent=2),encoding='utf8')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',action='store_true');main(p.parse_args().run)
