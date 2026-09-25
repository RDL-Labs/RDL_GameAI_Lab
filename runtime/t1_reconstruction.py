"""Finite T1-C construction of an inactive M_B prime artifact."""

from copy import deepcopy
import hashlib
import json
from typing import Any


RECONSTRUCTOR_ID = "gameai-t1-reconstruction-v1"


class T1ReconstructionError(ValueError):
    pass


class T1ReconstructionStore:
    """Create a new immutable model artifact without authority cutover."""

    def __init__(self, capacity: int = 128) -> None:
        if type(capacity) is not int or capacity <= 0:
            raise T1ReconstructionError("capacity must be a positive integer")
        self.capacity = capacity
        self._artifacts: dict[str, tuple[str, dict[str, Any]]] = {}
        self.capacity_rejections = 0

    def reconstruct(self, *, bundle: dict[str, Any], selection: dict[str, Any]) -> dict[str, Any] | None:
        old_model, retained_candidates, retained_sources = _validate_inputs(bundle, selection)
        identity = [
            RECONSTRUCTOR_ID, bundle["bundle_id"], selection["selection_id"],
            selection["revision"], [item["source_id"] for item in retained_candidates],
        ]
        artifact_id = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
        model_ref = f"gameai-reconstructed-mb:{artifact_id[:16]}:v1"
        adopted_relations = []
        material_by_id = {item["material_id"]: item for item in bundle["materials"]}
        for decision in retained_candidates:
            material = material_by_id[decision["material_id"]]
            candidate = material["payload"]
            signature = candidate.get("common_relation_signature")
            if not isinstance(signature, dict) or not signature:
                raise T1ReconstructionError("retained CandidateRelation lacks a finite signature")
            adopted_relations.append({
                "relation": deepcopy(signature),
                "source_candidate_id": candidate["candidate_id"],
                "source_material_id": material["material_id"],
                "selection_basis": decision["basis"],
                "selection_evidence": decision["evidence"],
                "status": "adopted-in-inactive-M_B-prime",
            })
        artifact = {
            "artifact_id": artifact_id,
            "schema_version": RECONSTRUCTOR_ID,
            "model_ref": model_ref,
            "parent_model_ref": old_model["model_ref"],
            "agent_id": old_model["agent_id"],
            "boundary": deepcopy(old_model["boundary"]),
            "coefficients": deepcopy(old_model["coefficients"]),
            "biases": deepcopy(old_model["biases"]),
            "xi_status": old_model["xi_status"],
            "adopted_relations": adopted_relations,
            "retained_materials": retained_sources,
            "source_bundle_id": bundle["bundle_id"],
            "source_selection_id": selection["selection_id"],
            "source_selection_revision": selection["revision"],
            "status": "RECONSTRUCTED_INACTIVE",
            "authority": "M_B-prime-artifact-only; not-active-not-reentry-not-action-authority",
        }
        fingerprint = json.dumps(artifact, sort_keys=True)
        existing = self._artifacts.get(artifact_id)
        if existing is not None:
            if existing[0] != fingerprint:
                raise T1ReconstructionError("reconstruction replay changed frozen inputs")
            return deepcopy(existing[1])
        if len(self._artifacts) >= self.capacity:
            self.capacity_rejections += 1
            return None
        self._artifacts[artifact_id] = (fingerprint, deepcopy(artifact))
        return deepcopy(artifact)

    def snapshot(self) -> dict[str, Any]:
        return {
            "reconstructor": RECONSTRUCTOR_ID,
            "artifacts": deepcopy([item[1] for item in self._artifacts.values()]),
            "count": len(self._artifacts),
            "capacity": self.capacity,
            "capacity_rejections": self.capacity_rejections,
            "authority": "read-only-T1-reconstruction-artifacts",
            "not_implemented": ["authority_cutover", "re_entry", "active_model_replacement",
                                "action_authority"],
        }


def _validate_inputs(bundle: dict[str, Any], selection: dict[str, Any]) -> tuple[dict, list, list]:
    if not isinstance(bundle, dict) or bundle.get("status") != "EXPANDED_FOR_INSPECTION":
        raise T1ReconstructionError("reconstruction requires a T1-A bundle")
    if not isinstance(selection, dict) or selection.get("status") != "INSPECTED":
        raise T1ReconstructionError("reconstruction requires a T1-B selection")
    if selection.get("bundle_id") != bundle.get("bundle_id"):
        raise T1ReconstructionError("selection belongs to a different bundle")
    materials = bundle.get("materials")
    decisions = selection.get("materials")
    if not isinstance(materials, list) or not isinstance(decisions, list):
        raise T1ReconstructionError("reconstruction sources must be finite lists")
    material_by_id = {item.get("material_id"): item for item in materials}
    decision_by_id = {item.get("material_id"): item for item in decisions}
    if set(material_by_id) != set(decision_by_id) or len(material_by_id) != len(materials):
        raise T1ReconstructionError("selection coverage differs from material bundle")
    current = [item for item in materials if item.get("kind") == "current_M_B"]
    if len(current) != 1:
        raise T1ReconstructionError("bundle must contain exactly one current M_B")
    if decision_by_id[current[0]["material_id"]].get("disposition") != "RETAIN":
        raise T1ReconstructionError("current M_B must be retained as reconstruction parent")
    retained_candidates = [decision for decision in decisions
                           if decision.get("kind") == "CandidateRelation"
                           and decision.get("disposition") == "RETAIN"]
    if not retained_candidates:
        raise T1ReconstructionError("reconstruction requires a retained CandidateRelation")
    retained_sources = [{
        "material_id": decision["material_id"],
        "kind": decision["kind"],
        "source_id": decision["source_id"],
        "disposition": decision["disposition"],
    } for decision in decisions if decision.get("disposition") == "RETAIN"]
    return deepcopy(current[0]["payload"]), retained_candidates, retained_sources
