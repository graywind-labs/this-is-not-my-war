extends Node

const ACTOR_MOTION_SCENE := preload("res://scenes/debug/ActorMotionBody.tscn")
const HORSE_DEFS_FILE := "horse_defs.json"
const STABLE_BUILDING_ID := "stable"
const STABLE_ACTION_ID := "work_stable"
const HORSE_CARE_SKILL := "养马"
const GRAIN_RESOURCE_ID := "grain"
const LOCATION_STABLE := "stable"
const LOCATION_APPROACHING_RIDER := "approaching_rider"
const LOCATION_RIDDEN := "ridden"
const LOCATION_RETURNING_STABLE := "returning_stable"
const LOCATION_DEAD := "dead"
const MOUNT_PICKUP_WAITING_PHASE := "waiting_for_rider_at_stable"
const RETURN_PATH_PICKUP_WAITING_PHASE := "waiting_for_rider_at_return_position"
const BEHAVIOR_MODE_RALLY := "rally"
const BEHAVIOR_MODE_COMBAT := "combat"
const BEHAVIOR_MODE_WORK := "work"
const BEHAVIOR_MODE_UNCONSCIOUS := "unconscious"
const BEHAVIOR_MODE_ESCAPED := "escaped"
const FIXED_SIMULATION_STEP_SECONDS := 60.0
const HORSE_PRESENTATION_GROUP := "horse_world_presentation"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const WORLD_CLICK_COLLISION_MASK := 4
const WORLD_CLICK_RAY_LENGTH := 1000.0
const RETURN_PATH_PICKUP_SEPARATION := 1.25
const RIDER_ROUTE_RECOVERY_RETRY_MSEC := 500

const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const STATION_LAYOUT_CONTROLLER_PATH := "/root/Main/Presentation/StationLayoutController"

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
	"mount_rendezvous_horse_speed": 7.0,
	"mount_rendezvous_npc_share": 0.35,
	"mount_rendezvous_arrival_distance": 0.35,
	"return_to_stable_speed": 3.2,
	"mounted_damage_share_min": 0.3,
	"mounted_damage_share_max": 0.5,
}

var _horses: Dictionary = {}
var _horse_order: Array[String] = []
var _horse_templates: Dictionary = {}
var _horse_template_order: Array[String] = []
var _stable_slots_by_level: Dictionary = {}
var _balance: Dictionary = DEFAULT_BALANCE.duplicate(true)
var _simulation_accumulator_seconds: float = 0.0
var _next_foal_serial: int = 1
var _last_stable_summary: Dictionary = {}
var _building_summary_published: bool = false
var _assignment_mutation_depth: int = 0
var _rng := RandomNumberGenerator.new()
var _event_bus: Node = null
var _last_birth_failure_reason := ""
var _horse_motion_actors: Dictionary = {}


func _ready() -> void:
	initialize()
	set_process(true)
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus == null:
		return
	if _event_bus.has_signal("logical_time_tick") and not _event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
		_event_bus.logical_time_tick.connect(_on_logical_time_tick)
	if _event_bus.has_signal("npc_state_changed") and not _event_bus.npc_state_changed.is_connected(_on_npc_state_changed):
		_event_bus.npc_state_changed.connect(_on_npc_state_changed)
	if _event_bus.has_signal("recruitment_changed") and not _event_bus.recruitment_changed.is_connected(_on_recruitment_changed):
		_event_bus.recruitment_changed.connect(_on_recruitment_changed)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var paused := _is_gameplay_paused()
	_set_horse_motion_paused(paused)
	if paused:
		return
	_advance_horse_world_transitions(delta)


func initialize() -> void:
	_clear_all_horse_motion_actors("horse_system_initialized")
	_horses.clear()
	_horse_order.clear()
	_horse_templates.clear()
	_horse_template_order.clear()
	_stable_slots_by_level.clear()
	_balance = DEFAULT_BALANCE.duplicate(true)
	_simulation_accumulator_seconds = 0.0
	_next_foal_serial = 1
	_last_stable_summary.clear()
	_building_summary_published = false
	_assignment_mutation_depth = 0
	_last_birth_failure_reason = ""
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
	_load_stable_slots(loaded_defs.get("stable_slots_by_level", {}))
	_load_horse_templates(loaded_defs.get("horse_templates", []))

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


func get_stable_slot_ids(level: int = 0) -> Array[String]:
	var resolved_level := _get_current_stable_level() if level <= 0 else clampi(level, 1, 3)
	var raw_slots: Variant = _stable_slots_by_level.get(str(resolved_level), [])
	var result: Array[String] = []
	if raw_slots is Array:
		for raw_slot_id in raw_slots:
			var slot_id := str(raw_slot_id).strip_edges()
			if not slot_id.is_empty() and not result.has(slot_id):
				result.append(slot_id)
	return result


func get_stable_capacity(level: int = 0) -> int:
	return get_stable_slot_ids(level).size()


func get_horse_template_snapshot(template_id: String) -> Dictionary:
	var template: Variant = _horse_templates.get(template_id, {})
	return (template as Dictionary).duplicate(true) if template is Dictionary else {}


func get_horse_presentation_snapshot(horse_id: String) -> Dictionary:
	for raw_presenter in get_tree().get_nodes_in_group(HORSE_PRESENTATION_GROUP):
		var presenter := raw_presenter as Node
		if presenter != null and presenter.has_method("get_horse_presentation_snapshot"):
			var raw_snapshot: Variant = presenter.call("get_horse_presentation_snapshot", horse_id)
			if raw_snapshot is Dictionary and not (raw_snapshot as Dictionary).is_empty():
				var snapshot := (raw_snapshot as Dictionary).duplicate(true)
				snapshot["valid"] = true
				return snapshot
	return {}


func get_world_click_interaction(screen_position: Vector2) -> Dictionary:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	if camera == null:
		return {}
	var world_3d := get_viewport().world_3d
	if world_3d == null:
		return {}
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * WORLD_CLICK_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, WORLD_CLICK_COLLISION_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var collider := result.get("collider") as Node
	while collider != null:
		var horse_id := str(collider.get_meta("horse_id", "")).strip_edges()
		if not horse_id.is_empty() and _horses.has(horse_id):
			var horse: Dictionary = _horses[horse_id]
			if bool(horse.get("alive", true)):
				return {
					"kind": "horse",
					"horse_id": horse_id,
					"collider": result.get("collider"),
					"distance": ray_origin.distance_to(result.get("position", ray_end)),
					"global_position": result.get("position", ray_end),
				}
		collider = collider.get_parent()
	return {}


func select_horse_from_world_click(horse_id: String) -> bool:
	if not _horses.has(horse_id) or not bool((_horses[horse_id] as Dictionary).get("alive", true)):
		return false
	if _event_bus == null:
		_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus == null or not _event_bus.has_signal("horse_clicked"):
		return false
	_event_bus.horse_clicked.emit(horse_id)
	return true


func get_stable_horse_summary() -> Dictionary:
	var total := 0
	var adult := 0
	for horse_id in _horse_order:
		var horse: Dictionary = _horses.get(horse_id, {})
		if not bool(horse.get("alive", true)):
			continue
		if str(horse.get("location", LOCATION_STABLE)) != LOCATION_STABLE:
			continue
		total += 1
		if _is_horse_adult(horse):
			adult += 1
	return {
		"total": total,
		"adult": adult,
		"foal": total - adult,
		"occupied_slots": _get_alive_horse_count(),
		"capacity": get_stable_capacity(),
		"full": _is_stable_full(),
	}


func get_stable_summary() -> Dictionary:
	var summary := get_stable_horse_summary()
	var outside := 0
	var ridden := 0
	var dead := 0
	for horse_id in _horse_order:
		var horse: Dictionary = _horses.get(horse_id, {})
		if not bool(horse.get("alive", true)):
			dead += 1
			continue
		if str(horse.get("location", LOCATION_STABLE)) == LOCATION_RIDDEN:
			ridden += 1
		if str(horse.get("location", LOCATION_STABLE)) != LOCATION_STABLE:
			outside += 1
	summary["outside"] = outside
	summary["ridden"] = ridden
	summary["dead"] = dead
	summary["total_count"] = int(summary.get("total", 0))
	summary["adult_count"] = int(summary.get("adult", 0))
	summary["foal_count"] = int(summary.get("foal", 0))
	return summary


func get_horse_counts_snapshot() -> Dictionary:
	var stable_summary := get_stable_horse_summary()
	var ridden := 0
	var assigned := 0
	var alive := 0
	var dead := 0
	for horse_id in _horse_order:
		var horse: Dictionary = _horses.get(horse_id, {})
		if not bool(horse.get("alive", true)):
			dead += 1
			continue
		alive += 1
		if str(horse.get("location", LOCATION_STABLE)) == LOCATION_RIDDEN:
			ridden += 1
		if not str(horse.get("assigned_npc_id", "")).is_empty():
			assigned += 1
	return {
		"total": alive,
		"records": _horse_order.size(),
		"dead": dead,
		"stable": stable_summary,
		"ridden": ridden,
		"assigned": assigned,
	}


