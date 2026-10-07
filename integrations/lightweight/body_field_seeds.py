"""Fixed three additional seeds; same 30-day social initial placement."""
from collections import Counter
import json
from pathlib import Path
from .timed_harvest import run
from .integrated_social_campaign import OPTIONS, audit, compact_report


def main():
    root=Path('outputs/body_field_seeds');root.mkdir(parents=True,exist_ok=True)
    report={}
    for seed in (20261005,20261006,20261007):
        path=root/f'{seed}.jsonl'
        options=dict(OPTIONS,seed=seed,body_scene='social_shared',personal_food=True,
                     hunger_enabled=True,body_method_field=True)
        run(path,**options)
        result=compact_report({str(seed):dict(options=options,audit=audit(path))})[str(seed)]
        agents={a:dict(last_day=Counter(),first_zero_us=None,zero_captures=0,rest=0) for a in ('npc_a','npc_b','npc_c')}
        with path.open(encoding='utf8') as source:
            for line in source:
                r=json.loads(line)
                if r['type'] in ('decision','working_capture'):
                    p=r['packet'];a=agents[p['agent_id']]
                    if p['locomotor']['state']['reserve']==0:
                        a['zero_captures']+=1
                        if a['first_zero_us'] is None:a['first_zero_us']=p['capture_us']
                    if r['type']=='decision' and r['command']['reason']=='personal_food_sufficient':a['rest']+=1
                elif r['type']=='completed' and r['command']['capture_us']>=29*64_000_000:
                    agents[r['command']['agent_id']]['last_day'][r['result']['status']]+=1
        result['individual_observation']=agents;report[str(seed)]=result
        (root/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
        print(json.dumps(dict(seed=seed,summary=result['audit']['summary'],
            actions=result['audit']['actions'],individual=agents)),flush=True)
    return report


if __name__=='__main__':main()
