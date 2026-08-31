extends ActorMotionBody

signal movement_arrived(npc_id: String, target_id: String)
signal movement_request_failed(npc_id: String, target_id: String, reason: String)

const LABEL_NODE_PATH := "NameLabel"
const STATUS_LABEL_NODE_PATH := "StatusLabel"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const CHARACTER_APPEARANCE_CONFIG_PATH := "res://data/presentation/character_appearances.json"
const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")
const HORSE_APPEARANCE := preload("res://scripts/presentation/characters/HorseAppearance.gd")
const COMBAT_HORSE_SCENE_PATH := "res://assets/3d/quaternius/animals/merchant_horse.glb"
const RECRUITED_NAME_COLOR := Color(0.64, 0.92, 0.68, 1.0)
const DEFAULT_NAME_COLOR := Color.WHITE
const PORTRAIT_OVERLAY_VISUAL_LAYER := 20
const PORTRAIT_STANDING_FOCUS_HEIGHT := 0.92
const PORTRAIT_STANDING_CAMERA_HEIGHT := 1.15
const PORTRAIT_MOUNTED_FOCUS_HEIGHT := 1.72
const PORTRAIT_MOUNTED_CAMERA_HEIGHT := 2.02
const PORTRAIT_LYING_FOCUS_HEIGHT := 0.42
const PORTRAIT_LYING_CAMERA_HEIGHT := 1.45
const MOVEMENT_SLOWDOWN_REQUEST_PREFIX := "npc_movement:"
const DEFAULT_WALK_SPEED := 3.2
const DEFAULT_RUN_SPEED := 5.0
const DEFAULT_EMERGENCY_BEHAVIOR_MODES := ["rally", "combat", "avoid_combat", "escaped"]

@export var move_speed := 5.0

var npc_id: String = ""
var profile: Dictionary = {}
var _movement_target_id := ""
var _movement_target_position := Vector3.ZERO
var _is_moving := false
var _movement_slowdown_request_id := ""
var _navigation_motion_enabled := false
var _spatial_attachment_active := false
var _spatial_attachment_pose := ""
var _spatial_attachment_position := Vector3.ZERO
var _legacy_visuals_base_transform := Transform3D.IDENTITY
var _art_mount_base_transform := Transform3D.IDENTITY
var _portrait_facing_direction := Vector3(0.0, 0.0, -1.0)
var _locomotion_config: Dictionary = {}
var _locomotion_state := "walk"
var _locomotion_reference_speed := DEFAULT_WALK_SPEED
var _actual_horizontal_speed := 0.0
var _pending_unmounted_actual_run_seconds := 0.0

@onready var _name_label := get_node_or_null(LABEL_NODE_PATH) as Label3D
@onready var _status_label := get_node_or_null(STATUS_LABEL_NODE_PATH) as Label3D
@onready var _unconscious_interaction_collision := get_node_or_null("InteractionArea/UnconsciousInteractionCollision") as CollisionShape3D
var _proactive_bubble: Label3D
var _dialogue_bubble_area: Area3D
var _dialogue_bubble_collision: CollisionShape3D
var _dialogue_bubble_label: Label3D
var _dialogue_bubble_material: StandardMaterial3D
var _llm_activity_marker: Label3D
var _escape_warning_marker: Label3D
var _mount_visual: Node3D
var _mount_horse_model: Node3D
var _mount_animation_player: AnimationPlayer
var _mount_uses_imported_horse := false
var _mount_applied_horse_id := ""
var _mount_applied_coat_color := ""
var _mount_applied_template_id := ""
var _facing_marker: Label3D
var _character_art_view: Node3D
var _character_appearance_id := "legacy_placeholder"
var _interaction_pose := "standing"


func setup(npc_profile: Dictionary) -> void:
	profile = npc_profile.duplicate(true)
	npc_id = str(profile.get("id", ""))
	_pending_unmounted_actual_run_seconds = 0.0
	name = _make_node_name(npc_id)
	set_meta("npc_id", npc_id)
	configure_avoidance_identity("friendly:%s" % npc_id, 0.5)
	_configure_character_art_view()
	_apply_profile_to_character_art()
	_sync_unconscious_physical_entity()
	_refresh_label()


func update_profile(npc_profile: Dictionary) -> void:
	profile = npc_profile.duplicate(true)
	_refresh_active_locomotion_profile()
	_apply_profile_to_character_art()
	var states: Dictionary = profile.get("states", {})
	if bool(states.get("escaped", false)):
		stop_movement()
		visible = false
		_set_interaction_enabled(false)
		return
	visible = true
	_set_interaction_enabled(true)
	if bool(states.get("unconscious", false)):
		stop_movement()
	_sync_unconscious_physical_entity()
	_refresh_label()


