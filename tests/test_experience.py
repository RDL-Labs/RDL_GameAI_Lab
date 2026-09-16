import json
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from unittest.mock import patch

from runtime import bridge
from runtime.core import decide_action
from runtime.experience import HistoryError, InteractionHistory
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_v23_interpretation import packet


def food_packet(observation_id, agent="npc_a", rule="radius-145"):
    observed = packet(observation_id, tick=1, perception_rule=rule)
    observed["agent_id"] = agent
    observed["observation"]["visible_objects"] = [{"id": "food_01", "kind": "food"}]
    return observed


def result(observation_id, outcome="approach_progress", agent="npc_a"):
    return {"agent_id": agent, "source_observation_id": observation_id,
            "subsequent_observation_id": observation_id + "-after", "tick": 1,
            "target_id": "food_01", "outcome": outcome}


class ExperienceTests(unittest.TestCase):
    def setUp(self):
        self.history = InteractionHistory()

    def admit(self, observation_id, agent="npc_a", rule="radius-145"):
        observed = food_packet(observation_id, agent, rule)
        self.history.register_decision(observed, decide_action(observed))

    def test_different_outcomes_coexist_without_net_affinity(self):
        for source, outcome in (("a", "approach_progress"), ("b", "approach_no_progress")):
            self.admit(source)
            self.history.record_result(result(source, outcome))
        snapshot = self.history.snapshot()
        self.assertEqual(len(snapshot["relations"]), 1)
        for outcome in ("approach_progress", "approach_no_progress"):
            self.assertEqual(len(snapshot["relations"][0][outcome]), 1)
        self.assertNotIn("H", snapshot)
        self.assertEqual(snapshot["authority"], "read-only-history")

    def test_decision_alone_is_not_a_completed_interaction(self):
        self.admit("a")
        snapshot = self.history.snapshot()
        self.assertEqual(snapshot["records"], [])
        self.assertEqual(snapshot["pending_results"], 1)

    def test_replay_is_idempotent_and_conflict_is_rejected(self):
        self.admit("a")
        self.history.record_result(result("a"))
        before = self.history.snapshot()
        self.admit("a")
        self.history.record_result(result("a"))
        self.assertEqual(before, self.history.snapshot())
        with self.assertRaises(HistoryError):
            self.history.record_result(result("a", "approach_no_progress"))
        with self.assertRaises(HistoryError):
            self.admit("a", rule="different")
        self.assertEqual(before, self.history.snapshot())

    def test_unknown_and_mismatched_reports_do_not_mutate(self):
        self.admit("a")
        before = self.history.snapshot()
        for field, value in (("source_observation_id", "unknown"), ("agent_id", "npc_b"),
                             ("target_id", "hidden-target"), ("subsequent_observation_id", "a"),
                             ("tick", 0), ("tick", True), ("outcome", "fear")):
            payload = result("a")
            payload[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(HistoryError):
                self.history.record_result(payload)
            self.assertEqual(before, self.history.snapshot())

    def test_agent_context_and_export_are_isolated(self):
        for source, agent, rule in (("a", "npc_a", "one"), ("b", "npc_b", "one"), ("c", "npc_a", "two")):
            self.admit(source, agent, rule)
            self.history.record_result(result(source, agent=agent))
        snapshot = self.history.snapshot()
        self.assertEqual(len(snapshot["relations"]), 3)
        snapshot["records"][0]["action"].clear()
        snapshot["relations"][0]["context"].clear()
        self.assertEqual(self.history.snapshot()["records"][0]["action"]["type"], "approach")

    def test_capacity_retains_old_results_and_restart_clears(self):
        self.history.capacity = 1
        self.admit("a")
        self.history.record_result(result("a"))
        self.admit("b")
        with self.assertRaises(HistoryError):
            self.history.record_result(result("b"))
        self.assertEqual(self.history.snapshot()["capacity_rejections"], 1)
        self.assertEqual(len(self.history.snapshot()["records"]), 1)
        self.assertEqual(InteractionHistory().snapshot()["records"], [])

    def test_http_result_is_read_only_for_action_and_canonical_state(self):
        with patch.object(bridge, "EXPERIENCE", self.history), patch.object(bridge, "CANONICAL_SIDECAR", GameAIFrozenComparisonSidecar()):
            server = ThreadingHTTPServer(("127.0.0.1", 0), bridge.BridgeHandler)
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            base = f"http://127.0.0.1:{server.server_port}"
            def post(path, data):
                with urlopen(Request(base + path, json.dumps(data).encode(), {"Content-Type": "application/json"}), timeout=3) as response:
                    return json.load(response)
            try:
                observed = food_packet("a")
                self.assertEqual(post("/v1/observe", observed), decide_action(observed))
                canonical = bridge.CANONICAL_SIDECAR.snapshot()
                self.assertTrue(post("/v1/interaction-result", result("a"))["accepted"])
                self.assertEqual(canonical, bridge.CANONICAL_SIDECAR.snapshot())
                with urlopen(base + "/v1/experience-snapshot", timeout=3) as response:
                    self.assertEqual(len(json.load(response)["records"]), 1)
                self.assertEqual(post("/v1/observe", observed), decide_action(observed))
                with self.assertRaises(HTTPError) as failure:
                    post("/v1/interaction-result", result("unknown"))
                self.assertEqual(failure.exception.code, 422)
                failure.exception.close()
            finally:
                server.shutdown()
                thread.join()
                server.server_close()
