extends Node

const ENEMY_WAVES_FILE := "enemy_waves.json"
const ENEMY_ROOT_PATH := "/root/Main/WorldRoot/Station/Enemies"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DEFAULT_SPAWN_POINT_ID := "front_forest"
const DEFAULT_TARGET_PREFERENCE: Array[String] = ["front_gate", "wall", "warehouse", "main_hall", "nearby_unit"]
const NEARBY_UNIT_TARGET_ID := "nearby_unit"
const MAIN_HALL_ID := "main_hall"
const PLAZA_LOCATION_ID := "plaza"
const ENEMY_DAMAGE_VISIBILITY := "local_public"
const DEFAULT_NEARBY_UNIT_DETECTION_RANGE := 6.0
const RALLY_ENCOUNTER_RANGE := 5.0
const FRIENDLY_CONTACT_RANGE := 5.0
const RALLY_WAIT_TIMEOUT_SECONDS := 3600.0
const MOVE_SPEED_GAME_SECONDS_DIVISOR := 60.0
const MAX_ATTACKS_PER_AI_STEP := 100
const FAILURE_REASON_MAIN_HALL_DESTROYED := "main_hall_destroyed"
const RALLY_TARGET_PREFIX := "combat_rally_"
const AVOIDANCE_TARGET_PREFIX := "avoid_shelter_"
const RALLY_LOCATION_ID := "front_gate"
const RALLY_LOCATION_NAME := "城门外防线"
const AVOIDANCE_LOCATION_ID := PLAZA_LOCATION_ID
const AVOIDANCE_LOCATION_NAME := "驿站内避战点"
const RALLY_FRONT_Z := 16.2
const RALLY_BACK_Z := 14.2
const RALLY_COLUMN_SPACING := 2.1
const RALLY_ROW_SPACING := 1.25
const AVOIDANCE_REPATH_DISTANCE := 4.0
const VALID_UNIT_TYPES: Array[String] = [
	"melee_infantry",
	"polearm_infantry",
	"archer",
	"crossbowman",
	"cavalry",
	"mounted_ranged"
]
const BEHAVIOR_MODE_WORK := "work"
const BEHAVIOR_MODE_RALLY := "rally"
const BEHAVIOR_MODE_COMBAT := "combat"
const BEHAVIOR_MODE_AVOID_COMBAT := "avoid_combat"
const BEHAVIOR_MODE_UNCONSCIOUS := "unconscious"
const BEHAVIOR_MODE_ESCAPED := "escaped"

const FALLBACK_SPAWN_POINTS := {
	"front_gate": Vector3(0.0, 0.0, 24.0),
	"front_forest": Vector3(0.0, 0.0, 29.0)
}

var _waves: Array[Dictionary] = []
var _wave_by_number: Dictionary = {}
var _active_enemies: Dictionary = {}
var _enemy_nodes: Dictionary = {}
var _active_rallies: Dictionary = {}
var _active_avoidances: Dictionary = {}
var _spawn_sequence := 0
var _last_spawn_result: Dictionary = {}
var _last_ai_step_result: Dictionary = {}
var _last_failure_result: Dictionary = {}
var _last_alarm_result: Dictionary = {}
var _last_mode_transition_result: Dictionary = {}
var _last_avoidance_result: Dictionary = {}


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
		event_bus.logical_time_tick.connect(_on_logical_time_tick)
	if event_bus != null and event_bus.has_signal("npc_revived") and not event_bus.npc_revived.is_connected(_on_npc_revived):
		event_bus.npc_revived.connect(_on_npc_revived)
	if event_bus != null and event_bus.has_signal("npc_unconscious") and not event_bus.npc_unconscious.is_connected(_on_npc_unconscious):
		event_bus.npc_unconscious.connect(_on_npc_unconscious)


func initialize() -> void:
	_clear_spawned_enemy_nodes()
	_waves.clear()
	_wave_by_number.clear()
	_active_enemies.clear()
	_enemy_nodes.clear()
	_active_rallies.clear()
	_active_avoidances.clear()
	_spawn_sequence = 0
	_last_spawn_result.clear()
	_last_ai_step_result.clear()
	_last_failure_result.clear()
	_last_alarm_result.clear()
	_last_mode_transition_result.clear()
	_last_avoidance_result.clear()

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("CombatSystem requires ConfigLoader autoload.")
		return

	var loaded_waves: Variant = config_loader.load_data_file(ENEMY_WAVES_FILE, [])
	if not loaded_waves is Array:
		push_error("Enemy waves must be a JSON array: %s" % ENEMY_WAVES_FILE)
		return

	for raw_wave in loaded_waves:
		if not raw_wave is Dictionary:
			push_warning("Skipped invalid enemy wave entry.")
			continue
		var normalized := _normalize_wave(raw_wave)
		if normalized.is_empty():
			continue
		_waves.append(normalized)
		_wave_by_number[int(normalized.get("wave_number", 0))] = normalized

	_waves.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("wave_number", 0)) < int(right.get("wave_number", 0))
	)


func get_wave_count() -> int:
	return _waves.size()


func get_wave_numbers() -> Array[int]:
	var result: Array[int] = []
	for wave in _waves:
		result.append(int(wave.get("wave_number", 0)))
	return result


func get_wave_config(wave_number: int) -> Dictionary:
	return _wave_by_number.get(wave_number, {}).duplicate(true)


func get_all_wave_configs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wave in _waves:
		result.append(wave.duplicate(true))
	return result


func get_last_spawn_result() -> Dictionary:
	return _last_spawn_result.duplicate(true)


func get_active_enemy_ids() -> Array[String]:
	var ids: Array[String] = []
	for enemy_id in _active_enemies.keys():
		ids.append(str(enemy_id))
	ids.sort()
	return ids


func get_active_enemy_count() -> int:
	return _active_enemies.size()


func get_enemy(enemy_id: String) -> Dictionary:
	return _active_enemies.get(enemy_id, {}).duplicate(true)


func get_active_enemies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy_id in get_active_enemy_ids():
		result.append(get_enemy(enemy_id))
	return result


func spawn_wave(wave_number: int, clear_existing: bool = false) -> Dictionary:
	if not _wave_by_number.has(wave_number):
		return _failure("unknown_wave", "敌人波次不存在。", {"wave_number": wave_number})

	var enemy_root := get_node_or_null(ENEMY_ROOT_PATH)
	if enemy_root == null:
		return _failure("enemy_root_missing", "敌人生成容器不存在。", {"wave_number": wave_number})

	if clear_existing:
		clear_spawned_enemies()

	var wave: Dictionary = _wave_by_number[wave_number]
	var enemies: Array = wave.get("enemies", [])
	var total_count := _get_wave_enemy_count(wave)
	var columns := maxi(1, ceili(sqrt(float(maxi(total_count, 1)))))
	var spawn_index := 0
	var spawned: Array[Dictionary] = []

	for raw_enemy in enemies:
		var enemy_template: Dictionary = raw_enemy if raw_enemy is Dictionary else {}
		var count := maxi(0, int(enemy_template.get("count", 0)))
		for group_index in range(count):
			_spawn_sequence += 1
			var enemy_id := "wave_%02d_enemy_%03d" % [wave_number, _spawn_sequence]
			var enemy := _make_enemy_state(enemy_id, wave, enemy_template, group_index, spawn_index, columns)
			_active_enemies[enemy_id] = enemy.duplicate(true)
			var enemy_node := _create_enemy_node(enemy)
			enemy_root.add_child(enemy_node)
			enemy_node.global_position = enemy.get("position", Vector3.ZERO)
			_enemy_nodes[enemy_id] = enemy_node.get_path()
			spawned.append(enemy.duplicate(true))
			spawn_index += 1

	_last_spawn_result = {
		"ok": true,
		"wave_number": wave_number,
		"wave_id": str(wave.get("id", "")),
		"spawned_count": spawned.size(),
		"active_enemy_count": get_active_enemy_count(),
		"spawned_enemy_ids": _extract_enemy_ids(spawned),
		"spawn_point": str(wave.get("spawn_point", DEFAULT_SPAWN_POINT_ID)),
		"spawn_position": _vector3_to_dict(_get_wave_spawn_position(wave))
	}
	return _last_spawn_result.duplicate(true)