func move_to_location(target_id: String, target_position: Vector3, motion_options: Dictionary = {}) -> void:
	_movement_target_id = target_id
	_movement_target_position = target_position
	if _navigation_motion_enabled:
		var runtime_overrides := {
			"profile": {"base_speed": _get_authoritative_move_speed()}
		}
		if motion_options.has("target_desired_distance"):
			runtime_overrides["navigation_agent"] = {
				"target_desired_distance": clampf(float(motion_options.get("target_desired_distance", 0.25)), 0.05, 0.5)
			}
		configure_profile("npc", runtime_overrides)
		if not request_motion(target_position, target_id, motion_options):
			_set_movement_active(false)
		return
	_set_movement_active(true)


func stop_movement() -> void:
	if _navigation_motion_enabled and is_motion_active():
		cancel_motion("stopped")
	_set_movement_active(false)
	_movement_target_id = ""
	velocity = Vector3.ZERO


func is_world_movement_active() -> bool:
	if _navigation_motion_enabled:
		return _is_moving and is_motion_active()
	return _is_moving


func configure_navigation_motion(enabled: bool, navigation_map: RID = RID()) -> bool:
	if enabled and _spatial_attachment_active:
		detach_from_spatial_anchor()
	stop_movement()
	_navigation_motion_enabled = enabled
	if enabled:
		if not set_navigation_map(navigation_map):
			_navigation_motion_enabled = false
			return false
		navigation_agent.avoidance_enabled = not _is_profile_unconscious()
	elif is_inside_tree() and get_world_3d() != null:
		navigation_agent.avoidance_enabled = false
		navigation_agent.set_navigation_map(get_world_3d().navigation_map)
	return true


func is_navigation_motion_enabled() -> bool:
	return _navigation_motion_enabled


func is_unconscious() -> bool:
	return _is_profile_unconscious()


func set_facing_direction(direction: Vector3) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() > 0.0001:
		_portrait_facing_direction = flat_direction.normalized()
	if _character_art_view != null and _character_art_view.has_method("set_facing_direction"):
		_character_art_view.set_facing_direction(direction)
	_sync_combat_mount_facing()


func play_temporary_presentation_action(action_id: String, event_id: String) -> Dictionary:
	if _character_art_view == null or not _character_art_view.has_method("play_temporary_presentation_action"):
		return {
			"ok": false,
			"reason": "formal_character_art_not_available",
			"npc_id": npc_id,
			"action_id": action_id,
			"event_id": event_id
		}
	var result: Dictionary = _character_art_view.play_temporary_presentation_action(action_id, event_id)
	result["npc_id"] = npc_id
	return result


func _process(_delta: float) -> void:
	_sync_combat_mount_facing()
	_refresh_combat_mount_animation()


func _sync_combat_mount_facing() -> void:
	if _mount_visual == null:
		return
	var visible_forward := _portrait_facing_direction
	if _character_art_view != null and _character_art_view.has_method("get_visible_forward"):
		var rider_forward: Vector3 = _character_art_view.get_visible_forward()
		rider_forward.y = 0.0
		if rider_forward.length_squared() > 0.0001:
			visible_forward = rider_forward.normalized()
	if visible_forward.length_squared() > 0.0001:
		_mount_visual.look_at(_mount_visual.global_position + visible_forward, Vector3.UP, true)


func get_portrait_camera_snapshot() -> Dictionary:
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	var escaped := bool(states.get("escaped", false))
	var visible_forward := _portrait_facing_direction
	if _character_art_view != null and _character_art_view.has_method("get_visible_forward"):
		var art_forward: Vector3 = _character_art_view.get_visible_forward()
		art_forward.y = 0.0
		if art_forward.length_squared() > 0.0001:
			visible_forward = art_forward.normalized()
	var lying_pose := _spatial_attachment_pose in ["lying_supine", "sleeping_supine"] or bool(states.get("unconscious", false))
	var mounted_pose := not lying_pose and bool(states.get("combat_mounted", false))
	var focus_height := PORTRAIT_STANDING_FOCUS_HEIGHT
	var camera_height := PORTRAIT_STANDING_CAMERA_HEIGHT
	if lying_pose:
		focus_height = PORTRAIT_LYING_FOCUS_HEIGHT
		camera_height = PORTRAIT_LYING_CAMERA_HEIGHT
	elif mounted_pose:
		focus_height = PORTRAIT_MOUNTED_FOCUS_HEIGHT
		camera_height = PORTRAIT_MOUNTED_CAMERA_HEIGHT
	var location_id := str(states.get("current_location", ""))
	var location_name := str(states.get("current_location_name", "")).strip_edges()
	if location_name.is_empty():
		location_name = "驿站内" if location_id.is_empty() else location_id
	return {
		"valid": not npc_id.is_empty() and is_inside_tree(),
		"visible": visible and is_visible_in_tree() and not escaped,
		"npc_id": npc_id,
		"display_name": str(profile.get("name", npc_id)),
		"world_position": global_position,
		"visual_forward": visible_forward,
		"focus_height": focus_height,
		"camera_height": camera_height,
		"mounted": mounted_pose,
		"location_id": location_id,
		"location_name": location_name,
		"current_action": str(states.get("current_action", "idle")),
		"unconscious": bool(states.get("unconscious", false)),
		"attachment_pose": _spatial_attachment_pose,
	}


