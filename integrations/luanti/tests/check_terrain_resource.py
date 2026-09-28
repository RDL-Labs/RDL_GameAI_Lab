"""Replay the opt-in L14B connection and audit finite rays independently."""
from collections import Counter
from math import cos, sin, isclose

from runtime.terrain_resource_exploration import TerrainResourceExploration, terrain_input, terrain_action
from runtime.subjective_movement_terrain import calculate_terrain
from .check_multi_resource import check as check_multi


def check(data):
    summary=check_multi(data, TerrainResourceExploration)
    world,state=data["world"],data["runtime"]["exploration"]
    assert world["surface_checks"]>=19
    for agent,a in state["agents"].items():
        counts=Counter();effects=Counter()
        for record in world["agents"][agent]["observations"]:
            p=record["packet"];surface=p["movement_surface"];audit=record["movement_surface_audit"]
            assert len(audit["ground"])==5 and len(audit["obstacles"])==8 and audit["reads"]<=547
            assert audit["reads"]==sum(r["reads"] for k in ("ground","obstacles") for r in audit[k])
            assert all(1<=r["reads"]<=31 for r in audit["ground"])
            assert all(1<=r["reads"]<=49 for r in audit["obstacles"])
            b=record["body"]
            for row,ray in zip(surface["ground"]["samples"],audit["ground"]):
                assert row["direction_deg"]==ray["angle"] and row["status"]==ray["status"]
                if row["status"]=="sampled":
                    from math import floor
                    assert isclose(row["height_delta"],floor(ray["hit"]["y"]+.5)+1-b["position"]["y"],abs_tol=1e-6)
                else:assert row["height_delta"] is None
            hits=[(index,r) for index,r in enumerate(audit["obstacles"],1) if r["status"]=="hit"]
            assert len(hits)==len(surface["obstacles"]["items"])
            for item,(index,ray) in zip(surface["obstacles"]["items"],hits):
                dx=ray["hit"]["x"]-ray["start"]["x"];dz=ray["hit"]["z"]-ray["start"]["z"]
                assert item["ref"]==p["observation_id"]+":ray:"+str(index)
                assert isclose(item["forward"],max(0,-sin(b["yaw"])*dx+cos(b["yaw"])*dz),abs_tol=1e-5)
                assert isclose(item["right"],cos(b["yaw"])*dx+sin(b["yaw"])*dz,abs_tol=1e-5)
            d=a["decisions"][p["observation_id"]]
            if d["movement_terrain"] is not None:
                calculated=calculate_terrain(terrain_input(p,a["teaching"]["appearance"],d["blocked_targets"]))
                assert d["movement_terrain"]==calculated
                action,reason=terrain_action(calculated)
                assert d["action"]==action and d["reason"]=="observed_material_terrain_"+reason
                counts[reason]+=1
                effects[a["results"]["op:"+p["observation_id"]]["status"]]+=1
        summary["agents"][agent]["terrain_decisions"]=dict(counts)
        summary["agents"][agent]["terrain_results"]=dict(effects)
    summary["surface_checks"]=world["surface_checks"]
    return summary
