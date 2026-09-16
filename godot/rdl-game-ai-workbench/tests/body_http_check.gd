extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.provider_mode = "runtime"
	var distances = [0.0, 36.0, 18.0]
	var indices = [2, 0, 1]
	for i in range(3):
		var before = workbench.state_provider.get_agent("npc_b")["position"]
		workbench._on_movement_selected(indices[i])
		var deadline = Time.get_ticks_msec() + 5000
		while workbench.runtime_pending or workbench.history_pending:
			if Time.get_ticks_msec() > deadline:
				_fail("body HTTP timeout")
				return
			await process_frame
		var after = workbench.state_provider.get_agent("npc_b")["position"]
		if not is_equal_approx(before.distance_to(after), distances[i]):
			_fail("unexpected displacement: %s" % before.distance_to(after))
			return
		if i == 0:
			if workbench.runtime_decision.get("action", {}).get("type", "") != "idle":
				_fail("stopped body should idle")
				return
			workbench.state_provider.step()
			if workbench.state_provider.get_agent("npc_b")["position"] != before:
				_fail("stopped body moved during mock tick")
				return
		elif workbench.history_status != "accepted":
			_fail("movement result not accepted")
			return
	if workbench.state_provider.get_body_snapshot("npc_a")["movement_scale"] != 1.0:
		_fail("body update leaked to another agent")
		return
	workbench._on_reset_pressed()
	if workbench.state_provider.get_body_snapshot("npc_b")["movement_scale"] != 1.0:
		_fail("reset did not restore body")
		return
	print("Body HTTP check passed: stopped=0 recovered=36 limited=18")
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
