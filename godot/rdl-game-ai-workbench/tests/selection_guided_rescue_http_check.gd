extends SceneTree
const Workbench = preload("res://scripts/workbench_main.gd")
const Guided = preload("res://scripts/selection_guided_rescue_fixture.gd")
var failed = false
var choice_calls = []
var replay_checks = 0
var action_replay_checks = 0

func _initialize(): _run.call_deferred()
func check(ok, message):
	if not ok:
		failed = true
		push_error(message)
	return ok

func _post(request):
	var client = HTTPRequest.new()
	root.add_child(client)
	client.timeout = 8.0
	var err = client.request("http://127.0.0.1:8765/soc3/choose", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(request))
	if err != OK:
		check(false, "choice request failed")
		client.queue_free()
		return {}
	var response = await client.request_completed
	client.queue_free()
	var result = JSON.parse_string(response[3].get_string_from_utf8())
	if not check(response[1] == 200 and result is Dictionary and result.has("selected"), "choice rejected: " + str(result)): return {}
	return result

func _choose(p):
	var obs = p.get_observation("npc_a")
	var request = {"choice_id": obs["observation_id"], "binding": p.binding,
		"source_observation_id": obs["observation_id"], "context_ref": p.binding["context_ref"],
		"events": p.experiences.duplicate(true), "execution_refs": p.execution_refs.duplicate(true),
		"available_conditions": p.available_conditions()}
	if not check(p.expect_choice(request["choice_id"]), "choice requested without a new boundary"): return {}
	var result = await _post(request)
	if result.is_empty(): return {}
	if not check(p.apply_choice(result), "current choice not applied"): return {}
	choice_calls.append({"request": request.duplicate(true), "result": result.duplicate(true)})
	var replay = await _post(request)
	var before = [p.participants.duplicate(), p.applied_choices.size(), p.attempt_count, p.experiences.size()]
	check(replay == result, "same choice request changed result")
	check(not p.apply_choice(replay), "choice replay reapplied")
	check(before == [p.participants, p.applied_choices.size(), p.attempt_count, p.experiences.size()], "choice replay changed body/state")
	replay_checks += 1
	if choice_calls.size() > 1:
		var old = await _post(choice_calls[0]["request"])
		check(not p.apply_choice(old), "old choice revived")
		check(p.active_choice["choice_id"] == result["choice_id"], "old reply replaced latest choice")
		replay_checks += 1
	return result

func _guard_checks(base_binding):
	# Direct fixture checks, separate from the three HTTP episode outcomes.
	for mode in ["helper_lost", "actor_lost", "consumed"]:
		var p = Guided.new()
		p.reset()
		p.body_states["npc_b"]["incapacitated"] = true
		var origin = p.get_agent("npc_b")["position"]
		p.agents[p._find_agent_index("npc_a")]["position"] = origin
		p.agents[p._find_agent_index("npc_c")]["position"] = origin
		var scope = base_binding.duplicate(true)
		scope["world_run_id"] += "-guard-" + mode
		p.configure(scope)
		var choice = {"schema": "soc3-selection-guided-rescue-v1", "binding": scope,
			"request_choice_id": "guard", "source_observation_id": "guard", "choice_index": 1,
			"choice_id": "guard-choice", "selected": "joint"}
		check(p.expect_choice("guard"), "guard could not reserve choice")
		var wrong = choice.duplicate(true)
		wrong["binding"]["world_run_id"] = "foreign"
		check(not p.apply_choice(wrong), "foreign choice accepted")
		check(p.apply_choice(choice), "guard choice not applied")
		if mode == "helper_lost": p.agents[p._find_agent_index("npc_c")]["position"] += Vector2(1000, 0)
		if mode == "actor_lost": p.body_states["npc_a"]["incapacitated"] = true
		p.target_load = 3
		var decision = {"agent_id": "npc_a", "action": {"type": "rescue", "target_id": "npc_b"},
			"inspection": {"observation_id": p.get_observation("npc_a")["observation_id"]}}
		p.resolve_action(decision)
		if mode == "consumed":
			check(p.attempt_count == 1 and p.experiences.size() == 1, "guard first failure absent")
			decision["inspection"]["observation_id"] = p.get_observation("npc_a")["observation_id"]
			p.resolve_action(decision)
			check(p.blocked_reason == "choice_already_consumed" and p.attempt_count == 1 and p.experiences.size() == 1, "choice reused for another attempt")
		else:
			check(p.blocked_reason == "current_condition_lost" and p.attempt_count == 0 and p.experiences.is_empty(), "lost condition became a failed trial")
		check(p.get_agent("npc_b")["position"] == origin, "guard moved target")
		p.close_episode()
		check(not p.apply_choice(choice), "closed guard accepted choice")
	return ["helper_lost", "actor_lost", "consumed"]

