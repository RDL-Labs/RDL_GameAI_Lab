import json
from itertools import zip_longest
from collections import Counter
from pathlib import Path
from integrations.lightweight.ground_appearance import validate
counts=Counter();observations=Counter();events=0

def rows(path,new=False):
 global events
 for line in open(path,encoding='utf8'):
  r=json.loads(line)
  if new and r['type'] in ('decision','working_capture'):
   p=r['packet'];v=p['ground_appearance'];validate(v,p);observations[p['agent_id']]+=1
   counts.update(c['appearance'] or 'occluded' for c in v['cells'])
  if r['type']=='decision':yield ('decision',r['command'])
  if r['type']=='completed':yield ('completed',r['command'],r['result'])
for a,b in zip_longest(rows('outputs/ground_recovery/enabled.jsonl'),rows('outputs/ground_appearance/enabled.jsonl',True)):
 assert a==b,'behavior_difference';events+=1
out=dict(observations=dict(observations),samples=dict(counts),identical_command_result_events=events)
Path('outputs/ground_appearance/observation_audit.json').write_text(json.dumps(out,indent=2)+'\n');print(out)
