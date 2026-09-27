"""SOC-4 finite two-condition carry prediction; no action or canonical authority.

The fixed hypothesis language is designer-owned. Which predicates survive is
computed from independent World experiences, never from the fixture formula.
"""
from copy import deepcopy
import hashlib
import json
from itertools import product

from .rescue_experience import RescueExperienceError, RescueExperienceStore

RULE = "soc4-contextual-carry-v1"
PURPOSE = "predict_solo_carry_establishment"
PROFILE = "soc4-local-contact-cues-v1"
CELLS = set(product(("full", "limited"), ("firm", "loose")))


class ContextualCarryError(ValueError):
    pass


def require(ok, reason):
    if not ok:
        raise ContextualCarryError(reason)


def fields(value, names, reason):
    require(isinstance(value, dict) and set(value) == set(names.split()), reason)


def ident(value):
    return isinstance(value, str) and bool(value.strip()) and len(value) <= 128


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _protocol(value):
    fields(value, "schema purpose experiment_id agent_id target_id context_ref formation validation forecast", "invalid_protocol")
    require(value["schema"] == RULE and value["purpose"] == PURPOSE, "unsupported_protocol")
    require(all(ident(value[k]) for k in ("experiment_id", "agent_id", "target_id", "context_ref")), "invalid_identity")
    require(value["agent_id"] != value["target_id"], "self_rescue")
    episodes, runs = set(), set()
    for phase in ("formation", "validation", "forecast"):
        rows = value[phase]
        require(isinstance(rows, list) and len(rows) == 4, "four_episode_roster_required")
        for row in rows:
            fields(row, "episode_id run_id", "invalid_roster_entry")
            require(all(ident(v) for v in row.values()), "invalid_roster_identity")
            require(row["episode_id"] not in episodes and row["run_id"] not in runs, "episode_or_run_reused")
            episodes.add(row["episode_id"]); runs.add(row["run_id"])
    result = deepcopy(value)
    for phase in ("formation", "validation", "forecast"):
        result[phase].sort(key=lambda r: r["episode_id"])
    return result


def _context(context, protocol, run_id):
    fields(context, "schema run_id agent_id target_id context_ref profile source_observation_id tick body_ref footing_ref movement_band footing_band coverage actor_ready target_ready within_reach", "invalid_context")
    require(context["schema"] == "soc4-pre-carry-context-v1" and context["profile"] == PROFILE, "unsupported_context_schema_or_profile")
    require(all(ident(context[k]) for k in ("run_id", "agent_id", "target_id", "context_ref", "source_observation_id", "body_ref", "footing_ref")), "invalid_context_identity")
    require(context["run_id"] == run_id and all(context[k] == protocol[k] for k in ("agent_id", "target_id")), "context_binding_mismatch")
    require(type(context["tick"]) is int and context["tick"] >= 0, "invalid_capture_tick")
    require(context["movement_band"] in ("full", "limited", "unknown") and context["footing_band"] in ("firm", "loose", "unknown"), "invalid_cue")
    require(context["coverage"] in ("complete", "partial"), "invalid_coverage")
    require(all(type(context[k]) is bool for k in ("actor_ready", "target_ready", "within_reach")), "invalid_readiness")
    reasons = []
    if context["context_ref"] != protocol["context_ref"]: reasons.append("context_mismatch")
    if context["coverage"] != "complete": reasons.append("acquisition_incomplete")
    if "unknown" in (context["movement_band"], context["footing_band"]): reasons.append("condition_unknown")
    if not all(context[k] for k in ("actor_ready", "target_ready", "within_reach")): reasons.append("attempt_not_ready")
    return reasons


