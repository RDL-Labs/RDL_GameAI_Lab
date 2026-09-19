extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_safety_actions_enabled(true)
	workbench.state_provider.set_incapacitation_fixture_enabled(true)
	workbench._on_mode_selected(1)
	var initial_position = workbench.state_provider.get_agent("npc_b")["position"]
	var actions = []
	var exposure_steps = []
	for guard in range(8):
		if not await _wait(workbench):
			return
		var action = workbench.runtime_decision.get("action", {})
		actions.append(action.get("type", ""))
		var body = workbench.state_provider.get_body_snapshot("npc_b")
		exposure_steps.append(body.get("danger_exposure_steps", -1))
		if body.get("incapacitated", false) and action.get("type", "") == "idle":
			break
		workbench._request_runtime_action_if_needed()
	var final_body = workbench.state_provider.get_body_snapshot("npc_b")
	if actions.count("flee") != 3 or actions[-1] != "idle":
		_fail("three failed flee resolutions did not end in idle: %s" % [actions])
		return
	if final_body.get("injury_level", "") != "severe" or not final_body.get("incapacitated", false):
		_fail("BodyState did not enter severe incapacitation: %s" % [final_body])
		return
	if final_body.get("danger_exposure_steps", 0) != 3:
		_fail("danger exposure count is not finite and exact: %s" % [exposure_steps])
		return
	if workbench.state_provider.get_agent("npc_b")["position"] != initial_position:
		_fail("failed-flee fixture unexpectedly moved the agent")
		return
	print("Safety incapacitation check passed: %s / %s" % [actions, final_body])
	workbench.queue_free()
	await process_frame
	quit(0)

func _wait(workbench):
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("Safety incapacitation Runtime roundtrip timed out")
			return false
		await process_frame
	return true

func _fail(message):
	push_error(message)
	quit(1)
