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
from runtime.contextual_carry import ContextualCarryError, ContextualCarryPredictor, inspect_context_hypotheses, hypotheses, RULE, PURPOSE, PROFILE
from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.rescue_policy import RescueTrajectoryPolicy
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_rescue_selection import synthetic
from test_sensory_observation import packet

ROOT = Path(__file__).resolve().parents[1]
CELLS = [("full", "firm"), ("full", "loose"), ("limited", "firm"), ("limited", "loose")]


def protocol():
    p = {"schema": RULE, "purpose": PURPOSE, "experiment_id": "soc4-two-conditions", "agent_id": "npc_a",
         "target_id": "npc_b", "context_ref": "soc4-fixed-pickup-v1"}
    for phase in ("formation", "validation", "forecast"):
        p[phase] = [{"episode_id": phase + "-" + str(i), "run_id": "soc4-" + phase + "-" + str(i)} for i in range(4)]
    return p


def material(phase, i, fail=None):
    b, f = CELLS[i]
    row = protocol()[phase][i]; run = row["run_id"]
    fail = i == 3 if fail is None else fail
    event = synthetic("temp", fail)["snapshot"]["records"][0]["event"]
    event.update(run_id=run, event_id=run + ":event:0", source_observation_id=run + ":before",
                 subsequent_observation_id=run + ":after", participants=["npc_a"], attempt_condition="solo")
    context = {"schema": "soc4-pre-carry-context-v1", "run_id": run, "agent_id": "npc_a", "target_id": "npc_b",
               "context_ref": protocol()["context_ref"], "profile": PROFILE, "source_observation_id": event["source_observation_id"],
               "tick": 0, "body_ref": "body-a-1", "footing_ref": "contact-1", "movement_band": b, "footing_band": f,
               "coverage": "complete", "actor_ready": True, "target_ready": True, "within_reach": True}
    return {"episode_id": row["episode_id"], "context": context, "event": event, "conditions_stable": True, "termination": "carry_observed"}


def materials(phase, truth=(False, False, False, True)):
    return {"episodes": [material(phase, i, truth[i]) for i in range(4)], "missing_episode_ids": []}


def predictor(formation=None, validation=None):
    return ContextualCarryPredictor(protocol(), formation if formation is not None else materials("formation"),
                                    validation if validation is not None else materials("validation"))


def request(i=0):
    m = material("forecast", i)
    return {"request_id": "request-" + str(i), "episode_id": m["episode_id"], "context": m["context"]}


