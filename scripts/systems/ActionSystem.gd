extends Node

const ACTION_DEFS_FILE := "action_defs.json"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const DAILY_PLAN_SYSTEM_PATH := "/root/Main/Systems/DailyPlanSystem"
const CRAFTING_SYSTEM_PATH := "/root/Main/Systems/CraftingSystem"
const PIETY_SYSTEM_PATH := "/root/Main/Systems/PietySystem"
const GAME_STATE_PATH := "/root/GameState"
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
const CLINIC_DOCTOR_WORKSTATION_TYPE := "clinic_doctor_station"
const CLINIC_PATIENT_BED_TYPE := "clinic_patient_bed"
const TRAINING_LOCATION_ID := "training_ground"
const TRAINING_INSTRUCTOR_ACTION_ID := "work_training_instructor"
const TRAINING_STUDENT_ACTION_ID := "receive_weapon_training"
const TRAINING_INSTRUCTOR_WORKSTATION_TYPE := "training_instructor_station"
const TRAINING_STUDENT_WORKSTATION_TYPE := "training_practice_slot"
const CLINIC_STUDY_SKILL_INTERVAL_SECONDS := 14400.0
const CLINIC_TREATMENT_SKILL_INTERVAL_SECONDS := 3600.0
const CLINIC_BASE_HP_PER_HOUR := 6.0
const CLINIC_SKILL_HP_PER_HOUR := 0.10
const CLINIC_INTELLIGENCE_HP_PER_HOUR := 0.45
const CLINIC_LEVEL_HP_PER_HOUR := 3.0
const TRAINING_SOLO_SKILL_INTERVAL_SECONDS := 14400.0
const TRAINING_COACHING_SKILL_INTERVAL_SECONDS := 3600.0
const TRAINING_STUDENT_SKILL_INTERVAL_SECONDS := 3600.0
const TRAINING_LOW_TEACHER_INTERVAL_MULTIPLIER := 6.0
const TRAINING_GAP_SPEED_SCALE := 0.65
const TRAINING_COACHING_SPEED_SCALE := 0.50
const TRAINING_BUILDING_LEVEL_SPEED_SCALE := 0.15
const TRAINING_MIN_STUDENT_SKILL_INTERVAL_SECONDS := 600.0
const NPC_DIALOGUE_ACTION_ID := "talk_to_npc"
const NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD := 5
const VISIT_LOCATION_ACTION_ID := "visit_location"
const PRAY_ACTION_ID := "pray_at_chapel"
const MASS_ACTION_ID := "lead_mass"
const PRAYER_MODE_PERSONAL := "personal_prayer"
const PRAYER_MODE_MASS := "mass_attendance"
const DRINK_WINE_ACTION_ID := "drink_wine"
const NPC_DIALOGUE_MAX_CHASES := 1
const WORK_SKILL_SPEED_SCALE := 0.50
const WORK_ATTRIBUTE_SPEED_SCALE := 0.025
const WORK_BUILDING_LEVEL_SPEED_SCALE := 0.15
const WORK_MAX_SPEED_MULTIPLIER := 2.5
const WORK_OUTPUT_DEFAULT_SKILL_PER_BONUS := 50
const WORK_OUTPUT_DEFAULT_ATTRIBUTE_BASELINE := 5
const WORK_OUTPUT_DEFAULT_ATTRIBUTE_PER_BONUS := 3
const COMPLETION_POLICY_REPEAT_WHILE_PLANNED := "repeat_while_planned"
const COMPLETION_POLICY_CONTINUOUS_UNTIL_PLAN_CHANGES := "continuous_until_plan_changes"
const COMPLETION_POLICY_UNTIL_TARGET_RESOLVED := "until_target_resolved"
const COMPLETION_POLICY_ONCE_PER_PLAN_HOUR := "once_per_plan_hour"
const COMPLETION_POLICY_TERMINAL := "terminal"
const COMPLETION_POLICY_NOT_PLAN_SELECTABLE := "not_plan_selectable"
const VALID_COMPLETION_POLICIES := {
	COMPLETION_POLICY_REPEAT_WHILE_PLANNED: true,
	COMPLETION_POLICY_CONTINUOUS_UNTIL_PLAN_CHANGES: true,
	COMPLETION_POLICY_UNTIL_TARGET_RESOLVED: true,
	COMPLETION_POLICY_ONCE_PER_PLAN_HOUR: true,
	COMPLETION_POLICY_TERMINAL: true,
	COMPLETION_POLICY_NOT_PLAN_SELECTABLE: true,
}

var _actions: Dictionary = {}
var _actions_by_location: Dictionary = {}
var _action_definition_errors: Array[String] = []
var _pending_actions: Dictionary = {}
var _pending_action_targets: Dictionary = {}
var _pending_action_options: Dictionary = {}
var _active_actions: Dictionary = {}
var _healing_helpers_by_target: Dictionary = {}
var _dialogue_reservations: Dictionary = {}
var _building_eviction_guards: Dictionary = {}
var _timed_experience_seconds: Dictionary = {}


func initialize() -> void:
	_actions.clear()
	_actions_by_location.clear()
	_action_definition_errors.clear()
	_pending_actions.clear()
	_pending_action_targets.clear()
	_pending_action_options.clear()
	_active_actions.clear()
	_healing_helpers_by_target.clear()
	_dialogue_reservations.clear()
	_building_eviction_guards.clear()
	_timed_experience_seconds.clear()

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
		var completion_policy := str(definition.get("completion_policy", ""))
		if not VALID_COMPLETION_POLICIES.has(completion_policy):
			var completion_policy_error := (
				"Skipped action definition '%s': missing or invalid completion_policy '%s'."
				% [action_id, completion_policy]
			)
			_action_definition_errors.append(completion_policy_error)
			push_error(completion_policy_error)
			continue
		var plan_selectable := bool(definition.get("plan_selectable", true))
		if not is_action_completion_policy_valid(completion_policy, plan_selectable):
			var plan_selectable_policy_error := (
				"Skipped action definition '%s': completion_policy '%s' conflicts with plan_selectable=%s."
				% [action_id, completion_policy, plan_selectable]
			)
			_action_definition_errors.append(plan_selectable_policy_error)
			push_error(plan_selectable_policy_error)
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
		if not event_bus.building_state_changed.is_connected(_on_building_state_changed):
			event_bus.building_state_changed.connect(_on_building_state_changed)
		if (
			event_bus.has_signal("npc_building_entry_failed")
			and not event_bus.npc_building_entry_failed.is_connected(_on_npc_building_entry_failed)
		):
			event_bus.npc_building_entry_failed.connect(_on_npc_building_entry_failed)


func get_action(action_id: String) -> Dictionary:
	if not _actions.has(action_id):
		push_warning("Unknown action id: %s" % action_id)
		return {}
	return _actions[action_id].duplicate(true)


func get_action_completion_policy(action_id: String) -> String:
	if not _actions.has(action_id):
		return ""
	return str((_actions[action_id] as Dictionary).get("completion_policy", ""))


func is_action_completion_policy_valid(
	completion_policy: String,
	plan_selectable: bool = true
) -> bool:
	if not VALID_COMPLETION_POLICIES.has(completion_policy):
		return false
	return (
		(plan_selectable and completion_policy != COMPLETION_POLICY_NOT_PLAN_SELECTABLE)
		or (
			not plan_selectable
			and completion_policy == COMPLETION_POLICY_NOT_PLAN_SELECTABLE
		)
	)


func get_action_definition_errors() -> Array[String]:
	return _action_definition_errors.duplicate()


func get_action_ids() -> Array[String]:
	var ids: Array[String] = []
	for action_id in _actions.keys():
		ids.append(str(action_id))
	ids.sort()
	return ids


func advance_timed_action_experience(
	npc_id: String,
	action_id: String,
	effective_game_seconds: float,
	location_id: String = ""
) -> Dictionary:
	if effective_game_seconds <= 0.0 or not _actions.has(action_id):
		return {}
	var action: Dictionary = _actions[action_id]
	var timed_experience: Dictionary = (
		action.get("timed_experience", {})
		if action.get("timed_experience", {}) is Dictionary
		else {}
	)
	if timed_experience.is_empty():
		return {}
	var skill_name := str(timed_experience.get("skill", ""))
	var interval_seconds := maxf(1.0, float(timed_experience.get("interval_seconds", 3600.0)))
	var amount := maxi(1, int(timed_experience.get("amount", 1)))
	if skill_name.is_empty():
		return {}

	var timer_key := "%s::%s" % [npc_id, action_id]
	var timer := float(_timed_experience_seconds.get(timer_key, 0.0)) + effective_game_seconds
	var awards := 0
	var experience_gained := 0
	var event_location := location_id
	if event_location.is_empty():
		var npc_system := _get_npc_system()
		if npc_system != null:
			event_location = str(npc_system.get_npc_state(npc_id).get("current_location", PLAZA_LOCATION_ID))
	while timer >= interval_seconds:
		timer -= interval_seconds
		var result := _improve_npc_skill_at_location(
			npc_id,
			skill_name,
			amount,
			str(timed_experience.get("reason", action_id)),
			event_location
		)
		if not result.is_empty():
			awards += 1
			experience_gained += int(result.get("experience_gained", 0))
	_timed_experience_seconds[timer_key] = timer
	return {
		"npc_id": npc_id,
		"action_id": action_id,
		"skill": skill_name,
		"effective_game_seconds": effective_game_seconds,
		"awards": awards,
		"experience_gained": experience_gained,
		"remainder_seconds": timer
	}


func get_timed_action_experience_snapshot(npc_id: String, action_id: String) -> Dictionary:
	if not _actions.has(action_id):
		return {}
	var action: Dictionary = _actions[action_id]
	var timed_experience: Dictionary = (
		action.get("timed_experience", {})
		if action.get("timed_experience", {}) is Dictionary
		else {}
	)
	if timed_experience.is_empty():
		return {}
	return {
		"npc_id": npc_id,
		"action_id": action_id,
		"skill": str(timed_experience.get("skill", "")),
		"interval_seconds": float(timed_experience.get("interval_seconds", 3600.0)),
		"amount": int(timed_experience.get("amount", 1)),
		"remainder_seconds": float(_timed_experience_seconds.get("%s::%s" % [npc_id, action_id], 0.0))
	}


func get_action_eligibility(npc_id: String, action_id: String) -> Dictionary:
	var action: Dictionary = _actions.get(action_id, {})
	if action.is_empty():
		return {
			"eligible": false,
			"available_now": false,
			"unavailable_reason": "未知行动",
			"required_ability": ""
		}

	var required_ability := str(action.get("required_ability", ""))
	var eligible := true
	var unavailable_reason := ""
	if not required_ability.is_empty():
		var npc_system := _get_npc_system()
		var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system != null else {}
		var abilities: Array = npc.get("abilities", []) if npc.get("abilities", []) is Array else []
		eligible = abilities.has(required_ability)
		if not eligible:
			unavailable_reason = "你没有%s的能力" % required_ability

	var environment_available := is_action_environment_available(action_id)
	if eligible and not environment_available:
		unavailable_reason = "当前环境不满足行动条件"
	var runtime_dependency_available := true
	var required_active_action_id := str(action.get("required_active_action_id", ""))
	if not required_active_action_id.is_empty() and _find_active_npc_ids_for_action(required_active_action_id).is_empty():
		runtime_dependency_available = false
		if eligible and environment_available:
			unavailable_reason = _get_missing_dependency_reason(action_id)
	var blocked_by_active_action_id := str(action.get("blocked_by_active_action_id", ""))
	if not blocked_by_active_action_id.is_empty() and not _find_active_npc_ids_for_action(blocked_by_active_action_id).is_empty():
		runtime_dependency_available = false
		if eligible and environment_available:
			unavailable_reason = _get_active_blocker_reason(action_id)

	var building_available := true
	var building_id := str(action.get("location_required", ""))
	if not building_id.is_empty() and building_id != PLAZA_LOCATION_ID:
		var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
		if building_system == null:
			building_available = false
		elif building_system.has_method("is_building_usable"):
			building_available = bool(building_system.is_building_usable(building_id))
		elif building_system.has_method("is_building_accessible"):
			building_available = bool(building_system.is_building_accessible(building_id))
		else:
			var building: Dictionary = building_system.get_building(building_id)
			building_available = (
				not building.is_empty()
				and int(building.get("hp", 0)) > 0
				and str(building.get("condition", "")) != "upgrading"
			)
		if eligible and environment_available and not building_available:
			unavailable_reason = "建筑当前不可进入或使用"

	var personal_resource_cost: Dictionary = (
		action.get("personal_resource_cost", {})
		if action.get("personal_resource_cost", {}) is Dictionary
		else {}
	)
	var personal_resources_available := true
	if not personal_resource_cost.is_empty():
		var personal_npc_system := _get_npc_system()
		personal_resources_available = (
			personal_npc_system != null
			and personal_npc_system.has_method("can_npc_afford_owned_resources")
			and bool(personal_npc_system.can_npc_afford_owned_resources(npc_id, personal_resource_cost))
		)
		if (
			eligible
			and environment_available
			and building_available
			and runtime_dependency_available
			and not personal_resources_available
		):
			unavailable_reason = (
				"本人当前没有酒，无法饮酒"
				if str(action.get("id", "")) == DRINK_WINE_ACTION_ID
				else "本人当前持有的资源不足"
			)

	return {
		"eligible": eligible,
		"available_now": (
			eligible
			and environment_available
			and building_available
			and runtime_dependency_available
			and personal_resources_available
		),
		"unavailable_reason": unavailable_reason,
		"required_ability": required_ability,
		"eligibility_hint": str(action.get("eligibility_hint", "")),
		"required_active_action_id": required_active_action_id,
		"blocked_by_active_action_id": blocked_by_active_action_id,
		"building_id": building_id,
		"personal_resource_cost": personal_resource_cost.duplicate(true),
		"personal_resources_available": personal_resources_available
	}


func is_action_environment_available(action_id: String) -> bool:
	var action: Dictionary = _actions.get(action_id, {})
	if action.is_empty():
		return false
	var required_npc_id := str(action.get("requires_present_npc_id", ""))
	if required_npc_id.is_empty():
		return true
	var npc_system := _get_npc_system()
	if npc_system == null or npc_system.get_npc(required_npc_id).is_empty():
		return false
	return not bool(npc_system.get_npc_state(required_npc_id).get("escaped", false))


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
	if action_id == NPC_DIALOGUE_ACTION_ID:
		push_warning("talk_to_npc requires a target NPC. Use assign_npc_dialogue(speaker_npc_id, target_npc_id, opening_text).")
		return false
	if action_id == VISIT_LOCATION_ACTION_ID:
		push_warning("visit_location requires a target location. Use assign_visit_location(npc_id, location_id).")
		return false
	if action_id in ["assist_repair", "assist_upgrade"]:
		push_warning("%s requires a target building. Use the matching target-aware assist method." % action_id)
		return false
	if not _can_npc_act(npc_id):
		return false
	if _active_actions.has(npc_id):
		push_warning("NPC is already performing an active action: %s" % npc_id)
		return false

	var action: Dictionary = _actions[action_id]
	var eligibility := get_action_eligibility(npc_id, action_id)
	if not bool(eligibility.get("eligible", false)):
		_update_action_failure(npc_id, "%s_failed_ineligible" % action_id, {
			"action_id": action_id,
			"required_ability": str(eligibility.get("required_ability", "")),
			"unavailable_reason": str(eligibility.get("unavailable_reason", ""))
		})
		_log_action_start_failure(npc_id, action, str(eligibility.get("unavailable_reason", "行动者没有资格")))
		return false
	var can_wait_for_pending_provider := _can_wait_for_pending_provider(action_id, npc_id)
	if not bool(eligibility.get("available_now", false)) and not can_wait_for_pending_provider:
		_fail_action_before_start(npc_id, action, eligibility)
		return false

	var location_id := str(action.get("location_required", ""))
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false

	if not location_id.is_empty():
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var movement_target := str(state.get("movement_target", ""))
		var is_in_transit := (
			not movement_target.is_empty()
			or str(state.get("current_action", "")).begins_with("moving_to_")
		)
		if str(state.get("current_location", "")) != location_id or is_in_transit:
			_pending_actions[npc_id] = action_id
			_pending_action_targets.erase(npc_id)
			_pending_action_options.erase(npc_id)
			return npc_system.move_npc_to_building(npc_id, location_id)

	if _is_gameplay_paused():
		_pending_actions[npc_id] = action_id
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
		return true
	if can_wait_for_pending_provider:
		# A paired plan may dispatch the service provider first while both NPCs are
		# still travelling. Keep the dependent queued until the provider becomes active.
		_pending_actions[npc_id] = action_id
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
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
		_pending_action_options.erase(npc_id)
		return npc_system.move_npc_to_building(npc_id, PLAZA_LOCATION_ID)

	if _is_gameplay_paused():
		_pending_actions[npc_id] = "assist_repair"
		_pending_action_targets[npc_id] = building_id
		_pending_action_options.erase(npc_id)
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
		_pending_action_options.erase(npc_id)
		return npc_system.move_npc_to_building(npc_id, PLAZA_LOCATION_ID)

	if _is_gameplay_paused():
		_pending_actions[npc_id] = "assist_upgrade"
		_pending_action_targets[npc_id] = building_id
		_pending_action_options.erase(npc_id)
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
		_pending_action_options.erase(healer_npc_id)
		return npc_system.move_npc_to_building(healer_npc_id, target_location_id)

	if _is_gameplay_paused():
		_pending_actions[healer_npc_id] = HEALING_ACTION_ID
		_pending_action_targets[healer_npc_id] = target_npc_id
		_pending_action_options.erase(healer_npc_id)
		return true

	return _execute_heal_assist(healer_npc_id, target_npc_id)


