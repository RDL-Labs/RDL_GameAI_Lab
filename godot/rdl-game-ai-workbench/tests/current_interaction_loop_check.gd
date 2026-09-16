extends SceneTree

const MockStateProviderScript = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var provider = MockStateProviderScript.new()
	provider.reset()

	var before_agent = provider.get_agent("npc_b")
	var before_position = before_agent["position"]
	var before_observation = provider.get_observation("npc_b")
	var source_observation_id = before_observation["observation_id"]
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
			"observation_id": source_observation_id
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
	if resolution.get("subsequent_observation_id", "") == source_observation_id:
		_fail("expected subsequent observation id to differ from source observation id")
		return
	if after_observation["tick"] != resolution["tick"]:
		_fail("expected subsequent observation to be generated from the resolution tick")
		return
	var history_result = provider.get_interaction_result(resolution)
	if history_result.get("outcome", "") != "approach_progress":
		_fail("expected bounded progress result")
		return
	if history_result.has("before_position") or history_result.has("after_position"):
		_fail("history result must not export world positions")
		return
	for i in range(20):
		decision["inspection"]["observation_id"] = provider.get_observation("npc_b")["observation_id"]
		resolution = provider.resolve_action(decision)
	if provider.get_interaction_result(resolution).get("outcome", "") != "approach_no_progress":
		_fail("expected no-progress result after reaching the target")
		return

	print("Current interaction loop check passed")
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
