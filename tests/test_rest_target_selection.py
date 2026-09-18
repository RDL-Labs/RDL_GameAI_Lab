import unittest

from runtime.core import ObservationError
from runtime.rest_target_selection import RestTargetSelectionPolicy


class RestTargetSelectionPolicyTests(unittest.TestCase):
    def test_safety_precedes_distance(self):
        result = RestTargetSelectionPolicy().select([
            {"id": "uncertain_near", "rest_capable": True,
             "rest_safety": "uncertain", "rest_distance_band": "within_reach"},
            {"id": "safe_far", "rest_capable": True,
             "rest_safety": "safe", "rest_distance_band": "far"},
        ])
        self.assertEqual(result["selected"]["target_id"], "safe_far")
        self.assertIn("not-rho", result["authority"])

    def test_distance_breaks_equal_safety_tie(self):
        result = RestTargetSelectionPolicy().select([
            {"id": "safe_far", "rest_capable": True,
             "rest_safety": "safe", "rest_distance_band": "far"},
            {"id": "safe_near", "rest_capable": True,
             "rest_safety": "safe", "rest_distance_band": "near"},
        ])
        self.assertEqual(result["selected"]["target_id"], "safe_near")

    def test_unreachable_is_excluded_and_invalid_distinction_rejected(self):
        result = RestTargetSelectionPolicy().select([
            {"id": "blocked", "rest_capable": True,
             "rest_safety": "safe", "rest_distance_band": "unreachable"},
        ])
        self.assertEqual(result, {})
        with self.assertRaises(ObservationError):
            RestTargetSelectionPolicy().select([
                {"id": "mystery", "rest_capable": True,
                 "rest_safety": "perfect", "rest_distance_band": "near"},
            ])


if __name__ == "__main__":
    unittest.main()
