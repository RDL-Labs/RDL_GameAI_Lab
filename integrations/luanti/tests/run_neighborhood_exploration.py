"""L13V natural series and a same-history, same-sampler cutover comparison."""
from copy import deepcopy
import argparse
import hashlib
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import subprocess
from threading import Thread
from uuid import uuid4

from runtime.neighborhood_exploration import NeighborhoodExplorationSeries, RELATION
from runtime.learned_exploration import observation_key
from runtime.learned_exploration_http import LearnedExplorationHandler
from runtime.exploration_series import digest
from .run_learned_exploration import run_series
from .run_exploration_series import ROOT, OUTPUT, write
from .check_exploration_series import reset_signature
from .check_learned_exploration import check_series


def fork_prefix(source, mode):
    c = source["config"]
    s = NeighborhoodExplorationSeries(c["series_id"],mode,c["seed"],c["max_days"])
    a = dict(schema="l13v-revisit-series-v1",config=s.config,scenario=source["scenario"],days=[],explicit_revisit_experiment=True)
    for d in source["days"]:
        start = s.start_day(d["start"]["request"])
        for wire in d["data"]["world"]["deliveries"]:
            assert getattr(s.loop,wire["kind"])(wire["request"]) == json.loads(wire["response_wire"])
        receipt = s.close_day(dict(**start["request"],state_digest=digest(s.loop.snapshot())))
        a["days"].append(dict(deepcopy(d),start=start,receipt=receipt,summary=s.summary()))
        if s.inspection: break
    require = s.inspection and s.inspection["disposition"] == "RETAIN" and s.learning and s.learning.get("artifact")
    if not require: raise ValueError("no retained no-discovery relation with reconstructed model")
    assert s.candidate["common_relation_signature"]["kind"] == RELATION
    a["replayed_prefix_days"] = len(a["days"])
    a["state"] = s.snapshot()
    return s,a


def revisit(source, mode, luanti_root):
    s,a = fork_prefix(source,mode)
    run = "l13v-revisit-"+uuid4().hex[:12]
    seed = s.candidate["common_relation_signature"]["formation_seed"]
    start = s.start_revisit_day(dict(episode_id="episode-"+uuid4().hex[:16],run_id=run),seed)
    path = OUTPUT/(run+".series.json.gz")
    a.update(pending=start);write(path,a)
    server = ThreadingHTTPServer(("127.0.0.1",8765),LearnedExplorationHandler);server.series=s
    thread = Thread(target=server.serve_forever,daemon=True);thread.start()
    shell = shutil.which("pwsh") or shutil.which("powershell")
    log = OUTPUT/(run+".launch.log")
    try:
        with log.open("wb") as stream:
            result = subprocess.run([shell,"-NoProfile","-ExecutionPolicy","Bypass","-File",
                str(ROOT/"integrations/luanti/scripts/test-learned-exploration-day.ps1"),"-Scenario",source["scenario"],
                "-RunId",run,"-LuantiRoot",luanti_root,"-Neighborhood"],cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=75)
        if result.returncode: raise RuntimeError(str(log))
    finally:
        server.shutdown();server.server_close();thread.join()
    raw = (OUTPUT/(run+".snapshot.json")).read_bytes();data=json.loads(raw.decode("utf-8-sig"))
    receipt = s.close_day(dict(**start["request"],state_digest=digest(s.loop.snapshot())))
    a["days"].append(dict(start=start,receipt=receipt,summary=s.summary(),data=data,
        source=dict(file=run+".snapshot.json",sha256=hashlib.sha256(raw).hexdigest())))
    a.pop("pending");a["state"]=s.snapshot();write(path,a)
    check_series(a)
    return a


