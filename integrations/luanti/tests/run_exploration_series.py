"""Run fresh Luanti + Runtime processes for every bounded exploration day.

The memory/reset control is a retention baseline. No retained record is fed to
the existing fixed L13A policy, and this harness does not invent learned rules.
"""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from datetime import datetime, timezone
from uuid import uuid4

from runtime.exploration_series import ExplorationSeries, digest
from .check_exploration import check
from .check_exploration_series import check_series, check_matrix, deliveries, reset_signature

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "integrations/luanti/output"


def write(path, value):
    raw = (json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False) + "\n").encode()
    if path.suffix == ".gz":
        raw = gzip.compress(raw, mtime=0)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(raw)
    os.replace(temporary, path)


def run_series(scenario, mode, max_days, luanti_root):
    series_id = "l13r-" + uuid4().hex[:16]
    series = ExplorationSeries(series_id, mode, max_days)
    path = OUTPUT / (series_id + ".series.json.gz")
    artifact = dict(schema="l13r-real-series-v1", config=series.config, scenario=scenario, days=[], summary=series.summary())
    executable = shutil.which("pwsh") or shutil.which("powershell")
    if executable is None:
        raise RuntimeError("PowerShell is required to launch the Windows Luanti fixture")
    signature = None
    try:
        while series.summary()["status"] == "running":
            run_id = "l13r-" + uuid4().hex[:16]
            episode = "episode-" + uuid4().hex[:16]
            start = series.start_day(dict(episode_id=episode, run_id=run_id))
            history_digest = digest(series.history())
            # Persist the reservation before starting a process; no automatic retry of partial days.
            artifact["pending"] = start
            write(path, artifact)
            command = [executable, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                       str(ROOT / "integrations/luanti/scripts/test-exploration.ps1"),
                       "-LuantiRoot", luanti_root, "-Scenario", scenario, "-RunId", run_id]
            log = OUTPUT / (run_id + ".launch.log")
            with log.open("wb") as stream:
                completed = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
            if completed.returncode:
                raise RuntimeError(f"Luanti day failed; see {log}")
            source = OUTPUT / (run_id + ".snapshot.json")
            raw = source.read_bytes()
            data = json.loads(raw.decode("utf-8-sig"))
            check(data)
            current = reset_signature(data)
            if signature is not None and current != signature:
                raise RuntimeError("Initial World/body changed between days")
            signature = current
            receipt = series.close_day(dict(episode_id=episode, run_id=run_id, deliveries=deliveries(data)))
            artifact["days"].append(dict(episode_id=episode, start=start, history_digest=history_digest,
                                         receipt=receipt, source=dict(file=source.name, sha256=hashlib.sha256(raw).hexdigest()),
                                         data=data))
            artifact.pop("pending", None)
            artifact["summary"] = series.summary()
            write(path, artifact)
            print(f"L13R {scenario}/{mode} day {start['day']}/{max_days}: "
                  f"{receipt['metrics']['ending']}, history={start['history_observations']}, "
                  f"series={artifact['summary']['status']}", flush=True)
        check_series(artifact, check_world=False)
        print(f"L13R SERIES: {path}", flush=True)
        return artifact, path
    except Exception as exc:
        if series.summary()["status"] == "running":
            series.abort("world_or_transport_error")
        artifact["summary"] = series.summary()
        artifact["error"] = str(exc)
        write(path, artifact)
        raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luanti-root", default=r"D:\luanti")
    parser.add_argument("--scenario", choices=("right", "no_strip", "no_food", "partial", "blocked", "faults"), default="no_strip")
    parser.add_argument("--mode", choices=("memory", "reset"), default="memory")
    parser.add_argument("--max-days", type=int, choices=range(1, 31), default=30)
    parser.add_argument("--matrix", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    # Snapshot implementation identities before execution. World/private evidence never enters the series ledger.
    source_paths = ["runtime/exploration.py", "runtime/exploration_series.py",
                    "integrations/luanti/scripts/test-exploration.ps1",
                    "integrations/luanti/tests/check_exploration.py",
                    "integrations/luanti/tests/check_exploration_series.py",
                    "integrations/luanti/tests/run_exploration_series.py"]
    source_paths += [str(p.relative_to(ROOT)).replace("\\", "/") for p in
                     (ROOT / "integrations/luanti/game/rdl_game/mods/rdl_bridge").glob("exploration*.lua")]
    hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in source_paths}
    cases = [(s, m) for s in ("right", "no_strip") for m in ("memory", "reset")] if args.matrix else [(args.scenario, args.mode)]
    if args.matrix and args.max_days != 30:
        parser.error("Acceptance matrix requires --max-days 30")
    series = []
    for scenario, mode in cases:
        value, path = run_series(scenario, mode, args.max_days, args.luanti_root)
        series.append(value)
    if args.matrix:
        artifact = dict(schema="l13r-real-matrix-v1", series=series, provenance=dict(
            baseline_commit=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
            working_tree_implementation=True, source_sha256=hashes,
            method="62 fresh real Luanti runs; unmodified snapshot trees and exact HTTP wires; private World evidence checker-only.",
            limitations="History retained or withheld, but neither feeds the fixed L13A action policy; no learned route, Experience/T1/M_B update, night, or physical return to base."))
        check_matrix(artifact)
        path = args.output or OUTPUT / ("l13r-matrix-" + datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S") + ".json.gz")
        write(path, artifact)
        print(f"L13R MATRIX: {path}", flush=True)
    elif args.output:
        write(args.output, series[0])


if __name__ == "__main__":
    main()
