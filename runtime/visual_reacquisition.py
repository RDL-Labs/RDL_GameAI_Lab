"""OBS-8 pure evaluation of admitted frames and body-adapter evidence.

Body evidence is a trusted, run-scoped adapter output, not arbitrary client data.
No World target information, action execution, or canonical updates occur here.
"""
from copy import deepcopy
from math import isfinite

PURPOSE = "visual_reacquisition_after_yaw"
RULE_VERSION = "obs8-v1"


class ProbeInputError(ValueError):
    pass


def circular_parts(interval, rotation=0, error=0):
    lo, hi = interval[0] - rotation - error, interval[1] - rotation + error
    if hi - lo >= 360:
        return [(-180, 180)]
    width = hi - lo
    lo = (lo + 180) % 360 - 180
    return [(lo, lo + width)] if lo + width <= 180 else [(lo, 180), (-180, lo + width - 360)]


def overlap(left, right):
    return any(max(a, c) < min(b, d) for a, b in left for c, d in right)


def _frame(snapshot, fid, request):
    matches = [f for f in snapshot["frames"] if f["frame_id"] == fid]
    if len(matches) != 1:
        raise ProbeInputError("unknown_or_ambiguous_frame")
    frame = matches[0]
    if any(frame[k] != request[k] for k in ("run_id", "world_epoch", "agent_id")):
        raise ProbeInputError("context_mismatch")
    return frame


def _conditions(frame):
    return (frame["channel"], frame["sensor_id"], frame["profile_id"], frame["profile_revision"],
            frame["sensor_model_revision"], frame["clock_id"]) == (
                "vision_distant", "eye", "fixture-distant-enabled", 1, "sampled-surface-v0.2", "world-sim-v1")


def _complete(frame):
    return frame["status"] == "SAMPLED" and frame["coverage"] == "COMPLETE_WITHIN_PLAN" and not frame["output_limited"]


def _known_interval(value):
    return (isinstance(value, list) and len(value) == 2 and
            all(type(x) in (int, float) and isfinite(x) for x in value) and value[0] < value[1])


def evaluate(snapshot, request, evidence):
    return _evaluate(snapshot, request, evidence, RULE_VERSION)


