import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import MagicMock


SERVER_PATH = Path(__file__).resolve().parents[1] / "gui-p5" / "serve.py"
SPEC = importlib.util.spec_from_file_location("gui_p5_server", SERVER_PATH)
SERVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SERVER)


class WorkbenchServerTests(unittest.TestCase):
    def handler(self):
        handler = object.__new__(SERVER.WorkbenchHandler)
        handler.send_error = MagicMock()
        return handler

    def test_mutating_methods_are_rejected(self):
        for method in ("do_POST", "do_PUT", "do_PATCH", "do_DELETE"):
            with self.subTest(method=method):
                handler = self.handler()
                getattr(handler, method)()
                handler.send_error.assert_called_once_with(
                    405, "Workbench proxy is read-only"
                )

    def test_all_workbench_responses_disable_browser_cache(self):
        handler = self.handler()
        handler.send_header = MagicMock()
        original = SERVER.SimpleHTTPRequestHandler.end_headers
        SERVER.SimpleHTTPRequestHandler.end_headers = MagicMock()
        try:
            handler.end_headers()
        finally:
            SERVER.SimpleHTTPRequestHandler.end_headers = original
        handler.send_header.assert_called_once_with("Cache-Control", "no-store")

    def test_abandoned_read_only_response_is_quiet(self):
        handler = self.handler()
        handler.path = "/runtime/health"
        handler.send_response = MagicMock()
        handler.send_header = MagicMock()
        handler.end_headers = MagicMock()
        handler.wfile = MagicMock()
        handler.wfile.write.side_effect = ConnectionAbortedError()

        class Response:
            status = 200
            headers = {"Content-Type": "application/json"}

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self):
                return b'{"ok": true}'

        original = SERVER.urlopen
        SERVER.urlopen = lambda *_args, **_kwargs: Response()
        try:
            handler._proxy_runtime_get()
        finally:
            SERVER.urlopen = original

        handler.wfile.write.assert_called_once_with(b'{"ok": true}')

    def test_l9_luanti_trace_uses_get_only_snapshot(self):
        api = (SERVER.GUI_DIR / "api.js").read_text(encoding="utf-8")
        lineage = (SERVER.GUI_DIR / "views" / "lineage_view.js").read_text(encoding="utf-8")
        self.assertIn("['luanti_outcome', '/v1/luanti-outcome-snapshot']", api)
        self.assertIn("luanti_outcome_snapshot", api)
        self.assertIn("LUANTI LIFE TRACE", lineage)
        self.assertNotIn("/v1/luanti-t1-cutover", api)
        self.assertNotIn("fetch(this.baseUrl", api.split("async fetchEndpoint", 1)[0])

    def test_l9_canonical_inspector_is_agent_scoped(self):
        inspector = (SERVER.GUI_DIR / "views" / "inspector_view.js").read_text(
            encoding="utf-8"
        )
        self.assertIn("item.agent_id === selectedAgentId", inspector)
        self.assertIn("assessmentIds.has(item.assessment_id)", inspector)
        self.assertIn("modelRefs.has(item.model_ref)", inspector)
        self.assertNotIn("paths[paths.length - 1]", inspector)

    def test_obs5_sensory_view_is_get_only_and_agent_scoped(self):
        api = (SERVER.GUI_DIR / "api.js").read_text(encoding="utf-8")
        sketch = (SERVER.GUI_DIR / "sketch.js").read_text(encoding="utf-8")
        view = (SERVER.GUI_DIR / "views" / "sensory_view.js").read_text(
            encoding="utf-8"
        )
        self.assertIn("['sensory', '/v1/sensory-observation-snapshot']", api)
        self.assertIn("sensory_observation_snapshot", api)
        self.assertIn("latest_by_agent?.[selectedAgentId]", view)
        self.assertIn("channels are not time-synchronized", view)
        self.assertIn("OUTPUT LIMITED", view)
        self.assertIn("capture_window", view)
        self.assertIn("sensoryView.draw(this, currentData, selectedAgentId)", sketch)
        self.assertNotIn("/v1/observe", api)

    def test_obs5_capture_labels_use_runtime_window_schema(self):
        view_path = SERVER.GUI_DIR / "views" / "sensory_view.js"
        script = (
            f"const View=require({json.dumps(str(view_path))});"
            "const view=new View(0,0,1,1);"
            "console.log(JSON.stringify(["
            "view.captureLabel({kind:'instant',start_us:250000,end_us:250000}),"
            "view.captureLabel({kind:'interval',start_us:500000,end_us:750000})"
            "]));"
        )
        result = subprocess.run(
            ["node", "-e", script], check=True, capture_output=True, text=True
        )
        self.assertEqual(
            json.loads(result.stdout),
            ["250000 us", "[500000, 750000) us"],
        )


if __name__ == "__main__":
    unittest.main()
