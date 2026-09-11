extends Node3D

const ART_REVISION := "t0132_p4b"
const FOOTPRINT_SIZE := Vector3(3.12, 3.48, 3.18)
const BOW_PLANE_Z := 0.26
const STRING_REST_Z := 0.20
const STRING_DRAW_Z := -0.24
const MUZZLE_LOCAL_Z := 1.18
const WOOD_BASE := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_BaseColor.png"
const WOOD_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Normal.png"
const WOOD_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Roughness.png"
const METAL_BASE := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_MetalOrnaments_BaseColor.png"
const METAL_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_MetalOrnaments_Roughness.png"
const ROOF_BASE := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RoundTiles_BaseColor.png"
const ROOF_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RoundTiles_Normal.png"
const ROOF_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RoundTiles_Roughness.png"

var _wood_material: StandardMaterial3D
var _wood_dark_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _roof_material: StandardMaterial3D
var _rope_material: StandardMaterial3D
var _arrow_material: StandardMaterial3D
var _fletching_material: StandardMaterial3D
var _yaw_pivot: Node3D
var _firing_slide: Node3D
var _loaded_arrow: Node3D
var _muzzle: Marker3D
var _string_left: MeshInstance3D
var _string_right: MeshInstance3D
var _reload_wheel: Node3D
var _string_draw_z := STRING_DRAW_Z
var _attack_interval := 1.39
var _projectile_speed := 64.0
var _reload_fraction := 0.58
var _reload_tween: Tween
var _recoil_tween: Tween
var _wheel_tween: Tween
var _shot_count := 0
var _last_target := Vector3.ZERO
var _last_flight_seconds := 0.0
var _last_reload_seconds := 0.0
var _active_projectiles: Array[Node3D] = []
var _static_structure_part_count := 0
var _last_authoritative_release_sequence := -1
var _timeline_phase := "idle"
var _destroyed_visual := false


func _ready() -> void:
	_build_materials()
	_build_arrow_tower()
	_static_structure_part_count = find_children("*", "MeshInstance3D", true, false).size()
	set_meta("art_revision", ART_REVISION)
	set_meta("formal_device_kind", "arrow_tower")
	set_meta("footprint_size", FOOTPRINT_SIZE)
	set_meta("uses_quaternius_pbr", true)


func configure_device(snapshot: Dictionary) -> void:
	var effect: Dictionary = snapshot.get("effect", {}) if snapshot.get("effect", {}) is Dictionary else {}
	var presentation: Dictionary = snapshot.get("presentation", {}) if snapshot.get("presentation", {}) is Dictionary else {}
	_attack_interval = maxf(0.1, float(effect.get("attack_interval", _attack_interval)))
	var projectile: Dictionary = effect.get("projectile", {}) if effect.get("projectile", {}) is Dictionary else {}
	_projectile_speed = maxf(1.0, float(projectile.get("speed", presentation.get("projectile_speed", _projectile_speed))))
	_reload_fraction = clampf(float(presentation.get("reload_fraction", _reload_fraction)), 0.25, 0.85)