func _run():
	var w = Workbench.new()
	root.add_child(w)
	var p = Guided.new()
	p.set_safety_actions_enabled(true)
	p.set_incapacitation_fixture_enabled(true)
	p.reset()
	var binding = JSON.parse_string(OS.get_environment("SOC3_BINDING"))
	p.run_id = binding["world_run_id"]
	for i in range(3):
		p.resolve_action({"agent_id": "npc_b", "action": {"type": "flee", "target_id": "plaza"},
			"inspection": {"observation_id": p.get_observation("npc_b")["observation_id"]}})
	p.set_safety_actions_enabled(false)
	var origin = p.get_agent("npc_b")["position"]
	p.agents[p._find_agent_index("npc_a")]["position"] = origin + Vector2(120, 0)
	p.agents[p._find_agent_index("npc_c")]["position"] = origin + (Vector2(1000, 0) if OS.get_environment("SOC3_HELPER_ABSENT") == "1" else Vector2.ZERO)
	p.configure(binding)
	var initial = {"positions": [], "b_body": p.get_body_snapshot("npc_b"), "carry_attempts": p.attempt_count, "experiences": p.experiences.size()}
	for a in p.agents: initial["positions"].append({"id": a["id"], "position": [a["position"].x, a["position"].y]})
	w.state_provider = p
	w.selected_agent_id = "npc_a"
	var choice = await _choose(p)
	if choice.is_empty(): quit(1); return
	var actions = []
	var status = "deferred" if choice["selected"] == "defer" else "incomplete"
	if status != "deferred":
		w._on_mode_selected(1)
		for guard in range(30):
			if not await _wait(w): return
			var decision = w.runtime_decision
			var kind = decision.get("action", {}).get("type", "")
			actions.append(kind)
			if not p.blocked_reason.is_empty(): break
			if kind == "rescue":
				var before = [p.attempt_count, p.experiences.size(), p.execution_refs.size(), p.action_choices.size(), p.action_receipts.size(), p.agents.duplicate(true), p.body_states.duplicate(true)]
				p.resolve_action(decision.duplicate(true))
				check(before == [p.attempt_count, p.experiences.size(), p.execution_refs.size(), p.action_choices.size(), p.action_receipts.size(), p.agents, p.body_states], "action replay repeated body effect")
				action_replay_checks += 1
				if p.body_states["npc_a"]["carried_agent_id"] == "":
					choice = await _choose(p)
					if choice.is_empty(): quit(1); return
					if choice["selected"] == "defer":
						status = "deferred"
						break
			if decision.get("inspection", {}).get("rescue", {}).get("trajectory_phase", "") == "COMPLETE":
				status = "completed"
				break
			if guard < 29: w._request_runtime_action_if_needed()
	p.close_episode()
	check(not p.apply_choice(choice_calls[0]["result"]), "closed episode revived")
	var stages = []
	if status == "completed":
		for i in range(4):
			p.step()
			stages.append(p.get_body_snapshot("npc_b")["recovery_stage"])
		check(stages == ["stabilizing", "mobilizing", "recovering", "recovered"], "recovery failed")
		check(p.get_agent("npc_b")["position"] == p._get_place("plaza")["position"], "target not delivered")
	elif status == "deferred":
		check(p.get_agent("npc_b")["position"] == origin, "deferred trial moved target")
		check(p.body_states["npc_a"]["carried_agent_id"].is_empty(), "deferred while carrying")
	check(p.blocked_reason.is_empty(), "unexpected execution stop")
	var solo = 0
	var joint = 0
	for event in p.experiences:
		if event["action"] == "rescue":
			if event["attempt_condition"] == "solo": solo += 1
			else: joint += 1
	var metrics = {"first_condition": choice_calls[0]["result"]["selected"], "solo_attempts": solo, "joint_attempts": joint,
		"status": status, "action_count": actions.size(), "actions_to_delivery": actions.find("deliver") + 1 if actions.has("deliver") else null,
		"rescue_goal_status": "completed" if status == "completed" else "pending"}
	var guard_checks = _guard_checks(binding)
	var evidence = {"guard_checks": guard_checks, "schema": "soc3-godot-episode-v1", "binding": binding, "initial": initial, "actions": actions,
		"choice_calls": choice_calls, "metrics": metrics, "world_checks": p.world_checks,
		"experiences": p.experiences, "execution_refs": p.execution_refs, "action_choices": p.action_choices,
		"recovery_stages": stages, "choice_replay_checks": replay_checks, "action_replay_checks": action_replay_checks,
		"experimenter_only": {"carry_capabilities": p.carry_capabilities, "target_load": p.target_load}}
	var file = FileAccess.open(OS.get_environment("SOC3_EVIDENCE_PATH"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	if not failed: print("SOC-3 EPISODE PASS: " + JSON.stringify(metrics))
	w.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _wait(w):
	var deadline = Time.get_ticks_msec() + 8000
	while w.runtime_pending or w.history_pending:
		if Time.get_ticks_msec() > deadline:
			check(false, "SOC3 Runtime timeout")
			quit(1)
			return false
		await process_frame
	if not check(not w.runtime_decision.has("error"), "SOC3 Runtime error: " + str(w.runtime_decision)):
		quit(1)
		return false
	return true
