extends SceneTree

const MockStateProviderScript = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var provider = MockStateProviderScript.new()
	provider.reset()
	var before_state = provider.get_state()
	var before_context_a = provider.get_life_context("npc_a")
	var before_context_b = provider.get_life_context("npc_b")

	if not provider.configure_observation_resolution({
		"npc_a": {"food": "LOW"},
		"npc_b": {"food": "HIGH"}
	}):
		_fail("valid rho profile assignments were rejected")
		return

	var low = provider.get_selected_food_resolution_projection("npc_a")
	var high = provider.get_selected_food_resolution_projection("npc_b")
	if low.get("level", "") != "LOW" or high.get("level", "") != "HIGH":
		_fail("per-agent rho selection was not applied")
		return
	if low.get("selection", {}).get("assignment_source", "") != "explicit":
		_fail("explicit rho selection provenance missing")
		return
	if high.get("selection", {}).get("selection_profile_version", "") != "rho-profile-selection-v1":
		_fail("rho selection version missing")
		return
	if low.get("distinctions", {}).has("stock_band") or not high.get("distinctions", {}).has("food_site_condition"):
		_fail("selected rho schemas were not distinct")
		return

	var accepted = provider.get_observation_resolution_assignments()
	if provider.configure_observation_resolution({"npc_a": {"food": "ULTRA"}}):
		_fail("invalid rho profile assignment was accepted")
		return
	if provider.get_observation_resolution_assignments() != accepted:
		_fail("invalid rho configuration partially replaced accepted assignments")
		return

	if provider.get_selected_food_resolution_projection("unassigned_agent") != {}:
		_fail("unknown agent should fail through provider agent validation")
		return
	if provider.get_state() != before_state:
		_fail("rho profile selection mutated world state")
		return
	if provider.get_life_context("npc_a") != before_context_a or provider.get_life_context("npc_b") != before_context_b:
		_fail("rho profile selection mutated default life context")
		return

	print("rho profile selection check passed: versioned, per-agent, and non-intervening")
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