func set_destroyed_visual(destroyed: bool) -> void:
	if not destroyed or _destroyed_visual:
		return
	_destroyed_visual = true
	_timeline_phase = "destroyed"
	_kill_active_tweens()
	if is_instance_valid(_loaded_arrow):
		_loaded_arrow.visible = false
	if is_instance_valid(_string_left):
		_string_left.visible = false
	if is_instance_valid(_string_right):
		_string_right.visible = false
	var tower := get_node_or_null("TexturedTimberTower") as Node3D
	if tower != null:
		var posts := tower.find_children("TowerPost", "MeshInstance3D", true, false)
		for index in posts.size():
			var post := posts[index] as MeshInstance3D
			post.position.y = 0.34 + 0.05 * float(index % 2)
			post.rotation_degrees = Vector3(4.0 * float(index % 2), -18.0 + 11.0 * float(index), 70.0 if index % 2 == 0 else -66.0)
		for raw_part in tower.find_children("CanopyPost", "MeshInstance3D", true, false):
			var canopy_post := raw_part as MeshInstance3D
			canopy_post.position.y = 0.40
			canopy_post.rotation_degrees.z = 76.0 if canopy_post.position.x < 0.0 else -72.0
		_set_ruin_part_pose(tower, "LookoutFloorFrame", Vector3(-0.16, 0.38, 0.10), Vector3(8.0, -7.0, 13.0))
		_set_ruin_part_pose(tower, "LookoutDeck", Vector3(0.10, 0.50, -0.18), Vector3(-5.0, 11.0, -10.0))
		_set_ruin_part_pose(tower, "LeftRoofSlope", Vector3(-0.58, 0.55, -0.12), Vector3(11.0, -18.0, 63.0))
		_set_ruin_part_pose(tower, "RightRoofSlope", Vector3(0.66, 0.43, 0.20), Vector3(-7.0, 22.0, -58.0))
		_set_ruin_part_pose(tower, "RoofRidge", Vector3(0.10, 0.22, -0.62), Vector3(83.0, 12.0, 8.0))
		for pattern in ["RearMantlet", "SideMantlet", "FrontShield"]:
			for raw_part in tower.find_children(pattern, "MeshInstance3D", true, false):
				var part := raw_part as MeshInstance3D
				part.position.y = 0.28 + 0.08 * float(part.get_index() % 3)
				part.rotation_degrees = Vector3(5.0, float(part.get_index() * 13), 72.0 if part.get_index() % 2 == 0 else -68.0)
	if is_instance_valid(_yaw_pivot):
		_yaw_pivot.position = Vector3(0.42, 0.28, 0.18)
		_yaw_pivot.rotation_degrees = Vector3(64.0, -22.0, 18.0)
	_build_ruin_debris()
	set_meta("destroyed_visual", true)


func _set_ruin_part_pose(parent: Node, part_name: String, target_position: Vector3, target_rotation_degrees: Vector3) -> void:
	var part := parent.find_child(part_name, true, false) as Node3D
	if part == null:
		return
	part.position = target_position
	part.rotation_degrees = target_rotation_degrees


func _build_ruin_debris() -> void:
	if get_node_or_null("RuinDebris") != null:
		return
	var debris := Node3D.new()
	debris.name = "RuinDebris"
	add_child(debris)
	_add_box(debris, "BrokenDeckPlankA", Vector3(1.55, 0.16, 0.34), Vector3(-0.58, 0.12, 0.86), Vector3(0.10, 0.34, -0.08), _wood_material)
	_add_box(debris, "BrokenDeckPlankB", Vector3(1.34, 0.15, 0.30), Vector3(0.68, 0.10, -0.74), Vector3(-0.08, -0.44, 0.12), _wood_dark_material)
	_add_box(debris, "SnappedSupportA", Vector3(0.20, 0.22, 1.42), Vector3(-0.92, 0.13, -0.18), Vector3(0.06, 0.82, 0.20), _wood_dark_material)
	_add_box(debris, "SnappedSupportB", Vector3(0.20, 0.22, 1.18), Vector3(0.96, 0.12, 0.44), Vector3(-0.08, -0.72, -0.16), _wood_dark_material)


func get_combat_projectile_release_snapshot(weapon_type: String) -> Dictionary:
	if weapon_type != "bow":
		return {"ready": false, "reason": "arrow_tower_weapon_type_mismatch", "origin_source": "unavailable"}
	if not is_instance_valid(_muzzle) or not is_instance_valid(_loaded_arrow) or not _loaded_arrow.visible:
		return {"ready": false, "reason": "arrow_tower_loaded_arrow_unavailable", "origin_source": "unavailable"}
	return {
		"ready": true,
		"transform": _muzzle.global_transform,
		"origin_source": "formal_arrow_tower_muzzle",
		"projectile_node_path": str(_loaded_arrow.get_path()),
		"muzzle_node_path": str(_muzzle.get_path()),
		"mounted": false
	}


