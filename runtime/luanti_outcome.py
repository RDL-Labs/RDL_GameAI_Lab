"""Explicit Luanti consequence admission into existing local learning stores."""

from copy import deepcopy
from typing import Any

from .functions.local_bias_deep_similarity import (
    LocalBiasDeepSimilarityError,
    build_local_bias_deep_shadow,
)
from .functions.local_bias_profile import LocalBiasProfileError, build_local_bias_profiles
from .outcome_bias import LocalBiasStore, OutcomeBiasError, OutcomeGradientStore
from .territory_experience import TerritoryExperienceError, TerritoryExperienceStore


class LuantiOutcomeError(ValueError):
    pass


class LuantiOutcomeCoordinator:
    """Adapt one physical Luanti event without adding action or canonical authority."""

    def __init__(self) -> None:
        self.experiences = TerritoryExperienceStore()
        self.gradients = OutcomeGradientStore()
        self.biases = LocalBiasStore()
        self._sleep_results: dict[str, dict[str, Any]] = {}

    def record(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise LuantiOutcomeError("payload must be an object")
        event = payload.get("event")
        outcome_facts = payload.get("outcome_facts")
        if not isinstance(event, dict) or not isinstance(outcome_facts, dict):
            raise LuantiOutcomeError("event and outcome_facts must be objects")
        try:
            experience = self.experiences.record_direct(event)
            if experience is None:
                raise LuantiOutcomeError("Experience capacity reached")
            gradient = self.gradients.form(experience, outcome_facts)
            if gradient is None:
                raise LuantiOutcomeError("Outcome Gradient capacity reached")
            biases = self.biases.form(gradient)
        except (TerritoryExperienceError, OutcomeBiasError) as exc:
            raise LuantiOutcomeError(str(exc)) from exc
        return {
            "accepted": True,
            "experience": experience,
            "gradient": gradient,
            "biases": biases,
            "authority": "GameAI-local-learning-result; not-action-canonical-H-M_B-or-T1",
        }

    def consolidate(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise LuantiOutcomeError("payload must be an object")
        agent_id = payload.get("agent_id")
        sleep_cycle = payload.get("sleep_cycle")
        formation_tick = payload.get("formation_tick")
        if not isinstance(agent_id, str) or not agent_id:
            raise LuantiOutcomeError("agent_id must be non-empty")
        try:
            projection = self.biases.sleep_projection(agent_id)
            profiles = build_local_bias_profiles(projection)
            result = build_local_bias_deep_shadow(
                profiles, sleep_cycle=sleep_cycle, formation_tick=formation_tick
            )
        except (OutcomeBiasError, LocalBiasProfileError, LocalBiasDeepSimilarityError) as exc:
            raise LuantiOutcomeError(str(exc)) from exc
        existing = self._sleep_results.get(result["deep_similarity_id"])
        if existing is not None and existing != result:
            raise LuantiOutcomeError("Sleep result replay changed frozen provenance")
        self._sleep_results[result["deep_similarity_id"]] = deepcopy(result)
        return deepcopy(result)

    def snapshot(self) -> dict[str, Any]:
        return {
            "schema": "luanti-outcome-learning-snapshot-v1",
            "experiences": self.experiences.snapshot(),
            "gradients": self.gradients.snapshot(),
            "biases": self.biases.snapshot(),
            "sleep_results": deepcopy(list(self._sleep_results.values())),
            "authority": "read-only-local-learning; not-action-or-canonical-authority",
        }
