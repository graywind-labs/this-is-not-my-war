extends Node


signal npc_temporary_presentation_event_emitted(event: Dictionary)

const NPC_PROFILES_FILE := "npc_profiles.json"
const NPC_INITIAL_LONG_MEMORY_FILE := "npc_initial_long_memory.json"
const NPC_INTERACTION_PRESENTATION_FILE := "npc_interaction_presentation.json"
const NPC_SCENE_PATH := "res://scenes/npc/NPC.tscn"
const NPC_ROOT_PATH := "/root/Main/WorldRoot/Station/NPCs"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const STATION_LAYOUT_CONTROLLER_PATH := "/root/Main/Presentation/StationLayoutController"
const PLAZA_LOCATION_ID := "plaza"
const FIRST_SPATIAL_INTERIOR_BUILDING_ID := "blacksmith"
const FIRST_FORMAL_NAVIGATION_PILOT_NPC_ID := "blacksmith_01"
const FIRST_FORMAL_NAVIGATION_PILOT_WORKSTATION_TYPE := "forge"
const CLINIC_FORMAL_NAVIGATION_PILOT_NPC_ID := "doctor_01"
const CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID := "clinic"
const CLINIC_DOCTOR_WORKSTATION_TYPE := "clinic_doctor_station"
const CLINIC_PATIENT_WORKSTATION_TYPE := "clinic_patient_bed"
const CLINIC_TREATMENT_DOCTOR_BODY_RADIUS := 0.35
const CLINIC_TREATMENT_BED_CLEARANCE := 0.08
const CLINIC_TREATMENT_ANCHOR_LATERAL_OFFSET := 0.35
const DORMITORY_FORMAL_NAVIGATION_PILOT_NPC_ID := "veteran_deputy_01"
const DORMITORY_FORMAL_NAVIGATION_PILOT_BUILDING_ID := "dormitory"
const DORMITORY_BED_WORKSTATION_TYPE := "dormitory_bed"
const DINING_FORMAL_NAVIGATION_PILOT_NPC_ID := "cook_01"
const DINING_FORMAL_NAVIGATION_PILOT_BUILDING_ID := "dining_hall"
const DINING_SEAT_WORKSTATION_TYPE := "dining_seat"
const CHAPEL_FORMAL_NAVIGATION_PILOT_NPC_ID := "priest_01"
const CHAPEL_FORMAL_NAVIGATION_PILOT_BUILDING_ID := "chapel"
const CHAPEL_PRAYER_SEAT_WORKSTATION_TYPE := "chapel_prayer_seat"
const STABLE_FORMAL_NAVIGATION_PILOT_NPC_ID := "stableman_01"
const STABLE_FORMAL_NAVIGATION_PILOT_BUILDING_ID := "stable"
const STABLE_CARE_WORKSTATION_TYPE := "horse_care"
const FORMAL_NAVIGATION_PILOT_SPECS := {
	"glen": {
		"npc_id": FIRST_FORMAL_NAVIGATION_PILOT_NPC_ID,
		"building_id": FIRST_SPATIAL_INTERIOR_BUILDING_ID,
		"workstation_type": FIRST_FORMAL_NAVIGATION_PILOT_WORKSTATION_TYPE
	},
	"clinic_doctor": {
		"npc_id": CLINIC_FORMAL_NAVIGATION_PILOT_NPC_ID,
		"building_id": CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID,
		"workstation_type": CLINIC_DOCTOR_WORKSTATION_TYPE
	},
	"clinic_bed": {
		"npc_id": CLINIC_FORMAL_NAVIGATION_PILOT_NPC_ID,
		"building_id": CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID,
		"workstation_type": CLINIC_PATIENT_WORKSTATION_TYPE
	},
	"dormitory_bed": {
		"npc_id": DORMITORY_FORMAL_NAVIGATION_PILOT_NPC_ID,
		"building_id": DORMITORY_FORMAL_NAVIGATION_PILOT_BUILDING_ID,
		"workstation_type": DORMITORY_BED_WORKSTATION_TYPE,
		"expected_workstation_id": "dormitory_bed_01"
	},
	"dining_seat": {
		"npc_id": DINING_FORMAL_NAVIGATION_PILOT_NPC_ID,
		"building_id": DINING_FORMAL_NAVIGATION_PILOT_BUILDING_ID,
		"workstation_type": DINING_SEAT_WORKSTATION_TYPE
	},
	"chapel_prayer_seat": {
		"npc_id": CHAPEL_FORMAL_NAVIGATION_PILOT_NPC_ID,
		"building_id": CHAPEL_FORMAL_NAVIGATION_PILOT_BUILDING_ID,
		"workstation_type": CHAPEL_PRAYER_SEAT_WORKSTATION_TYPE
	},
	"stable_care": {
		"npc_id": STABLE_FORMAL_NAVIGATION_PILOT_NPC_ID,
		"building_id": STABLE_FORMAL_NAVIGATION_PILOT_BUILDING_ID,
		"workstation_type": STABLE_CARE_WORKSTATION_TYPE
	}
}
const PLAYER_ACTOR_ID := "guard_officer"
const SYSTEM_ACTOR_ID := "system"
const MONEY_RESOURCE_ID := "money"
const WINE_RESOURCE_ID := "wine"
const NPC_OWNED_RESOURCE_IDS: Array[String] = [MONEY_RESOURCE_ID, WINE_RESOURCE_ID]
const PICK_RAY_LENGTH := 1000.0
const PROFESSIONAL_SKILLS: Array[String] = ["养马", "厨艺", "耕种", "打铁", "教练", "酿酒", "医术", "工程"]
const WEAPON_SKILLS: Array[String] = ["剑盾", "长杆", "弓", "弩", "骑术"]
const ATTRIBUTE_NAMES: Array[String] = ["strength", "intelligence"]
const SPECIALTY_THRESHOLD := 25
const SKILL_POINT_EXPERIENCE_THRESHOLD := 10
const ATTRIBUTE_MIN_VALUE := 0
const ATTRIBUTE_MAX_VALUE := 10
const UNCONSCIOUS_NATURAL_RECOVERY_HP_PER_HOUR := 2.0
const UNCONSCIOUS_HEALING_BASE_HP_PER_HOUR := 2.0
const UNCONSCIOUS_HEALING_MAX_BONUS_HP_PER_HOUR := 10.0
const UNCONSCIOUS_HEALING_SKILL_THRESHOLD := 20.0
const REVIVE_HP_RATIO := 0.3
const PROACTIVE_TALK_DEFAULT_DURATION_SECONDS := 3600.0
const PROACTIVE_TALK_GESTURE_DEFAULT_INTERVAL_REAL_SECONDS := 5.0
const PROACTIVE_TALK_GESTURE_MIN_INTERVAL_REAL_SECONDS := 0.1
const LLM_ACTIVITY_NONE := ""
const LLM_ACTIVITY_DIALOGUE := "dialogue"
const LLM_ACTIVITY_PLAN := "plan"
const LLM_ACTIVITY_FIRST_SLEEP_SUMMARY := "first_sleep_summary"
const LLM_ACTIVITY_BATTLE_JUDGEMENT := "battle_judgement"
const BEHAVIOR_MODE_WORK := "work"
const BEHAVIOR_MODE_RALLY := "rally"
const BEHAVIOR_MODE_COMBAT := "combat"
const BEHAVIOR_MODE_AVOID_COMBAT := "avoid_combat"
const BEHAVIOR_MODE_UNCONSCIOUS := "unconscious"
const BEHAVIOR_MODE_ESCAPED := "escaped"
const BEHAVIOR_MODE_LABELS := {
	"work": "工作模式",
	"rally": "集结模式",
	"combat": "战斗模式",
	"avoid_combat": "避战模式",
	"unconscious": "昏迷",
	"escaped": "逃离"
}
const VALID_BEHAVIOR_MODES: Array[String] = [
	BEHAVIOR_MODE_WORK,
	BEHAVIOR_MODE_RALLY,
	BEHAVIOR_MODE_COMBAT,
	BEHAVIOR_MODE_AVOID_COMBAT,
	BEHAVIOR_MODE_UNCONSCIOUS,
	BEHAVIOR_MODE_ESCAPED
]

const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-8.0, 0.0, 2.5),
	Vector3(-4.8, 0.0, 3.3),
	Vector3(-1.6, 0.0, 2.7),
	Vector3(1.6, 0.0, 3.2),
	Vector3(4.8, 0.0, 2.4),
	Vector3(8.0, 0.0, 3.0),
	Vector3(-3.2, 0.0, -1.2),
	Vector3(3.2, 0.0, -1.2)
]

var _profiles: Dictionary = {}
var _npc_order: Array[String] = []
var _npc_nodes: Dictionary = {}
var _movement_arrival_contexts: Dictionary = {}
var _building_interior_routes: Dictionary = {}
var _formal_navigation_pilots: Dictionary = {}
var _formal_workstation_action_sessions: Dictionary = {}
var _formal_workstation_action_session_sequence := 0
var _formal_dialogue_approach_sessions: Dictionary = {}
var _formal_healing_target_projections: Dictionary = {}
var _formal_combat_world_npcs: Dictionary = {}
var _default_formal_world_npcs: Dictionary = {}
var _default_formal_world_resume_positions: Dictionary = {}
var _building_eviction_guards: Dictionary = {}
var _selected_npc_id: String = ""
var _unconscious_recovery_remainders: Dictionary = {}
var _last_plan_reevaluation_request: Dictionary = {}
var _plan_reevaluation_requests_by_npc: Dictionary = {}
var _temporary_presentation_event_sequence := 0
var _temporary_presentation_event_history: Array[Dictionary] = []
var _proactive_talk_presentation_sessions: Dictionary = {}
var _proactive_talk_presentation_session_sequence := 0
var _proactive_talk_gesture_interval_real_seconds := PROACTIVE_TALK_GESTURE_DEFAULT_INTERVAL_REAL_SECONDS


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if not event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
			event_bus.logical_time_tick.connect(_on_logical_time_tick)
		if event_bus.has_signal("building_state_changed") and not event_bus.building_state_changed.is_connected(_on_building_state_changed):
			event_bus.building_state_changed.connect(_on_building_state_changed)


func _process(delta: float) -> void:
	_advance_proactive_talk_presentations(delta)


func _exit_tree() -> void:
	_proactive_talk_presentation_sessions.clear()


func initialize() -> void:
	_clear_spawned_npcs()
	_profiles.clear()
	_npc_order.clear()
	_npc_nodes.clear()
	_movement_arrival_contexts.clear()
	_building_interior_routes.clear()
	_formal_navigation_pilots.clear()
	_formal_workstation_action_sessions.clear()
	_formal_workstation_action_session_sequence = 0
	_formal_dialogue_approach_sessions.clear()
	_formal_healing_target_projections.clear()
	_formal_combat_world_npcs.clear()
	_default_formal_world_npcs.clear()
	_default_formal_world_resume_positions.clear()
	_building_eviction_guards.clear()
	_unconscious_recovery_remainders.clear()
	_last_plan_reevaluation_request.clear()
	_plan_reevaluation_requests_by_npc.clear()
	_temporary_presentation_event_sequence = 0
	_temporary_presentation_event_history.clear()
	_proactive_talk_presentation_sessions.clear()
	_proactive_talk_presentation_session_sequence = 0
	_proactive_talk_gesture_interval_real_seconds = PROACTIVE_TALK_GESTURE_DEFAULT_INTERVAL_REAL_SECONDS
	_selected_npc_id = ""

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("NPCSystem requires ConfigLoader autoload.")
		return
	_load_interaction_presentation_config(config_loader)

	var loaded_profiles: Variant = config_loader.load_data_file(NPC_PROFILES_FILE, [])
	if not loaded_profiles is Array:
		push_error("NPC profiles must be a JSON array: %s" % NPC_PROFILES_FILE)
		return
	var loaded_initial_long_memory: Variant = config_loader.load_data_file(NPC_INITIAL_LONG_MEMORY_FILE, {})
	if not loaded_initial_long_memory is Dictionary:
		push_error("NPC initial long memory must be a JSON object: %s" % NPC_INITIAL_LONG_MEMORY_FILE)
		return
	var initial_memory_validation := _validate_initial_long_memory_dataset(
		loaded_profiles,
		loaded_initial_long_memory
	)
	if not bool(initial_memory_validation.get("ok", false)):
		push_error("Invalid NPC initial long memory: %s" % str(initial_memory_validation.get("message", "")))
		return

	var npc_scene := load(NPC_SCENE_PATH) as PackedScene
	if npc_scene == null:
		push_error("NPC scene not found or invalid: %s" % NPC_SCENE_PATH)
		return

	var npc_root := get_node_or_null(NPC_ROOT_PATH)
	if npc_root == null:
		push_error("NPC root not found: %s" % NPC_ROOT_PATH)
		return

	for raw_profile in loaded_profiles:
		if not raw_profile is Dictionary:
			push_error("Skipped invalid NPC profile because it is not a dictionary.")
			continue

		var profile: Dictionary = (raw_profile as Dictionary).duplicate(true)
		var npc_id := str(profile.get("id", ""))
		if npc_id.is_empty():
			push_error("Skipped NPC profile with empty id.")
			continue
		if _profiles.has(npc_id):
			push_error("Skipped duplicate NPC id: %s" % npc_id)
			continue

		if not _apply_initial_long_memory(profile, npc_id, loaded_initial_long_memory):
			push_error("Failed to apply validated initial long memory for NPC: %s" % npc_id)
			return
		profile["skills"] = normalize_skills(profile.get("skills", {}))
		profile["current_order"] = _normalize_current_order(profile.get("current_order", {}))
		var npc_node := npc_scene.instantiate()
		npc_root.add_child(npc_node)
		npc_node.global_position = _get_spawn_position(_npc_order.size())
		if npc_node.has_method("setup"):
			npc_node.setup(profile)
		if npc_node.has_signal("movement_arrived"):
			npc_node.movement_arrived.connect(_on_npc_movement_arrived)
		if npc_node.has_signal("movement_request_failed"):
			npc_node.movement_request_failed.connect(_on_npc_movement_request_failed)

		_profiles[npc_id] = profile.duplicate(true)
		_ensure_runtime_state_defaults(npc_id)
		_npc_order.append(npc_id)
		_npc_nodes[npc_id] = npc_node.get_path()
	call_deferred("_begin_default_formal_world_if_configured")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var interaction := _pick_npc_interaction_at_screen_position(event.position)
		var clicked_npc_id := str(interaction.get("npc_id", ""))
		if not clicked_npc_id.is_empty() and _is_npc_hidden_by_opaque_building(clicked_npc_id):
			return
		if str(interaction.get("kind", "")) == "autonomous_dialogue_bubble":
			var event_bus := get_node_or_null("/root/EventBus")
			if event_bus != null and event_bus.has_signal("npc_dialogue_bubble_clicked"):
				event_bus.npc_dialogue_bubble_clicked.emit(
					str(interaction.get("npc_id", "")),
					str(interaction.get("dialogue_id", ""))
				)
				get_viewport().set_input_as_handled()
			return
		var npc_id := str(interaction.get("npc_id", ""))
		if not npc_id.is_empty():
			_select_npc(npc_id)
			get_viewport().set_input_as_handled()


func get_npc(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Unknown NPC id: %s" % npc_id)
		return {}
	return _profiles[npc_id].duplicate(true)


func get_npc_state(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Unknown NPC id: %s" % npc_id)
		return {}
	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	return states.duplicate(true)


func get_npc_ids() -> Array[String]:
	return _npc_order.duplicate()


func get_npc_count() -> int:
	return _npc_order.size()


func get_npc_world_position(npc_id: String) -> Variant:
	if not _npc_nodes.has(npc_id):
		return null
	var npc_node := get_node_or_null(_npc_nodes[npc_id]) as Node3D
	if npc_node == null:
		return null
	return npc_node.global_position


func get_npc_locomotion_needs_snapshot(npc_id: String) -> Dictionary:
	if not _npc_nodes.has(npc_id):
		return {}
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("get_locomotion_needs_snapshot"):
		return {}
	return npc_node.get_locomotion_needs_snapshot()


func consume_npc_unmounted_actual_run_seconds(npc_id: String) -> float:
	if not _npc_nodes.has(npc_id):
		return 0.0
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("consume_unmounted_actual_run_seconds"):
		return 0.0
	return maxf(0.0, float(npc_node.consume_unmounted_actual_run_seconds()))


func displace_npcs_from_world_obstacle(
	center: Vector3,
	obstacle_radius: float,
	source_id: String,
	clearance_margin: float = 0.12
) -> Dictionary:
	var checked_obstacle_radius := maxf(0.0, obstacle_radius)
	var checked_margin := maxf(0.02, clearance_margin)
	var affected: Array[Dictionary] = []
	var occupied: Array[Dictionary] = []
	for npc_id in _npc_order:
		var state := get_npc_state(npc_id)
		if bool(state.get("escaped", false)) or str(state.get("current_location", "")) == "outside_station":
			continue
		var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node == null or not npc_node.visible:
			continue
		var body_radius := 0.35
		if npc_node.has_method("debug_get_motion_snapshot"):
			body_radius = maxf(
				0.05,
				float((npc_node.debug_get_motion_snapshot() as Dictionary).get("body_radius", body_radius))
			)
		if bool(state.get("combat_mounted", false)):
			body_radius = maxf(body_radius, 0.65)
		var planar_distance := Vector2(
			npc_node.global_position.x - center.x,
			npc_node.global_position.z - center.z
		).length()
		var entry := {
			"npc_id": npc_id,
			"node": npc_node,
			"position": npc_node.global_position,
			"body_radius": body_radius,
		}
		if planar_distance < checked_obstacle_radius + body_radius + checked_margin:
			affected.append(entry)
		else:
			occupied.append(entry)

	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var navigation_map := RID()
	if controller != null and controller.has_method("get_production_navigation_map_rid"):
		navigation_map = controller.get_production_navigation_map_rid()
	var displaced: Array[Dictionary] = []
	var failed: Array[Dictionary] = []
	for affected_index in range(affected.size()):
		var entry: Dictionary = affected[affected_index]
		var npc_id := str(entry.get("npc_id", ""))
		var npc_node := entry.get("node", null) as Node3D
		var origin: Vector3 = entry.get("position", center)
		var body_radius := float(entry.get("body_radius", 0.35))
		if npc_node == null:
			continue
		var outward := Vector2(origin.x - center.x, origin.z - center.z)
		if outward.length_squared() <= 0.0001:
			var deterministic_angle := TAU * float(abs(npc_id.hash()) % 360) / 360.0
			outward = Vector2(cos(deterministic_angle), sin(deterministic_angle))
		else:
			outward = outward.normalized()
		var destination: Variant = _find_external_obstacle_displacement_position(
			center,
			origin.y,
			outward,
			checked_obstacle_radius + body_radius + checked_margin,
			body_radius,
			occupied,
			navigation_map
		)
		if destination == null:
			failed.append({"npc_id": npc_id, "reason": "safe_navigation_position_unavailable"})
			continue
		var displacement_result: Dictionary = (
			npc_node.apply_external_displacement(destination, source_id)
			if npc_node.has_method("apply_external_displacement")
			else {}
		)
		if displacement_result.is_empty():
			npc_node.global_position = destination
			displacement_result = {"ok": true, "position": destination, "motion_preserved": false}
		displacement_result["npc_id"] = npc_id
		displacement_result["body_radius"] = body_radius
		displaced.append(displacement_result)
		occupied.append({
			"npc_id": npc_id,
			"position": destination,
			"body_radius": body_radius,
		})
	return {
		"ok": failed.is_empty(),
		"source_id": source_id,
		"center": center,
		"obstacle_radius": checked_obstacle_radius,
		"affected_count": affected.size(),
		"displaced_count": displaced.size(),
		"displaced": displaced,
		"failed": failed,
	}


func _find_external_obstacle_displacement_position(
	center: Vector3,
	target_y: float,
	outward: Vector2,
	minimum_center_distance: float,
	body_radius: float,
	occupied: Array[Dictionary],
	navigation_map: RID
) -> Variant:
	var base_angle := atan2(outward.y, outward.x)
	var angular_step := deg_to_rad(15.0)
	for ring_index in range(6):
		var ring_distance := minimum_center_distance + float(ring_index) * 0.35
		for candidate_index in range(25):
			var signed_step := 0
			if candidate_index > 0:
				signed_step = int((candidate_index + 1) / 2)
				if candidate_index % 2 == 0:
					signed_step = -signed_step
			var angle := base_angle + float(signed_step) * angular_step
			var desired := Vector3(
				center.x + cos(angle) * ring_distance,
				target_y,
				center.z + sin(angle) * ring_distance
			)
			var candidate := desired
			if navigation_map.is_valid():
				candidate = NavigationServer3D.map_get_closest_point(navigation_map, desired)
				candidate.y = target_y
				if Vector2(candidate.x - desired.x, candidate.z - desired.z).length() > 1.25:
					continue
			if Vector2(candidate.x - center.x, candidate.z - center.z).length() < minimum_center_distance - 0.01:
				continue
			var overlaps_actor := false
			for raw_other in occupied:
				var other: Dictionary = raw_other
				var other_position: Vector3 = other.get("position", Vector3.ZERO)
				var separation := body_radius + float(other.get("body_radius", 0.35)) + 0.08
				if Vector2(candidate.x - other_position.x, candidate.z - other_position.z).length() < separation:
					overlaps_actor = true
					break
			if not overlaps_actor:
				return candidate
	return null


func get_npc_combat_projectile_release_transform(npc_id: String, weapon_type: String) -> Variant:
	if not _npc_nodes.has(npc_id):
		return null
	var npc_node := get_node_or_null(_npc_nodes[npc_id]) as Node3D
	if npc_node == null:
		return null
	if npc_node.has_method("get_combat_projectile_release_transform"):
		return npc_node.get_combat_projectile_release_transform(weapon_type)
	return Transform3D(npc_node.global_basis, npc_node.global_position + Vector3.UP * 1.15)


func get_npc_combat_projectile_release_snapshot(npc_id: String, weapon_type: String) -> Dictionary:
	if not _npc_nodes.has(npc_id):
		return {"ready": false, "reason": "npc_actor_unavailable", "npc_id": npc_id, "weapon_type": weapon_type}
	var npc_node := get_node_or_null(_npc_nodes[npc_id]) as Node3D
	if npc_node == null or not npc_node.has_method("get_combat_projectile_release_snapshot"):
		return {"ready": false, "reason": "npc_projectile_origin_unavailable", "npc_id": npc_id, "weapon_type": weapon_type}
	return npc_node.get_combat_projectile_release_snapshot(weapon_type)


func get_npc_combat_melee_contact_segment(npc_id: String, weapon_type: String) -> Dictionary:
	if not _npc_nodes.has(npc_id):
		return {}
	var npc_node := get_node_or_null(_npc_nodes[npc_id]) as Node3D
	if npc_node != null and npc_node.has_method("get_combat_melee_contact_segment"):
		return npc_node.get_combat_melee_contact_segment(weapon_type)
	return {}


func get_npc_combat_collision_rid(npc_id: String) -> RID:
	if not _npc_nodes.has(npc_id):
		return RID()
	var npc_body := get_node_or_null(_npc_nodes[npc_id]) as CollisionObject3D
	return npc_body.get_rid() if npc_body != null else RID()


func set_npc_facing_direction(npc_id: String, direction: Vector3) -> bool:
	if not _npc_nodes.has(npc_id):
		return false
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("set_facing_direction"):
		return false
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return false
	npc_node.set_facing_direction(flat_direction.normalized())
	return true


func play_formal_dialogue_presentation_event(
	dialogue_id: String,
	npc_id: String,
	event_kind: String
) -> Dictionary:
	if dialogue_id.is_empty() or npc_id.is_empty():
		return {"ok": false, "reason": "formal_dialogue_presentation_identity_missing"}
	if not event_kind in ["invitation_sent", "invitation_accepted"]:
		return {"ok": false, "reason": "unsupported_formal_dialogue_presentation_event"}
	var speaker_npc_id := _find_formal_dialogue_speaker_by_dialogue_id(dialogue_id)
	if speaker_npc_id.is_empty():
		# Direct test/debug dialogue sessions without the production spatial route do
		# not own a world presentation event.
		return {"ok": true, "active": false, "reason": "formal_dialogue_spatial_session_missing"}
	var session: Dictionary = _formal_dialogue_approach_sessions[speaker_npc_id]
	var target_npc_id := str(session.get("target_npc_id", ""))
	var expected_npc_id := speaker_npc_id if event_kind == "invitation_sent" else target_npc_id
	if npc_id != expected_npc_id:
		return {"ok": false, "reason": "formal_dialogue_presentation_role_mismatch"}
	if not _profiles.has(npc_id) or not _npc_nodes.has(npc_id):
		return {"ok": false, "reason": "npc_actor_unavailable", "npc_id": npc_id}
	var state := get_npc_state(npc_id)
	if bool(state.get("unconscious", false)) or bool(state.get("escaped", false)):
		return {"ok": false, "reason": "npc_presentation_unavailable", "npc_id": npc_id}
	if event_kind == "invitation_sent":
		var speaker_position: Variant = get_npc_world_position(speaker_npc_id)
		var target_position: Variant = get_npc_world_position(target_npc_id)
		if not speaker_position is Vector3 or not target_position is Vector3:
			return {"ok": false, "reason": "formal_dialogue_world_position_missing"}
		var horizontal_distance := Vector2(
			speaker_position.x - target_position.x,
			speaker_position.z - target_position.z
		).length()
		if horizontal_distance < 0.85 or horizontal_distance > 1.70:
			return {
				"ok": false,
				"reason": "formal_dialogue_presentation_not_in_range",
				"horizontal_distance": horizontal_distance
			}
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("play_temporary_presentation_action"):
		return {"ok": false, "reason": "npc_presentation_bridge_missing", "npc_id": npc_id}
	var event_id := "%s:%s:%s" % [dialogue_id, event_kind, npc_id]
	var presentation_result: Dictionary = npc_node.play_temporary_presentation_action("talk_gesture", event_id)
	if not bool(presentation_result.get("ok", false)):
		return presentation_result
	var duplicate := bool(presentation_result.get("duplicate", false))
	if not duplicate:
		_temporary_presentation_event_sequence += 1
	var event := {
		"sequence": _temporary_presentation_event_sequence,
		"event_id": event_id,
		"dialogue_id": dialogue_id,
		"event_kind": event_kind,
		"npc_id": npc_id,
		"speaker_npc_id": speaker_npc_id,
		"target_npc_id": target_npc_id,
		"presentation_action": "talk_gesture",
		"authority_action_at_emit": str(state.get("current_action", "idle")),
		"duplicate": duplicate,
		"duration_seconds": float(presentation_result.get("duration_seconds", 0.0))
	}
	if not duplicate:
		_temporary_presentation_event_history.append(event.duplicate(true))
		if _temporary_presentation_event_history.size() > 32:
			_temporary_presentation_event_history.pop_front()
		npc_temporary_presentation_event_emitted.emit(event.duplicate(true))
	return {"ok": true, "active": true, "event": event}


func get_temporary_presentation_event_snapshot() -> Dictionary:
	return {
		"sequence": _temporary_presentation_event_sequence,
		"events": _temporary_presentation_event_history.duplicate(true)
	}


func play_idle_portrait_talk_gesture(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id) or not _npc_nodes.has(npc_id):
		return {"ok": false, "reason": "npc_actor_unavailable", "npc_id": npc_id}
	var state := get_npc_state(npc_id)
	if bool(state.get("unconscious", false)):
		return {"ok": false, "reason": "npc_unconscious", "npc_id": npc_id}
	if bool(state.get("escaped", false)) or _is_npc_escaping_state(state):
		return {"ok": false, "reason": "npc_escaped_or_escaping", "npc_id": npc_id}
	if str(state.get("current_action", "idle")) != "idle":
		return {"ok": false, "reason": "npc_not_idle", "npc_id": npc_id}
	if not str(state.get("movement_target", "")).is_empty():
		return {"ok": false, "reason": "npc_moving", "npc_id": npc_id}
	if _get_current_behavior_mode(npc_id) != BEHAVIOR_MODE_WORK or not can_npc_act(npc_id):
		return {"ok": false, "reason": "npc_not_in_idle_work_mode", "npc_id": npc_id}
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("play_temporary_presentation_action"):
		return {"ok": false, "reason": "npc_presentation_bridge_missing", "npc_id": npc_id}
	var event_id := "portrait_idle:%s:%06d" % [npc_id, _temporary_presentation_event_sequence + 1]
	var presentation_result: Dictionary = npc_node.play_temporary_presentation_action("talk_gesture", event_id)
	if not bool(presentation_result.get("ok", false)):
		return presentation_result
	var event := {
		"event_id": event_id,
		"event_kind": "portrait_idle_talk_gesture",
		"npc_id": npc_id,
		"presentation_action": "talk_gesture",
		"authority_action_at_emit": str(state.get("current_action", "idle")),
		"source": "npc_panel_portrait"
	}
	return _record_temporary_presentation_event(event, presentation_result)


func play_damage_presentation_event(damage_result: Dictionary) -> Dictionary:
	if not bool(damage_result.get("ok", false)):
		return {"ok": false, "reason": "damage_result_invalid"}
	var npc_id := str(damage_result.get("npc_id", ""))
	var damage_event: Dictionary = (
		damage_result.get("damage_event", {})
		if damage_result.get("damage_event", {}) is Dictionary
		else {}
	)
	var damage_event_id := str(damage_event.get("event_id", damage_event.get("id", "")))
	if npc_id.is_empty() or damage_event_id.is_empty():
		return {"ok": false, "reason": "damage_presentation_identity_missing", "npc_id": npc_id}
	var event_id := "%s:hit_react:%s" % [damage_event_id, npc_id]
	var existing := _find_temporary_presentation_event(event_id)
	if not existing.is_empty():
		return {"ok": true, "active": true, "duplicate": true, "event": existing}
	var hp_before := int(damage_result.get("hp_before", 0))
	var hp_after := int(damage_result.get("hp_after", hp_before))
	var unconscious := bool(damage_result.get("unconscious", false))
	var event := {
		"event_id": event_id,
		"event_kind": "damage_hit_react",
		"npc_id": npc_id,
		"damage_event_id": damage_event_id,
		"presentation_action": "hit_react",
		"authority_action_at_emit": str(get_npc_state(npc_id).get("current_action", "idle")),
		"hp_before": hp_before,
		"hp_after": hp_after,
		"damage": int(damage_result.get("damage", 0)),
		"source_actor_id": str(damage_result.get("actor_id", "")),
		"suppressed_by_unconscious": unconscious,
		"suppressed_by_no_hp_change": hp_after >= hp_before
	}
	if unconscious or hp_after >= hp_before:
		return _record_temporary_presentation_event(event, {
			"ok": true,
			"duplicate": false,
			"duration_seconds": 0.0,
			"suppressed": true
		})
	if not _npc_nodes.has(npc_id):
		return {"ok": false, "reason": "npc_actor_unavailable", "npc_id": npc_id}
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("play_temporary_presentation_action"):
		return {"ok": false, "reason": "npc_presentation_bridge_missing", "npc_id": npc_id}
	var presentation_result: Dictionary = npc_node.play_temporary_presentation_action("hit_react", event_id)
	if not bool(presentation_result.get("ok", false)):
		return presentation_result
	return _record_temporary_presentation_event(event, presentation_result)


func _record_temporary_presentation_event(event: Dictionary, presentation_result: Dictionary) -> Dictionary:
	var duplicate := bool(presentation_result.get("duplicate", false))
	if not duplicate:
		_temporary_presentation_event_sequence += 1
	event["sequence"] = _temporary_presentation_event_sequence
	event["duplicate"] = duplicate
	event["duration_seconds"] = float(presentation_result.get("duration_seconds", 0.0))
	event["suppressed"] = bool(presentation_result.get("suppressed", false))
	if not duplicate:
		_temporary_presentation_event_history.append(event.duplicate(true))
		if _temporary_presentation_event_history.size() > 32:
			_temporary_presentation_event_history.pop_front()
		npc_temporary_presentation_event_emitted.emit(event.duplicate(true))
	return {"ok": true, "active": true, "duplicate": duplicate, "event": event}


func _find_temporary_presentation_event(event_id: String) -> Dictionary:
	for index in range(_temporary_presentation_event_history.size() - 1, -1, -1):
		var event: Dictionary = _temporary_presentation_event_history[index]
		if str(event.get("event_id", "")) == event_id:
			return event.duplicate(true)
	return {}


func get_proactive_talk_presentation_snapshot(npc_id: String = "") -> Variant:
	var clean_npc_id := npc_id.strip_edges()
	if not clean_npc_id.is_empty():
		if not _proactive_talk_presentation_sessions.has(clean_npc_id):
			return {}
		return (_proactive_talk_presentation_sessions[clean_npc_id] as Dictionary).duplicate(true)
	var sessions: Array[Dictionary] = []
	for raw_npc_id in _proactive_talk_presentation_sessions:
		var session: Dictionary = (_proactive_talk_presentation_sessions[raw_npc_id] as Dictionary).duplicate(true)
		sessions.append(session)
	sessions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("npc_id", "")) < str(b.get("npc_id", "")))
	return {
		"gesture_interval_real_seconds": _proactive_talk_gesture_interval_real_seconds,
		"active_count": sessions.size(),
		"sessions": sessions
	}


func get_npc_portrait_snapshot(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id) or not _npc_nodes.has(npc_id):
		return {}
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("get_portrait_camera_snapshot"):
		return {}
	var snapshot: Dictionary = npc_node.get_portrait_camera_snapshot()
	var location_id := str(snapshot.get("location_id", "")).strip_edges()
	var location_name := str(snapshot.get("location_name", "")).strip_edges()
	if location_name.is_empty() or location_name == location_id:
		var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
		if memory_system != null and memory_system.has_method("get_location_snapshot"):
			var location_snapshot: Dictionary = memory_system.get_location_snapshot(location_id)
			snapshot["location_name"] = str(location_snapshot.get("name", "驿站内"))
		else:
			snapshot["location_name"] = "驿站内"
	return snapshot.duplicate(true)


func debug_get_spatial_migration_snapshot(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	var state := get_npc_state(npc_id)
	var route: Dictionary = _building_interior_routes.get(npc_id, {})
	var step_snapshot: Dictionary = {}
	var steps: Array = route.get("steps", [])
	var step_index := int(route.get("step_index", -1))
	if step_index >= 0 and step_index < steps.size() and steps[step_index] is Dictionary:
		var step: Dictionary = steps[step_index]
		step_snapshot = {
			"id": str(step.get("id", "")),
			"phase": str(step.get("phase", "")),
			"position": step.get("position")
		}
	var reservation: Dictionary = {}
	var occupancy: Dictionary = {}
	var motion_snapshot: Dictionary = {}
	var attachment_snapshot: Dictionary = {}
	var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) if _npc_nodes.has(npc_id) else null
	if npc_node != null and npc_node.has_method("debug_get_motion_snapshot"):
		motion_snapshot = npc_node.debug_get_motion_snapshot()
	if npc_node != null and npc_node.has_method("debug_get_spatial_attachment_snapshot"):
		attachment_snapshot = npc_node.debug_get_spatial_attachment_snapshot()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null:
		for raw_building_id in building_system.get_building_ids():
			var building_id := str(raw_building_id)
			var building: Dictionary = building_system.get_building(building_id)
			for raw_workstation in building.get("workstations", []):
				if not raw_workstation is Dictionary:
					continue
				var workstation: Dictionary = raw_workstation
				if _clean_nullable_state_id(workstation.get("reserved_by", "")) == npc_id:
					reservation = {
						"building_id": building_id,
						"workstation_id": str(workstation.get("id", "")),
						"status": "reserved"
					}
				if _clean_nullable_state_id(workstation.get("occupied_by", "")) == npc_id:
					occupancy = {
						"building_id": building_id,
						"workstation_id": str(workstation.get("id", "")),
						"status": "occupied"
					}
	return {
		"npc_id": npc_id,
		"world_position": get_npc_world_position(npc_id),
		"logical_location_id": str(state.get("current_location", "")),
		"logical_location_name": str(state.get("current_location_name", "")),
		"movement_target": str(state.get("movement_target", "")),
		"path_phase": str(state.get("spatial_route_phase", "none")),
		"physical_location_phase": str(state.get("physical_location_phase", "legacy")),
		"current_workstation_id": str(state.get("current_workstation_id", "")),
		"route_kind": str(route.get("kind", "")),
		"passage_id": str(route.get("passage_id", "")),
		"passage_status": str(route.get("passage_status", "")),
		"route_step": step_snapshot,
		"formal_navigation_pilot": _formal_navigation_pilots.has(npc_id),
		"formal_navigation_pilot_state": (_formal_navigation_pilots.get(npc_id, {}) as Dictionary).duplicate(true),
		"formal_workstation_action_session": (_formal_workstation_action_sessions.get(npc_id, {}) as Dictionary).duplicate(true),
		"formal_dialogue_approach_session": get_formal_dialogue_approach_snapshot(npc_id),
		"motion": motion_snapshot,
		"attachment": attachment_snapshot,
		"reservation": reservation,
		"occupancy": occupancy
	}


func _begin_default_formal_world_if_configured() -> void:
	await get_tree().process_frame
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if (
		controller != null
		and controller.has_method("is_default_formal_world_enabled")
		and bool(controller.is_default_formal_world_enabled())
	):
		begin_default_formal_world()


func begin_default_formal_world() -> Dictionary:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if (
		controller == null
		or not controller.has_method("get_production_navigation_map_rid")
		or not controller.has_method("get_npc_initial_world_position")
	):
		return {"ok": false, "reason": "default_formal_world_dependencies_missing"}
	if (
		controller.has_method("is_default_formal_world_enabled")
		and not bool(controller.is_default_formal_world_enabled())
	):
		return {"ok": false, "reason": "default_formal_world_disabled"}
	if controller.has_method("set_runtime_formal_world_enabled"):
		controller.set_runtime_formal_world_enabled(true)
	if controller.has_method("force_sync_production_navigation"):
		controller.force_sync_production_navigation()
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not navigation_map.is_valid():
		return {"ok": false, "reason": "default_formal_navigation_map_missing"}
	var activated: Array[String] = []
	var skipped: Array[Dictionary] = []
	for npc_id in _npc_order:
		if _default_formal_world_npcs.has(npc_id):
			activated.append(npc_id)
			continue
		var state := get_npc_state(npc_id)
		if bool(state.get("escaped", false)):
			skipped.append({"npc_id": npc_id, "reason": "npc_escaped"})
			continue
		var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node == null or not npc_node.has_method("configure_navigation_motion"):
			skipped.append({"npc_id": npc_id, "reason": "npc_formal_actor_missing"})
			continue
		var target_position: Variant = _default_formal_world_resume_positions.get(npc_id)
		if not target_position is Vector3:
			var location_id := str(state.get("current_location", PLAZA_LOCATION_ID))
			if location_id != PLAZA_LOCATION_ID and controller.has_method("get_building_spatial_route"):
				var route: Dictionary = controller.get_building_spatial_route(location_id)
				target_position = route.get("interior_target_position")
			if not target_position is Vector3:
				target_position = controller.get_npc_initial_world_position(npc_id)
		if not target_position is Vector3:
			skipped.append({"npc_id": npc_id, "reason": "npc_formal_anchor_missing"})
			continue
		var snapped_position := NavigationServer3D.map_get_closest_point(navigation_map, target_position)
		var snap_error := Vector2(
			snapped_position.x - target_position.x,
			snapped_position.z - target_position.z
		).length()
		var actor_navigation_sync_pending := snap_error > 2.0
		if actor_navigation_sync_pending:
			# NavigationServer may still report Vector3.ZERO during the first frame in
			# which the formal map is enabled. The authored anchors are already inside
			# the audited walkable area, so they are safer than accepting that stale
			# result and visibly collapsing every resident onto the world origin.
			snapped_position = target_position
		_default_formal_world_npcs[npc_id] = {
			"legacy_position": npc_node.global_position,
			"legacy_navigation_enabled": bool(npc_node.is_navigation_motion_enabled()) if npc_node.has_method("is_navigation_motion_enabled") else false,
			"legacy_navigation_map": npc_node.get_navigation_map() if npc_node.has_method("get_navigation_map") else RID(),
			"navigation_map": navigation_map,
			"activated_at_msec": Time.get_ticks_msec(),
		}
		_cancel_building_interior_route(npc_id, true)
		_movement_arrival_contexts.erase(npc_id)
		_stop_npc_movement(npc_id)
		if npc_node.has_method("detach_from_spatial_anchor"):
			npc_node.detach_from_spatial_anchor()
		npc_node.global_position = snapped_position
		if not bool(npc_node.configure_navigation_motion(true, navigation_map)):
			_default_formal_world_npcs.erase(npc_id)
			skipped.append({"npc_id": npc_id, "reason": "npc_navigation_map_bind_failed"})
			continue
		_set_npc_state_without_signal(npc_id, {
			"movement_target": "",
			"movement_target_name": "",
			"spatial_route_phase": "default_formal_world_ready",
			"physical_location_phase": "formal_world_resident",
			"reserved_building_id": "",
			"reserved_workstation_id": "",
			"current_workstation_id": "",
		})
		_refresh_npc_node(npc_id)
		_emit_npc_state_changed(npc_id)
		activated.append(npc_id)
	return {
		"ok": skipped.is_empty(),
		"active": not _default_formal_world_npcs.is_empty(),
		"activated_count": activated.size(),
		"activated_npc_ids": activated,
		"skipped": skipped,
		"snapshot": get_default_formal_world_snapshot(),
	}


