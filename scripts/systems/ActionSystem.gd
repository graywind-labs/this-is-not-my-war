extends Node

const ACTION_DEFS_FILE := "action_defs.json"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const PLAZA_LOCATION_ID := "plaza"
const DEFAULT_WORK_DURATION_HOURS := 1
const DEFAULT_WORK_DURATION_SECONDS := 3600.0
const HEALING_ACTION_ID := "assist_heal"
const HEALING_RESOURCE_ID := "money"
const HEALING_INITIAL_COST := 1
const HEALING_COST_INTERVAL_SECONDS := 1800.0
const HEALING_MAX_HELPERS_PER_TARGET := 2
const CLINIC_LOCATION_ID := "clinic"
const CLINIC_DOCTOR_ACTION_ID := "work_clinic_doctor"
const CLINIC_PATIENT_ACTION_ID := "receive_clinic_treatment"
const CLINIC_DOCTOR_WORKSTATION_TYPE := "clinic_doctor"
const CLINIC_PATIENT_BED_TYPE := "patient_bed"
const CLINIC_STUDY_SKILL_INTERVAL_SECONDS := 14400.0
const CLINIC_TREATMENT_SKILL_INTERVAL_SECONDS := 3600.0
const CLINIC_BASE_HP_PER_HOUR := 6.0
const CLINIC_SKILL_HP_PER_HOUR := 0.10
const CLINIC_INTELLIGENCE_HP_PER_HOUR := 0.45
const CLINIC_LEVEL_HP_PER_HOUR := 3.0
const WORK_SKILL_SPEED_SCALE := 0.50
const WORK_ATTRIBUTE_SPEED_SCALE := 0.025
const WORK_BUILDING_LEVEL_SPEED_SCALE := 0.15
const WORK_MAX_SPEED_MULTIPLIER := 2.5
const WORK_OUTPUT_DEFAULT_SKILL_PER_BONUS := 50
const WORK_OUTPUT_DEFAULT_ATTRIBUTE_BASELINE := 5
const WORK_OUTPUT_DEFAULT_ATTRIBUTE_PER_BONUS := 3

var _actions: Dictionary = {}
var _actions_by_location: Dictionary = {}
var _pending_actions: Dictionary = {}
var _pending_action_targets: Dictionary = {}
var _active_actions: Dictionary = {}
var _healing_helpers_by_target: Dictionary = {}


func initialize() -> void:
	_actions.clear()
	_actions_by_location.clear()
	_pending_actions.clear()
	_pending_action_targets.clear()
	_active_actions.clear()
	_healing_helpers_by_target.clear()

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("ActionSystem requires ConfigLoader autoload.")
		return

	var loaded_defs: Variant = config_loader.load_data_file(ACTION_DEFS_FILE, [])
	if not loaded_defs is Array:
		push_error("Action definitions must be a JSON array: %s" % ACTION_DEFS_FILE)
		return

	for raw_definition in loaded_defs:
		if not raw_definition is Dictionary:
			push_error("Skipped invalid action definition because it is not a dictionary.")
			continue

		var definition: Dictionary = raw_definition
		var action_id := str(definition.get("id", ""))
		if action_id.is_empty():
			push_error("Skipped action definition with empty id.")
			continue

		_actions[action_id] = definition.duplicate(true)
		var location_id := str(definition.get("location_required", ""))
		if not location_id.is_empty():
			if not _actions_by_location.has(location_id):
				_actions_by_location[location_id] = []
			_actions_by_location[location_id].append(action_id)


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_state_changed.connect(_on_npc_state_changed)
		event_bus.gameplay_pause_changed.connect(_on_gameplay_pause_changed)
		event_bus.logical_time_tick.connect(_on_logical_time_tick)


func get_action(action_id: String) -> Dictionary:
	if not _actions.has(action_id):
		push_warning("Unknown action id: %s" % action_id)
		return {}
	return _actions[action_id].duplicate(true)


func get_action_ids() -> Array[String]:
	var ids: Array[String] = []
	for action_id in _actions.keys():
		ids.append(str(action_id))
	ids.sort()
	return ids


func debug_assign_work(npc_id: String, building_id: String) -> bool:
	var action_id := _find_work_action_for_building(building_id)
	if action_id.is_empty():
		push_warning("No work action configured for building: %s" % building_id)
		return false
	return debug_assign_action(npc_id, action_id)


func debug_assign_eat(npc_id: String) -> bool:
	return debug_assign_action(npc_id, "eat_at_dining_hall")


func debug_assign_sleep(npc_id: String) -> bool:
	return debug_assign_action(npc_id, "sleep_in_dormitory")


func debug_assign_action(npc_id: String, action_id: String) -> bool:
	if not _actions.has(action_id):
		push_warning("Cannot assign unknown action: %s" % action_id)
		return false
	if action_id == HEALING_ACTION_ID:
		push_warning("assist_heal requires a target NPC. Use debug_assign_heal_assist(healer_npc_id, target_npc_id).")
		return false
	if not _can_npc_act(npc_id):
		return false
	if _active_actions.has(npc_id):
		push_warning("NPC is already performing an active action: %s" % npc_id)
		return false

	var action: Dictionary = _actions[action_id]
	var location_id := str(action.get("location_required", ""))
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false

	if not location_id.is_empty():
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("current_location", "")) != location_id:
			_pending_actions[npc_id] = action_id
			_pending_action_targets.erase(npc_id)
			return npc_system.move_npc_to_building(npc_id, location_id)

	if _is_gameplay_paused():
		_pending_actions[npc_id] = action_id
		_pending_action_targets.erase(npc_id)
		return true

	return _execute_action(npc_id, action_id)


func debug_assign_repair_assist(npc_id: String, building_id: String) -> bool:
	if building_id.is_empty() or not _can_npc_act(npc_id):
		return false
	if _active_actions.has(npc_id):
		push_warning("NPC is already performing an active action: %s" % npc_id)
		return false

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("is_repair_in_progress"):
		return false
	if not building_system.is_repair_in_progress(building_id):
		push_warning("Cannot assist repair because no repair is active: %s" % building_id)
		return false

	var npc_system := _get_npc_system()
	if npc_system == null:
		return false

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_location", "")) != PLAZA_LOCATION_ID:
		_pending_actions[npc_id] = "assist_repair"
		_pending_action_targets[npc_id] = building_id
		return npc_system.move_npc_to_building(npc_id, PLAZA_LOCATION_ID)

	if _is_gameplay_paused():
		_pending_actions[npc_id] = "assist_repair"
		_pending_action_targets[npc_id] = building_id
		return true

	return _execute_repair_assist(npc_id, building_id)


func debug_assign_upgrade_assist(npc_id: String, building_id: String) -> bool:
	if building_id.is_empty() or not _can_npc_act(npc_id):
		return false
	if _active_actions.has(npc_id):
		push_warning("NPC is already performing an active action: %s" % npc_id)
		return false

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("is_upgrade_in_progress"):
		return false
	if not building_system.is_upgrade_in_progress(building_id):
		push_warning("Cannot assist upgrade because no upgrade is active: %s" % building_id)
		return false

	var npc_system := _get_npc_system()
	if npc_system == null:
		return false

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_location", "")) != PLAZA_LOCATION_ID:
		_pending_actions[npc_id] = "assist_upgrade"
		_pending_action_targets[npc_id] = building_id
		return npc_system.move_npc_to_building(npc_id, PLAZA_LOCATION_ID)

	if _is_gameplay_paused():
		_pending_actions[npc_id] = "assist_upgrade"
		_pending_action_targets[npc_id] = building_id
		return true

	return _execute_upgrade_assist(npc_id, building_id)


