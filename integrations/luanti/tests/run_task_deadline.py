"""One task, three deadlines, unchanged local action budgets."""
import argparse
import hashlib
import subprocess
from pathlib import Path
from .run_multi_resource import run
from .run_exploration_series import ROOT, OUTPUT, write


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    cases = [dict(scenario='natural_meadow', periods=1, assignment='steady',
                  seed=20260928, terrain=True, steering=True, rest='fatigue',
                  reactivation='enabled', reassessment='enabled', obstacle_probe='removed',
                  simulation_speed=1.5, task_seconds=n) for n in (16, 32, 64)]
    paths = ['runtime/exploration_deadline.py', 'runtime/resource_exploration.py',
             'runtime/movement_rest.py', 'runtime/movement_recurrence.py',
             'integrations/luanti/game/rdl_game/mods/rdl_bridge/multi_resource_fixture.lua']
    report = dict(schema='l15a-task-deadline-comparison-v1', predeclared=cases, runs=[],
                  baseline_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  source_sha256={s: hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in paths})
    OUTPUT.mkdir(exist_ok=True)
    write(args.output, report)
    for case in cases:
        report['runs'].append(run(**case, luanti_root=r'D:\luanti'))
        write(args.output, report)


if __name__ == '__main__':
    main()
