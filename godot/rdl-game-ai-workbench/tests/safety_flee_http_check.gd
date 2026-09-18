extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_safety_actions_enabled(true)
	var initial = workbench.state_provider.get_observation("npc_b")["safety_context"]
	if not initial["exposed"] or initial["danger_id"] != "danger_gully":
		_fail("NPC B did not begin in bounded danger exposure: %s" % initial)
		return
	workbench._on_mode_selected(1)
	var actions = []
	for iteration in range(10):
		if iteration > 0:
			workbench._request_runtime_action_if_needed()
		var deadline = Time.get_ticks_msec() + 5000
		while workbench.runtime_pending or workbench.history_pending:
			if Time.get_ticks_msec() > deadline:
				_fail("Safety HTTP roundtrip timed out")
				return
			await process_frame
		var action = workbench.runtime_decision.get("action", {})
		actions.append(action.get("type", ""))
		if action.get("type", "") == "idle":
			break
		if action.get("type", "") != "flee" or action.get("target_id", "") != "plaza":
			_fail("unexpected Safety action: %s" % action)
			return
	var final_context = workbench.state_provider.get_observation("npc_b")["safety_context"]
	if final_context["exposed"]:
		_fail("flee chain did not leave the bounded danger zone: %s" % final_context)
		return
	if actions.is_empty() or actions[-1] != "idle" or actions.slice(0, -1).any(func(action): return action != "flee"):
		_fail("unexpected Safety chain: %s" % actions)
		return
	print("Safety flee check passed: %s -> clear" % [actions])
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
