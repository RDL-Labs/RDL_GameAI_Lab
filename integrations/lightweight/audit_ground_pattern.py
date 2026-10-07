import json
from pathlib import Path
from itertools import zip_longest
from collections import Counter
from runtime.ground_pattern import recognize

def rows(path,check=False):
 for line in Path(path).open(encoding='utf8'):
  r=json.loads(line)
  if r['type']=='decision':
   if check:
    assert r['ground_patterns']==recognize(r['packet'])
    for g in r['ground_patterns']['groups']:counts[g['appearance']+':'+g['shape']]+=1
   yield ('decision',r['command'])
  elif r['type']=='completed':yield ('completed',r['command'],r['result'])
counts=Counter();n=0
for a,b in zip_longest(rows('outputs/ground_appearance/enabled.jsonl'),rows('outputs/ground_pattern/enabled.jsonl',True)):
 assert a==b;n+=1
out=dict(identical_events=n,patterns=dict(counts));Path('outputs/ground_pattern/pattern_audit.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf8');print(out)
