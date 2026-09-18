extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_sleep_actions_enabled(true)
	workbench.state_provider.set_sleep_window(true)
	workbench.state_provider.step()
	workbench.state_provider.step()
	var before_need = workbench.state_provider.get_body_snapshot("npc_b")["rest_need"]
	if before_need < 0.85:
		_fail("Sleep fixture did not reach the finite RestNeed threshold")
		return
	workbench._on_mode_selected(1)
	var actions = []
	for iteration in range(12):
		if iteration > 0:
			workbench._request_runtime_action_if_needed()
		var deadline = Time.get_ticks_msec() + 5000
		while workbench.runtime_pending or workbench.history_pending:
			if Time.get_ticks_msec() > deadline:
				_fail("Sleep HTTP roundtrip timed out")
				return
			await process_frame
		var action = workbench.runtime_decision.get("action", {})
		actions.append(action.get("type", ""))
		if action.get("type", "") == "sleep":
			if action.get("target_id", "") != "plaza":
				_fail("Sleep selected a non-safe target: %s" % action)
				return
			break
	if actions.is_empty() or actions[-1] != "sleep" or actions.slice(0, -1).any(func(action): return action != "approach"):
		_fail("unexpected Sleep action chain: %s" % actions)
		return
	var body = workbench.state_provider.get_body_snapshot("npc_b")
	if body["rest_need"] >= before_need:
		_fail("bounded Sleep did not reduce RestNeed")
		return
	var effects = workbench.runtime_resolution.get("effects", {})
	if effects.get("sleep_kind", "") != "bounded_sleep" or effects.get("consolidation", "") != "not_run":
		_fail("Sleep resolution did not preserve consolidation boundary: %s" % effects)
		return
	if not workbench.inspector_text.get_parsed_text().contains("reaction: sleeping"):
		_fail("Inspector did not show sleeping expression")
		return
	print("Sleep HTTP check passed: actions=%s need=%.2f->%.2f consolidation=not_run" % [actions, before_need, body["rest_need"]])
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
