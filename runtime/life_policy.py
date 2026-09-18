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
HABIT_SUCCESS_THRESHOLD = 2
INTERRUPT_THRESHOLD = 0.7
THREAT_PROFILE_THRESHOLDS = {"cautious": 0.4, "standard": 0.7, "steadfast": 0.9}
NOVELTY_RESPONSES = {"ignore", "inspect", "divert"}
ACTIVE_CUE_BANDS = {"low", "critical", "empty"}
VALID_CUE_RESPONSES = {"follow", "ignore"}


@dataclass
class TrajectoryState:
    goal: str
    phase: str
    target_id: str
    commitment: str = "committed"


class BaseFoodLifePolicy:
    """Keep one finite trajectory until completion or structural release."""

    def __init__(self, capacity: int = 128, cue_responses=None, threat_profiles=None,
                 novelty_responses=None):
        self.capacity = capacity
        configured = dict(cue_responses or {})
        for agent_id, response in configured.items():
            if not isinstance(agent_id, str) or not agent_id or response not in VALID_CUE_RESPONSES:
                raise ValueError("invalid Base-Food cue response")
        self._cue_responses = configured
        configured_threat_profiles = dict(threat_profiles or {})
        for agent_id, profile in configured_threat_profiles.items():
            if not isinstance(agent_id, str) or not agent_id or profile not in THREAT_PROFILE_THRESHOLDS:
                raise ValueError("invalid Base-Food threat profile")
        self._threat_profiles = configured_threat_profiles
        configured_novelty_responses = dict(novelty_responses or {})
        for agent_id, response in configured_novelty_responses.items():
            if not isinstance(agent_id, str) or not agent_id or response not in NOVELTY_RESPONSES:
                raise ValueError("invalid Base-Food novelty response")
        self._novelty_responses = configured_novelty_responses
        self._trajectories: dict[str, TrajectoryState] = {}
        self._decisions: dict[tuple[str, str], tuple[dict[str, Any], dict[str, Any]]] = {}
        self._results: dict[str, dict[str, Any]] = {}

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
        cue = context["god_statue_cue"]
        cue_response = self._cue_responses.get(agent_id, "follow") if cue else "autonomous"
        learned_trigger = cue is None and self._habit_ready(agent_id)
        if trajectory is None and cue_response != "ignore" and _should_form_goal(context, learned_trigger):
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
        reason = (
            "NPC ignored the finite God Statue cue"
            if cue_response == "ignore"
            else "no assisted Base-Food goal formed from bounded life context"
        )
        threat_profile = self._threat_profiles.get(agent_id, "standard")
        novelty_response = self._novelty_responses.get(agent_id, "inspect")
        interrupt, interrupt_threshold = _select_interrupt(
            context["interrupt_candidates"], threat_profile, novelty_response
        )
        interrupt_outcome = "continue"
        trajectory_interrupted = False
        if trajectory is not None and interrupt is not None:
            if interrupt["kind"] == "novelty" and novelty_response == "ignore":
                interrupt_outcome = "ignore"
            elif interrupt["kind"] == "novelty" and novelty_response == "divert":
                action_type = "approach"
                target_id = interrupt["target_id"]
                reason = "temporarily divert toward bounded novelty while retaining Base-Food trajectory"
                interrupt_outcome = "divert"
                trajectory_interrupted = True
            else:
                action_type = "idle"
                reason = (
                    "inspect bounded novelty while retaining Base-Food trajectory"
                    if interrupt["kind"] == "novelty"
                    else "hold committed Base-Food trajectory for finite interrupt candidate"
                )
                interrupt_outcome = "inspect" if interrupt["kind"] == "novelty" else "hold"
                trajectory_interrupted = True
        if trajectory is not None and not trajectory_interrupted:
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
            "cue_response": cue_response,
            "goal_trigger": "learned_low_stock_relation" if learned_trigger else (
                "god_statue_cue" if cue else "none"
            ),
            "habit_successes": self._success_count(agent_id),
            "habit_ready": self._habit_ready(agent_id),
            "goal": trajectory.goal if trajectory else None,
            "trajectory_phase": trajectory.phase if trajectory else "NONE",
            "commitment": trajectory.commitment if trajectory else "none",
            "interrupt": {
                "threshold": interrupt_threshold,
                "threat_profile": threat_profile,
                "novelty_response": novelty_response,
                "selected": deepcopy(interrupt),
                "outcome": interrupt_outcome,
                "authority": "GameAI-local-observation-comparison; not-action-authority",
            },
        }
        if trajectory_interrupted:
            life["trajectory_phase"] = "SUSPENDED"
        decision["inspection"]["life"] = life
        decision = with_expression(apply_body_constraint(packet, decision))
        self._decisions[key] = (deepcopy(packet), deepcopy(decision))
        return decision

    def complete_deposit(self, agent_id: str) -> None:
        self._trajectories.pop(agent_id, None)

    def record_result(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise ObservationError("life result must be an object")
        for field in ("result_id", "agent_id", "source_observation_id"):
            if not isinstance(payload.get(field), str) or not payload[field]:
                raise ObservationError(f"life result {field} must be non-empty")
        if payload.get("response") != "follow" or payload.get("outcome") != "replenish_success":
            raise ObservationError("unsupported life result response/outcome")
        cue_id = payload.get("cue_id")
        if not isinstance(cue_id, str) or not cue_id:
            raise ObservationError("life result cue_id must be non-empty")
        result = {
            "result_id": payload["result_id"],
            "agent_id": payload["agent_id"],
            "source_observation_id": payload["source_observation_id"],
            "cue_id": cue_id,
            "response": "follow",
            "outcome": "replenish_success",
            "relation": "low_base_food -> replenish_base_food",
            "authority": "GameAI-local-experience; not-canonical-M_B",
        }
        existing = self._results.get(result["result_id"])
        if existing is not None and existing != result:
            raise ObservationError("conflicting life result replay")
        self._results[result["result_id"]] = result
        self.complete_deposit(result["agent_id"])
        return deepcopy(result)

    def snapshot(self) -> dict[str, Any]:
        return {
            "policy": POLICY_ID,
            "cue_responses": deepcopy(self._cue_responses),
            "threat_profiles": deepcopy(self._threat_profiles),
            "novelty_responses": deepcopy(self._novelty_responses),
            "trajectories": {
                agent_id: deepcopy(vars(state))
                for agent_id, state in self._trajectories.items()
            },
            "decisions": len(self._decisions),
            "results": deepcopy(list(self._results.values())),
            "habit_success_threshold": HABIT_SUCCESS_THRESHOLD,
            "habit_ready_agents": sorted({
                result["agent_id"] for result in self._results.values()
                if self._habit_ready(result["agent_id"])
            }),
        }

    def _success_count(self, agent_id):
        return sum(
            result["agent_id"] == agent_id and result["outcome"] == "replenish_success"
            for result in self._results.values()
        )

    def _habit_ready(self, agent_id):
        return self._success_count(agent_id) >= HABIT_SUCCESS_THRESHOLD


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
    if cue is not None:
        if not isinstance(cue, dict):
            raise ObservationError("life_context.god_statue_cue must be an object or null")
        if cue.get("source") != "system_assessment" or cue.get("topic") != "base_food":
            raise ObservationError("unsupported God Statue cue provenance")
        if cue.get("delivery") != "morning":
            raise ObservationError("God Statue Food cue must use the finite morning delivery")
        if cue.get("band") not in {"enough", "low", "critical", "empty"}:
            raise ObservationError("unsupported God Statue Food cue band")
        if not isinstance(cue.get("cue_id"), str) or not cue["cue_id"]:
            raise ObservationError("God Statue cue_id must be non-empty")
    if context.get("observed_base_food_band") not in {"enough", "low", "critical", "empty"}:
        raise ObservationError("unsupported observed Base Food band")
    known_base = context.get("known_base")
    if not isinstance(known_base, dict) or not isinstance(known_base.get("id"), str) or not known_base["id"]:
        raise ObservationError("life_context.known_base.id is required")
    if type(context.get("at_base")) is not bool:
        raise ObservationError("life_context.at_base must be boolean")
    candidates = context.get("interrupt_candidates", [])
    if not isinstance(candidates, list):
        raise ObservationError("life_context.interrupt_candidates must be a list")
    seen_candidate_ids = set()
    for candidate in candidates:
        if not isinstance(candidate, dict):
            raise ObservationError("interrupt candidate must be an object")
        candidate_id = candidate.get("candidate_id")
        if not isinstance(candidate_id, str) or not candidate_id or candidate_id in seen_candidate_ids:
            raise ObservationError("interrupt candidate IDs must be finite and unique")
        seen_candidate_ids.add(candidate_id)
        if candidate.get("kind") not in {"generic", "threat", "novelty"}:
            raise ObservationError("unsupported interrupt candidate kind")
        salience = candidate.get("salience")
        if isinstance(salience, bool) or not isinstance(salience, (int, float)) or not 0.0 <= salience <= 1.0:
            raise ObservationError("interrupt candidate salience must be between 0 and 1")
        if candidate["kind"] == "novelty":
            target_id = candidate.get("target_id")
            visible_ids = {item.get("id") for item in observation["visible_objects"]}
            if not isinstance(target_id, str) or not target_id or target_id not in visible_ids:
                raise ObservationError("novelty target_id must name a visible object")
    context["interrupt_candidates"] = candidates
    return agent_id, observation_id, observation, context


def _should_form_goal(context, learned_trigger):
    cue = context["god_statue_cue"]
    cue_active = cue is not None and cue["band"] in ACTIVE_CUE_BANDS
    return context["observed_base_food_band"] in ACTIVE_CUE_BANDS and (cue_active or learned_trigger)


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


def _select_interrupt(candidates, threat_profile, novelty_response):
    threat_threshold = THREAT_PROFILE_THRESHOLDS[threat_profile]
    eligible = [
        candidate for candidate in candidates
        if candidate["salience"] >= (
            threat_threshold if candidate["kind"] == "threat" else INTERRUPT_THRESHOLD
        )
    ]
    if not eligible:
        return None, threat_threshold
    actionable = [
        candidate for candidate in eligible
        if candidate["kind"] != "novelty" or novelty_response != "ignore"
    ]
    selected = max(
        actionable or eligible,
        key=lambda candidate: (candidate["salience"], candidate["candidate_id"]),
    )
    selected_threshold = threat_threshold if selected["kind"] == "threat" else INTERRUPT_THRESHOLD
    return deepcopy(selected), selected_threshold


def parse_cue_responses(values):
    configured = {}
    for value in values:
        if not isinstance(value, str) or "=" not in value:
            raise ValueError("cue response must use AGENT=follow|ignore")
        agent_id, response = value.split("=", 1)
        if not agent_id or response not in VALID_CUE_RESPONSES or agent_id in configured:
            raise ValueError("invalid or duplicate Base-Food cue response")
        configured[agent_id] = response
    return configured


def parse_threat_profiles(values):
    configured = {}
    for value in values:
        if not isinstance(value, str) or "=" not in value:
            raise ValueError("threat profile must use AGENT=cautious|standard|steadfast")
        agent_id, profile = value.split("=", 1)
        if not agent_id or profile not in THREAT_PROFILE_THRESHOLDS or agent_id in configured:
            raise ValueError("invalid or duplicate Base-Food threat profile")
        configured[agent_id] = profile
    return configured


def parse_novelty_responses(values):
    configured = {}
    for value in values:
        if not isinstance(value, str) or "=" not in value:
            raise ValueError("novelty response must use AGENT=ignore|inspect|divert")
        agent_id, response = value.split("=", 1)
        if not agent_id or response not in NOVELTY_RESPONSES or agent_id in configured:
            raise ValueError("invalid or duplicate Base-Food novelty response")
        configured[agent_id] = response
    return configured
