class_name ActorMotionBody
extends CharacterBody3D

signal motion_started(request_id: String, target_position: Vector3)
signal motion_arrived(request_id: String, target_position: Vector3)
signal motion_failed(request_id: String, reason: String)
signal motion_cancelled(request_id: String, reason: String)
signal motion_repath_requested(request_id: String, repath_count: int)

const DEFAULT_CONFIG_PATH := "res://data/physics_navigation.json"
const DEFAULT_PROFILE_ID := "npc"
const NAVIGATION_MAP_SYNC_GRACE_FRAMES := 120
const STATION_LAYOUT_CONTROLLER_PATH := "/root/Main/Presentation/StationLayoutController"

@export_file("*.json") var physics_navigation_config_path := DEFAULT_CONFIG_PATH
@export var actor_profile_id := DEFAULT_PROFILE_ID
@export var avoidance_priority_override := -1.0

@onready var body_collision: CollisionShape3D = $BodyCollision
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_collision: CollisionShape3D = $InteractionArea/InteractionCollision
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var actor_mesh: MeshInstance3D = get_node_or_null("ActorMesh") as MeshInstance3D

var _config: Dictionary = {}
var _profile: Dictionary = {}
var _agent_config: Dictionary = {}
var _path_progression_config: Dictionary = {}
var _recovery_config: Dictionary = {}
var _configuration_errors: Array[String] = []
var _runtime_overrides: Dictionary = {}

var _motion_active := false
var _motion_paused := false
var _request_id := ""
var _target_position := Vector3.ZERO
var _motion_options: Dictionary = {}
var _motion_state := "idle"
var _last_result := ""
var _elapsed_seconds := 0.0
var _sample_elapsed_seconds := 0.0
var _stuck_elapsed_seconds := 0.0
var _last_sample_position := Vector3.ZERO
var _last_sample_remaining_path_distance := INF
var _last_sample_displacement := 0.0
var _last_sample_path_progress := 0.0
var _no_progress_samples := 0
var _stationary_sample_elapsed_seconds := 0.0
var _stationary_elapsed_seconds := 0.0
var _stationary_last_sample_position := Vector3.ZERO
var _stationary_last_sample_displacement := 0.0
var _stationary_supersede_preserve_count := 0
var _repath_count := 0
var _target_update_count := 0
var _path_query_frames := 0
var _planar_reachability_confirmed := false
var _avoidance_callback_count := 0
var _last_safe_velocity := Vector3.ZERO
var _safe_velocity_valid := false
var _minimum_target_distance := INF
var _maximum_observed_speed := 0.0
var _maximum_raw_safe_velocity_speed := 0.0
var _maximum_frame_displacement := 0.0
var _rvo_speed_clamp_count := 0
var _intermediate_waypoint_advance_count := 0
var _last_path_index := -1
var _last_waypoint_position := Vector3(INF, INF, INF)
var _last_waypoint_distance := INF
var _last_adaptive_waypoint_tolerance := 0.0
var _last_waypoint_shortcut_clear := false
var _last_waypoint_speed_limit := INF
var _tracked_waypoint_index := -1
var _tracked_waypoint_position := Vector3(INF, INF, INF)
var _tracked_waypoint_minimum_distance := INF
var _missed_waypoint_advance_count := 0
var _indoor_exit_prefix_points: Array[Vector3] = []
var _indoor_exit_prefix_point_ids: Array[String] = []
var _indoor_exit_prefix_index := 0
var _indoor_exit_prefix_building_id := ""
var _indoor_exit_prefix_generation_count := 0
var _indoor_exit_prefix_completed_point_count := 0
var _indoor_exit_prefix_target_update_preserved_count := 0
var _indoor_exit_prefix_last_result := ""
var _indoor_exit_prefix_forward_direction := Vector3.ZERO
var _minimum_navigation_leg_distance := INF
var _runtime_avoidance_override_reason := ""
var _runtime_actor_collision_override_reason := ""
var _world_collision_bitmask := 1
var _actor_collision_bitmask := 2
var _last_requested_speed := 0.0
var _last_desired_speed := 0.0
var _last_candidate_speed := 0.0
var _last_rvo_safe_speed := 0.0
var _last_applied_speed := 0.0
var _last_actual_speed := 0.0
var _last_speed_limit_reason := "idle"
var _last_motion_preserved_velocity := false
var _last_preserved_velocity_speed := 0.0
var _preserved_velocity_handoff_count := 0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_load_config()
	_apply_profile()
	if not navigation_agent.velocity_computed.is_connected(_on_velocity_computed):
		navigation_agent.velocity_computed.connect(_on_velocity_computed)


func configure_profile(profile_id: String, runtime_overrides: Dictionary = {}) -> bool:
	actor_profile_id = profile_id
	_runtime_overrides = runtime_overrides.duplicate(true)
	if not is_node_ready():
		return true
	_apply_profile()
	return _configuration_errors.is_empty()


func configure_avoidance_identity(identity: String, base_priority: float, spread: float = 0.08) -> float:
	# Equal RVO priorities can form a perfectly symmetric stand-off when several
	# actors converge on adjacent combat positions. A small stable identity-based
	# tie-break keeps the same path and target, but makes yielding deterministic.
	var normalized_hash := float(posmod(identity.hash(), 1001)) / 1000.0
	avoidance_priority_override = clampf(
		base_priority + (normalized_hash - 0.5) * maxf(0.0, spread),
		0.0,
		1.0
	)
	if is_node_ready() and navigation_agent != null:
		navigation_agent.avoidance_priority = avoidance_priority_override
	return avoidance_priority_override


func set_runtime_avoidance_enabled(enabled: bool, reason: String = "") -> bool:
	if not is_node_ready() or navigation_agent == null:
		return false
	_runtime_avoidance_override_reason = "" if enabled else reason
	if navigation_agent.avoidance_enabled == enabled:
		return true
	# A stale safe velocity from the previous RVO callback must not survive either
	# transition. The next physics tick recomputes velocity from the unchanged
	# navigation path, so this only changes local crowd steering authority.
	_safe_velocity_valid = false
	_last_safe_velocity = Vector3.ZERO
	navigation_agent.velocity = Vector3.ZERO
	navigation_agent.set_velocity_forced(Vector3.ZERO)
	navigation_agent.avoidance_enabled = enabled
	return true


func set_runtime_actor_collision_enabled(enabled: bool, reason: String = "") -> bool:
	if not is_node_ready():
		return false
	_runtime_actor_collision_override_reason = "" if enabled else reason
	# Stall recovery may temporarily let one moving attacker pass through allied
	# actor capsules. Static world geometry remains authoritative at all times.
	collision_mask = (
		_world_collision_bitmask | _actor_collision_bitmask
		if enabled
		else _world_collision_bitmask
	)
	return true


