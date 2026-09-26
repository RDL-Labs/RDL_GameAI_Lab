import copy
import json
from pathlib import Path
import unittest

from runtime.auditory_candidates import find_candidates, CandidateInputError
from runtime.sensory_observation import SensoryObservationStore
from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from integrations.luanti.tests.check_auditory_candidates import check, fixture_request
from test_sensory_observation import packet

FIXTURE = Path(__file__).parent / "fixtures/obs7b_luanti_replay.json"


def recorded():
    return json.loads(FIXTURE.read_text(encoding="utf-8"))["snapshot"]


def admitted(edit=None):
    frames = copy.deepcopy(recorded()["frames"][:2])
    if edit:
        edit(frames)
    store = SensoryObservationStore(assignments={"npc_a": ("fixture-audition-enabled", 1)})
    wire = [{k: v for k, v in f.items() if k not in ("run_id", "world_epoch")} for f in frames]
    ext = {"schema_version": "rdl-sensory-extension-v1", "run_id": "fixture-run-1", "world_epoch": 1,
           "agent_id": "npc_a", "delivery_observation_id": "admit", "delivery_world_tick": 10,
           "delivery_time_us": 3000000, "frames": wire}
    store.admit(packet("admit", tick=10), ext)
    req = fixture_request(store.snapshot())
    req["queries"] = req["queries"][:1]
    return store, req, ext


def run_edit(edit):
    store, req, _ = admitted(edit)
    return find_candidates(store.snapshot(), req)["results"][0]


