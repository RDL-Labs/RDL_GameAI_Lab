"""Finite, read-only storage for isolated sensory observation frames."""

from __future__ import annotations

from copy import deepcopy
from math import isfinite
from typing import Any

from .core import ObservationError


SCHEMA_VERSION = "rdl-sensory-extension-v1"
CHANNELS = {"vision_local", "vision_distant", "audition"}
STATUSES = {"SAMPLED", "UNAVAILABLE"}
COVERAGE = {"COMPLETE_WITHIN_PLAN", "PARTIAL", "UNAVAILABLE"}
PROFILE_REGISTRY = {
    ("fixture-sensor-default", 1),
    ("fixture-local-compact", 1),
    ("fixture-distant-enabled", 1),
    ("fixture-audition-enabled", 1),
    ("fixture-audition-compact", 1),
}


class SensoryObservationStore:
    """Validate immutable frames without granting semantic or action authority."""

    def __init__(self, capacity_per_agent_channel: int = 64, assignments=None,
                 run_id: str = "fixture-run-1", world_epoch: int = 1):
        if capacity_per_agent_channel < 1:
            raise ValueError("sensory capacity must be positive")
        _nonempty(run_id, "sensory store run_id")
        _integer(world_epoch, "sensory store world_epoch", minimum=1)
        self.capacity = capacity_per_agent_channel
        self.run_id = run_id
        self.world_epoch = world_epoch
        self.assignments = dict(assignments or {
            "npc_a": ("fixture-sensor-default", 1),
            "npc_b": ("fixture-sensor-default", 1),
        })
        self._frames: dict[tuple[str, str], list[dict[str, Any]]] = {}
        self._by_id: dict[str, dict[str, Any]] = {}
        self._latest_order: dict[tuple[str, str, str], tuple[int, int]] = {}
        self._rejections: list[dict[str, str]] = []

    def admit(self, packet: dict[str, Any], extension: dict[str, Any]) -> dict[str, Any]:
        validated = _validate_extension(
            packet, extension, self.assignments, self.run_id, self.world_epoch
        )
        pending = []
        pending_ids: dict[str, dict[str, Any]] = {}
        pending_counts: dict[tuple[str, str], int] = {}
        pending_order = dict(self._latest_order)
        for frame in validated["frames"]:
            existing = self._by_id.get(frame["frame_id"], pending_ids.get(frame["frame_id"]))
            if existing is not None:
                if existing != frame:
                    raise ObservationError("sensory frame ID replayed with different contents")
                continue
            key = (frame["agent_id"], frame["channel"])
            projected = len(self._frames.get(key, [])) + pending_counts.get(key, 0) + 1
            if projected > self.capacity:
                raise ObservationError("sensory frame capacity reached for agent/channel")
            order_key = (frame["agent_id"], frame["sensor_id"], frame["channel"])
            order = (frame["sample_seq"], frame["capture_window"]["end_us"])
            previous = pending_order.get(order_key)
            if previous is not None and (order[0] <= previous[0] or order[1] <= previous[1]):
                raise ObservationError("sensory frame sequence or capture time would roll latest backward")
            pending.append((key, frame))
            pending_ids[frame["frame_id"]] = frame
            pending_counts[key] = pending_counts.get(key, 0) + 1
            pending_order[order_key] = order
        for key, frame in pending:
            stored = deepcopy(frame)
            self._frames.setdefault(key, []).append(stored)
            self._by_id[stored["frame_id"]] = stored
            order_key = (stored["agent_id"], stored["sensor_id"], stored["channel"])
            self._latest_order[order_key] = (
                stored["sample_seq"], stored["capture_window"]["end_us"]
            )
        return {
            "accepted": True,
            "delivery_observation_id": validated["delivery_observation_id"],
            "new_frames": len(pending),
        }

    def record_rejection(self, packet: dict[str, Any], error: ObservationError) -> dict[str, Any]:
        record = {
            "observation_id": str(packet.get("observation_id", "")),
            "agent_id": str(packet.get("agent_id", "")),
            "detail": str(error),
        }
        if len(self._rejections) < self.capacity:
            self._rejections.append(record)
        return {"accepted": False, "error": "invalid_sensory_extension", "detail": str(error)}

    def snapshot(self) -> dict[str, Any]:
        frames = [deepcopy(frame) for key in sorted(self._frames)
                  for frame in self._frames[key]]
        latest = {
            agent_id: {
                channel: deepcopy(items[-1])
                for (stored_agent, channel), items in sorted(self._frames.items())
                if stored_agent == agent_id and items
            }
            for agent_id in sorted({key[0] for key in self._frames})
        }
        return {
            "schema_version": SCHEMA_VERSION,
            "authority": "read-only-sensory-observation; not-Experience-canonical-or-action",
            "capacity_per_agent_channel": self.capacity,
            "run_id": self.run_id,
            "world_epoch": self.world_epoch,
            "assignments": {
                agent: {"profile_id": value[0], "profile_revision": value[1]}
                for agent, value in sorted(self.assignments.items())
            },
            "count": len(frames),
            "frames": frames,
            "latest_by_agent": latest,
            "rejection_count": len(self._rejections),
            "rejections": deepcopy(self._rejections),
        }


