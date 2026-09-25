import copy
import unittest

from runtime.risky_tasty_food import RiskyTastyFoodExperiment
from runtime.territory_beast_world import TerritoryBeastFixture, TerritoryBeastWorld
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


def experiment():
    world = TerritoryBeastWorld(TerritoryBeastFixture(
        beast_id="beast_1", territory_id="north_grove",
        beast_position=(0.0, 0.0), territory_center=(0.0, 0.0),
        territory_radius=10.0, attack_distance=2.0,
    ))
    return RiskyTastyFoodExperiment(world)


class RiskyTastyFoodTests(unittest.TestCase):
    def test_observation_separates_food_facts_from_sourced_value_statement(self):
        observed = experiment().observation()
        foods = {item["food_id"]: item for item in observed["foods"]}
        self.assertEqual(set(foods), {"ordinary_food", "tasty_food"})
        self.assertEqual(foods["ordinary_food"]["desirability_fixture"], "NORMAL")
        self.assertEqual(foods["tasty_food"]["desirability_fixture"], "HIGH")
        self.assertTrue(all(
            not any(key in item for key in ("danger", "dangerous", "threat_score"))
            for item in foods.values()
        ))
        statement = observed["external_statements"][0]
        self.assertEqual((statement["source_id"], statement["subject_id"], statement["predicate"]),
                         ("god_statue", "tasty_food", "tasty"))
        self.assertIn("not-World-Truth-M_B-H-or-action", statement["authority"])

    def test_tasty_approach_reuses_warning_chase_attack_and_records_context(self):
        fixture = experiment()
        warning = fixture.approach(
            agent_id="npc_a", food_id="tasty_food", agent_position=(9, 0), tick=1
        )
        chase = fixture.approach(
            agent_id="npc_a", food_id="tasty_food", agent_position=(6, 0), tick=2
        )
        injury = fixture.approach(
            agent_id="npc_a", food_id="tasty_food", agent_position=(1, 0), tick=3
        )
        self.assertEqual([item["event"]["beast_response"] for item in (warning, chase, injury)],
                         ["warning", "chase", "attack"])
        record = injury["experience"]
        self.assertEqual(record["interaction"]["context"], {
            "action": "approach", "food_id": "tasty_food",
            "food_desirability_fixture": "HIGH", "territory_id": "north_grove",
        })
        self.assertEqual(record["world_consequence"]["injury_level"], "medium")
        self.assertTrue(not any(
            key in record["interaction"]["context"]
            for key in ("danger", "dangerous", "threat_score")
        ))

    def test_ordinary_food_does_not_invent_territory_or_canonical_effects(self):
        fixture = experiment()
        canonical = GameAIFrozenComparisonSidecar()
        before = copy.deepcopy(canonical.snapshot())
        result = fixture.approach(
            agent_id="npc_a", food_id="ordinary_food", agent_position=(1, 0), tick=1
        )
        self.assertIsNone(result["event"])
        self.assertEqual(fixture.snapshot()["experience"]["records"], [])
        self.assertEqual(canonical.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
