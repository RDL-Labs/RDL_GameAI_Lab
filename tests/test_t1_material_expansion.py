import copy
import unittest

from runtime.t1_material_expansion import T1MaterialExpansionError
from runtime.theta_effective import FiniteThetaEffectiveEvaluator
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_v23_interpretation import packet


def reviewed_sidecar(*, rupture=True):
    theta = 1.0 if rupture else 2.0
    sidecar = GameAIFrozenComparisonSidecar(
        theta_evaluator=FiniteThetaEffectiveEvaluator(theta)
    )
    sidecar.capture(packet("t1a-first", tick=1, objects=1))
    sidecar.capture(packet("t1a-later", tick=2, objects=3))
    record = sidecar.snapshot()["assessment"]["records"][0]
    sidecar.review_assessment({
        "assessment_id": record["assessment_id"], "expected_revision": 0,
        "reviewer": "t1a-test", "basis": "finite expansion fixture",
        "evidence": "t1a-first-to-later",
        "dimensions": {
            "visible_agents_count": {"status": "zero"},
            "visible_objects_count": {"status": "unresolved", "residual": 1.0},
            "visible_places_count": {"status": "zero"},
        },
    })
    return sidecar, record["assessment_id"]


def candidate(agent="npc_a", identity="candidate-a"):
    return {
        "candidate_id": identity,
        "agent_id": agent,
        "common_relation_signature": {
            "kind": "context", "predicate": "fixture", "object": "bounded",
            "status": "reported", "polarity": "neutral", "strength": "single_report",
        },
        "authority": "GameAI-local-shadow-candidate",
    }


def experience(agent="npc_a", identity="experience-a"):
    return {
        "record_id": identity,
        "agent_id": agent,
        "outcome": "approach_progress",
        "authority": "GameAI-local-Experience",
    }


class T1MaterialExpansionTests(unittest.TestCase):
    def test_active_m_delta_expands_typed_uninspected_materials(self):
        sidecar, assessment_id = reviewed_sidecar()
        bundle = sidecar.expand_t1_materials(
            assessment_id=assessment_id,
            candidates=[candidate()], experiences=[experience()],
        )
        self.assertEqual(bundle["status"], "EXPANDED_FOR_INSPECTION")
        self.assertEqual(bundle["counts"], {
            "canonical": 4, "candidates": 1, "experiences": 1,
        })
        self.assertEqual([item["kind"] for item in bundle["materials"]], [
            "current_M_B", "RIB_B", "RIB_B_prime", "unresolved_residual",
            "CandidateRelation", "Experience",
        ])
        self.assertTrue(all(item["disposition"] == "UNINSPECTED"
                            for item in bundle["materials"]))
        self.assertIn("not-retain-reject-defer", bundle["authority"])
        residual = bundle["materials"][3]["payload"]
        self.assertEqual(residual["H_vec"], {"visible_objects_count": 1.0})

    def test_normal_phase_cannot_expand_t1_materials(self):
        sidecar, assessment_id = reviewed_sidecar(rupture=False)
        with self.assertRaisesRegex(T1MaterialExpansionError, "active M_delta"):
            sidecar.expand_t1_materials(assessment_id=assessment_id)

    def test_foreign_agent_material_is_rejected(self):
        sidecar, assessment_id = reviewed_sidecar()
        with self.assertRaisesRegex(T1MaterialExpansionError, "different agent"):
            sidecar.expand_t1_materials(
                assessment_id=assessment_id, candidates=[candidate(agent="npc_b")]
            )

    def test_exact_replay_is_idempotent_but_changed_replay_is_rejected(self):
        sidecar, assessment_id = reviewed_sidecar()
        first = sidecar.expand_t1_materials(
            assessment_id=assessment_id, candidates=[candidate()]
        )
        self.assertEqual(sidecar.expand_t1_materials(
            assessment_id=assessment_id, candidates=[candidate()]
        ), first)
        with self.assertRaisesRegex(T1MaterialExpansionError, "changed frozen"):
            sidecar.expand_t1_materials(
                assessment_id=assessment_id,
                candidates=[candidate(identity="candidate-b")],
            )

    def test_snapshot_is_read_only_and_has_no_selection(self):
        sidecar, assessment_id = reviewed_sidecar()
        sidecar.expand_t1_materials(assessment_id=assessment_id)
        before = copy.deepcopy(sidecar.snapshot()["T1_materials"])
        self.assertEqual(sidecar.snapshot()["T1_materials"], before)
        self.assertIn("retain", before["not_implemented"])
        self.assertNotIn("selection", before["bundles"][0])


if __name__ == "__main__":
    unittest.main()
