class_name NPCArtView
extends Node3D


const REQUIRED_STATES := [
	"idle",
	"walk",
	"run",
	"talk",
	"work",
	"training_instructor",
	"training_practice",
	"mass_leader",
	"seated_prayer",
	"seated_eating",
	"attack",
	"hit_react",
	"unconscious",
	"get_up",
	"vehicle_seated"
]
const LOOPING_STATES := ["idle", "walk", "run", "talk", "work", "training_instructor", "training_practice", "mass_leader", "seated_prayer", "seated_eating", "vehicle_seated"]
const STATE_CLIPS := {
	"idle": "Idle_FoldArms",
	"walk": "Walk_Carry",
	# Standard 免费库没有独立 run；同一非 root-motion 步态加速播放，保留统一状态名供后续替换。
	"run": "Walk_Carry",
	"talk": "Idle_Rail_Call",
	# Farm_Harvest 是免费库中最接近双手向下锤击节奏的循环片段。
	"work": "Farm_Harvest",
	# 教官用持续招呼/示范手势，学员用无伤害事实的循环挥剑；两者只表达训练，不触发战斗结算。
	"training_instructor": "Idle_Rail_Call",
	"training_practice": "Sword_Regular_A",
	# Standard 免费库没有礼拜专用片段；主持使用持续宣讲手势，祈祷者使用稳定扶栏姿态并由长凳锚点下沉为坐姿。
	"mass_leader": "Idle_Rail_Call",
	"seated_prayer": "Idle_Rail",
	# Consume 提供稳定的手到口循环；座位锚点和局部下沉共同形成低模坐姿进食表现。
	"seated_eating": "Consume",
	"attack": "Sword_Regular_A",
	"hit_react": "Hit_Knockback",
	# 免费库只有 LayToIdle；反播用于倒地，正播用于起身。
	"unconscious": "LayToIdle",
	"get_up": "LayToIdle",
	# 免费库没有真正的坐姿；扶栏循环能让上身前倾、双臂稳定伸向缰绳。
	"vehicle_seated": "Idle_Rail"
}
const SOCKET_BONES := {
	"RightHand": "hand_r",
	"LeftHand": "hand_l",
	"Back": "spine_03",
	"Head": "Head",
	"Body": "spine_02",
	"Mount": "pelvis"
}
const DEFAULT_STATE := "idle"
const HIT_REACT_SECONDS := 0.55
const GET_UP_SECONDS := 1.25
const DAMAGE_FLASH_SECONDS := 0.28
const SEATED_PRAYER_POSE_OFFSET := Vector3(0.0, -0.60, 0.08)
const SEATED_EATING_POSE_OFFSET := Vector3(0.0, -0.60, 0.08)

@export var character_rim: Material
@export var appearance_id := "glen_blacksmith_v1"
@export var outfit_tint := Color(0.78, 0.63, 0.42, 1.0)
@export var hair_tint := Color(0.16, 0.09, 0.05, 1.0)
@export_range(0.01, 1.0, 0.01) var facing_turn_speed := 0.22
@export var show_smith_hammer := true
@export var vehicle_seated_pose := false

@onready var _character_pivot: Node3D = $CharacterPivot
@onready var _source_facing_correction: Node3D = $CharacterPivot/SourceFacingCorrection
@onready var _rig_source: Node3D = $CharacterPivot/SourceFacingCorrection/RigSource
@onready var _base_model: Node3D = $CharacterPivot/SourceFacingCorrection/BaseModel
@onready var _outfit_model: Node3D = $CharacterPivot/SourceFacingCorrection/OutfitModel
@onready var _hair_model: Node3D = $CharacterPivot/SourceFacingCorrection/HairModel
@onready var _animation_tree: AnimationTree = $AnimationTree
@onready var _equipment_sockets: Node3D = $EquipmentSockets
@onready var _hammer: Node3D = $ToolVisuals/SmithHammer

