"""Three-day continuous exploration, social actions and existing nightly Sleep."""
from collections import Counter
import gzip
import json
from pathlib import Path
from .timed_harvest import run


OPTIONS=dict(days=3,stop_after_returns=None,body_mode='enabled',energy_mode='enabled',
             selection_mode='continuous',sleep_learning=True,social_mode='enabled',social_pressure=False,
             return_completion_mode='enabled',orientation_mode='enabled',seed=20261004)


def audit(path):
    rows=[json.loads(x) for x in Path(path).read_text(encoding='utf8').splitlines()]
    manifest=next(r for r in rows if r['type']=='manifest')
    inventories={a:b['inventory'] for a,b in manifest['agents'].items()}
    initial=sum(inventories.values())+sum(r['stock'] for r in manifest['resources'])
    stock=consumed=0;effects=set();requests=[];kinds=Counter();conserved=True;clocks={};overlap=False
    for r in rows:
        if r['type']=='social_effect':
            inventories=dict(r['inventory']);stock=r['stock'];consumed=r['consumed']
            kinds[r['intent']['action']+':'+r['result']['status']]+=1
        elif r['type']=='completed':
            c=r['command'];result=r['result'];op=c['operation_id'];aid=c['agent_id']
            if op in effects:raise AssertionError('duplicate_effect')
            effects.add(op)
            overlap |= c['capture_us']<clocks.get(aid,0)
            clocks[aid]=result['executed_us']
            ledger=r['food_ledger']
            conserved &= sum(ledger['carried'].values())+ledger['ground']+ledger['shared']+ledger['consumed']==initial
        elif r['type']=='decision' and (r.get('social_intent') or {}).get('action')=='request':
            requests.append(dict(day=r['packet']['capture_us']//64_000_000+1,agent=r['packet']['agent_id'],
                                 target=r['social_intent']['target'],observation=r['packet']['observation_id']))
    summary=rows[-1]
    cycles={a:[c['status'] for c in b['sleep']['completed']+[b['sleep']['cycle']] if c]
            for a,b in summary['agents'].items()}
    return dict(initial_food=initial,conserved=conserved,body_overlap=overlap,effects=len(effects),
                actions=dict(kinds),requests=requests,sleep_cycles=cycles)


def main():
    root=Path('tests/fixtures/social_life');root.mkdir(parents=True,exist_ok=True)
    outputs=Path('outputs/social_life');outputs.mkdir(parents=True,exist_ok=True)
    report={}
    for name,scene,adopt in [('shadow','social_camp',False),('enabled','social_camp',True),('shared','social_shared',True)]:
        path=outputs/(name+'.jsonl');options=dict(OPTIONS,body_scene=scene,social_adopt=adopt)
        summary=run(path,**options);summary.pop('elapsed_seconds',None)
        checked=audit(path)
        assert checked['conserved'] and not checked['body_overlap']
        report[name]=dict(options=options,summary=summary,audit=checked)
        with gzip.GzipFile(filename=str(root/(name+'.jsonl.gz')),mode='wb',mtime=0) as f:f.write(path.read_bytes())
        first={}
        for r in checked['requests']:first.setdefault((r['day'],r['agent']),r['target'])
        print(name,checked['actions'],first,checked['sleep_cycles'],flush=True)
    (root/'comparison.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    return report


if __name__=='__main__':main()
