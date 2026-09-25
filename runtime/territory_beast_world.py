"""Finite World-side Territory Beast fixture without cognition authority."""

from copy import deepcopy
from dataclasses import dataclass
import math
from typing import Any


WORLD_MODEL_ID = "territory-beast-world-v1"
EVENT_SCHEMA = "territory-beast-fact-event-v1"


class TerritoryBeastWorldError(ValueError):
    pass


@dataclass(frozen=True)
class TerritoryBeastFixture:
    beast_id: str
    territory_id: str
    beast_position: tuple[float, float]
    territory_center: tuple[float, float]
    territory_radius: float
    attack_distance: float
    attack_succeeds: bool = True

    def __post_init__(self) -> None:
        if not self.beast_id or not self.territory_id:
            raise TerritoryBeastWorldError("beast and territory IDs must be non-empty")
        for name, point in (("beast_position", self.beast_position),
                            ("territory_center", self.territory_center)):
            if len(point) != 2 or any(type(value) not in (int, float) or not math.isfinite(value)
                                      for value in point):
                raise TerritoryBeastWorldError(f"{name} must be a finite 2D point")
        if (type(self.territory_radius) not in (int, float)
                or not math.isfinite(self.territory_radius) or self.territory_radius <= 0):
            raise TerritoryBeastWorldError("territory_radius must be finite and positive")
        if (type(self.attack_distance) not in (int, float)
                or not math.isfinite(self.attack_distance)
                or not 0 < self.attack_distance < self.territory_radius):
            raise TerritoryBeastWorldError("attack_distance must be inside the territory radius")


class TerritoryBeastWorld:
    """Resolve geometry and emit bounded facts; never infer danger or meaning."""

    def __init__(self, fixture: TerritoryBeastFixture, capacity: int = 128) -> None:
        if type(capacity) is not int or capacity <= 0:
            raise TerritoryBeastWorldError("capacity must be a positive integer")
        self.fixture = fixture
        self.capacity = capacity
        self._relations: dict[str, dict[str, Any]] = {}
        self._events: list[dict[str, Any]] = []
        self.capacity_rejections = 0

    def resolve(self, *, agent_id: str, agent_position: tuple[float, float],
                tick: int) -> dict[str, Any]:
        if not isinstance(agent_id, str) or not agent_id:
            raise TerritoryBeastWorldError("agent_id must be non-empty")
        if type(tick) is not int or tick < 0:
            raise TerritoryBeastWorldError("tick must be a non-negative integer")
        position = _point(agent_position)
        existing = self._relations.get(agent_id)
        if existing is None and len(self._relations) >= self.capacity:
            self.capacity_rejections += 1
            raise TerritoryBeastWorldError("territory relation capacity reached")

        center_distance = _distance(position, self.fixture.territory_center)
        beast_distance = _distance(position, self.fixture.beast_position)
        inside = center_distance <= self.fixture.territory_radius
        previous_steps = existing["intrusion_steps"] if existing else 0
        intrusion_steps = previous_steps + 1 if inside else 0

        if not inside:
            event_type, response, outcome = "outside_territory", "ignore", None
        elif intrusion_steps == 1:
            event_type, response, outcome = "territory_entered", "warning", "warning_observed"
        elif intrusion_steps == 2:
            event_type, response, outcome = "intrusion_continued", "chase", "chased"
        elif beast_distance <= self.fixture.attack_distance:
            event_type, response = "close_intrusion_persisted", "attack"
            outcome = "injured" if self.fixture.attack_succeeds else "attack_evaded"
        else:
            event_type, response, outcome = "intrusion_continued", "chase", "chased"

        relation = {
            "agent_id": agent_id,
            "beast_id": self.fixture.beast_id,
            "territory_id": self.fixture.territory_id,
            "inside_territory": inside,
            "intrusion_steps": intrusion_steps,
            "last_tick": tick,
            "last_response": response,
        }
        event = {
            "event_id": f"{self.fixture.beast_id}:{agent_id}:{tick}:{len(self._events)}",
            "schema": EVENT_SCHEMA,
            "tick": tick,
            "agent_id": agent_id,
            "beast_id": self.fixture.beast_id,
            "territory_id": self.fixture.territory_id,
            "event_type": event_type,
            "beast_response": response,
            "proximity": "close" if beast_distance <= self.fixture.attack_distance
                         else "within_territory" if inside else "outside",
            "outcome": outcome,
            "world_consequence": ({
                "injury_level": "medium",
                "forced_retreat": True,
                "incapacitated": False,
            } if outcome == "injured" else None),
            "authority": "World-interaction-fact; not-danger-belief-Experience-H-theta-M_delta-or-action",
        }
        self._relations[agent_id] = relation
        self._events.append(event)
        return deepcopy(event)

    def snapshot(self) -> dict[str, Any]:
        return {
            "world_model": WORLD_MODEL_ID,
            "fixture": {
                "beast_id": self.fixture.beast_id,
                "territory_id": self.fixture.territory_id,
                "beast_position": list(self.fixture.beast_position),
                "territory_center": list(self.fixture.territory_center),
                "territory_radius": self.fixture.territory_radius,
                "attack_distance": self.fixture.attack_distance,
            },
            "relations": deepcopy(list(self._relations.values())),
            "events": deepcopy(self._events),
            "capacity": self.capacity,
            "capacity_rejections": self.capacity_rejections,
            "authority": "finite-World-fixture; not-NPC-interpretation-or-canonical-authority",
        }


def _point(value: tuple[float, float]) -> tuple[float, float]:
    if (not isinstance(value, (tuple, list)) or len(value) != 2
            or any(type(item) not in (int, float) or not math.isfinite(item) for item in value)):
        raise TerritoryBeastWorldError("agent_position must be a finite 2D point")
    return float(value[0]), float(value[1])


def _distance(left: tuple[float, float], right: tuple[float, float]) -> float:
    return math.hypot(left[0] - right[0], left[1] - right[1])
