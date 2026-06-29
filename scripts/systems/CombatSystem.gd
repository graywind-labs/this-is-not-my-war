extends Node

const ENEMY_WAVES_FILE := "enemy_waves.json"
const ENEMY_ROOT_PATH := "/root/Main/WorldRoot/Station/Enemies"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const DEFAULT_SPAWN_POINT_ID := "front_forest"
const SYSTEM_ACTOR_ID := "system"
const COMBAT_TIME_CAP_REQUEST_ID := "combat_enemy_presence"
const COMBAT_TIME_CAP_SCALE := 1.0
const DEFAULT_TARGET_PREFERENCE: Array[String] = ["front_gate", "warehouse", "main_hall", "nearby_unit"]
const NEARBY_UNIT_TARGET_ID := "nearby_unit"
const MAIN_HALL_ID := "main_hall"
const PLAZA_LOCATION_ID := "plaza"
const ENEMY_DAMAGE_VISIBILITY := "local_public"
const DEFAULT_NEARBY_UNIT_DETECTION_RANGE := 6.0
const RALLY_ENCOUNTER_RANGE := 5.0
const FRIENDLY_CONTACT_RANGE := 5.0
const RALLY_WAIT_TIMEOUT_SECONDS := 3600.0
const MOVE_SPEED_GAME_SECONDS_DIVISOR := 60.0
const COMBAT_ACTION_GAME_SECONDS_PER_SECOND := 60.0
const MAX_ATTACKS_PER_AI_STEP := 100
const MAX_FRIENDLY_ATTACKS_PER_AI_STEP := 100
const DEFENSE_REDUCTION_PER_POINT := 0.04
const MAX_DEFENSE_DAMAGE_REDUCTION := 0.7
const STRENGTH_ATTACK_BASELINE := 5.0
const STRENGTH_ATTACK_BONUS_PER_POINT := 0.08
const MIN_STRENGTH_ATTACK_MULTIPLIER := 0.65
const MAX_STRENGTH_ATTACK_MULTIPLIER := 1.45
const SKILL_ATTACK_SPEED_BONUS_AT_100 := 0.35
const MOUNTED_ATTACK_SPEED_BONUS_AT_100_RIDING := 0.12
const FATIGUE_ATTACK_SPEED_PENALTY_START := 60.0
const FATIGUE_ATTACK_SPEED_MAX_PENALTY := 0.25
const SATIETY_ATTACK_SPEED_PENALTY_START := 35.0
const SATIETY_ATTACK_SPEED_MAX_PENALTY := 0.2
const MIN_ATTACK_SPEED_MULTIPLIER := 0.45
const MIN_NPC_ATTACK_INTERVAL := 0.25
const MORALE_BOOST_DURATION_SECONDS := 7200.0
const MORALE_BOOST_ATTACK_BONUS := 0.15
const MORALE_BOOST_MOVE_SPEED_BONUS := 0.15
const LOW_HP_JUDGEMENT_RATIO := 0.3
const FAILURE_REASON_MAIN_HALL_DESTROYED := "main_hall_destroyed"
const RALLY_TARGET_PREFIX := "combat_rally_"
const AVOIDANCE_TARGET_PREFIX := "avoid_shelter_"
const STRATEGY_MOVE_TARGET_PREFIX := "combat_strategy_"
const ESCAPE_TARGET_ID := "back_gate_escape_exit"
const ESCAPE_TARGET_NAME := "后门外出口"
const ESCAPE_INTERVENTION_MAX_ROUNDS := 5
const ESCAPE_STATUS_ESCAPING := "escaping"
const ESCAPE_STATUS_PAUSED_UNCONSCIOUS := "paused_unconscious"
const ESCAPE_STATUS_ESCAPED := "escaped"
const ESCAPE_STATUS_STAYED := "stayed"
const ESCAPE_DECISION_STAY := "stay"
const ESCAPE_DECISION_CONTINUE := "continue"
const ESCAPE_SPEED_DEFAULT_MULTIPLIER := 1.0
const ESCAPE_SPEED_MIN_MULTIPLIER := 0.35
const ESCAPE_SPEED_MAX_MULTIPLIER := 2.5
const ESCAPE_MONEY_SLOWDOWN_MIN_FACTOR := 0.65
const ESCAPE_ATTACK_SPEEDUP_FACTOR := 1.25
const RALLY_LOCATION_ID := "front_gate"
const RALLY_LOCATION_NAME := "城门外防线"
const AVOIDANCE_LOCATION_ID := PLAZA_LOCATION_ID
const AVOIDANCE_LOCATION_NAME := "驿站内避战点"
const ESCAPE_EXIT_POSITION := Vector3(-10.0, 0.0, -24.0)
const RALLY_FRONT_Z := 16.2
const RALLY_BACK_Z := 14.2
const RALLY_COLUMN_SPACING := 2.1
const RALLY_ROW_SPACING := 1.25
const AVOIDANCE_DESIRED_DISTANCE := 6.25
const AVOIDANCE_STEP_DISTANCE := 3.2
const AVOIDANCE_MIN_STEP_DISTANCE := 0.8
const AVOIDANCE_SCATTER_DEGREES := 38.0
const AVOIDANCE_SIDE_STEP_DEGREES := 22.0
const AVOIDANCE_MIN_X := -13.0
const AVOIDANCE_MAX_X := 13.0
const AVOIDANCE_MIN_Z := -12.5
const AVOIDANCE_MAX_Z := 6.5
const COMBAT_STRATEGY_MIN_X := -14.0
const COMBAT_STRATEGY_MAX_X := 14.0
const COMBAT_STRATEGY_MIN_Z := -12.5
const COMBAT_STRATEGY_MAX_Z := 18.5
const KEEP_DISTANCE_MIN_RANGE_RATIO := 0.45
const KEEP_DISTANCE_TARGET_RANGE_RATIO := 0.72
const KEEP_DISTANCE_MAX_RANGE_RATIO := 0.9
const COMBAT_APPROACH_RANGE_RATIO := 0.85
const CAVALRY_CHARGE_CLOSE_DISTANCE := 3.0
const CAVALRY_CHARGE_RESET_DISTANCE := 5.5
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
const WARTIME_REACTION_NONE := "none"
const WARTIME_REACTION_ESCAPE := "escape"
const WARTIME_REACTION_MORALE_BOOST := "morale_boost"
const WARTIME_REACTIONS: Array[String] = [WARTIME_REACTION_NONE, WARTIME_REACTION_ESCAPE, WARTIME_REACTION_MORALE_BOOST]
const BATTLE_DECISION_JOIN_BATTLE := "join_battle"
const BATTLE_DECISION_AVOID_BATTLE := "avoid_battle"
const BATTLE_DECISION_CONTINUE_FIGHTING := "continue_fighting"
const BATTLE_DECISION_ESCAPE_STATION := "escape_station"
const BATTLE_DECISION_INSPIRED := "inspired"
const BATTLE_DECISIONS: Array[String] = [
	BATTLE_DECISION_JOIN_BATTLE,
	BATTLE_DECISION_AVOID_BATTLE,
	BATTLE_DECISION_CONTINUE_FIGHTING,
	BATTLE_DECISION_ESCAPE_STATION,
	BATTLE_DECISION_INSPIRED
]
const STRATEGY_ATTACK := "attack"
const STRATEGY_MAX_OUTPUT := "max_output"
const STRATEGY_KEEP_DISTANCE := "keep_distance"
const STRATEGY_CHARGE_CYCLE := "charge_cycle"
const STRATEGY_AVOID := "avoid"
const COMBAT_STRATEGY_LABELS := {
	"attack": "主动进攻",
	"max_output": "最大化输出",
	"keep_distance": "保持距离射击",
	"charge_cycle": "拉开距离冲击",
	"avoid": "避战"
}
const COMBAT_STRATEGY_OPTIONS_BY_UNIT_TYPE := {
	"melee_infantry": ["attack", "avoid"],
	"polearm_infantry": ["attack", "avoid"],
	"archer": ["max_output", "keep_distance", "avoid"],
	"crossbowman": ["max_output", "keep_distance", "avoid"],
	"cavalry": ["attack", "charge_cycle", "avoid"],
	"mounted_ranged": ["max_output", "keep_distance", "avoid"]
}

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
var _active_escapes: Dictionary = {}
var _spawn_sequence := 0
var _last_spawn_result: Dictionary = {}
var _last_ai_step_result: Dictionary = {}
var _last_failure_result: Dictionary = {}
var _last_alarm_result: Dictionary = {}
var _last_mode_transition_result: Dictionary = {}
var _last_avoidance_result: Dictionary = {}
var _last_friendly_attack_result: Dictionary = {}
var _active_battle: Dictionary = {}
var _last_battle_start_result: Dictionary = {}
var _last_battle_end_result: Dictionary = {}
var _last_wartime_dialogue_result: Dictionary = {}
var _last_low_hp_judgement_result: Dictionary = {}
var _last_escape_result: Dictionary = {}


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
	_active_escapes.clear()
	_spawn_sequence = 0
	_last_spawn_result.clear()
	_last_ai_step_result.clear()
	_last_failure_result.clear()
	_last_alarm_result.clear()
	_last_mode_transition_result.clear()
	_last_avoidance_result.clear()
	_last_friendly_attack_result.clear()
	_active_battle.clear()
	_last_battle_start_result.clear()
	_last_battle_end_result.clear()
	_last_wartime_dialogue_result.clear()
	_last_low_hp_judgement_result.clear()
	_last_escape_result.clear()
	_sync_enemy_presence_time_cap("combat_initialize")

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


func get_combat_time_cap_snapshot() -> Dictionary:
	var snapshot := _get_time_scale_snapshot()
	return {
		"request_id": COMBAT_TIME_CAP_REQUEST_ID,
		"cap_scale": COMBAT_TIME_CAP_SCALE,
		"active_enemy_count": get_active_enemy_count(),
		"cap_expected": get_active_enemy_count() > 0,
		"time_scale": snapshot
	}


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

	var time_cap_result := _sync_enemy_presence_time_cap("enemies_spawned")
	var battle_start_result := _start_battle_for_wave(wave, spawned, "wave_spawned")
	_last_spawn_result = {
		"ok": true,
		"wave_number": wave_number,
		"wave_id": str(wave.get("id", "")),
		"spawned_count": spawned.size(),
		"active_enemy_count": get_active_enemy_count(),
		"spawned_enemy_ids": _extract_enemy_ids(spawned),
		"spawn_point": str(wave.get("spawn_point", DEFAULT_SPAWN_POINT_ID)),
		"spawn_position": _vector3_to_dict(_get_wave_spawn_position(wave)),
		"time_cap_result": time_cap_result,
		"battle_start_result": battle_start_result
	}
	return _last_spawn_result.duplicate(true)


func clear_spawned_enemies() -> Dictionary:
	var removed_count := _active_enemies.size()
	_clear_spawned_enemy_nodes()
	_active_enemies.clear()
	_enemy_nodes.clear()
	var time_cap_result := _sync_enemy_presence_time_cap("enemies_cleared")
	var mode_exit_result := _handle_all_enemies_cleared("enemies_cleared")
	_last_spawn_result = {
		"ok": true,
		"removed_count": removed_count,
		"active_enemy_count": 0,
		"time_cap_result": time_cap_result,
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
		"active_escapes": get_active_escapes(),
		"active_battle": _active_battle.duplicate(true),
		"behavior_modes": _get_behavior_mode_snapshots(),
		"combat_strategies": _get_combat_strategy_snapshots(),
		"last_alarm_result": get_last_alarm_result(),
		"last_spawn_result": get_last_spawn_result(),
		"last_ai_step_result": _last_ai_step_result.duplicate(true),
		"last_friendly_attack_result": _last_friendly_attack_result.duplicate(true),
		"last_failure_result": _last_failure_result.duplicate(true),
		"last_mode_transition_result": _last_mode_transition_result.duplicate(true),
		"last_avoidance_result": _last_avoidance_result.duplicate(true),
		"last_battle_start_result": _last_battle_start_result.duplicate(true),
		"last_battle_end_result": _last_battle_end_result.duplicate(true),
		"last_wartime_dialogue_result": _last_wartime_dialogue_result.duplicate(true),
		"last_low_hp_judgement_result": _last_low_hp_judgement_result.duplicate(true),
		"last_escape_result": _last_escape_result.duplicate(true),
		"time_scale": _get_time_scale_snapshot()
	}


func get_active_escapes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_npc_id in _active_escapes.keys():
		var escape: Dictionary = _active_escapes[raw_npc_id]
		result.append(escape.duplicate(true))
	return result


func debug_start_npc_escape(npc_id: String, trigger: String = "gm_debug") -> Dictionary:
	return start_npc_escape(npc_id, "", trigger, {
		"trigger": trigger,
		"interaction_context": "gm_debug"
	})


func debug_step_enemy_ai(game_seconds: float = 60.0) -> Dictionary:
	var seconds := maxf(0.0, game_seconds)
	_advance_rally_units(seconds)
	if _active_enemies.is_empty():
		return _advance_combat_ai(seconds)
	_advance_behavior_mode_contacts()
	_advance_avoidance_units()
	var result := _advance_combat_ai(seconds)
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
	if _is_npc_combat_eligible(npc_id, npc_system):
		return _avoidance_failure("npc_combat_eligible", "已入伍且有主武器的 NPC 会进入战斗，不进入非战斗避战模式。", {"npc_id": npc_id})
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


func build_battlefield_context(target_npc_id: String = "", interaction_context: String = "") -> Dictionary:
	var friendly_roster := _build_friendly_combatant_roster()
	var enemy_roster := _build_active_enemy_battlefield_roster()
	var noncombatants := _build_noncombatant_battlefield_roster()
	return {
		"interaction_context": interaction_context,
		"active_enemy_count": get_active_enemy_count(),
		"enemy_count": enemy_roster.size(),
		"friendly_combatant_count": friendly_roster.size(),
		"noncombatant_count": noncombatants.size(),
		"enemy_roster": enemy_roster,
		"friendly_roster": friendly_roster,
		"station_noncombatants": noncombatants,
		"participating_npcs": _extract_battlefield_npc_ids(friendly_roster),
		"target_npc": _build_battlefield_target_snapshot(target_npc_id),
		"active_battle": _active_battle.duplicate(true)
	}


