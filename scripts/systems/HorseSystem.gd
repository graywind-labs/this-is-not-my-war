extends Node

const HORSE_DEFS_FILE := "horse_defs.json"
const STABLE_BUILDING_ID := "stable"
const STABLE_ACTION_ID := "work_stable"
const HORSE_CARE_SKILL := "养马"
const GRAIN_RESOURCE_ID := "grain"
const LOCATION_STABLE := "stable"
const LOCATION_RIDDEN := "ridden"
const BEHAVIOR_MODE_RALLY := "rally"
const BEHAVIOR_MODE_COMBAT := "combat"
const BEHAVIOR_MODE_UNCONSCIOUS := "unconscious"
const BEHAVIOR_MODE_ESCAPED := "escaped"
const FIXED_SIMULATION_STEP_SECONDS := 60.0

const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"

const DEFAULT_BALANCE := {
	"stable_satiety_loss_per_hour": 0.5,
	"outside_satiety_loss_per_hour": 2.0,
	"feeding_missing_ratio": 0.2,
	"feeding_duration_seconds": 1200.0,
	"feeding_grain_cost": 1,
	"feeding_satiety_restore": 35.0,
	"natural_hp_restore_per_hour": 0.2,
	"satiety_cost_per_hp": 0.5,
	"foal_natural_max_hp": 40.0,
	"foal_max_satiety": 50.0,
	"adult_natural_max_hp": 100.0,
	"adult_max_satiety": 100.0,
	"adult_growth_threshold": 0.6,
	"base_full_growth_care_minutes": 10080.0,
	"birth_probability_gain_per_care_minute": 0.00005,
	"birth_probability_cap": 1.0,
	"birth_cooldown_minutes": 1440.0,
	"stable_level_birth_bonus_per_level": 0.1,
	"care_skill_100_bonus_hp_cap": 20.0,
}

var _horses: Dictionary = {}
var _horse_order: Array[String] = []
var _balance: Dictionary = DEFAULT_BALANCE.duplicate(true)
var _simulation_accumulator_seconds: float = 0.0
var _next_foal_serial: int = 1
var _last_stable_summary: Dictionary = {}
var _building_summary_published: bool = false
var _assignment_mutation_depth: int = 0
var _rng := RandomNumberGenerator.new()
var _event_bus: Node = null


func _ready() -> void:
	initialize()
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus == null:
		return
	if _event_bus.has_signal("logical_time_tick") and not _event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
		_event_bus.logical_time_tick.connect(_on_logical_time_tick)
	if _event_bus.has_signal("npc_state_changed") and not _event_bus.npc_state_changed.is_connected(_on_npc_state_changed):
		_event_bus.npc_state_changed.connect(_on_npc_state_changed)
	if _event_bus.has_signal("recruitment_changed") and not _event_bus.recruitment_changed.is_connected(_on_recruitment_changed):
		_event_bus.recruitment_changed.connect(_on_recruitment_changed)


func initialize() -> void:
	_horses.clear()
	_horse_order.clear()
	_balance = DEFAULT_BALANCE.duplicate(true)
	_simulation_accumulator_seconds = 0.0
	_next_foal_serial = 1
	_last_stable_summary.clear()
	_building_summary_published = false
	_assignment_mutation_depth = 0
	_rng.randomize()

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("HorseSystem requires ConfigLoader autoload.")
		return

	var loaded_defs: Variant = config_loader.load_data_file(HORSE_DEFS_FILE, {})
	if not loaded_defs is Dictionary:
		push_error("Horse definitions must be a JSON object: %s" % HORSE_DEFS_FILE)
		return

	var loaded_balance: Variant = loaded_defs.get("balance", {})
	if loaded_balance is Dictionary:
		_apply_loaded_balance(loaded_balance)
	else:
		push_error("Horse balance must be a JSON object: %s" % HORSE_DEFS_FILE)

	var initial_horses: Variant = loaded_defs.get("initial_horses", [])
	if not initial_horses is Array:
		push_error("Horse initial_horses must be a JSON array: %s" % HORSE_DEFS_FILE)
		_publish_stable_summary(true)
		return

	for raw_definition in initial_horses:
		if not raw_definition is Dictionary:
			push_error("Skipped invalid initial horse because it is not a dictionary.")
			continue
		var horse := _make_horse_from_definition(raw_definition)
		var horse_id := str(horse.get("horse_id", ""))
		if horse_id.is_empty():
			continue
		if _horses.has(horse_id):
			push_error("Skipped duplicate initial horse id: %s" % horse_id)
			continue
		_horses[horse_id] = horse
		_horse_order.append(horse_id)

	_publish_stable_summary(true)


func get_horse_ids() -> Array[String]:
	return _horse_order.duplicate()


func get_horse_count() -> int:
	return _horse_order.size()


func has_horse(horse_id: String) -> bool:
	return _horses.has(horse_id)


func get_horse_snapshot(horse_id: String) -> Dictionary:
	if not _horses.has(horse_id):
		return {}
	return _make_public_horse_snapshot(_horses[horse_id])


func get_horse(horse_id: String) -> Dictionary:
	return get_horse_snapshot(horse_id)


func get_horses_snapshot() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for horse_id in _horse_order:
		if _horses.has(horse_id):
			snapshots.append(_make_public_horse_snapshot(_horses[horse_id]))
	return snapshots


func get_horse_state_snapshot() -> Dictionary:
	var snapshot := {}
	for horse_id in _horse_order:
		if _horses.has(horse_id):
			snapshot[horse_id] = _make_public_horse_snapshot(_horses[horse_id])
	return snapshot


func get_balance_snapshot() -> Dictionary:
	return _balance.duplicate(true)


