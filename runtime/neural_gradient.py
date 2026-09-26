"""Finite NERV-1/2 replay only. No coordinator, action, or canonical hooks."""
from copy import deepcopy
from dataclasses import asdict, dataclass
import hashlib
import json

from .outcome_bias import GRADIENT_SCHEMA

RULE = "nerv-perceived-gradient-v1"
PREVIEW_SCHEMA = "nerv-shadow-bias-preview-v1"
RELATIONS = ("acquisition", "return", "injury", "reward_value")
BANDS = ("ZERO", "WEAK", "MEDIUM", "STRONG")


class NeuralInputError(ValueError):
    pass


def _require(ok, reason):
    if not ok:
        raise NeuralInputError(reason)


def _id(value):
    return isinstance(value, str) and bool(value.strip()) and len(value) <= 128


def _hash(value):
    try:
        encoded = json.dumps(value, sort_keys=True, allow_nan=False, separators=(",", ":"))
    except (ValueError, TypeError) as exc:
        raise NeuralInputError("non_json_or_nonfinite_input") from exc
    return hashlib.sha256(encoded.encode()).hexdigest()


@dataclass(frozen=True)
class NeuralParameter:
    agent_id: str
    parameter_id: str
    revision: int
    error_sensitivity: int
    reward_threshold: int

    def __post_init__(self):
        _require(_id(self.agent_id) and _id(self.parameter_id), "invalid_parameter_identity")
        _require(type(self.revision) is int and self.revision == 1, "invalid_revision")
        _require(type(self.error_sensitivity) is int and self.error_sensitivity in (1, 2, 3), "invalid_sensitivity")
        _require(type(self.reward_threshold) is int and self.reward_threshold in (0, 1, 2, 3), "invalid_threshold")

    @classmethod
    def parse(cls, value):
        if isinstance(value, cls):
            return value
        _require(isinstance(value, dict) and set(value) == set(cls.__dataclass_fields__), "invalid_parameter_fields")
        return cls(**value)


def _raw(record):
    fields = {"gradient_id", "schema", "agent_id", "source_experience_id", "source_world_event_ids",
              "context_signature", "outcome_facts", "dimensions", "formation_rule", "authority"}
    _require(isinstance(record, dict) and set(record) == fields and record["schema"] == GRADIENT_SCHEMA, "invalid_raw_schema")
    _require(all(_id(record[k]) for k in ("gradient_id", "agent_id", "source_experience_id")), "invalid_raw_identity")
    events = record["source_world_event_ids"]
    _require(isinstance(events, list) and 1 <= len(events) <= 128 and all(_id(x) for x in events), "invalid_event_provenance")
    _require(len(set(events)) == len(events), "duplicate_event")
    _require(isinstance(record["context_signature"], dict) and isinstance(record["outcome_facts"], dict), "invalid_provenance")
    dims = record["dimensions"]
    _require(isinstance(dims, list) and len(dims) == 4, "invalid_dimensions")
    seen = {}
    for d in dims:
        _require(isinstance(d, dict) and set(d) == {"relation", "direction", "magnitude", "magnitude_band"}, "invalid_dimension_fields")
        _require(isinstance(d["relation"], str) and d["relation"] in RELATIONS and d["relation"] not in seen, "invalid_or_duplicate_relation")
        m = d["magnitude"]
        _require(type(m) is int and m in range(4), "invalid_magnitude")
        _require(d["magnitude_band"] == BANDS[m], "band_mismatch")
        # Zero retains the supplied raw direction; filtered nonzero becomes neutral.
        _require(d["direction"] in ("positive", "negative", "neutral") and (m == 0 or d["direction"] != "neutral"), "invalid_direction")
        seen[d["relation"]] = deepcopy(d)
    result = deepcopy(record)
    result["dimensions"] = [seen[k] for k in RELATIONS]
    _hash(result)
    return result


def _snapshot(snapshot):
    _require(isinstance(snapshot, dict) and set(snapshot) == {"run_id", "gradients"} and _id(snapshot["run_id"]), "invalid_run_snapshot")
    raw = snapshot["gradients"]
    _require(isinstance(raw, dict) and raw.get("schema") == GRADIENT_SCHEMA, "invalid_snapshot_schema")
    records = raw.get("records")
    _require(isinstance(records, list) and len(records) <= 128, "snapshot_budget")
    by_id = {}
    for record in records:
        validated = _raw(record)
        key = validated["gradient_id"]
        _require(key not in by_id, "duplicate_gradient_id")
        by_id[key] = validated
    return by_id


