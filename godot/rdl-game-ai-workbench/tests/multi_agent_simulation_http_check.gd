extends SceneTree

const Workbench = preload("res://scripts/workbench_main.gd")

func _initialize():
	_run.call_deferred()

func _run():
	var workbench = Workbench.new()
	root.add_child(workbench)
	workbench.selected_agent_id = "npc_a"
	var before_a = workbench.state_provider.get_agent("npc_a")["position"]
	var before_b = workbench.state_provider.get_agent("npc_b")["position"]
	workbench.set_simulation_agents_enabled(true)
	workbench._on_mode_selected(1)
	var deadline = Time.get_ticks_msec() + 8000
	while workbench.runtime_pending or workbench.history_pending or not workbench.simulation_queue.is_empty():
		if Time.get_ticks_msec() > deadline:
			_fail("multi-agent simulation cycle timed out")
			return
		await process_frame
	await process_frame
	var decision_a = workbench.runtime_decisions_by_agent.get("npc_a", {})
	var decision_b = workbench.runtime_decisions_by_agent.get("npc_b", {})
	var after_a = workbench.state_provider.get_agent("npc_a")["position"]
	var after_b = workbench.state_provider.get_agent("npc_b")["position"]
	if workbench.selected_agent_id != "npc_a":
		_fail("simulation changed the Human inspector selection")
		return
	if decision_a.get("action", {}).get("type", "") != "idle":
		_fail("NPC A did not independently ignore its cue: %s" % decision_a)
		return
	if decision_b.get("action", {}).get("type", "") != "approach":
		_fail("NPC B did not independently act from its bounded observation: %s" % decision_b)
		return
	if after_a != before_a or after_b == before_b:
		_fail("selected A or simulated B moved unexpectedly: A %s->%s B %s->%s" % [before_a, after_a, before_b, after_b])
		return
	workbench.state_provider.step()
	if workbench.state_provider.get_agent("npc_b")["position"] != after_b:
		_fail("debug mock wandering changed position during simulation mode")
		return
	print("Multi-agent simulation check passed: selected A observed while B acted independently")
	workbench.queue_free()
	await process_frame
	quit(0)

func _fail(message):
	push_error(message)
	quit(1)
