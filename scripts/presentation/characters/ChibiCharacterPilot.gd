class_name ChibiCharacterPilot
extends Node3D


const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")
const SYNTY_KNIGHT_ARMOR_EXTRACTOR := preload("res://scripts/presentation/characters/SyntyKnightArmorExtractor.gd")
const COMBAT_ANIMATION_TIMING := preload("res://scripts/presentation/characters/CombatAnimationTiming.gd")
const REQUIRED_STATES := [
	"idle",
	"walk",
	"run",
	"talk",
	"happy",
	"angry",
	"work",
	"training_instructor",
	"training_practice",
	"mass_leader",
	"seated_prayer",
	"seated_study",
	"seated_eating",
	"drink",
	"attack",
	"medical_treatment",
	"hit_react",
	"unconscious",
	"get_up",
	"vehicle_seated",
	"mounted_attack",
	"mounted_walk",
	"mounted_hit_react",
	"mounted_training",
	"mounted_fall",
	"sleeping",
]
const COMBAT_PRESENTATION_STATES := [
	"attack", "hit_react", "unconscious", "get_up",
	"mounted_attack", "mounted_hit_react", "mounted_fall",
]
const LOOPING_STATES := [
	"idle", "walk", "run", "talk", "work", "training_instructor",
	"training_practice", "mass_leader", "seated_prayer", "seated_study", "seated_eating",
	"drink", "happy", "medical_treatment", "vehicle_seated", "mounted_walk", "mounted_training", "sleeping",
]
const HOLD_FINAL_POSE_STATES := ["unconscious", "mounted_fall"]
const EXTRA_LOOPING_CLIPS := [
	"Working_A", "Working_B", "Working_C", "Digging",
	"Ranged_Magic_Spellcasting_Long", "Ranged_Magic_Raise",
]
const WORK_ACTION_CLIPS := {
	"work_blacksmith": "Hammering",
	"work_stable": "Working_B",
	"work_dining_hall": "Working_C",
	"work_garden": "Digging",
	"work_tavern": "Working_A",
	"work_clinic_doctor": "Working_B",
	"work_workshop": "Working_A",
}
const MOUNTED_CLIP := "Mounted_Idle"
const MOUNTED_ATTACK_CLIP := "Mounted_1H_Attack"
const MOUNTED_POLEARM_ATTACK_CLIP := "Mounted_Polearm_Stab"
const MOUNTED_BOW_DRAW_CLIP := "Mounted_Bow_Draw"
const MOUNTED_BOW_AIM_CLIP := "Mounted_Bow_Aim"
const MOUNTED_BOW_RELEASE_CLIP := "Mounted_Bow_Release"
const MOUNTED_CROSSBOW_AIM_CLIP := "Mounted_Crossbow_Aim"
const MOUNTED_CROSSBOW_SHOOT_CLIP := "Mounted_Crossbow_Shoot"
const MOUNTED_CROSSBOW_RELOAD_CLIP := "Mounted_Crossbow_Reload"
const MOUNTED_WALK_CLIP := "Mounted_Walk"
const MOUNTED_HIT_REACT_CLIP := "Mounted_Hit"
const MOUNTED_TRAINING_CLIP := "Mounted_Training"
const MOUNTED_STATES := [
	"vehicle_seated", "mounted_attack", "mounted_walk", "mounted_hit_react",
	"mounted_training", "mounted_fall",
]
const MOUNTED_ATTACK_UPPER_BODY_BONES := [
	"Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
]
const SEATED_EATING_CLIP := "Seated_Eating"
const SEATED_STUDY_CLIP := "Seated_Study_Idle"
const DRINK_CLIP := "Drinking"
const SEATED_EATING_UPPER_BODY_BONES := [
	"Spine", "Chest", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
]
const SEATED_STUDY_STILL_ARM_BONES := [
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
]
const MOUNTED_THIGH_SPREAD_DEGREES := 58.0
const MOUNTED_FALL_AIRBORNE_SECONDS := 0.92
const MOUNTED_FALL_SIDE_DISTANCE := 0.62
const MOUNTED_FALL_BACK_DISTANCE := 0.14
const MOUNTED_FALL_ARC_HEIGHT := 0.34
const MOUNTED_FALL_MAX_ROLL_DEGREES := 58.0
const FOOT_SWORD_GRIP_DOWN_OFFSET := 0.18
const FOOT_SWORD_GRIP_INWARD_OFFSET := 0.10
const GARDEN_HOE_RIGHT_GRIP_SOURCE_LOCAL_POSITION := Vector3(0.0, 0.15, 0.0)
# The bone attachment origin sits near the outer knuckles in this retargeted
# rig. Pull the shaft back toward each lower arm so it passes through the
# enclosed palm volume instead of floating across the front of both hands.
const GARDEN_HOE_PALM_INSET := -0.08
# Keep the shaft centered in the closed palms instead of riding across the
# wrist seam after the depth correction above.
const GARDEN_HOE_PALM_DOWN_OFFSET := 0.25
const GARDEN_HOE_HANDLE_REAR_LOCAL_POSITION := Vector3(0.0, -0.025, 0.0)
const GARDEN_HOE_HANDLE_FRONT_LOCAL_POSITION := Vector3(0.0, 1.325, 0.0)
# The imported stable tool runs from its handle end at local +Y toward its
# working head at local -Y. Keep the handle end in Toma's palm and the head
# forward throughout the care animation instead of letting it trail behind.
const STABLE_TOOL_GRIP_SOURCE_LOCAL_POSITION := Vector3(0.0, 0.2259, 0.0)
const STABLE_TOOL_DOWNWARD_WEIGHT := 0.45
const STABLE_TOOL_SCALE := Vector3.ONE * 0.95
# The cooking utensil's local +Y axis runs from the rear of the handle toward
# the copper scoop. Keep that rear end in the palm while the scoop points
# forward and down toward the stove pot throughout Bruno's hand animation.
const COOK_SPOON_GRIP_SOURCE_LOCAL_POSITION := Vector3(0.0, -0.02, 0.0)
const COOK_SPOON_DOWNWARD_WEIGHT := 0.38
const COOK_SPOON_PALM_INWARD_OFFSET := 0.08
# Owen's procedural wrench runs from the rear end of its handle at local -Y
# toward the jaws at local +Y. Seat that rear end in his palm and keep the
# jaws aimed in front of him throughout the assembly loop.
const ENGINEER_WRENCH_GRIP_SOURCE_LOCAL_POSITION := Vector3(0.0, -0.03, 0.0)
const ENGINEER_WRENCH_DOWNWARD_WEIGHT := 0.18
const ENGINEER_TOOL_POUCH_SIDE_OFFSET := 0.22
const ENGINEER_TOOL_POUCH_FORWARD_OFFSET := 0.10
const PREVIEW_POLEARM_SCALE := Vector3.ONE * 0.88
const PREVIEW_BOW_SCALE := Vector3.ONE * 0.82
const PREVIEW_CROSSBOW_SCALE := Vector3.ONE * 0.90
const PREVIEW_POLEARM_GRIP_SOURCE_LOCAL_POSITION := Vector3.ZERO
const PREVIEW_POLEARM_PALM_OFFSET := 0.10
const PREVIEW_POLEARM_DOWN_OFFSET := 0.06
const PREVIEW_POLEARM_INWARD_OFFSET := 0.05
const PREVIEW_POLEARM_THRUST_CLIP := "Melee_2H_Attack_Stab"
const PREVIEW_POLEARM_SHAFT_REAR_LOCAL_POSITION := Vector3(0.0, -0.65, 0.0)
const PREVIEW_POLEARM_SHAFT_FRONT_LOCAL_POSITION := Vector3(0.0, 1.85, 0.0)
const PREVIEW_POLEARM_TIP_LOCAL_POSITION := Vector3(0.0, 2.27, 0.0)
const SWORD_BLADE_BASE_LOCAL_POSITION := Vector3(0.0, 0.10, 0.0)
const SWORD_BLADE_TIP_LOCAL_POSITION := Vector3(0.0, 1.266, 0.0)
const PREVIEW_BOW_GRIP_SOURCE_LOCAL_POSITION := Vector3(0.0, 0.0, 0.043)
const PREVIEW_BOW_PALM_OFFSET := 0.10
const PREVIEW_BOW_INWARD_OFFSET := 0.04
const PREVIEW_BOW_DOWN_OFFSET := 0.08
const PREVIEW_BOW_STRING_Z := -0.11
const PREVIEW_BOW_DRAW_CLIP := "Ranged_Bow_Draw"
const PREVIEW_BOW_AIM_CLIP := "Ranged_Bow_Aiming_Idle"
const PREVIEW_BOW_RELEASE_CLIP := "Ranged_Bow_Release"
const PREVIEW_BOW_DRAW_SECONDS := 1.3333334
const PREVIEW_BOW_AIM_SECONDS := 0.24
const PREVIEW_BOW_RELEASE_FIRE_SECONDS := 0.12
const PREVIEW_BOW_RELEASE_SECONDS := 1.3333334
const PREVIEW_ARROW_SPEED := 8.8
const PREVIEW_ARROW_LIFT_SPEED := 2.4
const PREVIEW_ARROW_GRAVITY := 5.2
const PREVIEW_ARROW_LIFETIME := 1.55
const PREVIEW_ARROW_REAR_LOCAL_Y := -0.52
const PREVIEW_ARROW_FRONT_LOCAL_Y := 0.64
const PREVIEW_ARROW_TIP_LOCAL_Y := 0.80
const PREVIEW_BOW_PULL_PALM_OFFSET := 0.08
const PREVIEW_BOW_PULL_UP_OFFSET := 0.03
const PREVIEW_CROSSBOW_PALM_OFFSET := 0.035
const PREVIEW_CROSSBOW_IDLE_DOWN_OFFSET := 0.22
const PREVIEW_CROSSBOW_ATTACK_DOWN_OFFSET := 0.02
# The crossbow belongs to the NPC's own RightHand. Never infer that side from
# the camera or pull it toward the torso center: both choices detach the grip
# when the retargeted two-handed clips move across the screen.
const PREVIEW_CROSSBOW_HAND_INWARD_OFFSET := 0.14
const PREVIEW_CROSSBOW_CENTERLINE_OFFSET := 0.04
const MOUNTED_CROSSBOW_CENTERLINE_EXTRA_OFFSET := 0.08
const PREVIEW_CROSSBOW_AIM_CLIP := "Ranged_2H_Aiming"
const PREVIEW_CROSSBOW_SHOOT_CLIP := "Ranged_2H_Shoot"
const PREVIEW_CROSSBOW_RELOAD_CLIP := "Ranged_2H_Reload"
const PREVIEW_CROSSBOW_AIM_SECONDS := 1.60
const PREVIEW_CROSSBOW_SHOOT_FIRE_SECONDS := 0.32
const PREVIEW_CROSSBOW_SHOOT_SECONDS := 1.0666667
const PREVIEW_CROSSBOW_RELOAD_SECONDS := 1.60
const PREVIEW_CROSSBOW_STRING_COCKED_Y := 0.27
const PREVIEW_CROSSBOW_STRING_RELEASED_Y := 0.53
const PREVIEW_CROSSBOW_BOLT_SPEED := 12.5
const PREVIEW_CROSSBOW_BOLT_LIFT_SPEED := 1.15
const PREVIEW_CROSSBOW_BOLT_LIFETIME := 1.35
const DRINK_MUG_GRIP_SOURCE_LOCAL_POSITION := Vector3(-0.16, 0.09, 0.0)
const DRINK_MUG_SCALE := Vector3.ONE * 1.15
const DRINK_MUG_PALM_OFFSET := 0.10
const DRINK_MUG_FORWARD_OFFSET := 0.05
const MEDICAL_BOOK_FORWARD_OFFSET := 0.30
const MEDICAL_BOOK_DOWN_OFFSET := 0.02
const MEDICAL_BOOK_CLINIC_TABLE_FORWARD_OFFSET := 0.42
const MEDICAL_BOOK_CLINIC_TABLE_HEIGHT_OFFSET := 0.15
const MEDICAL_BOOK_TILT_WEIGHT := 0.55
const ENGINEER_GOGGLES_FOREHEAD_MODEL_POSITION := Vector3(0.0, 1.69, 0.275)
const ENGINEER_GOGGLES_WORN_MODEL_POSITION := Vector3(0.0, 1.52, 0.292)
const ENGINEER_GOGGLES_WORN_SCALE := Vector3(1.18, 1.08, 1.0)
const ENGINEER_GOGGLES_TRANSITION_SECONDS := 0.16
const WOODEN_CROSS_LOCAL_POSITION := Vector3(0.0, 0.01, 0.195)
const WOODEN_CROSS_LOCAL_ROTATION_DEGREES := Vector3(-4.946784, 0.614417, -90.05296)
# Glen's resting hammer follows the hips instead of the chest.  The imported
# hammer's positive local Y axis runs from the handle toward the hammer head.
const HAMMER_STOW_LOCAL_POSITION := Vector3(-0.264662, -0.153232, 0.023966)
const HAMMER_STOW_LOCAL_ROTATION_DEGREES := Vector3(-67.44337, -90.08519, -94.86838)
const HAMMER_STOW_SCALE := Vector3.ONE * 0.34
# The imported hammer's thin wooden handle spans roughly local Y
# [-0.479, 0.307], while the bulky head begins near Y=0.568.  Keep the hand
# near the rear of the handle so the palm cannot visually overlap the head.
const HAMMER_HAND_LOCAL_POSITION := Vector3(-0.152, 0.0, 0.055)
const HAMMER_HAND_LOCAL_ROTATION_DEGREES := Vector3(0.0, 0.0, 90.0)
const HAMMER_HAND_SCALE := Vector3.ONE * 0.38
const HAMMER_GRIP_SOURCE_LOCAL_POSITION := Vector3(0.0, -0.4, 0.0)
const HAMMER_HANDLE_REAR_SOURCE_LOCAL_POSITION := Vector3(0.0, -0.478539, 0.0)
const HAMMER_HEAD_NEAR_SOURCE_LOCAL_POSITION := Vector3(0.0, 0.568391, 0.0)
# The imported props do not use their visual grip/brace centers as their roots.
# Keep the calibrated offsets shared by gameplay characters and the developer lab.
const SWORD_GRIP_SOURCE_LOCAL_POSITION := Vector3(0.009753, -0.091156, -0.054012)
# Mounted_Idle places the right-hand bone origin at the outer edge of the
# clenched fist. Pull the authored grip point back toward the forearm so the
# visible handle sits inside the palm while retaining its cavalry direction.
const MOUNTED_SWORD_PALM_INSET := -0.10
# The mounted fist sits visibly below its retargeted hand-bone origin. Lower
# the cavalry-only grip target so the handle, not the guard, crosses the palm.
const MOUNTED_SWORD_GRIP_DOWN_OFFSET := 0.28
# The shared authored grip marker sits too close to the guard for the mounted
# pose. Sample farther back along the handle so aligning that point to the palm
# moves the red-brown grip, rather than the blade side of the guard, into it.
const MOUNTED_SWORD_GRIP_SOURCE_LOCAL_POSITION := SWORD_GRIP_SOURCE_LOCAL_POSITION + Vector3(0.0, -0.22, 0.0)
const MOUNTED_SWORD_FORWARD_LEAN_DEGREES := 10.0
const MOUNTED_ATTACK_GRIP_LOCAL_POSITION := Vector3.ZERO
const MOUNTED_POLEARM_FORWARD_LEAN_DEGREES := 22.0
# Keep the visible grip slightly below and inside the retargeted hand-bone
# origin; that origin sits near the outer knuckles rather than the palm center.
const SWORD_HAND_LOCAL_POSITION := Vector3(-0.069310, 0.079340, 0.019445)
# The imported sword AABB spans local Y -0.257..1.266 and its grip marker is
# at Y -0.091, so the visible blade extends along local +Y. This local rotation
# is only the creation fallback; foot combat overrides the global basis below
# because the retargeted right-hand bone orientation differs between rigs.
const SWORD_HAND_LOCAL_ROTATION_DEGREES := Vector3(0.0, 0.0, 150.0)
# Push the shield another 3 cm toward its facing side so the left hand remains
# completely behind the plate instead of showing through the front surface.
const SHIELD_FOREARM_LOCAL_POSITION := Vector3(0.070131, -0.010137, 0.115153)
const SHIELD_FOREARM_LOCAL_ROTATION_DEGREES := Vector3(5.079137, 52.49611, 98.10695)
const SHIELD_BACK_CENTER_SOURCE_LOCAL_POSITION := Vector3(0.0, -0.066718, -0.072478)
const FOOT_SHIELD_FORWARD_OFFSET := 0.025
const FOOT_SHIELD_DOWN_OFFSET := 0.030
const SWORD_SHIELD_SCALE := Vector3.ONE * 0.72
const ARMOR_SLOT_IDS := {
	"helmet": "iron_helmet",
	"chest": "mail_chest",
	"bracers": "iron_bracers",
	"greaves": "iron_greaves",
}
const ARMOR_SLOTS := ["helmet", "chest", "bracers", "greaves"]
const STATE_CLIPS := {
	"idle": "Idle_A",
	"walk": "Walking_A",
	"run": "Running_A",
	"talk": "Waving",
	"happy": "Cheering",
	"angry": "Melee_1H_Attack_Slice_Horizontal",
	"work": "Hammering",
	"training_instructor": "Melee_Block_Attack",
	"training_practice": "Melee_1H_Attack_Slice_Diagonal",
	"mass_leader": "Waving",
	"seated_prayer": "Sit_Chair_Idle",
	"seated_study": SEATED_STUDY_CLIP,
	"seated_eating": SEATED_EATING_CLIP,
	"drink": DRINK_CLIP,
	"attack": "Melee_1H_Attack_Slice_Horizontal",
	"medical_treatment": "Working_A",
	"hit_react": "Hit_A",
	"unconscious": "Death_A",
	"get_up": "Lie_StandUp",
	"vehicle_seated": MOUNTED_CLIP,
	"mounted_attack": MOUNTED_ATTACK_CLIP,
	"mounted_walk": MOUNTED_WALK_CLIP,
	"mounted_hit_react": MOUNTED_HIT_REACT_CLIP,
	"mounted_training": MOUNTED_TRAINING_CLIP,
	"mounted_fall": "Death_A",
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
	"bow": "res://assets/3d/synty/t0130_pilot/Prop_Bow_01.fbx",
	"drink_mug": "res://assets/3d/quaternius/props/tavern_mug.glb",
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
	"LeftForearm": "LeftLowerArm",
	"RightForearm": "RightLowerArm",
	"LeftShin": "LeftLowerLeg",
	"RightShin": "RightLowerLeg",
	"Mount": "Hips",
}
const DEFAULT_STATE := "idle"
const HIT_REACT_SECONDS := 0.55
const GET_UP_SECONDS := 1.25
const TALK_GESTURE_FALLBACK_SECONDS := 1.25
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
	"drink", "happy", "angry",
	"attack", "medical_treatment", "hit_react", "unconscious", "get_up", "vehicle_seated", "mounted_attack",
	"mounted_walk", "mounted_hit_react", "mounted_training", "mounted_fall", "sleeping"
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
var _locomotion_state := "walk"
var _locomotion_reference_speed := 3.2
var _locomotion_minimum_speed_scale := 0.35
var _locomotion_maximum_speed_scale := 1.6
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
var _foot_sword_attack_attachment_transform := Transform3D.IDENTITY
var _foot_sword_attack_attachment_valid := false
var _mounted_sword_attack_attachment_transform := Transform3D.IDENTITY
var _mounted_sword_attack_attachment_valid := false
var _engineer_goggles_forehead_transform := Transform3D.IDENTITY
var _engineer_goggles_worn_transform := Transform3D.IDENTITY
var _engineer_goggles_mode := "forehead"
var _engineer_goggles_tween: Tween
var _authority_main_weapon_id := ""
var _authority_armor_ids: Dictionary = {}
var _authority_combat_visible := false
var _debug_equipment_preview_active := false
var _debug_preview_main_weapon_id := ""
var _debug_preview_combat_visible := false
var _debug_preview_armor_ids: Dictionary = {}
var _armor_nodes_by_slot: Dictionary = {}
var _helmet_original_character_meshes: Dictionary = {}
var _helmet_filtered_character_meshes: Dictionary = {}
var _helmet_hair_hidden := false
var _armor_masked_character_meshes: Dictionary = {}
var _active_armor_occlusion_key := ""
var _spatial_attachment_pose := ""
var _target_mesh_count := 0
var _physical_bone_simulator: PhysicalBoneSimulator3D
var _blood_particles: GPUParticles3D
var _damage_feedback_count := 0
var _hit_offset := Vector3.ZERO
var _hit_velocity := Vector3.ZERO
var _mounted_fall_active := false
var _mounted_fall_recovering := false
var _mounted_fall_elapsed := 0.0
var _mounted_fall_side := 1.0
var _mounted_fall_landing_offset := Vector3.ZERO
var _mounted_fall_trigger_count := 0
var _removed_headwear_triangle_count := 0
var _last_temporary_presentation_event_id := ""
var _temporary_presentation_event_count := 0
var _processed_temporary_presentation_event_ids: Dictionary = {}
var _temporary_presentation_event_order: Array[String] = []
var _wooden_cross: Node3D
var _rounded_tonsure_hair: Node3D
var _preview_bow_static_string: MeshInstance3D
var _preview_bow_string_front: MeshInstance3D
var _preview_bow_string_rear: MeshInstance3D
var _preview_bow_loaded_arrow: Node3D
var _preview_bow_attack_active := false
var _preview_bow_attack_phase := "idle"
var _preview_bow_phase_elapsed := 0.0
var _preview_bow_arrow_fired := false
var _preview_bow_shot_count := 0
var _preview_bow_nock_pull_hand_distance := -1.0
var _preview_crossbow_string_left: MeshInstance3D
var _preview_crossbow_string_right: MeshInstance3D
var _preview_crossbow_loaded_bolt: Node3D
var _preview_crossbow_attack_active := false
var _preview_crossbow_attack_phase := "idle"
var _preview_crossbow_phase_elapsed := 0.0
var _preview_crossbow_bolt_fired := false
var _preview_crossbow_shot_count := 0
var _combat_attack_sequence := -1
var _combat_attack_cycle_seconds := 0.0
var _combat_attack_impact_seconds := 0.0
var _combat_attack_elapsed_seconds := 0.0
var _combat_attack_playback_multiplier := 1.0
var _combat_attack_phase := "idle"
var _formal_projectile_authority := false
var _combat_time_system: Node
var _preview_crossbow_string_nock_y := PREVIEW_CROSSBOW_STRING_COCKED_Y
var _preview_arrow_projectiles: Array[Dictionary] = []

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
	if not _target_skeleton.skeleton_updated.is_connected(_on_target_skeleton_updated):
		_target_skeleton.skeleton_updated.connect(_on_target_skeleton_updated)
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
		var high_headwear := (
			int(entry["count"]) >= 80
			and minimum.y >= 1.40
			and maximum.y >= 1.60
			and maxf(span.x, span.z) >= 0.35
		)
		var trailing_back_hair := (
			int(entry["count"]) >= 60
			and maximum.y >= 1.45
			and maximum.z <= 0.05
			and maxf(span.x, span.y) >= 0.35
		)
		if high_headwear or trailing_back_hair:
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
	_wooden_cross.position = WOODEN_CROSS_LOCAL_POSITION
	_wooden_cross.rotation = _degrees_to_radians(WOODEN_CROSS_LOCAL_ROTATION_DEGREES)

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
	_add_mounted_animation(library)
	_add_mounted_attack_animation(library)
	_add_mounted_action_animations(library)
	_add_seated_study_animation(library)
	_add_seated_eating_animation(library)
	_add_drinking_animation(library)
	return library