func end_default_formal_world(reason: String = "legacy_compatibility") -> Dictionary:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	for raw_npc_id in _default_formal_world_npcs.keys().duplicate():
		var active_npc_id := str(raw_npc_id)
		if action_system != null and action_system.has_method("interrupt_npc_action"):
			action_system.interrupt_npc_action(active_npc_id, reason, true)
	var restored: Array[String] = []
	for raw_npc_id in _default_formal_world_npcs.keys().duplicate():
		var npc_id := str(raw_npc_id)
		var resident: Dictionary = _default_formal_world_npcs.get(npc_id, {})
		var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node != null:
			_default_formal_world_resume_positions[npc_id] = npc_node.global_position
			_stop_npc_movement(npc_id)
			if npc_node.has_method("detach_from_spatial_anchor"):
				npc_node.detach_from_spatial_anchor()
			if npc_node.has_method("configure_navigation_motion"):
				if bool(resident.get("legacy_navigation_enabled", false)):
					npc_node.configure_navigation_motion(true, resident.get("legacy_navigation_map", RID()))
				else:
					npc_node.configure_navigation_motion(false)
			var legacy_position: Variant = resident.get("legacy_position")
			if legacy_position is Vector3:
				npc_node.global_position = legacy_position
		_set_npc_state_without_signal(npc_id, {
			"movement_target": "",
			"movement_target_name": "",
			"spatial_route_phase": "default_formal_world_%s" % reason,
			"physical_location_phase": "legacy_location",
			"reserved_building_id": "",
			"reserved_workstation_id": "",
			"current_workstation_id": "",
		})
		_default_formal_world_npcs.erase(npc_id)
		_refresh_npc_node(npc_id)
		_emit_npc_state_changed(npc_id)
		restored.append(npc_id)
	return {"ok": true, "active": false, "reason": reason, "restored_npc_ids": restored}


func is_npc_in_default_formal_world(npc_id: String) -> bool:
	return _default_formal_world_npcs.has(npc_id)


func get_default_formal_world_snapshot() -> Dictionary:
	var actors: Array[Dictionary] = []
	for raw_npc_id in _default_formal_world_npcs.keys():
		var npc_id := str(raw_npc_id)
		var resident: Dictionary = _default_formal_world_npcs.get(npc_id, {})
		var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) as Node3D
		var expected_map: RID = resident.get("navigation_map", RID())
		var actual_map: RID = npc_node.get_navigation_map() if npc_node != null and npc_node.has_method("get_navigation_map") else RID()
		actors.append({
			"npc_id": npc_id,
			"world_position": npc_node.global_position if npc_node != null else Vector3.ZERO,
			"navigation_motion_enabled": bool(npc_node.is_navigation_motion_enabled()) if npc_node != null and npc_node.has_method("is_navigation_motion_enabled") else false,
			"navigation_map_matches": expected_map.is_valid() and expected_map == actual_map,
			"physical_location_phase": str(get_npc_state(npc_id).get("physical_location_phase", "")),
			"formal_action_session_active": _formal_workstation_action_sessions.has(npc_id),
			"formal_combat_active": _formal_combat_world_npcs.has(npc_id),
		})
	return {
		"ok": true,
		"active": not _default_formal_world_npcs.is_empty(),
		"actor_count": actors.size(),
		"npc_ids": _default_formal_world_npcs.keys(),
		"actors": actors,
		"action_session_count": _formal_workstation_action_sessions.size(),
		"combat_actor_count": _formal_combat_world_npcs.size(),
	}


func create_formal_spatial_checkpoint() -> Dictionary:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var world_origin: Vector3 = (
		controller.get_formal_world_origin()
		if controller != null and controller.has_method("get_formal_world_origin")
		else Vector3.ZERO
	)
	var actors: Array[Dictionary] = []
	for npc_id in _npc_order:
		var state := get_npc_state(npc_id)
		var position_value: Variant = get_npc_world_position(npc_id)
		var position: Vector3 = position_value if position_value is Vector3 else Vector3.ZERO
		var formal_session: Dictionary = _formal_workstation_action_sessions.get(npc_id, {}) if _formal_workstation_action_sessions.get(npc_id, {}) is Dictionary else {}
		actors.append({
			"npc_id": npc_id,
			"position": {"x": position.x, "y": position.y, "z": position.z},
			"information_location_id": str(state.get("current_location", PLAZA_LOCATION_ID)),
			"current_location_name": str(state.get("current_location_name", "")),
			"physical_location_phase": str(state.get("physical_location_phase", "formal_world_resident")),
			"spatial_route_phase": str(state.get("spatial_route_phase", "default_formal_world_ready")),
			"navigation_authority": "production_formal" if _default_formal_world_npcs.has(npc_id) else "escaped_or_suspended",
			"escaped": bool(state.get("escaped", false)),
			"unconscious": bool(state.get("unconscious", false)),
			"behavior_mode": str(state.get("behavior_mode", BEHAVIOR_MODE_WORK)),
			"combat_attack_sequence": maxi(0, int(state.get("combat_attack_sequence", 0))),
			"combat_attack_sequence_lock_remaining": maxf(
				0.0,
				float(state.get("combat_attack_sequence_lock_remaining", 0.0))
			),
			"escape_intent": (state.get("escape_intent", {}) as Dictionary).duplicate(true) if state.get("escape_intent", {}) is Dictionary else {},
			"in_flight_action": {
				"active": not formal_session.is_empty(),
				"action_id": str(formal_session.get("action_id", "")),
				"building_id": str(formal_session.get("building_id", "")),
				"workstation_id": str(formal_session.get("workstation_id", "")),
				"restore_policy": "rollback"
			},
			"movement_was_active": not str(state.get("movement_target", "")).is_empty(),
			"attachment_was_active": bool((debug_get_spatial_migration_snapshot(npc_id).get("attachment", {}) as Dictionary).get("active", false))
		})
	return {
		"schema": "formal_npc_spatial_checkpoint_v1",
		"world_origin": {"x": world_origin.x, "y": world_origin.y, "z": world_origin.z},
		"actor_count": actors.size(),
		"actors": actors,
		"in_flight_policy": "rollback_to_saved_safe_position"
	}


func restore_formal_spatial_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if str(checkpoint.get("schema", "")) != "formal_npc_spatial_checkpoint_v1":
		return {"ok": false, "reason": "npc_spatial_checkpoint_schema_mismatch"}
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null or not controller.has_method("get_production_navigation_map_rid"):
		return {"ok": false, "reason": "formal_navigation_controller_missing"}
	if controller.has_method("set_runtime_formal_world_enabled"):
		controller.set_runtime_formal_world_enabled(true)
	if controller.has_method("force_sync_production_navigation"):
		controller.force_sync_production_navigation()
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_navigation_map_missing"}
	var current_world_origin: Vector3 = (
		controller.get_formal_world_origin()
		if controller.has_method("get_formal_world_origin")
		else Vector3.ZERO
	)
	var checkpoint_has_origin := checkpoint.get("world_origin") is Dictionary
	var checkpoint_world_origin := _checkpoint_vector3(
		checkpoint.get("world_origin", {}),
		current_world_origin
	)

	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var rolled_back_actions: Array[String] = []
	for raw_actor in checkpoint.get("actors", []):
		if not raw_actor is Dictionary:
			continue
		var actor: Dictionary = raw_actor
		var npc_id := str(actor.get("npc_id", ""))
		if not _profiles.has(npc_id):
			continue
		if action_system != null and action_system.has_method("interrupt_npc_action"):
			if bool(action_system.interrupt_npc_action(npc_id, "save_restore_rollback", true)):
				rolled_back_actions.append(npc_id)
		end_formal_workstation_action(npc_id, "save_restore_rollback", false, "", false)
		_cancel_building_interior_route(npc_id, true)
		_movement_arrival_contexts.erase(npc_id)
		_stop_npc_movement(npc_id)

	# A formerly escaped runtime actor must be made eligible before the formal
	# resident lease is rebuilt. Saved escaped actors remain excluded below.
	for raw_actor in checkpoint.get("actors", []):
		if raw_actor is Dictionary and not bool((raw_actor as Dictionary).get("escaped", false)):
			_set_npc_state_without_signal(str((raw_actor as Dictionary).get("npc_id", "")), {"escaped": false})
	begin_default_formal_world()

	var restored: Array[String] = []
	var fallback_ids: Array[String] = []
	var escaped_ids: Array[String] = []
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	for raw_actor in checkpoint.get("actors", []):
		if not raw_actor is Dictionary:
			continue
		var actor: Dictionary = raw_actor
		var npc_id := str(actor.get("npc_id", ""))
		if not _profiles.has(npc_id) or not _npc_nodes.has(npc_id):
			continue
		var escaped := bool(actor.get("escaped", false))
		var npc_node := get_node_or_null(_npc_nodes[npc_id]) as Node3D
		if npc_node == null:
			continue
		if npc_node.has_method("detach_from_spatial_anchor"):
			npc_node.detach_from_spatial_anchor()
		var saved_position := _checkpoint_vector3(actor.get("position", {}), Vector3.ZERO)
		if checkpoint_has_origin:
			saved_position += current_world_origin - checkpoint_world_origin
		elif controller.has_method("migrate_legacy_formal_world_position"):
			saved_position = controller.migrate_legacy_formal_world_position(saved_position)
		var safe_position := NavigationServer3D.map_get_closest_point(navigation_map, saved_position)
		var horizontal_error := Vector2(safe_position.x - saved_position.x, safe_position.z - saved_position.z).length()
		if saved_position == Vector3.ZERO or horizontal_error > 3.0:
			var location_id := str(actor.get("information_location_id", PLAZA_LOCATION_ID))
			var route: Dictionary = controller.get_building_spatial_route(location_id) if location_id != PLAZA_LOCATION_ID and controller.has_method("get_building_spatial_route") else {}
			var fallback: Variant = route.get("interior_target_position")
			if not fallback is Vector3:
				fallback = controller.get_npc_initial_world_position(npc_id)
			safe_position = fallback if fallback is Vector3 else saved_position
			fallback_ids.append(npc_id)
		npc_node.global_position = safe_position
		var location_id := str(actor.get("information_location_id", PLAZA_LOCATION_ID))
		_set_npc_state_without_signal(npc_id, {
			"current_action": "escaped" if escaped else ("unconscious" if bool(actor.get("unconscious", false)) else "idle"),
			"current_location": "outside_station" if escaped else location_id,
			"current_location_name": "驿站外" if escaped else str(actor.get("current_location_name", location_id)),
			"movement_target": "",
			"movement_target_name": "",
			"physical_location_phase": "outside_station" if escaped else str(actor.get("physical_location_phase", "formal_world_resident")),
			"spatial_route_phase": "save_restored_escaped" if escaped else "save_restored_safe_position",
			"reserved_building_id": "",
			"reserved_workstation_id": "",
			"current_workstation_id": "",
			"escaped": escaped,
			"unconscious": bool(actor.get("unconscious", false)) and not escaped,
			"behavior_mode": BEHAVIOR_MODE_ESCAPED if escaped else str(actor.get("behavior_mode", BEHAVIOR_MODE_WORK)),
			"combat_attack_cooldown": maxf(0.0, float(actor.get("combat_attack_sequence_lock_remaining", 0.0))),
			"combat_attack_target_enemy_id": "",
			"combat_attack_phase": "idle",
			"combat_attack_elapsed_seconds": 0.0,
			"combat_attack_cycle_seconds": 0.0,
			"combat_attack_impact_seconds": 0.0,
			"combat_attack_playback_multiplier": 1.0,
			"combat_attack_sequence": maxi(0, int(actor.get("combat_attack_sequence", 0))),
			"combat_attack_impact_committed": false,
			"combat_attack_last_sequence_time": -1.0,
			"combat_attack_next_sequence_time": 0.0,
			"combat_attack_sequence_lock_remaining": maxf(
				0.0,
				float(actor.get("combat_attack_sequence_lock_remaining", 0.0))
			),
			"combat_last_attack_result": {},
			"escape_intent": (actor.get("escape_intent", {}) as Dictionary).duplicate(true) if actor.get("escape_intent", {}) is Dictionary else {}
		})
		if escaped:
			_default_formal_world_npcs.erase(npc_id)
			if npc_node.has_method("configure_navigation_motion"):
				npc_node.configure_navigation_motion(false)
			escaped_ids.append(npc_id)
		else:
			if npc_node.has_method("configure_navigation_motion"):
				npc_node.configure_navigation_motion(true, navigation_map)
		if memory_system != null and memory_system.has_method("restore_npc_location_membership_silent"):
			if escaped:
				memory_system.remove_npc_from_all_locations(npc_id)
			else:
				memory_system.restore_npc_location_membership_silent(npc_id, location_id)
		_refresh_npc_node(npc_id)
		_emit_npc_state_changed(npc_id)
		restored.append(npc_id)
	return {
		"ok": restored.size() == int(checkpoint.get("actor_count", restored.size())),
		"restored_npc_ids": restored,
		"escaped_npc_ids": escaped_ids,
		"fallback_npc_ids": fallback_ids,
		"rolled_back_action_npc_ids": rolled_back_actions,
		"duplicate_location_or_action_events": 0
	}


func _checkpoint_vector3(raw_value: Variant, fallback: Vector3) -> Vector3:
	if raw_value is Vector3:
		return raw_value
	if not raw_value is Dictionary:
		return fallback
	var data := raw_value as Dictionary
	return Vector3(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)), float(data.get("z", fallback.z)))


func get_npc_behavior_mode_snapshot(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	var state := get_npc_state(npc_id)
	var mode := _get_current_behavior_mode(npc_id)
	return {
		"npc_id": npc_id,
		"behavior_mode": mode,
		"behavior_mode_label": _get_behavior_mode_label(mode),
		"previous_mode": str(state.get("behavior_mode_previous", "")),
		"reason": str(state.get("behavior_mode_reason", "")),
		"entered_day": int(state.get("behavior_mode_entered_day", 1)),
		"entered_time": str(state.get("behavior_mode_entered_time", "00:00:00")),
		"current_action": str(state.get("current_action", "")),
		"combat_mode": str(state.get("combat_mode", "")),
		"combat_target_enemy_id": str(state.get("combat_target_enemy_id", "")),
		"combat_target_selection_reason": str(state.get("combat_target_selection_reason", "")),
		"combat_target_scope": str(state.get("combat_target_scope", "")),
		"combat_strategy": state.get("combat_strategy", {}),
		"combat_strategy_move_enemy_id": str(state.get("combat_strategy_move_enemy_id", "")),
		"combat_strategy_move_target_id": str(state.get("combat_strategy_move_target_id", "")),
		"combat_strategy_move_target_name": str(state.get("combat_strategy_move_target_name", "")),
		"combat_strategy_move_target_position": state.get("combat_strategy_move_target_position", {}),
		"combat_strategy_move_recovery_count": int(state.get("combat_strategy_move_recovery_count", 0)),
		"combat_strategy_last_stall": state.get("combat_strategy_last_stall", {}),
		"world_movement_progress": get_npc_world_movement_progress(npc_id),
		"keep_distance_retreat_active": bool(state.get("keep_distance_retreat_active", false)),
		"keep_distance_retreat_sequence": int(state.get("keep_distance_retreat_sequence", 0)),
		"keep_distance_retreat_target_id": str(state.get("keep_distance_retreat_target_id", "")),
		"keep_distance_retreat_target_position": state.get("keep_distance_retreat_target_position", {}),
		"keep_distance_retreat_threat_ids": state.get("keep_distance_retreat_threat_ids", []),
		"keep_distance_retreat_recovery_count": int(state.get("keep_distance_retreat_recovery_count", 0)),
		"avoidance_target_id": str(state.get("avoidance_target_id", "")),
		"avoidance_target_name": str(state.get("avoidance_target_name", "")),
		"avoidance_target_position": state.get("avoidance_target_position", {}),
		"unconscious": bool(state.get("unconscious", false)),
		"escaped": bool(state.get("escaped", false))
	}


func debug_get_behavior_mode_snapshot(npc_id: String = "") -> Variant:
	var clean_id := npc_id.strip_edges()
	if not clean_id.is_empty():
		return get_npc_behavior_mode_snapshot(clean_id)
	var result: Array[Dictionary] = []
	for id in _npc_order:
		result.append(get_npc_behavior_mode_snapshot(id))
	return result


func set_npc_behavior_mode(
	npc_id: String,
	mode: String,
	reason: String = "mode_changed",
	options: Dictionary = {}
) -> Dictionary:
	if not _profiles.has(npc_id):
		return {"ok": false, "error": "unknown_npc", "npc_id": npc_id}
	var clean_mode := mode.strip_edges()
	if not VALID_BEHAVIOR_MODES.has(clean_mode):
		return {"ok": false, "error": "invalid_behavior_mode", "npc_id": npc_id, "mode": mode}

	var state := get_npc_state(npc_id)
	if bool(state.get("escaped", false)) and clean_mode != BEHAVIOR_MODE_ESCAPED:
		return {"ok": false, "error": "npc_escaped", "npc_id": npc_id, "mode": clean_mode}
	if bool(state.get("unconscious", false)) and not [BEHAVIOR_MODE_UNCONSCIOUS, BEHAVIOR_MODE_WORK, BEHAVIOR_MODE_COMBAT, BEHAVIOR_MODE_AVOID_COMBAT].has(clean_mode):
		return {"ok": false, "error": "npc_unconscious", "npc_id": npc_id, "mode": clean_mode}

	var world_movement: Dictionary = (
		options.get("_world_movement", {})
		if options.get("_world_movement", {}) is Dictionary
		else {}
	)
	var movement_node: Node = null
	var movement_target_id := ""
	var movement_target_name := ""
	var movement_target_position := Vector3.ZERO
	var movement_arrival_state: Dictionary = {}
	if not world_movement.is_empty():
		movement_arrival_state = (
			(world_movement.get("arrival_state", {}) as Dictionary).duplicate(true)
			if world_movement.get("arrival_state", {}) is Dictionary
			else {}
		)
		if not can_npc_move_to_world_position(npc_id, movement_arrival_state):
			return {
				"ok": false,
				"error": "movement_unavailable",
				"npc_id": npc_id,
				"mode": clean_mode
			}
		movement_target_id = str(world_movement.get("target_id", "")).strip_edges()
		if movement_target_id.is_empty():
			movement_target_id = "world_target"
		movement_target_name = str(world_movement.get("target_name", "")).strip_edges()
		if movement_target_name.is_empty():
			movement_target_name = movement_target_id
		var raw_target_position: Variant = world_movement.get("target_position", Vector3.ZERO)
		if not raw_target_position is Vector3:
			return {
				"ok": false,
				"error": "invalid_movement_target",
				"npc_id": npc_id,
				"mode": clean_mode
			}
		movement_target_position = raw_target_position
		movement_node = get_node_or_null(_npc_nodes.get(npc_id, NodePath("")))
		if movement_node == null or not movement_node.has_method("move_to_location"):
			return {
				"ok": false,
				"error": "movement_unavailable",
				"npc_id": npc_id,
				"mode": clean_mode
			}

	var previous_mode := _get_current_behavior_mode(npc_id)
	var plan_interruption_status := {}
	if previous_mode == BEHAVIOR_MODE_WORK and [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT, BEHAVIOR_MODE_AVOID_COMBAT].has(clean_mode):
		var plan_system_for_interruption := get_node_or_null("/root/Main/Systems/DailyPlanSystem")
		if plan_system_for_interruption != null and plan_system_for_interruption.has_method("capture_current_plan_for_behavior_mode_interruption"):
			plan_interruption_status = plan_system_for_interruption.capture_current_plan_for_behavior_mode_interruption(npc_id, reason)
	var interrupt_modes := [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT, BEHAVIOR_MODE_AVOID_COMBAT]
	var should_interrupt := bool(options.get("interrupt", interrupt_modes.has(clean_mode)))
	var interrupt_result := {}
	if should_interrupt:
		interrupt_result = _interrupt_for_behavior_mode(npc_id, clean_mode, reason, options)
	if (
		not world_movement.is_empty()
		and (
			not is_instance_valid(movement_node)
			or not movement_node.has_method("move_to_location")
		)
	):
		return {
			"ok": false,
			"error": "movement_unavailable_after_interrupt",
			"npc_id": npc_id,
			"mode": clean_mode,
			"interrupt_result": interrupt_result
		}

	var state_changes: Dictionary = options.get("state_changes", {}) if (options.get("state_changes", {}) is Dictionary) else {}
	var time_snapshot := _get_game_time_snapshot()
	var changes := state_changes.duplicate(true)
	changes["behavior_mode"] = clean_mode
	changes["behavior_mode_previous"] = previous_mode
	changes["behavior_mode_reason"] = reason
	changes["behavior_mode_entered_day"] = int(time_snapshot.get("day", 1))
	changes["behavior_mode_entered_time"] = str(time_snapshot.get("time", "00:00:00"))
	match clean_mode:
		BEHAVIOR_MODE_RALLY:
			changes["combat_mode"] = "rally"
			if not changes.has("current_action"):
				changes["current_action"] = "rallying_defense_line"
		BEHAVIOR_MODE_COMBAT:
			changes["combat_mode"] = "combat"
			changes["avoidance_target_id"] = ""
			changes["avoidance_target_name"] = ""
			changes["avoidance_target_position"] = {}
			if not changes.has("current_action"):
				changes["current_action"] = "combat_ready"
		BEHAVIOR_MODE_AVOID_COMBAT:
			changes["combat_mode"] = ""
			changes["combat_mounted"] = false
			changes["combat_mount_phase"] = "unmounted"
			changes["combat_strategy_move_target_id"] = ""
			changes["combat_strategy_move_target_name"] = ""
			changes["combat_strategy_move_target_position"] = {}
			changes["combat_strategy_move_enemy_id"] = ""
			if not changes.has("current_action"):
				changes["current_action"] = "avoid_combat"
		BEHAVIOR_MODE_UNCONSCIOUS:
			changes["combat_mode"] = ""
			changes["combat_mounted"] = false
			changes["combat_mount_phase"] = "rider_unconscious"
			changes["combat_attack_cooldown"] = 0.0
			changes["combat_last_attack_result"] = {}
			changes["combat_strategy_move_target_id"] = ""
			changes["combat_strategy_move_target_name"] = ""
			changes["combat_strategy_move_target_position"] = {}
			changes["combat_strategy_move_enemy_id"] = ""
			changes["avoidance_target_id"] = ""
			changes["avoidance_target_name"] = ""
			changes["avoidance_target_position"] = {}
			changes["current_action"] = "unconscious"
		BEHAVIOR_MODE_ESCAPED:
			changes["combat_mode"] = ""
			changes["combat_mounted"] = false
			changes["combat_mount_phase"] = "unmounted"
			changes["combat_attack_cooldown"] = 0.0
			changes["combat_last_attack_result"] = {}
			changes["combat_strategy_move_target_id"] = ""
			changes["combat_strategy_move_target_name"] = ""
			changes["combat_strategy_move_target_position"] = {}
			changes["combat_strategy_move_enemy_id"] = ""
			changes["avoidance_target_id"] = ""
			changes["avoidance_target_name"] = ""
			changes["avoidance_target_position"] = {}
		BEHAVIOR_MODE_WORK:
			changes["combat_mode"] = ""
			changes["combat_mounted"] = false
			changes["combat_mount_phase"] = "horse_returning" if bool(state.get("combat_mounted", false)) else "unmounted"
			changes["combat_target_enemy_id"] = ""
			changes["combat_target_selection_reason"] = ""
			changes["combat_target_scope"] = ""
			changes["combat_attack_cooldown"] = 0.0
			changes["combat_last_attack_result"] = {}
			changes["combat_strategy_move_target_id"] = ""
			changes["combat_strategy_move_target_name"] = ""
			changes["combat_strategy_move_target_position"] = {}
			changes["combat_strategy_move_enemy_id"] = ""
			changes["avoidance_target_id"] = ""
			changes["avoidance_target_name"] = ""
			changes["avoidance_target_position"] = {}
			if _should_clear_action_when_returning_to_work(str(state.get("current_action", "")), options):
				changes["current_action"] = "idle"
			if not changes.has("last_action_result"):
				changes["last_action_result"] = reason

	if clean_mode != BEHAVIOR_MODE_COMBAT or previous_mode != BEHAVIOR_MODE_COMBAT:
		changes["combat_attack_cooldown"] = 0.0
		changes["combat_attack_target_enemy_id"] = ""
		changes["combat_attack_phase"] = "idle"
		changes["combat_attack_elapsed_seconds"] = 0.0
		changes["combat_attack_cycle_seconds"] = 0.0
		changes["combat_attack_impact_seconds"] = 0.0
		changes["combat_attack_playback_multiplier"] = 1.0
		changes["combat_attack_impact_committed"] = false
		changes["combat_last_attack_result"] = {}
		changes["combat_strategy_move_recovery_count"] = 0
		changes["combat_strategy_last_stall"] = {}
		changes["keep_distance_retreat_active"] = false
		changes["keep_distance_retreat_target_id"] = ""
		changes["keep_distance_retreat_target_position"] = {}
		changes["keep_distance_retreat_desired_position"] = {}
		changes["keep_distance_retreat_direction"] = {}
		changes["keep_distance_retreat_threat_ids"] = []
		changes["keep_distance_retreat_threats"] = []

	if not world_movement.is_empty():
		changes["current_action"] = "moving_to_%s" % movement_target_id
		changes["movement_target"] = movement_target_id
		changes["movement_target_name"] = movement_target_name
		changes["location_context"] = {}
		_movement_arrival_contexts[npc_id] = {
			"target_id": movement_target_id,
			"target_name": movement_target_name,
			"target_position": movement_target_position,
			"arrival_state": movement_arrival_state.duplicate(true)
		}
	_set_npc_state_without_signal(npc_id, changes)
	if not world_movement.is_empty():
		movement_node.move_to_location(movement_target_id, movement_target_position)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)

	var mode_event := {}
	if (
		(previous_mode != clean_mode or bool(options.get("log_if_same", false)))
		and _should_log_npc_mode_changed(previous_mode, clean_mode, options)
	):
		mode_event = _log_npc_mode_changed(npc_id, previous_mode, clean_mode, reason, options)
	var reevaluation_status := {}
	if bool(options.get("request_plan_reevaluation", false)):
		reevaluation_status = _request_plan_reevaluation_or_defer(npc_id, reason)
	var plan_resume_status := {}
	if clean_mode == BEHAVIOR_MODE_WORK and bool(options.get("resume_current_plan", false)):
		var daily_plan_system := get_node_or_null("/root/Main/Systems/DailyPlanSystem")
		if daily_plan_system != null and daily_plan_system.has_method("resume_current_plan_after_behavior_mode"):
			# A battle-clear caller still has to release the formal combat-world
			# lease after this transition returns. Resume on the deferred boundary so
			# that cleanup cannot cancel the newly started plan route.
			daily_plan_system.call_deferred("resume_current_plan_after_behavior_mode", npc_id, reason)
			plan_resume_status = {
				"ok": true,
				"npc_id": npc_id,
				"status": "scheduled",
				"resumed_after_behavior_mode": true,
				"behavior_mode_end_reason": reason
			}
	return {
		"ok": true,
		"npc_id": npc_id,
		"previous_mode": previous_mode,
		"behavior_mode": clean_mode,
		"reason": reason,
		"changed": previous_mode != clean_mode,
		"interrupt_result": interrupt_result,
		"plan_interruption_status": plan_interruption_status,
		"event": mode_event,
		"plan_reevaluation_status": reevaluation_status,
		"plan_resume_status": plan_resume_status,
		"movement_started": not world_movement.is_empty()
	}


func set_npc_behavior_mode_and_move_to_world_position(
	npc_id: String,
	mode: String,
	reason: String,
	target_id: String,
	target_name: String,
	target_position: Vector3,
	arrival_state: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var transition_options := options.duplicate(true)
	transition_options["_world_movement"] = {
		"target_id": target_id,
		"target_name": target_name,
		"target_position": target_position,
		"arrival_state": arrival_state.duplicate(true)
	}
	return set_npc_behavior_mode(npc_id, mode, reason, transition_options)


func is_npc_sleeping(npc_id: String) -> bool:
	if not _profiles.has(npc_id):
		return false
	return _is_sleeping_state(get_npc_state(npc_id))


func get_selected_npc_id() -> String:
	return _selected_npc_id


func get_professional_skill_names() -> Array[String]:
	return PROFESSIONAL_SKILLS.duplicate()


func get_weapon_skill_names() -> Array[String]:
	return WEAPON_SKILLS.duplicate()


func normalize_skills(raw_skills: Variant) -> Dictionary:
	var source: Dictionary = raw_skills if raw_skills is Dictionary else {}
	var normalized := {}
	for skill_name in PROFESSIONAL_SKILLS + WEAPON_SKILLS:
		normalized[skill_name] = clampi(int(source.get(skill_name, 0)), 0, 100)
	return normalized


func get_npc_specialties(npc_id: String, max_count: int = 3) -> Array[String]:
	var npc := get_npc(npc_id)
	if npc.is_empty():
		return []

	var skills: Dictionary = normalize_skills(npc.get("skills", {}))
	var entries: Array[Dictionary] = []
	for skill_name in PROFESSIONAL_SKILLS + WEAPON_SKILLS:
		var value := int(skills.get(skill_name, 0))
		if value >= SPECIALTY_THRESHOLD:
			entries.append({"name": skill_name, "value": value})

	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("value", 0)) > int(right.get("value", 0))
	)

	var result: Array[String] = []
	for index in range(mini(max_count, entries.size())):
		var entry: Dictionary = entries[index]
		result.append("%s %d" % [str(entry.get("name", "")), int(entry.get("value", 0))])
	return result


func debug_select_npc(npc_id: String) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot select unknown NPC: %s" % npc_id)
		return false
	_select_npc(npc_id)
	return true


func move_npc_to_building(npc_id: String, building_id: String) -> bool:
	if _profiles.has(npc_id):
		var state := get_npc_state(npc_id)
		var current_location := str(state.get("current_location", PLAZA_LOCATION_ID))
		var is_moving := not str(state.get("movement_target", "")).is_empty()
		if _default_formal_world_npcs.has(npc_id):
			var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
			if controller == null or not controller.has_method("get_building_spatial_route"):
				return false
			if current_location == building_id and not is_moving:
				return true
			var source_route: Dictionary = controller.get_building_spatial_route(current_location)
			if current_location != PLAZA_LOCATION_ID and current_location != building_id and not source_route.is_empty():
				return _start_building_exit_route(npc_id, building_id, current_location, source_route)
			if building_id == PLAZA_LOCATION_ID:
				return _start_formal_public_location_route(npc_id, PLAZA_LOCATION_ID)
			var target_route: Dictionary = controller.get_building_spatial_route(building_id)
			if target_route.is_empty():
				return false
			return _start_building_entry_route(npc_id, building_id, "", target_route)
		if current_location == FIRST_SPATIAL_INTERIOR_BUILDING_ID and building_id != current_location:
			return _start_building_exit_route(npc_id, building_id)
		if building_id == FIRST_SPATIAL_INTERIOR_BUILDING_ID:
			if current_location == building_id and not is_moving:
				return true
			return _start_building_entry_route(npc_id, building_id)
	return _move_npc_to_building_direct(npc_id, building_id)


func move_npc_to_building_workstation(npc_id: String, building_id: String, workstation_id: String) -> bool:
	if workstation_id.is_empty():
		return false
	if _formal_workstation_action_sessions.has(npc_id):
		var session: Dictionary = _formal_workstation_action_sessions[npc_id]
		session["workstation_id"] = workstation_id
		_formal_workstation_action_sessions[npc_id] = session
		var state := get_npc_state(npc_id)
		if (
			str(state.get("current_location", "")) == building_id
			and str(state.get("physical_location_phase", "")) == "workstation"
			and str(state.get("current_workstation_id", "")) == workstation_id
			and str(state.get("current_action", "")) == "idle"
		):
			_set_npc_state_without_signal(npc_id, {
				"reserved_building_id": building_id,
				"reserved_workstation_id": workstation_id,
				"spatial_route_phase": "workstation_arrived",
				"last_action_result": "formal_workstation_reused"
			})
			_refresh_npc_node(npc_id)
			_emit_npc_state_changed(npc_id)
			return true
	if _formal_navigation_pilots.has(npc_id) or _formal_workstation_action_sessions.has(npc_id):
		var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		if controller == null or not controller.has_method("get_building_spatial_route"):
			return false
		var formal_route: Dictionary = controller.get_building_spatial_route(building_id, workstation_id)
		if formal_route.is_empty():
			return false
		return _start_building_entry_route(npc_id, building_id, workstation_id, formal_route)
	if building_id != FIRST_SPATIAL_INTERIOR_BUILDING_ID:
		return _move_npc_to_building_direct(npc_id, building_id)
	return _start_building_entry_route(npc_id, building_id, workstation_id)


func _move_npc_to_building_direct(npc_id: String, building_id: String, preserve_last_result: bool = false) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot move unknown NPC: %s" % npc_id)
		return false
	if not can_npc_act(npc_id):
		return false
	if not _npc_nodes.has(npc_id):
		push_warning("Cannot move NPC without scene node: %s" % npc_id)
		return false

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		push_warning("Cannot move NPC because BuildingSystem is missing.")
		return false
	if not _is_location_available_for_access(building_id, building_system):
		var availability := _get_location_entry_availability(building_id, building_system)
		push_warning("Cannot move NPC %s into unavailable building %s: %s" % [
			npc_id,
			building_id,
			str(availability.get("unavailable_reason", "building_unavailable"))
		])
		return false

	var target_position: Variant = building_system.get_building_entry_position(building_id)
	if target_position == null:
		push_warning("Cannot move NPC %s to building without entry position: %s" % [npc_id, building_id])
		return false

	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("move_to_location"):
		push_warning("Cannot move NPC because node has no movement API: %s" % npc_id)
		return false

	var building_name := "广场" if building_id == PLAZA_LOCATION_ID else str(building_system.get_building(building_id).get("name", building_id))
	var previous_result := str(get_npc_state(npc_id).get("last_action_result", ""))
	_set_npc_state_without_signal(npc_id, {
		"current_action": "moving_to_%s" % building_id,
		"movement_target": building_id,
		"movement_target_name": building_name,
		"location_context": {},
		"last_action_result": previous_result if preserve_last_result else "movement_started",
		"last_action_failure_context": {}
	})
	npc_node.move_to_location(building_id, target_position)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func _start_building_entry_route(
	npc_id: String,
	building_id: String,
	workstation_id: String = "",
	route_override: Dictionary = {}
) -> bool:
	var is_formal_pilot_route := (
		(_formal_navigation_pilots.has(npc_id) or _formal_workstation_action_sessions.has(npc_id))
		and not route_override.is_empty()
	)
	if (
		not _profiles.has(npc_id)
		or (not can_npc_act(npc_id) and not is_formal_pilot_route)
		or not _npc_nodes.has(npc_id)
	):
		return false
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building_interior_route"):
		return false
	if not _is_location_available_for_access(building_id, building_system):
		return false
	var route_snapshot: Dictionary = (
		route_override.duplicate(true)
		if not route_override.is_empty()
		else building_system.get_building_interior_route(building_id, workstation_id)
	)
	if route_snapshot.is_empty():
		return false
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("move_to_location"):
		return false

	_stop_npc_movement(npc_id)
	_movement_arrival_contexts.erase(npc_id)
	_building_interior_routes.erase(npc_id)
	var state := get_npc_state(npc_id)
	var current_location := str(state.get("current_location", PLAZA_LOCATION_ID))
	var location_context: Dictionary = (
		(state.get("location_context", {}) as Dictionary).duplicate(true)
		if state.get("location_context", {}) is Dictionary
		else {}
	)
	if current_location != building_id and current_location != PLAZA_LOCATION_ID:
		var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
		if memory_system != null:
			location_context = _transition_npc_info_location(
				npc_id,
				_get_info_location_id(memory_system, current_location),
				PLAZA_LOCATION_ID,
				PLAZA_LOCATION_ID,
				memory_system
			)
		current_location = PLAZA_LOCATION_ID

	var steps: Array[Dictionary] = []
	if current_location != building_id:
		steps.append({
			"id": "%s:door_outside" % building_id,
			"phase": "approaching_door",
			"physical_phase": "outdoor_path",
			"position": route_snapshot.get("entry_outside_position"),
			"check_entry": true
		})
		steps.append({
			"id": "%s:door_inside" % building_id,
			"phase": "crossing_entry",
			"physical_phase": "door_threshold",
			"position": route_snapshot.get("interior_position", route_snapshot.get("door_inside_position")),
			"crosses_entry": true
		})
	steps.append({
		"id": "%s:%s" % [building_id, workstation_id if not workstation_id.is_empty() else "interior"],
		"phase": "moving_to_workstation" if not workstation_id.is_empty() else "moving_inside",
		"physical_phase": "inside_path",
		"position": route_snapshot.get("interior_target_position"),
		"target_desired_distance": route_snapshot.get("target_desired_distance"),
		"facing_direction": route_snapshot.get("interior_target_facing_direction", Vector3.ZERO),
		"arrival_mode": str(route_snapshot.get("arrival_mode", "stand")),
		"occupant_anchor_position": route_snapshot.get("occupant_anchor_position"),
		"occupant_anchor_facing_direction": route_snapshot.get("occupant_anchor_facing_direction", Vector3.ZERO),
		"occupant_pose": str(route_snapshot.get("occupant_pose", "")),
		"completes_entry": true
	})
	if steps.is_empty() or not steps[0].get("position") is Vector3:
		return false

	_building_interior_routes[npc_id] = {
		"kind": "entry",
		"route_source": "formal_station_layout" if not route_override.is_empty() else "legacy_building_art",
		"building_id": building_id,
		"building_name": str(building_system.get_building(building_id).get("name", building_id)),
		"workstation_id": workstation_id,
		"steps": steps,
		"step_index": 0
	}
	_set_npc_state_without_signal(npc_id, {
		"current_location": current_location,
		"current_location_name": str(location_context.get("name", "广场" if current_location == PLAZA_LOCATION_ID else building_id)),
		"location_context": location_context,
		"reserved_building_id": building_id if not workstation_id.is_empty() else "",
		"reserved_workstation_id": workstation_id,
		"current_workstation_id": "",
		"last_action_result": "interior_route_started",
		"last_action_failure_context": {}
	})
	_start_current_building_route_step(npc_id)
	return true


