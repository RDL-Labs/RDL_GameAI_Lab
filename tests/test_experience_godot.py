"""Opt-in real Workbench/HTTP check: set GODOT_BIN to a Godot 4 executable."""

import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import unittest
import urllib.request
from http.server import ThreadingHTTPServer
from unittest.mock import patch

from runtime import bridge
from runtime.experience import InteractionHistory
from runtime.history_policy import HistoryInfluencePolicy
from runtime.life_policy import BaseFoodLifePolicy
from runtime.rest_policy import RestTrajectoryPolicy
from runtime.safety_policy import SafetyTrajectoryPolicy
from runtime.food_safety_policy import FoodSafetyCoordinator
from runtime.food_rest_policy import FoodRestCoordinator
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


def admit_bounded_life_success(policy, agent_id, index):
    cue_id = f"seed-cue-{index}"

    def packet(observation_id, held, at_base):
        return {
            "observation_id": observation_id, "tick": index + 1, "agent_id": agent_id,
            "observation": {
                "visible_agents": [],
                "visible_objects": [{"id": "food_01", "kind": "food", "within_reach": False}],
                "visible_places": [],
                "body": {
                    "agent_id": agent_id, "snapshot_id": f"body-{index}", "revision": index,
                    "movement_scale": 1.0, "food_actions_enabled": True,
                    "food_need": 0.8, "held_food_ids": held,
                },
                "life_context": {
                    "god_statue_cue": {
                        "source": "system_assessment", "topic": "base_food", "band": "low",
                        "delivery": "morning", "cue_id": cue_id,
                    },
                    "observed_base_food_band": "low",
                    "known_base": {"id": "plaza"}, "at_base": at_base,
                    "interrupt_candidates": [],
                },
            },
        }

    policy.decide(packet(f"seed-start-{index}", [], False))
    source_id = f"seed-deposit-{index}"
    decision = policy.decide(packet(source_id, ["food_01"], True))
    if decision["action"] != {"type": "deposit", "target_id": "plaza"}:
        raise AssertionError(f"seed decision was not a bounded deposit: {decision}")
    return policy.record_result({
        "result_id": f"seed-{index}", "agent_id": agent_id,
        "source_observation_id": source_id, "cue_id": cue_id,
        "response": "follow", "outcome": "replenish_success",
    })


