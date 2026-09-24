"""I3 finite immutable Activity Fast Retrieval query store."""

from copy import deepcopy
import json
from typing import Any

from ..functions.fast_retrieval import build_fast_retrieval, FastRetrievalError


class FastRetrievalStore:
    def __init__(self, capacity: int = 128):
        if type(capacity) is not int or capacity < 1:
            raise ValueError("Fast retrieval capacity must be positive")
        self.capacity = capacity
        self._queries: dict[str, tuple[str, dict[str, Any]]] = {}

    def retrieve(self, current_profile: dict[str, Any], sources: list[dict[str, Any]], *,
                 query_tick: int, enabled: bool = False) -> dict[str, Any]:
        if enabled is not True:
            raise FastRetrievalError("Fast retrieval requires explicit opt-in")
        fingerprint = json.dumps([current_profile, sources, query_tick], sort_keys=True)
        result = build_fast_retrieval(current_profile, sources, query_tick=query_tick)
        query_id = result["query_id"]
        existing = self._queries.get(query_id)
        if existing is not None:
            if existing[0] != fingerprint:
                raise FastRetrievalError("Fast retrieval replay changed frozen inputs")
            return deepcopy(existing[1])
        if len(self._queries) >= self.capacity:
            raise FastRetrievalError("Fast retrieval capacity reached; start a fresh runtime")
        self._queries[query_id] = (fingerprint, deepcopy(result))
        return deepcopy(result)

    def snapshot(self) -> dict[str, Any]:
        return {
            "authority": "read-only-Activity-Fast-retrieval",
            "queries": deepcopy([item[1] for item in self._queries.values()]),
            "capacity": self.capacity,
            "retention": "process lifetime; no action influence; restart clears queries",
        }
