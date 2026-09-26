import json
import sys
from pathlib import Path
from runtime.continuous_visual_probe import evaluate


def check(snapshot, evidence):
    result = evaluate(snapshot, evidence["request"], evidence["evidence"])
    scenario = evidence["scenario"]
    expected = {"delayed":"reobserved", "loss":"reobserved", "preempt":"aborted", "same_slot":"aborted", "stale":"not_executed", "jump":"aborted"}
    assert result["status"] == expected[scenario], (scenario,result)
    assert evidence["evidence"]["rotations"] <= 1 and evidence["evidence"]["samples"] <= 1
    assert snapshot["rejection_count"] == 0
    assert evidence["arbiter_checks"] >= 40
    assert all(a["picked_up"] and a["deposited"] and a["result_accepted"] and a["pending"] == 0 for a in evidence["agents"].values()), evidence["agents"]
    samples=evidence["samples"]
    assert len({(s["agent_id"],s["tick"]) for s in samples}) == len(samples)
    assert all(s["time_us"]//250000==s["tick"] and s["tick"]%4==0 for s in samples)
    assert any(s["time_us"] != s["tick"]*250000 for s in samples)
    assert all(s["time_us"] < 6000000 for s in samples)
    traces=evidence["traces"]["npc_a"]
    if scenario in ("delayed","stale"):
        held=[t for t in traces if t["kind"]=="consume" and t["consumed_us"]-t["received_us"]>=1000000]
        assert held
        assert any(t["received_us"] < s["time_us"] < t["consumed_us"] for t in held for s in samples if s["agent_id"]=="npc_a")
    if scenario=="same_slot":
        old = [e for e in evidence["events"] if e["kind"]=="old_callback_after_new_request"]
        assert len(old)==1 and old[0]["retained"]
        stale = [t for t in evidence["traces"]["npc_b"] if t["kind"]=="consume" and t["request_generation"]!=t["generation"]]
        assert stale and all(not t["action_eligible"] for t in stale)
        assert not any(a["delivery_id"] in {t["delivery_id"] for t in stale} for a in evidence["actions"])
        assert not any(a["delivery_id"]==old[0]["old_id"] for a in evidence["actions"])
    if scenario=="jump":
        assert "missed_acquisition_slot" in evidence["evidence"]["reasons"]
        assert any(e["kind"]=="missed_slot" and e["tick"]==4 for e in evidence["events"])
    if scenario=="loss":
        assert any(t["kind"]=="consume" and t.get("new_frames")==0 for t in traces)
    if scenario=="delayed":
        assert evidence["evidence"]["pose"]["translation"] <= 0.000001
        assert evidence["evidence"]["final_translation"] > 0.01
        frame_id=evidence["evidence"]["new_frame_id"]
        acknowledged=min(t["consumed_us"] for t in traces if t["kind"]=="consume" and frame_id in (t.get("removed") or []))
        captured=evidence["evidence"]["pose"]["target_us"]
        assert any(a["agent_id"]=="npc_a" and captured<a["time_us"]<acknowledged for a in evidence["actions"])
    print(f"OBS8B PASS: scenario={scenario} result={result['status']} frames={snapshot['count']} life=A+B")
    return result


if __name__ == "__main__":
    check(*(json.loads(Path(p).read_text(encoding="utf-8-sig")) for p in sys.argv[1:3]))
