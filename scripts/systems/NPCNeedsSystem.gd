extends Node

const WorldFeedbackPayload = preload("res://scripts/core/WorldFeedbackPayload.gd")
const NEEDS_DEFS_FILE := "activity_needs.json"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const SECONDS_PER_HOUR := 3600.0
const NEED_KEYS: Array[String] = ["satiety", "fatigue"]
const FULL_FATIGUE_EVENT_TYPE := "full_fatigue_triggered"
const FULL_FATIGUE_REEVALUATION_REASON := "high_fatigue"
const ZERO_SATIETY_EVENT_TYPE := "zero_satiety_triggered"
const ZERO_SATIETY_REEVALUATION_REASON := "low_satiety"
const ZERO_SATIETY_HP_REMAINDER_KEY := "zero_satiety_hp_damage"

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


func get_fatigue_work_output_multiplier(npc_id: String) -> float:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return 1.0
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if state.is_empty():
		return 1.0
	var fatigue_bounds := get_need_bounds("fatigue")
	var maximum := int(fatigue_bounds.get("max", 100))
	if int(state.get("fatigue", 0)) < maximum:
		return 1.0
	return clampf(float(_config.get("full_fatigue_work_output_multiplier", 0.5)), 0.01, 1.0)


func get_zero_satiety_hp_cost_per_missing_satiety() -> float:
	return maxf(0.0, float(_config.get("zero_satiety_hp_cost_per_missing_satiety", 2.0)))


func get_zero_satiety_hp_categories() -> Array[String]:
	var result: Array[String] = []
	var raw_categories: Variant = _config.get("zero_satiety_hp_categories", [])
	if not raw_categories is Array:
		return result
	for raw_category in raw_categories:
		var category := str(raw_category).strip_edges()
		if not category.is_empty() and not result.has(category):
			result.append(category)
	return result


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
		),
		"zero_satiety_hp": {
			"hp_cost_per_missing_satiety": get_zero_satiety_hp_cost_per_missing_satiety(),
			"affected_categories": get_zero_satiety_hp_categories(),
			"damage_remainder": float(
				(_remainders_by_npc.get(npc_id, {}) as Dictionary).get(ZERO_SATIETY_HP_REMAINDER_KEY, 0.0)
				if _remainders_by_npc.get(npc_id, {}) is Dictionary
				else 0.0
			)
		}
	}


func create_game_save_snapshot() -> Dictionary:
	return {"remainders_by_npc": _remainders_by_npc.duplicate(true)}