func _configure_portrait_overlay_layers() -> void:
	for raw_label in find_children("*", "Label3D", true, false):
		var label := raw_label as Label3D
		if label == null:
			continue
		label.layers = 1 << (PORTRAIT_OVERLAY_VISUAL_LAYER - 1)


func attach_to_spatial_anchor(
	anchor_position: Vector3,
	facing_direction: Vector3,
	pose: String,
	disable_body_collision: bool = true
) -> bool:
	if pose.is_empty():
		return false
	stop_movement()
	_spatial_attachment_active = true
	_spatial_attachment_pose = pose
	_spatial_attachment_position = anchor_position
	navigation_agent.avoidance_enabled = false
	body_collision.set_deferred("disabled", disable_body_collision)
	global_position = anchor_position
	set_facing_direction(facing_direction)
	_apply_spatial_attachment_pose(pose)
	return true


func detach_from_spatial_anchor() -> void:
	if not _spatial_attachment_active:
		return
	_spatial_attachment_active = false
	_spatial_attachment_pose = ""
	_spatial_attachment_position = Vector3.ZERO
	var unconscious := _is_profile_unconscious()
	body_collision.set_deferred("disabled", unconscious)
	navigation_agent.avoidance_enabled = _navigation_motion_enabled and not unconscious
	_restore_spatial_attachment_pose()


func debug_get_spatial_attachment_snapshot() -> Dictionary:
	var active_interaction_collision := (
		_unconscious_interaction_collision
		if _interaction_pose == "unconscious_horizontal"
		else interaction_collision
	)
	var interaction_capsule := active_interaction_collision.shape as CapsuleShape3D if active_interaction_collision != null else null
	return {
		"active": _spatial_attachment_active,
		"pose": _spatial_attachment_pose,
		"anchor_position": _spatial_attachment_position,
		"world_position": global_position,
		"body_collision_disabled": body_collision.disabled,
		"navigation_avoidance_enabled": navigation_agent.avoidance_enabled,
		"unconscious_physical_entity_suppressed": _is_profile_unconscious() and body_collision.disabled and not navigation_agent.avoidance_enabled,
		"interaction_enabled": active_interaction_collision != null and not active_interaction_collision.disabled,
		"interaction_pose": _interaction_pose,
		"interaction_local_position": active_interaction_collision.position if active_interaction_collision != null else Vector3.ZERO,
		"interaction_long_axis": active_interaction_collision.basis.y.normalized() if active_interaction_collision != null else Vector3.UP,
		"interaction_capsule_radius": interaction_capsule.radius if interaction_capsule != null else 0.0,
		"interaction_capsule_height": interaction_capsule.height if interaction_capsule != null else 0.0
	}


func _sync_unconscious_physical_entity() -> void:
	if not is_node_ready() or body_collision == null or navigation_agent == null:
		return
	var unconscious := _is_profile_unconscious()
	_sync_interaction_collision_pose(unconscious)
	if unconscious:
		# Keep the fallen model and InteractionArea so the player can inspect it
		# and helpers can still target it, but remove both physical and RVO body
		# presence. Enemies changing target can therefore leave the exact knockout
		# point instead of running against an upright invisible capsule.
		body_collision.set_deferred("disabled", true)
		navigation_agent.avoidance_enabled = false
		navigation_agent.set_velocity_forced(Vector3.ZERO)
		return
	if _spatial_attachment_active:
		return
	body_collision.set_deferred("disabled", false)
	navigation_agent.avoidance_enabled = _navigation_motion_enabled


func _is_profile_unconscious() -> bool:
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	return bool(states.get("unconscious", false))


func _ready() -> void:
	super._ready()
	_load_locomotion_config()
	# Run the mount follow-up after the rider pilot's default-priority process so
	# the horse copies the visible (smoothed) rider facing from this same frame.
	process_priority = 10
	var legacy_visuals := get_node_or_null("LegacyVisuals") as Node3D
	var art_mount := get_node_or_null("ArtMount") as Node3D
	if legacy_visuals != null:
		_legacy_visuals_base_transform = legacy_visuals.transform
	if art_mount != null:
		_art_mount_base_transform = art_mount.transform
	_set_interaction_enabled(true)
	_sync_unconscious_physical_entity()
	if interaction_area != null and not interaction_area.input_event.is_connected(_on_input_event):
		interaction_area.input_event.connect(_on_input_event)
	if not motion_started.is_connected(_on_navigation_motion_started):
		motion_started.connect(_on_navigation_motion_started)
	if not motion_arrived.is_connected(_on_navigation_motion_arrived):
		motion_arrived.connect(_on_navigation_motion_arrived)
	if not motion_failed.is_connected(_on_navigation_motion_failed):
		motion_failed.connect(_on_navigation_motion_failed)
	if not motion_cancelled.is_connected(_on_navigation_motion_cancelled):
		motion_cancelled.connect(_on_navigation_motion_cancelled)
	_ensure_proactive_bubble()
	_ensure_dialogue_bubble()
	_ensure_llm_activity_marker()
	_ensure_escape_warning_marker()
	_ensure_combat_visuals()
	_configure_portrait_overlay_layers()
	_configure_character_art_view()
	_refresh_label()


