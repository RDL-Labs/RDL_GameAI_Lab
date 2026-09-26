"""NERV-4B: explicit neural evidence preparation and uninspected T1-A intake."""
from copy import deepcopy
import hashlib
import json

from .neural_candidate import build_neural_candidate
from .t1_material_expansion import _validate_canonical_sources

PREPARATION_SCHEMA = "nerv-t1-preparation-v1"
MATERIAL_SCHEMA = "nerv-t1-relation-material-v1"
PURPOSE = "inspect_neural_common_relations"


class NeuralT1Error(ValueError):
    pass


def _hash(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                     allow_nan=False).encode()).hexdigest()


def prepare_neural_t1_materials(materials, candidate_request):
    """Rebuild the candidate, preserving dependent raw/neural evidence as one pair."""
    source = build_neural_candidate(materials, candidate_request)
    candidate = source["candidate"]
    children = []
    if candidate is not None:
        for group in candidate["common_relations"]:
            relation = group["signature"]["relation"]
            evidence = []
            for projection in source["selected_projections"]:
                dimension = next(d for d in projection["dimensions"] if d["relation"] == relation)
                evidence.append({
                    "source_experience_id": projection["source_experience_id"],
                    "source_gradient_id": projection["source_gradient_id"],
                    "source_projection_id": projection["projection_id"],
                    "source_world_event_ids": deepcopy(projection["source_world_event_ids"]),
                    "raw_dimension": deepcopy(dimension["raw"]),
                    "neural_dimension": deepcopy(dimension),
                    "dependency": "same-experience-derived-evidence; not-independent-votes",
                })
            child = {
                "schema_version": MATERIAL_SCHEMA,
                "source_candidate_id": candidate["candidate_id"],
                "source_result_id": source["result_id"],
                "run_id": candidate["run_id"], "agent_id": candidate["agent_id"],
                "parameter": deepcopy(candidate["parameter"]),
                "rule_version": candidate["rule_version"],
                "sleep_cycle": candidate["sleep_cycle"], "formation_tick": candidate["formation_tick"],
                "common_relation_signature": deepcopy(group["signature"]),
                "source_experience_ids": deepcopy(group["source_experience_ids"]),
                "source_bias_ids": deepcopy(group["source_bias_ids"]),
                "support_count": group["support_count"], "evidence_pairs": evidence,
                "disposition": "UNINSPECTED",
                "authority": "neural-inspection-material-only; not-selected-adopted-M_B-or-action",
            }
            children.append(dict(child, candidate_id=_hash(child)))
    result = {"schema": PREPARATION_SCHEMA,
              "status": "ready_for_inspection" if children else "no_inspection_materials",
              "source_result": source, "children": children,
              "authority": "pure-preparation-only; not-expanded-selected-or-action"}
    return dict(result, preparation_id=_hash(result))


def _validate_binding(binding, source, state, model, path):
    fields = {"run_id", "agent_id", "transition_id", "model_ref", "assessment_id",
              "purpose", "boundary_ref", "criteria_ref"}
    if not isinstance(binding, dict) or set(binding) != fields:
        raise NeuralT1Error("invalid_binding_fields")
    if not all(isinstance(v, str) and v.strip() and len(v) <= 256 for v in binding.values()):
        raise NeuralT1Error("invalid_binding_value")
    if binding["purpose"] != PURPOSE:
        raise NeuralT1Error("unsupported_purpose")
    agent, transition = _validate_canonical_sources(state, model, path)
    expected = {"run_id": source["request"]["run_id"], "agent_id": source["request"]["agent_id"],
                "transition_id": transition, "model_ref": model["model_ref"],
                "assessment_id": path["assessment_id"]}
    if agent != expected["agent_id"] or any(binding[k] != v for k, v in expected.items()):
        raise NeuralT1Error("binding_mismatch")


def expand_neural_t1_materials(materials, candidate_request, binding,
                               m_delta_state, model, review_path, store):
    """Explicit opt-in; only the supplied T1-A store may change.

    Canonical inputs must be the caller's current snapshot. This function validates
    their mutual references; it cannot authenticate a fabricated or stale snapshot.
    """
    prepared = prepare_neural_t1_materials(materials, candidate_request)
    _validate_binding(binding, prepared["source_result"], m_delta_state, model, review_path)
    if not prepared["children"]:
        return {"status": "no_inspection_materials", "preparation": prepared, "bundle": None}
    children = deepcopy(prepared["children"])
    for child in children:
        child["binding"] = deepcopy(binding)
        child["preparation_id"] = prepared["preparation_id"]
        # Store the finite parent diagnosis with each child, so a frozen bundle is
        # self-contained and cannot lose excluded or filtered relations.
        child["source_result"] = deepcopy(prepared["source_result"])
    bundle = store.expand(m_delta_state=m_delta_state, model=model,
                          review_path=review_path, candidates=children)
    return {"status": "expanded_for_inspection" if bundle is not None else "capacity_rejected",
            "preparation": prepared, "bundle": bundle}
