"""L11 independent World checks plus exact Runtime request replay."""
import json
from pathlib import Path
import sys
from runtime.boundary_defense import BoundaryDefense, UNIT


def replay(deliveries, run):
    coordinator = BoundaryDefense(run)
    for delivery in deliveries:
        got = getattr(coordinator, delivery["kind"])(delivery["request"])
        assert got == json.loads(delivery["response_wire"]), (delivery["kind"], got)
    return coordinator.snapshot()


def check(data):
    w, s = data["world"], data["reaction"]
    assert not w.get("failure"), w.get("failure")
    assert w["lua_checks"] >= 35
    assert s["config"] == w["config"]
    assert replay(w["deliveries"], w["run_id"]) == s
    assert w["finished_us"] <= w["start_us"] + 12 * UNIT
    negative = w["negative"]
    expected_uses = 1 if negative or w["schedule"] == "single" else 3
    assert len(w["uses"]) == expected_uses and w["spawned"] == expected_uses
    assert w["acquired"] == w["removed"] == (0 if negative == "presence" else expected_uses)
    records = list(s["records"].values())
    assert len(records) == (0 if negative == "presence" else expected_uses)
    last_time, load, first = None, 0, None
    for i, use in enumerate(w["uses"], 1):
        assert use["scheduled_us"] <= use["capture_us"] < use["scheduled_us"] + 250_000
        assert use["quantity_before"] == 1
        assert use["defender_position"] == {"x": 0, "y": 1, "z": 0}
        assert use["actor_position"] == {"x": 16 if negative == "outside" else 2, "y": 1, "z": 0}
        if negative == "presence":
            assert use["no_pickup"] and use["quantity_after"] == 1 and use["acquired_after"] == 0
            continue
        assert use["quantity_after"] == 0 and use["acquired_after"] == use["acquired_before"] + 1 == i
        record = use["record"]
        assert record == records[i-1]["record"]
        receipt = records[i-1]["receipt"]
        if negative == "outside":
            assert receipt["status"] == "unavailable" and "actor_not_visible" in receipt["reasons"]
            assert receipt["evaluation"] is None and receipt["permit"] is None
            continue
        assert receipt["status"] == "evaluated" and receipt["reasons"] == []
        time = record["notice"]["capture_us"]
        elapsed = time-last_time if last_time is not None else 0
        before = max(0, load-elapsed)
        load = before+4*UNIT
        e = receipt["evaluation"]
        threshold = (w["config"]["reaction"]["base_threshold"]+8*w["config"]["relation"]["beneficiary_inclusion"])*UNIT
        assert e["load_before"] == before and e["load_after"] == load and e["elapsed_us"] == elapsed
        assert e["appraisal_increment"] == 4*UNIT and e["warning_threshold"] == threshold
        assert e["threshold_reached"] == (load >= threshold)
        if receipt["permit"]:
            assert first is None
            first = i
        last_time = time
    threshold = w["config"]["reaction"]["base_threshold"]+8*w["config"]["relation"]["beneficiary_inclusion"]
    expected_first = None if negative else (1 if threshold == 3 else (3 if threshold in (9,11) and w["schedule"] == "dense" else None))
    assert first == expected_first, (first, expected_first)
    assert w["warning_count"] == len(s["results"]) == int(first is not None)
    if first:
        action = w["action_result"]
        assert action["status"] == "displayed" and action["readback"] == "WARNING" and action["cleared"] == ""
        assert action == next(iter(s["results"].values()))
        assert action["ended_us"] >= action["started_us"]+250_000
        assert all(w["guards"][k] for k in ("foreign_rejected", "replay_rejected", "completed_replay_rejected"))
        assert w["result_confirmed"]
    if w["loss_requested"]:
        assert w["lost_response"] and w["loss_recovered"]
        deliveries = [d for d in w["deliveries"] if d["kind"] == "observe"]
        assert deliveries[0]["request"]["record"] == deliveries[1]["request"]["record"]
        assert json.loads(deliveries[0]["response_wire"])["new_event"] is True
        assert json.loads(deliveries[1]["response_wire"])["new_event"] is False
    return {"run_id": w["run_id"], "warning_use": first, "pickups": w["acquired"], "negative": negative}


if __name__ == "__main__":
    print("L11 PASS", check(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))))