func clear_spawned_enemies() -> Dictionary:
	var removed_count := _active_enemies.size()
	_clear_spawned_enemy_nodes()
	_active_enemies.clear()
	_enemy_nodes.clear()
	var mode_exit_result := _handle_all_enemies_cleared("enemies_cleared")
	_last_spawn_result = {
		"ok": true,
		"removed_count": removed_count,
		"active_enemy_count": 0,
		"mode_exit_result": mode_exit_result
	}
	return _last_spawn_result.duplicate(true)


func debug_spawn_wave(wave_number: int = 1, clear_existing: bool = false) -> Dictionary:
	return spawn_wave(wave_number, clear_existing)


func debug_clear_enemies() -> Dictionary:
	return clear_spawned_enemies()


func debug_get_combat_snapshot() -> Dictionary:
	return {
		"wave_count": get_wave_count(),
		"wave_numbers": get_wave_numbers(),
		"active_enemy_count": get_active_enemy_count(),
		"active_enemy_ids": get_active_enemy_ids(),
		"enemy_targets": _get_enemy_target_snapshot(),
		"active_rallies": get_active_rallies(),
		"active_avoidances": get_active_avoidances(),
		"behavior_modes": _get_behavior_mode_snapshots(),
		"last_alarm_result": get_last_alarm_result(),
		"last_spawn_result": get_last_spawn_result(),
		"last_ai_step_result": _last_ai_step_result.duplicate(true),
		"last_failure_result": _last_failure_result.duplicate(true),
		"last_mode_transition_result": _last_mode_transition_result.duplicate(true),
		"last_avoidance_result": _last_avoidance_result.duplicate(true)
	}


func debug_step_enemy_ai(game_seconds: float = 60.0) -> Dictionary:
	var seconds := maxf(0.0, game_seconds)
	_advance_rally_units(seconds)
	if _active_enemies.is_empty():
		_handle_all_enemies_cleared("no_active_enemies")
		return _advance_enemy_ai(seconds)
	_advance_behavior_mode_contacts()
	_advance_avoidance_units()
	var result := _advance_enemy_ai(seconds)
	_advance_avoidance_units()
	return result


func debug_advance_rally_wait(game_seconds: float = RALLY_WAIT_TIMEOUT_SECONDS) -> Dictionary:
	var before := get_active_rallies()
	_advance_rally_units(maxf(0.0, game_seconds))
	return {
		"ok": true,
		"game_seconds": maxf(0.0, game_seconds),
		"before": before,
		"after": get_active_rallies()
	}


func debug_trigger_npc_avoidance(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return _avoidance_failure("npc_system_missing", "NPC 系统不可用。", {"npc_id": npc_id})
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _avoidance_failure("unknown_npc", "NPC 不存在。", {"npc_id": npc_id})
	if bool(npc.get("recruited", false)):
		return _avoidance_failure("npc_recruited", "已入伍 NPC 不进入未入伍避战模式。", {"npc_id": npc_id})
	if _active_enemies.is_empty():
		return _avoidance_failure("no_active_enemies", "当前没有敌军，无法触发避战。", {"npc_id": npc_id})
	var encounter := _nearest_enemy_for_npc(npc_id)
	if encounter.is_empty():
		return _avoidance_failure("enemy_missing", "找不到可用于避战的敌人。", {"npc_id": npc_id})
	return _enter_npc_avoid_from_contact(npc_id, encounter, "gm_avoidance")


func debug_get_enemy_target(enemy_id: String) -> Dictionary:
	var enemy := get_enemy(enemy_id)
	if enemy.is_empty():
		return {}
	var target: Dictionary = enemy.get("target", {}) if (enemy.get("target", {}) is Dictionary) else {}
	return _serialize_target(target)


func trigger_combat_alarm(source: String = "hud") -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return _alarm_failure("npc_system_missing", "NPC 系统不可用。")

	_active_rallies.clear()
	var npc_ids: Array = npc_system.get_npc_ids()
	var alarm_events: Array[Dictionary] = []
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		var event := _log_combat_alarm_for_npc(npc_id, source, npc_ids.size())
		if not event.is_empty():
			alarm_events.append(event)

	var eligible: Array[Dictionary] = []
	var ignored: Array[Dictionary] = []
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		var eligibility := _get_rally_eligibility(npc_id)
		if bool(eligibility.get("ok", false)):
			eligible.append(eligibility)
		else:
			ignored.append(eligibility)

	var formation := _build_rally_formation(eligible)
	var rallied: Array[Dictionary] = []
	for entry in formation:
		var rally_result := _start_npc_rally(entry)
		if not rally_result.is_empty():
			rallied.append(rally_result)

	_last_alarm_result = {
		"ok": true,
		"source": source,
		"heard_count": alarm_events.size(),
		"eligible_count": eligible.size(),
		"rallied_count": rallied.size(),
		"ignored_count": ignored.size(),
		"rallied": rallied,
		"ignored": ignored
	}
	return _last_alarm_result.duplicate(true)


func debug_trigger_combat_alarm() -> Dictionary:
	return trigger_combat_alarm("gm_panel")


func get_last_alarm_result() -> Dictionary:
	return _last_alarm_result.duplicate(true)


func get_active_rallies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rally_ids := _active_rallies.keys()
	rally_ids.sort()
	for raw_npc_id in rally_ids:
		var rally: Dictionary = _active_rallies.get(str(raw_npc_id), {})
		result.append(_serialize_rally(rally))
	return result


func get_active_avoidances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var avoidance_ids := _active_avoidances.keys()
	avoidance_ids.sort()
	for raw_npc_id in avoidance_ids:
		var avoidance: Dictionary = _active_avoidances.get(str(raw_npc_id), {})
		result.append(_serialize_avoidance(avoidance))
	return result


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	_advance_rally_units(game_delta_seconds)
	if _active_enemies.is_empty():
		_handle_all_enemies_cleared("no_active_enemies")
		return
	_advance_behavior_mode_contacts()
	_advance_avoidance_units()
	_advance_enemy_ai(game_delta_seconds)
	_advance_avoidance_units()


func _advance_enemy_ai(game_delta_seconds: float) -> Dictionary:
	var result := {
		"ok": true,
		"game_seconds": game_delta_seconds,
		"moved": [],
		"attacks": [],
		"targets": []
	}
	if game_delta_seconds <= 0.0 or _active_enemies.is_empty():
		_last_ai_step_result = result.duplicate(true)
		if _active_enemies.is_empty():
			_handle_all_enemies_cleared("no_active_enemies")
		return result

	for enemy_id in get_active_enemy_ids():
		if not _active_enemies.has(enemy_id):
			continue
		var enemy: Dictionary = _active_enemies[enemy_id]
		if not bool(enemy.get("alive", true)):
			continue

		var target := _select_enemy_target(enemy)
		enemy["target"] = target.duplicate(true)
		(result["targets"] as Array).append({
			"enemy_id": enemy_id,
			"target": _serialize_target(target)
		})
		if target.is_empty():
			enemy["current_action"] = "idle_no_target"
			_active_enemies[enemy_id] = enemy
			_refresh_enemy_node(enemy_id)
			continue

		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		var target_position: Vector3 = target.get("position", enemy_position)
		var attack_range := maxf(0.1, float(enemy.get("attack_range", 1.5)))
		var distance := enemy_position.distance_to(target_position)
		if distance > attack_range:
			var move_distance := maxf(0.0, float(enemy.get("move_speed", 2.5))) * game_delta_seconds / MOVE_SPEED_GAME_SECONDS_DIVISOR
			var next_position := enemy_position.move_toward(target_position, move_distance)
			enemy["position"] = next_position
			enemy["current_action"] = "moving_to_%s" % str(target.get("id", "target"))
			(result["moved"] as Array).append({
				"enemy_id": enemy_id,
				"target_id": str(target.get("id", "")),
				"from": _vector3_to_dict(enemy_position),
				"to": _vector3_to_dict(next_position),
				"remaining_distance": next_position.distance_to(target_position)
			})
		else:
			enemy["current_action"] = "attacking_%s" % str(target.get("id", "target"))
			var attack_result := _advance_enemy_attack(enemy, target, game_delta_seconds)
			if not attack_result.is_empty():
				(result["attacks"] as Array).append(attack_result)
		_active_enemies[enemy_id] = enemy
		_refresh_enemy_node(enemy_id)

	_last_ai_step_result = result.duplicate(true)
	return result


func _advance_rally_units(game_delta_seconds: float = 0.0) -> void:
	if _active_rallies.is_empty():
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_world_position"):
		return
	var rally_ids := _active_rallies.keys()
	for raw_npc_id in rally_ids:
		var npc_id := str(raw_npc_id)
		if not _active_rallies.has(npc_id):
			continue
		var rally: Dictionary = _active_rallies.get(npc_id, {})
		if str(rally.get("status", "")) == "combat_ready":
			continue
		if npc_system.has_method("can_npc_act") and not npc_system.can_npc_act(npc_id):
			rally["status"] = "unavailable"
			_active_rallies[npc_id] = rally
			continue
		var raw_position: Variant = npc_system.get_npc_world_position(npc_id)
		if raw_position == null:
			continue
		var npc_position: Vector3 = raw_position
		var encounter := _find_nearest_enemy(npc_position, RALLY_ENCOUNTER_RANGE)
		if not encounter.is_empty():
			_switch_rally_to_combat(npc_id, rally, encounter)
			continue
		var target_position: Vector3 = rally.get("position", npc_position)
		if npc_position.distance_to(target_position) <= 0.2:
			rally["status"] = "rallied"
			var elapsed := maxf(0.0, float(rally.get("rallied_elapsed_seconds", 0.0)) + maxf(0.0, game_delta_seconds))
			rally["rallied_elapsed_seconds"] = elapsed
			rally["rally_wait_remaining_seconds"] = maxf(0.0, RALLY_WAIT_TIMEOUT_SECONDS - elapsed)
			_active_rallies[npc_id] = rally
			if elapsed >= RALLY_WAIT_TIMEOUT_SECONDS:
				_complete_rally_timeout(npc_id, rally)


func _advance_behavior_mode_contacts() -> void:
	if _active_enemies.is_empty():
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("get_npc_world_position"):
		return
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system.has_method("get_npc") else {}
		if npc.is_empty():
			continue
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		if bool(state.get("unconscious", false)) or bool(state.get("escaped", false)):
			continue
		if npc_system.has_method("is_npc_sleeping") and npc_system.is_npc_sleeping(npc_id):
			continue
		var mode := _get_npc_behavior_mode(npc_system, npc_id)
		if mode == BEHAVIOR_MODE_COMBAT or mode == BEHAVIOR_MODE_AVOID_COMBAT:
			continue
		var raw_position: Variant = npc_system.get_npc_world_position(npc_id)
		if raw_position == null:
			continue
		var npc_position: Vector3 = raw_position
		var encounter := _find_nearest_enemy(npc_position, FRIENDLY_CONTACT_RANGE)
		if encounter.is_empty():
			continue
		if bool(npc.get("recruited", false)) and [BEHAVIOR_MODE_WORK, BEHAVIOR_MODE_RALLY].has(mode):
			if _active_rallies.has(npc_id):
				_switch_rally_to_combat(npc_id, _active_rallies.get(npc_id, {}), encounter)
			else:
				_enter_npc_combat_from_contact(npc_id, encounter, "enemy_contact")
		elif not bool(npc.get("recruited", false)) and mode == BEHAVIOR_MODE_WORK:
			_enter_npc_avoid_from_contact(npc_id, encounter, "enemy_contact")


func _complete_rally_timeout(npc_id: String, rally: Dictionary) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("set_npc_behavior_mode"):
		var result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, "rally_wait_timeout", {
			"force_idle": true,
			"request_plan_reevaluation": false,
			"state_changes": {
				"last_action_result": "rally_wait_timeout",
				"movement_target": "",
				"movement_target_name": ""
			}
		})
		_last_mode_transition_result = result.duplicate(true)
	_active_rallies.erase(npc_id)


