import copy
import json
from pathlib import Path
import unittest

from runtime.core import decide_action


FIXTURE = Path(__file__).parents[1] / "integrations" / "luanti" / "tests" / "observation.fixture.json"


class LuantiBridgeContractTests(unittest.TestCase):
    def packet(self):
        return json.loads(FIXTURE.read_text(encoding="utf-8"))

    def test_finite_observation_produces_existing_runtime_action(self):
        response = decide_action(self.packet())
        self.assertEqual(response["agent_id"], "npc_a")
        self.assertEqual(response["action"], {
            "type": "approach", "target_id": "ordinary_food_1"
        })

    def test_subsequent_within_reach_observation_produces_pickup(self):
        packet = self.packet()
        packet["tick"] = 1
        packet["observation_id"] = "luanti-000001-npc_a"
        packet["observation"]["body"]["snapshot_id"] = "luanti-body-000001"
        packet["observation"]["body"]["revision"] = 1
        item = packet["observation"]["visible_objects"][0]
        item.update({"distance": 1.25, "distance_band": "within_reach", "within_reach": True})
        response = decide_action(packet)
        self.assertEqual(response["action"], {
            "type": "pickup", "target_id": "ordinary_food_1"
        })

    def test_fixture_has_no_interpretive_labels_or_raw_ids(self):
        packet = self.packet()
        encoded = json.dumps(packet, sort_keys=True).lower()
        for forbidden in ("dangerous", "valuable", "good", "bad", "objectref"):
            self.assertNotIn(forbidden, encoded)
        self.assertLessEqual(len(packet["observation"]["visible_objects"]), 16)
        self.assertLessEqual(len(packet["observation"]["visible_regions"]), 32)

    def test_runtime_does_not_mutate_source_packet(self):
        packet = self.packet()
        before = copy.deepcopy(packet)
        decide_action(packet)
        self.assertEqual(packet, before)


if __name__ == "__main__":
    unittest.main()
