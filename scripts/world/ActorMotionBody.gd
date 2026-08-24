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
var _recovery_config: Dictionary = {}
var _configuration_errors: Array[String] = []
var _runtime_overrides: Dictionary = {}

var _motion_active := false
var _motion_paused := false
var _request_id := ""
var _target_position := Vector3.ZERO
var _motion_state := "idle"
var _last_result := ""
var _elapsed_seconds := 0.0
var _sample_elapsed_seconds := 0.0
var _stuck_elapsed_seconds := 0.0
var _last_sample_position := Vector3.ZERO
var _no_progress_samples := 0
var _repath_count := 0
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


func request_motion(target_position: Vector3, request_id: String = "") -> bool:
	if not _configuration_errors.is_empty():
		_motion_state = "failed"
		_last_result = "configuration_error"
		motion_failed.emit(request_id, _last_result)
		return false
	if _motion_active:
		cancel_motion("superseded")
	_request_id = request_id if not request_id.is_empty() else "motion_%d" % Time.get_ticks_msec()
	_target_position = Vector3(target_position.x, global_position.y, target_position.z)
	_motion_active = true
	_motion_paused = false
	_motion_state = "moving"
	_last_result = ""
	_elapsed_seconds = 0.0
	_sample_elapsed_seconds = 0.0
	_stuck_elapsed_seconds = 0.0
	_last_sample_position = global_position
	_no_progress_samples = 0
	_repath_count = 0
	_path_query_frames = 0
	_planar_reachability_confirmed = false
	_avoidance_callback_count = 0
	_last_safe_velocity = Vector3.ZERO
	_safe_velocity_valid = false
	_minimum_target_distance = _horizontal_distance(global_position, _target_position)
	velocity = Vector3.ZERO
	navigation_agent.set_velocity_forced(Vector3.ZERO)
	navigation_agent.target_position = _target_position
	motion_started.emit(_request_id, _target_position)
	return true


func cancel_motion(reason: String = "cancelled") -> void:
	if not _motion_active:
		return
	var cancelled_request_id := _request_id
	_stop_physical_motion()
	_motion_active = false
	_motion_state = "cancelled"
	_last_result = reason
	motion_cancelled.emit(cancelled_request_id, reason)


func set_motion_paused(paused: bool) -> void:
	_motion_paused = paused
	if paused:
		_stop_physical_motion()
		_motion_state = "paused" if _motion_active else _motion_state
	elif _motion_active:
		_motion_state = "moving"
		_last_sample_position = global_position
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


func debug_get_motion_snapshot() -> Dictionary:
	var body_shape := body_collision.shape as CapsuleShape3D
	var interaction_shape := interaction_collision.shape as CapsuleShape3D
	return {
		"profile_id": actor_profile_id,
		"state": _motion_state,
		"active": _motion_active,
		"paused": _motion_paused,
		"request_id": _request_id,
		"target_position": _target_position,
		"world_position": global_position,
		"velocity": velocity,
		"elapsed_seconds": _elapsed_seconds,
		"stuck_elapsed_seconds": _stuck_elapsed_seconds,
		"minimum_target_distance": _minimum_target_distance,
		"repath_count": _repath_count,
		"avoidance_callback_count": _avoidance_callback_count,
		"navigation_max_speed": navigation_agent.max_speed,
		"profile_base_speed": float(_profile.get("base_speed", 0.0)),
		"maximum_observed_speed": _maximum_observed_speed,
		"maximum_raw_safe_velocity_speed": _maximum_raw_safe_velocity_speed,
		"maximum_frame_displacement": _maximum_frame_displacement,
		"rvo_speed_clamp_count": _rvo_speed_clamp_count,
		"last_result": _last_result,
		"target_reachable": (navigation_agent.is_target_reachable() or _planar_reachability_confirmed) if _path_query_frames > 0 else false,
		"navigation_finished": navigation_agent.is_navigation_finished() if _path_query_frames > 0 else false,
		"body_collision_layer": collision_layer,
		"body_collision_mask": collision_mask,
		"interaction_collision_layer": interaction_area.collision_layer,
		"interaction_collision_mask": interaction_area.collision_mask,
		"body_radius": body_shape.radius if body_shape != null else 0.0,
		"body_height": body_shape.height if body_shape != null else 0.0,
		"interaction_radius": interaction_shape.radius if interaction_shape != null else 0.0,
		"configuration_errors": _configuration_errors.duplicate()
	}


