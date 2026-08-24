class_name BuildingAutoDoor
extends Node3D


const ACTOR_COLLISION_MASK := 2
const OPEN_ANGLE_DEGREES := 100.0
const OPEN_SPEED_DEGREES_PER_SECOND := 260.0
const CLOSE_HOLD_SECONDS := 0.7

@export var clear_width := 2.08
@export var clear_height := 2.35
@export var leaf_visual_height := -1.0
@export var leaf_color := Color("#4c3b35")
@export var frame_color := Color("#302a2d")
@export var metal_color := Color("#68717d")

var _sensor: Area3D
var _left_hinge: Node3D
var _right_hinge: Node3D
var _open_requested := false
var _open_fraction := 0.0
var _close_hold_remaining := 0.0


func _ready() -> void:
	set_meta("authority_role", "presentation_only")
	set_meta("blocking_collision", false)
	set_meta("actor_collision_mask", ACTOR_COLLISION_MASK)
	_build_door_visuals()
	_build_actor_sensor()
	set_physics_process(true)


func configure(
	configured_leaf_color: Color,
	configured_frame_color: Color,
	configured_metal_color: Color = Color("#68717d")
) -> void:
	leaf_color = configured_leaf_color
	frame_color = configured_frame_color
	metal_color = configured_metal_color


func debug_get_snapshot() -> Dictionary:
	var overlapping_actor_count := 0
	if _sensor != null and _sensor.monitoring:
		for body in _sensor.get_overlapping_bodies():
			if _is_actor_body(body):
				overlapping_actor_count += 1
	return {
		"clear_width": clear_width,
		"clear_height": clear_height,
		"leaf_visual_height": _resolved_leaf_visual_height(),
		"minimum_contract_width": 1.8,
		"minimum_contract_height": 2.2,
		"centerline_clear": true,
		"blocking_collision": false,
		"actor_collision_mask": ACTOR_COLLISION_MASK,
		"overlapping_actor_count": overlapping_actor_count,
		"open_requested": _open_requested,
		"open_fraction": _open_fraction,
		"left_leaf_yaw_degrees": rad_to_deg(_left_hinge.rotation.y) if _left_hinge != null else 0.0,
		"right_leaf_yaw_degrees": rad_to_deg(_right_hinge.rotation.y) if _right_hinge != null else 0.0,
		"close_hold_seconds": CLOSE_HOLD_SECONDS,
		"authority_role": "presentation_only"
	}


func _physics_process(delta: float) -> void:
	var actor_near := _has_actor_in_sensor()
	if actor_near:
		_open_requested = true
		_close_hold_remaining = CLOSE_HOLD_SECONDS
	elif _close_hold_remaining > 0.0:
		_close_hold_remaining = maxf(0.0, _close_hold_remaining - delta)
		_open_requested = true
	else:
		_open_requested = false
	var target_fraction := 1.0 if _open_requested else 0.0
	var fraction_speed := OPEN_SPEED_DEGREES_PER_SECOND / OPEN_ANGLE_DEGREES
	_open_fraction = move_toward(_open_fraction, target_fraction, fraction_speed * delta)
	_apply_leaf_rotation()


func _build_door_visuals() -> void:
	_left_hinge = Node3D.new()
	_left_hinge.name = "LeftHinge"
	_left_hinge.position = Vector3(-clear_width * 0.5, 0.0, 0.0)
	add_child(_left_hinge)
	_right_hinge = Node3D.new()
	_right_hinge.name = "RightHinge"
	_right_hinge.position = Vector3(clear_width * 0.5, 0.0, 0.0)
	add_child(_right_hinge)
	var leaf_width := clear_width * 0.5 - 0.025
	_build_leaf(_left_hinge, "LeftLeaf", leaf_width, leaf_width * 0.5)
	_build_leaf(_right_hinge, "RightLeaf", leaf_width, -leaf_width * 0.5)
	_apply_leaf_rotation()


func _build_leaf(hinge: Node3D, leaf_name: String, leaf_width: float, center_x: float) -> void:
	var visual_height := _resolved_leaf_visual_height()
	var leaf := Node3D.new()
	leaf.name = leaf_name
	hinge.add_child(leaf)
	_add_box(leaf, "DoorPanel", Vector3(center_x, visual_height * 0.5, 0.0), Vector3(leaf_width, visual_height, 0.13), leaf_color)
	var side_sign := 1.0 if center_x > 0.0 else -1.0
	for frame_x in [0.08, leaf_width - 0.08]:
		_add_box(
			leaf,
			"VerticalFrame",
			Vector3(side_sign * frame_x, visual_height * 0.5, 0.085),
			Vector3(0.13, visual_height - 0.12, 0.09),
			frame_color
		)
	for frame_y in [0.12, visual_height * 0.5, visual_height - 0.12]:
		_add_box(
			leaf,
			"HorizontalFrame",
			Vector3(center_x, frame_y, 0.085),
			Vector3(leaf_width - 0.08, 0.13, 0.09),
			frame_color
		)
	var brace := _add_box(
		leaf,
		"DiagonalBrace",
		Vector3(center_x, visual_height * 0.52, 0.095),
		Vector3(0.12, visual_height * 0.78, 0.08),
		frame_color
	)
	brace.rotation_degrees.z = -22.0 * side_sign
	_add_box(
		leaf,
		"RingHandle",
		Vector3(side_sign * 0.13, visual_height * 0.52, 0.17),
		Vector3(0.12, 0.18, 0.08),
		metal_color
	)


func _resolved_leaf_visual_height() -> float:
	return clear_height if leaf_visual_height <= 0.0 else minf(leaf_visual_height, clear_height)


func _build_actor_sensor() -> void:
	_sensor = Area3D.new()
	_sensor.name = "ActorApproachSensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = ACTOR_COLLISION_MASK
	_sensor.monitoring = true
	_sensor.monitorable = false
	_sensor.input_ray_pickable = false
	add_child(_sensor)
	var collision := CollisionShape3D.new()
	collision.name = "SensorShape"
	collision.position = Vector3(0.0, 1.2, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.8, 2.8, 5.4)
	collision.shape = shape
	_sensor.add_child(collision)


func _has_actor_in_sensor() -> bool:
	if _sensor == null or not _sensor.monitoring:
		return false
	for body in _sensor.get_overlapping_bodies():
		if _is_actor_body(body):
			return true
	return false


func _is_actor_body(body: Node) -> bool:
	return body is CharacterBody3D and ((body as CharacterBody3D).collision_layer & ACTOR_COLLISION_MASK) != 0


func _apply_leaf_rotation() -> void:
	if _left_hinge != null:
		_left_hinge.rotation.y = deg_to_rad(-OPEN_ANGLE_DEGREES * _open_fraction)
	if _right_hinge != null:
		_right_hinge.rotation.y = deg_to_rad(OPEN_ANGLE_DEGREES * _open_fraction)


func _add_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh.material = material
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	return mesh_instance
