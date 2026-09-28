"""Offline exploratory diagnostics; no Runtime hook or action authority.

Use only records available at each accepted observe request. World coordinates
are joined afterwards as an observer audit, never used by diagnose_window.
"""
import argparse
from collections import Counter
import gzip
import hashlib
import json
from math import cos, sin, radians, degrees, sqrt
from pathlib import Path

from runtime.learned_exploration import observation_key
from runtime.resource_exploration import PERIOD_US
from runtime.terrain_resource_exploration import TerrainResourceExploration
from runtime.terrain_steering import SteeredResourceExploration
from runtime.terrain_tie_break import TieBreakResourceExploration
from .run_exploration_series import ROOT, write

WINDOW_OPERATIONS = 8
WINDOW_US = 2250000
RETURN_DISTANCE = .25
RETURN_YAW = 5.
SCHEMA = "l15a-movement-history-diagnostic-v1"


def wrap(value):
    return (value+180)%360-180


def view_key(p):
    key=observation_key(p)
    s=p["movement_surface"]
    if (key is None or any(s[k]["coverage"]!="complete" or s[k]["output_limited"] for k in ("ground","obstacles"))
            or any(r["status"]=="unavailable" for r in s["ground"]["samples"])):
        return None
    # Existing coarse visual key, plus rounded current Food appearance/range.
    # References, exact World identity and absolute coordinates are not keys.
    key["food_appearance_range"]=sorted((x["appearance"],round(x["distance"])) for x in p["food"]["visible"])
    return key


def diagnose_window(records):
    """At most nine acquired views, linked by eight already received results."""
    if not 1<=len(records)<=WINDOW_OPERATIONS+1:
        raise ValueError("history_budget")
    views=[r["observation"] for r in records]
    end=views[-1]
    if len({(p["run_id"],p["agent_id"],p["world_epoch"],p["clock_id"]) for p in views})!=1:
        raise ValueError("history_binding")
    if len({p["observation_id"] for p in views})!=len(views):
        raise ValueError("duplicate_observation")
    out=dict(source_id=end["observation_id"],capture_us=end["capture_us"],
        sources=[p["observation_id"] for p in views],operations=[],
        status="insufficient_history",reasons=[],local_motion=None,same_coarse_view=None,
        purpose_gate="unresolved",repetition_eligible=False)
    if len(records)<3:
        return out
    reasons=[]
    if end["capture_us"]-views[0]["capture_us"]>WINDOW_US:reasons.append("history_expired")
    if views[0]["capture_us"]//PERIOD_US!=end["capture_us"]//PERIOD_US:reasons.append("period_boundary")
    keys=[view_key(p) for p in views]
    if any(k is None for k in keys):reasons.append("acquisition_incomplete")
    results=[]
    for record,later in zip(records,views[1:]):
        p,c,r=record["observation"],record["command"],record["result"]
        if later["sample_seq"]!=p["sample_seq"]+1 or later["capture_us"]<=p["capture_us"]:
            reasons.append("observation_gap")
        if r is None:
            reasons.append("result_unavailable_at_decision");continue
        out["operations"].append(r["operation_id"])
        identity=all(r[k]==p[k] for k in ("run_id","agent_id","world_epoch"))
        bound=(c is not None and c["source_id"]==p["observation_id"] and c["operation_id"]==r["operation_id"]
            and r["source_id"]==p["observation_id"] and identity
            and r["before_pose_ref"]==p["pose_ref"] and r["before_revision"]==p["body_revision"]
            and r["after_pose_ref"]==later["pose_ref"] and r["after_revision"]==later["body_revision"]
            and p["capture_us"]<=r["executed_us"]<later["capture_us"])
        if not bound:reasons.append("body_chain_unavailable")
        if r["status"] in ("expired","stale","stopped"):reasons.append("unexecuted_operation")
        results.append(r)
    if reasons:
        out.update(status="unknown",reasons=sorted(set(reasons)))
        return out
    x=z=up=yaw=path=0.
    reversals=0;last_turn=None
    for r in results:
        theta=radians(yaw)
        x+=r["forward"]*sin(theta)+r["right"]*cos(theta)
        z+=r["forward"]*cos(theta)-r["right"]*sin(theta)
        up+=r["up"]
        path+=sqrt(r["forward"]**2+r["right"]**2+r["up"]**2)
        yaw=wrap(yaw+r["yaw"])
        if r["status"]=="turned":
            reversals+=int(last_turn is not None and last_turn*r["yaw"]<0)
            last_turn=r["yaw"]
        else:last_turn=None
    net=sqrt(x*x+z*z+up*up)
    same=keys[0]==keys[-1]
    returned=net<=RETURN_DISTANCE and abs(yaw)<=RETURN_YAW
    acquired=sum(r["acquired"] for r in results)
    if acquired:status="acquisition_progress"
    elif returned and same and path>=2:status="movement_return_candidate"
    elif returned and same and reversals and path<.001:status="stationary_reversal_candidate"
    elif path<.001:status="stationary_other"
    else:status="translated_or_view_changed"
    out.update(status=status,same_coarse_view=same,local_motion=dict(right=x,forward=z,up=up,
        net_distance=net,path_distance=path,yaw=yaw,consecutive_reversals=reversals,acquisitions=acquired))
    decisions=[r.get("decision") for r in records]
    reasons=[r["command"]["reason"] for r in records[:-1]]
    approaches=[d.get("approach") if d else None for d in decisions]
    if acquired:gate="acquisition_progress"
    elif "neighborhood_survey" in reasons:gate="planned_survey"
    elif (not all(x.startswith("observed_material_") for x in reasons)
          or not all(approaches) or len({a["ref"] for a in approaches if a})!=1):
        gate="purpose_not_stable_food_approach"
    else:
        target=approaches[0]["ref"]
        endpoints=[[x for x in p["food"]["visible"] if x["ref"]==target] for p in (views[0],end)]
        if any(len(x)!=1 for x in endpoints):gate="target_range_unavailable"
        elif endpoints[0][0]["distance"]-endpoints[1][0]["distance"]>.25:gate="observed_range_progress"
        else:gate="stable_food_approach"
    out["purpose_gate"]=gate
    out["repetition_eligible"]=gate=="stable_food_approach" and status in (
        "stationary_reversal_candidate","movement_return_candidate")
    return out


