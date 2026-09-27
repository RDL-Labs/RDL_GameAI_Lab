extends "res://scripts/mock_state_provider.gd"
# SOC-0 opt-in World fixture. Default provider and Rescue policy are unchanged.
var carry_capabilities = {"npc_a": 1, "npc_c": 1}
var target_load = 2
var participants = ["npc_a"]
var run_id = "soc0"
var experiences = []
var world_checks = []
var attempt_count = 0
var action_receipts = {}

func reset():
	super.reset()
	var helper = agents[0].duplicate(true)
	helper["id"] = "npc_c"
	helper["label"] = "NPC C"
	agents.append(helper)
	body_states["npc_c"] = body_states["npc_a"].duplicate(true)
	action_offsets["npc_c"] = Vector2.ZERO
	experiences = []
	world_checks = []
	attempt_count = 0
	action_receipts = {}
	participants = ["npc_a"]
	mock_wandering_enabled = false

func _active_carriers(target_id):
	var result = []
	var target = get_agent(target_id)
	if target.is_empty(): return result
	for id in participants:
		if id in result or id == target_id: continue
		var agent = get_agent(id)
		var body = body_states.get(id, {})
		if agent.is_empty() or body.get("incapacitated", true) or body.get("movement_scale", 0.0) <= 0.0: continue
		if not body.get("carried_agent_id", "") in ["", target_id]: continue
		if agent["position"].distance_to(target["position"]) > RESCUE_REACH_DISTANCE: continue
		result.append(id)
	return result

func _sufficient(active):
	var total = 0
	for id in active: total += carry_capabilities.get(id, 0)
	return total >= target_load

func resolve_action(decision):
	var id = decision.get("agent_id", "")
	var source = decision.get("inspection", {}).get("observation_id", "")
	var key = id + ":" + source
	if action_receipts.has(key):
		if action_receipts[key]["decision"] != decision: return {"error": "action_conflict"}
		return action_receipts[key]["result"].duplicate(true)
	if action_receipts.size() >= 64: return {"error": "fixture_action_budget"}
	var carried = body_states.get(id, {}).get("carried_agent_id", "")
	var kind = decision.get("action", {}).get("type", "")
	var active = _active_carriers(carried) if not carried.is_empty() else []
	var result
	if not carried.is_empty() and kind in ["approach", "deliver"] and (not id in active or not _sufficient(active)):
		result = _record_resolution(id, kind, decision["action"].get("target_id", ""), "transport did not progress")
	else:
		var before = get_agent(id).get("position", Vector2.ZERO)
		var target_before = get_agent(carried).get("position", Vector2.ZERO)
		result = super.resolve_action(decision)
		if not carried.is_empty() and kind == "approach":
			var delta = get_agent(id)["position"] - before
			for helper_id in active:
				if helper_id == id: continue
				var index = _find_agent_index(helper_id)
				agents[index]["position"] += delta
				action_offsets[helper_id] += delta
				if active_energy_enabled and delta.length() > 0: _change_active_energy(helper_id, -ACTIVE_ENERGY_APPROACH_COST)
		if kind == "deliver" and result.get("effects", {}).has("delivered_agent_id"):
			_experience(decision, active, "delivered", get_agent(carried)["position"] != target_before, false)
	action_receipts[key] = {"decision": decision.duplicate(true), "result": result.duplicate(true)}
	return result

func _resolve_rescue(decision, target_id):
	var id = decision.get("agent_id", "")
	for body in body_states.values():
		if body.get("carried_agent_id", "") == target_id:
			return _record_resolution(id, "rescue", target_id, "target is already carried")
	if attempt_count >= 2:
		return _record_resolution(id, "rescue", target_id, "finite attempt budget exhausted")
	attempt_count += 1
	var before = get_agent(target_id).get("position", Vector2.ZERO)
	var active = _active_carriers(target_id)
	var result
	if not id in active or not _sufficient(active):
		result = _record_resolution(id, "rescue", target_id, "carry attempted; transport did not establish", null, null,
			decision.get("inspection", {}).get("observation_id", ""), get_observation(id).get("observation_id", ""))
	else:
		result = super._resolve_rescue(decision, target_id)
	var established = body_states.get(id, {}).get("carried_agent_id", "") == target_id
	var moved = get_agent(target_id).get("position", Vector2.ZERO) != before
	world_checks.append({"attempt": attempt_count, "active": active.duplicate(), "established": established,
		"target_moved": moved, "target_before": [before.x, before.y],
		"target_after": [get_agent(target_id)["position"].x, get_agent(target_id)["position"].y]})
	_experience(decision, active, "carry_established" if established else "carry_not_established", moved, established)
	return result

func _experience(decision, active, outcome, moved, established):
	var id = decision["agent_id"]
	experiences.append({"schema": "soc0-rescue-experience-v1", "run_id": run_id,
		"event_id": run_id + ":event:" + str(experiences.size()), "agent_id": id,
		"source_observation_id": decision.get("inspection", {}).get("observation_id", ""),
		"subsequent_observation_id": get_observation(id)["observation_id"], "tick": tick,
		"action": decision["action"]["type"], "target_id": "npc_b",
		"participants": active.duplicate(), "attempt_condition": "solo" if active.size() == 1 else "joint",
		"result": outcome, "world_consequence": {"target_moved": moved, "carry_established": established},
		"body_consequence": {"actor_incapacitated": body_states[id]["incapacitated"],
			"target_incapacitated": body_states["npc_b"]["incapacitated"],
			"target_recovery_stage": body_states["npc_b"]["recovery_stage"]},
		"authority": "bounded-rescue-experience-only; not-social-relation-NERV-T1-or-action"})
