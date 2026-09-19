extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_food_rest_integration_enabled(true)
	workbench.state_provider.set_rest_need("npc_b", 0.2)
	workbench._on_mode_selected(1)
	var actions = []
	var phases = []
	var rest_targets = []
	var rest_activated = false
	for guard in range(28):
		if not await _wait(workbench):
			return
		var action = workbench.runtime_decision.get("action", {})
		var phase = workbench.runtime_decision.get("inspection", {}).get("food_rest", {}).get("phase", "")
		actions.append(action.get("type", ""))
		phases.append(phase)
		if action.get("type", "") == "pickup" and not rest_activated:
			workbench.state_provider.set_rest_need("npc_b", 0.9)
			rest_activated = true
		if phase == "FOOD_SUSPENDED" and action.get("target_id", ""):
			rest_targets.append(action.get("target_id", ""))
		if action.get("type", "") == "deposit":
			break
		workbench._request_runtime_action_if_needed()
	if not await _wait(workbench):
		return
	if not rest_activated or not actions.has("rest") or actions[-1] != "deposit":
		_fail("Food-Rest-Food chain did not complete: %s / %s" % [actions, phases])
		return
	if not phases.has("FOOD_SUSPENDED") or not phases.has("RESUME"):
		_fail("Food was not suspended and resumed around Rest: %s" % [phases])
		return
	if rest_targets.is_empty() or rest_targets.any(func(target): return target != "rest_hut"):
		_fail("Rest did not commit the distinct Rest Hut: %s" % [rest_targets])
		return
	var resumed_index = phases.find("RESUME")
	if resumed_index == -1 or actions[resumed_index] != "approach":
		_fail("Food did not resume by returning toward Plaza: %s / %s" % [actions, phases])
		return
	if workbench.history_status != "accepted":
		_fail("resumed deposit was not admitted as causal experience: %s" % workbench.history_status)
		return
	print("Food-Rest resume check passed: %s / %s" % [actions, phases])
	workbench.queue_free()
	await process_frame
	quit(0)

func _wait(workbench):
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("Food-Rest Runtime roundtrip timed out")
			return false
		await process_frame
	return true

func _fail(message):
	push_error(message)
	quit(1)