func _enter_npc_combat_from_contact(npc_id: String, encounter: Dictionary, reason: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("set_npc_behavior_mode"):
		return {}
	var has_mount := _does_npc_have_mount(npc_id)
	var result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_COMBAT, reason, {
		"state_changes": {
			"current_action": "combat_ready",
			"last_action_result": reason,
			"combat_mounted": has_mount,
			"combat_target_enemy_id": str(encounter.get("enemy_id", "")),
			"facing_direction": "front_forest"
		},
		"request_plan_reevaluation": false
	})
	_last_mode_transition_result = result.duplicate(true)
	return result


func _enter_npc_avoid_from_contact(npc_id: String, encounter: Dictionary, reason: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("set_npc_behavior_mode"):
		return {}
	var target := _select_avoidance_target(npc_id, encounter)
	var result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_AVOID_COMBAT, reason, {
		"state_changes": {
			"current_action": "avoid_combat",
			"last_action_result": reason,
			"combat_target_enemy_id": str(encounter.get("enemy_id", "")),
			"avoidance_target_id": str(target.get("target_id", "")),
			"avoidance_target_name": str(target.get("target_name", "")),
			"avoidance_target_position": _vector3_to_dict(target.get("position", Vector3.ZERO)),
			"movement_target": "",
			"movement_target_name": ""
		},
		"request_plan_reevaluation": false
	})
	_last_mode_transition_result = result.duplicate(true)
	if bool(result.get("ok", false)):
		var avoidance := _start_or_update_npc_avoidance(npc_id, encounter, target, reason, true)
		result["avoidance"] = avoidance
		_last_avoidance_result = avoidance.duplicate(true)
	return result


func handle_npc_recruited_during_avoidance(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("set_npc_behavior_mode"):
		return {}
	var mode := _get_npc_behavior_mode(npc_system, npc_id)
	if mode != BEHAVIOR_MODE_AVOID_COMBAT:
		return {"ok": true, "npc_id": npc_id, "changed": false, "reason": "not_avoiding"}
	var ended_event := _complete_npc_avoidance(npc_id, "recruited_during_avoidance")
	if _active_enemies.is_empty():
		var work_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, "recruited_no_enemies", {
			"force_idle": true,
			"request_plan_reevaluation": false
		})
		work_result["avoidance_ended_event"] = ended_event
		_last_mode_transition_result = work_result.duplicate(true)
		return work_result
	var combat_result := _enter_npc_combat_from_contact(npc_id, _nearest_enemy_for_npc(npc_id), "recruited_during_avoidance")
	combat_result["avoidance_ended_event"] = ended_event
	_last_mode_transition_result = combat_result.duplicate(true)
	return combat_result


func _advance_avoidance_units() -> void:
	if _active_enemies.is_empty():
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("get_npc_world_position"):
		return
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var mode := _get_npc_behavior_mode(npc_system, npc_id)
		if mode != BEHAVIOR_MODE_AVOID_COMBAT:
			if _active_avoidances.has(npc_id):
				_active_avoidances.erase(npc_id)
			continue
		if npc_system.has_method("can_npc_act") and not npc_system.can_npc_act(npc_id):
			continue
		var raw_position: Variant = npc_system.get_npc_world_position(npc_id)
		if raw_position == null:
			continue
		var npc_position: Vector3 = raw_position
		var encounter := _find_nearest_enemy(npc_position, INF)
		if encounter.is_empty():
			continue
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		var current_action := str(state.get("current_action", ""))
		if not _active_avoidances.has(npc_id):
			var target := _select_avoidance_target(npc_id, encounter)
			_last_avoidance_result = _start_or_update_npc_avoidance(npc_id, encounter, target, "avoidance_tracking", true)
			continue
		var avoidance: Dictionary = _active_avoidances.get(npc_id, {})
		var target_position: Vector3 = avoidance.get("target_position", npc_position)
		if current_action.begins_with("moving_to_%s" % AVOIDANCE_TARGET_PREFIX):
			avoidance["status"] = "moving"
			_active_avoidances[npc_id] = avoidance
			continue
		if npc_position.distance_to(target_position) <= 0.35:
			avoidance["status"] = "sheltered"
			_active_avoidances[npc_id] = avoidance
		if float(encounter.get("distance", INF)) <= AVOIDANCE_REPATH_DISTANCE:
			var next_target := _select_avoidance_target(npc_id, encounter)
			_last_avoidance_result = _start_or_update_npc_avoidance(npc_id, encounter, next_target, "enemy_too_close", false)


