"""Pure FoodNeed relation formation for the default-off M_B admission experiment.

This module validates and freezes an admission candidate. It does not register a
model, compare observations, mutate the canonical sidecar, or own action authority.
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace
import hashlib
import json
import math
from types import MappingProxyType
from typing import Any, Mapping

from .v23_acquisition import AcquisitionError, GameAIBoundary, GameAIRIBSection, acquire_rib_section


FOOD_RELATION_ID = "food-need-to-visible-food-salience-v1"
FOOD_RULE_VERSION = "linear-food-salience-v1"
FOOD_INPUT_DIMENSION = "visible_food_count"
FOOD_OUTPUT_DIMENSION = "visible_food_salience"
MAX_SHADOW_WINDOWS = 64


class FoodAdmissionError(ValueError):
    """Raised when a finite FoodNeed relation cannot be formed."""


def food_shadow_boundary_for_packet(packet: Mapping[str, Any]) -> GameAIBoundary:
    """Build the one allowlisted HTTP shadow boundary from a bounded packet."""

    agent_id = packet.get("agent_id")
    observation = packet.get("observation")
    if not isinstance(agent_id, str) or not agent_id:
        raise FoodAdmissionError("agent_id must be a non-empty string")
    if not isinstance(observation, Mapping):
        raise FoodAdmissionError("observation must be an object")
    perception_rule = observation.get("perception_rule", "unspecified")
    if perception_rule is None:
        perception_rule = "unspecified"
    return GameAIBoundary(
        boundary_id=f"gameai:{agent_id}:food-admission-shadow",
        purpose="food-need-admission-shadow",
        dimensions=(FOOD_INPUT_DIMENSION,),
        conditions={
            "packet_schema": "bounded-observation-v1",
            "perception_rule": str(perception_rule),
            "profile": "food-shadow-v1",
        },
    )


@dataclass(frozen=True)
class FoodNeedAdmissionSource:
    agent_id: str
    body_snapshot_id: str
    body_revision: int
    food_need: float
    source_observation_id: str
    source_tick: int
    owner: str = "Godot"

    def __post_init__(self) -> None:
        if not isinstance(self.agent_id, str) or not self.agent_id:
            raise FoodAdmissionError("agent_id must be non-empty")
        if not isinstance(self.body_snapshot_id, str) or not self.body_snapshot_id:
            raise FoodAdmissionError("body_snapshot_id must be non-empty")
        if type(self.body_revision) is not int or self.body_revision < 0:
            raise FoodAdmissionError("body_revision must be a non-negative integer")
        if (
            type(self.food_need) not in (int, float)
            or not math.isfinite(self.food_need)
            or not 0 <= self.food_need <= 1
        ):
            raise FoodAdmissionError("food_need must be finite in [0,1]")
        if not isinstance(self.source_observation_id, str) or not self.source_observation_id:
            raise FoodAdmissionError("source_observation_id must be non-empty")
        if type(self.source_tick) is not int or self.source_tick < 0:
            raise FoodAdmissionError("source_tick must be a non-negative integer")
        if self.owner != "Godot":
            raise FoodAdmissionError("FoodNeed admission owner must be Godot")
        object.__setattr__(self, "food_need", float(self.food_need))

    def to_json(self) -> dict[str, Any]:
        return {
            "agent_id": self.agent_id,
            "body_snapshot_id": self.body_snapshot_id,
            "body_revision": self.body_revision,
            "food_need": self.food_need,
            "source_observation_id": self.source_observation_id,
            "source_tick": self.source_tick,
            "owner": self.owner,
        }


@dataclass(frozen=True)
class FoodNeedMBRelation:
    agent_id: str
    relation_id: str
    model_ref: str
    boundary: GameAIBoundary
    source: FoodNeedAdmissionSource
    input_dimension: str = FOOD_INPUT_DIMENSION
    output_dimension: str = FOOD_OUTPUT_DIMENSION
    coefficient: float = 0.0
    rule_version: str = FOOD_RULE_VERSION
    provenance: Mapping[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if self.agent_id != self.source.agent_id:
            raise FoodAdmissionError("relation agent must match source agent")
        if self.relation_id != FOOD_RELATION_ID:
            raise FoodAdmissionError("unsupported FoodNeed relation_id")
        if not isinstance(self.model_ref, str) or not self.model_ref:
            raise FoodAdmissionError("model_ref must be non-empty")
        if self.input_dimension != FOOD_INPUT_DIMENSION:
            raise FoodAdmissionError("unsupported FoodNeed input dimension")
        if self.output_dimension != FOOD_OUTPUT_DIMENSION:
            raise FoodAdmissionError("unsupported FoodNeed output dimension")
        if self.input_dimension not in self.boundary.dimensions:
            raise FoodAdmissionError("boundary must select visible_food_count")
        if self.rule_version != FOOD_RULE_VERSION:
            raise FoodAdmissionError("unsupported FoodNeed rule version")
        if type(self.coefficient) not in (int, float) or not math.isfinite(self.coefficient):
            raise FoodAdmissionError("relation coefficient must be finite")
        if float(self.coefficient) != self.source.food_need:
            raise FoodAdmissionError("relation coefficient must equal frozen source FoodNeed")
        object.__setattr__(self, "coefficient", float(self.coefficient))
        object.__setattr__(self, "provenance", MappingProxyType(dict(self.provenance)))

    def to_json(self) -> dict[str, Any]:
        return {
            "agent_id": self.agent_id,
            "relation_id": self.relation_id,
            "model_ref": self.model_ref,
            "boundary": {
                "boundary_id": self.boundary.boundary_id,
                "purpose": self.boundary.purpose,
                "dimensions": list(self.boundary.dimensions),
                "conditions": dict(self.boundary.conditions),
            },
            "source": self.source.to_json(),
            "input_dimension": self.input_dimension,
            "output_dimension": self.output_dimension,
            "coefficient": self.coefficient,
            "rule_version": self.rule_version,
            "provenance": dict(self.provenance),
            "authority": "formation-only-no-registration",
        }


def form_food_need_mb_relation(
    packet: Mapping[str, Any],
    boundary: GameAIBoundary,
) -> FoodNeedMBRelation:
    """Validate one body snapshot and form a deterministic immutable relation."""

    if not isinstance(boundary, GameAIBoundary):
        raise FoodAdmissionError("boundary must be a GameAIBoundary")
    agent_id = packet.get("agent_id")
    observation_id = packet.get("observation_id")
    tick = packet.get("tick")
    observation = packet.get("observation")
    if not isinstance(agent_id, str) or not agent_id:
        raise FoodAdmissionError("agent_id must be a non-empty string")
    if not isinstance(observation_id, str) or not observation_id:
        raise FoodAdmissionError("observation_id is required for FoodNeed admission")
    if type(tick) is not int or tick < 0:
        raise FoodAdmissionError("tick must be a non-negative integer")
    if not isinstance(observation, Mapping):
        raise FoodAdmissionError("observation must be an object")
    body = observation.get("body")
    if not isinstance(body, Mapping):
        raise FoodAdmissionError("observation.body is required for FoodNeed admission")
    if body.get("agent_id") != agent_id:
        raise FoodAdmissionError("body owner must match observed agent")

    source = FoodNeedAdmissionSource(
        agent_id=agent_id,
        body_snapshot_id=body.get("snapshot_id"),
        body_revision=body.get("revision"),
        food_need=body.get("food_need"),
        source_observation_id=observation_id,
        source_tick=tick,
    )
    if FOOD_INPUT_DIMENSION not in boundary.dimensions:
        raise FoodAdmissionError("boundary must select visible_food_count")

    identity = {
        "experiment": "food-need-mb-admission-v1",
        "agent_id": agent_id,
        "boundary": {
            "boundary_id": boundary.boundary_id,
            "purpose": boundary.purpose,
            "dimensions": list(boundary.dimensions),
            "conditions": dict(sorted(boundary.conditions.items())),
        },
        "source": source.to_json(),
        "relation_id": FOOD_RELATION_ID,
        "rule_version": FOOD_RULE_VERSION,
    }
    serialized = json.dumps(identity, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    digest = hashlib.sha256(serialized.encode("utf-8")).hexdigest()[:16]
    return FoodNeedMBRelation(
        agent_id=agent_id,
        relation_id=FOOD_RELATION_ID,
        model_ref=f"gameai-food-mb:{agent_id}:{digest}:v1",
        boundary=boundary,
        source=source,
        coefficient=source.food_need,
        provenance={
            "formation": "validated-food-need-relation",
            "experiment": "food-need-mb-admission-v1",
            "source_snapshot_id": source.body_snapshot_id,
            "rule_version": FOOD_RULE_VERSION,
        },
    )


@dataclass(frozen=True)
class FoodNeedShadowInterpretation:
    section_id: str
    source_observation_id: str
    tick: int
    agent_id: str
    model_ref: str
    values: Mapping[str, float]
    provenance: Mapping[str, str]

    def __post_init__(self) -> None:
        object.__setattr__(self, "values", MappingProxyType(dict(self.values)))
        object.__setattr__(self, "provenance", MappingProxyType(dict(self.provenance)))

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
class FoodNeedShadowMismatch:
    first_section_id: str
    later_section_id: str
    agent_id: str
    model_ref: str
    deltas: Mapping[str, float]
    provenance: Mapping[str, str]

    def __post_init__(self) -> None:
        object.__setattr__(self, "deltas", MappingProxyType(dict(self.deltas)))
        object.__setattr__(self, "provenance", MappingProxyType(dict(self.provenance)))

    def to_json(self) -> dict[str, Any]:
        return {
            "first_section_id": self.first_section_id,
            "later_section_id": self.later_section_id,
            "agent_id": self.agent_id,
            "model_ref": self.model_ref,
            "deltas": dict(self.deltas),
            "provenance": dict(self.provenance),
            "status": "shadow-E-only-not-reviewed",
        }


def interpret_food_need_relation(
    relation: FoodNeedMBRelation,
    section: GameAIRIBSection,
) -> FoodNeedShadowInterpretation:
    """Interpret one food RIB_B section under an already-frozen relation."""

    if section.agent_id != relation.agent_id:
        raise FoodAdmissionError("section agent does not match frozen FoodNeed relation")
    if section.boundary.context_key != relation.boundary.context_key:
        raise FoodAdmissionError("section context does not match frozen FoodNeed relation")
    if relation.input_dimension not in section.values:
        raise FoodAdmissionError("section missing visible_food_count")
    value = relation.coefficient * float(section.values[relation.input_dimension])
    if not math.isfinite(value):
        raise FoodAdmissionError("visible_food_salience must be finite")
    return FoodNeedShadowInterpretation(
        section_id=section.section_id,
        source_observation_id=section.source_observation_id,
        tick=section.tick,
        agent_id=section.agent_id,
        model_ref=relation.model_ref,
        values={relation.output_dimension: value},
        provenance={
            "formation": "interp(frozen-food-need-relation,RIB_B)",
            "relation_id": relation.relation_id,
            "source_snapshot_id": relation.source.body_snapshot_id,
            "rib_section_id": section.section_id,
        },
    )


@dataclass(frozen=True)
class FoodNeedShadowWindow:
    window_id: str
    relation: FoodNeedMBRelation
    first_section: GameAIRIBSection
    first_interpretation: FoodNeedShadowInterpretation
    status: str = "open"
    later_section: GameAIRIBSection | None = None
    later_interpretation: FoodNeedShadowInterpretation | None = None
    mismatch: FoodNeedShadowMismatch | None = None
    next_relation_candidate: FoodNeedMBRelation | None = None
    next_relation_candidate_error: str | None = None
    error: str | None = None

    def to_json(self) -> dict[str, Any]:
        return {
            "window_id": self.window_id,
            "status": self.status,
            "model_ref": self.relation.model_ref,
            "relation": self.relation.to_json(),
            "first_section": self.first_section.to_json(),
            "F": self.first_interpretation.to_json(),
            "later_section": self.later_section.to_json() if self.later_section else None,
            "F_prime": self.later_interpretation.to_json() if self.later_interpretation else None,
            "E": self.mismatch.to_json() if self.mismatch else None,
            "next_relation_candidate": (
                self.next_relation_candidate.to_json() if self.next_relation_candidate else None
            ),
            "next_relation_candidate_error": self.next_relation_candidate_error,
            "error": self.error,
        }


class FoodNeedShadowComparisonSidecar:
    """Explicit one-comparison windows with no bridge or canonical registration."""

    def __init__(self, *, max_windows: int = MAX_SHADOW_WINDOWS) -> None:
        if type(max_windows) is not int or not 1 <= max_windows <= MAX_SHADOW_WINDOWS:
            raise FoodAdmissionError(f"max_windows must be in [1,{MAX_SHADOW_WINDOWS}]")
        self._windows: dict[str, FoodNeedShadowWindow] = {}
        self._max_windows = max_windows
        self._capacity_rejections = 0

    def open_window(self, packet: Mapping[str, Any], boundary: GameAIBoundary) -> str:
        if len(self._windows) >= self._max_windows:
            self._capacity_rejections += 1
            raise FoodAdmissionError("shadow comparison window capacity exhausted")
        relation = form_food_need_mb_relation(packet, boundary)
        try:
            section = acquire_rib_section(packet, boundary=boundary)
        except AcquisitionError as exc:
            raise FoodAdmissionError(str(exc)) from exc
        first = interpret_food_need_relation(relation, section)
        identity = f"{relation.model_ref}:{section.source_observation_id}"
        digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:16]
        window_id = f"food-shadow-window:{relation.agent_id}:{digest}:v1"
        if window_id in self._windows:
            raise FoodAdmissionError("comparison window already exists")
        self._windows[window_id] = FoodNeedShadowWindow(
            window_id=window_id,
            relation=relation,
            first_section=section,
            first_interpretation=first,
        )
        return window_id

    def compare_later(
        self,
        window_id: str,
        packet: Mapping[str, Any],
    ) -> FoodNeedShadowMismatch:
        window = self._windows.get(window_id)
        if window is None:
            raise FoodAdmissionError("unknown comparison window")
        if window.status != "open":
            raise FoodAdmissionError("comparison window is not open")
        try:
            section = acquire_rib_section(packet, boundary=window.relation.boundary)
            if section.source_observation_id == window.first_section.source_observation_id:
                raise FoodAdmissionError("F/F' require distinct observation instances")
            if section.tick < window.first_section.tick:
                raise FoodAdmissionError("later observation tick precedes comparison window")
            later = interpret_food_need_relation(window.relation, section)
            delta = (
                later.values[FOOD_OUTPUT_DIMENSION]
                - window.first_interpretation.values[FOOD_OUTPUT_DIMENSION]
            )
            mismatch = FoodNeedShadowMismatch(
                first_section_id=window.first_section.section_id,
                later_section_id=section.section_id,
                agent_id=window.relation.agent_id,
                model_ref=window.relation.model_ref,
                deltas={FOOD_OUTPUT_DIMENSION: delta},
                provenance={
                    "comparison": "Delta(shadow-F,shadow-F-prime)",
                    "window_id": window_id,
                    "frozen_source_snapshot_id": window.relation.source.body_snapshot_id,
                },
            )
        except (AcquisitionError, FoodAdmissionError) as exc:
            self._windows[window_id] = replace(window, status="rejected", error=str(exc))
            if isinstance(exc, FoodAdmissionError):
                raise
            raise FoodAdmissionError(str(exc)) from exc

        next_candidate = None
        next_candidate_error = None
        observation = packet.get("observation")
        if isinstance(observation, Mapping) and isinstance(observation.get("body"), Mapping):
            try:
                next_candidate = form_food_need_mb_relation(packet, window.relation.boundary)
            except FoodAdmissionError as exc:
                next_candidate_error = str(exc)

        self._windows[window_id] = replace(
            window,
            status="compared",
            later_section=section,
            later_interpretation=later,
            mismatch=mismatch,
            next_relation_candidate=next_candidate,
            next_relation_candidate_error=next_candidate_error,
        )
        return mismatch

    def snapshot(self) -> dict[str, Any]:
        return {
            "authority": "shadow-diagnostic-only",
            "stage": "food-need-frozen-M_B-shadow-F-F_prime-E",
            "max_windows": self._max_windows,
            "capacity_rejections": self._capacity_rejections,
            "windows": {
                window_id: window.to_json()
                for window_id, window in sorted(self._windows.items())
            },
            "not_implemented": [
                "bridge-registration",
                "assessment-H",
                "theta",
                "M_delta",
                "T1",
                "action-authority",
            ],
        }
