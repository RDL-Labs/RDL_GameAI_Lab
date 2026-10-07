"""Completed-Sleep organization of the existing experience-bundle campaign."""
import json
from pathlib import Path
from collections import Counter
from .timed_harvest import run
from .integrated_social_campaign import OPTIONS, audit, compact_report


def main(replay=False):
    root=Path('outputs/bundle_sleep');root.mkdir(parents=True,exist_ok=True)
    options=dict(OPTIONS,seed=20261005,body_scene='social_shared',personal_food=True,
        hunger_enabled=True,body_method_field=True,food_retention=True,
        experience_bundle_mode='enabled',bundle_sleep_enabled=True)
    path=root/'enabled.jsonl'
    if not replay:run(path,**options)
    checked=audit(path);summary=checked['summary']
    report=compact_report({'enabled':dict(options=options,audit=checked)})['enabled']
    report['bundles']={};counts=Counter()
    for aid,value in summary['agents'].items():
        state=value['experience_bundles'];all_bundles=state['bundles']+state['dormant']
        refs=[b['model_ref'] for b in all_bundles]
        sources=[s['operation'] for b in all_bundles for s in b['sources']]
        assert len(refs)==len(set(refs)) and len(sources)==len(set(sources))
        assert len(state['bundles'])<=32 and len(all_bundles)<=256
        report['bundles'][aid]=dict(active=len(state['bundles']),dormant=len(state['dormant']),
            total=len(all_bundles),reviews=state['sleep_reviews'],
            last_formed_us=max((b['formed_us'] for b in all_bundles),default=None))
    for line in path.open(encoding='utf8'):
        row=json.loads(line)
        if row['type']!='decision':continue
        counts['woken']+=len((row.get('bundle_sleep') or {}).get('woken',[]))
        trace=(row.get('continuous_selection') or {}).get('experience_bundle') or {}
        counts['changed']+=bool(trace.get('changed'))
    report['counts']=dict(counts)
    (root/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(summary=report['audit']['summary'],counts=counts,
        bundles={a:{k:v for k,v in b.items() if k!='reviews'} for a,b in report['bundles'].items()})),flush=True)
    return report


if __name__=='__main__':main()

