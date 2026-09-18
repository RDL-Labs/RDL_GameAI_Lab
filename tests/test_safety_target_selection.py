import unittest

from runtime.safety_target_selection import SafetySelectionError, SafetyTargetSelectionPolicy


class SafetyTargetSelectionPolicyTests(unittest.TestCase):
    def test_safety_precedes_distance(self):
        result = SafetyTargetSelectionPolicy().select([
            {"target_id": "near_uncertain", "safety": "uncertain", "distance_band": "near"},
            {"target_id": "far_safe", "safety": "safe", "distance_band": "far"},
        ])
        self.assertEqual(result["selected"]["target_id"], "far_safe")

    def test_distance_breaks_equal_safety_tie(self):
        result = SafetyTargetSelectionPolicy().select([
            {"target_id": "far_safe", "safety": "safe", "distance_band": "far"},
            {"target_id": "near_safe", "safety": "safe", "distance_band": "near"},
        ])
        self.assertEqual(result["selected"]["target_id"], "near_safe")

    def test_invalid_or_duplicate_candidates_are_rejected(self):
        for candidates in (
            [{"target_id": "a", "safety": "unsafe", "distance_band": "near"}],
            [
                {"target_id": "a", "safety": "safe", "distance_band": "near"},
                {"target_id": "a", "safety": "safe", "distance_band": "far"},
            ],
        ):
            with self.assertRaises(SafetySelectionError):
                SafetyTargetSelectionPolicy().select(candidates)
