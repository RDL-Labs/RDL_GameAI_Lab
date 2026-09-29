"""Audit completed paired runs; never count incomplete execution as an outcome."""
import gzip,hashlib,json,shutil
from collections import Counter
from pathlib import Path

SEEDS=(20260928,20260929,20260930)
THRESHOLDS=(1,2,4)

def audit(path):
    agents={};manifest=None;summary=None;h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for line in f:
            h.update(line);r=json.loads(line)
            if r['type']=='manifest':manifest=r
            if r['type']=='summary':summary=r
            if r['type'] not in ('decision','completed'):continue
            c=r['command'];aid=c['agent_id']
            a=agents.setdefault(aid,dict(movement=0,pickups=0,turns=0,rescans=0,
                home_switches=0,food_switches=0,previous_home='home_first',previous_food='existing_exploration',
                home_H=0,food_H=0))
            if r['type']=='decision':
                method=r['return_state'].get('method','home_first');food=r['food_method']
                if method=='landmark_first' and a['previous_home']!=method:a['home_switches']+=1
                if food=='bounded_rescan' and a['previous_food']!=food:a['food_switches']+=1
                a['previous_home']=method;a['previous_food']=food
                a['home_H']=r['goal_difference']['H'];a['food_H']=r['food_goal']['H']
                assert r['goal_difference']['threshold']==manifest['goal_switch_threshold']
                assert r['food_goal']['threshold']==manifest['goal_switch_threshold']
                assert r['food_review_scans']<=4
                a['rescans']+=int(c['reason']=='food_goal_rescan')
            else:
                a['movement']+=r['result']['forward'];a['pickups']+=int(r['result']['acquired'])
                a['turns']+=int(r['result']['status']=='turned')
    if not summary or summary['reason']!='time_limit' or summary['ended_us']!=1920000000:
        raise ValueError('incomplete run: '+str(path))
    for aid,a in agents.items():
        a.pop('previous_home');a.pop('previous_food')
        batches=[r for r in summary['returns'] if r['agent_id']==aid]
        a.update(deliveries=len(batches),delivered=sum(len(r['pickups']) for r in batches),
                 carried=summary['agents'][aid]['carried'],model_ref=summary['agents'][aid]['model_ref'])
    return dict(manifest=manifest,summary=summary,agents=agents,sha256=h.hexdigest())

def main():
    out=Path('tests/fixtures/lightweight_threshold_sweep');out.mkdir(exist_ok=True)
    archive=Path('integrations/lightweight/output/threshold_evidence');archive.mkdir(exist_ok=True)
    runs=[]
    for seed in SEEDS:
        reference=None
        for threshold in THRESHOLDS:
            source=Path(f'integrations/lightweight/output/threshold_{seed}_{threshold}.jsonl')
            r=audit(source);comparable={k:v for k,v in r['manifest'].items() if k!='goal_switch_threshold'}
            if reference is None:reference=comparable
            assert comparable==reference,'paired initial conditions differ'
            with source.open('rb') as f,gzip.open(archive/f'{seed}_{threshold}.jsonl.gz','wb') as dest:
                shutil.copyfileobj(f,dest)
            runs.append(r)
            print(seed,threshold,r['summary']['pickups'],sum(a['delivered'] for a in r['agents'].values()),
                  sum(a['deliveries'] for a in r['agents'].values()),sum(a['movement'] for a in r['agents'].values()),
                  sum(a['rescans'] for a in r['agents'].values()),flush=True)
    (out/'comparison.json').write_text(json.dumps(dict(runs=runs),indent=2),encoding='utf8')
if __name__=='__main__':main()
