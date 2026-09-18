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
from .history_policy import HistoryInfluencePolicy
from .life_policy import (
    BaseFoodLifePolicy,
    parse_cue_responses,
    parse_life_profiles,
    parse_novelty_responses,
    parse_threat_profiles,
)
from .sensitivity import parse_retry_profiles
from .rest_policy import RestTrajectoryPolicy
from .v23_food_admission import (
    FoodAdmissionError,
    FoodNeedShadowComparisonSidecar,
    food_shadow_boundary_for_packet,
)


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
CANONICAL_SIDECAR = GameAIFrozenComparisonSidecar()
CANONICAL_LOCK = RLock()
EXPERIENCE = InteractionHistory()


class BridgeHandler(BaseHTTPRequestHandler):
    server_version = "RDLGameAIRuntime/0.3"

    def do_GET(self) -> None:
        if self.path == "/v1/rest-snapshot":
            policy = getattr(self.server, "rest_policy", None)
            if policy is None:
                self._send_json(404, {"error": "rest_trajectory_disabled"})
                return
            with CANONICAL_LOCK:
                snapshot = policy.snapshot()
            self._send_json(200, snapshot)
            return
        if self.path == "/v1/life-snapshot":
            policy = getattr(self.server, "life_policy", None)
            if policy is None:
                self._send_json(404, {"error": "base_food_life_disabled"})
                return
            with CANONICAL_LOCK:
                snapshot = policy.snapshot()
            self._send_json(200, snapshot)
            return
        if self.path == "/v1/food-mb-shadow":
            sidecar = getattr(self.server, "food_mb_shadow", None)
            if sidecar is None:
                self._send_json(404, {"error": "food_mb_shadow_disabled"})
                return
            with self.server.food_mb_shadow_lock:
                snapshot = sidecar.snapshot()
            self._send_json(200, snapshot)
            return
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
        if self.path == "/v1/life-result":
            policy = getattr(self.server, "life_policy", None)
            if policy is None:
                self._send_json(404, {"error": "base_food_life_disabled"})
                return
            try:
                payload = self._read_json()
                with CANONICAL_LOCK:
                    record = policy.record_result(payload)
            except (ValueError, ObservationError) as exc:
                self._send_json(422, {"error": "invalid_life_result", "detail": str(exc)})
                return
            self._send_json(200, {"accepted": True, "record": record})
            return
        if self.path in ("/v1/food-mb-shadow/open", "/v1/food-mb-shadow/compare"):
            self._handle_food_mb_shadow()
            return
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
            with CANONICAL_LOCK:
                life_policy = getattr(self.server, "life_policy", None)
                rest_policy = getattr(self.server, "rest_policy", None)
                history_policy = getattr(self.server, "history_policy", None)
                if rest_policy:
                    response = rest_policy.decide(packet)
                elif life_policy:
                    response = life_policy.decide(packet)
                else:
                    response = history_policy.decide(packet, EXPERIENCE) if history_policy else decide_action(packet)
                CANONICAL_SIDECAR.capture(packet)
                try:
                    EXPERIENCE.register_decision(packet, response)
                except HistoryError as exc:
                    self.log_message("history admission rejected: %s", str(exc))
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid_json"})
            return
        except ObservationError as exc:
            self._send_json(422, {"error": "invalid_observation", "detail": str(exc)})
            return

        self._send_json(200, response)

    def _handle_food_mb_shadow(self) -> None:
        sidecar = getattr(self.server, "food_mb_shadow", None)
        if sidecar is None:
            self._send_json(404, {"error": "food_mb_shadow_disabled"})
            return
        try:
            payload = self._read_json()
            with self.server.food_mb_shadow_lock:
                if self.path.endswith("/open"):
                    boundary = food_shadow_boundary_for_packet(payload)
                    window_id = sidecar.open_window(payload, boundary)
                    result = {"window_id": window_id, "window": sidecar.snapshot()["windows"][window_id]}
                else:
                    window_id = payload.get("window_id")
                    packet = payload.get("packet")
                    if not isinstance(window_id, str) or not window_id:
                        raise FoodAdmissionError("window_id must be a non-empty string")
                    if not isinstance(packet, dict):
                        raise FoodAdmissionError("packet must be an object")
                    mismatch = sidecar.compare_later(window_id, packet)
                    result = {
                        "window_id": window_id,
                        "E": mismatch.to_json(),
                        "window": sidecar.snapshot()["windows"][window_id],
                    }
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid_json"})
            return
        except (ValueError, FoodAdmissionError) as exc:
            self._send_json(422, {"error": "invalid_food_mb_shadow_request", "detail": str(exc)})
            return
        self._send_json(200, result)

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


