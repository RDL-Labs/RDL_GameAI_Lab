import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

import test_multi_sensory_food_learning as fixtures
from runtime.sensory_food_learning import SharedFoodLearning, MultiAgentSensoryFoodLearning, SHARED_CONTEXT, CONTEXT
from runtime.bridge import run as run_bridge
from runtime.sensory_observation import SensoryObservationStore
from runtime.theta_effective import FiniteThetaEffectiveEvaluator
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


class SharedFoodLearningTests(unittest.TestCase):
    observe = fixtures.MultiSensoryLearningTests.observe
    result = fixtures.MultiSensoryLearningTests.result
    materials = fixtures.MultiSensoryLearningTests.materials
    state = fixtures.MultiSensoryLearningTests.state

    def setUp(self):
        fixtures.MultiSensoryLearningTests.setUp(self)
        self.loop = SharedFoodLearning(self.store, self.canonical)

    def test_apparatus_is_fixed_at_startup_and_not_request_input(self):
        req, decision = self.observe("npc_a", 1)
        self.assertEqual(decision["prediction"]["boundary"]["context"], SHARED_CONTEXT)
        before = self.state()
        for field in ("context", "winner", "first_agent", "other_model"):
            with self.assertRaises(ValueError): self.loop.decide(dict(req, **{field: CONTEXT}))
        self.assertEqual(self.state(), before)

    def test_old_apparatus_relation_is_not_used_in_shared_world(self):
        self.loop = MultiAgentSensoryFoodLearning(self.store, self.canonical)
        self.loop.learn(self.materials("npc_a"))
        self.loop = SharedFoodLearning(self.store, self.canonical)
        _, decision = self.observe("npc_a", 9)
        self.assertEqual(decision["prediction"]["status"], "unknown")
        self.assertEqual(decision["action"], "attempt_food")

    def test_shared_relation_is_not_used_in_old_apparatus(self):
        self.loop.learn(self.materials("npc_a"))
        self.loop = MultiAgentSensoryFoodLearning(self.store, self.canonical)
        self.assertEqual(self.observe("npc_a", 9)[1]["prediction"]["status"], "unknown")

    def test_same_shared_episode_is_not_a_shared_experience_or_receipt(self):
        fixtures.MultiSensoryLearningTests.test_same_local_ids_have_distinct_decisions_experiences_and_result_sections(self)
        fixtures.MultiSensoryLearningTests.test_other_agents_receipt_cannot_fill_same_named_operation(self)

    def test_opposite_histories_form_opposite_models_without_other_state_changes(self):
        fixtures.MultiSensoryLearningTests.test_independent_opposite_learning_and_cutover(self)

    def test_unattempted_operation_cannot_be_a_vote(self):
        request = self.materials("npc_a")
        self.loop.learn(request)
        self.observe("npc_a", 9)
        result = self.result("npc_a", 9, None)
        self.assertIsNone(result["experience"])
        self.assertEqual(result["comparison"]["status"], "not_attempted")

    def test_partial_and_stale_frames_defer_without_failure(self):
        req, _ = self.observe("npc_a", 1)
        for change in ("partial", "stale"):
            loop = SharedFoodLearning(self.store, self.canonical)
            if change == "partial":
                with patch.object(self.store, "snapshot", wraps=self.store.snapshot) as snapshot:
                    value = self.store.snapshot(); value["frames"][0]["coverage"] = "PARTIAL"
                    snapshot.return_value = value; snapshot.side_effect = None
                    d = loop.decide(req)
            else: d = loop.decide(dict(req, now_us=req["now_us"] + 500001))
            self.assertEqual(d["action"], "defer")
            receipt = loop.record({"agent_id": "npc_a", "decision_id": d["decision_id"], "operation_id": req["operation_id"],
                "event_id": change, "completed_us": req["now_us"] + 600000, "attempted": False, "food_acquired": None})
            self.assertIsNone(receipt["experience"])

    def test_foreign_inputs_are_rejected_without_state_changes(self):
        fixtures.MultiSensoryLearningTests.test_unknown_agent_and_foreign_frame_refused_without_mutation(self)

    def test_capacity_and_replay_are_per_agent(self):
        fixtures.MultiSensoryLearningTests.test_capacity_is_per_agent_and_full_agent_replay_still_works(self)

    def test_foreign_assessment_cannot_reconstruct(self):
        fixtures.MultiSensoryLearningTests.test_foreign_assessment_cannot_reconstruct_other_agent(self)

    def test_pending_result_keeps_pre_cutover_model(self):
        request = self.materials("npc_a")
        _, decision = self.observe("npc_a", 9, "dark_gray")
        self.loop.learn(request)
        receipt = self.result("npc_a", 9, False)
        self.assertEqual(receipt["F_prime"]["model_ref"], decision["model_ref"])
        self.assertEqual(receipt["comparison"]["status"], "not_comparable")

    def test_unfinished_or_unattempted_outcome_cannot_create_experience(self):
        _, decision = self.observe("npc_a", 1)
        before = self.state()
        for completed, attempted, acquired in ((1100000, False, False), (1100000, True, None), (6000001, True, True)):
            with self.assertRaises(ValueError):
                self.loop.record({"agent_id": "npc_a", "decision_id": decision["decision_id"], "operation_id": "op-1",
                    "event_id": "failed-input", "completed_us": completed, "attempted": attempted, "food_acquired": acquired})
        self.assertEqual(self.state(), before)

    def test_event_conflict_and_second_reconstruction_do_not_mutate_state(self):
        request = self.materials("npc_a")
        old = self.loop.snapshot()["by_agent"]["npc_a"]["results"]["op-1"]["result"]
        before = self.state()
        with self.assertRaises(ValueError): self.loop.record(dict(old, food_acquired=not old["food_acquired"]))
        self.assertEqual(self.state(), before)
        learned = self.loop.learn(request)
        before = self.state()
        self.assertEqual(self.loop.learn(request), learned)
        with self.assertRaises(ValueError): self.loop.learn(dict(request, learning_id="second"))
        self.assertEqual(self.state(), before)

    def test_cross_context_materials_refused_before_t1(self):
        request = self.materials("npc_a")
        # Corrupt a stored source to test the material-boundary guard, not a public mutation API.
        self.loop._agents["npc_a"]._results["op-1"]["experience"]["section"]["context"] = CONTEXT
        before = self.state()
        with self.assertRaisesRegex(ValueError, "conditions differ"): self.loop.learn(request)
        self.assertEqual(self.state(), before)

    def test_cli_requires_explicit_isolated_mode(self):
        with patch("runtime.bridge.ThreadingHTTPServer") as server:
            for settings in (
                {"luanti_learning_shared_food": True},
                {"luanti_learning_shared_food": True, "luanti_learning_loop": True, "luanti_learning_multi_agent": True},
                {"luanti_learning_shared_food": True, "luanti_learning_loop": True},
                {"luanti_learning_shared_food": True, "luanti_learning_loop": True, "sensory_observation": True, "host": "0.0.0.0"},
            ):
                with self.assertRaises(ValueError): run_bridge(**settings)
            server.assert_not_called()

    def test_real_luanti_shared_food_replay(self):
        path = Path(__file__).parent / "fixtures/luanti_l10c_replay.json"
        replay = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(len(replay["runs"]), 5)
        for saved in replay["runs"]:
            world = saved["world"]
            with self.subTest(scenario=world["scenario"]):
                self.setUp()
                self.store = SensoryObservationStore(run_id=world["run_id"], assignments={a: (p, 1) for a, p in self.profiles.items()})
                self.loop = SharedFoodLearning(self.store, self.canonical)
                sources = {a: [] for a in self.profiles}
                for episode in world["episodes"]:
                    decisions = {}
                    for agent in self.profiles:
                        p = episode["packets"]["before"][agent]
                        ext = p["observation"]["sensory_extension"]
                        self.assertEqual(self.store.admit(p, ext)["new_frames"], 3)
                        self.assertEqual(self.store.admit(p, ext)["new_frames"], 0)
                        self.canonical.capture(p)
                        rec = episode["by_agent"][agent]
                        req = rec["request"]
                        decision = self.loop.decide(req)
                        original = json.loads(rec["decision_wire"])
                        self.assertEqual(decision["action"], original["action"])
                        self.assertEqual(decision["prediction"]["status"], original["prediction"]["status"])
                        self.assertEqual(decision["prediction"]["values"], original["prediction"]["values"])
                        self.assertEqual(self.loop.decide(req), decision)
                        decisions[agent] = decision
                        sources[agent].append(req["operation_id"])
                    for agent in self.profiles:
                        rec = episode["by_agent"][agent]
                        result = dict(rec["result"], decision_id=decisions[agent]["decision_id"])
                        receipt = self.loop.record(result)
                        self.assertEqual(self.loop.record(result), receipt)
                        if result["attempted"]:
                            self.assertEqual(receipt["experience"]["episode_id"], episode["episode_id"])
                            if decisions[agent]["prediction"]["status"] == "known":
                                self.assertEqual(receipt["comparison"]["E"]["deltas"]["food_acquired"], float(result["food_acquired"]) - 1)
                        else: self.assertIsNone(receipt["experience"])
                        self.canonical.capture(episode["packets"]["after"][agent])
                    if episode["index"] == 8:
                        for agent in self.profiles:
                            record = [r for r in self.canonical.snapshot()["assessment"]["records"]
                                      if r["E"]["agent_id"] == agent and r["E"]["deltas"]["visible_objects_count"] != 0][-1]
                            self.canonical.review_assessment({"assessment_id": record["assessment_id"], "expected_revision": 0,
                                "reviewer": "l10c-replay", "basis": "independent finite count review", "evidence": world["run_id"],
                                "dimensions": {k: {"status": "unresolved", "residual": 1} if v else {"status": "zero"}
                                               for k, v in record["E"]["deltas"].items()}})
                            other = "npc_b" if agent == "npc_a" else "npc_a"
                            before = copy.deepcopy(self.loop.snapshot()["by_agent"][other])
                            self.loop.learn({"learning_id": "learn", "agent_id": agent, "formation_operations": sources[agent][:6],
                                "validation_operations": sources[agent][6:8], "assessment_id": record["assessment_id"],
                                "activate": world["by_agent"][agent]["activate"]})
                            self.assertEqual(self.loop.snapshot()["by_agent"][other], before)
                actual = {f["frame_id"]: f for f in self.store.snapshot()["frames"]}
                self.assertEqual(actual, {f["frame_id"]: f for f in saved["frames"]})
                self.assertEqual(self.canonical.snapshot()["model_cutover"]["count"],
                                 sum(a["activate"] for a in world["by_agent"].values()))


if __name__ == "__main__":
    unittest.main()
