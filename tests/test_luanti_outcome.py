import copy
import unittest

from runtime.luanti_outcome import LuantiOutcomeCoordinator, LuantiOutcomeError
from runtime.theta_effective import FiniteThetaEffectiveEvaluator
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


def attack_payload(index=0):
    return {
        "event": {
            "event_id": f"luanti-territory-{index:06d}",
            "schema": "territory-beast-fact-event-v1",
            "tick": 5 + index,
            "agent_id": "npc_a",
            "beast_id": "beast_1",
            "territory_id": "north_grove",
            "event_type": "close_intrusion_persisted",
            "beast_response": "attack",
            "proximity": "close",
            "outcome": "injured",
            "world_consequence": {
                "injury_level": "medium",
                "forced_retreat": True,
                "incapacitated": False,
            },
            "interaction_context": {
                "action": "approach",
                "food_id": "tasty_food",
                "food_desirability_fixture": "HIGH",
                "territory_id": "north_grove",
            },
            "authority": "World-interaction-fact; not-danger-belief-Experience-H-theta-M_delta-or-action",
        },
        "outcome_facts": {
            "food_acquired": False,
            "returned_to_base": False,
            "injury_level": "medium",
            "reward_value": "ZERO",
        },
    }


def canonical_packet(observation_id, tick, objects):
    return {
        "observation_id": observation_id,
        "tick": tick,
        "agent_id": "npc_a",
        "observation": {
            "perception_rule": "finite Luanti L7 fixture",
            "visible_agents": [],
            "visible_objects": [{"id": f"obj-{index}"} for index in range(objects)],
            "visible_places": [],
        },
    }


