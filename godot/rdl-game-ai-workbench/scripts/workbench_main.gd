extends Control

const MockStateProviderScript = preload("res://scripts/mock_state_provider.gd")
const WORLD_SIZE = Vector2(460, 340)
const TICK_SECONDS = 0.6
const RUNTIME_URL = "http://127.0.0.1:8765/v1/observe"

var state_provider = MockStateProviderScript.new()
var is_running = false
var selected_agent_id = "npc_a"
var entity_buttons = {}
var provider_mode = "mock"
var runtime_pending = false
var runtime_decision = {}

var tick_label
var status_label
var mode_select
var world_panel
var inspector_text
var observation_text
var decision_text
var timeline_text
var tick_timer
var runtime_request

func _ready():
	_build_ui()
	_build_timer()
	_build_runtime_request()
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

	mode_select = OptionButton.new()
	mode_select.add_item("Mock")
	mode_select.add_item("Runtime")
	mode_select.item_selected.connect(_on_mode_selected)
	toolbar.add_child(mode_select)

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

func _build_runtime_request():
	runtime_request = HTTPRequest.new()
	runtime_request.name = "RuntimeRequest"
	runtime_request.request_completed.connect(_on_runtime_request_completed)
	add_child(runtime_request)

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
	_request_runtime_action_if_needed()

func _on_reset_pressed():
	is_running = false
	tick_timer.stop()
	selected_agent_id = "npc_a"
	runtime_pending = false
	runtime_decision = {}
	state_provider.reset()
	_refresh_all()

func _on_tick_timer_timeout():
	if not is_running:
		return
	state_provider.step()
	_refresh_all()
	_request_runtime_action_if_needed()

func _on_agent_pressed(agent_id):
	selected_agent_id = agent_id
	_refresh_all()
	_request_runtime_action_if_needed()

func _on_mode_selected(index):
	if index == 1:
		provider_mode = "runtime"
	else:
		provider_mode = "mock"
	runtime_pending = false
	runtime_decision = {}
	_refresh_all()
	_request_runtime_action_if_needed()

func _request_runtime_action_if_needed():
	if provider_mode != "runtime":
		return
	if runtime_pending:
		return

	var packet = _build_runtime_packet(selected_agent_id)
	if packet.is_empty():
		return

	runtime_pending = true
	runtime_decision = {}
	_refresh_decision()

	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify(packet)
	var error = runtime_request.request(RUNTIME_URL, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		runtime_pending = false
		runtime_decision = {
			"error": "request_start_failed",
			"detail": "Godot HTTPRequest error %d" % error
		}
		_refresh_decision()

func _on_runtime_request_completed(result, response_code, headers, body):
	runtime_pending = false
	var response_text = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		runtime_decision = {
			"error": "runtime_request_failed",
			"detail": "result=%d status=%d body=%s" % [result, response_code, response_text]
		}
		_refresh_decision()
		return

	var parsed = JSON.parse_string(response_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		runtime_decision = {
			"error": "invalid_runtime_json",
			"detail": response_text
		}
		_refresh_decision()
		return

	runtime_decision = parsed
	_refresh_decision()

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
		status_label.text = "Running / %s" % provider_mode
	else:
		status_label.text = "Paused / %s" % provider_mode

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
	inspector_text.append_text("- optional localhost runtime bridge in Runtime mode\n")
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
	if provider_mode == "runtime":
		_refresh_runtime_decision()
		return

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

func _refresh_runtime_decision():
	decision_text.text = ""
	decision_text.append_text("mode: runtime bridge\n")
	decision_text.append_text("endpoint: %s\n" % RUNTIME_URL)
	if runtime_pending:
		decision_text.append_text("status: waiting for runtime response\n")
		return
	if runtime_decision.is_empty():
		decision_text.append_text("status: no runtime response yet\n")
		return
	if runtime_decision.has("error"):
		decision_text.append_text("error: %s\n" % runtime_decision.get("error", "unknown"))
		decision_text.append_text("detail: %s\n" % runtime_decision.get("detail", ""))
		return

	var action = runtime_decision.get("action", {})
	var inspection = runtime_decision.get("inspection", {})
	decision_text.append_text("agent: %s\n" % runtime_decision.get("agent_id", selected_agent_id))
	decision_text.append_text("action: %s\n" % action.get("type", "?"))
	if action.has("target_id"):
		decision_text.append_text("target: %s\n" % action["target_id"])
	decision_text.append_text("observation: %s\n" % inspection.get("observation_id", "?"))
	decision_text.append_text("reason: %s\n" % inspection.get("reason", "?"))

func _labels_for(items):
	if items.is_empty():
		return "(none)"
	var text = ""
	for item in items:
		if text != "":
			text += ", "
		text += item.get("label", item.get("id", "?"))
	return text

func _build_runtime_packet(agent_id):
	var observation = state_provider.get_observation(agent_id)
	if observation.is_empty():
		return {}
	var agent = state_provider.get_agent(agent_id)
	var origin = agent.get("position", Vector2.ZERO)

	return {
		"tick": observation["tick"],
		"agent_id": agent_id,
		"observation": {
			"visible_agents": _runtime_entities(observation["visible_agents"], origin),
			"visible_objects": _runtime_entities(observation["visible_objects"], origin),
			"visible_places": _runtime_entities(observation["visible_places"], origin)
		}
	}

func _runtime_entities(items, origin):
	var result = []
	for item in items:
		var position = item.get("position", Vector2.ZERO)
		var relative_position = position - origin
		var entity = {
			"id": item.get("id", ""),
			"label": item.get("label", ""),
			"role": item.get("role", ""),
			"relative_position": [relative_position.x, relative_position.y]
		}
		if item.get("role", "") == "mock object" and item.get("id", "").begins_with("food"):
			entity["kind"] = "food"
		result.append(entity)
	return result
