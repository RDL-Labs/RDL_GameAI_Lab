import copy
import json
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.request import Request, urlopen
from unittest.mock import patch

from runtime import bridge
from runtime.core import ObservationError, decide_action
from runtime.experience import InteractionHistory
from runtime.sensory_observation import SensoryObservationStore, split_sensory_extension
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


def packet(observation_id="obs-1", agent_id="npc_a", tick=1):
    return {
        "schema_version": "rdl-gameai-observation-v1",
        "observation_id": observation_id,
        "tick": tick,
        "agent_id": agent_id,
        "observation": {
            "perception_rule": "fixture",
            "visible_agents": [], "visible_objects": [], "visible_places": [],
            "visible_regions": [], "recent_events": [], "external_statements": [],
        },
    }


def extension(observed, frame_id="frame-1", profile_id="fixture-sensor-default"):
    frame = {
        "frame_id": frame_id, "agent_id": observed["agent_id"], "sensor_id": "eye",
        "channel": "vision_local", "profile_id": profile_id, "profile_revision": 1,
        "sensor_model_revision": "legacy-radius-v1", "sample_seq": 1,
        "clock_id": "world-sim-v1",
        "capture_window": {"kind": "instant", "start_us": 250000, "end_us": 250000},
        "sampled_world_tick": observed["tick"], "observer_frame_ref": "pose-1",
        "status": "SAMPLED", "coverage": "COMPLETE_WITHIN_PLAN",
        "output_limited": False, "payload": {"visible_count": 0},
    }
    return {
        "schema_version": "rdl-sensory-extension-v1", "run_id": "fixture-run-1",
        "world_epoch": 1, "agent_id": observed["agent_id"],
        "delivery_observation_id": observed["observation_id"],
        "delivery_world_tick": observed["tick"], "delivery_time_us": 250000,
        "frames": [frame],
    }


def distant_extension(observed):
    payload = extension(observed, profile_id="fixture-distant-enabled")
    frame = payload["frames"][0]
    frame["channel"] = "vision_distant"
    frame["sensor_model_revision"] = "sampled-surface-v0.2"
    frame["payload"] = {"features": [{
        "feature_id": "f0", "azimuth_interval_deg": [10, 15],
        "elevation_interval_deg": [-5, 0], "angular_width_band": "unknown",
        "angular_height_band": "unknown", "color_band": "muted_red",
    }]}
    return payload


