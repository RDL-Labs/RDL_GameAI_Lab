"""Exact agent-wire replay plus independent real-body checks for L13S."""
import json
from runtime.learned_exploration import LearnedExplorationSeries
from runtime.exploration_series import digest
from .check_exploration import check
from .check_exploration_series import reset_signature, read_artifact


def check_series(a, world=True):
    c = a["config"]
    s = LearnedExplorationSeries(c["series_id"], c["mode"], c["seed"], c["max_days"])
    signature = None
    for d in a["days"]:
        data = d["data"]
        start = s.start_day(d["start"]["request"])
        assert start == d["start"]
        current = reset_signature(data)
        assert signature is None or signature == current
        signature = current
        if world:
            check(data, replay_loop=s.loop, fixed_policy=False)
        else:
            for delivery in data["world"]["deliveries"]:
                actual = getattr(s.loop, delivery["kind"])(delivery["request"])
                assert actual == json.loads(delivery["response_wire"])
            assert s.loop.snapshot() == data["runtime"]["exploration"]
        request = dict(**start["request"], state_digest=digest(s.loop.snapshot()))
        r = s.close_day(request)
        assert r == d["receipt"]
        assert s.close_day(request) == r
        assert s.summary() == d["summary"]
        assert r["metrics"]["first_food_us"] == data["world"].get("first_food_us")
    # Canonical assessment contexts use Python tuples; JSON archives use arrays.
    assert json.loads(json.dumps(s.snapshot())) == json.loads(json.dumps(a["state"]))
    assert s.summary()["status"] in ("discovery_target_reached", "discovery_target_unmet_at_limit")
    return s.summary()


def check_matrix(a):
    summaries = [check_series(s) for s in a["series"]]
    by = {s["config"]["mode"]:s for s in a["series"]}
    if {"inspect", "adopt"} <= by.keys():
        left, right = by["inspect"], by["adopt"]
        # Same actor history and random draws up to activation; World clock timestamps
        # and run IDs differ, so compare observations/actions rather than raw bytes.
        for l, r in zip(left["days"], right["days"]):
            ls, rs = l["data"]["runtime"]["exploration"], r["data"]["runtime"]["exploration"]
            assert ls["tape"] == rs["tape"]
            if any(x["reason"] == "active_M_B" for x in rs["decisions"].values()):
                break
            assert [(x["kind"],x["amount"]) for x in ls["commands"].values()] == [(x["kind"],x["amount"]) for x in rs["commands"].values()]
    return summaries


if __name__ == "__main__":
    import sys
    a = read_artifact(sys.argv[1])
    print(json.dumps(check_matrix(a) if "series" in a else check_series(a), indent=2))
