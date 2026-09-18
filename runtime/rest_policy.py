"""Opt-in finite Rest Goal/Trajectory policy."""

from copy import deepcopy
from dataclasses import dataclass
from typing import Any

from .core import ObservationError, RuntimeDecision, apply_body_constraint, decide_action
from .expression import with_expression


POLICY_ID = "rest-trajectory-v1"
REST_GOAL_THRESHOLD = 0.5
INTERRUPT_THRESHOLD = 0.7


@dataclass
class RestTrajectory:
    target_id: str
    phase: str = "GO_TO_REST"
    commitment: str = "committed"


class RestTrajectoryPolicy:
    """Maintain one Rest target across observations and finite interruption."""

    def __init__(self, capacity: int = 128):
        self.capacity = capacity
        self._trajectories: dict[str, RestTrajectory] = {}
        self._decisions: dict[tuple[str, str], tuple[dict[str, Any], dict[str, Any]]] = {}

    def decide(self, packet: dict[str, Any]) -> dict[str, Any]:
        decide_action(packet)  # Validate the shared bounded packet contract.
        agent_id, observation_id, observation = _rest_packet(packet)
        key = (agent_id, observation_id)
        if key in self._decisions:
            original, response = self._decisions[key]
            if original != packet:
                raise ObservationError("Rest observation ID reused with different contents")
            return deepcopy(response)
        if len(self._decisions) >= self.capacity:
            raise ObservationError("Rest policy decision capacity reached; start a fresh runtime")

        body = observation["body"]
        visible_places = {place["id"]: place for place in observation["visible_places"]}
        trajectory = self._trajectories.get(agent_id)
        completed = trajectory is not None and body["rest_need"] < REST_GOAL_THRESHOLD
        structural_release = False
        completed_target_id = None
        if completed:
            completed_target_id = trajectory.target_id
            del self._trajectories[agent_id]
            trajectory = None
        elif trajectory is not None and trajectory.target_id not in visible_places:
            del self._trajectories[agent_id]
            trajectory = None
            structural_release = True

        if trajectory is None and not completed and body["rest_need"] >= REST_GOAL_THRESHOLD:
            target = _first_rest_place(observation["visible_places"])
            if target is not None:
                trajectory = RestTrajectory(target_id=target["id"])
                self._trajectories[agent_id] = trajectory

        selected_interrupt = _select_generic_interrupt(observation.get("life_context", {}))
        action_type = "idle"
        target_id = None
        reason = "no Rest goal formed from bounded body and place context"
        phase = "NONE"
        if completed:
            phase = "COMPLETE"
            reason = "observed RestNeed below threshold after short-rest completion"
        elif structural_release:
            phase = "RELEASED"
            reason = "Rest trajectory released because its target is no longer observed"
        elif trajectory is not None and selected_interrupt is not None:
            trajectory.phase = "SUSPENDED"
            phase = trajectory.phase
            reason = "hold committed Rest trajectory for finite generic interrupt"
        elif trajectory is not None:
            place = visible_places[trajectory.target_id]
            target_id = trajectory.target_id
            if place.get("within_reach") is True:
                trajectory.phase = "SHORT_REST"
                action_type = "rest"
                reason = "continue committed Rest trajectory with short rest"
            else:
                trajectory.phase = "GO_TO_REST"
                action_type = "approach"
                reason = "continue committed Rest trajectory toward fixed rest point"
            phase = trajectory.phase

        decision = RuntimeDecision(
            agent_id=agent_id,
            action_type=action_type,
            target_id=target_id,
            observation_id=observation_id,
            reason=reason,
        ).to_json()
        decision["inspection"]["rest"] = {
            "policy": POLICY_ID,
            "authority": "GameAI-local-Rest-policy; not-Sleep-Consolidation-M_B-or-T1",
            "goal": "restore_short_rest_capacity" if trajectory or completed else None,
            "trajectory_phase": phase,
            "target_id": trajectory.target_id if trajectory else completed_target_id,
            "commitment": trajectory.commitment if trajectory else "none",
            "selected_interrupt": deepcopy(selected_interrupt),
            "target_safety_observed_not_used": (
                visible_places.get(trajectory.target_id, {}).get("rest_safety")
                if trajectory else None
            ),
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


def _rest_packet(packet):
    observation = packet["observation"]
    body = observation.get("body")
    if not isinstance(body, dict) or body.get("rest_actions_enabled") is not True:
        raise ObservationError("Rest trajectory requires enabled bounded Rest state")
    return packet["agent_id"], packet["observation_id"], observation


def _first_rest_place(places):
    for place in places:
        if place.get("rest_capable") is True:
            return place
    return None


def _select_generic_interrupt(life_context):
    if not isinstance(life_context, dict):
        raise ObservationError("Rest life_context must be an object")
    candidates = life_context.get("interrupt_candidates", [])
    if not isinstance(candidates, list):
        raise ObservationError("Rest interrupt_candidates must be a list")
    eligible = []
    seen = set()
    for candidate in candidates:
        if not isinstance(candidate, dict):
            raise ObservationError("Rest interrupt candidate must be an object")
        candidate_id = candidate.get("candidate_id")
        salience = candidate.get("salience")
        if not isinstance(candidate_id, str) or not candidate_id or candidate_id in seen:
            raise ObservationError("Rest interrupt candidate IDs must be finite and unique")
        if candidate.get("kind") != "generic":
            raise ObservationError("Rest v1 accepts generic interrupts only")
        if isinstance(salience, bool) or not isinstance(salience, (int, float)) or not 0 <= salience <= 1:
            raise ObservationError("Rest interrupt salience must be between 0 and 1")
        seen.add(candidate_id)
        if salience >= INTERRUPT_THRESHOLD:
            eligible.append(candidate)
    return deepcopy(max(eligible, key=lambda item: (item["salience"], item["candidate_id"]))) if eligible else None