def compare(active, inactive):
    n=active["replayed_prefix_days"]
    assert n==inactive["replayed_prefix_days"]
    for a,b in zip(active["days"][:n],inactive["days"][:n]):
        assert a["data"]==b["data"] and a["receipt"]==b["receipt"]
    assert active["state"]["candidate"]==inactive["state"]["candidate"]
    assert active["state"]["inspection"]==inactive["state"]["inspection"]
    assert active["state"]["learning"]["artifact"]==inactive["state"]["learning"]["artifact"]
    a,b=active["days"][-1]["data"],inactive["days"][-1]["data"]
    assert reset_signature(a)==reset_signature(b)
    x,y=a["runtime"]["exploration"],b["runtime"]["exploration"]
    assert x["seed"]==y["seed"]
    from math import dist, degrees
    for index,(oa,ob) in enumerate(zip(a["world"]["observations"],b["world"]["observations"])):
        da=x["decisions"][oa["packet"]["observation_id"]];db=y["decisions"][ob["packet"]["observation_id"]]
        assert observation_key(oa["packet"])==observation_key(ob["packet"])
        assert dist([oa["body"]["position"][k] for k in "xyz"],[ob["body"]["position"][k] for k in "xyz"]) < .001
        assert abs((degrees(oa["body"]["yaw"]-ob["body"]["yaw"])+180)%360-180) < .01
        if da["action"]!=db["action"]:
            assert da["reason"]=="neighborhood_active_M_B_no_food" and db["reason"]=="neighborhood_survey"
            aa=a["world"]["actions"][index];bb=b["world"]["actions"][index]
            assert aa["result"]["status"]=="waited" and bb["result"]["status"]=="turned"
            return dict(shared_history_days=n, first_difference_sample=oa["packet"]["sample_seq"],
                same_acquisition_conditions=True,same_sampler_seed=x["seed"],active_action=da["action"],inactive_action=db["action"],
                active_prediction=da["neighborhood"]["prediction"],inactive_prediction=db["neighborhood"]["prediction"],
                active_result=aa["result"],inactive_result=bb["result"],
                limitation="explicit same-sampler reentry experiment; not autonomous place recognition or return")
    return dict(shared_history_days=n,result="no_matched_action_difference")


def main():
    p=argparse.ArgumentParser();p.add_argument("--output",type=Path,required=True);p.add_argument("--luanti-root",default=r"D:\luanti")
    args=p.parse_args();OUTPUT.mkdir(parents=True,exist_ok=True)
    files=[str(f.relative_to(ROOT)).replace("\\","/") for pattern in
        ("runtime/*exploration*.py","integrations/luanti/tests/*exploration*.py","integrations/luanti/game/rdl_game/mods/rdl_bridge/exploration*.lua") for f in ROOT.glob(pattern)]
    files += ["runtime/v23_interpretation.py","integrations/luanti/scripts/test-learned-exploration-day.ps1"]
    a=dict(schema="l13v-neighborhood-matrix-v1",series=[],revisit_branches=[],provenance=dict(
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        source_sha256={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in sorted(set(files))},
        predeclared=dict(layouts=["natural_meadow","natural_woodland"],seed=20260927,max_days=30,discovery_target=3,
                         mode="adopt",revisit="first retained no-discovery candidate per layout; two same-history branches")))
    write(args.output,a)
    for scenario in a["provenance"]["predeclared"]["layouts"]:
        source=run_series(scenario,"adopt",20260927,30,args.luanti_root,neighborhood=True)
        a["series"].append(source);write(args.output,a)
        state=source["state"]
        if (state["candidate"] and state["candidate"]["common_relation_signature"]["kind"]==RELATION
                and state["learning"] and state["learning"].get("artifact")
                and next(d["start"]["day"] for d in source["days"] if d["receipt"]["sleep"]["inspection"])<30):
            active=revisit(source,"adopt",args.luanti_root);inactive=revisit(source,"inspect",args.luanti_root)
            a["revisit_branches"].append(dict(scenario=scenario,active=active,inactive=inactive,comparison=compare(active,inactive)))
            write(args.output,a)
    print(f"L13V MATRIX: {args.output}",flush=True)


if __name__=="__main__":main()
