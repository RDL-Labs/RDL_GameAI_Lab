"""Finite Risky Tasty Food reference fixture without action authority."""

from copy import deepcopy
from typing import Any

from .territory_beast_world import TerritoryBeastWorld
from .territory_experience import TerritoryExperienceStore


FIXTURE_ID = "risky-tasty-food-reference-v1"
STATEMENT_SCHEMA = "external-value-statement-v1"


class RiskyTastyFoodError(ValueError):
    pass


class RiskyTastyFoodExperiment:
    """Join physical Food facts, one sourced statement, and Territory outcomes."""

    def __init__(self, territory_world: TerritoryBeastWorld,
                 experience: TerritoryExperienceStore | None = None) -> None:
        self.territory_world = territory_world
        self.experience = experience or TerritoryExperienceStore()
        territory_id = territory_world.fixture.territory_id
        self._foods = {
            "ordinary_food": {
                "food_id": "ordinary_food", "kind": "food",
                "desirability_fixture": "NORMAL", "territory_id": None,
                "authority": "World-physical-Food-fixture; not-value-belief-or-danger-meaning",
            },
            "tasty_food": {
                "food_id": "tasty_food", "kind": "food",
                "desirability_fixture": "HIGH", "territory_id": territory_id,
                "authority": "World-physical-Food-fixture; not-value-belief-or-danger-meaning",
            },
        }
        self._statement = {
            "statement_id": "god-statue-tasty-food-v1",
            "schema": STATEMENT_SCHEMA,
            "source_type": "external_statement",
            "source_id": "god_statue",
            "subject_id": "tasty_food",
            "predicate": "tasty",
            "polarity": "positive",
            "value_band": "HIGH",
            "authority": "source-attributed-information; not-World-Truth-M_B-H-or-action",
        }

    def observation(self) -> dict[str, Any]:
        return {
            "fixture": FIXTURE_ID,
            "foods": deepcopy(list(self._foods.values())),
            "external_statements": [deepcopy(self._statement)],
            "authority": "read-only-reference-observation; not-action-or-canonical-authority",
        }

    def approach(self, *, agent_id: str, food_id: str,
                 agent_position: tuple[float, float], tick: int) -> dict[str, Any]:
        if food_id not in self._foods:
            raise RiskyTastyFoodError("unknown food_id")
        food = self._foods[food_id]
        if food["territory_id"] is None:
            return {
                "food_id": food_id, "event": None, "experience": None,
                "authority": "ordinary-Food-approach; no-Territory-event",
            }
        event = self.territory_world.resolve(
            agent_id=agent_id, agent_position=agent_position, tick=tick
        )
        event["interaction_context"] = {
            "action": "approach",
            "food_id": food_id,
            "food_desirability_fixture": food["desirability_fixture"],
            "territory_id": food["territory_id"],
        }
        experience = self.experience.record_direct(event)
        return {"food_id": food_id, "event": event, "experience": experience}

    def snapshot(self) -> dict[str, Any]:
        return {
            "fixture": FIXTURE_ID,
            "observation": self.observation(),
            "territory": self.territory_world.snapshot(),
            "experience": self.experience.snapshot(),
            "not_implemented": ["preference", "trust", "expected_utility",
                                "M_B_action_authority", "canonical_admission"],
        }
