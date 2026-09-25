"""Finite Experience records derived from accepted Territory Beast fact events."""

from copy import deepcopy
import hashlib
import json
from typing import Any

from .territory_beast_world import EVENT_SCHEMA


STORE_ID = "territory-interaction-experience-v1"


class TerritoryExperienceError(ValueError):
    pass


class TerritoryExperienceStore:
    """Retain direct and observed event records without interpreting danger."""

    def __init__(self, capacity: int = 128) -> None:
        if type(capacity) is not int or capacity <= 0:
            raise TerritoryExperienceError("capacity must be a positive integer")
        self.capacity = capacity
        self._records: dict[str, dict[str, Any]] = {}
        self.capacity_rejections = 0

    def record_direct(self, event: dict[str, Any]) -> dict[str, Any] | None:
        _validate_event(event)
        return self._admit(
            experiencer_id=event["agent_id"],
            perspective="direct_participant",
            event=event,
            observation_tick=event["tick"],
        )

    def record_observed(self, *, observer_id: str, event: dict[str, Any],
                        observation_tick: int) -> dict[str, Any] | None:
        _validate_event(event)
        if not isinstance(observer_id, str) or not observer_id:
            raise TerritoryExperienceError("observer_id must be non-empty")
        if observer_id == event["agent_id"]:
            raise TerritoryExperienceError("participant must use direct Experience admission")
        if type(observation_tick) is not int or observation_tick < event["tick"]:
            raise TerritoryExperienceError("observation tick cannot precede the World event")
        return self._admit(
            experiencer_id=observer_id,
            perspective="bounded_observer",
            event=event,
            observation_tick=observation_tick,
        )

    def _admit(self, *, experiencer_id: str, perspective: str,
               event: dict[str, Any], observation_tick: int) -> dict[str, Any] | None:
        identity = [STORE_ID, experiencer_id, perspective, event["event_id"]]
        record_id = hashlib.sha256(json.dumps(identity).encode()).hexdigest()
        record = {
            "record_id": record_id,
            "agent_id": experiencer_id,
            "perspective": perspective,
            "source_event_id": event["event_id"],
            "source_event_tick": event["tick"],
            "observation_tick": observation_tick,
            "interaction": {
                "subject_agent_id": event["agent_id"],
                "beast_id": event["beast_id"],
                "territory_id": event["territory_id"],
                "event_type": event["event_type"],
                "beast_response": event["beast_response"],
                "proximity": event["proximity"],
                "outcome": event["outcome"],
                "context": deepcopy(event.get("interaction_context")),
            },
            "world_consequence": (deepcopy(event["world_consequence"])
                                  if perspective == "direct_participant" else None),
            "provenance": {
                "source_schema": event["schema"],
                "source_authority": event["authority"],
                "adapter": STORE_ID,
            },
            "authority": "GameAI-local-Experience; not-danger-belief-candidate-H-theta-M_delta-M_B-or-T1",
        }
        existing = self._records.get(record_id)
        if existing is not None:
            if existing != record:
                raise TerritoryExperienceError("Experience replay changed frozen event provenance")
            return deepcopy(existing)
        if len(self._records) >= self.capacity:
            self.capacity_rejections += 1
            return None
        self._records[record_id] = record
        return deepcopy(record)

    def snapshot(self) -> dict[str, Any]:
        return {
            "store": STORE_ID,
            "records": deepcopy(list(self._records.values())),
            "capacity": self.capacity,
            "capacity_rejections": self.capacity_rejections,
            "retention": "process lifetime; no decay or eviction",
            "authority": "read-only-territory-Experience; not-candidate-or-canonical-authority",
        }


def _validate_event(event: dict[str, Any]) -> None:
    if not isinstance(event, dict) or event.get("schema") != EVENT_SCHEMA:
        raise TerritoryExperienceError("unsupported Territory Beast event")
    for field in ("event_id", "agent_id", "beast_id", "territory_id",
                  "event_type", "beast_response", "proximity", "authority"):
        if not isinstance(event.get(field), str) or not event[field]:
            raise TerritoryExperienceError(f"event {field} must be non-empty")
    if type(event.get("tick")) is not int or event["tick"] < 0:
        raise TerritoryExperienceError("event tick must be a non-negative integer")
    if any(field in event for field in ("danger", "beast_is_dangerous", "threat_score")):
        raise TerritoryExperienceError("interpretive danger labels are not admissible facts")
    context = event.get("interaction_context")
    if context is not None:
        if not isinstance(context, dict):
            raise TerritoryExperienceError("interaction_context must be an object")
        if any(field in context for field in ("danger", "dangerous", "threat_score")):
            raise TerritoryExperienceError("interaction context cannot inject danger meaning")
