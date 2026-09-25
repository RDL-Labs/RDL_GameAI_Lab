"""OGB-7/8 Deep Similarity for Local Bias Sleep Profiles."""

from copy import deepcopy
from itertools import combinations
import hashlib
import json
from typing import Any


EVALUATOR_ID = "local-bias-deep-similarity-v1"


class LocalBiasDeepSimilarityError(ValueError):
    pass


def build_local_bias_deep_shadow(profile_set: dict[str, Any], *, sleep_cycle: str,
                                 formation_tick: int) -> dict[str, Any]:
    agent_id, profiles = _validate(profile_set, sleep_cycle, formation_tick)
    observations = [_compare(left, right) for left, right in combinations(profiles, 2)]
    common = _common_relations(profiles)
    candidate = None
    status = "NO_CANDIDATE"
    if common:
        source_experience_ids = [item["source_experience_id"] for item in profiles]
        source_bias_ids = sorted({bias_id for item in profiles for bias_id in item["source_bias_ids"]})
        source_world_event_ids = sorted({
            event_id for profile in profiles for relation in profile["relations"]
            for event_id in relation["source_world_event_ids"]
        })
        candidate = {
            "candidate_id": _stable("candidate", agent_id, sleep_cycle, common,
                                    source_experience_ids),
            "schema": EVALUATOR_ID,
            "agent_id": agent_id,
            "sleep_cycle": sleep_cycle,
            "formation_tick": formation_tick,
            "profile_ids": [item["profile_id"] for item in profiles],
            "source_experience_ids": source_experience_ids,
            "source_bias_ids": source_bias_ids,
            "source_world_event_ids": source_world_event_ids,
            "common_bias_relations": common,
            "support_count": len(profiles),
            "authority": "GameAI-local-shadow-candidate; not-truth-T1-M_B-H-or-action",
        }
        status = "CANDIDATE_FORMED"
    return {
        "deep_similarity_id": _stable(
            EVALUATOR_ID, profile_set["profile_set_id"], sleep_cycle, formation_tick
        ),
        "schema": EVALUATOR_ID,
        "status": status,
        "agent_id": agent_id,
        "sleep_cycle": sleep_cycle,
        "formation_tick": formation_tick,
        "profile_set_id": profile_set["profile_set_id"],
        "similarity_observations": observations,
        "candidate": candidate,
        "authority": "GameAI-local-Deep-shadow; not-E-H-theta-M_delta-T1-M_B-or-action",
    }


def _compare(left: dict[str, Any], right: dict[str, Any]) -> dict[str, Any]:
    left_relations = _by_relation(left)
    right_relations = _by_relation(right)
    names = sorted(set(left_relations) | set(right_relations))
    matched, different, conflicts = [], [], []
    for name in names:
        left_item, right_item = left_relations.get(name), right_relations.get(name)
        if left_item is None or right_item is None:
            different.append({"relation": name, "left": _signature(left_item),
                              "right": _signature(right_item)})
            continue
        left_signature, right_signature = _signature(left_item), _signature(right_item)
        if left_signature == right_signature:
            matched.append(left_signature)
        else:
            difference = {"relation": name, "left": left_signature, "right": right_signature}
            different.append(difference)
            if left_item["direction"] != right_item["direction"]:
                conflicts.append(difference)
    return {
        "similarity_observation_id": _stable(
            "observation", sorted((left["profile_id"], right["profile_id"])),
            matched, different, conflicts,
        ),
        "profile_ids": sorted((left["profile_id"], right["profile_id"])),
        "matched_relations": matched,
        "different_relations": different,
        "conflicts": conflicts,
        "authority": "similarity-observation-only; not-candidate-truth-E-H-or-action",
    }


def _common_relations(profiles: list[dict[str, Any]]) -> list[dict[str, Any]]:
    common = None
    for profile in profiles:
        signatures = {json.dumps(_signature(item), sort_keys=True)
                      for item in profile["relations"]}
        common = signatures if common is None else common & signatures
    return [json.loads(item) for item in sorted(common or set())]


def _by_relation(profile: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {item["relation"]: item for item in profile["relations"]}


def _signature(item: dict[str, Any] | None) -> dict[str, Any] | None:
    if item is None:
        return None
    return {
        "relation": item["relation"], "direction": item["direction"],
        "strength": item["strength"], "magnitude": item["magnitude"],
        "context_signature": deepcopy(item["context_signature"]),
    }


def _validate(profile_set: dict[str, Any], sleep_cycle: str,
              formation_tick: int) -> tuple[str, list[dict[str, Any]]]:
    if not isinstance(profile_set, dict) or profile_set.get("schema") != "local-bias-relation-profile-v1":
        raise LocalBiasDeepSimilarityError("unsupported Local Bias Profile set")
    agent_id = profile_set.get("agent_id")
    profiles = profile_set.get("profiles")
    if not isinstance(agent_id, str) or not agent_id:
        raise LocalBiasDeepSimilarityError("Profile agent_id must be non-empty")
    if not isinstance(profiles, list) or not 3 <= len(profiles) <= 6:
        raise LocalBiasDeepSimilarityError("Deep comparison requires three to six Profiles")
    if any(item.get("agent_id") != agent_id for item in profiles):
        raise LocalBiasDeepSimilarityError("Profile belongs to a different agent")
    ids = [item.get("profile_id") for item in profiles]
    sources = [item.get("source_experience_id") for item in profiles]
    if len(ids) != len(set(ids)) or len(sources) != len(set(sources)):
        raise LocalBiasDeepSimilarityError("Deep comparison requires distinct Profile sources")
    if not isinstance(sleep_cycle, str) or not sleep_cycle:
        raise LocalBiasDeepSimilarityError("sleep_cycle must be non-empty")
    if type(formation_tick) is not int or formation_tick < 0:
        raise LocalBiasDeepSimilarityError("formation_tick must be non-negative")
    return agent_id, deepcopy(profiles)


def _stable(*parts: Any) -> str:
    return hashlib.sha256(json.dumps(parts, sort_keys=True).encode()).hexdigest()