func debug_assign_heal_assist(healer_npc_id: String, target_npc_id: String) -> bool:
	if healer_npc_id.is_empty() or target_npc_id.is_empty():
		return false
	if healer_npc_id == target_npc_id:
		push_warning("NPC cannot assist healing themselves: %s" % healer_npc_id)
		return false
	if not _can_npc_act(healer_npc_id):
		return false
	if _active_actions.has(healer_npc_id):
		push_warning("NPC is already performing an active action: %s" % healer_npc_id)
		return false
	if not _is_npc_unconscious(target_npc_id):
		push_warning("Cannot assist healing because target is not unconscious: %s" % target_npc_id)
		return false
	if _get_healing_helper_count(target_npc_id) >= HEALING_MAX_HELPERS_PER_TARGET:
		push_warning("Cannot assist healing because target already has max helpers: %s" % target_npc_id)
		return false
	if not _can_pay_healing_cost():
		_update_action_failure(healer_npc_id, "assist_heal_failed_no_money")
		return false

	var npc_system := _get_npc_system()
	if npc_system == null:
		return false

	var target_location_id := _get_target_healing_location(target_npc_id)
	var healer_state: Dictionary = npc_system.get_npc_state(healer_npc_id)
	if str(healer_state.get("current_location", "")) != target_location_id:
		_pending_actions[healer_npc_id] = HEALING_ACTION_ID
		_pending_action_targets[healer_npc_id] = target_npc_id
		return npc_system.move_npc_to_building(healer_npc_id, target_location_id)

	if _is_gameplay_paused():
		_pending_actions[healer_npc_id] = HEALING_ACTION_ID
		_pending_action_targets[healer_npc_id] = target_npc_id
		return true

	return _execute_heal_assist(healer_npc_id, target_npc_id)


func has_pending_action(npc_id: String) -> bool:
	return _pending_actions.has(npc_id)


func has_active_action(npc_id: String) -> bool:
	return _active_actions.has(npc_id)


func get_healing_helpers_for_target(target_npc_id: String) -> Array[String]:
	var result: Array[String] = []
	var helpers: Array = _healing_helpers_by_target.get(target_npc_id, [])
	for raw_helper_id in helpers:
		var helper_id := str(raw_helper_id)
		if not helper_id.is_empty() and not result.has(helper_id):
			result.append(helper_id)
	return result


func _on_npc_state_changed(npc_id: String) -> void:
	if _is_npc_unconscious_or_escaped(npc_id):
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_stop_active_action(npc_id, "")
		return
	if _is_gameplay_paused():
		return
	_try_execute_pending_action(npc_id)


func _on_gameplay_pause_changed(paused: bool) -> void:
	if paused:
		return

	for npc_id in _pending_actions.keys():
		_try_execute_pending_action(str(npc_id))


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0 or _active_actions.is_empty():
		return

	var npc_ids := _active_actions.keys()
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		if not _active_actions.has(npc_id):
			continue
		_advance_active_action(npc_id, game_delta_seconds)


func _try_execute_pending_action(npc_id: String) -> void:
	if not _pending_actions.has(npc_id):
		return
	if not _can_npc_act(npc_id):
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		return

	var action_id := str(_pending_actions[npc_id])
	if action_id == "assist_repair":
		_try_execute_pending_repair_assist(npc_id)
		return
	if action_id == "assist_upgrade":
		_try_execute_pending_upgrade_assist(npc_id)
		return
	if action_id == HEALING_ACTION_ID:
		_try_execute_pending_heal_assist(npc_id)
		return

	if not _actions.has(action_id):
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		return

	var npc_system := _get_npc_system()
	if npc_system == null:
		return

	var action: Dictionary = _actions[action_id]
	var location_id := str(action.get("location_required", ""))
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		(location_id.is_empty() or str(state.get("current_location", "")) == location_id)
		and str(state.get("current_action", "")) == "idle"
		and not _active_actions.has(npc_id)
	):
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_execute_action(npc_id, action_id)


func _try_execute_pending_repair_assist(npc_id: String) -> void:
	var building_id := str(_pending_action_targets.get(npc_id, ""))
	if building_id.is_empty():
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		return

	var npc_system := _get_npc_system()
	if npc_system == null:
		return

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_location", "")) == PLAZA_LOCATION_ID and str(state.get("current_action", "")) == "idle":
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_execute_repair_assist(npc_id, building_id)


func _try_execute_pending_upgrade_assist(npc_id: String) -> void:
	var building_id := str(_pending_action_targets.get(npc_id, ""))
	if building_id.is_empty():
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		return

	var npc_system := _get_npc_system()
	if npc_system == null:
		return

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_location", "")) == PLAZA_LOCATION_ID and str(state.get("current_action", "")) == "idle":
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_execute_upgrade_assist(npc_id, building_id)


func _try_execute_pending_heal_assist(npc_id: String) -> void:
	var target_npc_id := str(_pending_action_targets.get(npc_id, ""))
	if target_npc_id.is_empty():
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		return

	var npc_system := _get_npc_system()
	if npc_system == null:
		return

	var target_location_id := _get_target_healing_location(target_npc_id)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_location", "")) == target_location_id and str(state.get("current_action", "")) == "idle":
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_execute_heal_assist(npc_id, target_npc_id)


func _execute_action(npc_id: String, action_id: String) -> bool:
	var action: Dictionary = _actions[action_id]
	var action_type := str(action.get("type", ""))
	match action_type:
		"work":
			return _start_work(npc_id, action)
		"eat":
			return _start_eat(npc_id, action)
		"sleep":
			return _start_sleep(npc_id, action)
		"clinic_doctor":
			return _start_clinic_doctor(npc_id, action)
		"clinic_patient":
			return _start_clinic_patient(npc_id, action)
		"targeted_heal":
			push_warning("assist_heal requires a target NPC. Use debug_assign_heal_assist(healer_npc_id, target_npc_id).")
			return false
		_:
			push_warning("Unsupported action type: %s" % action_type)
			return false


func _execute_repair_assist(npc_id: String, building_id: String) -> bool:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null or building_system == null:
		return false
	if not building_system.has_method("add_repair_helper") or not building_system.is_repair_in_progress(building_id):
		_update_action_failure(npc_id, "assist_repair_failed_no_active_repair")
		return false

	var npc: Dictionary = npc_system.get_npc(npc_id)
	var engineering_skill := _get_engineering_skill(npc)
	var ok: bool = building_system.add_repair_helper(building_id, npc_id, engineering_skill)
	if not ok:
		_update_action_failure(npc_id, "assist_repair_failed")
		return false

	npc_system.update_npc_state(npc_id, {
		"current_action": "assist_repair_%s" % building_id,
		"last_action_result": "assist_repair_started_%s" % building_id
	})

	_log_structured_action_event(npc_id, {
		"id": "assist_repair",
		"location_required": PLAZA_LOCATION_ID,
		"base_duration_hours": 0,
		"visibility": "local_public"
	}, "repair_assist_started", {
		"action_id": "assist_repair",
		"building_id": building_id,
		"engineering_skill": engineering_skill
	})
	return true


