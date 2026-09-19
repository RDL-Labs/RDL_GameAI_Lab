extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_food_safety_integration_enabled(true)
	workbench._on_mode_selected(1)
	var actions = []
	var phases = []
	var flee_targets = []
	var danger_activated = false
	for guard in range(24):
		if not await _wait(workbench):
			return
		var action = workbench.runtime_decision.get("action", {})
		var phase = workbench.runtime_decision.get("inspection", {}).get("food_safety", {}).get("phase", "")
		actions.append(action.get("type", ""))
		phases.append(phase)
		if action.get("type", "") == "flee":
			flee_targets.append(action.get("target_id", ""))
		if action.get("type", "") == "pickup" and not danger_activated:
			workbench.state_provider.set_danger_fixture_enabled(true, "npc_b")
			danger_activated = true
		if action.get("type", "") == "deposit":
			var life_result = workbench.state_provider.get_life_result(
				workbench.runtime_decision, workbench.runtime_resolution
			)
			if life_result.is_empty():
				_fail("deposit did not produce a causal life result: %s / %s" % [
					workbench.runtime_decision, workbench.runtime_resolution
				])
				return
			break
		workbench._request_runtime_action_if_needed()
	if not await _wait(workbench):
		return
	if not danger_activated or not actions.has("flee") or actions[-1] != "deposit":
		_fail("Food-Safety-Food chain did not complete: actions=%s phases=%s" % [actions, phases])
		return
	if not phases.has("FOOD_SUSPENDED") or not phases.has("RESUME"):
		_fail("Food trajectory was not suspended and resumed: %s" % [phases])
		return
	if flee_targets.is_empty() or flee_targets.any(func(target): return target != "shelter_east"):
		_fail("Safety did not commit the distinct Shelter target: %s" % [flee_targets])
		return
	var resumed_index = phases.find("RESUME")
	if resumed_index == -1 or actions[resumed_index] != "approach" or actions[-1] != "deposit":
		_fail("Food did not travel from Shelter back toward Base before deposit: %s / %s" % [actions, phases])
		return
	if not workbench.state_provider.get_body_snapshot("npc_b")["held_food_ids"].is_empty():
		_fail("resumed Food trajectory did not deposit held food")
		return
	if workbench.history_status != "accepted":
		_fail("resumed deposit was not admitted as causal experience: %s" % workbench.history_status)
		return
	print("Food-Safety resume check passed: %s / %s" % [actions, phases])
	workbench.queue_free()
	await process_frame
	quit(0)

func _wait(workbench):
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("Food-Safety Runtime roundtrip timed out")
			return false
		await process_frame
	return true

func _fail(message):
	push_error(message)
	quit(1)
