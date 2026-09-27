"""Two predeclared natural layouts; unchanged neutral sampler and L13S learning."""
import argparse
import hashlib
from pathlib import Path
import subprocess
from .run_learned_exploration import run_series
from .run_exploration_series import ROOT, OUTPUT, write


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--luanti-root", default=r"D:\luanti")
    args = p.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    files = ["runtime/exploration.py", "runtime/exploration_series.py", "runtime/learned_exploration.py",
             "runtime/learned_exploration_http.py", "runtime/v23_interpretation.py",
             "integrations/luanti/scripts/test-learned-exploration-day.ps1",
             "integrations/luanti/scripts/install-game.ps1"]
    files += [str(x.relative_to(ROOT)).replace("\\", "/") for pattern in
              ("integrations/luanti/tests/*exploration*.py", "integrations/luanti/game/rdl_game/mods/rdl_bridge/exploration*.lua")
              for x in ROOT.glob(pattern)]
    out = dict(schema="l13t-natural-matrix-v1", series=[], provenance=dict(
        baseline_commit=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        source_sha256={f: hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in sorted(set(files))},
        predeclared=dict(layouts=["natural_meadow", "natural_woodland"], mode="adopt", seed=20260927,
                         max_days=30, discovery_target=3),
        limitations="bounded procedural terrain, kinematic one-node steps, static daylight; not general physical navigation"))
    write(args.output, out)
    for scenario in out["provenance"]["predeclared"]["layouts"]:
        out["series"].append(run_series(scenario, "adopt", 20260927, 30, args.luanti_root))
        write(args.output, out)
    print(f"L13T MATRIX: {args.output}", flush=True)


if __name__ == "__main__":
    main()
