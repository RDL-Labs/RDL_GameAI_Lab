"""Audit the 30-day relational field against the saved directional baseline."""
import hashlib,json
from pathlib import Path
from collections import Counter


def audit():
 path=Path('integrations/lightweight/output/relation_field_30d.jsonl');h=hashlib.sha256();daily={};fields=Counter();max_pairs=0;summary=None
 for line in path.open('rb'):
  h.update(line);r=json.loads(line)
  if r['type']=='manifest':manifest=r
  if r['type']=='summary':summary=r
  if r['type'] not in ('decision','completed'):continue
  p=r['packet'];day=str(p['capture_us']//64000000+1);aid=p['agent_id']
  a=daily.setdefault(day,{}).setdefault(aid,dict(movement=0,turns=0,pickups=0,delivered=0,field_operations=0,relational_operations=0))
  if r['type']=='completed':
   result=r['result'];a['movement']+=result['forward'];a['turns']+=int(result['status']=='turned');a['pickups']+=int(result['acquired']);continue
  f=r.get('relation_field')
  if not f:continue
  fields[f['reason']]+=1
  assert f['operations']<=48
  if f['applied']:
   assert r['command']['reason']=='relation_field' and r['activity_phase'] in ('exploration','return')
   a['field_operations']+=1;trace=f['field'];assert trace['source']==p['observation_id'] and trace['pose_ref']==p['pose_ref']
   rows=[x for x in trace['samples'] if x['status']=='scored'];chosen=0 if r['command']['kind']=='move' else r['command']['amount']
   assert any(x['direction']==chosen for x in rows)
   ground=next(x for x in p['movement_surface']['ground']['samples'] if x['direction_deg']==chosen)
   assert ground['status']=='sampled' and abs(ground['height_delta'])<=.5
   for x in rows:assert abs(x['total']-(x['base']+x['relation']+x['goal']))<1e-9
   if trace['relation']['status']=='comparable':
    assert len(trace['relation']['current'])>=2
    a['relational_operations']+=1;max_pairs=max(max_pairs,len(trace['relation']['pairs']))
 assert summary and summary['ended_us']==1920000000 and summary['reason']=='time_limit'
 assert manifest['stock_mode']=='inexhaustible' and all(x==12 for x in summary['stock'])
 for ret in summary['returns']:daily[str(ret['day'])][ret['agent_id']]['delivered']+=len(ret['pickups'])
 totals={}
 for aid in summary['agents']:
  totals[aid]={k:sum(aa[aid][k] for aa in daily.values()) for k in daily['1'][aid]}
  totals[aid]['zero_translation_days']=[int(day) for day,aa in daily.items() if aa[aid]['movement']==0]
 baseline=json.loads(Path('tests/fixtures/lightweight_directional_routes_30d.json').read_text())['runs'][1]
 assert {k:v for k,v in manifest.items() if k!='relation_field_mode'}==baseline['manifest']
 out=dict(manifest=manifest,summary=summary,sha256=h.hexdigest(),daily=daily,totals=totals,field_reasons=dict(fields),max_pairs=max_pairs,baseline_sha256=baseline['sha256'])
 Path('tests/fixtures/lightweight_relation_field_30d.json').write_text(json.dumps(out,indent=2),encoding='utf8')
 print(json.dumps(dict(totals=totals,reasons=dict(fields),max_pairs=max_pairs)),flush=True)

if __name__=='__main__':audit()