func _start_or_update_npc_avoidance(
	npc_id: String,
	encounter: Dictionary,
	target: Dictionary,
	reason: String,
	log_started: bool
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("move_npc_to_world_position"):
		return _avoidance_failure("npc_system_missing", "NPC 系统避战移动接口不可用。", {"npc_id": npc_id})
	if target.is_empty():
		return _avoidance_failure("avoidance_target_missing", "没有可用避战目标。", {"npc_id": npc_id})
	var target_position: Vector3 = target.get("position", Vector3.ZERO)
	var target_id := "%s%s" % [AVOIDANCE_TARGET_PREFIX, npc_id]
	var target_name := str(target.get("target_name", AVOIDANCE_LOCATION_NAME))
	var event := {}
	if log_started:
		event = _log_avoidance_started(npc_id, encounter, target, reason)
	var arrival_state := {
		"current_action": "avoiding_enemy",
		"current_location": AVOIDANCE_LOCATION_ID,
		"current_location_name": AVOIDANCE_LOCATION_NAME,
		"last_action_result": "avoidance_arrived",
		"combat_target_enemy_id": str(encounter.get("enemy_id", "")),
		"avoidance_target_id": str(target.get("target_id", "")),
		"avoidance_target_name": target_name,
		"avoidance_target_position": _vector3_to_dict(target_position)
	}
	var moved := bool(npc_system.move_npc_to_world_position(npc_id, target_id, target_name, target_position, arrival_state))
	var avoidance := {
		"ok": moved,
		"npc_id": npc_id,
		"status": "moving" if moved else "holding",
		"reason": reason,
		"enemy_id": str(encounter.get("enemy_id", "")),
		"enemy_name": str(encounter.get("enemy_name", "")),
		"enemy_distance": float(encounter.get("distance", 0.0)),
		"target_id": target_id,
		"safe_target_id": str(target.get("target_id", "")),
		"target_name": target_name,
		"target_position": target_position,
		"started_event_id": str(event.get("event_id", "")),
		"event": event
	}
	_active_avoidances[npc_id] = avoidance
	return _serialize_avoidance(avoidance)


func _complete_npc_avoidance(npc_id: String, reason: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var mode := _get_npc_behavior_mode(npc_system, npc_id) if npc_system != null else BEHAVIOR_MODE_WORK
	if mode != BEHAVIOR_MODE_AVOID_COMBAT and not _active_avoidances.has(npc_id):
		return {}
	var event := _log_avoidance_ended(npc_id, reason)
	_active_avoidances.erase(npc_id)
	_last_avoidance_result = {
		"ok": true,
		"npc_id": npc_id,
		"reason": reason,
		"event": event
	}
	return event


func _select_avoidance_target(npc_id: String, encounter: Dictionary) -> Dictionary:
	var npc_position := _get_npc_position(npc_id)
	var best := {}
	var best_score := -INF
	for candidate in _get_avoidance_safe_targets():
		var position: Vector3 = candidate.get("position", Vector3.ZERO)
		var min_enemy_distance := _get_min_enemy_distance(position)
		var travel_distance := npc_position.distance_to(position)
		var contact_gain := min_enemy_distance - float(encounter.get("distance", 0.0))
		var score := min_enemy_distance + contact_gain * 0.5 - travel_distance * 0.05
		if score > best_score:
			best_score = score
			best = candidate.duplicate(true)
	best["score"] = best_score
	return best


func _get_avoidance_safe_targets() -> Array[Dictionary]:
	return [
		{"target_id": "clinic_shelter", "target_name": "小诊所旁避战点", "position": Vector3(4.8, 0.0, -10.4)},
		{"target_id": "chapel_shelter", "target_name": "小教堂旁避战点", "position": Vector3(-4.8, 0.0, -10.4)},
		{"target_id": "dormitory_shelter", "target_name": "宿舍旁避战点", "position": Vector3(-9.5, 0.0, -4.8)},
		{"target_id": "dining_hall_shelter", "target_name": "食堂旁避战点", "position": Vector3(9.4, 0.0, -4.7)},
		{"target_id": "tavern_shelter", "target_name": "酒窖旁避战点", "position": Vector3(-10.4, 0.0, 5.0)},
		{"target_id": "stable_shelter", "target_name": "马厩旁避战点", "position": Vector3(11.4, 0.0, -8.8)},
		{"target_id": "workshop_shelter", "target_name": "工械坊旁避战点", "position": Vector3(-12.0, 0.0, -8.8)},
		{"target_id": "plaza_rear_shelter", "target_name": "广场后方避战点", "position": Vector3(0.0, 0.0, -4.0)}
	]


func _get_min_enemy_distance(position: Vector3) -> float:
	var min_distance := INF
	for enemy_id in get_active_enemy_ids():
		var enemy: Dictionary = _active_enemies.get(enemy_id, {})
		if not bool(enemy.get("alive", true)):
			continue
		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		min_distance = minf(min_distance, position.distance_to(enemy_position))
	return min_distance


func _handle_all_enemies_cleared(reason: String) -> Dictionary:
	var result := {
		"ok": true,
		"reason": reason,
		"combat_to_work": [],
		"avoid_to_work": [],
		"avoidance_ended": []
	}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("set_npc_behavior_mode"):
		return result
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var mode := _get_npc_behavior_mode(npc_system, npc_id)
		if mode == BEHAVIOR_MODE_COMBAT:
			var combat_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, reason, {
				"force_idle": true,
				"request_plan_reevaluation": true
			})
			(result["combat_to_work"] as Array).append(combat_result)
			_active_rallies.erase(npc_id)
		elif mode == BEHAVIOR_MODE_AVOID_COMBAT:
			var ended_event := _complete_npc_avoidance(npc_id, reason)
			var avoid_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, reason, {
				"force_idle": true,
				"request_plan_reevaluation": false
			})
			avoid_result["avoidance_ended_event"] = ended_event
			(result["avoid_to_work"] as Array).append(avoid_result)
			(result["avoidance_ended"] as Array).append(ended_event)
	_last_mode_transition_result = result.duplicate(true)
	return result


func _on_npc_revived(npc_id: String) -> void:
	_route_revived_npc(npc_id)


func _on_npc_unconscious(npc_id: String) -> void:
	_active_rallies.erase(npc_id)
	_complete_npc_avoidance(npc_id, "npc_unconscious")


func _route_revived_npc(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("set_npc_behavior_mode"):
		return {}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}
	if _active_enemies.is_empty():
		var work_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, "revived_no_enemies", {
			"force_idle": true,
			"request_plan_reevaluation": true
		})
		_last_mode_transition_result = work_result.duplicate(true)
		return work_result
	if bool(npc.get("recruited", false)):
		var combat_result := _enter_npc_combat_from_contact(npc_id, _nearest_enemy_for_npc(npc_id), "revived_enemies_present")
		_last_mode_transition_result = combat_result.duplicate(true)
		return combat_result
	var avoid_result := _enter_npc_avoid_from_contact(npc_id, _nearest_enemy_for_npc(npc_id), "revived_enemies_present")
	_last_mode_transition_result = avoid_result.duplicate(true)
	return avoid_result