def _evaluate(snapshot, request, evidence, rule_version):
    required = {"operation_id", "run_id", "world_epoch", "agent_id", "purpose", "rule_version",
                "source_frame_id", "feature_id", "color_band"}
    if set(request) != required or request["purpose"] != PURPOSE or request["rule_version"] != rule_version:
        raise ProbeInputError("invalid_request")
    if any(snapshot[k] != request[k] for k in ("run_id", "world_epoch")):
        raise ProbeInputError("context_mismatch")
    if any(evidence[k] != request[k] for k in ("operation_id", "run_id", "world_epoch", "agent_id")):
        raise ProbeInputError("evidence_context_mismatch")
    source = _frame(snapshot, request["source_frame_id"], request)
    features = [f for f in source["payload"].get("features", []) if f["feature_id"] == request["feature_id"]]
    if len(features) != 1 or features[0]["color_band"] != request["color_band"]:
        raise ProbeInputError("invalid_feature")
    feature = features[0]
    result = {"purpose": PURPOSE, "rule_version": rule_version, "request": deepcopy(request),
              "evidence": deepcopy(evidence), "source_frame": deepcopy(source), "new_frame": None,
              "operation_status": evidence["operation_status"], "acquisition_status": "not_acquired",
              "comparison_reasons": [], "acquisition_reasons": [], "matches": None,
              "status": evidence["operation_status"], "evaluation": None,
              "authority": "coarse-record-reacquisition-only; not-object-identity"}
    if evidence["operation_status"] in ("not_executed", "aborted"):
        return result
    if evidence["operation_status"] != "sampled":
        raise ProbeInputError("operation_not_terminal")
    if not evidence.get("new_frame_id"):
        result.update(status="acquisition_incomplete", acquisition_reasons=["not_acquired"])
        return result
    target = _frame(snapshot, evidence["new_frame_id"], request)
    result["new_frame"] = deepcopy(target)
    missing, incomplete = [], []
    if not _complete(target):
        incomplete.append("incomplete_frame")
    if not _complete(source) or not _conditions(source) or not _conditions(target):
        missing.append("unsupported_conditions")
    if feature["color_band"] == "unknown" or not all(_known_interval(feature[k]) for k in ("azimuth_interval_deg", "elevation_interval_deg")):
        missing.append("unknown_source_feature")
    p = evidence["pose"]
    if (p["issuer"] != "luanti-body-yaw-v1" or not p["valid"] or not p["evidence_id"] or
            p["source_ref"] != source["observer_frame_ref"] or p["target_ref"] != target["observer_frame_ref"] or
            not p["start_ref"] or p["clock_id"] != source["clock_id"] or p["clock_id"] != target["clock_id"]):
        missing.append("pose_mapping_unavailable")
    src_time, dst_time = source["capture_window"]["start_us"], target["capture_window"]["start_us"]
    start, finish = evidence["started_us"], evidence["rotation_completed_us"]
    if (source["capture_window"]["kind"] != "instant" or target["capture_window"]["kind"] != "instant" or
            not src_time <= start <= finish < dst_time or start - src_time > 2000000 or
            dst_time - src_time > 2000000 or dst_time - start > 1500000 or
            p["source_us"] != src_time or p["start_us"] != start or p["target_us"] != dst_time or
            p["expires_us"] < dst_time):
        missing.append("time_or_expiry")
    if (evidence["sample_tick"] != target["sampled_world_tick"] or evidence["sample_tick"] % 4 or
            evidence["sample_tick"] != (finish // 1000000 + 1) * 4 or
            (dst_time != evidence["sample_tick"] * 250000 if rule_version == RULE_VERSION else
             dst_time // 250000 != evidence["sample_tick"]) or evidence["samples"] != 1):
        missing.append("invalid_acquisition_slot")
    nums = [p.get(k) for k in ("source_to_start_deg", "start_to_target_deg", "error_deg", "translation", "tilt_deg")]
    valid_numbers = all(type(x) in (int, float) and isfinite(x) for x in nums)
    if not valid_numbers:
        missing.append("pose_mapping_unavailable")
    elif (not 0 <= p["error_deg"] <= 0.01 or not 0 <= p["translation"] <= 0.000001 or
          not 0 <= p["tilt_deg"] <= 0.01):
        missing.append("body_changed")
    command = evidence.get("command_deg")
    if (type(command) not in (int, float) or not isfinite(command) or abs(command) > 45 or
            not valid_numbers or abs(p["start_to_target_deg"]) > 45 or
            abs(p["start_to_target_deg"] - command) > 0.01 or evidence["rotations"] != (0 if command == 0 else 1)):
        missing.append("rotation_unconfirmed")
    if valid_numbers and not missing:
        azimuth = circular_parts(feature["azimuth_interval_deg"], p["source_to_start_deg"] + p["start_to_target_deg"], p["error_deg"])
        elevation = feature["elevation_interval_deg"]
        result["inspection_region"] = {"azimuth": azimuth, "elevation": deepcopy(elevation)}
        if any(a < -45 or b > 45 for a, b in azimuth) or elevation[0] < -30 or elevation[1] > 30:
            missing.append("region_outside_fov")
    values = target["payload"].get("features", [])
    if any(not all(_known_interval(f[k]) for k in ("azimuth_interval_deg", "elevation_interval_deg")) or
           f["color_band"] == "unknown" for f in values):
        missing.append("unknown_target_feature")
    result.update(comparison_reasons=sorted(set(missing)), acquisition_reasons=incomplete,
                  acquisition_status="incomplete" if incomplete else "complete")
    if incomplete or missing:
        result["status"] = "acquisition_incomplete" if incomplete else "not_comparable"
        return result
    result["matches"] = [{"frame_id": target["frame_id"], "feature_id": f["feature_id"]} for f in values
                         if f["color_band"] == request["color_band"] and
                         overlap(azimuth, circular_parts(f["azimuth_interval_deg"])) and
                         overlap([elevation], [f["elevation_interval_deg"]])]
    result["evaluation"] = "reobserved" if result["matches"] else "not_reobserved"
    result["status"] = result["evaluation"]
    return result
