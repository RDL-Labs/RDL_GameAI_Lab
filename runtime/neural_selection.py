"""NERV-4C: finite acquisition recurrence inspection, never reconstruction."""
from copy import deepcopy
import hashlib
import json

from .neural_t1 import expand_neural_t1_materials
from .t1_material_expansion import T1MaterialExpansionStore

RULE = "nerv-food-acquisition-selection-v1"
PURPOSE = "inspect_food_acquisition_recurrence"
TARGET_SCHEMA = "nerv-food-acquisition-target-v1"
DIMENSION = "food_acquisition_outcome"


class NeuralSelectionError(ValueError):
    pass


def _require(ok, reason):
    if not ok:
        raise NeuralSelectionError(reason)


def _json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def _hash(value):
    return hashlib.sha256(_json(value).encode()).hexdigest()


def _id(value):
    return isinstance(value, str) and bool(value.strip()) and len(value) <= 256


def _normalized_bundle(bundle):
    copied = deepcopy(bundle)
    copied["materials"] = sorted(copied["materials"], key=lambda m: m["material_id"])
    return copied


def _rebuild(bundle, materials, request, model):
    """Reproduce the complete frozen bundle in a temporary store, never mutate it."""
    _require(isinstance(bundle, dict) and isinstance(bundle.get("materials"), list), "invalid_bundle")
    items = bundle["materials"]
    _require(5 <= len(items) <= 8 and all(isinstance(i, dict) for i in items), "bundle_budget")
    kinds = ("current_M_B", "RIB_B", "RIB_B_prime", "unresolved_residual")
    canonical = {}
    for kind in kinds:
        matches = [m for m in items if m.get("kind") == kind]
        _require(len(matches) == 1, "canonical_material_set")
        canonical[kind] = matches[0]["payload"]
    _require(model == canonical["current_M_B"], "model_mismatch")
    children = [m for m in items if m.get("kind") == "CandidateRelation"]
    _require(len(children) == len(items) - 4, "unexpected_material")
    binding = children[0]["payload"]["binding"]
    residual = canonical["unresolved_residual"]
    state = {"phase": "M_delta", "transition": {"transition_id": bundle["transition_id"]},
             "model_ref": bundle["model_ref"], "latest_assessment_id": bundle["assessment_id"],
             "H_vec": residual["H_vec"], "H": residual["H"],
             "latest_review_revision": residual["review_revision"]}
    path = {"agent_id": bundle["agent_id"], "model_ref": bundle["model_ref"],
            "assessment_id": bundle["assessment_id"], "RIB_B": canonical["RIB_B"],
            "RIB_B_prime": canonical["RIB_B_prime"]}
    rebuilt = expand_neural_t1_materials(materials, request, binding, state, model, path,
                                        T1MaterialExpansionStore())
    _require(rebuilt["bundle"] is not None, "no_reconstructed_candidate")
    _require(_normalized_bundle(bundle) == _normalized_bundle(rebuilt["bundle"]), "changed_frozen_bundle")
    return rebuilt["preparation"], binding


def _target(target, binding, model, context):
    if target is None:
        return ["target_mapping_unavailable"]
    fields = {"schema", "model_ref", "boundary_ref", "criteria_ref", "target_dimension", "relation",
              "context_signature", "positive_meaning", "negative_meaning", "allowed_mismatches"}
    _require(isinstance(target, dict) and set(target) == fields, "invalid_target_fields")
    _require(target["schema"] == TARGET_SCHEMA and target["relation"] == "acquisition"
             and target["target_dimension"] == DIMENSION
             and target["positive_meaning"] == "food_acquired"
             and target["negative_meaning"] == "food_not_acquired"
             and type(target["allowed_mismatches"]) is int and target["allowed_mismatches"] == 0,
             "unsupported_target_rule")
    _require(all(target[k] == binding[k] for k in ("model_ref", "boundary_ref", "criteria_ref")),
             "target_binding_mismatch")
    _require(_json(target["context_signature"]) == _json(context), "target_context_mismatch")
    return [] if DIMENSION in model["boundary"]["dimensions"] else ["target_mapping_unavailable"]


def _acquisition(projection):
    raw = projection["raw_record"]
    acquired = raw.get("outcome_facts", {}).get("food_acquired")
    _require(type(acquired) is bool, "missing_acquisition_fact")
    expected = {"relation": "acquisition", "direction": "positive" if acquired else "negative",
                "magnitude": 3, "magnitude_band": "STRONG"}
    dimension = next(d for d in projection["dimensions"] if d["relation"] == "acquisition")
    _require(dimension["raw"] == expected, "acquisition_rule_inconsistent")
    return dimension


