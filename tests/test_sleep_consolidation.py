import copy
import unittest

from runtime.core import ObservationError, decide_action
from runtime.experience import InteractionHistory
from runtime.sleep_consolidation import SleepConsolidationCoordinator
from test_experience import food_packet, result


def sleep_packet(observation_id="sleep-source", *, agent="npc_a", tick=10):
    return {
        "observation_id": observation_id,
        "tick": tick,
        "agent_id": agent,
        "observation": {
            "visible_agents": [],
            "visible_objects": [],
            "visible_places": [{
                "id": "plaza", "rest_capable": True, "rest_safety": "safe",
                "within_reach": True, "rest_distance_band": "within_reach",
            }],
            "body": {
                "agent_id": agent, "snapshot_id": "body-sleep-1",
                "revision": 1, "movement_scale": 1.0,
                "food_actions_enabled": False, "rest_actions_enabled": True,
                "sleep_actions_enabled": True, "sleep_window": True,
                "sleep_consolidation_cycle": "night-001",
                "rest_need": 0.9, "held_food_ids": [],
            },
        },
    }


def sleep_result(observation_id="sleep-source", *, agent="npc_a", tick=10):
    return {
        "result_id": f"sleep-{observation_id}",
        "agent_id": agent,
        "source_observation_id": observation_id,
        "subsequent_observation_id": observation_id + "-after",
        "target_id": "plaza",
        "tick": tick,
        "sleep_cycle": "night-001",
        "outcome": "bounded_sleep_completed",
    }


class SleepConsolidationTests(unittest.TestCase):
    def history_with(self, count):
        history = InteractionHistory()
        for index in range(count):
            source = f"day-{index}"
            packet = food_packet(source)
            history.register_decision(packet, decide_action(packet))
            history.record_result(result(source))
        return history

    def register_sleep(self, coordinator, packet=None):
        packet = packet or sleep_packet()
        decision = decide_action(packet)
        self.assertEqual(decision["action"]["type"], "sleep")
        coordinator.register_decision(packet, decision, self.current_history.snapshot())

    def test_real_sleep_result_runs_s1_to_s3_from_accepted_day_experience(self):
        history = self.history_with(3)
        self.current_history = history
        coordinator = SleepConsolidationCoordinator()
        self.register_sleep(coordinator)
        before = history.snapshot()
        record = coordinator.record_result(sleep_result(), history.snapshot())
        self.assertEqual(record["status"], "CANDIDATE_FORMED")
        self.assertEqual(record["window"]["source_count"], 3)
        self.assertEqual(
            record["candidate"]["source_experience_ids"],
            record["window"]["source_experience_ids"],
        )
        self.assertEqual(
            set(record["window"]["source_experience_ids"]),
            {item["record_id"] for item in before["records"]},
        )
        self.assertEqual(history.snapshot(), before)
        self.assertIn("not-action-E-H-theta-M_delta-M_B-prime-or-T1", record["authority"])

    def test_sleep_success_alone_does_not_manufacture_candidate(self):
        history = self.history_with(2)
        self.current_history = history
        coordinator = SleepConsolidationCoordinator()
        self.current_history = history
        self.register_sleep(coordinator)
        record = coordinator.record_result(sleep_result(), history.snapshot())
        self.assertEqual(record["status"], "INSUFFICIENT_EVIDENCE")
        self.assertIsNone(record["deep_similarity"])
        self.assertIsNone(record["candidate"])

    def test_result_requires_registered_matching_sleep_decision(self):
        history = self.history_with(3)
        self.current_history = history
        coordinator = SleepConsolidationCoordinator()
        with self.assertRaisesRegex(ObservationError, "no registered"):
            coordinator.record_result(sleep_result(), history.snapshot())
        self.register_sleep(coordinator)
        cases = []
        wrong_target = sleep_result()
        wrong_target["target_id"] = "z_grove"
        cases.append(wrong_target)
        same_observation = sleep_result()
        same_observation["subsequent_observation_id"] = "sleep-source"
        cases.append(same_observation)
        wrong_outcome = sleep_result()
        wrong_outcome["outcome"] = "sleep_attempted"
        cases.append(wrong_outcome)
        for payload in cases:
            with self.subTest(payload=payload), self.assertRaises(ObservationError):
                coordinator.record_result(payload, history.snapshot())
        self.assertEqual(coordinator.snapshot()["results"], [])

    def test_exact_replay_is_idempotent_and_conflict_is_rejected(self):
        history = self.history_with(3)
        self.current_history = history
        coordinator = SleepConsolidationCoordinator()
        self.register_sleep(coordinator)
        payload = sleep_result()
        first = coordinator.record_result(payload, history.snapshot())
        self.assertEqual(first, coordinator.record_result(payload, history.snapshot()))
        conflict = copy.deepcopy(payload)
        conflict["tick"] += 1
        with self.assertRaisesRegex(ObservationError, "conflicting"):
            coordinator.record_result(conflict, history.snapshot())


if __name__ == "__main__":
    unittest.main()
