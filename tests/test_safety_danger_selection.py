import unittest

from runtime.safety_danger_selection import DangerSelectionError, SafetyDangerSelectionPolicy


class SafetyDangerSelectionPolicyTests(unittest.TestCase):
    def test_highest_severity_is_selected(self):
        result = SafetyDangerSelectionPolicy().select([
            {"danger_id": "marsh", "severity": "medium"},
            {"danger_id": "gully", "severity": "high"},
            {"danger_id": "brush", "severity": "low"},
        ])
        self.assertEqual(result["selected"], {"danger_id": "gully", "severity": "high"})

    def test_id_breaks_equal_severity_tie(self):
        result = SafetyDangerSelectionPolicy().select([
            {"danger_id": "z_threat", "severity": "high"},
            {"danger_id": "a_threat", "severity": "high"},
        ])
        self.assertEqual(result["selected"]["danger_id"], "a_threat")

    def test_invalid_or_duplicate_candidates_are_rejected(self):
        for candidates in (
            [{"danger_id": "a", "severity": "extreme"}],
            [
                {"danger_id": "a", "severity": "low"},
                {"danger_id": "a", "severity": "high"},
            ],
        ):
            with self.assertRaises(DangerSelectionError):
                SafetyDangerSelectionPolicy().select(candidates)