func request_motion(target_position: Vector3, request_id: String = "", motion_options: Dictionary = {}) -> bool:
	if not _configuration_errors.is_empty():
		_motion_state = "failed"
		_last_result = "configuration_error"
		motion_failed.emit(request_id, _last_result)
		return false
	var preserve_velocity := (
		_motion_active
		and bool(motion_options.get("preserve_velocity_on_supersede", false))
	)
	var preserve_stationary_progress := (
		_motion_active
		and bool(motion_options.get("preserve_stationary_progress_on_supersede", false))
	)
	var preserved_stationary_sample_seconds := _stationary_sample_elapsed_seconds
	var preserved_stationary_elapsed_seconds := _stationary_elapsed_seconds
	var preserved_stationary_sample_position := _stationary_last_sample_position
	var preserved_stationary_sample_displacement := _stationary_last_sample_displacement
	var preserved_velocity := Vector3(velocity.x, 0.0, velocity.z) if preserve_velocity else Vector3.ZERO
	var maximum_speed := maxf(0.0, float(_profile.get("base_speed", 5.0)))
	preserved_velocity = preserved_velocity.limit_length(maximum_speed)
	if _motion_active:
		cancel_motion("superseded")
	_request_id = request_id if not request_id.is_empty() else "motion_%d" % Time.get_ticks_msec()
	_target_position = Vector3(target_position.x, global_position.y, target_position.z)
	_motion_options = motion_options.duplicate(true)
	# Combat contact points may need a tighter final approach than ordinary work
	# movement. Keep that precision on the request so one shared ActorMotionBody
	# can serve both without changing its profile-wide navigation contract.
	navigation_agent.target_desired_distance = _get_active_target_tolerance()
	_motion_active = true
	_motion_paused = false
	_motion_state = "moving"
	_last_result = ""
	_elapsed_seconds = 0.0
	_sample_elapsed_seconds = 0.0
	_stuck_elapsed_seconds = 0.0
	_last_sample_position = global_position
	_last_sample_remaining_path_distance = _horizontal_distance(global_position, _target_position)
	_last_sample_displacement = 0.0
	_last_sample_path_progress = 0.0
	_no_progress_samples = 0
	_reset_stationary_progress_tracking()
	if preserve_stationary_progress:
		_stationary_sample_elapsed_seconds = preserved_stationary_sample_seconds
		_stationary_elapsed_seconds = preserved_stationary_elapsed_seconds
		_stationary_last_sample_position = preserved_stationary_sample_position
		_stationary_last_sample_displacement = preserved_stationary_sample_displacement
		_stationary_supersede_preserve_count += 1
	_repath_count = 0
	_target_update_count = 0
	_path_query_frames = 0
	_planar_reachability_confirmed = false
	_avoidance_callback_count = 0
	_last_safe_velocity = Vector3.ZERO
	_safe_velocity_valid = false
	_minimum_target_distance = _horizontal_distance(global_position, _target_position)
	_intermediate_waypoint_advance_count = 0
	_last_path_index = -1
	_last_waypoint_position = Vector3(INF, INF, INF)
	_last_waypoint_distance = INF
	_last_adaptive_waypoint_tolerance = 0.0
	_last_waypoint_shortcut_clear = false
	_last_waypoint_speed_limit = INF
	_reset_waypoint_tracking()
	_missed_waypoint_advance_count = 0
	_indoor_exit_prefix_generation_count = 0
	_indoor_exit_prefix_completed_point_count = 0
	_indoor_exit_prefix_target_update_preserved_count = 0
	_clear_indoor_exit_prefix("request_reset")
	_build_indoor_exit_prefix()
	_last_requested_speed = maximum_speed
	_last_desired_speed = maximum_speed
	_last_candidate_speed = preserved_velocity.length()
	_last_rvo_safe_speed = preserved_velocity.length()
	_last_applied_speed = preserved_velocity.length()
	_last_actual_speed = 0.0
	_last_motion_preserved_velocity = preserve_velocity and preserved_velocity.length_squared() > 0.0001
	_last_preserved_velocity_speed = preserved_velocity.length() if _last_motion_preserved_velocity else 0.0
	_last_speed_limit_reason = "preserved_combat_retarget_velocity" if _last_motion_preserved_velocity else "motion_started_from_rest"
	if _last_motion_preserved_velocity:
		_preserved_velocity_handoff_count += 1
	velocity = preserved_velocity
	navigation_agent.velocity = preserved_velocity
	navigation_agent.set_velocity_forced(preserved_velocity)
	_apply_active_navigation_target()
	_last_sample_remaining_path_distance = _horizontal_distance(
		global_position,
		_get_active_navigation_target()
	)
	_minimum_navigation_leg_distance = _last_sample_remaining_path_distance
	motion_started.emit(_request_id, _target_position)
	return true


func update_motion_target(
	target_position: Vector3,
	reason: String = "target_moved",
	motion_option_updates: Dictionary = {}
) -> bool:
	if not _motion_active:
		var restarted_options := _motion_options.duplicate(true)
		for raw_key in motion_option_updates.keys():
			restarted_options[raw_key] = motion_option_updates[raw_key]
		return request_motion(target_position, _request_id, restarted_options)
	var contract_changed := false
	for raw_key in motion_option_updates.keys():
		var key := str(raw_key)
		var next_value: Variant = motion_option_updates[raw_key]
		if not _motion_options.has(key) or _motion_options[key] != next_value:
			_motion_options[key] = next_value
			contract_changed = true
	if contract_changed:
		navigation_agent.target_desired_distance = _get_active_target_tolerance()
	var updated := Vector3(target_position.x, global_position.y, target_position.z)
	var minimum_change := maxf(0.01, float(_motion_options.get("target_update_distance", 0.35)))
	if _horizontal_distance(updated, _target_position) < minimum_change:
		if contract_changed:
			_apply_active_navigation_target()
			_last_result = "%s:contract_updated" % reason
		return contract_changed
	_target_position = updated
	_target_update_count += 1
	_refresh_indoor_exit_prefix_for_target_update()
	_path_query_frames = 0
	_planar_reachability_confirmed = false
	_sample_elapsed_seconds = 0.0
	_stuck_elapsed_seconds = 0.0
	_no_progress_samples = 0
	_last_sample_position = global_position
	_last_sample_remaining_path_distance = _horizontal_distance(global_position, _get_active_navigation_target())
	_reset_waypoint_tracking()
	_safe_velocity_valid = false
	navigation_agent.set_velocity_forced(Vector3.ZERO)
	_apply_active_navigation_target()
	_last_result = reason
	return true


func cancel_motion(reason: String = "cancelled") -> void:
	if not _motion_active:
		return
	var cancelled_request_id := _request_id
	_stop_physical_motion()
	_motion_active = false
	_motion_state = "cancelled"
	_last_result = reason
	_last_speed_limit_reason = "cancelled:%s" % reason
	_clear_indoor_exit_prefix("cancelled:%s" % reason)
	motion_cancelled.emit(cancelled_request_id, reason)


func set_motion_paused(paused: bool) -> void:
	# NPC and combat authorities may repeat their desired pause state every frame.
	# Treat that as an idempotent command so an unpaused actor keeps accumulating
	# the same bounded no-progress window instead of silently resetting it.
	if _motion_paused == paused:
		return
	_motion_paused = paused
	if paused:
		_stop_physical_motion()
		_motion_state = "paused" if _motion_active else _motion_state
	elif _motion_active:
		_motion_state = "moving"
		_last_sample_position = global_position
		_last_sample_remaining_path_distance = _get_remaining_navigation_distance()
		_last_sample_displacement = 0.0
		_last_sample_path_progress = 0.0
		_sample_elapsed_seconds = 0.0


func is_motion_active() -> bool:
	return _motion_active


func get_interaction_area() -> Area3D:
	return interaction_area


func set_navigation_map(navigation_map: RID) -> bool:
	if not navigation_map.is_valid() or navigation_agent == null:
		return false
	navigation_agent.set_navigation_map(navigation_map)
	return navigation_agent.get_navigation_map() == navigation_map


func get_navigation_map() -> RID:
	return navigation_agent.get_navigation_map() if navigation_agent != null else RID()


