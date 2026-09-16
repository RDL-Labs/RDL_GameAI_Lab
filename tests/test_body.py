import unittest

from runtime.core import ObservationError, decide_action
from runtime.history_policy import HistoryInfluencePolicy
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
import test_history_policy
from test_experience import food_packet


class BodyTests(unittest.TestCase):
    def packet(self, scale):
        packet = food_packet("current")
        packet["observation"]["body"] = {"agent_id": "npc_a", "snapshot_id": "body-a-1",
                                           "revision": 1, "movement_scale": scale}
        return packet

    def test_same_observation_movement_availability_changes_action(self):
        for scale, action in ((0, "idle"), (0.5, "approach"), (1, "approach")):
            response = decide_action(self.packet(scale))
            self.assertEqual(response["action"]["type"], action)
            self.assertEqual(response["inspection"]["body"]["movement_scale"], scale)

    def test_invalid_body_rejected(self):
        for field, value in (("movement_scale", -1), ("movement_scale", 2),
                             ("movement_scale", float("nan")), ("movement_scale", True),
                             ("agent_id", "npc_b"), ("snapshot_id", ""), ("revision", -1)):
            packet = self.packet(1)
            packet["observation"]["body"][field] = value
            with self.assertRaises(ObservationError):
                decide_action(packet)

    def test_history_alternative_cannot_bypass_body_constraint(self):
        packet = self.packet(0)
        packet["observation"]["visible_objects"].append({"id": "food_02", "kind": "food"})
        history = test_history_policy.HistoryPolicyTests().history()
        response = HistoryInfluencePolicy().decide(packet, history)
        self.assertEqual(response["action"], {"type": "idle"})

    def test_recovery_requires_fresh_observation_and_keeps_history(self):
        history = test_history_policy.HistoryPolicyTests().history("approach_progress")
        before = history.snapshot()
        policy = HistoryInfluencePolicy()
        packet = self.packet(0)
        self.assertEqual(policy.decide(packet, history)["action"]["type"], "idle")
        recovered = self.packet(1)
        with self.assertRaises(ObservationError):
            policy.decide(recovered, history)
        recovered["observation_id"] = "recovered"
        self.assertEqual(policy.decide(recovered, history)["action"]["type"], "approach")
        self.assertEqual(history.snapshot(), before)

    def test_body_is_not_a_canonical_count_or_h(self):
        sidecar = GameAIFrozenComparisonSidecar()
        first = self.packet(0)
        later = self.packet(1)
        later["observation_id"] = "later"
        sidecar.capture(first)
        mismatch = sidecar.capture(later)
        self.assertTrue(mismatch.is_zero)
        self.assertEqual(sidecar.assessments.snapshot()["retained_H"][0]["H"], 0)