func _exit_tree() -> void:
	_release_movement_time_slowdown(true)


func _physics_process(delta: float) -> void:
	var position_before_motion := global_position
	if _navigation_motion_enabled:
		set_motion_paused(_is_gameplay_paused())
		super._physics_process(delta)
		if velocity.length_squared() > 0.0001:
			set_facing_direction(velocity)
		_update_actual_movement_presentation(position_before_motion, delta)
		return
	if not _is_moving:
		return
	if _is_gameplay_paused():
		velocity = Vector3.ZERO
		return

	var movement_direction := _movement_target_position - global_position
	set_facing_direction(movement_direction)
	velocity = Vector3.ZERO
	global_position = global_position.move_toward(
		_movement_target_position,
		_get_authoritative_move_speed() * delta
	)
	_update_actual_movement_presentation(position_before_motion, delta)
	if global_position.distance_to(_movement_target_position) <= 0.05:
		global_position = _movement_target_position
		var arrived_target_id := _movement_target_id
		stop_movement()
		movement_arrived.emit(npc_id, arrived_target_id)


func _on_navigation_motion_started(_request_id: String, _target_position: Vector3) -> void:
	if not _navigation_motion_enabled:
		return
	_set_movement_active(true)


func _on_navigation_motion_arrived(request_id: String, _target_position: Vector3) -> void:
	if not _navigation_motion_enabled:
		return
	_set_movement_active(false)
	_movement_target_id = ""
	movement_arrived.emit(npc_id, request_id)


func _on_navigation_motion_failed(request_id: String, reason: String) -> void:
	if not _navigation_motion_enabled:
		return
	_set_movement_active(false)
	_movement_target_id = ""
	movement_request_failed.emit(npc_id, request_id, reason)


func _on_navigation_motion_cancelled(_request_id: String, _reason: String) -> void:
	if not _navigation_motion_enabled:
		return
	_set_movement_active(false)


func _set_movement_active(active: bool) -> void:
	_is_moving = active
	_locomotion_state = _resolve_locomotion_state()
	_locomotion_reference_speed = _get_locomotion_reference_speed(_locomotion_state)
	if not active:
		_actual_horizontal_speed = 0.0
	if active:
		_request_movement_time_slowdown()
	else:
		_release_movement_time_slowdown()
	if _character_art_view != null and _character_art_view.has_method("set_movement_active"):
		_character_art_view.set_movement_active(
			active,
			_get_authoritative_move_speed() if active else 0.0,
			_locomotion_state,
			_locomotion_reference_speed,
			float(_locomotion_config.get("minimum_animation_speed_scale", 0.35)),
			float(_locomotion_config.get("maximum_animation_speed_scale", 1.6))
		)
	_refresh_combat_mount_animation()


func _update_actual_movement_presentation(position_before_motion: Vector3, delta: float) -> void:
	if not _is_moving or delta <= 0.0 or _is_gameplay_paused():
		return
	var displacement := global_position - position_before_motion
	displacement.y = 0.0
	_actual_horizontal_speed = displacement.length() / delta
	var actual_run_speed_margin := maxf(
		0.0,
		float(_locomotion_config.get("actual_run_speed_margin", 0.05))
	)
	if (
		_locomotion_state == "run"
		and not _is_combat_mounted()
		and _actual_horizontal_speed > _get_walk_speed() + actual_run_speed_margin
	):
		_pending_unmounted_actual_run_seconds += delta
	if _character_art_view != null and _character_art_view.has_method("set_movement_active"):
		_character_art_view.set_movement_active(
			true,
			_actual_horizontal_speed,
			_locomotion_state,
			_locomotion_reference_speed,
			float(_locomotion_config.get("minimum_animation_speed_scale", 0.35)),
			float(_locomotion_config.get("maximum_animation_speed_scale", 1.6))
		)
	_refresh_combat_mount_animation()


