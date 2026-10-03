"""Separate resource placement from danger response with a finite 2x2 comparison."""
import argparse
import json
from pathlib import Path
from .timed_harvest import run
from .finite_territory_comparison import stock_audit
from .audit_moving_hazard import ROOT


def main(execute=False):
    results={}
    for layout in ('original','three_inside'):
        for mode in ('disabled','enabled'):
            key=layout+'_'+mode;path=ROOT/f'territory_resources_{key}.jsonl'
            if execute:
                run(path,days=5,skyline_subrays=True,inexhaustible=False,stop_after_returns=None,
                    mb_field_mode='enabled',goal_difference_mode='enabled',food_goal_mode='enabled',seed=20261001,
                    lateral_side='left',orientation_mode='enabled',reposition_mode='enabled',return_completion_mode='enabled',
                    nested_model_mode='enabled',directional_route_mode='enabled',relation_field_mode='enabled',
                    hazard_mode=mode,hazard_scenario='territorial',warning_review_mode='enabled',territory_resource_layout=layout)
            r,_=stock_audit(path)
            final={}
            for line in path.open(encoding='utf8'):
                row=json.loads(line)
                if row['type']=='decision' and row.get('safety'):
                    model=row['safety'].get('mode_model',{})
                    final[row['packet']['agent_id']]=dict(source=row['packet']['observation_id'],
                        hazard=row['packet']['hazard'],mode=row['safety']['mode'],H=model.get('H'),reason=model.get('reason'))
            r['final_warning_basis']=final
            assert len(r['finite_resources']['overlapping_resources'])==(1 if layout=='original' else 3)
            assert r['finite_resources']['initial']==[12]*8
            results[key]=r
            print(key,r['summary']['pickups'],{a:(x['unloaded'],x['carried']) for a,x in r['summary']['agents'].items()},r['final_modes'],flush=True)
    Path('tests/fixtures/lightweight_territory_resources.json').write_text(json.dumps(results,indent=2),encoding='utf8')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',action='store_true');main(p.parse_args().run)
