import copy
import unittest

from runtime.core import ObservationError
from runtime.rescue_policy import RescueTrajectoryPolicy


class RescueTrajectoryPolicyTests(unittest.TestCase):
    def packet(self, observation_id, agents, *, carried="", delivery=None, places=None):
        return {
            "observation_id": observation_id,
            "tick": 1,
            "agent_id": "npc_a",
            "observation": {
                "visible_agents": agents,
                "visible_objects": [],
                "visible_places": places or [],
                "body": {
                    "agent_id": "npc_a", "snapshot_id": observation_id, "revision": 1,
                    "movement_scale": 1.0, "injury_level": "none", "incapacitated": False,
                    "food_actions_enabled": False, "held_food_ids": [],
                    "carried_agent_id": carried,
                    "last_rescue_delivery": delivery or {},
                },
            },
        }

    def candidate(self, agent_id, within_reach=False):
        return {
            "id": agent_id,
            "condition": "incapacitated",
            "condition_schema": "bounded-visible-agent-condition-v1",
            "within_reach": within_reach,
        }

    def safe_place(self, within_reach=False):
        return {
            "id": "plaza", "rest_capable": True, "rest_safety": "safe",
            "rescue_within_reach": within_reach, "rescue_distance_band": "within_reach" if within_reach else "far",
        }

    def test_commits_carries_delivers_and_completes_from_world_record(self):
        policy = RescueTrajectoryPolicy()
        first = policy.decide(self.packet(
            "r-1", [self.candidate("npc_b"), self.candidate("npc_c")], places=[self.safe_place()]
        ))
        self.assertEqual(first["action"], {"type": "approach", "target_id": "npc_b"})
        self.assertEqual(first["inspection"]["rescue"]["trajectory_phase"], "APPROACH_INCAPACITATED")

        reordered = policy.decide(self.packet(
            "r-2", [self.candidate("npc_c"), self.candidate("npc_b")], places=[self.safe_place()]
        ))
        self.assertEqual(reordered["action"]["target_id"], "npc_b")

        ready = policy.decide(self.packet(
            "r-3", [self.candidate("npc_b", True)], places=[self.safe_place()]
        ))
        self.assertEqual(ready["action"], {"type": "rescue", "target_id": "npc_b"})
        self.assertEqual(ready["inspection"]["rescue"]["trajectory_phase"], "READY_TO_RESCUE")

        carrying = policy.decide(self.packet(
            "r-4", [self.candidate("npc_b", True)], carried="npc_b", places=[self.safe_place()]
        ))
        self.assertEqual(carrying["action"], {"type": "approach", "target_id": "plaza"})
        self.assertEqual(carrying["inspection"]["rescue"]["trajectory_phase"], "CARRY_TO_SAFE")

        deliver = policy.decide(self.packet(
            "r-5", [self.candidate("npc_b", True)], carried="npc_b", places=[self.safe_place(True)]
        ))
        self.assertEqual(deliver["action"], {"type": "deliver", "target_id": "plaza"})

        complete = policy.decide(self.packet(
            "r-6", [self.candidate("npc_b", True)],
            delivery={"agent_id": "npc_b", "place_id": "plaza", "tick": 1},
            places=[self.safe_place(True)],
        ))
        self.assertEqual(complete["action"], {"type": "idle"})
        self.assertEqual(complete["inspection"]["rescue"]["trajectory_phase"], "COMPLETE")
        self.assertEqual(policy.snapshot()["trajectories"], {})

    def test_target_disappearance_releases_and_replay_is_frozen(self):
        policy = RescueTrajectoryPolicy()
        packet = self.packet("r-1", [self.candidate("npc_b")])
        original = policy.decide(packet)
        self.assertEqual(policy.decide(copy.deepcopy(packet)), original)
        changed = copy.deepcopy(packet)
        changed["tick"] = 2
        with self.assertRaises(ObservationError):
            policy.decide(changed)

        released = policy.decide(self.packet("r-2", []))
        self.assertEqual(released["action"], {"type": "idle"})
        self.assertEqual(released["inspection"]["rescue"]["trajectory_phase"], "RELEASED")
        self.assertEqual(policy.snapshot()["trajectories"], {})

    def test_rescuer_body_constraint_remains_authoritative(self):
        packet = self.packet("r-body", [self.candidate("npc_b")])
        packet["observation"]["body"] = {
            "agent_id": "npc_a", "snapshot_id": "body-a-1", "revision": 1,
            "movement_scale": 0.0, "injury_level": "severe", "incapacitated": True,
            "food_actions_enabled": False, "held_food_ids": [],
            "carried_agent_id": "", "last_rescue_delivery": {},
        }
        decision = RescueTrajectoryPolicy().decide(packet)
        self.assertEqual(decision["action"], {"type": "idle"})
        self.assertIn("incapacitation", decision["inspection"]["reason"])


if __name__ == "__main__":
    unittest.main()