func get_assigned_horse_for_npc(npc_id: String) -> Dictionary:
	var horse_id := _find_assigned_horse_id(npc_id)
	return get_horse_snapshot(horse_id) if not horse_id.is_empty() else {}


func get_available_horses_for_npc(npc_id: String) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if (
		not _get_npc_assignment_ineligibility_reason(npc_id).is_empty()
		or not _get_npc_manual_loadout_ineligibility_reason(npc_id).is_empty()
	):
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
	if npc_reason.is_empty():
		npc_reason = _get_npc_manual_loadout_ineligibility_reason(npc_id)
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
	if not bool(horse.get("alive", true)):
		return _assignment_failure("horse_dead", npc_id, resolved_horse_id)
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
	var mode_reason := _get_npc_manual_loadout_ineligibility_reason(npc_id)
	if not mode_reason.is_empty():
		return _assignment_failure(mode_reason, npc_id, _find_assigned_horse_id(npc_id))
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
	if str(horse.get("location", LOCATION_STABLE)) != LOCATION_RETURNING_STABLE:
		_release_horse_motion_actor(horse_id, "horse_unassigned_in_stable")
		horse["location"] = LOCATION_STABLE
		horse["movement_state"] = _make_idle_movement_state()
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


func apply_damage_to_horse(horse_id: String, damage: float, context: Dictionary = {}) -> Dictionary:
	if not _horses.has(horse_id):
		return {"ok": false, "reason": "unknown_horse", "horse_id": horse_id}
	if damage <= 0.0:
		return {"ok": false, "reason": "invalid_damage", "horse_id": horse_id}

	var horse: Dictionary = _horses[horse_id]
	if not bool(horse.get("alive", true)):
		return {"ok": false, "reason": "horse_dead", "horse_id": horse_id}
	var hp_before := float(horse.get("hp", 0.0))
	var applied_damage := minf(damage, hp_before)
	var bonus_before := float(horse.get("care_bonus_hp", 0.0))
	var bonus_damage := minf(applied_damage, bonus_before)
	horse["care_bonus_hp"] = maxf(0.0, bonus_before - bonus_damage)
	horse["hp"] = maxf(0.0, hp_before - applied_damage)
	var died := float(horse.get("hp", 0.0)) <= 0.0
	var rider_npc_id := str(horse.get("ridden_by_npc_id", horse.get("assigned_npc_id", "")))
	if rider_npc_id.is_empty():
		rider_npc_id = str(horse.get("assigned_npc_id", ""))
	_horses[horse_id] = horse
	var death_result := {}
	if died:
		var death_context := context.duplicate(true)
		death_context["horse_damage"] = applied_damage
		death_context["horse_hp_before"] = hp_before
		death_result = _handle_horse_death(horse_id, rider_npc_id, death_context)
	else:
		_log_horse_damage_event(horse_id, rider_npc_id, applied_damage, hp_before, float(horse.get("hp", 0.0)), false, context)
	_emit_horse_state_changed(horse_id)
	return {
		"ok": true,
		"horse_id": horse_id,
		"damage": applied_damage,
		"hp_before": hp_before,
		"hp_after": float(_horses.get(horse_id, {}).get("hp", 0.0)),
		"died": died,
		"rider_npc_id": rider_npc_id,
		"death_result": death_result,
		"horse": get_horse_snapshot(horse_id),
	}


