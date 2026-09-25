extends SceneTree

const MockStateProviderScript = preload("res://scripts/mock_state_provider.gd")


func _initialize():
	var provider = MockStateProviderScript.new()
	provider.set_risky_tasty_food_fixture_enabled(true)
	var state = provider.get_state()
	var objects = {}
	for item in state["objects"]:
		objects[item["id"]] = item
	if not objects.has("ordinary_food") or not objects.has("tasty_food") or not objects.has("beast_1"):
		_fail("Risky Tasty Food World objects are incomplete")
		return
	if objects["ordinary_food"].get("desirability_fixture", "") != "NORMAL":
		_fail("ordinary Food fixture value is missing")
		return
	if objects["tasty_food"].get("desirability_fixture", "") != "HIGH":
		_fail("tasty Food fixture value is missing")
		return
	if objects["tasty_food"].get("territory_id", "") != "north_grove":
		_fail("tasty Food is not physically related to the territory")
		return
	for item in state["objects"]:
		if item.has("danger") or item.has("dangerous") or item.has("threat_score"):
			_fail("World object injected NPC danger meaning: %s" % item)
			return

	var context = provider.get_life_context("npc_b")
	var statements = context.get("external_statements", [])
	if statements.size() != 1:
		_fail("God Statue statement was not projected")
		return
	var statement = statements[0]
	if statement.get("source_id", "") != "god_statue" or statement.get("subject_id", "") != "tasty_food":
		_fail("God Statue provenance is incomplete: %s" % statement)
		return
	if not statement.get("authority", "").contains("not-World-Truth-M_B-H-or-action"):
		_fail("statement authority boundary is missing")
		return

	print("Risky Tasty Food World check passed")
	quit(0)


func _fail(message):
	push_error(message)
	quit(1)
