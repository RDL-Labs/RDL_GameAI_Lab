"""Assertions for the same-run OBS-9 observation v1 completion gates."""
import json
import sys
from collections import Counter
from pathlib import Path
from runtime.observation_v1 import evaluate


def check(snapshot, record):
    scenario = record["scenario"]
    pid = record["probe_agent"]
    other = "npc_b" if pid == "npc_a" else "npc_a"
    evidence = record["evidence"]
    result = evaluate(snapshot, record["request"], evidence)
    expected = {"normal":"reobserved", "swap":"reobserved", "delayed":"reobserved",
                "faults":"reobserved", "preempt":"aborted", "same_slot":"aborted",
                "removed":"not_reobserved", "partial":"acquisition_incomplete"}
    assert result["status"] == expected[scenario], (scenario, result)
    assert record["arbiter_checks"] == 50 and record["v1_checks"] >= 100
    assert snapshot["rejection_count"] == (1 if scenario == "faults" else 0)
    assert snapshot["run_id"] == record["run_id"]
    assert snapshot["count"] == len(record["acquired_frames"]) == 108
    saved = {f["frame_id"]: f for f in snapshot["frames"]}
    assert len(saved) == snapshot["count"]
    for acquired in record["acquired_frames"]:
        f = saved[acquired["frame_id"]]
        assert acquired == {k:v for k,v in f.items() if k not in ("run_id", "world_epoch")}, (acquired,f)
    for aid, profile in [("npc_a","fixture-life-sensory"),("npc_b","fixture-life-sensory-compact")]:
        frames = [f for f in saved.values() if f["agent_id"] == aid]
        assert Counter(f["channel"] for f in frames) == {"vision_local":24,"vision_distant":6,"audition":24}
        assert all(f["profile_id"] == profile and f["profile_revision"] == 1 and f["observer_frame_ref"] for f in frames)
        first = next(f for f in frames if f["channel"] == "audition" and f["sampled_world_tick"] == 0)
        assert len([d for d in first["payload"]["detections"] if d["received_interval_us"] == [0,10000]]) == (1 if aid == "npc_a" else 0), first
        a = record["agents"][aid]
        assert a["picked_up"] and a["deposited"] and a["result_accepted"] and a["pending"] == a["reserved"] == 0, a
        assert a["transfers"] <= 32 and record["queue_peaks"][aid] <= 64
        assert len(record["traces"][aid]) <= 256
        for t in record["traces"][aid]:
            assert t["kind"] != "drop"
            if t["kind"] != "consume": continue
            ids=set(t["frame_ids"] or {});before=set(t["pending_before"] or []);removed=set(t["removed"] or [])
            assert list(t["frame_order"] or []) == [i for i in (t["pending_before"] or []) if i in ids] or not removed
            assert len(ids) <= 4 and all(saved[i]["agent_id"] == aid for i in ids | before | removed)
            assert removed == (before & ids if t.get("accepted") else set())
            assert not removed or t["consumed_us"] >= t["received_us"]
    samples=record["all_samples"]
    assert len({(s["agent_id"],s["channel"],s["tick"]) for s in samples}) == len(samples)
    for f in saved.values():
        start,end=f["capture_window"]["start_us"],f["capture_window"]["end_us"]
        assert 0 <= start < 6000000 and start <= end <= 6000000
        assert start//250000 == f["sampled_world_tick"]
        if f["channel"] == "audition":
            assert end-start == 250000
            for d in f["payload"]["detections"]:
                assert start <= d["received_interval_us"][0] < d["received_interval_us"][1] <= end
                assert d["observer_frame_ref"]
    forbidden={"position","object_id","node_name","distance","source_id","world_position","target_id"}
    def walk(x):
        if isinstance(x,dict):
            assert not forbidden & x.keys(), x
            for v in x.values(): walk(v)
        elif isinstance(x,list):
            for v in x: walk(v)
    walk(list(saved.values()));walk(record["request"]);walk(evidence)
    assert evidence["rotations"] <= 1 and evidence["samples"] <= 1
    assert len({a["delivery_id"] for a in record["actions"]}) == len(record["actions"])
    assert all(a["time_us"] < 6000000 for a in record["actions"])
    assert any(a["agent_id"] == other and a["time_us"] < 1200000 for a in record["actions"]) or scenario in ("faults","same_slot")
    if evidence["samples"]:
        f=saved[evidence["new_frame_id"]]
        assert f["channel"] == "vision_distant" and f["sampled_world_tick"] % 4 == 0
        assert evidence["rotation_completed_us"] < f["capture_window"]["start_us"]
        assert abs(evidence["pose"]["start_to_target_deg"]) <= 45
    if scenario in ("preempt","same_slot"):
        assert evidence["samples"] == 0 and "life_priority" in evidence["reasons"]
        assert any(a["agent_id"] == pid for a in record["actions"])
    if scenario in ("same_slot","faults"):
        old=[e for e in record["events"] if e["kind"] == "old_callback_after_new_request"]
        assert len(old)==1 and old[0]["retained"]
        stale=[t for t in record["traces"][other] if t["kind"]=="consume" and t["request_generation"]!=t["generation"]]
        assert stale and all(not t["action_eligible"] for t in stale)
        assert not {a["delivery_id"] for a in record["actions"]} & ({t["delivery_id"] for t in stale}|{old[0]["old_id"]})
    traces=[t for t in record["traces"][pid] if t["kind"]=="consume"]
    if scenario in ("delayed","faults"):
        held=[t for t in traces if t["consumed_us"]-t["received_us"]>=1000000]
        assert held
        assert {s["channel"] for s in samples if s["agent_id"]==pid and any(t["received_us"]<s["time_us"]<t["consumed_us"] for t in held)} == {"vision_local","vision_distant","audition"}
    if scenario=="delayed":
        ack=min(t["consumed_us"] for t in traces if evidence["new_frame_id"] in (t["removed"] or []))
        assert evidence["pose"]["translation"] <= 0.000001
        assert any(a["agent_id"]==pid and evidence["pose"]["target_us"] < a["time_us"] < ack for a in record["actions"])
    if scenario=="faults":
        kinds={e["kind"] for e in record["events"]}
        assert {"send_deferred","sensory_rejected","response_lost","old_callback_after_new_request"} <= kinds
        loss=next(e for e in record["events"] if e["kind"]=="response_lost")
        ids=loss["frame_ids"]
        assert ids and set(ids) <= set(loss["pending"])
        retries=[t for t in traces if t.get("accepted") and t.get("new_frames")==0 and set(t["frame_ids"])==set(ids)]
        assert len(retries)==1 and retries[0]["removed"]==ids and retries[0]["frame_order"]==ids
        assert len(retries[0]["pending_before"]) > len(ids)
        lost=next(t for t in traces if t["delivery_id"]==loss["delivery_id"])
        assert not lost["removed"] and not lost["action_eligible"]
    if result["status"] in ("acquisition_incomplete","aborted"):
        assert result["matches"] is None
    print(f"OBS9 PASS: scenario={scenario} result={result['status']} frames={snapshot['count']} queues={record['queue_peaks']} life=A+B")
    return result


if __name__ == "__main__":
    check(*(json.loads(Path(p).read_text(encoding="utf-8-sig")) for p in sys.argv[1:3]))
