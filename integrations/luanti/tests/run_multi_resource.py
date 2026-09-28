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


def run(scenario, periods, assignment, luanti_root, control=False, faults=False, seed=20260928, terrain=False, steering=False, lateral="off", tie_break="off", rest="off", reactivation="off", obstacle_probe="off", reassessment="off", simulation_speed=1, task_seconds=None, reversal_review="off"):
    if reversal_review not in ("off","disabled","enabled") or (reversal_review != "off" and task_seconds is None):
        raise ValueError("review requires explicit task deadline")
    if task_seconds is not None and (task_seconds not in (16,32,64) or periods != 1 or reassessment == "off"):
        raise ValueError("task deadline requires one reassessment task")
    if not 1 <= simulation_speed <= 16:
        raise ValueError("simulation speed out of range")
    if reassessment not in ("off","disabled","enabled") or (reassessment!="off" and reactivation=="off"):
        raise ValueError("reassessment requires reactivation")
    if obstacle_probe not in ("off","persistent","removed") or (obstacle_probe!="off" and reactivation=="off"):
        raise ValueError("obstacle probe requires reactivation mode")
    if reactivation!="off" and (reactivation not in ("disabled","enabled") or rest=="off"):
        raise ValueError("reactivation requires rest")
    if rest != "off":
        if rest not in ("disabled","fatigue","repetition","combined") or not steering or lateral!="off" or tie_break!="off":
            raise ValueError("rest requires isolated steering")
    if tie_break not in ("off", "disabled", "frozen") or (tie_break != "off" and (steering or lateral != "off")):
        raise ValueError("tie break only mode")
    if lateral not in ("off","neutral","mixed","swapped","left","right") or (lateral != "off" and steering):
        raise ValueError("lateral bias only mode")
    run_id="l14b-"+uuid4().hex[:16]
    if terrain:
        from runtime.terrain_resource_exploration import TerrainResourceExploration
    loop_type=TerrainResourceExploration if terrain else MultiResourceExploration
    if steering:
        from runtime.terrain_steering import SteeredResourceExploration
        loop_type=SteeredResourceExploration
    if lateral != "off":
        from runtime.terrain_lateral_bias import LateralResourceExploration
        loop_type=LateralResourceExploration
    if tie_break != "off":
        from runtime.terrain_tie_break import TieBreakResourceExploration
        loop_type=TieBreakResourceExploration
    if rest != "off":
        from runtime.movement_rest import RestResourceExploration
        loop_type=RestResourceExploration
    if reactivation!="off":
        from runtime.rest_reactivation import ReactivatingExploration
        loop_type=ReactivatingExploration
    if reassessment!="off":
        from runtime.goal_reassessment import ReassessingExploration
        loop_type=ReassessingExploration
    if task_seconds is not None:
        from runtime.exploration_deadline import deadline_loop
        loop_type=deadline_loop(task_seconds)
    if reversal_review != "off":
        from runtime.reversal_review_loop import review_loop
        loop_type=review_loop(task_seconds)
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
            "-ResourceAssignment",assignment,"-SimulationSpeed",str(simulation_speed)]
        if task_seconds is not None:command += ["-TaskSeconds",str(task_seconds)]
        if reversal_review != "off":command += ["-ReversalReviewMode",reversal_review]
        if control:command.append("-ResourceControl")
        if faults:command.append("-ResourceFaults")
        if terrain:command.append("-MovementTerrain")
        if steering:command.append("-MovementSteering")
        if rest != "off":command += ["-RestMode",rest]
        if reassessment!="off":command += ["-ReassessmentMode",reassessment]
        if obstacle_probe!="off":command += ["-ObstacleProbe",obstacle_probe]
        if reactivation!="off":command += ["-ReactivationMode",reactivation]
        if lateral != "off":command += ["-LateralAssignment",lateral]
        if tie_break != "off":command += ["-TieBreakMode",tie_break]
        with log.open("wb") as stream:
            result=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=periods*(task_seconds or 16)+80)
        if result.returncode:raise RuntimeError(f"World failed: {log}")
        path=OUTPUT/(run_id+".snapshot.json");raw=path.read_bytes();data=json.loads(raw.decode("utf-8-sig"))
        assert data["runtime"]["exploration"]==loop.snapshot()
        if reassessment!="off":
            from .check_goal_reassessment import check
        elif reactivation!="off":
            from .check_rest_reactivation import check
        elif rest != "off":
            from .check_movement_rest import check
        elif tie_break != "off":
            from .check_terrain_tie_break import check
        elif lateral != "off":
            from .check_terrain_lateral import check
        elif steering:
            from .check_terrain_steering import check
        elif terrain:
            from .check_terrain_resource import check
        else:
            from .check_multi_resource import check
        summary=check(data,loop_type) if task_seconds is not None else check(data)
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