func _execute_upgrade_assist(npc_id: String, building_id: String) -> bool:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null or building_system == null:
		return false
	if not building_system.has_method("add_upgrade_helper") or not building_system.is_upgrade_in_progress(building_id):
		_update_action_failure(npc_id, "assist_upgrade_failed_no_active_upgrade")
		return false

	var npc: Dictionary = npc_system.get_npc(npc_id)
	var engineering_skill := _get_engineering_skill(npc)
	var ok: bool = building_system.add_upgrade_helper(building_id, npc_id, engineering_skill)
	if not ok:
		_update_action_failure(npc_id, "assist_upgrade_failed")
		return false

	npc_system.update_npc_state(npc_id, {
		"current_action": "assist_upgrade_%s" % building_id,
		"last_action_result": "assist_upgrade_started_%s" % building_id
	})

	_log_structured_action_event(npc_id, {
		"id": "assist_upgrade",
		"location_required": PLAZA_LOCATION_ID,
		"base_duration_hours": 0,
		"visibility": "local_public"
	}, "upgrade_assist_started", {
		"action_id": "assist_upgrade",
		"building_id": building_id,
		"engineering_skill": engineering_skill
	})
	return true


func _execute_heal_assist(healer_npc_id: String, target_npc_id: String) -> bool:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false
	if not _is_npc_unconscious(target_npc_id):
		_update_action_failure(healer_npc_id, "assist_heal_failed_target_not_unconscious")
		return false
	if _get_healing_helper_count(target_npc_id) >= HEALING_MAX_HELPERS_PER_TARGET:
		_update_action_failure(healer_npc_id, "assist_heal_failed_target_helper_limit")
		return false
	if not _spend_healing_cost():
		_update_action_failure(healer_npc_id, "assist_heal_failed_no_money")
		_log_healing_event(healer_npc_id, target_npc_id, "healing_completed", {
			"action_id": HEALING_ACTION_ID,
			"healer_npc_id": healer_npc_id,
			"target_npc_id": target_npc_id,
			"money_spent": 0
		})
		return false

	var healer: Dictionary = npc_system.get_npc(healer_npc_id)
	var medical_skill := _get_medical_skill(healer)
	_add_healing_helper(target_npc_id, healer_npc_id)
	npc_system.update_npc_state(healer_npc_id, {
		"current_action": "assist_heal_%s" % target_npc_id,
		"last_action_result": "assist_heal_started_%s" % target_npc_id
	})
	_active_actions[healer_npc_id] = {
		"kind": HEALING_ACTION_ID,
		"target_npc_id": target_npc_id,
		"medical_skill": medical_skill,
		"cost_timer_seconds": 0.0,
		"money_spent": HEALING_INITIAL_COST
	}
	_log_healing_event(healer_npc_id, target_npc_id, "healing_started", {
		"action_id": HEALING_ACTION_ID,
		"healer_npc_id": healer_npc_id,
		"target_npc_id": target_npc_id,
		"money_spent": HEALING_INITIAL_COST,
		"max_helpers": HEALING_MAX_HELPERS_PER_TARGET
	})
	return true


func _start_clinic_doctor(npc_id: String, action: Dictionary) -> bool:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null or building_system == null:
		return false

	var claim_result: Dictionary = building_system.claim_workstation(
		CLINIC_LOCATION_ID,
		npc_id,
		str(action.get("workstation_type", CLINIC_DOCTOR_WORKSTATION_TYPE))
	)
	if not bool(claim_result.get("ok", false)):
		_update_action_failure(npc_id, "clinic_doctor_failed_no_workstation")
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", CLINIC_DOCTOR_ACTION_ID)),
			"reason": "没有空闲诊疗工位",
			"building_id": CLINIC_LOCATION_ID
		})
		return false

	var doctor: Dictionary = npc_system.get_npc(npc_id)
	var medical_skill := _get_medical_skill(doctor)
	npc_system.update_npc_state(npc_id, {
		"current_action": str(action.get("id", CLINIC_DOCTOR_ACTION_ID)),
		"last_action_result": "started_%s" % str(action.get("id", CLINIC_DOCTOR_ACTION_ID))
	})
	_active_actions[npc_id] = {
		"kind": "clinic_doctor",
		"action": action.duplicate(true),
		"building_id": CLINIC_LOCATION_ID,
		"workstation_id": str(claim_result.get("workstation_id", "")),
		"medical_skill": medical_skill,
		"money_spent": 0,
		"cost_timer_seconds": 0.0,
		"study_skill_timer_seconds": 0.0,
		"treatment_skill_timer_seconds": 0.0,
		"hp_recovery_remainders": {}
	}
	_log_structured_action_event(npc_id, action, "work_started", {
		"action_id": str(action.get("id", CLINIC_DOCTOR_ACTION_ID)),
		"workstation_id": str(claim_result.get("workstation_id", "")),
		"building_id": CLINIC_LOCATION_ID
	})
	return true


func _start_clinic_patient(npc_id: String, action: Dictionary) -> bool:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null or building_system == null:
		return false

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var hp := int(state.get("hp", 0))
	var max_hp := maxi(1, int(state.get("max_hp", 100)))
	if hp >= max_hp:
		_update_action_failure(npc_id, "clinic_patient_failed_not_injured")
		return false

	var claim_result: Dictionary = building_system.claim_workstation(
		CLINIC_LOCATION_ID,
		npc_id,
		str(action.get("workstation_type", CLINIC_PATIENT_BED_TYPE))
	)
	if not bool(claim_result.get("ok", false)):
		_update_action_failure(npc_id, "clinic_patient_failed_no_bed")
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", CLINIC_PATIENT_ACTION_ID)),
			"reason": "没有空闲病床",
			"building_id": CLINIC_LOCATION_ID
		})
		return false

	npc_system.update_npc_state(npc_id, {
		"current_action": str(action.get("id", CLINIC_PATIENT_ACTION_ID)),
		"last_action_result": "started_%s" % str(action.get("id", CLINIC_PATIENT_ACTION_ID))
	})
	_active_actions[npc_id] = {
		"kind": "clinic_patient",
		"action": action.duplicate(true),
		"building_id": CLINIC_LOCATION_ID,
		"workstation_id": str(claim_result.get("workstation_id", "")),
		"healer_npc_id": "",
		"money_spent": 0
	}
	_log_structured_action_event(npc_id, action, "work_started", {
		"action_id": str(action.get("id", CLINIC_PATIENT_ACTION_ID)),
		"workstation_id": str(claim_result.get("workstation_id", "")),
		"building_id": CLINIC_LOCATION_ID
	})
	return true


