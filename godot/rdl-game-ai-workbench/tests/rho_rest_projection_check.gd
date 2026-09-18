extends SceneTree

const MockStateProviderScript = preload("res://scripts/mock_state_provider.gd")

func _initialize():
	var provider = MockStateProviderScript.new()
	provider.reset()
	var before_state = provider.get_state()
	var before_context = provider.get_life_context("npc_a")
	var low = provider.get_rest_resolution_projection("npc_a", "LOW")
	var mid = provider.get_rest_resolution_projection("npc_a", "MID")
	var high = provider.get_rest_resolution_projection("npc_a", "HIGH")

	if low.get("distinctions", {}).get("rest_status", "") != "tired":
		_fail("LOW rest projection did not compress fatigue")
		return
	if mid.get("distinctions", {}).get("fatigue_band", "") != "tired":
		_fail("MID rest projection did not expose finite fatigue band")
		return
	var high_distinctions = high.get("distinctions", {})
	if high_distinctions.get("fatigue_trend", "") != "worsening":
		_fail("HIGH rest projection did not derive bounded temporal trend")
		return
	if high_distinctions.get("reachable_rest_context", "") != "available" or high_distinctions.get("safety_distinction", "") != "safe":
		_fail("HIGH rest projection did not expose bounded reachable context")
		return
	if not str(high.get("authority", "")).contains("not-RestNeed-sleep-H-M_B-or-action-authority"):
		_fail("rest projection authority boundary missing")
		return

	if not provider.configure_observation_resolution({
		"npc_a": {"rest": "LOW"},
		"npc_b": {"rest": "HIGH"}
	}):
		_fail("valid per-agent rest rho assignments were rejected")
		return
	var packet_a = provider.get_observation("npc_a")
	var packet_b = provider.get_observation("npc_b")
	var domains_a = packet_a.get("observation_resolution", {}).get("domains", {})
	var domains_b = packet_b.get("observation_resolution", {}).get("domains", {})
	if domains_a.keys() != ["rest"] or domains_b.keys() != ["rest"]:
		_fail("rest-only configuration leaked an unassigned domain")
		return
	if domains_a["rest"].get("level", "") != "LOW" or domains_b["rest"].get("level", "") != "HIGH":
		_fail("per-agent rest rho selection was not attached")
		return
	if provider.get_state() != before_state or provider.get_life_context("npc_a") != before_context:
		_fail("rest rho projection mutated World or life context")
		return

	print("rho Rest projection check passed: cross-domain, finite, and non-intervening")
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
