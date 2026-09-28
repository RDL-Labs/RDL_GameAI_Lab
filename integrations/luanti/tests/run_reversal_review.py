"""Stationary next-observation review, off/on at the same task deadline."""
import argparse
import hashlib
import subprocess
from pathlib import Path
from .run_multi_resource import run
from .run_exploration_series import ROOT, OUTPUT, write


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    cases = [dict(scenario='natural_meadow', periods=1, assignment='steady',
                  terrain=True, steering=True, rest='fatigue', reactivation='enabled',
                  reassessment='enabled', obstacle_probe='removed', simulation_speed=1.5,
                  task_seconds=32, reversal_review=mode) for mode in ('disabled', 'enabled')]
    sources = ['runtime/reversal_review.py', 'runtime/reversal_review_loop.py',
               'runtime/terrain_steering.py',
               'integrations/luanti/game/rdl_game/mods/rdl_bridge/multi_resource_fixture.lua']
    report = dict(schema='l15a-reversal-review-comparison-v1', predeclared=cases, runs=[],
                  baseline_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  source_sha256={s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in sources})
    OUTPUT.mkdir(exist_ok=True)
    write(args.output, report)
    for case in cases:
        report['runs'].append(run(**case, luanti_root=r'D:\luanti'))
        write(args.output, report)


if __name__ == '__main__':
    main()