func split_mounted_damage(npc_id: String, resolved_damage: int, context: Dictionary = {}) -> Dictionary:
	var unchanged := {
		"ok": true,
		"split": false,
		"npc_id": npc_id,
		"incoming_damage": maxi(0, resolved_damage),
		"npc_damage": maxi(0, resolved_damage),
		"horse_damage": 0,
		"share_ratio": 0.0,
		"horse_result": {}
	}
	if resolved_damage <= 0:
		return unchanged
	var horse_id := _find_assigned_horse_id(npc_id)
	if horse_id.is_empty() or not _horses.has(horse_id):
		return unchanged
	var horse: Dictionary = _horses[horse_id]
	if (
		not bool(horse.get("alive", true))
		or str(horse.get("location", "")) != LOCATION_RIDDEN
		or str(horse.get("ridden_by_npc_id", "")) != npc_id
	):
		return unchanged
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system != null and npc_system.has_method("get_npc_state") else {}
	if not bool(npc_state.get("combat_mounted", false)):
		return unchanged
	var min_share := clampf(_balance_float("mounted_damage_share_min"), 0.0, 1.0)
	var max_share := clampf(_balance_float("mounted_damage_share_max"), min_share, 1.0)
	var share_ratio := _rng.randf_range(min_share, max_share)
	var horse_damage := clampi(int(round(float(resolved_damage) * share_ratio)), 0, resolved_damage)
	var npc_damage := resolved_damage - horse_damage
	var horse_context := context.duplicate(true)
	horse_context["target_npc_id"] = npc_id
	horse_context["incoming_damage"] = resolved_damage
	horse_context["share_ratio"] = share_ratio
	var horse_result := apply_damage_to_horse(horse_id, float(horse_damage), horse_context) if horse_damage > 0 else {}
	return {
		"ok": true,
		"split": horse_damage > 0,
		"npc_id": npc_id,
		"horse_id": horse_id,
		"incoming_damage": resolved_damage,
		"npc_damage": npc_damage,
		"horse_damage": horse_damage,
		"share_ratio": share_ratio,
		"horse_result": horse_result
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


func debug_set_random_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func debug_complete_horse_transition(horse_id: String) -> Dictionary:
	if not _horses.has(horse_id):
		return {"ok": false, "reason": "unknown_horse", "horse_id": horse_id}
	var horse: Dictionary = _horses[horse_id]
	var movement: Dictionary = horse.get("movement_state", {}) if horse.get("movement_state", {}) is Dictionary else {}
	var phase := str(movement.get("phase", "idle"))
	if _is_mount_pickup_waiting_phase(phase) or phase == LOCATION_APPROACHING_RIDER:
		var npc_id := str(horse.get("assigned_npc_id", ""))
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system != null and npc_system.has_method("stop_npc_movement_with_state"):
			npc_system.stop_npc_movement_with_state(npc_id, {"movement_target": "", "movement_target_name": ""})
		_complete_mount_rendezvous(horse_id)
	elif phase == LOCATION_RETURNING_STABLE:
		horse["world_position"] = movement.get("target_position", Vector3.ZERO)
		_horses[horse_id] = horse
		_complete_return_to_stable(horse_id)
	else:
		return {"ok": false, "reason": "horse_not_moving", "horse_id": horse_id, "phase": phase}
	return {"ok": true, "horse_id": horse_id, "horse": get_horse_snapshot(horse_id)}


func debug_force_birth() -> Dictionary:
	var block_reason := _get_birth_block_reason()
	if not block_reason.is_empty():
		return {
			"ok": false,
			"reason": block_reason,
			"capacity": get_stable_capacity(),
			"occupied_slots": _get_alive_horse_count(),
		}
	var parent_ids := _get_stable_breeding_candidate_ids()
	var horse_id := _spawn_foal()
	if horse_id.is_empty():
		return {"ok": false, "reason": _last_birth_failure_reason if not _last_birth_failure_reason.is_empty() else "birth_failed"}
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


func debug_ensure_horses(definitions: Array) -> Dictionary:
	var normalized_definitions: Array[Dictionary] = []
	var requested_ids := {}
	for raw_definition in definitions:
		if not raw_definition is Dictionary:
			return {"ok": false, "reason": "invalid_horse_definition"}
		var definition: Dictionary = (raw_definition as Dictionary).duplicate(true)
		var horse_id := str(definition.get("horse_id", "")).strip_edges()
		if horse_id.is_empty() or requested_ids.has(horse_id):
			return {"ok": false, "reason": "invalid_or_duplicate_horse_id", "horse_id": horse_id}
		if float(definition.get("growth", 0.0)) + 0.0001 < _balance_float("adult_growth_threshold"):
			return {"ok": false, "reason": "debug_horse_not_adult", "horse_id": horse_id}
		requested_ids[horse_id] = true
		normalized_definitions.append(definition)
	var missing_count := 0
	for definition in normalized_definitions:
		if not _horses.has(str(definition.get("horse_id", ""))):
			missing_count += 1
	if _get_alive_horse_count() + missing_count > get_stable_capacity():
		return {
			"ok": false,
			"reason": "stable_full",
			"capacity": get_stable_capacity(),
			"occupied_slots": _get_alive_horse_count(),
			"requested_new_horses": missing_count,
		}

	var created_ids: Array[String] = []
	for definition in normalized_definitions:
		var horse_id := str(definition.get("horse_id", ""))
		if _horses.has(horse_id):
			var existing: Dictionary = _horses[horse_id]
			if not bool(existing.get("alive", true)) or not _is_horse_adult(existing):
				return {"ok": false, "reason": "existing_debug_horse_unavailable", "horse_id": horse_id}
			continue
		var horse := _make_horse_from_definition(definition)
		if horse.is_empty():
			return {"ok": false, "reason": "debug_horse_creation_failed", "horse_id": horse_id}
		horse["debug_created"] = true
		_horses[horse_id] = horse
		_horse_order.append(horse_id)
		created_ids.append(horse_id)
		_emit_horse_state_changed(horse_id)

	if not created_ids.is_empty():
		_publish_stable_summary(true)
	var horses: Array[Dictionary] = []
	for horse_id in requested_ids.keys():
		horses.append(get_horse_snapshot(str(horse_id)))
	return {
		"ok": true,
		"changed": not created_ids.is_empty(),
		"created_horse_ids": created_ids,
		"horses": horses,
	}


func debug_set_horse_growth(horse_id: String, growth: float) -> Dictionary:
	if not _horses.has(horse_id):
		return {"ok": false, "reason": "unknown_horse", "horse_id": horse_id}
	var horse: Dictionary = _horses[horse_id]
	var identity_before := {
		"template_id": str(horse.get("template_id", "")),
		"name": str(horse.get("name", "")),
		"coat_name": str(horse.get("coat_name", "")),
		"coat_color": str(horse.get("coat_color", "")),
		"stable_slot_id": str(horse.get("stable_slot_id", "")),
	}
	var previous_natural_max_hp := _calculate_natural_max_hp(float(horse.get("growth", 0.0)))
	var hp_ratio := clampf(float(horse.get("hp", 0.0)) / maxf(1.0, previous_natural_max_hp + float(horse.get("care_bonus_hp", 0.0))), 0.0, 1.0)
	horse["growth"] = clampf(growth, 0.0, 1.0)
	_normalize_horse_runtime(horse)
	horse["hp"] = hp_ratio * (float(_calculate_natural_max_hp(float(horse.get("growth", 0.0)))) + float(horse.get("care_bonus_hp", 0.0)))
	for key in identity_before.keys():
		horse[key] = identity_before[key]
	_horses[horse_id] = horse
	_emit_horse_state_changed(horse_id)
	_publish_stable_summary()
	return {"ok": true, "horse_id": horse_id, "horse": get_horse_snapshot(horse_id)}


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
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system != null and npc_system.has_method("get_npc_state") else {}
	if bool(state.get("unconscious", false)) or str(state.get("behavior_mode", "")) == BEHAVIOR_MODE_UNCONSCIOUS:
		_begin_return_to_stable(horse_id, true, "rider_unconscious")
		return
	var invalid_reason := _get_npc_assignment_ineligibility_reason(npc_id)
	if not invalid_reason.is_empty():
		_begin_return_to_stable(horse_id, true, invalid_reason)
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
		if not bool(horse.get("alive", true)):
			continue
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
	# A living horse keeps its assigned physical stall even while away or ridden.
	# Full capacity pauses both probability growth and birth rolls.
	if not _get_birth_block_reason().is_empty():
		return
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
	var should_mount := (
		[BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(behavior_mode)
		and not bool(states.get("unconscious", false))
		and not bool(states.get("escaped", false))
	)
	var horse: Dictionary = _horses[horse_id]
	if not bool(horse.get("alive", true)):
		return
	var location := str(horse.get("location", LOCATION_STABLE))
	var movement: Dictionary = horse.get("movement_state", {}) if horse.get("movement_state", {}) is Dictionary else {}
	var movement_phase := str(movement.get("phase", "idle"))
	if should_mount:
		if location == LOCATION_RIDDEN and str(horse.get("ridden_by_npc_id", "")) == npc_id:
			if not bool(states.get("combat_mounted", false)) and npc_system.has_method("update_npc_state"):
				npc_system.update_npc_state(npc_id, {"combat_mounted": true, "combat_mount_phase": "mounted"})
			return
		if _is_mount_pickup_waiting_phase(movement_phase):
			ensure_wartime_mount_route(npc_id, "npc_state_reconciled")
			return
		if location == LOCATION_RETURNING_STABLE:
			_start_return_path_mount_rendezvous(horse_id, npc_id)
			return
		elif location == LOCATION_STABLE:
			_start_mount_rendezvous(horse_id, npc_id)
		return
	if [LOCATION_RIDDEN, LOCATION_APPROACHING_RIDER].has(location) or _is_mount_pickup_waiting_phase(movement_phase):
		_begin_return_to_stable(horse_id, false, "wartime_ended")


func ensure_wartime_mount_route(npc_id: String, reason: String = "wartime_mount_route_recovery") -> Dictionary:
	var horse_id := _find_assigned_horse_id(npc_id)
	if horse_id.is_empty() or not _horses.has(horse_id):
		return {"ok": false, "reason": "no_assigned_horse", "npc_id": npc_id}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_state"):
		return {"ok": false, "reason": "npc_system_unavailable", "npc_id": npc_id, "horse_id": horse_id}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var behavior_mode := str(state.get("behavior_mode", "work"))
	if not [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(behavior_mode):
		return {"ok": false, "reason": "npc_not_in_wartime_mode", "npc_id": npc_id, "horse_id": horse_id}
	if bool(state.get("unconscious", false)) or bool(state.get("escaped", false)):
		return {"ok": false, "reason": "npc_unavailable", "npc_id": npc_id, "horse_id": horse_id}
	var horse: Dictionary = _horses[horse_id]
	if not bool(horse.get("alive", true)):
		return {"ok": false, "reason": "horse_dead", "npc_id": npc_id, "horse_id": horse_id}
	var location := str(horse.get("location", LOCATION_STABLE))
	if location == LOCATION_RIDDEN and str(horse.get("ridden_by_npc_id", "")) == npc_id:
		return {"ok": true, "reason": "already_mounted", "npc_id": npc_id, "horse_id": horse_id}
	var movement: Dictionary = horse.get("movement_state", {}) if horse.get("movement_state", {}) is Dictionary else {}
	var phase := str(movement.get("phase", "idle"))
	if not _is_mount_pickup_waiting_phase(phase):
		if location == LOCATION_RETURNING_STABLE:
			return _start_return_path_mount_rendezvous(horse_id, npc_id)
		if location == LOCATION_STABLE:
			return _start_mount_rendezvous(horse_id, npc_id)
		return {"ok": false, "reason": "horse_not_ready_for_pickup", "npc_id": npc_id, "horse_id": horse_id, "horse_location": location}

	var pickup_position: Vector3 = movement.get("target_position", horse.get("world_position", Vector3.ZERO))
	var raw_npc_position: Variant = npc_system.get_npc_world_position(npc_id) if npc_system.has_method("get_npc_world_position") else null
	if raw_npc_position is Vector3 and (raw_npc_position as Vector3).distance_to(pickup_position) <= _balance_float("mount_rendezvous_arrival_distance") + 0.15:
		_complete_mount_rendezvous(horse_id)
		return {"ok": true, "completed": true, "reason": "rider_already_at_pickup", "npc_id": npc_id, "horse_id": horse_id}
	var rider_route_active := (
		npc_system.has_method("is_npc_world_movement_active")
		and bool(npc_system.is_npc_world_movement_active(npc_id))
		and str(state.get("movement_target", "")) == STABLE_BUILDING_ID
	)
	if rider_route_active:
		return {"ok": true, "already_active": true, "reason": "rider_route_active", "npc_id": npc_id, "horse_id": horse_id}
	var now_msec := Time.get_ticks_msec()
	if now_msec < int(movement.get("rider_route_recovery_next_msec", 0)):
		return {"ok": false, "reason": "rider_route_recovery_cooldown", "npc_id": npc_id, "horse_id": horse_id}

	var returning_pickup := phase == RETURN_PATH_PICKUP_WAITING_PHASE
	movement["rider_route_recovery_count"] = int(movement.get("rider_route_recovery_count", 0)) + 1
	movement["last_rider_route_recovery_reason"] = reason
	# A successful request can still be cancelled later in the same frame by the
	# formal-world migration tail. Let the next watchdog frame retry immediately;
	# throttle only requests that genuinely failed to start.
	movement["rider_route_recovery_next_msec"] = 0
	horse["movement_state"] = movement
	_horses[horse_id] = horse
	var moved := false
	if npc_system.has_method("move_npc_to_world_position"):
		moved = bool(npc_system.move_npc_to_world_position(
			npc_id,
			STABLE_BUILDING_ID,
			"前往途中马匹" if returning_pickup else "前往马厩取马",
			pickup_position,
			{
				"current_action": "waiting_for_assigned_horse",
				"last_action_result": "rider_arrived_at_returning_horse" if returning_pickup else "rider_arrived_at_stable_horse",
				"combat_mounted": false,
				"combat_mount_phase": "beside_returning_horse" if returning_pickup else "beside_stable_horse",
				"preserve_location_context": true,
				"departure_state": {
					"combat_mounted": false,
					"combat_mount_phase": "going_to_returning_horse" if returning_pickup else "going_to_stable_horse",
					"last_action_result": reason
				}
			}
		))
	movement = (_horses[horse_id] as Dictionary).get("movement_state", {})
	movement["last_rider_route_recovery_ok"] = moved
	movement["rider_route_recovery_next_msec"] = 0 if moved else now_msec + RIDER_ROUTE_RECOVERY_RETRY_MSEC
	var latest_horse: Dictionary = _horses[horse_id]
	latest_horse["movement_state"] = movement
	_horses[horse_id] = latest_horse
	return {
		"ok": moved,
		"recovered": moved,
		"reason": reason if moved else "npc_rendezvous_move_failed",
		"npc_id": npc_id,
		"horse_id": horse_id,
		"pickup_position": pickup_position,
		"pickup_source": str(movement.get("pickup_source", "")),
		"recovery_count": int(movement.get("rider_route_recovery_count", 0))
	}


func _start_mount_rendezvous(horse_id: String, npc_id: String) -> Dictionary:
	if not _horses.has(horse_id):
		return {"ok": false, "reason": "unknown_horse", "horse_id": horse_id}
	var horse: Dictionary = _horses[horse_id]
	_release_horse_motion_actor(horse_id, "stable_mount_rendezvous")
	if not bool(horse.get("alive", true)):
		return {"ok": false, "reason": "horse_dead", "horse_id": horse_id}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_world_position"):
		return {"ok": false, "reason": "npc_system_unavailable", "horse_id": horse_id, "npc_id": npc_id}
	var raw_npc_position: Variant = npc_system.get_npc_world_position(npc_id)
	if not raw_npc_position is Vector3:
		return {"ok": false, "reason": "npc_position_unavailable", "horse_id": horse_id, "npc_id": npc_id}
	var npc_position: Vector3 = raw_npc_position
	var horse_position := _resolve_horse_world_position(horse_id, horse)
	var stable_position: Vector3 = horse.get("stable_world_position", horse_position)
	if str(horse.get("location", LOCATION_STABLE)) == LOCATION_STABLE or stable_position == Vector3.ZERO:
		stable_position = horse_position
	# The horse remains at its actual stable anchor. Only the rider moves, toward
	# that slot's configured open-side pickup point. Never snap from the horse
	# center itself: its nearest NavMesh point can lie across a stall partition.
	var raw_configured_pickup_position: Variant = _resolve_horse_pickup_world_position(horse_id)
	if not raw_configured_pickup_position is Vector3:
		return {"ok": false, "reason": "stable_pickup_anchor_unavailable", "horse_id": horse_id, "npc_id": npc_id}
	var configured_pickup_position: Vector3 = raw_configured_pickup_position
	var rendezvous_result := _resolve_navigable_rendezvous_position(npc_position, configured_pickup_position)
	if not bool(rendezvous_result.get("ok", false)):
		return {
			"ok": false,
			"reason": str(rendezvous_result.get("reason", "npc_rendezvous_path_unreachable")),
			"horse_id": horse_id,
			"npc_id": npc_id,
			"horse_position": horse_position,
			"configured_pickup_position": configured_pickup_position
		}
	var rendezvous: Vector3 = rendezvous_result.get("position", configured_pickup_position)
	horse["stable_world_position"] = stable_position
	horse["world_position"] = horse_position
	horse["location"] = LOCATION_STABLE
	horse["ridden_by_npc_id"] = ""
	horse["feeding"] = _make_idle_feeding_state()
	horse["movement_state"] = {
		"phase": MOUNT_PICKUP_WAITING_PHASE,
		"npc_id": npc_id,
		"target_position": rendezvous,
		"started_position": horse_position,
		"horse_stationary": true,
		"pickup_source": "stable_slot_open_side",
		"navigation_path_point_count": int(rendezvous_result.get("path_point_count", 0)),
		"pickup_policy": "rider_navigates_to_assigned_horse_at_stable",
		"reason": "wartime_started"
	}
	_horses[horse_id] = horse
	_emit_horse_state_changed(horse_id)
	_publish_stable_summary()
	if npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, {
			"combat_mounted": false,
			"combat_mount_phase": "going_to_stable_horse",
			"current_action": "meeting_assigned_horse",
			"last_action_result": "stable_horse_pickup_started"
		})
	if npc_system.has_method("move_npc_to_world_position"):
		# Use the real stable location id so notice/memory projections can resolve
		# the movement target without treating a synthetic horse id as a building.
		var target_id := STABLE_BUILDING_ID
		var moved: bool = npc_system.move_npc_to_world_position(npc_id, target_id, "前往马厩取马", rendezvous, {
			"current_action": "waiting_for_assigned_horse",
			"last_action_result": "rider_arrived_at_stable_horse",
			"combat_mounted": false,
			"combat_mount_phase": "beside_stable_horse",
			"preserve_location_context": true
		})
		if not moved:
			return {"ok": false, "reason": "npc_rendezvous_move_failed", "horse_id": horse_id, "npc_id": npc_id}
	return {
		"ok": true,
		"horse_id": horse_id,
		"npc_id": npc_id,
		"horse_start_position": horse_position,
		"npc_start_position": npc_position,
		"rendezvous_position": rendezvous,
		"horse_stationary": true,
		"pickup_source": "stable_slot_open_side",
		"navigation_path_point_count": int(rendezvous_result.get("path_point_count", 0)),
		"pickup_policy": "rider_navigates_to_assigned_horse_at_stable"
	}


func _start_return_path_mount_rendezvous(horse_id: String, npc_id: String) -> Dictionary:
	if not _horses.has(horse_id):
		return {"ok": false, "reason": "unknown_horse", "horse_id": horse_id}
	var horse: Dictionary = _horses[horse_id]
	if not bool(horse.get("alive", true)):
		return {"ok": false, "reason": "horse_dead", "horse_id": horse_id}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_world_position"):
		return {"ok": false, "reason": "npc_system_unavailable", "horse_id": horse_id, "npc_id": npc_id}
	var raw_npc_position: Variant = npc_system.get_npc_world_position(npc_id)
	if not raw_npc_position is Vector3:
		return {"ok": false, "reason": "npc_position_unavailable", "horse_id": horse_id, "npc_id": npc_id}
	var npc_position: Vector3 = raw_npc_position
	var horse_position := _get_current_horse_motion_position(horse_id, horse)
	var rendezvous_result := _resolve_return_path_pickup_position(npc_position, horse_position)
	if not bool(rendezvous_result.get("ok", false)):
		return {
			"ok": false,
			"reason": str(rendezvous_result.get("reason", "return_path_pickup_unreachable")),
			"horse_id": horse_id,
			"npc_id": npc_id,
			"horse_position": horse_position
		}
	var rendezvous: Vector3 = rendezvous_result.get("position", horse_position)
	var previous_movement: Dictionary = horse.get("movement_state", {}) if horse.get("movement_state", {}) is Dictionary else {}
	_cancel_horse_motion_actor(horse_id, "wartime_restarted_wait_for_rider")
	horse["world_position"] = horse_position
	horse["location"] = LOCATION_RETURNING_STABLE
	horse["ridden_by_npc_id"] = ""
	horse["movement_state"] = {
		"phase": RETURN_PATH_PICKUP_WAITING_PHASE,
		"npc_id": npc_id,
		"target_position": rendezvous,
		"started_position": horse_position,
		"return_target_position": previous_movement.get("target_position", horse.get("stable_world_position", Vector3.ZERO)),
		"horse_stationary": true,
		"pickup_source": "return_path_current_position",
		"navigation_path_point_count": int(rendezvous_result.get("path_point_count", 0)),
		"pickup_policy": "horse_stops_and_rider_navigates_to_return_path_position",
		"reason": "wartime_restarted_during_return"
	}
	_horses[horse_id] = horse
	_emit_horse_state_changed(horse_id)
	_publish_stable_summary()
	if npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, {
			"combat_mounted": false,
			"combat_mount_phase": "going_to_returning_horse",
			"current_action": "meeting_assigned_horse",
			"last_action_result": "returning_horse_stopped_for_pickup"
		})
	if npc_system.has_method("move_npc_to_world_position"):
		# Keep the information-space target on a real location id; the supplied
		# world point remains the stopped horse beside the rider's return route.
		var target_id := STABLE_BUILDING_ID
		var moved: bool = npc_system.move_npc_to_world_position(npc_id, target_id, "前往途中马匹", rendezvous, {
			"current_action": "waiting_for_assigned_horse",
			"last_action_result": "rider_arrived_at_returning_horse",
			"combat_mounted": false,
			"combat_mount_phase": "beside_returning_horse",
			"preserve_location_context": true
		})
		if not moved:
			return {"ok": false, "reason": "npc_rendezvous_move_failed", "horse_id": horse_id, "npc_id": npc_id}
	return {
		"ok": true,
		"horse_id": horse_id,
		"npc_id": npc_id,
		"horse_start_position": horse_position,
		"npc_start_position": npc_position,
		"rendezvous_position": rendezvous,
		"horse_stationary": true,
		"pickup_source": "return_path_current_position",
		"navigation_path_point_count": int(rendezvous_result.get("path_point_count", 0)),
		"pickup_policy": "horse_stops_and_rider_navigates_to_return_path_position"
	}


func _advance_horse_world_transitions(_delta: float) -> void:
	for horse_id in _horse_order:
		if not _horses.has(horse_id):
			continue
		var horse: Dictionary = _horses[horse_id]
		if not bool(horse.get("alive", true)):
			continue
		var movement: Dictionary = horse.get("movement_state", {}) if horse.get("movement_state", {}) is Dictionary else {}
		var phase := str(movement.get("phase", "idle"))
		if not (_is_mount_pickup_waiting_phase(phase) or phase in [LOCATION_APPROACHING_RIDER, LOCATION_RETURNING_STABLE]):
			continue
		if _is_mount_pickup_waiting_phase(phase):
			var npc_id := str(movement.get("npc_id", horse.get("assigned_npc_id", "")))
			var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
			var raw_npc_position: Variant = npc_system.get_npc_world_position(npc_id) if npc_system != null and npc_system.has_method("get_npc_world_position") else null
			var pickup_position: Vector3 = movement.get("target_position", horse.get("world_position", Vector3.ZERO))
			if raw_npc_position is Vector3 and (raw_npc_position as Vector3).distance_to(pickup_position) <= _balance_float("mount_rendezvous_arrival_distance") + 0.15:
				_complete_mount_rendezvous(horse_id)
			else:
				ensure_wartime_mount_route(npc_id, "horse_pickup_watchdog")
			continue
		var current: Vector3 = _get_current_horse_motion_position(horse_id, horse)
		var target: Vector3 = movement.get("target_position", current)
		var speed_key := "mount_rendezvous_horse_speed" if phase == LOCATION_APPROACHING_RIDER else "return_to_stable_speed"
		var actor := _get_horse_motion_actor(horse_id)
		if actor == null:
			actor = _request_horse_navigation(
				horse_id,
				current,
				target,
				_balance_float(speed_key),
				"horse_mount_rendezvous" if phase == LOCATION_APPROACHING_RIDER else "horse_return_to_stable"
			)
		if actor == null:
			continue
		current = actor.global_position
		horse["world_position"] = current
		var motion_snapshot := actor.debug_get_motion_snapshot()
		movement["navigation_authority"] = "ActorMotionBody"
		movement["navigation_state"] = str(motion_snapshot.get("state", "pending"))
		movement["navigation_request_id"] = str(motion_snapshot.get("request_id", ""))
		movement["navigation_path_plan_mode"] = str(motion_snapshot.get("path_plan_mode", "pending"))
		movement["navigation_maximum_observed_speed"] = float(motion_snapshot.get("maximum_observed_speed", 0.0))
		movement["navigation_maximum_frame_displacement"] = float(motion_snapshot.get("maximum_frame_displacement", 0.0))
		movement["velocity"] = motion_snapshot.get("velocity", Vector3.ZERO)
		horse["movement_state"] = movement
		_horses[horse_id] = horse
		var navigation_state := str(motion_snapshot.get("state", ""))
		if navigation_state == "failed":
			movement["navigation_failure_reason"] = str(motion_snapshot.get("last_result", "navigation_failed"))
			horse["movement_state"] = movement
			_horses[horse_id] = horse
			continue
		if navigation_state != "arrived":
			continue
		if phase == LOCATION_APPROACHING_RIDER:
			var npc_id := str(movement.get("npc_id", horse.get("assigned_npc_id", "")))
			var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
			var raw_npc_position: Variant = npc_system.get_npc_world_position(npc_id) if npc_system != null and npc_system.has_method("get_npc_world_position") else null
			if raw_npc_position is Vector3 and (raw_npc_position as Vector3).distance_to(target) <= _balance_float("mount_rendezvous_arrival_distance") + 0.15:
				_complete_mount_rendezvous(horse_id)
		else:
			_complete_return_to_stable(horse_id)


func _complete_mount_rendezvous(horse_id: String) -> void:
	if not _horses.has(horse_id):
		return
	var horse: Dictionary = _horses[horse_id]
	var npc_id := str(horse.get("assigned_npc_id", ""))
	if npc_id.is_empty() or not bool(horse.get("alive", true)):
		_begin_return_to_stable(horse_id, false, "mount_rendezvous_invalid")
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system != null and npc_system.has_method("get_npc_state") else {}
	if not [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(str(state.get("behavior_mode", ""))) or bool(state.get("unconscious", false)):
		_begin_return_to_stable(horse_id, false, "mount_rendezvous_cancelled")
		return
	_release_horse_motion_actor(horse_id, "horse_mounted")
	horse["location"] = LOCATION_RIDDEN
	horse["ridden_by_npc_id"] = npc_id
	horse["movement_state"] = _make_idle_movement_state()
	var raw_npc_position: Variant = npc_system.get_npc_world_position(npc_id) if npc_system != null and npc_system.has_method("get_npc_world_position") else null
	if raw_npc_position is Vector3:
		horse["world_position"] = raw_npc_position
	_horses[horse_id] = horse
	# The horse can enter the meeting tolerance just before ActorMotionBody emits
	# its own arrival. Stop and clear that request so its waiting state cannot
	# overwrite the mounted combat state on the following physics frame.
	if npc_system != null and npc_system.has_method("stop_npc_movement_with_state"):
		npc_system.stop_npc_movement_with_state(npc_id, {
			"movement_target": "",
			"movement_target_name": ""
		})
	if npc_system != null and npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, {
			"combat_mounted": true,
			"combat_mount_phase": "mounted",
			"current_action": "combat_ready" if str(state.get("behavior_mode", "")) == BEHAVIOR_MODE_COMBAT else "rallying_defense_line",
			"last_action_result": "horse_rendezvous_completed",
			"movement_target": "",
			"movement_target_name": ""
		})
	_emit_horse_state_changed(horse_id)
	_publish_stable_summary()
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system != null and combat_system.has_method("handle_npc_mount_ready"):
		combat_system.handle_npc_mount_ready(npc_id, horse_id)


func _begin_return_to_stable(horse_id: String, clear_assignment: bool, reason: String) -> Dictionary:
	if not _horses.has(horse_id):
		return {"ok": false, "reason": "unknown_horse", "horse_id": horse_id}
	var horse: Dictionary = _horses[horse_id]
	if not bool(horse.get("alive", true)):
		return {"ok": false, "reason": "horse_dead", "horse_id": horse_id}
	var npc_id := str(horse.get("assigned_npc_id", ""))
	var current := _get_current_horse_motion_position(horse_id, horse)
	var stable_target: Vector3 = horse.get("stable_world_position", Vector3.ZERO)
	if stable_target == Vector3.ZERO:
		stable_target = _resolve_stable_world_position(horse_id, current)
	var was_already_stable := str(horse.get("location", LOCATION_STABLE)) == LOCATION_STABLE
	if clear_assignment and not npc_id.is_empty():
		_clear_equipment_mount_projection(npc_id, reason, false)
		horse["assigned_npc_id"] = ""
		_emit_horse_assignment_changed(horse_id, "")
	if was_already_stable:
		_release_horse_motion_actor(horse_id, "stable_horse_return_not_needed")
		horse["ridden_by_npc_id"] = ""
		horse["location"] = LOCATION_STABLE
		horse["world_position"] = stable_target
		horse["stable_world_position"] = stable_target
		horse["feeding"] = _make_idle_feeding_state()
		horse["movement_state"] = _make_idle_movement_state()
		_horses[horse_id] = horse
		var stable_npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if not npc_id.is_empty() and stable_npc_system != null and stable_npc_system.has_method("update_npc_state"):
			stable_npc_system.update_npc_state(npc_id, {
				"combat_mounted": false,
				"combat_mount_phase": "horse_released" if clear_assignment else "unmounted",
				"last_action_result": reason
			})
		_emit_horse_state_changed(horse_id)
		_publish_stable_summary()
		return {
			"ok": true,
			"horse_id": horse_id,
			"npc_id": npc_id,
			"clear_assignment": clear_assignment,
			"reason": reason,
			"navigation_started": false,
			"already_stable": true
		}
	var navigation_target := stable_target
	var raw_stable_pickup: Variant = _resolve_horse_pickup_world_position(horse_id)
	if raw_stable_pickup is Vector3:
		var return_target_result := _resolve_navigable_rendezvous_position(current, raw_stable_pickup)
		if bool(return_target_result.get("ok", false)):
			navigation_target = return_target_result.get("position", raw_stable_pickup)
	horse["ridden_by_npc_id"] = ""
	horse["location"] = LOCATION_RETURNING_STABLE
	horse["world_position"] = current
	horse["stable_world_position"] = stable_target
	horse["feeding"] = _make_idle_feeding_state()
	horse["movement_state"] = {
		"phase": LOCATION_RETURNING_STABLE,
		"target_position": navigation_target,
		"stable_slot_position": stable_target,
		"started_position": current,
		"reason": reason,
		"assignment_retained": not clear_assignment,
		"locomotion_mode": "walk",
		"navigation_authority": "ActorMotionBody"
	}
	_horses[horse_id] = horse
	var actor := _request_horse_navigation(
		horse_id,
		current,
		navigation_target,
		_balance_float("return_to_stable_speed"),
		"horse_return_to_stable"
	)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if not npc_id.is_empty() and npc_system != null and npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, {
			"combat_mounted": false,
			"combat_mount_phase": "horse_returning" if not clear_assignment else "horse_released",
			"last_action_result": reason
		})
	_emit_horse_state_changed(horse_id)
	_publish_stable_summary()
	if current.distance_to(navigation_target) <= _balance_float("mount_rendezvous_arrival_distance"):
		_complete_return_to_stable(horse_id)
	return {
		"ok": actor != null,
		"horse_id": horse_id,
		"npc_id": npc_id,
		"clear_assignment": clear_assignment,
		"reason": reason,
		"navigation_started": actor != null,
		"navigation_target": navigation_target,
		"stable_slot_position": stable_target
	}