func _refresh_active_locomotion_profile() -> void:
	var next_state := _resolve_locomotion_state()
	var state_changed := next_state != _locomotion_state
	_locomotion_state = next_state
	_locomotion_reference_speed = _get_locomotion_reference_speed(next_state)
	if _is_moving and _navigation_motion_enabled:
		configure_profile("npc", {"profile": {"base_speed": _get_authoritative_move_speed()}})
	if _is_moving and (state_changed or _character_art_view != null):
		if _character_art_view != null and _character_art_view.has_method("set_movement_active"):
			_character_art_view.set_movement_active(
				true,
				_actual_horizontal_speed,
				_locomotion_state,
				_locomotion_reference_speed,
				float(_locomotion_config.get("minimum_animation_speed_scale", 0.35)),
				float(_locomotion_config.get("maximum_animation_speed_scale", 1.6))
			)


func _resolve_locomotion_state() -> String:
	if _is_zero_satiety_walk_limited():
		return "walk"
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	var escape_intent: Dictionary = states.get("escape_intent", {}) if states.get("escape_intent", {}) is Dictionary else {}
	if bool(escape_intent.get("active", false)) and str(escape_intent.get("status", "")) == "escaping":
		return "run"
	var emergency_modes: Array = _locomotion_config.get("emergency_behavior_modes", DEFAULT_EMERGENCY_BEHAVIOR_MODES)
	return "run" if str(states.get("behavior_mode", "work")) in emergency_modes else "walk"


func _get_locomotion_reference_speed(state_name: String) -> float:
	var key := "%s_animation_reference_speed" % state_name
	var fallback := DEFAULT_RUN_SPEED if state_name == "run" else DEFAULT_WALK_SPEED
	return maxf(0.01, float(_locomotion_config.get(key, fallback)))


func _get_authoritative_move_speed() -> float:
	var state_name := _resolve_locomotion_state()
	var fallback := DEFAULT_RUN_SPEED if state_name == "run" else DEFAULT_WALK_SPEED
	var base_speed := float(_locomotion_config.get("%s_speed" % state_name, fallback))
	var resolved_speed := maxf(0.0, base_speed * _get_move_speed_multiplier())
	if _is_zero_satiety_walk_limited():
		return minf(resolved_speed, _get_walk_speed())
	return resolved_speed


func _get_walk_speed() -> float:
	return maxf(0.0, float(_locomotion_config.get("walk_speed", DEFAULT_WALK_SPEED)))


func _is_combat_mounted() -> bool:
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	return bool(states.get("combat_mounted", false))


func _is_zero_satiety_walk_limited() -> bool:
	if _is_combat_mounted():
		return false
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	return float(states.get("satiety", 0.0)) <= 0.0


func consume_unmounted_actual_run_seconds() -> float:
	var consumed := maxf(0.0, _pending_unmounted_actual_run_seconds)
	_pending_unmounted_actual_run_seconds = 0.0
	return consumed


func get_locomotion_needs_snapshot() -> Dictionary:
	return {
		"npc_id": npc_id,
		"locomotion_state": _locomotion_state,
		"movement_active": is_world_movement_active(),
		"actual_horizontal_speed": _actual_horizontal_speed,
		"walk_speed": _get_walk_speed(),
		"authoritative_move_speed": _get_authoritative_move_speed(),
		"combat_mounted": _is_combat_mounted(),
		"zero_satiety_walk_limited": _is_zero_satiety_walk_limited(),
		"pending_unmounted_actual_run_seconds": _pending_unmounted_actual_run_seconds
	}


func _load_locomotion_config() -> void:
	_locomotion_config = (_config.get("npc_locomotion", {}) as Dictionary).duplicate(true)
	if str(_locomotion_config.get("schema_version", "")) != "npc_locomotion_v1":
		push_warning("NPC locomotion config missing or invalid; using production defaults.")
		_locomotion_config = {
			"schema_version": "npc_locomotion_v1",
			"walk_speed": DEFAULT_WALK_SPEED,
			"run_speed": DEFAULT_RUN_SPEED,
			"walk_animation_reference_speed": DEFAULT_WALK_SPEED,
			"run_animation_reference_speed": DEFAULT_RUN_SPEED,
			"actual_run_speed_margin": 0.05,
			"minimum_animation_speed_scale": 0.35,
			"maximum_animation_speed_scale": 1.6,
			"emergency_behavior_modes": DEFAULT_EMERGENCY_BEHAVIOR_MODES.duplicate()
		}
	_locomotion_state = _resolve_locomotion_state()
	_locomotion_reference_speed = _get_locomotion_reference_speed(_locomotion_state)


func _request_movement_time_slowdown() -> void:
	if npc_id.is_empty() or not _movement_slowdown_request_id.is_empty():
		return
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null or not time_system.has_method("request_time_slowdown"):
		return
	_movement_slowdown_request_id = "%s%s" % [MOVEMENT_SLOWDOWN_REQUEST_PREFIX, npc_id]
	time_system.request_time_slowdown(
		_movement_slowdown_request_id,
		-1.0,
		"npc_movement"
	)


