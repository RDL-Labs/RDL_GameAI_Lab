"""Opt-in finite Rescue Goal and approach trajectory."""

from copy import deepcopy
from dataclasses import dataclass
from typing import Any

from .core import ObservationError, RuntimeDecision, apply_body_constraint, decide_action
from .expression import with_expression


POLICY_ID = "rescue-approach-trajectory-v1"


@dataclass
class RescueTrajectory:
    target_id: str
    phase: str = "APPROACH_INCAPACITATED"
    commitment: str = "committed"


class RescueTrajectoryPolicy:
    """Commit once to one bounded incapacitated agent and approach it."""

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
        trajectory = self._trajectories.get(agent_id)
        released_target = None
        if trajectory is not None and trajectory.target_id not in candidates:
            released_target = trajectory.target_id
            del self._trajectories[agent_id]
            trajectory = None
            phase = "RELEASED"
            action_type = "idle"
            target_id = None
            reason = "committed incapacitated agent is no longer bounded and visible"
        else:
            if trajectory is None and candidates:
                selected_id = sorted(candidates)[0]
                trajectory = RescueTrajectory(target_id=selected_id)
                self._trajectories[agent_id] = trajectory
            if trajectory is None:
                phase = "NONE"
                action_type = "idle"
                target_id = None
                reason = "no bounded incapacitated agent formed a Rescue goal"
            elif candidates[trajectory.target_id]["within_reach"]:
                trajectory.phase = "READY_TO_RESCUE"
                phase = trajectory.phase
                action_type = "idle"
                target_id = None
                reason = "committed incapacitated agent reached; rescue resolution remains deferred"
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
            "goal": "reach_incapacitated_agent" if trajectory else None,
            "trajectory_phase": phase,
            "target_id": trajectory.target_id if trajectory else released_target,
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
                }
                for agent_id, trajectory in self._trajectories.items()
            },
            "decision_count": len(self._decisions),
        }
