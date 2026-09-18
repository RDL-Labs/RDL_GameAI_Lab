"""Finite dominant-danger selection without action or trajectory authority."""

from copy import deepcopy


POLICY_ID = "safety-danger-selection-v1"
SEVERITY_RANK = {"low": 1, "medium": 2, "high": 3}


class DangerSelectionError(ValueError):
    pass


class SafetyDangerSelectionPolicy:
    def select(self, candidates):
        if not isinstance(candidates, list):
            raise DangerSelectionError("danger candidates must be a list")
        ranked = []
        seen = set()
        for candidate in candidates:
            if not isinstance(candidate, dict):
                raise DangerSelectionError("danger candidate must be an object")
            danger_id = candidate.get("danger_id")
            severity = candidate.get("severity")
            if not isinstance(danger_id, str) or not danger_id or danger_id in seen:
                raise DangerSelectionError("danger candidate IDs must be finite and unique")
            if severity not in SEVERITY_RANK:
                raise DangerSelectionError("unsupported danger severity")
            seen.add(danger_id)
            ranked.append((SEVERITY_RANK[severity], danger_id, candidate))
        if not ranked:
            return {"policy": POLICY_ID, "selected": None, "candidates": []}
        ranked.sort(key=lambda item: (-item[0], item[1]))
        return {
            "policy": POLICY_ID,
            "selected": deepcopy(ranked[0][2]),
            "candidates": deepcopy(candidates),
        }
