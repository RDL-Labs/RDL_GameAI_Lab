import copy
import unittest

from runtime.core import ObservationError, decide_action


class BoundedAgentConditionTests(unittest.TestCase):
    def packet(self):
        return {
            "observation_id": "discovery-1",
            "tick": 1,
            "agent_id": "npc_a",
            "observation": {
                "visible_agents": [{
                    "id": "npc_b",
                    "condition": "incapacitated",
                    "condition_schema": "bounded-visible-agent-condition-v1",
                    "within_reach": False,
                }],
                "visible_objects": [],
                "visible_places": [],
            },
        }

    def test_condition_is_valid_but_has_no_rescue_authority(self):
        decision = decide_action(self.packet())
        self.assertEqual(decision["action"], {"type": "idle"})

    def test_condition_vocabulary_and_provenance_are_finite(self):
        for field, value in (("condition", "severe"), ("condition_schema", "unknown-v2")):
            packet = copy.deepcopy(self.packet())
            packet["observation"]["visible_agents"][0][field] = value
            with self.subTest(field=field), self.assertRaises(ObservationError):
                decide_action(packet)
        orphaned = copy.deepcopy(self.packet())
        del orphaned["observation"]["visible_agents"][0]["condition"]
        with self.assertRaises(ObservationError):
            decide_action(orphaned)


if __name__ == "__main__":
    unittest.main()