func _complete_return_to_stable(horse_id: String) -> void:
	if not _horses.has(horse_id):
		return
	var horse: Dictionary = _horses[horse_id]
	if not bool(horse.get("alive", true)):
		return
	_release_horse_motion_actor(horse_id, "horse_arrived_at_stable")
	horse["location"] = LOCATION_STABLE
	horse["ridden_by_npc_id"] = ""
	horse["world_position"] = horse.get("stable_world_position", horse.get("world_position", Vector3.ZERO))
	horse["movement_state"] = _make_idle_movement_state()
	_horses[horse_id] = horse
	_emit_horse_state_changed(horse_id)
	_publish_stable_summary()
	if not str(horse.get("assigned_npc_id", "")).is_empty():
		_reconcile_npc_riding_state(str(horse.get("assigned_npc_id", "")))


func get_horse_motion_snapshot(horse_id: String) -> Dictionary:
	var actor := _get_horse_motion_actor(horse_id)
	if actor == null:
		return {}
	var snapshot := actor.debug_get_motion_snapshot()
	snapshot["horse_id"] = horse_id
	snapshot["movement_authority"] = "ActorMotionBody"
	return snapshot


func _request_horse_navigation(
	horse_id: String,
	start_position: Vector3,
	target_position: Vector3,
	speed: float,
	movement_purpose: String
) -> ActorMotionBody:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null or not controller.has_method("get_production_navigation_map_rid"):
		push_error("Horse navigation requires StationLayoutController for %s." % horse_id)
		return null
	if controller.has_method("force_sync_production_navigation"):
		controller.force_sync_production_navigation()
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not navigation_map.is_valid():
		push_error("Horse navigation map is unavailable for %s." % horse_id)
		return null
	var actor := _get_horse_motion_actor(horse_id)
	if actor == null:
		actor = ACTOR_MOTION_SCENE.instantiate() as ActorMotionBody
		actor.name = "HorseMotion_%s" % horse_id
		actor.set_meta("horse_id", horse_id)
		actor.set_meta("horse_motion_authority", true)
		add_child(actor)
		_horse_motion_actors[horse_id] = actor
		var mesh := actor.get_node_or_null("ActorMesh") as MeshInstance3D
		if mesh != null:
			mesh.visible = false
		var label := actor.get_node_or_null("DebugLabel") as Label3D
		if label != null:
			label.visible = false
		var interaction_area := actor.get_interaction_area()
		if interaction_area != null:
			interaction_area.input_ray_pickable = false
			interaction_area.collision_layer = 0
	actor.global_position = start_position
	actor.configure_profile("horse", {
		"profile": {"base_speed": maxf(0.1, speed)}
	})
	# A ridden horse and its rider share one physical origin until the dismount
	# frame. Let the horse body collide authoritatively with world geometry while
	# RVO handles actors, otherwise CharacterBody depenetration ejects the newly
	# separated horse almost a metre and looks like a teleport.
	actor.collision_mask &= ~actor.collision_layer
	actor.configure_avoidance_identity("horse:%s" % horse_id, 0.48, 0.04)
	if not actor.set_navigation_map(navigation_map):
		_release_horse_motion_actor(horse_id, "horse_navigation_map_rejected")
		return null
	var request_id := "%s:%s:%d" % [movement_purpose, horse_id, Time.get_ticks_msec()]
	if not actor.request_motion(target_position, request_id, {
		"persistent_repath": true,
		"movement_purpose": movement_purpose,
		"target_desired_distance": _balance_float("mount_rendezvous_arrival_distance")
	}):
		_release_horse_motion_actor(horse_id, "horse_navigation_request_rejected")
		return null
	actor.set_motion_paused(_is_gameplay_paused())
	return actor


