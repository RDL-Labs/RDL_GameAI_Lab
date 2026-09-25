"""Finite C4 transition from normal operation into the M_delta phase."""

from copy import deepcopy
import hashlib
import json
from typing import Any


TRANSITION_ID = "gameai-m-delta-transition-v1"


class MDeltaTransitionError(ValueError):
    pass


class FiniteMDeltaStateMachine:
    """Retain one state per frozen model; only T1 may later resolve M_delta."""

    def __init__(self, capacity: int = 128) -> None:
        if type(capacity) is not int or capacity <= 0:
            raise MDeltaTransitionError("capacity must be a positive integer")
        self.capacity = capacity
        self._states: dict[str, dict[str, Any]] = {}
        self.capacity_rejections = 0

    def accept(self, evaluation: dict[str, Any]) -> dict[str, Any] | None:
        if not isinstance(evaluation, dict) or evaluation.get("status") != "evaluated":
            return None
        model_ref = evaluation.get("model_ref")
        assessment_id = evaluation.get("assessment_id")
        comparison = evaluation.get("comparison")
        if not isinstance(model_ref, str) or not model_ref:
            raise MDeltaTransitionError("evaluated boundary requires model_ref")
        if not isinstance(assessment_id, str) or not assessment_id:
            raise MDeltaTransitionError("evaluated boundary requires assessment_id")
        if comparison not in ("maintain", "rupture_boundary_met"):
            raise MDeltaTransitionError("unknown boundary comparison")

        current = self._states.get(model_ref)
        if current and current["phase"] == "M_delta":
            return deepcopy(current)
        if current is None and len(self._states) >= self.capacity:
            self.capacity_rejections += 1
            return None

        common = {
            "model_ref": model_ref,
            "latest_assessment_id": assessment_id,
            "latest_review_revision": evaluation["review_revision"],
            "H": evaluation["H"],
            "H_vec": deepcopy(evaluation.get("H_vec", {})),
            "theta_eff": evaluation["theta_eff"],
            "comparison": comparison,
        }
        if comparison == "maintain":
            state = {
                **common,
                "phase": "normal",
                "transition": None,
                "authority": "canonical-maintenance-state; not-M_delta-T1-M_B-prime-or-action",
            }
        else:
            identity = [model_ref, assessment_id, evaluation["review_revision"],
                        evaluation["theta_revision"]]
            state = {
                **common,
                "phase": "M_delta",
                "transition": {
                    "transition_id": hashlib.sha256(json.dumps(identity).encode()).hexdigest(),
                    "transition_rule": "H >= theta_eff",
                    "evaluator": evaluation["evaluation"]["evaluator"],
                    "theta_revision": evaluation["theta_revision"],
                },
                "authority": "canonical-M_delta-entry; not-T1-selection-reconstruction-M_B-prime-or-action",
            }
        self._states[model_ref] = state
        return deepcopy(state)

    def snapshot(self) -> dict[str, Any]:
        states = [deepcopy(state) for state in self._states.values()]
        return {
            "transition_model": TRANSITION_ID,
            "states": states,
            "count": len(states),
            "active_count": sum(state["phase"] == "M_delta" for state in states),
            "capacity": self.capacity,
            "capacity_rejections": self.capacity_rejections,
            "retention": "M_delta remains active until future explicit T1 resolution",
            "authority": "finite-canonical-phase-transition",
            "downstream_separation": ["T1_material_expansion", "selection", "reconstruction",
                                      "M_B_prime", "re_entry", "action_authority"],
        }

    def resolve_reentry(self, *, parent_model_ref: str, new_model_ref: str,
                        artifact_id: str, cutover_id: str) -> dict[str, Any]:
        current = self._states.get(parent_model_ref)
        if current is None or current.get("phase") != "M_delta":
            raise MDeltaTransitionError("re-entry requires active parent M_delta")
        if not all(isinstance(value, str) and value for value in
                   (new_model_ref, artifact_id, cutover_id)):
            raise MDeltaTransitionError("re-entry provenance must be complete")
        updated = deepcopy(current)
        updated.update({
            "phase": "REENTERED",
            "resolution": {
                "new_model_ref": new_model_ref,
                "artifact_id": artifact_id,
                "cutover_id": cutover_id,
                "rule": "explicit inactive artifact activation after T1-C",
            },
            "authority": "resolved-M_delta-reentry-record; not-action-authority",
        })
        self._states[parent_model_ref] = updated
        return deepcopy(updated)
