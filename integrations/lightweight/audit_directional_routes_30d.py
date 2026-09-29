"""Thirty-day paired continuation; compare early/late outcomes without tuning."""
import hashlib,json
from pathlib import Path

ROOT=Path('integrations/lightweight/output')

def audit(path):
    h=hashlib.sha256();prefix=hashlib.sha256();summary=None;daily={};final={};receipts=set();reason_counts={}
    for line in path.open('rb'):
        h.update(line);r=json.loads(line)
        if r['type']=='manifest':manifest=r
        if r['type']=='summary':summary=r
        if r['type']=='unload_receipt':receipts.add(r['receipt']['operation_id'])
        if r['type'] not in ('decision','completed'):continue
        p=r['packet'];aid=p['agent_id'];day=p['capture_us']//64000000+1
        a=daily.setdefault(str(day),{}).setdefault(aid,dict(pickups=0,delivered=0,movement=0,turns=0,waits=0,route_food=0,route_home=0,reverse_food=0,reverse_home=0,tower_priority=0,reinforcements=0,route_count=0,max_support=0))
        if r['type']=='completed':
            result=r['result'];a['pickups']+=int(result['acquired']);a['movement']+=result['forward']
            a['turns']+=int(result['status']=='turned');a['waits']+=int(result['status']=='waited')
            continue
        reasons=reason_counts.setdefault((str(day),aid),{})
        reason=r['command']['kind']+':'+r['command']['reason'];reasons[reason]=reasons.get(reason,0)+1
        if day<=5:prefix.update(json.dumps(r['command'],sort_keys=True,separators=(',',':')).encode())
        s=r.get('directional_routes')
        if not s:continue
        assert len(s['routes'])<=16 and s['operations']<=48
        for node in s['routes'].values():
            assert 0<=node['support']<=8 and 0<=node['H']<=32 and len(node['points'])<=8
            assert set(node['receipts'])<=receipts and set(node['proposals'])<=receipts
        if s['applied']:
            node=s['routes'][s['active']];a['route_'+node['goal']]+=1
            a['reverse_'+node['goal']]+=int(node['support']==0)
            assert r['command']['reason']=='directional_route'
        a['tower_priority']+=int(s['reason']=='current_goal_priority' and r['activity_phase']=='return')
        a['reinforcements']+=sum(not x['reverse_proposal'] for x in s['admissions'])
        a['route_count']=len(s['routes']);a['max_support']=max((n['support'] for n in s['routes'].values()),default=0)
        final[aid]=s['routes']
    assert summary and summary['reason']=='time_limit' and summary['ended_us']==manifest['days']*64000000
    assert manifest['stock_mode']=='inexhaustible' and all(v==12 for v in summary['stock'])
    for ret in summary['returns']:daily[str(ret['day'])][ret['agent_id']]['delivered']+=len(ret['pickups'])
    blocks=[]
    for start,end in [(1,5),(6,10),(11,20),(21,30)]:
        if start>manifest['days']:continue
        totals={}
        for day in range(start,min(end,manifest['days'])+1):
            for aid,a in daily[str(day)].items():
                out=totals.setdefault(aid,{})
                for k,v in a.items():
                    if k in ('route_count','max_support'):out[k]=v
                    else:out[k]=out.get(k,0)+v
        blocks.append(dict(start=start,end=min(end,manifest['days']),agents=totals))
    stopped=[dict(day=int(day),agent=aid,reasons=reason_counts.get((day,aid),{})) for day,aa in daily.items() for aid,a in aa.items() if a['movement']==0]
    return dict(zero_translation_days=stopped,manifest=manifest,summary=summary,sha256=h.hexdigest(),first5_commands_sha256=prefix.hexdigest(),daily=daily,blocks=blocks,final_routes=final)

if __name__=='__main__':
    reports=[]
    for mode in ('disabled','enabled'):
        r=audit(ROOT/f'directional_{mode}_30d.jsonl')
        old=audit(ROOT/f'directional_natural_{mode}.jsonl')
        assert r['first5_commands_sha256']==old['first5_commands_sha256']
        reports.append(r)
        print(mode,'total',r['summary']['pickups'],'delivered',sum(len(x['pickups']) for x in r['summary']['returns']),flush=True)
        for b in r['blocks']:print(b,flush=True)
    assert {k:v for k,v in reports[0]['manifest'].items() if k!='directional_route_mode'}=={k:v for k,v in reports[1]['manifest'].items() if k!='directional_route_mode'}
    Path('tests/fixtures/lightweight_directional_routes_30d.json').write_text(json.dumps(dict(runs=reports),indent=2),encoding='utf8')