func sync_attack_timeline(timeline: Dictionary) -> void:
	var target := _dict_to_vector3(timeline.get("target_position", {}))
	if not target.is_equal_approx(Vector3.ZERO):
		_aim_at(target)
	var phase := str(timeline.get("phase", "idle"))
	_timeline_phase = phase
	var interval := maxf(0.1, float(timeline.get("attack_interval", _attack_interval)))
	var release_seconds := clampf(float(timeline.get("release_seconds", interval * 0.25)), 0.0, interval)
	var elapsed := clampf(float(timeline.get("attack_elapsed", 0.0)), 0.0, interval)
	if phase == "release":
		var sequence := int(timeline.get("attack_sequence", -1))
		if sequence != _last_authoritative_release_sequence:
			_last_authoritative_release_sequence = sequence
			_shot_count += 1
			_last_target = target
			_loaded_arrow.visible = false
			_set_string_draw_z(STRING_REST_Z)
		return
	if phase == "recovery":
		var progress := clampf((elapsed - release_seconds) / maxf(0.001, interval - release_seconds), 0.0, 1.0)
		_set_string_draw_z(lerpf(STRING_REST_Z, STRING_DRAW_Z, progress))
		_loaded_arrow.visible = progress >= 0.98
		_firing_slide.position.z = -0.10 * pow(1.0 - progress, 4.0)
		_reload_wheel.rotation.x = TAU * 1.5 * progress
		_last_reload_seconds = interval - release_seconds
		return
	_firing_slide.position.z = 0.0
	_set_string_draw_z(STRING_DRAW_Z)
	_loaded_arrow.visible = true


func play_device_action(action_result: Dictionary) -> void:
	var target := _dict_to_vector3(action_result.get("target_position", {}))
	if target.is_equal_approx(Vector3.ZERO):
		target = global_position + global_basis.z * 16.0 + Vector3.UP * 0.85
	var interval := maxf(0.1, float(action_result.get("attack_interval", _attack_interval)))
	_aim_at(target)
	_fire_loaded_arrow(target, interval)


func debug_play_attack(target_global_position: Vector3, attack_interval: float = 1.39) -> void:
	play_device_action({
		"target_position": _vector3_to_dict(target_global_position),
		"attack_interval": attack_interval
	})


func get_debug_snapshot() -> Dictionary:
	_cleanup_projectiles()
	return {
		"art_revision": ART_REVISION,
		"formal_device_kind": "arrow_tower",
		"footprint_size": _vector3_to_dict(FOOTPRINT_SIZE),
		"loaded_arrow_visible": is_instance_valid(_loaded_arrow) and _loaded_arrow.visible,
		"string_draw_z": _string_draw_z,
		"attack_interval": _attack_interval,
		"projectile_speed": _projectile_speed,
		"reload_fraction": _reload_fraction,
		"shot_count": _shot_count,
		"active_projectile_count": _active_projectiles.size(),
		"last_target_position": _vector3_to_dict(_last_target),
		"last_flight_seconds": _last_flight_seconds,
		"last_reload_seconds": _last_reload_seconds,
		"timeline_phase": _timeline_phase,
		"destroyed_visual": _destroyed_visual,
		"last_authoritative_release_sequence": _last_authoritative_release_sequence,
		"yaw_degrees": rad_to_deg(_yaw_pivot.rotation.y) if is_instance_valid(_yaw_pivot) else 0.0,
		"wood_texture": WOOD_BASE,
		"metal_texture": METAL_BASE,
		"roof_texture": ROOF_BASE,
		"structure_parts": _static_structure_part_count,
		"has_timber_tower": true,
		"has_tiled_canopy": true,
		"roof_profile": "closed_convex_gable",
		"ridge_supported_by_slopes": true,
		"has_arrow_racks": true,
		"has_dynamic_string": true,
		"has_fake_operator": false,
		"authority_role": "presentation_only"
	}


