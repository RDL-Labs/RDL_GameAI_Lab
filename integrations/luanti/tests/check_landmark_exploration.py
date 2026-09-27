"""Independent ray/readback and subgoal authority checks for L13U."""
from math import cos, sin, floor, ceil, radians, isclose
from runtime.landmark_exploration import validate_landmarks


def round_node(value):
    # Luanti builtin/common/math.lua: half ties go away from zero.
    integral = ceil(value) if value < 0 else floor(value)
    return integral - int(value-integral <= -.5) if value < 0 else integral + int(value-integral >= .5)


def check_landmark_day(data):
    w, s = data["world"], data["runtime"]["exploration"]
    assert w["landmark_checks"] == 10
    assert s["draws"] == [] and all(x == ["wait", 0] for x in s["tape"])
    colors = dict(grass="green", dirt="brown", stone="gray", trunk="brown", leaves="green", water="blue", rock_gray="gray", rock_red="red")
    selected = {}
    for o in w["observations"]:
        p, rays, body = o["packet"], o["landmark_rays"], o["body"]
        assert len(rays) == 13
        validate_landmarks(p["landmarks"])
        features, previous = [], -2
        partial = False
        for i, ray in enumerate(rays):
            assert ray["angle"] == -90+15*i and 1 <= ray["samples"] <= 192
            if ray["status"] in ("unloaded", "unclassified"): partial = True
            if ray["status"] != "sampled": continue
            hit = ray["hit"]
            assert isclose(hit["distance"], ray["samples"]*.125)
            yaw = body["yaw"]-radians(ray["angle"])
            expected = dict(x=round_node(body["position"]["x"]-sin(yaw)*hit["distance"]),
                            y=round_node(body["position"]["y"]+.5),
                            z=round_node(body["position"]["z"]+cos(yaw)*hit["distance"]))
            assert hit["position"] == expected
            color = colors[hit["node"].removeprefix("rdl_bridge:exploration_")]
            band = "near" if hit["distance"] <= 3 else ("mid" if hit["distance"] <= 12 else "far")
            lo, hi = max(-90, ray["angle"]-7.5), min(90, ray["angle"]+7.5)
            if previous == i-1 and features and features[-1]["color"] == color and features[-1]["range_band"] == band:
                features[-1]["azimuth"][1] = hi
            else:
                features.append(dict(ref=f"patch{len(features)}", color=color, azimuth=[lo, hi], range_band=band))
            previous = i
        assert features == p["landmarks"]["features"]
        assert p["landmarks"]["coverage"] == ("partial" if partial else "complete")
        decision = s["decisions"][p["observation_id"]]
        state = decision["landmark"]
        assert state["selected_count"] <= 8 and state["scan_count"] <= 4
        assert decision["bootstrap_action"] is None
        if state["selection_index"] is not None:
            goal = state["goal"]
            assert goal["source_observation"] == p["observation_id"]
            assert goal["current_feature"] in p["landmarks"]["features"]
            assert goal["source_pose"] == p["pose_ref"] and goal["source_capture_us"] == p["capture_us"]
            assert goal["goal_id"] not in selected
            selected[goal["goal_id"]] = goal
        if state["goal"]:
            assert state["goal"]["operations"] <= 12
        if decision["action"][0] == "move":
            assert decision["reason"] in ("landmark_active", "active_M_B", "validation_probe")
            if decision["reason"] == "landmark_active":
                f = state["goal"]["current_feature"]
                assert f in p["landmarks"]["features"] and abs(sum(f["azimuth"])/2) <= 7.5
        if state["outcome"] in ("lost", "ambiguous", "blocked", "acquisition_incomplete", "near_feature_observed"):
            assert decision["action"] == ["wait", 0]
    return len(selected)