func _release_movement_time_slowdown(deferred: bool = false) -> void:
	if _movement_slowdown_request_id.is_empty():
		return
	var request_id := _movement_slowdown_request_id
	_movement_slowdown_request_id = ""
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system != null and time_system.has_method("release_time_slowdown"):
		if deferred:
			time_system.call_deferred("release_time_slowdown", request_id)
		else:
			time_system.release_time_slowdown(request_id)


func _apply_spatial_attachment_pose(pose: String) -> void:
	_restore_spatial_attachment_pose()
	if _character_art_view != null and _character_art_view.has_method("set_spatial_attachment_pose"):
		_character_art_view.call("set_spatial_attachment_pose", pose)
	if pose not in ["lying_supine", "sleeping_supine"]:
		return
	var pose_basis := Basis(Vector3.RIGHT, -PI * 0.5)
	var pose_offset := Vector3(0.0, 0.18, 0.55)
	var legacy_visuals := get_node_or_null("LegacyVisuals") as Node3D
	var art_mount := get_node_or_null("ArtMount") as Node3D
	if legacy_visuals != null:
		legacy_visuals.transform = Transform3D(pose_basis, pose_offset) * _legacy_visuals_base_transform
	if (_character_art_view == null or not _character_art_view.has_method("set_spatial_attachment_pose")) and art_mount != null:
		art_mount.transform = Transform3D(pose_basis, pose_offset) * _art_mount_base_transform


func _restore_spatial_attachment_pose() -> void:
	var legacy_visuals := get_node_or_null("LegacyVisuals") as Node3D
	var art_mount := get_node_or_null("ArtMount") as Node3D
	if legacy_visuals != null:
		legacy_visuals.transform = _legacy_visuals_base_transform
	if art_mount != null:
		art_mount.transform = _art_mount_base_transform
	if _character_art_view != null and _character_art_view.has_method("set_spatial_attachment_pose"):
		_character_art_view.call("set_spatial_attachment_pose", "")


func _set_interaction_enabled(enabled: bool) -> void:
	# The ActorMotionBody itself owns the physical collision and can receive ray
	# hits independently of the child interaction area. Escaped actors must make
	# both surfaces unpickable.
	input_ray_pickable = enabled
	if interaction_area != null:
		interaction_area.input_ray_pickable = enabled
	if interaction_collision != null:
		interaction_collision.set_deferred("disabled", not enabled or _interaction_pose != "standing")
	if _unconscious_interaction_collision != null:
		_unconscious_interaction_collision.set_deferred(
			"disabled",
			not enabled or _interaction_pose != "unconscious_horizontal"
		)


func _sync_interaction_collision_pose(unconscious: bool) -> void:
	if interaction_collision == null or _unconscious_interaction_collision == null:
		return
	if unconscious:
		_interaction_pose = "unconscious_horizontal"
	else:
		_interaction_pose = "standing"
	interaction_collision.set_deferred("disabled", _interaction_pose != "standing")
	_unconscious_interaction_collision.set_deferred(
		"disabled",
		_interaction_pose != "unconscious_horizontal"
	)


func _get_move_speed_multiplier() -> float:
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	var morale: Dictionary = states.get("morale_boost", {}) if states.get("morale_boost", {}) is Dictionary else {}
	var multiplier := 1.0
	if bool(morale.get("active", false)):
		multiplier += clampf(float(morale.get("move_speed_bonus", 0.0)), 0.0, 1.0)
	var escape_intent: Dictionary = states.get("escape_intent", {}) if states.get("escape_intent", {}) is Dictionary else {}
	if bool(escape_intent.get("active", false)) and str(escape_intent.get("status", "")) == "escaping":
		multiplier *= clampf(float(escape_intent.get("speed_multiplier", 1.0)), 0.25, 3.0)
	var equipment: Dictionary = profile.get("equipment", {}) if profile.get("equipment", {}) is Dictionary else {}
	var mount: Dictionary = equipment.get("mount", {}) if equipment.get("mount", {}) is Dictionary else {}
	if not mount.is_empty():
		multiplier *= maxf(0.25, float(mount.get("speed_bonus", 1.0)))
		if str(states.get("combat_charge_phase", "")) == "charging":
			multiplier *= maxf(1.0, float(mount.get("charge_speed_multiplier", 1.0)))
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
	elif action_text == "combat_strategy_avoid_holding":
		action_text = "避战待命"
	elif action_text == "combat_ready":
		action_text = "接敌"
	elif action_text == "meeting_assigned_horse":
		action_text = "会合马匹"
	elif action_text == "waiting_for_assigned_horse":
		action_text = "等待马匹"
	elif action_text == "planning_day":
		action_text = "制定计划"
	elif action_text.begins_with("moving_to_combat_strategy_avoid_"):
		action_text = "正在避战"
	elif action_text.begins_with("moving_to_combat_strategy_"):
		action_text = "战术移动"
	elif action_text == "keep_distance_retreating":
		action_text = "拉开距离"
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
	_dialogue_bubble_area.collision_layer = interaction_area.collision_layer if interaction_area != null else 4
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
		_mount_visual = Node3D.new()
		_mount_visual.name = "CombatMountVisual"
		_mount_visual.visible = false
		add_child(_mount_visual)
		var packed := load(COMBAT_HORSE_SCENE_PATH) as PackedScene
		var horse_model := packed.instantiate() as Node3D if packed != null else null
		if horse_model != null:
			horse_model.name = "HorseModel"
			horse_model.position = MOUNTED_PRESENTATION_REFERENCE.FRIENDLY_HORSE_ROOT_POSITION
			horse_model.scale = MOUNTED_PRESENTATION_REFERENCE.FRIENDLY_HORSE_SCALE
			_mount_visual.add_child(horse_model)
			_mount_horse_model = horse_model
			_mount_animation_player = horse_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			_mount_uses_imported_horse = true
		else:
			var fallback := MeshInstance3D.new()
			fallback.name = "FallbackMountMesh"
			var mount_mesh := BoxMesh.new()
			mount_mesh.size = Vector3(0.85, 0.28, 1.05)
			fallback.mesh = mount_mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.36, 0.22, 0.13, 1.0)
			fallback.set_surface_override_material(0, material)
			fallback.position = Vector3(0.0, 0.34, 0.0)
			_mount_visual.add_child(fallback)
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
		_refresh_combat_mount_appearance()
		_mount_visual.visible = show_combat_visuals and bool(states.get("combat_mounted", false))
		_refresh_combat_mount_animation()
	if _facing_marker != null:
		_facing_marker.visible = show_combat_visuals