func apply_wartime_dialogue_reaction(npc_id: String, reaction: String, context: Dictionary = {}) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("update_npc_state"):
		return _wartime_reaction_failure("npc_system_missing", "NPC 系统不可用。", npc_id, reaction)
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _wartime_reaction_failure("unknown_npc", "NPC 不存在。", npc_id, reaction)
	var mode := _get_npc_behavior_mode(npc_system, npc_id)
	if not [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(mode):
		return _wartime_reaction_failure("not_rally_or_combat", "只有集结或战斗中的可战斗 NPC 会产生战时心理结算。", npc_id, reaction, {"behavior_mode": mode})
	if not _is_npc_combat_eligible(npc_id, npc_system):
		return _wartime_reaction_failure("not_combat_eligible", "NPC 未入伍或没有主武器。", npc_id, reaction, {"behavior_mode": mode})

	var clean_reaction := _normalize_wartime_reaction(reaction)
	var battlefield_context := build_battlefield_context(npc_id, str(context.get("interaction_context", mode)))
	var source_event_id := str(context.get("source_event_id", ""))
	var result_event := _log_battle_psychology_result(npc_id, clean_reaction, context, battlefield_context)
	var state_result := {}
	match clean_reaction:
		WARTIME_REACTION_MORALE_BOOST:
			state_result = _start_morale_boost(npc_id, source_event_id)
		WARTIME_REACTION_ESCAPE:
			state_result = _start_escape_intent(npc_id, source_event_id, context)
		_:
			state_result = {"ok": true, "applied": false, "reason": "none"}
	_last_wartime_dialogue_result = {
		"ok": true,
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"reaction": clean_reaction,
		"behavior_mode": mode,
		"source_event_id": source_event_id,
		"battle_psychology_event": result_event,
		"state_result": state_result
	}
	return _last_wartime_dialogue_result.duplicate(true)


func start_npc_escape(
	npc_id: String,
	source_event_id: String = "",
	trigger: String = "manual",
	context: Dictionary = {}
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("get_npc_state"):
		return _escape_failure("npc_system_missing", "NPC 系统不可用。", npc_id)
	if not npc_system.has_method("set_npc_behavior_mode") or not npc_system.has_method("move_npc_to_world_position"):
		return _escape_failure("npc_system_missing_escape_api", "NPC 系统缺少逃离所需接口。", npc_id)
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _escape_failure("unknown_npc", "NPC 不存在。", npc_id)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if bool(state.get("escaped", false)):
		return _escape_failure("already_escaped", "NPC 已经离开驿站。", npc_id)
	if bool(state.get("unconscious", false)):
		return _escape_failure("npc_unconscious", "昏迷 NPC 不能逃离。", npc_id)
	var existing_intent: Dictionary = state.get("escape_intent", {}) if state.get("escape_intent", {}) is Dictionary else {}
	if bool(existing_intent.get("active", false)) and str(existing_intent.get("status", "")) == ESCAPE_STATUS_ESCAPING:
		var existing_result := {
			"ok": true,
			"applied": false,
			"reason": "already_escaping",
			"npc_id": npc_id,
			"escape_intent": existing_intent.duplicate(true)
		}
		_last_escape_result = existing_result.duplicate(true)
		return existing_result

	var clean_trigger := trigger.strip_edges()
	if clean_trigger.is_empty():
		clean_trigger = str(context.get("trigger", "manual"))
	var clean_source_event_id := source_event_id.strip_edges()
	if clean_source_event_id.is_empty():
		clean_source_event_id = str(context.get("source_event_id", ""))
	var previous_mode := _get_npc_behavior_mode(npc_system, npc_id)
	var event := _log_escape_started(npc_id, clean_source_event_id, clean_trigger, context, previous_mode)
	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_ESCAPED, "escape_started", {
		"interrupt": true,
		"stop_movement": true,
		"suppress_mode_event": true,
		"request_plan_reevaluation": false,
		"state_changes": {
			"escaped": false,
			"current_action": "escaping_station",
			"last_action_result": "escape_started",
			"combat_target_enemy_id": "",
			"morale_boost": {}
		}
	})
	if not bool(mode_result.get("ok", false)):
		return _escape_failure("mode_switch_failed", "无法切换到逃离状态。", npc_id, {"mode_result": mode_result})

	var arrival_state := {
		"escape_finalize": true,
		"allow_escaping_movement": true,
		"escape_reason": "escape_completed",
		"escape_trigger": clean_trigger,
		"source_event_id": clean_source_event_id,
		"exit_target_id": ESCAPE_TARGET_ID,
		"exit_target_name": ESCAPE_TARGET_NAME
	}
	var moved := bool(npc_system.move_npc_to_world_position(npc_id, ESCAPE_TARGET_ID, ESCAPE_TARGET_NAME, ESCAPE_EXIT_POSITION, arrival_state))
	if not moved:
		return _escape_failure("movement_failed", "无法让 NPC 前往后门出口。", npc_id, {"mode_result": mode_result})

	var time_snapshot := _get_game_time_snapshot()
	var escape_intent := {
		"active": true,
		"status": ESCAPE_STATUS_ESCAPING,
		"source_event_id": clean_source_event_id,
		"escape_started_event_id": str(event.get("event_id", "")),
		"trigger": clean_trigger,
		"interaction_context": str(context.get("interaction_context", previous_mode)),
		"exit_target_id": ESCAPE_TARGET_ID,
		"exit_target_name": ESCAPE_TARGET_NAME,
		"exit_position": _vector3_to_dict(ESCAPE_EXIT_POSITION),
		"intervention_rounds_used": 0,
		"intervention_max_rounds": ESCAPE_INTERVENTION_MAX_ROUNDS,
		"last_intervention_decision": "",
		"last_intervention_intent": "",
		"speed_multiplier": ESCAPE_SPEED_DEFAULT_MULTIPLIER,
		"money_slow_count": 0,
		"attack_speed_count": 0,
		"started_day": int(time_snapshot.get("day", 1)),
		"started_time": str(time_snapshot.get("time", "00:00:00"))
	}
	npc_system.update_npc_state(npc_id, {
		"escape_intent": escape_intent,
		"current_action": "escaping_station",
		"last_action_result": "escaping_to_back_gate"
	})
	var result := {
		"ok": true,
		"applied": true,
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"previous_mode": previous_mode,
		"behavior_mode": BEHAVIOR_MODE_ESCAPED,
		"escape_intent": escape_intent.duplicate(true),
		"event": event,
		"mode_result": mode_result,
		"target_id": ESCAPE_TARGET_ID,
		"target_name": ESCAPE_TARGET_NAME,
		"target_position": _vector3_to_dict(ESCAPE_EXIT_POSITION)
	}
	_active_escapes[npc_id] = result.duplicate(true)
	_last_escape_result = result.duplicate(true)
	return result


func handle_npc_escape_completed(npc_id: String, escaped_state: Dictionary = {}) -> Dictionary:
	var completion := {
		"ok": true,
		"npc_id": npc_id,
		"status": ESCAPE_STATUS_ESCAPED,
		"escaped_state": escaped_state.duplicate(true)
	}
	_active_escapes.erase(npc_id)
	_last_escape_result = completion.duplicate(true)
	return completion


func is_npc_escaping(npc_id: String) -> bool:
	var state := _get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	if not bool(intent.get("active", false)):
		return false
	return [ESCAPE_STATUS_ESCAPING, ESCAPE_STATUS_PAUSED_UNCONSCIOUS].has(str(intent.get("status", "")))


func get_escape_intervention_state(npc_id: String) -> Dictionary:
	var state := _get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	var rounds_used := clampi(int(intent.get("intervention_rounds_used", 0)), 0, ESCAPE_INTERVENTION_MAX_ROUNDS)
	var status := str(intent.get("status", ""))
	var can_dialogue := (
		bool(intent.get("active", false))
		and status == ESCAPE_STATUS_ESCAPING
		and not bool(state.get("escaped", false))
		and not bool(state.get("unconscious", false))
		and rounds_used < ESCAPE_INTERVENTION_MAX_ROUNDS
	)
	return {
		"ok": true,
		"npc_id": npc_id,
		"escaping": is_npc_escaping(npc_id),
		"status": status,
		"can_dialogue": can_dialogue,
		"rounds_used": rounds_used,
		"max_rounds": ESCAPE_INTERVENTION_MAX_ROUNDS,
		"rounds_left": maxi(0, ESCAPE_INTERVENTION_MAX_ROUNDS - rounds_used),
		"escape_intent": intent.duplicate(true)
	}


func pause_escape_for_dialogue(npc_id: String, dialogue_id: String = "") -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_state") or not npc_system.has_method("stop_npc_movement_with_state"):
		return _escape_failure("npc_system_missing", "NPC 系统不可用。", npc_id)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	if not bool(intent.get("active", false)) or str(intent.get("status", "")) != ESCAPE_STATUS_ESCAPING:
		return _escape_failure("escape_not_active", "该 NPC 当前没有正在逃离。", npc_id)
	if bool(state.get("escaped", false)) or bool(state.get("unconscious", false)):
		return _escape_failure("escape_not_intervenable", "该 NPC 当前无法暂停逃离挽留。", npc_id)
	intent["movement_paused_for_dialogue"] = true
	intent["paused_dialogue_id"] = dialogue_id
	intent["paused_dialogue_day"] = int(_get_game_time_snapshot().get("day", 1))
	intent["paused_dialogue_time"] = str(_get_game_time_snapshot().get("time", "00:00:00"))
	var stopped := bool(npc_system.stop_npc_movement_with_state(npc_id, {
		"escape_intent": intent,
		"current_action": "escape_intervention_dialogue",
		"last_action_result": "escape_intervention_dialogue_paused",
		"movement_target": "",
		"movement_target_name": ""
	}))
	var snapshot := _sync_active_escape_from_state(npc_id)
	var result := {
		"ok": stopped,
		"applied": stopped,
		"npc_id": npc_id,
		"status": str(intent.get("status", ESCAPE_STATUS_ESCAPING)),
		"escape_intent": intent.duplicate(true),
		"snapshot": snapshot
	}
	_last_escape_result = result.duplicate(true)
	return result


func resume_escape_after_dialogue(npc_id: String, reason: String = "escape_dialogue_closed") -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system == null
		or not npc_system.has_method("get_npc_state")
		or not npc_system.has_method("update_npc_state")
		or not npc_system.has_method("move_npc_to_world_position")
	):
		return _escape_failure("npc_system_missing", "NPC 系统不可用。", npc_id)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	if not _is_escape_intent_resumable(intent):
		return {"ok": true, "applied": false, "active_escape": false, "reason": "no_active_escape", "npc_id": npc_id}
	if bool(state.get("escaped", false)):
		return {"ok": true, "applied": false, "active_escape": false, "reason": "already_escaped", "npc_id": npc_id}
	if bool(state.get("unconscious", false)) or str(intent.get("status", "")) == ESCAPE_STATUS_PAUSED_UNCONSCIOUS:
		return {"ok": true, "applied": false, "active_escape": true, "reason": "npc_unconscious", "npc_id": npc_id}
	intent["active"] = true
	intent["status"] = ESCAPE_STATUS_ESCAPING
	intent["movement_paused_for_dialogue"] = false
	intent["last_dialogue_resume_reason"] = reason
	intent["last_dialogue_resume_day"] = int(_get_game_time_snapshot().get("day", 1))
	intent["last_dialogue_resume_time"] = str(_get_game_time_snapshot().get("time", "00:00:00"))
	var arrival_state := {
		"escape_finalize": true,
		"allow_escaping_movement": true,
		"escape_reason": "escape_completed",
		"escape_trigger": str(intent.get("trigger", "dialogue_resume")),
		"source_event_id": str(intent.get("source_event_id", "")),
		"exit_target_id": ESCAPE_TARGET_ID,
		"exit_target_name": ESCAPE_TARGET_NAME
	}
	var moved := bool(npc_system.move_npc_to_world_position(npc_id, ESCAPE_TARGET_ID, ESCAPE_TARGET_NAME, ESCAPE_EXIT_POSITION, arrival_state))
	if not moved:
		return _escape_failure("movement_failed", "无法让 NPC 继续前往后门出口。", npc_id, {"active_escape": true})
	npc_system.update_npc_state(npc_id, {
		"escape_intent": intent,
		"current_action": "escaping_station",
		"last_action_result": reason
	})
	var snapshot := _sync_active_escape_from_state(npc_id)
	var result := {
		"ok": true,
		"applied": true,
		"active_escape": true,
		"npc_id": npc_id,
		"status": ESCAPE_STATUS_ESCAPING,
		"escape_intent": intent.duplicate(true),
		"snapshot": snapshot
	}
	_last_escape_result = result.duplicate(true)
	return result


func apply_escape_intervention_result(npc_id: String, response: Dictionary, context: Dictionary = {}) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system == null
		or not npc_system.has_method("get_npc")
		or not npc_system.has_method("get_npc_state")
		or not npc_system.has_method("update_npc_state")
	):
		return _escape_failure("npc_system_missing", "NPC 系统不可用。", npc_id)
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _escape_failure("unknown_npc", "NPC 不存在。", npc_id)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	if not bool(intent.get("active", false)):
		return _escape_failure("escape_not_active", "NPC 当前没有正在进行的逃离。", npc_id)
	var status := str(intent.get("status", ""))
	if not [ESCAPE_STATUS_ESCAPING, ESCAPE_STATUS_PAUSED_UNCONSCIOUS].has(status):
		return _escape_failure("escape_not_intervenable", "该逃离状态不能被挽留。", npc_id, {"status": status})

	var previous_rounds := clampi(int(intent.get("intervention_rounds_used", 0)), 0, ESCAPE_INTERVENTION_MAX_ROUNDS)
	var current_round := clampi(int(context.get("current_round", previous_rounds + 1)), 1, ESCAPE_INTERVENTION_MAX_ROUNDS)
	var rounds_used := maxi(previous_rounds, current_round)
	var response_intent := str(response.get("intent", ""))
	var decision := _normalize_escape_intervention_decision(response_intent)
	intent["intervention_rounds_used"] = rounds_used
	intent["intervention_max_rounds"] = ESCAPE_INTERVENTION_MAX_ROUNDS
	intent["last_intervention_intent"] = response_intent
	intent["last_intervention_decision"] = decision
	intent["last_intervention_reply"] = str(response.get("reply_text", ""))
	intent["last_intervention_dialogue_event_id"] = str(context.get("dialogue_event_id", ""))
	intent["last_intervention_dialogue_id"] = str(context.get("dialogue_id", ""))
	intent["last_intervention_day"] = int(_get_game_time_snapshot().get("day", 1))
	intent["last_intervention_time"] = str(_get_game_time_snapshot().get("time", "00:00:00"))
	if not intent.has("speed_multiplier"):
		intent["speed_multiplier"] = ESCAPE_SPEED_DEFAULT_MULTIPLIER

	var event := _log_escape_intervention_result(npc_id, decision, intent, response, context)
	var result := {
		"ok": true,
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"decision": decision,
		"intent": response_intent,
		"rounds_used": rounds_used,
		"max_rounds": ESCAPE_INTERVENTION_MAX_ROUNDS,
		"rounds_left": maxi(0, ESCAPE_INTERVENTION_MAX_ROUNDS - rounds_used),
		"event": event
	}
	if decision == ESCAPE_DECISION_STAY:
		intent["active"] = false
		intent["status"] = ESCAPE_STATUS_STAYED
		intent["stayed_day"] = int(_get_game_time_snapshot().get("day", 1))
		intent["stayed_time"] = str(_get_game_time_snapshot().get("time", "00:00:00"))
		intent["stayed_event_id"] = str(event.get("event_id", ""))
		if npc_system.has_method("stop_npc_movement_with_state"):
			npc_system.stop_npc_movement_with_state(npc_id, {
				"movement_target": "",
				"movement_target_name": ""
			})
		var mode_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, "escape_intervention_stayed", {
			"force_idle": true,
			"request_plan_reevaluation": true,
			"state_changes": {
				"escaped": false,
				"escape_intent": intent,
				"current_action": "idle",
				"last_action_result": "escape_intervention_stayed"
			}
		}) if npc_system.has_method("set_npc_behavior_mode") else {}
		_active_escapes.erase(npc_id)
		result["state_result"] = mode_result
		result["escape_intent"] = intent.duplicate(true)
	else:
		if status != ESCAPE_STATUS_PAUSED_UNCONSCIOUS:
			intent["status"] = ESCAPE_STATUS_ESCAPING
		npc_system.update_npc_state(npc_id, {
			"escape_intent": intent,
			"last_action_result": "escape_intervention_continue"
		})
		result["state_result"] = {"ok": true, "status": intent.get("status", ESCAPE_STATUS_ESCAPING)}
		result["escape_intent"] = intent.duplicate(true)
		_sync_active_escape_from_state(npc_id)
	_last_escape_result = result.duplicate(true)
	return result


func handle_escape_money_given(npc_id: String, amount: int, source_event: Dictionary = {}) -> Dictionary:
	var state := _get_npc_state(npc_id)
	if bool(state.get("unconscious", false)):
		return {"ok": true, "applied": false, "reason": "npc_unconscious", "npc_id": npc_id}
	var factor := clampf(1.0 - minf(float(maxi(amount, 0)), 20.0) * 0.02, ESCAPE_MONEY_SLOWDOWN_MIN_FACTOR, 0.98)
	return _change_escape_speed_multiplier(npc_id, "money_given", factor, {
		"amount": amount,
		"source_event_id": str(source_event.get("event_id", source_event.get("id", "")))
	})


func handle_escape_guard_attack(npc_id: String, damage: int, source_event: Dictionary = {}, became_unconscious: bool = false) -> Dictionary:
	var speed_result := _change_escape_speed_multiplier(npc_id, "guard_attack", ESCAPE_ATTACK_SPEEDUP_FACTOR, {
		"damage": damage,
		"source_event_id": str(source_event.get("event_id", source_event.get("id", "")))
	})
	var pause_result := {}
	if became_unconscious:
		pause_result = _pause_escape_for_unconscious(npc_id, "guard_attack_unconscious")
	if not bool(speed_result.get("applied", false)) and pause_result.is_empty():
		return speed_result
	var result := speed_result.duplicate(true)
	result["pause_result"] = pause_result
	return result


func record_escape_attack_intervention_round(npc_id: String, current_round: int, context: Dictionary = {}) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_state") or not npc_system.has_method("update_npc_state"):
		return _escape_failure("npc_system_missing", "NPC 系统不可用。", npc_id)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	if not _is_escape_intent_resumable(intent):
		return _escape_failure("escape_not_active", "NPC 当前没有正在进行的逃离。", npc_id)
	var previous_rounds := clampi(int(intent.get("intervention_rounds_used", 0)), 0, ESCAPE_INTERVENTION_MAX_ROUNDS)
	var rounds_used := clampi(maxi(previous_rounds, current_round), 0, ESCAPE_INTERVENTION_MAX_ROUNDS)
	intent["intervention_rounds_used"] = rounds_used
	intent["intervention_max_rounds"] = ESCAPE_INTERVENTION_MAX_ROUNDS
	intent["last_intervention_intent"] = "guard_attack_no_reply"
	intent["last_intervention_decision"] = ESCAPE_DECISION_CONTINUE
	intent["last_intervention_reply"] = ""
	intent["last_intervention_dialogue_event_id"] = ""
	intent["last_intervention_dialogue_id"] = str(context.get("dialogue_id", ""))
	intent["last_intervention_source_event_id"] = str(context.get("source_event_id", ""))
	intent["last_intervention_day"] = int(_get_game_time_snapshot().get("day", 1))
	intent["last_intervention_time"] = str(_get_game_time_snapshot().get("time", "00:00:00"))
	if not intent.has("speed_multiplier"):
		intent["speed_multiplier"] = ESCAPE_SPEED_DEFAULT_MULTIPLIER
	npc_system.update_npc_state(npc_id, {
		"escape_intent": intent,
		"last_action_result": "escape_intervention_attack_continue"
	})
	var snapshot := _sync_active_escape_from_state(npc_id)
	var result := {
		"ok": true,
		"npc_id": npc_id,
		"decision": ESCAPE_DECISION_CONTINUE,
		"intent": "guard_attack_no_reply",
		"rounds_used": rounds_used,
		"max_rounds": ESCAPE_INTERVENTION_MAX_ROUNDS,
		"rounds_left": maxi(0, ESCAPE_INTERVENTION_MAX_ROUNDS - rounds_used),
		"event": {},
		"escape_intent": intent.duplicate(true),
		"snapshot": snapshot
	}
	_last_escape_result = result.duplicate(true)
	return result


