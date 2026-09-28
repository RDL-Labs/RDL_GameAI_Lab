"""One unchanged continuous World, up to thirty days or three returned batches."""
import argparse
import hashlib
import json
import lzma
import os
import shutil
import subprocess
from http.server import ThreadingHTTPServer
from pathlib import Path
from threading import Thread,RLock
from types import SimpleNamespace
from uuid import uuid4
from runtime.landmark_return_campaign import ReturnCampaign
from runtime.multi_resource_http import MultiResourceHandler
from .run_exploration_series import ROOT,OUTPUT,write as write_standard
from .check_return_campaign import check


def write(path, value):
    if path.suffix != ".xz": return write_standard(path,value)
    temporary=path.with_name(path.name+".tmp")
    with lzma.open(temporary,"wt",encoding="utf-8",preset=3) as stream:
        json.dump(value,stream,ensure_ascii=False,separators=(",",":"),allow_nan=False)
    os.replace(temporary,path)


def main():
    parser=argparse.ArgumentParser();parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--periods",type=int,default=30);parser.add_argument("--speed",type=float,default=1.5)
    parser.add_argument("--model-field",choices=("off","disabled","enabled"),default="off")
    parser.add_argument("--harvest-state",action="store_true")
    parser.add_argument("--agents",type=int,choices=(3,6),default=3)
    args=parser.parse_args()
    run_id="l15campaign-"+uuid4().hex[:12]
    loop=ReturnCampaign(run_id,args.periods,mb_field_mode=args.model_field,harvest_state=args.harvest_state,agent_count=args.agents)
    server=ThreadingHTTPServer(("127.0.0.1",8765),MultiResourceHandler)
    server.series=SimpleNamespace(loop=loop,lock=RLock())
    worker=Thread(target=server.serve_forever,daemon=True);worker.start()
    report=dict(schema="l15a-return-campaign-evidence-v1",run_id=run_id,
        predeclared=dict(days=args.periods,stop_after_returns=args.agents,agent_count=args.agents,scope="population aggregate; one batch per agent/night",
            harvest_state=args.harvest_state,model_field_mode=args.model_field,simulation_speed=args.speed,scenario="natural_meadow",assignment="steady"),runs=[],
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip())
    sources=["runtime/current_harvest_state.py","runtime/multi_resource_exploration.py","integrations/luanti/scripts/test-learned-exploration-day.ps1","runtime/landmark_return_campaign.py","runtime/landmark_day_cycle.py","runtime/exploration.py",
        "runtime/model_movement_field.py","runtime/terrain_resource_exploration.py","runtime/terrain_steering.py",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/multi_resource_fixture.lua"]
    report["source_sha256"]={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in sources}
    OUTPUT.mkdir(exist_ok=True);write(args.output,report)
    try:
        print(f"CAMPAIGN START {run_id} max_days={args.periods} speed={args.speed}",flush=True)
        command=[shutil.which("pwsh") or shutil.which("powershell"),"-NoProfile","-ExecutionPolicy","Bypass","-File",
            str(ROOT/"integrations/luanti/scripts/test-learned-exploration-day.ps1"),"-RunId",run_id,
            "-Scenario","natural_meadow","-MultiResources","-MovementTerrain","-MovementSteering","-DayCycle",
            "-ReturnCampaign","-RawWorldOnly","-ResourcePeriods",str(args.periods),"-ResourceAssignment","steady",
            "-AgentCount",str(args.agents),"-SimulationSpeed",str(args.speed),"-ModelFieldMode",args.model_field]
        log=OUTPUT/(run_id+".launch.log")
        with log.open("wb") as stream:
            result=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=args.periods*64+600)
        if result.returncode: raise RuntimeError(f"World failed: {log}")
        path=ROOT/"integrations/luanti/worlds"/run_id/"l14b-evidence.json"
        world=json.loads(path.read_text(encoding="utf-8"))
        print("World ended; collecting final Runtime before audit",flush=True)
        data=dict(world=world,runtime=dict(exploration=loop.snapshot(),history={}))
        # Save before checking so an audit failure never discards the actual run.
        failure=world.get("failure")
        aborted=dict(status="aborted",strict_acceptance=False,failure=failure,finished_us=world.get("finished_us")) if failure else None
        report["runs"].append(dict(data=data,summary=aborted));write(args.output,report)
        if failure: raise RuntimeError("World failed; partial World/Runtime preserved: "+str(failure))
        summary=check(data,require_clean_transport=False);report["runs"][0]["summary"]=summary;write(args.output,report)
        compact={k:v for k,v in summary.items() if k not in ("days","agents")}
        print(("CAMPAIGN PASS " if summary["strict_acceptance"] else "CAMPAIGN TIMING ACCEPTANCE FAILED ")+json.dumps(compact),flush=True)
        if not summary["strict_acceptance"]: raise SystemExit(1)
    finally:
        server.shutdown();server.server_close();worker.join()


if __name__=="__main__":main()