func _add_mounted_animation(library: AnimationLibrary) -> void:
	if not library.has_animation("Sit_Chair_Idle") or library.has_animation(MOUNTED_CLIP):
		return
	var mounted := library.get_animation("Sit_Chair_Idle").duplicate(true) as Animation
	for track_index in range(mounted.get_track_count()):
		if mounted.track_get_type(track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var path := mounted.track_get_path(track_index)
		if path.get_subname_count() < 1:
			continue
		var bone_name := String(path.get_subname(0))
		var spread_degrees := 0.0
		if bone_name == "LeftUpperLeg":
			spread_degrees = -MOUNTED_THIGH_SPREAD_DEGREES
		elif bone_name == "RightUpperLeg":
			spread_degrees = MOUNTED_THIGH_SPREAD_DEGREES
		else:
			continue
		var spread := Quaternion(Vector3.FORWARD, deg_to_rad(spread_degrees))
		for key_index in range(mounted.track_get_key_count(track_index)):
			var source_rotation := mounted.track_get_key_value(track_index, key_index) as Quaternion
			mounted.track_set_key_value(track_index, key_index, (spread * source_rotation).normalized())
	mounted.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(MOUNTED_CLIP, mounted)


func _add_mounted_attack_animation(library: AnimationLibrary) -> void:
	_add_mounted_upper_body_animation(library, MOUNTED_ATTACK_CLIP, str(STATE_CLIPS.attack), Animation.LOOP_NONE)
	_apply_mounted_spine_forward_lean(library, MOUNTED_ATTACK_CLIP, MOUNTED_SWORD_FORWARD_LEAN_DEGREES)
	_add_mounted_upper_body_animation(library, MOUNTED_POLEARM_ATTACK_CLIP, PREVIEW_POLEARM_THRUST_CLIP, Animation.LOOP_NONE)
	_apply_mounted_spine_forward_lean(library, MOUNTED_POLEARM_ATTACK_CLIP, MOUNTED_POLEARM_FORWARD_LEAN_DEGREES)
	_add_mounted_upper_body_animation(library, MOUNTED_BOW_DRAW_CLIP, PREVIEW_BOW_DRAW_CLIP, Animation.LOOP_NONE)
	_add_mounted_upper_body_animation(library, MOUNTED_BOW_AIM_CLIP, PREVIEW_BOW_AIM_CLIP, Animation.LOOP_LINEAR)
	_add_mounted_upper_body_animation(library, MOUNTED_BOW_RELEASE_CLIP, PREVIEW_BOW_RELEASE_CLIP, Animation.LOOP_NONE)
	_add_mounted_upper_body_animation(library, MOUNTED_CROSSBOW_AIM_CLIP, PREVIEW_CROSSBOW_AIM_CLIP, Animation.LOOP_LINEAR)
	_add_mounted_upper_body_animation(library, MOUNTED_CROSSBOW_SHOOT_CLIP, PREVIEW_CROSSBOW_SHOOT_CLIP, Animation.LOOP_NONE)
	_add_mounted_upper_body_animation(library, MOUNTED_CROSSBOW_RELOAD_CLIP, PREVIEW_CROSSBOW_RELOAD_CLIP, Animation.LOOP_NONE)
	for ranged_pair in [
		[MOUNTED_BOW_DRAW_CLIP, PREVIEW_BOW_DRAW_CLIP],
		[MOUNTED_BOW_AIM_CLIP, PREVIEW_BOW_AIM_CLIP],
		[MOUNTED_BOW_RELEASE_CLIP, PREVIEW_BOW_RELEASE_CLIP],
		[MOUNTED_CROSSBOW_AIM_CLIP, PREVIEW_CROSSBOW_AIM_CLIP],
		[MOUNTED_CROSSBOW_SHOOT_CLIP, PREVIEW_CROSSBOW_SHOOT_CLIP],
		[MOUNTED_CROSSBOW_RELOAD_CLIP, PREVIEW_CROSSBOW_RELOAD_CLIP],
	]:
		_transfer_foot_hips_rotation_to_mounted_spine(library, str(ranged_pair[0]), str(ranged_pair[1]))


func _apply_mounted_spine_forward_lean(library: AnimationLibrary, clip_name: String, lean_degrees: float) -> void:
	if not library.has_animation(clip_name):
		return
	var mounted_attack := library.get_animation(clip_name)
	var forward_pitch := Quaternion(Vector3.RIGHT, deg_to_rad(lean_degrees))
	# Keep the complete standing thrust motion on Spine/Chest/Head. Only bias the
	# animated spine forward so the rider coordinates with the two-handed stab
	# without inheriting the source clip's horseback-looking backward lean.
	for track_index in mounted_attack.get_track_count():
		if mounted_attack.track_get_type(track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var track_path := mounted_attack.track_get_path(track_index)
		if track_path.get_subname_count() < 1 or String(track_path.get_subname(0)) != "Spine":
			continue
		for key_index in mounted_attack.track_get_key_count(track_index):
			var standing_rotation := mounted_attack.track_get_key_value(track_index, key_index) as Quaternion
			mounted_attack.track_set_key_value(track_index, key_index, (standing_rotation * forward_pitch).normalized())


func _transfer_foot_hips_rotation_to_mounted_spine(library: AnimationLibrary, mounted_clip: String, foot_clip: String) -> void:
	if not library.has_animation(mounted_clip) or not library.has_animation(foot_clip):
		return
	var mounted_animation := library.get_animation(mounted_clip)
	var foot_animation := library.get_animation(foot_clip)
	var mounted_hips_track := -1
	var mounted_spine_track := -1
	var foot_hips_track := -1
	for track_index in mounted_animation.get_track_count():
		if mounted_animation.track_get_type(track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var track_path := mounted_animation.track_get_path(track_index)
		if track_path.get_subname_count() < 1:
			continue
		match String(track_path.get_subname(0)):
			"Hips":
				mounted_hips_track = track_index
			"Spine":
				mounted_spine_track = track_index
	for track_index in foot_animation.get_track_count():
		if foot_animation.track_get_type(track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var track_path := foot_animation.track_get_path(track_index)
		if track_path.get_subname_count() > 0 and String(track_path.get_subname(0)) == "Hips":
			foot_hips_track = track_index
			break
	if mounted_hips_track < 0 or mounted_spine_track < 0 or foot_hips_track < 0:
		return
	# Foot ranged clips turn the whole firing stance on Hips. Mounted Hips must
	# remain the parent of static straddle legs, so transfer that rotation into
	# Spine: mounted_hips * adjusted_spine == foot_hips * foot_spine.
	for key_index in mounted_animation.track_get_key_count(mounted_spine_track):
		var key_time := mounted_animation.track_get_key_time(mounted_spine_track, key_index)
		var mounted_hips_rotation := mounted_animation.rotation_track_interpolate(mounted_hips_track, key_time)
		var foot_hips_rotation := foot_animation.rotation_track_interpolate(foot_hips_track, key_time)
		var foot_spine_rotation := mounted_animation.track_get_key_value(mounted_spine_track, key_index) as Quaternion
		var adjusted_spine_rotation := (mounted_hips_rotation.inverse() * foot_hips_rotation * foot_spine_rotation).normalized()
		mounted_animation.track_set_key_value(mounted_spine_track, key_index, adjusted_spine_rotation)


func _add_mounted_action_animations(library: AnimationLibrary) -> void:
	if library.has_animation(MOUNTED_CLIP) and not library.has_animation(MOUNTED_WALK_CLIP):
		var mounted_walk := library.get_animation(MOUNTED_CLIP).duplicate(true) as Animation
		mounted_walk.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(MOUNTED_WALK_CLIP, mounted_walk)
	_add_mounted_upper_body_animation(library, MOUNTED_HIT_REACT_CLIP, "Hit_A", Animation.LOOP_NONE)
	_add_mounted_upper_body_animation(
		library,
		MOUNTED_TRAINING_CLIP,
		"Melee_1H_Attack_Slice_Diagonal",
		Animation.LOOP_LINEAR
	)

func _add_mounted_upper_body_animation(
	library: AnimationLibrary,
	target_clip: String,
	source_clip: String,
	loop_mode: Animation.LoopMode
) -> void:
	if not library.has_animation(MOUNTED_CLIP) or not library.has_animation(source_clip) or library.has_animation(target_clip):
		return
	var mounted_action := library.get_animation(MOUNTED_CLIP).duplicate(true) as Animation
	var standing_action := library.get_animation(source_clip)
	for source_track_index in range(standing_action.get_track_count()):
		if standing_action.track_get_type(source_track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var source_path := standing_action.track_get_path(source_track_index)
		if source_path.get_subname_count() < 1:
			continue
		if not MOUNTED_ATTACK_UPPER_BODY_BONES.has(String(source_path.get_subname(0))):
			continue
		for target_track_index in range(mounted_action.get_track_count() - 1, -1, -1):
			if mounted_action.track_get_path(target_track_index) == source_path:
				mounted_action.remove_track(target_track_index)
		var target_track_index := mounted_action.add_track(Animation.TYPE_ROTATION_3D)
		mounted_action.track_set_path(target_track_index, source_path)
		mounted_action.track_set_interpolation_type(target_track_index, standing_action.track_get_interpolation_type(source_track_index))
		mounted_action.track_set_interpolation_loop_wrap(target_track_index, standing_action.track_get_interpolation_loop_wrap(source_track_index))
		for key_index in range(standing_action.track_get_key_count(source_track_index)):
			var source_time := standing_action.track_get_key_time(source_track_index, key_index)
			mounted_action.track_insert_key(
				target_track_index,
				source_time,
				standing_action.track_get_key_value(source_track_index, key_index),
				standing_action.track_get_key_transition(source_track_index, key_index)
			)
	mounted_action.length = standing_action.length
	mounted_action.loop_mode = loop_mode
	library.add_animation(target_clip, mounted_action)


func _add_seated_study_animation(library: AnimationLibrary) -> void:
	if not library.has_animation("Sit_Chair_Idle") or library.has_animation(SEATED_STUDY_CLIP):
		return
	var study := library.get_animation("Sit_Chair_Idle").duplicate(true) as Animation
	for track_index in range(study.get_track_count() - 1, -1, -1):
		if study.track_get_type(track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var track_path := study.track_get_path(track_index)
		if track_path.get_subname_count() < 1:
			continue
		if not SEATED_STUDY_STILL_ARM_BONES.has(String(track_path.get_subname(0))):
			continue
		if study.track_get_key_count(track_index) < 1:
			continue
		var resting_rotation: Quaternion = study.track_get_key_value(track_index, 0)
		var interpolation_type := study.track_get_interpolation_type(track_index)
		var interpolation_loop_wrap := study.track_get_interpolation_loop_wrap(track_index)
		study.remove_track(track_index)
		var still_track_index := study.add_track(Animation.TYPE_ROTATION_3D)
		study.track_set_path(still_track_index, track_path)
		study.track_set_interpolation_type(still_track_index, interpolation_type)
		study.track_set_interpolation_loop_wrap(still_track_index, interpolation_loop_wrap)
		study.track_insert_key(still_track_index, 0.0, resting_rotation)
	study.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(SEATED_STUDY_CLIP, study)


func _add_seated_eating_animation(library: AnimationLibrary) -> void:
	if not library.has_animation("Sit_Chair_Idle") or not library.has_animation("Use_Item") or library.has_animation(SEATED_EATING_CLIP):
		return
	var seated := library.get_animation("Sit_Chair_Idle").duplicate(true) as Animation
	var eating := library.get_animation("Use_Item")
	for source_track_index in range(eating.get_track_count()):
		if eating.track_get_type(source_track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var source_path := eating.track_get_path(source_track_index)
		if source_path.get_subname_count() < 1:
			continue
		var bone_name := String(source_path.get_subname(0))
		if not SEATED_EATING_UPPER_BODY_BONES.has(bone_name):
			continue
		for target_track_index in range(seated.get_track_count() - 1, -1, -1):
			if seated.track_get_path(target_track_index) == source_path:
				seated.remove_track(target_track_index)
		var target_track_index := seated.add_track(Animation.TYPE_ROTATION_3D)
		seated.track_set_path(target_track_index, source_path)
		seated.track_set_interpolation_type(target_track_index, eating.track_get_interpolation_type(source_track_index))
		seated.track_set_interpolation_loop_wrap(target_track_index, eating.track_get_interpolation_loop_wrap(source_track_index))
		for key_index in range(eating.track_get_key_count(source_track_index)):
			seated.track_insert_key(
				target_track_index,
				eating.track_get_key_time(source_track_index, key_index),
				eating.track_get_key_value(source_track_index, key_index),
				eating.track_get_key_transition(source_track_index, key_index)
			)
	seated.length = eating.length
	seated.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(SEATED_EATING_CLIP, seated)


func _add_drinking_animation(library: AnimationLibrary) -> void:
	if not library.has_animation("Use_Item") or library.has_animation(DRINK_CLIP):
		return
	var drinking := library.get_animation("Use_Item").duplicate(true) as Animation
	drinking.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(DRINK_CLIP, drinking)


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
		_add_equipment("hammer", "RightHand", HAMMER_HAND_LOCAL_POSITION, HAMMER_HAND_LOCAL_ROTATION_DEGREES * PI / 180.0, HAMMER_HAND_SCALE)
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
		_ensure_sword_shield_nodes()
		_set_equipment_visible("sword", false)
		_set_equipment_visible("shield", false)
		_sync_engineering_kit_visibility("idle", "")
	elif equipment_mode in ["sword_shield", "synced_sword_shield"]:
		_ensure_sword_shield_nodes()
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


func _ensure_sword_shield_nodes() -> void:
	if not _equipment_nodes.has("sword"):
		_add_equipment(
			"sword",
			"RightHand",
			SWORD_HAND_LOCAL_POSITION,
			_degrees_to_radians(SWORD_HAND_LOCAL_ROTATION_DEGREES),
			SWORD_SHIELD_SCALE
		)
	if not _equipment_nodes.has("shield"):
		_add_equipment(
			"shield",
			"LeftHand",
			SHIELD_FOREARM_LOCAL_POSITION,
			_degrees_to_radians(SHIELD_FOREARM_LOCAL_ROTATION_DEGREES),
			SWORD_SHIELD_SCALE
		)


func _ensure_preview_weapon_node(weapon_id: String) -> void:
	_ensure_combat_weapon_node(weapon_id)


func _ensure_combat_weapon_node(weapon_id: String) -> void:
	if weapon_id == "sword_shield":
		_ensure_sword_shield_nodes()
		return
	if weapon_id == "polearm" and not _equipment_nodes.has("polearm"):
		_add_preview_polearm()
	elif weapon_id == "bow" and not _equipment_nodes.has("bow"):
		_add_preview_bow()
	elif weapon_id == "crossbow" and not _equipment_nodes.has("crossbow"):
		_add_preview_crossbow()


func _add_preview_polearm() -> void:
	var socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if socket == null:
		return
	var polearm := Node3D.new()
	polearm.name = "Polearm"
	polearm.visible = false
	socket.add_child(polearm)
	polearm.scale = PREVIEW_POLEARM_SCALE
	var wood := _new_weapon_material("PolearmAshWood", Color(0.34, 0.15, 0.055, 1.0))
	var iron := _new_weapon_material("PolearmForgedIron", Color(0.27, 0.29, 0.28, 1.0), 0.42)
	_add_weapon_cylinder(polearm, "AshShaft", PREVIEW_POLEARM_SHAFT_REAR_LOCAL_POSITION, PREVIEW_POLEARM_SHAFT_FRONT_LOCAL_POSITION, 0.035, wood)
	_add_weapon_cylinder(polearm, "IronCollar", Vector3(0.0, 1.76, 0.0), Vector3(0.0, 1.92, 0.0), 0.052, iron)
	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = 0.095
	spike_mesh.height = 0.38
	spike_mesh.radial_segments = 6
	spike_mesh.material = iron
	var spike := MeshInstance3D.new()
	spike.name = "SpearPoint"
	spike.mesh = spike_mesh
	spike.position = Vector3(0.0, 2.08, 0.0)
	polearm.add_child(spike)
	var blade_mesh := PrismMesh.new()
	blade_mesh.size = Vector3(0.30, 0.40, 0.065)
	blade_mesh.material = iron
	var blade := MeshInstance3D.new()
	blade.name = "HalberdBlade"
	blade.mesh = blade_mesh
	blade.position = Vector3(0.13, 1.88, 0.0)
	blade.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	polearm.add_child(blade)
	_add_weapon_box(polearm, "ButtCap", Vector3(0.0, -0.69, 0.0), Vector3(0.09, 0.10, 0.09), Vector3.ZERO, iron)
	_equipment_nodes["polearm"] = polearm


func _add_preview_bow() -> void:
	_add_equipment("bow", "LeftHand", Vector3.ZERO, Vector3.ZERO, PREVIEW_BOW_SCALE)
	var bow := _equipment_nodes.get("bow") as Node3D
	if bow == null:
		return
	var string_material := _new_weapon_material("BowString", Color(0.62, 0.54, 0.38, 1.0))
	_preview_bow_static_string = _add_weapon_cylinder(
		bow,
		"BowString",
		Vector3(0.0, -0.91, PREVIEW_BOW_STRING_Z),
		Vector3(0.0, 0.91, PREVIEW_BOW_STRING_Z),
		0.011,
		string_material
	)
	_preview_bow_string_rear = _add_weapon_cylinder(bow, "BowStringRear", Vector3(0.0, -0.91, PREVIEW_BOW_STRING_Z), Vector3(0.0, 0.0, PREVIEW_BOW_STRING_Z), 0.011, string_material)
	_preview_bow_string_front = _add_weapon_cylinder(bow, "BowStringFront", Vector3(0.0, 0.0, PREVIEW_BOW_STRING_Z), Vector3(0.0, 0.91, PREVIEW_BOW_STRING_Z), 0.011, string_material)
	_preview_bow_string_rear.visible = false
	_preview_bow_string_front.visible = false
	var arrow_material := _new_weapon_material("PreviewArrowWood", Color(0.36, 0.18, 0.065, 1.0))
	var arrow_iron := _new_weapon_material("PreviewArrowIron", Color(0.25, 0.27, 0.26, 1.0), 0.38)
	var fletching := _new_weapon_material("PreviewArrowFletching", Color(0.58, 0.16, 0.10, 1.0))
	_preview_bow_loaded_arrow = _build_preview_arrow(bow, "LoadedArrow", arrow_material, arrow_iron, fletching, true)
	_preview_bow_loaded_arrow.visible = false


func _build_preview_arrow(parent: Node3D, node_name: String, wood: Material, iron: Material, fletching: Material, along_local_y: bool) -> Node3D:
	var arrow := Node3D.new()
	arrow.name = node_name
	parent.add_child(arrow)
	if along_local_y:
		_add_weapon_cylinder(arrow, "Shaft", Vector3(0.0, PREVIEW_ARROW_REAR_LOCAL_Y, 0.0), Vector3(0.0, PREVIEW_ARROW_FRONT_LOCAL_Y, 0.0), 0.014, wood)
		_add_preview_arrow_head(arrow, Vector3(0.0, (PREVIEW_ARROW_FRONT_LOCAL_Y + PREVIEW_ARROW_TIP_LOCAL_Y) * 0.5, 0.0), Vector3.ZERO, iron)
		_add_weapon_box(arrow, "Fletching", Vector3(0.0, -0.44, 0.0), Vector3(0.12, 0.20, 0.018), Vector3.ZERO, fletching)
	else:
		_add_weapon_cylinder(arrow, "Shaft", Vector3(0.0, 0.0, -0.34), Vector3(0.0, 0.0, 0.42), 0.014, wood)
		_add_preview_arrow_head(arrow, Vector3(0.0, 0.0, 0.50), Vector3(90.0, 0.0, 0.0), iron)
		_add_weapon_box(arrow, "Fletching", Vector3(0.0, 0.0, -0.28), Vector3(0.10, 0.018, 0.16), Vector3.ZERO, fletching)
	return arrow


func _add_preview_arrow_head(parent: Node3D, local_position: Vector3, rotation_degrees: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.052
	mesh.height = PREVIEW_ARROW_TIP_LOCAL_Y - PREVIEW_ARROW_FRONT_LOCAL_Y
	mesh.radial_segments = 6
	mesh.material = material
	var arrow_head := MeshInstance3D.new()
	arrow_head.name = "ArrowHead"
	arrow_head.mesh = mesh
	arrow_head.position = local_position
	arrow_head.rotation_degrees = rotation_degrees
	parent.add_child(arrow_head)
	return arrow_head


func _add_preview_crossbow() -> void:
	var socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if socket == null:
		return
	var crossbow := Node3D.new()
	crossbow.name = "Crossbow"
	crossbow.visible = false
	socket.add_child(crossbow)
	crossbow.scale = PREVIEW_CROSSBOW_SCALE
	var wood := _new_weapon_material("CrossbowWalnut", Color(0.31, 0.12, 0.035, 1.0))
	var light_wood := _new_weapon_material("CrossbowLimbWood", Color(0.48, 0.25, 0.085, 1.0))
	var iron := _new_weapon_material("CrossbowForgedIron", Color(0.25, 0.27, 0.26, 1.0), 0.38)
	var string_material := _new_weapon_material("CrossbowString", Color(0.11, 0.075, 0.045, 1.0))
	_add_weapon_box(crossbow, "WoodenStock", Vector3(0.0, 0.20, 0.0), Vector3(0.12, 0.86, 0.13), Vector3.ZERO, wood)
	_add_weapon_box(crossbow, "ShoulderStock", Vector3(0.0, -0.28, 0.0), Vector3(0.20, 0.30, 0.16), Vector3(0.0, 0.0, -8.0), wood)
	_add_weapon_box(crossbow, "LeftLimb", Vector3(-0.30, 0.48, 0.0), Vector3(0.58, 0.075, 0.075), Vector3(0.0, 0.0, 10.0), light_wood)
	_add_weapon_box(crossbow, "RightLimb", Vector3(0.30, 0.48, 0.0), Vector3(0.58, 0.075, 0.075), Vector3(0.0, 0.0, -10.0), light_wood)
	_add_weapon_box(crossbow, "IronLock", Vector3(0.0, 0.18, 0.08), Vector3(0.18, 0.18, 0.055), Vector3.ZERO, iron)
	_add_weapon_box(crossbow, "Trigger", Vector3(0.0, 0.02, 0.12), Vector3(0.035, 0.16, 0.04), Vector3(18.0, 0.0, 0.0), iron)
	_preview_crossbow_string_left = _add_weapon_cylinder(crossbow, "LeftString", Vector3(-0.58, 0.53, 0.0), Vector3(0.0, PREVIEW_CROSSBOW_STRING_COCKED_Y, 0.0), 0.009, string_material)
	_preview_crossbow_string_right = _add_weapon_cylinder(crossbow, "RightString", Vector3(0.58, 0.53, 0.0), Vector3(0.0, PREVIEW_CROSSBOW_STRING_COCKED_Y, 0.0), 0.009, string_material)
	_preview_crossbow_loaded_bolt = _build_preview_crossbow_bolt(crossbow, "LoadedBolt", light_wood, iron)
	_preview_crossbow_loaded_bolt.position.z = 0.105
	_equipment_nodes["crossbow"] = crossbow


func _build_preview_crossbow_bolt(parent: Node3D, node_name: String, wood: Material, iron: Material) -> Node3D:
	var bolt := Node3D.new()
	bolt.name = node_name
	parent.add_child(bolt)
	_add_weapon_cylinder(bolt, "BoltShaft", Vector3(0.0, 0.05, 0.0), Vector3(0.0, 0.76, 0.0), 0.014, wood)
	var bolt_tip_mesh := CylinderMesh.new()
	bolt_tip_mesh.top_radius = 0.0
	bolt_tip_mesh.bottom_radius = 0.035
	bolt_tip_mesh.height = 0.12
	bolt_tip_mesh.radial_segments = 5
	bolt_tip_mesh.material = iron
	var bolt_tip := MeshInstance3D.new()
	bolt_tip.name = "BoltPoint"
	bolt_tip.mesh = bolt_tip_mesh
	bolt_tip.position = Vector3(0.0, 0.82, 0.0)
	bolt.add_child(bolt_tip)
	_add_weapon_box(bolt, "BoltFletching", Vector3(0.0, 0.11, 0.0), Vector3(0.10, 0.16, 0.018), Vector3.ZERO, wood)
	return bolt


func _new_weapon_material(material_name: String, color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.82 if metallic <= 0.0 else 0.58
	return material


func _ensure_armor_nodes() -> void:
	if not _armor_nodes_by_slot.is_empty() or _target_skeleton == null:
		return
	var packed := load(SYNTY_KNIGHT_ARMOR_EXTRACTOR.SOURCE_SCENE_PATH) as PackedScene
	var source_root := packed.instantiate() as Node3D if packed != null else null
	if source_root == null:
		push_warning("Synty knight armor source could not be loaded")
		return
	var source_skeleton := source_root.find_child("Skeleton3D", true, false) as Skeleton3D
	var source_mesh_instance := source_root.find_child("SK_Knights_Dark_01", true, false) as MeshInstance3D
	if source_skeleton == null or source_mesh_instance == null or not source_mesh_instance.mesh is ArrayMesh:
		source_root.free()
		push_warning("Synty knight armor source is missing its skinned mesh contract")
		return
	var slot_meshes: Dictionary = SYNTY_KNIGHT_ARMOR_EXTRACTOR.extract_slot_meshes(
		source_mesh_instance.mesh as ArrayMesh,
		source_skeleton
	)
	var remapped_skin: Skin = SYNTY_KNIGHT_ARMOR_EXTRACTOR.duplicate_remapped_skin(
		source_mesh_instance.skin,
		SYNTY_BONE_MAP
	)
	for slot in ARMOR_SLOTS:
		var extracted_mesh := slot_meshes.get(slot) as ArrayMesh
		if extracted_mesh == null:
			continue
		var armor_mesh := MeshInstance3D.new()
		armor_mesh.name = "SyntyKnight%sArmor" % slot.to_pascal_case()
		armor_mesh.mesh = extracted_mesh
		armor_mesh.skin = remapped_skin
		armor_mesh.skeleton = NodePath("..")
		armor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		armor_mesh.visible = false
		armor_mesh.set_meta("synty_extracted_armor", true)
		armor_mesh.set_meta("armor_source", SYNTY_KNIGHT_ARMOR_EXTRACTOR.SOURCE_SCENE_PATH)
		_target_skeleton.add_child(armor_mesh)
		_armor_nodes_by_slot[slot] = [armor_mesh]
	source_root.free()
	_sync_armor_visibility(_desired_state)


func _sync_armor_visibility(state_name: String) -> void:
	if _armor_nodes_by_slot.is_empty():
		return
	var selected_ids := _debug_preview_armor_ids if _debug_equipment_preview_active else _authority_armor_ids
	var combat_visible := _debug_preview_combat_visible if _debug_equipment_preview_active else _authority_combat_visible
	var state_allows := state_name != "sleeping"
	var helmet_visible := false
	var visible_slots: Array[String] = []
	for slot in ARMOR_SLOTS:
		var expected_id := str(ARMOR_SLOT_IDS.get(slot, ""))
		var slot_visible := combat_visible and state_allows and str(selected_ids.get(slot, "")) == expected_id
		if slot == "helmet":
			helmet_visible = slot_visible
		if slot_visible:
			visible_slots.append(slot)
		for raw_part in (_armor_nodes_by_slot.get(slot, []) as Array):
			var part := raw_part as Node3D
			if part != null:
				part.visible = slot_visible
	_sync_character_mesh_armor_occlusion(visible_slots)
	if _rounded_tonsure_hair != null:
		_rounded_tonsure_hair.visible = not helmet_visible
	_helmet_hair_hidden = helmet_visible


func _sync_character_mesh_armor_occlusion(visible_slots: Array[String]) -> void:
	if _target_skeleton == null:
		return
	var sorted_slots := visible_slots.duplicate()
	sorted_slots.sort()
	var mesh_slots := sorted_slots.duplicate()
	if (
		sorted_slots.has("greaves")
		and appearance_id in ["lina_doctor_chibi_v1", "marcel_priest_chibi_v1"]
	):
		mesh_slots.append("hide_lower_robe")
	var occlusion_key := "+".join(mesh_slots)
	if _active_armor_occlusion_key == occlusion_key:
		return
	_active_armor_occlusion_key = occlusion_key
	for raw_mesh in _target_skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if (
			mesh_instance == null
			or mesh_instance.get_meta("synty_extracted_armor", false)
			or mesh_instance.skin == null
			or not mesh_instance.mesh is ArrayMesh
		):
			continue
		var instance_key := mesh_instance.get_instance_id()
		if not _helmet_original_character_meshes.has(instance_key):
			_helmet_original_character_meshes[instance_key] = mesh_instance.mesh
		var original_mesh := _helmet_original_character_meshes[instance_key] as ArrayMesh
		if occlusion_key.is_empty():
			mesh_instance.mesh = original_mesh
			continue
		var armor_base_mesh := original_mesh
		if mesh_slots.has("helmet"):
			if not _helmet_filtered_character_meshes.has(instance_key):
				var filtered_headwear := _build_mesh_without_detached_headwear(original_mesh)
				_helmet_filtered_character_meshes[instance_key] = filtered_headwear if filtered_headwear != null else original_mesh
			armor_base_mesh = _helmet_filtered_character_meshes[instance_key] as ArrayMesh
		var variant_key := "%s:%s" % [str(instance_key), occlusion_key]
		if not _armor_masked_character_meshes.has(variant_key):
			_armor_masked_character_meshes[variant_key] = SYNTY_KNIGHT_ARMOR_EXTRACTOR.build_character_mesh_with_armor_occlusion(
				armor_base_mesh,
				_target_skeleton,
				mesh_slots
			)
		mesh_instance.mesh = _armor_masked_character_meshes[variant_key]


func _set_helmet_hair_hidden(hidden: bool) -> void:
	if _target_skeleton == null or _helmet_hair_hidden == hidden:
		return
	_helmet_hair_hidden = hidden
	for raw_mesh in _target_skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		# Armor primitives have no Skin. Only filter authored skinned character
		# geometry, where hairstyles and old headwear are detached topology islands.
		if (
			mesh_instance == null
			or mesh_instance.get_meta("synty_extracted_armor", false)
			or mesh_instance.skin == null
			or not mesh_instance.mesh is ArrayMesh
		):
			continue
		var instance_key := mesh_instance.get_instance_id()
		if not _helmet_original_character_meshes.has(instance_key):
			_helmet_original_character_meshes[instance_key] = mesh_instance.mesh
		if hidden:
			if not _helmet_filtered_character_meshes.has(instance_key):
				var filtered := _build_mesh_without_detached_headwear(mesh_instance.mesh as ArrayMesh)
				_helmet_filtered_character_meshes[instance_key] = filtered if filtered != null else mesh_instance.mesh
			mesh_instance.mesh = _helmet_filtered_character_meshes[instance_key]
		else:
			mesh_instance.mesh = _helmet_original_character_meshes[instance_key]


func _add_weapon_box(parent: Node3D, part_name: String, local_position: Vector3, size: Vector3, rotation_degrees: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = local_position
	part.rotation_degrees = rotation_degrees
	parent.add_child(part)
	return part


func _add_weapon_cylinder(parent: Node3D, part_name: String, start: Vector3, finish: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var direction := finish - start
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 8
	mesh.material = material
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = (start + finish) * 0.5
	if direction.length_squared() > 0.000001:
		part.quaternion = Quaternion(Vector3.UP, direction.normalized())
	parent.add_child(part)
	return part


func _degrees_to_radians(degrees: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


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
	var mount_socket := _equipment_sockets.get("Mount") as BoneAttachment3D
	if body_socket == null or left_hand_socket == null or right_hand_socket == null or mount_socket == null:
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
	pouch.position = Vector3(0.25, 0.64, 0.03)
	pouch.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	satchel.add_child(pouch)
	var flap_mesh := BoxMesh.new()
	flap_mesh.size = Vector3(0.31, 0.085, 0.135)
	flap_mesh.material = dark_leather_material
	var flap := MeshInstance3D.new()
	flap.name = "PouchFlap"
	flap.mesh = flap_mesh
	flap.position = Vector3(0.25, 0.735, 0.03)
	flap.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	satchel.add_child(flap)
	var patch_vertical_mesh := BoxMesh.new()
	patch_vertical_mesh.size = Vector3(0.018, 0.14, 0.055)
	patch_vertical_mesh.material = linen_material
	var patch_vertical := MeshInstance3D.new()
	patch_vertical.name = "LinenMarkVertical"
	patch_vertical.mesh = patch_vertical_mesh
	patch_vertical.position = Vector3(0.321, 0.645, 0.03)
	satchel.add_child(patch_vertical)
	var patch_horizontal_mesh := BoxMesh.new()
	patch_horizontal_mesh.size = Vector3(0.018, 0.055, 0.14)
	patch_horizontal_mesh.material = linen_material
	var patch_horizontal := MeshInstance3D.new()
	patch_horizontal.name = "LinenMarkHorizontal"
	patch_horizontal.mesh = patch_horizontal_mesh
	patch_horizontal.position = Vector3(0.322, 0.645, 0.03)
	satchel.add_child(patch_horizontal)
	_equipment_nodes["medical_satchel"] = satchel

	var book := Node3D.new()
	book.name = "MedicalBook"
	book.visible = false
	mount_socket.add_child(book)
	var cover_mesh := BoxMesh.new()
	cover_mesh.size = Vector3(0.27, 0.025, 0.35)
	cover_mesh.material = leather_material
	var pages_mesh := BoxMesh.new()
	pages_mesh.size = Vector3(0.245, 0.035, 0.315)
	pages_mesh.material = page_material
	for side in [-1.0, 1.0]:
		var page_roll: float = -5.0 * float(side)
		var cover := MeshInstance3D.new()
		cover.name = "LeftLeatherCover" if side < 0.0 else "RightLeatherCover"
		cover.mesh = cover_mesh
		cover.position = Vector3(0.137 * side, -0.015, 0.0)
		cover.rotation_degrees.z = page_roll
		book.add_child(cover)
		var pages := MeshInstance3D.new()
		pages.name = "LeftPages" if side < 0.0 else "RightPages"
		pages.mesh = pages_mesh
		pages.position = Vector3(0.13 * side, 0.012, 0.0)
		pages.rotation_degrees.z = page_roll
		book.add_child(pages)
	var ink_material := StandardMaterial3D.new()
	ink_material.albedo_color = Color(0.16, 0.11, 0.075, 1.0)
	ink_material.roughness = 0.96
	for side in [-1.0, 1.0]:
		for row in [-0.09, 0.0, 0.09]:
			var line_mesh := BoxMesh.new()
			line_mesh.size = Vector3(0.15, 0.006, 0.012)
			line_mesh.material = ink_material
			var line := MeshInstance3D.new()
			line.name = "MedicalNoteLine"
			line.mesh = line_mesh
			line.position = Vector3(0.13 * side, 0.035, row)
			line.rotation_degrees.z = -5.0 * side
			book.add_child(line)
	var mark_material := StandardMaterial3D.new()
	mark_material.albedo_color = Color(0.62, 0.075, 0.055, 1.0)
	mark_material.roughness = 0.9
	var medical_mark_sizes := [Vector3(0.025, 0.007, 0.105), Vector3(0.095, 0.007, 0.025)]
	for mark_index in range(medical_mark_sizes.size()):
		var mark_mesh := BoxMesh.new()
		mark_mesh.size = medical_mark_sizes[mark_index]
		mark_mesh.material = mark_material
		var mark := MeshInstance3D.new()
		mark.name = "MedicalCrossMarkVertical" if mark_index == 0 else "MedicalCrossMarkHorizontal"
		mark.mesh = mark_mesh
		mark.position = Vector3(0.13, 0.042, 0.0)
		book.add_child(mark)
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
	var left_pouch: MeshInstance3D
	var right_pouch: MeshInstance3D
	for side in [-1.0, 1.0]:
		var pouch := MeshInstance3D.new()
		pouch.name = "ToolPouchLeft" if side < 0.0 else "ToolPouchRight"
		pouch.mesh = pouch_mesh
		pouch.position = Vector3(ENGINEER_TOOL_POUCH_SIDE_OFFSET * side, 0.57, ENGINEER_TOOL_POUCH_FORWARD_OFFSET)
		pouch.rotation_degrees = Vector3(0.0, -8.0 * side, 0.0)
		tool_belt.add_child(pouch)
		if side < 0.0:
			left_pouch = pouch
		else:
			right_pouch = pouch
	var rule_mesh := BoxMesh.new()
	rule_mesh.size = Vector3(0.038, 0.31, 0.028)
	rule_mesh.material = wood_material
	var rule := MeshInstance3D.new()
	rule.name = "FoldingRule"
	rule.mesh = rule_mesh
	rule.position = Vector3(-0.055, 0.095, 0.015)
	rule.rotation_degrees = Vector3(0.0, 0.0, 13.0)
	left_pouch.add_child(rule)
	var wedge_mesh := PrismMesh.new()
	wedge_mesh.size = Vector3(0.075, 0.17, 0.06)
	wedge_mesh.material = wood_material
	var wedge := MeshInstance3D.new()
	wedge.name = "WoodWedge"
	wedge.mesh = wedge_mesh
	wedge.position = Vector3(0.055, 0.075, 0.015)
	wedge.rotation_degrees = Vector3(0.0, 0.0, -9.0)
	right_pouch.add_child(wedge)
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
	var previous_states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
	var states: Dictionary = npc_profile.get("states", {}) if npc_profile.get("states", {}) is Dictionary else {}
	var next_hp := int(states.get("hp", _previous_hp if _previous_hp >= 0 else 0))
	var next_unconscious := bool(states.get("unconscious", false))
	var initialized := _previous_hp >= 0
	var took_damage := initialized and next_hp < _previous_hp
	var revived := initialized and _previous_unconscious and not next_unconscious
	var started_mounted_fall := (
		initialized
		and not _previous_unconscious
		and next_unconscious
		and bool(previous_states.get("combat_mounted", false))
	)
	_profile = npc_profile.duplicate(true)
	var equipment: Dictionary = npc_profile.get("equipment", {}) if npc_profile.get("equipment", {}) is Dictionary else {}
	var main_weapon: Dictionary = equipment.get("main_weapon", {}) if equipment.get("main_weapon", {}) is Dictionary else {}
	_authority_main_weapon_id = str(main_weapon.get("id", ""))
	_ensure_combat_weapon_node(_authority_main_weapon_id)
	_authority_armor_ids.clear()
	for slot in ARMOR_SLOTS:
		var armor_item: Dictionary = equipment.get(slot, {}) if equipment.get(slot, {}) is Dictionary else {}
		_authority_armor_ids[slot] = str(armor_item.get("id", ""))
	var behavior_mode := str(states.get("behavior_mode", states.get("combat_mode", "")))
	_authority_combat_visible = behavior_mode in ["rally", "combat"]
	var next_attack_sequence := int(states.get("combat_attack_sequence", -1))
	var attack_sequence_changed := next_attack_sequence >= 0 and next_attack_sequence != _combat_attack_sequence
	_combat_attack_sequence = next_attack_sequence
	_combat_attack_cycle_seconds = maxf(0.0, float(states.get("combat_attack_cycle_seconds", 0.0)))
	_combat_attack_impact_seconds = maxf(0.0, float(states.get("combat_attack_impact_seconds", 0.0)))
	_combat_attack_elapsed_seconds = maxf(0.0, float(states.get("combat_attack_elapsed_seconds", 0.0)))
	_combat_attack_phase = str(states.get("combat_attack_phase", "idle"))
	_formal_projectile_authority = str(states.get("combat_projectile_authority", "")) == "combat_system"
	var timing := COMBAT_ANIMATION_TIMING.get_timing(
		_authority_main_weapon_id,
		_combat_attack_cycle_seconds if _combat_attack_cycle_seconds > 0.0 else 1.0,
		bool(states.get("combat_mounted", false))
	)
	_combat_attack_playback_multiplier = maxf(
		0.01,
		float(states.get("combat_attack_playback_multiplier", timing.get("playback_multiplier", 1.0)))
	)
	if _authority_armor_ids.values().any(func(value: Variant) -> bool: return not str(value).is_empty()):
		_ensure_armor_nodes()
	_previous_hp = next_hp
	_previous_unconscious = next_unconscious
	_debug_forced_state = ""
	if took_damage:
		_trigger_damage_feedback(next_unconscious)
	if started_mounted_fall:
		_start_mounted_fall(str(npc_profile.get("id", "")))
	if next_unconscious:
		_transient_state = ""
		_transient_remaining = 0.0
	elif revived:
		_mounted_fall_recovering = _mounted_fall_active
		_mounted_fall_active = false
		_start_transient("get_up", GET_UP_SECONDS)
	_apply_profile_state(attack_sequence_changed)
	_sync_attack_animation_to_authority(attack_sequence_changed)


func set_spatial_attachment_pose(pose: String) -> void:
	_spatial_attachment_pose = pose
	_debug_forced_state = ""
	_apply_profile_state(false)


func set_movement_active(
	active: bool,
	world_speed: float = 0.0,
	locomotion_state: String = "",
	reference_speed: float = 0.0,
	minimum_speed_scale: float = 0.35,
	maximum_speed_scale: float = 1.6
) -> void:
	if active and not _is_moving:
		_movement_activation_count += 1
	_is_moving = active
	_movement_speed = maxf(0.0, world_speed)
	if locomotion_state in ["walk", "run"]:
		_locomotion_state = locomotion_state
	else:
		var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
		var behavior_mode := str(states.get("behavior_mode", ""))
		_locomotion_state = "run" if world_speed > 5.5 or ["rally", "combat", "avoid_combat", "escaped"].has(behavior_mode) else "walk"
	if reference_speed > 0.0:
		_locomotion_reference_speed = reference_speed
	else:
		_locomotion_reference_speed = 5.0 if _locomotion_state == "run" else 3.2
	_locomotion_minimum_speed_scale = maxf(0.0, minimum_speed_scale)
	_locomotion_maximum_speed_scale = maxf(_locomotion_minimum_speed_scale, maximum_speed_scale)
	_apply_profile_state(false)
	if active:
		_last_locomotion_state = _desired_state


func set_facing_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() <= 0.0001:
		return
	_target_facing_direction = flat.normalized()
	_target_yaw = atan2(-_target_facing_direction.x, -_target_facing_direction.z)


func play_temporary_presentation_action(action_id: String, event_id: String) -> Dictionary:
	if not action_id in ["talk_gesture", "hit_react", "emotion_happy", "emotion_angry"]:
		return {"ok": false, "reason": "unsupported_temporary_presentation_action", "action_id": action_id}
	if event_id.is_empty():
		return {"ok": false, "reason": "temporary_presentation_event_id_missing"}
	if _processed_temporary_presentation_event_ids.has(event_id):
		var duplicate_state := str({
			"talk_gesture": "talk",
			"hit_react": "hit_react",
			"emotion_happy": "happy",
			"emotion_angry": "angry",
		}.get(action_id, ""))
		return {
			"ok": true,
			"duplicate": true,
			"event_id": event_id,
			"action_id": action_id,
			"presentation_state": duplicate_state
		}
	var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
	if bool(states.get("unconscious", false)) or bool(states.get("escaped", false)):
		return {"ok": false, "reason": "npc_presentation_unavailable", "event_id": event_id}
	var presentation_state := {
		"talk_gesture": "talk",
		"hit_react": "mounted_hit_react" if bool(states.get("combat_mounted", false)) else "hit_react",
		"emotion_happy": "happy",
		"emotion_angry": "angry",
	}.get(action_id, "talk") as String
	var duration := TALK_GESTURE_FALLBACK_SECONDS
	if action_id == "hit_react":
		duration = HIT_REACT_SECONDS
	var clip_name := str(STATE_CLIPS.get(presentation_state, ""))
	if _animation_player != null and _animation_player.has_animation(clip_name):
		duration = maxf(0.1, _animation_player.get_animation(clip_name).length / maxf(0.01, playback_speed))
	_last_temporary_presentation_event_id = event_id
	_temporary_presentation_event_count += 1
	_processed_temporary_presentation_event_ids[event_id] = true
	_temporary_presentation_event_order.append(event_id)
	if _temporary_presentation_event_order.size() > 32:
		_processed_temporary_presentation_event_ids.erase(_temporary_presentation_event_order.pop_front())
	_start_transient(presentation_state, duration)
	# Dialogue remains interactive during the player's gameplay pause. Happy and
	# angry are reply feedback, so start them immediately even when all authority
	# movement/combat/work animation remains frozen.
	_animation_paused = _is_gameplay_paused() and not _is_pause_exempt_dialogue_emotion_action()
	_apply_profile_state(true)
	return {
		"ok": true,
		"duplicate": false,
		"event_id": event_id,
		"action_id": action_id,
		"presentation_state": presentation_state,
		"duration_seconds": duration
	}


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
	var combat_frame_delta := _get_combat_frame_delta_seconds(delta)
	if _blood_particles != null:
		_blood_particles.speed_scale = _get_combat_time_multiplier()
	var gameplay_paused := _is_gameplay_paused()
	var pause_exempt_emotion_action := gameplay_paused and _is_pause_exempt_dialogue_emotion_action()
	var should_pause_animation := gameplay_paused and not pause_exempt_emotion_action
	if should_pause_animation != _animation_paused:
		_animation_paused = should_pause_animation
		_update_playback_speed()
	if gameplay_paused:
		if pause_exempt_emotion_action:
			_advance_temporary_presentation(maxf(0.0, delta))
		return
	if _desired_state in COMBAT_PRESENTATION_STATES:
		_update_playback_speed()
	if _visual_root != null:
		_visual_root.rotation.y = lerp_angle(
			_visual_root.rotation.y,
			_target_yaw + MODEL_FORWARD_CORRECTION_Y,
			clampf(delta / maxf(0.01, facing_turn_speed), 0.0, 1.0)
		)
	_update_combat_feedback(combat_frame_delta)
	if _mounted_fall_active and _mounted_fall_elapsed < MOUNTED_FALL_AIRBORNE_SECONDS:
		_mounted_fall_elapsed = minf(MOUNTED_FALL_AIRBORNE_SECONDS, _mounted_fall_elapsed + combat_frame_delta)
	_update_stable_broom_alignment()
	_update_cook_spoon_alignment()
	_update_engineer_wrench_alignment()
	_update_garden_hoe_alignment()
	_update_medical_book_alignment()
	_update_drink_mug_alignment()
	_update_preview_bow_attack(delta)
	_update_preview_crossbow_attack(delta)
	_update_preview_polearm_alignment()
	_update_preview_bow_alignment()
	_update_preview_crossbow_alignment()
	_update_preview_arrow_projectiles(delta)
	_update_mounted_sword_shield_alignment()
	_advance_temporary_presentation(combat_frame_delta)


func _advance_temporary_presentation(delta: float) -> void:
	if _transient_state.is_empty() or _transient_remaining <= 0.0:
		return
	_transient_remaining = maxf(0.0, _transient_remaining - maxf(0.0, delta))
	if not is_zero_approx(_transient_remaining):
		return
	_transient_state = ""
	_mounted_fall_recovering = false
	_mounted_fall_landing_offset = Vector3.ZERO
	# If a dialogue emotion finishes while gameplay is paused, the restored
	# authority animation must return frozen instead of advancing for one frame.
	_animation_paused = _is_gameplay_paused()
	_apply_profile_state(false)


func _is_pause_exempt_dialogue_emotion_action() -> bool:
	return _transient_state in ["happy", "angry"]


func _apply_profile_state(reset: bool) -> void:
	if not _ready_ok:
		return
	var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
	var current_action := str(states.get("current_action", ""))
	_ensure_action_equipment(current_action)
	var next_state := _resolve_animation_state()
	_desired_state = next_state
	_play_state(next_state, reset)
	_place_hammer(next_state == "work" and current_action == "work_blacksmith")
	_place_stable_broom(next_state == "work" and current_action == "work_stable")
	_place_cook_spoon(next_state == "work" and current_action == "work_dining_hall")
	_place_garden_hoe(next_state == "work" and current_action == "work_garden")
	_sync_medical_kit_visibility(next_state, current_action)
	_sync_engineering_kit_visibility(next_state, current_action)
	_sync_drink_mug_visibility(next_state, current_action)
	_sync_sword_shield_visibility(next_state)
	if current_action == "receive_weapon_training":
		_set_equipment_visible("hammer", false)
	_update_playback_speed()


func _resolve_animation_state() -> String:
	if not _debug_forced_state.is_empty():
		return _debug_forced_state
	var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
	var mounted_context := _spatial_attachment_pose == "vehicle_seated" or bool(states.get("combat_mounted", false))
	if bool(states.get("unconscious", false)):
		return "mounted_fall" if _mounted_fall_active else "unconscious"
	if not _transient_state.is_empty():
		if mounted_context and _transient_state == "hit_react":
			return "mounted_hit_react"
		return _transient_state
	if _is_moving:
		if mounted_context:
			return "mounted_walk"
		return _locomotion_state
	var current_action := str(states.get("current_action", "idle"))
	if _spatial_attachment_pose in ["sleeping_supine", "lying_supine"] or current_action == "sleep_in_dormitory":
		return "sleeping"
	if _spatial_attachment_pose == "seated_study":
		return "seated_study"
	if mounted_context:
		if current_action in ["work_training_instructor", "receive_weapon_training"]:
			return "mounted_training"
		return "mounted_attack" if current_action.begins_with("attacking_") or current_action.begins_with("winding_up_") else "vehicle_seated"
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
	if current_action == "drink_wine":
		return "drink"
	if current_action == "assist_heal" or current_action.begins_with("assist_heal_"):
		return "medical_treatment"
	if current_action == "work_clinic_doctor" and str(states.get("presentation_clinic_duty_mode", "")) == "treatment":
		return "medical_treatment"
	if current_action.begins_with("assist_repair_") or current_action.begins_with("assist_upgrade_"):
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
	if _current_state == state_name and _current_clip == clip_name and not reset:
		if _animation_player.is_playing():
			return true
		if state_name in HOLD_FINAL_POSE_STATES:
			# Death_A is a one-shot fall. Profile refreshes while authority still says
			# unconscious must keep its final pose; replaying from frame zero briefly
			# stands the NPC up before dropping them again.
			return true
		if state_name in ["attack", "mounted_attack"] and _combat_attack_phase in ["windup", "recovery"]:
			# Attack clips are authored as one-shot animations. Authority state can
			# remain in recovery for a fractional frame after the clip reaches its
			# end; profile refreshes must hold that final pose instead of replaying
			# the same sequence. Only a changed combat_attack_sequence passes reset.
			return true
	_restore_cached_sword_attack_attachment(state_name)
	# A blended transition keeps the previous action's hand-bone basis alive for
	# several rendered frames. Unlike the procedural weapons, the sword must then
	# remain rigidly parented to that hand, so the stale basis visibly twists the
	# restored grip. Start sword attacks from their authored first pose; subsequent
	# frames remain fully attachment-driven and require no world-space correction.
	var blend_time := 0.0 if _uses_sword_shield_weapon() and state_name in ["attack", "angry", "training_practice", "mounted_attack", "mounted_training"] else 0.16
	_animation_player.play(clip_name, blend_time)
	_current_state = state_name
	_current_clip = clip_name
	if state_name in ["attack", "mounted_attack"] and _active_preview_weapon_id() == "bow":
		_begin_preview_bow_attack()
	else:
		if _preview_bow_attack_active:
			_cancel_preview_bow_attack()
	if state_name in ["attack", "mounted_attack"] and _active_preview_weapon_id() == "crossbow":
		_begin_preview_crossbow_attack()
	else:
		if _preview_crossbow_attack_active:
			_cancel_preview_crossbow_attack()
	_update_playback_speed()
	return true


func _get_state_clip(state_name: String) -> String:
	if state_name == "mounted_attack":
		match _active_preview_weapon_id():
			"polearm":
				return MOUNTED_POLEARM_ATTACK_CLIP
			"bow":
				return MOUNTED_BOW_DRAW_CLIP
			"crossbow":
				return MOUNTED_CROSSBOW_AIM_CLIP
			_:
				return MOUNTED_ATTACK_CLIP
	if state_name in ["attack", "training_practice"] and _active_preview_weapon_id() == "polearm":
		return PREVIEW_POLEARM_THRUST_CLIP
	if state_name == "attack" and _active_preview_weapon_id() == "bow":
		return PREVIEW_BOW_DRAW_CLIP
	if state_name == "attack" and _active_preview_weapon_id() == "crossbow":
		return PREVIEW_CROSSBOW_AIM_CLIP
	if state_name == "work":
		var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
		var current_action := str(states.get("current_action", ""))
		if WORK_ACTION_CLIPS.has(current_action):
			return str(WORK_ACTION_CLIPS[current_action])
		return work_clip
	if state_name == "mass_leader":
		return mass_leader_clip
	if state_name == "medical_treatment":
		return medical_treatment_clip
	return str(STATE_CLIPS.get(state_name, "Idle_A"))


func _active_preview_weapon_id() -> String:
	if _debug_equipment_preview_active:
		return _debug_preview_main_weapon_id
	return _authority_main_weapon_id


func _start_transient(state_name: String, duration: float) -> void:
	_transient_state = state_name
	_transient_remaining = maxf(0.0, duration)


func _start_mounted_fall(npc_id: String) -> void:
	_mounted_fall_active = true
	_mounted_fall_recovering = false
	_mounted_fall_elapsed = 0.0
	_mounted_fall_side = 1.0 if absi(hash(npc_id)) % 2 == 0 else -1.0
	var visible_forward := _get_mounted_visible_forward_local()
	var visible_right := Vector3.UP.cross(visible_forward).normalized()
	_mounted_fall_landing_offset = (
		visible_right * _mounted_fall_side * MOUNTED_FALL_SIDE_DISTANCE
		- visible_forward * MOUNTED_FALL_BACK_DISTANCE
	)
	_mounted_fall_trigger_count += 1


func _update_playback_speed() -> void:
	if _animation_player == null:
		return
	if _animation_paused:
		_animation_player.speed_scale = 0.0
		return
	var effective_speed := playback_speed
	if _desired_state in ["walk", "run", "mounted_walk"]:
		effective_speed = clampf(_movement_speed / maxf(0.01, _locomotion_reference_speed), _locomotion_minimum_speed_scale, _locomotion_maximum_speed_scale)
	elif _desired_state in ["attack", "mounted_attack"]:
		# Locomotion personality speed must not stretch an authoritative combat
		# cycle. The shared timeline alone owns attack playback speed.
		effective_speed = _combat_attack_playback_multiplier * _get_combat_time_multiplier()
	elif _desired_state in COMBAT_PRESENTATION_STATES:
		# Hit, fall, unconscious and revive clips are combat presentation too.
		# They keep their authored personality rate, but share the same pause /
		# slowdown contract as the attack timeline and its root-motion feedback.
		effective_speed = playback_speed * _get_combat_time_multiplier()
	_animation_player.speed_scale = effective_speed


func _get_combat_time_multiplier() -> float:
	if _combat_time_system == null or not is_instance_valid(_combat_time_system):
		_combat_time_system = get_node_or_null("/root/Main/Systems/TimeSystem")
	if _combat_time_system != null and _combat_time_system.has_method("get_combat_frame_rate"):
		return maxf(0.0, float(_combat_time_system.get_combat_frame_rate()))
	return 1.0


func _get_combat_frame_delta_seconds(real_delta_seconds: float) -> float:
	if _combat_time_system == null or not is_instance_valid(_combat_time_system):
		_combat_time_system = get_node_or_null("/root/Main/Systems/TimeSystem")
	if _combat_time_system != null and _combat_time_system.has_method("get_combat_frame_delta_seconds"):
		return maxf(0.0, float(_combat_time_system.get_combat_frame_delta_seconds(real_delta_seconds)))
	return maxf(0.0, real_delta_seconds)


func _get_attack_animation_delta(delta: float) -> float:
	return maxf(0.0, delta) * _combat_attack_playback_multiplier * _get_combat_time_multiplier()


func _sync_attack_animation_to_authority(sequence_changed: bool) -> void:
	if (
		not sequence_changed
		or _animation_player == null
		or not _current_state in ["attack", "mounted_attack"]
		or _combat_attack_cycle_seconds <= 0.0
	):
		return
	var timing := COMBAT_ANIMATION_TIMING.get_timing(_active_preview_weapon_id(), _combat_attack_cycle_seconds, _current_state == "mounted_attack")
	var authored_elapsed := clampf(
		_combat_attack_elapsed_seconds * float(timing.get("playback_multiplier", 1.0)),
		0.0,
		float(timing.get("authored_cycle_seconds", 0.0))
	)
	match _active_preview_weapon_id():
		"bow":
			_seek_bow_attack_to_authored_time(authored_elapsed)
		"crossbow":
			_seek_crossbow_attack_to_authored_time(authored_elapsed)
		_:
			_animation_player.seek(minf(authored_elapsed, _animation_player.current_animation_length), true)


func _seek_bow_attack_to_authored_time(authored_elapsed: float) -> void:
	_preview_bow_attack_active = true
	_preview_bow_arrow_fired = false
	var clip_name := MOUNTED_BOW_DRAW_CLIP if _desired_state == "mounted_attack" else PREVIEW_BOW_DRAW_CLIP
	var local_elapsed := authored_elapsed
	if authored_elapsed < PREVIEW_BOW_DRAW_SECONDS:
		_preview_bow_attack_phase = "draw"
	elif authored_elapsed < PREVIEW_BOW_DRAW_SECONDS + PREVIEW_BOW_AIM_SECONDS:
		_preview_bow_attack_phase = "aim"
		local_elapsed -= PREVIEW_BOW_DRAW_SECONDS
		clip_name = MOUNTED_BOW_AIM_CLIP if _desired_state == "mounted_attack" else PREVIEW_BOW_AIM_CLIP
	else:
		_preview_bow_attack_phase = "release"
		local_elapsed -= PREVIEW_BOW_DRAW_SECONDS + PREVIEW_BOW_AIM_SECONDS
		clip_name = MOUNTED_BOW_RELEASE_CLIP if _desired_state == "mounted_attack" else PREVIEW_BOW_RELEASE_CLIP
	_preview_bow_phase_elapsed = maxf(0.0, local_elapsed)
	_animation_player.play(clip_name, 0.0)
	_current_clip = clip_name
	_animation_player.seek(minf(_preview_bow_phase_elapsed, _animation_player.current_animation_length), true)
	if _preview_bow_attack_phase == "release" and _preview_bow_phase_elapsed >= PREVIEW_BOW_RELEASE_FIRE_SECONDS:
		_fire_preview_bow_arrow()
	else:
		_update_preview_bow_draw_geometry()


func _seek_crossbow_attack_to_authored_time(authored_elapsed: float) -> void:
	_preview_crossbow_attack_active = true
	_preview_crossbow_bolt_fired = false
	var clip_name := MOUNTED_CROSSBOW_AIM_CLIP if _desired_state == "mounted_attack" else PREVIEW_CROSSBOW_AIM_CLIP
	var local_elapsed := authored_elapsed
	if authored_elapsed < PREVIEW_CROSSBOW_AIM_SECONDS:
		_preview_crossbow_attack_phase = "aim"
	elif authored_elapsed < PREVIEW_CROSSBOW_AIM_SECONDS + PREVIEW_CROSSBOW_SHOOT_SECONDS:
		_preview_crossbow_attack_phase = "shoot"
		local_elapsed -= PREVIEW_CROSSBOW_AIM_SECONDS
		clip_name = MOUNTED_CROSSBOW_SHOOT_CLIP if _desired_state == "mounted_attack" else PREVIEW_CROSSBOW_SHOOT_CLIP
	else:
		_preview_crossbow_attack_phase = "reload"
		local_elapsed -= PREVIEW_CROSSBOW_AIM_SECONDS + PREVIEW_CROSSBOW_SHOOT_SECONDS
		clip_name = MOUNTED_CROSSBOW_RELOAD_CLIP if _desired_state == "mounted_attack" else PREVIEW_CROSSBOW_RELOAD_CLIP
	_preview_crossbow_phase_elapsed = maxf(0.0, local_elapsed)
	_animation_player.play(clip_name, 0.0)
	_current_clip = clip_name
	_animation_player.seek(minf(_preview_crossbow_phase_elapsed, _animation_player.current_animation_length), true)
	if _preview_crossbow_attack_phase == "shoot" and _preview_crossbow_phase_elapsed >= PREVIEW_CROSSBOW_SHOOT_FIRE_SECONDS:
		_fire_preview_crossbow_bolt()
	elif _preview_crossbow_attack_phase == "reload":
		_preview_crossbow_bolt_fired = true
		_update_preview_crossbow_reload_geometry()


func _place_hammer(in_right_hand: bool) -> void:
	var hammer := _equipment_nodes.get("hammer") as Node3D
	if hammer == null:
		return
	var socket_name := "RightHand" if in_right_hand else "Mount"
	var socket := _equipment_sockets.get(socket_name) as BoneAttachment3D
	if socket == null:
		return
	if hammer.get_parent() != socket:
		hammer.reparent(socket, false)
	hammer.visible = in_right_hand or equipment_mode == "hammer"
	if not hammer.visible:
		return
	if in_right_hand:
		hammer.position = HAMMER_HAND_LOCAL_POSITION
		hammer.rotation_degrees = HAMMER_HAND_LOCAL_ROTATION_DEGREES
		hammer.scale = HAMMER_HAND_SCALE
	else:
		hammer.position = HAMMER_STOW_LOCAL_POSITION
		hammer.rotation_degrees = HAMMER_STOW_LOCAL_ROTATION_DEGREES
		hammer.scale = HAMMER_STOW_SCALE


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
	broom.scale = STABLE_TOOL_SCALE
	_update_stable_broom_alignment()


func _update_stable_broom_alignment() -> void:
	var broom := _equipment_nodes.get("stable_broom") as Node3D
	var socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if broom == null or socket == null or not broom.visible or broom.get_parent() != socket:
		return
	var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else _target_facing_direction
	var tool_direction := (visual_forward + Vector3.DOWN * STABLE_TOOL_DOWNWARD_WEIGHT).normalized()
	var socket_local_direction := (socket.global_basis.inverse() * tool_direction).normalized()
	broom.quaternion = Quaternion(Vector3.DOWN, socket_local_direction)
	# The FBX origin is not at the rear of the handle. Offset the model so its
	# measured local +Y endpoint remains exactly inside the right hand.
	broom.position = -(broom.basis * STABLE_TOOL_GRIP_SOURCE_LOCAL_POSITION)


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
	spoon.scale = Vector3.ONE
	_update_cook_spoon_alignment()


func _update_cook_spoon_alignment() -> void:
	var spoon := _equipment_nodes.get("cook_spoon") as Node3D
	var socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if spoon == null or socket == null or not spoon.visible or spoon.get_parent() != socket:
		return
	var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else _target_facing_direction
	var shaft_direction := (visual_forward + Vector3.DOWN * COOK_SPOON_DOWNWARD_WEIGHT).normalized()
	var socket_local_direction := (socket.global_basis.inverse() * shaft_direction).normalized()
	spoon.quaternion = Quaternion(Vector3.UP, socket_local_direction)
	# The hand bone sits toward the outer edge of Bruno's broad mitten mesh. Move
	# the handle inward to the visible palm center instead of aligning it to that
	# invisible bone origin.
	var grip_target := _cook_spoon_grip_target(socket)
	spoon.position = socket.to_local(grip_target) - spoon.basis * COOK_SPOON_GRIP_SOURCE_LOCAL_POSITION


func _cook_spoon_grip_target(socket: BoneAttachment3D) -> Vector3:
	if _visual_root == null:
		return socket.global_position
	var visual_right := _visual_root.global_basis.x.normalized()
	var hand_side := signf((socket.global_position - global_position).dot(visual_right))
	if is_zero_approx(hand_side):
		hand_side = -1.0
	return socket.global_position - visual_right * hand_side * COOK_SPOON_PALM_INWARD_OFFSET


func _update_engineer_wrench_alignment() -> void:
	var wrench := _equipment_nodes.get("engineer_wrench") as Node3D
	var socket := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if wrench == null or socket == null or not wrench.visible or wrench.get_parent() != socket:
		return
	var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else _target_facing_direction
	var tool_direction := (visual_forward + Vector3.DOWN * ENGINEER_WRENCH_DOWNWARD_WEIGHT).normalized()
	var socket_local_direction := (socket.global_basis.inverse() * tool_direction).normalized()
	wrench.quaternion = Quaternion(Vector3.UP, socket_local_direction)
	wrench.position = -(wrench.basis * ENGINEER_WRENCH_GRIP_SOURCE_LOCAL_POSITION)


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
	hoe.scale = Vector3.ONE * 0.9
	_update_garden_hoe_alignment()


func _update_garden_hoe_alignment() -> void:
	var hoe := _equipment_nodes.get("garden_hoe") as Node3D
	var right_hand := _equipment_sockets.get("RightHand") as BoneAttachment3D
	var left_hand := _equipment_sockets.get("LeftHand") as BoneAttachment3D
	if hoe == null or right_hand == null or left_hand == null or not hoe.visible or hoe.get_parent() != right_hand:
		return
	var right_palm := _hand_palm_target(right_hand, "RightLowerArm")
	var left_palm := _hand_palm_target(left_hand, "LeftLowerArm")
	var palm_direction := left_palm - right_palm
	if palm_direction.length_squared() <= 0.0001:
		return
	var right_local_direction := (right_hand.global_basis.inverse() * palm_direction.normalized()).normalized()
	hoe.quaternion = Quaternion(Vector3.UP, right_local_direction)
	hoe.position = right_hand.to_local(right_palm) - hoe.basis * GARDEN_HOE_RIGHT_GRIP_SOURCE_LOCAL_POSITION


func _hand_palm_target(hand: BoneAttachment3D, lower_arm_bone_name: String) -> Vector3:
	if _target_skeleton == null:
		return hand.global_position
	var lower_arm_index := _target_skeleton.find_bone(lower_arm_bone_name)
	if lower_arm_index < 0:
		return hand.global_position
	var lower_arm_position := _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(lower_arm_index).origin)
	var palm_direction := hand.global_position - lower_arm_position
	if palm_direction.length_squared() <= 0.0001:
		return hand.global_position
	return (
		hand.global_position
		+ palm_direction.normalized() * GARDEN_HOE_PALM_INSET
		+ Vector3.DOWN * GARDEN_HOE_PALM_DOWN_OFFSET
	)


func _sync_medical_kit_visibility(state_name: String, current_action: String) -> void:
	if not _equipment_nodes.has("medical_satchel"):
		return
	var medical_action := current_action in ["work_clinic_doctor", "medical_treatment", "seated_study", "assist_heal"] or current_action.begins_with("assist_heal_")
	_set_equipment_visible("medical_satchel", equipment_mode == "medical_kit" or medical_action)
	var debug_preview := current_action.is_empty()
	_set_equipment_visible("medical_book", state_name in ["work", "seated_study"] and (debug_preview or current_action in ["work_clinic_doctor", "seated_study"]))
	_set_equipment_visible("medical_bandage", state_name == "medical_treatment" and (debug_preview or medical_action))
	_update_medical_book_alignment()


func _update_medical_book_alignment() -> void:
	var book := _equipment_nodes.get("medical_book") as Node3D
	var left_hand := _equipment_sockets.get("LeftHand") as BoneAttachment3D
	var right_hand := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if book == null or left_hand == null or right_hand == null or not book.visible or _visual_root == null:
		return
	var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
	var current_action := str(states.get("current_action", ""))
	var on_clinic_table := current_action == "work_clinic_doctor" and _spatial_attachment_pose == "seated_study"
	var visual_forward := _visual_root.global_basis.z.normalized()
	if on_clinic_table:
		visual_forward = Vector3(_target_facing_direction.x, 0.0, _target_facing_direction.z).normalized()
	var visual_right := _visual_root.global_basis.x.normalized()
	if on_clinic_table and not visual_forward.is_zero_approx():
		visual_right = visual_forward.cross(Vector3.UP).normalized()
	var page_normal := Vector3.UP if on_clinic_table else (Vector3.UP + visual_forward * MEDICAL_BOOK_TILT_WEIGHT).normalized()
	var page_forward := visual_right.cross(page_normal).normalized()
	var hand_midpoint := (left_hand.global_position + right_hand.global_position) * 0.5
	var target_position := hand_midpoint + visual_forward * MEDICAL_BOOK_FORWARD_OFFSET + Vector3.DOWN * MEDICAL_BOOK_DOWN_OFFSET
	if on_clinic_table:
		target_position = global_position + visual_forward * MEDICAL_BOOK_CLINIC_TABLE_FORWARD_OFFSET + Vector3.UP * MEDICAL_BOOK_CLINIC_TABLE_HEIGHT_OFFSET
	book.global_transform = Transform3D(
		Basis(visual_right, page_normal, page_forward).orthonormalized(),
		target_position
	)


func _update_drink_mug_alignment() -> void:
	var mug := _equipment_nodes.get("drink_mug") as Node3D
	var right_hand := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if mug == null or right_hand == null or not mug.visible or _visual_root == null:
		return
	var mug_right := _visual_root.global_basis.x.normalized()
	var mug_forward := _visual_root.global_basis.z.normalized()
	var mug_basis := Basis(mug_right, Vector3.UP, mug_forward).orthonormalized().scaled(DRINK_MUG_SCALE)
	mug.global_basis = mug_basis
	mug.global_position = _drink_mug_grip_target(right_hand) - mug.global_basis * DRINK_MUG_GRIP_SOURCE_LOCAL_POSITION


func _drink_mug_grip_target(right_hand: BoneAttachment3D) -> Vector3:
	var target := right_hand.global_position
	if _target_skeleton != null:
		var lower_arm_index := _target_skeleton.find_bone("RightLowerArm")
		if lower_arm_index >= 0:
			var lower_arm_position := _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(lower_arm_index).origin)
			var palm_direction := right_hand.global_position - lower_arm_position
			if palm_direction.length_squared() > 0.0001:
				target += palm_direction.normalized() * DRINK_MUG_PALM_OFFSET
	if _visual_root != null:
		target += _visual_root.global_basis.z.normalized() * DRINK_MUG_FORWARD_OFFSET
	return target


func _update_preview_polearm_alignment() -> void:
	var polearm := _equipment_nodes.get("polearm") as Node3D
	var right_hand := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if polearm == null or right_hand == null or not polearm.visible or _visual_root == null:
		return
	# Keep the approved ready-pose weapon contract for the entire stab. The
	# animation moves the body and both arms, but must not steer or flip the
	# weapon from the changing line between the two palms.
	var polearm_side := _visual_root.global_basis.x.normalized()
	var polearm_axis := _visual_root.global_basis.z.normalized()
	var polearm_depth := polearm_side.cross(polearm_axis).normalized()
	var polearm_basis := Basis(polearm_side, polearm_axis, polearm_depth).orthonormalized().scaled(PREVIEW_POLEARM_SCALE)
	polearm.global_basis = polearm_basis
	polearm.global_position = _preview_polearm_grip_target(right_hand) - polearm.global_basis * PREVIEW_POLEARM_GRIP_SOURCE_LOCAL_POSITION


func _on_target_skeleton_updated() -> void:
	# Bone attachments receive their final animated transforms with this signal.
	# Reapply the fixed polearm contract here to avoid a one-frame grip/heading lag
	# during fast two-handed thrust frames.
	_update_preview_polearm_alignment()
	_update_preview_bow_alignment()
	_update_preview_crossbow_alignment()
	_update_mounted_sword_shield_alignment()


func _preview_polearm_grip_target(right_hand: BoneAttachment3D) -> Vector3:
	var target := right_hand.global_position + Vector3.DOWN * PREVIEW_POLEARM_DOWN_OFFSET
	if _visual_root != null:
		var visual_right := _visual_root.global_basis.x.normalized()
		var hand_side := signf((right_hand.global_position - global_position).dot(visual_right))
		if not is_zero_approx(hand_side):
			target -= visual_right * hand_side * PREVIEW_POLEARM_INWARD_OFFSET
	if _target_skeleton == null:
		return target
	var lower_arm_index := _target_skeleton.find_bone("RightLowerArm")
	if lower_arm_index < 0:
		return target
	var lower_arm_position := _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(lower_arm_index).origin)
	var palm_direction := right_hand.global_position - lower_arm_position
	if palm_direction.length_squared() > 0.0001:
		target += palm_direction.normalized() * PREVIEW_POLEARM_PALM_OFFSET
	return target


func _update_preview_bow_alignment() -> void:
	var bow := _equipment_nodes.get("bow") as Node3D
	var left_hand := _equipment_sockets.get("LeftHand") as BoneAttachment3D
	if bow == null or left_hand == null or not bow.visible or _visual_root == null:
		return
	# Idle inspection keeps the approved forward long axis and upper string.
	# During a shot, rotate to a conventional vertical bow: local +Y points up,
	# while local -Z (where the string is modeled) points behind the character.
	var visual_forward := _visual_root.global_basis.z.normalized()
	var bow_long_axis := Vector3.UP if _preview_bow_attack_active else visual_forward
	var bow_curve_axis := visual_forward if _preview_bow_attack_active else Vector3.DOWN
	var bow_thickness_axis := bow_long_axis.cross(bow_curve_axis).normalized()
	bow.global_basis = Basis(bow_thickness_axis, bow_long_axis, bow_curve_axis).scaled(PREVIEW_BOW_SCALE)
	var grip_target := _preview_bow_grip_target(left_hand)
	bow.global_position = grip_target - bow.global_basis * PREVIEW_BOW_GRIP_SOURCE_LOCAL_POSITION
	_update_preview_bow_draw_geometry()


func _preview_bow_grip_target(left_hand: BoneAttachment3D) -> Vector3:
	var target := left_hand.global_position + Vector3.DOWN * PREVIEW_BOW_DOWN_OFFSET
	if _visual_root != null:
		var visual_right := _visual_root.global_basis.x.normalized()
		var hand_side := signf((left_hand.global_position - global_position).dot(visual_right))
		if not is_zero_approx(hand_side):
			target -= visual_right * hand_side * PREVIEW_BOW_INWARD_OFFSET
	if _target_skeleton != null:
		var lower_arm_index := _target_skeleton.find_bone("LeftLowerArm")
		if lower_arm_index >= 0:
			var lower_arm_position := _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(lower_arm_index).origin)
			var palm_direction := left_hand.global_position - lower_arm_position
			if palm_direction.length_squared() > 0.0001:
				target += palm_direction.normalized() * PREVIEW_BOW_PALM_OFFSET
	return target


func _begin_preview_bow_attack() -> void:
	_preview_bow_attack_active = true
	_preview_bow_attack_phase = "draw"
	_preview_bow_phase_elapsed = 0.0
	_preview_bow_arrow_fired = false
	_update_preview_bow_draw_geometry()


func _cancel_preview_bow_attack() -> void:
	_preview_bow_attack_active = false
	_preview_bow_attack_phase = "idle"
	_preview_bow_phase_elapsed = 0.0
	_preview_bow_arrow_fired = false
	_reset_preview_bow_geometry()


func _update_preview_bow_attack(delta: float) -> void:
	if not _preview_bow_attack_active:
		return
	if _active_preview_weapon_id() != "bow" or not _desired_state in ["attack", "mounted_attack"]:
		_cancel_preview_bow_attack()
		return
	_preview_bow_phase_elapsed += _get_attack_animation_delta(delta)
	if _preview_bow_attack_phase == "draw" and _preview_bow_phase_elapsed >= PREVIEW_BOW_DRAW_SECONDS:
		_preview_bow_attack_phase = "aim"
		_preview_bow_phase_elapsed = 0.0
		var aim_clip := MOUNTED_BOW_AIM_CLIP if _desired_state == "mounted_attack" else PREVIEW_BOW_AIM_CLIP
		_animation_player.play(aim_clip, 0.06)
		_current_clip = aim_clip
	elif _preview_bow_attack_phase == "aim" and _preview_bow_phase_elapsed >= PREVIEW_BOW_AIM_SECONDS:
		_preview_bow_attack_phase = "release"
		_preview_bow_phase_elapsed = 0.0
		var release_clip := MOUNTED_BOW_RELEASE_CLIP if _desired_state == "mounted_attack" else PREVIEW_BOW_RELEASE_CLIP
		_animation_player.play(release_clip, 0.03)
		_current_clip = release_clip
	elif _preview_bow_attack_phase == "release":
		if not _preview_bow_arrow_fired and _preview_bow_phase_elapsed >= PREVIEW_BOW_RELEASE_FIRE_SECONDS:
			_fire_preview_bow_arrow()
		if _preview_bow_phase_elapsed >= PREVIEW_BOW_RELEASE_SECONDS:
			_preview_bow_attack_active = false
			_preview_bow_attack_phase = "complete"
			_reset_preview_bow_geometry()


func _update_preview_bow_draw_geometry() -> void:
	if _preview_bow_static_string == null or _preview_bow_string_front == null or _preview_bow_string_rear == null or _preview_bow_loaded_arrow == null:
		return
	if not _preview_bow_attack_active or _preview_bow_arrow_fired:
		_reset_preview_bow_geometry()
		return
	var bow := _equipment_nodes.get("bow") as Node3D
	var pull_hand := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if bow == null or pull_hand == null:
		return
	var draw_ratio := 1.0
	if _preview_bow_attack_phase == "draw":
		draw_ratio = clampf(_preview_bow_phase_elapsed / PREVIEW_BOW_DRAW_SECONDS, 0.0, 1.0)
	var rest_nock := Vector3(0.0, 0.0, PREVIEW_BOW_STRING_Z)
	var pull_hand_target := _preview_bow_pull_hand_target(pull_hand)
	var pulled_nock := bow.to_local(pull_hand_target)
	pulled_nock.y = clampf(pulled_nock.y, -0.72, 0.72)
	var nock := rest_nock.lerp(pulled_nock, draw_ratio)
	_preview_bow_nock_pull_hand_distance = bow.to_global(nock).distance_to(pull_hand_target)
	_preview_bow_static_string.visible = false
	_preview_bow_string_front.visible = true
	_preview_bow_string_rear.visible = true
	_set_weapon_cylinder_endpoints(_preview_bow_string_rear, Vector3(0.0, -0.91, PREVIEW_BOW_STRING_Z), nock)
	_set_weapon_cylinder_endpoints(_preview_bow_string_front, nock, Vector3(0.0, 0.91, PREVIEW_BOW_STRING_Z))
	_preview_bow_loaded_arrow.visible = draw_ratio >= 0.12
	# In the vertical attack basis, local +Z is character-forward. The arrow's
	# own +Y axis is aligned from the pulled nock toward that forward anchor.
	var arrow_front := Vector3(nock.x, nock.y, 0.72)
	var arrow_direction := arrow_front - nock
	if arrow_direction.length_squared() > 0.0001:
		_preview_bow_loaded_arrow.quaternion = Quaternion(Vector3.UP, arrow_direction.normalized())
		_preview_bow_loaded_arrow.position = nock - _preview_bow_loaded_arrow.basis * Vector3(0.0, PREVIEW_ARROW_REAR_LOCAL_Y, 0.0)


func _preview_bow_pull_hand_target(pull_hand: BoneAttachment3D) -> Vector3:
	var target := pull_hand.global_position + Vector3.UP * PREVIEW_BOW_PULL_UP_OFFSET
	if _target_skeleton == null:
		return target
	var lower_arm_index := _target_skeleton.find_bone("RightLowerArm")
	if lower_arm_index < 0:
		return target
	var lower_arm_position := _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(lower_arm_index).origin)
	var palm_direction := pull_hand.global_position - lower_arm_position
	if palm_direction.length_squared() > 0.0001:
		target += palm_direction.normalized() * PREVIEW_BOW_PULL_PALM_OFFSET
	return target


func _reset_preview_bow_geometry() -> void:
	if _preview_bow_static_string != null:
		_preview_bow_static_string.visible = true
	if _preview_bow_string_front != null:
		_preview_bow_string_front.visible = false
	if _preview_bow_string_rear != null:
		_preview_bow_string_rear.visible = false
	if _preview_bow_loaded_arrow != null:
		_preview_bow_loaded_arrow.visible = false


func _set_weapon_cylinder_endpoints(part: MeshInstance3D, start: Vector3, finish: Vector3) -> void:
	var direction := finish - start
	var mesh := part.mesh as CylinderMesh
	if mesh != null:
		mesh.height = maxf(0.001, direction.length())
	part.position = (start + finish) * 0.5
	if direction.length_squared() > 0.000001:
		part.quaternion = Quaternion(Vector3.UP, direction.normalized())


func _fire_preview_bow_arrow() -> void:
	_preview_bow_arrow_fired = true
	_preview_bow_shot_count += 1
	if _preview_bow_loaded_arrow == null or _visual_root == null:
		_reset_preview_bow_geometry()
		return
	if _formal_projectile_authority:
		_reset_preview_bow_geometry()
		return
	var host := get_tree().current_scene as Node3D
	if host == null:
		host = get_parent() as Node3D
	if host == null:
		return
	var wood := _new_weapon_material("FlyingArrowWood", Color(0.36, 0.18, 0.065, 1.0))
	var iron := _new_weapon_material("FlyingArrowIron", Color(0.25, 0.27, 0.26, 1.0), 0.38)
	var fletching := _new_weapon_material("FlyingArrowFletching", Color(0.58, 0.16, 0.10, 1.0))
	var projectile := _build_preview_arrow(host, "BowArrowProjectile%02d" % _preview_bow_shot_count, wood, iron, fletching, true)
	projectile.set_meta("presentation_only", true)
	projectile.set_meta("damage_authority", "combat_system_on_confirmed_hit")
	projectile.global_transform = _preview_bow_loaded_arrow.global_transform
	var forward := _visual_root.global_basis.z.normalized()
	var velocity := forward * PREVIEW_ARROW_SPEED + Vector3.UP * PREVIEW_ARROW_LIFT_SPEED
	_preview_arrow_projectiles.append({"node": projectile, "velocity": velocity, "age": 0.0, "kind": "bow"})
	_reset_preview_bow_geometry()


func _update_preview_arrow_projectiles(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for entry in _preview_arrow_projectiles:
		var projectile := entry.get("node") as Node3D
		if projectile == null or not is_instance_valid(projectile):
			continue
		var velocity: Vector3 = entry.get("velocity", Vector3.ZERO)
		var age := float(entry.get("age", 0.0)) + delta
		velocity += Vector3.DOWN * PREVIEW_ARROW_GRAVITY * delta
		projectile.global_position += velocity * delta
		if velocity.length_squared() > 0.001:
			var arrow_up := Vector3.UP
			var arrow_right := velocity.normalized().cross(arrow_up)
			if arrow_right.length_squared() < 0.001:
				arrow_right = Vector3.RIGHT
			arrow_right = arrow_right.normalized()
			var arrow_depth := arrow_right.cross(velocity.normalized()).normalized()
			projectile.global_basis = Basis(arrow_right, velocity.normalized(), arrow_depth)
		var lifetime := float(entry.get("lifetime", PREVIEW_ARROW_LIFETIME))
		if age >= lifetime:
			projectile.queue_free()
		else:
			alive.append({"node": projectile, "velocity": velocity, "age": age, "kind": str(entry.get("kind", "bow")), "lifetime": lifetime})
	_preview_arrow_projectiles = alive


func _begin_preview_crossbow_attack() -> void:
	_preview_crossbow_attack_active = true
	_preview_crossbow_attack_phase = "aim"
	_preview_crossbow_phase_elapsed = 0.0
	_preview_crossbow_bolt_fired = false
	_reset_preview_crossbow_geometry()


func _cancel_preview_crossbow_attack() -> void:
	_preview_crossbow_attack_active = false
	_preview_crossbow_attack_phase = "idle"
	_preview_crossbow_phase_elapsed = 0.0
	_preview_crossbow_bolt_fired = false
	_reset_preview_crossbow_geometry()


func _update_preview_crossbow_attack(delta: float) -> void:
	if not _preview_crossbow_attack_active:
		return
	if _active_preview_weapon_id() != "crossbow":
		_cancel_preview_crossbow_attack()
		return
	_preview_crossbow_phase_elapsed += _get_attack_animation_delta(delta)
	if _preview_crossbow_attack_phase == "aim" and _preview_crossbow_phase_elapsed >= PREVIEW_CROSSBOW_AIM_SECONDS:
		_preview_crossbow_attack_phase = "shoot"
		_preview_crossbow_phase_elapsed = 0.0
		var shoot_clip := MOUNTED_CROSSBOW_SHOOT_CLIP if _desired_state == "mounted_attack" else PREVIEW_CROSSBOW_SHOOT_CLIP
		_animation_player.play(shoot_clip, 0.06)
		_current_clip = shoot_clip
	elif _preview_crossbow_attack_phase == "shoot":
		if not _preview_crossbow_bolt_fired and _preview_crossbow_phase_elapsed >= PREVIEW_CROSSBOW_SHOOT_FIRE_SECONDS:
			_fire_preview_crossbow_bolt()
		if _preview_crossbow_phase_elapsed >= PREVIEW_CROSSBOW_SHOOT_SECONDS:
			_preview_crossbow_attack_phase = "reload"
			_preview_crossbow_phase_elapsed = 0.0
			var reload_clip := MOUNTED_CROSSBOW_RELOAD_CLIP if _desired_state == "mounted_attack" else PREVIEW_CROSSBOW_RELOAD_CLIP
			_animation_player.play(reload_clip, 0.08)
			_current_clip = reload_clip
	elif _preview_crossbow_attack_phase == "reload":
		_update_preview_crossbow_reload_geometry()
		if _preview_crossbow_phase_elapsed >= PREVIEW_CROSSBOW_RELOAD_SECONDS:
			_preview_crossbow_attack_active = false
			_preview_crossbow_attack_phase = "complete"
			_reset_preview_crossbow_geometry()


func _update_preview_crossbow_reload_geometry() -> void:
	var ratio := clampf(_preview_crossbow_phase_elapsed / PREVIEW_CROSSBOW_RELOAD_SECONDS, 0.0, 1.0)
	var nock_y := lerpf(PREVIEW_CROSSBOW_STRING_RELEASED_Y, PREVIEW_CROSSBOW_STRING_COCKED_Y, ratio)
	_set_preview_crossbow_string_nock(nock_y)
	if _preview_crossbow_loaded_bolt != null:
		_preview_crossbow_loaded_bolt.visible = ratio >= 0.72


func _set_preview_crossbow_string_nock(nock_y: float) -> void:
	_preview_crossbow_string_nock_y = nock_y
	if _preview_crossbow_string_left != null:
		_set_weapon_cylinder_endpoints(_preview_crossbow_string_left, Vector3(-0.58, 0.53, 0.0), Vector3(0.0, nock_y, 0.0))
	if _preview_crossbow_string_right != null:
		_set_weapon_cylinder_endpoints(_preview_crossbow_string_right, Vector3(0.58, 0.53, 0.0), Vector3(0.0, nock_y, 0.0))


func _reset_preview_crossbow_geometry() -> void:
	_set_preview_crossbow_string_nock(PREVIEW_CROSSBOW_STRING_COCKED_Y)
	if _preview_crossbow_loaded_bolt != null:
		_preview_crossbow_loaded_bolt.visible = true


func _fire_preview_crossbow_bolt() -> void:
	_preview_crossbow_bolt_fired = true
	_preview_crossbow_shot_count += 1
	if _preview_crossbow_loaded_bolt == null or _visual_root == null:
		return
	if _formal_projectile_authority:
		_preview_crossbow_loaded_bolt.visible = false
		_set_preview_crossbow_string_nock(PREVIEW_CROSSBOW_STRING_RELEASED_Y)
		return
	var host := get_tree().current_scene as Node3D
	if host == null:
		host = get_parent() as Node3D
	if host == null:
		return
	var wood := _new_weapon_material("FlyingCrossbowBoltWood", Color(0.48, 0.25, 0.085, 1.0))
	var iron := _new_weapon_material("FlyingCrossbowBoltIron", Color(0.25, 0.27, 0.26, 1.0), 0.38)
	var projectile := _build_preview_crossbow_bolt(host, "CrossbowBoltProjectile%02d" % _preview_crossbow_shot_count, wood, iron)
	projectile.set_meta("presentation_only", true)
	projectile.set_meta("damage_authority", "combat_system_on_confirmed_hit")
	projectile.global_transform = _preview_crossbow_loaded_bolt.global_transform
	var forward := _visual_root.global_basis.z.normalized()
	var velocity := forward * PREVIEW_CROSSBOW_BOLT_SPEED + Vector3.UP * PREVIEW_CROSSBOW_BOLT_LIFT_SPEED
	_preview_arrow_projectiles.append({"node": projectile, "velocity": velocity, "age": 0.0, "kind": "crossbow", "lifetime": PREVIEW_CROSSBOW_BOLT_LIFETIME})
	_preview_crossbow_loaded_bolt.visible = false
	_set_preview_crossbow_string_nock(PREVIEW_CROSSBOW_STRING_RELEASED_Y)


func _update_preview_crossbow_alignment() -> void:
	var crossbow := _equipment_nodes.get("crossbow") as Node3D
	var right_hand := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if crossbow == null or right_hand == null or not crossbow.visible or _visual_root == null:
		return
	# Model contract: local +Y runs from the shoulder stock to the bolt point;
	# local +Z is the upper face carrying the lock, trigger and loaded bolt.
	# Keep those axes explicitly forward and up so correcting the vertical roll
	# cannot accidentally reverse the weapon again.
	var crossbow_forward := _visual_root.global_basis.z.normalized()
	var crossbow_up := Vector3.UP
	var crossbow_right := crossbow_forward.cross(crossbow_up).normalized()
	crossbow.global_basis = Basis(crossbow_right, crossbow_forward, crossbow_up).scaled(PREVIEW_CROSSBOW_SCALE)
	crossbow.global_position = _preview_crossbow_grip_target(right_hand)


func _preview_crossbow_grip_target(right_hand: BoneAttachment3D) -> Vector3:
	var down_offset := PREVIEW_CROSSBOW_ATTACK_DOWN_OFFSET if _preview_crossbow_attack_active else PREVIEW_CROSSBOW_IDLE_DOWN_OFFSET
	var target := right_hand.global_position + Vector3.DOWN * down_offset
	if _target_skeleton == null:
		return target
	var lower_arm_index := _target_skeleton.find_bone("RightLowerArm")
	if lower_arm_index < 0:
		return target
	var lower_arm_position := _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(lower_arm_index).origin)
	var palm_direction := right_hand.global_position - lower_arm_position
	if palm_direction.length_squared() > 0.0001:
		target += palm_direction.normalized() * PREVIEW_CROSSBOW_PALM_OFFSET
	var inward := lower_arm_position - right_hand.global_position
	if inward.length_squared() > 0.0001:
		target += inward.normalized() * PREVIEW_CROSSBOW_HAND_INWARD_OFFSET
	var visual_right := _visual_root.global_basis.x.normalized()
	var hand_side := signf((right_hand.global_position - global_position).dot(visual_right))
	if not is_zero_approx(hand_side):
		var centerline_offset := PREVIEW_CROSSBOW_CENTERLINE_OFFSET
		if _desired_state == "mounted_attack":
			centerline_offset += MOUNTED_CROSSBOW_CENTERLINE_EXTRA_OFFSET
		target -= visual_right * hand_side * centerline_offset
	return target


func _sync_engineering_kit_visibility(state_name: String, current_action: String) -> void:
	if not _equipment_nodes.has("engineer_wrench"):
		return
	var debug_preview := current_action.is_empty()
	var engineering_action := (
		current_action == "work_workshop"
		or current_action.begins_with("assist_repair_")
		or current_action.begins_with("assist_upgrade_")
	)
	var kit_visible := equipment_mode == "engineering_kit" or engineering_action
	_set_equipment_visible("engineer_goggles", kit_visible)
	_set_equipment_visible("engineer_tool_belt", kit_visible)
	_set_engineer_goggles_worn(state_name == "work" and (debug_preview or current_action == "work_workshop"))
	_set_equipment_visible("engineer_wrench", state_name == "work" and (debug_preview or engineering_action))
	_update_engineer_wrench_alignment()


func _sync_drink_mug_visibility(state_name: String, current_action: String) -> void:
	var drinking := state_name == "drink" and (current_action.is_empty() or current_action == "drink_wine")
	_set_equipment_visible("drink_mug", drinking)
	_update_drink_mug_alignment()


func _ensure_action_equipment(current_action: String) -> void:
	if current_action == "work_blacksmith" and not _equipment_nodes.has("hammer"):
		_add_equipment("hammer", "RightHand", HAMMER_HAND_LOCAL_POSITION, HAMMER_HAND_LOCAL_ROTATION_DEGREES * PI / 180.0, HAMMER_HAND_SCALE)
	elif current_action == "work_stable" and not _equipment_nodes.has("stable_broom"):
		_add_equipment("stable_broom", "RightHand", Vector3.ZERO, Vector3.ZERO, STABLE_TOOL_SCALE)
	elif current_action == "work_dining_hall" and not _equipment_nodes.has("cook_spoon"):
		_add_cook_spoon()
	elif current_action == "work_garden" and not _equipment_nodes.has("garden_hoe"):
		_add_garden_hoe()
	elif (current_action in ["work_clinic_doctor", "medical_treatment", "seated_study", "assist_heal"] or current_action.begins_with("assist_heal_")) and not _equipment_nodes.has("medical_satchel"):
		_add_medical_kit()
	elif (current_action == "work_workshop" or current_action.begins_with("assist_repair_") or current_action.begins_with("assist_upgrade_")) and not _equipment_nodes.has("engineer_wrench"):
		_add_engineering_kit()
	elif current_action == "drink_wine" and not _equipment_nodes.has("drink_mug"):
		_add_equipment("drink_mug", "RightHand", Vector3.ZERO, Vector3.ZERO, DRINK_MUG_SCALE)


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
	_sync_armor_visibility(state_name)
	if (
		not _debug_equipment_preview_active
		and not equipment_mode in ["sword_shield", "synced_sword_shield", "engineering_kit"]
		and _authority_main_weapon_id.is_empty()
	):
		return
	var active_weapon_id := _active_preview_weapon_id()
	_ensure_combat_weapon_node(active_weapon_id)
	var combat_visible := (
		_debug_preview_combat_visible
		if _debug_equipment_preview_active
		else _authority_combat_visible or state_name in [
			"attack",
			"training_instructor",
			"training_practice",
			"mounted_attack",
			"mounted_training",
		]
	)
	var authority_allows := (
		_debug_preview_combat_visible and _debug_preview_main_weapon_id == "sword_shield"
		if _debug_equipment_preview_active
		else combat_visible and (equipment_mode == "sword_shield" or active_weapon_id == "sword_shield")
	)
	var state_allows := state_name != "sleeping"
	_set_equipment_visible("sword", authority_allows and state_allows)
	_set_equipment_visible("shield", authority_allows and state_allows)
	var ranged_or_polearm_visible := combat_visible
	for weapon_id in ["polearm", "bow", "crossbow"]:
		_set_equipment_visible(weapon_id, ranged_or_polearm_visible and active_weapon_id == weapon_id and state_allows)
	_update_preview_polearm_alignment()
	_update_preview_bow_alignment()
	_update_preview_crossbow_alignment()
	_update_mounted_sword_shield_alignment()


func _update_mounted_sword_shield_alignment() -> void:
	if not _desired_state in MOUNTED_STATES or _visual_root == null:
		# Idle/carry states define the approved level pose. During a melee swing the
		# sword must keep that calibrated transform relative to RightHand so the
		# animated hand bone, rather than a world-space correction, drives the blade.
		if not _desired_state in ["attack", "training_practice"]:
			_restore_foot_sword_shield_alignment()
		return
	var sword := _equipment_nodes.get("sword") as Node3D
	var shield := _equipment_nodes.get("shield") as Node3D
	var right_hand := _equipment_sockets.get("RightHand") as BoneAttachment3D
	var left_hand := _equipment_sockets.get("LeftHand") as BoneAttachment3D
	var visual_forward := _visual_root.global_basis.z.normalized()
	if sword != null and sword.visible and right_hand != null and _desired_state in ["vehicle_seated", "mounted_walk"]:
		# Calibrate the carry pose once in the hand attachment. Mounted attacks never
		# touch the sword transform again: the animated right arm and hand must carry
		# the weapon as one rigid unit through the whole chop.
		var blade_axis := visual_forward
		var sword_side := visual_forward.cross(Vector3.UP).normalized()
		var sword_face := sword_side.cross(blade_axis).normalized()
		var sword_basis := Basis(sword_side, blade_axis, sword_face).orthonormalized().scaled(SWORD_SHIELD_SCALE)
		var grip_target := _mounted_sword_grip_target(right_hand)
		sword.global_basis = sword_basis
		sword.global_position = grip_target - sword.global_basis * MOUNTED_SWORD_GRIP_SOURCE_LOCAL_POSITION
		if _desired_state == "vehicle_seated":
			_mounted_sword_attack_attachment_transform = sword.transform
			_mounted_sword_attack_attachment_valid = true
	if shield != null and shield.visible and left_hand != null:
		var body_socket := _equipment_sockets.get("Body") as BoneAttachment3D
		var outward := left_hand.global_position - (body_socket.global_position if body_socket != null else _visual_root.global_position)
		outward.y = 0.0
		outward -= visual_forward * outward.dot(visual_forward)
		if outward.length_squared() <= 0.0001:
			outward = -_visual_root.global_basis.x
		outward = outward.normalized()
		var shield_right := Vector3.UP.cross(outward).normalized()
		var shield_basis := Basis(shield_right, Vector3.UP, outward).orthonormalized().scaled(SWORD_SHIELD_SCALE)
		var back_center_target := left_hand.global_position + outward * 0.045
		shield.global_basis = shield_basis
		shield.global_position = back_center_target - shield.global_basis * SHIELD_BACK_CENTER_SOURCE_LOCAL_POSITION


func _mounted_sword_grip_target(right_hand: BoneAttachment3D) -> Vector3:
	if _target_skeleton == null:
		return right_hand.global_position
	var lower_arm_index := _target_skeleton.find_bone("RightLowerArm")
	if lower_arm_index < 0:
		return right_hand.global_position
	var lower_arm_position := _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(lower_arm_index).origin)
	var outward := right_hand.global_position - lower_arm_position
	if outward.length_squared() <= 0.0001:
		return right_hand.global_position
	return (
		right_hand.global_position
		+ outward.normalized() * MOUNTED_SWORD_PALM_INSET
		+ Vector3.DOWN * MOUNTED_SWORD_GRIP_DOWN_OFFSET
	)


func _restore_foot_sword_shield_alignment() -> void:
	var sword := _equipment_nodes.get("sword") as Node3D
	var right_hand := _equipment_sockets.get("RightHand") as BoneAttachment3D
	if sword != null:
		if right_hand != null:
			# Keep the visible blade level and aimed forward in character space instead of
			# inheriting each retargeted rig's incompatible hand-bone rotation.
			var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else global_basis.z.normalized()
			var visual_right := _visual_root.global_basis.x.normalized() if _visual_root != null else global_basis.x.normalized()
			var blade_axis := visual_forward
			var blade_face_axis := visual_right.cross(blade_axis).normalized()
			sword.global_basis = Basis(visual_right, blade_axis, blade_face_axis).orthonormalized().scaled(SWORD_SHIELD_SCALE)
			var inward := global_position - right_hand.global_position
			inward.y = 0.0
			var visible_grip_target := right_hand.global_position + Vector3.DOWN * FOOT_SWORD_GRIP_DOWN_OFFSET
			if inward.length_squared() > 0.0001:
				visible_grip_target += inward.normalized() * FOOT_SWORD_GRIP_INWARD_OFFSET
			sword.global_position = visible_grip_target - sword.global_basis * SWORD_GRIP_SOURCE_LOCAL_POSITION
			if _desired_state == "idle":
				_foot_sword_attack_attachment_transform = sword.transform
				_foot_sword_attack_attachment_valid = true
	var shield := _equipment_nodes.get("shield") as Node3D
	if shield != null:
		shield.position = SHIELD_FOREARM_LOCAL_POSITION
		shield.rotation = _degrees_to_radians(SHIELD_FOREARM_LOCAL_ROTATION_DEGREES)
		shield.scale = SWORD_SHIELD_SCALE
		# Start from the shared authored pose every frame, then apply corrections in
		# visible world directions so "forward" cannot flip with a hand-bone basis.
		shield.global_position += shield.global_basis.z.normalized() * FOOT_SHIELD_FORWARD_OFFSET
		shield.global_position += Vector3.DOWN * FOOT_SHIELD_DOWN_OFFSET


func _restore_cached_sword_attack_attachment(state_name: String) -> void:
	if not _uses_sword_shield_weapon():
		return
	var sword := _equipment_nodes.get("sword") as Node3D
	if sword == null:
		return
	if state_name in ["attack", "training_practice"] and _foot_sword_attack_attachment_valid:
		sword.transform = _foot_sword_attack_attachment_transform
	elif state_name in ["mounted_attack", "mounted_training"]:
		# Mounted melee already composites the exact standing upper-body tracks over
		# the straddle legs. Reuse the standing hand-to-sword contract as well; the
		# mounted carry transform belongs only to horseback idle/walk and otherwise
		# changes the blade angle even though the animated right hand is identical.
		if _foot_sword_attack_attachment_valid:
			var attack_transform := _foot_sword_attack_attachment_transform
			# The standing upper-body clip supplies the approved swing basis, but its
			# standing attachment origin is not the mounted palm origin. Re-anchor the
			# authored grip marker for every rider so switching between enemy and
			# friendly appearances cannot leave the blade about 20 cm off the hand.
			if state_name == "mounted_attack":
				attack_transform.origin = (
					MOUNTED_ATTACK_GRIP_LOCAL_POSITION
					- attack_transform.basis * SWORD_GRIP_SOURCE_LOCAL_POSITION
				)
			sword.transform = attack_transform
		elif _mounted_sword_attack_attachment_valid:
			sword.transform = _mounted_sword_attack_attachment_transform


func _uses_sword_shield_weapon() -> bool:
	if _debug_equipment_preview_active:
		return _debug_preview_main_weapon_id == "sword_shield"
	return _authority_main_weapon_id == "sword_shield" or equipment_mode == "sword_shield"


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
	if _mounted_fall_active and _mounted_fall_elapsed < MOUNTED_FALL_AIRBORNE_SECONDS:
		var fall_ratio := clampf(_mounted_fall_elapsed / MOUNTED_FALL_AIRBORNE_SECONDS, 0.0, 1.0)
		var airborne_weight := sin(fall_ratio * PI)
		settle_roll += deg_to_rad(MOUNTED_FALL_MAX_ROLL_DEGREES) * _mounted_fall_side * airborne_weight
		settle_pitch += deg_to_rad(14.0) * airborne_weight
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
	if _mounted_fall_active:
		var start_offset := _get_formal_combat_mount_root_offset() + _get_mounted_seated_pose_offset(Vector3(
			SEATED_POSE_OFFSET.x,
			seated_pose_offset_y,
			SEATED_POSE_OFFSET.z
		))
		var fall_ratio := clampf(_mounted_fall_elapsed / MOUNTED_FALL_AIRBORNE_SECONDS, 0.0, 1.0)
		var eased_ratio := smoothstep(0.0, 1.0, fall_ratio)
		var offset := start_offset.lerp(_mounted_fall_landing_offset, eased_ratio)
		offset.y += sin(fall_ratio * PI) * MOUNTED_FALL_ARC_HEIGHT
		return offset
	if _mounted_fall_recovering:
		var recovery_ratio := 1.0 - clampf(_transient_remaining / GET_UP_SECONDS, 0.0, 1.0)
		return _mounted_fall_landing_offset.lerp(Vector3.ZERO, smoothstep(0.35, 1.0, recovery_ratio))
	if _desired_state in ["seated_prayer", "seated_study", "seated_eating"] or _desired_state in MOUNTED_STATES:
		var seated_offset := Vector3(SEATED_POSE_OFFSET.x, seated_pose_offset_y, SEATED_POSE_OFFSET.z)
		var states: Dictionary = _profile.get("states", {}) if _profile.get("states", {}) is Dictionary else {}
		if bool(states.get("combat_mounted", false)) and _spatial_attachment_pose != "vehicle_seated":
			return _get_formal_combat_mount_root_offset() + _get_mounted_seated_pose_offset(seated_offset)
		return seated_offset
	return Vector3.ZERO


func _get_mounted_visible_forward_local() -> Vector3:
	if _visual_root == null:
		return MOUNTED_PRESENTATION_REFERENCE.VISIBLE_FORWARD_LOCAL
	var visible_forward := Vector3(_visual_root.basis.z.x, 0.0, _visual_root.basis.z.z)
	if visible_forward.length_squared() <= 0.0001:
		return MOUNTED_PRESENTATION_REFERENCE.VISIBLE_FORWARD_LOCAL
	return visible_forward.normalized()


func _get_formal_combat_mount_root_offset() -> Vector3:
	return MOUNTED_PRESENTATION_REFERENCE.get_friendly_rider_root_offset(_get_mounted_visible_forward_local())


func _get_mounted_seated_pose_offset(seated_offset: Vector3) -> Vector3:
	return MOUNTED_PRESENTATION_REFERENCE.orient_local_offset_to_visible_forward(
		seated_offset,
		_get_mounted_visible_forward_local()
	)


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
	_sync_drink_mug_visibility(state_name, "")
	_sync_sword_shield_visibility(state_name)
	return debug_get_snapshot()


func debug_force_action_preview(action_id: String, state_name: String) -> Dictionary:
	if not REQUIRED_STATES.has(state_name):
		return {"ok": false, "error": "unknown_animation_state", "state": state_name}
	var preview_profile := _profile.duplicate(true)
	var states: Dictionary = preview_profile.get("states", {}) if preview_profile.get("states", {}) is Dictionary else {}
	states = states.duplicate(true)
	states["current_action"] = action_id
	preview_profile["states"] = states
	_profile = preview_profile
	_debug_forced_state = state_name
	_transient_state = ""
	_transient_remaining = 0.0
	_ensure_action_equipment(action_id)
	_desired_state = state_name
	if not _play_state(state_name, true):
		return {"ok": false, "error": "missing_animation_clip", "state": state_name, "clip": _get_state_clip(state_name)}
	_place_hammer(state_name == "work" and action_id == "work_blacksmith")
	_place_stable_broom(state_name == "work" and action_id == "work_stable")
	_place_cook_spoon(state_name == "work" and action_id == "work_dining_hall")
	_place_garden_hoe(state_name == "work" and action_id == "work_garden")
	_sync_medical_kit_visibility(state_name, action_id)
	_sync_engineering_kit_visibility(state_name, action_id)
	_sync_drink_mug_visibility(state_name, action_id)
	_sync_sword_shield_visibility(state_name)
	return debug_get_snapshot()


func debug_advance_preview_bow_attack(seconds: float) -> Dictionary:
	var remaining := maxf(0.0, seconds)
	while remaining > 0.0:
		var step := minf(1.0 / 60.0, remaining)
		_update_preview_bow_attack(step)
		_update_preview_bow_alignment()
		_update_preview_arrow_projectiles(step)
		remaining -= step
	return debug_get_snapshot()


func debug_advance_preview_crossbow_attack(seconds: float) -> Dictionary:
	var remaining := maxf(0.0, seconds)
	while remaining > 0.0:
		var step := minf(1.0 / 60.0, remaining)
		_update_preview_crossbow_attack(step)
		_update_preview_crossbow_alignment()
		_update_preview_arrow_projectiles(step)
		remaining -= step
	return debug_get_snapshot()


func debug_set_equipment_preview(main_weapon_id: String, combat_visible: bool) -> Dictionary:
	# The standalone developer lab needs to inspect attachment readiness without
	# writing NPCSystem or EquipmentSystem. The override is opt-in per instance.
	_debug_equipment_preview_active = true
	_debug_preview_main_weapon_id = main_weapon_id.strip_edges()
	_debug_preview_combat_visible = combat_visible
	if _debug_preview_main_weapon_id == "sword_shield":
		_ensure_debug_sword_shield_nodes()
	else:
		_ensure_preview_weapon_node(_debug_preview_main_weapon_id)
	_sync_sword_shield_visibility(_desired_state)
	return debug_get_snapshot()


func debug_set_armor_preview(armor_ids_by_slot: Dictionary, combat_visible: bool) -> Dictionary:
	# Keep armor under the same opt-in developer preview authority as weapons. The
	# actual models remain bone-attached presentation only; EquipmentSystem owns the
	# authoritative items and stats in the formal game.
	_debug_equipment_preview_active = true
	_debug_preview_combat_visible = combat_visible
	_debug_preview_armor_ids.clear()
	for slot in ARMOR_SLOTS:
		_debug_preview_armor_ids[slot] = str(armor_ids_by_slot.get(slot, ""))
	_ensure_armor_nodes()
	_sync_armor_visibility(_desired_state)
	return debug_get_snapshot()


func _ensure_debug_sword_shield_nodes() -> void:
	_ensure_sword_shield_nodes()


func has_attachment_socket(socket_name: String) -> bool:
	return _equipment_sockets.get(socket_name) is Node3D


func get_attachment_global_position(socket_name: String) -> Vector3:
	var socket := _equipment_sockets.get(socket_name) as Node3D
	return socket.global_position if socket != null else global_position


func get_combat_projectile_release_transform(weapon_type: String) -> Transform3D:
	if weapon_type == "bow" and _preview_bow_loaded_arrow != null:
		return _preview_bow_loaded_arrow.global_transform
	if weapon_type == "crossbow" and _preview_crossbow_loaded_bolt != null:
		return _preview_crossbow_loaded_bolt.global_transform
	var right_hand := _equipment_sockets.get("RightHand") as Node3D
	return right_hand.global_transform if right_hand != null else global_transform


func get_combat_projectile_release_snapshot(weapon_type: String) -> Dictionary:
	var projectile_node: Node3D = null
	var weapon_node: Node3D = null
	match weapon_type:
		"bow":
			projectile_node = _preview_bow_loaded_arrow
			weapon_node = _equipment_nodes.get("bow") as Node3D
		"crossbow":
			projectile_node = _preview_crossbow_loaded_bolt
			weapon_node = _equipment_nodes.get("crossbow") as Node3D
		_:
			return {"ready": false, "reason": "unsupported_projectile_weapon", "weapon_type": weapon_type}
	var ready := (
		projectile_node != null
		and is_instance_valid(projectile_node)
		and weapon_node != null
		and is_instance_valid(weapon_node)
		and weapon_node.visible
		and _active_preview_weapon_id() == weapon_type
	)
	return {
		"ready": ready,
		"reason": "" if ready else "formal_loaded_projectile_unavailable",
		"weapon_type": weapon_type,
		"transform": projectile_node.global_transform if ready else Transform3D.IDENTITY,
		"origin_source": "formal_loaded_arrow" if weapon_type == "bow" else "formal_loaded_bolt",
		"mounted": _desired_state == "mounted_attack" or bool((_profile.get("states", {}) as Dictionary).get("combat_mounted", false)),
		"projectile_node_path": str(projectile_node.get_path()) if ready else "",
		"projectile_visible_at_sample": projectile_node.visible if ready else false,
		"weapon_visible_at_sample": weapon_node.visible if ready else false,
	}


func get_combat_melee_contact_segment(weapon_type: String) -> Dictionary:
	if not weapon_type in ["sword_shield", "polearm"] or _animation_player == null:
		return {}
	var weapon := _equipment_nodes.get("sword" if weapon_type == "sword_shield" else "polearm") as Node3D
	if weapon == null or not weapon.visible:
		return {}
	var contact_start := (
		weapon.global_transform * SWORD_BLADE_BASE_LOCAL_POSITION
		if weapon_type == "sword_shield"
		else weapon.global_transform * PREVIEW_POLEARM_SHAFT_FRONT_LOCAL_POSITION
	)
	var contact_end := (
		weapon.global_transform * SWORD_BLADE_TIP_LOCAL_POSITION
		if weapon_type == "sword_shield"
		else weapon.global_transform * PREVIEW_POLEARM_TIP_LOCAL_POSITION
	)
	var current_clip := str(_animation_player.assigned_animation)
	var valid_attack_clips := (
		[str(STATE_CLIPS.attack), MOUNTED_ATTACK_CLIP]
		if weapon_type == "sword_shield"
		else [PREVIEW_POLEARM_THRUST_CLIP, MOUNTED_POLEARM_ATTACK_CLIP]
	)
	return {
		"authored_seconds": _animation_player.current_animation_position,
		"animation_name": current_clip,
		"contact_start": contact_start,
		"contact_end": contact_end,
		"weapon_type": weapon_type,
		"mounted": _desired_state == "mounted_attack",
		"attack_visible": current_clip in valid_attack_clips,
		"geometry_source": "formal_character_model"
	}


func debug_get_snapshot() -> Dictionary:
	var available_clips: Array[String] = []
	if _animation_player != null:
		for raw_name in _animation_player.get_animation_list():
			available_clips.append(str(raw_name))
	var socket_snapshot := {}
	var hips_global_position := global_position
	var mounted_upper_body_forward_offset := 0.0
	var mounted_torso_facing_dot := -1.0
	if _target_skeleton != null:
		var hips_index := _target_skeleton.find_bone("Hips")
		if hips_index >= 0:
			hips_global_position = _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(hips_index).origin)
		var head_index := _target_skeleton.find_bone("Head")
		if hips_index >= 0 and head_index >= 0 and _visual_root != null:
			var head_global_position := _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(head_index).origin)
			mounted_upper_body_forward_offset = (head_global_position - hips_global_position).dot(_visual_root.global_basis.z.normalized())
		var left_shoulder_index := _target_skeleton.find_bone("LeftShoulder")
		var right_shoulder_index := _target_skeleton.find_bone("RightShoulder")
		if left_shoulder_index >= 0 and right_shoulder_index >= 0 and _visual_root != null:
			var left_shoulder_position := _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(left_shoulder_index).origin)
			var right_shoulder_position := _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(right_shoulder_index).origin)
			var shoulder_axis := right_shoulder_position - left_shoulder_position
			shoulder_axis.y = 0.0
			if shoulder_axis.length_squared() > 0.0001:
				var torso_forward := Vector3.UP.cross(shoulder_axis.normalized()).normalized()
				mounted_torso_facing_dot = torso_forward.dot(_visual_root.global_basis.z.normalized())
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
	var drink_mug := _equipment_nodes.get("drink_mug") as Node3D
	var polearm := _equipment_nodes.get("polearm") as Node3D
	var bow := _equipment_nodes.get("bow") as Node3D
	var crossbow := _equipment_nodes.get("crossbow") as Node3D
	var sword := _equipment_nodes.get("sword") as Node3D
	var shield := _equipment_nodes.get("shield") as Node3D
	var garden_hoe_blade := garden_hoe.find_child("IronBlade", true, false) as Node3D if garden_hoe != null else null
	var right_hand := _equipment_sockets.get("RightHand") as BoneAttachment3D
	var left_hand := _equipment_sockets.get("LeftHand") as BoneAttachment3D
	var sword_grip_hand_distance := -1.0
	var sword_grip_global_position := Vector3.ZERO
	var right_lower_arm_global_position := Vector3.ZERO
	var mounted_sword_grip_palm_distance := -1.0
	var sword_tip_hand_distance := -1.0
	var sword_forward_dot := -1.0
	var sword_blade_up_dot := -1.0
	var sword_tip_above_grip := -1.0
	var sword_sagittal_side_dot := -1.0
	var shield_hand_distance := -1.0
	var shield_back_hand_distance := -1.0
	var shield_back_hand_clearance := -1.0
	var shield_back_hand_vertical_offset := 0.0
	var shield_face_normal := Vector3.ZERO
	var shield_up_axis := Vector3.ZERO
	var shield_face_forward_dot := -1.0
	var wooden_cross_up_axis := Vector3.ZERO
	var wooden_cross_face_normal := Vector3.ZERO
	var wooden_cross_up_dot := -1.0
	var wooden_cross_face_forward_dot := -1.0
	var hammer_head_forward_dot := -1.0
	var hammer_long_axis_up_dot := -1.0
	var hammer_grip_hand_distance := -1.0
	var hammer_handle_rear_hand_distance := -1.0
	var hammer_head_near_hand_distance := -1.0
	var cook_spoon_grip_hand_distance := -1.0
	var cook_spoon_forward_dot := -1.0
	var cook_spoon_down_dot := -1.0
	var stable_tool_grip_hand_distance := -1.0
	var stable_tool_forward_dot := -1.0
	var stable_tool_down_dot := -1.0
	var engineer_wrench_grip_hand_distance := -1.0
	var engineer_wrench_forward_dot := -1.0
	var engineer_wrench_down_dot := -1.0
	var drink_mug_grip_hand_distance := -1.0
	var drink_mug_rim_head_distance := -1.0
	var polearm_grip_palm_distance := -1.0
	var polearm_axis_up_dot := -1.0
	var polearm_axis_forward_dot := -1.0
	var polearm_right_hand_shaft_distance := -1.0
	var polearm_left_hand_shaft_distance := -1.0
	var polearm_tip_forward_offset := -1.0
	var polearm_shaft_length := -1.0
	var bow_grip_palm_distance := -1.0
	var bow_long_axis_forward_dot := -1.0
	var bow_string_present := false
	var bow_string_above_grip_offset := -1.0
	var bow_attack_grip_palm_distance := -1.0
	var bow_attack_long_axis_up_dot := -1.0
	var bow_attack_string_back_dot := -1.0
	var bow_loaded_arrow_forward_dot := -1.0
	var bow_arrow_head_is_pointed := false
	var crossbow_forward_dot := -1.0
	var crossbow_top_up_dot := -1.0
	var crossbow_grip_palm_distance := -1.0
	var crossbow_grip_right_hand_distance := -1.0
	var crossbow_support_hand_stock_distance := -1.0
	var crossbow_side_offset := -1.0
	var crossbow_active_projectile_count := 0
	for projectile_entry in _preview_arrow_projectiles:
		if str(projectile_entry.get("kind", "bow")) == "crossbow":
			crossbow_active_projectile_count += 1
	if hammer != null:
		var hammer_long_axis := hammer.global_basis.y.normalized()
		var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else Vector3.FORWARD
		hammer_head_forward_dot = hammer_long_axis.dot(visual_forward)
		hammer_long_axis_up_dot = absf(hammer_long_axis.dot(Vector3.UP))
	if _wooden_cross != null:
		wooden_cross_up_axis = _wooden_cross.global_basis.y.normalized()
		wooden_cross_face_normal = _wooden_cross.global_basis.z.normalized()
		var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else Vector3.FORWARD
		wooden_cross_up_dot = wooden_cross_up_axis.dot(Vector3.UP)
		wooden_cross_face_forward_dot = wooden_cross_face_normal.dot(visual_forward)
	if sword != null and right_hand != null:
		var sword_grip_world := sword.global_transform * SWORD_GRIP_SOURCE_LOCAL_POSITION
		sword_grip_global_position = sword_grip_world
		sword_grip_hand_distance = sword_grip_world.distance_to(right_hand.global_position)
		if _target_skeleton != null:
			var right_lower_arm_index := _target_skeleton.find_bone("RightLowerArm")
			if right_lower_arm_index >= 0:
				right_lower_arm_global_position = _target_skeleton.to_global(_target_skeleton.get_bone_global_pose(right_lower_arm_index).origin)
		if _desired_state in MOUNTED_STATES:
			var mounted_sword_grip_world := sword.global_transform * MOUNTED_SWORD_GRIP_SOURCE_LOCAL_POSITION
			mounted_sword_grip_palm_distance = mounted_sword_grip_world.distance_to(_mounted_sword_grip_target(right_hand))
		var sword_tip_world := sword.global_transform * Vector3(0.0, 1.266, 0.0)
		sword_tip_hand_distance = sword_tip_world.distance_to(right_hand.global_position)
		var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else Vector3.FORWARD
		sword_forward_dot = sword.global_basis.y.normalized().dot(visual_forward)
		if _visual_root != null:
			sword_sagittal_side_dot = absf(sword.global_basis.y.normalized().dot(_visual_root.global_basis.x.normalized()))
		# The authored sword mesh extends from the grip along local +Y.
		sword_blade_up_dot = sword.global_basis.y.normalized().dot(Vector3.UP)
		sword_tip_above_grip = sword_tip_world.y - sword_grip_world.y
	if hammer != null and right_hand != null and hammer.get_parent() == right_hand:
		hammer_grip_hand_distance = (hammer.global_transform * HAMMER_GRIP_SOURCE_LOCAL_POSITION).distance_to(right_hand.global_position)
		hammer_handle_rear_hand_distance = (hammer.global_transform * HAMMER_HANDLE_REAR_SOURCE_LOCAL_POSITION).distance_to(right_hand.global_position)
		hammer_head_near_hand_distance = (hammer.global_transform * HAMMER_HEAD_NEAR_SOURCE_LOCAL_POSITION).distance_to(right_hand.global_position)
	if cook_spoon != null:
		var spoon_axis := cook_spoon.global_basis.y.normalized()
		var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else _target_facing_direction
		cook_spoon_forward_dot = spoon_axis.dot(visual_forward)
		cook_spoon_down_dot = spoon_axis.dot(Vector3.DOWN)
		if right_hand != null and cook_spoon.get_parent() == right_hand:
			cook_spoon_grip_hand_distance = (cook_spoon.global_transform * COOK_SPOON_GRIP_SOURCE_LOCAL_POSITION).distance_to(_cook_spoon_grip_target(right_hand))
	if stable_broom != null:
		var stable_tool_axis := (-stable_broom.global_basis.y).normalized()
		var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else _target_facing_direction
		stable_tool_forward_dot = stable_tool_axis.dot(visual_forward)
		stable_tool_down_dot = stable_tool_axis.dot(Vector3.DOWN)
		if right_hand != null and stable_broom.get_parent() == right_hand:
			stable_tool_grip_hand_distance = (stable_broom.global_transform * STABLE_TOOL_GRIP_SOURCE_LOCAL_POSITION).distance_to(right_hand.global_position)
	if engineer_wrench != null:
		var engineer_wrench_axis := engineer_wrench.global_basis.y.normalized()
		var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else _target_facing_direction
		engineer_wrench_forward_dot = engineer_wrench_axis.dot(visual_forward)
		engineer_wrench_down_dot = engineer_wrench_axis.dot(Vector3.DOWN)
		if right_hand != null and engineer_wrench.get_parent() == right_hand:
			engineer_wrench_grip_hand_distance = (engineer_wrench.global_transform * ENGINEER_WRENCH_GRIP_SOURCE_LOCAL_POSITION).distance_to(right_hand.global_position)
	if drink_mug != null and right_hand != null:
		drink_mug_grip_hand_distance = (drink_mug.global_transform * DRINK_MUG_GRIP_SOURCE_LOCAL_POSITION).distance_to(_drink_mug_grip_target(right_hand))
		var head := _equipment_sockets.get("Head") as BoneAttachment3D
		if head != null:
			drink_mug_rim_head_distance = (drink_mug.global_transform * Vector3(0.0, 0.18, 0.0)).distance_to(head.global_position)
	if polearm != null and right_hand != null:
		polearm_grip_palm_distance = (polearm.global_transform * PREVIEW_POLEARM_GRIP_SOURCE_LOCAL_POSITION).distance_to(_preview_polearm_grip_target(right_hand))
		polearm_axis_up_dot = absf(polearm.global_basis.y.normalized().dot(Vector3.UP))
		if _visual_root != null:
			polearm_axis_forward_dot = polearm.global_basis.y.normalized().dot(_visual_root.global_basis.z.normalized())
		var shaft_rear := polearm.global_transform * PREVIEW_POLEARM_SHAFT_REAR_LOCAL_POSITION
		var shaft_front := polearm.global_transform * PREVIEW_POLEARM_SHAFT_FRONT_LOCAL_POSITION
		polearm_shaft_length = shaft_rear.distance_to(shaft_front)
		polearm_right_hand_shaft_distance = _distance_to_segment(_hand_palm_target(right_hand, "RightLowerArm"), shaft_rear, shaft_front)
		if left_hand != null:
			polearm_left_hand_shaft_distance = _distance_to_segment(_hand_palm_target(left_hand, "LeftLowerArm"), shaft_rear, shaft_front)
		if _visual_root != null:
			polearm_tip_forward_offset = ((polearm.global_transform * PREVIEW_POLEARM_TIP_LOCAL_POSITION) - global_position).dot(_visual_root.global_basis.z.normalized())
	if bow != null and left_hand != null:
		var bow_grip_world := bow.global_transform * PREVIEW_BOW_GRIP_SOURCE_LOCAL_POSITION
		bow_grip_palm_distance = bow_grip_world.distance_to(_preview_bow_grip_target(left_hand))
		if _preview_bow_attack_active:
			bow_attack_grip_palm_distance = bow_grip_world.distance_to(_preview_bow_grip_target(left_hand))
			bow_attack_long_axis_up_dot = bow.global_basis.y.normalized().dot(Vector3.UP)
			if _visual_root != null:
				var visual_forward := _visual_root.global_basis.z.normalized()
				bow_attack_string_back_dot = (-bow.global_basis.z.normalized()).dot(-visual_forward)
				if _preview_bow_loaded_arrow != null:
					bow_loaded_arrow_forward_dot = _preview_bow_loaded_arrow.global_basis.y.normalized().dot(visual_forward)
	if _preview_bow_loaded_arrow != null:
		var arrow_head := _preview_bow_loaded_arrow.find_child("ArrowHead", true, false) as MeshInstance3D
		var arrow_head_mesh := arrow_head.mesh as CylinderMesh if arrow_head != null else null
		bow_arrow_head_is_pointed = arrow_head_mesh != null and is_zero_approx(arrow_head_mesh.top_radius) and arrow_head_mesh.bottom_radius > 0.0
		if _visual_root != null:
			bow_long_axis_forward_dot = absf(bow.global_basis.y.normalized().dot(_visual_root.global_basis.z.normalized()))
		var bow_string := bow.find_child("BowString", true, false) as MeshInstance3D
		bow_string_present = bow_string != null
		if bow_string != null:
			bow_string_above_grip_offset = bow_string.global_position.y - (bow.global_transform * PREVIEW_BOW_GRIP_SOURCE_LOCAL_POSITION).y
	if crossbow != null and _visual_root != null:
		crossbow_forward_dot = crossbow.global_basis.y.normalized().dot(_visual_root.global_basis.z.normalized())
		crossbow_top_up_dot = crossbow.global_basis.z.normalized().dot(Vector3.UP)
		crossbow_side_offset = (crossbow.global_position - global_position).dot(_visual_root.global_basis.x.normalized())
		if right_hand != null:
			crossbow_grip_palm_distance = crossbow.global_position.distance_to(_preview_crossbow_grip_target(right_hand))
			crossbow_grip_right_hand_distance = crossbow.global_position.distance_to(right_hand.global_position)
		if left_hand != null:
			crossbow_support_hand_stock_distance = _distance_to_segment(
				_hand_palm_target(left_hand, "LeftLowerArm"),
				crossbow.global_transform * Vector3(0.0, 0.05, 0.0),
				crossbow.global_transform * Vector3(0.0, 0.58, 0.0)
			)
	if shield != null:
		shield_face_normal = shield.global_basis.z.normalized()
		shield_up_axis = shield.global_basis.y.normalized()
		var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else Vector3.FORWARD
		shield_face_forward_dot = shield_face_normal.dot(visual_forward)
		if left_hand != null:
			shield_hand_distance = shield.global_position.distance_to(left_hand.global_position)
			var shield_back_center := shield.global_transform * SHIELD_BACK_CENTER_SOURCE_LOCAL_POSITION
			shield_back_hand_distance = shield_back_center.distance_to(left_hand.global_position)
			shield_back_hand_clearance = (shield_back_center - left_hand.global_position).dot(shield_face_normal)
			shield_back_hand_vertical_offset = (shield_back_center - left_hand.global_position).dot(Vector3.UP)
	var garden_hoe_front_offset := -1.0
	var garden_hoe_left_hand_distance := -1.0
	var garden_hoe_right_hand_distance := -1.0
	if garden_hoe != null and garden_hoe_blade != null:
		var visual_forward := _visual_root.global_basis.z.normalized() if _visual_root != null else Vector3.FORWARD
		garden_hoe_front_offset = (garden_hoe_blade.global_position - global_position).dot(visual_forward)
		if left_hand != null and right_hand != null:
			var shaft_rear := garden_hoe.global_transform * GARDEN_HOE_HANDLE_REAR_LOCAL_POSITION
			var shaft_front := garden_hoe.global_transform * GARDEN_HOE_HANDLE_FRONT_LOCAL_POSITION
			garden_hoe_left_hand_distance = _distance_to_segment(
				_hand_palm_target(left_hand, "LeftLowerArm"),
				shaft_rear,
				shaft_front
			)
			garden_hoe_right_hand_distance = _distance_to_segment(
				_hand_palm_target(right_hand, "RightLowerArm"),
				shaft_rear,
				shaft_front
			)
	var resolved_state_clips := STATE_CLIPS.duplicate(true)
	resolved_state_clips["work"] = work_clip
	resolved_state_clips["mass_leader"] = mass_leader_clip
	resolved_state_clips["medical_treatment"] = medical_treatment_clip
	var armor_snapshot := {}
	for slot in ARMOR_SLOTS:
		var part_snapshots: Array = []
		var slot_visible := false
		var slot_mesh_count := 0
		for raw_part in (_armor_nodes_by_slot.get(slot, []) as Array):
			var armor_part := raw_part as Node3D
			if armor_part == null:
				continue
			var part_mesh_count := (
				1 + armor_part.find_children("*", "MeshInstance3D", true, false).size()
				if armor_part is MeshInstance3D
				else armor_part.find_children("*", "MeshInstance3D", true, false).size()
			)
			slot_visible = slot_visible or armor_part.visible
			slot_mesh_count += part_mesh_count
			part_snapshots.append({
				"name": armor_part.name,
				"parent": str(armor_part.get_parent().name) if armor_part.get_parent() != null else "",
				"visible": armor_part.visible,
				"mesh_count": part_mesh_count,
				"mesh_aabb": (
					(armor_part as MeshInstance3D).mesh.get_aabb()
					if armor_part is MeshInstance3D and (armor_part as MeshInstance3D).mesh != null
					else AABB()
				),
				"skinned": armor_part is MeshInstance3D and (armor_part as MeshInstance3D).skin != null,
			})
		armor_snapshot[slot] = {
			"item_id": str((_debug_preview_armor_ids if _debug_equipment_preview_active else _authority_armor_ids).get(slot, "")),
			"source_asset": SYNTY_KNIGHT_ARMOR_EXTRACTOR.SOURCE_SCENE_PATH,
			"visible": slot_visible,
			"part_count": part_snapshots.size(),
			"mesh_count": slot_mesh_count,
			"parts": part_snapshots,
		}
	return {
		"ready": _ready_ok,
		"appearance_id": appearance_id,
		"state_contract": REQUIRED_STATES.duplicate(),
		"state_clips": resolved_state_clips,
		"current_state": _current_state,
		"desired_state": _desired_state,
		"current_clip": _current_clip,
		"current_animation_playing": _animation_player.is_playing() if _animation_player != null else false,
		"current_animation_position": _animation_player.current_animation_position if _animation_player != null else 0.0,
		"current_animation_length": _animation_player.current_animation_length if _animation_player != null else 0.0,
		"temporary_presentation_state": _transient_state,
		"temporary_presentation_remaining_seconds": _transient_remaining,
		"gameplay_paused": _is_gameplay_paused(),
		"animation_paused": _animation_paused,
		"pause_exempt_dialogue_emotion_action": _is_pause_exempt_dialogue_emotion_action(),
		"last_temporary_presentation_event_id": _last_temporary_presentation_event_id,
		"temporary_presentation_event_count": _temporary_presentation_event_count,
		"combat_attack_sequence": _combat_attack_sequence,
		"combat_attack_phase": _combat_attack_phase,
		"combat_attack_elapsed_seconds": _combat_attack_elapsed_seconds,
		"combat_attack_cycle_seconds": _combat_attack_cycle_seconds,
		"combat_attack_impact_seconds": _combat_attack_impact_seconds,
		"combat_attack_playback_multiplier": _combat_attack_playback_multiplier,
		"combat_attack_animation_speed_scale": _animation_player.speed_scale if _animation_player != null else 0.0,
		"combat_attack_animation_position": _animation_player.current_animation_position if _animation_player != null and _current_state in ["attack", "mounted_attack"] else -1.0,
		"combat_attack_animation_length": _animation_player.current_animation_length if _animation_player != null and _current_state in ["attack", "mounted_attack"] else 0.0,
		"mounted_thigh_spread_degrees": MOUNTED_THIGH_SPREAD_DEGREES,
		"available_clips": available_clips,
		"available_clip_count": available_clips.size(),
		"source_bones": _source_skeleton.get_bone_count() if _source_skeleton != null else 0,
		"target_bones": _target_skeleton.get_bone_count() if _target_skeleton != null else 0,
		"hips_global_position": hips_global_position,
		"rebound_mesh_count": _target_mesh_count,
		"equipment_mode": equipment_mode,
		"use_imported_character_material": use_imported_character_material,
		"remove_detached_headwear": remove_detached_headwear,
		"removed_headwear_triangle_count": _removed_headwear_triangle_count,
		"wooden_cross_visible": _wooden_cross != null and _wooden_cross.visible,
		"wooden_cross_parent": str(_wooden_cross.get_parent().name) if _wooden_cross != null and _wooden_cross.get_parent() != null else "",
		"wooden_cross_local_position": _wooden_cross.position if _wooden_cross != null else Vector3.ZERO,
		"wooden_cross_local_rotation_degrees": _wooden_cross.rotation_degrees if _wooden_cross != null else Vector3.ZERO,
		"wooden_cross_up_axis": wooden_cross_up_axis,
		"wooden_cross_face_normal": wooden_cross_face_normal,
		"wooden_cross_up_dot": wooden_cross_up_dot,
		"wooden_cross_face_forward_dot": wooden_cross_face_forward_dot,
		"rounded_tonsure_hair_visible": _rounded_tonsure_hair != null and _rounded_tonsure_hair.visible,
		"rounded_tonsure_hair_parent": str(_rounded_tonsure_hair.get_parent().name) if _rounded_tonsure_hair != null and _rounded_tonsure_hair.get_parent() != null else "",
		"rounded_tonsure_hair_mesh_count": _rounded_tonsure_hair.find_children("*", "MeshInstance3D", true, false).size() if _rounded_tonsure_hair != null else 0,
		"palette_saturation": palette_saturation,
		"palette_value_scale": palette_value_scale,
		"palette_path": palette_texture.resource_path if palette_texture != null else "",
		"socket_contract": socket_snapshot,
		"armor": armor_snapshot,
		"armor_model_style": "faceted_low_poly_synty_compatible",
		"armor_material_source": "procedural_modular_no_compatible_source_parts",
		"helmet_hair_hidden": _helmet_hair_hidden,
		"hammer_parent": str(hammer.get_parent().name) if hammer != null and hammer.get_parent() != null else "",
		"hammer_visible": hammer != null and hammer.visible,
		"hammer_local_position": hammer.position if hammer != null else Vector3.ZERO,
		"hammer_local_rotation_degrees": hammer.rotation_degrees if hammer != null else Vector3.ZERO,
		"hammer_head_forward_dot": hammer_head_forward_dot,
		"hammer_long_axis_up_dot": hammer_long_axis_up_dot,
		"hammer_grip_source_local_position": HAMMER_GRIP_SOURCE_LOCAL_POSITION,
		"hammer_grip_hand_distance": hammer_grip_hand_distance,
		"hammer_handle_rear_hand_distance": hammer_handle_rear_hand_distance,
		"hammer_head_near_hand_distance": hammer_head_near_hand_distance,
		"stable_broom_parent": str(stable_broom.get_parent().name) if stable_broom != null and stable_broom.get_parent() != null else "",
		"stable_broom_visible": stable_broom != null and stable_broom.visible,
		"stable_broom_local_position": stable_broom.position if stable_broom != null else Vector3.ZERO,
		"stable_broom_local_rotation_degrees": stable_broom.rotation_degrees if stable_broom != null else Vector3.ZERO,
		"stable_tool_grip_source_local_position": STABLE_TOOL_GRIP_SOURCE_LOCAL_POSITION,
		"stable_tool_grip_hand_distance": stable_tool_grip_hand_distance,
		"stable_tool_forward_dot": stable_tool_forward_dot,
		"stable_tool_down_dot": stable_tool_down_dot,
		"cook_spoon_parent": str(cook_spoon.get_parent().name) if cook_spoon != null and cook_spoon.get_parent() != null else "",
		"cook_spoon_visible": cook_spoon != null and cook_spoon.visible,
		"cook_spoon_local_position": cook_spoon.position if cook_spoon != null else Vector3.ZERO,
		"cook_spoon_local_rotation_degrees": cook_spoon.rotation_degrees if cook_spoon != null else Vector3.ZERO,
		"cook_spoon_grip_source_local_position": COOK_SPOON_GRIP_SOURCE_LOCAL_POSITION,
		"cook_spoon_palm_inward_offset": COOK_SPOON_PALM_INWARD_OFFSET,
		"cook_spoon_grip_hand_distance": cook_spoon_grip_hand_distance,
		"cook_spoon_forward_dot": cook_spoon_forward_dot,
		"cook_spoon_down_dot": cook_spoon_down_dot,
		"garden_hoe_parent": str(garden_hoe.get_parent().name) if garden_hoe != null and garden_hoe.get_parent() != null else "",
		"garden_hoe_visible": garden_hoe != null and garden_hoe.visible,
		"garden_hoe_local_position": garden_hoe.position if garden_hoe != null else Vector3.ZERO,
		"garden_hoe_front_offset": garden_hoe_front_offset,
		"garden_hoe_left_hand_distance": garden_hoe_left_hand_distance,
		"garden_hoe_right_hand_distance": garden_hoe_right_hand_distance,
		"drink_mug_parent": str(drink_mug.get_parent().name) if drink_mug != null and drink_mug.get_parent() != null else "",
		"drink_mug_visible": drink_mug != null and drink_mug.visible,
		"drink_mug_grip_hand_distance": drink_mug_grip_hand_distance,
		"drink_mug_rim_head_distance": drink_mug_rim_head_distance,
		"polearm_visible": polearm != null and polearm.visible,
		"polearm_parent": str(polearm.get_parent().name) if polearm != null and polearm.get_parent() != null else "",
		"polearm_mesh_count": polearm.find_children("*", "MeshInstance3D", true, false).size() if polearm != null else 0,
		"polearm_grip_palm_distance": polearm_grip_palm_distance,
		"polearm_axis_up_dot": polearm_axis_up_dot,
		"polearm_axis_forward_dot": polearm_axis_forward_dot,
		"polearm_palm_inward_offset": PREVIEW_POLEARM_INWARD_OFFSET,
		"polearm_right_hand_shaft_distance": polearm_right_hand_shaft_distance,
		"polearm_left_hand_shaft_distance": polearm_left_hand_shaft_distance,
		"polearm_tip_forward_offset": polearm_tip_forward_offset,
		"polearm_shaft_length": polearm_shaft_length,
		"bow_visible": bow != null and bow.visible,
		"bow_parent": str(bow.get_parent().name) if bow != null and bow.get_parent() != null else "",
		"bow_mesh_count": bow.find_children("*", "MeshInstance3D", true, false).size() if bow != null else 0,
		"bow_grip_palm_distance": bow_grip_palm_distance,
		"bow_long_axis_forward_dot": bow_long_axis_forward_dot,
		"bow_string_present": bow_string_present,
		"bow_string_above_grip_offset": bow_string_above_grip_offset,
		"bow_down_offset": PREVIEW_BOW_DOWN_OFFSET,
		"bow_attack_active": _preview_bow_attack_active,
		"bow_attack_phase": _preview_bow_attack_phase,
		"bow_attack_grip_palm_distance": bow_attack_grip_palm_distance,
		"bow_attack_long_axis_up_dot": bow_attack_long_axis_up_dot,
		"bow_attack_string_back_dot": bow_attack_string_back_dot,
		"bow_loaded_arrow_forward_dot": bow_loaded_arrow_forward_dot,
		"bow_nock_pull_hand_distance": _preview_bow_nock_pull_hand_distance,
		"bow_arrow_visible_length": PREVIEW_ARROW_TIP_LOCAL_Y - PREVIEW_ARROW_REAR_LOCAL_Y,
		"bow_arrow_head_is_pointed": bow_arrow_head_is_pointed,
		"bow_loaded_arrow_visible": _preview_bow_loaded_arrow != null and _preview_bow_loaded_arrow.visible,
		"bow_pulled_string_visible": _preview_bow_string_front != null and _preview_bow_string_front.visible and _preview_bow_string_rear != null and _preview_bow_string_rear.visible,
		"bow_static_string_visible": _preview_bow_static_string != null and _preview_bow_static_string.visible,
		"bow_shot_count": _preview_bow_shot_count,
		"bow_active_projectile_count": _preview_arrow_projectiles.size(),
		"bow_projectile_uses_arc": PREVIEW_ARROW_GRAVITY > 0.0 and PREVIEW_ARROW_LIFT_SPEED > 0.0,
		"bow_projectile_damage_authority": "combat_system_on_confirmed_hit",
		"crossbow_visible": crossbow != null and crossbow.visible,
		"crossbow_parent": str(crossbow.get_parent().name) if crossbow != null and crossbow.get_parent() != null else "",
		"crossbow_mesh_count": crossbow.find_children("*", "MeshInstance3D", true, false).size() if crossbow != null else 0,
		"crossbow_forward_dot": crossbow_forward_dot,
		"crossbow_top_up_dot": crossbow_top_up_dot,
		"crossbow_grip_palm_distance": crossbow_grip_palm_distance,
		"crossbow_grip_right_hand_distance": crossbow_grip_right_hand_distance,
		"crossbow_down_offset": PREVIEW_CROSSBOW_ATTACK_DOWN_OFFSET if _preview_crossbow_attack_active else PREVIEW_CROSSBOW_IDLE_DOWN_OFFSET,
		"crossbow_idle_down_offset": PREVIEW_CROSSBOW_IDLE_DOWN_OFFSET,
		"crossbow_attack_down_offset": PREVIEW_CROSSBOW_ATTACK_DOWN_OFFSET,
		"crossbow_hand_inward_offset": PREVIEW_CROSSBOW_HAND_INWARD_OFFSET,
		"crossbow_centerline_offset": PREVIEW_CROSSBOW_CENTERLINE_OFFSET,
		"mounted_crossbow_centerline_extra_offset": MOUNTED_CROSSBOW_CENTERLINE_EXTRA_OFFSET,
		"crossbow_attack_active": _preview_crossbow_attack_active,
		"crossbow_attack_phase": _preview_crossbow_attack_phase,
		"crossbow_loaded_bolt_visible": _preview_crossbow_loaded_bolt != null and _preview_crossbow_loaded_bolt.visible,
		"crossbow_string_nock_y": _preview_crossbow_string_nock_y,
		"crossbow_support_hand_stock_distance": crossbow_support_hand_stock_distance,
		"crossbow_side_offset": crossbow_side_offset,
		"crossbow_shot_count": _preview_crossbow_shot_count,
		"crossbow_active_projectile_count": crossbow_active_projectile_count,
		"crossbow_projectile_damage_authority": "combat_system_on_confirmed_hit",
		"formal_projectile_authority": _formal_projectile_authority,
		"medical_satchel_parent": str(medical_satchel.get_parent().name) if medical_satchel != null and medical_satchel.get_parent() != null else "",
		"medical_satchel_visible": medical_satchel != null and medical_satchel.visible,
		"medical_book_parent": str(medical_book.get_parent().name) if medical_book != null and medical_book.get_parent() != null else "",
		"medical_book_visible": medical_book != null and medical_book.visible,
		"medical_book_mesh_count": medical_book.find_children("*", "MeshInstance3D", true, false).size() if medical_book != null else 0,
		"medical_book_cross_mark_count": medical_book.find_children("MedicalCrossMark*", "MeshInstance3D", true, false).size() if medical_book != null else 0,
		"medical_bandage_parent": str(medical_bandage.get_parent().name) if medical_bandage != null and medical_bandage.get_parent() != null else "",
		"medical_bandage_visible": medical_bandage != null and medical_bandage.visible,
		"engineer_goggles_parent": str(engineer_goggles.get_parent().name) if engineer_goggles != null and engineer_goggles.get_parent() != null else "",
		"engineer_goggles_visible": engineer_goggles != null and engineer_goggles.visible,
		"engineer_goggles_mode": _engineer_goggles_mode,
		"engineer_goggles_target_model_position": ENGINEER_GOGGLES_WORN_MODEL_POSITION if _engineer_goggles_mode == "worn" else ENGINEER_GOGGLES_FOREHEAD_MODEL_POSITION,
		"engineer_tool_belt_parent": str(engineer_tool_belt.get_parent().name) if engineer_tool_belt != null and engineer_tool_belt.get_parent() != null else "",
		"engineer_tool_belt_visible": engineer_tool_belt != null and engineer_tool_belt.visible,
		"engineer_tool_pouch_left_position": (engineer_tool_belt.find_child("ToolPouchLeft", true, false) as Node3D).position if engineer_tool_belt != null and engineer_tool_belt.find_child("ToolPouchLeft", true, false) != null else Vector3.ZERO,
		"engineer_tool_pouch_right_position": (engineer_tool_belt.find_child("ToolPouchRight", true, false) as Node3D).position if engineer_tool_belt != null and engineer_tool_belt.find_child("ToolPouchRight", true, false) != null else Vector3.ZERO,
		"engineer_folding_rule_parent": str(engineer_tool_belt.find_child("FoldingRule", true, false).get_parent().name) if engineer_tool_belt != null and engineer_tool_belt.find_child("FoldingRule", true, false) != null else "",
		"engineer_folding_rule_local_position": (engineer_tool_belt.find_child("FoldingRule", true, false) as Node3D).position if engineer_tool_belt != null and engineer_tool_belt.find_child("FoldingRule", true, false) != null else Vector3.ZERO,
		"engineer_wood_wedge_parent": str(engineer_tool_belt.find_child("WoodWedge", true, false).get_parent().name) if engineer_tool_belt != null and engineer_tool_belt.find_child("WoodWedge", true, false) != null else "",
		"engineer_wood_wedge_local_position": (engineer_tool_belt.find_child("WoodWedge", true, false) as Node3D).position if engineer_tool_belt != null and engineer_tool_belt.find_child("WoodWedge", true, false) != null else Vector3.ZERO,
		"engineer_wrench_parent": str(engineer_wrench.get_parent().name) if engineer_wrench != null and engineer_wrench.get_parent() != null else "",
		"engineer_wrench_visible": engineer_wrench != null and engineer_wrench.visible,
		"engineer_wrench_grip_source_local_position": ENGINEER_WRENCH_GRIP_SOURCE_LOCAL_POSITION,
		"engineer_wrench_grip_hand_distance": engineer_wrench_grip_hand_distance,
		"engineer_wrench_forward_dot": engineer_wrench_forward_dot,
		"engineer_wrench_down_dot": engineer_wrench_down_dot,
		"authority_main_weapon_id": _authority_main_weapon_id,
		"debug_equipment_preview_active": _debug_equipment_preview_active,
		"debug_preview_main_weapon_id": _debug_preview_main_weapon_id,
		"debug_preview_combat_visible": _debug_preview_combat_visible,
		"sword_visible": sword != null and sword.visible,
		"shield_visible": shield != null and shield.visible,
		"sword_parent": str(sword.get_parent().name) if sword != null and sword.get_parent() != null else "",
		"shield_parent": str(shield.get_parent().name) if shield != null and shield.get_parent() != null else "",
		"sword_local_transform": sword.transform if sword != null else Transform3D.IDENTITY,
		"sword_local_position": sword.position if sword != null else Vector3.ZERO,
		"sword_local_rotation_degrees": sword.rotation_degrees if sword != null else Vector3.ZERO,
		"sword_local_scale": sword.scale if sword != null else Vector3.ZERO,
		"foot_sword_attack_attachment_valid": _foot_sword_attack_attachment_valid,
		"foot_sword_attack_attachment_transform": _foot_sword_attack_attachment_transform,
		"mounted_sword_attack_attachment_valid": _mounted_sword_attack_attachment_valid,
		"sword_global_position": sword.global_position if sword != null else Vector3.ZERO,
		"right_hand_global_position": right_hand.global_position if right_hand != null else Vector3.ZERO,
		"sword_grip_hand_distance": sword_grip_hand_distance,
		"sword_grip_global_position": sword_grip_global_position,
		"right_lower_arm_global_position": right_lower_arm_global_position,
		"foot_sword_grip_down_offset": FOOT_SWORD_GRIP_DOWN_OFFSET,
		"foot_sword_grip_inward_offset": FOOT_SWORD_GRIP_INWARD_OFFSET,
		"mounted_sword_grip_palm_distance": mounted_sword_grip_palm_distance,
		"mounted_sword_forward_lean_degrees": MOUNTED_SWORD_FORWARD_LEAN_DEGREES,
		"sword_tip_hand_distance": sword_tip_hand_distance,
		"sword_forward_dot": sword_forward_dot,
		"sword_blade_up_dot": sword_blade_up_dot,
		"sword_tip_above_grip": sword_tip_above_grip,
		"sword_sagittal_side_dot": sword_sagittal_side_dot,
		"mounted_upper_body_forward_offset": mounted_upper_body_forward_offset,
		"mounted_torso_facing_dot": mounted_torso_facing_dot,
		"shield_local_position": shield.position if shield != null else Vector3.ZERO,
		"shield_local_rotation_degrees": shield.rotation_degrees if shield != null else Vector3.ZERO,
		"shield_local_scale": shield.scale if shield != null else Vector3.ZERO,
		"shield_hand_distance": shield_hand_distance,
		"shield_back_hand_distance": shield_back_hand_distance,
		"shield_back_hand_clearance": shield_back_hand_clearance,
		"shield_back_hand_vertical_offset": shield_back_hand_vertical_offset,
		"shield_face_normal": shield_face_normal,
		"shield_up_axis": shield_up_axis,
		"shield_face_forward_dot": shield_face_forward_dot,
		"shield_face_side_dot": absf(shield_face_normal.dot(_visual_root.global_basis.x.normalized())) if _visual_root != null else -1.0,
		"spatial_attachment_pose": _spatial_attachment_pose,
		"logical_moving": _is_moving,
		"movement_speed": _movement_speed,
		"locomotion_state": _locomotion_state,
		"locomotion_reference_speed": _locomotion_reference_speed,
		"locomotion_animation_speed_scale": _animation_player.speed_scale if _animation_player != null and _desired_state in ["walk", "run", "mounted_walk"] else 0.0,
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
		"formal_combat_mount_root_offset": _get_formal_combat_mount_root_offset(),
		"mounted_seated_pose_offset": _get_mounted_seated_pose_offset(Vector3(SEATED_POSE_OFFSET.x, seated_pose_offset_y, SEATED_POSE_OFFSET.z)),
		"visual_root_local_position": _visual_root.position if _visual_root != null else Vector3.ZERO,
		"visual_root_local_rotation_degrees": _visual_root.rotation_degrees if _visual_root != null else Vector3.ZERO,
		"ragdoll_placeholder_ready": _physical_bone_simulator != null,
		"blood_vfx_ready": _blood_particles != null,
		"blood_vfx_emitting": _blood_particles != null and _blood_particles.emitting,
		"damage_feedback_count": _damage_feedback_count,
		"fall_feedback_mode": "mounted_arc_to_death_a" if _mounted_fall_active or _mounted_fall_recovering else "animated_fall_with_physics_impulse",
		"mounted_fall_active": _mounted_fall_active,
		"mounted_fall_recovering": _mounted_fall_recovering,
		"mounted_fall_phase": ("airborne" if _mounted_fall_elapsed < MOUNTED_FALL_AIRBORNE_SECONDS else "landed") if _mounted_fall_active else ("recovering" if _mounted_fall_recovering else "inactive"),
		"mounted_fall_elapsed": _mounted_fall_elapsed,
		"mounted_fall_duration": MOUNTED_FALL_AIRBORNE_SECONDS,
		"mounted_fall_progress": clampf(_mounted_fall_elapsed / MOUNTED_FALL_AIRBORNE_SECONDS, 0.0, 1.0),
		"mounted_fall_side": _mounted_fall_side,
		"mounted_fall_landing_offset": _mounted_fall_landing_offset,
		"mounted_fall_trigger_count": _mounted_fall_trigger_count,
		"retarget_mode": "Godot_4_6_RealtimeRetarget_profile_humanoid",
		"authority_role": "presentation_only",
	}
