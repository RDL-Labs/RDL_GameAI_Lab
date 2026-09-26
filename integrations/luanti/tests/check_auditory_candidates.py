"""Replay checks shared by the real-Luanti harness and committed-fixture test."""
import json
from pathlib import Path
import sys

from runtime.auditory_candidates import find_candidates, PURPOSE, RULE_VERSION
from runtime.sensory_comparison import diagnose, PURPOSE as PURPOSE_7A, RULE_VERSION as RULE_7A


def fixture_request(snapshot):
    return {"run_id": snapshot["run_id"], "world_epoch": snapshot["world_epoch"],
            "agent_id": "npc_a", "purpose": PURPOSE, "rule_version": RULE_VERSION,
            "queries": [{"source": {"frame_id": f"obs7b:audition:{i}", "detection_id": "d0"},
                         "target_frame_id": f"obs7b:audition:{i+1}"} for i in (1, 3, 5, 7)]}


def check(snapshot):
    assert snapshot["count"] == 8 and snapshot["rejection_count"] == 0
    frames = {f["frame_id"]: f for f in snapshot["frames"]}
    assert len(frames) == 8
    for f in frames.values():
        assert f["agent_id"] == "npc_a" and f["channel"] == "audition"
        assert f["coverage"] == "COMPLETE_WITHIN_PLAN" and not f["output_limited"]
        for d in f["payload"]["detections"]:
            assert not {"source_id", "world_position", "distance", "meaning"} & d.keys()
    left = frames["obs7b:audition:1"]["payload"]["detections"][0]
    right = frames["obs7b:audition:2"]["payload"]["detections"][0]
    assert left["received_interval_us"] == [245000, 250000]
    assert right["received_interval_us"] == [250000, 255000]
    assert left["observer_frame_ref"] == right["observer_frame_ref"]
    assert left["azimuth_interval_deg"] == right["azimuth_interval_deg"] == [0, 30]
    assert left["dominant_band"] == right["dominant_band"] == "mid"
    results = find_candidates(snapshot, fixture_request(snapshot))["results"]
    assert [r["status"] for r in results] == [
        "single_candidate", "multiple_candidates", "no_candidate", "not_comparable"]
    assert [len(r["candidates"]) for r in results[:3]] == [1, 2, 0]
    assert results[3]["candidates"] is None and not results[3]["search_complete"]
    assert sorted(p["status"] for p in results[3]["pair_results"]) == ["candidate", "not_comparable"]
    assert results[3]["reasons"] == ["pose_mapping_unavailable"]
    req = fixture_request(snapshot)
    req.pop("queries")
    req.update(purpose=PURPOSE_7A, rule_version=RULE_7A,
               pairs=[[{"frame_id": f"obs7b:audition:{i}", "element_id": "d0"} for i in (1, 2)]])
    assert diagnose(snapshot, req)["results"][0]["reasons"] == ["no_temporal_overlap"]
    return results


if __name__ == "__main__":
    check(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig")))
    print("OBS7B PASS: single=1 multiple=2 none=0 incomplete=not_comparable 7A=no_temporal_overlap")
