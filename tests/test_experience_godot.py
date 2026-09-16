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
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


@unittest.skipUnless(os.environ.get("GODOT_BIN"), "set GODOT_BIN for real Godot HTTP check")
class GodotExperienceTests(unittest.TestCase):
    def test_real_workbench_reports_both_outcomes(self):
        self._run_workbench(False)

    def test_real_workbench_history_changes_approach_to_idle(self):
        self._run_workbench(True)

    def _run_workbench(self, influence):
        history = InteractionHistory()
        canonical = GameAIFrozenComparisonSidecar()
        with patch.object(bridge, "EXPERIENCE", history), patch.object(bridge, "CANONICAL_SIDECAR", canonical):
            # Match the current Workbench endpoint; never reuse or stop another server.
            server = ThreadingHTTPServer(("127.0.0.1", 8765), bridge.BridgeHandler)
            server.history_policy = HistoryInfluencePolicy() if influence else None
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            try:
                project = Path(__file__).resolve().parents[1] / "godot" / "rdl-game-ai-workbench"
                completed = subprocess.run(
                    [os.environ["GODOT_BIN"], "--headless", "--path", str(project),
                     "--script", "res://tests/experience_http_check.gd"],
                    capture_output=True, text=True, timeout=40,
                    env={**os.environ, "RDL_TEST_HISTORY_INFLUENCE": "1" if influence else "0"},
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )
                output = completed.stdout + completed.stderr
                self.assertEqual(completed.returncode, 0, output)
                self.assertIn("Experience influence check passed" if influence else "Experience HTTP check passed", output)
                snapshot = history.snapshot()
                expected = 4 if influence else 12
                self.assertEqual(len(snapshot["records"]), expected)
                self.assertEqual(snapshot["pending_results"], 0)
                self.assertEqual(snapshot["capacity_rejections"], 0)
                self.assertEqual(len(snapshot["relations"]), 1)
                relation = snapshot["relations"][0]
                self.assertTrue(relation["approach_progress"])
                self.assertTrue(relation["approach_no_progress"])
                for record in snapshot["records"]:
                    self.assertEqual(record["agent_id"], "npc_b")
                    self.assertEqual(record["action"]["target_id"], "food_01")
                    self.assertNotEqual(record["source_observation_id"], record["subsequent_observation_id"])
                self.assertEqual(len({r["source_observation_id"] for r in snapshot["records"]}), expected)
                self.assertEqual(canonical.snapshot()["comparisons"], 4 if influence else 11)
                self.assertTrue(all(g["H"] == 0 for g in canonical.assessments.snapshot()["retained_H"]))
                print(output.strip())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()
