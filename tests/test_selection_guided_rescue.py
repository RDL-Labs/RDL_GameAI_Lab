import copy
import json
import os
from pathlib import Path
import subprocess
import threading
import unittest
from http.server import ThreadingHTTPServer
from unittest.mock import patch

from runtime import bridge
from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.rescue_policy import RescueTrajectoryPolicy
from runtime.rescue_condition_rank import rank_rescue_conditions
from runtime.selection_guided_rescue import SelectionGuidedRescueEpisode, SelectionGuidedRescueError, RULE
from runtime.rescue_selection import RescueSelectionError
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_rescue_selection import profile, fixture, synthetic
from test_sensory_observation import packet

ROOT = Path(__file__).resolve().parents[1]
AVAILABLE = ["solo", "joint", "defer"]


def source():
    return json.loads((ROOT / "tests/fixtures/soc2_godot_replay.json").read_text(encoding="utf-8"))


def binding(name="next"):
    return {"schema": "soc3-rescue-binding-v1", "rule": RULE, "experiment_id": "soc3-comparison",
            "episode_id": name, "world_run_id": "soc3-" + name, "agent_id": "npc_a", "target_id": "npc_b",
            "helper_id": "npc_c", "context_ref": "soc2-bounded-joint-rescue-v1"}


def make(tolerant=False, name="next", materials=None):
    saved = source(); protocol = saved["protocol"]
    req = {"experiment_id": protocol["experiment_id"], "purpose": protocol["purpose"],
           "episode_ids": [e["episode_id"] for e in protocol["episodes"]]}
    args = {"source_protocol": protocol, "source_materials": saved["materials"] if materials is None else materials,
            "source_request": req, "profile": profile(tolerant), "binding": binding(name)}
    return SelectionGuidedRescueEpisode(**args), args


def request(b=None, events=None, refs=None, identity="first", available=None, context=None):
    b = binding() if b is None else b
    return {"choice_id": identity, "binding": b, "source_observation_id": "observation-" + identity,
            "context_ref": b["context_ref"] if context is None else context,
            "events": [] if events is None else events, "execution_refs": [] if refs is None else refs,
            "available_conditions": AVAILABLE if available is None else available}


def trial(b, choice, success=False, offset=0):
    events = [r["event"] for r in synthetic("alpha", not success)["snapshot"]["records"]]
    refs = []
    for i, event in enumerate(events):
        event.update(run_id=b["world_run_id"], event_id=b["world_run_id"] + ":event:" + str(offset + i),
                     source_observation_id="action-" + str(offset + i), subsequent_observation_id="after-" + str(offset + i), tick=offset + i,
                     participants=["npc_a", "npc_c"] if choice["selected"] == "joint" else ["npc_a"], attempt_condition=choice["selected"])
        refs.append({"choice_id": choice["choice_id"], "event_id": event["event_id"],
                     "source_observation_id": event["source_observation_id"], "action": event["action"]})
    return events, refs


def finish(s, events, refs, status):
    return s.finish_episode(events=events, execution_refs=refs, status=status, reason="test-" + status)


