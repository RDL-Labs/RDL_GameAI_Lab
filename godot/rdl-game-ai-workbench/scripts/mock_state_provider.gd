extends RefCounted
class_name MockStateProvider

const INITIAL_AGENTS := [
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

const INITIAL_FOOD := {
	"id": "food_01",
	"label": "Mock Food",
	"role": "mock object",
	"position": Vector2(190, 260),
	"note": "Clickable selection is limited to mock NPCs for P0."
}

var tick := 0
var agents: Array[Dictionary] = []
var food: Dictionary = {}
var events: Array[String] = []

func reset() -> Dictionary:
	tick = 0
	agents = []
	for agent in INITIAL_AGENTS:
		agents.append(agent.duplicate(true))
	food = INITIAL_FOOD.duplicate(true)
	events = ["tick 000: workbench reset"]
	return get_state()

func step() -> Dictionary:
	tick += 1
	_update_mock_positions()
	events.append(_build_mock_event())
	if events.size() > 80:
		events.pop_front()
	return get_state()

func get_state() -> Dictionary:
	return {
		"tick": tick,
		"agents": agents.duplicate(true),
		"food": food.duplicate(true),
		"events": events.duplicate(true)
	}

func get_agent(agent_id: String) -> Dictionary:
	for agent in agents:
		if agent.get("id", "") == agent_id:
			return agent.duplicate(true)
	return {}

func _update_mock_positions() -> void:
	for i in range(agents.size()):
		var agent := agents[i]
		var base: Vector2 = INITIAL_AGENTS[i]["position"]
		var phase := float(tick + i * 3)
		agent["position"] = base + Vector2(sin(phase * 0.35) * 18.0, cos(phase * 0.25) * 12.0)
		agent["mood"] = "curious" if (tick + i) % 2 == 0 else "observing"

func _build_mock_event() -> String:
	var actor := agents[tick % agents.size()]
	var action := "observes the food object" if tick % 3 == 0 else "wanders through the mock world"
	return "tick %03d: %s %s" % [tick, actor["label"], action]