func get_stable_horse_summary() -> Dictionary:
	var total := 0
	var adult := 0
	for horse_id in _horse_order:
		var horse: Dictionary = _horses.get(horse_id, {})
		if str(horse.get("location", LOCATION_STABLE)) != LOCATION_STABLE:
			continue
		total += 1
		if _is_horse_adult(horse):
			adult += 1
	return {
		"total": total,
		"adult": adult,
		"foal": total - adult,
	}


func get_stable_summary() -> Dictionary:
	var summary := get_stable_horse_summary()
	var ridden := 0
	for horse_id in _horse_order:
		var horse: Dictionary = _horses.get(horse_id, {})
		if str(horse.get("location", LOCATION_STABLE)) == LOCATION_RIDDEN:
			ridden += 1
	summary["outside"] = ridden
	summary["ridden"] = ridden
	summary["total_count"] = int(summary.get("total", 0))
	summary["adult_count"] = int(summary.get("adult", 0))
	summary["foal_count"] = int(summary.get("foal", 0))
	return summary


func get_horse_counts_snapshot() -> Dictionary:
	var stable_summary := get_stable_horse_summary()
	var ridden := 0
	var assigned := 0
	for horse_id in _horse_order:
		var horse: Dictionary = _horses.get(horse_id, {})
		if str(horse.get("location", LOCATION_STABLE)) == LOCATION_RIDDEN:
			ridden += 1
		if not str(horse.get("assigned_npc_id", "")).is_empty():
			assigned += 1
	return {
		"total": _horse_order.size(),
		"stable": stable_summary,
		"ridden": ridden,
		"assigned": assigned,
	}


func get_assigned_horse_for_npc(npc_id: String) -> Dictionary:
	var horse_id := _find_assigned_horse_id(npc_id)
	return get_horse_snapshot(horse_id) if not horse_id.is_empty() else {}


func get_available_horses_for_npc(npc_id: String) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if not _get_npc_assignment_ineligibility_reason(npc_id).is_empty():
		return available
	if not _find_assigned_horse_id(npc_id).is_empty():
		return available
	for horse_id in _horse_order:
		var horse: Dictionary = _horses.get(horse_id, {})
		var assigned_npc_id := str(horse.get("assigned_npc_id", ""))
		if not _is_horse_adult(horse):
			continue
		if not assigned_npc_id.is_empty():
			continue
		if str(horse.get("location", LOCATION_STABLE)) != LOCATION_STABLE:
			continue
		available.append(_make_public_horse_snapshot(horse))
	return available


func assign_horse_to_npc(
	npc_id: String,
	horse_id: String = "",
	visibility: String = "local_public"
) -> Dictionary:
	var npc_reason := _get_npc_assignment_ineligibility_reason(npc_id)
	if not npc_reason.is_empty():
		return _assignment_failure(npc_reason, npc_id, horse_id)

	var resolved_horse_id := horse_id.strip_edges()
	if resolved_horse_id.is_empty():
		var available := get_available_horses_for_npc(npc_id)
		if available.is_empty():
			return _assignment_failure("no_available_horse", npc_id, "")
		resolved_horse_id = str(available[0].get("horse_id", ""))
	if not _horses.has(resolved_horse_id):
		return _assignment_failure("unknown_horse", npc_id, resolved_horse_id)

	var current_horse_id := _find_assigned_horse_id(npc_id)
	if current_horse_id == resolved_horse_id:
		_reconcile_npc_riding_state(npc_id)
		var current_horse := get_horse_snapshot(resolved_horse_id)
		return {
			"ok": true,
			"changed": false,
			"already_assigned": true,
			"npc_id": npc_id,
			"horse_id": resolved_horse_id,
			"horse_name": str(current_horse.get("name", resolved_horse_id)),
			"horse": current_horse,
		}
	if not current_horse_id.is_empty():
		return _assignment_failure("npc_already_has_horse", npc_id, resolved_horse_id)

	var horse: Dictionary = _horses[resolved_horse_id]
	if not _is_horse_adult(horse):
		return _assignment_failure("horse_not_adult", npc_id, resolved_horse_id)
	if not str(horse.get("assigned_npc_id", "")).is_empty():
		return _assignment_failure("horse_already_assigned", npc_id, resolved_horse_id)
	if str(horse.get("location", LOCATION_STABLE)) != LOCATION_STABLE:
		return _assignment_failure("horse_not_in_stable", npc_id, resolved_horse_id)

	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("set_npc_horse_mount"):
		return _assignment_failure("equipment_system_unavailable", npc_id, resolved_horse_id)

	var old_horse := horse.duplicate(true)
	horse["assigned_npc_id"] = npc_id
	horse["ridden_by_npc_id"] = ""
	horse["location"] = LOCATION_STABLE
	_horses[resolved_horse_id] = horse

	_assignment_mutation_depth += 1
	var equipment_result: Variant = equipment_system.call(
		"set_npc_horse_mount",
		npc_id,
		_make_public_horse_snapshot(horse),
		visibility,
		true
	)
	_assignment_mutation_depth -= 1
	if not _is_successful_interface_result(equipment_result):
		_horses[resolved_horse_id] = old_horse
		return _assignment_failure("equipment_sync_failed", npc_id, resolved_horse_id)

	_reconcile_npc_riding_state(npc_id)
	_emit_horse_assignment_changed(resolved_horse_id, npc_id)
	_emit_horse_state_changed(resolved_horse_id)
	_publish_stable_summary()
	var assigned_horse := get_horse_snapshot(resolved_horse_id)
	return {
		"ok": true,
		"changed": true,
		"npc_id": npc_id,
		"horse_id": resolved_horse_id,
		"horse_name": str(assigned_horse.get("name", resolved_horse_id)),
		"horse": assigned_horse,
	}