func apply_external_displacement(target_position: Vector3, reason: String = "external_displacement") -> Dictionary:
	var previous_position := global_position
	global_position = Vector3(target_position.x, target_position.y, target_position.z)
	velocity = Vector3.ZERO
	_last_safe_velocity = Vector3.ZERO
	_safe_velocity_valid = false
	_last_sample_position = global_position
	_last_sample_remaining_path_distance = (
		_get_remaining_navigation_distance()
		if _motion_active
		else INF
	)
	_last_sample_displacement = 0.0
	_last_sample_path_progress = 0.0
	_sample_elapsed_seconds = 0.0
	_stuck_elapsed_seconds = 0.0
	_no_progress_samples = 0
	_path_query_frames = 0
	_planar_reachability_confirmed = false
	_reset_waypoint_tracking()
	if _motion_active:
		_refresh_indoor_exit_prefix_after_external_displacement()
	if is_instance_valid(navigation_agent):
		navigation_agent.set_velocity_forced(Vector3.ZERO)
		if _motion_active:
			_apply_active_navigation_target()
	return {
		"ok": true,
		"reason": reason,
		"previous_position": previous_position,
		"position": global_position,
		"motion_preserved": _motion_active,
		"request_id": _request_id,
		"target_position": _target_position,
		"navigation_leg_target_position": _get_active_navigation_target(),
	}


func get_body_radius() -> float:
	var shape := body_collision.shape as CapsuleShape3D
	return shape.radius if shape != null else 0.0


func get_profile_base_speed() -> float:
	return float(_profile.get("base_speed", 0.0))


func debug_get_motion_snapshot() -> Dictionary:
	var body_shape := body_collision.shape as CapsuleShape3D
	var interaction_shape := interaction_collision.shape as CapsuleShape3D
	var path_contract := _get_path_contract_snapshot()
	return {
		"profile_id": actor_profile_id,
		"state": _motion_state,
		"active": _motion_active,
		"paused": _motion_paused,
		"request_id": _request_id,
		"target_position": _target_position,
		"navigation_leg_target_position": _get_active_navigation_target(),
		"navigation_leg_target_desired_distance": _get_active_navigation_target_tolerance(),
		"world_position": global_position,
		"velocity": velocity,
		"elapsed_seconds": _elapsed_seconds,
		"stuck_elapsed_seconds": _stuck_elapsed_seconds,
		"no_progress_samples": _no_progress_samples,
		"stationary_elapsed_seconds": _stationary_elapsed_seconds,
		"stationary_last_sample_displacement": _stationary_last_sample_displacement,
		"stationary_supersede_preserve_count": _stationary_supersede_preserve_count,
		"last_sample_displacement": _last_sample_displacement,
		"last_sample_path_progress": _last_sample_path_progress,
		"remaining_path_distance": _get_remaining_navigation_distance(),
		"minimum_target_distance": _minimum_target_distance,
		"minimum_navigation_leg_distance": _minimum_navigation_leg_distance,
		"repath_count": _repath_count,
		"target_update_count": _target_update_count,
		"target_desired_distance": _get_active_target_tolerance(),
		"persistent_repath": bool(_motion_options.get("persistent_repath", false)),
		"movement_purpose": str(_motion_options.get("movement_purpose", "general")),
		"path_plan_mode": str(path_contract.get("mode", "pending")),
		"path_length": float(path_contract.get("path_length", 0.0)),
		"direct_distance": float(path_contract.get("direct_distance", 0.0)),
		"avoidance_callback_count": _avoidance_callback_count,
		"avoidance_priority": navigation_agent.avoidance_priority,
		"avoidance_enabled": navigation_agent.avoidance_enabled,
		"avoidance_layers": navigation_agent.avoidance_layers,
		"avoidance_mask": navigation_agent.avoidance_mask,
		"runtime_avoidance_override_reason": _runtime_avoidance_override_reason,
		"navigation_max_speed": navigation_agent.max_speed,
		"profile_base_speed": float(_profile.get("base_speed", 0.0)),
		"requested_speed": _last_requested_speed,
		"desired_speed": _last_desired_speed,
		"candidate_speed": _last_candidate_speed,
		"rvo_safe_speed": _last_rvo_safe_speed,
		"applied_speed": _last_applied_speed,
		"actual_speed": _last_actual_speed,
		"speed_limit_reason": _last_speed_limit_reason,
		"final_target_braking_enabled": bool(
			_motion_options.get(
				"final_target_braking_enabled",
				_path_progression_config.get("final_target_braking_enabled", true)
			)
		),
		"preserve_velocity_on_supersede": bool(_motion_options.get("preserve_velocity_on_supersede", false)),
		"last_motion_preserved_velocity": _last_motion_preserved_velocity,
		"last_preserved_velocity_speed": _last_preserved_velocity_speed,
		"preserved_velocity_handoff_count": _preserved_velocity_handoff_count,
		"maximum_observed_speed": _maximum_observed_speed,
		"maximum_raw_safe_velocity_speed": _maximum_raw_safe_velocity_speed,
		"maximum_frame_displacement": _maximum_frame_displacement,
		"rvo_speed_clamp_count": _rvo_speed_clamp_count,
		"intermediate_waypoint_advance_count": _intermediate_waypoint_advance_count,
		"current_path_index": _last_path_index,
		"last_waypoint_position": _last_waypoint_position,
		"last_waypoint_distance": _last_waypoint_distance,
		"last_adaptive_waypoint_tolerance": _last_adaptive_waypoint_tolerance,
		"last_waypoint_shortcut_clear": _last_waypoint_shortcut_clear,
		"last_waypoint_speed_limit": _last_waypoint_speed_limit,
		"tracked_waypoint_minimum_distance": _tracked_waypoint_minimum_distance,
		"missed_waypoint_advance_count": _missed_waypoint_advance_count,
		"indoor_exit_prefix_active": _has_active_indoor_exit_prefix(),
		"indoor_exit_prefix_building_id": _indoor_exit_prefix_building_id,
		"indoor_exit_prefix_index": _indoor_exit_prefix_index,
		"indoor_exit_prefix_point_count": _indoor_exit_prefix_points.size(),
		"indoor_exit_prefix_current_point_id": _get_active_indoor_exit_prefix_point_id(),
		"indoor_exit_prefix_point_ids": _indoor_exit_prefix_point_ids.duplicate(),
		"indoor_exit_prefix_points": _indoor_exit_prefix_points.duplicate(),
		"indoor_exit_prefix_generation_count": _indoor_exit_prefix_generation_count,
		"indoor_exit_prefix_completed_point_count": _indoor_exit_prefix_completed_point_count,
		"indoor_exit_prefix_target_update_preserved_count": _indoor_exit_prefix_target_update_preserved_count,
		"indoor_exit_prefix_last_result": _indoor_exit_prefix_last_result,
		"last_result": _last_result,
		"target_reachable": (navigation_agent.is_target_reachable() or _planar_reachability_confirmed) if _path_query_frames > 0 else false,
		"navigation_finished": navigation_agent.is_navigation_finished() if _path_query_frames > 0 else false,
		"body_collision_layer": collision_layer,
		"body_collision_mask": collision_mask,
		"runtime_actor_collision_enabled": (collision_mask & _actor_collision_bitmask) != 0,
		"runtime_actor_collision_override_reason": _runtime_actor_collision_override_reason,
		"interaction_collision_layer": interaction_area.collision_layer,
		"interaction_collision_mask": interaction_area.collision_mask,
		"body_radius": body_shape.radius if body_shape != null else 0.0,
		"body_height": body_shape.height if body_shape != null else 0.0,
		"interaction_radius": interaction_shape.radius if interaction_shape != null else 0.0,
		"configuration_errors": _configuration_errors.duplicate()
	}


