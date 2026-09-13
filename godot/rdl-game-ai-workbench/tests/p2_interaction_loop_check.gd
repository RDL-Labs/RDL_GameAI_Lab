extends SceneTree

const MockStateProviderScript = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var provider = MockStateProviderScript.new()
	provider.reset()

	var before_agent = provider.get_agent("npc_b")
	var before_position = before_agent["position"]
	var before_observation = provider.get_observation("npc_b")
	var visible_food = false
	for item in before_observation["visible_objects"]:
		if item.get("id", "") == "food_01":
			visible_food = true

	if not visible_food:
		_fail("expected npc_b to observe food_01 before action")
		return

	var decision = {
		"agent_id": "npc_b",
		"action": {
			"type": "approach",
			"target_id": "food_01"
		},
		"inspection": {
			"observation_id": "obs-000000-npc_b"
		}
	}

	var resolution = provider.resolve_action(decision)
	var after_agent = provider.get_agent("npc_b")
	var after_position = after_agent["position"]
	var after_observation = provider.get_observation("npc_b")

	if before_position == after_position:
		_fail("expected approach action to change npc_b position")
		return
	if resolution.get("subsequent_observation_id", "") == "":
		_fail("expected resolution to record subsequent observation id")
		return
	if after_observation["tick"] != resolution["tick"]:
		_fail("expected subsequent observation to be generated from the resolution tick")
		return

	print("P2 interaction loop check passed")
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
