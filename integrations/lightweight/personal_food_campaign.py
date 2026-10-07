"""Thirty-day personal provisions run using the existing integration options."""
from collections import Counter
import json
from pathlib import Path
from .timed_harvest import run
from .integrated_social_campaign import OPTIONS, audit, compact_report


def main(hunger=False):
    root=Path('outputs/hunger' if hunger else 'outputs/personal_food');root.mkdir(parents=True,exist_ok=True)
    path=root/'personal.jsonl'
    options=dict(OPTIONS,body_scene='social_shared',personal_food=True,hunger_enabled=hunger)
    run(path,**options)
    result=compact_report(dict(personal=dict(options=options,audit=audit(path))))
    rests=Counter();bands=Counter();resumed=set();rested=set()
    with path.open(encoding='utf8') as source:
        for line in source:
            r=json.loads(line)
            if r['type']!='decision':continue
            aid=r['packet']['agent_id'];band=r['packet']['social']['food_band'];bands[band]+=1
            if r['command']['reason']=='personal_food_sufficient':
                rests[aid]+=1;rested.add(aid)
            elif aid in rested and band in ('none','low') and r['command']['kind'] in ('move','pickup'):
                resumed.add(aid)
    result['personal']['provision_review']=dict(rests=dict(rests),bands=dict(bands),
        resumed_after_low=sorted(resumed))
    (root/'report.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(summary=result['personal']['audit']['summary'],
        actions=result['personal']['audit']['actions'],provision_review=result['personal']['provision_review'])),flush=True)
    return result


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--hunger',action='store_true')
    main(parser.parse_args().hunger)