func get_motion_progress_snapshot() -> Dictionary:
	return {
		"active": _motion_active,
		"paused": _motion_paused,
		"request_id": _request_id,
		"target_position": _target_position,
		"world_position": global_position,
		"remaining_path_distance": _get_remaining_navigation_distance(),
		"stuck_elapsed_seconds": _stuck_elapsed_seconds,
		"stationary_elapsed_seconds": _stationary_elapsed_seconds,
		"stationary_last_sample_displacement": _stationary_last_sample_displacement,
		"stationary_supersede_preserve_count": _stationary_supersede_preserve_count,
		"no_progress_samples": _no_progress_samples,
		"repath_count": _repath_count,
		"target_update_count": _target_update_count,
		"movement_purpose": str(_motion_options.get("movement_purpose", "general")),
		"requested_speed": _last_requested_speed,
		"desired_speed": _last_desired_speed,
		"rvo_safe_speed": _last_rvo_safe_speed,
		"applied_speed": _last_applied_speed,
		"actual_speed": _last_actual_speed,
		"speed_limit_reason": _last_speed_limit_reason,
		"last_motion_preserved_velocity": _last_motion_preserved_velocity,
		"preserved_velocity_handoff_count": _preserved_velocity_handoff_count
	}


func _physics_process(delta: float) -> void:
	if not _motion_active:
		return
	if _motion_paused:
		_last_requested_speed = maxf(0.0, float(_profile.get("base_speed", 5.0)))
		_last_desired_speed = 0.0
		_last_candidate_speed = 0.0
		_last_rvo_safe_speed = 0.0
		_last_applied_speed = 0.0
		_last_actual_speed = 0.0
		_last_speed_limit_reason = "paused"
		_stop_physical_motion()
		return

	_elapsed_seconds += delta
	_path_query_frames += 1
	_advance_passed_indoor_exit_prefix_points()
	var navigation_target := _get_active_navigation_target()
	var target_distance := _horizontal_distance(global_position, navigation_target)
	_minimum_target_distance = minf(
		_minimum_target_distance,
		_horizontal_distance(global_position, _target_position)
	)
	_minimum_navigation_leg_distance = minf(_minimum_navigation_leg_distance, target_distance)
	var target_tolerance := _get_active_navigation_target_tolerance()
	if target_distance <= target_tolerance:
		if _advance_indoor_exit_prefix():
			return
		_complete_arrival()
		return

	var next_path_position := navigation_agent.get_next_path_position()
	# A newly assigned or re-enabled dedicated navigation map needs several
	# physics frames to synchronize. Keep the initial verdict separate from the
	# later bounded stuck/repath contract so fast session restarts do not become
	# false unreachable failures.
	if (
		_path_query_frames >= NAVIGATION_MAP_SYNC_GRACE_FRAMES
		and not navigation_agent.is_target_reachable()
	):
		if not _planar_reachability_confirmed:
			_planar_reachability_confirmed = _has_planar_path_to_target()
		if not _planar_reachability_confirmed:
			if bool(_motion_options.get("persistent_repath", false)):
				_repath_count += 1
				_path_query_frames = 0
				navigation_agent.target_position = _get_active_navigation_target()
				motion_repath_requested.emit(_request_id, _repath_count)
			else:
				_fail_motion("target_unreachable")
				return

	var maximum_speed := maxf(0.0, float(_profile.get("base_speed", 5.0)))
	var acceleration := maxf(0.001, float(_profile.get("acceleration", 14.0)))
	var waypoint_progress := _resolve_intermediate_waypoint_progress(
		next_path_position,
		maximum_speed,
		acceleration
	)
	next_path_position = waypoint_progress.get("next_path_position", next_path_position)
	var direction := next_path_position - global_position
	var final_segment_distance := _horizontal_distance(next_path_position, navigation_target)
	var using_direct_target := final_segment_distance <= float(_agent_config.get("path_desired_distance", 0.35)) * 1.5
	if using_direct_target:
		direction = navigation_target - global_position
	direction.y = 0.0
	var desired_speed := maximum_speed
	var speed_limit_reason := "profile_cruise"
	var waypoint_speed_limit := float(waypoint_progress.get("speed_limit", INF))
	if waypoint_speed_limit < INF:
		if waypoint_speed_limit < desired_speed - 0.001:
			speed_limit_reason = "intermediate_waypoint_braking"
		desired_speed = minf(desired_speed, waypoint_speed_limit)
	var final_target_braking_enabled := bool(
		_motion_options.get(
			"final_target_braking_enabled",
			_path_progression_config.get("final_target_braking_enabled", true)
		)
	)
	if using_direct_target and final_target_braking_enabled:
		var final_braking_speed := _get_braking_speed_limit(target_distance, target_tolerance, acceleration, maximum_speed)
		if final_braking_speed < desired_speed - 0.001:
			speed_limit_reason = "final_target_braking"
		desired_speed = minf(desired_speed, final_braking_speed)
	var desired_velocity := Vector3.ZERO
	if direction.length_squared() > 0.0001:
		desired_velocity = direction.normalized() * desired_speed
	var candidate_velocity := velocity.move_toward(desired_velocity, acceleration * delta)
	candidate_velocity.y = 0.0
	_last_requested_speed = maximum_speed
	_last_desired_speed = desired_speed
	_last_candidate_speed = candidate_velocity.length()
	if candidate_velocity.length() < desired_speed - 0.05 and speed_limit_reason == "profile_cruise":
		speed_limit_reason = "accelerating"
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = candidate_velocity
		var avoidance_target := _last_safe_velocity if _safe_velocity_valid else candidate_velocity
		avoidance_target.y = 0.0
		avoidance_target = avoidance_target.limit_length(desired_speed)
		_last_rvo_safe_speed = avoidance_target.length()
		if avoidance_target.length() < candidate_velocity.length() - 0.05:
			speed_limit_reason = "rvo_avoidance"
		avoidance_target = _constrain_avoidance_to_path(
			avoidance_target,
			desired_velocity,
			desired_speed
		)
		# RVO proposes a direction, but it must not bypass the same acceleration
		# and top-speed contract that governs ordinary character movement.
		velocity = velocity.move_toward(avoidance_target, acceleration * delta)
	else:
		_last_rvo_safe_speed = candidate_velocity.length()
		velocity = candidate_velocity
	# RVO is allowed to steer, never to override the current waypoint/final-target
	# braking speed. Limiting only to profile max speed lets a stale safe velocity
	# carry the actor straight past the point it is trying to reach.
	velocity = velocity.limit_length(desired_speed)
	var speed_before_backward_rejection := velocity.length()
	if bool(_path_progression_config.get("reject_backward_path_velocity", true)):
		velocity = _reject_backward_path_velocity(velocity, direction)
		if velocity.length() < speed_before_backward_rejection - 0.05:
			speed_limit_reason = "backward_path_velocity_rejected"
	velocity.y = 0.0
	_last_applied_speed = velocity.length()
	_maximum_observed_speed = maxf(_maximum_observed_speed, velocity.length())
	var position_before_slide := global_position
	move_and_slide()
	var actual_displacement := _horizontal_distance(position_before_slide, global_position)
	_last_actual_speed = actual_displacement / maxf(delta, 0.000001)
	if _last_actual_speed < _last_applied_speed - 0.05:
		speed_limit_reason = "physical_collision_slide"
	_last_speed_limit_reason = speed_limit_reason
	_maximum_frame_displacement = maxf(_maximum_frame_displacement, actual_displacement)

	navigation_target = _get_active_navigation_target()
	target_distance = _horizontal_distance(global_position, navigation_target)
	_minimum_target_distance = minf(
		_minimum_target_distance,
		_horizontal_distance(global_position, _target_position)
	)
	_minimum_navigation_leg_distance = minf(_minimum_navigation_leg_distance, target_distance)
	if target_distance <= target_tolerance:
		if _advance_indoor_exit_prefix():
			return
		_complete_arrival()
		return
	_update_stuck_recovery(delta)


