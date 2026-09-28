"""L14B predeclared three-agent continuous World runs."""
import argparse
import hashlib
import json
from http.server import ThreadingHTTPServer
from pathlib import Path
import shutil
import subprocess
from threading import Thread, RLock
from types import SimpleNamespace
from uuid import uuid4

from runtime.multi_resource_exploration import MultiResourceExploration
from runtime.multi_resource_http import MultiResourceHandler
from .run_exploration_series import ROOT, OUTPUT, write


def run(scenario, periods, assignment, luanti_root, control=False, faults=False, seed=20260928, terrain=False, steering=False):
    run_id="l14b-"+uuid4().hex[:16]
    if terrain:
        from runtime.terrain_resource_exploration import TerrainResourceExploration
    loop_type=TerrainResourceExploration if terrain else MultiResourceExploration
    if steering:
        from runtime.terrain_steering import SteeredResourceExploration
        loop_type=SteeredResourceExploration
    loop=loop_type(run_id, periods, seed=seed, assignment=assignment)
    server=ThreadingHTTPServer(("127.0.0.1",8765),MultiResourceHandler)
    server.series=SimpleNamespace(loop=loop,lock=RLock())
    worker=Thread(target=server.serve_forever,daemon=True);worker.start()
    log=OUTPUT/(run_id+".launch.log")
    try:
        print(f"L14B START {scenario} periods={periods} assignment={assignment} seed={seed} control={control} run={run_id}",flush=True)
        command=[shutil.which("pwsh") or shutil.which("powershell"),"-NoProfile","-ExecutionPolicy","Bypass","-File",
            str(ROOT/"integrations/luanti/scripts/test-learned-exploration-day.ps1"),"-Scenario",scenario,
            "-RunId",run_id,"-LuantiRoot",luanti_root,"-MultiResources","-ResourcePeriods",str(periods),
            "-ResourceAssignment",assignment]
        if control:command.append("-ResourceControl")
        if faults:command.append("-ResourceFaults")
        if terrain:command.append("-MovementTerrain")
        if steering:command.append("-MovementSteering")
        with log.open("wb") as stream:
            result=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=periods*16+80)
        if result.returncode:raise RuntimeError(f"World failed: {log}")
        path=OUTPUT/(run_id+".snapshot.json");raw=path.read_bytes();data=json.loads(raw.decode("utf-8-sig"))
        assert data["runtime"]["exploration"]==loop.snapshot()
        if steering:
            from .check_terrain_steering import check
        elif terrain:
            from .check_terrain_resource import check
        else:
            from .check_multi_resource import check
        summary=check(data)
        print("L14B PASS "+json.dumps(summary),flush=True)
        return dict(data=data,summary=summary,source=dict(file=path.name,sha256=hashlib.sha256(raw).hexdigest()))
    finally:
        server.shutdown();server.server_close();worker.join()


def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True)
    p.add_argument("--luanti-root",default=r"D:\luanti");p.add_argument("--control-only",action="store_true")
    p.add_argument("--main-only",action="store_true")
    args=p.parse_args();OUTPUT.mkdir(parents=True,exist_ok=True)
    cases=[] if args.main_only else [dict(scenario="natural_meadow",periods=2,assignment="mixed",control=True,faults=True)]
    if not args.control_only:
        cases += [dict(scenario="natural_woodland",periods=30,assignment=a) for a in ("mixed","swapped")]
    paths=[p for pattern in ("runtime/*resource*.py","runtime/harvest_predictability.py","runtime/v23_interpretation.py",
        "runtime/exploration.py","integrations/luanti/game/rdl_game/mods/rdl_bridge/*resource*.lua",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/exploration*.lua",
        "integrations/luanti/scripts/*exploration*.ps1","integrations/luanti/scripts/install-game.ps1") for p in ROOT.glob(pattern)]
    a=dict(schema="l14b-multi-resource-matrix-v1",runs=[],provenance=dict(
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        source_sha256={str(p.relative_to(ROOT)).replace("\\","/"):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
        predeclared=cases))
    write(args.output,a)
    for case in cases:
        a["runs"].append(run(**case,luanti_root=args.luanti_root));write(args.output,a)
    print("L14B MATRIX: "+str(args.output),flush=True)


if __name__=="__main__":main()
