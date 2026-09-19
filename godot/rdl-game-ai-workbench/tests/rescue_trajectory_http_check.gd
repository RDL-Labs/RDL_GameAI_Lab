extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	var provider = workbench.state_provider
	provider.set_safety_actions_enabled(true)
	provider.set_incapacitation_fixture_enabled(true)
	provider.reset()
	var target_id = "npc_b"
	var observer_id = "npc_a"
	for step in range(3):
		var observation = provider.get_observation(target_id)
		provider.resolve_action({
			"agent_id": target_id,
			"action": {"type": "flee", "target_id": "plaza"},
			"inspection": {"observation_id": observation["observation_id"]}
		})
	provider.set_safety_actions_enabled(false)
	var target_position = provider.get_agent(target_id)["position"]
	for agent in provider.agents:
		if agent.get("id", "") == observer_id:
			agent["position"] = target_position + Vector2(120, 0)
			break

	workbench.selected_agent_id = observer_id
	workbench._on_mode_selected(1)
	var actions = []
	for guard in range(8):
		if not await _wait(workbench):
			return
		var action = workbench.runtime_decision.get("action", {})
		actions.append(action.get("type", ""))
		if action.get("type", "") == "idle":
			break
		if action.get("type", "") != "approach" or action.get("target_id", "") != target_id:
			_fail("unexpected Rescue action: %s" % [action])
			return
		workbench._request_runtime_action_if_needed()

	var rescue = workbench.runtime_decision.get("inspection", {}).get("rescue", {})
	if actions != ["approach", "approach", "approach", "idle"]:
		_fail("Rescue approach chain was not finite: %s" % [actions])
		return
	if rescue.get("trajectory_phase", "") != "READY_TO_RESCUE":
		_fail("trajectory did not stop at READY_TO_RESCUE: %s" % [rescue])
		return
	if provider.get_agent(observer_id)["position"].distance_to(target_position) > 12.0:
		_fail("observer did not reach the incapacitated agent")
		return
	if not provider.get_body_snapshot(target_id).get("incapacitated", false):
		_fail("approach mutated the target incapacitation")
		return
	print("Rescue trajectory check passed: %s / %s" % [actions, rescue])
	workbench.queue_free()
	await process_frame
	quit(0)

func _wait(workbench):
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("Rescue Runtime roundtrip timed out")
			return false
		await process_frame
	return true

func _fail(message):
	push_error(message)
	quit(1)
