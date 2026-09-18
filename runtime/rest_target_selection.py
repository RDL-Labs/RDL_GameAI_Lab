"""Finite Rest candidate comparison without trajectory or rho authority."""

from copy import deepcopy

from .core import ObservationError


POLICY_ID = "rest-target-selection-v1"
SAFETY_RANK = {"unknown": 0, "uncertain": 1, "safe": 2}
DISTANCE_RANK = {"unreachable": 0, "far": 1, "near": 2, "within_reach": 3}


class RestTargetSelectionPolicy:
    """Select once from finite bounded candidate descriptions."""

    def select(self, places):
        candidates = []
        for place in places:
            if place.get("rest_capable") is not True:
                continue
            safety = place.get("rest_safety", "unknown")
            distance_band = place.get("rest_distance_band")
            if safety not in SAFETY_RANK:
                raise ObservationError("unsupported Rest safety distinction")
            if distance_band not in DISTANCE_RANK:
                raise ObservationError("unsupported Rest distance band")
            if distance_band == "unreachable":
                continue
            candidates.append({
                "target_id": place["id"],
                "safety": safety,
                "distance_band": distance_band,
            })
        if not candidates:
            return {}
        selected = max(
            candidates,
            key=lambda item: (
                SAFETY_RANK[item["safety"]],
                DISTANCE_RANK[item["distance_band"]],
                item["target_id"],
            ),
        )
        return {
            "policy": POLICY_ID,
            "authority": "GameAI-local-candidate-comparison; not-rho-M_B-or-action-authority",
            "rule": "safe>uncertain>unknown; same-safety within_reach>near>far",
            "selected": deepcopy(selected),
            "candidates": deepcopy(candidates),
        }
