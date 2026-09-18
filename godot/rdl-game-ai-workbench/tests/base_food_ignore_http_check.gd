extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_b"
	workbench.state_provider.reset()
	var initial_need = workbench.state_provider.get_body_snapshot("npc_b")["food_need"]
	workbench._on_mode_selected(1)
	var deadline = Time.get_ticks_msec() + 5000
	while workbench.runtime_pending:
		if Time.get_ticks_msec() > deadline:
			_fail("ignore HTTP roundtrip timed out")
			return
		await process_frame
	var life = workbench.runtime_decision.get("inspection", {}).get("life", {})
	if workbench.runtime_decision.get("action", {}).get("type", "") != "idle":
		_fail("ignored cue unexpectedly commanded action")
		return
	if life.get("cue_response", "") != "ignore" or life.get("goal") != null:
		_fail("ignore disposition formed a Goal: %s" % life)
		return
	for i in range(8):
		workbench.state_provider.step()
	workbench._refresh_all()
	var state = workbench.state_provider.get_state()
	var final_need = workbench.state_provider.get_body_snapshot("npc_b")["food_need"]
	if state["base_food_band"] != "empty":
		_fail("ignored shortage did not reach empty Base stock: %s" % state)
		return
	if final_need <= initial_need:
		_fail("FoodNeed did not worsen after ignored shortage")
		return
	if not workbench.timeline_text.get_parsed_text().contains("Base food consumed"):
		_fail("Timeline lacks Base consumption evidence")
		return
	print("Base-Food ignore check passed: stock=%s need=%.2f->%.2f" % [
		state["base_food_band"], initial_need, final_need
	])
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
