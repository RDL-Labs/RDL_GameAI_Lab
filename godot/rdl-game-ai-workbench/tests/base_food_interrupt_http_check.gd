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
		"candidate_id": "generic-001", "kind": "generic", "salience": 0.8
	}])
	await _request(workbench)
	var held_life = workbench.runtime_decision.get("inspection", {}).get("life", {})
	if workbench.runtime_decision.get("action", {}).get("type", "") != "idle" or held_life.get("trajectory_phase", "") != "SUSPENDED":
		_fail("generic interrupt did not hold trajectory: %s" % held_life)
		return

	workbench.state_provider.set_interrupt_candidates([])
	await _request(workbench)
	if workbench.runtime_decision.get("action", {}).get("type", "") != "approach":
		_fail("Base-Food trajectory did not resume")
		return

	print("Base-Food generic interrupt check passed")
	workbench.queue_free()
	await process_frame
	quit(0)

func _request(workbench):
	workbench._request_runtime_action_if_needed()
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("generic interrupt HTTP roundtrip timed out")
			return
		await process_frame

func _fail(message):
	push_error(message)
	quit(1)
