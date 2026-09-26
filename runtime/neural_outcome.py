"""NERV-3 opt-in, process-local admission and neural Sleep input profiles.

No inheritance from the raw coordinator and no Candidate/T1/action entry points.
"""
from copy import deepcopy
from dataclasses import asdict, dataclass, field
import hashlib
import json
from threading import RLock
from types import MappingProxyType

from .neural_gradient import NeuralParameter, NeuralInputError, RULE, project_perceived_gradient
from .outcome_bias import OutcomeGradientStore, OutcomeBiasError, GRADIENT_SCHEMA
from .territory_experience import TerritoryExperienceStore, TerritoryExperienceError

BIAS_SCHEMA = "nerv-local-bias-v1"
MATERIAL_SCHEMA = "nerv-sleep-materials-v1"
PROFILE_SCHEMA = "nerv-local-bias-relation-profile-v1"
LIMITS = {"receipts": 128, "experiences": 128, "gradients": 128, "projections": 128, "biases": 256}


class NeuralAdmissionError(ValueError):
    pass


def _require(ok, reason):
    if not ok:
        raise NeuralAdmissionError(reason)


def _identifier(value):
    return isinstance(value, str) and bool(value.strip()) and len(value) <= 128


def _digest(value):
    try:
        serialized = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    except (TypeError, ValueError) as exc:
        raise NeuralAdmissionError("invalid_json_or_nonfinite") from exc
    return hashlib.sha256(serialized.encode()).hexdigest()


def _validate_projection(projected, run_id, parameter):
    _require(isinstance(projected, dict) and "raw_record" in projected, "invalid_projection")
    raw = projected["raw_record"]
    _require(isinstance(raw, dict), "invalid_projection_source")
    request = {"run_id": run_id, "agent_id": parameter.agent_id,
               "source_gradient_id": raw.get("gradient_id"), "rule_version": RULE}
    try:
        expected = project_perceived_gradient(
            {"run_id": run_id, "gradients": {"schema": GRADIENT_SCHEMA, "records": [raw]}}, request, parameter)
    except NeuralInputError as exc:
        raise NeuralAdmissionError(str(exc)) from exc
    _require(projected == expected, "projection_provenance_mismatch")


def _form_biases(projected):
    """Called only with a validated, coordinator-derived projection."""
    result = []
    for d in projected["dimensions"]:
        if d["magnitude"] == 0:
            continue
        bias = {"schema": BIAS_SCHEMA, "run_id": projected["run_id"], "agent_id": projected["agent_id"],
                "source_gradient_id": projected["source_gradient_id"], "source_projection_id": projected["projection_id"],
                "source_experience_id": projected["source_experience_id"],
                "source_world_event_ids": deepcopy(projected["source_world_event_ids"]),
                "parameter": deepcopy(projected["parameter"]), "rule_version": RULE,
                "context_signature": deepcopy(projected["raw_record"]["context_signature"]),
                "relation": d["relation"], "direction": d["direction"],
                "strength": d["magnitude_band"], "magnitude": d["magnitude"],
                "authority": "neural-origin-local-bias; not-candidate-T1-M_B-or-action"}
        bias["bias_id"] = _digest([BIAS_SCHEMA, projected["run_id"], projected["projection_id"], d["relation"]])
        result.append(bias)
    return result