func _update_stuck_recovery(delta: float) -> void:
	var sample_seconds := float(_recovery_config.get("sample_seconds", 0.75))
	var minimum_progress := float(_recovery_config.get("minimum_progress", 0.08))
	_update_stationary_progress(delta, sample_seconds, minimum_progress)
	_sample_elapsed_seconds += delta
	if _sample_elapsed_seconds < sample_seconds:
		return
	var sampled_duration := _sample_elapsed_seconds
	var remaining_path_distance := _get_remaining_navigation_distance()
	var path_progress := _last_sample_remaining_path_distance - remaining_path_distance
	var displacement := _horizontal_distance(_last_sample_position, global_position)
	_last_sample_displacement = displacement
	_last_sample_path_progress = path_progress
	# Physical displacement alone is not progress: a blocked RVO actor can slide
	# sideways or orbit an occupied endpoint forever. Remaining route distance is
	# the authoritative signal for whether the request is actually advancing.
	if path_progress < minimum_progress:
		_no_progress_samples += 1
		_stuck_elapsed_seconds += sampled_duration
	else:
		_no_progress_samples = 0
		_stuck_elapsed_seconds = 0.0
	_last_sample_position = global_position
	_last_sample_remaining_path_distance = remaining_path_distance
	_sample_elapsed_seconds = 0.0

	var repath_after_samples := int(_recovery_config.get("repath_after_samples", 2))
	var maximum_repaths := int(_recovery_config.get("maximum_repaths_per_target", 4))
	var persistent_repath := bool(_motion_options.get("persistent_repath", false))
	if _no_progress_samples >= repath_after_samples and (persistent_repath or _repath_count < maximum_repaths):
		_repath_count += 1
		_no_progress_samples = 0
		navigation_agent.target_position = _get_active_navigation_target()
		motion_repath_requested.emit(_request_id, _repath_count)

	if not persistent_repath and _stuck_elapsed_seconds >= float(_recovery_config.get("fail_after_seconds", 8.0)):
		_fail_motion("stuck_timeout")


func _update_stationary_progress(delta: float, sample_seconds: float, minimum_progress: float) -> void:
	_stationary_sample_elapsed_seconds += delta
	if _stationary_sample_elapsed_seconds < sample_seconds:
		return
	var sampled_duration := _stationary_sample_elapsed_seconds
	_stationary_last_sample_displacement = _horizontal_distance(
		_stationary_last_sample_position,
		global_position
	)
	if _stationary_last_sample_displacement < minimum_progress:
		_stationary_elapsed_seconds += sampled_duration
	else:
		_stationary_elapsed_seconds = 0.0
	_stationary_last_sample_position = global_position
	_stationary_sample_elapsed_seconds = 0.0


func _reset_stationary_progress_tracking() -> void:
	_stationary_sample_elapsed_seconds = 0.0
	_stationary_elapsed_seconds = 0.0
	_stationary_last_sample_position = global_position
	_stationary_last_sample_displacement = 0.0


func _get_path_contract_snapshot() -> Dictionary:
	var direct_distance := _horizontal_distance(global_position, _get_active_navigation_target())
	var path := navigation_agent.get_current_navigation_path()
	if path.is_empty():
		return {
			"mode": "pending",
			"path_length": direct_distance,
			"direct_distance": direct_distance
		}
	var path_length := _horizontal_distance(global_position, path[0])
	for index in range(1, path.size()):
		path_length += _horizontal_distance(path[index - 1], path[index])
	var direct_ratio := maxf(1.0, float(_path_progression_config.get("shortcut_path_length_ratio", 1.05)))
	var direct_margin := maxf(0.0, float(_path_progression_config.get("shortcut_path_length_margin", 0.15)))
	return {
		"mode": "direct" if path_length <= direct_distance * direct_ratio + direct_margin else "detour",
		"path_length": path_length,
		"direct_distance": direct_distance
	}


func _get_remaining_navigation_distance() -> float:
	var path := navigation_agent.get_current_navigation_path()
	if path.is_empty():
		return _horizontal_distance(global_position, _get_active_navigation_target())
	var path_index := clampi(navigation_agent.get_current_navigation_path_index(), 0, path.size() - 1)
	var remaining := _horizontal_distance(global_position, path[path_index])
	for index in range(path_index + 1, path.size()):
		remaining += _horizontal_distance(path[index - 1], path[index])
	return remaining


func _resolve_intermediate_waypoint_progress(
	initial_next_path_position: Vector3,
	maximum_speed: float,
	acceleration: float
) -> Dictionary:
	var result := {
		"next_path_position": initial_next_path_position,
		"speed_limit": INF
	}
	var path := navigation_agent.get_current_navigation_path()
	if path.is_empty():
		_last_path_index = -1
		_last_waypoint_position = Vector3(INF, INF, INF)
		_last_waypoint_distance = INF
		_last_adaptive_waypoint_tolerance = 0.0
		_last_waypoint_shortcut_clear = false
		_last_waypoint_speed_limit = INF
		_reset_waypoint_tracking()
		return result
	var path_index := clampi(navigation_agent.get_current_navigation_path_index(), 0, path.size() - 1)
	_last_path_index = path_index
	var waypoint: Vector3 = path[path_index]
	_last_waypoint_position = waypoint
	var waypoint_distance := _horizontal_distance(global_position, waypoint)
	_track_waypoint(path_index, waypoint, waypoint_distance)
	_last_waypoint_distance = waypoint_distance
	var base_tolerance := float(_agent_config.get("path_desired_distance", 0.35))
	_last_adaptive_waypoint_tolerance = base_tolerance
	_last_waypoint_shortcut_clear = false
	_last_waypoint_speed_limit = INF
	if (
		not bool(_path_progression_config.get("adaptive_waypoint_enabled", true))
		or path_index >= path.size() - 1
	):
		return result
	var current_speed := maxf(
		velocity.length(),
		_last_safe_velocity.length() if _safe_velocity_valid else 0.0
	)
	current_speed = minf(current_speed, maximum_speed)
	var stopping_distance := current_speed * current_speed / (2.0 * acceleration)
	var maximum_tolerance := maxf(
		base_tolerance,
		float(_path_progression_config.get("maximum_intermediate_tolerance", 2.2))
	)
	var adaptive_tolerance := clampf(
		navigation_agent.radius * 2.0 + stopping_distance,
		base_tolerance,
		maximum_tolerance
	)
	_last_adaptive_waypoint_tolerance = adaptive_tolerance
	# A point already inside the authoritative base radius belongs to
	# NavigationAgent's normal index advancement. Applying a zero braking speed
	# here can freeze the first synchronized path point before the server advances
	# it on the next physics tick.
	if waypoint_distance <= base_tolerance:
		return result
	var crossed_waypoint := _has_crossed_waypoint_plane(path, path_index, waypoint)
	if waypoint_distance > adaptive_tolerance and not crossed_waypoint:
		return result
	var following_waypoint: Vector3 = path[path_index + 1]
	var shortcut_clear := _is_direct_navigation_shortcut_clear(following_waypoint)
	_last_waypoint_shortcut_clear = shortcut_clear
	if shortcut_clear:
		var original_tolerance := navigation_agent.path_desired_distance
		var advance_epsilon := maxf(
			0.001,
			float(_path_progression_config.get("waypoint_advance_epsilon", 0.02))
		)
		navigation_agent.path_desired_distance = maxf(
			original_tolerance,
			waypoint_distance + advance_epsilon
		)
		var advanced_position := navigation_agent.get_next_path_position()
		navigation_agent.path_desired_distance = original_tolerance
		var advanced_index := navigation_agent.get_current_navigation_path_index()
		if advanced_index > path_index:
			_intermediate_waypoint_advance_count += advanced_index - path_index
			_last_path_index = advanced_index
			_reset_waypoint_tracking()
			result["next_path_position"] = advanced_position
			if bool(_path_progression_config.get("reset_stale_avoidance_on_advance", true)):
				_safe_velocity_valid = false
				_last_safe_velocity = Vector3.ZERO
			return result
	if crossed_waypoint or _should_advance_missed_waypoint(waypoint, waypoint_distance, adaptive_tolerance):
		var missed_advance_position := _force_advance_missed_waypoint(path_index, waypoint_distance)
		if _last_path_index > path_index:
			result["next_path_position"] = missed_advance_position
			return result
	var speed_limit := _get_braking_speed_limit(
		waypoint_distance,
		base_tolerance,
		acceleration,
		maximum_speed
	)
	_last_waypoint_speed_limit = speed_limit
	result["speed_limit"] = speed_limit
	return result