func assign_npc_dialogue(
	speaker_npc_id: String,
	target_npc_id: String,
	opening_text: String,
	soft_round_threshold: int = NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD,
	require_real_provider: bool = true,
	plan_context: Dictionary = {}
) -> bool:
	if speaker_npc_id.is_empty() or target_npc_id.is_empty() or speaker_npc_id == target_npc_id:
		_update_action_failure(speaker_npc_id, "talk_to_npc_failed_invalid_target", {
			"action_id": NPC_DIALOGUE_ACTION_ID,
			"target_npc_id": target_npc_id
		})
		return false
	if not _can_npc_act(speaker_npc_id) or not _is_valid_dialogue_target(target_npc_id, true):
		_update_action_failure(speaker_npc_id, "talk_to_npc_failed_target_unavailable", {
			"action_id": NPC_DIALOGUE_ACTION_ID,
			"target_npc_id": target_npc_id
		})
		return false
	if _active_actions.has(speaker_npc_id):
		return false
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("start_autonomous_npc_dialogue"):
		_update_action_failure(speaker_npc_id, "talk_to_npc_failed_dialogue_system", {
			"action_id": NPC_DIALOGUE_ACTION_ID,
			"target_npc_id": target_npc_id
		})
		return false
	if dialog_system.has_method("has_active_dialogue") and dialog_system.has_active_dialogue():
		_update_action_failure(speaker_npc_id, "talk_to_npc_failed_dialogue_busy", {
			"action_id": NPC_DIALOGUE_ACTION_ID,
			"target_npc_id": target_npc_id
		})
		return false
	if _dialogue_reservations.has(speaker_npc_id) or _dialogue_reservations.has(target_npc_id):
		_update_action_failure(speaker_npc_id, "talk_to_npc_failed_target_reserved", {
			"action_id": NPC_DIALOGUE_ACTION_ID,
			"target_npc_id": target_npc_id
		})
		return false

	var npc_system := _get_npc_system()
	if npc_system == null:
		return false
	_dialogue_reservations[speaker_npc_id] = speaker_npc_id
	_dialogue_reservations[target_npc_id] = speaker_npc_id
	var clean_opening := opening_text.strip_edges()
	if clean_opening.is_empty():
		clean_opening = "我想和你谈谈眼下的事情。"
	_pending_actions[speaker_npc_id] = NPC_DIALOGUE_ACTION_ID
	_pending_action_targets[speaker_npc_id] = target_npc_id
	var pending_options := {
		"opening_text": clean_opening,
		"soft_round_threshold": maxi(1, soft_round_threshold),
		"require_real_provider": require_real_provider,
		"chase_count": 0,
		"waiting_for_target_plan": false
	}
	for raw_key in plan_context.keys():
		pending_options[str(raw_key)] = plan_context[raw_key]
	_pending_action_options[speaker_npc_id] = pending_options
	return _approach_or_start_npc_dialogue(speaker_npc_id)


func report_autonomous_dialogue_action_failure(
	speaker_npc_id: String,
	target_npc_id: String,
	failure_id: String,
	message: String = ""
) -> void:
	# Once the asynchronous invitation request has been accepted by LLMBridge,
	# ActionSystem no longer owns a pending action to fail. DialogSystem calls this
	# explicit bridge when that invitation later fails before any real exchange.
	# The normal NPC state-change path then requests a current-hour plan revision.
	if speaker_npc_id.is_empty():
		return
	var normalized_failure_id := failure_id.strip_edges()
	if normalized_failure_id.is_empty() or not normalized_failure_id.contains("failed"):
		normalized_failure_id = "talk_to_npc_failed_async_invitation"
	_update_action_failure(speaker_npc_id, normalized_failure_id, {
		"action_id": NPC_DIALOGUE_ACTION_ID,
		"target_npc_id": target_npc_id,
		"message": message
	})


func assign_visit_location(npc_id: String, location_id: String) -> bool:
	if npc_id.is_empty() or location_id.is_empty() or not _can_npc_act(npc_id):
		return false
	if _active_actions.has(npc_id):
		return false
	var action: Dictionary = _actions.get(VISIT_LOCATION_ACTION_ID, {})
	if action.is_empty() or not _is_enterable_location(location_id):
		_update_action_failure(npc_id, "visit_location_failed_invalid_target", {
			"action_id": VISIT_LOCATION_ACTION_ID,
			"location_id": location_id
		})
		return false
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_location", "")) != location_id:
		_pending_actions[npc_id] = VISIT_LOCATION_ACTION_ID
		_pending_action_targets[npc_id] = location_id
		_pending_action_options[npc_id] = {}
		var moved := bool(npc_system.move_npc_to_building(npc_id, location_id))
		if moved:
			return true
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
		_update_action_failure(npc_id, "visit_location_failed_movement", {
			"action_id": VISIT_LOCATION_ACTION_ID,
			"location_id": location_id
		})
		return false
	if _is_gameplay_paused():
		_pending_actions[npc_id] = VISIT_LOCATION_ACTION_ID
		_pending_action_targets[npc_id] = location_id
		_pending_action_options[npc_id] = {}
		return true
	return _start_visit(npc_id, action, location_id)


func has_pending_action(npc_id: String) -> bool:
	return _pending_actions.has(npc_id)


func has_active_action(npc_id: String) -> bool:
	return _active_actions.has(npc_id)


func get_pending_action_id(npc_id: String) -> String:
	return str(_pending_actions.get(npc_id, ""))


func get_active_action_id(npc_id: String) -> String:
	if not _active_actions.has(npc_id):
		return ""
	var active_action: Dictionary = _active_actions.get(npc_id, {})
	var action: Dictionary = active_action.get("action", {})
	var action_id := str(action.get("id", ""))
	if not action_id.is_empty():
		return action_id
	return str(active_action.get("kind", ""))


func get_runtime_action_id(npc_id: String) -> String:
	var pending_action_id := get_pending_action_id(npc_id)
	if not pending_action_id.is_empty():
		return pending_action_id
	var active_action_id := get_active_action_id(npc_id)
	if not active_action_id.is_empty():
		return active_action_id
	return ""


func get_runtime_action_snapshot(npc_id: String) -> Dictionary:
	if _pending_actions.has(npc_id):
		var pending_action_id := str(_pending_actions.get(npc_id, ""))
		var pending_action := get_action(pending_action_id)
		return {
			"phase": "pending",
			"action_id": pending_action_id,
			"target_id": str(_pending_action_targets.get(npc_id, "")),
			"required_active_action_id": str(pending_action.get("required_active_action_id", "")),
			"blocked_by_active_action_id": str(pending_action.get("blocked_by_active_action_id", "")),
			"options": (_pending_action_options.get(npc_id, {}) as Dictionary).duplicate(true),
		}
	if _active_actions.has(npc_id):
		var active_action: Dictionary = _active_actions.get(npc_id, {})
		var action: Dictionary = active_action.get("action", {}) if active_action.get("action", {}) is Dictionary else {}
		var action_id := str(action.get("id", ""))
		if action_id.is_empty():
			action_id = str(active_action.get("kind", ""))
		var target_id := str(active_action.get("target_npc_id", ""))
		if target_id.is_empty():
			target_id = str(active_action.get("location_id", ""))
		if target_id.is_empty():
			target_id = str(active_action.get("building_id", ""))
		return {
			"phase": "active",
			"action_id": action_id,
			"target_id": target_id,
			"building_id": str(active_action.get("building_id", action.get("location_required", ""))),
			"workstation_id": str(active_action.get("workstation_id", "")),
			"provider_npc_id": str(active_action.get("provider_npc_id", "")),
			"prayer_mode": str(active_action.get("prayer_mode", "")),
			"required_active_action_id": str(action.get("required_active_action_id", "")),
			"blocked_by_active_action_id": str(action.get("blocked_by_active_action_id", "")),
			"elapsed_seconds": float(active_action.get("elapsed_seconds", 0.0)),
			"duration_seconds": float(active_action.get("duration_seconds", 0.0)),
			"medical_skill": int(active_action.get("medical_skill", 0)),
			"options": {},
		}

	# Repair/upgrade helpers are owned by BuildingSystem rather than _active_actions,
	# but their target is encoded in the authoritative NPC action state.
	var npc_system := _get_npc_system()
	if npc_system != null:
		var current_action := str(npc_system.get_npc_state(npc_id).get("current_action", ""))
		for action_id in ["assist_repair", "assist_upgrade"]:
			var prefix := "%s_" % action_id
			if current_action.begins_with(prefix):
				return {
					"phase": "external_active",
					"action_id": action_id,
					"target_id": current_action.trim_prefix(prefix),
					"options": {},
				}
	return {}


func get_daily_plan_dialogue_carryover_snapshot(
	current_day: int = -1,
	current_hour: int = -1
) -> Dictionary:
	var game_state := get_node_or_null(GAME_STATE_PATH)
	if current_day < 0 and game_state != null:
		current_day = int(game_state.current_day)
	if current_hour < 0 and game_state != null:
		current_hour = int(game_state.current_hour)
	var result := {}
	for raw_speaker_npc_id in _pending_actions.keys():
		var speaker_npc_id := str(raw_speaker_npc_id)
		if str(_pending_actions.get(speaker_npc_id, "")) != NPC_DIALOGUE_ACTION_ID:
			continue
		var options: Dictionary = _pending_action_options.get(speaker_npc_id, {})
		if str(options.get("plan_action_source", "")) != "daily_plan":
			continue
		var assigned_day := int(options.get("assigned_plan_day", current_day))
		var assigned_hour := int(options.get("assigned_plan_hour", current_hour))
		if assigned_day != current_day or assigned_hour >= current_hour:
			continue
		result[speaker_npc_id] = {
			"speaker_npc_id": speaker_npc_id,
			"target_npc_id": str(_pending_action_targets.get(speaker_npc_id, "")),
			"phase": "pending",
			"assigned_plan_day": assigned_day,
			"assigned_plan_hour": assigned_hour,
			"assigned_plan_version": int(options.get("assigned_plan_version", -1)),
			"assigned_plan_item": (
				(options.get("assigned_plan_item", {}) as Dictionary).duplicate(true)
				if options.get("assigned_plan_item", {}) is Dictionary
				else {}
			),
			"waiting_for_target_plan": bool(options.get("waiting_for_target_plan", false)),
			"chase_count": int(options.get("chase_count", 0))
		}
	return result


func get_active_work_cycle_snapshots(building_id: String = "", action_ids: Array = []) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for raw_npc_id in _active_actions.keys():
		var npc_id := str(raw_npc_id)
		var active_action: Dictionary = _active_actions.get(npc_id, {})
		var action: Dictionary = active_action.get("action", {}) if active_action.get("action", {}) is Dictionary else {}
		if str(action.get("type", "")) != "work":
			continue
		var active_building_id := str(active_action.get("building_id", action.get("location_required", "")))
		if not building_id.is_empty() and active_building_id != building_id:
			continue
		var action_id := str(action.get("id", ""))
		if not action_ids.is_empty() and not action_ids.has(action_id):
			continue
		var duration := maxf(0.001, float(active_action.get("duration_seconds", DEFAULT_WORK_DURATION_SECONDS)))
		var elapsed := clampf(float(active_action.get("elapsed_seconds", 0.0)), 0.0, duration)
		snapshots.append({
			"npc_id": npc_id,
			"action_id": action_id,
			"building_id": active_building_id,
			"workstation_id": str(active_action.get("workstation_id", "")),
			"elapsed_seconds": elapsed,
			"duration_seconds": duration,
			"progress": elapsed / duration,
			"project_revision": int(active_action.get("crafting_project_revision", -1)),
			"recipe_id": str(active_action.get("crafting_recipe_id", "")),
			"target_item_id": str(active_action.get("crafting_target_item_id", ""))
		})
	return snapshots


func interrupt_work_actions_for_building(
	building_id: String,
	action_ids: Array = [],
	reason: String = "crafting_target_changed"
) -> Array[String]:
	var interrupted: Array[String] = []
	for snapshot in get_active_work_cycle_snapshots(building_id, action_ids):
		var npc_id := str(snapshot.get("npc_id", ""))
		if npc_id.is_empty() or not _active_actions.has(npc_id):
			continue
		_stop_active_action(npc_id, reason)
		interrupted.append(npc_id)
	return interrupted


func interrupt_npc_action(npc_id: String, reason: String = "interrupted", force: bool = false) -> bool:
	if _is_first_sleep_summary_locked(npc_id) and not force:
		return false
	var interrupted_pending_action_id := str(_pending_actions.get(npc_id, ""))
	var had_action := _pending_actions.has(npc_id) or _active_actions.has(npc_id) or _dialogue_reservations.has(npc_id)
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null and dialog_system.has_method("is_npc_in_dialogue") and dialog_system.is_npc_in_dialogue(npc_id):
		var dialogue_state: Dictionary = dialog_system.get_dialogue_state()
		if str(dialogue_state.get("dialogue_kind", "")) == "npc_npc" and str(dialogue_state.get("session_status", "")) == "active":
			dialog_system.force_end_dialogue_for_npc(npc_id, reason)
			had_action = true
	_cancel_dialogue_approach_for_participant(npc_id, reason)
	_pending_actions.erase(npc_id)
	_pending_action_targets.erase(npc_id)
	_pending_action_options.erase(npc_id)
	if interrupted_pending_action_id in [CLINIC_DOCTOR_ACTION_ID, TRAINING_INSTRUCTOR_ACTION_ID, MASS_ACTION_ID]:
		call_deferred("_fail_waiting_dependents_without_provider", interrupted_pending_action_id)
	if _active_actions.has(npc_id):
		_stop_active_action(npc_id, reason)
		had_action = true

	var npc_system := _get_npc_system()
	if npc_system != null:
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var current_action := str(state.get("current_action", ""))
		var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
		for action_id in ["assist_repair", "assist_upgrade"]:
			var prefix := "%s_" % action_id
			if not current_action.begins_with(prefix):
				continue
			var building_id := current_action.trim_prefix(prefix)
			if building_system != null:
				if action_id == "assist_repair" and building_system.has_method("remove_repair_helper"):
					building_system.remove_repair_helper(building_id, npc_id)
				elif action_id == "assist_upgrade" and building_system.has_method("remove_upgrade_helper"):
					building_system.remove_upgrade_helper(building_id, npc_id)
			npc_system.update_npc_state(npc_id, {
				"current_action": "idle",
				"last_action_result": "%s_%s" % [action_id, reason],
			})
			had_action = true
			break
	if npc_system != null and npc_system.has_method("stop_npc_movement_for_system"):
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var current_action := str(state.get("current_action", ""))
		if current_action.begins_with("moving_to_"):
			npc_system.stop_npc_movement_for_system(npc_id, reason)
			had_action = true
	return had_action


func is_npc_committed_to_active_mass(npc_id: String) -> bool:
	if not _active_actions.has(npc_id):
		return false
	var active_action: Dictionary = _active_actions.get(npc_id, {})
	var action: Dictionary = active_action.get("action", {})
	var action_id := str(action.get("id", ""))
	return (
		action_id == MASS_ACTION_ID
		or (
			action_id == PRAY_ACTION_ID
			and str(active_action.get("prayer_mode", "")) == PRAYER_MODE_MASS
		)
	)


func is_npc_dialogue_reserved(npc_id: String) -> bool:
	return _dialogue_reservations.has(npc_id)


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
		_cancel_dialogue_approach_for_participant(npc_id, "talk_to_npc_target_unavailable")
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
		_stop_active_action(npc_id, "")
		return
	if _is_gameplay_paused():
		return
	_try_execute_pending_action(npc_id)
	_retry_pending_npc_dialogue_for_target(npc_id)


