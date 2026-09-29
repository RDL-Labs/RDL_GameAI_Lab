"""Audit completed nested-local-model run and historical same-condition control."""
import json
from collections import Counter,defaultdict
from pathlib import Path
from .audit_threshold_sweep import audit

def summarize(path):
 r=audit(path);days=defaultdict(lambda:defaultdict(lambda:dict(moved=0,selected=0)))
 stats={a:Counter() for a in r['agents']};final={}
 for line in Path(path).open(encoding='utf8'):
  x=json.loads(line)
  if x['type']=='completed':
   aid=x['command']['agent_id'];day=x['command']['capture_us']//64000000+1
   days[str(day)][aid]['moved']+=x['result']['forward']
  if x['type']!='decision':continue
  a=x['command']['agent_id'];day=str(x['packet']['capture_us']//64000000+1)
  m=x.get('nested_models')
  if not m:continue
  assert len(m['events'])<=32 and all(0<=n['H']<=32 for n in m['nodes'].values())
  final[a]=m
  if m['selection']['applied']:
   stats[a]['selected']+=1;days[day][a]['selected']+=1
   stats[a][m['active_model']]+=1
   assert x['activity_phase'] in ('return','exploration')
   key='reposition' if x['activity_phase']=='exploration' else 'return_reposition'
   assert x[key]['operations']<=16
   angle=0 if x['command']['kind']=='move' else x['command']['amount']
   assert angle in x[key]['eligible']
 r.update(days=dict(days),selections={a:dict(c) for a,c in stats.items()},final_models=final)
 return r

def main():
 old=summarize('integrations/lightweight/output/shared_access_30d.jsonl')
 new=summarize('integrations/lightweight/output/nested_models_30d_final.jsonl')
 assert {k:v for k,v in new['manifest'].items() if k!='nested_model_mode'}==old['manifest']
 Path('tests/fixtures/lightweight_nested_models_30d.json').write_text(json.dumps(dict(runs=[old,new]),indent=2),encoding='utf8')
 print(json.dumps(dict(agents=new['agents'],selections=new['selections'],late_C={k:v.get('npc_c') for k,v in new['days'].items() if int(k)>=12}),indent=2))
if __name__=='__main__':main()