def evaluate_neural_t1_selection(*, bundle, materials, candidate_request,
                                 validation_experience_ids, model, target=None):
    """Evaluate frozen supplied sources; callers own snapshot freshness/authenticity."""
    ids = validation_experience_ids
    _require(isinstance(ids, list) and len(ids) <= 6, "validation_budget")
    _require(all(_id(i) for i in ids) and len(ids) == len(set(ids)), "invalid_validation_ids")
    try:
        prepared, binding = _rebuild(bundle, materials, candidate_request, model)
        source = prepared["source_result"]
        by_id = {p["source_experience_id"]: p for p in materials["projections"]}
        _require(all(i in by_id for i in ids), "unknown_validation_experience")
        formation = source["selected_projections"]
        _require(not set(ids).intersection(p["source_experience_id"] for p in formation), "formation_validation_overlap")
        events = {e for p in formation for e in p["source_world_event_ids"]}
        validation = [deepcopy(by_id[i]) for i in sorted(ids)]
        for p in validation:
            _require(not events.intersection(p["source_world_event_ids"]), "validation_event_overlap")
            events.update(p["source_world_event_ids"])
        for p in formation + validation:
            _acquisition(p)
        context = formation[0]["raw_record"]["context_signature"]
        mapping_reasons = _target(target, binding, model, context)
        decisions = []
        for item in sorted(bundle["materials"], key=lambda m: m["material_id"]):
            reasons, pairs = [], []
            comparable = False
            disposition = "DEFER"
            if item["kind"] != "CandidateRelation":
                reasons = ["canonical_material_out_of_scope"]
            else:
                child = item["payload"]
                signature = child["common_relation_signature"]
                if signature["relation"] != "acquisition":
                    reasons = ["relation_out_of_scope"]
                else:
                    reasons = list(mapping_reasons)
                    if not validation:
                        reasons.append("no_validation_experience")
                    for p in validation:
                        d = _acquisition(p)
                        pair_reasons = []
                        if _json(p["raw_record"]["context_signature"]) != _json(context):
                            pair_reasons.append("validation_context_mismatch")
                        if not d["magnitude"]:
                            pair_reasons.append("validation_not_comparable")
                        matched = d["direction"] == signature["direction"] and d["magnitude"] == signature["magnitude"]
                        pairs.append({"source_experience_id": p["source_experience_id"],
                                      "comparable": not pair_reasons, "matched": matched if not pair_reasons else None,
                                      "raw_dimension": deepcopy(d["raw"]), "neural_dimension": deepcopy(d),
                                      "reasons": pair_reasons})
                        reasons.extend(pair_reasons)
                    comparable = not reasons
                    if comparable:
                        disposition = "RETAIN" if all(p["matched"] for p in pairs) else "REJECT"
                        reasons = ["recurrence_within_declared_scope" if disposition == "RETAIN" else "recurrence_counterexample"]
            decisions.append({"material_id": item["material_id"], "disposition": disposition,
                              "reasons": sorted(set(reasons)), "comparison_complete": comparable,
                              "formation_support_count": item["payload"].get("support_count") if item["kind"] == "CandidateRelation" else None,
                              "validation_count": len(validation), "pair_results": pairs})
        result = {"schema": "nerv-t1-selection-evaluation-v1", "rule_version": RULE, "purpose": PURPOSE,
                  "bundle_id": bundle["bundle_id"], "binding": deepcopy(binding), "model": deepcopy(model),
                  "target": deepcopy(target), "source_result": source, "validation_projections": validation,
                  "decisions": decisions, "authority": "finite-selection-only; not-reconstruction-M_B-or-action"}
        return dict(result, evaluation_id=_hash(result))
    except (KeyError, TypeError, StopIteration) as exc:
        raise NeuralSelectionError("incomplete_inspection_sources") from exc


def record_neural_t1_selection(*, ledger, reviewer, expected_revision, **inputs):
    evaluation = evaluate_neural_t1_selection(**inputs)
    evidence = _json(evaluation)
    review = {"reviewer": reviewer, "expected_revision": expected_revision,
              "materials": [{"material_id": d["material_id"], "disposition": d["disposition"],
                             "basis": ";".join(d["reasons"]), "evidence": evidence}
                            for d in evaluation["decisions"]]}
    record = ledger.inspect(inputs["bundle"], review)
    return {"status": "recorded" if record is not None else "capacity_rejected",
            "evaluation": evaluation, "record": record}
