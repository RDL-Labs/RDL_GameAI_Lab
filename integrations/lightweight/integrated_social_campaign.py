"""Thirty-day integration of connected lightweight subsystems; streaming audit."""
import json
from collections import Counter
from pathlib import Path
from .timed_harvest import run

OPTIONS = dict(days=30, stop_after_returns=None, seed=20261004,
    skyline_subrays=True, mb_field_mode='enabled', goal_difference_mode='enabled',
    food_goal_mode='enabled', orientation_mode='enabled', reposition_mode='enabled',
    return_completion_mode='enabled', nested_model_mode='enabled', food_revisit_mode='enabled',
    directional_route_mode='enabled', relation_field_mode='enabled', hazard_mode='enabled',
    hazard_scenario='territorial', warning_review_mode='enabled', selection_mode='continuous',
    dynamic_hazard=True, regrowth_days=3, sleep_learning=True, sleep_auto_adopt=True,
    body_mode='enabled', energy_mode='enabled', social_mode='enabled', social_adopt=True,
    social_pressure=True, refusal_field_mode='enabled')


def audit(path, days=30, duration_us=None):
    actions=Counter(); commands=Counter(); choices=Counter(); clocks={}; operations=set()
    added=0; initial=None; completed=0; hazard_observations=0
    daily={}; safety=Counter(); visible_hazards=0
    with Path(path).open(encoding='utf8') as source:
        for line in source:
            r=json.loads(line)
            if r['type']=='manifest':
                assert r['days']==days, 'campaign_days'
                day_us=r.get('time_profile',{}).get('day_us',64_000_000)
                log_mode=r.get('log_mode','full')
                initial=r.get('initial_shared_stock',0)+sum(a['inventory'] for a in r['agents'].values())+sum(x['stock'] for x in r['resources'])
            elif r['type']=='resource_regrowth':added+=sum(r['added'])
            elif r['type']=='completed':
                c=r['command']; result=r['result']; op=c['operation_id']; aid=c['agent_id']
                assert op not in operations, 'duplicate_body_effect'
                assert c['capture_us']>=clocks.get(aid,0), 'overlapping_body_effect'
                operations.add(op);clocks[aid]=result['executed_us'];completed+=1
                ledger=r['food_ledger']
                assert sum(ledger['carried'].values())+ledger['ground']+ledger['shared']+ledger['consumed']==initial+added, 'food_conservation'
                commands[c['kind']]+=1
                day=str(c['capture_us']//day_us+1)
                counts=daily.setdefault(day,Counter());counts[c['kind']]+=1
                counts['picked_up']+=int(result['status']=='picked_up')
            elif r['type']=='social_effect':actions[r['intent']['action']+':'+r['result']['status']]+=1
            elif r['type']=='decision':
                if r.get('safety'):
                    hazard_observations+=1;safety[r['safety'].get('reason','unspecified')]+=1
                visible_hazards+=bool(r['packet'].get('hazard',{}).get('features'))
                choice=r.get('refusal_choice')
                if choice and choice['weight']>0:choices[choice['question']]+=1
            elif r['type']=='summary':summary=r
    assert summary['ended_us']==(duration_us or days*day_us) and summary['reason']==('window_limit' if duration_us and duration_us<days*day_us else 'time_limit')
    return dict(completed=completed,food_conserved=True,no_duplicate_or_overlapping_effects=True,
        initial_food=initial,regrown_food=added,actions=dict(actions),commands=dict(commands),
        decision_diagnostics_available=log_mode=='full',
        positive_refusal_choices=dict(choices) if log_mode=='full' else None,safety_decisions=hazard_observations if log_mode=='full' else None,
        visible_hazard_decisions=visible_hazards if log_mode=='full' else None,safety_reasons=dict(safety) if log_mode=='full' else None,daily=daily,
        summary=summary)


def compact_report(reports):
    result={}
    for name,r in reports.items():
        a=r['audit'];s=a['summary']
        compact={k:v for k,v in a.items() if k!='summary'}
        compact['summary']={k:s[k] for k in ('ended_us','pickups','social_stock','social_consumed',
            'physical_inventory','layered_bodies','elapsed_seconds')}
        compact['learning']={}
        for aid,v in s['agents'].items():
            social=v['social_relations'] or {};auto=v['sleep_auto_model'] or {}
            compact['learning'][aid]=dict(sleep_statuses=dict(Counter(c['status'] for c in
                v['sleep']['completed']+[v['sleep']['cycle']] if c)),harvest_model=v['model_ref'],
                social_records=len(social.get('records',{})),social_model=social.get('model'),
                sleep_model=auto.get('model_ref'),sleep_records=len(auto.get('records',[])))
        result[name]=dict(options=r['options'],audit=compact)
    return result


def main():
    root=Path('outputs/integrated_social_campaign');root.mkdir(parents=True,exist_ok=True)
    reports={}
    for scene in ('natural','social_shared'):
        options=dict(OPTIONS,body_scene=scene)
        path=root/(scene+'.jsonl')
        run(path,**options)
        reports[scene]=dict(options=options,audit=audit(path))
        (root/'report.json').write_text(json.dumps(reports,indent=2)+'\n',encoding='utf8')
        (root/'compact.json').write_text(json.dumps(compact_report(reports),indent=2)+'\n',encoding='utf8')
        print(scene,json.dumps({k:v for k,v in reports[scene]['audit'].items() if k!='summary'}),flush=True)
    return reports


if __name__=='__main__':main()
