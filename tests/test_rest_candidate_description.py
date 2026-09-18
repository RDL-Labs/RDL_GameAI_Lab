import unittest

from runtime.core import ObservationError
from runtime.rest_candidate_description import RestCandidateDescriptionAdapter
from runtime.rest_target_selection import RestTargetSelectionPolicy


class RestCandidateDescriptionTests(unittest.TestCase):
    def places(self):
        return [
            {"id": "plaza", "rest_capable": True, "rest_safety": "safe",
             "rest_distance_band": "near", "within_reach": False},
            {"id": "z_grove", "rest_capable": True, "rest_safety": "uncertain",
             "rest_distance_band": "near", "within_reach": False},
        ]

    def sidecar(self, level):
        return {
            "schema_version": "rho-observation-resolution-packet-v1",
            "domains": {"rest": {
                "level": level,
                "rule_version": "rho-rest-projection-v1",
                "selection": {"selection_profile_version": "rho-profile-selection-v1"},
            }},
        }

    def test_low_masks_candidate_difference_and_high_preserves_it(self):
        adapter = RestCandidateDescriptionAdapter()
        selector = RestTargetSelectionPolicy()
        low = adapter.describe(self.places(), self.sidecar("LOW"))
        high = adapter.describe(self.places(), self.sidecar("HIGH"))

        self.assertEqual({item["rest_safety"] for item in low["descriptions"]}, {"unknown"})
        self.assertEqual(selector.select(low["descriptions"])["selected"]["target_id"], "z_grove")
        self.assertEqual(selector.select(high["descriptions"])["selected"]["target_id"], "plaza")
        self.assertIn("not-selection", low["authority"])

    def test_mid_preserves_distance_but_not_safety(self):
        places = self.places()
        places[1]["rest_distance_band"] = "far"
        mid = RestCandidateDescriptionAdapter().describe(places, self.sidecar("MID"))
        by_id = {item["id"]: item for item in mid["descriptions"]}
        self.assertEqual(by_id["z_grove"]["rest_distance_band"], "far")
        self.assertEqual(by_id["plaza"]["rest_safety"], "unknown")

    def test_missing_or_wrong_provenance_fails_closed(self):
        adapter = RestCandidateDescriptionAdapter()
        with self.assertRaises(ObservationError):
            adapter.describe(self.places(), {})
        invalid = self.sidecar("HIGH")
        invalid["domains"]["rest"]["rule_version"] = "rho-rest-projection-v2"
        with self.assertRaises(ObservationError):
            adapter.describe(self.places(), invalid)


if __name__ == "__main__":
    unittest.main()
