"""Read-only Core v2.3 interpretation/comparison sidecar for GameAI.

This module introduces an explicit finite frozen self-side evaluator M_B and
forms F / F' / E from already-acquired RIB_B sections. A separate finite ledger
supports explicit residual review; neither path has action authority.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import hashlib
import math
from types import MappingProxyType
from typing import Any, Mapping
from .v23_assessment import FiniteAssessmentLedger
from .review_path import build_review_path_snapshot
from .theta_effective import FiniteThetaEffectiveEvaluator, build_theta_effective_snapshot
from .m_delta import FiniteMDeltaStateMachine
from .t1_material_expansion import T1MaterialExpansionStore, T1MaterialExpansionError
from .t1_material_selection import T1MaterialSelectionLedger
from .t1_reconstruction import T1ReconstructionStore

from .v23_acquisition import (
    AcquisitionError,
    GameAIBoundary,
    GameAIRIBSection,
    XI_STATUS,
    acquire_rib_section,
)


class InterpretationError(ValueError):
    """Raised when frozen M_B comparison invariants cannot be satisfied."""


def _freeze_numeric_mapping(
    name: str,
    values: Mapping[str, float],
    dimensions: tuple[str, ...],
) -> Mapping[str, float]:
    expected = set(dimensions)
    actual = set(values)
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise InterpretationError(f"{name} keys must match dimensions; missing={missing}, extra={extra}")

    frozen: dict[str, float] = {}
    for dimension in dimensions:
        value = float(values[dimension])
        if not math.isfinite(value):
            raise InterpretationError(f"{name}.{dimension} must be finite")
        frozen[dimension] = value
    return MappingProxyType(frozen)


@dataclass(frozen=True)
class FrozenGameAIMB:
    """Finite self-side evaluator used only for the declared GameAI boundary.

    Coefficients are GameAI-local implementation choices, not Core constants
    and not action authority. The object is immutable after construction so
    F/F' comparison can prove use of the same pre-update M_B.
    """

    agent_id: str
    model_ref: str
    boundary: GameAIBoundary
    coefficients: Mapping[str, float]
    biases: Mapping[str, float]
    provenance: Mapping[str, str] = field(default_factory=dict)
    xi_status: str = XI_STATUS

    def __post_init__(self) -> None:
        if not self.agent_id:
            raise InterpretationError("agent_id must be non-empty")
        if not self.model_ref:
            raise InterpretationError("model_ref must be non-empty")
        object.__setattr__(
            self,
            "coefficients",
            _freeze_numeric_mapping("coefficients", self.coefficients, self.boundary.dimensions),
        )
        object.__setattr__(
            self,
            "biases",
            _freeze_numeric_mapping("biases", self.biases, self.boundary.dimensions),
        )
        object.__setattr__(self, "provenance", MappingProxyType(dict(self.provenance)))

    @property
    def context_key(self) -> tuple[Any, ...]:
        return (self.agent_id,) + self.boundary.context_key

    def interpret(self, section: GameAIRIBSection) -> "GameAIInterpretation":
        if section.context_key != self.context_key:
            raise InterpretationError("RIB_B context does not match frozen M_B context")
        if tuple(section.coverage) != self.boundary.dimensions:
            raise InterpretationError("RIB_B selected coverage must exactly match frozen M_B dimensions")

        values: dict[str, float] = {}
        for dimension in self.boundary.dimensions:
            if dimension not in section.values:
                raise InterpretationError(f"RIB_B missing selected dimension {dimension}")
            source_value = float(section.values[dimension])
            if not math.isfinite(source_value):
                raise InterpretationError(f"RIB_B {dimension} must be finite")
            values[dimension] = (
                self.coefficients[dimension] * source_value + self.biases[dimension]
            )

        return GameAIInterpretation(
            section_id=section.section_id,
            source_observation_id=section.source_observation_id,
            tick=section.tick,
            agent_id=section.agent_id,
            context_key=section.context_key,
            model_ref=self.model_ref,
            values=MappingProxyType(values),
            provenance=MappingProxyType(
                {
                    "rib_section_id": section.section_id,
                    "model_ref": self.model_ref,
                    "formation": "interp(frozen-M_B,RIB_B)",
                }
            ),
        )

    def to_json(self) -> dict[str, Any]:
        return {
            "agent_id": self.agent_id,
            "model_ref": self.model_ref,
            "boundary": {
                "boundary_id": self.boundary.boundary_id,
                "purpose": self.boundary.purpose,
                "dimensions": list(self.boundary.dimensions),
                "conditions": dict(self.boundary.conditions),
            },
            "coefficients": dict(self.coefficients),
            "biases": dict(self.biases),
            "provenance": dict(self.provenance),
            "xi_status": self.xi_status,
            "authority": "diagnostic-only",
        }


@dataclass(frozen=True)
class GameAIInterpretation:
    section_id: str
    source_observation_id: str
    tick: int
    agent_id: str
    context_key: tuple[Any, ...]
    model_ref: str
    values: Mapping[str, float]
    provenance: Mapping[str, str]

    def to_json(self) -> dict[str, Any]:
        return {
            "section_id": self.section_id,
            "source_observation_id": self.source_observation_id,
            "tick": self.tick,
            "agent_id": self.agent_id,
            "model_ref": self.model_ref,
            "values": dict(self.values),
            "provenance": dict(self.provenance),
        }


@dataclass(frozen=True)
class GameAIMismatch:
    first_section_id: str
    later_section_id: str
    agent_id: str
    model_ref: str
    context_key: tuple[Any, ...]
    deltas: Mapping[str, float]
    nonzero_dimensions: tuple[str, ...]
    provenance: Mapping[str, str]

    @property
    def is_zero(self) -> bool:
        return not self.nonzero_dimensions

    def to_json(self) -> dict[str, Any]:
        return {
            "first_section_id": self.first_section_id,
            "later_section_id": self.later_section_id,
            "agent_id": self.agent_id,
            "model_ref": self.model_ref,
            "deltas": dict(self.deltas),
            "nonzero_dimensions": list(self.nonzero_dimensions),
            "is_zero": self.is_zero,
            "provenance": dict(self.provenance),
            "status": "E-only-not-reviewed",
        }


def build_diagnostic_frozen_mb(section: GameAIRIBSection) -> FrozenGameAIMB:
    """Create the minimal finite diagnostic evaluator for one exact context."""

    context_digest = hashlib.sha256(repr(section.context_key).encode("utf-8")).hexdigest()[:12]
    return FrozenGameAIMB(
        agent_id=section.agent_id,
        model_ref=f"gameai-diagnostic-mb:{section.agent_id}:{context_digest}:v1",
        boundary=section.boundary,
        coefficients={dimension: 1.0 for dimension in section.boundary.dimensions},
        biases={dimension: 0.0 for dimension in section.boundary.dimensions},
        provenance={
            "scope": "finite diagnostic evaluator",
            "selection": "explicit identity projection over selected RIB_B dimensions",
            "context_digest": context_digest,
        },
    )


def compare_interpretations(
    current: GameAIInterpretation,
    later: GameAIInterpretation,
) -> GameAIMismatch:
    """Form E only when F/F' share the exact frozen pre-update M_B/context."""

    if current.agent_id != later.agent_id:
        raise InterpretationError("F/F' agent mismatch")
    if current.model_ref != later.model_ref:
        raise InterpretationError("F/F' must use the same frozen pre-update M_B")
    if current.context_key != later.context_key:
        raise InterpretationError("F/F' finite boundary context changed")
    if current.source_observation_id == later.source_observation_id:
        raise InterpretationError("F/F' require distinct observation instances")
    if set(current.values) != set(later.values):
        raise InterpretationError("F/F' selected interpretation dimensions differ")

    deltas = {
        dimension: float(later.values[dimension]) - float(current.values[dimension])
        for dimension in current.values
    }
    nonzero = tuple(dimension for dimension, value in deltas.items() if value != 0.0)
    return GameAIMismatch(
        first_section_id=current.section_id,
        later_section_id=later.section_id,
        agent_id=current.agent_id,
        model_ref=current.model_ref,
        context_key=current.context_key,
        deltas=MappingProxyType(deltas),
        nonzero_dimensions=nonzero,
        provenance=MappingProxyType(
            {
                "first_section_id": current.section_id,
                "later_section_id": later.section_id,
                "model_ref": current.model_ref,
                "comparison": "Delta(F,F_prime)",
            }
        ),
    )


