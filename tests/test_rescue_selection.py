import copy
import itertools
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
from runtime.repeated_rescue import RepeatedRescueSelector
from runtime.rescue_experience import RescueExperienceStore
from runtime.rescue_selection import RescueSelectionEvaluator, RescueSelectionError, PURPOSE, RULE, CONTEXT
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_sensory_observation import packet

ROOT = Path(__file__).resolve().parents[1]


def protocol():
    return {"schema": "soc2-rescue-protocol-v1", "experiment_id": "soc2-three-trials",
            "agent_id": "npc_a", "target_id": "npc_b", "helper_id": "npc_c",
            "purpose": PURPOSE, "rule": RULE, "context_ref": CONTEXT,
            "episodes": [{"episode_id": e, "world_run_id": "soc2-" + e} for e in ("alpha", "beta", "gamma")]}


def profile(tolerant=False):
    return {"schema": "soc2-selection-profile-v1", "agent_id": "npc_a",
            "profile_id": "tolerant" if tolerant else "strict", "revision": 1,
            "tolerance_numerator": 1 if tolerant else 0, "tolerance_denominator": 3 if tolerant else 1}


def request():
    return {"experiment_id": protocol()["experiment_id"], "purpose": PURPOSE,
            "episode_ids": [r["episode_id"] for r in protocol()["episodes"]]}


def material(episode, events, termination, coverage="complete"):
    run = "soc2-" + episode
    store = RescueExperienceStore(run, capacity=2)
    refs = [store.record(e)["record_id"] for e in events]
    return {"envelope": {"schema": "soc2-rescue-episode-v1", "episode_id": episode,
            "world_run_id": run, "context_ref": CONTEXT, "coverage": coverage,
            "termination": termination, "event_refs": refs}, "snapshot": store.snapshot()}


def synthetic(episode, failed=False):
    run = "soc2-" + episode
    def event(index, outcome):
        return {"schema": "soc0-rescue-experience-v1", "run_id": run,
                "event_id": run + ":event:" + str(index), "agent_id": "npc_a",
                "source_observation_id": run + ":before:" + str(index),
                "subsequent_observation_id": run + ":after:" + str(index), "tick": index,
                "action": "deliver" if outcome == "delivered" else "rescue", "target_id": "npc_b",
                "participants": ["npc_a", "npc_c"], "attempt_condition": "joint", "result": outcome,
                "world_consequence": {"target_moved": False, "carry_established": outcome == "carry_established"},
                "body_consequence": {"actor_incapacitated": False, "target_incapacitated": True,
                                     "target_recovery_stage": "stabilizing" if outcome == "delivered" else "none"},
                "authority": "bounded-rescue-experience-only; not-social-relation-NERV-T1-or-action"}
    events = [event(0, "carry_not_established")] if failed else [event(0, "carry_established"), event(1, "delivered")]
    return material(episode, events, "carry_failed" if failed else "delivered")


def fixture(failures=1):
    return {"episodes": [synthetic(e, i >= 3 - failures) for i, e in enumerate(("alpha", "beta", "gamma"))],
            "missing_episode_ids": []}


def evaluate(materials=None, tolerant=False):
    return RescueSelectionEvaluator(protocol(), profile(tolerant)).evaluate(materials if materials is not None else fixture(), request())


