import copy
import unittest

from runtime.core import decide_action
from runtime.v23_acquisition import DEFAULT_DIMENSIONS, GameAIBoundary, acquire_rib_section
from runtime.v23_food_admission import (
    FoodAdmissionError,
    FoodNeedShadowComparisonSidecar,
    form_food_need_mb_relation,
)


def food_packet():
    return {
        "observation_id": "obs-food-1",
        "tick": 7,
        "agent_id": "npc_a",
        "observation": {
            "perception_rule": "radius-145",
            "visible_agents": [],
            "visible_objects": [
                {"id": "food_01", "kind": "food"},
                {"id": "food_named_only", "label": "food"},
                {"id": "stone_01", "kind": "object"},
            ],
            "visible_places": [],
            "body": {
                "agent_id": "npc_a",
                "snapshot_id": "body-npc_a-r3",
                "revision": 3,
                "movement_scale": 1.0,
                "food_need": 0.8,
                "held_food_ids": [],
                "food_actions_enabled": True,
            },
        },
    }


def food_boundary():
    return GameAIBoundary(
        boundary_id="gameai:npc_a:food-admission-shadow",
        purpose="food-need-admission-shadow",
        dimensions=("visible_food_count",),
        conditions={"perception_rule": "radius-145", "profile": "food-shadow-v1"},
    )


