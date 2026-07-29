extends Area3D

signal movement_arrived(npc_id: String, target_id: String)

const LABEL_NODE_PATH := "NameLabel"
const STATUS_LABEL_NODE_PATH := "StatusLabel"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const RECRUITED_NAME_COLOR := Color(0.64, 0.92, 0.68, 1.0)
const DEFAULT_NAME_COLOR := Color.WHITE

@export var move_speed := 5.0

var npc_id: String = ""
var profile: Dictionary = {}
var _movement_target_id := ""
var _movement_target_position := Vector3.ZERO
var _is_moving := false

@onready var _name_label := get_node_or_null(LABEL_NODE_PATH) as Label3D
@onready var _status_label := get_node_or_null(STATUS_LABEL_NODE_PATH) as Label3D
var _proactive_bubble: Label3D
var _dialogue_bubble_area: Area3D
var _dialogue_bubble_collision: CollisionShape3D
var _dialogue_bubble_label: Label3D
var _dialogue_bubble_material: StandardMaterial3D
var _llm_activity_marker: Label3D
var _escape_warning_marker: Label3D
var _mount_visual: MeshInstance3D
var _facing_marker: Label3D


func setup(npc_profile: Dictionary) -> void:
	profile = npc_profile.duplicate(true)
	npc_id = str(profile.get("id", ""))
	name = _make_node_name(npc_id)
	set_meta("npc_id", npc_id)
	_refresh_label()


func update_profile(npc_profile: Dictionary) -> void:
	profile = npc_profile.duplicate(true)
	var states: Dictionary = profile.get("states", {})
	if bool(states.get("escaped", false)):
		stop_movement()
		visible = false
		input_ray_pickable = false
		return
	visible = true
	input_ray_pickable = true
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
	_ensure_proactive_bubble()
	_ensure_dialogue_bubble()
	_ensure_llm_activity_marker()
	_ensure_escape_warning_marker()
	_ensure_combat_visuals()
	_refresh_label()


func _process(delta: float) -> void:
	if not _is_moving:
		return
	if _is_gameplay_paused():
		return

	var next_position := global_position.move_toward(_movement_target_position, move_speed * _get_move_speed_multiplier() * delta)
	global_position = next_position
	if global_position.distance_to(_movement_target_position) <= 0.05:
		global_position = _movement_target_position
		var arrived_target_id := _movement_target_id
		stop_movement()
		movement_arrived.emit(npc_id, arrived_target_id)


func _get_move_speed_multiplier() -> float:
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	var morale: Dictionary = states.get("morale_boost", {}) if states.get("morale_boost", {}) is Dictionary else {}
	var multiplier := 1.0
	if bool(morale.get("active", false)):
		multiplier += clampf(float(morale.get("move_speed_bonus", 0.0)), 0.0, 1.0)
	var escape_intent: Dictionary = states.get("escape_intent", {}) if states.get("escape_intent", {}) is Dictionary else {}
	if bool(escape_intent.get("active", false)) and str(escape_intent.get("status", "")) == "escaping":
		multiplier *= clampf(float(escape_intent.get("speed_multiplier", 1.0)), 0.25, 3.0)
	return multiplier


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
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("handle_npc_clicked") and npc_system.handle_npc_clicked(npc_id):
		get_viewport().set_input_as_handled()
		return
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not npc_id.is_empty():
		event_bus.npc_clicked.emit(npc_id)
		get_viewport().set_input_as_handled()


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
	elif _is_escape_warning_state(states):
		action_text = "逃离"
	elif action_text == "rallying_defense_line":
		action_text = "集结防线"
	elif action_text == "combat_ready":
		action_text = "接敌"
	elif action_text == "planning_day":
		action_text = "制定计划"
	elif action_text.begins_with("moving_to_combat_strategy_"):
		action_text = "战术移动"
	elif str(states.get("behavior_mode", "")) == "avoid_combat":
		action_text = "避战"
	_name_label.text = display_name
	_name_label.modulate = RECRUITED_NAME_COLOR if bool(profile.get("recruited", false)) else DEFAULT_NAME_COLOR
	if _status_label != null:
		_status_label.text = "HP %d/%d · %s" % [
		hp,
		max_hp,
		action_text
	]
	_ensure_proactive_bubble()
	_ensure_dialogue_bubble()
	_ensure_llm_activity_marker()
	_ensure_escape_warning_marker()
	_ensure_combat_visuals()
	var proactive: Dictionary = states.get("proactive_talk", {})
	_proactive_bubble.visible = bool(proactive.get("active", false))
	_refresh_dialogue_bubble(states)
	_refresh_llm_activity_marker(states)
	_refresh_escape_warning_marker(states)
	_refresh_combat_visuals(states)


