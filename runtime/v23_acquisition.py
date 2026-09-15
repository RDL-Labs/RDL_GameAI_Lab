"""Read-only Core v2.3 acquisition layer for bounded GameAI observations.

This module forms finite RIB_B sections only. Higher layers may interpret those
sections, but acquisition itself does not create M_B, F/F', E, H, M_delta, or T1.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Mapping

DEFAULT_PURPOSE = "bounded-action-context"
DEFAULT_DIMENSIONS = (
    "visible_agents_count",
    "visible_objects_count",
    "visible_places_count",
)
XI_STATUS = "unrecovered-relations-remain"


class AcquisitionError(ValueError):
    """Raised when a bounded observation cannot form the declared finite section."""


@dataclass(frozen=True)
class GameAIBoundary:
    boundary_id: str
    purpose: str
    dimensions: tuple[str, ...]
    conditions: Mapping[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.boundary_id:
            raise AcquisitionError("boundary_id must be non-empty")
        if not self.purpose:
            raise AcquisitionError("purpose must be non-empty")
        if not self.dimensions:
            raise AcquisitionError("dimensions must be non-empty")
        if len(set(self.dimensions)) != len(self.dimensions):
            raise AcquisitionError("dimensions must be unique")
        unknown = set(self.dimensions) - set(DEFAULT_DIMENSIONS)
        if unknown:
            raise AcquisitionError(f"unsupported dimensions: {sorted(unknown)}")

    @property
    def context_key(self) -> tuple[Any, ...]:
        return (
            self.boundary_id,
            self.purpose,
            self.dimensions,
            tuple(sorted((str(k), str(v)) for k, v in self.conditions.items())),
        )


@dataclass(frozen=True)
class GameAIRIBSection:
    section_id: str
    source_observation_id: str
    tick: int
    agent_id: str
    boundary: GameAIBoundary
    values: Mapping[str, float]
    coverage: tuple[str, ...]
    provenance: Mapping[str, str]
    xi_status: str = XI_STATUS

    @property
    def context_key(self) -> tuple[Any, ...]:
        return (self.agent_id,) + self.boundary.context_key

    def to_json(self) -> dict[str, Any]:
        return {
            "section_id": self.section_id,
            "source_observation_id": self.source_observation_id,
            "tick": self.tick,
            "agent_id": self.agent_id,
            "boundary": {
                "boundary_id": self.boundary.boundary_id,
                "purpose": self.boundary.purpose,
                "dimensions": list(self.boundary.dimensions),
                "conditions": dict(self.boundary.conditions),
            },
            "values": dict(self.values),
            "coverage": list(self.coverage),
            "provenance": dict(self.provenance),
            "xi_status": self.xi_status,
        }


def boundary_for_packet(
    packet: Mapping[str, Any],
    *,
    purpose: str = DEFAULT_PURPOSE,
    dimensions: tuple[str, ...] = DEFAULT_DIMENSIONS,
) -> GameAIBoundary:
    agent_id = packet.get("agent_id")
    observation = packet.get("observation")
    if not isinstance(agent_id, str) or not agent_id:
        raise AcquisitionError("agent_id must be a non-empty string")
    if not isinstance(observation, Mapping):
        raise AcquisitionError("observation must be an object")

    perception_rule = observation.get("perception_rule", "unspecified")
    if perception_rule is None:
        perception_rule = "unspecified"

    return GameAIBoundary(
        boundary_id=f"gameai:{agent_id}:bounded-observation",
        purpose=purpose,
        dimensions=dimensions,
        conditions={
            "packet_schema": "bounded-observation-v1",
            "perception_rule": str(perception_rule),
        },
    )


def acquire_rib_section(
    packet: Mapping[str, Any],
    *,
    boundary: GameAIBoundary | None = None,
) -> GameAIRIBSection:
    tick = packet.get("tick")
    agent_id = packet.get("agent_id")
    observation = packet.get("observation")

    if not isinstance(tick, int) or tick < 0:
        raise AcquisitionError("tick must be a non-negative integer")
    if not isinstance(agent_id, str) or not agent_id:
        raise AcquisitionError("agent_id must be a non-empty string")
    if not isinstance(observation, Mapping):
        raise AcquisitionError("observation must be an object")

    boundary = boundary or boundary_for_packet(packet)
    value_sources = {
        "visible_agents_count": "visible_agents",
        "visible_objects_count": "visible_objects",
        "visible_places_count": "visible_places",
    }

    values: dict[str, float] = {}
    coverage: list[str] = []
    for dimension in boundary.dimensions:
        source_key = value_sources[dimension]
        source_value = observation.get(source_key)
        if not isinstance(source_value, list):
            raise AcquisitionError(
                f"observation.{source_key} must be a list to form {dimension}; "
                "missing coverage is not converted to zero"
            )
        values[dimension] = float(len(source_value))
        coverage.append(dimension)

    observation_id = packet.get("observation_id")
    if not isinstance(observation_id, str) or not observation_id:
        observation_id = f"obs-{tick:06d}-{agent_id}"

    section_id = f"rib-{observation_id}-{boundary.boundary_id}"
    return GameAIRIBSection(
        section_id=section_id,
        source_observation_id=observation_id,
        tick=tick,
        agent_id=agent_id,
        boundary=boundary,
        values=values,
        coverage=tuple(coverage),
        provenance={
            "source": "accepted-bounded-observation-packet",
            "observation_id": observation_id,
            "adapter": "gameai-v23-acquisition-v1",
        },
    )


class GameAICanonicalAcquisitionSidecar:
    """Read-only diagnostic sidecar that records finite RIB_B sections."""

    def __init__(self) -> None:
        self._latest_by_agent: dict[str, GameAIRIBSection] = {}
        self._captures = 0
        self._failures: list[dict[str, str]] = []

    def capture(self, packet: Mapping[str, Any]) -> GameAIRIBSection | None:
        try:
            section = acquire_rib_section(packet)
        except AcquisitionError as exc:
            self._failures.append(
                {
                    "observation_id": str(packet.get("observation_id", "")),
                    "error": str(exc),
                }
            )
            return None

        self._latest_by_agent[section.agent_id] = section
        self._captures += 1
        return section

    def snapshot(self) -> dict[str, Any]:
        return {
            "authority": "read-only-acquisition-sidecar",
            "stage": "RIB_B-acquisition-only",
            "captures": self._captures,
            "latest_by_agent": {
                agent_id: section.to_json()
                for agent_id, section in sorted(self._latest_by_agent.items())
            },
            "failures": list(self._failures),
            "not_implemented": ["M_B", "F", "F_prime", "E", "H", "M_delta", "T1"],
            "xi_status": XI_STATUS,
        }
