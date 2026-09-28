"""L15A experiment A: a fixed, bounded lateral contribution, without hysteresis."""
from copy import deepcopy
from math import isclose

from .exploration import fields, require
from .subjective_movement_terrain import calculate_terrain, TIE_TOLERANCE
from .terrain_resource_exploration import TerrainResourceAgent, TerrainResourceExploration, terrain_input, terrain_action

SCHEMA = "l15a-terrain-lateral-bias-v1"
RULE = "l15a-lateral-near-tie-v1"
BIASES = {"left": -1, "neutral": 0, "right": 1}
NEAR_WIDTH = .10
BIAS_HEIGHT = .05


def calculate_lateral(observation, bias):
    """Validate/recompute current terrain; keep observed and individual terms separate.

    Only mirrored alternatives containing an observed global minimum are eligible.
    Each component and the total must be close; cancelling large component
    differences cannot manufacture a near tie. A forward minimum keeps priority.
    """
    require(isinstance(bias, str) and bias in BIASES, "lateral_bias")
    t = calculate_terrain(observation)
    rows = {r["direction_deg"]: r for r in t["directional_samples"]}
    pairs, eligible = [], set()
    for angle in (45, 90):
        left, right = rows[-angle], rows[angle]
        differences = None
        if t["status"] != "complete":
            reason = "terrain_" + t["status"]
        elif left["status"] != "scored" or right["status"] != "scored":
            reason = "mirrored_direction_excluded"
        else:
            differences = {k: abs(left[k] - right[k]) for k in ("physical", "food", "obstacle", "total")}
            if 0 in t["minimum_directions"]:
                reason = "forward_minimum"
            elif not ({-angle, angle} & set(t["minimum_directions"])):
                reason = "not_observed_minimum"
            elif any(v > NEAR_WIDTH + TIE_TOLERANCE for v in differences.values()):
                reason = "observed_difference_dominates"
            else:
                reason = "near_mirrored_minimum"
                eligible.update((-angle, angle))
        pairs.append(dict(magnitude=angle, differences=differences, reason=reason,
                          eligible=reason == "near_mirrored_minimum"))
    final = []
    for angle, row in rows.items():
        observed = row["total"]
        contribution = None if observed is None else (
            -BIAS_HEIGHT * BIASES[bias] * (1 if angle > 0 else -1) if angle in eligible else 0.)
        final.append(dict(direction_deg=angle, status=row["status"], observed_terrain_total=observed,
            lateral_bias_contribution=contribution, turn_hysteresis_contribution=None,
            final_total=None if observed is None else observed + contribution))
    minimum = min((r["final_total"] for r in final if r["final_total"] is not None), default=None)
    directions = None if t["minimum_directions"] is None else [r["direction_deg"] for r in final
        if r["final_total"] is not None and isclose(r["final_total"], minimum, rel_tol=0, abs_tol=TIE_TOLERANCE)]
    choice = dict(status=t["status"], minimum_directions=directions)
    action, reason = terrain_action(choice)
    return dict(schema=SCHEMA, rule=RULE, bias=bias, near_width=NEAR_WIDTH, bias_height=BIAS_HEIGHT,
        observed_terrain=t, pairs=pairs, directional_samples=final, minimum_height=minimum,
        minimum_directions=directions, turn_hysteresis="disabled", selected_action=action, selected_reason=reason,
        selected_direction=action[1] if action[0] == "turn" else (0 if action[0] == "move" else None))


class LateralResourceAgent(TerrainResourceAgent):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.lateral_bias = None

    def _decision(self, p):
        d = super()._decision(p)
        d["lateral"] = None
        if d["movement_terrain"] is None:
            return d
        result = calculate_lateral(terrain_input(p, self.teaching["appearance"], d["blocked_targets"]), self.lateral_bias)
        result["parameter_source"] = dict(run_id=self.run_id, agent_id=self.agent_id, kind="fixed_run_configuration")
        result["baseline_action"], result["baseline_reason"] = list(d["action"]), d["reason"]
        previous = next(reversed(self.observations.values())) if self.observations else None
        receipt = self.results.get("op:" + previous["observation_id"]) if previous else None
        result["previous_turn_direction"] = receipt["yaw"] if receipt and receipt["status"] == "turned" else None
        # Previous direction is diagnostic only. No persistence or turn budget
        # from the v2 steering experiment is imported into this separate mode.
        if result["selected_action"] != d["action"]:
            d.update(action=list(result["selected_action"]), target="", reason="observed_material_lateral_" + result["selected_reason"])
        d["lateral"] = result
        return d

    def snapshot(self):
        s = super().snapshot()
        s.update(movement_control=SCHEMA, lateral_bias=self.lateral_bias)
        return s


class LateralResourceExploration(TerrainResourceExploration):
    schema = SCHEMA
    agent_type = LateralResourceAgent

    def dispatch(self, name, value):
        if name != "configure":
            return super().dispatch(name, value)
        with self.lock:
            fields(value, "schema run_id world_epoch agent_id clock_id teaching selection_profile lateral_bias")
            bias = value["lateral_bias"]
            require(isinstance(bias, str) and bias in BIASES, "lateral_bias")
            require(isinstance(value["agent_id"], str) and value["agent_id"] in self.agents, "unknown_agent")
            agent = self.agents[value["agent_id"]]
            require(agent.lateral_bias in (None, bias), "lateral_configuration_conflict")
            response = super().dispatch(name, {k: deepcopy(v) for k,v in value.items() if k != "lateral_bias"})
            agent.lateral_bias = bias
            return dict(response, lateral_bias=bias)