func _get_rally_eligibility(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if npc_system == null or equipment_system == null:
		return {"ok": false, "npc_id": npc_id, "reason": "system_missing"}
	var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system.has_method("get_npc") else {}
	if npc.is_empty():
		return {"ok": false, "npc_id": npc_id, "reason": "unknown_npc"}
	if not bool(npc.get("recruited", false)):
		return {"ok": false, "npc_id": npc_id, "reason": "not_recruited"}
	var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
	if npc_system.has_method("is_npc_sleeping") and npc_system.is_npc_sleeping(npc_id):
		return {"ok": false, "npc_id": npc_id, "reason": "sleeping"}
	if npc_system.has_method("can_npc_act") and not npc_system.can_npc_act(npc_id):
		return {"ok": false, "npc_id": npc_id, "reason": "cannot_act"}
	if bool(state.get("unconscious", false)):
		return {"ok": false, "npc_id": npc_id, "reason": "unconscious"}
	var snapshot: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
	if not bool(snapshot.get("has_main_weapon", false)):
		return {"ok": false, "npc_id": npc_id, "reason": "no_main_weapon"}
	return {
		"ok": true,
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"unit_type": str(snapshot.get("unit_type", "")),
		"unit_type_label": str(snapshot.get("unit_type_label", "")),
		"has_mount": bool(snapshot.get("has_mount", false)),
		"main_weapon_id": str(snapshot.get("main_weapon_id", "")),
		"main_weapon_name": str(snapshot.get("main_weapon_name", ""))
	}


func _build_rally_formation(eligible: Array[Dictionary]) -> Array[Dictionary]:
	var front: Array[Dictionary] = []
	var back: Array[Dictionary] = []
	for entry in eligible:
		if _is_frontline_unit(str(entry.get("unit_type", ""))):
			front.append(entry)
		else:
			back.append(entry)
	var result: Array[Dictionary] = []
	result.append_array(_assign_rally_positions(front, "front", RALLY_FRONT_Z))
	result.append_array(_assign_rally_positions(back, "back", RALLY_BACK_Z))
	return result


func _assign_rally_positions(entries: Array[Dictionary], row_name: String, z_position: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if entries.is_empty():
		return result
	var center_offset := (float(entries.size() - 1) * RALLY_COLUMN_SPACING) * 0.5
	for index in range(entries.size()):
		var entry := entries[index].duplicate(true)
		var x_position := float(index) * RALLY_COLUMN_SPACING - center_offset
		var row_offset := 0.0
		if entries.size() > 5:
			row_offset = float(index / 5) * RALLY_ROW_SPACING
			x_position = float(index % 5) * RALLY_COLUMN_SPACING - (float(mini(entries.size(), 5) - 1) * RALLY_COLUMN_SPACING) * 0.5
		entry["formation_row"] = row_name
		entry["formation_index"] = index
		entry["position"] = Vector3(x_position, 0.0, z_position - row_offset)
		result.append(entry)
	return result


func _start_npc_rally(entry: Dictionary) -> Dictionary:
	var npc_id := str(entry.get("npc_id", ""))
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_id.is_empty() or npc_system == null:
		return {}

	var position: Vector3 = entry.get("position", Vector3.ZERO)
	var encounter := _find_nearest_enemy(_get_npc_position(npc_id), RALLY_ENCOUNTER_RANGE)
	var has_mount := bool(entry.get("has_mount", false))
	var rally_state := {
		"current_action": "rallying_defense_line",
		"current_location": RALLY_LOCATION_ID,
		"current_location_name": RALLY_LOCATION_NAME,
		"last_action_result": "combat_rally_arrived",
		"combat_mode": "rally",
		"combat_mounted": has_mount,
		"facing_direction": "front_forest"
	}
	var target_id := "%s%s" % [RALLY_TARGET_PREFIX, npc_id]
	if not encounter.is_empty():
		_switch_rally_to_combat(npc_id, entry, encounter)
		return _serialize_rally(_active_rallies.get(npc_id, {}))
	if npc_system.has_method("set_npc_behavior_mode"):
		var mode_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_RALLY, "combat_alarm", {
			"state_changes": rally_state,
			"request_plan_reevaluation": false
		})
		if not bool(mode_result.get("ok", false)):
			return {}
	if not npc_system.has_method("move_npc_to_world_position"):
		return {}
	var moved: bool = npc_system.move_npc_to_world_position(npc_id, target_id, RALLY_LOCATION_NAME, position, rally_state)
	if not moved:
		return {}
	if npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, {
			"combat_mode": "rally",
			"combat_mounted": has_mount,
			"facing_direction": "front_forest",
			"last_action_result": "combat_rally_started"
		})
	var event := _log_combat_rally_started(npc_id, entry, position)
	var rally := entry.duplicate(true)
	rally["status"] = "moving"
	rally["target_id"] = target_id
	rally["event_id"] = str(event.get("event_id", ""))
	rally["rallied_elapsed_seconds"] = 0.0
	rally["rally_wait_remaining_seconds"] = RALLY_WAIT_TIMEOUT_SECONDS
	_active_rallies[npc_id] = rally
	return _serialize_rally(rally)


func _switch_rally_to_combat(npc_id: String, rally: Dictionary, encounter: Dictionary) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var has_mount := bool(rally.get("has_mount", false))
	var enemy_id := str(encounter.get("enemy_id", ""))
	var changes := {
		"current_action": "combat_ready",
		"movement_target": "",
		"movement_target_name": "",
		"current_location": RALLY_LOCATION_ID,
		"current_location_name": RALLY_LOCATION_NAME,
		"last_action_result": "enemy_encountered_during_rally",
		"combat_mode": "combat",
		"combat_mounted": has_mount,
		"combat_target_enemy_id": enemy_id,
		"facing_direction": "front_forest"
	}
	if npc_system.has_method("set_npc_behavior_mode"):
		var mode_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_COMBAT, "enemy_contact", {
			"state_changes": changes,
			"request_plan_reevaluation": false
		})
		_last_mode_transition_result = mode_result.duplicate(true)
	elif npc_system.has_method("stop_npc_movement_with_state"):
		npc_system.stop_npc_movement_with_state(npc_id, changes)
	else:
		npc_system.update_npc_state(npc_id, changes)
	var next_rally := rally.duplicate(true)
	next_rally["status"] = "combat_ready"
	next_rally["encounter_enemy_id"] = enemy_id
	next_rally["encounter_distance"] = float(encounter.get("distance", 0.0))
	_active_rallies[npc_id] = next_rally
	_log_combat_rally_encounter(npc_id, next_rally, encounter)


func _find_nearest_enemy(position: Vector3, max_distance: float) -> Dictionary:
	var nearest := {}
	var nearest_distance := INF
	for enemy_id in get_active_enemy_ids():
		var enemy: Dictionary = _active_enemies.get(enemy_id, {})
		if not bool(enemy.get("alive", true)):
			continue
		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		var distance := position.distance_to(enemy_position)
		if distance > max_distance or distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest = {
			"enemy_id": enemy_id,
			"enemy_name": str(enemy.get("name", enemy_id)),
			"position": enemy_position,
			"distance": distance
		}
	return nearest


func _get_npc_position(npc_id: String) -> Vector3:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_world_position"):
		return Vector3.ZERO
	var raw_position: Variant = npc_system.get_npc_world_position(npc_id)
	if raw_position == null:
		return Vector3.ZERO
	return raw_position


func _nearest_enemy_for_npc(npc_id: String) -> Dictionary:
	return _find_nearest_enemy(_get_npc_position(npc_id), INF)


