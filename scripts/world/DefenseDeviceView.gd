extends Node3D

const ACTIVE_INTERACTION_AND_PROJECTILE_LAYER := 6
const PROJECTILE_COLLISION_LAYER := 2
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const WORLD_HEALTH_BAR := preload("res://scripts/world/WorldHealthBar3D.gd")

@onready var model_mount: Node3D = $ModelMount
@onready var status_label: Label3D = $StatusLabel
@onready var interaction_area: Area3D = $InteractionArea

var _deployment_id := ""
var _device_id := ""
var _loaded_model_scene := ""
var _latest_snapshot: Dictionary = {}
var _is_ruin := false
var _world_health_bar: WorldHealthBar3D
var _last_world_health_wartime := false


func _ready() -> void:
	if interaction_area != null and not interaction_area.input_event.is_connected(_on_input_event):
		interaction_area.input_event.connect(_on_input_event)
	_ensure_world_health_bar()


func _process(_delta: float) -> void:
	var wartime := _is_world_health_wartime()
	if wartime != _last_world_health_wartime:
		_last_world_health_wartime = wartime
		_refresh_world_health_bar()


func configure_device(snapshot: Dictionary) -> void:
	_is_ruin = false
	_latest_snapshot = snapshot.duplicate(true)
	_deployment_id = str(snapshot.get("deployment_id", ""))
	_device_id = str(snapshot.get("device_id", ""))
	set_meta("deployment_id", _deployment_id)
	set_meta("device_id", _device_id)
	set_meta("slot_id", str(snapshot.get("slot_id", "")))
	interaction_area.set_meta("deployment_id", _deployment_id)
	interaction_area.set_meta("device_id", _device_id)
	position = _dict_to_vector3(snapshot.get("position", {}))
	rotation.y = deg_to_rad(float(snapshot.get("rotation_y_degrees", 0.0)))
	status_label.text = str(snapshot.get("device_name", "工程器械"))
	status_label.visible = true
	interaction_area.collision_layer = ACTIVE_INTERACTION_AND_PROJECTILE_LAYER
	interaction_area.input_ray_pickable = true

	var presentation: Dictionary = snapshot.get("presentation", {}) if snapshot.get("presentation", {}) is Dictionary else {}
	status_label.position.y = float(presentation.get("status_label_height", 1.45))
	_refresh_world_health_bar()
	var model_scene_path := str(presentation.get("model_scene", ""))
	if model_mount.get_child_count() == 0 or model_scene_path != _loaded_model_scene:
		_rebuild_model(presentation)
	_configure_active_model(snapshot)


func configure_device_ruin(snapshot: Dictionary) -> void:
	_is_ruin = true
	_latest_snapshot = snapshot.duplicate(true)
	_deployment_id = str(snapshot.get("deployment_id", ""))
	_device_id = str(snapshot.get("device_id", ""))
	set_meta("deployment_id", _deployment_id)
	set_meta("device_id", _device_id)
	set_meta("slot_id", str(snapshot.get("slot_id", "")))
	interaction_area.remove_meta("deployment_id")
	interaction_area.remove_meta("device_id")
	set_meta("device_ruin", true)
	position = _dict_to_vector3(snapshot.get("position", {}))
	rotation.y = deg_to_rad(float(snapshot.get("rotation_y_degrees", 0.0)))
	status_label.visible = false
	_refresh_world_health_bar()
	interaction_area.collision_layer = 0
	interaction_area.input_ray_pickable = false
	var presentation: Dictionary = snapshot.get("presentation", {}) if snapshot.get("presentation", {}) is Dictionary else {}
	var model_scene_path := str(presentation.get("model_scene", ""))
	if model_mount.get_child_count() == 0 or model_scene_path != _loaded_model_scene:
		_rebuild_model(presentation)
	_configure_active_model(snapshot)
	var active_model := _get_active_model()
	if active_model != null and active_model.has_method("set_destroyed_visual"):
		active_model.set_destroyed_visual(true)


func play_device_action(action_result: Dictionary) -> void:
	# Retained for isolated art previews. Production combat uses
	# sync_device_attack_timeline() and CombatSystem's physical projectile.
	show_device_action_result(action_result)
	var active_model := _get_active_model()
	if active_model != null and active_model.has_method("play_device_action"):
		active_model.play_device_action(action_result)


func show_device_action_result(action_result: Dictionary) -> void:
	# Combat feedback belongs to projectiles and panels; the world label stays a
	# stable, low-noise device name.
	status_label.text = str(action_result.get("device_name", _latest_snapshot.get("device_name", "工程器械")))


func sync_device_attack_timeline(phase_snapshot: Dictionary) -> void:
	if _is_ruin:
		return
	var active_model := _get_active_model()
	if active_model != null and active_model.has_method("sync_attack_timeline"):
		active_model.sync_attack_timeline(phase_snapshot)


func get_combat_projectile_release_snapshot(weapon_type: String) -> Dictionary:
	if _is_ruin:
		return {"ready": false, "reason": "defense_device_destroyed", "origin_source": "unavailable"}
	var active_model := _get_active_model()
	if active_model == null or not active_model.has_method("get_combat_projectile_release_snapshot"):
		return {"ready": false, "reason": "formal_device_model_origin_unavailable", "origin_source": "unavailable"}
	var snapshot: Dictionary = active_model.get_combat_projectile_release_snapshot(weapon_type)
	if bool(snapshot.get("ready", false)):
		snapshot["deployment_id"] = _deployment_id
		snapshot["device_id"] = _device_id
	return snapshot


