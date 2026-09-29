"""Fixed infinite-resource comparison and observed-landmark positive fixture."""
import hashlib,json
from collections import Counter
from pathlib import Path
from unittest.mock import patch
from .timed_harvest import run
from .world import World

ROOT=Path('integrations/lightweight/output')
CASES=(('natural_disabled',5,'disabled'),('natural_enabled',5,'enabled'),('simple_enabled',4,'enabled'))


def simple_world(*args,**kwargs):
    world=World(*args,**kwargs)
    world.objects=[world.objects[0],dict(x=20.,z=0.,radius=1.,height=8.,color='brown',solid=True)]
    world.resources=[dict(x=18.,z=0.,stock=12)]
    return world


def execute():
    for name,days,mode in CASES:
        kwargs=dict(days=days,seed=20261001,skyline_subrays=True,inexhaustible=True,stop_after_returns=None,
            goal_difference_mode='enabled',food_goal_mode='enabled',lateral_side='left',orientation_mode='enabled',
            reposition_mode='enabled',return_completion_mode='enabled',nested_model_mode='enabled',food_revisit_mode=mode)
        path=ROOT/f'revisit_final_{name}.jsonl'
        if name.startswith('simple'):
            with patch('integrations.lightweight.timed_harvest.World',simple_world):summary=run(path,**kwargs)
        else:summary=run(path,**kwargs)
        print(name,summary['pickups'],flush=True)


def audit():
    reports=[]
    for name,days,mode in CASES:
        path=ROOT/f'revisit_final_{name}.jsonl';digest=hashlib.sha256();summary=None
        daily={}; comparisons=[]; receipts={}; results={};sources={}
        for line in path.open('rb'):
            digest.update(line);r=json.loads(line)
            if r['type']=='manifest':manifest=r
            if r['type']=='summary':summary=r
            if r['type']=='completed':
                result=r['result'];results[result['operation_id']]=(r['command']['agent_id'],result)
            if r['type']!='decision':continue
            p=r['packet'];aid=p['agent_id'];day=p['capture_us']//64000000+1
            sources[p['observation_id']]=aid
            key=f'{aid}:{day}';entry=daily.setdefault(key,dict(revisit_operations=0,first_food_method=None,comparisons=[]))
            s=r.get('food_revisit')
            if not s:continue
            assert s['binding']==[p['run_id'],aid]
            assert len(s['trail'])<=8 and s['operations']<=48 and 0<=s['H']<=32
            if r['activity_phase']=='exploration' and entry['first_food_method'] is None:
                entry['first_food_method']='revisit' if s['attempt'] else 'exploration'
            if s['memory']:
                m=s['memory'];who,result=results[m['success']]
                assert who==aid and result['acquired']
                assert all(sources[x['source']]==aid for x in m['anchors'])
            if s['applied']:
                assert r['activity_phase']=='exploration' and s['memory']
                assert r['command']['reason']=='food_revisit'
                entry['revisit_operations']+=1
            if s['comparison']:
                event=dict(agent=aid,day=day,operations=s['operations'],**s['comparison'])
                comparisons.append(event);entry['comparisons'].append(event)
        assert summary and summary['ended_us']==days*64000000 and summary['reason']=='time_limit'
        assert manifest['stock_mode']=='inexhaustible' and all(x==12 for x in summary['stock'])
        for ret in summary['returns']:
            receipts.setdefault(ret['agent_id'],[]).append(dict(day=ret['day'],count=len(ret['pickups'])))
        reports.append(dict(case=name,sha256=digest.hexdigest(),manifest=manifest,summary=summary,daily=daily,
            comparisons=comparisons,deliveries=receipts))
    a,b=reports[:2]
    assert {k:v for k,v in a['manifest'].items() if k!='food_revisit_mode'}=={k:v for k,v in b['manifest'].items() if k!='food_revisit_mode'}
    assert any(c['E']==0 and c['operations']>0 and c['day']>1 for c in reports[-1]['comparisons'])
    target=Path('tests/fixtures/lightweight_food_revisit.json')
    target.write_text(json.dumps(dict(runs=reports),indent=2),encoding='utf8')
    for r in reports:
        print(r['case'],r['summary']['pickups'],r['deliveries'],Counter(str(c['E']) for c in r['comparisons']),flush=True)

if __name__=='__main__':
    import sys
    if '--run' in sys.argv:execute()
    audit()
