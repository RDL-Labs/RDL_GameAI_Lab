"""Directional route comparison, raw logs and compact provenance audit."""
import json,hashlib
from pathlib import Path
from unittest.mock import patch
from .compare_food_revisit import simple_world
from .timed_harvest import run

CASES=[('natural_disabled','disabled',False),('natural_enabled','enabled',False),('simple_enabled','enabled',True)]

def execute():
 for name,mode,simple in CASES:
  kwargs=dict(days=5,seed=20261001,inexhaustible=True,skyline_subrays=True,stop_after_returns=None,orientation_mode='enabled',return_completion_mode='enabled',reposition_mode='enabled',nested_model_mode='enabled',goal_difference_mode='enabled',food_goal_mode='enabled',lateral_side='left',directional_route_mode=mode)
  path=f'integrations/lightweight/output/directional_{name}.jsonl'
  if simple:
   with patch('integrations.lightweight.timed_harvest.World',simple_world):s=run(path,**kwargs)
  else:s=run(path,**kwargs)
  print(name,s['pickups'],flush=True)

def audit():
 reports=[]
 for name,mode,simple in CASES:
  path=Path(f'integrations/lightweight/output/directional_{name}.jsonl');h=hashlib.sha256();summary=None;agents={};receipts=set()
  for line in path.open('rb'):
   h.update(line);r=json.loads(line)
   if r['type']=='manifest':manifest=r
   if r['type']=='summary':summary=r
   if r['type']=='unload_receipt':receipts.add(r['receipt']['operation_id'])
   if r['type']!='decision' or not r.get('directional_routes'):continue
   s=r['directional_routes'];a=agents.setdefault(r['packet']['agent_id'],dict(food=0,home=0,reverse=0,reverse_food=0,reverse_home=0,tower_priority=0,reinforcements=0))
   assert len(s['routes'])<=16 and s['operations']<=48
   for n in s['routes'].values():
    assert len(n['points'])<=8 and 0<=n['support']<=8
    assert set(n['receipts'])<=receipts and set(n['proposals'])<=receipts
   if s['applied']:
    n=s['routes'][s['active']];a[n['goal']]+=1;a['reverse']+=int(n['support']==0);a['reverse_'+n['goal']]+=int(n['support']==0)
    assert r['command']['reason']=='directional_route'
   a['tower_priority']+=int(s['reason']=='current_goal_priority' and r['activity_phase']=='return')
   a['reinforcements']+=sum(not x['reverse_proposal'] for x in s['admissions'])
   a['final_routes']=s['routes']
  assert summary and summary['ended_us']==320000000 and summary['reason']=='time_limit'
  assert all(x==12 for x in summary['stock'])
  reports.append(dict(case=name,manifest=manifest,summary=summary,agents=agents,sha256=h.hexdigest()))
  print(name,'picked',summary['pickups'],'delivered',sum(len(x['pickups']) for x in summary['returns']),{k:{x:v for x,v in a.items() if x!='final_routes'} for k,a in agents.items()})
 assert {k:v for k,v in reports[0]['manifest'].items() if k!='directional_route_mode'}=={k:v for k,v in reports[1]['manifest'].items() if k!='directional_route_mode'}
 Path('tests/fixtures/lightweight_directional_routes.json').write_text(json.dumps(dict(runs=reports),indent=2),encoding='utf8')

if __name__=='__main__':
 import sys
 if '--run' in sys.argv:execute()
 audit()
