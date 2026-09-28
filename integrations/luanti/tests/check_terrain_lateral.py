"""Independent World audit plus exact replay of the bias-only consumer."""
from collections import Counter
from math import floor

from runtime.terrain_lateral_bias import LateralResourceExploration, calculate_lateral
from runtime.terrain_resource_exploration import terrain_input
from .check_terrain_resource import check as check_terrain
from .check_terrain_steering import movement_metrics


def decision_links(data):
    links={}
    for aid,a in data["world"]["agents"].items():
        sources=[o["packet"]["observation_id"] for o in a["observations"]]
        links[aid]={source:(sources[i+1] if i+1<len(sources) else None) for i,source in enumerate(sources)}
    return links


def check(data):
    summary=check_terrain(data,LateralResourceExploration)
    summary["movement"]=movement_metrics(data)
    for aid,a in data["runtime"]["exploration"]["agents"].items():
        w=data["world"]["agents"][aid];counts=Counter();counterfactual=Counter()
        assert a["lateral_bias"]==w["config"]["lateral_bias"]
        for source,d in a["decisions"].items():
            assert "steering" not in d
            v=d["lateral"]
            if v is None:continue
            obs=terrain_input(a["observations"][source],a["teaching"]["appearance"],d["blocked_targets"])
            calculated=calculate_lateral(obs,a["lateral_bias"])
            assert all(v[k]==value for k,value in calculated.items())
            assert v["observed_terrain"]==d["movement_terrain"]
            assert v["selected_action"]==d["action"] and v["turn_hysteresis"]=="disabled"
            assert v["parameter_source"]==dict(run_id=data["world"]["run_id"],agent_id=aid,kind="fixed_run_configuration")
            counts["evaluations"]+=1
            counts["eligible"]+=any(pair["eligible"] for pair in v["pairs"])
            counts["nonzero_contribution"]+=any(row["lateral_bias_contribution"] not in (None,0) for row in v["directional_samples"])
            counts["changed_action"]+=v["selected_action"]!=v["baseline_action"]
            for bias in ("left","neutral","right"):
                c=calculate_lateral(obs,bias)
                counterfactual[bias]+=c["selected_action"]!=v["baseline_action"]
        points=[w["initial_body"]["position"]]+[x["after"]["position"] for x in w["actions"]]
        summary["agents"][aid]["lateral"]=dict(bias=a["lateral_bias"],counts=dict(counts),
            same_observation_changed_actions=dict(counterfactual),
            visited_two_node_cells=len({(floor(p["x"]/2),floor(p["z"]/2)) for p in points}),
            final_position=w["final_body"]["position"])
    return summary
