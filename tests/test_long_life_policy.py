import unittest

from runtime.core import ObservationError
from runtime.long_life_policy import FoodSafetySleepCoordinator


def packet(*, sleep=False, food_safety=False):
    return {
        "observation_id": f"mode-{sleep}-{food_safety}", "tick": 1, "agent_id": "npc_a",
        "observation": {
            "visible_agents": [], "visible_objects": [], "visible_places": [],
            "body": {
                "agent_id": "npc_a", "snapshot_id": "body-1", "revision": 1,
                "movement_scale": 1.0, "food_need": 0.2, "held_food_ids": [],
                "rest_actions_enabled": sleep, "sleep_actions_enabled": sleep,
                "sleep_window": sleep, "rest_need": 0.9,
                "food_safety_integration_enabled": food_safety,
            },
            "life_context": {"interrupt_candidates": []},
            "safety_context": {
                "exposed": False, "safe_reached": False,
                "reached_safe_target_id": "", "safe_targets": [],
            },
        },
    }


class LongLifePolicyTests(unittest.TestCase):
    def test_explicit_sleep_mode_uses_shared_local_action_policy(self):
        policy = FoodSafetySleepCoordinator()
        observed = packet(sleep=True)
        observed["observation"]["visible_places"] = [{
            "id": "plaza", "rest_capable": True, "rest_safety": "safe",
            "within_reach": True,
        }]
        decision = policy.decide(observed)
        self.assertEqual(decision["action"], {"type": "sleep", "target_id": "plaza"})
        self.assertEqual(decision["inspection"]["long_life"]["mode"], "SLEEP")

    def test_missing_or_overlapping_modes_are_rejected(self):
        policy = FoodSafetySleepCoordinator()
        for observed in (packet(), packet(sleep=True, food_safety=True)):
            with self.subTest(body=observed["observation"]["body"]):
                with self.assertRaisesRegex(ObservationError, "exactly one"):
                    policy.decide(observed)


if __name__ == "__main__":
    unittest.main()