func _start_building_exit_route(
	npc_id: String,
	destination_building_id: String,
	source_building_id: String = FIRST_SPATIAL_INTERIOR_BUILDING_ID,
	route_override: Dictionary = {}
) -> bool:
	if not _profiles.has(npc_id) or not can_npc_act(npc_id) or not _npc_nodes.has(npc_id):
		return false
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building_interior_route"):
		return false
	var route_snapshot: Dictionary = (
		route_override.duplicate(true)
		if not route_override.is_empty()
		else building_system.get_building_interior_route(source_building_id)
	)
	if route_snapshot.is_empty():
		return false
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("move_to_location"):
		return false
	_stop_npc_movement(npc_id)
	_movement_arrival_contexts.erase(npc_id)
	_release_npc_spatial_reservation(npc_id)
	var destination_name := "广场"
	if destination_building_id != PLAZA_LOCATION_ID:
		destination_name = str(building_system.get_building(destination_building_id).get("name", destination_building_id))
	var steps: Array[Dictionary] = [
		{
			"id": "%s:door_inside_exit" % source_building_id,
			"phase": "moving_to_exit",
			"physical_phase": "inside_path",
			"position": route_snapshot.get("door_inside_position")
		},
		{
			"id": "%s:door_outside_exit" % source_building_id,
			"phase": "crossing_exit",
			"physical_phase": "door_threshold",
			"position": route_snapshot.get("entry_outside_position"),
			"crosses_exit": true
		},
		{
			"id": "%s:exit_path" % source_building_id,
			"phase": "leaving_building",
			"physical_phase": "outdoor_path",
			"position": route_snapshot.get("exit_outside_position"),
			"completes_exit": true
		}
	]
	_building_interior_routes[npc_id] = {
		"kind": "exit",
		"route_source": "formal_station_layout" if not route_override.is_empty() else "legacy_building_art",
		"building_id": source_building_id,
		"building_name": str(building_system.get_building(source_building_id).get("name", source_building_id)),
		"destination_building_id": destination_building_id,
		"destination_name": destination_name,
		"workstation_id": "",
		"steps": steps,
		"step_index": 0
	}
	_set_npc_state_without_signal(npc_id, {
		"reserved_building_id": "",
		"reserved_workstation_id": "",
		"current_workstation_id": ""
	})
	_start_current_building_route_step(npc_id)
	return true


func _start_current_building_route_step(npc_id: String, extra_changes: Dictionary = {}) -> void:
	if not _building_interior_routes.has(npc_id) or not _npc_nodes.has(npc_id):
		return
	var route: Dictionary = _building_interior_routes[npc_id]
	var steps: Array = route.get("steps", [])
	var step_index := int(route.get("step_index", 0))
	if step_index < 0 or step_index >= steps.size() or not steps[step_index] is Dictionary:
		return
	var step: Dictionary = steps[step_index]
	var target_position: Variant = step.get("position")
	if not target_position is Vector3:
		return
	var movement_target := str(route.get("building_id", ""))
	var movement_target_name := str(route.get("building_name", movement_target))
	if str(route.get("kind", "")) == "exit":
		movement_target = str(route.get("destination_building_id", PLAZA_LOCATION_ID))
		movement_target_name = str(route.get("destination_name", movement_target))
	var changes := {
		"current_action": "moving_to_%s" % movement_target,
		"movement_target": movement_target,
		"movement_target_name": movement_target_name,
		"spatial_route_phase": str(step.get("phase", "moving")),
		"physical_location_phase": str(step.get("physical_phase", "path"))
	}
	for raw_key in extra_changes.keys():
		changes[str(raw_key)] = extra_changes[raw_key]
	_set_npc_state_without_signal(npc_id, changes)
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node != null and npc_node.has_method("move_to_location"):
		var motion_options := {}
		if step.get("target_desired_distance") is float or step.get("target_desired_distance") is int:
			motion_options["target_desired_distance"] = float(step.get("target_desired_distance"))
		npc_node.move_to_location(str(step.get("id", movement_target)), target_position, motion_options)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)


func move_npc_to_world_position(
	npc_id: String,
	target_id: String,
	target_name: String,
	target_position: Vector3,
	arrival_state: Dictionary = {},
	motion_options: Dictionary = {}
) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot move unknown NPC: %s" % npc_id)
		return false
	var allow_escaping_movement := bool(arrival_state.get("allow_escaping_movement", false))
	if not can_npc_act(npc_id):
		if not allow_escaping_movement:
			return false
		var state := get_npc_state(npc_id)
		if bool(state.get("unconscious", false)) or bool(state.get("escaped", false)) or bool(state.get("first_sleep_summary_active", false)):
			return false
	if not _npc_nodes.has(npc_id):
		push_warning("Cannot move NPC without scene node: %s" % npc_id)
		return false

	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("move_to_location"):
		push_warning("Cannot move NPC because node has no movement API: %s" % npc_id)
		return false
	_cancel_building_interior_route(npc_id, true)

	var clean_target_id := target_id.strip_edges()
	if clean_target_id.is_empty():
		clean_target_id = "world_target"
	var clean_target_name := target_name.strip_edges()
	if clean_target_name.is_empty():
		clean_target_name = clean_target_id

	_movement_arrival_contexts[npc_id] = {
		"target_id": clean_target_id,
		"target_name": clean_target_name,
		"target_position": target_position,
		"arrival_state": arrival_state.duplicate(true),
		"motion_options": motion_options.duplicate(true)
	}
	var departure_current_action := str(arrival_state.get(
		"departure_current_action",
		"moving_to_%s" % clean_target_id
	))
	var departure_location_context: Dictionary = {}
	if bool(arrival_state.get("preserve_location_context", false)):
		var current_location_context: Variant = get_npc_state(npc_id).get("location_context", {})
		if current_location_context is Dictionary:
			departure_location_context = current_location_context.duplicate(true)
	var departure_changes := {
		"current_action": departure_current_action,
		"movement_target": clean_target_id,
		"movement_target_name": clean_target_name,
		"location_context": departure_location_context,
		"last_action_result": "movement_started",
		"last_action_failure_context": {}
	}
	var requested_departure_state: Variant = arrival_state.get("departure_state", {})
	if requested_departure_state is Dictionary:
		for raw_key in requested_departure_state.keys():
			departure_changes[str(raw_key)] = requested_departure_state[raw_key]
	_set_npc_state_without_signal(npc_id, departure_changes)
	npc_node.move_to_location(clean_target_id, target_position, motion_options)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func begin_formal_combat_world(npc_ids: Array[String]) -> Dictionary:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if (
		controller == null
		or not controller.has_method("get_production_navigation_map_rid")
		or not controller.has_method("get_npc_initial_world_position")
	):
		return {"ok": false, "reason": "formal_combat_world_dependencies_missing"}
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_combat_navigation_map_missing"}
	var entry_world_positions := {}
	for npc_id in npc_ids:
		var entry_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) as Node3D if _npc_nodes.has(npc_id) else null
		if entry_node != null:
			entry_world_positions[npc_id] = entry_node.global_position

	# A workstation pilot owns the same physical body. End it before the combat
	# world takes over so one NPC never has two spatial authorities.
	debug_stop_all_formal_navigation_pilots("formal_combat_world_started")
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	for raw_session_npc_id in _formal_workstation_action_sessions.keys().duplicate():
		var session_npc_id := str(raw_session_npc_id)
		if action_system != null and action_system.has_method("interrupt_npc_action"):
			action_system.interrupt_npc_action(session_npc_id, "formal_combat_world_started", true)
		end_formal_workstation_action(session_npc_id, "formal_combat_world_started", true)
	var migrated: Array[String] = []
	var skipped: Array[Dictionary] = []
	var skipped_only_temporarily_unavailable := true
	for npc_id in npc_ids:
		if _formal_combat_world_npcs.has(npc_id):
			migrated.append(npc_id)
			continue
		if not _profiles.has(npc_id) or not _npc_nodes.has(npc_id):
			skipped_only_temporarily_unavailable = false
			skipped.append({"npc_id": npc_id, "reason": "npc_formal_actor_missing"})
			continue
		if not can_npc_act(npc_id):
			skipped.append({"npc_id": npc_id, "reason": "npc_not_combat_available"})
			continue
		var npc_node := get_node_or_null(_npc_nodes[npc_id]) as Node3D
		var default_formal_resident := _default_formal_world_npcs.has(npc_id)
		var preserved_entry_position: Variant = entry_world_positions.get(npc_id)
		if default_formal_resident and npc_node != null and preserved_entry_position is Vector3:
			# Workstation/seat cleanup may choose an authored stand point. Entering
			# the combat world is only an authority handoff, so retain the physical
			# body's exact pre-transition position.
			npc_node.global_position = preserved_entry_position
		var initial_position: Variant = npc_node.global_position if default_formal_resident and npc_node != null else controller.get_npc_initial_world_position(npc_id)
		if (
			npc_node == null
			or not initial_position is Vector3
			or not npc_node.has_method("configure_navigation_motion")
		):
			skipped_only_temporarily_unavailable = false
			skipped.append({"npc_id": npc_id, "reason": "npc_formal_anchor_missing"})
			continue
		var original_navigation_enabled := false
		if npc_node.has_method("is_navigation_motion_enabled"):
			original_navigation_enabled = bool(npc_node.is_navigation_motion_enabled())
		var original_navigation_map: RID = npc_node.get_navigation_map() if npc_node.has_method("get_navigation_map") else RID()
		_formal_combat_world_npcs[npc_id] = {
			"original_position": npc_node.global_position,
			"original_navigation_enabled": original_navigation_enabled,
			"original_navigation_map": original_navigation_map,
			"formal_initial_position": initial_position,
			"navigation_map": navigation_map,
			"default_formal_resident": default_formal_resident,
			"started_at_msec": Time.get_ticks_msec()
		}
		_cancel_building_interior_route(npc_id, true)
		_movement_arrival_contexts.erase(npc_id)
		if npc_node.has_method("detach_from_spatial_anchor"):
			npc_node.detach_from_spatial_anchor()
		_stop_npc_movement(npc_id)
		if not default_formal_resident:
			npc_node.global_position = initial_position
		if not bool(npc_node.configure_navigation_motion(true, navigation_map)):
			skipped_only_temporarily_unavailable = false
			var failed_state: Dictionary = _formal_combat_world_npcs[npc_id]
			if bool(failed_state.get("original_navigation_enabled", false)):
				npc_node.configure_navigation_motion(true, failed_state.get("original_navigation_map", RID()))
			npc_node.global_position = failed_state.get("original_position", npc_node.global_position)
			_formal_combat_world_npcs.erase(npc_id)
			skipped.append({"npc_id": npc_id, "reason": "npc_navigation_map_bind_failed"})
			continue
		_set_npc_state_without_signal(npc_id, {
			"movement_target": "",
			"movement_target_name": "",
			"spatial_route_phase": "formal_combat_world_ready",
			"physical_location_phase": "formal_combat_world",
			"reserved_building_id": "",
			"reserved_workstation_id": "",
			"current_workstation_id": ""
		})
		_refresh_npc_node(npc_id)
		_emit_npc_state_changed(npc_id)
		migrated.append(npc_id)
	return {
		# A wave may legitimately start while every NPC is unconscious or otherwise
		# unable to act. That is a valid empty migration, unlike a missing anchor or
		# a failed navigation-map bind.
		"ok": not migrated.is_empty() or npc_ids.is_empty() or skipped_only_temporarily_unavailable,
		"active": not _formal_combat_world_npcs.is_empty(),
		"requested_count": npc_ids.size(),
		"migrated_count": migrated.size(),
		"migrated_npc_ids": migrated,
		"skipped": skipped,
		"snapshot": get_formal_combat_world_snapshot()
	}


func end_formal_combat_world(
	reason: String = "combat_ended",
	preserve_npc_ids: Array[String] = []
) -> Dictionary:
	var restored: Array[String] = []
	var preserved: Array[String] = []
	for raw_npc_id in _formal_combat_world_npcs.keys().duplicate():
		var npc_id := str(raw_npc_id)
		if preserve_npc_ids.has(npc_id):
			preserved.append(npc_id)
			continue
		var migration: Dictionary = _formal_combat_world_npcs.get(npc_id, {})
		var keep_formal_resident := bool(migration.get("default_formal_resident", false)) and _default_formal_world_npcs.has(npc_id)
		var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) as Node3D if _npc_nodes.has(npc_id) else null
		_cancel_building_interior_route(npc_id, true)
		_movement_arrival_contexts.erase(npc_id)
		_stop_npc_movement(npc_id)
		if npc_node != null:
			if npc_node.has_method("detach_from_spatial_anchor"):
				npc_node.detach_from_spatial_anchor()
			if keep_formal_resident and npc_node.has_method("configure_navigation_motion"):
				var resident: Dictionary = _default_formal_world_npcs.get(npc_id, {})
				npc_node.configure_navigation_motion(true, resident.get("navigation_map", RID()))
			elif npc_node.has_method("configure_navigation_motion"):
				if bool(migration.get("original_navigation_enabled", false)):
					npc_node.configure_navigation_motion(true, migration.get("original_navigation_map", RID()))
				else:
					npc_node.configure_navigation_motion(false)
			# Legacy actors return to their pre-combat compatibility space. Default
			# formal residents already share the production world/map and must keep
			# their battle-end position; their resumed plan supplies the next route.
			var original_position: Variant = migration.get("original_position")
			if not keep_formal_resident and original_position is Vector3:
				npc_node.global_position = original_position
		_set_npc_state_without_signal(npc_id, {
			"movement_target": "",
			"movement_target_name": "",
			"spatial_route_phase": "default_formal_world_after_combat" if keep_formal_resident else "formal_combat_world_restored",
			"physical_location_phase": "formal_world_resident" if keep_formal_resident else "legacy_location",
			"last_action_result": "formal_combat_world_%s" % reason
		})
		_refresh_npc_node(npc_id)
		_emit_npc_state_changed(npc_id)
		restored.append(npc_id)
		_formal_combat_world_npcs.erase(npc_id)
	return {
		"ok": true,
		"active": not _formal_combat_world_npcs.is_empty(),
		"reason": reason,
		"restored_count": restored.size(),
		"restored_npc_ids": restored,
		"preserved_count": preserved.size(),
		"preserved_npc_ids": preserved
	}


func get_formal_combat_world_snapshot() -> Dictionary:
	var actors: Array[Dictionary] = []
	for raw_npc_id in _formal_combat_world_npcs.keys():
		var npc_id := str(raw_npc_id)
		var migration: Dictionary = _formal_combat_world_npcs.get(npc_id, {})
		var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) if _npc_nodes.has(npc_id) else null
		var motion: Dictionary = {}
		if npc_node != null and npc_node.has_method("debug_get_motion_snapshot"):
			motion = npc_node.debug_get_motion_snapshot()
		var expected_map: RID = migration.get("navigation_map", RID())
		var actual_map: RID = npc_node.get_navigation_map() if npc_node != null and npc_node.has_method("get_navigation_map") else RID()
		actors.append({
			"npc_id": npc_id,
			"world_position": npc_node.global_position if npc_node is Node3D else Vector3.ZERO,
			"original_position": migration.get("original_position", Vector3.ZERO),
			"navigation_motion_enabled": bool(npc_node.is_navigation_motion_enabled()) if npc_node != null and npc_node.has_method("is_navigation_motion_enabled") else false,
			"navigation_map_matches": expected_map.is_valid() and actual_map == expected_map,
			"body_collision_layer": int(motion.get("body_collision_layer", 0)),
			"body_collision_mask": int(motion.get("body_collision_mask", 0)),
			"motion": motion
		})
	return {
		"ok": true,
		"active": not _formal_combat_world_npcs.is_empty(),
		"actor_count": actors.size(),
		"npc_ids": _formal_combat_world_npcs.keys(),
		"actors": actors
	}


func is_npc_in_formal_combat_world(npc_id: String) -> bool:
	return _formal_combat_world_npcs.has(npc_id)


func can_npc_move_to_world_position(npc_id: String, arrival_state: Dictionary = {}) -> bool:
	if not _profiles.has(npc_id):
		return false
	var allow_escaping_movement := bool(arrival_state.get("allow_escaping_movement", false))
	if not can_npc_act(npc_id):
		if not allow_escaping_movement:
			return false
		var state := get_npc_state(npc_id)
		if (
			bool(state.get("unconscious", false))
			or bool(state.get("escaped", false))
			or bool(state.get("first_sleep_summary_active", false))
		):
			return false
	if not _npc_nodes.has(npc_id):
		return false
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	return npc_node != null and npc_node.has_method("move_to_location")


func stop_npc_movement_with_state(npc_id: String, changes: Dictionary = {}) -> bool:
	if not _profiles.has(npc_id):
		return false
	_cancel_building_interior_route(npc_id, true)
	_stop_npc_movement(npc_id)
	_movement_arrival_contexts.erase(npc_id)
	if not changes.is_empty():
		_set_npc_state_without_signal(npc_id, changes)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func is_npc_world_movement_active(npc_id: String) -> bool:
	if not _npc_nodes.has(npc_id):
		return false
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	return (
		npc_node != null
		and npc_node.has_method("is_world_movement_active")
		and bool(npc_node.is_world_movement_active())
	)


func get_npc_world_movement_progress(npc_id: String) -> Dictionary:
	if not _npc_nodes.has(npc_id):
		return {}
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("get_motion_progress_snapshot"):
		return {}
	return npc_node.get_motion_progress_snapshot()


func update_npc_world_movement_target(
	npc_id: String,
	target_position: Vector3,
	state_changes: Dictionary = {}
) -> bool:
	if not _npc_nodes.has(npc_id):
		return false
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("update_motion_target") or not is_npc_world_movement_active(npc_id):
		return false
	var updated := bool(npc_node.update_motion_target(target_position, "combat_target_moved"))
	if not updated:
		return false
	if _movement_arrival_contexts.has(npc_id):
		var context := _movement_arrival_contexts[npc_id] as Dictionary
		context["target_position"] = target_position
		_movement_arrival_contexts[npc_id] = context
	if not state_changes.is_empty():
		_set_npc_state_without_signal(npc_id, state_changes)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func get_npc_navigation_closest_point(npc_id: String, world_position: Vector3) -> Variant:
	if not _npc_nodes.has(npc_id):
		return null
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("get_navigation_map"):
		return null
	var navigation_map: RID = npc_node.get_navigation_map()
	if not navigation_map.is_valid():
		return null
	return NavigationServer3D.map_get_closest_point(navigation_map, world_position)


func cancel_spatial_route_for_incapacitation(npc_id: String, reason: String) -> bool:
	if not _profiles.has(npc_id):
		return false
	_cancel_building_interior_route(npc_id, true)
	_movement_arrival_contexts.erase(npc_id)
	var state := get_npc_state(npc_id)
	_set_npc_state_without_signal(npc_id, {
		"movement_target": "",
		"movement_target_name": "",
		"spatial_route_phase": reason,
		"physical_location_phase": "interior" if str(state.get("current_location", "")) == FIRST_SPATIAL_INTERIOR_BUILDING_ID else "outdoor_path",
		"reserved_building_id": "",
		"reserved_workstation_id": "",
		"current_workstation_id": ""
	})
	_refresh_npc_node(npc_id)
	return true


func debug_move_npc_to_building(npc_id: String, building_id: String) -> bool:
	if _is_gameplay_paused_for_debug_movement():
		push_warning("Cannot start GM NPC movement while gameplay is paused. Resume time and retry.")
		return false
	return move_npc_to_building(npc_id, building_id)


func debug_move_selected_npc_to_building(building_id: String) -> bool:
	if _selected_npc_id.is_empty():
		push_warning("Cannot move selected NPC because no NPC is selected.")
		return false
	return debug_move_npc_to_building(_selected_npc_id, building_id)


func begin_formal_workstation_action(
	npc_id: String,
	action_id: String,
	building_id: String,
	preserve_current_location: bool = false
) -> Dictionary:
	if not _profiles.has(npc_id) or not _npc_nodes.has(npc_id):
		return {"ok": false, "reason": "npc_missing", "npc_id": npc_id}
	if not can_npc_act(npc_id):
		return {"ok": false, "reason": "npc_cannot_act", "npc_id": npc_id}
	if _formal_workstation_action_sessions.has(npc_id):
		var existing: Dictionary = _formal_workstation_action_sessions[npc_id]
		if str(existing.get("action_id", "")) == action_id and str(existing.get("building_id", "")) == building_id:
			return {
				"ok": true,
				"already_active": true,
				"npc_id": npc_id,
				"action_id": action_id,
				"building_id": building_id,
				"session": existing.duplicate(true)
			}
		end_formal_workstation_action(npc_id, "superseded", true)

	debug_stop_all_formal_navigation_pilots("superseded_by_formal_work")
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if (
		controller == null
		or npc_node == null
		or not controller.has_method("debug_set_preview_enabled")
		or not controller.has_method("get_production_navigation_map_rid")
		or not controller.has_method("get_npc_initial_world_position")
		or not controller.has_method("get_building_spatial_route")
		or not npc_node.has_method("configure_navigation_motion")
	):
		return {"ok": false, "reason": "formal_work_dependencies_missing", "npc_id": npc_id}

	var original_state := get_npc_state(npc_id)
	var original_location_id := str(original_state.get("current_location", PLAZA_LOCATION_ID))
	var default_formal_resident := _default_formal_world_npcs.has(npc_id)
	var preserve_existing_location := preserve_current_location or default_formal_resident
	var formal_start_location_id := original_location_id if preserve_existing_location else PLAZA_LOCATION_ID
	var initial_position: Variant = npc_node.global_position if default_formal_resident else controller.get_npc_initial_world_position(npc_id)
	if preserve_existing_location and not default_formal_resident and formal_start_location_id != PLAZA_LOCATION_ID:
		var current_route: Dictionary = controller.get_building_spatial_route(formal_start_location_id)
		if current_route.is_empty() or not current_route.get("interior_target_position") is Vector3:
			return {
				"ok": false,
				"reason": "formal_current_location_unavailable",
				"npc_id": npc_id,
				"location_id": formal_start_location_id
			}
		initial_position = current_route.get("interior_target_position")
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not initial_position is Vector3 or not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_navigation_unavailable", "npc_id": npc_id}
	var preview_snapshot: Dictionary = controller.debug_set_preview_enabled(true)
	if not bool(preview_snapshot.get("preview_enabled", false)):
		return {"ok": false, "reason": "formal_preview_unavailable", "npc_id": npc_id}

	_formal_workstation_action_session_sequence += 1
	_formal_workstation_action_sessions[npc_id] = {
		"npc_id": npc_id,
		"session_id": _formal_workstation_action_session_sequence,
		"action_id": action_id,
		"building_id": building_id,
		"workstation_id": "",
		"original_position": npc_node.global_position,
		"original_navigation_enabled": bool(npc_node.is_navigation_motion_enabled()) if npc_node.has_method("is_navigation_motion_enabled") else false,
		"original_navigation_map": npc_node.get_navigation_map() if npc_node.has_method("get_navigation_map") else RID(),
		"original_location_id": original_location_id,
		"formal_start_location_id": formal_start_location_id,
		"default_formal_resident": default_formal_resident,
		"started_at_msec": Time.get_ticks_msec()
	}
	_cancel_building_interior_route(npc_id, true)
	_movement_arrival_contexts.erase(npc_id)
	if not preserve_existing_location:
		if not debug_enter_location_immediately(npc_id, PLAZA_LOCATION_ID):
			end_formal_workstation_action(npc_id, "plaza_reset_failed", true)
			return {"ok": false, "reason": "formal_work_plaza_reset_failed", "npc_id": npc_id}
	else:
		_set_npc_state_without_signal(npc_id, {
			"current_action": "idle",
			"movement_target": "",
			"movement_target_name": ""
		})
	if not default_formal_resident:
		npc_node.global_position = initial_position
	if not bool(npc_node.configure_navigation_motion(true, navigation_map)):
		end_formal_workstation_action(npc_id, "navigation_map_bind_failed", true)
		return {"ok": false, "reason": "navigation_map_bind_failed", "npc_id": npc_id}
	_set_npc_state_without_signal(npc_id, {
		"spatial_route_phase": "formal_work_ready",
		"physical_location_phase": "formal_location_interior" if formal_start_location_id != PLAZA_LOCATION_ID else "formal_work_outdoor",
		"reserved_building_id": "",
		"reserved_workstation_id": "",
		"current_workstation_id": ""
	})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"already_active": false,
		"npc_id": npc_id,
		"action_id": action_id,
		"building_id": building_id,
		"initial_position": initial_position,
		"preview_enabled": true
	}


func begin_formal_location_action(npc_id: String, action_id: String, building_id: String) -> Dictionary:
	return begin_formal_workstation_action(npc_id, action_id, building_id, true)


func begin_formal_building_exterior_action(
	npc_id: String,
	action_id: String,
	building_id: String,
	service_kind: String = "repair"
) -> Dictionary:
	var begin_result := begin_formal_location_action(npc_id, action_id, building_id)
	if not bool(begin_result.get("ok", false)):
		return begin_result
	var session: Dictionary = _formal_workstation_action_sessions.get(npc_id, {})
	if not str(session.get("service_slot_id", "")).is_empty():
		begin_result["service_slot"] = {
			"slot_id": str(session.get("service_slot_id", "")),
			"position": session.get("service_target_position"),
			"facing_direction": session.get("service_facing_direction", Vector3.ZERO),
		}
		return begin_result
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null or not controller.has_method("get_building_exterior_service_slots"):
		end_formal_location_action(npc_id, "exterior_service_provider_missing")
		return {"ok": false, "reason": "formal_exterior_service_provider_missing", "npc_id": npc_id}
	var occupied_slot_ids := {}
	for raw_other_npc_id in _formal_workstation_action_sessions.keys():
		var other_npc_id := str(raw_other_npc_id)
		if other_npc_id == npc_id:
			continue
		var other_session: Dictionary = _formal_workstation_action_sessions.get(other_npc_id, {})
		if str(other_session.get("building_id", "")) != building_id:
			continue
		var occupied_slot_id := str(other_session.get("service_slot_id", ""))
		if not occupied_slot_id.is_empty():
			occupied_slot_ids[occupied_slot_id] = true
	var selected_slot: Dictionary = {}
	var selected_distance_squared: float = INF
	var npc_node := get_node_or_null(_npc_nodes[npc_id]) as Node3D if _npc_nodes.has(npc_id) else null
	for raw_slot in controller.get_building_exterior_service_slots(building_id, service_kind):
		if not raw_slot is Dictionary:
			continue
		var slot: Dictionary = raw_slot
		if occupied_slot_ids.has(str(slot.get("slot_id", ""))):
			continue
		var slot_position: Variant = slot.get("position")
		if not slot_position is Vector3:
			continue
		var distance_squared: float = (
			npc_node.global_position.distance_squared_to(slot_position)
			if npc_node != null
			else float(selected_slot.size())
		)
		if distance_squared >= selected_distance_squared:
			continue
		selected_distance_squared = distance_squared
		selected_slot = slot.duplicate(true)
	if selected_slot.is_empty() or not selected_slot.get("position") is Vector3:
		end_formal_location_action(npc_id, "no_exterior_service_slot")
		return {
			"ok": false,
			"reason": "formal_exterior_service_slot_unavailable",
			"npc_id": npc_id,
			"building_id": building_id,
		}
	session["service_kind"] = service_kind
	session["service_slot_id"] = str(selected_slot.get("slot_id", ""))
	session["service_target_position"] = selected_slot.get("position")
	session["service_facing_direction"] = selected_slot.get("facing_direction", Vector3.ZERO)
	session["service_route_started"] = false
	_formal_workstation_action_sessions[npc_id] = session
	begin_result["service_slot"] = selected_slot
	return begin_result


func move_npc_to_formal_building_exterior(npc_id: String) -> bool:
	if not _formal_workstation_action_sessions.has(npc_id):
		return false
	var session: Dictionary = _formal_workstation_action_sessions[npc_id]
	if not session.get("service_target_position") is Vector3:
		return false
	var state := get_npc_state(npc_id)
	if (
		str(state.get("physical_location_phase", "")) == "building_exterior_service"
		and str(state.get("formal_exterior_slot_id", "")) == str(session.get("service_slot_id", ""))
	):
		return true
	var current_location_id := str(state.get("current_location", PLAZA_LOCATION_ID))
	if current_location_id != PLAZA_LOCATION_ID:
		var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		var exit_route: Dictionary = (
			controller.get_building_spatial_route(current_location_id)
			if controller != null and controller.has_method("get_building_spatial_route")
			else {}
		)
		if exit_route.is_empty():
			return false
		session["continue_to_exterior_after_exit"] = true
		_formal_workstation_action_sessions[npc_id] = session
		return _start_building_exit_route(
			npc_id,
			PLAZA_LOCATION_ID,
			current_location_id,
			exit_route
		)
	return _start_formal_exterior_service_route(npc_id)


func _start_formal_exterior_service_route(npc_id: String) -> bool:
	if not _formal_workstation_action_sessions.has(npc_id):
		return false
	var session: Dictionary = _formal_workstation_action_sessions[npc_id]
	var target_position: Variant = session.get("service_target_position")
	if not target_position is Vector3:
		return false
	var building_id := str(session.get("building_id", ""))
	var service_slot_id := str(session.get("service_slot_id", ""))
	var service_kind := str(session.get("service_kind", "service"))
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var building_name := building_id
	if building_system != null and building_system.has_method("get_building"):
		building_name = str(building_system.get_building(building_id).get("name", building_id))
	var service_point_name := (
		"%s外施工点" % building_name
		if service_kind == "upgrade"
		else "%s外维修点" % building_name
	)
	session["continue_to_exterior_after_exit"] = false
	session["service_route_started"] = true
	_formal_workstation_action_sessions[npc_id] = session
	return move_npc_to_world_position(
		npc_id,
		building_id,
		service_point_name,
		target_position,
		{
			"current_action": "idle",
			"current_location": PLAZA_LOCATION_ID,
			"current_location_name": "广场",
			"preserve_location_context": true,
			"spatial_route_phase": "exterior_service_arrived",
			"physical_location_phase": "building_exterior_service",
			"formal_exterior_building_id": building_id,
			"formal_exterior_service_kind": service_kind,
			"formal_exterior_slot_id": service_slot_id,
			"arrival_facing_direction": session.get("service_facing_direction", Vector3.ZERO),
			"last_action_result": "formal_exterior_service_arrived",
		}
	)


func move_npc_to_formal_location(npc_id: String, building_id: String) -> bool:
	if not _formal_workstation_action_sessions.has(npc_id):
		return false
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null or not controller.has_method("get_building_spatial_route"):
		return false
	var state := get_npc_state(npc_id)
	var current_location_id := str(state.get("current_location", PLAZA_LOCATION_ID))
	if current_location_id != PLAZA_LOCATION_ID and current_location_id != building_id:
		var exit_route: Dictionary = controller.get_building_spatial_route(current_location_id)
		if exit_route.is_empty():
			return false
		return _start_building_exit_route(
			npc_id,
			building_id,
			current_location_id,
			exit_route
		)
	if building_id == PLAZA_LOCATION_ID:
		return _start_formal_public_location_route(npc_id, PLAZA_LOCATION_ID)
	var formal_route: Dictionary = controller.get_building_spatial_route(building_id)
	if formal_route.is_empty():
		return false
	return _start_building_entry_route(npc_id, building_id, "", formal_route)


func _start_formal_public_location_route(npc_id: String, location_id: String) -> bool:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if (
		controller == null
		or not controller.has_method("get_public_location_world_position")
	):
		return false
	var target_position: Variant = controller.get_public_location_world_position(location_id)
	if not target_position is Vector3:
		return false
	return move_npc_to_world_position(npc_id, location_id, "广场", target_position, {
		"current_action": "idle",
		"current_location": location_id,
		"current_location_name": "广场",
		"spatial_route_phase": "public_location_arrived",
		"physical_location_phase": "formal_public_location",
		"last_action_result": "formal_public_location_arrived"
	})


func end_formal_location_action(
	npc_id: String,
	reason: String = "stopped",
	preserve_location_id: String = "",
	emit_state_changed: bool = true
) -> Dictionary:
	return end_formal_workstation_action(npc_id, reason, true, preserve_location_id, emit_state_changed)


func end_formal_workstation_action(
	npc_id: String,
	reason: String = "stopped",
	restore_legacy: bool = true,
	legacy_location_override: String = "",
	emit_state_changed: bool = true
) -> Dictionary:
	if not _formal_workstation_action_sessions.has(npc_id):
		return {"ok": true, "active": false, "npc_id": npc_id, "reason": reason}
	var session: Dictionary = _formal_workstation_action_sessions[npc_id]
	_formal_workstation_action_sessions.erase(npc_id)
	var keep_formal_resident := _default_formal_world_npcs.has(npc_id)
	var should_restore_legacy := restore_legacy and not keep_formal_resident
	var healing_target_npc_id := str(session.get("healing_target_npc_id", ""))
	if not healing_target_npc_id.is_empty():
		_release_formal_healing_target_projection(npc_id, healing_target_npc_id)
	_cancel_building_interior_route(npc_id, true)
	_movement_arrival_contexts.erase(npc_id)
	_stop_npc_movement(npc_id)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var building_id := str(session.get("building_id", ""))
	var workstation_id := str(session.get("workstation_id", ""))
	if building_system != null and not building_id.is_empty() and not workstation_id.is_empty():
		if building_system.has_method("release_workstation_reservation"):
			building_system.release_workstation_reservation(building_id, npc_id, workstation_id)
		if building_system.has_method("release_workstation"):
			building_system.release_workstation(building_id, npc_id, workstation_id)
	var npc_node := get_node_or_null(_npc_nodes[npc_id]) if _npc_nodes.has(npc_id) else null
	if npc_node != null:
		if npc_node.has_method("detach_from_spatial_anchor"):
			npc_node.detach_from_spatial_anchor()
		if keep_formal_resident:
			# Mounted beds, chairs and benches disable the Body at their display
			# anchor. Return to the audited stand point before collision is restored.
			if not building_id.is_empty() and not workstation_id.is_empty():
				var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
				var safe_route: Dictionary = (
					controller.get_building_spatial_route(building_id, workstation_id)
					if controller != null and controller.has_method("get_building_spatial_route")
					else {}
				)
				var safe_position: Variant = safe_route.get("interior_target_position")
				if safe_position is Vector3:
					npc_node.global_position = safe_position
			var resident: Dictionary = _default_formal_world_npcs.get(npc_id, {})
			var resident_map: RID = resident.get("navigation_map", RID())
			if npc_node.has_method("configure_navigation_motion") and resident_map.is_valid():
				npc_node.configure_navigation_motion(true, resident_map)
		elif npc_node.has_method("configure_navigation_motion"):
			npc_node.configure_navigation_motion(false)
		if should_restore_legacy:
			var restore_position: Variant = session.get("original_position")
			if (
				not legacy_location_override.is_empty()
				and building_system != null
				and building_system.has_method("get_building_entry_position")
			):
				var override_position: Variant = building_system.get_building_entry_position(legacy_location_override)
				if override_position is Vector3:
					restore_position = override_position
			if restore_position is Vector3:
				npc_node.global_position = restore_position
	if should_restore_legacy:
		var restored_location_id := (
			legacy_location_override
			if not legacy_location_override.is_empty()
			else str(session.get("original_location_id", PLAZA_LOCATION_ID))
		)
		if not debug_enter_location_immediately(npc_id, restored_location_id, false):
			debug_enter_location_immediately(npc_id, PLAZA_LOCATION_ID, false)
	var resident_location_id := str(get_npc_state(npc_id).get("current_location", PLAZA_LOCATION_ID))
	_set_npc_state_without_signal(npc_id, {
		"movement_target": "",
		"movement_target_name": "",
		"spatial_route_phase": ("default_formal_resident_%s" if keep_formal_resident else "formal_work_%s") % reason,
		"physical_location_phase": (
			"formal_location_interior"
			if keep_formal_resident and resident_location_id != PLAZA_LOCATION_ID
			else ("formal_public_location" if keep_formal_resident else ("legacy_location" if should_restore_legacy else "formal_work_stopped"))
		),
		"reserved_building_id": "",
		"reserved_workstation_id": "",
		"current_workstation_id": "",
		"formal_exterior_building_id": "",
		"formal_exterior_service_kind": "",
		"formal_exterior_slot_id": "",
		"formal_healing_target_npc_id": "",
		"presentation_clinic_duty_mode": "",
		"presentation_clinic_patient_id": ""
	})
	_refresh_npc_node(npc_id)
	if emit_state_changed:
		_emit_npc_state_changed(npc_id)
	_maybe_disable_formal_preview()
	return {
		"ok": true,
		"active": false,
		"npc_id": npc_id,
		"action_id": str(session.get("action_id", "")),
		"building_id": building_id,
		"workstation_id": workstation_id,
		"reason": reason,
		"restored_legacy": should_restore_legacy,
		"kept_default_formal_resident": keep_formal_resident,
		"restored_location_id": (
			legacy_location_override
			if should_restore_legacy and not legacy_location_override.is_empty()
			else (resident_location_id if keep_formal_resident else str(session.get("original_location_id", PLAZA_LOCATION_ID)))
		)
	}


func get_formal_workstation_action_snapshot(npc_id: String = "") -> Dictionary:
	if not npc_id.is_empty():
		return {
			"active": _formal_workstation_action_sessions.has(npc_id),
			"npc_id": npc_id,
			"session": (_formal_workstation_action_sessions.get(npc_id, {}) as Dictionary).duplicate(true),
			"spatial": debug_get_spatial_migration_snapshot(npc_id)
		}
	var sessions := {}
	for raw_npc_id in _formal_workstation_action_sessions.keys():
		var active_npc_id := str(raw_npc_id)
		sessions[active_npc_id] = get_formal_workstation_action_snapshot(active_npc_id)
	return {"active": not sessions.is_empty(), "npc_ids": sessions.keys(), "sessions": sessions}