func _has_crossed_waypoint_plane(path: PackedVector3Array, path_index: int, waypoint: Vector3) -> bool:
	if path_index <= 0 or path_index >= path.size() - 1:
		return false
	var incoming := waypoint - path[path_index - 1]
	incoming.y = 0.0
	if incoming.length_squared() <= 0.0001:
		return false
	var beyond_waypoint := global_position - waypoint
	beyond_waypoint.y = 0.0
	return beyond_waypoint.dot(incoming.normalized()) > 0.1


func _track_waypoint(path_index: int, waypoint: Vector3, waypoint_distance: float) -> void:
	var waypoint_changed := (
		path_index != _tracked_waypoint_index
		or not is_finite(_tracked_waypoint_position.x)
		or _horizontal_distance(_tracked_waypoint_position, waypoint) > 0.05
	)
	if waypoint_changed:
		_tracked_waypoint_index = path_index
		_tracked_waypoint_position = waypoint
		_tracked_waypoint_minimum_distance = waypoint_distance
		return
	_tracked_waypoint_minimum_distance = minf(
		_tracked_waypoint_minimum_distance,
		waypoint_distance
	)


func _should_advance_missed_waypoint(
	waypoint: Vector3,
	waypoint_distance: float,
	adaptive_tolerance: float
) -> bool:
	if not bool(_path_progression_config.get("missed_waypoint_advance_enabled", true)):
		return false
	if _tracked_waypoint_minimum_distance > adaptive_tolerance:
		return false
	var distance_growth := maxf(
		0.05,
		float(_path_progression_config.get("missed_waypoint_distance_growth", 0.25))
	)
	if waypoint_distance < _tracked_waypoint_minimum_distance + distance_growth:
		return false
	var minimum_speed := maxf(
		0.0,
		float(_path_progression_config.get("missed_waypoint_minimum_speed", 0.5))
	)
	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if planar_velocity.length() < minimum_speed:
		return false
	var to_waypoint := waypoint - global_position
	to_waypoint.y = 0.0
	if to_waypoint.length_squared() <= 0.0001:
		return false
	# Once avoidance or inertia has carried the body past an intermediate point,
	# chasing that now-behind point is exactly what creates the visible loop. The
	# caller advances to the next point already present in the authoritative path;
	# it does not invent a building-specific route or cut directly to the target.
	return planar_velocity.dot(to_waypoint.normalized()) < 0.0


func _force_advance_missed_waypoint(path_index: int, waypoint_distance: float) -> Vector3:
	var original_tolerance := navigation_agent.path_desired_distance
	var advance_epsilon := maxf(
		0.001,
		float(_path_progression_config.get("waypoint_advance_epsilon", 0.02))
	)
	navigation_agent.path_desired_distance = maxf(original_tolerance, waypoint_distance + advance_epsilon)
	var advanced_position := navigation_agent.get_next_path_position()
	navigation_agent.path_desired_distance = original_tolerance
	var advanced_index := navigation_agent.get_current_navigation_path_index()
	if advanced_index > path_index:
		var advance_count := advanced_index - path_index
		_intermediate_waypoint_advance_count += advance_count
		_missed_waypoint_advance_count += advance_count
		_last_path_index = advanced_index
		_safe_velocity_valid = false
		_last_safe_velocity = Vector3.ZERO
		navigation_agent.set_velocity_forced(Vector3.ZERO)
		_reset_waypoint_tracking()
	return advanced_position


func _reset_waypoint_tracking() -> void:
	_tracked_waypoint_index = -1
	_tracked_waypoint_position = Vector3(INF, INF, INF)
	_tracked_waypoint_minimum_distance = INF


func _is_direct_navigation_shortcut_clear(target_position: Vector3) -> bool:
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid():
		return false
	var shortcut_path := NavigationServer3D.map_get_path(
		navigation_map,
		global_position,
		target_position,
		true
	)
	if shortcut_path.is_empty():
		return false
	var target_tolerance := _get_active_navigation_target_tolerance()
	if _horizontal_distance(shortcut_path[shortcut_path.size() - 1], target_position) > target_tolerance:
		return false
	var direct_distance := _horizontal_distance(global_position, target_position)
	if direct_distance <= 0.001:
		return true
	var shortcut_length := _horizontal_distance(global_position, shortcut_path[0])
	for index in range(1, shortcut_path.size()):
		shortcut_length += _horizontal_distance(shortcut_path[index - 1], shortcut_path[index])
	var ratio := maxf(
		1.0,
		float(_path_progression_config.get("shortcut_path_length_ratio", 1.05))
	)
	var margin := maxf(
		0.0,
		float(_path_progression_config.get("shortcut_path_length_margin", 0.15))
	)
	return shortcut_length <= direct_distance * ratio + margin


func _get_braking_speed_limit(
	distance: float,
	tolerance: float,
	acceleration: float,
	maximum_speed: float
) -> float:
	var braking_distance := maxf(0.0, distance - tolerance)
	return minf(
		maximum_speed,
		sqrt(2.0 * maxf(0.001, acceleration) * braking_distance)
	)


func _constrain_avoidance_to_path(
	avoidance_velocity: Vector3,
	desired_velocity: Vector3,
	desired_speed: float
) -> Vector3:
	var safe_speed := minf(avoidance_velocity.length(), desired_speed)
	if safe_speed <= 0.001 or desired_velocity.length_squared() <= 0.0001:
		return Vector3.ZERO
	var desired_direction := desired_velocity.normalized()
	var safe_direction := avoidance_velocity.normalized()
	var maximum_angle := deg_to_rad(clampf(
		float(_path_progression_config.get("maximum_avoidance_steering_degrees", 75.0)),
		0.0,
		89.0
	))
	var direction_dot := clampf(safe_direction.dot(desired_direction), -1.0, 1.0)
	if acos(direction_dot) <= maximum_angle:
		return safe_direction * safe_speed
	var lateral_direction := safe_direction - desired_direction * direction_dot
	lateral_direction.y = 0.0
	if lateral_direction.length_squared() <= 0.0001:
		return desired_direction * safe_speed
	var constrained_direction := (
		desired_direction * cos(maximum_angle)
		+ lateral_direction.normalized() * sin(maximum_angle)
	)
	return constrained_direction.normalized() * safe_speed


func _reject_backward_path_velocity(current_velocity: Vector3, path_direction: Vector3) -> Vector3:
	var planar_direction := Vector3(path_direction.x, 0.0, path_direction.z)
	if planar_direction.length_squared() <= 0.0001:
		return Vector3.ZERO
	var forward := planar_direction.normalized()
	var forward_speed := current_velocity.dot(forward)
	if forward_speed >= 0.0:
		return current_velocity
	return current_velocity - forward * forward_speed


func _has_planar_path_to_target() -> bool:
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid():
		return false
	var navigation_target := _get_active_navigation_target()
	var path := NavigationServer3D.map_get_path(
		navigation_map,
		global_position,
		navigation_target,
		true
	)
	if path.is_empty():
		return false
	var path_end: Vector3 = path[path.size() - 1]
	return _horizontal_distance(path_end, navigation_target) <= _get_active_navigation_target_tolerance()


