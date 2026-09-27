"""L13R: bounded cross-day record retention around the unchanged L13A policy.

This ledger has no body, route-selection, Experience, T1 or M_B authority.
World geometry belongs to the experiment harness, never to retained material.
"""
from copy import deepcopy
from hashlib import sha256
from math import hypot
import json
from threading import RLock

from .exploration import CAPACITY, LIMIT_US, FiniteExploration, fields, integer, ref, require

SCHEMA = "l13r-exploration-series-v1"
MAX_DAYS = 30
AUTHORITY = "record-retention-only; fixed-L13A-policy-does-not-consume-history"


def digest(value):
    return sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                             ensure_ascii=False, allow_nan=False).encode()).hexdigest()


def accepted_day(deliveries):
    """Revalidate only agent-facing requests/receipts, including actual results.

    Successful replay verifies the software contract, not physical truth. The
    independent Luanti checker validates these records against World readbacks.
    """
    require(isinstance(deliveries, list) and 2 <= len(deliveries) <= 4 * CAPACITY,
            "delivery_budget")
    first = deliveries[0]
    fields(first, "kind request response")
    require(first["kind"] == "configure", "configure_first")
    loop = FiniteExploration(first["request"]["run_id"])
    for delivery in deliveries:
        fields(delivery, "kind request response")
        require(delivery["kind"] in ("configure", "observe", "result", "finish"), "delivery_kind")
        actual = getattr(loop, delivery["kind"])(delivery["request"])
        require(actual == delivery["response"], "receipt_mismatch")
    state = loop.snapshot()
    require(deliveries[-1]["kind"] == "finish" and state["ending"] is not None, "unfinished_day")
    require(state["ending"]["reason"] in ("acquired", "time_limit"), "mechanism_error")
    require(bool(state["observations"]), "empty_day")
    require(not next(iter(state["observations"].values()))["food"]["visible"], "initial_food_known")
    return state


def day_metrics(state):
    observations = list(state["observations"].values())
    results = list(state["results"].values())
    found = next((p for p in observations if p["food"]["visible"]), None)
    acquired = next((r for r in results if r["acquired"]), None)
    limit = found["capture_us"] if found else None
    prefix = [r for r in results if limit is not None and r["executed_us"] <= limit]
    return dict(
        observations=len(observations), permits=len(state["commands"]),
        distance=sum(hypot(r["forward"], r["right"], r["up"]) if "up" in r else abs(r["forward"]) for r in results),
        rotation=sum(abs(r["yaw"]) for r in results),
        exploration_us=min(state["ending"]["ended_us"], LIMIT_US),
        first_food_us=limit, first_food_source=found["observation_id"] if found else None,
        acquired=acquired is not None, acquired_us=acquired["executed_us"] if acquired else None,
        distance_to_discovery=sum(hypot(r["forward"], r["right"], r["up"]) if "up" in r else abs(r["forward"]) for r in prefix) if found else None,
        permits_to_discovery=len(prefix) if found else None,
        incomplete_observations=sum(p["ground"]["coverage"] != "complete"
                                    or p["food"]["coverage"] != "complete" for p in observations),
        blocked=sum(r["status"] == "blocked" for r in results),
        ending=state["ending"]["reason"],
    )


