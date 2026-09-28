"""L15A opt-in: current visible-Food locomotion inside the existing L14B loop.

No learned/model contribution is added to terrain. Landmark exploration,
harvest learning, body receipts and operation identity remain L14B-owned.
"""
from copy import deepcopy

from .exploration import fields, require
from .multi_resource_exploration import MultiResourceExploration, PredictableResourceAgent
from .subjective_movement_terrain import SCHEMA as TERRAIN, PROFILE, calculate_terrain

SCHEMA = "l15a-terrain-resource-exploration-v1"
SURFACE = "l15a-current-surface-rays-v1"
CONTEXT = "run_id world_epoch agent_id observation_id clock_id capture_us pose_ref body_revision".split()


def terrain_input(packet, appearance, blocked=()):
    """Project declared current observations, never infer unseen surface geometry."""
    surface = packet["movement_surface"]
    fields(surface, "schema ground obstacles")
    require(surface["schema"] == SURFACE, "movement_surface_schema")
    context = {k: packet[k] for k in CONTEXT}
    for key in ("ground", "obstacles"):
        require(isinstance(surface[key], dict) and
                surface[key].get("source") == dict(context, frame_id=packet["observation_id"]+":"+key),
                "movement_surface_binding")
    food = dict(source=dict(context, frame_id=packet["observation_id"]+":food"),
        coverage=packet["food"]["coverage"], output_limited=False,
        items=[{k: i[k] for k in ("ref", "forward", "right")}
               for i in packet["food"]["visible"] if i["appearance"] == appearance
               and i["forward"] >= 0 and i["ref"] not in blocked])
    return dict(schema=TERRAIN, profile=PROFILE, context=context, food=food,
                ground=deepcopy(surface["ground"]), obstacles=deepcopy(surface["obstacles"]))


def terrain_action(terrain):
    if terrain["status"] != "complete":
        return ["wait", 0], terrain["status"]
    minima = terrain["minimum_directions"]
    # Preserve the current heading when tied; equal left/right turns defer.
    if 0 in minima:
        return ["move", 1], "forward_minimum"
    magnitude = min(abs(x) for x in minima)
    turns = [x for x in minima if abs(x) == magnitude]
    if len(turns) != 1:
        return ["wait", 0], "symmetric_minimum"
    return ["turn", turns[0]], "turn_minimum"


class TerrainResourceAgent(PredictableResourceAgent):
    def _packet(self, p):
        require(isinstance(p, dict) and "movement_surface" in p, "movement_surface_required")
        super()._packet({k: v for k, v in p.items() if k != "movement_surface"})
        # Validate even while pickup/variation/landmark has precedence. Bad or
        # cross-body extensions cannot be silently bypassed to publish a packet.
        calculate_terrain(terrain_input(p, self.teaching["appearance"]))

    def _decision(self, p):
        decision = super()._decision(p)
        decision["movement_terrain"] = None
        decision["terrain_gate"] = "existing_priority"
        if decision["reason"] not in ("observed_material_heading", "observed_material_approach"):
            return decision
        observed = terrain_input(p, self.teaching["appearance"], decision["blocked_targets"])
        if not observed["food"]["items"]:
            # Legacy local Food observation covers behind the body too. Orient
            # using that sourced observation, then obtain new frontal rays.
            decision["terrain_gate"] = "no_front_food; existing_orientation"
            return decision
        terrain = calculate_terrain(observed)
        action, reason = terrain_action(terrain)
        decision.update(action=action, target="", reason="observed_material_terrain_"+reason,
                        movement_terrain=terrain, terrain_gate="visible_food_locomotion")
        return decision

    def snapshot(self):
        state = super().snapshot()
        state["movement_control"] = SCHEMA
        return state


class TerrainResourceExploration(MultiResourceExploration):
    schema = SCHEMA
    agent_type = TerrainResourceAgent