class FoodMBAdmissionTests(unittest.TestCase):
    def test_visible_food_count_is_explicit_and_not_in_default_boundary(self):
        packet = food_packet()
        default_section = acquire_rib_section(packet)
        food_section = acquire_rib_section(packet, boundary=food_boundary())

        self.assertEqual(default_section.boundary.dimensions, DEFAULT_DIMENSIONS)
        self.assertNotIn("visible_food_count", default_section.values)
        self.assertEqual(food_section.values, {"visible_food_count": 1.0})

    def test_forms_deterministic_immutable_relation(self):
        packet = food_packet()
        relation = form_food_need_mb_relation(packet, food_boundary())
        repeated = form_food_need_mb_relation(copy.deepcopy(packet), food_boundary())

        self.assertEqual(relation.model_ref, repeated.model_ref)
        self.assertEqual(relation.coefficient, 0.8)
        self.assertEqual(relation.input_dimension, "visible_food_count")
        self.assertEqual(relation.output_dimension, "visible_food_salience")
        self.assertEqual(relation.source.body_snapshot_id, "body-npc_a-r3")
        self.assertEqual(relation.to_json()["authority"], "formation-only-no-registration")
        with self.assertRaises(TypeError):
            relation.provenance["formation"] = "changed"
        with self.assertRaises(TypeError):
            relation.boundary.conditions["profile"] = "changed"

    def test_source_or_boundary_change_gets_distinct_model_ref(self):
        baseline = form_food_need_mb_relation(food_packet(), food_boundary())
        changed_packet = food_packet()
        changed_packet["observation"]["body"]["food_need"] = 0.2
        changed_packet["observation"]["body"]["revision"] = 4
        changed_packet["observation"]["body"]["snapshot_id"] = "body-npc_a-r4"
        changed_source = form_food_need_mb_relation(changed_packet, food_boundary())
        changed_boundary = GameAIBoundary(
            boundary_id="gameai:npc_a:food-admission-shadow",
            purpose="food-need-admission-shadow",
            dimensions=("visible_food_count",),
            conditions={"perception_rule": "radius-90", "profile": "food-shadow-v1"},
        )
        changed_context = form_food_need_mb_relation(food_packet(), changed_boundary)

        self.assertNotEqual(baseline.model_ref, changed_source.model_ref)
        self.assertNotEqual(baseline.model_ref, changed_context.model_ref)

    def test_rejects_invalid_or_incomplete_source(self):
        cases = [
            ("snapshot_id", ""),
            ("snapshot_id", 3),
            ("revision", -1),
            ("revision", True),
            ("food_need", -0.1),
            ("food_need", 1.1),
            ("food_need", float("nan")),
            ("food_need", True),
        ]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                packet = food_packet()
                packet["observation"]["body"][field] = value
                with self.assertRaises(FoodAdmissionError):
                    form_food_need_mb_relation(packet, food_boundary())

    def test_rejects_wrong_owner_and_boundary_without_food_dimension(self):
        packet = food_packet()
        packet["observation"]["body"]["agent_id"] = "npc_b"
        with self.assertRaises(FoodAdmissionError):
            form_food_need_mb_relation(packet, food_boundary())
        with self.assertRaises(FoodAdmissionError):
            form_food_need_mb_relation(food_packet(), GameAIBoundary(
                boundary_id="legacy", purpose="legacy",
                dimensions=("visible_objects_count",),
            ))
        with self.assertRaises(FoodAdmissionError):
            form_food_need_mb_relation(food_packet(), None)

    def test_pure_formation_does_not_change_packet_or_action(self):
        packet = food_packet()
        before = copy.deepcopy(packet)
        action = decide_action(copy.deepcopy(packet))

        form_food_need_mb_relation(packet, food_boundary())

        self.assertEqual(packet, before)
        self.assertEqual(decide_action(copy.deepcopy(packet)), action)

    def test_shadow_window_uses_same_frozen_food_need_for_f_and_fprime(self):
        first = food_packet()
        sidecar = FoodNeedShadowComparisonSidecar()
        window_id = sidecar.open_window(first, food_boundary())
        later = food_packet()
        later["observation_id"] = "obs-food-2"
        later["tick"] = 8
        later["observation"]["visible_objects"] = []
        later["observation"]["body"]["food_need"] = 0.2
        later["observation"]["body"]["revision"] = 4
        later["observation"]["body"]["snapshot_id"] = "body-npc_a-r4"

        mismatch = sidecar.compare_later(window_id, later)
        window = sidecar.snapshot()["windows"][window_id]

        self.assertEqual(window["F"]["values"], {"visible_food_salience": 0.8})
        self.assertEqual(window["F_prime"]["values"], {"visible_food_salience": 0.0})
        self.assertEqual(mismatch.deltas, {"visible_food_salience": -0.8})
        self.assertEqual(window["relation"]["source"]["food_need"], 0.8)
        self.assertEqual(window["next_relation_candidate"]["source"]["food_need"], 0.2)
        self.assertNotEqual(window["model_ref"], window["next_relation_candidate"]["model_ref"])

    def test_same_rib_under_different_preformed_models_yields_different_f(self):
        low = food_packet()
        low["observation_id"] = "obs-low"
        low["observation"]["body"]["food_need"] = 0.2
        high = food_packet()
        high["observation_id"] = "obs-high"
        sidecar = FoodNeedShadowComparisonSidecar()
        low_id = sidecar.open_window(low, food_boundary())
        high_id = sidecar.open_window(high, food_boundary())
        windows = sidecar.snapshot()["windows"]

        self.assertEqual(windows[low_id]["F"]["values"]["visible_food_salience"], 0.2)
        self.assertEqual(windows[high_id]["F"]["values"]["visible_food_salience"], 0.8)
        self.assertNotEqual(windows[low_id]["model_ref"], windows[high_id]["model_ref"])

    def test_shadow_window_is_single_use_and_rejects_same_observation(self):
        sidecar = FoodNeedShadowComparisonSidecar()
        window_id = sidecar.open_window(food_packet(), food_boundary())
        with self.assertRaises(FoodAdmissionError):
            sidecar.compare_later(window_id, food_packet())
        window = sidecar.snapshot()["windows"][window_id]
        self.assertEqual(window["status"], "rejected")
        with self.assertRaises(FoodAdmissionError):
            sidecar.compare_later(window_id, food_packet())

    def test_shadow_snapshot_has_no_assessment_or_action_authority(self):
        sidecar = FoodNeedShadowComparisonSidecar()
        sidecar.open_window(food_packet(), food_boundary())
        snapshot = sidecar.snapshot()

        self.assertEqual(snapshot["authority"], "shadow-diagnostic-only")
        self.assertNotIn("assessment", snapshot)
        self.assertIn("assessment-H", snapshot["not_implemented"])
        self.assertIn("action-authority", snapshot["not_implemented"])

    def test_invalid_next_source_does_not_invalidate_frozen_comparison(self):
        sidecar = FoodNeedShadowComparisonSidecar()
        window_id = sidecar.open_window(food_packet(), food_boundary())
        later = food_packet()
        later["observation_id"] = "obs-food-2"
        later["tick"] = 8
        later["observation"]["body"]["food_need"] = 2.0

        mismatch = sidecar.compare_later(window_id, later)
        window = sidecar.snapshot()["windows"][window_id]

        self.assertEqual(mismatch.deltas, {"visible_food_salience": 0.0})
        self.assertEqual(window["status"], "compared")
        self.assertIsNone(window["next_relation_candidate"])
        self.assertIn("food_need", window["next_relation_candidate_error"])

    def test_shadow_window_capacity_is_finite(self):
        sidecar = FoodNeedShadowComparisonSidecar(max_windows=1)
        sidecar.open_window(food_packet(), food_boundary())
        second = food_packet()
        second["observation_id"] = "obs-food-other"
        with self.assertRaises(FoodAdmissionError):
            sidecar.open_window(second, food_boundary())
        self.assertEqual(sidecar.snapshot()["capacity_rejections"], 1)


if __name__ == "__main__":
    unittest.main()