func _on_building_state_changed(building_id: String) -> void:
	if building_id.is_empty() or _building_eviction_guards.has(building_id):
		return
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var npc_system := _get_npc_system()
	if building_system == null or npc_system == null:
		return
	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty():
		return
	var is_accessible := (
		bool(building_system.is_building_accessible(building_id))
		if building_system.has_method("is_building_accessible")
		else int(building.get("hp", 0)) > 0 and str(building.get("condition", "")) != "upgrading"
	)
	if is_accessible:
		_refresh_active_building_action_efficiencies(building_id)
		return

	_building_eviction_guards[building_id] = true
	var condition := str(building.get("condition", "unavailable"))
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var current_location := str(state.get("current_location", ""))
		var movement_target := str(state.get("movement_target", ""))
		var pending_action_id := str(_pending_actions.get(npc_id, ""))
		var pending_action: Dictionary = _actions.get(pending_action_id, {})
		var pending_target_id := str(_pending_action_targets.get(npc_id, ""))
		var pending_targets_building := (
			not pending_action_id.is_empty()
			and (
				str(pending_action.get("location_required", "")) == building_id
				or (
					pending_action_id == VISIT_LOCATION_ACTION_ID
					and pending_target_id == building_id
				)
			)
		)
		var active_action: Dictionary = _active_actions.get(npc_id, {})
		var active_definition: Dictionary = active_action.get("action", {})
		var active_action_id := str(active_definition.get("id", ""))
		var active_targets_building := (
			not active_action_id.is_empty()
			and (
				str(active_action.get("building_id", active_action.get("location_id", ""))) == building_id
				or str(active_definition.get("location_required", "")) == building_id
			)
		)
		var targets_building := pending_targets_building or active_targets_building
		if not targets_building:
			if current_location == building_id and npc_system.has_method("debug_enter_location_immediately"):
				npc_system.debug_enter_location_immediately(npc_id, PLAZA_LOCATION_ID)
			elif (
				movement_target == building_id
				and npc_system.has_method("stop_npc_movement_for_system")
			):
				npc_system.stop_npc_movement_for_system(npc_id, "building_%s" % condition)
			continue
		if condition == "upgrading" and pending_targets_building and not active_targets_building:
			# Travellers have not observed the closure yet. Their authoritative
			# failure is produced only when NPCSystem rejects entry at the door.
			continue

		var interrupted_action_id := pending_action_id if not pending_action_id.is_empty() else active_action_id
		var interrupted_action: Dictionary = (
			pending_action
			if not pending_action.is_empty()
			else active_definition
		)
		var interrupted_phase := "pending" if not pending_action_id.is_empty() else "active"
		var building_name := str(building.get("name", building_id))
		var action_name := str(interrupted_action.get("name", interrupted_action_id))
		var failure_reason := "building_upgrading" if condition == "upgrading" else "building_unavailable"
		var unavailable_reason := "建筑正在升级" if condition == "upgrading" else "建筑已经失效"
		var failure_summary := (
			"%s开始升级，依赖该建筑的“%s”行动无法继续。"
			% [building_name, action_name]
			if condition == "upgrading"
			else "%s已经失效，依赖该建筑的“%s”行动无法继续。" % [building_name, action_name]
		)
		interrupt_npc_action(npc_id, "building_%s" % condition, true)
		if current_location == building_id and npc_system.has_method("debug_enter_location_immediately"):
			npc_system.debug_enter_location_immediately(npc_id, PLAZA_LOCATION_ID)
		_update_action_failure(npc_id, "%s_failed_%s" % [interrupted_action_id, failure_reason], {
			"action_id": interrupted_action_id,
			"action_name": action_name,
			"building_id": building_id,
			"building_name": building_name,
			"condition": condition,
			"is_enterable": false,
			"unavailable_reason": unavailable_reason,
			"failure_reason": failure_reason,
			"failure_summary": failure_summary,
			"interrupted_phase": interrupted_phase,
			"was_moving_to_building": movement_target == building_id,
			"current_location_before_failure": current_location,
			"movement_target_before_failure": movement_target
		})
	_building_eviction_guards.erase(building_id)


func _on_npc_building_entry_failed(
	npc_id: String,
	building_id: String,
	entry_context: Dictionary
) -> void:
	var pending_action_id := str(_pending_actions.get(npc_id, ""))
	if pending_action_id.is_empty():
		return
	var pending_action: Dictionary = _actions.get(pending_action_id, {})
	var pending_target_id := str(_pending_action_targets.get(npc_id, ""))
	var targets_building := (
		str(pending_action.get("location_required", "")) == building_id
		or (
			pending_action_id == VISIT_LOCATION_ACTION_ID
			and pending_target_id == building_id
		)
	)
	if not targets_building:
		return
	_pending_actions.erase(npc_id)
	_pending_action_targets.erase(npc_id)
	_pending_action_options.erase(npc_id)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var building: Dictionary = (
		building_system.get_building(building_id)
		if building_system != null and building_system.has_method("get_building")
		else {}
	)
	var condition := str(entry_context.get("condition", building.get("condition", "unavailable")))
	var failure_reason := "building_upgrading" if condition == "upgrading" else "building_unavailable"
	var unavailable_reason := "建筑正在升级" if condition == "upgrading" else "建筑已经失效"
	var building_name := str(building.get("name", building_id))
	var action_name := str(pending_action.get("name", pending_action_id))
	var failure_summary := (
		"到达%s入口后发现建筑正在升级，无法进入执行“%s”。"
		% [building_name, action_name]
		if condition == "upgrading"
		else "到达%s入口后发现建筑已经失效，无法进入执行“%s”。"
		% [building_name, action_name]
	)
	var failure_context := entry_context.duplicate(true)
	failure_context.merge({
		"action_id": pending_action_id,
		"action_name": action_name,
		"building_id": building_id,
		"building_name": building_name,
		"condition": condition,
		"is_enterable": false,
		"unavailable_reason": unavailable_reason,
		"failure_reason": failure_reason,
		"failure_summary": failure_summary,
		"interrupted_phase": "pending",
		"arrival_check_failed": true
	}, true)
	_update_action_failure(
		npc_id,
		"%s_failed_%s" % [pending_action_id, failure_reason],
		failure_context
	)


func _refresh_active_building_action_efficiencies(building_id: String) -> void:
	for raw_npc_id in _active_actions.keys():
		var npc_id := str(raw_npc_id)
		var active_action: Dictionary = _active_actions.get(npc_id, {})
		var action: Dictionary = active_action.get("action", {})
		var active_building_id := str(active_action.get("building_id", action.get("location_required", "")))
		if active_building_id != building_id:
			continue
		if str(action.get("type", "")) != "work" and str(action.get("building_efficiency_key", "")).is_empty():
			continue
		var old_duration := maxf(0.001, float(active_action.get("duration_seconds", _get_action_duration_seconds(action))))
		var old_elapsed := clampf(float(active_action.get("elapsed_seconds", 0.0)), 0.0, old_duration)
		var progress := old_elapsed / old_duration
		var new_duration := _get_effective_action_duration_seconds(action, npc_id)
		active_action["duration_seconds"] = new_duration
		active_action["elapsed_seconds"] = progress * new_duration
		if str(action.get("type", "")) == "work":
			active_action["efficiency_multiplier"] = _get_work_efficiency_multiplier(npc_id, action)
		_active_actions[npc_id] = active_action


func _on_gameplay_pause_changed(paused: bool) -> void:
	if paused:
		return

	for npc_id in _pending_actions.keys():
		_try_execute_pending_action(str(npc_id))


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0 or _is_gameplay_paused():
		return
	expire_invalid_daily_plan_dialogues()
	if _active_actions.is_empty():
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
	if _is_gameplay_paused():
		return
	if not _can_npc_act(npc_id):
		_cancel_dialogue_approach_for_participant(npc_id, "talk_to_npc_target_unavailable")
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
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
	if action_id in [CLINIC_PATIENT_ACTION_ID, TRAINING_STUDENT_ACTION_ID]:
		_try_execute_pending_service_dependent(npc_id, action_id)
		return
	if action_id == NPC_DIALOGUE_ACTION_ID:
		_approach_or_start_npc_dialogue(npc_id)
		return
	if action_id == VISIT_LOCATION_ACTION_ID:
		_try_execute_pending_visit(npc_id)
		return

	if not _actions.has(action_id):
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
		return

	var npc_system := _get_npc_system()
	if npc_system == null:
		return

	var action: Dictionary = _actions[action_id]
	var location_id := str(action.get("location_required", ""))
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		_is_action_commit_ready(npc_id, location_id, state)
		and not _active_actions.has(npc_id)
	):
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
		_execute_action(npc_id, action_id)


func _try_execute_pending_repair_assist(npc_id: String) -> void:
	if _is_gameplay_paused():
		return
	var building_id := str(_pending_action_targets.get(npc_id, ""))
	if building_id.is_empty():
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		return

	var npc_system := _get_npc_system()
	if npc_system == null:
		return

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		_is_action_commit_ready(npc_id, PLAZA_LOCATION_ID, state)
		and not _active_actions.has(npc_id)
	):
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
		_execute_repair_assist(npc_id, building_id)


func _try_execute_pending_upgrade_assist(npc_id: String) -> void:
	if _is_gameplay_paused():
		return
	var building_id := str(_pending_action_targets.get(npc_id, ""))
	if building_id.is_empty():
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		return

	var npc_system := _get_npc_system()
	if npc_system == null:
		return

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		_is_action_commit_ready(npc_id, PLAZA_LOCATION_ID, state)
		and not _active_actions.has(npc_id)
	):
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
		_execute_upgrade_assist(npc_id, building_id)


func _try_execute_pending_heal_assist(npc_id: String) -> void:
	if _is_gameplay_paused():
		return
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
	if (
		_is_action_commit_ready(npc_id, target_location_id, state)
		and not _active_actions.has(npc_id)
	):
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
		_execute_heal_assist(npc_id, target_npc_id)


func _try_execute_pending_training_student(npc_id: String) -> void:
	_try_execute_pending_service_dependent(npc_id, TRAINING_STUDENT_ACTION_ID)


func _try_execute_pending_service_dependent(npc_id: String, action_id: String) -> void:
	if _is_gameplay_paused():
		return
	var npc_system := _get_npc_system()
	if npc_system == null:
		return
	var action: Dictionary = _actions.get(action_id, {})
	if action.is_empty():
		return
	var location_id := str(action.get("location_required", ""))
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		not _is_action_commit_ready(npc_id, location_id, state)
		or _active_actions.has(npc_id)
	):
		return
	var provider_action_id := str(action.get("required_active_action_id", ""))
	if not provider_action_id.is_empty() and _find_active_npc_ids_for_action(provider_action_id).is_empty():
		if _has_pending_action_id(provider_action_id, npc_id):
			return
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
		_execute_action(npc_id, action_id)
		return
	_pending_actions.erase(npc_id)
	_pending_action_targets.erase(npc_id)
	_pending_action_options.erase(npc_id)
	_execute_action(npc_id, action_id)


func _approach_or_start_npc_dialogue(speaker_npc_id: String) -> bool:
	var target_npc_id := str(_pending_action_targets.get(speaker_npc_id, ""))
	var options: Dictionary = _pending_action_options.get(speaker_npc_id, {})
	var invalid_plan_context := _get_invalid_daily_plan_dialogue_context(speaker_npc_id)
	if not invalid_plan_context.is_empty():
		_fail_pending_npc_dialogue(
			speaker_npc_id,
			"talk_to_npc_failed_plan_superseded",
			invalid_plan_context
		)
		return false
	if target_npc_id.is_empty() or not _is_valid_dialogue_target(target_npc_id, true):
		_fail_pending_npc_dialogue(speaker_npc_id, "talk_to_npc_failed_target_unavailable")
		return false
	var npc_system := _get_npc_system()
	if npc_system == null:
		_fail_pending_npc_dialogue(speaker_npc_id, "talk_to_npc_failed_npc_system")
		return false
	var speaker_state: Dictionary = npc_system.get_npc_state(speaker_npc_id)
	var target_state: Dictionary = npc_system.get_npc_state(target_npc_id)
	var target_location_id := str(target_state.get("current_location", PLAZA_LOCATION_ID))
	if not _is_enterable_location(target_location_id):
		_fail_pending_npc_dialogue(speaker_npc_id, "talk_to_npc_failed_target_location")
		return false
	if str(speaker_state.get("current_location", "")) != target_location_id:
		if str(speaker_state.get("current_action", "")).begins_with("moving_to_"):
			return true
		var chase_count := int(options.get("chase_count", 0))
		if chase_count > NPC_DIALOGUE_MAX_CHASES:
			_fail_pending_npc_dialogue(speaker_npc_id, "talk_to_npc_failed_target_moved")
			return false
		options["chase_count"] = chase_count + 1
		_pending_action_options[speaker_npc_id] = options
		var moved := bool(npc_system.move_npc_to_building(speaker_npc_id, target_location_id))
		if not moved:
			_fail_pending_npc_dialogue(speaker_npc_id, "talk_to_npc_failed_movement")
		return moved
	if str(speaker_state.get("current_action", "")) != "idle" or _is_gameplay_paused():
		return true
	if _is_npc_plan_generation_busy(target_npc_id, npc_system):
		options["waiting_for_target_plan"] = true
		_pending_action_options[speaker_npc_id] = options
		return true
	options["waiting_for_target_plan"] = false
	_pending_action_options[speaker_npc_id] = options

	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("start_autonomous_npc_dialogue"):
		_fail_pending_npc_dialogue(speaker_npc_id, "talk_to_npc_failed_dialogue_system")
		return false
	var start_result: Dictionary = dialog_system.start_autonomous_npc_dialogue(
		speaker_npc_id,
		target_npc_id,
		str(options.get("opening_text", "")),
		"local_public",
		int(options.get("soft_round_threshold", NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD)),
		bool(options.get("require_real_provider", true)),
		options.duplicate(true)
	)
	if bool(start_result.get("ok", false)):
		_pending_actions.erase(speaker_npc_id)
		_pending_action_targets.erase(speaker_npc_id)
		_pending_action_options.erase(speaker_npc_id)
		_release_dialogue_reservations(speaker_npc_id)
		return true
	if str(start_result.get("error_code", "")) == "npc_planning":
		options["waiting_for_target_plan"] = true
		_pending_action_options[speaker_npc_id] = options
		return true
	_pending_actions.erase(speaker_npc_id)
	_pending_action_targets.erase(speaker_npc_id)
	_pending_action_options.erase(speaker_npc_id)
	_release_dialogue_reservations(speaker_npc_id)
	_update_action_failure(speaker_npc_id, "talk_to_npc_failed_start", {
		"action_id": NPC_DIALOGUE_ACTION_ID,
		"target_npc_id": target_npc_id,
		"error_code": str(start_result.get("error_code", "dialogue_start_failed")),
		"message": str(start_result.get("message", "NPC 对话启动失败。"))
	})
	return false


func _retry_pending_npc_dialogue_for_target(target_npc_id: String) -> void:
	var speaker_npc_id := str(_dialogue_reservations.get(target_npc_id, ""))
	if speaker_npc_id.is_empty() or speaker_npc_id == target_npc_id:
		return
	if str(_pending_actions.get(speaker_npc_id, "")) != NPC_DIALOGUE_ACTION_ID:
		return
	if str(_pending_action_targets.get(speaker_npc_id, "")) != target_npc_id:
		return
	var options: Dictionary = _pending_action_options.get(speaker_npc_id, {})
	if not bool(options.get("waiting_for_target_plan", false)):
		return
	var npc_system := _get_npc_system()
	if npc_system == null or _is_npc_plan_generation_busy(target_npc_id, npc_system):
		return
	call_deferred("_continue_pending_npc_dialogue_after_plan", speaker_npc_id, target_npc_id)


func _continue_pending_npc_dialogue_after_plan(speaker_npc_id: String, target_npc_id: String) -> void:
	if str(_pending_actions.get(speaker_npc_id, "")) != NPC_DIALOGUE_ACTION_ID:
		return
	if str(_pending_action_targets.get(speaker_npc_id, "")) != target_npc_id:
		return
	var options: Dictionary = _pending_action_options.get(speaker_npc_id, {})
	if not bool(options.get("waiting_for_target_plan", false)):
		return
	var npc_system := _get_npc_system()
	if npc_system != null and _is_npc_plan_generation_busy(target_npc_id, npc_system):
		return
	_approach_or_start_npc_dialogue(speaker_npc_id)


func expire_invalid_daily_plan_dialogues(current_day: int = -1, current_hour: int = -1) -> Array[String]:
	var expired_npc_ids: Array[String] = []
	for raw_speaker_npc_id in _pending_actions.keys():
		var speaker_npc_id := str(raw_speaker_npc_id)
		if str(_pending_actions.get(speaker_npc_id, "")) != NPC_DIALOGUE_ACTION_ID:
			continue
		var failure_context := _get_invalid_daily_plan_dialogue_context(
			speaker_npc_id,
			current_day,
			current_hour
		)
		if failure_context.is_empty():
			continue
		_fail_pending_npc_dialogue(
			speaker_npc_id,
			"talk_to_npc_failed_plan_superseded",
			failure_context
		)
		expired_npc_ids.append(speaker_npc_id)
	return expired_npc_ids


