"""Finite GameAI-local interaction history, without interpretation authority."""

from copy import deepcopy
import hashlib
import json


class HistoryError(ValueError):
    pass


class InteractionHistory:
    def __init__(self, capacity=128):
        self.capacity = capacity
        self._decisions = {}
        self._results = {}
        self.capacity_rejections = 0

    def register_decision(self, packet, decision):
        if decision["action"]["type"] != "approach":
            return
        key = (decision["agent_id"], decision["inspection"]["observation_id"])
        entry = {"agent_id": key[0], "source_observation_id": key[1],
                 "tick": packet["tick"], "action": deepcopy(decision["action"]),
                 "context": {"purpose": "approach-result-history",
                             "perception_rule": str(packet["observation"].get("perception_rule", "unspecified"))}}
        if key in self._decisions:
            if self._decisions[key] != entry:
                raise HistoryError("observation ID reused with a different decision/context")
            return
        if len(self._decisions) >= self.capacity:
            self.capacity_rejections += 1
            return
        self._decisions[key] = entry

    def record_result(self, payload):
        if not isinstance(payload, dict):
            raise HistoryError("result must be an object")
        for name in ("agent_id", "source_observation_id", "subsequent_observation_id", "target_id"):
            if not isinstance(payload.get(name), str) or not payload[name].strip():
                raise HistoryError(f"{name} must be non-empty")
        key = (payload["agent_id"], payload["source_observation_id"])
        decision = self._decisions.get(key)
        if decision is None:
            raise HistoryError("no admitted approach decision for source observation")
        if payload["target_id"] != decision["action"]["target_id"]:
            raise HistoryError("target differs from accepted decision")
        if payload["subsequent_observation_id"] == key[1]:
            raise HistoryError("subsequent observation must be distinct")
        if type(payload.get("tick")) is not int or payload["tick"] < decision["tick"]:
            raise HistoryError("result tick precedes decision")
        if payload.get("outcome") not in ("approach_progress", "approach_no_progress"):
            raise HistoryError("unsupported outcome")
        record = {**deepcopy(decision), "tick": payload["tick"],
                  "decision_tick": decision["tick"],
                  "subsequent_observation_id": payload["subsequent_observation_id"],
                  "outcome": payload["outcome"],
                  "record_id": hashlib.sha256(json.dumps(key).encode()).hexdigest(),
                  "provenance": "workbench-reported bounded action result"}
        if key in self._results and self._results[key] != record:
            raise HistoryError("conflicting result for the same source decision")
        self._results[key] = record
        return deepcopy(record)

    def snapshot(self):
        groups = {}
        for record in self._results.values():
            key = json.dumps([record["agent_id"], record["action"]["target_id"], record["context"]], sort_keys=True)
            group = groups.setdefault(key, {"agent_id": record["agent_id"],
                                          "target_id": record["action"]["target_id"],
                                          "context": deepcopy(record["context"]),
                                          "approach_progress": [], "approach_no_progress": []})
            group[record["outcome"]].append(record["record_id"])
        return {"authority": "read-only-history", "records": deepcopy(list(self._results.values())),
                "relations": list(groups.values()), "capacity": self.capacity,
                "admitted_decisions": len(self._decisions),
                "pending_results": len(self._decisions) - len(self._results),
                "capacity_rejections": self.capacity_rejections,
                "retention": "process lifetime; no decay or eviction; restart clears history"}
