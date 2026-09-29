"""Summarize completed side/threshold/seed runs; raw traces stay local."""
import hashlib,json
from pathlib import Path
from .audit_threshold_sweep import SEEDS,THRESHOLDS,audit

def summarize(path):
    report=audit(path)
    traces=0;applied=0;changed=0;example=None;commands=hashlib.sha256()
    for line in Path(path).open(encoding='utf8'):
        r=json.loads(line)
        if r['type']!='decision':continue
        c=r['command']
        commands.update(json.dumps([c['agent_id'],c['capture_us'],c['kind'],c['amount'],c['target_ref']],separators=(',',':')).encode())
        t=r.get('lateral')
        if t is None:continue
        traces+=1;applied+=int(t['applied']);changed+=int(t['before_minima']!=t['after_minima'])
        if t['applied'] and example is None:example=dict(packet=r['packet'],command=c,trace=t)
    report['lateral']=dict(evaluated=traces,applied=applied,minima_changed=changed,first_applied=example)
    report['action_sha256']=commands.hexdigest()
    return report

def main():
    runs=[]
    for seed in SEEDS:
        reference=None
        for threshold in THRESHOLDS:
            for side in ('left','right'):
                r=summarize(f'integrations/lightweight/output/lateral_{seed}_{threshold}_{side}.jsonl')
                comparable={k:v for k,v in r['manifest'].items() if k not in ('goal_switch_threshold','lateral_side')}
                if reference is None:reference=comparable
                assert comparable==reference,'initial-condition mismatch'
                runs.append(r)
                print(seed,threshold,side,r['summary']['pickups'],sum(a['delivered'] for a in r['agents'].values()),r['lateral']['applied'],r['lateral']['minima_changed'],flush=True)
    pairs=[]
    for i in range(0,len(runs),2):
        a,b=runs[i:i+2]
        pairs.append(dict(seed=a['manifest']['seed'],threshold=a['manifest']['goal_switch_threshold'],
            actions_identical=a['action_sha256']==b['action_sha256']))
    Path('tests/fixtures/lightweight_lateral_threshold_comparison.json').write_text(json.dumps(dict(runs=runs,pairs=pairs),indent=2),encoding='utf8')
if __name__=='__main__':main()
