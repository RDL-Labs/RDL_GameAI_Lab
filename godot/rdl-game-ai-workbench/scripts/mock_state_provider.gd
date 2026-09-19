extends RefCounted
class_name MockStateProvider

const ObservationResolutionAdapterScript = preload("res://scripts/observation_resolution_adapter.gd")
const ObservationResolutionProfileScript = preload("res://scripts/observation_resolution_profile.gd")

const INITIAL_AGENTS = [
	{
		"id": "npc_a",
		"label": "NPC A",
		"role": "mock agent",
		"position": Vector2(120, 120),
		"mood": "curious",
		"note": "Mock state only. No RDL semantics are evaluated here."
	},
	{
		"id": "npc_b",
		"label": "NPC B",
		"role": "mock agent",
		"position": Vector2(260, 180),
		"mood": "calm",
		"note": "Mock state only. No RDL semantics are evaluated here."
	}
]

const INITIAL_OBJECTS = [
	{
		"id": "food_01",
		"label": "Mock Food",
		"role": "mock object",
		"kind": "food",
		"position": Vector2(190, 260),
		"note": "Visible only when inside the selected agent perception radius."
	},
	{
		"id": "far_cache",
		"label": "Far Cache",
		"role": "mock object",
		"position": Vector2(390, 295),
		"note": "Deliberately outside NPC A's initial bounded observation."
	}
]

const INITIAL_PLACES = [
	{
		"id": "plaza",
		"label": "Plaza",
		"role": "mock place",
		"position": Vector2(90, 80),
		"radius": 95.0,
		"rest_capable": true,
		"rest_safety": "safe"
	},
	{
		"id": "z_grove",
		"label": "Grove",
		"role": "mock place",
		"position": Vector2(355, 245),
		"radius": 90.0,
		"rest_capable": true,
		"rest_safety": "uncertain"
	}
]

const SAFETY_DANGER_PLACE = {
	"id": "danger_gully",
	"label": "Danger Gully",
	"role": "mock place",
	"position": Vector2(260, 180),
	"radius": 85.0,
	"danger_capable": true,
	"danger_level": "high"
}

const SAFETY_SHELTER_PLACE = {
	"id": "shelter_east",
	"label": "East Shelter",
	"role": "mock place",
	"position": Vector2(260, 120),
	"radius": 42.0,
	"rest_capable": true,
	"rest_safety": "safe"
}

const SAFETY_MOVING_THREAT = {
	"id": "threat_01",
	"label": "Mock Dangerous Creature",
	"role": "mock object",
	"kind": "dangerous_creature",
	"position": Vector2(260, 180),
	"threat_capable": true,
	"threat_radius": 70.0,
	"danger_level": "high"
}

const PERCEPTION_RADIUS = 145.0
const ACTION_STEP_DISTANCE = 36.0
const PICKUP_DISTANCE = 8.0
const FOOD_NEED_PER_TICK = 0.02
const FOOD_RECOVERY = 0.6
const REST_NEED_PER_TICK = 0.03
const REST_RECOVERY = 0.6
const SLEEP_RECOVERY = 0.9
const ACTIVE_ENERGY_INITIAL = 1.0
const ACTIVE_ENERGY_APPROACH_COST = 0.08
const ACTIVE_ENERGY_REST_RECOVERY = 0.25
const ACTIVE_ENERGY_SLEEP_RECOVERY = 0.75
const ENERGY_RESERVE_INITIAL = 0.4
const ENERGY_RESERVE_SLEEP_RECOVERY = 0.4
const THREAT_STEP_DISTANCE = 12.0
const REST_REACH_DISTANCE = 12.0
const BASE_ID = "plaza"
const BASE_FOOD_INITIAL = 1.0
const BASE_FOOD_CAPACITY = 10.0
const BASE_FOOD_DEPOSIT = 4.0
const BASE_FOOD_CONSUMPTION_PER_TICK = 0.15
const BASE_REACH_DISTANCE = 12.0

var tick = 0
var agents = []
var objects = []
var places = []
var events = []
var decision_records = []
var action_offsets = {}
var resolution_records = []
var observation_seq = 0
var body_states = {}
var food_actions_enabled = true
var rest_actions_enabled = false
var sleep_actions_enabled = false
var sleep_window_enabled = false
var active_energy_enabled = false
var energy_reserve_enabled = false
var safety_actions_enabled = false
var food_safety_integration_enabled = false
var moving_threat_enabled = false
var mock_wandering_enabled = true
var base_food_stock = BASE_FOOD_INITIAL
var base_food_revision = 0
var god_statue_cue_enabled = true
var interrupt_candidates = []
var observation_resolution_profile = ObservationResolutionProfileScript.new()
var observation_resolution_enabled = false
var mock_rest_contexts = {}

