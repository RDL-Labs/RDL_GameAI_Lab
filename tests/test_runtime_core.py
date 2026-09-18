import unittest
from copy import deepcopy

from runtime.core import ObservationError, decide_action


class RuntimeCoreTests(unittest.TestCase):
    def rest_packet(self, *, within_reach=False, rest_need=0.8):
        return {
            "observation_id": "rest-state",
            "tick": 4,
            "agent_id": "npc_a",
            "observation": {
                "visible_agents": [],
                "visible_objects": [],
                "visible_places": [{
                    "id": "plaza", "rest_capable": True,
                    "rest_safety": "safe", "within_reach": within_reach,
                }],
                "body": {
                    "agent_id": "npc_a", "snapshot_id": "body-rest-1",
                    "revision": 1, "movement_scale": 1.0,
                    "food_actions_enabled": False,
                    "rest_actions_enabled": True, "rest_need": rest_need,
                    "held_food_ids": [],
                },
            },
        }

    def test_rest_actions_progress_from_approach_to_short_rest(self):
        approach = decide_action(self.rest_packet())
        rest = decide_action(self.rest_packet(within_reach=True))
        wait = decide_action(self.rest_packet(within_reach=True, rest_need=0.2))
        self.assertEqual(approach["action"], {"type": "approach", "target_id": "plaza"})
        self.assertEqual(rest["action"], {"type": "rest", "target_id": "plaza"})
        self.assertEqual(rest["inspection"]["expression"]["label"], "recovering")
        self.assertEqual(wait["action"], {"type": "idle"})

    def test_rest_state_rejects_invalid_need_and_food_coactivation(self):
        for field, value in (("rest_need", -0.1), ("rest_need", 1.1),
                             ("rest_actions_enabled", "yes"),
                             ("food_actions_enabled", True)):
            with self.subTest(field=field, value=value):
                packet = self.rest_packet()
                packet["observation"]["body"][field] = value
                with self.assertRaises(ObservationError):
                    decide_action(packet)

        for field in ("rest_capable", "within_reach"):
            with self.subTest(place_field=field):
                packet = self.rest_packet()
                packet["observation"]["visible_places"][0][field] = "yes"
                with self.assertRaises(ObservationError):
                    decide_action(packet)

    def test_observation_resolution_sidecar_does_not_change_action(self):
        packet = {
            "observation_id": "rho-non-intervention",
            "tick": 0,
            "agent_id": "npc_a",
            "observation": {
                "visible_agents": [],
                "visible_objects": [{"id": "food_01", "kind": "food"}],
                "visible_places": [],
            },
        }
        enriched = deepcopy(packet)
        enriched["observation"]["observation_resolution"] = {
            "schema_version": "rho-observation-resolution-packet-v1",
            "domains": {"food": {
                "level": "LOW",
                "distinctions": {"supply_status": "needs_supply"},
                "selection": {"selection_profile_version": "rho-profile-selection-v1"},
            }},
        }

        self.assertEqual(decide_action(packet), decide_action(enriched))

    def food_packet(self, *, within_reach=False, held=None, food_need=0.8):
        return {
            "observation_id": "food-state",
            "tick": 4,
            "agent_id": "npc_a",
            "observation": {
                "visible_agents": [],
                "visible_objects": [{
                    "id": "food_01", "kind": "food",
                    "within_reach": within_reach,
                }],
                "visible_places": [],
                "body": {
                    "agent_id": "npc_a", "snapshot_id": "body-food-1",
                    "revision": 1, "movement_scale": 1.0,
                    "food_actions_enabled": True, "food_need": food_need,
                    "held_food_ids": list(held or []),
                },
            },
        }

    def test_selects_visible_food_from_bounded_observation(self):
        response = decide_action(
            {
                "observation_id": "obs-000012-001-npc_a",
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
        self.assertEqual(response["inspection"]["observation_id"], "obs-000012-001-npc_a")

    def test_falls_back_to_legacy_observation_id(self):
        response = decide_action(
            {
                "tick": 12,
                "agent_id": "npc_a",
                "observation": {
                    "visible_agents": [],
                    "visible_objects": [],
                    "visible_places": [],
                },
            }
        )

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

    def test_food_actions_progress_from_approach_to_pickup_to_eat(self):
        approach = decide_action(self.food_packet())
        pickup = decide_action(self.food_packet(within_reach=True))
        eat = decide_action(self.food_packet(within_reach=True, held=["food_01"]))
        self.assertEqual(approach["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(pickup["action"], {"type": "pickup", "target_id": "food_01"})
        self.assertEqual(eat["action"], {"type": "eat", "target_id": "food_01"})
        self.assertEqual(pickup["inspection"]["expression"]["label"], "acquiring")
        self.assertEqual(eat["inspection"]["expression"]["label"], "feeding")

    def test_food_actions_wait_below_finite_need_threshold(self):
        response = decide_action(self.food_packet(within_reach=True, food_need=0.2))
        self.assertEqual(response["action"], {"type": "idle"})

    def test_rejects_invalid_bounded_food_state(self):
        cases = [
            ("food_actions_enabled", "yes"),
            ("food_need", -0.1),
            ("food_need", 1.1),
            ("held_food_ids", "food_01"),
            ("held_food_ids", ["food_01", "food_01"]),
        ]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                packet = self.food_packet()
                packet["observation"]["body"][field] = value
                with self.assertRaises(ObservationError):
                    decide_action(packet)


if __name__ == "__main__":
    unittest.main()
