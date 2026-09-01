extends Node

const WorldFeedbackPayload = preload("res://scripts/core/WorldFeedbackPayload.gd")
const NEEDS_DEFS_FILE := "activity_needs.json"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const SECONDS_PER_HOUR := 3600.0
const NEED_KEYS: Array[String] = ["satiety", "fatigue"]

var _config: Dictionary = {}
var _profiles: Dictionary = {}
var _definition_errors: Array[String] = []
var _remainders_by_npc: Dictionary = {}
var _combat_sprint_runtime_by_npc: Dictionary = {}


func initialize() -> void:
	_config.clear()
	_profiles.clear()
	_definition_errors.clear()
	_remainders_by_npc.clear()
	_combat_sprint_runtime_by_npc.clear()

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		_add_definition_error("NPCNeedsSystem requires ConfigLoader autoload.")
		return

	var loaded: Variant = config_loader.load_data_file(NEEDS_DEFS_FILE, {})
	if not loaded is Dictionary:
		_add_definition_error("Activity needs definitions must be a JSON object: %s" % NEEDS_DEFS_FILE)
		return
	_config = (loaded as Dictionary).duplicate(true)
	var raw_profiles: Variant = _config.get("profiles", {})
	if not raw_profiles is Dictionary or (raw_profiles as Dictionary).is_empty():
		_add_definition_error("Activity needs definitions require a non-empty profiles object.")
		return
	_profiles = (raw_profiles as Dictionary).duplicate(true)
	_validate_profiles()
	_validate_system_mappings()
	_validate_combat_sprint_config()


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
		event_bus.logical_time_tick.connect(_on_logical_time_tick)
	call_deferred("_validate_action_mappings")


func get_definition_errors() -> Array[String]:
	return _definition_errors.duplicate()


func get_profile_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_profile_id in _profiles.keys():
		result.append(str(raw_profile_id))
	result.sort()
	return result


func get_profile(profile_id: String) -> Dictionary:
	if not _profiles.has(profile_id):
		return {}
	return (_profiles[profile_id] as Dictionary).duplicate(true)


