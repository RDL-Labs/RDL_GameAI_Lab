extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.state_provider.set_food_actions_enabled(false)
	workbench.selected_agent_id = "npc_b"
	workbench._on_mode_selected(1)
	var progress = 0
	var no_progress = 0
	var influence = OS.get_environment("RDL_TEST_HISTORY_INFLUENCE") == "1"
	for iteration in range(12):
		if iteration > 0:
			workbench._request_runtime_action_if_needed()
		var deadline = Time.get_ticks_msec() + 5000
		while workbench.runtime_pending or workbench.history_pending:
			if Time.get_ticks_msec() > deadline:
				_fail("HTTP roundtrip timed out")
				return
			await process_frame
		if influence and workbench.runtime_decision.get("action", {}).get("type", "") == "idle":
			var trace = workbench.runtime_decision.get("inspection", {}).get("history_influence", {})
			var expression = workbench.runtime_decision.get("inspection", {}).get("expression", {})
			if expression.get("label", "") != "holding" or not workbench.inspector_text.get_parsed_text().contains("reaction: holding"):
				_fail("expected derived holding expression in Inspector")
				return
			if progress == 0 or no_progress == 0 or not trace.get("action_changed", false):
				_fail("expected history-backed idle after real no-progress result")
				return
			print("Experience influence check passed: progress=%d no_progress=%d then idle" % [progress, no_progress])
			if OS.get_environment("RDL_TEST_RETRY_PROFILE") == "short":
				workbench._on_step_pressed()
				deadline = Time.get_ticks_msec() + 5000
				while workbench.runtime_pending or workbench.history_pending:
					if Time.get_ticks_msec() > deadline:
						_fail("profile retry timed out")
						return
					await process_frame
				var retried = workbench.runtime_decision
				if retried.get("action", {}).get("type", "") != "approach" or workbench.history_status != "accepted":
					_fail("short profile should retry after one tick")
					return
				if retried.get("inspection", {}).get("history_influence", {}).get("profile_id", "") != "retry-short-v1":
					_fail("expected short profile provenance")
					return
				print("Short profile retry check passed")
			workbench.queue_free()
			await process_frame
			quit(0)
			return
		if workbench.history_status != "accepted":
			_fail("history not accepted: %s / %s" % [workbench.history_status, workbench.runtime_decision])
			return
		var result = workbench.state_provider.get_interaction_result(workbench.runtime_resolution)
		if result.get("outcome", "") == "approach_progress":
			progress += 1
		else:
			no_progress += 1
	if influence or progress == 0 or no_progress == 0:
		_fail("expected both progress and no-progress")
		return
	print("Experience HTTP check passed: progress=%d no_progress=%d" % [progress, no_progress])
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