func restore_game_save_snapshot(snapshot: Dictionary) -> Dictionary:
	_remainders_by_npc = snapshot.get("remainders_by_npc", {}).duplicate(true) if snapshot.get("remainders_by_npc", {}) is Dictionary else {}
	_combat_sprint_runtime_by_npc.clear()
	return {"ok": true, "npc_count": _remainders_by_npc.size()}


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
			if before > minimum and after <= minimum:
				_handle_zero_satiety_reached(npc_id, before, minimum, "combat_sprint")
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
		var active_action: Dictionary = action_system.get_action(action_id)
		if str(active_action.get("completion_policy", "")) == "continuous_until_plan_changes":
			return requested_seconds
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
	var satiety_minimum := int(get_need_bounds("satiety").get("min", 0))
	if int(state.get("satiety", satiety_minimum)) > satiety_minimum:
		remainders.erase(ZERO_SATIETY_HP_REMAINDER_KEY)
	var changes := {}
	var applied_deltas := {}
	var reached_full_fatigue := false
	var reached_zero_satiety := false
	var satiety_before_zero := satiety_minimum
	var unpaid_satiety_points := 0.0
	var fatigue_before_full := 0
	var fatigue_maximum := int(get_need_bounds("fatigue").get("max", 100))
	for need_key in NEED_KEYS:
		var rate_key := "%s_per_hour" % need_key
		var accumulated := float(remainders.get(need_key, 0.0))
		var rate_multiplier := _get_need_rate_multiplier(npc_id, state, profile_id, need_key)
		accumulated += (
			float(profile.get(rate_key, 0.0))
			* rate_multiplier
			* game_seconds
			/ SECONDS_PER_HOUR
		)
		var whole_delta := (
			floori(accumulated + 0.000001)
			if accumulated >= 0.0
			else ceili(accumulated - 0.000001)
		)
		if whole_delta == 0:
			var zero_delta_bounds: Dictionary = (
				bounds.get(need_key, {})
				if bounds.get(need_key, {}) is Dictionary
				else {}
			)
			var zero_delta_minimum := int(zero_delta_bounds.get("min", 0))
			if (
				need_key == "satiety"
				and accumulated < 0.0
				and int(state.get(need_key, zero_delta_minimum)) <= zero_delta_minimum
			):
				unpaid_satiety_points += -accumulated
				remainders[need_key] = 0.0
			else:
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
			if need_key == "fatigue" and before < maximum and after >= maximum:
				reached_full_fatigue = true
				fatigue_before_full = before
				fatigue_maximum = maximum
			if need_key == "satiety" and before > minimum and after <= minimum:
				reached_zero_satiety = true
				satiety_before_zero = before
		if need_key == "satiety" and whole_delta < 0 and actual_delta > whole_delta:
			unpaid_satiety_points += float(actual_delta) - accumulated
		if actual_delta == whole_delta:
			remainders[need_key] = accumulated - float(whole_delta)
		else:
			remainders[need_key] = 0.0

	if not changes.is_empty():
		npc_system.update_npc_state(npc_id, changes)
	if reached_zero_satiety:
		_handle_zero_satiety_reached(npc_id, satiety_before_zero, satiety_minimum, profile_id)
	var starvation_damage := _apply_zero_satiety_hp_damage(
		npc_id,
		profile_id,
		profile,
		unpaid_satiety_points,
		remainders
	)
	_remainders_by_npc[npc_id] = remainders
	if reached_full_fatigue:
		_handle_full_fatigue_reached(npc_id, fatigue_before_full, fatigue_maximum)
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
		"unpaid_satiety_points": unpaid_satiety_points,
		"zero_satiety_hp_damage": starvation_damage,
		"remainders": remainders.duplicate(true)
	}


func _get_need_rate_multiplier(
	npc_id: String,
	state: Dictionary,
	profile_id: String,
	need_key: String
) -> float:
	if profile_id != "sleep" or need_key != "fatigue":
		return 1.0
	if str(state.get("current_action", "")) != "sleep_in_dormitory":
		return 1.0
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if action_system == null or building_system == null:
		return 1.0
	var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
	if (
		str(runtime.get("phase", "")) != "active"
		or str(runtime.get("action_id", "")) != "sleep_in_dormitory"
	):
		return 1.0
	var action: Dictionary = action_system.get_action("sleep_in_dormitory")
	var building_id := str(runtime.get("building_id", action.get("location_required", "")))
	var efficiency_key := str(action.get("building_efficiency_key", "sleep_recovery"))
	if building_id.is_empty() or efficiency_key.is_empty():
		return 1.0
	return maxf(
		0.0,
		float(building_system.get_building_activity_efficiency_multiplier(
			building_id,
			efficiency_key
		))
	)


func _apply_zero_satiety_hp_damage(
	npc_id: String,
	profile_id: String,
	profile: Dictionary,
	unpaid_satiety_points: float,
	remainders: Dictionary
) -> int:
	if unpaid_satiety_points <= 0.0:
		return 0
	var category := str(profile.get("category", ""))
	if not category in get_zero_satiety_hp_categories():
		return 0
	var hp_cost := get_zero_satiety_hp_cost_per_missing_satiety()
	if hp_cost <= 0.0:
		return 0
	var accumulated := float(remainders.get(ZERO_SATIETY_HP_REMAINDER_KEY, 0.0))
	accumulated += unpaid_satiety_points * hp_cost
	var whole_damage := floori(accumulated + 0.000001)
	if whole_damage <= 0:
		remainders[ZERO_SATIETY_HP_REMAINDER_KEY] = accumulated
		return 0
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("apply_needs_hp_damage_to_npc"):
		remainders[ZERO_SATIETY_HP_REMAINDER_KEY] = accumulated
		return 0
	var damage_result: Dictionary = npc_system.apply_needs_hp_damage_to_npc(
		npc_id,
		whole_damage,
		{
			"source": "zero_satiety",
			"profile_id": profile_id,
			"profile_category": category,
			"unpaid_satiety_points": unpaid_satiety_points,
			"hp_cost_per_missing_satiety": hp_cost
		}
	)
	if not bool(damage_result.get("ok", false)):
		remainders[ZERO_SATIETY_HP_REMAINDER_KEY] = accumulated
		return 0
	var applied_damage := maxi(0, int(damage_result.get("hp_before", 0)) - int(damage_result.get("hp_after", 0)))
	accumulated -= float(whole_damage)
	if accumulated > 0.000001:
		remainders[ZERO_SATIETY_HP_REMAINDER_KEY] = accumulated
	else:
		remainders.erase(ZERO_SATIETY_HP_REMAINDER_KEY)
	return applied_damage


