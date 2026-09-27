"""SOC-2 offline, bounded rescue inspection and fixed selection tolerance.

No action, NERV, or canonical T1 authority. Reports are adapter-owned evidence;
revalidation establishes consistency, not the authenticity of a World run.
"""
from copy import deepcopy
import hashlib
import json

from .rescue_experience import RescueExperienceError, RescueExperienceStore

PURPOSE = "joint_rescue_delivery_eligibility"
RULE = "soc2-joint-rescue-tolerance-v1"
CONTEXT = "soc2-bounded-joint-rescue-v1"


class RescueSelectionError(ValueError):
    pass


def _require(condition, reason):
    if not condition:
        raise RescueSelectionError(reason)


def _fields(value, names, reason):
    _require(isinstance(value, dict) and set(value) == set(names.split()), reason)


def _id(value):
    return isinstance(value, str) and bool(value.strip()) and len(value) <= 128


def _ids(values, limit, reason):
    _require(isinstance(values, list) and len(values) <= limit
             and all(_id(v) for v in values), reason)
    _require(len(set(values)) == len(values), reason)


class RescueSelectionEvaluator:
    """An immutable-by-interface protocol/profile; each evaluation is stateless."""

    def __init__(self, protocol, profile):
        _fields(protocol, "schema experiment_id agent_id target_id helper_id purpose rule context_ref episodes", "invalid_protocol")
        _require(protocol["schema"] == "soc2-rescue-protocol-v1"
                 and protocol["purpose"] == PURPOSE and protocol["rule"] == RULE
                 and protocol["context_ref"] == CONTEXT, "unsupported_protocol")
        _require(all(_id(protocol[k]) for k in ("experiment_id", "agent_id", "target_id", "helper_id")), "invalid_identity")
        _require(len({protocol[k] for k in ("agent_id", "target_id", "helper_id")}) == 3, "identity_collision")
        roster = protocol["episodes"]
        _require(isinstance(roster, list) and len(roster) == 3, "episode_budget")
        for row in roster:
            _fields(row, "episode_id world_run_id", "invalid_roster")
            _require(all(_id(v) for v in row.values()), "invalid_roster")
        _require(len({e["episode_id"] for e in roster}) == 3
                 and len({e["world_run_id"] for e in roster}) == 3, "episode_identity_reused")
        _fields(profile, "schema agent_id profile_id revision tolerance_numerator tolerance_denominator", "invalid_profile")
        _require(profile["schema"] == "soc2-selection-profile-v1"
                 and profile["agent_id"] == protocol["agent_id"] and _id(profile["profile_id"]), "invalid_profile")
        _require(type(profile["revision"]) is int and profile["revision"] == 1, "invalid_profile")
        p, q = profile["tolerance_numerator"], profile["tolerance_denominator"]
        _require(type(p) is int and type(q) is int and (p, q) in ((0, 1), (1, 3)), "invalid_tolerance")
        self._protocol = deepcopy(protocol)
        self._protocol["episodes"] = sorted(self._protocol["episodes"], key=lambda e: e["episode_id"])
        self._profile = deepcopy(profile)

    def _inspect(self, material, roster, seen_events):
        _fields(material, "envelope snapshot", "invalid_material")
        envelope, snapshot = material["envelope"], material["snapshot"]
        _fields(envelope, "schema episode_id world_run_id context_ref coverage termination event_refs", "invalid_envelope")
        _require(envelope["schema"] == "soc2-rescue-episode-v1", "invalid_envelope")
        episode, run = envelope["episode_id"], envelope["world_run_id"]
        _require(_id(episode) and episode in roster and run == roster[episode], "episode_binding_mismatch")
        _require(_id(envelope["context_ref"]), "invalid_context")
        _require(envelope["coverage"] in ("complete", "partial"), "invalid_coverage")
        _require(envelope["termination"] in ("delivered", "carry_failed", "not_attempted", "interrupted"), "invalid_termination")
        refs = envelope["event_refs"]
        _ids(refs, 2, "event_reference_budget_or_duplicate")
        _fields(snapshot, "run_id records retention", "invalid_snapshot")
        store = RescueExperienceStore(run, capacity=2)
        _require(snapshot["run_id"] == run and snapshot["retention"] == store.snapshot()["retention"], "snapshot_binding_mismatch")
        records = snapshot["records"]
        _require(isinstance(records, list) and len(records) <= 2, "record_budget")
        by_ref = {}
        for record in records:
            _fields(record, "record_id event authority", "invalid_record")
            try:
                restored = store.record(record["event"])
            except (RescueExperienceError, TypeError, KeyError) as exc:
                raise RescueSelectionError("invalid_bounded_event") from exc
            _require(restored == record, "record_mismatch")
            event = record["event"]
            _require(all(_id(event[k]) for k in ("event_id", "run_id", "agent_id", "target_id",
                                                "source_observation_id", "subsequent_observation_id")), "invalid_event_identity")
            _require(event["agent_id"] == self._protocol["agent_id"]
                     and event["target_id"] == self._protocol["target_id"], "actor_target_mismatch")
            _require(set(event["participants"]) <= {self._protocol["agent_id"], self._protocol["helper_id"]}, "participant_scope_mismatch")
            _require(event["event_id"] not in seen_events, "event_reused")
            seen_events.add(event["event_id"])
            by_ref[record["record_id"]] = record
        _require(set(refs) == set(by_ref) and len(refs) == len(records), "record_reference_mismatch")
        ordered = [by_ref[ref] for ref in refs]
        events = [r["event"] for r in ordered]
        outcomes = [e["result"] for e in events]
        term = envelope["termination"]
        # Enforce the causal sequence even for partial or incomparable evidence.
        if not events:
            _require(term in ("not_attempted", "interrupted"), "termination_conflict")
            observed = "unresolved"
        elif outcomes == ["carry_not_established"]:
            _require(term == "carry_failed", "termination_conflict")
            observed = "failure"
        elif outcomes == ["carry_established"]:
            _require(term == "interrupted", "termination_conflict")
            observed = "unresolved"
        elif outcomes == ["carry_established", "delivered"]:
            _require(term == "delivered", "termination_conflict")
            _require(events[0]["tick"] <= events[1]["tick"], "time_reversal")
            _require(set(events[0]["participants"]) == set(events[1]["participants"]), "participants_changed")
            _require(events[0]["source_observation_id"] != events[1]["source_observation_id"], "action_source_reused")
            observed = "success"
        else:
            raise RescueSelectionError("invalid_action_sequence")
        reasons = []
        if envelope["context_ref"] != self._protocol["context_ref"]:
            reasons.append("context_mismatch")
        if envelope["coverage"] == "partial":
            reasons.append("acquisition_incomplete")
        if not events:
            reasons.append("not_attempted" if term == "not_attempted" else "trial_unconfirmed")
        else:
            if set(events[0]["participants"]) != {self._protocol["agent_id"], self._protocol["helper_id"]}:
                reasons.append("condition_not_realized")
            if any(e["body_consequence"]["actor_incapacitated"] for e in events):
                reasons.append("actor_unavailable")
            if not events[0]["body_consequence"]["target_incapacitated"]:
                reasons.append("target_not_incapacitated")
            if outcomes == ["carry_established"]:
                reasons.append("delivery_unconfirmed")
        normalized = deepcopy(material)
        normalized["snapshot"]["records"] = deepcopy(ordered)
        return {"episode_id": episode, "world_run_id": run,
                "status": "unresolved" if reasons else observed,
                "observed_outcome": observed, "reasons": reasons,
                "event_refs": deepcopy(refs), "source": normalized}

    def evaluate(self, materials, request):
        _fields(request, "experiment_id purpose episode_ids", "invalid_request")
        _require(request["experiment_id"] == self._protocol["experiment_id"]
                 and request["purpose"] == PURPOSE, "request_binding_mismatch")
        _ids(request["episode_ids"], 3, "request_episode_budget_or_duplicate")
        roster = {e["episode_id"]: e["world_run_id"] for e in self._protocol["episodes"]}
        _require(set(request["episode_ids"]) == set(roster), "whole_roster_required")
        _fields(materials, "episodes missing_episode_ids", "invalid_materials")
        episodes, missing = materials["episodes"], materials["missing_episode_ids"]
        _require(isinstance(episodes, list) and len(episodes) <= 3, "episode_budget")
        _ids(missing, 3, "missing_episode_budget_or_duplicate")
        _require(len(episodes) + len(missing) == 3, "whole_roster_required")
        rows, present, seen_events = [], set(), set()
        for material in episodes:
            row = self._inspect(material, roster, seen_events)
            _require(row["episode_id"] not in present, "episode_reused")
            present.add(row["episode_id"])
            rows.append(row)
        _require(not present.intersection(missing) and present.union(missing) == set(roster), "invalid_missing_partition")
        for episode in missing:
            rows.append({"episode_id": episode, "world_run_id": roster[episode], "status": "unresolved",
                         "observed_outcome": "unresolved", "reasons": ["episode_unavailable"], "event_refs": [], "source": None})
        rows.sort(key=lambda r: r["episode_id"])
        complete = all(r["status"] != "unresolved" for r in rows)
        k = sum(r["status"] == "failure" for r in rows) if complete else None
        n = 3 if complete else None
        p, q = self._profile["tolerance_numerator"], self._profile["tolerance_denominator"]
        if not complete:
            disposition, baseline = "DEFER", "DEFER"
            reasons = sorted({reason for row in rows for reason in row["reasons"]})
        else:
            disposition = "RETAIN" if k * q <= n * p else "REJECT"
            baseline = "RETAIN" if k == 0 else "REJECT"
            reasons = ["no_observed_failure" if k == 0 else
                       "within_declared_tolerance" if disposition == "RETAIN" else "exceeds_declared_tolerance"]
        result = {"schema": "soc2-rescue-selection-evaluation-v1", "protocol": deepcopy(self._protocol),
                  "profile": deepcopy(self._profile), "episode_results": rows,
                  "comparison_complete": complete, "failure_count": k, "validation_count": n,
                  "tolerance_numerator": p, "tolerance_denominator": q,
                  "baseline_disposition": baseline, "disposition": disposition, "reasons": reasons,
                  "authority": "local-inspection-only; not-action-NERV-or-canonical-T1"}
        result["evaluation_id"] = hashlib.sha256(json.dumps(result, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        return result
