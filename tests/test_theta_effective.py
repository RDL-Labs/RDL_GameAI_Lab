import copy
import unittest

from runtime.theta_effective import FiniteThetaEffectiveEvaluator, ThetaEffectiveError
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_v23_interpretation import packet


def reviewed_sidecar(evaluator=None, residual=1.0):
    sidecar = GameAIFrozenComparisonSidecar(theta_evaluator=evaluator)
    sidecar.capture(packet("theta-first", tick=1, objects=1))
    sidecar.capture(packet("theta-later", tick=2, objects=3))
    assessment = sidecar.snapshot()["assessment"]["records"][0]
    sidecar.review_assessment({
        "assessment_id": assessment["assessment_id"],
        "expected_revision": 0,
        "reviewer": "c3-test",
        "basis": "finite residual fixture",
        "evidence": "theta-first-to-later",
        "dimensions": {
            "visible_agents_count": {"status": "zero"},
            "visible_objects_count": {"status": "unresolved", "residual": residual},
            "visible_places_count": {"status": "zero"},
        },
    })
    return sidecar


class ThetaEffectiveTests(unittest.TestCase):
    def test_pending_review_is_not_compared(self):
        sidecar = GameAIFrozenComparisonSidecar()
        sidecar.capture(packet("pending-first", tick=1, objects=1))
        sidecar.capture(packet("pending-later", tick=2, objects=2))
        evaluation = sidecar.snapshot()["theta_effective"]["evaluations"][0]
        self.assertEqual(evaluation["status"], "pending_review")
        self.assertIsNone(evaluation["H"])
        self.assertIsNone(evaluation["comparison"])

    def test_reviewed_h_is_compared_without_entering_m_delta(self):
        evaluation = reviewed_sidecar(residual=1.0).snapshot()["theta_effective"]["evaluations"][0]
        self.assertEqual(evaluation["H"], 1.0)
        self.assertEqual(evaluation["theta_eff"], 1.0)
        self.assertEqual(evaluation["comparison"], "rupture_boundary_met")
        self.assertIn("not-M_delta", evaluation["authority"])

    def test_declared_relations_can_move_theta_while_h_stays_fixed(self):
        higher = FiniteThetaEffectiveEvaluator(1.0, [
            {"relation_id": "support-a", "source": "c3-fixture", "delta": 0.5},
        ])
        lower = FiniteThetaEffectiveEvaluator(1.0, [
            {"relation_id": "constraint-a", "source": "c3-fixture", "delta": -0.25},
        ])
        high_result = reviewed_sidecar(higher, residual=1.0).snapshot()["theta_effective"]["evaluations"][0]
        low_result = reviewed_sidecar(lower, residual=1.0).snapshot()["theta_effective"]["evaluations"][0]
        self.assertEqual(high_result["H"], low_result["H"])
        self.assertEqual(high_result["comparison"], "maintain")
        self.assertEqual(low_result["comparison"], "rupture_boundary_met")
        self.assertEqual(high_result["evaluation"]["relation_adjustments"][0]["source"], "c3-fixture")

    def test_theta_evaluation_does_not_change_review_path(self):
        sidecar = reviewed_sidecar()
        before = copy.deepcopy(sidecar.snapshot()["review_path"])
        sidecar.snapshot()["theta_effective"]
        self.assertEqual(sidecar.snapshot()["review_path"], before)

    def test_non_positive_effective_boundary_is_rejected_atomically(self):
        with self.assertRaises(ThetaEffectiveError):
            FiniteThetaEffectiveEvaluator(1.0, [
                {"relation_id": "invalid", "source": "test", "delta": -1.0},
            ])


if __name__ == "__main__":
    unittest.main()
