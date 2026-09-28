"""SOC-5 finite post-failure candidate expansion; no selection or action authority."""
from copy import deepcopy
import hashlib
import json

from .rescue_experience import RescueExperienceError, RescueExperienceStore

RULE = "soc5-failure-response-candidates-v1"
CONTEXT_SCHEMA = "soc5-post-failure-context-v1"
AUTHORITY = "finite-candidate-expansion-only; no-selection-action-communication-NERV-T1-or-canonical-authority"
CANDIDATE_ORDER = ("retry", "reposition", "known_tool", "seek_agent", "wait", "abandon")


class FailureResponseCandidateError(ValueError):
    pass


def _require(ok, reason):
    if not ok:
        raise FailureResponseCandidateError(reason)


def _ident(value):
    return isinstance(value, str) and bool(value.strip()) and len(value) <= 128


def _digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _refs(values, *, forbidden=()):
    _require(isinstance(values, list) and len(values) <= 8, "invalid_reference_list")
    _require(all(_ident(v) for v in values), "invalid_reference_list")
    _require(len(set(values)) == len(values), "duplicate_reference")
    _require(not set(values).intersection(forbidden), "invalid_reference_scope")
    return sorted(values)


def _validate_failure(event):
    _require(isinstance(event, dict), "failure_event_required")
    run_id = event.get("run_id")
    _require(_ident(run_id), "invalid_failure_run")
    try:
        record = RescueExperienceStore(run_id, 1).record(event)
    except (RescueExperienceError, TypeError, KeyError) as exc:
        raise FailureResponseCandidateError("invalid_bounded_rescue_event") from exc
    checked = record["event"]
    _require(checked["result"] == "carry_not_established", "actual_carry_failure_required")
    _require(checked["attempt_condition"] == "solo" and checked["participants"] == [checked["agent_id"]],
             "solo_failure_required")
    _require(not checked["body_consequence"]["actor_incapacitated"], "actor_unavailable_after_failure")
    _require(checked["body_consequence"]["target_incapacitated"], "rescue_target_no_longer_pending")
    return deepcopy(record)


def _validate_context(context, event):
    names = {
        "schema", "run_id", "agent_id", "target_id", "context_ref", "source_observation_id",
        "coverage", "actor_ready", "movement_ready", "retry_budget_remaining",
        "known_tool_refs", "observed_agent_refs",
    }
    _require(isinstance(context, dict) and set(context) == names, "invalid_post_failure_context")
    _require(context["schema"] == CONTEXT_SCHEMA, "unsupported_context_schema")
    _require(all(_ident(context[k]) for k in
                 ("run_id", "agent_id", "target_id", "context_ref", "source_observation_id")),
             "invalid_context_identity")
    _require(context["run_id"] == event["run_id"] and context["agent_id"] == event["agent_id"]
             and context["target_id"] == event["target_id"], "context_binding_mismatch")
    _require(context["source_observation_id"] == event["subsequent_observation_id"],
             "post_failure_observation_required")
    _require(context["coverage"] in ("complete", "partial"), "invalid_coverage")
    _require(type(context["actor_ready"]) is bool and type(context["movement_ready"]) is bool,
             "invalid_readiness")
    _require(type(context["retry_budget_remaining"]) is int and 0 <= context["retry_budget_remaining"] <= 2,
             "invalid_retry_budget")
    tools = _refs(context["known_tool_refs"], forbidden=(event["agent_id"], event["target_id"]))
    agents = _refs(context["observed_agent_refs"], forbidden=(event["agent_id"], event["target_id"]))
    normalized = deepcopy(context)
    normalized["known_tool_refs"] = tools
    normalized["observed_agent_refs"] = agents
    return normalized


def _candidate(kind, status, reasons, refs=()):
    _require(kind in CANDIDATE_ORDER and status in ("available", "unavailable", "unresolved"),
             "invalid_candidate")
    return {"candidate": kind, "status": status, "reasons": list(reasons), "evidence_refs": list(refs)}


def expand_failure_response(*, failure_event, context):
    """Expand a real solo carry failure into a bounded option set without choosing an option."""
    record = _validate_failure(deepcopy(failure_event))
    event = record["event"]
    context = _validate_context(deepcopy(context), event)
    actor_ready = context["actor_ready"]
    coverage = context["coverage"]

    candidates = []
    candidates.append(_candidate(
        "retry",
        "available" if actor_ready and context["retry_budget_remaining"] > 0 else "unavailable",
        ["bounded_retry_budget_remains"] if actor_ready and context["retry_budget_remaining"] > 0
        else ["actor_not_ready" if not actor_ready else "retry_budget_exhausted"],
    ))
    candidates.append(_candidate(
        "reposition",
        "available" if actor_ready and context["movement_ready"] else "unavailable",
        ["movement_currently_available"] if actor_ready and context["movement_ready"]
        else ["actor_not_ready" if not actor_ready else "movement_not_ready"],
    ))

    if not actor_ready:
        tool_status, tool_reasons = "unavailable", ["actor_not_ready"]
    elif context["known_tool_refs"]:
        tool_status, tool_reasons = "available", ["known_tool_observed"]
    elif coverage == "partial":
        tool_status, tool_reasons = "unresolved", ["tool_coverage_incomplete"]
    else:
        tool_status, tool_reasons = "unavailable", ["no_known_tool_observed"]
    candidates.append(_candidate("known_tool", tool_status, tool_reasons, context["known_tool_refs"]))

    if not actor_ready:
        agent_status, agent_reasons = "unavailable", ["actor_not_ready"]
    elif context["observed_agent_refs"]:
        agent_status, agent_reasons = "available", ["other_agent_observed"]
    elif coverage == "partial":
        agent_status, agent_reasons = "unresolved", ["agent_coverage_incomplete"]
    else:
        agent_status, agent_reasons = "unavailable", ["no_other_agent_observed"]
    candidates.append(_candidate("seek_agent", agent_status, agent_reasons, context["observed_agent_refs"]))

    candidates.append(_candidate("wait", "available", ["nonintervention_option_retained"]))
    candidates.append(_candidate("abandon", "available", ["goal_exit_option_retained"]))

    result = {
        "schema": RULE,
        "failure_record_id": record["record_id"],
        "source_event_id": event["event_id"],
        "source_observation_id": context["source_observation_id"],
        "context": context,
        "candidates": candidates,
        "authority": AUTHORITY,
        "retention": "single finite expansion; no learned ranking or persistent relation created",
    }
    result["candidate_set_id"] = _digest(result)
    return deepcopy(result)