func begin_formal_healing_approach(
	healer_npc_id: String,
	target_npc_id: String,
	action_id: String,
	approach_distance: float = 1.25,
	max_helpers: int = 2
) -> Dictionary:
	if (
		healer_npc_id.is_empty()
		or target_npc_id.is_empty()
		or healer_npc_id == target_npc_id
		or not _profiles.has(healer_npc_id)
		or not _profiles.has(target_npc_id)
	):
		return {"ok": false, "reason": "invalid_healing_participants"}
	var target_state := get_npc_state(target_npc_id)
	if not bool(target_state.get("unconscious", false)) or bool(target_state.get("escaped", false)):
		return {"ok": false, "reason": "healing_target_unavailable", "target_npc_id": target_npc_id}
	if _formal_workstation_action_sessions.has(healer_npc_id):
		var existing: Dictionary = _formal_workstation_action_sessions[healer_npc_id]
		if (
			str(existing.get("action_id", "")) == action_id
			and str(existing.get("healing_target_npc_id", "")) == target_npc_id
		):
			return {"ok": true, "already_active": true, "session": existing.duplicate(true)}
		end_formal_workstation_action(healer_npc_id, "healing_target_replaced", true)
	var committed_healers := 0
	for raw_other_healer_id in _formal_workstation_action_sessions.keys():
		var other_session: Dictionary = _formal_workstation_action_sessions[raw_other_healer_id]
		if (
			str(other_session.get("action_id", "")) == action_id
			and str(other_session.get("healing_target_npc_id", "")) == target_npc_id
		):
			committed_healers += 1
	if committed_healers >= maxi(1, max_helpers):
		return {"ok": false, "reason": "healing_target_helper_limit", "target_npc_id": target_npc_id}
	var target_location_id := str(target_state.get("current_location", PLAZA_LOCATION_ID))
	var begin_result := begin_formal_location_action(healer_npc_id, action_id, target_location_id)
	if not bool(begin_result.get("ok", false)):
		return begin_result
	var projection_result := _acquire_formal_healing_target_projection(healer_npc_id, target_npc_id)
	if not bool(projection_result.get("ok", false)):
		end_formal_location_action(healer_npc_id, "healing_target_projection_failed")
		return projection_result
	var session: Dictionary = _formal_workstation_action_sessions.get(healer_npc_id, {})
	session["healing_target_npc_id"] = target_npc_id
	session["healing_target_location_id"] = target_location_id
	# Healing follows the casualty's physical body, not the semantic location that
	# was current before a battle. Combat keeps unconscious residents where they
	# fell, so routing through that old building first can strand the healer at a
	# doorway or send them away from the patient entirely.
	session["healing_direct_world_route"] = true
	_formal_workstation_action_sessions[healer_npc_id] = session
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var healer_position: Variant = get_npc_world_position(healer_npc_id)
	var target_position: Variant = get_npc_world_position(target_npc_id)
	var navigation_map: RID = (
		controller.get_production_navigation_map_rid()
		if controller != null and controller.has_method("get_production_navigation_map_rid")
		else RID()
	)
	if not healer_position is Vector3 or not target_position is Vector3 or not navigation_map.is_valid():
		end_formal_location_action(healer_npc_id, "healing_approach_dependencies_missing")
		return {"ok": false, "reason": "healing_approach_dependencies_missing"}
	var excluded_positions: Array = []
	for raw_other_healer_id in _formal_workstation_action_sessions.keys():
		var other_healer_id := str(raw_other_healer_id)
		if other_healer_id == healer_npc_id:
			continue
		var other_session: Dictionary = _formal_workstation_action_sessions[other_healer_id]
		if str(other_session.get("healing_target_npc_id", "")) != target_npc_id:
			continue
		var occupied_position: Variant = other_session.get("healing_approach_position")
		if occupied_position is Vector3:
			excluded_positions.append(occupied_position)
	_append_formal_healing_occupied_positions(excluded_positions, healer_npc_id, target_npc_id, target_position)
	var clean_distance := clampf(approach_distance, 1.0, 1.8)
	var approach_position: Variant = _find_formal_dialogue_approach_position(
		navigation_map,
		healer_position,
		target_position,
		clean_distance,
		excluded_positions
	)
	session = _formal_workstation_action_sessions.get(healer_npc_id, {})
	session["healing_approach_distance"] = clean_distance
	if approach_position is Vector3:
		session["healing_approach_position"] = approach_position
	session["healing_route_started"] = false
	_formal_workstation_action_sessions[healer_npc_id] = session
	begin_result["target_npc_id"] = target_npc_id
	begin_result["target_location_id"] = target_location_id
	begin_result["target_world_position"] = target_position
	begin_result["approach_position"] = approach_position
	begin_result["approach_distance"] = clean_distance
	begin_result["direct_world_route"] = true
	return begin_result


func move_npc_to_formal_healing_target(healer_npc_id: String, target_npc_id: String) -> Dictionary:
	if not _formal_workstation_action_sessions.has(healer_npc_id):
		return {"ok": false, "reason": "formal_healing_session_missing"}
	var session: Dictionary = _formal_workstation_action_sessions[healer_npc_id]
	if str(session.get("healing_target_npc_id", "")) != target_npc_id:
		return {"ok": false, "reason": "formal_healing_target_mismatch"}
	var target_state := get_npc_state(target_npc_id)
	if not bool(target_state.get("unconscious", false)) or bool(target_state.get("escaped", false)):
		return {"ok": false, "reason": "healing_target_unavailable"}
	var approach_position: Variant = session.get("healing_approach_position")
	var target_position: Variant = get_npc_world_position(target_npc_id)
	if not target_position is Vector3:
		return {"ok": false, "reason": "formal_healing_world_position_missing"}
	if not approach_position is Vector3:
		var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		var healer_position: Variant = get_npc_world_position(healer_npc_id)
		var navigation_map: RID = (
			controller.get_production_navigation_map_rid()
			if controller != null and controller.has_method("get_production_navigation_map_rid")
			else RID()
		)
		if not healer_position is Vector3 or not navigation_map.is_valid():
			return {"ok": false, "reason": "formal_healing_navigation_map_missing"}
		var excluded_positions: Array = []
		for raw_other_healer_id in _formal_workstation_action_sessions.keys():
			var other_healer_id := str(raw_other_healer_id)
			if other_healer_id == healer_npc_id:
				continue
			var other_session: Dictionary = _formal_workstation_action_sessions[other_healer_id]
			if str(other_session.get("healing_target_npc_id", "")) != target_npc_id:
				continue
			var occupied_position: Variant = other_session.get("healing_approach_position")
			if occupied_position is Vector3:
				excluded_positions.append(occupied_position)
		_append_formal_healing_occupied_positions(excluded_positions, healer_npc_id, target_npc_id, target_position)
		approach_position = _find_formal_dialogue_approach_position(
			navigation_map,
			healer_position,
			target_position,
			float(session.get("healing_approach_distance", 1.25)),
			excluded_positions
		)
		if not approach_position is Vector3:
			return {"ok": false, "reason": "healing_approach_position_unreachable"}
		session["healing_approach_position"] = approach_position
		_formal_workstation_action_sessions[healer_npc_id] = session
	var target_location_id := str(session.get("healing_target_location_id", PLAZA_LOCATION_ID))
	var facing_direction: Vector3 = target_position - approach_position
	facing_direction.y = 0.0
	if facing_direction.length_squared() > 0.0001:
		facing_direction = facing_direction.normalized()
	session["healing_route_started"] = true
	_formal_workstation_action_sessions[healer_npc_id] = session
	var crowd_recovery_active := bool(session.get("healing_crowd_recovery_active", false))
	var moved := move_npc_to_world_position(
		healer_npc_id,
		"healing_target_%s" % target_npc_id,
		str(get_npc(target_npc_id).get("name", target_npc_id)),
		approach_position,
		{
			"current_action": "idle",
			"current_location": target_location_id,
			"current_location_name": str(target_state.get("current_location_name", target_location_id)),
			"preserve_location_context": true,
			"spatial_route_phase": "healing_approach_arrived",
			"physical_location_phase": "formal_healing_approach",
			"formal_healing_target_npc_id": target_npc_id,
			"arrival_facing_direction": facing_direction,
			"last_action_result": "formal_healing_approach_arrived",
			"departure_state": {
				"spatial_route_phase": "formal_healing_approach_moving",
				"physical_location_phase": "formal_healing_world_route"
			}
		},
		{"healing_crowd_recovery": true} if crowd_recovery_active else {}
	)
	return {
		"ok": moved,
		"reason": "" if moved else "formal_healing_approach_start_failed",
		"target_npc_id": target_npc_id,
		"target_world_position": target_position,
		"approach_position": approach_position
	}


func retry_formal_healing_approach(healer_npc_id: String, target_npc_id: String) -> Dictionary:
	if not _formal_workstation_action_sessions.has(healer_npc_id):
		return {"ok": false, "reason": "formal_healing_session_missing"}
	var session: Dictionary = _formal_workstation_action_sessions[healer_npc_id]
	if str(session.get("healing_target_npc_id", "")) != target_npc_id:
		return {"ok": false, "reason": "formal_healing_target_mismatch"}
	var retry_count := int(session.get("healing_route_retry_count", 0))
	if retry_count >= 3:
		return {"ok": false, "reason": "formal_healing_retry_limit", "retry_count": retry_count}
	var healer_position: Variant = get_npc_world_position(healer_npc_id)
	var target_position: Variant = get_npc_world_position(target_npc_id)
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var navigation_map: RID = (
		controller.get_production_navigation_map_rid()
		if controller != null and controller.has_method("get_production_navigation_map_rid")
		else RID()
	)
	if not healer_position is Vector3 or not target_position is Vector3 or not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_healing_retry_dependencies_missing"}
	var excluded_positions: Array = (
		(session.get("healing_failed_approach_positions", []) as Array).duplicate()
		if session.get("healing_failed_approach_positions", []) is Array
		else []
	)
	var failed_position: Variant = session.get("healing_approach_position")
	if failed_position is Vector3:
		excluded_positions.append(failed_position)
	for raw_other_healer_id in _formal_workstation_action_sessions.keys():
		var other_healer_id := str(raw_other_healer_id)
		if other_healer_id == healer_npc_id:
			continue
		var other_session: Dictionary = _formal_workstation_action_sessions[other_healer_id]
		if str(other_session.get("healing_target_npc_id", "")) != target_npc_id:
			continue
		var occupied_position: Variant = other_session.get("healing_approach_position")
		if occupied_position is Vector3:
			excluded_positions.append(occupied_position)
	_append_formal_healing_occupied_positions(excluded_positions, healer_npc_id, target_npc_id, target_position)
	var approach_position: Variant = _find_formal_dialogue_approach_position(
		navigation_map,
		healer_position,
		target_position,
		float(session.get("healing_approach_distance", 1.25)),
		excluded_positions
	)
	if not approach_position is Vector3:
		return {"ok": false, "reason": "healing_retry_position_unreachable", "retry_count": retry_count}
	retry_count += 1
	session["healing_failed_approach_positions"] = excluded_positions
	session["healing_approach_position"] = approach_position
	session["healing_route_retry_count"] = retry_count
	session["healing_route_started"] = false
	# A retry is only entered after the normal RVO/capsule route has genuinely
	# stalled. Let this one healer pass through actor capsules while retaining
	# world/navmesh collision, so a post-battle crowd cannot make a valid rescue
	# command permanently impossible.
	session["healing_crowd_recovery_active"] = true
	_formal_workstation_action_sessions[healer_npc_id] = session
	var move_result := move_npc_to_formal_healing_target(healer_npc_id, target_npc_id)
	# Movement startup refreshes the actor from authoritative state, which restores
	# its ordinary RVO setting. Apply the bounded recovery override afterwards.
	if bool(move_result.get("ok", false)):
		_set_healing_crowd_recovery_enabled(healer_npc_id, true)
	move_result["retried"] = true
	move_result["retry_count"] = retry_count
	return move_result


func _append_formal_healing_occupied_positions(
	excluded_positions: Array,
	healer_npc_id: String,
	target_npc_id: String,
	_target_position: Vector3
) -> void:
	for raw_npc_id in _npc_order:
		var npc_id := str(raw_npc_id)
		if npc_id == healer_npc_id or npc_id == target_npc_id:
			continue
		var occupied_position: Variant = get_npc_world_position(npc_id)
		if not occupied_position is Vector3:
			continue
		excluded_positions.append(occupied_position)


func _set_healing_crowd_recovery_enabled(npc_id: String, enabled: bool) -> void:
	var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) if _npc_nodes.has(npc_id) else null
	if npc_node == null:
		return
	if npc_node.has_method("set_runtime_actor_collision_enabled"):
		npc_node.set_runtime_actor_collision_enabled(not enabled, "formal_healing_crowd_recovery" if enabled else "")
	if npc_node.has_method("set_runtime_avoidance_enabled"):
		npc_node.set_runtime_avoidance_enabled(not enabled, "formal_healing_crowd_recovery" if enabled else "")


func _restore_healing_crowd_recovery_from_movement_context(npc_id: String, context: Dictionary) -> void:
	var motion_options: Dictionary = context.get("motion_options", {}) if context.get("motion_options", {}) is Dictionary else {}
	if not bool(motion_options.get("healing_crowd_recovery", false)):
		return
	_set_healing_crowd_recovery_enabled(npc_id, false)
	if _formal_workstation_action_sessions.has(npc_id):
		var session: Dictionary = _formal_workstation_action_sessions[npc_id]
		session["healing_crowd_recovery_active"] = false
		_formal_workstation_action_sessions[npc_id] = session


func is_formal_healing_approach_ready(healer_npc_id: String, target_npc_id: String) -> bool:
	if not _formal_workstation_action_sessions.has(healer_npc_id):
		return false
	var session: Dictionary = _formal_workstation_action_sessions[healer_npc_id]
	if str(session.get("healing_target_npc_id", "")) != target_npc_id:
		return false
	var healer_state := get_npc_state(healer_npc_id)
	var target_state := get_npc_state(target_npc_id)
	if (
		str(healer_state.get("physical_location_phase", "")) != "formal_healing_approach"
		or str(healer_state.get("formal_healing_target_npc_id", "")) != target_npc_id
		or str(healer_state.get("current_location", "")) != str(target_state.get("current_location", ""))
		or not bool(target_state.get("unconscious", false))
		or bool(target_state.get("escaped", false))
	):
		return false
	var healer_position: Variant = get_npc_world_position(healer_npc_id)
	var target_position: Variant = get_npc_world_position(target_npc_id)
	if not healer_position is Vector3 or not target_position is Vector3:
		return false
	var horizontal_distance := Vector2(
		healer_position.x - target_position.x,
		healer_position.z - target_position.z
	).length()
	var desired_distance := float(session.get("healing_approach_distance", 1.25))
	return horizontal_distance >= 0.8 and horizontal_distance <= desired_distance + 0.45


func end_formal_healing_approach(
	healer_npc_id: String,
	reason: String = "stopped",
	emit_state_changed: bool = true
) -> Dictionary:
	_set_healing_crowd_recovery_enabled(healer_npc_id, false)
	if not _formal_workstation_action_sessions.has(healer_npc_id):
		return {"ok": true, "active": false, "healer_npc_id": healer_npc_id}
	var session: Dictionary = _formal_workstation_action_sessions[healer_npc_id]
	var target_location_id := str(session.get(
		"healing_target_location_id",
		get_npc_state(healer_npc_id).get("current_location", PLAZA_LOCATION_ID)
	))
	return end_formal_location_action(healer_npc_id, reason, target_location_id, emit_state_changed)


func get_formal_healing_approach_snapshot(healer_npc_id: String = "") -> Dictionary:
	if not healer_npc_id.is_empty():
		var formal_snapshot := get_formal_workstation_action_snapshot(healer_npc_id)
		var session: Dictionary = formal_snapshot.get("session", {}) if formal_snapshot.get("session", {}) is Dictionary else {}
		var target_npc_id := str(session.get("healing_target_npc_id", ""))
		return {
			"active": bool(formal_snapshot.get("active", false)) and not target_npc_id.is_empty(),
			"healer_npc_id": healer_npc_id,
			"target_npc_id": target_npc_id,
			"session": session.duplicate(true),
			"ready": is_formal_healing_approach_ready(healer_npc_id, target_npc_id) if not target_npc_id.is_empty() else false,
			"healer_world_position": get_npc_world_position(healer_npc_id),
			"target_world_position": get_npc_world_position(target_npc_id) if not target_npc_id.is_empty() else null,
			"target_projection": (_formal_healing_target_projections.get(target_npc_id, {}) as Dictionary).duplicate(true) if _formal_healing_target_projections.has(target_npc_id) else {}
		}
	var sessions := {}
	for raw_healer_id in _formal_workstation_action_sessions.keys():
		var active_healer_id := str(raw_healer_id)
		var active_session: Dictionary = _formal_workstation_action_sessions[active_healer_id]
		if str(active_session.get("healing_target_npc_id", "")).is_empty():
			continue
		sessions[active_healer_id] = get_formal_healing_approach_snapshot(active_healer_id)
	return {"active": not sessions.is_empty(), "sessions": sessions}


func _acquire_formal_healing_target_projection(healer_npc_id: String, target_npc_id: String) -> Dictionary:
	if _formal_healing_target_projections.has(target_npc_id):
		var existing: Dictionary = _formal_healing_target_projections[target_npc_id]
		var healer_ids: Array = existing.get("healer_ids", []) if existing.get("healer_ids", []) is Array else []
		if not healer_ids.has(healer_npc_id):
			healer_ids.append(healer_npc_id)
		existing["healer_ids"] = healer_ids
		_formal_healing_target_projections[target_npc_id] = existing
		return {"ok": true, "projection": existing.duplicate(true)}
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var target_node := get_node_or_null(_npc_nodes.get(target_npc_id, NodePath())) if _npc_nodes.has(target_npc_id) else null
	if (
		controller == null
		or target_node == null
		or not controller.has_method("get_production_navigation_map_rid")
		or not target_node.has_method("configure_navigation_motion")
	):
		return {"ok": false, "reason": "formal_healing_target_dependencies_missing"}
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_healing_navigation_map_missing"}
	var target_state := get_npc_state(target_npc_id)
	var target_location_id := str(target_state.get("current_location", PLAZA_LOCATION_ID))
	var target_already_formal: bool = (
		_formal_workstation_action_sessions.has(target_npc_id)
		or _formal_combat_world_npcs.has(target_npc_id)
		or _default_formal_world_npcs.has(target_npc_id)
		or (
			target_node.has_method("is_navigation_motion_enabled")
			and bool(target_node.is_navigation_motion_enabled())
			and target_node.has_method("get_navigation_map")
			and target_node.get_navigation_map() == navigation_map
		)
	)
	var projection := {
		"target_npc_id": target_npc_id,
		"target_location_id": target_location_id,
		"healer_ids": [healer_npc_id],
		"owned": not target_already_formal,
		"target_mode": "existing_formal_actor" if target_already_formal else "projected_static_actor"
	}
	if target_already_formal:
		projection["target_world_position"] = target_node.global_position
		_formal_healing_target_projections[target_npc_id] = projection
		return {"ok": true, "projection": projection.duplicate(true)}
	var target_position: Variant = null
	if target_location_id == PLAZA_LOCATION_ID and controller.has_method("get_public_location_world_position"):
		target_position = controller.get_public_location_world_position(PLAZA_LOCATION_ID)
	elif controller.has_method("get_building_spatial_route"):
		var target_route: Dictionary = controller.get_building_spatial_route(target_location_id)
		target_position = target_route.get("interior_target_position")
		var door_inside_position: Variant = target_route.get("door_inside_position")
		if target_position is Vector3 and door_inside_position is Vector3:
			var interior_depth: Vector3 = target_position - door_inside_position
			interior_depth.y = 0.0
			if interior_depth.length_squared() > 0.01:
				# The generic interior marker sits directly behind the doorway. A prone
				# body there would physically block every healer entering the room.
				target_position += interior_depth.normalized() * 1.8
	if not target_position is Vector3:
		return {"ok": false, "reason": "formal_healing_target_anchor_missing", "target_location_id": target_location_id}
	var snapped_target := NavigationServer3D.map_get_closest_point(navigation_map, target_position)
	projection["original_position"] = target_node.global_position
	projection["original_navigation_enabled"] = bool(target_node.is_navigation_motion_enabled()) if target_node.has_method("is_navigation_motion_enabled") else false
	projection["original_navigation_map"] = target_node.get_navigation_map() if target_node.has_method("get_navigation_map") else RID()
	projection["original_spatial_route_phase"] = str(target_state.get("spatial_route_phase", "none"))
	projection["original_physical_location_phase"] = str(target_state.get("physical_location_phase", "legacy_location"))
	projection["target_world_position"] = snapped_target
	if not bool(target_node.configure_navigation_motion(true, navigation_map)):
		return {"ok": false, "reason": "formal_healing_target_navigation_bind_failed"}
	target_node.global_position = snapped_target
	_set_npc_state_without_signal(target_npc_id, {
		"spatial_route_phase": "formal_healing_target_ready",
		"physical_location_phase": "formal_healing_target"
	})
	_refresh_npc_node(target_npc_id)
	_formal_healing_target_projections[target_npc_id] = projection
	return {"ok": true, "projection": projection.duplicate(true)}


func _release_formal_healing_target_projection(healer_npc_id: String, target_npc_id: String) -> void:
	if target_npc_id.is_empty() or not _formal_healing_target_projections.has(target_npc_id):
		return
	var projection: Dictionary = _formal_healing_target_projections[target_npc_id]
	var healer_ids: Array = projection.get("healer_ids", []) if projection.get("healer_ids", []) is Array else []
	healer_ids.erase(healer_npc_id)
	if not healer_ids.is_empty():
		projection["healer_ids"] = healer_ids
		_formal_healing_target_projections[target_npc_id] = projection
		return
	_formal_healing_target_projections.erase(target_npc_id)
	if not bool(projection.get("owned", false)):
		return
	var target_node := get_node_or_null(_npc_nodes.get(target_npc_id, NodePath())) if _npc_nodes.has(target_npc_id) else null
	if target_node == null or str(get_npc_state(target_npc_id).get("physical_location_phase", "")) != "formal_healing_target":
		return
	if target_node.has_method("configure_navigation_motion"):
		if bool(projection.get("original_navigation_enabled", false)):
			target_node.configure_navigation_motion(true, projection.get("original_navigation_map", RID()))
		else:
			target_node.configure_navigation_motion(false)
	var original_position: Variant = projection.get("original_position")
	if original_position is Vector3:
		target_node.global_position = original_position
	_set_npc_state_without_signal(target_npc_id, {
		"spatial_route_phase": str(projection.get("original_spatial_route_phase", "none")),
		"physical_location_phase": str(projection.get("original_physical_location_phase", "legacy_location"))
	})
	_refresh_npc_node(target_npc_id)


func begin_formal_dialogue_approach(
	speaker_npc_id: String,
	target_npc_id: String,
	action_id: String
) -> Dictionary:
	if (
		speaker_npc_id.is_empty()
		or target_npc_id.is_empty()
		or speaker_npc_id == target_npc_id
		or not _profiles.has(speaker_npc_id)
		or not _profiles.has(target_npc_id)
	):
		return {"ok": false, "reason": "invalid_dialogue_participants"}
	if _formal_dialogue_approach_sessions.has(speaker_npc_id):
		var existing: Dictionary = _formal_dialogue_approach_sessions[speaker_npc_id]
		if str(existing.get("target_npc_id", "")) == target_npc_id:
			return {"ok": true, "already_active": true, "session": existing.duplicate(true)}
		end_formal_dialogue_approach(speaker_npc_id, "dialogue_target_replaced")
	for raw_speaker_id in _formal_dialogue_approach_sessions.keys():
		var other: Dictionary = _formal_dialogue_approach_sessions[raw_speaker_id]
		if [str(other.get("speaker_npc_id", "")), str(other.get("target_npc_id", ""))].has(speaker_npc_id):
			return {"ok": false, "reason": "speaker_already_in_formal_dialogue"}
		if [str(other.get("speaker_npc_id", "")), str(other.get("target_npc_id", ""))].has(target_npc_id):
			return {"ok": false, "reason": "target_already_in_formal_dialogue"}
	var target_state := get_npc_state(target_npc_id)
	var target_location_id := str(target_state.get("current_location", PLAZA_LOCATION_ID))
	var begin_result := begin_formal_location_action(
		speaker_npc_id,
		action_id,
		target_location_id
	)
	if not bool(begin_result.get("ok", false)):
		return begin_result
	_formal_dialogue_approach_sessions[speaker_npc_id] = {
		"speaker_npc_id": speaker_npc_id,
		"target_npc_id": target_npc_id,
		"target_location_id": target_location_id,
		"dialogue_id": "",
		"target_migration": {},
		"started_at_msec": Time.get_ticks_msec()
	}
	var sync_result := sync_formal_dialogue_target(speaker_npc_id)
	if not bool(sync_result.get("ok", false)) and str(sync_result.get("reason", "")) != "target_legacy_movement_active":
		end_formal_dialogue_approach(speaker_npc_id, "target_projection_failed")
		return sync_result
	return {
		"ok": true,
		"already_active": false,
		"speaker_npc_id": speaker_npc_id,
		"target_npc_id": target_npc_id,
		"target_location_id": target_location_id,
		"target_ready": bool(sync_result.get("ok", false)),
		"session": (_formal_dialogue_approach_sessions[speaker_npc_id] as Dictionary).duplicate(true)
	}


func sync_formal_dialogue_target(speaker_npc_id: String) -> Dictionary:
	if not _formal_dialogue_approach_sessions.has(speaker_npc_id):
		return {"ok": false, "reason": "formal_dialogue_session_missing"}
	var session: Dictionary = _formal_dialogue_approach_sessions[speaker_npc_id]
	var target_npc_id := str(session.get("target_npc_id", ""))
	if not _profiles.has(target_npc_id) or not _npc_nodes.has(target_npc_id):
		return {"ok": false, "reason": "target_actor_missing"}
	var target_state := get_npc_state(target_npc_id)
	var target_location_id := str(target_state.get("current_location", PLAZA_LOCATION_ID))
	var current_action := str(target_state.get("current_action", ""))
	var migration: Dictionary = session.get("target_migration", {}) if session.get("target_migration", {}) is Dictionary else {}
	if not migration.is_empty() and current_action.begins_with("moving_to_"):
		_restore_formal_dialogue_target_actor(session, true)
		session = _formal_dialogue_approach_sessions.get(speaker_npc_id, session)
		session["target_location_id"] = target_location_id
		_formal_dialogue_approach_sessions[speaker_npc_id] = session
		return {"ok": false, "reason": "target_legacy_movement_active", "target_location_id": target_location_id}
	if _formal_workstation_action_sessions.has(target_npc_id):
		if not migration.is_empty():
			_restore_formal_dialogue_target_actor(session, false)
		session = _formal_dialogue_approach_sessions.get(speaker_npc_id, session)
		session["target_location_id"] = target_location_id
		session["target_mode"] = "existing_formal_actor"
		_formal_dialogue_approach_sessions[speaker_npc_id] = session
		return {
			"ok": true,
			"target_mode": "existing_formal_actor",
			"target_location_id": target_location_id,
			"target_world_position": get_npc_world_position(target_npc_id)
		}
	if current_action.begins_with("moving_to_"):
		session["target_location_id"] = target_location_id
		_formal_dialogue_approach_sessions[speaker_npc_id] = session
		return {"ok": false, "reason": "target_legacy_movement_active", "target_location_id": target_location_id}
	if not migration.is_empty() and str(migration.get("projected_location_id", "")) == target_location_id:
		return {
			"ok": true,
			"target_mode": "projected_static_actor",
			"target_location_id": target_location_id,
			"target_world_position": get_npc_world_position(target_npc_id)
		}
	if not migration.is_empty():
		_restore_formal_dialogue_target_actor(session, false)
		session = _formal_dialogue_approach_sessions.get(speaker_npc_id, session)
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var target_node := get_node_or_null(_npc_nodes[target_npc_id])
	if (
		controller == null
		or target_node == null
		or not controller.has_method("get_production_navigation_map_rid")
		or not target_node.has_method("configure_navigation_motion")
	):
		return {"ok": false, "reason": "formal_dialogue_target_dependencies_missing"}
	var target_position: Variant = null
	if target_location_id == PLAZA_LOCATION_ID and controller.has_method("get_public_location_world_position"):
		target_position = controller.get_public_location_world_position(PLAZA_LOCATION_ID)
	elif controller.has_method("get_building_spatial_route"):
		var target_route: Dictionary = controller.get_building_spatial_route(target_location_id)
		target_position = target_route.get("interior_target_position")
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not target_position is Vector3 or not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_dialogue_target_anchor_missing", "target_location_id": target_location_id}
	var snapped_target := NavigationServer3D.map_get_closest_point(navigation_map, target_position)
	var original_navigation_enabled := bool(target_node.is_navigation_motion_enabled()) if target_node.has_method("is_navigation_motion_enabled") else false
	var original_navigation_map: RID = target_node.get_navigation_map() if target_node.has_method("get_navigation_map") else RID()
	migration = {
		"owned": true,
		"source": "legacy_static_projection",
		"original_position": target_node.global_position,
		"original_navigation_enabled": original_navigation_enabled,
		"original_navigation_map": original_navigation_map,
		"original_spatial_route_phase": str(target_state.get("spatial_route_phase", "none")),
		"original_physical_location_phase": str(target_state.get("physical_location_phase", "legacy_location")),
		"projected_location_id": target_location_id
	}
	if not bool(target_node.configure_navigation_motion(true, navigation_map)):
		return {"ok": false, "reason": "formal_dialogue_target_navigation_bind_failed"}
	target_node.global_position = snapped_target
	_set_npc_state_without_signal(target_npc_id, {
		"spatial_route_phase": "formal_dialogue_target_ready",
		"physical_location_phase": "formal_dialogue_target"
	})
	_refresh_npc_node(target_npc_id)
	session["target_location_id"] = target_location_id
	session["target_mode"] = "projected_static_actor"
	session["target_migration"] = migration
	_formal_dialogue_approach_sessions[speaker_npc_id] = session
	return {
		"ok": true,
		"target_mode": "projected_static_actor",
		"target_location_id": target_location_id,
		"target_world_position": snapped_target
	}


func move_npc_to_formal_dialogue_target(
	speaker_npc_id: String,
	target_npc_id: String,
	approach_distance: float
) -> Dictionary:
	var sync_result := sync_formal_dialogue_target(speaker_npc_id)
	if not bool(sync_result.get("ok", false)):
		return sync_result
	if str((_formal_dialogue_approach_sessions.get(speaker_npc_id, {}) as Dictionary).get("target_npc_id", "")) != target_npc_id:
		return {"ok": false, "reason": "formal_dialogue_target_mismatch"}
	var speaker_position: Variant = get_npc_world_position(speaker_npc_id)
	var target_position: Variant = get_npc_world_position(target_npc_id)
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if not speaker_position is Vector3 or not target_position is Vector3 or controller == null:
		return {"ok": false, "reason": "formal_dialogue_world_position_missing"}
	var navigation_map: RID = controller.get_production_navigation_map_rid() if controller.has_method("get_production_navigation_map_rid") else RID()
	if not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_dialogue_navigation_map_missing"}
	var clean_distance := clampf(approach_distance, 1.0, 2.0)
	var approach_position: Variant = _find_formal_dialogue_approach_position(
		navigation_map,
		speaker_position,
		target_position,
		clean_distance
	)
	if approach_position == null:
		return {"ok": false, "reason": "formal_dialogue_approach_position_unreachable"}
	var speaker_state := get_npc_state(speaker_npc_id)
	var moved := move_npc_to_world_position(
		speaker_npc_id,
		"dialogue_target_%s" % target_npc_id,
		str(get_npc(target_npc_id).get("name", target_npc_id)),
		approach_position,
		{
			"current_action": "idle",
			"current_location": str(speaker_state.get("current_location", PLAZA_LOCATION_ID)),
			"current_location_name": str(speaker_state.get("current_location_name", "广场")),
			"spatial_route_phase": "dialogue_approach_arrived",
			"physical_location_phase": "formal_dialogue_approach",
			"last_action_result": "formal_dialogue_approach_arrived",
			"preserve_location_context": true
		}
	)
	return {
		"ok": moved,
		"reason": "" if moved else "formal_dialogue_approach_start_failed",
		"approach_position": approach_position,
		"target_world_position": target_position,
		"approach_distance": clean_distance
	}


func face_formal_dialogue_participants(speaker_npc_id: String, target_npc_id: String) -> void:
	var speaker_node := get_node_or_null(_npc_nodes.get(speaker_npc_id, NodePath())) if _npc_nodes.has(speaker_npc_id) else null
	var target_node := get_node_or_null(_npc_nodes.get(target_npc_id, NodePath())) if _npc_nodes.has(target_npc_id) else null
	if speaker_node == null or target_node == null:
		return
	var direction: Vector3 = target_node.global_position - speaker_node.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return
	if speaker_node.has_method("set_facing_direction"):
		speaker_node.set_facing_direction(direction.normalized())
	if target_node.has_method("set_facing_direction"):
		target_node.set_facing_direction(-direction.normalized())


func face_formal_dialogue_speaker(speaker_npc_id: String, target_npc_id: String) -> bool:
	var speaker_position: Variant = get_npc_world_position(speaker_npc_id)
	var target_position: Variant = get_npc_world_position(target_npc_id)
	if not speaker_position is Vector3 or not target_position is Vector3:
		return false
	return set_npc_facing_direction(speaker_npc_id, target_position - speaker_position)


func bind_formal_dialogue_session(speaker_npc_id: String, dialogue_id: String) -> Dictionary:
	if not _formal_dialogue_approach_sessions.has(speaker_npc_id) or dialogue_id.is_empty():
		return {"ok": false, "reason": "formal_dialogue_session_missing"}
	var session: Dictionary = _formal_dialogue_approach_sessions[speaker_npc_id]
	session["dialogue_id"] = dialogue_id
	_formal_dialogue_approach_sessions[speaker_npc_id] = session
	return {"ok": true, "session": session.duplicate(true)}


func stage_formal_dialogue_acceptance(dialogue_id: String) -> Dictionary:
	var speaker_npc_id := _find_formal_dialogue_speaker_by_dialogue_id(dialogue_id)
	if speaker_npc_id.is_empty():
		return {"ok": true, "active": false}
	var session: Dictionary = _formal_dialogue_approach_sessions[speaker_npc_id]
	var target_npc_id := str(session.get("target_npc_id", ""))
	if not _formal_workstation_action_sessions.has(target_npc_id):
		return {"ok": true, "active": true, "staged_target_action": false}
	var target_node := get_node_or_null(_npc_nodes.get(target_npc_id, NodePath())) if _npc_nodes.has(target_npc_id) else null
	if target_node == null:
		return {"ok": false, "reason": "formal_dialogue_target_transfer_dependencies_missing"}
	session["acceptance_handoff"] = {
		"target_world_position": target_node.global_position,
		"work_session": (_formal_workstation_action_sessions[target_npc_id] as Dictionary).duplicate(true)
	}
	_formal_dialogue_approach_sessions[speaker_npc_id] = session
	return {"ok": true, "active": true, "staged_target_action": true}


func prepare_formal_dialogue_activation(dialogue_id: String) -> Dictionary:
	var speaker_npc_id := _find_formal_dialogue_speaker_by_dialogue_id(dialogue_id)
	if speaker_npc_id.is_empty():
		return {"ok": true, "active": false}
	var session: Dictionary = _formal_dialogue_approach_sessions[speaker_npc_id]
	var target_npc_id := str(session.get("target_npc_id", ""))
	var acceptance_handoff: Dictionary = session.get("acceptance_handoff", {}) if session.get("acceptance_handoff", {}) is Dictionary else {}
	if not acceptance_handoff.is_empty():
		if _formal_workstation_action_sessions.has(target_npc_id):
			return {"ok": false, "reason": "formal_dialogue_target_action_not_interrupted"}
		var target_node := get_node_or_null(_npc_nodes.get(target_npc_id, NodePath())) if _npc_nodes.has(target_npc_id) else null
		var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		if target_node == null or controller == null or not controller.has_method("get_production_navigation_map_rid"):
			return {"ok": false, "reason": "formal_dialogue_target_transfer_dependencies_missing"}
		var navigation_map: RID = controller.get_production_navigation_map_rid()
		if not bool(target_node.configure_navigation_motion(true, navigation_map)):
			return {"ok": false, "reason": "formal_dialogue_target_transfer_navigation_failed"}
		var current_position: Variant = acceptance_handoff.get("target_world_position")
		if current_position is Vector3:
			target_node.global_position = current_position
		var work_session: Dictionary = acceptance_handoff.get("work_session", {}) if acceptance_handoff.get("work_session", {}) is Dictionary else {}
		session["target_migration"] = {
			"owned": true,
			"source": "formal_action_transfer",
			"original_position": work_session.get("original_position", target_node.global_position),
			"original_navigation_enabled": bool(work_session.get("original_navigation_enabled", false)),
			"original_navigation_map": work_session.get("original_navigation_map", RID()),
			"original_spatial_route_phase": "none",
			"original_physical_location_phase": "legacy_location",
			"projected_location_id": str(get_npc_state(target_npc_id).get("current_location", PLAZA_LOCATION_ID))
		}
		session["target_mode"] = "transferred_formal_actor"
		session.erase("acceptance_handoff")
		_formal_dialogue_approach_sessions[speaker_npc_id] = session
		face_formal_dialogue_participants(speaker_npc_id, target_npc_id)
		return {"ok": true, "active": true, "transferred_target": true}
	if not _formal_workstation_action_sessions.has(target_npc_id):
		face_formal_dialogue_participants(speaker_npc_id, target_npc_id)
		return {"ok": true, "active": true, "transferred_target": false}
	var target_node := get_node_or_null(_npc_nodes.get(target_npc_id, NodePath())) if _npc_nodes.has(target_npc_id) else null
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if target_node == null or controller == null or not controller.has_method("get_production_navigation_map_rid"):
		return {"ok": false, "reason": "formal_dialogue_target_transfer_dependencies_missing"}
	var work_session: Dictionary = _formal_workstation_action_sessions[target_npc_id]
	var current_position: Vector3 = target_node.global_position
	var target_state := get_npc_state(target_npc_id)
	var migration := {
		"owned": true,
		"source": "formal_action_transfer",
		"original_position": work_session.get("original_position", current_position),
		"original_navigation_enabled": bool(work_session.get("original_navigation_enabled", false)),
		"original_navigation_map": work_session.get("original_navigation_map", RID()),
		"original_spatial_route_phase": "none",
		"original_physical_location_phase": "legacy_location",
		"projected_location_id": str(target_state.get("current_location", PLAZA_LOCATION_ID))
	}
	end_formal_workstation_action(target_npc_id, "formal_dialogue_activation_transfer", false)
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not bool(target_node.configure_navigation_motion(true, navigation_map)):
		return {"ok": false, "reason": "formal_dialogue_target_transfer_navigation_failed"}
	target_node.global_position = current_position
	session["target_migration"] = migration
	session["target_mode"] = "transferred_formal_actor"
	_formal_dialogue_approach_sessions[speaker_npc_id] = session
	face_formal_dialogue_participants(speaker_npc_id, target_npc_id)
	return {"ok": true, "active": true, "transferred_target": true}


func end_formal_dialogue_by_id(dialogue_id: String, reason: String = "dialogue_ended") -> Dictionary:
	var speaker_npc_id := _find_formal_dialogue_speaker_by_dialogue_id(dialogue_id)
	if speaker_npc_id.is_empty():
		return {"ok": true, "active": false, "dialogue_id": dialogue_id}
	return end_formal_dialogue_approach(speaker_npc_id, reason)


func end_formal_dialogue_approach(
	speaker_npc_id: String,
	reason: String = "stopped",
	emit_state_changed: bool = true
) -> Dictionary:
	if not _formal_dialogue_approach_sessions.has(speaker_npc_id):
		return {"ok": true, "active": false, "speaker_npc_id": speaker_npc_id}
	var session: Dictionary = _formal_dialogue_approach_sessions[speaker_npc_id]
	_formal_dialogue_approach_sessions.erase(speaker_npc_id)
	_restore_formal_dialogue_target_actor(session, false)
	var speaker_location_id := str(get_npc_state(speaker_npc_id).get("current_location", PLAZA_LOCATION_ID))
	if speaker_location_id.begins_with("dialogue_target_"):
		# A same-frame stop can observe the synthetic movement target after the
		# arrival signal but before formal cleanup. Restore a real information
		# location instead of publishing the synthetic id as a building.
		speaker_location_id = str(session.get("target_location_id", PLAZA_LOCATION_ID))
	_set_npc_state_without_signal(speaker_npc_id, {
		"current_action": "idle",
		"movement_target": "",
		"movement_target_name": ""
	})
	end_formal_location_action(speaker_npc_id, reason, speaker_location_id, emit_state_changed)
	_maybe_disable_formal_preview()
	return {
		"ok": true,
		"active": false,
		"speaker_npc_id": speaker_npc_id,
		"target_npc_id": str(session.get("target_npc_id", "")),
		"dialogue_id": str(session.get("dialogue_id", "")),
		"reason": reason
	}