def _record(material, protocol, roster, seen_events):
    fields(material, "episode_id context event conditions_stable termination", "invalid_episode_material")
    episode = material["episode_id"]
    require(ident(episode) and episode in roster, "unknown_episode")
    context = material["context"]
    reasons = _context(context, protocol, roster[episode])
    require(type(material["conditions_stable"]) is bool, "invalid_stability")
    if not material["conditions_stable"]: reasons.append("conditions_changed")
    event = material["event"]
    if event is None:
        require(material["termination"] in ("not_attempted", "interrupted"), "termination_conflict")
        reasons.append(material["termination"])
        observed = None
    else:
        try:
            RescueExperienceStore(roster[episode], 1).record(event)
        except (RescueExperienceError, TypeError, KeyError) as exc:
            raise ContextualCarryError("invalid_carry_event") from exc
        require(all(ident(event[k]) for k in ("event_id", "source_observation_id", "subsequent_observation_id")), "invalid_event_identity")
        require(event["event_id"] not in seen_events, "event_reused")
        seen_events.add(event["event_id"])
        require(event["agent_id"] == protocol["agent_id"] and event["target_id"] == protocol["target_id"], "event_scope_mismatch")
        require(event["source_observation_id"] == context["source_observation_id"] and event["tick"] == context["tick"], "capture_action_mismatch")
        require(event["action"] == "rescue" and event["attempt_condition"] == "solo" and event["participants"] == [protocol["agent_id"]], "solo_carry_required")
        require(material["termination"] == "carry_observed", "termination_conflict")
        observed = "established" if event["result"] == "carry_established" else "not_established"
        if event["body_consequence"]["actor_incapacitated"] or not event["body_consequence"]["target_incapacitated"]:
            reasons.append("body_condition_unavailable")
    return {"episode_id": episode, "run_id": roster[episode], "comparable": not reasons,
            "observed": observed, "reasons": sorted(set(reasons)), "source": deepcopy(material)}


def _materials(materials, protocol, phase, seen_events):
    fields(materials, "episodes missing_episode_ids", "invalid_materials")
    roster = {r["episode_id"]: r["run_id"] for r in protocol[phase]}
    episodes, missing = materials["episodes"], materials["missing_episode_ids"]
    require(isinstance(episodes, list) and isinstance(missing, list) and len(episodes) + len(missing) == 4, "whole_roster_required")
    require(all(ident(i) and i in roster for i in missing) and len(set(missing)) == len(missing), "invalid_missing_partition")
    rows = [_record(m, protocol, roster, seen_events) for m in episodes]
    present = [r["episode_id"] for r in rows]
    require(len(set(present)) == len(present) and not set(present).intersection(missing)
            and set(present).union(missing) == set(roster), "invalid_missing_partition")
    rows += [{"episode_id": i, "run_id": roster[i], "comparable": False, "observed": None,
              "reasons": ["episode_unavailable"], "source": None} for i in missing]
    rows.sort(key=lambda r: r["episode_id"])
    cells = {(r["source"]["context"]["movement_band"], r["source"]["context"]["footing_band"]) for r in rows if r["comparable"]}
    reasons = {reason for r in rows for reason in r["reasons"]}
    if cells != CELLS: reasons.add("context_cells_incomplete")
    return rows, sorted(reasons)


def hypotheses():
    # Generic symmetric language: 2 constants, 4 literals, 4 ANDs, 4 ORs.
    result = [{"op": "constant", "value": v} for v in (False, True)]
    result += [{"op": "literal", "axis": a, "value": v} for a, values in
               (("movement_band", ("full", "limited")), ("footing_band", ("firm", "loose"))) for v in values]
    result += [{"op": op, "movement_band": b, "footing_band": f} for op in ("and", "or") for b, f in sorted(CELLS)]
    return [{"hypothesis_id": digest(r), "predicate": r} for r in result]


def _outcome(predicate, context):
    op = predicate["op"]
    if op == "constant": failure = predicate["value"]
    elif op == "literal": failure = context[predicate["axis"]] == predicate["value"]
    else:
        body = context["movement_band"] == predicate["movement_band"]
        footing = context["footing_band"] == predicate["footing_band"]
        failure = body and footing if op == "and" else body or footing
    return "not_established" if failure else "established"


def _checks(hypothesis, rows):
    result = []
    for row in rows:
        expected = _outcome(hypothesis["predicate"], row["source"]["context"]) if row["comparable"] else None
        result.append({"episode_id": row["episode_id"], "expected": expected, "observed": row["observed"],
                       "match": expected == row["observed"] if expected is not None else None, "reasons": row["reasons"]})
    return result