func _build_materials() -> void:
	_wood_material = _make_pbr_material(WOOD_BASE, WOOD_ROUGHNESS, WOOD_NORMAL, Color("#6c513e"), Vector3(2.0, 2.0, 2.0))
	_wood_dark_material = _make_pbr_material(WOOD_BASE, WOOD_ROUGHNESS, WOOD_NORMAL, Color("#49352b"), Vector3(2.4, 2.4, 2.4))
	_metal_material = _make_pbr_material(METAL_BASE, METAL_ROUGHNESS, "", Color("#505254"), Vector3(2.6, 2.6, 2.6))
	_roof_material = _make_pbr_material(ROOF_BASE, ROOF_ROUGHNESS, ROOF_NORMAL, Color("#6d7479"), Vector3(2.2, 2.2, 2.2))
	_rope_material = _make_flat_material(Color("#26170e"), 0.96)
	_arrow_material = _make_flat_material(Color("#60432a"), 0.88)
	_fletching_material = _make_flat_material(Color("#8a3030"), 0.82)


func _build_arrow_tower() -> void:
	var tower := Node3D.new()
	tower.name = "TexturedTimberTower"
	add_child(tower)
	_add_box(tower, "LowerFooting", Vector3(2.82, 0.22, 2.72), Vector3(0.0, 0.11, 0.0), Vector3.ZERO, _wood_dark_material)
	_add_box(tower, "LowerDeck", Vector3(2.62, 0.16, 2.52), Vector3(0.0, 0.27, 0.0), Vector3.ZERO, _wood_material)
	for x in [-1.05, 1.05]:
		for z in [-0.95, 0.95]:
			_add_box(tower, "TowerPost", Vector3(0.24, 1.26, 0.24), Vector3(x, 0.86, z), Vector3.ZERO, _wood_dark_material)
			_add_box(tower, "IronFoot", Vector3(0.31, 0.14, 0.31), Vector3(x, 0.18, z), Vector3.ZERO, _metal_material)
	for x in [-1.05, 1.05]:
		_add_beam(tower, "FrontCrossBrace", Vector3(x, 0.32, 0.97), Vector3(-x, 1.34, 0.97), 0.055, _wood_material)
		_add_beam(tower, "RearCrossBrace", Vector3(x, 0.32, -0.97), Vector3(-x, 1.34, -0.97), 0.055, _wood_material)
	_add_box(tower, "LookoutFloorFrame", Vector3(2.92, 0.30, 2.82), Vector3(0.0, 1.43, 0.0), Vector3.ZERO, _wood_dark_material)
	_add_box(tower, "LookoutDeck", Vector3(2.72, 0.12, 2.62), Vector3(0.0, 1.62, 0.0), Vector3.ZERO, _wood_material)

	# Waist-high mantlets leave the mechanism and its loaded arrow visible from
	# the game camera while keeping a clear forward firing opening.
	_add_box(tower, "RearMantlet", Vector3(2.72, 0.56, 0.20), Vector3(0.0, 1.95, -1.20), Vector3.ZERO, _wood_dark_material)
	for x in [-1.25, 1.25]:
		_add_box(tower, "SideMantlet", Vector3(0.20, 0.56, 2.52), Vector3(x, 1.95, 0.0), Vector3.ZERO, _wood_dark_material)
	for x in [-0.92, 0.92]:
		_add_box(tower, "FrontShield", Vector3(0.62, 0.58, 0.20), Vector3(x, 1.96, 1.20), Vector3.ZERO, _wood_dark_material)
	for x in [-1.24, 1.24]:
		for z in [-1.18, 1.18]:
			_add_box(tower, "CanopyPost", Vector3(0.16, 1.28, 0.16), Vector3(x, 2.48, z), Vector3.ZERO, _wood_dark_material)
	# Left and right signs must make the inner edges rise toward x=0. Reversing
	# these signs creates a butterfly roof and leaves the ridge floating.
	_add_box(tower, "LeftRoofSlope", Vector3(1.76, 0.12, 3.06), Vector3(-0.72, 3.03, 0.0), Vector3(0.0, 0.0, 0.42), _roof_material)
	_add_box(tower, "RightRoofSlope", Vector3(1.76, 0.12, 3.06), Vector3(0.72, 3.03, 0.0), Vector3(0.0, 0.0, -0.42), _roof_material)
	_add_cylinder(tower, "RoofRidge", 0.10, 3.10, Vector3(0.0, 3.38, 0.0), Vector3(PI * 0.5, 0.0, 0.0), _wood_dark_material, 10)
	_build_arrow_rack(tower, -1.08)
	_build_arrow_rack(tower, 1.08)

	_yaw_pivot = Node3D.new()
	_yaw_pivot.name = "AimingYawPivot"
	_yaw_pivot.position.y = 1.70
	add_child(_yaw_pivot)
	_add_cylinder(_yaw_pivot, "IronTurntable", 0.48, 0.14, Vector3(0.0, 0.06, -0.02), Vector3.ZERO, _metal_material, 14)
	_firing_slide = Node3D.new()
	_firing_slide.name = "RepeatingArrowCradle"
	_yaw_pivot.add_child(_firing_slide)
	_add_box(_firing_slide, "ArrowRail", Vector3(0.20, 0.14, 1.76), Vector3(0.0, 0.38, 0.18), Vector3.ZERO, _wood_material)
	_add_box(_firing_slide, "IronArrowGroove", Vector3(0.08, 0.04, 1.62), Vector3(0.0, 0.47, 0.26), Vector3.ZERO, _metal_material)
	_add_box(_firing_slide, "LeftMechanismCheek", Vector3(0.16, 0.34, 0.58), Vector3(-0.22, 0.34, -0.46), Vector3.ZERO, _wood_dark_material)
	_add_box(_firing_slide, "RightMechanismCheek", Vector3(0.16, 0.34, 0.58), Vector3(0.22, 0.34, -0.46), Vector3.ZERO, _wood_dark_material)
	_build_bow_arm(-1.0)
	_build_bow_arm(1.0)
	_build_dynamic_string()
	_build_reload_wheel()
	_loaded_arrow = _build_arrow("LoadedArrow", true)
	_firing_slide.add_child(_loaded_arrow)
	_loaded_arrow.position = Vector3(0.0, 0.53, 0.38)
	_muzzle = Marker3D.new()
	_muzzle.name = "ArrowMuzzle"
	_muzzle.position = Vector3(0.0, 0.53, MUZZLE_LOCAL_Z)
	_firing_slide.add_child(_muzzle)


