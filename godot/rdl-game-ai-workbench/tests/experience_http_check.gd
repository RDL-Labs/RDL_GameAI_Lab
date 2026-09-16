extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench._on_mode_selected(1)
	var progress = 0
	var no_progress = 0
	for iteration in range(12):
		if iteration > 0:
			workbench._request_runtime_action_if_needed()
		var deadline = Time.get_ticks_msec() + 5000
		while workbench.runtime_pending or workbench.history_pending:
			if Time.get_ticks_msec() > deadline:
				_fail("HTTP roundtrip timed out")
				return
			await process_frame
		if workbench.history_status != "accepted":
			_fail("history not accepted: %s / %s" % [workbench.history_status, workbench.runtime_decision])
			return
		var result = workbench.state_provider.get_interaction_result(workbench.runtime_resolution)
		if result.get("outcome", "") == "approach_progress":
			progress += 1
		else:
			no_progress += 1
	if progress == 0 or no_progress == 0:
		_fail("expected both progress and no-progress")
		return
	print("Experience HTTP check passed: progress=%d no_progress=%d" % [progress, no_progress])
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
