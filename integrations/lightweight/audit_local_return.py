"""Audit local return completion and retained-purpose recovery trials."""
import json
from collections import Counter
from pathlib import Path
from .audit_threshold_sweep import audit

def summarize(path):
 r=audit(path);reasons={a:Counter() for a in r['agents']};extra={a:Counter() for a in r['agents']};last={}
 for line in Path(path).open(encoding='utf8'):
  x=json.loads(line)
  if x['type']=='decision':
   a=x['command']['agent_id'];reasons[a][x['command']['reason']]+=1
   t=x.get('return_reposition')
   if t:
    extra[a][t['reason']]+=1;assert t['operations']<=16
    if t['applied']:
     assert x['activity_phase']=='return'
     angle=0 if x['command']['kind']=='move' else x['command']['amount']
     assert angle in t['eligible']
  elif x['type']=='completed':last[x['command']['agent_id']]=x['body']
 r.update(reasons={a:dict(c) for a,c in reasons.items()},recovery={a:dict(c) for a,c in extra.items()},final_bodies=last)
 return r

def main():
 names=('reposition_30d_enabled','local_return_30d','local_return_30d_v2')
 runs=[summarize('integrations/lightweight/output/'+n+'.jsonl') for n in names]
 base={k:v for k,v in runs[0]['manifest'].items() if k!='return_completion_mode'}
 assert all({k:v for k,v in r['manifest'].items() if k!='return_completion_mode'}==base for r in runs)
 Path('tests/fixtures/lightweight_local_return_comparison.json').write_text(json.dumps(dict(runs=runs,labels=['previous control','initial implementation with integration defects','corrected implementation']),indent=2),encoding='utf8')
 for name,r in zip(names,runs):print(name,json.dumps(r['agents']),json.dumps(r['recovery']),flush=True)
if __name__=='__main__':main()