func unassign_horse_from_npc(
	npc_id: String,
	reason: String = "manual",
	visibility: String = "local_public"
) -> Dictionary:
	var horse_id := _find_assigned_horse_id(npc_id)
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	var equipment_synced := false
	if equipment_system != null and equipment_system.has_method("clear_npc_horse_mount"):
		_assignment_mutation_depth += 1
		var equipment_result: Variant = equipment_system.call(
			"clear_npc_horse_mount",
			npc_id,
			visibility,
			reason,
			true
		)
		_assignment_mutation_depth -= 1
		equipment_synced = _is_successful_interface_result(equipment_result)

	if horse_id.is_empty():
		return {
			"ok": true,
			"changed": false,
			"already_unassigned": true,
			"npc_id": npc_id,
			"horse_id": "",
			"reason": reason,
			"equipment_synced": equipment_synced,
		}

	var horse: Dictionary = _horses[horse_id]
	horse["assigned_npc_id"] = ""
	horse["ridden_by_npc_id"] = ""
	horse["location"] = LOCATION_STABLE
	horse["feeding"] = _make_idle_feeding_state()
	_horses[horse_id] = horse
	_emit_horse_assignment_changed(horse_id, "")
	_emit_horse_state_changed(horse_id)
	_publish_stable_summary()
	if not equipment_synced:
		push_warning("Horse assignment cleared but equipment projection could not be synchronized for NPC: %s" % npc_id)
	return {
		"ok": true,
		"changed": true,
		"npc_id": npc_id,
		"horse_id": horse_id,
		"reason": reason,
		"equipment_synced": equipment_synced,
		"horse": get_horse_snapshot(horse_id),
	}


func reconcile_npc_riding_state(npc_id: String) -> Dictionary:
	_reconcile_npc_riding_state(npc_id)
	var horse := get_assigned_horse_for_npc(npc_id)
	return {
		"ok": not horse.is_empty(),
		"npc_id": npc_id,
		"horse": horse,
	}


func apply_damage_to_horse(horse_id: String, damage: float) -> Dictionary:
	if not _horses.has(horse_id):
		return {"ok": false, "reason": "unknown_horse", "horse_id": horse_id}
	if damage <= 0.0:
		return {"ok": false, "reason": "invalid_damage", "horse_id": horse_id}

	var horse: Dictionary = _horses[horse_id]
	var hp_before := float(horse.get("hp", 0.0))
	var applied_damage := minf(damage, hp_before)
	var bonus_before := float(horse.get("care_bonus_hp", 0.0))
	var bonus_damage := minf(applied_damage, bonus_before)
	horse["care_bonus_hp"] = maxf(0.0, bonus_before - bonus_damage)
	horse["hp"] = maxf(0.0, hp_before - applied_damage)
	_horses[horse_id] = horse
	_emit_horse_state_changed(horse_id)
	return {
		"ok": true,
		"horse_id": horse_id,
		"damage": applied_damage,
		"hp_before": hp_before,
		"hp_after": float(horse.get("hp", 0.0)),
		"horse": get_horse_snapshot(horse_id),
	}


func debug_advance(game_seconds: float) -> Dictionary:
	if game_seconds <= 0.0:
		return {"ok": false, "reason": "invalid_duration", "game_seconds": game_seconds}
	_advance_simulation(game_seconds)
	return {
		"ok": true,
		"advanced_game_seconds": game_seconds,
		"pending_partial_minute_seconds": _simulation_accumulator_seconds,
		"stable": get_stable_horse_summary(),
		"horses": get_horses_snapshot(),
	}


func debug_damage(horse_id: String, damage: float) -> Dictionary:
	return apply_damage_to_horse(horse_id, damage)


func debug_force_birth() -> Dictionary:
	var parent_ids := _get_stable_breeding_candidate_ids()
	var horse_id := _spawn_foal()
	if horse_id.is_empty():
		return {"ok": false, "reason": "birth_failed"}
	var changed_horse_ids := {}
	changed_horse_ids[horse_id] = true
	_start_birth_cooldown(parent_ids, changed_horse_ids)
	for changed_horse_id in changed_horse_ids.keys():
		_emit_horse_state_changed(str(changed_horse_id))
	_publish_stable_summary()
	return {
		"ok": true,
		"forced": true,
		"horse_id": horse_id,
		"horse": get_horse_snapshot(horse_id),
		"parent_horse_ids": parent_ids,
	}


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0:
		return
	_advance_simulation(game_delta_seconds)
	if not _building_summary_published:
		_publish_stable_summary(true)


func _on_npc_state_changed(npc_id: String) -> void:
	if _assignment_mutation_depth > 0:
		return
	var horse_id := _find_assigned_horse_id(npc_id)
	if horse_id.is_empty():
		return
	var invalid_reason := _get_npc_assignment_ineligibility_reason(npc_id)
	if not invalid_reason.is_empty():
		unassign_horse_from_npc(npc_id, invalid_reason, "local_public")
		return
	_reconcile_npc_riding_state(npc_id)


func _on_recruitment_changed(npc_id: String, _recruited: bool) -> void:
	_on_npc_state_changed(npc_id)


