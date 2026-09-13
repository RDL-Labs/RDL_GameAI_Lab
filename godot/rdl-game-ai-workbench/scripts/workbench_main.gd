extends Control

const MockStateProvider := preload("res://scripts/mock_state_provider.gd")

const WORLD_SIZE := Vector2(460, 340)
const TICK_SECONDS := 0.6

var state_provider := MockStateProvider.new()
var is_running := false
var selected_agent_id := "npc_a"
var entity_buttons: Dictionary = {}

var tick_label: Label
var status_label: Label
var world_panel: Panel
var inspector_text: RichTextLabel
var timeline_text: RichTextLabel
var tick_timer: Timer

func _ready() -> void:
	_build_ui()
	_build_timer()
	state_provider.reset()
	_refresh_all()

func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.name = "WorkbenchLayout"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var left := VBoxContainer.new()
	left.name = "WorldColumn"
	left.custom_minimum_size = Vector2(540, 0)
	root.add_child(left)

	var title := Label.new()
	title.text = "RDL GameAI Workbench Shell"
	title.add_theme_font_size_override("font_size", 22)
	left.add_child(title)

	var toolbar := HBoxContainer.new()
	toolbar.name = "Controls"
	left.add_child(toolbar)

	var run_button := Button.new()
	run_button.text = "Run"
	run_button.pressed.connect(_on_run_pressed)
	toolbar.add_child(run_button)

	var pause_button := Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(_on_pause_pressed)
	toolbar.add_child(pause_button)

	var step_button := Button.new()
	step_button.text = "Step"
	step_button.pressed.connect(_on_step_pressed)
	toolbar.add_child(step_button)

	var reset_button := Button.new()
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

	var world_title := Label.new()
	world_title.text = "2D World View"
	world_title.add_theme_font_size_override("font_size", 16)
	left.add_child(world_title)

	world_panel = Panel.new()
	world_panel.name = "WorldView"
	world_panel.custom_minimum_size = WORLD_SIZE
	left.add_child(world_panel)

	var right := VBoxContainer.new()
	right.name = "ObservationColumn"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)

	var inspector_title := Label.new()
	inspector_title.text = "Agent Inspector"
	inspector_title.add_theme_font_size_override("font_size", 16)
	right.add_child(inspector_title)

	inspector_text = RichTextLabel.new()
	inspector_text.name = "AgentInspector"
	inspector_text.fit_content = false
	inspector_text.custom_minimum_size = Vector2(360, 190)
	inspector_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(inspector_text)

	var timeline_title := Label.new()
	timeline_title.text = "Timeline / Event Log"
	timeline_title.add_theme_font_size_override("font_size", 16)
	right.add_child(timeline_title)

	timeline_text = RichTextLabel.new()
	timeline_text.name = "Timeline"
	timeline_text.fit_content = false
	timeline_text.custom_minimum_size = Vector2(360, 360)
	timeline_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(timeline_text)

func _build_timer() -> void:
	tick_timer = Timer.new()
	tick_timer.name = "TickTimer"
	tick_timer.wait_time = TICK_SECONDS
	tick_timer.timeout.connect(_on_tick_timer_timeout)
	add_child(tick_timer)

func _on_run_pressed() -> void:
	is_running = true
	tick_timer.start()
	_refresh_status()

func _on_pause_pressed() -> void:
	is_running = false
	tick_timer.stop()
	_refresh_status()

func _on_step_pressed() -> void:
	is_running = false
	tick_timer.stop()
	state_provider.step()
	_refresh_all()

func _on_reset_pressed() -> void:
	is_running = false
	tick_timer.stop()
	selected_agent_id = "npc_a"
	state_provider.reset()
	_refresh_all()

func _on_tick_timer_timeout() -> void:
	if not is_running:
		return
	state_provider.step()
	_refresh_all()

func _on_agent_pressed(agent_id: String) -> void:
	selected_agent_id = agent_id
	_refresh_all()

func _refresh_all() -> void:
	var state := state_provider.get_state()
	tick_label.text = "Tick: %d" % state["tick"]
	_refresh_status()
	_refresh_world(state)
	_refresh_inspector()
	_refresh_timeline(state)

func _refresh_status() -> void:
	status_label.text = "Running" if is_running else "Paused"

func _refresh_world(state: Dictionary) -> void:
	for child in world_panel.get_children():
		child.queue_free()
	entity_buttons.clear()

	var food := state["food"]
	_add_entity_button(food, Color(0.38, 0.68, 0.36), false)

	for agent in state["agents"]:
		_add_entity_button(agent, Color(0.35, 0.55, 0.9), true)

func _add_entity_button(entity: Dictionary, color: Color, selectable: bool) -> void:
	var button := Button.new()
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

func _refresh_inspector() -> void:
	var agent := state_provider.get_agent(selected_agent_id)
	if agent.is_empty():
		inspector_text.text = "No agent selected."
		return

	var position: Vector2 = agent["position"]
	inspector_text.text = ""
	inspector_text.append_text("[b]%s[/b]\n" % agent["label"])
	inspector_text.append_text("id: %s\n" % agent["id"])
	inspector_text.append_text("role: %s\n" % agent["role"])
	inspector_text.append_text("mock mood: %s\n" % agent["mood"])
	inspector_text.append_text("position: (%.1f, %.1f)\n\n" % [position.x, position.y])
	inspector_text.append_text("P0 boundary:\n")
	inspector_text.append_text("- mock data only\n")
	inspector_text.append_text("- no Python connection\n")
	inspector_text.append_text("- no RDL EFP / M_B / F / F' / E / H logic\n")

func _refresh_timeline(state: Dictionary) -> void:
	timeline_text.text = ""
	for event in state["events"]:
		timeline_text.append_text(event + "\n")
