"""Observation-to-action boundary for the minimal GameAI runtime.

The runtime only receives bounded observation packets. It has no access to the
Godot world reference state, and it does not implement RDL semantics.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


RUNTIME_NAME = "rdl-gameai-minimal-runtime"


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
    """Return a structured action for one bounded observation packet."""

    tick, agent_id, observation = _validate_packet(packet)
    observation_id = f"obs-{tick:06d}-{agent_id}"

    visible_objects = observation.get("visible_objects", [])
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
            reason="agent observed another agent, but PR1 does not resolve interaction",
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
    _validate_entities(observation["visible_places"], "visible_places")

    return tick, agent_id, observation


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

