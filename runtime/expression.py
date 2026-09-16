"""Derived GameAI-local response expression; no action or Core authority."""

from copy import deepcopy


def with_expression(decision):
    result = deepcopy(decision)
    inspection = result["inspection"]
    body = inspection.get("body", {})
    history = inspection.get("history_influence", {})
    deferred = history.get("deferred_targets", [])
    scale = body.get("movement_scale")
    action = result["action"]["type"]
    flags = []
    if scale is not None and scale < 1:
        flags.append("movement-limited")
    if deferred:
        flags.append("recent-no-progress")
    if scale == 0:
        label = "restricted"
    elif action == "approach":
        label = "engaged"
    elif deferred:
        label = "holding"
    else:
        label = "observing"
    inspection["expression"] = {
        "label": label, "factors": flags,
        "rule": "response-expression-v1",
        "authority": "derived-display-only",
        "observation_id": inspection["observation_id"],
        "body_snapshot_id": body.get("snapshot_id"),
        "profile_id": history.get("profile_id"),
        "history_record_ids": list(dict.fromkeys(item["record_id"] for item in deferred)),
    }
    return result
