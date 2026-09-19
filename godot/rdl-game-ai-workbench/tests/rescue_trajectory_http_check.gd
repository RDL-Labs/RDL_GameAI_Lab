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
	for guard in range(20):
		if not await _wait(workbench):
			return
		var action = workbench.runtime_decision.get("action", {})
		actions.append(action.get("type", ""))
		if action.get("type", "") == "idle" and not actions.is_empty():
			break
		if action.get("type", "") not in ["approach", "rescue", "deliver"]:
			_fail("unexpected Rescue action: %s" % [action])
			return
		workbench._request_runtime_action_if_needed()

	var rescue = workbench.runtime_decision.get("inspection", {}).get("rescue", {})
	if actions.count("rescue") != 1 or actions.count("deliver") != 1 or actions[-1] != "idle":
		_fail("Rescue delivery chain was not finite: %s" % [actions])
		return
	if rescue.get("trajectory_phase", "") != "COMPLETE":
		_fail("trajectory did not complete from subsequent delivery evidence: %s" % [rescue])
		return
	var delivery = provider.get_body_snapshot(observer_id).get("last_rescue_delivery", {})
	if delivery.get("agent_id", "") != target_id or delivery.get("place_id", "") != "plaza":
		_fail("World did not record bounded safe-place delivery: %s" % [delivery])
		return
	if not provider.get_body_snapshot(target_id).get("incapacitated", false):
		_fail("delivery improperly recovered the target")
		return
	var plaza = provider.get_state()["places"].filter(func(place): return place.get("id", "") == "plaza")[0]
	if provider.get_agent(target_id)["position"] != plaza["position"]:
		_fail("delivered target is not at the safe place")
		return
	print("Rescue delivery check passed: %s / %s / %s" % [actions, rescue, delivery])
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
