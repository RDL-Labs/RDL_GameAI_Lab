"""OBS-7B: finite, pure links between adjacent auditory-window records."""
from copy import deepcopy
from math import isfinite

from .sensory_observation import SCHEMA_VERSION

PURPOSE = "adjacent_window_auditory_pattern_candidates"
RULE_VERSION = "obs7b-v1"
MAX_QUERIES = 16


class CandidateInputError(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def _require(condition, code):
    if not condition:
        raise CandidateInputError(code)


def _text(value):
    return isinstance(value, str) and 0 < len(value) <= 128


def _frame_reasons(frame):
    reasons = []
    for condition, code in [
        (frame["channel"] == "audition", "unsupported_channel"),
        (frame["sensor_id"] == "ears", "unsupported_sensor"),
        (frame["sensor_model_revision"] == "direct_band_energy_v0", "unsupported_model"),
        ((frame["profile_id"], frame["profile_revision"]) == ("fixture-audition-enabled", 1), "unsupported_profile"),
        (frame["status"] == "SAMPLED", "unavailable"),
        (frame["coverage"] == "COMPLETE_WITHIN_PLAN", "incomplete_coverage"),
        (not frame["output_limited"], "output_limited"),
        (frame["capture_window"]["kind"] == "interval" and
         frame["capture_window"]["end_us"] - frame["capture_window"]["start_us"] == 250000,
         "unsupported_window"),
    ]:
        if not condition:
            reasons.append(code)
    return reasons


def _element_reasons(value):
    reasons = []
    direction = value["azimuth_interval_deg"]
    if direction == "unknown":
        reasons.append("unknown_direction")
    elif not (isinstance(direction, list) and len(direction) == 2 and
              all(type(x) in (int, float) and isfinite(x) for x in direction) and
              -180 <= direction[0] < direction[1] <= 180 and
              direction[1] - direction[0] == 30 and all(x % 30 == 0 for x in direction)):
        reasons.append("unsupported_direction_bin")
    if value["dominant_band"] not in ("low", "mid", "high"):
        reasons.append("unknown_band")
    if value["elevation_band"] not in ("below", "level", "above"):
        reasons.append("unknown_elevation")
    if value["received_interval_us"][0] >= value["received_interval_us"][1]:
        reasons.append("empty_received_interval")
    return reasons


def _detections(frame):
    values = frame["payload"].get("detections", [])
    _require(isinstance(values, list) and len(values) <= 8, "invalid_snapshot")
    ids = [value.get("detection_id") for value in values]
    _require(all(_text(value) for value in ids), "invalid_snapshot")
    _require(len(set(ids)) == len(ids), "ambiguous_detection")
    return {value["detection_id"]: value for value in values}


def _query_result(source, detection_id, target):
    source_values, target_values = _detections(source), _detections(target)
    _require(detection_id in source_values, "unknown_detection")
    reasons = _frame_reasons(source) + _frame_reasons(target)
    if source["clock_id"] != target["clock_id"]:
        reasons.append("clock_mismatch")
    elif source["capture_window"]["end_us"] != target["capture_window"]["start_us"]:
        reasons.append("non_adjacent_windows")
    result = {
        "source": {"frame_id": source["frame_id"], "detection_id": detection_id},
        "target_frame_id": target["frame_id"],
        "conditions": {"source_frame": deepcopy(source), "target_frame": deepcopy(target)},
        "status": "not_comparable", "search_complete": False,
        "reasons": sorted(set(reasons)), "pair_results": [], "candidates": None,
    }
    if reasons:
        return result
    left = source_values[detection_id]
    source_reasons = _element_reasons(left)
    if source_reasons:
        result["reasons"] = sorted(source_reasons)
        return result
    candidates = []
    for target_id, right in sorted(target_values.items()):
        missing = _element_reasons(right)
        if left["observer_frame_ref"] != right["observer_frame_ref"]:
            missing.append("pose_mapping_unavailable")
        mismatch = []
        if not missing:
            boundary = source["capture_window"]["end_us"]
            if left["received_interval_us"][1] != boundary or right["received_interval_us"][0] != boundary:
                mismatch.append("boundary_not_touched")
            if left["dominant_band"] != right["dominant_band"]:
                mismatch.append("band_mismatch")
            if left["elevation_band"] != right["elevation_band"]:
                mismatch.append("elevation_mismatch")
            distance = abs(sum(left["azimuth_interval_deg"]) / 2 - sum(right["azimuth_interval_deg"]) / 2)
            if min(distance, 360 - distance) > 30:
                mismatch.append("azimuth_outside_neighborhood")
        status = "not_comparable" if missing else ("not_candidate" if mismatch else "candidate")
        ref = {"frame_id": target["frame_id"], "detection_id": target_id}
        result["pair_results"].append({"target": ref, "status": status,
                                        "reasons": sorted(set(missing or mismatch))})
        reasons.extend(missing)
        if status == "candidate":
            candidates.append(ref)
    if reasons:
        result["reasons"] = sorted(set(reasons))
        return result
    result.update(search_complete=True, candidates=candidates,
                  status=("no_candidate" if not candidates else
                          "single_candidate" if len(candidates) == 1 else "multiple_candidates"))
    return result


def find_candidates(snapshot, request):
    """Diagnose all detections in explicit target frames of an admitted snapshot.

    snapshot is trusted store output, not an alternative admission interface.
    Input errors reject the entire call. No input/global state is mutated.
    """
    _require(isinstance(request, dict) and set(request) == {
        "run_id", "world_epoch", "agent_id", "purpose", "rule_version", "queries",
    }, "invalid_request")
    _require(request["purpose"] == PURPOSE, "unsupported_purpose")
    _require(request["rule_version"] == RULE_VERSION, "unsupported_rule")
    _require(_text(request["agent_id"]), "invalid_agent")
    _require(isinstance(snapshot, dict) and snapshot.get("schema_version") == SCHEMA_VERSION
             and isinstance(snapshot.get("frames"), list), "invalid_snapshot")
    _require(request["run_id"] == snapshot.get("run_id") and type(request["world_epoch"]) is int
             and request["world_epoch"] == snapshot.get("world_epoch"), "context_mismatch")
    _require(request["agent_id"] in snapshot.get("assignments", {}), "unknown_agent")
    queries = request["queries"]
    _require(isinstance(queries, list), "invalid_queries")
    _require(len(queries) <= MAX_QUERIES, "budget_exceeded")
    frames = {}
    for frame in snapshot["frames"]:
        _require(isinstance(frame, dict) and _text(frame.get("frame_id")), "invalid_snapshot")
        _require(frame["frame_id"] not in frames, "duplicate_snapshot_frame")
        frames[frame["frame_id"]] = frame
    keys = set()
    for query in queries:
        _require(isinstance(query, dict) and set(query) == {"source", "target_frame_id"}, "invalid_query")
        src = query["source"]
        _require(isinstance(src, dict) and set(src) == {"frame_id", "detection_id"}, "invalid_reference")
        key = (src["frame_id"], src["detection_id"], query["target_frame_id"])
        _require(all(_text(value) for value in key), "invalid_reference")
        _require(key[0] != key[2], "self_query")
        for fid in (key[0], key[2]):
            _require(fid in frames, "unknown_frame")
            frame = frames[fid]
            _require(frame.get("agent_id") == request["agent_id"], "cross_agent_reference")
            _require(frame.get("run_id") == request["run_id"] and
                     frame.get("world_epoch") == request["world_epoch"], "context_mismatch")
        left, right = frames[key[0]], frames[key[2]]
        # Different clocks have no meaningful chronological ordering here.
        if left["clock_id"] == right["clock_id"]:
            _require(left["capture_window"]["start_us"] < right["capture_window"]["start_us"], "reverse_time")
        keys.add(key)
    results = [_query_result(frames[left], element, frames[right]) for left, element, right in sorted(keys)]
    return {"purpose": PURPOSE, "rule_version": RULE_VERSION,
            "run_id": request["run_id"], "world_epoch": request["world_epoch"],
            "agent_id": request["agent_id"], "authority": "record-links-only; not-source-identity-canonical-or-action",
            "results": results}