func _refresh_combat_mount_appearance() -> void:
	if _mount_horse_model == null:
		return
	var equipment: Dictionary = profile.get("equipment", {}) if profile.get("equipment", {}) is Dictionary else {}
	var mount: Dictionary = equipment.get("mount", {}) if equipment.get("mount", {}) is Dictionary else {}
	var horse_id := str(mount.get("horse_id", ""))
	var coat_color := str(mount.get("horse_coat_color", "#9B6846"))
	var template_id := str(mount.get("horse_template_id", ""))
	if horse_id == _mount_applied_horse_id and coat_color == _mount_applied_coat_color and template_id == _mount_applied_template_id:
		return
	HORSE_APPEARANCE.apply_coat_color(_mount_horse_model, coat_color)
	_mount_applied_horse_id = horse_id
	_mount_applied_coat_color = coat_color
	_mount_applied_template_id = template_id


func _refresh_combat_mount_animation() -> void:
	if _mount_animation_player == null or _mount_visual == null or not _mount_visual.visible:
		return
	var suffix := "Walk" if _is_moving else "Idle"
	var clip := ""
	for raw_clip in _mount_animation_player.get_animation_list():
		var candidate := str(raw_clip)
		if candidate == suffix or candidate.ends_with("|" + suffix) or candidate.ends_with("/" + suffix):
			clip = candidate
			break
	if not clip.is_empty() and (_mount_animation_player.current_animation != clip or not _mount_animation_player.is_playing()):
		_mount_animation_player.play(clip, 0.16)
	var authored_speed := _get_locomotion_animation_speed_scale() if _is_moving else 1.0
	_mount_animation_player.speed_scale = authored_speed * _get_combat_frame_rate()


func _get_locomotion_animation_speed_scale() -> float:
	var minimum_scale := float(_locomotion_config.get("minimum_animation_speed_scale", 0.35))
	var maximum_scale := float(_locomotion_config.get("maximum_animation_speed_scale", 1.6))
	return clampf(_actual_horizontal_speed / maxf(0.01, _locomotion_reference_speed), minimum_scale, maximum_scale)


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
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	return time_system != null and time_system.is_gameplay_paused()


func _get_combat_frame_rate() -> float:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system != null and time_system.has_method("get_combat_frame_rate"):
		return maxf(0.0, float(time_system.get_combat_frame_rate()))
	return 1.0