func _get_horse_motion_actor(horse_id: String) -> ActorMotionBody:
	var raw_actor: Variant = _horse_motion_actors.get(horse_id)
	if raw_actor is ActorMotionBody and is_instance_valid(raw_actor):
		return raw_actor as ActorMotionBody
	_horse_motion_actors.erase(horse_id)
	return null


func _get_current_horse_motion_position(horse_id: String, horse: Dictionary) -> Vector3:
	var actor := _get_horse_motion_actor(horse_id)
	if actor != null:
		return actor.global_position
	return _resolve_horse_world_position(horse_id, horse)


func _cancel_horse_motion_actor(horse_id: String, reason: String) -> void:
	var actor := _get_horse_motion_actor(horse_id)
	if actor == null:
		return
	if actor.is_motion_active():
		actor.cancel_motion(reason)
	actor.set_motion_paused(true)


func _release_horse_motion_actor(horse_id: String, reason: String) -> void:
	var actor := _get_horse_motion_actor(horse_id)
	_horse_motion_actors.erase(horse_id)
	if actor == null:
		return
	if actor.is_motion_active():
		actor.cancel_motion(reason)
	actor.collision_layer = 0
	actor.collision_mask = 0
	var navigation_agent := actor.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if navigation_agent != null:
		navigation_agent.avoidance_enabled = false
	actor.queue_free()


