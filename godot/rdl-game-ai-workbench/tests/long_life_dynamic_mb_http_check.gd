extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")
const SNAPSHOT_URL = "http://127.0.0.1:8765/v1/canonical-snapshot"


func _initialize():
	_run.call_deferred()


func _run():
	print("Long-life G2 fixture starting")
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_food_safety_integration_enabled(true)
	workbench._on_mode_selected(1)
	print("Long-life G2 first Runtime request pending=%s" % workbench.runtime_pending)

	var day_one = []
	for cycle in range(2):
		if cycle > 0:
			workbench.state_provider.set_danger_fixture_enabled(false)
			workbench.state_provider.replenish_food_site("npc_b")
			while workbench.state_provider.get_state()["base_food_band"] == "enough":
				workbench.state_provider.step()
			workbench._request_runtime_action_if_needed()
		if not await _wait(workbench):
			return
		var actions = []
		var danger_started = false
		for _guard in range(32):
			var action_type = workbench.runtime_decision.get("action", {}).get("type", "")
			actions.append(action_type)
			if cycle == 0 and action_type == "pickup" and not danger_started:
				workbench.state_provider.set_danger_fixture_enabled(true, "npc_b")
				danger_started = true
			if action_type == "deposit":
				break
			workbench._request_runtime_action_if_needed()
			if not await _wait(workbench):
				return
		if actions.is_empty() or actions[-1] != "deposit":
			_fail("day-one Food cycle did not complete: %s" % [actions])
			return
		if cycle == 0 and not actions.has("flee"):
			_fail("day-one danger did not interrupt Food: %s" % [actions])
			return
		day_one.append(actions)

	workbench.state_provider.set_food_safety_integration_enabled(false)
	workbench.state_provider.set_sleep_actions_enabled(true)
	workbench.state_provider.set_sleep_window(true)
	workbench.state_provider.set_sleep_consolidation_enabled(true)
	workbench.state_provider.set_rest_need("npc_b", 0.9)
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
		_fail("day-one Sleep did not complete: %s" % [sleep_actions])
		return

	if not await _wait_for_cutover():
		return

	workbench.state_provider.set_sleep_actions_enabled(false)
	workbench.state_provider.set_sleep_window(false)
	workbench.state_provider.set_sleep_consolidation_enabled(false)
	workbench.state_provider.set_food_safety_integration_enabled(true)
	workbench.state_provider.set_danger_fixture_enabled(false)
	workbench.state_provider.replenish_food_site("npc_b")
	while workbench.state_provider.get_state()["base_food_band"] == "enough":
		workbench.state_provider.step()
	workbench.state_provider.set_god_statue_cue_enabled(false)
	workbench._request_runtime_action_if_needed()
	if not await _wait(workbench):
		return
	var first_life = workbench.runtime_decision.get("inspection", {}).get("life", {})
	if first_life.get("goal_trigger", "") != "learned_low_stock_relation":
		_fail("day-two life did not use retained autonomous relation: %s" % first_life)
		return
	var day_two = []
	for _guard in range(32):
		var action_type = workbench.runtime_decision.get("action", {}).get("type", "")
		day_two.append(action_type)
		if action_type == "deposit":
			break
		workbench._request_runtime_action_if_needed()
		if not await _wait(workbench):
			return
	if day_two.is_empty() or day_two[-1] != "deposit":
		_fail("day-two autonomous Food cycle did not complete: %s" % [day_two])
		return

	print("Long-life Dynamic M_B check passed: day1=%s sleep=%s day2=%s" % [
		day_one, sleep_actions, day_two
	])
	workbench.queue_free()
	await process_frame
	quit(0)


func _wait(workbench):
	var deadline = Time.get_ticks_msec() + 7000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("long-life Runtime roundtrip timed out")
			return false
		await process_frame
	return true


func _wait_for_cutover():
	var deadline = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() <= deadline:
		var request = HTTPRequest.new()
		root.add_child(request)
		var error = request.request(SNAPSHOT_URL)
		if error != OK:
			request.queue_free()
			await process_frame
			continue
		var response = await request.request_completed
		request.queue_free()
		if response[1] == 200:
			var parsed = JSON.parse_string(response[3].get_string_from_utf8())
			if typeof(parsed) == TYPE_DICTIONARY and parsed.get("model_cutover", {}).get("count", 0) >= 1:
				return true
		await create_timer(0.05).timeout
	_fail("Runtime did not complete Dynamic M_B cutover")
	return false


func _fail(message):
	push_error(message)
	quit(1)