class GameAIFrozenComparisonSidecar:
    """Read-only sidecar for acquisition -> frozen M_B -> F/F' -> E."""

    def __init__(self, theta_evaluator: FiniteThetaEffectiveEvaluator | None = None) -> None:
        self._models: dict[tuple[Any, ...], FrozenGameAIMB] = {}
        self._previous: dict[tuple[Any, ...], GameAIInterpretation] = {}
        self._previous_sections: dict[tuple[Any, ...], GameAIRIBSection] = {}
        self._seen_observations: dict[tuple[Any, ...], set[str]] = {}
        self._latest_sections: dict[str, GameAIRIBSection] = {}
        self._latest_interpretations: dict[str, GameAIInterpretation] = {}
        self._latest_mismatches: dict[str, GameAIMismatch] = {}
        self._comparison_paths: dict[str, dict[str, Any]] = {}
        self._captures = 0
        self._comparisons = 0
        self._duplicate_observations = 0
        self._failures: list[dict[str, str]] = []
        self.assessments = FiniteAssessmentLedger()
        self.theta_evaluator = theta_evaluator or FiniteThetaEffectiveEvaluator()
        self.m_delta = FiniteMDeltaStateMachine()
        self.t1_materials = T1MaterialExpansionStore()
        self.t1_selection = T1MaterialSelectionLedger()
        self.t1_reconstruction = T1ReconstructionStore()

    def review_assessment(self, payload: Mapping[str, Any]) -> dict[str, Any]:
        """Commit explicit review, then evaluate and apply the C3/C4 boundary once."""

        reviewed = self.assessments.review(payload)
        assessment = self.assessments.snapshot()
        review_path = build_review_path_snapshot(self._comparison_paths, assessment)
        theta_snapshot = build_theta_effective_snapshot(review_path, self.theta_evaluator)
        matching = [item for item in theta_snapshot["evaluations"]
                    if item["assessment_id"] == reviewed["assessment_id"]]
        if len(matching) != 1:
            raise InterpretationError("reviewed assessment lost its theta evaluation")
        self.m_delta.accept(matching[0])
        return reviewed

    def expand_t1_materials(self, *, assessment_id: str,
                            candidates: list[dict[str, Any]] | None = None,
                            experiences: list[dict[str, Any]] | None = None) -> dict[str, Any] | None:
        """Explicitly freeze T1-A inputs for one active M_delta entry."""

        assessment = self.assessments.snapshot()
        review_path = build_review_path_snapshot(self._comparison_paths, assessment)
        paths = [path for path in review_path["paths"]
                 if path["assessment_id"] == assessment_id]
        if len(paths) != 1:
            raise T1MaterialExpansionError("unknown or ambiguous assessment_id")
        path = paths[0]
        states = [state for state in self.m_delta.snapshot()["states"]
                  if state["model_ref"] == path["model_ref"]]
        if len(states) != 1:
            raise T1MaterialExpansionError("assessment has no finite phase state")
        models = {model.model_ref: model.to_json() for model in self._models.values()}
        return self.t1_materials.expand(
            m_delta_state=states[0], model=models[path["model_ref"]], review_path=path,
            candidates=candidates, experiences=experiences,
        )

    def inspect_t1_materials(self, *, bundle_id: str,
                             payload: Mapping[str, Any]) -> dict[str, Any] | None:
        """Apply one explicit, complete T1-B review to a frozen T1-A bundle."""

        return self.t1_selection.inspect(
            self.t1_materials.bundle(bundle_id), dict(payload)
        )

    def reconstruct_t1(self, *, bundle_id: str) -> dict[str, Any] | None:
        """Construct an inactive M_B prime artifact from the latest T1-B revision."""

        return self.t1_reconstruction.reconstruct(
            bundle=self.t1_materials.bundle(bundle_id),
            selection=self.t1_selection.record(bundle_id),
        )

    def capture(self, packet: Mapping[str, Any]) -> GameAIMismatch | None:
        try:
            section = acquire_rib_section(packet)
            key = section.context_key
            model = self._models.get(key)
            if model is None:
                model = build_diagnostic_frozen_mb(section)
                self._models[key] = model
            interpretation = model.interpret(section)
        except (AcquisitionError, InterpretationError) as exc:
            self._failures.append(
                {
                    "observation_id": str(packet.get("observation_id", "")),
                    "error": str(exc),
                }
            )
            return None

        self._captures += 1
        seen = self._seen_observations.setdefault(key, set())
        if interpretation.source_observation_id in seen:
            self._duplicate_observations += 1
            return None

        previous = self._previous.get(key)
        previous_section = self._previous_sections.get(key)
        if previous is not None and interpretation.tick < previous.tick:
            self._failures.append({"observation_id": interpretation.source_observation_id,
                                   "error": "observation tick precedes comparison window"})
            return None
        seen.add(interpretation.source_observation_id)
        self._latest_sections[section.agent_id] = section
        self._latest_interpretations[section.agent_id] = interpretation
        self._previous[key] = interpretation
        self._previous_sections[key] = section
        if previous is None:
            return None

        mismatch = compare_interpretations(previous, interpretation)
        self._latest_mismatches[section.agent_id] = mismatch
        self._comparisons += 1
        assessment_id = self.assessments.register(mismatch)
        if assessment_id is not None:
            self._comparison_paths.setdefault(assessment_id, {
                "RIB_B": previous_section.to_json(),
                "F": previous.to_json(),
                "RIB_B_prime": section.to_json(),
                "F_prime": interpretation.to_json(),
                "E": mismatch.to_json(),
            })
        return mismatch

    def snapshot(self) -> dict[str, Any]:
        assessment = self.assessments.snapshot()
        review_path = build_review_path_snapshot(self._comparison_paths, assessment)
        return {
            "authority": "read-only-comparison-sidecar",
            "stage": "RIB_B-frozen-M_B-F-F_prime-E",
            "captures": self._captures,
            "comparisons": self._comparisons,
            "duplicate_observations": self._duplicate_observations,
            "latest_sections": {
                agent_id: section.to_json()
                for agent_id, section in sorted(self._latest_sections.items())
            },
            "models": {
                model.model_ref: model.to_json()
                for model in sorted(self._models.values(), key=lambda item: item.model_ref)
            },
            "latest_interpretations": {
                agent_id: interpretation.to_json()
                for agent_id, interpretation in sorted(self._latest_interpretations.items())
            },
            "latest_E": {
                agent_id: mismatch.to_json()
                for agent_id, mismatch in sorted(self._latest_mismatches.items())
            },
            "failures": list(self._failures),
            "assessment": assessment,
            "review_path": review_path,
            "theta_effective": build_theta_effective_snapshot(review_path, self.theta_evaluator),
            "M_delta": self.m_delta.snapshot(),
            "T1_materials": self.t1_materials.snapshot(),
            "T1_selection": self.t1_selection.snapshot(),
            "T1_reconstruction": self.t1_reconstruction.snapshot(),
            "not_implemented": ["time-decay", "authority-cutover", "re-entry"],
            "xi_status": XI_STATUS,
        }
