extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench._on_mode_selected(1)

	# Produce three accepted daytime approach Experiences through the real bridge.
	for index in range(3):
		if index > 0:
			workbench._request_runtime_action_if_needed()
		if not await _wait_for_roundtrip(workbench):
			return
		if workbench.runtime_decision.get("action", {}).get("type", "") != "approach":
			_fail("day interaction did not produce approach Experience: %s" % workbench.runtime_decision)
			return
		if workbench.history_status != "accepted":
			_fail("day Experience was not accepted: %s" % workbench.history_status)
			return

	workbench.state_provider.set_sleep_actions_enabled(true)
	workbench.state_provider.set_sleep_window(true)
	workbench.state_provider.set_sleep_consolidation_enabled(true)
	workbench.state_provider.step()
	workbench.state_provider.step()

	var actions = []
	for _iteration in range(12):
		workbench._request_runtime_action_if_needed()
		if not await _wait_for_roundtrip(workbench):
			return
		var action_type = workbench.runtime_decision.get("action", {}).get("type", "")
		actions.append(action_type)
		if action_type == "sleep":
			break

	if actions.is_empty() or actions[-1] != "sleep":
		_fail("real Sleep action did not complete: %s" % actions)
		return
	if workbench.history_status != "accepted":
		_fail("Sleep consolidation report was not accepted: %s" % workbench.history_status)
		return
	var effects = workbench.runtime_resolution.get("effects", {})
	if effects.get("sleep_kind", "") != "bounded_sleep" or effects.get("consolidation", "") != "report_pending":
		_fail("Sleep resolution did not enter the opt-in consolidation path: %s" % effects)
		return

	print("Sleep consolidation HTTP check passed: day=3 actions=%s" % [actions])
	workbench.queue_free()
	await process_frame
	quit(0)

func _wait_for_roundtrip(workbench):
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("Sleep consolidation HTTP roundtrip timed out")
			return false
		await process_frame
	return true

func _fail(message):
	push_error(message)
	quit(1)
