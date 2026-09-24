"""I2 pure Experience-to-relation-profile compilation."""

from copy import deepcopy
import hashlib
import json
from typing import Any

from ..structural.relations import build_reported_relation, validate_relation_sources


PROFILE_COMPILER_ID = "experience-relation-profile-v1"
SUPPORTED_OUTCOMES = {"approach_progress", "approach_no_progress"}


class ExperienceProfileError(ValueError):
    pass


def build_relation_profiles(window: dict[str, Any],
                            history_snapshot: dict[str, Any]) -> dict[str, Any]:
    """Project a bounded Sleep source window without mutating either input."""
    source_ids, agent_id = _validate_window(window)
    records = _records_by_id(history_snapshot)
    profiles = []
    for source_id in source_ids:
        record = records.get(source_id)
        if record is None:
            raise ExperienceProfileError("Sleep window source Experience disappeared")
        if record.get("agent_id") != agent_id:
            raise ExperienceProfileError("Sleep window source agent identity changed")
        profiles.append(build_experience_profile(record))

    all_relations = [relation for profile in profiles for relation in profile["relations"]]
    validate_relation_sources(all_relations, set(source_ids))
    return {
        "profile_set_id": hashlib.sha256(
            json.dumps([PROFILE_COMPILER_ID, window["window_id"], source_ids], sort_keys=True).encode()
        ).hexdigest(),
        "window_id": window["window_id"],
        "window_status": window["status"],
        "agent_id": agent_id,
        "source_experience_ids": list(source_ids),
        "profiles": profiles,
        "compiler": PROFILE_COMPILER_ID,
        "authority": "GameAI-local-derived-profile; not-candidate-commitment-M_B-or-T1",
    }


def build_experience_profile(record: dict[str, Any]) -> dict[str, Any]:
    """Build one derived Profile for an already admitted Experience record."""
    source_id = record["record_id"]
    action = record.get("action")
    context = record.get("context")
    if not isinstance(action, dict) or action.get("type") != "approach":
        raise ExperienceProfileError("S2 supports admitted approach Experience only")
    target_id = action.get("target_id")
    if not isinstance(target_id, str) or not target_id:
        raise ExperienceProfileError("Experience target_id must be non-empty")
    if not isinstance(context, dict):
        raise ExperienceProfileError("Experience context must be an object")
    purpose = context.get("purpose")
    perception_rule = context.get("perception_rule")
    if not isinstance(purpose, str) or not purpose:
        raise ExperienceProfileError("Experience context purpose must be non-empty")
    if not isinstance(perception_rule, str) or not perception_rule:
        raise ExperienceProfileError("Experience perception_rule must be non-empty")
    outcome = record.get("outcome")
    if outcome not in SUPPORTED_OUTCOMES:
        raise ExperienceProfileError("unsupported Experience outcome")

    experience_ref = f"experience:{source_id}"
    relations = [
        build_reported_relation(
            source_experience_id=source_id, kind="actor", subject=experience_ref,
            predicate="actor", object_value=record["agent_id"],
        ),
        build_reported_relation(
            source_experience_id=source_id, kind="target", subject=experience_ref,
            predicate="target", object_value=target_id,
        ),
        build_reported_relation(
            source_experience_id=source_id, kind="context", subject=experience_ref,
            predicate=purpose, object_value=perception_rule,
        ),
        build_reported_relation(
            source_experience_id=source_id, kind="action", subject=record["agent_id"],
            predicate="performed", object_value="approach",
        ),
        build_reported_relation(
            source_experience_id=source_id, kind="outcome", subject=experience_ref,
            predicate="reported_outcome", object_value=outcome,
            polarity="supportive" if outcome == "approach_progress" else "unresolved",
        ),
    ]
    profile_id = hashlib.sha256(
        json.dumps([PROFILE_COMPILER_ID, source_id, relations], sort_keys=True).encode()
    ).hexdigest()
    return {
        "profile_id": profile_id,
        "source_experience_id": source_id,
        "relations": relations,
        "authority": "derived-comparison-profile-only",
    }


def _validate_window(window: dict[str, Any]) -> tuple[list[str], str]:
    if not isinstance(window, dict):
        raise ExperienceProfileError("Sleep window must be an object")
    for name in ("window_id", "agent_id", "status"):
        if not isinstance(window.get(name), str) or not window[name]:
            raise ExperienceProfileError(f"Sleep window {name} must be non-empty")
    source_ids = window.get("source_experience_ids")
    if not isinstance(source_ids, list) or len(source_ids) > 6:
        raise ExperienceProfileError("Sleep window source IDs must be a finite list")
    if len(source_ids) != len(set(source_ids)) or any(
        not isinstance(source_id, str) or not source_id for source_id in source_ids
    ):
        raise ExperienceProfileError("Sleep window source IDs must be unique and non-empty")
    if window["status"] not in {"READY", "INSUFFICIENT_EVIDENCE"}:
        raise ExperienceProfileError("unsupported Sleep window status")
    return list(source_ids), window["agent_id"]


def _records_by_id(snapshot: dict[str, Any]) -> dict[str, dict[str, Any]]:
    if not isinstance(snapshot, dict) or snapshot.get("authority") != "read-only-history":
        raise ExperienceProfileError("Profile compiler requires a raw Experience snapshot")
    records = snapshot.get("records")
    if not isinstance(records, list):
        raise ExperienceProfileError("Experience records must be a list")
    by_id = {}
    for record in records:
        if not isinstance(record, dict):
            raise ExperienceProfileError("Experience record must be an object")
        record_id = record.get("record_id")
        if not isinstance(record_id, str) or not record_id:
            raise ExperienceProfileError("Experience record_id must be non-empty")
        if record_id in by_id:
            raise ExperienceProfileError("duplicate Experience record identity")
        by_id[record_id] = deepcopy(record)
    return by_id
