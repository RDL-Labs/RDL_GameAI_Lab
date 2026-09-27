extends SceneTree
const Workbench = preload("res://scripts/workbench_main.gd")
const Heavy = preload("res://scripts/heavy_rescue_fixture.gd")
var failed = false

func _initialize():
	_run.call_deferred()

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
	p.run_id = "soc0-real-world"
	for i in range(3):
		p.resolve_action({"agent_id": "npc_b", "action": {"type": "flee", "target_id": "plaza"},
			"inspection": {"observation_id": p.get_observation("npc_b")["observation_id"]}})
	p.set_safety_actions_enabled(false)
	var origin = p.get_agent("npc_b")["position"]
	p.agents[p._find_agent_index("npc_a")]["position"] = origin + Vector2(120, 0)
	p.agents[p._find_agent_index("npc_c")]["position"] = origin
	w.state_provider = p
	w.selected_agent_id = "npc_a"
	w._on_mode_selected(1)
	var actions = []
	var solo_checked = false
	for guard in range(30):
		if not await _wait(w): return
		var decision = w.runtime_decision
		var action = decision.get("action", {}).get("type", "")
		actions.append(action)
		if action == "rescue" and not solo_checked:
			if not check(p.attempt_count == 1 and p.get_agent("npc_b")["position"] == origin, "solo must actually fail without displacement"): break
			check(p.body_states["npc_a"]["carried_agent_id"] == "", "solo incorrectly attached")
			var before = p.experiences.duplicate(true)
			p.resolve_action(decision)
			check(p.experiences == before and p.attempt_count == 1, "response replay repeated attempt")
			# Explicit harness intervention, not help-seeking by the policy.
			p.participants = ["npc_a", "npc_c"]
			solo_checked = true
		if decision.get("inspection", {}).get("rescue", {}).get("trajectory_phase", "") == "COMPLETE": break
		w._request_runtime_action_if_needed()
	check(actions.count("rescue") == 2 and actions.count("deliver") == 1, "expected failed and successful carry plus one delivery: " + str(actions))
	check(p.world_checks.size() == 2 and not p.world_checks[0]["established"] and p.world_checks[1]["established"], "solo/joint actual result missing")
	var stages = []
	for i in range(4):
		p.step()
		stages.append(p.get_body_snapshot("npc_b")["recovery_stage"])
	check(stages == ["stabilizing", "mobilizing", "recovering", "recovered"], "existing recovery did not finish")
	check(not p.get_body_snapshot("npc_b")["incapacitated"], "B remains incapacitated")
	var plaza = p._get_place("plaza")
	check(p.get_agent("npc_b")["position"] == plaza["position"], "B not delivered to safe place")
	var observations = []
	for id in ["npc_a", "npc_b", "npc_c"]: observations.append(p.get_observation(id))
	var controls = _controls()
	var evidence = {"schema": "soc0-godot-evidence-v1", "actions": actions, "world_checks": p.world_checks,
		"experiences": p.experiences, "recovery_stages": stages, "observations": observations, "controls": controls}
	var output = OS.get_environment("SOC0_EVIDENCE_PATH")
	if not output.is_empty():
		var file = FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(evidence, "  "))
	if not failed: print("SOC-0 Heavy Rescue PASS: solo failure -> joint delivery -> recovered")
	w.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _controls():
	var results = []
	for scenario in ["strong_solo", "two_insufficient", "duplicate", "distant", "incapacitated", "withdrawn"]:
		var p = Heavy.new()
		p.reset()
		p.body_states["npc_b"]["incapacitated"] = true
		p.body_states["npc_b"]["movement_scale"] = 0.0
		for a in p.agents: a["position"] = Vector2(260, 180)
		p.participants = ["npc_a", "npc_c"]
		p.active_energy_enabled = true
		var original_body = p.body_states.duplicate(true)
		if scenario == "strong_solo":
			p.carry_capabilities = {"npc_a": 2, "npc_c": 1}
			p.participants = ["npc_a"]
		if scenario == "two_insufficient": p.target_load = 3
		if scenario == "duplicate": p.participants = ["npc_a", "npc_a"]
		if scenario == "distant": p.agents[2]["position"] += Vector2(120, 0)
		if scenario == "incapacitated": p.body_states["npc_c"]["incapacitated"] = true
		var decision = {"agent_id": "npc_a", "action": {"type": "rescue", "target_id": "npc_b"}, "inspection": {"observation_id": "control-1"}}
		p.resolve_action(decision)
		var attached = not p.body_states["npc_a"]["carried_agent_id"].is_empty()
		check(attached == (scenario in ["strong_solo", "withdrawn"]), "capability control failed: " + scenario)
		if scenario == "withdrawn":
			p.participants = ["npc_a"]
			var before = p.get_agent("npc_b")["position"]
			p.resolve_action({"agent_id": "npc_a", "action": {"type": "approach", "target_id": "plaza"}, "inspection": {"observation_id": "withdrawn"}})
			check(before == p.get_agent("npc_b")["position"], "withdrawn helper still contributed to movement")
		else:
			for i in range(5):
				decision["inspection"]["observation_id"] = "retry-" + str(i)
				p.resolve_action(decision)
			check(p.attempt_count <= 2, "finite attempt budget not enforced")
			if not attached:
				check(p.get_agent("npc_b")["position"] == Vector2(260, 180), "failed retry moved target")
				check(p.body_states["npc_a"]["active_energy"] == original_body["npc_a"]["active_energy"], "failed retry consumed energy")
		results.append({"scenario": scenario, "attached": attached, "attempt_count": p.attempt_count})
	return results

func _wait(w):
	var deadline = Time.get_ticks_msec() + 8000
	while w.runtime_pending or w.history_pending:
		if Time.get_ticks_msec() > deadline or w.runtime_decision.has("error"):
			check(false, "SOC0 Runtime timeout/error: " + str(w.runtime_decision))
			quit(1)
			return false
		await process_frame
	return true
