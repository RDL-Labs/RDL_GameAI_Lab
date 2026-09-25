import copy
import unittest

from runtime.theta_effective import FiniteThetaEffectiveEvaluator
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_v23_interpretation import packet


def form_and_review(sidecar, residual):
    sidecar.capture(packet("md-first", tick=1, objects=1))
    sidecar.capture(packet("md-later", tick=2, objects=3))
    record = sidecar.snapshot()["assessment"]["records"][0]
    sidecar.review_assessment({
        "assessment_id": record["assessment_id"],
        "expected_revision": 0,
        "reviewer": "c4-test",
        "basis": "finite transition fixture",
        "evidence": "md-first-to-later",
        "dimensions": {
            "visible_agents_count": {"status": "zero"},
            "visible_objects_count": {"status": "unresolved", "residual": residual},
            "visible_places_count": {"status": "zero"},
        },
    })


class MDeltaTransitionTests(unittest.TestCase):
    def test_below_boundary_remains_normal(self):
        sidecar = GameAIFrozenComparisonSidecar(
            theta_evaluator=FiniteThetaEffectiveEvaluator(base_theta=1.5)
        )
        form_and_review(sidecar, residual=1.0)
        state = sidecar.snapshot()["M_delta"]["states"][0]
        self.assertEqual(state["phase"], "normal")
        self.assertIsNone(state["transition"])
        self.assertEqual(sidecar.snapshot()["M_delta"]["active_count"], 0)

    def test_met_boundary_enters_m_delta_without_running_t1(self):
        sidecar = GameAIFrozenComparisonSidecar()
        form_and_review(sidecar, residual=1.0)
        snapshot = sidecar.snapshot()["M_delta"]
        state = snapshot["states"][0]
        self.assertEqual(state["phase"], "M_delta")
        self.assertEqual(state["transition"]["transition_rule"], "H >= theta_eff")
        self.assertEqual(snapshot["active_count"], 1)
        self.assertIn("T1_material_expansion", snapshot["not_implemented"])
        self.assertIn("not-T1", state["authority"])

    def test_get_style_snapshots_do_not_create_or_change_transition(self):
        sidecar = GameAIFrozenComparisonSidecar()
        sidecar.capture(packet("read-first", tick=1, objects=1))
        sidecar.capture(packet("read-later", tick=2, objects=3))
        self.assertEqual(sidecar.snapshot()["M_delta"]["states"], [])
        self.assertEqual(sidecar.snapshot()["M_delta"]["states"], [])
        form = sidecar.snapshot()["assessment"]["records"][0]
        sidecar.review_assessment({
            "assessment_id": form["assessment_id"], "expected_revision": 0,
            "reviewer": "c4-test", "basis": "explicit review", "evidence": "read-pair",
            "dimensions": {
                "visible_agents_count": {"status": "zero"},
                "visible_objects_count": {"status": "unresolved", "residual": 1.0},
                "visible_places_count": {"status": "zero"},
            },
        })
        before = copy.deepcopy(sidecar.snapshot()["M_delta"])
        self.assertEqual(sidecar.snapshot()["M_delta"], before)

    def test_active_m_delta_is_not_silently_released_by_later_review(self):
        sidecar = GameAIFrozenComparisonSidecar()
        form_and_review(sidecar, residual=1.0)
        active = copy.deepcopy(sidecar.snapshot()["M_delta"]["states"][0])
        assessment_id = sidecar.snapshot()["assessment"]["records"][0]["assessment_id"]
        sidecar.review_assessment({
            "assessment_id": assessment_id, "expected_revision": 1,
            "reviewer": "c4-test", "basis": "resolved reassessment", "evidence": "same-pair-r2",
            "dimensions": {
                "visible_agents_count": {"status": "zero"},
                "visible_objects_count": {"status": "resolved"},
                "visible_places_count": {"status": "zero"},
            },
        })
        self.assertEqual(sidecar.snapshot()["M_delta"]["states"][0], active)


if __name__ == "__main__":
    unittest.main()
