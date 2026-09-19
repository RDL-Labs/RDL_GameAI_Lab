import copy
import unittest

from runtime.core import ObservationError
from runtime.food_rest_policy import FoodRestCoordinator


class FoodRestCoordinatorTests(unittest.TestCase):
    def packet(self, observation_id, *, rest_need=0.2, held=None, at_base=False,
               food_within=False, hut_within=False):
        return {
            "observation_id": observation_id,
            "tick": 1,
            "agent_id": "npc_a",
            "observation": {
                "visible_agents": [],
                "visible_objects": [{
                    "id": "food_01", "kind": "food", "within_reach": food_within,
                }],
                "visible_places": [
                    {
                        "id": "plaza", "rest_capable": True, "rest_safety": "safe",
                        "within_reach": at_base,
                        "rest_distance_band": "within_reach" if at_base else "far",
                    },
                    {
                        "id": "rest_hut", "rest_capable": True, "rest_safety": "safe",
                        "within_reach": hut_within,
                        "rest_distance_band": "within_reach" if hut_within else "near",
                    },
                ],
                "body": {
                    "agent_id": "npc_a", "snapshot_id": observation_id, "revision": 1,
                    "movement_scale": 1.0, "food_actions_enabled": True,
                    "rest_actions_enabled": True, "food_rest_integration_enabled": True,
                    "food_need": 0.8, "rest_need": rest_need,
                    "held_food_ids": list(held or []),
                },
                "life_context": {
                    "god_statue_cue": {
                        "source": "system_assessment", "topic": "base_food", "band": "low",
                        "delivery": "morning", "cue_id": "cue-1",
                    },
                    "observed_base_food_band": "low",
                    "known_base": {"id": "plaza"},
                    "at_base": at_base,
                    "interrupt_candidates": [],
                },
            },
        }

    def test_rest_preempts_retained_food_then_current_packet_resumes(self):
        policy = FoodRestCoordinator()
        food = policy.decide(self.packet("fr-1"))
        self.assertEqual(food["action"], {"type": "approach", "target_id": "food_01"})

        rest = policy.decide(self.packet("fr-2", rest_need=0.9, held=["food_01"]))
        self.assertEqual(rest["action"], {"type": "approach", "target_id": "rest_hut"})
        self.assertEqual(rest["inspection"]["food_rest"]["phase"], "FOOD_SUSPENDED")
        self.assertIn("npc_a", policy.snapshot()["food"]["trajectories"])

        at_hut = policy.decide(self.packet(
            "fr-3", rest_need=0.9, held=["food_01"], hut_within=True
        ))
        self.assertEqual(at_hut["action"], {"type": "rest", "target_id": "rest_hut"})

        resumed = policy.decide(self.packet(
            "fr-4", rest_need=0.3, held=["food_01"], hut_within=True
        ))
        self.assertEqual(resumed["action"], {"type": "approach", "target_id": "plaza"})
        self.assertEqual(resumed["inspection"]["food_rest"]["phase"], "RESUME")
        self.assertEqual(policy.snapshot()["rest"]["trajectories"], {})

    def test_requires_explicit_integration_and_frozen_replay(self):
        policy = FoodRestCoordinator()
        packet = self.packet("fr-1")
        missing = copy.deepcopy(packet)
        del missing["observation"]["body"]["food_rest_integration_enabled"]
        with self.assertRaises(ObservationError):
            policy.decide(missing)
        self.assertEqual(policy.decide(packet), policy.decide(copy.deepcopy(packet)))


if __name__ == "__main__":
    unittest.main()