func _build_arrow_rack(parent: Node3D, x: float) -> void:
	var rack := Node3D.new()
	rack.name = "LeftArrowRack" if x < 0.0 else "RightArrowRack"
	rack.position = Vector3(x, 1.86, -0.70)
	parent.add_child(rack)
	_add_box(rack, "RackBar", Vector3(0.12, 0.48, 0.62), Vector3.ZERO, Vector3.ZERO, _wood_dark_material)
	for index in 3:
		var arrow := _build_arrow("ReserveArrow%02d" % (index + 1), true)
		rack.add_child(arrow)
		arrow.scale = Vector3.ONE * 0.58
		arrow.position = Vector3(0.0, -0.12 + index * 0.13, -0.10 + index * 0.12)
		arrow.rotation_degrees = Vector3(-12.0, 0.0, 0.0)


func _build_bow_arm(side: float) -> void:
	var prefix := "Left" if side < 0.0 else "Right"
	var root := Vector3(side * 0.18, 0.37, BOW_PLANE_Z)
	var middle := Vector3(side * 0.66, 0.52, BOW_PLANE_Z + 0.05)
	var tip := Vector3(side * 1.08, 0.58, BOW_PLANE_Z - 0.05)
	_add_beam(_firing_slide, prefix + "InnerBowArm", root, middle, 0.065, _wood_material)
	_add_beam(_firing_slide, prefix + "OuterBowArm", middle, tip, 0.052, _wood_material)
	_add_cylinder(_firing_slide, prefix + "BowTipIron", 0.07, 0.12, tip, Vector3(0.0, 0.0, PI * 0.5), _metal_material, 8)