func _ensure_proactive_bubble() -> void:
	if _proactive_bubble != null:
		return
	_proactive_bubble = Label3D.new()
	_proactive_bubble.name = "ProactiveTalkBubble"
	_proactive_bubble.text = "?"
	_proactive_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_proactive_bubble.pixel_size = 0.032
	_proactive_bubble.modulate = Color(1.0, 0.92, 0.24, 1.0)
	_proactive_bubble.outline_size = 8
	_proactive_bubble.outline_modulate = Color(0.08, 0.07, 0.02, 1.0)
	_proactive_bubble.position = Vector3(0.0, 2.45, 0.0)
	_proactive_bubble.visible = false
	add_child(_proactive_bubble)


func _ensure_dialogue_bubble() -> void:
	if _dialogue_bubble_area != null:
		return
	_dialogue_bubble_area = Area3D.new()
	_dialogue_bubble_area.name = "AutonomousDialogueBubble"
	_dialogue_bubble_area.set_meta("interaction_kind", "autonomous_dialogue_bubble")
	_dialogue_bubble_area.position = Vector3(0.0, 2.62, 0.0)
	_dialogue_bubble_area.input_ray_pickable = true
	_dialogue_bubble_area.collision_layer = 1
	_dialogue_bubble_area.collision_mask = 0
	_dialogue_bubble_area.monitoring = false
	_dialogue_bubble_area.monitorable = false
	_dialogue_bubble_area.visible = false
	add_child(_dialogue_bubble_area)
	_dialogue_bubble_area.input_event.connect(_on_dialogue_bubble_input_event)

	_dialogue_bubble_collision = CollisionShape3D.new()
	_dialogue_bubble_collision.name = "ClickCollision"
	var click_shape := SphereShape3D.new()
	click_shape.radius = 0.5
	_dialogue_bubble_collision.shape = click_shape
	_dialogue_bubble_collision.disabled = true
	_dialogue_bubble_area.add_child(_dialogue_bubble_collision)

	var bubble_body := MeshInstance3D.new()
	bubble_body.name = "BubbleBody"
	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.42
	bubble_mesh.height = 0.52
	bubble_body.mesh = bubble_mesh
	bubble_body.scale = Vector3(1.15, 0.78, 0.35)
	_dialogue_bubble_material = StandardMaterial3D.new()
	_dialogue_bubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dialogue_bubble_material.albedo_color = Color(0.96, 0.93, 0.78, 0.98)
	bubble_body.set_surface_override_material(0, _dialogue_bubble_material)
	_dialogue_bubble_area.add_child(bubble_body)

	_dialogue_bubble_label = Label3D.new()
	_dialogue_bubble_label.name = "BubbleText"
	_dialogue_bubble_label.text = "..."
	_dialogue_bubble_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dialogue_bubble_label.no_depth_test = true
	_dialogue_bubble_label.pixel_size = 0.014
	_dialogue_bubble_label.modulate = Color(0.12, 0.10, 0.07, 1.0)
	_dialogue_bubble_label.outline_size = 3
	_dialogue_bubble_label.outline_modulate = Color(0.96, 0.93, 0.78, 1.0)
	_dialogue_bubble_area.add_child(_dialogue_bubble_label)