func get_behavior_mode_profiles() -> Dictionary:
	var value: Variant = _config.get("behavior_mode_profiles", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func get_need_bounds(need_id: String) -> Dictionary:
	var bounds: Dictionary = _config.get("bounds", {}) if _config.get("bounds", {}) is Dictionary else {}
	var value: Variant = bounds.get(need_id, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {"min": 0, "max": 100}


func get_npc_needs_snapshot(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return {}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if state.is_empty():
		return {}
	var profile_id := _resolve_profile_id(npc_id, state)
	return {
		"npc_id": npc_id,
		"profile_id": profile_id,
		"profile": get_profile(profile_id),
		"remainders": (
			(_remainders_by_npc[npc_id] as Dictionary).duplicate(true)
			if _remainders_by_npc.has(npc_id)
			else {}
		),
		"combat_sprint": (
			(_combat_sprint_runtime_by_npc[npc_id] as Dictionary).duplicate(true)
			if _combat_sprint_runtime_by_npc.has(npc_id)
			else {}
		)
	}


func debug_advance_profile(npc_id: String, profile_id: String, game_seconds: float) -> Dictionary:
	if game_seconds <= 0.0 or not _profiles.has(profile_id):
		return {}
	return _apply_profile(npc_id, profile_id, game_seconds)


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0 or not _definition_errors.is_empty():
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var enemies_present := (
		combat_system != null
		and combat_system.has_method("get_active_enemy_count")
		and int(combat_system.get_active_enemy_count()) > 0
	)
	for npc_id in npc_system.get_npc_ids():
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if state.is_empty():
			continue
		if bool(state.get("escaped", false)):
			_remainders_by_npc.erase(npc_id)
			_combat_sprint_runtime_by_npc.erase(npc_id)
			continue
		_advance_combat_sprint(npc_id, game_delta_seconds, enemies_present)
		_advance_npc(npc_id, state, game_delta_seconds)


func _advance_combat_sprint(npc_id: String, game_delta_seconds: float, enemies_present: bool) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("consume_npc_unmounted_actual_run_seconds"):
		return {}
	var sampled_run_seconds := maxf(
		0.0,
		float(npc_system.consume_npc_unmounted_actual_run_seconds(npc_id))
	)
	var charged_run_seconds := (
		minf(sampled_run_seconds, maxf(0.0, game_delta_seconds))
		if enemies_present
		else 0.0
	)
	var previous_runtime: Dictionary = (
		_combat_sprint_runtime_by_npc.get(npc_id, {})
		if _combat_sprint_runtime_by_npc.get(npc_id, {}) is Dictionary
		else {}
	)
	var runtime := {
		"npc_id": npc_id,
		"enemies_present": enemies_present,
		"sampled_actual_run_seconds": sampled_run_seconds,
		"charged_game_seconds": charged_run_seconds,
		"discarded_sample_seconds": maxf(0.0, sampled_run_seconds - charged_run_seconds),
		"satiety_per_game_second": 0.0,
		"applied_satiety_delta": 0,
		"total_charged_game_seconds": float(previous_runtime.get("total_charged_game_seconds", 0.0)) + charged_run_seconds,
		"total_applied_satiety_delta": int(previous_runtime.get("total_applied_satiety_delta", 0))
	}
	var sprint_config: Dictionary = (
		_config.get("combat_sprint", {})
		if _config.get("combat_sprint", {}) is Dictionary
		else {}
	)
	var satiety_rate := minf(0.0, float(sprint_config.get("satiety_per_game_second", -0.1)))
	runtime["satiety_per_game_second"] = satiety_rate
	if charged_run_seconds <= 0.0 or satiety_rate == 0.0:
		_combat_sprint_runtime_by_npc[npc_id] = runtime
		return runtime.duplicate(true)

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if state.is_empty() or bool(state.get("unconscious", false)):
		_combat_sprint_runtime_by_npc[npc_id] = runtime
		return runtime.duplicate(true)
	var remainders: Dictionary = (
		(_remainders_by_npc[npc_id] as Dictionary).duplicate(true)
		if _remainders_by_npc.has(npc_id)
		else {}
	)
	var remainder_key := "combat_sprint_satiety"
	var accumulated := float(remainders.get(remainder_key, 0.0)) + satiety_rate * charged_run_seconds
	var whole_delta := (
		floori(accumulated + 0.000001)
		if accumulated >= 0.0
		else ceili(accumulated - 0.000001)
	)
	if whole_delta != 0:
		var bounds: Dictionary = _config.get("bounds", {}) if _config.get("bounds", {}) is Dictionary else {}
		var satiety_bounds: Dictionary = bounds.get("satiety", {}) if bounds.get("satiety", {}) is Dictionary else {}
		var minimum := int(satiety_bounds.get("min", 0))
		var maximum := int(satiety_bounds.get("max", 100))
		var before := clampi(int(state.get("satiety", minimum)), minimum, maximum)
		var after := clampi(before + whole_delta, minimum, maximum)
		var actual_delta := after - before
		if actual_delta != 0:
			npc_system.update_npc_state(npc_id, {"satiety": after})
			runtime["applied_satiety_delta"] = actual_delta
			runtime["total_applied_satiety_delta"] = int(runtime.get("total_applied_satiety_delta", 0)) + actual_delta
		if actual_delta == whole_delta:
			accumulated -= float(whole_delta)
		else:
			accumulated = 0.0
	remainders[remainder_key] = accumulated
	_remainders_by_npc[npc_id] = remainders
	runtime["satiety_remainder"] = accumulated
	_combat_sprint_runtime_by_npc[npc_id] = runtime
	return runtime.duplicate(true)


func _advance_npc(npc_id: String, state: Dictionary, game_delta_seconds: float) -> void:
	var profile_id := _resolve_profile_id(npc_id, state)
	if profile_id.is_empty():
		return
	var effective_seconds := _get_effective_activity_seconds(npc_id, state, game_delta_seconds)
	if effective_seconds > 0.0:
		_apply_profile(npc_id, profile_id, effective_seconds)
		_advance_timed_experience(npc_id, state, effective_seconds)
	var remaining_seconds := maxf(0.0, game_delta_seconds - effective_seconds)
	if remaining_seconds > 0.0001:
		_apply_profile(npc_id, str(_config.get("idle_profile", "idle")), remaining_seconds)


func _resolve_profile_id(npc_id: String, state: Dictionary) -> String:
	if bool(state.get("unconscious", false)):
		return str(_config.get("unconscious_profile", "unconscious_rest"))

	var current_action := str(state.get("current_action", "idle"))
	var dialogue_current_actions: Array = (
		_config.get("dialogue_current_actions", [])
		if _config.get("dialogue_current_actions", []) is Array
		else []
	)
	if dialogue_current_actions.has(current_action):
		return "dialogue"

	var behavior_mode := str(state.get("behavior_mode", "work"))
	var behavior_profiles: Dictionary = (
		_config.get("behavior_mode_profiles", {})
		if _config.get("behavior_mode_profiles", {}) is Dictionary
		else {}
	)
	var behavior_profile_id := str(behavior_profiles.get(behavior_mode, ""))
	if not behavior_profile_id.is_empty():
		return behavior_profile_id

	if current_action.begins_with("moving_to_"):
		return str(_config.get("movement_profile", "movement"))

	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system != null:
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) in ["active", "external_active"]:
			var runtime_action_id := str(runtime.get("action_id", ""))
			var runtime_action: Dictionary = action_system.get_action(runtime_action_id)
			var runtime_profile_id := str(runtime_action.get("needs_profile", ""))
			if not runtime_profile_id.is_empty():
				return runtime_profile_id

		if action_system.get_action_ids().has(current_action):
			var direct_action: Dictionary = action_system.get_action(current_action)
			var direct_profile_id := str(direct_action.get("needs_profile", ""))
			if not direct_profile_id.is_empty():
				return direct_profile_id

	return str(_config.get("idle_profile", "idle"))


func _get_effective_activity_seconds(npc_id: String, state: Dictionary, requested_seconds: float) -> float:
	if requested_seconds <= 0.0:
		return 0.0
	if bool(state.get("unconscious", false)):
		return requested_seconds
	var current_action := str(state.get("current_action", "idle"))
	var dialogue_current_actions: Array = (
		_config.get("dialogue_current_actions", [])
		if _config.get("dialogue_current_actions", []) is Array
		else []
	)
	if dialogue_current_actions.has(current_action):
		return requested_seconds
	var behavior_mode := str(state.get("behavior_mode", "work"))
	if behavior_mode != "work":
		return requested_seconds
	if current_action.begins_with("moving_to_"):
		return requested_seconds

	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		return requested_seconds
	var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
	var phase := str(runtime.get("phase", ""))
	if phase == "active":
		var action_id := str(runtime.get("action_id", ""))
		if action_id == "assist_heal":
			var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
			if npc_system != null and npc_system.has_method("get_assisted_recovery_effective_seconds"):
				return npc_system.get_assisted_recovery_effective_seconds(
					str(runtime.get("target_id", "")),
					requested_seconds,
					npc_id,
					int(runtime.get("medical_skill", 0))
				)
		var duration := float(runtime.get("duration_seconds", 0.0))
		if duration > 0.0:
			return minf(
				requested_seconds,
				maxf(0.0, duration - float(runtime.get("elapsed_seconds", 0.0)))
			)
	if phase == "external_active":
		var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
		if building_system == null:
			return 0.0
		var action_id := str(runtime.get("action_id", ""))
		var target_id := str(runtime.get("target_id", ""))
		var status: Dictionary = (
			building_system.get_repair_status(target_id)
			if action_id == "assist_repair"
			else building_system.get_upgrade_status(target_id)
		)
		if status.is_empty():
			return 0.0
		var speed_multiplier := maxf(0.001, float(status.get("speed_multiplier", 1.0)))
		return minf(
			requested_seconds,
			maxf(0.0, float(status.get("remaining_seconds", 0.0))) / speed_multiplier
		)
	return requested_seconds


func _advance_timed_experience(npc_id: String, state: Dictionary, effective_seconds: float) -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("advance_timed_action_experience"):
		return
	var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
	if str(runtime.get("phase", "")) not in ["active", "external_active"]:
		return
	var action_id := str(runtime.get("action_id", ""))
	if action_id.is_empty():
		return
	action_system.advance_timed_action_experience(
		npc_id,
		action_id,
		effective_seconds,
		str(state.get("current_location", "plaza"))
	)


func _apply_profile(npc_id: String, profile_id: String, game_seconds: float) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not _profiles.has(profile_id):
		return {}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if state.is_empty():
		return {}
	var profile: Dictionary = _profiles[profile_id]
	var bounds: Dictionary = _config.get("bounds", {}) if _config.get("bounds", {}) is Dictionary else {}
	var remainders: Dictionary = (
		(_remainders_by_npc[npc_id] as Dictionary).duplicate(true)
		if _remainders_by_npc.has(npc_id)
		else {}
	)
	var changes := {}
	var applied_deltas := {}
	for need_key in NEED_KEYS:
		var rate_key := "%s_per_hour" % need_key
		var accumulated := float(remainders.get(need_key, 0.0))
		accumulated += float(profile.get(rate_key, 0.0)) * game_seconds / SECONDS_PER_HOUR
		var whole_delta := (
			floori(accumulated + 0.000001)
			if accumulated >= 0.0
			else ceili(accumulated - 0.000001)
		)
		if whole_delta == 0:
			remainders[need_key] = accumulated
			continue

		var need_bounds: Dictionary = (
			bounds.get(need_key, {})
			if bounds.get(need_key, {}) is Dictionary
			else {}
		)
		var minimum := int(need_bounds.get("min", 0))
		var maximum := int(need_bounds.get("max", 100))
		var before := clampi(int(state.get(need_key, minimum)), minimum, maximum)
		var after := clampi(before + whole_delta, minimum, maximum)
		var actual_delta := after - before
		if actual_delta != 0:
			changes[need_key] = after
			applied_deltas[need_key] = actual_delta
		if actual_delta == whole_delta:
			remainders[need_key] = accumulated - float(whole_delta)
		else:
			remainders[need_key] = 0.0

	_remainders_by_npc[npc_id] = remainders
	if not changes.is_empty():
		npc_system.update_npc_state(npc_id, changes)
	if profile_id == "sleep":
		var fatigue_delta := int(applied_deltas.get("fatigue", 0))
		if fatigue_delta < 0:
			var fatigue_entry := WorldFeedbackPayload.make_value_entry(
				"疲劳",
				fatigue_delta,
				"neutral"
			)
			if not fatigue_entry.is_empty():
				var fatigue_entries: Array[Dictionary] = [fatigue_entry]
				WorldFeedbackPayload.emit_npc(self, npc_id, "needs", fatigue_entries, true)
	return {
		"npc_id": npc_id,
		"profile_id": profile_id,
		"applied_deltas": applied_deltas,
		"remainders": remainders.duplicate(true)
	}


func _validate_profiles() -> void:
	for raw_profile_id in _profiles.keys():
		var profile_id := str(raw_profile_id)
		var value: Variant = _profiles[raw_profile_id]
		if not value is Dictionary:
			_add_definition_error("Needs profile '%s' must be an object." % profile_id)
			continue
		var profile: Dictionary = value
		for need_key in NEED_KEYS:
			var rate_key := "%s_per_hour" % need_key
			if not profile.has(rate_key):
				_add_definition_error("Needs profile '%s' is missing %s." % [profile_id, rate_key])
			elif not profile[rate_key] is float and not profile[rate_key] is int:
				_add_definition_error("Needs profile '%s' has a non-numeric %s." % [profile_id, rate_key])


func _validate_system_mappings() -> void:
	for config_key in ["idle_profile", "movement_profile", "unconscious_profile"]:
		_validate_profile_reference(str(_config.get(config_key, "")), "config.%s" % config_key)

	var behavior_profiles: Dictionary = (
		_config.get("behavior_mode_profiles", {})
		if _config.get("behavior_mode_profiles", {}) is Dictionary
		else {}
	)
	for required_mode in ["work", "rally", "combat", "avoid_combat", "unconscious", "escaped"]:
		if not behavior_profiles.has(required_mode):
			_add_definition_error("Missing needs mapping for behavior mode '%s'." % required_mode)
			continue
		var profile_id := str(behavior_profiles.get(required_mode, ""))
		if required_mode != "work":
			_validate_profile_reference(profile_id, "behavior mode %s" % required_mode)


func _validate_combat_sprint_config() -> void:
	var value: Variant = _config.get("combat_sprint", {})
	if not value is Dictionary:
		_add_definition_error("Activity needs definitions require combat_sprint object.")
		return
	var sprint_config: Dictionary = value
	var rate: Variant = sprint_config.get("satiety_per_game_second", null)
	if not rate is float and not rate is int:
		_add_definition_error("combat_sprint.satiety_per_game_second must be numeric.")
	elif float(rate) > 0.0:
		_add_definition_error("combat_sprint.satiety_per_game_second must not restore satiety.")

func _validate_action_mappings() -> void:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		_add_definition_error("NPCNeedsSystem requires ActionSystem.")
		return
	for action_id in action_system.get_action_ids():
		var action: Dictionary = action_system.get_action(action_id)
		var profile_id := str(action.get("needs_profile", ""))
		if profile_id.is_empty():
			_add_definition_error("Action '%s' is missing needs_profile." % action_id)
			continue
		_validate_profile_reference(profile_id, "action %s" % action_id)


func _validate_profile_reference(profile_id: String, owner: String) -> void:
	if profile_id.is_empty() or not _profiles.has(profile_id):
		_add_definition_error("%s references unknown needs profile '%s'." % [owner, profile_id])


func _add_definition_error(message: String) -> void:
	_definition_errors.append(message)
	push_error(message)