class ContextualCarryTests(unittest.TestCase):
    def test_combination_formed_and_independently_validated(self):
        s = predictor(); model = s.snapshot()["model"]
        retained = [r for r in model["hypotheses"] if r["disposition"] == "RETAIN"]
        self.assertEqual(len(model["hypotheses"]), 14); self.assertEqual(len(retained), 1)
        self.assertEqual(retained[0]["predicate"], {"op": "and", "movement_band": "limited", "footing_band": "loose"})
        for r in model["hypotheses"]:
            if r["predicate"]["op"] in ("constant", "literal"):
                self.assertEqual(r["disposition"], "REJECT"); self.assertTrue(r["formation_conflicts"])
        self.assertEqual((model["formation_count"], model["validation_count"]), (4, 4))
        self.assertEqual([s.predict(**request(i))["prediction"] for i in range(4)],
                         ["likely_established"] * 3 + ["likely_not_established"])

    def test_all_sixteen_tables_not_a_hardcoded_failure_conjunction(self):
        for truth in itertools.product((False, True), repeat=4):
            s = predictor(materials("formation", truth), materials("validation", truth))
            expected = ["unknown"] * 4 if truth in ((False, True, True, False), (True, False, False, True)) else [
                "likely_not_established" if v else "likely_established" for v in truth]
            self.assertEqual([s.predict(**request(i))["prediction"] for i in range(4)], expected)
        self.assertEqual(len({r["hypothesis_id"] for r in hypotheses()}), 14)

    def test_independent_counterexample_rejects_without_refitting(self):
        s = predictor(validation=materials("validation", (False, False, False, False)))
        rows = s.snapshot()["model"]["hypotheses"]
        joint = next(r for r in rows if r["formation_compatible"])
        self.assertEqual(joint["disposition"], "REJECT")
        self.assertEqual(joint["reasons"], ["validation_counterexample"])
        self.assertEqual(joint["validation_conflicts"], ["validation-3"])
        self.assertEqual(s.predict(**request(3))["prediction"], "unknown")
        self.assertFalse(any(r["disposition"] == "RETAIN" for r in rows))

    def test_missing_or_partial_evidence_never_becomes_failure(self):
        for phase in ("formation", "validation"):
            for missing in (True, False):
                m = materials(phase)
                if missing:
                    removed = m["episodes"].pop(); m["missing_episode_ids"].append(removed["episode_id"])
                else: m["episodes"][3]["context"]["coverage"] = "partial"
                s = predictor(**{phase: m})
                self.assertEqual(s.predict(**request(3))["prediction"], "unknown")
                rows = s.snapshot()["model"][phase]
                self.assertEqual(sum(r["comparable"] for r in rows), 3)
                self.assertTrue(rows[3]["reasons"])
                self.assertIsNone(rows[3]["observed"]) if missing else self.assertEqual(rows[3]["observed"], "not_established")

    def test_untried_changed_condition_and_unavailable_actor_remain_unresolved(self):
        for mode in ("untried", "changed", "body", "not-ready"):
            v = materials("validation"); m = v["episodes"][3]
            if mode == "untried": m.update(event=None, termination="not_attempted")
            elif mode == "changed": m["conditions_stable"] = False
            elif mode == "body": m["event"]["body_consequence"]["actor_incapacitated"] = True
            else: m["context"]["actor_ready"] = False
            s = predictor(validation=v)
            self.assertEqual(s.predict(**request(3))["prediction"], "unknown")
            self.assertFalse(s.snapshot()["model"]["validation"][3]["comparable"])

    def test_unseen_cell_and_conflicting_identical_context(self):
        train = materials("formation")
        train["episodes"][3]["context"].update(movement_band="full", footing_band="firm")
        s = predictor(formation=train); model = s.snapshot()["model"]
        self.assertIn("context_cells_incomplete", model["formation_reasons"])
        self.assertFalse(any(r["formation_compatible"] for r in model["hypotheses"]))
        self.assertEqual(s.predict(**request(3))["prediction"], "unknown")

    def test_current_unknown_and_context_mismatch_are_not_negative_predictions(self):
        for change in ({"movement_band": "unknown"}, {"footing_band": "unknown"}, {"coverage": "partial"},
                       {"actor_ready": False}, {"target_ready": False}, {"within_reach": False}, {"context_ref": "different"}):
            s = predictor(); r = request(3); r["context"].update(change)
            out = s.predict(**r)
            self.assertEqual(out["prediction"], "unknown"); self.assertTrue(out["reasons"])

    def test_rosters_are_disjoint_and_do_not_accept_partial_selection(self):
        for mode in ("episode", "run", "over", "under"):
            p = protocol()
            if mode in ("episode", "run"):
                key = "episode_id" if mode == "episode" else "run_id"
                p["validation"][0][key] = p["formation"][0][key]
            elif mode == "over": p["formation"].append(p["formation"][0])
            else: p["formation"].pop()
            with self.assertRaises(ContextualCarryError): ContextualCarryPredictor(p, materials("formation"), materials("validation"))
        for change in (lambda m: m["episodes"].pop(), lambda m: m["missing_episode_ids"].append("foreign"),
                       lambda m: m["episodes"].__setitem__(1, m["episodes"][0])):
            m = materials("formation"); change(m)
            with self.assertRaises(ContextualCarryError): predictor(formation=m)

    def test_event_binding_and_capture_integrity_rejected(self):
        edits = [lambda m: m["event"].update(run_id="foreign"), lambda m: m["event"].update(target_id="foreign"),
                 lambda m: m["event"].update(source_observation_id="different"), lambda m: m["event"].update(tick=1),
                 lambda m: m["event"].update(participants=["npc_a", "npc_c"], attempt_condition="joint"),
                 lambda m: m["context"].update(agent_id="npc_c"), lambda m: m["context"].update(profile="different"),
                 lambda m: m.update(termination="delivered"), lambda m: m["context"].update(target_load=2),
                 lambda m: m["context"].update(actor_ready=1)]
        for edit in edits:
            m = materials("formation"); edit(m["episodes"][0])
            with self.assertRaises(ContextualCarryError): predictor(formation=m)
        v = materials("validation"); v["episodes"][0]["event"]["event_id"] = materials("formation")["episodes"][0]["event"]["event_id"]
        with self.assertRaisesRegex(ContextualCarryError, "event_reused"): predictor(validation=v)

    def test_input_order_and_names_do_not_choose_the_hypothesis(self):
        p, f, v = protocol(), materials("formation"), materials("validation")
        first = inspect_context_hypotheses(p, f, v)
        p["formation"].reverse(); p["validation"].reverse(); f["episodes"].reverse(); v["episodes"].reverse()
        self.assertEqual(inspect_context_hypotheses(p, f, v), first)
        for phase, m in (("formation", f), ("validation", v)):
            rename = {r["episode_id"]: "arbitrary-" + str(i) + "-" + phase for i, r in enumerate(p[phase])}
            for r in p[phase]: r["episode_id"] = rename[r["episode_id"]]
            for row in m["episodes"]: row["episode_id"] = rename[row["episode_id"]]
        second = inspect_context_hypotheses(p, f, v)
        self.assertEqual([r["predicate"] for r in first["hypotheses"] if r["disposition"] == "RETAIN"],
                         [r["predicate"] for r in second["hypotheses"] if r["disposition"] == "RETAIN"])

    def test_frozen_input_and_returned_values_do_not_alias(self):
        p, f, v = protocol(), materials("formation"), materials("validation")
        s = ContextualCarryPredictor(p, f, v); before = s.snapshot()
        p.clear(); f.clear(); v.clear(); exposed = s.snapshot(); exposed["model"].clear()
        self.assertEqual(s.snapshot(), before)
        req = request(); out = s.predict(**req); expected = s.snapshot(); req["context"].clear(); out.clear()
        self.assertEqual(s.snapshot(), expected)

    def test_prediction_replay_conflict_and_finite_roster(self):
        s = predictor(); first = s.predict(**request()); before = s.snapshot()
        self.assertEqual(s.predict(**request()), first); self.assertEqual(s.snapshot(), before)
        for r in ({**request(), "context": {**request()["context"], "footing_band": "loose"}},
                  {**request(), "request_id": "another"}, {**request(), "request_id": "other", "episode_id": "formation-0"}):
            with self.assertRaises(ContextualCarryError): s.predict(**r)
            self.assertEqual(s.snapshot(), before)
        for i in range(1, 4): s.predict(**request(i))
        before = s.snapshot()
        with self.assertRaises(ContextualCarryError): s.predict(**{**request(), "request_id": "fifth"})
        self.assertEqual(s.snapshot(), before)

    def test_new_outcome_checked_against_frozen_prediction_not_used_for_learning(self):
        s = predictor(); model = s.snapshot()["model"]
        with self.assertRaises(ContextualCarryError): s.record_outcome(request_id="request-0", material=material("forecast", 0))
        p = s.predict(**request()); wrong = material("forecast", 0, True)
        result = s.record_outcome(request_id="request-0", material=wrong)
        self.assertFalse(result["match"]); self.assertEqual(result["prediction_id"], p["prediction_id"])
        self.assertEqual(s.snapshot()["model"], model)
        self.assertEqual(s.record_outcome(request_id="request-0", material=wrong), result)
        before = s.snapshot()
        with self.assertRaises(ContextualCarryError): s.record_outcome(request_id="request-0", material=material("forecast", 0))
        self.assertEqual(s.snapshot(), before)
        self.assertEqual(s.predict(**request()), p)

    def test_unexecuted_prediction_is_not_a_failure_vote(self):
        s = predictor(); s.predict(**request(3)); m = material("forecast", 3)
        m.update(event=None, termination="not_attempted")
        out = s.record_outcome(request_id="request-3", material=m)
        self.assertIsNone(out["match"]); self.assertIsNone(out["observation"]["observed"])
        self.assertEqual(s.snapshot()["model"]["validation_count"], 4)

    def test_outcome_context_change_and_past_event_alias_leave_state_unchanged(self):
        for edit in (lambda m: m["context"].update(tick=1), lambda m: m.update(episode_id="formation-0"),
                     lambda m: m["event"].update(event_id=materials("formation")["episodes"][0]["event"]["event_id"])):
            s = predictor(); s.predict(**request()); before = s.snapshot(); m = material("forecast", 0); edit(m)
            with self.assertRaises(ContextualCarryError): s.record_outcome(request_id="request-0", material=m)
            self.assertEqual(s.snapshot(), before)

    def test_default_action_history_canonical_noninterference(self):
        def run(enabled):
            h, canonical = InteractionHistory(), GameAIFrozenComparisonSidecar(); actions = []
            with patch.object(canonical.t1_reconstruction, "reconstruct", side_effect=AssertionError("no T1")):
                if enabled: predictor().predict(**request())
                for i in range(3):
                    p = packet("soc4-" + str(i), tick=i + 1); a = decide_action(p)
                    actions.append(a); h.register_decision(p, a); canonical.capture(p)
            return actions, h.snapshot(), canonical.snapshot()
        self.assertEqual(run(False), run(True))

    def test_saved_world_replay(self):
        saved = json.loads((ROOT / "tests/fixtures/soc4_godot_replay.json").read_text(encoding="utf-8"))
        s = ContextualCarryPredictor(saved["protocol"], saved["formation"], saved["validation"])
        self.assertEqual(s.snapshot()["model"], saved["snapshot"]["model"])
        for world in saved["worlds"][8:]:
            self.assertEqual(s.predict(**world["prediction_request"]), world["prediction"])
            s.record_outcome(request_id=world["prediction_request"]["request_id"], material=world["material"])
        self.assertEqual(s.snapshot(), saved["snapshot"])

    @unittest.skipUnless(os.environ.get("GODOT_BIN"), "set GODOT_BIN for SOC-4 twelve real World/HTTP episodes")
    def test_real_formation_validation_and_prediction_before_action(self):
        output_dir = ROOT / "integrations/luanti/output"; output_dir.mkdir(parents=True, exist_ok=True)
        p = protocol(); worlds = []; forecaster = None; http_events = []
        class Handler(bridge.BridgeHandler):
            def do_POST(self):
                if self.path == "/soc4/predict":
                    try:
                        self.assert_predictor()
                        payload = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                        result = forecaster.predict(**payload)
                        http_events.append(("predict", payload["context"]["run_id"], payload["context"]["source_observation_id"]))
                        self._send_json(200, result)
                    except (ValueError, TypeError) as exc: self._send_json(400, {"error": str(exc)})
                else:
                    if self.path == "/v1/observe": http_events.append(("action", self.server.run_id, None))
                    super().do_POST()
            def assert_predictor(self):
                if forecaster is None: raise ValueError("formation not complete")
        server = ThreadingHTTPServer(("127.0.0.1", 8765), Handler)
        thread = threading.Thread(target=server.serve_forever); thread.start()
        try:
            for phase in ("formation", "validation", "forecast"):
                if phase == "forecast":
                    formation = {"episodes": [w["material"] for w in worlds[:4]], "missing_episode_ids": []}
                    validation = {"episodes": [w["material"] for w in worlds[4:8]], "missing_episode_ids": []}
                    forecaster = ContextualCarryPredictor(p, formation, validation); frozen = forecaster.snapshot()["model"]
                for i, row in enumerate(p[phase]):
                    rescue, canonical = RescueTrajectoryPolicy(), GameAIFrozenComparisonSidecar()
                    server.rescue_policy = rescue; server.history_policy = None; server.run_id = row["run_id"]
                    path = output_dir / (row["run_id"] + ".json")
                    with patch.object(bridge, "EXPERIENCE", InteractionHistory()), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
                        proc = subprocess.run([os.environ["GODOT_BIN"], "--headless", "--path", str(ROOT / "godot/rdl-game-ai-workbench"),
                            "--script", "res://tests/contextual_carry_http_check.gd"], capture_output=True, text=True, timeout=30,
                            env={**os.environ, "SOC4_RUN_ID": row["run_id"], "SOC4_EPISODE_ID": row["episode_id"],
                                 "SOC4_MOVEMENT": "1.0" if CELLS[i][0] == "full" else "0.5", "SOC4_FOOTING": CELLS[i][1],
                                 "SOC4_FORECAST": "1" if phase == "forecast" else "0", "SOC4_EVIDENCE_PATH": str(path)},
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
                        text = proc.stdout + proc.stderr; (output_dir / (row["run_id"] + ".log")).write_text(text, encoding="utf-8")
                        self.assertEqual(proc.returncode, 0, text); self.assertIn("SOC-4 EPISODE PASS", text)
                        world = json.loads(path.read_text(encoding="utf-8")); m = world["material"]
                        self.assertEqual(m["event"]["result"], "carry_not_established" if i == 3 else "carry_established")
                        self.assertTrue(m["conditions_stable"]); self.assertEqual(m["context"]["source_observation_id"], m["event"]["source_observation_id"])
                        self.assertEqual(len(world["world_checks"]), 1); self.assertEqual(world["world_checks"][0]["active"], ["npc_a"])
                        self.assertEqual(canonical.snapshot()["T1_materials"]["count"], 0)
                        for surface in (m, world["packet"], world["prediction"], world["prediction_request"]):
                            for forbidden in ("target_load", "carry_capabilities", "effective_capacity", "resistance"):
                                self.assertNotIn(chr(34) + forbidden + chr(34), json.dumps(surface))
                        if phase == "forecast":
                            self.assertEqual(world["prediction"]["prediction"], "likely_not_established" if i == 3 else "likely_established")
                            self.assertEqual([e[0] for e in http_events if e[1] == row["run_id"]], ["predict", "predict", "action"])
                            result = forecaster.record_outcome(request_id=world["prediction_request"]["request_id"], material=m)
                            self.assertTrue(result["match"]); self.assertEqual(forecaster.snapshot()["model"], frozen)
                        worlds.append(world)
            capture = {"protocol": p, "formation": formation, "validation": validation, "worlds": worlds, "snapshot": forecaster.snapshot()}
            (output_dir / "soc4-contextual-world.json").write_text(json.dumps(capture, ensure_ascii=False, indent=2), encoding="utf-8")
            self.assertEqual(len(worlds), 12)
            print("SOC-4 WORLD PASS: formation 4 + validation 4 + prospective 4; predicted 3 established / 1 not established before action")
        finally:
            server.shutdown(); thread.join(); server.server_close()


if __name__ == "__main__": unittest.main()
