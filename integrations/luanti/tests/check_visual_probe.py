import json
import sys
from pathlib import Path
from runtime.visual_reacquisition import evaluate


def check(snapshot, evidence):
    expected = {"right": "reobserved", "left": "reobserved", "removed": "not_reobserved",
                "occluded": "not_reobserved", "multiple": "reobserved", "overflow": "acquisition_incomplete",
                "rotation_mismatch": "aborted", "expired": "not_executed", "life_busy": "not_executed",
                "moved": "aborted", "profile_changed": "aborted", "pose_expired": "aborted", "priority": "aborted",
                "unloaded": "acquisition_incomplete", "wrap": "reobserved"}
    assert evidence["ledger_checks"] and snapshot["run_id"] == evidence["run_id"]
    assert len(evidence["records"]) == len(expected)
    results = []
    for record in evidence["records"]:
        result = evaluate(snapshot, record["request"], record["evidence"])
        assert result["status"] == expected[record["case"]], (record["case"], result)
        assert record["evidence"]["rotations"] <= 1 and record["evidence"]["samples"] <= 1
        if record["case"] == "right":
            assert record["evidence"]["operation_response_lost"]
            assert record["evidence"]["delivery_new_frames"] == [1, 0]
            assert record["evidence"]["rotations"] == record["evidence"]["samples"] == 1
        if record["case"] == "wrap":
            assert abs(record["evidence"]["pose"]["source_to_start_deg"] + 10) < 0.01
        if record["case"] == "multiple":
            assert len(result["matches"]) == 2, result
        results.append(result)
    assert len({f["frame_id"] for f in snapshot["frames"]}) == len(snapshot["frames"]) == 23
    forbidden = {"position", "source_id", "object_id", "distance", "node_name"}
    def walk(value):
        if isinstance(value, dict):
            assert not (forbidden & value.keys())
            for x in value.values(): walk(x)
        elif isinstance(value, list):
            for x in value: walk(x)
    walk(snapshot["frames"])
    print("OBS8 PASS: cases=15 frames=23 rotation_once=true sample_once=true ledger_capacity=16")
    return results


if __name__ == "__main__":
    check(*(json.loads(Path(p).read_text(encoding="utf-8-sig")) for p in sys.argv[1:3]))
