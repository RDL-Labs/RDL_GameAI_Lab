extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var level = OS.get_environment("RDL_TEST_RHO_REST_LEVEL")
	var expected_target = "z_grove" if level == "LOW" else "plaza"
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_rest_actions_enabled(true)
	if not workbench.state_provider.configure_observation_resolution({"npc_b": {"rest": level}}):
		_fail("rho Rest profile configuration failed")
		return
	workbench._on_mode_selected(1)
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("rho Rest selection HTTP roundtrip timed out")
			return
		await process_frame
	var decision = workbench.runtime_decision
	var actual_target = decision.get("action", {}).get("target_id", "")
	var selection = decision.get("inspection", {}).get("rest", {}).get("target_selection", {})
	if actual_target != expected_target:
		_fail("rho Rest level %s selected %s instead of %s: %s" % [level, actual_target, expected_target, selection])
		return
	if selection.get("candidate_description", {}).get("rho_level", "") != level:
		_fail("rho candidate-description provenance missing")
		return
	print("rho Rest selection HTTP check passed: %s -> %s" % [level, actual_target])
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
