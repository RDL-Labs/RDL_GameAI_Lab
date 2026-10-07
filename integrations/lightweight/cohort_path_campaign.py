"""30-day path formation, then fresh cohorts with/without inherited wear."""
import json
from pathlib import Path
from collections import Counter
from .timed_harvest import run
from .integrated_social_campaign import OPTIONS,audit,compact_report
from .render_ground_wear import render


def main():
    root=Path('outputs/cohort_paths');root.mkdir(parents=True,exist_ok=True)
    options=dict(OPTIONS,seed=20261005,body_scene='social_shared',personal_food=True,
        hunger_enabled=True,body_method_field=True,food_retention=True,
        experience_bundle_mode='enabled',bundle_sleep_enabled=True,trail_enabled=True,
        ground_wear_enabled=True,ground_recovery_enabled=True,
        ground_appearance_enabled=True,ground_pattern_enabled=True)
    reports={};state=None
    for name in ('formation','inherited','reset'):
        path=root/(name+'.jsonl')
        opts=dict(options,run_id='cohort-founders' if name=='formation' else 'cohort-newcomers')
        result=run(path,**opts,world_checkpoint=state if name!='formation' else None,
            reset_inherited_wear=name=='reset')
        checked=audit(path)
        report=compact_report({name:dict(options=opts,audit=checked)})[name]
        report['ground_wear']=result['ground_wear']
        counts=Counter();first={};initial={}
        for line in path.open(encoding='utf8'):
            r=json.loads(line)
            if r['type']=='decision':
                aid=r['packet']['agent_id']
                initial.setdefault(aid,dict(records=r['records'],model_ref=r['model_ref']))
                for g in (r.get('ground_patterns') or {}).get('groups',[]):counts[g['shape']]+=1
            if r['type']=='completed' and r['result']['status']=='picked_up':
                aid=r['command']['agent_id'];first.setdefault(aid,r['result']['executed_us']/64_000_000+1)
        assert all(x['records']==0 for x in initial.values()),'new_cohort_has_experience'
        report.update(first_pickup_day=first,initial_learning=initial,patterns=dict(counts))
        reports[name]=report
        target=root/(name+'.json');target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
        render(target,root/(name+'.svg'))
        if name=='formation':
            state=result['world_checkpoint']
            (root/'checkpoint.json').write_text(json.dumps(state,indent=2)+'\n',encoding='utf8')
        print(name,json.dumps(report['audit']['summary']),flush=True)
    (root/'report.json').write_text(json.dumps(reports,indent=2)+'\n',encoding='utf8')
    from .audit_cohort_paths import main as compare
    compare()

if __name__=='__main__':main()
