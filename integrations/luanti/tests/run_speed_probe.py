"""Finite speed sweep. Failed runs and command differences remain evidence."""
import argparse
import hashlib
import json
import platform
import subprocess
import time
from pathlib import Path

from .run_multi_resource import run
from .run_exploration_series import ROOT, OUTPUT, write


def signature(data):
    return {aid: [(c['kind'], c['amount'], c['reason'],
                   a['results'].get(c['operation_id'], {}).get('status'))
                  for c in a['commands'].values()]
            for aid, a in data['runtime']['exploration']['agents'].items()}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--speeds', nargs='+', type=float, default=[1, 2, 4, 8, 16])
    p.add_argument('--periods', type=int, default=1)
    args = p.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = dict(schema='l15a-speed-probe-v1', predeclared_speeds=args.speeds,
                  periods=args.periods, runs=[])
    sources = ['integrations/luanti/game/rdl_game/mods/rdl_bridge/multi_resource_fixture.lua',
               'integrations/luanti/scripts/test-learned-exploration-day.ps1',
               'integrations/luanti/tests/run_multi_resource.py']
    report['provenance'] = dict(platform=platform.platform(), python=platform.python_version(),
        baseline_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        source_sha256={s: hashlib.sha256((ROOT / s).read_bytes()).hexdigest() for s in sources})
    baseline = None
    for speed in args.speeds:
        before = set(OUTPUT.glob('*.snapshot.json'))
        start = time.perf_counter()
        entry = dict(speed=speed)
        try:
            result = run('natural_meadow', args.periods, 'steady', r'D:\luanti',
                         terrain=True, steering=True, rest='fatigue',
                         reactivation='enabled', reassessment='enabled',
                         obstacle_probe='removed', simulation_speed=speed)
            entry.update(accepted=True, data=result['data'], summary=result['summary'])
        except Exception as exc:
            entry.update(accepted=False, error=str(exc))
            snapshots = set(OUTPUT.glob('*.snapshot.json')) - before
            if len(snapshots) == 1:
                entry['data'] = json.loads(snapshots.pop().read_text(encoding='utf-8-sig'))
        entry['launch_and_check_seconds'] = time.perf_counter() - start
        if 'data' in entry:
            current = signature(entry['data'])
            if baseline is None and speed == 1 and entry['accepted']:
                baseline = current
            entry['same_commands_and_results_as_1x'] = current == baseline if baseline is not None else None
        report['runs'].append(entry)
        write(args.output, report)
        print('SPEED RESULT', {k: v for k, v in entry.items() if k not in ('data', 'summary')}, flush=True)


if __name__ == '__main__':
    main()
