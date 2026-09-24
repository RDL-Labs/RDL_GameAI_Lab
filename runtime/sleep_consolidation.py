"""S4 coordinator for a real Sleep result and the S1-S3 shadow path."""

from copy import deepcopy
from typing import Any

from .core import ObservationError
from .functions.deep_similarity import build_deep_similarity_shadow
from .functions.experience_profile import build_relation_profiles
from .sleep_window import SleepExperienceWindowStore


COORDINATOR_ID = "sleep-consolidation-vertical-v1"


class SleepConsolidationCoordinator:
    """Correlate one bounded Sleep result before running local shadow compute."""

    def __init__(self, capacity: int = 128):
        self.capacity = capacity
        self._decisions: dict[tuple[str, str], dict[str, Any]] = {}
        self._results: dict[str, dict[str, Any]] = {}
        self._prepared: dict[tuple[str, str], dict[str, Any]] = {}
        self._windows = SleepExperienceWindowStore(capacity=capacity)

    def register_decision(self, packet: dict[str, Any], decision: dict[str, Any],
                          history_snapshot: dict[str, Any]) -> None:
        observation = packet.get("observation", {})
        body = observation.get("body", {})
        agent_id = decision.get("agent_id")
        sleep_cycle = body.get("sleep_consolidation_cycle") if isinstance(body, dict) else None
        if not isinstance(sleep_cycle, str) or not sleep_cycle:
            return
        if not isinstance(agent_id, str) or not agent_id:
            raise ObservationError("Sleep consolidation agent identity is incomplete")
        prepared_key = (agent_id, sleep_cycle)
        if prepared_key not in self._prepared:
            window = self._windows.form_window(
                history_snapshot,
                agent_id=agent_id,
                sleep_cycle=sleep_cycle,
                formation_tick=packet.get("tick"),
                enabled=True,
            )
            self._prepared[prepared_key] = {
                "window": window,
                "relation_profiles": build_relation_profiles(window, history_snapshot),
            }

        action = decision.get("action", {})
        if action.get("type") != "sleep":
            return
        observation_id = decision.get("inspection", {}).get("observation_id")
        target_id = action.get("target_id")
        if not all(isinstance(item, str) and item for item in (
            agent_id, observation_id, target_id
        )):
            raise ObservationError("Sleep decision identity is incomplete")
        places = observation.get("visible_places", [])
        safe_target = next((place for place in places if (
            place.get("id") == target_id
            and place.get("rest_capable") is True
            and place.get("rest_safety") == "safe"
            and place.get("within_reach") is True
        )), None)
        if not (
            isinstance(body, dict)
            and body.get("sleep_actions_enabled") is True
            and body.get("sleep_window") is True
            and safe_target is not None
        ):
            raise ObservationError("Sleep consolidation requires the bounded safe Sleep decision")
        key = (agent_id, observation_id)
        entry = {
            "agent_id": agent_id,
            "source_observation_id": observation_id,
            "target_id": target_id,
            "decision_tick": packet.get("tick"),
            "sleep_cycle": sleep_cycle,
        }
        existing = self._decisions.get(key)
        if existing is not None and existing != entry:
            raise ObservationError("Sleep observation ID reused with a different decision")
        if existing is None and len(self._decisions) >= self.capacity:
            raise ObservationError("Sleep consolidation decision capacity reached")
        self._decisions[key] = entry

    def record_result(self, payload: dict[str, Any], history_snapshot: dict[str, Any]) -> dict[str, Any]:
        _validate_result_shape(payload)
        result_id = payload["result_id"]
        existing = self._results.get(result_id)
        if existing is not None:
            if existing["reported_result"] != payload:
                raise ObservationError("conflicting Sleep result replay")
            return deepcopy(existing)

        key = (payload["agent_id"], payload["source_observation_id"])
        decision = self._decisions.get(key)
        if decision is None:
            raise ObservationError("Sleep result has no registered source decision")
        if payload["target_id"] != decision["target_id"]:
            raise ObservationError("Sleep result target differs from the registered decision")
        if payload["sleep_cycle"] != decision["sleep_cycle"]:
            raise ObservationError("Sleep result cycle differs from the prepared window")
        if payload["subsequent_observation_id"] == payload["source_observation_id"]:
            raise ObservationError("Sleep result requires a distinct subsequent observation")
        if type(decision["decision_tick"]) is not int or payload["tick"] < decision["decision_tick"]:
            raise ObservationError("Sleep result tick precedes its decision")

        before_history = deepcopy(history_snapshot)
        prepared = self._prepared.get((payload["agent_id"], payload["sleep_cycle"]))
        if prepared is None:
            raise ObservationError("Sleep result has no prepared consolidation window")
        window = deepcopy(prepared["window"])
        profiles = deepcopy(prepared["relation_profiles"])
        deep = None
        status = "INSUFFICIENT_EVIDENCE"
        if window["status"] == "READY":
            deep = build_deep_similarity_shadow(
                window, profiles, formation_tick=payload["tick"]
            )
            status = deep["status"]
        if history_snapshot != before_history:
            raise ObservationError("Sleep consolidation mutated raw Experience")

        record = {
            "result_id": result_id,
            "status": status,
            "agent_id": payload["agent_id"],
            "sleep_cycle": payload["sleep_cycle"],
            "reported_result": deepcopy(payload),
            "window": window,
            "relation_profiles": profiles,
            "deep_similarity": deep,
            "candidate": deepcopy(deep["candidate"]) if deep else None,
            "coordinator": COORDINATOR_ID,
            "authority": "GameAI-local-Sleep-consolidation-shadow; not-action-E-H-theta-M_delta-M_B-prime-or-T1",
        }
        self._results[result_id] = deepcopy(record)
        return deepcopy(record)

    def snapshot(self) -> dict[str, Any]:
        return {
            "authority": "read-only-Sleep-consolidation-shadow",
            "coordinator": COORDINATOR_ID,
            "pending_sleep_results": len(self._decisions) - len(self._results),
            "results": deepcopy(list(self._results.values())),
        }


def _validate_result_shape(payload: dict[str, Any]) -> None:
    if not isinstance(payload, dict):
        raise ObservationError("Sleep result must be an object")
    for field in (
        "result_id", "agent_id", "source_observation_id",
        "subsequent_observation_id", "target_id", "sleep_cycle",
    ):
        if not isinstance(payload.get(field), str) or not payload[field].strip():
            raise ObservationError(f"Sleep result {field} must be non-empty")
    if payload.get("outcome") != "bounded_sleep_completed":
        raise ObservationError("unsupported Sleep result outcome")
    if type(payload.get("tick")) is not int or payload["tick"] < 0:
        raise ObservationError("Sleep result tick must be a non-negative integer")
