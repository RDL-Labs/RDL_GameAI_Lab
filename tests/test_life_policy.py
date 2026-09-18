import unittest

from runtime.life_policy import BaseFoodLifePolicy, parse_cue_responses


class BaseFoodLifePolicyTests(unittest.TestCase):
    def packet(self, *, cue="low", observed="low", at_base=True,
               position="far", held=None, observation_id="life-1"):
        item = {"id": "food_01", "kind": "food", "within_reach": position == "near"}
        return {
            "observation_id": observation_id,
            "tick": 1,
            "agent_id": "npc_a",
            "observation": {
                "visible_agents": [],
                "visible_objects": [item],
                "visible_places": [],
                "body": {
                    "agent_id": "npc_a", "snapshot_id": "body-1", "revision": 1,
                    "movement_scale": 1.0, "food_actions_enabled": True,
                    "food_need": 0.8, "held_food_ids": list(held or []),
                },
                "life_context": {
                    "god_statue_cue": {
                        "source": "system_assessment", "topic": "base_food",
                        "band": cue, "delivery": "morning", "cue_id": "cue-1",
                    },
                    "observed_base_food_band": observed,
                    "known_base": {"id": "base"},
                    "at_base": at_base,
                },
            },
        }

    def test_cue_and_observation_form_goal_but_cue_has_no_direct_authority(self):
        policy = BaseFoodLifePolicy()
        active = policy.decide(self.packet())
        inconsistent = BaseFoodLifePolicy().decide(self.packet(observed="enough"))
        self.assertEqual(active["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(active["inspection"]["life"]["goal"], "replenish_base_food")
        self.assertEqual(inconsistent["action"], {"type": "idle"})
        self.assertIn("cue-is-observation-not-command", active["inspection"]["life"]["authority"])

    def test_trajectory_continues_through_gather_return_and_deposit(self):
        policy = BaseFoodLifePolicy()
        first = policy.decide(self.packet())
        gather = policy.decide(self.packet(position="near", observation_id="life-2"))
        returning = policy.decide(self.packet(held=["food_01"], at_base=False, observation_id="life-3"))
        deposit = policy.decide(self.packet(held=["food_01"], at_base=True, observation_id="life-4"))
        self.assertEqual(first["inspection"]["life"]["trajectory_phase"], "GO_TO_SITE")
        self.assertEqual(gather["action"]["type"], "pickup")
        self.assertEqual(returning["action"], {"type": "approach", "target_id": "base"})
        self.assertEqual(deposit["action"], {"type": "deposit", "target_id": "base"})

    def test_structural_release_when_target_disappears(self):
        policy = BaseFoodLifePolicy()
        policy.decide(self.packet())
        packet = self.packet(observation_id="life-2")
        packet["observation"]["visible_objects"] = []
        response = policy.decide(packet)
        self.assertEqual(response["action"], {"type": "idle"})
        self.assertEqual(response["inspection"]["life"]["trajectory_phase"], "NONE")

    def test_ignore_is_agent_owned_and_forms_no_goal(self):
        response = BaseFoodLifePolicy(cue_responses={"npc_a": "ignore"}).decide(self.packet())
        self.assertEqual(response["action"], {"type": "idle"})
        self.assertEqual(response["inspection"]["life"]["cue_response"], "ignore")
        self.assertIsNone(response["inspection"]["life"]["goal"])
        self.assertIn("ignored", response["inspection"]["reason"])

    def test_cue_response_parser_is_finite(self):
        self.assertEqual(parse_cue_responses(["npc_a=ignore"]), {"npc_a": "ignore"})
        for values in (["npc_a=delay"], ["npc_a"], ["npc_a=follow", "npc_a=ignore"]):
            with self.subTest(values=values), self.assertRaises(ValueError):
                parse_cue_responses(values)

    def test_two_successes_enable_cue_independent_goal(self):
        policy = BaseFoodLifePolicy()
        for index in range(2):
            policy.record_result({
                "result_id": f"result-{index}", "agent_id": "npc_a",
                "source_observation_id": f"source-{index}", "cue_id": f"cue-{index}",
                "response": "follow", "outcome": "replenish_success",
            })
        packet = self.packet(observation_id="autonomous")
        packet["observation"]["life_context"]["god_statue_cue"] = None
        response = policy.decide(packet)
        self.assertEqual(response["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(response["inspection"]["life"]["goal_trigger"], "learned_low_stock_relation")
        self.assertTrue(response["inspection"]["life"]["habit_ready"])

    def test_one_success_is_not_enough_and_replay_is_idempotent(self):
        policy = BaseFoodLifePolicy()
        result = {
            "result_id": "result-1", "agent_id": "npc_a",
            "source_observation_id": "source-1", "cue_id": "cue-1",
            "response": "follow", "outcome": "replenish_success",
        }
        self.assertEqual(policy.record_result(result), policy.record_result(result))
        packet = self.packet(observation_id="autonomous")
        packet["observation"]["life_context"]["god_statue_cue"] = None
        response = policy.decide(packet)
        self.assertEqual(response["action"], {"type": "idle"})
        self.assertFalse(response["inspection"]["life"]["habit_ready"])


if __name__ == "__main__":
    unittest.main()