func _advance_simulation(game_seconds: float) -> void:
	_simulation_accumulator_seconds += maxf(game_seconds, 0.0)
	var changed_horse_ids := {}
	while _simulation_accumulator_seconds + 0.0001 >= FIXED_SIMULATION_STEP_SECONDS:
		_simulation_accumulator_seconds -= FIXED_SIMULATION_STEP_SECONDS
		var caretaker := _get_effective_caretaker_snapshot()
		_advance_horse_ecology(FIXED_SIMULATION_STEP_SECONDS, changed_horse_ids)
		if bool(caretaker.get("active", false)):
			_advance_care(FIXED_SIMULATION_STEP_SECONDS, caretaker, changed_horse_ids)
			_roll_births_for_minute(caretaker, changed_horse_ids)
	for horse_id in changed_horse_ids.keys():
		_emit_horse_state_changed(str(horse_id))
	_publish_stable_summary()


func _advance_horse_ecology(game_seconds: float, changed_horse_ids: Dictionary) -> void:
	for horse_id in _horse_order:
		if not _horses.has(horse_id):
			continue
		var horse: Dictionary = _horses[horse_id]
		var before := horse.duplicate(true)
		var location := str(horse.get("location", LOCATION_STABLE))
		var breeding_cooldown := maxf(
			0.0,
			float(horse.get("breeding_cooldown_remaining_seconds", 0.0)) - game_seconds
		)
		horse["breeding_cooldown_remaining_seconds"] = breeding_cooldown
		if breeding_cooldown > 0.0:
			horse["breeding_probability"] = 0.0
		var satiety_loss_rate := _balance_float("stable_satiety_loss_per_hour")
		if location != LOCATION_STABLE:
			satiety_loss_rate = _balance_float("outside_satiety_loss_per_hour")
		var satiety := float(horse.get("satiety", 0.0))
		satiety = maxf(0.0, satiety - satiety_loss_rate * game_seconds / 3600.0)
		horse["satiety"] = satiety
		_apply_natural_healing(horse, game_seconds)

		if location == LOCATION_STABLE:
			_advance_feeding(horse, game_seconds)
		else:
			horse["feeding"] = _make_idle_feeding_state()

		_normalize_horse_runtime(horse)
		_horses[horse_id] = horse
		if before != horse:
			changed_horse_ids[horse_id] = true


func _apply_natural_healing(horse: Dictionary, game_seconds: float) -> void:
	var hp := float(horse.get("hp", 0.0))
	var natural_max_hp := _calculate_natural_max_hp(float(horse.get("growth", 0.0)))
	var care_bonus_hp := float(horse.get("care_bonus_hp", 0.0))
	var natural_hp := maxf(0.0, hp - care_bonus_hp)
	var missing_natural_hp := maxf(0.0, natural_max_hp - natural_hp)
	if missing_natural_hp <= 0.0:
		return

	var heal_amount := minf(
		missing_natural_hp,
		_balance_float("natural_hp_restore_per_hour") * game_seconds / 3600.0
	)
	var satiety_cost_per_hp := maxf(0.0, _balance_float("satiety_cost_per_hp"))
	if satiety_cost_per_hp > 0.0:
		heal_amount = minf(heal_amount, float(horse.get("satiety", 0.0)) / satiety_cost_per_hp)
	if heal_amount <= 0.0:
		return

	horse["hp"] = hp + heal_amount
	if satiety_cost_per_hp > 0.0:
		horse["satiety"] = maxf(
			0.0,
			float(horse.get("satiety", 0.0)) - heal_amount * satiety_cost_per_hp
		)


func _advance_feeding(horse: Dictionary, game_seconds: float) -> void:
	var feeding: Dictionary = (
		(horse.get("feeding", {}) as Dictionary).duplicate(true)
		if horse.get("feeding", {}) is Dictionary
		else {}
	)
	if bool(feeding.get("waiting_for_grain", false)):
		if _try_spend_horse_feed():
			horse["satiety"] = minf(
				_calculate_max_satiety(float(horse.get("growth", 0.0))),
				float(horse.get("satiety", 0.0)) + _balance_float("feeding_satiety_restore")
			)
			horse["feeding"] = _make_idle_feeding_state()
		else:
			feeding["active"] = false
			feeding["elapsed_seconds"] = maxf(1.0, _balance_float("feeding_duration_seconds"))
			horse["feeding"] = feeding
		return
	var active := bool(feeding.get("active", false))
	if active:
		var duration := maxf(1.0, _balance_float("feeding_duration_seconds"))
		var elapsed := minf(duration, float(feeding.get("elapsed_seconds", 0.0)) + game_seconds)
		feeding["elapsed_seconds"] = elapsed
		feeding["waiting_for_grain"] = false
		if elapsed + 0.0001 >= duration:
			var spent_grain := _try_spend_horse_feed()
			if spent_grain:
				horse["satiety"] = minf(
					_calculate_max_satiety(float(horse.get("growth", 0.0))),
					float(horse.get("satiety", 0.0)) + _balance_float("feeding_satiety_restore")
				)
				feeding = _make_idle_feeding_state()
			else:
				feeding["active"] = false
				feeding["elapsed_seconds"] = duration
				feeding["waiting_for_grain"] = true
		horse["feeding"] = feeding
		return

	var max_satiety := _calculate_max_satiety(float(horse.get("growth", 0.0)))
	var missing_satiety := maxf(0.0, max_satiety - float(horse.get("satiety", 0.0)))
	if missing_satiety + 0.0001 < max_satiety * _balance_float("feeding_missing_ratio"):
		horse["feeding"] = _make_idle_feeding_state()
		return
	horse["feeding"] = {
		"active": true,
		"elapsed_seconds": 0.0,
		"waiting_for_grain": false,
	}


func _try_spend_horse_feed() -> bool:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.has_method("spend_resources"):
		return false
	return bool(resource_system.call(
		"spend_resources",
		{GRAIN_RESOURCE_ID: _balance_int("feeding_grain_cost")}
	))


