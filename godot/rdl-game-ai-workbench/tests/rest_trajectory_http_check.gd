extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_rest_actions_enabled(true)
	workbench._on_mode_selected(1)
	if not await _wait(workbench):
		return
	var first = workbench.runtime_decision
	var target_id = first.get("action", {}).get("target_id", "")
	if first.get("inspection", {}).get("rest", {}).get("trajectory_phase", "") != "GO_TO_REST" or target_id != "plaza":
		_fail("Rest Goal/Trajectory did not form: %s" % first)
		return
	var selection = first.get("inspection", {}).get("rest", {}).get("target_selection", {})
	if selection.get("selected", {}).get("safety", "") != "safe" or selection.get("candidates", []).size() != 2:
		_fail("finite Rest candidate comparison was not preserved: %s" % selection)
		return

	workbench.state_provider.set_interrupt_candidates([{
		"candidate_id": "generic-rest-1", "kind": "generic", "salience": 0.9
	}])
	workbench._request_runtime_action_if_needed()
	if not await _wait(workbench):
		return
	var held = workbench.runtime_decision
	var held_rest = held.get("inspection", {}).get("rest", {})
	if held.get("action", {}).get("type", "") != "idle" or held_rest.get("trajectory_phase", "") != "SUSPENDED":
		_fail("generic interrupt did not suspend Rest trajectory: %s" % held)
		return
	if held_rest.get("target_id", "") != target_id:
		_fail("Rest target changed while suspended")
		return

	workbench.state_provider.set_interrupt_candidates([])
	workbench._request_runtime_action_if_needed()
	if not await _wait(workbench):
		return
	var resumed = workbench.runtime_decision
	if resumed.get("action", {}).get("type", "") != "approach" or resumed.get("action", {}).get("target_id", "") != target_id:
		_fail("Rest trajectory did not resume the same target: %s" % resumed)
		return

	var guard = 0
	while workbench.runtime_decision.get("action", {}).get("type", "") != "rest" and guard < 12:
		workbench._request_runtime_action_if_needed()
		if not await _wait(workbench):
			return
		guard += 1
	if workbench.runtime_decision.get("action", {}).get("type", "") != "rest":
		_fail("Rest trajectory did not reach short rest")
		return

	workbench._request_runtime_action_if_needed()
	if not await _wait(workbench):
		return
	var completed = workbench.runtime_decision
	if completed.get("inspection", {}).get("rest", {}).get("trajectory_phase", "") != "COMPLETE":
		_fail("Rest trajectory did not complete after recovery: %s" % completed)
		return
	print("Rest trajectory HTTP check passed: suspend -> same-target resume -> complete")
	workbench.queue_free()
	await process_frame
	quit(0)

func _wait(workbench):
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("Rest trajectory HTTP roundtrip timed out")
			return false
		await process_frame
	return true

func _fail(message):
	push_error(message)
	quit(1)