class SensoryObservationTests(unittest.TestCase):
    def test_distant_payload_accepts_only_coarse_local_features(self):
        observed = packet()
        store = SensoryObservationStore(assignments={
            "npc_a": ("fixture-distant-enabled", 1)
        })
        payload = distant_extension(observed)
        self.assertEqual(store.admit(observed, payload)["new_frames"], 1)
        stored = store.snapshot()["frames"][0]
        self.assertNotIn("target_id", stored["payload"]["features"][0])
        for field in ("world_position", "distance", "target_id"):
            invalid = copy.deepcopy(payload)
            invalid["frames"][0]["frame_id"] = "bad-" + field
            invalid["frames"][0]["payload"]["features"][0][field] = "leak"
            with self.subTest(field=field), self.assertRaises(ObservationError):
                SensoryObservationStore(assignments={
                    "npc_a": ("fixture-distant-enabled", 1)
                }).admit(observed, invalid)

    def test_split_removes_extension_from_legacy_consumers(self):
        observed = packet()
        observed["observation"]["sensory_extension"] = extension(observed)
        store = SensoryObservationStore()
        legacy, receipt = split_sensory_extension(observed, store)
        self.assertNotIn("sensory_extension", legacy["observation"])
        self.assertIn("sensory_extension", observed["observation"])
        self.assertEqual(receipt["new_frames"], 1)
        self.assertEqual(decide_action(legacy), decide_action(packet()))

    def test_disabled_store_strips_without_admission(self):
        observed = packet()
        observed["observation"]["sensory_extension"] = {"untrusted": True}
        legacy, receipt = split_sensory_extension(observed, None)
        self.assertNotIn("sensory_extension", legacy["observation"])
        self.assertIsNone(receipt)

    def test_invalid_extension_is_diagnosed_without_stopping_legacy_decision(self):
        for invalid in ({"untrusted": True}, ["not-an-object"]):
            observed = packet()
            observed["observation"]["sensory_extension"] = invalid
            store = SensoryObservationStore()
            legacy, receipt = split_sensory_extension(observed, store)
            self.assertFalse(receipt["accepted"])
            self.assertEqual(decide_action(legacy), decide_action(packet()))
            self.assertEqual(store.snapshot()["count"], 0)
            self.assertEqual(store.snapshot()["rejection_count"], 1)

    def test_replay_is_idempotent_and_conflict_is_atomic(self):
        observed = packet()
        payload = extension(observed)
        store = SensoryObservationStore()
        self.assertEqual(store.admit(observed, payload)["new_frames"], 1)
        before = store.snapshot()
        self.assertEqual(store.admit(observed, payload)["new_frames"], 0)
        conflict = copy.deepcopy(payload)
        conflict["frames"][0]["payload"]["visible_count"] = 1
        with self.assertRaisesRegex(ObservationError, "different contents"):
            store.admit(observed, conflict)
        self.assertEqual(store.snapshot(), before)

    def test_agent_profile_time_and_allowlist_are_strict(self):
        observed = packet()
        valid = extension(observed)
        cases = []
        wrong_agent = copy.deepcopy(valid)
        wrong_agent["agent_id"] = "npc_b"
        cases.append(wrong_agent)
        wrong_profile = copy.deepcopy(valid)
        wrong_profile["frames"][0]["profile_id"] = "fixture-local-compact"
        cases.append(wrong_profile)
        future = copy.deepcopy(valid)
        future["frames"][0]["capture_window"]["end_us"] = 250001
        cases.append(future)
        extra = copy.deepcopy(valid)
        extra["world_position"] = [0, 0, 0]
        cases.append(extra)
        payload_leak = copy.deepcopy(valid)
        payload_leak["frames"][0]["payload"]["world_position"] = [0, 0, 0]
        cases.append(payload_leak)
        premature_channel = copy.deepcopy(valid)
        premature_channel["frames"][0]["channel"] = "audition"
        cases.append(premature_channel)
        store = SensoryObservationStore()
        for payload in cases:
            with self.subTest(payload=payload), self.assertRaises(ObservationError):
                store.admit(observed, payload)
            self.assertEqual(store.snapshot()["count"], 0)

    def test_run_epoch_and_latest_order_cannot_cross_or_roll_back(self):
        observed = packet()
        store = SensoryObservationStore(run_id="fixture-run-1", world_epoch=1)
        first = extension(observed)
        first["frames"][0]["sample_seq"] = 10
        store.admit(observed, first)
        before = store.snapshot()

        wrong_run = extension(packet("obs-2", tick=2), frame_id="frame-run")
        wrong_run["run_id"] = "other-run"
        wrong_run["delivery_time_us"] = 500000
        wrong_run["frames"][0]["sampled_world_tick"] = 2
        wrong_run["frames"][0]["capture_window"] = {
            "kind": "instant", "start_us": 500000, "end_us": 500000,
        }
        wrong_epoch = copy.deepcopy(wrong_run)
        wrong_epoch["run_id"] = "fixture-run-1"
        wrong_epoch["world_epoch"] = 2
        old_sequence = copy.deepcopy(wrong_run)
        old_sequence["run_id"] = "fixture-run-1"
        old_sequence["frames"][0]["sample_seq"] = 9
        old_time = copy.deepcopy(old_sequence)
        old_time["frames"][0]["sample_seq"] = 11
        old_time["delivery_time_us"] = 250000
        old_time["frames"][0]["capture_window"] = {
            "kind": "instant", "start_us": 249999, "end_us": 249999,
        }
        for payload in (wrong_run, wrong_epoch, old_sequence, old_time):
            with self.subTest(payload=payload), self.assertRaises(ObservationError):
                store.admit(packet("obs-2", tick=2), payload)
            self.assertEqual(store.snapshot(), before)

        latest = store.snapshot()["latest_by_agent"]["npc_a"]["vision_local"]
        self.assertEqual(latest["sample_seq"], 10)
        self.assertEqual(latest["run_id"], "fixture-run-1")
        self.assertEqual(latest["world_epoch"], 1)

    def test_capacity_rejection_does_not_partially_store(self):
        observed = packet()
        store = SensoryObservationStore(capacity_per_agent_channel=1)
        store.admit(observed, extension(observed))
        second = packet("obs-2", tick=2)
        payload = extension(second, frame_id="frame-2")
        payload["delivery_time_us"] = 500000
        payload["frames"][0]["capture_window"] = {
            "kind": "instant", "start_us": 500000, "end_us": 500000,
        }
        payload["frames"][0]["sampled_world_tick"] = 2
        with self.assertRaisesRegex(ObservationError, "capacity"):
            store.admit(second, payload)
        self.assertEqual(store.snapshot()["count"], 1)

    def test_one_delivery_cannot_overrun_capacity_or_duplicate_frame_id(self):
        observed = packet()
        payload = extension(observed)
        second = copy.deepcopy(payload["frames"][0])
        second["frame_id"] = "frame-2"
        second["sample_seq"] = 2
        payload["frames"].append(second)
        store = SensoryObservationStore(capacity_per_agent_channel=1)
        with self.assertRaisesRegex(ObservationError, "capacity"):
            store.admit(observed, payload)
        self.assertEqual(store.snapshot()["count"], 0)

        duplicate = extension(observed)
        duplicate["frames"].append(copy.deepcopy(duplicate["frames"][0]))
        self.assertEqual(SensoryObservationStore().admit(observed, duplicate)["new_frames"], 1)

    def test_http_observe_and_get_are_read_only_for_existing_decision(self):
        observed = packet()
        observed["observation"]["sensory_extension"] = extension(observed)
        store = SensoryObservationStore()
        with patch.object(bridge, "EXPERIENCE", InteractionHistory()), patch.object(
            bridge, "CANONICAL_SIDECAR", GameAIFrozenComparisonSidecar()
        ):
            server = ThreadingHTTPServer(("127.0.0.1", 0), bridge.BridgeHandler)
            server.sensory_observation = store
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            base = f"http://127.0.0.1:{server.server_port}"
            try:
                request = Request(base + "/v1/observe", json.dumps(observed).encode(),
                                  {"Content-Type": "application/json"})
                with urlopen(request, timeout=3) as response:
                    self.assertEqual(json.load(response), decide_action(packet()))
                with urlopen(base + "/v1/sensory-observation-snapshot", timeout=3) as response:
                    snapshot = json.load(response)
                self.assertEqual(snapshot["count"], 1)
                self.assertEqual(snapshot["latest_by_agent"]["npc_a"]["vision_local"]["frame_id"],
                                 "frame-1")
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_http_invalid_extension_keeps_legacy_path_running(self):
        observed = packet("obs-invalid")
        observed["observation"]["sensory_extension"] = {"untrusted": True}
        store = SensoryObservationStore()
        with patch.object(bridge, "EXPERIENCE", InteractionHistory()), patch.object(
            bridge, "CANONICAL_SIDECAR", GameAIFrozenComparisonSidecar()
        ):
            server = ThreadingHTTPServer(("127.0.0.1", 0), bridge.BridgeHandler)
            server.sensory_observation = store
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            base = f"http://127.0.0.1:{server.server_port}"
            try:
                request = Request(base + "/v1/observe", json.dumps(observed).encode(),
                                  {"Content-Type": "application/json"})
                with urlopen(request, timeout=3) as response:
                    self.assertEqual(json.load(response), decide_action(packet("obs-invalid")))
                self.assertEqual(store.snapshot()["rejection_count"], 1)
                self.assertEqual(bridge.CANONICAL_SIDECAR.snapshot()["captures"], 1)
            finally:
                server.shutdown()
                thread.join()
                server.server_close()


if __name__ == "__main__":
    unittest.main()
