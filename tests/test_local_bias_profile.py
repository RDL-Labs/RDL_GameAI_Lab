import copy
import unittest

from runtime.functions.local_bias_profile import (
    LocalBiasProfileError,
    build_local_bias_profiles,
)
from runtime.outcome_bias import LocalBiasStore, OutcomeGradientStore
from tests.test_outcome_bias import source


def projection(agent_id="npc_a", mixed=True):
    gradient = OutcomeGradientStore().form(source(agent_id, injury=mixed), {
        "food_acquired": True,
        "returned_to_base": True,
        "injury_level": "severe" if mixed else "none",
        "reward_value": "HIGH",
    })
    store = LocalBiasStore()
    store.form(gradient)
    return store.sleep_projection(agent_id)


class LocalBiasProfileTests(unittest.TestCase):
    def test_compiles_mixed_biases_without_netting_or_candidate_formation(self):
        compiled = build_local_bias_profiles(projection())
        self.assertEqual(compiled["profile_count"], 1)
        relations = compiled["profiles"][0]["relations"]
        pairs = {(item["relation"], item["direction"], item["strength"])
                 for item in relations}
        self.assertIn(("reward_value", "positive", "STRONG"), pairs)
        self.assertIn(("injury", "negative", "STRONG"), pairs)
        self.assertNotIn("net_score", str(compiled))
        self.assertNotIn("candidate", compiled["profiles"][0])
        self.assertIn("not-similarity-cluster-candidate", compiled["authority"])

    def test_profile_retains_complete_bias_experience_event_and_context_provenance(self):
        source_projection = projection()
        compiled = build_local_bias_profiles(source_projection)
        profile = compiled["profiles"][0]
        self.assertEqual(profile["agent_id"], "npc_a")
        self.assertEqual(set(profile["source_bias_ids"]),
                         {item["bias_id"] for item in source_projection["local_bias_materials"]})
        for relation in profile["relations"]:
            self.assertTrue(relation["source_experience_id"])
            self.assertTrue(relation["source_world_event_ids"])
            self.assertEqual(relation["context_signature"]["food_id"], "tasty_food")

    def test_compiler_is_pure_deterministic_and_agent_scoped(self):
        original = projection()
        before = copy.deepcopy(original)
        first = build_local_bias_profiles(original)
        second = build_local_bias_profiles(original)
        self.assertEqual(first, second)
        self.assertEqual(original, before)
        changed = copy.deepcopy(original)
        changed["local_bias_materials"][0]["agent_id"] = "npc_b"
        with self.assertRaisesRegex(LocalBiasProfileError, "different agent"):
            build_local_bias_profiles(changed)

    def test_finite_limit_and_strength_integrity_are_enforced(self):
        changed = projection()
        changed["local_bias_materials"] = changed["local_bias_materials"] * 9
        for index, item in enumerate(changed["local_bias_materials"]):
            item["bias_id"] = f"bias-{index}"
        with self.assertRaisesRegex(LocalBiasProfileError, "finite profile limit"):
            build_local_bias_profiles(changed)
        changed = projection()
        changed["local_bias_materials"][0]["magnitude"] = 1
        with self.assertRaisesRegex(LocalBiasProfileError, "differs from magnitude"):
            build_local_bias_profiles(changed)


if __name__ == "__main__":
    unittest.main()
