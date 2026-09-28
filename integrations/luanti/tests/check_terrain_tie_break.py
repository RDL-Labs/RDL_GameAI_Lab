"""Exact wire replay, current-ray audit and separate World-side dwell metrics."""
from collections import Counter
import json
from math import dist, floor

from runtime.terrain_tie_break import TieBreakResourceExploration, calculate_tie_break
from runtime.terrain_resource_exploration import terrain_input
from .check_terrain_resource import check as check_terrain
from .check_terrain_steering import movement_metrics


def dwell_metrics(agent, end_us):
    """World readbacks only; not fed to the agent. No task-progress inference."""
    def xyz(p):return (p["x"],p["y"],p["z"])
    def cell(p):return (floor(p["x"]/2),floor(p["z"]/2))
    current_cell=cell(agent["initial_body"]["position"])
    visited={current_cell};cell_start=last_translation=0
    cell_max=gap_max=translations=0;stationary=Counter()
    for a in agent["actions"]:
        before,after=a["before"]["position"],a["after"]["position"]
        # Drain may report expired commands after the finite World horizon.
        time=min(a["result"]["executed_us"],end_us)
        if dist(xyz(before),xyz(after))>1e-6:
            translations+=1;gap_max=max(gap_max,time-last_translation);last_translation=time
        else:stationary[a["result"]["status"]]+=1
        next_cell=cell(after);visited.add(next_cell)
        if next_cell!=current_cell:
            cell_max=max(cell_max,time-cell_start);cell_start=time;current_cell=next_cell
    return dict(translation_events=translations,nontranslating_actions_by_status=dict(stationary),
        max_gap_between_translations_us=max(gap_max,end_us-last_translation),
        max_two_node_cell_dwell_us=max(cell_max,end_us-cell_start),
        visited_two_node_cells=len(visited),final_position=agent["final_body"]["position"])


def check(data):
    summary=check_terrain(data,TieBreakResourceExploration)
    summary["movement"]=movement_metrics(data)
    state=data["runtime"]["exploration"];world=data["world"]
    for aid,a in state["agents"].items():
        counts=Counter();closures=Counter();seeds={}
        assert a["tie_break_mode"]==world["agents"][aid]["config"]["tie_break_mode"]
        for source,d in a["decisions"].items():
            assert "steering" not in d and "lateral" not in d
            meta=d["tie_break"];v=meta["evaluation"];episode=meta["episode"]
            if meta["closure_reason"]:closures[meta["closure_reason"]]+=1
            if episode:
                assert 1<=episode["uses"]<=3
                assert episode["start_capture_us"]<=a["observations"][source]["capture_us"]<episode["expires_us"]
                counts[meta["transition"]]+=1
            if v is None:continue
            calculated=calculate_tie_break(terrain_input(a["observations"][source],a["teaching"]["appearance"],d["blocked_targets"]),
                a["tie_break_mode"],state["seed"],max(meta["episode_seq"],1))
            assert all(v[k]==value for k,value in calculated.items())
            assert v["observed_terrain"]==d["movement_terrain"] and v["selected_action"]==d["action"]
            counts["evaluations"]+=1
            counts["eligible"]+=bool(v["eligible_directions"])
            counts["applied"]+=v["sample"] is not None
            counts["changed_action"]+=v["selected_action"]!=v["baseline_action"]
            if v["sample"]:
                assert episode
                old=seeds.setdefault(episode["ref"],v["sample"])
                assert old==v["sample"]
                counts["actual_"+a["results"]["op:"+source]["status"]]+=1
        summary["agents"][aid]["tie_break"]=dict(mode=a["tie_break_mode"],counts=dict(counts),closures=dict(closures),
            dwell=dwell_metrics(world["agents"][aid],state["periods"]*16_000_000))
    if world["faults"]:
        loss=world["guards"]["lost_tie"]
        deliveries=[d for d in world["deliveries"] if d["kind"]=="observe" and d["request"]["observation_id"]==loss["source_id"]]
        assert len(deliveries)==2 and deliveries[0]["request"]==deliveries[1]["request"]
        first,repeat=[json.loads(d["response_wire"]) for d in deliveries]
        assert first["command"]==repeat["command"] and repeat["new_observations"]==repeat["new_frames"]==0
        actions=[a for a in world["agents"][loss["agent_id"]]["actions"] if a["command"]["operation_id"]==loss["operation_id"]]
        assert len(actions)==1 and actions[0]["result"]["status"] in ("turned","moved","blocked","expired")
        summary["lost_tie_result"]=actions[0]["result"]["status"]
    return summary
