"""Predeclared bounded World connection, with the existing L14B loop as control."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from .run_multi_resource import run
from .run_exploration_series import ROOT, OUTPUT, write


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--luanti-root",default=r"D:\luanti")
    args=parser.parse_args()
    cases=[dict(scenario="natural_meadow",periods=2,assignment="mixed",control=True,faults=True,terrain=True),
           dict(scenario="natural_woodland",periods=2,assignment="mixed",terrain=True),
           dict(scenario="natural_meadow",periods=2,assignment="mixed",control=True,faults=True,terrain=False)]
    files=[p for pattern in ("runtime/*resource*.py","runtime/subjective_movement_terrain.py",
        "runtime/exploration.py","runtime/harvest_predictability.py",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/*resource*.lua",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/movement_surface*.lua",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/exploration*.lua",
        "integrations/luanti/scripts/*exploration*.ps1","integrations/luanti/scripts/install-game.ps1") for p in ROOT.glob(pattern)]
    matrix=dict(schema="l15a-terrain-resource-matrix-v1",runs=[],provenance=dict(predeclared=cases,
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
        source_sha256={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}))
    OUTPUT.mkdir(parents=True,exist_ok=True);write(args.output,matrix)
    for case in cases:
        matrix["runs"].append(run(**case,luanti_root=args.luanti_root));write(args.output,matrix)
    # Do not classify a merely completed run as locomotion connection acceptance.
    terrain=matrix["runs"][0]["summary"]["agents"].values()
    assert sum(a["terrain_results"].get("moved",0) for a in terrain)>0
    assert sum(a["pickups"] for a in terrain)>0
    assert any(a["learned"] for a in terrain)
    print("L15A CONNECTION PASS: "+json.dumps([r["summary"] for r in matrix["runs"]]),flush=True)


if __name__=="__main__":main()
