extends SceneTree

const MockStateProviderScript = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var provider = MockStateProviderScript.new()
	provider.reset()
	provider.set_rest_actions_enabled(true)
	var initial_body = provider.get_body_snapshot("npc_a")
	provider.step()
	var tired_body = provider.get_body_snapshot("npc_a")
	if tired_body.get("rest_need", 0.0) <= initial_body.get("rest_need", 0.0):
		_fail("RestNeed did not increase with an enabled tick")
		return
	if tired_body.get("food_actions_enabled", true):
		_fail("minimal Rest slice did not isolate Food actions")
		return

	var guard = 0
	while guard < 20:
		var observation = provider.get_observation("npc_a")
		var rest_place = {}
		for place in observation.get("visible_places", []):
			if place.get("rest_capable", false):
				rest_place = place
				break
		if rest_place.is_empty():
			_fail("bounded Rest point disappeared before completion")
			return
		var action_type = "rest" if rest_place.get("within_reach", false) else "approach"
		var decision = {
			"agent_id": "npc_a",
			"action": {"type": action_type, "target_id": rest_place["id"]},
			"inspection": {"observation_id": observation["observation_id"]}
		}
		var resolution = provider.resolve_action(decision)
		if action_type == "rest":
			var effects = resolution.get("effects", {})
			if effects.get("after_rest_need", 1.0) >= effects.get("before_rest_need", 0.0):
				_fail("short rest did not reduce RestNeed")
				return
			if effects.get("rest_kind", "") != "short_rest":
				_fail("Rest resolution provenance missing")
				return
			print("minimal Rest loop check passed: need -> approach -> rest -> recovery")
			quit(0)
			return
		guard += 1

	_fail("minimal Rest loop did not complete within finite steps")

func _fail(message):
	push_error(message)
	quit(1)
