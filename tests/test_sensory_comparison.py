import copy
import json
from pathlib import Path
import unittest

from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from runtime.sensory_observation import SensoryObservationStore
from runtime.sensory_comparison import (
    diagnose, ComparisonInputError, PURPOSE, RULE_VERSION,
)
from test_sensory_observation import packet, audition_extension, distant_extension


def admitted_pair(change=None):
    store = SensoryObservationStore(assignments={"npc_a": ("fixture-life-sensory", 1)})
    extensions = []
    for index in range(2):
        observed = packet(f"obs-{index}", tick=index + 1)
        ext = audition_extension(observed, "fixture-life-sensory")
        frame = ext["frames"][0]
        frame["frame_id"] = f"frame-{index}"
        frame["sample_seq"] = index + 1
        frame["capture_window"]["end_us"] += index
        ext["delivery_time_us"] += index
        if change:
            change(frame, index)
        store.admit(observed, ext)
        extensions.append(ext)
    return store, extensions


def request(snapshot, pairs=None):
    return {"run_id": snapshot["run_id"], "world_epoch": snapshot["world_epoch"],
            "agent_id": "npc_a", "purpose": PURPOSE, "rule_version": RULE_VERSION,
            "pairs": pairs if pairs is not None else [[
                {"frame_id": "frame-0", "element_id": "d0"},
                {"frame_id": "frame-1", "element_id": "d0"}]]}


