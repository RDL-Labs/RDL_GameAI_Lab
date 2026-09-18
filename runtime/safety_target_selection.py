"""Finite Safety target selection without trajectory authority."""

from copy import deepcopy

POLICY_ID = "safety-target-selection-v1"
SAFETY_RANK = {"uncertain": 1, "safe": 2}
DISTANCE_RANK = {"far": 1, "near": 2, "within_reach": 3}


class SafetySelectionError(ValueError):
    pass


class SafetyTargetSelectionPolicy:
    def select(self, candidates):
        if not isinstance(candidates, list):
            raise SafetySelectionError("Safety candidates must be a list")
        ranked = []
        seen = set()
        for candidate in candidates:
            if not isinstance(candidate, dict):
                raise SafetySelectionError("Safety candidate must be an object")
            target_id = candidate.get("target_id")
            safety = candidate.get("safety")
            distance = candidate.get("distance_band")
            if not isinstance(target_id, str) or not target_id or target_id in seen:
                raise SafetySelectionError("Safety candidate IDs must be finite and unique")
            if safety not in SAFETY_RANK or distance not in DISTANCE_RANK:
                raise SafetySelectionError("unsupported Safety candidate distinction")
            seen.add(target_id)
            ranked.append((SAFETY_RANK[safety], DISTANCE_RANK[distance], target_id, candidate))
        if not ranked:
            return {"policy": POLICY_ID, "selected": None, "candidates": []}
        ranked.sort(key=lambda item: (-item[0], -item[1], item[2]))
        selected = ranked[0][3]
        return {
            "policy": POLICY_ID,
            "selected": deepcopy(selected),
            "candidates": deepcopy(candidates),
        }
