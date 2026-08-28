class_name FormalGateArtView
extends Node3D


const ACTOR_COLLISION_MASK := 2
const WORLD_COLLISION_LAYER := 1
const OPEN_ANGLE_DEGREES := 92.0
const OPEN_SPEED_DEGREES_PER_SECOND := 105.0
const CLOSE_HOLD_SECONDS := 1.15
const ROCK_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_BaseColor.png"
const ROCK_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_Normal.png"
const ROCK_ORM := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_ORM.png"
const BRICK_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_UnevenBrick_BaseColor.png"
const BRICK_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_UnevenBrick_Normal.png"
const BRICK_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_UnevenBrick_Roughness.png"
const WOOD_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_BaseColor.png"
const WOOD_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Normal.png"
const WOOD_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Roughness.png"

var gate_id := "front_gate"
var display_name := "正门"
var clear_width := 6.0
var clear_height := 3.2
var is_front_gate := true
var _sensor: Area3D
var _left_hinge: AnimatableBody3D
var _right_hinge: AnimatableBody3D
var _level_two: Node3D
var _open_fraction := 0.0
var _close_hold_remaining := 0.0
var _destroyed := false
var _collapse_fraction := 0.0
var _recovery_hp_ratio := 0.01
var _material_cache: Dictionary = {}


func configure(config: Dictionary) -> void:
	gate_id = str(config.get("id", "front_gate"))
	display_name = str(config.get("display_name", "城门"))
	clear_width = float(config.get("clear_width", 5.0))
	clear_height = float(config.get("height", 2.8))
	is_front_gate = gate_id == "front_gate"


func _ready() -> void:
	set_meta("building_id", gate_id)
	set_meta("art_revision", "t0132_p3r_timber_stockade")
	set_meta("authority_role", "presentation_and_physical_door_only")
	set_meta("enemy_can_trigger", false)
	_build_gatehouse()
	_build_actor_sensor()
	_bind_building_state()
	call_deferred("_refresh_building_state")
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_collapse_fraction = move_toward(_collapse_fraction, 1.0 if _destroyed else 0.0, delta * 1.7)
	if _destroyed:
		_open_fraction = move_toward(
			_open_fraction,
			0.0,
			(OPEN_SPEED_DEGREES_PER_SECOND / OPEN_ANGLE_DEGREES) * delta
		)
		_apply_door_pose()
		return
	var friendly_near := _has_friendly_in_sensor()
	var combat_locked := is_front_gate and _has_active_enemies()
	var open_requested := friendly_near and not combat_locked
	if open_requested:
		_close_hold_remaining = CLOSE_HOLD_SECONDS
	elif _close_hold_remaining > 0.0:
		_close_hold_remaining = maxf(0.0, _close_hold_remaining - delta)
		open_requested = true
	var target := 1.0 if open_requested else 0.0
	_open_fraction = move_toward(
		_open_fraction,
		target,
		(OPEN_SPEED_DEGREES_PER_SECOND / OPEN_ANGLE_DEGREES) * delta
	)
	_apply_door_pose()


func debug_get_snapshot() -> Dictionary:
	return {
		"gate_id": gate_id,
		"display_name": display_name,
		"is_front_gate": is_front_gate,
		"clear_width": clear_width,
		"clear_height": clear_height,
		"gatehouse_height": 5.65 if is_front_gate else 4.15,
		"gatehouse_outer_half_width": 5.45 if is_front_gate else 4.22,
		"architectural_material": "timber_gatehouse_with_low_stone_footings",
		"stone_role": "foundation_only",
		"door_leaf_count": 2,
		"open_fraction": _open_fraction,
		"friendly_near": _has_friendly_in_sensor(),
		"enemy_can_trigger": false,
		"combat_locked": is_front_gate and _has_active_enemies(),
		"destroyed": _destroyed,
		"collapse_fraction": _collapse_fraction,
		"recovery_hp_ratio": _recovery_hp_ratio,
		"level_two_visible": _level_two != null and _level_two.visible,
		"blocking_collision": not _destroyed,
		"authority_role": "presentation_and_physical_door_only"
	}


func debug_set_open_fraction(value: float) -> Dictionary:
	_open_fraction = clampf(value, 0.0, 1.0)
	_close_hold_remaining = 0.0
	_apply_door_pose()
	return debug_get_snapshot()