var _profile: Dictionary = {}
var _rig_skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _playback: AnimationNodeStateMachinePlayback
var _current_state := DEFAULT_STATE
var _desired_state := DEFAULT_STATE
var _is_moving := false
var _movement_speed := 0.0
var _movement_activation_count := 0
var _last_locomotion_state := ""
var _target_yaw := 0.0
var _target_facing_direction := Vector3(0.0, 0.0, -1.0)
var _previous_hp := -1
var _previous_unconscious := false
var _transient_state := ""
var _transient_remaining := 0.0
var _rebound_mesh_count := 0
var _physical_bone_simulator: PhysicalBoneSimulator3D
var _animation_paused := false
var _blood_particles: GPUParticles3D
var _damage_flash_remaining := 0.0
var _damage_feedback_count := 0
var _hit_offset := Vector3.ZERO
var _hit_velocity := Vector3.ZERO
var _vehicle_pose_applied := false


func _ready() -> void:
	_rig_skeleton = _rig_source.find_child("Skeleton3D", true, false) as Skeleton3D
	_animation_player = _rig_source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_hide_animation_mannequin()
	_configure_sockets()
	_rebound_mesh_count = 0
	_rebind_character_meshes(_base_model, Color.WHITE)
	_rebind_character_meshes(_outfit_model, outfit_tint)
	_rebind_character_meshes(_hair_model, hair_tint)
	_ensure_ragdoll_placeholder()
	_configure_combat_feedback()
	_configure_animation_tree()
	_place_hammer(false)
	_apply_profile_state(true)
	if vehicle_seated_pose:
		set_vehicle_seated_pose(true)
	set_process(true)


func apply_profile(npc_profile: Dictionary) -> void:
	var states: Dictionary = npc_profile.get("states", {}) if npc_profile.get("states", {}) is Dictionary else {}
	var next_hp := int(states.get("hp", _previous_hp if _previous_hp >= 0 else 0))
	var next_unconscious := bool(states.get("unconscious", false))
	var was_initialized := _previous_hp >= 0
	var took_damage := was_initialized and next_hp < _previous_hp
	var damage_amount := _previous_hp - next_hp if took_damage else 0
	var revived := was_initialized and _previous_unconscious and not next_unconscious

	_profile = npc_profile.duplicate(true)
	_previous_hp = next_hp
	_previous_unconscious = next_unconscious
	if took_damage:
		_trigger_damage_feedback(damage_amount, next_unconscious)

	if next_unconscious:
		_start_transient("", 0.0)
	elif revived:
		_start_transient("get_up", GET_UP_SECONDS)
	elif took_damage:
		_start_transient("hit_react", HIT_REACT_SECONDS)
	_apply_profile_state(false)


func set_movement_active(active: bool, world_speed: float = 0.0) -> void:
	if active and not _is_moving:
		_movement_activation_count += 1
	_is_moving = active
	_movement_speed = maxf(0.0, world_speed)
	_apply_profile_state(false)
	if active:
		_last_locomotion_state = _desired_state


func set_facing_direction(direction: Vector3) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return
	flat_direction = flat_direction.normalized()
	_target_facing_direction = flat_direction
	_target_yaw = atan2(-flat_direction.x, -flat_direction.z)


func get_visible_forward() -> Vector3:
	if _character_pivot == null:
		return _target_facing_direction
	return -_character_pivot.global_basis.z.normalized()


func set_selected(selected: bool) -> void:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return
	for raw_mesh in _all_character_meshes():
		var mesh_instance := raw_mesh as MeshInstance3D
		if _mesh_has_material(mesh_instance):
			mesh_instance.set_instance_shader_parameter("selection_strength", 1.0 if selected else 0.0)


func _mesh_has_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null:
		return false
	if mesh_instance.material_override != null:
		return true
	var mesh := mesh_instance.mesh
	if mesh == null:
		return false
	for surface_index in range(mesh.get_surface_count()):
		if mesh.surface_get_material(surface_index) != null:
			return true
	return false


func set_vehicle_seated_pose(enabled: bool) -> void:
	vehicle_seated_pose = enabled
	if _animation_tree == null or _rig_skeleton == null:
		return
	if not enabled:
		_vehicle_pose_applied = false
		_animation_tree.active = true
		_apply_profile_state(true)
		return
	# UAL2 Standard 不含真正的坐姿。车夫使用专用扶栏循环，加上场景中的
	# 下沉角色根、座板和挡腿板组成俯视角可读的驾驶坐姿；仅影响表现层。
	_animation_tree.active = true
	_desired_state = "vehicle_seated"
	_transition_to("vehicle_seated", true)
	_vehicle_pose_applied = _get_playback_state() == "vehicle_seated"