func _clear_all_horse_motion_actors(reason: String) -> void:
	for raw_horse_id in _horse_motion_actors.keys():
		_release_horse_motion_actor(str(raw_horse_id), reason)
	_horse_motion_actors.clear()


func _set_horse_motion_paused(paused: bool) -> void:
	for raw_horse_id in _horse_motion_actors.keys():
		var actor := _get_horse_motion_actor(str(raw_horse_id))
		if actor != null and actor.is_motion_active():
			actor.set_motion_paused(paused)


func _is_mount_pickup_waiting_phase(phase: String) -> bool:
	return phase in [MOUNT_PICKUP_WAITING_PHASE, RETURN_PATH_PICKUP_WAITING_PHASE]


func _resolve_return_path_pickup_position(npc_position: Vector3, horse_position: Vector3) -> Dictionary:
	var to_npc := npc_position - horse_position
	to_npc.y = 0.0
	if to_npc.length() <= RETURN_PATH_PICKUP_SEPARATION:
		var immediate_result := _resolve_navigable_rendezvous_position(npc_position, npc_position)
		if bool(immediate_result.get("ok", false)):
			immediate_result["immediate_pickup"] = true
			return immediate_result
	var base_direction := to_npc.normalized() if to_npc.length_squared() > 0.0001 else Vector3.RIGHT
	for angle_degrees in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
		var direction_2d := Vector2(base_direction.x, base_direction.z).rotated(deg_to_rad(angle_degrees))
		var desired := horse_position + Vector3(direction_2d.x, 0.0, direction_2d.y) * RETURN_PATH_PICKUP_SEPARATION
		var result := _resolve_navigable_rendezvous_position(npc_position, desired)
		if not bool(result.get("ok", false)):
			continue
		var resolved_position: Vector3 = result.get("position", desired)
		if Vector2(resolved_position.x - horse_position.x, resolved_position.z - horse_position.z).length() < 0.9:
			continue
		result["pickup_angle_degrees"] = angle_degrees
		return result
	return {"ok": false, "reason": "return_path_pickup_unreachable"}


func _resolve_horse_world_position(horse_id: String, horse: Dictionary) -> Vector3:
	if str(horse.get("location", LOCATION_STABLE)) == LOCATION_RIDDEN:
		var rider_npc_id := str(horse.get("ridden_by_npc_id", horse.get("assigned_npc_id", "")))
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		var raw_rider_position: Variant = (
			npc_system.get_npc_world_position(rider_npc_id)
			if not rider_npc_id.is_empty() and npc_system != null and npc_system.has_method("get_npc_world_position")
			else null
		)
		if raw_rider_position is Vector3:
			return raw_rider_position
	var stored: Variant = horse.get("world_position", null)
	if stored is Vector3:
		return stored
	return _resolve_stable_world_position(horse_id, Vector3.ZERO)


