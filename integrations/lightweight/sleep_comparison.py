"""Three-day paired World run: online versus night-checkpoint harvest adoption."""
import json
from pathlib import Path
from .timed_harvest import run


def main():
    root = Path('outputs/sleep_learning')
    root.mkdir(parents=True, exist_ok=True)
    reports = {}
    for enabled in (False, True):
        reports[str(enabled)] = run(root / f'{enabled}.jsonl', days=3,
            stop_after_returns=None, seed=20261002, skyline_subrays=True,
            goal_difference_mode='enabled', food_goal_mode='enabled', lateral_side='left',
            orientation_mode='enabled', reposition_mode='enabled', return_completion_mode='enabled',
            nested_model_mode='enabled', directional_route_mode='enabled', relation_field_mode='enabled',
            selection_mode='continuous', hazard_mode='enabled', hazard_scenario='territorial',
            warning_review_mode='enabled', territory_resource_layout='three_inside',
            dynamic_hazard=True, regrowth_days=3, sleep_learning=enabled)
        print(enabled, reports[str(enabled)]['pickups'], flush=True)
    Path('tests/fixtures/lightweight_sleep_comparison.json').write_text(
        json.dumps(reports, indent=2), encoding='utf8')


if __name__ == '__main__':
    main()
