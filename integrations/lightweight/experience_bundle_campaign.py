"""Matched shadow/enabled retrospective conjunction experiment."""
import json
from pathlib import Path
from collections import Counter
from .timed_harvest import run
from .integrated_social_campaign import OPTIONS,audit,compact_report


def main():
    root=Path('outputs/experience_bundle');root.mkdir(parents=True,exist_ok=True);reports={}
    for mode in ('shadow','enabled'):
        options=dict(OPTIONS,seed=20261005,body_scene='social_shared',personal_food=True,
            hunger_enabled=True,body_method_field=True,food_retention=True,experience_bundle_mode=mode)
        path=root/(mode+'.jsonl');summary=run(path,**options)
        entry=compact_report({mode:dict(options=options,audit=audit(path))})[mode]
        entry['bundles']={a:s['experience_bundles'] for a,s in summary['agents'].items()}
        counts=Counter()
        for line in path.open(encoding='utf8'):
            row=json.loads(line)
            if row['type']!='decision':continue
            cs=row.get('continuous_selection') or {};trace=cs.get('experience_bundle') or {}
            if trace.get('contributions'):counts['matched']+=1
            if trace.get('changed'):
                counts['changed']+=1
                chosen=next(c for c in cs['candidates'] if c['model']==cs['selected'])
                counts['final_matches']+=int(row['command']['kind']==chosen['action'][0] and row['command']['amount']==chosen['action'][1])
        entry['reactivation']=dict(counts);reports[mode]=entry
        (root/'report.json').write_text(json.dumps(reports,indent=2)+'\n',encoding='utf8')
        print(mode,json.dumps(dict(summary=entry['audit']['summary'],counts=counts,
            bundles={a:len(s['bundles']) for a,s in entry['bundles'].items()})),flush=True)
    return reports


if __name__=='__main__':main()