func _resolve_navigable_rendezvous_position(npc_position: Vector3, desired_position: Vector3) -> Dictionary:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null or not controller.has_method("get_production_navigation_map_rid"):
		return {"ok": false, "reason": "formal_navigation_controller_missing"}
	if controller.has_method("force_sync_production_navigation"):
		controller.force_sync_production_navigation()
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_navigation_map_missing"}
	var snapped_start := NavigationServer3D.map_get_closest_point(navigation_map, npc_position)
	var snapped_position := NavigationServer3D.map_get_closest_point(navigation_map, desired_position)
	var planar_snap_error := Vector2(
		snapped_position.x - desired_position.x,
		snapped_position.z - desired_position.z
	).length()
	if planar_snap_error > 1.0:
		return {"ok": false, "reason": "stable_pickup_point_off_navigation", "snap_error": planar_snap_error}
	var path := NavigationServer3D.map_get_path(navigation_map, snapped_start, snapped_position, true)
	if path.is_empty() and snapped_start.distance_to(snapped_position) > 0.5:
		return {"ok": false, "reason": "stable_pickup_path_unreachable", "snap_error": planar_snap_error}
	return {
		"ok": true,
		"position": snapped_position,
		"snap_error": planar_snap_error,
		"path_point_count": path.size()
	}


func _resolve_horse_pickup_world_position(horse_id: String) -> Variant:
	for raw_presenter in get_tree().get_nodes_in_group(HORSE_PRESENTATION_GROUP):
		var presenter := raw_presenter as Node
		if presenter != null and presenter.has_method("get_horse_pickup_world_position"):
			var raw_position: Variant = presenter.call("get_horse_pickup_world_position", horse_id)
			if raw_position is Vector3:
				return raw_position
	return null


func _resolve_stable_world_position(horse_id: String, fallback: Vector3) -> Vector3:
	for raw_presenter in get_tree().get_nodes_in_group(HORSE_PRESENTATION_GROUP):
		var presenter := raw_presenter as Node
		if presenter != null and presenter.has_method("get_horse_world_position"):
			var raw_position: Variant = presenter.call("get_horse_world_position", horse_id)
			if raw_position is Vector3:
				return raw_position
	return fallback


func _is_gameplay_paused() -> bool:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	return time_system != null and time_system.has_method("is_gameplay_paused") and bool(time_system.is_gameplay_paused())


func _handle_horse_death(horse_id: String, rider_npc_id: String, context: Dictionary) -> Dictionary:
	if not _horses.has(horse_id):
		return {}
	var horse: Dictionary = _horses[horse_id]
	_release_horse_motion_actor(horse_id, "horse_died")
	var assigned_npc_id := str(horse.get("assigned_npc_id", rider_npc_id))
	horse["alive"] = false
	horse["hp"] = 0.0
	horse["location"] = LOCATION_DEAD
	horse["assigned_npc_id"] = ""
	horse["ridden_by_npc_id"] = ""
	horse["feeding"] = _make_idle_feeding_state()
	horse["movement_state"] = _make_idle_movement_state()
	horse["stable_slot_id"] = ""
	_horses[horse_id] = horse
	var projection_result := {}
	if not assigned_npc_id.is_empty():
		projection_result = _clear_equipment_mount_projection(assigned_npc_id, "horse_died", false)
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system != null and npc_system.has_method("update_npc_state"):
			npc_system.update_npc_state(assigned_npc_id, {
				"combat_mounted": false,
				"combat_mount_phase": "horse_dead",
				"combat_charge_phase": "",
				"current_action": "combat_ready",
				"last_action_result": "assigned_horse_died"
			})
	_emit_horse_assignment_changed(horse_id, "")
	_publish_stable_summary()
	var event := _log_horse_damage_event(
		horse_id,
		assigned_npc_id,
		float(context.get("horse_damage", context.get("damage", 0.0))),
		float(context.get("horse_hp_before", 0.0)),
		0.0,
		true,
		context
	)
	return {
		"ok": true,
		"horse_id": horse_id,
		"npc_id": assigned_npc_id,
		"projection_result": projection_result,
		"event": event
	}


func _clear_equipment_mount_projection(npc_id: String, reason: String, record_event: bool) -> Dictionary:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("clear_npc_horse_mount"):
		return {"ok": false, "reason": "equipment_system_unavailable", "npc_id": npc_id}
	_assignment_mutation_depth += 1
	var raw_result: Variant = equipment_system.call(
		"clear_npc_horse_mount",
		npc_id,
		"local_public",
		reason,
		record_event,
		true
	)
	_assignment_mutation_depth -= 1
	return (raw_result as Dictionary).duplicate(true) if raw_result is Dictionary else {"ok": false, "reason": "equipment_sync_failed"}


func _log_horse_damage_event(
	horse_id: String,
	npc_id: String,
	damage: float,
	hp_before: float,
	hp_after: float,
	died: bool,
	context: Dictionary
) -> Dictionary:
	if npc_id.is_empty():
		return {}
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var horse: Dictionary = _horses.get(horse_id, {})
	var actor_id := str(context.get("enemy_id", context.get("actor_id", "system")))
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system != null and npc_system.has_method("get_npc_state") else {}
	return memory_system.add_event({
		"type": "horse_died" if died else "horse_damaged",
		"subject_npc_id": npc_id,
		"actor_ids": [actor_id],
		"target_ids": [npc_id, horse_id],
		"location_id": str(state.get("current_location", "plaza")),
		"visibility": "local_public",
		"importance": 90 if died else 65,
		"payload": {
			"target_npc_id": npc_id,
			"horse_id": horse_id,
			"horse_name": str(horse.get("name", horse_id)),
			"damage": damage,
			"hp_before": hp_before,
			"hp_after": hp_after,
			"share_ratio": float(context.get("share_ratio", 0.0)),
			"enemy_id": str(context.get("enemy_id", "")),
			"enemy_name": str(context.get("enemy_name", ""))
		}
	})


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


func _get_npc_manual_loadout_ineligibility_reason(npc_id: String) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_state"):
		return "npc_system_unavailable"
	var states: Dictionary = npc_system.get_npc_state(npc_id)
	if states.is_empty():
		return "unknown_npc"
	var behavior_mode := str(states.get("behavior_mode", BEHAVIOR_MODE_WORK))
	if behavior_mode != BEHAVIOR_MODE_WORK:
		return "loadout_locked_in_wartime"
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
	_last_birth_failure_reason = _get_birth_block_reason()
	if not _last_birth_failure_reason.is_empty():
		return ""
	var template_id := _find_next_unused_template_id()
	if template_id.is_empty():
		_last_birth_failure_reason = "horse_template_pool_exhausted"
		return ""
	var horse_id := ""
	while horse_id.is_empty() or _horses.has(horse_id):
		horse_id = "horse_foal_%03d" % _next_foal_serial
		_next_foal_serial += 1
	var horse := _make_horse_from_definition({
		"horse_id": horse_id,
		"template_id": template_id,
		"growth": 0.0,
	})
	if horse.is_empty():
		_last_birth_failure_reason = "birth_failed"
		return ""
	_horses[horse_id] = horse
	_horse_order.append(horse_id)
	_last_birth_failure_reason = ""
	return horse_id


func _make_horse_from_definition(definition: Dictionary) -> Dictionary:
	var horse_id := str(definition.get("horse_id", "")).strip_edges()
	if horse_id.is_empty():
		push_error("Skipped horse definition with empty horse_id.")
		return {}
	var template_id := str(definition.get("template_id", "")).strip_edges()
	if template_id.is_empty():
		template_id = _find_template_id_by_name(str(definition.get("name", "")))
	if template_id.is_empty():
		template_id = _find_next_unused_template_id()
	var template: Dictionary = get_horse_template_snapshot(template_id)
	if template.is_empty():
		push_error("Skipped horse %s because template is unavailable: %s" % [horse_id, template_id])
		return {}
	if _is_template_in_use(template_id, horse_id):
		push_error("Skipped horse %s because template is already used: %s" % [horse_id, template_id])
		return {}
	var stable_slot_id := str(definition.get("stable_slot_id", "")).strip_edges()
	if stable_slot_id.is_empty():
		stable_slot_id = _find_next_free_stable_slot_id()
	if stable_slot_id.is_empty() or not get_stable_slot_ids().has(stable_slot_id) or _is_stable_slot_in_use(stable_slot_id, horse_id):
		push_error("Skipped horse %s because no valid stable slot is available: %s" % [horse_id, stable_slot_id])
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
		"template_id": template_id,
		"name": str(template.get("name", horse_id)),
		"coat_name": str(template.get("coat_name", "未知毛色")),
		"coat_color": str(template.get("coat_color", "#9B6846")),
		"icon": str(template.get("icon", "")),
		"stable_slot_id": stable_slot_id,
		"alive": bool(definition.get("alive", true)),
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
		"movement_state": _make_idle_movement_state(),
	}
	_normalize_horse_runtime(horse)
	return horse


