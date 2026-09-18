extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.reset()
	workbench.state_provider.objects.append({
		"id": "novelty_01", "label": "Novel Object", "role": "mock object",
		"kind": "artifact", "position": Vector2(300, 200),
		"note": "Finite Phase 8 novelty fixture."
	})
	workbench._on_mode_selected(1)

	await _request(workbench)
	if workbench.runtime_decision.get("action", {}).get("type", "") != "approach":
		_fail("Base-Food trajectory did not start")
		return

	workbench.state_provider.set_interrupt_candidates([{
		"candidate_id": "novelty-candidate-001", "kind": "novelty",
		"salience": 0.8, "target_id": "novelty_01"
	}])
	await _request(workbench)
	var life = workbench.runtime_decision.get("inspection", {}).get("life", {})
	var action = workbench.runtime_decision.get("action", {})
	var expected_response = OS.get_environment("RDL_TEST_NOVELTY_RESPONSE")
	var expected_action = "approach" if expected_response != "inspect" else "idle"
	var expected_target = "novelty_01" if expected_response == "divert" else "food_01"
	if action.get("type", "") != expected_action:
		_fail("Novelty %s expected action %s: %s" % [expected_response, expected_action, life])
		return
	if expected_action == "approach" and action.get("target_id", "") != expected_target:
		_fail("Novelty %s expected target %s: %s" % [expected_response, expected_target, action])
		return
	if life.get("interrupt", {}).get("outcome", "") != expected_response:
		_fail("Novelty outcome mismatch: %s" % life)
		return
	var expected_phase = "GO_TO_SITE" if expected_response == "ignore" else "SUSPENDED"
	if life.get("trajectory_phase", "") != expected_phase:
		_fail("Novelty phase mismatch: %s" % life)
		return

	workbench.state_provider.set_interrupt_candidates([])
	await _request(workbench)
	var resumed_action = workbench.runtime_decision.get("action", {})
	if resumed_action.get("type", "") != "approach" or resumed_action.get("target_id", "") != "food_01":
		_fail("Base-Food trajectory did not resume after novelty: %s" % resumed_action)
		return

	print("Base-Food novelty response check passed: %s" % expected_response)
	workbench.queue_free()
	await process_frame
	quit(0)

func _request(workbench):
	workbench._request_runtime_action_if_needed()
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("Novelty response HTTP roundtrip timed out")
			return
		await process_frame

func _fail(message):
	push_error(message)
	quit(1)