func _start_work(npc_id: String, action: Dictionary) -> bool:
	var resource_system := _get_resource_system()
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if resource_system == null or npc_system == null or building_system == null:
		return false

	var input_resources: Dictionary = action.get("input_resources", {})
	if not resource_system.can_afford(input_resources):
		_update_action_failure(npc_id, "work_failed_no_resources")
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", "")),
			"reason": "资源不足",
			"input_resources": input_resources,
			"duration_seconds": _get_action_duration_seconds(action)
		})
		return false

	var building_id := str(action.get("location_required", ""))
	var claim_result: Dictionary = {}
	if building_system.has_method("claim_workstation"):
		claim_result = building_system.claim_workstation(building_id, npc_id, str(action.get("workstation_type", "")))
	if not bool(claim_result.get("ok", false)):
		_update_action_failure(npc_id, "work_failed_no_workstation")
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", "")),
			"reason": "没有空闲工位",
			"building_id": building_id,
			"duration_seconds": _get_effective_action_duration_seconds(action, npc_id)
		})
		return false

	var effective_duration := _get_effective_action_duration_seconds(action, npc_id)
	var efficiency_multiplier := _get_work_efficiency_multiplier(npc_id, action)
	var workstation_id := str(claim_result.get("workstation_id", ""))
	_log_structured_action_event(npc_id, action, "work_started", {
		"action_id": str(action.get("id", "")),
		"workstation_id": workstation_id,
		"building_id": building_id,
		"base_duration_seconds": _get_action_duration_seconds(action),
		"duration_seconds": effective_duration,
		"efficiency_multiplier": efficiency_multiplier
	})

	npc_system.update_npc_state(npc_id, {
		"current_action": str(action.get("id", "work")),
		"last_action_result": "started_%s" % str(action.get("id", "work"))
	})
	var active_action := _create_active_action(action, npc_id)
	active_action["building_id"] = building_id
	active_action["workstation_id"] = workstation_id
	active_action["efficiency_multiplier"] = efficiency_multiplier
	_active_actions[npc_id] = active_action
	return true


func _complete_work(npc_id: String, active_action: Dictionary) -> void:
	var action: Dictionary = active_action.get("action", {})
	var resource_system := _get_resource_system()
	if resource_system == null:
		_release_workstation_for_action(npc_id, active_action)
		_update_action_failure(npc_id, "work_failed_no_resource_system")
		return

	var input_resources: Dictionary = action.get("input_resources", {})
	if not resource_system.spend_resources(input_resources):
		_release_workstation_for_action(npc_id, active_action)
		_update_action_failure(npc_id, "work_failed_no_resources")
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", "")),
			"reason": "资源不足",
			"input_resources": input_resources,
			"workstation_id": str(active_action.get("workstation_id", "")),
			"building_id": str(active_action.get("building_id", action.get("location_required", ""))),
			"duration_seconds": float(active_action.get("duration_seconds", _get_action_duration_seconds(action)))
		})
		return

	var output_resources: Dictionary = _get_work_output_resources(action, npc_id)
	for resource_id in output_resources.keys():
		resource_system.add_resource(str(resource_id), int(output_resources[resource_id]))

	_apply_building_effects(action)
	_apply_final_state_deltas(npc_id, active_action)
	_release_workstation_for_action(npc_id, active_action)
	_set_action_idle(npc_id, "completed_%s" % str(action.get("id", "work")))
	_log_structured_action_event(npc_id, action, "work_completed", {
		"action_id": str(action.get("id", "")),
		"input_resources": input_resources,
		"output_resources": output_resources,
		"building_hp_restore": int(action.get("building_hp_restore", 0)),
		"satiety_delta": int(action.get("satiety_delta", 0)),
		"fatigue_delta": int(action.get("fatigue_delta", 0)),
		"workstation_id": str(active_action.get("workstation_id", "")),
		"building_id": str(active_action.get("building_id", action.get("location_required", ""))),
		"base_duration_seconds": _get_action_duration_seconds(action),
		"duration_seconds": float(active_action.get("duration_seconds", _get_action_duration_seconds(action))),
		"efficiency_multiplier": float(active_action.get("efficiency_multiplier", 1.0))
	})


func _start_eat(npc_id: String, action: Dictionary) -> bool:
	var resource_system := _get_resource_system()
	var npc_system := _get_npc_system()
	if resource_system == null:
		return false

	var food_options: Array = action.get("food_options", [])
	for raw_option in food_options:
		if not raw_option is Dictionary:
			continue
		var option: Dictionary = raw_option
		var resource_id := str(option.get("resource", ""))
		var cost := maxi(1, int(option.get("amount", 1)))
		if resource_system.get_resource(resource_id) >= cost:
			if not resource_system.spend_resources({resource_id: cost}):
				return false
			_log_structured_action_event(npc_id, action, "eat_started", {
				"action_id": str(action.get("id", "")),
				"resource_id": resource_id,
				"amount": cost,
				"duration_seconds": _get_action_duration_seconds(action)
			})
			if npc_system != null:
				npc_system.update_npc_state(npc_id, {
					"current_action": str(action.get("id", "eat")),
					"last_action_result": "started_eat"
				})
			var active_action := _create_active_action(action, npc_id)
			active_action["resource_id"] = resource_id
			active_action["amount"] = cost
			active_action["state_deltas"] = {"satiety": int(option.get("satiety_restore", 0))}
			_active_actions[npc_id] = active_action
			return true

	_update_action_failure(npc_id, "eat_failed_no_food")
	_log_structured_action_event(npc_id, action, "work_failed", {
		"action_id": str(action.get("id", "")),
		"reason": "没有可用食物",
		"duration_seconds": _get_action_duration_seconds(action)
	})
	return false


func _complete_eat(npc_id: String, active_action: Dictionary) -> void:
	var action: Dictionary = active_action.get("action", {})
	_apply_final_state_deltas(npc_id, active_action)
	_set_action_idle(npc_id, "completed_eat")
	_log_structured_action_event(npc_id, action, "eat_completed", {
		"action_id": str(action.get("id", "")),
		"resource_id": str(active_action.get("resource_id", "")),
		"amount": int(active_action.get("amount", 0)),
		"satiety_restore": int(active_action.get("state_deltas", {}).get("satiety", 0)),
		"duration_seconds": _get_action_duration_seconds(action)
	})


func _start_sleep(npc_id: String, action: Dictionary) -> bool:
	var npc_system := _get_npc_system()
	_log_structured_action_event(npc_id, action, "sleep_started", {
		"action_id": str(action.get("id", "")),
		"duration_seconds": _get_action_duration_seconds(action)
	})
	if npc_system != null:
		npc_system.update_npc_state(npc_id, {
			"current_action": str(action.get("id", "sleep")),
			"last_action_result": "started_sleep"
		})
	_active_actions[npc_id] = _create_active_action(action, npc_id)
	return true


func _complete_sleep(npc_id: String, active_action: Dictionary) -> void:
	var action: Dictionary = active_action.get("action", {})
	_apply_final_state_deltas(npc_id, active_action)
	_set_action_idle(npc_id, "completed_sleep")
	_log_structured_action_event(npc_id, action, "sleep_ended", {
		"action_id": str(action.get("id", "")),
		"satiety_delta": int(action.get("satiety_delta", 0)),
		"fatigue_delta": int(action.get("fatigue_delta", 0)),
		"duration_seconds": _get_action_duration_seconds(action)
	})


