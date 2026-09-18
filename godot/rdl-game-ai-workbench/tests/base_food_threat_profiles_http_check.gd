extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.reset()
	workbench._on_mode_selected(1)

	await _request(workbench)
	if workbench.runtime_decision.get("action", {}).get("type", "") != "approach":
		_fail("Base-Food trajectory did not start")
		return

	workbench.state_provider.set_interrupt_candidates([{
		"candidate_id": "threat-001", "kind": "threat", "salience": 0.7
	}])
	await _request(workbench)
	var life = workbench.runtime_decision.get("inspection", {}).get("life", {})
	var expected_action = OS.get_environment("RDL_TEST_EXPECT_THREAT_ACTION")
	var actual_action = workbench.runtime_decision.get("action", {}).get("type", "")
	if actual_action != expected_action:
		_fail("Threat profile expected %s but got %s: %s" % [expected_action, actual_action, life])
		return

	print("Base-Food threat profile check passed: %s" % expected_action)
	workbench.queue_free()
	await process_frame
	quit(0)

func _request(workbench):
	workbench._request_runtime_action_if_needed()
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("Threat profile HTTP roundtrip timed out")
			return
		await process_frame

func _fail(message):
	push_error(message)
	quit(1)
