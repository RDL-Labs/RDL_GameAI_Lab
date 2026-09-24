"""I3 opt-in immutable store for Deep Similarity shadow results."""

from copy import deepcopy
import json
from typing import Any

from ..functions.deep_similarity import build_deep_similarity_shadow, DeepSimilarityError


class DeepSimilarityShadowStore:
    def __init__(self, capacity: int = 128):
        if type(capacity) is not int or capacity < 1:
            raise ValueError("Deep Similarity capacity must be a positive integer")
        self.capacity = capacity
        self._results: dict[str, tuple[str, dict[str, Any]]] = {}

    def form(self, window: dict[str, Any], profile_set: dict[str, Any], *,
             formation_tick: int, enabled: bool = False) -> dict[str, Any]:
        if enabled is not True:
            raise DeepSimilarityError("Deep Similarity requires explicit opt-in")
        window_id = window.get("window_id") if isinstance(window, dict) else None
        if not isinstance(window_id, str) or not window_id:
            raise DeepSimilarityError("window_id must be non-empty")
        fingerprint = json.dumps(
            [window, profile_set, formation_tick], sort_keys=True, separators=(",", ":")
        )
        existing = self._results.get(window_id)
        if existing is not None:
            if existing[0] != fingerprint:
                raise DeepSimilarityError("Deep Similarity replay changed frozen inputs")
            return deepcopy(existing[1])
        if len(self._results) >= self.capacity:
            raise DeepSimilarityError("Deep Similarity capacity reached; start a fresh runtime")
        result = build_deep_similarity_shadow(
            window, profile_set, formation_tick=formation_tick
        )
        self._results[window_id] = (fingerprint, deepcopy(result))
        return deepcopy(result)

    def snapshot(self) -> dict[str, Any]:
        return {
            "authority": "read-only-deep-similarity-shadow-store",
            "results": deepcopy([item[1] for item in self._results.values()]),
            "capacity": self.capacity,
        }
