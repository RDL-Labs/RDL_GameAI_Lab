"""L13W changes the resource count, retaining L13V terrain and learning rules."""
import argparse
import hashlib
import subprocess
from pathlib import Path
from .run_exploration_series import ROOT, OUTPUT, write
from .run_learned_exploration import run_series
from .check_learned_exploration import check_matrix
from .check_multifood_exploration import SITES


def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True)
    p.add_argument("--luanti-root",default=r"D:\luanti");args=p.parse_args()
    OUTPUT.mkdir(parents=True,exist_ok=True)
    paths=[str(f.relative_to(ROOT)).replace("\\","/") for pattern in
           ("runtime/*exploration*.py","integrations/luanti/tests/*exploration*.py", "integrations/luanti/game/rdl_game/mods/rdl_bridge/exploration*.lua") for f in ROOT.glob(pattern)]
    paths += ["runtime/v23_interpretation.py","integrations/luanti/scripts/test-learned-exploration-day.ps1","integrations/luanti/scripts/install-game.ps1"]
    a=dict(schema="l13w-multifood-matrix-v1",series=[],provenance=dict(
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        source_sha256={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in sorted(set(paths))},
        predeclared=dict(layouts=["natural_meadow","natural_woodland"],seed=20260927,max_days=30,
                         discovery_target=3,mode="adopt",food_sites=SITES,food_count=5,
                         comparison="same terrain and controller as archived L13V; resource count/placement intervention, not a learning-only effect")))
    write(args.output,a)
    for scenario in a["provenance"]["predeclared"]["layouts"]:
        a["series"].append(run_series(scenario,"adopt",20260927,30,args.luanti_root,multifood=True))
        write(args.output,a)
    check_matrix(a);write(args.output,a)
    print("L13W MATRIX: "+str(args.output),flush=True)


if __name__=="__main__":main()
