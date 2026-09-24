import json
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.request import Request, urlopen
from unittest.mock import patch

from runtime import bridge
from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.mechanisms.fast_retrieval import FastRetrievalStore
from runtime.sleep_consolidation import SleepConsolidationCoordinator
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_experience import food_packet, result
from test_sleep_consolidation import sleep_packet, sleep_result


class FastDeepCycleEvidenceTests(unittest.TestCase):
    def test_day_sleep_next_day_rediscovers_sourced_candidate_over_http(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        sleep = SleepConsolidationCoordinator()
        fast = FastRetrievalStore()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(
            bridge, "CANONICAL_SIDECAR", canonical
        ):
            server = ThreadingHTTPServer(("127.0.0.1", 0), bridge.BridgeHandler)
            server.sleep_consolidation = sleep
            server.fast_retrieval = fast
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            base = f"http://127.0.0.1:{server.server_port}"

            def post(path, payload):
                request = Request(base + path, json.dumps(payload).encode(),
                                  {"Content-Type": "application/json"})
                with urlopen(request, timeout=3) as response:
                    return json.load(response)

            try:
                day_one_ids = []
                for tick, source in enumerate(("day-one-a", "day-one-b", "day-one-c"), 1):
                    packet = food_packet(source)
                    packet["tick"] = tick
                    expected = decide_action(packet)
                    self.assertEqual(post("/v1/observe", packet), expected)
                    reported = result(source)
                    reported["tick"] = tick
                    accepted = post("/v1/interaction-result", reported)["record"]
                    day_one_ids.append(accepted["record_id"])

                night = sleep_packet(tick=10)
                self.assertEqual(post("/v1/observe", night)["action"]["type"], "sleep")
                sleep_record = post("/v1/sleep-result", sleep_result(tick=10))["record"]
                candidate = sleep_record["candidate"]
                self.assertEqual(candidate["source_experience_ids"], day_one_ids)

                day_two = food_packet("day-two-current")
                day_two["tick"] = 20
                action_without_retrieval_authority = decide_action(day_two)
                self.assertEqual(post("/v1/observe", day_two), action_without_retrieval_authority)
                day_two_result = result("day-two-current")
                day_two_result["tick"] = 20
                post("/v1/interaction-result", day_two_result)

                with urlopen(base + "/v1/fast-retrieval-snapshot", timeout=3) as response:
                    snapshot = json.load(response)
                latest = snapshot["queries"][-1]
                recovered = next(item for item in latest["results"]
                                 if item["source_type"] == "sleep_candidate")
                self.assertEqual(recovered["source_id"], candidate["candidate_id"])
                self.assertEqual(recovered["source_provenance"]["sleep_cycle"], "night-001")
                self.assertEqual(recovered["source_provenance"]["source_experience_ids"], day_one_ids)
                self.assertTrue(recovered["l1"]["matched_relation_signatures"])
                self.assertEqual(decide_action(day_two), action_without_retrieval_authority)
                self.assertEqual(len(history.snapshot()["records"]), 4)
                self.assertIn("not-candidate-generation-action", latest["authority"])
            finally:
                server.shutdown()
                thread.join()
                server.server_close()


if __name__ == "__main__":
    unittest.main()
