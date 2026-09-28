"""Fresh v1/v2 control pairs; coefficients fixed before running either layout."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from .run_exploration_series import ROOT, OUTPUT, write
from .run_multi_resource import run
from .check_terrain_steering import movement_metrics


def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True)
    p.add_argument("--luanti-root",default=r"D:\luanti");args=p.parse_args()
    cases=[dict(scenario=scenario,periods=2,assignment="mixed",control=control,faults=control,
                terrain=True,steering=version) for scenario,control in
           (("natural_meadow",True),("natural_woodland",False)) for version in (False,True)]
    paths=set(p for pattern in ("runtime/*resource*.py","runtime/terrain_steering.py",
        "runtime/subjective_movement_terrain.py","runtime/exploration.py","runtime/harvest_predictability.py",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/*resource*.lua",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/movement_surface*.lua",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/exploration*.lua",
        "integrations/luanti/scripts/*exploration*.ps1","integrations/luanti/scripts/install-game.ps1") for p in ROOT.glob(pattern))
    m=dict(schema="l15a-steering-comparison-v2",runs=[],provenance=dict(predeclared=cases,
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
        source_sha256={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}))
    OUTPUT.mkdir(parents=True,exist_ok=True);write(args.output,m)
    for case in cases:
        result=run(**case,luanti_root=args.luanti_root)
        result["movement"]=movement_metrics(result["data"])
        m["runs"].append(result);write(args.output,m)
    for old,new in zip(m["runs"][::2],m["runs"][1::2]):
        before=sum(a["consecutive_reversals"] for a in old["movement"].values())
        after=sum(a["consecutive_reversals"] for a in new["movement"].values())
        moves=sum(a["food_locomotion_results"].get("moved",0) for a in new["movement"].values())
        assert before>0 and after==0 and moves>0,(before,after,moves)
    print("L15A STEERING PASS: "+json.dumps([dict(summary=r["summary"],movement=r["movement"]) for r in m["runs"]]),flush=True)


if __name__=="__main__":main()