func get_formal_dialogue_approach_snapshot(npc_id: String = "") -> Dictionary:
	if not npc_id.is_empty():
		if _formal_dialogue_approach_sessions.has(npc_id):
			return {"active": true, "role": "speaker", "session": (_formal_dialogue_approach_sessions[npc_id] as Dictionary).duplicate(true)}
		for raw_speaker_id in _formal_dialogue_approach_sessions.keys():
			var session: Dictionary = _formal_dialogue_approach_sessions[raw_speaker_id]
			if str(session.get("target_npc_id", "")) == npc_id:
				return {"active": true, "role": "target", "session": session.duplicate(true)}
		return {"active": false, "npc_id": npc_id}
	var sessions := {}
	for raw_speaker_id in _formal_dialogue_approach_sessions.keys():
		sessions[str(raw_speaker_id)] = (_formal_dialogue_approach_sessions[raw_speaker_id] as Dictionary).duplicate(true)
	return {"active": not sessions.is_empty(), "sessions": sessions}


func _find_formal_dialogue_speaker_by_dialogue_id(dialogue_id: String) -> String:
	if dialogue_id.is_empty():
		return ""
	for raw_speaker_id in _formal_dialogue_approach_sessions.keys():
		var speaker_npc_id := str(raw_speaker_id)
		var session: Dictionary = _formal_dialogue_approach_sessions[speaker_npc_id]
		if str(session.get("dialogue_id", "")) == dialogue_id:
			return speaker_npc_id
	return ""


func _restore_formal_dialogue_target_actor(session: Dictionary, resume_legacy_movement: bool) -> void:
	var speaker_npc_id := str(session.get("speaker_npc_id", ""))
	var target_npc_id := str(session.get("target_npc_id", ""))
	var migration: Dictionary = session.get("target_migration", {}) if session.get("target_migration", {}) is Dictionary else {}
	if migration.is_empty() or not bool(migration.get("owned", false)):
		return
	var target_node := get_node_or_null(_npc_nodes.get(target_npc_id, NodePath())) if _npc_nodes.has(target_npc_id) else null
	var movement_target_id := str(get_npc_state(target_npc_id).get("movement_target", ""))
	if target_node != null:
		if target_node.has_method("configure_navigation_motion"):
			if bool(migration.get("original_navigation_enabled", false)):
				target_node.configure_navigation_motion(true, migration.get("original_navigation_map", RID()))
			else:
				target_node.configure_navigation_motion(false)
		var original_position: Variant = migration.get("original_position")
		if original_position is Vector3:
			target_node.global_position = original_position
	_set_npc_state_without_signal(target_npc_id, {
		"spatial_route_phase": str(migration.get("original_spatial_route_phase", "none")),
		"physical_location_phase": str(migration.get("original_physical_location_phase", "legacy_location"))
	})
	_refresh_npc_node(target_npc_id)
	session["target_migration"] = {}
	session["target_mode"] = "legacy_actor"
	if not speaker_npc_id.is_empty() and _formal_dialogue_approach_sessions.has(speaker_npc_id):
		_formal_dialogue_approach_sessions[speaker_npc_id] = session
	if resume_legacy_movement and not movement_target_id.is_empty():
		call_deferred("_resume_formal_dialogue_target_legacy_movement", target_npc_id, movement_target_id)


func _resume_formal_dialogue_target_legacy_movement(npc_id: String, target_location_id: String) -> void:
	if not _profiles.has(npc_id) or target_location_id.is_empty():
		return
	move_npc_to_building(npc_id, target_location_id)


func _find_formal_dialogue_approach_position(
	navigation_map: RID,
	speaker_position: Vector3,
	target_position: Vector3,
	approach_distance: float,
	excluded_positions: Array = []
) -> Variant:
	var base_direction := speaker_position - target_position
	base_direction.y = 0.0
	if base_direction.length_squared() <= 0.0001:
		base_direction = Vector3(0.0, 0.0, 1.0)
	base_direction = base_direction.normalized()
	var best_position: Variant = null
	var best_score := INF
	var snapped_speaker := NavigationServer3D.map_get_closest_point(navigation_map, speaker_position)
	var speaker_region: RID = NavigationServer3D.map_get_closest_point_owner(
		navigation_map,
		snapped_speaker
	)
	for index in range(12):
		var direction := base_direction.rotated(Vector3.UP, TAU * float(index) / 12.0)
		var desired := target_position + direction * approach_distance
		var candidate := NavigationServer3D.map_get_closest_point(navigation_map, desired)
		var separation := Vector2(candidate.x - target_position.x, candidate.z - target_position.z).length()
		if separation < 0.9 or separation > 2.15:
			continue
		var overlaps_reserved_position := false
		for raw_excluded_position in excluded_positions:
			if not raw_excluded_position is Vector3:
				continue
			var excluded_position: Vector3 = raw_excluded_position
			if Vector2(candidate.x - excluded_position.x, candidate.z - excluded_position.z).length() < 0.85:
				overlaps_reserved_position = true
				break
		if overlaps_reserved_position:
			continue
		var path := NavigationServer3D.map_get_path(navigation_map, speaker_position, candidate, true)
		var path_length := 0.0
		if path.is_empty():
			var candidate_region: RID = NavigationServer3D.map_get_closest_point_owner(
				navigation_map,
				candidate
			)
			if not speaker_region.is_valid() or candidate_region != speaker_region:
				continue
			path_length = Vector2(
				candidate.x - speaker_position.x,
				candidate.z - speaker_position.z
			).length()
		else:
			for path_index in range(1, path.size()):
				path_length += path[path_index - 1].distance_to(path[path_index])
		var score := path_length + absf(separation - approach_distance) * 4.0
		if score < best_score:
			best_score = score
			best_position = candidate
	if best_position != null:
		return best_position
	# Public anchors and tight interiors can sit close to a navigation polygon
	# boundary. In that case every radial sample may collapse onto the same edge.
	# The path itself is still authoritative, so walk backwards from its endpoint
	# and choose the point that is approach_distance away from the target.
	var target_path: PackedVector3Array = NavigationServer3D.map_get_path(
		navigation_map,
		speaker_position,
		target_position,
		true
	)
	if target_path.size() < 2:
		return null
	var remaining := approach_distance
	for reverse_index in range(target_path.size() - 1, 0, -1):
		var segment_end: Vector3 = target_path[reverse_index]
		var segment_start: Vector3 = target_path[reverse_index - 1]
		var segment_length := Vector2(
			segment_end.x - segment_start.x,
			segment_end.z - segment_start.z
		).length()
		if segment_length <= 0.001:
			continue
		if segment_length >= remaining:
			var fallback := segment_end.lerp(segment_start, remaining / segment_length)
			fallback = NavigationServer3D.map_get_closest_point(navigation_map, fallback)
			var fallback_separation := Vector2(
				fallback.x - target_position.x,
				fallback.z - target_position.z
			).length()
			var fallback_reserved := false
			for raw_excluded_position in excluded_positions:
				if not raw_excluded_position is Vector3:
					continue
				var excluded_position: Vector3 = raw_excluded_position
				if Vector2(fallback.x - excluded_position.x, fallback.z - excluded_position.z).length() < 0.85:
					fallback_reserved = true
					break
			if fallback_separation >= 0.8 and fallback_separation <= 2.3 and not fallback_reserved:
				return fallback
			return null
		remaining -= segment_length
	return best_position


func attach_formal_workstation_occupant(npc_id: String, building_id: String, workstation_id: String) -> Dictionary:
	if not _formal_workstation_action_sessions.has(npc_id):
		return {"ok": false, "reason": "formal_work_session_missing", "npc_id": npc_id}
	var session: Dictionary = _formal_workstation_action_sessions[npc_id]
	if (
		str(session.get("building_id", "")) != building_id
		or str(session.get("workstation_id", "")) != workstation_id
	):
		return {"ok": false, "reason": "formal_work_session_mismatch", "npc_id": npc_id}
	var state := get_npc_state(npc_id)
	if (
		str(state.get("current_location", "")) != building_id
		or str(state.get("current_workstation_id", "")) != workstation_id
		or str(state.get("physical_location_phase", "")) != "workstation"
	):
		return {"ok": false, "reason": "formal_workstation_not_reached", "npc_id": npc_id}
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null or not controller.has_method("get_building_spatial_route"):
		return {"ok": false, "reason": "formal_route_provider_missing", "npc_id": npc_id}
	var route: Dictionary = controller.get_building_spatial_route(building_id, workstation_id)
	if str(route.get("arrival_mode", "stand")) != "mount_after_arrival":
		return {"ok": false, "reason": "formal_workstation_does_not_mount", "npc_id": npc_id}
	var anchor_position: Variant = route.get("occupant_anchor_position")
	var anchor_facing: Variant = route.get("occupant_anchor_facing_direction", Vector3.ZERO)
	var occupant_pose := str(route.get("occupant_pose", ""))
	var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) if _npc_nodes.has(npc_id) else null
	if (
		npc_node == null
		or not npc_node.has_method("attach_to_spatial_anchor")
		or not anchor_position is Vector3
		or not anchor_facing is Vector3
		or not bool(npc_node.attach_to_spatial_anchor(anchor_position, anchor_facing, occupant_pose))
	):
		return {"ok": false, "reason": "formal_occupant_attachment_failed", "npc_id": npc_id}
	session["attachment_committed"] = true
	_formal_workstation_action_sessions[npc_id] = session
	_set_npc_state_without_signal(npc_id, {
		"spatial_route_phase": "occupant_attached",
		"physical_location_phase": "occupant_anchor",
		"last_action_result": "occupant_attached"
	})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"building_id": building_id,
		"workstation_id": workstation_id,
		"occupant_pose": occupant_pose,
		"anchor_position": anchor_position
	}


func move_formal_clinic_doctor_to_patient_bed(doctor_npc_id: String, patient_npc_id: String) -> Dictionary:
	if not _formal_workstation_action_sessions.has(doctor_npc_id):
		return {"ok": false, "reason": "formal_doctor_session_missing"}
	if not _formal_workstation_action_sessions.has(patient_npc_id):
		return {"ok": false, "reason": "formal_patient_session_missing"}
	var doctor_session: Dictionary = _formal_workstation_action_sessions[doctor_npc_id]
	var patient_session: Dictionary = _formal_workstation_action_sessions[patient_npc_id]
	if (
		str(doctor_session.get("building_id", "")) != CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID
		or str(patient_session.get("building_id", "")) != CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID
	):
		return {"ok": false, "reason": "formal_clinic_session_mismatch"}
	var patient_workstation_id := str(patient_session.get("workstation_id", ""))
	var doctor_workstation_id := str(doctor_session.get("workstation_id", ""))
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null or not controller.has_method("get_building_spatial_route"):
		return {"ok": false, "reason": "formal_route_provider_missing"}
	var patient_route: Dictionary = controller.get_building_spatial_route(
		CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID,
		patient_workstation_id
	)
	var target_position: Variant = patient_route.get("interior_target_position")
	var patient_anchor_position: Variant = patient_route.get("occupant_anchor_position")
	if not target_position is Vector3 or not patient_anchor_position is Vector3:
		return {"ok": false, "reason": "clinic_patient_bedside_anchor_missing"}
	var navigation_target: Vector3 = target_position
	var patient_anchor: Vector3 = patient_anchor_position
	var treatment_side: Vector3 = navigation_target - patient_anchor
	treatment_side.y = 0.0
	if treatment_side.length_squared() <= 0.0001:
		return {"ok": false, "reason": "clinic_patient_bedside_direction_missing"}
	treatment_side = treatment_side.normalized()
	var fixture_collision_size: Variant = patient_route.get("target_fixture_collision_size")
	var fixture_right_direction: Variant = patient_route.get("target_fixture_right_direction")
	var fixture_forward_direction: Variant = patient_route.get("target_fixture_forward_direction")
	if (
		not fixture_collision_size is Vector3
		or not fixture_right_direction is Vector3
		or not fixture_forward_direction is Vector3
	):
		return {"ok": false, "reason": "clinic_patient_bed_collision_contract_missing"}
	var bed_collision_size: Vector3 = fixture_collision_size
	var bed_right_direction: Vector3 = fixture_right_direction
	var bed_forward_direction: Vector3 = fixture_forward_direction
	var bed_half_extent_toward_doctor: float = (
		absf(treatment_side.dot(bed_right_direction)) * bed_collision_size.x * 0.5
		+ absf(treatment_side.dot(bed_forward_direction)) * bed_collision_size.z * 0.5
	)
	var treatment_outward_distance: float = (
		bed_half_extent_toward_doctor
		+ CLINIC_TREATMENT_DOCTOR_BODY_RADIUS
		+ CLINIC_TREATMENT_BED_CLEARANCE
	)
	# Working_A's right hand sweeps toward the character's local-left side. Mirror
	# this small along-bed offset with the selected bedside so the hand lands over
	# the patient's torso from either aisle instead of passing beside the mattress.
	var treatment_lateral_direction := Vector3(-treatment_side.z, 0.0, treatment_side.x)
	var treatment_anchor_position: Vector3 = (
		patient_anchor
		+ treatment_side * treatment_outward_distance
		+ treatment_lateral_direction * CLINIC_TREATMENT_ANCHOR_LATERAL_OFFSET
	)
	treatment_anchor_position.y = navigation_target.y
	var facing_direction: Vector3 = patient_anchor - treatment_anchor_position
	facing_direction.y = 0.0
	facing_direction = facing_direction.normalized()
	_detach_formal_clinic_doctor_for_rounds(doctor_npc_id)
	var patient_name := str(get_npc(patient_npc_id).get("name", patient_npc_id))
	var moved := move_npc_to_world_position(
		doctor_npc_id,
		"clinic_bedside_%s" % patient_npc_id,
		"%s的病床" % patient_name,
		target_position,
		{
			"current_action": "work_clinic_doctor",
			"current_location": CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID,
			"current_location_name": "小诊所",
			"current_workstation_id": doctor_workstation_id,
			"spatial_route_phase": "clinic_round_treatment",
			"physical_location_phase": "clinic_bedside",
			"presentation_clinic_duty_mode": "treatment",
			"presentation_clinic_patient_id": patient_npc_id,
			"last_action_result": "clinic_round_reached_%s" % patient_npc_id,
			"preserve_location_context": true,
			"departure_current_action": "work_clinic_doctor",
			"departure_state": {
				"spatial_route_phase": "clinic_round_travel",
				"physical_location_phase": "clinic_round_path",
				"presentation_clinic_duty_mode": "travel",
				"presentation_clinic_patient_id": patient_npc_id
			},
			"arrival_facing_direction": facing_direction,
			"attach_clinic_treatment_on_arrival": true,
			"clinic_treatment_anchor_position": treatment_anchor_position,
			"clinic_treatment_anchor_facing_direction": facing_direction
		}
	)
	return {
		"ok": moved,
		"reason": "" if moved else "clinic_round_movement_rejected",
		"doctor_npc_id": doctor_npc_id,
		"patient_npc_id": patient_npc_id,
		"patient_workstation_id": patient_workstation_id,
		"target_position": target_position,
		"treatment_anchor_position": treatment_anchor_position,
		"treatment_outward_distance": treatment_outward_distance,
		"bed_half_extent_toward_doctor": bed_half_extent_toward_doctor
	}


func move_formal_clinic_doctor_to_study_seat(doctor_npc_id: String) -> Dictionary:
	if not _formal_workstation_action_sessions.has(doctor_npc_id):
		return {"ok": false, "reason": "formal_doctor_session_missing"}
	var session: Dictionary = _formal_workstation_action_sessions[doctor_npc_id]
	if str(session.get("building_id", "")) != CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID:
		return {"ok": false, "reason": "formal_clinic_session_mismatch"}
	var workstation_id := str(session.get("workstation_id", ""))
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null or not controller.has_method("get_building_spatial_route"):
		return {"ok": false, "reason": "formal_route_provider_missing"}
	var study_route: Dictionary = controller.get_building_spatial_route(
		CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID,
		workstation_id
	)
	var target_position: Variant = study_route.get("interior_target_position")
	var facing_direction: Variant = study_route.get("interior_target_facing_direction", Vector3.ZERO)
	if (
		str(study_route.get("arrival_mode", "stand")) != "mount_after_arrival"
		or not target_position is Vector3
		or not facing_direction is Vector3
	):
		return {"ok": false, "reason": "clinic_study_seat_anchor_missing"}
	_detach_formal_clinic_doctor_for_rounds(doctor_npc_id)
	var moved := move_npc_to_world_position(
		doctor_npc_id,
		"clinic_study_%s" % workstation_id,
		"医生书桌",
		target_position,
		{
			"current_action": "work_clinic_doctor",
			"current_location": CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID,
			"current_location_name": "小诊所",
			"current_workstation_id": workstation_id,
			"spatial_route_phase": "clinic_study_seat_arrival",
			"physical_location_phase": "workstation",
			"presentation_clinic_duty_mode": "study",
			"presentation_clinic_patient_id": "",
			"last_action_result": "clinic_study_seat_reached",
			"preserve_location_context": true,
			"departure_current_action": "work_clinic_doctor",
			"departure_state": {
				"spatial_route_phase": "clinic_study_return_travel",
				"physical_location_phase": "clinic_round_path",
				"presentation_clinic_duty_mode": "study_travel",
				"presentation_clinic_patient_id": ""
			},
			"arrival_facing_direction": facing_direction,
			"attach_clinic_study_on_arrival": true
		}
	)
	return {
		"ok": moved,
		"reason": "" if moved else "clinic_study_movement_rejected",
		"doctor_npc_id": doctor_npc_id,
		"workstation_id": workstation_id,
		"target_position": target_position
	}


func _detach_formal_clinic_doctor_for_rounds(doctor_npc_id: String) -> void:
	var npc_node := get_node_or_null(_npc_nodes.get(doctor_npc_id, NodePath())) if _npc_nodes.has(doctor_npc_id) else null
	if npc_node != null and npc_node.has_method("detach_from_spatial_anchor"):
		npc_node.detach_from_spatial_anchor()
	if _formal_workstation_action_sessions.has(doctor_npc_id):
		var session: Dictionary = _formal_workstation_action_sessions[doctor_npc_id]
		var treatment_safe_position: Variant = session.get("clinic_treatment_safe_position")
		session["attachment_committed"] = false
		session.erase("clinic_treatment_safe_position")
		session.erase("clinic_treatment_anchor_position")
		# Mounted seats are inside their own collision footprint. Restore the doctor
		# to the matching audited approach point before asking NavigationAgent3D
		# for a route. A bedside attachment returns to that bed's safe point; a
		# study-chair attachment returns to the doctor's workstation approach.
		var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		var safe_route: Dictionary = (
			controller.get_building_spatial_route(
				str(session.get("building_id", CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID)),
				str(session.get("workstation_id", ""))
			)
			if controller != null and controller.has_method("get_building_spatial_route")
			else {}
		)
		var safe_position: Variant = (
			treatment_safe_position
			if treatment_safe_position is Vector3
			else safe_route.get("interior_target_position")
		)
		if npc_node != null and safe_position is Vector3:
			npc_node.global_position = safe_position
		_formal_workstation_action_sessions[doctor_npc_id] = session


func _maybe_disable_formal_preview() -> void:
	if (
		not _default_formal_world_npcs.is_empty()
		or
		not _formal_workstation_action_sessions.is_empty()
		or not _formal_dialogue_approach_sessions.is_empty()
		or not _formal_navigation_pilots.is_empty()
		or not _formal_combat_world_npcs.is_empty()
	):
		return
	call_deferred("_disable_formal_preview_if_still_idle_after_grace")


func _disable_formal_preview_if_still_idle_after_grace() -> void:
	# Avoid a close/open NavigationServer topology churn between consecutive
	# crafting stages or immediately reassigned formal work. Authority and
	# workstation cleanup have already completed; only presentation/nav hiding
	# is debounced.
	await get_tree().create_timer(0.15, true, false, true).timeout
	if (
		not _default_formal_world_npcs.is_empty()
		or
		not _formal_workstation_action_sessions.is_empty()
		or not _formal_dialogue_approach_sessions.is_empty()
		or not _formal_navigation_pilots.is_empty()
		or not _formal_combat_world_npcs.is_empty()
	):
		return
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("set_runtime_formal_world_enabled"):
		controller.set_runtime_formal_world_enabled(false)


func debug_run_formal_navigation_pilot(pilot_id: String) -> Dictionary:
	var clean_pilot_id := pilot_id.strip_edges().to_lower()
	if not FORMAL_NAVIGATION_PILOT_SPECS.has(clean_pilot_id):
		return {
			"ok": false,
			"reason": "unknown_formal_navigation_pilot",
			"pilot_id": clean_pilot_id,
			"registered_pilot_ids": FORMAL_NAVIGATION_PILOT_SPECS.keys()
		}
	var spec: Dictionary = (FORMAL_NAVIGATION_PILOT_SPECS[clean_pilot_id] as Dictionary).duplicate(true)
	var npc_id := str(spec.get("npc_id", ""))
	var building_id := str(spec.get("building_id", ""))
	var workstation_type := str(spec.get("workstation_type", ""))
	if npc_id.is_empty() or building_id.is_empty() or workstation_type.is_empty():
		return {"ok": false, "reason": "invalid_formal_navigation_pilot_spec", "pilot_id": clean_pilot_id}
	if _is_gameplay_paused_for_debug_movement():
		return {"ok": false, "reason": "gameplay_paused", "pilot_id": clean_pilot_id, "npc_id": npc_id}
	if not _profiles.has(npc_id) or not _npc_nodes.has(npc_id):
		return {"ok": false, "reason": "pilot_npc_missing", "pilot_id": clean_pilot_id, "npc_id": npc_id}

	debug_stop_all_formal_navigation_pilots("superseded_by_%s" % clean_pilot_id)
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if (
		controller == null
		or building_system == null
		or npc_node == null
		or not controller.has_method("debug_set_preview_enabled")
		or not controller.has_method("get_production_navigation_map_rid")
		or not controller.has_method("get_npc_initial_world_position")
		or not controller.has_method("get_building_spatial_route")
		or not npc_node.has_method("configure_navigation_motion")
	):
		return {
			"ok": false,
			"reason": "pilot_dependencies_missing",
			"pilot_id": clean_pilot_id,
			"npc_id": npc_id
		}

	var initial_position: Variant = controller.get_npc_initial_world_position(npc_id)
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not initial_position is Vector3 or not navigation_map.is_valid():
		return {
			"ok": false,
			"reason": "formal_navigation_unavailable",
			"pilot_id": clean_pilot_id,
			"npc_id": npc_id
		}
	var preview_snapshot: Dictionary = controller.debug_set_preview_enabled(true)
	if not bool(preview_snapshot.get("preview_enabled", false)):
		return {
			"ok": false,
			"reason": "formal_preview_unavailable",
			"pilot_id": clean_pilot_id,
			"npc_id": npc_id
		}

	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		action_system.interrupt_npc_action(npc_id, "formal_navigation_pilot", true)
	var original_state := get_npc_state(npc_id)
	var original_location_id := str(original_state.get("current_location", PLAZA_LOCATION_ID))
	var original_position: Vector3 = npc_node.global_position
	_formal_navigation_pilots[npc_id] = {
		"pilot_id": clean_pilot_id,
		"building_id": building_id,
		"workstation_id": "",
		"workstation_type": workstation_type,
		"expected_workstation_id": str(spec.get("expected_workstation_id", "")),
		"original_position": original_position,
		"original_location_id": original_location_id,
		"commit_reservation_on_arrival": true,
		"occupancy_committed": false,
		"attachment_committed": false,
		"setting_up": true
	}
	_cancel_building_interior_route(npc_id, true)
	_movement_arrival_contexts.erase(npc_id)
	if not debug_enter_location_immediately(npc_id, PLAZA_LOCATION_ID):
		_rollback_formal_navigation_pilot_setup(npc_id)
		return {
			"ok": false,
			"reason": "pilot_plaza_reset_failed",
			"pilot_id": clean_pilot_id,
			"npc_id": npc_id
		}
	npc_node.global_position = initial_position
	if not bool(npc_node.configure_navigation_motion(true, navigation_map)):
		_rollback_formal_navigation_pilot_setup(npc_id)
		return {
			"ok": false,
			"reason": "navigation_map_bind_failed",
			"pilot_id": clean_pilot_id,
			"npc_id": npc_id
		}

	var reserve_result: Dictionary = building_system.reserve_workstation(building_id, npc_id, workstation_type)
	if not bool(reserve_result.get("ok", false)):
		_rollback_formal_navigation_pilot_setup(npc_id)
		return {
			"ok": false,
			"reason": str(reserve_result.get("reason", "workstation_reservation_failed")),
			"pilot_id": clean_pilot_id,
			"npc_id": npc_id,
			"reservation": reserve_result
		}
	var workstation_id := str(reserve_result.get("workstation_id", ""))
	var pilot: Dictionary = _formal_navigation_pilots[npc_id]
	pilot["workstation_id"] = workstation_id
	_formal_navigation_pilots[npc_id] = pilot
	var expected_workstation_id := str(spec.get("expected_workstation_id", ""))
	if not expected_workstation_id.is_empty() and workstation_id != expected_workstation_id:
		_rollback_formal_navigation_pilot_setup(npc_id)
		return {
			"ok": false,
			"reason": "assigned_workstation_mismatch",
			"pilot_id": clean_pilot_id,
			"npc_id": npc_id,
			"expected_workstation_id": expected_workstation_id,
			"workstation_id": workstation_id
		}

	var formal_route: Dictionary = controller.get_building_spatial_route(building_id, workstation_id)
	if formal_route.is_empty():
		_rollback_formal_navigation_pilot_setup(npc_id)
		return {
			"ok": false,
			"reason": "formal_route_missing",
			"pilot_id": clean_pilot_id,
			"npc_id": npc_id
		}

	pilot = _formal_navigation_pilots[npc_id]
	pilot.merge({
		"arrival_mode": str(formal_route.get("arrival_mode", "stand")),
		"occupant_pose": str(formal_route.get("occupant_pose", "")),
		"setting_up": false
	}, true)
	_formal_navigation_pilots[npc_id] = pilot
	if not _start_building_entry_route(npc_id, building_id, workstation_id, formal_route):
		_debug_stop_formal_navigation_pilot_npc(npc_id, "route_start_failed")
		return {
			"ok": false,
			"reason": "formal_route_start_failed",
			"pilot_id": clean_pilot_id,
			"npc_id": npc_id
		}
	var route: Dictionary = _building_interior_routes.get(npc_id, {})
	route["commit_reservation_on_arrival"] = true
	route["workstation_type"] = workstation_type
	_building_interior_routes[npc_id] = route
	return {
		"ok": true,
		"pilot_id": clean_pilot_id,
		"npc_id": npc_id,
		"building_id": building_id,
		"workstation_id": workstation_id,
		"workstation_type": workstation_type,
		"expected_workstation_id": expected_workstation_id,
		"arrival_mode": str(formal_route.get("arrival_mode", "stand")),
		"occupant_pose": str(formal_route.get("occupant_pose", "")),
		"route_source": "formal_station_layout",
		"preview_enabled": true
	}


func _rollback_formal_navigation_pilot_setup(npc_id: String) -> void:
	if not _formal_navigation_pilots.has(npc_id):
		return
	var pilot: Dictionary = _formal_navigation_pilots[npc_id]
	var building_id := str(pilot.get("building_id", ""))
	var workstation_id := str(pilot.get("workstation_id", ""))
	_cancel_building_interior_route(npc_id, true)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and not workstation_id.is_empty():
		building_system.release_workstation_reservation(building_id, npc_id, workstation_id)
		if bool(pilot.get("occupancy_committed", false)):
			building_system.release_workstation(building_id, npc_id, workstation_id)
	var npc_node := get_node_or_null(_npc_nodes[npc_id]) if _npc_nodes.has(npc_id) else null
	if npc_node != null:
		if npc_node.has_method("detach_from_spatial_anchor"):
			npc_node.detach_from_spatial_anchor()
		if npc_node.has_method("configure_navigation_motion"):
			npc_node.configure_navigation_motion(false)
		var original_position: Variant = pilot.get("original_position")
		if original_position is Vector3:
			npc_node.global_position = original_position
	_formal_navigation_pilots.erase(npc_id)
	var original_location_id := str(pilot.get("original_location_id", PLAZA_LOCATION_ID))
	if not debug_enter_location_immediately(npc_id, original_location_id):
		debug_enter_location_immediately(npc_id, PLAZA_LOCATION_ID)


func _debug_stop_formal_navigation_pilot_npc(npc_id: String, reason: String = "stopped") -> Dictionary:
	if not _formal_navigation_pilots.has(npc_id):
		return {"ok": true, "active": false, "npc_id": npc_id}
	var pilot: Dictionary = _formal_navigation_pilots[npc_id]
	var building_id := str(pilot.get("building_id", ""))
	var workstation_id := str(pilot.get("workstation_id", ""))
	var state_before_restore := get_npc_state(npc_id)
	_cancel_building_interior_route(npc_id, true)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null:
		if bool(pilot.get("occupancy_committed", false)):
			building_system.release_workstation(building_id, npc_id, workstation_id)
		elif not workstation_id.is_empty():
			building_system.release_workstation_reservation(building_id, npc_id, workstation_id)
	var npc_node := get_node_or_null(_npc_nodes[npc_id]) if _npc_nodes.has(npc_id) else null
	if npc_node != null:
		if npc_node.has_method("detach_from_spatial_anchor"):
			npc_node.detach_from_spatial_anchor()
		if npc_node.has_method("configure_navigation_motion"):
			npc_node.configure_navigation_motion(false)
		var original_position: Variant = pilot.get("original_position")
		if original_position is Vector3:
			npc_node.global_position = original_position
	_formal_navigation_pilots.erase(npc_id)
	var original_location_id := str(pilot.get("original_location_id", PLAZA_LOCATION_ID))
	if not debug_enter_location_immediately(npc_id, original_location_id):
		debug_enter_location_immediately(npc_id, PLAZA_LOCATION_ID)
	var restored_action := "unconscious" if bool(state_before_restore.get("unconscious", false)) else "idle"
	_set_npc_state_without_signal(npc_id, {
		"current_action": restored_action,
		"last_action_result": "formal_navigation_pilot_%s" % reason,
		"spatial_route_phase": "pilot_stopped",
		"physical_location_phase": "legacy_location",
		"reserved_building_id": "",
		"reserved_workstation_id": "",
		"current_workstation_id": ""
	})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"active": false,
		"pilot_id": str(pilot.get("pilot_id", "")),
		"npc_id": npc_id,
		"reason": reason
	}


func debug_stop_formal_navigation_pilot(pilot_id: String, reason: String = "stopped") -> Dictionary:
	var clean_pilot_id := pilot_id.strip_edges().to_lower()
	if not FORMAL_NAVIGATION_PILOT_SPECS.has(clean_pilot_id):
		return {"ok": false, "reason": "unknown_formal_navigation_pilot", "pilot_id": clean_pilot_id}
	var spec: Dictionary = FORMAL_NAVIGATION_PILOT_SPECS[clean_pilot_id]
	return _debug_stop_formal_navigation_pilot_npc(str(spec.get("npc_id", "")), reason)


func debug_get_formal_navigation_pilot_snapshot(pilot_id: String) -> Dictionary:
	var clean_pilot_id := pilot_id.strip_edges().to_lower()
	if not FORMAL_NAVIGATION_PILOT_SPECS.has(clean_pilot_id):
		return {"ok": false, "reason": "unknown_formal_navigation_pilot", "pilot_id": clean_pilot_id}
	var spec: Dictionary = FORMAL_NAVIGATION_PILOT_SPECS[clean_pilot_id]
	var npc_id := str(spec.get("npc_id", ""))
	var snapshot := debug_get_spatial_migration_snapshot(npc_id)
	var active_pilot: Dictionary = _formal_navigation_pilots.get(npc_id, {})
	snapshot["pilot_id"] = clean_pilot_id
	snapshot["active"] = str(active_pilot.get("pilot_id", "")) == clean_pilot_id
	snapshot["registered_spec"] = spec.duplicate(true)
	return snapshot


func debug_run_glen_blacksmith_navigation_pilot() -> Dictionary:
	return debug_run_formal_navigation_pilot("glen")


func debug_stop_glen_blacksmith_navigation_pilot(reason: String = "stopped") -> Dictionary:
	return _debug_stop_formal_navigation_pilot_npc(FIRST_FORMAL_NAVIGATION_PILOT_NPC_ID, reason)


func debug_get_glen_blacksmith_navigation_pilot_snapshot() -> Dictionary:
	return debug_get_formal_navigation_pilot_snapshot("glen")


func debug_run_clinic_navigation_pilot(pilot_mode: String = "doctor") -> Dictionary:
	var clean_mode := pilot_mode.strip_edges().to_lower()
	if clean_mode not in ["doctor", "bed"]:
		return {"ok": false, "reason": "invalid_clinic_pilot_mode", "mode": clean_mode}
	var pilot_id := "clinic_doctor" if clean_mode == "doctor" else "clinic_bed"
	var result := debug_run_formal_navigation_pilot(pilot_id)
	result["mode"] = clean_mode
	return result


func debug_stop_clinic_navigation_pilot(reason: String = "stopped") -> Dictionary:
	return _debug_stop_formal_navigation_pilot_npc(CLINIC_FORMAL_NAVIGATION_PILOT_NPC_ID, reason)


func debug_get_clinic_navigation_pilot_snapshot() -> Dictionary:
	var snapshot := debug_get_spatial_migration_snapshot(CLINIC_FORMAL_NAVIGATION_PILOT_NPC_ID)
	var active_pilot: Dictionary = _formal_navigation_pilots.get(CLINIC_FORMAL_NAVIGATION_PILOT_NPC_ID, {})
	snapshot["active"] = not active_pilot.is_empty()
	snapshot["active_pilot_id"] = str(active_pilot.get("pilot_id", ""))
	return snapshot


func debug_run_dormitory_navigation_pilot() -> Dictionary:
	return debug_run_formal_navigation_pilot("dormitory_bed")


func debug_stop_dormitory_navigation_pilot(reason: String = "stopped") -> Dictionary:
	return _debug_stop_formal_navigation_pilot_npc(DORMITORY_FORMAL_NAVIGATION_PILOT_NPC_ID, reason)


func debug_get_dormitory_navigation_pilot_snapshot() -> Dictionary:
	return debug_get_formal_navigation_pilot_snapshot("dormitory_bed")


func debug_run_dining_navigation_pilot() -> Dictionary:
	return debug_run_formal_navigation_pilot("dining_seat")


func debug_stop_dining_navigation_pilot(reason: String = "stopped") -> Dictionary:
	return _debug_stop_formal_navigation_pilot_npc(DINING_FORMAL_NAVIGATION_PILOT_NPC_ID, reason)


func debug_get_dining_navigation_pilot_snapshot() -> Dictionary:
	return debug_get_formal_navigation_pilot_snapshot("dining_seat")


func debug_run_chapel_navigation_pilot() -> Dictionary:
	return debug_run_formal_navigation_pilot("chapel_prayer_seat")


func debug_stop_chapel_navigation_pilot(reason: String = "stopped") -> Dictionary:
	return _debug_stop_formal_navigation_pilot_npc(CHAPEL_FORMAL_NAVIGATION_PILOT_NPC_ID, reason)


func debug_get_chapel_navigation_pilot_snapshot() -> Dictionary:
	return debug_get_formal_navigation_pilot_snapshot("chapel_prayer_seat")


func debug_run_stable_navigation_pilot() -> Dictionary:
	return debug_run_formal_navigation_pilot("stable_care")


func debug_stop_stable_navigation_pilot(reason: String = "stopped") -> Dictionary:
	return _debug_stop_formal_navigation_pilot_npc(STABLE_FORMAL_NAVIGATION_PILOT_NPC_ID, reason)


func debug_get_stable_navigation_pilot_snapshot() -> Dictionary:
	return debug_get_formal_navigation_pilot_snapshot("stable_care")


func debug_stop_all_formal_navigation_pilots(reason: String = "stopped") -> Dictionary:
	var results: Array[Dictionary] = []
	for raw_npc_id in _formal_navigation_pilots.keys().duplicate():
		results.append(_debug_stop_formal_navigation_pilot_npc(str(raw_npc_id), reason))
	return {"ok": true, "active": false, "results": results}


func debug_get_formal_navigation_pilots_snapshot() -> Dictionary:
	return {
		"registered_pilot_ids": FORMAL_NAVIGATION_PILOT_SPECS.keys(),
		"active_npc_ids": _formal_navigation_pilots.keys(),
		"glen_blacksmith": debug_get_glen_blacksmith_navigation_pilot_snapshot(),
		"clinic": debug_get_clinic_navigation_pilot_snapshot(),
		"dormitory": debug_get_dormitory_navigation_pilot_snapshot(),
		"dining_hall": debug_get_dining_navigation_pilot_snapshot(),
		"chapel": debug_get_chapel_navigation_pilot_snapshot(),
		"stable": debug_get_stable_navigation_pilot_snapshot()
	}

func update_npc_state(npc_id: String, changes: Dictionary) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot update unknown NPC: %s" % npc_id)
		return false
	if changes.is_empty():
		return true

	_set_npc_state_without_signal(npc_id, changes)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func set_npc_state_value(npc_id: String, state_key: String, value: Variant) -> bool:
	return update_npc_state(npc_id, {state_key: value})


func set_npc_recruited(npc_id: String, recruited: bool) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot update recruitment for unknown NPC: %s" % npc_id)
		return false
	var profile: Dictionary = _profiles[npc_id]
	if bool(profile.get("recruited", false)) == recruited:
		return true
	profile["recruited"] = recruited
	_profiles[npc_id] = profile
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("recruitment_changed"):
		event_bus.recruitment_changed.emit(npc_id, recruited)
	if recruited:
		_route_recruited_from_avoidance(npc_id)
	return true


