extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_rest_actions_enabled(true)
	var initial_need = workbench.state_provider.get_body_snapshot("npc_b")["rest_need"]
	workbench._on_mode_selected(1)
	var actions = []
	for iteration in range(12):
		if iteration > 0:
			workbench._request_runtime_action_if_needed()
		var deadline = Time.get_ticks_msec() + 5000
		while workbench.runtime_pending or workbench.history_pending:
			if Time.get_ticks_msec() > deadline:
				_fail("Rest HTTP roundtrip timed out")
				return
			await process_frame
		var action_type = workbench.runtime_decision.get("action", {}).get("type", "")
		actions.append(action_type)
		if action_type == "rest":
			break
	if actions.is_empty() or actions[-1] != "rest" or actions.slice(0, -1).any(func(action): return action != "approach"):
		_fail("unexpected Rest action chain: %s" % actions)
		return
	var body = workbench.state_provider.get_body_snapshot("npc_b")
	if body["rest_need"] >= initial_need:
		_fail("short rest did not decrease RestNeed")
		return
	if not workbench.inspector_text.get_parsed_text().contains("reaction: recovering"):
		_fail("Inspector did not show recovering expression")
		return
	if not workbench.timeline_text.get_parsed_text().contains("RestNeed decreased"):
		_fail("Timeline did not record short rest")
		return
	print("Rest HTTP check passed: actions=%s need=%.2f->%.2f" % [actions, initial_need, body["rest_need"]])
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
