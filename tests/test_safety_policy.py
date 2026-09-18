import copy
import unittest

from runtime.core import ObservationError
from runtime.safety_policy import SafetyTrajectoryPolicy


class SafetyTrajectoryPolicyTests(unittest.TestCase):
    def packet(self, observation_id, *, exposed, reached=False, target="plaza"):
        return {
            "observation_id": observation_id, "tick": 1, "agent_id": "npc_b",
            "observation": {
                "visible_agents": [], "visible_objects": [],
                "visible_places": [{"id": target}] if target else [],
                "safety_context": {
                    "schema_version": "bounded-safety-context-v1",
                    "exposed": exposed,
                    "danger_id": "danger_gully" if exposed else "",
                    "safe_target_id": target,
                    "safe_reached": reached,
                },
                "body": {
                    "agent_id": "npc_b", "snapshot_id": "body-safety-1",
                    "revision": 1, "movement_scale": 1.0,
                    "food_actions_enabled": False, "safety_actions_enabled": True,
                    "held_food_ids": [],
                },
            },
        }

    def test_escape_persists_after_danger_exit_until_safe_target(self):
        policy = SafetyTrajectoryPolicy()
        formed = policy.decide(self.packet("safe-1", exposed=True))
        outside = policy.decide(self.packet("safe-2", exposed=False))
        complete = policy.decide(self.packet("safe-3", exposed=False, reached=True))
        self.assertEqual(formed["action"], {"type": "flee", "target_id": "plaza"})
        self.assertEqual(outside["action"], {"type": "flee", "target_id": "plaza"})
        self.assertEqual(outside["inspection"]["safety"]["trajectory_phase"], "FLEE_TO_SAFE")
        self.assertEqual(complete["action"], {"type": "idle"})
        self.assertEqual(complete["inspection"]["safety"]["trajectory_phase"], "COMPLETE")
        self.assertEqual(policy.snapshot()["trajectories"], {})

    def test_missing_target_releases_and_replay_is_frozen(self):
        policy = SafetyTrajectoryPolicy()
        first_packet = self.packet("safe-1", exposed=True)
        first = policy.decide(first_packet)
        self.assertEqual(policy.decide(copy.deepcopy(first_packet)), first)
        released = policy.decide(self.packet("safe-2", exposed=False, target=""))
        self.assertEqual(released["inspection"]["safety"]["trajectory_phase"], "RELEASED")
        changed = copy.deepcopy(first_packet)
        changed["observation"]["safety_context"]["danger_id"] = "other"
        with self.assertRaises(ObservationError):
            policy.decide(changed)