func reset():
	tick = 0
	observation_seq = 0
	body_states = {}
	mock_rest_contexts = {
		"npc_a": {"fatigue_band": "tired", "previous_fatigue_band": "tiring"},
		"npc_b": {"fatigue_band": "tired", "previous_fatigue_band": "tiring"}
	}
	base_food_stock = BASE_FOOD_INITIAL
	base_food_revision = 0
	god_statue_cue_enabled = true
	interrupt_candidates = []
	agents = []
	for agent in INITIAL_AGENTS:
		agents.append(agent.duplicate(true))
		body_states[agent["id"]] = {
			"movement_scale": 1.0,
			"food_need": 0.8,
			"rest_need": 0.8,
			"active_energy": ACTIVE_ENERGY_INITIAL,
			"active_energy_capacity": ACTIVE_ENERGY_INITIAL,
			"energy_reserve": ENERGY_RESERVE_INITIAL,
			"held_food_ids": [],
			"revision": 0
		}
	action_offsets = {}
	for agent in agents:
		action_offsets[agent["id"]] = Vector2.ZERO
	objects = []
	for object_data in INITIAL_OBJECTS:
		objects.append(object_data.duplicate(true))
	if safety_actions_enabled and moving_threat_enabled:
		objects.append(SAFETY_MOVING_THREAT.duplicate(true))
	places = []
	for place in INITIAL_PLACES:
		places.append(place.duplicate(true))
	if safety_actions_enabled and not moving_threat_enabled:
		places.append(SAFETY_DANGER_PLACE.duplicate(true))
	if food_safety_integration_enabled:
		places.append(SAFETY_SHELTER_PLACE.duplicate(true))
	events = ["tick 000: workbench reset"]
	decision_records = [_build_decision_record("npc_a"), _build_decision_record("npc_b")]
	resolution_records = []
	return get_state()

func step():
	tick += 1
	_consume_base_food()
	_update_food_needs()
	_update_rest_needs()
	_update_mock_positions()
	decision_records.append(_build_decision_record("npc_a"))
	decision_records.append(_build_decision_record("npc_b"))
	if decision_records.size() > 80:
		decision_records.pop_front()
	events.append(_build_mock_event())
	if events.size() > 80:
		events.pop_front()
	return get_state()

func get_state():
	return {
		"tick": tick,
		"agents": agents.duplicate(true),
		"objects": objects.duplicate(true),
		"places": places.duplicate(true),
		"base_food_stock": base_food_stock,
		"base_food_band": _base_food_band(),
		"perception_radius": PERCEPTION_RADIUS,
		"decision_records": decision_records.duplicate(true),
		"resolution_records": resolution_records.duplicate(true),
		"events": events.duplicate(true)
	}

func get_agent(agent_id):
	for agent in agents:
		if agent.get("id", "") == agent_id:
			return agent.duplicate(true)
	return {}

func get_observation(agent_id):
	var agent = get_agent(agent_id)
	if agent.is_empty():
		return {}

	var visible_agents = []
	for other in agents:
		if other.get("id", "") == agent_id:
			continue
		if _is_visible(agent["position"], other["position"], PERCEPTION_RADIUS):
			visible_agents.append(other.duplicate(true))

	var visible_objects = []
	for object_data in objects:
		if _is_visible(agent["position"], object_data["position"], PERCEPTION_RADIUS):
			var visible_object = object_data.duplicate(true)
			if object_data.get("kind", "") == "food":
				visible_object["within_reach"] = agent["position"].distance_to(object_data["position"]) <= PICKUP_DISTANCE
			visible_objects.append(visible_object)

	var visible_places = []
	for place in places:
		if _is_visible(agent["position"], place["position"], PERCEPTION_RADIUS + place.get("radius", 0.0)):
			var visible_place = place.duplicate(true)
			if rest_actions_enabled and place.get("rest_capable", false):
				var rest_distance = agent["position"].distance_to(place["position"])
				visible_place["within_reach"] = rest_distance <= REST_REACH_DISTANCE
				visible_place["rest_distance_band"] = _rest_distance_band(rest_distance)
			visible_places.append(visible_place)

	var observation = {
		"observation_id": _next_observation_id(agent_id),
		"tick": tick,
		"agent_id": agent_id,
		"perception_rule": "distance <= %.1f from agent position" % PERCEPTION_RADIUS,
		"visible_agents": visible_agents,
		"visible_objects": visible_objects,
		"visible_places": visible_places
	}
	if safety_actions_enabled:
		observation["safety_context"] = _build_safety_context(agent, visible_places)
	if observation_resolution_enabled:
		var domains = {}
		for domain in observation_resolution_profile.explicit_domains(agent_id):
			var projection = get_selected_resolution_projection(agent_id, domain)
			if not projection.is_empty():
				domains[domain] = projection
		if not domains.is_empty():
			observation["observation_resolution"] = {
				"schema_version": "rho-observation-resolution-packet-v1",
				"domains": domains
			}
	return observation

func get_latest_decision(agent_id):
	for i in range(decision_records.size() - 1, -1, -1):
		var record = decision_records[i]
		if record.get("agent_id", "") == agent_id:
			return record.duplicate(true)
	return {}

