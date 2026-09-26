"""NERV-4A pure common-relation candidates; no T1 or coordinator hook."""
from copy import deepcopy
from dataclasses import asdict
from itertools import combinations
import hashlib
import json

from .neural_gradient import RELATIONS, NeuralParameter
from .neural_outcome import compile_neural_sleep_profile, NeuralAdmissionError

RULE = "nerv-common-relations-v1"
CANDIDATE_SCHEMA = "nerv-relation-candidate-v1"


class NeuralCandidateError(ValueError):
    pass


def _require(ok, why):
    if not ok:
        raise NeuralCandidateError(why)


def _id(value):
    return isinstance(value, str) and bool(value.strip()) and len(value) <= 128


def _json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def _hash(value):
    return hashlib.sha256(_json(value).encode()).hexdigest()


def _signature(d, context):
    return {"relation": d["relation"], "direction": d["direction"],
            "strength": d["magnitude_band"], "magnitude": d["magnitude"], "context_signature": deepcopy(context)}


def build_neural_candidate(materials, request):
    fields = {"run_id", "agent_id", "parameter_id", "parameter_revision", "rule_version",
              "source_experience_ids", "sleep_cycle", "formation_tick"}
    _require(isinstance(request, dict) and set(request) == fields, "invalid_request")
    _require(all(_id(request[k]) for k in ("run_id", "agent_id", "parameter_id", "sleep_cycle")), "invalid_identity")
    _require(type(request["parameter_revision"]) is int and request["parameter_revision"] == 1, "invalid_revision")
    _require(request["rule_version"] == RULE, "invalid_rule")
    _require(type(request["formation_tick"]) is int and request["formation_tick"] >= 0, "invalid_tick")
    ids = request["source_experience_ids"]
    _require(isinstance(ids, list) and len(ids) <= 6, "selection_budget")
    _require(all(_id(i) for i in ids) and len(set(ids)) == len(ids), "invalid_or_duplicate_experience")
    try:
        compiled = compile_neural_sleep_profile(materials)
    except NeuralAdmissionError as exc:
        raise NeuralCandidateError(str(exc)) from exc
    parameter = asdict(NeuralParameter.parse(materials["parameter"]))
    _require(request["run_id"] == materials["run_id"] and request["agent_id"] == materials["agent_id"], "context_mismatch")
    _require(request["parameter_id"] == parameter["parameter_id"] and request["parameter_revision"] == parameter["revision"], "parameter_mismatch")
    by_experience = {p["source_experience_id"]: p for p in materials["projections"]}
    _require(all(i in by_experience for i in ids), "unknown_experience")
    ids = sorted(ids)
    selected = [deepcopy(by_experience[i]) for i in ids]
    normalized_request = deepcopy(request)
    normalized_request["source_experience_ids"] = ids
    selection_id = _hash({"request": normalized_request, "parameter": parameter, "projections": selected})
    profile_ids = {p["source_experience_id"]: p["profile_id"] for p in compiled["profiles"]}
    bias_ids = {(b["source_experience_id"], b["relation"]): b["bias_id"] for b in materials["biases"]}
    result = {"schema": RULE, "request": normalized_request, "parameter": deepcopy(parameter),
              "selection_id": selection_id, "selected_projections": selected,
              "status": "insufficient_experiences", "comparison_complete": False, "reasons": [],
              "pair_results": [], "relation_results": [], "candidate": None,
              "authority": "finite-neural-comparison-only; not-T1-M_B-or-action"}

    def finish():
        return dict(result, result_id=_hash(result))

    if len(ids) < 3:
        result["reasons"] = ["fewer_than_three_experiences"]
        return finish()
    contexts = [p["raw_record"]["context_signature"] for p in selected]
    if any(c.get("food_id") != "tasty_food" for c in contexts):
        result["reasons"].append("unsupported_context")
    if any(_json(c) != _json(contexts[0]) for c in contexts[1:]):
        result["reasons"].append("context_difference")
    if result["reasons"]:
        result["status"] = "not_comparable"
        return finish()
    dimensions = {p["source_experience_id"]: {d["relation"]: d for d in p["dimensions"]} for p in selected}
    for left, right in combinations(ids, 2):
        relations = []
        for name in RELATIONS:
            a, b = dimensions[left][name], dimensions[right][name]
            reasons = []
            for side, d in (("left", a), ("right", b)):
                if d["magnitude"] == 0:
                    reasons.append({"side": side, "reason": "neural_filtered" if d["raw"]["magnitude"] else "raw_zero",
                                    "projection_reasons": deepcopy(d["reasons"])})
            if a["magnitude"] and b["magnitude"]:
                if a["direction"] != b["direction"]:
                    reasons.append({"reason": "direction_conflict"})
                if a["magnitude"] != b["magnitude"]:
                    reasons.append({"reason": "strength_difference"})
            relations.append({"relation": name, "matched": not reasons, "reasons": reasons,
                              "left": deepcopy(a), "right": deepcopy(b)})
        result["pair_results"].append({"source_experience_ids": [left, right], "relations": relations})
    common = []
    for name in RELATIONS:
        groups, unsupported = {}, []
        for eid in ids:
            d = dimensions[eid][name]
            if d["magnitude"]:
                signature = _signature(d, contexts[0])
                key = _json(signature)
                groups.setdefault(key, {"signature": signature, "source_experience_ids": [], "source_bias_ids": []})
                groups[key]["source_experience_ids"].append(eid)
                groups[key]["source_bias_ids"].append(bias_ids[eid, name])
            else:
                unsupported.append({"source_experience_id": eid, "reason": "neural_filtered" if d["raw"]["magnitude"] else "raw_zero",
                              "projection_reasons": deepcopy(d["reasons"])})
        supports = [dict(groups[k], support_count=len(groups[k]["source_experience_ids"])) for k in sorted(groups)]
        unanimous = len(supports) == 1 and supports[0]["support_count"] == len(ids)
        result["relation_results"].append({"relation": name, "common": unanimous, "support_groups": supports, "unsupported": unsupported})
        if unanimous:
            common.append(supports[0])
    result.update(status="candidate_formed" if common else "no_candidate", comparison_complete=True)
    if common:
        candidate = {"schema": CANDIDATE_SCHEMA, "rule_version": RULE,
                     "run_id": request["run_id"], "agent_id": request["agent_id"], "parameter": deepcopy(parameter),
                     "sleep_cycle": request["sleep_cycle"], "formation_tick": request["formation_tick"], "selection_id": selection_id,
                     "source_experience_ids": ids, "support_count": len(ids), "common_relations": common,
                     "source_gradient_ids": sorted(p["source_gradient_id"] for p in selected),
                     "source_projection_ids": sorted(p["projection_id"] for p in selected),
                     "source_profile_ids": sorted(profile_ids[i] for i in ids if i in profile_ids),
                     "source_bias_ids": sorted({bid for g in common for bid in g["source_bias_ids"]}),
                     "source_world_event_ids": sorted({i for p in selected for i in p["source_world_event_ids"]}),
                     "authority": "GameAI-local-neural-candidate; not-canonical-CandidateRelation-T1-M_B-or-action"}
        result["candidate"] = dict(candidate, candidate_id=_hash(candidate))
    return finish()
