"""SOC-1 finite episodic condition choice, explicitly separate from NERV/T1."""
from copy import deepcopy
import hashlib
import json

from .rescue_experience import RescueExperienceStore
from .rescue_condition_rank import CONDITIONS, rank_rescue_conditions

RULE = "soc1-rescue-condition-choice-v1"


class RepeatedRescueError(ValueError):
    pass


def _require(ok, why):
    if not ok:
        raise RepeatedRescueError(why)


def _id(value):
    return isinstance(value, str) and bool(value.strip()) and len(value) <= 128


def _hash(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


class RepeatedRescueSelector:
    """Three explicit episodes, at most three bounded events/choices per episode.

    Retention controls access to earlier episodes, never current-episode evidence.
    There is no episode-number or World capability branch in the selection rule.
    """
    def __init__(self, agent_id="npc_a", target_id="npc_b", retain_previous=True, helper_id="npc_c"):
        _require(all(_id(i) for i in (agent_id, target_id, helper_id)) and len({agent_id, target_id, helper_id}) == 3, "invalid_identity")
        _require(type(retain_previous) is bool, "invalid_retention")
        self._agent, self._target, self._retain = agent_id, target_id, retain_previous
        self._helper = helper_id
        self._episodes = []
        self._current = None

    def begin_episode(self, episode_id, world_run_id):
        _require(self._current is None, "episode_already_active")
        _require(_id(episode_id) and _id(world_run_id), "invalid_episode_identity")
        _require(len(self._episodes) < 3, "episode_budget")
        _require(all(e["episode_id"] != episode_id and e["world_run_id"] != world_run_id for e in self._episodes), "episode_identity_reused")
        self._current = {"episode_id": episode_id, "world_run_id": world_run_id, "events": [], "choices": []}

    def _validate_events(self, events):
        _require(self._current is not None, "no_active_episode")
        _require(isinstance(events, list) and len(events) <= 3, "event_budget")
        old = self._current["events"]
        _require(events[:len(old)] == old and len(events) >= len(old), "event_prefix_changed")
        store = RescueExperienceStore(self._current["world_run_id"], 3)
        seen = {e["event_id"] for ep in self._episodes for e in ep["events"]}
        carry, delivered, failures = None, False, set()
        for index, e in enumerate(events):
            store.record(e)
            _require(e["event_id"] not in seen, "event_reused")
            seen.add(e["event_id"])
            _require(e["agent_id"] == self._agent and e["target_id"] == self._target, "actor_target_mismatch")
            _require(not e["body_consequence"]["actor_incapacitated"], "incapacitated_actor")
            _require(not delivered, "event_after_delivery")
            outcome, condition = e["result"], e["attempt_condition"]
            _require(set(e["participants"]) == ({self._agent} if condition == "solo" else {self._agent, self._helper}), "participant_scope_mismatch")
            if outcome == "delivered":
                _require(carry is not None and carry["participants"] == e["participants"], "delivery_without_matching_carry")
                delivered = True
            else:
                selections = [c for c in self._current["choices"] if len(c["request"]["events"]) == index]
                _require(selections and selections[-1]["result"]["selected"] == condition, "attempt_without_selected_condition")
                _require(carry is None, "attempt_while_carried")
                _require(e["body_consequence"]["target_incapacitated"], "target_not_incapacitated")
                _require(condition not in failures, "repeated_failed_condition")
                if outcome == "carry_established":
                    carry = e
                else:
                    failures.add(condition)
        return deepcopy(events)

    def choose(self, *, choice_id, events, available_conditions):
        _require(self._current is not None and _id(choice_id), "invalid_choice_identity")
        _require(isinstance(available_conditions, list) and len(available_conditions) <= 3
                 and all(c in (*CONDITIONS, "defer") for c in available_conditions)
                 and len(set(available_conditions)) == len(available_conditions) and "defer" in available_conditions,
                 "invalid_available_conditions")
        request = {"choice_id": choice_id, "events": events, "available_conditions": sorted(available_conditions)}
        for old in self._current["choices"]:
            if old["request"]["choice_id"] == choice_id:
                _require(old["request"] == request, "choice_conflict")
                return deepcopy(old["result"])
        _require(len(self._current["choices"]) < 3, "choice_budget")
        validated = self._validate_events(events)
        _require(not any(e["result"] in ("carry_established", "delivered") for e in validated), "choice_after_attachment")
        current = dict(self._current, events=validated)
        accessible = (self._episodes if self._retain else []) + [current]
        rows = []
        for condition in CONDITIONS:
            successes, failures = [], []
            for ep in accessible:
                for event in ep["events"]:
                    if event["attempt_condition"] != condition:
                        continue
                    ref = {"episode_id": ep["episode_id"], "world_run_id": ep["world_run_id"], "event_id": event["event_id"]}
                    if event["result"] == "delivered": successes.append(ref)
                    if event["result"] == "carry_not_established": failures.append(ref)
            failed_now = any(e["attempt_condition"] == condition and e["result"] == "carry_not_established" for e in validated)
            rows.append({"condition": condition, "available": condition in available_conditions,
                         "failed_this_episode": failed_now, "success_evidence": successes, "failure_evidence": failures,
                         "success_episode_count": len({r["episode_id"] for r in successes}),
                         "failure_episode_count": len({r["episode_id"] for r in failures})})
        eligible = rank_rescue_conditions(rows)
        selected = eligible[0]["condition"] if eligible else "defer"
        result = {"schema": RULE, "episode_id": current["episode_id"], "world_run_id": current["world_run_id"],
                  "agent_id": self._agent, "target_id": self._target, "retain_previous": self._retain,
                  "accessible_episode_ids": [ep["episode_id"] for ep in accessible],
                  "candidates": rows + [{"condition": "defer", "available": True}], "selected": selected,
                  "reason": "no_untried_available_condition" if not eligible else
                            "recorded_delivery_priority" if eligible[0]["success_episode_count"] else "untried_condition_then_fixed_tie_break",
                  "source_events": [deepcopy(e) for ep in accessible for e in ep["events"]],
                  "authority": "fixture-condition-choice-only; not-help-request-social-relation-NERV-or-T1"}
        result["choice_id"] = _hash({"request": request, "result": result})
        self._current["events"] = validated
        self._current["choices"].append({"request": deepcopy(request), "result": deepcopy(result)})
        return result

    def finish_episode(self, events, status):
        _require(status in ("completed", "deferred", "incomplete"), "invalid_terminal_status")
        validated = self._validate_events(events)
        _require((status == "completed") == any(e["result"] == "delivered" for e in validated), "terminal_result_mismatch")
        if status == "deferred":
            _require(self._current["choices"] and self._current["choices"][-1]["result"]["selected"] == "defer", "defer_not_selected")
        finished = deepcopy(self._current)
        finished.update(events=validated, status=status)
        self._episodes.append(finished)
        self._current = None
        return deepcopy(finished)

    def snapshot(self):
        return deepcopy({"rule_version": RULE, "agent_id": self._agent, "target_id": self._target,
                         "retain_previous": self._retain, "episodes": self._episodes, "current": self._current,
                         "retention": "three process-local episodes; audit archives are not all accessible for choice"})
