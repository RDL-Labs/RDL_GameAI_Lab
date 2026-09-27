"""Predeclared L14B exploration-seed panel; the World terrain stays fixed."""
import argparse
from datetime import datetime, timezone
import hashlib
from pathlib import Path
import subprocess

from .run_exploration_series import ROOT, OUTPUT, write
from .run_multi_resource import run

SEEDS = (20260929, 20260930, 20261001)
BASELINE = ROOT / "tests/fixtures/luanti_l14b_replay.json.gz"


def cases():
    return [dict(scenario="natural_woodland", periods=30, assignment="mixed",
                 control=False, faults=False, seed=seed) for seed in SEEDS]


def source_hashes():
    # Include all Runtime dependencies and the shared World producer, not just
    # files whose names mention resources. This manifest is frozen before runs.
    paths = [*ROOT.glob("runtime/*.py"),
             *ROOT.glob("integrations/luanti/game/rdl_game/mods/rdl_bridge/*.lua"),
             *ROOT.glob("integrations/luanti/scripts/*.ps1"),
             ROOT / "integrations/luanti/tests/run_multi_resource.py",
             Path(__file__).resolve()]
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(set(paths))}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--luanti-root", default=r"D:\luanti")
    args = p.parse_args()
    if args.output.exists():
        raise FileExistsError("Keep prior attempts; choose a new output path")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    artifact = dict(schema="l14b-seed-panel-v1", runs=[], provenance=dict(
        declared_at_utc=datetime.now(timezone.utc).isoformat(),
        baseline_commit=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        historical_baseline=dict(file=BASELINE.relative_to(ROOT).as_posix(),
            sha256=hashlib.sha256(BASELINE.read_bytes()).hexdigest(),
            run_id="l14b-0381821f5c40434d", seed=20260928),
        source_sha256=source_hashes(), predeclared=cases(),
        scope="Exploration seed only; fixed terrain, starts, profiles and stock. No sweep selection."))
    write(args.output, artifact)
    for case in cases():
        artifact["pending"] = case
        write(args.output, artifact)
        try:
            item = run(**case, luanti_root=args.luanti_root)
        except Exception as error:
            artifact["failure"] = dict(case=case, message=str(error))
            write(args.output, artifact)
            raise
        assert item["data"]["runtime"]["exploration"]["seed"] == case["seed"]
        artifact["runs"].append(item)
        artifact.pop("pending")
        write(args.output, artifact)
    print("L14B SEED PANEL: " + str(args.output), flush=True)


if __name__ == "__main__":
    main()