func _make_public_horse_snapshot(horse: Dictionary) -> Dictionary:
	var snapshot := horse.duplicate(true)
	var horse_id := str(horse.get("horse_id", ""))
	if not horse_id.is_empty():
		snapshot["world_position"] = _resolve_horse_world_position(horse_id, horse)
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
		bool(horse.get("alive", true))
		and float(horse.get("hp", 0.0)) - float(horse.get("care_bonus_hp", 0.0)) + 0.0001 < natural_max_hp
		and float(horse.get("satiety", 0.0)) > 0.0
	)
	snapshot["stable_capacity"] = get_stable_capacity()
	snapshot["stable_occupied_slots"] = _get_alive_horse_count()
	snapshot["stable_full"] = _is_stable_full()
	return snapshot


func _normalize_horse_runtime(horse: Dictionary) -> void:
	var alive := bool(horse.get("alive", float(horse.get("hp", 0.0)) > 0.0))
	horse["alive"] = alive
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
	if not [LOCATION_STABLE, LOCATION_APPROACHING_RIDER, LOCATION_RIDDEN, LOCATION_RETURNING_STABLE, LOCATION_DEAD].has(location):
		location = LOCATION_STABLE
	if not alive:
		location = LOCATION_DEAD
		horse["hp"] = 0.0
		horse["assigned_npc_id"] = ""
		horse["ridden_by_npc_id"] = ""
		horse["stable_slot_id"] = ""
	horse["location"] = location
	if location == LOCATION_STABLE:
		horse["ridden_by_npc_id"] = ""
	if not horse.get("feeding", {}) is Dictionary:
		horse["feeding"] = _make_idle_feeding_state()
	if not horse.get("movement_state", {}) is Dictionary:
		horse["movement_state"] = _make_idle_movement_state()


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


func _make_idle_movement_state() -> Dictionary:
	return {
		"phase": "idle",
		"target_position": Vector3.ZERO,
		"reason": ""
	}


func _load_stable_slots(raw_slots_by_level: Variant) -> void:
	if not raw_slots_by_level is Dictionary:
		push_error("Horse stable_slots_by_level must be a JSON object: %s" % HORSE_DEFS_FILE)
		return
	var previous_slots: Array[String] = []
	for level in range(1, 4):
		var level_key := str(level)
		var raw_slots: Variant = raw_slots_by_level.get(level_key, [])
		var slots: Array[String] = []
		if raw_slots is Array:
			for raw_slot_id in raw_slots:
				var slot_id := str(raw_slot_id).strip_edges()
				if not slot_id.is_empty() and not slots.has(slot_id):
					slots.append(slot_id)
		if slots.is_empty():
			push_error("Horse stable slot level %d must not be empty." % level)
			continue
		for previous_slot_id in previous_slots:
			if not slots.has(previous_slot_id):
				push_error("Horse stable slots must be monotonic; level %d removed %s." % [level, previous_slot_id])
		_stable_slots_by_level[level_key] = slots
		previous_slots = slots


func _load_horse_templates(raw_templates: Variant) -> void:
	if not raw_templates is Array:
		push_error("Horse horse_templates must be a JSON array: %s" % HORSE_DEFS_FILE)
		return
	var used_names := {}
	for raw_template in raw_templates:
		if not raw_template is Dictionary:
			continue
		var template: Dictionary = (raw_template as Dictionary).duplicate(true)
		var template_id := str(template.get("template_id", "")).strip_edges()
		var horse_name := str(template.get("name", "")).strip_edges()
		var coat_color := str(template.get("coat_color", "")).strip_edges()
		if template_id.is_empty() or horse_name.is_empty() or coat_color.is_empty():
			push_error("Skipped incomplete horse template: %s" % JSON.stringify(template))
			continue
		if _horse_templates.has(template_id) or used_names.has(horse_name):
			push_error("Skipped duplicate horse template id/name: %s / %s" % [template_id, horse_name])
			continue
		if not Color.html_is_valid(coat_color):
			push_error("Skipped horse template with invalid coat color: %s" % template_id)
			continue
		template["template_id"] = template_id
		template["name"] = horse_name
		template["coat_color"] = Color.from_string(coat_color, Color("#9B6846")).to_html()
		_horse_templates[template_id] = template
		_horse_template_order.append(template_id)
		used_names[horse_name] = true


func _get_current_stable_level() -> int:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and building_system.has_method("get_building"):
		var stable: Variant = building_system.call("get_building", STABLE_BUILDING_ID)
		if stable is Dictionary:
			return clampi(int((stable as Dictionary).get("level", 1)), 1, 3)
	return 1


func _get_alive_horse_count() -> int:
	var count := 0
	for horse_id in _horse_order:
		if bool((_horses.get(horse_id, {}) as Dictionary).get("alive", true)):
			count += 1
	return count


func _is_stable_full() -> bool:
	var capacity := get_stable_capacity()
	return capacity <= 0 or _get_alive_horse_count() >= capacity


func _get_birth_block_reason() -> String:
	if _is_stable_full():
		return "stable_full"
	if _find_next_unused_template_id().is_empty():
		return "horse_template_pool_exhausted"
	if _find_next_free_stable_slot_id().is_empty():
		return "stable_full"
	return ""


func _find_next_free_stable_slot_id() -> String:
	for slot_id in get_stable_slot_ids():
		if not _is_stable_slot_in_use(slot_id):
			return slot_id
	return ""


func _is_stable_slot_in_use(slot_id: String, except_horse_id: String = "") -> bool:
	for horse_id in _horse_order:
		if horse_id == except_horse_id:
			continue
		var horse: Dictionary = _horses.get(horse_id, {})
		if bool(horse.get("alive", true)) and str(horse.get("stable_slot_id", "")) == slot_id:
			return true
	return false


func _find_next_unused_template_id() -> String:
	for template_id in _horse_template_order:
		if not _is_template_in_use(template_id):
			return template_id
	return ""


func _is_template_in_use(template_id: String, except_horse_id: String = "") -> bool:
	for horse_id in _horse_order:
		if horse_id == except_horse_id:
			continue
		if str((_horses.get(horse_id, {}) as Dictionary).get("template_id", "")) == template_id:
			return true
	return false


func _find_template_id_by_name(horse_name: String) -> String:
	var clean_name := horse_name.strip_edges()
	if clean_name.is_empty():
		return ""
	for template_id in _horse_template_order:
		if str((_horse_templates.get(template_id, {}) as Dictionary).get("name", "")) == clean_name:
			return template_id
	return ""


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
		"mount_rendezvous_horse_speed",
		"mount_rendezvous_arrival_distance",
		"return_to_stable_speed",
	]:
		_balance[key] = maxf(0.0, float(_balance.get(key, DEFAULT_BALANCE[key])))
	_balance["feeding_duration_seconds"] = maxf(1.0, float(_balance["feeding_duration_seconds"]))
	_balance["base_full_growth_care_minutes"] = maxf(1.0, float(_balance["base_full_growth_care_minutes"]))
	_balance["feeding_grain_cost"] = maxi(0, int(_balance.get("feeding_grain_cost", 1)))
	_balance["mount_rendezvous_npc_share"] = clampf(float(_balance.get("mount_rendezvous_npc_share", 0.35)), 0.1, 0.9)
	_balance["mounted_damage_share_min"] = clampf(float(_balance.get("mounted_damage_share_min", 0.3)), 0.0, 1.0)
	_balance["mounted_damage_share_max"] = clampf(
		float(_balance.get("mounted_damage_share_max", 0.5)),
		float(_balance["mounted_damage_share_min"]),
		1.0
	)


func _balance_float(key: String) -> float:
	return float(_balance.get(key, DEFAULT_BALANCE.get(key, 0.0)))


func _balance_int(key: String) -> int:
	return int(_balance.get(key, DEFAULT_BALANCE.get(key, 0)))


func _publish_stable_summary(force: bool = false) -> void:
	var public_summary := get_stable_horse_summary()
	# BuildingSystem's stable special-state contract intentionally remains the
	# compact total/adult/foal projection. Slot occupancy stays HorseSystem-owned.
	var summary := {
		"total": int(public_summary.get("total", 0)),
		"adult": int(public_summary.get("adult", 0)),
		"foal": int(public_summary.get("foal", 0)),
	}
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
		"loadout_locked_in_wartime":
			return "只有工作模式下才能更换装备或马匹。"
		"no_available_horse":
			return "没有可分配的成年在厩马。"
		"unknown_horse":
			return "马匹不存在。"
		"horse_not_adult":
			return "幼马尚未成年，不能分配。"
		"horse_dead":
			return "阵亡马匹不能再被分配。"
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