func _get_invalid_daily_plan_dialogue_context(
	speaker_npc_id: String,
	current_day: int = -1,
	current_hour: int = -1
) -> Dictionary:
	var options: Dictionary = _pending_action_options.get(speaker_npc_id, {})
	if str(options.get("plan_action_source", "")) != "daily_plan":
		return {}
	var game_state := get_node_or_null(GAME_STATE_PATH)
	if current_day < 0 and game_state != null:
		current_day = int(game_state.current_day)
	if current_hour < 0 and game_state != null:
		current_hour = int(game_state.current_hour)
	var assigned_day := int(options.get("assigned_plan_day", current_day))
	var assigned_hour := int(options.get("assigned_plan_hour", current_hour))
	# Once a planned conversation is already in progress, an ordinary hour change
	# does not revoke it. A new day remains a hard boundary and may supersede it.
	if assigned_day == current_day and assigned_hour < current_hour:
		return {}
	var daily_plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if daily_plan_system == null or not daily_plan_system.has_method("get_current_plan_item"):
		return {}
	var target_npc_id := str(_pending_action_targets.get(speaker_npc_id, ""))
	var current_plan_item: Dictionary = daily_plan_system.get_current_plan_item(speaker_npc_id)
	var current_target_npc_id := _get_plan_dialogue_target_id(current_plan_item)
	if (
		assigned_day == current_day
		and str(current_plan_item.get("action_id", "")) == NPC_DIALOGUE_ACTION_ID
		and current_target_npc_id == target_npc_id
	):
		return {}
	var assigned_plan_item: Dictionary = (
		(options.get("assigned_plan_item", {}) as Dictionary).duplicate(true)
		if options.get("assigned_plan_item", {}) is Dictionary
		else {}
	)
	var current_plan_version := -1
	if daily_plan_system.has_method("get_plan_version"):
		current_plan_version = int(daily_plan_system.get_plan_version(speaker_npc_id))
	return {
		"reason": "daily_plan_item_changed_while_dialogue_pending",
		"failure_summary": "等待对方制定计划期间，当前计划已不再要求与原目标对话。",
		"waiting_for_target_plan": bool(options.get("waiting_for_target_plan", false)),
		"assigned_plan_day": assigned_day,
		"assigned_plan_hour": assigned_hour,
		"assigned_plan_version": int(options.get("assigned_plan_version", -1)),
		"assigned_plan_item": assigned_plan_item.duplicate(true),
		"failed_plan_item": assigned_plan_item.duplicate(true),
		"assigned_target_npc_id": target_npc_id,
		"current_plan_day": current_day,
		"current_plan_hour": current_hour,
		"current_plan_version": current_plan_version,
		"current_plan_item": current_plan_item.duplicate(true),
		"current_target_npc_id": current_target_npc_id,
		"waited_across_hour": assigned_day != current_day or assigned_hour != current_hour
	}


func _get_plan_dialogue_target_id(item: Dictionary) -> String:
	var target: Dictionary = item.get("target", {}) if item.get("target", {}) is Dictionary else {}
	return str(target.get("target_npc_id", target.get("target_id", item.get("target_id", ""))))


func _try_execute_pending_visit(npc_id: String) -> void:
	if _is_gameplay_paused():
		return
	var location_id := str(_pending_action_targets.get(npc_id, ""))
	var npc_system := _get_npc_system()
	if location_id.is_empty() or npc_system == null or not _is_enterable_location(location_id):
		_pending_actions.erase(npc_id)
		_pending_action_targets.erase(npc_id)
		_pending_action_options.erase(npc_id)
		_update_action_failure(npc_id, "visit_location_failed_invalid_target", {
			"action_id": VISIT_LOCATION_ACTION_ID,
			"location_id": location_id
		})
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		not _is_action_commit_ready(npc_id, location_id, state)
		or _active_actions.has(npc_id)
	):
		return
	_pending_actions.erase(npc_id)
	_pending_action_targets.erase(npc_id)
	_pending_action_options.erase(npc_id)
	_start_visit(npc_id, _actions.get(VISIT_LOCATION_ACTION_ID, {}), location_id)


func _execute_action(npc_id: String, action_id: String) -> bool:
	var action: Dictionary = _actions[action_id]
	if not _is_action_commit_ready(
		npc_id,
		str(action.get("location_required", ""))
	):
		return false
	var action_type := str(action.get("type", ""))
	match action_type:
		"work":
			return _start_work(npc_id, action)
		"eat":
			return _start_eat(npc_id, action)
		"drink":
			return _start_drink(npc_id, action)
		"sleep":
			return _start_sleep(npc_id, action)
		"pray":
			return _start_pray(npc_id, action)
		"clinic_doctor":
			return _start_clinic_doctor(npc_id, action)
		"clinic_patient":
			return _start_clinic_patient(npc_id, action)
		"training_instructor":
			return _start_training_instructor(npc_id, action)
		"training_student":
			return _start_training_student(npc_id, action)
		"targeted_heal":
			push_warning("assist_heal requires a target NPC. Use debug_assign_heal_assist(healer_npc_id, target_npc_id).")
			return false
		"npc_dialogue", "visit", "proactive_talk":
			push_warning("Action type %s requires a target-aware plan dispatcher." % action_type)
			return false
		_:
			push_warning("Unsupported action type: %s" % action_type)
			return false


func _execute_repair_assist(npc_id: String, building_id: String) -> bool:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null or building_system == null:
		return false
	if (
		not _is_action_commit_ready(npc_id, PLAZA_LOCATION_ID)
		or _active_actions.has(npc_id)
	):
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
	if (
		not _is_action_commit_ready(npc_id, PLAZA_LOCATION_ID)
		or _active_actions.has(npc_id)
	):
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
	if (
		not _is_action_commit_ready(
			healer_npc_id,
			_get_target_healing_location(target_npc_id)
		)
		or _active_actions.has(healer_npc_id)
	):
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
		_update_action_failure(npc_id, "clinic_doctor_failed_no_workstation", _make_workstation_failure_context(action, claim_result))
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", CLINIC_DOCTOR_ACTION_ID)),
			"reason": "没有空闲诊疗工位",
			"building_id": CLINIC_LOCATION_ID,
			"blocked_by_npc_ids": claim_result.get("blocked_by_npc_ids", [])
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
	_retry_pending_dependents_for_provider(CLINIC_DOCTOR_ACTION_ID)
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
	if _find_active_clinic_doctor_ids().is_empty():
		_fail_action_before_start(npc_id, action, {
			"building_id": CLINIC_LOCATION_ID,
			"required_active_action_id": CLINIC_DOCTOR_ACTION_ID,
			"unavailable_reason": "诊所没有在岗医生"
		})
		return false

	var claim_result: Dictionary = building_system.claim_workstation(
		CLINIC_LOCATION_ID,
		npc_id,
		str(action.get("workstation_type", CLINIC_PATIENT_BED_TYPE))
	)
	if not bool(claim_result.get("ok", false)):
		_update_action_failure(npc_id, "clinic_patient_failed_no_bed", _make_workstation_failure_context(action, claim_result))
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", CLINIC_PATIENT_ACTION_ID)),
			"reason": "没有空闲病床",
			"building_id": CLINIC_LOCATION_ID,
			"blocked_by_npc_ids": claim_result.get("blocked_by_npc_ids", [])
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


func _start_training_instructor(npc_id: String, action: Dictionary) -> bool:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null or building_system == null:
		return false

	var equipped_skills := _get_equipped_training_skills(npc_system.get_npc(npc_id))
	if equipped_skills.is_empty():
		_update_action_failure(npc_id, "training_instructor_failed_no_equipment")
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", TRAINING_INSTRUCTOR_ACTION_ID)),
			"reason": "没有可训练的武器或坐骑",
			"building_id": TRAINING_LOCATION_ID
		})
		return false

	var claim_result: Dictionary = building_system.claim_workstation(
		TRAINING_LOCATION_ID,
		npc_id,
		str(action.get("workstation_type", TRAINING_INSTRUCTOR_WORKSTATION_TYPE))
	)
	if not bool(claim_result.get("ok", false)):
		_update_action_failure(npc_id, "training_instructor_failed_no_workstation", _make_workstation_failure_context(action, claim_result))
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", TRAINING_INSTRUCTOR_ACTION_ID)),
			"reason": "没有空闲教官工位",
			"building_id": TRAINING_LOCATION_ID,
			"blocked_by_npc_ids": claim_result.get("blocked_by_npc_ids", [])
		})
		return false

	npc_system.update_npc_state(npc_id, {
		"current_action": str(action.get("id", TRAINING_INSTRUCTOR_ACTION_ID)),
		"last_action_result": "started_%s" % str(action.get("id", TRAINING_INSTRUCTOR_ACTION_ID))
	})
	_active_actions[npc_id] = {
		"kind": "training_instructor",
		"action": action.duplicate(true),
		"building_id": TRAINING_LOCATION_ID,
		"workstation_id": str(claim_result.get("workstation_id", "")),
		"solo_skill_timer_seconds": {},
		"coaching_skill_timer_seconds": 0.0
	}
	_log_structured_action_event(npc_id, action, "work_started", {
		"action_id": str(action.get("id", TRAINING_INSTRUCTOR_ACTION_ID)),
		"workstation_id": str(claim_result.get("workstation_id", "")),
		"building_id": TRAINING_LOCATION_ID,
		"training_skills": equipped_skills
	})
	_retry_pending_training_students()
	return true


func _retry_pending_training_students() -> void:
	_retry_pending_dependents_for_provider(TRAINING_INSTRUCTOR_ACTION_ID)


func _has_pending_training_instructor(excluded_npc_id: String = "") -> bool:
	return _has_pending_action_id(TRAINING_INSTRUCTOR_ACTION_ID, excluded_npc_id)


func _fail_waiting_training_students_without_instructor() -> void:
	_fail_waiting_dependents_without_provider(TRAINING_INSTRUCTOR_ACTION_ID)


func _start_training_student(npc_id: String, action: Dictionary) -> bool:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null or building_system == null:
		return false

	var equipped_skills := _get_equipped_training_skills(npc_system.get_npc(npc_id))
	if equipped_skills.is_empty():
		_update_action_failure(npc_id, "training_student_failed_no_equipment")
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", TRAINING_STUDENT_ACTION_ID)),
			"reason": "没有可训练的武器或坐骑",
			"building_id": TRAINING_LOCATION_ID
		})
		return false

	var instructor_ids := _find_active_training_instructor_ids()
	if instructor_ids.is_empty():
		_update_action_failure(npc_id, "training_student_failed_no_instructor")
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", TRAINING_STUDENT_ACTION_ID)),
			"reason": "训练场没有教官",
			"building_id": TRAINING_LOCATION_ID
		})
		return false

	var claim_result: Dictionary = building_system.claim_workstation(
		TRAINING_LOCATION_ID,
		npc_id,
		str(action.get("workstation_type", TRAINING_STUDENT_WORKSTATION_TYPE))
	)
	if not bool(claim_result.get("ok", false)):
		_update_action_failure(npc_id, "training_student_failed_no_workstation", _make_workstation_failure_context(action, claim_result))
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", TRAINING_STUDENT_ACTION_ID)),
			"reason": "没有空闲受训位",
			"building_id": TRAINING_LOCATION_ID,
			"blocked_by_npc_ids": claim_result.get("blocked_by_npc_ids", [])
		})
		return false

	npc_system.update_npc_state(npc_id, {
		"current_action": str(action.get("id", TRAINING_STUDENT_ACTION_ID)),
		"last_action_result": "started_%s" % str(action.get("id", TRAINING_STUDENT_ACTION_ID))
	})
	_active_actions[npc_id] = {
		"kind": "training_student",
		"action": action.duplicate(true),
		"building_id": TRAINING_LOCATION_ID,
		"workstation_id": str(claim_result.get("workstation_id", "")),
		"instructor_npc_id": str(instructor_ids[0]),
		"instructor_npc_ids": instructor_ids.duplicate(),
		"training_skills": equipped_skills,
		"skill_timers": {}
	}
	_log_structured_action_event(npc_id, action, "work_started", {
		"action_id": str(action.get("id", TRAINING_STUDENT_ACTION_ID)),
		"workstation_id": str(claim_result.get("workstation_id", "")),
		"building_id": TRAINING_LOCATION_ID,
		"instructor_npc_id": str(instructor_ids[0]),
		"instructor_npc_ids": instructor_ids.duplicate(),
		"training_skills": equipped_skills
	})
	return true


func _start_work(npc_id: String, action: Dictionary) -> bool:
	var resource_system := _get_resource_system()
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if resource_system == null or npc_system == null or building_system == null:
		return false

	var building_id := str(action.get("location_required", ""))
	var crafting_context: Dictionary = {}
	if bool(action.get("requires_crafting_target", false)):
		var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
		if crafting_system == null or not crafting_system.has_method("can_start_work_cycle"):
			_update_action_failure(npc_id, "work_failed_no_crafting_system")
			return false
		crafting_context = crafting_system.can_start_work_cycle(building_id, npc_id)
		if not bool(crafting_context.get("ok", false)):
			var crafting_failure := str(crafting_context.get("error", crafting_context.get("reason", "crafting_target_missing")))
			_update_action_failure(npc_id, "work_failed_%s" % crafting_failure, crafting_context)
			_log_structured_action_event(
				npc_id,
				action,
				"work_failed",
				_build_crafting_failure_event_payload(
					action,
					building_id,
					crafting_failure,
					crafting_context
				)
			)
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

	var claim_result: Dictionary = {}
	if building_system.has_method("claim_workstation"):
		claim_result = building_system.claim_workstation(building_id, npc_id, str(action.get("workstation_type", "")))
	if not bool(claim_result.get("ok", false)):
		_update_action_failure(npc_id, "work_failed_no_workstation", _make_workstation_failure_context(action, claim_result))
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", "")),
			"reason": "没有空闲工位",
			"building_id": building_id,
			"duration_seconds": _get_effective_action_duration_seconds(action, npc_id),
			"blocked_by_npc_ids": claim_result.get("blocked_by_npc_ids", [])
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
		"efficiency_multiplier": efficiency_multiplier,
		"crafting_recipe_id": str(crafting_context.get("recipe_id", "")),
		"crafting_target_item_id": str(crafting_context.get("target_item_id", "")),
		"crafting_project_revision": int(crafting_context.get("project_revision", -1))
	})

	npc_system.update_npc_state(npc_id, {
		"current_action": str(action.get("id", "work")),
		"last_action_result": "started_%s" % str(action.get("id", "work"))
	})
	var active_action := _create_active_action(action, npc_id)
	active_action["building_id"] = building_id
	active_action["workstation_id"] = workstation_id
	active_action["efficiency_multiplier"] = efficiency_multiplier
	if not crafting_context.is_empty():
		active_action["crafting_project_revision"] = int(crafting_context.get("project_revision", -1))
		active_action["crafting_recipe_id"] = str(crafting_context.get("recipe_id", ""))
		active_action["crafting_target_item_id"] = str(crafting_context.get("target_item_id", ""))
	_active_actions[npc_id] = active_action
	return true


