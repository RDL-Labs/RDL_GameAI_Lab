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
	var rescuer_id = "npc_a"
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
		if agent.get("id", "") == rescuer_id:
			agent["position"] = target_position + Vector2(120, 0)

	workbench.selected_agent_id = rescuer_id
	workbench.set_simulation_agents_enabled(true)
	workbench._on_mode_selected(1)
	var rescuer_actions = []
	var target_actions = []
	for guard in range(20):
		if not await _wait_cycle(workbench):
			return
		var rescuer_decision = workbench.runtime_decisions_by_agent.get(rescuer_id, {})
		var target_decision = workbench.runtime_decisions_by_agent.get(target_id, {})
		rescuer_actions.append(rescuer_decision.get("action", {}).get("type", ""))
		target_actions.append(target_decision.get("action", {}).get("type", ""))
		if target_actions[-1] != "idle":
			_fail("incapacitated target received a world-changing action: %s" % [target_decision])
			return
		if rescuer_decision.get("inspection", {}).get("rescue", {}).get("trajectory_phase", "") == "COMPLETE":
			break
		workbench._request_runtime_action_if_needed()

	if rescuer_actions.count("rescue") != 1 or rescuer_actions.count("deliver") != 1:
		_fail("finite Rescue chain was not completed exactly once: %s" % [rescuer_actions])
		return
	var stages = []
	for step in range(4):
		provider.step()
		workbench._request_runtime_action_if_needed()
		if not await _wait_cycle(workbench):
			return
		stages.append(provider.get_body_snapshot(target_id).get("recovery_stage", ""))
		var rescuer_action = workbench.runtime_decisions_by_agent.get(rescuer_id, {}).get("action", {}).get("type", "")
		var target_action = workbench.runtime_decisions_by_agent.get(target_id, {}).get("action", {}).get("type", "")
		if rescuer_action != "idle" or target_action != "idle":
			_fail("recovery cycle formed an unexpected action: A=%s B=%s" % [rescuer_action, target_action])
			return

	if stages != ["stabilizing", "mobilizing", "recovering", "recovered"]:
		_fail("staged recovery sequence mismatch: %s" % [stages])
		return
	var final_body = provider.get_body_snapshot(target_id)
	if final_body.get("incapacitated", true) or final_body.get("injury_level", "") != "none":
		_fail("target did not return to a mobile recovered body: %s" % [final_body])
		return
	var observer_view = provider.get_observation(rescuer_id).get("visible_agents", [])
	var target_views = observer_view.filter(func(item): return item.get("id", "") == target_id)
	if not target_views.is_empty() and target_views[0].has("condition"):
		_fail("recovered target retained a bounded injury condition: %s" % [target_views[0]])
		return
	print("Multi-agent Rescue evidence passed: %s -> %s" % [rescuer_actions, stages])
	workbench.queue_free()
	await process_frame
	quit(0)

func _wait_cycle(workbench):
	var deadline = Time.get_ticks_msec() + 8000
	while workbench.runtime_pending or workbench.history_pending or not workbench.simulation_queue.is_empty():
		if workbench.runtime_decision.has("error"):
			_fail("multi-agent Rescue Runtime error: %s queue=%s" % [
				workbench.runtime_decision, workbench.simulation_queue
			])
			return false
		if Time.get_ticks_msec() > deadline:
			_fail("multi-agent Rescue cycle timed out")
			return false
		await process_frame
	await process_frame
	return true

func _fail(message):
	push_error(message)
	quit(1)