func _get_active_target_tolerance() -> float:
	return maxf(
		0.01,
		float(
			_motion_options.get(
				"target_desired_distance",
				_agent_config.get("target_desired_distance", 0.25)
			)
		)
	)


func _get_active_navigation_target_tolerance() -> float:
	if not _has_active_indoor_exit_prefix():
		return _get_active_target_tolerance()
	return maxf(
		_get_active_target_tolerance(),
		float(_agent_config.get("path_desired_distance", 0.35))
	)


func _get_active_navigation_target() -> Vector3:
	if _has_active_indoor_exit_prefix():
		return _indoor_exit_prefix_points[_indoor_exit_prefix_index]
	return _target_position


func _has_active_indoor_exit_prefix() -> bool:
	return (
		not _indoor_exit_prefix_building_id.is_empty()
		and _indoor_exit_prefix_index >= 0
		and _indoor_exit_prefix_index < _indoor_exit_prefix_points.size()
	)


func _get_active_indoor_exit_prefix_point_id() -> String:
	if (
		_has_active_indoor_exit_prefix()
		and _indoor_exit_prefix_index < _indoor_exit_prefix_point_ids.size()
	):
		return _indoor_exit_prefix_point_ids[_indoor_exit_prefix_index]
	return ""


func _get_station_layout_controller() -> Node:
	return get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)


func _build_indoor_exit_prefix() -> bool:
	var station_layout := _get_station_layout_controller()
	if (
		station_layout == null
		or not station_layout.has_method("get_indoor_exit_navigation_prefix")
	):
		return false
	var body_shape := body_collision.shape as CapsuleShape3D
	var reached_tolerance := maxf(
		0.45,
		(body_shape.radius if body_shape != null else 0.35) + 0.10
	)
	var prefix: Dictionary = station_layout.get_indoor_exit_navigation_prefix(
		global_position,
		_target_position,
		reached_tolerance
	)
	if prefix.is_empty():
		return false
	var raw_points: Array = prefix.get("points", [])
	var raw_point_ids: Array = prefix.get("point_ids", [])
	for raw_point in raw_points:
		if raw_point is Vector3:
			_indoor_exit_prefix_points.append(raw_point)
	var point_index := 0
	for raw_point_id in raw_point_ids:
		if point_index >= _indoor_exit_prefix_points.size():
			break
		_indoor_exit_prefix_point_ids.append(str(raw_point_id))
		point_index += 1
	while _indoor_exit_prefix_point_ids.size() < _indoor_exit_prefix_points.size():
		_indoor_exit_prefix_point_ids.append("point_%02d" % _indoor_exit_prefix_point_ids.size())
	if _indoor_exit_prefix_points.is_empty():
		_clear_indoor_exit_prefix("empty_prefix")
		return false
	_indoor_exit_prefix_index = 0
	_indoor_exit_prefix_building_id = str(prefix.get("building_id", ""))
	_indoor_exit_prefix_forward_direction = prefix.get("exit_forward_direction", Vector3.ZERO)
	_indoor_exit_prefix_forward_direction.y = 0.0
	if _indoor_exit_prefix_forward_direction.length_squared() > 0.0001:
		_indoor_exit_prefix_forward_direction = _indoor_exit_prefix_forward_direction.normalized()
	_indoor_exit_prefix_generation_count += 1
	_indoor_exit_prefix_last_result = "active"
	return not _indoor_exit_prefix_building_id.is_empty()


func _refresh_indoor_exit_prefix_for_target_update() -> void:
	var station_layout := _get_station_layout_controller()
	if _has_active_indoor_exit_prefix():
		if (
			station_layout != null
			and station_layout.has_method("is_world_position_inside_enterable_building")
			and station_layout.is_world_position_inside_enterable_building(
				_indoor_exit_prefix_building_id,
				_target_position
			)
		):
			_clear_indoor_exit_prefix("target_returned_inside")
			return
		# The fixed door route does not depend on which outdoor target is moving.
		# Keep its current stage and only let update_motion_target replace the final
		# target; rebuilding here used to reset laterally displaced actors to an
		# earlier indoor point and produced visible U-turns at every building door.
		_indoor_exit_prefix_target_update_preserved_count += 1
		_indoor_exit_prefix_last_result = "target_updated_prefix_preserved:%s" % _get_active_indoor_exit_prefix_point_id()
		return
	_clear_indoor_exit_prefix("target_update_rebuild")
	_build_indoor_exit_prefix()


func _refresh_indoor_exit_prefix_after_external_displacement() -> void:
	if not _has_active_indoor_exit_prefix():
		_build_indoor_exit_prefix()
		return
	var station_layout := _get_station_layout_controller()
	if (
		station_layout != null
		and station_layout.has_method("is_world_position_inside_enterable_building")
		and not station_layout.is_world_position_inside_enterable_building(
			_indoor_exit_prefix_building_id,
			global_position
		)
	):
		_clear_indoor_exit_prefix("external_displacement_left_building")
		return
	_clear_indoor_exit_prefix("external_displacement_rebuild")
	_build_indoor_exit_prefix()


func _apply_active_navigation_target() -> void:
	if not is_instance_valid(navigation_agent):
		return
	navigation_agent.target_desired_distance = _get_active_navigation_target_tolerance()
	navigation_agent.target_position = _get_active_navigation_target()


func _advance_passed_indoor_exit_prefix_points() -> bool:
	if (
		not _has_active_indoor_exit_prefix()
		or _indoor_exit_prefix_forward_direction.length_squared() <= 0.5
	):
		return false
	var body_shape := body_collision.shape as CapsuleShape3D
	var pass_margin := maxf(0.08, (body_shape.radius if body_shape != null else 0.35) * 0.18)
	var advanced := false
	while _has_active_indoor_exit_prefix():
		var current_point := _indoor_exit_prefix_points[_indoor_exit_prefix_index]
		var outward_progress := global_position - current_point
		outward_progress.y = 0.0
		if outward_progress.dot(_indoor_exit_prefix_forward_direction) < pass_margin:
			break
		_advance_indoor_exit_prefix()
		advanced = true
	return advanced


func _advance_indoor_exit_prefix() -> bool:
	if not _has_active_indoor_exit_prefix():
		return false
	_indoor_exit_prefix_completed_point_count += 1
	_indoor_exit_prefix_index += 1
	_path_query_frames = 0
	_planar_reachability_confirmed = false
	_sample_elapsed_seconds = 0.0
	_stuck_elapsed_seconds = 0.0
	_no_progress_samples = 0
	_reset_stationary_progress_tracking()
	_last_sample_position = global_position
	_reset_waypoint_tracking()
	_safe_velocity_valid = false
	navigation_agent.set_velocity_forced(Vector3.ZERO)
	if _has_active_indoor_exit_prefix():
		_indoor_exit_prefix_last_result = "advanced:%s" % _get_active_indoor_exit_prefix_point_id()
	else:
		_indoor_exit_prefix_last_result = "completed"
		_indoor_exit_prefix_building_id = ""
	_apply_active_navigation_target()
	_last_sample_remaining_path_distance = _horizontal_distance(
		global_position,
		_get_active_navigation_target()
	)
	_minimum_navigation_leg_distance = _last_sample_remaining_path_distance
	return true


