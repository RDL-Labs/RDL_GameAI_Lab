import importlib.util
from pathlib import Path
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


if __name__ == "__main__":
    unittest.main()
