extends SceneTree

const MockStateProviderScript = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var provider = MockStateProviderScript.new()
	provider.reset()
	var before_state = provider.get_state()
	var before_context = provider.get_life_context("npc_b")
	var low = provider.get_food_resolution_projection("npc_b", "LOW")
	var mid = provider.get_food_resolution_projection("npc_b", "MID")
	var high = provider.get_food_resolution_projection("npc_b", "HIGH")
	var after_state = provider.get_state()
	var after_context = provider.get_life_context("npc_b")

	if low.get("distinctions", {}) == mid.get("distinctions", {}) or mid.get("distinctions", {}) == high.get("distinctions", {}):
		_fail("rho Food levels did not produce distinct finite projections")
		return
	if low.get("distinctions", {}).get("supply_status", "") != "needs_supply":
		_fail("LOW projection did not compress shortage")
		return
	if mid.get("distinctions", {}).get("stock_band", "") != before_context.get("observed_base_food_band", ""):
		_fail("MID projection did not preserve finite stock band")
		return
	if high.get("distinctions", {}).get("food_site_condition", "") != "available":
		_fail("HIGH projection did not expose bounded site condition")
		return
	for projection in [low, mid, high]:
		var encoded = JSON.stringify(projection)
		if encoded.contains("base_food_stock") or encoded.contains(str(before_state["base_food_stock"])):
			_fail("rho projection leaked exact world stock: %s" % encoded)
			return
		if not str(projection.get("authority", "")).contains("not-M_B-or-action-authority"):
			_fail("rho projection authority boundary missing")
			return
	if provider.get_food_resolution_projection("npc_b", "ULTRA") != {}:
		_fail("unsupported rho level did not fail closed")
		return
	if before_state != after_state or before_context != after_context:
		_fail("rho projection mutated world or default life context")
		return

	print("rho Food projection check passed: LOW/MID/HIGH finite and non-intervening")
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