func _get_npc_behavior_mode(npc_system: Node, npc_id: String) -> String:
	if npc_system != null and npc_system.has_method("get_npc_behavior_mode_snapshot"):
		var snapshot: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
		return str(snapshot.get("behavior_mode", BEHAVIOR_MODE_WORK))
	var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system != null and npc_system.has_method("get_npc_state") else {}
	if bool(state.get("escaped", false)):
		return BEHAVIOR_MODE_ESCAPED
	if bool(state.get("unconscious", false)):
		return BEHAVIOR_MODE_UNCONSCIOUS
	var mode := str(state.get("behavior_mode", ""))
	if not mode.is_empty():
		return mode
	var combat_mode := str(state.get("combat_mode", ""))
	if [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(combat_mode):
		return combat_mode
	return BEHAVIOR_MODE_WORK


func _does_npc_have_mount(npc_id: String) -> bool:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_unit_type_snapshot"):
		return false
	var snapshot: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
	return bool(snapshot.get("has_mount", false))


func _get_behavior_mode_snapshots() -> Array:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_get_behavior_mode_snapshot"):
		return []
	var raw: Variant = npc_system.debug_get_behavior_mode_snapshot()
	return raw if raw is Array else []


func _is_frontline_unit(unit_type: String) -> bool:
	return ["melee_infantry", "polearm_infantry", "cavalry"].has(unit_type)


func _select_enemy_target(enemy: Dictionary) -> Dictionary:
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	var preferences := _normalize_string_array(enemy.get("target_preference", DEFAULT_TARGET_PREFERENCE))
	if preferences.is_empty():
		preferences = DEFAULT_TARGET_PREFERENCE.duplicate()

	if preferences.has(NEARBY_UNIT_TARGET_ID):
		var nearby_unit := _find_nearby_unit_target(enemy, enemy_position)
		if not nearby_unit.is_empty():
			return nearby_unit

	for raw_target_id in preferences:
		var target_id := _normalize_building_target_id(str(raw_target_id))
		if target_id.is_empty() or target_id == NEARBY_UNIT_TARGET_ID:
			continue
		var building_target := _make_building_target(target_id)
		if not building_target.is_empty():
			return building_target

	return _make_building_target(MAIN_HALL_ID)


func _find_nearby_unit_target(enemy: Dictionary, enemy_position: Vector3) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("get_npc_world_position"):
		return {}

	var detection_range := maxf(DEFAULT_NEARBY_UNIT_DETECTION_RANGE, float(enemy.get("attack_range", 1.5)))
	var nearest_target := {}
	var nearest_distance := INF
	for npc_id in npc_system.get_npc_ids():
		if npc_system.has_method("can_npc_act") and not npc_system.can_npc_act(npc_id):
			continue
		var raw_position: Variant = npc_system.get_npc_world_position(npc_id)
		if raw_position == null:
			continue
		var npc_position: Vector3 = raw_position
		var distance := enemy_position.distance_to(npc_position)
		if distance > detection_range or distance >= nearest_distance:
			continue
		var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system.has_method("get_npc") else {}
		nearest_distance = distance
		nearest_target = {
			"type": "npc",
			"id": npc_id,
			"name": str(npc.get("name", npc_id)),
			"position": npc_position,
			"distance": distance
		}
	return nearest_target


func _make_building_target(building_id: String) -> Dictionary:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		return {}
	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty() or int(building.get("hp", 0)) <= 0:
		return {}
	var raw_position: Variant = null
	if building_system.has_method("get_building_entry_position"):
		raw_position = building_system.get_building_entry_position(building_id)
	if raw_position == null:
		return {}
	return {
		"type": "building",
		"id": building_id,
		"name": str(building.get("name", building_id)),
		"position": raw_position,
		"distance": 0.0
	}


func _advance_enemy_attack(enemy: Dictionary, target: Dictionary, game_delta_seconds: float) -> Dictionary:
	var remaining := game_delta_seconds
	var cooldown := maxf(0.0, float(enemy.get("attack_cooldown", 0.0)))
	var interval := maxf(0.1, float(enemy.get("attack_interval", 1.8)))
	var attacks: Array[Dictionary] = []
	while remaining > 0.0 and attacks.size() < MAX_ATTACKS_PER_AI_STEP:
		if cooldown > remaining:
			cooldown -= remaining
			remaining = 0.0
			break
		remaining -= cooldown
		var single_attack := _apply_enemy_attack(enemy, target)
		if single_attack.is_empty():
			break
		attacks.append(single_attack)
		cooldown = interval
		if _is_target_defeated(target):
			break
	enemy["attack_cooldown"] = cooldown
	var result := {
		"enemy_id": str(enemy.get("id", "")),
		"target": _serialize_target(target),
		"attack_count": attacks.size(),
		"attacks": attacks
	}
	enemy["last_attack_result"] = result.duplicate(true)
	return result


func _apply_enemy_attack(enemy: Dictionary, target: Dictionary) -> Dictionary:
	var target_type := str(target.get("type", ""))
	var target_id := str(target.get("id", ""))
	if target_id.is_empty():
		return {}
	var damage := maxi(1, int(enemy.get("attack_power", 1)))
	match target_type:
		"npc":
			return _apply_enemy_attack_to_npc(enemy, target_id, damage)
		"building":
			return _apply_enemy_attack_to_building(enemy, target_id, damage)
		_:
			return {}


func _apply_enemy_attack_to_npc(enemy: Dictionary, npc_id: String, damage: int) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("apply_damage_to_npc"):
		return {}
	var npc_name := npc_id
	if npc_system.has_method("get_npc"):
		var npc: Dictionary = npc_system.get_npc(npc_id)
		npc_name = str(npc.get("name", npc_id))
	var enemy_id := str(enemy.get("id", ""))
	var enemy_name := str(enemy.get("name", enemy_id))
	var damage_result: Dictionary = npc_system.apply_damage_to_npc(
		npc_id,
		damage,
		enemy_id,
		ENEMY_DAMAGE_VISIBILITY,
		{
			"summary": "%s攻击了%s，造成%d点伤害。" % [enemy_name, npc_name, damage],
			"request_plan_reevaluation": false,
			"enemy_attack": true
		}
	)
	return {
		"target_type": "npc",
		"target_id": npc_id,
		"damage": damage,
		"result": damage_result
	}


func _apply_enemy_attack_to_building(enemy: Dictionary, building_id: String, damage: int) -> Dictionary:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("apply_damage_to_building"):
		return {}
	var enemy_id := str(enemy.get("id", ""))
	var enemy_name := str(enemy.get("name", enemy_id))
	var damage_result: Dictionary = building_system.apply_damage_to_building(
		building_id,
		damage,
		enemy_id,
		ENEMY_DAMAGE_VISIBILITY,
		{"attacker_name": enemy_name}
	)
	if building_id == MAIN_HALL_ID and bool(damage_result.get("destroyed", false)):
		_trigger_main_hall_failure(enemy, damage_result)
	return {
		"target_type": "building",
		"target_id": building_id,
		"damage": damage,
		"result": damage_result
	}


func _trigger_main_hall_failure(enemy: Dictionary, damage_result: Dictionary) -> void:
	if not _last_failure_result.is_empty():
		return
	_last_failure_result = {
		"ok": true,
		"result": "failure",
		"reason": FAILURE_REASON_MAIN_HALL_DESTROYED,
		"attacker_enemy_id": str(enemy.get("id", "")),
		"damage": damage_result.duplicate(true)
	}
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("set_game_over"):
		game_state.set_game_over("failure", FAILURE_REASON_MAIN_HALL_DESTROYED)


func _is_target_defeated(target: Dictionary) -> bool:
	var target_type := str(target.get("type", ""))
	var target_id := str(target.get("id", ""))
	match target_type:
		"building":
			var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
			if building_system == null or not building_system.has_method("get_building"):
				return false
			var building: Dictionary = building_system.get_building(target_id)
			return building.is_empty() or int(building.get("hp", 0)) <= 0
		"npc":
			var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
			if npc_system == null or not npc_system.has_method("get_npc_state"):
				return false
			var state: Dictionary = npc_system.get_npc_state(target_id)
			return state.is_empty() or bool(state.get("unconscious", false)) or bool(state.get("escaped", false))
	return false


func _normalize_wave(raw_wave: Dictionary) -> Dictionary:
	var wave_number := int(raw_wave.get("wave_number", 0))
	if wave_number <= 0:
		push_warning("Skipped enemy wave with invalid wave_number: %s" % JSON.stringify(raw_wave))
		return {}

	var enemies := _normalize_enemy_group_array(raw_wave.get("enemies", []), wave_number)
	if enemies.is_empty():
		push_warning("Skipped enemy wave without valid enemies: %s" % str(wave_number))
		return {}

	var normalized := raw_wave.duplicate(true)
	normalized["id"] = str(raw_wave.get("id", "wave_%02d" % wave_number))
	normalized["wave_number"] = wave_number
	normalized["name"] = str(raw_wave.get("name", "第%d波敌人" % wave_number))
	normalized["spawn_point"] = str(raw_wave.get("spawn_point", DEFAULT_SPAWN_POINT_ID))
	normalized["spawn_position"] = _normalize_vector3_dict(raw_wave.get("spawn_position", {}), _get_named_spawn_position(str(normalized["spawn_point"])))
	normalized["spawn_spread"] = _normalize_spawn_spread(raw_wave.get("spawn_spread", {}))
	normalized["enemies"] = enemies
	return normalized


func _normalize_enemy_group_array(raw_enemies: Variant, wave_number: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source: Array = raw_enemies if raw_enemies is Array else []
	for raw_enemy in source:
		if not raw_enemy is Dictionary:
			continue
		var normalized := _normalize_enemy_group(raw_enemy, wave_number)
		if not normalized.is_empty():
			result.append(normalized)
	return result


func _normalize_enemy_group(raw_enemy: Dictionary, wave_number: int) -> Dictionary:
	var enemy_type_id := str(raw_enemy.get("enemy_type_id", raw_enemy.get("enemy_id", ""))).strip_edges()
	if enemy_type_id.is_empty():
		enemy_type_id = "wave_%02d_enemy_type" % wave_number
	var count := maxi(0, int(raw_enemy.get("count", 0)))
	if count <= 0:
		return {}

	var hp := maxi(1, int(raw_enemy.get("hp", raw_enemy.get("max_hp", 1))))
	var max_hp := maxi(hp, int(raw_enemy.get("max_hp", hp)))
	var unit_type := _normalize_unit_type(str(raw_enemy.get("unit_type", "")), str(raw_enemy.get("weapon_type", "")), str(raw_enemy.get("mount_type", "")))
	var target_preference := _normalize_string_array(raw_enemy.get("target_preference", DEFAULT_TARGET_PREFERENCE))
	if target_preference.is_empty():
		target_preference = DEFAULT_TARGET_PREFERENCE.duplicate()

	var normalized := raw_enemy.duplicate(true)
	normalized["enemy_type_id"] = enemy_type_id
	normalized["count"] = count
	normalized["name"] = str(raw_enemy.get("name", enemy_type_id))
	normalized["unit_type"] = unit_type
	normalized["weapon_type"] = str(raw_enemy.get("weapon_type", _default_weapon_for_unit_type(unit_type)))
	normalized["hp"] = hp
	normalized["max_hp"] = max_hp
	normalized["attack_power"] = maxi(1, int(raw_enemy.get("attack_power", raw_enemy.get("damage", 1))))
	normalized["defense"] = maxi(0, int(raw_enemy.get("defense", 0)))
	normalized["move_speed"] = maxf(0.1, float(raw_enemy.get("move_speed", 2.5)))
	normalized["attack_range"] = maxf(0.1, float(raw_enemy.get("attack_range", raw_enemy.get("range", 1.5))))
	normalized["attack_interval"] = maxf(0.1, float(raw_enemy.get("attack_interval", 1.8)))
	normalized["target_preference"] = target_preference
	return normalized


func _make_enemy_state(
	enemy_id: String,
	wave: Dictionary,
	enemy_template: Dictionary,
	group_index: int,
	spawn_index: int,
	columns: int
) -> Dictionary:
	var position := _get_spawn_position_for_index(wave, spawn_index, columns)
	var state := enemy_template.duplicate(true)
	state.erase("count")
	state["id"] = enemy_id
	state["enemy_id"] = enemy_id
	state["wave_id"] = str(wave.get("id", ""))
	state["wave_number"] = int(wave.get("wave_number", 0))
	state["group_index"] = group_index
	state["spawn_index"] = spawn_index
	state["position"] = position
	state["current_action"] = "spawned"
	state["target"] = {}
	state["attack_cooldown"] = 0.0
	state["last_attack_result"] = {}
	state["alive"] = true
	return state


func _create_enemy_node(enemy: Dictionary) -> Area3D:
	var enemy_node := Area3D.new()
	enemy_node.name = _make_node_name(str(enemy.get("id", "Enemy")))
	enemy_node.input_ray_pickable = true
	enemy_node.set_meta("enemy_id", str(enemy.get("id", "")))
	enemy_node.set_meta("wave_number", int(enemy.get("wave_number", 0)))

	var body := MeshInstance3D.new()
	body.name = "Body"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 1.35
	body.mesh = mesh
	body.position = Vector3(0.0, 0.72, 0.0)
	body.set_surface_override_material(0, _make_enemy_material(str(enemy.get("unit_type", ""))))
	enemy_node.add_child(body)

	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.4
	shape_node.shape = shape
	shape_node.position = Vector3(0.0, 0.72, 0.0)
	enemy_node.add_child(shape_node)

	var label := Label3D.new()
	label.name = "EnemyLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.014
	label.outline_size = 6
	label.outline_modulate = Color(0.04, 0.02, 0.02, 1.0)
	label.position = Vector3(0.0, 1.75, 0.0)
	label.text = "%s\nHP %d/%d · %s" % [
		str(enemy.get("name", "敌人")),
		int(enemy.get("hp", 0)),
		int(enemy.get("max_hp", 0)),
		_get_unit_type_label(str(enemy.get("unit_type", "")))
	]
	enemy_node.add_child(label)
	return enemy_node


func _make_enemy_material(unit_type: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _get_enemy_color(unit_type)
	return material


func _get_enemy_color(unit_type: String) -> Color:
	match unit_type:
		"polearm_infantry":
			return Color(0.7, 0.42, 0.18, 1.0)
		"archer":
			return Color(0.26, 0.46, 0.22, 1.0)
		"crossbowman":
			return Color(0.32, 0.34, 0.42, 1.0)
		"cavalry":
			return Color(0.46, 0.24, 0.16, 1.0)
		"mounted_ranged":
			return Color(0.24, 0.38, 0.42, 1.0)
		_:
			return Color(0.62, 0.2, 0.16, 1.0)


func _get_spawn_position_for_index(wave: Dictionary, spawn_index: int, columns: int) -> Vector3:
	var origin := _get_wave_spawn_position(wave)
	var spread: Dictionary = wave.get("spawn_spread", {})
	var spread_x := float(spread.get("x", 2.5))
	var spread_z := float(spread.get("z", 1.8))
	var column := spawn_index % columns
	var row := int(spawn_index / columns)
	var offset_x := (float(column) - (float(columns) - 1.0) * 0.5) * spread_x
	var offset_z := float(row) * spread_z
	return origin + Vector3(offset_x, 0.0, offset_z)


func _get_wave_spawn_position(wave: Dictionary) -> Vector3:
	return _vector3_from_dict(wave.get("spawn_position", {}), _get_named_spawn_position(str(wave.get("spawn_point", DEFAULT_SPAWN_POINT_ID))))


func _get_named_spawn_position(spawn_point_id: String) -> Vector3:
	return FALLBACK_SPAWN_POINTS.get(spawn_point_id, FALLBACK_SPAWN_POINTS[DEFAULT_SPAWN_POINT_ID])


func _normalize_vector3_dict(raw_value: Variant, fallback: Vector3) -> Dictionary:
	return _vector3_to_dict(_vector3_from_dict(raw_value, fallback))


func _vector3_from_dict(raw_value: Variant, fallback: Vector3) -> Vector3:
	var data: Dictionary = raw_value if raw_value is Dictionary else {}
	return Vector3(
		float(data.get("x", fallback.x)),
		float(data.get("y", fallback.y)),
		float(data.get("z", fallback.z))
	)


func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _normalize_spawn_spread(raw_value: Variant) -> Dictionary:
	var data: Dictionary = raw_value if raw_value is Dictionary else {}
	return {
		"x": maxf(0.5, float(data.get("x", 2.5))),
		"z": maxf(0.5, float(data.get("z", 1.8)))
	}


func _normalize_unit_type(raw_unit_type: String, weapon_type: String, mount_type: String) -> String:
	if VALID_UNIT_TYPES.has(raw_unit_type):
		return raw_unit_type
	if not mount_type.is_empty():
		if ["bow", "crossbow"].has(weapon_type):
			return "mounted_ranged"
		return "cavalry"
	match weapon_type:
		"polearm":
			return "polearm_infantry"
		"bow":
			return "archer"
		"crossbow":
			return "crossbowman"
		_:
			return "melee_infantry"


func _default_weapon_for_unit_type(unit_type: String) -> String:
	match unit_type:
		"polearm_infantry":
			return "polearm"
		"archer", "mounted_ranged":
			return "bow"
		"crossbowman":
			return "crossbow"
		_:
			return "sword_shield"


func _get_unit_type_label(unit_type: String) -> String:
	match unit_type:
		"melee_infantry":
			return "近战步兵"
		"polearm_infantry":
			return "长杆步兵"
		"archer":
			return "弓箭兵"
		"crossbowman":
			return "弩兵"
		"cavalry":
			return "近战骑兵"
		"mounted_ranged":
			return "骑射单位"
		_:
			return "敌人"


func _normalize_building_target_id(raw_target_id: String) -> String:
	match raw_target_id:
		"gate":
			return "front_gate"
		"front_wall":
			return "wall"
		"hall":
			return MAIN_HALL_ID
		_:
			return raw_target_id


func _get_enemy_target_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy_id in get_active_enemy_ids():
		var enemy: Dictionary = _active_enemies.get(enemy_id, {})
		var target: Dictionary = enemy.get("target", {}) if (enemy.get("target", {}) is Dictionary) else {}
		result.append({
			"enemy_id": enemy_id,
			"current_action": str(enemy.get("current_action", "")),
			"position": _vector3_to_dict(enemy.get("position", Vector3.ZERO)),
			"target": _serialize_target(target),
			"attack_cooldown": float(enemy.get("attack_cooldown", 0.0))
		})
	return result


func _serialize_target(target: Dictionary) -> Dictionary:
	if target.is_empty():
		return {}
	var result := target.duplicate(true)
	if result.has("position") and result["position"] is Vector3:
		result["position"] = _vector3_to_dict(result["position"])
	return result


func _serialize_rally(rally: Dictionary) -> Dictionary:
	if rally.is_empty():
		return {}
	var result := rally.duplicate(true)
	if result.has("position") and result["position"] is Vector3:
		result["position"] = _vector3_to_dict(result["position"])
	return result


func _serialize_avoidance(avoidance: Dictionary) -> Dictionary:
	if avoidance.is_empty():
		return {}
	var result := avoidance.duplicate(true)
	if result.has("target_position") and result["target_position"] is Vector3:
		result["target_position"] = _vector3_to_dict(result["target_position"])
	return result


func _log_combat_alarm_for_npc(npc_id: String, source: String, npc_count: int) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "combat_alarm_rang",
		"subject_npc_id": npc_id,
		"actor_ids": ["guard_officer"],
		"target_ids": [npc_id, "combat_alarm"],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "private",
		"importance": 75,
		"payload": {
			"source": source,
			"npc_count": npc_count,
			"active_enemy_count": get_active_enemy_count()
		}
	})


func _log_combat_rally_started(npc_id: String, entry: Dictionary, position: Vector3) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "combat_rally_started",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id, RALLY_LOCATION_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 70,
		"payload": {
			"formation_row": str(entry.get("formation_row", "")),
			"formation_index": int(entry.get("formation_index", 0)),
			"unit_type": str(entry.get("unit_type", "")),
			"unit_type_label": str(entry.get("unit_type_label", "")),
			"main_weapon_id": str(entry.get("main_weapon_id", "")),
			"main_weapon_name": str(entry.get("main_weapon_name", "")),
			"has_mount": bool(entry.get("has_mount", false)),
			"rally_location_id": RALLY_LOCATION_ID,
			"rally_location_name": RALLY_LOCATION_NAME,
			"position": _vector3_to_dict(position),
			"facing_direction": "front_forest"
		}
	})


