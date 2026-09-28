"""Same fatigue rest, retrieval disabled/enabled; separate fault/control run."""
import argparse
import hashlib
import subprocess
from pathlib import Path
from .run_multi_resource import run
from .run_exploration_series import ROOT,OUTPUT,write


def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True)
    p.add_argument("--luanti-root",default=r"D:\luanti");args=p.parse_args()
    cases=[dict(scenario="natural_meadow",periods=2,assignment="steady",seed=20260928,
        terrain=True,steering=True,rest="fatigue",reactivation=mode) for mode in ("disabled","enabled")]
    cases.append(dict(cases[-1],control=True,faults=True))
    paths=[ROOT/n for n in ("runtime/rest_reactivation.py","runtime/movement_rest.py",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/multi_resource_fixture.lua")]
    report=dict(schema="l15a-rest-reactivation-comparison-v1",runs=[],provenance=dict(predeclared=cases,
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
        source_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}))
    OUTPUT.mkdir(parents=True,exist_ok=True);write(args.output,report)
    for case in cases:
        report["runs"].append(run(**case,luanti_root=args.luanti_root));write(args.output,report)


if __name__=="__main__":main()
