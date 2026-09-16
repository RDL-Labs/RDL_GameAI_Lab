"""Finite, explicit diagnostic review of E; no action authority."""

from copy import deepcopy
import hashlib
import json
import math


class AssessmentError(ValueError):
    pass


class FiniteAssessmentLedger:
    """Keep at most 128 comparisons; never silently discard an unresolved case."""

    def __init__(self, capacity=128):
        self.capacity = capacity
        self.records = {}
        self.capacity_rejections = 0

    def register(self, mismatch):
        identity = [mismatch.context_key, mismatch.model_ref,
                    mismatch.first_section_id, mismatch.later_section_id]
        key = hashlib.sha256(json.dumps(identity).encode()).hexdigest()
        if key in self.records:
            return key
        if len(self.records) >= self.capacity:
            self.capacity_rejections += 1
            return None
        self.records[key] = {
            "assessment_id": key,
            "E": mismatch.to_json(),
            "context": deepcopy(mismatch.context_key),
            "revision": 0,
            "dimensions": {
                name: {"status": "zero" if delta == 0 else "pending", "residual": 0.0}
                for name, delta in mismatch.deltas.items()
            },
            "review": None,
        }
        return key

    def review(self, payload):
        if not isinstance(payload, dict):
            raise AssessmentError("review must be an object")
        key = payload.get("assessment_id")
        if not isinstance(key, str) or key not in self.records:
            raise AssessmentError("unknown assessment_id")
        current = self.records[key]
        if type(payload.get("expected_revision")) is not int or payload["expected_revision"] != current["revision"]:
            raise AssessmentError("expected_revision must match current revision")
        for field in ("reviewer", "basis", "evidence"):
            if not isinstance(payload.get(field), str) or not payload[field].strip():
                raise AssessmentError(f"{field} must be a non-empty string")
        supplied = payload.get("dimensions")
        if not isinstance(supplied, dict) or set(supplied) != set(current["dimensions"]):
            raise AssessmentError("review must cover exactly the selected dimensions")
        dimensions = {}
        allowed = {"zero", "pending", "resolved", "ordinary_temporal_change",
                   "boundary_coverage_change", "unresolved"}
        for name, item in supplied.items():
            if not isinstance(item, dict) or not isinstance(item.get("status"), str) or item["status"] not in allowed:
                raise AssessmentError("invalid dimension status")
            status = item["status"]
            delta = current["E"]["deltas"][name]
            residual = item.get("residual", 0.0)
            if type(residual) not in (int, float) or not math.isfinite(residual):
                raise AssessmentError("residual must be finite")
            if not 0 <= residual <= abs(delta):
                raise AssessmentError("residual must lie between zero and abs(E)")
            if (status == "zero") != (delta == 0):
                raise AssessmentError("zero status must match zero E")
            if (status == "unresolved") != (residual > 0):
                raise AssessmentError("only unresolved dimensions have positive residual")
            dimensions[name] = {"status": status, "residual": float(residual)}
        # Commit only after the entire review is valid.
        updated = deepcopy(current)
        updated["dimensions"] = dimensions
        updated["revision"] += 1
        updated["review"] = {field: payload[field] for field in ("reviewer", "basis", "evidence")}
        self.records[key] = updated
        return self._export(updated)

    def _export(self, record):
        result = deepcopy(record)
        vector = {name: item["residual"] for name, item in record["dimensions"].items()
                  if item["status"] == "unresolved"}
        result.update(H_vec=vector, H=math.hypot(*vector.values()),
                      norm="GameAI-local L2", scope="single-comparison residual",
                      reviewed=record["review"] is not None)
        return result

    def snapshot(self):
        return {"records": [self._export(record) for record in self.records.values()],
                "retained_H": self._retained_h(),
                "capacity": self.capacity, "capacity_rejections": self.capacity_rejections,
                "retention": "process lifetime; capacity rejects new cases; no eviction",
                "authority": "diagnostic-only"}

    def _retained_h(self):
        """Recompute from latest revisions so replay/re-review cannot add twice."""
        groups = {}
        for record in self.records.values():
            identity = json.dumps([record["context"], record["E"]["model_ref"]])
            groups.setdefault(identity, []).append(record)
        result = []
        for identity, records in groups.items():
            first = records[0]
            values = {name: [] for name in first["dimensions"]}
            contributions = []
            for record in records:
                residuals = {name: item["residual"] for name, item in record["dimensions"].items()
                             if item["status"] == "unresolved"}
                for name, value in residuals.items():
                    values[name].append(value)
                if residuals:
                    contributions.append({"assessment_id": record["assessment_id"],
                                          "revision": record["revision"], "H_vec": residuals})
            try:
                vector = {name: math.fsum(items) for name, items in values.items()}
                magnitude = math.hypot(*vector.values())
                finite = math.isfinite(magnitude)
            except OverflowError:
                vector, magnitude, finite = None, None, False
            result.append({
                "context_id": hashlib.sha256(identity.encode()).hexdigest(),
                "agent_id": first["E"]["agent_id"],
                "model_ref": first["E"]["model_ref"],
                "context": deepcopy(first["context"]),
                "H_vec": vector if finite else None,
                "H": magnitude if finite else None,
                "status": "finite" if finite else "numeric_overflow",
                "norm": "GameAI-local L2 of per-dimension residual sums",
                "retention_rule": "retain-until-explicit-review; no-time-decay",
                "comparison_count": len(records),
                "pending_dimensions": sum(item["status"] == "pending"
                                          for record in records for item in record["dimensions"].values()),
                "contributions": contributions,
            })
        return result