func _build_gatehouse() -> void:
	var tower_width := 2.35 if is_front_gate else 1.72
	var tower_depth := 3.55 if is_front_gate else 2.55
	var tower_height := 5.05 if is_front_gate else 3.62
	var outer_x := clear_width * 0.5 + tower_width * 0.5
	var stone_tint := Color("#74756f") if is_front_gate else Color("#6d6e68")
	var timber_tint := Color("#684a36") if is_front_gate else Color("#604632")
	var dark_wood := Color("#443027")
	var iron := Color("#34383c")

	var structure := Node3D.new()
	structure.name = "GatehouseStructure"
	add_child(structure)
	for side in [-1.0, 1.0]:
		var crown_x := outer_x
		var foundation_pad := _add_textured_box(
			structure, "LowStoneFoundationPad", Vector3(side * outer_x, 0.13, 0.0),
			Vector3(tower_width + 0.24, 0.26, tower_depth + 0.24), "rock", stone_tint, 0.68
		)
		foundation_pad.set_meta("gate_structure_role", "low_stone_foundation_pad")
		if is_front_gate:
			_add_textured_box(
				structure, "TimberGatePier", Vector3(side * outer_x, 1.66, 0.0),
				Vector3(tower_width, 2.98, tower_depth), "wood", timber_tint, 0.86
			)
			crown_x += side * 0.42
			_add_textured_box(
				structure, "UpperTimberGuardTower", Vector3(side * crown_x, 4.08, 0.0),
				Vector3(tower_width * 0.72, 1.94, tower_depth), "wood", timber_tint.lightened(0.04), 0.88
			)
		else:
			_add_textured_box(
				structure, "TimberSideTower", Vector3(side * outer_x, tower_height * 0.5 + 0.13, 0.0),
				Vector3(tower_width, tower_height - 0.26, tower_depth), "wood", timber_tint, 0.88
			)
		_build_tower_timber_frame(structure, side * crown_x, tower_height, tower_width * (0.72 if is_front_gate else 1.0), tower_depth, dark_wood)
		_build_battlements(structure, side * crown_x, tower_height + 0.30, tower_width * (0.72 if is_front_gate else 1.0), tower_depth, timber_tint.darkened(0.05))
	var lintel_y := clear_height - 0.03 if is_front_gate else clear_height + 0.46
	var lintel_height := 0.32 if is_front_gate else 0.56
	_add_textured_box(
		structure, "TimberGateLintel", Vector3(0.0, lintel_y, 0.0),
		Vector3(clear_width + tower_width * 0.56, lintel_height, tower_depth * 0.72),
		"wood", timber_tint.darkened(0.08), 0.92
	)
	_add_textured_box(
		structure, "LintelTimber", Vector3(0.0, clear_height - 0.24 if is_front_gate else clear_height + 0.13, tower_depth * 0.38),
		Vector3(clear_width + 0.30, 0.24, 0.24), "wood", dark_wood, 0.75
	)
	for side in [-1.0, 1.0]:
		_add_box(structure, "IronTowerTie", Vector3(side * (clear_width * 0.5 + 0.10), clear_height * 0.72, tower_depth * 0.52), Vector3(0.14, clear_height * 0.76, 0.10), iron)
	if is_front_gate:
		_build_front_gate_identity(structure, tower_height, tower_depth)
	else:
		_build_rear_gate_identity(structure, tower_height, tower_depth)
	_build_door_leaves(dark_wood, iron, tower_depth)

	_level_two = Node3D.new()
	_level_two.name = "Level2Reinforcement"
	add_child(_level_two)
	for side in [-1.0, 1.0]:
		_add_box(_level_two, "IronCornerBand", Vector3(side * outer_x, tower_height * 0.46, tower_depth * 0.535), Vector3(tower_width * 0.72, 0.16, 0.12), iron)
		_add_box(_level_two, "IronCrownBand", Vector3(side * outer_x, tower_height - 0.24, tower_depth * 0.535), Vector3(tower_width * 0.88, 0.17, 0.12), iron)


func _build_front_gate_identity(parent: Node3D, tower_height: float, tower_depth: float) -> void:
	var banner_red := Color("#73363b")
	var old_gold := Color("#b48b45")
	_add_box(parent, "FrontGateBanner", Vector3(0.0, tower_height - 0.48, tower_depth * 0.38), Vector3(1.12, 1.16, 0.07), banner_red)
	_add_box(parent, "BannerVerticalMark", Vector3(0.0, tower_height - 0.48, tower_depth * 0.425), Vector3(0.13, 0.76, 0.04), old_gold)
	_add_box(parent, "BannerHorizontalMark", Vector3(0.0, tower_height - 0.48, tower_depth * 0.425), Vector3(0.70, 0.13, 0.04), old_gold)
	for side in [-1.0, 1.0]:
		_add_cylinder(parent, "TorchBracket", Vector3(side * (clear_width * 0.5 + 0.52), 2.72, tower_depth * 0.56), 0.055, 0.62, Color("#3b3d40"), Vector3(90.0, 0.0, 0.0))