func resolve_action(decision):
	var action = decision.get("action", {})
	var action_type = action.get("type", "idle")
	if action_type == "approach":
		return _resolve_approach(decision, action.get("target_id", ""))
	if action_type == "pickup":
		return _resolve_pickup(decision, action.get("target_id", ""))
	if action_type == "eat":
		return _resolve_eat(decision, action.get("target_id", ""))
	if action_type == "deposit":
		return _resolve_deposit(decision, action.get("target_id", ""))
	if action_type == "rest":
		return _resolve_rest(decision, action.get("target_id", ""))
	if action_type == "sleep":
		return _resolve_sleep(decision, action.get("target_id", ""))
	if action_type == "flee":
		return _resolve_flee(decision, action.get("target_id", ""))
	return _record_resolution(decision.get("agent_id", ""), action_type, "", "no world change for action")

func get_latest_resolution(agent_id):
	for i in range(resolution_records.size() - 1, -1, -1):
		var record = resolution_records[i]
		if record.get("agent_id", "") == agent_id:
			return record.duplicate(true)
	return {}

func set_movement_scale(agent_id, scale):
	if not body_states.has(agent_id) or not is_finite(float(scale)) or scale < 0.0 or scale > 1.0:
		return false
	var body = body_states[agent_id]
	if body["movement_scale"] != scale:
		body["movement_scale"] = float(scale)
		body["revision"] += 1
	return true

func get_body_snapshot(agent_id):
	if not body_states.has(agent_id):
		return {}
	var body = body_states[agent_id]
	var snapshot = {
		"agent_id": agent_id,
		"movement_scale": body["movement_scale"],
		"food_actions_enabled": food_actions_enabled,
		"food_need": body["food_need"],
		"held_food_ids": body["held_food_ids"].duplicate(),
		"revision": body["revision"],
		"snapshot_id": "body-%s-%d" % [agent_id, body["revision"]]
	}
	if rest_actions_enabled:
		snapshot["rest_actions_enabled"] = true
		snapshot["rest_need"] = body["rest_need"]
	if sleep_actions_enabled:
		snapshot["sleep_actions_enabled"] = true
		snapshot["sleep_window"] = sleep_window_enabled
	if active_energy_enabled:
		snapshot["active_energy"] = body["active_energy"]
		snapshot["active_energy_capacity"] = body["active_energy_capacity"]
	if energy_reserve_enabled:
		snapshot["energy_reserve"] = body["energy_reserve"]
	if safety_actions_enabled:
		snapshot["safety_actions_enabled"] = true
	if food_safety_integration_enabled:
		snapshot["food_safety_integration_enabled"] = true
	return snapshot

func set_active_energy_enabled(enabled):
	active_energy_enabled = bool(enabled)

func set_active_energy_capacity(agent_id, capacity):
	if not body_states.has(agent_id) or typeof(capacity) not in [TYPE_FLOAT, TYPE_INT]:
		return false
	var numeric_capacity = float(capacity)
	if not is_finite(numeric_capacity) or numeric_capacity <= 0.0 or numeric_capacity > 1.0:
		return false
	var body = body_states[agent_id]
	if is_equal_approx(body["active_energy_capacity"], numeric_capacity):
		return true
	body["active_energy_capacity"] = numeric_capacity
	body["active_energy"] = min(body["active_energy"], numeric_capacity)
	body["revision"] += 1
	return true

func set_energy_reserve_enabled(enabled):
	energy_reserve_enabled = bool(enabled)

func set_safety_actions_enabled(enabled):
	food_safety_integration_enabled = false
	safety_actions_enabled = bool(enabled)
	if safety_actions_enabled:
		food_actions_enabled = false
		rest_actions_enabled = false
		sleep_actions_enabled = false
		sleep_window_enabled = false
		if moving_threat_enabled and _get_object(SAFETY_MOVING_THREAT["id"]).is_empty():
			objects.append(SAFETY_MOVING_THREAT.duplicate(true))
		elif not moving_threat_enabled and _get_place(SAFETY_DANGER_PLACE["id"]).is_empty():
			places.append(SAFETY_DANGER_PLACE.duplicate(true))
	else:
		for index in range(places.size() - 1, -1, -1):
			if places[index].get("id", "") == SAFETY_DANGER_PLACE["id"]:
				places.remove_at(index)
		for index in range(objects.size() - 1, -1, -1):
			if objects[index].get("id", "") == SAFETY_MOVING_THREAT["id"]:
				objects.remove_at(index)

func set_food_safety_integration_enabled(enabled):
	food_safety_integration_enabled = bool(enabled)
	food_actions_enabled = bool(enabled)
	safety_actions_enabled = bool(enabled)
	rest_actions_enabled = false
	sleep_actions_enabled = false
	set_danger_fixture_enabled(false)
	for index in range(places.size() - 1, -1, -1):
		if places[index].get("id", "") == SAFETY_SHELTER_PLACE["id"]:
			places.remove_at(index)
	if food_safety_integration_enabled:
		places.append(SAFETY_SHELTER_PLACE.duplicate(true))

