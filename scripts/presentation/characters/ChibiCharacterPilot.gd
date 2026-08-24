class_name ChibiCharacterPilot
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
	"seated_study",
	"seated_eating",
	"attack",
	"medical_treatment",
	"hit_react",
	"unconscious",
	"get_up",
	"vehicle_seated",
	"sleeping",
]
const LOOPING_STATES := [
	"idle", "walk", "run", "talk", "work", "training_instructor",
	"training_practice", "mass_leader", "seated_prayer", "seated_study", "seated_eating",
	"medical_treatment", "vehicle_seated", "sleeping",
]
const EXTRA_LOOPING_CLIPS := [
	"Working_A", "Working_B", "Working_C", "Digging",
	"Ranged_Magic_Spellcasting_Long", "Ranged_Magic_Raise",
]
const GARDEN_HOE_SHAFT_DIRECTION := Vector3(-0.564863, -0.173648, -0.806707)
const ENGINEER_GOGGLES_FOREHEAD_MODEL_POSITION := Vector3(0.0, 1.69, 0.275)
const ENGINEER_GOGGLES_WORN_MODEL_POSITION := Vector3(0.0, 1.52, 0.292)
const ENGINEER_GOGGLES_WORN_SCALE := Vector3(1.18, 1.08, 1.0)
const ENGINEER_GOGGLES_TRANSITION_SECONDS := 0.16
const STATE_CLIPS := {
	"idle": "Idle_A",
	"walk": "Walking_A",
	"run": "Running_A",
	"talk": "Waving",
	"work": "Hammering",
	"training_instructor": "Melee_Block_Attack",
	"training_practice": "Melee_1H_Attack_Slice_Diagonal",
	"mass_leader": "Waving",
	"seated_prayer": "Sit_Chair_Idle",
	"seated_study": "Sit_Chair_Idle",
	"seated_eating": "Use_Item",
	"attack": "Melee_1H_Attack_Slice_Horizontal",
	"medical_treatment": "Working_A",
	"hit_react": "Hit_A",
	"unconscious": "Death_A",
	"get_up": "Lie_StandUp",
	"vehicle_seated": "Sit_Chair_Idle",
	"sleeping": "Lie_Idle",
}
const ANIMATION_SCENE_PATHS: PackedStringArray = [
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_MovementBasic.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_MovementAdvanced.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_General.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_Simulation.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_Special.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_Tools.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_CombatMelee.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_CombatRanged.glb",
]
const SOURCE_RIG_SCENE_PATH := "res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_MovementBasic.glb"
const SOURCE_SKELETON_NODE_PATH := "SourceRig/Rig_Medium/Skeleton3D"
const EQUIPMENT_SCENES := {
	"hammer": "res://assets/3d/synty/t0130_pilot/Prop_Hammer_01.fbx",
	"stable_broom": "res://assets/3d/synty/t0130_pilot/Prop_Broom_01.fbx",
	"sword": "res://assets/3d/synty/t0130_pilot/Prop_Sword_01.fbx",
	"shield": "res://assets/3d/synty/t0130_pilot/Prop_ShieldKnight_01.fbx",
}
const KAYKIT_BONE_MAP := {
	"root": "Root",
	"hips": "Hips",
	"spine": "Spine",
	"chest": "Chest",
	"head": "Head",
	"upperarm.l": "LeftUpperArm",
	"lowerarm.l": "LeftLowerArm",
	"hand.l": "LeftHand",
	"upperleg.l": "LeftUpperLeg",
	"lowerleg.l": "LeftLowerLeg",
	"foot.l": "LeftFoot",
	"toes.l": "LeftToes",
	"upperarm.r": "RightUpperArm",
	"lowerarm.r": "RightLowerArm",
	"hand.r": "RightHand",
	"upperleg.r": "RightUpperLeg",
	"lowerleg.r": "RightLowerLeg",
	"foot.r": "RightFoot",
	"toes.r": "RightToes",
}
const SYNTY_BONE_MAP := {
	"root": "Root",
	"pelvis": "Hips",
	"spine_01": "Spine",
	"spine_02": "Chest",
	"spine_03": "UpperChest",
	"neck_01": "Neck",
	"head": "Head",
	"clavicle_l": "LeftShoulder",
	"upperarm_l": "LeftUpperArm",
	"lowerarm_l": "LeftLowerArm",
	"hand_l": "LeftHand",
	"thigh_l": "LeftUpperLeg",
	"calf_l": "LeftLowerLeg",
	"foot_l": "LeftFoot",
	"ball_l": "LeftToes",
	"clavicle_r": "RightShoulder",
	"upperarm_r": "RightUpperArm",
	"lowerarm_r": "RightLowerArm",
	"hand_r": "RightHand",
	"thigh_r": "RightUpperLeg",
	"calf_r": "RightLowerLeg",
	"foot_r": "RightFoot",
	"ball_r": "RightToes",
}
const SOCKET_BONES := {
	"RightHand": "RightHand",
	"LeftHand": "LeftHand",
	"Back": "UpperChest",
	"Head": "Head",
	"Body": "Chest",
	"Mount": "Hips",
}
const DEFAULT_STATE := "idle"
const HIT_REACT_SECONDS := 0.55
const GET_UP_SECONDS := 1.25
const SEATED_POSE_OFFSET := Vector3(0.0, -0.48, 0.06)
# Synty Mini characters face local +Z, while the project movement contract uses
# local -Z as forward. Keep this correction separate from runtime target yaw.
const MODEL_FORWARD_CORRECTION_Y := PI
const PALETTE_GRADE_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D palette : source_color, filter_nearest_mipmap_anisotropic;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float value_scale : hint_range(0.25, 1.25) = 1.0;