func _build_dynamic_string() -> void:
	_string_left = MeshInstance3D.new()
	_string_left.name = "LeftDynamicBowString"
	_firing_slide.add_child(_string_left)
	_string_right = MeshInstance3D.new()
	_string_right.name = "RightDynamicBowString"
	_firing_slide.add_child(_string_right)
	_set_string_draw_z(STRING_DRAW_Z)


func _build_reload_wheel() -> void:
	_reload_wheel = Node3D.new()
	_reload_wheel.name = "RepeaterReloadWheel"
	_reload_wheel.position = Vector3(0.38, 0.43, -0.52)
	_firing_slide.add_child(_reload_wheel)
	_add_cylinder(_reload_wheel, "WoodWheel", 0.19, 0.11, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), _wood_dark_material, 10)
	_add_cylinder(_reload_wheel, "IronAxle", 0.06, 0.22, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), _metal_material, 8)
	for index in 6:
		var angle := TAU * float(index) / 6.0
		_add_beam(_reload_wheel, "Spoke%02d" % index, Vector3.ZERO, Vector3(0.0, cos(angle) * 0.16, sin(angle) * 0.16), 0.014, _metal_material)


func _set_string_draw_z(value: float) -> void:
	_string_draw_z = value
	if not is_instance_valid(_string_left) or not is_instance_valid(_string_right):
		return
	var anchor := Vector3(0.0, 0.53, value)
	_set_beam_geometry(_string_left, Vector3(-1.08, 0.58, BOW_PLANE_Z - 0.05), anchor, 0.012, _rope_material)
	_set_beam_geometry(_string_right, Vector3(1.08, 0.58, BOW_PLANE_Z - 0.05), anchor, 0.012, _rope_material)


func _build_arrow(node_name: String, loaded: bool) -> Node3D:
	var arrow := Node3D.new()
	arrow.name = node_name
	_add_cylinder(arrow, "Shaft", 0.022 if loaded else 0.030, 1.42, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0), _arrow_material, 8)
	_add_cylinder(arrow, "IronHead", 0.075 if loaded else 0.09, 0.20, Vector3(0.0, 0.0, 0.80), Vector3(PI * 0.5, 0.0, 0.0), _metal_material, 8, 0.0)
	_add_box(arrow, "FletchingLeft", Vector3(0.14, 0.018, 0.20), Vector3(0.0, 0.0, -0.61), Vector3.ZERO, _fletching_material)
	_add_box(arrow, "FletchingVertical", Vector3(0.018, 0.14, 0.20), Vector3(0.0, 0.0, -0.61), Vector3.ZERO, _fletching_material)
	return arrow


func _aim_at(target_global: Vector3) -> void:
	var local_target := to_local(target_global)
	var flat := Vector3(local_target.x, 0.0, local_target.z)
	if flat.length_squared() < 0.001:
		return
	_yaw_pivot.rotation.y = clampf(atan2(flat.x, flat.z), -PI * 0.54, PI * 0.54)


