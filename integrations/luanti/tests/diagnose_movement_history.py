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
from .check_multi_resource import first_difference

from runtime.movement_recurrence import (
    WINDOW_OPERATIONS, WINDOW_US, RETURN_DISTANCE, RETURN_YAW, SCHEMA, wrap, view_key, diagnose_window,
)


def analyze(data, diagnostic=diagnose_window):
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
            windows[p["agent_id"]].append(diagnostic(records))
    difference=first_difference(loop.snapshot(),state)
    assert difference is None, "diagnostic replay changed the accepted state: "+str(difference)
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
