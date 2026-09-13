import unittest

from runtime.core import ObservationError, decide_action


class RuntimeCoreTests(unittest.TestCase):
    def test_selects_visible_food_from_bounded_observation(self):
        response = decide_action(
            {
                "tick": 12,
                "agent_id": "npc_a",
                "observation": {
                    "visible_agents": [],
                    "visible_objects": [
                        {
                            "id": "food_01",
                            "kind": "food",
                            "relative_position": [1.0, 0.0],
                        }
                    ],
                    "visible_places": [],
                },
            }
        )

        self.assertEqual(response["agent_id"], "npc_a")
        self.assertEqual(response["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(response["inspection"]["observation_id"], "obs-000012-npc_a")

    def test_hidden_entities_are_not_needed_for_decision(self):
        response = decide_action(
            {
                "tick": 2,
                "agent_id": "npc_b",
                "observation": {
                    "visible_agents": [],
                    "visible_objects": [],
                    "visible_places": [],
                },
            }
        )

        self.assertEqual(response["action"], {"type": "idle"})
        self.assertIn("bounded observation", response["inspection"]["reason"])

    def test_rejects_malformed_observation(self):
        with self.assertRaises(ObservationError):
            decide_action(
                {
                    "tick": 1,
                    "agent_id": "npc_a",
                    "observation": {
                        "visible_agents": [],
                        "visible_objects": "food_01",
                        "visible_places": [],
                    },
                }
            )


if __name__ == "__main__":
    unittest.main()
