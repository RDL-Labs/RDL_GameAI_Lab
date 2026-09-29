"""Summarize observer diagnostics; optionally replay delivered responses."""
import argparse
import hashlib
import json
import lzma
from pathlib import Path


def analyze(path, replay=False):
    with lzma.open(path, "rt", encoding="utf8") as stream:
        report=json.load(stream)
    run=report["runs"][0]; w=run["data"]["world"]; s=run["data"]["runtime"]["exploration"]
    d=report["diagnostics"]; wd=d["world"]
    assert len(wd["recent"] or [])<=128 and len(wd["slow"] or [])<=128 and len(wd["days"])<=32
    assert len(d["runtime"]["slow"])<=128 and len(d["runtime"]["stats"])<=128
    assert wd["phase"]=="after_export" and wd["sim_us"]==w["finished_us"]
    days=[]
    for key,day in sorted(wd["days"].items(),key=lambda pair:int(pair[0])):
        days.append(dict(day=int(key),steps=day["steps"],max_dt_us=day["max_dt_us"],
            max_work_us=day["max_work_us"],max_gap_us=day["max_gap_us"],last_heap_kib=day.get("last_heap_kib"),
            phases=day["phases"]))
    agents={}; pending_receipts={}
    for aid,a in w["agents"].items():
        deliveries=[e for e in w["deliveries"] if e["request"]["agent_id"]==aid]
        received_observations={e["request"]["observation_id"] for e in deliveries if e["kind"]=="observe"}
        received_results={e["request"]["operation_id"] for e in deliveries if e["kind"]=="result"}
        pending_receipts[aid]=dict(
            accepted_observations_without_received_reply=sorted(set(s["agents"][aid]["observations"])-received_observations),
            accepted_results_without_received_reply=sorted(set(s["agents"][aid]["results"])-received_results))
        agents[aid]=dict(max_pending=a["max_pending"],world_observations=len(a["observations"]),
            runtime_observations=len(s["agents"][aid]["observations"]),
            pickups=sum(e["agent_id"]==aid for e in (w["stock_events"] or [])),
            last_deliveries=[{k:e.get(k) for k in ("kind","sent_us","arrived_us","received_us")} for e in deliveries[-8:]])
    result=dict(schema="campaign-timing-audit-v1",run_id=w["run_id"],source=str(path),
        source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),failure=w.get("failure"),
        finished_us=w["finished_us"],days=days,export_us=wd["export_us"],
        final_heap_kib=wd["lua_heap_kib"],last_flush_us=wd.get("last_flush_us"),
        final_entries=wd["recent"][-8:],runtime=d["runtime"],agents=agents,
        returns=len(w["return_campaign"]["events"] or []),
        source_matches={k:hashlib.sha256(Path(k).read_bytes()).hexdigest()==v for k,v in report["source_sha256"].items()},
        accepted_without_received_reply=pending_receipts, replay_verified=False)
    if replay:
        from runtime.landmark_return_campaign import ReturnCampaign
        loop=ReturnCampaign(w["run_id"],s["periods"],mb_field_mode=s["mb_field_mode"],harvest_state=True,agent_count=s.get("agent_count",3))
        for i,entry in enumerate(w["deliveries"]):
            assert getattr(loop,entry["kind"])(entry["request"])==json.loads(entry["response_wire"]),(i,entry["kind"])
        result["replay_verified"]=True
        result["replayed_responses"]=len(w["deliveries"])
        actual=loop.snapshot()
        result["final_runtime_exact"]=actual==s
        result["replay_observations"]={aid:len(a["observations"]) for aid,a in actual["agents"].items()}
        # Received response history may stop before already in-flight calls settle.
        # Do not silently replace the actual final Runtime with the replay prefix.
    return result


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("path",type=Path);p.add_argument("--replay",action="store_true");p.add_argument("--output",type=Path,required=True)
    a=p.parse_args();r=analyze(a.path,a.replay);a.output.write_text(json.dumps(r,indent=2)+"\n",encoding="utf8")
    print(json.dumps({k:v for k,v in r.items() if k not in ("days","runtime","agents","final_entries","source_matches")}))
