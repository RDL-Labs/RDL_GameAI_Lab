extends SceneTree

const MockStateProviderScript = preload("res://scripts/mock_state_provider.gd")
const WorkbenchMainScript = preload("res://scripts/workbench_main.gd")

func _initialize():
	var provider = MockStateProviderScript.new()
	provider.reset()
	var before_state = provider.get_state()
	var legacy = provider.get_observation("npc_a")
	if legacy.has("observation_resolution"):
		_fail("unconfigured observation changed the legacy packet")
		return

	if not provider.configure_observation_resolution({"npc_a": {"food": "LOW"}}):
		_fail("valid rho packet configuration was rejected")
		return
	var enriched = provider.get_observation("npc_a")
	var sidecar = enriched.get("observation_resolution", {})
	if sidecar.get("schema_version", "") != "rho-observation-resolution-packet-v1":
		_fail("rho packet schema version missing")
		return
	var food = sidecar.get("domains", {}).get("food", {})
	if food.get("level", "") != "LOW" or food.get("selection", {}).get("assignment_source", "") != "explicit":
		_fail("rho packet did not preserve projection and selection provenance")
		return
	if JSON.stringify(sidecar).contains("base_food_stock") or JSON.stringify(sidecar).contains(str(before_state["base_food_stock"])):
		_fail("rho packet leaked exact World stock")
		return

	for field in ["tick", "agent_id", "perception_rule", "visible_agents", "visible_objects", "visible_places"]:
		if legacy[field] != enriched[field]:
			_fail("rho packet rewrote legacy field: %s" % field)
			return
	if provider.get_state() != before_state:
		_fail("rho packet generation mutated World state")
		return

	var workbench = WorkbenchMainScript.new()
	workbench.state_provider = provider
	var runtime_packet = workbench._build_runtime_packet("npc_a")
	if not runtime_packet.get("observation", {}).has("observation_resolution"):
		_fail("Workbench Runtime packet did not forward the rho sidecar")
		return
	workbench.free()

	provider.disable_observation_resolution()
	if provider.get_observation("npc_a").has("observation_resolution"):
		_fail("disabled rho packet remained attached")
		return

	print("rho observation packet check passed: opt-in sidecar preserves legacy fields")
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
