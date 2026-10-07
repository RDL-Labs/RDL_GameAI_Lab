"""Thirty-day trail-use and whole-parent-success experiment."""
import json
from pathlib import Path
from collections import Counter
from .timed_harvest import run
from .integrated_social_campaign import OPTIONS,audit,compact_report

def main():
 root=Path('outputs/ground_pattern');root.mkdir(parents=True,exist_ok=True)
 options=dict(OPTIONS,seed=20261005,body_scene='social_shared',personal_food=True,hunger_enabled=True,body_method_field=True,food_retention=True,experience_bundle_mode='enabled',bundle_sleep_enabled=True,trail_enabled=True,ground_wear_enabled=True,ground_recovery_enabled=True,ground_appearance_enabled=True,ground_pattern_enabled=True)
 path=root/'enabled.jsonl';run(path,**options);checked=audit(path)
 report=compact_report({'enabled':dict(options=options,audit=checked)})['enabled']
 report['ground_wear']=checked['summary']['ground_wear']
 report['trails']={a:v['selection_trail'] for a,v in checked['summary']['agents'].items()}
 counts=Counter()
 for line in path.open(encoding='utf8'):
  r=json.loads(line)
  if r['type']=='decision':
   t=(r.get('continuous_selection') or {}).get('selection_trail') or {}
   for g in (r.get('ground_patterns') or {}).get('groups',[]):counts[g['shape']]+=1
   counts['changed']+=bool(t.get('changed'));counts['contributed']+=any(c['delta']>0 for c in t.get('contributions',[]))
 report['counts']=dict(counts)
 (root/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
 from .render_ground_wear import render
 render(root/'report.json',root/'map.svg')
 print('Ground map: '+str((root/'map.html').resolve()),flush=True)
 print(json.dumps(dict(summary=report['audit']['summary'],counts=counts,trails={a:dict(edges=len(s['edges']),uses=sum(e['uses'] for e in s['edges'].values()),successes=len(s['completed']),pending=bool(s['episode'])) for a,s in report['trails'].items()})),flush=True)
if __name__=='__main__':main()