def run(
    host: str = DEFAULT_HOST,
    port: int = DEFAULT_PORT,
    history_influence: bool = False,
    retry_profiles=None,
    food_mb_shadow: bool = False,
    base_food_life: bool = False,
    cue_responses=None,
    threat_profiles=None,
    novelty_responses=None,
    life_profiles=None,
    rest_trajectory: bool = False,
    rest_rho_candidates: bool = False,
) -> None:
    if retry_profiles and not history_influence:
        raise ValueError("retry profiles require history influence")
    if food_mb_shadow and host not in ("127.0.0.1", "localhost", "::1"):
        raise ValueError("FoodNeed M_B shadow experiment requires a loopback host")
    if base_food_life and history_influence:
        raise ValueError("Base-Food life policy and history influence are separate opt-in policies")
    if rest_trajectory and (base_food_life or history_influence):
        raise ValueError("Rest trajectory is an isolated opt-in policy")
    if rest_rho_candidates and not rest_trajectory:
        raise ValueError("rho Rest candidates require the Rest trajectory policy")
    if cue_responses and not base_food_life:
        raise ValueError("Base-Food cue responses require the life policy")
    if threat_profiles and not base_food_life:
        raise ValueError("Base-Food threat profiles require the life policy")
    if novelty_responses and not base_food_life:
        raise ValueError("Base-Food novelty responses require the life policy")
    if life_profiles and not base_food_life:
        raise ValueError("Base-Food extreme profiles require the life policy")
    policy = HistoryInfluencePolicy(profiles=retry_profiles) if history_influence else None
    server = ThreadingHTTPServer((host, port), BridgeHandler)
    server.history_policy = policy
    server.life_policy = BaseFoodLifePolicy(
        cue_responses=cue_responses,
        threat_profiles=threat_profiles,
        novelty_responses=novelty_responses,
        life_profiles=life_profiles,
    ) if base_food_life else None
    server.rest_policy = RestTrajectoryPolicy(
        use_rho_candidates=rest_rho_candidates
    ) if rest_trajectory else None
    server.food_mb_shadow = FoodNeedShadowComparisonSidecar() if food_mb_shadow else None
    server.food_mb_shadow_lock = RLock()
    print("RDL GameAI Runtime listening on http://%s:%d" % (host, port))
    server.serve_forever()


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the RDL GameAI Runtime bridge.")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", default=DEFAULT_PORT, type=int)
    parser.add_argument("--history-influence", action="store_true", help="Enable finite history retry experiment")
    parser.add_argument("--retry-profile", action="append", default=[], metavar="AGENT=PROFILE",
                        help="Fixed retry tendency: short, standard, or long; requires --history-influence")
    parser.add_argument("--food-mb-shadow", action="store_true",
                        help="Enable loopback-only FoodNeed M_B shadow endpoints")
    parser.add_argument("--base-food-life", action="store_true",
                        help="Enable the assisted Base-Food Goal/Trajectory policy")
    parser.add_argument("--base-food-cue-response", action="append", default=[], metavar="AGENT=RESPONSE",
                        help="NPC cue disposition: follow or ignore; requires --base-food-life")
    parser.add_argument("--base-food-threat-profile", action="append", default=[], metavar="AGENT=PROFILE",
                        help="Threat interruption profile: cautious, standard, or steadfast")
    parser.add_argument("--base-food-novelty-response", action="append", default=[], metavar="AGENT=RESPONSE",
                        help="Novelty response: ignore, inspect, or divert")
    parser.add_argument("--base-food-extreme-profile", action="append", default=[], metavar="AGENT=PROFILE",
                        help="Tuning preset: trajectory_locked or context_switching")
    parser.add_argument("--rest-trajectory", action="store_true",
                        help="Enable isolated Rest Goal/Trajectory policy")
    parser.add_argument("--rest-rho-candidates", action="store_true",
                        help="Describe Rest candidates through the configured rho_rest sidecar")
    args = parser.parse_args()
    try:
        profiles = parse_retry_profiles(args.retry_profile)
        if profiles and not args.history_influence:
            raise ValueError("--retry-profile requires --history-influence")
        if args.food_mb_shadow and args.host not in ("127.0.0.1", "localhost", "::1"):
            raise ValueError("--food-mb-shadow requires a loopback --host")
        if args.base_food_life and args.history_influence:
            raise ValueError("--base-food-life cannot be combined with --history-influence")
        if args.rest_trajectory and (args.base_food_life or args.history_influence):
            raise ValueError("--rest-trajectory cannot be combined with other action policies")
        if args.rest_rho_candidates and not args.rest_trajectory:
            raise ValueError("--rest-rho-candidates requires --rest-trajectory")
        cue_responses = parse_cue_responses(args.base_food_cue_response)
        if cue_responses and not args.base_food_life:
            raise ValueError("--base-food-cue-response requires --base-food-life")
        threat_profiles = parse_threat_profiles(args.base_food_threat_profile)
        if threat_profiles and not args.base_food_life:
            raise ValueError("--base-food-threat-profile requires --base-food-life")
        novelty_responses = parse_novelty_responses(args.base_food_novelty_response)
        if novelty_responses and not args.base_food_life:
            raise ValueError("--base-food-novelty-response requires --base-food-life")
        life_profiles = parse_life_profiles(args.base_food_extreme_profile)
        if life_profiles and not args.base_food_life:
            raise ValueError("--base-food-extreme-profile requires --base-food-life")
    except ValueError as exc:
        parser.error(str(exc))
    run(args.host, args.port, args.history_influence, profiles, args.food_mb_shadow,
        args.base_food_life, cue_responses, threat_profiles, novelty_responses, life_profiles,
        args.rest_trajectory, args.rest_rho_candidates)


if __name__ == "__main__":
    main()
