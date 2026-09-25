"""Finite C3 evaluation of an effective retention boundary."""

from copy import deepcopy
import math
from typing import Any


EVALUATOR_ID = "gameai-theta-effective-evaluator-v1"


class ThetaEffectiveError(ValueError):
    pass


class FiniteThetaEffectiveEvaluator:
    """Evaluate theta_eff from explicit finite relation conditions only."""

    def __init__(self, base_theta: float = 1.0,
                 relation_adjustments: list[dict[str, Any]] | None = None) -> None:
        if type(base_theta) not in (int, float) or not math.isfinite(base_theta) or base_theta <= 0:
            raise ThetaEffectiveError("base_theta must be finite and positive")
        adjustments = relation_adjustments or []
        if not isinstance(adjustments, list):
            raise ThetaEffectiveError("relation_adjustments must be a list")
        accepted = []
        for item in adjustments:
            if not isinstance(item, dict):
                raise ThetaEffectiveError("each relation adjustment must be an object")
            relation_id = item.get("relation_id")
            source = item.get("source")
            delta = item.get("delta")
            if not isinstance(relation_id, str) or not relation_id:
                raise ThetaEffectiveError("relation_id must be non-empty")
            if not isinstance(source, str) or not source:
                raise ThetaEffectiveError("relation source must be non-empty")
            if type(delta) not in (int, float) or not math.isfinite(delta):
                raise ThetaEffectiveError("relation delta must be finite")
            accepted.append({"relation_id": relation_id, "source": source, "delta": float(delta)})
        theta = math.fsum([float(base_theta)] + [item["delta"] for item in accepted])
        if not math.isfinite(theta) or theta <= 0:
            raise ThetaEffectiveError("evaluated theta_eff must be finite and positive")
        self._base_theta = float(base_theta)
        self._adjustments = tuple(accepted)

    def evaluate(self, review_path: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(review_path, dict):
            raise ThetaEffectiveError("review_path must be an object")
        review = review_path.get("review")
        if not isinstance(review, dict):
            raise ThetaEffectiveError("review_path must contain review provenance")
        theta_eff = math.fsum(
            [self._base_theta] + [item["delta"] for item in self._adjustments]
        )
        result = {
            "assessment_id": review_path.get("assessment_id"),
            "model_ref": review_path.get("model_ref"),
            "review_revision": review.get("revision"),
            "theta_eff": theta_eff,
            "theta_revision": 0,
            "evaluation": {
                "evaluator": EVALUATOR_ID,
                "base_theta": self._base_theta,
                "relation_adjustments": deepcopy(list(self._adjustments)),
            },
            "authority": "canonical-diagnostic-boundary-comparison; not-M_delta-T1-M_B-prime-or-action",
        }
        if review.get("status") != "reviewed":
            result.update(status="pending_review", H=None, comparison=None)
            return result
        h_value = review_path.get("H")
        if type(h_value) not in (int, float) or not math.isfinite(h_value) or h_value < 0:
            raise ThetaEffectiveError("reviewed H must be finite and non-negative")
        result.update(
            status="evaluated",
            H=float(h_value),
            comparison="maintain" if h_value < theta_eff else "rupture_boundary_met",
        )
        return result


def build_theta_effective_snapshot(review_path_snapshot: dict[str, Any],
                                   evaluator: FiniteThetaEffectiveEvaluator) -> dict[str, Any]:
    paths = review_path_snapshot.get("paths") if isinstance(review_path_snapshot, dict) else None
    if not isinstance(paths, list):
        raise ThetaEffectiveError("review path snapshot must contain paths")
    evaluations = [evaluator.evaluate(path) for path in paths]
    return {
        "evaluator": EVALUATOR_ID,
        "evaluations": evaluations,
        "count": len(evaluations),
        "authority": "read-only-H-theta-effective-comparison",
        "not_implemented": ["M_delta_transition", "T1", "M_B_prime", "action_authority"],
    }