class SelectionGuidedRescueTests(unittest.TestCase):
    def test_same_inspection_changes_candidate_eligibility_and_first_choice(self):
        outcomes = []
        for tolerant in (False, True):
            s, _ = make(tolerant); outcomes.append(s.choose(**request()))
        self.assertEqual([o["selected"] for o in outcomes], ["solo", "joint"])
        self.assertEqual(outcomes[0]["source_evaluation"]["episode_results"], outcomes[1]["source_evaluation"]["episode_results"])
        for out in outcomes:
            joint = out["candidates"][1]
            self.assertEqual((joint["success_episode_count"], joint["failure_episode_count"]), (2, 1))
            self.assertEqual(out["candidates"][0]["success_episode_count"], 0)
        self.assertEqual(outcomes[0]["candidates"][1]["exclusion_reasons"], ["selection_rejected"])
        self.assertEqual(outcomes[1]["candidates"][1]["exclusion_reasons"], [])

    def test_strict_failure_defers_without_reviving_joint(self):
        s, _ = make(); first = s.choose(**request()); original = s.snapshot()["source_evaluation"]
        es, refs = trial(binding(), first)
        last = s.choose(**request(events=es, refs=refs, identity="failed"))
        self.assertEqual(last["selected"], "defer")
        self.assertIn("failed_this_episode", last["candidates"][0]["exclusion_reasons"])
        self.assertIn("selection_rejected", last["candidates"][1]["exclusion_reasons"])
        snap = finish(s, es, refs, "deferred")
        self.assertEqual(snap["terminal"]["rescue_goal_status"], "pending")
        self.assertEqual(snap["terminal"]["pending_target_id"], "npc_b")
        self.assertEqual(snap["source_evaluation"], original)
        self.assertEqual([e["attempt_condition"] for e in snap["current_events"]], ["solo"])

    def test_tolerant_delivers_with_one_choice_no_historical_vote_added(self):
        s, _ = make(True); first = s.choose(**request()); es, refs = trial(binding(), first, True)
        snap = finish(s, es, refs, "completed")
        self.assertEqual(snap["terminal"]["rescue_goal_status"], "completed")
        self.assertIsNone(snap["terminal"]["pending_target_id"])
        self.assertEqual(len(snap["choices"]), 1)
        self.assertEqual(snap["source_evaluation"]["validation_count"], 3)
        self.assertEqual(snap["source_evaluation"]["failure_count"], 1)

    def test_current_unavailability_and_context_override_retention(self):
        s, _ = make(True)
        out = s.choose(**request(available=["solo", "defer"]))
        self.assertEqual(out["selected"], "solo")
        self.assertEqual(out["candidates"][1]["selection_disposition"], "RETAIN")
        self.assertIn("currently_unavailable", out["candidates"][1]["exclusion_reasons"])
        s, _ = make(True); out = s.choose(**request(context="unconfirmed"))
        self.assertEqual(out["selected"], "defer")
        self.assertTrue(all("current_context_unavailable" in r["exclusion_reasons"] for r in out["candidates"][:2]))

    def test_past_defer_preserves_partial_evidence_and_null_counts(self):
        materials = source()["materials"]; materials["episodes"][0]["envelope"]["coverage"] = "partial"
        for tolerant in (False, True):
            s, _ = make(tolerant, materials=materials)
            out = s.choose(**request()); joint = out["candidates"][1]
            self.assertEqual(out["selected"], "solo")
            self.assertEqual(joint["selection_disposition"], "DEFER")
            self.assertIn("selection_unresolved", joint["exclusion_reasons"])
            self.assertIsNone(joint["success_episode_count"]); self.assertIsNone(joint["failure_episode_count"])
            self.assertEqual(len(joint["failure_evidence"]), 1)

    def test_all_success_or_all_failure_agree_across_profiles(self):
        for failures, expected in ((0, "joint"), (3, "solo")):
            for tolerant in (False, True):
                s, _ = make(tolerant, materials=fixture(failures))
                self.assertEqual(s.choose(**request())["selected"], expected)

    def test_rule_ignores_profile_and_episode_labels(self):
        for name in ("99", "last", "Episode4", "strict"):
            s, args = make(True, name=name)
            args["profile"]["profile_id"] = "strict-even-though-tolerant"
            s = SelectionGuidedRescueEpisode(**args)
            self.assertEqual(s.choose(**request(b=args["binding"]))["selected"], "joint")
        rows = [{"condition": c, "available": True, "failed_this_episode": False,
                 "success_episode_count": 0, "failure_episode_count": 0} for c in ("joint", "solo")]
        self.assertEqual(rank_rescue_conditions(rows)[0]["condition"], "solo")
        rows[1]["failure_episode_count"] = 1
        self.assertEqual(rank_rescue_conditions(rows)[0]["condition"], "joint")

    def test_two_conditions_fail_then_defer_at_three_choice_limit(self):
        s, _ = make(True); first = s.choose(**request()); es, refs = trial(binding(), first)
        second = s.choose(**request(events=es, refs=refs, identity="second"))
        self.assertEqual(second["selected"], "solo")
        es2, refs2 = trial(binding(), second, offset=1); es += es2; refs += refs2
        third = s.choose(**request(events=es, refs=refs, identity="third"))
        self.assertEqual(third["selected"], "defer")
        before = s.snapshot()
        with self.assertRaisesRegex(SelectionGuidedRescueError, "choice_budget"):
            s.choose(**request(events=es, refs=refs, identity="fourth"))
        self.assertEqual(s.snapshot(), before)
        finish(s, es, refs, "deferred")

    def test_three_current_events_have_separate_budget(self):
        s, _ = make(True); first = s.choose(**request(available=["solo", "defer"]))
        es, refs = trial(binding(), first)
        second = s.choose(**request(events=es, refs=refs, identity="second")); self.assertEqual(second["selected"], "joint")
        es2, refs2 = trial(binding(), second, True, offset=1); es += es2; refs += refs2
        before = s.snapshot()
        with self.assertRaisesRegex(SelectionGuidedRescueError, "event_budget"):
            finish(s, es + [es[-1]], refs + [refs[-1]], "completed")
        self.assertEqual(s.snapshot(), before)
        snap = finish(s, es, refs, "completed")
        self.assertEqual(len(snap["current_events"]), 3)
        self.assertEqual(snap["source_evaluation"]["validation_count"], 3)

    def test_choice_requires_new_failure_and_stops_after_attach(self):
        s, _ = make(True); first = s.choose(**request()); before = s.snapshot()
        with self.assertRaisesRegex(SelectionGuidedRescueError, "new_failure"):
            s.choose(**request(identity="new-but-no-event"))
        self.assertEqual(s.snapshot(), before)
        es, refs = trial(binding(), first, True)
        with self.assertRaisesRegex(SelectionGuidedRescueError, "choice_after_attachment"):
            s.choose(**request(events=es[:1], refs=refs[:1], identity="after-attach"))
        self.assertEqual(s.snapshot(), before)
        with self.assertRaises(SelectionGuidedRescueError): finish(s, es[:1], refs[:1], "completed")
        snap = finish(s, es[:1], refs[:1], "incomplete")
        self.assertEqual(snap["terminal"]["rescue_goal_status"], "pending")

    def test_replay_conflict_and_closed_episode_are_separate(self):
        s, _ = make(); req = request(); first = s.choose(**req)
        self.assertEqual(s.choose(**req), first)
        es, refs = trial(binding(), first)
        last_req = request(events=es, refs=refs, identity="last")
        s.choose(**last_req); finish(s, es, refs, "deferred"); before = s.snapshot()
        self.assertEqual(s.choose(**req), first)
        self.assertEqual(s.snapshot(), before)
        with self.assertRaisesRegex(SelectionGuidedRescueError, "choice_conflict"):
            s.choose(**{**req, "available_conditions": ["defer"]})
        with self.assertRaisesRegex(SelectionGuidedRescueError, "episode_closed"):
            s.choose(**request(identity="future", events=es, refs=refs))
        with self.assertRaisesRegex(SelectionGuidedRescueError, "episode_closed"): finish(s, es, refs, "deferred")
        self.assertEqual(s.snapshot(), before)

    def test_illegal_events_and_execution_refs_are_atomic(self):
        mutations = [lambda es, rs: es[0].update(run_id="foreign"), lambda es, rs: es[0].update(target_id="foreign"),
                     lambda es, rs: es[0].update(hidden_load=2), lambda es, rs: es[0].update(event_id="soc2-alpha:event:0"),
                     lambda es, rs: es[0].update(participants=["npc_a", "npc_d"], attempt_condition="joint"),
                     lambda es, rs: rs[0].update(choice_id="unselected"), lambda es, rs: rs[0].update(source_observation_id="unrelated"),
                     lambda es, rs: rs.clear(), lambda es, rs: rs[0].update(extra="hidden")]
        for mutation in mutations:
            s, _ = make(); first = s.choose(**request()); es, refs = trial(binding(), first); mutation(es, refs)
            before = s.snapshot()
            with self.assertRaises(SelectionGuidedRescueError): s.choose(**request(events=es, refs=refs, identity="bad"))
            self.assertEqual(s.snapshot(), before)

    def test_prefix_alias_source_time_and_unselected_condition_rejected(self):
        for change in ("drop", "source", "tick", "condition", "execution-prefix"):
            s, _ = make(True); first = s.choose(**request()); es, refs = trial(binding(), first)
            second = s.choose(**request(events=es, refs=refs, identity="second"))
            more, more_refs = trial(binding(), second, offset=1)
            if change == "drop": es, refs = [], []
            elif change == "source": more[0]["source_observation_id"] = es[0]["source_observation_id"]; more_refs[0]["source_observation_id"] = es[0]["source_observation_id"]
            elif change == "tick": more[0]["tick"] = -1
            elif change == "condition": more[0].update(participants=["npc_a", "npc_c"], attempt_condition="joint")
            else: refs[0]["choice_id"] = "other"
            before = s.snapshot()
            with self.assertRaises(SelectionGuidedRescueError): s.choose(**request(events=es + more, refs=refs + more_refs, identity="bad"))
            self.assertEqual(s.snapshot(), before)

    def test_multiple_exclusions_preserve_distinct_causes(self):
        s, _ = make()
        out = s.choose(**request(available=["defer"], context="unconfirmed"))
        self.assertEqual(out["selected"], "defer")
        self.assertEqual(set(out["candidates"][1]["exclusion_reasons"]),
                         {"selection_rejected", "currently_unavailable", "current_context_unavailable"})

    def test_nonnegative_time_reversal_and_renamed_action_rejected(self):
        for alias in (False, True):
            s, _ = make(True); first = s.choose(**request()); es, refs = trial(binding(), first, offset=5)
            second = s.choose(**request(events=es, refs=refs, identity="second"))
            more, more_refs = trial(binding(), second, offset=6)
            if alias:
                more[0]["source_observation_id"] = es[0]["source_observation_id"]
                more_refs[0]["source_observation_id"] = more[0]["source_observation_id"]
            else:
                more[0]["tick"] = 4
            before = s.snapshot()
            with self.assertRaisesRegex(SelectionGuidedRescueError, "action_source_reused" if alias else "time_reversal"):
                s.choose(**request(events=es + more, refs=refs + more_refs, identity="bad"))
            self.assertEqual(s.snapshot(), before)

    def test_invalid_binding_availability_and_source_rejected(self):
        for edit in (lambda b: b.update(world_run_id="soc2-alpha"), lambda b: b.update(episode_id="alpha"),
                     lambda b: b.update(agent_id="npc_c"), lambda b: b.update(context_ref="other"),
                     lambda b: b.update(extra=True), lambda b: b.update(episode_id=" ")):
            _, args = make(); edit(args["binding"])
            with self.assertRaises(SelectionGuidedRescueError): SelectionGuidedRescueEpisode(**args)
        s, _ = make(); before = s.snapshot()
        for req in (request(b=binding("foreign")), request(available=[]), request(available=["solo", "solo", "defer"]), request(identity=" ")):
            with self.assertRaises(SelectionGuidedRescueError): s.choose(**req)
            self.assertEqual(s.snapshot(), before)
        _, args = make(); args["source_materials"]["episodes"].pop()
        with self.assertRaises(RescueSelectionError): SelectionGuidedRescueEpisode(**args)

    def test_freezing_and_output_alias_independence(self):
        s, args = make(True); original = s.snapshot()
        args["source_materials"]["episodes"].clear(); args["profile"]["tolerance_numerator"] = 0; args["binding"].clear()
        self.assertEqual(s.snapshot(), original)
        req = request(); out = s.choose(**req); before = s.snapshot()
        out["source_evaluation"].clear(); out["candidates"].clear(); req["binding"].clear()
        self.assertEqual(s.snapshot(), before)

    def test_completion_and_defer_cannot_be_fabricated(self):
        s, _ = make(True); first = s.choose(**request()); es, refs = trial(binding(), first, True)
        before = s.snapshot()
        for ev, ex, status in (([], [], "completed"), ([], [], "deferred"), (es[1:], refs[1:], "completed"),
                               (es[:1], refs[:1], "deferred"), (es, refs, "incomplete")):
            with self.assertRaises(SelectionGuidedRescueError): finish(s, ev, ex, status)
            self.assertEqual(s.snapshot(), before)

    def test_explicit_calls_do_not_change_default_action_history_or_canonical(self):
        def run(enabled):
            history, canonical = InteractionHistory(), GameAIFrozenComparisonSidecar(); actions = []
            s, _ = make(True)
            with patch.object(canonical.t1_reconstruction, "reconstruct", side_effect=AssertionError("no reconstruction")):
                if enabled: s.choose(**request())
                for i in range(3):
                    obs = packet("soc3-default-" + str(i), tick=i + 1)
                    action = decide_action(obs); actions.append(action); history.register_decision(obs, action); canonical.capture(obs)
            return actions, history.snapshot(), canonical.snapshot()
        self.assertEqual(run(True), run(False))

    def test_saved_world_replay(self):
        data = json.loads((ROOT / "tests/fixtures/soc3_godot_replay.json").read_text(encoding="utf-8"))
        for case in data["cases"]:
            s = SelectionGuidedRescueEpisode(**case["inputs"])
            for call in case["world"]["choice_calls"]:
                self.assertEqual(s.choose(**call["request"]), call["result"])
            world = case["world"]
            self.assertEqual(finish(s, world["experiences"], world["execution_refs"], world["metrics"]["status"]), case["coordinator"])

    @unittest.skipUnless(os.environ.get("GODOT_BIN"), "set GODOT_BIN for SOC-3 real World/HTTP")
    def test_real_selection_changes_next_episode_with_unavailable_control(self):
        output_dir = ROOT / "integrations/luanti/output"; output_dir.mkdir(parents=True, exist_ok=True)
        cases = []
        for name, tolerant, absent in (("strict", False, False), ("tolerant", True, False), ("helper-absent", True, True)):
            coordinator, inputs = make(tolerant, name=name); frozen = coordinator.snapshot()["source_evaluation"]
            class Handler(bridge.BridgeHandler):
                def do_POST(self):
                    if self.path != "/soc3/choose": return super().do_POST()
                    try:
                        payload = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                        self._send_json(200, coordinator.choose(**payload))
                    except (ValueError, TypeError) as exc: self._send_json(400, {"error": str(exc)})
            class RecordingRescue(RescueTrajectoryPolicy):
                def __init__(self): super().__init__(); self.packets = []
                def decide(self, packet): self.packets.append(copy.deepcopy(packet)); return super().decide(packet)
            rescue, canonical = RecordingRescue(), GameAIFrozenComparisonSidecar()
            with patch.object(bridge, "EXPERIENCE", InteractionHistory()), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
                server = ThreadingHTTPServer(("127.0.0.1", 8765), Handler); server.history_policy = None; server.rescue_policy = rescue
                thread = threading.Thread(target=server.serve_forever); thread.start()
                path = output_dir / ("soc3-" + name + ".json")
                try:
                    process = subprocess.run([os.environ["GODOT_BIN"], "--headless", "--path", str(ROOT / "godot/rdl-game-ai-workbench"),
                        "--script", "res://tests/selection_guided_rescue_http_check.gd"], capture_output=True, text=True, timeout=60,
                        env={**os.environ, "SOC3_BINDING": json.dumps(inputs["binding"]), "SOC3_HELPER_ABSENT": "1" if absent else "0", "SOC3_EVIDENCE_PATH": str(path)},
                        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
                    output = process.stdout + process.stderr; (output_dir / ("soc3-" + name + ".log")).write_text(output, encoding="utf-8")
                    self.assertEqual(process.returncode, 0, output); self.assertIn("SOC-3 EPISODE PASS", output)
                    world = json.loads(path.read_text(encoding="utf-8")); expected = "completed" if tolerant and not absent else "deferred"
                    self.assertEqual(world["metrics"]["status"], expected)
                    self.assertEqual(world["initial"]["carry_attempts"], 0); self.assertEqual(world["initial"]["experiences"], 0)
                    self.assertEqual(world["metrics"]["solo_attempts"], int(expected == "deferred"))
                    self.assertEqual(world["metrics"]["joint_attempts"], int(expected == "completed"))
                    self.assertEqual(world["guard_checks"], ["helper_lost", "actor_lost", "consumed"])
                    self.assertEqual(world["action_replay_checks"], 1)
                    self.assertEqual(world["choice_replay_checks"], 1 if expected == "completed" else 3)
                    if expected == "completed":
                        self.assertEqual(world["recovery_stages"], ["stabilizing", "mobilizing", "recovering", "recovered"])
                        self.assertEqual(rescue.snapshot()["trajectories"], {})
                    else:
                        self.assertEqual(world["world_checks"][0]["target_before"], world["world_checks"][0]["target_after"])
                        self.assertTrue(rescue.snapshot()["trajectories"])
                        self.assertEqual(world["metrics"]["rescue_goal_status"], "pending")
                        self.assertIsNone(world["metrics"]["actions_to_delivery"])
                    self.assertEqual(canonical.snapshot()["T1_materials"]["count"], 0)
                    snap = finish(coordinator, world["experiences"], world["execution_refs"], expected)
                    self.assertEqual(snap["source_evaluation"], frozen)
                    self.assertEqual([c["result"] for c in snap["choices"]], [c["result"] for c in world["choice_calls"]])
                    for e, ref in zip(world["experiences"], world["execution_refs"]):
                        self.assertIn({"choice_id": ref["choice_id"], "source_observation_id": e["source_observation_id"], "action": e["action"]}, world["action_choices"])
                    for surface in (snap, world["choice_calls"], world["experiences"], rescue.packets):
                        for forbidden in ("target_load", "carry_capabilities", "combined_capacity", "required_carriers", "requires_helper"):
                            self.assertNotIn(chr(34) + forbidden + chr(34), json.dumps(surface))
                    cases.append({"inputs": inputs, "world": world, "coordinator": snap, "rescue_runtime": rescue.snapshot()})
                finally:
                    server.shutdown(); thread.join(); server.server_close()
        self.assertEqual(cases[0]["world"]["initial"], cases[1]["world"]["initial"])
        self.assertNotEqual(cases[1]["world"]["initial"]["positions"], cases[2]["world"]["initial"]["positions"])
        self.assertTrue(all(c["inputs"]["source_materials"] == cases[0]["inputs"]["source_materials"] for c in cases))
        self.assertEqual([c["world"]["metrics"]["first_condition"] for c in cases], ["solo", "joint", "solo"])
        self.assertEqual(cases[2]["world"]["choice_calls"][0]["result"]["candidates"][1]["exclusion_reasons"], ["currently_unavailable"])
        (output_dir / "soc3-guided-world.json").write_text(json.dumps({"cases": cases}, ensure_ascii=False, indent=2), encoding="utf-8")
        print("SOC-3 WORLD PASS: strict solo/failure/defer; tolerant joint/delivery; unavailable helper solo/failure/defer")


if __name__ == "__main__": unittest.main()
