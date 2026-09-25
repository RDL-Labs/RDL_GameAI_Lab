import copy
import unittest

from runtime.t1_reconstruction import T1ReconstructionError
from test_t1_material_selection import expanded, review


def selected_for_reconstruction():
    sidecar, bundle = expanded()
    sidecar.inspect_t1_materials(
        bundle_id=bundle["bundle_id"],
        payload=review(bundle, dispositions={
            "current_M_B": "RETAIN",
            "CandidateRelation": "RETAIN",
            "Experience": "REJECT",
            "unresolved_residual": "DEFER",
        }),
    )
    return sidecar, bundle


class T1ReconstructionTests(unittest.TestCase):
    def test_reconstructs_distinct_inactive_m_b_prime_and_preserves_parent(self):
        sidecar, bundle = selected_for_reconstruction()
        old_models = copy.deepcopy(sidecar.snapshot()["models"])
        artifact = sidecar.reconstruct_t1(bundle_id=bundle["bundle_id"])
        self.assertEqual(artifact["status"], "RECONSTRUCTED_INACTIVE")
        self.assertNotEqual(artifact["model_ref"], artifact["parent_model_ref"])
        self.assertIn(artifact["parent_model_ref"], old_models)
        self.assertEqual(artifact["coefficients"], old_models[artifact["parent_model_ref"]]["coefficients"])
        self.assertEqual(artifact["biases"], old_models[artifact["parent_model_ref"]]["biases"])
        self.assertEqual(sidecar.snapshot()["models"], old_models)
        self.assertIn("not-active-not-reentry", artifact["authority"])

    def test_only_retained_candidate_becomes_adopted_relation(self):
        sidecar, bundle = selected_for_reconstruction()
        artifact = sidecar.reconstruct_t1(bundle_id=bundle["bundle_id"])
        self.assertEqual(len(artifact["adopted_relations"]), 1)
        adopted = artifact["adopted_relations"][0]
        self.assertEqual(adopted["source_candidate_id"], "candidate-a")
        self.assertEqual(adopted["status"], "adopted-in-inactive-M_B-prime")
        retained_kinds = {item["kind"] for item in artifact["retained_materials"]}
        self.assertIn("current_M_B", retained_kinds)
        self.assertIn("CandidateRelation", retained_kinds)
        self.assertNotIn("Experience", retained_kinds)

    def test_requires_retained_parent_and_candidate(self):
        for dispositions, message in (
            ({"current_M_B": "REJECT", "CandidateRelation": "RETAIN"}, "current M_B"),
            ({"current_M_B": "RETAIN", "CandidateRelation": "DEFER"}, "CandidateRelation"),
        ):
            with self.subTest(dispositions=dispositions):
                sidecar, bundle = expanded()
                sidecar.inspect_t1_materials(
                    bundle_id=bundle["bundle_id"],
                    payload=review(bundle, dispositions=dispositions),
                )
                with self.assertRaisesRegex(T1ReconstructionError, message):
                    sidecar.reconstruct_t1(bundle_id=bundle["bundle_id"])
                self.assertEqual(sidecar.snapshot()["T1_reconstruction"]["artifacts"], [])

    def test_exact_replay_is_idempotent_and_does_not_reenter(self):
        sidecar, bundle = selected_for_reconstruction()
        first = sidecar.reconstruct_t1(bundle_id=bundle["bundle_id"])
        self.assertEqual(sidecar.reconstruct_t1(bundle_id=bundle["bundle_id"]), first)
        snapshot = sidecar.snapshot()
        self.assertEqual(snapshot["T1_reconstruction"]["count"], 1)
        self.assertEqual(snapshot["M_delta"]["active_count"], 1)
        self.assertIn("re_entry", snapshot["T1_reconstruction"]["downstream_separation"])
        self.assertNotIn(first["model_ref"], snapshot["models"])


if __name__ == "__main__":
    unittest.main()
