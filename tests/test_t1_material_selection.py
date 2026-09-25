import copy
import unittest

from runtime.t1_material_selection import T1MaterialSelectionError
from test_t1_material_expansion import candidate, experience, reviewed_sidecar


def expanded():
    sidecar, assessment_id = reviewed_sidecar()
    bundle = sidecar.expand_t1_materials(
        assessment_id=assessment_id,
        candidates=[candidate()], experiences=[experience()],
    )
    return sidecar, bundle


def review(bundle, revision=0, dispositions=None):
    dispositions = dispositions or {}
    return {
        "expected_revision": revision,
        "reviewer": "t1b-test",
        "materials": [{
            "material_id": item["material_id"],
            "disposition": dispositions.get(item["kind"], "DEFER"),
            "basis": f"finite inspection of {item['kind']}",
            "evidence": item["source_id"],
        } for item in bundle["materials"]],
    }


class T1MaterialSelectionTests(unittest.TestCase):
    def test_complete_explicit_review_assigns_all_three_dispositions(self):
        sidecar, bundle = expanded()
        record = sidecar.inspect_t1_materials(
            bundle_id=bundle["bundle_id"],
            payload=review(bundle, dispositions={
                "current_M_B": "RETAIN",
                "CandidateRelation": "REJECT",
                "Experience": "DEFER",
            }),
        )
        self.assertEqual(record["status"], "INSPECTED")
        self.assertEqual(record["revision"], 1)
        self.assertEqual(record["counts"], {"RETAIN": 1, "REJECT": 1, "DEFER": 4})
        self.assertEqual(len(record["materials"]), bundle["material_count"])
        self.assertIn("RETAIN-not-adoption", record["authority"])

    def test_partial_or_duplicate_review_is_rejected_atomically(self):
        sidecar, bundle = expanded()
        partial = review(bundle)
        partial["materials"].pop()
        with self.assertRaisesRegex(T1MaterialSelectionError, "cover every"):
            sidecar.inspect_t1_materials(bundle_id=bundle["bundle_id"], payload=partial)
        self.assertEqual(sidecar.snapshot()["T1_selection"]["records"], [])

        duplicate = review(bundle)
        duplicate["materials"][-1]["material_id"] = duplicate["materials"][0]["material_id"]
        with self.assertRaisesRegex(T1MaterialSelectionError, "unknown or duplicated"):
            sidecar.inspect_t1_materials(bundle_id=bundle["bundle_id"], payload=duplicate)
        self.assertEqual(sidecar.snapshot()["T1_selection"]["records"], [])

    def test_revision_guard_supports_explicit_reinspection(self):
        sidecar, bundle = expanded()
        first = sidecar.inspect_t1_materials(
            bundle_id=bundle["bundle_id"], payload=review(bundle)
        )
        with self.assertRaisesRegex(T1MaterialSelectionError, "expected_revision"):
            sidecar.inspect_t1_materials(
                bundle_id=bundle["bundle_id"], payload=review(bundle)
            )
        changed = review(bundle, revision=1, dispositions={"CandidateRelation": "RETAIN"})
        second = sidecar.inspect_t1_materials(
            bundle_id=bundle["bundle_id"], payload=changed
        )
        self.assertEqual((first["revision"], second["revision"]), (1, 2))
        self.assertEqual(second["counts"]["RETAIN"], 1)

    def test_selection_does_not_mutate_bundle_model_or_action_authority(self):
        sidecar, bundle = expanded()
        before_bundle = copy.deepcopy(sidecar.snapshot()["T1_materials"])
        before_models = copy.deepcopy(sidecar.snapshot()["models"])
        sidecar.inspect_t1_materials(
            bundle_id=bundle["bundle_id"],
            payload=review(bundle, dispositions={"CandidateRelation": "RETAIN"}),
        )
        snapshot = sidecar.snapshot()
        self.assertEqual(snapshot["T1_materials"], before_bundle)
        self.assertEqual(snapshot["models"], before_models)
        self.assertIn("reconstruction", snapshot["T1_selection"]["not_implemented"])
        self.assertNotIn("M_B_prime", snapshot)


if __name__ == "__main__":
    unittest.main()
