"""Finite GameAI-local Outcome Gradient and Local Bias stores."""

from copy import deepcopy
import hashlib
import json
from typing import Any


GRADIENT_SCHEMA = "risky-food-outcome-gradient-v1"
BIAS_SCHEMA = "risky-food-local-bias-v1"


class OutcomeBiasError(ValueError):
    pass


class OutcomeGradientStore:
    """Project physical outcome facts into relation-specific gradients."""

    def __init__(self, capacity: int = 128) -> None:
        _capacity(capacity)
        self.capacity = capacity
        self._records: dict[str, tuple[str, dict[str, Any]]] = {}
        self.capacity_rejections = 0

    def form(self, experience: dict[str, Any], outcome_facts: dict[str, Any]) -> dict[str, Any] | None:
        agent_id, experience_id, context = _validate_sources(experience, outcome_facts)
        dimensions = _dimensions(outcome_facts)
        identity = [GRADIENT_SCHEMA, agent_id, experience_id, outcome_facts]
        gradient_id = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
        record = {
            "gradient_id": gradient_id,
            "schema": GRADIENT_SCHEMA,
            "agent_id": agent_id,
            "source_experience_id": experience_id,
            "source_world_event_ids": [experience["source_event_id"]],
            "context_signature": context,
            "outcome_facts": deepcopy(outcome_facts),
            "dimensions": dimensions,
            "formation_rule": "relation-specific finite bands; no global reward scalar",
            "authority": "GameAI-local-gradient; not-E-H-theta-rho-M_B-candidate-or-action",
        }
        return self._admit(gradient_id, record)

    def _admit(self, identity: str, record: dict[str, Any]) -> dict[str, Any] | None:
        fingerprint = json.dumps(record, sort_keys=True)
        existing = self._records.get(identity)
        if existing is not None:
            if existing[0] != fingerprint:
                raise OutcomeBiasError("gradient replay changed frozen provenance")
            return deepcopy(existing[1])
        if len(self._records) >= self.capacity:
            self.capacity_rejections += 1
            return None
        self._records[identity] = (fingerprint, deepcopy(record))
        return deepcopy(record)

    def snapshot(self) -> dict[str, Any]:
        return {
            "schema": GRADIENT_SCHEMA,
            "records": deepcopy([item[1] for item in self._records.values()]),
            "count": len(self._records), "capacity": self.capacity,
            "capacity_rejections": self.capacity_rejections,
            "retention": "process lifetime; deterministic replay; no eviction",
            "authority": "read-only-local-gradients",
        }


class LocalBiasStore:
    """Form one non-command relation bias for every non-zero gradient dimension."""

    def __init__(self, capacity: int = 256) -> None:
        _capacity(capacity)
        self.capacity = capacity
        self._records: dict[str, tuple[str, dict[str, Any]]] = {}
        self.capacity_rejections = 0

    def form(self, gradient: dict[str, Any]) -> list[dict[str, Any]]:
        _validate_gradient(gradient)
        created = []
        for dimension in gradient["dimensions"]:
            if dimension["magnitude"] == 0:
                continue
            identity = [BIAS_SCHEMA, gradient["gradient_id"], dimension["relation"]]
            bias_id = hashlib.sha256(json.dumps(identity).encode()).hexdigest()
            record = {
                "bias_id": bias_id,
                "schema": BIAS_SCHEMA,
                "agent_id": gradient["agent_id"],
                "source_gradient_id": gradient["gradient_id"],
                "source_experience_id": gradient["source_experience_id"],
                "source_world_event_ids": deepcopy(gradient["source_world_event_ids"]),
                "context_signature": deepcopy(gradient["context_signature"]),
                "relation": dimension["relation"],
                "direction": dimension["direction"],
                "strength": dimension["magnitude_band"],
                "magnitude": dimension["magnitude"],
                "formation_rule": "bias strength equals absolute finite gradient band",
                "authority": "GameAI-local-bias; relation-only-not-action-M_B-H-E-theta-rho-or-candidate",
            }
            admitted = self._admit(bias_id, record)
            if admitted is not None:
                created.append(admitted)
        return created

    def _admit(self, identity: str, record: dict[str, Any]) -> dict[str, Any] | None:
        fingerprint = json.dumps(record, sort_keys=True)
        existing = self._records.get(identity)
        if existing is not None:
            if existing[0] != fingerprint:
                raise OutcomeBiasError("bias replay changed frozen provenance")
            return deepcopy(existing[1])
        if len(self._records) >= self.capacity:
            self.capacity_rejections += 1
            return None
        self._records[identity] = (fingerprint, deepcopy(record))
        return deepcopy(record)

    def sleep_projection(self, agent_id: str) -> dict[str, Any]:
        if not isinstance(agent_id, str) or not agent_id:
            raise OutcomeBiasError("agent_id must be non-empty")
        records = [deepcopy(item[1]) for item in self._records.values()
                   if item[1]["agent_id"] == agent_id]
        return {
            "agent_id": agent_id,
            "local_bias_materials": records,
            "count": len(records),
            "authority": "Sleep-input-material-only; not-profile-candidate-T1-M_B-or-action",
        }

    def snapshot(self) -> dict[str, Any]:
        return {
            "schema": BIAS_SCHEMA,
            "records": deepcopy([item[1] for item in self._records.values()]),
            "count": len(self._records), "capacity": self.capacity,
            "capacity_rejections": self.capacity_rejections,
            "retention": "process lifetime; deterministic replay; no eviction",
            "authority": "read-only-local-biases",
        }