func _physics_process(delta: float) -> void:
	if not _motion_active:
		return
	if _motion_paused:
		_stop_physical_motion()
		return

	_elapsed_seconds += delta
	_path_query_frames += 1
	var target_distance := _horizontal_distance(global_position, _target_position)
	_minimum_target_distance = minf(_minimum_target_distance, target_distance)
	var target_tolerance := float(_agent_config.get("target_desired_distance", 0.25))
	if target_distance <= target_tolerance:
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
			_fail_motion("target_unreachable")
			return

	var direction := next_path_position - global_position
	var final_segment_distance := _horizontal_distance(next_path_position, _target_position)
	if final_segment_distance <= float(_agent_config.get("path_desired_distance", 0.35)) * 1.5:
		direction = _target_position - global_position
	direction.y = 0.0
	var desired_velocity := Vector3.ZERO
	if direction.length_squared() > 0.0001:
		desired_velocity = direction.normalized() * float(_profile.get("base_speed", 5.0))
	var maximum_speed := maxf(0.0, float(_profile.get("base_speed", 5.0)))
	var acceleration := float(_profile.get("acceleration", 14.0))
	var candidate_velocity := velocity.move_toward(desired_velocity, acceleration * delta)
	candidate_velocity.y = 0.0
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = candidate_velocity
		var avoidance_target := _last_safe_velocity if _safe_velocity_valid else candidate_velocity
		avoidance_target.y = 0.0
		avoidance_target = avoidance_target.limit_length(maximum_speed)
		# RVO proposes a direction, but it must not bypass the same acceleration
		# and top-speed contract that governs ordinary character movement.
		velocity = velocity.move_toward(avoidance_target, acceleration * delta)
	else:
		velocity = candidate_velocity
	velocity = velocity.limit_length(maximum_speed)
	velocity.y = 0.0
	_maximum_observed_speed = maxf(_maximum_observed_speed, velocity.length())
	var position_before_slide := global_position
	move_and_slide()
	_maximum_frame_displacement = maxf(_maximum_frame_displacement, _horizontal_distance(position_before_slide, global_position))

	target_distance = _horizontal_distance(global_position, _target_position)
	_minimum_target_distance = minf(_minimum_target_distance, target_distance)
	if target_distance <= target_tolerance:
		_complete_arrival()
		return
	_update_stuck_recovery(delta)


func _update_stuck_recovery(delta: float) -> void:
	_sample_elapsed_seconds += delta
	var sample_seconds := float(_recovery_config.get("sample_seconds", 0.75))
	if _sample_elapsed_seconds < sample_seconds:
		return
	var sampled_duration := _sample_elapsed_seconds
	var progress := _horizontal_distance(_last_sample_position, global_position)
	var minimum_progress := float(_recovery_config.get("minimum_progress", 0.08))
	if progress < minimum_progress:
		_no_progress_samples += 1
		_stuck_elapsed_seconds += sampled_duration
	else:
		_no_progress_samples = 0
		_stuck_elapsed_seconds = 0.0
	_last_sample_position = global_position
	_sample_elapsed_seconds = 0.0

	var repath_after_samples := int(_recovery_config.get("repath_after_samples", 2))
	var maximum_repaths := int(_recovery_config.get("maximum_repaths_per_target", 4))
	if _no_progress_samples >= repath_after_samples and _repath_count < maximum_repaths:
		_repath_count += 1
		_no_progress_samples = 0
		navigation_agent.target_position = _target_position
		motion_repath_requested.emit(_request_id, _repath_count)

	if _stuck_elapsed_seconds >= float(_recovery_config.get("fail_after_seconds", 8.0)):
		_fail_motion("stuck_timeout")


func _has_planar_path_to_target() -> bool:
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid():
		return false
	var path := NavigationServer3D.map_get_path(
		navigation_map,
		global_position,
		_target_position,
		true
	)
	if path.is_empty():
		return false
	var path_end: Vector3 = path[path.size() - 1]
	return _horizontal_distance(path_end, _target_position) <= float(_agent_config.get("target_desired_distance", 0.25))


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
	motion_arrived.emit(completed_request_id, _target_position)


func _fail_motion(reason: String) -> void:
	var failed_request_id := _request_id
	_stop_physical_motion()
	_motion_active = false
	_motion_state = "failed"
	_last_result = reason
	motion_failed.emit(failed_request_id, reason)


func _stop_physical_motion() -> void:
	velocity = Vector3.ZERO
	_last_safe_velocity = Vector3.ZERO
	_safe_velocity_valid = false
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
	navigation_agent.avoidance_layers = int(_agent_config.get("avoidance_layers", 1))
	navigation_agent.avoidance_mask = int(_agent_config.get("avoidance_mask", 1))
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
