extends Control

const MockStateProviderScript = preload("res://scripts/mock_state_provider.gd")
const WORLD_SIZE = Vector2(460, 340)
const TICK_SECONDS = 0.6

var state_provider = MockStateProviderScript.new()
var is_running = false
var selected_agent_id = "npc_a"
var entity_buttons = {}

var tick_label
var status_label
var world_panel
var inspector_text
var observation_text
var decision_text
var timeline_text
var tick_timer

func _ready():
	_build_ui()
	_build_timer()
	state_provider.reset()
	_refresh_all()

func _build_ui():
	var root = HBoxContainer.new()
	root.name = "WorkbenchLayout"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var left = VBoxContainer.new()
	left.name = "WorldColumn"
	left.custom_minimum_size = Vector2(540, 0)
	root.add_child(left)

	var title = Label.new()
	title.text = "RDL GameAI Workbench Shell"
	title.add_theme_font_size_override("font_size", 22)
	left.add_child(title)

	var toolbar = HBoxContainer.new()
	toolbar.name = "Controls"
	left.add_child(toolbar)

	var run_button = Button.new()
	run_button.text = "Run"
	run_button.pressed.connect(_on_run_pressed)
	toolbar.add_child(run_button)

	var pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(_on_pause_pressed)
	toolbar.add_child(pause_button)

	var step_button = Button.new()
	step_button.text = "Step"
	step_button.pressed.connect(_on_step_pressed)
	toolbar.add_child(step_button)

	var reset_button = Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(_on_reset_pressed)
	toolbar.add_child(reset_button)

	tick_label = Label.new()
	tick_label.text = "Tick: 0"
	tick_label.custom_minimum_size = Vector2(110, 0)
	toolbar.add_child(tick_label)

	status_label = Label.new()
	status_label.text = "Paused"
	toolbar.add_child(status_label)

	var world_title = Label.new()
	world_title.text = "2D World View"
	world_title.add_theme_font_size_override("font_size", 16)
	left.add_child(world_title)

	world_panel = Panel.new()
	world_panel.name = "WorldView"
	world_panel.custom_minimum_size = WORLD_SIZE
	left.add_child(world_panel)

	var right = VBoxContainer.new()
	right.name = "ObservationColumn"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)

	var inspector_title = Label.new()
	inspector_title.text = "Agent Inspector"
	inspector_title.add_theme_font_size_override("font_size", 16)
	right.add_child(inspector_title)

	inspector_text = RichTextLabel.new()
	inspector_text.name = "AgentInspector"
	inspector_text.custom_minimum_size = Vector2(360, 190)
	inspector_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(inspector_text)

	var observation_title = Label.new()
	observation_title.text = "Bounded Observation"
	observation_title.add_theme_font_size_override("font_size", 16)
	right.add_child(observation_title)

	observation_text = RichTextLabel.new()
	observation_text.name = "BoundedObservation"
	observation_text.custom_minimum_size = Vector2(360, 180)
	observation_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(observation_text)

	var decision_title = Label.new()
	decision_title.text = "Decision Record"
	decision_title.add_theme_font_size_override("font_size", 16)
	right.add_child(decision_title)

	decision_text = RichTextLabel.new()
	decision_text.name = "DecisionRecord"
	decision_text.custom_minimum_size = Vector2(360, 110)
	decision_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(decision_text)

	var timeline_title = Label.new()
	timeline_title.text = "Timeline / Event Log"
	timeline_title.add_theme_font_size_override("font_size", 16)
	right.add_child(timeline_title)

	timeline_text = RichTextLabel.new()
	timeline_text.name = "Timeline"
	timeline_text.custom_minimum_size = Vector2(360, 250)
	timeline_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(timeline_text)

func _build_timer():
	tick_timer = Timer.new()
	tick_timer.name = "TickTimer"
	tick_timer.wait_time = TICK_SECONDS
	tick_timer.timeout.connect(_on_tick_timer_timeout)
	add_child(tick_timer)

func _on_run_pressed():
	is_running = true
	tick_timer.start()
	_refresh_status()

func _on_pause_pressed():
	is_running = false
	tick_timer.stop()
	_refresh_status()

func _on_step_pressed():
	is_running = false
	tick_timer.stop()
	state_provider.step()
	_refresh_all()

func _on_reset_pressed():
	is_running = false
	tick_timer.stop()
	selected_agent_id = "npc_a"
	state_provider.reset()
	_refresh_all()