func _fire_loaded_arrow(target_global: Vector3, interval: float) -> void:
	_shot_count += 1
	_last_target = target_global
	_loaded_arrow.visible = false
	_set_string_draw_z(STRING_REST_Z)
	_spawn_projectile(target_global)
	_kill_active_tweens()
	_firing_slide.position.z = 0.0
	_recoil_tween = create_tween()
	_recoil_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(_firing_slide, "position:z", -0.10, 0.045)
	_recoil_tween.set_ease(Tween.EASE_IN_OUT)
	_recoil_tween.tween_property(_firing_slide, "position:z", 0.0, 0.11)

	_last_reload_seconds = clampf(interval * _reload_fraction, 0.38, 1.10)
	_reload_tween = create_tween()
	_reload_tween.tween_interval(0.10)
	_reload_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reload_tween.tween_method(_set_string_draw_z, STRING_REST_Z, STRING_DRAW_Z, _last_reload_seconds)
	_reload_tween.tween_callback(_finish_reload)
	_reload_wheel.rotation.x = 0.0
	_wheel_tween = create_tween()
	_wheel_tween.set_trans(Tween.TRANS_LINEAR)
	_wheel_tween.tween_property(_reload_wheel, "rotation:x", TAU * 1.5, _last_reload_seconds)


func _kill_active_tweens() -> void:
	for tween in [_reload_tween, _recoil_tween, _wheel_tween]:
		if tween != null and tween.is_valid():
			tween.kill()


func _finish_reload() -> void:
	_set_string_draw_z(STRING_DRAW_Z)
	if is_instance_valid(_loaded_arrow):
		_loaded_arrow.visible = true


func _spawn_projectile(target_global: Vector3) -> void:
	var projectile := _build_arrow("ArrowTowerProjectile", false)
	projectile.set_meta("presentation_only", true)
	var host := get_tree().current_scene
	if host == null:
		host = self
	host.add_child(projectile)
	projectile.global_position = _muzzle.global_position
	var target := target_global + Vector3.UP * 0.82
	projectile.look_at(target, Vector3.UP, true)
	_active_projectiles.append(projectile)
	_last_flight_seconds = clampf(projectile.global_position.distance_to(target) / _projectile_speed, 0.10, 0.48)
	var flight := projectile.create_tween()
	flight.set_trans(Tween.TRANS_LINEAR)
	flight.tween_property(projectile, "global_position", target, _last_flight_seconds)
	flight.finished.connect(func() -> void:
		if is_instance_valid(projectile):
			projectile.queue_free()
		_cleanup_projectiles()
	)


func _cleanup_projectiles() -> void:
	var alive: Array[Node3D] = []
	for projectile in _active_projectiles:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			alive.append(projectile)
	_active_projectiles = alive


func _make_pbr_material(base_path: String, roughness_path: String, normal_path: String, tint: Color, uv_scale: Vector3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.86
	material.uv1_triplanar = true
	material.uv1_scale = uv_scale
	if ResourceLoader.exists(base_path):
		material.albedo_texture = load(base_path)
	if not roughness_path.is_empty() and ResourceLoader.exists(roughness_path):
		material.roughness_texture = load(roughness_path)
	if not normal_path.is_empty() and ResourceLoader.exists(normal_path):
		material.normal_enabled = true
		material.normal_texture = load(normal_path)
	return material


func _make_flat_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _add_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, local_rotation: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.set_meta("formal_textured_part", true)
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, local_position: Vector3, local_rotation: Vector3, material: Material, radial_segments: int = 12, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.set_meta("formal_textured_part", true)
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_beam(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	beam.name = node_name
	parent.add_child(beam)
	_set_beam_geometry(beam, start, finish, radius, material)
	beam.set_meta("formal_textured_part", true)
	return beam


func _set_beam_geometry(beam: MeshInstance3D, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var direction := finish - start
	var length := maxf(0.001, direction.length())
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	beam.mesh = mesh
	beam.position = (start + finish) * 0.5
	var up := direction / length
	var reference := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.92 else Vector3.FORWARD
	var forward := up.cross(reference).normalized()
	var right := forward.cross(up).normalized()
	beam.basis = Basis(right, up, forward)
	beam.set_surface_override_material(0, material)


func _dict_to_vector3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if not raw is Dictionary:
		return Vector3.ZERO
	return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))


func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}
