extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")


func _initialize():
	_run.call_deferred()


func _run():
	var phase = OS.get_environment("RDL_TEST_DMB_PHASE")
	if phase not in ["before", "after"]:
		_fail("RDL_TEST_DMB_PHASE must be before or after")
		return

	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	# A second Godot process must not replay the pre-cutover observation IDs.
	workbench.state_provider.observation_seq = 1000 if phase == "after" else 100
	workbench._on_mode_selected(1)
	if not await _wait_for_roundtrip(workbench):
		return

	var first_action = workbench.runtime_decision.get("action", {}).get("type", "")
	var first_resolution = workbench.runtime_resolution.duplicate(true)
	workbench._request_runtime_action_if_needed()
	if not await _wait_for_roundtrip(workbench):
		return
	var second_action = workbench.runtime_decision.get("action", {}).get("type", "")

	if first_action != "approach" or second_action != "approach":
		_fail("expected the unchanged local policy to approach twice: %s/%s" % [first_action, second_action])
		return
	if first_resolution.get("source_observation_id", "") == first_resolution.get("subsequent_observation_id", ""):
		_fail("world action did not produce a distinct subsequent observation")
		return
	var moved_agent = workbench.state_provider.get_agent("npc_b")
	if moved_agent.get("position", Vector2.ZERO) == Vector2(260, 180):
		_fail("accepted Godot action did not change the agent position")
		return

	print("Dynamic M_B Godot reintegration passed: phase=%s actions=%s/%s" % [
		phase, first_action, second_action
	])
	workbench.queue_free()
	await process_frame
	quit(0)


func _wait_for_roundtrip(workbench):
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("Dynamic M_B Godot HTTP roundtrip timed out")
			return false
		await process_frame
	return true


func _fail(message):
	push_error(message)
	quit(1)
