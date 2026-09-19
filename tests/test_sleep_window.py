import unittest

from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.sleep_window import SleepExperienceWindowStore, SleepWindowError
from test_experience import food_packet, result


class SleepExperienceWindowTests(unittest.TestCase):
    def setUp(self):
        self.history = InteractionHistory()
        self.store = SleepExperienceWindowStore()

    def record(self, source, *, agent="npc_a", tick=1):
        packet = food_packet(source, agent=agent)
        packet["tick"] = tick
        self.history.register_decision(packet, decide_action(packet))
        payload = result(source, agent=agent)
        payload["tick"] = tick
        self.history.record_result(payload)

    def form(self, **overrides):
        arguments = {
            "agent_id": "npc_a",
            "sleep_cycle": "night-001",
            "formation_tick": 20,
            "enabled": True,
        }
        arguments.update(overrides)
        return self.store.form_window(self.history.snapshot(), **arguments)

    def test_opt_in_and_insufficient_evidence_are_explicit(self):
        self.record("a")
        with self.assertRaises(SleepWindowError):
            self.store.form_window(
                self.history.snapshot(), agent_id="npc_a", sleep_cycle="night-001",
                formation_tick=20,
            )
        window = self.form()
        self.assertEqual(window["status"], "INSUFFICIENT_EVIDENCE")
        self.assertEqual(window["source_count"], 1)

    def test_window_is_same_agent_finite_ordered_and_does_not_mutate_history(self):
        for index in range(8):
            self.record(f"a-{index}", tick=index + 1)
            self.record(f"b-{index}", agent="npc_b", tick=index + 1)
        before = self.history.snapshot()
        window = self.form()
        self.assertEqual(window["status"], "READY")
        self.assertEqual(window["source_count"], 6)
        expected = [record["record_id"] for record in before["records"]
                    if record["agent_id"] == "npc_a"][-6:]
        self.assertEqual(window["source_experience_ids"], expected)
        self.assertEqual(before, self.history.snapshot())
        self.assertNotIn("records", window)
        self.assertIn("not-relation-candidate-M_B-or-T1", window["authority"])

    def test_pending_decision_is_not_selected(self):
        for source in ("a", "b", "c"):
            self.record(source)
        pending = food_packet("pending")
        self.history.register_decision(pending, decide_action(pending))
        window = self.form()
        self.assertEqual(window["source_count"], 3)
        self.assertEqual(self.history.snapshot()["pending_results"], 1)

    def test_replay_is_immutable_when_new_history_arrives(self):
        for source in ("a", "b", "c"):
            self.record(source)
        original = self.form()
        self.record("later", tick=30)
        replay = self.form(formation_tick=999)
        self.assertEqual(replay, original)

    def test_replay_rejects_missing_or_cross_agent_sources(self):
        for source in ("a", "b", "c"):
            self.record(source)
        window = self.form()
        snapshot = self.history.snapshot()
        snapshot["records"] = snapshot["records"][1:]
        with self.assertRaisesRegex(SleepWindowError, "disappeared"):
            self.store.form_window(
                snapshot, agent_id="npc_a", sleep_cycle="night-001",
                formation_tick=20, enabled=True,
            )
        snapshot = self.history.snapshot()
        source_id = window["source_experience_ids"][0]
        next(record for record in snapshot["records"] if record["record_id"] == source_id)["agent_id"] = "npc_b"
        with self.assertRaisesRegex(SleepWindowError, "agent identity"):
            self.store.form_window(
                snapshot, agent_id="npc_a", sleep_cycle="night-001",
                formation_tick=20, enabled=True,
            )

    def test_export_is_isolated(self):
        for source in ("a", "b", "c"):
            self.record(source)
        window = self.form()
        window["source_experience_ids"].clear()
        snapshot = self.store.snapshot()
        snapshot["windows"][0]["boundary"].clear()
        self.assertEqual(self.form()["source_count"], 3)
        self.assertEqual(len(self.store.snapshot()["windows"][0]["boundary"]), 6)


if __name__ == "__main__":
    unittest.main()
