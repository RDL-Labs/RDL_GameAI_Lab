import copy
import json
from pathlib import Path
import unittest

from runtime.sensory_observation import SensoryObservationStore
from runtime.sensory_food_learning import MultiAgentSensoryFoodLearning
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from runtime.theta_effective import FiniteThetaEffectiveEvaluator
from test_sensory_observation import packet, distant_extension


class MultiSensoryLearningTests(unittest.TestCase):
    def setUp(self):
        self.profiles = {"npc_a": "fixture-life-sensory", "npc_b": "fixture-life-sensory-compact"}
        self.store = SensoryObservationStore(assignments={a: (p, 1) for a, p in self.profiles.items()})
        self.canonical = GameAIFrozenComparisonSidecar(theta_evaluator=FiniteThetaEffectiveEvaluator(1.0))
        self.loop = MultiAgentSensoryFoodLearning(self.store, self.canonical)

    def observe(self, agent, i, color="muted_red"):
        p = packet(f"{agent}-obs-{i}", agent_id=agent, tick=i * 4)
        ext = distant_extension(p)
        f = ext["frames"][0]
        f.update(frame_id=f"{agent}-frame-{i}", sample_seq=i, profile_id=self.profiles[agent])
        f["capture_window"].update(start_us=i * 1000000, end_us=i * 1000000)
        f["payload"]["features"][0].update(color_band=color, azimuth_interval_deg=[0, 5])
        ext["delivery_time_us"] = i * 1000000
        self.assertTrue(self.store.admit(p, ext)["accepted"])
        self.canonical.capture(p)
        # Deliberately reuse local operation and Episode names across both agents.
        request = {"operation_id": f"op-{i}", "episode_id": f"episode-{i}", "agent_id": agent,
                   "run_id": "fixture-run-1", "world_epoch": 1, "frame_id": f["frame_id"], "now_us": i * 1000000}
        return request, self.loop.decide(request)

    def result(self, agent, i, acquired):
        decision = self.loop.snapshot()["by_agent"][agent]["operations"][f"op-{i}"]["decision"]
        return self.loop.record({"agent_id": agent, "decision_id": decision["decision_id"],
            "operation_id": f"op-{i}", "event_id": f"event-{i}", "completed_us": i * 1000000 + 100000,
            "attempted": decision["action"] == "attempt_food", "food_acquired": acquired})

    def materials(self, agent, reverse=False):
        for i in range(1, 9):
            self.observe(agent, i, "muted_red" if i % 2 else "dark_gray")
            self.result(agent, i, bool(i % 2) if reverse else not bool(i % 2))
        p = packet(agent + "-independent", agent_id=agent, tick=40)
        p["observation"]["visible_objects"] = [{"id": "object"}]
        self.canonical.capture(p)
        record = [r for r in self.canonical.snapshot()["assessment"]["records"] if r["E"]["agent_id"] == agent][-1]
        self.canonical.review_assessment({"assessment_id": record["assessment_id"], "expected_revision": 0,
            "reviewer": "test", "basis": "explicit independent review", "evidence": "independent",
            "dimensions": {k: {"status": "unresolved", "residual": 1.0} if v else {"status": "zero"}
                           for k, v in record["E"]["deltas"].items()}})
        return {"learning_id": "learn", "agent_id": agent, "formation_operations": [f"op-{i}" for i in range(1, 7)],
                "validation_operations": ["op-7", "op-8"], "assessment_id": record["assessment_id"], "activate": True}

    def state(self):
        return self.loop.snapshot(), self.canonical.snapshot()

    def test_same_local_ids_have_distinct_decisions_experiences_and_result_sections(self):
        results, decisions = [], []
        for agent in self.profiles:
            decisions.append(self.observe(agent, 1)[1])
            results.append(self.result(agent, 1, False))
        self.assertNotEqual(decisions[0]["decision_id"], decisions[1]["decision_id"])
        self.assertNotEqual(results[0]["experience"]["record_id"], results[1]["experience"]["record_id"])
        self.assertNotEqual(results[0]["F_prime"]["section_id"], results[1]["F_prime"]["section_id"])
        for result in results:
            self.assertEqual(self.loop.record(result["result"]), result)

    def test_other_agents_receipt_cannot_fill_same_named_operation(self):
        self.observe("npc_a", 1); self.observe("npc_b", 1)
        receipt = self.result("npc_a", 1, False)["result"]
        before = self.state()
        with self.assertRaisesRegex(ValueError, "decision identity"):
            self.loop.record(dict(receipt, agent_id="npc_b"))
        self.assertEqual(self.state(), before)

    def test_unknown_agent_and_foreign_frame_refused_without_mutation(self):
        req, _ = self.observe("npc_a", 1)
        before = self.state()
        for changed in (dict(req, agent_id="npc_c"), dict(req, agent_id="npc_b")):
            with self.assertRaises(ValueError): self.loop.decide(changed)
        for method in (self.loop.record, self.loop.learn):
            with self.assertRaisesRegex(ValueError, "unknown learning agent"):
                method({"agent_id": "npc_c"})
        self.assertEqual(self.state(), before)

    def test_independent_opposite_learning_and_cutover(self):
        a = self.materials("npc_a")
        b = self.materials("npc_b", reverse=True)
        b_before = copy.deepcopy((self.loop.snapshot()["by_agent"]["npc_b"], self.canonical.model_for_agent("npc_b").to_json()))
        learned_a = self.loop.learn(a)
        self.assertEqual((self.loop.snapshot()["by_agent"]["npc_b"], self.canonical.model_for_agent("npc_b").to_json()), b_before)
        learned_b = self.loop.learn(b)
        self.assertEqual(self.observe("npc_a", 9)[1]["action"], "defer")
        self.assertEqual(self.observe("npc_b", 9)[1]["action"], "attempt_food")
        self.assertEqual(self.observe("npc_a", 10, "dark_gray")[1]["action"], "attempt_food")
        self.assertEqual(self.observe("npc_b", 10, "dark_gray")[1]["action"], "defer")
        self.assertEqual(self.canonical.snapshot()["model_cutover"]["count"], 2)
        self.assertFalse({c["candidate_id"] for c in learned_a["candidates"]} & {c["candidate_id"] for c in learned_b["candidates"]})

    def test_activation_control_with_roles_swapped(self):
        for active in self.profiles:
            with self.subTest(active=active):
                self.setUp()
                for agent in self.profiles:
                    req = self.materials(agent)
                    self.loop.learn(dict(req, activate=agent == active))
                for agent in self.profiles:
                    decision = self.observe(agent, 9)[1]
                    self.assertEqual(decision["action"], "defer" if agent == active else "attempt_food")
                    self.assertEqual(decision["prediction"]["status"], "known" if agent == active else "unknown")

    def test_foreign_assessment_cannot_reconstruct_other_agent(self):
        a, b = self.materials("npc_a"), self.materials("npc_b")
        before = self.state()
        with self.assertRaises(ValueError): self.loop.learn(dict(a, assessment_id=b["assessment_id"]))
        self.assertEqual(self.state(), before)

    def test_other_agents_sources_are_not_an_implicit_learning_input(self):
        a = self.materials("npc_a")
        before = self.state()
        with self.assertRaisesRegex(ValueError, "Experience"):
            self.loop.learn(dict(a, agent_id="npc_b"))
        self.assertEqual(self.state(), before)

    def test_capacity_is_per_agent_and_full_agent_replay_still_works(self):
        req, first = self.observe("npc_a", 1)
        for i in range(2, 17): self.observe("npc_a", i)
        with self.assertRaisesRegex(ValueError, "capacity"): self.observe("npc_a", 17)
        self.assertEqual(self.loop.decide(req), first)
        self.assertEqual(self.observe("npc_b", 1)[1]["prediction"]["status"], "unknown")
        self.assertEqual(len(self.loop.snapshot()["by_agent"]["npc_b"]["operations"]), 1)

    def test_pending_results_use_own_frozen_model_across_both_cutovers(self):
        a, b = self.materials("npc_a"), self.materials("npc_b", reverse=True)
        decisions = {agent: self.observe(agent, 9)[1] for agent in self.profiles}
        self.loop.learn(a); self.loop.learn(b)
        for agent in self.profiles:
            result = self.result(agent, 9, False)
            self.assertEqual(result["F_prime"]["model_ref"], decisions[agent]["model_ref"])
            self.assertEqual(result["comparison"]["status"], "not_comparable")

    def test_repeat_learning_and_output_mutation_do_not_change_other_agent(self):
        a, b = self.materials("npc_a"), self.materials("npc_b")
        result = self.loop.learn(a)
        before = self.state()
        self.assertEqual(self.loop.learn(a), result)
        result["candidates"].clear()
        snapshot = self.loop.snapshot(); snapshot["by_agent"]["npc_b"]["results"].clear()
        self.assertEqual(self.state(), before)
        with self.assertRaisesRegex(ValueError, "conflict"): self.loop.learn(dict(a, activate=False))
        self.assertEqual(self.state(), before)
        self.assertEqual(self.loop.learn(b)["status"], "activated")

    def test_defer_does_not_become_failure_or_remove_other_agents_experience(self):
        self.loop.learn(self.materials("npc_a"))
        self.observe("npc_b", 1); other = self.result("npc_b", 1, False)
        self.observe("npc_a", 9)
        self.assertIsNone(self.result("npc_a", 9, None)["experience"])
        self.assertEqual(self.loop.snapshot()["by_agent"]["npc_b"]["results"]["op-1"], other)

    def test_real_luanti_two_agent_frames_replay_through_own_t1_and_actions(self):
        fixture = json.loads((Path(__file__).parent / "fixtures/luanti_l10b_replay.json").read_text(encoding="utf-8"))
        for run in fixture["runs"]:
            with self.subTest(scenario=run["scenario"]):
                self.setUp(); self.store.run_id = run["run_id"]
                sources = {agent: [] for agent in self.profiles}
                for index in range(1, 13):
                    for agent, a in run["by_agent"].items():
                        trial = a["trials"][index-1]
                        req = trial["request"]
                        p = packet(f"{agent}-replay-{index}", agent_id=agent, tick=req["now_us"] // 250000)
                        p["observation"]["visible_objects"] = [{"id": "local_food", "kind": "food"}]
                        frames = [f for f in run["frames"] if f["agent_id"] == agent and f["sample_seq"] == index]
                        self.assertEqual(len(frames), 3)
                        ext = {"schema_version": "rdl-sensory-extension-v1", "run_id": run["run_id"],
                            "world_epoch": 1, "agent_id": agent, "delivery_observation_id": p["observation_id"],
                            "delivery_world_tick": p["tick"], "delivery_time_us": req["now_us"],
                            "frames": [{k: v for k, v in f.items() if k not in ("run_id", "world_epoch")} for f in frames]}
                        self.assertEqual(self.store.admit(p, ext)["new_frames"], 3)
                        stored = {f["frame_id"]: f for f in self.store.snapshot()["frames"]}
                        for f in frames: self.assertEqual(stored[f["frame_id"]], f)
                        self.canonical.capture(p)
                        decision = self.loop.decide(req)
                        self.assertEqual(decision["action"], trial["expected_action"])
                        self.assertEqual(decision["prediction"]["status"], trial["expected_prediction"])
                        self.assertEqual(self.loop.decide(req), decision)
                        # Independent replay review changes model IDs; factual outcomes are unchanged.
                        receipt = self.loop.record(dict(trial["result"], decision_id=decision["decision_id"]))
                        if trial["result"]["attempted"]:
                            self.assertEqual(receipt["experience"]["food_acquired"], not trial["world"]["hidden_blocked"])
                            self.assertEqual(receipt["F_prime"]["model_ref"], decision["model_ref"])
                            if index > 8 and a["activate"]:
                                self.assertEqual(receipt["comparison"]["E"]["deltas"]["food_acquired"], -1.0 if index >= 11 else 0.0)
                        else:
                            self.assertIsNone(receipt["experience"])
                            self.assertEqual(trial["world"]["actions"], 0)
                        self.assertEqual(trial["world"]["authority_consumptions"], 1)
                        sources[agent].append(req["operation_id"])
                        after = packet(f"{agent}-after-{index}", agent_id=agent, tick=trial["result"]["completed_us"] // 250000)
                        after["observation"]["visible_objects"] = [] if trial["result"]["food_acquired"] else p["observation"]["visible_objects"]
                        self.canonical.capture(after)
                        if index == 8:
                            record = [r for r in self.canonical.snapshot()["assessment"]["records"]
                                      if r["E"]["agent_id"] == agent and r["E"]["deltas"]["visible_objects_count"] != 0][-1]
                            self.canonical.review_assessment({"assessment_id": record["assessment_id"], "expected_revision": 0,
                                "reviewer": "replay", "basis": "independent finite review", "evidence": run["run_id"],
                                "dimensions": {k: {"status": "unresolved", "residual": 1.0} if v else {"status": "zero"}
                                               for k, v in record["E"]["deltas"].items()}})
                            other = "npc_b" if agent == "npc_a" else "npc_a"
                            before = copy.deepcopy(self.loop.snapshot()["by_agent"][other])
                            self.loop.learn({"learning_id": "learn", "agent_id": agent,
                                "formation_operations": sources[agent][:6], "validation_operations": sources[agent][6:8],
                                "assessment_id": record["assessment_id"], "activate": a["activate"]})
                            self.assertEqual(self.loop.snapshot()["by_agent"][other], before)
                self.assertEqual(self.store.snapshot()["count"], 72)
                self.assertEqual(self.canonical.snapshot()["model_cutover"]["count"],
                                 sum(a["activate"] for a in run["by_agent"].values()))


if __name__ == "__main__":
    unittest.main()
