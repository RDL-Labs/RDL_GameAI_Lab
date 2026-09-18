"""Opt-in finite Safety escape trajectory policy."""

from copy import deepcopy
from dataclasses import dataclass
from typing import Any

from .core import ObservationError, RuntimeDecision, apply_body_constraint, decide_action
from .expression import with_expression


POLICY_ID = "safety-escape-trajectory-v1"


@dataclass
class SafetyTrajectory:
    target_id: str
    phase: str = "FLEE_TO_SAFE"


class SafetyTrajectoryPolicy:
    def __init__(self, capacity: int = 128):
        self.capacity = capacity
        self._trajectories: dict[str, SafetyTrajectory] = {}
        self._decisions: dict[tuple[str, str], tuple[dict[str, Any], dict[str, Any]]] = {}

    def decide(self, packet: dict[str, Any]) -> dict[str, Any]:
        decide_action(packet)  # Validate the shared bounded packet contract.
        agent_id = packet["agent_id"]
        observation_id = packet["observation_id"]
        observation = packet["observation"]
        body = observation["body"]
        if body.get("safety_actions_enabled") is not True:
            raise ObservationError("Safety trajectory requires enabled bounded Safety state")
        key = (agent_id, observation_id)
        if key in self._decisions:
            original, response = self._decisions[key]
            if original != packet:
                raise ObservationError("Safety observation ID reused with different contents")
            return deepcopy(response)
        if len(self._decisions) >= self.capacity:
            raise ObservationError("Safety policy decision capacity reached; start a fresh runtime")

        safety = observation["safety_context"]
        trajectory = self._trajectories.get(agent_id)
        completed_target = None
        if trajectory is not None and safety["safe_reached"]:
            completed_target = trajectory.target_id
            del self._trajectories[agent_id]
            trajectory = None
            phase = "COMPLETE"
            action_type = "idle"
            target_id = None
            reason = "committed safe target reached in subsequent bounded observation"
        else:
            if trajectory is None and safety["exposed"] and safety["safe_target_id"]:
                trajectory = SafetyTrajectory(target_id=safety["safe_target_id"])
                self._trajectories[agent_id] = trajectory
            if trajectory is None:
                phase = "NONE"
                action_type = "idle"
                target_id = None
                reason = "no bounded danger exposure formed a Safety trajectory"
            elif safety["safe_target_id"] != trajectory.target_id:
                completed_target = trajectory.target_id
                del self._trajectories[agent_id]
                trajectory = None
                phase = "RELEASED"
                action_type = "idle"
                target_id = None
                reason = "committed safe target is no longer bounded and visible"
            else:
                phase = trajectory.phase
                action_type = "flee"
                target_id = trajectory.target_id
                reason = "continue committed Safety trajectory to the fixed safe target"

        decision = RuntimeDecision(
            agent_id=agent_id, action_type=action_type, target_id=target_id,
            observation_id=observation_id, reason=reason,
        ).to_json()
        decision["inspection"]["safety"] = {
            "policy": POLICY_ID,
            "authority": "GameAI-local-Safety-policy; not-World-truth-Energy-M_B-or-H",
            "trajectory_phase": phase,
            "target_id": trajectory.target_id if trajectory else completed_target,
            "danger_exposed": safety["exposed"],
            "safe_reached": safety["safe_reached"],
        }
        decision = with_expression(apply_body_constraint(packet, decision))
        self._decisions[key] = (deepcopy(packet), deepcopy(decision))
        return decision

    def snapshot(self):
        return {
            "policy": POLICY_ID,
            "trajectories": {
                agent_id: {"target_id": trajectory.target_id, "phase": trajectory.phase}
                for agent_id, trajectory in self._trajectories.items()
            },
            "decision_count": len(self._decisions),
        }
