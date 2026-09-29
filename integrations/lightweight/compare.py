"""Offline paired audit; no control authority and no hidden data in Runtime."""
import argparse
import gzip
import hashlib
import json
from collections import Counter
from itertools import zip_longest
from math import hypot, floor
from pathlib import Path


def rows(path):
    opener=gzip.open if str(path).endswith('.gz') else open
    with opener(path,'rt',encoding='utf-8-sig') as f:
        for line in f:
            if line.strip():yield json.loads(line)


def audit(path):
    agents={};manifest=None;summary=None;seen=set();daily={}
    for row in rows(path):
        if row['type']=='manifest':manifest=row;continue
        if row['type']=='summary':summary=row;continue
        if row['type']!='step':continue
        p,c,r=row['packet'],row['command'],row['result'];aid=p['agent_id']
        assert aid==c['agent_id']==r['agent_id']
        assert c['operation_id']==r['operation_id']=='op:'+p['observation_id']
        assert c['operation_id'] not in seen;seen.add(c['operation_id'])
        assert r['executed_us']>=p['capture_us']
        if aid not in agents:
            agents[aid]=dict(observations=0,actions=Counter(),reasons=Counter(),statuses=Counter(),distance=0.,
                cells=set(),field_statuses=Counter(),field_applied=0,first_model_us=None,max_learning_records=0,last_capture=-1,
                previous=manifest['agents'][aid],first_pickup_us=None,acquisition_reasons=Counter(),food_visible_steps=0)
        a=agents[aid];assert p['capture_us']>a['last_capture'];a['last_capture']=p['capture_us']
        assert p['sample_seq']==p['capture_us']//250000
        a['food_visible_steps']+=int(bool(p['food']['visible']))
        if c['reason']=='acquisition_incomplete':
            for key in ('ground','food','landmarks'):
                if p[key]['coverage']!='complete':a['acquisition_reasons'][key+'_partial']+=1
            if p['distant']['coverage']!='COMPLETE_WITHIN_PLAN':a['acquisition_reasons']['distant_partial']+=1
        a['observations']+=1;a['actions'][c['kind']]+=1;a['reasons'][c['reason']]+=1;a['statuses'][r['status']]+=1
        b=row['body'];a['distance']+=hypot(b['x']-a['previous']['x'],b['z']-a['previous']['z']);a['previous']=b
        a['cells'].add((floor(b['x']/4),floor(b['z']/4)))
        a['max_learning_records']=max(a['max_learning_records'],row['learning_count'])
        if row['model_ref'] and a['first_model_us'] is None:a['first_model_us']=p['capture_us']
        if r['acquired'] and a['first_pickup_us'] is None:a['first_pickup_us']=r['executed_us']
        field=(row.get('model_field') or {}).get('field')
        if field:a['field_statuses'][field['status']]+=1;a['field_applied']+=int(field['applied'])
        d=daily.setdefault(str(p['capture_us']//64000000+1),dict(pickups=0,moves=0,turns=0,waits=0))
        d['pickups']+=int(r['acquired']);d['moves']+=int(r['status']=='moved');d['turns']+=int(r['status']=='turned');d['waits']+=int(r['status']=='waited')
    assert manifest and summary,'incomplete run'
    assert sum(a['statuses']['picked_up'] for a in agents.values())==summary['pickups']
    assert sum(x['stock'] for x in manifest['resources'])-sum(summary['stock'])==summary['pickups']
    for aid,a in agents.items():
        assert a['observations']==summary['agents'][aid]['observations']==summary['slots']
        a['visited_4unit_cells']=len(a.pop('cells'));a.pop('previous');a['distance']=round(a['distance'],6)
    return dict(manifest=manifest,summary=summary,agents=agents,daily=daily)


def compare(left,right):
    a,b=audit(left),audit(right)
    # The only predeclared difference is the model-field gate.
    ma,mb=dict(a['manifest']),dict(b['manifest']);ma.pop('model_field');mb.pop('model_field');assert ma==mb
    counts=Counter();first={}
    steps=lambda p:(r for r in rows(p) if r['type']=='step')
    for x,y in zip_longest(steps(left),steps(right)):
        if x is None or y is None:counts['unpaired_steps']+=1;continue
        assert (x['packet']['agent_id'],x['packet']['capture_us'])==(y['packet']['agent_id'],y['packet']['capture_us'])
        for name,v,w in [('packet',x['packet'],y['packet']),('command',x['command'],y['command']),('result',x['result'],y['result']),('body',x['body'],y['body'])]:
            if v!=w:
                counts[name]+=1;first.setdefault(name,dict(agent=x['packet']['agent_id'],capture_us=x['packet']['capture_us']))
    return dict(schema='lw-paired-audit-v1',disabled=a,enabled=b,differences=dict(counts),first_difference=first,
        inputs={str(p):hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in (left,right)})


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('disabled',type=Path);p.add_argument('enabled',type=Path);p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();report=compare(args.disabled,args.enabled);args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print(json.dumps({k:report[k] for k in ('differences','first_difference')}))
