"""Audit shared resource consumption from observed reference bindings and World stock totals, observer-only."""
import hashlib,json
from pathlib import Path
from collections import defaultdict

def audit(path):
    consumers=defaultdict(lambda:defaultdict(int));commands=hashlib.sha256();raw=hashlib.sha256();summary=None
    with Path(path).open('rb') as f:
        for line in f:
            raw.update(line);r=json.loads(line)
            if r['type']=='manifest':
                manifest=r;stock=[x['stock'] for x in r['resources']]
            elif r['type']=='decision':
                c=r['command'];commands.update(json.dumps(c,sort_keys=True,separators=(',',':')).encode())
            elif r['type']=='completed':
                after=r['stock'];delta=[a-b for a,b in zip(stock,after)]
                if r['result']['acquired']:
                    c=r['command'];aid=c['agent_id']
                    matches=[i for i in range(len(stock)) if c['target_ref']=='seen:'+hashlib.sha256(f"{c['run_id']}:{aid}:{i}".encode()).hexdigest()[:24]]
                    assert len(matches)==1
                    consumers[str(matches[0])][aid]+=1
                assert all(x>=0 for x in delta) # WorkScheduler may finish several agents before emitting results.
                stock=after
            elif r['type']=='summary':summary=r
    assert summary and summary['ended_us']==1920000000 and summary['reason']=='time_limit'
    assert sum(sum(a.values()) for a in consumers.values())==summary['pickups']
    for i,initial in enumerate(manifest['resources']):
        assert initial['stock']-stock[i]==sum(consumers[str(i)].values())
    return dict(manifest=manifest,summary=summary,resource_consumers=dict(consumers),raw_sha256=raw.hexdigest(),command_sha256=commands.hexdigest())

def main():
    old=audit('integrations/lightweight/output/local_return_30d_v2.jsonl')
    new=audit('integrations/lightweight/output/shared_access_30d.jsonl')
    assert new['manifest']['resource_access']=='shared-all-agents-v1'
    assert {k:v for k,v in new['manifest'].items() if k!='resource_access'}==old['manifest']
    report=dict(baseline=old,current=new,commands_identical=old['command_sha256']==new['command_sha256'])
    Path('tests/fixtures/lightweight_shared_access_30d.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(dict(consumers=new['resource_consumers'],commands_identical=report['commands_identical'],agents=new['summary']['agents']),indent=2))
if __name__=='__main__':main()
