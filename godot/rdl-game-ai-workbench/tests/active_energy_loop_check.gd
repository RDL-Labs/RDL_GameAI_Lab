extends SceneTree

const Provider = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var rest_provider = Provider.new()
	rest_provider.reset()
	rest_provider.set_rest_actions_enabled(true)
	rest_provider.set_active_energy_enabled(true)
	_drain_and_reach_plaza(rest_provider, "npc_a")
	var before_rest = rest_provider.get_body_snapshot("npc_a")["active_energy"]
	var rest_resolution = rest_provider.resolve_action(_decision("npc_a", "rest", "plaza"))
	var after_rest = rest_provider.get_body_snapshot("npc_a")["active_energy"]
	if not is_equal_approx(after_rest - before_rest, Provider.ACTIVE_ENERGY_REST_RECOVERY):
		_fail("short rest did not apply finite ActiveEnergy recovery: %.2f -> %.2f" % [before_rest, after_rest])
		return

	var sleep_provider = Provider.new()
	sleep_provider.reset()
	sleep_provider.set_sleep_actions_enabled(true)
	sleep_provider.set_sleep_window(true)
	sleep_provider.set_active_energy_enabled(true)
	_drain_and_reach_plaza(sleep_provider, "npc_a")
	var before_sleep = sleep_provider.get_body_snapshot("npc_a")["active_energy"]
	var sleep_resolution = sleep_provider.resolve_action(_decision("npc_a", "sleep", "plaza"))
	var after_sleep = sleep_provider.get_body_snapshot("npc_a")["active_energy"]
	if after_sleep - before_sleep <= after_rest - before_rest:
		_fail("sleep did not recover more ActiveEnergy than short rest")
		return
	if sleep_resolution.get("effects", {}).get("consolidation", "") != "not_run":
		_fail("ActiveEnergy recovery crossed the consolidation boundary")
		return
	if rest_resolution.get("effects", {}).get("energy_model", "") != "active-energy-v1":
		_fail("short rest omitted ActiveEnergy provenance")
		return
	print("ActiveEnergy check passed: movement drained to %.2f, rest -> %.2f, sleep %.2f -> %.2f" % [before_rest, after_rest, before_sleep, after_sleep])
	quit(0)

func _drain_and_reach_plaza(provider, agent_id):
	for index in range(8):
		var target_id = "far_cache" if index % 2 == 0 else "plaza"
		provider.resolve_action(_decision(agent_id, "approach", target_id))
	for index in range(12):
		var resolution = provider.resolve_action(_decision(agent_id, "approach", "plaza"))
		if resolution.get("before_position", Vector2.ZERO) == resolution.get("after_position", Vector2.ZERO):
			break

func _decision(agent_id, action_type, target_id):
	return {
		"agent_id": agent_id,
		"action": {"type": action_type, "target_id": target_id},
		"inspection": {"observation_id": "energy-fixture"}
	}

func _fail(message):
	push_error(message)
	quit(1)
