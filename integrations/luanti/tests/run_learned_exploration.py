"""Finite real Luanti runs; no World truth is supplied to the learning runtime."""
import argparse
import hashlib
import json
from http.server import ThreadingHTTPServer
from pathlib import Path
import shutil
import subprocess
from threading import Thread
from uuid import uuid4

from runtime.learned_exploration import LearnedExplorationSeries
from runtime.learned_exploration_http import LearnedExplorationHandler
from runtime.exploration_series import digest
from .run_exploration_series import write, ROOT, OUTPUT
from .check_learned_exploration import check_series, check_matrix


def run_series(scenario, mode, seed, max_days, luanti_root, *, landmarks=False, neighborhood=False, multifood=False):
    from runtime.landmark_exploration import LandmarkExplorationSeries
    from runtime.neighborhood_exploration import NeighborhoodExplorationSeries
    from runtime.multifood_exploration import MultiFoodExplorationSeries
    series_type = MultiFoodExplorationSeries if multifood else (NeighborhoodExplorationSeries if neighborhood else (LandmarkExplorationSeries if landmarks else LearnedExplorationSeries))
    s = series_type(("l13w-" if multifood else ("l13v-" if neighborhood else ("l13u-" if landmarks else "l13s-")))+uuid4().hex[:16], mode, seed, max_days)
    path = OUTPUT/(s.config["series_id"]+".series.json.gz")
    a = dict(schema="l13s-real-series-v1", config=s.config, scenario=scenario, days=[], state=s.snapshot())
    shell = shutil.which("pwsh") or shutil.which("powershell")
    try:
        while s.summary()["status"] == "running":
            run = "l13s-"+uuid4().hex[:16]
            start = s.start_day(dict(run_id=run, episode_id="episode-"+uuid4().hex[:16]))
            a["pending"] = start; write(path,a)
            server = ThreadingHTTPServer(("127.0.0.1",8765), LearnedExplorationHandler)
            server.series = s
            thread = Thread(target=server.serve_forever,daemon=True); thread.start()
            log = OUTPUT/(run+".launch.log")
            try:
                with log.open("wb") as stream:
                    result = subprocess.run([shell,"-NoProfile","-ExecutionPolicy","Bypass","-File",
                        str(ROOT/"integrations/luanti/scripts/test-learned-exploration-day.ps1"),
                        "-Scenario",scenario,"-RunId",run,"-LuantiRoot",luanti_root]+(["-MultiFood"] if multifood else (["-Neighborhood"] if neighborhood else (["-Landmarks"] if landmarks else []))),
                        cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=75)
                if result.returncode:
                    raise RuntimeError(f"Luanti failed: {log}")
            finally:
                server.shutdown(); server.server_close(); thread.join()
            raw = (OUTPUT/(run+".snapshot.json")).read_bytes()
            data = json.loads(raw.decode("utf-8-sig"))
            assert data["runtime"]["exploration"] == s.loop.snapshot()
            receipt = s.close_day(dict(**start["request"], state_digest=digest(s.loop.snapshot())))
            a["days"].append(dict(start=start, receipt=receipt, summary=s.summary(), data=data,
                source=dict(file=run+".snapshot.json", sha256=hashlib.sha256(raw).hexdigest())))
            a.pop("pending",None); a["state"] = s.snapshot(); write(path,a)
            print(f"L13S {scenario}/{mode} day {start['day']}: found={s.summary()['discovery_count']}/3 "
                  f"Sleep={receipt['sleep']['status']} adopted={s.summary()['adopted']} status={s.summary()['status']}",flush=True)
        check_series(a)
        print(f"L13S SERIES: {path}",flush=True)
        return a
    except Exception as exc:
        if s.summary()["status"] == "running": s.abort("world_or_transport_error")
        a.update(state=s.snapshot(), error=str(exc)); write(path,a)
        raise


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--scenario", default="straight", choices=("straight","right","left","rotated","no_strip","no_food","partial","blocked","faults","natural_meadow","natural_woodland"))
    p.add_argument("--modes", nargs="+", choices=("record","inspect","adopt"), default=["record","inspect","adopt"])
    p.add_argument("--seed", type=int, default=20260927)
    p.add_argument("--max-days", type=int, default=30)
    p.add_argument("--luanti-root", default=r"D:\luanti")
    p.add_argument("--output", type=Path, required=True)
    args=p.parse_args(); OUTPUT.mkdir(parents=True,exist_ok=True)
    sources=["runtime/exploration_series.py","runtime/exploration.py","runtime/learned_exploration.py","runtime/learned_exploration_http.py","runtime/v23_interpretation.py",
        "integrations/luanti/scripts/test-learned-exploration-day.ps1",
        "integrations/luanti/tests/check_exploration.py","integrations/luanti/tests/check_learned_exploration.py",
        "integrations/luanti/tests/run_learned_exploration.py"]
    sources += [str(x.relative_to(ROOT)).replace("\\","/") for x in (ROOT/"integrations/luanti/game/rdl_game/mods/rdl_bridge").glob("exploration*.lua")]
    a=dict(schema="l13s-real-matrix-v1", series=[], provenance=dict(
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        source_sha256={x:hashlib.sha256((ROOT/x).read_bytes()).hexdigest() for x in sources},
        method="fresh real Luanti days, continuous clock, exact HTTP wires; no seed search or success rescue",
        limitations="one episodic formation plus one explicitly prompted held-out Probe; no general road semantics, physical sleep or autonomous review"))
    for mode in args.modes:
        a["series"].append(run_series(args.scenario,mode,args.seed,args.max_days,args.luanti_root)); write(args.output,a)
    check_matrix(a); write(args.output,a)
    print(f"L13S MATRIX: {args.output}",flush=True)

if __name__ == "__main__": main()
