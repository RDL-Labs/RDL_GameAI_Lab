"""Thirty-day blocks of observed behavior, without changing campaign state."""
import json
from collections import Counter
from math import hypot
from pathlib import Path


def summarize(path):
    blocks={};first_zero={};minimum={};last_reserve={};consumed=0
    for line in path.open(encoding='utf8'):
        r=json.loads(line)
        if r['type']=='metabolism':
            for aid,value in r['after'].items():
                minimum[aid]=min(minimum.get(aid,value),value)
                if value==0:first_zero.setdefault(aid,r['end_us']/64_000_000+1)
        if r['type'] not in ('decision','completed'):continue
        c=r['command'];aid=c['agent_id'];day=c['capture_us']//64_000_000+1
        key=str((day-1)//30+1)
        block=blocks.setdefault(key,dict(total=Counter(),agents={}))
        agent=block['agents'].setdefault(aid,Counter());total=block['total']
        def add(key,value=1):agent[key]+=value;total[key]+=value
        if r['type']=='decision':
            s=r.get('continuous_selection') or {}
            if '/ground_' in (s.get('selected') or ''):add('ground_selected')
            continue
        result=r['result'];add('operations');add('action_'+c['kind'])
        if result['status']=='picked_up':add('pickups')
        if result['status']=='moved':add('distance',hypot(result['forward'],result['right']))
        if c['reason'].startswith('continuous_food/ground_'):add('ground_executed')
        ledger=r['food_ledger'];eaten=ledger['consumed']-consumed;consumed=ledger['consumed']
        if eaten:add('eaten',eaten)
        body=r.get('layered_body')
        if body:
            value=body['after']['reserve'];last_reserve[aid]=value
            minimum[aid]=min(minimum.get(aid,value),value)
            if value==0:first_zero.setdefault(aid,result['executed_us']/64_000_000+1)
        block['last_completed_reserve']=dict(last_reserve)
    return dict(blocks=blocks,minimum_reserve=minimum,first_zero_day=first_zero)


def main(root):
    out={name:summarize(root/(name+'.jsonl')) for name in ('disabled','enabled')}
    reports=json.loads((root/'report.json').read_text(encoding='utf8'))
    for name,periods in out.items():
        summary=reports['runs'][name]['audit']['summary']
        assert sum(b['total']['pickups'] for b in periods['blocks'].values())==summary['pickups']
        assert sum(b['total']['eaten'] for b in periods['blocks'].values())==summary['social_consumed']
    (root/'periods.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf8')
    print(json.dumps(out,indent=2))

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('root',type=Path);main(p.parse_args().root)
