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
from .safety_policy import SafetyTrajectoryPolicy
from .food_safety_policy import FoodSafetyCoordinator
from .food_rest_policy import FoodRestCoordinator
from .rescue_policy import RescueTrajectoryPolicy
from .sleep_consolidation import SleepConsolidationCoordinator
from .functions.experience_profile import build_experience_profile
from .mechanisms.fast_retrieval import FastRetrievalStore
from .luanti_outcome import LuantiOutcomeCoordinator, LuantiOutcomeError
from .sensory_observation import SensoryObservationStore, split_sensory_extension
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
        if self.path == "/v1/sensory-observation-snapshot":
            store = getattr(self.server, "sensory_observation", None)
            if store is None:
                self._send_json(404, {"error": "sensory_observation_disabled"})
                return
            with CANONICAL_LOCK:
                snapshot = store.snapshot()
            self._send_json(200, snapshot)
            return
        if self.path == "/v1/luanti-outcome-snapshot":
            coordinator = getattr(self.server, "luanti_outcome", None)
            if coordinator is None:
                self._send_json(404, {"error": "luanti_outcome_learning_disabled"})
                return
            with CANONICAL_LOCK:
                snapshot = coordinator.snapshot()
            self._send_json(200, snapshot)
            return
        if self.path == "/v1/fast-retrieval-snapshot":
            store = getattr(self.server, "fast_retrieval", None)
            if store is None:
                self._send_json(404, {"error": "fast_retrieval_disabled"})
                return
            with CANONICAL_LOCK:
                snapshot = store.snapshot()
            self._send_json(200, snapshot)
            return
        if self.path == "/v1/sleep-consolidation-snapshot":
            coordinator = getattr(self.server, "sleep_consolidation", None)
            if coordinator is None:
                self._send_json(404, {"error": "sleep_consolidation_disabled"})
                return
            with CANONICAL_LOCK:
                snapshot = coordinator.snapshot()
            self._send_json(200, snapshot)
            return
        if self.path == "/v1/rescue-snapshot":
            policy = getattr(self.server, "rescue_policy", None)
            if policy is None:
                self._send_json(404, {"error": "rescue_trajectory_disabled"})
                return
            with CANONICAL_LOCK:
                snapshot = policy.snapshot()
            self._send_json(200, snapshot)
            return
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
        if self.path == "/v1/luanti-territory-result":
            coordinator = getattr(self.server, "luanti_outcome", None)
            if coordinator is None:
                self._send_json(404, {"error": "luanti_outcome_learning_disabled"})
                return
            try:
                payload = self._read_json()
                with CANONICAL_LOCK:
                    result = coordinator.record(payload)
            except (ValueError, ObservationError, LuantiOutcomeError) as exc:
                self._send_json(422, {"error": "invalid_luanti_territory_result", "detail": str(exc)})
                return
            self._send_json(200, result)
            return
        if self.path == "/v1/luanti-bias-sleep":
            coordinator = getattr(self.server, "luanti_outcome", None)
            if coordinator is None:
                self._send_json(404, {"error": "luanti_outcome_learning_disabled"})
                return
            try:
                payload = self._read_json()
                with CANONICAL_LOCK:
                    result = coordinator.consolidate(payload)
            except (ValueError, ObservationError, LuantiOutcomeError) as exc:
                self._send_json(422, {"error": "invalid_luanti_bias_sleep", "detail": str(exc)})
                return
            self._send_json(200, {"accepted": True, "result": result})
            return
        if self.path == "/v1/luanti-t1-cutover":
            coordinator = getattr(self.server, "luanti_outcome", None)
            if coordinator is None:
                self._send_json(404, {"error": "luanti_outcome_learning_disabled"})
                return
            try:
                payload = self._read_json()
                with CANONICAL_LOCK:
                    result = coordinator.t1_cutover(CANONICAL_SIDECAR, payload)
            except (ValueError, ObservationError, LuantiOutcomeError) as exc:
                self._send_json(422, {"error": "invalid_luanti_t1_cutover", "detail": str(exc)})
                return
            self._send_json(200, {"accepted": True, "result": result})
            return
        if self.path == "/v1/sleep-result":
            coordinator = getattr(self.server, "sleep_consolidation", None)
            if coordinator is None:
                self._send_json(404, {"error": "sleep_consolidation_disabled"})
                return
            try:
                payload = self._read_json()
                with CANONICAL_LOCK:
                    record = coordinator.record_result(payload, EXPERIENCE.snapshot())
            except (ValueError, ObservationError) as exc:
                self._send_json(422, {"error": "invalid_sleep_result", "detail": str(exc)})
                return
            self._send_json(200, {"accepted": True, "record": record})
            return
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
                    fast_retrieval = getattr(self.server, "fast_retrieval", None)
                    if fast_retrieval:
                        history = EXPERIENCE.snapshot()
                        current_profile = build_experience_profile(record)
                        sources = _fast_sources(
                            history, getattr(self.server, "sleep_consolidation", None),
                            record["agent_id"],
                        )
                        fast_retrieval.retrieve(
                            current_profile, sources, query_tick=record["tick"], enabled=True
                        )
            except (ValueError, ObservationError) as exc:
                self._send_json(422, {"error": "invalid_interaction_result", "detail": str(exc)})
                return
            self._send_json(200, {"accepted": True, "record": record})
            return
        if self.path == "/v1/assessment-review":
            try:
                payload = self._read_json()
                with CANONICAL_LOCK:
                    result = CANONICAL_SIDECAR.review_assessment(payload)
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
                packet, _sensory_receipt = split_sensory_extension(
                    packet, getattr(self.server, "sensory_observation", None)
                )
                life_policy = getattr(self.server, "life_policy", None)
                rest_policy = getattr(self.server, "rest_policy", None)
                safety_policy = getattr(self.server, "safety_policy", None)
                rescue_policy = getattr(self.server, "rescue_policy", None)
                history_policy = getattr(self.server, "history_policy", None)
                if rescue_policy:
                    response = rescue_policy.decide(packet)
                elif safety_policy:
                    response = safety_policy.decide(packet)
                elif rest_policy:
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
                sleep_consolidation = getattr(self.server, "sleep_consolidation", None)
                if sleep_consolidation:
                    sleep_consolidation.register_decision(
                        packet, response, EXPERIENCE.snapshot()
                    )
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
    safety_trajectory: bool = False,
    food_safety_life: bool = False,
    food_rest_life: bool = False,
    rescue_trajectory: bool = False,
    sleep_consolidation: bool = False,
    fast_retrieval: bool = False,
    luanti_outcome_learning: bool = False,
    sensory_observation: bool = False,
    sensory_run_id: str = "fixture-run-1",
    sensory_world_epoch: int = 1,
    sensory_profiles=None,
) -> None:
    if retry_profiles and not history_influence:
        raise ValueError("retry profiles require history influence")
    if food_mb_shadow and host not in ("127.0.0.1", "localhost", "::1"):
        raise ValueError("FoodNeed M_B shadow experiment requires a loopback host")
    if base_food_life and history_influence:
        raise ValueError("Base-Food life policy and history influence are separate opt-in policies")
    if rest_trajectory and (base_food_life or history_influence):
        raise ValueError("Rest trajectory is an isolated opt-in policy")
    if safety_trajectory and (base_food_life or history_influence or rest_trajectory):
        raise ValueError("Safety trajectory is an isolated opt-in policy")
    if food_safety_life and (base_food_life or safety_trajectory or rest_trajectory or history_influence):
        raise ValueError("Food-Safety life coordinator is an isolated opt-in policy")
    if food_rest_life and (base_food_life or safety_trajectory or rest_trajectory or food_safety_life or history_influence):
        raise ValueError("Food-Rest life coordinator is an isolated opt-in policy")
    if rescue_trajectory and (base_food_life or safety_trajectory or rest_trajectory or food_safety_life or food_rest_life or history_influence):
        raise ValueError("Rescue trajectory is an isolated opt-in policy")
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
    ) if base_food_life else (
        FoodSafetyCoordinator() if food_safety_life else (
            FoodRestCoordinator() if food_rest_life else None
        )
    )
    server.rest_policy = RestTrajectoryPolicy(
        use_rho_candidates=rest_rho_candidates
    ) if rest_trajectory else None
    server.safety_policy = SafetyTrajectoryPolicy() if safety_trajectory else None
    server.rescue_policy = RescueTrajectoryPolicy() if rescue_trajectory else None
    server.sleep_consolidation = (
        SleepConsolidationCoordinator() if sleep_consolidation else None
    )
    server.fast_retrieval = FastRetrievalStore() if fast_retrieval else None
    server.luanti_outcome = LuantiOutcomeCoordinator() if luanti_outcome_learning else None
    server.sensory_observation = SensoryObservationStore(
        run_id=sensory_run_id, world_epoch=sensory_world_epoch,
        assignments=sensory_profiles,
    ) if sensory_observation else None
    server.food_safety_policy = server.life_policy if food_safety_life else None
    server.food_rest_policy = server.life_policy if food_rest_life else None
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
    parser.add_argument("--safety-trajectory", action="store_true",
                        help="Enable isolated Safety escape trajectory policy")
    parser.add_argument("--food-safety-life", action="store_true",
                        help="Enable finite Food-Safety continuous-life coordinator")
    parser.add_argument("--food-rest-life", action="store_true",
                        help="Enable finite Food-Rest continuous-life coordinator")
    parser.add_argument("--rescue-trajectory", action="store_true",
                        help="Enable finite bounded Rescue approach trajectory")
    parser.add_argument("--sleep-consolidation", action="store_true",
                        help="Enable opt-in S4 Sleep consolidation shadow reporting")
    parser.add_argument("--fast-retrieval", action="store_true",
                        help="Enable opt-in F1 Activity Fast retrieval snapshots")
    parser.add_argument("--luanti-outcome-learning", action="store_true",
                        help="Enable explicit Luanti consequence to Experience/Gradient/Bias admission")
    parser.add_argument("--sensory-observation", action="store_true",
                        help="Enable isolated finite sensory frame validation and snapshots")
    parser.add_argument("--sensory-run-id", default="fixture-run-1",
                        help="Registered run identity for sensory frame admission")
    parser.add_argument("--sensory-world-epoch", default=1, type=int,
                        help="Registered positive World epoch for sensory frame admission")
    parser.add_argument("--sensory-profile", action="append", default=[], metavar="AGENT=PROFILE",
                        help="Registered sensory profile assignment; requires --sensory-observation")
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
        if args.safety_trajectory and (args.base_food_life or args.history_influence or args.rest_trajectory):
            raise ValueError("--safety-trajectory cannot be combined with other action policies")
        if args.food_safety_life and (args.base_food_life or args.safety_trajectory or args.rest_trajectory or args.history_influence):
            raise ValueError("--food-safety-life cannot be combined with other action policies")
        if args.food_rest_life and (args.base_food_life or args.safety_trajectory or args.rest_trajectory or args.food_safety_life or args.history_influence):
            raise ValueError("--food-rest-life cannot be combined with other action policies")
        if args.rescue_trajectory and (args.base_food_life or args.safety_trajectory or args.rest_trajectory or args.food_safety_life or args.food_rest_life or args.history_influence):
            raise ValueError("--rescue-trajectory cannot be combined with other action policies")
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
        if args.sensory_world_epoch < 1:
            raise ValueError("--sensory-world-epoch must be positive")
        sensory_profiles = _parse_sensory_profiles(args.sensory_profile)
        if sensory_profiles and not args.sensory_observation:
            raise ValueError("--sensory-profile requires --sensory-observation")
    except ValueError as exc:
        parser.error(str(exc))
    run(args.host, args.port, args.history_influence, profiles, args.food_mb_shadow,
        args.base_food_life, cue_responses, threat_profiles, novelty_responses, life_profiles,
        args.rest_trajectory, args.rest_rho_candidates, args.safety_trajectory,
        args.food_safety_life, args.food_rest_life, args.rescue_trajectory,
        args.sleep_consolidation, args.fast_retrieval, args.luanti_outcome_learning,
        args.sensory_observation, args.sensory_run_id, args.sensory_world_epoch,
        sensory_profiles or None)