@unittest.skipUnless(os.environ.get("GODOT_BIN"), "set GODOT_BIN for real Godot HTTP check")
class GodotExperienceTests(unittest.TestCase):
    def test_food_rest_coordinator_suspends_recovers_and_resumes(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        coordinator = FoodRestCoordinator()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.life_policy = coordinator
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/food_rest_resume_http_check.gd"],
                    capture_output=True, text=True, timeout=60,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Food-Rest resume check passed", output)
                self.assertEqual(len(coordinator.snapshot()["food"]["results"]), 1)
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_food_safety_coordinator_suspends_escapes_and_resumes(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        coordinator = FoodSafetyCoordinator()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.life_policy = coordinator
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/food_safety_resume_http_check.gd"],
                    capture_output=True, text=True, timeout=50,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Food-Safety resume check passed", output)
                self.assertIs(server.life_policy, coordinator)
                self.assertEqual(
                    len(coordinator.snapshot()["food"]["results"]), 1,
                    f"{output}\nserver policy={server.life_policy.snapshot()}"
                    f"\ninteraction history={history.snapshot()}",
                )
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()
    def test_selected_inspector_is_separate_from_simulated_agents(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.life_policy = BaseFoodLifePolicy(cue_responses={"npc_a": "ignore"})
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/multi_agent_simulation_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Multi-agent simulation check passed", output)
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()
    def test_three_real_food_cycles_enable_autonomy_without_seed_results(self):
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
                     "--script", "res://tests/base_food_three_cycle_http_check.gd"],
                    capture_output=True, text=True, timeout=60,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Base-Food three-cycle check passed", output)
                snapshot = life_policy.snapshot()
                self.assertEqual(len(snapshot["results"]), 2)
                self.assertIn("npc_b", snapshot["habit_ready_agents"])
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()
    def test_continuous_life_interrupt_experience_and_autonomy(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        coordinator = FoodSafetyCoordinator()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.life_policy = coordinator
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/continuous_life_evidence_http_check.gd"],
                    capture_output=True, text=True, timeout=75,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Continuous-life evidence check passed", output)
                snapshot = coordinator.snapshot()["food"]
                self.assertEqual(len(snapshot["results"]), 2)
                self.assertIn("npc_b", snapshot["habit_ready_agents"])
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_safety_vertical_uses_normal_cli_startup(self):
        project_root = Path(__file__).resolve().parents[1]
        flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
        process = subprocess.Popen(
            [sys.executable, "-m", "runtime.bridge", "--safety-trajectory"],
            cwd=project_root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, env=os.environ.copy(), creationflags=flags,
        )
        try:
            deadline = time.monotonic() + 10
            while True:
                if process.poll() is not None:
                    self.fail(f"Safety CLI exited early: {process.stdout.read()}")
                try:
                    with urllib.request.urlopen("http://127.0.0.1:8765/health", timeout=0.5) as response:
                        if response.status == 200:
                            break
                except OSError:
                    if time.monotonic() >= deadline:
                        self.fail("Safety CLI did not become healthy")
                    time.sleep(0.1)
            project = project_root / "godot" / "rdl-game-ai-workbench"
            completed = subprocess.run(
                [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                 "--script", "res://tests/safety_flee_http_check.gd"],
                capture_output=True, text=True, timeout=40,
                env=os.environ.copy(), creationflags=flags,
            )
            output = completed.stdout + completed.stderr
            self.assertEqual(completed.returncode, 0, output)
            self.assertIn("Safety trajectory check passed", output)
        finally:
            process.terminate()
            try:
                process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate(timeout=5)
    def test_food_safety_vertical_uses_normal_cli_startup(self):
        project_root = Path(__file__).resolve().parents[1]
        flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
        process = subprocess.Popen(
            [sys.executable, "-m", "runtime.bridge", "--food-safety-life"],
            cwd=project_root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, env=os.environ.copy(), creationflags=flags,
        )
        try:
            deadline = time.monotonic() + 10
            while True:
                if process.poll() is not None:
                    self.fail(f"Food-Safety CLI exited early: {process.stdout.read()}")
                try:
                    with urllib.request.urlopen("http://127.0.0.1:8765/health", timeout=0.5) as response:
                        if response.status == 200:
                            break
                except OSError:
                    if time.monotonic() >= deadline:
                        self.fail("Food-Safety CLI did not become healthy")
                    time.sleep(0.1)
            project = project_root / "godot" / "rdl-game-ai-workbench"
            completed = subprocess.run(
                [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                 "--script", "res://tests/food_safety_resume_http_check.gd"],
                capture_output=True, text=True, timeout=50,
                env=os.environ.copy(), creationflags=flags,
            )
            output = completed.stdout + completed.stderr
            self.assertEqual(completed.returncode, 0, output)
            self.assertIn("Food-Safety resume check passed", output)
        finally:
            process.terminate()
            try:
                process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate(timeout=5)

    def test_food_rest_vertical_uses_normal_cli_startup(self):
        project_root = Path(__file__).resolve().parents[1]
        flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
        process = subprocess.Popen(
            [sys.executable, "-m", "runtime.bridge", "--food-rest-life"],
            cwd=project_root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, env=os.environ.copy(), creationflags=flags,
        )
        try:
            deadline = time.monotonic() + 10
            while True:
                if process.poll() is not None:
                    self.fail(f"Food-Rest CLI exited early: {process.stdout.read()}")
                try:
                    with urllib.request.urlopen("http://127.0.0.1:8765/health", timeout=0.5) as response:
                        if response.status == 200:
                            break
                except OSError:
                    if time.monotonic() >= deadline:
                        self.fail("Food-Rest CLI did not become healthy")
                    time.sleep(0.1)
            project = project_root / "godot" / "rdl-game-ai-workbench"
            completed = subprocess.run(
                [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                 "--script", "res://tests/food_rest_resume_http_check.gd"],
                capture_output=True, text=True, timeout=60,
                env=os.environ.copy(), creationflags=flags,
            )
            output = completed.stdout + completed.stderr
            self.assertEqual(completed.returncode, 0, output)
            self.assertIn("Food-Rest resume check passed", output)
        finally:
            process.terminate()
            try:
                process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate(timeout=5)

    def test_workbench_visualization_is_observational_only(self):
        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
        completed = subprocess.run(
            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
             "--script", "res://tests/workbench_visualization_check.gd"],
            capture_output=True, text=True, timeout=40,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        output = completed.stdout + completed.stderr
        self.assertEqual(completed.returncode, 0, output)
        self.assertIn("Workbench visualization check passed", output)
        print(output.strip())

    def test_real_workbench_escapes_bounded_moving_threat(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.safety_policy = SafetyTrajectoryPolicy()
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/safety_moving_threat_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Moving threat Safety check passed", output)
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_real_workbench_flees_bounded_danger_zone(self):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = None
            server.safety_policy = SafetyTrajectoryPolicy()
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/safety_flee_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env=os.environ.copy(),
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Safety trajectory check passed", output)
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_active_energy_capacity_bounds_recovery(self):
        project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
        completed = subprocess.run(
            [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
             "--script", "res://tests/active_energy_capacity_check.gd"],
            capture_output=True, text=True, timeout=40,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        output = completed.stdout + completed.stderr
        self.assertEqual(completed.returncode, 0, output)
        self.assertIn("ActiveEnergyCapacity check passed", output)
        print(output.strip())

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
            admit_bounded_life_success(life_policy, "npc_b", index)
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
