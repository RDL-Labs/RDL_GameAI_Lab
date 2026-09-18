extends SceneTree

const Provider = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var provider = Provider.new()
	provider.reset()
	provider.set_sleep_actions_enabled(true)
	provider.set_sleep_window(true)
	provider.set_active_energy_enabled(true)
	if not provider.set_active_energy_capacity("npc_a", 0.6):
		_fail("valid ActiveEnergyCapacity was rejected")
		return
	var configured = provider.get_body_snapshot("npc_a")
	if configured["active_energy_capacity"] != 0.6 or configured["active_energy"] != 0.6:
		_fail("capacity did not clamp current ActiveEnergy: %s" % configured)
		return
	provider.resolve_action(_decision("npc_a", "approach", "plaza"))
	provider.resolve_action(_decision("npc_a", "approach", "plaza"))
	var before_sleep = provider.get_body_snapshot("npc_a")["active_energy"]
	provider.resolve_action(_decision("npc_a", "sleep", "plaza"))
	var after_sleep = provider.get_body_snapshot("npc_a")
	if after_sleep["active_energy"] != 0.6 or after_sleep["active_energy_capacity"] != 0.6:
		_fail("Sleep recovery exceeded ActiveEnergyCapacity: %s" % after_sleep)
		return
	var revision = after_sleep["revision"]
	for invalid in [0.0, -0.1, 1.1, NAN, true]:
		if provider.set_active_energy_capacity("npc_a", invalid):
			_fail("invalid ActiveEnergyCapacity was accepted: %s" % invalid)
			return
	var unchanged = provider.get_body_snapshot("npc_a")
	if unchanged["active_energy_capacity"] != 0.6 or unchanged["revision"] != revision:
		_fail("invalid capacity update was not atomic")
		return
	print("ActiveEnergyCapacity check passed: %.2f -> sleep clamp %.2f/%.2f" % [before_sleep, after_sleep["active_energy"], after_sleep["active_energy_capacity"]])
	quit(0)

func _decision(agent_id, action_type, target_id):
	return {
		"agent_id": agent_id,
		"action": {"type": action_type, "target_id": target_id},
		"inspection": {"observation_id": "capacity-fixture"}
	}

func _fail(message):
	push_error(message)
	quit(1)
