"""OBS-7A: pure eligibility diagnostics over admitted sensory snapshots.

No store, model, action, candidate generation, or observer-pose reconstruction.
The snapshot is trusted output of SensoryObservationStore, not an admission API.
"""
from copy import deepcopy

from .sensory_observation import SCHEMA_VERSION

RULE_VERSION = "obs7a-v1"
PURPOSE = "coincident_azimuth_comparison"
MAX_PAIRS = 16
MAX_FRAME_REFERENCES = 32
# Explicit v1 permission table; feature values are never compared here.
MODELS = {
    "vision_distant": "sampled-surface-v0.2",
    "audition": "direct_band_energy_v0",
}
PROFILES = frozenset({
    ("fixture-distant-enabled", 1), ("fixture-audition-enabled", 1),
    ("fixture-audition-compact", 1), ("fixture-life-sensory", 1),
    ("fixture-life-sensory-compact", 1),
})


class ComparisonInputError(ValueError):
    """Invalid request/context, distinct from valid but incomparable evidence."""

    def __init__(self, code):
        self.code = code
        super().__init__(code)


def _require(condition, code):
    if not condition:
        raise ComparisonInputError(code)


def _text(value):
    return isinstance(value, str) and 0 < len(value) <= 128


def _overlap(left, right):
    # Empty intervals do not become instant samples.
    a, b = left["start_us"], left["end_us"]
    c, d = right["start_us"], right["end_us"]
    if left["kind"] == "instant" and right["kind"] == "instant":
        return a == c
    if left["kind"] == "instant":
        return c <= a < d
    if right["kind"] == "instant":
        return a <= c < b
    return max(a, c) < min(b, d)


def _selected(frame, ref):
    channel = frame["channel"]
    values_key, id_key = {
        "vision_distant": ("features", "feature_id"),
        "audition": ("detections", "detection_id"),
    }.get(channel, (None, None))
    values = frame["payload"].get(values_key, [])
    element_id = ref.get("element_id")
    if element_id is None:
        return None, "element_selection_required" if values else "no_element"
    matches = [value for value in values if value[id_key] == element_id]
    _require(len(matches) == 1, "unknown_or_ambiguous_element")
    return matches[0], None


def _conditions(frame, element):
    window = frame["capture_window"]
    pose = frame["observer_frame_ref"]
    if frame["channel"] == "audition" and element is not None:
        start, end = element["received_interval_us"]
        window = {"kind": "interval", "start_us": start, "end_us": end}
        pose = element["observer_frame_ref"]
    return deepcopy({
        key: frame[key] for key in (
            "run_id", "world_epoch", "agent_id", "sensor_id", "channel",
            "profile_id", "profile_revision", "sensor_model_revision", "clock_id",
            "capture_window", "sampled_world_tick", "status", "coverage", "output_limited",
        )
    } | {"comparison_window": window, "observer_frame_ref": pose})


