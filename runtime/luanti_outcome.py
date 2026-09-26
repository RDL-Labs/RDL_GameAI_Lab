"""Explicit Luanti consequence admission into existing local learning stores."""

from typing import Any

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

    def snapshot(self) -> dict[str, Any]:
        return {
            "schema": "luanti-outcome-learning-snapshot-v1",
            "experiences": self.experiences.snapshot(),
            "gradients": self.gradients.snapshot(),
            "biases": self.biases.snapshot(),
            "authority": "read-only-local-learning; not-action-or-canonical-authority",
        }
