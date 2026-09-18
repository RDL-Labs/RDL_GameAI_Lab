"""Opt-in assisted-to-autonomous Base-Food policy.

The policy receives only finite NPC-facing life context. Godot keeps world
truth and resolves movement, pickup, and deposit.
"""

from copy import deepcopy
from dataclasses import dataclass
from typing import Any

from .core import ObservationError, RuntimeDecision, apply_body_constraint
from .expression import with_expression


POLICY_ID = "base-food-assisted-trajectory-v1"
ACTIVE_CUE_BANDS = {"low", "critical", "empty"}


@dataclass
class TrajectoryState:
    goal: str
    phase: str
    target_id: str
    commitment: str = "committed"


class BaseFoodLifePolicy:
    """Keep one finite trajectory until completion or structural release."""

    def __init__(self, capacity: int = 128):
        self.capacity = capacity
        self._trajectories: dict[str, TrajectoryState] = {}
        self._decisions: dict[tuple[str, str], tuple[dict[str, Any], dict[str, Any]]] = {}

    def decide(self, packet: dict[str, Any]) -> dict[str, Any]:
        agent_id, observation_id, observation, context = _validate_life_packet(packet)
        key = (agent_id, observation_id)
        if key in self._decisions:
            original, response = self._decisions[key]
            if original != packet:
                raise ObservationError("life-policy observation ID reused with different contents")
            return deepcopy(response)
        if len(self._decisions) >= self.capacity:
            raise ObservationError("life-policy decision capacity reached; start a fresh runtime")

        body = observation["body"]
        trajectory = self._trajectories.get(agent_id)
        if trajectory is None and _should_form_goal(context):
            target_id = _first_visible_food_id(observation)
            if target_id:
                trajectory = TrajectoryState(
                    goal="replenish_base_food",
                    phase="GO_TO_SITE",
                    target_id=target_id,
                )
                self._trajectories[agent_id] = trajectory

        action_type = "idle"
        target_id = None
        reason = "no assisted Base-Food goal formed from bounded life context"
        if trajectory is not None:
            held = body.get("held_food_ids", [])
            visible = {item["id"]: item for item in observation["visible_objects"]}
            if held:
                trajectory.phase = "DEPOSIT" if context["at_base"] else "RETURN_BASE"
                action_type = "deposit" if context["at_base"] else "approach"
                target_id = context["known_base"]["id"]
                reason = "continue committed Base-Food trajectory toward deposit"
            else:
                food = visible.get(trajectory.target_id)
                if food is None:
                    del self._trajectories[agent_id]
                    trajectory = None
                    reason = "trajectory released because the Food target is no longer observed"
                elif food.get("within_reach") is True:
                    trajectory.phase = "GATHER"
                    action_type = "pickup"
                    target_id = food["id"]
                    reason = "continue committed Base-Food trajectory with gather"
                else:
                    trajectory.phase = "GO_TO_SITE"
                    action_type = "approach"
                    target_id = food["id"]
                    reason = "continue committed Base-Food trajectory toward Food Site"

        decision = RuntimeDecision(
            agent_id=agent_id,
            action_type=action_type,
            target_id=target_id,
            observation_id=observation_id,
            reason=reason,
        ).to_json()
        life = {
            "policy": POLICY_ID,
            "authority": "GameAI-local-policy; cue-is-observation-not-command",
            "cue": deepcopy(context["god_statue_cue"]),
            "observed_base_food_band": context["observed_base_food_band"],
            "short_prediction": _short_prediction(context),
            "goal": trajectory.goal if trajectory else None,
            "trajectory_phase": trajectory.phase if trajectory else "NONE",
            "commitment": trajectory.commitment if trajectory else "none",
        }
        decision["inspection"]["life"] = life
        decision = with_expression(apply_body_constraint(packet, decision))
        self._decisions[key] = (deepcopy(packet), deepcopy(decision))
        return decision

    def complete_deposit(self, agent_id: str) -> None:
        self._trajectories.pop(agent_id, None)

    def snapshot(self) -> dict[str, Any]:
        return {
            "policy": POLICY_ID,
            "trajectories": {
                agent_id: deepcopy(vars(state))
                for agent_id, state in self._trajectories.items()
            },
            "decisions": len(self._decisions),
        }


def _validate_life_packet(packet):
    if not isinstance(packet, dict):
        raise ObservationError("request body must be a JSON object")
    agent_id = packet.get("agent_id")
    observation_id = packet.get("observation_id")
    observation = packet.get("observation")
    if not isinstance(agent_id, str) or not agent_id:
        raise ObservationError("agent_id must be a non-empty string")
    if not isinstance(observation_id, str) or not observation_id:
        raise ObservationError("observation_id must be a non-empty string")
    if not isinstance(observation, dict):
        raise ObservationError("observation must be an object")
    for field in ("visible_objects", "body"):
        if field not in observation:
            raise ObservationError(f"observation.{field} is required for Base-Food policy")
    if not isinstance(observation["visible_objects"], list):
        raise ObservationError("observation.visible_objects must be a list")
    if not isinstance(observation["body"], dict):
        raise ObservationError("observation.body must be an object")

    context = observation.get("life_context")
    if not isinstance(context, dict):
        raise ObservationError("observation.life_context must be an object")
    cue = context.get("god_statue_cue")
    if not isinstance(cue, dict):
        raise ObservationError("life_context.god_statue_cue must be an object")
    if cue.get("source") != "system_assessment" or cue.get("topic") != "base_food":
        raise ObservationError("unsupported God Statue cue provenance")
    if cue.get("delivery") != "morning":
        raise ObservationError("God Statue Food cue must use the finite morning delivery")
    if cue.get("band") not in {"enough", "low", "critical", "empty"}:
        raise ObservationError("unsupported God Statue Food cue band")
    if context.get("observed_base_food_band") not in {"enough", "low", "critical", "empty"}:
        raise ObservationError("unsupported observed Base Food band")
    known_base = context.get("known_base")
    if not isinstance(known_base, dict) or not isinstance(known_base.get("id"), str) or not known_base["id"]:
        raise ObservationError("life_context.known_base.id is required")
    if type(context.get("at_base")) is not bool:
        raise ObservationError("life_context.at_base must be boolean")
    return agent_id, observation_id, observation, context


def _should_form_goal(context):
    return (
        context["god_statue_cue"]["band"] in ACTIVE_CUE_BANDS
        and context["observed_base_food_band"] in ACTIVE_CUE_BANDS
    )


def _first_visible_food_id(observation):
    for item in observation["visible_objects"]:
        kind = str(item.get("kind", item.get("role", ""))).lower()
        if kind == "food" or "food" in str(item.get("label", "")).lower():
            return str(item["id"])
    return None


def _short_prediction(context):
    if context["observed_base_food_band"] in ACTIVE_CUE_BANDS:
        return "base_food_shortage_may_worsen"
    return "base_food_stable"