class AuditoryCandidateTests(unittest.TestCase):
    def test_real_luanti_all_four_states_and_7a_boundary(self):
        self.assertEqual(len(check(recorded())), 4)

    def test_admission_positive_and_detached_output(self):
        store, req, _ = admitted()
        snapshot = store.snapshot()
        before = copy.deepcopy((snapshot, req))
        result = find_candidates(snapshot, req)
        self.assertEqual(result["results"][0]["status"], "single_candidate")
        result["results"][0]["conditions"]["source_frame"]["payload"]["detections"].clear()
        self.assertEqual((snapshot, req), before)
        self.assertEqual(snapshot, store.snapshot())

    def test_direction_circle_exact_threshold_and_far(self):
        for left, right, status in [([150, 180], [-180, -150], "single_candidate"),
                                    ([0, 30], [30, 60], "single_candidate"),
                                    ([0, 30], [60, 90], "no_candidate"),
                                    ([0, 30], [-180, -150], "no_candidate")]:
            with self.subTest(left=left, right=right):
                def edit(frames):
                    for f, direction in zip(frames, (left, right)):
                        f["payload"]["detections"][0]["azimuth_interval_deg"] = direction
                result = run_edit(edit)
                self.assertEqual(result["status"], status)

    def test_predicate_mismatches_are_not_missingness(self):
        edits = [
            (lambda d: d.update(dominant_band="high"), "band_mismatch"),
            (lambda d: d.update(elevation_band="above"), "elevation_mismatch"),
            (lambda d: d.update(received_interval_us=[250001, 255000]), "boundary_not_touched"),
        ]
        for edit, reason in edits:
            with self.subTest(reason=reason):
                result = run_edit(lambda f: edit(f[1]["payload"]["detections"][0]))
                self.assertEqual(result["status"], "no_candidate")
                self.assertTrue(result["search_complete"])
                self.assertIn(reason, result["pair_results"][0]["reasons"])

    def test_known_candidate_plus_unknown_is_not_single(self):
        def edit(frames):
            unknown = copy.deepcopy(frames[1]["payload"]["detections"][0])
            unknown.update(detection_id="unknown", azimuth_interval_deg="unknown")
            frames[1]["payload"]["detections"].append(unknown)
        result = run_edit(edit)
        self.assertEqual(result["status"], "not_comparable")
        self.assertIsNone(result["candidates"])
        self.assertFalse(result["search_complete"])
        self.assertEqual([x["status"] for x in result["pair_results"]], ["candidate", "not_comparable"])

    def test_frame_missingness_short_circuits_candidate_generation(self):
        for metadata, reason in [({"coverage": "PARTIAL"}, "incomplete_coverage"),
                                 ({"output_limited": True}, "output_limited"),
                                 ({"status": "UNAVAILABLE", "coverage": "UNAVAILABLE", "payload": {"detections": []}}, "unavailable")]:
            with self.subTest(reason=reason):
                result = run_edit(lambda f: f[1].update(metadata))
                self.assertEqual(result["status"], "not_comparable")
                self.assertEqual(result["pair_results"], [])
                self.assertIsNone(result["candidates"])
                self.assertIn(reason, result["reasons"])

    def test_empty_complete_window_has_no_candidate(self):
        result = run_edit(lambda f: f[1].update(payload={"detections": []}))
        self.assertEqual(result["status"], "no_candidate")
        self.assertTrue(result["search_complete"])

    def test_invalid_elements_are_not_forced_to_match(self):
        for field, value, reason in [
            ("dominant_band", "mixed", "unknown_band"),
            ("elevation_band", "unknown", "unknown_elevation"),
            ("azimuth_interval_deg", [1, 31], "unsupported_direction_bin"),
            ("received_interval_us", [250000, 250000], "empty_received_interval"),
            ("observer_frame_ref", "different-pose", "pose_mapping_unavailable"),
        ]:
            with self.subTest(reason=reason):
                result = run_edit(lambda f: f[1]["payload"]["detections"][0].update({field: value}))
                self.assertIn(reason, result["reasons"])
                self.assertEqual(result["status"], "not_comparable")

    def test_source_conditions_are_checked_even_with_empty_target(self):
        def edit(frames):
            frames[0]["payload"]["detections"][0]["azimuth_interval_deg"] = "unknown"
            frames[1]["payload"]["detections"] = []
        self.assertEqual(run_edit(edit)["reasons"], ["unknown_direction"])

    def test_clock_model_sensor_and_window_conditions(self):
        cases = [("clock_id", "another-clock", "clock_mismatch"),
                 ("sensor_model_revision", "other-model", "unsupported_model"),
                 ("sensor_id", "other-ears", "unsupported_sensor")]
        for field, value, reason in cases:
            self.assertIn(reason, run_edit(lambda f: f[1].update({field: value}))["reasons"])
        def gap(frames):
            frames[1]["capture_window"].update(start_us=500000, end_us=750000)
            frames[1]["payload"]["detections"][0]["received_interval_us"] = [500000, 505000]
        self.assertIn("non_adjacent_windows", run_edit(gap)["reasons"])

    def test_strength_and_temporal_form_are_not_identity_keys(self):
        def edit(frames):
            frames[1]["payload"]["detections"][0].update(received_strength_band="strong", temporal_form="sustained")
        self.assertEqual(run_edit(edit)["status"], "single_candidate")

    def test_replay_and_order_invariance(self):
        store, req, ext = admitted()
        expected = find_candidates(store.snapshot(), req)
        ext.update(delivery_observation_id="retry", delivery_world_tick=11)
        self.assertEqual(store.admit(packet("retry", tick=11), ext)["new_frames"], 0)
        snapshot = store.snapshot()
        snapshot["frames"].reverse()
        req["queries"] *= 2
        self.assertEqual(find_candidates(snapshot, req), expected)

    def test_budget_before_dedup_and_atomic_unknown_reference(self):
        store, req, _ = admitted()
        req["queries"] *= 16
        self.assertEqual(len(find_candidates(store.snapshot(), req)["results"]), 1)
        req["queries"].append(copy.deepcopy(req["queries"][0]))
        with self.assertRaisesRegex(CandidateInputError, "budget_exceeded"):
            find_candidates(store.snapshot(), req)
        req["queries"] = req["queries"][:2]
        req["queries"][1] = copy.deepcopy(req["queries"][1])
        req["queries"][1]["target_frame_id"] = "unknown"
        before = store.snapshot()
        with self.assertRaisesRegex(CandidateInputError, "unknown_frame"):
            find_candidates(before, req)
        self.assertEqual(before, store.snapshot())

    def test_context_reference_and_partial_list_rejection(self):
        store, original, _ = admitted()
        for edit, reason in [
            (lambda r: r.update(run_id="elsewhere"), "context_mismatch"),
            (lambda r: r.update(world_epoch=True), "context_mismatch"),
            (lambda r: r.update(purpose="same_source"), "unsupported_purpose"),
            (lambda r: r.update(rule_version="v2"), "unsupported_rule"),
            (lambda r: r["queries"][0].update(target_detections=["d0"]), "invalid_query"),
            (lambda r: r["queries"][0]["source"].update(detection_id="absent"), "unknown_detection"),
            (lambda r: r["queries"][0].update(target_frame_id="obs7b:audition:1"), "self_query"),
        ]:
            with self.subTest(reason=reason):
                req = copy.deepcopy(original)
                edit(req)
                with self.assertRaisesRegex(CandidateInputError, reason):
                    find_candidates(store.snapshot(), req)
        req = copy.deepcopy(original)
        req["queries"][0]["source"]["frame_id"] = "obs7b:audition:2"
        req["queries"][0]["target_frame_id"] = "obs7b:audition:1"
        with self.assertRaisesRegex(CandidateInputError, "reverse_time"):
            find_candidates(store.snapshot(), req)
        for field, value, reason in [("agent_id", "npc_b", "cross_agent_reference"),
                                     ("world_epoch", 2, "context_mismatch")]:
            snapshot = store.snapshot()
            snapshot["frames"][1][field] = value
            with self.assertRaisesRegex(CandidateInputError, reason):
                find_candidates(snapshot, original)

    def test_ambiguous_detection_id_rejects(self):
        store, req, _ = admitted()
        snapshot = store.snapshot()
        values = snapshot["frames"][1]["payload"]["detections"]
        values.append(copy.deepcopy(values[0]))
        with self.assertRaisesRegex(CandidateInputError, "ambiguous_detection"):
            find_candidates(snapshot, req)

    def test_maximum_query_cross_product_is_128_without_ranking(self):
        template = recorded()["frames"][:2]
        store = SensoryObservationStore(assignments={"npc_a": ("fixture-audition-enabled", 1)})
        queries = []
        for index in range(16):
            frames = copy.deepcopy(template)
            for side, frame in enumerate(frames):
                shift = index * 500000
                frame.update(frame_id=f"bounded-{index}-{side}", sample_seq=index*2+side+1,
                             sampled_world_tick=index*2+side+1)
                for key in ("start_us", "end_us"):
                    frame["capture_window"][key] += shift
                d = frame["payload"]["detections"][0]
                d["received_interval_us"] = [t+shift for t in d["received_interval_us"]]
                if side:
                    frame["payload"]["detections"] = [dict(copy.deepcopy(d), detection_id=f"d{j}",
                        azimuth_interval_deg=[-180+j*30, -150+j*30]) for j in range(8)]
                frame.pop("run_id")
                frame.pop("world_epoch")
            ext = {"schema_version": "rdl-sensory-extension-v1", "run_id": "fixture-run-1", "world_epoch": 1,
                   "agent_id": "npc_a", "delivery_observation_id": f"bound-{index}", "delivery_world_tick": 32,
                   "delivery_time_us": 8000000, "frames": frames}
            store.admit(packet(f"bound-{index}", tick=32), ext)
            queries.append({"source": {"frame_id": frames[0]["frame_id"], "detection_id": "d0"},
                            "target_frame_id": frames[1]["frame_id"]})
        req = fixture_request(store.snapshot())
        req["queries"] = queries
        results = find_candidates(store.snapshot(), req)["results"]
        self.assertEqual(sum(len(r["pair_results"]) for r in results), 128)
        self.assertTrue(all(r["status"] == "multiple_candidates" for r in results))

    def test_unsupported_profile_is_not_silently_permitted(self):
        store, req, ext = admitted()
        other = SensoryObservationStore(assignments={"npc_a": ("fixture-audition-compact", 1)})
        for frame in ext["frames"]:
            frame["profile_id"] = "fixture-audition-compact"
        other.admit(packet("admit", tick=10), ext)
        self.assertEqual(find_candidates(other.snapshot(), req)["results"][0]["reasons"], ["unsupported_profile"])

    def test_fixed_packet_non_interference(self):
        store, req, _ = admitted()
        def replay(enabled):
            history, canonical = InteractionHistory(), GameAIFrozenComparisonSidecar()
            actions = []
            for i in range(3):
                observed = packet(f"fixed-{i}", tick=i+1)
                if enabled:
                    find_candidates(store.snapshot(), req)
                action = decide_action(observed)
                history.register_decision(observed, action)
                canonical.capture(observed)
                actions.append(action)
            return actions, history.snapshot(), canonical.snapshot(), store.snapshot()
        self.assertEqual(replay(False), replay(True))


if __name__ == "__main__":
    unittest.main()