func get_npc_equipment(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Cannot get equipment for unknown NPC: %s" % npc_id)
		return {}
	var profile: Dictionary = _profiles[npc_id]
	var equipment: Dictionary = profile.get("equipment", {})
	return equipment.duplicate(true)


func set_npc_equipment_slot(npc_id: String, slot: String, item: Dictionary) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot set equipment for unknown NPC: %s" % npc_id)
		return false
	if slot.is_empty():
		push_warning("Cannot set equipment with empty slot for NPC: %s" % npc_id)
		return false

	var profile: Dictionary = _profiles[npc_id]
	var equipment: Dictionary = profile.get("equipment", {})
	if item.is_empty():
		equipment.erase(slot)
	else:
		equipment[slot] = item.duplicate(true)
	profile["equipment"] = equipment
	_profiles[npc_id] = profile
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	if slot == "main_weapon" and not item.is_empty():
		_route_recruited_from_avoidance(npc_id)
	return true


func get_current_order(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Cannot get order for unknown NPC: %s" % npc_id)
		return {}
	return _normalize_current_order((_profiles[npc_id] as Dictionary).get("current_order", {}))


func get_npc_plan(npc_id: String) -> Array:
	if not _profiles.has(npc_id):
		push_warning("Cannot get plan for unknown NPC: %s" % npc_id)
		return []
	var profile: Dictionary = _profiles[npc_id]
	var plan: Array = profile.get("plan", [])
	return plan.duplicate(true)


func set_npc_plan(npc_id: String, plan: Array) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot set plan for unknown NPC: %s" % npc_id)
		return false
	var profile: Dictionary = _profiles[npc_id]
	profile["plan"] = plan.duplicate(true)
	_profiles[npc_id] = profile
	_refresh_npc_node(npc_id)
	_emit_npc_daily_plan_changed(npc_id, plan)
	_emit_npc_state_changed(npc_id)
	return true


func stop_npc_movement_for_system(
	npc_id: String,
	last_result: String = "movement_stopped",
	emit_state_changed: bool = true
) -> bool:
	if not _profiles.has(npc_id):
		return false
	var previous_state := get_npc_state(npc_id)
	var previous_location_id := str(previous_state.get("current_location", PLAZA_LOCATION_ID))
	var movement_target_id := str(previous_state.get("movement_target", ""))
	var was_in_transit := (
		not movement_target_id.is_empty()
		or str(previous_state.get("current_action", "")).begins_with("moving_to_")
	)
	if _building_interior_routes.has(npc_id):
		_release_npc_spatial_reservation(npc_id)
		if previous_location_id == FIRST_SPATIAL_INTERIOR_BUILDING_ID and can_npc_act(npc_id):
			_set_npc_state_without_signal(npc_id, {"last_action_result": last_result})
			return _start_building_exit_route(npc_id, PLAZA_LOCATION_ID)
		_cancel_building_interior_route(npc_id, false)
	_stop_npc_movement(npc_id)
	_movement_arrival_contexts.erase(npc_id)
	_building_interior_routes.erase(npc_id)
	var location_id := previous_location_id
	var location_name := str(previous_state.get("current_location_name", previous_location_id))
	var location_context: Dictionary = (
		(previous_state.get("location_context", {}) as Dictionary).duplicate(true)
		if previous_state.get("location_context", {}) is Dictionary
		else {}
	)
	if was_in_transit and previous_location_id != PLAZA_LOCATION_ID:
		# Building travel is logically routed through the plaza. If travel is
		# interrupted before arrival, the NPC is outdoors rather than still inside
		# the old building; settling the information node at the plaza also prevents
		# a same-origin action from starting while the scene actor is mid-route.
		var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
		if memory_system != null:
			location_context = _transition_npc_info_location(
				npc_id,
				_get_info_location_id(memory_system, previous_location_id),
				PLAZA_LOCATION_ID,
				PLAZA_LOCATION_ID,
				memory_system
			)
		location_id = PLAZA_LOCATION_ID
		location_name = str(location_context.get("name", "广场"))
	_set_npc_state_without_signal(npc_id, {
		"current_action": "idle",
		"current_location": location_id,
		"current_location_name": location_name,
		"movement_target": "",
		"movement_target_name": "",
		"location_context": location_context,
		"last_action_result": last_result,
		"spatial_route_phase": "interrupted",
		"physical_location_phase": "interior" if location_id == FIRST_SPATIAL_INTERIOR_BUILDING_ID else "outdoor_path",
		"reserved_building_id": "",
		"reserved_workstation_id": ""
	})
	_refresh_npc_node(npc_id)
	if emit_state_changed:
		_emit_npc_state_changed(npc_id)
	return true


func get_npc_owned_resources(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	var states: Dictionary = (_profiles[npc_id] as Dictionary).get("states", {})
	var owned_resources := {}
	for resource_id in NPC_OWNED_RESOURCE_IDS:
		owned_resources[resource_id] = maxi(0, int(states.get(resource_id, 0)))
	return owned_resources


func can_npc_afford_owned_resources(npc_id: String, costs: Dictionary) -> bool:
	if not _profiles.has(npc_id):
		return false
	var owned_resources := get_npc_owned_resources(npc_id)
	for raw_resource_id in costs.keys():
		var resource_id := str(raw_resource_id)
		var amount := int(costs.get(raw_resource_id, 0))
		if not NPC_OWNED_RESOURCE_IDS.has(resource_id) or amount < 0:
			return false
		if int(owned_resources.get(resource_id, 0)) < amount:
			return false
	return true


func spend_npc_owned_resources(npc_id: String, costs: Dictionary) -> Dictionary:
	if not _profiles.has(npc_id):
		return _interaction_failure("unknown_npc", "NPC 不存在。")
	if costs.is_empty():
		return _interaction_failure("invalid_personal_resource_cost", "个人资源消耗不能为空。")
	var normalized_costs := {}
	for raw_resource_id in costs.keys():
		var resource_id := str(raw_resource_id)
		var amount := int(costs.get(raw_resource_id, 0))
		if not NPC_OWNED_RESOURCE_IDS.has(resource_id) or amount < 0:
			return _interaction_failure("invalid_personal_resource_cost", "个人资源消耗无效。")
		if amount > 0:
			normalized_costs[resource_id] = amount
	if normalized_costs.is_empty():
		return _interaction_failure("invalid_personal_resource_cost", "个人资源消耗必须大于 0。")

	var owned_before := get_npc_owned_resources(npc_id)
	for resource_id in normalized_costs.keys():
		if int(owned_before.get(resource_id, 0)) < int(normalized_costs[resource_id]):
			return _interaction_failure(
				"not_enough_personal_resource",
				"NPC 本人持有的%s不足。" % resource_id
			)

	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	for resource_id in normalized_costs.keys():
		states[resource_id] = int(owned_before.get(resource_id, 0)) - int(normalized_costs[resource_id])
	profile["states"] = states
	_profiles[npc_id] = profile
	var owned_after := get_npc_owned_resources(npc_id)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"costs": normalized_costs.duplicate(true),
		"owned_resources_before": owned_before,
		"owned_resources_after": owned_after
	}


func give_money_to_npc(
	npc_id: String,
	amount: int,
	visibility: String = "local_public"
) -> Dictionary:
	if not _profiles.has(npc_id):
		return _interaction_failure("unknown_npc", "NPC 不存在。")
	if amount <= 0:
		return _interaction_failure("invalid_amount", "赠予金额必须大于 0。")

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.has_method("spend_resources"):
		return _interaction_failure("resource_system_missing", "资源系统不可用。")
	if not resource_system.spend_resources({MONEY_RESOURCE_ID: amount}):
		return _interaction_failure("not_enough_money", "第纳尔不足。")

	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	var money_before := int(states.get("money", 0))
	var money_after := money_before + amount
	states["money"] = money_after
	profile["states"] = states
	_profiles[npc_id] = profile

	var event := _log_player_interaction(npc_id, "money_given", {
		"amount": amount,
		"resource_id": MONEY_RESOURCE_ID,
		"npc_money_before": money_before,
		"npc_money_after": money_after
	}, visibility)
	var escape_speed_result := _notify_escape_money_given(npc_id, amount, event)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"amount": amount,
		"npc_money_before": money_before,
		"npc_money_after": money_after,
		"event": event,
		"escape_speed_result": escape_speed_result
	}


func give_wine_to_npc(
	npc_id: String,
	amount: int,
	visibility: String = "local_public"
) -> Dictionary:
	if not _profiles.has(npc_id):
		return _interaction_failure("unknown_npc", "NPC 不存在。")
	if amount <= 0:
		return _interaction_failure("invalid_amount", "赠予酒的数量必须大于 0。")

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.has_method("spend_resources"):
		return _interaction_failure("resource_system_missing", "资源系统不可用。")
	if not resource_system.spend_resources({WINE_RESOURCE_ID: amount}):
		return _interaction_failure("not_enough_wine", "驿站库存中的酒不足。")

	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	var wine_before := int(states.get("wine", 0))
	var wine_after := wine_before + amount
	states["wine"] = wine_after
	profile["states"] = states
	_profiles[npc_id] = profile

	var event := _log_player_interaction(npc_id, "wine_given", {
		"amount": amount,
		"resource_id": WINE_RESOURCE_ID,
		"npc_wine_before": wine_before,
		"npc_wine_after": wine_after
	}, visibility)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"amount": amount,
		"npc_wine_before": wine_before,
		"npc_wine_after": wine_after,
		"event": event
	}


