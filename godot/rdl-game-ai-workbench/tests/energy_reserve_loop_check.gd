extends SceneTree

const Provider = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var provider = Provider.new()
	provider.reset()
	provider.set_rest_actions_enabled(true)
	provider.set_active_energy_enabled(true)
	provider.set_energy_reserve_enabled(true)
	var initial = provider.get_body_snapshot("npc_a")
	provider.resolve_action(_decision("npc_a", "approach", "plaza"))
	var after_move = provider.get_body_snapshot("npc_a")
	if after_move["energy_reserve"] != initial["energy_reserve"]:
		_fail("movement changed EnergyReserve")
		return
	provider.resolve_action(_decision("npc_a", "approach", "plaza"))
	provider.resolve_action(_decision("npc_a", "rest", "plaza"))
	var after_rest = provider.get_body_snapshot("npc_a")
	if after_rest["energy_reserve"] != initial["energy_reserve"]:
		_fail("short rest changed EnergyReserve")
		return

	provider.set_sleep_actions_enabled(true)
	provider.set_sleep_window(true)
	var sleep_resolution = provider.resolve_action(_decision("npc_a", "sleep", "plaza"))
	var after_sleep = provider.get_body_snapshot("npc_a")
	if not is_equal_approx(after_sleep["energy_reserve"] - initial["energy_reserve"], Provider.ENERGY_RESERVE_SLEEP_RECOVERY):
		_fail("bounded Sleep did not restore finite EnergyReserve")
		return
	var effects = sleep_resolution.get("effects", {})
	if effects.get("reserve_model", "") != "energy-reserve-v1" or effects.get("consolidation", "") != "not_run":
		_fail("EnergyReserve provenance crossed a boundary: %s" % effects)
		return
	print("EnergyReserve check passed: move/rest %.2f, sleep -> %.2f" % [initial["energy_reserve"], after_sleep["energy_reserve"]])
	quit(0)

func _decision(agent_id, action_type, target_id):
	return {
		"agent_id": agent_id,
		"action": {"type": action_type, "target_id": target_id},
		"inspection": {"observation_id": "reserve-fixture"}
	}

func _fail(message):
	push_error(message)
	quit(1)
