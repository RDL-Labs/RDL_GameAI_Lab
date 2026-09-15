import copy
import unittest

from runtime.core import decide_action
from runtime.v23_acquisition import (
    AcquisitionError,
    GameAICanonicalAcquisitionSidecar,
    GameAIBoundary,
    acquire_rib_section,
)


class V23AcquisitionTests(unittest.TestCase):
    def _packet(self):
        return {
            "observation_id": "obs-000012-001-npc_a",
            "tick": 12,
            "agent_id": "npc_a",
            "observation": {
                "perception_rule": "distance <= 145.0 from agent position",
                "visible_agents": [{"id": "npc_b"}],
                "visible_objects": [{"id": "food_01", "kind": "food"}],
                "visible_places": [{"id": "plaza"}, {"id": "grove"}],
            },
        }

    def test_acquires_finite_rib_section_from_observation(self):
        section = acquire_rib_section(self._packet())

        self.assertEqual(section.source_observation_id, "obs-000012-001-npc_a")
        self.assertEqual(section.boundary.purpose, "bounded-action-context")
        self.assertEqual(
            section.values,
            {
                "visible_agents_count": 1.0,
                "visible_objects_count": 1.0,
                "visible_places_count": 2.0,
            },
        )
        self.assertEqual(section.coverage, section.boundary.dimensions)
        self.assertEqual(section.xi_status, "unrecovered-relations-remain")
        self.assertEqual(section.provenance["source"], "accepted-bounded-observation-packet")

    def test_missing_selected_dimension_is_not_invented_as_zero(self):
        packet = self._packet()
        del packet["observation"]["visible_places"]

        with self.assertRaises(AcquisitionError):
            acquire_rib_section(packet)

    def test_custom_boundary_remains_finite_and_explicit(self):
        boundary = GameAIBoundary(
            boundary_id="gameai:npc_a:agents-only",
            purpose="social-presence-check",
            dimensions=("visible_agents_count",),
            conditions={"perception_rule": "distance <= 145.0"},
        )
        section = acquire_rib_section(self._packet(), boundary=boundary)

        self.assertEqual(section.values, {"visible_agents_count": 1.0})
        self.assertIn("social-presence-check", section.context_key)

    def test_sidecar_does_not_change_existing_action_decision(self):
        packet = self._packet()
        original_packet = copy.deepcopy(packet)
        expected = decide_action(copy.deepcopy(packet))

        sidecar = GameAICanonicalAcquisitionSidecar()
        sidecar.capture(packet)
        actual = decide_action(copy.deepcopy(packet))

        self.assertEqual(actual, expected)
        self.assertEqual(packet, original_packet)

    def test_snapshot_stops_before_mb_f_e_h(self):
        sidecar = GameAICanonicalAcquisitionSidecar()
        sidecar.capture(self._packet())
        snapshot = sidecar.snapshot()

        self.assertEqual(snapshot["authority"], "read-only-acquisition-sidecar")
        self.assertEqual(snapshot["stage"], "RIB_B-acquisition-only")
        self.assertEqual(snapshot["captures"], 1)
        self.assertEqual(
            snapshot["not_implemented"],
            ["M_B", "F", "F_prime", "E", "H", "M_delta", "T1"],
        )
        latest = snapshot["latest_by_agent"]["npc_a"]
        self.assertNotIn("F", latest)
        self.assertNotIn("E", latest)
        self.assertNotIn("H", latest)


if __name__ == "__main__":
    unittest.main()
