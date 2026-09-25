"""I2 pure construction of bounded Deep Similarity shadow output."""

from copy import deepcopy
from itertools import combinations
import hashlib
import json
from typing import Any

from ..structural.similarity import (
    SELECTED_KINDS,
    compare_relation_profiles,
    relation_signature,
)


DEEP_FUNCTION_ID = "deep-similarity-shadow-v1"
PURPOSE = "sleep-deep-common-relation-shadow"
CANDIDATE_KIND_PRIORITY = {"target": 0, "context": 1, "outcome": 2}


class DeepSimilarityError(ValueError):
    pass


def build_deep_similarity_shadow(window: dict[str, Any],
                                 profile_set: dict[str, Any],
                                 *, formation_tick: int) -> dict[str, Any]:
    """Build pair observations, one cluster, and at most one shadow candidate."""
    if type(formation_tick) is not int or formation_tick < 0:
        raise DeepSimilarityError("formation_tick must be a non-negative integer")
    profiles, source_ids = _validate_inputs(window, profile_set)
    observations = [
        compare_relation_profiles(left, right, purpose=PURPOSE)
        for left, right in combinations(profiles, 2)
    ]
    if len(observations) > 15:
        raise DeepSimilarityError("Deep comparison pair limit exceeded")

    common = _common_signatures(profiles)
    complete = all(item["coverage"]["status"] == "complete" for item in observations)
    cluster = None
    candidate = None
    status = "NO_CLUSTER"
    if len(profiles) >= 3 and complete and common:
        profile_ids = [profile["profile_id"] for profile in profiles]
        observation_ids = [item["similarity_observation_id"] for item in observations]
        cluster_id = _stable_id("cluster", window["window_id"], profile_ids, common)
        cluster = {
            "cluster_id": cluster_id,
            "window_id": window["window_id"],
            "profile_ids": profile_ids,
            "source_experience_ids": list(source_ids),
            "similarity_observation_ids": observation_ids,
            "common_relation_signatures": common,
            "member_count": len(profiles),
            "authority": "comparison-cluster-only; not-category-truth-rule-or-commitment",
        }
        eligible = [item for item in common if _candidate_eligible(item)]
        if eligible:
            selected = sorted(eligible, key=_candidate_order)[0]
            candidate_id = _stable_id("candidate", cluster_id, selected, source_ids)
            candidate = {
                "candidate_id": candidate_id,
                "agent_id": window["agent_id"],
                "schema_version": DEEP_FUNCTION_ID,
                "cluster_id": cluster_id,
                "window_id": window["window_id"],
                "sleep_cycle": window["sleep_cycle"],
                "formation_tick": formation_tick,
                "profile_ids": profile_ids,
                "similarity_observation_ids": observation_ids,
                "source_experience_ids": list(source_ids),
                "common_relation_signature": selected,
                "support_count": len(profiles),
                "member_count": len(profiles),
                "coverage": "complete",
                "conflict": _collect(observations, "conflict"),
                "unresolved": _collect(observations, "unresolved"),
                "purpose": PURPOSE,
                "evaluator": DEEP_FUNCTION_ID,
                "authority": "GameAI-local-shadow-candidate; not-truth-commitment-action-M_B-H-or-T1",
            }
            status = "CANDIDATE_FORMED"
        else:
            status = "NO_CANDIDATE"

    return {
        "deep_similarity_id": _stable_id(
            "deep", DEEP_FUNCTION_ID, window["window_id"],
            profile_set["profile_set_id"], formation_tick,
        ),
        "status": status,
        "window_id": window["window_id"],
        "profile_set_id": profile_set["profile_set_id"],
        "agent_id": window["agent_id"],
        "sleep_cycle": window["sleep_cycle"],
        "formation_tick": formation_tick,
        "source_experience_ids": list(source_ids),
        "similarity_observations": observations,
        "cluster": cluster,
        "candidate": candidate,
        "evaluator": DEEP_FUNCTION_ID,
        "authority": "GameAI-local-deep-shadow; not-E-H-theta-M_delta-M_B-prime-or-T1",
    }


def _validate_inputs(window: dict[str, Any], profile_set: dict[str, Any]) -> tuple[list, list]:
    if not isinstance(window, dict) or not isinstance(profile_set, dict):
        raise DeepSimilarityError("window and Profile set must be objects")
    if window.get("status") != "READY":
        raise DeepSimilarityError("Deep Similarity requires a READY Sleep window")
    if profile_set.get("compiler") != "experience-relation-profile-v1":
        raise DeepSimilarityError("unsupported Profile compiler")
    if profile_set.get("window_id") != window.get("window_id"):
        raise DeepSimilarityError("Profile set belongs to a different Sleep window")
    if profile_set.get("agent_id") != window.get("agent_id"):
        raise DeepSimilarityError("Profile set belongs to a different agent")
    source_ids = window.get("source_experience_ids")
    profiles = profile_set.get("profiles")
    if not isinstance(source_ids, list) or not 3 <= len(source_ids) <= 6:
        raise DeepSimilarityError("Deep Similarity requires three to six sources")
    if len(source_ids) != len(set(source_ids)):
        raise DeepSimilarityError("duplicate Sleep source identity")
    if not isinstance(profiles, list) or len(profiles) != len(source_ids):
        raise DeepSimilarityError("Profile count differs from the Sleep window")
    profile_sources = [profile.get("source_experience_id") for profile in profiles]
    if profile_sources != source_ids:
        raise DeepSimilarityError("Profile sources differ from the frozen Sleep window")
    profile_ids = [profile.get("profile_id") for profile in profiles]
    if any(not isinstance(item, str) or not item for item in profile_ids):
        raise DeepSimilarityError("profile_id must be non-empty")
    if len(profile_ids) != len(set(profile_ids)):
        raise DeepSimilarityError("duplicate Profile identity")
    return deepcopy(profiles), list(source_ids)


def _common_signatures(profiles: list[dict[str, Any]]) -> list[dict[str, str]]:
    shared = None
    for profile in profiles:
        signatures = {
            json.dumps(relation_signature(relation), sort_keys=True)
            for relation in profile["relations"]
        }
        shared = signatures if shared is None else shared & signatures
    return [json.loads(item) for item in sorted(shared or set())]


def _candidate_eligible(signature: dict[str, str]) -> bool:
    if signature["kind"] not in CANDIDATE_KIND_PRIORITY:
        return False
    if signature["polarity"] == "unresolved":
        return False
    return True


def _candidate_order(signature: dict[str, str]) -> tuple:
    return (
        CANDIDATE_KIND_PRIORITY[signature["kind"]],
        signature["predicate"], signature["object"],
        signature["status"], signature["polarity"], signature["strength"],
    )


def _collect(observations: list[dict[str, Any]], field: str) -> list[dict[str, Any]]:
    unique = {}
    for observation in observations:
        for item in observation[field]:
            key = json.dumps(item, sort_keys=True)
            unique[key] = item
    return [unique[key] for key in sorted(unique)]


def _stable_id(*parts: Any) -> str:
    return hashlib.sha256(json.dumps(parts, sort_keys=True).encode()).hexdigest()
