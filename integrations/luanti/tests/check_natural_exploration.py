"""Independent World readback checks, never supplied as learning material."""
from math import dist, isclose


def check_natural_day(data):
    w = data["world"]
    assert w["natural_checks"] == 18
    t = w["terrain"]
    assert t["schema"] == "l13t-terrain-v1" and not t["artificial_path"]
    assert t["height_min"] < 0 < t["height_max"]
    assert t["counts"]["trees"] > 0 and t["counts"]["rocks"] == 4 and t["counts"]["water_columns"] > 0
    assert len(t["node_readback_sha1"]) == 40
    assert len(t["columns"]) == 65*65
    assert {c[0] for c in t["columns"] if c[1] == "rdl_bridge:exploration_water"} == {-1}
    actions = {a["command"]["operation_id"]: a for a in w["actions"]}
    moves = w["terrain_moves"] or []
    assert len(moves) == sum(a["result"]["status"] in ("moved", "blocked") for a in actions.values())
    for m in moves:
        a = actions[m["operation_id"]]
        assert a["command"]["kind"] == "move" and m["before"] == a["before"]["position"]
        if a["result"]["status"] == "moved":
            assert m["audit"]["reason"] == "supported_step"
            support = m["audit"]["samples"][-1]
            assert support["support"] in ("rdl_bridge:exploration_grass", "rdl_bridge:exploration_dirt", "rdl_bridge:exploration_stone")
            assert support["foot"] == support["head"] == "air"
            assert support["floor"]["y"] + 1 == a["after"]["position"]["y"]
        else:
            assert m["audit"]["reason"] in ("boundary", "unsupported_or_obstructed")
    for o in w["observations"]:
        p, b, v = o["packet"], o["body"], o.get("food_visibility")
        assert p["ground"]["model"] == "l13t-local-surface-rays-v1"
        if v:
            distance = dist([b["position"][k] for k in "xyz"], [w["food_initial"][k] for k in "xyz"])
            assert isclose(distance, v["distance"], abs_tol=1e-5)
            assert v["in_range"] == (distance <= 12)
            assert bool(p["food"]["visible"]) == (v["in_range"] and v["line_of_sight"])
            assert p["food"]["coverage"] == v["coverage"]
            if p["food"]["visible"]:
                item = p["food"]["visible"][0]
                assert isclose(item["distance"], distance, abs_tol=1e-5)
                assert isclose(item["up"], w["food_initial"]["y"]-b["position"]["y"], abs_tol=1e-5)
    return True
