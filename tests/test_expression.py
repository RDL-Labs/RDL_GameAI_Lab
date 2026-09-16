import copy
import unittest

from runtime.core import decide_action
from runtime.expression import with_expression
from runtime.history_policy import HistoryInfluencePolicy
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_experience import food_packet
import test_history_policy


class ExpressionTests(unittest.TestCase):
    def test_no_actionable_context_observes_and_food_engages(self):
        packet = food_packet("now")
        self.assertEqual(decide_action(packet)["inspection"]["expression"]["label"], "engaged")
        packet["observation"]["visible_objects"] = []
        self.assertEqual(decide_action(packet)["inspection"]["expression"]["label"], "observing")

    def test_identical_context_different_history_and_profiles(self):
        history = test_history_policy.HistoryPolicyTests().history()
        packet = food_packet("now")
        packet["tick"] = 2
        for profile, label in (("short", "engaged"), ("long", "holding")):
            response = HistoryInfluencePolicy(profiles={"npc_a": profile}).decide(packet, history)
            expression = response["inspection"]["expression"]
            self.assertEqual(expression["label"], label)
            self.assertEqual(expression["profile_id"], f"retry-{profile}-v1")
            if label == "holding":
                self.assertEqual(expression["history_record_ids"], [history.snapshot()["records"][0]["record_id"]])

    def test_body_and_history_factors_coexist(self):
        history = test_history_policy.HistoryPolicyTests().history()
        packet = food_packet("now")
        packet["observation"]["body"] = {"agent_id": "npc_a", "snapshot_id": "body-1", "revision": 1, "movement_scale": 0}
        response = HistoryInfluencePolicy().decide(packet, history)
        expression = response["inspection"]["expression"]
        self.assertEqual(expression["label"], "restricted")
        self.assertEqual(expression["factors"], ["movement-limited", "recent-no-progress"])
        self.assertEqual(expression["body_snapshot_id"], "body-1")

    def test_derivation_is_pure_and_cannot_change_action(self):
        response = decide_action(food_packet("now"))
        before = copy.deepcopy(response)
        annotated = with_expression(response)
        self.assertEqual(response, before)
        self.assertEqual(annotated["action"], response["action"])
        annotated["inspection"]["expression"]["factors"].append("changed")
        self.assertEqual(response, before)

    def test_equal_h_does_not_imply_equal_expression(self):
        packet = food_packet("now")
        packet["tick"] = 2
        history = test_history_policy.HistoryPolicyTests().history()
        outputs = []
        for profile in ("short", "long"):
            canonical = GameAIFrozenComparisonSidecar()
            canonical.capture(food_packet("prior"))
            response = HistoryInfluencePolicy(profiles={"npc_a": profile}).decide(packet, history)
            canonical.capture(packet)
            self.assertEqual(canonical.assessments.snapshot()["retained_H"][0]["H"], 0)
            outputs.append(response["inspection"]["expression"]["label"])
        self.assertEqual(outputs, ["engaged", "holding"])
