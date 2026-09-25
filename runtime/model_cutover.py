"""Finite DMB-B authority cutover records for reconstructed models."""

from copy import deepcopy
import hashlib
import json
from typing import Any


CUTOVER_ID = "gameai-model-cutover-v1"


class ModelCutoverError(ValueError):
    pass


class ModelCutoverLedger:
    def __init__(self, capacity: int = 128) -> None:
        if type(capacity) is not int or capacity <= 0:
            raise ModelCutoverError("capacity must be a positive integer")
        self.capacity = capacity
        self._records: dict[str, dict[str, Any]] = {}
        self.capacity_rejections = 0

    def admit(self, *, artifact: dict[str, Any], parent_model_ref: str,
              transition_id: str, expected_active_model_ref: str,
              operator: str, basis: str, evidence: str) -> dict[str, Any] | None:
        if artifact.get("status") != "RECONSTRUCTED_INACTIVE":
            raise ModelCutoverError("cutover requires an inactive reconstructed artifact")
        if artifact.get("parent_model_ref") != parent_model_ref:
            raise ModelCutoverError("artifact parent differs from active model")
        if expected_active_model_ref != parent_model_ref:
            raise ModelCutoverError("expected active model does not match registry")
        for name, value in (("transition_id", transition_id), ("operator", operator),
                            ("basis", basis), ("evidence", evidence)):
            if not isinstance(value, str) or not value.strip():
                raise ModelCutoverError(f"{name} must be non-empty")
        artifact_id = artifact.get("artifact_id")
        new_model_ref = artifact.get("model_ref")
        if not isinstance(artifact_id, str) or not isinstance(new_model_ref, str):
            raise ModelCutoverError("artifact identity is incomplete")
        identity = [CUTOVER_ID, artifact_id, parent_model_ref, transition_id]
        cutover_id = hashlib.sha256(json.dumps(identity).encode()).hexdigest()
        record = {
            "cutover_id": cutover_id,
            "schema_version": CUTOVER_ID,
            "artifact_id": artifact_id,
            "agent_id": artifact["agent_id"],
            "parent_model_ref": parent_model_ref,
            "new_model_ref": new_model_ref,
            "transition_id": transition_id,
            "operator": operator,
            "basis": basis,
            "evidence": evidence,
            "status": "CUTOVER_ACCEPTED",
            "authority": "canonical-model-registry-cutover; not-game-action-authority",
        }
        existing = self._records.get(artifact_id)
        if existing is not None:
            if existing != record:
                raise ModelCutoverError("artifact cutover replay changed provenance")
            return deepcopy(existing)
        if len(self._records) >= self.capacity:
            self.capacity_rejections += 1
            return None
        self._records[artifact_id] = record
        return deepcopy(record)

    def snapshot(self) -> dict[str, Any]:
        return {
            "cutover_model": CUTOVER_ID,
            "records": deepcopy(list(self._records.values())),
            "count": len(self._records),
            "capacity": self.capacity,
            "capacity_rejections": self.capacity_rejections,
            "authority": "read-only-model-cutover-ledger; not-game-action-authority",
        }

    def record_for_artifact(self, artifact_id: str) -> dict[str, Any] | None:
        record = self._records.get(artifact_id)
        return deepcopy(record) if record is not None else None