func _refresh_dialogue_bubble(states: Dictionary) -> void:
	if _dialogue_bubble_area == null or _dialogue_bubble_collision == null:
		return
	var dialogue_id := str(states.get("active_dialogue_id", ""))
	var show_bubble := false
	var suspended_player_dialogue := false
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if not dialogue_id.is_empty() and dialog_system != null:
		if dialog_system.has_method("get_suspended_player_dialogue_state"):
			suspended_player_dialogue = not dialog_system.get_suspended_player_dialogue_state(npc_id).is_empty()
		if suspended_player_dialogue:
			show_bubble = true
		elif str(states.get("current_action", "")) == "talk_to_npc" and dialog_system.has_method("get_autonomous_dialogue_observer_state"):
			show_bubble = not dialog_system.get_autonomous_dialogue_observer_state(npc_id, dialogue_id).is_empty()
	_dialogue_bubble_area.visible = show_bubble
	_dialogue_bubble_area.set_meta("suspended_player_dialogue", suspended_player_dialogue)
	_dialogue_bubble_area.set_meta("npc_id", npc_id if show_bubble else "")
	_dialogue_bubble_area.set_meta("dialogue_id", dialogue_id if show_bubble else "")
	_dialogue_bubble_collision.set_deferred("disabled", not show_bubble)
	if _dialogue_bubble_material != null:
		_dialogue_bubble_material.albedo_color = Color(1.0, 0.52, 0.12, 0.98) if suspended_player_dialogue else Color(0.96, 0.93, 0.78, 0.98)
	if _dialogue_bubble_label != null:
		_dialogue_bubble_label.text = "↩" if suspended_player_dialogue else "..."
		_dialogue_bubble_label.outline_modulate = Color(1.0, 0.52, 0.12, 1.0) if suspended_player_dialogue else Color(0.96, 0.93, 0.78, 1.0)
	if show_bubble and _proactive_bubble != null:
		_proactive_bubble.visible = false


func _on_dialogue_bubble_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	_emit_dialogue_bubble_clicked()


func _emit_dialogue_bubble_clicked() -> void:
	if _dialogue_bubble_area == null or not _dialogue_bubble_area.visible:
		return
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	var dialogue_id := str(states.get("active_dialogue_id", ""))
	if dialogue_id.is_empty():
		return
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_dialogue_bubble_clicked"):
		event_bus.npc_dialogue_bubble_clicked.emit(npc_id, dialogue_id)
		get_viewport().set_input_as_handled()


func debug_get_dialogue_bubble_snapshot() -> Dictionary:
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	return {
		"visible": _dialogue_bubble_area != null and _dialogue_bubble_area.visible,
		"click_enabled": _dialogue_bubble_collision != null and not _dialogue_bubble_collision.disabled,
		"dialogue_id": str(states.get("active_dialogue_id", "")),
		"suspended_player_dialogue": _dialogue_bubble_area != null and bool(_dialogue_bubble_area.get_meta("suspended_player_dialogue", false))
	}


func debug_click_dialogue_bubble() -> void:
	_emit_dialogue_bubble_clicked()


func _ensure_llm_activity_marker() -> void:
	if _llm_activity_marker != null:
		return
	_llm_activity_marker = Label3D.new()
	_llm_activity_marker.name = "LLMActivityMarker"
	_llm_activity_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_llm_activity_marker.pixel_size = 0.032
	_llm_activity_marker.outline_size = 8
	_llm_activity_marker.outline_modulate = Color(0.04, 0.04, 0.04, 1.0)
	_llm_activity_marker.position = Vector3(0.0, 2.45, 0.0)
	_llm_activity_marker.visible = false
	add_child(_llm_activity_marker)


