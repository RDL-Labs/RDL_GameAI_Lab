import copy
import unittest

from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.functions.deep_similarity import DeepSimilarityError, build_deep_similarity_shadow
from runtime.functions.experience_profile import build_relation_profiles
from runtime.mechanisms.deep_similarity import DeepSimilarityShadowStore
from runtime.sleep_window import SleepExperienceWindowStore
from runtime.structural.relations import build_reported_relation
from runtime.structural.similarity import compare_relation_profiles
from test_experience import food_packet, result


class DeepSimilarityTests(unittest.TestCase):
    def setUp(self):
        self.history = InteractionHistory()
        for source, outcome in (
            ("a", "approach_progress"),
            ("b", "approach_no_progress"),
            ("c", "approach_progress"),
        ):
            packet = food_packet(source)
            self.history.register_decision(packet, decide_action(packet))
            self.history.record_result(result(source, outcome))
        self.window = SleepExperienceWindowStore().form_window(
            self.history.snapshot(), agent_id="npc_a", sleep_cycle="night-001",
            formation_tick=10, enabled=True,
        )
        self.profiles = build_relation_profiles(self.window, self.history.snapshot())

    def build(self):
        return build_deep_similarity_shadow(
            self.window, self.profiles, formation_tick=11
        )

    def test_forms_three_pair_observations_one_cluster_and_one_shadow_candidate(self):
        result = self.build()
        self.assertEqual(result["status"], "CANDIDATE_FORMED")
        self.assertEqual(len(result["similarity_observations"]), 3)
        self.assertEqual(result["cluster"]["member_count"], 3)
        self.assertEqual(result["candidate"]["common_relation_signature"]["kind"], "target")
        self.assertEqual(result["candidate"]["common_relation_signature"]["object"], "food_01")
        self.assertEqual(result["candidate"]["support_count"], 3)
        self.assertEqual(
            result["candidate"]["source_experience_ids"],
            self.window["source_experience_ids"],
        )
        self.assertIn("not-E-H-theta-M_delta-M_B-prime-or-T1", result["authority"])
        self.assertIn("not-truth-commitment-action-M_B-H-or-T1", result["candidate"]["authority"])

    def test_unresolved_is_not_conflict_or_negative_score(self):
        result = self.build()
        observations = result["similarity_observations"]
        self.assertTrue(any(item["unresolved"] for item in observations))
        self.assertTrue(all(item["conflict"] == [] for item in observations))
        self.assertTrue(all(item["score"] is not None for item in observations))
        self.assertNotIn("negative", str(result))

    def test_missing_coverage_is_explicit_and_prevents_cluster(self):
        incomplete = copy.deepcopy(self.profiles)
        incomplete["profiles"][0]["relations"] = [
            item for item in incomplete["profiles"][0]["relations"]
            if item["kind"] != "outcome"
        ]
        result = build_deep_similarity_shadow(
            self.window, incomplete, formation_tick=11
        )
        affected = [
            item for item in result["similarity_observations"]
            if incomplete["profiles"][0]["profile_id"] in item["profile_ids"]
        ]
        self.assertTrue(all(item["coverage"]["status"] == "incomplete" for item in affected))
        self.assertTrue(all(item["score"] is None for item in affected))
        self.assertEqual(result["status"], "NO_CLUSTER")
        self.assertIsNone(result["cluster"])
        self.assertIsNone(result["candidate"])

    def test_difference_is_not_conflict_but_opposing_polarity_is(self):
        left, right = copy.deepcopy(self.profiles["profiles"][:2])
        target = next(item for item in right["relations"] if item["kind"] == "target")
        target["object"] = "other_food"
        rebuilt = build_reported_relation(
            source_experience_id=right["source_experience_id"], kind="target",
            subject=target["subject"], predicate=target["predicate"],
            object_value=target["object"], polarity=target["polarity"],
        )
        target.update(rebuilt)
        observation = compare_relation_profiles(left, right, purpose="test")
        self.assertTrue(any(item["kind"] == "target" for item in observation["different_relations"]))
        self.assertEqual(observation["conflict"], [])

        outcome = next(item for item in right["relations"] if item["kind"] == "outcome")
        left_outcome = next(item for item in left["relations"] if item["kind"] == "outcome")
        outcome.update(build_reported_relation(
            source_experience_id=right["source_experience_id"], kind="outcome",
            subject=outcome["subject"], predicate=left_outcome["predicate"],
            object_value=left_outcome["object"], polarity="adverse",
        ))
        observation = compare_relation_profiles(left, right, purpose="test")
        self.assertEqual(len(observation["conflict"]), 1)

    def test_schema_scaffolding_alone_does_not_form_candidate(self):
        varied = copy.deepcopy(self.profiles)
        for index, profile in enumerate(varied["profiles"]):
            for relation in profile["relations"]:
                if relation["kind"] in {"target", "context", "outcome"}:
                    relation.update(build_reported_relation(
                        source_experience_id=profile["source_experience_id"],
                        kind=relation["kind"], subject=relation["subject"],
                        predicate=relation["predicate"],
                        object_value=f"different-{index}-{relation['kind']}",
                        polarity="neutral",
                    ))
        result = build_deep_similarity_shadow(self.window, varied, formation_tick=11)
        self.assertEqual(result["status"], "NO_CANDIDATE")
        self.assertIsNotNone(result["cluster"])
        self.assertIsNone(result["candidate"])

    def test_store_is_opt_in_deterministic_and_rejects_changed_replay(self):
        store = DeepSimilarityShadowStore()
        with self.assertRaises(DeepSimilarityError):
            store.form(self.window, self.profiles, formation_tick=11)
        first = store.form(
            self.window, self.profiles, formation_tick=11, enabled=True
        )
        second = store.form(
            self.window, self.profiles, formation_tick=11, enabled=True
        )
        self.assertEqual(first, second)
        first["similarity_observations"].clear()
        self.assertEqual(len(store.snapshot()["results"][0]["similarity_observations"]), 3)
        with self.assertRaisesRegex(DeepSimilarityError, "replay changed"):
            store.form(
                self.window, self.profiles, formation_tick=12, enabled=True
            )

    def test_six_profiles_are_bounded_to_fifteen_pairs(self):
        history = InteractionHistory()
        for index in range(6):
            source = f"six-{index}"
            packet = food_packet(source)
            history.register_decision(packet, decide_action(packet))
            history.record_result(result(source))
        window = SleepExperienceWindowStore().form_window(
            history.snapshot(), agent_id="npc_a", sleep_cycle="night-006",
            formation_tick=20, enabled=True,
        )
        profiles = build_relation_profiles(window, history.snapshot())
        deep = build_deep_similarity_shadow(window, profiles, formation_tick=21)
        self.assertEqual(len(deep["similarity_observations"]), 15)

    def test_insufficient_window_and_duplicate_sources_are_rejected(self):
        insufficient = copy.deepcopy(self.window)
        insufficient["status"] = "INSUFFICIENT_EVIDENCE"
        with self.assertRaisesRegex(DeepSimilarityError, "READY"):
            build_deep_similarity_shadow(insufficient, self.profiles, formation_tick=11)
        duplicate = copy.deepcopy(self.window)
        duplicate["source_experience_ids"][1] = duplicate["source_experience_ids"][0]
        changed_profiles = copy.deepcopy(self.profiles)
        changed_profiles["source_experience_ids"] = list(duplicate["source_experience_ids"])
        changed_profiles["profiles"][1]["source_experience_id"] = duplicate["source_experience_ids"][1]
        with self.assertRaisesRegex(DeepSimilarityError, "duplicate Sleep source"):
            build_deep_similarity_shadow(duplicate, changed_profiles, formation_tick=11)

    def test_input_mismatch_rejects_without_mutation(self):
        window_before = copy.deepcopy(self.window)
        profiles_before = copy.deepcopy(self.profiles)
        changed = copy.deepcopy(self.profiles)
        changed["agent_id"] = "npc_b"
        with self.assertRaisesRegex(DeepSimilarityError, "different agent"):
            build_deep_similarity_shadow(self.window, changed, formation_tick=11)
        self.assertEqual(self.window, window_before)
        self.assertEqual(self.profiles, profiles_before)


if __name__ == "__main__":
    unittest.main()
