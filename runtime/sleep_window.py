"""Finite immutable source windows for opt-in Sleep consolidation experiments."""

from copy import deepcopy
import hashlib
import json
from typing import Any


MIN_WINDOW_SIZE = 3
MAX_WINDOW_SIZE = 6
WINDOW_POLICY_ID = "sleep-experience-window-v1"


class SleepWindowError(ValueError):
    pass


class SleepExperienceWindowStore:
    """Freeze bounded references to accepted raw Experience records."""

    def __init__(self, capacity: int = 128):
        if type(capacity) is not int or capacity < 1:
            raise ValueError("sleep window capacity must be a positive integer")
        self.capacity = capacity
        self._windows: dict[tuple[str, str], dict[str, Any]] = {}

    def form_window(self, history_snapshot: dict[str, Any], *, agent_id: str,
                    sleep_cycle: str, formation_tick: int,
                    enabled: bool = False) -> dict[str, Any]:
        if enabled is not True:
            raise SleepWindowError("Sleep window formation requires explicit opt-in")
        _validate_identity(agent_id, sleep_cycle, formation_tick)
        records = _accepted_records(history_snapshot)
        key = (agent_id, sleep_cycle)

        existing = self._windows.get(key)
        if existing is not None:
            self._verify_sources(existing, records)
            return deepcopy(existing)
        if len(self._windows) >= self.capacity:
            raise SleepWindowError("sleep window capacity reached; start a fresh runtime")

        eligible = [record for record in records if record.get("agent_id") == agent_id]
        eligible.sort(key=_record_order)
        selected = eligible[-MAX_WINDOW_SIZE:]
        source_ids = [record["record_id"] for record in selected]
        if len(source_ids) != len(set(source_ids)):
            raise SleepWindowError("duplicate Experience source identity")

        status = "READY" if len(selected) >= MIN_WINDOW_SIZE else "INSUFFICIENT_EVIDENCE"
        boundary = {
            "agent_id": agent_id,
            "sleep_cycle": sleep_cycle,
            "formation_tick": formation_tick,
            "minimum_records": MIN_WINDOW_SIZE,
            "maximum_records": MAX_WINDOW_SIZE,
            "selection": "latest accepted same-agent records by tick/decision_tick/record_id",
        }
        window_id = hashlib.sha256(
            json.dumps([WINDOW_POLICY_ID, boundary, source_ids], sort_keys=True).encode()
        ).hexdigest()
        window = {
            "window_id": window_id,
            "status": status,
            "agent_id": agent_id,
            "sleep_cycle": sleep_cycle,
            "formation_tick": formation_tick,
            "source_experience_ids": source_ids,
            "source_count": len(source_ids),
            "boundary": boundary,
            "policy": WINDOW_POLICY_ID,
            "authority": "GameAI-local-source-window; not-relation-candidate-M_B-or-T1",
        }
        self._windows[key] = deepcopy(window)
        return deepcopy(window)

    def snapshot(self) -> dict[str, Any]:
        return {
            "authority": "read-only-sleep-window-store",
            "policy": WINDOW_POLICY_ID,
            "capacity": self.capacity,
            "windows": deepcopy(list(self._windows.values())),
        }

    @staticmethod
    def _verify_sources(window: dict[str, Any], records: list[dict[str, Any]]) -> None:
        by_id = {record["record_id"]: record for record in records}
        for source_id in window["source_experience_ids"]:
            source = by_id.get(source_id)
            if source is None:
                raise SleepWindowError("Sleep window source Experience disappeared")
            if source.get("agent_id") != window["agent_id"]:
                raise SleepWindowError("Sleep window source agent identity changed")


def _validate_identity(agent_id: str, sleep_cycle: str, formation_tick: int) -> None:
    if not isinstance(agent_id, str) or not agent_id.strip():
        raise SleepWindowError("agent_id must be non-empty")
    if not isinstance(sleep_cycle, str) or not sleep_cycle.strip():
        raise SleepWindowError("sleep_cycle must be non-empty")
    if type(formation_tick) is not int or formation_tick < 0:
        raise SleepWindowError("formation_tick must be a non-negative integer")


def _accepted_records(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    if not isinstance(snapshot, dict) or snapshot.get("authority") != "read-only-history":
        raise SleepWindowError("Sleep window requires a raw Experience history snapshot")
    records = snapshot.get("records")
    if not isinstance(records, list):
        raise SleepWindowError("Experience records must be a list")
    accepted = []
    for record in records:
        if not isinstance(record, dict):
            raise SleepWindowError("Experience record must be an object")
        record_id = record.get("record_id")
        agent_id = record.get("agent_id")
        if not isinstance(record_id, str) or not record_id:
            raise SleepWindowError("Experience record_id must be non-empty")
        if not isinstance(agent_id, str) or not agent_id:
            raise SleepWindowError("Experience agent_id must be non-empty")
        accepted.append(record)
    return accepted


def _record_order(record: dict[str, Any]) -> tuple[int, int, str]:
    tick = record.get("tick")
    decision_tick = record.get("decision_tick")
    if type(tick) is not int or type(decision_tick) is not int:
        raise SleepWindowError("Experience ordering ticks must be integers")
    return tick, decision_tick, record["record_id"]
