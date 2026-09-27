"""Five actual Food objects; union of finite local observations, not hidden sites."""
from math import dist, isclose, sin, cos

SITES = [(18,18),(-18,-17),(-20,7),(7,-20),(20,-6)]


def check_food_observation(world, observation):
    assert world["food_set_checks"] == 11
    sites = world["foods_initial"]
    assert [(f["position"]["x"], f["position"]["z"]) for f in sites] == SITES
    assert len({f["ref"] for f in sites}) == 5
    initial = world["initial_body"]["position"]
    assert all(dist([initial[k] for k in "xyz"], [f["position"][k] for k in "xyz"]) > 12 for f in sites)
    p, body, audit = observation["packet"], observation["body"], observation["food_visibility"]
    by_ref = {f["ref"]: f["position"] for f in sites}
    # Capture stops after the first successful pickup, so every capture has all five.
    assert len(audit) == 5 and {v["ref"] for v in audit} == set(by_ref)
    visible = []
    for v in audit:
        target = by_ref[v["ref"]]
        delta = {k:target[k]-body["position"][k] for k in "xyz"}
        d = dist([body["position"][k] for k in "xyz"], [target[k] for k in "xyz"])
        assert isclose(v["distance"], d, abs_tol=1e-5)
        assert v["in_range"] == (d <= 12)
        if v["in_range"] and v["line_of_sight"]:
            visible.append(v["ref"])
            item = next(f for f in p["food"]["visible"] if f["ref"] == v["ref"])
            assert isclose(item["distance"], d, abs_tol=1e-5)
            assert isclose(item["up"], delta["y"], abs_tol=1e-5)
            yaw = body["yaw"]
            assert isclose(item["forward"], -sin(yaw)*delta["x"]+cos(yaw)*delta["z"], abs_tol=1e-5)
            assert isclose(item["right"], cos(yaw)*delta["x"]+sin(yaw)*delta["z"], abs_tol=1e-5)
    assert set(visible) == {f["ref"] for f in p["food"]["visible"]}
    assert p["food"]["visible"] == sorted(p["food"]["visible"], key=lambda f:(f["distance"], f["ref"]))
    assert (p["food"]["coverage"] == "complete") == all(v["coverage"] == "complete" for v in audit)
