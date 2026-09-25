import copy
import unittest

from runtime.outcome_bias import LocalBiasStore, OutcomeGradientStore
from runtime.risky_tasty_food import RiskyTastyFoodExperiment
from runtime.territory_beast_world import TerritoryBeastFixture, TerritoryBeastWorld
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


def source(agent_id="npc_a", injury=False):
    fixture = RiskyTastyFoodExperiment(TerritoryBeastWorld(TerritoryBeastFixture(
        beast_id="beast_1", territory_id="north_grove",
        beast_position=(0, 0), territory_center=(0, 0),
        territory_radius=10, attack_distance=2,
    )))
    positions = [(9, 0), (6, 0), (1, 0)] if injury else [(9, 0)]
    result = None
    for tick, position in enumerate(positions, 1):
        result = fixture.approach(
            agent_id=agent_id, food_id="tasty_food", agent_position=position, tick=tick
        )
    return result["experience"]


class OutcomeBiasTests(unittest.TestCase):
    def test_strong_success_forms_relation_specific_positive_biases(self):
        gradient = OutcomeGradientStore().form(source(), {
            "food_acquired": True, "returned_to_base": True,
            "injury_level": "none", "reward_value": "HIGH",
        })
        dimensions = {item["relation"]: item for item in gradient["dimensions"]}
        self.assertEqual(dimensions["injury"]["magnitude_band"], "ZERO")
        biases = LocalBiasStore().form(gradient)
        self.assertEqual(
            {(item["relation"], item["direction"], item["strength"]) for item in biases},
            {("acquisition", "positive", "STRONG"),
             ("return", "positive", "STRONG"),
             ("reward_value", "positive", "STRONG")},
        )

    def test_strong_failure_forms_negative_bias_without_reward_scalar(self):
        gradient = OutcomeGradientStore().form(source(injury=True), {
            "food_acquired": False, "returned_to_base": False,
            "injury_level": "severe", "reward_value": "ZERO",
        })
        biases = LocalBiasStore().form(gradient)
        by_relation = {item["relation"]: item for item in biases}
        self.assertEqual((by_relation["acquisition"]["direction"],
                          by_relation["acquisition"]["strength"]), ("negative", "STRONG"))
        self.assertEqual((by_relation["injury"]["direction"],
                          by_relation["injury"]["strength"]), ("negative", "STRONG"))
        self.assertNotIn("net_score", gradient)

    def test_mixed_outcome_preserves_positive_and_negative_biases(self):
        gradient = OutcomeGradientStore().form(source(injury=True), {
            "food_acquired": True, "returned_to_base": True,
            "injury_level": "severe", "reward_value": "HIGH",
        })
        biases = LocalBiasStore().form(gradient)
        directions = {(item["relation"], item["direction"]) for item in biases}
        self.assertIn(("reward_value", "positive"), directions)
        self.assertIn(("injury", "negative"), directions)
        self.assertTrue(all(item["strength"] == "STRONG" for item in biases))

    def test_multi_agent_provenance_and_sleep_projection_remain_separate(self):
        gradients = OutcomeGradientStore()
        biases = LocalBiasStore()
        for agent_id, injury in (("npc_a", False), ("npc_b", True)):
            gradient = gradients.form(source(agent_id, injury), {
                "food_acquired": not injury, "returned_to_base": not injury,
                "injury_level": "severe" if injury else "none",
                "reward_value": "ZERO" if injury else "HIGH",
            })
            formed = biases.form(gradient)
            self.assertTrue(all(item["agent_id"] == agent_id for item in formed))
        a = biases.sleep_projection("npc_a")
        b = biases.sleep_projection("npc_b")
        self.assertTrue(all(item["agent_id"] == "npc_a" for item in a["local_bias_materials"]))
        self.assertTrue(all(item["agent_id"] == "npc_b" for item in b["local_bias_materials"]))
        self.assertIn("not-profile-candidate", a["authority"])

    def test_replay_capacity_and_canonical_non_intervention(self):
        canonical = GameAIFrozenComparisonSidecar()
        before = copy.deepcopy(canonical.snapshot())
        gradients = OutcomeGradientStore(capacity=1)
        experience = source()
        facts = {"food_acquired": True, "returned_to_base": True,
                 "injury_level": "none", "reward_value": "HIGH"}
        first = gradients.form(experience, facts)
        self.assertEqual(gradients.form(experience, facts), first)
        rejected = gradients.form(source("npc_b"), facts)
        self.assertIsNone(rejected)
        self.assertEqual(gradients.snapshot()["capacity_rejections"], 1)
        self.assertEqual(canonical.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
