"""Opt-in finite Rescue Goal, carrying, and safe-place delivery trajectory."""

from copy import deepcopy
from dataclasses import dataclass
from typing import Any

from .core import ObservationError, RuntimeDecision, apply_body_constraint, decide_action
from .expression import with_expression


POLICY_ID = "rescue-safe-delivery-trajectory-v1"


@dataclass
class RescueTrajectory:
    target_id: str
    safe_target_id: str | None = None
    phase: str = "APPROACH_INCAPACITATED"
    commitment: str = "committed"


class RescueTrajectoryPolicy:
    """Commit to one incapacitated agent and one bounded safe delivery target."""

    def __init__(self, capacity: int = 128):
        self.capacity = capacity
        self._trajectories: dict[str, RescueTrajectory] = {}
        self._decisions: dict[tuple[str, str], tuple[dict[str, Any], dict[str, Any]]] = {}

    def decide(self, packet: dict[str, Any]) -> dict[str, Any]:
        decide_action(packet)  # Validate without granting the core policy Rescue authority.
        agent_id = packet["agent_id"]
        observation_id = packet["observation_id"]
        key = (agent_id, observation_id)
        if key in self._decisions:
            original, response = self._decisions[key]
            if original != packet:
                raise ObservationError("Rescue observation ID reused with different contents")
            return deepcopy(response)
        if len(self._decisions) >= self.capacity:
            raise ObservationError("Rescue policy decision capacity reached; start a fresh runtime")

        candidates = {
            item["id"]: item for item in packet["observation"]["visible_agents"]
            if item.get("condition") == "incapacitated"
        }
        body = packet["observation"].get("body", {})
        carried_agent_id = body.get("carried_agent_id", "") if isinstance(body, dict) else ""
        last_delivery = body.get("last_rescue_delivery", {}) if isinstance(body, dict) else {}
        safe_places = {
            item["id"]: item for item in packet["observation"]["visible_places"]
            if item.get("rest_safety") == "safe" and item.get("rest_capable") is True
        }
        trajectory = self._trajectories.get(agent_id)
        released_target = None
        completed_target = None
        if (
            trajectory is not None
            and isinstance(last_delivery, dict)
            and last_delivery.get("agent_id") == trajectory.target_id
            and last_delivery.get("place_id") == trajectory.safe_target_id
        ):
            completed_target = trajectory.target_id
            del self._trajectories[agent_id]
            trajectory = None
            phase = "COMPLETE"
            action_type = "idle"
            target_id = None
            reason = "World-owned safe-place delivery observed in subsequent body snapshot"
        elif trajectory is not None and trajectory.target_id not in candidates and carried_agent_id != trajectory.target_id:
            released_target = trajectory.target_id
            del self._trajectories[agent_id]
            trajectory = None
            phase = "RELEASED"
            action_type = "idle"
            target_id = None
            reason = "committed incapacitated agent is no longer bounded and visible"
        else:
            if trajectory is None and candidates and completed_target is None:
                selected_id = sorted(candidates)[0]
                trajectory = RescueTrajectory(target_id=selected_id)
                self._trajectories[agent_id] = trajectory
            if trajectory is None and completed_target is None:
                phase = "NONE"
                action_type = "idle"
                target_id = None
                reason = "no bounded incapacitated agent formed a Rescue goal"
            elif trajectory is not None and carried_agent_id == trajectory.target_id:
                if trajectory.safe_target_id is None and safe_places:
                    trajectory.safe_target_id = sorted(safe_places)[0]
                if trajectory.safe_target_id is None:
                    trajectory.phase = "DELIVERY_BLOCKED"
                    phase = trajectory.phase
                    action_type = "idle"
                    target_id = None
                    reason = "carried agent retained while no bounded safe place is visible"
                elif trajectory.safe_target_id not in safe_places:
                    trajectory.phase = "DELIVERY_BLOCKED"
                    phase = trajectory.phase
                    action_type = "idle"
                    target_id = None
                    reason = "committed safe delivery target is no longer bounded and visible"
                elif safe_places[trajectory.safe_target_id].get("rescue_within_reach") is True:
                    trajectory.phase = "DELIVER_TO_SAFE"
                    phase = trajectory.phase
                    action_type = "deliver"
                    target_id = trajectory.safe_target_id
                    reason = "deliver carried incapacitated agent to committed safe place"
                else:
                    trajectory.phase = "CARRY_TO_SAFE"
                    phase = trajectory.phase
                    action_type = "approach"
                    target_id = trajectory.safe_target_id
                    reason = "continue carrying incapacitated agent toward fixed safe place"
            elif trajectory is not None and candidates[trajectory.target_id]["within_reach"]:
                trajectory.phase = "READY_TO_RESCUE"
                phase = trajectory.phase
                action_type = "rescue"
                target_id = trajectory.target_id
                reason = "attach reached incapacitated agent for bounded safe-place delivery"
            else:
                trajectory.phase = "APPROACH_INCAPACITATED"
                phase = trajectory.phase
                action_type = "approach"
                target_id = trajectory.target_id
                reason = "continue committed Rescue trajectory toward the fixed incapacitated agent"

        decision = RuntimeDecision(
            agent_id=agent_id, action_type=action_type, target_id=target_id,
            observation_id=observation_id, reason=reason,
        ).to_json()
        decision["inspection"]["rescue"] = {
            "policy": POLICY_ID,
            "authority": "GameAI-local-Rescue-policy; not-World-truth-recovery-M_B-or-H",
            "goal": "deliver_incapacitated_agent_to_safe_place" if trajectory else None,
            "trajectory_phase": phase,
            "target_id": trajectory.target_id if trajectory else (completed_target or released_target),
            "safe_target_id": trajectory.safe_target_id if trajectory else None,
            "commitment": trajectory.commitment if trajectory else "none",
            "candidate_ids": sorted(candidates),
        }
        decision = with_expression(apply_body_constraint(packet, decision))
        self._decisions[key] = (deepcopy(packet), deepcopy(decision))
        return decision

    def snapshot(self):
        return {
            "policy": POLICY_ID,
            "trajectories": {
                agent_id: {
                    "target_id": trajectory.target_id,
                    "phase": trajectory.phase,
                    "commitment": trajectory.commitment,
                    "safe_target_id": trajectory.safe_target_id,
                }
                for agent_id, trajectory in self._trajectories.items()
            },
            "decision_count": len(self._decisions),
        }
