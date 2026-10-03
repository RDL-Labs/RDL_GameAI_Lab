"""Compare continuing selection with the legacy quotas under identical Worlds."""
import argparse
import json
from collections import Counter
from pathlib import Path
from .timed_harvest import run
from .finite_territory_comparison import stock_audit
from .audit_moving_hazard import ROOT


def main(execute=False):
    reports={}
    for hazard in ('disabled','enabled'):
        for selection in ('legacy','continuous'):
            key=hazard+'_'+selection;path=ROOT/f'continuous_selection_{key}.jsonl'
            if execute:
                run(path,days=5,skyline_subrays=True,inexhaustible=False,stop_after_returns=None,
                    mb_field_mode='enabled',goal_difference_mode='enabled',food_goal_mode='enabled',seed=20261001,
                    lateral_side='left',orientation_mode='enabled',reposition_mode='enabled',return_completion_mode='enabled',
                    nested_model_mode='enabled',directional_route_mode='enabled',relation_field_mode='enabled',
                    hazard_mode=hazard,hazard_scenario='territorial',warning_review_mode='enabled',
                    territory_resource_layout='three_inside',selection_mode=selection)
            r,_=stock_audit(path);counts=Counter();phases=Counter();methods=Counter();max_ops=0;over=Counter();final={}
            for line in path.open(encoding='utf8'):
                x=json.loads(line)
                if x['type']!='decision':continue
                s=x.get('continuous_selection');safety=x.get('safety') or {}
                max_ops=max(max_ops,safety.get('operations',0))
                if selection=='legacy':continue
                assert s and s['candidates'] and s['selected'] in {c['model'] for c in s['candidates']}
                assert len(s['candidates'])<=9 and len(s['nodes'])<=64 and len(s['events'])<=32
                assert x['command']['kind'] in ('wait','turn','move','pickup')
                counts[x['command']['kind']]+=1;phases[x['activity_phase']]+=1;methods[s['selected']]+=1
                counts['H_threshold_nodes']+=sum(n['H']>=n['threshold'] for n in s['nodes'].values())
                if safety.get('override') and safety.get('operations',0)>32:over[x['command']['kind']]+=1
                final[x['packet']['agent_id']]=dict(source=x['packet']['observation_id'],selected=s['selected'],action=x['command']['kind'],phase=x['activity_phase'])
                if s['applied']:assert x['command']['reason'].startswith('continuous_')
                if x['activity_phase']=='safety':assert x['command']['kind']!='pickup'
            r['selection_audit']=dict(counts=dict(counts),phases=dict(phases),methods=dict(methods),max_safety_operations=max_ops,
                actions_after_old_safety_limit=dict(over),final=final)
            reports[key]=r
            print(key,r['summary']['pickups'],{a:(v['unloaded'],v['carried']) for a,v in r['summary']['agents'].items()},r['final_modes'],max_ops,flush=True)
    Path('tests/fixtures/lightweight_continuous_selection.json').write_text(json.dumps(reports,indent=2),encoding='utf8')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',action='store_true');main(p.parse_args().run)
