extends Node3D

const ART_REVISION := "t0132_p4a"
const FOOTPRINT_SIZE := Vector3(2.92, 1.72, 3.08)
const BOW_PLANE_Z := 0.62
const STRING_REST_Z := 0.54
const STRING_DRAW_Z := -0.34
const MUZZLE_LOCAL_Z := 1.48
const WOOD_BASE := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_BaseColor.png"
const WOOD_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Normal.png"
const WOOD_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Roughness.png"
const METAL_BASE := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_MetalOrnaments_BaseColor.png"
const METAL_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_MetalOrnaments_Roughness.png"

var _wood_material: StandardMaterial3D
var _wood_dark_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _rope_material: StandardMaterial3D
var _bolt_material: StandardMaterial3D
var _fletching_material: StandardMaterial3D
var _yaw_pivot: Node3D
var _firing_cradle: Node3D
var _loaded_bolt: Node3D
var _muzzle: Marker3D
var _string_left: MeshInstance3D
var _string_right: MeshInstance3D
var _winch: Node3D
var _string_draw_z := STRING_DRAW_Z
var _attack_interval := 4.25
var _projectile_speed := 52.0
var _reload_fraction := 0.62
var _reload_tween: Tween
var _recoil_tween: Tween
var _winch_tween: Tween
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
	_build_ballista()
	_static_structure_part_count = find_children("*", "MeshInstance3D", true, false).size()
	set_meta("art_revision", ART_REVISION)
	set_meta("formal_device_kind", "ballista")
	set_meta("footprint_size", FOOTPRINT_SIZE)
	set_meta("uses_quaternius_pbr", true)


func configure_device(snapshot: Dictionary) -> void:
	var effect: Dictionary = snapshot.get("effect", {}) if snapshot.get("effect", {}) is Dictionary else {}
	var presentation: Dictionary = snapshot.get("presentation", {}) if snapshot.get("presentation", {}) is Dictionary else {}
	_attack_interval = maxf(0.1, float(effect.get("attack_interval", _attack_interval)))
	var projectile: Dictionary = effect.get("projectile", {}) if effect.get("projectile", {}) is Dictionary else {}
	_projectile_speed = maxf(1.0, float(projectile.get("speed", presentation.get("projectile_speed", _projectile_speed))))
	_reload_fraction = clampf(float(presentation.get("reload_fraction", _reload_fraction)), 0.2, 0.9)