func set_danger_fixture_enabled(enabled, agent_id = ""):
	for index in range(places.size() - 1, -1, -1):
		if places[index].get("id", "") == SAFETY_DANGER_PLACE["id"]:
			places.remove_at(index)
	if not enabled:
		return
	var danger = SAFETY_DANGER_PLACE.duplicate(true)
	if not agent_id.is_empty():
		var agent = get_agent(agent_id)
		if not agent.is_empty():
			danger["position"] = agent["position"]
	places.append(danger)

func set_moving_threat_enabled(enabled):
	moving_threat_enabled = bool(enabled)
	for index in range(places.size() - 1, -1, -1):
		if places[index].get("id", "") == SAFETY_DANGER_PLACE["id"]:
			places.remove_at(index)
	for index in range(objects.size() - 1, -1, -1):
		if objects[index].get("id", "") == SAFETY_MOVING_THREAT["id"]:
			objects.remove_at(index)
	if safety_actions_enabled:
		if moving_threat_enabled:
			objects.append(SAFETY_MOVING_THREAT.duplicate(true))
		else:
			places.append(SAFETY_DANGER_PLACE.duplicate(true))

func get_life_context(agent_id):
	var agent = get_agent(agent_id)
	var base = _get_place(BASE_ID)
	if agent.is_empty() or base.is_empty():
		return {}
	var band = _base_food_band()
	var cue = null
	if god_statue_cue_enabled:
		cue = {
			"source": "system_assessment",
			"topic": "base_food",
			"band": band,
			"delivery": "morning",
			"cue_id": "god-food-%03d" % base_food_revision,
			"assessment_revision": base_food_revision
		}
	return {
		"god_statue_cue": cue,
		"observed_base_food_band": band,
		"known_base": {
			"id": BASE_ID,
			"relative_position": [
				base["position"].x - agent["position"].x,
				base["position"].y - agent["position"].y
			]
		},
		"at_base": agent["position"].distance_to(base["position"]) <= BASE_REACH_DISTANCE,
		"interrupt_candidates": interrupt_candidates.duplicate(true)
	}

func set_interrupt_candidates(candidates):
	interrupt_candidates = candidates.duplicate(true)

func get_food_resolution_projection(agent_id, level):
	var agent = get_agent(agent_id)
	if agent.is_empty():
		return {}
	var food_site_visible = false
	for object_data in objects:
		if object_data.get("kind", "") == "food" and _is_visible(agent["position"], object_data["position"], PERCEPTION_RADIUS):
			food_site_visible = true
			break
	return ObservationResolutionAdapterScript.project_food(
		level, _base_food_band(), base_food_revision, food_site_visible
	)

func configure_observation_resolution(assignments):
	if not observation_resolution_profile.configure(assignments):
		return false
	observation_resolution_enabled = true
	return true

func disable_observation_resolution():
	observation_resolution_enabled = false

func get_selected_food_resolution_projection(agent_id):
	var selection = observation_resolution_profile.select(agent_id, "food")
	if selection.is_empty():
		return {}
	var projection = get_food_resolution_projection(agent_id, selection["level"])
	if projection.is_empty():
		return {}
	projection["selection"] = selection
	return projection

func get_rest_resolution_projection(agent_id, level):
	var agent = get_agent(agent_id)
	if agent.is_empty() or not mock_rest_contexts.has(agent_id):
		return {}
	var rest_context = {"availability": "not_observed", "safety": "unknown"}
	for place in places:
		if place.get("rest_capable", false) and _is_visible(
			agent["position"], place["position"], PERCEPTION_RADIUS + place.get("radius", 0.0)
		):
			rest_context = {"availability": "available", "safety": place.get("rest_safety", "unknown")}
			break
	var source = mock_rest_contexts[agent_id]
	return ObservationResolutionAdapterScript.project_rest(
		level, source["fatigue_band"], source["previous_fatigue_band"], rest_context
	)

func get_selected_rest_resolution_projection(agent_id):
	var selection = observation_resolution_profile.select(agent_id, "rest")
	if selection.is_empty():
		return {}
	var projection = get_rest_resolution_projection(agent_id, selection["level"])
	if projection.is_empty():
		return {}
	projection["selection"] = selection
	return projection

func get_selected_resolution_projection(agent_id, domain):
	if domain == "food":
		return get_selected_food_resolution_projection(agent_id)
	if domain == "rest":
		return get_selected_rest_resolution_projection(agent_id)
	return {}

func get_observation_resolution_assignments():
	return observation_resolution_profile.snapshot()

func set_god_statue_cue_enabled(enabled):
	god_statue_cue_enabled = bool(enabled)

func set_food_actions_enabled(enabled):
	food_actions_enabled = bool(enabled)

func set_mock_wandering_enabled(enabled):
	mock_wandering_enabled = bool(enabled)

