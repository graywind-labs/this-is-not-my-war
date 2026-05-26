extends Node

const ACTION_DEFS_FILE := "action_defs.json"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const PLAZA_LOCATION_ID := "plaza"
const DEFAULT_WORK_DURATION_HOURS := 1
const DEFAULT_WORK_DURATION_SECONDS := 3600.0

var _actions: Dictionary = {}
var _actions_by_location: Dictionary = {}
var _pending_actions: Dictionary = {}
var _pending_action_targets: Dictionary = {}
var _active_actions: Dictionary = {}


func initialize() -> void:
	_actions.clear()
	_actions_by_location.clear()
	_pending_actions.clear()
	_pending_action_targets.clear()
	_active_actions.clear()

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


func has_pending_action(npc_id: String) -> bool:
	return _pending_actions.has(npc_id)


func has_active_action(npc_id: String) -> bool:
	return _active_actions.has(npc_id)


func _on_npc_state_changed(npc_id: String) -> void:
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

	var action_id := str(_pending_actions[npc_id])
	if action_id == "assist_repair":
		_try_execute_pending_repair_assist(npc_id)
		return
	if action_id == "assist_upgrade":
		_try_execute_pending_upgrade_assist(npc_id)
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


func _start_work(npc_id: String, action: Dictionary) -> bool:
	var resource_system := _get_resource_system()
	var npc_system := _get_npc_system()
	if resource_system == null or npc_system == null:
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

	_log_structured_action_event(npc_id, action, "work_started", {
		"action_id": str(action.get("id", "")),
		"workstation_id": str(action.get("location_required", "")),
		"duration_seconds": _get_action_duration_seconds(action)
	})

	npc_system.update_npc_state(npc_id, {
		"current_action": str(action.get("id", "work")),
		"last_action_result": "started_%s" % str(action.get("id", "work"))
	})
	_active_actions[npc_id] = _create_active_action(action)
	return true


func _complete_work(npc_id: String, active_action: Dictionary) -> void:
	var action: Dictionary = active_action.get("action", {})
	var resource_system := _get_resource_system()
	if resource_system == null:
		_update_action_failure(npc_id, "work_failed_no_resource_system")
		return

	var input_resources: Dictionary = action.get("input_resources", {})
	if not resource_system.spend_resources(input_resources):
		_update_action_failure(npc_id, "work_failed_no_resources")
		_log_structured_action_event(npc_id, action, "work_failed", {
			"action_id": str(action.get("id", "")),
			"reason": "资源不足",
			"input_resources": input_resources,
			"duration_seconds": _get_action_duration_seconds(action)
		})
		return

	var output_resources: Dictionary = action.get("output_resources", {})
	for resource_id in output_resources.keys():
		resource_system.add_resource(str(resource_id), int(output_resources[resource_id]))

	_apply_building_effects(action)
	_apply_final_state_deltas(npc_id, active_action)
	_set_action_idle(npc_id, "completed_%s" % str(action.get("id", "work")))
	_log_structured_action_event(npc_id, action, "work_completed", {
		"action_id": str(action.get("id", "")),
		"input_resources": input_resources,
		"output_resources": output_resources,
		"building_hp_restore": int(action.get("building_hp_restore", 0)),
		"satiety_delta": int(action.get("satiety_delta", 0)),
		"fatigue_delta": int(action.get("fatigue_delta", 0)),
		"duration_seconds": _get_action_duration_seconds(action)
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
			var active_action := _create_active_action(action)
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
	_active_actions[npc_id] = _create_active_action(action)
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


func _create_active_action(action: Dictionary) -> Dictionary:
	return {
		"action": action.duplicate(true),
		"elapsed_seconds": 0.0,
		"duration_seconds": _get_action_duration_seconds(action),
		"state_deltas": _get_action_state_deltas(action),
		"applied_state_deltas": {}
	}


func _advance_active_action(npc_id: String, game_delta_seconds: float) -> void:
	var active_action: Dictionary = _active_actions[npc_id]
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


func _get_engineering_skill(npc: Dictionary) -> int:
	var skills: Dictionary = npc.get("skills", {})
	for skill_key in ["工程", "宸ョ▼"]:
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


func _find_work_action_for_building(building_id: String) -> String:
	var action_ids: Array = _actions_by_location.get(building_id, [])
	for raw_action_id in action_ids:
		var action_id := str(raw_action_id)
		var action: Dictionary = _actions.get(action_id, {})
		if str(action.get("type", "")) == "work":
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