func set_destroyed_visual(destroyed: bool) -> void:
	if not destroyed or _destroyed_visual:
		return
	_destroyed_visual = true
	_timeline_phase = "destroyed"
	for tween in [_reload_tween, _recoil_tween, _winch_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	if is_instance_valid(_loaded_bolt):
		_loaded_bolt.visible = false
	if is_instance_valid(_string_left):
		_string_left.visible = false
	if is_instance_valid(_string_right):
		_string_right.visible = false
	var carriage := get_node_or_null("TexturedCarriage") as Node3D
	if carriage != null:
		carriage.position = Vector3(-0.10, -0.08, 0.06)
		carriage.rotation_degrees = Vector3(3.0, -5.0, -8.0)
	if is_instance_valid(_yaw_pivot):
		_yaw_pivot.position = Vector3(0.38, 0.16, -0.18)
		_yaw_pivot.rotation_degrees = Vector3(58.0, -16.0, 22.0)
	if is_instance_valid(_firing_cradle):
		_firing_cradle.position = Vector3(0.12, -0.12, 0.30)
		_firing_cradle.rotation_degrees.z = -12.0
	if is_instance_valid(_winch):
		_winch.position += Vector3(0.22, -0.18, -0.10)
		_winch.rotation_degrees = Vector3(42.0, 18.0, 74.0)
	_build_ruin_debris()
	set_meta("destroyed_visual", true)


func _build_ruin_debris() -> void:
	if get_node_or_null("RuinDebris") != null:
		return
	var debris := Node3D.new()
	debris.name = "RuinDebris"
	add_child(debris)
	_add_box(debris, "BrokenBowArmLeft", Vector3(0.16, 0.14, 1.26), Vector3(-0.94, 0.11, 0.62), Vector3(0.0, 0.38, 1.36), _wood_material)
	_add_box(debris, "BrokenBowArmRight", Vector3(0.16, 0.14, 1.08), Vector3(0.88, 0.12, 0.35), Vector3(0.12, -0.42, -1.18), _wood_material)
	_add_box(debris, "SnappedRunner", Vector3(0.24, 0.20, 1.34), Vector3(-0.40, 0.10, -0.82), Vector3(0.08, 0.55, 0.16), _wood_dark_material)
	_add_cylinder(debris, "LooseWheel", 0.43, 0.20, Vector3(1.03, 0.12, -0.56), Vector3(0.18, 0.22, PI * 0.43), _wood_dark_material, 12)


func get_combat_projectile_release_snapshot(weapon_type: String) -> Dictionary:
	if weapon_type != "crossbow":
		return {"ready": false, "reason": "ballista_weapon_type_mismatch", "origin_source": "unavailable"}
	if not is_instance_valid(_muzzle) or not is_instance_valid(_loaded_bolt) or not _loaded_bolt.visible:
		return {"ready": false, "reason": "ballista_loaded_bolt_unavailable", "origin_source": "unavailable"}
	return {
		"ready": true,
		"transform": _muzzle.global_transform,
		"origin_source": "formal_ballista_muzzle",
		"projectile_node_path": str(_loaded_bolt.get_path()),
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
			_loaded_bolt.visible = false
			_set_string_draw_z(STRING_REST_Z)
		return
	if phase == "recovery":
		var progress := clampf((elapsed - release_seconds) / maxf(0.001, interval - release_seconds), 0.0, 1.0)
		_set_string_draw_z(lerpf(STRING_REST_Z, STRING_DRAW_Z, progress))
		_loaded_bolt.visible = progress >= 0.98
		_firing_cradle.position.z = -0.15 * pow(1.0 - progress, 4.0)
		_winch.rotation.x = TAU * 3.0 * progress
		_last_reload_seconds = interval - release_seconds
		return
	_firing_cradle.position.z = 0.0
	_set_string_draw_z(STRING_DRAW_Z)
	_loaded_bolt.visible = true


func play_device_action(action_result: Dictionary) -> void:
	var target := _dict_to_vector3(action_result.get("target_position", {}))
	if target.is_equal_approx(Vector3.ZERO):
		target = global_position + global_basis.z * 18.0 + Vector3.UP * 0.85
	var interval := maxf(0.1, float(action_result.get("attack_interval", _attack_interval)))
	_aim_at(target)
	_fire_loaded_bolt(target, interval)


func debug_play_attack(target_global_position: Vector3, attack_interval: float = 4.25) -> void:
	play_device_action({
		"target_position": _vector3_to_dict(target_global_position),
		"attack_interval": attack_interval
	})


func get_debug_snapshot() -> Dictionary:
	_cleanup_projectiles()
	return {
		"art_revision": ART_REVISION,
		"formal_device_kind": "ballista",
		"footprint_size": _vector3_to_dict(FOOTPRINT_SIZE),
		"loaded_bolt_visible": is_instance_valid(_loaded_bolt) and _loaded_bolt.visible,
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
		"structure_parts": _static_structure_part_count,
		"has_carriage": true,
		"has_turntable": true,
		"has_winch": true,
		"has_dynamic_string": true
	}


func _build_materials() -> void:
	_wood_material = _make_pbr_material(WOOD_BASE, WOOD_ROUGHNESS, WOOD_NORMAL, Color(0.72, 0.62, 0.51, 1.0), Vector3(1.8, 1.8, 1.8))
	_wood_dark_material = _make_pbr_material(WOOD_BASE, WOOD_ROUGHNESS, WOOD_NORMAL, Color(0.40, 0.30, 0.24, 1.0), Vector3(2.2, 2.2, 2.2))
	_metal_material = _make_pbr_material(METAL_BASE, METAL_ROUGHNESS, "", Color(0.48, 0.50, 0.52, 1.0), Vector3(2.5, 2.5, 2.5))
	_rope_material = _make_flat_material(Color(0.12, 0.075, 0.04, 1.0), 0.96)
	_bolt_material = _make_flat_material(Color(0.26, 0.18, 0.10, 1.0), 0.88)
	_fletching_material = _make_flat_material(Color(0.43, 0.09, 0.07, 1.0), 0.82)


func _build_ballista() -> void:
	var carriage := Node3D.new()
	carriage.name = "TexturedCarriage"
	add_child(carriage)

	_add_box(carriage, "LeftRunner", Vector3(0.26, 0.24, 2.52), Vector3(-0.78, 0.20, -0.02), Vector3.ZERO, _wood_dark_material)
	_add_box(carriage, "RightRunner", Vector3(0.26, 0.24, 2.52), Vector3(0.78, 0.20, -0.02), Vector3.ZERO, _wood_dark_material)
	_add_box(carriage, "FrontCrossBeam", Vector3(2.12, 0.24, 0.28), Vector3(0.0, 0.34, 0.78), Vector3.ZERO, _wood_material)
	_add_box(carriage, "RearCrossBeam", Vector3(2.12, 0.24, 0.28), Vector3(0.0, 0.34, -0.80), Vector3.ZERO, _wood_material)
	_add_box(carriage, "CenterBed", Vector3(0.62, 0.22, 2.20), Vector3(0.0, 0.44, -0.02), Vector3.ZERO, _wood_material)
	_add_box(carriage, "LeftChock", Vector3(0.34, 0.30, 0.46), Vector3(-1.03, 0.19, -0.58), Vector3.ZERO, _wood_dark_material)
	_add_box(carriage, "RightChock", Vector3(0.34, 0.30, 0.46), Vector3(1.03, 0.19, -0.58), Vector3.ZERO, _wood_dark_material)
	_build_wheel(carriage, "LeftWheel", Vector3(-1.06, 0.43, -0.55))
	_build_wheel(carriage, "RightWheel", Vector3(1.06, 0.43, -0.55))
	_add_beam(carriage, "LeftFrontBrace", Vector3(-0.78, 0.35, 0.65), Vector3(-0.43, 0.76, 0.10), 0.075, _wood_dark_material)
	_add_beam(carriage, "RightFrontBrace", Vector3(0.78, 0.35, 0.65), Vector3(0.43, 0.76, 0.10), 0.075, _wood_dark_material)
	_add_beam(carriage, "LeftRearBrace", Vector3(-0.78, 0.35, -0.70), Vector3(-0.43, 0.76, -0.10), 0.075, _wood_dark_material)
	_add_beam(carriage, "RightRearBrace", Vector3(0.78, 0.35, -0.70), Vector3(0.43, 0.76, -0.10), 0.075, _wood_dark_material)

	_yaw_pivot = Node3D.new()
	_yaw_pivot.name = "AimingYawPivot"
	_yaw_pivot.position.y = 0.55
	add_child(_yaw_pivot)
	_add_cylinder(_yaw_pivot, "IronTurntable", 0.58, 0.18, Vector3(0.0, 0.05, -0.04), Vector3.ZERO, _metal_material, 16)
	_add_cylinder(_yaw_pivot, "WoodTurntable", 0.46, 0.22, Vector3(0.0, 0.15, -0.04), Vector3.ZERO, _wood_dark_material, 16)

	_firing_cradle = Node3D.new()
	_firing_cradle.name = "FiringCradle"
	_yaw_pivot.add_child(_firing_cradle)
	_add_box(_firing_cradle, "MainStock", Vector3(0.34, 0.25, 2.42), Vector3(0.0, 0.52, 0.08), Vector3.ZERO, _wood_material)
	_add_box(_firing_cradle, "ArrowGroove", Vector3(0.13, 0.055, 2.20), Vector3(0.0, 0.665, 0.15), Vector3.ZERO, _metal_material)
	_add_box(_firing_cradle, "RearCheekLeft", Vector3(0.20, 0.38, 0.64), Vector3(-0.25, 0.50, -0.76), Vector3(0.0, 0.0, -0.14), _wood_dark_material)
	_add_box(_firing_cradle, "RearCheekRight", Vector3(0.20, 0.38, 0.64), Vector3(0.25, 0.50, -0.76), Vector3(0.0, 0.0, 0.14), _wood_dark_material)
	_add_cylinder(_firing_cradle, "LeftTorsionCase", 0.20, 0.48, Vector3(-0.34, 0.55, BOW_PLANE_Z), Vector3.ZERO, _wood_dark_material, 12)
	_add_cylinder(_firing_cradle, "RightTorsionCase", 0.20, 0.48, Vector3(0.34, 0.55, BOW_PLANE_Z), Vector3.ZERO, _wood_dark_material, 12)
	_add_cylinder(_firing_cradle, "LeftTorsionTopBand", 0.215, 0.055, Vector3(-0.34, 0.81, BOW_PLANE_Z), Vector3.ZERO, _metal_material, 12)
	_add_cylinder(_firing_cradle, "RightTorsionTopBand", 0.215, 0.055, Vector3(0.34, 0.81, BOW_PLANE_Z), Vector3.ZERO, _metal_material, 12)
	_add_cylinder(_firing_cradle, "LeftTorsionBottomBand", 0.215, 0.055, Vector3(-0.34, 0.29, BOW_PLANE_Z), Vector3.ZERO, _metal_material, 12)
	_add_cylinder(_firing_cradle, "RightTorsionBottomBand", 0.215, 0.055, Vector3(0.34, 0.29, BOW_PLANE_Z), Vector3.ZERO, _metal_material, 12)
	_add_cylinder(_firing_cradle, "LeftTorsionRope", 0.12, 0.52, Vector3(-0.34, 0.55, BOW_PLANE_Z), Vector3.ZERO, _rope_material, 10)
	_add_cylinder(_firing_cradle, "RightTorsionRope", 0.12, 0.52, Vector3(0.34, 0.55, BOW_PLANE_Z), Vector3.ZERO, _rope_material, 10)
	_build_bow_arm(-1.0)
	_build_bow_arm(1.0)
	_build_winch()
	_build_dynamic_string()
	_loaded_bolt = _build_bolt("LoadedHeavyBolt", true)
	_firing_cradle.add_child(_loaded_bolt)
	_loaded_bolt.position = Vector3(0.0, 0.76, 0.66)

	_muzzle = Marker3D.new()
	_muzzle.name = "BoltMuzzle"
	_muzzle.position = Vector3(0.0, 0.76, MUZZLE_LOCAL_Z)
	_firing_cradle.add_child(_muzzle)


func _build_wheel(parent: Node3D, node_name: String, center: Vector3) -> void:
	var wheel := Node3D.new()
	wheel.name = node_name
	wheel.position = center
	parent.add_child(wheel)
	_add_cylinder(wheel, "WoodRim", 0.43, 0.20, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), _wood_dark_material, 12)
	_add_cylinder(wheel, "IronHub", 0.12, 0.28, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), _metal_material, 12)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var endpoint := Vector3(0.0, cos(angle) * 0.35, sin(angle) * 0.35)
		_add_beam(wheel, "Spoke%02d" % index, Vector3.ZERO, endpoint, 0.025, _wood_material)


