import copy
import unittest

from runtime.model_cutover import ModelCutoverError
from test_t1_reconstruction import selected_for_reconstruction
from test_v23_interpretation import packet


def reconstructed():
    sidecar, bundle = selected_for_reconstruction()
    artifact = sidecar.reconstruct_t1(bundle_id=bundle["bundle_id"])
    return sidecar, artifact


def cutover(sidecar, artifact, expected=None):
    return sidecar.cutover_reentry(
        artifact_id=artifact["artifact_id"],
        expected_active_model_ref=expected or artifact["parent_model_ref"],
        operator="dmb-b-test",
        basis="explicit finite reconstructed model activation",
        evidence=artifact["artifact_id"],
    )


class ModelCutoverReentryTests(unittest.TestCase):
    def test_cutover_archives_parent_activates_prime_and_resolves_m_delta(self):
        sidecar, artifact = reconstructed()
        before = sidecar.snapshot()
        parent = copy.deepcopy(before["models"][artifact["parent_model_ref"]])
        record = cutover(sidecar, artifact)
        after = sidecar.snapshot()

        self.assertEqual(record["status"], "CUTOVER_ACCEPTED")
        self.assertEqual(set(after["models"]), {artifact["model_ref"]})
        self.assertEqual(after["model_archive"][artifact["parent_model_ref"]], parent)
        active = after["models"][artifact["model_ref"]]
        self.assertEqual(active["adopted_relations"], artifact["adopted_relations"])
        self.assertEqual(after["M_delta"]["active_count"], 0)
        state = after["M_delta"]["states"][0]
        self.assertEqual(state["phase"], "REENTERED")
        self.assertEqual(state["resolution"]["new_model_ref"], artifact["model_ref"])
        self.assertIn("not-game-action-authority", record["authority"])

    def test_reentry_starts_fresh_comparison_window_under_new_model(self):
        sidecar, artifact = reconstructed()
        prior_comparisons = sidecar.snapshot()["comparisons"]
        cutover(sidecar, artifact)
        self.assertIsNone(sidecar.capture(packet("reentry-first", tick=30, objects=3)))
        mismatch = sidecar.capture(packet("reentry-later", tick=31, objects=4))
        self.assertIsNotNone(mismatch)
        self.assertEqual(mismatch.model_ref, artifact["model_ref"])
        self.assertEqual(sidecar.snapshot()["comparisons"], prior_comparisons + 1)

    def test_wrong_expected_parent_is_rejected_without_mutation(self):
        sidecar, artifact = reconstructed()
        before = copy.deepcopy(sidecar.snapshot())
        with self.assertRaisesRegex(ModelCutoverError, "expected active model"):
            cutover(sidecar, artifact, expected="wrong-model")
        self.assertEqual(sidecar.snapshot(), before)

    def test_exact_replay_is_idempotent_and_changed_provenance_is_rejected(self):
        sidecar, artifact = reconstructed()
        first = cutover(sidecar, artifact)
        self.assertEqual(cutover(sidecar, artifact), first)
        with self.assertRaisesRegex(ModelCutoverError, "changed provenance"):
            sidecar.cutover_reentry(
                artifact_id=artifact["artifact_id"],
                expected_active_model_ref=artifact["parent_model_ref"],
                operator="different-operator", basis="changed", evidence="changed",
            )
        self.assertEqual(sidecar.snapshot()["model_cutover"]["count"], 1)


if __name__ == "__main__":
    unittest.main()
