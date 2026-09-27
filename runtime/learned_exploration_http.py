"""Isolated L13S loopback transport. Day-boundary mutation is harness-owned."""
import json
from http.server import BaseHTTPRequestHandler
from .learned_exploration import SCHEMA


class LearnedExplorationHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, status, value):
        raw = json.dumps(value, allow_nan=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        s = self.server.series
        with s.lock:
            if self.path == "/health":
                return self.send(200, dict(ok=True, schema=SCHEMA, run_id=s.loop.run_id))
            if self.path == "/v1/exploration-snapshot":
                return self.send(200, dict(exploration=s.loop.snapshot(), canonical=s.canonical.snapshot(), history={}))
        self.send(404, dict(error="unknown_endpoint"))

    def do_POST(self):
        name = self.path.removeprefix("/v1/exploration/")
        known = self.path.startswith("/v1/exploration/") and name in ("configure", "observe", "result", "finish")
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 <= size <= 262144 or (known and size == 0):
                return self.send(413, dict(error="payload_budget"))
            # Drain bounded bodies before 404. Closing with unread bytes can reset
            # the connection on Windows before the client receives the response.
            raw = self.rfile.read(size)
            if not known:
                return self.send(404, dict(error="unknown_endpoint"))
            value = json.loads(raw)
            s = self.server.series
            with s.lock:
                response = getattr(s.loop, name)(value)
            self.send(200, response)
        except (ValueError, TypeError, KeyError) as exc:
            self.send(422, dict(error=str(exc)))