func _build_bow_arm(side: float) -> void:
	var prefix := "Left" if side < 0.0 else "Right"
	var root := Vector3(side * 0.30, 0.58, BOW_PLANE_Z)
	var middle := Vector3(side * 0.88, 0.72, BOW_PLANE_Z + 0.10)
	var tip := Vector3(side * 1.42, 0.82, BOW_PLANE_Z - 0.08)
	_add_beam(_firing_cradle, prefix + "InnerBowArm", root, middle, 0.105, _wood_material)
	_add_beam(_firing_cradle, prefix + "OuterBowArm", middle, tip, 0.085, _wood_material)
	_add_cylinder(_firing_cradle, prefix + "BowTipIron", 0.10, 0.16, tip, Vector3(0.0, 0.0, PI * 0.5), _metal_material, 10)


func _build_winch() -> void:
	_winch = Node3D.new()
	_winch.name = "ReloadWinch"
	_winch.position = Vector3(0.0, 0.79, -0.78)
	_firing_cradle.add_child(_winch)
	_add_cylinder(_winch, "WinchDrum", 0.17, 0.58, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), _wood_dark_material, 12)
	_add_cylinder(_winch, "LeftIronCap", 0.20, 0.06, Vector3(-0.31, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), _metal_material, 12)
	_add_cylinder(_winch, "RightIronCap", 0.20, 0.06, Vector3(0.31, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), _metal_material, 12)
	_add_beam(_winch, "WinchHandle", Vector3(0.31, 0.0, 0.0), Vector3(0.55, 0.18, 0.0), 0.035, _metal_material)
	_add_cylinder(_winch, "WoodGrip", 0.055, 0.23, Vector3(0.55, 0.28, 0.0), Vector3.ZERO, _wood_material, 10)