func _create_active_action(action: Dictionary, npc_id: String = "") -> Dictionary:
	return {
		"action": action.duplicate(true),
		"elapsed_seconds": 0.0,
		"duration_seconds": _get_effective_action_duration_seconds(action, npc_id),
		"state_deltas": _get_action_state_deltas(action),
		"applied_state_deltas": {}
	}


func _advance_active_action(npc_id: String, game_delta_seconds: float) -> void:
	if _is_npc_unconscious_or_escaped(npc_id):
		_stop_active_action(npc_id, "")
		return
	var active_action: Dictionary = _active_actions[npc_id]
	if str(active_action.get("kind", "")) == HEALING_ACTION_ID:
		_advance_healing_assist(npc_id, active_action, game_delta_seconds)
		return
	if str(active_action.get("kind", "")) == "clinic_doctor":
		_advance_clinic_doctor(npc_id, active_action, game_delta_seconds)
		return
	if str(active_action.get("kind", "")) == "clinic_patient":
		_advance_clinic_patient(npc_id, active_action, game_delta_seconds)
		return
	var duration := maxf(0.001, float(active_action.get("duration_seconds", DEFAULT_WORK_DURATION_SECONDS)))
	var elapsed := clampf(float(active_action.get("elapsed_seconds", 0.0)) + game_delta_seconds, 0.0, duration)
	active_action["elapsed_seconds"] = elapsed
	_active_actions[npc_id] = active_action

	_apply_progress_state_deltas(npc_id, active_action)
	active_action = _active_actions.get(npc_id, active_action)

	if elapsed < duration:
		return

	_active_actions.erase(npc_id)
	var action: Dictionary = active_action.get("action", {})
	match str(action.get("type", "")):
		"work":
			_complete_work(npc_id, active_action)
		"eat":
			_complete_eat(npc_id, active_action)
		"sleep":
			_complete_sleep(npc_id, active_action)


func _advance_clinic_doctor(doctor_npc_id: String, active_action: Dictionary, game_delta_seconds: float) -> void:
	var npc_system := _get_npc_system()
	if npc_system == null:
		_stop_active_action(doctor_npc_id, "clinic_doctor_failed_no_npc_system")
		return
	if str(npc_system.get_npc_state(doctor_npc_id).get("current_location", "")) != CLINIC_LOCATION_ID:
		_stop_active_action(doctor_npc_id, "clinic_doctor_left_clinic")
		return

	var patient_id := _find_active_clinic_patient_id()
	if patient_id.is_empty():
		_advance_clinic_study(doctor_npc_id, active_action, game_delta_seconds)
		return

	var resource_system := _get_resource_system()
	var action: Dictionary = active_action.get("action", {})
	var cost_interval := maxf(1.0, float(action.get("resource_cost_interval_seconds", HEALING_COST_INTERVAL_SECONDS)))
	var cost_timer := float(active_action.get("cost_timer_seconds", 0.0)) + game_delta_seconds
	var money_spent := int(active_action.get("money_spent", 0))
	while cost_timer >= cost_interval:
		if resource_system == null or not resource_system.spend_resources({HEALING_RESOURCE_ID: HEALING_INITIAL_COST}):
			active_action["cost_timer_seconds"] = cost_timer
			active_action["money_spent"] = money_spent
			_active_actions[doctor_npc_id] = active_action
			_finish_clinic_patient(patient_id, doctor_npc_id, "clinic_treatment_failed_no_money")
			_stop_active_action(doctor_npc_id, "clinic_doctor_failed_no_money")
			return
		cost_timer -= cost_interval
		money_spent += HEALING_INITIAL_COST

	var hp_per_hour := _get_clinic_hp_per_hour(doctor_npc_id)
	var remainders: Dictionary = active_action.get("hp_recovery_remainders", {})
	var accumulated := float(remainders.get(patient_id, 0.0)) + hp_per_hour / 3600.0 * game_delta_seconds
	var hp_to_restore := int(floor(accumulated))
	if hp_to_restore > 0:
		accumulated -= float(hp_to_restore)
		var recovery_result: Dictionary = npc_system.restore_npc_hp(patient_id, hp_to_restore, "clinic_treatment", doctor_npc_id)
		if not recovery_result.is_empty():
			_update_active_clinic_patient_healer(patient_id, doctor_npc_id, money_spent)
			var patient_state: Dictionary = npc_system.get_npc_state(patient_id)
			if int(patient_state.get("hp", 0)) >= int(patient_state.get("max_hp", 100)):
				_finish_clinic_patient(patient_id, doctor_npc_id, "clinic_treatment_completed", money_spent)
	remainders[patient_id] = accumulated
	active_action["hp_recovery_remainders"] = remainders
	active_action["cost_timer_seconds"] = cost_timer
	active_action["money_spent"] = money_spent

	var skill_timer := float(active_action.get("treatment_skill_timer_seconds", 0.0)) + game_delta_seconds
	var skill_interval := maxf(1.0, float(action.get("treatment_skill_interval_seconds", CLINIC_TREATMENT_SKILL_INTERVAL_SECONDS)))
	while skill_timer >= skill_interval:
		skill_timer -= skill_interval
		_improve_medical_skill(doctor_npc_id, 1, "clinic_treatment")
	active_action["treatment_skill_timer_seconds"] = skill_timer
	_active_actions[doctor_npc_id] = active_action


func _advance_clinic_study(doctor_npc_id: String, active_action: Dictionary, game_delta_seconds: float) -> void:
	var action: Dictionary = active_action.get("action", {})
	var skill_timer := float(active_action.get("study_skill_timer_seconds", 0.0)) + game_delta_seconds
	var skill_interval := maxf(1.0, float(action.get("study_skill_interval_seconds", CLINIC_STUDY_SKILL_INTERVAL_SECONDS)))
	while skill_timer >= skill_interval:
		skill_timer -= skill_interval
		_improve_medical_skill(doctor_npc_id, 1, "clinic_study")
	active_action["study_skill_timer_seconds"] = skill_timer
	_active_actions[doctor_npc_id] = active_action


func _advance_clinic_patient(npc_id: String, _active_action: Dictionary, _game_delta_seconds: float) -> void:
	var npc_system := _get_npc_system()
	if npc_system == null:
		_stop_active_action(npc_id, "clinic_patient_failed_no_npc_system")
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_location", "")) != CLINIC_LOCATION_ID:
		_finish_clinic_patient(npc_id, "", "clinic_patient_left_clinic")
		return
	if int(state.get("hp", 0)) >= int(state.get("max_hp", 100)):
		_finish_clinic_patient(npc_id, str(_active_action.get("healer_npc_id", "")), "clinic_treatment_completed", int(_active_action.get("money_spent", 0)))