func handle_npc_damage_applied(damage_result: Dictionary, context: Dictionary = {}) -> Dictionary:
	if damage_result.is_empty() or not bool(damage_result.get("ok", false)):
		return _low_hp_judgement_skip("invalid_damage_result", "", damage_result, context)
	if _active_battle.is_empty() or get_active_enemy_count() <= 0:
		return _low_hp_judgement_skip("no_active_battle", str(damage_result.get("npc_id", "")), damage_result, context)
	var npc_id := str(damage_result.get("npc_id", ""))
	if npc_id.is_empty():
		return _low_hp_judgement_skip("empty_npc_id", npc_id, damage_result, context)
	var max_hp := maxi(1, int(damage_result.get("max_hp", 100)))
	var hp_before := clampi(int(damage_result.get("hp_before", max_hp)), 0, max_hp)
	var hp_after := clampi(int(damage_result.get("hp_after", hp_before)), 0, max_hp)
	if hp_after <= 0:
		return _low_hp_judgement_skip("became_unconscious", npc_id, damage_result, context)
	if float(hp_before) / float(max_hp) < LOW_HP_JUDGEMENT_RATIO:
		return _low_hp_judgement_skip("already_below_threshold", npc_id, damage_result, context)
	if float(hp_after) / float(max_hp) >= LOW_HP_JUDGEMENT_RATIO:
		return _low_hp_judgement_skip("above_threshold", npc_id, damage_result, context)

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("get_npc_state"):
		return _low_hp_judgement_failure("npc_system_missing", "NPC 系统不可用。", npc_id, damage_result, context)
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _low_hp_judgement_failure("unknown_npc", "NPC 不存在。", npc_id, damage_result, context)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if bool(state.get("unconscious", false)) or bool(state.get("escaped", false)):
		return _low_hp_judgement_skip("npc_unconscious_or_escaped", npc_id, damage_result, context)
	if _has_low_hp_judgement_for_active_battle(npc_id):
		return _low_hp_judgement_skip("already_triggered_this_battle", npc_id, damage_result, context)

	var mode := _get_npc_behavior_mode(npc_system, npc_id)
	var combatant_decisions_allowed := mode == BEHAVIOR_MODE_COMBAT and _is_npc_combat_eligible(npc_id, npc_system)
	var allowed_decisions := _get_low_hp_allowed_decisions(combatant_decisions_allowed)
	var battlefield_context := build_battlefield_context(npc_id, mode)
	var low_hp_event := _log_low_hp_triggered(npc_id, damage_result, context, mode, combatant_decisions_allowed)
	var damage_event: Dictionary = damage_result.get("damage_event", {}) if damage_result.get("damage_event", {}) is Dictionary else {}
	_mark_low_hp_judgement_for_active_battle(npc_id, {
		"status": "pending",
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"behavior_mode": mode,
		"combatant_decisions_allowed": combatant_decisions_allowed,
		"allowed_decisions": allowed_decisions,
		"low_hp_event_id": str(low_hp_event.get("event_id", "")),
		"damage_event_id": str(damage_event.get("event_id", ""))
	})

	var dialogue_result := _force_end_dialogue_for_low_hp(npc_id)
	var llm_result := _request_low_hp_battle_judgement(npc_id, low_hp_event, damage_result, context, battlefield_context, allowed_decisions, mode)
	var judgement: Dictionary = llm_result.get("battle_judgement", {}) if (llm_result.get("battle_judgement", {}) is Dictionary) else {}
	if not bool(llm_result.get("ok", false)) or judgement.is_empty():
		judgement = _make_low_hp_rule_fallback_judgement(npc_id, allowed_decisions, llm_result)
	var applied := _apply_low_hp_judgement_result(npc_id, judgement, {
		"low_hp_event": low_hp_event,
		"damage_result": damage_result,
		"damage_context": context,
		"battlefield_context": battlefield_context,
		"allowed_decisions": allowed_decisions,
		"behavior_mode": mode,
		"combatant_decisions_allowed": combatant_decisions_allowed,
		"dialogue_result": dialogue_result,
		"llm_result": llm_result
	})
	return applied


func get_combat_strategy_options_for_unit_type(unit_type: String) -> Array[Dictionary]:
	var option_ids: Array = COMBAT_STRATEGY_OPTIONS_BY_UNIT_TYPE.get(unit_type, [])
	var result: Array[Dictionary] = []
	for index in range(option_ids.size()):
		var strategy_id := str(option_ids[index])
		result.append({
			"id": strategy_id,
			"label": _get_combat_strategy_label(strategy_id),
			"is_default": index == 0
		})
	return result


func get_npc_combat_strategy_options(npc_id: String) -> Array[Dictionary]:
	var snapshot := _get_npc_unit_type_snapshot(npc_id)
	if snapshot.is_empty() or not bool(snapshot.get("has_main_weapon", false)):
		return []
	return get_combat_strategy_options_for_unit_type(str(snapshot.get("unit_type", "")))


func get_npc_combat_strategy(npc_id: String) -> Dictionary:
	var snapshot := _get_npc_unit_type_snapshot(npc_id)
	if snapshot.is_empty() or not bool(snapshot.get("has_main_weapon", false)):
		return {}
	var unit_type := str(snapshot.get("unit_type", ""))
	var options := get_combat_strategy_options_for_unit_type(unit_type)
	if options.is_empty():
		return {}
	var state := _get_npc_state(npc_id)
	var selected_id := _extract_combat_strategy_id(state.get("combat_strategy", {}))
	if not _strategy_options_have_id(options, selected_id):
		selected_id = str(options[0].get("id", ""))
	return {
		"npc_id": npc_id,
		"id": selected_id,
		"label": _get_combat_strategy_label(selected_id),
		"unit_type": unit_type,
		"unit_type_label": str(snapshot.get("unit_type_label", "")),
		"options": options
	}


func set_npc_combat_strategy(
	npc_id: String,
	strategy_id: String,
	visibility: String = "local_public",
	reason: String = "manual"
) -> Dictionary:
	return _set_npc_combat_strategy(npc_id, strategy_id, visibility, reason, true)


func normalize_npc_combat_strategy(
	npc_id: String,
	reason: String = "equipment_changed",
	visibility: String = "local_public",
	force_default: bool = false
) -> Dictionary:
	var snapshot := _get_npc_unit_type_snapshot(npc_id)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("update_npc_state"):
		return {"ok": false, "error": "npc_system_missing", "npc_id": npc_id}
	if snapshot.is_empty() or not bool(snapshot.get("has_main_weapon", false)):
		npc_system.update_npc_state(npc_id, {"combat_strategy": {}})
		return {"ok": true, "npc_id": npc_id, "changed": false, "strategy": {}, "reason": "no_main_weapon"}
	var options := get_combat_strategy_options_for_unit_type(str(snapshot.get("unit_type", "")))
	if options.is_empty():
		npc_system.update_npc_state(npc_id, {"combat_strategy": {}})
		return {"ok": true, "npc_id": npc_id, "changed": false, "strategy": {}, "reason": "no_strategy_options"}
	var state := _get_npc_state(npc_id)
	var current_id := _extract_combat_strategy_id(state.get("combat_strategy", {}))
	if force_default:
		var default_id := str(options[0].get("id", ""))
		if current_id == default_id:
			return {"ok": true, "npc_id": npc_id, "changed": false, "strategy": get_npc_combat_strategy(npc_id), "reason": "already_default"}
		return _set_npc_combat_strategy(npc_id, default_id, visibility, reason, true)
	if _strategy_options_have_id(options, current_id):
		return {"ok": true, "npc_id": npc_id, "changed": false, "strategy": get_npc_combat_strategy(npc_id), "reason": "already_valid"}
	return _set_npc_combat_strategy(npc_id, str(options[0].get("id", "")), visibility, reason, true)


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	_advance_morale_boosts(game_delta_seconds)
	_advance_rally_units(game_delta_seconds)
	if _active_enemies.is_empty():
		return
	_advance_behavior_mode_contacts()
	_advance_avoidance_units()
	_advance_combat_ai(game_delta_seconds)
	_advance_avoidance_units()


func _advance_combat_ai(game_delta_seconds: float) -> Dictionary:
	var combat_delta_seconds := _get_combat_action_seconds(game_delta_seconds)
	var friendly_result := _advance_friendly_combat_ai(combat_delta_seconds, game_delta_seconds)
	var enemy_result := _advance_enemy_ai(game_delta_seconds, combat_delta_seconds)
	enemy_result["combat_seconds"] = combat_delta_seconds
	enemy_result["friendly_attacks"] = friendly_result
	_last_ai_step_result = enemy_result.duplicate(true)
	return enemy_result


func _advance_friendly_combat_ai(combat_delta_seconds: float, game_delta_seconds: float = 0.0) -> Dictionary:
	var result := {
		"ok": true,
		"game_seconds": game_delta_seconds,
		"combat_seconds": combat_delta_seconds,
		"attacks": [],
		"ready_count": 0,
		"skipped": []
	}
	if combat_delta_seconds <= 0.0 or _active_enemies.is_empty():
		_last_friendly_attack_result = result.duplicate(true)
		return result

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		_last_friendly_attack_result = result.duplicate(true)
		return result

	for raw_npc_id in npc_system.get_npc_ids():
		if _active_enemies.is_empty():
			break
		var npc_id := str(raw_npc_id)
		var mode := _get_npc_behavior_mode(npc_system, npc_id)
		if mode != BEHAVIOR_MODE_COMBAT:
			continue
		if not _is_npc_combat_eligible(npc_id, npc_system):
			(result["skipped"] as Array).append({"npc_id": npc_id, "reason": "not_combat_eligible"})
			continue
		if npc_system.has_method("can_npc_act") and not npc_system.can_npc_act(npc_id):
			(result["skipped"] as Array).append({"npc_id": npc_id, "reason": "cannot_act"})
			continue
		var attack_result := _advance_single_npc_combat_attack(npc_id, combat_delta_seconds)
		if attack_result.is_empty():
			continue
		result["ready_count"] = int(result.get("ready_count", 0)) + 1
		(result["attacks"] as Array).append(attack_result)

	if _active_enemies.is_empty():
		result["mode_exit_result"] = _handle_all_enemies_cleared("enemies_defeated")

	_last_friendly_attack_result = result.duplicate(true)
	return result


func _advance_single_npc_combat_attack(npc_id: String, combat_delta_seconds: float) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("get_npc_state"):
		return {}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var attack_context := _calculate_npc_attack_context(npc_id, npc, state)
	if attack_context.is_empty():
		return {}
	var strategy := get_npc_combat_strategy(npc_id)
	if not strategy.is_empty():
		attack_context["strategy_id"] = str(strategy.get("id", ""))
		attack_context["strategy_label"] = str(strategy.get("label", ""))
		attack_context["unit_type"] = str(strategy.get("unit_type", ""))
		attack_context["unit_type_label"] = str(strategy.get("unit_type_label", ""))

	var remaining := maxf(0.0, combat_delta_seconds)
	var cooldown := maxf(0.0, float(state.get("combat_attack_cooldown", 0.0)))
	var attacks: Array[Dictionary] = []
	var target := _select_npc_attack_target(npc_id, attack_context)
	var strategy_movement := _advance_npc_combat_strategy_movement(npc_id, state, attack_context, target)
	if not strategy_movement.is_empty():
		cooldown = maxf(0.0, cooldown - remaining)
		if npc_system.has_method("update_npc_state"):
			npc_system.update_npc_state(npc_id, {
				"combat_attack_cooldown": cooldown,
				"combat_last_attack_result": {},
				"last_action_result": str(strategy_movement.get("reason", "combat_strategy_movement"))
			})
		return {
			"npc_id": npc_id,
			"npc_name": str(npc.get("name", npc_id)),
			"attack_count": 0,
			"target": _serialize_target(target),
			"attack_context": attack_context,
			"combat_seconds": combat_delta_seconds,
			"cooldown": cooldown,
			"strategy_movement": strategy_movement,
			"reason": str(strategy_movement.get("reason", "combat_strategy_movement"))
		}

	if target.is_empty():
		cooldown = maxf(0.0, cooldown - remaining)
		if npc_system.has_method("update_npc_state"):
			npc_system.update_npc_state(npc_id, {
				"combat_attack_cooldown": cooldown,
				"combat_last_attack_result": {},
				"last_action_result": "combat_no_enemy_in_range"
			})
		return {
			"npc_id": npc_id,
			"attack_count": 0,
			"target": {},
			"attack_context": attack_context,
			"combat_seconds": combat_delta_seconds,
			"cooldown": cooldown,
			"reason": "no_enemy_in_range"
		}

	while remaining > 0.0 and attacks.size() < MAX_FRIENDLY_ATTACKS_PER_AI_STEP and not _active_enemies.is_empty():
		if cooldown > remaining:
			cooldown -= remaining
			remaining = 0.0
			break
		remaining -= cooldown
		target = _select_npc_attack_target(npc_id, attack_context)
		if target.is_empty():
			break
		var single_attack := _apply_npc_attack_to_enemy(npc_id, npc, target, attack_context)
		if single_attack.is_empty():
			break
		attacks.append(single_attack)
		cooldown = float(attack_context.get("attack_interval", 1.5))

	var last_attack := attacks[attacks.size() - 1] if not attacks.is_empty() else {}
	var state_changes := {
		"combat_attack_cooldown": cooldown,
		"combat_target_enemy_id": str(target.get("id", "")),
		"combat_last_attack_result": last_attack,
		"last_action_result": "combat_attack_made" if not attacks.is_empty() else "combat_waiting_for_cooldown"
	}
	if not attacks.is_empty():
		state_changes["current_action"] = "attacking_%s" % str(target.get("id", "enemy"))
	if npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, state_changes)

	return {
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"attack_count": attacks.size(),
		"target": _serialize_target(target),
		"attack_context": attack_context,
		"combat_seconds": combat_delta_seconds,
		"cooldown": cooldown,
		"attacks": attacks
	}


func _select_npc_attack_target(npc_id: String, attack_context: Dictionary) -> Dictionary:
	var npc_position := _get_npc_position(npc_id)
	var attack_range := maxf(0.1, float(attack_context.get("range", 1.5)))
	var preferred_enemy_id := ""
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc_state"):
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		preferred_enemy_id = str(state.get("combat_target_enemy_id", ""))
	if _active_enemies.has(preferred_enemy_id):
		var preferred := _make_enemy_attack_target(preferred_enemy_id, npc_position)
		if not preferred.is_empty() and float(preferred.get("distance", INF)) <= attack_range:
			return preferred

	var nearest := {}
	var nearest_distance := INF
	for enemy_id in get_active_enemy_ids():
		var target := _make_enemy_attack_target(enemy_id, npc_position)
		if target.is_empty():
			continue
		var distance := float(target.get("distance", INF))
		if distance > attack_range or distance >= nearest_distance:
			continue
		nearest = target
		nearest_distance = distance
	return nearest


func _make_enemy_attack_target(enemy_id: String, origin: Vector3) -> Dictionary:
	var enemy: Dictionary = _active_enemies.get(enemy_id, {})
	if enemy.is_empty() or not bool(enemy.get("alive", true)):
		return {}
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	return {
		"type": "enemy",
		"id": enemy_id,
		"name": str(enemy.get("name", enemy_id)),
		"position": enemy_position,
		"distance": origin.distance_to(enemy_position),
		"defense": _calculate_enemy_defense(enemy_id)
	}


func _advance_npc_combat_strategy_movement(
	npc_id: String,
	state: Dictionary,
	attack_context: Dictionary,
	target_in_range: Dictionary
) -> Dictionary:
	var strategy_id := str(attack_context.get("strategy_id", STRATEGY_ATTACK))
	var attack_range := maxf(0.1, float(attack_context.get("range", 1.5)))
	var current_action := str(state.get("current_action", ""))
	var is_strategy_moving := current_action.begins_with("moving_to_%s" % STRATEGY_MOVE_TARGET_PREFIX)
	var nearest := _nearest_enemy_for_npc(npc_id)
	if nearest.is_empty():
		return {}
	var distance := float(nearest.get("distance", INF))

	if is_strategy_moving:
		if strategy_id == STRATEGY_AVOID and distance >= AVOIDANCE_DESIRED_DISTANCE:
			return _hold_combat_strategy_avoid(npc_id, state, nearest, true)
		if strategy_id == STRATEGY_AVOID or target_in_range.is_empty():
			return {
				"ok": true,
				"npc_id": npc_id,
				"strategy_id": strategy_id,
				"strategy_label": _get_combat_strategy_label(strategy_id),
				"reason": "combat_strategy_movement_in_progress"
			}
		return {}

	match strategy_id:
		STRATEGY_AVOID:
			if distance >= AVOIDANCE_DESIRED_DISTANCE:
				return _hold_combat_strategy_avoid(npc_id, state, nearest, false)
			var avoid_target := _select_avoidance_target(npc_id, nearest)
			var move_result := _start_combat_strategy_move(npc_id, strategy_id, nearest, avoid_target, "combat_strategy_avoid")
			if move_result.is_empty():
				return _hold_combat_strategy_avoid(npc_id, state, nearest, false)
			return move_result
		STRATEGY_KEEP_DISTANCE:
			if distance < _get_keep_distance_min_distance(attack_range):
				return _start_combat_strategy_move(
					npc_id,
					strategy_id,
					nearest,
					_select_keep_distance_target(npc_id, nearest, attack_range),
					"combat_strategy_keep_distance"
				)
			if target_in_range.is_empty() and distance > attack_range:
				return _start_combat_strategy_move(
					npc_id,
					strategy_id,
					nearest,
					_select_approach_target(npc_id, nearest, attack_range),
					"combat_strategy_keep_in_range"
				)
		STRATEGY_ATTACK:
			if target_in_range.is_empty() and distance > attack_range:
				return _start_combat_strategy_move(
					npc_id,
					strategy_id,
					nearest,
					_select_approach_target(npc_id, nearest, attack_range),
					"combat_strategy_attack_approach"
				)
		STRATEGY_CHARGE_CYCLE:
			var cooldown := maxf(0.0, float(state.get("combat_attack_cooldown", 0.0)))
			var close_distance := maxf(CAVALRY_CHARGE_CLOSE_DISTANCE, attack_range + 0.75)
			if distance <= attack_range and cooldown <= 0.0:
				return {}
			if distance < close_distance or (not target_in_range.is_empty() and cooldown > 0.0):
				return _start_combat_strategy_move(
					npc_id,
					strategy_id,
					nearest,
					_select_charge_reset_target(npc_id, nearest, attack_range),
					"combat_strategy_charge_reset"
				)
			if target_in_range.is_empty():
				return _start_combat_strategy_move(
					npc_id,
					strategy_id,
					nearest,
					_select_approach_target(npc_id, nearest, attack_range),
					"combat_strategy_charge_approach"
				)
		_:
			pass
	return {}


