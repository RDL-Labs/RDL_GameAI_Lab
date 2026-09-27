import copy
import json
from pathlib import Path
import unittest

from runtime.sensory_observation import SensoryObservationStore
from runtime.sensory_food_learning import SensoryFoodLearning, comparison
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from runtime.theta_effective import FiniteThetaEffectiveEvaluator
from test_sensory_observation import packet, distant_extension


class SensoryFoodLearningTests(unittest.TestCase):
    def setUp(self):
        self.store = SensoryObservationStore(assignments={"npc_a": ("fixture-life-sensory", 1)})
        self.canonical = GameAIFrozenComparisonSidecar(theta_evaluator=FiniteThetaEffectiveEvaluator(1.0))
        self.loop = SensoryFoodLearning(self.store, self.canonical)

    def observe(self, index, color="muted_red", now_offset=0, **changes):
        p = packet(f"obs-{index}", tick=index * 4)
        ext = distant_extension(p)
        f = ext["frames"][0]
        f.update(frame_id=f"frame-{index}", sample_seq=index, profile_id="fixture-life-sensory")
        f["capture_window"].update(start_us=index * 1000000, end_us=index * 1000000)
        f["payload"]["features"][0].update(color_band=color, azimuth_interval_deg=[0, 5])
        f.update(changes)
        ext["delivery_time_us"] = index * 1000000
        self.store.admit(p, ext)
        self.canonical.capture(p)
        request = {"operation_id": f"op-{index}", "episode_id": f"episode-{index}",
                   "agent_id": "npc_a", "run_id": "fixture-run-1", "world_epoch": 1,
                   "frame_id": f["frame_id"], "now_us": index * 1000000 + now_offset}
        return request, self.loop.decide(request)

    def result(self, index, acquired, attempted=True):
        return self.loop.record({"operation_id": f"op-{index}", "event_id": f"event-{index}",
            "completed_us": index * 1000000 + 100000, "attempted": attempted, "food_acquired": acquired})

    def materials(self, reverse=False, contradict=False):
        for i in range(1, 9):
            self.observe(i, "muted_red" if i % 2 else "dark_gray")
            acquired = bool(i % 2) if reverse else not bool(i % 2)
            self.result(i, not acquired if contradict and i == 7 else acquired)
        p = packet("independent", tick=40)
        p["observation"]["visible_objects"] = [{"id": "object"}]
        self.canonical.capture(p)
        record = self.canonical.snapshot()["assessment"]["records"][-1]
        self.canonical.review_assessment({"assessment_id": record["assessment_id"], "expected_revision": 0,
            "reviewer": "test", "basis": "explicit independent review", "evidence": "independent",
            "dimensions": {k: {"status": "unresolved", "residual": 1.0} if v else {"status": "zero"}
                           for k, v in record["E"]["deltas"].items()}})
        return {"learning_id": "learn", "agent_id": "npc_a", "formation_operations": [f"op-{i}" for i in range(1, 7)],
                "validation_operations": ["op-7", "op-8"], "assessment_id": record["assessment_id"], "activate": True}

    def test_learned_active_mb_changes_action_and_preserves_parent(self):
        request = self.materials()
        parent = self.canonical.model_for_agent("npc_a").to_json()
        result = self.loop.learn(request)
        self.assertEqual(result["status"], "activated")
        _, red = self.observe(9)
        _, dark = self.observe(10, "dark_gray")
        self.assertEqual(red["action"], "defer")
        self.assertEqual(dark["action"], "attempt_food")
        self.assertEqual(red["prediction"]["values"], {"food_acquired": 0.0})
        self.assertEqual(dark["prediction"]["values"], {"food_acquired": 1.0})
        self.assertEqual(self.canonical.snapshot()["model_archive"][parent["model_ref"]], parent)
        self.assertEqual(len(result["artifact"]["adopted_relations"]), 2)

    def test_inactive_artifact_does_not_change_action(self):
        request = self.materials(); request["activate"] = False
        result = self.loop.learn(request)
        self.assertEqual(result["status"], "reconstructed_inactive_control")
        _, decision = self.observe(9)
        self.assertEqual(decision["action"], "attempt_food")
        self.assertEqual(decision["prediction"]["status"], "unknown")

    def test_color_mapping_is_induced_and_can_reverse(self):
        self.loop.learn(self.materials(reverse=True))
        self.assertEqual(self.observe(9)[1]["action"], "attempt_food")
        self.assertEqual(self.observe(10, "dark_gray")[1]["action"], "defer")

    def test_held_out_counterexample_rejects_only_that_relation(self):
        result = self.loop.learn(self.materials(contradict=True))
        self.assertEqual({i["color_band"]: i["disposition"] for i in result["inspections"]},
                         {"muted_red": "REJECT", "dark_gray": "RETAIN"})
        self.assertEqual(self.observe(9)[1]["prediction"]["status"], "unknown")

    def test_defer_creates_no_failure_experience(self):
        self.loop.learn(self.materials())
        self.observe(9)
        result = self.result(9, None, attempted=False)
        self.assertIsNone(result["experience"])
        self.assertEqual(result["comparison"]["status"], "not_attempted")

    def test_unexpected_failure_compares_under_same_model(self):
        self.loop.learn(self.materials())
        _, decision = self.observe(9, "dark_gray")
        result = self.result(9, False)
        self.assertEqual(result["comparison"]["E"]["deltas"], {"food_acquired": -1.0})
        self.assertEqual(result["F_prime"]["model_ref"], decision["model_ref"])
        self.assertEqual(self.canonical.snapshot()["M_delta"]["active_count"], 0)

    def test_pending_decision_keeps_old_model_after_cutover(self):
        req = self.materials()
        _, decision = self.observe(9, "dark_gray")
        self.loop.learn(req)
        result = self.result(9, True)
        self.assertEqual(result["F_prime"]["model_ref"], decision["model_ref"])
        self.assertEqual(result["comparison"]["status"], "not_comparable")

    def test_partial_and_empty_acquisition_are_not_negative_evidence(self):
        _, decision = self.observe(1, coverage="PARTIAL")
        self.assertEqual(decision["action"], "defer")
        self.assertIsNone(decision["prediction"]["values"])

    def test_replay_conflict_and_detached_outputs(self):
        req, decision = self.observe(1)
        self.assertEqual(self.loop.decide(req), decision)
        decision["prediction"]["reasons"].append("tamper")
        self.assertNotEqual(self.loop.decide(req), decision)
        changed = dict(req, now_us=req["now_us"]+1)
        with self.assertRaisesRegex(ValueError, "conflict"):
            self.loop.decide(changed)
        result = self.result(1, False)
        self.assertEqual(self.loop.record(result["result"]), result)
        with self.assertRaisesRegex(ValueError, "conflict"):
            self.result(1, True)

    def test_foreign_unknown_stale_and_hidden_inputs(self):
        req, _ = self.observe(1)
        for changed in [dict(req, operation_id="new", episode_id="new", agent_id="npc_b"),
                        dict(req, operation_id="new", episode_id="new", frame_id="missing"),
                        dict(req, hidden_blocked=True)]:
            with self.assertRaises(ValueError):
                self.loop.decide(changed)
        self.assertEqual(self.observe(2, now_offset=600000)[1]["action"], "defer")

    def test_distinct_validation_and_event_identity(self):
        req = self.materials()
        req["validation_operations"][0] = req["formation_operations"][0]
        with self.assertRaisesRegex(ValueError, "distinct"):
            self.loop.learn(req)
        self.observe(9)
        with self.assertRaisesRegex(ValueError, "event reused"):
            self.loop.record({"operation_id": "op-9", "event_id": "event-1", "completed_us": 9100000,
                              "attempted": True, "food_acquired": True})

    def test_learning_replay_and_no_mutation_on_read(self):
        req = self.materials(); result = self.loop.learn(req)
        before = copy.deepcopy((self.loop.snapshot(), self.canonical.snapshot()))
        self.assertEqual(self.loop.learn(req), result)
        self.assertEqual((self.loop.snapshot(), self.canonical.snapshot()), before)
        with self.assertRaisesRegex(ValueError, "conflict"):
            self.loop.learn(dict(req, activate=False))

    def test_comparison_refuses_different_model(self):
        self.loop.learn(self.materials()); _, decision = self.observe(9, "dark_gray")
        result = self.result(9, True)
        changed = copy.deepcopy(result["F_prime"]); changed["model_ref"] = "other"
        with self.assertRaisesRegex(ValueError, "same frozen"):
            comparison(decision["prediction"], changed)

    def test_finite_capacity_does_not_break_replay(self):
        req, first = self.observe(1)
        for i in range(2, 17): self.observe(i)
        with self.assertRaisesRegex(ValueError, "capacity"):
            self.observe(17)
        self.assertEqual(self.loop.decide(req), first)

    def test_episode_or_frame_alias_does_not_create_another_trial(self):
        req, _ = self.observe(1)
        with self.assertRaisesRegex(ValueError, "episode already"):
            self.loop.decide(dict(req, operation_id="alias"))
        with self.assertRaisesRegex(ValueError, "source frame already"):
            self.loop.decide(dict(req, operation_id="alias", episode_id="new"))

    def test_action_reads_adopted_model_not_experience_counter(self):
        self.loop.learn(self.materials())
        # A fresh consumer with no local experiences still interprets the active M_B.
        self.loop = SensoryFoodLearning(self.store, self.canonical)
        decision = self.observe(9)[1]
        self.assertEqual(decision["action"], "defer")
        self.assertTrue(decision["prediction"]["source_candidates"])

    def test_absent_feature_defers_without_claiming_no_food(self):
        _, decision = self.observe(1, payload={"features": []})
        self.assertEqual(decision["action"], "defer")
        self.assertIn("single_feature_unavailable", decision["prediction"]["reasons"])
        self.assertIsNone(decision["prediction"]["values"])

    def test_result_cannot_claim_unattempted_failure_or_late_success(self):
        self.observe(1, coverage="PARTIAL")
        with self.assertRaisesRegex(ValueError, "unattempted"):
            self.result(1, False, attempted=False)
        self.observe(2)
        with self.assertRaisesRegex(ValueError, "result time"):
            self.loop.record({"operation_id": "op-2", "event_id": "late", "completed_us": 8000000,
                              "attempted": True, "food_acquired": True})
        self.assertEqual(self.loop.snapshot()["results"], {})

    def test_real_luanti_frames_and_results_replay_through_store_t1_and_action(self):
        data = json.loads((Path(__file__).parent / "fixtures/luanti_l10_replay.json").read_text(encoding="utf-8"))
        for run in data["runs"]:
            with self.subTest(activate=run["activate"], reverse=run["reverse"]):
                self.setUp()
                self.store.run_id = run["run_id"]
                operations = []
                for index, trial in enumerate(run["trials"], 1):
                    request = trial["request"]
                    p = packet(f"replay-before-{index}", tick=request["now_us"] // 250000)
                    p["observation"]["visible_objects"] = [{"id": "local_food", "kind": "food"}]
                    frames = [f for f in run["frames"] if f["sample_seq"] == index]
                    self.assertEqual(len(frames), 3)
                    # Store ownership metadata belongs to the delivery envelope on readmission.
                    wire_frames = [{k: v for k, v in f.items() if k not in ("run_id", "world_epoch")} for f in frames]
                    ext = {"schema_version": "rdl-sensory-extension-v1", "run_id": run["run_id"],
                           "world_epoch": 1, "agent_id": "npc_a", "delivery_observation_id": p["observation_id"],
                           "delivery_world_tick": p["tick"], "delivery_time_us": request["now_us"], "frames": wire_frames}
                    self.assertEqual(self.store.admit(p, ext)["new_frames"], 3)
                    stored = {f["frame_id"]: f for f in self.store.snapshot()["frames"]}
                    for f in frames: self.assertEqual(stored[f["frame_id"]], f)
                    self.canonical.capture(p)
                    decision = self.loop.decide(request)
                    self.assertEqual(decision["action"], trial["expected_action"])
                    self.assertEqual(decision["prediction"]["status"], trial["expected_prediction"])
                    self.assertEqual(trial["world"]["authority_consumptions"], 1)
                    self.assertEqual(trial["world"]["base_stock_after"] - trial["world"]["base_stock_before"],
                                     int(trial["world"]["deposited"]))
                    self.assertEqual(self.loop.decide(request), decision)
                    result = self.loop.record(trial["result"])
                    operations.append(request["operation_id"])
                    if trial["result"]["attempted"]:
                        self.assertEqual(result["experience"]["food_acquired"], not trial["world"]["hidden_blocked"])
                        if index > 8 and run["activate"]:
                            self.assertEqual(result["comparison"]["E"]["deltas"]["food_acquired"], -1.0 if index >= 11 else 0.0)
                    else:
                        self.assertIsNone(result["experience"])
                        self.assertEqual(trial["world"]["actions"], 0)
                        self.assertEqual(trial["world"]["start"], trial["world"]["finish"])
                    after = packet(f"replay-after-{index}", tick=trial["result"]["completed_us"] // 250000)
                    after["observation"]["visible_objects"] = [] if trial["result"]["food_acquired"] else p["observation"]["visible_objects"]
                    self.canonical.capture(after)
                    if index == 8:
                        assessment = [a for a in self.canonical.snapshot()["assessment"]["records"]
                                      if a["E"]["deltas"]["visible_objects_count"] != 0][-1]
                        self.canonical.review_assessment({"assessment_id": assessment["assessment_id"],
                            "expected_revision": 0, "reviewer": "replay-explicit", "basis": "independent count review", "evidence": run["run_id"],
                            "dimensions": {k: {"status": "unresolved", "residual": 1.0} if v else {"status": "zero"}
                                           for k, v in assessment["E"]["deltas"].items()}})
                        self.loop.learn({"learning_id": "replay-learning", "agent_id": "npc_a",
                            "formation_operations": operations[:6], "validation_operations": operations[6:8],
                            "assessment_id": assessment["assessment_id"], "activate": run["activate"]})
                self.assertEqual(self.store.snapshot()["count"], 36)


if __name__ == "__main__":
    unittest.main()
