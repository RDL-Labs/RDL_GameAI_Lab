"""Fixed contact/rest experiment, not a new action or recovery policy."""
import argparse
import hashlib
import subprocess
from pathlib import Path
from .run_multi_resource import run
from .run_exploration_series import ROOT, OUTPUT, write
from .check_rest_obstacle import check, compare


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True)
    p.add_argument('--luanti-root',default=r'D:\luanti');args=p.parse_args()
    cases=[dict(scenario='natural_meadow',periods=1,assignment='steady',seed=20260928,
        terrain=True,steering=True,rest='fatigue',reactivation=mode,obstacle_probe=obstacle)
        for obstacle in ('persistent','removed') for mode in ('disabled','enabled')]
    paths=['runtime/rest_reactivation.py','runtime/movement_rest.py',
        'integrations/luanti/game/rdl_game/mods/rdl_bridge/multi_resource_fixture.lua']
    report=dict(schema='l15a-rest-obstacle-comparison-v1',runs=[],provenance=dict(
        baseline_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        predeclared=cases,selection='After one exploratory persistent/enabled run; no acceptance rules relaxed.',
        schedule=dict(insert_slot=23,remove_slot=27,review_slot=28),
        source_sha256={s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in paths}))
    OUTPUT.mkdir(parents=True,exist_ok=True);write(args.output,report)
    for case in cases:
        r=run(**case,luanti_root=args.luanti_root)
        report['runs'].append(r);write(args.output,report)
        r['obstacle_summary']=check(r['data']);write(args.output,report)
    report['comparison']=compare(report['runs']);write(args.output,report)
    print(report['comparison'],flush=True)


if __name__=='__main__':main()
