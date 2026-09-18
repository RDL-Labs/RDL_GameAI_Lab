"""Opt-in real Workbench/HTTP check: set GODOT_BIN to a Godot 4 executable."""

import os
from pathlib import Path
import subprocess
import threading
import unittest
from http.server import ThreadingHTTPServer
from unittest.mock import patch

from runtime import bridge
from runtime.experience import InteractionHistory
from runtime.history_policy import HistoryInfluencePolicy
from runtime.life_policy import BaseFoodLifePolicy
from runtime.rest_policy import RestTrajectoryPolicy
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


@unittest.skipUnless(os.environ.get("GODOT_BIN"), "set GODOT_BIN for real Godot HTTP check")
class GodotExperienceTests(unittest.TestCase):
    def test_energy_reserve_world_loop(self):
        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
        completed = subprocess.run(
            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
             "--script", "res://tests/energy_reserve_loop_check.gd"],
            capture_output=True, text=True, timeout=40,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        output = completed.stdout + completed.stderr
        self.assertEqual(completed.returncode, 0, output)
        self.assertIn("EnergyReserve check passed", output)
        print(output.strip())

    def test_active_energy_world_loop(self):
        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
        completed = subprocess.run(
            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
             "--script", "res://tests/active_energy_loop_check.gd"],
            capture_output=True, text=True, timeout=40,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        output = completed.stdout + completed.stderr
        self.assertEqual(completed.returncode, 0, output)
        self.assertIn("ActiveEnergy check passed", output)
        print(output.strip())

    def test_real_workbench_sleep_is_world_action_without_consolidation(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/sleep_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Sleep HTTP check passed", output)
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_real_godot_minimal_rest_loop_changes_body_state(self):
        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
        completed = subprocess.run(
            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
             "--script", "res://tests/rest_minimal_loop_check.gd"],
            capture_output=True, text=True, timeout=40,
            env=os.environ.copy(),
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        output = completed.stdout + completed.stderr
        self.assertEqual(completed.returncode, 0, output)
        self.assertIn("minimal Rest loop check passed", output)
        print(output.strip())

    def test_real_godot_rho_rest_projection_reuses_packet_contract(self):
        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
        completed = subprocess.run(
            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
             "--script", "res://tests/rho_rest_projection_check.gd"],
            capture_output=True, text=True, timeout=40,
            env=os.environ.copy(),
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        output = completed.stdout + completed.stderr
        self.assertEqual(completed.returncode, 0, output)
        self.assertIn("rho Rest projection check passed", output)
        print(output.strip())

    def test_real_godot_rho_packet_is_opt_in(self):
        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
        completed = subprocess.run(
            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
             "--script", "res://tests/rho_observation_packet_check.gd"],
            capture_output=True, text=True, timeout=40,
            env=os.environ.copy(),
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        output = completed.stdout + completed.stderr
        self.assertEqual(completed.returncode, 0, output)
        self.assertIn("rho observation packet check passed", output)
        print(output.strip())

    def test_real_godot_rho_profile_selection_is_versioned(self):
        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
        completed = subprocess.run(
            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
             "--script", "res://tests/rho_profile_selection_check.gd"],
            capture_output=True, text=True, timeout=40,
            env=os.environ.copy(),
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        output = completed.stdout + completed.stderr
        self.assertEqual(completed.returncode, 0, output)
        self.assertIn("rho profile selection check passed", output)
        print(output.strip())

    def test_real_godot_rho_food_projection_is_non_intervening(self):
        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
        completed = subprocess.run(
            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
             "--script", "res://tests/rho_food_projection_check.gd"],
            capture_output=True, text=True, timeout=40,
            env=os.environ.copy(),
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        output = completed.stdout + completed.stderr
        self.assertEqual(completed.returncode, 0, output)
        self.assertIn("rho Food projection check passed", output)
        print(output.strip())

    def test_real_workbench_reports_both_outcomes(self):
        self._run_workbench(False)

    def test_real_workbench_history_changes_approach_to_idle(self):
        self._run_workbench(True)

    def test_real_workbench_short_profile_retries_next_tick(self):
        self._run_workbench(True, "short")

    def test_real_workbench_body_constraint_and_recovery(self):
        self._run_workbench(True, body=True)

    def test_real_workbench_food_loop(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = HistoryInfluencePolicy(profiles={"npc_b": "standard"})
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/food_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Food HTTP check passed", output)
                self.assertEqual(len(history.snapshot()["records"]), 3)
                self.assertEqual(history.snapshot()["pending_results"], 0)
                self.assertEqual(canonical.snapshot()["comparisons"], 4)
                self.assertTrue(all(group["H"] == 0 for group in canonical.assessments.snapshot()["retained_H"]))
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_real_workbench_rest_loop(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/rest_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Rest HTTP check passed", output)
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_real_workbench_rest_trajectory_interrupts_and_resumes(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        rest_policy = RestTrajectoryPolicy()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.rest_policy = rest_policy
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/rest_trajectory_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Rest trajectory HTTP check passed", output)
                self.assertEqual(rest_policy.snapshot()["trajectories"], {})
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_real_workbench_rho_changes_rest_candidate_description_then_selection(self):
        for level, expected_target in (("LOW", "z_grove"), ("HIGH", "plaza")):
            with self.subTest(level=level):
                history = InteractionHistory()
                canonical = GameAIFrozenComparisonSidecar()
                rest_policy = RestTrajectoryPolicy(use_rho_candidates=True)
                with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
                    server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
                    server.history_policy = None
                    server.rest_policy = rest_policy
                    thread = threading.Thread(target=server.serve_forever)
                    thread.start()
                    try:
                        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                        completed = subprocess.run(
                            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                             "--script", "res://tests/rest_rho_selection_http_check.gd"],
                            capture_output=True, text=True, timeout=40,
                            env={**os.environ, "RDL_TEST_RHO_REST_LEVEL": level},
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                        )
                        output = completed.stdout + completed.stderr
                        self.assertEqual(completed.returncode, 0, output)
                        self.assertIn(f"rho Rest selection HTTP check passed: {level} -> {expected_target}", output)
                        print(output.strip())
                    finally:
                        server.shutdown()
                        thread.join()
                        server.server_close()

    def test_real_workbench_assisted_base_food_loop(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        life_policy = BaseFoodLifePolicy()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.life_policy = life_policy
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/base_food_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Base-Food HTTP check passed", output)
                self.assertGreaterEqual(len(history.snapshot()["records"]), 2)
                self.assertGreaterEqual(canonical.snapshot()["comparisons"], 1)
                self.assertEqual(len(life_policy.snapshot()["results"]), 1)
                self.assertEqual(life_policy.snapshot()["results"][0]["outcome"], "replenish_success")
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_real_workbench_ignored_cue_has_shortage_consequence(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.life_policy = BaseFoodLifePolicy(cue_responses={"npc_b": "ignore"})
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/base_food_ignore_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Base-Food ignore check passed", output)
                self.assertEqual(history.snapshot()["records"], [])
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_real_workbench_learned_relation_runs_without_cue(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        life_policy = BaseFoodLifePolicy()
        for index in range(2):
            life_policy.record_result({
                "result_id": f"seed-{index}", "agent_id": "npc_b",
                "source_observation_id": f"seed-observation-{index}",
                "cue_id": f"seed-cue-{index}", "response": "follow",
                "outcome": "replenish_success",
            })
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.life_policy = life_policy
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/base_food_autonomous_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Base-Food autonomous check passed", output)
                self.assertEqual(len(life_policy.snapshot()["results"]), 2)
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_real_workbench_generic_interrupt_holds_and_resumes(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.life_policy = BaseFoodLifePolicy()
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/base_food_interrupt_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Base-Food generic interrupt check passed", output)
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_real_workbench_same_threat_differs_by_profile(self):
        for profile, expected_action in (("cautious", "idle"), ("steadfast", "approach")):
            with self.subTest(profile=profile):
                history = InteractionHistory()
                canonical = GameAIFrozenComparisonSidecar()
                with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
                    server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
                    server.history_policy = None
                    server.life_policy = BaseFoodLifePolicy(threat_profiles={"npc_b": profile})
                    thread = threading.Thread(target=server.serve_forever)
                    thread.start()
                    try:
                        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                        completed = subprocess.run(
                            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                             "--script", "res://tests/base_food_threat_profiles_http_check.gd"],
                            capture_output=True, text=True, timeout=40,
                            env={**os.environ, "RDL_TEST_EXPECT_THREAT_ACTION": expected_action},
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                        )
                        output = completed.stdout + completed.stderr
                        self.assertEqual(completed.returncode, 0, output)
                        self.assertIn("Base-Food threat profile check passed", output)
                        print(output.strip())
                    finally:
                        server.shutdown()
                        thread.join()
                        server.server_close()

    def test_real_workbench_same_novelty_supports_three_responses(self):
        for response in ("ignore", "inspect", "divert"):
            with self.subTest(response=response):
                history = InteractionHistory()
                canonical = GameAIFrozenComparisonSidecar()
                with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
                    server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
                    server.history_policy = None
                    server.life_policy = BaseFoodLifePolicy(novelty_responses={"npc_b": response})
                    thread = threading.Thread(target=server.serve_forever)
                    thread.start()
                    try:
                        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                        completed = subprocess.run(
                            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                             "--script", "res://tests/base_food_novelty_responses_http_check.gd"],
                            capture_output=True, text=True, timeout=40,
                            env={**os.environ, "RDL_TEST_NOVELTY_RESPONSE": response},
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                        )
                        output = completed.stdout + completed.stderr
                        self.assertEqual(completed.returncode, 0, output)
                        self.assertIn(f"Base-Food novelty response check passed: {response}", output)
                        print(output.strip())
                    finally:
                        server.shutdown()
                        thread.join()
                        server.server_close()

    def test_real_workbench_extreme_profiles_bound_tuning(self):
        for profile in ("trajectory_locked", "context_switching"):
            with self.subTest(profile=profile):
                history = InteractionHistory()
                canonical = GameAIFrozenComparisonSidecar()
                with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
                    server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
                    server.history_policy = None
                    server.life_policy = BaseFoodLifePolicy(life_profiles={"npc_b": profile})
                    thread = threading.Thread(target=server.serve_forever)
                    thread.start()
                    try:
                        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                        completed = subprocess.run(
                            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                             "--script", "res://tests/base_food_extreme_profiles_http_check.gd"],
                            capture_output=True, text=True, timeout=40,
                            env={**os.environ, "RDL_TEST_LIFE_PROFILE": profile},
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                        )
                        output = completed.stdout + completed.stderr
                        self.assertEqual(completed.returncode, 0, output)
                        self.assertIn(f"Base-Food extreme profile check passed: {profile}", output)
                        print(output.strip())
                    finally:
                        server.shutdown()
                        thread.join()
                        server.server_close()

    def _run_workbench(self, influence, profile="standard", body=False):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            # Match the current Workbench endpoint; never reuse or stop another server.
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = HistoryInfluencePolicy(profiles={"npc_b": profile}) if influence else None
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/body_http_check.gd" if body else "res://tests/experience_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env={**os.environ, "RDL_TEST_HISTORY_INFLUENCE": "1" if influence else "0",
                         "RDL_TEST_RETRY_PROFILE": profile},
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                marker = "Body HTTP check passed" if body else ("Experience influence check passed" if influence else "Experience HTTP check passed")
                self.assertIn(marker, output)
                snapshot = history.snapshot()
                expected = (5 if profile == "short" else 4) if influence else 12
                if body:
                    expected = 2
                self.assertEqual(len(snapshot["records"]), expected)
                self.assertEqual(snapshot["pending_results"], 0)
                self.assertEqual(snapshot["capacity_rejections"], 0)
                self.assertEqual(len(snapshot["relations"]), 1)
                relation = snapshot["relations"][0]
                self.assertTrue(relation["approach_progress"])
                if not body:
                    self.assertTrue(relation["approach_no_progress"])
                for record in snapshot["records"]:
                    self.assertEqual(record["agent_id"], "npc_b")
                    self.assertEqual(record["action"]["target_id"], "food_01")
                    self.assertNotEqual(record["source_observation_id"], record["subsequent_observation_id"])
                self.assertEqual(len({r["source_observation_id"] for r in snapshot["records"]}), expected)
                self.assertEqual(canonical.snapshot()["comparisons"], expected if influence else 11)
                self.assertTrue(all(g["H"] == 0 for g in canonical.assessments.snapshot()["retained_H"]))
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()
