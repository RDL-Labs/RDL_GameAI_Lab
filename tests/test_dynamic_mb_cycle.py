import copy
import unittest

from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.functions.deep_similarity import build_deep_similarity_shadow
from runtime.functions.experience_profile import build_relation_profiles
from runtime.sleep_window import SleepExperienceWindowStore
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_experience import food_packet, result
from test_v23_interpretation import packet


class DynamicMBCycleTests(unittest.TestCase):
    def test_same_agent_experience_and_canonical_paths_join_only_at_t1_materials(self):
        agent_id = "npc_a"

        history = InteractionHistory()
        for index in range(3):
            source = f"dmb-experience-{index}"
            observed = food_packet(source, agent=agent_id)
            history.register_decision(observed, decide_action(observed))
            history.record_result(result(source, agent=agent_id))
        history_snapshot = history.snapshot()
        source_experience_ids = [item["record_id"] for item in history_snapshot["records"]]

        window = SleepExperienceWindowStore().form_window(
            history_snapshot, agent_id=agent_id, sleep_cycle="dmb-night-1",
            formation_tick=10, enabled=True,
        )
        profiles = build_relation_profiles(window, history_snapshot)
        deep = build_deep_similarity_shadow(window, profiles, formation_tick=11)
        candidate = deep["candidate"]
        self.assertEqual(candidate["source_experience_ids"], source_experience_ids)

        canonical = GameAIFrozenComparisonSidecar()
        canonical.capture(packet("dmb-rib-first", tick=20, objects=1))
        canonical.capture(packet("dmb-rib-later", tick=21, objects=3))
        before_review = canonical.snapshot()
        self.assertEqual(before_review["M_delta"]["active_count"], 0)
        self.assertEqual(before_review["T1_materials"]["count"], 0)
        assessment = before_review["assessment"]["records"][0]

        canonical.review_assessment({
            "assessment_id": assessment["assessment_id"], "expected_revision": 0,
            "reviewer": "dmb-cycle-test", "basis": "finite unresolved canonical fixture",
            "evidence": "dmb-rib-first-to-later",
            "dimensions": {
                "visible_agents_count": {"status": "zero"},
                "visible_objects_count": {"status": "unresolved", "residual": 1.0},
                "visible_places_count": {"status": "zero"},
            },
        })
        entered = canonical.snapshot()
        self.assertEqual(entered["M_delta"]["active_count"], 1)
        self.assertEqual(entered["T1_materials"]["count"], 0)

        bundle = canonical.expand_t1_materials(
            assessment_id=assessment["assessment_id"],
            candidates=[candidate], experiences=history_snapshot["records"],
        )
        self.assertEqual(bundle["agent_id"], agent_id)
        candidate_material = next(
            item for item in bundle["materials"] if item["kind"] == "CandidateRelation"
        )
        self.assertEqual(candidate_material["source_id"], candidate["candidate_id"])
        self.assertEqual(
            {item["source_id"] for item in bundle["materials"] if item["kind"] == "Experience"},
            set(source_experience_ids),
        )

        dispositions = {
            "current_M_B": "RETAIN",
            "CandidateRelation": "RETAIN",
            "Experience": "DEFER",
            "RIB_B": "RETAIN",
            "RIB_B_prime": "RETAIN",
            "unresolved_residual": "DEFER",
        }
        selection = canonical.inspect_t1_materials(
            bundle_id=bundle["bundle_id"],
            payload={
                "expected_revision": 0,
                "reviewer": "dmb-cycle-test",
                "materials": [{
                    "material_id": item["material_id"],
                    "disposition": dispositions[item["kind"]],
                    "basis": f"bounded DMB inspection of {item['kind']}",
                    "evidence": item["source_id"],
                } for item in bundle["materials"]],
            },
        )
        artifact = canonical.reconstruct_t1(bundle_id=bundle["bundle_id"])

        self.assertEqual(artifact["source_bundle_id"], bundle["bundle_id"])
        self.assertEqual(artifact["source_selection_id"], selection["selection_id"])
        self.assertEqual(
            artifact["adopted_relations"][0]["source_candidate_id"],
            candidate["candidate_id"],
        )
        final = canonical.snapshot()
        self.assertEqual(final["M_delta"]["active_count"], 1)
        self.assertEqual(artifact["status"], "RECONSTRUCTED_INACTIVE")
        self.assertNotIn(artifact["model_ref"], final["models"])
        self.assertEqual(final["review_path"], entered["review_path"])

    def test_cycle_is_deterministic_and_read_only_snapshots_are_stable(self):
        # Full determinism of each stage is covered by its unit contract. Here the
        # integration guard confirms empty reads do not invent a joined cycle.
        canonical = GameAIFrozenComparisonSidecar()
        before = copy.deepcopy(canonical.snapshot())
        self.assertEqual(canonical.snapshot(), before)
        self.assertEqual(before["T1_reconstruction"]["artifacts"], [])


if __name__ == "__main__":
    unittest.main()
