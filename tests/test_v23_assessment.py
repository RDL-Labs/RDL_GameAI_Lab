import json
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.request import Request, urlopen
from unittest.mock import patch

from runtime import bridge
from runtime.core import decide_action
from runtime.v23_assessment import AssessmentError
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_v23_interpretation import packet


class AssessmentTests(unittest.TestCase):
    def setUp(self):
        self.sidecar = GameAIFrozenComparisonSidecar()
        self.sidecar.capture(packet("a", tick=0))
        self.mismatch = self.sidecar.capture(packet("b", tick=1, agents=3, objects=4))
        self.ledger = self.sidecar.assessments
        self.record = self.ledger.snapshot()["records"][0]

    def review(self):
        return dict(assessment_id=self.record["assessment_id"], expected_revision=0,
                    reviewer="finite-test-reviewer", basis="declared fixture residual",
                    evidence="fixture:a->b", dimensions={
                        "visible_agents_count": {"status": "unresolved", "residual": 3},
                        "visible_objects_count": {"status": "unresolved", "residual": 4},
                        "visible_places_count": {"status": "zero"},
                    })

    def test_pending_reviewed_l2_and_resolution(self):
        self.assertEqual(self.record["H"], 0)
        self.assertFalse(self.record["reviewed"])
        self.assertEqual(self.ledger.review(self.review())["H"], 5)
        payload = self.review()
        payload["expected_revision"] = 1
        payload["dimensions"]["visible_agents_count"] = {"status": "resolved"}
        payload["dimensions"]["visible_objects_count"] = {"status": "unresolved", "residual": 2}
        self.assertEqual(self.ledger.review(payload)["H"], 2)

    def test_non_residual_classifications_never_enter_h(self):
        for status in ("pending", "resolved", "ordinary_temporal_change", "boundary_coverage_change"):
            payload = self.review()
            payload["expected_revision"] = self.ledger.snapshot()["records"][0]["revision"]
            for name in ("visible_agents_count", "visible_objects_count"):
                payload["dimensions"][name] = {"status": status}
            self.assertEqual(self.ledger.review(payload)["H_vec"], {})

    def test_invalid_review_is_atomic(self):
        invalid = []
        for value in (-1, 5, float("nan"), float("inf"), True):
            payload = self.review()
            payload["dimensions"]["visible_objects_count"]["residual"] = value
            invalid.append(payload)
        for field, value in (("basis", ""), ("reviewer", None), ("evidence", ""),
                             ("assessment_id", "unknown"), ("expected_revision", 9)):
            payload = self.review()
            payload[field] = value
            invalid.append(payload)
        payload = self.review()
        payload["dimensions"]["fear"] = {"status": "unresolved", "residual": 1}
        invalid.append(payload)
        before = self.ledger.snapshot()
        for payload in invalid:
            with self.assertRaises(AssessmentError):
                self.ledger.review(payload)
            self.assertEqual(before, self.ledger.snapshot())

    def test_replay_and_capacity_preserve_reviewed_residual(self):
        self.ledger.review(self.review())
        self.ledger.register(self.mismatch)
        self.assertEqual(len(self.ledger.snapshot()["records"]), 1)
        self.ledger.capacity = 1
        self.sidecar.capture(packet("c", tick=2, objects=2))
        self.assertEqual(self.ledger.snapshot()["capacity_rejections"], 1)
        self.assertEqual(self.ledger.snapshot()["records"][0]["H"], 5)

    def test_contexts_and_export_are_isolated(self):
        self.ledger.review(self.review())
        self.sidecar.capture(packet("c", tick=2, perception_rule="other"))
        self.sidecar.capture(packet("d", tick=3, objects=1, perception_rule="other"))
        records = self.ledger.snapshot()["records"]
        self.assertEqual([r["H"] for r in records], [5, 0])
        records[0]["dimensions"].clear()
        self.assertEqual(self.ledger.snapshot()["records"][0]["H"], 5)

    def test_http_observe_review_snapshot_roundtrip(self):
        with patch.object(bridge, "CANONICAL_SIDECAR", GameAIFrozenComparisonSidecar()):
            server = ThreadingHTTPServer(("127.0.0.1", 0), bridge.BridgeHandler)
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            base = f"http://127.0.0.1:{server.server_port}"
            def post(path, data):
                request = Request(base + path, json.dumps(data).encode(),
                                  {"Content-Type": "application/json"})
                with urlopen(request, timeout=3) as response:
                    return json.load(response)
            try:
                for observed in (packet("a", tick=0), packet("b", tick=1, agents=3, objects=4)):
                    self.assertEqual(post("/v1/observe", observed), decide_action(observed))
                self.assertEqual(post("/v1/assessment-review", self.review())["H"], 5)
                with urlopen(base + "/v1/canonical-snapshot", timeout=3) as response:
                    assessment = json.load(response)["assessment"]
                    self.assertEqual(assessment["records"][0]["H"], 5)
                    self.assertEqual(assessment["retained_H"][0]["H"], 5)
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_retention_sums_latest_revisions_without_signed_cancellation(self):
        self.ledger.review(self.review())
        self.sidecar.capture(packet("c", tick=2))
        second = self.ledger.snapshot()["records"][1]
        payload = self.review()
        payload["assessment_id"] = second["assessment_id"]
        self.ledger.review(payload)
        retained = self.ledger.snapshot()["retained_H"][0]
        self.assertEqual(retained["H"], 10)
        self.assertEqual(len(retained["contributions"]), 2)
        # Re-review replaces a contribution, not an additional event.
        payload["expected_revision"] = 1
        self.ledger.review(payload)
        self.assertEqual(self.ledger.snapshot()["retained_H"][0]["H"], 10)
        payload["expected_revision"] = 2
        for name in ("visible_agents_count", "visible_objects_count"):
            payload["dimensions"][name] = {"status": "resolved"}
        self.ledger.review(payload)
        self.assertEqual(self.ledger.snapshot()["retained_H"][0]["H"], 5)
        self.sidecar.capture(packet("later", tick=10000))
        self.assertEqual(self.ledger.snapshot()["retained_H"][0]["H"], 5)

    def test_retention_is_separate_for_context_and_model(self):
        from dataclasses import replace
        self.ledger.review(self.review())
        other = replace(self.mismatch, model_ref="different-frozen-model")
        other_id = self.ledger.register(other)
        payload = self.review()
        payload["assessment_id"] = other_id
        self.ledger.review(payload)
        self.sidecar.capture(packet("c", tick=2, perception_rule="other"))
        self.sidecar.capture(packet("d", tick=3, objects=2, perception_rule="other"))
        self.assertEqual([g["H"] for g in self.ledger.snapshot()["retained_H"]], [5, 5, 0])

    def test_nonadjacent_replay_does_not_manufacture_reverse_comparison(self):
        self.ledger.review(self.review())
        self.assertIsNone(self.sidecar.capture(packet("a", tick=0)))
        self.assertIsNone(self.sidecar.capture(packet("b", tick=1, agents=3, objects=4)))
        snapshot = self.sidecar.snapshot()
        self.assertEqual(snapshot["comparisons"], 1)
        self.assertEqual(snapshot["latest_sections"]["npc_a"]["source_observation_id"], "b")
        self.assertEqual(snapshot["assessment"]["retained_H"][0]["H"], 5)

    def test_out_of_order_rejected_but_distinct_same_tick_allowed(self):
        self.assertIsNone(self.sidecar.capture(packet("old", tick=0)))
        self.assertIsNotNone(self.sidecar.capture(packet("same-tick", tick=1, objects=2)))
        snapshot = self.sidecar.snapshot()
        self.assertEqual(snapshot["comparisons"], 2)
        self.assertIn("precedes", snapshot["failures"][0]["error"])

    def test_capacity_and_restart_are_explicit(self):
        self.ledger.review(self.review())
        self.ledger.capacity = 1
        self.sidecar.capture(packet("c", tick=2))
        self.assertEqual(self.ledger.snapshot()["retained_H"][0]["H"], 5)
        self.assertEqual(self.ledger.snapshot()["capacity_rejections"], 1)
        self.assertEqual(GameAIFrozenComparisonSidecar().assessments.snapshot()["retained_H"], [])

    def test_numeric_overflow_is_reported_without_nonfinite_json(self):
        from dataclasses import replace
        for index in range(2):
            mismatch = replace(self.mismatch, later_section_id=f"large-{index}",
                               deltas={"visible_agents_count": 0, "visible_objects_count": 1e308,
                                       "visible_places_count": 0})
            payload = self.review()
            payload["assessment_id"] = self.ledger.register(mismatch)
            payload["dimensions"]["visible_agents_count"] = {"status": "zero"}
            payload["dimensions"]["visible_objects_count"]["residual"] = 1e308
            self.ledger.review(payload)
        snapshot = self.ledger.snapshot()
        self.assertIsNone(snapshot["retained_H"][0]["H"])
        self.assertEqual(snapshot["retained_H"][0]["status"], "numeric_overflow")
        json.dumps(snapshot, allow_nan=False)
