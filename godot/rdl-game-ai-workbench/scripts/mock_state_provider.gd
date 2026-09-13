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
	"note": "Clickable selection is limited to mock NPCs for P0."
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

var tick = 0
var agents = []
var food = {}
var objects = []
var places = []
var events = []
var decision_records = []

func reset():
	tick = 0
	agents = []
	for agent in INITIAL_AGENTS:
		agents.append(agent.duplicate(true))
	food = INITIAL_FOOD.duplicate(true)
	objects = []
	for object_data in INITIAL_OBJECTS:
		objects.append(object_data.duplicate(true))
	places = []
	for place in INITIAL_PLACES:
		places.append(place.duplicate(true))
	events = ["tick 000: workbench reset"]
	decision_records = [_build_decision_record("npc_a"), _build_decision_record("npc_b")]
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

func _update_mock_positions():
	for i in range(agents.size()):
		var agent = agents[i]
		var base = INITIAL_AGENTS[i]["position"]
		var phase = float(tick + i * 3)
		agent["position"] = base + Vector2(sin(phase * 0.35) * 18.0, cos(phase * 0.25) * 12.0)
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
