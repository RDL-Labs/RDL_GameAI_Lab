"""Measured movement/oscillation metrics, plus exact accepted-wire replay."""
from collections import Counter
import json

from runtime.terrain_steering import SteeredResourceExploration
from runtime.terrain_resource_exploration import terrain_input
from runtime.subjective_movement_terrain import calculate_terrain
from .check_terrain_resource import check as check_terrain
from .check_multi_resource import first_difference


def movement_metrics(data):
    metrics={}
    for agent,a in data["world"]["agents"].items():
        previous=None;streak=0;maximum=0;reversals=0
        counts=Counter()
        for action in a["actions"]:
            c,r=action["command"],action["result"]
            owned=c["reason"].startswith("observed_material_") and c["kind"] in ("turn","move","wait")
            if owned:counts[r["status"]]+=1
            if owned and r["status"]=="turned":
                streak+=1;maximum=max(maximum,streak)
                if previous and previous["command"]["amount"]*c["amount"]<0:
                    assert previous["before"]["position"]==action["after"]["position"]
                    reversals+=1
                previous=action
            else:previous=None;streak=0
        metrics[agent]=dict(food_locomotion_results=dict(counts),
            consecutive_reversals=reversals,max_consecutive_food_turns=maximum)
    return metrics


def check(data):
    summary=check_terrain(data,SteeredResourceExploration)
    summary["movement"]=movement_metrics(data)
    if data["world"]["faults"]:
        loss=data["world"]["guards"]["lost_turn"]
        deliveries=[d for d in data["world"]["deliveries"] if d["kind"]=="observe"
                    and d["request"]["observation_id"]==loss["source_id"]]
        assert len(deliveries)==2 and deliveries[0]["request"]==deliveries[1]["request"]
        first,repeat=[json.loads(d["response_wire"]) for d in deliveries]
        assert first["command"]==repeat["command"] and repeat["new_observations"]==repeat["new_frames"]==0
        command=first["command"]
        assert command["kind"]=="turn" and command["operation_id"]==loss["operation_id"]
        actions=[a for a in data["world"]["agents"][loss["agent_id"]]["actions"]
                 if a["command"]["operation_id"]==loss["operation_id"]]
        assert len(actions)==1 and actions[0]["result"]["status"]=="turned"
    for a in data["runtime"]["exploration"]["agents"].values():
        for source,d in a["decisions"].items():
            meta=d["steering"]
            if meta["current_recheck"] is not None:
                assert d["movement_terrain"] is None
                calculated=calculate_terrain(terrain_input(
                    a["observations"][source],a["teaching"]["appearance"],meta["input_blocked_targets"]))
                difference=first_difference(meta["current_recheck"],calculated,
                    f'$/agents/agent/decisions/{source}/steering/current_recheck')
                assert difference is None, difference
            if d["reason"].endswith("confirmed_turn_step"):
                assert all(meta["step_recheck"]["checks"].values()) and meta["previous_operation"]
                assert a["results"][meta["previous_operation"]]["status"]=="turned"
            if meta["stopped_targets"]:
                assert d["action"]==["wait",0] and d["approach"] is None
                assert set(meta["stopped_targets"]) <= set(d["blocked_targets"])
                assert d["movement_terrain"] is None or d["movement_terrain"]["status"]=="complete"
    return summary