class RescueSelectionTests(unittest.TestCase):
    def test_identical_evidence_different_tolerance_preserves_counterexample(self):
        strict, tolerant = evaluate(), evaluate(tolerant=True)
        self.assertEqual((strict["disposition"], tolerant["disposition"]), ("REJECT", "RETAIN"))
        self.assertEqual(strict["episode_results"], tolerant["episode_results"])
        self.assertEqual(strict["baseline_disposition"], tolerant["baseline_disposition"])
        self.assertEqual(tolerant["baseline_disposition"], "REJECT")
        self.assertEqual((tolerant["failure_count"], tolerant["validation_count"]), (1, 3))
        self.assertEqual(tolerant["episode_results"][2]["status"], "failure")
        self.assertEqual(tolerant["reasons"], ["within_declared_tolerance"])
        self.assertNotEqual(strict["evaluation_id"], tolerant["evaluation_id"])

    def test_all_integer_boundaries(self):
        for failures in range(4):
            for tolerant in (False, True):
                out = evaluate(fixture(failures), tolerant)
                self.assertEqual(out["disposition"], "RETAIN" if failures <= int(tolerant) else "REJECT")
                self.assertEqual(out["failure_count"], failures)
                self.assertEqual(out["validation_count"], 3)
                if failures == 0: self.assertEqual(out["reasons"], ["no_observed_failure"])

    def test_incomplete_keeps_counterexample_but_no_partial_rate(self):
        for edit, reason in ((lambda ep: ep["envelope"].update(coverage="partial"), "acquisition_incomplete"),
                             (lambda ep: ep["envelope"].update(context_ref="another-context"), "context_mismatch")):
            m = fixture(); edit(m["episodes"][0])
            for tolerant in (False, True):
                out = evaluate(m, tolerant)
                self.assertEqual(out["disposition"], "DEFER")
                self.assertEqual(out["baseline_disposition"], "DEFER")
                self.assertIsNone(out["failure_count"]); self.assertIsNone(out["validation_count"])
                self.assertIn(reason, out["reasons"])
                self.assertEqual(out["episode_results"][2]["status"], "failure")

    def test_unattempted_interrupted_and_explicit_missing(self):
        for term in ("not_attempted", "interrupted"):
            m = fixture(); m["episodes"][0] = material("alpha", [], term)
            self.assertEqual(evaluate(m, True)["disposition"], "DEFER")
        m = fixture(); m["episodes"].pop(0); m["missing_episode_ids"] = ["alpha"]
        out = evaluate(m, True)
        self.assertIn("episode_unavailable", out["reasons"])
        self.assertIsNone(out["episode_results"][0]["source"])

    def test_attachment_only_is_unconfirmed_not_failure(self):
        m = fixture(); events = [m["episodes"][0]["snapshot"]["records"][0]["event"]]
        m["episodes"][0] = material("alpha", events, "interrupted")
        out = evaluate(m, True)
        self.assertEqual(out["disposition"], "DEFER")
        self.assertIn("delivery_unconfirmed", out["reasons"])
        self.assertEqual(out["episode_results"][0]["observed_outcome"], "unresolved")

    def test_unrealized_participants_and_body_conditions_defer(self):
        for edit, reason in ((lambda e: e.update(participants=["npc_a"], attempt_condition="solo"), "condition_not_realized"),
                             (lambda e: e["body_consequence"].update(actor_incapacitated=True), "actor_unavailable"),
                             (lambda e: e["body_consequence"].update(target_incapacitated=False), "target_not_incapacitated")):
            m = fixture(); e = m["episodes"][2]["snapshot"]["records"][0]["event"]
            edit(e); m["episodes"][2] = material("gamma", [e], "carry_failed")
            out = evaluate(m, True)
            self.assertEqual(out["disposition"], "DEFER"); self.assertIn(reason, out["reasons"])
            self.assertEqual(out["episode_results"][2]["observed_outcome"], "failure")
            self.assertEqual(out["episode_results"][2]["status"], "unresolved")

    def test_multiple_unresolved_reasons_and_known_failure_preserved(self):
        m = fixture(); ep = m["episodes"][0]
        ep["envelope"].update(coverage="partial", context_ref="different")
        m["episodes"][1] = material("beta", [], "not_attempted")
        out = evaluate(m, True)
        self.assertEqual(set(out["reasons"]), {"acquisition_incomplete", "context_mismatch", "not_attempted"})
        self.assertEqual(out["episode_results"][2]["status"], "failure")

    def test_replay_does_not_multiply_experience(self):
        m = fixture(); ev = RescueSelectionEvaluator(protocol(), profile(True))
        expected = ev.evaluate(m, request())
        for ep in m["episodes"]:
            store = RescueExperienceStore(ep["snapshot"]["run_id"], 2)
            for record in ep["snapshot"]["records"]: store.record(record["event"])
            before = store.snapshot()
            for _ in range(4):
                for record in ep["snapshot"]["records"]: store.record(record["event"])
            self.assertEqual(store.snapshot(), before)
        for _ in range(4): self.assertEqual(ev.evaluate(m, request()), expected)
        self.assertEqual(sum(len(r["event_refs"]) for r in expected["episode_results"]), 5)
        self.assertEqual(expected["validation_count"], 3)

    def test_fixed_profile_protocol_and_outputs_are_independent(self):
        p, prof, m, req = protocol(), profile(True), fixture(), request()
        ev = RescueSelectionEvaluator(p, prof); before = copy.deepcopy((m, req))
        expected = ev.evaluate(m, req)
        p["episodes"].clear(); prof["tolerance_numerator"] = 0
        out = ev.evaluate(m, req); self.assertEqual(out, expected)
        out["protocol"].clear(); out["episode_results"][0]["source"]["snapshot"]["records"].clear()
        self.assertEqual((m, req), before); self.assertEqual(ev.evaluate(m, req), expected)

    def test_invalid_profiles_and_protocols_rejected(self):
        for edit in (lambda p: p.update(revision=True), lambda p: p.update(revision=2),
                     lambda p: p.update(tolerance_numerator=True), lambda p: p.update(tolerance_numerator=0.0),
                     lambda p: p.update(tolerance_numerator=2, tolerance_denominator=6),
                     lambda p: p.update(tolerance_denominator=0), lambda p: p.update(tolerance_numerator=-1),
                     lambda p: p.update(agent_id="other"), lambda p: p.update(profile_id=" "),
                     lambda p: p.update(profile_id="x" * 129), lambda p: p.update(hidden=2)):
            prof = profile(True); edit(prof)
            with self.assertRaises(RescueSelectionError): RescueSelectionEvaluator(protocol(), prof)
        for edit in (lambda p: p.update(purpose="other"), lambda p: p.update(rule="other"),
                     lambda p: p.update(helper_id="npc_a"), lambda p: p["episodes"].pop(),
                     lambda p: p["episodes"].append(p["episodes"][0]),
                     lambda p: p["episodes"][1].update(world_run_id="soc2-alpha"),
                     lambda p: p["episodes"][1].update(episode_id="alpha")):
            p = protocol(); edit(p)
            with self.assertRaises(RescueSelectionError): RescueSelectionEvaluator(p, profile())

    def test_whole_roster_and_missing_partition_required(self):
        for edit in (lambda m: m["episodes"].pop(), lambda m: m["missing_episode_ids"].append("alpha"),
                     lambda m: m["episodes"][0]["envelope"].update(episode_id="unknown"),
                     lambda m: m["episodes"][0]["envelope"].update(world_run_id="foreign"),
                     lambda m: m["episodes"].append(m["episodes"][0])):
            m = fixture(); edit(m)
            with self.assertRaises(RescueSelectionError): evaluate(m)
        for edit in (lambda r: r["episode_ids"].pop(), lambda r: r["episode_ids"].append("alpha"),
                     lambda r: r.update(experiment_id="other"), lambda r: r.update(purpose="other")):
            req = request(); edit(req)
            with self.assertRaises(RescueSelectionError): RescueSelectionEvaluator(protocol(), profile()).evaluate(fixture(), req)

    def test_record_reference_tampering_and_hidden_fields_rejected(self):
        for edit in (lambda ep: ep["envelope"]["event_refs"].clear(),
                     lambda ep: ep["snapshot"]["records"].clear(),
                     lambda ep: ep["envelope"]["event_refs"].append("missing"),
                     lambda ep: ep["snapshot"]["records"].append(ep["snapshot"]["records"][0]),
                     lambda ep: ep["snapshot"]["records"][0].update(record_id="fake"),
                     lambda ep: ep["snapshot"]["records"][0]["event"].update(hidden_capacity=2),
                     lambda ep: ep["snapshot"].update(target_load=3),
                     lambda ep: ep["envelope"].update(target_load=3)):
            m = fixture(); edit(m["episodes"][0])
            with self.assertRaises(RescueSelectionError): evaluate(m)

    def test_cross_scope_duplicate_event_and_time_reversal_rejected(self):
        for edit in (lambda es: es[0].update(agent_id="npc_c"), lambda es: es[0].update(target_id="other"),
                     lambda es: es[0].update(run_id="foreign"),
                     lambda es: es[0].update(participants=["npc_a", "npc_d"]),
                     lambda es: es[0].update(event_id="soc2-gamma:event:0"),
                     lambda es: es[0].update(tick=5),
                     lambda es: es[1].update(source_observation_id=es[0]["source_observation_id"])):
            m = fixture(); es = [r["event"] for r in m["episodes"][0]["snapshot"]["records"]]
            edit(es)
            # Re-accept legal SOC-0 edits, leaving cross-run corruption for the evaluator.
            if es[0]["run_id"] == "foreign":
                m["episodes"][0]["snapshot"]["records"][0]["event"] = es[0]
            else:
                m["episodes"][0] = material("alpha", es, "delivered")
            with self.assertRaises(RescueSelectionError): evaluate(m)

    def test_duplicates_within_budget_and_invalid_record_types_rejected(self):
        edits = (
            lambda ep: ep["snapshot"]["records"].append(copy.deepcopy(ep["snapshot"]["records"][0])),
            lambda ep: ep["envelope"]["event_refs"].append(ep["envelope"]["event_refs"][0]),
            lambda ep: ep["snapshot"]["records"][0].update(authority="action-authority"),
            lambda ep: ep["snapshot"].update(retention="altered"),
            lambda ep: ep["snapshot"]["records"][0]["event"].update(tick=True),
            lambda ep: ep["snapshot"]["records"][0]["event"].update(event_id=" "),
            lambda ep: ep["snapshot"]["records"][0]["event"]["world_consequence"].update(target_moved=True),
            lambda ep: ep["envelope"].update(coverage="unknown"),
            lambda ep: ep["envelope"].update(termination="success"),
        )
        for edit in edits:
            m = fixture(); edit(m["episodes"][2]); before = copy.deepcopy(m)
            with self.assertRaises(RescueSelectionError): evaluate(m, True)
            self.assertEqual(m, before)

    def test_all_missing_and_rejection_do_not_change_later_evaluations(self):
        ev = RescueSelectionEvaluator(protocol(), profile(True))
        m = fixture(); before = copy.deepcopy(m); expected = ev.evaluate(m, request())
        missing = {"episodes": [], "missing_episode_ids": request()["episode_ids"]}
        out = ev.evaluate(missing, request())
        self.assertEqual(out["disposition"], "DEFER")
        self.assertIsNone(out["validation_count"])
        self.assertTrue(all(r["source"] is None for r in out["episode_results"]))
        broken = copy.deepcopy(m); broken["episodes"][2]["envelope"]["event_refs"] = ["absent"]
        with self.assertRaises(RescueSelectionError): ev.evaluate(broken, request())
        self.assertEqual(ev.evaluate(m, request()), expected)
        self.assertEqual(m, before)

    def test_action_order_and_terminal_consistency_even_when_partial(self):
        for kind in ("delivery-only", "reversed", "failure-delivery", "participants-changed", "wrong-terminal"):
            m = fixture(); es = [r["event"] for r in m["episodes"][0]["snapshot"]["records"]]
            if kind == "delivery-only": es = es[1:]
            if kind == "reversed": es.reverse()
            if kind == "failure-delivery":
                es[0]["result"] = "carry_not_established"; es[0]["world_consequence"]["carry_established"] = False
            if kind == "participants-changed": es[1].update(participants=["npc_a"], attempt_condition="solo")
            m["episodes"][0] = material("alpha", es, "interrupted" if kind == "wrong-terminal" else "delivered", "partial")
            with self.assertRaises(RescueSelectionError): evaluate(m)

    def test_episode_and_snapshot_order_do_not_change_identity(self):
        expected = evaluate(tolerant=True)
        for permutation in itertools.permutations(range(3)):
            m = fixture(); m["episodes"] = [m["episodes"][i] for i in permutation]
            for ep in m["episodes"]: ep["snapshot"]["records"].reverse()
            p, req = protocol(), request(); p["episodes"].reverse(); req["episode_ids"].reverse()
            self.assertEqual(RescueSelectionEvaluator(p, profile(True)).evaluate(m, req), expected)

    def test_default_runtime_and_soc1_noninterference(self):
        def run(enabled):
            selector = RepeatedRescueSelector(); selector.begin_episode("first", "unrelated-run")
            history, canonical, actions = InteractionHistory(), GameAIFrozenComparisonSidecar(), []
            m = fixture(); before = copy.deepcopy(m)
            with patch.object(canonical.t1_reconstruction, "reconstruct", side_effect=AssertionError("no reconstruction")):
                for i in range(3):
                    if enabled: evaluate(m, bool(i % 2))
                    obs = packet("soc2-control-" + str(i), tick=i + 1)
                    action = decide_action(obs); actions.append(action)
                    history.register_decision(obs, action); canonical.capture(obs)
            self.assertEqual(m, before)
            choice = selector.choose(choice_id="initial", events=[], available_conditions=["solo", "joint", "defer"])
            self.assertEqual(choice["selected"], "solo")
            return actions, history.snapshot(), canonical.snapshot(), selector.snapshot()
        self.assertEqual(run(True), run(False))

    def test_saved_world_replay(self):
        saved = json.loads((ROOT / "tests/fixtures/soc2_godot_replay.json").read_text(encoding="utf-8"))
        for tolerant in (False, True):
            out = RescueSelectionEvaluator(saved["protocol"], profile(tolerant)).evaluate(saved["materials"], request())
            self.assertEqual(out, saved["evaluations"][int(tolerant)])
        for row, world in zip(saved["materials"]["episodes"], saved["worlds"]):
            self.assertEqual([r["event"] for r in row["snapshot"]["records"]], world["experiences"])

    @unittest.skipUnless(os.environ.get("GODOT_BIN"), "set GODOT_BIN for SOC-2 real World/HTTP")
    def test_real_joint_successes_and_counterexample(self):
        output_dir = ROOT / "integrations/luanti/output"; output_dir.mkdir(parents=True, exist_ok=True)
        # Construct both evaluators and the full roster before any World outcome exists.
        plan = protocol(); evaluators = [RescueSelectionEvaluator(plan, profile(t)) for t in (False, True)]
        worlds, materials = [], {"episodes": [], "missing_episode_ids": []}
        for row, load in zip(plan["episodes"], (2, 2, 3)):
            run = row["world_run_id"]
            class RecordingRescue(RescueTrajectoryPolicy):
                def __init__(self): super().__init__(); self.packets = []
                def decide(self, packet): self.packets.append(copy.deepcopy(packet)); return super().decide(packet)
            rescue, canonical = RecordingRescue(), GameAIFrozenComparisonSidecar()
            with patch.object(bridge, "EXPERIENCE", InteractionHistory()), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
                server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
                server.history_policy = None; server.rescue_policy = rescue
                thread = threading.Thread(target=server.serve_forever); thread.start()
                path = output_dir / (run + ".json")
                try:
                    process = subprocess.run([os.environ["GODOT_BIN"], "--headless", "--path", str(ROOT / "godot/rdl-game-ai-workbench"),
                        "--script", "res://tests/rescue_selection_http_check.gd"], capture_output=True, text=True, timeout=60,
                        env={**os.environ, "SOC2_WORLD_RUN": run, "SOC2_TARGET_LOAD": str(load), "SOC2_EVIDENCE_PATH": str(path)},
                        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
                    output = process.stdout + process.stderr; (output_dir / (run + ".log")).write_text(output, encoding="utf-8")
                    self.assertEqual(process.returncode, 0, output); self.assertIn("SOC-2 EPISODE PASS", output)
                    world = json.loads(path.read_text(encoding="utf-8"))
                    self.assertEqual(world["world_run_id"], run)
                    self.assertEqual(world["termination"], "delivered" if load == 2 else "carry_failed")
                    self.assertEqual(world["metrics"]["joint_attempts"], 1)
                    self.assertEqual(world["world_checks"][0]["active"], ["npc_a", "npc_c"])
                    self.assertEqual(world["experimenter_only"], {"carry_capabilities": {"npc_a": 1, "npc_c": 1}, "target_load": load})
                    self.assertEqual(world["initial"]["carry_attempts"], 0); self.assertEqual(world["initial"]["experiences"], 0)
                    if load == 2:
                        self.assertEqual(world["recovery_stages"], ["stabilizing", "mobilizing", "recovering", "recovered"])
                        self.assertEqual(rescue.snapshot()["trajectories"], {})
                    else:
                        self.assertEqual(world["world_checks"][0]["target_before"], world["world_checks"][0]["target_after"])
                        self.assertEqual(world["recovery_stages"], [])
                        self.assertIsNone(world["metrics"]["actions_to_delivery"])
                    self.assertEqual(canonical.snapshot()["T1_materials"]["count"], 0)
                    for surface in (world["experiences"], rescue.packets):
                        for forbidden in ("target_load", "carry_capabilities", "combined_capacity", "required_carriers", "requires_helper"):
                            self.assertNotIn(chr(34) + forbidden + chr(34), json.dumps(surface))
                    worlds.append(world)
                    materials["episodes"].append(material(row["episode_id"], world["experiences"], world["termination"]))
                finally:
                    server.shutdown(); thread.join(); server.server_close()
        self.assertTrue(all(w["initial"] == worlds[0]["initial"] for w in worlds))
        before = copy.deepcopy(materials)
        evaluations = [ev.evaluate(materials, request()) for ev in evaluators]
        self.assertEqual(materials, before)
        self.assertEqual([e["disposition"] for e in evaluations], ["REJECT", "RETAIN"])
        self.assertEqual(evaluations[0]["episode_results"], evaluations[1]["episode_results"])
        self.assertEqual(evaluations[0]["failure_count"], 1); self.assertEqual(evaluations[0]["validation_count"], 3)
        for surface in (materials, evaluations):
            for forbidden in ("target_load", "carry_capabilities", "world_checks", "position"):
                self.assertNotIn(chr(34) + forbidden + chr(34), json.dumps(surface))
        captured = {"protocol": plan, "worlds": worlds, "materials": materials, "evaluations": evaluations}
        (output_dir / "soc2-selection-world.json").write_text(json.dumps(captured, ensure_ascii=False, indent=2), encoding="utf-8")
        print("SOC-2 WORLD PASS: joint success/success/failure; same evidence -> REJECT at 0, RETAIN at 1/3")


if __name__ == "__main__": unittest.main()