func replenish_food_site(observer_agent_id = ""):
	if not _get_object("food_01").is_empty():
		return false
	var replenished_food = INITIAL_OBJECTS[0].duplicate(true)
	if not observer_agent_id.is_empty():
		var observer = get_agent(observer_agent_id)
		if observer.is_empty():
			return false
		replenished_food["position"] = observer["position"] + Vector2(100, 40)
	objects.append(replenished_food)
	events.append("tick %03d: finite Food Site supply replenished" % tick)
	if events.size() > 80:
		events.pop_front()
	return true

func set_rest_actions_enabled(enabled):
	rest_actions_enabled = bool(enabled)
	if rest_actions_enabled:
		food_actions_enabled = false
		sleep_actions_enabled = false
		sleep_window_enabled = false

func set_sleep_actions_enabled(enabled):
	sleep_actions_enabled = bool(enabled)
	rest_actions_enabled = sleep_actions_enabled
	if sleep_actions_enabled:
		food_actions_enabled = false

func set_sleep_window(enabled):
	sleep_window_enabled = bool(enabled)

func get_interaction_result(resolution):
	if resolution.get("action_type", "") != "approach":
		return {}
	if not resolution.has("before_position") or not resolution.has("after_position"):
		return {}
	var outcome = "approach_no_progress"
	if resolution["before_position"] != resolution["after_position"]:
		outcome = "approach_progress"
	return {
		"agent_id": resolution["agent_id"],
		"source_observation_id": resolution["source_observation_id"],
		"subsequent_observation_id": resolution["subsequent_observation_id"],
		"target_id": resolution["target_id"],
		"tick": resolution["tick"],
		"outcome": outcome
	}

func get_life_result(decision, resolution):
	if resolution.get("action_type", "") != "deposit":
		return {}
	var effects = resolution.get("effects", {})
	if effects.get("base_food_band", "") != "enough":
		return {}
	var life = decision.get("inspection", {}).get("life", {})
	var cue = life.get("cue")
	if typeof(cue) != TYPE_DICTIONARY:
		return {}
	var source_observation_id = resolution.get("source_observation_id", "")
	return {
		"result_id": "life-%s-deposit" % source_observation_id,
		"agent_id": resolution.get("agent_id", ""),
		"source_observation_id": source_observation_id,
		"cue_id": cue.get("cue_id", ""),
		"response": life.get("cue_response", ""),
		"outcome": "replenish_success"
	}

func _update_mock_positions():
	if not mock_wandering_enabled:
		return
	for i in range(agents.size()):
		var agent = agents[i]
		var base = INITIAL_AGENTS[i]["position"]
		var phase = float(tick + i * 3)
		var offset = action_offsets.get(agent["id"], Vector2.ZERO)
		var desired = base + Vector2(sin(phase * 0.35) * 18.0, cos(phase * 0.25) * 12.0) + offset
		agent["position"] += (desired - agent["position"]) * body_states[agent["id"]]["movement_scale"]
		if (tick + i) % 2 == 0:
			agent["mood"] = "curious"
		else:
			agent["mood"] = "observing"

func _update_food_needs():
	for agent_id in body_states:
		var body = body_states[agent_id]
		var next_need = min(1.0, body["food_need"] + FOOD_NEED_PER_TICK)
		if not is_equal_approx(next_need, body["food_need"]):
			body["food_need"] = next_need
			body["revision"] += 1

func _update_rest_needs():
	if not rest_actions_enabled:
		return
	for agent_id in body_states:
		var body = body_states[agent_id]
		var next_need = min(1.0, body["rest_need"] + REST_NEED_PER_TICK)
		if not is_equal_approx(next_need, body["rest_need"]):
			body["rest_need"] = next_need
			body["revision"] += 1

func _consume_base_food():
	if base_food_stock <= 0.0:
		return
	var before_stock = base_food_stock
	base_food_stock = max(0.0, base_food_stock - BASE_FOOD_CONSUMPTION_PER_TICK)
	base_food_revision += 1
	events.append("tick %03d: Base food consumed %.2f -> %.2f (%s)" % [
		tick, before_stock, base_food_stock, _base_food_band()
	])
	if events.size() > 80:
		events.pop_front()

func _build_mock_event():
	var actor = agents[tick % agents.size()]
	var action = "wanders through the mock world"
	if tick % 3 == 0:
		action = "observes the food object"
	return "tick %03d: %s %s" % [tick, actor["label"], action]

func _build_decision_record(agent_id):
	var observation = get_observation(agent_id)
	var visible_count = observation.get("visible_agents", []).size() + observation.get("visible_objects", []).size() + observation.get("visible_places", []).size()
	var chosen_action = "wait"
	var decision_reason = "nothing visible inside bounded observation"
	if visible_count > 0:
		chosen_action = "approach_visible_context"
		decision_reason = "uses only visible agents, objects, and places"
	return {
		"tick": tick,
		"agent_id": agent_id,
		"observation_summary": "%d visible item(s)" % visible_count,
		"chosen_action": chosen_action,
		"decision_reason": decision_reason
	}

func _is_visible(origin, target, radius):
	return origin.distance_to(target) <= radius

