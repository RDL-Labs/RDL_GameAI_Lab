extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_food_safety_integration_enabled(true)
	workbench._on_mode_selected(1)
	var cycle_summaries = []
	for cycle in range(3):
		if cycle > 0:
			workbench.state_provider.set_danger_fixture_enabled(false)
			if not workbench.state_provider.replenish_food_site("npc_b"):
				_fail("Food Site did not require finite replenishment before cycle %d" % (cycle + 1))
				return
			while workbench.state_provider.get_state()["base_food_band"] == "enough":
				workbench.state_provider.step()
			if cycle == 2:
				workbench.state_provider.set_god_statue_cue_enabled(false)
			workbench._refresh_all()
			workbench._request_runtime_action_if_needed()
		if not await _wait(workbench):
			return
		var first_life = workbench.runtime_decision.get("inspection", {}).get("life", {})
		if cycle < 2 and typeof(first_life.get("cue")) != TYPE_DICTIONARY:
			_fail("assisted cycle %d did not receive a God Statue cue" % (cycle + 1))
			return
		if cycle == 2:
			if first_life.get("cue") != null:
				_fail("autonomous cycle unexpectedly received a God Statue cue")
				return
			if first_life.get("goal_trigger", "") != "learned_low_stock_relation":
				_fail("autonomous cycle did not use retained experience: %s" % first_life)
				return
			if first_life.get("habit_successes", 0) < 2:
				_fail("autonomous cycle began without two real successes: %s" % first_life)
				return
		var actions = []
		var phases = []
		var danger_activated = false
		for guard in range(28):
			var action = workbench.runtime_decision.get("action", {})
			var phase = workbench.runtime_decision.get("inspection", {}).get("food_safety", {}).get("phase", "")
			actions.append(action.get("type", ""))
			phases.append(phase)
			if cycle == 0 and action.get("type", "") == "pickup" and not danger_activated:
				workbench.state_provider.set_danger_fixture_enabled(true, "npc_b")
				danger_activated = true
			if action.get("type", "") == "deposit":
				break
			workbench._request_runtime_action_if_needed()
			if not await _wait(workbench):
				return
		if actions.is_empty() or actions[-1] != "deposit" or not actions.has("pickup"):
			_fail("continuous-life cycle %d did not complete: %s" % [cycle + 1, actions])
			return
		if cycle == 0 and (not danger_activated or not actions.has("flee") or not phases.has("RESUME")):
			_fail("cycle 1 did not suspend for Safety and resume Food: %s / %s" % [actions, phases])
			return
		cycle_summaries.append({
			"cycle": cycle + 1,
			"goal_trigger": first_life.get("goal_trigger", "none"),
			"habit_successes": first_life.get("habit_successes", 0),
			"actions": actions,
			"phases": phases
		})
	print("Continuous-life evidence check passed: %s" % [cycle_summaries])
	workbench.queue_free()
	await process_frame
	quit(0)

func _wait(workbench):
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("continuous-life Runtime roundtrip timed out")
			return false
		await process_frame
	return true

func _fail(message):
	push_error(message)
	quit(1)
