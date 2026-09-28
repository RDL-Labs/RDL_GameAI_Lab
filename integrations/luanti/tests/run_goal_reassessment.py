"""2x2 finite goal re-evaluation / memory comparison in the contact World."""
import argparse
import hashlib
import subprocess
from pathlib import Path
from .run_multi_resource import run
from .run_exploration_series import ROOT,OUTPUT,write


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True)
    p.add_argument('--luanti-root',default=r'D:\luanti');args=p.parse_args()
    cases=[dict(scenario='natural_meadow',periods=1,assignment='steady',seed=20260928,
        terrain=True,steering=True,rest='fatigue',reactivation=memory,reassessment=review,obstacle_probe=obstacle)
        for obstacle in ('persistent','removed') for review in ('disabled','enabled') for memory in ('disabled','enabled')]
    paths=['runtime/goal_reassessment.py','runtime/rest_reactivation.py',
        'integrations/luanti/game/rdl_game/mods/rdl_bridge/multi_resource_fixture.lua']
    report=dict(schema='l15a-goal-reassessment-comparison-v1',runs=[],provenance=dict(predeclared=cases,
        baseline_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        source_sha256={s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in paths}))
    OUTPUT.mkdir(exist_ok=True);write(args.output,report)
    for case in cases:
        report['runs'].append(run(**case,luanti_root=args.luanti_root));write(args.output,report)


if __name__=='__main__':main()