func _advance_healing_assist(healer_npc_id: String, active_action: Dictionary, game_delta_seconds: float) -> void:
	var npc_system := _get_npc_system()
	if npc_system == null:
		_stop_active_action(healer_npc_id, "assist_heal_failed_no_npc_system")
		return

	var target_npc_id := str(active_action.get("target_npc_id", ""))
	if not _is_npc_unconscious(target_npc_id):
		_finish_healing_assist(healer_npc_id, target_npc_id, "target_no_longer_unconscious")
		return
	if str(npc_system.get_npc_state(healer_npc_id).get("current_location", "")) != _get_target_healing_location(target_npc_id):
		_finish_healing_assist(healer_npc_id, target_npc_id, "healer_left_location")
		return

	var cost_timer := float(active_action.get("cost_timer_seconds", 0.0)) + game_delta_seconds
	var money_spent := int(active_action.get("money_spent", 0))
	while cost_timer >= HEALING_COST_INTERVAL_SECONDS:
		if not _spend_healing_cost():
			active_action["cost_timer_seconds"] = cost_timer
			active_action["money_spent"] = money_spent
			_active_actions[healer_npc_id] = active_action
			_finish_healing_assist(healer_npc_id, target_npc_id, "资源不足")
			return
		cost_timer -= HEALING_COST_INTERVAL_SECONDS
		money_spent += 1

	var recovery_result: Dictionary = npc_system.assist_unconscious_recovery(
		target_npc_id,
		game_delta_seconds,
		healer_npc_id,
		int(active_action.get("medical_skill", 0))
	)
	active_action["cost_timer_seconds"] = cost_timer
	active_action["money_spent"] = money_spent
	_active_actions[healer_npc_id] = active_action
	if bool(recovery_result.get("revived", false)):
		_finish_healing_assist(healer_npc_id, target_npc_id, "target_revived")


func _apply_progress_state_deltas(npc_id: String, active_action: Dictionary) -> void:
	var duration := maxf(0.001, float(active_action.get("duration_seconds", DEFAULT_WORK_DURATION_SECONDS)))
	var elapsed := clampf(float(active_action.get("elapsed_seconds", 0.0)), 0.0, duration)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var state_deltas: Dictionary = active_action.get("state_deltas", {})
	var applied: Dictionary = active_action.get("applied_state_deltas", {})
	for state_key in state_deltas.keys():
		var total_delta := int(state_deltas[state_key])
		var target_applied := int(round(float(total_delta) * progress))
		var already_applied := int(applied.get(state_key, 0))
		var delta_to_apply := target_applied - already_applied
		if delta_to_apply == 0:
			continue
		_apply_single_state_delta(npc_id, str(state_key), delta_to_apply)
		applied[state_key] = target_applied
	active_action["applied_state_deltas"] = applied
	_active_actions[npc_id] = active_action


func _apply_final_state_deltas(npc_id: String, active_action: Dictionary) -> void:
	var state_deltas: Dictionary = active_action.get("state_deltas", {})
	var applied: Dictionary = active_action.get("applied_state_deltas", {})
	for state_key in state_deltas.keys():
		var total_delta := int(state_deltas[state_key])
		var already_applied := int(applied.get(state_key, 0))
		var delta_to_apply := total_delta - already_applied
		if delta_to_apply != 0:
			_apply_single_state_delta(npc_id, str(state_key), delta_to_apply)


func _get_action_state_deltas(action: Dictionary) -> Dictionary:
	var state_deltas := {}
	if action.has("satiety_delta"):
		state_deltas["satiety"] = int(action.get("satiety_delta", 0))
	if action.has("fatigue_delta"):
		state_deltas["fatigue"] = int(action.get("fatigue_delta", 0))
	return state_deltas


func _get_action_duration_seconds(action: Dictionary) -> float:
	if action.has("duration_seconds"):
		return maxf(1.0, float(action.get("duration_seconds", DEFAULT_WORK_DURATION_SECONDS)))
	return maxf(1.0, float(action.get("base_duration_hours", DEFAULT_WORK_DURATION_HOURS)) * 3600.0)


func _get_effective_action_duration_seconds(action: Dictionary, npc_id: String = "") -> float:
	var base_duration := _get_action_duration_seconds(action)
	if str(action.get("type", "")) != "work" or npc_id.is_empty():
		return base_duration
	var multiplier := _get_work_efficiency_multiplier(npc_id, action)
	return maxf(60.0, base_duration / multiplier)


func _get_work_efficiency_multiplier(npc_id: String, action: Dictionary) -> float:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null:
		return 1.0

	var npc: Dictionary = npc_system.get_npc(npc_id)
	var skill_value := _get_action_skill_value(npc, str(action.get("skill", "")))
	var attribute_value := _get_work_attribute_value(npc, action)
	var building_level := 1
	var building_id := str(action.get("location_required", ""))
	if building_system != null and not building_id.is_empty():
		var building: Dictionary = building_system.get_building(building_id)
		building_level = maxi(1, int(building.get("level", 1)))

	var skill_bonus := float(skill_value) / 100.0 * WORK_SKILL_SPEED_SCALE
	var attribute_bonus := maxf(0.0, float(attribute_value - 5)) * WORK_ATTRIBUTE_SPEED_SCALE
	var building_bonus := maxf(0.0, float(building_level - 1)) * WORK_BUILDING_LEVEL_SPEED_SCALE
	return clampf(1.0 + skill_bonus + attribute_bonus + building_bonus, 1.0, WORK_MAX_SPEED_MULTIPLIER)


func _get_work_output_resources(action: Dictionary, npc_id: String) -> Dictionary:
	var output_resources: Dictionary = action.get("output_resources", {}).duplicate(true)
	var scaling: Dictionary = action.get("output_scaling", {})
	if scaling.is_empty() or npc_id.is_empty():
		return output_resources

	var resources: Array = scaling.get("resources", [])
	if resources.is_empty():
		resources = output_resources.keys()

	var skill_bonus := 0
	var skill_per_bonus := maxi(1, int(scaling.get("skill_per_bonus", WORK_OUTPUT_DEFAULT_SKILL_PER_BONUS)))
	var npc_system := _get_npc_system()
	if npc_system != null:
		var npc: Dictionary = npc_system.get_npc(npc_id)
		skill_bonus = int(floor(float(_get_action_skill_value(npc, str(action.get("skill", "")))) / float(skill_per_bonus)))

	var attribute_bonus := 0
	if npc_system != null:
		var npc_for_attribute: Dictionary = npc_system.get_npc(npc_id)
		var attribute_baseline := int(scaling.get("attribute_baseline", WORK_OUTPUT_DEFAULT_ATTRIBUTE_BASELINE))
		var attribute_per_bonus := maxi(1, int(scaling.get("attribute_per_bonus", WORK_OUTPUT_DEFAULT_ATTRIBUTE_PER_BONUS)))
		var attribute_value := _get_work_attribute_value(npc_for_attribute, action)
		attribute_bonus = int(floor(float(maxi(0, attribute_value - attribute_baseline)) / float(attribute_per_bonus)))

	var building_bonus := 0
	if bool(scaling.get("building_level_bonus", true)):
		var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
		var building_id := str(action.get("location_required", ""))
		if building_system != null and not building_id.is_empty():
			var building: Dictionary = building_system.get_building(building_id)
			building_bonus = maxi(0, int(building.get("level", 1)) - 1)

	var total_bonus := maxi(0, skill_bonus + attribute_bonus + building_bonus)
	if total_bonus <= 0:
		return output_resources

	for raw_resource_id in resources:
		var resource_id := str(raw_resource_id)
		if output_resources.has(resource_id):
			output_resources[resource_id] = maxi(0, int(output_resources.get(resource_id, 0)) + total_bonus)
	return output_resources


