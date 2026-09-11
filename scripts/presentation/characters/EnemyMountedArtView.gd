class_name EnemyMountedArtView
extends Node3D


signal defeat_cleanup_completed(snapshot: Dictionary)

const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")
const HORSE_SCENE_PATH := MOUNTED_PRESENTATION_REFERENCE.HORSE_SCENE_PATH
const HORSE_SCALE := MOUNTED_PRESENTATION_REFERENCE.ENEMY_HORSE_SCALE
const DEFAULT_CORPSE_LINGER_SECONDS := 8.0
const HORSE_DEATH_ANIMATION := "Death"

var _rider: Node3D
var _horse: Node3D
var _horse_animation_player: AnimationPlayer
var _enemy_id := ""
var _unit_type := ""
var _alive := true
var _moving := false
var _facing_direction := Vector3(0.0, 0.0, -1.0)
var _defeat_phase := "mounted"
var _defeat_elapsed := 0.0
var _corpse_linger_seconds := DEFAULT_CORPSE_LINGER_SECONDS
var _defeat_world_origin := Vector3.ZERO
var _horse_defeat_world_origin := Vector3.ZERO
var _horse_defeat_local_position := Vector3.ZERO
var _horse_death_pose_held := false
var _cleanup_completed := false


func setup(
	rider: Node3D,
	enemy_id: String,
	unit_type: String
) -> void:
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
		begin_mounted_shared_defeat()


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


func get_visible_forward() -> Vector3:
	if _rider != null and _rider.has_method("get_visible_forward"):
		var rider_forward: Vector3 = _rider.get_visible_forward()
		rider_forward.y = 0.0
		if rider_forward.length_squared() > 0.0001:
			return rider_forward.normalized()
	return _facing_direction


func begin_mounted_shared_defeat(corpse_linger_seconds: float = DEFAULT_CORPSE_LINGER_SECONDS) -> Dictionary:
	if _cleanup_completed:
		return debug_get_snapshot()
	if _defeat_phase == "bodies_lingering":
		# CombatSystem reapplies the authoritative presentation duration after the
		# unconscious profile starts this phase; allow that call to extend cleanup.
		_corpse_linger_seconds = maxf(_corpse_linger_seconds, maxf(0.1, corpse_linger_seconds))
		return debug_get_snapshot()
	_alive = false
	_moving = false
	_defeat_phase = "bodies_lingering"
	_defeat_elapsed = 0.0
	_corpse_linger_seconds = maxf(0.1, corpse_linger_seconds)
	_defeat_world_origin = global_position
	_horse_defeat_world_origin = _horse.global_position if _horse != null else global_position
	_horse_defeat_local_position = _horse.position if _horse != null else Vector3.ZERO
	_horse_death_pose_held = false
	_play_horse_death_animation()
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
	rider_snapshot["defeat_phase"] = _defeat_phase
	rider_snapshot["defeat_elapsed"] = _defeat_elapsed
	rider_snapshot["corpse_linger_seconds"] = _corpse_linger_seconds
	rider_snapshot["corpse_linger_remaining_seconds"] = maxf(0.0, _corpse_linger_seconds - _defeat_elapsed)
	rider_snapshot["defeat_world_origin"] = _defeat_world_origin
	rider_snapshot["root_world_position"] = global_position
	rider_snapshot["root_position_drift"] = global_position.distance_to(_defeat_world_origin) if _defeat_phase != "mounted" else 0.0
	rider_snapshot["horse_defeat_world_origin"] = _horse_defeat_world_origin
	rider_snapshot["horse_world_position"] = _horse.global_position if _horse != null else Vector3.ZERO
	rider_snapshot["horse_position_drift"] = _horse.global_position.distance_to(_horse_defeat_world_origin) if _horse != null and _defeat_phase != "mounted" else 0.0
	rider_snapshot["horse_visible_forward"] = (_horse.global_basis * Vector3.BACK).normalized() if _horse != null else Vector3.ZERO
	rider_snapshot["horse_local_position"] = _horse.position if _horse != null else Vector3.ZERO
	rider_snapshot["horse_scale"] = _horse.scale if _horse != null else Vector3.ZERO
	rider_snapshot["horse_death_clip_available"] = _horse_animation_player != null and _horse_animation_player.has_animation(HORSE_DEATH_ANIMATION)
	rider_snapshot["horse_death_clip_length"] = _get_horse_death_clip_length()
	rider_snapshot["horse_death_pose_held"] = _horse_death_pose_held
	var rider_forward := Vector3(rider_snapshot.get("visual_forward", Vector3.ZERO)).normalized()
	var horse_forward := Vector3(rider_snapshot.get("horse_visible_forward", Vector3.ZERO)).normalized()
	rider_snapshot["mounted_forward_dot"] = rider_forward.dot(horse_forward) if not rider_forward.is_zero_approx() and not horse_forward.is_zero_approx() else 0.0
	rider_snapshot["rider_body_visible"] = _rider != null and _rider.visible
	rider_snapshot["cleanup_completed"] = _cleanup_completed
	return rider_snapshot


