extends Area3D

signal movement_arrived(npc_id: String, target_id: String)

const LABEL_NODE_PATH := "NameLabel"

@export var move_speed := 5.0

var npc_id: String = ""
var profile: Dictionary = {}
var _movement_target_id := ""
var _movement_target_position := Vector3.ZERO
var _is_moving := false

@onready var _name_label := get_node_or_null(LABEL_NODE_PATH) as Label3D


func setup(npc_profile: Dictionary) -> void:
	profile = npc_profile.duplicate(true)
	npc_id = str(profile.get("id", ""))
	name = _make_node_name(npc_id)
	set_meta("npc_id", npc_id)
	_refresh_label()


func update_profile(npc_profile: Dictionary) -> void:
	profile = npc_profile.duplicate(true)
	var states: Dictionary = profile.get("states", {})
	if bool(states.get("unconscious", false)):
		stop_movement()
	_refresh_label()


func move_to_location(target_id: String, target_position: Vector3) -> void:
	_movement_target_id = target_id
	_movement_target_position = target_position
	_is_moving = true
	set_process(true)


func stop_movement() -> void:
	_is_moving = false
	_movement_target_id = ""
	set_process(false)


func _ready() -> void:
	input_ray_pickable = true
	set_process(_is_moving)
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	_refresh_label()


func _process(delta: float) -> void:
	if not _is_moving:
		return
	if _is_gameplay_paused():
		return

	var next_position := global_position.move_toward(_movement_target_position, move_speed * delta)
	global_position = next_position
	if global_position.distance_to(_movement_target_position) <= 0.05:
		global_position = _movement_target_position
		var arrived_target_id := _movement_target_id
		stop_movement()
		movement_arrived.emit(npc_id, arrived_target_id)


func _on_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_emit_clicked()


func _emit_clicked() -> void:
	print("NPC clicked: %s" % npc_id)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not npc_id.is_empty():
		event_bus.npc_clicked.emit(npc_id)


func _refresh_label() -> void:
	if _name_label == null:
		return

	var display_name := str(profile.get("name", npc_id))
	var states: Dictionary = profile.get("states", {})
	var hp := int(states.get("hp", 0))
	var max_hp := int(states.get("max_hp", 0))
	var action_text := str(states.get("current_action", "idle"))
	if bool(states.get("unconscious", false)):
		action_text = "昏迷"
	_name_label.text = "%s\nHP %d/%d · %s" % [
		display_name,
		hp,
		max_hp,
		action_text
	]


func _make_node_name(id_value: String) -> String:
	if id_value.is_empty():
		return "NPC"

	var parts := id_value.split("_")
	var result := ""
	for part in parts:
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1).to_lower()
	return result


func _is_gameplay_paused() -> bool:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	return time_system != null and time_system.is_gameplay_paused()
