extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.reset()
	var initial_context = workbench.state_provider.get_life_context("npc_b")
	if initial_context.get("god_statue_cue", {}).get("band", "") != "critical":
		_fail("expected critical coarse Food cue")
		return
	workbench._on_mode_selected(1)
	var actions = []
	var phases = []
	for iteration in range(16):
		if iteration > 0:
			workbench._request_runtime_action_if_needed()
		var deadline = Time.get_ticks_msec() + 5000
		while workbench.runtime_pending or workbench.history_pending:
			if Time.get_ticks_msec() > deadline:
				_fail("Base-Food HTTP roundtrip timed out")
				return
			await process_frame
		var action = workbench.runtime_decision.get("action", {})
		var life = workbench.runtime_decision.get("inspection", {}).get("life", {})
		actions.append(action.get("type", ""))
		phases.append(life.get("trajectory_phase", ""))
		if not str(life.get("authority", "")).contains("cue-is-observation-not-command"):
			_fail("God Statue cue gained direct action authority")
			return
		if action.get("type", "") == "deposit":
			break
	if actions.is_empty() or actions[0] != "approach":
		_fail("Base-Food loop did not begin with approach: %s" % actions)
		return
	if not actions.has("pickup") or actions[-1] != "deposit":
		_fail("Base-Food loop did not gather and deposit: %s" % actions)
		return
	for expected in ["GO_TO_SITE", "GATHER", "RETURN_BASE", "DEPOSIT"]:
		if not phases.has(expected):
			_fail("missing trajectory phase %s in %s" % [expected, phases])
			return
	var state = workbench.state_provider.get_state()
	if state["base_food_stock"] <= 1.0 or state["base_food_band"] != "enough":
		_fail("deposit did not restore Base stock: %s" % state)
		return
	var body = workbench.state_provider.get_body_snapshot("npc_b")
	if not body["held_food_ids"].is_empty():
		_fail("deposited food remained held")
		return
	if not workbench.decision_text.get_parsed_text().contains("Base stock:"):
		_fail("Decision Record did not show deposit effect")
		return
	print("Base-Food HTTP check passed: actions=%s phases=%s stock=%.1f" % [
		actions, phases, state["base_food_stock"]
	])
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