func debug_advance_defeat(seconds: float) -> Dictionary:
	if seconds > 0.0:
		_advance_defeat(seconds)
	return debug_get_snapshot()


func _process(delta: float) -> void:
	if _cleanup_completed:
		return
	var combat_delta := _get_combat_frame_delta_seconds(delta)
	if _horse_animation_player != null:
		_horse_animation_player.speed_scale = _get_combat_frame_rate()
	if combat_delta <= 0.0:
		return
	if _defeat_phase == "mounted":
		_sync_horse_to_rider_facing()
		return
	if _defeat_phase != "bodies_lingering":
		return
	if _horse != null:
		_horse.position = _horse_defeat_local_position
	_advance_defeat(combat_delta)


func _get_combat_frame_delta_seconds(real_delta_seconds: float) -> float:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system != null and time_system.has_method("get_combat_frame_delta_seconds"):
		return maxf(0.0, float(time_system.get_combat_frame_delta_seconds(real_delta_seconds)))
	return 0.0 if get_tree().paused else maxf(0.0, real_delta_seconds)


func _get_combat_frame_rate() -> float:
	return _get_combat_frame_delta_seconds(1.0)


func _advance_defeat(delta: float) -> void:
	if _cleanup_completed or _defeat_phase != "bodies_lingering":
		return
	_defeat_elapsed += delta
	if _horse != null:
		_horse.position = _horse_defeat_local_position
	if _defeat_elapsed >= _corpse_linger_seconds:
		_complete_defeat_cleanup()


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
	if _horse_animation_player != null and not _horse_animation_player.animation_finished.is_connected(_on_horse_animation_finished):
		_horse_animation_player.animation_finished.connect(_on_horse_animation_finished)
	_play_horse_animation("Idle")


func _play_horse_animation(animation_name: String) -> void:
	if _horse_animation_player == null or not _horse_animation_player.has_animation(animation_name):
		return
	if _horse_animation_player.current_animation != animation_name or not _horse_animation_player.is_playing():
		_horse_animation_player.play(animation_name)


func _play_horse_death_animation() -> void:
	if _horse_animation_player == null or not _horse_animation_player.has_animation(HORSE_DEATH_ANIMATION):
		return
	var death_animation := _horse_animation_player.get_animation(HORSE_DEATH_ANIMATION)
	if death_animation != null:
		death_animation.loop_mode = Animation.LOOP_NONE
	_horse_animation_player.play(HORSE_DEATH_ANIMATION)


func _get_horse_death_clip_length() -> float:
	if _horse_animation_player == null or not _horse_animation_player.has_animation(HORSE_DEATH_ANIMATION):
		return 0.0
	var death_animation := _horse_animation_player.get_animation(HORSE_DEATH_ANIMATION)
	return death_animation.length if death_animation != null else 0.0


func _on_horse_animation_finished(animation_name: StringName) -> void:
	if str(animation_name) != HORSE_DEATH_ANIMATION or _defeat_phase != "bodies_lingering":
		return
	var clip_length := _get_horse_death_clip_length()
	if clip_length > 0.0:
		_horse_animation_player.seek(clip_length, true)
	_horse_animation_player.pause()
	_horse_death_pose_held = true


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


func _complete_defeat_cleanup() -> void:
	if _cleanup_completed:
		return
	_cleanup_completed = true
	_defeat_phase = "cleaned_up"
	var snapshot := debug_get_snapshot()
	defeat_cleanup_completed.emit(snapshot)
	queue_free()
