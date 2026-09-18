extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.reset()
	workbench.state_provider.set_god_statue_cue_enabled(false)
	workbench._on_mode_selected(1)
	var actions = []
	for iteration in range(16):
		if iteration > 0:
			workbench._request_runtime_action_if_needed()
		var deadline = Time.get_ticks_msec() + 5000
		while workbench.runtime_pending or workbench.history_pending:
			if Time.get_ticks_msec() > deadline:
				_fail("autonomous Base-Food HTTP roundtrip timed out")
				return
			await process_frame
		var life = workbench.runtime_decision.get("inspection", {}).get("life", {})
		if iteration == 0:
			if life.get("cue") != null:
				_fail("autonomous path unexpectedly received God Statue cue")
				return
			if life.get("goal_trigger", "") != "learned_low_stock_relation":
				_fail("autonomous path did not use learned relation: %s" % life)
				return
		var action_type = workbench.runtime_decision.get("action", {}).get("type", "")
		actions.append(action_type)
		if action_type == "deposit":
			break
	if actions.is_empty() or actions[0] != "approach" or not actions.has("pickup") or actions[-1] != "deposit":
		_fail("autonomous Base-Food loop incomplete: %s" % actions)
		return
	print("Base-Food autonomous check passed: actions=%s" % [actions])
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