func debug_force_animation_state(state_name: String) -> Dictionary:
	if not REQUIRED_STATES.has(state_name):
		return {"ok": false, "error": "unknown_animation_state", "state": state_name}
	_start_transient(state_name, 0.0)
	_desired_state = state_name
	_transition_to(state_name, true)
	_place_hammer(state_name == "work")
	if _animation_player != null:
		_animation_player.speed_scale = 1.45 if state_name == "run" else 1.0
	return debug_get_snapshot()


func debug_get_snapshot() -> Dictionary:
	var socket_snapshot := {}
	for raw_name in SOCKET_BONES.keys():
		var socket_name := str(raw_name)
		var socket := _equipment_sockets.get_node_or_null(socket_name) as BoneAttachment3D
		socket_snapshot[socket_name] = {
			"present": socket != null,
			"bone": socket.bone_name if socket != null else ""
		}
	var available_clips: Array[String] = []
	if _animation_player != null:
		for raw_animation in _animation_player.get_animation_list():
			available_clips.append(str(raw_animation))
	return {
		"ready": _rig_skeleton != null and _animation_player != null and _playback != null,
		"appearance_id": appearance_id,
		"current_state": _get_playback_state(),
		"desired_state": _desired_state,
		"logical_moving": _is_moving,
		"movement_speed": _movement_speed,
		"movement_activation_count": _movement_activation_count,
		"last_locomotion_state": _last_locomotion_state,
		"visual_forward": -_character_pivot.global_basis.z.normalized(),
		"target_facing_direction": _target_facing_direction,
		"source_facing_correction_degrees": rad_to_deg(_source_facing_correction.rotation.y),
		"work_cycle_position": _playback.get_current_play_position() if _playback != null and _get_playback_state() == "work" else -1.0,
		"work_cycle_length": _animation_player.get_animation(str(STATE_CLIPS.work)).length if _animation_player != null and _animation_player.has_animation(str(STATE_CLIPS.work)) else 0.0,
		"work_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.work)),
		"training_instructor_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.training_instructor)),
		"training_practice_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.training_practice)),
		"mass_leader_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.mass_leader)),
		"seated_prayer_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.seated_prayer)),
		"seated_eating_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.seated_eating)),
		"presentation_pose_offset": _get_presentation_pose_offset(),
		"state_contract": REQUIRED_STATES.duplicate(),
		"state_clips": STATE_CLIPS.duplicate(true),
		"available_clips": available_clips,
		"socket_contract": socket_snapshot,
		"rebound_mesh_count": _rebound_mesh_count,
		"hammer_parent": str(_hammer.get_parent().name) if _hammer != null and _hammer.get_parent() != null else "",
		"hammer_visible": _hammer != null and _hammer.visible,
		"ragdoll_placeholder_ready": _physical_bone_simulator != null,
		"blood_vfx_ready": _blood_particles != null,
		"blood_vfx_emitting": _blood_particles != null and _blood_particles.emitting,
		"damage_feedback_count": _damage_feedback_count,
		"vehicle_seated_pose": vehicle_seated_pose,
		"vehicle_pose_applied": _vehicle_pose_applied,
		"damage_flash_remaining": _damage_flash_remaining,
		"fall_feedback_mode": "animated_fall_with_physics_impulse",
		"authority_role": "presentation_only"
	}


func _process(delta: float) -> void:
	var gameplay_paused := _is_gameplay_paused()
	if vehicle_seated_pose:
		_animation_tree.active = not gameplay_paused
		if not gameplay_paused and _get_playback_state() != "vehicle_seated":
			_transition_to("vehicle_seated", true)
		_vehicle_pose_applied = _get_playback_state() == "vehicle_seated"
		if gameplay_paused:
			return
		_update_combat_feedback(delta)
		return
	if gameplay_paused != _animation_paused:
		_animation_paused = gameplay_paused
		_animation_tree.active = not gameplay_paused
		if not gameplay_paused:
			_transition_to(_desired_state, true)
	if gameplay_paused:
		return
	_update_combat_feedback(delta)
	_character_pivot.rotation.y = lerp_angle(
		_character_pivot.rotation.y,
		_target_yaw,
		clampf(delta / maxf(0.01, facing_turn_speed), 0.0, 1.0)
	)
	if not _transient_state.is_empty() and _transient_remaining > 0.0:
		_transient_remaining = maxf(0.0, _transient_remaining - delta)
		if is_zero_approx(_transient_remaining):
			_transient_state = ""
			_apply_profile_state(false)