func get_combat_projectile_target_snapshot() -> Dictionary:
	if _is_ruin or interaction_area == null or (interaction_area.collision_layer & PROJECTILE_COLLISION_LAYER) == 0:
		return {
			"ready": false,
			"reason": "defense_device_projectile_target_unavailable",
			"target_source": "unavailable"
		}
	var hit_shape := interaction_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if hit_shape == null or hit_shape.disabled or hit_shape.shape == null:
		return {
			"ready": false,
			"reason": "defense_device_projectile_target_shape_unavailable",
			"target_source": "unavailable"
		}
	return {
		"ready": true,
		"deployment_id": _deployment_id,
		"device_id": _device_id,
		"position": hit_shape.global_position,
		"target_source": "defense_device_hit_area_center",
		"target_node_path": str(hit_shape.get_path()),
		"collision_layer": interaction_area.collision_layer
	}


func get_debug_snapshot() -> Dictionary:
	var result := {
		"deployment_id": _deployment_id,
		"device_id": _device_id,
		"model_scene": _loaded_model_scene,
		"position": _vector3_to_dict(position),
		"rotation_y_degrees": rad_to_deg(rotation.y),
		"is_ruin": _is_ruin,
		"has_formal_model": false,
		"model": {}
	}
	result["overhead_ui"] = {
		"name_text": status_label.text if status_label != null else "",
		"health_bar": _world_health_bar.get_debug_snapshot() if _world_health_bar != null else {},
	}
	var active_model := _get_active_model()
	if active_model != null:
		result["has_formal_model"] = active_model.has_method("get_debug_snapshot")
		if active_model.has_method("get_debug_snapshot"):
			result["model"] = active_model.get_debug_snapshot()
	return result


func _refresh_world_health_bar() -> void:
	_ensure_world_health_bar()
	if _world_health_bar == null:
		return
	_world_health_bar.position.y = status_label.position.y + 0.34 if status_label != null else 1.79
	_world_health_bar.set_health(
		int(_latest_snapshot.get("hp", 0)),
		int(_latest_snapshot.get("max_hp", 1)),
		not _is_ruin and _is_world_health_wartime()
	)


func _ensure_world_health_bar() -> void:
	if _world_health_bar != null:
		return
	_world_health_bar = WORLD_HEALTH_BAR.new() as WorldHealthBar3D
	_world_health_bar.name = "WorldHealthBar"
	add_child(_world_health_bar)
	_world_health_bar.configure_size(1.35, 0.12)


func _is_world_health_wartime() -> bool:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	return combat_system != null and combat_system.has_method("get_active_enemy_count") and int(combat_system.get_active_enemy_count()) > 0


func debug_emit_clicked() -> bool:
	if _deployment_id.is_empty():
		return false
	_emit_clicked()
	return true


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
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("defense_device_clicked") and not _deployment_id.is_empty():
		event_bus.defense_device_clicked.emit(_deployment_id)
		get_viewport().set_input_as_handled()


func _rebuild_model(presentation: Dictionary) -> void:
	for child in model_mount.get_children():
		child.queue_free()
	_loaded_model_scene = str(presentation.get("model_scene", ""))
	if not _loaded_model_scene.is_empty() and ResourceLoader.exists(_loaded_model_scene):
		var resource := load(_loaded_model_scene)
		if resource is PackedScene:
			model_mount.add_child((resource as PackedScene).instantiate())
			return
	_build_placeholder(str(presentation.get("placeholder_kind", _device_id)), _read_color(presentation.get("placeholder_color", {})))


func _configure_active_model(snapshot: Dictionary) -> void:
	var active_model := _get_active_model()
	if active_model != null and active_model.has_method("configure_device"):
		active_model.configure_device(snapshot)


func _get_active_model() -> Node:
	if model_mount.get_child_count() <= 0:
		return null
	return model_mount.get_child(0)


func _build_placeholder(kind: String, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if kind == "arrow_tower" or _device_id.contains("arrow_tower"):
		_add_box("TowerBase", Vector3(1.35, 0.28, 1.35), Vector3(0.0, 0.14, 0.0), Vector3.ZERO, material)
		_add_box("TowerPost", Vector3(0.72, 2.0, 0.72), Vector3(0.0, 1.2, 0.0), Vector3.ZERO, material)
		_add_box("FiringPlatform", Vector3(1.55, 0.22, 1.55), Vector3(0.0, 2.25, 0.0), Vector3.ZERO, material)
		_add_box("Roof", Vector3(1.8, 0.18, 1.8), Vector3(0.0, 2.8, 0.0), Vector3.ZERO, material)
		_add_box("ArrowSlit", Vector3(0.18, 0.18, 1.25), Vector3(0.0, 2.5, 0.45), Vector3.ZERO, material)
		return
	_add_box("Base", Vector3(0.9, 0.24, 1.25), Vector3(0.0, 0.18, 0.0), Vector3.ZERO, material)
	_add_box("Stock", Vector3(0.18, 0.18, 1.7), Vector3(0.0, 0.58, 0.25), Vector3.ZERO, material)
	_add_box("Bow", Vector3(1.9, 0.14, 0.14), Vector3(0.0, 0.62, 0.92), Vector3.ZERO, material)
	_add_box("Stand", Vector3(0.18, 0.55, 0.18), Vector3(0.0, 0.38, -0.12), Vector3.ZERO, material)


func _add_box(node_name: String, size: Vector3, local_position: Vector3, local_rotation: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	mesh_instance.set_surface_override_material(0, material)
	model_mount.add_child(mesh_instance)


func _read_color(raw: Variant) -> Color:
	if not raw is Dictionary:
		return Color(0.38, 0.22, 0.10, 1.0)
	return Color(
		float(raw.get("r", 0.38)),
		float(raw.get("g", 0.22)),
		float(raw.get("b", 0.10)),
		float(raw.get("a", 1.0))
	)


func _dict_to_vector3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if not raw is Dictionary:
		return Vector3.ZERO
	return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))


func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}