func _advance_care(
	game_seconds: float,
	caretaker: Dictionary,
	changed_horse_ids: Dictionary
) -> void:
	var skill_factor := clampf(float(caretaker.get("skill", 0.0)) / 100.0, 0.0, 1.0)
	if skill_factor <= 0.0:
		return
	var effective_care_minutes := game_seconds / 60.0 * skill_factor
	var full_growth_minutes := maxf(1.0, _balance_float("base_full_growth_care_minutes"))
	var growth_delta := effective_care_minutes / full_growth_minutes
	var skill_bonus_cap := _balance_float("care_skill_100_bonus_hp_cap") * skill_factor
	var bonus_hp_delta := _balance_float("care_skill_100_bonus_hp_cap") * growth_delta

	for horse_id in _horse_order:
		if not _horses.has(horse_id):
			continue
		var horse: Dictionary = _horses[horse_id]
		if str(horse.get("location", LOCATION_STABLE)) != LOCATION_STABLE:
			continue
		var before := horse.duplicate(true)
		var old_growth := clampf(float(horse.get("growth", 0.0)), 0.0, 1.0)
		var old_natural_max_hp := _calculate_natural_max_hp(old_growth)
		var new_growth := minf(1.0, old_growth + growth_delta)
		if new_growth > old_growth:
			horse["growth"] = new_growth
			var natural_max_increase := _calculate_natural_max_hp(new_growth) - old_natural_max_hp
			horse["hp"] = float(horse.get("hp", 0.0)) + maxf(0.0, natural_max_increase)

		var care_bonus_cap := maxf(float(horse.get("care_bonus_cap", 0.0)), skill_bonus_cap)
		horse["care_bonus_cap"] = care_bonus_cap
		var natural_max_hp := _calculate_natural_max_hp(float(horse.get("growth", 0.0)))
		var natural_hp := float(horse.get("hp", 0.0)) - float(horse.get("care_bonus_hp", 0.0))
		if natural_hp + 0.0001 >= natural_max_hp:
			var missing_bonus_hp := maxf(0.0, care_bonus_cap - float(horse.get("care_bonus_hp", 0.0)))
			var restored_bonus_hp := minf(missing_bonus_hp, bonus_hp_delta)
			if restored_bonus_hp > 0.0:
				horse["care_bonus_hp"] = float(horse.get("care_bonus_hp", 0.0)) + restored_bonus_hp
				horse["hp"] = float(horse.get("hp", 0.0)) + restored_bonus_hp

		_normalize_horse_runtime(horse)
		_horses[horse_id] = horse
		if before != horse:
			changed_horse_ids[horse_id] = true


func _roll_births_for_minute(caretaker: Dictionary, changed_horse_ids: Dictionary) -> void:
	var candidate_ids := _get_stable_breeding_candidate_ids()
	if candidate_ids.size() < 2:
		return

	var skill_factor := clampf(float(caretaker.get("skill", 0.0)) / 100.0, 0.0, 1.0)
	var level_factor := maxf(1.0, float(caretaker.get("level_factor", 1.0)))
	var probability_gain := maxf(
		0.0,
		_balance_float("birth_probability_gain_per_care_minute") * skill_factor * level_factor
	)
	var probability_cap := clampf(
		_balance_float("birth_probability_cap"),
		0.0,
		1.0
	)
	for horse_id in candidate_ids:
		var horse: Dictionary = _horses.get(horse_id, {})
		var before_probability := float(horse.get("breeding_probability", 0.0))
		horse["breeding_probability"] = minf(probability_cap, before_probability + probability_gain)
		_normalize_horse_runtime(horse)
		_horses[horse_id] = horse
		if not is_equal_approx(before_probability, float(horse.get("breeding_probability", 0.0))):
			changed_horse_ids[horse_id] = true

	var roll_candidates: Array[String] = candidate_ids.duplicate()
	for roll_index in range(candidate_ids.size() - 1):
		var swap_index := _rng.randi_range(roll_index, roll_candidates.size() - 1)
		var swap_value := roll_candidates[roll_index]
		roll_candidates[roll_index] = roll_candidates[swap_index]
		roll_candidates[swap_index] = swap_value
		var parent_id := roll_candidates[roll_index]
		var parent: Dictionary = _horses.get(parent_id, {})
		if _rng.randf() >= float(parent.get("breeding_probability", 0.0)):
			continue
		var horse_id := _spawn_foal()
		if not horse_id.is_empty():
			changed_horse_ids[horse_id] = true
			_start_birth_cooldown(candidate_ids, changed_horse_ids)
		return


func _get_stable_breeding_candidate_ids() -> Array[String]:
	var candidate_ids: Array[String] = []
	for horse_id in _horse_order:
		var horse: Dictionary = _horses.get(horse_id, {})
		if str(horse.get("location", LOCATION_STABLE)) != LOCATION_STABLE:
			continue
		if not _is_horse_adult(horse):
			continue
		if float(horse.get("breeding_cooldown_remaining_seconds", 0.0)) > 0.0:
			continue
		candidate_ids.append(horse_id)
	return candidate_ids


func _start_birth_cooldown(parent_ids: Array[String], changed_horse_ids: Dictionary) -> void:
	var cooldown_seconds := maxf(0.0, _balance_float("birth_cooldown_minutes") * 60.0)
	for horse_id in parent_ids:
		if not _horses.has(horse_id):
			continue
		var horse: Dictionary = _horses[horse_id]
		horse["breeding_probability"] = 0.0
		horse["breeding_cooldown_remaining_seconds"] = cooldown_seconds
		_normalize_horse_runtime(horse)
		_horses[horse_id] = horse
		changed_horse_ids[horse_id] = true


