"""L15A Phase 1: pure, bounded directional movement terrain.

The caller supplies one current, body-relative observation. Binding checks do
not authenticate a sensor or look up an admitted frame. No World adapter,
action selection, history, canonical model, or global map is accessed here.
"""
from copy import deepcopy
from math import fsum, hypot, isclose, isfinite, sqrt

SCHEMA = "l15a-subjective-movement-terrain-v1"
PROFILE = "l15a-finite-directional-v1"
RULE_VERSION = "l15a-phase1-v1"
DIRECTIONS = (-90, -45, 0, 45, 90)  # Positive is body-right.
_DIAGONAL = sqrt(.5)
_POINTS = ((0., -1.), (_DIAGONAL, -_DIAGONAL), (1., 0.),
           (_DIAGONAL, _DIAGONAL), (0., 1.))  # (forward, right)
_CONTEXT = "run_id world_epoch agent_id observation_id clock_id capture_us pose_ref body_revision"
_COVERAGES = ("complete", "partial", "unavailable")
FOOD_LIMIT, OBSTACLE_LIMIT = 5, 8
OBSERVATION_RADIUS = 12.
FOOD_GAIN, FOOD_RADIUS = 4., 12.
OBSTACLE_GAIN, OBSTACLE_RADIUS, OBSTACLE_CAP = 6., 6., 12.
HEIGHT_GAIN, MAX_STEP_HEIGHT = 2., 1.
TIE_TOLERANCE = 1e-9


class TerrainInputError(ValueError):
    """Malformed/unbound input, distinct from valid incomplete acquisition."""

    def __init__(self, code):
        self.code = code
        super().__init__(code)


def _require(condition, code):
    if not condition:
        raise TerrainInputError(code)


def _fields(value, names):
    _require(isinstance(value, dict) and set(value) == set(names.split()), "fields")


def _ref(value):
    _require(isinstance(value, str) and 0 < len(value) <= 128, "reference")


def _number(value, low, high):
    _require(type(value) in (int, float) and low <= value <= high and isfinite(value), "number")


def _context(value):
    _fields(value, _CONTEXT)
    for key in ("run_id", "agent_id", "observation_id", "clock_id", "pose_ref"):
        _ref(value[key])
    for key in ("world_epoch", "capture_us", "body_revision"):
        _require(type(value[key]) is int and 0 <= value[key] <= 10**12, "integer")


def _channel(channel, context, payload):
    _fields(channel, "source coverage output_limited " + payload)
    source = channel["source"]
    _fields(source, _CONTEXT + " frame_id")
    _context({k: v for k, v in source.items() if k != "frame_id"})
    _ref(source["frame_id"])
    _require(all(source[k] == v for k, v in context.items()), "source_context_mismatch")
    _require(channel["coverage"] in _COVERAGES, "coverage")
    _require(type(channel["output_limited"]) is bool, "output_limited")
    _require(not channel["output_limited"] or channel["coverage"] == "partial", "limited_complete")


def _objects(channel, context, limit):
    _channel(channel, context, "items")
    items = channel["items"]
    _require(isinstance(items, list) and len(items) <= limit, "object_budget")
    _require(channel["coverage"] != "unavailable" or not items, "unavailable_items")
    seen = set()
    for item in items:
        _fields(item, "ref forward right")
        _ref(item["ref"])
        _require(item["ref"] not in seen, "duplicate_object_ref")
        seen.add(item["ref"])
        _number(item["forward"], 0, OBSERVATION_RADIUS)
        _number(item["right"], -OBSERVATION_RADIUS, OBSERVATION_RADIUS)
        _require(hypot(item["forward"], item["right"]) <= OBSERVATION_RADIUS, "object_range")


def _validate(observation):
    _fields(observation, "schema profile context food obstacles ground")
    _require(observation["schema"] == SCHEMA and observation["profile"] == PROFILE, "schema_profile")
    context = observation["context"]
    _context(context)
    _objects(observation["food"], context, FOOD_LIMIT)
    _objects(observation["obstacles"], context, OBSTACLE_LIMIT)
    ground = observation["ground"]
    _channel(ground, context, "samples")
    samples = ground["samples"]
    _require(isinstance(samples, list) and len(samples) == len(DIRECTIONS), "ground_budget")
    directions = set()
    for sample in samples:
        _fields(sample, "direction_deg status height_delta")
        angle = sample["direction_deg"]
        _require(type(angle) is int and angle in DIRECTIONS and angle not in directions, "ground_direction")
        directions.add(angle)
        _require(sample["status"] in ("sampled", "blocked", "no_surface", "unavailable"), "ground_status")
        if sample["status"] == "sampled":
            _number(sample["height_delta"], -4, 4)
        else:
            _require(sample["height_delta"] is None, "ground_height_missing")
    _require(ground["coverage"] != "complete" or all(s["status"] != "unavailable" for s in samples),
             "ground_completeness")
    _require(ground["coverage"] != "unavailable" or all(s["status"] == "unavailable" for s in samples),
             "ground_unavailable")


