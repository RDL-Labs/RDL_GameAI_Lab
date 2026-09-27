extends SceneTree
const Workbench = preload("res://scripts/workbench_main.gd")
const Heavy = preload("res://scripts/heavy_rescue_fixture.gd")
var failed = false

func _initialize(): _run.call_deferred()

func check(ok, message):
	if not ok:
		failed = true
		push_error(message)
	return ok

func _choose(p):
	var client = HTTPRequest.new()
	root.add_child(client)
	client.timeout = 8.0
	var request = {"choice_id": p.get_observation("npc_a")["observation_id"],
		"events": p.experiences.duplicate(true), "available_conditions": ["solo", "joint", "defer"]}
	var err = client.request("http://127.0.0.1:8765/soc1/choose", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(request))
	if err != OK:
		check(false, "choice request failed")
		client.queue_free()
		return {}
	var response = await client.request_completed
	client.queue_free()
	var result = JSON.parse_string(response[3].get_string_from_utf8())
	if not check(response[1] == 200 and result is Dictionary and result.has("selected"), "choice rejected: " + str(result)): return {}
	match result["selected"]:
		"solo": p.participants = ["npc_a"]
		"joint": p.participants = ["npc_a", "npc_c"]
	return result

func _run():
	var w = Workbench.new()
	root.add_child(w)
	var p = Heavy.new()
	p.set_safety_actions_enabled(true)
	p.set_incapacitation_fixture_enabled(true)
	p.reset()
	p.run_id = OS.get_environment("SOC1_WORLD_RUN")
	for i in range(3):
		p.resolve_action({"agent_id": "npc_b", "action": {"type": "flee", "target_id": "plaza"},
			"inspection": {"observation_id": p.get_observation("npc_b")["observation_id"]}})
	p.set_safety_actions_enabled(false)
	var origin = p.get_agent("npc_b")["position"]
	p.agents[p._find_agent_index("npc_a")]["position"] = origin + Vector2(120, 0)
	p.agents[p._find_agent_index("npc_c")]["position"] = origin
	var initial = {"positions": [], "b_body": p.get_body_snapshot("npc_b"), "carry_attempts": p.attempt_count, "experiences": p.experiences.size()}
	for a in p.agents: initial["positions"].append({"id": a["id"], "position": [a["position"].x, a["position"].y]})
	w.state_provider = p
	w.selected_agent_id = "npc_a"
	var choices = []
	var choice = await _choose(p)
	if choice.is_empty(): quit(1); return
	choices.append(choice)
	var actions = []
	var status = "deferred" if choice["selected"] == "defer" else "incomplete"
	if status != "deferred":
		w._on_mode_selected(1)
		for guard in range(30):
			if not await _wait(w): return
			var decision = w.runtime_decision
			var kind = decision.get("action", {}).get("type", "")
			actions.append(kind)
			if kind == "rescue" and p.body_states["npc_a"]["carried_agent_id"] == "":
				choice = await _choose(p)
				if choice.is_empty(): quit(1); return
				choices.append(choice)
				if choice["selected"] == "defer":
					status = "deferred"
					break
			if decision.get("inspection", {}).get("rescue", {}).get("trajectory_phase", "") == "COMPLETE":
				status = "completed"
				break
			if guard < 29: w._request_runtime_action_if_needed()
	var stages = []
	if status == "completed":
		for i in range(4):
			p.step()
			stages.append(p.get_body_snapshot("npc_b")["recovery_stage"])
		check(stages == ["stabilizing", "mobilizing", "recovering", "recovered"], "recovery failed")
		check(p.get_agent("npc_b")["position"] == p._get_place("plaza")["position"], "target not delivered")
	var solo_attempts = 0
	var joint_attempts = 0
	for e in p.experiences:
		if e["action"] == "rescue":
			if e["attempt_condition"] == "solo": solo_attempts += 1
			if e["attempt_condition"] == "joint": joint_attempts += 1
	var metrics = {"first_condition": choices[0]["selected"], "solo_attempts": solo_attempts,
		"solo_retries": maxi(0, solo_attempts - 1), "joint_attempts": joint_attempts,
		"condition_switches": choices.size() - 1, "status": status,
		"action_count": actions.size(), "actions_to_delivery": actions.find("deliver") + 1 if actions.has("deliver") else null}
	var evidence = {"schema": "soc1-godot-episode-v1", "world_run_id": p.run_id, "initial": initial,
		"actions": actions, "choices": choices, "metrics": metrics, "world_checks": p.world_checks,
		"experiences": p.experiences, "recovery_stages": stages}
	var file = FileAccess.open(OS.get_environment("SOC1_EVIDENCE_PATH"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	if not failed: print("SOC-1 EPISODE PASS: " + JSON.stringify(metrics))
	w.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _wait(w):
	var deadline = Time.get_ticks_msec() + 8000
	while w.runtime_pending or w.history_pending:
		if Time.get_ticks_msec() > deadline or w.runtime_decision.has("error"):
			check(false, "SOC1 Runtime timeout/error: " + str(w.runtime_decision))
			quit(1)
			return false
		await process_frame
	return true
