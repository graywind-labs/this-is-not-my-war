class_name HorseWorldView
extends Node3D


const HORSE_APPEARANCE := preload("res://scripts/presentation/characters/HorseAppearance.gd")

var horse_id := ""
var _horse_snapshot: Dictionary = {}
var _model: Node3D
var _name_label: Label3D
var _interaction_area: Area3D
var _applied_coat_color := ""


func setup_horse(horse_snapshot: Dictionary, horse_model: Node3D) -> void:
	horse_id = str(horse_snapshot.get("horse_id", "")).strip_edges()
	_horse_snapshot = horse_snapshot.duplicate(true)
	set_meta("horse_id", horse_id)
	set_meta("authority_role", "real_horse_read_only_projection")
	_model = horse_model
	if _model != null and _model.get_parent() != self:
		add_child(_model)
	_build_name_label()
	_build_interaction_area()
	refresh_horse(horse_snapshot)


func refresh_horse(horse_snapshot: Dictionary) -> void:
	_horse_snapshot = horse_snapshot.duplicate(true)
	if _name_label != null:
		_name_label.text = str(horse_snapshot.get("name", horse_id))
		_name_label.visible = bool(horse_snapshot.get("alive", true))
	var coat_color := str(horse_snapshot.get("coat_color", ""))
	if _model != null and coat_color != _applied_coat_color:
		HORSE_APPEARANCE.apply_coat_color(_model, coat_color)
		_applied_coat_color = coat_color
	set_meta("template_id", str(horse_snapshot.get("template_id", "")))
	set_meta("coat_name", str(horse_snapshot.get("coat_name", "")))
	set_meta("coat_color", str(horse_snapshot.get("coat_color", "")))
	set_meta("stable_slot_id", str(horse_snapshot.get("stable_slot_id", "")))


func get_visual_forward() -> Vector3:
	return (global_basis * Vector3.BACK).normalized()


func debug_click() -> void:
	_emit_horse_clicked()


func debug_get_snapshot() -> Dictionary:
	return {
		"horse_id": horse_id,
		"name": _name_label.text if _name_label != null else "",
		"name_visible": _name_label != null and _name_label.visible,
		"click_enabled": _interaction_area != null and _interaction_area.input_ray_pickable,
		"template_id": str(get_meta("template_id", "")),
		"coat_name": str(get_meta("coat_name", "")),
		"coat_color": str(get_meta("coat_color", "")),
		"stable_slot_id": str(get_meta("stable_slot_id", "")),
		"world_position": global_position,
		"visual_forward": get_visual_forward(),
		"visible": visible,
	}


func _build_name_label() -> void:
	if _name_label != null:
		return
	_name_label = Label3D.new()
	_name_label.name = "HorseNameLabel"
	_name_label.position = Vector3(0.0, 2.15, 0.0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.pixel_size = 0.014
	_name_label.outline_size = 7
	_name_label.outline_modulate = Color(0.04, 0.03, 0.02, 0.95)
	_name_label.modulate = Color(1.0, 0.94, 0.76, 1.0)
	_name_label.no_depth_test = true
	# Match NPC labels: visible to the main camera, omitted from the live portrait.
	_name_label.layers = 1 << 19
	add_child(_name_label)


func _build_interaction_area() -> void:
	if _interaction_area != null:
		return
	_interaction_area = Area3D.new()
	_interaction_area.name = "HorseInteractionArea"
	_interaction_area.collision_layer = 4
	_interaction_area.collision_mask = 0
	_interaction_area.monitoring = false
	_interaction_area.input_ray_pickable = true
	_interaction_area.set_meta("interaction_kind", "horse")
	_interaction_area.set_meta("horse_id", horse_id)
	_interaction_area.input_event.connect(_on_interaction_input_event)
	add_child(_interaction_area)
	var collision := CollisionShape3D.new()
	collision.name = "HorseInteractionCollision"
	collision.position = Vector3(0.0, 0.95, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, 1.9, 2.25)
	collision.shape = shape
	_interaction_area.add_child(collision)


func _on_interaction_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_emit_horse_clicked()


func _emit_horse_clicked() -> void:
	if horse_id.is_empty() or not visible:
		return
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("horse_clicked"):
		event_bus.horse_clicked.emit(horse_id)
		get_viewport().set_input_as_handled()
