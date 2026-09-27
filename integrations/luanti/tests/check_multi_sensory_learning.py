"""L10B: actual effects, per-agent provenance and shared-clock concurrency."""
import json
from pathlib import Path
import sys

from .check_sensory_learning import check as check_agent


def check(data):
    world, learning, sensory, canonical = [data[k] for k in ("world", "learning", "sensory", "canonical")]
    assert learning["schema"] == "luanti-sensory-learning-l10b-v1"
    assert set(world["by_agent"]) == set(learning["by_agent"]) == {"npc_a", "npc_b"}
    assert sensory["count"] == 72 and sensory["rejection_count"] == 0
    assert len({f["frame_id"] for f in sensory["frames"]}) == 72
    summaries, experiences, candidates, active_models = {}, set(), set(), set()
    for agent, w in world["by_agent"].items():
        l = learning["by_agent"][agent]
        frames = [f for f in sensory["frames"] if f["agent_id"] == agent]
        summaries[agent] = check_agent({"world": w, "learning": l,
            "sensory": dict(sensory, frames=frames, count=len(frames)), "canonical": canonical}, shared_canonical=True)
        profile = "fixture-life-sensory" if agent == "npc_a" else "fixture-life-sensory-compact"
        assert {f["profile_id"] for f in frames} == {profile}
        frame_ids = {f["frame_id"] for f in frames}
        own_experiences = set()
        for op, operation in l["operations"].items():
            decision = operation["decision"]
            result = l["results"][op]
            assert operation["request"]["agent_id"] == decision["agent_id"] == result["result"]["agent_id"] == agent
            assert decision["frame_id"] in frame_ids
            assert result["result"]["decision_id"] == decision["decision_id"]
            if result["experience"]:
                e = result["experience"]
                assert e["agent_id"] == e["section"]["agent_id"] == agent
                own_experiences.add(e["record_id"])
        assert not own_experiences & experiences
        experiences |= own_experiences
        learned = next(iter(l["learning"].values()))["response"]
        assert learned["artifact"]["agent_id"] == agent
        for c in learned["candidates"]:
            assert c["agent_id"] == c["common_relation_signature"]["boundary"]["agent_id"] == agent
            assert c["candidate_id"] not in candidates
            candidates.add(c["candidate_id"])
            signature = c["common_relation_signature"]
            assert set(signature["formation_experiences"] + signature["validation_experiences"]) <= own_experiences
        parents = {e["decision"]["model_ref"] for e in w["episodes"][:8]}
        later = {e["decision"]["model_ref"] for e in w["episodes"][8:]}
        assert len(parents) == len(later) == 1
        assert (parents != later) == w["activate"]
        assert not later & active_models
        active_models |= later
        assert any(e.get("foreign_response_rejected") for e in w["episodes"])
    activated = sum(w["activate"] for w in world["by_agent"].values())
    assert canonical["model_cutover"]["count"] == len(canonical["model_archive"]) == activated
    assert canonical["M_delta"]["active_count"] == 2 - activated
    assert {m["agent_id"] for m in canonical["model_archive"].values()} == {
        a for a, w in world["by_agent"].items() if w["activate"]}
    a, b = world["by_agent"]["npc_a"], world["by_agent"]["npc_b"]
    start, end = a["learning_hold_started_us"], a["learning_hold_released_us"]
    assert end - start >= 2000000
    assert any(start <= e.get("last_body_us", -1) < end for e in b["episodes"])
    assert any(start <= f["capture_window"]["end_us"] < end for f in sensory["frames"] if f["agent_id"] == "npc_b")
    assert b["episodes"][0]["started_us"] < a["finished_us"]
    assert a["episodes"][0]["started_us"] < b["finished_us"]
    scenario = world["scenario"]
    expected = {"opposite": ((True, False), (True, True)),
                "a_only": ((True, False), (False, False)),
                "b_only": ((False, False), (True, False))}[scenario]
    assert ((a["activate"], a["reverse"]), (b["activate"], b["reverse"])) == expected
    return {"scenario": scenario, "frames": 72, "by_agent": summaries,
            "A_response_hold_us": end - start, "B_progress_during_A_hold": True}


if __name__ == "__main__":
    print("L10B PASS", json.dumps(check(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig")))))
