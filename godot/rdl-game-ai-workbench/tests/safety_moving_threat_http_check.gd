extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_safety_actions_enabled(true)
	workbench.state_provider.set_moving_threat_enabled(true)
	workbench.state_provider.set_safety_actions_enabled(true)
	if _threat_count(workbench) != 1:
		_fail("moving threat fixture was duplicated while enabling Safety")
		return
	var initial_threat_position = _threat_position(workbench)
	var initial = workbench.state_provider.get_observation("npc_b")["safety_context"]
	if not initial["exposed"] or initial["danger_candidates"] != [{"danger_id": "threat_01", "severity": "high"}]:
		_fail("NPC B did not begin beside the bounded moving threat: %s" % initial)
		return
	workbench._on_mode_selected(1)
	var actions = []
	var first_dominant_danger = ""
	for iteration in range(12):
		if iteration > 0:
			workbench._request_runtime_action_if_needed()
		var deadline = Time.get_ticks_msec() + 5000
		while workbench.runtime_pending or workbench.history_pending:
			if Time.get_ticks_msec() > deadline:
				_fail("moving-threat Safety HTTP roundtrip timed out")
				return
			await process_frame
		var action = workbench.runtime_decision.get("action", {})
		if iteration == 0:
			first_dominant_danger = workbench.runtime_decision.get("inspection", {}).get("safety", {}).get("dominant_danger", {}).get("danger_id", "")
		actions.append(action.get("type", ""))
		if action.get("type", "") == "idle":
			break
		if action.get("type", "") != "flee" or action.get("target_id", "") != "plaza":
			_fail("unexpected moving-threat Safety action: %s" % action)
			return
	var final_context = workbench.state_provider.get_observation("npc_b")["safety_context"]
	var final_threat_position = _threat_position(workbench)
	if first_dominant_danger != "threat_01":
		_fail("moving threat was not retained as dominant danger provenance: %s" % first_dominant_danger)
		return
	if final_threat_position == initial_threat_position:
		_fail("moving threat fixture did not change world position")
		return
	if final_context["exposed"] or not final_context["safe_reached"] or final_context["reached_safe_target_id"] != "plaza":
		_fail("moving-threat escape did not reach committed Plaza: %s" % final_context)
		return
	if actions.is_empty() or actions[-1] != "idle" or actions.slice(0, -1).any(func(action): return action != "flee"):
		_fail("unexpected moving-threat Safety chain: %s" % actions)
		return
	workbench.state_provider.set_safety_actions_enabled(false)
	if _threat_count(workbench) != 0:
		_fail("moving threat fixture remained after Safety was disabled")
		return
	print("Moving threat Safety check passed: %s -> Plaza complete" % [actions])
	workbench.queue_free()
	await process_frame
	quit(0)

func _threat_position(workbench):
	for object_data in workbench.state_provider.objects:
		if object_data.get("id", "") == "threat_01":
			return object_data["position"]
	return Vector2.INF

func _threat_count(workbench):
	return workbench.state_provider.objects.filter(func(object_data): return object_data.get("id", "") == "threat_01").size()

func _fail(message):
	push_error(message)
	quit(1)
