"""Three-day paired World run: online versus night-checkpoint harvest adoption."""
import json
from pathlib import Path
from .timed_harvest import run


def main(auto_adoption=False,days=3):
    suffix='' if days==3 else f'_{days}d'
    root = Path(('outputs/sleep_auto' if auto_adoption else 'outputs/sleep_learning')+suffix)
    root.mkdir(parents=True, exist_ok=True)
    reports = {}
    for enabled in (False, True):
        reports[str(enabled)] = run(root / f'{enabled}.jsonl', days=days,
            stop_after_returns=None, seed=20261002, skyline_subrays=True,
            goal_difference_mode='enabled', food_goal_mode='enabled', lateral_side='left',
            orientation_mode='enabled', reposition_mode='enabled', return_completion_mode='enabled',
            nested_model_mode='enabled', directional_route_mode='enabled', relation_field_mode='enabled',
            selection_mode='continuous', hazard_mode='enabled', hazard_scenario='territorial',
            warning_review_mode='enabled', territory_resource_layout='three_inside',
            dynamic_hazard=True, regrowth_days=3, sleep_learning=True if auto_adoption else enabled,
            sleep_auto_adopt=enabled if auto_adoption else False)
        print(enabled, reports[str(enabled)]['pickups'], flush=True)
        if days!=3:
            from .daily_review import analyze
            reports[str(enabled)]['daily_review']=analyze(root/f'{enabled}.jsonl',days)
    path=Path(('tests/fixtures/lightweight_sleep_auto_comparison' if auto_adoption
         else 'tests/fixtures/lightweight_sleep_comparison')+suffix+'.json')
    if days!=3:
        import gzip
        with gzip.open(str(path)+'.gz','wt',encoding='utf8') as stream:
            json.dump(reports,stream,separators=(',',':'))
    else:
        path.write_text(json.dumps(reports, indent=2), encoding='utf8')


if __name__ == '__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--auto-adoption',action='store_true')
    parser.add_argument('--days',type=int,default=3);args=parser.parse_args()
    main(args.auto_adoption,args.days)
