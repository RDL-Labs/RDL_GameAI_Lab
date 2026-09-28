"""Predeclared continuous three-day skyline return / night-rest experiment."""
import argparse
import hashlib
import subprocess
from pathlib import Path
from .run_multi_resource import run
from .run_exploration_series import ROOT, OUTPUT, write


def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True)
    p.add_argument("--periods",type=int,choices=(1,3),default=3)
    args=p.parse_args()
    cases=[dict(scenario="natural_meadow",periods=args.periods,assignment="steady",
        terrain=True,steering=True,day_cycle=True,simulation_speed=1.5)]
    sources=["runtime/landmark_day_cycle.py","integrations/luanti/game/rdl_game/mods/rdl_bridge/exploration_natural.lua","integrations/luanti/game/rdl_game/mods/rdl_bridge/elevated_landmarks.lua",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/multi_resource_fixture.lua",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/exploration_controller.lua"]
    report=dict(schema="l15a-landmark-day-cycle-evidence-v1",predeclared=cases,runs=[],
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        source_sha256={s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in sources})
    OUTPUT.mkdir(exist_ok=True);write(args.output,report)
    for case in cases:
        report["runs"].append(run(**case,luanti_root=r"D:\luanti"));write(args.output,report)


if __name__=="__main__":main()
