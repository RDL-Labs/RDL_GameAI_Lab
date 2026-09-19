"""Observation-to-action boundary for the minimal GameAI runtime.

The runtime only receives bounded observation packets. It has no access to the
Godot world reference state, and its existing action policy remains separate
from the canonical read-only RDL sidecar.
"""

from __future__ import annotations

from dataclasses import dataclass
from copy import deepcopy
import math
from typing import Any
from .expression import with_expression
from .safety_target_selection import SafetySelectionError, SafetyTargetSelectionPolicy
from .safety_danger_selection import DangerSelectionError, SafetyDangerSelectionPolicy


RUNTIME_NAME = "rdl-gameai-minimal-runtime"
FOOD_ACTION_THRESHOLD = 0.5
REST_ACTION_THRESHOLD = 0.5
SLEEP_ACTION_THRESHOLD = 0.85


class ObservationError(ValueError):
    """Raised when a bounded observation packet is malformed."""


@dataclass(frozen=True)
class RuntimeDecision:
    agent_id: str
    action_type: str
    target_id: str | None
    observation_id: str
    reason: str

    def to_json(self) -> dict[str, Any]:
        action: dict[str, Any] = {"type": self.action_type}
        if self.target_id is not None:
            action["target_id"] = self.target_id
        return {
            "agent_id": self.agent_id,
            "action": action,
            "inspection": {
                "observation_id": self.observation_id,
                "runtime": RUNTIME_NAME,
                "reason": self.reason,
            },
        }


def decide_action(packet: dict[str, Any]) -> dict[str, Any]:
    return with_expression(apply_body_constraint(packet, _decide_action(packet)))


def apply_body_constraint(packet, response):
    body = packet["observation"].get("body")
    if body is None:
        return response
    if not isinstance(body, dict):
        raise ObservationError("observation.body must be an object")
    scale = body.get("movement_scale")
    if type(scale) not in (int, float) or not math.isfinite(scale) or not 0 <= scale <= 1:
        raise ObservationError("body movement_scale must be finite in [0,1]")
    if body.get("agent_id") != packet["agent_id"]:
        raise ObservationError("body owner must match observed agent")
    if not isinstance(body.get("snapshot_id"), str) or not body["snapshot_id"]:
        raise ObservationError("body snapshot_id required")
    if type(body.get("revision")) is not int or body["revision"] < 0:
        raise ObservationError("body revision must be non-negative integer")
    response = deepcopy(response)
    if scale == 0 and response["action"]["type"] == "approach":
        response["action"] = {"type": "idle"}
        response["inspection"]["reason"] = "self body snapshot reports no movement capability"
    response["inspection"]["body"] = {
        "snapshot_id": body["snapshot_id"], "revision": body["revision"],
        "movement_scale": scale, "authority": "bounded-self-body-report",
    }
    return response