func _get_effective_caretaker_snapshot() -> Dictionary:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if action_system == null or npc_system == null:
		return {"active": false}
	if not action_system.has_method("get_active_action_id") or not npc_system.has_method("get_npc_ids"):
		return {"active": false}

	var best_npc_id := ""
	var best_skill := -1.0
	var npc_ids: Variant = npc_system.call("get_npc_ids")
	if not npc_ids is Array:
		return {"active": false}
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		if str(action_system.call("get_active_action_id", npc_id)) != STABLE_ACTION_ID:
			continue
		var profile: Dictionary = npc_system.call("get_npc", npc_id)
		if profile.is_empty():
			continue
		var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
		if str(states.get("current_location", "")) != STABLE_BUILDING_ID:
			continue
		if bool(states.get("unconscious", false)) or bool(states.get("escaped", false)):
			continue
		var behavior_mode := str(states.get("behavior_mode", "work"))
		if [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT, BEHAVIOR_MODE_UNCONSCIOUS, BEHAVIOR_MODE_ESCAPED].has(behavior_mode):
			continue
		var skills: Dictionary = profile.get("skills", {}) if profile.get("skills", {}) is Dictionary else {}
		var skill := clampf(float(skills.get(HORSE_CARE_SKILL, 0.0)), 0.0, 100.0)
		if skill > best_skill:
			best_skill = skill
			best_npc_id = npc_id
	if best_npc_id.is_empty():
		return {"active": false}

	var stable_level := 1
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and building_system.has_method("get_building"):
		var stable: Variant = building_system.call("get_building", STABLE_BUILDING_ID)
		if stable is Dictionary:
			stable_level = maxi(1, int(stable.get("level", 1)))
	return {
		"active": true,
		"npc_id": best_npc_id,
		"skill": best_skill,
		"stable_level": stable_level,
		"level_factor": 1.0 + float(stable_level - 1) * _balance_float("stable_level_birth_bonus_per_level"),
	}


