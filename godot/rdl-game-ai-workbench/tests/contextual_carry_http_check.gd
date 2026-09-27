extends SceneTree
const Workbench = preload("res://scripts/workbench_main.gd")
const Carry = preload("res://scripts/contextual_carry_fixture.gd")
var failed = false

func _initialize(): _run.call_deferred()
func check(ok, message):
	if not ok:
		failed = true
		push_error(message)
	return ok

func _post(path, payload):
	var client = HTTPRequest.new()
	root.add_child(client)
	client.timeout = 8
	var code = client.request("http://127.0.0.1:8765" + path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if code != OK:
		check(false, "HTTP request failed")
		client.queue_free()
		return {}
	var response = await client.request_completed
	client.queue_free()
	var result = JSON.parse_string(response[3].get_string_from_utf8())
	if not check(response[1] == 200 and result is Dictionary, "HTTP result invalid: " + str(result)): return {}
	return result

func _run():
	var w = Workbench.new()
	root.add_child(w)
	var p = Carry.new()
	p.set_safety_actions_enabled(true)
	p.set_incapacitation_fixture_enabled(true)
	p.reset()
	p.run_id = OS.get_environment("SOC4_RUN_ID")
	for i in range(3):
		p.resolve_action({"agent_id": "npc_b", "action": {"type": "flee", "target_id": "plaza"},
			"inspection": {"observation_id": p.get_observation("npc_b")["observation_id"]}})
	p.set_safety_actions_enabled(false)
	p.agents[p._find_agent_index("npc_a")]["position"] = p.get_agent("npc_b")["position"] + Vector2(10, 0)
	p.set_movement_scale("npc_a", float(OS.get_environment("SOC4_MOVEMENT")))
	p.footing = OS.get_environment("SOC4_FOOTING")
	check(p.footing in ["firm", "loose"], "bad footing")
	w.state_provider = p
	var packet = w._build_runtime_packet("npc_a")
	var context = p.capture_context(packet)
	var acquired_position = p.get_agent("npc_a")["position"]
	check(context["actor_ready"] and context["target_ready"] and context["within_reach"], "precondition unavailable")
	var request = {"request_id": p.run_id + ":forecast", "episode_id": OS.get_environment("SOC4_EPISODE_ID"), "context": context}
	var prediction = {}
	if OS.get_environment("SOC4_FORECAST") == "1":
		prediction = await _post("/soc4/predict", request)
		if prediction.is_empty(): quit(1); return
		check(p.experiences.is_empty() and p.attempt_count == 0, "forecast obtained after outcome")
		check(prediction == await _post("/soc4/predict", request), "forecast replay changed")
	var before = {"actor": p.get_agent("npc_a")["position"], "target": p.get_agent("npc_b")["position"],
		"movement": p.body_states["npc_a"]["movement_scale"], "footing": p.footing, "body_ref": p.get_body_snapshot("npc_a")["snapshot_id"]}
	# Experimental verification deliberately tries solo regardless of prediction.
	var decision = await _post("/v1/observe", packet)
	if not check(decision.get("action", {}).get("type", "") == "rescue", "expected existing Runtime rescue"): quit(1); return
	p.resolve_action(decision)
	check(p.experiences.size() == 1 and p.attempt_count == 1, "one carry trial required")
	if p.experiences.is_empty(): quit(1); return
	var stable = before["actor"] == acquired_position and before["body_ref"] == context["body_ref"] and before["movement"] == packet["observation"]["body"]["movement_scale"] and before["footing"] == context["footing_band"]
	stable = stable and before["actor"] == p.get_agent("npc_a")["position"] and before["movement"] == p.body_states["npc_a"]["movement_scale"] and before["footing"] == p.footing
	var event = p.experiences[0]
	var established = p.body_states["npc_a"]["carried_agent_id"] == "npc_b"
	check(established == (event["result"] == "carry_established"), "event and body disagree")
	if not established: check(before["target"] == p.get_agent("npc_b")["position"], "failed carry moved target")
	var state = [p.agents.duplicate(true), p.body_states.duplicate(true), p.experiences.duplicate(true), p.attempt_count]
	p.resolve_action(decision)
	check(state == [p.agents, p.body_states, p.experiences, p.attempt_count], "action replay repeated effect")
	var extra = decision.duplicate(true)
	extra["inspection"]["observation_id"] = p.get_observation("npc_a")["observation_id"]
	p.resolve_action(extra)
	check(state == [p.agents, p.body_states, p.experiences, p.attempt_count], "second distinct action exceeded one-trial budget")
	var material = {"episode_id": request["episode_id"], "context": context, "event": event,
		"conditions_stable": stable, "termination": "carry_observed"}
	var evidence = {"material": material, "prediction_request": request if not prediction.is_empty() else null,
		"prediction": prediction, "decision": decision, "packet": packet, "world_checks": p.world_checks,
		"experimenter_only": {"carry_capabilities": p.carry_capabilities, "target_load": p.target_load,
			"effective_capacity": 3 if before["movement"] == 1.0 else 2, "resistance": 2 if p.footing == "firm" else 3},
		"verification_authority": "experimenter-prescribed-solo-trial; not-prediction-driven-action"}
	var file = FileAccess.open(OS.get_environment("SOC4_EVIDENCE_PATH"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	if not failed: print("SOC-4 EPISODE PASS: " + event["result"])
	w.queue_free()
	await process_frame
	quit(1 if failed else 0)
