"""I1 finite relation alignment for local similarity observation."""

import hashlib
import json
from typing import Any

from .relations import build_reported_relation, RelationStructureError


SIMILARITY_EVALUATOR_ID = "finite-relation-similarity-v1"
SELECTED_KINDS = ("actor", "target", "context", "action", "outcome")
OPPOSING_POLARITIES = {("supportive", "adverse"), ("adverse", "supportive")}


class SimilarityStructureError(ValueError):
    pass


def compare_relation_profiles(left: dict[str, Any], right: dict[str, Any],
                              *, purpose: str) -> dict[str, Any]:
    """Compare two profiles without forming a cluster or candidate."""
    if not isinstance(purpose, str) or not purpose.strip():
        raise SimilarityStructureError("comparison purpose must be non-empty")
    left_id, left_by_kind = _profile_relations(left)
    right_id, right_by_kind = _profile_relations(right)
    if left_id == right_id:
        raise SimilarityStructureError("similarity requires two distinct Profiles")

    matched = []
    different = []
    conflicts = []
    unresolved = []
    available = []
    missing = []
    for kind in SELECTED_KINDS:
        left_relation = left_by_kind.get(kind)
        right_relation = right_by_kind.get(kind)
        if left_relation is None or right_relation is None:
            missing.append({
                "kind": kind,
                "left_available": left_relation is not None,
                "right_available": right_relation is not None,
            })
            continue
        available.append(kind)
        left_signature = relation_signature(left_relation)
        right_signature = relation_signature(right_relation)
        if left_signature == right_signature:
            matched.append({"kind": kind, "signature": left_signature})
        else:
            difference = {
                "kind": kind,
                "left": left_signature,
                "right": right_signature,
            }
            different.append(difference)
            if _is_explicit_conflict(left_signature, right_signature):
                conflicts.append(difference)
        for side, relation in (("left", left_relation), ("right", right_relation)):
            if relation["polarity"] == "unresolved":
                unresolved.append({
                    "side": side,
                    "kind": kind,
                    "relation_id": relation["relation_id"],
                    "source_experience_ids": list(relation["source_experience_ids"]),
                })

    complete = not missing
    score = None
    if complete:
        score = {
            "matched": len(matched),
            "compared": len(available),
            "ratio": len(matched) / len(available),
        }
    profile_ids = sorted((left_id, right_id))
    observation_id = hashlib.sha256(json.dumps([
        SIMILARITY_EVALUATOR_ID, purpose, profile_ids, available, missing,
        matched, different, conflicts, unresolved,
    ], sort_keys=True).encode()).hexdigest()
    return {
        "similarity_observation_id": observation_id,
        "profile_ids": profile_ids,
        "source_experience_ids": sorted((
            left["source_experience_id"], right["source_experience_id"]
        )),
        "purpose": purpose,
        "evaluator": SIMILARITY_EVALUATOR_ID,
        "selected_relation_kinds": list(SELECTED_KINDS),
        "matched_relations": matched,
        "different_relations": different,
        "coverage": {
            "status": "complete" if complete else "incomplete",
            "available": available,
            "missing": missing,
        },
        "conflict": conflicts,
        "unresolved": unresolved,
        "score": score,
        "authority": "similarity-observation-only; not-cluster-candidate-E-H-or-truth",
    }


def relation_signature(relation: dict[str, Any]) -> dict[str, str]:
    required = ("kind", "predicate", "object", "status", "polarity", "strength")
    signature = {}
    for field in required:
        value = relation.get(field) if isinstance(relation, dict) else None
        if not isinstance(value, str) or not value:
            raise SimilarityStructureError(f"relation {field} must be non-empty")
        signature[field] = value
    return signature


def _profile_relations(profile: dict[str, Any]) -> tuple[str, dict[str, dict[str, Any]]]:
    if not isinstance(profile, dict):
        raise SimilarityStructureError("Profile must be an object")
    profile_id = profile.get("profile_id")
    source_id = profile.get("source_experience_id")
    relations = profile.get("relations")
    if not isinstance(profile_id, str) or not profile_id:
        raise SimilarityStructureError("profile_id must be non-empty")
    if not isinstance(source_id, str) or not source_id:
        raise SimilarityStructureError("Profile source Experience must be non-empty")
    if not isinstance(relations, list):
        raise SimilarityStructureError("Profile relations must be a list")
    by_kind = {}
    for relation in relations:
        signature = relation_signature(relation)
        kind = signature["kind"]
        if kind not in SELECTED_KINDS:
            raise SimilarityStructureError("unsupported relation kind")
        if kind in by_kind:
            raise SimilarityStructureError("Profile contains duplicate relation kind")
        source_ids = relation.get("source_experience_ids")
        if source_ids != [source_id]:
            raise SimilarityStructureError("relation provenance differs from Profile source")
        relation_id = relation.get("relation_id")
        if not isinstance(relation_id, str) or not relation_id:
            raise SimilarityStructureError("relation_id must be non-empty")
        try:
            expected = build_reported_relation(
                source_experience_id=source_id,
                kind=signature["kind"],
                subject=relation.get("subject"),
                predicate=signature["predicate"],
                object_value=signature["object"],
                polarity=signature["polarity"],
                strength=signature["strength"],
            )
        except RelationStructureError as exc:
            raise SimilarityStructureError(str(exc)) from exc
        if relation_id != expected["relation_id"]:
            raise SimilarityStructureError("relation identity differs from its structure")
        by_kind[kind] = relation
    return profile_id, by_kind


def _is_explicit_conflict(left: dict[str, str], right: dict[str, str]) -> bool:
    same_relation = all(
        left[field] == right[field] for field in ("kind", "predicate", "object", "status")
    )
    return same_relation and (left["polarity"], right["polarity"]) in OPPOSING_POLARITIES