func _handle_zero_satiety_reached(
	npc_id: String,
	satiety_before: int,
	satiety_minimum: int,
	profile_id: String
) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var location_id := str(state.get("current_location", "plaza"))
	if location_id.is_empty():
		location_id = "plaza"
	var profile := get_profile(profile_id)
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system != null and memory_system.has_method("add_event"):
		memory_system.add_event({
			"type": ZERO_SATIETY_EVENT_TYPE,
			"subject_npc_id": npc_id,
			"actor_ids": [npc_id],
			"target_ids": [npc_id],
			"location_id": location_id,
			"visibility": "private",
			"importance": 75,
			"summary": "你当前非常饥饿，继续工作或战斗会损伤身体。",
			"payload": {
				"satiety_before": satiety_before,
				"satiety_after": satiety_minimum,
				"min_satiety": satiety_minimum,
				"hp_cost_per_missing_satiety": get_zero_satiety_hp_cost_per_missing_satiety(),
				"current_action": str(state.get("current_action", "idle")),
				"profile_id": profile_id,
				"profile_category": str(profile.get("category", ""))
			}
		})
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_plan_reevaluation_requested.emit(
			npc_id,
			ZERO_SATIETY_REEVALUATION_REASON
		)


func _handle_full_fatigue_reached(npc_id: String, fatigue_before: int, fatigue_maximum: int) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var location_id := str(state.get("current_location", "plaza"))
	if location_id.is_empty():
		location_id = "plaza"
	var output_multiplier := get_fatigue_work_output_multiplier(npc_id)
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system != null and memory_system.has_method("add_event"):
		memory_system.add_event({
			"type": FULL_FATIGUE_EVENT_TYPE,
			"subject_npc_id": npc_id,
			"actor_ids": [npc_id],
			"target_ids": [npc_id],
			"location_id": location_id,
			"visibility": "private",
			"importance": 70,
			"summary": "你当前很疲惫，工作效率大幅下降。",
			"payload": {
				"fatigue_before": fatigue_before,
				"fatigue_after": fatigue_maximum,
				"max_fatigue": fatigue_maximum,
				"work_output_multiplier": output_multiplier
			}
		})
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_plan_reevaluation_requested.emit(
			npc_id,
			FULL_FATIGUE_REEVALUATION_REASON
		)


func _validate_profiles() -> void:
	var full_fatigue_multiplier: Variant = _config.get("full_fatigue_work_output_multiplier", null)
	if (
		not full_fatigue_multiplier is float
		and not full_fatigue_multiplier is int
	):
		_add_definition_error("full_fatigue_work_output_multiplier must be numeric.")
	elif float(full_fatigue_multiplier) <= 0.0 or float(full_fatigue_multiplier) >= 1.0:
		_add_definition_error("full_fatigue_work_output_multiplier must be greater than 0 and less than 1.")
	var zero_satiety_hp_cost: Variant = _config.get("zero_satiety_hp_cost_per_missing_satiety", null)
	if not zero_satiety_hp_cost is float and not zero_satiety_hp_cost is int:
		_add_definition_error("zero_satiety_hp_cost_per_missing_satiety must be numeric.")
	elif float(zero_satiety_hp_cost) <= 0.0:
		_add_definition_error("zero_satiety_hp_cost_per_missing_satiety must be greater than 0.")
	var zero_satiety_categories: Variant = _config.get("zero_satiety_hp_categories", null)
	if not zero_satiety_categories is Array or (zero_satiety_categories as Array).is_empty():
		_add_definition_error("zero_satiety_hp_categories must be a non-empty array.")
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