func _complete_work(npc_id: String, active_action: Dictionary) -> void:
	var action: Dictionary = active_action.get("action", {})
	var resource_system := _get_resource_system()
	if resource_system == null:
		_release_workstation_for_action(npc_id, active_action)
		_update_action_failure(npc_id, "work_failed_no_resource_system")
		return
	if bool(action.get("requires_crafting_target", false)):
		var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
		if crafting_system == null or not crafting_system.has_method("complete_stage"):
			_release_workstation_for_action(npc_id, active_action)
			_update_action_failure(npc_id, "work_failed_no_crafting_system")
			return
		var building_id := str(active_action.get("building_id", action.get("location_required", "")))
		var crafting_result: Dictionary = crafting_system.complete_stage(
			building_id,
			int(active_action.get("crafting_project_revision", -1)),
			npc_id
		)
		if not bool(crafting_result.get("ok", false)):
			_clear_crafting_cycle_progress(npc_id, active_action)
			_release_workstation_for_action(npc_id, active_action)
			var crafting_failure := str(crafting_result.get("error", crafting_result.get("reason", "crafting_stage_failed")))
			_update_action_failure(npc_id, "work_failed_%s" % crafting_failure, crafting_result)
			var failure_payload := _build_crafting_failure_event_payload(
				action,
				building_id,
				crafting_failure,
				crafting_result
			)
			failure_payload["recipe_id"] = str(
				failure_payload.get("recipe_id", active_action.get("crafting_recipe_id", ""))
			)
			failure_payload["workstation_id"] = str(active_action.get("workstation_id", ""))
			_log_structured_action_event(npc_id, action, "work_failed", failure_payload)
			return
		var crafting_inputs: Dictionary = crafting_result.get("input_resources", {}) if crafting_result.get("input_resources", {}) is Dictionary else {}
		var crafting_outputs: Dictionary = crafting_result.get("output_resources", {}) if crafting_result.get("output_resources", {}) is Dictionary else {}
		_apply_building_effects(action)
		_apply_final_state_deltas(npc_id, active_action)
		_improve_work_skill(npc_id, action)
		_release_workstation_for_action(npc_id, active_action)
		_set_action_idle(npc_id, "completed_%s" % str(action.get("id", "work")))
		_log_structured_action_event(npc_id, action, "work_completed", {
			"action_id": str(action.get("id", "")),
			"input_resources": crafting_inputs,
			"output_resources": crafting_outputs,
			"building_id": building_id,
			"workstation_id": str(active_action.get("workstation_id", "")),
			"recipe_id": str(crafting_result.get("recipe_id", active_action.get("crafting_recipe_id", ""))),
			"target_item_id": str(crafting_result.get("target_item_id", active_action.get("crafting_target_item_id", ""))),
			"completed_stage": (
				(crafting_result.get("completed_stage", {}) as Dictionary).duplicate(true)
				if crafting_result.get("completed_stage", {}) is Dictionary
				else {}
			),
			"total_stages": int(
				(crafting_result.get("project", {}) as Dictionary).get("total_stages", 0)
				if crafting_result.get("project", {}) is Dictionary
				else 0
			),
			"product_completed": bool(crafting_result.get("product_completed", false)),
			"base_duration_seconds": _get_action_duration_seconds(action),
			"duration_seconds": float(active_action.get("duration_seconds", _get_action_duration_seconds(action))),
			"efficiency_multiplier": float(active_action.get("efficiency_multiplier", 1.0))
		})
		return

	var input_resources: Dictionary = action.get("input_resources", {})
	var output_resources: Dictionary = _get_work_output_resources(action, npc_id)
	if (
		resource_system.has_method("can_store_resources")
		and not bool(resource_system.can_store_resources(output_resources))
	):
		_release_workstation_for_action(npc_id, active_action)
		_update_action_failure(npc_id, "work_failed_storage_capacity", {
			"output_resources": output_resources.duplicate(true),
			"failure_reason": "warehouse_capacity"
		})
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", "")),
			"reason": "仓库容量不足",
			"output_resources": output_resources,
			"workstation_id": str(active_action.get("workstation_id", "")),
			"building_id": str(active_action.get("building_id", action.get("location_required", ""))),
			"duration_seconds": float(active_action.get("duration_seconds", _get_action_duration_seconds(action)))
		})
		return
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

	if resource_system.has_method("add_resources"):
		if not bool(resource_system.add_resources(output_resources)):
			# Capacity was checked before inputs were spent; reaching this branch
			# means another same-frame producer filled the warehouse first.
			for raw_resource_id in input_resources.keys():
				resource_system.add_resource(str(raw_resource_id), int(input_resources[raw_resource_id]))
			_release_workstation_for_action(npc_id, active_action)
			_update_action_failure(npc_id, "work_failed_storage_capacity", {
				"output_resources": output_resources.duplicate(true),
				"failure_reason": "warehouse_capacity_race"
			})
			return
	else:
		for resource_id in output_resources.keys():
			resource_system.add_resource(str(resource_id), int(output_resources[resource_id]))

	_apply_building_effects(action)
	_apply_final_state_deltas(npc_id, active_action)
	_improve_work_skill(npc_id, action)
	_release_workstation_for_action(npc_id, active_action)
	_set_action_idle(npc_id, "completed_%s" % str(action.get("id", "work")))
	_log_structured_action_event(npc_id, action, "work_completed", {
		"action_id": str(action.get("id", "")),
		"input_resources": input_resources,
		"output_resources": output_resources,
		"building_hp_restore": int(action.get("building_hp_restore", 0)),
		"needs_profile": str(action.get("needs_profile", "")),
		"workstation_id": str(active_action.get("workstation_id", "")),
		"building_id": str(active_action.get("building_id", action.get("location_required", ""))),
		"base_duration_seconds": _get_action_duration_seconds(action),
		"duration_seconds": float(active_action.get("duration_seconds", _get_action_duration_seconds(action))),
		"efficiency_multiplier": float(active_action.get("efficiency_multiplier", 1.0))
	})


func _start_eat(npc_id: String, action: Dictionary) -> bool:
	var resource_system := _get_resource_system()
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if resource_system == null or npc_system == null or building_system == null:
		return false

	var building_id := str(action.get("location_required", "dining_hall"))
	var claim_result: Dictionary = building_system.claim_workstation(
		building_id,
		npc_id,
		str(action.get("workstation_type", "dining_seat"))
	)
	if not bool(claim_result.get("ok", false)):
		_update_action_failure(npc_id, "eat_failed_no_seat", _make_workstation_failure_context(action, claim_result))
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
				building_system.release_workstation(building_id, npc_id, str(claim_result.get("workstation_id", "")))
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
			active_action["building_id"] = building_id
			active_action["workstation_id"] = str(claim_result.get("workstation_id", ""))
			active_action["resource_id"] = resource_id
			active_action["amount"] = cost
			active_action["state_deltas"] = {"satiety": int(option.get("satiety_restore", 0))}
			_active_actions[npc_id] = active_action
			return true

	building_system.release_workstation(building_id, npc_id, str(claim_result.get("workstation_id", "")))
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
	_release_workstation_for_action(npc_id, active_action)
	_set_action_idle(npc_id, "completed_eat")
	_log_structured_action_event(npc_id, action, "eat_completed", {
		"action_id": str(action.get("id", "")),
		"resource_id": str(active_action.get("resource_id", "")),
		"amount": int(active_action.get("amount", 0)),
		"satiety_restore": int(active_action.get("state_deltas", {}).get("satiety", 0)),
		"duration_seconds": _get_action_duration_seconds(action)
	})


func _start_drink(npc_id: String, action: Dictionary) -> bool:
	var npc_system := _get_npc_system()
	if npc_system == null or not npc_system.has_method("spend_npc_owned_resources"):
		return false
	var personal_resource_cost: Dictionary = (
		action.get("personal_resource_cost", {})
		if action.get("personal_resource_cost", {}) is Dictionary
		else {}
	)
	var spend_result: Dictionary = npc_system.spend_npc_owned_resources(npc_id, personal_resource_cost)
	if not bool(spend_result.get("ok", false)):
		var failure_context := {
			"action_id": str(action.get("id", DRINK_WINE_ACTION_ID)),
			"resource_id": "wine",
			"unavailable_reason": "自己当前没有酒，无法饮酒"
		}
		_update_action_failure(npc_id, "drink_wine_failed_no_wine", failure_context)
		_log_action_start_failure(npc_id, action, "自己当前没有酒，无法饮酒", failure_context)
		return false

	var owned_before: Dictionary = spend_result.get("owned_resources_before", {})
	var owned_after: Dictionary = spend_result.get("owned_resources_after", {})
	var amount := int(personal_resource_cost.get("wine", 1))
	npc_system.update_npc_state(npc_id, {
		"current_action": str(action.get("id", DRINK_WINE_ACTION_ID)),
		"last_action_result": "started_drink_wine",
		"last_action_failure_context": {}
	})
	var active_action := _create_active_action(action, npc_id)
	active_action["personal_resource_cost"] = personal_resource_cost.duplicate(true)
	_active_actions[npc_id] = active_action
	var event_action := action.duplicate(true)
	var current_location := str(npc_system.get_npc_state(npc_id).get("current_location", PLAZA_LOCATION_ID))
	event_action["location_required"] = current_location
	_log_structured_action_event(npc_id, event_action, "wine_consumed", {
		"action_id": str(action.get("id", DRINK_WINE_ACTION_ID)),
		"resource_id": "wine",
		"amount": amount,
		"npc_wine_before": int(owned_before.get("wine", 0)),
		"npc_wine_after": int(owned_after.get("wine", 0)),
		"context_effect": "饮酒改善了心情，让过去的伤痛暂时淡化；不删除记忆，也不产生情绪数值。"
	})
	return true


func _complete_drink(npc_id: String, _active_action: Dictionary) -> void:
	_set_action_idle(npc_id, "completed_drink_wine")


func _start_sleep(npc_id: String, action: Dictionary) -> bool:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null or building_system == null:
		return false
	var building_id := str(action.get("location_required", "dormitory"))
	var claim_result: Dictionary = building_system.claim_workstation(
		building_id,
		npc_id,
		str(action.get("workstation_type", "dormitory_bed"))
	)
	if not bool(claim_result.get("ok", false)):
		_update_action_failure(npc_id, "sleep_failed_no_bed", _make_workstation_failure_context(action, claim_result))
		return false
	_log_structured_action_event(npc_id, action, "sleep_started", {
		"action_id": str(action.get("id", "")),
		"duration_seconds": _get_action_duration_seconds(action)
	})
	npc_system.update_npc_state(npc_id, {
		"current_action": str(action.get("id", "sleep")),
		"last_action_result": "started_sleep"
	})
	var active_action := _create_active_action(action, npc_id)
	active_action["building_id"] = building_id
	active_action["workstation_id"] = str(claim_result.get("workstation_id", ""))
	_active_actions[npc_id] = active_action
	return true


func _complete_sleep(npc_id: String, active_action: Dictionary) -> void:
	var action: Dictionary = active_action.get("action", {})
	if _is_first_sleep_summary_locked(npc_id):
		_active_actions[npc_id] = active_action
		return
	_apply_final_state_deltas(npc_id, active_action)
	_release_workstation_for_action(npc_id, active_action)
	_set_action_idle(npc_id, "completed_sleep")
	_log_structured_action_event(npc_id, action, "sleep_ended", {
		"action_id": str(action.get("id", "")),
		"needs_profile": str(action.get("needs_profile", "")),
		"duration_seconds": _get_action_duration_seconds(action)
	})
	var npc_system := _get_npc_system()
	if npc_system != null and npc_system.has_method("consume_deferred_plan_reevaluation_after_sleep"):
		npc_system.consume_deferred_plan_reevaluation_after_sleep(npc_id)


func _start_pray(npc_id: String, action: Dictionary) -> bool:
	var npc_system := _get_npc_system()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if npc_system == null or building_system == null:
		return false
	var action_id := str(action.get("id", PRAY_ACTION_ID))
	var building_id := str(action.get("location_required", "chapel"))
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		str(state.get("current_location", "")) != building_id
		or not str(state.get("movement_target", "")).is_empty()
		or str(state.get("current_action", "")).begins_with("moving_to_")
	):
		var location_failure_id := "%s_failed_target_unavailable_not_arrived" % action_id
		var location_failure_context := {
			"action_id": action_id,
			"building_id": building_id,
			"current_location": str(state.get("current_location", "")),
			"movement_target": str(state.get("movement_target", "")),
			"unavailable_reason": "尚未实际到达小教堂，不能开始教堂活动"
		}
		_update_action_failure(npc_id, location_failure_id, location_failure_context)
		_log_action_start_failure(
			npc_id,
			action,
			str(location_failure_context["unavailable_reason"]),
			location_failure_context
		)
		return false
	var eligibility := get_action_eligibility(npc_id, action_id)
	if not bool(eligibility.get("eligible", false)):
		_update_action_failure(npc_id, "%s_failed_ineligible" % action_id, {
			"action_id": action_id,
			"building_id": building_id,
			"required_ability": str(eligibility.get("required_ability", "")),
			"unavailable_reason": str(eligibility.get("unavailable_reason", ""))
		})
		_log_structured_action_event(npc_id, action, "prayer_failed", {
			"action_id": action_id,
			"reason": str(eligibility.get("unavailable_reason", "行动者没有资格")),
			"building_id": building_id
		})
		return false
	if not bool(eligibility.get("available_now", false)):
		_fail_action_before_start(npc_id, action, eligibility)
		return false
	var claim_result: Dictionary = building_system.claim_workstation(
		building_id,
		npc_id,
		str(action.get("workstation_type", "chapel_prayer_seat"))
	)
	if not bool(claim_result.get("ok", false)):
		var workstation_failure_id := "pray_failed_no_workstation" if action_id == PRAY_ACTION_ID else "%s_failed_no_workstation" % action_id
		_update_action_failure(npc_id, workstation_failure_id, _make_workstation_failure_context(action, claim_result))
		_log_structured_action_event(npc_id, action, "prayer_failed", {
			"action_id": action_id,
			"reason": "没有空闲的%s" % ("祭坛" if action_id == MASS_ACTION_ID else "祈祷席"),
			"building_id": building_id,
			"blocked_by_npc_ids": claim_result.get("blocked_by_npc_ids", [])
		})
		return false
	var started_result := "started_prayer"
	var active_kind := "prayer"
	if action_id == MASS_ACTION_ID:
		started_result = "started_mass"
		active_kind = "mass_leader"
	var mass_leader_id := ""
	if action_id == PRAY_ACTION_ID:
		mass_leader_id = _find_active_mass_leader_id()
		if not mass_leader_id.is_empty():
			started_result = "started_mass_attendance"
	npc_system.update_npc_state(npc_id, {
		"current_action": action_id,
		"last_action_result": started_result,
		"last_action_failure_context": {}
	})
	var active_action := _create_active_action(action, npc_id)
	active_action["kind"] = active_kind
	active_action["building_id"] = building_id
	active_action["workstation_id"] = str(claim_result.get("workstation_id", ""))
	if action_id == PRAY_ACTION_ID:
		active_action["prayer_mode"] = (
			PRAYER_MODE_MASS
			if not mass_leader_id.is_empty()
			else PRAYER_MODE_PERSONAL
		)
		if not mass_leader_id.is_empty():
			active_action["provider_npc_id"] = mass_leader_id
	_active_actions[npc_id] = active_action
	_log_structured_action_event(npc_id, action, "prayer_started", {
		"action_id": action_id,
		"building_id": building_id,
		"workstation_id": str(claim_result.get("workstation_id", "")),
		"duration_seconds": _get_action_duration_seconds(action),
		"prayer_mode": str(active_action.get("prayer_mode", ""))
	})
	if action_id == PRAY_ACTION_ID and not mass_leader_id.is_empty():
		_log_prayer_mode_transition(
			npc_id,
			action,
			"prayer_joined_mass",
			mass_leader_id,
			"prayer_started_during_mass"
		)
	if action_id == MASS_ACTION_ID:
		_transition_active_prayers_to_mass(npc_id)
	return true


func _complete_pray(npc_id: String, active_action: Dictionary) -> void:
	var action: Dictionary = active_action.get("action", {})
	var action_id := str(action.get("id", PRAY_ACTION_ID))
	_release_workstation_for_action(npc_id, active_action)
	var completed_result := "completed_prayer"
	if action_id == MASS_ACTION_ID:
		completed_result = "completed_mass"
	_set_action_idle(npc_id, completed_result)
	_log_structured_action_event(npc_id, action, "prayer_completed", {
		"action_id": action_id,
		"building_id": str(active_action.get("building_id", "chapel")),
		"workstation_id": str(active_action.get("workstation_id", "")),
		"duration_seconds": float(active_action.get("duration_seconds", _get_action_duration_seconds(action))),
		"prayer_mode": str(active_action.get("prayer_mode", ""))
	})


func _start_visit(npc_id: String, action: Dictionary, location_id: String) -> bool:
	if action.is_empty() or not _is_enterable_location(location_id):
		return false
	if (
		not _is_action_commit_ready(npc_id, location_id)
		or _active_actions.has(npc_id)
	):
		return false
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false
	var runtime_action := action.duplicate(true)
	runtime_action["location_required"] = location_id
	npc_system.update_npc_state(npc_id, {
		"current_action": "%s_%s" % [VISIT_LOCATION_ACTION_ID, location_id],
		"last_action_result": "started_visit_%s" % location_id,
		"last_action_failure_context": {}
	})
	var active_action := _create_active_action(runtime_action, npc_id)
	active_action["kind"] = "visit"
	active_action["location_id"] = location_id
	_active_actions[npc_id] = active_action
	_log_structured_action_event(npc_id, runtime_action, "visit_started", {
		"action_id": VISIT_LOCATION_ACTION_ID,
		"location_id": location_id,
		"duration_seconds": _get_action_duration_seconds(runtime_action)
	})
	return true


func _complete_visit(npc_id: String, active_action: Dictionary) -> void:
	var action: Dictionary = active_action.get("action", {})
	var location_id := str(active_action.get("location_id", action.get("location_required", PLAZA_LOCATION_ID)))
	_set_action_idle(npc_id, "completed_visit_%s" % location_id)
	_log_structured_action_event(npc_id, action, "visit_completed", {
		"action_id": VISIT_LOCATION_ACTION_ID,
		"location_id": location_id,
		"duration_seconds": float(active_action.get("duration_seconds", _get_action_duration_seconds(action)))
	})


func _create_active_action(action: Dictionary, npc_id: String = "") -> Dictionary:
	return {
		"action": action.duplicate(true),
		"elapsed_seconds": 0.0,
		"duration_seconds": _get_effective_action_duration_seconds(action, npc_id),
		"state_deltas": {},
		"applied_state_deltas": {}
	}


