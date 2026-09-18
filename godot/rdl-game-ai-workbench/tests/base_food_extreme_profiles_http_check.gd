extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var profile = OS.get_environment("RDL_TEST_LIFE_PROFILE")
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.reset()
	workbench.state_provider.objects.append({
		"id": "novelty_01", "label": "Novel Object", "role": "mock object",
		"kind": "artifact", "position": Vector2(300, 200),
		"note": "Finite extreme-profile fixture."
	})
	workbench._on_mode_selected(1)

	await _request(workbench)
	if workbench.runtime_decision.get("action", {}).get("type", "") != "approach":
		_fail("Base-Food trajectory did not start")
		return

	workbench.state_provider.set_interrupt_candidates([
		{"candidate_id": "generic-001", "kind": "generic", "salience": 0.8},
		{"candidate_id": "novelty-001", "kind": "novelty", "salience": 0.85, "target_id": "novelty_01"}
	])
	await _request(workbench)
	var action = workbench.runtime_decision.get("action", {})
	var life = workbench.runtime_decision.get("inspection", {}).get("life", {})
	var interrupt = life.get("interrupt", {})
	var expected_target = "food_01" if profile == "trajectory_locked" else "novelty_01"
	var expected_outcome = "continue" if profile == "trajectory_locked" else "divert"
	var expected_phase = "GO_TO_SITE" if profile == "trajectory_locked" else "SUSPENDED"
	if action.get("type", "") != "approach" or action.get("target_id", "") != expected_target:
		_fail("Extreme profile action mismatch for %s: %s" % [profile, action])
		return
	if interrupt.get("life_profile", "") != profile or interrupt.get("outcome", "") != expected_outcome:
		_fail("Extreme profile inspection mismatch for %s: %s" % [profile, interrupt])
		return
	if life.get("trajectory_phase", "") != expected_phase:
		_fail("Extreme profile phase mismatch for %s: %s" % [profile, life])
		return

	workbench.state_provider.set_interrupt_candidates([])
	await _request(workbench)
	var resumed = workbench.runtime_decision.get("action", {})
	if resumed.get("type", "") != "approach" or resumed.get("target_id", "") != "food_01":
		_fail("Base-Food trajectory did not continue after profile comparison: %s" % resumed)
		return

	print("Base-Food extreme profile check passed: %s" % profile)
	workbench.queue_free()
	await process_frame
	quit(0)

func _request(workbench):
	workbench._request_runtime_action_if_needed()
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("Extreme profile HTTP roundtrip timed out")
			return
		await process_frame

func _fail(message):
	push_error(message)
	quit(1)
