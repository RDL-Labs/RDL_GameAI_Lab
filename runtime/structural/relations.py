"""I1 finite relation construction and validation."""

import hashlib
import json
from typing import Any


RELATION_KINDS = {"actor", "target", "context", "action", "outcome"}
RELATION_STATUSES = {"reported"}
RELATION_POLARITIES = {"neutral", "supportive", "adverse", "unresolved"}
RELATION_STRENGTHS = {"single_report"}


class RelationStructureError(ValueError):
    pass


def build_reported_relation(*, source_experience_id: str, kind: str,
                            subject: str, predicate: str, object_value: str,
                            polarity: str = "neutral",
                            strength: str = "single_report") -> dict[str, Any]:
    """Build one finite relation without interpreting it as truth or authority."""
    for name, value in (
        ("source_experience_id", source_experience_id),
        ("subject", subject),
        ("predicate", predicate),
        ("object", object_value),
    ):
        if not isinstance(value, str) or not value.strip():
            raise RelationStructureError(f"{name} must be non-empty")
    if kind not in RELATION_KINDS:
        raise RelationStructureError("unsupported relation kind")
    if polarity not in RELATION_POLARITIES:
        raise RelationStructureError("unsupported relation polarity")
    if strength not in RELATION_STRENGTHS:
        raise RelationStructureError("unsupported relation strength")

    identity = [kind, subject, predicate, object_value, "reported", polarity, strength]
    relation_id = hashlib.sha256(
        json.dumps([source_experience_id, identity], sort_keys=True).encode()
    ).hexdigest()
    return {
        "relation_id": relation_id,
        "kind": kind,
        "subject": subject,
        "predicate": predicate,
        "object": object_value,
        "status": "reported",
        "polarity": polarity,
        "strength": strength,
        "source_experience_ids": [source_experience_id],
    }


def validate_relation_sources(relations: list[dict[str, Any]],
                              allowed_source_ids: set[str]) -> None:
    """Reject missing, duplicated, or out-of-bound provenance references."""
    seen_ids = set()
    for relation in relations:
        if not isinstance(relation, dict):
            raise RelationStructureError("relation must be an object")
        relation_id = relation.get("relation_id")
        if not isinstance(relation_id, str) or not relation_id:
            raise RelationStructureError("relation_id must be non-empty")
        if relation_id in seen_ids:
            raise RelationStructureError("duplicate relation identity")
        seen_ids.add(relation_id)
        source_ids = relation.get("source_experience_ids")
        if not isinstance(source_ids, list) or len(source_ids) != 1:
            raise RelationStructureError("reported relation requires one source Experience")
        if source_ids[0] not in allowed_source_ids:
            raise RelationStructureError("relation source is outside the bounded window")