def _decide_action(packet: dict[str, Any]) -> dict[str, Any]:
    """Return a structured action for one bounded observation packet."""

    tick, agent_id, observation = _validate_packet(packet)
    observation_id = str(packet.get("observation_id") or f"obs-{tick:06d}-{agent_id}")

    visible_objects = observation.get("visible_objects", [])
    body = observation.get("body")
    if isinstance(body, dict) and body.get("safety_actions_enabled", False):
        safety = observation["safety_context"]
        danger_selection = _select_safety_danger(safety["danger_candidates"])
        selection = _select_safety_target(safety["safe_candidates"])
        selected = selection["selected"]
        if danger_selection["selected"] and selected:
            return RuntimeDecision(
                agent_id=agent_id, action_type="flee", target_id=selected["target_id"],
                observation_id=observation_id,
                reason="bounded danger exposure selects the visible safe target",
            ).to_json()
        return RuntimeDecision(
            agent_id=agent_id, action_type="idle", target_id=None,
            observation_id=observation_id,
            reason="no bounded danger exposure or no visible safe target",
        ).to_json()
    if isinstance(body, dict) and body.get("sleep_actions_enabled", False):
        if body["sleep_window"] and body["rest_need"] >= SLEEP_ACTION_THRESHOLD:
            safe_places = [
                place for place in observation.get("visible_places", [])
                if place.get("rest_capable") is True and place.get("rest_safety") == "safe"
            ]
            for place in safe_places:
                if place.get("within_reach") is True:
                    return RuntimeDecision(
                        agent_id=agent_id, action_type="sleep", target_id=str(place["id"]),
                        observation_id=observation_id,
                        reason="reachable bounded safe place selected inside the finite sleep window",
                    ).to_json()
            if safe_places:
                return RuntimeDecision(
                    agent_id=agent_id, action_type="approach", target_id=str(safe_places[0]["id"]),
                    observation_id=observation_id,
                    reason="visible bounded safe place selected inside the finite sleep window",
                ).to_json()
        return RuntimeDecision(
            agent_id=agent_id, action_type="idle", target_id=None,
            observation_id=observation_id,
            reason="bounded Sleep trigger is incomplete",
        ).to_json()
    if isinstance(body, dict) and body.get("rest_actions_enabled", False):
        if body["rest_need"] >= REST_ACTION_THRESHOLD:
            for place in observation.get("visible_places", []):
                if place.get("rest_capable") is True and place.get("within_reach") is True:
                    return RuntimeDecision(
                        agent_id=agent_id,
                        action_type="rest",
                        target_id=str(place["id"]),
                        observation_id=observation_id,
                        reason="reachable bounded rest point selected while RestNeed meets the finite threshold",
                    ).to_json()
            for place in observation.get("visible_places", []):
                if place.get("rest_capable") is True:
                    return RuntimeDecision(
                        agent_id=agent_id,
                        action_type="approach",
                        target_id=str(place["id"]),
                        observation_id=observation_id,
                        reason="visible bounded rest point selected while RestNeed meets the finite threshold",
                    ).to_json()
        return RuntimeDecision(
            agent_id=agent_id,
            action_type="idle",
            target_id=None,
            observation_id=observation_id,
            reason="RestNeed is below threshold or no bounded rest point is visible",
        ).to_json()
    if isinstance(body, dict) and body.get("food_actions_enabled", False):
        if body["food_need"] >= FOOD_ACTION_THRESHOLD:
            held_food_ids = body.get("held_food_ids", [])
            if held_food_ids:
                return RuntimeDecision(
                    agent_id=agent_id,
                    action_type="eat",
                    target_id=str(held_food_ids[0]),
                    observation_id=observation_id,
                    reason="held food selected while bounded FoodNeed meets the finite threshold",
                ).to_json()
            for item in visible_objects:
                if _is_food(item) and item.get("within_reach") is True:
                    return RuntimeDecision(
                        agent_id=agent_id,
                        action_type="pickup",
                        target_id=str(item["id"]),
                        observation_id=observation_id,
                        reason="visible food is within reach while bounded FoodNeed meets the finite threshold",
                    ).to_json()
            for item in visible_objects:
                if _is_food(item):
                    return RuntimeDecision(
                        agent_id=agent_id,
                        action_type="approach",
                        target_id=str(item["id"]),
                        observation_id=observation_id,
                        reason="visible food selected while bounded FoodNeed meets the finite threshold",
                    ).to_json()
    else:
        for item in visible_objects:
            if _is_food(item):
                return RuntimeDecision(
                    agent_id=agent_id,
                    action_type="approach",
                    target_id=str(item["id"]),
                    observation_id=observation_id,
                    reason="first visible food object selected from bounded observation",
                ).to_json()

    visible_agents = observation.get("visible_agents", [])
    if visible_agents:
        return RuntimeDecision(
            agent_id=agent_id,
            action_type="idle",
            target_id=None,
            observation_id=observation_id,
            reason="agent observed another agent, but the minimal runtime has no social action yet",
        ).to_json()

    return RuntimeDecision(
        agent_id=agent_id,
        action_type="idle",
        target_id=None,
        observation_id=observation_id,
        reason="nothing actionable inside bounded observation",
    ).to_json()


def _validate_packet(packet: dict[str, Any]) -> tuple[int, str, dict[str, Any]]:
    if not isinstance(packet, dict):
        raise ObservationError("request body must be a JSON object")

    tick = packet.get("tick")
    agent_id = packet.get("agent_id")
    observation = packet.get("observation")

    if not isinstance(tick, int) or tick < 0:
        raise ObservationError("tick must be a non-negative integer")
    if not isinstance(agent_id, str) or not agent_id:
        raise ObservationError("agent_id must be a non-empty string")
    if not isinstance(observation, dict):
        raise ObservationError("observation must be an object")

    for key in ("visible_agents", "visible_objects", "visible_places"):
        if key not in observation:
            raise ObservationError(f"observation.{key} is required")
        if not isinstance(observation[key], list):
            raise ObservationError(f"observation.{key} must be a list")

    _validate_entities(observation["visible_agents"], "visible_agents")
    _validate_entities(observation["visible_objects"], "visible_objects")
    for index, item in enumerate(observation["visible_objects"]):
        if "within_reach" in item and type(item["within_reach"]) is not bool:
            raise ObservationError(f"visible_objects[{index}].within_reach must be boolean")
    _validate_entities(observation["visible_places"], "visible_places")
    for index, place in enumerate(observation["visible_places"]):
        if "rest_capable" in place and type(place["rest_capable"]) is not bool:
            raise ObservationError(f"visible_places[{index}].rest_capable must be boolean")
        if "within_reach" in place and type(place["within_reach"]) is not bool:
            raise ObservationError(f"visible_places[{index}].within_reach must be boolean")
        if "rest_distance_band" in place and place["rest_distance_band"] not in {
            "within_reach", "near", "far", "unreachable"
        }:
            raise ObservationError(f"visible_places[{index}].rest_distance_band is unsupported")
    _validate_food_state(observation.get("body"), agent_id)
    _validate_rest_state(observation.get("body"), agent_id)
    _validate_sleep_state(observation.get("body"), agent_id)
    _validate_safety_state(observation, agent_id)

    return tick, agent_id, observation


