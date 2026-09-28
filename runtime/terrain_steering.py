"""L15A v2: finite heading persistence, confirmed-turn step, and turn-cycle exit.

The v1 calculator/sensors are unchanged. State comes only from this agent's
accepted observations, commands and measured results; no World position lookup.
"""
from copy import deepcopy

from .exploration import require
from .terrain_resource_exploration import TerrainResourceAgent, TerrainResourceExploration, terrain_input
from .subjective_movement_terrain import calculate_terrain

SCHEMA = "l15a-terrain-resource-steering-v2"
RULE = "l15a-heading-persistence-v2"
HEADING_MARGIN = .10
RECHECK_MARGIN = .25
MAX_TURNS_WITHOUT_MOVE = 2


class SteeredResourceAgent(TerrainResourceAgent):
    def _decision(self, p):
        d = self._steering_decision(p)
        if getattr(self, 'reversal_review_mode', None) is not None:
            from .reversal_review import review
            return review(self, p, d)
        return d

    def _steering_decision(self, p):
        d = super()._decision(p)
        t = d["movement_terrain"]
        meta = dict(rule=RULE, baseline_action=list(d["action"]), baseline_reason=d["reason"],
            input_blocked_targets=list(d["blocked_targets"]), turns_without_move=0,
            previous_operation=None, forward_gap=None, step_recheck=None, current_recheck=None, stopped_targets=[])
        d["steering"] = meta
        previous = next(reversed(self.observations.values())) if self.observations else None
        last = self.decisions.get(previous["observation_id"]) if previous else None
        command = self.commands.get(previous["observation_id"]) if previous else None
        result = self.results.get(command["operation_id"]) if command else None
        confirmed_turn = (last is not None and "steering" in last and last["period"] == d["period"]
            and last["terrain_gate"] in ("visible_food_locomotion", "no_front_food; existing_orientation")
            and command["kind"] == "turn" and result is not None and result["status"] == "turned"
            and result["after_pose_ref"] == p["pose_ref"] and result["after_revision"] == p["body_revision"]
            and result["executed_us"] < p["capture_us"] < command["expires_us"]
            and abs(result["yaw"] - command["amount"]) < .01)
        if confirmed_turn:
            meta["previous_operation"] = command["operation_id"]
            meta["turns_without_move"] = last["steering"]["turns_without_move"] + 1
        owned = t is not None or d["terrain_gate"] == "no_front_food; existing_orientation"
        if not owned:
            return d  # pickup, variation, incomplete legacy view and body gates retain priority
        frontal = t is not None
        if t is None and confirmed_turn and last["movement_terrain"] is not None:
            # The local Food sensor still sees behind the body. Turning sideways
            # must not automatically undo a chosen step when only its frontal
            # Food projection disappears. Recheck current geometry, with no
            # invented Food in that frontal projection.
            t = calculate_terrain(terrain_input(p, self.teaching["appearance"], d["blocked_targets"]))
            meta["current_recheck"] = t
        if t is not None and t["status"] != "complete":
            if not frontal:
                d.update(action=["wait",0], target="", reason="observed_material_terrain_"+t["status"])
            return d  # never replace missing/currently excluded geometry with a prior plan
        if t is not None:
            forward = next(row for row in t["directional_samples"] if row["direction_deg"] == 0)
            if forward["status"] == "scored":
                meta["forward_gap"] = forward["total"] - t["minimum_height"]
                if frontal and meta["forward_gap"] <= HEADING_MARGIN + 1e-9:
                    d.update(action=["move", 1], target="", reason="observed_material_terrain_heading_held")
                elif confirmed_turn and last["movement_terrain"] is not None:
                    old = last["movement_terrain"]
                    planned = next((r for r in old["directional_samples"] if r["direction_deg"] == command["amount"]), None)
                    def visible_refs(packet, excluded):
                        return {i["ref"] for i in packet["food"]["visible"]
                            if i["appearance"] == self.teaching["appearance"] and i["ref"] not in excluded}
                    same_food = (visible_refs(previous, last["steering"]["input_blocked_targets"])
                                 == visible_refs(p, meta["input_blocked_targets"]))
                    if planned is not None and planned["status"] == "scored":
                        checks = dict(same_food=same_food,
                            physical_not_worse=forward["physical"] <= planned["physical"] + 1e-9,
                            obstacle_not_worse=forward["obstacle"] <= planned["obstacle"] + RECHECK_MARGIN)
                        meta["step_recheck"] = dict(source=previous["observation_id"],
                            planned_direction=command["amount"], planned=deepcopy(planned), checks=checks)
                        if all(checks.values()):
                            d.update(action=["move", 1], target="", reason="observed_material_terrain_confirmed_turn_step")
        # A new ray basis may still favor undoing the last turn. Do not make a
        # repeated body oscillation or force a step through a rejected surface.
        if d["action"][0] == "turn" and confirmed_turn:
            reversal = d["action"][1] * command["amount"] < 0
            exhausted = meta["turns_without_move"] >= MAX_TURNS_WITHOUT_MOVE
            if reversal or exhausted:
                # Postpone only the active approach, not every observed Food.
                # Other resources remain eligible, including later pickup.
                refs = [d["approach"]["ref"]] if d["approach"] is not None else []
                if getattr(self, 'reversal_review_mode', None) is not None:
                    meta['stopped_approach'] = deepcopy(d['approach'])
                require(len(d["blocked_targets"]) + len(refs) <= 32, "approach_capacity")
                d["blocked_targets"] += refs
                d["approach"] = None
                meta["stopped_targets"] = refs
                d.update(action=["wait", 0], target="", reason="observed_material_terrain_"+
                    ("reversal_stopped" if reversal else "turn_budget_stopped"))
        return d

    def snapshot(self):
        state = super().snapshot()
        state["movement_control"] = SCHEMA
        return state


class SteeredResourceExploration(TerrainResourceExploration):
    schema = SCHEMA
    agent_type = SteeredResourceAgent