def analyze(data):
    state=data["runtime"]["exploration"]
    types={t.schema:t for t in (TerrainResourceExploration,SteeredResourceExploration,TieBreakResourceExploration)}
    loop=types[state["schema"]](state["run_id"],state["periods"],state["seed"],state["assignment"])
    windows={aid:[] for aid in loop.agents};duplicates=0
    for delivery in data["world"]["deliveries"]:
        name,p=delivery["kind"],delivery["request"]
        agent=loop.agents[p["agent_id"]]
        fresh=name=="observe" and p["observation_id"] not in agent.observations
        if fresh:
            history=list(agent.observations.values())[-WINDOW_OPERATIONS:]
            records=[dict(observation=o,command=agent.commands[o["observation_id"]],decision=agent.decisions[o["observation_id"]],
                          result=agent.results.get("op:"+o["observation_id"])) for o in history]
            records.append(dict(observation=p,command=None,result=None,decision=None))
        elif name=="observe":duplicates+=1
        assert getattr(loop,name)(p)==json.loads(delivery["response_wire"])
        if fresh:
            records[-1]["decision"]=agent.decisions[p["observation_id"]]
            windows[p["agent_id"]].append(diagnose_window(records))
    assert loop.snapshot()==state,"diagnostic replay changed the accepted state"
    # Independent observer comparison after every agent diagnostic is frozen.
    for aid,rows in windows.items():
        bodies={r["packet"]["observation_id"]:r["body"] for r in data["world"]["agents"][aid]["observations"]}
        for row in rows:
            row["world_audit"]=None
            if row["local_motion"] is None:continue
            first,last=[bodies[row["sources"][i]] for i in (0,-1)]
            a,b=first["position"],last["position"];dx,dy,dz=b["x"]-a["x"],b["y"]-a["y"],b["z"]-a["z"]
            y=first["yaw"]
            audit=dict(right=dx*cos(y)+dz*sin(y),forward=-dx*sin(y)+dz*cos(y),up=dy,
                       yaw=wrap(-degrees(last["yaw"]-first["yaw"])))
            assert all(abs(row["local_motion"][k]-audit[k])<.01 for k in audit),(aid,row["source_id"],audit)
            row["world_audit"]=audit
    return dict(run_id=state["run_id"],runtime_schema=state["schema"],scenario=data["world"]["scenario"],
        duplicate_observe_deliveries_ignored=duplicates,windows=windows,
        counts={aid:dict(Counter(r["status"] for r in rows)) for aid,rows in windows.items()},
        purpose_counts={aid:dict(Counter(r["purpose_gate"] for r in rows)) for aid,rows in windows.items()},
        repetition_eligible_counts={aid:sum(r["repetition_eligible"] for r in rows) for aid,rows in windows.items()},
        unknown_reasons={aid:dict(Counter(reason for r in rows for reason in r["reasons"])) for aid,rows in windows.items()})


def main():
    parser=argparse.ArgumentParser();parser.add_argument("--output",type=Path,required=True);args=parser.parse_args()
    paths=[ROOT/"tests/fixtures"/name for name in ("luanti_l15a_steering_replay.json.gz","luanti_l15a_tie_break_replay.json.gz")]
    report=dict(schema=SCHEMA,authority="offline diagnostic only",parameters=dict(window_operations=WINDOW_OPERATIONS,
        window_us=WINDOW_US,return_distance=RETURN_DISTANCE,return_yaw=RETURN_YAW),
        provenance=dict(inputs={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
            analyzer_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()),runs=[])
    for path in paths:
        matrix=json.loads(gzip.decompress(path.read_bytes()))
        for run in matrix["runs"]:
            result=analyze(run["data"]);report["runs"].append(result)
            print(json.dumps({k:v for k,v in result.items() if k!="windows"}),flush=True)
    args.output.parent.mkdir(parents=True,exist_ok=True);write(args.output,report)


if __name__=="__main__":main()
