extends Control
class_name WorkbenchWorldView

signal agent_selected(agent_id)

const AGENT_RADIUS = 11.0
const OBJECT_RADIUS = 6.0
const PLACE_MIN_RADIUS = 22.0

var world_state = {}
var selected_agent_id = ""
var committed_target_id = ""

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(false)

func set_visual_state(state, agent_id, target_id):
	world_state = state.duplicate(true)
	selected_agent_id = agent_id
	committed_target_id = target_id
	queue_redraw()

func _draw():
	if world_state.is_empty():
		return
	_draw_danger_zones()
	_draw_places()
	_draw_observation_boundary()
	_draw_committed_target()
	_draw_objects()
	_draw_agents()
	_draw_threats()

func _draw_danger_zones():
	for place in world_state.get("places", []):
		if not place.get("danger_capable", false):
			continue
		var radius = float(place.get("radius", PLACE_MIN_RADIUS))
		var position = Vector2(place["position"])
		draw_circle(position, radius, Color(0.78, 0.18, 0.16, 0.16))
		draw_arc(position, radius, 0.0, TAU, 64, Color(0.95, 0.32, 0.27, 0.8), 2.0)

func _draw_places():
	for place in world_state.get("places", []):
		var position = Vector2(place["position"])
		var radius = max(PLACE_MIN_RADIUS, float(place.get("radius", PLACE_MIN_RADIUS)))
		var color = Color(0.42, 0.67, 0.62, 0.18)
		if place.get("rest_safety", "") == "uncertain":
			color = Color(0.76, 0.66, 0.28, 0.16)
		draw_circle(position, radius, color)
		draw_arc(position, radius, 0.0, TAU, 64, color.lightened(0.25), 2.0)
		if place.get("id", "") == committed_target_id:
			draw_arc(position, radius + 5.0, 0.0, TAU, 64, Color(0.98, 0.82, 0.26), 3.0)

func _draw_observation_boundary():
	var agent = _entity_by_id(world_state.get("agents", []), selected_agent_id)
	if agent.is_empty():
		return
	var radius = float(world_state.get("perception_radius", 0.0))
	if radius <= 0.0:
		return
	draw_arc(Vector2(agent["position"]), radius, 0.0, TAU, 72, Color(0.4, 0.76, 0.96, 0.48), 1.5)

func _draw_committed_target():
	if committed_target_id.is_empty():
		return
	var agent = _entity_by_id(world_state.get("agents", []), selected_agent_id)
	var target = _find_world_entity(committed_target_id)
	if agent.is_empty() or target.is_empty():
		return
	var start = Vector2(agent["position"])
	var finish = Vector2(target["position"])
	draw_dashed_line(start, finish, Color(0.98, 0.82, 0.26, 0.92), 2.0, 8.0)
	var direction = (finish - start).normalized()
	if direction != Vector2.ZERO:
		var side = direction.rotated(PI * 0.75) * 9.0
		draw_line(finish, finish + side, Color(0.98, 0.82, 0.26), 2.0)
		draw_line(finish, finish + side.rotated(PI * 0.5), Color(0.98, 0.82, 0.26), 2.0)

func _draw_objects():
	for object_data in world_state.get("objects", []):
		if object_data.get("threat_capable", false):
			continue
		var position = Vector2(object_data["position"])
		var color = Color(0.43, 0.78, 0.35) if object_data.get("kind", "") == "food" else Color(0.62, 0.68, 0.72)
		draw_circle(position, OBJECT_RADIUS, color)

func _draw_agents():
	for agent in world_state.get("agents", []):
		var position = Vector2(agent["position"])
		draw_circle(position, AGENT_RADIUS, Color(0.25, 0.6, 0.92))
		draw_arc(position, AGENT_RADIUS, 0.0, TAU, 32, Color(0.8, 0.93, 1.0), 2.0)
		if agent.get("id", "") == selected_agent_id:
			draw_arc(position, AGENT_RADIUS + 5.0, 0.0, TAU, 32, Color(1.0, 0.84, 0.28), 3.0)

func _draw_threats():
	for object_data in world_state.get("objects", []):
		if not object_data.get("threat_capable", false):
			continue
		var position = Vector2(object_data["position"])
		var points = PackedVector2Array([
			position + Vector2(0, -22),
			position + Vector2(19, 16),
			position + Vector2(-19, 16),
			position + Vector2(0, -22)
		])
		draw_polyline(points, Color(1.0, 0.3, 0.24), 3.0)

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for agent in world_state.get("agents", []):
			if event.position.distance_to(Vector2(agent["position"])) <= AGENT_RADIUS + 7.0:
				agent_selected.emit(agent["id"])
				accept_event()
				return

func _get_tooltip(at_position):
	for collection in [world_state.get("agents", []), world_state.get("objects", []), world_state.get("places", [])]:
		for entity in collection:
			var radius = float(entity.get("radius", 16.0)) if entity.get("role", "") == "mock place" else 16.0
			if at_position.distance_to(Vector2(entity["position"])) <= max(radius, 16.0):
				return "%s\n%s" % [entity.get("label", "Entity"), entity.get("id", "unknown")]
	return ""

func _find_world_entity(entity_id):
	for collection in [world_state.get("agents", []), world_state.get("objects", []), world_state.get("places", [])]:
		var entity = _entity_by_id(collection, entity_id)
		if not entity.is_empty():
			return entity
	return {}

func _entity_by_id(entities, entity_id):
	for entity in entities:
		if entity.get("id", "") == entity_id:
			return entity
	return {}