func _start_combat_strategy_move(
	npc_id: String,
	strategy_id: String,
	encounter: Dictionary,
	target: Dictionary,
	reason: String
) -> Dictionary:
	if target.is_empty():
		return {}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("move_npc_to_world_position"):
		return {}
	var target_position: Vector3 = target.get("position", _get_npc_position(npc_id))
	var npc_position := _get_npc_position(npc_id)
	if npc_position.distance_to(target_position) < 0.2:
		return {}
	var target_id := "%s%s_%s" % [STRATEGY_MOVE_TARGET_PREFIX, strategy_id, npc_id]
	var target_name := str(target.get("target_name", _get_combat_strategy_label(strategy_id)))
	var arrival_state := {
		"current_action": "combat_ready",
		"current_location": RALLY_LOCATION_ID,
		"current_location_name": RALLY_LOCATION_NAME,
		"last_action_result": reason,
		"combat_target_enemy_id": str(encounter.get("enemy_id", "")),
		"combat_strategy_move_target_id": str(target.get("target_id", target_id)),
		"combat_strategy_move_target_name": target_name,
		"combat_strategy_move_target_position": _vector3_to_dict(target_position)
	}
	var moved := bool(npc_system.move_npc_to_world_position(npc_id, target_id, target_name, target_position, arrival_state))
	return {
		"ok": moved,
		"npc_id": npc_id,
		"strategy_id": strategy_id,
		"strategy_label": _get_combat_strategy_label(strategy_id),
		"reason": reason,
		"enemy_id": str(encounter.get("enemy_id", "")),
		"enemy_name": str(encounter.get("enemy_name", "")),
		"enemy_distance": float(encounter.get("distance", 0.0)),
		"target_id": target_id,
		"target_name": target_name,
		"target_position": _vector3_to_dict(target_position),
		"target_enemy_distance": float(target.get("enemy_distance_after", 0.0)),
		"travel_distance": npc_position.distance_to(target_position)
	}


func _hold_combat_strategy_avoid(
	npc_id: String,
	state: Dictionary,
	encounter: Dictionary,
	stop_movement: bool
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var current_action := str(state.get("current_action", ""))
	var state_changes := {
		"current_action": "combat_ready",
		"movement_target": "",
		"movement_target_name": "",
		"last_action_result": "combat_strategy_avoid_holding",
		"combat_target_enemy_id": str(encounter.get("enemy_id", "")),
		"combat_strategy_move_target_id": "",
		"combat_strategy_move_target_name": "",
		"combat_strategy_move_target_position": {}
	}
	var should_update := stop_movement
	if not should_update:
		should_update = (
			current_action != "combat_ready"
			or not str(state.get("movement_target", "")).is_empty()
			or not str(state.get("combat_strategy_move_target_id", "")).is_empty()
		)
	if should_update and npc_system != null:
		if stop_movement and npc_system.has_method("stop_npc_movement_with_state"):
			npc_system.stop_npc_movement_with_state(npc_id, state_changes)
		elif npc_system.has_method("update_npc_state"):
			npc_system.update_npc_state(npc_id, state_changes)
	return {
		"ok": true,
		"npc_id": npc_id,
		"strategy_id": STRATEGY_AVOID,
		"strategy_label": _get_combat_strategy_label(STRATEGY_AVOID),
		"reason": "combat_strategy_avoid_holding",
		"enemy_id": str(encounter.get("enemy_id", "")),
		"enemy_name": str(encounter.get("enemy_name", "")),
		"enemy_distance": float(encounter.get("distance", 0.0)),
		"holding": true,
		"stopped_movement": stop_movement
	}


func _select_keep_distance_target(npc_id: String, encounter: Dictionary, attack_range: float) -> Dictionary:
	var npc_position := _get_npc_position(npc_id)
	var enemy_position: Vector3 = encounter.get("position", npc_position + Vector3(0.0, 0.0, 1.0))
	var away_direction := npc_position - enemy_position
	away_direction.y = 0.0
	if away_direction.length() <= 0.001:
		away_direction = _fallback_avoidance_direction(npc_id)
	else:
		away_direction = away_direction.normalized()
	var target_distance := clampf(
		attack_range * KEEP_DISTANCE_TARGET_RANGE_RATIO,
		_get_keep_distance_min_distance(attack_range) + 0.6,
		attack_range * KEEP_DISTANCE_MAX_RANGE_RATIO
	)
	var unclamped_position := enemy_position + away_direction * target_distance
	var position := _constrain_combat_strategy_position(unclamped_position)
	return {
		"target_id": "keep_distance_%d" % _stable_hash_text("%s:%s" % [npc_id, str(encounter.get("enemy_id", ""))]),
		"target_name": "保持距离射击点",
		"position": position,
		"enemy_distance_after": position.distance_to(enemy_position)
	}


func _select_charge_reset_target(npc_id: String, encounter: Dictionary, attack_range: float) -> Dictionary:
	var npc_position := _get_npc_position(npc_id)
	var enemy_position: Vector3 = encounter.get("position", npc_position + Vector3(0.0, 0.0, 1.0))
	var away_direction := npc_position - enemy_position
	away_direction.y = 0.0
	if away_direction.length() <= 0.001:
		away_direction = _fallback_avoidance_direction(npc_id)
	else:
		away_direction = away_direction.normalized()
	var target_distance := maxf(CAVALRY_CHARGE_RESET_DISTANCE, attack_range + 2.0)
	var position := _constrain_combat_strategy_position(enemy_position + away_direction * target_distance)
	return {
		"target_id": "charge_reset_%d" % _stable_hash_text("%s:%s" % [npc_id, str(encounter.get("enemy_id", ""))]),
		"target_name": "拉开距离准备冲击",
		"position": position,
		"enemy_distance_after": position.distance_to(enemy_position)
	}


func _select_approach_target(npc_id: String, encounter: Dictionary, attack_range: float) -> Dictionary:
	var npc_position := _get_npc_position(npc_id)
	var enemy_position: Vector3 = encounter.get("position", npc_position + Vector3(0.0, 0.0, 1.0))
	var away_from_enemy := npc_position - enemy_position
	away_from_enemy.y = 0.0
	if away_from_enemy.length() <= 0.001:
		away_from_enemy = _fallback_avoidance_direction(npc_id)
	else:
		away_from_enemy = away_from_enemy.normalized()
	var desired_distance := maxf(0.2, attack_range * COMBAT_APPROACH_RANGE_RATIO)
	var position := _constrain_combat_strategy_position(enemy_position + away_from_enemy * desired_distance)
	return {
		"target_id": "approach_%d" % _stable_hash_text("%s:%s" % [npc_id, str(encounter.get("enemy_id", ""))]),
		"target_name": "接近攻击距离",
		"position": position,
		"enemy_distance_after": position.distance_to(enemy_position)
	}


func _get_keep_distance_min_distance(attack_range: float) -> float:
	return clampf(attack_range * KEEP_DISTANCE_MIN_RANGE_RATIO, 2.8, attack_range * 0.8)


func _constrain_combat_strategy_position(position: Vector3) -> Vector3:
	return Vector3(
		clampf(position.x, COMBAT_STRATEGY_MIN_X, COMBAT_STRATEGY_MAX_X),
		0.0,
		clampf(position.z, COMBAT_STRATEGY_MIN_Z, COMBAT_STRATEGY_MAX_Z)
	)


func _calculate_npc_attack_context(npc_id: String, npc: Dictionary, state: Dictionary) -> Dictionary:
	var weapon := _get_npc_main_weapon(npc)
	if weapon.is_empty():
		return {}
	var required_skill := str(weapon.get("required_skill", weapon.get("weapon_class", "")))
	var weapon_skill := _get_npc_skill_value(npc, required_skill)
	var strength := _get_npc_stat_value(npc, "strength", int(STRENGTH_ATTACK_BASELINE))
	var base_damage := maxf(1.0, float(weapon.get("damage", 1.0)))
	var strength_multiplier := clampf(
		1.0 + (float(strength) - STRENGTH_ATTACK_BASELINE) * STRENGTH_ATTACK_BONUS_PER_POINT,
		MIN_STRENGTH_ATTACK_MULTIPLIER,
		MAX_STRENGTH_ATTACK_MULTIPLIER
	)
	var morale_attack_bonus := _get_active_morale_attack_bonus(state)
	var raw_attack_power := base_damage * strength_multiplier * (1.0 + morale_attack_bonus)
	var attack_speed_multiplier := _calculate_npc_attack_speed_multiplier(npc, state, weapon_skill)
	var base_interval := maxf(0.1, float(weapon.get("attack_interval", 1.8)))
	var attack_interval := maxf(MIN_NPC_ATTACK_INTERVAL, base_interval / attack_speed_multiplier)
	return {
		"npc_id": npc_id,
		"weapon_id": str(weapon.get("id", "")),
		"weapon_name": str(weapon.get("name", "武器")),
		"weapon_class": str(weapon.get("weapon_class", "")),
		"required_skill": required_skill,
		"weapon_skill": weapon_skill,
		"strength": strength,
		"base_damage": base_damage,
		"strength_multiplier": strength_multiplier,
		"morale_attack_bonus": morale_attack_bonus,
		"raw_attack_power": raw_attack_power,
		"attack_power": maxi(1, int(round(raw_attack_power))),
		"base_attack_interval": base_interval,
		"attack_speed_multiplier": attack_speed_multiplier,
		"attack_interval": attack_interval,
		"range": maxf(0.1, float(weapon.get("range", 1.5)))
	}


func _calculate_npc_attack_speed_multiplier(npc: Dictionary, state: Dictionary, weapon_skill: int) -> float:
	var skill_bonus := clampf(float(weapon_skill) / 100.0, 0.0, 1.0) * SKILL_ATTACK_SPEED_BONUS_AT_100
	var multiplier := 1.0 + skill_bonus
	var fatigue := clampf(float(state.get("fatigue", 0.0)), 0.0, 100.0)
	if fatigue > FATIGUE_ATTACK_SPEED_PENALTY_START:
		var fatigue_ratio := (fatigue - FATIGUE_ATTACK_SPEED_PENALTY_START) / (100.0 - FATIGUE_ATTACK_SPEED_PENALTY_START)
		multiplier *= 1.0 - clampf(fatigue_ratio, 0.0, 1.0) * FATIGUE_ATTACK_SPEED_MAX_PENALTY
	var satiety := clampf(float(state.get("satiety", 100.0)), 0.0, 100.0)
	if satiety < SATIETY_ATTACK_SPEED_PENALTY_START:
		var satiety_ratio := (SATIETY_ATTACK_SPEED_PENALTY_START - satiety) / SATIETY_ATTACK_SPEED_PENALTY_START
		multiplier *= 1.0 - clampf(satiety_ratio, 0.0, 1.0) * SATIETY_ATTACK_SPEED_MAX_PENALTY
	var equipment: Dictionary = npc.get("equipment", {}) if (npc.get("equipment", {}) is Dictionary) else {}
	var mount: Dictionary = equipment.get("mount", {}) if (equipment.get("mount", {}) is Dictionary) else {}
	if not mount.is_empty():
		var riding_skill := _get_npc_skill_value(npc, "骑术")
		multiplier *= 1.0 + clampf(float(riding_skill) / 100.0, 0.0, 1.0) * MOUNTED_ATTACK_SPEED_BONUS_AT_100_RIDING
	return maxf(MIN_ATTACK_SPEED_MULTIPLIER, multiplier)


func _get_npc_main_weapon(npc: Dictionary) -> Dictionary:
	var equipment: Dictionary = npc.get("equipment", {}) if (npc.get("equipment", {}) is Dictionary) else {}
	var weapon: Dictionary = equipment.get("main_weapon", {}) if (equipment.get("main_weapon", {}) is Dictionary) else {}
	return weapon.duplicate(true)


func _get_npc_skill_value(npc: Dictionary, skill_name: String) -> int:
	var skills: Dictionary = npc.get("skills", {}) if (npc.get("skills", {}) is Dictionary) else {}
	return clampi(int(skills.get(skill_name, 0)), 0, 100)


func _get_npc_stat_value(npc: Dictionary, stat_name: String, fallback: int = 5) -> int:
	var stats: Dictionary = npc.get("stats", {}) if (npc.get("stats", {}) is Dictionary) else {}
	return int(stats.get(stat_name, fallback))


func _apply_npc_attack_to_enemy(npc_id: String, npc: Dictionary, target: Dictionary, attack_context: Dictionary) -> Dictionary:
	var enemy_id := str(target.get("id", ""))
	if enemy_id.is_empty() or not _active_enemies.has(enemy_id):
		return {}
	var target_defense := _calculate_enemy_defense(enemy_id)
	var raw_attack_power := float(attack_context.get("raw_attack_power", 1.0))
	var damage := _calculate_actual_hp_damage(raw_attack_power, target_defense)
	var damage_result := _apply_damage_to_enemy(enemy_id, damage, npc_id, {
		"raw_attack_power": raw_attack_power,
		"target_defense": target_defense,
		"weapon_id": str(attack_context.get("weapon_id", "")),
		"weapon_name": str(attack_context.get("weapon_name", "武器"))
	})
	var event := _log_npc_attack_made(npc_id, npc, target, attack_context, damage_result)
	return {
		"attacker_npc_id": npc_id,
		"attacker_name": str(npc.get("name", npc_id)),
		"target_enemy_id": enemy_id,
		"target_enemy_name": str(target.get("name", enemy_id)),
		"raw_attack_power": raw_attack_power,
		"target_defense": target_defense,
		"damage": damage,
		"damage_result": damage_result,
		"event": event
	}


func _apply_damage_to_enemy(enemy_id: String, damage: int, actor_npc_id: String, context: Dictionary = {}) -> Dictionary:
	if damage <= 0 or not _active_enemies.has(enemy_id):
		return {}
	var enemy: Dictionary = _active_enemies.get(enemy_id, {})
	var max_hp := maxi(1, int(enemy.get("max_hp", enemy.get("hp", 1))))
	var hp_before := clampi(int(enemy.get("hp", max_hp)), 0, max_hp)
	var hp_after := maxi(0, hp_before - damage)
	var defeated := hp_after <= 0
	var result := {
		"ok": true,
		"enemy_id": enemy_id,
		"enemy_name": str(enemy.get("name", enemy_id)),
		"damage": damage,
		"raw_attack_power": float(context.get("raw_attack_power", damage)),
		"target_defense": float(context.get("target_defense", 0.0)),
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"defeated": defeated,
		"actor_npc_id": actor_npc_id
	}
	enemy["hp"] = hp_after
	enemy["alive"] = not defeated
	enemy["last_damage_result"] = result.duplicate(true)
	if defeated:
		_record_battle_enemy_defeat(actor_npc_id, enemy, result)
		result["removed"] = true
		_remove_enemy_from_combat(enemy_id)
	else:
		_active_enemies[enemy_id] = enemy
		_refresh_enemy_node(enemy_id)
	return result


func _remove_enemy_from_combat(enemy_id: String) -> void:
	if _enemy_nodes.has(enemy_id):
		var enemy_node := get_node_or_null(_enemy_nodes[enemy_id]) as Node
		if enemy_node != null:
			enemy_node.queue_free()
	_enemy_nodes.erase(enemy_id)
	_active_enemies.erase(enemy_id)
	for raw_npc_id in _active_rallies.keys():
		var npc_id := str(raw_npc_id)
		var rally: Dictionary = _active_rallies.get(npc_id, {})
		if str(rally.get("encounter_enemy_id", "")) == enemy_id:
			rally["encounter_enemy_id"] = ""
			_active_rallies[npc_id] = rally
	if _active_enemies.is_empty():
		_sync_enemy_presence_time_cap("last_enemy_removed")


func _calculate_enemy_defense(enemy_id: String) -> float:
	var enemy: Dictionary = _active_enemies.get(enemy_id, {})
	return maxf(0.0, float(enemy.get("defense", 0.0)))


func _calculate_npc_defense(npc_id: String) -> float:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return 0.0
	var npc: Dictionary = npc_system.get_npc(npc_id)
	var equipment: Dictionary = npc.get("equipment", {}) if (npc.get("equipment", {}) is Dictionary) else {}
	var defense := 0.0
	for slot in ["helmet", "chest", "bracers", "greaves"]:
		var item: Dictionary = equipment.get(slot, {}) if (equipment.get(slot, {}) is Dictionary) else {}
		defense += maxf(0.0, float(item.get("armor_value", 0.0)))
	return defense


func _calculate_actual_hp_damage(raw_attack_power: float, defense: float) -> int:
	var reduction := clampf(maxf(0.0, defense) * DEFENSE_REDUCTION_PER_POINT, 0.0, MAX_DEFENSE_DAMAGE_REDUCTION)
	var damage := maxf(1.0, maxf(1.0, raw_attack_power) * (1.0 - reduction))
	return maxi(1, int(round(damage)))


func _log_npc_attack_made(
	npc_id: String,
	npc: Dictionary,
	target: Dictionary,
	attack_context: Dictionary,
	damage_result: Dictionary
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var enemy_id := str(target.get("id", damage_result.get("enemy_id", "")))
	var enemy_name := str(target.get("name", damage_result.get("enemy_name", enemy_id)))
	return memory_system.add_event({
		"type": "attack_made",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id, enemy_id],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 75 if bool(damage_result.get("defeated", false)) else 55,
		"payload": {
			"attacker_npc_id": npc_id,
			"attacker_name": str(npc.get("name", npc_id)),
			"target_type": "enemy",
			"target_enemy_id": enemy_id,
			"target_enemy_name": enemy_name,
			"weapon_id": str(attack_context.get("weapon_id", "")),
			"weapon_name": str(attack_context.get("weapon_name", "武器")),
			"required_skill": str(attack_context.get("required_skill", "")),
			"weapon_skill": int(attack_context.get("weapon_skill", 0)),
			"strength": int(attack_context.get("strength", 0)),
			"base_damage": float(attack_context.get("base_damage", 0.0)),
			"strength_multiplier": float(attack_context.get("strength_multiplier", 1.0)),
			"raw_attack_power": float(attack_context.get("raw_attack_power", 0.0)),
			"attack_speed_multiplier": float(attack_context.get("attack_speed_multiplier", 1.0)),
			"attack_interval": float(attack_context.get("attack_interval", 1.0)),
			"target_defense": float(damage_result.get("target_defense", 0.0)),
			"damage": int(damage_result.get("damage", 0)),
			"hp_before": int(damage_result.get("hp_before", 0)),
			"hp_after": int(damage_result.get("hp_after", 0)),
			"defeated": bool(damage_result.get("defeated", false))
		}
	})


func _advance_enemy_ai(game_delta_seconds: float, combat_delta_seconds: float = -1.0) -> Dictionary:
	if combat_delta_seconds < 0.0:
		combat_delta_seconds = _get_combat_action_seconds(game_delta_seconds)
	var result := {
		"ok": true,
		"game_seconds": game_delta_seconds,
		"combat_seconds": combat_delta_seconds,
		"moved": [],
		"attacks": [],
		"targets": []
	}
	if game_delta_seconds <= 0.0 or _active_enemies.is_empty():
		_last_ai_step_result = result.duplicate(true)
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
			var attack_result := _advance_enemy_attack(enemy, target, combat_delta_seconds)
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
		var combat_eligible := _is_npc_combat_eligible(npc_id, npc_system)
		if combat_eligible and [BEHAVIOR_MODE_WORK, BEHAVIOR_MODE_RALLY].has(mode):
			if _active_rallies.has(npc_id):
				_switch_rally_to_combat(npc_id, _active_rallies.get(npc_id, {}), encounter)
			else:
				_enter_npc_combat_from_contact(npc_id, encounter, "enemy_contact")
		elif not combat_eligible and [BEHAVIOR_MODE_WORK, BEHAVIOR_MODE_RALLY].has(mode):
			_active_rallies.erase(npc_id)
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
	if _active_enemies.is_empty():
		var ended_event := _complete_npc_avoidance(npc_id, "recruited_no_enemies")
		var work_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, "recruited_no_enemies", {
			"force_idle": true,
			"request_plan_reevaluation": false
		})
		work_result["avoidance_ended_event"] = ended_event
		_last_mode_transition_result = work_result.duplicate(true)
		return work_result
	if not _is_npc_combat_eligible(npc_id, npc_system):
		var encounter := _nearest_enemy_for_npc(npc_id)
		var result := {
			"ok": true,
			"npc_id": npc_id,
			"changed": false,
			"reason": "recruited_without_main_weapon",
			"message": "NPC 已入伍但仍无主武器，继续按非战斗人员避战。"
		}
		if not encounter.is_empty():
			var target := _select_avoidance_target(npc_id, encounter)
			result["avoidance"] = _start_or_update_npc_avoidance(
				npc_id,
				encounter,
				target,
				"recruited_without_main_weapon",
				not _active_avoidances.has(npc_id)
			)
		return result
	var ended_event := _complete_npc_avoidance(npc_id, "armed_during_avoidance")
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
		avoidance["enemy_distance"] = float(encounter.get("distance", INF))
		if current_action.begins_with("moving_to_%s" % AVOIDANCE_TARGET_PREFIX):
			avoidance["status"] = "moving"
			_active_avoidances[npc_id] = avoidance
			continue
		if npc_position.distance_to(target_position) <= 0.35:
			avoidance["status"] = "keeping_distance" if float(encounter.get("distance", INF)) >= AVOIDANCE_DESIRED_DISTANCE else "ready_to_scatter"
			_active_avoidances[npc_id] = avoidance
		if float(encounter.get("distance", INF)) < AVOIDANCE_DESIRED_DISTANCE:
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
		"target_travel_distance": float(target.get("travel_distance", 0.0)),
		"enemy_distance_after_target": float(target.get("enemy_distance_after", 0.0)),
		"enemy_distance_before_target": float(target.get("enemy_distance_before", float(encounter.get("distance", 0.0)))),
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
	var enemy_id := str(encounter.get("enemy_id", ""))
	var enemy_name := str(encounter.get("enemy_name", "敌军"))
	if enemy_name.is_empty():
		enemy_name = "敌军"
	var enemy_position: Vector3 = encounter.get("position", npc_position + Vector3(0.0, 0.0, 1.0))
	var away_direction := npc_position - enemy_position
	away_direction.y = 0.0
	if away_direction.length() <= 0.001:
		away_direction = _fallback_avoidance_direction(npc_id)
	else:
		away_direction = away_direction.normalized()
	var scatter_angle := _get_avoidance_scatter_angle(npc_id, enemy_id)
	var angle_candidates := [
		scatter_angle,
		scatter_angle + deg_to_rad(AVOIDANCE_SIDE_STEP_DEGREES),
		scatter_angle - deg_to_rad(AVOIDANCE_SIDE_STEP_DEGREES),
		scatter_angle + deg_to_rad(AVOIDANCE_SIDE_STEP_DEGREES * 2.0),
		scatter_angle - deg_to_rad(AVOIDANCE_SIDE_STEP_DEGREES * 2.0)
	]
	var best := {}
	var best_score := -INF
	var current_enemy_distance := float(encounter.get("distance", npc_position.distance_to(enemy_position)))
	for index in range(angle_candidates.size()):
		var direction := _rotate_direction_y(away_direction, float(angle_candidates[index]))
		if direction.length() <= 0.001:
			continue
		var unclamped_position := npc_position + direction * AVOIDANCE_STEP_DISTANCE
		var position := _constrain_avoidance_step(npc_position, unclamped_position)
		var min_enemy_distance := _get_min_enemy_distance(position)
		var travel_distance := npc_position.distance_to(position)
		var contact_gain := min_enemy_distance - current_enemy_distance
		var clamp_penalty := position.distance_to(unclamped_position)
		var step_penalty := absf(travel_distance - AVOIDANCE_STEP_DISTANCE)
		var score := min_enemy_distance * 2.0 + contact_gain * 4.0 - clamp_penalty * 3.0 - step_penalty * 0.25 - float(index) * 0.05
		if travel_distance < AVOIDANCE_MIN_STEP_DISTANCE:
			score -= 20.0
		if score > best_score:
			best_score = score
			best = {
				"target_id": "scatter_%d_%d" % [_stable_hash_text("%s:%s" % [npc_id, enemy_id]), index],
				"target_name": "远离%s的避战方向" % enemy_name,
				"position": position,
				"direction": direction,
				"score": score,
				"enemy_distance_after": min_enemy_distance,
				"enemy_distance_before": current_enemy_distance,
				"travel_distance": travel_distance
			}
	if best.is_empty():
		var fallback_position := _constrain_avoidance_step(
			npc_position,
			npc_position + _fallback_avoidance_direction(npc_id) * AVOIDANCE_STEP_DISTANCE
		)
		best = {
			"target_id": "scatter_%d_fallback" % _stable_hash_text(npc_id),
			"target_name": "远离敌人的避战方向",
			"position": fallback_position,
			"score": best_score,
			"enemy_distance_after": _get_min_enemy_distance(fallback_position),
			"enemy_distance_before": current_enemy_distance,
			"travel_distance": npc_position.distance_to(fallback_position)
		}
	return best


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
	var time_cap_result := _sync_enemy_presence_time_cap(reason)
	var result := {
		"ok": true,
		"reason": reason,
		"time_cap_result": time_cap_result,
		"combat_to_work": [],
		"rally_to_work": [],
		"avoid_to_work": [],
		"avoidance_ended": [],
		"battle_end_result": {}
	}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("set_npc_behavior_mode"):
		result["battle_end_result"] = _finish_active_battle(reason)
		return result
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var mode := _get_npc_behavior_mode(npc_system, npc_id)
		if mode == BEHAVIOR_MODE_COMBAT:
			var combat_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, reason, {
				"interrupt": true,
				"force_idle": true,
				"request_plan_reevaluation": true
			})
			(result["combat_to_work"] as Array).append(combat_result)
			_active_rallies.erase(npc_id)
		elif mode == BEHAVIOR_MODE_RALLY:
			var rally_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, reason, {
				"interrupt": true,
				"force_idle": true,
				"request_plan_reevaluation": false
			})
			(result["rally_to_work"] as Array).append(rally_result)
			_active_rallies.erase(npc_id)
		elif mode == BEHAVIOR_MODE_AVOID_COMBAT:
			var ended_event := _complete_npc_avoidance(npc_id, reason)
			var avoid_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, reason, {
				"interrupt": true,
				"force_idle": true,
				"request_plan_reevaluation": false
			})
			avoid_result["avoidance_ended_event"] = ended_event
			(result["avoid_to_work"] as Array).append(avoid_result)
			(result["avoidance_ended"] as Array).append(ended_event)
	result["battle_end_result"] = _finish_active_battle(reason)
	_last_mode_transition_result = result.duplicate(true)
	return result


