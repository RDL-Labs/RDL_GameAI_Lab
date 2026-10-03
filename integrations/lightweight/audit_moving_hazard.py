"""Replay acceptance for bounded moving-hazard interaction."""
import json,hashlib
from pathlib import Path
from collections import Counter
from runtime.moving_hazard_safety import validate

ROOT=Path('integrations/lightweight/output')


def audit(path):
    stats=Counter();events=[];commands=[];previous={};summ=None;seen=set();digest=hashlib.sha256()
    for line in path.open('rb'):
        digest.update(line);r=json.loads(line)
        if r['type']=='manifest':manifest=r
        if r['type']=='summary':summ=r
        if r['type']=='hazard_world':stats['sampled_contacts']+=sum(d<=1 for d in r['distances'].values())
        if r['type']=='completed':
            op=r['result']['operation_id'];assert op not in seen;seen.add(op)
        if r['type']!='decision':continue
        p=r['packet'];c=r['command'];aid=p['agent_id'];s=r.get('safety')
        commands.append(c)
        if not s:continue
        validate(p)
        if manifest.get('selection_mode','legacy')=='legacy':assert s['operations']<=32
        stats[s['reason']]+=1
        prev=previous.get(aid)
        if not prev or s['mode']!=prev['safety']['mode']:
            events.append(dict(agent=aid,capture_us=p['capture_us'],mode=s['mode'],reason=s['reason']))
        if manifest['hazard_mode']=='enabled' and s['override']:
            assert c['reason']==s['reason'] and r['activity_phase']=='safety'
            assert c['kind'] in ('wait','move','turn')
            for n in ('food_goal','goal_difference'):
                if r[n]['trial']:assert r[n]['trial']['interrupted_by_safety']
            if prev:
                old=prev.get('directional_routes') or {};new=r.get('directional_routes') or {}
                for k,v in old.get('routes',{}).items():
                    assert new['routes'][k]['support']==v['support']
                    if new.get('comparison',{}):
                        assert new['comparison']['reason']=='actual_blocked_before_safety'
                    else:assert new['routes'][k]['H']==v['H']
        if s['reason']=='limited_clearance':
            stats['resume_reviews']+=1
            assert not s['override']
        previous[aid]=r
    assert summ and summ['ended_us']==manifest['days']*64000000
    return dict(sha256=digest.hexdigest(),manifest=manifest,summary=summ,counts=dict(stats),transitions=events,
        final_modes={a:r['safety']['mode'] for a,r in previous.items()},command_hash=hashlib.sha256(json.dumps(commands,sort_keys=True).encode()).hexdigest()),commands

if __name__=='__main__':
    results={};base,commands=audit(ROOT/'hazard_disabled_5d.jsonl')
    for mode,scenario in [('shadow','crossing'),('enabled','crossing'),('shadow','route_crossing'),('enabled','route_crossing'),('enabled','night'),('enabled','persistent')]:
        k=mode+'_'+scenario;r,cs=audit(ROOT/f'hazard_{k}.jsonl');results[k]=r
        if mode=='shadow':assert cs==commands
        if scenario=='route_crossing':assert [c for c in cs if c['capture_us']<64000000]==[c for c in commands if c['capture_us']<64000000]
        print(k,r['summary']['pickups'],r['counts'],r['final_modes'])
    results['disabled']=base
    Path('tests/fixtures/lightweight_moving_hazard.json').write_text(json.dumps(results,indent=2),encoding='utf8')
