import copy
import unittest

from runtime.core import decide_action
from runtime.functions.deep_similarity import build_deep_similarity_shadow
from runtime.functions.experience_profile import build_relation_profiles
from runtime.sleep_window import SleepExperienceWindowStore
from runtime.experience import InteractionHistory
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_experience import food_packet, result
from test_v23_interpretation import packet


class ReviewPathProjectionTests(unittest.TestCase):
    def test_pending_then_reviewed_path_preserves_full_canonical_chain(self):
        sidecar = GameAIFrozenComparisonSidecar()
        first = packet("c2-first", agents=0, objects=1, places=0, tick=1)
        later = packet("c2-later", agents=0, objects=3, places=0, tick=2)
        sidecar.capture(first)
        sidecar.capture(later)
        snapshot = sidecar.snapshot()
        path = snapshot["review_path"]["paths"][0]
        self.assertEqual(path["RIB_B"]["source_observation_id"], "c2-first")
        self.assertEqual(path["F"]["source_observation_id"], "c2-first")
        self.assertEqual(path["RIB_B_prime"]["source_observation_id"], "c2-later")
        self.assertEqual(path["F_prime"]["source_observation_id"], "c2-later")
        self.assertEqual(path["E"]["deltas"]["visible_objects_count"], 2.0)
        self.assertEqual(path["review"], {
            "status": "pending", "revision": 0,
            "dimensions": snapshot["assessment"]["records"][0]["dimensions"],
            "provenance": None,
        })
        assessment_id = path["assessment_id"]
        reviewed = sidecar.review_assessment({
            "assessment_id": assessment_id, "expected_revision": 0,
            "reviewer": "c2-test", "basis": "finite unresolved fixture",
            "evidence": "c2-first-to-later",
            "dimensions": {
                "visible_agents_count": {"status": "zero"},
                "visible_objects_count": {"status": "unresolved", "residual": 1.0},
                "visible_places_count": {"status": "zero"},
            },
        })
        path = sidecar.snapshot()["review_path"]["paths"][0]
        self.assertEqual(path["review"]["status"], "reviewed")
        self.assertEqual(path["review"]["revision"], 1)
        self.assertEqual(path["H_vec"], {"visible_objects_count": 1.0})
        self.assertEqual(path["H"], reviewed["H"])
        self.assertIn("not-candidate-theta-M_delta", path["authority"])

    def test_sleep_candidate_does_not_enter_review_path(self):
        sidecar = GameAIFrozenComparisonSidecar()
        sidecar.capture(packet("only-canonical-a", objects=1, tick=1))
        sidecar.capture(packet("only-canonical-b", objects=2, tick=2))
        before = copy.deepcopy(sidecar.snapshot()["review_path"])

        history = InteractionHistory()
        for source in ("local-a", "local-b", "local-c"):
            observed = food_packet(source)
            history.register_decision(observed, decide_action(observed))
            history.record_result(result(source))
        window = SleepExperienceWindowStore().form_window(
            history.snapshot(), agent_id="npc_a", sleep_cycle="night-local",
            formation_tick=10, enabled=True,
        )
        profiles = build_relation_profiles(window, history.snapshot())
        candidate = build_deep_similarity_shadow(window, profiles, formation_tick=11)["candidate"]
        self.assertIsNotNone(candidate)
        self.assertEqual(sidecar.snapshot()["review_path"], before)
        self.assertEqual(before["excluded_sources"], [
            "raw_experience", "sleep_candidate", "fast_retrieval"
        ])


if __name__ == "__main__":
    unittest.main()
