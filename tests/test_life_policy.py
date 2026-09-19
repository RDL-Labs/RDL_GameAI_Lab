import unittest

from runtime.core import ObservationError
from runtime.life_policy import (
    BaseFoodLifePolicy,
    parse_cue_responses,
    parse_life_profiles,
    parse_novelty_responses,
    parse_threat_profiles,
)


class BaseFoodLifePolicyTests(unittest.TestCase):
    def packet(self, *, cue="low", observed="low", at_base=True,
               position="far", held=None, observation_id="life-1", interrupts=None,
               agent_id="npc_a", cue_id="cue-1"):
        item = {"id": "food_01", "kind": "food", "within_reach": position == "near"}
        return {
            "observation_id": observation_id,
            "tick": 1,
            "agent_id": agent_id,
            "observation": {
                "visible_agents": [],
                "visible_objects": [item],
                "visible_places": [],
                "body": {
                    "agent_id": agent_id, "snapshot_id": "body-1", "revision": 1,
                    "movement_scale": 1.0, "food_actions_enabled": True,
                    "food_need": 0.8, "held_food_ids": list(held or []),
                },
                "life_context": {
                    "god_statue_cue": {
                        "source": "system_assessment", "topic": "base_food",
                        "band": cue, "delivery": "morning", "cue_id": cue_id,
                    },
                    "observed_base_food_band": observed,
                    "known_base": {"id": "base"},
                    "at_base": at_base,
                    "interrupt_candidates": list(interrupts or []),
                },
            },
        }

    def admitted_success(self, policy, index, agent_id="npc_a"):
        cue_id = f"cue-{index}"
        source_id = f"deposit-{index}"
        policy.decide(self.packet(observation_id=f"start-{index}", agent_id=agent_id, cue_id=cue_id))
        deposit = policy.decide(self.packet(
            held=["food_01"], at_base=True, observation_id=source_id,
            agent_id=agent_id, cue_id=cue_id,
        ))
        self.assertEqual(deposit["action"], {"type": "deposit", "target_id": "base"})
        result = {
            "result_id": f"result-{index}", "agent_id": agent_id,
            "source_observation_id": source_id, "cue_id": cue_id,
            "response": "follow", "outcome": "replenish_success",
        }
        return result, policy.record_result(result)

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
            self.admitted_success(policy, index)
        packet = self.packet(observation_id="autonomous")
        packet["observation"]["life_context"]["god_statue_cue"] = None
        response = policy.decide(packet)
        self.assertEqual(response["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(response["inspection"]["life"]["goal_trigger"], "learned_low_stock_relation")
        self.assertTrue(response["inspection"]["life"]["habit_ready"])

    def test_one_success_is_not_enough_and_replay_is_idempotent(self):
        policy = BaseFoodLifePolicy()
        result, record = self.admitted_success(policy, 1)
        policy.decide(self.packet(observation_id="new-active", cue_id="cue-new"))
        before_replay = policy.snapshot()
        self.assertEqual(record, policy.record_result(result))
        self.assertEqual(before_replay, policy.snapshot())
        packet = self.packet(observation_id="autonomous")
        packet["observation"]["life_context"]["god_statue_cue"] = None
        response = policy.decide(packet)
        self.assertEqual(response["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(response["inspection"]["life"]["trajectory_phase"], "GO_TO_SITE")
        self.assertFalse(response["inspection"]["life"]["habit_ready"])

    def test_success_result_must_bind_to_registered_deposit_causality(self):
        policy = BaseFoodLifePolicy()
        approach = policy.decide(self.packet(observation_id="approach-source"))
        self.assertEqual(approach["action"]["type"], "approach")
        invalid = {
            "result_id": "bad", "agent_id": "npc_a",
            "source_observation_id": "missing", "cue_id": "cue-1",
            "response": "follow", "outcome": "replenish_success",
        }
        cases = []
        cases.append(dict(invalid))
        wrong_agent = dict(invalid, source_observation_id="approach-source", agent_id="npc_b")
        cases.append(wrong_agent)
        wrong_action = dict(invalid, source_observation_id="approach-source")
        cases.append(wrong_action)
        for payload in cases:
            with self.subTest(payload=payload), self.assertRaises(ObservationError):
                policy.record_result(payload)
        self.assertEqual(policy.snapshot()["results"], [])

        valid, accepted = self.admitted_success(policy, "valid")
        self.assertEqual(accepted["source_observation_id"], "deposit-valid")
        conflict = dict(valid, cue_id="different")
        with self.assertRaises(ObservationError):
            policy.record_result(conflict)

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

    def test_extreme_profiles_expose_tuning_bounds(self):
        candidates = [
            {"candidate_id": "generic-1", "kind": "generic", "salience": 0.8},
            {"candidate_id": "novelty-1", "kind": "novelty", "salience": 0.85, "target_id": "food_01"},
        ]
        locked = BaseFoodLifePolicy(
            life_profiles={"npc_a": "trajectory_locked"}
        ).decide(self.packet(interrupts=candidates))
        switching = BaseFoodLifePolicy(
            life_profiles={"npc_a": "context_switching"}
        ).decide(self.packet(interrupts=candidates))
        self.assertEqual(locked["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(locked["inspection"]["life"]["interrupt"]["outcome"], "continue")
        self.assertEqual(switching["action"], {"type": "approach", "target_id": "food_01"})
        self.assertEqual(switching["inspection"]["life"]["trajectory_phase"], "SUSPENDED")
        self.assertEqual(switching["inspection"]["life"]["interrupt"]["outcome"], "divert")

    def test_extreme_profile_is_not_mixed_with_axis_overrides(self):
        with self.assertRaises(ValueError):
            BaseFoodLifePolicy(
                life_profiles={"npc_a": "trajectory_locked"},
                novelty_responses={"npc_a": "inspect"},
            )

    def test_extreme_profile_parser_is_finite(self):
        self.assertEqual(
            parse_life_profiles(["npc_a=context_switching"]),
            {"npc_a": "context_switching"},
        )
        for values in (["npc_a=balanced"], ["npc_a"], ["npc_a=trajectory_locked", "npc_a=context_switching"]):
            with self.subTest(values=values), self.assertRaises(ValueError):
                parse_life_profiles(values)


if __name__ == "__main__":
    unittest.main()