func _apply_profile_state(reset: bool) -> void:
	if _playback == null:
		return
	var next_state := _resolve_animation_state()
	_desired_state = next_state
	_transition_to(next_state, reset)
	var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
	var current_action := str(states.get("current_action", ""))
	_place_hammer(next_state == "work" and current_action == "work_blacksmith")
	if _hammer != null and current_action == "receive_weapon_training":
		_hammer.visible = false
	if _animation_player != null:
		if next_state == "run":
			_animation_player.speed_scale = 1.45
		elif next_state == "walk":
			_animation_player.speed_scale = clampf(_movement_speed / 3.2, 0.85, 1.35)
		else:
			_animation_player.speed_scale = 1.0


func _resolve_animation_state() -> String:
	var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
	if bool(states.get("unconscious", false)):
		return "unconscious"
	if not _transient_state.is_empty():
		return _transient_state
	if _is_moving:
		var behavior_mode := str(states.get("behavior_mode", ""))
		return "run" if _movement_speed > 5.5 or ["combat", "avoid_combat", "escaped"].has(behavior_mode) else "walk"
	var current_action := str(states.get("current_action", "idle"))
	if current_action == "work_training_instructor":
		return "training_instructor"
	if current_action == "receive_weapon_training":
		return "training_practice"
	if current_action == "lead_mass":
		return "mass_leader"
	if current_action == "pray_at_chapel":
		return "seated_prayer"
	if current_action == "eat_at_dining_hall":
		return "seated_eating"
	if current_action in ["work_blacksmith", "work_stable", "work_workshop", "work_dining_hall", "work_garden", "work_tavern", "work_clinic_doctor"]:
		return "work"
	if current_action.begins_with("attacking_") or current_action.begins_with("winding_up_"):
		return "attack"
	if ["talk_to_npc", "proactive_talk", "escape_intervention_dialogue"].has(current_action):
		return "talk"
	return DEFAULT_STATE


func _transition_to(state_name: String, reset: bool = false) -> void:
	if _playback == null or not REQUIRED_STATES.has(state_name):
		return
	if _current_state == state_name and not reset:
		return
	if reset or not _playback.is_playing():
		_playback.start(StringName(state_name), true)
	else:
		_playback.travel(StringName(state_name), true)
	_current_state = state_name


func _start_transient(state_name: String, duration: float) -> void:
	_transient_state = state_name
	_transient_remaining = maxf(0.0, duration)


func _configure_animation_tree() -> void:
	if _animation_player == null:
		push_warning("NPCArtView requires an AnimationPlayer in RigSource.")
		return
	_make_animation_libraries_instance_local()
	var available := _animation_player.get_animation_list()
	var state_machine := AnimationNodeStateMachine.new()
	var column := 0
	for raw_state in REQUIRED_STATES:
		var state_name := str(raw_state)
		var clip_name := str(STATE_CLIPS.get(state_name, ""))
		if not available.has(StringName(clip_name)):
			push_warning("NPCArtView missing animation clip: %s -> %s" % [state_name, clip_name])
			continue
		var animation_node := AnimationNodeAnimation.new()
		animation_node.animation = StringName(clip_name)
		animation_node.loop_mode = Animation.LOOP_LINEAR if LOOPING_STATES.has(state_name) else Animation.LOOP_NONE
		if state_name == "unconscious":
			animation_node.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
		state_machine.add_node(StringName(state_name), animation_node, Vector2(160.0 * column, 90.0 * (column % 2)))
		column += 1
	for raw_from in REQUIRED_STATES:
		var from_state := str(raw_from)
		if not state_machine.has_node(StringName(from_state)):
			continue
		for raw_to in REQUIRED_STATES:
			var to_state := str(raw_to)
			if from_state == to_state or not state_machine.has_node(StringName(to_state)):
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = 0.12
			state_machine.add_transition(StringName(from_state), StringName(to_state), transition)
	_animation_tree.anim_player = _animation_tree.get_path_to(_animation_player)
	_animation_tree.tree_root = state_machine
	_animation_tree.active = true
	_playback = _animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if _playback != null:
		_playback.start(DEFAULT_STATE, true)


