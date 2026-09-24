"""I2 pure bounded Activity Fast Retrieval."""

from copy import deepcopy
import hashlib
import json
from typing import Any

from ..structural.similarity import relation_signature


FAST_RETRIEVAL_ID = "activity-fast-retrieval-v1"
MAX_SOURCES = 32
MAX_TOP_K = 3


class FastRetrievalError(ValueError):
    pass


def build_fast_retrieval(current_profile: dict[str, Any], sources: list[dict[str, Any]],
                         *, query_tick: int, top_k: int = MAX_TOP_K) -> dict[str, Any]:
    """Run L0 semantic identity overlap and L1 finite comparison."""
    if type(query_tick) is not int or query_tick < 0:
        raise FastRetrievalError("query_tick must be a non-negative integer")
    if type(top_k) is not int or not 1 <= top_k <= MAX_TOP_K:
        raise FastRetrievalError("top_k must be between one and three")
    current_id, current_signatures = _profile_signatures(current_profile)
    if not isinstance(sources, list) or len(sources) > MAX_SOURCES:
        raise FastRetrievalError("Fast source catalog must contain at most 32 entries")

    ranked = []
    seen = set()
    for source in sources:
        source_type, source_id, signatures, provenance = _source_signatures(source)
        key = (source_type, source_id)
        if key in seen:
            raise FastRetrievalError("duplicate Fast source identity")
        seen.add(key)
        if source_type == "raw_experience" and source_id == current_profile.get("source_experience_id"):
            continue
        shared = _shared(current_signatures, signatures)
        if not shared:
            continue
        union_count = len({_key(item) for item in current_signatures + signatures})
        l0 = {
            "shared_relation_count": len(shared),
            "current_relation_count": len(current_signatures),
            "source_relation_count": len(signatures),
            "jaccard": len(shared) / union_count,
            "shared_relation_signatures": shared,
        }
        l1 = _l1(current_signatures, signatures)
        ranked.append({
            "source_type": source_type,
            "source_id": source_id,
            "source_provenance": provenance,
            "l0": l0,
            "l1": l1,
            "authority": "retrieval-result-only; not-candidate-commitment-action-E-H-M_B-or-T1",
        })

    ranked.sort(key=lambda item: (
        -item["l0"]["shared_relation_count"],
        -item["l0"]["jaccard"],
        item["source_type"], item["source_id"],
    ))
    selected = _source_aware_top_k(ranked, top_k)
    query_id = hashlib.sha256(json.dumps([
        FAST_RETRIEVAL_ID, current_id, query_tick, top_k,
        [(item["source_type"], item["source_id"]) for item in selected],
    ], sort_keys=True).encode()).hexdigest()
    return {
        "query_id": query_id,
        "status": "MATCHES_FOUND" if selected else "NO_MATCH",
        "query_tick": query_tick,
        "current_profile_id": current_id,
        "current_source_experience_id": current_profile["source_experience_id"],
        "catalog_size": len(sources),
        "eligible_count": len(ranked),
        "top_k": top_k,
        "selection_policy": "best-per-source-type-then-global-rank-v1",
        "results": selected,
        "evaluator": FAST_RETRIEVAL_ID,
        "authority": "GameAI-local-read-only-retrieval; not-candidate-generation-action-E-H-M_B-or-T1",
    }


def _profile_signatures(profile: dict[str, Any]) -> tuple[str, list[dict[str, str]]]:
    if not isinstance(profile, dict):
        raise FastRetrievalError("current Profile must be an object")
    profile_id = profile.get("profile_id")
    source_id = profile.get("source_experience_id")
    relations = profile.get("relations")
    if not isinstance(profile_id, str) or not profile_id:
        raise FastRetrievalError("Profile ID must be non-empty")
    if not isinstance(source_id, str) or not source_id:
        raise FastRetrievalError("Profile source Experience must be non-empty")
    if not isinstance(relations, list) or not relations:
        raise FastRetrievalError("Profile relations must be a non-empty list")
    return profile_id, [relation_signature(item) for item in relations]


def _source_signatures(source: dict[str, Any]) -> tuple[str, str, list, dict]:
    if not isinstance(source, dict):
        raise FastRetrievalError("Fast source must be an object")
    source_type = source.get("source_type")
    source_id = source.get("source_id")
    if source_type not in {"raw_experience", "sleep_candidate"}:
        raise FastRetrievalError("unsupported Fast source type")
    if not isinstance(source_id, str) or not source_id:
        raise FastRetrievalError("Fast source ID must be non-empty")
    if source_type == "raw_experience":
        profile = source.get("profile")
        _, signatures = _profile_signatures(profile)
        if profile["source_experience_id"] != source_id:
            raise FastRetrievalError("raw source identity differs from Profile provenance")
        provenance = {"source_experience_ids": [source_id]}
    else:
        candidate = source.get("candidate")
        if not isinstance(candidate, dict) or candidate.get("candidate_id") != source_id:
            raise FastRetrievalError("sleep candidate identity is incomplete")
        signatures = [relation_signature(candidate.get("common_relation_signature"))]
        provenance = {
            "candidate_id": source_id,
            "sleep_cycle": candidate.get("sleep_cycle"),
            "source_experience_ids": deepcopy(candidate.get("source_experience_ids")),
        }
        if not isinstance(provenance["source_experience_ids"], list) or not provenance["source_experience_ids"]:
            raise FastRetrievalError("sleep candidate provenance is incomplete")
    return source_type, source_id, signatures, provenance


def _shared(left: list[dict[str, str]], right: list[dict[str, str]]) -> list[dict[str, str]]:
    right_keys = {_key(item) for item in right}
    return [deepcopy(item) for item in left if _key(item) in right_keys]


def _l1(current: list[dict[str, str]], source: list[dict[str, str]]) -> dict[str, Any]:
    shared = _shared(current, source)
    unresolved = [deepcopy(item) for item in current + source if item["polarity"] == "unresolved"]
    conflict = []
    for left in current:
        for right in source:
            same_relation = all(left[field] == right[field] for field in (
                "kind", "predicate", "object", "status"
            ))
            if same_relation and {left["polarity"], right["polarity"]} == {"supportive", "adverse"}:
                conflict.append({"current": deepcopy(left), "source": deepcopy(right)})
    return {
        "score": {"matched": len(shared), "compared": min(len(current), len(source)),
                  "ratio": len(shared) / min(len(current), len(source))},
        "coverage": {"status": "complete" if len(current) == len(source) else "partial",
                     "current": len(current), "source": len(source)},
        "conflict": conflict,
        "unresolved": unresolved,
        "matched_relation_signatures": shared,
        "evaluator": FAST_RETRIEVAL_ID,
    }


def _key(signature: dict[str, str]) -> str:
    return json.dumps(signature, sort_keys=True, separators=(",", ":"))


def _source_aware_top_k(ranked: list[dict[str, Any]], top_k: int) -> list[dict[str, Any]]:
    if top_k == 1:
        return ranked[:1]
    selected = []
    selected_ids = set()
    for source_type in ("raw_experience", "sleep_candidate"):
        match = next((item for item in ranked if item["source_type"] == source_type), None)
        if match is not None:
            selected.append(match)
            selected_ids.add((match["source_type"], match["source_id"]))
    for item in ranked:
        key = (item["source_type"], item["source_id"])
        if len(selected) >= top_k:
            break
        if key not in selected_ids:
            selected.append(item)
            selected_ids.add(key)
    rank = {(item["source_type"], item["source_id"]): index for index, item in enumerate(ranked)}
    return sorted(selected, key=lambda item: rank[(item["source_type"], item["source_id"])])
