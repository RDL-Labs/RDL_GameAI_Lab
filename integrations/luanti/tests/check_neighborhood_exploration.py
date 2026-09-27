"""Real body return and typed survey checks, separate from exact wire replay."""
from math import dist, degrees
from runtime.neighborhood_exploration import SURVEY, MAX_SURVEY_US
from .check_landmark_exploration import check_landmark_day


def check_neighborhood_day(data):
    check_landmark_day(data, subgoal_only=False)
    w, state = data["world"], data["runtime"]["exploration"]
    observations = {o["packet"]["observation_id"]:o for o in w["observations"]}
    completed = 0
    for ident, d in state["decisions"].items():
        n = d["neighborhood"]; s = n["survey"]
        if n["phase"] == "survey":
            assert d["action"] == list(SURVEY[s["cursor"]])
        if n["phase"] in ("incomplete", "skipped", "completed") and d["reason"] != "observed_food_in_reach":
            assert d["action"] == ["wait",0]
        if n["phase"] == "skipped":
            assert n["prediction"]["status"] == "known" and n["prediction"]["predicts_food"] is False
        if n["phase"] != "completed": continue
        completed += 1
        assert s["cursor"] == 16 and len(s["return_sources"]) == 2
        source = observations[s["source_observation"]]
        terminal = observations[ident]
        assert terminal["packet"]["capture_us"]-source["packet"]["capture_us"] <= MAX_SURVEY_US
        for returning in s["return_sources"]:
            b = observations[returning["observation_id"]]["body"]; a = source["body"]
            assert dist([a["position"][k] for k in "xyz"], [b["position"][k] for k in "xyz"]) < .001
            assert abs((degrees(a["yaw"]-b["yaw"])+180)%360-180) < .01
        ps = list(state["observations"].values())[s["start_index"]:s["end_index"]+1]
        assert len(ps) == 17
        assert (not any(p["food"]["visible"] for p in ps)) == (n["outcome"] == "completed_no_food")
    return completed
