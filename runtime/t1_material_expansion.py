"""Finite T1-A expansion of inspectable materials for an active M_delta."""

from copy import deepcopy
import hashlib
import json
from typing import Any


EXPANSION_ID = "gameai-t1-material-expansion-v1"
MAX_CANDIDATES = 16
MAX_EXPERIENCES = 32


class T1MaterialExpansionError(ValueError):
    pass


class T1MaterialExpansionStore:
    """Freeze source materials without selecting, adopting, or reconstructing."""

    def __init__(self, capacity: int = 128) -> None:
        if type(capacity) is not int or capacity <= 0:
            raise T1MaterialExpansionError("capacity must be a positive integer")
        self.capacity = capacity
        self._bundles: dict[str, tuple[str, dict[str, Any]]] = {}
        self.capacity_rejections = 0

    def expand(self, *, m_delta_state: dict[str, Any], model: dict[str, Any],
               review_path: dict[str, Any], candidates: list[dict[str, Any]] | None = None,
               experiences: list[dict[str, Any]] | None = None) -> dict[str, Any] | None:
        agent_id, transition_id = _validate_canonical_sources(
            m_delta_state, model, review_path
        )
        candidate_items = _validate_local_materials(
            candidates or [], agent_id, "candidate", MAX_CANDIDATES
        )
        experience_items = _validate_local_materials(
            experiences or [], agent_id, "experience", MAX_EXPERIENCES
        )
        identity = [EXPANSION_ID, transition_id]
        bundle_id = hashlib.sha256(json.dumps(identity).encode()).hexdigest()
        materials = [
            _material("current_M_B", model["model_ref"], model, "canonical_subject"),
            _material("RIB_B", review_path["RIB_B"]["section_id"],
                      review_path["RIB_B"], "canonical_history"),
            _material("RIB_B_prime", review_path["RIB_B_prime"]["section_id"],
                      review_path["RIB_B_prime"], "canonical_history"),
            _material("unresolved_residual", review_path["assessment_id"], {
                "H_vec": deepcopy(m_delta_state["H_vec"]),
                "H": m_delta_state["H"],
                "review_revision": m_delta_state["latest_review_revision"],
            }, "canonical_residual"),
        ]
        materials.extend(
            _material("CandidateRelation", item["candidate_id"], item, "local_candidate")
            for item in candidate_items
        )
        materials.extend(
            _material("Experience", _experience_id(item), item, "local_history")
            for item in experience_items
        )
        bundle = {
            "bundle_id": bundle_id,
            "schema_version": EXPANSION_ID,
            "agent_id": agent_id,
            "model_ref": model["model_ref"],
            "transition_id": transition_id,
            "assessment_id": review_path["assessment_id"],
            "materials": materials,
            "material_count": len(materials),
            "counts": {
                "canonical": 4,
                "candidates": len(candidate_items),
                "experiences": len(experience_items),
            },
            "status": "EXPANDED_FOR_INSPECTION",
            "authority": "T1-material-bundle-only; not-retain-reject-defer-selection-reconstruction-M_B-prime-or-action",
        }
        fingerprint = json.dumps(bundle, sort_keys=True)
        existing = self._bundles.get(bundle_id)
        if existing is not None:
            if existing[0] != fingerprint:
                raise T1MaterialExpansionError(
                    "T1 material replay changed frozen transition inputs"
                )
            return deepcopy(existing[1])
        if len(self._bundles) >= self.capacity:
            self.capacity_rejections += 1
            return None
        self._bundles[bundle_id] = (fingerprint, deepcopy(bundle))
        return deepcopy(bundle)

    def snapshot(self) -> dict[str, Any]:
        return {
            "expander": EXPANSION_ID,
            "bundles": deepcopy([item[1] for item in self._bundles.values()]),
            "count": len(self._bundles),
            "capacity": self.capacity,
            "capacity_rejections": self.capacity_rejections,
            "retention": "process lifetime; immutable bundles; no eviction",
            "authority": "read-only-T1-material-expansion",
            "not_implemented": ["retain", "reject", "defer", "Probe", "selection",
                                "reconstruction", "M_B_prime", "re_entry", "action_authority"],
        }


def _validate_canonical_sources(state: dict[str, Any], model: dict[str, Any],
                                path: dict[str, Any]) -> tuple[str, str]:
    if not all(isinstance(item, dict) for item in (state, model, path)):
        raise T1MaterialExpansionError("canonical material sources must be objects")
    if state.get("phase") != "M_delta" or not isinstance(state.get("transition"), dict):
        raise T1MaterialExpansionError("T1-A requires an active M_delta transition")
    model_ref = state.get("model_ref")
    if model.get("model_ref") != model_ref or path.get("model_ref") != model_ref:
        raise T1MaterialExpansionError("canonical material model_ref mismatch")
    if path.get("assessment_id") != state.get("latest_assessment_id"):
        raise T1MaterialExpansionError("review path differs from M_delta entry assessment")
    agent_id = model.get("agent_id")
    if not isinstance(agent_id, str) or not agent_id or path.get("agent_id") != agent_id:
        raise T1MaterialExpansionError("canonical material agent mismatch")
    transition_id = state["transition"].get("transition_id")
    if not isinstance(transition_id, str) or not transition_id:
        raise T1MaterialExpansionError("M_delta transition identity is incomplete")
    return agent_id, transition_id


def _validate_local_materials(items: list[dict[str, Any]], agent_id: str,
                              kind: str, limit: int) -> list[dict[str, Any]]:
    if not isinstance(items, list) or len(items) > limit:
        raise T1MaterialExpansionError(f"{kind} materials exceed finite limit")
    accepted = []
    seen = set()
    for item in items:
        if not isinstance(item, dict) or item.get("agent_id") != agent_id:
            raise T1MaterialExpansionError(f"{kind} material belongs to a different agent")
        if kind == "candidate":
            identity = item.get("candidate_id")
            if not isinstance(identity, str) or not identity:
                raise T1MaterialExpansionError("candidate_id must be non-empty")
        else:
            identity = _experience_id(item)
        if identity in seen:
            raise T1MaterialExpansionError(f"duplicate {kind} material identity")
        seen.add(identity)
        accepted.append(deepcopy(item))
    return accepted


def _experience_id(item: dict[str, Any]) -> str:
    identity = item.get("record_id")
    if not isinstance(identity, str) or not identity:
        raise T1MaterialExpansionError("Experience record_id must be non-empty")
    return identity


def _material(kind: str, source_id: str, payload: dict[str, Any], source_class: str) -> dict[str, Any]:
    return {
        "material_id": hashlib.sha256(
            json.dumps([kind, source_id], sort_keys=True).encode()
        ).hexdigest(),
        "kind": kind,
        "source_id": source_id,
        "source_class": source_class,
        "payload": deepcopy(payload),
        "disposition": "UNINSPECTED",
        "authority": "material-only; not-adopted-not-M_B-prime",
    }
