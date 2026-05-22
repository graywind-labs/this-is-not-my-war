extends Node

const ACTION_DEFS_FILE := "action_defs.json"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DEFAULT_WORK_DURATION_HOURS := 1

var _actions: Dictionary = {}
var _actions_by_location: Dictionary = {}
var _pending_actions: Dictionary = {}


func initialize() -> void:
	_actions.clear()
	_actions_by_location.clear()
	_pending_actions.clear()

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

	var action: Dictionary = _actions[action_id]
	var location_id := str(action.get("location_required", ""))
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false

	if not location_id.is_empty():
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("current_location", "")) != location_id:
			_pending_actions[npc_id] = action_id
			return npc_system.move_npc_to_building(npc_id, location_id)

	if _is_gameplay_paused():
		_pending_actions[npc_id] = action_id
		return true

	return _execute_action(npc_id, action_id)


func has_pending_action(npc_id: String) -> bool:
	return _pending_actions.has(npc_id)


func _on_npc_state_changed(npc_id: String) -> void:
	if _is_gameplay_paused():
		return
	_try_execute_pending_action(npc_id)


func _on_gameplay_pause_changed(paused: bool) -> void:
	if paused:
		return

	for npc_id in _pending_actions.keys():
		_try_execute_pending_action(str(npc_id))


func _try_execute_pending_action(npc_id: String) -> void:
	if not _pending_actions.has(npc_id):
		return

	var action_id := str(_pending_actions[npc_id])
	if not _actions.has(action_id):
		_pending_actions.erase(npc_id)
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
	):
		_pending_actions.erase(npc_id)
		_execute_action(npc_id, action_id)


func _execute_action(npc_id: String, action_id: String) -> bool:
	var action: Dictionary = _actions[action_id]
	var action_type := str(action.get("type", ""))
	match action_type:
		"work":
			return _execute_work(npc_id, action)
		"eat":
			return _execute_eat(npc_id, action)
		"sleep":
			return _execute_sleep(npc_id, action)
		_:
			push_warning("Unsupported action type: %s" % action_type)
			return false


func _execute_work(npc_id: String, action: Dictionary) -> bool:
	var resource_system := _get_resource_system()
	var npc_system := _get_npc_system()
	if resource_system == null or npc_system == null:
		return false

	var input_resources: Dictionary = action.get("input_resources", {})
	if not resource_system.spend_resources(input_resources):
		_update_action_failure(npc_id, "work_failed_no_resources")
		_log_action_event(npc_id, action, false, "资源不足，工作未能完成。")
		return false

	var output_resources: Dictionary = action.get("output_resources", {})
	for resource_id in output_resources.keys():
		resource_system.add_resource(str(resource_id), int(output_resources[resource_id]))

	_apply_building_effects(action)
	_apply_state_deltas(npc_id, action)
	_set_action_idle(npc_id, "completed_%s" % str(action.get("id", "work")))
	_log_action_event(npc_id, action, true, "完成工作：%s。" % str(action.get("name", "工作")))
	return true


func _execute_eat(npc_id: String, action: Dictionary) -> bool:
	var resource_system := _get_resource_system()
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
			_apply_single_state_delta(npc_id, "satiety", int(option.get("satiety_restore", 0)))
			_set_action_idle(npc_id, "completed_eat")
			_log_action_event(npc_id, action, true, "吃饭恢复了饱食度，消耗了%s。" % resource_system.get_resource_name(resource_id))
			return true

	_update_action_failure(npc_id, "eat_failed_no_food")
	_log_action_event(npc_id, action, false, "没有可用食物，吃饭失败。")
	return false


func _execute_sleep(npc_id: String, action: Dictionary) -> bool:
	_apply_state_deltas(npc_id, action)
	_set_action_idle(npc_id, "completed_sleep")
	_log_action_event(npc_id, action, true, "睡觉降低了疲劳。")
	return true


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


func _log_action_event(npc_id: String, action: Dictionary, succeeded: bool, content: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return

	var building_name := _get_location_name(str(action.get("location_required", "")))
	memory_system.add_event({
		"type": "npc_action",
		"location": building_name,
		"actors": [npc_id],
		"content": content,
		"action_id": str(action.get("id", "")),
		"succeeded": succeeded,
		"duration_hours": int(action.get("base_duration_hours", DEFAULT_WORK_DURATION_HOURS)),
		"importance": 25,
		"visible_to_public_square": false
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
