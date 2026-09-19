extends SceneTree

const MockStateProvider = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var provider = MockStateProvider.new()
	provider.set_safety_actions_enabled(true)
	provider.set_incapacitation_fixture_enabled(true)
	provider.mock_wandering_enabled = false
	provider.reset()
	var target_id = "npc_b"
	var rescuer_id = "npc_a"

	for step in range(3):
		var observation = provider.get_observation(target_id)
		provider.resolve_action({
			"agent_id": target_id,
			"action": {"type": "flee", "target_id": "plaza"},
			"inspection": {"observation_id": observation["observation_id"]}
		})
	provider.set_safety_actions_enabled(false)
	var target_position = provider.get_agent(target_id)["position"]
	for agent in provider.agents:
		if agent.get("id", "") == rescuer_id:
			agent["position"] = target_position
	provider.resolve_action({
		"agent_id": rescuer_id,
		"action": {"type": "rescue", "target_id": target_id},
		"inspection": {"observation_id": "recovery-rescue"}
	})
	var plaza = provider.get_state()["places"].filter(func(place): return place.get("id", "") == "plaza")[0]
	for agent in provider.agents:
		if agent.get("id", "") == rescuer_id:
			agent["position"] = plaza["position"]
		if agent.get("id", "") == target_id:
			agent["position"] = plaza["position"]
	provider.resolve_action({
		"agent_id": rescuer_id,
		"action": {"type": "deliver", "target_id": "plaza"},
		"inspection": {"observation_id": "recovery-deliver"}
	})

	_assert_body(provider, target_id, "stabilizing", "severe", true, 0.0, 0)
	for agent in provider.agents:
		if agent.get("id", "") == target_id:
			agent["position"] = plaza["position"] + Vector2(20, 0)
	provider.step()
	_assert_body(provider, target_id, "stabilizing", "severe", true, 0.0, 0)
	for agent in provider.agents:
		if agent.get("id", "") == target_id:
			agent["position"] = plaza["position"]
	provider.step()
	_assert_body(provider, target_id, "stabilizing", "severe", true, 0.0, 1)
	provider.step()
	_assert_body(provider, target_id, "mobilizing", "medium", false, 0.35, 2)
	provider.step()
	_assert_body(provider, target_id, "recovering", "light", false, 0.7, 3)
	provider.step()
	_assert_body(provider, target_id, "recovered", "none", false, 1.0, 4)
	if provider.get_agent(target_id)["position"] != plaza["position"]:
		_fail("recovery moved the delivered target away from its safe place")
		return
	print("Rescue recovery check passed")
	quit(0)

func _assert_body(provider, agent_id, stage, injury, incapacitated, movement_scale, steps):
	var body = provider.get_body_snapshot(agent_id)
	if (
		body.get("recovery_stage") != stage
		or body.get("injury_level") != injury
		or body.get("incapacitated") != incapacitated
		or not is_equal_approx(body.get("movement_scale", -1.0), movement_scale)
		or body.get("recovery_steps") != steps
	):
		_fail("unexpected recovery body: %s" % [body])

func _fail(message):
	push_error(message)
	quit(1)
