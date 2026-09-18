import copy
import unittest

from runtime.core import ObservationError
from runtime.rest_policy import RestTrajectoryPolicy


class RestTrajectoryPolicyTests(unittest.TestCase):
    def packet(self, observation_id, *, need=0.8, within=False, places=True,
               interrupts=None, plaza_safety="safe", plaza_distance=None):
        visible_places = []
        if places:
            visible_places.append({
                "id": "plaza", "rest_capable": True, "rest_safety": plaza_safety,
                "within_reach": within,
                "rest_distance_band": plaza_distance or ("within_reach" if within else "near"),
            })
        return {
            "observation_id": observation_id,
            "tick": 1,
            "agent_id": "npc_a",
            "observation": {
                "visible_agents": [], "visible_objects": [], "visible_places": visible_places,
                "body": {
                    "agent_id": "npc_a", "snapshot_id": "rest-body-1", "revision": 1,
                    "movement_scale": 1.0, "food_actions_enabled": False,
                    "rest_actions_enabled": True, "rest_need": need, "held_food_ids": [],
                },
                "life_context": {"interrupt_candidates": list(interrupts or [])},
            },
        }

    def test_goal_trajectory_interrupt_resume_and_completion(self):
        policy = RestTrajectoryPolicy()
        first = policy.decide(self.packet("rest-1"))
        self.assertEqual(first["action"], {"type": "approach", "target_id": "plaza"})
        self.assertEqual(first["inspection"]["rest"]["trajectory_phase"], "GO_TO_REST")
        self.assertEqual(first["inspection"]["rest"]["target_safety_observed_not_used"], "safe")

        interrupt = [{"candidate_id": "generic-1", "kind": "generic", "salience": 0.9}]
        held = policy.decide(self.packet("rest-2", interrupts=interrupt))
        self.assertEqual(held["action"], {"type": "idle"})
        self.assertEqual(held["inspection"]["rest"]["trajectory_phase"], "SUSPENDED")

        resumed = policy.decide(self.packet("rest-3"))
        self.assertEqual(resumed["action"], {"type": "approach", "target_id": "plaza"})
        at_rest = policy.decide(self.packet("rest-4", within=True))
        self.assertEqual(at_rest["action"], {"type": "rest", "target_id": "plaza"})
        self.assertEqual(at_rest["inspection"]["rest"]["trajectory_phase"], "SHORT_REST")

        complete = policy.decide(self.packet("rest-5", need=0.2, within=True))
        self.assertEqual(complete["action"], {"type": "idle"})
        self.assertEqual(complete["inspection"]["rest"]["trajectory_phase"], "COMPLETE")
        self.assertEqual(policy.snapshot()["trajectories"], {})

    def test_candidate_rank_change_does_not_reselect_committed_target(self):
        policy = RestTrajectoryPolicy()
        packet = self.packet("rest-1")
        packet["observation"]["visible_places"].insert(0, {
            "id": "grove", "rest_capable": True, "rest_safety": "uncertain",
            "within_reach": True, "rest_distance_band": "within_reach",
        })
        first = policy.decide(packet)
        self.assertEqual(first["action"]["target_id"], "plaza")

        changed = self.packet("rest-2", plaza_distance="far")
        changed["observation"]["visible_places"].insert(0, {
            "id": "grove", "rest_capable": True, "rest_safety": "safe",
            "within_reach": True, "rest_distance_band": "within_reach",
        })
        continued = policy.decide(changed)
        self.assertEqual(continued["action"], {"type": "approach", "target_id": "plaza"})
        self.assertEqual(
            continued["inspection"]["rest"]["target_selection"]["selected"]["target_id"],
            "plaza",
        )

    def test_target_disappearance_structurally_releases(self):
        policy = RestTrajectoryPolicy()
        policy.decide(self.packet("rest-1"))
        released = policy.decide(self.packet("rest-2", places=False))
        self.assertEqual(released["inspection"]["rest"]["trajectory_phase"], "RELEASED")
        self.assertEqual(policy.snapshot()["trajectories"], {})

    def test_target_capability_loss_or_unreachable_band_releases(self):
        for change in ("capability", "reachability"):
            with self.subTest(change=change):
                policy = RestTrajectoryPolicy()
                policy.decide(self.packet("rest-1"))
                changed = self.packet("rest-2")
                target = changed["observation"]["visible_places"][0]
                if change == "capability":
                    target["rest_capable"] = False
                else:
                    target["rest_distance_band"] = "unreachable"
                released = policy.decide(changed)
                self.assertEqual(released["inspection"]["rest"]["trajectory_phase"], "RELEASED")
                self.assertEqual(policy.snapshot()["trajectories"], {})

    def test_observation_replay_is_frozen(self):
        policy = RestTrajectoryPolicy()
        packet = self.packet("rest-1")
        self.assertEqual(policy.decide(packet), policy.decide(copy.deepcopy(packet)))
        changed = copy.deepcopy(packet)
        changed["observation"]["body"]["rest_need"] = 0.9
        with self.assertRaises(ObservationError):
            policy.decide(changed)


if __name__ == "__main__":
    unittest.main()
