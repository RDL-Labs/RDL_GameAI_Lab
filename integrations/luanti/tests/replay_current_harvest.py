"""Replay actual accepted packets with explicit current-availability recording."""
import argparse
from collections import Counter
import hashlib
import json
import lzma
from pathlib import Path
from runtime.landmark_return_campaign import ReturnCampaign


def replay(path):
    with lzma.open(path,'rt',encoding='utf8') as f: report=json.load(f)
    run=report['runs'][0];world=run['data']['world'];old=run['data']['runtime']['exploration']
    loop=ReturnCampaign(world['run_id'],old['periods'],mb_field_mode=old['mb_field_mode'],harvest_state=True)
    for entry in world['deliveries']:
        assert getattr(loop,entry['kind'])(entry['request']) == json.loads(entry['response_wire'])
    agents={}
    for aid,agent in loop.agents.items():
        baseline=old['agents'][aid]
        assert agent.learning==baseline['learning']
        assert (agent.model.to_json() if agent.model else None)==baseline['active_model']
        counts=Counter();after_success=[]
        for ident,decision in agent.decisions.items():
            original=dict(decision);state=original.pop('current_harvest')
            assert original==baseline['decisions'][ident]
            counts[state['status']]+=1
            if state['status']=='none_observed' and state['historical_success']['count']:
                assert decision['action'][0]!='pickup'
                if not after_success:after_success.append(state)
        agents[aid]=dict(states=dict(counts),first_absence_after_success=after_success,
                        historical_successes=sum(x['acquired'] for x in agent.learning['records']),
                        model_invalidated=agent.learning['invalidated'])
    return dict(schema='l15a-current-harvest-replay-v1',source=str(path),
        source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        implementation_sha256={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in
            map(Path,['runtime/current_harvest_state.py','runtime/landmark_return_campaign.py'])},
        validation='all saved HTTP responses and prior decisions unchanged; learning and models unchanged',
        limitation='offline replay of actual World records; no new Luanti execution; original timing failures remain',
        responses=len(world['deliveries']),agents=agents)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('source',type=Path);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();result=replay(args.source)
    args.output.write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps(result))