func _advance_active_action(npc_id: String, game_delta_seconds: float) -> void:
	if _is_first_sleep_summary_locked(npc_id):
		return
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
	if str(active_action.get("kind", "")) == "training_instructor":
		_advance_training_instructor(npc_id, active_action, game_delta_seconds)
		return
	if str(active_action.get("kind", "")) == "training_student":
		_advance_training_student(npc_id, active_action, game_delta_seconds)
		return
	var duration := maxf(0.001, float(active_action.get("duration_seconds", DEFAULT_WORK_DURATION_SECONDS)))
	var elapsed_before := clampf(float(active_action.get("elapsed_seconds", 0.0)), 0.0, duration)
	var elapsed := clampf(elapsed_before + game_delta_seconds, 0.0, duration)
	var action: Dictionary = active_action.get("action", {})
	if str(action.get("type", "")) == "pray":
		_add_piety_from_prayer(
			npc_id,
			str(action.get("id", "")),
			maxf(0.0, elapsed - elapsed_before),
			str(active_action.get("prayer_mode", ""))
		)
	active_action["elapsed_seconds"] = elapsed
	_active_actions[npc_id] = active_action
	_sync_crafting_cycle_progress(npc_id, active_action, elapsed / duration)

	_apply_progress_state_deltas(npc_id, active_action)
	active_action = _active_actions.get(npc_id, active_action)

	if (
		elapsed >= duration
		and str(action.get("id", "")) == PRAY_ACTION_ID
		and str(active_action.get("prayer_mode", "")) == PRAYER_MODE_MASS
	):
		# Personal prayer time may expire while the NPC is attending Mass, but
		# an ordinary timer completion must not make an attendee walk out before
		# the active Mass ends.
		return
	if elapsed < duration:
		return

	if str(action.get("id", "")) == MASS_ACTION_ID:
		_transition_mass_prayers_to_personal(
			npc_id,
			"mass_completed",
			"主持弥撒正常结束"
		)
	_active_actions.erase(npc_id)
	match str(action.get("type", "")):
		"work":
			_complete_work(npc_id, active_action)
		"eat":
			_complete_eat(npc_id, active_action)
		"drink":
			_complete_drink(npc_id, active_action)
		"sleep":
			_complete_sleep(npc_id, active_action)
		"pray":
			_complete_pray(npc_id, active_action)
		"visit":
			_complete_visit(npc_id, active_action)


func _add_piety_from_prayer(
	npc_id: String,
	action_id: String,
	active_game_seconds: float,
	prayer_mode: String
) -> void:
	if active_game_seconds <= 0.0:
		return
	var piety_system := get_node_or_null(PIETY_SYSTEM_PATH)
	if piety_system == null or not piety_system.has_method("add_prayer_progress"):
		return
	piety_system.add_prayer_progress(
		npc_id,
		action_id,
		active_game_seconds,
		prayer_mode
	)


func _advance_clinic_doctor(doctor_npc_id: String, active_action: Dictionary, game_delta_seconds: float) -> void:
	var npc_system := _get_npc_system()
	if npc_system == null:
		_stop_active_action(doctor_npc_id, "clinic_doctor_failed_no_npc_system")
		return
	if str(npc_system.get_npc_state(doctor_npc_id).get("current_location", "")) != CLINIC_LOCATION_ID:
		_stop_active_action(doctor_npc_id, "clinic_doctor_left_clinic")
		return

	var patient_ids := _find_active_clinic_patient_ids()
	if patient_ids.is_empty():
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
			_stop_active_action(doctor_npc_id, "clinic_doctor_failed_no_money")
			return
		cost_timer -= cost_interval
		money_spent += HEALING_INITIAL_COST

	var hp_per_hour := _get_clinic_hp_per_hour(doctor_npc_id)
	var remainders: Dictionary = active_action.get("hp_recovery_remainders", {})
	for patient_id in patient_ids:
		if not _active_actions.has(patient_id):
			continue
		var accumulated := float(remainders.get(patient_id, 0.0)) + hp_per_hour / 3600.0 * game_delta_seconds
		var hp_to_restore := int(floor(accumulated))
		if hp_to_restore > 0:
			accumulated -= float(hp_to_restore)
			var recovery_result: Dictionary = npc_system.restore_npc_hp(patient_id, hp_to_restore, "clinic_treatment", doctor_npc_id)
			if not recovery_result.is_empty():
				_update_active_clinic_patient_healer(patient_id, doctor_npc_id, money_spent)
				var patient_state: Dictionary = npc_system.get_npc_state(patient_id)
				if int(patient_state.get("hp", 0)) >= int(patient_state.get("max_hp", 100)):
					var patient_action: Dictionary = _active_actions.get(patient_id, {})
					_finish_clinic_patient(
						patient_id,
						doctor_npc_id,
						"clinic_treatment_completed",
						int(patient_action.get("money_spent", money_spent))
					)
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
	if _find_active_clinic_doctor_ids().is_empty():
		_fail_active_service_dependent(
			npc_id,
			"clinic_patient_failed_doctor_left",
			"全部医生已经离开诊疗位",
			CLINIC_DOCTOR_ACTION_ID
		)
		return
	if int(state.get("hp", 0)) >= int(state.get("max_hp", 100)):
		_finish_clinic_patient(npc_id, str(_active_action.get("healer_npc_id", "")), "clinic_treatment_completed", int(_active_action.get("money_spent", 0)))


func _advance_training_instructor(instructor_npc_id: String, active_action: Dictionary, game_delta_seconds: float) -> void:
	var npc_system := _get_npc_system()
	if npc_system == null:
		_stop_active_action(instructor_npc_id, "training_instructor_failed_no_npc_system")
		return
	if str(npc_system.get_npc_state(instructor_npc_id).get("current_location", "")) != TRAINING_LOCATION_ID:
		_stop_active_action(instructor_npc_id, "training_instructor_left_training_ground")
		return
	if _get_equipped_training_skills(npc_system.get_npc(instructor_npc_id)).is_empty():
		_stop_active_action(instructor_npc_id, "training_instructor_failed_no_equipment")
		return

	var student_ids := _find_active_training_students_for_instructor(instructor_npc_id)
	if student_ids.is_empty():
		active_action = _advance_solo_training(instructor_npc_id, active_action, game_delta_seconds)
	else:
		active_action = _advance_coaching_skill(instructor_npc_id, active_action, game_delta_seconds, student_ids.size())
	if not _active_actions.has(instructor_npc_id):
		return
	_active_actions[instructor_npc_id] = active_action


func _advance_training_student(student_npc_id: String, active_action: Dictionary, game_delta_seconds: float) -> void:
	var npc_system := _get_npc_system()
	if npc_system == null:
		_stop_active_action(student_npc_id, "training_student_failed_no_npc_system")
		return
	if str(npc_system.get_npc_state(student_npc_id).get("current_location", "")) != TRAINING_LOCATION_ID:
		_stop_active_action(student_npc_id, "training_student_left_training_ground")
		return

	var instructor_ids := _find_active_training_instructor_ids()
	if instructor_ids.is_empty():
		_fail_active_service_dependent(
			student_npc_id,
			"training_student_failed_instructor_left",
			"全部教官已经离开教官位",
			TRAINING_INSTRUCTOR_ACTION_ID
		)
		return
	active_action["instructor_npc_id"] = str(instructor_ids[0])
	active_action["instructor_npc_ids"] = instructor_ids.duplicate()

	var current_skills := _get_equipped_training_skills(npc_system.get_npc(student_npc_id))
	if current_skills.is_empty():
		_stop_active_action(student_npc_id, "training_student_failed_no_equipment")
		return
	active_action["training_skills"] = current_skills

	var skill_timers: Dictionary = active_action.get("skill_timers", {})
	for skill_name in current_skills:
		var interval := _get_training_team_skill_interval_seconds(
			instructor_ids,
			student_npc_id,
			skill_name,
			active_action.get("action", {})
		)
		var timer := float(skill_timers.get(skill_name, 0.0)) + game_delta_seconds
		while timer >= interval:
			timer -= interval
			_improve_npc_skill(student_npc_id, skill_name, 1, "training_student")
		skill_timers[skill_name] = timer
	active_action["skill_timers"] = skill_timers
	_active_actions[student_npc_id] = active_action


func _advance_solo_training(instructor_npc_id: String, active_action: Dictionary, game_delta_seconds: float) -> Dictionary:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return active_action
	var action: Dictionary = active_action.get("action", {})
	var interval := maxf(1.0, float(action.get("solo_skill_interval_seconds", TRAINING_SOLO_SKILL_INTERVAL_SECONDS)))
	var equipped_skills := _get_equipped_training_skills(npc_system.get_npc(instructor_npc_id))
	if equipped_skills.is_empty():
		_stop_active_action(instructor_npc_id, "training_instructor_failed_no_equipment")
		return active_action
	var timers: Dictionary = active_action.get("solo_skill_timer_seconds", {})
	for skill_name in equipped_skills:
		var timer := float(timers.get(skill_name, 0.0)) + game_delta_seconds
		while timer >= interval:
			timer -= interval
			_improve_npc_skill(instructor_npc_id, skill_name, 1, "training_solo")
		timers[skill_name] = timer
	active_action["solo_skill_timer_seconds"] = timers
	return active_action


func _advance_coaching_skill(instructor_npc_id: String, active_action: Dictionary, game_delta_seconds: float, student_count: int) -> Dictionary:
	var action: Dictionary = active_action.get("action", {})
	var base_interval := maxf(1.0, float(action.get("coaching_skill_interval_seconds", TRAINING_COACHING_SKILL_INTERVAL_SECONDS)))
	var interval := maxf(600.0, base_interval / (1.0 + maxf(0.0, float(student_count - 1)) * 0.25))
	var timer := float(active_action.get("coaching_skill_timer_seconds", 0.0)) + game_delta_seconds
	while timer >= interval:
		timer -= interval
		_improve_npc_skill(instructor_npc_id, "教练", 1, "training_coaching")
	active_action["coaching_skill_timer_seconds"] = timer
	return active_action


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
		_finish_healing_assist(healer_npc_id, target_npc_id, "assist_heal_failed_left_location")
		return

	var cost_timer := float(active_action.get("cost_timer_seconds", 0.0)) + game_delta_seconds
	var money_spent := int(active_action.get("money_spent", 0))
	while cost_timer >= HEALING_COST_INTERVAL_SECONDS:
		if not _spend_healing_cost():
			active_action["cost_timer_seconds"] = cost_timer
			active_action["money_spent"] = money_spent
			_active_actions[healer_npc_id] = active_action
			_finish_healing_assist(healer_npc_id, target_npc_id, "assist_heal_failed_no_money")
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


func _get_action_duration_seconds(action: Dictionary) -> float:
	if action.has("duration_seconds"):
		return maxf(1.0, float(action.get("duration_seconds", DEFAULT_WORK_DURATION_SECONDS)))
	return maxf(1.0, float(action.get("base_duration_hours", DEFAULT_WORK_DURATION_HOURS)) * 3600.0)


func _get_effective_action_duration_seconds(action: Dictionary, npc_id: String = "") -> float:
	var base_duration := _get_action_duration_seconds(action)
	if str(action.get("type", "")) == "work" and not npc_id.is_empty():
		var work_multiplier := _get_work_efficiency_multiplier(npc_id, action)
		return maxf(60.0, base_duration / maxf(0.1, work_multiplier))
	var efficiency_key := str(action.get("building_efficiency_key", ""))
	if not efficiency_key.is_empty():
		var building_multiplier := _get_building_activity_efficiency_multiplier(
			str(action.get("location_required", "")),
			efficiency_key
		)
		return maxf(60.0, base_duration / maxf(0.1, building_multiplier))
	return base_duration


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
	var worker_multiplier := clampf(1.0 + skill_bonus + attribute_bonus + building_bonus, 1.0, WORK_MAX_SPEED_MULTIPLIER)
	var building_multiplier := _get_building_activity_efficiency_multiplier(
		building_id,
		str(action.get("building_efficiency_key", "production"))
	)
	return maxf(0.1, worker_multiplier * building_multiplier)


func _get_building_activity_efficiency_multiplier(building_id: String, activity_key: String) -> float:
	if building_id.is_empty():
		return 1.0
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		return 1.0
	if building_system.has_method("get_building_activity_efficiency_multiplier"):
		return maxf(0.0, float(building_system.get_building_activity_efficiency_multiplier(building_id, activity_key)))
	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty() or int(building.get("hp", 0)) <= 0 or str(building.get("condition", "")) == "upgrading":
		return 0.0
	return clampf(float(building.get("hp", 0)) / maxf(1.0, float(building.get("max_hp", 1))), 0.1, 1.0)


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
			"last_action_result": last_result,
			"last_action_failure_context": {}
		})


func _update_action_failure(npc_id: String, failure_id: String, failure_context: Dictionary = {}) -> void:
	if npc_id.is_empty():
		return
	var authoritative_failure_context := failure_context.duplicate(true)
	authoritative_failure_context["failure_id"] = failure_id
	var npc_system := _get_npc_system()
	if npc_system != null:
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": failure_id,
			"last_action_failure_context": authoritative_failure_context
		})
	if failure_id.begins_with("clinic_doctor_failed"):
		call_deferred("_fail_waiting_dependents_without_provider", CLINIC_DOCTOR_ACTION_ID)
	elif failure_id.begins_with("training_instructor_failed"):
		call_deferred("_fail_waiting_dependents_without_provider", TRAINING_INSTRUCTOR_ACTION_ID)


func _build_crafting_failure_event_payload(
	action: Dictionary,
	building_id: String,
	crafting_error: String,
	failure_context: Dictionary
) -> Dictionary:
	var reason_messages := {
		"crafting_target_missing": "未选择制造目标",
		"unsupported_building": "该建筑不支持制造",
		"stage_commit_in_progress": "另一名工人正在结算同一制造阶段",
		"invalid_current_recipe": "当前制造配方无效",
		"invalid_current_stage": "当前制造阶段无效",
		"resource_system_unavailable": "资源系统不可用",
		"output_inventory_missing": "产物库存项不存在",
		"insufficient_stage_resources": "当前制造阶段材料不足",
		"project_revision_mismatch": "制造目标已发生变化",
		"stage_resource_commit_failed": "制造阶段材料扣除失败",
		"output_inventory_commit_failed": "制造产物入库失败",
		"crafting_stage_failed": "制造阶段未能完成"
	}
	var project: Dictionary = (
		(failure_context.get("project", {}) as Dictionary).duplicate(true)
		if failure_context.get("project", {}) is Dictionary
		else {}
	)
	var required_resources: Dictionary = (
		(failure_context.get("required_resources", {}) as Dictionary).duplicate(true)
		if failure_context.get("required_resources", {}) is Dictionary
		else {}
	)
	if required_resources.is_empty() and project.get("current_stage_cost", {}) is Dictionary:
		required_resources = (project.get("current_stage_cost", {}) as Dictionary).duplicate(true)
	var crafting_project := {}
	for key in [
		"target_recipe_id",
		"recipe_id",
		"target_item_id",
		"target_name",
		"project_revision",
		"completed_stages",
		"total_stages",
		"current_stage_index",
		"current_stage_id",
		"current_stage_name",
		"current_stage_cost",
		"stock_amount"
	]:
		if project.has(key):
			crafting_project[key] = (
				(project[key] as Dictionary).duplicate(true)
				if project[key] is Dictionary
				else project[key]
			)
	var payload := {
		"action_id": str(action.get("id", "")),
		"reason": str(failure_context.get(
			"message",
			reason_messages.get(crafting_error, "制造阶段未能完成")
		)),
		"failure_reason": crafting_error,
		"crafting_error": crafting_error,
		"building_id": building_id,
		"required_resources": required_resources,
		"crafting_project": crafting_project
	}
	var recipe_id := str(
		project.get(
			"recipe_id",
			project.get("target_recipe_id", failure_context.get("recipe_id", ""))
		)
	)
	if not recipe_id.is_empty():
		payload["recipe_id"] = recipe_id
	return payload


func _stop_active_action(npc_id: String, last_result: String = "active_action_stopped") -> void:
	if not _active_actions.has(npc_id):
		return
	var active_action: Dictionary = _active_actions[npc_id]
	_clear_crafting_cycle_progress(npc_id, active_action)
	var stopped_action_id := str(active_action.get("action", {}).get("id", ""))
	var has_workstation := not str(active_action.get("workstation_id", "")).is_empty()
	if has_workstation:
		_release_workstation_for_action(npc_id, active_action)
	if str(active_action.get("kind", "")) == HEALING_ACTION_ID:
		var target_npc_id := str(active_action.get("target_npc_id", ""))
		_remove_healing_helper(target_npc_id, npc_id)
	elif str(active_action.get("action", {}).get("type", "")) == "work":
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
	if stopped_action_id in [CLINIC_DOCTOR_ACTION_ID, TRAINING_INSTRUCTOR_ACTION_ID, MASS_ACTION_ID]:
		_handle_service_provider_stopped(stopped_action_id, npc_id, last_result)


