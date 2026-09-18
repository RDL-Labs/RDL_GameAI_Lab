import unittest

from runtime.core import ObservationError
from runtime.life_policy import (
    BaseFoodLifePolicy,
    parse_cue_responses,
    parse_novelty_responses,
    parse_threat_profiles,
)


class BaseFoodLifePolicyTests(unittest.TestCase):
    def packet(self, *, cue="low", observed="low", at_base=True,
               position="far", held=None, observation_id="life-1", interrupts=None):
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
                    "interrupt_candidates": list(interrupts or []),
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

    def test_generic_interrupt_holds_then_resumes_committed_trajectory(self):
        policy = BaseFoodLifePolicy()
        policy.decide(self.packet())
        held = policy.decide(self.packet(
            observation_id="life-2",
            interrupts=[{"candidate_id": "candidate-1", "kind": "generic", "salience": 0.8}],
        ))
        resumed = policy.decide(self.packet(observation_id="life-3"))
        self.assertEqual(held["action"], {"type": "idle"})
        self.assertEqual(held["inspection"]["life"]["trajectory_phase"], "SUSPENDED")
        self.assertEqual(held["inspection"]["life"]["interrupt"]["outcome"], "hold")
        self.assertEqual(resumed["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(resumed["inspection"]["life"]["trajectory_phase"], "GO_TO_SITE")

    def test_subthreshold_interrupt_does_not_break_trajectory(self):
        response = BaseFoodLifePolicy().decide(self.packet(
            interrupts=[{"candidate_id": "candidate-1", "kind": "generic", "salience": 0.6}],
        ))
        self.assertEqual(response["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(response["inspection"]["life"]["interrupt"]["outcome"], "continue")

    def test_interrupt_candidates_have_a_finite_phase_six_schema(self):
        invalid_candidates = [
            [{"candidate_id": "candidate-1", "kind": "novelty", "salience": 0.8}],
            [{"candidate_id": "candidate-1", "kind": "generic", "salience": 1.1}],
            [
                {"candidate_id": "duplicate", "kind": "generic", "salience": 0.8},
                {"candidate_id": "duplicate", "kind": "generic", "salience": 0.9},
            ],
        ]
        for index, candidates in enumerate(invalid_candidates):
            with self.subTest(index=index), self.assertRaises(ObservationError):
                BaseFoodLifePolicy().decide(self.packet(interrupts=candidates))

    def test_same_threat_observation_differs_by_agent_profile(self):
        threat = [{"candidate_id": "threat-1", "kind": "threat", "salience": 0.7}]
        cautious = BaseFoodLifePolicy(threat_profiles={"npc_a": "cautious"}).decide(
            self.packet(interrupts=threat)
        )
        steadfast = BaseFoodLifePolicy(threat_profiles={"npc_a": "steadfast"}).decide(
            self.packet(interrupts=threat)
        )
        self.assertEqual(cautious["action"], {"type": "idle"})
        self.assertEqual(cautious["inspection"]["life"]["interrupt"]["threat_profile"], "cautious")
        self.assertEqual(steadfast["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(steadfast["inspection"]["life"]["interrupt"]["threat_profile"], "steadfast")

    def test_threat_profile_parser_is_finite(self):
        self.assertEqual(parse_threat_profiles(["npc_a=cautious"]), {"npc_a": "cautious"})
        for values in (["npc_a=fearful"], ["npc_a"], ["npc_a=cautious", "npc_a=steadfast"]):
            with self.subTest(values=values), self.assertRaises(ValueError):
                parse_threat_profiles(values)

    def test_same_novelty_supports_ignore_inspect_and_divert(self):
        novelty = [{
            "candidate_id": "novelty-1", "kind": "novelty",
            "salience": 0.8, "target_id": "food_01",
        }]
        expected = {
            "ignore": ({"type": "approach", "target_id": "food_01"}, "GO_TO_SITE"),
            "inspect": ({"type": "idle"}, "SUSPENDED"),
            "divert": ({"type": "approach", "target_id": "food_01"}, "SUSPENDED"),
        }
        for response, (action, phase) in expected.items():
            with self.subTest(response=response):
                decision = BaseFoodLifePolicy(
                    novelty_responses={"npc_a": response}
                ).decide(self.packet(interrupts=novelty))
                life = decision["inspection"]["life"]
                self.assertEqual(decision["action"], action)
                self.assertEqual(life["trajectory_phase"], phase)
                self.assertEqual(life["interrupt"]["outcome"], response)

    def test_novelty_target_must_be_visible(self):
        with self.assertRaises(ObservationError):
            BaseFoodLifePolicy().decide(self.packet(interrupts=[{
                "candidate_id": "novelty-1", "kind": "novelty",
                "salience": 0.8, "target_id": "hidden-object",
            }]))

    def test_novelty_response_parser_is_finite(self):
        self.assertEqual(parse_novelty_responses(["npc_a=divert"]), {"npc_a": "divert"})
        for values in (["npc_a=flee"], ["npc_a"], ["npc_a=ignore", "npc_a=inspect"]):
            with self.subTest(values=values), self.assertRaises(ValueError):
                parse_novelty_responses(values)

    def test_ignored_novelty_does_not_hide_actionable_threat(self):
        decision = BaseFoodLifePolicy(
            novelty_responses={"npc_a": "ignore"},
            threat_profiles={"npc_a": "cautious"},
        ).decide(self.packet(interrupts=[
            {"candidate_id": "novelty-1", "kind": "novelty", "salience": 0.9, "target_id": "food_01"},
            {"candidate_id": "threat-1", "kind": "threat", "salience": 0.6},
        ]))
        life = decision["inspection"]["life"]
        self.assertEqual(decision["action"], {"type": "idle"})
        self.assertEqual(life["interrupt"]["selected"]["candidate_id"], "threat-1")
        self.assertEqual(life["interrupt"]["outcome"], "hold")


if __name__ == "__main__":
    unittest.main()
