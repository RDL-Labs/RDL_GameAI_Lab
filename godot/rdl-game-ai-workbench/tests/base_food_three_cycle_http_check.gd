extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench._on_mode_selected(1)
	var cycle_summaries = []
	for cycle in range(3):
		if cycle > 0:
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
				_fail("cycle 3 unexpectedly received a God Statue cue")
				return
			if first_life.get("goal_trigger", "") != "learned_low_stock_relation":
				_fail("cycle 3 did not use the learned relation: %s" % first_life)
				return
			if first_life.get("habit_successes", 0) < 2:
				_fail("cycle 3 began without two retained real successes: %s" % first_life)
				return
		var actions = []
		for guard in range(18):
			var action = workbench.runtime_decision.get("action", {})
			actions.append(action.get("type", ""))
			if action.get("type", "") == "deposit":
				break
			workbench._request_runtime_action_if_needed()
			if not await _wait(workbench):
				return
		if actions.is_empty() or actions[-1] != "deposit" or not actions.has("pickup"):
			_fail("Base-Food cycle %d did not complete through pickup/deposit: %s" % [cycle + 1, actions])
			return
		cycle_summaries.append({
			"cycle": cycle + 1,
			"goal_trigger": first_life.get("goal_trigger", "none"),
			"habit_successes": first_life.get("habit_successes", 0),
			"actions": actions
		})
	print("Base-Food three-cycle check passed: %s" % [cycle_summaries])
	workbench.queue_free()
	await process_frame
	quit(0)

func _wait(workbench):
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending or workbench.history_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("three-cycle Runtime roundtrip timed out")
			return false
		await process_frame
	return true

func _fail(message):
	push_error(message)
	quit(1)
