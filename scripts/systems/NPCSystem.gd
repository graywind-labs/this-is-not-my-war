extends Node

const NPC_PROFILES_FILE := "npc_profiles.json"
const NPC_SCENE_PATH := "res://scenes/npc/NPC.tscn"
const NPC_ROOT_PATH := "/root/Main/WorldRoot/Station/NPCs"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const PLAZA_LOCATION_ID := "plaza"
const PLAYER_ACTOR_ID := "guard_officer"
const SYSTEM_ACTOR_ID := "system"
const MONEY_RESOURCE_ID := "money"
const PICK_RAY_LENGTH := 1000.0
const PROFESSIONAL_SKILLS: Array[String] = ["养马", "厨艺", "耕种", "打铁", "教练", "酿酒", "医术", "工程"]
const WEAPON_SKILLS: Array[String] = ["剑盾", "长杆", "弓", "弩", "骑术"]
const ATTRIBUTE_NAMES: Array[String] = ["strength", "intelligence"]
const SPECIALTY_THRESHOLD := 25
const SKILL_POINT_EXPERIENCE_THRESHOLD := 5
const ATTRIBUTE_MIN_VALUE := 0
const ATTRIBUTE_MAX_VALUE := 10
const UNCONSCIOUS_NATURAL_RECOVERY_HP_PER_HOUR := 2.0
const UNCONSCIOUS_HEALING_BASE_HP_PER_HOUR := 2.0
const UNCONSCIOUS_HEALING_MAX_BONUS_HP_PER_HOUR := 10.0
const UNCONSCIOUS_HEALING_SKILL_THRESHOLD := 20.0
const REVIVE_HP_RATIO := 0.3
const PROACTIVE_TALK_DEFAULT_DURATION_SECONDS := 3600.0
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
var _selected_npc_id: String = ""
var _unconscious_recovery_remainders: Dictionary = {}
var _last_plan_reevaluation_request: Dictionary = {}


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
		event_bus.logical_time_tick.connect(_on_logical_time_tick)


func initialize() -> void:
	_clear_spawned_npcs()
	_profiles.clear()
	_npc_order.clear()
	_npc_nodes.clear()
	_movement_arrival_contexts.clear()
	_unconscious_recovery_remainders.clear()
	_last_plan_reevaluation_request.clear()
	_selected_npc_id = ""

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("NPCSystem requires ConfigLoader autoload.")
		return

	var loaded_profiles: Variant = config_loader.load_data_file(NPC_PROFILES_FILE, [])
	if not loaded_profiles is Array:
		push_error("NPC profiles must be a JSON array: %s" % NPC_PROFILES_FILE)
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

		var profile: Dictionary = raw_profile
		var npc_id := str(profile.get("id", ""))
		if npc_id.is_empty():
			push_error("Skipped NPC profile with empty id.")
			continue
		if _profiles.has(npc_id):
			push_error("Skipped duplicate NPC id: %s" % npc_id)
			continue

		profile["skills"] = normalize_skills(profile.get("skills", {}))
		profile["current_order"] = _normalize_current_order(profile.get("current_order", {}))
		var npc_node := npc_scene.instantiate()
		npc_root.add_child(npc_node)
		npc_node.global_position = _get_spawn_position(_npc_order.size())
		if npc_node.has_method("setup"):
			npc_node.setup(profile)
		if npc_node.has_signal("movement_arrived"):
			npc_node.movement_arrived.connect(_on_npc_movement_arrived)

		_profiles[npc_id] = profile.duplicate(true)
		_ensure_runtime_state_defaults(npc_id)
		_npc_order.append(npc_id)
		_npc_nodes[npc_id] = npc_node.get_path()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var npc_id := _pick_npc_at_screen_position(event.position)
		if not npc_id.is_empty():
			_select_npc(npc_id)
			get_viewport().set_input_as_handled()


