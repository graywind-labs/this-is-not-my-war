extends Node3D

@onready var model_mount: Node3D = $ModelMount
@onready var status_label: Label3D = $StatusLabel

var _deployment_id := ""
var _device_id := ""
var _loaded_model_scene := ""


func configure_device(snapshot: Dictionary) -> void:
	_deployment_id = str(snapshot.get("deployment_id", ""))
	_device_id = str(snapshot.get("device_id", ""))
	set_meta("deployment_id", _deployment_id)
	set_meta("device_id", _device_id)
	set_meta("slot_id", str(snapshot.get("slot_id", "")))
	position = _dict_to_vector3(snapshot.get("position", {}))
	rotation.y = deg_to_rad(float(snapshot.get("rotation_y_degrees", 0.0)))
	var effect: Dictionary = snapshot.get("effect", {}) if snapshot.get("effect", {}) is Dictionary else {}
	status_label.text = "%s\nHP %d/%d · 射程 %.1f" % [
		str(snapshot.get("device_name", "工程器械")),
		int(snapshot.get("hp", 0)),
		int(snapshot.get("max_hp", 0)),
		float(effect.get("range", 0.0))
	]

	var presentation: Dictionary = snapshot.get("presentation", {}) if snapshot.get("presentation", {}) is Dictionary else {}
	var model_scene_path := str(presentation.get("model_scene", ""))
	if model_mount.get_child_count() == 0 or model_scene_path != _loaded_model_scene:
		_rebuild_model(presentation)


func play_device_action(action_result: Dictionary) -> void:
	status_label.text = "%s\n命中 %s · %d 伤害" % [
		str(action_result.get("device_name", "工程器械")),
		str(action_result.get("target_enemy_name", "敌人")),
		int(action_result.get("damage", 0))
	]


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
