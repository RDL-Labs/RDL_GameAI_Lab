extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	await process_frame
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.set_safety_actions_enabled(true)
	workbench.state_provider.set_moving_threat_enabled(true)
	workbench.provider_mode = "runtime"
	workbench.runtime_decision = {
		"agent_id": "npc_b",
		"action": {"type": "flee", "target_id": "plaza"},
		"inspection": {
			"expression": {"label": "escaping", "factors": []},
			"safety": {
				"dominant_danger": {"danger_id": "threat_01", "severity": "high"},
				"target_id": "plaza",
				"trajectory_phase": "FLEE_TO_SAFE",
				"danger_exposed": true,
				"safe_reached": false
			}
		}
	}
	var state_before = workbench.state_provider.get_state()
	var decision_before = workbench.runtime_decision.duplicate(true)
	workbench._refresh_all()
	await process_frame
	if workbench.state_provider.get_state() != state_before or workbench.runtime_decision != decision_before:
		_fail("visual refresh changed World or Runtime decision state")
		return
	var canvas = workbench.world_view
	if canvas.size.x < 400.0 or canvas.size.y < 300.0:
		_fail("World canvas did not receive a stable drawable size: %s" % canvas.size)
		return
	if canvas.selected_agent_id != "npc_b" or canvas.committed_target_id != "plaza":
		_fail("visual relation state was not projected: %s -> %s" % [canvas.selected_agent_id, canvas.committed_target_id])
		return
	if canvas.world_state.get("perception_radius", 0.0) <= 0.0:
		_fail("selected-agent observation boundary was not projected")
		return
	var threat = canvas._find_world_entity("threat_01")
	if threat.is_empty() or not threat.get("threat_capable", false):
		_fail("moving threat was not projected as a distinct World entity")
		return
	var capture_path = OS.get_environment("RDL_VISUAL_CAPTURE")
	if not capture_path.is_empty():
		await process_frame
		var error = root.get_texture().get_image().save_png(capture_path)
		if error != OK:
			_fail("Workbench visual capture failed: %d" % error)
			return
	print("Workbench visualization check passed: entities, boundary, trajectory, Safety, non-intervention")
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