func _build_dynamic_string() -> void:
	_string_left = MeshInstance3D.new()
	_string_left.name = "LeftDynamicBowString"
	_firing_cradle.add_child(_string_left)
	_string_right = MeshInstance3D.new()
	_string_right.name = "RightDynamicBowString"
	_firing_cradle.add_child(_string_right)
	_set_string_draw_z(STRING_DRAW_Z)


func _set_string_draw_z(value: float) -> void:
	_string_draw_z = value
	if not is_instance_valid(_string_left) or not is_instance_valid(_string_right):
		return
	var anchor := Vector3(0.0, 0.76, _string_draw_z)
	_set_beam_geometry(_string_left, Vector3(-1.42, 0.82, BOW_PLANE_Z - 0.08), anchor, 0.018, _rope_material)
	_set_beam_geometry(_string_right, Vector3(1.42, 0.82, BOW_PLANE_Z - 0.08), anchor, 0.018, _rope_material)


func _build_bolt(node_name: String, loaded: bool) -> Node3D:
	var bolt := Node3D.new()
	bolt.name = node_name
	_add_cylinder(bolt, "Shaft", 0.035 if loaded else 0.045, 1.64, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0), _bolt_material, 10)
	_add_cylinder(bolt, "IronHead", 0.10 if loaded else 0.12, 0.24, Vector3(0.0, 0.0, 0.94), Vector3(PI * 0.5, 0.0, 0.0), _metal_material, 8, 0.0)
	_add_box(bolt, "FletchingLeft", Vector3(0.20, 0.025, 0.25), Vector3(0.0, 0.0, -0.73), Vector3.ZERO, _fletching_material)
	_add_box(bolt, "FletchingVertical", Vector3(0.025, 0.20, 0.25), Vector3(0.0, 0.0, -0.73), Vector3.ZERO, _fletching_material)
	return bolt


