"""Explicit Luanti consequence admission into existing local learning stores."""

from copy import deepcopy
from typing import Any

from .functions.local_bias_deep_similarity import (
    LocalBiasDeepSimilarityError,
    build_local_bias_deep_shadow,
)
from .functions.local_bias_profile import LocalBiasProfileError, build_local_bias_profiles
from .functions.local_bias_t1_projection import (
    LocalBiasT1ProjectionError,
    project_local_bias_candidate,
)
from .outcome_bias import LocalBiasStore, OutcomeBiasError, OutcomeGradientStore
from .territory_experience import TerritoryExperienceError, TerritoryExperienceStore


class LuantiOutcomeError(ValueError):
    pass


class LuantiOutcomeCoordinator:
    """Adapt one physical Luanti event without adding action or canonical authority."""

    def __init__(self) -> None:
        self.experiences = TerritoryExperienceStore()
        self.gradients = OutcomeGradientStore()
        self.biases = LocalBiasStore()
        self._sleep_results: dict[str, dict[str, Any]] = {}

    def record(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise LuantiOutcomeError("payload must be an object")
        event = payload.get("event")
        outcome_facts = payload.get("outcome_facts")
        if not isinstance(event, dict) or not isinstance(outcome_facts, dict):
            raise LuantiOutcomeError("event and outcome_facts must be objects")
        try:
            experience = self.experiences.record_direct(event)
            if experience is None:
                raise LuantiOutcomeError("Experience capacity reached")
            gradient = self.gradients.form(experience, outcome_facts)
            if gradient is None:
                raise LuantiOutcomeError("Outcome Gradient capacity reached")
            biases = self.biases.form(gradient)
        except (TerritoryExperienceError, OutcomeBiasError) as exc:
            raise LuantiOutcomeError(str(exc)) from exc
        return {
            "accepted": True,
            "experience": experience,
            "gradient": gradient,
            "biases": biases,
            "authority": "GameAI-local-learning-result; not-action-canonical-H-M_B-or-T1",
        }

    def consolidate(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise LuantiOutcomeError("payload must be an object")
        agent_id = payload.get("agent_id")
        sleep_cycle = payload.get("sleep_cycle")
        formation_tick = payload.get("formation_tick")
        if not isinstance(agent_id, str) or not agent_id:
            raise LuantiOutcomeError("agent_id must be non-empty")
        try:
            projection = self.biases.sleep_projection(agent_id)
            profiles = build_local_bias_profiles(projection)
            result = build_local_bias_deep_shadow(
                profiles, sleep_cycle=sleep_cycle, formation_tick=formation_tick
            )
        except (OutcomeBiasError, LocalBiasProfileError, LocalBiasDeepSimilarityError) as exc:
            raise LuantiOutcomeError(str(exc)) from exc
        existing = self._sleep_results.get(result["deep_similarity_id"])
        if existing is not None and existing != result:
            raise LuantiOutcomeError("Sleep result replay changed frozen provenance")
        self._sleep_results[result["deep_similarity_id"]] = deepcopy(result)
        return deepcopy(result)

    def t1_cutover(self, canonical, payload: dict[str, Any]) -> dict[str, Any]:
        """Explicitly inspect and activate one agent-owned Sleep candidate."""
        if not isinstance(payload, dict):
            raise LuantiOutcomeError("payload must be an object")
        assessment_id = payload.get("assessment_id")
        agent_id = payload.get("agent_id")
        deep_similarity_id = payload.get("deep_similarity_id")
        candidate_id = payload.get("candidate_id")
        reviewer = payload.get("reviewer")
        basis = payload.get("basis")
        evidence = payload.get("evidence")
        for field, value in (("assessment_id", assessment_id), ("agent_id", agent_id),
                             ("deep_similarity_id", deep_similarity_id),
                             ("candidate_id", candidate_id), ("reviewer", reviewer),
                             ("basis", basis), ("evidence", evidence)):
            if not isinstance(value, str) or not value:
                raise LuantiOutcomeError(f"{field} must be non-empty")
        if payload.get("candidate_disposition") != "RETAIN":
            raise LuantiOutcomeError("L7 requires explicit CandidateRelation RETAIN")
        if payload.get("experience_disposition") != "DEFER":
            raise LuantiOutcomeError("L7 requires explicit Experience DEFER")
        sleep_result = self._sleep_results.get(deep_similarity_id)
        if sleep_result is None:
            raise LuantiOutcomeError("unknown deep_similarity_id")
        if sleep_result.get("agent_id") != agent_id:
            raise LuantiOutcomeError("Sleep result belongs to a different agent")
        candidate = sleep_result.get("candidate")
        if not isinstance(candidate, dict):
            raise LuantiOutcomeError("selected Sleep result has no candidate")
        if candidate.get("candidate_id") != candidate_id:
            raise LuantiOutcomeError("candidate_id does not match selected Sleep result")
        if candidate.get("agent_id") != agent_id:
            raise LuantiOutcomeError("candidate belongs to a different agent")
        try:
            projected = project_local_bias_candidate(candidate)
            source_ids = set(candidate["source_experience_ids"])
            experiences = [
                record for record in self.experiences.snapshot()["records"]
                if record.get("agent_id") == agent_id and record.get("record_id") in source_ids
            ]
            if {record["record_id"] for record in experiences} != source_ids:
                raise LuantiOutcomeError("candidate Experience provenance is incomplete")
            bundle = canonical.expand_t1_materials(
                assessment_id=assessment_id,
                candidates=projected,
                experiences=experiences,
            )
            dispositions = {
                "current_M_B": "RETAIN",
                "CandidateRelation": "RETAIN",
                "Experience": "DEFER",
                "RIB_B": "RETAIN",
                "RIB_B_prime": "RETAIN",
                "unresolved_residual": "DEFER",
            }
            selection = canonical.inspect_t1_materials(
                bundle_id=bundle["bundle_id"],
                payload={
                    "expected_revision": 0,
                    "reviewer": reviewer,
                    "materials": [{
                        "material_id": item["material_id"],
                        "disposition": dispositions[item["kind"]],
                        "basis": f"{basis}: {item['kind']}",
                        "evidence": evidence,
                    } for item in bundle["materials"]],
                },
            )
            artifact = canonical.reconstruct_t1(bundle_id=bundle["bundle_id"])
            cutover = canonical.cutover_reentry(
                artifact_id=artifact["artifact_id"],
                expected_active_model_ref=artifact["parent_model_ref"],
                operator=reviewer,
                basis=basis,
                evidence=evidence,
            )
        except (ValueError, LocalBiasT1ProjectionError) as exc:
            raise LuantiOutcomeError(str(exc)) from exc
        return {
            "agent_id": agent_id,
            "deep_similarity_id": deep_similarity_id,
            "candidate_id": candidate_id,
            "projected_candidates": deepcopy(projected),
            "bundle": bundle,
            "selection": selection,
            "artifact": artifact,
            "cutover": cutover,
            "authority": "explicit-agent-scoped-L7-cycle-record; not-game-action-authority",
        }

    def snapshot(self) -> dict[str, Any]:
        return {
            "schema": "luanti-outcome-learning-snapshot-v1",
            "experiences": self.experiences.snapshot(),
            "gradients": self.gradients.snapshot(),
            "biases": self.biases.snapshot(),
            "sleep_results": deepcopy(list(self._sleep_results.values())),
            "authority": "read-only-local-learning; not-action-or-canonical-authority",
        }