func _on_npc_revived(npc_id: String) -> void:
	_route_revived_npc(npc_id)


func _on_npc_unconscious(npc_id: String) -> void:
	_active_rallies.erase(npc_id)
	_complete_npc_avoidance(npc_id, "npc_unconscious")
	_pause_escape_for_unconscious(npc_id, "npc_unconscious")
	_record_battle_npc_unconscious(npc_id, "npc_unconscious")


func _route_revived_npc(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("set_npc_behavior_mode"):
		return {}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}
	var escape_resume := _resume_escape_after_revive(npc_id, npc_system)
	if bool(escape_resume.get("active_escape", false)):
		_last_mode_transition_result = escape_resume.duplicate(true)
		return escape_resume
	if _active_enemies.is_empty():
		var work_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, "revived_no_enemies", {
			"force_idle": true,
			"request_plan_reevaluation": true
		})
		_last_mode_transition_result = work_result.duplicate(true)
		return work_result
	if _is_npc_combat_eligible(npc_id, npc_system):
		var combat_result := _enter_npc_combat_from_contact(npc_id, _nearest_enemy_for_npc(npc_id), "revived_enemies_present")
		_last_mode_transition_result = combat_result.duplicate(true)
		return combat_result
	var avoid_result := _enter_npc_avoid_from_contact(npc_id, _nearest_enemy_for_npc(npc_id), "revived_enemies_present")
	_last_mode_transition_result = avoid_result.duplicate(true)
	return avoid_result


func _start_battle_for_wave(wave: Dictionary, spawned: Array[Dictionary], reason: String) -> Dictionary:
	if spawned.is_empty():
		return {"ok": false, "error": "no_spawned_enemies", "reason": reason}
	if not _active_battle.is_empty():
		var additional_waves: Array = _active_battle.get("additional_waves", [])
		additional_waves.append({
			"wave_number": int(wave.get("wave_number", 0)),
			"wave_id": str(wave.get("id", "")),
			"enemy_count": spawned.size(),
			"reason": reason
		})
		_active_battle["additional_waves"] = additional_waves
		return {
			"ok": true,
			"already_active": true,
			"wave_number": int(_active_battle.get("wave_number", 0)),
			"additional_wave_number": int(wave.get("wave_number", 0))
		}

	var enemy_roster := _build_enemy_roster_from_spawned(spawned)
	var friendly_roster := _build_friendly_combatant_roster()
	_active_battle = {
		"active": true,
		"wave_number": int(wave.get("wave_number", 0)),
		"wave_id": str(wave.get("id", "")),
		"reason": reason,
		"started_enemy_count": spawned.size(),
		"enemy_roster": enemy_roster,
		"friendly_roster": friendly_roster,
		"friendly_combatant_count": friendly_roster.size(),
		"noncombatant_count": _get_noncombatant_count(friendly_roster.size()),
		"injured_npcs": {},
		"unconscious_npcs": {},
		"low_hp_judgements": {},
		"defeated_by_npc": {},
		"defeated_enemy_count": 0,
		"additional_waves": []
	}
	var event := _log_combat_started(_active_battle)
	_active_battle["started_event_id"] = str(event.get("event_id", ""))
	_last_battle_start_result = {
		"ok": true,
		"wave_number": int(_active_battle.get("wave_number", 0)),
		"wave_id": str(_active_battle.get("wave_id", "")),
		"enemy_count": spawned.size(),
		"friendly_combatant_count": friendly_roster.size(),
		"event": event
	}
	return _last_battle_start_result.duplicate(true)


func _finish_active_battle(reason: String) -> Dictionary:
	if _active_battle.is_empty():
		return {"ok": false, "error": "no_active_battle", "reason": reason}
	var ended := _active_battle.duplicate(true)
	ended["active"] = false
	ended["end_reason"] = reason
	ended["remaining_enemy_count"] = get_active_enemy_count()
	ended["injured_npcs"] = _battle_map_to_sorted_array(_active_battle.get("injured_npcs", {}))
	ended["unconscious_npcs"] = _battle_map_to_sorted_array(_active_battle.get("unconscious_npcs", {}))
	ended["low_hp_judgements"] = _battle_map_to_sorted_array(_active_battle.get("low_hp_judgements", {}))
	ended["defeated_by_npc"] = _battle_map_to_sorted_array(_active_battle.get("defeated_by_npc", {}))
	var event := _log_combat_ended(ended)
	ended["ended_event_id"] = str(event.get("event_id", ""))
	ended["event"] = event
	_last_battle_end_result = ended.duplicate(true)
	_active_battle.clear()
	return _last_battle_end_result.duplicate(true)


func _record_battle_enemy_defeat(npc_id: String, enemy: Dictionary, damage_result: Dictionary) -> void:
	if _active_battle.is_empty() or npc_id.is_empty():
		return
	var defeated_by: Dictionary = _active_battle.get("defeated_by_npc", {})
	var entry: Dictionary = defeated_by.get(npc_id, {})
	if entry.is_empty():
		entry = {
			"npc_id": npc_id,
			"npc_name": _get_npc_name(npc_id),
			"defeated_count": 0,
			"enemies": []
		}
	entry["defeated_count"] = int(entry.get("defeated_count", 0)) + 1
	var enemies: Array = entry.get("enemies", [])
	enemies.append({
		"enemy_id": str(enemy.get("id", damage_result.get("enemy_id", ""))),
		"enemy_name": str(enemy.get("name", damage_result.get("enemy_name", ""))),
		"unit_type": str(enemy.get("unit_type", "")),
		"unit_type_label": _get_unit_type_label(str(enemy.get("unit_type", "")))
	})
	entry["enemies"] = enemies
	defeated_by[npc_id] = entry
	_active_battle["defeated_by_npc"] = defeated_by
	_active_battle["defeated_enemy_count"] = int(_active_battle.get("defeated_enemy_count", 0)) + 1


