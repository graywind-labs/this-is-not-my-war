class_name EnemyMountedArtView
extends Node3D


signal escape_completed(snapshot: Dictionary)

const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")
const HORSE_SCENE_PATH := MOUNTED_PRESENTATION_REFERENCE.HORSE_SCENE_PATH
const HORSE_SCALE := MOUNTED_PRESENTATION_REFERENCE.ENEMY_HORSE_SCALE
const ESCAPE_SPEED_METERS_PER_SECOND := 18.0
const ESCAPE_ARRIVAL_TOLERANCE := 0.8
const RIDER_BODY_VISIBLE_SECONDS := 3.2

var _rider: Node3D
var _horse: Node3D
var _horse_animation_player: AnimationPlayer
var _enemy_id := ""
var _unit_type := ""
var _alive := true
var _moving := false
var _facing_direction := Vector3(0.0, 0.0, -1.0)
var _escape_phase := "mounted"
var _escape_target := Vector3.ZERO
var _escape_start := Vector3.ZERO
var _escape_elapsed := 0.0
var _escape_distance := 0.0
var _rider_body_hidden := false
var _released := false


func setup(rider: Node3D, enemy_id: String, unit_type: String) -> void:
	process_priority = 10
	_rider = rider
	_enemy_id = enemy_id
	_unit_type = unit_type
	if _rider != null:
		_rider.name = "RiderArt"
		add_child(_rider)
	_build_horse()
	add_to_group("enemy_mounted_art")
	set_process(true)


func apply_profile(profile: Dictionary) -> void:
	var mounted_profile := profile.duplicate(true)
	var states: Dictionary = mounted_profile.get("states", {}) if mounted_profile.get("states", {}) is Dictionary else {}
	var next_alive := not bool(states.get("unconscious", false)) and int(states.get("hp", 1)) > 0
	states["combat_mounted"] = next_alive
	states["enemy_mount_has_independent_hp"] = false
	mounted_profile["states"] = states
	if _rider != null and _rider.has_method("apply_profile"):
		_rider.apply_profile(mounted_profile)
	_alive = next_alive
	if not _alive:
		_moving = false
		_play_horse_animation("Walk")


func set_movement_active(active: bool, world_speed: float = 0.0) -> void:
	_moving = active and _alive
	if _rider != null and _rider.has_method("set_movement_active"):
		_rider.set_movement_active(_moving, world_speed)
	if _alive:
		_play_horse_animation("Walk" if _moving else "Idle")


func get_combat_projectile_release_transform(weapon_type: String) -> Transform3D:
	if _rider != null and _rider.has_method("get_combat_projectile_release_transform"):
		return _rider.get_combat_projectile_release_transform(weapon_type)
	return Transform3D(global_basis, global_position + Vector3.UP * 1.8)


func get_combat_projectile_release_snapshot(weapon_type: String) -> Dictionary:
	if _rider == null or not _rider.has_method("get_combat_projectile_release_snapshot"):
		return {
			"ready": false,
			"reason": "mounted_rider_projectile_origin_unavailable",
			"weapon_type": weapon_type,
			"mounted": true,
		}
	var snapshot: Dictionary = _rider.get_combat_projectile_release_snapshot(weapon_type)
	snapshot["mounted"] = true
	snapshot["mounted_wrapper"] = true
	snapshot["source_enemy_id"] = _enemy_id
	return snapshot


func get_combat_melee_contact_segment(weapon_type: String) -> Dictionary:
	if _rider != null and _rider.has_method("get_combat_melee_contact_segment"):
		return _rider.get_combat_melee_contact_segment(weapon_type)
	return {}


func set_facing_direction(direction: Vector3) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return
	_facing_direction = flat_direction.normalized()
	if _rider != null and _rider.has_method("set_facing_direction"):
		_rider.set_facing_direction(_facing_direction)
	_sync_horse_to_rider_facing()


func begin_mounted_defeat_escape(target_world_position: Vector3) -> Dictionary:
	if _released:
		return debug_get_snapshot()
	_alive = false
	_escape_phase = "fleeing_to_map_edge"
	_escape_target = target_world_position
	_escape_start = _horse.global_position if _horse != null else global_position
	_escape_elapsed = 0.0
	_escape_distance = 0.0
	_play_horse_animation("Walk")
	var flee_direction := _escape_target - _escape_start
	if flee_direction.length_squared() > 0.0001:
		_face_horse_toward(flee_direction.normalized())
	return debug_get_snapshot()


