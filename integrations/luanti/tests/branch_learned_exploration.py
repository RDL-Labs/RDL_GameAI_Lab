"""Fork the same accepted formation/validation history; only cutover differs."""
from copy import deepcopy
import hashlib
import json
from http.server import ThreadingHTTPServer
from pathlib import Path
import shutil
import subprocess
from threading import Thread
from uuid import uuid4

from runtime.learned_exploration import LearnedExplorationSeries, LearnedExplorationDay
from runtime.learned_exploration_http import LearnedExplorationHandler
from runtime.exploration_series import digest
from .run_exploration_series import write, ROOT, OUTPUT
from .check_exploration_series import read_artifact, reset_signature
from .check_learned_exploration import check_series


def fork(source):
    c=source["config"]
    s=LearnedExplorationSeries(c["series_id"],"inspect",c["seed"],c["max_days"])
    a=dict(schema="l13s-real-series-v1",config=s.config,scenario=source["scenario"],days=[])
    for d in source["days"]:
        start=s.start_day(d["start"]["request"])
        for wire in d["data"]["world"]["deliveries"]:
            actual=getattr(s.loop,wire["kind"])(wire["request"])
            assert actual==json.loads(wire["response_wire"])
        assert s.loop.snapshot()==d["data"]["runtime"]["exploration"]
        receipt=s.close_day(dict(**start["request"],state_digest=digest(s.loop.snapshot())))
        a["days"].append(dict(deepcopy(d),start=start,receipt=receipt,summary=s.summary()))
        if s.inspection:
            assert s.inspection["disposition"]=="RETAIN"
            break
    assert s.learning and s.learning["cutover"] is None
    a["replayed_prefix_days"]=len(a["days"])
    a["state"]=s.snapshot()
    return s,a


def compare(source, branch):
    n=branch["replayed_prefix_days"]
    assert source["days"][:n] and len(branch["days"])>n
    for x,y in zip(source["days"][:n],branch["days"][:n]):
        assert x["data"]==y["data"],"prefix World/agent records must be literally identical"
        assert x["receipt"]==y["receipt"]
    assert source["state"]["candidate"]==branch["state"]["candidate"]
    assert source["state"]["inspection"]==branch["state"]["inspection"]
    assert source["state"]["learning"]["artifact"]==branch["state"]["learning"]["artifact"]
    x,y=source["days"][n],branch["days"][n]
    assert reset_signature(x["data"])==reset_signature(y["data"])
    xs,ys=[d["data"]["runtime"]["exploration"] for d in (x,y)]
    assert xs["tape"]==ys["tape"] and xs["seed"]==ys["seed"]
    # Exact-input counterfactual, separate from the actual distinct World run.
    s,_=fork(source)
    model=s.canonical.model_for_agent("npc_a")
    shadow=LearnedExplorationDay(xs["config"]["run_id"],xs["series_id"],xs["day"],xs["seed"],model)
    shadow.configure(xs["config"])
    p=next(iter(xs["observations"].values()))
    shadow.observe(p)
    active=next(iter(xs["decisions"].values()));inactive=next(iter(shadow.decisions.values()))
    assert active["reason"]=="active_M_B" and inactive["prediction"]["status"]=="unknown"
    assert active["action"]!=inactive["action"]
    assert inactive["action"]==next(iter(ys["decisions"].values()))["action"]
    return dict(shared_history_days=n, shared_experience_ids=[d["receipt"]["experience"]["record_id"] for d in source["days"][:n]],
        first_compared_day=n+1, exact_input=p["observation_id"], active_action=active["action"],
        inactive_action=inactive["action"], active_model_ref=active["prediction"]["model_ref"],
        inactive_model_ref=inactive["prediction"]["model_ref"], actual_world_branches=True,
        source_discoveries=source["state"]["summary"]["discoveries"], branch_discoveries=branch["state"]["summary"]["discoveries"])


def main():
    import argparse
    p=argparse.ArgumentParser();p.add_argument("source",type=Path);p.add_argument("output",type=Path)
    args=p.parse_args()
    matrix=read_artifact(args.source)
    source=next(s for s in matrix["series"] if s["config"]["mode"]=="adopt")
    s,a=fork(source)
    shell=shutil.which("pwsh") or shutil.which("powershell")
    while s.summary()["status"]=="running":
        run="l13s-"+uuid4().hex[:16]
        start=s.start_day(dict(run_id=run,episode_id="episode-"+uuid4().hex[:16]))
        a["pending"]=start;write(args.output,a)
        server=ThreadingHTTPServer(("127.0.0.1",8765),LearnedExplorationHandler);server.series=s
        thread=Thread(target=server.serve_forever,daemon=True);thread.start()
        log=OUTPUT/(run+".launch.log")
        try:
            with log.open("wb") as stream:
                result=subprocess.run([shell,"-NoProfile","-ExecutionPolicy","Bypass","-File",
                    str(ROOT/"integrations/luanti/scripts/test-learned-exploration-day.ps1"),
                    "-Scenario",source["scenario"],"-RunId",run],cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=75)
            if result.returncode:raise RuntimeError(str(log))
        finally:
            server.shutdown();server.server_close();thread.join()
        raw=(OUTPUT/(run+".snapshot.json")).read_bytes();data=json.loads(raw.decode("utf-8-sig"))
        receipt=s.close_day(dict(**start["request"],state_digest=digest(s.loop.snapshot())))
        a["days"].append(dict(start=start,receipt=receipt,summary=s.summary(),data=data,
            source=dict(file=run+".snapshot.json",sha256=hashlib.sha256(raw).hexdigest())))
        a.pop("pending",None);a["state"]=s.snapshot();write(args.output,a)
        print(f"L13S shared-history inactive day {start['day']}: {s.summary()['discovery_count']}/3",flush=True)
    check_series(a)
    a["comparison"]=compare(source,a);write(args.output,a)
    print(json.dumps(a["comparison"],indent=2),flush=True)

if __name__=="__main__":main()
