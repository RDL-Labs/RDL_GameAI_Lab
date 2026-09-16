extends RefCounted
class_name MockStateProvider

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

const INITIAL_FOOD = {
	"id": "food_01",
	"label": "Mock Food",
	"role": "mock object",
	"position": Vector2(190, 260),
	"note": "Clickable selection is limited to mock NPCs in the current workbench."
}

const INITIAL_OBJECTS = [
	{
		"id": "food_01",
		"label": "Mock Food",
		"role": "mock object",
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
		"radius": 95.0
	},
	{
		"id": "grove",
		"label": "Grove",
		"role": "mock place",
		"position": Vector2(355, 245),
		"radius": 90.0
	}
]

const PERCEPTION_RADIUS = 145.0
const ACTION_STEP_DISTANCE = 36.0

var tick = 0
var agents = []
var food = {}
var objects = []
var places = []
var events = []
var decision_records = []
var action_offsets = {}
var resolution_records = []
var observation_seq = 0

func reset():
	tick = 0
	observation_seq = 0
	agents = []
	for agent in INITIAL_AGENTS:
		agents.append(agent.duplicate(true))
	action_offsets = {}
	for agent in agents:
		action_offsets[agent["id"]] = Vector2.ZERO
	food = INITIAL_FOOD.duplicate(true)
	objects = []
	for object_data in INITIAL_OBJECTS:
		objects.append(object_data.duplicate(true))
	places = []
	for place in INITIAL_PLACES:
		places.append(place.duplicate(true))
	events = ["tick 000: workbench reset"]
	decision_records = [_build_decision_record("npc_a"), _build_decision_record("npc_b")]
	resolution_records = []
	return get_state()

func step():
	tick += 1
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
		"food": food.duplicate(true),
		"objects": objects.duplicate(true),
		"places": places.duplicate(true),
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
			visible_objects.append(object_data.duplicate(true))

	var visible_places = []
	for place in places:
		if _is_visible(agent["position"], place["position"], PERCEPTION_RADIUS + place.get("radius", 0.0)):
			visible_places.append(place.duplicate(true))

	return {
		"observation_id": _next_observation_id(agent_id),
		"tick": tick,
		"agent_id": agent_id,
		"perception_rule": "distance <= %.1f from agent position" % PERCEPTION_RADIUS,
		"visible_agents": visible_agents,
		"visible_objects": visible_objects,
		"visible_places": visible_places
	}

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
	return _record_resolution(decision.get("agent_id", ""), action_type, "", "no world change for action")

func get_latest_resolution(agent_id):
	for i in range(resolution_records.size() - 1, -1, -1):
		var record = resolution_records[i]
		if record.get("agent_id", "") == agent_id:
			return record.duplicate(true)
	return {}

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

func _update_mock_positions():
	for i in range(agents.size()):
		var agent = agents[i]
		var base = INITIAL_AGENTS[i]["position"]
		var phase = float(tick + i * 3)
		var offset = action_offsets.get(agent["id"], Vector2.ZERO)
		agent["position"] = base + Vector2(sin(phase * 0.35) * 18.0, cos(phase * 0.25) * 12.0) + offset
		if (tick + i) % 2 == 0:
			agent["mood"] = "curious"
		else:
			agent["mood"] = "observing"

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
	var target = _get_object(target_id)
	if agent_index == -1 or target.is_empty():
		return _record_resolution(agent_id, "approach", target_id, "target or agent not found")

	var agent = agents[agent_index]
	var before_position = agent["position"]
	var direction = target["position"] - before_position
	if direction.length() > ACTION_STEP_DISTANCE:
		direction = direction.normalized() * ACTION_STEP_DISTANCE
	var after_position = before_position + direction
	agent["position"] = after_position
	action_offsets[agent_id] = action_offsets.get(agent_id, Vector2.ZERO) + direction

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
		subsequent_observation.get("observation_id", "")
	)

func _record_resolution(agent_id, action_type, target_id, note, before_position = null, after_position = null, source_observation_id = "", subsequent_observation_id = ""):
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

func _next_observation_id(agent_id):
	observation_seq += 1
	return "obs-%06d-%03d-%s" % [tick, observation_seq, agent_id]
