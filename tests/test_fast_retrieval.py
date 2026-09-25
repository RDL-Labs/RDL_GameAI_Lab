import copy
import json
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.request import Request, urlopen
from unittest.mock import patch

from runtime import bridge
from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.functions.deep_similarity import build_deep_similarity_shadow
from runtime.functions.experience_profile import build_experience_profile, build_relation_profiles
from runtime.functions.fast_retrieval import build_fast_retrieval, FastRetrievalError
from runtime.mechanisms.fast_retrieval import FastRetrievalStore
from runtime.sleep_window import SleepExperienceWindowStore
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_experience import food_packet, result


class FastRetrievalTests(unittest.TestCase):
    def setUp(self):
        self.history = InteractionHistory()
        for source, outcome in (("a", "approach_progress"), ("b", "approach_no_progress"),
                                ("c", "approach_progress"), ("current", "approach_progress")):
            packet = food_packet(source)
            self.history.register_decision(packet, decide_action(packet))
            self.history.record_result(result(source, outcome))
        records = self.history.snapshot()["records"]
        self.profiles = {record["source_observation_id"]: build_experience_profile(record)
                         for record in records}
        window = SleepExperienceWindowStore().form_window(
            {**self.history.snapshot(), "records": records[:3]}, agent_id="npc_a",
            sleep_cycle="night-001", formation_tick=10, enabled=True,
        )
        profile_set = build_relation_profiles(
            window, {**self.history.snapshot(), "records": records[:3]}
        )
        self.candidate = build_deep_similarity_shadow(
            window, profile_set, formation_tick=11
        )["candidate"]
        self.sources = [{
            "source_type": "raw_experience", "source_id": profile["source_experience_id"],
            "profile": profile,
        } for name, profile in self.profiles.items() if name != "current"] + [{
            "source_type": "sleep_candidate", "source_id": self.candidate["candidate_id"],
            "candidate": self.candidate,
        }]

    def test_l0_l1_top_k_are_finite_deterministic_and_source_typed(self):
        found = build_fast_retrieval(self.profiles["current"], self.sources, query_tick=20)
        self.assertEqual(found["status"], "MATCHES_FOUND")
        self.assertLessEqual(len(found["results"]), 3)
        self.assertEqual(
            {item["source_type"] for item in found["results"]},
            {"raw_experience", "sleep_candidate"},
        )
        self.assertTrue(all(item["l0"]["shared_relation_count"] > 0 for item in found["results"]))
        self.assertTrue(all("coverage" in item["l1"] for item in found["results"]))
        self.assertEqual(found["selection_policy"], "best-per-source-type-then-global-rank-v1")
        self.assertEqual(found, build_fast_retrieval(
            self.profiles["current"], self.sources, query_tick=20
        ))

    def test_storage_relation_ids_are_not_used_as_semantic_overlap(self):
        current_ids = {item["relation_id"] for item in self.profiles["current"]["relations"]}
        past_ids = {item["relation_id"] for item in self.profiles["a"]["relations"]}
        self.assertFalse(current_ids & past_ids)
        found = build_fast_retrieval(self.profiles["current"], self.sources, query_tick=20)
        raw = next(item for item in found["results"] if item["source_type"] == "raw_experience")
        self.assertGreater(raw["l0"]["shared_relation_count"], 0)

    def test_cross_agent_sources_are_rejected(self):
        foreign = copy.deepcopy(self.sources[0])
        foreign["profile"]["agent_id"] = "npc_b"
        with self.assertRaisesRegex(FastRetrievalError, "different agent"):
            build_fast_retrieval(self.profiles["current"], [foreign], query_tick=20)

    def test_retrieval_does_not_change_sources_or_form_candidate_or_action(self):
        current_before = copy.deepcopy(self.profiles["current"])
        sources_before = copy.deepcopy(self.sources)
        action_before = decide_action(food_packet("same-action"))
        found = build_fast_retrieval(self.profiles["current"], self.sources, query_tick=20)
        self.assertEqual(self.profiles["current"], current_before)
        self.assertEqual(self.sources, sources_before)
        self.assertEqual(decide_action(food_packet("same-action")), action_before)
        self.assertNotIn("candidate", found)
        self.assertIn("not-candidate-generation-action", found["authority"])

    def test_bounds_invalid_sources_and_store_replay(self):
        with self.assertRaisesRegex(FastRetrievalError, "between one and three"):
            build_fast_retrieval(self.profiles["current"], self.sources, query_tick=20, top_k=4)
        with self.assertRaisesRegex(FastRetrievalError, "at most 32"):
            build_fast_retrieval(self.profiles["current"], self.sources * 11, query_tick=20)
        store = FastRetrievalStore(capacity=1)
        with self.assertRaisesRegex(FastRetrievalError, "opt-in"):
            store.retrieve(self.profiles["current"], self.sources, query_tick=20)
        first = store.retrieve(self.profiles["current"], self.sources, query_tick=20, enabled=True)
        self.assertEqual(first, store.retrieve(
            self.profiles["current"], self.sources, query_tick=20, enabled=True
        ))
        first["results"].clear()
        self.assertTrue(store.snapshot()["queries"][0]["results"])

    def test_http_path_is_opt_in_get_only_and_does_not_change_action(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(
            bridge, "CANONICAL_SIDECAR", canonical
        ):
            server = ThreadingHTTPServer(("127.0.0.1", 0), bridge.BridgeHandler)
            server.fast_retrieval = FastRetrievalStore()
            server.sleep_consolidation = None
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            base = f"http://127.0.0.1:{server.server_port}"

            def post(path, payload):
                request = Request(base + path, json.dumps(payload).encode(),
                                  {"Content-Type": "application/json"})
                with urlopen(request, timeout=3) as response:
                    return json.load(response)

            try:
                for source in ("http-a", "http-b"):
                    packet = food_packet(source)
                    expected = decide_action(packet)
                    self.assertEqual(post("/v1/observe", packet), expected)
                    self.assertTrue(post("/v1/interaction-result", result(source))["accepted"])
                with urlopen(base + "/v1/fast-retrieval-snapshot", timeout=3) as response:
                    snapshot = json.load(response)
                self.assertEqual(len(snapshot["queries"]), 2)
                self.assertEqual(snapshot["queries"][-1]["status"], "MATCHES_FOUND")
                self.assertIn("not-candidate-generation-action", snapshot["queries"][-1]["authority"])
                self.assertEqual(post("/v1/observe", food_packet("http-c")),
                                 decide_action(food_packet("http-c")))
            finally:
                server.shutdown()
                thread.join()
                server.server_close()


if __name__ == "__main__":
    unittest.main()
