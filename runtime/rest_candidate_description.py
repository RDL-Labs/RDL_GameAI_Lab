"""Translate bounded Rest places through an opt-in rho description level."""

from copy import deepcopy

from .core import ObservationError


ADAPTER_ID = "rho-rest-candidate-description-v1"


class RestCandidateDescriptionAdapter:
    """Change candidate distinctions without selecting or committing a target."""

    def describe(self, places, observation_resolution):
        rest_projection = _rest_projection(observation_resolution)
        level = rest_projection["level"]
        descriptions = []
        for place in places:
            if place.get("rest_capable") is not True:
                continue
            description = {
                "id": place["id"],
                "rest_capable": True,
                "within_reach": place.get("within_reach", False),
                "rest_safety": "unknown",
                "rest_distance_band": "near",
            }
            if level in {"MID", "HIGH"}:
                description["rest_distance_band"] = place.get("rest_distance_band")
            if level == "HIGH":
                description["rest_safety"] = place.get("rest_safety", "unknown")
            descriptions.append(description)
        return {
            "adapter": ADAPTER_ID,
            "authority": "GameAI-local-candidate-description; not-selection-trajectory-M_B-or-action-authority",
            "rho_level": level,
            "selection_profile_version": rest_projection["selection"]["selection_profile_version"],
            "projection_rule_version": rest_projection["rule_version"],
            "descriptions": deepcopy(descriptions),
        }


def _rest_projection(observation_resolution):
    if not isinstance(observation_resolution, dict):
        raise ObservationError("rho Rest candidate mode requires observation_resolution")
    if observation_resolution.get("schema_version") != "rho-observation-resolution-packet-v1":
        raise ObservationError("unsupported observation resolution packet version")
    projection = observation_resolution.get("domains", {}).get("rest")
    if not isinstance(projection, dict):
        raise ObservationError("rho Rest projection is required")
    if projection.get("level") not in {"LOW", "MID", "HIGH"}:
        raise ObservationError("unsupported rho Rest level")
    if projection.get("rule_version") != "rho-rest-projection-v1":
        raise ObservationError("unsupported rho Rest projection rule")
    selection = projection.get("selection")
    if not isinstance(selection, dict) or selection.get("selection_profile_version") != "rho-profile-selection-v1":
        raise ObservationError("unsupported rho Rest selection provenance")
    return projection