func _resolve_approach(decision, target_id):
	var agent_id = decision.get("agent_id", "")
	var agent_index = _find_agent_index(agent_id)
	var target = _get_target(target_id)
	if agent_index == -1 or target.is_empty():
		return _record_resolution(agent_id, "approach", target_id, "target or agent not found")

	var agent = agents[agent_index]
	var before_position = agent["position"]
	var direction = target["position"] - before_position
	var step_distance = ACTION_STEP_DISTANCE * body_states[agent_id]["movement_scale"]
	if direction.length() > step_distance:
		direction = direction.normalized() * step_distance
	var after_position = before_position + direction
	agent["position"] = after_position
	action_offsets[agent_id] = action_offsets.get(agent_id, Vector2.ZERO) + direction
	var energy_effects = {}
	if active_energy_enabled and direction.length() > 0.0:
		energy_effects = _change_active_energy(agent_id, -ACTIVE_ENERGY_APPROACH_COST)

	var before_observation = decision.get("inspection", {}).get("observation_id", "")
	var subsequent_observation = get_observation(agent_id)
	var summary = "%d visible object(s)" % subsequent_observation.get("visible_objects", []).size()
	return _record_resolution(
		agent_id,
		"approach",
		target_id,
		"actual response moved agent; changed conditions now yield %s" % summary,
		before_position,
		after_position,
		before_observation,
		subsequent_observation.get("observation_id", ""),
		energy_effects
	)

func _resolve_pickup(decision, target_id):
	var agent_id = decision.get("agent_id", "")
	var agent_index = _find_agent_index(agent_id)
	var object_index = _find_object_index(target_id)
	var source_observation_id = decision.get("inspection", {}).get("observation_id", "")
	if agent_index == -1 or object_index == -1:
		return _record_resolution(agent_id, "pickup", target_id, "target or agent not found")
	var target = objects[object_index]
	if target.get("kind", "") != "food":
		return _record_resolution(agent_id, "pickup", target_id, "target is not food")
	if agents[agent_index]["position"].distance_to(target["position"]) > PICKUP_DISTANCE:
		return _record_resolution(agent_id, "pickup", target_id, "target is outside pickup reach")
	var body = body_states[agent_id]
	objects.remove_at(object_index)
	body["held_food_ids"].append(target_id)
	body["revision"] += 1
	var subsequent_observation = get_observation(agent_id)
	return _record_resolution(
		agent_id, "pickup", target_id, "food moved from world to agent inventory",
		null, null, source_observation_id, subsequent_observation.get("observation_id", ""),
		{"held_food_ids": body["held_food_ids"].duplicate(), "food_need": body["food_need"]}
	)

func _resolve_eat(decision, target_id):
	var agent_id = decision.get("agent_id", "")
	var source_observation_id = decision.get("inspection", {}).get("observation_id", "")
	if not body_states.has(agent_id):
		return _record_resolution(agent_id, "eat", target_id, "agent not found")
	var body = body_states[agent_id]
	var held_index = body["held_food_ids"].find(target_id)
	if held_index == -1:
		return _record_resolution(agent_id, "eat", target_id, "food is not held")
	var before_need = body["food_need"]
	body["held_food_ids"].remove_at(held_index)
	body["food_need"] = max(0.0, before_need - FOOD_RECOVERY)
	body["revision"] += 1
	var subsequent_observation = get_observation(agent_id)
	return _record_resolution(
		agent_id, "eat", target_id, "held food consumed; FoodNeed decreased",
		null, null, source_observation_id, subsequent_observation.get("observation_id", ""),
		{"before_food_need": before_need, "after_food_need": body["food_need"],
			"held_food_ids": body["held_food_ids"].duplicate()}
	)

func _resolve_deposit(decision, target_id):
	var agent_id = decision.get("agent_id", "")
	var agent_index = _find_agent_index(agent_id)
	var source_observation_id = decision.get("inspection", {}).get("observation_id", "")
	var base = _get_place(BASE_ID)
	if agent_index == -1 or target_id != BASE_ID or base.is_empty():
		return _record_resolution(agent_id, "deposit", target_id, "Base or agent not found")
	if agents[agent_index]["position"].distance_to(base["position"]) > BASE_REACH_DISTANCE:
		return _record_resolution(agent_id, "deposit", target_id, "agent is outside Base reach")
	var body = body_states[agent_id]
	if body["held_food_ids"].is_empty():
		return _record_resolution(agent_id, "deposit", target_id, "no held food to deposit")
	var deposited_ids = body["held_food_ids"].duplicate()
	var before_stock = base_food_stock
	body["held_food_ids"] = []
	body["revision"] += 1
	base_food_stock = min(BASE_FOOD_CAPACITY, base_food_stock + BASE_FOOD_DEPOSIT * deposited_ids.size())
	base_food_revision += 1
	var subsequent_observation = get_observation(agent_id)
	return _record_resolution(
		agent_id, "deposit", target_id, "held food deposited; Base stock increased",
		null, null, source_observation_id, subsequent_observation.get("observation_id", ""),
		{"deposited_food_ids": deposited_ids, "before_base_food_stock": before_stock,
			"after_base_food_stock": base_food_stock, "base_food_band": _base_food_band(),
			"held_food_ids": []}
	)