func _sync_crafting_cycle_progress(npc_id: String, active_action: Dictionary, progress: float) -> void:
	var action: Dictionary = active_action.get("action", {}) if active_action.get("action", {}) is Dictionary else {}
	if str(action.get("type", "")) != "work" or not bool(action.get("requires_crafting_target", false)):
		return
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system == null or not crafting_system.has_method("set_work_cycle_progress"):
		return
	crafting_system.call(
		"set_work_cycle_progress",
		str(active_action.get("building_id", action.get("location_required", ""))),
		int(active_action.get("crafting_project_revision", -1)),
		npc_id,
		clampf(progress, 0.0, 1.0)
	)


func _clear_crafting_cycle_progress(npc_id: String, active_action: Dictionary) -> void:
	var action: Dictionary = active_action.get("action", {}) if active_action.get("action", {}) is Dictionary else {}
	if str(action.get("type", "")) != "work" or not bool(action.get("requires_crafting_target", false)):
		return
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system == null or not crafting_system.has_method("clear_work_cycle_progress"):
		return
	crafting_system.call(
		"clear_work_cycle_progress",
		str(active_action.get("building_id", action.get("location_required", ""))),
		npc_id,
		int(active_action.get("crafting_project_revision", -1))
	)


func _finish_healing_assist(healer_npc_id: String, target_npc_id: String, reason: String) -> void:
	var active_action: Dictionary = _active_actions.get(healer_npc_id, {})
	var money_spent := int(active_action.get("money_spent", 0))
	_remove_healing_helper(target_npc_id, healer_npc_id)
	_active_actions.erase(healer_npc_id)
	var completed_normally := reason in ["target_revived", "target_no_longer_unconscious"]
	if completed_normally:
		_set_action_idle(healer_npc_id, "assist_heal_completed_%s" % target_npc_id)
	else:
		_update_action_failure(healer_npc_id, reason, {
			"action_id": HEALING_ACTION_ID,
			"target_npc_id": target_npc_id,
			"resource_id": HEALING_RESOURCE_ID if reason == "assist_heal_failed_no_money" else "",
		})
	var event_payload := {
		"action_id": HEALING_ACTION_ID,
		"healer_npc_id": healer_npc_id,
		"target_npc_id": target_npc_id,
		"money_spent": money_spent,
	}
	if not completed_normally:
		event_payload["reason"] = reason
	_log_healing_event(
		healer_npc_id,
		target_npc_id,
		"healing_completed" if completed_normally else "healing_failed",
		event_payload
	)


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


func _find_active_npc_ids_for_action(action_id: String) -> Array[String]:
	var result: Array[String] = []
	for raw_npc_id in _active_actions.keys():
		var npc_id := str(raw_npc_id)
		if _is_active_provider_for_action(npc_id, action_id):
			result.append(npc_id)
	result.sort()
	return result


func _is_active_provider_for_action(npc_id: String, action_id: String) -> bool:
	if not _active_actions.has(npc_id):
		return false
	var active_action: Dictionary = _active_actions.get(npc_id, {})
	var action: Dictionary = active_action.get("action", {})
	if str(action.get("id", "")) != action_id:
		return false
	var npc_system := _get_npc_system()
	if npc_system == null or not npc_system.can_npc_act(npc_id):
		return false
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_action", "")) != action_id:
		return false
	var building_id := str(active_action.get("building_id", action.get("location_required", "")))
	if not building_id.is_empty() and str(state.get("current_location", "")) != building_id:
		return false
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		return false
	if building_system.has_method("is_building_usable") and not bool(building_system.is_building_usable(building_id)):
		return false
	var workstation_id := str(active_action.get("workstation_id", ""))
	if workstation_id.is_empty():
		return false
	var workstation_claim_is_valid := false
	var building: Dictionary = building_system.get_building(building_id)
	for raw_workstation in building.get("workstations", []):
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		if (
			str(workstation.get("id", "")) == workstation_id
			and str(workstation.get("occupied_by", "")) == npc_id
		):
			workstation_claim_is_valid = true
			break
	if not workstation_claim_is_valid:
		return false
	if action_id == TRAINING_INSTRUCTOR_ACTION_ID and _get_equipped_training_skills(npc_system.get_npc(npc_id)).is_empty():
		return false
	return true


func _find_active_mass_leader_id() -> String:
	var leader_ids := _find_active_npc_ids_for_action(MASS_ACTION_ID)
	return "" if leader_ids.is_empty() else leader_ids[0]


func _get_dependent_action_ids_for_provider(provider_action_id: String) -> Array[String]:
	match provider_action_id:
		CLINIC_DOCTOR_ACTION_ID:
			return [CLINIC_PATIENT_ACTION_ID]
		TRAINING_INSTRUCTOR_ACTION_ID:
			return [TRAINING_STUDENT_ACTION_ID]
	return []


func _has_pending_action_id(action_id: String, excluded_npc_id: String = "") -> bool:
	for raw_npc_id in _pending_actions.keys():
		var npc_id := str(raw_npc_id)
		if npc_id == excluded_npc_id:
			continue
		if str(_pending_actions.get(npc_id, "")) == action_id:
			return true
	return false


func _can_wait_for_pending_provider(action_id: String, npc_id: String = "") -> bool:
	var action: Dictionary = _actions.get(action_id, {})
	var provider_action_id := str(action.get("required_active_action_id", ""))
	return (
		not provider_action_id.is_empty()
		and _find_active_npc_ids_for_action(provider_action_id).is_empty()
		and _has_pending_action_id(provider_action_id, npc_id)
	)


func _retry_pending_dependents_for_provider(provider_action_id: String) -> void:
	for dependent_action_id in _get_dependent_action_ids_for_provider(provider_action_id):
		for raw_npc_id in _pending_actions.keys():
			var npc_id := str(raw_npc_id)
			if str(_pending_actions.get(npc_id, "")) == dependent_action_id:
				_try_execute_pending_service_dependent(npc_id, dependent_action_id)


func _fail_waiting_dependents_without_provider(provider_action_id: String) -> void:
	if (
		not _find_active_npc_ids_for_action(provider_action_id).is_empty()
		or _has_pending_action_id(provider_action_id)
	):
		return
	var npc_system := _get_npc_system()
	for dependent_action_id in _get_dependent_action_ids_for_provider(provider_action_id):
		for raw_npc_id in _pending_actions.keys():
			var npc_id := str(raw_npc_id)
			if str(_pending_actions.get(npc_id, "")) != dependent_action_id:
				continue
			_pending_actions.erase(npc_id)
			_pending_action_targets.erase(npc_id)
			_pending_action_options.erase(npc_id)
			if npc_system != null and npc_system.has_method("stop_npc_movement_for_system"):
				npc_system.stop_npc_movement_for_system(
					npc_id,
					"%s_provider_unavailable" % dependent_action_id,
					false
				)
			var action: Dictionary = _actions.get(dependent_action_id, {})
			_fail_action_before_start(npc_id, action, {
				"building_id": str(action.get("location_required", "")),
				"required_active_action_id": provider_action_id,
				"unavailable_reason": _get_missing_dependency_reason(dependent_action_id)
			})


func _handle_service_provider_stopped(provider_action_id: String, provider_npc_id: String, reason: String) -> void:
	if provider_action_id == MASS_ACTION_ID:
		var replacement_leader_id := _find_active_mass_leader_id()
		if replacement_leader_id.is_empty():
			_transition_mass_prayers_to_personal(
				provider_npc_id,
				"mass_leader_stopped",
				reason
			)
		else:
			_rebind_mass_prayers(provider_npc_id, replacement_leader_id)
		return
	if not _find_active_npc_ids_for_action(provider_action_id).is_empty():
		return
	var failure_id := "service_activity_failed_provider_left"
	var failure_reason := "服务人员已经全部离开"
	match provider_action_id:
		CLINIC_DOCTOR_ACTION_ID:
			failure_id = "clinic_patient_failed_doctor_left"
			failure_reason = "全部医生已经离开诊疗位"
		TRAINING_INSTRUCTOR_ACTION_ID:
			failure_id = "training_student_failed_instructor_left"
			failure_reason = "全部教官已经离开教官位"
	for dependent_action_id in _get_dependent_action_ids_for_provider(provider_action_id):
		var dependent_ids: Array[String] = []
		for raw_npc_id in _active_actions.keys():
			var npc_id := str(raw_npc_id)
			var active_action: Dictionary = _active_actions.get(npc_id, {})
			if str(active_action.get("action", {}).get("id", "")) == dependent_action_id:
				dependent_ids.append(npc_id)
		for dependent_npc_id in dependent_ids:
			_fail_active_service_dependent(
				dependent_npc_id,
				failure_id,
				failure_reason,
				provider_action_id,
				provider_npc_id,
				reason
			)
	_fail_waiting_dependents_without_provider(provider_action_id)


func _fail_active_service_dependent(
	npc_id: String,
	failure_id: String,
	reason: String,
	provider_action_id: String,
	provider_npc_id: String = "",
	provider_stop_reason: String = ""
) -> void:
	if not _active_actions.has(npc_id):
		return
	var active_action: Dictionary = _active_actions.get(npc_id, {})
	var action: Dictionary = active_action.get("action", {})
	_release_workstation_for_action(npc_id, active_action)
	_active_actions.erase(npc_id)
	var failure_context := {
		"action_id": str(action.get("id", "")),
		"building_id": str(active_action.get("building_id", action.get("location_required", ""))),
		"required_active_action_id": provider_action_id,
		"provider_npc_id": provider_npc_id,
		"provider_stop_reason": provider_stop_reason,
		"unavailable_reason": reason
	}
	_update_action_failure(npc_id, failure_id, failure_context)
	_log_action_start_failure(npc_id, action, reason, failure_context)


func _transition_active_prayers_to_mass(leader_npc_id: String) -> void:
	for raw_npc_id in _active_actions.keys():
		var npc_id := str(raw_npc_id)
		var active_action: Dictionary = _active_actions.get(npc_id, {})
		var action: Dictionary = active_action.get("action", {})
		if (
			str(action.get("id", "")) != PRAY_ACTION_ID
			or str(active_action.get("prayer_mode", PRAYER_MODE_PERSONAL)) == PRAYER_MODE_MASS
		):
			continue
		active_action["prayer_mode"] = PRAYER_MODE_MASS
		active_action["provider_npc_id"] = leader_npc_id
		_active_actions[npc_id] = active_action
		var npc_system := _get_npc_system()
		if npc_system != null:
			npc_system.update_npc_state(npc_id, {
				"current_action": PRAY_ACTION_ID,
				"last_action_result": "prayer_joined_mass",
				"last_action_failure_context": {}
			})
		_log_prayer_mode_transition(
			npc_id,
			action,
			"prayer_joined_mass",
			leader_npc_id,
			"mass_started"
		)


func _transition_mass_prayers_to_personal(
	leader_npc_id: String,
	trigger: String,
	provider_stop_reason: String
) -> void:
	for raw_npc_id in _active_actions.keys():
		var npc_id := str(raw_npc_id)
		var active_action: Dictionary = _active_actions.get(npc_id, {})
		var action: Dictionary = active_action.get("action", {})
		if (
			str(action.get("id", "")) != PRAY_ACTION_ID
			or str(active_action.get("prayer_mode", "")) != PRAYER_MODE_MASS
			or str(active_action.get("provider_npc_id", "")) != leader_npc_id
		):
			continue
		active_action["prayer_mode"] = PRAYER_MODE_PERSONAL
		active_action.erase("provider_npc_id")
		_active_actions[npc_id] = active_action
		var npc_system := _get_npc_system()
		if npc_system != null:
			npc_system.update_npc_state(npc_id, {
				"current_action": PRAY_ACTION_ID,
				"last_action_result": "prayer_resumed_alone",
				"last_action_failure_context": {}
			})
		_log_prayer_mode_transition(
			npc_id,
			action,
			"prayer_resumed_alone",
			leader_npc_id,
			trigger,
			provider_stop_reason
		)
		if (
			float(active_action.get("elapsed_seconds", 0.0))
			>= float(active_action.get(
				"duration_seconds",
				_get_action_duration_seconds(action)
			))
		):
			_active_actions.erase(npc_id)
			_complete_pray(npc_id, active_action)


func _rebind_mass_prayers(stopped_leader_npc_id: String, replacement_leader_npc_id: String) -> void:
	for raw_npc_id in _active_actions.keys():
		var npc_id := str(raw_npc_id)
		var active_action: Dictionary = _active_actions.get(npc_id, {})
		if (
			str(active_action.get("action", {}).get("id", "")) == PRAY_ACTION_ID
			and str(active_action.get("prayer_mode", "")) == PRAYER_MODE_MASS
			and str(active_action.get("provider_npc_id", "")) == stopped_leader_npc_id
		):
			active_action["provider_npc_id"] = replacement_leader_npc_id
			_active_actions[npc_id] = active_action


func _log_prayer_mode_transition(
	npc_id: String,
	action: Dictionary,
	event_type: String,
	leader_npc_id: String,
	trigger: String,
	provider_stop_reason: String = ""
) -> void:
	var payload := {
		"action_id": PRAY_ACTION_ID,
		"leader_npc_id": leader_npc_id,
		"trigger": trigger,
		"from_mode": (
			PRAYER_MODE_PERSONAL
			if event_type == "prayer_joined_mass"
			else PRAYER_MODE_MASS
		),
		"to_mode": (
			PRAYER_MODE_MASS
			if event_type == "prayer_joined_mass"
			else PRAYER_MODE_PERSONAL
		)
	}
	if not provider_stop_reason.is_empty():
		payload["provider_stop_reason"] = provider_stop_reason
	_log_structured_action_event(npc_id, action, event_type, payload)


func _get_missing_dependency_reason(action_id: String) -> String:
	match action_id:
		CLINIC_PATIENT_ACTION_ID:
			return "诊所没有在岗医生"
		TRAINING_STUDENT_ACTION_ID:
			return "训练场没有在岗教官"
	return "所需服务人员当前不在岗"


func _get_active_blocker_reason(action_id: String) -> String:
	return "当前存在互斥活动"


func _get_dependency_failure_id(action_id: String) -> String:
	match action_id:
		CLINIC_PATIENT_ACTION_ID:
			return "clinic_patient_failed_no_doctor"
		TRAINING_STUDENT_ACTION_ID:
			return "training_student_failed_no_instructor"
	return "%s_failed_dependency_unavailable" % action_id


func _fail_action_before_start(npc_id: String, action: Dictionary, availability: Dictionary) -> void:
	var action_id := str(action.get("id", ""))
	var required_active_action_id := str(action.get("required_active_action_id", availability.get("required_active_action_id", "")))
	var blocked_by_active_action_id := str(action.get("blocked_by_active_action_id", availability.get("blocked_by_active_action_id", "")))
	var reason := str(availability.get("unavailable_reason", "当前不能执行该行动"))
	var failure_id := "%s_failed_building_unavailable" % action_id
	if not bool(availability.get("personal_resources_available", true)):
		failure_id = "drink_wine_failed_no_wine" if action_id == DRINK_WINE_ACTION_ID else "%s_failed_no_personal_resources" % action_id
	elif not required_active_action_id.is_empty() and _find_active_npc_ids_for_action(required_active_action_id).is_empty():
		failure_id = _get_dependency_failure_id(action_id)
	elif not blocked_by_active_action_id.is_empty() and not _find_active_npc_ids_for_action(blocked_by_active_action_id).is_empty():
		failure_id = "%s_failed_conflicting_action" % action_id
	var failure_context := {
		"action_id": action_id,
		"building_id": str(availability.get("building_id", action.get("location_required", ""))),
		"required_active_action_id": required_active_action_id,
		"blocked_by_active_action_id": blocked_by_active_action_id,
		"unavailable_reason": reason
	}
	_update_action_failure(npc_id, failure_id, failure_context)
	_log_action_start_failure(npc_id, action, reason, failure_context)


func _log_action_start_failure(
	npc_id: String,
	action: Dictionary,
	reason: String,
	extra_context: Dictionary = {}
) -> void:
	if action.is_empty():
		return
	var payload := {
		"action_id": str(action.get("id", "")),
		"reason": reason,
		"building_id": str(action.get("location_required", ""))
	}
	for key in ["required_active_action_id", "blocked_by_active_action_id", "provider_npc_id", "provider_stop_reason"]:
		if extra_context.has(key) and not str(extra_context.get(key, "")).is_empty():
			payload[key] = extra_context.get(key)
	var event_type := "prayer_failed" if str(action.get("type", "")) == "pray" else "work_failed"
	_log_structured_action_event(npc_id, action, event_type, payload)


func _find_active_clinic_patient_id() -> String:
	var patient_ids := _find_active_clinic_patient_ids()
	return "" if patient_ids.is_empty() else patient_ids[0]


func _find_active_clinic_patient_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_npc_id in _active_actions.keys():
		var npc_id := str(raw_npc_id)
		var active_action: Dictionary = _active_actions.get(npc_id, {})
		if str(active_action.get("kind", "")) == "clinic_patient":
			result.append(npc_id)
	result.sort()
	return result