func _build_rear_gate_identity(parent: Node3D, tower_height: float, tower_depth: float) -> void:
	var beam := _add_textured_box(parent, "MerchantSignBeam", Vector3(0.0, tower_height - 0.38, tower_depth * 0.48), Vector3(1.56, 0.18, 0.18), "wood", Color("#4a352b"), 0.75)
	beam.rotation_degrees.z = -2.0
	_add_box(parent, "MerchantRoutePlaque", Vector3(0.0, tower_height - 0.72, tower_depth * 0.55), Vector3(0.72, 0.46, 0.08), Color("#70533b"))


func _build_battlements(parent: Node3D, center_x: float, y: float, width: float, depth: float, color: Color) -> void:
	for local_x in [-0.38, 0.38]:
		for z_sign in [-1.0, 1.0]:
			_add_textured_box(parent, "TimberTowerMerlon", Vector3(center_x + local_x * width, y, z_sign * depth * 0.40), Vector3(width * 0.30, 0.62, depth * 0.22), "wood", color, 0.94)


func _build_tower_timber_frame(parent: Node3D, center_x: float, tower_height: float, width: float, depth: float, color: Color) -> void:
	for face_z in [-depth * 0.515, depth * 0.515]:
		for local_x in [-width * 0.40, width * 0.40]:
			_add_textured_box(parent, "TowerCornerPost", Vector3(center_x + local_x, tower_height * 0.50, face_z), Vector3(0.20, tower_height - 0.30, 0.18), "wood", color, 1.0)
		for rail_y in [0.82, tower_height * 0.52, tower_height - 0.40]:
			_add_textured_box(parent, "TowerBindingBeam", Vector3(center_x, rail_y, face_z), Vector3(width * 0.90, 0.18, 0.18), "wood", color, 1.0)
		for direction in [-1.0, 1.0]:
			var brace := _add_textured_box(parent, "TowerCrossBrace", Vector3(center_x, tower_height * 0.50, face_z + 0.012), Vector3(0.16, tower_height * 0.56, 0.16), "wood", color, 1.0)
			brace.rotation_degrees.z = direction * 22.0
			brace.set_meta("gate_structure_role", "timber_cross_brace")


func _build_door_leaves(wood: Color, iron: Color, tower_depth: float) -> void:
	var leaf_width := clear_width * 0.5 - 0.035
	var leaf_height := clear_height - (0.22 if is_front_gate else 0.08)
	_left_hinge = _make_hinge("LeftDoorHinge", Vector3(-clear_width * 0.5, 0.0, tower_depth * 0.12))
	_right_hinge = _make_hinge("RightDoorHinge", Vector3(clear_width * 0.5, 0.0, tower_depth * 0.12))
	_build_door_leaf(_left_hinge, "LeftDoorLeaf", leaf_width, leaf_height, leaf_width * 0.5, wood, iron)
	_build_door_leaf(_right_hinge, "RightDoorLeaf", leaf_width, leaf_height, -leaf_width * 0.5, wood, iron)
	_apply_door_pose()


func _make_hinge(node_name: String, local_position: Vector3) -> AnimatableBody3D:
	var hinge := AnimatableBody3D.new()
	hinge.name = node_name
	hinge.position = local_position
	hinge.collision_layer = WORLD_COLLISION_LAYER
	hinge.collision_mask = ACTOR_COLLISION_MASK
	hinge.sync_to_physics = true
	hinge.set_meta("building_id", gate_id)
	hinge.set_meta("gate_door_leaf", true)
	add_child(hinge)
	return hinge


func _build_door_leaf(parent: AnimatableBody3D, node_name: String, width: float, height: float, center_x: float, wood: Color, iron: Color) -> void:
	var leaf := Node3D.new()
	leaf.name = node_name
	parent.add_child(leaf)
	_add_textured_box(leaf, "TimberPanel", Vector3(center_x, height * 0.5, 0.0), Vector3(width, height, 0.20), "wood", wood, 0.72)
	var side_sign := 1.0 if center_x > 0.0 else -1.0
	for offset in [0.12, width - 0.12]:
		_add_box(leaf, "VerticalIron", Vector3(side_sign * offset, height * 0.5, 0.14), Vector3(0.13, height - 0.10, 0.08), iron)
	for y in [0.16, height * 0.48, height - 0.16]:
		_add_box(leaf, "HorizontalIron", Vector3(center_x, y, 0.14), Vector3(width - 0.10, 0.13, 0.08), iron)
	var brace := _add_box(leaf, "DiagonalIron", Vector3(center_x, height * 0.52, 0.15), Vector3(0.13, height * 0.80, 0.07), iron)
	brace.rotation_degrees.z = -24.0 * side_sign
	var shape := CollisionShape3D.new()
	shape.name = "DoorLeafCollision"
	shape.position = Vector3(center_x, height * 0.5, 0.0)
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 0.24)
	shape.shape = box
	parent.add_child(shape)