class SensoryComparisonTests(unittest.TestCase):
    def test_admitted_positive_is_pure_and_result_is_detached(self):
        store, _ = admitted_pair()
        snapshot = store.snapshot()
        req = request(snapshot)
        before = copy.deepcopy((snapshot, req))
        result = diagnose(snapshot, req)
        self.assertEqual(result["results"][0]["status"], "eligible")
        self.assertEqual(result["results"][0]["reasons"], [])
        self.assertEqual((snapshot, req), before)
        result["results"][0]["conditions"][0]["comparison_window"]["start_us"] = -1
        self.assertEqual(snapshot, store.snapshot())

    def test_detection_pose_overrides_window_pose_and_no_id_parsing(self):
        def same(frame, index):
            frame["observer_frame_ref"] = f"different-window-{index}"
        store, _ = admitted_pair(same)
        self.assertEqual(diagnose(store.snapshot(), request(store.snapshot()))["results"][0]["status"], "eligible")
        def different(frame, index):
            frame["payload"]["detections"][0]["observer_frame_ref"] = f"pose-{index}"
        store, _ = admitted_pair(different)
        self.assertIn("pose_mapping_unavailable", diagnose(store.snapshot(), request(store.snapshot()))["results"][0]["reasons"])

    def test_point_interval_boundaries_and_cross_channel_pose(self):
        for point, overlaps in [(210000, True), (219999, True), (220000, False)]:
            with self.subTest(point=point):
                store, _ = admitted_pair()
                observed = packet("distant", tick=3)
                ext = distant_extension(observed)
                frame = ext["frames"][0]
                frame.update(frame_id="distant", profile_id="fixture-life-sensory")
                frame["capture_window"].update(start_us=point, end_us=point)
                # Even equal spelling cannot bridge eye and ear coordinates.
                frame["observer_frame_ref"] = "npc_a:ear-pose:1"
                store.admit(observed, ext)
                refs = [[{"frame_id": "distant", "element_id": "f0"},
                         {"frame_id": "frame-0", "element_id": "d0"}]]
                for pair in (refs[0], refs[0][::-1]):
                    reasons = diagnose(store.snapshot(), request(store.snapshot(), [pair]))["results"][0]["reasons"]
                    self.assertEqual("no_temporal_overlap" not in reasons, overlaps)
                    self.assertIn("pose_mapping_unavailable", reasons)

    def test_interval_overlap_touching_and_empty(self):
        for interval, overlaps in [([219999, 230000], True), ([220000, 230000], False), ([215000, 215000], False)]:
            def change(frame, index):
                if index:
                    frame["payload"]["detections"][0]["received_interval_us"] = interval
            store, _ = admitted_pair(change)
            result = diagnose(store.snapshot(), request(store.snapshot()))["results"][0]
            self.assertEqual(result["status"] == "eligible", overlaps)

    def test_missing_partial_unknown_and_unsupported_conditions(self):
        cases = [
            (lambda f: f.update(coverage="PARTIAL"), "incomplete_coverage"),
            (lambda f: f.update(output_limited=True), "output_limited"),
            (lambda f: f.update(clock_id="other-clock"), "clock_mismatch"),
            (lambda f: f.update(sensor_model_revision="future-model"), "unsupported_model"),
            (lambda f: f["payload"]["detections"][0].update(azimuth_interval_deg="unknown"), "unknown_direction"),
        ]
        for edit, expected in cases:
            with self.subTest(expected=expected):
                def change(frame, index):
                    if index:
                        edit(frame)
                store, _ = admitted_pair(change)
                self.assertIn(expected, diagnose(store.snapshot(), request(store.snapshot()))["results"][0]["reasons"])
        def unavailable(frame, index):
            if index:
                frame.update(status="UNAVAILABLE", coverage="UNAVAILABLE", payload={"detections": []})
        store, _ = admitted_pair(unavailable)
        req = request(store.snapshot())
        req["pairs"][0][1].pop("element_id")
        result = diagnose(store.snapshot(), req)["results"][0]
        self.assertEqual(result["status"], "not_comparable")
        self.assertTrue({"no_element", "unavailable", "incomplete_coverage"} <= set(result["reasons"]))

    def test_missing_selection_is_not_implicit_first_element(self):
        store, _ = admitted_pair()
        req = request(store.snapshot())
        req["pairs"][0][0].pop("element_id")
        self.assertIn("element_selection_required", diagnose(store.snapshot(), req)["results"][0]["reasons"])

    def test_direction_values_and_wrap_edges_do_not_establish_identity(self):
        def change(frame, index):
            frame["payload"]["detections"][0]["azimuth_interval_deg"] = [-180, -170] if index else [170, 180]
        store, _ = admitted_pair(change)
        result = diagnose(store.snapshot(), request(store.snapshot()))["results"][0]
        self.assertEqual(result["status"], "eligible")
        self.assertEqual(set(result), {"references", "conditions", "status", "reasons"})

    def test_replay_delivery_and_pair_order_do_not_add_evidence(self):
        store, extensions = admitted_pair()
        snapshot = store.snapshot()
        req = request(snapshot)
        expected = diagnose(snapshot, req)
        for ext in extensions:
            replay = copy.deepcopy(ext)
            replay.update(delivery_observation_id="later", delivery_world_tick=10, delivery_time_us=999999)
            self.assertEqual(store.admit(packet("later", tick=10), replay)["new_frames"], 0)
        req["pairs"] += [req["pairs"][0][::-1]]
        snapshot = store.snapshot()
        snapshot["frames"].reverse()
        self.assertEqual(diagnose(snapshot, req), expected)

    def test_budget_and_duplicate_pairs_are_bounded_before_deduplication(self):
        store, _ = admitted_pair()
        req = request(store.snapshot())
        pair = req["pairs"][0]
        req["pairs"] = [pair] * 16
        self.assertEqual(len(diagnose(store.snapshot(), req)["results"]), 1)
        req["pairs"].append(pair)
        with self.assertRaises(ComparisonInputError) as caught:
            diagnose(store.snapshot(), req)
        self.assertEqual(caught.exception.code, "budget_exceeded")

    def test_invalid_references_context_and_requests_reject_atomically(self):
        store, _ = admitted_pair()
        snapshot = store.snapshot()
        cases = [
            (lambda r: r.update(run_id="other"), "context_mismatch"),
            (lambda r: r.update(world_epoch=2), "context_mismatch"),
            (lambda r: r.update(world_epoch=True), "context_mismatch"),
            (lambda r: r.update(agent_id="npc_b"), "unknown_agent"),
            (lambda r: r.update(purpose="same_source"), "unsupported_purpose"),
            (lambda r: r.update(rule_version="future"), "unsupported_rule"),
            (lambda r: r["pairs"][0][0].update(frame_id="missing"), "unknown_frame"),
            (lambda r: r["pairs"][0][0].update(element_id="missing"), "unknown_or_ambiguous_element"),
            (lambda r: r["pairs"][0][0].update(frame_id="frame-1"), "self_pair"),
        ]
        for edit, expected in cases:
            with self.subTest(expected=expected):
                req = request(snapshot)
                edit(req)
                before = copy.deepcopy(snapshot)
                with self.assertRaises(ComparisonInputError) as caught:
                    diagnose(snapshot, req)
                self.assertEqual(caught.exception.code, expected)
                self.assertEqual(snapshot, before)
        altered = copy.deepcopy(snapshot)
        altered["frames"][0]["agent_id"] = "npc_b"
        with self.assertRaisesRegex(ComparisonInputError, "cross_agent_reference"):
            diagnose(altered, request(snapshot))
        altered = copy.deepcopy(snapshot)
        altered["frames"][0]["world_epoch"] = 2
        with self.assertRaisesRegex(ComparisonInputError, "context_mismatch"):
            diagnose(altered, request(snapshot))

    def test_profile_permission_table_and_multiple_reasons(self):
        store, _ = admitted_pair()
        observed = packet("other-profile", tick=3)
        store.assignments["npc_a"] = ("fixture-audition-compact", 1)
        ext = audition_extension(observed, "fixture-audition-compact")
        frame = ext["frames"][0]
        frame.update(frame_id="other-profile", sample_seq=3, coverage="PARTIAL", output_limited=True)
        frame["capture_window"]["end_us"] = 250002
        ext["delivery_time_us"] = 250002
        store.admit(observed, ext)
        req = request(store.snapshot())
        req["pairs"][0][1]["frame_id"] = "other-profile"
        reasons = diagnose(store.snapshot(), req)["results"][0]["reasons"]
        self.assertEqual(reasons, ["incomplete_coverage", "output_limited", "profile_mismatch"])

    def test_instant_time_comparison_uses_equality(self):
        for instant, expected in [(250000, True), (249999, False)]:
            store = SensoryObservationStore(assignments={"npc_a": ("fixture-distant-enabled", 1)})
            refs = []
            for index in range(2):
                observed = packet(f"instant-{index}")
                ext = distant_extension(observed)
                frame = ext["frames"][0]
                frame.update(frame_id=f"instant-{index}", sensor_id=f"eye-{index}")
                if index:
                    frame["capture_window"].update(start_us=instant, end_us=instant)
                store.admit(observed, ext)
                refs.append({"frame_id": frame["frame_id"], "element_id": "f0"})
            reasons = diagnose(store.snapshot(), request(store.snapshot(), [refs]))["results"][0]["reasons"]
            self.assertEqual("no_temporal_overlap" not in reasons, expected)

    def test_real_luanti_replay_keeps_pose_and_time_gaps(self):
        artifact = json.loads((Path(__file__).parent / "fixtures/obs7a_luanti_replay.json").read_text())
        self.assertEqual(artifact["provenance"]["kind"], "real-luanti-admitted-snapshot-projection")
        snapshot = artifact["snapshot"]
        refs = []
        for frame in snapshot["frames"]:
            field, key = ("features", "feature_id") if frame["channel"] == "vision_distant" else ("detections", "detection_id")
            refs.append({"frame_id": frame["frame_id"], "element_id": frame["payload"][field][0][key]})
        result = diagnose(snapshot, request(snapshot, [refs]))["results"][0]
        self.assertEqual(result["status"], "not_comparable")
        self.assertEqual(result["reasons"], ["no_temporal_overlap", "pose_mapping_unavailable"])

    def test_fixed_packet_actions_experience_and_canonical_are_unchanged(self):
        store, _ = admitted_pair()
        def replay(enabled):
            history, canonical = InteractionHistory(), GameAIFrozenComparisonSidecar()
            actions = []
            for index in range(3):
                observed = packet(f"fixed-{index}", tick=index + 1)
                if enabled:
                    diagnose(store.snapshot(), request(store.snapshot()))
                action = decide_action(observed)
                history.register_decision(observed, action)
                canonical.capture(observed)
                actions.append(action)
            return actions, history.snapshot(), canonical.snapshot(), store.snapshot()
        self.assertEqual(replay(False), replay(True))


if __name__ == "__main__":
    unittest.main()