func _update_active_clinic_patient_healer(patient_npc_id: String, doctor_npc_id: String, money_spent: int) -> void:
	if not _active_actions.has(patient_npc_id):
		return
	var patient_action: Dictionary = _active_actions[patient_npc_id]
	patient_action["healer_npc_id"] = doctor_npc_id
	var healer_ids: Array = patient_action.get("healer_npc_ids", []) if patient_action.get("healer_npc_ids", []) is Array else []
	if not healer_ids.has(doctor_npc_id):
		healer_ids.append(doctor_npc_id)
	patient_action["healer_npc_ids"] = healer_ids
	var spent_by_doctor: Dictionary = (
		patient_action.get("money_spent_by_doctor", {}).duplicate(true)
		if patient_action.get("money_spent_by_doctor", {}) is Dictionary
		else {}
	)
	spent_by_doctor[doctor_npc_id] = money_spent
	patient_action["money_spent_by_doctor"] = spent_by_doctor
	var total_money_spent := 0
	for raw_amount in spent_by_doctor.values():
		total_money_spent += int(raw_amount)
	patient_action["money_spent"] = total_money_spent
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
	var provider_rate := (
		CLINIC_BASE_HP_PER_HOUR
		+ float(medical_skill) * CLINIC_SKILL_HP_PER_HOUR
		+ maxf(0.0, float(intelligence - 5)) * CLINIC_INTELLIGENCE_HP_PER_HOUR
		+ maxf(0.0, float(building_level - 1)) * CLINIC_LEVEL_HP_PER_HOUR
	)
	return provider_rate * _get_building_activity_efficiency_multiplier(CLINIC_LOCATION_ID, "clinic_recovery")


func get_clinic_team_hp_per_hour() -> float:
	var total := 0.0
	for doctor_npc_id in _find_active_clinic_doctor_ids():
		total += _get_clinic_hp_per_hour(doctor_npc_id)
	return total


func _find_active_clinic_doctor_ids() -> Array[String]:
	return _find_active_npc_ids_for_action(CLINIC_DOCTOR_ACTION_ID)


func _improve_medical_skill(npc_id: String, amount: int, reason: String) -> void:
	_improve_npc_skill_at_location(npc_id, "医术", amount, reason, CLINIC_LOCATION_ID)


func _improve_npc_skill(npc_id: String, skill_name: String, amount: int, reason: String) -> void:
	_improve_npc_skill_at_location(npc_id, skill_name, amount, reason, TRAINING_LOCATION_ID)


func _improve_work_skill(npc_id: String, action: Dictionary) -> void:
	var skill_name := str(action.get("skill", ""))
	if skill_name.is_empty():
		return
	_improve_npc_skill_at_location(npc_id, skill_name, 1, "work_completed", str(action.get("location_required", PLAZA_LOCATION_ID)))


func _improve_npc_skill_at_location(npc_id: String, skill_name: String, amount: int, reason: String, location_id: String) -> Dictionary:
	var npc_system := _get_npc_system()
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("increase_npc_skill"):
		return {}
	var result: Dictionary = npc_system.increase_npc_skill(npc_id, skill_name, amount)
	if result.is_empty():
		return {}
	if memory_system == null or not memory_system.has_method("add_event"):
		return result
	var event_location := location_id if not location_id.is_empty() else PLAZA_LOCATION_ID
	memory_system.add_event({
		"type": "skill_improved",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [event_location, skill_name],
		"location_id": event_location,
		"visibility": "private",
		"importance": 20,
		"payload": {
			"skill_name": skill_name,
			"amount": int(result.get("amount", amount)),
			"before": int(result.get("before", 0)),
			"after": int(result.get("after", 0)),
			"reason": reason,
			"experience_gained": int(result.get("experience_gained", 0)),
			"total_experience": int(result.get("total_experience", 0)),
			"skill_points_gained": int(result.get("skill_points_gained", 0)),
			"unspent_skill_points": int(result.get("unspent_skill_points", 0)),
			"skill_experience": int(result.get("skill_experience", 0)),
			"next_skill_point_xp": int(result.get("next_skill_point_xp", 0))
		}
	})
	return result


func _get_equipped_training_skills(npc: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var equipment: Dictionary = npc.get("equipment", {})
	var main_weapon: Dictionary = equipment.get("main_weapon", {})
	var weapon_skill := str(main_weapon.get("required_skill", ""))
	if not weapon_skill.is_empty() and not result.has(weapon_skill):
		result.append(weapon_skill)
	var mount: Dictionary = equipment.get("mount", {})
	var mount_skill := str(mount.get("required_skill", ""))
	if not mount_skill.is_empty() and not result.has(mount_skill):
		result.append(mount_skill)
	return result


func _find_active_training_instructor_id() -> String:
	var instructor_ids := _find_active_training_instructor_ids()
	return "" if instructor_ids.is_empty() else instructor_ids[0]


func _find_active_training_instructor_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_npc_id in _active_actions.keys():
		var npc_id := str(raw_npc_id)
		if _is_training_instructor_active(npc_id):
			result.append(npc_id)
	result.sort()
	return result


func _is_training_instructor_active(npc_id: String) -> bool:
	return _is_active_provider_for_action(npc_id, TRAINING_INSTRUCTOR_ACTION_ID)


func _find_active_training_students_for_instructor(instructor_npc_id: String) -> Array[String]:
	var result: Array[String] = []
	if not _is_training_instructor_active(instructor_npc_id):
		return result
	for raw_npc_id in _active_actions.keys():
		var npc_id := str(raw_npc_id)
		var active_action: Dictionary = _active_actions.get(npc_id, {})
		if str(active_action.get("kind", "")) == "training_student":
			result.append(npc_id)
	result.sort()
	return result


func _get_training_student_skill_interval_seconds(instructor_id: String, student_id: String, skill_name: String, action: Dictionary) -> float:
	return _get_training_team_skill_interval_seconds([instructor_id], student_id, skill_name, action)


func _get_training_team_skill_interval_seconds(instructor_ids: Array, student_id: String, skill_name: String, action: Dictionary) -> float:
	var npc_system := _get_npc_system()
	if npc_system == null or instructor_ids.is_empty():
		return TRAINING_STUDENT_SKILL_INTERVAL_SECONDS * TRAINING_LOW_TEACHER_INTERVAL_MULTIPLIER
	var student: Dictionary = npc_system.get_npc(student_id)
	var student_skill := _get_action_skill_value(student, skill_name)
	var base_interval := maxf(1.0, float(action.get("student_skill_interval_seconds", TRAINING_STUDENT_SKILL_INTERVAL_SECONDS)))
	var team_speed_multiplier := 0.0
	for raw_instructor_id in instructor_ids:
		var instructor_id := str(raw_instructor_id)
		if not _is_training_instructor_active(instructor_id):
			continue
		var instructor: Dictionary = npc_system.get_npc(instructor_id)
		var instructor_skill := _get_action_skill_value(instructor, skill_name)
		var coaching_value := _get_action_skill_value(instructor, "教练")
		if instructor_skill < student_skill:
			var weak_multiplier := 1.0 + float(coaching_value) / 100.0 * 0.20
			team_speed_multiplier += weak_multiplier / TRAINING_LOW_TEACHER_INTERVAL_MULTIPLIER
		else:
			var skill_gap_bonus := minf(1.0, float(instructor_skill - student_skill) / 100.0) * TRAINING_GAP_SPEED_SCALE
			var coaching_bonus := float(coaching_value) / 100.0 * TRAINING_COACHING_SPEED_SCALE
			team_speed_multiplier += 1.0 + skill_gap_bonus + coaching_bonus

	var building_bonus := maxf(0.0, float(_get_training_ground_level() - 1)) * TRAINING_BUILDING_LEVEL_SPEED_SCALE
	var building_efficiency := _get_building_activity_efficiency_multiplier(TRAINING_LOCATION_ID, "training_gain")
	var speed_multiplier := maxf(0.1, (team_speed_multiplier + building_bonus) * building_efficiency)
	return maxf(TRAINING_MIN_STUDENT_SKILL_INTERVAL_SECONDS, base_interval / speed_multiplier)


func _get_training_ground_level() -> int:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		return 1
	var building: Dictionary = building_system.get_building(TRAINING_LOCATION_ID)
	return maxi(1, int(building.get("level", 1)))


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
	for key in ["leader_npc_id", "provider_npc_id"]:
		if payload.has(key):
			var target_npc_id := str(payload[key])
			if not target_npc_id.is_empty() and not target_ids.has(target_npc_id):
				target_ids.append(target_npc_id)
	for key in ["input_resources", "output_resources", "required_resources"]:
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
		if ["work", "clinic_doctor", "training_instructor"].has(str(action.get("type", ""))):
			return action_id
	return ""


func _make_workstation_failure_context(action: Dictionary, claim_result: Dictionary) -> Dictionary:
	var npc_system := _get_npc_system()
	var blocked_by_npc_ids: Array[String] = []
	var blocked_by_npcs: Array[Dictionary] = []
	for raw_npc_id in claim_result.get("blocked_by_npc_ids", []):
		var blocked_npc_id := str(raw_npc_id)
		if blocked_npc_id.is_empty() or blocked_by_npc_ids.has(blocked_npc_id):
			continue
		blocked_by_npc_ids.append(blocked_npc_id)
		var blocked_npc: Dictionary = npc_system.get_npc(blocked_npc_id) if npc_system != null else {}
		var blocked_state: Dictionary = npc_system.get_npc_state(blocked_npc_id) if npc_system != null else {}
		blocked_by_npcs.append({
			"npc_id": blocked_npc_id,
			"name": str(blocked_npc.get("name", blocked_npc_id)),
			"current_action": str(blocked_state.get("current_action", "")),
			"current_location": str(blocked_state.get("current_location", ""))
		})
	return {
		"action_id": str(action.get("id", "")),
		"reason": str(claim_result.get("reason", "no_free_workstation")),
		"unavailable_reason": str(claim_result.get("unavailable_reason", "")),
		"building_id": str(claim_result.get("building_id", action.get("location_required", ""))),
		"building_condition": str(claim_result.get("building_condition", claim_result.get("condition", ""))),
		"is_enterable": bool(claim_result.get("is_enterable", true)),
		"workstation_type": str(claim_result.get("preferred_type", action.get("workstation_type", ""))),
		"assigned_workstation_id": str(claim_result.get("assigned_workstation_id", "")),
		"blocked_workstations": claim_result.get("blocked_workstations", []),
		"blocked_by_npc_ids": blocked_by_npc_ids,
		"blocked_by_npcs": blocked_by_npcs,
		"reserved_workstations": claim_result.get("reserved_workstations", [])
	}


func _is_valid_dialogue_target(npc_id: String, allow_plan_wait: bool = false) -> bool:
	var npc_system := _get_npc_system()
	if npc_system == null or npc_system.get_npc(npc_id).is_empty() or not npc_system.can_npc_act(npc_id):
		return false
	if npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(npc_id):
		return false
	if npc_system.has_method("get_npc_behavior_mode_snapshot"):
		var mode: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
		if str(mode.get("behavior_mode", "work")) != "work":
			return false
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var plan_request_active := _is_npc_plan_request_active(npc_id, npc_system)
	var current_action := str(state.get("current_action", ""))
	if current_action in ["proactive_talk", NPC_DIALOGUE_ACTION_ID]:
		return false
	if current_action == "planning_day" and not allow_plan_wait:
		return false
	if npc_system.has_method("get_npc_llm_activity"):
		var activity: Dictionary = npc_system.get_npc_llm_activity(npc_id)
		if bool(activity.get("active", false)) and not (allow_plan_wait and plan_request_active):
			return false
	return true


func _is_npc_plan_request_active(npc_id: String, npc_system: Node = null) -> bool:
	var resolved_npc_system := npc_system
	if resolved_npc_system == null:
		resolved_npc_system = _get_npc_system()
	if resolved_npc_system == null or npc_id.is_empty():
		return false
	if resolved_npc_system.has_method("is_npc_plan_llm_active"):
		return bool(resolved_npc_system.is_npc_plan_llm_active(npc_id))
	if not resolved_npc_system.has_method("get_npc_llm_activity"):
		return false
	var activity: Dictionary = resolved_npc_system.get_npc_llm_activity(npc_id)
	return bool(activity.get("active", false)) and str(activity.get("kind", "")) == "plan"


func _is_npc_plan_generation_busy(npc_id: String, npc_system: Node = null) -> bool:
	var resolved_npc_system := npc_system
	if resolved_npc_system == null:
		resolved_npc_system = _get_npc_system()
	if resolved_npc_system == null or npc_id.is_empty():
		return false
	if _is_npc_plan_request_active(npc_id, resolved_npc_system):
		return true
	if not resolved_npc_system.has_method("get_npc_state"):
		return false
	var state: Dictionary = resolved_npc_system.get_npc_state(npc_id)
	return str(state.get("current_action", "")) == "planning_day"


func _is_enterable_location(location_id: String) -> bool:
	if location_id == PLAZA_LOCATION_ID:
		return true
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system != null and memory_system.has_method("is_enterable_location") and not memory_system.is_enterable_location(location_id):
		return false
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		return false
	if building_system.has_method("is_building_enterable"):
		return bool(building_system.is_building_enterable(location_id))
	var building: Dictionary = building_system.get_building(location_id)
	return (
		not building.is_empty()
		and int(building.get("hp", 0)) > 0
		and str(building.get("condition", "")) != "upgrading"
	)


func _is_action_commit_ready(
	npc_id: String,
	location_id: String,
	state_override: Dictionary = {}
) -> bool:
	if _is_gameplay_paused():
		return false
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false
	var state: Dictionary = (
		state_override
		if not state_override.is_empty()
		else npc_system.get_npc_state(npc_id)
	)
	if state.is_empty():
		return false
	if str(state.get("current_action", "")) != "idle":
		return false
	if not str(state.get("movement_target", "")).is_empty():
		return false
	if str(state.get("current_action", "")).begins_with("moving_to_"):
		return false
	return location_id.is_empty() or str(state.get("current_location", "")) == location_id


func _fail_pending_npc_dialogue(
	speaker_npc_id: String,
	failure_id: String,
	failure_context: Dictionary = {}
) -> void:
	var target_npc_id := str(_pending_action_targets.get(speaker_npc_id, ""))
	_pending_actions.erase(speaker_npc_id)
	_pending_action_targets.erase(speaker_npc_id)
	_pending_action_options.erase(speaker_npc_id)
	_release_dialogue_reservations(speaker_npc_id)
	var npc_system := _get_npc_system()
	if npc_system != null and npc_system.has_method("stop_npc_movement_for_system"):
		# Movement cleanup may emit npc_state_changed synchronously. Keep its reason
		# non-failing so DailyPlanSystem only observes the final structured failure
		# written below, with the original plan item and full failure context intact.
		npc_system.stop_npc_movement_for_system(
			speaker_npc_id,
			"pending_dialogue_cancelled",
			false
		)
	var merged_failure_context := {
		"action_id": NPC_DIALOGUE_ACTION_ID,
		"target_npc_id": target_npc_id
	}
	for raw_key in failure_context.keys():
		merged_failure_context[str(raw_key)] = failure_context[raw_key]
	_update_action_failure(speaker_npc_id, failure_id, merged_failure_context)


func _release_dialogue_reservations(speaker_npc_id: String) -> void:
	for raw_npc_id in _dialogue_reservations.keys():
		var npc_id := str(raw_npc_id)
		if str(_dialogue_reservations.get(npc_id, "")) == speaker_npc_id:
			_dialogue_reservations.erase(npc_id)


func _cancel_dialogue_approach_for_participant(npc_id: String, reason: String) -> bool:
	var speaker_npc_id := str(_dialogue_reservations.get(npc_id, ""))
	if speaker_npc_id.is_empty():
		return false
	var target_npc_id := str(_pending_action_targets.get(speaker_npc_id, ""))
	_release_dialogue_reservations(speaker_npc_id)
	_pending_actions.erase(speaker_npc_id)
	_pending_action_targets.erase(speaker_npc_id)
	_pending_action_options.erase(speaker_npc_id)
	if speaker_npc_id != npc_id:
		var npc_system := _get_npc_system()
		if npc_system != null and npc_system.has_method("stop_npc_movement_for_system"):
			npc_system.stop_npc_movement_for_system(speaker_npc_id, reason, false)
		_update_action_failure(speaker_npc_id, "talk_to_npc_failed_target_unavailable", {
			"action_id": NPC_DIALOGUE_ACTION_ID,
			"target_npc_id": target_npc_id,
			"reason": reason
		})
	return true


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
	if bool(state.get("first_sleep_summary_active", false)):
		return false
	if npc_system.has_method("get_npc_behavior_mode_snapshot"):
		var mode: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
		if str(mode.get("behavior_mode", "work")) != "work":
			return false
	return true


func _is_first_sleep_summary_locked(npc_id: String) -> bool:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false
	if npc_system.has_method("is_first_sleep_summary_locked"):
		return bool(npc_system.is_first_sleep_summary_locked(npc_id))
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	return bool(state.get("first_sleep_summary_active", false))


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