func debug_get_character_art_snapshot() -> Dictionary:
	if _character_art_view == null or not _character_art_view.has_method("debug_get_snapshot"):
		return {
			"ready": false,
			"appearance_id": _character_appearance_id,
			"authority_role": "presentation_only"
		}
	var snapshot: Dictionary = _character_art_view.debug_get_snapshot()
	snapshot["npc_id"] = npc_id
	snapshot["combat_mount_visual_visible"] = _mount_visual != null and _mount_visual.visible
	snapshot["combat_mount_uses_imported_horse"] = _mount_uses_imported_horse
	snapshot["combat_mount_animation"] = _mount_animation_player.current_animation if _mount_animation_player != null else ""
	snapshot["combat_mount_horse_local_position"] = _mount_horse_model.position if _mount_horse_model != null else Vector3.ZERO
	snapshot["combat_mount_horse_scale"] = _mount_horse_model.scale if _mount_horse_model != null else Vector3.ZERO
	var rider_forward := Vector3(snapshot.get("visual_forward", Vector3.ZERO)).normalized()
	var horse_forward := (_mount_horse_model.global_basis * MOUNTED_PRESENTATION_REFERENCE.VISIBLE_FORWARD_LOCAL).normalized() if _mount_horse_model != null else Vector3.ZERO
	snapshot["combat_mount_horse_visible_forward"] = horse_forward
	snapshot["combat_mount_forward_dot"] = rider_forward.dot(horse_forward) if not rider_forward.is_zero_approx() and not horse_forward.is_zero_approx() else 0.0
	snapshot["locomotion_state"] = _locomotion_state
	snapshot["locomotion_reference_speed"] = _locomotion_reference_speed
	snapshot["authoritative_move_speed"] = _get_authoritative_move_speed()
	snapshot["actual_horizontal_speed"] = _actual_horizontal_speed
	snapshot["walk_speed"] = _get_walk_speed()
	snapshot["zero_satiety_walk_limited"] = _is_zero_satiety_walk_limited()
	snapshot["pending_unmounted_actual_run_seconds"] = _pending_unmounted_actual_run_seconds
	snapshot["navigation_motion_enabled"] = _navigation_motion_enabled
	snapshot["combat_mount_animation_speed_scale"] = _mount_animation_player.speed_scale if _mount_animation_player != null else 0.0
	snapshot["combat_mount_horse_id"] = _mount_applied_horse_id
	snapshot["combat_mount_template_id"] = _mount_applied_template_id
	snapshot["combat_mount_coat_color"] = _mount_applied_coat_color
	return snapshot


func debug_force_character_animation(state_name: String) -> Dictionary:
	if _character_art_view == null or not _character_art_view.has_method("debug_force_animation_state"):
		return {"ok": false, "error": "formal_character_art_not_available", "npc_id": npc_id}
	return _character_art_view.debug_force_animation_state(state_name)


func _configure_character_art_view() -> void:
	if npc_id.is_empty() or _character_art_view != null:
		return
	var appearance_config := _load_character_appearance_config()
	var characters: Dictionary = appearance_config.get("characters", {}) if appearance_config.get("characters", {}) is Dictionary else {}
	var appearance: Dictionary = characters.get(npc_id, {}) if characters.get(npc_id, {}) is Dictionary else {}
	var scene_path := str(appearance.get("scene", "")).strip_edges()
	if scene_path.is_empty():
		return
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Cannot load NPC appearance scene: %s" % scene_path)
		return
	var art_mount := get_node_or_null("ArtMount") as Node3D
	if art_mount == null:
		push_warning("NPC scene is missing ArtMount for %s." % npc_id)
		return
	_character_art_view = packed_scene.instantiate() as Node3D
	if _character_art_view == null:
		return
	art_mount.add_child(_character_art_view)
	_character_appearance_id = str(appearance.get("appearance_id", scene_path))
	var legacy_visuals := get_node_or_null("LegacyVisuals") as Node3D
	if legacy_visuals != null:
		legacy_visuals.visible = false


func _apply_profile_to_character_art() -> void:
	if _character_art_view != null and _character_art_view.has_method("apply_profile"):
		_character_art_view.apply_profile(profile)


func get_combat_projectile_release_transform(weapon_type: String) -> Transform3D:
	if _character_art_view != null and _character_art_view.has_method("get_combat_projectile_release_transform"):
		return _character_art_view.get_combat_projectile_release_transform(weapon_type)
	return Transform3D(global_basis, global_position + Vector3.UP * 1.15)


func get_combat_projectile_release_snapshot(weapon_type: String) -> Dictionary:
	if _character_art_view == null or not _character_art_view.has_method("get_combat_projectile_release_snapshot"):
		return {
			"ready": false,
			"reason": "formal_character_art_unavailable",
			"weapon_type": weapon_type,
			"source_npc_id": npc_id,
		}
	var snapshot: Dictionary = _character_art_view.get_combat_projectile_release_snapshot(weapon_type)
	snapshot["source_npc_id"] = npc_id
	return snapshot


func get_combat_melee_contact_segment(weapon_type: String) -> Dictionary:
	if _character_art_view != null and _character_art_view.has_method("get_combat_melee_contact_segment"):
		return _character_art_view.get_combat_melee_contact_segment(weapon_type)
	return {}


func _load_character_appearance_config() -> Dictionary:
	var file := FileAccess.open(CHARACTER_APPEARANCE_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_warning("Cannot open character appearance config: %s" % CHARACTER_APPEARANCE_CONFIG_PATH)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Character appearance config must contain a JSON object.")
		return {}
	return parsed