func publish_npc_order(npc_id: String, text: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return _order_failure("unknown_npc", "NPC 不存在。")

	var profile: Dictionary = _profiles[npc_id]
	if not bool(profile.get("recruited", false)):
		return _order_failure("npc_not_recruited", "未入伍 NPC 不能接收个人指令。")

	var current_order := _normalize_current_order(profile.get("current_order", {}))
	var old_text := str(current_order.get("text", ""))
	var new_text := text.strip_edges()
	if new_text == old_text:
		return {
			"ok": true,
			"changed": false,
			"npc_id": npc_id,
			"current_order": current_order.duplicate(true)
		}

	var issued_at := _get_game_time_snapshot()
	var revision := int(current_order.get("revision", 0)) + 1
	var next_order := {
		"text": new_text,
		"issued_by": PLAYER_ACTOR_ID,
		"issued_day": int(issued_at.get("day", 1)),
		"issued_time": str(issued_at.get("time", "00:00:00")),
		"revision": revision
	}
	profile["current_order"] = next_order
	_profiles[npc_id] = profile

	var event := _log_order_assigned(npc_id, old_text, new_text, revision)
	var reevaluation_status := _request_plan_reevaluation_or_defer(npc_id, "order_changed")
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_order_changed"):
		event_bus.npc_order_changed.emit(npc_id, next_order.duplicate(true))

	return {
		"ok": true,
		"changed": true,
		"npc_id": npc_id,
		"current_order": next_order.duplicate(true),
		"event": event,
		"plan_reevaluation_status": reevaluation_status
	}


func debug_publish_npc_order(npc_id: String, text: String) -> Dictionary:
	return publish_npc_order(npc_id, text)


func start_proactive_talk(npc_id: String, prompt_text: String, duration_seconds: float = PROACTIVE_TALK_DEFAULT_DURATION_SECONDS) -> Dictionary:
	if not _profiles.has(npc_id):
		return _interaction_failure("unknown_npc", "NPC 不存在。")
	if not can_npc_act(npc_id):
		return _interaction_failure("npc_cannot_act", "NPC 当前无法主动交涉。")
	var clean_text := prompt_text.strip_edges()
	if clean_text.is_empty():
		clean_text = "守备官，我有件事想问你。"
	var duration := maxf(1.0, duration_seconds)
	var proactive_state := {
		"active": true,
		"prompt_text": clean_text,
		"remaining_seconds": duration,
		"duration_seconds": duration
	}
	_set_npc_state_without_signal(npc_id, {
		"current_action": "proactive_talk",
		"proactive_talk": proactive_state,
		# Starting a new authoritative action must replace the previous action's
		# terminal result before npc_state_changed is emitted. Otherwise the plan
		# listener can misattribute a stale failure to this proactive interaction.
		"last_action_result": "proactive_talk_started",
		"last_action_failure_context": {}
	})
	var event := _log_proactive_talk_started(npc_id, clean_text, duration)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	_emit_npc_proactive_talk_changed(npc_id, true)
	var presentation_result := _start_proactive_talk_presentation_session(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"proactive_talk": proactive_state.duplicate(true),
		"event": event,
		"presentation": presentation_result
	}


func debug_start_proactive_talk(npc_id: String, prompt_text: String, duration_seconds: float = PROACTIVE_TALK_DEFAULT_DURATION_SECONDS) -> Dictionary:
	return start_proactive_talk(npc_id, prompt_text, duration_seconds)


func get_proactive_talk(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	var state := get_npc_state(npc_id)
	var proactive: Dictionary = state.get("proactive_talk", {})
	return proactive.duplicate(true)


func has_active_proactive_talk(npc_id: String) -> bool:
	var proactive := get_proactive_talk(npc_id)
	return bool(proactive.get("active", false))


func cancel_proactive_talk(npc_id: String, reason: String = "cancelled") -> Dictionary:
	if not _profiles.has(npc_id):
		return {"ok": false, "reason": "unknown_npc", "npc_id": npc_id}
	if not has_active_proactive_talk(npc_id):
		_proactive_talk_presentation_sessions.erase(npc_id)
		return {"ok": true, "changed": false, "npc_id": npc_id}
	var clean_reason := reason.strip_edges()
	if clean_reason.is_empty():
		clean_reason = "cancelled"
	_clear_proactive_talk(npc_id, clean_reason)
	return {"ok": true, "changed": true, "npc_id": npc_id, "reason": clean_reason}


func debug_cancel_proactive_talk(npc_id: String, reason: String = "cancelled") -> Dictionary:
	return cancel_proactive_talk(npc_id, reason)


func handle_npc_clicked(npc_id: String) -> bool:
	if _profiles.has(npc_id) and _is_escape_intervenable_state(get_npc_state(npc_id)):
		return false
	if not has_active_proactive_talk(npc_id):
		return false
	var proactive := get_proactive_talk(npc_id)
	var prompt_text := str(proactive.get("prompt_text", "")).strip_edges()
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("start_proactive_player_dialogue"):
		# The click belongs to the active proactive interaction even when its
		# consumer is temporarily unavailable. Keep the question intact instead
		# of falling through to the ordinary NPC panel.
		return true
	var result: Dictionary = dialog_system.start_proactive_player_dialogue(npc_id, prompt_text)
	if not bool(result.get("ok", false)):
		# Plan activity and other dialogue guards are allowed to reject the
		# handoff. The proactive state remains authoritative and can be retried.
		return true
	_clear_proactive_talk(npc_id, "clicked")
	return true


func _notify_escape_money_given(npc_id: String, amount: int, event: Dictionary) -> Dictionary:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("handle_escape_money_given"):
		return {}
	return combat_system.handle_escape_money_given(npc_id, amount, event)


func _notify_escape_guard_attack(npc_id: String, damage: int, event: Dictionary, became_unconscious: bool) -> Dictionary:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("handle_escape_guard_attack"):
		return {}
	return combat_system.handle_escape_guard_attack(npc_id, damage, event, became_unconscious)


func get_last_plan_reevaluation_request() -> Dictionary:
	return _last_plan_reevaluation_request.duplicate(true)


func get_plan_reevaluation_request(npc_id: String) -> Dictionary:
	return (_plan_reevaluation_requests_by_npc.get(npc_id, {}) as Dictionary).duplicate(true)


func request_plan_reevaluation(npc_id: String, reason: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	return _request_plan_reevaluation_or_defer(npc_id, reason)


func set_npc_llm_activity(npc_id: String, activity: Dictionary) -> bool:
	if not _profiles.has(npc_id):
		return false
	var next_activity := _normalize_llm_activity(activity)
	_set_npc_state_without_signal(npc_id, {"llm_activity": next_activity})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	_emit_npc_llm_activity_changed(npc_id, next_activity)
	return true


func clear_npc_llm_activity(npc_id: String, request_id: String = "") -> bool:
	if not _profiles.has(npc_id):
		return false
	var current := get_npc_llm_activity(npc_id)
	if not request_id.is_empty() and str(current.get("request_id", "")) != request_id:
		return false
	return set_npc_llm_activity(npc_id, {})


func get_npc_llm_activity(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	var state := get_npc_state(npc_id)
	var activity: Dictionary = state.get("llm_activity", {}) if (state.get("llm_activity", {}) is Dictionary) else {}
	return _normalize_llm_activity(activity)


func set_first_sleep_summary_lock(npc_id: String, locked: bool, request_id: String = "") -> bool:
	if not _profiles.has(npc_id):
		return false
	var state := get_npc_state(npc_id)
	var current_action := str(state.get("current_action", ""))
	var changes := {
		"first_sleep_summary_active": locked
	}
	if locked:
		changes["current_action"] = "sleep_in_dormitory"
		changes["last_action_result"] = "first_sleep_summary_started"
		if not request_id.is_empty():
			changes["first_sleep_summary_request_id"] = request_id
	else:
		changes["first_sleep_summary_request_id"] = ""
		if current_action == "sleep_in_dormitory":
			changes["last_action_result"] = "first_sleep_summary_completed"
	_set_npc_state_without_signal(npc_id, changes)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func is_first_sleep_summary_locked(npc_id: String) -> bool:
	if not _profiles.has(npc_id):
		return false
	var state := get_npc_state(npc_id)
	return bool(state.get("first_sleep_summary_active", false))


func is_npc_dialogue_blocked(npc_id: String) -> bool:
	if is_first_sleep_summary_locked(npc_id):
		return true
	var activity := get_npc_llm_activity(npc_id)
	return bool(activity.get("active", false)) and str(activity.get("kind", "")) == LLM_ACTIVITY_BATTLE_JUDGEMENT


func is_npc_plan_llm_active(npc_id: String) -> bool:
	var activity := get_npc_llm_activity(npc_id)
	return bool(activity.get("active", false)) and str(activity.get("kind", "")) == LLM_ACTIVITY_PLAN


func defer_plan_reevaluation_until_wake(npc_id: String, reason: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	var issued_at := _get_game_time_snapshot()
	var deferred := {
		"active": true,
		"reason": reason,
		"day": int(issued_at.get("day", 1)),
		"time": str(issued_at.get("time", "00:00:00")),
		"current_order": get_current_order(npc_id)
	}
	_set_npc_state_without_signal(npc_id, {"pending_plan_reevaluation_after_sleep": deferred})
	var request_snapshot := {
		"npc_id": npc_id,
		"reason": reason,
		"day": int(deferred.get("day", 1)),
		"time": str(deferred.get("time", "00:00:00")),
		"current_order": deferred.get("current_order", {}),
		"result": {
			"status": "deferred_until_wake",
			"fallback_used": false,
			"summary": "NPC 正在首次睡眠总结，计划重评估延后到醒来后执行。"
		}
	}
	_store_plan_reevaluation_request(npc_id, request_snapshot)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return request_snapshot.duplicate(true)


func consume_deferred_plan_reevaluation_after_sleep(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	var state := get_npc_state(npc_id)
	var deferred: Dictionary = state.get("pending_plan_reevaluation_after_sleep", {}) if (state.get("pending_plan_reevaluation_after_sleep", {}) is Dictionary) else {}
	if not bool(deferred.get("active", false)):
		return {}
	_set_npc_state_without_signal(npc_id, {"pending_plan_reevaluation_after_sleep": {}})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return _request_plan_reevaluation(npc_id, str(deferred.get("reason", "deferred_until_wake")))


func apply_plan_reevaluation_result(npc_id: String, reason: String, result: Dictionary) -> void:
	var request_snapshot: Dictionary = _plan_reevaluation_requests_by_npc.get(npc_id, {})
	if request_snapshot.is_empty():
		return
	if str(request_snapshot.get("reason", "")) != reason:
		return
	request_snapshot["result"] = result.duplicate(true)
	_plan_reevaluation_requests_by_npc[npc_id] = request_snapshot
	if (
		str(_last_plan_reevaluation_request.get("npc_id", "")) == npc_id
		and str(_last_plan_reevaluation_request.get("reason", "")) == reason
	):
		_last_plan_reevaluation_request = request_snapshot.duplicate(true)


func can_npc_act(npc_id: String) -> bool:
	if not _profiles.has(npc_id):
		return false
	var state := get_npc_state(npc_id)
	return (
		not bool(state.get("unconscious", false))
		and not bool(state.get("escaped", false))
		and not _is_npc_escaping_state(state)
		and not bool(state.get("first_sleep_summary_active", false))
		and not _formal_navigation_pilots.has(npc_id)
	)


func apply_damage_to_npc(
	npc_id: String,
	damage: int,
	actor_id: String = PLAYER_ACTOR_ID,
	visibility: String = "local_public",
	options: Dictionary = {}
) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Cannot damage unknown NPC: %s" % npc_id)
		return {}
	if damage <= 0:
		push_warning("NPC damage must be positive: %d" % damage)
		return {}

	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	var max_hp := maxi(1, int(states.get("max_hp", 100)))
	var hp_before := clampi(int(states.get("hp", max_hp)), 0, max_hp)
	var was_unconscious := bool(states.get("unconscious", false))
	var previous_behavior_mode := _get_current_behavior_mode(npc_id)
	var hp_after := maxi(0, hp_before - damage)
	states["hp"] = hp_after
	states["max_hp"] = max_hp
	var became_unconscious := hp_after <= 0 and not was_unconscious
	if became_unconscious:
		states["unconscious"] = true
		states["current_action"] = "unconscious"
		states["movement_target"] = ""
		states["movement_target_name"] = ""
		states["behavior_mode"] = BEHAVIOR_MODE_UNCONSCIOUS
		states["behavior_mode_previous"] = previous_behavior_mode
		states["behavior_mode_reason"] = "hp_zero"
		var unconscious_time := _get_game_time_snapshot()
		states["behavior_mode_entered_day"] = int(unconscious_time.get("day", 1))
		states["behavior_mode_entered_time"] = str(unconscious_time.get("time", "00:00:00"))
		states["combat_mode"] = ""
		states["combat_mounted"] = false
		states["combat_mount_phase"] = "rider_unconscious"
		states["combat_target_enemy_id"] = ""
		states["combat_target_selection_reason"] = ""
		states["combat_target_scope"] = ""
		states["combat_attack_cooldown"] = 0.0
		states["combat_attack_target_enemy_id"] = ""
		states["combat_attack_phase"] = "idle"
		states["combat_attack_elapsed_seconds"] = 0.0
		states["combat_attack_cycle_seconds"] = 0.0
		states["combat_attack_impact_seconds"] = 0.0
		states["combat_attack_playback_multiplier"] = 1.0
		states["combat_attack_impact_committed"] = false
		states["combat_strategy_move_enemy_id"] = ""
		states["combat_strategy_move_recovery_count"] = 0
		states["combat_strategy_last_stall"] = {}
		states["keep_distance_retreat_active"] = false
		states["keep_distance_retreat_target_id"] = ""
		states["keep_distance_retreat_target_position"] = {}
		states["keep_distance_retreat_desired_position"] = {}
		states["keep_distance_retreat_direction"] = {}
		states["keep_distance_retreat_threat_ids"] = []
		states["keep_distance_retreat_threats"] = []
		states["combat_last_attack_result"] = {}
		states["last_action_result"] = "became_unconscious"
	profile["states"] = states
	# The damage fact receives its unique MemorySystem event ID before any
	# HP projection or presentation is dispatched. Character animation consumes
	# that same ID and never becomes a second damage authority.
	var damage_event := _log_damage_taken(npc_id, actor_id, damage, hp_before, hp_after, visibility, options)
	_profiles[npc_id] = profile

	if became_unconscious:
		if _formal_navigation_pilots.has(npc_id):
			_debug_stop_formal_navigation_pilot_npc(npc_id, "unconscious")
		else:
			_stop_npc_movement(npc_id)
	_refresh_npc_node(npc_id)
	_emit_npc_hp_changed(npc_id, hp_after, max_hp)
	_emit_npc_state_changed(npc_id)

	var presentation_result := play_damage_presentation_event({
		"ok": true,
		"npc_id": npc_id,
		"actor_id": actor_id,
		"damage": damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"unconscious": bool(states.get("unconscious", false)),
		"damage_event": damage_event
	})
	var escape_speed_result := {}
	if actor_id == PLAYER_ACTOR_ID:
		escape_speed_result = _notify_escape_guard_attack(npc_id, damage, damage_event, became_unconscious)
	var unconscious_event := {}
	if became_unconscious:
		unconscious_event = _log_unconscious_started(npc_id, actor_id, damage, hp_before, hp_after, "local_public")
		_log_npc_mode_changed(npc_id, previous_behavior_mode, BEHAVIOR_MODE_UNCONSCIOUS, "hp_zero", {
			"visibility": "local_public",
			"trigger_actor_id": actor_id
		})
		_emit_npc_unconscious(npc_id)
	elif bool(options.get("enemy_attack", false)):
		_route_enemy_attack_mode(npc_id, actor_id)
	elif actor_id == PLAYER_ACTOR_ID and bool(options.get("request_plan_reevaluation", true)):
		_request_plan_reevaluation_or_defer(npc_id, "guard_attack")

	var result := {
		"ok": true,
		"npc_id": npc_id,
		"actor_id": actor_id,
		"visibility": visibility,
		"damage": damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"unconscious": bool(states.get("unconscious", false)),
		"damage_event": damage_event,
		"presentation": presentation_result,
		"unconscious_event": unconscious_event,
		"escape_speed_result": escape_speed_result,
		"options": options.duplicate(true)
	}
	_notify_combat_damage_applied(result, options)
	return result


func debug_damage_npc(npc_id: String, damage: int, visibility: String = "local_public") -> Dictionary:
	return apply_damage_to_npc(npc_id, damage, PLAYER_ACTOR_ID, visibility)


func _notify_combat_damage_applied(damage_result: Dictionary, options: Dictionary) -> void:
	if damage_result.is_empty() or not bool(damage_result.get("ok", false)):
		return
	if bool(options.get("skip_low_hp_judgement", false)):
		return
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("handle_npc_damage_applied"):
		return
	combat_system.call_deferred(
		"handle_npc_damage_applied",
		damage_result.duplicate(true),
		options.duplicate(true)
	)


func debug_advance_unconscious_recovery(npc_id: String, game_seconds: float) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Cannot advance recovery for unknown NPC: %s" % npc_id)
		return {}
	if game_seconds <= 0.0:
		push_warning("Recovery advance seconds must be positive: %f" % game_seconds)
		return {}
	return _advance_unconscious_recovery(game_seconds, npc_id)


func assist_unconscious_recovery(
	target_npc_id: String,
	game_seconds: float,
	healer_npc_id: String,
	medical_skill: int
) -> Dictionary:
	if not _profiles.has(target_npc_id):
		push_warning("Cannot heal unknown NPC: %s" % target_npc_id)
		return {}
	if not _profiles.has(healer_npc_id):
		push_warning("Cannot use unknown healer NPC: %s" % healer_npc_id)
		return {}
	if game_seconds <= 0.0:
		return {}
	var hp_per_hour := _calculate_healing_hp_per_hour(medical_skill)
	return _advance_single_unconscious_recovery_with_rate(
		target_npc_id,
		game_seconds,
		hp_per_hour,
		"healing_assist",
		healer_npc_id
	)


func get_assisted_recovery_effective_seconds(
	target_npc_id: String,
	requested_game_seconds: float,
	healer_npc_id: String,
	medical_skill: int
) -> float:
	if requested_game_seconds <= 0.0 or not _profiles.has(target_npc_id):
		return 0.0
	var state: Dictionary = get_npc_state(target_npc_id)
	if not bool(state.get("unconscious", false)) or bool(state.get("escaped", false)):
		return 0.0
	var max_hp := maxi(1, int(state.get("max_hp", 100)))
	var hp_before := clampi(int(state.get("hp", 0)), 0, max_hp)
	var revive_threshold := _get_revive_hp_threshold(max_hp)
	if hp_before >= revive_threshold:
		return 0.0
	var hp_per_hour := _calculate_healing_hp_per_hour(medical_skill)
	if hp_per_hour <= 0.0:
		return 0.0
	var remainder_key := _get_recovery_remainder_key(target_npc_id, "healing_assist", healer_npc_id)
	var accumulated := float(_unconscious_recovery_remainders.get(remainder_key, 0.0))
	var hp_progress_needed := maxf(0.0, float(revive_threshold - hp_before) - accumulated)
	var seconds_until_revive := hp_progress_needed * 3600.0 / hp_per_hour
	return minf(requested_game_seconds, seconds_until_revive)


func restore_npc_hp(
	npc_id: String,
	amount: int,
	recovery_source: String = "clinic_treatment",
	healer_npc_id: String = ""
) -> Dictionary:
	if amount <= 0 or not _profiles.has(npc_id):
		return {}

	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	if bool(states.get("escaped", false)) or bool(states.get("unconscious", false)):
		return {}

	var max_hp := maxi(1, int(states.get("max_hp", 100)))
	var hp_before := clampi(int(states.get("hp", max_hp)), 0, max_hp)
	if hp_before >= max_hp:
		return {}

	var hp_after := mini(max_hp, hp_before + amount)
	states["hp"] = hp_after
	states["max_hp"] = max_hp
	states["last_action_result"] = "%s_recovered" % recovery_source
	profile["states"] = states
	_profiles[npc_id] = profile
	_refresh_npc_node(npc_id)
	_emit_npc_hp_changed(npc_id, hp_after, max_hp)
	_emit_npc_state_changed(npc_id)
	return {
		"npc_id": npc_id,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"recovery_source": recovery_source,
		"healer_npc_id": healer_npc_id
	}


func increase_npc_skill(npc_id: String, skill_name: String, amount: int) -> Dictionary:
	if amount <= 0 or skill_name.is_empty() or not _profiles.has(npc_id):
		return {}

	var profile: Dictionary = _profiles[npc_id]
	var skills: Dictionary = normalize_skills(profile.get("skills", {}))
	if not skills.has(skill_name):
		return {}
	var before := clampi(int(skills.get(skill_name, 0)), 0, 100)
	var after := clampi(before + amount, 0, 100)
	if after == before:
		return {}

	skills[skill_name] = after
	profile["skills"] = skills
	var progression_result := _add_growth_experience(profile, skill_name, after - before)
	profile["progression"] = progression_result.get("progression", {})
	_profiles[npc_id] = profile
	_emit_npc_state_changed(npc_id)
	return {
		"npc_id": npc_id,
		"skill_name": skill_name,
		"before": before,
		"after": after,
		"amount": after - before,
		"experience_gained": int(progression_result.get("experience_gained", 0)),
		"total_experience": int(progression_result.get("total_experience", 0)),
		"skill_points_gained": int(progression_result.get("skill_points_gained", 0)),
		"unspent_skill_points": int(progression_result.get("unspent_skill_points", 0)),
		"skill_experience": int(progression_result.get("skill_experience", 0)),
		"next_skill_point_xp": SKILL_POINT_EXPERIENCE_THRESHOLD
	}


func get_npc_progression(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	var profile: Dictionary = _profiles[npc_id]
	var progression := _normalize_progression(profile.get("progression", {}))
	profile["progression"] = progression
	_profiles[npc_id] = profile
	return progression.duplicate(true)


func get_npc_long_memory(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	var profile: Dictionary = _profiles[npc_id]
	return {
		"knowledge_graph": profile.get("knowledge_graph", {}).duplicate(true) if (profile.get("knowledge_graph", {}) is Dictionary) else {},
		"diary": _normalize_diary_entries(profile.get("diary", []))
	}


func apply_daily_reflection(npc_id: String, reflection: Dictionary) -> Dictionary:
	if not _profiles.has(npc_id):
		return _interaction_failure("unknown_npc", "NPC 不存在。")
	if reflection.is_empty():
		return _interaction_failure("empty_reflection", "首次睡眠总结为空。")

	var diary_entry := str(reflection.get("diary_entry", "")).strip_edges()
	if diary_entry.is_empty():
		return _interaction_failure("empty_diary", "首次睡眠日记为空。")

	var profile: Dictionary = _profiles[npc_id]
	var day := maxi(1, int(reflection.get("day", _get_game_time_snapshot().get("day", 1))))
	var trigger_day := maxi(1, int(reflection.get(
		"trigger_day",
		_get_game_time_snapshot().get("day", day)
	)))
	var time_text := str(reflection.get(
		"trigger_time",
		_get_game_time_snapshot().get("time", "00:00:00")
	))
	var record_label := str(reflection.get("record_label", "")).strip_edges()
	var diary := _normalize_diary_entries(profile.get("diary", []))
	var diary_record := {
		"day": day,
		"time": time_text,
		"record_label": record_label,
		"entry": diary_entry,
		"source": str(reflection.get("source", "daily_reflection")),
		"model_provider": str(reflection.get("model_provider", "")),
		"model_name": str(reflection.get("model_name", "")),
		"model_fallback_used": bool(reflection.get("model_fallback_used", false)),
		"debug_reason": str(reflection.get("debug_reason", "")),
		"summary_window_key": str(reflection.get("summary_window_key", "")),
		"window_anchor_day": maxi(0, int(reflection.get("window_anchor_day", day))),
		"trigger_day": trigger_day,
		"trigger_time": time_text,
		"reflection_period": (
			reflection.get("reflection_period", {}).duplicate(true)
			if reflection.get("reflection_period", {}) is Dictionary
			else {}
		)
	}
	diary.append(diary_record)
	profile["diary"] = diary

	var graph: Dictionary = profile.get("knowledge_graph", {}) if (profile.get("knowledge_graph", {}) is Dictionary) else {}
	graph = _apply_knowledge_graph_updates(
		graph,
		reflection.get("knowledge_graph_updates", []),
		trigger_day,
		time_text
	)
	profile["knowledge_graph"] = graph
	_profiles[npc_id] = profile

	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"day": day,
		"trigger_day": trigger_day,
		"record_label": record_label,
		"diary_count": diary.size(),
		"diary_entry": diary_entry,
		"knowledge_graph_update_count": (reflection.get("knowledge_graph_updates", []) as Array).size() if (reflection.get("knowledge_graph_updates", []) is Array) else 0
	}


func assign_npc_attribute_point(npc_id: String, attribute_name: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return _interaction_failure("unknown_npc", "NPC 不存在。")
	var normalized_attribute := _normalize_attribute_name(attribute_name)
	if normalized_attribute.is_empty():
		return _interaction_failure("invalid_attribute", "只能分配到力量或智力。")

	var profile: Dictionary = _profiles[npc_id]
	var progression := _normalize_progression(profile.get("progression", {}))
	var unspent_points := int(progression.get("unspent_skill_points", 0))
	if unspent_points <= 0:
		return _interaction_failure("no_skill_points", "没有可分配技能点。")

	var stats: Dictionary = profile.get("stats", {})
	var before := clampi(int(stats.get(normalized_attribute, 0)), ATTRIBUTE_MIN_VALUE, ATTRIBUTE_MAX_VALUE)
	if before >= ATTRIBUTE_MAX_VALUE:
		return _interaction_failure("attribute_maxed", "该属性已达到上限。")

	var after := clampi(before + 1, ATTRIBUTE_MIN_VALUE, ATTRIBUTE_MAX_VALUE)
	stats[normalized_attribute] = after
	progression["unspent_skill_points"] = unspent_points - 1
	progression["spent_skill_points"] = int(progression.get("spent_skill_points", 0)) + 1
	profile["stats"] = stats
	profile["progression"] = progression
	_profiles[npc_id] = profile

	var event := _log_attribute_improved(npc_id, normalized_attribute, before, after)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"attribute": normalized_attribute,
		"attribute_label": _get_attribute_label(normalized_attribute),
		"before": before,
		"after": after,
		"unspent_skill_points": int(progression.get("unspent_skill_points", 0)),
		"event": event
	}


func debug_assign_attribute_point(npc_id: String, attribute_name: String) -> Dictionary:
	return assign_npc_attribute_point(npc_id, attribute_name)


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0:
		return
	_advance_unconscious_recovery(game_delta_seconds)
	_advance_proactive_talk_timers(game_delta_seconds)


func _advance_unconscious_recovery(game_delta_seconds: float, only_npc_id: String = "") -> Dictionary:
	var result := {
		"ok": true,
		"game_seconds": game_delta_seconds,
		"recovered": [],
		"revived": []
	}
	var npc_ids: Array = [only_npc_id] if not only_npc_id.is_empty() else _npc_order.duplicate()
	for npc_id in npc_ids:
		if not _profiles.has(npc_id):
			continue
		var recovery_result := _advance_single_unconscious_recovery(npc_id, game_delta_seconds)
		if recovery_result.is_empty():
			continue
		(result["recovered"] as Array).append(recovery_result)
		if bool(recovery_result.get("revived", false)):
			(result["revived"] as Array).append(npc_id)
	return result


func _advance_single_unconscious_recovery(npc_id: String, game_delta_seconds: float) -> Dictionary:
	return _advance_single_unconscious_recovery_with_rate(
		npc_id,
		game_delta_seconds,
		UNCONSCIOUS_NATURAL_RECOVERY_HP_PER_HOUR,
		"natural_recovery"
	)


func _advance_single_unconscious_recovery_with_rate(
	npc_id: String,
	game_delta_seconds: float,
	hp_per_hour: float = UNCONSCIOUS_NATURAL_RECOVERY_HP_PER_HOUR,
	recovery_source: String = "natural_recovery",
	healer_npc_id: String = ""
) -> Dictionary:
	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	if not bool(states.get("unconscious", false)) or bool(states.get("escaped", false)):
		_unconscious_recovery_remainders.erase(npc_id)
		return {}

	var max_hp := maxi(1, int(states.get("max_hp", 100)))
	var hp_before := clampi(int(states.get("hp", 0)), 0, max_hp)
	var revive_threshold := _get_revive_hp_threshold(max_hp)
	if hp_before >= revive_threshold:
		return _revive_npc_from_unconscious(npc_id, hp_before, hp_before, recovery_source)

	var remainder_key := _get_recovery_remainder_key(npc_id, recovery_source, healer_npc_id)
	var accumulated := float(_unconscious_recovery_remainders.get(remainder_key, 0.0))
	accumulated += (maxf(0.0, hp_per_hour) / 3600.0) * game_delta_seconds
	var hp_to_restore := int(floor(accumulated))
	if hp_to_restore <= 0:
		_unconscious_recovery_remainders[remainder_key] = accumulated
		return {}

	accumulated -= float(hp_to_restore)
	var hp_after := mini(max_hp, hp_before + hp_to_restore)
	if hp_after >= revive_threshold:
		hp_after = revive_threshold
		_clear_recovery_remainders_for_npc(npc_id)
		return _revive_npc_from_unconscious(npc_id, hp_before, hp_after, recovery_source)

	_unconscious_recovery_remainders[remainder_key] = accumulated
	states["hp"] = hp_after
	states["max_hp"] = max_hp
	states["last_action_result"] = "unconscious_%s" % recovery_source
	profile["states"] = states
	_profiles[npc_id] = profile
	_refresh_npc_node(npc_id)
	_emit_npc_hp_changed(npc_id, hp_after, max_hp)
	_emit_npc_state_changed(npc_id)
	return {
		"npc_id": npc_id,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"revive_threshold": revive_threshold,
		"revived": false,
		"recovery_source": recovery_source,
		"hp_per_hour": hp_per_hour,
		"healer_npc_id": healer_npc_id
	}


func _revive_npc_from_unconscious(npc_id: String, hp_before: int, hp_after: int, recovery_source: String) -> Dictionary:
	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	var max_hp := maxi(1, int(states.get("max_hp", 100)))
	var revive_threshold := _get_revive_hp_threshold(max_hp)
	hp_after = clampi(maxi(hp_after, revive_threshold), 1, max_hp)
	states["hp"] = hp_after
	states["max_hp"] = max_hp
	states["unconscious"] = false
	states["current_action"] = "idle"
	states["last_action_result"] = "revived_%s" % recovery_source
	profile["states"] = states
	_profiles[npc_id] = profile
	_clear_recovery_remainders_for_npc(npc_id)

	_refresh_npc_node(npc_id)
	_emit_npc_hp_changed(npc_id, hp_after, max_hp)
	_emit_npc_state_changed(npc_id)
	var revived_event := _log_revived(npc_id, hp_before, hp_after, recovery_source, "local_public")
	_emit_npc_revived(npc_id)
	return {
		"npc_id": npc_id,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"revive_threshold": revive_threshold,
		"revived": true,
		"revived_event": revived_event
	}


func _get_revive_hp_threshold(max_hp: int) -> int:
	return maxi(1, int(ceil(float(max_hp) * REVIVE_HP_RATIO)))


func _calculate_healing_hp_per_hour(medical_skill: int) -> float:
	var normalized_skill := clampf((float(medical_skill) - UNCONSCIOUS_HEALING_SKILL_THRESHOLD) / 80.0, 0.0, 1.0)
	var bonus := pow(normalized_skill, 1.5) * UNCONSCIOUS_HEALING_MAX_BONUS_HP_PER_HOUR
	return UNCONSCIOUS_HEALING_BASE_HP_PER_HOUR + bonus


func _get_recovery_remainder_key(npc_id: String, recovery_source: String, helper_id: String = "") -> String:
	if recovery_source == "natural_recovery" or helper_id.is_empty():
		return npc_id
	return "%s:%s:%s" % [npc_id, recovery_source, helper_id]


func _clear_recovery_remainders_for_npc(npc_id: String) -> void:
	var keys := _unconscious_recovery_remainders.keys()
	for raw_key in keys:
		var key := str(raw_key)
		if key == npc_id or key.begins_with("%s:" % npc_id):
			_unconscious_recovery_remainders.erase(key)


func _set_npc_state_without_signal(npc_id: String, changes: Dictionary) -> void:
	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	for key in changes.keys():
		states[str(key)] = changes[key]
	profile["states"] = states
	_profiles[npc_id] = profile


func _is_npc_escaping_state(state: Dictionary) -> bool:
	var escape_intent: Dictionary = state.get("escape_intent", {}) if state.get("escape_intent", {}) is Dictionary else {}
	if not bool(escape_intent.get("active", false)):
		return false
	return ["escaping", "paused_unconscious"].has(str(escape_intent.get("status", "")))


func _is_escape_intervenable_state(state: Dictionary) -> bool:
	if bool(state.get("unconscious", false)) or bool(state.get("escaped", false)):
		return false
	var escape_intent: Dictionary = state.get("escape_intent", {}) if state.get("escape_intent", {}) is Dictionary else {}
	if not bool(escape_intent.get("active", false)) or str(escape_intent.get("status", "")) != "escaping":
		return false
	return int(escape_intent.get("intervention_rounds_used", 0)) < int(escape_intent.get("intervention_max_rounds", 5))


func _stop_npc_movement(npc_id: String) -> void:
	if not _npc_nodes.has(npc_id):
		return
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node != null and npc_node.has_method("stop_movement"):
		npc_node.stop_movement()


func _cancel_building_interior_route(npc_id: String, release_reservation: bool) -> void:
	if release_reservation:
		_release_npc_spatial_reservation(npc_id)
	_building_interior_routes.erase(npc_id)
	_stop_npc_movement(npc_id)


func _release_npc_spatial_reservation(npc_id: String) -> bool:
	if not _profiles.has(npc_id):
		return false
	var state := get_npc_state(npc_id)
	var building_id := str(state.get("reserved_building_id", ""))
	var workstation_id := str(state.get("reserved_workstation_id", ""))
	if building_id.is_empty() and _building_interior_routes.has(npc_id):
		var route: Dictionary = _building_interior_routes[npc_id]
		building_id = str(route.get("building_id", ""))
		workstation_id = str(route.get("workstation_id", ""))
	if building_id.is_empty() or workstation_id.is_empty():
		return false
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("release_workstation_reservation"):
		return false
	return bool(building_system.release_workstation_reservation(building_id, npc_id, workstation_id))


func _clean_nullable_state_id(value: Variant) -> String:
	var clean_id := str(value).strip_edges()
	return "" if clean_id == "<null>" else clean_id


func _is_gameplay_paused_for_debug_movement() -> bool:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	return (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	)


func _ensure_runtime_state_defaults(npc_id: String) -> void:
	var profile: Dictionary = _profiles[npc_id]
	profile["skills"] = normalize_skills(profile.get("skills", {}))
	profile["current_order"] = _normalize_current_order(profile.get("current_order", {}))
	profile["progression"] = _normalize_progression(profile.get("progression", {}))
	if not (profile.get("knowledge_graph", {}) is Dictionary):
		profile["knowledge_graph"] = {}
	profile["diary"] = _normalize_diary_entries(profile.get("diary", []))
	var states: Dictionary = profile.get("states", {})
	states["money"] = maxi(0, int(states.get("money", 0)))
	states["wine"] = maxi(0, int(states.get("wine", 0)))
	if not states.has("current_location"):
		states["current_location"] = "plaza"
	if not states.has("spatial_route_phase"):
		states["spatial_route_phase"] = "none"
	if not states.has("physical_location_phase"):
		states["physical_location_phase"] = "plaza"
	if not states.has("reserved_building_id"):
		states["reserved_building_id"] = ""
	if not states.has("reserved_workstation_id"):
		states["reserved_workstation_id"] = ""
	if not states.has("current_workstation_id"):
		states["current_workstation_id"] = ""
	if not states.has("location_context"):
		states["location_context"] = {}
	if not states.has("proactive_talk"):
		states["proactive_talk"] = {}
	if not states.has("active_dialogue_id"):
		states["active_dialogue_id"] = ""
	if not states.has("player_dialogue_suspended"):
		states["player_dialogue_suspended"] = false
	if not states.has("llm_activity"):
		states["llm_activity"] = {}
	if not states.has("first_sleep_summary_active"):
		states["first_sleep_summary_active"] = false
	if not states.has("first_sleep_summary_request_id"):
		states["first_sleep_summary_request_id"] = ""
	if not states.has("pending_plan_reevaluation_after_sleep"):
		states["pending_plan_reevaluation_after_sleep"] = {}
	if not states.has("combat_strategy"):
		states["combat_strategy"] = {}
	if not states.has("combat_strategy_move_recovery_count"):
		states["combat_strategy_move_recovery_count"] = 0
	if not states.has("combat_strategy_last_stall"):
		states["combat_strategy_last_stall"] = {}
	if not states.has("keep_distance_retreat_active"):
		states["keep_distance_retreat_active"] = false
	if not states.has("keep_distance_retreat_sequence"):
		states["keep_distance_retreat_sequence"] = 0
	if not states.has("keep_distance_retreat_recovery_count"):
		states["keep_distance_retreat_recovery_count"] = 0
	if not states.has("behavior_mode"):
		if bool(states.get("escaped", false)):
			states["behavior_mode"] = BEHAVIOR_MODE_ESCAPED
		elif bool(states.get("unconscious", false)):
			states["behavior_mode"] = BEHAVIOR_MODE_UNCONSCIOUS
		else:
			var legacy_combat_mode := str(states.get("combat_mode", ""))
			states["behavior_mode"] = legacy_combat_mode if [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(legacy_combat_mode) else BEHAVIOR_MODE_WORK
	if not states.has("behavior_mode_previous"):
		states["behavior_mode_previous"] = ""
	if not states.has("behavior_mode_reason"):
		states["behavior_mode_reason"] = "initial_state"
	if not states.has("behavior_mode_entered_day"):
		states["behavior_mode_entered_day"] = 1
	if not states.has("behavior_mode_entered_time"):
		states["behavior_mode_entered_time"] = "00:00:00"
	profile["states"] = states
	_profiles[npc_id] = profile


func _get_current_behavior_mode(npc_id: String) -> String:
	if not _profiles.has(npc_id):
		return BEHAVIOR_MODE_WORK
	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	if bool(states.get("escaped", false)):
		return BEHAVIOR_MODE_ESCAPED
	if bool(states.get("unconscious", false)):
		return BEHAVIOR_MODE_UNCONSCIOUS
	var mode := str(states.get("behavior_mode", "")).strip_edges()
	if VALID_BEHAVIOR_MODES.has(mode):
		return mode
	var legacy_combat_mode := str(states.get("combat_mode", "")).strip_edges()
	if [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(legacy_combat_mode):
		return legacy_combat_mode
	return BEHAVIOR_MODE_WORK


func _get_behavior_mode_label(mode: String) -> String:
	return str(BEHAVIOR_MODE_LABELS.get(mode, mode))


func _is_sleeping_state(state: Dictionary) -> bool:
	var current_action := str(state.get("current_action", ""))
	return current_action.begins_with("sleep") or current_action == "sleep_in_dormitory"


func _should_clear_action_when_returning_to_work(current_action: String, options: Dictionary) -> bool:
	if bool(options.get("force_idle", false)):
		return true
	if current_action.is_empty():
		return true
	return (
		[
			"rallying_defense_line",
			"combat_ready",
			"avoid_combat",
			"avoiding_enemy",
			"unconscious"
		].has(current_action)
		or current_action.begins_with("moving_to_combat_rally_")
		or current_action.begins_with("moving_to_combat_strategy_")
		or current_action.begins_with("moving_to_avoid_shelter_")
	)


func _route_recruited_from_avoidance(npc_id: String) -> void:
	if _get_current_behavior_mode(npc_id) != BEHAVIOR_MODE_AVOID_COMBAT:
		return
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system != null and combat_system.has_method("handle_npc_recruited_during_avoidance"):
		combat_system.handle_npc_recruited_during_avoidance(npc_id)


func _interrupt_for_behavior_mode(npc_id: String, mode: String, reason: String, options: Dictionary = {}) -> Dictionary:
	var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) as Node3D if _npc_nodes.has(npc_id) else null
	var world_position_before: Variant = npc_node.global_position if npc_node != null else null
	var result := {
		"dialogue": {},
		"llm": {},
		"action_interrupted": false,
		"movement_stopped": false,
		"proactive_cleared": false,
		"world_position_preserved": npc_node != null,
		"world_position_restored": false
	}
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null and dialog_system.has_method("force_end_dialogue_for_npc"):
		result["dialogue"] = dialog_system.force_end_dialogue_for_npc(npc_id, reason)

	var llm_bridge := get_node_or_null("/root/Main/Systems/LLMBridge")
	if llm_bridge != null and llm_bridge.has_method("cancel_npc_llm_requests"):
		result["llm"] = llm_bridge.cancel_npc_llm_requests(npc_id, reason)

	var state := get_npc_state(npc_id)
	var proactive: Dictionary = state.get("proactive_talk", {}) if (state.get("proactive_talk", {}) is Dictionary) else {}
	if bool(proactive.get("active", false)):
		_clear_proactive_talk(npc_id, "behavior_mode_changed")
		result["proactive_cleared"] = true

	var action_system := get_node_or_null("/root/Main/Systems/ActionSystem")
	if action_system != null and action_system.has_method("interrupt_npc_action"):
		result["action_interrupted"] = bool(action_system.interrupt_npc_action(npc_id, reason))
	if bool(options.get("stop_movement", true)):
		_stop_npc_movement(npc_id)
		_movement_arrival_contexts.erase(npc_id)
		result["movement_stopped"] = true
	# Interrupting a chair/bed/workstation action may detach the presentation
	# anchor through an older cleanup path. A behavior-mode change owns no spatial
	# relocation: the next rally/combat/avoid/work route must start at this exact
	# world position.
	if npc_node != null and world_position_before is Vector3:
		var displacement := npc_node.global_position.distance_to(world_position_before)
		if displacement > 0.0001:
			npc_node.global_position = world_position_before
			result["world_position_restored"] = true
		result["world_position_before"] = world_position_before
		result["world_position_after"] = npc_node.global_position
	return result


func _route_enemy_attack_mode(npc_id: String, enemy_id: String) -> void:
	var profile: Dictionary = _profiles.get(npc_id, {})
	if profile.is_empty():
		return
	var states: Dictionary = profile.get("states", {})
	if bool(states.get("unconscious", false)) or bool(states.get("escaped", false)):
		return
	var target_mode := BEHAVIOR_MODE_COMBAT if _is_npc_combat_eligible(npc_id) else BEHAVIOR_MODE_AVOID_COMBAT
	var current_mode := _get_current_behavior_mode(npc_id)
	# CombatSystem owns armed-NPC target selection. Re-entering the same behavior
	# mode on every hit used to interrupt navigation/attack and force the exact
	# attacker into state before the nearest-target selector could run.
	if target_mode == BEHAVIOR_MODE_COMBAT and current_mode == BEHAVIOR_MODE_COMBAT:
		update_npc_state(npc_id, {"last_action_result": "enemy_attack_combat_lock_preserved"})
		return
	var target_enemy_id := enemy_id if target_mode == BEHAVIOR_MODE_AVOID_COMBAT else ""
	set_npc_behavior_mode(npc_id, target_mode, "enemy_attack", {
		"state_changes": {
			"combat_target_enemy_id": target_enemy_id,
			"last_action_result": "enemy_attack_mode_switch"
		},
		"request_plan_reevaluation": false
	})


func _is_npc_combat_eligible(npc_id: String) -> bool:
	var profile: Dictionary = _profiles.get(npc_id, {})
	if profile.is_empty() or not bool(profile.get("recruited", false)):
		return false
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system != null and equipment_system.has_method("get_unit_type_snapshot"):
		var snapshot: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
		return bool(snapshot.get("has_main_weapon", false))
	var equipment: Dictionary = profile.get("equipment", {}) if (profile.get("equipment", {}) is Dictionary) else {}
	var main_weapon: Dictionary = equipment.get("main_weapon", {}) if (equipment.get("main_weapon", {}) is Dictionary) else {}
	return not main_weapon.is_empty()


func _normalize_llm_activity(raw_activity: Variant) -> Dictionary:
	var activity: Dictionary = raw_activity if raw_activity is Dictionary else {}
	if not bool(activity.get("active", false)):
		return {}
	var kind := str(activity.get("kind", LLM_ACTIVITY_DIALOGUE))
	var label := str(activity.get("label", ""))
	if label.is_empty():
		label = _label_for_llm_activity_kind(kind)
	return {
		"active": true,
		"kind": kind,
		"label": label,
		"request_id": str(activity.get("request_id", "")),
		"cancellable": bool(activity.get("cancellable", true)),
		"started_day": int(activity.get("started_day", _get_game_time_snapshot().get("day", 1))),
		"started_time": str(activity.get("started_time", _get_game_time_snapshot().get("time", "00:00:00"))),
		"reason": str(activity.get("reason", ""))
	}


func _label_for_llm_activity_kind(kind: String) -> String:
	match kind:
		LLM_ACTIVITY_FIRST_SLEEP_SUMMARY:
			return "正在熟睡"
		LLM_ACTIVITY_BATTLE_JUDGEMENT:
			return "正在压住恐惧"
		LLM_ACTIVITY_PLAN:
			return "正在计划下一步行动"
		LLM_ACTIVITY_DIALOGUE:
			return "正在思考"
		_:
			return "正在思考"


func _normalize_progression(raw_progression: Variant) -> Dictionary:
	var source: Dictionary = raw_progression if raw_progression is Dictionary else {}
	var skill_experience: Dictionary = source.get("skill_experience", {})
	var normalized_skill_experience := {}
	for skill_name in PROFESSIONAL_SKILLS + WEAPON_SKILLS:
		normalized_skill_experience[skill_name] = maxi(0, int(skill_experience.get(skill_name, 0)))

	var total_experience := maxi(0, int(source.get("total_experience", 0)))
	return {
		"total_experience": total_experience,
		"next_skill_point_xp": SKILL_POINT_EXPERIENCE_THRESHOLD,
		"unspent_skill_points": maxi(0, int(source.get("unspent_skill_points", source.get("skill_points", 0)))),
		"spent_skill_points": maxi(0, int(source.get("spent_skill_points", 0))),
		"skill_experience": normalized_skill_experience
	}


func _add_growth_experience(profile: Dictionary, skill_name: String, experience_amount: int) -> Dictionary:
	var progression := _normalize_progression(profile.get("progression", {}))
	var gained := maxi(0, experience_amount)
	if gained <= 0:
		return {
			"progression": progression,
			"experience_gained": 0,
			"total_experience": int(progression.get("total_experience", 0)),
			"skill_points_gained": 0,
			"unspent_skill_points": int(progression.get("unspent_skill_points", 0)),
			"skill_experience": int((progression.get("skill_experience", {}) as Dictionary).get(skill_name, 0))
		}

	var skill_experience: Dictionary = progression.get("skill_experience", {})
	skill_experience[skill_name] = maxi(0, int(skill_experience.get(skill_name, 0)) + gained)
	var total_before := int(progression.get("total_experience", 0))
	var total_after := total_before + gained
	var points_before := int(floor(float(total_before) / float(SKILL_POINT_EXPERIENCE_THRESHOLD)))
	var points_after := int(floor(float(total_after) / float(SKILL_POINT_EXPERIENCE_THRESHOLD)))
	var points_gained := maxi(0, points_after - points_before)
	progression["total_experience"] = total_after
	progression["skill_experience"] = skill_experience
	progression["unspent_skill_points"] = int(progression.get("unspent_skill_points", 0)) + points_gained
	progression["next_skill_point_xp"] = SKILL_POINT_EXPERIENCE_THRESHOLD

	return {
		"progression": progression,
		"experience_gained": gained,
		"total_experience": total_after,
		"skill_points_gained": points_gained,
		"unspent_skill_points": int(progression.get("unspent_skill_points", 0)),
		"skill_experience": int(skill_experience.get(skill_name, 0))
	}


func _normalize_attribute_name(attribute_name: String) -> String:
	match attribute_name.strip_edges().to_lower():
		"strength", "str", "力量":
			return "strength"
		"intelligence", "int", "智力":
			return "intelligence"
		_:
			return ""


func _get_attribute_label(attribute_name: String) -> String:
	match attribute_name:
		"strength":
			return "力量"
		"intelligence":
			return "智力"
		_:
			return attribute_name


func _normalize_current_order(raw_order: Variant) -> Dictionary:
	var order: Dictionary = raw_order if raw_order is Dictionary else {}
	return {
		"text": str(order.get("text", "")),
		"issued_by": str(order.get("issued_by", PLAYER_ACTOR_ID)),
		"issued_day": maxi(0, int(order.get("issued_day", 0))),
		"issued_time": str(order.get("issued_time", "")),
		"revision": maxi(0, int(order.get("revision", 0)))
	}


func _normalize_diary_entries(raw_diary: Variant) -> Array:
	var diary: Array = raw_diary if raw_diary is Array else []
	var normalized: Array = []
	for raw_entry in diary:
		if raw_entry is Dictionary:
			var entry := (raw_entry as Dictionary).duplicate(true)
			# T0046 removes the legacy parallel summary so old runtime/save data cannot
			# silently re-enter later LLM contexts through the diary record.
			entry.erase("memory_summary")
			normalized.append(entry)
		else:
			normalized.append(raw_entry)
	return normalized


func _validate_initial_long_memory_dataset(raw_profiles: Array, memory_by_npc: Dictionary) -> Dictionary:
	var expected_npc_ids: Array[String] = []
	for raw_profile in raw_profiles:
		if not raw_profile is Dictionary:
			return {"ok": false, "message": "NPC profile list contains a non-dictionary item."}
		var npc_id := str((raw_profile as Dictionary).get("id", "")).strip_edges()
		if npc_id.is_empty():
			return {"ok": false, "message": "NPC profile contains an empty id."}
		if expected_npc_ids.has(npc_id):
			return {"ok": false, "message": "NPC profile contains a duplicate id: %s" % npc_id}
		expected_npc_ids.append(npc_id)
		if not memory_by_npc.has(npc_id):
			return {"ok": false, "message": "Missing initial long memory for NPC: %s" % npc_id}
		var raw_memory: Variant = memory_by_npc.get(npc_id)
		if not raw_memory is Dictionary:
			return {"ok": false, "message": "Initial long memory is not an object for NPC: %s" % npc_id}
		var initial_memory := raw_memory as Dictionary
		var raw_diary: Variant = initial_memory.get("diary")
		if not raw_diary is Array or (raw_diary as Array).size() < 3:
			return {"ok": false, "message": "Initial diary needs at least three records for NPC: %s" % npc_id}
		for raw_entry in (raw_diary as Array):
			if (
				not raw_entry is Dictionary
				or str((raw_entry as Dictionary).get("entry", "")).strip_edges().is_empty()
				or int((raw_entry as Dictionary).get("day", -1)) != 0
				or str((raw_entry as Dictionary).get("time", "")).strip_edges().is_empty()
				or str((raw_entry as Dictionary).get("source", "")) != "initial_long_memory"
				or str((raw_entry as Dictionary).get("model_provider", "")) != ""
				or str((raw_entry as Dictionary).get("model_name", "")) != ""
				or bool((raw_entry as Dictionary).get("model_fallback_used", true))
				or str((raw_entry as Dictionary).get("debug_reason", "")) != "seeded_before_game"
			):
				return {"ok": false, "message": "Initial diary contains an invalid record for NPC: %s" % npc_id}
		var raw_graph: Variant = initial_memory.get("knowledge_graph")
		if not raw_graph is Dictionary:
			return {"ok": false, "message": "Initial knowledge graph is missing for NPC: %s" % npc_id}
		var graph := raw_graph as Dictionary
		if str(graph.get("schema_version", "")) != "key_value_replace_v1":
			return {"ok": false, "message": "Initial knowledge graph schema mismatch for NPC: %s" % npc_id}
		if graph.has("patches"):
			return {"ok": false, "message": "Initial knowledge graph must not use patches for NPC: %s" % npc_id}
		var raw_subjects: Variant = graph.get("by_subject")
		if not raw_subjects is Dictionary or (raw_subjects as Dictionary).is_empty():
			return {"ok": false, "message": "Initial knowledge graph has no subjects for NPC: %s" % npc_id}
		for raw_subject in (raw_subjects as Dictionary).keys():
			var raw_relations: Variant = (raw_subjects as Dictionary).get(raw_subject)
			if not raw_relations is Dictionary or (raw_relations as Dictionary).is_empty():
				return {
					"ok": false,
					"message": "Initial knowledge subject has no relations for NPC %s: %s" % [
						npc_id,
						str(raw_subject)
					]
				}
			for raw_relation in (raw_relations as Dictionary).keys():
				var raw_record: Variant = (raw_relations as Dictionary).get(raw_relation)
				if (
					not raw_record is Dictionary
					or str((raw_record as Dictionary).get("value", "")).strip_edges().is_empty()
					or str((raw_record as Dictionary).get("subject_label", "")).strip_edges().is_empty()
					or str((raw_record as Dictionary).get("relation_label", "")).strip_edges().is_empty()
					or str((raw_record as Dictionary).get("value_label", "")).strip_edges().is_empty()
					or float((raw_record as Dictionary).get("confidence", -1.0)) < 0.0
					or float((raw_record as Dictionary).get("confidence", -1.0)) > 1.0
					or int((raw_record as Dictionary).get("day", -1)) != 0
					or str((raw_record as Dictionary).get("time", "")) != "开局前"
				):
					return {
						"ok": false,
						"message": "Initial knowledge record is invalid for NPC %s: %s.%s" % [
							npc_id,
							str(raw_subject),
							str(raw_relation)
						]
					}
	if memory_by_npc.size() != expected_npc_ids.size():
		return {
			"ok": false,
			"message": "Initial long memory contains unknown NPC ids; expected %d entries, got %d." % [
				expected_npc_ids.size(),
				memory_by_npc.size()
			]
		}
	return {"ok": true, "message": ""}


func _apply_initial_long_memory(profile: Dictionary, npc_id: String, memory_by_npc: Dictionary) -> bool:
	var raw_memory: Variant = memory_by_npc.get(npc_id)
	if not raw_memory is Dictionary:
		return false
	var initial_memory := raw_memory as Dictionary
	var raw_graph: Variant = initial_memory.get("knowledge_graph")
	if not raw_graph is Dictionary:
		return false
	var graph := raw_graph as Dictionary
	profile["diary"] = _normalize_diary_entries(initial_memory.get("diary", []))
	profile["knowledge_graph"] = {
		"schema_version": "key_value_replace_v1",
		"updated_day": int(graph.get("updated_day", 0)),
		"updated_time": str(graph.get("updated_time", "开局前")),
		"by_subject": _normalize_knowledge_graph_subjects(graph)
	}
	return true


func _apply_knowledge_graph_updates(graph: Dictionary, raw_updates: Variant, day: int, time_text: String) -> Dictionary:
	var updates: Array = raw_updates if raw_updates is Array else []
	var by_subject := _normalize_knowledge_graph_subjects(graph)
	for raw_update in updates:
		if not raw_update is Dictionary:
			continue
		var update: Dictionary = raw_update
		var subject := str(update.get("subject", "")).strip_edges()
		var relation := str(update.get("relation", "")).strip_edges()
		var value := str(update.get("value", "")).strip_edges()
		if subject.is_empty() or relation.is_empty() or value.is_empty():
			continue
		var subject_bucket: Dictionary = by_subject.get(subject, {})
		var previous_record: Dictionary = subject_bucket.get(relation, {}) if subject_bucket.get(relation, {}) is Dictionary else {}
		var subject_label := str(update.get("subject_label", previous_record.get("subject_label", ""))).strip_edges()
		var relation_label := str(update.get("relation_label", previous_record.get("relation_label", ""))).strip_edges()
		var value_label := str(update.get("value_label", previous_record.get("value_label", value))).strip_edges()
		var record := {
			"value": value,
			"confidence": clampf(float(update.get("confidence", 1.0)), 0.0, 1.0),
			"day": day,
			"time": time_text
		}
		if not subject_label.is_empty():
			record["subject_label"] = subject_label
		if not relation_label.is_empty():
			record["relation_label"] = relation_label
		if not value_label.is_empty():
			record["value_label"] = value_label
		subject_bucket[relation] = record
		by_subject[subject] = subject_bucket

	return {
		"schema_version": "key_value_replace_v1",
		"updated_day": day,
		"updated_time": time_text,
		"by_subject": by_subject
	}


func _normalize_knowledge_graph_subjects(graph: Dictionary) -> Dictionary:
	var by_subject: Dictionary = {}
	if graph.get("by_subject", {}) is Dictionary:
		by_subject = (graph.get("by_subject", {}) as Dictionary).duplicate(true)
	for raw_subject in graph.keys():
		var subject := str(raw_subject)
		if ["by_subject", "patches", "schema_version", "updated_day", "updated_time"].has(subject):
			continue
		var raw_bucket: Variant = graph.get(raw_subject)
		if not raw_bucket is Dictionary:
			continue
		var subject_bucket: Dictionary = by_subject.get(subject, {})
		for raw_relation in (raw_bucket as Dictionary).keys():
			var relation := str(raw_relation)
			if relation.is_empty():
				continue
			var raw_value: Variant = (raw_bucket as Dictionary).get(raw_relation)
			if raw_value is Dictionary and (raw_value as Dictionary).has("value"):
				subject_bucket[relation] = (raw_value as Dictionary).duplicate(true)
			else:
				subject_bucket[relation] = {
					"value": str(raw_value),
					"confidence": 1.0,
					"day": 0,
					"time": ""
				}
		by_subject[subject] = subject_bucket
	return by_subject


func _get_game_time_snapshot() -> Dictionary:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return {"day": 1, "time": "00:00:00"}
	return {
		"day": int(game_state.current_day),
		"time": "%02d:%02d:%02d" % [
			int(game_state.current_hour),
			int(game_state.current_minute),
			int(game_state.current_second)
		]
	}


func _log_order_assigned(npc_id: String, old_text: String, new_text: String, revision: int) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "order_assigned",
		"subject_npc_id": npc_id,
		"actor_ids": [PLAYER_ACTOR_ID],
		"target_ids": [npc_id],
		"location_id": _get_current_info_location(npc_id, memory_system),
		"visibility": "private",
		"importance": 65,
		"payload": {
			"previous_order_text": old_text,
			"new_order_text": new_text,
			"order_revision": revision
		}
	})


func _log_attribute_improved(npc_id: String, attribute_name: String, before: int, after: int) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "attribute_improved",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id, attribute_name],
		"location_id": _get_current_info_location(npc_id, memory_system),
		"visibility": "private",
		"importance": 35,
		"payload": {
			"attribute": attribute_name,
			"attribute_label": _get_attribute_label(attribute_name),
			"before": before,
			"after": after,
			"training_kind": "physical" if attribute_name == "strength" else "mental"
		}
	})


func _log_player_interaction(npc_id: String, event_type: String, payload: Dictionary, visibility: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("record_player_interaction"):
		return {}
	var normalized_visibility := "private" if visibility == "private" else "local_public"
	return memory_system.record_player_interaction(npc_id, event_type, payload, normalized_visibility)


func _request_plan_reevaluation_or_defer(npc_id: String, reason: String) -> Dictionary:
	if is_first_sleep_summary_locked(npc_id):
		return defer_plan_reevaluation_until_wake(npc_id, reason)
	return _request_plan_reevaluation(npc_id, reason)


func _request_plan_reevaluation(npc_id: String, reason: String) -> Dictionary:
	var issued_at := _get_game_time_snapshot()
	var request_snapshot := {
		"npc_id": npc_id,
		"reason": reason,
		"day": int(issued_at.get("day", 1)),
		"time": str(issued_at.get("time", "00:00:00")),
		"current_order": get_current_order(npc_id),
		"result": {
			"status": "pending",
			"fallback_used": false,
			"summary": "计划重评估请求已发出，等待 DailyPlanSystem 处理。"
		}
	}
	_store_plan_reevaluation_request(npc_id, request_snapshot)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_plan_reevaluation_requested"):
		event_bus.npc_plan_reevaluation_requested.emit(npc_id, reason)
	return request_snapshot.duplicate(true)


func _store_plan_reevaluation_request(npc_id: String, request_snapshot: Dictionary) -> void:
	_plan_reevaluation_requests_by_npc[npc_id] = request_snapshot.duplicate(true)
	_last_plan_reevaluation_request = request_snapshot.duplicate(true)


func _load_interaction_presentation_config(config_loader: Node) -> void:
	var loaded: Variant = config_loader.load_data_file(NPC_INTERACTION_PRESENTATION_FILE, {})
	if not loaded is Dictionary:
		push_error("NPC interaction presentation config must be a JSON object: %s" % NPC_INTERACTION_PRESENTATION_FILE)
		return
	var config: Dictionary = loaded
	if str(config.get("schema_version", "")) != "npc_interaction_presentation_v1":
		push_error("NPC interaction presentation config schema mismatch: %s" % NPC_INTERACTION_PRESENTATION_FILE)
		return
	var proactive_config: Dictionary = (
		config.get("proactive_talk", {})
		if config.get("proactive_talk", {}) is Dictionary
		else {}
	)
	_proactive_talk_gesture_interval_real_seconds = maxf(
		PROACTIVE_TALK_GESTURE_MIN_INTERVAL_REAL_SECONDS,
		float(proactive_config.get(
			"gesture_interval_real_seconds",
			PROACTIVE_TALK_GESTURE_DEFAULT_INTERVAL_REAL_SECONDS
		))
	)


func _start_proactive_talk_presentation_session(npc_id: String) -> Dictionary:
	_proactive_talk_presentation_session_sequence += 1
	var session_id := "proactive_talk:%s:%06d" % [
		npc_id,
		_proactive_talk_presentation_session_sequence
	]
	_proactive_talk_presentation_sessions[npc_id] = {
		"npc_id": npc_id,
		"session_id": session_id,
		"gesture_count": 0,
		"remaining_real_seconds": _proactive_talk_gesture_interval_real_seconds,
		"gesture_interval_real_seconds": _proactive_talk_gesture_interval_real_seconds
	}
	return _emit_proactive_talk_gesture(npc_id)


func _advance_proactive_talk_presentations(real_delta_seconds: float) -> void:
	if _proactive_talk_presentation_sessions.is_empty():
		return
	var invalid_npc_ids: Array[String] = []
	for raw_npc_id in _proactive_talk_presentation_sessions:
		var npc_id := str(raw_npc_id)
		if not _profiles.has(npc_id) or not has_active_proactive_talk(npc_id):
			invalid_npc_ids.append(npc_id)
			continue
		var state := get_npc_state(npc_id)
		if (
			bool(state.get("unconscious", false))
			or bool(state.get("escaped", false))
			or not _npc_nodes.has(npc_id)
		):
			invalid_npc_ids.append(npc_id)
	for npc_id in invalid_npc_ids:
		if _profiles.has(npc_id) and has_active_proactive_talk(npc_id):
			_clear_proactive_talk(npc_id, "actor_unavailable")
		else:
			_proactive_talk_presentation_sessions.erase(npc_id)
	if _proactive_talk_presentation_sessions.is_empty() or _is_gameplay_paused_for_presentation():
		return
	var safe_delta := maxf(real_delta_seconds, 0.0)
	for raw_npc_id in _proactive_talk_presentation_sessions.keys():
		var npc_id := str(raw_npc_id)
		if not _proactive_talk_presentation_sessions.has(npc_id):
			continue
		var session: Dictionary = _proactive_talk_presentation_sessions[npc_id]
		var remaining := float(session.get("remaining_real_seconds", _proactive_talk_gesture_interval_real_seconds)) - safe_delta
		if remaining > 0.0:
			session["remaining_real_seconds"] = remaining
			_proactive_talk_presentation_sessions[npc_id] = session
			continue
		# One process update may emit at most one gesture. Large frames and resume
		# edges deliberately discard overflow instead of replaying accumulated waves.
		session["remaining_real_seconds"] = _proactive_talk_gesture_interval_real_seconds
		_proactive_talk_presentation_sessions[npc_id] = session
		_emit_proactive_talk_gesture(npc_id)


func _emit_proactive_talk_gesture(npc_id: String) -> Dictionary:
	if not _proactive_talk_presentation_sessions.has(npc_id) or not has_active_proactive_talk(npc_id):
		return {"ok": false, "reason": "proactive_talk_presentation_inactive", "npc_id": npc_id}
	var state := get_npc_state(npc_id)
	if bool(state.get("unconscious", false)) or bool(state.get("escaped", false)):
		return {"ok": false, "reason": "npc_presentation_unavailable", "npc_id": npc_id}
	var npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath("")))
	var camera := get_node_or_null(CAMERA_PATH) as Node3D
	if npc_node == null or camera == null or not npc_node is Node3D:
		return {"ok": false, "reason": "proactive_talk_camera_or_actor_missing", "npc_id": npc_id}
	var facing_direction := camera.global_position - (npc_node as Node3D).global_position
	facing_direction.y = 0.0
	if not set_npc_facing_direction(npc_id, facing_direction):
		return {"ok": false, "reason": "proactive_talk_camera_facing_failed", "npc_id": npc_id}
	if not npc_node.has_method("play_temporary_presentation_action"):
		return {"ok": false, "reason": "npc_presentation_bridge_missing", "npc_id": npc_id}
	var session: Dictionary = _proactive_talk_presentation_sessions[npc_id]
	var gesture_index := int(session.get("gesture_count", 0)) + 1
	var event_id := "%s:gesture:%04d" % [str(session.get("session_id", "")), gesture_index]
	var presentation_result: Dictionary = npc_node.play_temporary_presentation_action("talk_gesture", event_id)
	if not bool(presentation_result.get("ok", false)):
		return presentation_result
	var duplicate := bool(presentation_result.get("duplicate", false))
	if not duplicate:
		session["gesture_count"] = gesture_index
		_proactive_talk_presentation_sessions[npc_id] = session
		_temporary_presentation_event_sequence += 1
	var event := {
		"sequence": _temporary_presentation_event_sequence,
		"event_id": event_id,
		"event_kind": "proactive_talk_gesture",
		"npc_id": npc_id,
		"presentation_session_id": str(session.get("session_id", "")),
		"gesture_index": gesture_index,
		"presentation_action": "talk_gesture",
		"authority_action_at_emit": str(state.get("current_action", "idle")),
		"facing_target": "current_game_camera",
		"facing_direction": facing_direction.normalized(),
		"duplicate": duplicate,
		"duration_seconds": float(presentation_result.get("duration_seconds", 0.0))
	}
	if not duplicate:
		_temporary_presentation_event_history.append(event.duplicate(true))
		if _temporary_presentation_event_history.size() > 32:
			_temporary_presentation_event_history.pop_front()
		npc_temporary_presentation_event_emitted.emit(event.duplicate(true))
	return {"ok": true, "active": true, "event": event}


func _is_gameplay_paused_for_presentation() -> bool:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	return (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	)


func _advance_proactive_talk_timers(game_delta_seconds: float) -> void:
	for npc_id in _npc_order:
		var proactive := get_proactive_talk(npc_id)
		if not bool(proactive.get("active", false)):
			continue
		var remaining := float(proactive.get("remaining_seconds", 0.0)) - game_delta_seconds
		if remaining <= 0.0:
			_clear_proactive_talk(npc_id, "expired")
			_request_plan_reevaluation_or_defer(npc_id, "proactive_talk_expired")
		else:
			proactive["remaining_seconds"] = remaining
			_set_npc_state_without_signal(npc_id, {"proactive_talk": proactive})
			_refresh_npc_node(npc_id)
			_emit_npc_state_changed(npc_id)


func _clear_proactive_talk(npc_id: String, clear_reason: String) -> void:
	_proactive_talk_presentation_sessions.erase(npc_id)
	if not _profiles.has(npc_id):
		return
	var state := get_npc_state(npc_id)
	if not bool(state.get("proactive_talk", {}).get("active", false)):
		return
	var current_action := str(state.get("current_action", ""))
	var changes := {
		"proactive_talk": {},
		"last_action_result": "proactive_talk_%s" % clear_reason
	}
	if current_action == "proactive_talk":
		if bool(state.get("unconscious", false)):
			changes["current_action"] = "unconscious"
		elif bool(state.get("escaped", false)):
			changes["current_action"] = "escaped"
		else:
			changes["current_action"] = "idle"
	_set_npc_state_without_signal(npc_id, changes)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	_emit_npc_proactive_talk_changed(npc_id, false)


func _order_failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "changed": false, "error": code, "message": message}


func _interaction_failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": code, "message": message}


func _clear_spawned_npcs() -> void:
	var npc_root := get_node_or_null(NPC_ROOT_PATH)
	if npc_root == null:
		return

	for child in npc_root.get_children():
		child.queue_free()


func _get_spawn_position(index: int) -> Vector3:
	if index < SPAWN_POINTS.size():
		return SPAWN_POINTS[index]

	var overflow_index := index - SPAWN_POINTS.size()
	return Vector3(-8.0 + float(overflow_index % 8) * 2.3, 0.0, -3.0 - float(overflow_index / 8) * 2.0)


func _pick_npc_at_screen_position(screen_position: Vector2) -> String:
	return str(_pick_npc_interaction_at_screen_position(screen_position).get("npc_id", ""))


func get_world_click_interaction(screen_position: Vector2) -> Dictionary:
	return _pick_npc_interaction_at_screen_position(screen_position)


func select_npc_from_world_click(npc_id: String) -> bool:
	if not _profiles.has(npc_id):
		return false
	_select_npc(npc_id)
	return true


func _is_npc_hidden_by_opaque_building(npc_id: String) -> bool:
	var state := get_npc_state(npc_id)
	var location_id := str(state.get("current_location", ""))
	if location_id.is_empty():
		return false
	for raw_view in get_tree().get_nodes_in_group("building_art_view"):
		var view := raw_view as Node
		if view == null or str(view.get("building_id")) != location_id:
			continue
		var interaction_size: Vector3 = view.get("interaction_bounds_size")
		if interaction_size.x <= 0.0 or interaction_size.y <= 0.0 or interaction_size.z <= 0.0:
			continue
		if view.has_method("is_interior_revealed_for_selection"):
			return not bool(view.call("is_interior_revealed_for_selection"))
	return false


func _pick_npc_interaction_at_screen_position(screen_position: Vector2) -> Dictionary:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	if camera == null:
		return {}

	var world_3d := get_viewport().world_3d
	if world_3d == null:
		return {}

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * PICK_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}

	var collider := result.get("collider") as Node
	if (
		collider != null
		and str(collider.get_meta("interaction_kind", "")) == "autonomous_dialogue_bubble"
		and collider is Node3D
		and (collider as Node3D).visible
	):
		var bubble_npc_id := str(collider.get_meta("npc_id", ""))
		var dialogue_id := str(collider.get_meta("dialogue_id", ""))
		if not bubble_npc_id.is_empty() and not dialogue_id.is_empty():
			return {
				"kind": "autonomous_dialogue_bubble",
				"npc_id": bubble_npc_id,
				"dialogue_id": dialogue_id,
				"collider": collider,
				"distance": ray_origin.distance_to(result.get("position", ray_end)),
				"global_position": result.get("position", ray_end)
			}

	while collider != null:
		var npc_id := str(collider.get_meta("npc_id", ""))
		if not npc_id.is_empty():
			return {
				"kind": "npc",
				"npc_id": npc_id,
				"collider": result.get("collider"),
				"distance": ray_origin.distance_to(result.get("position", ray_end)),
				"global_position": result.get("position", ray_end)
			}
		collider = collider.get_parent()

	return {}