def _dimensions(facts: dict[str, Any]) -> list[dict[str, Any]]:
    acquired = facts["food_acquired"]
    returned = facts["returned_to_base"]
    injury = facts["injury_level"]
    reward = facts["reward_value"]
    injury_magnitude = {"none": 0, "light": 1, "medium": 2, "severe": 3}[injury]
    reward_magnitude = {"ZERO": 0, "NORMAL": 2, "HIGH": 3}[reward] if acquired else 0
    return [
        _dimension("acquisition", "positive" if acquired else "negative", 3),
        _dimension("return", "positive" if returned else "negative", 3 if returned else 2),
        _dimension("injury", "neutral" if injury_magnitude == 0 else "negative", injury_magnitude),
        _dimension("reward_value", "positive" if reward_magnitude else "neutral", reward_magnitude),
    ]


def _dimension(relation: str, direction: str, magnitude: int) -> dict[str, Any]:
    return {
        "relation": relation, "direction": direction, "magnitude": magnitude,
        "magnitude_band": {0: "ZERO", 1: "WEAK", 2: "MEDIUM", 3: "STRONG"}[magnitude],
    }


def _validate_sources(experience: dict[str, Any], facts: dict[str, Any]) -> tuple[str, str, dict[str, Any]]:
    if not isinstance(experience, dict):
        raise OutcomeBiasError("Experience must be an object")
    agent_id = experience.get("agent_id")
    experience_id = experience.get("record_id")
    interaction = experience.get("interaction")
    context = interaction.get("context") if isinstance(interaction, dict) else None
    if not isinstance(agent_id, str) or not agent_id:
        raise OutcomeBiasError("Experience agent_id must be non-empty")
    if not isinstance(experience_id, str) or not experience_id:
        raise OutcomeBiasError("Experience record_id must be non-empty")
    if not isinstance(context, dict) or context.get("food_id") != "tasty_food":
        raise OutcomeBiasError("v1 requires Risky Tasty Food Experience context")
    if not isinstance(facts, dict) or set(facts) != {
        "food_acquired", "returned_to_base", "injury_level", "reward_value"
    }:
        raise OutcomeBiasError("outcome facts must use the finite v1 dimensions")
    if type(facts["food_acquired"]) is not bool or type(facts["returned_to_base"]) is not bool:
        raise OutcomeBiasError("acquisition and return facts must be boolean")
    if facts["injury_level"] not in {"none", "light", "medium", "severe"}:
        raise OutcomeBiasError("unsupported injury level")
    if facts["reward_value"] not in {"ZERO", "NORMAL", "HIGH"}:
        raise OutcomeBiasError("unsupported reward value")
    if not facts["food_acquired"] and facts["reward_value"] != "ZERO":
        raise OutcomeBiasError("unacquired Food cannot report a reward value")
    return agent_id, experience_id, deepcopy(context)


def _validate_gradient(gradient: dict[str, Any]) -> None:
    if not isinstance(gradient, dict) or gradient.get("schema") != GRADIENT_SCHEMA:
        raise OutcomeBiasError("unsupported Outcome Gradient")
    if not isinstance(gradient.get("agent_id"), str) or not gradient["agent_id"]:
        raise OutcomeBiasError("gradient agent identity is incomplete")
    if not isinstance(gradient.get("dimensions"), list):
        raise OutcomeBiasError("gradient dimensions must be a list")


def _capacity(value: int) -> None:
    if type(value) is not int or value <= 0:
        raise OutcomeBiasError("capacity must be a positive integer")