class ExplorationSeries:
    def __init__(self, series_id, mode="memory", max_days=MAX_DAYS):
        ref(series_id)
        require(mode in ("memory", "reset"), "mode")
        integer(max_days, 1, MAX_DAYS)
        self.config = dict(schema=SCHEMA, series_id=series_id, agent_id="npc_a",
                           mode=mode, max_days=max_days)
        self.days = []
        self.pending = None
        self.failure = None
        self.lock = RLock()

    def history(self):
        """Read-only next-day material; the baseline action policy does not use it."""
        with self.lock:
            return deepcopy([dict(episode_id=d["episode_id"], run_id=d["run_id"],
                                  state=d["state"], evidence_digest=d["evidence_digest"])
                             for d in self.days] if self.config["mode"] == "memory" else [])

    def _status(self):
        if self.failure is not None:
            return "mechanism_error"
        if self.days and self.days[-1]["metrics"]["first_food_us"] is not None:
            return "discovered"
        if len(self.days) == self.config["max_days"]:
            return "undiscovered_at_limit"
        return "running"

    def start_day(self, request):
        with self.lock:
            fields(request, "episode_id run_id")
            for value in request.values():
                ref(value)
            for day in self.days:
                if day["episode_id"] == request["episode_id"]:
                    require(day["run_id"] == request["run_id"], "episode_conflict")
                    return deepcopy(day["start"])
            if self.pending is not None:
                require(self.pending["request"] == request, "day_in_progress")
                return deepcopy(self.pending)
            require(self._status() == "running", "series_closed")
            require(all(d["run_id"] != request["run_id"] for d in self.days), "run_reused")
            prior = self.days if self.config["mode"] == "memory" else []
            start = dict(request=deepcopy(request), day=len(self.days) + 1,
                         history_refs=[dict(episode_id=d["episode_id"], run_id=d["run_id"],
                                            evidence_digest=d["evidence_digest"]) for d in prior],
                         history_observations=sum(d["metrics"]["observations"] for d in prior),
                         history_consumed_by_policy=False, authority=AUTHORITY)
            self.pending = start
            return deepcopy(start)

    def close_day(self, request):
        with self.lock:
            fields(request, "episode_id run_id deliveries")
            fingerprint = digest(request)
            for day in self.days:
                if day["episode_id"] == request["episode_id"]:
                    require(day["input_digest"] == fingerprint, "day_conflict")
                    return deepcopy(day["receipt"])
            require(self.pending is not None and self._status() == "running", "no_active_day")
            require(self.pending["request"] == {k: request[k] for k in ("episode_id", "run_id")},
                    "day_binding")
            # Validate everything before publishing; failed/foreign input retains the pending day.
            state = accepted_day(request["deliveries"])
            require(state["config"]["run_id"] == request["run_id"], "run_binding")
            metrics = day_metrics(state)
            evidence_digest = digest(state)
            receipt = dict(accepted=True, episode_id=request["episode_id"], run_id=request["run_id"],
                           day=len(self.days) + 1, metrics=metrics, evidence_digest=evidence_digest)
            day = dict(episode_id=request["episode_id"], run_id=request["run_id"],
                       input_digest=fingerprint, evidence_digest=evidence_digest,
                       start=deepcopy(self.pending), state=state, metrics=metrics, receipt=receipt)
            self.days.append(day)
            self.pending = None
            return deepcopy(receipt)

    def abort(self, reason):
        with self.lock:
            require(reason in ("world_or_transport_error", "replay_error"), "abort_reason")
            if self.failure is not None:
                require(self.failure["reason"] == reason, "abort_conflict")
                return deepcopy(self.failure)
            require(self._status() == "running", "series_closed")
            self.failure = dict(reason=reason, day=len(self.days) + 1,
                                pending=deepcopy(self.pending))
            return deepcopy(self.failure)

    def summary(self):
        with self.lock:
            found = self.days[-1] if self.days and self.days[-1]["metrics"]["first_food_us"] is not None else None
            prior = self.days[:-1] if found else []
            def total(key, days=None):
                return sum(d["metrics"][key] for d in (self.days if days is None else days))
            return dict(config=deepcopy(self.config), authority=AUTHORITY, status=self._status(),
                        completed_days=len(self.days), discovery_day=len(self.days) if found else None,
                        time_to_discovery_us=(total("exploration_us", prior) + found["metrics"]["first_food_us"]) if found else None,
                        distance_to_discovery=(total("distance", prior) + found["metrics"]["distance_to_discovery"]) if found else None,
                        permits_to_discovery=(total("permits", prior) + found["metrics"]["permits_to_discovery"]) if found else None,
                        consumed_exploration_us=total("exploration_us"), observations=total("observations"),
                        permits=total("permits"), distance=total("distance"),
                        acquired=any(d["metrics"]["acquired"] for d in self.days),
                        history_available_next_day=len(self.days) if self.config["mode"] == "memory" else 0,
                        failure=deepcopy(self.failure))

    def snapshot(self):
        """Experimenter audit archive, including reset control records; not agent input."""
        with self.lock:
            return deepcopy(dict(summary=self.summary(), days=self.days, pending=self.pending))