def inspect_context_hypotheses(protocol, formation, validation):
    protocol = _protocol(protocol)
    seen_events = set()
    train, train_reasons = _materials(formation, protocol, "formation", seen_events)
    held, held_reasons = _materials(validation, protocol, "validation", seen_events)
    rows = []
    for hypothesis in hypotheses():
        formation_checks, validation_checks = _checks(hypothesis, train), _checks(hypothesis, held)
        formation_conflicts = [r["episode_id"] for r in formation_checks if r["match"] is False]
        validation_conflicts = [r["episode_id"] for r in validation_checks if r["match"] is False]
        if train_reasons:
            disposition, reasons = "DEFER", ["formation_incomplete"]
        elif formation_conflicts:
            disposition, reasons = "REJECT", ["formation_counterexample"]
        elif held_reasons:
            disposition, reasons = "DEFER", ["validation_incomplete"]
        elif validation_conflicts:
            disposition, reasons = "REJECT", ["validation_counterexample"]
        else:
            disposition, reasons = "RETAIN", ["independent_recurrence"]
        rows.append({**hypothesis, "formation_checks": formation_checks, "validation_checks": validation_checks,
                     "formation_conflicts": formation_conflicts, "validation_conflicts": validation_conflicts,
                     "formation_compatible": not formation_conflicts, "disposition": disposition, "reasons": reasons})
    result = {"schema": RULE, "protocol": protocol, "formation": train, "validation": held,
              "formation_reasons": train_reasons, "validation_reasons": held_reasons, "hypotheses": rows,
              "formation_count": sum(r["comparable"] for r in train), "validation_count": sum(r["comparable"] for r in held),
              "authority": "finite-local-prediction-only; not-cause-action-NERV-canonical-model-or-E"}
    result["model_id"] = digest(result)
    return deepcopy(result)


class ContextualCarryPredictor:
    """Frozen formation/validation evidence; four independent prospective trials."""
    def __init__(self, protocol, formation, validation):
        self._model = inspect_context_hypotheses(protocol, formation, validation)
        self._protocol = self._model["protocol"]
        self._predictions, self._outcomes = {}, {}

    def predict(self, *, request_id, episode_id, context):
        require(ident(request_id) and ident(episode_id), "invalid_prediction_identity")
        request = {"request_id": request_id, "episode_id": episode_id, "context": deepcopy(context)}
        if request_id in self._predictions:
            old = self._predictions[request_id]
            require(old["request"] == request, "prediction_conflict")
            return deepcopy(old["result"])
        roster = {r["episode_id"]: r["run_id"] for r in self._protocol["forecast"]}
        require(episode_id in roster, "unknown_forecast_episode")
        require(len(self._predictions) < 4, "prediction_budget")
        require(all(p["request"]["episode_id"] != episode_id for p in self._predictions.values()), "forecast_episode_reused")
        reasons = _context(context, self._protocol, roster[episode_id])
        retained = [r for r in self._model["hypotheses"] if r["disposition"] == "RETAIN"]
        if not retained: reasons.append("no_validated_hypothesis")
        alternatives = [{"hypothesis_id": r["hypothesis_id"], "outcome": _outcome(r["predicate"], context)} for r in retained] if not reasons else []
        outcomes = {r["outcome"] for r in alternatives}
        if len(outcomes) > 1: reasons.append("hypothesis_disagreement")
        prediction = "unknown" if reasons else "likely_established" if outcomes == {"established"} else "likely_not_established"
        result = {"request_id": request_id, "episode_id": episode_id, "model_id": self._model["model_id"],
                  "context": deepcopy(context), "prediction": prediction, "reasons": sorted(set(reasons)),
                  "alternatives": alternatives, "authority": self._model["authority"]}
        result["prediction_id"] = digest(result)
        self._predictions[request_id] = {"request": request, "result": deepcopy(result)}
        return deepcopy(result)

    def record_outcome(self, *, request_id, material):
        require(request_id in self._predictions, "prediction_required_before_outcome")
        if request_id in self._outcomes:
            old = self._outcomes[request_id]
            require(old["material"] == material, "outcome_conflict")
            return deepcopy(old["result"])
        prediction = self._predictions[request_id]["result"]
        require(isinstance(material, dict) and material.get("episode_id") == prediction["episode_id"]
                and material.get("context") == prediction["context"], "forecast_context_changed")
        seen = {r["source"]["event"]["event_id"] for phase in ("formation", "validation") for r in self._model[phase] if r["source"] and r["source"]["event"]}
        seen.update(o["material"]["event"]["event_id"] for o in self._outcomes.values() if o["material"]["event"])
        roster = {r["episode_id"]: r["run_id"] for r in self._protocol["forecast"]}
        row = _record(material, self._protocol, roster, seen)
        expected = {"likely_established": "established", "likely_not_established": "not_established"}.get(prediction["prediction"])
        result = {"prediction_id": prediction["prediction_id"], "model_id": self._model["model_id"], "observation": row,
                  "match": expected == row["observed"] if expected is not None and row["comparable"] else None,
                  "interpretation": "local-prediction-check; not-canonical-E-or-model-update"}
        self._outcomes[request_id] = {"material": deepcopy(material), "result": deepcopy(result)}
        return deepcopy(result)

    def snapshot(self):
        return deepcopy({"model": self._model, "predictions": self._predictions, "outcomes": self._outcomes})
