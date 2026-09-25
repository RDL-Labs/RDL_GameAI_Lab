import copy
import unittest

from runtime.functions.local_bias_deep_similarity import build_local_bias_deep_shadow
from runtime.functions.local_bias_t1_projection import (
    LocalBiasT1ProjectionError,
    project_local_bias_candidate,
)
from runtime.theta_effective import FiniteThetaEffectiveEvaluator
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from tests.test_local_bias_deep_similarity import profile_set


def mixed_candidate():
    return build_local_bias_deep_shadow(
        profile_set(), sleep_cycle="night-bias-t1", formation_tick=30
    )["candidate"]


def packet(observation_id, tick, objects):
    return {
        "observation_id": observation_id,
        "tick": tick,
        "agent_id": "npc_a",
        "observation": {
            "perception_rule": "distance <= 145.0",
            "visible_agents": [],
            "visible_objects": [{"id": f"obj_{index}"} for index in range(objects)],
            "visible_places": [],
        },
    }


def reviewed_sidecar():
    sidecar = GameAIFrozenComparisonSidecar(
        theta_evaluator=FiniteThetaEffectiveEvaluator(1.0)
    )
    sidecar.capture(packet("bias-t1-first", 1, 1))
    sidecar.capture(packet("bias-t1-later", 2, 3))
    record = sidecar.snapshot()["assessment"]["records"][0]
    sidecar.review_assessment({
        "assessment_id": record["assessment_id"],
        "expected_revision": 0,
        "reviewer": "local-bias-t1-test",
        "basis": "finite Local Bias T1 projection fixture",
        "evidence": "bias-t1-first-to-later",
        "dimensions": {
            "visible_agents_count": {"status": "zero"},
            "visible_objects_count": {"status": "unresolved", "residual": 1.0},
            "visible_places_count": {"status": "zero"},
        },
    })
    return sidecar, record["assessment_id"]


class LocalBiasT1ProjectionTests(unittest.TestCase):
    def test_mixed_candidate_becomes_independently_inspectable_children(self):
        source = mixed_candidate()
        projected = project_local_bias_candidate(source)
        signatures = {
            (item["common_relation_signature"]["relation"],
             item["common_relation_signature"]["direction"]): item
            for item in projected
        }
        self.assertIn(("reward_value", "positive"), signatures)
        self.assertIn(("injury", "negative"), signatures)
        self.assertEqual(len(projected), len(source["common_bias_relations"]))
        self.assertEqual(len({item["candidate_id"] for item in projected}), len(projected))
        self.assertTrue(all(item["source_local_bias_candidate_id"] == source["candidate_id"]
                            for item in projected))

    def test_projection_preserves_provenance_and_is_deterministic(self):
        source = mixed_candidate()
        first = project_local_bias_candidate(source)
        self.assertEqual(first, project_local_bias_candidate(source))
        for item in first:
            self.assertEqual(item["source_experience_ids"], source["source_experience_ids"])
            self.assertEqual(item["source_bias_ids"], source["source_bias_ids"])
            self.assertEqual(item["source_world_event_ids"], source["source_world_event_ids"])
            self.assertIn("not-expanded-selected-adopted", item["authority"])

    def test_explicit_t1_expansion_keeps_every_child_uninspected(self):
        projected = project_local_bias_candidate(mixed_candidate())
        sidecar, assessment_id = reviewed_sidecar()
        bundle = sidecar.expand_t1_materials(
            assessment_id=assessment_id, candidates=projected
        )
        materials = [item for item in bundle["materials"]
                     if item["kind"] == "CandidateRelation"]
        self.assertEqual(len(materials), len(projected))
        self.assertTrue(all(item["disposition"] == "UNINSPECTED" for item in materials))
        self.assertEqual(bundle["counts"]["candidates"], len(projected))

    def test_invalid_source_and_duplicate_relation_are_rejected(self):
        source = mixed_candidate()
        changed = copy.deepcopy(source)
        changed["agent_id"] = ""
        with self.assertRaisesRegex(LocalBiasT1ProjectionError, "agent_id"):
            project_local_bias_candidate(changed)
        changed = copy.deepcopy(source)
        changed["common_bias_relations"].append(
            copy.deepcopy(changed["common_bias_relations"][0])
        )
        with self.assertRaisesRegex(LocalBiasT1ProjectionError, "unique"):
            project_local_bias_candidate(changed)


if __name__ == "__main__":
    unittest.main()