def diagnose(snapshot, request):
    """Return diagnostics for explicit pairs, or reject the entire request.

    No input is changed. Repeated unordered pairs are returned once in canonical
    order; the result contains no support count, similarity, or identity verdict.
    """
    _require(isinstance(request, dict) and set(request) == {
        "run_id", "world_epoch", "agent_id", "purpose", "rule_version", "pairs",
    }, "invalid_request")
    _require(request["purpose"] == PURPOSE, "unsupported_purpose")
    _require(request["rule_version"] == RULE_VERSION, "unsupported_rule")
    _require(_text(request["agent_id"]), "invalid_agent")
    _require(isinstance(snapshot, dict) and snapshot.get("schema_version") == SCHEMA_VERSION
             and isinstance(snapshot.get("frames"), list), "invalid_snapshot")
    _require(request["run_id"] == snapshot.get("run_id") and
             type(request["world_epoch"]) is int and
             request["world_epoch"] == snapshot.get("world_epoch"), "context_mismatch")
    _require(request["agent_id"] in snapshot.get("assignments", {}), "unknown_agent")
    pairs = request["pairs"]
    _require(isinstance(pairs, list), "invalid_pairs")
    _require(len(pairs) <= MAX_PAIRS and 2 * len(pairs) <= MAX_FRAME_REFERENCES,
             "budget_exceeded")
    by_id = {}
    for frame in snapshot["frames"]:
        _require(isinstance(frame, dict) and _text(frame.get("frame_id")), "invalid_snapshot")
        _require(frame["frame_id"] not in by_id, "duplicate_snapshot_frame")
        by_id[frame["frame_id"]] = frame
    selected = {}
    for pair in pairs:
        _require(isinstance(pair, list) and len(pair) == 2, "invalid_pair")
        normalized = []
        for ref in pair:
            _require(isinstance(ref, dict) and set(ref) in (
                {"frame_id"}, {"frame_id", "element_id"}), "invalid_reference")
            _require(_text(ref.get("frame_id")) and
                     ("element_id" not in ref or _text(ref["element_id"])), "invalid_reference")
            _require(ref["frame_id"] in by_id, "unknown_frame")
            frame = by_id[ref["frame_id"]]
            _require(frame.get("agent_id") == request["agent_id"], "cross_agent_reference")
            _require(frame.get("run_id") == request["run_id"] and
                     frame.get("world_epoch") == request["world_epoch"], "context_mismatch")
            normalized.append((ref["frame_id"], ref.get("element_id", "")))
        _require(normalized[0][0] != normalized[1][0], "self_pair")
        key = tuple(sorted(normalized))
        selected[key] = None
    results = []
    for key in sorted(selected):
        refs = [{"frame_id": fid, **({"element_id": eid} if eid else {})} for fid, eid in key]
        frames = [by_id[ref["frame_id"]] for ref in refs]
        reasons, conditions = [], []
        for frame, ref in zip(frames, refs):
            element, reason = _selected(frame, ref)
            if reason:
                reasons.append(reason)
            condition = _conditions(frame, element)
            conditions.append(condition)
            if frame["channel"] not in MODELS:
                reasons.append("unsupported_channel")
            elif frame["sensor_model_revision"] != MODELS[frame["channel"]]:
                reasons.append("unsupported_model")
            if (frame["profile_id"], frame["profile_revision"]) not in PROFILES:
                reasons.append("unsupported_profile")
            if frame["status"] != "SAMPLED":
                reasons.append("unavailable")
            if frame["coverage"] != "COMPLETE_WITHIN_PLAN":
                reasons.append("incomplete_coverage")
            if frame["output_limited"]:
                reasons.append("output_limited")
            if element is not None and element["azimuth_interval_deg"] == "unknown":
                reasons.append("unknown_direction")
        left, right = conditions
        if (left["profile_id"], left["profile_revision"]) != (right["profile_id"], right["profile_revision"]):
            reasons.append("profile_mismatch")
        if left["clock_id"] != right["clock_id"]:
            reasons.append("clock_mismatch")
        elif not _overlap(left["comparison_window"], right["comparison_window"]):
            reasons.append("no_temporal_overlap")
        # Same sensor and opaque pose token scope the reference. Eye/ear tokens
        # with identical spellings alone cannot authorize a coordinate transform.
        if (left["channel"], left["sensor_id"], left["observer_frame_ref"]) != (right["channel"], right["sensor_id"], right["observer_frame_ref"]):
            reasons.append("pose_mapping_unavailable")
        reasons = sorted(set(reasons))
        results.append({"references": refs, "conditions": conditions,
                        "status": "not_comparable" if reasons else "eligible", "reasons": reasons})
    return {"rule_version": RULE_VERSION, "purpose": PURPOSE,
            "run_id": request["run_id"], "world_epoch": request["world_epoch"],
            "agent_id": request["agent_id"],
            "authority": "diagnostic-only; not-identity-candidate-canonical-or-action",
            "results": results}
