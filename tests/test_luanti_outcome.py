import copy
import unittest

from runtime.luanti_outcome import LuantiOutcomeCoordinator, LuantiOutcomeError
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


def attack_payload():
    return {
        "event": {
            "event_id": "luanti-territory-000005",
            "schema": "territory-beast-fact-event-v1",
            "tick": 5,
            "agent_id": "npc_a",
            "beast_id": "beast_1",
            "territory_id": "north_grove",
            "event_type": "close_intrusion_persisted",
            "beast_response": "attack",
            "proximity": "close",
            "outcome": "injured",
            "world_consequence": {
                "injury_level": "medium",
                "forced_retreat": True,
                "incapacitated": False,
            },
            "interaction_context": {
                "action": "approach",
                "food_id": "tasty_food",
                "food_desirability_fixture": "HIGH",
                "territory_id": "north_grove",
            },
            "authority": "World-interaction-fact; not-danger-belief-Experience-H-theta-M_delta-or-action",
        },
        "outcome_facts": {
            "food_acquired": False,
            "returned_to_base": False,
            "injury_level": "medium",
            "reward_value": "ZERO",
        },
    }


class LuantiOutcomeTests(unittest.TestCase):
    def test_attack_forms_existing_experience_gradient_and_biases(self):
        result = LuantiOutcomeCoordinator().record(attack_payload())
        self.assertTrue(result["accepted"])
        self.assertEqual(result["experience"]["perspective"], "direct_participant")
        dimensions = {item["relation"]: item for item in result["gradient"]["dimensions"]}
        self.assertEqual(dimensions["injury"]["magnitude_band"], "MEDIUM")
        self.assertEqual(
            {(item["relation"], item["direction"], item["strength"])
             for item in result["biases"]},
            {("acquisition", "negative", "STRONG"),
             ("return", "negative", "MEDIUM"),
             ("injury", "negative", "MEDIUM")},
        )

    def test_exact_replay_is_deterministic_and_does_not_duplicate(self):
        coordinator = LuantiOutcomeCoordinator()
        first = coordinator.record(attack_payload())
        second = coordinator.record(attack_payload())
        self.assertEqual(first, second)
        snapshot = coordinator.snapshot()
        self.assertEqual(len(snapshot["experiences"]["records"]), 1)
        self.assertEqual(snapshot["gradients"]["count"], 1)
        self.assertEqual(snapshot["biases"]["count"], 3)

    def test_interpretive_label_is_rejected(self):
        payload = attack_payload()
        payload["event"]["danger"] = True
        with self.assertRaisesRegex(LuantiOutcomeError, "danger labels"):
            LuantiOutcomeCoordinator().record(payload)

    def test_learning_path_does_not_mutate_canonical_sidecar(self):
        canonical = GameAIFrozenComparisonSidecar()
        before = copy.deepcopy(canonical.snapshot())
        LuantiOutcomeCoordinator().record(attack_payload())
        self.assertEqual(canonical.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
