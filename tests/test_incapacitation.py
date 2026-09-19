import copy
import unittest

from runtime.core import ObservationError
from runtime.safety_policy import SafetyTrajectoryPolicy


class IncapacitationConstraintTests(unittest.TestCase):
    def packet(self, observation_id, *, incapacitated=True, injury="severe"):
        return {
            "observation_id": observation_id,
            "tick": 1,
            "agent_id": "npc_b",
            "observation": {
                "visible_agents": [],
                "visible_objects": [],
                "visible_places": [{"id": "plaza"}],
                "safety_context": {
                    "schema_version": "bounded-safety-context-v1",
                    "exposed": True,
                    "danger_candidates": [{"danger_id": "danger_gully", "severity": "high"}],
                    "safe_candidates": [{
                        "target_id": "plaza", "safety": "safe", "distance_band": "far",
                    }],
                    "safe_reached": False,
                    "reached_safe_target_id": "",
                },
                "body": {
                    "agent_id": "npc_b", "snapshot_id": observation_id, "revision": 3,
                    "movement_scale": 0.0, "food_actions_enabled": False,
                    "safety_actions_enabled": True, "held_food_ids": [],
                    "injury_level": injury, "incapacitated": incapacitated,
                    "danger_exposure_steps": 3,
                },
            },
        }

    def test_incapacitated_body_constrains_safety_action(self):
        decision = SafetyTrajectoryPolicy().decide(self.packet("incap-1"))
        self.assertEqual(decision["action"], {"type": "idle"})
        self.assertEqual(decision["inspection"]["body"]["injury_level"], "severe")
        self.assertTrue(decision["inspection"]["body"]["incapacitated"])
        self.assertIn("incapacitation", decision["inspection"]["reason"])

    def test_incapacitation_schema_is_finite_and_consistent(self):
        policy = SafetyTrajectoryPolicy()
        for field, value in (("injury_level", "fatal"), ("incapacitated", "yes")):
            with self.subTest(field=field), self.assertRaises(ObservationError):
                packet = self.packet("invalid-%s" % field)
                packet["observation"]["body"][field] = value
                policy.decide(packet)
        inconsistent = self.packet("invalid-pair", injury="light")
        with self.assertRaises(ObservationError):
            SafetyTrajectoryPolicy().decide(copy.deepcopy(inconsistent))


if __name__ == "__main__":
    unittest.main()
