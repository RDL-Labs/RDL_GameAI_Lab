extends "res://scripts/heavy_rescue_fixture.gd"
# SOC-4 toy World mechanics. These numbers never enter the predictor.
var footing = "firm"

func reset():
	super.reset()
	carry_capabilities = {"npc_a": 3, "npc_c": 1}
	target_load = 2
	footing = "firm"

func _sufficient(active):
	var total = 0
	for id in active:
		total += carry_capabilities.get(id, 0)
		if body_states[id]["movement_scale"] < 1.0: total -= 1
	var resistance = target_load + (1 if footing == "loose" else 0)
	return total >= resistance

func _resolve_rescue(decision, target_id):
	if attempt_count >= 1:
		return _record_resolution(decision.get("agent_id", ""), "rescue", target_id, "SOC-4 one-trial budget exhausted")
	return super._resolve_rescue(decision, target_id)

func capture_context(packet):
	var actor = packet["agent_id"]
	var body = packet["observation"]["body"]
	var target = {}
	for item in packet["observation"]["visible_agents"]:
		if item["id"] == "npc_b": target = item
	var in_reach = target.get("within_reach", false)
	var scale = body["movement_scale"]
	var movement = "full" if scale == 1.0 else "limited" if scale == 0.5 else "unknown"
	return {"schema": "soc4-pre-carry-context-v1", "run_id": run_id, "agent_id": actor, "target_id": "npc_b",
		"context_ref": "soc4-fixed-pickup-v1", "profile": "soc4-local-contact-cues-v1",
		"source_observation_id": packet["observation_id"], "tick": packet["tick"],
		"body_ref": body["snapshot_id"], "footing_ref": "contact:" + packet["observation_id"],
		"movement_band": movement, "footing_band": footing if in_reach else "unknown",
		"coverage": "complete" if in_reach else "partial",
		"actor_ready": not body["incapacitated"] and scale > 0 and body["carried_agent_id"].is_empty(),
		"target_ready": target.get("condition", "") == "incapacitated", "within_reach": in_reach}
