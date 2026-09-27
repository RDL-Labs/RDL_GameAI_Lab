extends SceneTree
# SOC-2 candidate is prescribed before the trial; no selector or help request.
const Workbench = preload("res://scripts/workbench_main.gd")
const Heavy = preload("res://scripts/heavy_rescue_fixture.gd")
var failed = false

func _initialize(): _run.call_deferred()

func check(ok, message):
	if not ok:
		failed = true
		push_error(message)
	return ok

func _run():
	var w = Workbench.new()
	root.add_child(w)
	var p = Heavy.new()
	p.set_safety_actions_enabled(true)
	p.set_incapacitation_fixture_enabled(true)
	p.reset()
	p.run_id = OS.get_environment("SOC2_WORLD_RUN")
	p.target_load = int(OS.get_environment("SOC2_TARGET_LOAD"))
	if not check(p.target_load in [2, 3], "invalid experimental load"): quit(1); return
	for i in range(3):
		p.resolve_action({"agent_id": "npc_b", "action": {"type": "flee", "target_id": "plaza"},
			"inspection": {"observation_id": p.get_observation("npc_b")["observation_id"]}})
	p.set_safety_actions_enabled(false)
	var origin = p.get_agent("npc_b")["position"]
	p.agents[p._find_agent_index("npc_a")]["position"] = origin + Vector2(120, 0)
	p.agents[p._find_agent_index("npc_c")]["position"] = origin
	p.participants = ["npc_a", "npc_c"]
	var initial = {"positions": [], "b_body": p.get_body_snapshot("npc_b"),
		"carry_attempts": p.attempt_count, "experiences": p.experiences.size()}
	for a in p.agents: initial["positions"].append({"id": a["id"], "position": [a["position"].x, a["position"].y]})
	check(initial["b_body"]["incapacitated"], "target must start incapacitated")
	w.state_provider = p
	w.selected_agent_id = "npc_a"
	var actions = []
	var termination = "interrupted"
	w._on_mode_selected(1)
	for guard in range(30):
		if not await _wait(w): return
		var decision = w.runtime_decision
		var kind = decision.get("action", {}).get("type", "")
		actions.append(kind)
		if kind == "rescue" and p.body_states["npc_a"]["carried_agent_id"] == "":
			termination = "carry_failed"
			break
		if decision.get("inspection", {}).get("rescue", {}).get("trajectory_phase", "") == "COMPLETE":
			termination = "delivered"
			break
		if guard < 29: w._request_runtime_action_if_needed()
	var stages = []
	check(p.attempt_count == 1, "joint must be tried exactly once")
	check(p.world_checks.size() == 1 and p.world_checks[0]["active"] == ["npc_a", "npc_c"], "both carriers must actually participate")
	if p.target_load == 2:
		check(termination == "delivered", "expected real delivery")
		check(p.experiences.size() == 2, "expected carry and delivery records")
		for i in range(4):
			p.step()
			stages.append(p.get_body_snapshot("npc_b")["recovery_stage"])
		check(stages == ["stabilizing", "mobilizing", "recovering", "recovered"], "recovery failed")
		check(p.get_agent("npc_b")["position"] == p._get_place("plaza")["position"], "target not delivered")
	else:
		check(termination == "carry_failed", "expected real carry failure")
		check(p.experiences.size() == 1 and p.experiences[0]["result"] == "carry_not_established", "failure evidence absent")
		check(p.get_agent("npc_b")["position"] == origin, "failed rescue moved target")
		check(not p.world_checks[0]["target_moved"] and not p.world_checks[0]["established"], "failure had an effect")
		check(not actions.has("deliver"), "failure must not fabricate delivery")
	var evidence = {"schema": "soc2-godot-episode-v1", "world_run_id": p.run_id,
		"initial": initial, "actions": actions, "termination": termination,
		"world_checks": p.world_checks, "experiences": p.experiences, "recovery_stages": stages,
		"experimenter_only": {"carry_capabilities": p.carry_capabilities, "target_load": p.target_load},
		"metrics": {"joint_attempts": p.attempt_count, "action_count": actions.size(),
			"actions_to_delivery": actions.find("deliver") + 1 if actions.has("deliver") else null}}
	var file = FileAccess.open(OS.get_environment("SOC2_EVIDENCE_PATH"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	if not failed: print("SOC-2 EPISODE PASS: " + termination + " " + JSON.stringify(evidence["metrics"]))
	w.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _wait(w):
	var deadline = Time.get_ticks_msec() + 8000
	while w.runtime_pending or w.history_pending:
		if Time.get_ticks_msec() > deadline or w.runtime_decision.has("error"):
			check(false, "SOC2 Runtime timeout/error: " + str(w.runtime_decision))
			quit(1)
			return false
		await process_frame
	return check(not w.runtime_decision.has("error"), "Runtime error")
