"""Localhost HTTP bridge for the minimal GameAI runtime."""

from __future__ import annotations

import argparse
import json
from threading import RLock
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from .core import ObservationError, decide_action
from .v23_interpretation import GameAIFrozenComparisonSidecar
from .experience import InteractionHistory, HistoryError


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
CANONICAL_SIDECAR = GameAIFrozenComparisonSidecar()
CANONICAL_LOCK = RLock()
EXPERIENCE = InteractionHistory()


class BridgeHandler(BaseHTTPRequestHandler):
    server_version = "RDLGameAIRuntime/0.3"

    def do_GET(self) -> None:
        if self.path == "/v1/experience-snapshot":
            with CANONICAL_LOCK:
                snapshot = EXPERIENCE.snapshot()
            self._send_json(200, snapshot)
            return
        if self.path == "/health":
            self._send_json(200, {"ok": True, "service": "rdl-gameai-runtime"})
            return
        if self.path == "/v1/canonical-snapshot":
            with CANONICAL_LOCK:
                snapshot = CANONICAL_SIDECAR.snapshot()
            self._send_json(200, snapshot)
            return
        self._send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if self.path == "/v1/interaction-result":
            try:
                payload = self._read_json()
                with CANONICAL_LOCK:
                    record = EXPERIENCE.record_result(payload)
            except (ValueError, ObservationError) as exc:
                self._send_json(422, {"error": "invalid_interaction_result", "detail": str(exc)})
                return
            self._send_json(200, {"accepted": True, "record": record})
            return
        if self.path == "/v1/assessment-review":
            try:
                payload = self._read_json()
                with CANONICAL_LOCK:
                    result = CANONICAL_SIDECAR.assessments.review(payload)
            except (ValueError, ObservationError) as exc:
                self._send_json(422, {"error": "invalid_review", "detail": str(exc)})
                return
            self._send_json(200, result)
            return
        if self.path != "/v1/observe":
            self._send_json(404, {"error": "not_found"})
            return

        try:
            packet = self._read_json()
            response = decide_action(packet)
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid_json"})
            return
        except ObservationError as exc:
            self._send_json(422, {"error": "invalid_observation", "detail": str(exc)})
            return

        # Canonical v2.3 observation remains diagnostic-only. Capture occurs
        # only after the existing action path accepts the packet, and neither
        # RIB_B acquisition nor frozen M_B/F/F'/E can alter the action response.
        with CANONICAL_LOCK:
            CANONICAL_SIDECAR.capture(packet)
            try:
                EXPERIENCE.register_decision(packet, response)
            except HistoryError as exc:
                self.log_message("history admission rejected: %s", str(exc))
        self._send_json(200, response)

    def log_message(self, format: str, *args: Any) -> None:
        print("%s - %s" % (self.address_string(), format % args))

    def _read_json(self) -> dict[str, Any]:
        raw_length = self.headers.get("Content-Length", "0")
        length = int(raw_length)
        body = self.rfile.read(length)
        decoded = body.decode("utf-8")
        data = json.loads(decoded)
        if not isinstance(data, dict):
            raise ObservationError("request body must be a JSON object")
        return data

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def run(host: str = DEFAULT_HOST, port: int = DEFAULT_PORT) -> None:
    server = ThreadingHTTPServer((host, port), BridgeHandler)
    print("RDL GameAI Runtime listening on http://%s:%d" % (host, port))
    server.serve_forever()


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the RDL GameAI Runtime bridge.")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", default=DEFAULT_PORT, type=int)
    args = parser.parse_args()
    run(args.host, args.port)


if __name__ == "__main__":
    main()