def split_sensory_extension(packet: dict[str, Any], store: SensoryObservationStore | None):
    """Return a legacy packet with the extension removed from all old consumers."""
    legacy = deepcopy(packet)
    observation = legacy.get("observation")
    if not isinstance(observation, dict):
        return legacy, None
    extension = observation.pop("sensory_extension", None)
    if extension is None or store is None:
        return legacy, None
    if not isinstance(extension, dict):
        error = ObservationError("observation.sensory_extension must be an object")
        return legacy, store.record_rejection(legacy, error)
    try:
        return legacy, store.admit(legacy, extension)
    except ObservationError as exc:
        return legacy, store.record_rejection(legacy, exc)


def _validate_extension(packet, extension, assignments, expected_run_id, expected_world_epoch):
    required = {
        "schema_version", "run_id", "world_epoch", "agent_id",
        "delivery_observation_id", "delivery_world_tick", "delivery_time_us", "frames",
    }
    if set(extension) != required:
        raise ObservationError("sensory extension fields do not match v1 allowlist")
    if extension["schema_version"] != SCHEMA_VERSION:
        raise ObservationError("unsupported sensory extension schema")
    agent_id = packet.get("agent_id")
    _nonempty(agent_id, "sensory packet agent_id")
    _nonempty(extension["agent_id"], "sensory extension agent_id")
    if extension["agent_id"] != agent_id or agent_id not in assignments:
        raise ObservationError("sensory extension agent/profile assignment mismatch")
    if extension["delivery_observation_id"] != packet.get("observation_id"):
        raise ObservationError("sensory delivery observation does not match packet")
    if extension["delivery_world_tick"] != packet.get("tick"):
        raise ObservationError("sensory delivery tick does not match packet")
    _nonempty(extension["run_id"], "sensory run_id")
    _integer(extension["world_epoch"], "sensory world_epoch", minimum=1)
    if extension["run_id"] != expected_run_id or extension["world_epoch"] != expected_world_epoch:
        raise ObservationError("sensory extension run or world epoch does not match active context")
    _integer(extension["delivery_time_us"], "sensory delivery_time_us", minimum=0)
    if not isinstance(extension["frames"], list) or len(extension["frames"]) > 4:
        raise ObservationError("sensory frames must be a list of at most four")
    frames = [_validate_frame(frame, extension, assignments[agent_id])
              for frame in extension["frames"]]
    result = deepcopy(extension)
    result["frames"] = frames
    return result


def _validate_frame(frame, extension, assignment):
    required = {
        "frame_id", "agent_id", "sensor_id", "channel", "profile_id",
        "profile_revision", "sensor_model_revision", "sample_seq", "clock_id",
        "capture_window", "sampled_world_tick", "observer_frame_ref", "status",
        "coverage", "output_limited", "payload",
    }
    if not isinstance(frame, dict) or set(frame) != required:
        raise ObservationError("sensory frame fields do not match v1 allowlist")
    for name in ("frame_id", "sensor_id", "sensor_model_revision", "clock_id",
                 "observer_frame_ref"):
        _nonempty(frame[name], f"sensory {name}")
    if frame["agent_id"] != extension["agent_id"]:
        raise ObservationError("sensory frame agent does not match delivery agent")
    _enum(frame["channel"], CHANNELS, "sensory channel")
    _nonempty(frame["profile_id"], "sensory profile_id")
    _integer(frame["profile_revision"], "sensory profile_revision", minimum=1)
    profile = (frame["profile_id"], frame["profile_revision"])
    if profile not in PROFILE_REGISTRY or profile != assignment:
        raise ObservationError("sensory frame profile is not assigned to agent")
    _integer(frame["sample_seq"], "sensory sample_seq", minimum=0)
    _integer(frame["sampled_world_tick"], "sensory sampled_world_tick", minimum=0)
    if frame["sampled_world_tick"] > extension["delivery_world_tick"]:
        raise ObservationError("sensory frame cannot be sampled after delivery tick")
    window = frame["capture_window"]
    if not isinstance(window, dict) or set(window) != {"kind", "start_us", "end_us"}:
        raise ObservationError("invalid sensory capture window")
    _enum(window["kind"], {"instant", "interval"}, "sensory capture window kind")
    _integer(window["start_us"], "sensory start_us", minimum=0)
    _integer(window["end_us"], "sensory end_us", minimum=0)
    if window["start_us"] > window["end_us"] or window["end_us"] > extension["delivery_time_us"]:
        raise ObservationError("invalid sensory capture time ordering")
    if window["kind"] == "instant" and window["start_us"] != window["end_us"]:
        raise ObservationError("instant sensory capture must have zero duration")
    _enum(frame["status"], STATUSES, "sensory status")
    _enum(frame["coverage"], COVERAGE, "sensory coverage")
    if not isinstance(frame["output_limited"], bool) or not isinstance(frame["payload"], dict):
        raise ObservationError("invalid sensory output metadata")
    if frame["channel"] == "vision_local":
        if set(frame["payload"]) != {"visible_count"}:
            raise ObservationError("vision_local payload fields do not match allowlist")
        _integer(frame["payload"]["visible_count"], "sensory visible_count", minimum=0)
    elif frame["channel"] == "vision_distant":
        _validate_distant_payload(frame["payload"])
    else:
        _validate_audition_payload(frame["payload"], window)
    if frame["status"] == "UNAVAILABLE" and (
            frame["coverage"] != "UNAVAILABLE" or any(frame["payload"].values())):
        raise ObservationError("unavailable sensory frame must have unavailable empty payload")
    result = deepcopy(frame)
    result["run_id"] = extension["run_id"]
    result["world_epoch"] = extension["world_epoch"]
    return result