func _get_action_skill_value(npc: Dictionary, skill_name: String) -> int:
	if skill_name.is_empty():
		return 0
	var skills: Dictionary = npc.get("skills", {})
	return clampi(int(skills.get(skill_name, 0)), 0, 100)


func _get_work_attribute_value(npc: Dictionary, action: Dictionary) -> int:
	var stats: Dictionary = npc.get("stats", {})
	var preferred_stat := str(action.get("stat", ""))
	if preferred_stat.is_empty():
		var skill_name := str(action.get("skill", ""))
		if ["厨艺", "酿酒", "医术", "工程", "教练"].has(skill_name):
			preferred_stat = "intelligence"
		else:
			preferred_stat = "strength"
	return clampi(int(stats.get(preferred_stat, 5)), 0, 10)


func _release_workstation_for_action(npc_id: String, active_action: Dictionary) -> void:
	var building_id := str(active_action.get("building_id", active_action.get("action", {}).get("location_required", "")))
	var workstation_id := str(active_action.get("workstation_id", ""))
	if building_id.is_empty():
		return
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and building_system.has_method("release_workstation"):
		building_system.release_workstation(building_id, npc_id, workstation_id)


func _get_engineering_skill(npc: Dictionary) -> int:
	var skills: Dictionary = npc.get("skills", {})
	for skill_key in ["工程", "宸ョ▼"]:
		if skills.has(skill_key):
			return int(skills.get(skill_key, 0))
	return 0


func _get_medical_skill(npc: Dictionary) -> int:
	var skills: Dictionary = npc.get("skills", {})
	for skill_key in ["医术", "醫術", "鍖绘湳"]:
		if skills.has(skill_key):
			return int(skills.get(skill_key, 0))
	return 0


func _apply_state_deltas(npc_id: String, action: Dictionary) -> void:
	if action.has("satiety_delta"):
		_apply_single_state_delta(npc_id, "satiety", int(action.get("satiety_delta", 0)))
	if action.has("fatigue_delta"):
		_apply_single_state_delta(npc_id, "fatigue", int(action.get("fatigue_delta", 0)))


func _apply_building_effects(action: Dictionary) -> void:
	var hp_restore := int(action.get("building_hp_restore", 0))
	if hp_restore <= 0:
		return

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("restore_building_hp"):
		return

	var building_id := str(action.get("location_required", ""))
	if not building_id.is_empty():
		building_system.restore_building_hp(building_id, hp_restore)


func _apply_single_state_delta(npc_id: String, state_key: String, delta: int) -> void:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var current_value := int(state.get(state_key, 0))
	var next_value := clampi(current_value + delta, 0, 100)
	npc_system.set_npc_state_value(npc_id, state_key, next_value)


func _set_action_idle(npc_id: String, last_result: String) -> void:
	var npc_system := _get_npc_system()
	if npc_system != null:
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": last_result
		})


func _update_action_failure(npc_id: String, failure_id: String) -> void:
	var npc_system := _get_npc_system()
	if npc_system != null:
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": failure_id
		})


func _stop_active_action(npc_id: String, last_result: String = "active_action_stopped") -> void:
	if not _active_actions.has(npc_id):
		return
	var active_action: Dictionary = _active_actions[npc_id]
	if str(active_action.get("kind", "")) == HEALING_ACTION_ID:
		var target_npc_id := str(active_action.get("target_npc_id", ""))
		_remove_healing_helper(target_npc_id, npc_id)
	elif ["clinic_doctor", "clinic_patient"].has(str(active_action.get("kind", ""))):
		_release_workstation_for_action(npc_id, active_action)
	elif str(active_action.get("action", {}).get("type", "")) == "work":
		_release_workstation_for_action(npc_id, active_action)
		_log_structured_action_event(npc_id, active_action.get("action", {}), "work_failed", {
			"action_id": str(active_action.get("action", {}).get("id", "")),
			"reason": "工作中断",
			"workstation_id": str(active_action.get("workstation_id", "")),
			"building_id": str(active_action.get("building_id", "")),
			"duration_seconds": float(active_action.get("duration_seconds", DEFAULT_WORK_DURATION_SECONDS))
		})
	_active_actions.erase(npc_id)
	if not last_result.is_empty():
		_set_action_idle(npc_id, last_result)


func _finish_healing_assist(healer_npc_id: String, target_npc_id: String, reason: String) -> void:
	var active_action: Dictionary = _active_actions.get(healer_npc_id, {})
	var money_spent := int(active_action.get("money_spent", 0))
	_remove_healing_helper(target_npc_id, healer_npc_id)
	_active_actions.erase(healer_npc_id)
	_set_action_idle(healer_npc_id, "assist_heal_completed_%s" % target_npc_id)
	_log_healing_event(healer_npc_id, target_npc_id, "healing_completed", {
		"action_id": HEALING_ACTION_ID,
		"healer_npc_id": healer_npc_id,
		"target_npc_id": target_npc_id,
		"money_spent": money_spent
	})


func _finish_clinic_patient(patient_npc_id: String, doctor_npc_id: String, last_result: String, money_spent: int = 0) -> void:
	if not _active_actions.has(patient_npc_id):
		return
	var patient_action: Dictionary = _active_actions[patient_npc_id]
	if str(patient_action.get("kind", "")) != "clinic_patient":
		return
	_release_workstation_for_action(patient_npc_id, patient_action)
	_active_actions.erase(patient_npc_id)
	_set_action_idle(patient_npc_id, last_result)
	if not doctor_npc_id.is_empty():
		_log_healing_event(doctor_npc_id, patient_npc_id, "healing_completed", {
			"action_id": CLINIC_PATIENT_ACTION_ID,
			"healer_npc_id": doctor_npc_id,
			"target_npc_id": patient_npc_id,
			"money_spent": money_spent
		})


func _find_active_clinic_patient_id() -> String:
	for raw_npc_id in _active_actions.keys():
		var npc_id := str(raw_npc_id)
		var active_action: Dictionary = _active_actions.get(npc_id, {})
		if str(active_action.get("kind", "")) == "clinic_patient":
			return npc_id
	return ""


func _update_active_clinic_patient_healer(patient_npc_id: String, doctor_npc_id: String, money_spent: int) -> void:
	if not _active_actions.has(patient_npc_id):
		return
	var patient_action: Dictionary = _active_actions[patient_npc_id]
	patient_action["healer_npc_id"] = doctor_npc_id
	patient_action["money_spent"] = money_spent
	_active_actions[patient_npc_id] = patient_action


func _get_clinic_hp_per_hour(doctor_npc_id: String) -> float:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null:
		return CLINIC_BASE_HP_PER_HOUR
	var doctor: Dictionary = npc_system.get_npc(doctor_npc_id)
	var medical_skill := _get_medical_skill(doctor)
	var stats: Dictionary = doctor.get("stats", {})
	var intelligence := clampi(int(stats.get("intelligence", 5)), 0, 10)
	var building_level := 1
	if building_system != null:
		var clinic: Dictionary = building_system.get_building(CLINIC_LOCATION_ID)
		building_level = maxi(1, int(clinic.get("level", 1)))
	return (
		CLINIC_BASE_HP_PER_HOUR
		+ float(medical_skill) * CLINIC_SKILL_HP_PER_HOUR
		+ maxf(0.0, float(intelligence - 5)) * CLINIC_INTELLIGENCE_HP_PER_HOUR
		+ maxf(0.0, float(building_level - 1)) * CLINIC_LEVEL_HP_PER_HOUR
	)