func _select_npc(npc_id: String) -> void:
	if handle_npc_clicked(npc_id):
		return
	_selected_npc_id = npc_id
	print("NPC selected: %s" % npc_id)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_clicked.emit(npc_id)


func _refresh_npc_node(npc_id: String) -> void:
	if not _npc_nodes.has(npc_id):
		return

	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node != null and npc_node.has_method("update_profile"):
		npc_node.update_profile(_profiles[npc_id])


func _emit_npc_state_changed(npc_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_state_changed.emit(npc_id)


func _emit_npc_llm_activity_changed(npc_id: String, activity: Dictionary) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_llm_activity_changed"):
		event_bus.npc_llm_activity_changed.emit(npc_id, activity.duplicate(true))


func _emit_npc_hp_changed(npc_id: String, hp: int, max_hp: int) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_hp_changed"):
		event_bus.npc_hp_changed.emit(npc_id, hp, max_hp)


func _emit_npc_unconscious(npc_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_unconscious"):
		event_bus.npc_unconscious.emit(npc_id)


func _emit_npc_revived(npc_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_revived"):
		event_bus.npc_revived.emit(npc_id)


func _emit_npc_proactive_talk_changed(npc_id: String, active: bool) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_proactive_talk_changed"):
		event_bus.npc_proactive_talk_changed.emit(npc_id, active)


func _emit_npc_daily_plan_changed(npc_id: String, plan: Array) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_daily_plan_changed"):
		event_bus.npc_daily_plan_changed.emit(npc_id, plan.duplicate(true))


func _log_proactive_talk_started(npc_id: String, prompt_text: String, duration_seconds: float) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "proactive_talk_started",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id, PLAYER_ACTOR_ID],
		"location_id": _get_current_info_location(npc_id, memory_system),
		"visibility": "private",
		"importance": 55,
		"payload": {
			"prompt_text": prompt_text,
			"duration_seconds": duration_seconds
		}
	})


func _log_damage_taken(
	npc_id: String,
	actor_id: String,
	damage: int,
	hp_before: int,
	hp_after: int,
	visibility: String,
	options: Dictionary = {}
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}

	var location_id := _get_current_info_location(npc_id, memory_system)
	var payload := {
		"damage": damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"damage_source": actor_id
	}
	for key in [
		"interaction_kind",
		"event_text",
		"attack_prompt",
		"raw_attack_power",
		"target_defense",
		"damage_after_defense"
	]:
		if options.has(key):
			payload[key] = options[key]
	var event := {
		"type": "damage_taken",
		"subject_npc_id": npc_id,
		"actor_ids": [actor_id],
		"target_ids": [npc_id, location_id],
		"location_id": location_id,
		"visibility": visibility,
		"importance": 60,
		"payload": payload
	}
	var summary := str(options.get("summary", "")).strip_edges()
	if not summary.is_empty():
		event["summary"] = summary
	return memory_system.add_event(event)


func _log_unconscious_started(
	npc_id: String,
	actor_id: String,
	damage: int,
	hp_before: int,
	hp_after: int,
	visibility: String
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}

	var location_id := _get_current_info_location(npc_id, memory_system)
	return memory_system.add_event({
		"type": "unconscious_started",
		"subject_npc_id": npc_id,
		"actor_ids": [actor_id],
		"target_ids": [npc_id, location_id],
		"location_id": location_id,
		"visibility": visibility,
		"importance": 85,
		"payload": {
			"damage": damage,
			"hp_before": hp_before,
			"hp_after": hp_after,
			"damage_source": actor_id
		}
	})


func _log_revived(npc_id: String, hp_before: int, hp_after: int, recovery_source: String, visibility: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}

	var location_id := _get_current_info_location(npc_id, memory_system)
	return memory_system.add_event({
		"type": "revived",
		"subject_npc_id": npc_id,
		"actor_ids": [SYSTEM_ACTOR_ID],
		"target_ids": [npc_id, location_id],
		"location_id": location_id,
		"visibility": visibility,
		"importance": 80,
		"payload": {
			"hp_before": hp_before,
			"hp_after": hp_after,
			"recovery_source": recovery_source
		}
	})


func _log_npc_mode_changed(
	npc_id: String,
	from_mode: String,
	to_mode: String,
	reason: String,
	options: Dictionary = {}
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var visibility := str(options.get("visibility", "local_public"))
	if not ["private", "local_public"].has(visibility):
		visibility = "local_public"
	var location_id := _get_current_info_location(npc_id, memory_system)
	return memory_system.add_event({
		"type": "npc_mode_changed",
		"subject_npc_id": npc_id,
		"actor_ids": [str(options.get("trigger_actor_id", SYSTEM_ACTOR_ID))],
		"target_ids": [npc_id, to_mode],
		"location_id": location_id,
		"visibility": visibility,
		"importance": int(options.get("importance", 70)),
		"payload": {
			"npc_id": npc_id,
			"from_mode": from_mode,
			"from_mode_label": _get_behavior_mode_label(from_mode),
			"to_mode": to_mode,
			"to_mode_label": _get_behavior_mode_label(to_mode),
			"reason": reason
		}
	})


func _log_npc_escaped(npc_id: String, arrival_state: Dictionary = {}) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var exit_target_id := str(arrival_state.get("exit_target_id", arrival_state.get("target_id", "back_gate_exit")))
	var exit_target_name := str(arrival_state.get("exit_target_name", arrival_state.get("target_name", "后门外出口")))
	return memory_system.add_event({
		"type": "escaped",
		"subject_npc_id": npc_id,
		"actor_ids": [SYSTEM_ACTOR_ID],
		"target_ids": [npc_id, exit_target_id],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 95,
		"payload": {
			"npc_id": npc_id,
			"exit_target_id": exit_target_id,
			"exit_target_name": exit_target_name,
			"source_event_id": str(arrival_state.get("source_event_id", "")),
			"trigger": str(arrival_state.get("escape_trigger", "")),
			"reason": str(arrival_state.get("escape_reason", "escape_completed"))
		}
	})


func _should_log_npc_mode_changed(from_mode: String, to_mode: String, options: Dictionary = {}) -> bool:
	if bool(options.get("force_mode_event", false)):
		return true
	if bool(options.get("suppress_mode_event", false)):
		return false
	if _is_quiet_behavior_mode_transition(from_mode, to_mode):
		return false
	return true


func _is_quiet_behavior_mode_transition(from_mode: String, to_mode: String) -> bool:
	return (
		(from_mode == BEHAVIOR_MODE_WORK and to_mode == BEHAVIOR_MODE_COMBAT)
		or (from_mode == BEHAVIOR_MODE_COMBAT and to_mode == BEHAVIOR_MODE_WORK)
		or (from_mode == BEHAVIOR_MODE_WORK and to_mode == BEHAVIOR_MODE_AVOID_COMBAT)
		or (from_mode == BEHAVIOR_MODE_AVOID_COMBAT and to_mode == BEHAVIOR_MODE_WORK)
	)


func _get_current_info_location(npc_id: String, memory_system: Node) -> String:
	var state := get_npc_state(npc_id)
	var location_id := str(state.get("current_location", PLAZA_LOCATION_ID))
	if memory_system != null and memory_system.has_method("is_enterable_location") and memory_system.is_enterable_location(location_id):
		return location_id
	return PLAZA_LOCATION_ID


func _get_location_entry_availability(location_id: String, building_system: Node = null) -> Dictionary:
	if location_id == PLAZA_LOCATION_ID:
		return {
			"ok": true,
			"building_id": location_id,
			"is_enterable": true,
			"is_accessible": true,
			"is_operational": true,
			"is_activity_available": true,
			"unavailable_reason": ""
		}
	if building_system == null:
		building_system = get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		return {
			"ok": false,
			"building_id": location_id,
			"is_enterable": false,
			"is_accessible": false,
			"is_operational": false,
			"is_activity_available": false,
			"unavailable_reason": "building_system_missing"
		}
	if building_system.has_method("get_building_availability"):
		return building_system.get_building_availability(location_id)
	var building: Dictionary = building_system.get_building(location_id) if building_system.has_method("get_building") else {}
	if building.is_empty():
		return {
			"ok": false,
			"building_id": location_id,
			"is_enterable": false,
			"is_accessible": false,
			"is_operational": false,
			"is_activity_available": false,
			"unavailable_reason": "unknown_building"
		}
	var enterable := int(building.get("hp", 0)) > 0 and str(building.get("condition", "")) != "upgrading"
	return {
		"ok": enterable,
		"building_id": location_id,
		"is_enterable": enterable,
		"is_accessible": enterable,
		"is_operational": enterable,
		"is_activity_available": enterable,
		"unavailable_reason": "" if enterable else "building_unavailable"
	}


func _is_location_available_for_entry(location_id: String, building_system: Node = null) -> bool:
	return bool(_get_location_entry_availability(location_id, building_system).get("is_enterable", false))


func _is_location_available_for_access(location_id: String, building_system: Node = null) -> bool:
	var availability := _get_location_entry_availability(location_id, building_system)
	return bool(availability.get("is_accessible", availability.get("is_operational", false)))


func _redirect_npc_to_plaza(npc_id: String, unavailable_building_id: String, building_system: Node = null) -> void:
	if not _profiles.has(npc_id):
		return
	var availability := _get_location_entry_availability(unavailable_building_id, building_system)
	_set_npc_state_without_signal(npc_id, {
		# ActionSystem writes a structured failure when an actual dependency was
		# interrupted. Plain occupants are only evicted and must not trigger replan.
		"last_action_result": "building_evicted_to_plaza",
		"last_action_failure_context": {
			"building_id": unavailable_building_id,
			"condition": str(availability.get("condition", "unknown")),
			"unavailable_reason": str(availability.get("unavailable_reason", "building_unavailable")),
			"is_enterable": false,
			"is_operational": bool(availability.get("is_operational", false)),
			"is_activity_available": false
		}
	})
	if move_npc_to_building(npc_id, PLAZA_LOCATION_ID):
		return
	debug_enter_location_immediately(npc_id, PLAZA_LOCATION_ID)


func _settle_failed_building_entry(
	npc_id: String,
	unavailable_building_id: String,
	availability: Dictionary
) -> void:
	if not _profiles.has(npc_id):
		return
	_stop_npc_movement(npc_id)
	_movement_arrival_contexts.erase(npc_id)
	var previous_state: Dictionary = get_npc_state(npc_id)
	var previous_location_id := str(previous_state.get("current_location", PLAZA_LOCATION_ID))
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	var location_context: Dictionary = {}
	if memory_system != null and memory_system.has_method("is_enterable_location"):
		location_context = _transition_npc_info_location(
			npc_id,
			_get_info_location_id(memory_system, previous_location_id),
			PLAZA_LOCATION_ID,
			PLAZA_LOCATION_ID,
			memory_system
		)
	var failure_context := availability.duplicate(true)
	failure_context["building_id"] = unavailable_building_id
	failure_context["arrival_check_failed"] = true
	failure_context["current_location_before_failure"] = previous_location_id
	_set_npc_state_without_signal(npc_id, {
		"current_action": "idle",
		"current_location": PLAZA_LOCATION_ID,
		"current_location_name": str(location_context.get("name", "广场")),
		"movement_target": "",
		"movement_target_name": "",
		"location_context": location_context,
		# ActionSystem owns any pending action failure and emits the final
		# building-specific result after this arrival state has settled.
		"last_action_result": "building_entry_rejected",
		"last_action_failure_context": failure_context,
		"spatial_route_phase": "entry_rejected",
		"physical_location_phase": "door_outside",
		"reserved_building_id": "",
		"reserved_workstation_id": "",
		"current_workstation_id": ""
	})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_building_entry_failed"):
		event_bus.npc_building_entry_failed.emit(
			npc_id,
			unavailable_building_id,
			failure_context.duplicate(true)
		)


func _on_building_state_changed(building_id: String) -> void:
	if building_id.is_empty() or _building_eviction_guards.has(building_id):
		return
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if _is_location_available_for_access(building_id, building_system):
		return
	_building_eviction_guards[building_id] = true
	for raw_pilot_npc_id in _formal_navigation_pilots.keys().duplicate():
		var pilot_npc_id := str(raw_pilot_npc_id)
		var pilot: Dictionary = _formal_navigation_pilots.get(pilot_npc_id, {})
		if str(pilot.get("building_id", "")) != building_id:
			continue
		_debug_stop_formal_navigation_pilot_npc(pilot_npc_id, "building_unavailable")
	for raw_npc_id in _npc_order:
		var npc_id := str(raw_npc_id)
		if (
			_formal_workstation_action_sessions.has(npc_id)
			and str((_formal_workstation_action_sessions[npc_id] as Dictionary).get("building_id", "")) == building_id
		):
			# ActionSystem owns this work interruption and restores the formal
			# session after releasing its reservation / occupancy.
			continue
		var state: Dictionary = get_npc_state(npc_id)
		if str(state.get("current_location", "")) != building_id:
			continue
		if str(state.get("movement_target", "")) == PLAZA_LOCATION_ID:
			continue
		if not can_npc_act(npc_id):
			continue
		_redirect_npc_to_plaza(npc_id, building_id, building_system)
	_building_eviction_guards.erase(building_id)


func _on_npc_movement_arrived(npc_id: String, building_id: String) -> void:
	if not _profiles.has(npc_id):
		return
	if _building_interior_routes.has(npc_id):
		_on_building_interior_route_arrived(npc_id, building_id)
		return
	if _movement_arrival_contexts.has(npc_id):
		_on_custom_movement_arrived(npc_id, building_id)
		return

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var availability := _get_location_entry_availability(building_id, building_system)
	if not bool(availability.get("is_accessible", availability.get("is_operational", false))):
		_settle_failed_building_entry(npc_id, building_id, availability)
		return
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	var location_context: Dictionary = {}
	var building_name := building_id
	var previous_state: Dictionary = get_npc_state(npc_id)
	var previous_location_id := str(previous_state.get("current_location", "plaza"))
	var info_location_id := building_id
	var previous_info_location_id := previous_location_id
	if memory_system != null and memory_system.has_method("is_enterable_location"):
		previous_info_location_id = _get_info_location_id(memory_system, previous_location_id)
		if not memory_system.is_enterable_location(building_id):
			info_location_id = "plaza"
		location_context = _transition_npc_info_location(
			npc_id,
			previous_info_location_id,
			building_id,
			info_location_id,
			memory_system
		)
	if location_context.is_empty() and building_system != null:
		location_context = building_system.get_building_location_context(building_id)
		building_name = str(location_context.get("name", building_id))
	elif building_system != null and building_id != PLAZA_LOCATION_ID:
		var building: Dictionary = building_system.get_building(building_id)
		building_name = str(building.get("name", location_context.get("name", building_id)))
	else:
		building_name = str(location_context.get("name", building_id))

	_set_npc_state_without_signal(npc_id, {
		"current_action": "idle",
		"current_location": building_id,
		"current_location_name": building_name,
		"movement_target": "",
		"movement_target_name": "",
		"location_context": location_context,
		"spatial_route_phase": "none",
		"physical_location_phase": "legacy_location",
		"current_workstation_id": ""
	})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)


func _on_npc_movement_request_failed(npc_id: String, _target_id: String, reason: String) -> void:
	if not _profiles.has(npc_id):
		return
	if _building_interior_routes.has(npc_id):
		_settle_navigation_route_failure(npc_id, reason)
		return
	var failed_context: Dictionary = _movement_arrival_contexts.get(npc_id, {})
	_movement_arrival_contexts.erase(npc_id)
	_restore_healing_crowd_recovery_from_movement_context(npc_id, failed_context)
	_set_npc_state_without_signal(npc_id, {
		"current_action": "idle",
		"movement_target": "",
		"movement_target_name": "",
		"last_action_result": "movement_failed_%s" % reason,
		"last_action_failure_context": {"reason": reason},
		"spatial_route_phase": "navigation_failed"
	})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)


func _settle_navigation_route_failure(npc_id: String, reason: String) -> void:
	var route: Dictionary = _building_interior_routes.get(npc_id, {})
	_release_npc_spatial_reservation(npc_id)
	_building_interior_routes.erase(npc_id)
	_stop_npc_movement(npc_id)
	if _formal_navigation_pilots.has(npc_id):
		var pilot: Dictionary = _formal_navigation_pilots[npc_id]
		if bool(pilot.get("occupancy_committed", false)):
			var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
			if building_system != null:
				building_system.release_workstation(
					str(pilot.get("building_id", "")),
					npc_id,
					str(pilot.get("workstation_id", ""))
				)
		pilot["occupancy_committed"] = false
		pilot["attachment_committed"] = false
		_formal_navigation_pilots[npc_id] = pilot
		var pilot_node := get_node_or_null(_npc_nodes[npc_id]) if _npc_nodes.has(npc_id) else null
		if pilot_node != null and pilot_node.has_method("detach_from_spatial_anchor"):
			pilot_node.detach_from_spatial_anchor()
	var state := get_npc_state(npc_id)
	var current_location_id := str(state.get("current_location", PLAZA_LOCATION_ID))
	var route_building_id := str(route.get("building_id", ""))
	_set_npc_state_without_signal(npc_id, {
		"current_action": "idle",
		"movement_target": "",
		"movement_target_name": "",
		"last_action_result": "movement_failed_%s" % reason,
		"last_action_failure_context": {
			"reason": reason,
			"building_id": str(route.get("building_id", "")),
			"workstation_id": str(route.get("workstation_id", "")),
			"route_source": str(route.get("route_source", ""))
		},
		"spatial_route_phase": "navigation_failed",
		"physical_location_phase": "interior" if not route_building_id.is_empty() and current_location_id == route_building_id else "outdoor_path",
		"reserved_building_id": "",
		"reserved_workstation_id": "",
		"current_workstation_id": ""
	})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)


func _on_building_interior_route_arrived(npc_id: String, target_id: String) -> void:
	var route: Dictionary = _building_interior_routes.get(npc_id, {})
	var steps: Array = route.get("steps", [])
	var step_index := int(route.get("step_index", 0))
	if step_index < 0 or step_index >= steps.size() or not steps[step_index] is Dictionary:
		_cancel_building_interior_route(npc_id, true)
		return
	var step: Dictionary = steps[step_index]
	if str(step.get("id", "")) != target_id:
		return
	var building_id := str(route.get("building_id", FIRST_SPATIAL_INTERIOR_BUILDING_ID))
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if bool(step.get("check_entry", false)):
		var availability := _get_location_entry_availability(building_id, building_system)
		if not bool(availability.get("is_accessible", availability.get("is_operational", false))):
			_cancel_building_interior_route(npc_id, true)
			_settle_failed_building_entry(npc_id, building_id, availability)
			return

	var transition_changes: Dictionary = {}
	var state := get_npc_state(npc_id)
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if bool(step.get("crosses_entry", false)):
		var location_context: Dictionary = {}
		if memory_system != null:
			location_context = _transition_npc_info_location(
				npc_id,
				_get_info_location_id(memory_system, str(state.get("current_location", PLAZA_LOCATION_ID))),
				building_id,
				building_id,
				memory_system
			)
		var building_name := str(building_system.get_building(building_id).get("name", building_id)) if building_system != null else building_id
		transition_changes = {
			"current_location": building_id,
			"current_location_name": building_name,
			"location_context": location_context
		}
	elif bool(step.get("crosses_exit", false)):
		var plaza_context: Dictionary = {}
		if memory_system != null:
			plaza_context = _transition_npc_info_location(
				npc_id,
				_get_info_location_id(memory_system, str(state.get("current_location", building_id))),
				PLAZA_LOCATION_ID,
				PLAZA_LOCATION_ID,
				memory_system
			)
		transition_changes = {
			"current_location": PLAZA_LOCATION_ID,
			"current_location_name": str(plaza_context.get("name", "广场")),
			"location_context": plaza_context,
			"current_workstation_id": ""
		}
	route["step_index"] = step_index + 1
	_building_interior_routes[npc_id] = route
	if int(route.get("step_index", 0)) < steps.size():
		_start_current_building_route_step(npc_id, transition_changes)
		return

	_building_interior_routes.erase(npc_id)
	if str(route.get("kind", "")) == "entry":
		var workstation_id := str(route.get("workstation_id", ""))
		var workstation_type := str(route.get("workstation_type", FIRST_FORMAL_NAVIGATION_PILOT_WORKSTATION_TYPE))
		if bool(route.get("commit_reservation_on_arrival", false)) and not workstation_id.is_empty():
			var commit_result: Dictionary = (
				building_system.commit_workstation_reservation(
					building_id,
					npc_id,
					workstation_id,
					workstation_type
				)
				if building_system != null and building_system.has_method("commit_workstation_reservation")
				else {"ok": false, "reason": "building_system_missing"}
			)
			if not bool(commit_result.get("ok", false)):
				_settle_navigation_route_failure(
					npc_id,
					str(commit_result.get("reason", "workstation_commit_failed"))
				)
				return
			if _formal_navigation_pilots.has(npc_id):
				var pilot: Dictionary = _formal_navigation_pilots[npc_id]
				pilot["occupancy_committed"] = true
				_formal_navigation_pilots[npc_id] = pilot
		var final_facing: Variant = step.get("facing_direction", Vector3.ZERO)
		var npc_node := get_node_or_null(_npc_nodes[npc_id]) if _npc_nodes.has(npc_id) else null
		if final_facing is Vector3:
			var final_facing_direction: Vector3 = final_facing
			if final_facing_direction.length_squared() <= 0.0001:
				final_facing_direction = Vector3.ZERO
			if npc_node != null and npc_node.has_method("set_facing_direction"):
				npc_node.set_facing_direction(final_facing_direction)
		var arrival_mode := str(step.get("arrival_mode", "stand"))
		var attachment_committed := false
		# Formal gameplay actions let ActionSystem revalidate their service
		# dependency and commit the reserved workstation first. Only the pure GM
		# navigation pilot mounts here; gameplay patients mount through
		# attach_formal_workstation_occupant() after occupancy becomes authoritative.
		if arrival_mode == "mount_after_arrival" and not _formal_workstation_action_sessions.has(npc_id):
			var anchor_position: Variant = step.get("occupant_anchor_position")
			var anchor_facing: Variant = step.get("occupant_anchor_facing_direction", Vector3.ZERO)
			var occupant_pose := str(step.get("occupant_pose", ""))
			attachment_committed = (
				npc_node != null
				and npc_node.has_method("attach_to_spatial_anchor")
				and anchor_position is Vector3
				and anchor_facing is Vector3
				and bool(npc_node.attach_to_spatial_anchor(anchor_position, anchor_facing, occupant_pose))
			)
			if not attachment_committed:
				if building_system != null:
					building_system.release_workstation(building_id, npc_id, workstation_id)
				if _formal_navigation_pilots.has(npc_id):
					var failed_pilot: Dictionary = _formal_navigation_pilots[npc_id]
					failed_pilot["occupancy_committed"] = false
					_formal_navigation_pilots[npc_id] = failed_pilot
				_settle_navigation_route_failure(npc_id, "occupant_attachment_failed")
				return
			if _formal_navigation_pilots.has(npc_id):
				var attached_pilot: Dictionary = _formal_navigation_pilots[npc_id]
				attached_pilot["attachment_committed"] = true
				_formal_navigation_pilots[npc_id] = attached_pilot
		var final_changes := transition_changes.duplicate(true)
		final_changes.merge({
			"current_action": "idle",
			"movement_target": "",
			"movement_target_name": "",
			"spatial_route_phase": "occupant_attached" if attachment_committed else ("workstation_arrived" if not workstation_id.is_empty() else "interior_arrived"),
			"physical_location_phase": "occupant_anchor" if attachment_committed else ("workstation" if not workstation_id.is_empty() else "interior"),
			"current_workstation_id": workstation_id,
			"last_action_result": "occupant_attached" if attachment_committed else ("workstation_arrived" if not workstation_id.is_empty() else "interior_arrived"),
			"reserved_building_id": "" if bool(route.get("commit_reservation_on_arrival", false)) else str(state.get("reserved_building_id", "")),
			"reserved_workstation_id": "" if bool(route.get("commit_reservation_on_arrival", false)) else str(state.get("reserved_workstation_id", ""))
		}, true)
		_set_npc_state_without_signal(npc_id, final_changes)
		_refresh_npc_node(npc_id)
		_emit_npc_state_changed(npc_id)
		return

	var destination_id := str(route.get("destination_building_id", PLAZA_LOCATION_ID))
	_set_npc_state_without_signal(npc_id, transition_changes)
	if _formal_workstation_action_sessions.has(npc_id):
		if destination_id == PLAZA_LOCATION_ID:
			var formal_session: Dictionary = _formal_workstation_action_sessions[npc_id]
			if bool(formal_session.get("continue_to_exterior_after_exit", false)):
				formal_session["continue_to_exterior_after_exit"] = false
				_formal_workstation_action_sessions[npc_id] = formal_session
				if _start_formal_exterior_service_route(npc_id):
					return
				_settle_navigation_route_failure(npc_id, "formal_exterior_destination_route_failed")
				return
			if _start_formal_public_location_route(npc_id, destination_id):
				return
			_settle_navigation_route_failure(npc_id, "formal_public_destination_route_failed")
			return
		var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		var destination_route: Dictionary = (
			controller.get_building_spatial_route(destination_id)
			if controller != null and controller.has_method("get_building_spatial_route")
			else {}
		)
		if not destination_route.is_empty() and _start_building_entry_route(
			npc_id,
			destination_id,
			"",
			destination_route
		):
			return
		_settle_navigation_route_failure(npc_id, "formal_destination_route_failed")
		return
	if _default_formal_world_npcs.has(npc_id):
		if destination_id == PLAZA_LOCATION_ID:
			if _start_formal_public_location_route(npc_id, destination_id):
				return
			_settle_navigation_route_failure(npc_id, "default_formal_public_route_failed")
			return
		var resident_controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		var resident_route: Dictionary = (
			resident_controller.get_building_spatial_route(destination_id)
			if resident_controller != null and resident_controller.has_method("get_building_spatial_route")
			else {}
		)
		if not resident_route.is_empty() and _start_building_entry_route(npc_id, destination_id, "", resident_route):
			return
		_settle_navigation_route_failure(npc_id, "default_formal_destination_route_failed")
		return
	if not _move_npc_to_building_direct(npc_id, destination_id, true):
		_set_npc_state_without_signal(npc_id, {
			"current_action": "idle",
			"movement_target": "",
			"movement_target_name": "",
			"spatial_route_phase": "exit_complete",
			"physical_location_phase": "outdoor_path",
			"last_action_result": "exit_destination_unavailable"
		})
		_refresh_npc_node(npc_id)
		_emit_npc_state_changed(npc_id)


func _on_custom_movement_arrived(npc_id: String, target_id: String) -> void:
	var context: Dictionary = _movement_arrival_contexts.get(npc_id, {})
	_movement_arrival_contexts.erase(npc_id)
	_restore_healing_crowd_recovery_from_movement_context(npc_id, context)

	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	var previous_state: Dictionary = get_npc_state(npc_id)
	var previous_location_id := str(previous_state.get("current_location", PLAZA_LOCATION_ID))
	var location_context: Dictionary = {}
	var arrival_state: Dictionary = context.get("arrival_state", {}) if (context.get("arrival_state", {}) is Dictionary) else {}
	if (
		not bool(arrival_state.get("preserve_location_context", false))
		and memory_system != null
		and memory_system.has_method("is_enterable_location")
	):
		var previous_info_location_id := _get_info_location_id(memory_system, previous_location_id)
		location_context = _transition_npc_info_location(
			npc_id,
			previous_info_location_id,
			PLAZA_LOCATION_ID,
			PLAZA_LOCATION_ID,
			memory_system
		)

	var target_name := str(context.get("target_name", target_id))
	if bool(arrival_state.get("preserve_location_context", false)):
		location_context = previous_state.get("location_context", {}).duplicate(true) if previous_state.get("location_context", {}) is Dictionary else {}
	var changes := {
		"current_action": str(arrival_state.get("current_action", "idle")),
		"current_location": str(arrival_state.get("current_location", target_id)),
		"current_location_name": str(arrival_state.get("current_location_name", target_name)),
		"movement_target": "",
		"movement_target_name": "",
		"location_context": location_context
	}
	for key in arrival_state.keys():
		if [
			"arrival_facing_direction",
			"attach_clinic_study_on_arrival",
			"attach_clinic_treatment_on_arrival",
			"clinic_treatment_anchor_position",
			"clinic_treatment_anchor_facing_direction",
			"departure_current_action",
			"departure_state",
			"escape_finalize",
			"escape_reason",
			"escape_trigger",
			"source_event_id",
			"exit_target_id",
			"exit_target_name",
			"preserve_location_context"
		].has(str(key)):
			continue
		changes[str(key)] = arrival_state[key]
	if bool(arrival_state.get("escape_finalize", false)):
		var escape_intent: Dictionary = previous_state.get("escape_intent", {}) if previous_state.get("escape_intent", {}) is Dictionary else {}
		var time_snapshot := _get_game_time_snapshot()
		escape_intent["active"] = false
		escape_intent["status"] = "escaped"
		escape_intent["completed_day"] = int(time_snapshot.get("day", 1))
		escape_intent["completed_time"] = str(time_snapshot.get("time", "00:00:00"))
		escape_intent["exit_target_id"] = str(arrival_state.get("exit_target_id", target_id))
		escape_intent["exit_target_name"] = str(arrival_state.get("exit_target_name", target_name))
		escape_intent["completed_world_position"] = get_npc_world_position(npc_id)
		changes["escape_intent"] = escape_intent
		changes["escaped"] = true
		changes["unconscious"] = false
		changes["behavior_mode"] = BEHAVIOR_MODE_ESCAPED
		changes["behavior_mode_reason"] = str(arrival_state.get("escape_reason", "escape_completed"))
		changes["current_action"] = "escaped"
		changes["current_location"] = "outside_station"
		changes["current_location_name"] = "驿站外"
		changes["location_context"] = {}
		changes["last_action_result"] = "escaped_station"
	if bool(arrival_state.get("attach_clinic_study_on_arrival", false)):
		var workstation_id := str(changes.get("current_workstation_id", ""))
		var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		var study_route: Dictionary = (
			controller.get_building_spatial_route(CLINIC_FORMAL_NAVIGATION_PILOT_BUILDING_ID, workstation_id)
			if controller != null and controller.has_method("get_building_spatial_route")
			else {}
		)
		var anchor_position: Variant = study_route.get("occupant_anchor_position")
		var anchor_facing: Variant = study_route.get("occupant_anchor_facing_direction", Vector3.ZERO)
		var occupant_pose := str(study_route.get("occupant_pose", ""))
		var study_npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) if _npc_nodes.has(npc_id) else null
		var attached := (
			study_npc_node != null
			and study_npc_node.has_method("attach_to_spatial_anchor")
			and anchor_position is Vector3
			and anchor_facing is Vector3
			and bool(study_npc_node.attach_to_spatial_anchor(anchor_position, anchor_facing, occupant_pose))
		)
		if attached:
			changes["spatial_route_phase"] = "occupant_attached"
			changes["physical_location_phase"] = "occupant_anchor"
			changes["last_action_result"] = "clinic_study_seated"
			if _formal_workstation_action_sessions.has(npc_id):
				var session: Dictionary = _formal_workstation_action_sessions[npc_id]
				session["attachment_committed"] = true
				_formal_workstation_action_sessions[npc_id] = session
		else:
			changes["spatial_route_phase"] = "clinic_study_attachment_failed"
			changes["physical_location_phase"] = "workstation"
			changes["last_action_result"] = "clinic_study_attachment_failed"
	if bool(arrival_state.get("attach_clinic_treatment_on_arrival", false)):
		var treatment_anchor_position: Variant = arrival_state.get("clinic_treatment_anchor_position")
		var treatment_anchor_facing: Variant = arrival_state.get("clinic_treatment_anchor_facing_direction")
		var treatment_npc_node := get_node_or_null(_npc_nodes.get(npc_id, NodePath())) if _npc_nodes.has(npc_id) else null
		var treatment_attached := (
			treatment_npc_node != null
			and treatment_npc_node.has_method("attach_to_spatial_anchor")
			and treatment_anchor_position is Vector3
			and treatment_anchor_facing is Vector3
			and bool(treatment_npc_node.attach_to_spatial_anchor(
				treatment_anchor_position,
				treatment_anchor_facing,
				"standing_treatment",
				false
			))
		)
		if treatment_attached:
			changes["spatial_route_phase"] = "clinic_round_treatment_attached"
			changes["physical_location_phase"] = "clinic_bedside"
			changes["last_action_result"] = "clinic_treatment_anchor_attached"
			if _formal_workstation_action_sessions.has(npc_id):
				var treatment_session: Dictionary = _formal_workstation_action_sessions[npc_id]
				treatment_session["attachment_committed"] = true
				treatment_session["clinic_treatment_safe_position"] = context.get("target_position")
				treatment_session["clinic_treatment_anchor_position"] = treatment_anchor_position
				_formal_workstation_action_sessions[npc_id] = treatment_session
		else:
			changes["spatial_route_phase"] = "clinic_round_treatment_attachment_failed"
			changes["last_action_result"] = "clinic_treatment_attachment_failed"
	_set_npc_state_without_signal(npc_id, changes)
	var arrival_facing: Variant = arrival_state.get("arrival_facing_direction")
	if arrival_facing is Vector3:
		var npc_node := get_node_or_null(_npc_nodes[npc_id]) if _npc_nodes.has(npc_id) else null
		if npc_node != null and npc_node.has_method("set_facing_direction"):
			npc_node.set_facing_direction(arrival_facing)
	if (
		bool(arrival_state.get("escape_finalize", false))
		and memory_system != null
		and memory_system.has_method("remove_npc_from_all_locations")
	):
		memory_system.remove_npc_from_all_locations(npc_id)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	if bool(arrival_state.get("escape_finalize", false)):
		_log_npc_escaped(npc_id, arrival_state)
		var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
		if combat_system != null and combat_system.has_method("handle_npc_escape_completed"):
			combat_system.handle_npc_escape_completed(npc_id, changes.duplicate(true))


func debug_enter_location_immediately(
	npc_id: String,
	location_id: String,
	emit_state_changed: bool = true
) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot set location for unknown NPC: %s" % npc_id)
		return false
	_cancel_building_interior_route(npc_id, true)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if not _is_location_available_for_entry(location_id, building_system):
		var availability := _get_location_entry_availability(location_id, building_system)
		push_warning("Cannot place NPC %s inside unavailable building %s: %s" % [
			npc_id,
			location_id,
			str(availability.get("unavailable_reason", "building_unavailable"))
		])
		return false

	var previous_state: Dictionary = get_npc_state(npc_id)
	var previous_location_id := str(previous_state.get("current_location", "plaza"))
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	var info_location_id := location_id
	var previous_info_location_id := previous_location_id
	var location_context: Dictionary = {}
	if memory_system != null and memory_system.has_method("is_enterable_location"):
		previous_info_location_id = _get_info_location_id(memory_system, previous_location_id)
		if not memory_system.is_enterable_location(location_id):
			info_location_id = "plaza"
		location_context = _transition_npc_info_location(
			npc_id,
			previous_info_location_id,
			location_id,
			info_location_id,
			memory_system
		)

	_set_npc_state_without_signal(npc_id, {
		"current_action": "idle",
		"current_location": location_id,
		"current_location_name": str(location_context.get("name", location_id)),
		"movement_target": "",
		"movement_target_name": "",
		"location_context": location_context,
		"spatial_route_phase": "debug_teleport",
		"physical_location_phase": "debug_location",
		"reserved_building_id": "",
		"reserved_workstation_id": "",
		"current_workstation_id": ""
	})
	_refresh_npc_node(npc_id)
	if emit_state_changed:
		_emit_npc_state_changed(npc_id)
	return true


func _transition_npc_info_location(
	npc_id: String,
	from_info_location_id: String,
	to_location_id: String,
	to_info_location_id: String,
	memory_system: Node
) -> Dictionary:
	if memory_system == null or not memory_system.has_method("move_npc_between_locations"):
		return {}

	var normalized_from_info := _get_info_location_id(memory_system, from_info_location_id)
	var normalized_to_info := _get_info_location_id(memory_system, to_info_location_id)
	if normalized_from_info == normalized_to_info:
		return memory_system.move_npc_between_locations(npc_id, normalized_from_info, normalized_to_info)

	if _should_route_between_indoor_locations_through_plaza(normalized_from_info, normalized_to_info):
		memory_system.move_npc_between_locations(npc_id, normalized_from_info, PLAZA_LOCATION_ID)
		_log_location_exited(npc_id, normalized_from_info, PLAZA_LOCATION_ID)
		_log_location_entered(npc_id, normalized_from_info, PLAZA_LOCATION_ID, PLAZA_LOCATION_ID)

		var final_context: Dictionary = memory_system.move_npc_between_locations(npc_id, PLAZA_LOCATION_ID, normalized_to_info)
		_log_location_exited(npc_id, PLAZA_LOCATION_ID, normalized_to_info)
		_log_location_entered(npc_id, PLAZA_LOCATION_ID, to_location_id, normalized_to_info)
		return final_context

	var location_context: Dictionary = memory_system.move_npc_between_locations(npc_id, normalized_from_info, normalized_to_info)
	_log_location_exited(npc_id, normalized_from_info, normalized_to_info)
	_log_location_entered(npc_id, normalized_from_info, to_location_id, normalized_to_info)
	return location_context


func _should_route_between_indoor_locations_through_plaza(from_info_location_id: String, to_info_location_id: String) -> bool:
	return (
		from_info_location_id != PLAZA_LOCATION_ID
		and to_info_location_id != PLAZA_LOCATION_ID
		and from_info_location_id != to_info_location_id
	)


func _log_location_entered(
	npc_id: String,
	from_location_id: String,
	to_location_id: String,
	event_location_id: String,
	location_context: Dictionary = {}
) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return

	memory_system.add_event({
		"type": "location_entered",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [to_location_id],
		"location_id": event_location_id,
		"visibility": "local_public",
		"importance": 20,
		"payload": {
			"from_location_id": from_location_id,
			"to_location_id": to_location_id
		}
	})


func _log_location_exited(npc_id: String, from_location_id: String, to_location_id: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return
	if from_location_id.is_empty() or from_location_id == to_location_id:
		return

	memory_system.add_event({
		"type": "location_exited",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [from_location_id, to_location_id],
		"location_id": from_location_id,
		"visibility": "local_public",
		"importance": 20,
		"payload": {
			"from_location_id": from_location_id,
			"to_location_id": to_location_id
		}
	})


func _get_info_location_id(memory_system: Node, location_id: String) -> String:
	if memory_system != null and memory_system.has_method("is_enterable_location") and memory_system.is_enterable_location(location_id):
		return location_id
	return PLAZA_LOCATION_ID


func debug_get_npc_character_art_snapshot(npc_id: String) -> Dictionary:
	if not _npc_nodes.has(npc_id):
		return {"ok": false, "error": "npc_node_not_found", "npc_id": npc_id}
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("debug_get_character_art_snapshot"):
		return {"ok": false, "error": "character_art_snapshot_unavailable", "npc_id": npc_id}
	var snapshot: Dictionary = npc_node.debug_get_character_art_snapshot()
	snapshot["ok"] = bool(snapshot.get("ready", false))
	return snapshot
