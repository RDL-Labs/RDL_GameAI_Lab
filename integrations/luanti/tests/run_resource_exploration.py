"""L14A predeclared continuous World runs. No daily resource/body restoration."""
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

from runtime.resource_exploration import ResourceExploration
from runtime.resource_exploration_http import ResourceExplorationHandler
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from .run_exploration_series import ROOT, OUTPUT, write


def run(scenario, periods, seed, luanti_root, *, control=False, faults=False):
    run_id = "l14a-"+uuid4().hex[:16]
    loop = ResourceExploration(run_id, periods, seed)
    server = ThreadingHTTPServer(("127.0.0.1",8765), ResourceExplorationHandler)
    server.series = SimpleNamespace(loop=loop, lock=RLock(), canonical=GameAIFrozenComparisonSidecar())
    worker = Thread(target=server.serve_forever, daemon=True); worker.start()
    shell = shutil.which("pwsh") or shutil.which("powershell")
    log = OUTPUT/(run_id+".launch.log")
    try:
        print(f"L14A START {scenario} periods={periods} control={control} faults={faults} run={run_id}",flush=True)
        with log.open("wb") as stream:
            command = [shell,"-NoProfile","-ExecutionPolicy","Bypass","-File",
                str(ROOT/"integrations/luanti/scripts/test-learned-exploration-day.ps1"),
                "-Scenario",scenario,"-RunId",run_id,"-LuantiRoot",luanti_root,"-Resources","-ResourcePeriods",str(periods)]
            if control: command.append("-ResourceControl")
            if faults: command.append("-ResourceFaults")
            result = subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=periods*16+80)
        if result.returncode: raise RuntimeError(f"World failed: {log}")
        path = OUTPUT/(run_id+".snapshot.json")
        raw = path.read_bytes(); data = json.loads(raw.decode("utf-8-sig"))
        assert data["runtime"]["exploration"] == loop.snapshot()
        from .check_resource_exploration import check
        summary = check(data)
        print("L14A PASS "+json.dumps(summary),flush=True)
        return dict(data=data, summary=summary, source=dict(file=path.name,sha256=hashlib.sha256(raw).hexdigest()))
    finally:
        server.shutdown();server.server_close();worker.join()


def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True)
    p.add_argument("--luanti-root",default=r"D:\luanti");p.add_argument("--control-only",action="store_true")
    args=p.parse_args();OUTPUT.mkdir(parents=True,exist_ok=True)
    paths=[str(f.relative_to(ROOT)).replace("\\","/") for pattern in
        ("runtime/*exploration*.py","integrations/luanti/tests/*resource*.py",
         "integrations/luanti/game/rdl_game/mods/rdl_bridge/exploration*.lua",
         "integrations/luanti/game/rdl_game/mods/rdl_bridge/resource*.lua",
         "integrations/luanti/game/rdl_game/mods/rdl_bridge/textures/rdl_l14_*") for f in ROOT.glob(pattern)]
    paths += ["integrations/luanti/scripts/install-game.ps1","integrations/luanti/scripts/test-learned-exploration-day.ps1"]
    cases=[dict(scenario="natural_meadow",periods=2,seed=20260928,control=True,faults=True)]
    if not args.control_only:
        cases += [dict(scenario=s,periods=30,seed=20260928,control=False,faults=False)
                  for s in ("natural_meadow","natural_woodland")]
    a=dict(schema="l14a-resource-matrix-v1",runs=[],provenance=dict(
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        source_sha256={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in sorted(set(paths))},
        predeclared=cases,scope="continuous resource and observed control acceptance; feature learning not connected"))
    write(args.output,a)
    for case in cases:
        a["runs"].append(run(**case,luanti_root=args.luanti_root));write(args.output,a)
    print("L14A MATRIX: "+str(args.output),flush=True)


if __name__=="__main__":main()