def compile_neural_sleep_profile(materials):
    """Validate the complete selected agent's materials, without truncation."""
    fields = {"schema", "run_id", "agent_id", "parameter", "projections", "biases"}
    _require(isinstance(materials, dict) and set(materials) == fields and materials["schema"] == MATERIAL_SCHEMA, "invalid_sleep_materials")
    run_id, agent_id = materials["run_id"], materials["agent_id"]
    _require(_identifier(run_id) and _identifier(agent_id), "invalid_sleep_context")
    try:
        parameter = NeuralParameter.parse(materials["parameter"])
    except NeuralInputError as exc:
        raise NeuralAdmissionError(str(exc)) from exc
    _require(parameter.agent_id == agent_id, "sleep_agent_mismatch")
    projections, biases = materials["projections"], materials["biases"]
    _require(isinstance(projections, list) and len(projections) <= 128, "sleep_projection_budget")
    _require(isinstance(biases, list) and len(biases) <= 32, "sleep_bias_budget")
    expected, sources, projection_ids = {}, {}, set()
    for p in projections:
        _validate_projection(p, run_id, parameter)
        _require(p["projection_id"] not in projection_ids and p["source_experience_id"] not in sources, "duplicate_sleep_source")
        projection_ids.add(p["projection_id"])
        sources[p["source_experience_id"]] = p
        for b in _form_biases(p):
            expected[b["bias_id"]] = b
    supplied = {}
    for b in biases:
        _require(isinstance(b, dict) and _identifier(b.get("bias_id")), "invalid_sleep_bias")
        key = b["bias_id"]
        _require(key not in supplied and key in expected and b == expected[key], "sleep_bias_provenance_mismatch")
        supplied[key] = b
    _require(supplied == expected, "incomplete_sleep_materials")
    profiles = []
    for eid, p in sorted(sources.items()):
        relations = sorted((deepcopy(b) for b in supplied.values() if b["source_experience_id"] == eid), key=lambda b: b["relation"])
        if relations:
            body = {"schema": PROFILE_SCHEMA, "run_id": run_id, "agent_id": agent_id,
                    "source_experience_id": eid, "source_projection_id": p["projection_id"],
                    "relations": relations}
            profiles.append(dict(body, profile_id=_digest(body)))
    status = "profiles_available" if profiles else "no_experience" if not projections else (
        "all_relations_filtered" if any(d["raw"]["magnitude"] > 0 for p in projections for d in p["dimensions"]) else "no_nonzero_relations")
    summaries = [{"projection_id": p["projection_id"], "source_gradient_id": p["source_gradient_id"],
                  "source_experience_id": p["source_experience_id"], "source_world_event_ids": deepcopy(p["source_world_event_ids"]),
                  "parameter": deepcopy(p["parameter"]), "rule_version": RULE, "dimensions": deepcopy(p["dimensions"])}
                 for p in sorted(projections, key=lambda p: p["projection_id"])]
    result = {"schema": PROFILE_SCHEMA, "run_id": run_id, "agent_id": agent_id, "status": status,
              "profiles": profiles, "profile_count": len(profiles), "projection_summaries": summaries,
              "authority": "neural-Sleep-input-only; not-DeepSimilarity-Candidate-T1-or-action"}
    return dict(result, profile_set_id=_digest(result))


@dataclass
class _State:
    experiences: TerritoryExperienceStore
    gradients: OutcomeGradientStore
    projections: dict = field(default_factory=dict)
    biases: dict = field(default_factory=dict)
    receipts: dict = field(default_factory=dict)


