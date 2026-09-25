"""Project one Local Bias shadow candidate into finite T1-ready candidates."""

from copy import deepcopy
import hashlib
import json
from typing import Any


PROJECTION_ID = "local-bias-t1-candidate-projection-v1"
SOURCE_SCHEMA = "local-bias-deep-similarity-v1"
MAX_RELATIONS = 16


class LocalBiasT1ProjectionError(ValueError):
    pass


def project_local_bias_candidate(candidate: dict[str, Any]) -> list[dict[str, Any]]:
    """Return one independently inspectable CandidateRelation per bias relation."""
    source = _validate(candidate)
    projected = []
    for relation in source["common_bias_relations"]:
        signature = deepcopy(relation)
        child_id = _stable(PROJECTION_ID, source["candidate_id"], signature)
        projected.append({
            "candidate_id": child_id,
            "schema_version": PROJECTION_ID,
            "agent_id": source["agent_id"],
            "sleep_cycle": source["sleep_cycle"],
            "formation_tick": source["formation_tick"],
            "source_local_bias_candidate_id": source["candidate_id"],
            "source_experience_ids": deepcopy(source["source_experience_ids"]),
            "source_bias_ids": deepcopy(source["source_bias_ids"]),
            "source_world_event_ids": deepcopy(source["source_world_event_ids"]),
            "common_relation_signature": signature,
            "support_count": source["support_count"],
            "authority": (
                "T1-ready-local-candidate-material-only; "
                "not-expanded-selected-adopted-M_B-or-action"
            ),
        })
    return projected


def _validate(candidate: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(candidate, dict) or candidate.get("schema") != SOURCE_SCHEMA:
        raise LocalBiasT1ProjectionError("unsupported Local Bias candidate")
    for field in ("candidate_id", "agent_id", "sleep_cycle"):
        if not isinstance(candidate.get(field), str) or not candidate[field]:
            raise LocalBiasT1ProjectionError(f"{field} must be non-empty")
    relations = candidate.get("common_bias_relations")
    if not isinstance(relations, list) or not relations or len(relations) > MAX_RELATIONS:
        raise LocalBiasT1ProjectionError("candidate relations exceed finite boundary")
    signatures = []
    for relation in relations:
        if not isinstance(relation, dict):
            raise LocalBiasT1ProjectionError("candidate relation must be an object")
        for field in ("relation", "direction", "strength"):
            if not isinstance(relation.get(field), str) or not relation[field]:
                raise LocalBiasT1ProjectionError(f"relation {field} must be non-empty")
        if type(relation.get("magnitude")) is not int or relation["magnitude"] < 0:
            raise LocalBiasT1ProjectionError("relation magnitude must be non-negative")
        if not isinstance(relation.get("context_signature"), dict):
            raise LocalBiasT1ProjectionError("relation context_signature must be an object")
        signature = json.dumps(relation, sort_keys=True)
        if signature in signatures:
            raise LocalBiasT1ProjectionError("candidate relations must be unique")
        signatures.append(signature)
    for field in ("source_experience_ids", "source_bias_ids", "source_world_event_ids"):
        values = candidate.get(field)
        if not isinstance(values, list) or not values or len(values) != len(set(values)):
            raise LocalBiasT1ProjectionError(f"{field} must be finite and unique")
    if type(candidate.get("formation_tick")) is not int or candidate["formation_tick"] < 0:
        raise LocalBiasT1ProjectionError("formation_tick must be non-negative")
    if type(candidate.get("support_count")) is not int or candidate["support_count"] < 3:
        raise LocalBiasT1ProjectionError("support_count must preserve Deep support")
    return deepcopy(candidate)


def _stable(*parts: Any) -> str:
    return hashlib.sha256(json.dumps(parts, sort_keys=True).encode()).hexdigest()
