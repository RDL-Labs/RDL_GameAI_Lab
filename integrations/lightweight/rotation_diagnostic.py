"""Observer-only stationary rotation analysis of completed body operations."""
import argparse
from collections import Counter
import json
from math import hypot
from pathlib import Path


def analyze(path, limit_us):
    states={};contexts={}
    def state(a):
        return states.setdefault(a,dict(turns=0,moves=0,stationary_reversals=0,
            turn_followed_by_move=0,previous_kind=None,position=None,previous_sign=None,
            chain=[],stationary=[],max_chain=[],max_stationary=[],episodes=[],reasons=Counter()))
    def finish(s):
        if len(s['chain'])>=4:s['episodes'].append(s['chain'])
        if len(s['chain'])>len(s['max_chain']):s['max_chain']=s['chain'][:]
        if len(s['stationary'])>len(s['max_stationary']):s['max_stationary']=s['stationary'][:]
        s['chain']=[];s['stationary']=[];s['previous_sign']=None
    with Path(path).open(encoding='utf8') as stream:
        for line in stream:
            r=json.loads(line)
            if r.get('capture_us',0)>limit_us:break
            if r['type']=='decision':
                c=r['command'];contexts[c['operation_id']]=r['activity_phase']
            if r['type']!='completed':continue
            v=r['result'];c=r['command'];b=r['body'];t=v['executed_us']
            if t>limit_us:continue
            s=state(c['agent_id']);pos=(b['x'],b['z'])
            displaced=s['position'] is not None and hypot(pos[0]-s['position'][0],pos[1]-s['position'][1])>1e-6
            s['position']=pos
            phase=contexts.pop(c['operation_id'],None)
            if displaced or (v['status']=='moved' and hypot(v.get('forward',0),v.get('right',0))>1e-6):
                s['moves']+=1
                s['turn_followed_by_move']+=s['previous_kind']=='turned'
                finish(s)
            elif v['status']=='turned' and v['yaw']:
                sign=1 if v['yaw']>0 else -1
                item=dict(t=t,yaw=v['yaw'],x=pos[0],z=pos[1],phase=phase,reason=c['reason'])
                s['turns']+=1;s['reasons'][c['reason']]+=1;s['stationary'].append(item)
                if s['previous_sign'] is not None and sign!=s['previous_sign']:
                    s['stationary_reversals']+=1;s['chain'].append(item)
                else:
                    if len(s['chain'])>=4:s['episodes'].append(s['chain'])
                    if len(s['chain'])>len(s['max_chain']):s['max_chain']=s['chain'][:]
                    s['chain']=[item]
                s['previous_sign']=sign
            s['previous_kind']=v['status']
    def describe(chain):
        if not chain:return None
        return dict(turns=len(chain),start_us=chain[0]['t'],end_us=chain[-1]['t'],
            duration_us=chain[-1]['t']-chain[0]['t'],position=[chain[0]['x'],chain[0]['z']],
            max_position_displacement=max(hypot(x['x']-chain[0]['x'],x['z']-chain[0]['z']) for x in chain),
            reasons=dict(Counter(x['reason'] for x in chain)),first_turns=chain[:6])
    report={}
    for a,s in states.items():
        finish(s)
        report[a]={k:s[k] for k in ('turns','moves','stationary_reversals','turn_followed_by_move')}
        report[a].update(max_alternating=describe(s['max_chain']),max_stationary=describe(s['max_stationary']),
            alternating_episodes_ge4=len(s['episodes']),reasons=dict(s['reasons']))
    return report


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('log');p.add_argument('--seconds',type=int,required=True)
    args=p.parse_args();print(json.dumps(analyze(args.log,args.seconds*1_000_000),indent=2))
