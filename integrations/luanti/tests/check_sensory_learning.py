"""Check actual World effects separately from learned prediction and selection."""
import json
from pathlib import Path
import sys


def check(data, *, shared_canonical=False):
    world, learning, sensory, canonical = [data[k] for k in ("world", "learning", "sensory", "canonical")]
    episodes = world["episodes"]
    assert len(episodes) == 12
    assert sensory["count"] == 36 and sensory["rejection_count"] == 0
    assert {f["channel"] for f in sensory["frames"]} == {"vision_local", "vision_distant", "audition"}
    assert len({f["frame_id"] for f in sensory["frames"]}) == 36
    frames = {f["frame_id"]: f for f in sensory["frames"]}
    for f in frames.values():
        if f["channel"] != "vision_local":
            serialized = json.dumps(f)
            for forbidden in ("world_position", "source_id", "hidden_blocked", "target_id"):
                assert forbidden not in serialized
    assert len(learning["operations"]) == len(learning["results"]) == 12
    assert len({r["result"]["event_id"] for r in learning["results"].values()}) == 12
    for index, episode in enumerate(episodes, 1):
        decision = json.loads(episode["decision_wire"])
        operation = learning["operations"][episode["operation_id"]]
        result = learning["results"][episode["operation_id"]]
        frame = frames[decision["frame_id"]]
        assert operation["section"]["feature"] == frame["payload"]["features"][0]
        assert operation["decision"] == decision
        assert episode["actions"] <= 16
        assert episode["authority_consumptions"] == 1
        assert episode["base_stock_after"] - episode["base_stock_before"] == int(episode["deposited"])
        if index <= 8 or not world["activate"]:
            assert decision["prediction"]["status"] == "unknown"
            assert episode["attempted"]
        else:
            # This expectation is experimenter-only; runtime never receives it.
            trained_blocked = (episode["color_band"] == "dark_gray") if world["reverse"] else (episode["color_band"] == "muted_red")
            assert decision["action"] == ("defer" if trained_blocked else "attempt_food")
        if episode["attempted"]:
            assert result["experience"]["food_acquired"] == (not episode["hidden_blocked"])
            assert episode["deposited"] == (not episode["hidden_blocked"])
            assert episode["actions"] > 0
            assert result["F_prime"]["model_ref"] == decision["model_ref"]
            if index > 8 and world["activate"]:
                assert result["comparison"]["E"]["deltas"]["food_acquired"] == (-1.0 if index >= 11 else 0.0)
        else:
            assert episode["actions"] == 0 and episode["start"] == episode["finish"]
            assert result["experience"] is None and result["result"]["food_acquired"] is None
            assert result["comparison"]["status"] == "not_attempted"
    learned = next(iter(learning["learning"].values()))["response"]
    assert all(i["disposition"] == "RETAIN" for i in learned["inspections"])
    assert all(c["support_count"] == 3 for c in learned["candidates"])
    assert len(learned["artifact"]["adopted_relations"]) == 2
    for c in learned["candidates"]:
        signature = c["common_relation_signature"]
        assert not set(signature["formation_experiences"]) & set(signature["validation_experiences"])
    if not shared_canonical:
        assert canonical["model_cutover"]["count"] == int(world["activate"])
        assert len(canonical["model_archive"]) == int(world["activate"])
        assert canonical["M_delta"]["active_count"] == int(not world["activate"])
    return {"activate": world["activate"], "reverse": world["reverse"], "episodes": 12,
            "frames": 36, "evaluation_actions": [e["decision"]["action"] for e in episodes[8:]],
            "attempts": sum(e["attempted"] for e in episodes),
            "deposits": sum(e["deposited"] for e in episodes)}


if __name__ == "__main__":
    print("L10 PASS", json.dumps(check(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig")))))