class LuantiOutcomeTests(unittest.TestCase):
    def test_attack_forms_existing_experience_gradient_and_biases(self):
        result = LuantiOutcomeCoordinator().record(attack_payload())
        self.assertTrue(result["accepted"])
        self.assertEqual(result["experience"]["perspective"], "direct_participant")
        dimensions = {item["relation"]: item for item in result["gradient"]["dimensions"]}
        self.assertEqual(dimensions["injury"]["magnitude_band"], "MEDIUM")
        self.assertEqual(
            {(item["relation"], item["direction"], item["strength"])
             for item in result["biases"]},
            {("acquisition", "negative", "STRONG"),
             ("return", "negative", "MEDIUM"),
             ("injury", "negative", "MEDIUM")},
        )

    def test_exact_replay_is_deterministic_and_does_not_duplicate(self):
        coordinator = LuantiOutcomeCoordinator()
        first = coordinator.record(attack_payload())
        second = coordinator.record(attack_payload())
        self.assertEqual(first, second)
        snapshot = coordinator.snapshot()
        self.assertEqual(len(snapshot["experiences"]["records"]), 1)
        self.assertEqual(snapshot["gradients"]["count"], 1)
        self.assertEqual(snapshot["biases"]["count"], 3)

    def test_interpretive_label_is_rejected(self):
        payload = attack_payload()
        payload["event"]["danger"] = True
        with self.assertRaisesRegex(LuantiOutcomeError, "danger labels"):
            LuantiOutcomeCoordinator().record(payload)

    def test_learning_path_does_not_mutate_canonical_sidecar(self):
        canonical = GameAIFrozenComparisonSidecar()
        before = copy.deepcopy(canonical.snapshot())
        LuantiOutcomeCoordinator().record(attack_payload())
        self.assertEqual(canonical.snapshot(), before)

    def test_three_luanti_outcomes_form_one_sleep_shadow_candidate(self):
        coordinator = LuantiOutcomeCoordinator()
        for index in range(3):
            coordinator.record(attack_payload(index))
        result = coordinator.consolidate({
            "agent_id": "npc_a", "sleep_cycle": "luanti-night-1", "formation_tick": 40,
        })
        self.assertEqual(result["status"], "CANDIDATE_FORMED")
        candidate = result["candidate"]
        self.assertEqual(candidate["support_count"], 3)
        self.assertEqual(len(candidate["source_world_event_ids"]), 3)
        common = {(item["relation"], item["direction"], item["strength"])
                  for item in candidate["common_bias_relations"]}
        self.assertEqual(common, {
            ("acquisition", "negative", "STRONG"),
            ("return", "negative", "MEDIUM"),
            ("injury", "negative", "MEDIUM"),
        })
        self.assertIn("not-truth-T1-M_B-H-or-action", candidate["authority"])

    def test_sleep_requires_three_distinct_experiences(self):
        coordinator = LuantiOutcomeCoordinator()
        coordinator.record(attack_payload())
        with self.assertRaisesRegex(LuantiOutcomeError, "three to six"):
            coordinator.consolidate({
                "agent_id": "npc_a", "sleep_cycle": "too-early", "formation_tick": 6,
            })

    def test_explicit_l7_cycle_reconstructs_cutovers_and_reenters(self):
        coordinator = LuantiOutcomeCoordinator()
        for index in range(3):
            coordinator.record(attack_payload(index))
        coordinator.consolidate({
            "agent_id": "npc_a", "sleep_cycle": "luanti-night-l7", "formation_tick": 40,
        })
        canonical = GameAIFrozenComparisonSidecar(
            theta_evaluator=FiniteThetaEffectiveEvaluator(1.0)
        )
        canonical.capture(canonical_packet("l7-first", 50, 1))
        canonical.capture(canonical_packet("l7-later", 51, 3))
        assessment = canonical.snapshot()["assessment"]["records"][0]
        canonical.review_assessment({
            "assessment_id": assessment["assessment_id"], "expected_revision": 0,
            "reviewer": "luanti-l7-test", "basis": "independent finite rupture fixture",
            "evidence": "l7-first-to-later",
            "dimensions": {
                "visible_agents_count": {"status": "zero"},
                "visible_objects_count": {"status": "unresolved", "residual": 1.0},
                "visible_places_count": {"status": "zero"},
            },
        })
        before = canonical.snapshot()
        self.assertEqual(before["M_delta"]["active_count"], 1)
        result = coordinator.t1_cutover(canonical, {
            "assessment_id": assessment["assessment_id"],
            "reviewer": "luanti-l7-test",
            "basis": "explicit finite Luanti candidate inspection",
            "evidence": "three Luanti attack outcomes",
            "candidate_disposition": "RETAIN",
            "experience_disposition": "DEFER",
        })
        after = canonical.snapshot()
        self.assertEqual(len(result["projected_candidates"]), 3)
        self.assertEqual(result["artifact"]["status"], "RECONSTRUCTED_INACTIVE")
        self.assertEqual(result["cutover"]["status"], "CUTOVER_ACCEPTED")
        self.assertEqual(after["M_delta"]["active_count"], 0)
        self.assertEqual(after["M_delta"]["states"][0]["phase"], "REENTERED")
        self.assertIn(result["artifact"]["parent_model_ref"], after["model_archive"])
        self.assertEqual(
            len(result["artifact"]["adopted_relations"]), 3,
        )
        prior_comparisons = after["comparisons"]
        self.assertIsNone(canonical.capture(canonical_packet("l7-reentry-first", 60, 3)))
        self.assertEqual(canonical.snapshot()["comparisons"], prior_comparisons)
        self.assertIn("not-game-action-authority", result["authority"])

    def test_l7_requires_explicit_dispositions(self):
        coordinator = LuantiOutcomeCoordinator()
        with self.assertRaisesRegex(LuantiOutcomeError, "explicit CandidateRelation RETAIN"):
            coordinator.t1_cutover(object(), {
                "assessment_id": "assessment", "reviewer": "reviewer",
                "basis": "basis", "evidence": "evidence",
                "candidate_disposition": "DEFER", "experience_disposition": "DEFER",
            })


if __name__ == "__main__":
    unittest.main()
