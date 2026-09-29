"""Finite World acceptance of relative route weights; observer-only reporting."""
import hashlib,json
from collections import Counter
from pathlib import Path
from runtime.relational_movement import route_strength,WEIGHT_RULE,RULE


def audit():
    path=Path('integrations/lightweight/output/route_weight_5d.jsonl')
    digest=hashlib.sha256();counts=Counter();agents={};summary=None
    for line in path.open('rb'):
        digest.update(line);r=json.loads(line)
        if r['type']=='manifest':manifest=r
        if r['type']=='summary':summary=r
        if r['type']=='completed':
            a=agents.setdefault(r['packet']['agent_id'],dict(movement=0,pickups=0,turns=0))
            a['movement']+=r['result']['forward'];a['pickups']+=int(r['result']['acquired']);a['turns']+=int(r['result']['status']=='turned')
        if r['type']!='decision':continue
        f=r.get('relation_field') or {};s=r.get('directional_routes') or {}
        assert f['rule']==RULE
        cs=f['candidates']
        if cs:
            assert f['weight_rule']==WEIGHT_RULE
            assert abs(sum(c['share'] for c in cs)-1)<1e-12
            counts['eligible_reviews']+=1
            counts['multiple_candidates']+=int(len(cs)>1)
            for c in cs:
                n=s['routes'][c['route']]
                assert c['route'] not in s['failed']
                assert c['score']==route_strength(n) and 0<c['field_weight']<=1
                counts['weakened_candidate_entries']+=int(n['H']>=2)
            if f['applied'] and f['owner']:
                counts['weighted_route_operations']+=1
                counts['competing_route_operations']+=int(len(cs)>1)
                counts['weakened_route_operations']+=int(s['routes'][f['owner']]['H']>=2)
        assert f['operations']<=48
    assert summary and summary['ended_us']==320000000 and summary['reason']=='time_limit'
    assert sum(a['pickups'] for a in agents.values())==summary['pickups']
    old=json.loads(Path('tests/fixtures/lightweight_relation_field_30d.json').read_text())
    baseline={aid:{k:sum(old['daily'][str(d)][aid][k] for d in range(1,6)) for k in ('movement','pickups','turns')} for aid in agents}
    assert {k:v for k,v in manifest.items() if k not in ('days','relation_field_rule')}=={k:v for k,v in old['manifest'].items() if k!='days'}
    out=dict(sha256=digest.hexdigest(),manifest=manifest,counts=dict(counts),agents=agents,baseline_first5=baseline,summary=summary,baseline_sha256=old['sha256'])
    Path('tests/fixtures/lightweight_route_weight_5d.json').write_text(json.dumps(out,indent=2),encoding='utf8')
    print(json.dumps(dict(counts=dict(counts),agents=agents,baseline=baseline)))

if __name__=='__main__':audit()
