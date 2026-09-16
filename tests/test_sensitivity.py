from dataclasses import FrozenInstanceError
import unittest

from runtime.history_policy import HistoryInfluencePolicy
from runtime.sensitivity import RETRY_PROFILES, parse_retry_profiles
from test_experience import food_packet
import test_history_policy


class SensitivityTests(unittest.TestCase):
    def test_identical_packet_and_history_differ_only_by_profile(self):
        history = test_history_policy.HistoryPolicyTests().history()
        packet = food_packet("current")
        packet["tick"] = 2
        before = history.snapshot()
        for name, expected, ticks in (("short", "approach", 1), ("standard", "idle", 3), ("long", "idle", 5)):
            response = HistoryInfluencePolicy(profiles={"npc_a": name}).decide(packet, history)
            self.assertEqual(response["action"]["type"], expected)
            self.assertEqual(response["inspection"]["history_influence"]["retry_ticks"], ticks)
            self.assertEqual(response["inspection"]["history_influence"]["profile_id"], f"retry-{name}-v1")
        self.assertEqual(history.snapshot(), before)

    def test_retry_boundaries_for_each_profile(self):
        history = test_history_policy.HistoryPolicyTests().history()
        for name, profile in RETRY_PROFILES.items():
            for age, expected in ((profile.retry_ticks - 1, "idle"), (profile.retry_ticks, "approach")):
                packet = food_packet("current")
                packet["tick"] = 1 + age
                response = HistoryInfluencePolicy(profiles={"npc_a": name}).decide(packet, history)
                self.assertEqual(response["action"]["type"], expected)

    def test_configuration_is_frozen_and_agent_scoped(self):
        configured = {"npc_a": "short"}
        policy = HistoryInfluencePolicy(profiles=configured)
        configured["npc_a"] = "long"
        for agent, profile_id in (("npc_a", "retry-short-v1"), ("npc_b", "retry-standard-v1")):
            history = test_history_policy.HistoryPolicyTests().history(agent=agent)
            response = policy.decide(food_packet("current", agent), history)
            self.assertEqual(response["inspection"]["history_influence"]["profile_id"], profile_id)
        with self.assertRaises(FrozenInstanceError):
            RETRY_PROFILES["short"].retry_ticks = 20
        with self.assertRaises(TypeError):
            RETRY_PROFILES["short"] = RETRY_PROFILES["long"]

    def test_configuration_parser_rejects_invalid_or_duplicate_assignments(self):
        self.assertEqual(parse_retry_profiles(["npc_a=short", "npc_b=long"]), {"npc_a": "short", "npc_b": "long"})
        for values in (["npc_a=unknown"], ["=short"], ["npc_a"], ["npc_a=short", "npc_a=long"]):
            with self.assertRaises(ValueError):
                parse_retry_profiles(values)
