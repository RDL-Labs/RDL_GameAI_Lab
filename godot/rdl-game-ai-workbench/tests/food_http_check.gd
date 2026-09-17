extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	var initial_need = workbench.state_provider.get_body_snapshot("npc_b")["food_need"]
	workbench.state_provider.step()
	var stepped_need = workbench.state_provider.get_body_snapshot("npc_b")["food_need"]
	if not is_equal_approx(stepped_need, initial_need + 0.02):
		_fail("FoodNeed did not increase on tick")
		return
	workbench.state_provider.reset()
	workbench._on_mode_selected(1)
	var actions = []
	for iteration in range(10):
		if iteration > 0:
			workbench._request_runtime_action_if_needed()
		var deadline = Time.get_ticks_msec() + 5000
		while workbench.runtime_pending or workbench.history_pending:
			if Time.get_ticks_msec() > deadline:
				_fail("Food HTTP roundtrip timed out")
				return
			await process_frame
		var action_type = workbench.runtime_decision.get("action", {}).get("type", "")
		actions.append(action_type)
		if action_type == "eat":
			break
	if actions != ["approach", "approach", "approach", "pickup", "eat"]:
		_fail("unexpected Food action chain: %s" % actions)
		return
	var state = workbench.state_provider.get_state()
	for item in state["objects"]:
		if item.get("id", "") == "food_01":
			_fail("consumed food remained in world")
			return
	var body = workbench.state_provider.get_body_snapshot("npc_b")
	if not body["held_food_ids"].is_empty():
		_fail("consumed food remained held")
		return
	if body["food_need"] >= initial_need:
		_fail("eating did not decrease FoodNeed")
		return
	if not workbench.inspector_text.get_parsed_text().contains("reaction: feeding"):
		_fail("Inspector did not show feeding expression")
		return
	if not workbench.timeline_text.get_parsed_text().contains("FoodNeed decreased"):
		_fail("Timeline did not record food consumption")
		return
	workbench._on_reset_pressed()
	var reset_state = workbench.state_provider.get_state()
	if not reset_state["objects"].any(func(item): return item.get("id", "") == "food_01"):
		_fail("Reset did not restore food_01")
		return
	var reset_body = workbench.state_provider.get_body_snapshot("npc_b")
	if not is_equal_approx(reset_body["food_need"], initial_need) or not reset_body["held_food_ids"].is_empty():
		_fail("Reset did not restore FoodNeed and held state")
		return
	print("Food HTTP check passed: actions=%s need=%.2f->%.2f" % [actions, initial_need, body["food_need"]])
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
