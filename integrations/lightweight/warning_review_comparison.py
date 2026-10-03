"""Warning-mode H selection under the same finite territorial campaign."""
import argparse
import json
from pathlib import Path
from .timed_harvest import run
from .finite_territory_comparison import stock_audit
from .audit_moving_hazard import ROOT


def main(execute=False):
    reports={};baseline=None
    for mode in ('disabled','shadow','enabled'):
        path=ROOT/f'warning_review_{mode}.jsonl'
        if execute:
            run(path,days=5,skyline_subrays=True,inexhaustible=False,stop_after_returns=None,
                mb_field_mode='enabled',goal_difference_mode='enabled',food_goal_mode='enabled',seed=20261001,
                lateral_side='left',orientation_mode='enabled',reposition_mode='enabled',return_completion_mode='enabled',
                nested_model_mode='enabled',directional_route_mode='enabled',relation_field_mode='enabled',
                hazard_mode='enabled',hazard_scenario='territorial',warning_review_mode=mode)
        r,c=stock_audit(path);releases=[]
        for line in path.open(encoding='utf8'):
            row=json.loads(line)
            if row['type']!='decision':continue
            s=row.get('safety') or {};n=s.get('mode_model')
            if not n:continue
            assert 0<=n['H']<=n['threshold'] and len(n['events'])<=32
            if row['packet']['hazard']['features'] and s['override']:assert n['H']==0
            if n['applied']:
                assert mode=='enabled' and not s['override'] and not row['packet']['hazard']['features']
                assert s['reason']=='provisional_mode_release' and n['H']>=n['threshold']
                releases.append(dict(agent=row['packet']['agent_id'],capture_us=row['packet']['capture_us'],
                    coverage=row['packet']['hazard']['coverage'],H=n['H'],action=row['command']['kind'],reason=row['command']['reason'],phase=row['activity_phase']))
        r['provisional_releases']=releases;reports[mode]=r
        if mode=='disabled':baseline=c
        if mode=='shadow':assert c==baseline
        print(mode,r['summary']['pickups'],{a:(x['unloaded'],x['carried']) for a,x in r['summary']['agents'].items()},r['final_modes'],len(releases),flush=True)
    Path('tests/fixtures/lightweight_warning_review.json').write_text(json.dumps(reports,indent=2),encoding='utf8')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--run',action='store_true');main(p.parse_args().run)