func _record_battle_npc_damage(npc_id: String, npc_name: String, enemy: Dictionary, damage_result: Dictionary) -> void:
	if _active_battle.is_empty() or npc_id.is_empty() or damage_result.is_empty():
		return
	var hp_before := int(damage_result.get("hp_before", 0))
	var hp_after := int(damage_result.get("hp_after", hp_before))
	if hp_after >= hp_before:
		return
	var damage := maxi(0, hp_before - hp_after)
	var injured: Dictionary = _active_battle.get("injured_npcs", {})
	var entry: Dictionary = injured.get(npc_id, {})
	if entry.is_empty():
		entry = {
			"npc_id": npc_id,
			"npc_name": npc_name,
			"damage_taken": 0,
			"hp_before_first": hp_before,
			"hp_after_last": hp_after,
			"lowest_hp": hp_after,
			"max_hp": int(damage_result.get("max_hp", 0)),
			"attackers": []
		}
	entry["damage_taken"] = int(entry.get("damage_taken", 0)) + damage
	entry["hp_after_last"] = hp_after
	entry["lowest_hp"] = mini(int(entry.get("lowest_hp", hp_after)), hp_after)
	var attackers: Array = entry.get("attackers", [])
	var enemy_id := str(enemy.get("id", damage_result.get("damage_source", "")))
	if not enemy_id.is_empty() and not _array_has_id(attackers, "enemy_id", enemy_id):
		attackers.append({
			"enemy_id": enemy_id,
			"enemy_name": str(enemy.get("name", enemy_id))
		})
	entry["attackers"] = attackers
	injured[npc_id] = entry
	_active_battle["injured_npcs"] = injured
	if bool(damage_result.get("unconscious", false)) or hp_after <= 0:
		_record_battle_npc_unconscious(npc_id, "enemy_attack")


func _record_battle_npc_unconscious(npc_id: String, reason: String) -> void:
	if _active_battle.is_empty() or npc_id.is_empty():
		return
	var unconscious: Dictionary = _active_battle.get("unconscious_npcs", {})
	if unconscious.has(npc_id):
		return
	var state := _get_npc_state(npc_id)
	unconscious[npc_id] = {
		"npc_id": npc_id,
		"npc_name": _get_npc_name(npc_id),
		"reason": reason,
		"hp": int(state.get("hp", 0)),
		"max_hp": int(state.get("max_hp", 0))
	}
	_active_battle["unconscious_npcs"] = unconscious


func _build_enemy_roster_from_spawned(spawned: Array[Dictionary]) -> Array[Dictionary]:
	var by_key: Dictionary = {}
	var order: Array[String] = []
	for enemy in spawned:
		var key := str(enemy.get("enemy_type_id", enemy.get("name", enemy.get("unit_type", "enemy"))))
		if not by_key.has(key):
			order.append(key)
			by_key[key] = {
				"enemy_type_id": str(enemy.get("enemy_type_id", key)),
				"name": str(enemy.get("name", key)),
				"unit_type": str(enemy.get("unit_type", "")),
				"unit_type_label": _get_unit_type_label(str(enemy.get("unit_type", ""))),
				"weapon_type": str(enemy.get("weapon_type", "")),
				"count": 0,
				"max_hp": int(enemy.get("max_hp", enemy.get("hp", 0)))
			}
		var entry: Dictionary = by_key.get(key, {})
		entry["count"] = int(entry.get("count", 0)) + 1
		by_key[key] = entry
	var result: Array[Dictionary] = []
	for key in order:
		var entry: Dictionary = by_key.get(key, {}) if by_key.get(key, {}) is Dictionary else {}
		result.append(entry.duplicate(true))
	return result


func _build_friendly_combatant_roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return result
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		if not _is_npc_combat_eligible(npc_id, npc_system):
			continue
		var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system.has_method("get_npc") else {}
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		var unit_snapshot := _get_npc_unit_type_snapshot(npc_id)
		result.append({
			"npc_id": npc_id,
			"npc_name": str(npc.get("name", npc_id)),
			"unit_type": str(unit_snapshot.get("unit_type", "")),
			"unit_type_label": str(unit_snapshot.get("unit_type_label", "")),
			"main_weapon_id": str(unit_snapshot.get("main_weapon_id", "")),
			"main_weapon_name": str(unit_snapshot.get("main_weapon_name", "")),
			"has_mount": bool(unit_snapshot.get("has_mount", false)),
			"hp": int(state.get("hp", 0)),
			"max_hp": int(state.get("max_hp", 0)),
			"behavior_mode": _get_npc_behavior_mode(npc_system, npc_id)
		})
	return result


func _build_active_enemy_battlefield_roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy_id in get_active_enemy_ids():
		var enemy: Dictionary = _active_enemies.get(enemy_id, {}) if _active_enemies.get(enemy_id, {}) is Dictionary else {}
		if enemy.is_empty():
			continue
		result.append({
			"enemy_id": enemy_id,
			"name": str(enemy.get("name", enemy_id)),
			"enemy_type_id": str(enemy.get("enemy_type_id", "")),
			"unit_type": str(enemy.get("unit_type", "")),
			"unit_type_label": _get_unit_type_label(str(enemy.get("unit_type", ""))),
			"weapon_type": str(enemy.get("weapon_type", "")),
			"hp": int(enemy.get("hp", 0)),
			"max_hp": int(enemy.get("max_hp", enemy.get("hp", 0))),
			"position": _vector3_to_dict(enemy.get("position", Vector3.ZERO))
		})
	return result


func _build_noncombatant_battlefield_roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return result
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		if _is_npc_combat_eligible(npc_id, npc_system):
			continue
		var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system.has_method("get_npc") else {}
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		result.append({
			"npc_id": npc_id,
			"npc_name": str(npc.get("name", npc_id)),
			"hp": int(state.get("hp", 0)),
			"max_hp": int(state.get("max_hp", 0)),
			"behavior_mode": _get_npc_behavior_mode(npc_system, npc_id),
			"current_location": str(state.get("current_location", PLAZA_LOCATION_ID)),
			"current_action": str(state.get("current_action", "idle"))
		})
	return result


func _extract_battlefield_npc_ids(roster: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for entry in roster:
		var npc_id := str(entry.get("npc_id", ""))
		if not npc_id.is_empty() and not ids.has(npc_id):
			ids.append(npc_id)
	return ids


func _build_battlefield_target_snapshot(npc_id: String) -> Dictionary:
	if npc_id.is_empty():
		return {}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return {}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}
	var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
	var unit_snapshot := _get_npc_unit_type_snapshot(npc_id)
	return {
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"behavior_mode": _get_npc_behavior_mode(npc_system, npc_id),
		"unit_type": str(unit_snapshot.get("unit_type", "")),
		"unit_type_label": str(unit_snapshot.get("unit_type_label", "")),
		"has_main_weapon": bool(unit_snapshot.get("has_main_weapon", false)),
		"hp": int(state.get("hp", 0)),
		"max_hp": int(state.get("max_hp", 0)),
		"current_action": str(state.get("current_action", "idle")),
		"morale_boost": state.get("morale_boost", {}),
		"escape_intent": state.get("escape_intent", {})
	}


func _summarize_battlefield_context(context: Dictionary) -> Dictionary:
	return {
		"active_enemy_count": int(context.get("active_enemy_count", 0)),
		"friendly_combatant_count": int(context.get("friendly_combatant_count", 0)),
		"noncombatant_count": int(context.get("noncombatant_count", 0)),
		"target_npc": context.get("target_npc", {}),
		"enemy_roster": context.get("enemy_roster", []),
		"friendly_roster": context.get("friendly_roster", [])
	}


func _get_noncombatant_count(friendly_count: int) -> int:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return 0
	var npc_ids: Array = npc_system.get_npc_ids()
	return maxi(0, npc_ids.size() - friendly_count)


func _battle_map_to_sorted_array(raw_map: Variant) -> Array[Dictionary]:
	var source: Dictionary = raw_map if raw_map is Dictionary else {}
	var result: Array[Dictionary] = []
	for key in source.keys():
		var entry: Dictionary = source.get(key, {}) if source.get(key, {}) is Dictionary else {}
		if not entry.is_empty():
			result.append(entry.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("npc_id", left.get("enemy_id", ""))) < str(right.get("npc_id", right.get("enemy_id", "")))
	)
	return result


func _array_has_id(entries: Array, key: String, value: String) -> bool:
	for raw_entry in entries:
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if str(entry.get(key, "")) == value:
			return true
	return false


func _get_npc_name(npc_id: String) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc"):
		var npc: Dictionary = npc_system.get_npc(npc_id)
		return str(npc.get("name", npc_id))
	return npc_id


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