func _aim_at(target_global: Vector3) -> void:
	var local_target := to_local(target_global)
	var flat := Vector3(local_target.x, 0.0, local_target.z)
	if flat.length_squared() < 0.001:
		return
	_yaw_pivot.rotation.y = clampf(atan2(flat.x, flat.z), -PI * 0.48, PI * 0.48)


func _fire_loaded_bolt(target_global: Vector3, interval: float) -> void:
	_shot_count += 1
	_last_target = target_global
	_loaded_bolt.visible = false
	_set_string_draw_z(STRING_REST_Z)
	_spawn_projectile(target_global)

	if _reload_tween != null and _reload_tween.is_valid():
		_reload_tween.kill()
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	if _winch_tween != null and _winch_tween.is_valid():
		_winch_tween.kill()
	_firing_cradle.position.z = 0.0
	_recoil_tween = create_tween()
	_recoil_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(_firing_cradle, "position:z", -0.15, 0.075)
	_recoil_tween.set_ease(Tween.EASE_IN_OUT)
	_recoil_tween.tween_property(_firing_cradle, "position:z", 0.0, 0.18)

	_last_reload_seconds = clampf(interval * _reload_fraction, 0.45, 3.20)
	_reload_tween = create_tween()
	_reload_tween.tween_interval(0.16)
	_reload_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reload_tween.tween_method(_set_string_draw_z, STRING_REST_Z, STRING_DRAW_Z, _last_reload_seconds)
	_reload_tween.tween_callback(_finish_reload)

	_winch.rotation.x = 0.0
	_winch_tween = create_tween()
	_winch_tween.set_trans(Tween.TRANS_LINEAR)
	_winch_tween.tween_property(_winch, "rotation:x", TAU * 3.0, _last_reload_seconds)


func _finish_reload() -> void:
	_set_string_draw_z(STRING_DRAW_Z)
	if is_instance_valid(_loaded_bolt):
		_loaded_bolt.visible = true


func _spawn_projectile(target_global: Vector3) -> void:
	var projectile := _build_bolt("BallistaBoltProjectile", false)
	projectile.set_meta("presentation_only", true)
	var host := get_tree().current_scene
	if host == null:
		host = self
	host.add_child(projectile)
	projectile.global_position = _muzzle.global_position
	var target := target_global + Vector3.UP * 0.82
	projectile.look_at(target, Vector3.UP, true)
	_active_projectiles.append(projectile)
	_last_flight_seconds = clampf(projectile.global_position.distance_to(target) / _projectile_speed, 0.14, 0.62)
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
	material.roughness = 0.84
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
	mesh.radial_segments = 10
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