func _make_animation_libraries_instance_local() -> void:
	for raw_library_name in _animation_player.get_animation_library_list():
		var library_name := str(raw_library_name)
		var source_library := _animation_player.get_animation_library(library_name)
		if source_library == null:
			continue
		var local_library := AnimationLibrary.new()
		for raw_animation_name in source_library.get_animation_list():
			var animation_name := str(raw_animation_name)
			var source_animation := source_library.get_animation(animation_name)
			if source_animation == null:
				continue
			var local_animation := source_animation.duplicate(true) as Animation
			if _is_looping_clip(animation_name):
				local_animation.loop_mode = Animation.LOOP_LINEAR
			local_library.add_animation(StringName(animation_name), local_animation)
		_animation_player.remove_animation_library(StringName(library_name))
		_animation_player.add_animation_library(StringName(library_name), local_library)


func _is_looping_clip(animation_name: String) -> bool:
	for raw_state in LOOPING_STATES:
		if str(STATE_CLIPS.get(str(raw_state), "")) == animation_name:
			return true
	return false


func _get_clip_loop_mode(animation_name: String) -> int:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return -1
	return int(_animation_player.get_animation(animation_name).loop_mode)


func _configure_sockets() -> void:
	if _rig_skeleton == null:
		push_warning("NPCArtView requires a compatible Skeleton3D.")
		return
	for raw_name in SOCKET_BONES.keys():
		var socket_name := str(raw_name)
		var socket := _equipment_sockets.get_node_or_null(socket_name) as BoneAttachment3D
		if socket == null:
			continue
		socket.use_external_skeleton = true
		socket.external_skeleton = socket.get_path_to(_rig_skeleton)
		socket.bone_name = str(SOCKET_BONES[socket_name])


func _rebind_character_meshes(model_root: Node, tint: Color) -> void:
	if _rig_skeleton == null or model_root == null:
		return
	for raw_mesh in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		mesh_instance.skeleton = mesh_instance.get_path_to(_rig_skeleton)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.material_overlay = character_rim
		_rebound_mesh_count += 1
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_active_material(surface_index)
			if not source_material is BaseMaterial3D:
				continue
			var material_copy := source_material.duplicate() as BaseMaterial3D
			material_copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			material_copy.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			if tint != Color.WHITE:
				material_copy.albedo_color *= tint
			mesh_instance.set_surface_override_material(surface_index, material_copy)


func _hide_animation_mannequin() -> void:
	for raw_mesh in _rig_source.find_children("*", "MeshInstance3D", true, false):
		(raw_mesh as MeshInstance3D).visible = false


func _ensure_ragdoll_placeholder() -> void:
	if _rig_skeleton == null:
		return
	_physical_bone_simulator = PhysicalBoneSimulator3D.new()
	_physical_bone_simulator.name = "PhysicalBoneSimulator3D"
	_rig_skeleton.add_child(_physical_bone_simulator)


func _configure_combat_feedback() -> void:
	var center_mass := get_node_or_null("VFXMounts/CenterMass") as Marker3D
	if center_mass == null:
		return
	_blood_particles = GPUParticles3D.new()
	_blood_particles.name = "BloodBurst"
	_blood_particles.amount = 24
	_blood_particles.lifetime = 0.72
	_blood_particles.one_shot = true
	_blood_particles.explosiveness = 0.96
	_blood_particles.randomness = 0.82
	_blood_particles.visibility_aabb = AABB(Vector3(-2.2, -2.2, -2.2), Vector3(4.4, 4.4, 4.4))
	var particle_process := ParticleProcessMaterial.new()
	particle_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_process.emission_sphere_radius = 0.1
	particle_process.direction = Vector3(0.0, 0.35, 1.0)
	particle_process.spread = 72.0
	particle_process.initial_velocity_min = 1.2
	particle_process.initial_velocity_max = 2.8
	particle_process.gravity = Vector3(0.0, -5.5, 0.0)
	particle_process.damping_min = 1.2
	particle_process.damping_max = 2.2
	particle_process.scale_min = 0.6
	particle_process.scale_max = 1.35
	_blood_particles.process_material = particle_process
	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.028
	droplet_mesh.height = 0.08
	var blood_material := StandardMaterial3D.new()
	blood_material.albedo_color = Color(0.42, 0.006, 0.004, 1.0)
	blood_material.roughness = 0.68
	droplet_mesh.material = blood_material
	_blood_particles.draw_pass_1 = droplet_mesh
	center_mass.add_child(_blood_particles)