func get_npc(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Unknown NPC id: %s" % npc_id)
		return {}
	return _profiles[npc_id].duplicate(true)


func get_npc_state(npc_id: String) -> Dictionary:
	var profile := get_npc(npc_id)
	if profile.is_empty():
		return {}
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
		"combat_strategy": state.get("combat_strategy", {}),
		"combat_strategy_move_target_id": str(state.get("combat_strategy_move_target_id", "")),
		"combat_strategy_move_target_name": str(state.get("combat_strategy_move_target_name", "")),
		"combat_strategy_move_target_position": state.get("combat_strategy_move_target_position", {}),
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

	var previous_mode := _get_current_behavior_mode(npc_id)
	var interrupt_modes := [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT, BEHAVIOR_MODE_AVOID_COMBAT]
	var should_interrupt := bool(options.get("interrupt", interrupt_modes.has(clean_mode)))
	var interrupt_result := {}
	if should_interrupt:
		interrupt_result = _interrupt_for_behavior_mode(npc_id, clean_mode, reason, options)

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
			changes["combat_strategy_move_target_id"] = ""
			changes["combat_strategy_move_target_name"] = ""
			changes["combat_strategy_move_target_position"] = {}
			if not changes.has("current_action"):
				changes["current_action"] = "avoid_combat"
		BEHAVIOR_MODE_UNCONSCIOUS:
			changes["combat_mode"] = ""
			changes["combat_mounted"] = false
			changes["combat_attack_cooldown"] = 0.0
			changes["combat_last_attack_result"] = {}
			changes["combat_strategy_move_target_id"] = ""
			changes["combat_strategy_move_target_name"] = ""
			changes["combat_strategy_move_target_position"] = {}
			changes["avoidance_target_id"] = ""
			changes["avoidance_target_name"] = ""
			changes["avoidance_target_position"] = {}
			changes["current_action"] = "unconscious"
		BEHAVIOR_MODE_ESCAPED:
			changes["combat_mode"] = ""
			changes["combat_mounted"] = false
			changes["combat_attack_cooldown"] = 0.0
			changes["combat_last_attack_result"] = {}
			changes["combat_strategy_move_target_id"] = ""
			changes["combat_strategy_move_target_name"] = ""
			changes["combat_strategy_move_target_position"] = {}
			changes["avoidance_target_id"] = ""
			changes["avoidance_target_name"] = ""
			changes["avoidance_target_position"] = {}
		BEHAVIOR_MODE_WORK:
			changes["combat_mode"] = ""
			changes["combat_mounted"] = false
			changes["combat_target_enemy_id"] = ""
			changes["combat_attack_cooldown"] = 0.0
			changes["combat_last_attack_result"] = {}
			changes["combat_strategy_move_target_id"] = ""
			changes["combat_strategy_move_target_name"] = ""
			changes["combat_strategy_move_target_position"] = {}
			changes["avoidance_target_id"] = ""
			changes["avoidance_target_name"] = ""
			changes["avoidance_target_position"] = {}
			if _should_clear_action_when_returning_to_work(str(state.get("current_action", "")), options):
				changes["current_action"] = "idle"
			if not changes.has("last_action_result"):
				changes["last_action_result"] = reason

	_set_npc_state_without_signal(npc_id, changes)
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
	return {
		"ok": true,
		"npc_id": npc_id,
		"previous_mode": previous_mode,
		"behavior_mode": clean_mode,
		"reason": reason,
		"changed": previous_mode != clean_mode,
		"interrupt_result": interrupt_result,
		"event": mode_event,
		"plan_reevaluation_status": reevaluation_status
	}


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

	var target_position: Variant = building_system.get_building_entry_position(building_id)
	if target_position == null:
		push_warning("Cannot move NPC %s to building without entry position: %s" % [npc_id, building_id])
		return false

	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("move_to_location"):
		push_warning("Cannot move NPC because node has no movement API: %s" % npc_id)
		return false

	var building_name := "广场" if building_id == PLAZA_LOCATION_ID else str(building_system.get_building(building_id).get("name", building_id))
	_set_npc_state_without_signal(npc_id, {
		"current_action": "moving_to_%s" % building_id,
		"movement_target": building_id,
		"movement_target_name": building_name,
		"location_context": {}
	})
	npc_node.move_to_location(building_id, target_position)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func move_npc_to_world_position(
	npc_id: String,
	target_id: String,
	target_name: String,
	target_position: Vector3,
	arrival_state: Dictionary = {}
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
		"arrival_state": arrival_state.duplicate(true)
	}
	_set_npc_state_without_signal(npc_id, {
		"current_action": "moving_to_%s" % clean_target_id,
		"movement_target": clean_target_id,
		"movement_target_name": clean_target_name,
		"location_context": {}
	})
	npc_node.move_to_location(clean_target_id, target_position)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func stop_npc_movement_with_state(npc_id: String, changes: Dictionary = {}) -> bool:
	if not _profiles.has(npc_id):
		return false
	_stop_npc_movement(npc_id)
	_movement_arrival_contexts.erase(npc_id)
	if not changes.is_empty():
		_set_npc_state_without_signal(npc_id, changes)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func debug_move_npc_to_building(npc_id: String, building_id: String) -> bool:
	return move_npc_to_building(npc_id, building_id)


func debug_move_selected_npc_to_building(building_id: String) -> bool:
	if _selected_npc_id.is_empty():
		push_warning("Cannot move selected NPC because no NPC is selected.")
		return false
	return move_npc_to_building(_selected_npc_id, building_id)


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


func stop_npc_movement_for_system(npc_id: String, last_result: String = "movement_stopped") -> bool:
	if not _profiles.has(npc_id):
		return false
	_stop_npc_movement(npc_id)
	_movement_arrival_contexts.erase(npc_id)
	_set_npc_state_without_signal(npc_id, {
		"current_action": "idle",
		"movement_target": "",
		"movement_target_name": "",
		"last_action_result": last_result
	})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


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
		"proactive_talk": proactive_state
	})
	var event := _log_proactive_talk_started(npc_id, clean_text, duration)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	_emit_npc_proactive_talk_changed(npc_id, true)
	return {
		"ok": true,
		"npc_id": npc_id,
		"proactive_talk": proactive_state.duplicate(true),
		"event": event
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


func handle_npc_clicked(npc_id: String) -> bool:
	if _profiles.has(npc_id) and _is_escape_intervenable_state(get_npc_state(npc_id)):
		return false
	if not has_active_proactive_talk(npc_id):
		return false
	var proactive := get_proactive_talk(npc_id)
	var prompt_text := str(proactive.get("prompt_text", "")).strip_edges()
	_clear_proactive_talk(npc_id, "clicked")
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("start_proactive_player_dialogue"):
		return false
	var result: Dictionary = dialog_system.start_proactive_player_dialogue(npc_id, prompt_text)
	return bool(result.get("ok", false))


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
	_last_plan_reevaluation_request = {
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
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return _last_plan_reevaluation_request.duplicate(true)


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
	if _last_plan_reevaluation_request.is_empty():
		return
	if str(_last_plan_reevaluation_request.get("npc_id", "")) != npc_id:
		return
	if str(_last_plan_reevaluation_request.get("reason", "")) != reason:
		return
	_last_plan_reevaluation_request["result"] = result.duplicate(true)


func can_npc_act(npc_id: String) -> bool:
	if not _profiles.has(npc_id):
		return false
	var state := get_npc_state(npc_id)
	return (
		not bool(state.get("unconscious", false))
		and not bool(state.get("escaped", false))
		and not _is_npc_escaping_state(state)
		and not bool(state.get("first_sleep_summary_active", false))
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
		states["last_action_result"] = "became_unconscious"
	profile["states"] = states
	_profiles[npc_id] = profile

	if became_unconscious:
		_stop_npc_movement(npc_id)
	_refresh_npc_node(npc_id)
	_emit_npc_hp_changed(npc_id, hp_after, max_hp)
	_emit_npc_state_changed(npc_id)

	var damage_event := _log_damage_taken(npc_id, actor_id, damage, hp_before, hp_after, visibility, options)
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
		"diary": (profile.get("diary", []) as Array).duplicate(true) if (profile.get("diary", []) is Array) else []
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
	var time_text := str(_get_game_time_snapshot().get("time", "00:00:00"))
	var diary: Array = profile.get("diary", []) if (profile.get("diary", []) is Array) else []
	var diary_record := {
		"day": day,
		"time": time_text,
		"entry": diary_entry,
		"memory_summary": str(reflection.get("memory_summary", "")),
		"source": str(reflection.get("source", "daily_reflection")),
		"debug_reason": str(reflection.get("debug_reason", ""))
	}
	diary.append(diary_record)
	profile["diary"] = diary

	var graph: Dictionary = profile.get("knowledge_graph", {}) if (profile.get("knowledge_graph", {}) is Dictionary) else {}
	graph = _apply_knowledge_graph_updates(graph, reflection.get("knowledge_graph_updates", []), day, time_text)
	profile["knowledge_graph"] = graph
	_profiles[npc_id] = profile

	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"day": day,
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


func _ensure_runtime_state_defaults(npc_id: String) -> void:
	var profile: Dictionary = _profiles[npc_id]
	profile["skills"] = normalize_skills(profile.get("skills", {}))
	profile["current_order"] = _normalize_current_order(profile.get("current_order", {}))
	profile["progression"] = _normalize_progression(profile.get("progression", {}))
	if not (profile.get("knowledge_graph", {}) is Dictionary):
		profile["knowledge_graph"] = {}
	if not (profile.get("diary", []) is Array):
		profile["diary"] = []
	var states: Dictionary = profile.get("states", {})
	if not states.has("current_location"):
		states["current_location"] = "plaza"
	if not states.has("location_context"):
		states["location_context"] = {}
	if not states.has("proactive_talk"):
		states["proactive_talk"] = {}
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
	var result := {
		"dialogue": {},
		"llm": {},
		"action_interrupted": false,
		"movement_stopped": false,
		"proactive_cleared": false
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
	return result


func _route_enemy_attack_mode(npc_id: String, enemy_id: String) -> void:
	var profile: Dictionary = _profiles.get(npc_id, {})
	if profile.is_empty():
		return
	var states: Dictionary = profile.get("states", {})
	if bool(states.get("unconscious", false)) or bool(states.get("escaped", false)):
		return
	var target_mode := BEHAVIOR_MODE_COMBAT if _is_npc_combat_eligible(npc_id) else BEHAVIOR_MODE_AVOID_COMBAT
	set_npc_behavior_mode(npc_id, target_mode, "enemy_attack", {
		"state_changes": {
			"combat_target_enemy_id": enemy_id,
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
		subject_bucket[relation] = {
			"value": value,
			"confidence": clampf(float(update.get("confidence", 1.0)), 0.0, 1.0),
			"day": day,
			"time": time_text
		}
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
		"actor_ids": [PLAYER_ACTOR_ID],
		"target_ids": [npc_id, attribute_name],
		"location_id": _get_current_info_location(npc_id, memory_system),
		"visibility": "private",
		"importance": 35,
		"payload": {
			"attribute": attribute_name,
			"attribute_label": _get_attribute_label(attribute_name),
			"before": before,
			"after": after,
			"assigned_by": PLAYER_ACTOR_ID
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
	_last_plan_reevaluation_request = {
		"npc_id": npc_id,
		"reason": reason,
		"day": int(issued_at.get("day", 1)),
		"time": str(issued_at.get("time", "00:00:00")),
		"current_order": get_current_order(npc_id),
		"result": {
			"status": "pending",
			"fallback_used": true,
			"summary": "计划重评估请求已发出，等待 DailyPlanSystem 处理。"
		}
	}
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_plan_reevaluation_requested"):
		event_bus.npc_plan_reevaluation_requested.emit(npc_id, reason)
	return _last_plan_reevaluation_request.duplicate(true)


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
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	if camera == null:
		return ""

	var world_3d := get_viewport().world_3d
	if world_3d == null:
		return ""

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * PICK_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return ""

	var collider := result.get("collider") as Node
	while collider != null:
		var npc_id := str(collider.get_meta("npc_id", ""))
		if not npc_id.is_empty():
			return npc_id
		collider = collider.get_parent()

	return ""


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


func _on_npc_movement_arrived(npc_id: String, building_id: String) -> void:
	if not _profiles.has(npc_id):
		return
	if _movement_arrival_contexts.has(npc_id):
		_on_custom_movement_arrived(npc_id, building_id)
		return

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
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
		"location_context": location_context
	})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)


func _on_custom_movement_arrived(npc_id: String, target_id: String) -> void:
	var context: Dictionary = _movement_arrival_contexts.get(npc_id, {})
	_movement_arrival_contexts.erase(npc_id)

	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	var previous_state: Dictionary = get_npc_state(npc_id)
	var previous_location_id := str(previous_state.get("current_location", PLAZA_LOCATION_ID))
	var location_context: Dictionary = {}
	if memory_system != null and memory_system.has_method("is_enterable_location"):
		var previous_info_location_id := _get_info_location_id(memory_system, previous_location_id)
		location_context = _transition_npc_info_location(
			npc_id,
			previous_info_location_id,
			PLAZA_LOCATION_ID,
			PLAZA_LOCATION_ID,
			memory_system
		)

	var target_name := str(context.get("target_name", target_id))
	var arrival_state: Dictionary = context.get("arrival_state", {}) if (context.get("arrival_state", {}) is Dictionary) else {}
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
			"escape_finalize",
			"escape_reason",
			"escape_trigger",
			"source_event_id",
			"exit_target_id",
			"exit_target_name"
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
	_set_npc_state_without_signal(npc_id, changes)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	if bool(arrival_state.get("escape_finalize", false)):
		_log_npc_escaped(npc_id, arrival_state)
		var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
		if combat_system != null and combat_system.has_method("handle_npc_escape_completed"):
			combat_system.handle_npc_escape_completed(npc_id, changes.duplicate(true))


func debug_enter_location_immediately(npc_id: String, location_id: String) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot set location for unknown NPC: %s" % npc_id)
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
		"location_context": location_context
	})
	_refresh_npc_node(npc_id)
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
