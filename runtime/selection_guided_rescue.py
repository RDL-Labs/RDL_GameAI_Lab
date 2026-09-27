"""SOC-3: a frozen SOC-2 inspection gates one new, finite rescue episode.

This adapter chooses conditions only; the fixture owns body execution. Historical
inspection and current outcomes remain separate. No NERV/canonical T1 authority.
"""
from copy import deepcopy
import hashlib
import json

from .rescue_condition_rank import CONDITIONS, rank_rescue_conditions
from .rescue_experience import RescueExperienceStore, RescueExperienceError
from .rescue_selection import RescueSelectionEvaluator

RULE = "soc3-selection-guided-rescue-v1"


class SelectionGuidedRescueError(ValueError):
    pass


def _require(ok, reason):
    if not ok:
        raise SelectionGuidedRescueError(reason)


def _id(value):
    return isinstance(value, str) and bool(value.strip()) and len(value) <= 128


def _hash(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


class SelectionGuidedRescueEpisode:
    def __init__(self, source_protocol, source_materials, source_request, profile, binding):
        evaluation = RescueSelectionEvaluator(source_protocol, profile).evaluate(source_materials, source_request)
        fields = {"schema", "rule", "experiment_id", "episode_id", "world_run_id", "agent_id", "target_id", "helper_id", "context_ref"}
        _require(isinstance(binding, dict) and set(binding) == fields and all(_id(v) for v in binding.values()), "invalid_binding")
        _require(binding["schema"] == "soc3-rescue-binding-v1" and binding["rule"] == RULE, "invalid_binding")
        _require(all(binding[k] == evaluation["protocol"][k] for k in ("agent_id", "target_id", "helper_id", "context_ref")), "binding_scope_mismatch")
        _require(all(binding["episode_id"] != row["episode_id"] and binding["world_run_id"] != row["world_run_id"]
                     for row in evaluation["protocol"]["episodes"]), "past_episode_reused")
        self._binding = deepcopy(binding)
        self._evaluation = evaluation
        self._past_events = {r["event"]["event_id"] for row in evaluation["episode_results"] if row["source"]
                             for r in row["source"]["snapshot"]["records"]}
        self._events, self._executions, self._choices = [], [], []
        self._terminal = None

    def _validate(self, events, execution_refs):
        _require(isinstance(events, list) and len(events) <= 3, "event_budget")
        _require(isinstance(execution_refs, list) and len(execution_refs) == len(events), "execution_reference_count")
        _require(events[:len(self._events)] == self._events and len(events) >= len(self._events), "event_prefix_changed")
        _require(execution_refs[:len(self._executions)] == self._executions, "execution_prefix_changed")
        store = RescueExperienceStore(self._binding["world_run_id"], 3)
        seen_events, seen_sources, failures = set(self._past_events), set(), set()
        carry, carry_choice, delivered, tick = None, None, False, -1
        for index, (event, ref) in enumerate(zip(events, execution_refs)):
            try:
                store.record(event)
            except (RescueExperienceError, TypeError, KeyError) as exc:
                raise SelectionGuidedRescueError("invalid_bounded_event") from exc
            _require(all(_id(event[k]) for k in ("event_id", "source_observation_id", "subsequent_observation_id")), "invalid_event_identity")
            _require(event["event_id"] not in seen_events, "event_reused")
            seen_events.add(event["event_id"])
            _require(event["source_observation_id"] not in seen_sources, "action_source_reused")
            seen_sources.add(event["source_observation_id"])
            _require(event["tick"] >= tick, "time_reversal")
            tick = event["tick"]
            _require(event["agent_id"] == self._binding["agent_id"] and event["target_id"] == self._binding["target_id"], "actor_target_mismatch")
            _require(not event["body_consequence"]["actor_incapacitated"], "actor_unavailable")
            _require(not delivered, "event_after_delivery")
            condition, outcome = event["attempt_condition"], event["result"]
            expected = {self._binding["agent_id"]} if condition == "solo" else {self._binding["agent_id"], self._binding["helper_id"]}
            _require(set(event["participants"]) == expected, "participant_scope_mismatch")
            _require(isinstance(ref, dict) and set(ref) == {"choice_id", "event_id", "source_observation_id", "action"}
                     and all(_id(v) for v in ref.values()), "invalid_execution_reference")
            _require(all(ref[k] == event[k] for k in ("event_id", "source_observation_id", "action")), "execution_event_mismatch")
            if outcome == "delivered":
                _require(carry is not None and carry["attempt_condition"] == condition
                         and ref["choice_id"] == carry_choice, "delivery_without_matching_carry")
                delivered = True
            else:
                selections = [c for c in self._choices if len(c["request"]["events"]) == index]
                _require(selections and selections[-1]["result"]["selected"] == condition
                         and selections[-1]["result"]["choice_id"] == ref["choice_id"], "attempt_without_selected_condition")
                _require(carry is None and condition not in failures, "repeated_or_attached_attempt")
                _require(event["body_consequence"]["target_incapacitated"], "target_not_incapacitated")
                if outcome == "carry_established":
                    carry, carry_choice = event, ref["choice_id"]
                else:
                    failures.add(condition)
        return deepcopy(events), deepcopy(execution_refs)

    def choose(self, *, choice_id, binding, source_observation_id, context_ref, events, available_conditions, execution_refs):
        _require(binding == self._binding, "binding_mismatch")
        _require(all(_id(v) for v in (choice_id, source_observation_id, context_ref)), "invalid_choice_identity")
        _require(isinstance(available_conditions, list) and len(available_conditions) <= 3
                 and all(c in (*CONDITIONS, "defer") for c in available_conditions)
                 and len(set(available_conditions)) == len(available_conditions) and "defer" in available_conditions, "invalid_availability")
        request = {"choice_id": choice_id, "binding": binding, "source_observation_id": source_observation_id,
                   "context_ref": context_ref, "events": events, "execution_refs": execution_refs,
                   "available_conditions": sorted(available_conditions)}
        for old in self._choices:
            if old["request"]["choice_id"] == choice_id:
                _require(old["request"] == request, "choice_conflict")
                return deepcopy(old["result"])
        _require(self._terminal is None, "episode_closed")
        _require(len(self._choices) < 3, "choice_budget")
        validated, refs = self._validate(events, execution_refs)
        _require(all(e["result"] == "carry_not_established" for e in validated), "choice_after_attachment")
        if self._choices:
            _require(self._choices[-1]["result"]["selected"] != "defer"
                     and len(validated) > len(self._choices[-1]["request"]["events"]), "choice_requires_new_failure")
        complete = self._evaluation["comparison_complete"]
        disposition = self._evaluation["disposition"]
        rows = []
        for condition in CONDITIONS:
            successes, failures = [], []
            if condition == "joint":
                for row in self._evaluation["episode_results"]:
                    if row["status"] not in ("success", "failure"):
                        continue
                    evidence = {k: deepcopy(row[k]) for k in ("episode_id", "world_run_id", "event_refs")}
                    (successes if row["status"] == "success" else failures).append(evidence)
            failed_now = any(e["attempt_condition"] == condition for e in validated)
            reasons = []
            if condition == "joint" and disposition != "RETAIN":
                reasons.append("selection_rejected" if disposition == "REJECT" else "selection_unresolved")
            if condition not in available_conditions:
                reasons.append("currently_unavailable")
            if context_ref != self._binding["context_ref"]:
                reasons.append("current_context_unavailable")
            if failed_now:
                reasons.append("failed_this_episode")
            rows.append({"condition": condition, "available_now": condition in available_conditions,
                         "selection_disposition": disposition if condition == "joint" else None,
                         "selection_reasons": deepcopy(self._evaluation["reasons"]) if condition == "joint" else [],
                         "eligibility": not reasons, "available": not reasons, "exclusion_reasons": reasons,
                         "failed_this_episode": failed_now, "success_evidence": successes, "failure_evidence": failures,
                         "success_episode_count": len(successes) if complete or condition == "solo" else None,
                         "failure_episode_count": len(failures) if complete or condition == "solo" else None})
        ranked = rank_rescue_conditions(rows)
        selected = ranked[0]["condition"] if ranked else "defer"
        result = {"schema": RULE, "binding": deepcopy(self._binding), "request_choice_id": choice_id,
                  "choice_index": len(self._choices) + 1, "source_observation_id": source_observation_id,
                  "source_evaluation": deepcopy(self._evaluation), "current_events": validated,
                  "execution_refs": refs, "context_ref": context_ref,
                  "candidates": rows + [{"condition": "defer", "available": True}], "selected": selected,
                  "reason": "no_untried_available_condition" if not ranked else
                            "recorded_delivery_priority" if ranked[0]["success_episode_count"] else "untried_condition_then_fixed_tie_break",
                  "authority": "fixture-condition-choice-only; not-help-request-NERV-or-canonical-T1"}
        result["choice_id"] = _hash({"request": request, "result": result})
        self._events, self._executions = validated, refs
        self._choices.append({"request": deepcopy(request), "result": deepcopy(result)})
        return deepcopy(result)

    def finish_episode(self, *, events, execution_refs, status, reason):
        _require(self._terminal is None, "episode_closed")
        _require(status in ("completed", "deferred", "incomplete") and _id(reason), "invalid_terminal")
        validated, refs = self._validate(events, execution_refs)
        delivered = any(e["result"] == "delivered" for e in validated)
        _require((status == "completed") == delivered, "terminal_result_mismatch")
        if status == "deferred":
            _require(self._choices and self._choices[-1]["result"]["selected"] == "defer"
                     and not any(e["result"] == "carry_established" for e in validated), "defer_not_selected")
        self._events, self._executions = validated, refs
        self._terminal = {"status": status, "reason": reason,
                          "rescue_goal_status": "completed" if delivered else "pending",
                          "pending_target_id": None if delivered else self._binding["target_id"]}
        return self.snapshot()

    def snapshot(self):
        return deepcopy({"rule": RULE, "binding": self._binding, "source_evaluation": self._evaluation,
                         "current_events": self._events, "execution_refs": self._executions,
                         "choices": self._choices, "terminal": self._terminal,
                         "retention": "one current episode; frozen three-episode inspection; no automatic NERV/T1 intake"})