func _trigger_damage_feedback(damage_amount: int, became_unconscious: bool) -> void:
	_damage_feedback_count += 1
	_damage_flash_remaining = DAMAGE_FLASH_SECONDS
	if _blood_particles != null:
		_blood_particles.amount_ratio = clampf(0.45 + float(damage_amount) / 40.0, 0.45, 1.0)
		_blood_particles.restart()
		_blood_particles.emitting = true
	var impact_direction := Vector3(
		_target_facing_direction.x,
		0.0,
		_target_facing_direction.z
	).normalized()
	if impact_direction.length_squared() <= 0.0001:
		impact_direction = Vector3.FORWARD
	_hit_velocity += -impact_direction * (2.6 if became_unconscious else 1.5)
	_hit_velocity.y += 0.9 if became_unconscious else 0.45


func _update_combat_feedback(delta: float) -> void:
	_damage_flash_remaining = maxf(0.0, _damage_flash_remaining - delta)
	var spring_strength := 32.0
	_hit_velocity += -_hit_offset * spring_strength * delta
	_hit_velocity *= exp(-8.5 * delta)
	_hit_offset += _hit_velocity * delta
	if _previous_unconscious:
		_hit_offset.y = maxf(_hit_offset.y, 0.0)
	_character_pivot.position = _hit_offset + _get_presentation_pose_offset()
	var settle_roll := deg_to_rad(-7.0) if _previous_unconscious else 0.0
	var settle_pitch := deg_to_rad(5.0) if _previous_unconscious else 0.0
	_character_pivot.rotation.x = lerp_angle(
		_character_pivot.rotation.x,
		settle_pitch + clampf(_hit_offset.z * 0.18, -0.16, 0.16),
		clampf(delta * 8.0, 0.0, 1.0)
	)
	_character_pivot.rotation.z = lerp_angle(
		_character_pivot.rotation.z,
		settle_roll - clampf(_hit_offset.x * 0.22, -0.2, 0.2),
		clampf(delta * 8.0, 0.0, 1.0)
	)


func _get_presentation_pose_offset() -> Vector3:
	if _desired_state == "seated_prayer":
		return SEATED_PRAYER_POSE_OFFSET
	if _desired_state == "seated_eating":
		return SEATED_EATING_POSE_OFFSET
	return Vector3.ZERO


func _place_hammer(in_right_hand: bool) -> void:
	if _hammer == null:
		return
	_hammer.visible = show_smith_hammer
	if not show_smith_hammer:
		return
	var socket_name := "RightHand" if in_right_hand else "Back"
	var socket := _equipment_sockets.get_node_or_null(socket_name) as BoneAttachment3D
	if socket == null:
		return
	if _hammer.get_parent() != socket:
		_hammer.reparent(socket, false)
	if in_right_hand:
		_hammer.position = Vector3(0.02, 0.02, -0.02)
		_hammer.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	else:
		_hammer.position = Vector3(0.05, 0.03, 0.16)
		_hammer.rotation_degrees = Vector3(8.0, 0.0, 28.0)


func _all_character_meshes() -> Array:
	var result: Array = []
	for root_node in [_base_model, _outfit_model, _hair_model]:
		if root_node == null:
			continue
		result.append_array(root_node.find_children("*", "MeshInstance3D", true, false))
	return result


func _get_playback_state() -> String:
	if _playback == null:
		return _current_state
	return str(_playback.get_current_node())


func _is_gameplay_paused() -> bool:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	return time_system != null and time_system.has_method("is_gameplay_paused") and time_system.is_gameplay_paused()
