"""Predeclared neutral/mixed/swapped bias-only runs, unchanged L14B profiles."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from .run_exploration_series import ROOT, OUTPUT, write
from .run_multi_resource import run
from .check_terrain_lateral import decision_links


def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True)
    p.add_argument("--followup",action="store_true",help="After-primary diagnostic: all-left/all-right meadow, fixed coefficients")
    p.add_argument("--luanti-root",default=r"D:\luanti");args=p.parse_args()
    cases=[dict(scenario=scenario,periods=2,assignment="mixed",control=control,faults=False,
        terrain=True,steering=False,lateral=lateral,seed=20260928)
        for scenario,control in (("natural_meadow",True),("natural_woodland",False))
        for lateral in ("neutral","mixed","swapped")]
    if args.followup:
        cases=[dict(scenario="natural_meadow",periods=2,assignment="mixed",control=True,faults=False,
            terrain=True,steering=False,lateral=lateral,seed=20260928) for lateral in ("left","right")]
    paths=set(p for pattern in ("runtime/*resource*.py","runtime/terrain_lateral_bias.py",
        "runtime/subjective_movement_terrain.py","runtime/exploration.py","runtime/harvest_predictability.py",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/*resource*.lua",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/movement_surface*.lua",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/exploration*.lua",
        "integrations/luanti/scripts/*exploration*.ps1","integrations/luanti/scripts/install-game.ps1") for p in ROOT.glob(pattern))
    matrix=dict(schema="l15a-lateral-comparison-v1",runs=[],provenance=dict(predeclared=cases,
        phase="after-primary exploratory diagnostic" if args.followup else "primary six-run comparison",
        motivation="Primary A/C had no eligible pairs; vary B as well, without changing coefficients" if args.followup else None,
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        source_sha256={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}))
    OUTPUT.mkdir(parents=True,exist_ok=True);write(args.output,matrix)
    for case in cases:
        result=run(**case,luanti_root=args.luanti_root)
        result["decision_links"]=decision_links(result["data"])
        matrix["runs"].append(result);write(args.output,matrix)
    print("L15A LATERAL COMPLETE: "+str(args.output),flush=True)


if __name__=="__main__":main()
