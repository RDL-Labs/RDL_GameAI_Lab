"""Read-only C2 projection of the canonical comparison and review path."""

from copy import deepcopy
from typing import Any


PROJECTION_ID = "canonical-review-path-projection-v1"


class ReviewPathProjectionError(ValueError):
    pass


def build_review_path_snapshot(comparisons: dict[str, dict[str, Any]],
                               assessment_snapshot: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(comparisons, dict) or not isinstance(assessment_snapshot, dict):
        raise ReviewPathProjectionError("review path inputs must be objects")
    records = assessment_snapshot.get("records")
    if not isinstance(records, list):
        raise ReviewPathProjectionError("assessment records must be a list")
    reviews = {}
    for record in records:
        assessment_id = record.get("assessment_id") if isinstance(record, dict) else None
        if not isinstance(assessment_id, str) or not assessment_id or assessment_id in reviews:
            raise ReviewPathProjectionError("assessment identity must be finite and unique")
        reviews[assessment_id] = record

    paths = []
    for assessment_id, comparison in comparisons.items():
        if assessment_id not in reviews:
            raise ReviewPathProjectionError("comparison path lost its assessment")
        review = reviews[assessment_id]
        if comparison.get("E") != review.get("E"):
            raise ReviewPathProjectionError("comparison E differs from assessment E")
        paths.append({
            "assessment_id": assessment_id,
            "agent_id": comparison["E"]["agent_id"],
            "model_ref": comparison["E"]["model_ref"],
            "RIB_B": deepcopy(comparison["RIB_B"]),
            "F": deepcopy(comparison["F"]),
            "RIB_B_prime": deepcopy(comparison["RIB_B_prime"]),
            "F_prime": deepcopy(comparison["F_prime"]),
            "E": deepcopy(comparison["E"]),
            "review": {
                "status": "reviewed" if review["reviewed"] else "pending",
                "revision": review["revision"],
                "dimensions": deepcopy(review["dimensions"]),
                "provenance": deepcopy(review["review"]),
            },
            "H_vec": deepcopy(review["H_vec"]),
            "H": review["H"],
            "norm": review["norm"],
            "authority": "canonical-diagnostic-review-path; not-candidate-theta-M_delta-T1-or-action",
        })
    return {
        "projection": PROJECTION_ID,
        "paths": paths,
        "count": len(paths),
        "authority": "read-only-canonical-review-path-projection",
        "excluded_sources": ["raw_experience", "sleep_candidate", "fast_retrieval"],
        "downstream_separation": ["theta_eff", "M_delta", "T1", "M_B_prime"],
    }
