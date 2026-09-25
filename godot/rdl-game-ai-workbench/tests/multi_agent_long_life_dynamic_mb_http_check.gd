extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")
const SNAPSHOT_URL = "http://127.0.0.1:8765/v1/canonical-snapshot"


func _initialize():
	_run.call_deferred()


func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.state_provider.set_food_safety_integration_enabled(true)
	workbench.provider_mode = "runtime"

	var day_one = {}
	for agent_id in ["npc_a", "npc_b"]:
		workbench.selected_agent_id = agent_id
		var cycles = []
		for cycle in range(2):
			while workbench.state_provider.get_state()["base_food_band"] == "enough":
				workbench.state_provider.step()
			workbench.state_provider.objects = []
			workbench.state_provider.replenish_food_site(agent_id)
			workbench._request_runtime_action_if_needed()
			if not await _wait(workbench):
				return
			var actions = await _finish_food_cycle(workbench)
			if actions.is_empty() or actions[-1] != "deposit":
				_fail("day-one cycle failed for %s: %s" % [agent_id, actions])
				return
			cycles.append(actions)
		day_one[agent_id] = cycles

		workbench.state_provider.set_food_safety_integration_enabled(false)
		workbench.state_provider.set_sleep_actions_enabled(true)
		workbench.state_provider.set_sleep_window(true)
		workbench.state_provider.set_sleep_consolidation_enabled(true)
		workbench.state_provider.set_rest_need(agent_id, 0.9)
		workbench._request_runtime_action_if_needed()
		var sleep_actions = []
		for _guard in range(16):
			if not await _wait(workbench):
				return
			var action_type = workbench.runtime_decision.get("action", {}).get("type", "")
			sleep_actions.append(action_type)
			if action_type == "sleep":
				break
			workbench._request_runtime_action_if_needed()
		if sleep_actions.is_empty() or sleep_actions[-1] != "sleep":
			_fail("Sleep failed for %s: %s" % [agent_id, sleep_actions])
			return
		workbench.state_provider.set_sleep_actions_enabled(false)
		workbench.state_provider.set_sleep_window(false)
		workbench.state_provider.set_sleep_consolidation_enabled(false)
		workbench.state_provider.set_food_safety_integration_enabled(true)

	if not await _wait_for_cutovers(2):
		return

	workbench.state_provider.set_god_statue_cue_enabled(false)
	var day_two = {}
	for agent_id in ["npc_a", "npc_b"]:
		workbench.selected_agent_id = agent_id
		while workbench.state_provider.get_state()["base_food_band"] == "enough":
			workbench.state_provider.step()
		workbench.state_provider.objects = []
		workbench.state_provider.replenish_food_site(agent_id)
		workbench._request_runtime_action_if_needed()
		if not await _wait(workbench):
			return
		var life = workbench.runtime_decision.get("inspection", {}).get("life", {})
		if life.get("goal_trigger", "") != "learned_low_stock_relation":
			_fail("day-two autonomy missing for %s: %s" % [agent_id, life])
			return
		var actions = await _finish_food_cycle(workbench)
		if actions.is_empty() or actions[-1] != "deposit":
			_fail("day-two cycle failed for %s: %s" % [agent_id, actions])
			return
		day_two[agent_id] = actions

	print("Multi-agent long-life Dynamic M_B check passed: day1=%s day2=%s" % [day_one, day_two])
	workbench.queue_free()
	await process_frame
	quit(0)


func _finish_food_cycle(workbench):
	var actions = []
	for _guard in range(32):
		var action_type = workbench.runtime_decision.get("action", {}).get("type", "")
		actions.append(action_type)
		if action_type == "deposit":
			break
		workbench._request_runtime_action_if_needed()
		if not await _wait(workbench):
			return []
	return actions


func _wait(workbench):
	var deadline = Time.get_ticks_msec() + 7000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("multi-agent long-life Runtime roundtrip timed out")
			return false
		await process_frame
	return true


func _wait_for_cutovers(expected_count):
	var deadline = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() <= deadline:
		var request = HTTPRequest.new()
		root.add_child(request)
		var error = request.request(SNAPSHOT_URL)
		if error == OK:
			var response = await request.request_completed
			if response[1] == 200:
				var parsed = JSON.parse_string(response[3].get_string_from_utf8())
				if typeof(parsed) == TYPE_DICTIONARY and parsed.get("model_cutover", {}).get("count", 0) >= expected_count:
					request.queue_free()
					return true
		request.queue_free()
		await create_timer(0.05).timeout
	_fail("Runtime did not complete both Dynamic M_B cutovers")
	return false


func _fail(message):
	push_error(message)
	quit(1)