class NeuralOutcomeCoordinator:
    """Fixed configuration; serialize operations and publish one staged state."""

    def __init__(self, run_id, parameters, *, capacities=None):
        _require(_identifier(run_id), "invalid_run")
        _require(isinstance(parameters, (list, tuple)) and 1 <= len(parameters) <= 16, "parameter_budget")
        registry, identities = {}, set()
        for value in parameters:
            try:
                p = NeuralParameter.parse(value)
            except NeuralInputError as exc:
                raise NeuralAdmissionError(str(exc)) from exc
            _require(p.agent_id not in registry and p.parameter_id not in identities, "parameter_reassignment")
            registry[p.agent_id] = p
            identities.add(p.parameter_id)
        _require(capacities is None or isinstance(capacities, dict), "invalid_capacities")
        limits = dict(LIMITS)
        for name, value in (capacities or {}).items():
            _require(name in limits and type(value) is int and 1 <= value <= limits[name], "invalid_capacity")
            limits[name] = value
        self._run_id = run_id
        self._parameters = MappingProxyType(registry)
        self._limits = MappingProxyType(limits)
        self._lock = RLock()
        self._state = _State(TerritoryExperienceStore(limits["experiences"]), OutcomeGradientStore(limits["gradients"]))

    @property
    def run_id(self):
        return self._run_id

    @property
    def parameters(self):
        return self._parameters

    def record(self, payload):
        _require(isinstance(payload, dict) and set(payload) == {"event", "outcome_facts"}, "invalid_payload_fields")
        payload = deepcopy(payload)
        event = payload["event"]
        _require(isinstance(event, dict) and _identifier(event.get("agent_id")) and _identifier(event.get("event_id")), "invalid_event_identity")
        agent_id = event["agent_id"]
        _require(agent_id in self._parameters, "unassigned_agent")
        identity = (self.run_id, agent_id, event["event_id"])
        fingerprint = _digest(payload)
        with self._lock:
            old = self._state.receipts.get(identity)
            if old:
                _require(old["fingerprint"] == fingerprint, "event_conflict")
                return deepcopy(old["result"])
            _require(len(self._state.receipts) < self._limits["receipts"], "receipt_capacity")
            _require(len(self._state.projections) < self._limits["projections"], "projection_capacity")
            staged = deepcopy(self._state)
            try:
                experience = staged.experiences.record_direct(event)
                _require(experience is not None, "experience_capacity")
                raw = staged.gradients.form(experience, payload["outcome_facts"])
                _require(raw is not None, "gradient_capacity")
                request = {"run_id": self.run_id, "agent_id": agent_id, "source_gradient_id": raw["gradient_id"], "rule_version": RULE}
                projected = project_perceived_gradient({"run_id": self.run_id, "gradients": staged.gradients.snapshot()}, request, self._parameters[agent_id])
                _validate_projection(projected, self.run_id, self._parameters[agent_id])
            except (TerritoryExperienceError, OutcomeBiasError, NeuralInputError) as exc:
                raise NeuralAdmissionError(str(exc)) from exc
            biases = _form_biases(projected)
            _require(len(staged.biases) + len(biases) <= self._limits["biases"], "bias_capacity")
            staged.projections[projected["projection_id"]] = projected
            for b in biases:
                staged.biases[b["bias_id"]] = b
            result = {"accepted": True, "run_id": self.run_id, "agent_id": agent_id,
                      "experience": experience, "gradient": raw, "projection": projected, "biases": biases,
                      "bias_status": "formed" if biases else "no_bias",
                      "authority": "neural-local-admission; not-candidate-T1-canonical-or-action"}
            staged.receipts[identity] = {"fingerprint": fingerprint, "result": deepcopy(result)}
            returned = deepcopy(result)
            self._state = staged
            return returned

    def snapshot(self):
        with self._lock:
            s = self._state
            return deepcopy({"schema": "nerv-outcome-snapshot-v1", "run_id": self.run_id,
                             "parameters": [asdict(p) for _, p in sorted(self._parameters.items())], "capacities": dict(self._limits),
                             "experiences": s.experiences.snapshot(), "gradients": s.gradients.snapshot(),
                             "projections": list(s.projections.values()), "biases": list(s.biases.values()),
                             "receipts": [{"run_id": k[0], "agent_id": k[1], "event_id": k[2], **v} for k, v in s.receipts.items()]})

    def sleep_materials(self, agent_id):
        _require(_identifier(agent_id) and agent_id in self._parameters, "unassigned_agent")
        with self._lock:
            return deepcopy({"schema": MATERIAL_SCHEMA, "run_id": self.run_id, "agent_id": agent_id,
                             "parameter": asdict(self._parameters[agent_id]),
                             "projections": [p for p in self._state.projections.values() if p["agent_id"] == agent_id],
                             "biases": [b for b in self._state.biases.values() if b["agent_id"] == agent_id]})

    def build_sleep_profile(self, agent_id):
        return compile_neural_sleep_profile(self.sleep_materials(agent_id))