func _get_npc_state(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc_state"):
		return npc_system.get_npc_state(npc_id)
	return {}


func _get_npc_unit_type_snapshot(npc_id: String) -> Dictionary:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_unit_type_snapshot"):
		return {}
	return equipment_system.get_unit_type_snapshot(npc_id)


func _extract_combat_strategy_id(raw_strategy: Variant) -> String:
	if raw_strategy is Dictionary:
		return str((raw_strategy as Dictionary).get("id", "")).strip_edges()
	return str(raw_strategy).strip_edges()


func _get_combat_strategy_label(strategy_id: String) -> String:
	return str(COMBAT_STRATEGY_LABELS.get(strategy_id, strategy_id))


func _strategy_options_have_id(options: Array[Dictionary], strategy_id: String) -> bool:
	for option in options:
		if str(option.get("id", "")) == strategy_id:
			return true
	return false


func _set_npc_combat_strategy(
	npc_id: String,
	strategy_id: String,
	visibility: String,
	reason: String,
	should_log: bool
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("update_npc_state"):
		return {"ok": false, "error": "npc_system_missing", "npc_id": npc_id}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {"ok": false, "error": "unknown_npc", "npc_id": npc_id}
	if not bool(npc.get("recruited", false)):
		return {"ok": false, "error": "npc_not_recruited", "message": "只有已入伍 NPC 可以设置战斗策略。", "npc_id": npc_id}

	var snapshot := _get_npc_unit_type_snapshot(npc_id)
	if snapshot.is_empty() or not bool(snapshot.get("has_main_weapon", false)):
		return {"ok": false, "error": "no_main_weapon", "message": "NPC 没有主武器，无法设置战斗策略。", "npc_id": npc_id}
	var options := get_combat_strategy_options_for_unit_type(str(snapshot.get("unit_type", "")))
	if options.is_empty():
		return {"ok": false, "error": "no_strategy_options", "message": "当前兵种没有可用战斗策略。", "npc_id": npc_id}
	var clean_strategy_id := strategy_id.strip_edges()
	if not _strategy_options_have_id(options, clean_strategy_id):
		return {
			"ok": false,
			"error": "strategy_not_available",
			"message": "当前装备对应的兵种不能使用该战斗策略。",
			"npc_id": npc_id,
			"strategy_id": clean_strategy_id,
			"available_options": options
		}

	var previous := get_npc_combat_strategy(npc_id)
	var previous_id := _extract_combat_strategy_id(_get_npc_state(npc_id).get("combat_strategy", {}))
	var strategy_state := _make_combat_strategy_state(npc_id, clean_strategy_id, snapshot, reason)
	var changed := previous_id != clean_strategy_id
	npc_system.update_npc_state(npc_id, {
		"combat_strategy": strategy_state,
		"last_action_result": "combat_strategy_selected" if changed else "combat_strategy_unchanged"
	})
	var event := {}
	if should_log and changed:
		event = _log_combat_strategy_selected(npc_id, previous, strategy_state, reason, visibility)
	return {
		"ok": true,
		"changed": changed,
		"npc_id": npc_id,
		"strategy": strategy_state,
		"previous_strategy": previous,
		"available_options": options,
		"event": event
	}


func _make_combat_strategy_state(
	npc_id: String,
	strategy_id: String,
	unit_snapshot: Dictionary,
	reason: String
) -> Dictionary:
	var time_snapshot := _get_game_time_snapshot()
	return {
		"npc_id": npc_id,
		"id": strategy_id,
		"label": _get_combat_strategy_label(strategy_id),
		"unit_type": str(unit_snapshot.get("unit_type", "")),
		"unit_type_label": str(unit_snapshot.get("unit_type_label", "")),
		"selected_by": "guard_officer",
		"reason": reason,
		"day": int(time_snapshot.get("day", 1)),
		"time": str(time_snapshot.get("time", "00:00:00"))
	}


func _log_combat_strategy_selected(
	npc_id: String,
	previous_strategy: Dictionary,
	next_strategy: Dictionary,
	reason: String,
	visibility: String
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var normalized_visibility := "private" if visibility == "private" else "local_public"
	return memory_system.add_event({
		"type": "combat_strategy_selected",
		"subject_npc_id": npc_id,
		"actor_ids": ["guard_officer"],
		"target_ids": [npc_id, str(next_strategy.get("id", ""))],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": normalized_visibility,
		"importance": 60,
		"payload": {
			"npc_id": npc_id,
			"previous_strategy_id": str(previous_strategy.get("id", "")),
			"previous_strategy_label": str(previous_strategy.get("label", "")),
			"strategy_id": str(next_strategy.get("id", "")),
			"strategy_label": str(next_strategy.get("label", "")),
			"unit_type": str(next_strategy.get("unit_type", "")),
			"unit_type_label": str(next_strategy.get("unit_type_label", "")),
			"reason": reason
		}
	})


func _does_npc_have_mount(npc_id: String) -> bool:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_unit_type_snapshot"):
		return false
	var snapshot: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
	return bool(snapshot.get("has_mount", false))


func _is_npc_combat_eligible(npc_id: String, npc_system: Node = null) -> bool:
	var resolved_npc_system := npc_system
	if resolved_npc_system == null:
		resolved_npc_system = get_node_or_null(NPC_SYSTEM_PATH)
	if resolved_npc_system == null or not resolved_npc_system.has_method("get_npc"):
		return false
	var npc: Dictionary = resolved_npc_system.get_npc(npc_id)
	if npc.is_empty() or not bool(npc.get("recruited", false)):
		return false
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system != null and equipment_system.has_method("get_unit_type_snapshot"):
		var snapshot: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
		return bool(snapshot.get("has_main_weapon", false))
	var equipment: Dictionary = npc.get("equipment", {}) if (npc.get("equipment", {}) is Dictionary) else {}
	var main_weapon: Dictionary = equipment.get("main_weapon", {}) if (equipment.get("main_weapon", {}) is Dictionary) else {}
	return not main_weapon.is_empty()


func _rotate_direction_y(direction: Vector3, radians: float) -> Vector3:
	var normalized := direction
	normalized.y = 0.0
	if normalized.length() <= 0.001:
		return Vector3.ZERO
	normalized = normalized.normalized()
	var cos_value := cos(radians)
	var sin_value := sin(radians)
	return Vector3(
		normalized.x * cos_value - normalized.z * sin_value,
		0.0,
		normalized.x * sin_value + normalized.z * cos_value
	).normalized()


func _clamp_avoidance_position(position: Vector3) -> Vector3:
	return Vector3(
		clampf(position.x, AVOIDANCE_MIN_X, AVOIDANCE_MAX_X),
		0.0,
		clampf(position.z, AVOIDANCE_MIN_Z, AVOIDANCE_MAX_Z)
	)


func _constrain_avoidance_step(npc_position: Vector3, proposed_position: Vector3) -> Vector3:
	var clamped_position := _clamp_avoidance_position(proposed_position)
	var clamped_distance := npc_position.distance_to(clamped_position)
	if clamped_distance > AVOIDANCE_STEP_DISTANCE + 0.25:
		return npc_position.move_toward(clamped_position, AVOIDANCE_STEP_DISTANCE)
	return clamped_position


func _get_avoidance_scatter_angle(npc_id: String, enemy_id: String) -> float:
	var hash_value := _stable_hash_text("%s:%s" % [npc_id, enemy_id])
	var normalized := float((hash_value % 2001) - 1000) / 1000.0
	return deg_to_rad(normalized * AVOIDANCE_SCATTER_DEGREES)


func _fallback_avoidance_direction(npc_id: String) -> Vector3:
	var hash_value := _stable_hash_text(npc_id)
	var angle := deg_to_rad(float(hash_value % 360))
	return Vector3(cos(angle), 0.0, sin(angle)).normalized()


func _stable_hash_text(text: String) -> int:
	var value := 0
	for index in range(text.length()):
		value = (value * 131 + text.unicode_at(index)) % 1000003
	return value


func _get_behavior_mode_snapshots() -> Array:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("debug_get_behavior_mode_snapshot"):
		return []
	var raw: Variant = npc_system.debug_get_behavior_mode_snapshot()
	return raw if raw is Array else []


func _get_combat_strategy_snapshots() -> Array[Dictionary]:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return []
	var result: Array[Dictionary] = []
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var strategy := get_npc_combat_strategy(npc_id)
		if strategy.is_empty():
			continue
		result.append(strategy)
	return result


func _is_frontline_unit(unit_type: String) -> bool:
	return ["melee_infantry", "polearm_infantry", "cavalry"].has(unit_type)


func _select_enemy_target(enemy: Dictionary) -> Dictionary:
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	var preferences := _normalize_enemy_target_preferences(enemy.get("target_preference", DEFAULT_TARGET_PREFERENCE))
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


func _advance_enemy_attack(enemy: Dictionary, target: Dictionary, combat_delta_seconds: float) -> Dictionary:
	var remaining := combat_delta_seconds
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
		"combat_seconds": combat_delta_seconds,
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
	var raw_attack_power := maxf(1.0, float(enemy.get("attack_power", 1.0)))
	match target_type:
		"npc":
			var target_defense := _calculate_npc_defense(target_id)
			var damage := _calculate_actual_hp_damage(raw_attack_power, target_defense)
			return _apply_enemy_attack_to_npc(enemy, target_id, damage, raw_attack_power, target_defense)
		"building":
			return _apply_enemy_attack_to_building(enemy, target_id, maxi(1, int(round(raw_attack_power))))
		_:
			return {}


func _apply_enemy_attack_to_npc(
	enemy: Dictionary,
	npc_id: String,
	damage: int,
	raw_attack_power: float,
	target_defense: float
) -> Dictionary:
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
			"enemy_attack": true,
			"enemy_id": enemy_id,
			"enemy_name": enemy_name,
			"raw_attack_power": raw_attack_power,
			"target_defense": target_defense,
			"damage_after_defense": damage
		}
	)
	if not damage_result.is_empty():
		_record_battle_npc_damage(npc_id, npc_name, enemy, damage_result)
	return {
		"target_type": "npc",
		"target_id": npc_id,
		"raw_attack_power": raw_attack_power,
		"target_defense": target_defense,
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
	var target_preference := _normalize_enemy_target_preferences(raw_enemy.get("target_preference", DEFAULT_TARGET_PREFERENCE))
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


func _normalize_enemy_target_preferences(raw_value: Variant) -> Array[String]:
	var result: Array[String] = []
	for raw_item in _normalize_string_array(raw_value):
		var target_id := _normalize_building_target_id(raw_item)
		if target_id == "wall":
			continue
		if not result.has(target_id):
			result.append(target_id)
	return result


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


func _normalize_wartime_reaction(reaction: String) -> String:
	var clean_reaction := reaction.strip_edges()
	if WARTIME_REACTIONS.has(clean_reaction):
		return clean_reaction
	return WARTIME_REACTION_NONE


func _wartime_reaction_failure(error_code: String, message: String, npc_id: String, reaction: String, extra: Dictionary = {}) -> Dictionary:
	_last_wartime_dialogue_result = {
		"ok": false,
		"error": error_code,
		"message": message,
		"npc_id": npc_id,
		"reaction": _normalize_wartime_reaction(reaction)
	}
	for key in extra.keys():
		_last_wartime_dialogue_result[key] = extra[key]
	return _last_wartime_dialogue_result.duplicate(true)


func _low_hp_judgement_skip(reason: String, npc_id: String, damage_result: Dictionary, context: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"triggered": false,
		"reason": reason,
		"npc_id": npc_id,
		"damage_result": damage_result.duplicate(true),
		"context": context.duplicate(true)
	}


func _low_hp_judgement_failure(error_code: String, message: String, npc_id: String, damage_result: Dictionary, context: Dictionary) -> Dictionary:
	_last_low_hp_judgement_result = {
		"ok": false,
		"triggered": false,
		"error": error_code,
		"message": message,
		"npc_id": npc_id,
		"damage_result": damage_result.duplicate(true),
		"context": context.duplicate(true)
	}
	return _last_low_hp_judgement_result.duplicate(true)


func _has_low_hp_judgement_for_active_battle(npc_id: String) -> bool:
	if _active_battle.is_empty() or npc_id.is_empty():
		return false
	var judgements: Dictionary = _active_battle.get("low_hp_judgements", {}) if _active_battle.get("low_hp_judgements", {}) is Dictionary else {}
	return judgements.has(npc_id)


func _mark_low_hp_judgement_for_active_battle(npc_id: String, entry: Dictionary) -> void:
	if _active_battle.is_empty() or npc_id.is_empty():
		return
	var judgements: Dictionary = _active_battle.get("low_hp_judgements", {}) if _active_battle.get("low_hp_judgements", {}) is Dictionary else {}
	judgements[npc_id] = entry.duplicate(true)
	_active_battle["low_hp_judgements"] = judgements


func _update_low_hp_judgement_for_active_battle(npc_id: String, changes: Dictionary) -> void:
	if _active_battle.is_empty() or npc_id.is_empty():
		return
	var judgements: Dictionary = _active_battle.get("low_hp_judgements", {}) if _active_battle.get("low_hp_judgements", {}) is Dictionary else {}
	var entry: Dictionary = judgements.get(npc_id, {}) if judgements.get(npc_id, {}) is Dictionary else {}
	for key in changes.keys():
		entry[key] = changes[key]
	judgements[npc_id] = entry
	_active_battle["low_hp_judgements"] = judgements


func _get_low_hp_allowed_decisions(combatant_decisions_allowed: bool) -> Array[String]:
	if combatant_decisions_allowed:
		return [
			BATTLE_DECISION_CONTINUE_FIGHTING,
			BATTLE_DECISION_ESCAPE_STATION,
			BATTLE_DECISION_INSPIRED
		]
	return [
		BATTLE_DECISION_AVOID_BATTLE,
		BATTLE_DECISION_ESCAPE_STATION
	]


func _normalize_low_hp_decision(raw_decision: String, allowed_decisions: Array[String]) -> String:
	var clean_decision := raw_decision.strip_edges()
	match clean_decision:
		WARTIME_REACTION_MORALE_BOOST:
			clean_decision = BATTLE_DECISION_INSPIRED
		WARTIME_REACTION_ESCAPE:
			clean_decision = BATTLE_DECISION_ESCAPE_STATION
		WARTIME_REACTION_NONE:
			clean_decision = allowed_decisions[0] if not allowed_decisions.is_empty() else BATTLE_DECISION_AVOID_BATTLE
	if not BATTLE_DECISIONS.has(clean_decision):
		clean_decision = allowed_decisions[0] if not allowed_decisions.is_empty() else BATTLE_DECISION_AVOID_BATTLE
	if not allowed_decisions.has(clean_decision):
		clean_decision = allowed_decisions[0] if not allowed_decisions.is_empty() else BATTLE_DECISION_AVOID_BATTLE
	return clean_decision


func _battle_decision_to_psychology_decision(decision: String) -> String:
	match decision:
		BATTLE_DECISION_INSPIRED:
			return WARTIME_REACTION_MORALE_BOOST
		BATTLE_DECISION_ESCAPE_STATION:
			return WARTIME_REACTION_ESCAPE
		BATTLE_DECISION_CONTINUE_FIGHTING, BATTLE_DECISION_JOIN_BATTLE:
			return BATTLE_DECISION_CONTINUE_FIGHTING
		BATTLE_DECISION_AVOID_BATTLE:
			return BATTLE_DECISION_AVOID_BATTLE
		_:
			return WARTIME_REACTION_NONE


func _log_low_hp_triggered(npc_id: String, damage_result: Dictionary, context: Dictionary, behavior_mode: String, combatant_decisions_allowed: bool) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var damage_event: Dictionary = damage_result.get("damage_event", {}) if damage_result.get("damage_event", {}) is Dictionary else {}
	var source_actor_id := str(damage_result.get("actor_id", context.get("enemy_id", context.get("actor_id", SYSTEM_ACTOR_ID)))).strip_edges()
	if source_actor_id.is_empty():
		source_actor_id = SYSTEM_ACTOR_ID
	var hp_before := int(damage_result.get("hp_before", 0))
	var hp_after := int(damage_result.get("hp_after", hp_before))
	var max_hp := maxi(1, int(damage_result.get("max_hp", 100)))
	return memory_system.add_event({
		"type": "low_hp_triggered",
		"subject_npc_id": npc_id,
		"actor_ids": [source_actor_id],
		"target_ids": [npc_id, PLAZA_LOCATION_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 85,
		"payload": {
			"hp_before": hp_before,
			"hp_after": hp_after,
			"max_hp": max_hp,
			"damage": int(damage_result.get("damage", maxi(0, hp_before - hp_after))),
			"damage_source": source_actor_id,
			"damage_event_id": str(damage_event.get("event_id", "")),
			"threshold_ratio": LOW_HP_JUDGEMENT_RATIO,
			"behavior_mode": behavior_mode,
			"combatant_decisions_allowed": combatant_decisions_allowed,
			"wave_number": int(_active_battle.get("wave_number", 0)),
			"wave_id": str(_active_battle.get("wave_id", "")),
			"active_enemy_count": get_active_enemy_count()
		}
	})


func _force_end_dialogue_for_low_hp(npc_id: String) -> Dictionary:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("force_end_dialogue_for_npc"):
		return {"ok": true, "ended": false, "reason": "dialog_system_missing"}
	return dialog_system.force_end_dialogue_for_npc(npc_id, "low_hp_judgement")


func _request_low_hp_battle_judgement(
	npc_id: String,
	low_hp_event: Dictionary,
	damage_result: Dictionary,
	damage_context: Dictionary,
	battlefield_context: Dictionary,
	allowed_decisions: Array[String],
	behavior_mode: String
) -> Dictionary:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("request_npc_battle_judgement"):
		return {"ok": false, "error": "llm_bridge_missing", "message": "LLMBridge 不可用。"}
	var hp_before := int(damage_result.get("hp_before", 0))
	var hp_after := int(damage_result.get("hp_after", hp_before))
	var max_hp := maxi(1, int(damage_result.get("max_hp", 100)))
	var combat_context := {
		"trigger": "low_hp",
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"hp_ratio": float(hp_after) / float(max_hp),
		"threshold_ratio": LOW_HP_JUDGEMENT_RATIO,
		"behavior_mode": behavior_mode,
		"damage": int(damage_result.get("damage", maxi(0, hp_before - hp_after))),
		"damage_source": str(damage_result.get("actor_id", damage_context.get("enemy_id", ""))),
		"combatant_decisions_allowed": allowed_decisions.has(BATTLE_DECISION_INSPIRED),
		"low_hp_event_id": str(low_hp_event.get("event_id", ""))
	}
	return llm_bridge.request_npc_battle_judgement(npc_id, {
		"trigger": "low_hp",
		"reason": "low_hp",
		"related_event_id": str(low_hp_event.get("event_id", "")),
		"interaction_context": behavior_mode,
		"combat_context": combat_context,
		"battlefield_context": battlefield_context,
		"allowed_decisions": allowed_decisions
	})


func _make_low_hp_rule_fallback_judgement(npc_id: String, allowed_decisions: Array[String], error_result: Dictionary) -> Dictionary:
	var decision := allowed_decisions[0] if not allowed_decisions.is_empty() else BATTLE_DECISION_AVOID_BATTLE
	return {
		"ok": true,
		"npc_id": npc_id,
		"decision": decision,
		"emotion": "tense",
		"morale_delta_intent": 0,
		"should_start_escape": decision == BATTLE_DECISION_ESCAPE_STATION,
		"rule_fallback": true,
		"fallback_error": str(error_result.get("error", "")),
		"debug_reason": "rule_low_hp_first_allowed_decision"
	}


func _apply_low_hp_judgement_result(npc_id: String, judgement: Dictionary, context: Dictionary) -> Dictionary:
	var allowed_decisions: Array[String] = []
	for raw_decision in _normalize_string_array(context.get("allowed_decisions", [])):
		if BATTLE_DECISIONS.has(raw_decision) and not allowed_decisions.has(raw_decision):
			allowed_decisions.append(raw_decision)
	if allowed_decisions.is_empty():
		allowed_decisions = _get_low_hp_allowed_decisions(bool(context.get("combatant_decisions_allowed", false)))
	var decision := _normalize_low_hp_decision(str(judgement.get("decision", "")), allowed_decisions)
	var psychology_decision := _battle_decision_to_psychology_decision(decision)
	var low_hp_event: Dictionary = context.get("low_hp_event", {}) if context.get("low_hp_event", {}) is Dictionary else {}
	var source_event_id := str(low_hp_event.get("event_id", ""))
	var battlefield_context: Dictionary = context.get("battlefield_context", {}) if context.get("battlefield_context", {}) is Dictionary else {}
	var behavior_mode := str(context.get("behavior_mode", ""))
	var result_event := _log_battle_psychology_result(npc_id, psychology_decision, {
		"trigger": "low_hp",
		"source_event_id": source_event_id,
		"low_hp_event_id": source_event_id,
		"interaction_context": behavior_mode,
		"raw_decision": str(judgement.get("decision", "")),
		"emotion": str(judgement.get("emotion", "")),
		"morale_delta_intent": int(judgement.get("morale_delta_intent", 0)),
		"rule_fallback": bool(judgement.get("rule_fallback", false))
	}, battlefield_context)
	var state_result := {}
	match decision:
		BATTLE_DECISION_INSPIRED:
			state_result = _start_morale_boost(npc_id, source_event_id, "low_hp")
		BATTLE_DECISION_ESCAPE_STATION:
			state_result = _start_escape_intent(npc_id, source_event_id, {
				"trigger": "low_hp",
				"interaction_context": behavior_mode
			})
		BATTLE_DECISION_CONTINUE_FIGHTING, BATTLE_DECISION_JOIN_BATTLE:
			state_result = {"ok": true, "applied": false, "reason": "continue_fighting"}
		BATTLE_DECISION_AVOID_BATTLE:
			state_result = {"ok": true, "applied": false, "reason": "continue_avoid_combat"}
		_:
			state_result = {"ok": true, "applied": false, "reason": "none"}

	var llm_result: Dictionary = context.get("llm_result", {}) if context.get("llm_result", {}) is Dictionary else {}
	var dialogue_result: Dictionary = context.get("dialogue_result", {}) if context.get("dialogue_result", {}) is Dictionary else {}
	_update_low_hp_judgement_for_active_battle(npc_id, {
		"status": "completed",
		"decision": decision,
		"psychology_decision": psychology_decision,
		"emotion": str(judgement.get("emotion", "")),
		"rule_fallback": bool(judgement.get("rule_fallback", false)),
		"battle_psychology_event_id": str(result_event.get("event_id", "")),
		"state_result": state_result.duplicate(true),
		"dialogue_result": dialogue_result.duplicate(true),
		"llm_ok": bool(llm_result.get("ok", false))
	})

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system != null and npc_system.has_method("get_npc") else {}
	_last_low_hp_judgement_result = {
		"ok": true,
		"triggered": true,
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"decision": decision,
		"psychology_decision": psychology_decision,
		"allowed_decisions": allowed_decisions,
		"behavior_mode": behavior_mode,
		"combatant_decisions_allowed": bool(context.get("combatant_decisions_allowed", false)),
		"low_hp_event": low_hp_event.duplicate(true),
		"battle_psychology_event": result_event.duplicate(true),
		"state_result": state_result.duplicate(true),
		"dialogue_result": dialogue_result.duplicate(true),
		"llm_ok": bool(llm_result.get("ok", false)),
		"rule_fallback": bool(judgement.get("rule_fallback", false))
	}
	return _last_low_hp_judgement_result.duplicate(true)


func _start_morale_boost(npc_id: String, source_event_id: String, trigger: String = "wartime_dialogue") -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("update_npc_state"):
		return {"ok": false, "error": "npc_system_missing", "npc_id": npc_id}
	var time_snapshot := _get_game_time_snapshot()
	var morale_state := {
		"active": true,
		"source_event_id": source_event_id,
		"duration_seconds": MORALE_BOOST_DURATION_SECONDS,
		"remaining_game_seconds": MORALE_BOOST_DURATION_SECONDS,
		"attack_bonus": MORALE_BOOST_ATTACK_BONUS,
		"move_speed_bonus": MORALE_BOOST_MOVE_SPEED_BONUS,
		"trigger": trigger,
		"started_day": int(time_snapshot.get("day", 1)),
		"started_time": str(time_snapshot.get("time", "00:00:00"))
	}
	npc_system.update_npc_state(npc_id, {
		"morale_boost": morale_state,
		"last_action_result": "morale_boost_started"
	})
	var event := _log_morale_boost_started(npc_id, morale_state)
	return {
		"ok": true,
		"applied": true,
		"npc_id": npc_id,
		"morale_boost": morale_state,
		"event": event
	}


func _start_escape_intent(npc_id: String, source_event_id: String, context: Dictionary) -> Dictionary:
	var trigger := str(context.get("trigger", "wartime_dialogue"))
	return start_npc_escape(npc_id, source_event_id, trigger, context)


func _pause_escape_for_unconscious(npc_id: String, reason: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_state") or not npc_system.has_method("update_npc_state"):
		return {"ok": false, "error": "npc_system_missing", "npc_id": npc_id}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	if not _is_escape_intent_resumable(intent):
		return {"ok": true, "applied": false, "reason": "no_active_escape", "npc_id": npc_id}
	intent["active"] = true
	intent["status"] = ESCAPE_STATUS_PAUSED_UNCONSCIOUS
	intent["paused_reason"] = reason
	intent["paused_day"] = int(_get_game_time_snapshot().get("day", 1))
	intent["paused_time"] = str(_get_game_time_snapshot().get("time", "00:00:00"))
	npc_system.update_npc_state(npc_id, {
		"escape_intent": intent,
		"last_action_result": "escape_paused_unconscious"
	})
	var snapshot := _sync_active_escape_from_state(npc_id)
	return {
		"ok": true,
		"applied": true,
		"active_escape": true,
		"npc_id": npc_id,
		"status": ESCAPE_STATUS_PAUSED_UNCONSCIOUS,
		"escape_intent": intent.duplicate(true),
		"snapshot": snapshot
	}


func _resume_escape_after_revive(npc_id: String, npc_system: Node) -> Dictionary:
	if npc_system == null or not npc_system.has_method("get_npc_state"):
		return {"ok": false, "active_escape": false, "error": "npc_system_missing", "npc_id": npc_id}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	if not _is_escape_intent_resumable(intent):
		return {"ok": true, "applied": false, "active_escape": false, "reason": "no_active_escape", "npc_id": npc_id}
	if bool(state.get("escaped", false)):
		return {"ok": true, "applied": false, "active_escape": false, "reason": "already_escaped", "npc_id": npc_id}
	if bool(state.get("unconscious", false)):
		return {"ok": true, "applied": false, "active_escape": true, "reason": "still_unconscious", "npc_id": npc_id}
	if not npc_system.has_method("set_npc_behavior_mode") or not npc_system.has_method("move_npc_to_world_position"):
		return _escape_failure("npc_system_missing_escape_api", "NPC 系统缺少逃离所需接口。", npc_id)
	intent["active"] = true
	intent["status"] = ESCAPE_STATUS_ESCAPING
	intent["resumed_day"] = int(_get_game_time_snapshot().get("day", 1))
	intent["resumed_time"] = str(_get_game_time_snapshot().get("time", "00:00:00"))
	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_ESCAPED, "escape_resumed_after_revive", {
		"interrupt": true,
		"stop_movement": true,
		"suppress_mode_event": true,
		"request_plan_reevaluation": false,
		"state_changes": {
			"escaped": false,
			"escape_intent": intent,
			"current_action": "escaping_station",
			"last_action_result": "escape_resumed_after_revive",
			"combat_target_enemy_id": "",
			"morale_boost": {}
		}
	})
	if not bool(mode_result.get("ok", false)):
		return _escape_failure("mode_switch_failed", "无法恢复逃离状态。", npc_id, {"mode_result": mode_result, "active_escape": true})
	var arrival_state := {
		"escape_finalize": true,
		"allow_escaping_movement": true,
		"escape_reason": "escape_completed",
		"escape_trigger": str(intent.get("trigger", "resume_after_revive")),
		"source_event_id": str(intent.get("source_event_id", "")),
		"exit_target_id": ESCAPE_TARGET_ID,
		"exit_target_name": ESCAPE_TARGET_NAME
	}
	var moved := bool(npc_system.move_npc_to_world_position(npc_id, ESCAPE_TARGET_ID, ESCAPE_TARGET_NAME, ESCAPE_EXIT_POSITION, arrival_state))
	if not moved:
		return _escape_failure("movement_failed", "无法让复苏 NPC 继续前往后门出口。", npc_id, {"mode_result": mode_result, "active_escape": true})
	var snapshot := _sync_active_escape_from_state(npc_id)
	var result := {
		"ok": true,
		"applied": true,
		"active_escape": true,
		"npc_id": npc_id,
		"status": ESCAPE_STATUS_ESCAPING,
		"escape_intent": intent.duplicate(true),
		"mode_result": mode_result,
		"snapshot": snapshot
	}
	_last_escape_result = result.duplicate(true)
	return result


func _change_escape_speed_multiplier(npc_id: String, trigger: String, factor: float, context: Dictionary = {}) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_state") or not npc_system.has_method("update_npc_state"):
		return {"ok": false, "applied": false, "error": "npc_system_missing", "npc_id": npc_id}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	if not _is_escape_intent_resumable(intent):
		return {"ok": true, "applied": false, "reason": "no_active_escape", "npc_id": npc_id}
	var before := _get_escape_speed_multiplier(intent)
	var after := clampf(before * factor, ESCAPE_SPEED_MIN_MULTIPLIER, ESCAPE_SPEED_MAX_MULTIPLIER)
	intent["speed_multiplier"] = after
	intent["last_speed_change_trigger"] = trigger
	intent["last_speed_change_day"] = int(_get_game_time_snapshot().get("day", 1))
	intent["last_speed_change_time"] = str(_get_game_time_snapshot().get("time", "00:00:00"))
	if trigger == "money_given":
		intent["money_slow_count"] = int(intent.get("money_slow_count", 0)) + 1
	elif trigger == "guard_attack":
		intent["attack_speed_count"] = int(intent.get("attack_speed_count", 0)) + 1
	npc_system.update_npc_state(npc_id, {
		"escape_intent": intent,
		"last_action_result": "escape_speed_%s" % trigger
	})
	var event := _log_escape_speed_changed(npc_id, trigger, before, after, context)
	var snapshot := _sync_active_escape_from_state(npc_id)
	var result := {
		"ok": true,
		"applied": true,
		"npc_id": npc_id,
		"trigger": trigger,
		"speed_multiplier_before": before,
		"speed_multiplier_after": after,
		"escape_intent": intent.duplicate(true),
		"event": event,
		"snapshot": snapshot
	}
	_last_escape_result = result.duplicate(true)
	return result


func _sync_active_escape_from_state(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("get_npc_state"):
		return {}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	if not _is_escape_intent_resumable(intent):
		_active_escapes.erase(npc_id)
		return {}
	var existing: Dictionary = _active_escapes.get(npc_id, {}) if (_active_escapes.get(npc_id, {}) is Dictionary) else {}
	var snapshot := existing.duplicate(true)
	snapshot["ok"] = true
	snapshot["applied"] = true
	snapshot["npc_id"] = npc_id
	snapshot["npc_name"] = str(npc.get("name", npc_id))
	snapshot["status"] = str(intent.get("status", ESCAPE_STATUS_ESCAPING))
	snapshot["behavior_mode"] = _get_npc_behavior_mode(npc_system, npc_id)
	snapshot["escape_intent"] = intent.duplicate(true)
	snapshot["intervention_rounds_used"] = int(intent.get("intervention_rounds_used", 0))
	snapshot["intervention_max_rounds"] = ESCAPE_INTERVENTION_MAX_ROUNDS
	snapshot["intervention_rounds_left"] = maxi(0, ESCAPE_INTERVENTION_MAX_ROUNDS - int(intent.get("intervention_rounds_used", 0)))
	snapshot["speed_multiplier"] = _get_escape_speed_multiplier(intent)
	snapshot["target_id"] = str(intent.get("exit_target_id", ESCAPE_TARGET_ID))
	snapshot["target_name"] = str(intent.get("exit_target_name", ESCAPE_TARGET_NAME))
	snapshot["target_position"] = _vector3_to_dict(ESCAPE_EXIT_POSITION)
	_active_escapes[npc_id] = snapshot.duplicate(true)
	return snapshot


func _get_escape_intent_from_state(state: Dictionary) -> Dictionary:
	var intent: Dictionary = state.get("escape_intent", {}) if state.get("escape_intent", {}) is Dictionary else {}
	return intent.duplicate(true)


func _is_escape_intent_resumable(intent: Dictionary) -> bool:
	if not bool(intent.get("active", false)):
		return false
	return [ESCAPE_STATUS_ESCAPING, ESCAPE_STATUS_PAUSED_UNCONSCIOUS].has(str(intent.get("status", "")))


func _get_escape_speed_multiplier(intent: Dictionary) -> float:
	return clampf(float(intent.get("speed_multiplier", ESCAPE_SPEED_DEFAULT_MULTIPLIER)), ESCAPE_SPEED_MIN_MULTIPLIER, ESCAPE_SPEED_MAX_MULTIPLIER)


func _normalize_escape_intervention_decision(response_intent: String) -> String:
	if response_intent == "stay_after_intervention":
		return ESCAPE_DECISION_STAY
	return ESCAPE_DECISION_CONTINUE


func _log_escape_intervention_result(
	npc_id: String,
	decision: String,
	intent: Dictionary,
	response: Dictionary,
	context: Dictionary
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "escape_intervention_result",
		"subject_npc_id": npc_id,
		"actor_ids": ["guard_officer"],
		"target_ids": [npc_id, PLAZA_LOCATION_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 88 if decision == ESCAPE_DECISION_STAY else 78,
		"payload": {
			"npc_id": npc_id,
			"decision": decision,
			"intent": str(response.get("intent", "")),
			"current_round": int(intent.get("intervention_rounds_used", 0)),
			"max_rounds": ESCAPE_INTERVENTION_MAX_ROUNDS,
			"rounds_left": maxi(0, ESCAPE_INTERVENTION_MAX_ROUNDS - int(intent.get("intervention_rounds_used", 0))),
			"dialogue_id": str(context.get("dialogue_id", "")),
			"dialogue_event_id": str(context.get("dialogue_event_id", "")),
			"reply_text": str(response.get("reply_text", "")),
			"source_event_id": str(intent.get("source_event_id", "")),
			"speed_multiplier": _get_escape_speed_multiplier(intent)
		}
	})


func _log_escape_speed_changed(
	npc_id: String,
	trigger: String,
	before: float,
	after: float,
	context: Dictionary
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "escape_speed_changed",
		"subject_npc_id": npc_id,
		"actor_ids": ["guard_officer"],
		"target_ids": [npc_id, PLAZA_LOCATION_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 74,
		"payload": {
			"npc_id": npc_id,
			"trigger": trigger,
			"speed_multiplier_before": before,
			"speed_multiplier_after": after,
			"amount": int(context.get("amount", 0)),
			"damage": int(context.get("damage", 0)),
			"source_event_id": str(context.get("source_event_id", ""))
		}
	})


func _escape_failure(error: String, message: String, npc_id: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": false,
		"error": error,
		"message": message,
		"npc_id": npc_id
	}
	for key in extra.keys():
		result[str(key)] = extra[key]
	_last_escape_result = result.duplicate(true)
	return result


func _log_escape_started(
	npc_id: String,
	source_event_id: String,
	trigger: String,
	context: Dictionary,
	previous_mode: String
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "escape_started",
		"subject_npc_id": npc_id,
		"actor_ids": [SYSTEM_ACTOR_ID],
		"target_ids": [npc_id, ESCAPE_TARGET_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 90,
		"payload": {
			"npc_id": npc_id,
			"source_event_id": source_event_id,
			"trigger": trigger,
			"interaction_context": str(context.get("interaction_context", previous_mode)),
			"from_mode": previous_mode,
			"exit_target_id": ESCAPE_TARGET_ID,
			"exit_target_name": ESCAPE_TARGET_NAME,
			"exit_position": _vector3_to_dict(ESCAPE_EXIT_POSITION)
		}
	})


func _advance_morale_boosts(game_delta_seconds: float) -> void:
	if game_delta_seconds <= 0.0:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("update_npc_state"):
		return
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		var morale: Dictionary = state.get("morale_boost", {}) if state.get("morale_boost", {}) is Dictionary else {}
		if not bool(morale.get("active", false)):
			continue
		var remaining := maxf(0.0, float(morale.get("remaining_game_seconds", MORALE_BOOST_DURATION_SECONDS)) - game_delta_seconds)
		if remaining > 0.0:
			morale["remaining_game_seconds"] = remaining
			npc_system.update_npc_state(npc_id, {"morale_boost": morale})
			continue
		_log_morale_boost_ended(npc_id, morale)
		npc_system.update_npc_state(npc_id, {
			"morale_boost": {},
			"last_action_result": "morale_boost_ended"
		})


func _get_active_morale_attack_bonus(state: Dictionary) -> float:
	var morale: Dictionary = state.get("morale_boost", {}) if state.get("morale_boost", {}) is Dictionary else {}
	if not bool(morale.get("active", false)):
		return 0.0
	return clampf(float(morale.get("attack_bonus", MORALE_BOOST_ATTACK_BONUS)), 0.0, 1.0)


func _log_battle_psychology_result(npc_id: String, reaction: String, context: Dictionary, battlefield_context: Dictionary) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var clean_decision := reaction.strip_edges()
	if not [
		WARTIME_REACTION_NONE,
		WARTIME_REACTION_ESCAPE,
		WARTIME_REACTION_MORALE_BOOST,
		BATTLE_DECISION_AVOID_BATTLE,
		BATTLE_DECISION_CONTINUE_FIGHTING
	].has(clean_decision):
		clean_decision = WARTIME_REACTION_NONE
	var trigger := str(context.get("trigger", "wartime_dialogue"))
	var actor_id := "guard_officer" if trigger == "wartime_dialogue" else SYSTEM_ACTOR_ID
	return memory_system.add_event({
		"type": "battle_psychology_result",
		"subject_npc_id": npc_id,
		"actor_ids": [actor_id],
		"target_ids": [npc_id, PLAZA_LOCATION_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 80,
		"payload": {
			"trigger": trigger,
			"decision": clean_decision,
			"source_event_id": str(context.get("source_event_id", "")),
			"low_hp_event_id": str(context.get("low_hp_event_id", "")),
			"dialogue_id": str(context.get("dialogue_id", "")),
			"interaction_context": str(context.get("interaction_context", "")),
			"raw_decision": str(context.get("raw_decision", "")),
			"emotion": str(context.get("emotion", "")),
			"morale_delta_intent": int(context.get("morale_delta_intent", 0)),
			"rule_fallback": bool(context.get("rule_fallback", false)),
			"battlefield_context_summary": _summarize_battlefield_context(battlefield_context)
		}
	})


func _log_morale_boost_started(npc_id: String, morale_state: Dictionary) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var trigger := str(morale_state.get("trigger", "wartime_dialogue"))
	var actor_id := "guard_officer" if trigger == "wartime_dialogue" else SYSTEM_ACTOR_ID
	return memory_system.add_event({
		"type": "morale_boost_started",
		"subject_npc_id": npc_id,
		"actor_ids": [actor_id],
		"target_ids": [npc_id, PLAZA_LOCATION_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 80,
		"payload": {
			"source_event_id": str(morale_state.get("source_event_id", "")),
			"trigger": trigger,
			"duration_seconds": float(morale_state.get("duration_seconds", MORALE_BOOST_DURATION_SECONDS)),
			"attack_bonus": float(morale_state.get("attack_bonus", MORALE_BOOST_ATTACK_BONUS)),
			"move_speed_bonus": float(morale_state.get("move_speed_bonus", MORALE_BOOST_MOVE_SPEED_BONUS))
		}
	})


func _log_morale_boost_ended(npc_id: String, morale_state: Dictionary) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "morale_boost_ended",
		"subject_npc_id": npc_id,
		"actor_ids": ["system"],
		"target_ids": [npc_id, PLAZA_LOCATION_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 55,
		"payload": {
			"source_event_id": str(morale_state.get("source_event_id", "")),
			"duration_seconds": float(morale_state.get("duration_seconds", MORALE_BOOST_DURATION_SECONDS))
		}
	})


func _log_combat_started(battle: Dictionary) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var wave_id := str(battle.get("wave_id", ""))
	return memory_system.add_event({
		"type": "combat_started",
		"subject_npc_id": SYSTEM_ACTOR_ID,
		"actor_ids": [SYSTEM_ACTOR_ID],
		"target_ids": [wave_id, PLAZA_LOCATION_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 90,
		"payload": {
			"wave_number": int(battle.get("wave_number", 0)),
			"wave_id": wave_id,
			"enemy_count": int(battle.get("started_enemy_count", 0)),
			"enemy_roster": battle.get("enemy_roster", []),
			"friendly_combatant_count": int(battle.get("friendly_combatant_count", 0)),
			"friendly_roster": battle.get("friendly_roster", []),
			"noncombatant_count": int(battle.get("noncombatant_count", 0)),
			"reason": str(battle.get("reason", "wave_spawned"))
		}
	})


func _log_combat_ended(battle: Dictionary) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var wave_id := str(battle.get("wave_id", ""))
	return memory_system.add_event({
		"type": "combat_ended",
		"subject_npc_id": SYSTEM_ACTOR_ID,
		"actor_ids": [SYSTEM_ACTOR_ID],
		"target_ids": [wave_id, PLAZA_LOCATION_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 90,
		"payload": {
			"wave_number": int(battle.get("wave_number", 0)),
			"wave_id": wave_id,
			"enemy_count": int(battle.get("started_enemy_count", 0)),
			"defeated_enemy_count": int(battle.get("defeated_enemy_count", 0)),
			"remaining_enemy_count": int(battle.get("remaining_enemy_count", 0)),
			"injured_npcs": battle.get("injured_npcs", []),
			"unconscious_npcs": battle.get("unconscious_npcs", []),
			"low_hp_judgements": battle.get("low_hp_judgements", []),
			"defeated_by_npc": battle.get("defeated_by_npc", []),
			"reason": str(battle.get("end_reason", "enemies_defeated")),
			"started_event_id": str(battle.get("started_event_id", ""))
		}
	})


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


func _get_combat_action_seconds(game_delta_seconds: float) -> float:
	return maxf(0.0, game_delta_seconds) / COMBAT_ACTION_GAME_SECONDS_PER_SECOND


func _sync_enemy_presence_time_cap(reason: String) -> Dictionary:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	var should_cap := not _active_enemies.is_empty()
	var result := {
		"ok": false,
		"request_id": COMBAT_TIME_CAP_REQUEST_ID,
		"cap_scale": COMBAT_TIME_CAP_SCALE,
		"active_enemy_count": get_active_enemy_count(),
		"cap_expected": should_cap,
		"reason": reason
	}
	if time_system == null:
		result["error"] = "time_system_missing"
		return result

	if should_cap:
		if time_system.has_method("request_time_scale_cap"):
			time_system.request_time_scale_cap(COMBAT_TIME_CAP_REQUEST_ID, COMBAT_TIME_CAP_SCALE, "combat_enemy_presence")
			result["ok"] = true
			result["action"] = "cap_requested"
		else:
			result["error"] = "time_scale_cap_api_missing"
	else:
		if time_system.has_method("release_time_scale_cap"):
			time_system.release_time_scale_cap(COMBAT_TIME_CAP_REQUEST_ID)
			result["ok"] = true
			result["action"] = "cap_released"
		else:
			result["error"] = "time_scale_cap_api_missing"
	result["time_scale"] = _get_time_scale_snapshot()
	return result


func _get_time_scale_snapshot() -> Dictionary:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		return {}
	if time_system.has_method("get_time_scale_snapshot"):
		return time_system.get_time_scale_snapshot()
	return {
		"player_scale": time_system.get("time_scale"),
		"effective_scale": time_system.get_effective_time_scale() if time_system.has_method("get_effective_time_scale") else null,
		"numeric_multiplier": time_system.get_numeric_delta_multiplier() if time_system.has_method("get_numeric_delta_multiplier") else null
	}


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