def _clearance(point, obstacle):
    """Observed point to the closed, one-node candidate segment; not collision truth.

    Including the segment prevents a nearby obstacle behind its endpoint from
    losing repulsion merely because the hypothetical sample steps past it.
    """
    f, r = point
    t = max(0., min(1., obstacle["forward"] * f + obstacle["right"] * r))
    return hypot(obstacle["forward"] - t * f, obstacle["right"] - t * r)


def _ordered(items):
    # References only order diagnostics for co-located points. Numeric reduction
    # is by sorted contribution values, so labels cannot affect floating sums.
    return sorted(items, key=lambda i: (i["forward"], i["right"], i["ref"]))


def calculate_terrain(observation):
    """Return five sourced heights and all tied minima; never an action.

    Any incomplete channel suppresses all numeric terrain contributions.
    Complete observed blocked/no-surface/over-height directions are excluded
    individually, with null physical/total instead of infinity or zero.
    """
    _validate(observation)
    reasons = [f"{key}_{observation[key]['coverage']}" for key in ("food", "obstacles", "ground")
               if observation[key]["coverage"] != "complete"]
    reasons += [f"{key}_output_limited" for key in ("food", "obstacles", "ground")
                if observation[key]["output_limited"]]
    evidence = deepcopy({k: observation[k] for k in ("food", "obstacles", "ground")})
    for key in ("food", "obstacles"):
        evidence[key]["items"] = _ordered(evidence[key]["items"])
    evidence["ground"]["samples"].sort(key=lambda s: s["direction_deg"])
    output = dict(schema=SCHEMA, profile=PROFILE, rule_version=RULE_VERSION,
        context=deepcopy(observation["context"]),
        evidence=evidence,
        status="acquisition_incomplete" if reasons else "complete", reasons=reasons,
        directional_samples=[], minimum_height=None, minimum_directions=None)
    ground = {s["direction_deg"]: s for s in observation["ground"]["samples"]}
    for angle, point in zip(DIRECTIONS, _POINTS):
        row = dict(direction_deg=angle, sample_point=dict(forward=point[0], right=point[1]),
            status="not_evaluated", reasons=list(reasons),
            physical=None, food=None, obstacle=None, total=None, source_contributions=None)
        if not reasons:
            food = []
            items = observation["food"]["items"]
            denominator = max(1, len(items))
            for item in _ordered(items):
                distance = hypot(point[0] - item["forward"], point[1] - item["right"])
                raw = -FOOD_GAIN * max(0., 1 - distance / FOOD_RADIUS)
                food.append(dict(ref=item["ref"], distance=distance, raw=raw,
                                 normalized=raw / denominator))
            obstacle = []
            for item in _ordered(observation["obstacles"]["items"]):
                clearance = _clearance(point, item)
                value = OBSTACLE_GAIN * max(0., 1 - clearance / OBSTACLE_RADIUS)**2
                obstacle.append(dict(ref=item["ref"], clearance=clearance, value=value))
            obstacle_sum = fsum(sorted(i["value"] for i in obstacle))
            surface = ground[angle]
            excluded = (surface["status"] if surface["status"] != "sampled" else
                        "step_height_exceeded" if abs(surface["height_delta"]) > MAX_STEP_HEIGHT else None)
            row.update(status="excluded_by_observation" if excluded else "scored",
                reasons=[excluded] if excluded else [],
                physical=None if excluded else HEIGHT_GAIN * abs(surface["height_delta"]),
                food=fsum(sorted(i["normalized"] for i in food)), obstacle=min(OBSTACLE_CAP, obstacle_sum),
                source_contributions=dict(ground=deepcopy(surface), food=food, food_denominator=denominator,
                    obstacles=obstacle, obstacle_sum=obstacle_sum, obstacle_cap=OBSTACLE_CAP))
            if not excluded:
                row["total"] = fsum((row["physical"], row["food"], row["obstacle"]))
        output["directional_samples"].append(row)
    scored = [r for r in output["directional_samples"] if r["status"] == "scored"]
    if not reasons:
        output["status"] = "complete" if scored else "no_supported_direction"
        output["minimum_height"] = min((r["total"] for r in scored), default=None)
        output["minimum_directions"] = [r["direction_deg"] for r in scored
            if isclose(r["total"], output["minimum_height"], rel_tol=0, abs_tol=TIE_TOLERANCE)]
    return output