func debug_get_snapshot() -> Dictionary:
	var rider_snapshot: Dictionary = _rider.debug_get_snapshot() if _rider != null and _rider.has_method("debug_get_snapshot") else {}
	rider_snapshot["mounted_enemy_wrapper"] = true
	rider_snapshot["enemy_id"] = _enemy_id
	rider_snapshot["unit_type"] = _unit_type
	rider_snapshot["horse_visible"] = _horse != null and _horse.visible
	rider_snapshot["horse_animation"] = _horse_animation_player.current_animation if _horse_animation_player != null else ""
	rider_snapshot["horse_has_independent_hp"] = false
	rider_snapshot["damage_routing"] = "enemy_unit_only"
	rider_snapshot["escape_phase"] = _escape_phase
	rider_snapshot["escape_target"] = _escape_target
	rider_snapshot["escape_start"] = _escape_start
	rider_snapshot["escape_distance"] = _escape_distance
	rider_snapshot["escape_elapsed"] = _escape_elapsed
	rider_snapshot["horse_world_position"] = _horse.global_position if _horse != null else Vector3.ZERO
	rider_snapshot["horse_visible_forward"] = (_horse.global_basis * Vector3.BACK).normalized() if _horse != null else Vector3.ZERO
	rider_snapshot["horse_local_position"] = _horse.position if _horse != null else Vector3.ZERO
	rider_snapshot["horse_scale"] = _horse.scale if _horse != null else Vector3.ZERO
	var rider_forward := Vector3(rider_snapshot.get("visual_forward", Vector3.ZERO)).normalized()
	var horse_forward := Vector3(rider_snapshot.get("horse_visible_forward", Vector3.ZERO)).normalized()
	rider_snapshot["mounted_forward_dot"] = rider_forward.dot(horse_forward) if not rider_forward.is_zero_approx() and not horse_forward.is_zero_approx() else 0.0
	rider_snapshot["rider_body_hidden"] = _rider_body_hidden
	rider_snapshot["released_outside_map"] = _released
	return rider_snapshot


func debug_advance_escape(seconds: float) -> Dictionary:
	if seconds > 0.0:
		_advance_escape(seconds)
	return debug_get_snapshot()


func _process(delta: float) -> void:
	if _released:
		return
	var combat_delta := _get_combat_frame_delta_seconds(delta)
	if _horse_animation_player != null:
		_horse_animation_player.speed_scale = _get_combat_frame_rate()
	if combat_delta <= 0.0:
		return
	if _escape_phase == "mounted":
		_sync_horse_to_rider_facing()
		return
	if _escape_phase != "fleeing_to_map_edge":
		return
	_advance_escape(combat_delta)


func _get_combat_frame_delta_seconds(real_delta_seconds: float) -> float:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system != null and time_system.has_method("get_combat_frame_delta_seconds"):
		return maxf(0.0, float(time_system.get_combat_frame_delta_seconds(real_delta_seconds)))
	return 0.0 if get_tree().paused else maxf(0.0, real_delta_seconds)


func _get_combat_frame_rate() -> float:
	return _get_combat_frame_delta_seconds(1.0)
func _advance_escape(delta: float) -> void:
	if _released or _escape_phase != "fleeing_to_map_edge":
		return
	_escape_elapsed += delta
	if not _rider_body_hidden and _escape_elapsed >= RIDER_BODY_VISIBLE_SECONDS and _rider != null:
		_rider.visible = false
		_rider_body_hidden = true
	if _horse == null:
		_complete_escape()
		return
	var before := _horse.global_position
	var flat_target := Vector3(_escape_target.x, before.y, _escape_target.z)
	var remaining := flat_target - before
	if remaining.length_squared() > 0.0001:
		_face_horse_toward(remaining.normalized())
		_horse.global_position = before.move_toward(flat_target, ESCAPE_SPEED_METERS_PER_SECOND * delta)
	_escape_distance += before.distance_to(_horse.global_position)
	if _horse.global_position.distance_to(flat_target) <= ESCAPE_ARRIVAL_TOLERANCE:
		_complete_escape()


func _build_horse() -> void:
	var horse_scene := load(HORSE_SCENE_PATH) as PackedScene
	if horse_scene == null:
		return
	_horse = horse_scene.instantiate() as Node3D
	if _horse == null:
		return
	_horse.name = "HorseModel"
	_horse.position = MOUNTED_PRESENTATION_REFERENCE.ENEMY_HORSE_LOCAL_POSITION
	_horse.scale = HORSE_SCALE
	add_child(_horse)
	_horse_animation_player = _horse.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play_horse_animation("Idle")


func _play_horse_animation(animation_name: String) -> void:
	if _horse_animation_player == null or not _horse_animation_player.has_animation(animation_name):
		return
	if _horse_animation_player.current_animation != animation_name or not _horse_animation_player.is_playing():
		_horse_animation_player.play(animation_name)


func _face_horse_toward(direction: Vector3) -> void:
	if _horse == null:
		return
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return
	flat_direction = flat_direction.normalized()
	if _horse.is_inside_tree():
		_horse.look_at(_horse.global_position + flat_direction, Vector3.UP, true)
	else:
		_horse.rotation.y = atan2(flat_direction.x, flat_direction.z)


func _sync_horse_to_rider_facing() -> void:
	if _rider == null or not _rider.has_method("get_visible_forward"):
		_face_horse_toward(_facing_direction)
		return
	var rider_forward: Vector3 = _rider.get_visible_forward()
	rider_forward.y = 0.0
	if rider_forward.length_squared() > 0.0001:
		_face_horse_toward(rider_forward.normalized())


func _complete_escape() -> void:
	if _released:
		return
	_released = true
	_escape_phase = "released_outside_map"
	if _horse != null:
		_horse.visible = false
	var snapshot := debug_get_snapshot()
	escape_completed.emit(snapshot)
	queue_free()
