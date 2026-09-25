"""Pure OGB-6 Local Bias to Sleep relation-profile projection."""

from copy import deepcopy
import hashlib
import json
from typing import Any


COMPILER_ID = "local-bias-relation-profile-v1"
MAX_BIASES = 32
RELATIONS = {"acquisition", "return", "injury", "reward_value"}
DIRECTIONS = {"positive", "negative"}
STRENGTHS = {"WEAK", "MEDIUM", "STRONG"}


class LocalBiasProfileError(ValueError):
    pass


def build_local_bias_profiles(projection: dict[str, Any]) -> dict[str, Any]:
    """Compile same-agent Local Bias materials without forming a candidate."""

    agent_id, materials = _validate_projection(projection)
    grouped: dict[str, list[dict[str, Any]]] = {}
    for material in materials:
        _validate_material(material, agent_id)
        grouped.setdefault(material["source_experience_id"], []).append(material)

    profiles = []
    for experience_id in sorted(grouped):
        sources = sorted(grouped[experience_id], key=lambda item: item["relation"])
        relations = [{
            "bias_id": item["bias_id"],
            "source_gradient_id": item["source_gradient_id"],
            "source_experience_id": item["source_experience_id"],
            "source_world_event_ids": deepcopy(item["source_world_event_ids"]),
            "context_signature": deepcopy(item["context_signature"]),
            "relation": item["relation"],
            "direction": item["direction"],
            "strength": item["strength"],
            "magnitude": item["magnitude"],
            "status": "reported_local_bias",
        } for item in sources]
        profile_id = _stable_id(COMPILER_ID, agent_id, experience_id, relations)
        profiles.append({
            "profile_id": profile_id,
            "schema": COMPILER_ID,
            "agent_id": agent_id,
            "source_experience_id": experience_id,
            "source_bias_ids": [item["bias_id"] for item in sources],
            "relations": relations,
            "authority": "derived-Sleep-comparison-material; not-candidate-T1-M_B-or-action",
        })

    return {
        "profile_set_id": _stable_id(
            COMPILER_ID, agent_id, [item["profile_id"] for item in profiles]
        ),
        "schema": COMPILER_ID,
        "agent_id": agent_id,
        "source_bias_ids": sorted(item["bias_id"] for item in materials),
        "source_experience_ids": sorted(grouped),
        "profiles": profiles,
        "profile_count": len(profiles),
        "compiler": COMPILER_ID,
        "authority": "Sleep-profile-material-only; not-similarity-cluster-candidate-T1-M_B-or-action",
    }


def _validate_projection(projection: dict[str, Any]) -> tuple[str, list[dict[str, Any]]]:
    if not isinstance(projection, dict):
        raise LocalBiasProfileError("Sleep projection must be an object")
    agent_id = projection.get("agent_id")
    if not isinstance(agent_id, str) or not agent_id:
        raise LocalBiasProfileError("Sleep projection agent_id must be non-empty")
    if "Sleep-input-material-only" not in str(projection.get("authority", "")):
        raise LocalBiasProfileError("unsupported Local Bias Sleep projection")
    materials = projection.get("local_bias_materials")
    if not isinstance(materials, list) or len(materials) > MAX_BIASES:
        raise LocalBiasProfileError("Local Bias materials exceed the finite profile limit")
    ids = [item.get("bias_id") if isinstance(item, dict) else None for item in materials]
    if any(not isinstance(item, str) or not item for item in ids) or len(ids) != len(set(ids)):
        raise LocalBiasProfileError("Local Bias identities must be unique and non-empty")
    return agent_id, deepcopy(materials)


def _validate_material(material: dict[str, Any], agent_id: str) -> None:
    if material.get("schema") != "risky-food-local-bias-v1":
        raise LocalBiasProfileError("unsupported Local Bias schema")
    if material.get("agent_id") != agent_id:
        raise LocalBiasProfileError("Local Bias belongs to a different agent")
    for field in ("source_gradient_id", "source_experience_id"):
        if not isinstance(material.get(field), str) or not material[field]:
            raise LocalBiasProfileError(f"Local Bias {field} must be non-empty")
    if material.get("relation") not in RELATIONS:
        raise LocalBiasProfileError("unsupported Local Bias relation")
    if material.get("direction") not in DIRECTIONS:
        raise LocalBiasProfileError("unsupported Local Bias direction")
    if material.get("strength") not in STRENGTHS:
        raise LocalBiasProfileError("unsupported Local Bias strength")
    expected = {"WEAK": 1, "MEDIUM": 2, "STRONG": 3}[material["strength"]]
    if material.get("magnitude") != expected:
        raise LocalBiasProfileError("Local Bias strength differs from magnitude")
    if not isinstance(material.get("context_signature"), dict):
        raise LocalBiasProfileError("Local Bias context signature must be an object")
    event_ids = material.get("source_world_event_ids")
    if not isinstance(event_ids, list) or not event_ids or any(
        not isinstance(item, str) or not item for item in event_ids
    ):
        raise LocalBiasProfileError("Local Bias World event provenance is incomplete")


def _stable_id(*parts: Any) -> str:
    return hashlib.sha256(json.dumps(parts, sort_keys=True).encode()).hexdigest()
