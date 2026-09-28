"""Audit current harvest states recorded during an actual World run, including a preserved interruption."""
import argparse
from collections import Counter
import hashlib
import json
import lzma
from pathlib import Path
from runtime.current_harvest_state import assess


def analyze(path, replay=False):
    with lzma.open(path,'rt',encoding='utf8') as f: report=json.load(f)
    run=report['runs'][0];w=run['data']['world'];s=run['data']['runtime']['exploration']
    assert s['harvest_state'] is True
    assert run['summary'] is not None
    if replay:
        from runtime.landmark_return_campaign import ReturnCampaign
        loop=ReturnCampaign(w['run_id'],s['periods'],mb_field_mode=s['mb_field_mode'],harvest_state=True,agent_count=s.get("agent_count",3))
        for entry in w['deliveries']:
            assert getattr(loop,entry['kind'])(entry['request'])==json.loads(entry['response_wire'])
        assert loop.snapshot()==s
    from .check_return_campaign import trips
    assert trips(w)==(w['return_campaign']['events'] or [])
    agents={}
    for aid,a in s['agents'].items():
        counts=Counter();first=None
        for ident,d in a['decisions'].items():
            p=a['observations'][ident]
            records=[r for r in a['learning']['records'] if r['later_us']<=p['capture_us']]
            expected=assess(p,a['teaching']['appearance'],records)
            assert expected==d['current_harvest'],ident
            counts[expected['status']]+=1
            if expected['status']=='none_observed':
                assert d['action'][0]!='pickup',ident
                if first is None and expected['historical_success']['count']:
                    first=dict(state=expected,action=d['action'],reason=d['reason'])
        agents[aid]=dict(observations=len(a['observations']),states=dict(counts),
            historical_successes=sum(r['acquired'] for r in a['learning']['records']),
            adopted_model=a['active_model'] is not None,invalidated=a['learning']['invalidated'],
            first_absence_after_success=first,
            field_applications=sum(bool(d['mb_field']['field'] and d['mb_field']['field']['applied']) for d in a['decisions'].values()),
            pickups_by_day=dict(Counter(e['executed_us']//64000000+1 for e in (w['stock_events'] or []) if e['agent_id']==aid)))
    return dict(schema='l15a-current-harvest-world-audit-v1',run_id=w['run_id'],source=str(path),
        source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        replay_verified=replay, world_failure=w.get('failure'),timing=w.get('timing'),
        pickups=len(w.get('stock_events') or []),returns=len(w['return_campaign']['events'] or []),
        responses=len(w['deliveries']),observations=sum(len(a['observations']) for a in s['agents'].values()),
        transport_faults=dict(Counter(x['result']['status'] for a in w['agents'].values() for x in a['actions'] if x['result']['status'] in ('expired','stale','stopped'))),
        source_matches={k:hashlib.sha256(Path(k).read_bytes()).hexdigest()==v for k,v in report['source_sha256'].items()},
        predeclared=report['predeclared'],
        summary={k:v for k,v in run['summary'].items() if k not in ('days','agents')},
        validation='each state recomputed from its observation and earlier own records; no absent-state pickup command',
        agents=agents)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--replay',action='store_true')
    args=p.parse_args();out=analyze(args.source,args.replay)
    args.output.write_text(json.dumps(out,indent=2),encoding='utf8');print(json.dumps(out))
