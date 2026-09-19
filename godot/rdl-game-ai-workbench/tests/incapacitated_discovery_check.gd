extends SceneTree

const Provider = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var provider = Provider.new()
	provider.set_safety_actions_enabled(true)
	provider.set_incapacitation_fixture_enabled(true)
	provider.reset()

	var target_id = "npc_b"
	var observer_id = "npc_a"
	var target = provider.get_agent(target_id)
	var initial = provider.get_observation(observer_id)
	if not initial["visible_agents"].is_empty():
		_fail("target must begin outside the observer boundary")
		return

	for step in range(3):
		var observation = provider.get_observation(target_id)
		var decision = {
			"agent_id": target_id,
			"action": {"type": "flee", "target_id": "plaza"},
			"inspection": {"observation_id": observation["observation_id"]}
		}
		provider.resolve_action(decision)

	if not provider.get_body_snapshot(target_id).get("incapacitated", false):
		_fail("target did not enter world-owned incapacitation")
		return

	var hidden = provider.get_observation(observer_id)
	if not hidden["visible_agents"].is_empty():
		_fail("incapacitation leaked outside the observer boundary")
		return

	for agent in provider.agents:
		if agent.get("id", "") == observer_id:
			agent["position"] = target["position"] + Vector2(40, 0)
			break
	var discovered = provider.get_observation(observer_id)
	if discovered["visible_agents"].size() != 1:
		_fail("observer did not receive exactly one visible agent")
		return
	var visible = discovered["visible_agents"][0]
	if visible.get("id", "") != target_id:
		_fail("bounded discovery identified the wrong agent")
		return
	if visible.get("condition", "") != "incapacitated":
		_fail("bounded visible condition is missing: %s" % [visible])
		return
	if visible.get("condition_schema", "") != "bounded-visible-agent-condition-v1":
		_fail("bounded visible condition provenance is missing")
		return
	for forbidden in ["injury_level", "danger_exposure_steps", "movement_scale"]:
		if visible.has(forbidden):
			_fail("private body detail leaked into visible agent: %s" % forbidden)
			return
	print("Incapacitated discovery check passed: %s" % [visible])
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
