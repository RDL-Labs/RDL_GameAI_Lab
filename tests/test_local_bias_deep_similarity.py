import copy
import unittest

from runtime.functions.local_bias_deep_similarity import (
    LocalBiasDeepSimilarityError,
    build_local_bias_deep_shadow,
)
from runtime.functions.local_bias_profile import build_local_bias_profiles
from runtime.outcome_bias import LocalBiasStore, OutcomeGradientStore
from tests.test_outcome_bias import source


def profile_set(agent_id="npc_a", mixed=True):
    bias_store = LocalBiasStore()
    for index in range(3):
        experience = source(agent_id, injury=mixed)
        experience["record_id"] = f"{experience['record_id']}-{index}"
        experience["source_event_id"] = f"{experience['source_event_id']}-{index}"
        gradient = OutcomeGradientStore().form(experience, {
            "food_acquired": True, "returned_to_base": True,
            "injury_level": "severe" if mixed else "none", "reward_value": "HIGH",
        })
        bias_store.form(gradient)
    return build_local_bias_profiles(bias_store.sleep_projection(agent_id))


class LocalBiasDeepSimilarityTests(unittest.TestCase):
    def test_repeated_mixed_outcomes_form_one_non_net_shadow_candidate(self):
        result = build_local_bias_deep_shadow(
            profile_set(), sleep_cycle="night-bias-1", formation_tick=20
        )
        self.assertEqual(result["status"], "CANDIDATE_FORMED")
        candidate = result["candidate"]
        common = {(item["relation"], item["direction"], item["strength"])
                  for item in candidate["common_bias_relations"]}
        self.assertIn(("reward_value", "positive", "STRONG"), common)
        self.assertIn(("injury", "negative", "STRONG"), common)
        self.assertNotIn("net_score", str(candidate))
        self.assertIn("not-truth-T1-M_B-H-or-action", candidate["authority"])

    def test_candidate_retains_all_bias_experience_and_world_event_sources(self):
        profiles = profile_set()
        result = build_local_bias_deep_shadow(
            profiles, sleep_cycle="night-bias-2", formation_tick=21
        )
        candidate = result["candidate"]
        self.assertEqual(set(candidate["source_experience_ids"]),
                         set(profiles["source_experience_ids"]))
        self.assertEqual(set(candidate["source_bias_ids"]), set(profiles["source_bias_ids"]))
        self.assertEqual(len(candidate["source_world_event_ids"]), 3)

    def test_opposing_direction_is_conflict_not_automatic_resolution(self):
        profiles = profile_set(mixed=False)
        changed = copy.deepcopy(profiles)
        relation = next(item for item in changed["profiles"][0]["relations"]
                        if item["relation"] == "acquisition")
        relation["direction"] = "negative"
        result = build_local_bias_deep_shadow(
            changed, sleep_cycle="night-bias-3", formation_tick=22
        )
        self.assertTrue(any(item["conflicts"] for item in result["similarity_observations"]))
        self.assertFalse(any(item["relation"] == "acquisition"
                             for item in result["candidate"]["common_bias_relations"]))

    def test_cross_agent_and_insufficient_profiles_are_rejected(self):
        profiles = profile_set()
        changed = copy.deepcopy(profiles)
        changed["profiles"][0]["agent_id"] = "npc_b"
        with self.assertRaisesRegex(LocalBiasDeepSimilarityError, "different agent"):
            build_local_bias_deep_shadow(changed, sleep_cycle="night", formation_tick=1)
        changed = copy.deepcopy(profiles)
        changed["profiles"] = changed["profiles"][:2]
        with self.assertRaisesRegex(LocalBiasDeepSimilarityError, "three to six"):
            build_local_bias_deep_shadow(changed, sleep_cycle="night", formation_tick=1)

    def test_duplicate_sources_and_oversized_windows_are_rejected(self):
        profiles = profile_set()
        changed = copy.deepcopy(profiles)
        changed["profiles"][1]["profile_id"] = changed["profiles"][0]["profile_id"]
        with self.assertRaisesRegex(LocalBiasDeepSimilarityError, "distinct Profile sources"):
            build_local_bias_deep_shadow(changed, sleep_cycle="night", formation_tick=1)

        changed = copy.deepcopy(profiles)
        changed["profiles"] = [copy.deepcopy(changed["profiles"][0]) for _ in range(7)]
        for index, item in enumerate(changed["profiles"]):
            item["profile_id"] = f"profile-{index}"
            item["source_experience_id"] = f"experience-{index}"
        with self.assertRaisesRegex(LocalBiasDeepSimilarityError, "three to six"):
            build_local_bias_deep_shadow(changed, sleep_cycle="night", formation_tick=1)


if __name__ == "__main__":
    unittest.main()
