"""Bounded zero-harvest seed screen; positions are observer-only diagnostics."""
import hashlib,json,sys
from collections import Counter
from pathlib import Path

def audit(path):
    digest=hashlib.sha256(); agents={}; summary=None
    for line in Path(path).open('rb'):
        digest.update(line); row=json.loads(line)
        if row['type']=='manifest': manifest=row
        if row['type']=='summary': summary=row
        if row['type']!='completed': continue
        c=row['command']; r=row['result']; aid=c['agent_id']; day=int(c['capture_us']//64000000)+1
        a=agents.setdefault(aid,dict(pickups=0,movement=0,turns=0,wait_reasons=Counter(),days={},cells=set(),still=0,max_still=0))
        d=a['days'].setdefault(str(day),dict(movement=0,pickups=0,new_2m_cells=0,cells=set()))
        moved=r['forward']; a['movement']+=moved; d['movement']+=moved
        a['pickups']+=int(r['acquired']); d['pickups']+=int(r['acquired'])
        a['turns']+=int(r['status']=='turned')
        if c['kind']=='wait': a['wait_reasons'][c['reason']]+=1
        a['still']=0 if moved else a['still']+1; a['max_still']=max(a['max_still'],a['still'])
        cell=(int(row['body']['x']//2),int(row['body']['z']//2)); d['new_2m_cells']+=int(cell not in a['cells']); a['cells'].add(cell); d['cells'].add(cell)
    if not summary or summary['reason']!='time_limit' or summary['ended_us']!=manifest['days']*64000000:
        raise ValueError('incomplete run: '+str(path))
    for aid,a in agents.items():
        a['visited_2m_cells']=len(a.pop('cells')); a.pop('still')
        a['max_nontranslation_completions']=a.pop('max_still')
        a['zero_translation_days']=[day for day in range(1,manifest['days']+1) if a['days'].get(str(day),{}).get('movement',0)==0]
        for d in a['days'].values(): d['visited_2m_cells']=len(d.pop('cells'))
        a['delivered']=sum(len(r['pickups']) for r in summary['returns'] if r['agent_id']==aid)
    return dict(path=str(path),sha256=digest.hexdigest(),manifest=manifest,summary=summary,agents=agents)

if __name__=='__main__':
    reports=[audit(p) for p in sys.argv[2:]]
    fixed=[{k:v for k,v in r['manifest'].items() if k not in ('seed','objects','resources','days')} for r in reports]
    assert all(f==fixed[0] for f in fixed), 'non-layout configuration changed'
    Path(sys.argv[1]).write_text(json.dumps(dict(runs=reports),indent=2),encoding='utf8')
    for r in reports:
        print(r['manifest']['seed'],r['manifest']['days'],json.dumps({k:{x:v for x,v in a.items() if x not in ('days','wait_reasons')} for k,a in r['agents'].items()}))