def _request(request, run_id, records, parameter):
    _require(isinstance(request, dict) and set(request) == {"run_id", "agent_id", "source_gradient_id", "rule_version"}, "invalid_request")
    _require(request["run_id"] == run_id and request["rule_version"] == RULE, "run_or_rule_mismatch")
    _require(_id(request["source_gradient_id"]) and request["source_gradient_id"] in records, "unknown_gradient")
    raw = records[request["source_gradient_id"]]
    _require(request["agent_id"] == raw["agent_id"] == parameter.agent_id, "agent_mismatch")
    return raw


def _project(raw, parameter, run_id):
    dimensions = []
    for d in raw["dimensions"]:
        m = d["magnitude"]
        reasons = []
        if m == 0:
            reasons.append("raw_zero")
        else:
            if m < {1: 3, 2: 2, 3: 1}[parameter.error_sensitivity]:
                reasons.append("sensitivity_filtered")
            if d["relation"] == "reward_value" and d["direction"] == "positive" and m < parameter.reward_threshold:
                reasons.append("reward_below_threshold")
        filtered = m > 0 and bool(reasons)
        magnitude = 0 if filtered else m
        dimensions.append({"relation": d["relation"], "raw": deepcopy(d),
                           "direction": "neutral" if filtered else d["direction"],
                           "magnitude": magnitude, "magnitude_band": BANDS[magnitude], "reasons": reasons})
    record = {"schema": RULE, "rule_version": RULE, "run_id": run_id, "agent_id": parameter.agent_id,
              "source_gradient_id": raw["gradient_id"], "source_experience_id": raw["source_experience_id"],
              "source_world_event_ids": deepcopy(raw["source_world_event_ids"]), "raw_record": deepcopy(raw),
              "parameter": asdict(parameter), "dimensions": dimensions,
              "authority": "GameAI-local-perceived-gradient; not-prediction-error-E-H-or-action"}
    return dict(record, projection_id=_hash(record))


def project_perceived_gradient(raw_snapshot, request, parameter):
    parameter = NeuralParameter.parse(parameter)
    records = _snapshot(raw_snapshot)
    raw = _request(request, raw_snapshot["run_id"], records, parameter)
    return _project(raw, parameter, raw_snapshot["run_id"])


def preview_neural_bias(perceived):
    _require(isinstance(perceived, dict) and perceived.get("schema") == RULE, "invalid_perceived_schema")
    _require(all(k in perceived for k in ("raw_record", "parameter", "run_id")), "missing_perceived_provenance")
    _require(_id(perceived["run_id"]), "invalid_run")
    raw = _raw(perceived["raw_record"])
    parameter = NeuralParameter.parse(perceived["parameter"])
    _require(raw["agent_id"] == parameter.agent_id, "agent_mismatch")
    _require(perceived == _project(raw, parameter, perceived["run_id"]), "changed_perceived_record")
    biases = []
    for d in perceived["dimensions"]:
        if d["magnitude"] == 0:
            continue
        record = {"schema": PREVIEW_SCHEMA, "agent_id": parameter.agent_id,
                  "source_projection_id": perceived["projection_id"], "source_gradient_id": raw["gradient_id"],
                  "source_experience_id": raw["source_experience_id"], "source_world_event_ids": deepcopy(raw["source_world_event_ids"]),
                  "relation": d["relation"], "direction": d["direction"], "strength": d["magnitude_band"], "magnitude": d["magnitude"],
                  "authority": "shadow-preview-only; not-LocalBiasStore-Sleep-candidate-or-action"}
        biases.append(dict(record, preview_id=_hash(record)))
    return {"schema": PREVIEW_SCHEMA, "source_projection_id": perceived["projection_id"], "biases": biases}


def replay_neural_gradients(raw_snapshot, parameters, queries):
    """One fixed parameter per agent per run; independent runs compare alternatives."""
    _require(isinstance(parameters, list) and len(parameters) <= 16, "parameter_budget")
    _require(isinstance(queries, list) and len(queries) <= 64, "query_budget")
    records = _snapshot(raw_snapshot)
    registry, agents = {}, set()
    for value in parameters:
        p = NeuralParameter.parse(value)
        _require(p.parameter_id not in registry and p.agent_id not in agents, "parameter_reassignment")
        registry[p.parameter_id] = p
        agents.add(p.agent_id)
    validated = []
    for q in queries:
        _require(isinstance(q, dict) and set(q) == {"parameter_id", "request"}, "invalid_query")
        _require(_id(q["parameter_id"]) and q["parameter_id"] in registry, "unknown_parameter")
        p = registry[q["parameter_id"]]
        raw = _request(q["request"], raw_snapshot["run_id"], records, p)
        validated.append((raw, p))
    # All validation precedes producing results; no state or partial writes exist.
    result = []
    for raw, p in validated:
        projected = _project(raw, p, raw_snapshot["run_id"])
        result.append({"perceived": projected, "preview": preview_neural_bias(projected)})
    return result