func _reconcile_npc_riding_state(npc_id: String) -> void:
	var horse_id := _find_assigned_horse_id(npc_id)
	if horse_id.is_empty() or not _horses.has(horse_id):
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return
	var profile: Dictionary = npc_system.call("get_npc", npc_id)
	if profile.is_empty():
		return
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	var behavior_mode := str(states.get("behavior_mode", "work"))
	var should_be_ridden := (
		[BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(behavior_mode)
		and not bool(states.get("unconscious", false))
		and not bool(states.get("escaped", false))
	)
	var horse: Dictionary = _horses[horse_id]
	var changed := false
	if should_be_ridden:
		if str(horse.get("location", LOCATION_STABLE)) != LOCATION_RIDDEN or str(horse.get("ridden_by_npc_id", "")) != npc_id:
			horse["location"] = LOCATION_RIDDEN
			horse["ridden_by_npc_id"] = npc_id
			horse["feeding"] = _make_idle_feeding_state()
			changed = true
	else:
		if str(horse.get("location", LOCATION_STABLE)) != LOCATION_STABLE or not str(horse.get("ridden_by_npc_id", "")).is_empty():
			horse["location"] = LOCATION_STABLE
			horse["ridden_by_npc_id"] = ""
			horse["feeding"] = _make_idle_feeding_state()
			changed = true
	if not changed:
		return
	_horses[horse_id] = horse
	_emit_horse_state_changed(horse_id)
	_publish_stable_summary()


func _get_npc_assignment_ineligibility_reason(npc_id: String) -> String:
	if npc_id.is_empty():
		return "invalid_npc_id"
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return "npc_system_unavailable"
	var profile: Dictionary = npc_system.call("get_npc", npc_id)
	if profile.is_empty():
		return "unknown_npc"
	if not bool(profile.get("recruited", false)):
		return "npc_not_recruited"
	var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
	if bool(states.get("escaped", false)) or str(states.get("behavior_mode", "")) == BEHAVIOR_MODE_ESCAPED:
		return "npc_escaped"
	var equipment: Dictionary = profile.get("equipment", {}) if profile.get("equipment", {}) is Dictionary else {}
	var main_weapon: Variant = equipment.get("main_weapon", {})
	if not main_weapon is Dictionary or main_weapon.is_empty():
		return "npc_has_no_main_weapon"
	return ""


func _find_assigned_horse_id(npc_id: String) -> String:
	if npc_id.is_empty():
		return ""
	for horse_id in _horse_order:
		var horse: Dictionary = _horses.get(horse_id, {})
		if str(horse.get("assigned_npc_id", "")) == npc_id:
			return horse_id
	return ""


func _spawn_foal() -> String:
	var horse_id := ""
	while horse_id.is_empty() or _horses.has(horse_id):
		horse_id = "horse_foal_%03d" % _next_foal_serial
		_next_foal_serial += 1
	var horse := _make_horse_from_definition({
		"horse_id": horse_id,
		"name": "幼马 %d" % (_next_foal_serial - 1),
		"growth": 0.0,
	})
	if horse.is_empty():
		return ""
	_horses[horse_id] = horse
	_horse_order.append(horse_id)
	return horse_id


func _make_horse_from_definition(definition: Dictionary) -> Dictionary:
	var horse_id := str(definition.get("horse_id", "")).strip_edges()
	if horse_id.is_empty():
		push_error("Skipped horse definition with empty horse_id.")
		return {}
	var growth := clampf(float(definition.get("growth", 0.0)), 0.0, 1.0)
	var natural_max_hp := _calculate_natural_max_hp(growth)
	var max_satiety := _calculate_max_satiety(growth)
	var care_bonus_cap := clampf(
		float(definition.get("care_bonus_cap", 0.0)),
		0.0,
		_balance_float("care_skill_100_bonus_hp_cap")
	)
	var care_bonus_hp := clampf(float(definition.get("care_bonus_hp", 0.0)), 0.0, care_bonus_cap)
	var horse := {
		"horse_id": horse_id,
		"name": str(definition.get("name", horse_id)),
		"growth": growth,
		"hp": clampf(
			float(definition.get("hp", natural_max_hp + care_bonus_hp)),
			0.0,
			natural_max_hp + care_bonus_hp
		),
		"care_bonus_hp": care_bonus_hp,
		"care_bonus_cap": care_bonus_cap,
		"breeding_probability": clampf(
			float(definition.get("breeding_probability", 0.0)),
			0.0,
			_balance_float("birth_probability_cap")
		),
		"breeding_cooldown_remaining_seconds": maxf(
			0.0,
			float(definition.get("breeding_cooldown_remaining_seconds", 0.0))
		),
		"satiety": clampf(float(definition.get("satiety", max_satiety)), 0.0, max_satiety),
		"location": LOCATION_STABLE,
		"feeding": _make_idle_feeding_state(),
		"assigned_npc_id": "",
		"ridden_by_npc_id": "",
	}
	_normalize_horse_runtime(horse)
	return horse


func _make_public_horse_snapshot(horse: Dictionary) -> Dictionary:
	var snapshot := horse.duplicate(true)
	var growth := clampf(float(horse.get("growth", 0.0)), 0.0, 1.0)
	var natural_max_hp := _calculate_natural_max_hp(growth)
	var max_satiety := _calculate_max_satiety(growth)
	var care_bonus_cap := float(horse.get("care_bonus_cap", 0.0))
	var feeding: Dictionary = (
		(horse.get("feeding", {}) as Dictionary).duplicate(true)
		if horse.get("feeding", {}) is Dictionary
		else {}
	)
	var feeding_duration := maxf(1.0, _balance_float("feeding_duration_seconds"))
	feeding["progress"] = clampf(
		float(feeding.get("elapsed_seconds", 0.0)) / feeding_duration,
		0.0,
		1.0
	)
	snapshot["growth"] = growth
	snapshot["is_adult"] = growth + 0.0001 >= _balance_float("adult_growth_threshold")
	snapshot["life_stage"] = "adult" if bool(snapshot["is_adult"]) else "foal"
	snapshot["natural_max_hp"] = natural_max_hp
	snapshot["base_hp"] = maxf(0.0, float(horse.get("hp", 0.0)) - float(horse.get("care_bonus_hp", 0.0)))
	snapshot["care_bonus_cap"] = care_bonus_cap
	snapshot["extra_hp"] = float(horse.get("care_bonus_hp", 0.0))
	snapshot["extra_hp_cap"] = care_bonus_cap
	snapshot["max_hp"] = natural_max_hp + care_bonus_cap
	snapshot["max_satiety"] = max_satiety
	snapshot["breeding_probability"] = clampf(
		float(horse.get("breeding_probability", 0.0)),
		0.0,
		_balance_float("birth_probability_cap")
	)
	snapshot["breeding_cooldown_remaining_seconds"] = maxf(
		0.0,
		float(horse.get("breeding_cooldown_remaining_seconds", 0.0))
	)
	snapshot["breeding_cooldown_active"] = float(snapshot["breeding_cooldown_remaining_seconds"]) > 0.0
	snapshot["feeding"] = feeding
	snapshot["recovering"] = (
		float(horse.get("hp", 0.0)) - float(horse.get("care_bonus_hp", 0.0)) + 0.0001 < natural_max_hp
		and float(horse.get("satiety", 0.0)) > 0.0
	)
	return snapshot


func _normalize_horse_runtime(horse: Dictionary) -> void:
	var growth := clampf(float(horse.get("growth", 0.0)), 0.0, 1.0)
	horse["growth"] = growth
	var natural_max_hp := _calculate_natural_max_hp(growth)
	var max_satiety := _calculate_max_satiety(growth)
	var care_bonus_cap := clampf(
		float(horse.get("care_bonus_cap", 0.0)),
		0.0,
		_balance_float("care_skill_100_bonus_hp_cap")
	)
	var care_bonus_hp := clampf(float(horse.get("care_bonus_hp", 0.0)), 0.0, care_bonus_cap)
	horse["care_bonus_cap"] = care_bonus_cap
	horse["care_bonus_hp"] = care_bonus_hp
	horse["hp"] = clampf(float(horse.get("hp", 0.0)), 0.0, natural_max_hp + care_bonus_hp)
	horse["satiety"] = clampf(float(horse.get("satiety", 0.0)), 0.0, max_satiety)
	var breeding_cooldown := maxf(0.0, float(horse.get("breeding_cooldown_remaining_seconds", 0.0)))
	horse["breeding_cooldown_remaining_seconds"] = breeding_cooldown
	horse["breeding_probability"] = clampf(
		float(horse.get("breeding_probability", 0.0)),
		0.0,
		_balance_float("birth_probability_cap")
	)
	if breeding_cooldown > 0.0:
		horse["breeding_probability"] = 0.0
	var location := str(horse.get("location", LOCATION_STABLE))
	if not [LOCATION_STABLE, LOCATION_RIDDEN].has(location):
		location = LOCATION_STABLE
	horse["location"] = location
	if location == LOCATION_STABLE:
		horse["ridden_by_npc_id"] = ""
	if not horse.get("feeding", {}) is Dictionary:
		horse["feeding"] = _make_idle_feeding_state()


func _calculate_natural_max_hp(growth: float) -> float:
	return lerpf(
		_balance_float("foal_natural_max_hp"),
		_balance_float("adult_natural_max_hp"),
		clampf(growth, 0.0, 1.0)
	)


func _calculate_max_satiety(growth: float) -> float:
	return lerpf(
		_balance_float("foal_max_satiety"),
		_balance_float("adult_max_satiety"),
		clampf(growth, 0.0, 1.0)
	)


func _is_horse_adult(horse: Dictionary) -> bool:
	return float(horse.get("growth", 0.0)) + 0.0001 >= _balance_float("adult_growth_threshold")


func _make_idle_feeding_state() -> Dictionary:
	return {
		"active": false,
		"elapsed_seconds": 0.0,
		"waiting_for_grain": false,
	}


func _apply_loaded_balance(loaded_balance: Dictionary) -> void:
	for key in DEFAULT_BALANCE.keys():
		if not loaded_balance.has(key):
			push_warning("Horse balance uses default for missing field: %s" % str(key))
			continue
		_balance[key] = loaded_balance[key]
	_balance["feeding_missing_ratio"] = clampf(float(_balance.get("feeding_missing_ratio", 0.2)), 0.0, 1.0)
	_balance["adult_growth_threshold"] = clampf(float(_balance.get("adult_growth_threshold", 0.6)), 0.0, 1.0)
	_balance["birth_probability_gain_per_care_minute"] = clampf(
		float(_balance.get("birth_probability_gain_per_care_minute", 0.0)),
		0.0,
		1.0
	)
	_balance["birth_probability_cap"] = clampf(float(_balance.get("birth_probability_cap", 1.0)), 0.0, 1.0)
	for key in [
		"stable_satiety_loss_per_hour",
		"outside_satiety_loss_per_hour",
		"feeding_duration_seconds",
		"feeding_satiety_restore",
		"natural_hp_restore_per_hour",
		"satiety_cost_per_hp",
		"foal_natural_max_hp",
		"foal_max_satiety",
		"adult_natural_max_hp",
		"adult_max_satiety",
		"base_full_growth_care_minutes",
		"birth_cooldown_minutes",
		"stable_level_birth_bonus_per_level",
		"care_skill_100_bonus_hp_cap",
	]:
		_balance[key] = maxf(0.0, float(_balance.get(key, DEFAULT_BALANCE[key])))
	_balance["feeding_duration_seconds"] = maxf(1.0, float(_balance["feeding_duration_seconds"]))
	_balance["base_full_growth_care_minutes"] = maxf(1.0, float(_balance["base_full_growth_care_minutes"]))
	_balance["feeding_grain_cost"] = maxi(0, int(_balance.get("feeding_grain_cost", 1)))


func _balance_float(key: String) -> float:
	return float(_balance.get(key, DEFAULT_BALANCE.get(key, 0.0)))


func _balance_int(key: String) -> int:
	return int(_balance.get(key, DEFAULT_BALANCE.get(key, 0)))


func _publish_stable_summary(force: bool = false) -> void:
	var summary := get_stable_horse_summary()
	if summary != _last_stable_summary:
		_last_stable_summary = summary.duplicate(true)
		_building_summary_published = false
	if not force and _building_summary_published:
		return
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("set_building_special_state_section"):
		return
	var result: Variant = building_system.call(
		"set_building_special_state_section",
		STABLE_BUILDING_ID,
		"horses",
		summary
	)
	_building_summary_published = not (result is bool and not bool(result))


func _emit_horse_state_changed(horse_id: String) -> void:
	var event_bus := _get_event_bus()
	if event_bus != null and event_bus.has_signal("horse_state_changed"):
		event_bus.horse_state_changed.emit(horse_id)


func _emit_horse_assignment_changed(horse_id: String, npc_id: String) -> void:
	var event_bus := _get_event_bus()
	if event_bus != null and event_bus.has_signal("horse_assignment_changed"):
		event_bus.horse_assignment_changed.emit(horse_id, npc_id)


func _get_event_bus() -> Node:
	if _event_bus == null:
		_event_bus = get_node_or_null("/root/EventBus")
	return _event_bus


func _is_successful_interface_result(result: Variant) -> bool:
	if result is bool:
		return bool(result)
	if result is Dictionary:
		return bool(result.get("ok", false))
	return result != null


func _assignment_failure(reason: String, npc_id: String, horse_id: String) -> Dictionary:
	return {
		"ok": false,
		"changed": false,
		"error": reason,
		"reason": reason,
		"message": _get_assignment_failure_message(reason),
		"npc_id": npc_id,
		"horse_id": horse_id,
	}


func _get_assignment_failure_message(reason: String) -> String:
	match reason:
		"invalid_npc_id", "unknown_npc":
			return "NPC 不存在。"
		"npc_system_unavailable":
			return "NPC 系统不可用。"
		"npc_not_recruited":
			return "只有已入伍 NPC 可以分配马匹。"
		"npc_escaped":
			return "逃离的 NPC 不能分配马匹。"
		"npc_has_no_main_weapon":
			return "NPC 必须先装备主武器才能分配马匹。"
		"no_available_horse":
			return "没有可分配的成年在厩马。"
		"unknown_horse":
			return "马匹不存在。"
		"horse_not_adult":
			return "幼马尚未成年，不能分配。"
		"horse_already_assigned":
			return "该马已分配给其他 NPC。"
		"npc_already_has_horse":
			return "该 NPC 已分配马匹，请先取消当前分配。"
		"horse_not_in_stable":
			return "只有物理上在马厩的马才能分配。"
		"equipment_system_unavailable":
			return "装备系统不可用。"
		"equipment_sync_failed":
			return "马匹分配未能写入 NPC 坐骑槽。"
		_:
			return "马匹分配失败：%s" % reason
