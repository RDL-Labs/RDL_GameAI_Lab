import copy
import json
from pathlib import Path
import unittest

from runtime.life_policy import BaseFoodLifePolicy


FIXTURE = Path(__file__).parents[1] / "integrations" / "luanti" / "tests" / "observation.fixture.json"
CUE_ID = "luanti-morning-base-food-low-1"


def packet(observation_id, *, within_reach=False, held=None, at_base=False):
    value = json.loads(FIXTURE.read_text(encoding="utf-8"))
    value["observation_id"] = observation_id
    value["tick"] = int(observation_id.rsplit("-", 1)[-1])
    value["observation"]["body"]["snapshot_id"] = f"body-{observation_id}"
    value["observation"]["body"]["held_food_ids"] = list(held or [])
    value["observation"]["inventory"]["held_food_ids"] = list(held or [])
    value["observation"]["visible_places"] = [{"id": "base", "within_reach": at_base}]
    value["observation"]["life_context"] = {
        "god_statue_cue": {
            "cue_id": CUE_ID,
            "source": "system_assessment",
            "topic": "base_food",
            "band": "low",
            "delivery": "morning",
        },
        "observed_base_food_band": "low",
        "known_base": {"id": "base"},
        "at_base": at_base,
        "interrupt_candidates": [],
    }
    item = value["observation"]["visible_objects"][0]
    item["within_reach"] = within_reach
    return value


class LuantiL3ContractTests(unittest.TestCase):
    def test_existing_policy_completes_luanti_food_vertical(self):
        policy = BaseFoodLifePolicy()
        go_to_site = policy.decide(packet("luanti-l3-0"))
        self.assertEqual(go_to_site["action"], {
            "type": "approach", "target_id": "ordinary_food_1"
        })

        gather = policy.decide(packet("luanti-l3-1", within_reach=True))
        self.assertEqual(gather["action"], {
            "type": "pickup", "target_id": "ordinary_food_1"
        })

        returning = policy.decide(packet("luanti-l3-2", held=["ordinary_food_1"]))
        self.assertEqual(returning["action"], {"type": "approach", "target_id": "base"})

        deposit_packet = packet(
            "luanti-l3-3", held=["ordinary_food_1"], at_base=True
        )
        deposit = policy.decide(deposit_packet)
        self.assertEqual(deposit["action"], {"type": "deposit", "target_id": "base"})
        accepted = policy.record_result({
            "result_id": "luanti-deposit-000003-npc_a",
            "agent_id": "npc_a",
            "source_observation_id": "luanti-l3-3",
            "cue_id": CUE_ID,
            "response": "follow",
            "outcome": "replenish_success",
        })
        self.assertEqual(accepted["outcome"], "replenish_success")
        self.assertEqual(policy.snapshot()["trajectories"], {})

    def test_luanti_packet_does_not_gain_world_truth_label(self):
        value = packet("luanti-l3-0")
        before = copy.deepcopy(value)
        BaseFoodLifePolicy().decide(value)
        self.assertEqual(value, before)
        self.assertNotIn("base_food_stock", json.dumps(value, sort_keys=True))


if __name__ == "__main__":
    unittest.main()
