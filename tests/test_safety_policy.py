import copy
import unittest

from runtime.core import ObservationError
from runtime import bridge
from runtime.safety_policy import SafetyTrajectoryPolicy


class SafetyTrajectoryPolicyTests(unittest.TestCase):
    def test_bridge_rejects_safety_combined_with_other_action_policies(self):
        for kwargs in (
            {"base_food_life": True, "safety_trajectory": True},
            {"rest_trajectory": True, "safety_trajectory": True},
            {"history_influence": True, "safety_trajectory": True},
        ):
            with self.subTest(kwargs=kwargs), self.assertRaisesRegex(ValueError, "isolated"):
                bridge.run(port=0, **kwargs)

    def packet(self, observation_id, *, exposed, reached=False, target="plaza"):
        return {
            "observation_id": observation_id, "tick": 1, "agent_id": "npc_b",
            "observation": {
                "visible_agents": [], "visible_objects": [],
                "visible_places": [{"id": target}] if target else [],
                "safety_context": {
                    "schema_version": "bounded-safety-context-v1",
                    "exposed": exposed,
                    "danger_candidates": ([{
                        "danger_id": "danger_gully", "severity": "high",
                    }] if exposed else []),
                    "safe_candidates": ([{
                        "target_id": target, "safety": "safe", "distance_band": "far",
                    }] if target else []),
                    "safe_reached": reached,
                    "reached_safe_target_id": target if reached else "",
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

    def test_reaching_a_different_safe_target_does_not_complete_commitment(self):
        policy = SafetyTrajectoryPolicy()
        policy.decide(self.packet("safe-1", exposed=True, target="plaza"))
        mismatch = self.packet("safe-2", exposed=False, reached=True, target="plaza")
        mismatch["observation"]["safety_context"]["reached_safe_target_id"] = "shelter_b"
        continued = policy.decide(mismatch)
        self.assertEqual(continued["action"], {"type": "flee", "target_id": "plaza"})
        self.assertEqual(continued["inspection"]["safety"]["trajectory_phase"], "FLEE_TO_SAFE")

    def test_candidate_rank_change_does_not_reselect_committed_target(self):
        policy = SafetyTrajectoryPolicy()
        first = self.packet("safe-1", exposed=True, target="plaza")
        first["observation"]["safety_context"]["safe_candidates"].append({
            "target_id": "shelter_b", "safety": "uncertain", "distance_band": "near",
        })
        formed = policy.decide(first)
        self.assertEqual(formed["action"]["target_id"], "plaza")
        changed = self.packet("safe-2", exposed=False, target="plaza")
        changed["observation"]["safety_context"]["safe_candidates"] = [
            {"target_id": "shelter_b", "safety": "safe", "distance_band": "within_reach"},
            {"target_id": "plaza", "safety": "uncertain", "distance_band": "far"},
        ]
        continued = policy.decide(changed)
        self.assertEqual(continued["action"], {"type": "flee", "target_id": "plaza"})

    def test_missing_target_releases_and_replay_is_frozen(self):
        policy = SafetyTrajectoryPolicy()
        first_packet = self.packet("safe-1", exposed=True)
        first = policy.decide(first_packet)
        self.assertEqual(policy.decide(copy.deepcopy(first_packet)), first)
        released = policy.decide(self.packet("safe-2", exposed=False, target=""))
        self.assertEqual(released["inspection"]["safety"]["trajectory_phase"], "RELEASED")
        changed = copy.deepcopy(first_packet)
        changed["observation"]["safety_context"]["danger_candidates"][0]["danger_id"] = "other"
        with self.assertRaises(ObservationError):
            policy.decide(changed)
