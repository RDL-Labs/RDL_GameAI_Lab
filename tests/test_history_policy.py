import unittest

from runtime.core import ObservationError, decide_action
from runtime.experience import InteractionHistory
from runtime.history_policy import HistoryInfluencePolicy
from test_experience import food_packet, result


class HistoryPolicyTests(unittest.TestCase):
    def history(self, outcome="approach_no_progress", agent="npc_a", rule="radius-145"):
        history = InteractionHistory()
        observed = food_packet("past", agent, rule)
        history.register_decision(observed, decide_action(observed))
        history.record_result(result("past", outcome, agent))
        return history

    def test_same_current_observation_different_history_changes_action(self):
        current = food_packet("current")
        cases = [(InteractionHistory(), "approach"),
                 (self.history("approach_progress"), "approach"),
                 (self.history(), "idle")]
        for history, expected in cases:
            decision = HistoryInfluencePolicy().decide(current, history)
            self.assertEqual(decision["action"]["type"], expected)
            if expected == "idle":
                trace = decision["inspection"]["history_influence"]
                self.assertTrue(trace["action_changed"])
                self.assertEqual(trace["deferred_targets"][0]["record_id"], history.snapshot()["records"][0]["record_id"])

    def test_retry_boundary_and_future_history_exclusion(self):
        history = self.history()
        for tick, expected in ((0, "approach"), (1, "idle"), (3, "idle"), (4, "approach")):
            observed = food_packet(f"current-{tick}")
            observed["tick"] = tick
            self.assertEqual(HistoryInfluencePolicy().decide(observed, history)["action"]["type"], expected)

    def test_alternative_must_be_currently_visible_food(self):
        observed = food_packet("current")
        observed["observation"]["visible_objects"].append({"id": "food_02", "kind": "food"})
        action = HistoryInfluencePolicy().decide(observed, self.history())["action"]
        self.assertEqual(action, {"type": "approach", "target_id": "food_02"})
        observed["observation"]["visible_objects"] = []
        self.assertEqual(HistoryInfluencePolicy().decide(observed, self.history())["action"], {"type": "idle"})

    def test_agent_and_context_are_isolated(self):
        observed = food_packet("current")
        for history in (self.history(agent="npc_b"), self.history(rule="other")):
            self.assertEqual(HistoryInfluencePolicy().decide(observed, history)["action"], decide_action(observed)["action"])

    def test_latest_progress_supersedes_deferral_but_keeps_both_records(self):
        history = self.history()
        newer = food_packet("newer")
        newer["tick"] = 2
        history.register_decision(newer, decide_action(newer))
        report = result("newer", "approach_progress")
        report["tick"] = 2
        history.record_result(report)
        current = food_packet("current")
        current["tick"] = 2
        self.assertEqual(HistoryInfluencePolicy().decide(current, history)["action"]["type"], "approach")
        self.assertEqual(len(history.snapshot()["records"]), 2)

    def test_replay_is_frozen_and_capacity_is_explicit(self):
        policy = HistoryInfluencePolicy(capacity=1)
        current = food_packet("current")
        first = policy.decide(current, InteractionHistory())
        self.assertEqual(policy.decide(current, self.history()), first)
        first["action"].clear()
        self.assertEqual(policy.decide(current, self.history())["action"]["type"], "approach")
        current["tick"] = 2
        with self.assertRaises(ObservationError):
            policy.decide(current, self.history())
        with self.assertRaises(ObservationError):
            policy.decide(food_packet("different"), self.history())