func _log_combat_rally_encounter(npc_id: String, rally: Dictionary, encounter: Dictionary) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "combat_rally_encountered_enemy",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id, str(encounter.get("enemy_id", ""))],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 80,
		"payload": {
			"enemy_id": str(encounter.get("enemy_id", "")),
			"enemy_name": str(encounter.get("enemy_name", "")),
			"distance": float(encounter.get("distance", 0.0)),
			"previous_formation_row": str(rally.get("formation_row", "")),
			"unit_type": str(rally.get("unit_type", "")),
			"has_mount": bool(rally.get("has_mount", false))
		}
	})


func _log_avoidance_started(npc_id: String, encounter: Dictionary, target: Dictionary, reason: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "avoidance_started",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id, str(encounter.get("enemy_id", "")), str(target.get("target_id", ""))],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 75,
		"payload": {
			"enemy_id": str(encounter.get("enemy_id", "")),
			"enemy_name": str(encounter.get("enemy_name", "")),
			"distance": float(encounter.get("distance", 0.0)),
			"reason": reason,
			"target_id": str(target.get("target_id", "")),
			"target_name": str(target.get("target_name", AVOIDANCE_LOCATION_NAME)),
			"target_position": _vector3_to_dict(target.get("position", Vector3.ZERO))
		}
	})