def _parse_sensory_profiles(values):
    known = {
        "fixture-sensor-default", "fixture-local-compact", "fixture-distant-enabled",
        "fixture-audition-enabled", "fixture-audition-compact",
        "fixture-life-sensory", "fixture-life-sensory-compact",
    }
    result = {}
    for item in values:
        if "=" not in item:
            raise ValueError("sensory profile must use AGENT=PROFILE")
        agent_id, profile_id = item.split("=", 1)
        if not agent_id or profile_id not in known:
            raise ValueError("invalid sensory profile assignment")
        result[agent_id] = (profile_id, 1)
    return result


def _fast_sources(history_snapshot: dict[str, Any], sleep_consolidation,
                  agent_id: str) -> list[dict[str, Any]]:
    records = [record for record in history_snapshot["records"]
               if record.get("agent_id") == agent_id][-29:]
    sources = [{
        "source_type": "raw_experience",
        "source_id": record["record_id"],
        "profile": build_experience_profile(record),
    } for record in records]
    if sleep_consolidation is not None:
        for result in sleep_consolidation.snapshot()["results"][-3:]:
            candidate = result.get("candidate")
            if candidate is not None and candidate.get("agent_id") == agent_id:
                sources.append({
                    "source_type": "sleep_candidate",
                    "source_id": candidate["candidate_id"],
                    "candidate": candidate,
                })
    return sources


if __name__ == "__main__":
    main()