def _nonempty(value, name):
    if not isinstance(value, str) or not value or len(value) > 128:
        raise ObservationError(f"{name} must be a bounded non-empty string")


def _enum(value, allowed, name):
    if not isinstance(value, str) or value not in allowed:
        raise ObservationError(f"unsupported {name}")


def _validate_distant_payload(payload):
    if set(payload) != {"features"} or not isinstance(payload["features"], list):
        raise ObservationError("vision_distant payload fields do not match allowlist")
    if len(payload["features"]) > 4:
        raise ObservationError("vision_distant feature limit exceeded")
    required = {
        "feature_id", "azimuth_interval_deg", "elevation_interval_deg",
        "angular_width_band", "angular_height_band", "color_band",
    }
    for index, feature in enumerate(payload["features"]):
        if not isinstance(feature, dict) or set(feature) != required:
            raise ObservationError(f"vision_distant feature {index} fields are invalid")
        _nonempty(feature["feature_id"], "vision_distant feature_id")
        for field in ("azimuth_interval_deg", "elevation_interval_deg"):
            interval = feature[field]
            if (not isinstance(interval, list) or len(interval) != 2 or
                    any(type(value) not in (int, float) or not isfinite(value)
                        for value in interval) or interval[0] > interval[1] or
                    interval[0] < -180 or interval[1] > 180):
                raise ObservationError(f"vision_distant {field} is invalid")
        size_bands = {"unknown", "small", "medium", "large"}
        _enum(feature["angular_width_band"], size_bands,
              "vision_distant angular_width_band")
        _enum(feature["angular_height_band"], size_bands,
              "vision_distant angular_height_band")
        _enum(feature["color_band"], {"dark_gray", "muted_red", "unknown"},
              "vision_distant color_band")


def _validate_audition_payload(payload, capture_window):
    if set(payload) != {"detections"} or not isinstance(payload["detections"], list):
        raise ObservationError("audition payload fields do not match allowlist")
    if len(payload["detections"]) > 8:
        raise ObservationError("audition detection limit exceeded")
    required = {
        "detection_id", "received_interval_us", "observer_frame_ref",
        "azimuth_interval_deg", "elevation_band", "received_strength_band",
        "dominant_band", "temporal_form",
    }
    for index, detection in enumerate(payload["detections"]):
        if not isinstance(detection, dict) or set(detection) != required:
            raise ObservationError(f"audition detection {index} fields are invalid")
        _nonempty(detection["detection_id"], "audition detection_id")
        _nonempty(detection["observer_frame_ref"], "audition observer_frame_ref")
        received = detection["received_interval_us"]
        if not isinstance(received, list) or len(received) != 2:
            raise ObservationError("audition received interval is invalid")
        _integer(received[0], "audition received start_us", minimum=0)
        _integer(received[1], "audition received end_us", minimum=0)
        if (received[0] > received[1] or received[0] < capture_window["start_us"] or
                received[1] > capture_window["end_us"]):
            raise ObservationError("audition received interval is outside capture window")
        direction = detection["azimuth_interval_deg"]
        if direction != "unknown":
            if (not isinstance(direction, list) or len(direction) != 2 or
                    any(type(value) not in (int, float) or not isfinite(value)
                        for value in direction) or direction[0] > direction[1] or
                    direction[0] < -180 or direction[1] > 180):
                raise ObservationError("audition azimuth interval is invalid")
        _enum(detection["elevation_band"], {"below", "level", "above", "unknown"},
              "audition elevation_band")
        _enum(detection["received_strength_band"], {"weak", "medium", "strong"},
              "audition received_strength_band")
        _enum(detection["dominant_band"], {"low", "mid", "high", "mixed", "unknown"},
              "audition dominant_band")
        _enum(detection["temporal_form"], {"brief", "sustained", "unknown"},
              "audition temporal_form")


def _integer(value, name, minimum):
    if not isinstance(value, int) or isinstance(value, bool) or not isfinite(value) or value < minimum:
        raise ObservationError(f"{name} must be an integer >= {minimum}")
