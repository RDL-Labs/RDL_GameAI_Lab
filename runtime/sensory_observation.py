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
}


class SensoryObservationStore:
    """Validate immutable frames without granting semantic or action authority."""

    def __init__(self, capacity_per_agent_channel: int = 64, assignments=None):
        if capacity_per_agent_channel < 1:
            raise ValueError("sensory capacity must be positive")
        self.capacity = capacity_per_agent_channel
        self.assignments = dict(assignments or {
            "npc_a": ("fixture-sensor-default", 1),
            "npc_b": ("fixture-sensor-default", 1),
        })
        self._frames: dict[tuple[str, str], list[dict[str, Any]]] = {}
        self._by_id: dict[str, dict[str, Any]] = {}

    def admit(self, packet: dict[str, Any], extension: dict[str, Any]) -> dict[str, Any]:
        validated = _validate_extension(packet, extension, self.assignments)
        pending = []
        pending_ids: dict[str, dict[str, Any]] = {}
        pending_counts: dict[tuple[str, str], int] = {}
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
            pending.append((key, frame))
            pending_ids[frame["frame_id"]] = frame
            pending_counts[key] = pending_counts.get(key, 0) + 1
        for key, frame in pending:
            stored = deepcopy(frame)
            self._frames.setdefault(key, []).append(stored)
            self._by_id[stored["frame_id"]] = stored
        return {
            "accepted": True,
            "delivery_observation_id": validated["delivery_observation_id"],
            "new_frames": len(pending),
        }

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
            "assignments": {
                agent: {"profile_id": value[0], "profile_revision": value[1]}
                for agent, value in sorted(self.assignments.items())
            },
            "count": len(frames),
            "frames": frames,
            "latest_by_agent": latest,
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
        raise ObservationError("observation.sensory_extension must be an object")
    return legacy, store.admit(legacy, extension)


def _validate_extension(packet, extension, assignments):
    required = {
        "schema_version", "run_id", "world_epoch", "agent_id",
        "delivery_observation_id", "delivery_world_tick", "delivery_time_us", "frames",
    }
    if set(extension) != required:
        raise ObservationError("sensory extension fields do not match v1 allowlist")
    if extension["schema_version"] != SCHEMA_VERSION:
        raise ObservationError("unsupported sensory extension schema")
    agent_id = packet.get("agent_id")
    if extension["agent_id"] != agent_id or agent_id not in assignments:
        raise ObservationError("sensory extension agent/profile assignment mismatch")
    if extension["delivery_observation_id"] != packet.get("observation_id"):
        raise ObservationError("sensory delivery observation does not match packet")
    if extension["delivery_world_tick"] != packet.get("tick"):
        raise ObservationError("sensory delivery tick does not match packet")
    _nonempty(extension["run_id"], "sensory run_id")
    _integer(extension["world_epoch"], "sensory world_epoch", minimum=1)
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
    if frame["channel"] not in CHANNELS:
        raise ObservationError("unsupported sensory channel")
    if frame["channel"] != "vision_local":
        raise ObservationError("sensory channel is planned but not enabled in OBS-1")
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
    if window["kind"] not in {"instant", "interval"}:
        raise ObservationError("unsupported sensory capture window kind")
    _integer(window["start_us"], "sensory start_us", minimum=0)
    _integer(window["end_us"], "sensory end_us", minimum=0)
    if window["start_us"] > window["end_us"] or window["end_us"] > extension["delivery_time_us"]:
        raise ObservationError("invalid sensory capture time ordering")
    if window["kind"] == "instant" and window["start_us"] != window["end_us"]:
        raise ObservationError("instant sensory capture must have zero duration")
    if frame["status"] not in STATUSES or frame["coverage"] not in COVERAGE:
        raise ObservationError("unsupported sensory status or coverage")
    if not isinstance(frame["output_limited"], bool) or not isinstance(frame["payload"], dict):
        raise ObservationError("invalid sensory output metadata")
    if set(frame["payload"]) != {"visible_count"}:
        raise ObservationError("vision_local payload fields do not match OBS-1 allowlist")
    _integer(frame["payload"]["visible_count"], "sensory visible_count", minimum=0)
    return deepcopy(frame)


def _nonempty(value, name):
    if not isinstance(value, str) or not value or len(value) > 128:
        raise ObservationError(f"{name} must be a bounded non-empty string")


def _integer(value, name, minimum):
    if not isinstance(value, int) or isinstance(value, bool) or not isfinite(value) or value < minimum:
        raise ObservationError(f"{name} must be an integer >= {minimum}")
