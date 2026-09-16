"""Opt-in finite retry policy; GameAI-local and independent of Core M_B/H."""

from copy import deepcopy
from types import MappingProxyType

from .core import ObservationError, RuntimeDecision, _is_food, decide_action, apply_body_constraint
from .sensitivity import RETRY_PROFILES
from .expression import with_expression


POLICY_ID = "approach-retry-window-v2"


class HistoryInfluencePolicy:
    """Freeze each decision by observation identity for one finite experiment."""

    def __init__(self, capacity=128, profiles=None):
        self.capacity = capacity
        self._decisions = {}
        configured = dict(profiles or {})
        for agent, name in configured.items():
            if not isinstance(agent, str) or not agent.strip() or not isinstance(name, str) or name not in RETRY_PROFILES:
                raise ValueError("invalid agent retry profile")
        self._profiles = MappingProxyType({agent: RETRY_PROFILES[name] for agent, name in configured.items()})

    def decide(self, packet, history):
        baseline = decide_action(packet)
        key = (baseline["agent_id"], baseline["inspection"]["observation_id"])
        if key in self._decisions:
            original, response = self._decisions[key]
            if original != packet:
                raise ObservationError("history-policy observation ID reused with different contents")
            return deepcopy(response)
        if len(self._decisions) >= self.capacity:
            raise ObservationError("history-policy decision capacity reached; start a fresh runtime")
        profile = self._profiles.get(key[0], RETRY_PROFILES["standard"])

        latest = {}
        rule = str(packet["observation"].get("perception_rule", "unspecified"))
        for record in history.snapshot()["records"]:
            if record["agent_id"] != key[0] or record["context"]["perception_rule"] != rule:
                continue
            if record["context"]["purpose"] != "approach-result-history":
                continue
            if record["tick"] > packet["tick"] or record["source_observation_id"] == key[1]:
                continue
            target = record["action"]["target_id"]
            if target not in latest or record["tick"] >= latest[target]["tick"]:
                latest[target] = record

        deferred = []
        candidate = None
        for item in packet["observation"]["visible_objects"]:
            if not _is_food(item):
                continue
            record = latest.get(item["id"])
            if (record is not None and record["outcome"] == "approach_no_progress"
                    and packet["tick"] - record["tick"] < profile.retry_ticks):
                deferred.append({"target_id": item["id"], "record_id": record["record_id"],
                                 "retry_at_tick": record["tick"] + profile.retry_ticks})
            elif candidate is None:
                candidate = item["id"]

        response = baseline
        if deferred:
            response = RuntimeDecision(
                agent_id=key[0], action_type="approach" if candidate else "idle",
                target_id=candidate, observation_id=key[1],
                reason="finite history retry window: recent no-progress targets deferred",
            ).to_json()
        response = apply_body_constraint(packet, response)
        response["inspection"]["history_influence"] = {
            "policy": POLICY_ID, "retry_ticks": profile.retry_ticks,
            "profile_id": profile.profile_id,
            "deferred_targets": deferred,
            "action_changed": response["action"] != baseline["action"],
            "authority": "GameAI-local-action-policy; not-canonical-M_B",
        }
        response = with_expression(response)
        self._decisions[key] = (deepcopy(packet), deepcopy(response))
        return response