def _validate_food_state(body: Any, agent_id: str) -> None:
    if not isinstance(body, dict):
        return
    enabled = body.get("food_actions_enabled", False)
    if type(enabled) is not bool:
        raise ObservationError("body food_actions_enabled must be boolean")
    if not enabled:
        return
    if body.get("agent_id") != agent_id:
        raise ObservationError("food body owner must match observed agent")
    food_need = body.get("food_need")
    if type(food_need) not in (int, float) or not math.isfinite(food_need) or not 0 <= food_need <= 1:
        raise ObservationError("body food_need must be finite in [0,1]")
    held = body.get("held_food_ids")
    if not isinstance(held, list) or any(not isinstance(item, str) or not item for item in held):
        raise ObservationError("body held_food_ids must contain non-empty strings")
    for index, item in enumerate(body.get("held_food_ids", [])):
        if item in body["held_food_ids"][:index]:
            raise ObservationError("body held_food_ids must be unique")


def _validate_rest_state(body: Any, agent_id: str) -> None:
    if not isinstance(body, dict):
        return
    enabled = body.get("rest_actions_enabled", False)
    if type(enabled) is not bool:
        raise ObservationError("body rest_actions_enabled must be boolean")
    if not enabled:
        return
    integration_enabled = body.get("food_rest_integration_enabled", False)
    if type(integration_enabled) is not bool:
        raise ObservationError("body food_rest_integration_enabled must be boolean")
    if body.get("food_actions_enabled", False) and integration_enabled is not True:
        raise ObservationError("Food and Rest actions cannot both be enabled in the minimal Rest slice")
    if body.get("agent_id") != agent_id:
        raise ObservationError("rest body owner must match observed agent")
    rest_need = body.get("rest_need")
    if type(rest_need) not in (int, float) or not math.isfinite(rest_need) or not 0 <= rest_need <= 1:
        raise ObservationError("body rest_need must be finite in [0,1]")


def _validate_sleep_state(body: Any, agent_id: str) -> None:
    if not isinstance(body, dict):
        return
    enabled = body.get("sleep_actions_enabled", False)
    if type(enabled) is not bool:
        raise ObservationError("body sleep_actions_enabled must be boolean")
    if not enabled:
        return
    if body.get("rest_actions_enabled") is not True:
        raise ObservationError("Sleep requires the bounded Rest body state")
    if type(body.get("sleep_window")) is not bool:
        raise ObservationError("body sleep_window must be boolean")


def _validate_safety_state(observation: dict[str, Any], agent_id: str) -> None:
    body = observation.get("body")
    if not isinstance(body, dict):
        return
    enabled = body.get("safety_actions_enabled", False)
    if type(enabled) is not bool:
        raise ObservationError("body safety_actions_enabled must be boolean")
    if not enabled:
        return
    if body.get("agent_id") != agent_id:
        raise ObservationError("safety body owner must match observed agent")
    if body.get("rest_actions_enabled", False):
        raise ObservationError("Safety actions must be isolated from Food and Rest actions")
    if body.get("food_actions_enabled", False) and body.get("food_safety_integration_enabled") is not True:
        raise ObservationError("Safety and Food require the explicit integration coordinator")
    safety = observation.get("safety_context")
    if not isinstance(safety, dict):
        raise ObservationError("observation.safety_context required")
    if safety.get("schema_version") != "bounded-safety-context-v1":
        raise ObservationError("unsupported safety_context schema")
    if type(safety.get("exposed")) is not bool:
        raise ObservationError("safety_context.exposed must be boolean")
    if type(safety.get("safe_reached")) is not bool:
        raise ObservationError("safety_context.safe_reached must be boolean")
    danger_selection = _select_safety_danger(safety.get("danger_candidates"))
    if safety["exposed"] != bool(danger_selection["selected"]):
        raise ObservationError("safety_context.exposed must match danger candidates")
    _select_safety_target(safety.get("safe_candidates"))
    reached_target_id = safety.get("reached_safe_target_id")
    if not isinstance(reached_target_id, str):
        raise ObservationError("safety_context.reached_safe_target_id must be a string")
    if safety["safe_reached"] != bool(reached_target_id):
        raise ObservationError("safe_reached must match reached_safe_target_id presence")


def _validate_entities(items: list[Any], field_name: str) -> None:
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            raise ObservationError(f"{field_name}[{index}] must be an object")
        if not isinstance(item.get("id"), str) or not item["id"]:
            raise ObservationError(f"{field_name}[{index}].id must be a non-empty string")


def _is_food(item: dict[str, Any]) -> bool:
    kind = str(item.get("kind", item.get("role", ""))).lower()
    label = str(item.get("label", "")).lower()
    return kind == "food" or "food" in label


def _select_safety_target(candidates):
    try:
        return SafetyTargetSelectionPolicy().select(candidates)
    except SafetySelectionError as exc:
        raise ObservationError(str(exc)) from exc


def _select_safety_danger(candidates):
    try:
        return SafetyDangerSelectionPolicy().select(candidates)
    except DangerSelectionError as exc:
        raise ObservationError(str(exc)) from exc