func _build_actor_sensor() -> void:
	_sensor = Area3D.new()
	_sensor.name = "FriendlyApproachSensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = ACTOR_COLLISION_MASK
	_sensor.monitoring = true
	_sensor.monitorable = false
	_sensor.input_ray_pickable = false
	add_child(_sensor)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "SensorShape"
	shape_node.position = Vector3(0.0, 1.35, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(clear_width + 3.4, 3.0, 8.2 if is_front_gate else 7.0)
	shape_node.shape = shape
	_sensor.add_child(shape_node)


func _has_friendly_in_sensor() -> bool:
	if _sensor == null or not _sensor.monitoring:
		return false
	for body in _sensor.get_overlapping_bodies():
		if _is_friendly_body(body):
			return true
	return false


func _is_friendly_body(body: Node) -> bool:
	if not body is CharacterBody3D:
		return false
	if body.has_meta("enemy_id"):
		return false
	return body.has_meta("npc_id") or body is MerchantWagon


func _has_active_enemies() -> bool:
	var combat_system := get_node_or_null("/root/Main/Systems/CombatSystem")
	return combat_system != null and combat_system.has_method("get_active_enemy_count") and int(combat_system.call("get_active_enemy_count")) > 0


func _bind_building_state() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("building_state_changed"):
		if not event_bus.building_state_changed.is_connected(_on_building_state_changed):
			event_bus.building_state_changed.connect(_on_building_state_changed)


func _on_building_state_changed(changed_id: String) -> void:
	if changed_id == gate_id:
		_refresh_building_state()


func _refresh_building_state() -> void:
	var building_system := get_node_or_null("/root/Main/Systems/BuildingSystem")
	if building_system == null or not building_system.has_method("get_building"):
		return
	var building: Dictionary = building_system.call("get_building", gate_id)
	if building.is_empty():
		return
	var destruction: Dictionary = building.get("destruction", {}) if building.get("destruction", {}) is Dictionary else {}
	_recovery_hp_ratio = clampf(float(destruction.get("recovery_hp_ratio", 0.01)), 0.0, 1.0)
	_destroyed = bool(building.get("destruction_latched", int(building.get("hp", 1)) <= 0))
	if _level_two != null:
		_level_two.visible = int(building.get("level", 1)) >= 2
	_set_leaf_collisions_enabled(not _destroyed)


func _set_leaf_collisions_enabled(enabled: bool) -> void:
	for hinge in [_left_hinge, _right_hinge]:
		if hinge == null:
			continue
		for raw_shape in hinge.find_children("*", "CollisionShape3D", true, false):
			(raw_shape as CollisionShape3D).set_deferred("disabled", not enabled)


func _apply_door_pose() -> void:
	if _left_hinge != null:
		_left_hinge.rotation = Vector3(
			deg_to_rad(86.0 * _collapse_fraction),
			deg_to_rad(-OPEN_ANGLE_DEGREES * _open_fraction * (1.0 - _collapse_fraction)),
			deg_to_rad(-5.0 * _collapse_fraction)
		)
	if _right_hinge != null:
		_right_hinge.rotation = Vector3(
			deg_to_rad(82.0 * _collapse_fraction),
			deg_to_rad(OPEN_ANGLE_DEGREES * _open_fraction * (1.0 - _collapse_fraction)),
			deg_to_rad(7.0 * _collapse_fraction)
		)


func _add_textured_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, texture_kind: String, tint: Color, density: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _textured_material(texture_kind, tint, density)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, center: Vector3, radius: float, height: float, color: Color, rotation_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.rotation_degrees = rotation_degrees
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var key := "flat:%s" % color.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	_material_cache[key] = material
	return material


func _textured_material(kind: String, tint: Color, density: float) -> StandardMaterial3D:
	var key := "textured:%s:%s:%.2f" % [kind, tint.to_html(true), density]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * density
	var base_path := ROCK_BASE_COLOR
	var normal_path := ROCK_NORMAL
	var roughness_path := ""
	if kind == "brick":
		base_path = BRICK_BASE_COLOR
		normal_path = BRICK_NORMAL
		roughness_path = BRICK_ROUGHNESS
	elif kind == "wood":
		base_path = WOOD_BASE_COLOR
		normal_path = WOOD_NORMAL
		roughness_path = WOOD_ROUGHNESS
	if ResourceLoader.exists(base_path):
		material.albedo_texture = load(base_path) as Texture2D
	if ResourceLoader.exists(normal_path):
		material.normal_enabled = true
		material.normal_scale = 0.62
		material.normal_texture = load(normal_path) as Texture2D
	if kind == "rock" and ResourceLoader.exists(ROCK_ORM):
		material.orm_texture = load(ROCK_ORM) as Texture2D
	elif not roughness_path.is_empty() and ResourceLoader.exists(roughness_path):
		material.roughness_texture = load(roughness_path) as Texture2D
	_material_cache[key] = material
	return material