func _improve_medical_skill(npc_id: String, amount: int, reason: String) -> void:
	var npc_system := _get_npc_system()
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("increase_npc_skill"):
		return
	var result: Dictionary = npc_system.increase_npc_skill(npc_id, "医术", amount)
	if result.is_empty() or memory_system == null or not memory_system.has_method("add_event"):
		return
	memory_system.add_event({
		"type": "skill_improved",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [CLINIC_LOCATION_ID, "医术"],
		"location_id": CLINIC_LOCATION_ID,
		"visibility": "private",
		"importance": 20,
		"payload": {
			"skill_name": "医术",
			"amount": int(result.get("amount", amount)),
			"before": int(result.get("before", 0)),
			"after": int(result.get("after", 0)),
			"reason": reason
		}
	})


func _log_structured_action_event(npc_id: String, action: Dictionary, event_type: String, payload: Dictionary) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return

	var location_id := str(action.get("location_required", ""))
	if location_id.is_empty():
		location_id = "plaza"
	var target_ids: Array[String] = [location_id, str(action.get("id", ""))]
	if payload.has("building_id"):
		var building_id := str(payload["building_id"])
		if not target_ids.has(building_id):
			target_ids.append(building_id)
	if payload.has("resource_id"):
		target_ids.append(str(payload["resource_id"]))
	for key in ["input_resources", "output_resources"]:
		if payload.has(key) and payload[key] is Dictionary:
			for resource_id in (payload[key] as Dictionary).keys():
				var resource_text := str(resource_id)
				if not target_ids.has(resource_text):
					target_ids.append(resource_text)

	memory_system.add_event({
		"type": event_type,
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": target_ids,
		"location_id": location_id,
		"visibility": str(action.get("visibility", "local_public")),
		"duration_seconds": _get_action_duration_seconds(action),
		"importance": 25,
		"payload": payload
	})


func _log_healing_event(healer_npc_id: String, target_npc_id: String, event_type: String, payload: Dictionary) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return

	var location_id := _get_target_healing_location(target_npc_id)
	var target_ids: Array[String] = [target_npc_id, healer_npc_id, location_id, HEALING_ACTION_ID, HEALING_RESOURCE_ID]
	var event_payload := payload.duplicate(true)
	event_payload["location_id"] = location_id
	event_payload.erase("medical_skill")
	for subject_id in [healer_npc_id, target_npc_id]:
		memory_system.add_event({
			"type": event_type,
			"subject_npc_id": subject_id,
			"actor_ids": [healer_npc_id],
			"target_ids": target_ids,
			"location_id": location_id,
			"visibility": "private",
			"importance": 55,
			"payload": event_payload
		})
	var public_event: Dictionary = memory_system.add_event({
		"type": event_type,
		"subject_npc_id": "system",
		"actor_ids": [healer_npc_id],
		"target_ids": target_ids,
		"location_id": location_id,
		"visibility": "private",
		"importance": 55,
		"payload": event_payload
	})
	if public_event.is_empty() or not memory_system.has_method("add_witness_event"):
		return

	var people_present: Array[String] = []
	if memory_system.has_method("get_location_people_present"):
		people_present = memory_system.get_location_people_present(location_id)
	for npc_id in people_present:
		if npc_id == healer_npc_id or npc_id == target_npc_id:
			continue
		memory_system.add_witness_event(npc_id, str(public_event.get("event_id", "")))


func _find_work_action_for_building(building_id: String) -> String:
	var action_ids: Array = _actions_by_location.get(building_id, [])
	for raw_action_id in action_ids:
		var action_id := str(raw_action_id)
		var action: Dictionary = _actions.get(action_id, {})
		if ["work", "clinic_doctor"].has(str(action.get("type", ""))):
			return action_id
	return ""


func _can_npc_act(npc_id: String) -> bool:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return false

	var state: Dictionary = npc.get("states", {})
	if bool(state.get("unconscious", false)):
		push_warning("Unconscious NPC cannot act: %s" % npc_id)
		return false
	if bool(state.get("escaped", false)):
		push_warning("Escaped NPC cannot act: %s" % npc_id)
		return false
	return true


func _is_npc_unconscious(npc_id: String) -> bool:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	return bool(state.get("unconscious", false)) and not bool(state.get("escaped", false))


func _is_npc_unconscious_or_escaped(npc_id: String) -> bool:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return true
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	return bool(state.get("unconscious", false)) or bool(state.get("escaped", false))


func _get_target_healing_location(target_npc_id: String) -> String:
	var npc_system := _get_npc_system()
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if npc_system == null:
		return PLAZA_LOCATION_ID
	var state: Dictionary = npc_system.get_npc_state(target_npc_id)
	var location_id := str(state.get("current_location", PLAZA_LOCATION_ID))
	if memory_system != null and memory_system.has_method("is_enterable_location") and memory_system.is_enterable_location(location_id):
		return location_id
	return PLAZA_LOCATION_ID


func _get_healing_helper_count(target_npc_id: String) -> int:
	return (_healing_helpers_by_target.get(target_npc_id, []) as Array).size()


func _add_healing_helper(target_npc_id: String, healer_npc_id: String) -> void:
	var helpers: Array = _healing_helpers_by_target.get(target_npc_id, [])
	if not helpers.has(healer_npc_id):
		helpers.append(healer_npc_id)
	_healing_helpers_by_target[target_npc_id] = helpers


func _remove_healing_helper(target_npc_id: String, healer_npc_id: String) -> void:
	if not _healing_helpers_by_target.has(target_npc_id):
		return
	var helpers: Array = _healing_helpers_by_target[target_npc_id]
	helpers.erase(healer_npc_id)
	if helpers.is_empty():
		_healing_helpers_by_target.erase(target_npc_id)
	else:
		_healing_helpers_by_target[target_npc_id] = helpers


func _can_pay_healing_cost() -> bool:
	var resource_system := _get_resource_system()
	return resource_system != null and resource_system.can_afford({HEALING_RESOURCE_ID: HEALING_INITIAL_COST})


func _spend_healing_cost() -> bool:
	var resource_system := _get_resource_system()
	return resource_system != null and resource_system.spend_resources({HEALING_RESOURCE_ID: HEALING_INITIAL_COST})


func _get_location_name(location_id: String) -> String:
	if location_id.is_empty():
		return ""
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		return location_id
	var building: Dictionary = building_system.get_building(location_id)
	return str(building.get("name", location_id))


func _get_npc_system() -> Node:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		push_warning("ActionSystem requires NPCSystem.")
	return npc_system


func _get_resource_system() -> Node:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		push_warning("ActionSystem requires ResourceSystem.")
	return resource_system


func _is_gameplay_paused() -> bool:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	return time_system != null and time_system.is_gameplay_paused()
