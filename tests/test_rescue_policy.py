import copy
import unittest

from runtime.core import ObservationError
from runtime.rescue_policy import RescueTrajectoryPolicy


class RescueTrajectoryPolicyTests(unittest.TestCase):
    def packet(self, observation_id, agents):
        return {
            "observation_id": observation_id,
            "tick": 1,
            "agent_id": "npc_a",
            "observation": {
                "visible_agents": agents,
                "visible_objects": [],
                "visible_places": [],
            },
        }

    def candidate(self, agent_id, within_reach=False):
        return {
            "id": agent_id,
            "condition": "incapacitated",
            "condition_schema": "bounded-visible-agent-condition-v1",
            "within_reach": within_reach,
        }

    def test_commits_once_approaches_and_stops_ready_without_rescue_resolution(self):
        policy = RescueTrajectoryPolicy()
        first = policy.decide(self.packet("r-1", [self.candidate("npc_b"), self.candidate("npc_c")]))
        self.assertEqual(first["action"], {"type": "approach", "target_id": "npc_b"})
        self.assertEqual(first["inspection"]["rescue"]["trajectory_phase"], "APPROACH_INCAPACITATED")

        reordered = policy.decide(self.packet("r-2", [self.candidate("npc_c"), self.candidate("npc_b")]))
        self.assertEqual(reordered["action"]["target_id"], "npc_b")

        ready = policy.decide(self.packet("r-3", [self.candidate("npc_b", True)]))
        self.assertEqual(ready["action"], {"type": "idle"})
        self.assertEqual(ready["inspection"]["rescue"]["trajectory_phase"], "READY_TO_RESCUE")
        self.assertEqual(policy.snapshot()["trajectories"]["npc_a"]["target_id"], "npc_b")

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
        }
        decision = RescueTrajectoryPolicy().decide(packet)
        self.assertEqual(decision["action"], {"type": "idle"})
        self.assertIn("incapacitation", decision["inspection"]["reason"])


if __name__ == "__main__":
    unittest.main()