func _log_avoidance_ended(npc_id: String, reason: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var active_count := get_active_enemy_count()
	var avoidance: Dictionary = _active_avoidances.get(npc_id, {}) if (_active_avoidances.get(npc_id, {}) is Dictionary) else {}
	return memory_system.add_event({
		"type": "avoidance_ended",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id, str(avoidance.get("target_id", ""))],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 70,
		"payload": {
			"reason": reason,
			"active_enemy_count": active_count,
			"target_id": str(avoidance.get("safe_target_id", "")),
			"target_name": str(avoidance.get("target_name", ""))
		}
	})


func _refresh_enemy_node(enemy_id: String) -> void:
	if not _active_enemies.has(enemy_id) or not _enemy_nodes.has(enemy_id):
		return
	var enemy_node := get_node_or_null(_enemy_nodes[enemy_id]) as Node3D
	if enemy_node == null:
		return
	var enemy: Dictionary = _active_enemies[enemy_id]
	enemy_node.global_position = enemy.get("position", enemy_node.global_position)
	var label := enemy_node.get_node_or_null("EnemyLabel") as Label3D
	if label == null:
		return
	var target: Dictionary = enemy.get("target", {}) if (enemy.get("target", {}) is Dictionary) else {}
	var target_name := str(target.get("name", "无目标"))
	label.text = "%s\nHP %d/%d · %s\n%s -> %s" % [
		str(enemy.get("name", "敌人")),
		int(enemy.get("hp", 0)),
		int(enemy.get("max_hp", 0)),
		_get_unit_type_label(str(enemy.get("unit_type", ""))),
		_format_enemy_action(str(enemy.get("current_action", ""))),
		target_name
	]


func _format_enemy_action(action: String) -> String:
	if action.begins_with("moving_to_"):
		return "移动"
	if action.begins_with("attacking_"):
		return "攻击"
	match action:
		"spawned":
			return "出现"
		"idle_no_target":
			return "无目标"
		_:
			return action


func _normalize_string_array(raw_value: Variant) -> Array[String]:
	var result: Array[String] = []
	var source: Array = raw_value if raw_value is Array else []
	for raw_item in source:
		var item := str(raw_item).strip_edges()
		if not item.is_empty():
			result.append(item)
	return result


func _get_wave_enemy_count(wave: Dictionary) -> int:
	var total := 0
	var enemies: Array = wave.get("enemies", [])
	for raw_enemy in enemies:
		var enemy: Dictionary = raw_enemy if raw_enemy is Dictionary else {}
		total += maxi(0, int(enemy.get("count", 0)))
	return total


func _extract_enemy_ids(enemies: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for enemy in enemies:
		result.append(str(enemy.get("id", "")))
	return result


func _clear_spawned_enemy_nodes() -> void:
	var enemy_root := get_node_or_null(ENEMY_ROOT_PATH)
	if enemy_root == null:
		return
	for child in enemy_root.get_children():
		child.queue_free()


func _make_node_name(id_value: String) -> String:
	var parts := id_value.split("_")
	var result := ""
	for part in parts:
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1).to_lower()
	if result.is_empty():
		return "Enemy"
	return result


func _failure(code: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": false,
		"error": code,
		"message": message
	}
	for key in extra.keys():
		result[key] = extra[key]
	_last_spawn_result = result.duplicate(true)
	return result


func _avoidance_failure(code: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": false,
		"error": code,
		"message": message
	}
	for key in extra.keys():
		result[key] = extra[key]
	_last_avoidance_result = result.duplicate(true)
	return result


func _alarm_failure(code: String, message: String) -> Dictionary:
	var result := {
		"ok": false,
		"error": code,
		"message": message
	}
	_last_alarm_result = result.duplicate(true)
	return result