func _clear_indoor_exit_prefix(reason: String) -> void:
	_indoor_exit_prefix_points.clear()
	_indoor_exit_prefix_point_ids.clear()
	_indoor_exit_prefix_index = 0
	_indoor_exit_prefix_building_id = ""
	_indoor_exit_prefix_forward_direction = Vector3.ZERO
	_indoor_exit_prefix_last_result = reason


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not _motion_active or _motion_paused:
		return
	var planar_safe_velocity := Vector3(safe_velocity.x, 0.0, safe_velocity.z)
	var maximum_speed := maxf(0.0, float(_profile.get("base_speed", 5.0)))
	_maximum_raw_safe_velocity_speed = maxf(_maximum_raw_safe_velocity_speed, planar_safe_velocity.length())
	if planar_safe_velocity.length() > maximum_speed + 0.001:
		_rvo_speed_clamp_count += 1
	_last_safe_velocity = planar_safe_velocity.limit_length(maximum_speed)
	_safe_velocity_valid = true
	_avoidance_callback_count += 1


func _complete_arrival() -> void:
	var completed_request_id := _request_id
	_stop_physical_motion()
	_motion_active = false
	_motion_state = "arrived"
	_last_result = "arrived"
	_last_speed_limit_reason = "arrived"
	_clear_indoor_exit_prefix("arrived")
	motion_arrived.emit(completed_request_id, _target_position)


func _fail_motion(reason: String) -> void:
	var failed_request_id := _request_id
	_stop_physical_motion()
	_motion_active = false
	_motion_state = "failed"
	_last_result = reason
	_last_speed_limit_reason = "failed:%s" % reason
	_clear_indoor_exit_prefix("failed:%s" % reason)
	motion_failed.emit(failed_request_id, reason)


func _stop_physical_motion() -> void:
	velocity = Vector3.ZERO
	_last_safe_velocity = Vector3.ZERO
	_safe_velocity_valid = false
	_last_desired_speed = 0.0
	_last_candidate_speed = 0.0
	_last_rvo_safe_speed = 0.0
	_last_applied_speed = 0.0
	_last_actual_speed = 0.0
	if is_instance_valid(navigation_agent):
		navigation_agent.velocity = Vector3.ZERO
		navigation_agent.set_velocity_forced(Vector3.ZERO)


func _load_config() -> void:
	_configuration_errors.clear()
	if not FileAccess.file_exists(physics_navigation_config_path):
		_configuration_errors.append("config_missing:%s" % physics_navigation_config_path)
		return
	var file := FileAccess.open(physics_navigation_config_path, FileAccess.READ)
	if file == null:
		_configuration_errors.append("config_open_failed:%s" % physics_navigation_config_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_configuration_errors.append("config_invalid_json")
		return
	_config = parsed
	if str(_config.get("schema_version", "")) != "physics_navigation_v1":
		_configuration_errors.append("config_schema_mismatch")


func _apply_profile() -> void:
	if _config.is_empty():
		_load_config()
	var profiles: Dictionary = _config.get("actor_profiles", {})
	if not profiles.has(actor_profile_id):
		_configuration_errors.append("profile_missing:%s" % actor_profile_id)
		return
	_profile = (profiles.get(actor_profile_id, {}) as Dictionary).duplicate(true)
	for raw_key in _runtime_overrides.get("profile", {}).keys():
		_profile[raw_key] = (_runtime_overrides.get("profile", {}) as Dictionary)[raw_key]
	_agent_config = (_config.get("navigation_agent", {}) as Dictionary).duplicate(true)
	for raw_key in _runtime_overrides.get("navigation_agent", {}).keys():
		_agent_config[raw_key] = (_runtime_overrides.get("navigation_agent", {}) as Dictionary)[raw_key]
	_path_progression_config = (_config.get("path_progression", {}) as Dictionary).duplicate(true)
	_recovery_config = (_config.get("stuck_recovery", {}) as Dictionary).duplicate(true)
	for raw_key in _runtime_overrides.get("stuck_recovery", {}).keys():
		_recovery_config[raw_key] = (_runtime_overrides.get("stuck_recovery", {}) as Dictionary)[raw_key]

	var radius := float(_profile.get("radius", 0.0))
	var height := float(_profile.get("height", 0.0))
	if radius <= 0.0 or height < radius * 2.0:
		_configuration_errors.append("invalid_profile_shape:%s" % actor_profile_id)
		return
	var layers: Dictionary = _config.get("collision_layers", {})
	var actor_layer := int((layers.get("actor_body", {}) as Dictionary).get("bitmask", 2))
	var world_layer := int((layers.get("world_static", {}) as Dictionary).get("bitmask", 1))
	var interaction_layer := int((layers.get("interaction", {}) as Dictionary).get("bitmask", 4))
	_actor_collision_bitmask = actor_layer
	_world_collision_bitmask = world_layer
	_runtime_actor_collision_override_reason = ""
	collision_layer = actor_layer
	collision_mask = world_layer | actor_layer
	safe_margin = float((_config.get("structural_collision", {}) as Dictionary).get("collision_margin", 0.04))
	interaction_area.collision_layer = interaction_layer
	interaction_area.collision_mask = 0
	interaction_area.monitoring = false
	interaction_area.monitorable = true

	_configure_capsule(body_collision, radius, height)
	_configure_capsule(interaction_collision, radius + 0.06, height)
	if actor_mesh != null and actor_mesh.mesh is CapsuleMesh:
		var capsule_mesh := actor_mesh.mesh.duplicate() as CapsuleMesh
		capsule_mesh.radius = radius
		capsule_mesh.height = height
		actor_mesh.mesh = capsule_mesh
		actor_mesh.position.y = height * 0.5

	navigation_agent.path_desired_distance = float(_agent_config.get("path_desired_distance", 0.35))
	navigation_agent.target_desired_distance = float(_agent_config.get("target_desired_distance", 0.25))
	navigation_agent.path_height_offset = float(_agent_config.get("path_height_offset", 0.0))
	# RVO needs a small predictive buffer beyond the physical capsule. Without it,
	# simultaneous CharacterBody moves can enter each other's safe margins before
	# move_and_slide resolves the next actor, causing visible depenetration pops.
	navigation_agent.radius = radius + maxf(0.0, float(_agent_config.get("avoidance_radius_padding", 0.0)))
	navigation_agent.height = height
	navigation_agent.max_speed = float(_profile.get("base_speed", 5.0))
	navigation_agent.neighbor_distance = float(_agent_config.get("neighbor_distance", 3.5))
	navigation_agent.max_neighbors = int(_agent_config.get("max_neighbors", 10))
	navigation_agent.time_horizon_agents = float(_agent_config.get("time_horizon_agents", 0.9))
	navigation_agent.time_horizon_obstacles = float(_agent_config.get("time_horizon_obstacles", 1.0))
	navigation_agent.avoidance_priority = (
		avoidance_priority_override
		if avoidance_priority_override >= 0.0
		else float(_agent_config.get("avoidance_priority_npc", 0.5))
	)
	# RVO is a same-side crowd tool. Opposing combatants must close to their real
	# attack handoff range instead of treating one another as pedestrians that
	# should begin yielding several metres early. CharacterBody collision remains
	# shared, so this does not permit either side to pass through an opponent.
	navigation_agent.avoidance_layers = int(
		_profile.get("avoidance_layers", _agent_config.get("avoidance_layers", 1))
	)
	navigation_agent.avoidance_mask = int(
		_profile.get("avoidance_mask", _agent_config.get("avoidance_mask", 1))
	)
	navigation_agent.use_3d_avoidance = bool(_agent_config.get("use_3d_avoidance", false))
	navigation_agent.avoidance_enabled = bool(_agent_config.get("avoidance_enabled", true))


func _configure_capsule(collision_shape: CollisionShape3D, radius: float, height: float) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	collision_shape.shape = capsule
	collision_shape.position.y = height * 0.5


func _horizontal_distance(from_position: Vector3, to_position: Vector3) -> float:
	return Vector2(from_position.x, from_position.z).distance_to(Vector2(to_position.x, to_position.z))
