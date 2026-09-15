import unittest

from runtime.core import decide_action
from runtime.v23_acquisition import acquire_rib_section
from runtime.v23_interpretation import (
    FrozenGameAIMB,
    GameAIFrozenComparisonSidecar,
    InterpretationError,
    build_diagnostic_frozen_mb,
    compare_interpretations,
)


def packet(
    observation_id: str,
    *,
    tick: int,
    agents: int = 0,
    objects: int = 0,
    places: int = 0,
    perception_rule: str = "distance <= 145.0",
):
    return {
        "observation_id": observation_id,
        "tick": tick,
        "agent_id": "npc_a",
        "observation": {
            "perception_rule": perception_rule,
            "visible_agents": [{"id": f"npc_{i}"} for i in range(agents)],
            "visible_objects": [{"id": f"obj_{i}"} for i in range(objects)],
            "visible_places": [{"id": f"place_{i}"} for i in range(places)],
        },
    }


class V23InterpretationTests(unittest.TestCase):
    def test_same_frozen_mb_forms_f_fprime_and_e(self):
        first = acquire_rib_section(packet("obs-1", tick=1, objects=1))
        later = acquire_rib_section(packet("obs-2", tick=2, objects=2, places=1))
        model = build_diagnostic_frozen_mb(first)

        f = model.interpret(first)
        f_prime = model.interpret(later)
        mismatch = compare_interpretations(f, f_prime)

        self.assertEqual(f.model_ref, f_prime.model_ref)
        self.assertEqual(mismatch.model_ref, model.model_ref)
        self.assertEqual(mismatch.deltas["visible_objects_count"], 1.0)
        self.assertEqual(mismatch.deltas["visible_places_count"], 1.0)
        self.assertIn("visible_objects_count", mismatch.nonzero_dimensions)
        self.assertEqual(mismatch.to_json()["status"], "E-only-not-reviewed")

    def test_model_drift_is_rejected(self):
        first = acquire_rib_section(packet("obs-1", tick=1, objects=1))
        later = acquire_rib_section(packet("obs-2", tick=2, objects=2))
        model_a = build_diagnostic_frozen_mb(first)
        model_b = FrozenGameAIMB(
            agent_id=first.agent_id,
            model_ref="different-model-ref",
            boundary=first.boundary,
            coefficients={dimension: 1.0 for dimension in first.boundary.dimensions},
            biases={dimension: 0.0 for dimension in first.boundary.dimensions},
        )

        with self.assertRaises(InterpretationError):
            compare_interpretations(model_a.interpret(first), model_b.interpret(later))

    def test_boundary_condition_change_breaks_window(self):
        first = acquire_rib_section(packet("obs-1", tick=1, objects=1, perception_rule="radius-145"))
        changed = acquire_rib_section(packet("obs-2", tick=2, objects=1, perception_rule="radius-90"))
        model = build_diagnostic_frozen_mb(first)

        with self.assertRaises(InterpretationError):
            model.interpret(changed)

    def test_frozen_model_mappings_are_immutable(self):
        first = acquire_rib_section(packet("obs-1", tick=1, objects=1))
        model = build_diagnostic_frozen_mb(first)

        with self.assertRaises(TypeError):
            model.coefficients["visible_objects_count"] = 2.0
        with self.assertRaises(TypeError):
            model.biases["visible_objects_count"] = 1.0

    def test_same_observation_instance_cannot_form_f_fprime_pair(self):
        section = acquire_rib_section(packet("obs-1", tick=1, objects=1))
        model = build_diagnostic_frozen_mb(section)
        interpretation = model.interpret(section)

        with self.assertRaises(InterpretationError):
            compare_interpretations(interpretation, interpretation)

    def test_sidecar_creates_e_only_after_second_same_context_section(self):
        sidecar = GameAIFrozenComparisonSidecar()
        self.assertIsNone(sidecar.capture(packet("obs-1", tick=1, objects=1)))
        mismatch = sidecar.capture(packet("obs-2", tick=2, objects=2))

        self.assertIsNotNone(mismatch)
        snapshot = sidecar.snapshot()
        self.assertEqual(snapshot["authority"], "read-only-comparison-sidecar")
        self.assertEqual(snapshot["captures"], 2)
        self.assertEqual(snapshot["comparisons"], 1)
        self.assertIn("npc_a", snapshot["latest_E"])
        self.assertNotIn("H", snapshot["latest_E"]["npc_a"])
        self.assertIn("H", snapshot["not_implemented"])

    def test_duplicate_observation_is_not_counted_as_new_comparison(self):
        sidecar = GameAIFrozenComparisonSidecar()
        first_packet = packet("obs-1", tick=1, objects=1)
        sidecar.capture(first_packet)
        self.assertIsNone(sidecar.capture(first_packet))

        snapshot = sidecar.snapshot()
        self.assertEqual(snapshot["comparisons"], 0)
        self.assertEqual(snapshot["duplicate_observations"], 1)

    def test_different_context_gets_distinct_frozen_model_and_no_cross_context_e(self):
        sidecar = GameAIFrozenComparisonSidecar()
        sidecar.capture(packet("obs-1", tick=1, objects=1, perception_rule="radius-145"))
        result = sidecar.capture(packet("obs-2", tick=2, objects=2, perception_rule="radius-90"))

        self.assertIsNone(result)
        snapshot = sidecar.snapshot()
        self.assertEqual(snapshot["comparisons"], 0)
        self.assertEqual(len(snapshot["models"]), 2)

    def test_sidecar_does_not_change_action_decision(self):
        observed = packet("obs-1", tick=1, objects=1)
        observed["observation"]["visible_objects"][0]["kind"] = "food"
        baseline = decide_action(observed)

        sidecar = GameAIFrozenComparisonSidecar()
        sidecar.capture(observed)
        after = decide_action(observed)

        self.assertEqual(baseline, after)


if __name__ == "__main__":
    unittest.main()