func _on_tick_timer_timeout():
	if not is_running:
		return
	state_provider.step()
	_refresh_all()

func _on_agent_pressed(agent_id):
	selected_agent_id = agent_id
	_refresh_all()

func _refresh_all():
	var state = state_provider.get_state()
	tick_label.text = "Tick: %d" % state["tick"]
	_refresh_status()
	_refresh_world(state)
	_refresh_inspector()
	_refresh_observation(state)
	_refresh_decision()
	_refresh_timeline(state)

func _refresh_status():
	if is_running:
		status_label.text = "Running"
	else:
		status_label.text = "Paused"

func _refresh_world(state):
	for child in world_panel.get_children():
		child.queue_free()
	entity_buttons.clear()

	for place in state["places"]:
		_add_entity_button(place, Color(0.55, 0.55, 0.55), false)

	for object_data in state["objects"]:
		_add_entity_button(object_data, Color(0.38, 0.68, 0.36), false)

	for agent in state["agents"]:
		_add_entity_button(agent, Color(0.35, 0.55, 0.9), true)

func _add_entity_button(entity, color, selectable):
	var button = Button.new()
	button.text = entity["label"]
	button.custom_minimum_size = Vector2(96, 40)
	button.position = entity["position"]
	button.tooltip_text = entity.get("note", "")
	button.modulate = color
	world_panel.add_child(button)
	entity_buttons[entity["id"]] = button
	if selectable:
		button.pressed.connect(_on_agent_pressed.bind(entity["id"]))
		if entity["id"] == selected_agent_id:
			button.text = "* " + entity["label"]

func _refresh_inspector():
	var agent = state_provider.get_agent(selected_agent_id)
	if agent.is_empty():
		inspector_text.text = "No agent selected."
		return

	var position = agent["position"]
	inspector_text.text = ""
	inspector_text.append_text("[b]%s[/b]\n" % agent["label"])
	inspector_text.append_text("id: %s\n" % agent["id"])
	inspector_text.append_text("role: %s\n" % agent["role"])
	inspector_text.append_text("mock mood: %s\n" % agent["mood"])
	inspector_text.append_text("position: (%.1f, %.1f)\n\n" % [position.x, position.y])
	inspector_text.append_text("P0 boundary:\n")
	inspector_text.append_text("- mock data only\n")
	inspector_text.append_text("- no Python connection\n")
	inspector_text.append_text("- no RDL semantic logic yet\n")

func _refresh_observation(state):
	var observation = state_provider.get_observation(selected_agent_id)
	if observation.is_empty():
		observation_text.text = "No bounded observation available."
		return

	var world_object_count = state["objects"].size()
	var visible_object_count = observation["visible_objects"].size()
	observation_text.text = ""
	observation_text.append_text("[b]%s[/b]\n" % selected_agent_id)
	observation_text.append_text("rule: %s\n" % observation["perception_rule"])
	observation_text.append_text("visible agents: %s\n" % _labels_for(observation["visible_agents"]))
	observation_text.append_text("visible objects: %s\n" % _labels_for(observation["visible_objects"]))
	observation_text.append_text("visible places: %s\n" % _labels_for(observation["visible_places"]))
	observation_text.append_text("world objects visible to observer UI: %d\n" % world_object_count)
	observation_text.append_text("objects inside selected agent boundary: %d\n" % visible_object_count)
	if visible_object_count < world_object_count:
		observation_text.append_text("bounded evidence: at least one world object is outside this observation.\n")

func _refresh_decision():
	var decision = state_provider.get_latest_decision(selected_agent_id)
	if decision.is_empty():
		decision_text.text = "No decision record available."
		return

	decision_text.text = ""
	decision_text.append_text("tick: %d\n" % decision["tick"])
	decision_text.append_text("agent: %s\n" % decision["agent_id"])
	decision_text.append_text("observation: %s\n" % decision["observation_summary"])
	decision_text.append_text("action: %s\n" % decision["chosen_action"])
	decision_text.append_text("reason: %s\n" % decision["decision_reason"])

func _refresh_timeline(state):
	timeline_text.text = ""
	for event in state["events"]:
		timeline_text.append_text(event + "\n")

func _labels_for(items):
	if items.is_empty():
		return "(none)"
	var text = ""
	for item in items:
		if text != "":
			text += ", "
		text += item.get("label", item.get("id", "?"))
	return text