func _resolve_rest(decision, target_id):
	var agent_id = decision.get("agent_id", "")
	var agent_index = _find_agent_index(agent_id)
	var place = _get_place(target_id)
	var source_observation_id = decision.get("inspection", {}).get("observation_id", "")
	if not rest_actions_enabled or agent_index == -1 or place.is_empty() or not place.get("rest_capable", false):
		return _record_resolution(agent_id, "rest", target_id, "Rest action or target is unavailable")
	if agents[agent_index]["position"].distance_to(place["position"]) > REST_REACH_DISTANCE:
		return _record_resolution(agent_id, "rest", target_id, "agent is outside rest reach")
	var body = body_states[agent_id]
	var before_need = body["rest_need"]
	body["rest_need"] = max(0.0, before_need - REST_RECOVERY)
	body["revision"] += 1
	var energy_effects = _change_active_energy(agent_id, ACTIVE_ENERGY_REST_RECOVERY)
	var subsequent_observation = get_observation(agent_id)
	energy_effects.merge({"before_rest_need": before_need, "after_rest_need": body["rest_need"],
		"rest_kind": "short_rest"})
	return _record_resolution(
		agent_id, "rest", target_id, "short rest completed; RestNeed decreased",
		null, null, source_observation_id, subsequent_observation.get("observation_id", ""),
		energy_effects
	)

func _resolve_sleep(decision, target_id):
	var agent_id = decision.get("agent_id", "")
	var agent_index = _find_agent_index(agent_id)
	var place = _get_place(target_id)
	var source_observation_id = decision.get("inspection", {}).get("observation_id", "")
	if not sleep_actions_enabled or not sleep_window_enabled:
		return _record_resolution(agent_id, "sleep", target_id, "Sleep action is outside the finite sleep window")
	if agent_index == -1 or place.is_empty() or not place.get("rest_capable", false):
		return _record_resolution(agent_id, "sleep", target_id, "Sleep target is unavailable")
	if place.get("rest_safety", "unknown") != "safe":
		return _record_resolution(agent_id, "sleep", target_id, "long sleep requires a bounded safe place")
	if agents[agent_index]["position"].distance_to(place["position"]) > REST_REACH_DISTANCE:
		return _record_resolution(agent_id, "sleep", target_id, "agent is outside sleep reach")
	var body = body_states[agent_id]
	var before_need = body["rest_need"]
	body["rest_need"] = max(0.0, before_need - SLEEP_RECOVERY)
	body["revision"] += 1
	var energy_effects = _change_active_energy(agent_id, ACTIVE_ENERGY_SLEEP_RECOVERY)
	energy_effects.merge(_change_energy_reserve(agent_id, ENERGY_RESERVE_SLEEP_RECOVERY))
	var subsequent_observation = get_observation(agent_id)
	energy_effects.merge({"before_rest_need": before_need, "after_rest_need": body["rest_need"],
		"sleep_kind": "bounded_sleep", "consolidation": "not_run"})
	return _record_resolution(
		agent_id, "sleep", target_id, "bounded sleep completed; RestNeed decreased",
		null, null, source_observation_id, subsequent_observation.get("observation_id", ""),
		energy_effects
	)

func _resolve_flee(decision, target_id):
	var agent_id = decision.get("agent_id", "")
	var agent_index = _find_agent_index(agent_id)
	var target = _get_place(target_id)
	if not safety_actions_enabled or agent_index == -1 or target.is_empty():
		return _record_resolution(agent_id, "flee", target_id, "Safety action or target is unavailable")
	if target.get("rest_safety", "unknown") != "safe":
		return _record_resolution(agent_id, "flee", target_id, "flee target is not a bounded safe place")
	var before_position = agents[agent_index]["position"]
	var direction = target["position"] - before_position
	var step_distance = ACTION_STEP_DISTANCE * body_states[agent_id]["movement_scale"]
	if direction.length() > step_distance:
		direction = direction.normalized() * step_distance
	var after_position = before_position + direction
	agents[agent_index]["position"] = after_position
	action_offsets[agent_id] = action_offsets.get(agent_id, Vector2.ZERO) + direction
	if moving_threat_enabled:
		_move_threat_toward(after_position)
	var subsequent_observation = get_observation(agent_id)
	var subsequent_safety = subsequent_observation.get("safety_context", {})
	return _record_resolution(
		agent_id, "flee", target_id, "bounded flee changed danger exposure",
		before_position, after_position,
		decision.get("inspection", {}).get("observation_id", ""),
		subsequent_observation.get("observation_id", ""),
		{"before_exposed": true, "after_exposed": subsequent_safety.get("exposed", false),
			"safety_model": "bounded-danger-zone-v1"}
	)

