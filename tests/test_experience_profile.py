import copy
import unittest

from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.functions.experience_profile import ExperienceProfileError, build_relation_profiles
from runtime.sleep_window import SleepExperienceWindowStore
from runtime.structural.relations import RelationStructureError, build_reported_relation
from test_experience import food_packet, result


class ExperienceProfileTests(unittest.TestCase):
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

    def test_compiles_five_finite_sourced_relations_per_experience(self):
        compiled = build_relation_profiles(self.window, self.history.snapshot())
        self.assertEqual(len(compiled["profiles"]), 3)
        for profile in compiled["profiles"]:
            self.assertEqual(
                [relation["kind"] for relation in profile["relations"]],
                ["actor", "target", "context", "action", "outcome"],
            )
            self.assertTrue(all(
                relation["source_experience_ids"] == [profile["source_experience_id"]]
                for relation in profile["relations"]
            ))
        self.assertIn("not-candidate-commitment-M_B-or-T1", compiled["authority"])
        self.assertNotIn("candidate", compiled["profiles"][0])

    def test_no_progress_remains_unresolved_not_failure_or_dislike(self):
        compiled = build_relation_profiles(self.window, self.history.snapshot())
        outcomes = [
            relation for profile in compiled["profiles"] for relation in profile["relations"]
            if relation["kind"] == "outcome"
        ]
        no_progress = next(item for item in outcomes if item["object"] == "approach_no_progress")
        self.assertEqual(no_progress["polarity"], "unresolved")
        self.assertNotIn("failure", str(no_progress))
        self.assertNotIn("dislike", str(no_progress))

    def test_compiler_is_deterministic_pure_and_separate_from_raw_records(self):
        window_before = copy.deepcopy(self.window)
        history_before = self.history.snapshot()
        first = build_relation_profiles(self.window, history_before)
        second = build_relation_profiles(self.window, self.history.snapshot())
        self.assertEqual(first, second)
        self.assertEqual(self.window, window_before)
        self.assertEqual(self.history.snapshot(), history_before)
        first["profiles"][0]["relations"].clear()
        self.assertEqual(len(build_relation_profiles(self.window, history_before)["profiles"][0]["relations"]), 5)

    def test_missing_or_cross_agent_source_is_rejected(self):
        missing = self.history.snapshot()
        missing["records"] = missing["records"][1:]
        with self.assertRaisesRegex(ExperienceProfileError, "disappeared"):
            build_relation_profiles(self.window, missing)
        changed = self.history.snapshot()
        changed["records"][0]["agent_id"] = "npc_b"
        with self.assertRaisesRegex(ExperienceProfileError, "agent identity"):
            build_relation_profiles(self.window, changed)

    def test_i1_relation_builder_rejects_unbounded_vocabulary(self):
        with self.assertRaises(RelationStructureError):
            build_reported_relation(
                source_experience_id="source", kind="emotion", subject="a",
                predicate="feels", object_value="happy", polarity="certain",
            )


if __name__ == "__main__":
    unittest.main()