void fragment() {
	vec4 sampled = texture(palette, UV);
	float luma = dot(sampled.rgb, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(vec3(luma), sampled.rgb, saturation) * value_scale;
	ROUGHNESS = 0.82;
	SPECULAR = 0.28;
	ALPHA = sampled.a;
}
"""

@export var character_scene: PackedScene
@export var palette_texture: Texture2D
@export_enum("none", "hammer", "stable_broom", "cook_spoon", "garden_hoe", "medical_kit", "engineering_kit", "sword_shield", "synced_sword_shield") var equipment_mode := "none"
@export var use_imported_character_material := false
@export_enum(
	"idle", "walk", "run", "talk", "work", "training_instructor",
	"training_practice", "mass_leader", "seated_prayer", "seated_study", "seated_eating",
	"attack", "medical_treatment", "hit_react", "unconscious", "get_up", "vehicle_seated", "sleeping"
) var initial_state := "idle"
@export_range(0.25, 2.0, 0.01) var playback_speed := 1.0
@export var appearance_id := "t0130_chibi_pilot"
@export var work_clip := "Hammering"
@export var mass_leader_clip := "Waving"
@export var medical_treatment_clip := "Working_A"
@export var remove_detached_headwear := false
@export var show_wooden_cross := false
@export var show_rounded_tonsure_hair := false
@export_range(0.01, 1.0, 0.01) var facing_turn_speed := 0.10
@export_range(0.0, 1.0, 0.01) var palette_saturation := 1.0
@export_range(0.25, 1.25, 0.01) var palette_value_scale := 1.0
@export_range(-1.0, 0.0, 0.01) var seated_pose_offset_y := SEATED_POSE_OFFSET.y

var _source_skeleton: Skeleton3D
var _target_skeleton: Skeleton3D
var _retarget_modifier: RetargetModifier3D
var _animation_player: AnimationPlayer
var _visual_root: Node3D
var _current_state := ""
var _current_clip := ""
var _desired_state := DEFAULT_STATE
var _ready_ok := false
var _material: Material
var _profile: Dictionary = {}
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
var _debug_forced_state := ""
var _animation_paused := false
var _equipment_sockets: Dictionary = {}
var _equipment_nodes: Dictionary = {}
var _engineer_goggles_forehead_transform := Transform3D.IDENTITY
var _engineer_goggles_worn_transform := Transform3D.IDENTITY
var _engineer_goggles_mode := "forehead"
var _engineer_goggles_tween: Tween
var _authority_main_weapon_id := ""
var _spatial_attachment_pose := ""
var _target_mesh_count := 0
var _physical_bone_simulator: PhysicalBoneSimulator3D
var _blood_particles: GPUParticles3D
var _damage_feedback_count := 0
var _hit_offset := Vector3.ZERO
var _hit_velocity := Vector3.ZERO
var _removed_headwear_triangle_count := 0
var _wooden_cross: Node3D
var _rounded_tonsure_hair: Node3D

static var _shared_animation_library: AnimationLibrary


func _ready() -> void:
	_ready_ok = _build_pilot()
	if _ready_ok:
		_play_state(initial_state, true)
		set_process(true)


func _build_pilot() -> bool:
	if character_scene == null or palette_texture == null:
		push_error("T0130 pilot is missing character_scene or palette_texture")
		return false
	var source_scene := load(SOURCE_RIG_SCENE_PATH) as PackedScene
	if source_scene == null:
		push_error("T0130 pilot could not load KayKit source rig")
		return false
	var source_root := source_scene.instantiate() as Node3D
	source_root.name = "SourceRig"
	add_child(source_root)
	_visual_root = source_root
	_visual_root.rotation.y = MODEL_FORWARD_CORRECTION_Y
	_source_skeleton = source_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if _source_skeleton == null:
		push_error("T0130 pilot source Skeleton3D was not found")
		return false
	_remove_source_meshes(source_root)
	_rename_bones(_source_skeleton, KAYKIT_BONE_MAP)

	_retarget_modifier = RetargetModifier3D.new()
	_retarget_modifier.name = "RealtimeRetarget"
	_retarget_modifier.profile = SkeletonProfileHumanoid.new()
	# Preserve Synty's own bone lengths. Global-pose transfer visibly compresses this
	# character because KayKit and Synty use different proportions and helper bones.
	_retarget_modifier.use_global_pose = false
	_retarget_modifier.set_scale_enabled(false)
	_source_skeleton.add_child(_retarget_modifier)

	var target_root := character_scene.instantiate() as Node3D
	target_root.name = "TargetImport"
	add_child(target_root)
	_target_skeleton = target_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if _target_skeleton == null:
		push_error("T0130 pilot target Skeleton3D was not found")
		return false
	# RetargetModifier3D caches direct child bone indices when the target enters it.
	# Rename both Skin binds and Skeleton bones before reparenting so that cache is valid.
	_remap_skin_bind_names(_target_skeleton, SYNTY_BONE_MAP)
	_rename_bones(_target_skeleton, SYNTY_BONE_MAP)
	_target_skeleton.reparent(_retarget_modifier, false)
	target_root.queue_free()
	_target_skeleton.name = "TargetSkeleton"
	if remove_detached_headwear:
		_remove_detached_headwear_recursive(_target_skeleton)
	_apply_palette(_target_skeleton)
	_configure_socket_contract()
	_configure_identity_accessories()
	_configure_equipment()
	_configure_feedback()
	_build_animation_library()
	return _animation_player != null and _animation_player.get_animation_list().size() > 0


func _rename_bones(skeleton: Skeleton3D, bone_map: Dictionary) -> void:
	for bone_index in skeleton.get_bone_count():
		var source_name := String(skeleton.get_bone_name(bone_index))
		if bone_map.has(source_name):
			skeleton.set_bone_name(bone_index, StringName(bone_map[source_name]))


func _remove_source_meshes(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			child.free()
		else:
			_remove_source_meshes(child)


func _remap_skin_bind_names(root: Node, bone_map: Dictionary) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		if mesh_instance.skin != null:
			var remapped_skin := mesh_instance.skin.duplicate(true) as Skin
			for bind_index in remapped_skin.get_bind_count():
				var source_name := String(remapped_skin.get_bind_name(bind_index))
				if bone_map.has(source_name):
					remapped_skin.set_bind_name(bind_index, StringName(bone_map[source_name]))
			mesh_instance.skin = remapped_skin
	for child in root.get_children():
		_remap_skin_bind_names(child, bone_map)


func _apply_palette(root: Node) -> void:
	if palette_saturation < 0.999 or not is_equal_approx(palette_value_scale, 1.0):
		var shader := Shader.new()
		shader.code = PALETTE_GRADE_SHADER
		var graded_material := ShaderMaterial.new()
		graded_material.resource_name = "T0130PilotPaletteGraded"
		graded_material.shader = shader
		graded_material.set_shader_parameter("palette", palette_texture)
		graded_material.set_shader_parameter("saturation", palette_saturation)
		graded_material.set_shader_parameter("value_scale", palette_value_scale)
		_material = graded_material
	else:
		var standard_material := StandardMaterial3D.new()
		standard_material.resource_name = "T0130PilotPalette"
		standard_material.albedo_texture = palette_texture
		standard_material.roughness = 0.82
		standard_material.metallic_specular = 0.28
		_material = standard_material
	if use_imported_character_material:
		_apply_imported_character_material_recursive(root)
	else:
		_apply_material_recursive(root, _material)


func _apply_imported_character_material_recursive(root: Node) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		var imported_material := mesh_instance.mesh.surface_get_material(0) if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0 else null
		if imported_material is BaseMaterial3D:
			var preserved_material := imported_material.duplicate(true) as BaseMaterial3D
			preserved_material.resource_name = "T0130ImportedCharacterPalette"
			preserved_material.albedo_texture = palette_texture
			var imported_tint := preserved_material.albedo_color
			imported_tint.r *= palette_value_scale
			imported_tint.g *= palette_value_scale
			imported_tint.b *= palette_value_scale
			preserved_material.albedo_color = imported_tint
			preserved_material.roughness = 0.82
			mesh_instance.material_override = preserved_material
		else:
			mesh_instance.material_override = null
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_target_mesh_count += 1
	for child in root.get_children():
		_apply_imported_character_material_recursive(child)


func _apply_material_recursive(root: Node, material: Material) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_target_mesh_count += 1
	for child in root.get_children():
		_apply_material_recursive(child, material)


func _remove_detached_headwear_recursive(root: Node) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		var source_mesh := mesh_instance.mesh as ArrayMesh
		if source_mesh != null:
			var filtered_mesh := _build_mesh_without_detached_headwear(source_mesh)
			if filtered_mesh != null:
				mesh_instance.mesh = filtered_mesh
	for child in root.get_children():
		_remove_detached_headwear_recursive(child)


func _build_mesh_without_detached_headwear(source_mesh: ArrayMesh) -> ArrayMesh:
	# The purchased Synty source combines accessories and body into one skinned
	# MeshInstance3D. Accessories are still detached topology islands. Strip only
	# a large island entirely above the face; skin weights and authored face/body
	# vertices remain byte-for-byte equivalent in the rebuilt surface arrays.
	if source_mesh.get_blend_shape_count() > 0:
		return null
	var rebuilt := ArrayMesh.new()
	var removed_any := false
	for surface_index in source_mesh.get_surface_count():
		var arrays := source_mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var result := _filter_detached_headwear_indices(vertices, indices)
		var filtered_indices: PackedInt32Array = result.get("indices", indices)
		var removed_triangles := int(result.get("removed_triangles", 0))
		if removed_triangles > 0:
			arrays[Mesh.ARRAY_INDEX] = filtered_indices
			removed_any = true
			_removed_headwear_triangle_count += removed_triangles
		rebuilt.add_surface_from_arrays(source_mesh.surface_get_primitive_type(surface_index), arrays)
		rebuilt.surface_set_material(surface_index, source_mesh.surface_get_material(surface_index))
		rebuilt.surface_set_name(surface_index, source_mesh.surface_get_name(surface_index))
	return rebuilt if removed_any else null


func _filter_detached_headwear_indices(vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	if vertices.is_empty() or indices.size() < 3:
		return {"indices": indices, "removed_triangles": 0}
	var parent: Array[int] = []
	parent.resize(vertices.size())
	for vertex_index in vertices.size():
		parent[vertex_index] = vertex_index
	for triangle_start in range(0, indices.size(), 3):
		_component_union(parent, indices[triangle_start], indices[triangle_start + 1])
		_component_union(parent, indices[triangle_start], indices[triangle_start + 2])
	var coincident_vertices := {}
	for vertex_index in vertices.size():
		var vertex := vertices[vertex_index]
		var key := Vector3i(
			roundi(vertex.x * 10000.0),
			roundi(vertex.y * 10000.0),
			roundi(vertex.z * 10000.0)
		)
		if coincident_vertices.has(key):
			_component_union(parent, vertex_index, int(coincident_vertices[key]))
		else:
			coincident_vertices[key] = vertex_index
	var components := {}
	for vertex_index in vertices.size():
		var root := _component_find(parent, vertex_index)
		var entry: Dictionary = components.get(root, {
			"count": 0,
			"min": vertices[vertex_index],
			"max": vertices[vertex_index],
		})
		entry["count"] = int(entry["count"]) + 1
		entry["min"] = (entry["min"] as Vector3).min(vertices[vertex_index])
		entry["max"] = (entry["max"] as Vector3).max(vertices[vertex_index])
		components[root] = entry
	var removed_roots := {}
	for raw_root in components.keys():
		var entry: Dictionary = components[raw_root]
		var minimum := entry["min"] as Vector3
		var maximum := entry["max"] as Vector3
		var span := maximum - minimum
		if int(entry["count"]) >= 100 and minimum.y >= 1.40 and maximum.y >= 1.75 and maxf(span.x, span.z) >= 0.40:
			removed_roots[raw_root] = true
	if removed_roots.is_empty():
		return {"indices": indices, "removed_triangles": 0}
	var filtered := PackedInt32Array()
	var removed_triangles := 0
	for triangle_start in range(0, indices.size(), 3):
		var root := _component_find(parent, indices[triangle_start])
		if removed_roots.has(root):
			removed_triangles += 1
			continue
		filtered.append(indices[triangle_start])
		filtered.append(indices[triangle_start + 1])
		filtered.append(indices[triangle_start + 2])
	return {"indices": filtered, "removed_triangles": removed_triangles}


func _component_find(parent: Array[int], index: int) -> int:
	var cursor := index
	while parent[cursor] != cursor:
		parent[cursor] = parent[parent[cursor]]
		cursor = parent[cursor]
	return cursor


func _component_union(parent: Array[int], a: int, b: int) -> void:
	var root_a := _component_find(parent, a)
	var root_b := _component_find(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a


func _configure_socket_contract() -> void:
	for raw_socket_name in SOCKET_BONES.keys():
		var socket_name := str(raw_socket_name)
		var socket := BoneAttachment3D.new()
		socket.name = socket_name
		socket.bone_name = str(SOCKET_BONES[socket_name])
		_target_skeleton.add_child(socket)
		_equipment_sockets[socket_name] = socket


func _configure_identity_accessories() -> void:
	if show_wooden_cross:
		_configure_wooden_cross()
	if show_rounded_tonsure_hair:
		_configure_rounded_tonsure_hair()


func _configure_wooden_cross() -> void:
	var body_socket := _equipment_sockets.get("Body") as BoneAttachment3D
	if body_socket == null:
		return
	_wooden_cross = Node3D.new()
	_wooden_cross.name = "WoodenCross"
	body_socket.add_child(_wooden_cross)
	_wooden_cross.position = Vector3(0.0, 0.01, 0.245)

	var wood_material := StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.24, 0.095, 0.025, 1.0)
	wood_material.roughness = 0.94
	var upright_mesh := BoxMesh.new()
	upright_mesh.size = Vector3(0.065, 0.27, 0.045)
	upright_mesh.material = wood_material
	var upright := MeshInstance3D.new()
	upright.name = "Upright"
	upright.mesh = upright_mesh
	upright.position = Vector3(0.0, -0.045, 0.0)
	_wooden_cross.add_child(upright)
	var crossbar_mesh := BoxMesh.new()
	crossbar_mesh.size = Vector3(0.19, 0.06, 0.047)
	crossbar_mesh.material = wood_material
	var crossbar := MeshInstance3D.new()
	crossbar.name = "Crossbar"
	crossbar.mesh = crossbar_mesh
	crossbar.position = Vector3(0.0, 0.015, 0.002)
	_wooden_cross.add_child(crossbar)


func _configure_rounded_tonsure_hair() -> void:
	var head_socket := _equipment_sockets.get("Head") as BoneAttachment3D
	if head_socket == null:
		return
	_rounded_tonsure_hair = Node3D.new()
	_rounded_tonsure_hair.name = "RoundedTonsureHair"
	head_socket.add_child(_rounded_tonsure_hair)
	# The Wizard mesh was authored beneath a detached pointed hat, so its scalp ends
	# on a flat plane. Place one faceted hair dome in model space, then let the Head
	# attachment carry it through every animation. It deliberately has no collider.
	var head_index := _target_skeleton.find_bone("Head")
	if head_index < 0:
		_rounded_tonsure_hair.queue_free()
		_rounded_tonsure_hair = null
		return
	var crown_model_transform := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.65, 0.0))
	_rounded_tonsure_hair.transform = _target_skeleton.get_bone_global_rest(head_index).affine_inverse() * crown_model_transform

	var hair_material := StandardMaterial3D.new()
	hair_material.albedo_color = Color(0.26, 0.28, 0.30, 1.0)
	hair_material.roughness = 0.96
	hair_material.metallic = 0.0
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.30
	crown_mesh.height = 0.30
	crown_mesh.radial_segments = 12
	crown_mesh.rings = 5
	crown_mesh.material = hair_material
	var crown := MeshInstance3D.new()
	crown.name = "FacetedHairCrown"
	crown.mesh = crown_mesh
	_rounded_tonsure_hair.add_child(crown)


func _build_animation_library() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "PilotAnimationPlayer"
	_animation_player.root_node = NodePath("..")
	add_child(_animation_player)
	if _shared_animation_library == null:
		_shared_animation_library = _create_shared_animation_library()
	_animation_player.add_animation_library("", _shared_animation_library)


func _create_shared_animation_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var looping_clips: Array[String] = []
	for looping_state in LOOPING_STATES:
		var looping_clip := String(STATE_CLIPS.get(looping_state, ""))
		if not looping_clip.is_empty() and not looping_clips.has(looping_clip):
			looping_clips.append(looping_clip)
	for extra_looping_clip in EXTRA_LOOPING_CLIPS:
		if not looping_clips.has(extra_looping_clip):
			looping_clips.append(extra_looping_clip)
	for scene_path in ANIMATION_SCENE_PATHS:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			continue
		var imported_root := packed.instantiate()
		var imported_player := imported_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if imported_player != null:
			for raw_name in imported_player.get_animation_list():
				var animation_name := String(raw_name)
				if animation_name == "RESET" or animation_name == "T-Pose" or library.has_animation(animation_name):
					continue
				var imported_animation := imported_player.get_animation(raw_name)
				var animation := imported_animation.duplicate(true) as Animation
				_retarget_animation_tracks(animation)
				if animation.get_track_count() > 0:
					animation.loop_mode = Animation.LOOP_LINEAR if looping_clips.has(animation_name) else Animation.LOOP_NONE
					library.add_animation(animation_name, animation)
		imported_root.free()
	return library


func _retarget_animation_tracks(animation: Animation) -> void:
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		var path := animation.track_get_path(track_index)
		if path.get_subname_count() < 1:
			animation.remove_track(track_index)
			continue
		var source_bone := String(path.get_subname(0))
		if not KAYKIT_BONE_MAP.has(source_bone):
			animation.remove_track(track_index)
			continue
		var profile_bone := String(KAYKIT_BONE_MAP[source_bone])
		var track_type := animation.track_get_type(track_index)
		if track_type == Animation.TYPE_SCALE_3D:
			animation.remove_track(track_index)
			continue
		if track_type == Animation.TYPE_POSITION_3D and profile_bone != "Root" and profile_bone != "Hips":
			animation.remove_track(track_index)
			continue
		animation.track_set_path(track_index, NodePath("%s:%s" % [SOURCE_SKELETON_NODE_PATH, profile_bone]))


func _configure_equipment() -> void:
	if equipment_mode == "hammer":
		_add_equipment("hammer", "RightHand", Vector3.ZERO, Vector3(0.0, 0.0, deg_to_rad(90.0)), Vector3.ONE * 0.38)
		_place_hammer(false)
	elif equipment_mode == "stable_broom":
		_add_equipment("stable_broom", "RightHand", Vector3(0.0, -0.02, 0.0), Vector3(0.0, 0.0, deg_to_rad(90.0)), Vector3.ONE * 0.95)
		_place_stable_broom(false)
	elif equipment_mode == "cook_spoon":
		_add_cook_spoon()
		_place_cook_spoon(false)
	elif equipment_mode == "garden_hoe":
		_add_garden_hoe()
		_place_garden_hoe(false)
	elif equipment_mode == "medical_kit":
		_add_medical_kit()
		_sync_medical_kit_visibility("idle", "")
	elif equipment_mode == "engineering_kit":
		_add_engineering_kit()
		_add_equipment("sword", "RightHand", Vector3.ZERO, Vector3(0.0, 0.0, deg_to_rad(90.0)), Vector3.ONE * 0.72)
		_add_equipment("shield", "LeftHand", Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 0.72)
		_set_equipment_visible("sword", false)
		_set_equipment_visible("shield", false)
		_sync_engineering_kit_visibility("idle", "")
	elif equipment_mode in ["sword_shield", "synced_sword_shield"]:
		# These props and the visible target rig come from the same Synty pack, so the
		# FBX grip origin and hand axes are already authored to match each other.
		_add_equipment("sword", "RightHand", Vector3.ZERO, Vector3(0.0, 0.0, deg_to_rad(90.0)), Vector3.ONE * 0.72)
		_add_equipment("shield", "LeftHand", Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 0.72)
		if equipment_mode == "synced_sword_shield":
			_set_equipment_visible("sword", false)
			_set_equipment_visible("shield", false)


func _add_equipment(
	equipment_name: String,
	socket_name: String,
	local_position: Vector3,
	local_rotation: Vector3,
	local_scale: Vector3
) -> void:
	var packed := load(String(EQUIPMENT_SCENES.get(equipment_name, ""))) as PackedScene
	if packed == null:
		return
	var socket := _equipment_sockets.get(socket_name) as BoneAttachment3D
	if socket == null:
		return
	var equipment := packed.instantiate() as Node3D
	equipment.name = equipment_name.capitalize()
	socket.add_child(equipment)
	equipment.position = local_position
	equipment.rotation = local_rotation
	equipment.scale = local_scale
	_apply_material_recursive(equipment, _material)
	_equipment_nodes[equipment_name] = equipment


func _add_cook_spoon() -> void:
	var socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if socket == null:
		return
	var spoon := Node3D.new()
	spoon.name = "CookSpoon"
	spoon.visible = false
	socket.add_child(spoon)

	var wood_material := StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.32, 0.14, 0.055, 1.0)
	wood_material.roughness = 0.88
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.025
	handle_mesh.bottom_radius = 0.035
	handle_mesh.height = 0.64
	handle_mesh.radial_segments = 8
	handle_mesh.material = wood_material
	var handle := MeshInstance3D.new()
	handle.name = "WoodHandle"
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.30, 0.0)
	spoon.add_child(handle)

	var copper_material := StandardMaterial3D.new()
	copper_material.albedo_color = Color(0.62, 0.27, 0.075, 1.0)
	copper_material.metallic = 0.22
	copper_material.roughness = 0.58
	var bowl_mesh := SphereMesh.new()
	bowl_mesh.radius = 0.115
	bowl_mesh.height = 0.16
	bowl_mesh.radial_segments = 12
	bowl_mesh.rings = 6
	bowl_mesh.material = copper_material
	var bowl := MeshInstance3D.new()
	bowl.name = "CopperBowl"
	bowl.mesh = bowl_mesh
	bowl.position = Vector3(0.0, 0.66, 0.0)
	bowl.scale = Vector3(0.82, 0.44, 1.12)
	spoon.add_child(bowl)
	_equipment_nodes["cook_spoon"] = spoon


func _add_garden_hoe() -> void:
	var socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if socket == null:
		return
	var hoe := Node3D.new()
	hoe.name = "GardenHoe"
	hoe.visible = false
	socket.add_child(hoe)

	var wood_material := StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.26, 0.12, 0.045, 1.0)
	wood_material.roughness = 0.92
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.032
	handle_mesh.bottom_radius = 0.042
	handle_mesh.height = 1.35
	handle_mesh.radial_segments = 8
	handle_mesh.material = wood_material
	var handle := MeshInstance3D.new()
	handle.name = "AshHandle"
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.62, 0.0)
	hoe.add_child(handle)

	var iron_material := StandardMaterial3D.new()
	iron_material.albedo_color = Color(0.22, 0.25, 0.23, 1.0)
	iron_material.metallic = 0.38
	iron_material.roughness = 0.7
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.055
	collar_mesh.bottom_radius = 0.055
	collar_mesh.height = 0.13
	collar_mesh.radial_segments = 8
	collar_mesh.material = iron_material
	var collar := MeshInstance3D.new()
	collar.name = "IronCollar"
	collar.mesh = collar_mesh
	collar.position = Vector3(0.0, 1.28, 0.0)
	hoe.add_child(collar)

	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.46, 0.11, 0.20)
	blade_mesh.material = iron_material
	var blade := MeshInstance3D.new()
	blade.name = "IronBlade"
	blade.mesh = blade_mesh
	blade.position = Vector3(0.0, 1.37, 0.075)
	blade.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	hoe.add_child(blade)
	_equipment_nodes["garden_hoe"] = hoe


func _add_medical_kit() -> void:
	var body_socket := _equipment_sockets.get("Body") as BoneAttachment3D
	var left_hand_socket := _equipment_sockets.get("LeftHand") as BoneAttachment3D
	var right_hand_socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if body_socket == null or left_hand_socket == null or right_hand_socket == null:
		return
	var leather_material := StandardMaterial3D.new()
	leather_material.albedo_color = Color(0.25, 0.105, 0.045, 1.0)
	leather_material.roughness = 0.94
	var dark_leather_material := StandardMaterial3D.new()
	dark_leather_material.albedo_color = Color(0.12, 0.055, 0.025, 1.0)
	dark_leather_material.roughness = 0.96
	var linen_material := StandardMaterial3D.new()
	linen_material.albedo_color = Color(0.72, 0.69, 0.59, 1.0)
	linen_material.roughness = 0.98
	var page_material := StandardMaterial3D.new()
	page_material.albedo_color = Color(0.68, 0.62, 0.50, 1.0)
	page_material.roughness = 0.98

	var satchel := Node3D.new()
	satchel.name = "MedicalSatchel"
	body_socket.add_child(satchel)
	var chest_index := _target_skeleton.find_bone("Chest")
	if chest_index >= 0:
		satchel.transform = _target_skeleton.get_bone_global_rest(chest_index).affine_inverse()
	var pouch_mesh := BoxMesh.new()
	pouch_mesh.size = Vector3(0.30, 0.23, 0.12)
	pouch_mesh.material = leather_material
	var pouch := MeshInstance3D.new()
	pouch.name = "WornMedicinePouch"
	pouch.mesh = pouch_mesh
	pouch.position = Vector3(0.36, 0.70, 0.28)
	pouch.rotation_degrees = Vector3(0.0, -8.0, 0.0)
	satchel.add_child(pouch)
	var flap_mesh := BoxMesh.new()
	flap_mesh.size = Vector3(0.31, 0.085, 0.135)
	flap_mesh.material = dark_leather_material
	var flap := MeshInstance3D.new()
	flap.name = "PouchFlap"
	flap.mesh = flap_mesh
	flap.position = Vector3(0.36, 0.795, 0.285)
	flap.rotation_degrees = Vector3(0.0, -8.0, 0.0)
	satchel.add_child(flap)
	var patch_vertical_mesh := BoxMesh.new()
	patch_vertical_mesh.size = Vector3(0.055, 0.14, 0.018)
	patch_vertical_mesh.material = linen_material
	var patch_vertical := MeshInstance3D.new()
	patch_vertical.name = "LinenMarkVertical"
	patch_vertical.mesh = patch_vertical_mesh
	patch_vertical.position = Vector3(0.36, 0.705, 0.352)
	satchel.add_child(patch_vertical)
	var patch_horizontal_mesh := BoxMesh.new()
	patch_horizontal_mesh.size = Vector3(0.14, 0.055, 0.018)
	patch_horizontal_mesh.material = linen_material
	var patch_horizontal := MeshInstance3D.new()
	patch_horizontal.name = "LinenMarkHorizontal"
	patch_horizontal.mesh = patch_horizontal_mesh
	patch_horizontal.position = Vector3(0.36, 0.705, 0.353)
	satchel.add_child(patch_horizontal)
	_equipment_nodes["medical_satchel"] = satchel

	var book := Node3D.new()
	book.name = "MedicalBook"
	book.visible = false
	left_hand_socket.add_child(book)
	var cover_mesh := BoxMesh.new()
	cover_mesh.size = Vector3(0.24, 0.055, 0.31)
	cover_mesh.material = leather_material
	var cover := MeshInstance3D.new()
	cover.name = "LeatherCover"
	cover.mesh = cover_mesh
	book.add_child(cover)
	var pages_mesh := BoxMesh.new()
	pages_mesh.size = Vector3(0.205, 0.061, 0.275)
	pages_mesh.material = page_material
	var pages := MeshInstance3D.new()
	pages.name = "Pages"
	pages.mesh = pages_mesh
	pages.position = Vector3(0.0, 0.006, 0.0)
	book.add_child(pages)
	book.position = Vector3(0.0, -0.05, 0.02)
	book.rotation_degrees = Vector3(8.0, -18.0, 88.0)
	_equipment_nodes["medical_book"] = book

	var bandage := Node3D.new()
	bandage.name = "BandageRoll"
	bandage.visible = false
	right_hand_socket.add_child(bandage)
	var roll_mesh := CylinderMesh.new()
	roll_mesh.top_radius = 0.085
	roll_mesh.bottom_radius = 0.085
	roll_mesh.height = 0.14
	roll_mesh.radial_segments = 10
	roll_mesh.material = linen_material
	var roll := MeshInstance3D.new()
	roll.name = "LinenRoll"
	roll.mesh = roll_mesh
	bandage.add_child(roll)
	bandage.position = Vector3(0.0, -0.035, 0.015)
	bandage.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	_equipment_nodes["medical_bandage"] = bandage


func _add_engineering_kit() -> void:
	var head_socket := _equipment_sockets.get("Head") as BoneAttachment3D
	var body_socket := _equipment_sockets.get("Body") as BoneAttachment3D
	var right_hand_socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if head_socket == null or body_socket == null or right_hand_socket == null:
		return
	var leather_material := StandardMaterial3D.new()
	leather_material.albedo_color = Color(0.22, 0.105, 0.045, 1.0)
	leather_material.roughness = 0.94
	var dark_leather_material := StandardMaterial3D.new()
	dark_leather_material.albedo_color = Color(0.08, 0.055, 0.042, 1.0)
	dark_leather_material.roughness = 0.96
	var brass_material := StandardMaterial3D.new()
	brass_material.albedo_color = Color(0.52, 0.31, 0.09, 1.0)
	brass_material.metallic = 0.42
	brass_material.roughness = 0.55
	var iron_material := StandardMaterial3D.new()
	iron_material.albedo_color = Color(0.24, 0.29, 0.30, 1.0)
	iron_material.metallic = 0.48
	iron_material.roughness = 0.62
	var lens_material := StandardMaterial3D.new()
	lens_material.albedo_color = Color(0.16, 0.34, 0.35, 0.78)
	lens_material.metallic = 0.18
	lens_material.roughness = 0.38
	lens_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var wood_material := StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.42, 0.24, 0.08, 1.0)
	wood_material.roughness = 0.92

	var goggles := Node3D.new()
	goggles.name = "EngineerGoggles"
	head_socket.add_child(goggles)
	var head_index := _target_skeleton.find_bone("Head")
	if head_index >= 0:
		var inverse_head_rest := _target_skeleton.get_bone_global_rest(head_index).affine_inverse()
		_engineer_goggles_forehead_transform = inverse_head_rest * Transform3D(Basis.IDENTITY, ENGINEER_GOGGLES_FOREHEAD_MODEL_POSITION)
		_engineer_goggles_worn_transform = inverse_head_rest * Transform3D(Basis.from_scale(ENGINEER_GOGGLES_WORN_SCALE), ENGINEER_GOGGLES_WORN_MODEL_POSITION)
		goggles.transform = _engineer_goggles_forehead_transform
	for side in [-1.0, 1.0]:
		var rim_mesh := TorusMesh.new()
		rim_mesh.inner_radius = 0.050
		rim_mesh.outer_radius = 0.076
		rim_mesh.rings = 8
		rim_mesh.ring_segments = 10
		rim_mesh.material = brass_material
		var rim := MeshInstance3D.new()
		rim.name = "GoggleRimLeft" if side < 0.0 else "GoggleRimRight"
		rim.mesh = rim_mesh
		rim.position = Vector3(0.082 * side, 0.0, 0.0)
		rim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		goggles.add_child(rim)
		var lens_mesh := CylinderMesh.new()
		lens_mesh.top_radius = 0.050
		lens_mesh.bottom_radius = 0.050
		lens_mesh.height = 0.018
		lens_mesh.radial_segments = 10
		lens_mesh.material = lens_material
		var lens := MeshInstance3D.new()
		lens.name = "GoggleLensLeft" if side < 0.0 else "GoggleLensRight"
		lens.mesh = lens_mesh
		lens.position = Vector3(0.082 * side, 0.0, 0.004)
		lens.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		goggles.add_child(lens)
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(0.055, 0.025, 0.025)
	bridge_mesh.material = brass_material
	var bridge := MeshInstance3D.new()
	bridge.name = "GoggleBridge"
	bridge.mesh = bridge_mesh
	goggles.add_child(bridge)
	var strap_mesh := BoxMesh.new()
	strap_mesh.size = Vector3(0.42, 0.032, 0.026)
	strap_mesh.material = dark_leather_material
	var strap := MeshInstance3D.new()
	strap.name = "GoggleStrap"
	strap.mesh = strap_mesh
	strap.position = Vector3(0.0, 0.0, -0.045)
	goggles.add_child(strap)
	_equipment_nodes["engineer_goggles"] = goggles

	var tool_belt := Node3D.new()
	tool_belt.name = "EngineerToolBelt"
	body_socket.add_child(tool_belt)
	var chest_index := _target_skeleton.find_bone("Chest")
	if chest_index >= 0:
		tool_belt.transform = _target_skeleton.get_bone_global_rest(chest_index).affine_inverse()
	var pouch_mesh := BoxMesh.new()
	pouch_mesh.size = Vector3(0.17, 0.17, 0.095)
	pouch_mesh.material = leather_material
	for side in [-1.0, 1.0]:
		var pouch := MeshInstance3D.new()
		pouch.name = "ToolPouchLeft" if side < 0.0 else "ToolPouchRight"
		pouch.mesh = pouch_mesh
		pouch.position = Vector3(0.30 * side, 0.57, 0.18)
		pouch.rotation_degrees = Vector3(0.0, -8.0 * side, 0.0)
		tool_belt.add_child(pouch)
	var rule_mesh := BoxMesh.new()
	rule_mesh.size = Vector3(0.038, 0.31, 0.028)
	rule_mesh.material = wood_material
	var rule := MeshInstance3D.new()
	rule.name = "FoldingRule"
	rule.mesh = rule_mesh
	rule.position = Vector3(-0.38, 0.62, 0.19)
	rule.rotation_degrees = Vector3(0.0, 0.0, 13.0)
	tool_belt.add_child(rule)
	var wedge_mesh := PrismMesh.new()
	wedge_mesh.size = Vector3(0.075, 0.17, 0.06)
	wedge_mesh.material = wood_material
	var wedge := MeshInstance3D.new()
	wedge.name = "WoodWedge"
	wedge.mesh = wedge_mesh
	wedge.position = Vector3(0.38, 0.62, 0.20)
	wedge.rotation_degrees = Vector3(0.0, 0.0, -9.0)
	tool_belt.add_child(wedge)
	_equipment_nodes["engineer_tool_belt"] = tool_belt

	var wrench := Node3D.new()
	wrench.name = "EngineerWrench"
	wrench.visible = false
	right_hand_socket.add_child(wrench)
	wrench.scale = Vector3.ONE * 0.68
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.075, 0.56, 0.055)
	handle_mesh.material = iron_material
	var handle := MeshInstance3D.new()
	handle.name = "WrenchHandle"
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 0.25, 0.0)
	wrench.add_child(handle)
	for side in [-1.0, 1.0]:
		var jaw_mesh := BoxMesh.new()
		jaw_mesh.size = Vector3(0.09, 0.20, 0.07)
		jaw_mesh.material = iron_material
		var jaw := MeshInstance3D.new()
		jaw.name = "WrenchJawLeft" if side < 0.0 else "WrenchJawRight"
		jaw.mesh = jaw_mesh
		jaw.position = Vector3(0.07 * side, 0.58, 0.0)
		jaw.rotation_degrees = Vector3(0.0, 0.0, -24.0 * side)
		wrench.add_child(jaw)
	_equipment_nodes["engineer_wrench"] = wrench


func apply_profile(npc_profile: Dictionary) -> void:
	var states: Dictionary = npc_profile.get("states", {}) if npc_profile.get("states", {}) is Dictionary else {}
	var next_hp := int(states.get("hp", _previous_hp if _previous_hp >= 0 else 0))
	var next_unconscious := bool(states.get("unconscious", false))
	var initialized := _previous_hp >= 0
	var took_damage := initialized and next_hp < _previous_hp
	var revived := initialized and _previous_unconscious and not next_unconscious
	_profile = npc_profile.duplicate(true)
	var equipment: Dictionary = npc_profile.get("equipment", {}) if npc_profile.get("equipment", {}) is Dictionary else {}
	var main_weapon: Dictionary = equipment.get("main_weapon", {}) if equipment.get("main_weapon", {}) is Dictionary else {}
	_authority_main_weapon_id = str(main_weapon.get("id", ""))
	_previous_hp = next_hp
	_previous_unconscious = next_unconscious
	_debug_forced_state = ""
	if took_damage:
		_trigger_damage_feedback(next_unconscious)
	if next_unconscious:
		_transient_state = ""
		_transient_remaining = 0.0
	elif revived:
		_start_transient("get_up", GET_UP_SECONDS)
	elif took_damage:
		_start_transient("hit_react", HIT_REACT_SECONDS)
	_apply_profile_state(false)


func set_spatial_attachment_pose(pose: String) -> void:
	_spatial_attachment_pose = pose
	_debug_forced_state = ""
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
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() <= 0.0001:
		return
	_target_facing_direction = flat.normalized()
	_target_yaw = atan2(-_target_facing_direction.x, -_target_facing_direction.z)


func get_visible_forward() -> Vector3:
	if _visual_root == null:
		return _target_facing_direction
	return _visual_root.global_basis.z.normalized()


func set_selected(_selected: bool) -> void:
	# Selection ownership remains on the parent NPC / enemy actor. The imported
	# palette material has no project-specific outline shader parameter.
	pass


func _process(delta: float) -> void:
	if not _ready_ok:
		return
	var gameplay_paused := _is_gameplay_paused()
	if gameplay_paused != _animation_paused:
		_animation_paused = gameplay_paused
		_update_playback_speed()
	if gameplay_paused:
		return
	_update_combat_feedback(delta)
	if _visual_root != null:
		_visual_root.rotation.y = lerp_angle(
			_visual_root.rotation.y,
			_target_yaw + MODEL_FORWARD_CORRECTION_Y,
			clampf(delta / maxf(0.01, facing_turn_speed), 0.0, 1.0)
		)
	if not _transient_state.is_empty() and _transient_remaining > 0.0:
		_transient_remaining = maxf(0.0, _transient_remaining - delta)
		if is_zero_approx(_transient_remaining):
			_transient_state = ""
			_apply_profile_state(false)


func _apply_profile_state(reset: bool) -> void:
	if not _ready_ok:
		return
	var next_state := _resolve_animation_state()
	_desired_state = next_state
	_play_state(next_state, reset)
	var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
	var current_action := str(states.get("current_action", ""))
	_place_hammer(next_state == "work" and current_action == "work_blacksmith")
	_place_stable_broom(next_state == "work" and current_action == "work_stable")
	_place_cook_spoon(next_state == "work" and current_action == "work_dining_hall")
	_place_garden_hoe(next_state == "work" and current_action == "work_garden")
	_sync_medical_kit_visibility(next_state, current_action)
	_sync_engineering_kit_visibility(next_state, current_action)
	_sync_sword_shield_visibility(next_state)
	if current_action == "receive_weapon_training":
		_set_equipment_visible("hammer", false)
	_update_playback_speed()


func _resolve_animation_state() -> String:
	if not _debug_forced_state.is_empty():
		return _debug_forced_state
	var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
	if bool(states.get("unconscious", false)):
		return "unconscious"
	if not _transient_state.is_empty():
		return _transient_state
	if _is_moving:
		var behavior_mode := str(states.get("behavior_mode", ""))
		return "run" if _movement_speed > 5.5 or ["combat", "avoid_combat", "escaped"].has(behavior_mode) else "walk"
	var current_action := str(states.get("current_action", "idle"))
	if _spatial_attachment_pose in ["sleeping_supine", "lying_supine"] or current_action == "sleep_in_dormitory":
		return "sleeping"
	if _spatial_attachment_pose == "seated_study":
		return "seated_study"
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
	if current_action == "assist_heal" or current_action.begins_with("assist_heal_"):
		return "medical_treatment"
	if current_action == "work_clinic_doctor" and str(states.get("presentation_clinic_duty_mode", "")) == "treatment":
		return "medical_treatment"
	if equipment_mode == "engineering_kit" and (current_action.begins_with("assist_repair_") or current_action.begins_with("assist_upgrade_")):
		return "work"
	if current_action in ["work_blacksmith", "work_stable", "work_workshop", "work_dining_hall", "work_garden", "work_tavern", "work_clinic_doctor"]:
		return "work"
	if current_action.begins_with("attacking_") or current_action.begins_with("winding_up_"):
		return "attack"
	if ["talk_to_npc", "proactive_talk", "escape_intervention_dialogue"].has(current_action):
		return "talk"
	return DEFAULT_STATE


func _play_state(state_name: String, reset: bool = false) -> bool:
	if not REQUIRED_STATES.has(state_name):
		return false
	var clip_name := _get_state_clip(state_name)
	if _animation_player == null or not _animation_player.has_animation(clip_name):
		return false
	if _current_state == state_name and not reset and _animation_player.is_playing():
		return true
	_animation_player.play(clip_name, 0.16)
	_current_state = state_name
	_current_clip = clip_name
	_update_playback_speed()
	return true


func _get_state_clip(state_name: String) -> String:
	if state_name == "work":
		return work_clip
	if state_name == "mass_leader":
		return mass_leader_clip
	if state_name == "medical_treatment":
		return medical_treatment_clip
	return str(STATE_CLIPS.get(state_name, "Idle_A"))


func _start_transient(state_name: String, duration: float) -> void:
	_transient_state = state_name
	_transient_remaining = maxf(0.0, duration)


func _update_playback_speed() -> void:
	if _animation_player == null:
		return
	if _animation_paused:
		_animation_player.speed_scale = 0.0
		return
	var state_scale := 1.15 if _desired_state == "run" else 1.0
	if _desired_state == "walk":
		state_scale = clampf(_movement_speed / 3.2, 0.85, 1.35)
	_animation_player.speed_scale = playback_speed * state_scale


func _place_hammer(in_right_hand: bool) -> void:
	var hammer := _equipment_nodes.get("hammer") as Node3D
	if hammer == null:
		return
	var socket_name := "RightHand" if in_right_hand else "Back"
	var socket := _equipment_sockets.get(socket_name) as BoneAttachment3D
	if socket == null:
		return
	if hammer.get_parent() != socket:
		hammer.reparent(socket, false)
	hammer.visible = true
	if in_right_hand:
		hammer.position = Vector3.ZERO
		hammer.rotation = Vector3(0.0, 0.0, deg_to_rad(90.0))
		hammer.scale = Vector3.ONE * 0.38
	else:
		hammer.position = Vector3(0.08, 0.10, 0.12)
		hammer.rotation_degrees = Vector3(0.0, 18.0, 28.0)
		hammer.scale = Vector3.ONE * 0.34


func _place_stable_broom(in_right_hand: bool) -> void:
	var broom := _equipment_nodes.get("stable_broom") as Node3D
	if broom == null:
		return
	broom.visible = in_right_hand
	if not in_right_hand:
		return
	var socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if socket == null:
		return
	if broom.get_parent() != socket:
		broom.reparent(socket, false)
	broom.position = Vector3(0.0, -0.02, 0.0)
	broom.rotation = Vector3(0.0, 0.0, deg_to_rad(90.0))
	broom.scale = Vector3.ONE * 0.95


func _place_cook_spoon(in_right_hand: bool) -> void:
	var spoon := _equipment_nodes.get("cook_spoon") as Node3D
	if spoon == null:
		return
	spoon.visible = in_right_hand
	if not in_right_hand:
		return
	var socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if socket == null:
		return
	if spoon.get_parent() != socket:
		spoon.reparent(socket, false)
	spoon.position = Vector3(0.0, -0.03, 0.0)
	spoon.rotation_degrees = Vector3(8.0, -12.0, 0.0)
	spoon.scale = Vector3.ONE


func _place_garden_hoe(in_right_hand: bool) -> void:
	var hoe := _equipment_nodes.get("garden_hoe") as Node3D
	if hoe == null:
		return
	hoe.visible = in_right_hand
	if not in_right_hand:
		return
	var socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if socket == null:
		return
	if hoe.get_parent() != socket:
		hoe.reparent(socket, false)
	hoe.position = Vector3(0.0, -0.04, 0.0)
	# KayKit Digging keeps the off hand on this direction in RightHand-local
	# space. Aligning the shaft to it makes the grip read as two-handed and
	# keeps the blade in front of the worker instead of trailing behind him.
	hoe.quaternion = Quaternion(Vector3.UP, GARDEN_HOE_SHAFT_DIRECTION.normalized())
	hoe.scale = Vector3.ONE * 0.9


func _sync_medical_kit_visibility(state_name: String, current_action: String) -> void:
	if equipment_mode != "medical_kit":
		return
	_set_equipment_visible("medical_satchel", true)
	var debug_preview := current_action.is_empty()
	_set_equipment_visible("medical_book", state_name in ["work", "seated_study"] and (debug_preview or current_action == "work_clinic_doctor"))
	_set_equipment_visible("medical_bandage", state_name == "medical_treatment" and (debug_preview or current_action == "work_clinic_doctor" or current_action == "assist_heal" or current_action.begins_with("assist_heal_")))


func _sync_engineering_kit_visibility(state_name: String, current_action: String) -> void:
	if equipment_mode != "engineering_kit":
		return
	_set_equipment_visible("engineer_goggles", true)
	_set_equipment_visible("engineer_tool_belt", true)
	var debug_preview := current_action.is_empty()
	_set_engineer_goggles_worn(state_name == "work" and (debug_preview or current_action == "work_workshop"))
	var engineering_action := (
		current_action == "work_workshop"
		or current_action.begins_with("assist_repair_")
		or current_action.begins_with("assist_upgrade_")
	)
	_set_equipment_visible("engineer_wrench", state_name == "work" and (debug_preview or engineering_action))


func _set_engineer_goggles_worn(worn: bool) -> void:
	var goggles := _equipment_nodes.get("engineer_goggles") as Node3D
	if goggles == null:
		return
	var next_mode := "worn" if worn else "forehead"
	if _engineer_goggles_mode == next_mode:
		return
	_engineer_goggles_mode = next_mode
	if _engineer_goggles_tween != null and _engineer_goggles_tween.is_valid():
		_engineer_goggles_tween.kill()
	var target_transform := _engineer_goggles_worn_transform if worn else _engineer_goggles_forehead_transform
	if not is_inside_tree():
		goggles.transform = target_transform
		return
	_engineer_goggles_tween = create_tween()
	_engineer_goggles_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_engineer_goggles_tween.set_trans(Tween.TRANS_SINE)
	_engineer_goggles_tween.set_ease(Tween.EASE_IN_OUT)
	_engineer_goggles_tween.tween_property(goggles, "transform", target_transform, ENGINEER_GOGGLES_TRANSITION_SECONDS)


func _distance_to_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_to(segment_start)
	var ratio := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_start + segment * ratio)


func _set_equipment_visible(equipment_name: String, visible_value: bool) -> void:
	var equipment := _equipment_nodes.get(equipment_name) as Node3D
	if equipment != null:
		equipment.visible = visible_value


func _sync_sword_shield_visibility(state_name: String) -> void:
	if not equipment_mode in ["sword_shield", "synced_sword_shield", "engineering_kit"]:
		return
	var authority_allows := equipment_mode == "sword_shield" or _authority_main_weapon_id == "sword_shield"
	var state_allows := state_name != "sleeping"
	_set_equipment_visible("sword", authority_allows and state_allows)
	_set_equipment_visible("shield", authority_allows and state_allows)


func _configure_feedback() -> void:
	_physical_bone_simulator = PhysicalBoneSimulator3D.new()
	_physical_bone_simulator.name = "PhysicalBoneSimulator3D"
	_target_skeleton.add_child(_physical_bone_simulator)
	_blood_particles = GPUParticles3D.new()
	_blood_particles.name = "BloodBurst"
	_blood_particles.amount = 18
	_blood_particles.lifetime = 0.62
	_blood_particles.one_shot = true
	_blood_particles.emitting = false
	_blood_particles.explosiveness = 0.95
	_blood_particles.position = Vector3(0.0, 1.0, 0.0)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.1
	process_material.direction = Vector3(0.0, 0.35, 1.0)
	process_material.spread = 68.0
	process_material.initial_velocity_min = 1.0
	process_material.initial_velocity_max = 2.4
	process_material.gravity = Vector3(0.0, -5.2, 0.0)
	_blood_particles.process_material = process_material
	var droplet := SphereMesh.new()
	droplet.radius = 0.025
	droplet.height = 0.07
	var blood_material := StandardMaterial3D.new()
	blood_material.albedo_color = Color(0.42, 0.006, 0.004, 1.0)
	droplet.material = blood_material
	_blood_particles.draw_pass_1 = droplet
	add_child(_blood_particles)


func _trigger_damage_feedback(became_unconscious: bool) -> void:
	_damage_feedback_count += 1
	if _blood_particles != null:
		_blood_particles.restart()
		_blood_particles.emitting = true
	var impact_direction := Vector3(_target_facing_direction.x, 0.0, _target_facing_direction.z).normalized()
	if impact_direction.length_squared() <= 0.0001:
		impact_direction = Vector3.FORWARD
	_hit_velocity += -impact_direction * (2.6 if became_unconscious else 1.5)
	_hit_velocity.y += 0.9 if became_unconscious else 0.45


func _update_combat_feedback(delta: float) -> void:
	_hit_velocity += -_hit_offset * 32.0 * delta
	_hit_velocity *= exp(-8.5 * delta)
	_hit_offset += _hit_velocity * delta
	if _previous_unconscious:
		_hit_offset.y = maxf(_hit_offset.y, 0.0)
	if _visual_root == null:
		return
	_visual_root.position = _hit_offset + _get_presentation_pose_offset()
	var settle_roll := deg_to_rad(-7.0) if _previous_unconscious else 0.0
	var settle_pitch := deg_to_rad(5.0) if _previous_unconscious else 0.0
	_visual_root.rotation.x = lerp_angle(
		_visual_root.rotation.x,
		settle_pitch + clampf(_hit_offset.z * 0.18, -0.16, 0.16),
		clampf(delta * 8.0, 0.0, 1.0)
	)
	_visual_root.rotation.z = lerp_angle(
		_visual_root.rotation.z,
		settle_roll - clampf(_hit_offset.x * 0.22, -0.2, 0.2),
		clampf(delta * 8.0, 0.0, 1.0)
	)


func _get_presentation_pose_offset() -> Vector3:
	return Vector3(SEATED_POSE_OFFSET.x, seated_pose_offset_y, SEATED_POSE_OFFSET.z) if _desired_state in ["seated_prayer", "seated_study", "seated_eating", "vehicle_seated"] else Vector3.ZERO


func _get_clip_loop_mode(clip_name: String) -> int:
	if _animation_player == null or not _animation_player.has_animation(clip_name):
		return -1
	return int(_animation_player.get_animation(clip_name).loop_mode)


func _is_gameplay_paused() -> bool:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	return time_system != null and time_system.has_method("is_gameplay_paused") and time_system.is_gameplay_paused()


func debug_force_animation_state(state_name: String) -> Dictionary:
	if not REQUIRED_STATES.has(state_name):
		return {"ok": false, "error": "unknown_animation_state", "state": state_name}
	_debug_forced_state = state_name
	_transient_state = ""
	_transient_remaining = 0.0
	_desired_state = state_name
	if not _play_state(state_name, true):
		return {"ok": false, "error": "missing_animation_clip", "state": state_name, "clip": _get_state_clip(state_name)}
	_place_hammer(state_name == "work" and equipment_mode == "hammer")
	_place_stable_broom(state_name == "work" and equipment_mode == "stable_broom")
	_place_cook_spoon(state_name == "work" and equipment_mode == "cook_spoon")
	_place_garden_hoe(state_name == "work" and equipment_mode == "garden_hoe")
	_sync_medical_kit_visibility(state_name, "")
	_sync_engineering_kit_visibility(state_name, "")
	_sync_sword_shield_visibility(state_name)
	return debug_get_snapshot()


func has_attachment_socket(socket_name: String) -> bool:
	return _equipment_sockets.get(socket_name) is Node3D


func get_attachment_global_position(socket_name: String) -> Vector3:
	var socket := _equipment_sockets.get(socket_name) as Node3D
	return socket.global_position if socket != null else global_position


func debug_get_snapshot() -> Dictionary:
	var available_clips: Array[String] = []
	if _animation_player != null:
		for raw_name in _animation_player.get_animation_list():
			available_clips.append(str(raw_name))
	var socket_snapshot := {}
	for raw_socket_name in SOCKET_BONES.keys():
		var socket_name := str(raw_socket_name)
		var socket := _equipment_sockets.get(socket_name) as BoneAttachment3D
		socket_snapshot[socket_name] = {
			"present": socket != null,
			"bone": socket.bone_name if socket != null else "",
		}
	var hammer := _equipment_nodes.get("hammer") as Node3D
	var stable_broom := _equipment_nodes.get("stable_broom") as Node3D
	var cook_spoon := _equipment_nodes.get("cook_spoon") as Node3D
	var garden_hoe := _equipment_nodes.get("garden_hoe") as Node3D
	var medical_satchel := _equipment_nodes.get("medical_satchel") as Node3D
	var medical_book := _equipment_nodes.get("medical_book") as Node3D
	var medical_bandage := _equipment_nodes.get("medical_bandage") as Node3D
	var engineer_goggles := _equipment_nodes.get("engineer_goggles") as Node3D
	var engineer_tool_belt := _equipment_nodes.get("engineer_tool_belt") as Node3D
	var engineer_wrench := _equipment_nodes.get("engineer_wrench") as Node3D
	var sword := _equipment_nodes.get("sword") as Node3D
	var shield := _equipment_nodes.get("shield") as Node3D
	var garden_hoe_blade := garden_hoe.find_child("IronBlade", true, false) as Node3D if garden_hoe != null else null
	var left_hand := _equipment_sockets.get("LeftHand") as BoneAttachment3D
	var garden_hoe_front_offset := -1.0
	var garden_hoe_left_hand_distance := -1.0
	if garden_hoe != null and garden_hoe_blade != null:
		var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else Vector3.FORWARD
		garden_hoe_front_offset = (garden_hoe_blade.global_position - global_position).dot(visual_forward)
		if left_hand != null:
			garden_hoe_left_hand_distance = _distance_to_segment(
				left_hand.global_position,
				garden_hoe.global_position,
				garden_hoe_blade.global_position
			)
	var resolved_state_clips := STATE_CLIPS.duplicate(true)
	resolved_state_clips["work"] = work_clip
	resolved_state_clips["mass_leader"] = mass_leader_clip
	resolved_state_clips["medical_treatment"] = medical_treatment_clip
	return {
		"ready": _ready_ok,
		"appearance_id": appearance_id,
		"state_contract": REQUIRED_STATES.duplicate(),
		"state_clips": resolved_state_clips,
		"current_state": _current_state,
		"desired_state": _desired_state,
		"current_clip": _current_clip,
		"available_clips": available_clips,
		"available_clip_count": available_clips.size(),
		"source_bones": _source_skeleton.get_bone_count() if _source_skeleton != null else 0,
		"target_bones": _target_skeleton.get_bone_count() if _target_skeleton != null else 0,
		"rebound_mesh_count": _target_mesh_count,
		"equipment_mode": equipment_mode,
		"use_imported_character_material": use_imported_character_material,
		"remove_detached_headwear": remove_detached_headwear,
		"removed_headwear_triangle_count": _removed_headwear_triangle_count,
		"wooden_cross_visible": _wooden_cross != null and _wooden_cross.visible,
		"wooden_cross_parent": str(_wooden_cross.get_parent().name) if _wooden_cross != null and _wooden_cross.get_parent() != null else "",
		"rounded_tonsure_hair_visible": _rounded_tonsure_hair != null and _rounded_tonsure_hair.visible,
		"rounded_tonsure_hair_parent": str(_rounded_tonsure_hair.get_parent().name) if _rounded_tonsure_hair != null and _rounded_tonsure_hair.get_parent() != null else "",
		"rounded_tonsure_hair_mesh_count": _rounded_tonsure_hair.find_children("*", "MeshInstance3D", true, false).size() if _rounded_tonsure_hair != null else 0,
		"palette_saturation": palette_saturation,
		"palette_value_scale": palette_value_scale,
		"palette_path": palette_texture.resource_path if palette_texture != null else "",
		"socket_contract": socket_snapshot,
		"hammer_parent": str(hammer.get_parent().name) if hammer != null and hammer.get_parent() != null else "",
		"hammer_visible": hammer != null and hammer.visible,
		"stable_broom_parent": str(stable_broom.get_parent().name) if stable_broom != null and stable_broom.get_parent() != null else "",
		"stable_broom_visible": stable_broom != null and stable_broom.visible,
		"cook_spoon_parent": str(cook_spoon.get_parent().name) if cook_spoon != null and cook_spoon.get_parent() != null else "",
		"cook_spoon_visible": cook_spoon != null and cook_spoon.visible,
		"garden_hoe_parent": str(garden_hoe.get_parent().name) if garden_hoe != null and garden_hoe.get_parent() != null else "",
		"garden_hoe_visible": garden_hoe != null and garden_hoe.visible,
		"garden_hoe_front_offset": garden_hoe_front_offset,
		"garden_hoe_left_hand_distance": garden_hoe_left_hand_distance,
		"medical_satchel_parent": str(medical_satchel.get_parent().name) if medical_satchel != null and medical_satchel.get_parent() != null else "",
		"medical_satchel_visible": medical_satchel != null and medical_satchel.visible,
		"medical_book_parent": str(medical_book.get_parent().name) if medical_book != null and medical_book.get_parent() != null else "",
		"medical_book_visible": medical_book != null and medical_book.visible,
		"medical_bandage_parent": str(medical_bandage.get_parent().name) if medical_bandage != null and medical_bandage.get_parent() != null else "",
		"medical_bandage_visible": medical_bandage != null and medical_bandage.visible,
		"engineer_goggles_parent": str(engineer_goggles.get_parent().name) if engineer_goggles != null and engineer_goggles.get_parent() != null else "",
		"engineer_goggles_visible": engineer_goggles != null and engineer_goggles.visible,
		"engineer_goggles_mode": _engineer_goggles_mode,
		"engineer_goggles_target_model_position": ENGINEER_GOGGLES_WORN_MODEL_POSITION if _engineer_goggles_mode == "worn" else ENGINEER_GOGGLES_FOREHEAD_MODEL_POSITION,
		"engineer_tool_belt_parent": str(engineer_tool_belt.get_parent().name) if engineer_tool_belt != null and engineer_tool_belt.get_parent() != null else "",
		"engineer_tool_belt_visible": engineer_tool_belt != null and engineer_tool_belt.visible,
		"engineer_wrench_parent": str(engineer_wrench.get_parent().name) if engineer_wrench != null and engineer_wrench.get_parent() != null else "",
		"engineer_wrench_visible": engineer_wrench != null and engineer_wrench.visible,
		"authority_main_weapon_id": _authority_main_weapon_id,
		"sword_visible": sword != null and sword.visible,
		"shield_visible": shield != null and shield.visible,
		"sword_parent": str(sword.get_parent().name) if sword != null and sword.get_parent() != null else "",
		"shield_parent": str(shield.get_parent().name) if shield != null and shield.get_parent() != null else "",
		"spatial_attachment_pose": _spatial_attachment_pose,
		"logical_moving": _is_moving,
		"movement_speed": _movement_speed,
		"movement_activation_count": _movement_activation_count,
		"last_locomotion_state": _last_locomotion_state,
		"visual_forward": _visual_root.global_basis.z.normalized() if _visual_root != null else Vector3.FORWARD,
		"target_facing_direction": _target_facing_direction,
		"source_facing_correction_degrees": rad_to_deg(MODEL_FORWARD_CORRECTION_Y),
		"model_forward_axis": "+Z",
		"work_cycle_position": _animation_player.current_animation_position if _animation_player != null and _current_state == "work" else -1.0,
		"work_cycle_length": _animation_player.current_animation_length if _animation_player != null and _current_state == "work" else 0.0,
		"work_clip_loop_mode": _get_clip_loop_mode(work_clip),
		"medical_treatment_clip_loop_mode": _get_clip_loop_mode(medical_treatment_clip),
		"training_instructor_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.training_instructor)),
		"training_practice_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.training_practice)),
		"mass_leader_clip_loop_mode": _get_clip_loop_mode(mass_leader_clip),
		"seated_prayer_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.seated_prayer)),
		"seated_study_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.seated_study)),
		"seated_eating_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.seated_eating)),
		"sleeping_clip_loop_mode": _get_clip_loop_mode(str(STATE_CLIPS.sleeping)),
		"presentation_pose_offset": _get_presentation_pose_offset(),
		"ragdoll_placeholder_ready": _physical_bone_simulator != null,
		"blood_vfx_ready": _blood_particles != null,
		"blood_vfx_emitting": _blood_particles != null and _blood_particles.emitting,
		"damage_feedback_count": _damage_feedback_count,
		"fall_feedback_mode": "animated_fall_with_physics_impulse",
		"retarget_mode": "Godot_4_6_RealtimeRetarget_profile_humanoid",
		"authority_role": "presentation_only",
	}