func _build_safety_context(agent, visible_places):
	var danger_candidates = []
	for place in places:
		if place.get("danger_capable", false) and agent["position"].distance_to(place["position"]) <= place.get("radius", 0.0):
			danger_candidates.append({
				"danger_id": place["id"],
				"severity": place.get("danger_level", "low")
			})
	for object_data in objects:
		if object_data.get("threat_capable", false) and agent["position"].distance_to(object_data["position"]) <= object_data.get("threat_radius", 0.0):
			danger_candidates.append({
				"danger_id": object_data["id"],
				"severity": object_data.get("danger_level", "low")
			})
	var safe_candidates = []
	var reached_safe_target_id = ""
	for place in visible_places:
		var safety = place.get("rest_safety", "unknown")
		if safety not in ["safe", "uncertain"]:
			continue
		var distance = agent["position"].distance_to(place["position"])
		safe_candidates.append({
			"target_id": place["id"],
			"safety": safety,
			"distance_band": _rest_distance_band(distance)
		})
		if reached_safe_target_id.is_empty() and distance <= REST_REACH_DISTANCE:
			reached_safe_target_id = place["id"]
	return {
		"schema_version": "bounded-safety-context-v1",
		"exposed": not danger_candidates.is_empty(),
		"danger_candidates": danger_candidates,
		"safe_candidates": safe_candidates,
		"safe_reached": not reached_safe_target_id.is_empty(),
		"reached_safe_target_id": reached_safe_target_id
	}

func _move_threat_toward(target_position):
	for index in range(objects.size()):
		if objects[index].get("id", "") != SAFETY_MOVING_THREAT["id"]:
			continue
		var direction = target_position - objects[index]["position"]
		if direction.length() > THREAT_STEP_DISTANCE:
			direction = direction.normalized() * THREAT_STEP_DISTANCE
		objects[index]["position"] += direction
		return

func _change_active_energy(agent_id, delta):
	if not active_energy_enabled or not body_states.has(agent_id):
		return {}
	var body = body_states[agent_id]
	var before_energy = body["active_energy"]
	body["active_energy"] = clamp(before_energy + delta, 0.0, body["active_energy_capacity"])
	if not is_equal_approx(before_energy, body["active_energy"]):
		body["revision"] += 1
	return {
		"before_active_energy": before_energy,
		"after_active_energy": body["active_energy"],
		"energy_model": "active-energy-v1"
	}

func _change_energy_reserve(agent_id, delta):
	if not energy_reserve_enabled or not body_states.has(agent_id):
		return {}
	var body = body_states[agent_id]
	var before_reserve = body["energy_reserve"]
	body["energy_reserve"] = clamp(before_reserve + delta, 0.0, 1.0)
	if not is_equal_approx(before_reserve, body["energy_reserve"]):
		body["revision"] += 1
	return {
		"before_energy_reserve": before_reserve,
		"after_energy_reserve": body["energy_reserve"],
		"reserve_model": "energy-reserve-v1"
	}

func _record_resolution(agent_id, action_type, target_id, note, before_position = null, after_position = null, source_observation_id = "", subsequent_observation_id = "", effects = {}):
	var record = {
		"tick": tick,
		"agent_id": agent_id,
		"action_type": action_type,
		"target_id": target_id,
		"note": note,
		"source_observation_id": source_observation_id,
		"subsequent_observation_id": subsequent_observation_id
	}
	if before_position != null and after_position != null:
		record["before_position"] = before_position
		record["after_position"] = after_position
	if not effects.is_empty():
		record["effects"] = effects.duplicate(true)
	resolution_records.append(record)
	if resolution_records.size() > 80:
		resolution_records.pop_front()
	events.append("tick %03d: resolved %s for %s -> %s" % [tick, action_type, agent_id, note])
	if events.size() > 80:
		events.pop_front()
	return record

func _find_agent_index(agent_id):
	for i in range(agents.size()):
		if agents[i].get("id", "") == agent_id:
			return i
	return -1

func _get_object(object_id):
	for object_data in objects:
		if object_data.get("id", "") == object_id:
			return object_data
	return {}

func _get_place(place_id):
	for place in places:
		if place.get("id", "") == place_id:
			return place
	return {}

func _get_target(target_id):
	var object_data = _get_object(target_id)
	if not object_data.is_empty():
		return object_data
	return _get_place(target_id)

func _base_food_band():
	if base_food_stock <= 0.0:
		return "empty"
	if base_food_stock <= 1.0:
		return "critical"
	if base_food_stock <= 2.0:
		return "low"
	return "enough"

func _rest_distance_band(distance):
	if distance <= REST_REACH_DISTANCE:
		return "within_reach"
	if distance <= 180.0:
		return "near"
	return "far"

func _find_object_index(object_id):
	for i in range(objects.size()):
		if objects[i].get("id", "") == object_id:
			return i
	return -1

func _next_observation_id(agent_id):
	observation_seq += 1
	return "obs-%06d-%03d-%s" % [tick, observation_seq, agent_id]
