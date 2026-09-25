"""Finite T1-B explicit inspection and disposition of T1-A materials."""

from copy import deepcopy
import hashlib
import json
from typing import Any


SELECTION_ID = "gameai-t1-material-selection-v1"
DISPOSITIONS = {"RETAIN", "REJECT", "DEFER"}


class T1MaterialSelectionError(ValueError):
    pass


class T1MaterialSelectionLedger:
    """Require explicit complete review; never infer a disposition."""

    def __init__(self, capacity: int = 128) -> None:
        if type(capacity) is not int or capacity <= 0:
            raise T1MaterialSelectionError("capacity must be a positive integer")
        self.capacity = capacity
        self._records: dict[str, dict[str, Any]] = {}
        self.capacity_rejections = 0

    def inspect(self, bundle: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any] | None:
        bundle_id, materials = _validate_bundle(bundle)
        if not isinstance(payload, dict):
            raise T1MaterialSelectionError("selection review must be an object")
        current = self._records.get(bundle_id)
        expected_revision = payload.get("expected_revision")
        actual_revision = current["revision"] if current else 0
        if type(expected_revision) is not int or expected_revision != actual_revision:
            raise T1MaterialSelectionError("expected_revision must match selection revision")
        reviewer = payload.get("reviewer")
        if not isinstance(reviewer, str) or not reviewer.strip():
            raise T1MaterialSelectionError("reviewer must be non-empty")
        supplied = payload.get("materials")
        if not isinstance(supplied, list):
            raise T1MaterialSelectionError("materials must be a list")
        material_by_id = {item["material_id"]: item for item in materials}
        decisions = {}
        for item in supplied:
            if not isinstance(item, dict):
                raise T1MaterialSelectionError("material decision must be an object")
            material_id = item.get("material_id")
            if material_id not in material_by_id or material_id in decisions:
                raise T1MaterialSelectionError("material decision identity is unknown or duplicated")
            disposition = item.get("disposition")
            if disposition not in DISPOSITIONS:
                raise T1MaterialSelectionError("unsupported material disposition")
            for field in ("basis", "evidence"):
                if not isinstance(item.get(field), str) or not item[field].strip():
                    raise T1MaterialSelectionError(f"material {field} must be non-empty")
            decisions[material_id] = {
                "material_id": material_id,
                "kind": material_by_id[material_id]["kind"],
                "source_id": material_by_id[material_id]["source_id"],
                "disposition": disposition,
                "basis": item["basis"],
                "evidence": item["evidence"],
            }
        if set(decisions) != set(material_by_id):
            raise T1MaterialSelectionError("selection must cover every bundle material exactly once")
        if current is None and len(self._records) >= self.capacity:
            self.capacity_rejections += 1
            return None
        ordered = [decisions[item["material_id"]] for item in materials]
        revision = actual_revision + 1
        record = {
            "selection_id": hashlib.sha256(
                json.dumps([SELECTION_ID, bundle_id], sort_keys=True).encode()
            ).hexdigest(),
            "bundle_id": bundle_id,
            "agent_id": bundle["agent_id"],
            "model_ref": bundle["model_ref"],
            "transition_id": bundle["transition_id"],
            "revision": revision,
            "reviewer": reviewer,
            "materials": ordered,
            "counts": {
                disposition: sum(item["disposition"] == disposition for item in ordered)
                for disposition in ("RETAIN", "REJECT", "DEFER")
            },
            "status": "INSPECTED",
            "authority": "T1-selection-record-only; RETAIN-not-adoption; not-reconstruction-M_B-prime-re-entry-or-action",
        }
        self._records[bundle_id] = record
        return deepcopy(record)

    def snapshot(self) -> dict[str, Any]:
        return {
            "selector": SELECTION_ID,
            "records": deepcopy(list(self._records.values())),
            "count": len(self._records),
            "capacity": self.capacity,
            "capacity_rejections": self.capacity_rejections,
            "authority": "read-only-T1-material-selection",
            "not_implemented": ["adoption", "reconstruction", "M_B_prime", "re_entry",
                                "action_authority"],
        }

    def record(self, bundle_id: str) -> dict[str, Any]:
        if not isinstance(bundle_id, str) or bundle_id not in self._records:
            raise T1MaterialSelectionError("unknown T1 selection record")
        return deepcopy(self._records[bundle_id])


def _validate_bundle(bundle: dict[str, Any]) -> tuple[str, list[dict[str, Any]]]:
    if not isinstance(bundle, dict) or bundle.get("status") != "EXPANDED_FOR_INSPECTION":
        raise T1MaterialSelectionError("selection requires an expanded T1-A bundle")
    bundle_id = bundle.get("bundle_id")
    materials = bundle.get("materials")
    if not isinstance(bundle_id, str) or not bundle_id:
        raise T1MaterialSelectionError("bundle_id must be non-empty")
    if not isinstance(materials, list) or not materials:
        raise T1MaterialSelectionError("bundle materials must be non-empty")
    identities = [item.get("material_id") for item in materials if isinstance(item, dict)]
    if len(identities) != len(materials) or len(set(identities)) != len(materials):
        raise T1MaterialSelectionError("bundle material identities must be finite and unique")
    return bundle_id, materials