func _ensure_escape_warning_marker() -> void:
	if _escape_warning_marker != null:
		return
	_escape_warning_marker = Label3D.new()
	_escape_warning_marker.name = "EscapeWarningMarker"
	_escape_warning_marker.text = "!"
	_escape_warning_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_escape_warning_marker.pixel_size = 0.04
	_escape_warning_marker.modulate = Color(1.0, 0.22, 0.12, 1.0)
	_escape_warning_marker.outline_size = 9
	_escape_warning_marker.outline_modulate = Color(0.08, 0.02, 0.0, 1.0)
	_escape_warning_marker.position = Vector3(0.0, 2.75, 0.0)
	_escape_warning_marker.visible = false
	add_child(_escape_warning_marker)


func _ensure_combat_visuals() -> void:
	if _mount_visual == null:
		_mount_visual = MeshInstance3D.new()
		_mount_visual.name = "CombatMountVisual"
		var mount_mesh := BoxMesh.new()
		mount_mesh.size = Vector3(0.85, 0.28, 1.05)
		_mount_visual.mesh = mount_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.36, 0.22, 0.13, 1.0)
		_mount_visual.set_surface_override_material(0, material)
		_mount_visual.position = Vector3(0.0, 0.34, 0.0)
		_mount_visual.visible = false
		add_child(_mount_visual)
	if _facing_marker == null:
		_facing_marker = Label3D.new()
		_facing_marker.name = "CombatFacingMarker"
		_facing_marker.text = "↑"
		_facing_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_facing_marker.pixel_size = 0.028
		_facing_marker.modulate = Color(0.95, 0.86, 0.42, 1.0)
		_facing_marker.outline_size = 7
		_facing_marker.outline_modulate = Color(0.06, 0.05, 0.02, 1.0)
		_facing_marker.position = Vector3(0.0, 2.18, 0.0)
		_facing_marker.visible = false
		add_child(_facing_marker)


func _refresh_combat_visuals(states: Dictionary) -> void:
	var combat_mode := str(states.get("behavior_mode", states.get("combat_mode", "")))
	var show_combat_visuals := ["rally", "combat"].has(combat_mode)
	if _mount_visual != null:
		_mount_visual.visible = show_combat_visuals and bool(states.get("combat_mounted", false))
	if _facing_marker != null:
		_facing_marker.visible = show_combat_visuals


func _refresh_llm_activity_marker(states: Dictionary) -> void:
	if _llm_activity_marker == null:
		return
	if bool(states.get("first_sleep_summary_active", false)):
		_llm_activity_marker.text = "⊘"
		_llm_activity_marker.modulate = Color(1.0, 0.18, 0.16, 1.0)
		_llm_activity_marker.visible = true
		if _proactive_bubble != null:
			_proactive_bubble.visible = false
		return
	var activity: Dictionary = states.get("llm_activity", {}) if (states.get("llm_activity", {}) is Dictionary) else {}
	if (
		_dialogue_bubble_area != null
		and _dialogue_bubble_area.visible
		and str(activity.get("kind", "")) == "dialogue"
	):
		_llm_activity_marker.visible = false
		return
	if bool(activity.get("active", false)):
		_llm_activity_marker.text = "..."
		_llm_activity_marker.modulate = Color(0.42, 0.82, 1.0, 1.0)
		_llm_activity_marker.visible = true
		if _proactive_bubble != null:
			_proactive_bubble.visible = false
		return
	_llm_activity_marker.visible = false


func _refresh_escape_warning_marker(states: Dictionary) -> void:
	if _escape_warning_marker == null:
		return
	_escape_warning_marker.visible = _is_escape_warning_state(states)


func _is_escape_warning_state(states: Dictionary) -> bool:
	if bool(states.get("escaped", false)):
		return false
	var escape_intent: Dictionary = states.get("escape_intent", {}) if states.get("escape_intent", {}) is Dictionary else {}
	if not bool(escape_intent.get("active", false)):
		return false
	return ["escaping", "paused_unconscious"].has(str(escape_intent.get("status", "")))


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
