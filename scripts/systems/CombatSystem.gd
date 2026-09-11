extends Node

const WorldFeedbackPayload = preload("res://scripts/core/WorldFeedbackPayload.gd")
const ENEMY_WAVES_FILE := "enemy_waves.json"
const COMBAT_PROGRESSION_FILE := "combat_progression.json"
const ENEMY_ROOT_PATH := "/root/Main/WorldRoot/Station/Enemies"
const FORMAL_ENEMY_ROOT_PATH := "/root/Main/WorldRoot/FormalStationLayout/FormalEnemies"
const STATION_LAYOUT_CONTROLLER_PATH := "/root/Main/Presentation/StationLayoutController"
const ACTOR_MOTION_SCENE := preload("res://scenes/debug/ActorMotionBody.tscn")
const LEGACY_FORMAL_ENEMY_ART_SCENE_PATH := "res://scenes/characters/GlenArtView.tscn"
const SWORD_SHIELD_CHIBI_ART_SCENE_PATH := "res://scenes/characters/EnemySwordShieldChibiArtView.tscn"
const ENEMY_MOUNTED_ART_SCRIPT := preload("res://scripts/presentation/characters/EnemyMountedArtView.gd")
const COMBAT_ANIMATION_TIMING := preload("res://scripts/presentation/characters/CombatAnimationTiming.gd")
const COMBAT_PROJECTILE_VIEW_SCRIPT := preload("res://scripts/presentation/combat/CombatProjectileView.gd")
const WORLD_HEALTH_BAR := preload("res://scripts/world/WorldHealthBar3D.gd")
const ENEMY_NAME_LABEL_HEIGHT := 2.10
const ENEMY_HEALTH_BAR_OFFSET := 0.34
const FORMAL_CHIBI_WEAPON_TYPES := ["sword_shield", "polearm", "bow", "crossbow"]
const RANGED_WEAPON_TYPES := ["bow", "crossbow"]
const MELEE_WEAPON_TYPES := ["sword_shield", "polearm"]
const ENEMY_SWORD_SCENE_PATH := "res://assets/3d/quaternius/props/sword_bronze.glb"
const ENEMY_SHIELD_SCENE_PATH := "res://assets/3d/quaternius/props/shield_wooden.glb"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"
const DEFENSE_DEVICE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const DEFENSE_DEVICE_PRESENTER_PATH := "/root/Main/WorldRoot/Station/DefenseDevices"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const DAILY_REFLECTION_SYSTEM_PATH := "/root/Main/Systems/DailyReflectionSystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const DEFAULT_SPAWN_POINT_ID := "front_forest"
const DEFAULT_FORMAL_WAVE_SPAWN_STAGE_ID := "spawn"
const DEBUG_GM_SPAWN_STAGE_ID := "gm_front_gate_enemy_spawn_zone"
const FORMAL_ENEMY_NAVIGATION_PILOT_ID := "formal_enemy_foot_01"
const FORMAL_ACTIVE_ENEMY_SLICE_ID := "wave_01_formal_enemy_001"
const SYSTEM_ACTOR_ID := "system"
const COMBAT_TIME_SLOWDOWN_REQUEST_ID := "combat_enemy_presence"
const COMBAT_TIME_SLOWDOWN_SCALE := 1.0 / 60.0
const DEFAULT_TARGET_PREFERENCE: Array[String] = ["front_gate", "warehouse", "main_hall", "nearby_unit"]
const ENEMY_BUILDING_TARGET_IDS: Array[String] = ["front_gate", "warehouse", "main_hall"]
const NEARBY_UNIT_TARGET_ID := "nearby_unit"
const MAIN_HALL_ID := "main_hall"
const PLAZA_LOCATION_ID := "plaza"
const ENEMY_DAMAGE_VISIBILITY := "local_public"
const DEFAULT_NEARBY_UNIT_DETECTION_RANGE := 6.0
const FRIENDLY_CONTACT_RANGE := 5.0
const FRIENDLY_TARGET_DETECTION_RANGE_FALLBACK := 37.2
const RALLY_WAIT_TIMEOUT_SECONDS := 3600.0
const RALLY_ARRIVAL_TOLERANCE := 0.3
const MAX_ATTACKS_PER_AI_STEP := 100
const MAX_FRIENDLY_ATTACKS_PER_AI_STEP := 100
const PROJECTILE_COLLISION_MASK := 3
const ENEMY_GATE_COMBAT_CONTACT_LAYER := 8
const PROJECTILE_MAX_SUBSTEP_SECONDS := 1.0 / 120.0
const PROJECTILE_RANGE_EPSILON := 0.000001
const PROJECTILE_MAX_TRANSPARENT_SKIPS_PER_SUBSTEP := 32
const PROJECTILE_TRANSPARENT_BUILDING_IDS: Array[String] = ["front_gate", "main_hall"]
const PROJECTILE_TARGET_HEIGHT_NPC := 0.8
const PROJECTILE_TARGET_HEIGHT_ENEMY_FOOT := 0.9
const PROJECTILE_TARGET_HEIGHT_ENEMY_MOUNTED := 1.25
const PROJECTILE_TARGET_HEIGHT_STRUCTURE := 1.1
const MELEE_COLLISION_MASK := 3
const MELEE_IGNORED_COLLISION_CATEGORIES := ["navigation_floor"]
const ENEMY_PRESENTATION_MOVE_START_SPEED := 0.01
const ENEMY_PRESENTATION_MOVE_STOP_SPEED := 0.003
const ENEMY_PRESENTATION_MOVE_STOP_GRACE_SECONDS := 0.18
const DEFENSE_CURVE_SCALE := 20.0
const STRENGTH_ATTACK_BASELINE := 5.0
const STRENGTH_ATTACK_BONUS_PER_POINT := 0.08
const MIN_STRENGTH_ATTACK_MULTIPLIER := 0.65
const MAX_STRENGTH_ATTACK_MULTIPLIER := 1.45
const WEAPON_PROFICIENCY_ATTACK_SPEED_BONUS_AT_100 := 0.35
const FATIGUE_ATTACK_SPEED_PENALTY_START := 60.0
const FATIGUE_ATTACK_SPEED_MAX_PENALTY := 0.25
const SATIETY_ATTACK_SPEED_PENALTY_START := 35.0
const SATIETY_ATTACK_SPEED_MAX_PENALTY := 0.2
const MIN_ATTACK_SPEED_MULTIPLIER := 0.45
const MIN_NPC_ATTACK_INTERVAL := 0.25
const COMBAT_LEVEL_EXPERIENCE_STEP := 10
const MAX_COMBAT_LEVEL := 10
const LEVEL_ATTACK_POWER_BONUS := 0.6
const LEVEL_DEFENSE_BONUS := 0.3
const LEVEL_PENETRATION_BONUS := 0.2
const LEVEL_ATTACK_SPEED_BONUS := 0.015
const DEFAULT_WEAPON_DAMAGE_PER_SKILL_POINT := 50
const DEFAULT_RIDING_DAMAGE_PER_SKILL_POINT := 100
const DEFAULT_KILL_TOTAL_EXPERIENCE := 1
const ENEMY_CORPSE_LINGER_SECONDS := 8.0
const STRENGTH_DEFENSE_BONUS_PER_POINT := 0.15
const STRENGTH_PENETRATION_BONUS_PER_POINT := 0.08
const MORALE_BOOST_DURATION_SECONDS := 86400.0
const MORALE_BOOST_ATTACK_BONUS := 0.15
const MORALE_BOOST_MOVE_SPEED_BONUS := 0.15
const LOW_HP_JUDGEMENT_RATIO := 0.3
const ENEMY_WORLD_HEALTH_COLOR := Color("#c97832")
const FAILURE_REASON_MAIN_HALL_DESTROYED := "main_hall_destroyed"
const VICTORY_REASON_FIVE_WAVES_SURVIVED := "five_waves_survived"
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
const ESCAPE_STATUS_RESUME_FAILED := "resume_failed"
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
const AVOIDANCE_DETECTION_MARGIN_FALLBACK := 2.0
const AVOIDANCE_WEIGHT_EXPONENT_FALLBACK := 2.0
const AVOIDANCE_MIN_WEIGHT_DISTANCE_FALLBACK := 1.0
const AVOIDANCE_BOUNDARY_INSET_FALLBACK := 1.25
const AVOIDANCE_SAFE_DISTANCE_FALLBACK := 8.5
const AVOIDANCE_RANGED_SAFE_MARGIN_FALLBACK := 2.5
const COMBAT_STRATEGY_MIN_X := -14.0
const COMBAT_STRATEGY_MAX_X := 14.0
const COMBAT_STRATEGY_MIN_Z := -12.5
const COMBAT_STRATEGY_MAX_Z := 18.5
const KEEP_DISTANCE_RETREAT_TRIGGER_RANGE_RATIO_FALLBACK := 1.0 / 3.0
const KEEP_DISTANCE_RETREAT_SEGMENT_RANGE_RATIO_FALLBACK := 2.0 / 3.0
const KEEP_DISTANCE_RETREAT_ARRIVAL_TOLERANCE_FALLBACK := 0.35
const COMBAT_APPROACH_RANGE_RATIO := 0.85
const RANGED_ATTACK_POSITION_RANGE_RATIO := 0.95
const RANGED_ATTACK_POSITION_SAMPLE_COUNT := 32
const RANGED_ATTACK_POSITION_SNAP_TOLERANCE := 0.65
const RANGED_ATTACK_POSITION_ARRIVAL_TOLERANCE_FALLBACK := 0.08
const FRIENDLY_STRATEGY_STALLED_RESELECT_SECONDS_FALLBACK := 2.25
const FRIENDLY_STRATEGY_RESELECT_MIN_SEPARATION_FALLBACK := 0.8
const CAVALRY_CHARGE_CLOSE_DISTANCE := 3.0
const CAVALRY_CHARGE_RESET_DISTANCE := 5.5
const CAVALRY_CHARGE_IMPACT_TOLERANCE := 0.9
const CHARGE_PHASE_WITHDRAW := "withdraw"
const CHARGE_PHASE_READY := "ready"
const CHARGE_PHASE_CHARGING := "charging"
const CHARGE_PHASE_IMPACT := "impact"
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
	"keep_distance": "拉开距离射击",
	"charge_cycle": "拉开距离冲击",
	"avoid": "避战"
}
const COMBAT_STRATEGY_OPTIONS_BY_UNIT_TYPE := {
	"melee_infantry": ["attack", "avoid"],
	"polearm_infantry": ["attack", "avoid"],
	"archer": ["attack", "keep_distance", "avoid"],
	"crossbowman": ["attack", "keep_distance", "avoid"],
	"cavalry": ["attack", "avoid"],
	"mounted_ranged": ["attack", "keep_distance", "avoid"]
}

const FALLBACK_SPAWN_POINTS := {
	"front_gate": Vector3(0.0, 0.0, 24.0),
	"front_forest": Vector3(0.0, 0.0, 29.0)
}
const PORTRAIT_STANDING_FOCUS_HEIGHT := 0.92
const PORTRAIT_STANDING_CAMERA_HEIGHT := 1.15
const PORTRAIT_MOUNTED_FOCUS_HEIGHT := 1.72
const PORTRAIT_MOUNTED_CAMERA_HEIGHT := 2.02

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
var _last_victory_result: Dictionary = {}
var _last_alarm_result: Dictionary = {}
var _last_mode_transition_result: Dictionary = {}
var _last_avoidance_result: Dictionary = {}
var _last_friendly_attack_result: Dictionary = {}
var _last_area_damage_result: Dictionary = {}
var _last_defeated_enemy_audio_position: Variant = null
var _active_battle: Dictionary = {}
var _last_battle_start_result: Dictionary = {}
var _last_battle_end_result: Dictionary = {}
var _last_wartime_dialogue_result: Dictionary = {}
var _last_low_hp_judgement_result: Dictionary = {}
var _pending_low_hp_judgement_by_request: Dictionary = {}
var _last_escape_result: Dictionary = {}
var _formal_enemy_navigation_pilot: Dictionary = {}
var _formal_enemy_navigation_pilot_node_path := NodePath()
var _formal_active_enemy_slice: Dictionary = {}
var _formal_active_enemy_slice_node_path := NodePath()
var _formal_first_wave_slices: Dictionary = {}
var _formal_first_wave_node_paths: Dictionary = {}
var _default_formal_wave_active := false
var _formal_escape_world_hold := false
var _default_formal_wave_number := 0
var _formal_crowd_logic_frame := 0
var _formal_enemy_ai_cursor := 0
var _formal_enemy_ai_updates_per_frame := 8
var _formal_contact_update_interval_frames := 6
var _formal_avoidance_update_interval_frames := 3
var _formal_enemy_game_seconds_accumulator: Dictionary = {}
var _formal_enemy_combat_seconds_accumulator: Dictionary = {}
var _formal_attack_position_policy: Dictionary = {}
var _formal_enemy_targeting_policy: Dictionary = {}
var _combat_navigation_policy: Dictionary = {}
var _enemy_attack_position_leases: Dictionary = {}
var _enemy_attack_position_by_enemy: Dictionary = {}
var _enemy_attack_wait_queues: Dictionary = {}
var _enemy_attack_unreachable_until_frame: Dictionary = {}
var _enemy_precise_arrival_recoveries: Dictionary = {}
var _enemy_guidance_stall_recoveries: Dictionary = {}
var _enemy_attack_wait_sequence := 0
var _enemy_attack_position_metrics := {
	"reservations_created": 0,
	"reservations_released": 0,
	"guidance_assignments_created": 0,
	"guidance_zone_switches": 0,
	"guidance_in_range_handoffs": 0,
	"waiters_enqueued": 0,
	"waiters_promoted": 0,
	"unreachable_candidates_rejected": 0,
	"precise_arrival_recoveries_started": 0,
	"precise_arrival_recoveries_completed": 0,
	"precise_arrival_recoveries_cancelled": 0,
	"guidance_stall_recoveries_started": 0,
	"guidance_stall_recoveries_completed": 0,
	"guidance_stall_recoveries_cancelled": 0,
	"guidance_stall_reselections": 0
}
var _enemy_retaliation_relations: Dictionary = {}
var _enemy_retaliation_sequence := 0
var _enemy_high_threat_reacquire_requests: Dictionary = {}
var _enemy_high_threat_reacquire_sequence := 0
var _friendly_enemy_reacquire_requests: Dictionary = {}
var _friendly_enemy_reacquire_sequence := 0
var _friendly_targeting_metrics := {
	"evaluations": 0,
	"initial_acquisitions": 0,
	"locked_target_holds": 0,
	"invalid_target_reacquisitions": 0,
	"different_attacker_damage_signals": 0,
	"different_attacker_damage_reacquisitions": 0,
	"different_attacker_damage_no_candidate_consumptions": 0,
	"target_switches": 0
}
var _enemy_targeting_metrics := {
	"evaluations": 0,
	"target_switches": 0,
	"higher_priority_switches": 0,
	"locked_high_target_holds": 0,
	"locked_unarmed_target_holds": 0,
	"high_threat_preemptions": 0,
	"different_attacker_damage_signals": 0,
	"different_attacker_damage_reacquisitions": 0,
	"different_attacker_damage_no_candidate_consumptions": 0,
	"fixed_target_full_skips": 0,
	"gate_full_holds": 0,
	"building_fallbacks": 0
}
var _triggered_wave_numbers: Array[int] = []
var _last_auto_wave_result: Dictionary = {}
var _last_manual_next_wave_result: Dictionary = {}
var _last_enemy_mounted_defeat_cleanup_result: Dictionary = {}
var _last_emitted_enemy_presence_count := -1
var _active_projectiles: Dictionary = {}
var _stuck_projectiles: Dictionary = {}
var _last_projectile_result: Dictionary = {}
var _projectile_sequence := 0
var _resolved_projectile_attack_facts: Dictionary = {}
var _last_melee_contact_result: Dictionary = {}
var _active_melee_swings: Dictionary = {}
var _pending_melee_damage_commits: PackedStringArray = []
var _combat_timeline_seconds := 0.0
var _combat_progression_config: Dictionary = {}
var _performance_probe: RefCounted


func _ready() -> void:
	process_priority = 20
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
		event_bus.logical_time_tick.connect(_on_logical_time_tick)
	if event_bus != null and event_bus.has_signal("time_scale_changed") and not event_bus.time_scale_changed.is_connected(_on_time_scale_changed):
		event_bus.time_scale_changed.connect(_on_time_scale_changed)
	if event_bus != null and event_bus.has_signal("gameplay_pause_changed") and not event_bus.gameplay_pause_changed.is_connected(_on_gameplay_pause_changed):
		event_bus.gameplay_pause_changed.connect(_on_gameplay_pause_changed)
	if event_bus != null and event_bus.has_signal("npc_revived") and not event_bus.npc_revived.is_connected(_on_npc_revived):
		event_bus.npc_revived.connect(_on_npc_revived)
	if event_bus != null and event_bus.has_signal("npc_unconscious") and not event_bus.npc_unconscious.is_connected(_on_npc_unconscious):
		event_bus.npc_unconscious.connect(_on_npc_unconscious)
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if (
		llm_bridge != null
		and llm_bridge.has_signal("battle_judgement_async_response_received")
		and not llm_bridge.battle_judgement_async_response_received.is_connected(_on_battle_judgement_async_response_received)
	):
		llm_bridge.battle_judgement_async_response_received.connect(_on_battle_judgement_async_response_received)


func _physics_process(delta: float) -> void:
	# Enemy ActorMotionBody nodes are owned directly by CombatSystem, unlike NPC
	# actors which poll TimeSystem themselves. Re-assert the effective pause before
	# any presentation sync so a newly issued navigation request cannot clear a
	# global pause and slide for one physics frame.
	var measured: bool = _performance_probe != null and _performance_probe.active
	var started := Time.get_ticks_usec() if measured else 0
	_sync_enemy_motion_pause(_is_gameplay_paused())
	if measured:
		_performance_probe.record("pause_sync_ms", Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
	_commit_pending_melee_contact_damage()
	_advance_combat_projectiles(delta)
	if measured:
		_performance_probe.record("projectile_contact_ms", Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
	_sync_formal_enemy_navigation_pilot_presentation(delta)
	_sync_formal_active_enemy_slice_presentation(delta)
	_sync_formal_first_wave_presentation(delta)
	if measured:
		_performance_probe.record("enemy_presentation_ms", Time.get_ticks_usec() - started)


func _process(_delta: float) -> void:
	var measured: bool = _performance_probe != null and _performance_probe.active
	var started := Time.get_ticks_usec() if measured else 0
	_sample_active_melee_swings()
	if measured:
		_performance_probe.record("melee_sample_ms", Time.get_ticks_usec() - started)
		_performance_probe.sample_frame(_active_enemies.size(), _is_gameplay_paused())


func debug_start_performance_capture(duration_seconds: float = 30.0) -> Dictionary:
	_performance_probe = load("res://scripts/debug/CombatPerformanceProbe.gd").new()
	var camera := get_viewport().get_camera_3d()
	_performance_probe.configure(duration_seconds, {
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"display": DisplayServer.get_name(),
		"viewport_size": str(get_viewport().get_visible_rect().size),
		"camera_transform": str(camera.global_transform) if camera != null else "none",
		"enemy_count_at_start": _active_enemies.size(),
		"note": "Process includes engine work; section timings can nest. No gameplay mutation.",
	})
	return {"ok": true, "duration_seconds": clampf(duration_seconds, 1.0, 60.0)}


func debug_get_performance_capture(stop: bool = false, include_samples: bool = false) -> Dictionary:
	if _performance_probe == null:
		return {"active": false, "metrics": {}, "reason": "capture_not_started"}
	if stop:
		_performance_probe.active = false
	return _performance_probe.snapshot(include_samples)


func initialize() -> void:
	_performance_probe = null
	_clear_combat_projectiles("combat_initialize")
	_exit_default_formal_combat_world("combat_initialize")
	_clear_formal_enemy_navigation_pilot("combat_initialize")
	_clear_formal_active_enemy_slice_node("combat_initialize")
	_clear_formal_first_wave_nodes("combat_initialize")
	_clear_spawned_enemy_nodes()
	_waves.clear()
	_wave_by_number.clear()
	_active_enemies.clear()
	_enemy_nodes.clear()
	_clear_enemy_attack_positions()
	_clear_enemy_targeting_runtime()
	_reset_formal_crowd_ai_budget()
	_active_rallies.clear()
	_active_avoidances.clear()
	_active_escapes.clear()
	_spawn_sequence = 0
	_last_spawn_result.clear()
	_last_ai_step_result.clear()
	_last_failure_result.clear()
	_last_victory_result.clear()
	_last_alarm_result.clear()
	_last_mode_transition_result.clear()
	_last_avoidance_result.clear()
	_last_friendly_attack_result.clear()
	_last_area_damage_result.clear()
	_last_defeated_enemy_audio_position = null
	_last_enemy_mounted_defeat_cleanup_result.clear()
	_last_emitted_enemy_presence_count = -1
	_last_projectile_result.clear()
	_projectile_sequence = 0
	_last_melee_contact_result.clear()
	_active_melee_swings.clear()
	_pending_melee_damage_commits.clear()
	_combat_timeline_seconds = 0.0
	_combat_progression_config.clear()
	_active_battle.clear()
	_last_battle_start_result.clear()
	_last_battle_end_result.clear()
	_last_wartime_dialogue_result.clear()
	_last_low_hp_judgement_result.clear()
	_pending_low_hp_judgement_by_request.clear()
	_last_escape_result.clear()
	_default_formal_wave_active = false
	_formal_escape_world_hold = false
	_default_formal_wave_number = 0
	_triggered_wave_numbers.clear()
	_last_auto_wave_result.clear()
	_last_manual_next_wave_result.clear()
	_sync_enemy_presence_time_slowdown("combat_initialize")

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("CombatSystem requires ConfigLoader autoload.")
		return

	var loaded_waves: Variant = config_loader.load_data_file(ENEMY_WAVES_FILE, [])
	if not loaded_waves is Array:
		push_error("Enemy waves must be a JSON array: %s" % ENEMY_WAVES_FILE)
		return
	_load_combat_progression_config(config_loader)

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


func get_combat_progression_config() -> Dictionary:
	return _combat_progression_config.duplicate(true)


func _load_combat_progression_config(config_loader: Node) -> void:
	var loaded: Variant = config_loader.load_data_file(COMBAT_PROGRESSION_FILE, {})
	var source: Dictionary = loaded if loaded is Dictionary else {}
	if str(source.get("schema_version", "")) != "combat_progression_v1":
		push_warning("Combat progression config missing or invalid; using production defaults.")
	_combat_progression_config = {
		"schema_version": "combat_progression_v1",
		"weapon_damage_per_skill_point": maxi(
			1,
			int(source.get(
				"weapon_damage_per_skill_point",
				DEFAULT_WEAPON_DAMAGE_PER_SKILL_POINT
			))
		),
		"riding_damage_per_skill_point": maxi(
			1,
			int(source.get(
				"riding_damage_per_skill_point",
				DEFAULT_RIDING_DAMAGE_PER_SKILL_POINT
			))
		),
		"kill_total_experience": maxi(
			0,
			int(source.get("kill_total_experience", DEFAULT_KILL_TOTAL_EXPERIENCE))
		),
		"count_actual_hp_damage_only": bool(source.get("count_actual_hp_damage_only", true)),
		"count_overkill_damage": bool(source.get("count_overkill_damage", false)),
		"defense_device_grants_npc_growth": bool(source.get("defense_device_grants_npc_growth", false)),
		"meteor_grants_npc_growth": bool(source.get("meteor_grants_npc_growth", false)),
		"horse_collision_grants_npc_growth": bool(source.get("horse_collision_grants_npc_growth", false))
	}


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


func get_wave_schedule_snapshot() -> Dictionary:
	var next_wave := _get_next_pending_wave()
	var current_absolute_seconds := _get_current_absolute_seconds()
	var pending_wave_numbers: Array[int] = []
	for wave in _waves:
		var wave_number := int(wave.get("wave_number", 0))
		if _triggered_wave_numbers.has(wave_number):
			continue
		pending_wave_numbers.append(wave_number)
	var next_info := {}
	if not next_wave.is_empty():
		var trigger_seconds := _get_wave_trigger_absolute_seconds(next_wave)
		next_info = {
			"wave_number": int(next_wave.get("wave_number", 0)),
			"wave_id": str(next_wave.get("id", "")),
			"name": str(next_wave.get("name", "")),
			"trigger_day": int(next_wave.get("trigger_day", 1)),
			"trigger_hour": int(next_wave.get("trigger_hour", 0)),
			"trigger_minute": int(next_wave.get("trigger_minute", 0)),
			"trigger_second": int(next_wave.get("trigger_second", 0)),
			"trigger_absolute_seconds": trigger_seconds,
			"seconds_until": maxf(0.0, trigger_seconds - current_absolute_seconds),
			"due": current_absolute_seconds >= trigger_seconds
		}
	return {
		"wave_count": get_wave_count(),
		"triggered_wave_numbers": _triggered_wave_numbers.duplicate(),
		"pending_wave_numbers": pending_wave_numbers,
		"next_wave": next_info,
		"all_waves_triggered": next_wave.is_empty(),
		"active_enemy_count": get_active_enemy_count(),
		"active_battle": _active_battle.duplicate(true),
		"last_victory_result": _last_victory_result.duplicate(true),
		"last_auto_wave_result": _last_auto_wave_result.duplicate(true),
		"last_manual_next_wave_result": _last_manual_next_wave_result.duplicate(true)
	}


func get_wave_hud_snapshot() -> Dictionary:
	var next_wave := _get_next_pending_wave()
	var next_info := {}
	if not next_wave.is_empty():
		var trigger_seconds := _get_wave_trigger_absolute_seconds(next_wave)
		next_info = {
			"wave_number": int(next_wave.get("wave_number", 0)),
			"seconds_until": maxf(0.0, trigger_seconds - _get_current_absolute_seconds()),
		}
	return {
		"next_wave": next_info,
		"all_waves_triggered": next_wave.is_empty(),
		"active_enemy_count": get_active_enemy_count(),
		"active_wave_number": int(_active_battle.get("wave_number", 0)),
	}


func debug_get_wave_schedule_snapshot() -> Dictionary:
	return get_wave_schedule_snapshot()


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


func get_combat_time_slowdown_snapshot() -> Dictionary:
	var snapshot := _get_time_scale_snapshot()
	return {
		"request_id": COMBAT_TIME_SLOWDOWN_REQUEST_ID,
		"slowdown_scale": COMBAT_TIME_SLOWDOWN_SCALE,
		"active_enemy_count": get_active_enemy_count(),
		"slowdown_expected": get_active_enemy_count() > 0,
		"time_scale": snapshot
	}


func get_enemy(enemy_id: String) -> Dictionary:
	return _active_enemies.get(enemy_id, {}).duplicate(true)


func get_enemy_world_position(enemy_id: String) -> Variant:
	if _enemy_nodes.has(enemy_id):
		var actor := get_node_or_null(_enemy_nodes.get(enemy_id, NodePath())) as Node3D
		if actor != null:
			return actor.global_position
	var enemy: Dictionary = _active_enemies.get(enemy_id, {})
	var position: Variant = enemy.get("position", null)
	return position if position is Vector3 else null


func get_enemy_detail_snapshot(enemy_id: String) -> Dictionary:
	var enemy: Dictionary = _active_enemies.get(enemy_id, {})
	if enemy.is_empty() or not bool(enemy.get("alive", true)):
		return {}
	return {
		"valid": true,
		"enemy_id": enemy_id,
		"name": str(enemy.get("name", enemy_id)),
		"hp": int(enemy.get("hp", 0)),
		"max_hp": int(enemy.get("max_hp", 0)),
		"unit_type": str(enemy.get("unit_type", "")),
		"unit_type_label": _get_unit_type_label(str(enemy.get("unit_type", ""))),
		"weapon_type": str(enemy.get("weapon_type", "")),
		"weapon_name": _get_enemy_weapon_name(str(enemy.get("weapon_type", ""))),
		"attack_power": int(enemy.get("attack_power", 0)),
		"defense": int(enemy.get("defense", 0)),
		"penetration": float(enemy.get("penetration", 0.0)),
		"attack_speed": float(enemy.get("attack_speed", 0.0)),
		"attack_range": float(enemy.get("attack_range", 0.0)),
		"move_speed": float(enemy.get("move_speed", 0.0)),
		"current_action": str(enemy.get("current_action", "idle")),
		"action_label": _format_enemy_action(str(enemy.get("current_action", "idle"))),
		"mounted": str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"],
		"wave_number": int(enemy.get("wave_number", 0)),
	}


func get_enemy_portrait_snapshot(enemy_id: String) -> Dictionary:
	var detail := get_enemy_detail_snapshot(enemy_id)
	if detail.is_empty() or not _enemy_nodes.has(enemy_id):
		return {}
	var actor := get_node_or_null(_enemy_nodes.get(enemy_id, NodePath())) as Node3D
	if actor == null:
		return {}
	var forward := Vector3(0.0, 0.0, -1.0)
	var art_view := actor.get_node_or_null("EnemyArtView") as Node3D
	if art_view != null and art_view.has_method("get_visible_forward"):
		forward = art_view.get_visible_forward()
	elif _formal_first_wave_slices.has(enemy_id):
		var slice: Dictionary = _formal_first_wave_slices.get(enemy_id, {})
		forward = slice.get("presentation_facing_direction", forward)
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	var mounted := bool(detail.get("mounted", false))
	return {
		"valid": true,
		"visible": actor.visible and actor.is_visible_in_tree(),
		"enemy_id": enemy_id,
		"display_name": str(detail.get("name", enemy_id)),
		"world_position": actor.global_position,
		"visual_forward": forward,
		"focus_height": PORTRAIT_MOUNTED_FOCUS_HEIGHT if mounted else PORTRAIT_STANDING_FOCUS_HEIGHT,
		"camera_height": PORTRAIT_MOUNTED_CAMERA_HEIGHT if mounted else PORTRAIT_STANDING_CAMERA_HEIGHT,
		"current_action": str(detail.get("current_action", "idle")),
		"mounted": mounted,
	}


func debug_get_enemy_overhead_snapshot(enemy_id: String) -> Dictionary:
	if not _active_enemies.has(enemy_id) or not _enemy_nodes.has(enemy_id):
		return {}
	var enemy: Dictionary = _active_enemies.get(enemy_id, {})
	var actor := get_node_or_null(_enemy_nodes.get(enemy_id, NodePath())) as Node3D
	if actor == null:
		return {}
	var label := actor.get_node_or_null("EnemyLabel") as Label3D
	var bar := actor.get_node_or_null("WorldHealthBar") as WorldHealthBar3D
	return {
		"enemy_id": enemy_id,
		"authority_name": str(enemy.get("name", enemy_id)),
		"authority_hp": int(enemy.get("hp", 0)),
		"authority_max_hp": int(enemy.get("max_hp", 0)),
		"name_text": label.text if label != null else "",
		"name_position": label.position if label != null else Vector3.ZERO,
		"health_bar": bar.get_debug_snapshot() if bar != null else {},
	}


func get_active_enemies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy_id in get_active_enemy_ids():
		result.append(get_enemy(enemy_id))
	return result


func get_npc_combat_level(npc_id: String) -> int:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return 1
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return 1
	return _get_npc_combat_level_from_profile(npc, npc_system)


func _get_npc_combat_level_from_profile(npc: Dictionary, npc_system: Node) -> int:
	var progression: Dictionary = npc.get("progression", {}) if npc.get("progression", {}) is Dictionary else {}
	var skill_experience: Dictionary = progression.get("skill_experience", {}) if progression.get("skill_experience", {}) is Dictionary else {}
	var combat_experience := 0
	var weapon_skill_names: Array[String] = []
	if npc_system.has_method("get_weapon_skill_names"):
		weapon_skill_names = npc_system.get_weapon_skill_names()
	for skill_name in weapon_skill_names:
		combat_experience = maxi(combat_experience, maxi(0, int(skill_experience.get(skill_name, 0))))
	return clampi(
		1 + int(floor(float(combat_experience) / float(COMBAT_LEVEL_EXPERIENCE_STEP))),
		1,
		MAX_COMBAT_LEVEL
	)


func get_npc_combat_stats(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system == null
		or not npc_system.has_method("get_npc")
		or not npc_system.has_method("get_npc_state")
	):
		return {}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	return _calculate_npc_combat_stats_from_profile(npc_id, npc, state, npc_system)


func _calculate_npc_combat_stats_from_profile(
	npc_id: String,
	npc: Dictionary,
	state: Dictionary,
	npc_system: Node
) -> Dictionary:
	var weapon := _get_npc_main_weapon(npc)
	var required_skill := str(weapon.get("required_skill", weapon.get("weapon_class", "")))
	var weapon_skill := _get_npc_skill_value(npc, required_skill)
	var strength := _get_npc_stat_value(npc, "strength", int(STRENGTH_ATTACK_BASELINE))
	var combat_base: Dictionary = npc.get("combat_base", {}) if npc.get("combat_base", {}) is Dictionary else {}
	var level := _get_npc_combat_level_from_profile(npc, npc_system)
	var level_steps := maxi(0, level - 1)
	var strength_growth_steps := maxi(0, strength - int(STRENGTH_ATTACK_BASELINE))

	var equipment: Dictionary = npc.get("equipment", {}) if npc.get("equipment", {}) is Dictionary else {}
	var equipment_attack_power := 0.0
	var equipment_defense := 0.0
	var equipment_penetration := 0.0
	var equipment_attack_speed_modifier := 0.0
	var combat_mount_active := bool(state.get("combat_mounted", false))
	for slot_id in ["main_weapon", "helmet", "chest", "bracers", "greaves", "mount"]:
		if slot_id == "mount" and not combat_mount_active:
			continue
		var item: Dictionary = equipment.get(slot_id, {}) if equipment.get(slot_id, {}) is Dictionary else {}
		if item.is_empty():
			continue
		equipment_attack_power += float(item.get("attack_power_modifier", 0.0))
		equipment_defense += maxf(0.0, float(item.get("defense", 0.0)))
		equipment_defense += maxf(0.0, float(item.get("armor_value", 0.0)))
		equipment_penetration += maxf(0.0, float(item.get("penetration", 0.0)))
		equipment_penetration += maxf(0.0, float(item.get("penetration_modifier", 0.0)))
		equipment_attack_speed_modifier += float(item.get("attack_speed_modifier", 0.0))

	var weapon_damage := maxf(0.0, float(weapon.get("damage", 0.0)))
	var innate_attack_power := maxf(0.0, float(combat_base.get("attack_power", 0.0)))
	var strength_multiplier := clampf(
		1.0 + (float(strength) - STRENGTH_ATTACK_BASELINE) * STRENGTH_ATTACK_BONUS_PER_POINT,
		MIN_STRENGTH_ATTACK_MULTIPLIER,
		MAX_STRENGTH_ATTACK_MULTIPLIER
	)
	var morale_attack_bonus := _get_active_morale_attack_bonus(state)
	var attack_before_multipliers := weapon_damage + innate_attack_power + equipment_attack_power
	attack_before_multipliers += float(level_steps) * LEVEL_ATTACK_POWER_BONUS
	var raw_attack_power := maxf(
		0.0,
		attack_before_multipliers * strength_multiplier * (1.0 + morale_attack_bonus)
	)
	var base_defense := maxf(0.0, float(combat_base.get("defense", 0.0)))
	var final_defense := (
		base_defense
		+ equipment_defense
		+ float(strength_growth_steps) * STRENGTH_DEFENSE_BONUS_PER_POINT
		+ float(level_steps) * LEVEL_DEFENSE_BONUS
	)
	var base_penetration := maxf(0.0, float(combat_base.get("penetration", 0.0)))
	var final_penetration := (
		base_penetration
		+ equipment_penetration
		+ float(strength_growth_steps) * STRENGTH_PENETRATION_BONUS_PER_POINT
		+ float(level_steps) * LEVEL_PENETRATION_BONUS
	)
	var weapon_skill_attack_speed_multiplier := (
		1.0
		+ clampf(float(weapon_skill) / 100.0, 0.0, 1.0)
		* WEAPON_PROFICIENCY_ATTACK_SPEED_BONUS_AT_100
	)
	var condition_attack_speed_multiplier := _calculate_npc_condition_attack_speed_multiplier(state)
	var innate_attack_speed_multiplier := maxf(
		0.2,
		float(combat_base.get("attack_speed_multiplier", 1.0))
	)
	var equipment_attack_speed_multiplier := maxf(0.2, 1.0 + equipment_attack_speed_modifier)
	var mount: Dictionary = equipment.get("mount", {}) if equipment.get("mount", {}) is Dictionary else {}
	var riding_skill := _get_npc_skill_value(npc, "骑术")
	var riding_attack_speed_multiplier := 1.0
	if combat_mount_active and not mount.is_empty():
		riding_attack_speed_multiplier += (
			clampf(float(riding_skill) / 100.0, 0.0, 1.0)
			* maxf(0.0, float(mount.get("riding_attack_speed_bonus_at_100", 0.08)))
		)
	var level_attack_speed_multiplier := 1.0 + float(level_steps) * LEVEL_ATTACK_SPEED_BONUS
	var final_attack_speed_multiplier := maxf(
		MIN_ATTACK_SPEED_MULTIPLIER,
		condition_attack_speed_multiplier
		* weapon_skill_attack_speed_multiplier
		* innate_attack_speed_multiplier
		* equipment_attack_speed_multiplier
		* riding_attack_speed_multiplier
		* level_attack_speed_multiplier
	)
	var base_interval := maxf(0.1, float(weapon.get("attack_interval", 1.8)))
	var attack_interval := maxf(MIN_NPC_ATTACK_INTERVAL, base_interval / final_attack_speed_multiplier)
	var attack_speed := 1.0 / attack_interval
	var weapon_range := maxf(0.1, float(weapon.get("range", 1.5))) if not weapon.is_empty() else 0.0
	if bool(state.get("combat_mounted", false)) and str(weapon.get("id", "")) in MELEE_WEAPON_TYPES:
		var melee_contact: Dictionary = weapon.get("melee_contact", {}) if weapon.get("melee_contact", {}) is Dictionary else {}
		weapon_range = maxf(0.1, float(melee_contact.get("mounted_range", weapon_range)))
	var max_hp := maxi(1, int(state.get("max_hp", 100)))
	var hp := clampi(int(state.get("hp", max_hp)), 0, max_hp)
	return {
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"level": level,
		"total_experience": int((npc.get("progression", {}) as Dictionary).get("total_experience", 0)) if npc.get("progression", {}) is Dictionary else 0,
		"combat_level_source": "highest_weapon_skill_experience",
		"strength": strength,
		"weapon_skill": weapon_skill,
		"base": {
			"attack_power": innate_attack_power,
			"defense": base_defense,
			"penetration": base_penetration,
			"attack_speed_multiplier": innate_attack_speed_multiplier,
			"hp": hp,
			"max_hp": max_hp
		},
		"growth": {
			"level_steps": level_steps,
			"strength_steps": strength_growth_steps,
			"attack_power": float(level_steps) * LEVEL_ATTACK_POWER_BONUS,
			"defense": (
				float(strength_growth_steps) * STRENGTH_DEFENSE_BONUS_PER_POINT
				+ float(level_steps) * LEVEL_DEFENSE_BONUS
			),
			"penetration": (
				float(strength_growth_steps) * STRENGTH_PENETRATION_BONUS_PER_POINT
				+ float(level_steps) * LEVEL_PENETRATION_BONUS
			),
			"weapon_skill_name": required_skill,
			"weapon_skill_attack_speed_multiplier": weapon_skill_attack_speed_multiplier,
			"riding_skill": riding_skill,
			"riding_attack_speed_multiplier": riding_attack_speed_multiplier,
			"level_attack_speed_multiplier": level_attack_speed_multiplier,
			"attack_speed_multiplier": (
				weapon_skill_attack_speed_multiplier
				* riding_attack_speed_multiplier
				* level_attack_speed_multiplier
			)
		},
		"equipment": {
			"weapon_id": str(weapon.get("id", "")),
			"weapon_name": str(weapon.get("name", "")),
			"weapon_damage": weapon_damage,
			"attack_power": equipment_attack_power,
			"defense": equipment_defense,
			"penetration": equipment_penetration,
			"attack_speed_modifier": equipment_attack_speed_modifier,
			"combat_mount_active": combat_mount_active
		},
		"condition": {
			"strength_multiplier": strength_multiplier,
			"morale_attack_bonus": morale_attack_bonus,
			"attack_speed_multiplier": condition_attack_speed_multiplier
		},
		"final": {
			"attack_power": raw_attack_power,
			"defense": maxf(0.0, final_defense),
			"penetration": maxf(0.0, final_penetration),
			"attack_speed": attack_speed,
			"attack_speed_multiplier": final_attack_speed_multiplier,
			"attack_interval": attack_interval,
			"range": weapon_range,
			"hp": hp,
			"max_hp": max_hp
		}
	}


func get_npc_attack_range_indicator_snapshot(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return {"ready": false, "reason": "npc_system_unavailable", "npc_id": npc_id}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {"ready": false, "reason": "npc_unavailable", "npc_id": npc_id}
	var state: Dictionary = npc.get("states", {}) if npc.get("states", {}) is Dictionary else {}
	var behavior_mode := str(state.get("behavior_mode", state.get("combat_mode", "work")))
	if not [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(behavior_mode):
		return {"ready": false, "reason": "behavior_mode_not_eligible", "npc_id": npc_id, "behavior_mode": behavior_mode}
	if int(state.get("hp", 0)) <= 0 or bool(state.get("unconscious", false)) or bool(state.get("escaped", false)):
		return {"ready": false, "reason": "npc_not_actionable", "npc_id": npc_id, "behavior_mode": behavior_mode}
	var weapon := _get_npc_main_weapon(npc)
	var weapon_id := str(weapon.get("id", weapon.get("weapon_class", "")))
	if not _is_ranged_weapon_type(weapon_id):
		return {
			"ready": false,
			"reason": "ranged_weapon_required",
			"npc_id": npc_id,
			"behavior_mode": behavior_mode,
			"weapon_id": weapon_id
		}
	var combat_stats := get_npc_combat_stats(npc_id)
	var final_stats: Dictionary = combat_stats.get("final", {}) if combat_stats.get("final", {}) is Dictionary else {}
	var effective_range := maxf(0.0, float(final_stats.get("range", 0.0)))
	var world_position: Variant = npc_system.get_npc_world_position(npc_id) if npc_system.has_method("get_npc_world_position") else null
	if effective_range <= 0.0 or not world_position is Vector3:
		return {"ready": false, "reason": "authoritative_range_or_position_unavailable", "npc_id": npc_id}
	return {
		"ready": true,
		"source_type": "npc",
		"source_id": npc_id,
		"source_name": str(npc.get("name", npc_id)),
		"behavior_mode": behavior_mode,
		"weapon_id": weapon_id,
		"effective_range": effective_range,
		"world_position": world_position,
		"range_authority": "combat_system.final.range",
		"range_semantics": "maximum_attack_initiation_ballistic_distance"
	}


func calculate_damage_resolution(raw_attack_power: float, defense: float, penetration: float = 0.0) -> Dictionary:
	var target_defense := maxf(0.0, defense)
	var attacker_penetration := maxf(0.0, penetration)
	var effective_defense := maxf(0.0, target_defense - attacker_penetration)
	var damage_multiplier := DEFENSE_CURVE_SCALE / (DEFENSE_CURVE_SCALE + effective_defense)
	var reduction := 1.0 - damage_multiplier
	var damage := maxi(
		1,
		int(round(maxf(1.0, raw_attack_power) * damage_multiplier))
	)
	return {
		"raw_attack_power": raw_attack_power,
		"target_defense": target_defense,
		"penetration": attacker_penetration,
		"effective_defense": effective_defense,
		"damage_multiplier": damage_multiplier,
		"damage_reduction": reduction,
		"damage": damage
	}


func apply_defense_device_attack(enemy_id: String, raw_attack_power: float, context: Dictionary = {}) -> Dictionary:
	if enemy_id.is_empty() or raw_attack_power <= 0.0 or not _active_enemies.has(enemy_id):
		return {}
	var target_defense := _calculate_enemy_defense(enemy_id)
	var penetration := maxf(0.0, float(context.get("penetration", 0.0)))
	var resolution := calculate_damage_resolution(raw_attack_power, target_defense, penetration)
	var damage := int(resolution.get("damage", 1))
	var damage_result := _apply_damage_to_enemy(
		enemy_id,
		damage,
		"",
		{
			"raw_attack_power": raw_attack_power,
			"target_defense": target_defense,
			"penetration": penetration,
			"effective_defense": float(resolution.get("effective_defense", target_defense)),
			"source_type": "defense_device",
			"deployment_id": str(context.get("deployment_id", "")),
			"device_id": str(context.get("device_id", "")),
			"device_name": str(context.get("device_name", "工程器械")),
			"hit_world_position": context.get("hit_world_position", null)
		}
	)
	if damage_result.is_empty():
		return {}
	damage_result["source_type"] = "defense_device"
	damage_result["deployment_id"] = str(context.get("deployment_id", ""))
	damage_result["device_id"] = str(context.get("device_id", ""))
	damage_result["device_name"] = str(context.get("device_name", "工程器械"))
	return damage_result


func release_defense_device_projectile(
	deployment: Dictionary,
	target: Dictionary,
	effect: Dictionary
) -> Dictionary:
	var deployment_id := str(deployment.get("deployment_id", ""))
	var target_id := str(target.get("id", ""))
	if deployment_id.is_empty() or target_id.is_empty() or not _active_enemies.has(target_id):
		return {}
	var projectile_config: Dictionary = effect.get("projectile", {}) if effect.get("projectile", {}) is Dictionary else {}
	var weapon_type := str(projectile_config.get("weapon_type", "crossbow"))
	if not _is_ranged_weapon_type(weapon_type):
		return {}
	var attack_sequence := maxi(0, int(deployment.get("attack_sequence", 0)))
	return _spawn_combat_projectile(
		"defense_device",
		deployment_id,
		str(deployment.get("device_name", "工程器械")),
		weapon_type,
		{
			"type": "enemy",
			"id": target_id,
			"name": str(target.get("name", "敌人")),
			"position": target.get("position", Vector3.ZERO)
		},
		{
			"raw_attack_power": maxf(1.0, float(effect.get("damage", 1.0))),
			"penetration": maxf(0.0, float(effect.get("penetration", 0.0))),
			"weapon_id": weapon_type,
			"weapon_name": "弓矢" if weapon_type == "bow" else "弩矢",
			"attack_sequence": attack_sequence,
			"deployment_id": deployment_id,
			"device_id": str(deployment.get("device_id", "")),
			"device_name": str(deployment.get("device_name", "工程器械")),
			"slot_id": str(deployment.get("slot_id", "")),
			"projectile_config": projectile_config.duplicate(true)
		},
		deployment
	)


func apply_enemy_area_damage(
	center: Vector3,
	radius: float,
	raw_attack_power: float,
	context: Dictionary = {}
) -> Dictionary:
	if radius <= 0.0 or raw_attack_power <= 0.0:
		return {}
	var penetration := maxf(0.0, float(context.get("penetration", 0.0)))
	var source_type := str(context.get("source_type", "enemy_area_damage"))
	var source_id := str(context.get("source_id", ""))
	var source_name := str(context.get("source_name", "范围效果"))
	var hit_results: Array[Dictionary] = []
	var defeated_count := 0
	var max_targets := maxi(0, int(context.get("max_targets", 0)))
	var eligible_targets: Array[Dictionary] = []
	for enemy_id in get_active_enemy_ids():
		if not _active_enemies.has(enemy_id):
			continue
		var enemy: Dictionary = _active_enemies.get(enemy_id, {})
		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		var horizontal_distance := Vector2(center.x, center.z).distance_to(
			Vector2(enemy_position.x, enemy_position.z)
		)
		if horizontal_distance > radius:
			continue
		eligible_targets.append({
			"enemy_id": enemy_id,
			"distance_to_center": horizontal_distance
		})
	eligible_targets.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := float(left.get("distance_to_center", 0.0))
		var right_distance := float(right.get("distance_to_center", 0.0))
		if not is_equal_approx(left_distance, right_distance):
			return left_distance < right_distance
		return str(left.get("enemy_id", "")) < str(right.get("enemy_id", ""))
	)
	var eligible_target_count := eligible_targets.size()
	if max_targets > 0 and eligible_targets.size() > max_targets:
		eligible_targets.resize(max_targets)
	for target in eligible_targets:
		var enemy_id := str(target.get("enemy_id", ""))
		var horizontal_distance := float(target.get("distance_to_center", 0.0))
		var target_defense := _calculate_enemy_defense(enemy_id)
		var resolution := calculate_damage_resolution(
			raw_attack_power,
			target_defense,
			penetration
		)
		var damage_result := _apply_damage_to_enemy(
			enemy_id,
			int(resolution.get("damage", 1)),
			"",
			{
				"raw_attack_power": raw_attack_power,
				"target_defense": target_defense,
				"penetration": penetration,
				"effective_defense": float(resolution.get("effective_defense", target_defense)),
				"source_type": source_type,
				"source_id": source_id,
				"source_name": source_name
			}
		)
		if damage_result.is_empty():
			continue
		damage_result["distance_to_center"] = horizontal_distance
		damage_result["source_type"] = source_type
		damage_result["source_id"] = source_id
		damage_result["source_name"] = source_name
		hit_results.append(damage_result)
		if bool(damage_result.get("defeated", false)):
			defeated_count += 1

	_last_area_damage_result = {
		"ok": true,
		"center": _vector3_to_dict(center),
		"radius": radius,
		"raw_attack_power": raw_attack_power,
		"penetration": penetration,
		"source_type": source_type,
		"source_id": source_id,
		"source_name": source_name,
		"max_targets": max_targets,
		"eligible_target_count": eligible_target_count,
		"hit_count": hit_results.size(),
		"defeated_count": defeated_count,
		"hits": hit_results
	}
	if defeated_count > 0 and _active_enemies.is_empty():
		_last_area_damage_result["mode_exit_result"] = _handle_all_enemies_cleared(
			str(context.get("mode_exit_reason", "enemies_defeated_by_area_damage"))
		)
	return _last_area_damage_result.duplicate(true)


func apply_enemy_stagger(enemy_id: String, duration_seconds: float, context: Dictionary = {}) -> Dictionary:
	if not _active_enemies.has(enemy_id) or duration_seconds <= 0.0:
		return {}
	var enemy: Dictionary = _active_enemies.get(enemy_id, {})
	var windup_before := maxf(0.0, float(enemy.get("attack_windup_remaining", 0.0)))
	var stagger_before := maxf(0.0, float(enemy.get("stagger_remaining", 0.0)))
	var stagger_after := maxf(stagger_before, duration_seconds)
	var interrupted := windup_before > 0.0
	_release_enemy_attack_position(enemy_id, "staggered")
	enemy["stagger_remaining"] = stagger_after
	_cancel_enemy_attack_timeline(enemy)
	enemy["current_action"] = "staggered"
	enemy["stagger_count"] = int(enemy.get("stagger_count", 0)) + 1
	if interrupted:
		enemy["windup_interrupt_count"] = int(enemy.get("windup_interrupt_count", 0)) + 1
	enemy["last_stagger_result"] = {
		"duration": duration_seconds,
		"stagger_before": stagger_before,
		"stagger_after": stagger_after,
		"windup_before": windup_before,
		"interrupted_windup": interrupted,
		"source_type": str(context.get("source_type", "")),
		"source_id": str(context.get("source_id", "")),
		"source_name": str(context.get("source_name", ""))
	}
	_active_enemies[enemy_id] = enemy
	_refresh_enemy_node(enemy_id)
	return {
		"ok": true,
		"enemy_id": enemy_id,
		"duration": duration_seconds,
		"stagger_before": stagger_before,
		"stagger_after": stagger_after,
		"interrupted_windup": interrupted,
		"windup_before": windup_before
	}


func spawn_wave(
	wave_number: int,
	clear_existing: bool = false,
	reason: String = "wave_spawned",
	spawn_stage_id: String = DEFAULT_FORMAL_WAVE_SPAWN_STAGE_ID
) -> Dictionary:
	if not _wave_by_number.has(wave_number):
		return _failure("unknown_wave", "敌人波次不存在。", {"wave_number": wave_number})
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and bool(game_state.get("game_over")):
		var game_over_reason := str(game_state.get("game_over_reason"))
		if game_over_reason.is_empty():
			game_over_reason = str(game_state.get("failure_reason"))
		return _failure("game_over", "游戏已经结算，不能继续生成敌人。", {
			"wave_number": wave_number,
			"game_result": str(game_state.get("game_result")),
			"game_over_reason": game_over_reason
		})

	var reflection_interrupt_result := _interrupt_pending_reflections_for_combat("enemy_wave_spawned")
	var spawn_result := _spawn_formal_dynamic_wave(wave_number, clear_existing, reason, true, spawn_stage_id)
	spawn_result["reflection_interrupt_result"] = reflection_interrupt_result
	return spawn_result


func clear_spawned_enemies() -> Dictionary:
	var removed_count := _active_enemies.size()
	# Clearing an empty staging area is not a battle-end event. In particular,
	# GM/formal wave replacement calls this before spawning; treating that no-op
	# as victory cleanup used to dismiss an in-progress prebattle rally.
	var had_combat_runtime := (
		removed_count > 0
		or not _active_battle.is_empty()
		or _default_formal_wave_active
		or not _formal_enemy_navigation_pilot.is_empty()
		or not _formal_active_enemy_slice.is_empty()
		or not _formal_first_wave_slices.is_empty()
	)
	_clear_combat_projectiles("enemies_cleared")
	_active_melee_swings.clear()
	_pending_melee_damage_commits.clear()
	var formal_pilot_was_active := not _formal_enemy_navigation_pilot.is_empty()
	var formal_active_slice_was_active := not _formal_active_enemy_slice.is_empty()
	var formal_first_wave_count := _formal_first_wave_slices.size()
	_clear_formal_enemy_navigation_pilot("enemies_cleared")
	_clear_formal_active_enemy_slice_node("enemies_cleared")
	_clear_formal_first_wave_nodes("enemies_cleared")
	_clear_spawned_enemy_nodes()
	_active_enemies.clear()
	_enemy_nodes.clear()
	_clear_enemy_attack_positions()
	_clear_enemy_targeting_runtime()
	_reset_formal_crowd_ai_budget()
	var time_slowdown_result := _sync_enemy_presence_time_slowdown("enemies_cleared")
	var mode_exit_result := (
		_handle_all_enemies_cleared("enemies_cleared")
		if had_combat_runtime
		else {
			"ok": true,
			"skipped": true,
			"reason": "no_active_combat"
		}
	)
	_last_spawn_result = {
		"ok": true,
		"removed_count": removed_count,
		"formal_enemy_pilot_removed": formal_pilot_was_active,
		"formal_active_enemy_slice_removed": formal_active_slice_was_active,
		"formal_first_wave_removed_count": formal_first_wave_count,
		"active_enemy_count": 0,
		"time_slowdown_result": time_slowdown_result,
		"mode_exit_result": mode_exit_result
	}
	return _last_spawn_result.duplicate(true)


func debug_spawn_wave(wave_number: int = 1, clear_existing: bool = false, spawn_near_front_gate: bool = false) -> Dictionary:
	var spawn_stage_id := DEBUG_GM_SPAWN_STAGE_ID if spawn_near_front_gate else DEFAULT_FORMAL_WAVE_SPAWN_STAGE_ID
	return spawn_wave(wave_number, clear_existing, "wave_spawned", spawn_stage_id)


func debug_clear_enemies() -> Dictionary:
	return clear_spawned_enemies()


func debug_run_formal_enemy_navigation_pilot() -> Dictionary:
	_clear_formal_enemy_navigation_pilot("superseded")
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var formal_root := get_node_or_null("/root/Main/WorldRoot/FormalStationLayout") as Node3D
	if (
		controller == null
		or formal_root == null
		or not controller.has_method("debug_set_preview_enabled")
		or not controller.has_method("get_production_navigation_map_rid")
		or not controller.has_method("get_enemy_route_world")
	):
		return {"ok": false, "reason": "formal_enemy_pilot_dependencies_missing"}
	var route: Dictionary = controller.get_enemy_route_world()
	var stages := route.get("stages", []) as Array
	if stages.size() < 2:
		return {"ok": false, "reason": "formal_enemy_route_missing"}
	var preview: Dictionary = controller.debug_set_preview_enabled(true)
	if not bool(preview.get("preview_enabled", false)):
		return {"ok": false, "reason": "formal_preview_unavailable"}
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_navigation_map_missing"}

	var enemy_template := _get_formal_enemy_pilot_template()
	if enemy_template.is_empty():
		return {"ok": false, "reason": "enemy_template_missing"}
	var spawn_stage := stages[0] as Dictionary
	var enemy := enemy_template.duplicate(true)
	enemy["id"] = FORMAL_ENEMY_NAVIGATION_PILOT_ID
	enemy["enemy_id"] = FORMAL_ENEMY_NAVIGATION_PILOT_ID
	enemy["wave_id"] = "formal_navigation_pilot"
	enemy["wave_number"] = 0
	enemy["position"] = spawn_stage.get("position", Vector3.ZERO)
	enemy["current_action"] = "moving_to_%s" % str((stages[1] as Dictionary).get("id", "reveal"))
	enemy["alive"] = true
	enemy["target"] = {}

	var pilot_root := formal_root.get_node_or_null("FormalEnemies") as Node3D
	if pilot_root == null:
		pilot_root = Node3D.new()
		pilot_root.name = "FormalEnemies"
		formal_root.add_child(pilot_root)
	var actor := _create_formal_enemy_pilot_actor(enemy)
	pilot_root.add_child(actor)
	actor.global_position = spawn_stage.get("position", Vector3.ZERO)
	actor.configure_avoidance_identity("enemy:%s" % str(enemy.get("id", FORMAL_ENEMY_NAVIGATION_PILOT_ID)), 0.55)
	actor.configure_profile("enemy_foot")
	if not actor.set_navigation_map(navigation_map):
		actor.queue_free()
		return {"ok": false, "reason": "formal_enemy_navigation_bind_failed"}
	actor.motion_arrived.connect(_on_formal_enemy_pilot_motion_arrived)
	actor.motion_failed.connect(_on_formal_enemy_pilot_motion_failed)
	actor.motion_cancelled.connect(_on_formal_enemy_pilot_motion_cancelled)
	_formal_enemy_navigation_pilot_node_path = actor.get_path()
	_formal_enemy_navigation_pilot = {
		"pilot_id": FORMAL_ENEMY_NAVIGATION_PILOT_ID,
		"active": true,
		"completed": false,
		"phase": "marching",
		"route_source": str(route.get("route_source", "formal_station_layout")),
		"route": route.duplicate(true),
		"target_stage_index": 1,
		"current_stage_id": str(spawn_stage.get("id", "spawn")),
		"target_stage_id": str((stages[1] as Dictionary).get("id", "reveal")),
		"completed_stage_ids": [str(spawn_stage.get("id", "spawn"))],
		"stop_stage_id": str(route.get("pilot_stop_stage_id", "front_gate")),
		"failure_reason": "",
		"enemy": enemy,
		"previous_position": actor.global_position,
		"combat_authority_committed": false
	}
	if not _request_formal_enemy_pilot_stage(actor, 1):
		var failed_snapshot := debug_get_formal_enemy_navigation_pilot_snapshot()
		_clear_formal_enemy_navigation_pilot("route_start_failed")
		failed_snapshot["ok"] = false
		failed_snapshot["reason"] = "formal_enemy_route_start_failed"
		return failed_snapshot
	return {
		"ok": true,
		"pilot_id": FORMAL_ENEMY_NAVIGATION_PILOT_ID,
		"actor_profile_id": "enemy_foot",
		"route_source": str(route.get("route_source", "formal_station_layout")),
		"spawn_stage_id": str(spawn_stage.get("id", "spawn")),
		"target_stage_id": str((stages[1] as Dictionary).get("id", "reveal")),
		"stop_stage_id": str(route.get("pilot_stop_stage_id", "front_gate")),
		"stage_count": stages.size(),
		"preview_enabled": true,
		"combat_authority_committed": false
	}


func debug_stop_formal_enemy_navigation_pilot(reason: String = "stopped") -> Dictionary:
	var snapshot := debug_get_formal_enemy_navigation_pilot_snapshot()
	_clear_formal_enemy_navigation_pilot(reason)
	return {
		"ok": true,
		"active": false,
		"reason": reason,
		"previous_phase": str(snapshot.get("phase", "inactive"))
	}


func debug_get_formal_enemy_navigation_pilot_snapshot() -> Dictionary:
	if _formal_enemy_navigation_pilot.is_empty():
		return {
			"ok": true,
			"active": false,
			"pilot_id": FORMAL_ENEMY_NAVIGATION_PILOT_ID,
			"phase": "inactive",
			"combat_authority_committed": false
		}
	var result := _formal_enemy_navigation_pilot.duplicate(true)
	result.erase("route")
	result.erase("enemy")
	result.erase("previous_position")
	var actor := get_node_or_null(_formal_enemy_navigation_pilot_node_path) as ActorMotionBody
	result["node_available"] = actor != null
	result["node_class"] = actor.get_class() if actor != null else ""
	result["world_position"] = actor.global_position if actor != null else Vector3.ZERO
	result["motion"] = actor.debug_get_motion_snapshot() if actor != null else {}
	result["active_enemy_count"] = get_active_enemy_count()
	return result


func debug_run_formal_active_enemy_main_hall_slice() -> Dictionary:
	clear_spawned_enemies()
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var formal_root := get_node_or_null("/root/Main/WorldRoot/FormalStationLayout") as Node3D
	if (
		controller == null
		or formal_root == null
		or not controller.has_method("debug_set_preview_enabled")
		or not controller.has_method("get_production_navigation_map_rid")
		or not controller.has_method("get_enemy_route_world")
	):
		return {"ok": false, "reason": "formal_active_enemy_dependencies_missing"}
	var route: Dictionary = controller.get_enemy_route_world()
	var stages := route.get("stages", []) as Array
	if stages.size() < 10:
		return {"ok": false, "reason": "formal_active_enemy_route_missing"}
	var preview: Dictionary = controller.debug_set_preview_enabled(true)
	if not bool(preview.get("preview_enabled", false)):
		return {"ok": false, "reason": "formal_preview_unavailable"}
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_navigation_map_missing"}
	if _waves.is_empty():
		return {"ok": false, "reason": "wave_missing"}
	var wave := (_waves[0] as Dictionary).duplicate(true)
	var enemy_template := _get_formal_enemy_pilot_template()
	if enemy_template.is_empty():
		return {"ok": false, "reason": "enemy_template_missing"}
	var spawn_stage := stages[0] as Dictionary
	var enemy := _make_enemy_state(FORMAL_ACTIVE_ENEMY_SLICE_ID, wave, enemy_template, 0, 0, 1)
	enemy["position"] = spawn_stage.get("position", Vector3.ZERO)
	enemy["target_preference"] = ["front_gate", "warehouse", "main_hall"]
	enemy["current_action"] = "moving_to_%s" % str((stages[1] as Dictionary).get("id", "reveal"))
	enemy["formal_navigation_authority"] = true
	enemy["formal_route_phase"] = "marching"

	var pilot_root := formal_root.get_node_or_null("FormalEnemies") as Node3D
	if pilot_root == null:
		pilot_root = Node3D.new()
		pilot_root.name = "FormalEnemies"
		formal_root.add_child(pilot_root)
	var actor := _create_formal_enemy_actor(enemy, "FormalActiveEnemyFoot01", false)
	pilot_root.add_child(actor)
	actor.global_position = spawn_stage.get("position", Vector3.ZERO)
	actor.configure_avoidance_identity("enemy:%s" % FORMAL_ACTIVE_ENEMY_SLICE_ID, 0.55)
	actor.configure_profile("enemy_foot")
	if not actor.set_navigation_map(navigation_map):
		actor.queue_free()
		return {"ok": false, "reason": "formal_active_enemy_navigation_bind_failed"}
	actor.motion_arrived.connect(_on_formal_active_enemy_motion_arrived)
	actor.motion_failed.connect(_on_formal_active_enemy_motion_failed)
	actor.motion_cancelled.connect(_on_formal_active_enemy_motion_cancelled)

	_active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID] = enemy
	_enemy_nodes[FORMAL_ACTIVE_ENEMY_SLICE_ID] = actor.get_path()
	_formal_active_enemy_slice_node_path = actor.get_path()
	_formal_active_enemy_slice = {
		"enemy_id": FORMAL_ACTIVE_ENEMY_SLICE_ID,
		"active": true,
		"completed": false,
		"phase": "marching",
		"route": route.duplicate(true),
		"target_stage_index": 1,
		"current_stage_id": str(spawn_stage.get("id", "spawn")),
		"target_stage_id": str((stages[1] as Dictionary).get("id", "reveal")),
		"completed_stage_ids": [str(spawn_stage.get("id", "spawn"))],
		"stop_stage_id": "main_hall",
		"failure_reason": "",
		"previous_position": actor.global_position,
		"combat_authority_committed": false,
		"front_gate_combat_authority_committed": false,
		"warehouse_combat_authority_committed": false,
		"main_hall_combat_authority_committed": false,
		"attack_target_building_id": "",
		"attack_unlocked": false
	}
	if not _request_formal_active_enemy_stage(actor, 1):
		var failed := debug_get_formal_active_enemy_main_hall_slice_snapshot()
		clear_spawned_enemies()
		failed["ok"] = false
		failed["reason"] = "formal_active_enemy_route_start_failed"
		return failed
	var spawned: Array[Dictionary] = [enemy.duplicate(true)]
	var time_slowdown_result := _sync_enemy_presence_time_slowdown("formal_active_enemy_spawned")
	var battle_start_result := _start_battle_for_wave(wave, spawned, "formal_active_enemy_slice")
	_last_spawn_result = {
		"ok": true,
		"wave_number": int(wave.get("wave_number", 1)),
		"wave_id": str(wave.get("id", "wave_01")),
		"spawned_count": 1,
		"active_enemy_count": 1,
		"spawned_enemy_ids": [FORMAL_ACTIVE_ENEMY_SLICE_ID],
		"spawn_point": "formal_front_forest",
		"spawn_position": _vector3_to_dict(actor.global_position),
		"reason": "formal_active_enemy_slice",
		"time_slowdown_result": time_slowdown_result,
		"battle_start_result": battle_start_result
	}
	return _last_spawn_result.duplicate(true)


func debug_stop_formal_active_enemy_main_hall_slice(reason: String = "stopped") -> Dictionary:
	var before := debug_get_formal_active_enemy_main_hall_slice_snapshot()
	var clear_result := clear_spawned_enemies()
	return {
		"ok": true,
		"reason": reason,
		"previous_phase": str(before.get("phase", "inactive")),
		"clear_result": clear_result
	}


func debug_get_formal_active_enemy_main_hall_slice_snapshot() -> Dictionary:
	if _formal_active_enemy_slice.is_empty():
		return {
			"ok": true,
			"active": false,
			"enemy_id": FORMAL_ACTIVE_ENEMY_SLICE_ID,
			"phase": "inactive",
			"active_enemy_count": get_active_enemy_count()
		}
	var result := _formal_active_enemy_slice.duplicate(true)
	result.erase("route")
	result.erase("previous_position")
	var actor := get_node_or_null(_formal_active_enemy_slice_node_path) as ActorMotionBody
	result["node_available"] = actor != null
	result["world_position"] = actor.global_position if actor != null else Vector3.ZERO
	result["motion"] = actor.debug_get_motion_snapshot() if actor != null else {}
	result["enemy"] = get_enemy(FORMAL_ACTIVE_ENEMY_SLICE_ID)
	result["active_enemy_count"] = get_active_enemy_count()
	result["active_battle"] = _active_battle.duplicate(true)
	return result


func debug_run_formal_first_wave_slice() -> Dictionary:
	return _debug_run_formal_wave_slice(1)


func debug_run_formal_second_wave_slice() -> Dictionary:
	return _debug_run_formal_wave_slice(2)


func debug_run_formal_dynamic_wave_slice(wave_number: int = 1, spawn_near_front_gate: bool = false) -> Dictionary:
	return _debug_run_formal_wave_slice(clampi(wave_number, 1, 5), spawn_near_front_gate)


func debug_get_formal_dynamic_wave_slice_snapshot() -> Dictionary:
	return debug_get_formal_first_wave_slice_snapshot()


func debug_stop_formal_dynamic_wave_slice(reason: String = "stopped") -> Dictionary:
	return debug_stop_formal_first_wave_slice(reason)


func _debug_run_formal_wave_slice(wave_number: int, spawn_near_front_gate: bool = false) -> Dictionary:
	var spawn_stage_id := DEBUG_GM_SPAWN_STAGE_ID if spawn_near_front_gate else DEFAULT_FORMAL_WAVE_SPAWN_STAGE_ID
	return _spawn_formal_dynamic_wave(wave_number, true, "formal_wave_slice", false, spawn_stage_id)


func _spawn_formal_dynamic_wave(
	wave_number: int,
	clear_existing: bool,
	reason: String,
	is_default_runtime: bool,
	spawn_stage_id: String = DEFAULT_FORMAL_WAVE_SPAWN_STAGE_ID
) -> Dictionary:
	if clear_existing:
		clear_spawned_enemies()
	elif not _active_enemies.is_empty() and (not is_default_runtime or not _default_formal_wave_active):
		return {
			"ok": false,
			"reason": "formal_wave_already_active",
			"wave_number": wave_number,
			"active_enemy_count": _active_enemies.size()
		}
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var formal_root := get_node_or_null("/root/Main/WorldRoot/FormalStationLayout") as Node3D
	if (
		controller == null
		or formal_root == null
		or not controller.has_method("debug_set_preview_enabled")
		or not controller.has_method("set_runtime_formal_world_enabled")
		or not controller.has_method("get_production_navigation_map_rid")
		or not controller.has_method("get_enemy_route_world")
		or not controller.has_method("get_formal_wave_navigation_config")
		or not controller.has_method("get_actor_motion_profile")
		or not controller.has_method("get_formal_wave_spawn_config")
		or not controller.has_method("get_gm_enemy_spawn_world_config")
	):
		return {"ok": false, "reason": "formal_wave_dependencies_missing", "wave_number": wave_number}
	var route: Dictionary = controller.get_enemy_route_world()
	var navigation_config: Dictionary = controller.get_formal_wave_navigation_config(wave_number)
	var stages := route.get("stages", []) as Array
	var use_gm_spawn_zone := spawn_stage_id == DEBUG_GM_SPAWN_STAGE_ID
	var gm_spawn_config: Dictionary = controller.get_gm_enemy_spawn_world_config() if use_gm_spawn_zone else {}
	if use_gm_spawn_zone and gm_spawn_config.is_empty():
		return {"ok": false, "reason": "gm_enemy_spawn_zone_missing", "wave_number": wave_number}
	var spawn_stage_index := _find_route_stage_index(route, spawn_stage_id)
	if spawn_stage_index < 0 and not use_gm_spawn_zone:
		spawn_stage_id = DEFAULT_FORMAL_WAVE_SPAWN_STAGE_ID
		spawn_stage_index = _find_route_stage_index(route, spawn_stage_id)
	if spawn_stage_index < 0:
		spawn_stage_index = _find_route_stage_index(route, "front_gate") if use_gm_spawn_zone else 0
	var target_sequence := navigation_config.get("target_sequence", []) as Array
	var attack_slots_world := navigation_config.get("attack_slots_world", {}) as Dictionary
	var attack_slot_sets_world := navigation_config.get("attack_slot_sets_world", {}) as Dictionary
	var movement_model := str(navigation_config.get("movement_model", "fixed_attack_slots"))
	_formal_attack_position_policy = (
		(navigation_config.get("attack_position_policy", {}) as Dictionary).duplicate(true)
		if navigation_config.get("attack_position_policy", {}) is Dictionary
		else {}
	)
	_formal_enemy_targeting_policy = (
		(navigation_config.get("targeting_policy", {}) as Dictionary).duplicate(true)
		if navigation_config.get("targeting_policy", {}) is Dictionary
		else {}
	)
	_combat_navigation_policy = (
		(navigation_config.get("combat_navigation_policy", {}) as Dictionary).duplicate(true)
		if navigation_config.get("combat_navigation_policy", {}) is Dictionary
		else {}
	)
	if stages.size() < 10 or target_sequence != ["front_gate", "warehouse", "main_hall"]:
		return {"ok": false, "reason": "formal_wave_route_missing", "wave_number": wave_number}
	var preview: Dictionary = (
		controller.set_runtime_formal_world_enabled(true)
		if is_default_runtime
		else controller.debug_set_preview_enabled(true)
	)
	if not bool(preview.get("preview_enabled", false)):
		return {"ok": false, "reason": "formal_preview_unavailable"}
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	if not navigation_map.is_valid():
		return {"ok": false, "reason": "formal_navigation_map_missing"}
	if wave_number <= 0 or wave_number > _waves.size():
		return {"ok": false, "reason": "wave_missing"}

	var wave := (_waves[wave_number - 1] as Dictionary).duplicate(true)
	var templates := wave.get("enemies", []) as Array
	var expected_count := _get_wave_enemy_count(wave)
	if expected_count <= 0:
		return {"ok": false, "reason": "enemy_template_missing"}
	var spawn_formation := _resolve_formal_wave_spawn_formation(controller, templates)
	if use_gm_spawn_zone:
		spawn_formation["columns"] = maxi(1, int(gm_spawn_config.get("columns", spawn_formation.get("columns", 3))))
		spawn_formation["source"] = "station_layout.gm_enemy_spawn"
	var spawn_columns := int(spawn_formation.get("columns", 3))
	var spawn_spacing := float(spawn_formation.get("spacing", 0.95))
	_formal_enemy_ai_updates_per_frame = maxi(1, int(spawn_formation.get("ai_updates_per_frame", 8)))
	_formal_contact_update_interval_frames = maxi(1, int(spawn_formation.get("contact_update_interval_frames", 6)))
	_formal_avoidance_update_interval_frames = maxi(1, int(spawn_formation.get("avoidance_update_interval_frames", 3)))
	_reset_formal_crowd_ai_budget(false)
	var expected_by_role: Dictionary = {}
	for raw_template in templates:
		var template := raw_template as Dictionary
		var role_id := _get_formal_attack_slot_role(str(template.get("unit_type", "")))
		expected_by_role[role_id] = int(expected_by_role.get(role_id, 0)) + maxi(0, int(template.get("count", 0)))
	if movement_model != "dynamic_combat_pressure":
		for building_id in target_sequence:
			if attack_slot_sets_world.is_empty():
				if (attack_slots_world.get(str(building_id), []) as Array).size() < expected_count:
					return {"ok": false, "reason": "formal_wave_attack_slots_missing", "building_id": building_id}
			else:
				var building_sets := attack_slot_sets_world.get(str(building_id), {}) as Dictionary
				for raw_role_id in expected_by_role.keys():
					var role_id := str(raw_role_id)
					if (building_sets.get(role_id, []) as Array).size() < int(expected_by_role[role_id]):
						return {"ok": false, "reason": "formal_wave_role_slots_missing", "building_id": building_id, "role_id": role_id}
	var actor_root := formal_root.get_node_or_null("FormalEnemies") as Node3D
	if actor_root == null:
		actor_root = Node3D.new()
		actor_root.name = "FormalEnemies"
		formal_root.add_child(actor_root)

	var spawned: Array[Dictionary] = []
	var spawn_index := 0
	var role_spawn_counts: Dictionary = {}
	for raw_template in templates:
		var enemy_template: Dictionary = raw_template if raw_template is Dictionary else {}
		var attack_slot_role := _get_formal_attack_slot_role(str(enemy_template.get("unit_type", "")))
		var count := maxi(0, int(enemy_template.get("count", 0)))
		for group_index in range(count):
			spawn_index += 1
			var role_formation_index := int(role_spawn_counts.get(attack_slot_role, 0))
			role_spawn_counts[attack_slot_role] = role_formation_index + 1
			_spawn_sequence += 1
			var enemy_id := (
				"wave_%02d_runtime_enemy_%03d" % [wave_number, _spawn_sequence]
				if is_default_runtime
				else "wave_%02d_formal_wave_enemy_%03d" % [wave_number, spawn_index]
			)
			var spawn_stage := stages[spawn_stage_index] as Dictionary
			var spawn_position := (
				_get_oriented_formation_position(
					gm_spawn_config.get("formation_front_center", Vector3.ZERO),
					gm_spawn_config.get("travel_direction", Vector3(0.0, 0.0, -1.0)),
					spawn_index - 1,
					spawn_columns,
					spawn_spacing
				)
				if use_gm_spawn_zone
				else _get_route_formation_position(
					route,
					spawn_stage_index,
					spawn_index - 1,
					spawn_stage.get("position", Vector3.ZERO),
					spawn_columns,
					spawn_spacing
				)
			)
			var enemy := _make_enemy_state(enemy_id, wave, enemy_template, group_index, spawn_index - 1, 4)
			enemy["position"] = spawn_position
			enemy["target_preference"] = _normalize_enemy_target_preferences(enemy_template.get("target_preference", DEFAULT_TARGET_PREFERENCE))
			enemy["current_action"] = "moving_to_front_gate"
			enemy["formal_navigation_authority"] = true
			enemy["formal_route_phase"] = "marching_to_front_gate"
			var actor_name := "FormalWaveEnemyFoot%02d" % spawn_index if wave_number == 1 else "FormalWave%02dEnemyFoot%02d" % [wave_number, spawn_index]
			var actor := _create_formal_enemy_actor(enemy, actor_name, false)
			actor_root.add_child(actor)
			actor.global_position = spawn_position
			actor.set_meta("default_formal_runtime", is_default_runtime)
			# Stable per-actor RVO tie-breaks prevent symmetric stand-offs without
			# restoring privileged formation rows or changing target/path authority.
			actor.configure_avoidance_identity("enemy:%s" % enemy_id, 0.55)
			var actor_profile := "enemy_mounted" if str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"] else "enemy_foot"
			actor.configure_profile(actor_profile, {
				"navigation_agent": {
					# Attack-position spacing is based on the physical capsule plus
					# one shared safety margin. Give RVO half of that margin per
					# actor so its effective diameter exactly matches the slot pitch.
					"avoidance_radius_padding": maxf(0.0, float(_formal_attack_position_policy.get("safety_margin", 0.08))) * 0.5,
					"target_desired_distance": maxf(0.05, float(_formal_attack_position_policy.get("arrival_tolerance", 0.32))),
					"neighbor_distance": 1.8,
					"max_neighbors": 12,
					"time_horizon_agents": 0.6,
					"time_horizon_obstacles": 0.8
				},
				"stuck_recovery": {"fail_after_seconds": 4.5, "maximum_repaths_per_target": 3}
			})
			if not actor.set_navigation_map(navigation_map):
				clear_spawned_enemies()
				return {"ok": false, "reason": "formal_wave_navigation_bind_failed", "enemy_id": enemy_id, "wave_number": wave_number}
			actor.motion_arrived.connect(_on_formal_first_wave_motion_arrived.bind(enemy_id))
			actor.motion_failed.connect(_on_formal_first_wave_motion_failed.bind(enemy_id))
			actor.motion_cancelled.connect(_on_formal_first_wave_motion_cancelled.bind(enemy_id))
			_active_enemies[enemy_id] = enemy
			_enemy_nodes[enemy_id] = actor.get_path()
			_formal_first_wave_node_paths[enemy_id] = actor.get_path()
			_formal_first_wave_slices[enemy_id] = {
				"enemy_id": enemy_id,
				"wave_number": wave_number,
				"unit_type": str(enemy.get("unit_type", "")),
				"attack_slot_role": attack_slot_role,
				"active": true,
				"completed": false,
				"phase": "marching_to_front_gate",
				"route": route.duplicate(true),
				"target_sequence": target_sequence.duplicate(),
				"roads_affect_navigation": bool(navigation_config.get("roads_affect_navigation", true)),
				"path_policy": str(navigation_config.get("path_policy", "")),
				"movement_model": movement_model,
				"attack_position_mode": str(navigation_config.get("attack_position_mode", "")),
				"attack_position_policy_schema": str(_formal_attack_position_policy.get("schema", "")),
				"targeting_policy_schema": str(_formal_enemy_targeting_policy.get("schema", "")),
				"blocked_policy": str(navigation_config.get("blocked_policy", "")),
				"target_policy": str(navigation_config.get("target_policy", "")),
				"attack_slots_world": _resolve_formal_wave_role_slots(attack_slots_world, attack_slot_sets_world, attack_slot_role),
				"formation_index": role_formation_index,
				"formation_column": (spawn_index - 1) % spawn_columns,
				"formation_row": (spawn_index - 1) / spawn_columns,
				"spawn_formation_columns": spawn_columns,
				"spawn_formation_spacing": spawn_spacing,
				"resolved_stage_positions": {},
				"target_stage_index": _find_route_stage_index(route, "front_gate"),
				"current_stage_id": spawn_stage_id if use_gm_spawn_zone else str(spawn_stage.get("id", "spawn")),
				"target_stage_id": "front_gate",
				"completed_stage_ids": [spawn_stage_id if use_gm_spawn_zone else str(spawn_stage.get("id", "spawn"))],
				"previous_position": spawn_position,
				"combat_authority_committed": false,
				"front_gate_combat_authority_committed": false,
				"warehouse_combat_authority_committed": false,
				"main_hall_combat_authority_committed": false,
				"attack_target_building_id": "",
				"attack_unlocked": false,
				"combat_target_id": "front_gate",
				"combat_target_type": "building",
				"motion_target_position": Vector3.ZERO,
				"pressure_repath_count": 0,
				"blocked_count": 0,
				"presentation_facing_direction": Vector3.ZERO,
				"presentation_total_turn_radians": 0.0,
				"presentation_max_turn_radians_per_frame": 0.0,
				"tactical_motion_paused": false,
				"failure_reason": ""
			}
			if not _request_formal_first_wave_stage(enemy_id, _find_route_stage_index(route, "front_gate")):
				var failed := debug_get_formal_first_wave_slice_snapshot()
				clear_spawned_enemies()
				failed["ok"] = false
				failed["reason"] = "formal_wave_route_start_failed"
				failed["enemy_id"] = enemy_id
				return failed
			spawned.append(enemy.duplicate(true))

	var formal_combat_world_result: Dictionary = {}
	if is_default_runtime:
		_default_formal_wave_active = true
		_formal_escape_world_hold = false
		_default_formal_wave_number = wave_number
		formal_combat_world_result = _enter_default_formal_combat_world()
		if not bool(formal_combat_world_result.get("ok", false)):
			clear_spawned_enemies()
			return {
				"ok": false,
				"reason": "formal_friendly_world_migration_failed",
				"wave_number": wave_number,
				"formal_combat_world_result": formal_combat_world_result
			}
	var time_slowdown_result := _sync_enemy_presence_time_slowdown("formal_wave_spawned")
	var battle_start_result := _start_battle_for_wave(wave, spawned, reason)
	_last_spawn_result = {
		"ok": true,
		"wave_number": int(wave.get("wave_number", 1)),
		"wave_id": str(wave.get("id", "wave_01")),
		"spawned_count": spawned.size(),
		"expected_count": expected_count,
		"active_enemy_count": get_active_enemy_count(),
		"spawned_enemy_ids": _extract_enemy_ids(spawned),
		"spawn_stage_id": spawn_stage_id,
		"spawn_near_front_gate": spawn_stage_id == DEBUG_GM_SPAWN_STAGE_ID,
		"spawn_in_gm_staging_zone": spawn_stage_id == DEBUG_GM_SPAWN_STAGE_ID,
		"spawn_zone": gm_spawn_config.duplicate(true) if use_gm_spawn_zone else {},
		"reason": reason,
		"world_mode": "formal_runtime" if is_default_runtime else "formal_debug_slice",
		"legacy_area3d_spawned_count": 0,
		"formal_combat_world_result": formal_combat_world_result,
		"spawn_formation": spawn_formation,
		"time_slowdown_result": time_slowdown_result,
		"battle_start_result": battle_start_result
	}
	return _last_spawn_result.duplicate(true)
func debug_stop_formal_first_wave_slice(reason: String = "stopped") -> Dictionary:
	var before := debug_get_formal_first_wave_slice_snapshot()
	var clear_result := clear_spawned_enemies()
	return {
		"ok": true,
		"reason": reason,
		"previous_active_count": int(before.get("active_enemy_count", 0)),
		"clear_result": clear_result
	}


func debug_stop_formal_second_wave_slice(reason: String = "stopped") -> Dictionary:
	return debug_stop_formal_first_wave_slice(reason)


func debug_get_formal_second_wave_slice_snapshot() -> Dictionary:
	return debug_get_formal_first_wave_slice_snapshot()


func debug_get_formal_first_wave_slice_snapshot() -> Dictionary:
	var slices: Array[Dictionary] = []
	var phase_counts: Dictionary = {}
	var unit_type_counts: Dictionary = {}
	var attack_slot_role_counts: Dictionary = {}
	var positions: Array[Vector3] = []
	var avoidance_callback_count := 0
	var navigation_failure_count := 0
	var active_wave_number := 0
	if not _formal_first_wave_slices.is_empty():
		active_wave_number = int((_formal_first_wave_slices.values()[0] as Dictionary).get("wave_number", 1))
	var expected_enemy_count := _get_wave_enemy_count(_waves[active_wave_number - 1] as Dictionary) if active_wave_number > 0 and active_wave_number <= _waves.size() else 0
	for raw_enemy_id in _formal_first_wave_slices.keys():
		var enemy_id := str(raw_enemy_id)
		var slice: Dictionary = (_formal_first_wave_slices[enemy_id] as Dictionary).duplicate(true)
		slice.erase("route")
		slice.erase("attack_slots_world")
		slice.erase("previous_position")
		var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		var motion := actor.debug_get_motion_snapshot() if actor != null else {}
		slice["node_available"] = actor != null
		slice["node_class"] = actor.get_class() if actor != null else ""
		slice["world_position"] = actor.global_position if actor != null else Vector3.ZERO
		slice["motion"] = motion
		slice["enemy"] = get_enemy(enemy_id)
		if actor != null:
			positions.append(actor.global_position)
		avoidance_callback_count += int(motion.get("avoidance_callback_count", 0))
		var phase := str(slice.get("phase", "inactive"))
		phase_counts[phase] = int(phase_counts.get(phase, 0)) + 1
		var unit_type := str(slice.get("unit_type", "unknown"))
		unit_type_counts[unit_type] = int(unit_type_counts.get(unit_type, 0)) + 1
		var role_id := str(slice.get("attack_slot_role", "default"))
		attack_slot_role_counts[role_id] = int(attack_slot_role_counts.get(role_id, 0)) + 1
		if phase == "navigation_failed":
			navigation_failure_count += 1
		slices.append(slice)
	var minimum_pair_distance := -1.0
	for first_index in range(positions.size()):
		for second_index in range(first_index + 1, positions.size()):
			var distance := positions[first_index].distance_to(positions[second_index])
			minimum_pair_distance = distance if minimum_pair_distance < 0.0 else minf(minimum_pair_distance, distance)
	return {
		"ok": true,
		"active": not _formal_first_wave_slices.is_empty(),
		"wave_number": active_wave_number,
		"expected_enemy_count": expected_enemy_count,
		"active_enemy_count": get_active_enemy_count(),
		"formal_actor_count": positions.size(),
		"phase_counts": phase_counts,
		"unit_type_counts": unit_type_counts,
		"attack_slot_role_counts": attack_slot_role_counts,
		"navigation_failure_count": navigation_failure_count,
		"avoidance_callback_count": avoidance_callback_count,
		"minimum_pair_distance": minimum_pair_distance,
		"slices": slices,
		"active_battle": _active_battle.duplicate(true)
	}


# A4-P3 / C3-P3 compatibility wrappers. The production debug slice now continues to the main hall.
func debug_run_formal_active_enemy_warehouse_slice() -> Dictionary:
	return debug_run_formal_active_enemy_main_hall_slice()


func debug_stop_formal_active_enemy_warehouse_slice(reason: String = "stopped") -> Dictionary:
	return debug_stop_formal_active_enemy_main_hall_slice(reason)


func debug_get_formal_active_enemy_warehouse_slice_snapshot() -> Dictionary:
	return debug_get_formal_active_enemy_main_hall_slice_snapshot()


# A4-P2 / C3-P2 compatibility wrappers.
func debug_run_formal_active_enemy_front_gate_slice() -> Dictionary:
	return debug_run_formal_active_enemy_main_hall_slice()


func debug_stop_formal_active_enemy_front_gate_slice(reason: String = "stopped") -> Dictionary:
	return debug_stop_formal_active_enemy_main_hall_slice(reason)


func debug_get_formal_active_enemy_front_gate_slice_snapshot() -> Dictionary:
	return debug_get_formal_active_enemy_main_hall_slice_snapshot()


func debug_trigger_next_wave(clear_existing: bool = false) -> Dictionary:
	return trigger_next_scheduled_wave("gm_panel", clear_existing, DEBUG_GM_SPAWN_STAGE_ID)


func debug_trigger_game_outcome(result: String) -> Dictionary:
	var normalized_result := result.strip_edges().to_lower()
	if not normalized_result in ["victory", "failure"]:
		return {"ok": false, "reason": "invalid_game_outcome", "result": normalized_result}
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null or not game_state.has_method("set_game_over"):
		return {"ok": false, "reason": "game_state_missing", "result": normalized_result}
	if bool(game_state.game_over):
		return {
			"ok": false,
			"reason": "game_already_over",
			"current_result": str(game_state.game_result)
		}
	if normalized_result == "victory":
		var final_wave_number := _get_final_wave_number()
		if final_wave_number <= 0:
			return {"ok": false, "reason": "no_configured_waves", "result": normalized_result}
		var battle_result := {
			"wave_number": final_wave_number,
			"remaining_enemy_count": 0,
			"defeated_enemy_count": 0,
			"debug_forced_outcome": true
		}
		_trigger_five_wave_victory(final_wave_number, battle_result, "gm_epilogue_acceptance")
		return {
			"ok": bool(game_state.game_over) and str(game_state.game_result) == "victory",
			"result": str(game_state.game_result),
			"reason": str(game_state.game_over_reason),
			"settlement_snapshot": game_state.settlement_snapshot.duplicate(true)
		}
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("apply_damage_to_building"):
		return {"ok": false, "reason": "building_system_missing", "result": normalized_result}
	var main_hall: Dictionary = building_system.get_building(MAIN_HALL_ID)
	if main_hall.is_empty():
		return {"ok": false, "reason": "main_hall_missing", "result": normalized_result}
	var remaining_hp := maxi(0, int(main_hall.get("hp", 0)))
	var damage_result: Dictionary = building_system.apply_damage_to_building(
		MAIN_HALL_ID,
		maxi(1, remaining_hp),
		"gm_epilogue_acceptance",
		ENEMY_DAMAGE_VISIBILITY
	)
	if not bool(damage_result.get("ok", false)) or not bool(damage_result.get("destroyed", false)):
		return {
			"ok": false,
			"reason": "main_hall_destruction_failed",
			"damage_result": damage_result
		}
	_trigger_main_hall_failure({"id": "gm_epilogue_acceptance"}, damage_result)
	return {
		"ok": bool(game_state.game_over) and str(game_state.game_result) == "failure",
		"result": str(game_state.game_result),
		"reason": str(game_state.game_over_reason),
		"main_hall": building_system.get_building(MAIN_HALL_ID),
		"damage_result": damage_result
	}


func trigger_next_scheduled_wave(
	source: String = "system",
	clear_existing: bool = false,
	spawn_stage_id: String = DEFAULT_FORMAL_WAVE_SPAWN_STAGE_ID
) -> Dictionary:
	var next_wave := _get_next_pending_wave()
	if next_wave.is_empty():
		_last_manual_next_wave_result = {
			"ok": false,
			"error": "no_pending_wave",
			"message": "没有尚未触发的敌人波次。",
			"source": source
		}
		return _last_manual_next_wave_result.duplicate(true)
	var wave_number := int(next_wave.get("wave_number", 0))
	var result := spawn_wave(wave_number, clear_existing, "manual_next_wave", spawn_stage_id)
	result["source"] = source
	if bool(result.get("ok", false)):
		_mark_wave_triggered(wave_number)
		result["triggered_wave_numbers"] = _triggered_wave_numbers.duplicate()
		result["next_wave_after"] = get_wave_schedule_snapshot().get("next_wave", {})
	_last_manual_next_wave_result = result.duplicate(true)
	return _last_manual_next_wave_result.duplicate(true)


func debug_get_combat_snapshot() -> Dictionary:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	var horse_lifecycle: Dictionary = (
		horse_system.get_horse_state_snapshot()
		if horse_system != null and horse_system.has_method("get_horse_state_snapshot")
		else {}
	)
	return {
		"wave_count": get_wave_count(),
		"wave_numbers": get_wave_numbers(),
		"wave_schedule": get_wave_schedule_snapshot(),
		"active_enemy_count": get_active_enemy_count(),
		"active_enemy_ids": get_active_enemy_ids(),
		"friendly_station_response": _get_friendly_station_response_snapshot(),
		"formal_enemy_navigation_pilot": debug_get_formal_enemy_navigation_pilot_snapshot(),
		"formal_active_enemy_front_gate_slice": debug_get_formal_active_enemy_front_gate_slice_snapshot(),
		"enemy_targets": _get_enemy_target_snapshot(),
		"enemy_attack_positions": debug_get_enemy_attack_position_snapshot(),
		"enemy_targeting": debug_get_enemy_targeting_snapshot(),
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
		"active_projectiles": get_active_projectile_snapshots(),
		"stuck_projectiles": get_stuck_projectile_snapshots(),
		"last_projectile_result": _last_projectile_result.duplicate(true),
		"resolved_projectile_attack_count": _resolved_projectile_attack_facts.size(),
		"active_melee_swings": get_active_melee_swing_snapshots(),
		"last_melee_contact_result": _last_melee_contact_result.duplicate(true),
		"last_area_damage_result": _last_area_damage_result.duplicate(true),
		"last_failure_result": _last_failure_result.duplicate(true),
		"last_victory_result": _last_victory_result.duplicate(true),
		"combatant_availability": _get_combatant_availability_snapshot(),
		"friendly_combat_stats": _get_all_npc_combat_stats(),
		"horse_lifecycle": horse_lifecycle,
		"defense_devices": _get_defense_device_combat_snapshot(),
		"last_mode_transition_result": _last_mode_transition_result.duplicate(true),
		"last_avoidance_result": _last_avoidance_result.duplicate(true),
		"last_battle_start_result": _last_battle_start_result.duplicate(true),
		"last_battle_end_result": _last_battle_end_result.duplicate(true),
		"last_wartime_dialogue_result": _last_wartime_dialogue_result.duplicate(true),
		"last_low_hp_judgement_result": _last_low_hp_judgement_result.duplicate(true),
		"last_escape_result": _last_escape_result.duplicate(true),
		"time_scale": _get_time_scale_snapshot()
	}


func create_formal_spatial_checkpoint() -> Dictionary:
	var enemies: Array[Dictionary] = []
	for enemy_id in get_active_enemy_ids():
		var enemy: Dictionary = _active_enemies.get(enemy_id, {})
		var actor := get_node_or_null(_enemy_nodes.get(enemy_id, NodePath())) as Node3D if _enemy_nodes.has(enemy_id) else null
		var position: Vector3 = actor.global_position if actor != null else enemy.get("position", Vector3.ZERO)
		enemies.append({
			"spawn_index": int(enemy.get("spawn_index", -1)),
			"group_index": int(enemy.get("group_index", -1)),
			"unit_type": str(enemy.get("unit_type", "")),
			"hp": int(enemy.get("hp", 0)),
			"max_hp": int(enemy.get("max_hp", 0)),
			"position": _vector3_to_dict(position),
			"current_action": str(enemy.get("current_action", "")),
			"attack_cooldown": float(enemy.get("attack_cooldown", 0.0)),
			"attack_windup_remaining": float(enemy.get("attack_windup_remaining", 0.0)),
			"attack_sequence": int(enemy.get("attack_sequence", 0)),
			"attack_sequence_lock_remaining": maxf(
				0.0,
				float(enemy.get("attack_next_sequence_time", 0.0)) - _combat_timeline_seconds
			),
			"attack_cycle_phase": str(enemy.get("attack_cycle_phase", "idle")),
			"attack_cycle_elapsed": float(enemy.get("attack_cycle_elapsed", 0.0)),
			"attack_cycle_duration": float(enemy.get("attack_cycle_duration", 0.0)),
			"attack_impact_seconds": float(enemy.get("attack_impact_seconds", 0.0)),
			"attack_cycle_target": _serialize_target(
				enemy.get("attack_cycle_target", {})
				if enemy.get("attack_cycle_target", {}) is Dictionary
				else {}
			),
			"attack_impact_committed": bool(enemy.get("attack_impact_committed", false)),
			"attack_playback_multiplier": float(enemy.get("attack_playback_multiplier", 1.0)),
			"stagger_remaining": float(enemy.get("stagger_remaining", 0.0))
		})
	enemies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("spawn_index", -1)) < int(right.get("spawn_index", -1)))
	return {
		"schema": "formal_combat_spatial_checkpoint_v1",
		"active": _default_formal_wave_active and not enemies.is_empty(),
		"wave_number": _default_formal_wave_number,
		"enemy_count": enemies.size(),
		"enemies": enemies,
		"triggered_wave_numbers": _triggered_wave_numbers.duplicate(),
		"restore_policy": "rebuild_wave_entities_then_apply_survivor_spatial_state"
	}


func restore_formal_spatial_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if str(checkpoint.get("schema", "")) != "formal_combat_spatial_checkpoint_v1":
		return {"ok": false, "reason": "combat_spatial_checkpoint_schema_mismatch"}
	var restored_triggered: Array[int] = []
	for raw_wave_number in checkpoint.get("triggered_wave_numbers", []):
		var triggered_wave := int(raw_wave_number)
		if triggered_wave > 0 and not restored_triggered.has(triggered_wave):
			restored_triggered.append(triggered_wave)
	_triggered_wave_numbers = restored_triggered
	if not bool(checkpoint.get("active", false)):
		if not _active_enemies.is_empty():
			clear_spawned_enemies()
		return {"ok": true, "active": false, "enemy_count": 0}
	var wave_number := int(checkpoint.get("wave_number", 0))
	if wave_number <= 0 or wave_number > _waves.size():
		return {"ok": false, "reason": "combat_restore_wave_missing", "wave_number": wave_number}
	# SpatialSaveSystem restores NPC data before it rebuilds combat entities.
	# The spawn transaction clears the old battle, so retain the relative
	# friendly cadence locks across that intentional intermediate cleanup.
	var friendly_cadence_checkpoint := _capture_friendly_attack_cadence_state()
	var spawn_result := _spawn_formal_dynamic_wave(wave_number, true, "save_restore", true)
	if not bool(spawn_result.get("ok", false)):
		return {"ok": false, "reason": "combat_restore_spawn_failed", "spawn_result": spawn_result}
	var friendly_cadence_result := _restore_friendly_attack_cadence_state(friendly_cadence_checkpoint)
	var saved_by_spawn_index: Dictionary = {}
	for raw_enemy in checkpoint.get("enemies", []):
		if raw_enemy is Dictionary:
			saved_by_spawn_index[int((raw_enemy as Dictionary).get("spawn_index", -1))] = (raw_enemy as Dictionary).duplicate(true)
	var restored_ids: Array[String] = []
	var removed_ids: Array[String] = []
	for enemy_id in get_active_enemy_ids():
		var enemy: Dictionary = _active_enemies.get(enemy_id, {})
		var spawn_index := int(enemy.get("spawn_index", -1))
		if not saved_by_spawn_index.has(spawn_index):
			var obsolete_actor := get_node_or_null(_enemy_nodes.get(enemy_id, NodePath())) as Node if _enemy_nodes.has(enemy_id) else null
			if obsolete_actor != null:
				obsolete_actor.queue_free()
			_enemy_nodes.erase(enemy_id)
			_active_enemies.erase(enemy_id)
			_formal_first_wave_slices.erase(enemy_id)
			_formal_first_wave_node_paths.erase(enemy_id)
			removed_ids.append(enemy_id)
			continue
		var saved: Dictionary = saved_by_spawn_index[spawn_index]
		var saved_position := _vector3_from_dict(saved.get("position", {}), enemy.get("position", Vector3.ZERO))
		var actor := get_node_or_null(_enemy_nodes.get(enemy_id, NodePath())) as Node3D if _enemy_nodes.has(enemy_id) else null
		if actor != null:
			actor.global_position = saved_position
		enemy["position"] = saved_position
		enemy["hp"] = clampi(int(saved.get("hp", enemy.get("hp", 1))), 1, int(enemy.get("max_hp", 1)))
		enemy["alive"] = true
		enemy["current_action"] = str(saved.get("current_action", enemy.get("current_action", "moving_to_front_gate")))
		enemy["attack_cooldown"] = maxf(0.0, float(saved.get("attack_cooldown", 0.0)))
		enemy["attack_windup_remaining"] = maxf(0.0, float(saved.get("attack_windup_remaining", 0.0)))
		enemy["attack_sequence"] = maxi(0, int(saved.get("attack_sequence", 0)))
		var saved_sequence_lock_remaining := maxf(0.0, float(saved.get("attack_sequence_lock_remaining", 0.0)))
		enemy["attack_next_sequence_time"] = _combat_timeline_seconds + saved_sequence_lock_remaining
		enemy["attack_last_sequence_time"] = (
			enemy["attack_next_sequence_time"] - maxf(0.1, float(enemy.get("attack_interval", 1.8)))
			if int(enemy.get("attack_sequence", 0)) > 0
			else -1.0
		)
		enemy["attack_cycle_phase"] = str(saved.get("attack_cycle_phase", "idle"))
		enemy["attack_cycle_elapsed"] = maxf(0.0, float(saved.get("attack_cycle_elapsed", 0.0)))
		enemy["attack_cycle_duration"] = maxf(0.0, float(saved.get("attack_cycle_duration", 0.0)))
		enemy["attack_impact_seconds"] = maxf(0.0, float(saved.get("attack_impact_seconds", 0.0)))
		enemy["attack_cycle_target"] = _deserialize_target(
			saved.get("attack_cycle_target", {}) if saved.get("attack_cycle_target", {}) is Dictionary else {}
		)
		enemy["attack_impact_committed"] = bool(saved.get("attack_impact_committed", false))
		enemy["attack_playback_multiplier"] = maxf(0.01, float(saved.get("attack_playback_multiplier", 1.0)))
		enemy["attack_windup_target"] = (
			enemy["attack_cycle_target"].duplicate(true)
			if str(enemy.get("attack_cycle_phase", "idle")) == "windup"
			else {}
		)
		enemy["stagger_remaining"] = maxf(0.0, float(saved.get("stagger_remaining", 0.0)))
		_active_enemies[enemy_id] = enemy
		if _formal_first_wave_slices.has(enemy_id):
			var slice: Dictionary = _formal_first_wave_slices[enemy_id]
			slice["previous_position"] = saved_position
			_formal_first_wave_slices[enemy_id] = slice
		restored_ids.append(enemy_id)
	_sync_enemy_presence_time_slowdown("save_restored")
	return {
		"ok": restored_ids.size() == int(checkpoint.get("enemy_count", restored_ids.size())),
		"active": true,
		"wave_number": wave_number,
		"enemy_count": restored_ids.size(),
		"restored_enemy_ids": restored_ids,
		"removed_unsaved_enemy_ids": removed_ids,
		"friendly_cadence_result": friendly_cadence_result
	}


func _capture_friendly_attack_cadence_state() -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("get_npc_state"):
		return {}
	var result: Dictionary = {}
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var sequence := maxi(0, int(state.get("combat_attack_sequence", 0)))
		var remaining := maxf(0.0, float(state.get("combat_attack_sequence_lock_remaining", 0.0)))
		if sequence <= 0 and remaining <= 0.0:
			continue
		result[npc_id] = {
			"sequence": sequence,
			"lock_remaining": remaining
		}
	return result


func _restore_friendly_attack_cadence_state(checkpoint: Dictionary) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("update_npc_state"):
		return {"ok": false, "reason": "npc_state_update_unavailable", "restored_npc_ids": []}
	var restored_ids: Array[String] = []
	for raw_npc_id in checkpoint.keys():
		var npc_id := str(raw_npc_id)
		var saved: Dictionary = checkpoint.get(raw_npc_id, {}) if checkpoint.get(raw_npc_id, {}) is Dictionary else {}
		var remaining := maxf(0.0, float(saved.get("lock_remaining", 0.0)))
		if not npc_system.update_npc_state(npc_id, {
			"combat_attack_cooldown": remaining,
			"combat_attack_sequence": maxi(0, int(saved.get("sequence", 0))),
			"combat_attack_last_sequence_time": -1.0,
			"combat_attack_next_sequence_time": 0.0,
			"combat_attack_sequence_lock_remaining": remaining
		}):
			continue
		restored_ids.append(npc_id)
	return {
		"ok": restored_ids.size() == checkpoint.size(),
		"restored_npc_ids": restored_ids
	}


func restore_formal_escape_sessions_from_npc_checkpoint(npc_checkpoint: Dictionary) -> Dictionary:
	_active_escapes.clear()
	var resumed: Array[String] = []
	var paused: Array[String] = []
	var failed: Array[Dictionary] = []
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return {"ok": false, "reason": "npc_system_missing"}
	for raw_actor in npc_checkpoint.get("actors", []):
		if not raw_actor is Dictionary:
			continue
		var actor: Dictionary = raw_actor
		var npc_id := str(actor.get("npc_id", ""))
		var intent: Dictionary = actor.get("escape_intent", {}) if actor.get("escape_intent", {}) is Dictionary else {}
		if not _is_escape_intent_resumable(intent) or bool(actor.get("escaped", false)):
			continue
		if bool(actor.get("unconscious", false)):
			_sync_active_escape_from_state(npc_id)
			paused.append(npc_id)
			continue
		var result := _resume_escape_after_revive(npc_id, npc_system)
		if bool(result.get("ok", false)) and bool(result.get("active_escape", false)):
			resumed.append(npc_id)
		else:
			failed.append({"npc_id": npc_id, "result": result})
	return {"ok": failed.is_empty(), "resumed_npc_ids": resumed, "paused_npc_ids": paused, "failed": failed}


func _get_all_npc_combat_stats() -> Array[Dictionary]:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return []
	var result: Array[Dictionary] = []
	for raw_npc_id in npc_system.get_npc_ids():
		var combat_stats := get_npc_combat_stats(str(raw_npc_id))
		if not combat_stats.is_empty():
			result.append(combat_stats)
	return result


func _get_defense_device_combat_snapshot() -> Dictionary:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("get_state_snapshot"):
		return {}
	return device_system.get_state_snapshot()


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


func debug_step_enemy_ai(game_seconds: float = 1.0) -> Dictionary:
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
	var encounter := _find_nearest_enemy(_get_npc_position(npc_id), _get_avoidance_trigger_range())
	if encounter.is_empty():
		return _avoidance_failure("enemy_outside_avoidance_range", "避战范围内没有敌军。", {
			"npc_id": npc_id,
			"avoidance_range": _get_avoidance_trigger_range()
		})
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
	var reflection_interrupt_result := _interrupt_pending_reflections_for_combat("combat_alarm")

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
			# A bell command must have no side effects on a combatant who already
			# owns a valid attack-target lock. Other stale rally records are not
			# authoritative once their owner is no longer a responder.
			if str(eligibility.get("reason", "")) != "target_locked":
				_active_rallies.erase(npc_id)

	var formation := _build_rally_formation(eligible)
	var rallied: Array[Dictionary] = []
	for entry in formation:
		var rally_result := _start_npc_rally(entry)
		if not rally_result.is_empty():
			rallied.append(rally_result)
	var target_locked_count := 0
	var mount_route_recovered_count := 0
	for item in ignored:
		if str(item.get("reason", "")) == "target_locked":
			target_locked_count += 1
			# Repeated bells must not replace a valid attack lock, but they may heal
			# the wartime rider-to-horse route that a world/mode handoff interrupted.
			var mount_route_result := _ensure_wartime_mount_route(
				str(item.get("npc_id", "")),
				"combat_alarm_target_locked_recovery"
			)
			item["mount_route_result"] = mount_route_result
			if bool(mount_route_result.get("recovered", false)):
				mount_route_recovered_count += 1

	_last_alarm_result = {
		"ok": true,
		"source": source,
		"heard_count": alarm_events.size(),
		"eligible_count": eligible.size(),
		"rallied_count": rallied.size(),
		"target_locked_count": target_locked_count,
		"mount_route_recovered_count": mount_route_recovered_count,
		"reflection_interrupt_result": reflection_interrupt_result,
		"ignored_count": ignored.size(),
		"rallied": rallied,
		"ignored": ignored
	}
	_emit_combat_audio_event({
		"event_type": "combat_alarm",
		"target_type": "building",
		"target_id": MAIN_HALL_ID,
		"source": source,
	})
	return _last_alarm_result.duplicate(true)


func _interrupt_pending_reflections_for_combat(reason: String) -> Dictionary:
	var reflection_system := get_node_or_null(DAILY_REFLECTION_SYSTEM_PATH)
	if reflection_system == null or not reflection_system.has_method("interrupt_pending_reflections_for_combat"):
		return {"ok": true, "reason": "reflection_system_unavailable", "interrupted_count": 0, "interrupted": []}
	return reflection_system.interrupt_pending_reflections_for_combat(reason)


func debug_trigger_combat_alarm() -> Dictionary:
	return trigger_combat_alarm("gm_panel")


func dismiss_combat_rally(source: String = "hud") -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("set_npc_behavior_mode"):
		return {"ok": false, "error": "npc_system_missing", "source": source}
	var dismissed: Array[Dictionary] = []
	var ignored: Array[Dictionary] = []
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var mode := _get_npc_behavior_mode(npc_system, npc_id)
		if mode != BEHAVIOR_MODE_RALLY:
			ignored.append({"npc_id": npc_id, "behavior_mode": mode})
			continue
		var position_before := _get_npc_position(npc_id)
		var transition: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, "rally_dismissed", {
			"interrupt": true,
			"force_idle": true,
			"request_plan_reevaluation": false,
			"resume_current_plan": true,
			"state_changes": {
				"last_action_result": "rally_dismissed",
				"movement_target": "",
				"movement_target_name": ""
			}
		})
		if bool(transition.get("ok", false)):
			_active_rallies.erase(npc_id)
		transition["world_position_before"] = position_before
		transition["world_position_after_transition"] = _get_npc_position(npc_id)
		dismissed.append(transition)
	var result := {
		"ok": true,
		"source": source,
		"dismissed_count": dismissed.size(),
		"ignored_count": ignored.size(),
		"dismissed": dismissed,
		"ignored": ignored
	}
	_last_mode_transition_result = result.duplicate(true)
	return result


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


func get_wartime_dialogue_reaction_eligibility(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return {"eligible": false, "reason": "npc_system_missing", "message": "NPC 系统不可用。"}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {"eligible": false, "reason": "unknown_npc", "message": "NPC 不存在。"}
	var mode := _get_npc_behavior_mode(npc_system, npc_id)
	if not [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(mode):
		return {
			"eligible": false,
			"reason": "not_rally_or_combat",
			"message": "只有集结或战斗中的 NPC 可以被鼓舞。",
			"behavior_mode": mode
		}
	if not bool(npc.get("recruited", false)):
		return {
			"eligible": false,
			"reason": "not_recruited",
			"message": "只有已入伍的 NPC 可以被鼓舞。",
			"behavior_mode": mode
		}
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
	var morale_state: Dictionary = npc_state.get("morale_boost", {}) if npc_state.get("morale_boost", {}) is Dictionary else {}
	if bool(morale_state.get("active", false)):
		return {
			"eligible": false,
			"reason": "morale_boost_active",
			"message": "该 NPC 的鼓舞士气增益正在生效，跨天后才能再次鼓舞。",
			"behavior_mode": mode
		}
	if not _is_npc_combat_eligible(npc_id, npc_system):
		return {
			"eligible": false,
			"reason": "no_main_weapon",
			"message": "NPC 没有主武器，不能进行战时鼓舞。",
			"behavior_mode": mode
		}
	return {
		"eligible": true,
		"reason": "eligible",
		"message": "可对该 NPC 发起一次鼓舞士气判定。",
		"behavior_mode": mode
	}


func get_combat_strategy_dialogue_eligibility(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return {"eligible": false, "reason": "npc_system_missing", "message": "NPC 系统不可用。"}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {"eligible": false, "reason": "unknown_npc", "message": "NPC 不存在。"}
	var mode := _get_npc_behavior_mode(npc_system, npc_id)
	if not [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(mode):
		return {
			"eligible": false,
			"reason": "not_rally_or_combat",
			"message": "只有集结或战斗中的 NPC 可以调整战斗策略。",
			"behavior_mode": mode
		}
	if not bool(npc.get("recruited", false)):
		return {
			"eligible": false,
			"reason": "not_recruited",
			"message": "只有已入伍的 NPC 可以调整战斗策略。",
			"behavior_mode": mode
		}
	if not _is_npc_combat_eligible(npc_id, npc_system):
		return {
			"eligible": false,
			"reason": "no_main_weapon",
			"message": "NPC 没有主武器，不能调整战斗策略。",
			"behavior_mode": mode
		}
	var options := get_npc_combat_strategy_options(npc_id)
	if options.size() < 2:
		return {
			"eligible": false,
			"reason": "no_alternative_strategy",
			"message": "当前兵种没有可切换的其他战斗策略。",
			"behavior_mode": mode
		}
	return {
		"eligible": true,
		"reason": "eligible",
		"message": "可通过对话请求该 NPC 调整战斗策略。",
		"behavior_mode": mode
	}


func get_npc_combat_strategy_dialogue_context(npc_id: String) -> Dictionary:
	var eligibility := get_combat_strategy_dialogue_eligibility(npc_id)
	if not bool(eligibility.get("eligible", false)):
		return {}
	var current := get_npc_combat_strategy(npc_id)
	var options := get_npc_combat_strategy_options(npc_id)
	return {
		"current_strategy": {
			"id": str(current.get("id", "attack")),
			"label": str(current.get("label", "主动进攻"))
		},
		"available_strategies": options.duplicate(true)
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


func debug_start_morale_boost(npc_id: String, source_event_id: String = "gm_special_result_preview") -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("get_npc_state"):
		return {"ok": false, "applied": false, "error": "npc_system_missing", "npc_id": npc_id}
	if (npc_system.get_npc(npc_id) as Dictionary).is_empty():
		return {"ok": false, "applied": false, "error": "unknown_npc", "npc_id": npc_id}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var morale: Dictionary = state.get("morale_boost", {}) if state.get("morale_boost", {}) is Dictionary else {}
	if bool(morale.get("active", false)):
		return {
			"ok": false,
			"applied": false,
			"error": "morale_boost_active",
			"message": "该 NPC 的鼓舞士气增益正在生效。",
			"npc_id": npc_id
		}
	return _start_morale_boost(npc_id, source_event_id, "gm_special_result_preview")


func debug_clear_morale_boost(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_state") or not npc_system.has_method("update_npc_state"):
		return {"ok": false, "applied": false, "error": "npc_system_missing", "npc_id": npc_id}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var morale: Dictionary = state.get("morale_boost", {}) if state.get("morale_boost", {}) is Dictionary else {}
	if not bool(morale.get("active", false)):
		return {"ok": true, "applied": false, "reason": "no_active_morale_boost", "npc_id": npc_id}
	_log_morale_boost_ended(npc_id, morale)
	npc_system.update_npc_state(npc_id, {
		"morale_boost": {},
		"last_action_result": "morale_boost_cleared_by_gm"
	})
	return {"ok": true, "applied": true, "npc_id": npc_id}


func start_npc_escape(
	npc_id: String,
	source_event_id: String = "",
	trigger: String = "manual",
	context: Dictionary = {}
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("get_npc_state"):
		return _escape_failure("npc_system_missing", "NPC 系统不可用。", npc_id)
	if (
		not npc_system.has_method("set_npc_behavior_mode_and_move_to_world_position")
		or not npc_system.has_method("can_npc_move_to_world_position")
	):
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
	var escape_exit_position := _get_escape_exit_position(npc_id, npc_system)
	var escape_route_contract := _get_escape_route_contract(npc_id, npc_system)
	var arrival_state := {
		"escape_finalize": true,
		"allow_escaping_movement": true,
		"escape_reason": "escape_completed",
		"escape_trigger": clean_trigger,
		"source_event_id": clean_source_event_id,
		"exit_target_id": ESCAPE_TARGET_ID,
		"exit_target_name": ESCAPE_TARGET_NAME
	}
	if not bool(npc_system.can_npc_move_to_world_position(npc_id, arrival_state)):
		return _escape_failure("movement_unavailable", "NPC 当前无法开始前往后门出口。", npc_id)
	var mode_result: Dictionary = npc_system.set_npc_behavior_mode_and_move_to_world_position(
		npc_id,
		BEHAVIOR_MODE_ESCAPED,
		"escape_started",
		ESCAPE_TARGET_ID,
		ESCAPE_TARGET_NAME,
		escape_exit_position,
		arrival_state,
		{
			"interrupt": true,
			"stop_movement": true,
			"request_plan_reevaluation": false,
			"state_changes": {
				"escaped": false,
				"current_action": "escaping_station",
				"last_action_result": "escape_started",
				"combat_target_enemy_id": "",
				"morale_boost": {}
			}
		}
	)
	if not bool(mode_result.get("ok", false)):
		return _escape_failure("escape_transition_failed", "无法切换到逃离状态并开始移动。", npc_id, {
			"mode_result": mode_result
		})

	var event := _log_escape_started(npc_id, clean_source_event_id, clean_trigger, context, previous_mode, escape_exit_position)
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
		"exit_position": _vector3_to_dict(escape_exit_position),
		"intervention_rounds_used": 0,
		"intervention_max_rounds": ESCAPE_INTERVENTION_MAX_ROUNDS,
		"last_intervention_decision": "",
		"last_intervention_result": "",
		"speed_multiplier": ESCAPE_SPEED_DEFAULT_MULTIPLIER,
		"money_slow_count": 0,
		"attack_speed_count": 0,
		"started_day": int(time_snapshot.get("day", 1)),
		"started_time": str(time_snapshot.get("time", "00:00:00"))
	}
	if not escape_route_contract.is_empty():
		escape_intent["route_source"] = str(escape_route_contract.get("route_source", "formal_station_layout"))
		escape_intent["route_point_count"] = (escape_route_contract.get("path_points", []) as Array).size()
		escape_intent["route_length"] = float(escape_route_contract.get("route_length", 0.0))
		escape_intent["completion_position"] = _vector3_to_dict(escape_exit_position)
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
		"target_position": _vector3_to_dict(escape_exit_position)
	}
	_active_escapes[npc_id] = result.duplicate(true)
	_last_escape_result = result.duplicate(true)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_escape_started"):
		event_bus.npc_escape_started.emit(npc_id, result.duplicate(true))
	return result


func _get_escape_exit_position(npc_id: String, npc_system: Node = null) -> Vector3:
	var resolved_npc_system := npc_system if npc_system != null else get_node_or_null(NPC_SYSTEM_PATH)
	if _npc_uses_formal_escape_world(resolved_npc_system, npc_id):
		var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		if controller != null and controller.has_method("get_escape_exit_world_position"):
			var formal_exit: Variant = controller.get_escape_exit_world_position()
			if formal_exit is Vector3:
				return formal_exit
	return ESCAPE_EXIT_POSITION


func _get_escape_route_contract(npc_id: String, npc_system: Node = null) -> Dictionary:
	var resolved_npc_system := npc_system if npc_system != null else get_node_or_null(NPC_SYSTEM_PATH)
	if not _npc_uses_formal_escape_world(resolved_npc_system, npc_id):
		return {}
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("get_formal_escape_route_world"):
		return controller.get_formal_escape_route_world()
	return {}


func _npc_uses_formal_escape_world(npc_system: Node, npc_id: String) -> bool:
	if npc_system == null:
		return false
	if (
		npc_system.has_method("is_npc_in_formal_combat_world")
		and bool(npc_system.is_npc_in_formal_combat_world(npc_id))
	):
		return true
	return (
		npc_system.has_method("is_npc_in_default_formal_world")
		and bool(npc_system.is_npc_in_default_formal_world(npc_id))
	)


func handle_npc_escape_completed(npc_id: String, escaped_state: Dictionary = {}) -> Dictionary:
	var completion := {
		"ok": true,
		"npc_id": npc_id,
		"status": ESCAPE_STATUS_ESCAPED,
		"escaped_state": escaped_state.duplicate(true)
	}
	_active_escapes.erase(npc_id)
	_last_escape_result = completion.duplicate(true)
	call_deferred("_release_formal_escape_world_if_idle", "escape_completed")
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
	var resume_exit_position := _get_escape_exit_position(npc_id, npc_system)
	intent["exit_position"] = _vector3_to_dict(resume_exit_position)
	var moved := bool(npc_system.move_npc_to_world_position(npc_id, ESCAPE_TARGET_ID, ESCAPE_TARGET_NAME, resume_exit_position, arrival_state))
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
	var intervention_result := str(response.get("escape_intervention_result", ""))
	var decision := _normalize_escape_intervention_decision(intervention_result)
	intent["intervention_rounds_used"] = rounds_used
	intent["intervention_max_rounds"] = ESCAPE_INTERVENTION_MAX_ROUNDS
	intent.erase("last_intervention_intent")
	intent["last_intervention_result"] = intervention_result
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
		"intervention_result": intervention_result,
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
			# 本轮挽留对话结束后由统一对话判别层决定是否以及修改哪些阶段，
			# 避免“留下”同时触发一条无条件计划重估。
			"request_plan_reevaluation": false,
			"state_changes": {
				"escaped": false,
				"escape_intent": intent,
				"current_action": "idle",
				"last_action_result": "escape_intervention_stayed"
			}
		}) if npc_system.has_method("set_npc_behavior_mode") else {}
		_active_escapes.erase(npc_id)
		call_deferred("_release_formal_escape_world_if_idle", "escape_intervention_stayed")
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
	intent.erase("last_intervention_intent")
	intent["last_intervention_result"] = "guard_attack_no_reply"
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
		"intervention_result": "guard_attack_no_reply",
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
	_interrupt_npc_attack_from_damage(
		str(damage_result.get("npc_id", "")),
		int(damage_result.get("damage", 0)),
		{
			"source_id": str(damage_result.get("actor_id", "")),
			"damage_event": damage_result.get("damage_event", {}).duplicate(true) if damage_result.get("damage_event", {}) is Dictionary else {}
		}
	)
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
	var apply_context := {
		"low_hp_event": low_hp_event,
		"damage_result": damage_result,
		"damage_context": context,
		"battlefield_context": battlefield_context,
		"allowed_decisions": allowed_decisions,
		"behavior_mode": mode,
		"combatant_decisions_allowed": combatant_decisions_allowed,
		"dialogue_result": dialogue_result,
		"llm_result": llm_result,
		"battle_wave_id": str(_active_battle.get("wave_id", "")),
		"battle_started_event_id": str(_active_battle.get("started_event_id", ""))
	}
	if bool(llm_result.get("ok", false)) and bool(llm_result.get("pending", false)):
		var request_id := str(llm_result.get("request_id", ""))
		if not request_id.is_empty():
			_pending_low_hp_judgement_by_request[request_id] = {
				"npc_id": npc_id,
				"context": apply_context.duplicate(true)
			}
		_last_low_hp_judgement_result = {
			"ok": true,
			"triggered": true,
			"status": "pending",
			"npc_id": npc_id,
			"request_id": request_id,
			"allowed_decisions": allowed_decisions,
			"behavior_mode": mode,
			"combatant_decisions_allowed": combatant_decisions_allowed,
			"dialogue_result": dialogue_result.duplicate(true)
		}
		return _last_low_hp_judgement_result.duplicate(true)
	var judgement: Dictionary = llm_result.get("battle_judgement", {}) if (llm_result.get("battle_judgement", {}) is Dictionary) else {}
	if not bool(llm_result.get("ok", false)) or judgement.is_empty():
		judgement = _make_low_hp_rule_fallback_judgement(npc_id, allowed_decisions, llm_result)
	var applied := _apply_low_hp_judgement_result(npc_id, judgement, apply_context)
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


func _get_npc_combat_strategy_from_profile(
	npc_id: String,
	npc: Dictionary,
	state: Dictionary
) -> Dictionary:
	var equipment: Dictionary = npc.get("equipment", {}) if npc.get("equipment", {}) is Dictionary else {}
	var main_weapon: Dictionary = equipment.get("main_weapon", {}) if equipment.get("main_weapon", {}) is Dictionary else {}
	if main_weapon.is_empty():
		return {}
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if (
		equipment_system == null
		or not equipment_system.has_method("determine_unit_type")
		or not equipment_system.has_method("get_unit_type_label")
	):
		return get_npc_combat_strategy(npc_id)
	var unit_type := str(equipment_system.determine_unit_type(equipment))
	var options := get_combat_strategy_options_for_unit_type(unit_type)
	if options.is_empty():
		return {}
	var selected_id := _extract_combat_strategy_id(state.get("combat_strategy", {}))
	if not _strategy_options_have_id(options, selected_id):
		selected_id = str(options[0].get("id", ""))
	return {
		"npc_id": npc_id,
		"id": selected_id,
		"label": _get_combat_strategy_label(selected_id),
		"unit_type": unit_type,
		"unit_type_label": str(equipment_system.get_unit_type_label(unit_type)),
		"options": options,
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
	var measured: bool = _performance_probe != null and _performance_probe.active
	var started := Time.get_ticks_usec() if measured else 0
	_advance_morale_boosts(game_delta_seconds)
	_advance_wave_schedule(game_delta_seconds)
	_advance_rally_units(game_delta_seconds)
	if _active_enemies.is_empty():
		if not _active_battle.is_empty():
			_handle_all_enemies_cleared("enemies_removed_before_combat_step")
		if measured:
			_performance_probe.record("combat_logic_ms", Time.get_ticks_usec() - started)
		return
	if _default_formal_wave_active:
		_formal_crowd_logic_frame += 1
		var contact_started := Time.get_ticks_usec() if measured else 0
		if _formal_crowd_logic_frame % _formal_contact_update_interval_frames == 0:
			_advance_behavior_mode_contacts()
		if measured:
			_performance_probe.record("behavior_contacts_ms", Time.get_ticks_usec() - contact_started)
			contact_started = Time.get_ticks_usec()
		if _formal_crowd_logic_frame % _formal_avoidance_update_interval_frames == 0:
			_advance_avoidance_units()
		if measured:
			_performance_probe.record("avoidance_decisions_ms", Time.get_ticks_usec() - contact_started)
		_advance_combat_ai(game_delta_seconds, true)
		if measured:
			_performance_probe.record("combat_logic_ms", Time.get_ticks_usec() - started)
		return
	_advance_behavior_mode_contacts()
	_advance_avoidance_units()
	_advance_combat_ai(game_delta_seconds)
	_advance_avoidance_units()
	if measured:
		_performance_probe.record("combat_logic_ms", Time.get_ticks_usec() - started)


func _on_time_scale_changed(
	_player_scale: float,
	_effective_scale: float,
	_numeric_multiplier: float,
	_reason: String
) -> void:
	if _active_enemies.is_empty():
		return
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if (
		time_system != null
		and time_system.has_method("has_time_slowdown")
		and not bool(time_system.has_time_slowdown(COMBAT_TIME_SLOWDOWN_REQUEST_ID))
	):
		_sync_enemy_presence_time_slowdown("combat_enemy_presence_guard")


func _on_gameplay_pause_changed(paused: bool) -> void:
	_sync_enemy_motion_pause(paused)


func _is_gameplay_paused() -> bool:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	return (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	)


func _sync_enemy_motion_pause(gameplay_paused: bool) -> void:
	var pilot := get_node_or_null(_formal_enemy_navigation_pilot_node_path) as ActorMotionBody
	if pilot != null:
		pilot.set_motion_paused(gameplay_paused)
	var active_slice_actor := get_node_or_null(_formal_active_enemy_slice_node_path) as ActorMotionBody
	if active_slice_actor != null:
		active_slice_actor.set_motion_paused(gameplay_paused)
	for raw_enemy_id in _formal_first_wave_node_paths.keys():
		var enemy_id := str(raw_enemy_id)
		var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		if actor == null:
			continue
		var slice: Dictionary = _formal_first_wave_slices.get(enemy_id, {}) if _formal_first_wave_slices.get(enemy_id, {}) is Dictionary else {}
		var tactical_paused := bool(slice.get("tactical_motion_paused", false))
		actor.set_motion_paused(gameplay_paused or tactical_paused)


func _set_formal_enemy_tactical_motion_paused(enemy_id: String, tactical_paused: bool) -> void:
	if _formal_first_wave_slices.has(enemy_id):
		var slice: Dictionary = _formal_first_wave_slices[enemy_id]
		slice["tactical_motion_paused"] = tactical_paused
		_formal_first_wave_slices[enemy_id] = slice
	var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	if actor != null:
		actor.set_motion_paused(_is_gameplay_paused() or tactical_paused)


func _advance_combat_ai(game_delta_seconds: float, use_formal_crowd_budget: bool = false) -> Dictionary:
	var measured: bool = _performance_probe != null and _performance_probe.active
	var started := Time.get_ticks_usec() if measured else 0
	var combat_delta_seconds := _get_combat_action_seconds(game_delta_seconds)
	# This clock advances exactly once for each authoritative combat step. Enemy
	# attack starts are anchored to it so losing contact, changing targets, or
	# briefly returning to movement cannot reset a swing and immediately start a
	# second visible swing inside the configured attack interval.
	_combat_timeline_seconds += maxf(0.0, combat_delta_seconds)
	var friendly_result := _advance_friendly_combat_ai(combat_delta_seconds, game_delta_seconds)
	if measured:
		_performance_probe.record("friendly_ai_ms", Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
	var enemy_result := (
		_advance_formal_enemy_ai_budgeted(game_delta_seconds, combat_delta_seconds)
		if use_formal_crowd_budget and _default_formal_wave_active
		else _advance_enemy_ai(game_delta_seconds, combat_delta_seconds)
	)
	enemy_result["combat_seconds"] = combat_delta_seconds
	if measured:
		_performance_probe.record("enemy_ai_ms", Time.get_ticks_usec() - started)
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
	if combat_delta_seconds <= 0.0:
		_last_friendly_attack_result = result.duplicate(true)
		return result
	if _active_enemies.is_empty():
		if not _active_battle.is_empty():
			result["mode_exit_result"] = _handle_all_enemies_cleared("enemies_removed_before_friendly_step")
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
			_active_melee_swings.erase(_melee_swing_key("friendly", npc_id))
			var noncombat_state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
			if bool(noncombat_state.get("keep_distance_retreat_active", false)):
				var settled_action := "unconscious" if mode == BEHAVIOR_MODE_UNCONSCIOUS else ("avoid_combat" if mode == BEHAVIOR_MODE_AVOID_COMBAT else "idle")
				_clear_keep_distance_retreat(npc_id, noncombat_state, "keep_distance_retreat_combat_mode_exited", true, false, settled_action)
			continue
		if not _is_npc_combat_eligible(npc_id, npc_system):
			_active_melee_swings.erase(_melee_swing_key("friendly", npc_id))
			var ineligible_state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
			if bool(ineligible_state.get("keep_distance_retreat_active", false)):
				_clear_keep_distance_retreat(npc_id, ineligible_state, "keep_distance_retreat_no_longer_eligible", true)
			(result["skipped"] as Array).append({"npc_id": npc_id, "reason": "not_combat_eligible"})
			continue
		if npc_system.has_method("can_npc_act") and not npc_system.can_npc_act(npc_id):
			_active_melee_swings.erase(_melee_swing_key("friendly", npc_id))
			(result["skipped"] as Array).append({"npc_id": npc_id, "reason": "cannot_act"})
			continue
		var npc_state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		if str(npc_state.get("combat_mount_phase", "")) in [
			"approaching_horse",
			"waiting_for_horse",
			"going_to_stable_horse",
			"beside_stable_horse",
			"going_to_returning_horse",
			"beside_returning_horse",
		]:
			if bool(npc_state.get("keep_distance_retreat_active", false)):
				_clear_keep_distance_retreat(npc_id, npc_state, "keep_distance_retreat_mount_pickup_started", false, true)
			(result["skipped"] as Array).append({"npc_id": npc_id, "reason": "waiting_for_assigned_horse"})
			continue
		var attack_result := _advance_single_npc_combat_attack(npc_id, combat_delta_seconds, npc_state)
		if attack_result.is_empty():
			continue
		result["ready_count"] = int(result.get("ready_count", 0)) + 1
		(result["attacks"] as Array).append(attack_result)

	if _active_enemies.is_empty():
		result["mode_exit_result"] = _handle_all_enemies_cleared("enemies_defeated")

	_last_friendly_attack_result = result.duplicate(true)
	return result


func _advance_single_npc_combat_attack(
	npc_id: String,
	combat_delta_seconds: float,
	initial_state: Dictionary = {}
) -> Dictionary:
	var measured: bool = _performance_probe != null and _performance_probe.active
	var section_started := Time.get_ticks_usec() if measured else 0
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("get_npc_state"):
		return {}
	var npc: Dictionary = (
		npc_system.get_npc_combat_profile_snapshot(npc_id)
		if npc_system.has_method("get_npc_combat_profile_snapshot")
		else npc_system.get_npc(npc_id)
	)
	if npc.is_empty():
		return {}
	var state: Dictionary = initial_state if not initial_state.is_empty() else npc_system.get_npc_state(npc_id)
	if measured:
		_performance_probe.record("friendly_profile_read_ms", Time.get_ticks_usec() - section_started)
		section_started = Time.get_ticks_usec()
	var attack_context := _calculate_npc_attack_context(npc_id, npc, state, npc_system)
	if measured:
		_performance_probe.record("friendly_attack_context_ms", Time.get_ticks_usec() - section_started)
		section_started = Time.get_ticks_usec()
	if attack_context.is_empty():
		return {}
	var strategy := _get_npc_combat_strategy_from_profile(npc_id, npc, state)
	if measured:
		_performance_probe.record("friendly_strategy_snapshot_ms", Time.get_ticks_usec() - section_started)
		section_started = Time.get_ticks_usec()
	if not strategy.is_empty():
		attack_context["strategy_id"] = str(strategy.get("id", ""))
		attack_context["strategy_label"] = str(strategy.get("label", ""))
		attack_context["unit_type"] = str(strategy.get("unit_type", ""))
		attack_context["unit_type_label"] = str(strategy.get("unit_type_label", ""))

	# T0232: a close threat owns the whole keep-distance decision before target
	# acquisition, attack-position movement, windup, or projectile release. A
	# committed retreat leg is immutable until arrival, even when its threats
	# move or a more attractive target appears in the meantime.
	var existing_attack_phase := str(state.get("combat_attack_phase", "idle"))
	var existing_cycle_target_enemy_id := str(state.get("combat_attack_target_enemy_id", ""))
	var completing_locked_melee_action := (
		existing_attack_phase in ["windup", "recovery"]
		and str(attack_context.get("weapon_id", "")) in MELEE_WEAPON_TYPES
		and not existing_cycle_target_enemy_id.is_empty()
		and not (
			str(attack_context.get("strategy_id", "")) == STRATEGY_CHARGE_CYCLE
			and str(state.get("combat_charge_phase", "")) == CHARGE_PHASE_IMPACT
		)
	)
	var completing_locked_projectile_action := (
		existing_attack_phase in ["windup", "recovery"]
		and _is_ranged_weapon_type(str(attack_context.get("weapon_id", "")))
		and not existing_cycle_target_enemy_id.is_empty()
	)
	var keep_distance_retreat := (
		{}
		if completing_locked_melee_action
		else _advance_keep_distance_retreat_priority(npc_id, state, attack_context)
	)
	if measured:
		_performance_probe.record("friendly_keep_distance_ms", Time.get_ticks_usec() - section_started)
		section_started = Time.get_ticks_usec()
	state = npc_system.get_npc_state(npc_id)
	if not keep_distance_retreat.is_empty():
		_active_melee_swings.erase(_melee_swing_key("friendly", npc_id))
		_pending_melee_damage_commits.erase(_melee_swing_key("friendly", npc_id))
		var retreat_cooldown := maxf(0.0, float(state.get("combat_attack_cooldown", 0.0)))
		if npc_system.has_method("update_npc_state"):
			npc_system.update_npc_state(npc_id, {
				"combat_target_enemy_id": "",
				"combat_target_selection_reason": "keep_distance_close_threat_retreat",
				"combat_target_scope": "",
				"combat_attack_phase": "idle",
				"combat_attack_elapsed_seconds": 0.0,
				"combat_attack_cycle_seconds": 0.0,
				"combat_attack_impact_seconds": 0.0,
				"combat_attack_target_enemy_id": "",
				"combat_attack_impact_committed": false,
				"combat_last_attack_result": {},
				"last_action_result": str(keep_distance_retreat.get("reason", "keep_distance_retreat"))
			})
		return {
			"npc_id": npc_id,
			"npc_name": str(npc.get("name", npc_id)),
			"attack_count": 0,
			"target": {},
			"attack_context": attack_context,
			"combat_seconds": combat_delta_seconds,
			"cooldown": retreat_cooldown,
			"strategy_movement": keep_distance_retreat,
			"reason": str(keep_distance_retreat.get("reason", "keep_distance_retreat"))
		}

	# One selector owns both strategic movement and attack contact. The existing
	# state ID is the durable presence lock; only invalidation or a one-shot
	# different-attacker damage request may replace it.
	var strategic_target := _select_friendly_combat_target_lock(npc_id, state)
	if measured:
		_performance_probe.record("friendly_target_lock_ms", Time.get_ticks_usec() - section_started)
		section_started = Time.get_ticks_usec()
	var strategic_target_enemy_id := str(strategic_target.get("id", ""))
	var target_state_changes := {
		"combat_target_enemy_id": strategic_target_enemy_id,
		"combat_target_selection_reason": str(strategic_target.get("target_selection_reason", "no_enemy_in_scope")),
		"combat_target_scope": str(
			strategic_target.get(
				"target_scope",
				_get_friendly_target_scope(npc_id).get("scope", "")
			)
		)
	}
	if (
		str(state.get("combat_target_enemy_id", "")) != strategic_target_enemy_id
		or str(state.get("combat_target_selection_reason", "")) != str(target_state_changes.get("combat_target_selection_reason", ""))
		or str(state.get("combat_target_scope", "")) != str(target_state_changes.get("combat_target_scope", ""))
	):
		if npc_system.has_method("update_npc_state"):
			npc_system.update_npc_state(npc_id, target_state_changes)
	if measured:
		_performance_probe.record("friendly_target_state_ms", Time.get_ticks_usec() - section_started)
		section_started = Time.get_ticks_usec()

	var remaining := maxf(0.0, combat_delta_seconds)
	var timeline_cursor := maxf(0.0, _combat_timeline_seconds - remaining)
	var cooldown := maxf(0.0, float(state.get("combat_attack_cooldown", 0.0)))
	var phase := str(state.get("combat_attack_phase", "idle"))
	if not phase in ["windup", "recovery"]:
		phase = "idle"
	var elapsed := maxf(0.0, float(state.get("combat_attack_elapsed_seconds", 0.0)))
	var cycle_seconds := maxf(0.0, float(state.get("combat_attack_cycle_seconds", 0.0)))
	var impact_seconds := maxf(0.0, float(state.get("combat_attack_impact_seconds", 0.0)))
	var playback_multiplier := maxf(0.01, float(state.get("combat_attack_playback_multiplier", 1.0)))
	var sequence := maxi(0, int(state.get("combat_attack_sequence", 0)))
	var last_sequence_time := float(state.get("combat_attack_last_sequence_time", -1.0))
	var next_sequence_time := maxf(0.0, float(state.get("combat_attack_next_sequence_time", 0.0)))
	var restored_sequence_lock_remaining := maxf(
		0.0,
		float(state.get("combat_attack_sequence_lock_remaining", 0.0))
	)
	# Spatial checkpoints store a relative duration, never a process-local
	# absolute clock. Rebuild it against this combat step's starting cursor.
	if sequence > 0 and next_sequence_time <= 0.0:
		if restored_sequence_lock_remaining > 0.0:
			next_sequence_time = timeline_cursor + restored_sequence_lock_remaining
		elif cooldown > 0.0:
			# Compatibility for states authored before the monotonic friendly lock.
			next_sequence_time = timeline_cursor + cooldown
	var cycle_target_enemy_id := str(state.get("combat_attack_target_enemy_id", ""))
	var impact_committed := bool(state.get("combat_attack_impact_committed", phase == "recovery"))
	var attacks: Array[Dictionary] = []
	var engagement_range_margin := maxf(0.0, float(_formal_attack_position_policy.get("engagement_range_exit_margin", 0.18)))
	var target := _select_npc_attack_target(
		npc_id,
		attack_context,
		strategic_target_enemy_id,
		engagement_range_margin if phase != "idle" and cycle_target_enemy_id == strategic_target_enemy_id else 0.0
	)
	if measured:
		_performance_probe.record("friendly_attack_target_ms", Time.get_ticks_usec() - section_started)
		section_started = Time.get_ticks_usec()
	# Once a melee action or ranged release animation starts, range and line of
	# fire are no longer re-evaluated. A still-valid actor target owns the action
	# through authored impact/release; only an actual interruption may cancel it.
	var completing_locked_actor_action := completing_locked_melee_action or completing_locked_projectile_action
	if completing_locked_actor_action:
		target = _make_enemy_attack_target(cycle_target_enemy_id, _get_npc_position(npc_id))
	var attack_path_blocked := (
		not completing_locked_actor_action
		and
		not target.is_empty()
		and not _is_friendly_attack_path_clear(
			npc_id,
			target,
			str(attack_context.get("weapon_id", ""))
		)
	)
	if measured:
		_performance_probe.record("friendly_attack_path_ms", Time.get_ticks_usec() - section_started)
		section_started = Time.get_ticks_usec()
	# Once an authored attack has started, movement strategy may not replace it
	# before impact/recovery has finished. This is especially important for the
	# cavalry charge strategy, whose cooldown now represents the active cycle.
	var strategy_movement := (
		_advance_npc_combat_strategy_movement(npc_id, state, attack_context, target, strategic_target)
		if phase == "idle"
		else {}
	)
	if measured:
		_performance_probe.record("friendly_strategy_movement_ms", Time.get_ticks_usec() - section_started)
		section_started = Time.get_ticks_usec()
	if not strategy_movement.is_empty():
		_active_melee_swings.erase(_melee_swing_key("friendly", npc_id))
		cooldown = maxf(0.0, next_sequence_time - _combat_timeline_seconds)
		phase = "idle"
		elapsed = 0.0
		cycle_seconds = 0.0
		impact_seconds = 0.0
		cycle_target_enemy_id = ""
		impact_committed = false
		if npc_system.has_method("update_npc_state"):
			npc_system.update_npc_state(npc_id, {
				"combat_attack_cooldown": cooldown,
				"combat_attack_phase": phase,
				"combat_attack_elapsed_seconds": elapsed,
				"combat_attack_cycle_seconds": cycle_seconds,
				"combat_attack_impact_seconds": impact_seconds,
				"combat_attack_target_enemy_id": cycle_target_enemy_id,
				"combat_attack_impact_committed": impact_committed,
				"combat_attack_last_sequence_time": last_sequence_time,
				"combat_attack_next_sequence_time": next_sequence_time,
				"combat_attack_sequence_lock_remaining": cooldown,
				"combat_last_attack_result": {},
				"last_action_result": str(strategy_movement.get("reason", "combat_strategy_movement"))
			})
		if measured:
			_performance_probe.record("friendly_state_commit_ms", Time.get_ticks_usec() - section_started)
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
	if attack_path_blocked:
		# Range alone is not an attack opportunity. Keep the strategic lock, but
		# never release a projectile or melee sweep into formal world geometry.
		target = {}

	if target.is_empty():
		_active_melee_swings.erase(_melee_swing_key("friendly", npc_id))
		cooldown = maxf(0.0, next_sequence_time - _combat_timeline_seconds)
		phase = "idle"
		elapsed = 0.0
		cycle_seconds = 0.0
		impact_seconds = 0.0
		cycle_target_enemy_id = ""
		impact_committed = false
		if npc_system.has_method("update_npc_state"):
			npc_system.update_npc_state(npc_id, {
				"combat_attack_cooldown": cooldown,
				"combat_attack_phase": phase,
				"combat_attack_elapsed_seconds": elapsed,
				"combat_attack_cycle_seconds": cycle_seconds,
				"combat_attack_impact_seconds": impact_seconds,
				"combat_attack_target_enemy_id": cycle_target_enemy_id,
				"combat_attack_impact_committed": impact_committed,
				"combat_attack_last_sequence_time": last_sequence_time,
				"combat_attack_next_sequence_time": next_sequence_time,
				"combat_attack_sequence_lock_remaining": cooldown,
				"combat_last_attack_result": {},
				"last_action_result": "combat_attack_path_blocked" if attack_path_blocked else "combat_no_enemy_in_range",
				"current_action": "combat_ready"
			})
		if measured:
			_performance_probe.record("friendly_state_commit_ms", Time.get_ticks_usec() - section_started)
		return {
			"npc_id": npc_id,
			"attack_count": 0,
			"target": {},
			"attack_context": attack_context,
			"combat_seconds": combat_delta_seconds,
			"cooldown": cooldown,
			"reason": "attack_path_blocked" if attack_path_blocked else "no_enemy_in_range"
		}

	while remaining > 0.000001 and attacks.size() < MAX_FRIENDLY_ATTACKS_PER_AI_STEP and not _active_enemies.is_empty():
		if phase == "idle":
			if sequence > 0 and timeline_cursor + 0.000001 < next_sequence_time:
				var cadence_wait := minf(remaining, next_sequence_time - timeline_cursor)
				remaining -= cadence_wait
				timeline_cursor += cadence_wait
				if remaining <= 0.000001 or timeline_cursor + 0.000001 < next_sequence_time:
					break
			target = _select_npc_attack_target(npc_id, attack_context)
			if target.is_empty():
				break
			var timing := COMBAT_ANIMATION_TIMING.get_timing(
				str(attack_context.get("weapon_id", "sword_shield")),
				float(attack_context.get("attack_interval", 1.5)),
				bool(attack_context.get("mounted", false))
			)
			cycle_seconds = float(timing.get("cycle_seconds", 1.5))
			impact_seconds = float(timing.get("impact_seconds", cycle_seconds * 0.5))
			playback_multiplier = float(timing.get("playback_multiplier", 1.0))
			attack_context["animation_timing"] = timing.duplicate(true)
			phase = "windup"
			elapsed = 0.0
			cooldown = cycle_seconds
			cycle_target_enemy_id = str(target.get("id", ""))
			impact_committed = false
			sequence += 1
			last_sequence_time = timeline_cursor
			next_sequence_time = timeline_cursor + cycle_seconds
			_face_npc_toward_target(npc_system, npc_id, target)
			if str(attack_context.get("weapon_id", "")) in MELEE_WEAPON_TYPES:
				var begins_as_charge_impact := (
					str(attack_context.get("strategy_id", "")) == STRATEGY_CHARGE_CYCLE
					and str(state.get("combat_charge_phase", "")) == CHARGE_PHASE_IMPACT
				)
				_begin_melee_swing(
					"friendly",
					npc_id,
					str(attack_context.get("weapon_id", "")),
					target,
					sequence,
					attack_context,
					begins_as_charge_impact
				)
		elif str(target.get("id", "")) != cycle_target_enemy_id:
			_active_melee_swings.erase(_melee_swing_key("friendly", npc_id))
			phase = "idle"
			elapsed = 0.0
			cycle_seconds = 0.0
			impact_seconds = 0.0
			cycle_target_enemy_id = ""
			impact_committed = false
			continue

		_face_npc_toward_target(npc_system, npc_id, target)
		var boundary := impact_seconds if phase == "windup" else cycle_seconds
		var until_boundary := maxf(0.0, boundary - elapsed)
		var phase_step := minf(remaining, until_boundary)
		elapsed += phase_step
		remaining -= phase_step
		timeline_cursor += phase_step
		cooldown = maxf(0.0, next_sequence_time - timeline_cursor)
		if elapsed + 0.000001 < boundary:
			break

		if phase == "windup":
			var normal_locked_melee_impact := (
				str(attack_context.get("weapon_id", "")) in MELEE_WEAPON_TYPES
				and not (
					str(attack_context.get("strategy_id", "")) == STRATEGY_CHARGE_CYCLE
					and str(state.get("combat_charge_phase", "")) == CHARGE_PHASE_IMPACT
				)
			)
			var locked_projectile_release := _is_ranged_weapon_type(str(attack_context.get("weapon_id", "")))
			var impact_target := (
				_make_enemy_attack_target(cycle_target_enemy_id, _get_npc_position(npc_id))
				if normal_locked_melee_impact or locked_projectile_release
				else _select_npc_attack_target(
					npc_id,
					attack_context,
					cycle_target_enemy_id,
					engagement_range_margin
				)
			)
			if impact_target.is_empty() or str(impact_target.get("id", "")) != cycle_target_enemy_id:
				_active_melee_swings.erase(_melee_swing_key("friendly", npc_id))
				phase = "idle"
				elapsed = 0.0
				cycle_target_enemy_id = ""
				impact_committed = false
				continue
			target = impact_target
			_face_npc_toward_target(npc_system, npc_id, target)
			var is_charge_impact := (
				str(attack_context.get("strategy_id", "")) == STRATEGY_CHARGE_CYCLE
				and str(state.get("combat_charge_phase", "")) == CHARGE_PHASE_IMPACT
			)
			var impact_attack_context := attack_context.duplicate(true)
			impact_attack_context["attack_sequence"] = sequence
			var single_attack := _resolve_npc_attack_impact(
				npc_id,
				npc,
				target,
				impact_attack_context,
				is_charge_impact
			)
			if not single_attack.is_empty():
				single_attack["attack_sequence"] = sequence
				single_attack["impact_seconds"] = impact_seconds
				single_attack["cycle_seconds"] = cycle_seconds
				attacks.append(single_attack)
			impact_committed = not single_attack.is_empty()
			phase = "recovery"
			if is_charge_impact:
				break
		else:
			phase = "idle"
			elapsed = 0.0
			cycle_seconds = 0.0
			impact_seconds = 0.0
			cycle_target_enemy_id = ""
			impact_committed = false
			if str(attack_context.get("strategy_id", "")) == STRATEGY_CHARGE_CYCLE:
				break

	cooldown = maxf(0.0, next_sequence_time - _combat_timeline_seconds)
	var last_attack := attacks[attacks.size() - 1] if not attacks.is_empty() else {}
	var state_changes := {
		"combat_attack_cooldown": cooldown,
		"combat_target_enemy_id": str(target.get("id", "")),
		"combat_attack_target_enemy_id": cycle_target_enemy_id,
		"combat_attack_phase": phase,
		"combat_attack_elapsed_seconds": elapsed,
		"combat_attack_cycle_seconds": cycle_seconds,
		"combat_attack_impact_seconds": impact_seconds,
		"combat_attack_playback_multiplier": playback_multiplier,
		"combat_attack_sequence": sequence,
		"combat_attack_impact_committed": impact_committed,
		"combat_attack_last_sequence_time": last_sequence_time,
		"combat_attack_next_sequence_time": next_sequence_time,
		"combat_attack_sequence_lock_remaining": cooldown,
		"combat_projectile_authority": "combat_system" if _is_ranged_weapon_type(str(attack_context.get("weapon_id", ""))) else "",
		"combat_last_attack_result": last_attack,
		"last_action_result": "combat_attack_made" if not attacks.is_empty() else "combat_attack_in_progress"
	}
	if phase == "windup":
		state_changes["current_action"] = "winding_up_%s" % cycle_target_enemy_id
	elif phase == "recovery":
		state_changes["current_action"] = "attacking_%s" % cycle_target_enemy_id
	else:
		state_changes["current_action"] = "combat_ready"
	if npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, state_changes)
	if measured:
		_performance_probe.record("friendly_state_commit_ms", Time.get_ticks_usec() - section_started)

	return {
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"attack_count": attacks.size(),
		"target": _serialize_target(target),
		"attack_context": attack_context,
		"combat_seconds": combat_delta_seconds,
		"cooldown": cooldown,
		"attack_next_sequence_time": next_sequence_time,
		"attack_sequence_lock_remaining": cooldown,
		"attacks": attacks
	}


func _resolve_npc_attack_impact(
	npc_id: String,
	npc: Dictionary,
	target: Dictionary,
	attack_context: Dictionary,
	is_charge_impact: bool
) -> Dictionary:
	if not is_charge_impact:
		if _is_ranged_weapon_type(str(attack_context.get("weapon_id", ""))):
			return _release_npc_projectile(npc_id, npc, target, attack_context)
		return _resolve_npc_locked_actor_melee_impact(npc_id, npc, target, attack_context)
	var swing_key := _melee_swing_key("friendly", npc_id)
	var active_swing: Dictionary = _active_melee_swings.get(swing_key, {}) if _active_melee_swings.get(swing_key, {}) is Dictionary else {}
	if bool(active_swing.get("damage_committed", false)):
		return _resolve_npc_melee_contact(npc_id, npc, target, attack_context)
	var charge_impact := _apply_cavalry_charge_impact(npc_id, npc, target, attack_context)
	if charge_impact.is_empty():
		return {}
	var target_enemy_id := str(target.get("id", ""))
	var single_attack := {}
	if _active_enemies.has(target_enemy_id):
		var charged_attack_context := attack_context.duplicate(true)
		var weapon_multiplier := maxf(1.0, float(charge_impact.get("weapon_damage_multiplier", 1.0)))
		charged_attack_context["raw_attack_power"] = (
			float(attack_context.get("raw_attack_power", 1.0))
			* weapon_multiplier
		)
		charged_attack_context["attack_power"] = maxi(
			1,
			int(round(float(charged_attack_context.get("raw_attack_power", 1.0))))
		)
		charged_attack_context["charge_impact"] = charge_impact.duplicate(true)
		single_attack = _resolve_npc_melee_contact(
			npc_id,
			npc,
			target,
			charged_attack_context
		)
		single_attack["charge_impact"] = charge_impact.duplicate(true)
	else:
		single_attack = {
			"attacker_npc_id": npc_id,
			"attacker_name": str(npc.get("name", npc_id)),
			"target_enemy_id": target_enemy_id,
			"target_enemy_name": str(target.get("name", target_enemy_id)),
			"source_type": "horse_collision",
			"damage": int(charge_impact.get("collision_damage", 0)),
			"damage_result": charge_impact.get("collision_damage_result", {}).duplicate(true),
			"charge_impact": charge_impact.duplicate(true),
			"event": {}
		}
	_update_npc_charge_phase(npc_id, CHARGE_PHASE_WITHDRAW, charge_impact)
	return single_attack


func _face_npc_toward_target(npc_system: Node, npc_id: String, target: Dictionary) -> void:
	if npc_system == null or not npc_system.has_method("set_npc_facing_direction"):
		return
	var npc_position := _get_npc_position(npc_id)
	var target_position: Vector3 = target.get("position", npc_position)
	var direction := target_position - npc_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		npc_system.set_npc_facing_direction(npc_id, direction)


func _select_npc_attack_target(
	npc_id: String,
	attack_context: Dictionary,
	locked_enemy_id: String = "",
	locked_range_margin: float = 0.0
) -> Dictionary:
	var npc_position := _get_npc_position(npc_id)
	var attack_range := maxf(0.1, float(attack_context.get("range", 1.5)))
	var preferred_enemy_id := ""
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc_state"):
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		preferred_enemy_id = str(state.get("combat_target_enemy_id", ""))
		if (
			str(attack_context.get("strategy_id", "")) == STRATEGY_CHARGE_CYCLE
			and str(state.get("combat_charge_phase", "")) == CHARGE_PHASE_IMPACT
		):
			attack_range += CAVALRY_CHARGE_IMPACT_TOLERANCE
	if not locked_enemy_id.is_empty():
		preferred_enemy_id = locked_enemy_id
	if preferred_enemy_id.is_empty() or not _active_enemies.has(preferred_enemy_id):
		return {}
	var preferred := _make_enemy_attack_target(preferred_enemy_id, npc_position)
	if preferred.is_empty():
		return {}
	var permitted_range := attack_range + maxf(0.0, locked_range_margin)
	return preferred if float(preferred.get("distance", INF)) <= permitted_range else {}


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
	target_in_range: Dictionary,
	strategic_target: Dictionary = {}
) -> Dictionary:
	var strategy_id := str(attack_context.get("strategy_id", STRATEGY_ATTACK))
	# Combat avoidance is threat-field driven, not target-lock driven. A durable
	# attack lock may legitimately point at a distant enemy while another enemy
	# closes from a different angle; using that lock as the avoidance trigger
	# strands the unit in combat_ready. Keep the attack lock for combat identity,
	# but let the nearest live threat trigger the shared weighted avoidance leg.
	if strategy_id == STRATEGY_AVOID:
		return _advance_combat_avoid_strategy_movement(npc_id, state)
	var attack_range := maxf(0.1, float(attack_context.get("range", 1.5)))
	var current_action := str(state.get("current_action", ""))
	var is_strategy_moving := current_action.begins_with("moving_to_%s" % STRATEGY_MOVE_TARGET_PREFIX)
	var nearest := strategic_target.duplicate(true)
	if nearest.is_empty():
		nearest = _nearest_enemy_for_combat_strategy(npc_id, strategy_id)
	if nearest.is_empty():
		if is_strategy_moving:
			return _stop_combat_strategy_move(npc_id, strategy_id, "combat_strategy_no_enemy_in_detection_range")
		return {}
	var distance := float(nearest.get("distance", INF))
	var weapon_id := str(attack_context.get("weapon_id", ""))
	var is_ranged_weapon := _is_ranged_weapon_type(weapon_id)
	var attack_path_blocked := (
		not target_in_range.is_empty()
		and not _is_friendly_attack_path_clear(npc_id, target_in_range, weapon_id)
	)
	var attack_handoff_range := attack_range * RANGED_ATTACK_POSITION_RANGE_RATIO if is_ranged_weapon else attack_range
	if not is_ranged_weapon:
		# The configured melee range is the outer acquisition boundary. Do not
		# cancel an active approach on that exact edge: the authored blade sweep
		# can legitimately miss there after animation/body clearance is applied.
		# Enter the same inner standoff band used to author the approach point
		# before handing physical authority from navigation to the attack cycle.
		attack_handoff_range = maxf(0.1, attack_range * COMBAT_APPROACH_RANGE_RATIO)

	if is_strategy_moving:
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		var physical_movement_active := (
			npc_system != null
			and npc_system.has_method("is_npc_world_movement_active")
			and bool(npc_system.is_npc_world_movement_active(npc_id))
		)
		var moving_enemy_id := str(
			state.get(
				"combat_strategy_move_enemy_id",
				state.get("combat_target_enemy_id", "")
			)
		)
		# The state label is not movement authority. A navigation request can be
		# cancelled/replaced without an arrival callback; trusting only the
		# moving_to_combat_strategy_* string strands the NPC in tactical movement
		# forever. Also cancel a still-live melee approach only after it reaches
		# the inner handoff band so movement and attack never control the body at
		# the same time and the authored blade is not left on the outer edge.
		if (
			strategy_id in [STRATEGY_ATTACK, STRATEGY_KEEP_DISTANCE, STRATEGY_MAX_OUTPUT]
			and not target_in_range.is_empty()
			and not attack_path_blocked
			and float(target_in_range.get("distance", INF)) <= attack_handoff_range
		):
			_settle_combat_strategy_move_handoff(
				npc_id,
				strategy_id,
				target_in_range,
				"combat_strategy_attack_range_reached"
			)
			return {}
		if (
			physical_movement_active
			and not moving_enemy_id.is_empty()
			and moving_enemy_id != str(nearest.get("enemy_id", nearest.get("id", "")))
		):
			_settle_combat_strategy_move_handoff(
				npc_id,
				strategy_id,
				nearest,
				"combat_strategy_locked_enemy_retarget"
			)
			physical_movement_active = false
			is_strategy_moving = false
		var movement_progress: Dictionary = (
			npc_system.get_npc_world_movement_progress(npc_id)
			if physical_movement_active and npc_system.has_method("get_npc_world_movement_progress")
			else {}
		)
		var stationary_elapsed := float(movement_progress.get("stationary_elapsed_seconds", 0.0))
		if (
			physical_movement_active
			and is_ranged_weapon
			and strategy_id in [STRATEGY_ATTACK, STRATEGY_KEEP_DISTANCE, STRATEGY_MAX_OUTPUT]
			and stationary_elapsed >= _get_friendly_strategy_stalled_reselect_seconds()
		):
			var stalled_position := _vector3_from_dict(
				state.get("combat_strategy_move_target_position", {}),
				_get_npc_position(npc_id)
			)
			var recovery_count := int(state.get("combat_strategy_move_recovery_count", 0)) + 1
			var recovered_target := _select_ranged_attack_position(
				npc_id,
				nearest,
				attack_range,
				weapon_id,
				stalled_position,
				_get_friendly_strategy_reselect_min_separation()
			)
			_settle_combat_strategy_move_handoff(
				npc_id,
				strategy_id,
				nearest,
				"combat_strategy_stalled_position_reselected"
			)
			var recovery_state := {
				"combat_strategy_move_recovery_count": recovery_count,
				"combat_strategy_last_stall": {
					"stationary_elapsed_seconds": stationary_elapsed,
					"repath_count": int(movement_progress.get("repath_count", 0)),
					"target_update_count": int(movement_progress.get("target_update_count", 0)),
					"previous_target_position": _vector3_to_dict(stalled_position)
				}
			}
			var recovery_result := _start_combat_strategy_move(
				npc_id,
				strategy_id,
				nearest,
				recovered_target,
				"combat_strategy_stalled_position_reselected",
				recovery_state,
				recovery_state
			)
			recovery_result["stationary_elapsed_seconds"] = stationary_elapsed
			recovery_result["previous_target_position"] = _vector3_to_dict(stalled_position)
			recovery_result["recovery_count"] = recovery_count
			return recovery_result
		if physical_movement_active:
			if (
				strategy_id in [STRATEGY_ATTACK, STRATEGY_KEEP_DISTANCE, STRATEGY_MAX_OUTPUT]
				and (target_in_range.is_empty() or attack_path_blocked or distance > attack_handoff_range)
				and (distance > attack_handoff_range or attack_path_blocked)
				and npc_system.has_method("update_npc_world_movement_target")
			):
				var updated_approach := (
					_select_ranged_attack_position(npc_id, nearest, attack_range, weapon_id)
					if is_ranged_weapon
					else _select_blocked_attack_approach_target(npc_id, nearest, attack_range, weapon_id)
					if attack_path_blocked
					else _select_approach_target(npc_id, nearest, attack_range)
				)
				var updated_position: Vector3 = updated_approach.get("position", _get_npc_position(npc_id))
				var stored_position := _vector3_from_dict(
					state.get("combat_strategy_move_target_position", {}),
					updated_position
				)
				var target_update_distance := maxf(0.05, float(_combat_navigation_policy.get("target_update_distance", 0.35)))
				if _horizontal_vector_distance(stored_position, updated_position) > target_update_distance:
					var target_updated := bool(npc_system.update_npc_world_movement_target(npc_id, updated_position, {
						"combat_strategy_move_target_position": _vector3_to_dict(updated_position),
						"last_action_result": "combat_target_moved_repath"
					}))
					if target_updated:
						return {
							"ok": true,
							"npc_id": npc_id,
							"strategy_id": strategy_id,
							"strategy_label": _get_combat_strategy_label(strategy_id),
							"reason": "combat_target_moved_repath",
							"target_position": _vector3_to_dict(updated_position)
						}
			return {
				"ok": true,
				"npc_id": npc_id,
				"strategy_id": strategy_id,
				"strategy_label": _get_combat_strategy_label(strategy_id),
				"reason": "combat_strategy_movement_in_progress"
			}
		# The physical request is gone while state still claims it is moving.
		# Settle the stale request, then let the normal strategy branch below
		# calculate a fresh target from the enemy's current position this frame.
		_settle_combat_strategy_move_handoff(
			npc_id,
			strategy_id,
			nearest,
			"combat_strategy_stale_movement_recovered"
		)
		is_strategy_moving = false
		if is_ranged_weapon and strategy_id in [STRATEGY_ATTACK, STRATEGY_KEEP_DISTANCE, STRATEGY_MAX_OUTPUT]:
			var stale_position := _vector3_from_dict(
				state.get("combat_strategy_move_target_position", {}),
				_get_npc_position(npc_id)
			)
			return _start_combat_strategy_move(
				npc_id,
				strategy_id,
				nearest,
				_select_ranged_attack_position(
					npc_id,
					nearest,
					attack_range,
					weapon_id,
					stale_position,
					_get_friendly_strategy_reselect_min_separation()
				),
				"combat_strategy_stale_movement_recovered"
			)

	if attack_path_blocked and strategy_id in [STRATEGY_MAX_OUTPUT, STRATEGY_KEEP_DISTANCE, STRATEGY_ATTACK, STRATEGY_CHARGE_CYCLE]:
		return _start_combat_strategy_move(
			npc_id,
			strategy_id,
			nearest,
			_select_ranged_attack_position(npc_id, nearest, attack_range, weapon_id)
			if is_ranged_weapon
			else _select_blocked_attack_approach_target(npc_id, nearest, attack_range, weapon_id),
			"combat_strategy_attack_path_blocked"
		)
	if (
		is_ranged_weapon
		and strategy_id in [STRATEGY_MAX_OUTPUT, STRATEGY_KEEP_DISTANCE, STRATEGY_ATTACK]
		and distance > attack_handoff_range
	):
		return _start_combat_strategy_move(
			npc_id,
			strategy_id,
			nearest,
			_select_ranged_attack_position(npc_id, nearest, attack_range, weapon_id),
			"combat_strategy_ranged_attack_position"
		)

	match strategy_id:
		STRATEGY_KEEP_DISTANCE:
			# Close-range withdrawal is handled before target acquisition by
			# _advance_keep_distance_retreat_priority(). Once safe, this branch only
			# preserves the ordinary ranged approach behavior.
			if target_in_range.is_empty() and distance > attack_range:
				return _start_combat_strategy_move(
					npc_id,
					strategy_id,
					nearest,
					_select_approach_target(npc_id, nearest, attack_range),
					"combat_strategy_keep_in_range"
				)
		STRATEGY_MAX_OUTPUT:
			if target_in_range.is_empty() and distance > attack_range:
				return _start_combat_strategy_move(
					npc_id,
					strategy_id,
					nearest,
					_select_approach_target(npc_id, nearest, attack_range),
					"combat_strategy_max_output_approach"
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
			var charge_phase := str(state.get("combat_charge_phase", CHARGE_PHASE_WITHDRAW))
			if charge_phase == CHARGE_PHASE_IMPACT and distance <= attack_range + CAVALRY_CHARGE_IMPACT_TOLERANCE and cooldown <= 0.0:
				return {}
			if charge_phase == CHARGE_PHASE_IMPACT and cooldown > 0.0:
				charge_phase = CHARGE_PHASE_WITHDRAW
				_update_npc_charge_phase(npc_id, charge_phase)
			if charge_phase == CHARGE_PHASE_WITHDRAW:
				if distance >= CAVALRY_CHARGE_RESET_DISTANCE:
					charge_phase = CHARGE_PHASE_READY
					_update_npc_charge_phase(npc_id, charge_phase)
				else:
					return _start_combat_strategy_move(
						npc_id,
						strategy_id,
						nearest,
						_select_charge_reset_target(npc_id, nearest, attack_range),
						"combat_strategy_charge_reset",
						{"combat_charge_phase": CHARGE_PHASE_READY},
						{"combat_charge_phase": CHARGE_PHASE_WITHDRAW}
					)
			if charge_phase == CHARGE_PHASE_READY and not target_in_range.is_empty():
				_update_npc_charge_phase(npc_id, CHARGE_PHASE_IMPACT)
				return {}
			if [CHARGE_PHASE_READY, CHARGE_PHASE_CHARGING, CHARGE_PHASE_IMPACT].has(charge_phase):
				return _start_combat_strategy_move(
					npc_id,
					strategy_id,
					nearest,
					_select_approach_target(npc_id, nearest, attack_range, false),
					"combat_strategy_charge_approach",
					{"combat_charge_phase": CHARGE_PHASE_IMPACT},
					{"combat_charge_phase": CHARGE_PHASE_CHARGING}
				)
		_:
			pass
	return {}


func _advance_combat_avoid_strategy_movement(npc_id: String, state: Dictionary) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_world_position"):
		return {}
	var npc_position := _get_npc_position(npc_id)
	var trigger_range := _get_avoidance_trigger_range()
	var safe_distance := _get_avoidance_safe_distance()
	var threat_field := _build_avoidance_threat_field(npc_position, trigger_range, npc_id)
	var encounter: Dictionary = threat_field.get("nearest_encounter", {})
	var current_action := str(state.get("current_action", ""))
	var is_any_strategy_moving := current_action.begins_with("moving_to_%s" % STRATEGY_MOVE_TARGET_PREFIX)
	var is_avoid_strategy_moving := current_action.begins_with("moving_to_%s%s_" % [STRATEGY_MOVE_TARGET_PREFIX, STRATEGY_AVOID])
	var physical_movement_active := (
		npc_system.has_method("is_npc_world_movement_active")
		and bool(npc_system.is_npc_world_movement_active(npc_id))
	)

	# A request authored by attack/keep-distance/charge is not an avoidance leg.
	# Stop it before selecting the weighted point, otherwise changing strategy can
	# leave the NPC walking toward the enemy while the UI already says "avoid".
	if is_any_strategy_moving and not is_avoid_strategy_moving:
		_settle_combat_strategy_move_handoff(
			npc_id,
			STRATEGY_AVOID,
			{"enemy_id": str(state.get("combat_target_enemy_id", ""))},
			"combat_strategy_changed_to_avoid"
		)
		state = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else state
		current_action = str(state.get("current_action", ""))
		is_any_strategy_moving = false
		is_avoid_strategy_moving = false
		physical_movement_active = false

	var nearest_distance := float(encounter.get("distance", INF))
	if is_avoid_strategy_moving:
		# Preserve the existing contract: once the closest actual threat is outside
		# the safe threshold, stop immediately and wait. Crucially, this distance is
		# no longer taken from a potentially distant durable attack lock.
		if encounter.is_empty() or nearest_distance >= safe_distance:
			return _hold_combat_strategy_avoid(npc_id, state, encounter, true, threat_field)
		if physical_movement_active:
			return {
				"ok": true,
				"npc_id": npc_id,
				"strategy_id": STRATEGY_AVOID,
				"strategy_label": _get_combat_strategy_label(STRATEGY_AVOID),
				"reason": "combat_strategy_avoid_movement_in_progress",
				"enemy_id": str(encounter.get("enemy_id", "")),
				"enemy_name": str(encounter.get("enemy_name", "")),
				"enemy_distance": nearest_distance,
				"safe_distance": safe_distance,
				"threat_count": (threat_field.get("threats", []) as Array).size(),
				"threats": (threat_field.get("threats", []) as Array).duplicate(true)
			}
		var committed_position := _vector3_from_dict(
			state.get("combat_strategy_move_target_position", {}),
			npc_position
		)
		if _horizontal_vector_distance(npc_position, committed_position) > 0.35:
			var recovery_count := int(state.get("combat_strategy_avoid_movement_recovery_count", 0)) + 1
			var committed_target := {
				"target_id": str(state.get("combat_strategy_move_target_id", "combat_strategy_avoid_recovery")),
				"target_name": str(state.get("combat_strategy_move_target_name", "继续前往避战点")),
				"position": committed_position,
				"enemy_distance_after": float(state.get("combat_strategy_avoid_enemy_distance_after_target", 0.0))
			}
			var recovery_state := _make_combat_avoid_runtime_state(
				encounter,
				threat_field,
				committed_target,
				safe_distance,
				"combat_strategy_avoid_movement_recovered"
			)
			recovery_state["combat_strategy_avoid_movement_recovery_count"] = recovery_count
			var recovery := _start_combat_strategy_move(
				npc_id,
				STRATEGY_AVOID,
				encounter,
				committed_target,
				"combat_strategy_avoid_movement_recovered",
				recovery_state,
				recovery_state
			)
			recovery["movement_recovery_count"] = recovery_count
			return recovery
		_settle_combat_strategy_move_handoff(
			npc_id,
			STRATEGY_AVOID,
			encounter,
			"combat_strategy_avoid_leg_arrived"
		)
		state = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else state

	if encounter.is_empty() or nearest_distance >= safe_distance:
		return _hold_combat_strategy_avoid(npc_id, state, encounter, false, threat_field)
	var avoid_target := _select_avoidance_target(npc_id, encounter)
	if avoid_target.is_empty():
		return _hold_combat_strategy_avoid(npc_id, state, encounter, false, threat_field)
	var avoid_state := _make_combat_avoid_runtime_state(
		encounter,
		threat_field,
		avoid_target,
		safe_distance,
		"combat_strategy_avoid"
	)
	var move_result := _start_combat_strategy_move(
		npc_id,
		STRATEGY_AVOID,
		encounter,
		avoid_target,
		"combat_strategy_avoid",
		avoid_state,
		avoid_state
	)
	if not bool(move_result.get("ok", false)):
		return _hold_combat_strategy_avoid(npc_id, state, encounter, false, threat_field)
	move_result["safe_distance"] = safe_distance
	move_result["threat_count"] = (threat_field.get("threats", []) as Array).size()
	move_result["threats"] = (threat_field.get("threats", []) as Array).duplicate(true)
	move_result["avoidance_direction"] = _vector3_to_dict(avoid_target.get("direction", Vector3.ZERO))
	return move_result


func _make_combat_avoid_runtime_state(
	encounter: Dictionary,
	threat_field: Dictionary,
	target: Dictionary,
	safe_distance: float,
	reason: String
) -> Dictionary:
	return {
		"combat_strategy_move_strategy_id": STRATEGY_AVOID,
		"combat_strategy_avoid_nearest_enemy_id": str(encounter.get("enemy_id", "")),
		"combat_strategy_avoid_nearest_enemy_name": str(encounter.get("enemy_name", "")),
		"combat_strategy_avoid_nearest_enemy_distance": float(encounter.get("distance", INF)),
		"combat_strategy_avoid_safe_distance": safe_distance,
		"combat_strategy_avoid_threat_count": (threat_field.get("threats", []) as Array).size(),
		"combat_strategy_avoid_threats": (threat_field.get("threats", []) as Array).duplicate(true),
		"combat_strategy_avoid_direction": _vector3_to_dict(target.get("direction", threat_field.get("direction", Vector3.ZERO))),
		"combat_strategy_avoid_enemy_distance_after_target": float(target.get("enemy_distance_after", 0.0)),
		"combat_strategy_avoid_last_reason": reason
	}


func _settle_combat_strategy_move_handoff(
	npc_id: String,
	strategy_id: String,
	target: Dictionary,
	reason: String
) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("stop_npc_movement_with_state"):
		return
	var target_enemy_id := str(target.get("id", target.get("enemy_id", "")))
	if strategy_id == STRATEGY_AVOID and npc_system.has_method("get_npc_state"):
		var current_state: Dictionary = npc_system.get_npc_state(npc_id)
		var locked_enemy_id := str(current_state.get("combat_target_enemy_id", ""))
		if not locked_enemy_id.is_empty():
			target_enemy_id = locked_enemy_id
	npc_system.stop_npc_movement_with_state(npc_id, {
		"current_action": "combat_ready",
		"movement_target": "",
		"movement_target_name": "",
		"last_action_result": reason,
		"combat_target_enemy_id": target_enemy_id,
		"combat_strategy_move_target_id": "",
		"combat_strategy_move_target_name": "",
		"combat_strategy_move_target_position": {},
		"combat_strategy_move_enemy_id": "",
		"combat_strategy_move_strategy_id": "",
		"combat_strategy_last_handoff": {
			"reason": reason,
			"strategy_id": strategy_id,
			"enemy_id": target_enemy_id
		}
	})


func _start_combat_strategy_move(
	npc_id: String,
	strategy_id: String,
	encounter: Dictionary,
	target: Dictionary,
	reason: String,
	arrival_state_overrides: Dictionary = {},
	moving_state_overrides: Dictionary = {}
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
	var movement_enemy_id := str(encounter.get("enemy_id", encounter.get("id", "")))
	var current_state: Dictionary = (
		npc_system.get_npc_state(npc_id)
		if npc_system.has_method("get_npc_state")
		else {}
	)
	var combat_target_enemy_id := movement_enemy_id
	if strategy_id == STRATEGY_AVOID:
		var locked_enemy_id := str(current_state.get("combat_target_enemy_id", ""))
		if not locked_enemy_id.is_empty():
			combat_target_enemy_id = locked_enemy_id
	var arrival_state := {
		"current_action": "combat_ready",
		"current_location": RALLY_LOCATION_ID,
		"current_location_name": RALLY_LOCATION_NAME,
		"last_action_result": reason,
		"combat_target_enemy_id": combat_target_enemy_id,
		"combat_strategy_move_target_id": str(target.get("target_id", target_id)),
		"combat_strategy_move_target_name": target_name,
		"combat_strategy_move_target_position": _vector3_to_dict(target_position),
		"combat_strategy_move_enemy_id": movement_enemy_id,
		"combat_strategy_move_strategy_id": strategy_id
	}
	arrival_state["departure_state"] = {
		"combat_target_enemy_id": combat_target_enemy_id,
		"combat_strategy_move_target_id": str(target.get("target_id", target_id)),
		"combat_strategy_move_target_name": target_name,
		"combat_strategy_move_target_position": _vector3_to_dict(target_position),
		"combat_strategy_move_enemy_id": movement_enemy_id,
		"combat_strategy_move_strategy_id": strategy_id
	}
	arrival_state.merge(arrival_state_overrides, true)
	var motion_options := _get_combat_motion_options("friendly_%s_approach" % strategy_id)
	if bool(target.get("tracks_live_target", false)):
		# CombatSystem, not a fixed destination radius, owns the handoff for a live
		# opponent. Braking against every refreshed predicted point makes two actors
		# repeatedly decelerate while they are still outside melee range.
		motion_options["final_target_braking_enabled"] = false
	if target.get("target_desired_distance") is float or target.get("target_desired_distance") is int:
		motion_options["target_desired_distance"] = maxf(
			0.01,
			float(target.get("target_desired_distance", RANGED_ATTACK_POSITION_ARRIVAL_TOLERANCE_FALLBACK))
		)
	var moved := bool(npc_system.move_npc_to_world_position(
		npc_id,
		target_id,
		target_name,
		target_position,
		arrival_state,
		motion_options
	))
	if moved and not moving_state_overrides.is_empty() and npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, moving_state_overrides)
	return {
		"ok": moved,
		"npc_id": npc_id,
		"strategy_id": strategy_id,
		"strategy_label": _get_combat_strategy_label(strategy_id),
		"reason": reason,
		"enemy_id": str(encounter.get("enemy_id", encounter.get("id", ""))),
		"enemy_name": str(encounter.get("enemy_name", encounter.get("name", ""))),
		"enemy_distance": float(encounter.get("distance", 0.0)),
		"target_id": target_id,
		"target_name": target_name,
		"target_position": _vector3_to_dict(target_position),
		"target_enemy_distance": float(target.get("enemy_distance_after", 0.0)),
		"travel_distance": npc_position.distance_to(target_position)
	}


func _update_npc_charge_phase(npc_id: String, phase: String, impact: Dictionary = {}) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("update_npc_state"):
		return
	var changes := {"combat_charge_phase": phase}
	if not impact.is_empty():
		changes["combat_charge_last_impact"] = impact.duplicate(true)
	npc_system.update_npc_state(npc_id, changes)


func _stop_combat_strategy_move(npc_id: String, strategy_id: String, reason: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var state_changes := {
		"current_action": "combat_ready",
		"movement_target": "",
		"movement_target_name": "",
		"last_action_result": reason,
		"combat_target_enemy_id": "",
		"combat_strategy_move_target_id": "",
		"combat_strategy_move_target_name": "",
		"combat_strategy_move_target_position": {},
		"combat_strategy_move_enemy_id": "",
		"combat_strategy_move_strategy_id": ""
	}
	if npc_system != null and npc_system.has_method("stop_npc_movement_with_state"):
		npc_system.stop_npc_movement_with_state(npc_id, state_changes)
	return {
		"ok": true,
		"npc_id": npc_id,
		"strategy_id": strategy_id,
		"strategy_label": _get_combat_strategy_label(strategy_id),
		"reason": reason,
		"stopped_movement": true
	}


func _hold_combat_strategy_avoid(
	npc_id: String,
	state: Dictionary,
	encounter: Dictionary,
	stop_movement: bool,
	threat_field: Dictionary = {}
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var current_action := str(state.get("current_action", ""))
	var locked_enemy_id := str(state.get("combat_target_enemy_id", ""))
	var threat_count := (threat_field.get("threats", []) as Array).size()
	var safe_distance := _get_avoidance_safe_distance()
	var state_changes := {
		"current_action": "combat_strategy_avoid_holding",
		"movement_target": "",
		"movement_target_name": "",
		"last_action_result": "combat_strategy_avoid_holding",
		"combat_target_enemy_id": locked_enemy_id if not locked_enemy_id.is_empty() else str(encounter.get("enemy_id", "")),
		"combat_strategy_move_target_id": "",
		"combat_strategy_move_target_name": "",
		"combat_strategy_move_target_position": {},
		"combat_strategy_move_enemy_id": "",
		"combat_strategy_move_strategy_id": "",
		"combat_strategy_avoid_nearest_enemy_id": str(encounter.get("enemy_id", "")),
		"combat_strategy_avoid_nearest_enemy_name": str(encounter.get("enemy_name", "")),
		"combat_strategy_avoid_nearest_enemy_distance": float(encounter.get("distance", INF)),
		"combat_strategy_avoid_safe_distance": safe_distance,
		"combat_strategy_avoid_threat_count": threat_count,
		"combat_strategy_avoid_threats": (threat_field.get("threats", []) as Array).duplicate(true),
		"combat_strategy_avoid_last_reason": "combat_strategy_avoid_holding"
	}
	var should_update := stop_movement
	if not should_update:
		should_update = (
			current_action != "combat_strategy_avoid_holding"
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
		"safe_distance": safe_distance,
		"threat_count": threat_count,
		"threats": (threat_field.get("threats", []) as Array).duplicate(true),
		"holding": true,
		"stopped_movement": stop_movement
	}


func _advance_keep_distance_retreat_priority(
	npc_id: String,
	state: Dictionary,
	attack_context: Dictionary
) -> Dictionary:
	var strategy_id := str(attack_context.get("strategy_id", ""))
	var weapon_id := str(attack_context.get("weapon_id", ""))
	var retreat_active := bool(state.get("keep_distance_retreat_active", false))
	if strategy_id != STRATEGY_KEEP_DISTANCE or not _is_ranged_weapon_type(weapon_id):
		if retreat_active:
			_clear_keep_distance_retreat(npc_id, state, "keep_distance_retreat_strategy_changed", true)
		return {}

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_world_position"):
		return {}
	var npc_position := _get_npc_position(npc_id)
	var attack_range := maxf(0.1, float(attack_context.get("range", 1.5)))
	var trigger_range := attack_range * _get_keep_distance_retreat_trigger_range_ratio()
	var arrival_tolerance := _get_keep_distance_retreat_arrival_tolerance()
	if retreat_active:
		var stored_target_position := _vector3_from_dict(
			state.get("keep_distance_retreat_target_position", {}),
			npc_position
		)
		var stored_target_id := str(state.get("keep_distance_retreat_target_id", ""))
		var physical_movement_active := (
			npc_system.has_method("is_npc_world_movement_active")
			and bool(npc_system.is_npc_world_movement_active(npc_id))
		)
		var owns_physical_movement := (
			physical_movement_active
			and not stored_target_id.is_empty()
			and str(state.get("movement_target", "")) == stored_target_id
		)
		if owns_physical_movement:
			_enforce_keep_distance_retreat_attack_lock(npc_id, state)
			return {
				"ok": true,
				"npc_id": npc_id,
				"strategy_id": STRATEGY_KEEP_DISTANCE,
				"strategy_label": _get_combat_strategy_label(STRATEGY_KEEP_DISTANCE),
				"reason": "keep_distance_retreat_movement_in_progress",
				"target_id": stored_target_id,
				"target_position": _vector3_to_dict(stored_target_position),
				"trigger_range": trigger_range,
				"committed_leg": true
			}
		if _horizontal_vector_distance(npc_position, stored_target_position) > arrival_tolerance:
			# The request was cancelled or replaced before arrival. Restore the
			# exact committed endpoint; do not rescan and silently bend the leg.
			return _start_keep_distance_retreat_segment(
				npc_id,
				state,
				_keep_distance_retreat_target_from_state(state, stored_target_position),
				attack_range,
				"keep_distance_retreat_movement_recovered",
				true
			)

	# A new scan is legal only before the first leg or after the committed leg
	# has physically arrived. This is what makes new enemies irrelevant in transit.
	var threat_field := _build_avoidance_threat_field(npc_position, trigger_range, npc_id)
	var threats: Array = threat_field.get("threats", [])
	if threats.is_empty():
		if retreat_active:
			_clear_keep_distance_retreat(npc_id, state, "keep_distance_retreat_safe", false)
		return {}
	var retreat_target := _select_keep_distance_retreat_target(
		npc_id,
		npc_position,
		attack_range,
		threat_field
	)
	if retreat_target.is_empty():
		_enforce_keep_distance_retreat_attack_lock(npc_id, state)
		return {
			"ok": false,
			"npc_id": npc_id,
			"strategy_id": STRATEGY_KEEP_DISTANCE,
			"strategy_label": _get_combat_strategy_label(STRATEGY_KEEP_DISTANCE),
			"reason": "keep_distance_retreat_target_unavailable",
			"trigger_range": trigger_range,
			"threat_count": threats.size()
		}
	return _start_keep_distance_retreat_segment(
		npc_id,
		state,
		retreat_target,
		attack_range,
		"keep_distance_retreat_started" if not retreat_active else "keep_distance_retreat_repeated",
		false
	)


func _select_keep_distance_retreat_target(
	npc_id: String,
	npc_position: Vector3,
	attack_range: float,
	threat_field: Dictionary
) -> Dictionary:
	var threats: Array = threat_field.get("threats", [])
	if threats.is_empty():
		return {}
	var direction: Vector3 = threat_field.get("direction", _fallback_avoidance_direction(npc_id))
	direction.y = 0.0
	if direction.length_squared() <= 0.000001:
		direction = _fallback_avoidance_direction(npc_id)
	else:
		direction = direction.normalized()
	var desired_travel_distance := attack_range * _get_keep_distance_retreat_segment_range_ratio()
	var desired_position := npc_position + direction * desired_travel_distance
	var resolution := _resolve_avoidance_navigation_target(npc_position, desired_position)
	if not bool(resolution.get("ok", false)):
		return {}
	var position: Vector3 = resolution.get("position", npc_position)
	# A direct ray can terminate at the origin when a building envelope occupies
	# the weighted direction. In that case fan around the same direction and pick
	# a nearby reachable point that still does not reduce threat clearance. This
	# is an obstacle correction only; the authored weighted direction is retained.
	if _horizontal_vector_distance(npc_position, position) <= _get_keep_distance_retreat_arrival_tolerance():
		var alternate := _resolve_keep_distance_retreat_alternate_target(
			npc_position,
			direction,
			desired_travel_distance
		)
		if alternate.is_empty():
			return {}
		resolution = alternate
		position = resolution.get("position", npc_position)
		desired_position = resolution.get("desired_position", desired_position)
	var nearest: Dictionary = threat_field.get("nearest_encounter", {})
	var threat_ids: Array[String] = []
	var serialized_threats: Array[Dictionary] = []
	for raw_threat in threats:
		var threat := raw_threat as Dictionary
		var enemy_id := str(threat.get("enemy_id", ""))
		threat_ids.append(enemy_id)
		serialized_threats.append({
			"enemy_id": enemy_id,
			"enemy_name": str(threat.get("enemy_name", enemy_id)),
			"distance": float(threat.get("distance", 0.0)),
			"weight": float(threat.get("weight", 0.0))
		})
	return {
		"target_name": "保持距离撤离点",
		"position": position,
		"desired_position": desired_position,
		"direction": direction,
		"threat_ids": threat_ids,
		"threats": serialized_threats,
		"threat_count": serialized_threats.size(),
		"nearest_enemy_id": str(nearest.get("enemy_id", "")),
		"nearest_enemy_name": str(nearest.get("enemy_name", "")),
		"desired_travel_distance": desired_travel_distance,
		"travel_distance": _horizontal_vector_distance(npc_position, position),
		"boundary_limited": bool(resolution.get("boundary_limited", false)),
		"navigation_adjusted": bool(resolution.get("navigation_adjusted", false)),
		"navigation_resolution_reason": str(resolution.get("reason", "")),
		"weight_formula": "inverse_distance_power",
		"weight_exponent": _get_avoidance_weight_exponent()
	}


func _resolve_keep_distance_retreat_alternate_target(
	npc_position: Vector3,
	weighted_direction: Vector3,
	desired_travel_distance: float
) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	var origin_threat_distance := _get_min_enemy_distance(npc_position)
	for angle_degrees in [22.5, -22.5, 45.0, -45.0, 67.5, -67.5, 90.0, -90.0, 112.5, -112.5, 135.0, -135.0, 157.5, -157.5, 180.0]:
		var candidate_direction := weighted_direction.rotated(Vector3.UP, deg_to_rad(float(angle_degrees))).normalized()
		var alternate_desired := npc_position + candidate_direction * desired_travel_distance
		var resolution := _resolve_avoidance_navigation_target(npc_position, alternate_desired)
		if not bool(resolution.get("ok", false)):
			continue
		var candidate: Vector3 = resolution.get("position", npc_position)
		var travel_distance := _horizontal_vector_distance(npc_position, candidate)
		if travel_distance <= _get_keep_distance_retreat_arrival_tolerance():
			continue
		if _get_min_enemy_distance(candidate) + 0.05 < origin_threat_distance:
			continue
		var actual_direction := candidate - npc_position
		actual_direction.y = 0.0
		if actual_direction.length_squared() <= 0.000001:
			continue
		actual_direction = actual_direction.normalized()
		var alignment := actual_direction.dot(weighted_direction)
		var score := travel_distance * (0.75 + maxf(-0.5, alignment) * 0.25)
		if score <= best_score:
			continue
		best_score = score
		best = resolution.duplicate(true)
		best["desired_position"] = alternate_desired
		best["reason"] = "station_navigation_resolved_with_keep_distance_side_offset"
		best["side_offset_degrees"] = float(angle_degrees)
	return best


func _start_keep_distance_retreat_segment(
	npc_id: String,
	state: Dictionary,
	target: Dictionary,
	attack_range: float,
	reason: String,
	is_recovery: bool
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("move_npc_to_world_position"):
		return {}
	var sequence := maxi(1, int(state.get("keep_distance_retreat_sequence", 0)) + (0 if is_recovery else 1))
	var target_id := str(target.get("target_id", ""))
	if target_id.is_empty():
		target_id = "keep_distance_retreat_%s_%d" % [npc_id, sequence]
	var target_position: Vector3 = target.get("position", _get_npc_position(npc_id))
	var target_name := str(target.get("target_name", "保持距离撤离点"))
	var target_state := {
		"keep_distance_retreat_active": true,
		"keep_distance_retreat_sequence": sequence,
		"keep_distance_retreat_target_id": target_id,
		"keep_distance_retreat_target_position": _vector3_to_dict(target_position),
		"keep_distance_retreat_desired_position": _vector3_to_dict(target.get("desired_position", target_position)),
		"keep_distance_retreat_direction": _vector3_to_dict(target.get("direction", Vector3.ZERO)),
		"keep_distance_retreat_threat_ids": (target.get("threat_ids", []) as Array).duplicate(),
		"keep_distance_retreat_threats": (target.get("threats", []) as Array).duplicate(true),
		"keep_distance_retreat_desired_travel_distance": float(target.get("desired_travel_distance", attack_range * _get_keep_distance_retreat_segment_range_ratio())),
		"keep_distance_retreat_actual_travel_distance": float(target.get("travel_distance", 0.0)),
		"keep_distance_retreat_boundary_limited": bool(target.get("boundary_limited", false)),
		"keep_distance_retreat_navigation_adjusted": bool(target.get("navigation_adjusted", false)),
		"keep_distance_retreat_recovery_count": int(state.get("keep_distance_retreat_recovery_count", 0)) + (1 if is_recovery else 0),
		"combat_target_enemy_id": "",
		"combat_target_selection_reason": "keep_distance_close_threat_retreat",
		"combat_target_scope": "",
		"combat_attack_target_enemy_id": "",
		"combat_attack_phase": "idle",
		"combat_attack_elapsed_seconds": 0.0,
		"combat_attack_cycle_seconds": 0.0,
		"combat_attack_impact_seconds": 0.0,
		"combat_attack_impact_committed": false,
		"combat_last_attack_result": {},
		"combat_strategy_move_target_id": target_id,
		"combat_strategy_move_target_name": target_name,
		"combat_strategy_move_target_position": _vector3_to_dict(target_position),
		"combat_strategy_move_enemy_id": "",
		"last_action_result": reason
	}
	var arrival_state := target_state.duplicate(true)
	arrival_state.merge({
		"current_action": "combat_ready",
		"departure_current_action": "keep_distance_retreating",
		"current_location": RALLY_LOCATION_ID,
		"current_location_name": RALLY_LOCATION_NAME,
		"movement_target": "",
		"movement_target_name": "",
		"departure_state": target_state.duplicate(true)
	}, true)
	_friendly_enemy_reacquire_requests.erase(npc_id)
	var moved := bool(npc_system.move_npc_to_world_position(
		npc_id,
		target_id,
		target_name,
		target_position,
		arrival_state,
		_get_combat_motion_options("friendly_keep_distance_retreat")
	))
	if not moved and npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, target_state)
	return {
		"ok": moved,
		"npc_id": npc_id,
		"strategy_id": STRATEGY_KEEP_DISTANCE,
		"strategy_label": _get_combat_strategy_label(STRATEGY_KEEP_DISTANCE),
		"reason": reason,
		"target_id": target_id,
		"target_name": target_name,
		"target_position": _vector3_to_dict(target_position),
		"desired_position": _vector3_to_dict(target.get("desired_position", target_position)),
		"direction": _vector3_to_dict(target.get("direction", Vector3.ZERO)),
		"trigger_range": attack_range * _get_keep_distance_retreat_trigger_range_ratio(),
		"desired_travel_distance": float(target_state.get("keep_distance_retreat_desired_travel_distance", 0.0)),
		"travel_distance": float(target_state.get("keep_distance_retreat_actual_travel_distance", 0.0)),
		"threat_count": (target.get("threats", []) as Array).size(),
		"threats": (target.get("threats", []) as Array).duplicate(true),
		"boundary_limited": bool(target.get("boundary_limited", false)),
		"navigation_adjusted": bool(target.get("navigation_adjusted", false)),
		"committed_leg": true,
		"movement_recovery": is_recovery
	}


func _keep_distance_retreat_target_from_state(state: Dictionary, position: Vector3) -> Dictionary:
	return {
		"target_id": str(state.get("keep_distance_retreat_target_id", "")),
		"target_name": "保持距离撤离点",
		"position": position,
		"desired_position": _vector3_from_dict(state.get("keep_distance_retreat_desired_position", {}), position),
		"direction": _vector3_from_dict(state.get("keep_distance_retreat_direction", {}), Vector3.ZERO),
		"threat_ids": (state.get("keep_distance_retreat_threat_ids", []) as Array).duplicate(),
		"threats": (state.get("keep_distance_retreat_threats", []) as Array).duplicate(true),
		"desired_travel_distance": float(state.get("keep_distance_retreat_desired_travel_distance", 0.0)),
		"travel_distance": float(state.get("keep_distance_retreat_actual_travel_distance", 0.0)),
		"boundary_limited": bool(state.get("keep_distance_retreat_boundary_limited", false)),
		"navigation_adjusted": bool(state.get("keep_distance_retreat_navigation_adjusted", false))
	}


func _enforce_keep_distance_retreat_attack_lock(npc_id: String, state: Dictionary) -> void:
	_friendly_enemy_reacquire_requests.erase(npc_id)
	if (
		str(state.get("combat_target_enemy_id", "")).is_empty()
		and str(state.get("combat_attack_target_enemy_id", "")).is_empty()
		and str(state.get("combat_attack_phase", "idle")) == "idle"
	):
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, {
			"combat_target_enemy_id": "",
			"combat_target_selection_reason": "keep_distance_close_threat_retreat",
			"combat_target_scope": "",
			"combat_attack_target_enemy_id": "",
			"combat_attack_phase": "idle",
			"combat_attack_elapsed_seconds": 0.0,
			"combat_attack_cycle_seconds": 0.0,
			"combat_attack_impact_seconds": 0.0,
			"combat_attack_impact_committed": false,
			"combat_last_attack_result": {}
		})


func _clear_keep_distance_retreat(
	npc_id: String,
	state: Dictionary,
	reason: String,
	stop_movement: bool,
	preserve_current_movement: bool = false,
	settled_action: String = "combat_ready"
) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var changes := {
		"last_action_result": reason,
		"keep_distance_retreat_active": false,
		"keep_distance_retreat_target_id": "",
		"keep_distance_retreat_target_position": {},
		"keep_distance_retreat_desired_position": {},
		"keep_distance_retreat_direction": {},
		"keep_distance_retreat_threat_ids": [],
		"keep_distance_retreat_threats": [],
		"combat_strategy_move_target_id": "",
		"combat_strategy_move_target_name": "",
		"combat_strategy_move_target_position": {},
		"combat_strategy_move_enemy_id": ""
	}
	if not preserve_current_movement:
		changes["current_action"] = settled_action
		changes["movement_target"] = ""
		changes["movement_target_name"] = ""
	if stop_movement and npc_system.has_method("stop_npc_movement_with_state"):
		npc_system.stop_npc_movement_with_state(npc_id, changes)
	elif npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, changes)


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
	var position := _constrain_combat_strategy_position(enemy_position + away_direction * target_distance, npc_id)
	return {
		"target_id": "charge_reset_%d" % _stable_hash_text("%s:%s" % [npc_id, str(encounter.get("enemy_id", ""))]),
		"target_name": "拉开距离准备冲击",
		"position": position,
		"enemy_distance_after": position.distance_to(enemy_position)
	}


func _select_approach_target(
	npc_id: String,
	encounter: Dictionary,
	attack_range: float,
	reserve_arrival_tolerance: bool = true
) -> Dictionary:
	var npc_position := _get_npc_position(npc_id)
	var enemy_position: Vector3 = encounter.get("position", npc_position + Vector3(0.0, 0.0, 1.0))
	var away_from_enemy := npc_position - enemy_position
	away_from_enemy.y = 0.0
	if away_from_enemy.length() <= 0.001:
		away_from_enemy = _fallback_avoidance_direction(npc_id)
	else:
		away_from_enemy = away_from_enemy.normalized()
	# Reserve the generic navigation arrival tolerance inside the authored
	# standoff. Otherwise a request may legally finish one tolerance-width before
	# the approach point and leave a melee unit just outside its weapon range.
	var arrival_reserve := maxf(
		0.0,
		float(_formal_attack_position_policy.get("arrival_tolerance", 0.32))
	) if reserve_arrival_tolerance else 0.0
	var desired_distance := maxf(
		0.2,
		attack_range * COMBAT_APPROACH_RANGE_RATIO - arrival_reserve
	)
	var position := _constrain_combat_strategy_position(enemy_position + away_from_enemy * desired_distance, npc_id)
	return {
		"target_id": "approach_%d" % _stable_hash_text("%s:%s" % [npc_id, str(encounter.get("enemy_id", ""))]),
		"target_name": "接近攻击距离",
		"position": position,
		"enemy_distance_after": position.distance_to(enemy_position),
		"tracks_live_target": true
	}


func _select_blocked_attack_approach_target(
	npc_id: String,
	encounter: Dictionary,
	attack_range: float,
	weapon_id: String
) -> Dictionary:
	var npc_position := _get_npc_position(npc_id)
	var enemy_position: Vector3 = encounter.get("position", npc_position + Vector3(0.0, 0.0, 1.0))
	var away_from_enemy := npc_position - enemy_position
	away_from_enemy.y = 0.0
	if away_from_enemy.length() <= 0.001:
		away_from_enemy = _fallback_avoidance_direction(npc_id)
	else:
		away_from_enemy = away_from_enemy.normalized()
	var arrival_reserve := maxf(0.0, float(_formal_attack_position_policy.get("arrival_tolerance", 0.32)))
	var standoff_ratio := 0.5 if _is_ranged_weapon_type(weapon_id) else COMBAT_APPROACH_RANGE_RATIO
	var desired_distance := maxf(0.2, attack_range * standoff_ratio - arrival_reserve)
	var position := _constrain_combat_strategy_position(enemy_position + away_from_enemy * desired_distance, npc_id)
	return {
		"target_id": "clear_attack_path_%d" % _stable_hash_text("%s:%s" % [npc_id, str(encounter.get("enemy_id", encounter.get("id", "")))]),
		"target_name": "移动到可攻击位置",
		"position": position,
		"enemy_distance_after": position.distance_to(enemy_position)
	}


func _select_ranged_attack_position(
	npc_id: String,
	encounter: Dictionary,
	attack_range: float,
	weapon_id: String,
	excluded_position: Vector3 = Vector3(INF, INF, INF),
	excluded_radius: float = 0.0
) -> Dictionary:
	var measured: bool = _performance_probe != null and _performance_probe.active
	var profile_started := Time.get_ticks_usec() if measured else 0
	var npc_position := _get_npc_position(npc_id)
	var enemy_position: Vector3 = encounter.get("position", npc_position + Vector3(0.0, 0.0, 1.0))
	var arrival_tolerance := _get_friendly_ranged_attack_position_arrival_tolerance()
	# ActorMotion may finish anywhere inside target_desired_distance. Put the
	# physical endpoint one tolerance inside the 95% handoff boundary so an
	# outward-edge arrival still transfers authority to the attack timeline.
	var attack_position_radius := maxf(
		0.2,
		attack_range * RANGED_ATTACK_POSITION_RANGE_RATIO - arrival_tolerance
	)
	var maximum_endpoint_distance := attack_range * RANGED_ATTACK_POSITION_RANGE_RATIO - arrival_tolerance
	var direct_direction := npc_position - enemy_position
	direct_direction.y = 0.0
	if direct_direction.length() <= 0.001:
		direct_direction = _fallback_avoidance_direction(npc_id)
	else:
		direct_direction = direct_direction.normalized()
	var base_angle := atan2(direct_direction.z, direct_direction.x)
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var navigation_map := RID()
	if controller != null and controller.has_method("get_production_navigation_map_rid"):
		navigation_map = controller.get_production_navigation_map_rid()
	var best_clear := {}
	var best_reachable := {}
	# All samples are evaluated synchronously in one combat decision. The release
	# socket, target aim point, shooter RID and stable target ID therefore cannot
	# change between samples; resolve them once while retaining all 32 authored
	# navigation paths, rays and the original nearest-candidate ordering.
	var attack_position_target_id := "ranged_attack_position_%d" % _stable_hash_text(
		"%s:%s" % [npc_id, str(encounter.get("enemy_id", encounter.get("id", "")))]
	)
	var attack_path_destination := _get_projectile_target_aim_position(encounter)
	var attack_origin_height := _get_friendly_attack_origin_height(npc_id, weapon_id, npc_position)
	var attack_path_excluded := _get_friendly_attack_segment_exclusions(npc_id)
	if navigation_map.is_valid():
		var candidates: Array[Dictionary] = []
		for sample_index in range(RANGED_ATTACK_POSITION_SAMPLE_COUNT):
			var angle := base_angle + TAU * float(sample_index) / float(RANGED_ATTACK_POSITION_SAMPLE_COUNT)
			var authored_position := enemy_position + Vector3(cos(angle), 0.0, sin(angle)) * attack_position_radius
			var snapped := NavigationServer3D.map_get_closest_point(navigation_map, authored_position)
			if _horizontal_vector_distance(authored_position, snapped) > RANGED_ATTACK_POSITION_SNAP_TOLERANCE:
				continue
			if excluded_position != Vector3(INF, INF, INF) and _horizontal_vector_distance(snapped, excluded_position) < excluded_radius:
				continue
			if _horizontal_vector_distance(snapped, enemy_position) > maximum_endpoint_distance + 0.001:
				continue
			candidates.append({
				"sample_index": sample_index,
				"position": snapped,
				"travel_distance": _horizontal_vector_distance(npc_position, snapped),
			})
		# The authored winner is the nearest reachable/clear point by direct travel
		# distance. Evaluate in that exact priority order so the first clear point is
		# provably the same winner; the old loop paid for all 32 path and ray queries
		# even after that winner was already known.
		candidates.sort_custom(_ranged_attack_position_candidate_less)
		for raw_candidate in candidates:
			var snapped: Vector3 = raw_candidate.position
			var travel_distance := float(raw_candidate.travel_distance)
			var path := NavigationServer3D.map_get_path(navigation_map, npc_position, snapped, true)
			if path.is_empty() and travel_distance > 0.2:
				continue
			if not path.is_empty() and _horizontal_vector_distance(path[path.size() - 1], snapped) > RANGED_ATTACK_POSITION_SNAP_TOLERANCE:
				continue
			var candidate := {
				"target_id": attack_position_target_id,
				"target_name": "选择远程攻击点",
				"position": snapped,
				"enemy_distance_after": _horizontal_vector_distance(snapped, enemy_position),
				"line_of_fire_clear": _is_static_attack_segment_clear_with_exclusions(
					snapped + Vector3.UP * attack_origin_height,
					attack_path_destination,
					attack_path_excluded
				),
				"target_desired_distance": arrival_tolerance
			}
			if best_reachable.is_empty():
				best_reachable = candidate
			if bool(candidate.get("line_of_fire_clear", false)):
				best_clear = candidate
				break
	if not best_clear.is_empty():
		return _profile_friendly_ranged_attack_position(best_clear, profile_started, measured)
	if not best_reachable.is_empty():
		return _profile_friendly_ranged_attack_position(best_reachable, profile_started, measured)
	# Navigation data can be unavailable during the first synchronization frame.
	# Keep the combat loop live with the direct 95%-range point; the movement
	# request and the next combat tick will constrain/reselect it again.
	var fallback_position := _constrain_combat_strategy_position(
		enemy_position + direct_direction * attack_position_radius,
		npc_id
	)
	if excluded_position != Vector3(INF, INF, INF) and _horizontal_vector_distance(fallback_position, excluded_position) < excluded_radius:
		for offset_index in range(1, 9):
			var rotated_direction := direct_direction.rotated(Vector3.UP, float(offset_index) * PI / 4.0)
			var rotated_position := _constrain_combat_strategy_position(
				enemy_position + rotated_direction * attack_position_radius,
				npc_id
			)
			if _horizontal_vector_distance(rotated_position, excluded_position) >= excluded_radius:
				fallback_position = rotated_position
				break
	var fallback_offset := fallback_position - enemy_position
	fallback_offset.y = 0.0
	if fallback_offset.length() > maximum_endpoint_distance and fallback_offset.length() > 0.001:
		fallback_position = enemy_position + fallback_offset.normalized() * maximum_endpoint_distance
	return _profile_friendly_ranged_attack_position({
		"target_id": "ranged_attack_position_fallback_%d" % _stable_hash_text("%s:%s" % [npc_id, str(encounter.get("enemy_id", encounter.get("id", "")))]),
		"target_name": "选择远程攻击点",
		"position": fallback_position,
		"enemy_distance_after": _horizontal_vector_distance(fallback_position, enemy_position),
		"line_of_fire_clear": false,
		"target_desired_distance": arrival_tolerance
	}, profile_started, measured)


func _ranged_attack_position_candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var a_distance := float(a.get("travel_distance", INF))
	var b_distance := float(b.get("travel_distance", INF))
	if is_equal_approx(a_distance, b_distance):
		return int(a.get("sample_index", 0)) < int(b.get("sample_index", 0))
	return a_distance < b_distance


func _profile_friendly_ranged_attack_position(result: Dictionary, started_usec: int, measured: bool) -> Dictionary:
	if measured:
		_performance_probe.record("friendly_ranged_position_ms", Time.get_ticks_usec() - started_usec)
	return result


func _is_friendly_attack_path_clear(npc_id: String, target: Dictionary, weapon_id: String) -> bool:
	if target.is_empty():
		return false
	var origin := _get_npc_position(npc_id) + Vector3.UP * PROJECTILE_TARGET_HEIGHT_ENEMY_FOOT
	var destination: Vector3 = target.get("position", origin)
	destination.y = origin.y
	if _is_ranged_weapon_type(weapon_id):
		var release := _get_projectile_release_descriptor("friendly", npc_id, weapon_id)
		if bool(release.get("ready", false)) and release.get("transform") is Transform3D:
			origin = (release.get("transform") as Transform3D).origin
		destination = _get_projectile_target_aim_position(target)
	return _is_static_attack_segment_clear(npc_id, origin, destination)


func _is_friendly_attack_path_clear_from_position(
	npc_id: String,
	origin_ground: Vector3,
	target: Dictionary,
	weapon_id: String
) -> bool:
	var current_ground := _get_npc_position(npc_id)
	var origin_height := _get_friendly_attack_origin_height(npc_id, weapon_id, current_ground)
	var origin := origin_ground + Vector3.UP * origin_height
	var destination := _get_projectile_target_aim_position(target)
	return _is_static_attack_segment_clear(npc_id, origin, destination)


func _get_friendly_attack_origin_height(npc_id: String, weapon_id: String, current_ground: Vector3) -> float:
	var origin_height := PROJECTILE_TARGET_HEIGHT_ENEMY_FOOT
	if _is_ranged_weapon_type(weapon_id):
		var release := _get_projectile_release_descriptor("friendly", npc_id, weapon_id)
		if bool(release.get("ready", false)) and release.get("transform") is Transform3D:
			origin_height = maxf(0.1, (release.get("transform") as Transform3D).origin.y - current_ground.y)
	return origin_height


func _get_friendly_attack_segment_exclusions(npc_id: String) -> Array[RID]:
	var excluded: Array[RID] = []
	var shooter_rid := _get_projectile_shooter_rid("friendly", npc_id)
	if shooter_rid.is_valid():
		excluded.append(shooter_rid)
	return excluded


func _is_static_attack_segment_clear(npc_id: String, origin: Vector3, destination: Vector3) -> bool:
	return _is_static_attack_segment_clear_with_exclusions(
		origin,
		destination,
		_get_friendly_attack_segment_exclusions(npc_id)
	)


func _is_static_attack_segment_clear_with_exclusions(
	origin: Vector3,
	destination: Vector3,
	excluded: Array[RID]
) -> bool:
	if origin.distance_to(destination) <= 0.05:
		return true
	var world := get_viewport().world_3d
	if world == null:
		return true
	# Layer 1 is formal world-static geometry. Same-side actors and the target
	# remain outside this probe so a crowd overlap is not mistaken for a wall.
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1, excluded)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = false
	return world.direct_space_state.intersect_ray(query).is_empty()


func _constrain_combat_strategy_position(position: Vector3, npc_id: String = "") -> Vector3:
	# Constrain against the navigation map that actually owns this NPC. Debug
	# formal waves use the same production world without setting
	# _default_formal_wave_active; the old mode flag therefore sent valid
	# warehouse targets through the legacy [-14, 14] / [-12.5, 18.5] clamp.
	# That produced a perfectly completed request to a point ten metres away from
	# the enemy and left the combatant repeatedly "moving" toward the wrong edge.
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		not npc_id.is_empty()
		and npc_system != null
		and npc_system.has_method("get_npc_navigation_closest_point")
	):
		var navigation_position: Variant = npc_system.get_npc_navigation_closest_point(npc_id, position)
		if navigation_position is Vector3:
			return navigation_position
	return Vector3(
		clampf(position.x, COMBAT_STRATEGY_MIN_X, COMBAT_STRATEGY_MAX_X),
		0.0,
		clampf(position.z, COMBAT_STRATEGY_MIN_Z, COMBAT_STRATEGY_MAX_Z)
	)


func _calculate_npc_attack_context(
	npc_id: String,
	npc: Dictionary,
	state: Dictionary,
	npc_system: Node = null
) -> Dictionary:
	var weapon := _get_npc_main_weapon(npc)
	if weapon.is_empty():
		return {}
	var resolved_npc_system := npc_system if npc_system != null else get_node_or_null(NPC_SYSTEM_PATH)
	var combat_stats := (
		_calculate_npc_combat_stats_from_profile(npc_id, npc, state, resolved_npc_system)
		if resolved_npc_system != null
		else {}
	)
	if combat_stats.is_empty():
		return {}
	var final_stats: Dictionary = combat_stats.get("final", {})
	var condition: Dictionary = combat_stats.get("condition", {})
	var required_skill := str(weapon.get("required_skill", weapon.get("weapon_class", "")))
	var weapon_skill := _get_npc_skill_value(npc, required_skill)
	var strength := _get_npc_stat_value(npc, "strength", int(STRENGTH_ATTACK_BASELINE))
	var base_damage := maxf(1.0, float(weapon.get("damage", 1.0)))
	var strength_multiplier := float(condition.get("strength_multiplier", 1.0))
	var morale_attack_bonus := float(condition.get("morale_attack_bonus", 0.0))
	var raw_attack_power := maxf(1.0, float(final_stats.get("attack_power", base_damage)))
	var attack_speed_multiplier := maxf(
		MIN_ATTACK_SPEED_MULTIPLIER,
		float(final_stats.get("attack_speed_multiplier", 1.0))
	)
	var base_interval := maxf(0.1, float(weapon.get("attack_interval", 1.8)))
	var attack_interval := maxf(
		MIN_NPC_ATTACK_INTERVAL,
		float(final_stats.get("attack_interval", base_interval / attack_speed_multiplier))
	)
	var mounted := bool(state.get("combat_mounted", false))
	var animation_timing := COMBAT_ANIMATION_TIMING.get_timing(str(weapon.get("id", "")), attack_interval, mounted)
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
		"defense": maxf(0.0, float(final_stats.get("defense", 0.0))),
		"penetration": maxf(0.0, float(final_stats.get("penetration", 0.0))),
		"base_attack_interval": base_interval,
		"attack_speed_multiplier": attack_speed_multiplier,
		"attack_speed": maxf(0.01, float(final_stats.get("attack_speed", 1.0 / attack_interval))),
		"attack_interval": attack_interval,
		"mounted": mounted,
		"animation_timing": animation_timing,
		"attack_impact_ratio": float(animation_timing.get("impact_ratio", 0.5)),
		"attack_impact_seconds": float(animation_timing.get("impact_seconds", attack_interval * 0.5)),
		"attack_playback_multiplier": float(animation_timing.get("playback_multiplier", 1.0)),
		"range": maxf(0.1, float(final_stats.get("range", weapon.get("range", 1.5)))),
		"combat_level": int(combat_stats.get("level", 1)),
		"combat_stats": combat_stats
	}


func _calculate_npc_condition_attack_speed_multiplier(state: Dictionary) -> float:
	var multiplier := 1.0
	var fatigue := clampf(float(state.get("fatigue", 0.0)), 0.0, 100.0)
	if fatigue > FATIGUE_ATTACK_SPEED_PENALTY_START:
		var fatigue_ratio := (fatigue - FATIGUE_ATTACK_SPEED_PENALTY_START) / (100.0 - FATIGUE_ATTACK_SPEED_PENALTY_START)
		multiplier *= 1.0 - clampf(fatigue_ratio, 0.0, 1.0) * FATIGUE_ATTACK_SPEED_MAX_PENALTY
	var satiety := clampf(float(state.get("satiety", 100.0)), 0.0, 100.0)
	if satiety < SATIETY_ATTACK_SPEED_PENALTY_START:
		var satiety_ratio := (SATIETY_ATTACK_SPEED_PENALTY_START - satiety) / SATIETY_ATTACK_SPEED_PENALTY_START
		multiplier *= 1.0 - clampf(satiety_ratio, 0.0, 1.0) * SATIETY_ATTACK_SPEED_MAX_PENALTY
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


func _resolve_npc_melee_contact(
	npc_id: String,
	npc: Dictionary,
	locked_target: Dictionary,
	attack_context: Dictionary
) -> Dictionary:
	var weapon_type := str(attack_context.get("weapon_id", ""))
	var swing_key := _melee_swing_key("friendly", npc_id)
	var swing_before: Dictionary = _active_melee_swings.get(swing_key, {}) if _active_melee_swings.get(swing_key, {}) is Dictionary else {}
	var committed_result: Dictionary = swing_before.get("committed_attack_result", {}) if swing_before.get("committed_attack_result", {}) is Dictionary else {}
	var contact := _resolve_melee_contact_geometry("friendly", npc_id, weapon_type, locked_target)
	if committed_result.is_empty() and contact.get("committed_attack_result", {}) is Dictionary:
		committed_result = (contact.get("committed_attack_result", {}) as Dictionary).duplicate(true)
	contact.erase("committed_attack_result")
	var actual_enemy_id := str(contact.get("actual_target_id", ""))
	var result := {
		"attacker_npc_id": npc_id,
		"attacker_name": str(npc.get("name", npc_id)),
		"target_enemy_id": str(locked_target.get("id", "")),
		"target_enemy_name": str(locked_target.get("name", locked_target.get("id", ""))),
		"actual_target_enemy_id": actual_enemy_id,
		"weapon_id": weapon_type,
		"damage": 0,
		"damage_result": {},
		"event": {},
		"melee_status": str(contact.get("status", "miss")),
		"melee_contact": contact
	}
	if not committed_result.is_empty():
		result = committed_result.duplicate(true)
		result["melee_contact"] = contact
		result["melee_status"] = str(contact.get("status", "hit"))
	elif str(contact.get("status", "")) == "hit" and _active_enemies.has(actual_enemy_id):
		var actual_target: Dictionary = (_active_enemies.get(actual_enemy_id, {}) as Dictionary).duplicate(true)
		var damage_result := _apply_npc_attack_to_enemy(npc_id, npc, actual_target, attack_context)
		for key in damage_result:
			result[key] = damage_result[key]
		result["target_enemy_id"] = str(locked_target.get("id", ""))
		result["target_enemy_name"] = str(locked_target.get("name", locked_target.get("id", "")))
		result["actual_target_enemy_id"] = actual_enemy_id
	contact["damage_result"] = (result.get("damage_result", {}) as Dictionary).duplicate(true)
	_last_melee_contact_result = contact.duplicate(true)
	return result


func _resolve_npc_locked_actor_melee_impact(
	npc_id: String,
	npc: Dictionary,
	locked_target: Dictionary,
	attack_context: Dictionary
) -> Dictionary:
	var target_enemy_id := str(locked_target.get("id", ""))
	if target_enemy_id.is_empty() or not _active_enemies.has(target_enemy_id):
		_active_melee_swings.erase(_melee_swing_key("friendly", npc_id))
		_pending_melee_damage_commits.erase(_melee_swing_key("friendly", npc_id))
		return {}
	var live_target := _make_enemy_attack_target(target_enemy_id, _get_npc_position(npc_id))
	if live_target.is_empty():
		_active_melee_swings.erase(_melee_swing_key("friendly", npc_id))
		_pending_melee_damage_commits.erase(_melee_swing_key("friendly", npc_id))
		return {}
	var swing_key := _melee_swing_key("friendly", npc_id)
	var contact := _build_locked_actor_melee_impact_contact(
		"friendly",
		npc_id,
		str(attack_context.get("weapon_id", "")),
		live_target,
		"enemy",
		target_enemy_id
	)
	var result := _apply_npc_attack_to_enemy(npc_id, npc, live_target, attack_context)
	if result.is_empty():
		_active_melee_swings.erase(swing_key)
		_pending_melee_damage_commits.erase(swing_key)
		return {}
	result["actual_target_enemy_id"] = target_enemy_id
	result["weapon_id"] = str(attack_context.get("weapon_id", ""))
	result["melee_status"] = "hit"
	result["melee_contact"] = contact.duplicate(true)
	contact["damage_result"] = (result.get("damage_result", {}) as Dictionary).duplicate(true)
	_last_melee_contact_result = contact.duplicate(true)
	_pending_melee_damage_commits.erase(swing_key)
	_active_melee_swings.erase(swing_key)
	return result


func _resolve_enemy_locked_actor_melee_impact(enemy: Dictionary, locked_target: Dictionary) -> Dictionary:
	var enemy_id := str(enemy.get("id", ""))
	var npc_id := str(locked_target.get("id", ""))
	var swing_key := _melee_swing_key("enemy", enemy_id)
	if npc_id.is_empty() or _is_target_defeated({"type": "npc", "id": npc_id}):
		_active_melee_swings.erase(swing_key)
		_pending_melee_damage_commits.erase(swing_key)
		return {}
	var live_target := _make_npc_enemy_target(npc_id, enemy.get("position", Vector3.ZERO))
	if live_target.is_empty():
		_active_melee_swings.erase(swing_key)
		_pending_melee_damage_commits.erase(swing_key)
		return {}
	var weapon_type := str(enemy.get("weapon_type", ""))
	var contact := _build_locked_actor_melee_impact_contact(
		"enemy",
		enemy_id,
		weapon_type,
		live_target,
		"npc",
		npc_id
	)
	var raw_attack_power := maxf(1.0, float(enemy.get("attack_power", 1.0)))
	var penetration := maxf(0.0, float(enemy.get("penetration", 0.0)))
	var target_defense := _calculate_npc_defense(npc_id)
	var resolution := calculate_damage_resolution(raw_attack_power, target_defense, penetration)
	var result := _apply_enemy_attack_to_npc(
		enemy,
		npc_id,
		int(resolution.get("damage", 1)),
		raw_attack_power,
		target_defense,
		penetration,
		float(resolution.get("effective_defense", target_defense))
	)
	if result.is_empty():
		_active_melee_swings.erase(swing_key)
		_pending_melee_damage_commits.erase(swing_key)
		return {}
	result["enemy_id"] = enemy_id
	result["target_type"] = "npc"
	result["target_id"] = npc_id
	result["actual_target_type"] = "npc"
	result["actual_target_id"] = npc_id
	result["weapon_id"] = weapon_type
	result["melee_status"] = "hit"
	result["melee_contact"] = contact.duplicate(true)
	contact["damage_result"] = (result.get("result", {}) as Dictionary).duplicate(true)
	_last_melee_contact_result = contact.duplicate(true)
	_pending_melee_damage_commits.erase(swing_key)
	_active_melee_swings.erase(swing_key)
	return result


func _build_locked_actor_melee_impact_contact(
	source_side: String,
	source_id: String,
	weapon_type: String,
	locked_target: Dictionary,
	actual_target_type: String,
	actual_target_id: String
) -> Dictionary:
	var swing_key := _melee_swing_key(source_side, source_id)
	var swing: Dictionary = _active_melee_swings.get(swing_key, {}) if _active_melee_swings.get(swing_key, {}) is Dictionary else {}
	var sampled_contact: Dictionary = swing.get("terminal_contact", {}) if swing.get("terminal_contact", {}) is Dictionary else {}
	return {
		"status": "hit",
		"reason": "locked_actor_impact_phase",
		"source_side": source_side,
		"source_id": source_id,
		"weapon_type": weapon_type,
		"locked_target": _serialize_target(locked_target),
		"actual_target_type": actual_target_type,
		"actual_target_id": actual_target_id,
		"sample_count": int(swing.get("sample_count", 0)),
		"model_max_horizontal_reach": float(swing.get("model_max_horizontal_reach", 0.0)),
		"sampled_model_contact": sampled_contact.duplicate(true),
		"impact_authority": "locked_actor_timeline",
		"range_rechecked_at_impact": false
	}


func _resolve_enemy_melee_contact(enemy: Dictionary, locked_target: Dictionary) -> Dictionary:
	var enemy_id := str(enemy.get("id", ""))
	var weapon_type := str(enemy.get("weapon_type", ""))
	var swing_key := _melee_swing_key("enemy", enemy_id)
	var swing_before: Dictionary = _active_melee_swings.get(swing_key, {}) if _active_melee_swings.get(swing_key, {}) is Dictionary else {}
	var committed_result: Dictionary = swing_before.get("committed_attack_result", {}) if swing_before.get("committed_attack_result", {}) is Dictionary else {}
	var contact := _resolve_melee_contact_geometry("enemy", enemy_id, weapon_type, locked_target)
	if committed_result.is_empty() and contact.get("committed_attack_result", {}) is Dictionary:
		committed_result = (contact.get("committed_attack_result", {}) as Dictionary).duplicate(true)
	contact.erase("committed_attack_result")
	var result := {
		"enemy_id": enemy_id,
		"enemy_name": str(enemy.get("name", enemy_id)),
		"target_type": str(locked_target.get("type", "")),
		"target_id": str(locked_target.get("id", "")),
		"actual_target_type": str(contact.get("actual_target_type", "")),
		"actual_target_id": str(contact.get("actual_target_id", "")),
		"weapon_id": weapon_type,
		"damage": 0,
		"damage_result": {},
		"melee_status": str(contact.get("status", "miss")),
		"melee_contact": contact
	}
	if not committed_result.is_empty():
		result = committed_result.duplicate(true)
		result["melee_contact"] = contact
		result["melee_status"] = str(contact.get("status", "hit"))
		_last_melee_contact_result = contact.duplicate(true)
		return result
	if str(contact.get("status", "")) != "hit":
		_last_melee_contact_result = contact.duplicate(true)
		return result
	var actual_type := str(contact.get("actual_target_type", ""))
	var actual_id := str(contact.get("actual_target_id", ""))
	var damage_result := _apply_enemy_melee_contact_damage(enemy, locked_target, contact)
	if not damage_result.is_empty():
		result = damage_result.duplicate(true)
		result["enemy_id"] = enemy_id
		result["target_type"] = str(locked_target.get("type", ""))
		result["target_id"] = str(locked_target.get("id", ""))
		result["actual_target_type"] = actual_type
		result["actual_target_id"] = actual_id
		result["weapon_id"] = weapon_type
		result["melee_status"] = "hit"
		result["melee_contact"] = contact
	contact["damage_result"] = damage_result.duplicate(true)
	_last_melee_contact_result = contact.duplicate(true)
	return result


func _resolve_melee_contact_geometry(
	source_side: String,
	source_id: String,
	weapon_type: String,
	locked_target: Dictionary
) -> Dictionary:
	var config := _get_weapon_melee_contact_config(weapon_type)
	var swing_key := _melee_swing_key(source_side, source_id)
	if not _active_melee_swings.has(swing_key):
		_begin_melee_swing(source_side, source_id, weapon_type, locked_target, -1)
	_sample_melee_swing(swing_key)
	var swing: Dictionary = _active_melee_swings.get(swing_key, {}) if _active_melee_swings.get(swing_key, {}) is Dictionary else {}
	var terminal_contact: Dictionary = swing.get("terminal_contact", {}) if swing.get("terminal_contact", {}) is Dictionary else {}
	var result := {
		"status": "miss",
		"reason": "no_contact" if int(swing.get("sample_count", 0)) > 0 else "melee_geometry_unavailable",
		"source_side": source_side,
		"source_id": source_id,
		"weapon_type": weapon_type,
		"locked_target": _serialize_target(locked_target),
		"actual_target_type": "",
		"actual_target_id": "",
		"sample_count": int(swing.get("sample_count", 0)),
		"contact_radius": float(config.get("radius", 0.1)),
		"model_max_horizontal_reach": float(swing.get("model_max_horizontal_reach", 0.0)),
		"contact_window_start_authored_seconds": float(swing.get("contact_window_start_authored_seconds", 0.0)),
		"impact_authored_seconds": float(swing.get("impact_authored_seconds", 0.0)),
		"geometry_source": "formal_character_model" if int(swing.get("sample_count", 0)) > 0 else "unavailable"
	}
	for key in terminal_contact:
		result[key] = terminal_contact[key]
	var committed_result: Dictionary = swing.get("committed_attack_result", {}) if swing.get("committed_attack_result", {}) is Dictionary else {}
	if not committed_result.is_empty():
		result["committed_attack_result"] = committed_result.duplicate(true)
	_active_melee_swings.erase(swing_key)
	return result


func _get_weapon_melee_contact_config(weapon_type: String) -> Dictionary:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_weapon_def"):
		return {}
	var weapon: Dictionary = equipment_system.get_weapon_def(weapon_type)
	var contact: Dictionary = weapon.get("melee_contact", {}) if weapon.get("melee_contact", {}) is Dictionary else {}
	return contact.duplicate(true)


func _get_model_calibrated_melee_range(weapon_type: String, fallback: float) -> float:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_weapon_def"):
		return maxf(0.1, fallback)
	var weapon: Dictionary = equipment_system.get_weapon_def(weapon_type)
	return maxf(0.1, float(weapon.get("range", fallback)))


func _is_melee_source_mounted(source_side: String, source_id: String) -> bool:
	if source_side == "friendly":
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system != null and npc_system.has_method("get_npc_state"):
			return bool((npc_system.get_npc_state(source_id) as Dictionary).get("combat_mounted", false))
		return false
	var enemy: Dictionary = _active_enemies.get(source_id, {}) if _active_enemies.get(source_id, {}) is Dictionary else {}
	return str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"]


func get_active_melee_swing_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for raw_key in _active_melee_swings.keys():
		var swing: Dictionary = _active_melee_swings.get(raw_key, {}) if _active_melee_swings.get(raw_key, {}) is Dictionary else {}
		snapshots.append({
			"swing_key": str(raw_key),
			"source_side": str(swing.get("source_side", "")),
			"source_id": str(swing.get("source_id", "")),
			"weapon_type": str(swing.get("weapon_type", "")),
			"sequence": int(swing.get("sequence", -1)),
			"impact_authority": str(swing.get("impact_authority", "model_contact")),
			"sample_count": int(swing.get("sample_count", 0)),
			"model_max_horizontal_reach": float(swing.get("model_max_horizontal_reach", 0.0)),
			"terminal_contact": (swing.get("terminal_contact", {}) as Dictionary).duplicate(true),
		})
	snapshots.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("swing_key", "")) < str(right.get("swing_key", ""))
	)
	return snapshots


func _melee_swing_key(source_side: String, source_id: String) -> String:
	return "%s:%s" % [source_side, source_id]


func _begin_melee_swing(
	source_side: String,
	source_id: String,
	weapon_type: String,
	locked_target: Dictionary,
	sequence: int,
	attack_context: Dictionary = {},
	is_charge_impact: bool = false
) -> void:
	if not weapon_type in MELEE_WEAPON_TYPES:
		return
	var config := _get_weapon_melee_contact_config(weapon_type)
	var timing := COMBAT_ANIMATION_TIMING.get_timing(weapon_type, 1.0, _is_melee_source_mounted(source_side, source_id))
	var impact_authored_seconds := float(timing.get("impact_authored_seconds", 0.0))
	var window := maxf(0.0, float(config.get("sample_window_authored_seconds", 0.22)))
	var excluded_rids: Array[RID] = []
	var shooter_rid := _get_projectile_shooter_rid(source_side, source_id)
	if shooter_rid.is_valid():
		excluded_rids.append(shooter_rid)
	_active_melee_swings[_melee_swing_key(source_side, source_id)] = {
		"source_side": source_side,
		"source_id": source_id,
		"weapon_type": weapon_type,
		"sequence": sequence,
		"locked_target": locked_target.duplicate(true),
		"attack_context": attack_context.duplicate(true),
		"is_charge_impact": is_charge_impact,
		"impact_authority": (
			"locked_actor_timeline"
			if not is_charge_impact and (
				(source_side == "friendly" and str(locked_target.get("type", "")) == "enemy")
				or (source_side == "enemy" and str(locked_target.get("type", "")) == "npc")
			)
			else "model_contact"
		),
		"contact_radius": maxf(0.01, float(config.get("radius", 0.1))),
		"contact_window_start_authored_seconds": maxf(0.0, impact_authored_seconds - window),
		"impact_authored_seconds": impact_authored_seconds,
		"desired_sample_count": maxi(2, int(config.get("sample_count", 7))),
		"last_sample_authored_seconds": -1.0,
		"previous_sample": {},
		"terminal_contact": {},
		"sample_count": 0,
		"model_max_horizontal_reach": 0.0,
		"committed_attack_result": {},
		"damage_committed": false,
		"excluded_rids": excluded_rids
	}
	var source_position: Variant = (
		_get_npc_position(source_id)
		if source_side == "friendly"
		else get_enemy_world_position(source_id)
	)
	_emit_combat_audio_event({
		"event_type": "attack_swing",
		"source_side": source_side,
		"source_id": source_id,
		"weapon_type": weapon_type,
		"attack_sequence": sequence,
		"world_position": source_position if source_position is Vector3 else Vector3.ZERO,
	})


func _sample_active_melee_swings() -> void:
	if _is_gameplay_paused():
		return
	for raw_key in _active_melee_swings.keys().duplicate():
		_sample_melee_swing(str(raw_key))


func _sample_melee_swing(swing_key: String) -> void:
	var swing: Dictionary = _active_melee_swings.get(swing_key, {}) if _active_melee_swings.get(swing_key, {}) is Dictionary else {}
	if swing.is_empty() or not (swing.get("terminal_contact", {}) as Dictionary).is_empty():
		return
	var source_side := str(swing.get("source_side", ""))
	var source_id := str(swing.get("source_id", ""))
	var weapon_type := str(swing.get("weapon_type", ""))
	var sample := _get_current_melee_contact_segment(source_side, source_id, weapon_type)
	if sample.is_empty() or not bool(sample.get("attack_visible", false)):
		return
	var authored_seconds := float(sample.get("authored_seconds", -1.0))
	if (
		authored_seconds + 0.0001 < float(swing.get("contact_window_start_authored_seconds", 0.0))
		or authored_seconds > float(swing.get("impact_authored_seconds", 0.0)) + 0.08
	):
		return
	var accepted_sample_count := int(swing.get("sample_count", 0))
	var desired_sample_count := maxi(2, int(swing.get("desired_sample_count", 7)))
	var contact_window_start := float(swing.get("contact_window_start_authored_seconds", 0.0))
	var impact_authored_seconds := float(swing.get("impact_authored_seconds", 0.0))
	var sample_interval := maxf(
		0.001,
		(impact_authored_seconds - contact_window_start) / float(desired_sample_count - 1)
	)
	var last_sample_authored_seconds := float(swing.get("last_sample_authored_seconds", -1.0))
	if (
		accepted_sample_count > 0
		and authored_seconds + 0.0001 < impact_authored_seconds
		and authored_seconds - last_sample_authored_seconds + 0.0001 < sample_interval
	):
		return
	var contact_start: Vector3 = sample.get("contact_start", Vector3.ZERO)
	var contact_end: Vector3 = sample.get("contact_end", contact_start)
	var source_origin := _get_melee_source_position(source_side, source_id)
	swing["model_max_horizontal_reach"] = maxf(
		float(swing.get("model_max_horizontal_reach", 0.0)),
		maxf(
			_horizontal_vector_distance(source_origin, contact_start),
			_horizontal_vector_distance(source_origin, contact_end)
		)
	)
	var previous_sample: Dictionary = swing.get("previous_sample", {}) if swing.get("previous_sample", {}) is Dictionary else {}
	var sweep_segments: Array[Dictionary] = [
		{"from": contact_start, "to": contact_end, "kind": "weapon"}
	]
	if not previous_sample.is_empty():
		var previous_start: Vector3 = previous_sample.get("contact_start", contact_start)
		var previous_end: Vector3 = previous_sample.get("contact_end", contact_end)
		for blade_weight in [1.0, 0.5]:
			sweep_segments.append({
				"from": previous_start.lerp(previous_end, blade_weight),
				"to": contact_start.lerp(contact_end, blade_weight),
				"kind": "motion"
			})
	for segment in sweep_segments:
		var segment_start: Vector3 = segment.get("from", contact_start)
		var segment_end: Vector3 = segment.get("to", contact_end)
		var contact := _query_melee_segment_contact(
			segment_start,
			segment_end,
			float(swing.get("contact_radius", 0.1)),
			swing.get("excluded_rids", []) as Array[RID],
			source_side,
			swing.get("locked_target", {}) as Dictionary
		)
		if contact.is_empty():
			continue
		contact["authored_seconds"] = authored_seconds
		contact["sweep_kind"] = str(segment.get("kind", "weapon"))
		swing["terminal_contact"] = contact
		break
	swing["previous_sample"] = sample.duplicate(true)
	swing["last_sample_authored_seconds"] = authored_seconds
	swing["sample_count"] = int(swing.get("sample_count", 0)) + 1
	_active_melee_swings[swing_key] = swing
	if (
		str(swing.get("impact_authority", "model_contact")) == "model_contact"
		and str((swing.get("terminal_contact", {}) as Dictionary).get("status", "")) == "hit"
	):
		if not _pending_melee_damage_commits.has(swing_key):
			_pending_melee_damage_commits.append(swing_key)


func _commit_pending_melee_contact_damage() -> void:
	if _is_gameplay_paused():
		return
	var pending := _pending_melee_damage_commits.duplicate()
	_pending_melee_damage_commits.clear()
	for swing_key in pending:
		_commit_melee_contact_damage(swing_key)


func _get_current_melee_contact_segment(source_side: String, source_id: String, weapon_type: String) -> Dictionary:
	if source_side == "friendly":
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system != null and npc_system.has_method("get_npc_combat_melee_contact_segment"):
			return npc_system.get_npc_combat_melee_contact_segment(source_id, weapon_type)
		return {}
	var enemy_node := get_node_or_null(_enemy_nodes.get(source_id, NodePath())) as Node3D if _enemy_nodes.has(source_id) else null
	var art_view := enemy_node.get_node_or_null("EnemyArtView") as Node3D if enemy_node != null else null
	if art_view != null and art_view.has_method("get_combat_melee_contact_segment"):
		return art_view.get_combat_melee_contact_segment(weapon_type)
	return {}


func _commit_melee_contact_damage(swing_key: String) -> void:
	var swing: Dictionary = _active_melee_swings.get(swing_key, {}) if _active_melee_swings.get(swing_key, {}) is Dictionary else {}
	if swing.is_empty() or bool(swing.get("damage_committed", false)):
		return
	var contact: Dictionary = swing.get("terminal_contact", {}) if swing.get("terminal_contact", {}) is Dictionary else {}
	if str(contact.get("status", "")) != "hit":
		return
	var source_side := str(swing.get("source_side", ""))
	var source_id := str(swing.get("source_id", ""))
	var locked_target: Dictionary = swing.get("locked_target", {}) if swing.get("locked_target", {}) is Dictionary else {}
	var result := {}
	if source_side == "friendly":
		var actual_enemy_id := str(contact.get("actual_target_id", ""))
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system == null or not _active_enemies.has(actual_enemy_id):
			return
		var npc: Dictionary = npc_system.get_npc(source_id)
		var state: Dictionary = npc_system.get_npc_state(source_id)
		var attack_context: Dictionary = swing.get("attack_context", {}) if swing.get("attack_context", {}) is Dictionary else {}
		if attack_context.is_empty():
			attack_context = _calculate_npc_attack_context(source_id, npc, state)
		if attack_context.is_empty():
			return
		var actual_target: Dictionary = (_active_enemies.get(actual_enemy_id, {}) as Dictionary).duplicate(true)
		var charge_impact := {}
		if bool(swing.get("is_charge_impact", false)):
			charge_impact = _apply_cavalry_charge_impact(source_id, npc, actual_target, attack_context)
			if charge_impact.is_empty():
				return
			var charged_attack_context := attack_context.duplicate(true)
			charged_attack_context["raw_attack_power"] = (
				float(attack_context.get("raw_attack_power", 1.0))
				* maxf(1.0, float(charge_impact.get("weapon_damage_multiplier", 1.0)))
			)
			charged_attack_context["attack_power"] = maxi(
				1,
				int(round(float(charged_attack_context.get("raw_attack_power", 1.0))))
			)
			charged_attack_context["charge_impact"] = charge_impact.duplicate(true)
			attack_context = charged_attack_context
		if _active_enemies.has(actual_enemy_id):
			attack_context["hit_world_position"] = WorldFeedbackPayload.find_world_position(
				contact.get("collision_identity", {}) if contact.get("collision_identity", {}) is Dictionary else {}
			)
			result = _apply_npc_attack_to_enemy(source_id, npc, actual_target, attack_context)
		elif not charge_impact.is_empty():
			result = {
				"attacker_npc_id": source_id,
				"attacker_name": str(npc.get("name", source_id)),
				"target_enemy_id": actual_enemy_id,
				"target_enemy_name": str(actual_target.get("name", actual_enemy_id)),
				"source_type": "horse_collision",
				"damage": int(charge_impact.get("collision_damage", 0)),
				"damage_result": (charge_impact.get("collision_damage_result", {}) as Dictionary).duplicate(true),
				"event": {}
			}
		if not charge_impact.is_empty():
			result["charge_impact"] = charge_impact.duplicate(true)
			_update_npc_charge_phase(source_id, CHARGE_PHASE_WITHDRAW, charge_impact)
		result["target_enemy_id"] = str(locked_target.get("id", ""))
		result["target_enemy_name"] = str(locked_target.get("name", locked_target.get("id", "")))
		result["actual_target_enemy_id"] = actual_enemy_id
		result["weapon_id"] = str(swing.get("weapon_type", ""))
		result["melee_status"] = "hit"
		result["melee_contact"] = contact.duplicate(true)
	else:
		var enemy: Dictionary = _active_enemies.get(source_id, {}) if _active_enemies.get(source_id, {}) is Dictionary else {}
		if enemy.is_empty():
			return
		var damage_result := _apply_enemy_melee_contact_damage(enemy, locked_target, contact)
		if damage_result.is_empty():
			return
		result = damage_result.duplicate(true)
		result["enemy_id"] = source_id
		result["target_type"] = str(locked_target.get("type", ""))
		result["target_id"] = str(locked_target.get("id", ""))
		result["actual_target_type"] = str(contact.get("actual_target_type", ""))
		result["actual_target_id"] = str(contact.get("actual_target_id", ""))
		result["weapon_id"] = str(swing.get("weapon_type", ""))
		result["melee_status"] = "hit"
		result["melee_contact"] = contact.duplicate(true)
	contact["damage_result"] = (result.get("damage_result", result) as Dictionary).duplicate(true)
	swing["terminal_contact"] = contact
	swing["committed_attack_result"] = result.duplicate(true)
	swing["damage_committed"] = true
	_active_melee_swings[swing_key] = swing
	_last_melee_contact_result = contact.duplicate(true)


func _apply_enemy_melee_contact_damage(
	enemy: Dictionary,
	locked_target: Dictionary,
	contact: Dictionary
) -> Dictionary:
	var raw_attack_power := maxf(1.0, float(enemy.get("attack_power", 1.0)))
	var penetration := maxf(0.0, float(enemy.get("penetration", 0.0)))
	var actual_type := str(contact.get("actual_target_type", ""))
	var actual_id := str(contact.get("actual_target_id", ""))
	match actual_type:
		"npc":
			var target_defense := _calculate_npc_defense(actual_id)
			var resolution := calculate_damage_resolution(raw_attack_power, target_defense, penetration)
			return _apply_enemy_attack_to_npc(
				enemy,
				actual_id,
				int(resolution.get("damage", 1)),
				raw_attack_power,
				target_defense,
				penetration,
				float(resolution.get("effective_defense", target_defense))
			)
		"defense_device":
			var device_defense := maxf(0.0, float(locked_target.get("defense", 0.0)))
			var resolution := calculate_damage_resolution(raw_attack_power, device_defense, penetration)
			return _apply_enemy_attack_to_defense_device(
				enemy,
				actual_id,
				int(resolution.get("damage", 1)),
				resolution,
				{
					"host_proxy_id": str(locked_target.get("attack_host_proxy_region_id", locked_target.get("host_proxy_id", ""))),
					"collision_identity": contact.get("collision_identity", {}).duplicate(true) if contact.get("collision_identity", {}) is Dictionary else {},
					"hit_world_position": WorldFeedbackPayload.find_world_position(
						contact.get("collision_identity", {}) if contact.get("collision_identity", {}) is Dictionary else {}
					)
				}
			)
		"building":
			return _apply_enemy_attack_to_building(
				enemy,
				actual_id,
				maxi(1, int(round(raw_attack_power))),
				{
					"hit_world_position": WorldFeedbackPayload.find_world_position(
						contact.get("collision_identity", {}) if contact.get("collision_identity", {}) is Dictionary else {}
					)
				}
			)
	return {}


func _get_melee_source_position(source_side: String, source_id: String) -> Vector3:
	if source_side == "friendly":
		return _get_npc_position(source_id)
	var enemy_node := get_node_or_null(_enemy_nodes.get(source_id, NodePath())) as Node3D if _enemy_nodes.has(source_id) else null
	if enemy_node != null:
		return enemy_node.global_position
	var enemy: Dictionary = _active_enemies.get(source_id, {}) if _active_enemies.get(source_id, {}) is Dictionary else {}
	return enemy.get("position", Vector3.ZERO)


func _query_melee_segment_contact(
	segment_start: Vector3,
	segment_end: Vector3,
	radius: float,
	excluded_rids: Array[RID],
	source_side: String,
	locked_target: Dictionary
) -> Dictionary:
	var segment := segment_end - segment_start
	var length := segment.length()
	if length <= 0.0001:
		return {}
	var capsule := CapsuleShape3D.new()
	capsule.radius = maxf(0.01, radius)
	capsule.height = maxf(capsule.radius * 2.0, length + capsule.radius * 2.0)
	var direction := segment / length
	var reference := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis_x := reference.cross(direction).normalized()
	var basis_z := basis_x.cross(direction).normalized()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(basis_x, direction, basis_z), segment_start.lerp(segment_end, 0.5))
	query.collision_mask = MELEE_COLLISION_MASK
	if (
		source_side == "enemy"
		and str(locked_target.get("type", "")) == "building"
		and str(locked_target.get("id", "")) == "front_gate"
	):
		query.collision_mask |= ENEMY_GATE_COMBAT_CONTACT_LAYER
	query.exclude = excluded_rids
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var world := get_viewport().world_3d
	if world == null:
		return {}
	var hits := world.direct_space_state.intersect_shape(query, 32)
	hits.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _melee_collider_sort_distance(left.get("collider"), segment_start) < _melee_collider_sort_distance(right.get("collider"), segment_start)
	)
	for hit in hits:
		var collision_position := _closest_point_on_segment_to_collider(
			segment_start,
			segment_end,
			hit.get("collider")
		)
		var classification := _classify_melee_collider(
			source_side,
			locked_target,
			hit.get("collider"),
			collision_position
		)
		if str(classification.get("status", "ignore")) == "ignore":
			continue
		classification["collision_position"] = collision_position
		return classification
	return {}


func _classify_melee_collider(
	source_side: String,
	locked_target: Dictionary,
	collider: Variant,
	collision_position: Vector3 = Vector3.INF
) -> Dictionary:
	var identity := _extract_projectile_collision_identity(collider)
	if str(identity.get("collision_category", "")) in MELEE_IGNORED_COLLISION_CATEGORIES:
		return {"status": "ignore", "reason": "non_combat_world_surface"}
	var collider_node := collider as Node
	var result := {
		"status": "blocked",
		"reason": "non_enemy_blocker" if source_side == "friendly" else "non_friendly_blocker",
		"collision_identity": identity,
		"collider_path": str(collider_node.get_path()) if collider_node != null and collider_node.is_inside_tree() else ""
	}
	if source_side == "friendly":
		var enemy_id := str(identity.get("enemy_id", ""))
		if not enemy_id.is_empty() and _active_enemies.has(enemy_id):
			result["status"] = "hit"
			result["reason"] = "actual_enemy_contact"
			result["actual_target_type"] = "enemy"
			result["actual_target_id"] = enemy_id
			return result
		if not str(identity.get("npc_id", "")).is_empty():
			return {"status": "ignore", "reason": "same_side_actor"}
	else:
		var npc_id := str(identity.get("npc_id", ""))
		if not npc_id.is_empty():
			result["status"] = "hit"
			result["reason"] = "actual_npc_contact"
			result["actual_target_type"] = "npc"
			result["actual_target_id"] = npc_id
			return result
		if not str(identity.get("enemy_id", "")).is_empty():
			return {"status": "ignore", "reason": "same_side_actor"}
	var intended_type := str(locked_target.get("type", ""))
	var intended_id := str(locked_target.get("id", ""))
	if intended_type == "defense_device":
		if _is_defense_device_proxy_contact(locked_target, identity, collision_position):
			result["status"] = "hit"
			result["reason"] = "actual_defense_host_proxy_contact"
			result["actual_target_type"] = "defense_device"
			result["actual_target_id"] = intended_id
			return result
	if intended_type == "building" and str(identity.get("building_id", "")) == intended_id:
		result["status"] = "hit"
		result["reason"] = "actual_building_contact"
		result["actual_target_type"] = "building"
		result["actual_target_id"] = intended_id
		return result
	return result


func _is_defense_device_proxy_contact(
	target: Dictionary,
	identity: Dictionary,
	collision_position: Vector3 = Vector3.INF
) -> bool:
	var deployment_id := str(target.get("id", ""))
	if not deployment_id.is_empty() and str(identity.get("deployment_id", "")) == deployment_id:
		return true
	for proxy in _get_defense_device_host_proxy_regions(target):
		if _is_single_defense_device_proxy_contact(target, proxy, identity, collision_position):
			return true
	return false


func _is_single_defense_device_proxy_contact(
	target: Dictionary,
	proxy: Dictionary,
	identity: Dictionary,
	collision_position: Vector3
) -> bool:
	var proxy_kind := str(proxy.get("kind", target.get("host_proxy_kind", "")))
	var building_id := str(proxy.get("building_id", target.get("building_id", "")))
	if building_id.is_empty() or str(identity.get("building_id", "")) != building_id:
		return false
	if proxy_kind == "legacy_host_building":
		return true
	var identity_matched := false
	var matched_fixture := false
	var wall_segment_id := str(proxy.get("wall_segment_id", target.get("host_proxy_wall_segment_id", "")))
	if not wall_segment_id.is_empty() and str(identity.get("wall_segment_id", "")) == wall_segment_id:
		identity_matched = true
	var building_segment_id := str(proxy.get("building_segment_id", target.get("host_proxy_building_segment_id", "")))
	if not building_segment_id.is_empty() and str(identity.get("building_segment_id", "")) == building_segment_id:
		identity_matched = true
	var fixture_id := str(proxy.get("fixture_id", target.get("host_proxy_fixture_id", "")))
	if not fixture_id.is_empty() and str(identity.get("fixture_id", "")) == fixture_id:
		identity_matched = true
		matched_fixture = true
	if not identity_matched:
		return false
	if collision_position == Vector3.INF:
		return true
	var raw_proxy_position: Variant = (
		proxy.get("fixture_aim_position", proxy.get("aim_position", target.get("aim_position", target.get("position", Vector3.ZERO))))
		if matched_fixture
		else proxy.get("aim_position", target.get("aim_position", target.get("position", Vector3.ZERO)))
	)
	var proxy_position: Vector3 = raw_proxy_position if raw_proxy_position is Vector3 else _vector3_from_dict(raw_proxy_position, Vector3.ZERO)
	var hit_radius := maxf(0.1, float(proxy.get("hit_radius", target.get("host_proxy_hit_radius", 2.0))))
	return _horizontal_vector_distance(collision_position, proxy_position) <= hit_radius


func _get_defense_device_host_proxy_regions(target: Dictionary) -> Array[Dictionary]:
	var proxy: Dictionary = target.get("host_proxy", {}) if target.get("host_proxy", {}) is Dictionary else {}
	var raw_regions: Variant = target.get("host_proxy_regions", proxy.get("regions", []))
	var regions: Array[Dictionary] = []
	if raw_regions is Array:
		for raw_region in raw_regions as Array:
			if not raw_region is Dictionary:
				continue
			var region := (raw_region as Dictionary).duplicate(true)
			region["kind"] = str(region.get("kind", proxy.get("kind", target.get("host_proxy_kind", ""))))
			region["id"] = str(region.get("id", proxy.get("id", target.get("host_proxy_id", ""))))
			region["building_id"] = str(region.get("building_id", proxy.get("building_id", target.get("building_id", ""))))
			region["slot_id"] = str(region.get("slot_id", proxy.get("slot_id", target.get("slot_id", ""))))
			region["wall_segment_id"] = str(region.get("wall_segment_id", ""))
			region["building_segment_id"] = str(region.get("building_segment_id", ""))
			region["fixture_id"] = str(region.get("fixture_id", proxy.get("fixture_id", target.get("host_proxy_fixture_id", ""))))
			region["position"] = _vector3_from_dict(region.get("position", target.get("position", Vector3.ZERO)), target.get("position", Vector3.ZERO))
			region["aim_position"] = _vector3_from_dict(region.get("aim_position", target.get("aim_position", region["position"])), region["position"])
			region["fixture_aim_position"] = _vector3_from_dict(region.get("fixture_aim_position", region["aim_position"]), region["aim_position"])
			region["outward_direction"] = _vector3_from_dict(
				region.get("outward_direction", target.get("host_proxy_outward_direction", target.get("facing_direction", Vector3.FORWARD))),
				Vector3.FORWARD
			)
			region["contact_radius"] = maxf(0.0, float(region.get("contact_radius", target.get("contact_radius", 0.0))))
			region["hit_radius"] = maxf(0.1, float(region.get("hit_radius", target.get("host_proxy_hit_radius", 2.0))))
			regions.append(region)
	if not regions.is_empty():
		return regions
	var fallback := proxy.duplicate(true)
	fallback.erase("regions")
	fallback["kind"] = str(fallback.get("kind", target.get("host_proxy_kind", "legacy_host_building")))
	fallback["id"] = str(fallback.get("id", target.get("host_proxy_id", "")))
	fallback["building_id"] = str(fallback.get("building_id", target.get("building_id", "")))
	fallback["slot_id"] = str(fallback.get("slot_id", target.get("slot_id", "")))
	fallback["wall_segment_id"] = str(fallback.get("wall_segment_id", target.get("host_proxy_wall_segment_id", "")))
	fallback["building_segment_id"] = str(fallback.get("building_segment_id", target.get("host_proxy_building_segment_id", "")))
	fallback["fixture_id"] = str(fallback.get("fixture_id", target.get("host_proxy_fixture_id", "")))
	fallback["position"] = _vector3_from_dict(fallback.get("position", target.get("position", Vector3.ZERO)), target.get("position", Vector3.ZERO))
	fallback["aim_position"] = _vector3_from_dict(fallback.get("aim_position", target.get("aim_position", fallback["position"])), fallback["position"])
	fallback["fixture_aim_position"] = _vector3_from_dict(fallback.get("fixture_aim_position", fallback["aim_position"]), fallback["aim_position"])
	fallback["outward_direction"] = _vector3_from_dict(
		fallback.get("outward_direction", target.get("host_proxy_outward_direction", target.get("facing_direction", Vector3.FORWARD))),
		Vector3.FORWARD
	)
	fallback["contact_radius"] = maxf(0.0, float(fallback.get("contact_radius", target.get("contact_radius", 0.0))))
	fallback["hit_radius"] = maxf(0.1, float(fallback.get("hit_radius", target.get("host_proxy_hit_radius", 2.0))))
	regions.append(fallback)
	return regions


func _melee_collider_sort_distance(collider: Variant, origin: Vector3) -> float:
	var node := collider as Node3D
	return origin.distance_squared_to(node.global_position) if node != null else INF


func _closest_point_on_segment_to_collider(segment_start: Vector3, segment_end: Vector3, collider: Variant) -> Vector3:
	var node := collider as Node3D
	if node == null:
		return segment_end
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return segment_start
	var weight := clampf((node.global_position - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return segment_start + segment * weight


func _horizontal_vector_distance(left: Vector3, right: Vector3) -> float:
	return Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))


func _apply_npc_attack_to_enemy(npc_id: String, npc: Dictionary, target: Dictionary, attack_context: Dictionary) -> Dictionary:
	var enemy_id := str(target.get("id", ""))
	if enemy_id.is_empty() or not _active_enemies.has(enemy_id):
		return {}
	var target_defense := _calculate_enemy_defense(enemy_id)
	var raw_attack_power := float(attack_context.get("raw_attack_power", 1.0))
	var penetration := maxf(0.0, float(attack_context.get("penetration", 0.0)))
	var resolution := calculate_damage_resolution(raw_attack_power, target_defense, penetration)
	var damage := int(resolution.get("damage", 1))
	var damage_result := _apply_damage_to_enemy(enemy_id, damage, npc_id, {
		"raw_attack_power": raw_attack_power,
		"target_defense": target_defense,
		"penetration": penetration,
		"effective_defense": float(resolution.get("effective_defense", target_defense)),
		"weapon_id": str(attack_context.get("weapon_id", "")),
		"weapon_name": str(attack_context.get("weapon_name", "武器")),
		"source_type": "npc_weapon",
		"npc_combat_growth_eligible": true,
		"required_skill": str(attack_context.get("required_skill", "")),
		# This value is captured at attack creation/release and survives projectile
		# flight, so mounting or falling while an arrow is airborne cannot rewrite it.
		"mounted_at_attack": bool(attack_context.get("mounted", false)),
		"hit_world_position": attack_context.get("hit_world_position", null)
	})
	var event := _log_npc_attack_made(npc_id, npc, target, attack_context, damage_result)
	return {
		"attacker_npc_id": npc_id,
		"attacker_name": str(npc.get("name", npc_id)),
		"target_enemy_id": enemy_id,
		"target_enemy_name": str(target.get("name", enemy_id)),
		"raw_attack_power": raw_attack_power,
		"target_defense": target_defense,
		"penetration": penetration,
		"effective_defense": float(resolution.get("effective_defense", target_defense)),
		"damage": damage,
		"damage_result": damage_result,
		"event": event
	}


func _is_ranged_weapon_type(weapon_type: String) -> bool:
	return RANGED_WEAPON_TYPES.has(weapon_type)


func _make_projectile_attack_id(
	source_side: String,
	source_id: String,
	attack_sequence: int,
	projectile_sequence: int
) -> String:
	var sequence_token := "%06d" % attack_sequence if attack_sequence > 0 else "adhoc"
	return "ranged:%s:%s:%s:%06d" % [
		source_side,
		source_id,
		sequence_token,
		projectile_sequence
	]


func _release_npc_projectile(
	npc_id: String,
	npc: Dictionary,
	target: Dictionary,
	attack_context: Dictionary
) -> Dictionary:
	var enemy_id := str(target.get("id", ""))
	if enemy_id.is_empty() or not _active_enemies.has(enemy_id):
		return {}
	var weapon_type := str(attack_context.get("weapon_id", ""))
	var release := _spawn_combat_projectile(
		"friendly",
		npc_id,
		str(npc.get("name", npc_id)),
		weapon_type,
		target,
		attack_context,
		npc
	)
	if release.is_empty():
		return {}
	return {
		"attacker_npc_id": npc_id,
		"attacker_name": str(npc.get("name", npc_id)),
		"target_enemy_id": enemy_id,
		"target_enemy_name": str(target.get("name", enemy_id)),
		"weapon_id": weapon_type,
		"attack_id": str(release.get("attack_id", "")),
		"attack_sequence": int(release.get("attack_sequence", 0)),
		"damage": 0,
		"damage_result": {},
		"projectile_status": "in_flight",
		"projectile": release,
		"event": {}
	}


func _release_enemy_projectile(enemy: Dictionary, target: Dictionary) -> Dictionary:
	var enemy_id := str(enemy.get("id", ""))
	var target_id := str(target.get("id", ""))
	if enemy_id.is_empty() or target_id.is_empty():
		return {}
	var weapon_type := str(enemy.get("weapon_type", ""))
	var attack_context := {
		"raw_attack_power": maxf(1.0, float(enemy.get("attack_power", 1.0))),
		"penetration": maxf(0.0, float(enemy.get("penetration", 0.0))),
		"weapon_id": weapon_type,
		"weapon_name": "弓" if weapon_type == "bow" else "弩",
		"attack_sequence": int(enemy.get("attack_sequence", 0))
	}
	var release := _spawn_combat_projectile(
		"enemy",
		enemy_id,
		str(enemy.get("name", enemy_id)),
		weapon_type,
		target,
		attack_context,
		enemy
	)
	if release.is_empty():
		return {}
	return {
		"attacker_enemy_id": enemy_id,
		"attacker_name": str(enemy.get("name", enemy_id)),
		"target_type": str(target.get("type", "")),
		"target_id": target_id,
		"weapon_id": weapon_type,
		"attack_id": str(release.get("attack_id", "")),
		"attack_sequence": int(release.get("attack_sequence", 0)),
		"damage": 0,
		"result": {},
		"projectile_status": "in_flight",
		"projectile": release
	}


func _spawn_combat_projectile(
	source_side: String,
	source_id: String,
	source_name: String,
	weapon_type: String,
	target: Dictionary,
	attack_context: Dictionary,
	source_snapshot: Dictionary
) -> Dictionary:
	if not _is_ranged_weapon_type(weapon_type):
		return {}
	var projectile_config: Dictionary = (
		attack_context.get("projectile_config", {}).duplicate(true)
		if attack_context.get("projectile_config", {}) is Dictionary
		else {}
	)
	if projectile_config.is_empty():
		projectile_config = _get_weapon_projectile_config(weapon_type)
	if projectile_config.is_empty():
		return {}
	var release_descriptor := _get_projectile_release_descriptor(source_side, source_id, weapon_type)
	if not bool(release_descriptor.get("ready", false)):
		_last_projectile_result = {
			"status": "release_rejected",
			"source_side": source_side,
			"source_id": source_id,
			"weapon_type": weapon_type,
			"reason": str(release_descriptor.get("reason", "formal_weapon_projectile_origin_unavailable")),
			"release_origin_source": str(release_descriptor.get("origin_source", "unavailable")),
		}
		return {}
	var release_transform: Transform3D = release_descriptor.get("transform", Transform3D.IDENTITY)
	var release_position := release_transform.origin
	var aim_target_snapshot := (
		{
			"ready": true,
			"position": _get_defense_device_target_aim_position(target),
			"target_source": "live_enemy_body"
		}
		if source_side == "defense_device"
		else _get_projectile_target_aim_snapshot(target)
	)
	var aim_position: Vector3 = aim_target_snapshot.get("position", Vector3.ZERO)
	var speed := maxf(0.1, float(projectile_config.get("speed", 20.0)))
	var gravity := maxf(0.01, float(projectile_config.get("gravity", 9.8)))
	var velocity := _calculate_ballistic_velocity(release_position, aim_position, speed, gravity)
	if velocity.length_squared() <= 0.000001:
		return {}

	_projectile_sequence += 1
	var projectile_id := "combat_projectile_%06d" % _projectile_sequence
	var attack_sequence := maxi(0, int(attack_context.get("attack_sequence", 0)))
	var attack_id := _make_projectile_attack_id(
		source_side,
		source_id,
		attack_sequence,
		_projectile_sequence
	)
	var projectile_attack_context := attack_context.duplicate(true)
	projectile_attack_context["attack_id"] = attack_id
	projectile_attack_context["attack_sequence"] = attack_sequence
	var view := COMBAT_PROJECTILE_VIEW_SCRIPT.new() as Node3D
	add_child(view)
	view.configure(projectile_id, weapon_type)
	view.project(release_position, velocity)
	var excluded_rids: Array[RID] = []
	var shooter_rid := _get_projectile_shooter_rid(source_side, source_id)
	if shooter_rid.is_valid():
		excluded_rids.append(shooter_rid)
	var projectile := {
		"id": projectile_id,
		"attack_id": attack_id,
		"attack_sequence": attack_sequence,
		"source_side": source_side,
		"source_id": source_id,
		"source_name": source_name,
		"weapon_type": weapon_type,
		"source_mounted": bool(release_descriptor.get("mounted", false)),
		"release_position": release_position,
		"release_basis": release_transform.basis,
		"release_origin_source": str(release_descriptor.get("origin_source", "formal_loaded_projectile")),
		"release_origin_node_path": str(release_descriptor.get("projectile_node_path", "")),
		"position": release_position,
		"velocity": velocity,
		"gravity": gravity,
		"max_range": maxf(0.0, float(projectile_config.get("max_range", 0.0))),
		"age": 0.0,
		"max_lifetime": maxf(0.1, float(projectile_config.get("max_lifetime", 3.0))),
		"target_at_release": target.duplicate(true),
		"aim_position_at_release": aim_position,
		"aim_target_source": str(aim_target_snapshot.get("target_source", "target_snapshot")),
		"aim_target_node_path": str(aim_target_snapshot.get("target_node_path", "")),
		"attack_context": projectile_attack_context,
		"source_snapshot": source_snapshot.duplicate(true),
		"excluded_rids": excluded_rids,
		"view": view,
		"status": "in_flight"
	}
	_active_projectiles[projectile_id] = projectile
	var snapshot := _make_projectile_snapshot(projectile)
	_last_projectile_result = snapshot.duplicate(true)
	_emit_combat_audio_event({
		"event_type": "projectile_released",
		"source_side": source_side,
		"source_id": source_id,
		"weapon_type": weapon_type,
		"device_id": str(projectile_attack_context.get("device_id", "")),
		"attack_id": attack_id,
		"world_position": release_position,
		"source_node_path": str(view.get_path()),
	})
	return snapshot


func _get_weapon_projectile_config(weapon_type: String) -> Dictionary:
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system == null or not equipment_system.has_method("get_weapon_def"):
		return {}
	var weapon: Dictionary = equipment_system.get_weapon_def(weapon_type)
	var projectile: Dictionary = weapon.get("projectile", {}) if weapon.get("projectile", {}) is Dictionary else {}
	return projectile.duplicate(true)


func _get_projectile_release_transform(source_side: String, source_id: String, weapon_type: String) -> Transform3D:
	var descriptor := _get_projectile_release_descriptor(source_side, source_id, weapon_type)
	if bool(descriptor.get("ready", false)) and descriptor.get("transform") is Transform3D:
		return descriptor.get("transform", Transform3D.IDENTITY)
	if source_side == "friendly":
		return Transform3D(Basis.IDENTITY, _get_npc_position(source_id) + Vector3.UP * 1.15)
	var enemy: Dictionary = _active_enemies.get(source_id, {}) if _active_enemies.get(source_id, {}) is Dictionary else {}
	return Transform3D(Basis.IDENTITY, enemy.get("position", Vector3.ZERO) + Vector3.UP * 1.15)


func _get_projectile_release_descriptor(source_side: String, source_id: String, weapon_type: String) -> Dictionary:
	if source_side == "friendly":
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system == null or not npc_system.has_method("get_npc_combat_projectile_release_snapshot"):
			return {"ready": false, "reason": "npc_projectile_origin_api_unavailable", "origin_source": "unavailable"}
		var friendly_snapshot: Dictionary = npc_system.get_npc_combat_projectile_release_snapshot(source_id, weapon_type)
		if not bool(friendly_snapshot.get("ready", false)) or not friendly_snapshot.get("transform") is Transform3D:
			return friendly_snapshot
		return friendly_snapshot
	if source_side == "defense_device":
		var presenter := get_node_or_null(DEFENSE_DEVICE_PRESENTER_PATH)
		if presenter == null or not presenter.has_method("get_projectile_release_snapshot"):
			return {"ready": false, "reason": "defense_device_presenter_origin_api_unavailable", "origin_source": "unavailable"}
		var device_snapshot: Dictionary = presenter.get_projectile_release_snapshot(source_id, weapon_type)
		if not bool(device_snapshot.get("ready", false)) or not device_snapshot.get("transform") is Transform3D:
			return device_snapshot
		device_snapshot["source_deployment_id"] = source_id
		return device_snapshot
	var enemy_node := get_node_or_null(_enemy_nodes.get(source_id, NodePath())) as Node3D if _enemy_nodes.has(source_id) else null
	if enemy_node == null:
		return {"ready": false, "reason": "enemy_actor_unavailable", "origin_source": "unavailable"}
	var art_view := enemy_node.get_node_or_null("EnemyArtView") as Node3D
	if art_view == null or not art_view.has_method("get_combat_projectile_release_snapshot"):
		return {"ready": false, "reason": "enemy_formal_art_projectile_origin_unavailable", "origin_source": "unavailable"}
	var enemy_snapshot: Dictionary = art_view.get_combat_projectile_release_snapshot(weapon_type)
	if not bool(enemy_snapshot.get("ready", false)) or not enemy_snapshot.get("transform") is Transform3D:
		return enemy_snapshot
	enemy_snapshot["source_enemy_id"] = source_id
	return enemy_snapshot


func _get_projectile_shooter_rid(source_side: String, source_id: String) -> RID:
	if source_side == "friendly":
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system != null and npc_system.has_method("get_npc_combat_collision_rid"):
			return npc_system.get_npc_combat_collision_rid(source_id)
		return RID()
	if source_side == "defense_device":
		return RID()
	var enemy_body := get_node_or_null(_enemy_nodes.get(source_id, NodePath())) as CollisionObject3D if _enemy_nodes.has(source_id) else null
	return enemy_body.get_rid() if enemy_body != null else RID()


func _get_projectile_target_aim_position(target: Dictionary) -> Vector3:
	return _get_projectile_target_aim_snapshot(target).get("position", Vector3.ZERO)


func _get_projectile_target_aim_snapshot(target: Dictionary) -> Dictionary:
	var target_type := str(target.get("type", ""))
	var target_id := str(target.get("id", ""))
	match target_type:
		"enemy":
			var enemy: Dictionary = _active_enemies.get(target_id, {}) if _active_enemies.get(target_id, {}) is Dictionary else {}
			var enemy_node := get_node_or_null(_enemy_nodes.get(target_id, NodePath())) as Node3D if _enemy_nodes.has(target_id) else null
			var base_position: Vector3 = enemy_node.global_position if enemy_node != null else enemy.get("position", target.get("position", Vector3.ZERO))
			var height := PROJECTILE_TARGET_HEIGHT_ENEMY_MOUNTED if str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"] else PROJECTILE_TARGET_HEIGHT_ENEMY_FOOT
			return {
				"ready": true,
				"position": base_position + Vector3.UP * height,
				"target_source": "live_enemy_body"
			}
		"npc":
			var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
			if npc_system != null and npc_system.has_method("get_npc_world_position"):
				var value: Variant = npc_system.get_npc_world_position(target_id)
				if value is Vector3:
					return {
						"ready": true,
						"position": value + Vector3.UP * PROJECTILE_TARGET_HEIGHT_NPC,
						"target_source": "live_npc_body"
					}
		"defense_device", "building":
			if target_type == "defense_device":
				var presenter := get_node_or_null(DEFENSE_DEVICE_PRESENTER_PATH)
				if presenter != null and presenter.has_method("get_projectile_target_snapshot"):
					var device_snapshot: Dictionary = presenter.get_projectile_target_snapshot(target_id)
					if bool(device_snapshot.get("ready", false)) and device_snapshot.get("position") is Vector3:
						return device_snapshot
				if target.get("aim_position") is Vector3:
					return {
						"ready": true,
						"position": target.get("aim_position"),
						"target_source": "legacy_defense_host_proxy_fallback"
					}
			return {
				"ready": true,
				"position": _get_enemy_attack_contact_position(target, Vector3(target.get("position", Vector3.ZERO))) + Vector3.UP * PROJECTILE_TARGET_HEIGHT_STRUCTURE,
				"target_source": "structure_contact"
			}
	return {
		"ready": true,
		"position": Vector3(target.get("position", Vector3.ZERO)) + Vector3.UP * PROJECTILE_TARGET_HEIGHT_NPC,
		"target_source": "target_snapshot_fallback"
	}


func _get_defense_device_target_aim_position(target: Dictionary) -> Vector3:
	var target_id := str(target.get("id", ""))
	var enemy: Dictionary = _active_enemies.get(target_id, {}) if _active_enemies.get(target_id, {}) is Dictionary else {}
	var base_position: Vector3 = target.get("position", enemy.get("position", Vector3.ZERO))
	var height := PROJECTILE_TARGET_HEIGHT_ENEMY_MOUNTED if str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"] else PROJECTILE_TARGET_HEIGHT_ENEMY_FOOT
	return base_position + Vector3.UP * height


func _calculate_ballistic_velocity(origin: Vector3, target: Vector3, speed: float, gravity: float) -> Vector3:
	var displacement := target - origin
	var horizontal := Vector3(displacement.x, 0.0, displacement.z)
	var distance := horizontal.length()
	if distance <= 0.0001:
		return Vector3.UP * speed
	var speed_squared := speed * speed
	var discriminant := speed_squared * speed_squared - gravity * (gravity * distance * distance + 2.0 * displacement.y * speed_squared)
	if discriminant >= 0.0:
		var tangent := (speed_squared - sqrt(discriminant)) / (gravity * distance)
		var angle := atan(tangent)
		return horizontal.normalized() * (speed * cos(angle)) + Vector3.UP * (speed * sin(angle))
	var flight_time := maxf(0.15, distance / speed)
	return displacement / flight_time + Vector3.UP * (0.5 * gravity * flight_time)


func _advance_combat_projectiles(delta: float) -> void:
	if delta <= 0.0 or _active_projectiles.is_empty():
		return
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	var remaining := maxf(0.0, delta)
	if time_system != null and time_system.has_method("get_combat_frame_delta_seconds"):
		remaining = maxf(0.0, float(time_system.get_combat_frame_delta_seconds(delta)))
	elif time_system != null and time_system.has_method("is_gameplay_paused") and bool(time_system.is_gameplay_paused()):
		remaining = 0.0
	while remaining > 0.000001 and not _active_projectiles.is_empty():
		var step := minf(PROJECTILE_MAX_SUBSTEP_SECONDS, remaining)
		remaining -= step
		for raw_projectile_id in _active_projectiles.keys().duplicate():
			var projectile_id := str(raw_projectile_id)
			if _active_projectiles.has(projectile_id):
				_advance_single_combat_projectile(projectile_id, step)


func _advance_single_combat_projectile(projectile_id: String, delta: float) -> void:
	var projectile: Dictionary = _active_projectiles.get(projectile_id, {})
	if projectile.is_empty():
		return
	var previous_position: Vector3 = projectile.get("position", Vector3.ZERO)
	var previous_velocity: Vector3 = projectile.get("velocity", Vector3.ZERO)
	var gravity := maxf(0.01, float(projectile.get("gravity", 9.8)))
	var next_velocity := previous_velocity + Vector3.DOWN * gravity * delta
	var next_position := previous_position + (previous_velocity + next_velocity) * 0.5 * delta
	var max_range := maxf(0.0, float(projectile.get("max_range", 0.0)))
	if max_range > 0.0:
		var release_position: Vector3 = projectile.get("release_position", previous_position)
		var next_horizontal := Vector2(next_position.x - release_position.x, next_position.z - release_position.z).length()
		if next_horizontal > max_range + PROJECTILE_RANGE_EPSILON:
			projectile["authored_range_crossed"] = true
	var projectile_collision_mask := PROJECTILE_COLLISION_MASK
	var release_target: Dictionary = projectile.get("target_at_release", {}) if projectile.get("target_at_release", {}) is Dictionary else {}
	if (
		str(projectile.get("source_side", "")) == "enemy"
		and str(release_target.get("type", "")) == "building"
		and str(release_target.get("id", "")) == "front_gate"
	):
		projectile_collision_mask |= ENEMY_GATE_COMBAT_CONTACT_LAYER
	var trace := _trace_combat_projectile_segment(
		projectile,
		previous_position,
		next_position,
		projectile_collision_mask
	)
	var collision: Dictionary = trace.get("collision", {}) if trace.get("collision", {}) is Dictionary else {}
	projectile["excluded_rids"] = trace.get("excluded_rids", projectile.get("excluded_rids", []))
	projectile["same_side_skip_count"] = int(projectile.get("same_side_skip_count", 0)) + int(trace.get("same_side_skip_count", 0))
	var skipped_ids: PackedStringArray = projectile.get("same_side_skipped_ids", PackedStringArray())
	for raw_skipped_id in trace.get("same_side_skipped_ids", PackedStringArray()):
		var skipped_id := str(raw_skipped_id)
		if not skipped_id.is_empty() and not skipped_ids.has(skipped_id):
			skipped_ids.append(skipped_id)
	projectile["same_side_skipped_ids"] = skipped_ids
	projectile["transparent_building_skip_count"] = int(projectile.get("transparent_building_skip_count", 0)) + int(trace.get("transparent_building_skip_count", 0))
	var skipped_building_ids: PackedStringArray = projectile.get("transparent_building_skipped_ids", PackedStringArray())
	for raw_building_id in trace.get("transparent_building_skipped_ids", PackedStringArray()):
		var skipped_building_id := str(raw_building_id)
		if not skipped_building_id.is_empty() and not skipped_building_ids.has(skipped_building_id):
			skipped_building_ids.append(skipped_building_id)
	projectile["transparent_building_skipped_ids"] = skipped_building_ids
	projectile["age"] = float(projectile.get("age", 0.0)) + delta
	projectile["velocity"] = next_velocity
	projectile["position"] = collision.get("position", next_position) if not collision.is_empty() else next_position
	var view := projectile.get("view") as Node3D
	if view != null and is_instance_valid(view):
		view.project(projectile.get("position", next_position), next_velocity)
	_active_projectiles[projectile_id] = projectile
	if not collision.is_empty():
		projectile = _prepare_projectile_stick(projectile, collision)
		_active_projectiles[projectile_id] = projectile
		var resolution := _resolve_combat_projectile_collision(projectile, collision)
		var status := str(
			resolution.get(
				"terminal_status",
				"hit" if bool(resolution.get("damage_applied", false)) else "blocked"
			)
		)
		_finish_combat_projectile(projectile_id, status, collision, resolution)
		return
	if float(projectile.get("age", 0.0)) >= float(projectile.get("max_lifetime", 3.0)):
		_finish_combat_projectile(projectile_id, "miss", {}, {"reason": "lifetime_expired"})


func _trace_combat_projectile_segment(
	projectile: Dictionary,
	from_position: Vector3,
	to_position: Vector3,
	collision_mask: int
) -> Dictionary:
	var excluded_rids: Array[RID] = []
	for raw_rid in projectile.get("excluded_rids", []):
		if raw_rid is RID and (raw_rid as RID).is_valid() and not excluded_rids.has(raw_rid):
			excluded_rids.append(raw_rid)
	var skipped_ids := PackedStringArray()
	var skipped_count := 0
	var skipped_building_ids := PackedStringArray()
	var skipped_building_count := 0
	var world := get_viewport().world_3d
	if world == null:
		return {
			"collision": {},
			"excluded_rids": excluded_rids,
			"same_side_skip_count": skipped_count,
			"same_side_skipped_ids": skipped_ids,
			"transparent_building_skip_count": skipped_building_count,
			"transparent_building_skipped_ids": skipped_building_ids
		}
	for _skip_index in range(PROJECTILE_MAX_TRANSPARENT_SKIPS_PER_SUBSTEP + 1):
		var query := PhysicsRayQueryParameters3D.create(
			from_position,
			to_position,
			collision_mask,
			excluded_rids
		)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.hit_from_inside = false
		var collision: Dictionary = world.direct_space_state.intersect_ray(query)
		if collision.is_empty():
			return {
				"collision": {},
				"excluded_rids": excluded_rids,
				"same_side_skip_count": skipped_count,
				"same_side_skipped_ids": skipped_ids,
				"transparent_building_skip_count": skipped_building_count,
				"transparent_building_skipped_ids": skipped_building_ids
			}
		var identity := _extract_projectile_collision_identity(collision.get("collider"))
		var same_side_actor := _is_projectile_same_side_actor(projectile, identity)
		var transparent_building := _is_projectile_transparent_building(projectile, identity)
		if not same_side_actor and not transparent_building:
			return {
				"collision": collision,
				"excluded_rids": excluded_rids,
				"same_side_skip_count": skipped_count,
				"same_side_skipped_ids": skipped_ids,
				"transparent_building_skip_count": skipped_building_count,
				"transparent_building_skipped_ids": skipped_building_ids
			}
		var collider := collision.get("collider") as CollisionObject3D
		if collider == null or not collider.get_rid().is_valid() or excluded_rids.has(collider.get_rid()):
			# A transparent hit without an excludable collision RID cannot safely be
			# retraced forever. Treat this one surface as transparent for this step.
			from_position = collision.get("position", from_position) + (to_position - from_position).normalized() * 0.01
			if from_position.distance_squared_to(to_position) <= 0.000001:
				break
		else:
			excluded_rids.append(collider.get_rid())
		if same_side_actor:
			var skipped_id := str(identity.get("npc_id", identity.get("enemy_id", identity.get("deployment_id", ""))))
			if not skipped_id.is_empty() and not skipped_ids.has(skipped_id):
				skipped_ids.append(skipped_id)
			skipped_count += 1
		if transparent_building:
			var building_id := str(identity.get("building_id", ""))
			if not building_id.is_empty() and not skipped_building_ids.has(building_id):
				skipped_building_ids.append(building_id)
			skipped_building_count += 1
	return {
		"collision": {},
		"excluded_rids": excluded_rids,
		"same_side_skip_count": skipped_count,
		"same_side_skipped_ids": skipped_ids,
		"transparent_building_skip_count": skipped_building_count,
		"transparent_building_skipped_ids": skipped_building_ids,
		"skip_limit_reached": true
	}


func _is_projectile_same_side_actor(projectile: Dictionary, identity: Dictionary) -> bool:
	var source_side := str(projectile.get("source_side", ""))
	if source_side == "enemy":
		return not str(identity.get("enemy_id", "")).is_empty()
	if source_side in ["friendly", "defense_device"]:
		return (
			not str(identity.get("npc_id", "")).is_empty()
			or not str(identity.get("deployment_id", "")).is_empty()
		)
	return false


func _is_projectile_transparent_building(projectile: Dictionary, identity: Dictionary) -> bool:
	# This is projectile-only filtering. The StaticBody and navigation source stay
	# enabled, so actors and horses still collide with and route around the host.
	var building_id := str(identity.get("building_id", ""))
	if (
		building_id.is_empty()
		or not str(identity.get("deployment_id", "")).is_empty()
		or not PROJECTILE_TRANSPARENT_BUILDING_IDS.has(building_id)
	):
		return false
	# Gate/main-hall transparency exists so an arrow aimed at a unit or hosted
	# defense device behind the shell can reach that target. When an enemy has
	# selected the building itself, the same shell is the intended hit surface and
	# must remain collidable so BuildingSystem receives the physical hit fact.
	var intended: Dictionary = (
		projectile.get("target_at_release", {})
		if projectile.get("target_at_release", {}) is Dictionary
		else {}
	)
	return not (
		str(projectile.get("source_side", "")) == "enemy"
		and str(intended.get("type", "")) == "building"
		and str(intended.get("id", "")) == building_id
	)


func _prepare_projectile_stick(projectile: Dictionary, collision: Dictionary) -> Dictionary:
	if bool(projectile.get("stick_prepared", false)):
		return projectile
	var view := projectile.get("view") as Node3D
	if view == null or not is_instance_valid(view):
		return projectile
	var collision_position: Vector3 = collision.get("position", projectile.get("position", Vector3.ZERO))
	var collision_normal: Vector3 = collision.get("normal", Vector3.ZERO)
	var incoming_velocity: Vector3 = projectile.get("velocity", Vector3.DOWN)
	if view.has_method("stick_at"):
		view.stick_at(collision_position, incoming_velocity, collision_normal)
	else:
		view.project(collision_position, incoming_velocity)
	var identity := _extract_projectile_collision_identity(collision.get("collider"))
	var anchor := _resolve_projectile_stick_anchor(collision.get("collider"), identity)
	var anchor_kind := "world"
	var anchor_target_id := ""
	if not str(identity.get("enemy_id", "")).is_empty():
		anchor_kind = "enemy"
		anchor_target_id = str(identity.get("enemy_id", ""))
	elif not str(identity.get("npc_id", "")).is_empty():
		anchor_kind = "npc"
		anchor_target_id = str(identity.get("npc_id", ""))
	elif not str(identity.get("building_id", "")).is_empty():
		anchor_kind = "building"
		anchor_target_id = str(identity.get("building_id", ""))
	elif not str(identity.get("deployment_id", "")).is_empty():
		anchor_kind = "defense_device"
		anchor_target_id = str(identity.get("deployment_id", ""))
	if anchor != null and is_instance_valid(anchor) and view.get_parent() != anchor:
		view.reparent(anchor, true)
	projectile["stick_prepared"] = true
	projectile["stick_anchor_kind"] = anchor_kind
	projectile["stick_anchor_target_id"] = anchor_target_id
	projectile["stick_anchor_node"] = anchor
	projectile["stick_collision_position"] = collision_position
	projectile["stick_collision_normal"] = collision_normal
	projectile["stick_world_position"] = view.global_position
	return projectile


func _resolve_projectile_stick_anchor(collider: Variant, identity: Dictionary) -> Node3D:
	var enemy_id := str(identity.get("enemy_id", ""))
	if not enemy_id.is_empty() and _enemy_nodes.has(enemy_id):
		var enemy_actor := get_node_or_null(_enemy_nodes.get(enemy_id, NodePath())) as Node3D
		if enemy_actor != null:
			var art_view := enemy_actor.get_node_or_null("EnemyArtView") as Node3D
			if art_view != null:
				return art_view
	var expected_npc_id := str(identity.get("npc_id", ""))
	var current := collider as Node
	var nearest_node_3d := current as Node3D
	while current != null:
		if nearest_node_3d == null and current is Node3D:
			nearest_node_3d = current as Node3D
		if not expected_npc_id.is_empty() and str(current.get_meta("npc_id", "")) == expected_npc_id:
			return current as Node3D
		current = current.get_parent()
	return nearest_node_3d


func _resolve_combat_projectile_collision(projectile: Dictionary, collision: Dictionary) -> Dictionary:
	var attack_id := str(projectile.get("attack_id", ""))
	if attack_id.is_empty():
		return {
			"damage_applied": false,
			"reason": "projectile_attack_id_missing",
			"terminal_status": "blocked"
		}
	if _resolved_projectile_attack_facts.has(attack_id):
		var existing_fact: Dictionary = (_resolved_projectile_attack_facts.get(attack_id, {}) as Dictionary).duplicate(true)
		return {
			"attack_id": attack_id,
			"damage_applied": false,
			"duplicate_ignored": true,
			"reason": "projectile_attack_id_already_resolved",
			"terminal_status": str(existing_fact.get("status", "blocked")),
			"hit_fact": existing_fact
		}
	var identity := _extract_projectile_collision_identity(collision.get("collider"))
	identity["collision_position"] = collision.get("position", projectile.get("position", Vector3.ZERO))
	var pending_fact := _make_projectile_terminal_fact(
		projectile,
		"resolving",
		collision,
		{
			"damage_applied": false,
			"collision_identity": identity
		}
	)
	# Reserve before damage/event callbacks run so re-entrant collision reports
	# for the same authoritative attack can never submit a second damage result.
	_resolved_projectile_attack_facts[attack_id] = pending_fact.duplicate(true)
	var resolution := _apply_combat_projectile_collision_damage(projectile, identity)
	var terminal_status := "hit" if bool(resolution.get("damage_applied", false)) else "blocked"
	resolution["attack_id"] = attack_id
	resolution["terminal_status"] = terminal_status
	var fact := _make_projectile_terminal_fact(projectile, terminal_status, collision, resolution)
	_resolved_projectile_attack_facts[attack_id] = fact.duplicate(true)
	resolution["hit_fact"] = fact.duplicate(true)
	if bool(resolution.get("damage_applied", false)):
		var projectile_context: Dictionary = (
			projectile.get("attack_context", {})
			if projectile.get("attack_context", {}) is Dictionary
			else {}
		)
		_emit_combat_audio_event({
			"event_type": "projectile_hit",
			"source_side": str(projectile.get("source_side", "")),
			"source_id": str(projectile.get("source_id", "")),
			"weapon_type": str(projectile.get("weapon_type", "")),
			"device_id": str(projectile_context.get("device_id", "")),
			"attack_id": attack_id,
			"target_type": str(resolution.get("actual_target_type", "")),
			"target_id": str(resolution.get("actual_target_id", "")),
			"world_position": collision.get("position", projectile.get("position", Vector3.ZERO)),
		})
	return resolution


func _apply_combat_projectile_collision_damage(projectile: Dictionary, identity: Dictionary) -> Dictionary:
	var source_side := str(projectile.get("source_side", ""))
	var attack_id := str(projectile.get("attack_id", ""))
	if source_side == "friendly":
		var hit_enemy_id := str(identity.get("enemy_id", ""))
		if hit_enemy_id.is_empty() or not _active_enemies.has(hit_enemy_id):
			return {"damage_applied": false, "reason": "non_enemy_blocker", "collision_identity": identity}
		var target: Dictionary = _active_enemies.get(hit_enemy_id, {}).duplicate(true)
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		var npc_id := str(projectile.get("source_id", ""))
		var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system != null and npc_system.has_method("get_npc") else projectile.get("source_snapshot", {})
		var projectile_attack_context: Dictionary = projectile.get("attack_context", {}).duplicate(true) if projectile.get("attack_context", {}) is Dictionary else {}
		projectile_attack_context["hit_world_position"] = WorldFeedbackPayload.find_world_position(identity)
		var damage_result := _apply_npc_attack_to_enemy(npc_id, npc, target, projectile_attack_context)
		_stamp_projectile_attack_id(damage_result, attack_id)
		return {
			"damage_applied": not damage_result.is_empty(),
			"actual_target_type": "enemy",
			"actual_target_id": hit_enemy_id,
			"collision_identity": identity,
			"damage_result": damage_result
		}
	if source_side == "defense_device":
		var hit_enemy_id := str(identity.get("enemy_id", ""))
		if hit_enemy_id.is_empty() or not _active_enemies.has(hit_enemy_id):
			return {"damage_applied": false, "reason": "non_enemy_blocker", "collision_identity": identity}
		var attack_context: Dictionary = projectile.get("attack_context", {}) if projectile.get("attack_context", {}) is Dictionary else {}
		var damage_result := apply_defense_device_attack(
			hit_enemy_id,
			maxf(1.0, float(attack_context.get("raw_attack_power", 1.0))),
			{
				"penetration": maxf(0.0, float(attack_context.get("penetration", 0.0))),
				"deployment_id": str(projectile.get("source_id", "")),
				"device_id": str(attack_context.get("device_id", "")),
				"device_name": str(projectile.get("source_name", "工程器械")),
				"attack_id": attack_id,
				"projectile_hit_fact": true,
				"hit_world_position": WorldFeedbackPayload.find_world_position(identity)
			}
		)
		_stamp_projectile_attack_id(damage_result, attack_id)
		return {
			"damage_applied": not damage_result.is_empty(),
			"actual_target_type": "enemy",
			"actual_target_id": hit_enemy_id,
			"collision_identity": identity,
			"damage_result": damage_result
		}

	var enemy: Dictionary = projectile.get("source_snapshot", {}) if projectile.get("source_snapshot", {}) is Dictionary else {}
	var hit_npc_id := str(identity.get("npc_id", ""))
	if not hit_npc_id.is_empty():
		var damage_result := _apply_enemy_projectile_damage_to_npc(enemy, hit_npc_id, projectile.get("attack_context", {}))
		_stamp_projectile_attack_id(damage_result, attack_id)
		return {
			"damage_applied": not damage_result.is_empty(),
			"actual_target_type": "npc",
			"actual_target_id": hit_npc_id,
			"collision_identity": identity,
			"damage_result": damage_result
		}

	var intended: Dictionary = projectile.get("target_at_release", {}) if projectile.get("target_at_release", {}) is Dictionary else {}
	var intended_type := str(intended.get("type", ""))
	var intended_id := str(intended.get("id", ""))
	if intended_type == "defense_device":
		var collision_position: Vector3 = identity.get("collision_position", Vector3.INF)
		if _is_defense_device_proxy_contact(intended, identity, collision_position):
			var proxy_attack_context: Dictionary = projectile.get("attack_context", {}).duplicate(true) if projectile.get("attack_context", {}) is Dictionary else {}
			proxy_attack_context["attack_id"] = attack_id
			proxy_attack_context["hit_world_position"] = WorldFeedbackPayload.find_world_position(identity)
			var damage_result := _apply_enemy_projectile_damage_to_device(enemy, intended_id, proxy_attack_context, intended)
			_stamp_projectile_attack_id(damage_result, attack_id)
			return {
				"damage_applied": not damage_result.is_empty(),
				"actual_target_type": "defense_device",
				"actual_target_id": intended_id,
				"collision_identity": identity,
				"damage_result": damage_result
			}
	if intended_type == "building" and str(identity.get("building_id", "")) == intended_id:
		var raw_power := maxf(1.0, float((projectile.get("attack_context", {}) as Dictionary).get("raw_attack_power", 1.0)))
		var damage_result := _apply_enemy_attack_to_building(
			enemy,
			intended_id,
			maxi(1, int(round(raw_power))),
			{"hit_world_position": WorldFeedbackPayload.find_world_position(identity)}
		)
		_stamp_projectile_attack_id(damage_result, attack_id)
		return {
			"damage_applied": not damage_result.is_empty(),
			"actual_target_type": "building",
			"actual_target_id": intended_id,
			"collision_identity": identity,
			"damage_result": damage_result
		}
	return {"damage_applied": false, "reason": "non_friendly_blocker", "collision_identity": identity}


func _stamp_projectile_attack_id(result: Dictionary, attack_id: String) -> void:
	if result.is_empty() or attack_id.is_empty():
		return
	result["attack_id"] = attack_id
	var nested_damage: Dictionary = result.get("damage_result", {}) if result.get("damage_result", {}) is Dictionary else {}
	if not nested_damage.is_empty():
		nested_damage["attack_id"] = attack_id
		result["damage_result"] = nested_damage


func _apply_enemy_projectile_damage_to_npc(enemy: Dictionary, npc_id: String, attack_context: Dictionary) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_state"):
		return {}
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	if npc_state.is_empty() or int(npc_state.get("hp", 0)) <= 0 or bool(npc_state.get("unconscious", false)):
		return {}
	var raw_attack_power := maxf(1.0, float(attack_context.get("raw_attack_power", 1.0)))
	var penetration := maxf(0.0, float(attack_context.get("penetration", 0.0)))
	var target_defense := _calculate_npc_defense(npc_id)
	var resolution := calculate_damage_resolution(raw_attack_power, target_defense, penetration)
	return _apply_enemy_attack_to_npc(
		enemy,
		npc_id,
		int(resolution.get("damage", 1)),
		raw_attack_power,
		target_defense,
		penetration,
		float(resolution.get("effective_defense", target_defense))
	)


func _apply_enemy_projectile_damage_to_device(
	enemy: Dictionary,
	deployment_id: String,
	attack_context: Dictionary,
	intended_target: Dictionary
) -> Dictionary:
	var raw_attack_power := maxf(1.0, float(attack_context.get("raw_attack_power", 1.0)))
	var penetration := maxf(0.0, float(attack_context.get("penetration", 0.0)))
	var defense := maxf(0.0, float(intended_target.get("defense", 0.0)))
	var resolution := calculate_damage_resolution(raw_attack_power, defense, penetration)
	return _apply_enemy_attack_to_defense_device(
		enemy,
		deployment_id,
		int(resolution.get("damage", 1)),
		resolution,
		{
			"attack_id": str(attack_context.get("attack_id", "")),
			"host_proxy_id": str(intended_target.get("attack_host_proxy_region_id", intended_target.get("host_proxy_id", ""))),
			"hit_world_position": attack_context.get("hit_world_position", null)
		}
	)


func _extract_projectile_collision_identity(collider: Variant) -> Dictionary:
	var current := collider as Node
	var identity := {}
	while current != null:
		for key in [
			"enemy_id",
			"npc_id",
			"deployment_id",
			"device_id",
			"building_id",
			"wall_segment_id",
			"building_segment_id",
			"fixture_id",
			"fixture_kind",
			"collision_category"
		]:
			if identity.has(key) or not current.has_meta(key):
				continue
			var value := str(current.get_meta(key, ""))
			if not value.is_empty():
				identity[key] = value
		current = current.get_parent()
	return identity


func _make_projectile_terminal_fact(
	projectile: Dictionary,
	status: String,
	collision: Dictionary,
	resolution: Dictionary
) -> Dictionary:
	var fact := {
		"attack_id": str(projectile.get("attack_id", "")),
		"projectile_id": str(projectile.get("id", "")),
		"attack_sequence": int(projectile.get("attack_sequence", 0)),
		"source_side": str(projectile.get("source_side", "")),
		"source_id": str(projectile.get("source_id", "")),
		"weapon_type": str(projectile.get("weapon_type", "")),
		"status": status,
		"collision_position": collision.get("position", projectile.get("position", Vector3.ZERO)),
		"collision_normal": collision.get("normal", Vector3.ZERO),
		"collision_identity": (resolution.get("collision_identity", {}) as Dictionary).duplicate(true) if resolution.get("collision_identity", {}) is Dictionary else {},
		"actual_target_type": str(resolution.get("actual_target_type", "")),
		"actual_target_id": str(resolution.get("actual_target_id", "")),
		"damage_applied": bool(resolution.get("damage_applied", false)),
		"reason": str(resolution.get("reason", "")),
		"duplicate_ignored": bool(resolution.get("duplicate_ignored", false)),
		"same_side_skip_count": int(projectile.get("same_side_skip_count", 0)),
		"same_side_skipped_ids": projectile.get("same_side_skipped_ids", PackedStringArray()),
		"transparent_building_skip_count": int(projectile.get("transparent_building_skip_count", 0)),
		"transparent_building_skipped_ids": projectile.get("transparent_building_skipped_ids", PackedStringArray()),
		"stick_anchor_kind": str(projectile.get("stick_anchor_kind", "world_endpoint")),
		"stick_anchor_target_id": str(projectile.get("stick_anchor_target_id", ""))
	}
	var damage_result: Dictionary = resolution.get("damage_result", {}) if resolution.get("damage_result", {}) is Dictionary else {}
	if not damage_result.is_empty():
		fact["damage_result"] = damage_result.duplicate(true)
	return fact


func _finish_combat_projectile(
	projectile_id: String,
	status: String,
	collision: Dictionary,
	resolution: Dictionary
) -> void:
	var projectile: Dictionary = _active_projectiles.get(projectile_id, {})
	if projectile.is_empty():
		return
	if not bool(projectile.get("stick_prepared", false)):
		projectile = _prepare_projectile_stick(projectile, collision)
		if not bool(projectile.get("stick_prepared", false)):
			var endpoint_view := projectile.get("view") as Node3D
			if endpoint_view != null and is_instance_valid(endpoint_view):
				var endpoint: Vector3 = projectile.get("position", Vector3.ZERO)
				var endpoint_velocity: Vector3 = projectile.get("velocity", Vector3.DOWN)
				if endpoint_view.has_method("stick_at"):
					endpoint_view.stick_at(endpoint, endpoint_velocity, Vector3.ZERO)
				projectile["stick_prepared"] = true
				projectile["stick_anchor_kind"] = "world_endpoint"
				projectile["stick_anchor_target_id"] = ""
				projectile["stick_collision_position"] = endpoint
				projectile["stick_collision_normal"] = Vector3.ZERO
				projectile["stick_world_position"] = endpoint_view.global_position
	projectile["status"] = status
	var attack_id := str(projectile.get("attack_id", ""))
	var terminal_resolution := resolution.duplicate(true)
	terminal_resolution["attack_id"] = attack_id
	var fact: Dictionary = _resolved_projectile_attack_facts.get(attack_id, {}) if _resolved_projectile_attack_facts.get(attack_id, {}) is Dictionary else {}
	if fact.is_empty() or str(fact.get("status", "")) == "resolving":
		fact = _make_projectile_terminal_fact(projectile, status, collision, terminal_resolution)
		if not attack_id.is_empty():
			_resolved_projectile_attack_facts[attack_id] = fact.duplicate(true)
	var result := _make_projectile_snapshot(projectile)
	result["status"] = status
	result["collision_position"] = collision.get("position", projectile.get("position", Vector3.ZERO))
	result["collision_normal"] = collision.get("normal", Vector3.ZERO)
	result["resolution"] = terminal_resolution
	result["hit_fact"] = fact.duplicate(true)
	var view := projectile.get("view") as Node3D
	if view != null and is_instance_valid(view):
		_register_stuck_projectile(projectile, status)
	result["stuck_projectile"] = _make_stuck_projectile_snapshot(
		_stuck_projectiles.get(projectile_id, {})
	)
	_last_projectile_result = result
	_active_projectiles.erase(projectile_id)
	if str(projectile.get("source_side", "")) == "defense_device":
		var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
		if device_system != null and device_system.has_method("resolve_defense_device_projectile"):
			result["defense_device_resolution"] = device_system.resolve_defense_device_projectile(result)
			_last_projectile_result = result
	if status == "hit" and str(projectile.get("source_side", "")) in ["friendly", "defense_device"] and _active_enemies.is_empty():
		result["mode_exit_result"] = _handle_all_enemies_cleared("enemies_defeated_by_projectile")
		_last_projectile_result = result


func _make_projectile_snapshot(projectile: Dictionary) -> Dictionary:
	return {
		"id": str(projectile.get("id", "")),
		"attack_id": str(projectile.get("attack_id", "")),
		"attack_sequence": int(projectile.get("attack_sequence", 0)),
		"source_side": str(projectile.get("source_side", "")),
		"source_id": str(projectile.get("source_id", "")),
		"source_name": str(projectile.get("source_name", "")),
		"weapon_type": str(projectile.get("weapon_type", "")),
		"source_mounted": bool(projectile.get("source_mounted", false)),
		"release_position": projectile.get("release_position", Vector3.ZERO),
		"release_basis": projectile.get("release_basis", Basis.IDENTITY),
		"release_origin_source": str(projectile.get("release_origin_source", "")),
		"release_origin_node_path": str(projectile.get("release_origin_node_path", "")),
		"position": projectile.get("position", Vector3.ZERO),
		"velocity": projectile.get("velocity", Vector3.ZERO),
		"gravity": float(projectile.get("gravity", 0.0)),
		"max_range": float(projectile.get("max_range", 0.0)),
		"age": float(projectile.get("age", 0.0)),
		"max_lifetime": float(projectile.get("max_lifetime", 0.0)),
		"target_at_release": _serialize_target(projectile.get("target_at_release", {})),
		"aim_position_at_release": projectile.get("aim_position_at_release", Vector3.ZERO),
		"aim_target_source": str(projectile.get("aim_target_source", "")),
		"aim_target_node_path": str(projectile.get("aim_target_node_path", "")),
		"status": str(projectile.get("status", "in_flight")),
		"damage_authority": "combat_system_swept_collision",
		"tracks_target_after_release": false,
		"authored_range_crossed": bool(projectile.get("authored_range_crossed", false)),
		"same_side_skip_count": int(projectile.get("same_side_skip_count", 0)),
		"same_side_skipped_ids": projectile.get("same_side_skipped_ids", PackedStringArray()),
		"transparent_building_skip_count": int(projectile.get("transparent_building_skip_count", 0)),
		"transparent_building_skipped_ids": projectile.get("transparent_building_skipped_ids", PackedStringArray())
	}


func get_active_projectile_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for projectile_id in _active_projectiles.keys():
		result.append(_make_projectile_snapshot(_active_projectiles.get(projectile_id, {})))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id", "")) < str(right.get("id", "")))
	return result


func get_stuck_projectile_snapshots() -> Array[Dictionary]:
	_prune_stuck_projectiles()
	var result: Array[Dictionary] = []
	for projectile_id in _stuck_projectiles.keys():
		var snapshot := _make_stuck_projectile_snapshot(_stuck_projectiles.get(projectile_id, {}))
		if not snapshot.is_empty():
			result.append(snapshot)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id", "")) < str(right.get("id", "")))
	return result


func _register_stuck_projectile(projectile: Dictionary, status: String) -> void:
	var projectile_id := str(projectile.get("id", ""))
	var view := projectile.get("view") as Node3D
	if projectile_id.is_empty() or view == null or not is_instance_valid(view):
		return
	view.set_meta("projectile_state", "stuck")
	view.set_meta("projectile_status", status)
	view.set_meta("stick_anchor_kind", str(projectile.get("stick_anchor_kind", "world_endpoint")))
	view.set_meta("stick_anchor_target_id", str(projectile.get("stick_anchor_target_id", "")))
	_stuck_projectiles[projectile_id] = {
		"id": projectile_id,
		"attack_id": str(projectile.get("attack_id", "")),
		"source_side": str(projectile.get("source_side", "")),
		"source_id": str(projectile.get("source_id", "")),
		"weapon_type": str(projectile.get("weapon_type", "")),
		"status": status,
		"anchor_kind": str(projectile.get("stick_anchor_kind", "world_endpoint")),
		"anchor_target_id": str(projectile.get("stick_anchor_target_id", "")),
		"collision_position": projectile.get("stick_collision_position", projectile.get("position", Vector3.ZERO)),
		"collision_normal": projectile.get("stick_collision_normal", Vector3.ZERO),
		"same_side_skip_count": int(projectile.get("same_side_skip_count", 0)),
		"same_side_skipped_ids": projectile.get("same_side_skipped_ids", PackedStringArray()),
		"transparent_building_skip_count": int(projectile.get("transparent_building_skip_count", 0)),
		"transparent_building_skipped_ids": projectile.get("transparent_building_skipped_ids", PackedStringArray()),
		"view": view
	}
	if not view.tree_exiting.is_connected(_on_stuck_projectile_tree_exiting.bind(projectile_id)):
		view.tree_exiting.connect(_on_stuck_projectile_tree_exiting.bind(projectile_id), CONNECT_ONE_SHOT)


func _make_stuck_projectile_snapshot(stuck: Dictionary) -> Dictionary:
	if stuck.is_empty():
		return {}
	var view := stuck.get("view") as Node3D
	if view == null or not is_instance_valid(view):
		return {}
	return {
		"id": str(stuck.get("id", "")),
		"attack_id": str(stuck.get("attack_id", "")),
		"source_side": str(stuck.get("source_side", "")),
		"source_id": str(stuck.get("source_id", "")),
		"weapon_type": str(stuck.get("weapon_type", "")),
		"status": str(stuck.get("status", "")),
		"anchor_kind": str(stuck.get("anchor_kind", "")),
		"anchor_target_id": str(stuck.get("anchor_target_id", "")),
		"collision_position": stuck.get("collision_position", Vector3.ZERO),
		"collision_normal": stuck.get("collision_normal", Vector3.ZERO),
		"same_side_skip_count": int(stuck.get("same_side_skip_count", 0)),
		"same_side_skipped_ids": stuck.get("same_side_skipped_ids", PackedStringArray()),
		"transparent_building_skip_count": int(stuck.get("transparent_building_skip_count", 0)),
		"transparent_building_skipped_ids": stuck.get("transparent_building_skipped_ids", PackedStringArray()),
		"world_position": view.global_position,
		"parent_path": str(view.get_parent().get_path()) if view.get_parent() != null else "",
		"visible": view.visible,
		"presentation_only": bool(view.get_meta("presentation_only", false))
	}


func _on_stuck_projectile_tree_exiting(projectile_id: String) -> void:
	_stuck_projectiles.erase(projectile_id)


func _prune_stuck_projectiles() -> void:
	for raw_projectile_id in _stuck_projectiles.keys().duplicate():
		var projectile_id := str(raw_projectile_id)
		var stuck: Dictionary = _stuck_projectiles.get(projectile_id, {}) if _stuck_projectiles.get(projectile_id, {}) is Dictionary else {}
		var view := stuck.get("view") as Node3D
		if view == null or not is_instance_valid(view):
			_stuck_projectiles.erase(projectile_id)


func debug_advance_combat_projectiles(seconds: float) -> Dictionary:
	var remaining := clampf(seconds, 0.0, 10.0)
	while remaining > 0.000001 and not _active_projectiles.is_empty():
		var step := minf(PROJECTILE_MAX_SUBSTEP_SECONDS, remaining)
		remaining -= step
		for raw_projectile_id in _active_projectiles.keys().duplicate():
			var projectile_id := str(raw_projectile_id)
			if _active_projectiles.has(projectile_id):
				_advance_single_combat_projectile(projectile_id, step)
	return {
		"active": get_active_projectile_snapshots(),
		"last_result": _last_projectile_result.duplicate(true)
	}


func _clear_combat_projectiles(reason: String) -> void:
	_clear_active_combat_projectiles(reason)
	_clear_stuck_projectiles(reason, true)
	_resolved_projectile_attack_facts.clear()
	if not reason.is_empty():
		_last_projectile_result = {
			"status": "cleared",
			"reason": reason,
			"active_attack_ids_cleared": true,
			"stuck_projectiles_cleared": true
		}


func _clear_active_combat_projectiles(reason: String) -> void:
	for projectile in _active_projectiles.values():
		if not projectile is Dictionary:
			continue
		var projectile_data := projectile as Dictionary
		if str(projectile_data.get("source_side", "")) == "defense_device":
			var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
			if device_system != null and device_system.has_method("resolve_defense_device_projectile"):
				var cleared_result := _make_projectile_snapshot(projectile_data)
				cleared_result["status"] = "cleared"
				cleared_result["resolution"] = {"reason": reason, "attack_id": str(projectile_data.get("attack_id", ""))}
				device_system.resolve_defense_device_projectile(cleared_result)
		var view := projectile_data.get("view") as Node3D
		if view != null and is_instance_valid(view):
			view.queue_free()
	_active_projectiles.clear()


func _clear_stuck_projectiles(reason: String, include_enemy_attachments: bool) -> int:
	var cleared_count := 0
	for raw_projectile_id in _stuck_projectiles.keys().duplicate():
		var projectile_id := str(raw_projectile_id)
		var stuck: Dictionary = _stuck_projectiles.get(projectile_id, {}) if _stuck_projectiles.get(projectile_id, {}) is Dictionary else {}
		if not include_enemy_attachments and str(stuck.get("anchor_kind", "")) == "enemy":
			continue
		var view := stuck.get("view") as Node3D
		_stuck_projectiles.erase(projectile_id)
		if view != null and is_instance_valid(view):
			view.set_meta("projectile_clear_reason", reason)
			view.queue_free()
		cleared_count += 1
	return cleared_count


func _clear_battlefield_projectiles(reason: String) -> Dictionary:
	var active_count := _active_projectiles.size()
	_clear_active_combat_projectiles(reason)
	var stuck_count := _clear_stuck_projectiles(reason, false)
	_resolved_projectile_attack_facts.clear()
	return {
		"reason": reason,
		"active_projectiles_cleared": active_count,
		"world_and_npc_arrows_cleared": stuck_count,
		"enemy_corpse_arrows_preserved": get_stuck_projectile_snapshots().filter(
			func(entry: Dictionary) -> bool: return str(entry.get("anchor_kind", "")) == "enemy"
		).size()
	}


func _apply_cavalry_charge_impact(
	npc_id: String,
	npc: Dictionary,
	target: Dictionary,
	attack_context: Dictionary
) -> Dictionary:
	var enemy_id := str(target.get("id", ""))
	if enemy_id.is_empty() or not _active_enemies.has(enemy_id):
		return {}
	var equipment: Dictionary = npc.get("equipment", {}) if npc.get("equipment", {}) is Dictionary else {}
	var mount: Dictionary = equipment.get("mount", {}) if equipment.get("mount", {}) is Dictionary else {}
	if mount.is_empty():
		return {}
	var riding_skill := _get_npc_skill_value(npc, "骑术")
	var collision_raw_damage := maxf(
		1.0,
		float(mount.get("charge_damage", 4.0))
		+ float(riding_skill) * maxf(0.0, float(mount.get("charge_damage_riding_scale", 0.04)))
	)
	var collision_penetration := maxf(0.0, float(mount.get("charge_penetration", 0.0)))
	var target_defense := _calculate_enemy_defense(enemy_id)
	var resolution := calculate_damage_resolution(
		collision_raw_damage,
		target_defense,
		collision_penetration
	)
	var stagger_duration := maxf(0.0, float(mount.get("charge_stagger_seconds", 0.6)))
	var stagger_result := apply_enemy_stagger(
		enemy_id,
		stagger_duration,
		{
			"source_type": "horse_collision",
			"source_id": npc_id,
			"source_name": str(npc.get("name", npc_id))
		}
	)
	var damage_result := _apply_damage_to_enemy(
		enemy_id,
		int(resolution.get("damage", 1)),
		npc_id,
		{
			"raw_attack_power": collision_raw_damage,
			"target_defense": target_defense,
			"penetration": collision_penetration,
			"effective_defense": float(resolution.get("effective_defense", target_defense)),
			"source_type": "horse_collision",
			"mount_id": str(mount.get("id", mount.get("horse_id", ""))),
			"mount_name": str(mount.get("name", "坐骑"))
		}
	)
	return {
		"ok": true,
		"npc_id": npc_id,
		"enemy_id": enemy_id,
		"mount_id": str(mount.get("id", mount.get("horse_id", ""))),
		"mount_name": str(mount.get("name", "坐骑")),
		"riding_skill": riding_skill,
		"weapon_damage_multiplier": maxf(
			1.0,
			float(mount.get("charge_weapon_damage_multiplier", 1.45))
		),
		"collision_raw_damage": collision_raw_damage,
		"collision_damage": int(resolution.get("damage", 1)),
		"collision_penetration": collision_penetration,
		"collision_damage_result": damage_result,
		"stagger_duration": stagger_duration,
		"stagger_result": stagger_result,
		"interrupted_windup": bool(stagger_result.get("interrupted_windup", false)),
		"base_attack_context": attack_context.duplicate(true)
	}


func _apply_damage_to_enemy(enemy_id: String, damage: int, actor_npc_id: String, context: Dictionary = {}) -> Dictionary:
	if damage <= 0 or not _active_enemies.has(enemy_id):
		return {}
	var enemy: Dictionary = _active_enemies.get(enemy_id, {})
	var feedback_world_position: Variant = WorldFeedbackPayload.find_world_position(context)
	var prefer_feedback_position := feedback_world_position is Vector3
	if not prefer_feedback_position:
		feedback_world_position = get_enemy_world_position(enemy_id)
	var max_hp := maxi(1, int(enemy.get("max_hp", enemy.get("hp", 1))))
	var hp_before := clampi(int(enemy.get("hp", max_hp)), 0, max_hp)
	var hp_after := maxi(0, hp_before - damage)
	var actual_damage := maxi(0, hp_before - hp_after)
	var defeated := hp_after <= 0
	var attack_interrupt := _interrupt_enemy_attack_from_damage(enemy, damage, {
		"source_type": "npc" if not actor_npc_id.is_empty() else str(context.get("source_type", "")),
		"source_id": actor_npc_id if not actor_npc_id.is_empty() else str(context.get("deployment_id", context.get("source_id", "")))
	})
	var result := {
		"ok": true,
		"enemy_id": enemy_id,
		"enemy_name": str(enemy.get("name", enemy_id)),
		"damage": damage,
		"actual_damage": actual_damage,
		"raw_attack_power": float(context.get("raw_attack_power", damage)),
		"target_defense": float(context.get("target_defense", 0.0)),
		"penetration": float(context.get("penetration", 0.0)),
		"effective_defense": float(context.get("effective_defense", context.get("target_defense", 0.0))),
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"defeated": defeated,
		"actor_npc_id": actor_npc_id,
		"attack_interrupt": attack_interrupt
	}
	var damage_source_type := ""
	var damage_source_id := ""
	if not actor_npc_id.is_empty():
		damage_source_type = "npc"
		damage_source_id = actor_npc_id
		_record_enemy_retaliation_relation(enemy_id, damage_source_type, damage_source_id, "recent_hit")
	elif str(context.get("source_type", "")) == "defense_device":
		damage_source_type = "defense_device"
		damage_source_id = str(context.get("deployment_id", ""))
		_record_enemy_retaliation_relation(
			enemy_id,
			damage_source_type,
			damage_source_id,
			"recent_hit"
		)
	enemy["hp"] = hp_after
	enemy["alive"] = not defeated
	var combat_growth := _apply_npc_weapon_combat_growth(
		actor_npc_id,
		actual_damage,
		defeated,
		context
	)
	if not combat_growth.is_empty():
		result["combat_growth"] = combat_growth
	enemy["last_damage_result"] = result.duplicate(true)
	WorldFeedbackPayload.emit_hp_change(
		self,
		"enemy",
		enemy_id,
		hp_before,
		hp_after,
		feedback_world_position,
		prefer_feedback_position,
		0.35 if prefer_feedback_position else WorldFeedbackPayload.ENEMY_ANCHOR_HEIGHT
	)
	_emit_combat_audio_event({
		"event_type": "actor_damaged",
		"target_type": "enemy",
		"target_id": enemy_id,
		"source_type": "npc" if not actor_npc_id.is_empty() else str(context.get("source_type", "")),
		"source_id": actor_npc_id if not actor_npc_id.is_empty() else str(context.get("deployment_id", context.get("source_id", ""))),
		"weapon_type": str(context.get("weapon_id", "")),
		"damage": damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"defeated": defeated,
		"world_position": feedback_world_position if feedback_world_position is Vector3 else get_enemy_world_position(enemy_id),
	})
	if defeated:
		_last_defeated_enemy_audio_position = (
			feedback_world_position
			if feedback_world_position is Vector3
			else get_enemy_world_position(enemy_id)
		)
		_record_battle_resolved_enemy_defeat()
		_record_battle_enemy_defeat(actor_npc_id, enemy, result)
		result["removed"] = true
		_remove_enemy_from_combat(enemy_id)
	else:
		_record_enemy_high_threat_damage_reacquire_request(
			enemy_id,
			enemy,
			damage_source_type,
			damage_source_id
		)
		_active_enemies[enemy_id] = enemy
		_refresh_enemy_node(enemy_id)
	return result


func _apply_npc_weapon_combat_growth(
	npc_id: String,
	actual_damage: int,
	defeated: bool,
	context: Dictionary
) -> Dictionary:
	if (
		npc_id.is_empty()
		or actual_damage <= 0
		or not bool(context.get("npc_combat_growth_eligible", false))
		or str(context.get("source_type", "")) != "npc_weapon"
	):
		return {}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system == null
		or not npc_system.has_method("accumulate_npc_combat_skill_damage")
		or not npc_system.has_method("increase_npc_total_experience")
	):
		return {}

	var weapon_damage_threshold := maxi(
		1,
		int(_combat_progression_config.get(
			"weapon_damage_per_skill_point",
			DEFAULT_WEAPON_DAMAGE_PER_SKILL_POINT
		))
	)
	var riding_damage_threshold := maxi(
		1,
		int(_combat_progression_config.get(
			"riding_damage_per_skill_point",
			DEFAULT_RIDING_DAMAGE_PER_SKILL_POINT
		))
	)
	var weapon_skill := str(context.get("required_skill", ""))
	var weapon_growth: Dictionary = npc_system.accumulate_npc_combat_skill_damage(
		npc_id,
		weapon_skill,
		actual_damage,
		weapon_damage_threshold,
		false
	)
	var riding_growth := {}
	if bool(context.get("mounted_at_attack", false)):
		riding_growth = npc_system.accumulate_npc_combat_skill_damage(
			npc_id,
			"骑术",
			actual_damage,
			riding_damage_threshold,
			false
		)

	var kill_experience := {}
	var kill_experience_amount := maxi(
		0,
		int(_combat_progression_config.get(
			"kill_total_experience",
			DEFAULT_KILL_TOTAL_EXPERIENCE
		))
	)
	if defeated and kill_experience_amount > 0:
		kill_experience = npc_system.increase_npc_total_experience(
			npc_id,
			kill_experience_amount,
			false
		)

	var feedback_results: Array[Dictionary] = []
	for growth_result in [weapon_growth, riding_growth, kill_experience]:
		if (
			growth_result is Dictionary
			and (
				int((growth_result as Dictionary).get("amount", 0)) > 0
				or int((growth_result as Dictionary).get("experience_gained", 0)) > 0
				or int((growth_result as Dictionary).get("skill_points_gained", 0)) > 0
			)
		):
			feedback_results.append((growth_result as Dictionary).duplicate(true))
	if not feedback_results.is_empty():
		var feedback_entries: Array[Dictionary] = []
		WorldFeedbackPayload.append_growth_batch_entry(feedback_entries, feedback_results)
		WorldFeedbackPayload.emit_npc(self, npc_id, "growth", feedback_entries)

	return {
		"npc_id": npc_id,
		"actual_damage": actual_damage,
		"mounted_at_attack": bool(context.get("mounted_at_attack", false)),
		"weapon_skill": weapon_skill,
		"weapon_growth": weapon_growth.duplicate(true),
		"riding_growth": riding_growth.duplicate(true),
		"kill_experience": kill_experience.duplicate(true),
		"feedback_emitted": not feedback_results.is_empty()
	}


func _remove_enemy_from_combat(enemy_id: String) -> void:
	_release_enemy_attack_position(enemy_id, "enemy_removed")
	_enemy_retaliation_relations.erase(enemy_id)
	_enemy_high_threat_reacquire_requests.erase(enemy_id)
	if _enemy_nodes.has(enemy_id):
		var enemy_node := get_node_or_null(_enemy_nodes[enemy_id]) as Node
		if enemy_node != null:
			_preserve_enemy_defeat_presentation(enemy_node, _active_enemies.get(enemy_id, {}))
			enemy_node.queue_free()
	_enemy_nodes.erase(enemy_id)
	_active_enemies.erase(enemy_id)
	if enemy_id == FORMAL_ACTIVE_ENEMY_SLICE_ID:
		_formal_active_enemy_slice.clear()
		_formal_active_enemy_slice_node_path = NodePath()
	if _formal_first_wave_slices.has(enemy_id):
		_formal_first_wave_slices.erase(enemy_id)
		_formal_first_wave_node_paths.erase(enemy_id)
	for raw_npc_id in _active_rallies.keys():
		var npc_id := str(raw_npc_id)
		var rally: Dictionary = _active_rallies.get(npc_id, {})
		if str(rally.get("encounter_enemy_id", "")) == enemy_id:
			rally["encounter_enemy_id"] = ""
			_active_rallies[npc_id] = rally
	if _active_enemies.is_empty():
		_sync_enemy_presence_time_slowdown("last_enemy_removed")


func _preserve_enemy_defeat_presentation(enemy_node: Node, enemy: Dictionary) -> void:
	var enemy_root := get_node_or_null(ENEMY_ROOT_PATH)
	if bool(enemy_node.get_meta("formal_active_enemy", false)):
		enemy_root = enemy_node.get_parent()
	var art_view := enemy_node.get_node_or_null("EnemyArtView") as Node3D
	if enemy_root == null or art_view == null:
		return
	art_view.reparent(enemy_root, true)
	art_view.name = "%sDefeatPresentation" % enemy_node.name
	art_view.set_meta("presentation_only", true)
	art_view.set_meta("corpse_linger_seconds", ENEMY_CORPSE_LINGER_SECONDS)
	var defeated_state := enemy.duplicate(true)
	defeated_state["hp"] = 0
	defeated_state["alive"] = false
	defeated_state["current_action"] = "unconscious"
	_apply_enemy_art_state(art_view, defeated_state, Vector3.ZERO)
	if art_view.has_method("begin_mounted_shared_defeat"):
		art_view.begin_mounted_shared_defeat(ENEMY_CORPSE_LINGER_SECONDS)
	else:
		get_tree().create_timer(ENEMY_CORPSE_LINGER_SECONDS).timeout.connect(art_view.queue_free)


func _on_enemy_mounted_defeat_cleanup_completed(snapshot: Dictionary) -> void:
	_last_enemy_mounted_defeat_cleanup_result = snapshot.duplicate(true)


func _calculate_enemy_defense(enemy_id: String) -> float:
	var enemy: Dictionary = _active_enemies.get(enemy_id, {})
	return maxf(0.0, float(enemy.get("defense", 0.0)))


func _calculate_npc_defense(npc_id: String) -> float:
	var combat_stats := get_npc_combat_stats(npc_id)
	var final_stats: Dictionary = combat_stats.get("final", {}) if combat_stats.get("final", {}) is Dictionary else {}
	return maxf(0.0, float(final_stats.get("defense", 0.0)))


func _calculate_actual_hp_damage(raw_attack_power: float, defense: float, penetration: float = 0.0) -> int:
	return int(calculate_damage_resolution(raw_attack_power, defense, penetration).get("damage", 1))


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


func _reset_formal_crowd_ai_budget(reset_configuration: bool = true) -> void:
	_formal_crowd_logic_frame = 0
	_formal_enemy_ai_cursor = 0
	_formal_enemy_game_seconds_accumulator.clear()
	_formal_enemy_combat_seconds_accumulator.clear()
	if reset_configuration:
		_formal_enemy_ai_updates_per_frame = 8
		_formal_contact_update_interval_frames = 6
		_formal_avoidance_update_interval_frames = 3


func _advance_formal_enemy_ai_budgeted(game_delta_seconds: float, combat_delta_seconds: float) -> Dictionary:
	var enemy_ids := get_active_enemy_ids()
	if enemy_ids.is_empty():
		return _advance_enemy_ai(game_delta_seconds, combat_delta_seconds)
	for raw_enemy_id in _formal_enemy_game_seconds_accumulator.keys():
		if not enemy_ids.has(str(raw_enemy_id)):
			_formal_enemy_game_seconds_accumulator.erase(raw_enemy_id)
			_formal_enemy_combat_seconds_accumulator.erase(raw_enemy_id)
	for enemy_id in enemy_ids:
		_formal_enemy_game_seconds_accumulator[enemy_id] = float(_formal_enemy_game_seconds_accumulator.get(enemy_id, 0.0)) + game_delta_seconds
		_formal_enemy_combat_seconds_accumulator[enemy_id] = float(_formal_enemy_combat_seconds_accumulator.get(enemy_id, 0.0)) + combat_delta_seconds
	var update_count := mini(_formal_enemy_ai_updates_per_frame, enemy_ids.size())
	_formal_enemy_ai_cursor %= enemy_ids.size()
	var selected_ids: Array[String] = []
	var game_seconds_by_enemy: Dictionary = {}
	var combat_seconds_by_enemy: Dictionary = {}
	for offset in range(update_count):
		var enemy_id := str(enemy_ids[(_formal_enemy_ai_cursor + offset) % enemy_ids.size()])
		selected_ids.append(enemy_id)
		game_seconds_by_enemy[enemy_id] = float(_formal_enemy_game_seconds_accumulator.get(enemy_id, game_delta_seconds))
		combat_seconds_by_enemy[enemy_id] = float(_formal_enemy_combat_seconds_accumulator.get(enemy_id, combat_delta_seconds))
		_formal_enemy_game_seconds_accumulator[enemy_id] = 0.0
		_formal_enemy_combat_seconds_accumulator[enemy_id] = 0.0
	_formal_enemy_ai_cursor = (_formal_enemy_ai_cursor + update_count) % enemy_ids.size()
	var result := _advance_enemy_ai(
		game_delta_seconds,
		combat_delta_seconds,
		selected_ids,
		game_seconds_by_enemy,
		combat_seconds_by_enemy
	)
	result["budgeted"] = true
	result["updated_enemy_count"] = selected_ids.size()
	result["total_enemy_count"] = enemy_ids.size()
	result["next_cursor"] = _formal_enemy_ai_cursor
	return result


func _advance_enemy_ai(
	game_delta_seconds: float,
	combat_delta_seconds: float = -1.0,
	enemy_ids_override: Array[String] = [],
	game_seconds_by_enemy: Dictionary = {},
	combat_seconds_by_enemy: Dictionary = {}
) -> Dictionary:
	if combat_delta_seconds < 0.0:
		combat_delta_seconds = _get_combat_action_seconds(game_delta_seconds)
	var result := {
		"ok": true,
		"game_seconds": game_delta_seconds,
		"combat_seconds": combat_delta_seconds,
		"moved": [],
		"attacks": [],
		"staggered": [],
		"targets": []
	}
	if game_delta_seconds <= 0.0 or _active_enemies.is_empty():
		_last_ai_step_result = result.duplicate(true)
		return result

	var enemy_ids := enemy_ids_override if not enemy_ids_override.is_empty() else get_active_enemy_ids()
	for enemy_id in enemy_ids:
		if not _active_enemies.has(enemy_id):
			continue
		var enemy_game_delta_seconds := float(game_seconds_by_enemy.get(enemy_id, game_delta_seconds))
		var enemy_combat_delta_seconds := float(combat_seconds_by_enemy.get(enemy_id, combat_delta_seconds))
		var enemy: Dictionary = _active_enemies[enemy_id]
		if not bool(enemy.get("alive", true)):
			continue
		var stagger_remaining := maxf(0.0, float(enemy.get("stagger_remaining", 0.0)))
		if stagger_remaining > 0.0:
			var stagger_after := maxf(0.0, stagger_remaining - enemy_combat_delta_seconds)
			enemy["stagger_remaining"] = stagger_after
			enemy["current_action"] = "staggered" if stagger_after > 0.0 else "recovering_from_stagger"
			(result["staggered"] as Array).append({
				"enemy_id": enemy_id,
				"before": stagger_remaining,
				"after": stagger_after
			})
			_active_enemies[enemy_id] = enemy
			_refresh_enemy_node(enemy_id)
			continue
		if _formal_first_wave_slices.has(enemy_id):
			var wave_slice: Dictionary = _formal_first_wave_slices[enemy_id]
			var wave_phase := str(wave_slice.get("phase", "inactive"))
			var dynamic_pressure := str(wave_slice.get("movement_model", "")) == "dynamic_combat_pressure"
			if wave_phase in ["marching_to_front_gate", "front_gate_reached", "attacking_front_gate"] and _is_building_destroyed("front_gate"):
				if not _begin_formal_first_wave_route(enemy_id, enemy, "warehouse", "marching_to_warehouse"):
					_on_formal_first_wave_motion_failed("", "post_gate_route_start_failed", enemy_id)
				else:
					(result["moved"] as Array).append({"enemy_id": enemy_id, "movement_authority": "ActorMotionBody", "route_phase": "marching_to_warehouse", "target_stage_id": "warehouse"})
				continue
			if wave_phase in ["marching_to_warehouse", "warehouse_reached", "attacking_warehouse"] and _is_building_destroyed("warehouse"):
				if (
					not dynamic_pressure
					and
					int(wave_slice.get("wave_number", 1)) == 2
					and str(wave_slice.get("attack_slot_role", "")) == "polearm_rear"
					and not _is_formal_wave_role_ready_at_stage(2, "melee_front", "main_hall")
				):
					enemy["target"] = {}
					enemy["current_action"] = "waiting_for_melee_front_main_hall"
					enemy["formal_route_phase"] = wave_phase
					_active_enemies[enemy_id] = enemy
					(result["moved"] as Array).append({"enemy_id": enemy_id, "movement_authority": "formation_wait", "route_phase": wave_phase, "waiting_for_role": "melee_front"})
					continue
				if not _begin_formal_first_wave_route(enemy_id, enemy, "main_hall", "marching_to_main_hall"):
					_on_formal_first_wave_motion_failed("", "main_hall_route_start_failed", enemy_id)
				else:
					(result["moved"] as Array).append({"enemy_id": enemy_id, "movement_authority": "ActorMotionBody", "route_phase": "marching_to_main_hall", "target_stage_id": "main_hall"})
				continue
			if wave_phase in ["main_hall_reached", "attacking_main_hall"] and _is_building_destroyed("main_hall"):
				_release_enemy_attack_position(enemy_id, "main_hall_destroyed")
				enemy["target"] = {}
				enemy["current_action"] = "main_hall_destroyed_failure"
				enemy["formal_route_phase"] = "main_hall_destroyed_failure"
				_active_enemies[enemy_id] = enemy
				wave_slice["phase"] = "main_hall_destroyed_failure"
				wave_slice["attack_unlocked"] = false
				wave_slice["attack_target_building_id"] = ""
				_formal_first_wave_slices[enemy_id] = wave_slice
				_refresh_enemy_node(enemy_id)
				continue
			if not dynamic_pressure and wave_phase not in ["front_gate_reached", "attacking_front_gate", "warehouse_reached", "attacking_warehouse", "main_hall_reached", "attacking_main_hall"]:
				enemy["target"] = {}
				enemy["formal_route_phase"] = wave_phase
				_active_enemies[enemy_id] = enemy
				(result["moved"] as Array).append({"enemy_id": enemy_id, "movement_authority": "ActorMotionBody", "route_phase": wave_phase, "position": _vector3_to_dict(enemy.get("position", Vector3.ZERO))})
				_refresh_enemy_node(enemy_id)
				continue
		if enemy_id == FORMAL_ACTIVE_ENEMY_SLICE_ID:
			var formal_phase := str(_formal_active_enemy_slice.get("phase", "inactive"))
			if formal_phase in ["front_gate_reached", "attacking_front_gate"] and _is_building_destroyed("front_gate"):
				if not _begin_formal_active_enemy_post_gate_route(enemy):
					_on_formal_active_enemy_motion_failed("", "post_gate_route_start_failed")
				else:
					(result["moved"] as Array).append({
						"enemy_id": enemy_id,
						"movement_authority": "ActorMotionBody",
						"route_phase": "marching_to_warehouse",
						"target_stage_id": "gate_turn",
						"position": _vector3_to_dict(enemy.get("position", Vector3.ZERO))
					})
				continue
			if formal_phase in ["warehouse_reached", "attacking_warehouse"] and _is_building_destroyed("warehouse"):
				if not _begin_formal_active_enemy_main_hall_route(enemy):
					_on_formal_active_enemy_motion_failed("", "main_hall_route_start_failed")
				else:
					(result["moved"] as Array).append({
						"enemy_id": enemy_id,
						"movement_authority": "ActorMotionBody",
						"route_phase": "marching_to_main_hall",
						"target_stage_id": "main_hall",
						"position": _vector3_to_dict(enemy.get("position", Vector3.ZERO))
					})
				continue
			if formal_phase in ["main_hall_reached", "attacking_main_hall"] and _is_building_destroyed("main_hall"):
				_release_enemy_attack_position(enemy_id, "main_hall_destroyed")
				enemy["target"] = {}
				enemy["current_action"] = "main_hall_destroyed_failure"
				enemy["formal_route_phase"] = "main_hall_destroyed_failure"
				_active_enemies[enemy_id] = enemy
				var failure_slice := _formal_active_enemy_slice
				failure_slice["phase"] = "main_hall_destroyed_failure"
				failure_slice["attack_unlocked"] = false
				failure_slice["attack_target_building_id"] = ""
				_formal_active_enemy_slice = failure_slice
				_refresh_enemy_node(enemy_id)
				continue
			if formal_phase not in ["front_gate_reached", "attacking_front_gate", "warehouse_reached", "attacking_warehouse", "main_hall_reached", "attacking_main_hall"]:
				enemy["target"] = {}
				enemy["formal_route_phase"] = formal_phase
				_active_enemies[enemy_id] = enemy
				(result["moved"] as Array).append({
					"enemy_id": enemy_id,
					"movement_authority": "ActorMotionBody",
					"route_phase": formal_phase,
					"position": _vector3_to_dict(enemy.get("position", Vector3.ZERO))
				})
				_refresh_enemy_node(enemy_id)
				continue
		# Every live enemy must use the same presence-lock priority selector.  The
		# previous conditional kept the pre-T0196 preference selector alive for any
		# actor whose formal slice was temporarily missing / restored without the
		# dynamic marker; those actors could ignore an in-range defense device and
		# continue straight to the gate.
		var target_measured: bool = _performance_probe != null and _performance_probe.active
		var target_started := Time.get_ticks_usec() if target_measured else 0
		var target := _select_formal_dynamic_enemy_target(enemy_id, enemy)
		if target_measured:
			_performance_probe.record("enemy_target_select_ms", Time.get_ticks_usec() - target_started)
		var active_cycle_target: Dictionary = enemy.get("attack_cycle_target", {}) if enemy.get("attack_cycle_target", {}) is Dictionary else {}
		var completing_locked_actor_melee := (
			str(enemy.get("attack_cycle_phase", "idle")) in ["windup", "recovery"]
			and str(enemy.get("weapon_type", "")) in MELEE_WEAPON_TYPES
			and str(active_cycle_target.get("type", "")) == "npc"
		)
		var completing_locked_projectile_action := (
			str(enemy.get("attack_cycle_phase", "idle")) in ["windup", "recovery"]
			and _is_ranged_weapon_type(str(enemy.get("weapon_type", "")))
			and str(active_cycle_target.get("type", "")) == "npc"
		)
		var completing_locked_actor_action := completing_locked_actor_melee or completing_locked_projectile_action
		if completing_locked_actor_action:
			var locked_npc_target := _make_npc_enemy_target(
				str(active_cycle_target.get("id", "")),
				enemy.get("position", Vector3.ZERO)
			)
			if not locked_npc_target.is_empty():
				target = locked_npc_target
			else:
				completing_locked_actor_action = false
		if _formal_first_wave_slices.has(enemy_id) and str(target.get("id", "")) in ["front_gate", "warehouse", "main_hall"]:
			var wave_target_id := str(target.get("id", ""))
			var wave_approach_position := _get_formal_first_wave_stage_position(
				enemy_id,
				wave_target_id,
				target.get("route_approach_position", target.get("position", enemy.get("position", Vector3.ZERO)))
			)
			target["route_approach_position"] = wave_approach_position
			if str(target.get("building_geometry_schema", "")).is_empty() or not _uses_enemy_attack_position_leases(enemy_id):
				target["position"] = wave_approach_position
		elif enemy_id == FORMAL_ACTIVE_ENEMY_SLICE_ID and str(target.get("id", "")) in ["front_gate", "warehouse", "main_hall"]:
			var formal_target_id := str(target.get("id", ""))
			var formal_approach_position := _get_formal_enemy_stage_position(
				formal_target_id,
				target.get("route_approach_position", target.get("position", enemy.get("position", Vector3.ZERO)))
			)
			target["route_approach_position"] = formal_approach_position
			target["position"] = formal_approach_position
		var lease_started := Time.get_ticks_usec() if target_measured else 0
		target = _ensure_enemy_attack_position(enemy_id, enemy, target)
		if target_measured:
			_performance_probe.record("enemy_attack_position_ms", Time.get_ticks_usec() - lease_started)
		_configure_enemy_attack_wait_avoidance(
			enemy_id,
			str(target.get("attack_position_status", "")) == "waiting"
		)
		enemy["target"] = target.duplicate(true)
		(result["targets"] as Array).append({
			"enemy_id": enemy_id,
			"target": _serialize_target(target)
		})
		if target.is_empty():
			_release_enemy_attack_position(enemy_id, "no_target")
			_cancel_enemy_attack_timeline(enemy)
			enemy["current_action"] = "idle_no_target"
			_active_enemies[enemy_id] = enemy
			_refresh_enemy_node(enemy_id)
			continue

		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		if str(target.get("attack_position_status", "")) == "waiting":
			_cancel_enemy_attack_timeline(enemy)
			_ensure_formal_dynamic_pressure_motion(enemy_id, target)
			enemy["current_action"] = "waiting_for_attack_position"
			(result["moved"] as Array).append({
				"enemy_id": enemy_id,
				"target_id": str(target.get("id", "")),
				"movement_authority": "attack_position_wait_pressure",
				"pressure_state": "waiting_for_lease",
				"desired_attack_position_id": str(target.get("attack_position_wait_target_id", "")),
				"queue_sequence": int(target.get("attack_position_queue_sequence", 0))
			})
			_active_enemies[enemy_id] = enemy
			_refresh_enemy_node(enemy_id)
			continue
		var target_position: Vector3 = target.get("position", enemy_position)
		target_position.y = enemy_position.y
		var attack_contact_position := _get_enemy_attack_contact_position(target, target_position)
		attack_contact_position.y = enemy_position.y
		var attack_range := _get_enemy_guided_attack_handoff_range(enemy, target)
		var center_distance := enemy_position.distance_to(target_position)
		var distance := (
			enemy_position.distance_to(attack_contact_position)
			if target.get("attack_contact_position", null) is Vector3
			else (
				center_distance
				if str(target.get("type", "")) == "npc"
				else maxf(0.0, center_distance - maxf(0.0, float(target.get("contact_radius", 0.0))))
			)
		)
		var attack_position_reached := _has_enemy_reached_attack_position(enemy_id, target)
		var attack_phase := str(enemy.get("attack_cycle_phase", "idle"))
		var engagement_range_margin := (
			maxf(0.0, float(_formal_attack_position_policy.get("engagement_range_exit_margin", 0.18)))
			if attack_phase in ["windup", "recovery"]
			else 0.0
		)
		if (
			not completing_locked_actor_action
			and (distance > attack_range + engagement_range_margin or not attack_position_reached)
		):
			_cancel_enemy_attack_timeline(enemy)
			if _is_formal_dynamic_pressure_enemy(enemy_id):
				_ensure_formal_dynamic_pressure_motion(enemy_id, target)
				var pressure_actor := get_node_or_null(
					_formal_first_wave_node_paths.get(enemy_id, NodePath())
				) as ActorMotionBody
				_update_enemy_guidance_stall_recovery(
					enemy_id,
					target,
					pressure_actor,
					distance,
					attack_range + engagement_range_margin
				)
				enemy["current_action"] = "pressing_to_%s" % str(target.get("id", "target"))
				(result["moved"] as Array).append({
					"enemy_id": enemy_id,
					"target_id": str(target.get("id", "")),
					"movement_authority": "ActorMotionBody",
					"pressure_state": "seeking_contact",
					"remaining_distance": maxf(0.0, distance - attack_range),
					"attack_position_reached": attack_position_reached
				})
				_active_enemies[enemy_id] = enemy
				_refresh_enemy_node(enemy_id)
				continue
			var move_distance := maxf(0.0, float(enemy.get("move_speed", 2.5))) * enemy_game_delta_seconds
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
			_end_enemy_guidance_stall_recovery(enemy_id, "completed:attack_range_reached")
			if _is_formal_dynamic_pressure_enemy(enemy_id):
				_pause_formal_dynamic_pressure_motion(enemy_id)
				_mark_formal_dynamic_contact(enemy_id, target)
			if _uses_enemy_attack_guidance(enemy_id, target):
				var prior_action := str(enemy.get("current_action", ""))
				var was_already_in_attack_timeline := (
					prior_action.begins_with("winding_up_")
					or prior_action.begins_with("attacking_")
					or prior_action.begins_with("recovering_")
				)
				if not was_already_in_attack_timeline:
					_enemy_attack_position_metrics["guidance_in_range_handoffs"] = int(
						_enemy_attack_position_metrics.get("guidance_in_range_handoffs", 0)
					) + 1
				target["attack_position_status"] = "in_range"
				target["attack_guidance_handoff"] = "hurtbox_in_weapon_range"
				enemy["target"] = target.duplicate(true)
				if _enemy_attack_position_by_enemy.has(enemy_id):
					var guidance_key := str(_enemy_attack_position_by_enemy[enemy_id])
					var guidance_record := _enemy_attack_position_leases.get(guidance_key, {}) as Dictionary
					guidance_record["status"] = "engaging"
					guidance_record["in_range_frame"] = _formal_crowd_logic_frame
					_enemy_attack_position_leases[guidance_key] = guidance_record
			enemy["current_action"] = "attacking_%s" % str(target.get("id", "target"))
			var attack_result := _advance_enemy_attack(
				enemy,
				target,
				enemy_combat_delta_seconds,
				_combat_timeline_seconds
			)
			if not attack_result.is_empty():
				(result["attacks"] as Array).append(attack_result)
				if _formal_first_wave_slices.has(enemy_id) and int(attack_result.get("attack_count", 0)) > 0:
					var wave_attack_slice: Dictionary = _formal_first_wave_slices[enemy_id]
					var wave_attacked_building_id := str(target.get("id", ""))
					wave_attack_slice["combat_authority_committed"] = true
					wave_attack_slice["attack_target_building_id"] = wave_attacked_building_id
					match wave_attacked_building_id:
						"main_hall":
							wave_attack_slice["main_hall_combat_authority_committed"] = true
							wave_attack_slice["phase"] = "main_hall_destroyed_failure" if _is_building_destroyed("main_hall") else "attacking_main_hall"
						"warehouse":
							wave_attack_slice["warehouse_combat_authority_committed"] = true
							wave_attack_slice["phase"] = "attacking_warehouse"
						_:
							wave_attack_slice["front_gate_combat_authority_committed"] = true
							wave_attack_slice["phase"] = "attacking_front_gate"
					_formal_first_wave_slices[enemy_id] = wave_attack_slice
				elif enemy_id == FORMAL_ACTIVE_ENEMY_SLICE_ID and int(attack_result.get("attack_count", 0)) > 0:
					var slice := _formal_active_enemy_slice
					var attacked_building_id := str(target.get("id", ""))
					slice["combat_authority_committed"] = true
					slice["attack_target_building_id"] = attacked_building_id
					match attacked_building_id:
						"main_hall":
							slice["main_hall_combat_authority_committed"] = true
							slice["phase"] = "main_hall_destroyed_failure" if _is_building_destroyed("main_hall") else "attacking_main_hall"
						"warehouse":
							slice["warehouse_combat_authority_committed"] = true
							slice["phase"] = "attacking_warehouse"
						_:
							slice["front_gate_combat_authority_committed"] = true
							slice["phase"] = "attacking_front_gate"
					_formal_active_enemy_slice = slice
		_active_enemies[enemy_id] = enemy
		_refresh_enemy_node(enemy_id)

	_last_ai_step_result = result.duplicate(true)
	return result


func _is_building_destroyed(building_id: String) -> bool:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		return false
	var building: Dictionary = (
		building_system.get_building_combat_snapshot(building_id)
		if building_system.has_method("get_building_combat_snapshot")
		else building_system.get_building(building_id)
	)
	return building.is_empty() or int(building.get("hp", 0)) <= 0


func _get_formal_enemy_stage_position(stage_id: String, fallback: Vector3) -> Vector3:
	var route := _formal_active_enemy_slice.get("route", {}) as Dictionary
	for raw_stage in route.get("stages", []):
		if raw_stage is Dictionary and str((raw_stage as Dictionary).get("id", "")) == stage_id:
			return (raw_stage as Dictionary).get("position", fallback)
	return fallback


func _get_formal_enemy_stage_index(stage_id: String) -> int:
	var route := _formal_active_enemy_slice.get("route", {}) as Dictionary
	var stages := route.get("stages", []) as Array
	for stage_index in range(stages.size()):
		var stage := stages[stage_index] as Dictionary
		if str(stage.get("id", "")) == stage_id:
			return stage_index
	return -1


func _begin_formal_active_enemy_post_gate_route(enemy: Dictionary) -> bool:
	var actor := get_node_or_null(_formal_active_enemy_slice_node_path) as ActorMotionBody
	var gate_turn_index := _get_formal_enemy_stage_index("gate_turn")
	if actor == null or gate_turn_index < 0:
		return false
	enemy["target"] = {}
	_cancel_enemy_attack_timeline(enemy)
	enemy["formal_route_phase"] = "marching_to_warehouse"
	_active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID] = enemy
	var slice := _formal_active_enemy_slice
	slice["completed"] = false
	slice["attack_unlocked"] = false
	slice["attack_target_building_id"] = ""
	slice["phase"] = "marching_to_warehouse"
	_formal_active_enemy_slice = slice
	return _request_formal_active_enemy_stage(actor, gate_turn_index)


func _begin_formal_active_enemy_main_hall_route(enemy: Dictionary) -> bool:
	var actor := get_node_or_null(_formal_active_enemy_slice_node_path) as ActorMotionBody
	var main_hall_index := _get_formal_enemy_stage_index("main_hall")
	if actor == null or main_hall_index < 0:
		return false
	enemy["target"] = {}
	_cancel_enemy_attack_timeline(enemy)
	enemy["formal_route_phase"] = "marching_to_main_hall"
	_active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID] = enemy
	var slice := _formal_active_enemy_slice
	slice["completed"] = false
	slice["attack_unlocked"] = false
	slice["attack_target_building_id"] = ""
	slice["phase"] = "marching_to_main_hall"
	_formal_active_enemy_slice = slice
	return _request_formal_active_enemy_stage(actor, main_hall_index)


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
		var encounter := _find_rally_combat_encounter(npc_id)
		if not encounter.is_empty():
			_switch_rally_to_combat(npc_id, rally, encounter)
			continue
		if str(rally.get("status", "")) == "mounting":
			var mount_recovery := _ensure_wartime_mount_route(npc_id, "rally_mount_route_watchdog")
			# Completing the rendezvous invokes handle_npc_mount_ready synchronously,
			# which may replace this record with a moving/combat-ready rally. Never
			# write the stale pre-callback `mounting` snapshot back over that result.
			var current_rally: Dictionary = _active_rallies.get(npc_id, {})
			current_rally["mount_route_result"] = mount_recovery
			_active_rallies[npc_id] = current_rally
			continue
		var target_position: Vector3 = rally.get("position", npc_position)
		if npc_position.distance_to(target_position) <= RALLY_ARRIVAL_TOLERANCE:
			rally["status"] = "rallied"
			var elapsed := maxf(0.0, float(rally.get("rallied_elapsed_seconds", 0.0)) + maxf(0.0, game_delta_seconds))
			rally["rallied_elapsed_seconds"] = elapsed
			rally["rally_wait_remaining_seconds"] = maxf(0.0, RALLY_WAIT_TIMEOUT_SECONDS - elapsed)
			_active_rallies[npc_id] = rally
			if elapsed >= RALLY_WAIT_TIMEOUT_SECONDS:
				_complete_rally_timeout(npc_id, rally)
			continue
		if str(rally.get("status", "")) != "moving":
			continue
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		var current_action := str(state.get("current_action", ""))
		var physical_movement_active := (
			npc_system.has_method("is_npc_world_movement_active")
			and bool(npc_system.is_npc_world_movement_active(npc_id))
		)
		if current_action.begins_with("moving_to_%s" % RALLY_TARGET_PREFIX) and physical_movement_active:
			continue
		# Rally state is only movement intent. A mounted body can time out while
		# negotiating the gate or have its navigation request replaced without an
		# arrival callback. Restore the same reserved formation point instead of
		# leaving a visually rallying rider stationary before the destination.
		var recovery := _request_rally_movement(
			npc_id,
			rally,
			"rally_movement_recovered",
			true
		)
		_last_mode_transition_result = recovery.duplicate(true)


func _advance_behavior_mode_contacts() -> void:
	if _active_enemies.is_empty():
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("get_npc_world_position"):
		return
	var station_breached := _has_station_enemy()
	var avoidance_trigger_range := _get_avoidance_trigger_range()
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system.has_method("get_npc") else {}
		if npc.is_empty():
			continue
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		if bool(state.get("unconscious", false)) or bool(state.get("escaped", false)):
			continue
		var mode := _get_npc_behavior_mode(npc_system, npc_id)
		if mode == BEHAVIOR_MODE_COMBAT or mode == BEHAVIOR_MODE_AVOID_COMBAT:
			continue
		var raw_position: Variant = npc_system.get_npc_world_position(npc_id)
		if raw_position == null:
			continue
		var npc_position: Vector3 = raw_position
		var combat_eligible := _is_npc_combat_eligible(npc_id, npc_system)
		var friendly_scope := _get_friendly_target_scope(npc_id) if combat_eligible else {}
		var encounter := (
			_find_nearest_friendly_combat_enemy(npc_id, friendly_scope)
			if combat_eligible
			else _find_nearest_enemy(npc_position, avoidance_trigger_range)
		)
		if (
			npc_system.has_method("is_npc_sleeping")
			and npc_system.is_npc_sleeping(npc_id)
			and (not combat_eligible or encounter.is_empty())
		):
			continue
		if encounter.is_empty():
			continue
		if combat_eligible and [BEHAVIOR_MODE_WORK, BEHAVIOR_MODE_RALLY].has(mode):
			if _active_rallies.has(npc_id):
				_switch_rally_to_combat(npc_id, _active_rallies.get(npc_id, {}), encounter)
			else:
				_enter_npc_combat_from_contact(
					npc_id,
					encounter,
					"enemy_inside_station" if station_breached else "enemy_contact"
				)
		elif not combat_eligible and [BEHAVIOR_MODE_WORK, BEHAVIOR_MODE_RALLY].has(mode):
			_active_rallies.erase(npc_id)
			_enter_npc_avoid_from_contact(npc_id, encounter, "enemy_contact")


func _complete_rally_timeout(npc_id: String, rally: Dictionary) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("set_npc_behavior_mode"):
		var result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, "rally_wait_timeout", {
			"force_idle": true,
			"request_plan_reevaluation": false,
			"resume_current_plan": true,
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
			"current_action": "meeting_assigned_horse" if has_mount else "combat_ready",
			"last_action_result": reason,
			"combat_mounted": false,
			"combat_mount_phase": "going_to_stable_horse" if has_mount else "unmounted",
			"combat_target_enemy_id": str(
				encounter.get("combat_target_enemy_id", encounter.get("enemy_id", ""))
			),
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
			"request_plan_reevaluation": false,
			"resume_current_plan": true
		})
		work_result["avoidance_ended_event"] = ended_event
		_last_mode_transition_result = work_result.duplicate(true)
		return work_result
	if not _is_npc_combat_eligible(npc_id, npc_system):
		var encounter := _find_nearest_enemy(_get_npc_position(npc_id), _get_avoidance_trigger_range())
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
	var avoidance_range := _get_avoidance_trigger_range()
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
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		var current_action := str(state.get("current_action", ""))
		var physical_movement_active := (
			npc_system.has_method("is_npc_world_movement_active")
			and bool(npc_system.is_npc_world_movement_active(npc_id))
		)
		var has_active_avoidance := _active_avoidances.has(npc_id)
		var avoidance: Dictionary = _active_avoidances.get(npc_id, {}) if has_active_avoidance else {}
		var target_position: Vector3 = avoidance.get("target_position", npc_position)
		var threat_field := _build_avoidance_threat_field(npc_position, avoidance_range, npc_id)
		var encounter: Dictionary = threat_field.get("nearest_encounter", {})
		if encounter.is_empty():
			if not has_active_avoidance:
				continue
			avoidance["enemy_distance"] = INF
			avoidance["threat_count"] = 0
			avoidance["threats"] = []
			if npc_position.distance_to(target_position) <= 0.35:
				avoidance["status"] = "no_threat_in_range"
				_active_avoidances[npc_id] = avoidance
				continue
			if current_action.begins_with("moving_to_%s" % AVOIDANCE_TARGET_PREFIX) and physical_movement_active:
				avoidance["status"] = "moving_without_current_threat"
				_active_avoidances[npc_id] = avoidance
				continue
			# A threat leaving the detection radius does not cancel a committed
			# re-entry/avoidance leg. If another system or a failed navigation
			# request stopped the body, restore that exact destination.
			_last_avoidance_result = _start_or_update_npc_avoidance(
				npc_id,
				_avoidance_encounter_from_runtime(avoidance),
				_avoidance_target_from_runtime(avoidance),
				"avoidance_movement_recovered_without_current_threat",
				false
			)
			continue
		if not has_active_avoidance:
			var target := _select_avoidance_target(npc_id, encounter)
			_last_avoidance_result = _start_or_update_npc_avoidance(npc_id, encounter, target, "avoidance_tracking", true)
			continue
		avoidance["enemy_distance"] = float(encounter.get("distance", INF))
		if current_action.begins_with("moving_to_%s" % AVOIDANCE_TARGET_PREFIX) and physical_movement_active:
			avoidance["status"] = "moving"
			_active_avoidances[npc_id] = avoidance
			continue
		if npc_position.distance_to(target_position) <= 0.35:
			avoidance["status"] = "ready_to_retarget"
			_active_avoidances[npc_id] = avoidance
			var next_target := _select_avoidance_target(npc_id, encounter)
			_last_avoidance_result = _start_or_update_npc_avoidance(npc_id, encounter, next_target, "enemy_in_avoidance_range", false)
			continue
		# The state label is not physical movement authority. Navigation can fail
		# to start or be cancelled without an arrival callback, leaving the old
		# moving_to_* text behind. Re-resolve against the current threat field and
		# reissue the leg instead of stranding the NPC in avoid_combat forever.
		var recovered_target := _select_avoidance_target(npc_id, encounter)
		_last_avoidance_result = _start_or_update_npc_avoidance(
			npc_id,
			encounter,
			recovered_target,
			"avoidance_movement_recovered",
			false
		)


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
	var previous_avoidance: Dictionary = (
		_active_avoidances.get(npc_id, {})
		if _active_avoidances.get(npc_id, {}) is Dictionary
		else {}
	)
	var is_movement_recovery := reason.begins_with("avoidance_movement_recovered")
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
		"desired_target_distance": float(target.get("desired_travel_distance", 0.0)),
		"desired_target_position": target.get("desired_position", target_position),
		"movement_phase": str(target.get("movement_phase", "station_weighted_avoidance")),
		"target_policy": str(target.get("target_policy", "weighted_enemy_repulsion")),
		"reentry_gate_id": str(target.get("reentry_gate_id", "")),
		"avoidance_direction": target.get("direction", Vector3.ZERO),
		"threat_count": int(target.get("threat_count", 0)),
		"threats": (target.get("threats", []) as Array).duplicate(true),
		"weight_formula": str(target.get("weight_formula", "inverse_distance_power")),
		"weight_exponent": float(target.get("weight_exponent", _get_avoidance_weight_exponent())),
		"boundary_limited": bool(target.get("boundary_limited", false)),
		"navigation_adjusted": bool(target.get("navigation_adjusted", false)),
		"navigation_resolution_reason": str(target.get("navigation_resolution_reason", "")),
		"enemy_distance_after_target": float(target.get("enemy_distance_after", 0.0)),
		"enemy_distance_before_target": float(target.get("enemy_distance_before", float(encounter.get("distance", 0.0)))),
		"trigger_range": _get_avoidance_trigger_range(),
		"safe_distance": _get_avoidance_target_distance(),
		"movement_recovery_count": (
			int(previous_avoidance.get("movement_recovery_count", 0)) + 1
			if is_movement_recovery
			else int(previous_avoidance.get("movement_recovery_count", 0))
		),
		"last_movement_recovery_reason": reason if is_movement_recovery else str(previous_avoidance.get("last_movement_recovery_reason", "")),
		"started_event_id": str(event.get("event_id", "")),
		"event": event
	}
	_active_avoidances[npc_id] = avoidance
	return _serialize_avoidance(avoidance)


func _avoidance_encounter_from_runtime(avoidance: Dictionary) -> Dictionary:
	return {
		"enemy_id": str(avoidance.get("enemy_id", "")),
		"enemy_name": str(avoidance.get("enemy_name", "")),
		"distance": float(avoidance.get("enemy_distance", INF))
	}


func _avoidance_target_from_runtime(avoidance: Dictionary) -> Dictionary:
	return {
		"target_id": str(avoidance.get("safe_target_id", "")),
		"target_name": str(avoidance.get("target_name", AVOIDANCE_LOCATION_NAME)),
		"position": avoidance.get("target_position", Vector3.ZERO),
		"desired_position": avoidance.get("desired_target_position", avoidance.get("target_position", Vector3.ZERO)),
		"direction": avoidance.get("avoidance_direction", Vector3.ZERO),
		"movement_phase": str(avoidance.get("movement_phase", "station_weighted_avoidance")),
		"target_policy": str(avoidance.get("target_policy", "weighted_enemy_repulsion")),
		"reentry_gate_id": str(avoidance.get("reentry_gate_id", "")),
		"travel_distance": float(avoidance.get("target_travel_distance", 0.0)),
		"desired_travel_distance": float(avoidance.get("desired_target_distance", 0.0)),
		"threat_count": int(avoidance.get("threat_count", 0)),
		"threats": (avoidance.get("threats", []) as Array).duplicate(true),
		"weight_formula": str(avoidance.get("weight_formula", "inverse_distance_power")),
		"weight_exponent": float(avoidance.get("weight_exponent", _get_avoidance_weight_exponent())),
		"boundary_limited": bool(avoidance.get("boundary_limited", false)),
		"navigation_adjusted": bool(avoidance.get("navigation_adjusted", false)),
		"navigation_resolution_reason": str(avoidance.get("navigation_resolution_reason", "")),
		"enemy_distance_after": float(avoidance.get("enemy_distance_after_target", 0.0)),
		"enemy_distance_before": float(avoidance.get("enemy_distance_before_target", 0.0))
	}


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
	var avoidance_range := _get_avoidance_trigger_range()
	var threat_field := _build_avoidance_threat_field(npc_position, avoidance_range, npc_id)
	var threats: Array = threat_field.get("threats", [])
	if threats.is_empty():
		return {}
	var nearest_encounter: Dictionary = threat_field.get("nearest_encounter", encounter)
	if not _is_world_position_inside_station(npc_position):
		return _select_outside_avoidance_reentry_target(npc_id, npc_position, nearest_encounter, threats)
	var direction: Vector3 = threat_field.get("direction", _fallback_avoidance_direction(npc_id))
	var desired_position := npc_position + direction * _get_avoidance_target_distance()
	var resolution := _resolve_avoidance_navigation_target(npc_position, desired_position)
	if not bool(resolution.get("ok", false)):
		return {}
	var position: Vector3 = resolution.get("position", npc_position)
	var threat_ids: Array[String] = []
	for raw_threat in threats:
		threat_ids.append(str((raw_threat as Dictionary).get("enemy_id", "")))
	var nearest_name := str(nearest_encounter.get("enemy_name", "敌军"))
	return {
		"target_id": "weighted_%d" % _stable_hash_text("%s:%s" % [npc_id, ",".join(threat_ids)]),
		"movement_phase": "station_weighted_avoidance",
		"target_policy": "weighted_enemy_repulsion",
		"target_name": (
			"远离%s的避战方向" % nearest_name
			if threats.size() == 1
			else "远离%d名敌军的加权避战方向" % threats.size()
		),
		"position": position,
		"desired_position": desired_position,
		"direction": direction,
		"threat_count": threats.size(),
		"threats": threats,
		"weight_formula": "inverse_distance_power",
		"weight_exponent": _get_avoidance_weight_exponent(),
		"enemy_distance_after": _get_min_enemy_distance(position),
		"enemy_distance_before": float(nearest_encounter.get("distance", 0.0)),
		"travel_distance": npc_position.distance_to(position),
		"desired_travel_distance": _get_avoidance_target_distance(),
		"boundary_limited": bool(resolution.get("boundary_limited", false)),
		"navigation_adjusted": bool(resolution.get("navigation_adjusted", false)),
		"navigation_resolution_reason": str(resolution.get("reason", ""))
	}


func _select_outside_avoidance_reentry_target(
	npc_id: String,
	npc_position: Vector3,
	nearest_encounter: Dictionary,
	threats: Array
) -> Dictionary:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller == null or not controller.has_method("get_front_gate_inside_avoidance_target"):
		return {}
	var resolution: Dictionary = controller.get_front_gate_inside_avoidance_target()
	if not bool(resolution.get("ok", false)):
		return {}
	var target_position: Vector3 = resolution.get("position", npc_position)
	var direction := target_position - npc_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	var serialized_threats: Array[Dictionary] = []
	for raw_threat in threats:
		serialized_threats.append((raw_threat as Dictionary).duplicate(true))
	return {
		"target_id": "front_gate_inside_reentry",
		"target_name": "正门内侧回站点",
		"movement_phase": "returning_to_station",
		"target_policy": "front_gate_inside_reentry",
		"reentry_gate_id": str(resolution.get("gate_id", "front_gate")),
		"position": target_position,
		"desired_position": resolution.get("desired_position", target_position),
		"direction": direction,
		"threat_count": serialized_threats.size(),
		"threats": serialized_threats,
		"weight_formula": "reentry_overrides_repulsion_until_inside",
		"weight_exponent": _get_avoidance_weight_exponent(),
		"enemy_distance_after": _get_min_enemy_distance(target_position),
		"enemy_distance_before": float(nearest_encounter.get("distance", 0.0)),
		"travel_distance": npc_position.distance_to(target_position),
		"desired_travel_distance": npc_position.distance_to(
			resolution.get("desired_position", target_position)
		),
		"boundary_limited": true,
		"navigation_adjusted": bool(resolution.get("navigation_adjusted", false)),
		"navigation_resolution_reason": str(resolution.get("reason", ""))
	}


func _build_avoidance_threat_field(
	npc_position: Vector3,
	detection_range: float,
	npc_id: String = ""
) -> Dictionary:
	var threats: Array[Dictionary] = []
	var weighted_direction := Vector3.ZERO
	var weight_exponent := _get_avoidance_weight_exponent()
	var minimum_weight_distance := _get_avoidance_min_weight_distance()
	for enemy_id in get_active_enemy_ids():
		var enemy: Dictionary = _active_enemies.get(enemy_id, {})
		if enemy.is_empty() or not bool(enemy.get("alive", true)):
			continue
		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		var away_direction := npc_position - enemy_position
		away_direction.y = 0.0
		var distance := away_direction.length()
		if distance > detection_range:
			continue
		if distance <= 0.001:
			away_direction = _fallback_avoidance_direction("%s:%s" % [npc_id, enemy_id])
		else:
			away_direction /= distance
		var weighted_distance := maxf(minimum_weight_distance, distance)
		var weight := pow(detection_range / weighted_distance, weight_exponent)
		weighted_direction += away_direction * weight
		threats.append({
			"enemy_id": enemy_id,
			"enemy_name": str(enemy.get("name", enemy_id)),
			"position": enemy_position,
			"distance": distance,
			"weight": weight,
			"away_direction": away_direction
		})
	threats.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := float(left.get("distance", INF))
		var right_distance := float(right.get("distance", INF))
		return str(left.get("enemy_id", "")) < str(right.get("enemy_id", "")) if is_equal_approx(left_distance, right_distance) else left_distance < right_distance
	)
	if threats.is_empty():
		return {"threats": [], "direction": Vector3.ZERO, "nearest_encounter": {}}
	if weighted_direction.length_squared() <= 0.000001:
		weighted_direction = threats[0].get("away_direction", _fallback_avoidance_direction(npc_id))
	weighted_direction.y = 0.0
	weighted_direction = weighted_direction.normalized()
	var nearest: Dictionary = threats[0]
	return {
		"threats": threats,
		"direction": weighted_direction,
		"nearest_encounter": {
			"enemy_id": str(nearest.get("enemy_id", "")),
			"enemy_name": str(nearest.get("enemy_name", "")),
			"position": nearest.get("position", Vector3.ZERO),
			"distance": float(nearest.get("distance", 0.0))
		}
	}


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
	_clear_friendly_targeting_runtime()
	_active_melee_swings.clear()
	_pending_melee_damage_commits.clear()
	var projectile_cleanup_result := _clear_battlefield_projectiles(reason)
	var time_slowdown_result := _sync_enemy_presence_time_slowdown(reason)
	var result := {
		"ok": true,
		"reason": reason,
		"projectile_cleanup_result": projectile_cleanup_result,
		"time_slowdown_result": time_slowdown_result,
		"combat_to_work": [],
		"rally_to_work": [],
		"avoid_to_work": [],
		"avoidance_ended": [],
		"battle_end_result": {}
	}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("set_npc_behavior_mode"):
		result["battle_end_result"] = _finish_active_battle(reason)
		result["victory_result"] = _evaluate_five_wave_victory(result["battle_end_result"], reason)
		result["wave_clear_notification_numbers"] = _emit_successful_wave_clear_events(result["battle_end_result"])
		result["formal_world_exit_result"] = _exit_default_formal_combat_world(reason)
		_emit_battle_end_audio(result)
		return result
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		if npc_system.has_method("update_npc_state"):
			npc_system.update_npc_state(npc_id, {
				"combat_attack_last_sequence_time": -1.0,
				"combat_attack_next_sequence_time": 0.0,
				"combat_attack_sequence_lock_remaining": 0.0
			})
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
				"request_plan_reevaluation": false,
				"resume_current_plan": true
			})
			(result["rally_to_work"] as Array).append(rally_result)
			_active_rallies.erase(npc_id)
		elif mode == BEHAVIOR_MODE_AVOID_COMBAT:
			var ended_event := _complete_npc_avoidance(npc_id, reason)
			var avoid_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_WORK, reason, {
				"interrupt": true,
				"force_idle": true,
				"request_plan_reevaluation": false,
				"resume_current_plan": true
			})
			avoid_result["avoidance_ended_event"] = ended_event
			(result["avoid_to_work"] as Array).append(avoid_result)
			(result["avoidance_ended"] as Array).append(ended_event)
	result["battle_end_result"] = _finish_active_battle(reason)
	result["victory_result"] = _evaluate_five_wave_victory(result["battle_end_result"], reason)
	result["wave_clear_notification_numbers"] = _emit_successful_wave_clear_events(result["battle_end_result"])
	result["formal_world_exit_result"] = _exit_default_formal_combat_world(reason)
	_emit_battle_end_audio(result)
	_last_mode_transition_result = result.duplicate(true)
	return result


func _emit_battle_end_audio(result: Dictionary) -> void:
	var battle_end: Dictionary = result.get("battle_end_result", {}) if result.get("battle_end_result", {}) is Dictionary else {}
	if str(battle_end.get("error", "")) == "no_active_battle":
		_last_defeated_enemy_audio_position = null
		return
	var victory: Dictionary = result.get("victory_result", {}) if result.get("victory_result", {}) is Dictionary else {}
	if not bool(victory.get("triggered", false)) and _last_failure_result.is_empty():
		_emit_combat_audio_event({
			"event_type": "wave_cleared",
			"target_type": "enemy",
			"world_position": (
				_last_defeated_enemy_audio_position
				if _last_defeated_enemy_audio_position is Vector3
				else Vector3.ZERO
			),
		})
	_last_defeated_enemy_audio_position = null


func _emit_successful_wave_clear_events(battle_end: Dictionary) -> Array[int]:
	var notified_wave_numbers: Array[int] = []
	if not bool(battle_end.get("ok", true)) or int(battle_end.get("remaining_enemy_count", -1)) != 0:
		return notified_wave_numbers
	if not _last_failure_result.is_empty():
		return notified_wave_numbers
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and bool(game_state.get("game_over")) and str(game_state.get("game_result")) == "failure":
		return notified_wave_numbers
	var expected_enemy_count := int(battle_end.get("started_enemy_count", 0))
	for raw_additional_wave in battle_end.get("additional_waves", []):
		if raw_additional_wave is Dictionary:
			expected_enemy_count += int((raw_additional_wave as Dictionary).get("enemy_count", 0))
	if expected_enemy_count <= 0 or int(battle_end.get("resolved_defeated_enemy_count", 0)) < expected_enemy_count:
		return notified_wave_numbers
	var wave_number := int(battle_end.get("wave_number", 0))
	if wave_number > 0:
		notified_wave_numbers.append(wave_number)
	for raw_additional_wave in battle_end.get("additional_waves", []):
		if not raw_additional_wave is Dictionary:
			continue
		var additional_wave_number := int((raw_additional_wave as Dictionary).get("wave_number", 0))
		if additional_wave_number > 0 and not notified_wave_numbers.has(additional_wave_number):
			notified_wave_numbers.append(additional_wave_number)
	notified_wave_numbers.sort()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("combat_wave_cleared"):
		for cleared_wave_number in notified_wave_numbers:
			event_bus.combat_wave_cleared.emit(cleared_wave_number)
	return notified_wave_numbers


func _enter_default_formal_combat_world() -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system == null
		or not npc_system.has_method("begin_formal_combat_world")
		or not npc_system.has_method("get_npc_ids")
	):
		return {"ok": false, "reason": "npc_formal_combat_world_api_missing"}
	var requested_ids: Array[String] = npc_system.get_npc_ids()
	var combatant_ids: Array[String] = []
	for entry in _build_friendly_combatant_roster():
		var npc_id := str(entry.get("npc_id", ""))
		if not npc_id.is_empty():
			combatant_ids.append(npc_id)
	var result: Dictionary = npc_system.begin_formal_combat_world(requested_ids)
	var migrated_ids: Array = result.get("migrated_npc_ids", [])
	var noncombatant_ids: Array[String] = []
	for raw_npc_id in migrated_ids:
		var npc_id := str(raw_npc_id)
		if not combatant_ids.has(npc_id):
			noncombatant_ids.append(npc_id)
	# Keep the P7b key as a compatibility alias for callers that only need the
	# armed roster, while A5-P1 exposes the full spatial population explicitly.
	result["eligible_npc_ids"] = combatant_ids
	result["requested_npc_ids"] = requested_ids
	result["combatant_npc_ids"] = combatant_ids
	result["noncombatant_npc_ids"] = noncombatant_ids
	result["world_mode"] = "formal_runtime"
	return result


func _exit_default_formal_combat_world(reason: String) -> Dictionary:
	if not _default_formal_wave_active:
		return {"ok": true, "active": false, "reason": "formal_runtime_not_active"}
	var npc_result: Dictionary = {}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var preserved_escape_ids := _get_active_formal_escape_ids(npc_system)
	if npc_system != null and npc_system.has_method("end_formal_combat_world"):
		npc_result = npc_system.end_formal_combat_world(reason, preserved_escape_ids)
	var preview_result: Dictionary = {}
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if preserved_escape_ids.is_empty() and controller != null and controller.has_method("set_runtime_formal_world_enabled"):
		preview_result = controller.set_runtime_formal_world_enabled(false)
	_formal_escape_world_hold = not preserved_escape_ids.is_empty()
	var previous_wave_number := _default_formal_wave_number
	_default_formal_wave_active = false
	_default_formal_wave_number = 0
	return {
		"ok": bool(npc_result.get("ok", true)),
		"active": false,
		"reason": reason,
		"wave_number": previous_wave_number,
		"escape_world_hold": _formal_escape_world_hold,
		"preserved_escape_npc_ids": preserved_escape_ids,
		"npc_result": npc_result,
		"preview_result": preview_result
	}


func _get_active_formal_escape_ids(npc_system: Node = null) -> Array[String]:
	var result: Array[String] = []
	var resolved_npc_system := npc_system if npc_system != null else get_node_or_null(NPC_SYSTEM_PATH)
	if (
		resolved_npc_system == null
		or not resolved_npc_system.has_method("get_npc_ids")
		or not resolved_npc_system.has_method("is_npc_in_formal_combat_world")
	):
		return result
	for npc_id in resolved_npc_system.get_npc_ids():
		if (
			resolved_npc_system.is_npc_in_formal_combat_world(npc_id)
			and is_npc_escaping(npc_id)
		):
			result.append(npc_id)
	return result


func _release_formal_escape_world_if_idle(reason: String) -> void:
	if not _formal_escape_world_hold or _default_formal_wave_active:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if not _get_active_formal_escape_ids(npc_system).is_empty():
		return
	if npc_system != null and npc_system.has_method("end_formal_combat_world"):
		npc_system.end_formal_combat_world(reason)
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("set_runtime_formal_world_enabled"):
		controller.set_runtime_formal_world_enabled(false)
	_formal_escape_world_hold = false


func debug_get_default_formal_combat_world_snapshot() -> Dictionary:
	var npc_snapshot: Dictionary = {}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_formal_combat_world_snapshot"):
		npc_snapshot = npc_system.get_formal_combat_world_snapshot()
	return {
		"ok": true,
		"active": _default_formal_wave_active,
		"escape_world_hold": _formal_escape_world_hold,
		"wave_number": _default_formal_wave_number,
		"active_enemy_count": _active_enemies.size(),
		"formal_enemy_count": _formal_first_wave_slices.size(),
		"npc_world": npc_snapshot
	}


func _on_npc_revived(npc_id: String) -> void:
	_route_revived_npc(npc_id)


func _on_npc_unconscious(npc_id: String) -> void:
	_friendly_enemy_reacquire_requests.erase(npc_id)
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
	_last_defeated_enemy_audio_position = null
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
		"resolved_defeated_enemy_count": 0,
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
	var first_enemy: Dictionary = spawned[0]
	_emit_combat_audio_event({
		"event_type": "battle_started",
		"target_type": "enemy",
		"target_id": str(first_enemy.get("id", "")),
		"wave_number": int(wave.get("wave_number", 0)),
		"world_position": first_enemy.get("position", Vector3.ZERO),
	})
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


func _record_battle_resolved_enemy_defeat() -> void:
	if _active_battle.is_empty():
		return
	_active_battle["resolved_defeated_enemy_count"] = int(
		_active_battle.get("resolved_defeated_enemy_count", 0)
	) + 1


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


func _get_rally_eligibility(npc_id: String, ignore_target_lock: bool = false) -> Dictionary:
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
	if npc_system.has_method("can_npc_act") and not npc_system.can_npc_act(npc_id):
		return {"ok": false, "npc_id": npc_id, "reason": "cannot_act"}
	if bool(state.get("unconscious", false)):
		return {"ok": false, "npc_id": npc_id, "reason": "unconscious"}
	var snapshot: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
	if not bool(snapshot.get("has_main_weapon", false)):
		return {"ok": false, "npc_id": npc_id, "reason": "no_main_weapon"}
	var locked_target_id := _get_alarm_blocking_target_lock(state)
	if not ignore_target_lock and not locked_target_id.is_empty():
		return {
			"ok": false,
			"npc_id": npc_id,
			"reason": "target_locked",
			"locked_enemy_id": locked_target_id,
			"behavior_mode": str(state.get("behavior_mode", ""))
		}
	return {
		"ok": true,
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"unit_type": str(snapshot.get("unit_type", "")),
		"unit_type_label": str(snapshot.get("unit_type_label", "")),
		"has_mount": bool(snapshot.get("has_mount", false)),
		"is_mounted": bool(state.get("combat_mounted", false)),
		"previous_behavior_mode": str(state.get("behavior_mode", BEHAVIOR_MODE_WORK)),
		"main_weapon_id": str(snapshot.get("main_weapon_id", "")),
		"main_weapon_name": str(snapshot.get("main_weapon_name", ""))
}


func _get_alarm_blocking_target_lock(state: Dictionary) -> String:
	if str(state.get("behavior_mode", "")) != BEHAVIOR_MODE_COMBAT:
		return ""
	for state_key in [
		"combat_target_enemy_id",
		"combat_attack_target_enemy_id",
		"combat_strategy_move_enemy_id"
	]:
		var enemy_id := str(state.get(state_key, "")).strip_edges()
		if not enemy_id.is_empty() and _active_enemies.has(enemy_id):
			var enemy: Dictionary = _active_enemies.get(enemy_id, {})
			if bool(enemy.get("alive", true)) and int(enemy.get("hp", 1)) > 0:
				return enemy_id
	return ""


func _build_rally_formation(eligible: Array[Dictionary]) -> Array[Dictionary]:
	var melee: Array[Dictionary] = []
	var ranged: Array[Dictionary] = []
	var mounted: Array[Dictionary] = []
	for entry in eligible:
		var unit_type := str(entry.get("unit_type", ""))
		if unit_type in ["cavalry", "mounted_ranged"]:
			mounted.append(entry)
		elif unit_type in ["melee_infantry", "polearm_infantry"]:
			melee.append(entry)
		else:
			ranged.append(entry)
	_sort_rally_entries(melee)
	_sort_rally_entries(ranged)
	_sort_rally_entries(mounted)
	var config := _get_rally_formation_world_config()
	var center: Vector3 = config.get("center", Vector3(0.0, 0.0, 15.2))
	var forward: Vector3 = config.get("enemy_direction", Vector3.FORWARD)
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var lateral := Vector3(forward.z, 0.0, -forward.x).normalized()
	var result: Array[Dictionary] = []
	result.append_array(_assign_rally_line_positions(
		melee,
		"melee_front",
		center + forward * float(config.get("melee_forward_offset", 2.5)),
		forward,
		lateral,
		config
	))
	result.append_array(_assign_rally_line_positions(
		ranged,
		"ranged_rear",
		center + forward * float(config.get("ranged_forward_offset", -2.5)),
		forward,
		lateral,
		config
	))
	result.append_array(_assign_rally_wing_positions(mounted, center, forward, lateral, config))
	return result


func _sort_rally_entries(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("npc_id", "")) < str(b.get("npc_id", ""))
	)


func _get_rally_formation_world_config() -> Dictionary:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("get_friendly_rally_world_config"):
		var config: Dictionary = controller.get_friendly_rally_world_config()
		if not config.is_empty():
			return config
	return {
		"schema_version": "friendly_rally_legacy_fallback",
		"area_id": RALLY_LOCATION_ID,
		"display_name": RALLY_LOCATION_NAME,
		"center": Vector3(0.0, 0.0, 15.2),
		"enemy_direction": Vector3.FORWARD,
		"melee_forward_offset": RALLY_FRONT_Z - 15.2,
		"ranged_forward_offset": RALLY_BACK_Z - 15.2,
		"line_spacing": RALLY_COLUMN_SPACING,
		"line_row_spacing": RALLY_ROW_SPACING,
		"max_line_columns": 5,
		"cavalry_lateral_offset": 5.2,
		"cavalry_forward_offset": 0.0,
		"cavalry_depth_spacing": 2.2
	}


func _build_mount_completion_rally_entry(npc_id: String, horse_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return {}
	# Build against the complete currently actionable armed roster while ignoring
	# combat locks. This keeps cavalry-wing slots deterministic as riders mount at
	# different times instead of assigning every late rider the same one-unit slot.
	var roster: Array[Dictionary] = []
	for raw_npc_id in npc_system.get_npc_ids():
		var eligibility := _get_rally_eligibility(str(raw_npc_id), true)
		if bool(eligibility.get("ok", false)):
			roster.append(eligibility)
	for raw_entry in _build_rally_formation(roster):
		var entry: Dictionary = raw_entry
		if str(entry.get("npc_id", "")) != npc_id:
			continue
		entry["has_mount"] = true
		entry["is_mounted"] = true
		entry["horse_id"] = horse_id
		return entry
	return {}


func _assign_rally_line_positions(
	entries: Array[Dictionary],
	row_name: String,
	row_center: Vector3,
	forward: Vector3,
	lateral: Vector3,
	config: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if entries.is_empty():
		return result
	var column_spacing := maxf(0.1, float(config.get("line_spacing", RALLY_COLUMN_SPACING)))
	var row_spacing := maxf(0.1, float(config.get("line_row_spacing", RALLY_ROW_SPACING)))
	var max_columns := maxi(1, int(config.get("max_line_columns", 5)))
	for index in range(entries.size()):
		var entry := entries[index].duplicate(true)
		var row_index := index / max_columns
		var column_index := index % max_columns
		var remaining := entries.size() - row_index * max_columns
		var columns_in_row := mini(max_columns, remaining)
		var lateral_offset := (float(column_index) - float(columns_in_row - 1) * 0.5) * column_spacing
		var position := row_center + lateral * lateral_offset - forward * float(row_index) * row_spacing
		entry["formation_row"] = row_name
		entry["formation_group"] = row_name
		entry["formation_index"] = index
		entry["position"] = _snap_rally_position(position)
		result.append(entry)
	return result


func _assign_rally_wing_positions(
	entries: Array[Dictionary],
	center: Vector3,
	forward: Vector3,
	lateral: Vector3,
	config: Dictionary
) -> Array[Dictionary]:
	var left: Array[Dictionary] = []
	var right: Array[Dictionary] = []
	for index in range(entries.size()):
		if index % 2 == 0:
			left.append(entries[index])
		else:
			right.append(entries[index])
	var result: Array[Dictionary] = []
	result.append_array(_assign_single_rally_wing(left, "cavalry_left", -1.0, center, forward, lateral, config))
	result.append_array(_assign_single_rally_wing(right, "cavalry_right", 1.0, center, forward, lateral, config))
	return result


func _assign_single_rally_wing(
	entries: Array[Dictionary],
	row_name: String,
	side: float,
	center: Vector3,
	forward: Vector3,
	lateral: Vector3,
	config: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lateral_offset := maxf(0.1, float(config.get("cavalry_lateral_offset", 5.2))) * side
	var forward_offset := float(config.get("cavalry_forward_offset", 0.0))
	var depth_spacing := maxf(0.1, float(config.get("cavalry_depth_spacing", 2.2)))
	for index in range(entries.size()):
		var entry := entries[index].duplicate(true)
		var depth_offset := (float(index) - float(entries.size() - 1) * 0.5) * depth_spacing
		var position := center + lateral * lateral_offset + forward * (forward_offset + depth_offset)
		entry["formation_row"] = row_name
		entry["formation_group"] = "cavalry_wings"
		entry["formation_index"] = index
		entry["formation_side"] = "left" if side < 0.0 else "right"
		entry["position"] = _snap_rally_position(position)
		result.append(entry)
	return result


func _snap_rally_position(target: Vector3) -> Vector3:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("get_production_navigation_map_rid"):
		var navigation_map: RID = controller.get_production_navigation_map_rid()
		if navigation_map.is_valid():
			target = NavigationServer3D.map_get_closest_point(navigation_map, target)
	return target


func _start_npc_rally(entry: Dictionary, mode_reason: String = "combat_alarm") -> Dictionary:
	var npc_id := str(entry.get("npc_id", ""))
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_id.is_empty() or npc_system == null:
		return {}

	entry = entry.duplicate(true)
	entry["command_reason"] = mode_reason
	_active_rallies.erase(npc_id)
	if _active_avoidances.has(npc_id):
		_complete_npc_avoidance(npc_id, "combat_alarm_rally_command")
	_clear_npc_attack_runtime_for_rally(npc_id)
	var position: Vector3 = entry.get("position", Vector3.ZERO)
	var encounter := _find_rally_combat_encounter(npc_id)
	var has_mount := bool(entry.get("has_mount", false))
	var is_mounted := has_mount and bool(entry.get("is_mounted", false))
	var rally_state := {
		"current_action": "meeting_assigned_horse" if has_mount and not is_mounted else "rallying_defense_line",
		"current_location": RALLY_LOCATION_ID,
		"current_location_name": RALLY_LOCATION_NAME,
		"last_action_result": "combat_rally_arrived",
		"combat_mode": "rally",
		"combat_mounted": is_mounted,
		"combat_mount_phase": "mounted" if is_mounted else ("going_to_stable_horse" if has_mount else "unmounted"),
		"combat_target_enemy_id": "",
		"combat_target_selection_reason": "",
		"combat_target_scope": "",
		"combat_strategy_move_target_id": "",
		"combat_strategy_move_target_name": "",
		"combat_strategy_move_target_position": {},
		"combat_strategy_move_enemy_id": "",
		"avoidance_target_id": "",
		"avoidance_target_name": "",
		"avoidance_target_position": {},
		"facing_direction": "front_forest"
	}
	var target_id := "%s%s" % [RALLY_TARGET_PREFIX, npc_id]
	if not encounter.is_empty():
		_switch_rally_to_combat(npc_id, entry, encounter)
		return _serialize_rally(_active_rallies.get(npc_id, {}))
	if npc_system.has_method("set_npc_behavior_mode"):
		var mode_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, BEHAVIOR_MODE_RALLY, mode_reason, {
			"state_changes": rally_state,
			"request_plan_reevaluation": false
		})
		if not bool(mode_result.get("ok", false)):
			return {}
	if has_mount and not is_mounted:
		var mounting_rally := entry.duplicate(true)
		mounting_rally["status"] = "mounting"
		mounting_rally["target_id"] = target_id
		mounting_rally["rallied_elapsed_seconds"] = 0.0
		mounting_rally["rally_wait_remaining_seconds"] = RALLY_WAIT_TIMEOUT_SECONDS
		var mounting_event := _log_combat_rally_started(npc_id, entry, position)
		mounting_rally["event_id"] = str(mounting_event.get("event_id", ""))
		_active_rallies[npc_id] = mounting_rally
		return _serialize_rally(mounting_rally)
	if not npc_system.has_method("move_npc_to_world_position"):
		return {}
	var moved: bool = npc_system.move_npc_to_world_position(
		npc_id,
		target_id,
		RALLY_LOCATION_NAME,
		position,
		rally_state,
		{"movement_purpose": "friendly_rally"}
	)
	if not moved:
		return {}
	if npc_system.has_method("update_npc_state"):
		npc_system.update_npc_state(npc_id, {
			"combat_mode": "rally",
			"combat_mounted": is_mounted,
			"combat_mount_phase": "mounted" if is_mounted else "unmounted",
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


func _request_rally_movement(
	npc_id: String,
	rally: Dictionary,
	reason: String,
	is_recovery: bool
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("move_npc_to_world_position"):
		return {"ok": false, "reason": "npc_movement_system_missing", "npc_id": npc_id}
	var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
	var is_mounted := bool(state.get("combat_mounted", false))
	var target_id := str(rally.get("target_id", "%s%s" % [RALLY_TARGET_PREFIX, npc_id]))
	var target_position: Vector3 = rally.get("position", _get_npc_position(npc_id))
	var arrival_state := {
		"current_action": "rallying_defense_line",
		"current_location": RALLY_LOCATION_ID,
		"current_location_name": RALLY_LOCATION_NAME,
		"last_action_result": "combat_rally_arrived",
		"combat_mode": "rally",
		"combat_mounted": is_mounted,
		"combat_mount_phase": "mounted" if is_mounted else "unmounted",
		"facing_direction": "front_forest"
	}
	var moved := bool(npc_system.move_npc_to_world_position(
		npc_id,
		target_id,
		RALLY_LOCATION_NAME,
		target_position,
		arrival_state,
		{"movement_purpose": "friendly_rally"}
	))
	var next_rally := rally.duplicate(true)
	next_rally["status"] = "moving" if moved else "unavailable"
	next_rally["target_id"] = target_id
	if is_recovery:
		next_rally["movement_recovery_count"] = int(rally.get("movement_recovery_count", 0)) + 1
		next_rally["last_movement_recovery_reason"] = reason
	if not moved:
		next_rally["movement_failure_reason"] = reason
	else:
		next_rally.erase("movement_failure_reason")
	_active_rallies[npc_id] = next_rally
	return {
		"ok": moved,
		"npc_id": npc_id,
		"reason": reason,
		"rally": _serialize_rally(next_rally)
	}


func _clear_npc_attack_runtime_for_rally(npc_id: String) -> void:
	var swing_key := _melee_swing_key("friendly", npc_id)
	_active_melee_swings.erase(swing_key)
	_pending_melee_damage_commits.erase(swing_key)
	_friendly_enemy_reacquire_requests.erase(npc_id)


func _find_rally_combat_encounter(npc_id: String) -> Dictionary:
	var scope := _get_friendly_target_scope(npc_id)
	if not bool(scope.get("station_breached", false)):
		# A rally route intentionally crosses the front-gate station boundary.
		# Re-evaluate the actor's current side of that boundary: outside uses the
		# ordinary radius, while inside retains the station-plus-radius union.
		scope["scope"] = (
			"rally_transition_station_plus_unified_radius"
			if bool(scope.get("npc_inside_station", false))
			else "rally_transition_radius"
		)
		scope["station_enemy_only"] = false
		scope["detection_range"] = _get_friendly_target_detection_range()
	return _find_nearest_friendly_combat_enemy(npc_id, scope)


func _switch_rally_to_combat(npc_id: String, rally: Dictionary, encounter: Dictionary) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var has_mount := _does_npc_have_mount(npc_id)
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
	var is_mounted := has_mount and bool(npc_state.get("combat_mounted", false))
	var enemy_id := str(encounter.get("enemy_id", ""))
	var changes := {
		"current_action": "combat_ready",
		"movement_target": "",
		"movement_target_name": "",
		"current_location": RALLY_LOCATION_ID,
		"current_location_name": RALLY_LOCATION_NAME,
		"last_action_result": "enemy_encountered_during_rally",
		"combat_mode": "combat",
		"combat_mounted": is_mounted,
		"combat_mount_phase": "mounted" if is_mounted else ("going_to_stable_horse" if has_mount else "unmounted"),
		"combat_target_enemy_id": enemy_id,
		"facing_direction": "front_forest"
	}
	if npc_system.has_method("set_npc_behavior_mode"):
		var mode_result: Dictionary = npc_system.set_npc_behavior_mode(
			npc_id,
			BEHAVIOR_MODE_COMBAT,
			"enemy_inside_station" if _is_enemy_inside_station(enemy_id) else "enemy_contact",
			{
			"state_changes": changes,
			"request_plan_reevaluation": false
			}
		)
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
	if has_mount and not is_mounted:
		var mount_route_result := _ensure_wartime_mount_route(
			npc_id,
			"rally_enemy_contact_handoff"
		)
		# The ensure call may synchronously complete mounting and replace the rally.
		next_rally = _active_rallies.get(npc_id, next_rally)
		next_rally["mount_route_result"] = mount_route_result
		_active_rallies[npc_id] = next_rally
	_log_combat_rally_encounter(npc_id, next_rally, encounter)


func _ensure_wartime_mount_route(npc_id: String, reason: String) -> Dictionary:
	if npc_id.is_empty():
		return {"ok": false, "reason": "npc_id_missing"}
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("ensure_wartime_mount_route"):
		return {"ok": false, "reason": "horse_mount_route_api_missing", "npc_id": npc_id}
	return horse_system.ensure_wartime_mount_route(npc_id, reason)


func handle_npc_mount_ready(npc_id: String, horse_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_state"):
		return {"ok": false, "reason": "npc_system_missing", "npc_id": npc_id, "horse_id": horse_id}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var mode := str(state.get("behavior_mode", ""))
	if [BEHAVIOR_MODE_RALLY, BEHAVIOR_MODE_COMBAT].has(mode):
		var entry: Dictionary = (
			(_active_rallies.get(npc_id, {}) as Dictionary).duplicate(true)
			if _active_rallies.get(npc_id, {}) is Dictionary
			else {}
		)
		if entry.is_empty():
			entry = _build_mount_completion_rally_entry(npc_id, horse_id)
		if entry.is_empty():
			return {
				"ok": false,
				"reason": "mount_completion_rally_entry_missing",
				"npc_id": npc_id,
				"horse_id": horse_id,
				"mode": mode
			}
		entry["has_mount"] = true
		entry["is_mounted"] = true
		entry["horse_id"] = horse_id
		var rally_result := _start_npc_rally(entry, "horse_mounted_auto_rally")
		return {
			"ok": bool(rally_result.get("ok", false)),
			"npc_id": npc_id,
			"horse_id": horse_id,
			"mode_before_mount_command": mode,
			"mode": str(npc_system.get_npc_state(npc_id).get("behavior_mode", mode)),
			"rally": rally_result
		}
	return {"ok": false, "reason": "npc_not_in_wartime_mode", "npc_id": npc_id, "horse_id": horse_id, "mode": mode}


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


func _find_nearest_station_enemy(position: Vector3) -> Dictionary:
	var nearest := {}
	var nearest_distance := INF
	for enemy_id in get_active_enemy_ids():
		if not _is_enemy_inside_station(enemy_id):
			continue
		var enemy: Dictionary = _active_enemies.get(enemy_id, {})
		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		var distance := position.distance_to(enemy_position)
		if distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest = {
			"enemy_id": enemy_id,
			"enemy_name": str(enemy.get("name", enemy_id)),
			"position": enemy_position,
			"distance": distance,
			"inside_station": true
		}
	return nearest


func _has_station_enemy() -> bool:
	for enemy_id in get_active_enemy_ids():
		if _is_enemy_inside_station(enemy_id):
			return true
	return false


func _is_enemy_inside_station(enemy_id: String) -> bool:
	if enemy_id.is_empty() or not _active_enemies.has(enemy_id):
		return false
	var enemy := _active_enemies.get(enemy_id, {}) as Dictionary
	if enemy.is_empty() or not bool(enemy.get("alive", true)):
		return false
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	return (
		controller != null
		and controller.has_method("is_world_position_inside_station")
		and bool(controller.is_world_position_inside_station(enemy.get("position", Vector3.ZERO)))
	)


func _nearest_enemy_for_combat_strategy(npc_id: String, strategy_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var state: Dictionary = (
		npc_system.get_npc_state(npc_id)
		if npc_system != null and npc_system.has_method("get_npc_state")
		else {}
	)
	return _select_friendly_combat_target_lock(npc_id, state)


func _get_friendly_target_detection_range() -> float:
	return maxf(
		0.1,
		float(
			_get_friendly_station_response_config().get(
				"combat_target_detection_range",
				FRIENDLY_TARGET_DETECTION_RANGE_FALLBACK
			)
		)
	)


func _is_world_position_inside_station(world_position: Vector3) -> bool:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	return (
		controller != null
		and controller.has_method("is_world_position_inside_station")
		and bool(controller.is_world_position_inside_station(world_position))
	)


func _is_npc_inside_station(npc_id: String) -> bool:
	return _is_world_position_inside_station(_get_npc_position(npc_id))


func _get_friendly_target_scope(npc_id: String) -> Dictionary:
	var inside_station := _is_npc_inside_station(npc_id)
	var station_breached := _has_station_enemy()
	var rally: Dictionary = _active_rallies.get(npc_id, {}) if _active_rallies.get(npc_id, {}) is Dictionary else {}
	var rally_transition := str(rally.get("status", "")) == "combat_ready"
	# An inside defender sees the union of the complete station polygon and the
	# ordinary authored detection circle. Neither half receives target priority:
	# the normal nearest-enemy ordering runs across the complete union. Outside
	# responders retain the station-breach emergency rule, so a defender still on
	# an exterior rally route can globally acquire an intruder after a breach.
	var include_station_enemies := inside_station or station_breached
	var station_enemy_only := station_breached and not inside_station
	var scope_name := "unified_radius"
	if inside_station:
		scope_name = (
			"station_breach_plus_unified_radius"
			if station_breached
			else (
				"rally_transition_station_plus_unified_radius"
				if rally_transition
				else "entire_station_plus_unified_radius"
			)
		)
	elif station_breached:
		scope_name = "station_breach_global"
	elif rally_transition:
		scope_name = "rally_transition_radius"
	return {
		"scope": scope_name,
		"npc_inside_station": inside_station,
		"station_breached": station_breached,
		"rally_transition": rally_transition,
		"include_station_enemies": include_station_enemies,
		"station_enemy_only": station_enemy_only,
		"detection_range": _get_friendly_target_detection_range()
	}


func _make_friendly_enemy_target(enemy_id: String, origin: Vector3) -> Dictionary:
	var target := _make_enemy_attack_target(enemy_id, origin)
	if target.is_empty():
		return {}
	target["enemy_id"] = enemy_id
	target["enemy_name"] = str(target.get("name", enemy_id))
	target["distance"] = _horizontal_vector_distance(origin, target.get("position", origin))
	return target


func _is_friendly_enemy_target_present(npc_id: String, enemy_id: String, scope: Dictionary) -> bool:
	var target := _make_friendly_enemy_target(enemy_id, _get_npc_position(npc_id))
	if target.is_empty():
		return false
	var enemy_inside_station := _is_enemy_inside_station(enemy_id)
	if bool(scope.get("station_enemy_only", false)):
		return enemy_inside_station
	if bool(scope.get("include_station_enemies", false)) and enemy_inside_station:
		return true
	return float(target.get("distance", INF)) <= float(scope.get("detection_range", 0.0)) + 0.000001


func _find_nearest_friendly_combat_enemy(npc_id: String, scope: Dictionary) -> Dictionary:
	var origin := _get_npc_position(npc_id)
	var station_enemy_only := bool(scope.get("station_enemy_only", false))
	var include_station_enemies := bool(scope.get("include_station_enemies", false))
	var candidates: Array[Dictionary] = []
	for enemy_id in get_active_enemy_ids():
		var enemy_inside_station := _is_enemy_inside_station(enemy_id)
		if station_enemy_only and not enemy_inside_station:
			continue
		var target := _make_friendly_enemy_target(enemy_id, origin)
		if target.is_empty():
			continue
		if (
			not station_enemy_only
			and not (include_station_enemies and enemy_inside_station)
			and float(target.get("distance", INF)) > float(scope.get("detection_range", 0.0)) + 0.000001
		):
			continue
		candidates.append(target)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := float(left.get("distance", INF))
		var right_distance := float(right.get("distance", INF))
		return str(left.get("id", "")) < str(right.get("id", "")) if is_equal_approx(left_distance, right_distance) else left_distance < right_distance
	)
	return candidates[0] if not candidates.is_empty() else {}


func _mark_friendly_target_choice(
	target: Dictionary,
	previous_target_id: String,
	scope: Dictionary,
	reason: String
) -> Dictionary:
	if target.is_empty():
		return {}
	var chosen := target.duplicate(true)
	chosen["previous_target_id"] = previous_target_id
	chosen["target_selection_reason"] = reason
	chosen["target_scope"] = str(scope.get("scope", ""))
	chosen["target_detection_range"] = (
		-1.0
		if bool(scope.get("station_enemy_only", false))
		else float(scope.get("detection_range", _get_friendly_target_detection_range()))
	)
	if not previous_target_id.is_empty() and previous_target_id != str(chosen.get("id", "")):
		_friendly_targeting_metrics["target_switches"] = int(
			_friendly_targeting_metrics.get("target_switches", 0)
		) + 1
	return chosen


func _select_friendly_combat_target_lock(npc_id: String, state: Dictionary) -> Dictionary:
	_friendly_targeting_metrics["evaluations"] = int(
		_friendly_targeting_metrics.get("evaluations", 0)
	) + 1
	var scope := _get_friendly_target_scope(npc_id)
	var previous_target_id := str(state.get("combat_target_enemy_id", ""))
	if _friendly_enemy_reacquire_requests.has(npc_id):
		var request := (_friendly_enemy_reacquire_requests.get(npc_id, {}) as Dictionary).duplicate(true)
		_friendly_enemy_reacquire_requests.erase(npc_id)
		var damage_target := _find_nearest_friendly_combat_enemy(npc_id, scope)
		if not damage_target.is_empty():
			damage_target["damage_reacquire_source_enemy_id"] = str(request.get("source_enemy_id", ""))
			damage_target["damage_reacquire_sequence"] = int(request.get("sequence", 0))
			_friendly_targeting_metrics["different_attacker_damage_reacquisitions"] = int(
				_friendly_targeting_metrics.get("different_attacker_damage_reacquisitions", 0)
			) + 1
			return _mark_friendly_target_choice(
				damage_target,
				previous_target_id,
				scope,
				"different_attacker_damage_nearest_enemy_reacquire"
			)
		_friendly_targeting_metrics["different_attacker_damage_no_candidate_consumptions"] = int(
			_friendly_targeting_metrics.get("different_attacker_damage_no_candidate_consumptions", 0)
		) + 1
		return {}

	if _is_friendly_enemy_target_present(npc_id, previous_target_id, scope):
		var held := _make_friendly_enemy_target(previous_target_id, _get_npc_position(npc_id))
		_friendly_targeting_metrics["locked_target_holds"] = int(
			_friendly_targeting_metrics.get("locked_target_holds", 0)
		) + 1
		return _mark_friendly_target_choice(held, previous_target_id, scope, "locked_enemy_present")

	var nearest := _find_nearest_friendly_combat_enemy(npc_id, scope)
	if nearest.is_empty():
		return {}
	if previous_target_id.is_empty():
		_friendly_targeting_metrics["initial_acquisitions"] = int(
			_friendly_targeting_metrics.get("initial_acquisitions", 0)
		) + 1
		return _mark_friendly_target_choice(nearest, previous_target_id, scope, "nearest_enemy_initial_lock")
	_friendly_targeting_metrics["invalid_target_reacquisitions"] = int(
		_friendly_targeting_metrics.get("invalid_target_reacquisitions", 0)
	) + 1
	return _mark_friendly_target_choice(nearest, previous_target_id, scope, "invalid_locked_enemy_nearest_reacquire")


func _record_friendly_enemy_damage_reacquire_request(
	npc_id: String,
	previous_target_enemy_id: String,
	source_enemy_id: String,
	damage_result: Dictionary
) -> void:
	if (
		npc_id.is_empty()
		or previous_target_enemy_id.is_empty()
		or source_enemy_id.is_empty()
		or previous_target_enemy_id == source_enemy_id
		or not bool(damage_result.get("ok", false))
		or int(damage_result.get("damage", 0)) <= 0
		or int(damage_result.get("hp_after", 0)) <= 0
		or not _active_enemies.has(source_enemy_id)
	):
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not _is_npc_combat_eligible(npc_id, npc_system):
		return
	var scope := _get_friendly_target_scope(npc_id)
	if not _is_friendly_enemy_target_present(npc_id, previous_target_enemy_id, scope):
		return
	_friendly_enemy_reacquire_sequence += 1
	_friendly_enemy_reacquire_requests[npc_id] = {
		"schema": "friendly_enemy_damage_reacquire_request_v1",
		"sequence": _friendly_enemy_reacquire_sequence,
		"created_frame": _formal_crowd_logic_frame,
		"source_enemy_id": source_enemy_id,
		"previous_target_enemy_id": previous_target_enemy_id,
		"scope_at_damage": str(scope.get("scope", ""))
	}
	_friendly_targeting_metrics["different_attacker_damage_signals"] = int(
		_friendly_targeting_metrics.get("different_attacker_damage_signals", 0)
	) + 1


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


func _get_friendly_station_response_config() -> Dictionary:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("get_friendly_station_response_config"):
		return controller.get_friendly_station_response_config()
	return {}


func _get_normal_contact_range() -> float:
	return maxf(
		0.1,
		float(_get_friendly_station_response_config().get("normal_contact_range", FRIENDLY_CONTACT_RANGE))
	)


func _get_max_active_enemy_ranged_attack_range() -> float:
	var maximum_range := 0.0
	for enemy_id in get_active_enemy_ids():
		var enemy := _active_enemies.get(enemy_id, {}) as Dictionary
		if enemy.is_empty() or not bool(enemy.get("alive", true)):
			continue
		if not str(enemy.get("weapon_type", "")) in RANGED_WEAPON_TYPES:
			continue
		maximum_range = maxf(maximum_range, float(enemy.get("attack_range", 0.0)))
	return maximum_range


func _get_avoidance_trigger_range() -> float:
	var config := _get_friendly_station_response_config()
	var detection_margin := maxf(
		0.1,
		float(config.get("avoidance_detection_range_margin", AVOIDANCE_DETECTION_MARGIN_FALLBACK))
	)
	return _get_enemy_target_detection_range({}) + detection_margin


func _get_avoidance_target_distance() -> float:
	return _get_avoidance_trigger_range()


func _get_avoidance_weight_exponent() -> float:
	return maxf(
		0.1,
		float(
			_get_friendly_station_response_config().get(
				"avoidance_weight_exponent",
				AVOIDANCE_WEIGHT_EXPONENT_FALLBACK
			)
		)
	)


func _get_keep_distance_retreat_trigger_range_ratio() -> float:
	return clampf(
		float(
			_get_friendly_station_response_config().get(
				"keep_distance_retreat_trigger_range_ratio",
				KEEP_DISTANCE_RETREAT_TRIGGER_RANGE_RATIO_FALLBACK
			)
		),
		0.05,
		0.95
	)


func _get_keep_distance_retreat_segment_range_ratio() -> float:
	return clampf(
		float(
			_get_friendly_station_response_config().get(
				"keep_distance_retreat_segment_range_ratio",
				KEEP_DISTANCE_RETREAT_SEGMENT_RANGE_RATIO_FALLBACK
			)
		),
		0.1,
		2.0
	)


func _get_keep_distance_retreat_arrival_tolerance() -> float:
	return clampf(
		float(
			_get_friendly_station_response_config().get(
				"keep_distance_retreat_arrival_tolerance",
				KEEP_DISTANCE_RETREAT_ARRIVAL_TOLERANCE_FALLBACK
			)
		),
		0.05,
		1.0
	)


func _get_avoidance_min_weight_distance() -> float:
	return maxf(
		0.1,
		float(
			_get_friendly_station_response_config().get(
				"avoidance_min_weight_distance",
				AVOIDANCE_MIN_WEIGHT_DISTANCE_FALLBACK
			)
		)
	)


func _get_avoidance_boundary_inset() -> float:
	return maxf(
		0.1,
		float(
			_get_friendly_station_response_config().get(
				"avoidance_boundary_inset",
				AVOIDANCE_BOUNDARY_INSET_FALLBACK
			)
		)
	)


func _get_avoidance_safe_distance() -> float:
	var config := _get_friendly_station_response_config()
	var minimum_distance := maxf(
		AVOIDANCE_DESIRED_DISTANCE,
		float(config.get("avoidance_min_safe_distance", AVOIDANCE_SAFE_DISTANCE_FALLBACK))
	)
	var ranged_margin := maxf(
		0.1,
		float(config.get("avoidance_ranged_safe_margin", AVOIDANCE_RANGED_SAFE_MARGIN_FALLBACK))
	)
	return maxf(minimum_distance, _get_max_active_enemy_ranged_attack_range() + ranged_margin)


func _is_proactive_combat_strategy(strategy_id: String) -> bool:
	var configured: Variant = _get_friendly_station_response_config().get(
		"proactive_strategy_ids",
		[STRATEGY_ATTACK]
	)
	if not configured is Array:
		return false
	return (configured as Array).has(strategy_id)


func _get_friendly_station_response_snapshot() -> Dictionary:
	var station_enemy_ids: Array[String] = []
	for enemy_id in get_active_enemy_ids():
		if _is_enemy_inside_station(enemy_id):
			station_enemy_ids.append(enemy_id)
	var locks: Array[Dictionary] = []
	var keep_distance_retreats: Array[Dictionary] = []
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc_ids") and npc_system.has_method("get_npc_state"):
		for raw_npc_id in npc_system.get_npc_ids():
			var npc_id := str(raw_npc_id)
			if not _is_npc_combat_eligible(npc_id, npc_system):
				continue
			var state: Dictionary = npc_system.get_npc_state(npc_id)
			var scope := _get_friendly_target_scope(npc_id)
			var target_enemy_id := str(state.get("combat_target_enemy_id", ""))
			locks.append({
				"npc_id": npc_id,
				"scope": str(scope.get("scope", "")),
				"npc_inside_station": bool(scope.get("npc_inside_station", false)),
				"station_breached": bool(scope.get("station_breached", false)),
				"include_station_enemies": bool(scope.get("include_station_enemies", false)),
				"station_enemy_only": bool(scope.get("station_enemy_only", false)),
				"target_enemy_id": target_enemy_id,
				"target_present": _is_friendly_enemy_target_present(npc_id, target_enemy_id, scope),
				"target_selection_reason": str(state.get("combat_target_selection_reason", "")),
				"different_attacker_damage_reacquire_pending": _friendly_enemy_reacquire_requests.has(npc_id)
			})
			if bool(state.get("keep_distance_retreat_active", false)):
				keep_distance_retreats.append({
					"npc_id": npc_id,
					"sequence": int(state.get("keep_distance_retreat_sequence", 0)),
					"target_id": str(state.get("keep_distance_retreat_target_id", "")),
					"target_position": state.get("keep_distance_retreat_target_position", {}),
					"desired_position": state.get("keep_distance_retreat_desired_position", {}),
					"direction": state.get("keep_distance_retreat_direction", {}),
					"threat_ids": state.get("keep_distance_retreat_threat_ids", []),
					"desired_travel_distance": float(state.get("keep_distance_retreat_desired_travel_distance", 0.0)),
					"actual_travel_distance": float(state.get("keep_distance_retreat_actual_travel_distance", 0.0)),
					"boundary_limited": bool(state.get("keep_distance_retreat_boundary_limited", false)),
					"navigation_adjusted": bool(state.get("keep_distance_retreat_navigation_adjusted", false)),
					"movement_recovery_count": int(state.get("keep_distance_retreat_recovery_count", 0)),
					"physical_movement_active": (
						npc_system.has_method("is_npc_world_movement_active")
						and bool(npc_system.is_npc_world_movement_active(npc_id))
					)
				})
	var reacquire_requests: Array[Dictionary] = []
	for raw_npc_id in _friendly_enemy_reacquire_requests.keys():
		var request_npc_id := str(raw_npc_id)
		var request := (_friendly_enemy_reacquire_requests.get(request_npc_id, {}) as Dictionary).duplicate(true)
		request["npc_id"] = request_npc_id
		reacquire_requests.append(request)
	reacquire_requests.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("sequence", 0)) < int(right.get("sequence", 0)))
	return {
		"schema_version": "friendly_station_response_runtime_v4",
		"combat_targeting_schema": str(
			_get_friendly_station_response_config().get(
				"combat_targeting_schema",
				"friendly_enemy_presence_lock_v1"
			)
		),
		"station_breached": not station_enemy_ids.is_empty(),
		"station_enemy_ids": station_enemy_ids,
		"normal_contact_range": _get_normal_contact_range(),
		"combat_target_detection_range": _get_friendly_target_detection_range(),
		"inside_station_target_scope": str(
			_get_friendly_station_response_config().get(
				"inside_station_target_scope",
				"entire_station_plus_unified_radius"
			)
		),
		"station_breach_target_scope": "station_breach_global",
		"inside_station_breach_target_scope": "station_breach_plus_unified_radius",
		"combat_navigation_policy": _combat_navigation_policy.duplicate(true),
		"maximum_active_enemy_ranged_attack_range": _get_max_active_enemy_ranged_attack_range(),
		"avoidance_trigger_range": _get_avoidance_trigger_range(),
		"avoidance_target_distance": _get_avoidance_target_distance(),
		"avoidance_policy_schema": str(
			_get_friendly_station_response_config().get(
				"avoidance_policy_schema",
				"weighted_enemy_repulsion_v1"
			)
		),
		"avoidance_weight_formula": "inverse_distance_power",
		"avoidance_weight_exponent": _get_avoidance_weight_exponent(),
		"avoidance_boundary_inset": _get_avoidance_boundary_inset(),
		"avoidance_safe_distance": _get_avoidance_safe_distance(),
		"keep_distance_retreat_policy_schema": str(
			_get_friendly_station_response_config().get(
				"keep_distance_retreat_policy_schema",
				"weighted_close_threat_retreat_v1"
			)
		),
		"keep_distance_retreat_trigger_range_ratio": _get_keep_distance_retreat_trigger_range_ratio(),
		"keep_distance_retreat_segment_range_ratio": _get_keep_distance_retreat_segment_range_ratio(),
		"keep_distance_retreat_arrival_tolerance": _get_keep_distance_retreat_arrival_tolerance(),
		"keep_distance_retreats": keep_distance_retreats,
		"proactive_strategy_ids": _get_friendly_station_response_config().get(
			"proactive_strategy_ids",
			[STRATEGY_ATTACK]
		),
		"locks": locks,
		"different_attacker_damage_reacquire_requests": reacquire_requests,
		"metrics": _friendly_targeting_metrics.duplicate(true)
	}


func debug_get_friendly_targeting_snapshot() -> Dictionary:
	return _get_friendly_station_response_snapshot()


func _get_npc_behavior_mode(npc_system: Node, npc_id: String) -> String:
	if npc_system != null and npc_system.has_method("get_npc_behavior_mode"):
		return str(npc_system.get_npc_behavior_mode(npc_id))
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
	var state_before_change := _get_npc_state(npc_id)
	var previous_id := _extract_combat_strategy_id(state_before_change.get("combat_strategy", {}))
	var strategy_state := _make_combat_strategy_state(npc_id, clean_strategy_id, snapshot, reason)
	var changed := previous_id != clean_strategy_id
	var state_changes := {
		"combat_strategy": strategy_state,
		"last_action_result": "combat_strategy_selected" if changed else "combat_strategy_unchanged",
		"combat_charge_phase": CHARGE_PHASE_WITHDRAW if clean_strategy_id == STRATEGY_CHARGE_CYCLE else "",
		"combat_charge_last_impact": {}
	}
	npc_system.update_npc_state(npc_id, state_changes)
	if (
		changed
		and clean_strategy_id == STRATEGY_AVOID
		and str(state_before_change.get("current_action", "")).begins_with("moving_to_%s" % STRATEGY_MOVE_TARGET_PREFIX)
		and not str(state_before_change.get("current_action", "")).begins_with("moving_to_%s%s_" % [STRATEGY_MOVE_TARGET_PREFIX, STRATEGY_AVOID])
	):
		_settle_combat_strategy_move_handoff(
			npc_id,
			STRATEGY_AVOID,
			{"enemy_id": str(state_before_change.get("combat_target_enemy_id", ""))},
			"combat_strategy_changed_to_avoid"
		)
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
	if resolved_npc_system.has_method("get_npc_combat_identity"):
		var identity: Dictionary = resolved_npc_system.get_npc_combat_identity(npc_id)
		return (
			not identity.is_empty()
			and bool(identity.get("recruited", false))
			and bool(identity.get("has_main_weapon", false))
		)
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


func _resolve_avoidance_navigation_target(
	npc_position: Vector3,
	desired_position: Vector3
) -> Dictionary:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if (
		controller == null
		or not controller.has_method("resolve_station_avoidance_navigation_target")
	):
		return {
			"ok": false,
			"reason": "station_avoidance_navigation_resolver_missing"
		}
	return controller.resolve_station_avoidance_navigation_target(
		npc_position,
		desired_position,
		_get_avoidance_boundary_inset()
	)


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
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		strategy["charge_phase"] = str(state.get("combat_charge_phase", ""))
		strategy["charge_last_impact"] = state.get("combat_charge_last_impact", {}).duplicate(true) if state.get("combat_charge_last_impact", {}) is Dictionary else {}
		result.append(strategy)
	return result


func _is_frontline_unit(unit_type: String) -> bool:
	return ["melee_infantry", "polearm_infantry", "cavalry"].has(unit_type)


func _is_formal_dynamic_pressure_enemy(enemy_id: String) -> bool:
	if not _formal_first_wave_slices.has(enemy_id):
		return false
	return str((_formal_first_wave_slices[enemy_id] as Dictionary).get("movement_model", "")) == "dynamic_combat_pressure"


func _uses_enemy_attack_position_leases(enemy_id: String) -> bool:
	var schema := str(_formal_attack_position_policy.get("schema", ""))
	return (
		_is_formal_dynamic_pressure_enemy(enemy_id)
		and schema in ["enemy_attack_position_leases_v1", "enemy_attack_guidance_zones_v2"]
	)


func _uses_enemy_attack_guidance(enemy_id: String, target: Dictionary = {}) -> bool:
	if not _uses_enemy_attack_position_leases(enemy_id):
		return false
	if str(_formal_attack_position_policy.get("schema", "")) != "enemy_attack_guidance_zones_v2":
		return false
	return target.is_empty() or str(target.get("type", "")) in ["building", "defense_device"]


func _enemy_attack_target_key(target: Dictionary) -> String:
	var target_type := str(target.get("type", ""))
	var target_id := str(target.get("id", ""))
	return "%s:%s" % [target_type, target_id] if not target_type.is_empty() and not target_id.is_empty() else ""


func _enemy_attack_position_role(enemy: Dictionary) -> String:
	var weapon_type := str(enemy.get("weapon_type", "sword_shield"))
	return "ranged_%s" % weapon_type if weapon_type in RANGED_WEAPON_TYPES else "melee_%s" % weapon_type


func _get_enemy_attack_position_radius(enemy: Dictionary) -> float:
	var mounted := str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"]
	var fallback := 0.65 if mounted else 0.42
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("get_actor_motion_profile"):
		var profile_id := "enemy_mounted" if mounted else "enemy_foot"
		var profile: Dictionary = controller.get_actor_motion_profile(profile_id)
		return maxf(0.1, float(profile.get("radius", fallback)))
	return fallback


func _get_max_enemy_attack_position_radius() -> float:
	var maximum_radius := 0.65
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("get_actor_motion_profile"):
		for profile_id in ["enemy_foot", "enemy_mounted"]:
			var profile: Dictionary = controller.get_actor_motion_profile(profile_id)
			maximum_radius = maxf(maximum_radius, float(profile.get("radius", 0.0)))
	return maximum_radius


func _get_enemy_attack_position_standoff(
	enemy: Dictionary,
	target: Dictionary,
	ranged_range_ratio_override: float = -1.0
) -> float:
	var enemy_radius := _get_enemy_attack_position_radius(enemy)
	var target_radius := maxf(0.0, float(target.get("contact_radius", 0.0)))
	if str(target.get("type", "")) == "npc":
		target_radius = maxf(target_radius, 0.35)
	var safety_margin := maxf(0.0, float(_formal_attack_position_policy.get("safety_margin", 0.08)))
	var attack_range := maxf(0.1, float(enemy.get("attack_range", 1.5)))
	var is_ranged := str(enemy.get("weapon_type", "")) in RANGED_WEAPON_TYPES
	var reach_ratio := (
		(
			ranged_range_ratio_override
			if ranged_range_ratio_override > 0.0
			else float(_formal_attack_position_policy.get("ranged_range_ratio", 0.72))
		)
		if is_ranged
		else float(_formal_attack_position_policy.get("melee_reach_ratio", 0.82))
	)
	var arrival_tolerance := maxf(0.05, float(_formal_attack_position_policy.get("arrival_tolerance", 0.32)))
	var arrival_margin := maxf(0.0, float(_formal_attack_position_policy.get("attack_range_arrival_margin", 0.02)))
	var standoff := attack_range * clampf(reach_ratio, 0.2, 0.95)
	if str(enemy.get("weapon_type", "")) in MELEE_WEAPON_TYPES:
		# NavigationAgent may legitimately stop anywhere inside its arrival radius.
		# Reserve part of that radius inside the authored reach. Keeping the reserve
		# configurable preserves enough facade clearance for the solid capsule while
		# still putting a normal arrival inside the real weapon sweep.
		var arrival_reserve_ratio := clampf(float(_formal_attack_position_policy.get("melee_arrival_reserve_ratio", 0.40)), 0.0, 1.0)
		standoff = maxf(0.1, standoff - arrival_tolerance * arrival_reserve_ratio - arrival_margin)
	if str(target.get("type", "")) != "npc":
		standoff += target_radius
	var contact_origin_offset := 0.0 if str(target.get("type", "")) == "npc" else target_radius
	var maximum_reachable_standoff := contact_origin_offset + maxf(0.1, attack_range - arrival_tolerance - arrival_margin)
	if str(target.get("type", "")) == "building" and str(target.get("id", "")) == "front_gate":
		# The gate attack line sits beside two physical posts. Keep the intended
		# seven-footman line just outside the baked post clearance while retaining
		# the configured arrival reserve inside actual melee reach.
		standoff = maxf(
			standoff,
			float(_formal_attack_position_policy.get("front_gate_navigation_clearance_standoff", standoff))
		)
	standoff = minf(standoff, maximum_reachable_standoff)
	return maxf(enemy_radius + target_radius + safety_margin, standoff)


func _get_enemy_attack_position_row_specs(enemy: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var fallback_standoff := _get_enemy_attack_position_standoff(enemy, target)
	if (
		str(target.get("type", "")) not in ["building", "defense_device"]
		or str(enemy.get("weapon_type", "")) not in RANGED_WEAPON_TYPES
	):
		return [{
			"index": 0,
			"count": 1,
			"range_ratio": -1.0,
			"standoff": fallback_standoff
		}]
	var configured_ratios := _formal_attack_position_policy.get(
		"ranged_fixed_target_row_range_ratios",
		_formal_attack_position_policy.get(
			"ranged_building_row_range_ratios",
			[_formal_attack_position_policy.get("ranged_range_ratio", 0.72)]
		)
	) as Array
	var normalized_ratios: Array[float] = []
	for raw_ratio in configured_ratios:
		var ratio := clampf(float(raw_ratio), 0.2, 0.95)
		if normalized_ratios.any(func(existing_ratio: float) -> bool: return is_equal_approx(existing_ratio, ratio)):
			continue
		normalized_ratios.append(ratio)
	if normalized_ratios.is_empty():
		normalized_ratios.append(clampf(float(_formal_attack_position_policy.get("ranged_range_ratio", 0.72)), 0.2, 0.95))
	var row_specs: Array[Dictionary] = []
	for row_index in range(normalized_ratios.size()):
		var range_ratio := normalized_ratios[row_index]
		row_specs.append({
			"index": row_index,
			"count": normalized_ratios.size(),
			"range_ratio": range_ratio,
			"standoff": _get_enemy_attack_position_standoff(enemy, target, range_ratio)
		})
	return row_specs


func _get_enemy_attack_position_outward(enemy_id: String, target: Dictionary) -> Vector3:
	var proxy_outward: Variant = target.get("host_proxy_outward_direction", null)
	if proxy_outward is Vector3:
		var proxy_outward_vector := proxy_outward as Vector3
		proxy_outward_vector.y = 0.0
		if proxy_outward_vector.length_squared() > 0.0001:
			return proxy_outward_vector.normalized()
	var facing: Variant = target.get("facing_direction", null)
	if facing is Vector3:
		var facing_vector := facing as Vector3
		facing_vector.y = 0.0
		if facing_vector.length_squared() > 0.0001:
			return facing_vector.normalized()
	var target_id := str(target.get("id", ""))
	var slice := _formal_first_wave_slices.get(enemy_id, {}) as Dictionary
	var route := slice.get("route", {}) as Dictionary
	var stages := route.get("stages", []) as Array
	for stage_index in range(stages.size()):
		var stage := stages[stage_index] as Dictionary
		if str(stage.get("id", "")) != target_id or stage_index <= 0:
			continue
		var previous_stage := stages[stage_index - 1] as Dictionary
		var outward: Vector3 = previous_stage.get("position", Vector3.ZERO) - stage.get("position", Vector3.ZERO)
		outward.y = 0.0
		if outward.length_squared() > 0.0001:
			return outward.normalized()
	var target_position: Vector3 = target.get("position", Vector3.ZERO)
	var enemy_position: Vector3 = (_active_enemies.get(enemy_id, {}) as Dictionary).get("position", target_position + Vector3.FORWARD)
	var fallback := enemy_position - target_position
	fallback.y = 0.0
	return fallback.normalized() if fallback.length_squared() > 0.0001 else Vector3.FORWARD


func _get_front_gate_attack_lane_distance(
	enemy_id: String,
	enemy: Dictionary,
	target: Dictionary,
	candidate: Dictionary
) -> float:
	if str(target.get("type", "")) != "building" or str(target.get("id", "")) != "front_gate":
		return INF
	var outward := _get_enemy_attack_position_outward(enemy_id, target)
	var tangent := Vector3(-outward.z, 0.0, outward.x)
	var target_position: Vector3 = target.get("position", Vector3.ZERO)
	var enemy_position: Vector3 = enemy.get("position", target_position)
	var approach_direction := Vector3.ZERO
	var slice := _formal_first_wave_slices.get(enemy_id, {}) as Dictionary
	var stages := (slice.get("route", {}) as Dictionary).get("stages", []) as Array
	for stage_index in range(1, stages.size()):
		var stage := stages[stage_index] as Dictionary
		if str(stage.get("id", "")) != "front_gate":
			continue
		var previous_stage := stages[stage_index - 1] as Dictionary
		approach_direction = stage.get("position", target_position) - previous_stage.get("position", enemy_position)
		approach_direction.y = 0.0
		break
	if approach_direction.length_squared() <= 0.0001:
		approach_direction = target_position - enemy_position
		approach_direction.y = 0.0
	if approach_direction.length_squared() > 0.0001:
		approach_direction = approach_direction.normalized()
	var projected_position := enemy_position
	var approach_dot := approach_direction.dot(outward)
	if absf(approach_dot) > 0.05:
		var travel_distance := (target_position - enemy_position).dot(outward) / approach_dot
		if travel_distance > 0.0:
			projected_position += approach_direction * travel_distance
	var projected_lateral := (projected_position - target_position).dot(tangent)
	var candidate_position: Vector3 = candidate.get("position", target_position)
	var candidate_lateral := (candidate_position - target_position).dot(tangent)
	return absf(candidate_lateral - projected_lateral)


func _get_oriented_building_attack_position_candidates(
	enemy: Dictionary,
	target: Dictionary,
	target_key: String,
	role: String,
	enemy_radius: float,
	spacing: float,
	row_specs: Array[Dictionary],
	max_positions: int
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if str(target.get("building_geometry_schema", "")) != "oriented_building_combat_geometry_v1":
		return candidates
	var center: Vector3 = target.get("position", enemy.get("position", Vector3.ZERO))
	var size_data := target.get("building_footprint_size", {}) as Dictionary
	var half_x := maxf(0.0, float(size_data.get("x", 0.0))) * 0.5
	var half_z := maxf(0.0, float(size_data.get("z", 0.0))) * 0.5
	var right: Vector3 = target.get("building_right_direction", Vector3.RIGHT)
	var forward: Vector3 = target.get("building_forward_direction", Vector3.FORWARD)
	right.y = 0.0
	forward.y = 0.0
	if half_x <= 0.0 or half_z <= 0.0 or right.length_squared() <= 0.0001 or forward.length_squared() <= 0.0001:
		return candidates
	right = right.normalized()
	forward = forward.normalized()
	var approach_position: Vector3 = target.get("route_approach_position", enemy.get("position", center + forward))
	approach_position.y = center.y
	var front_door_half_width := maxf(0.0, float(target.get("building_front_door_clear_width", 0.0))) * 0.5
	var raw_surface_samples: Array[Dictionary] = []
	var faces: Array[Dictionary] = [
		{"id": "front", "normal": forward, "tangent": right, "normal_extent": half_z, "tangent_extent": half_x, "door_half_width": front_door_half_width},
		{"id": "right", "normal": right, "tangent": -forward, "normal_extent": half_x, "tangent_extent": half_z, "door_half_width": 0.0},
		{"id": "back", "normal": -forward, "tangent": -right, "normal_extent": half_z, "tangent_extent": half_x, "door_half_width": 0.0},
		{"id": "left", "normal": -right, "tangent": forward, "normal_extent": half_x, "tangent_extent": half_z, "door_half_width": 0.0}
	]
	for face in faces:
		var normal: Vector3 = face.get("normal", Vector3.FORWARD)
		var tangent: Vector3 = face.get("tangent", Vector3.RIGHT)
		var normal_extent := maxf(0.0, float(face.get("normal_extent", 0.0)))
		var tangent_extent := maxf(0.0, float(face.get("tangent_extent", 0.0)))
		var corner_inset := minf(tangent_extent, maxf(spacing * 0.5, enemy_radius))
		var usable_length := maxf(0.0, tangent_extent * 2.0 - corner_inset * 2.0)
		var face_count := maxi(1, int(floor(usable_length / maxf(0.1, spacing))) + 1)
		var sample_gap := usable_length / float(face_count - 1) if face_count > 1 else 0.0
		for index in range(face_count):
			var lateral_offset := -usable_length * 0.5 + sample_gap * float(index) if face_count > 1 else 0.0
			if float(face.get("door_half_width", 0.0)) > 0.0 and absf(lateral_offset) < float(face.get("door_half_width", 0.0)) + enemy_radius * 0.25:
				continue
			var contact_position := center + normal * normal_extent + tangent * lateral_offset
			contact_position.y = center.y
			raw_surface_samples.append({
				"surface_slot_id": "%s_%02d_of_%02d" % [str(face.get("id", "face")), index, face_count],
				"contact_position": contact_position,
				"face_id": str(face.get("id", "")),
				"outward_direction": normal,
				"approach_distance": _horizontal_vector_distance(contact_position, approach_position)
			})
	raw_surface_samples.sort_custom(func(left: Dictionary, right_candidate: Dictionary) -> bool:
		var left_distance := float(left.get("approach_distance", INF))
		var right_distance := float(right_candidate.get("approach_distance", INF))
		return str(left.get("surface_slot_id", "")) < str(right_candidate.get("surface_slot_id", "")) if is_equal_approx(left_distance, right_distance) else left_distance < right_distance
	)
	var selected_surface_count := mini(maxi(1, max_positions), raw_surface_samples.size())
	for row_spec in row_specs:
		var row_index := int(row_spec.get("index", 0))
		var row_count := maxi(1, int(row_spec.get("count", row_specs.size())))
		var standoff := maxf(0.0, float(row_spec.get("standoff", 0.0)))
		for index in range(selected_surface_count):
			var sample := raw_surface_samples[index] as Dictionary
			var surface_slot_id := str(sample.get("surface_slot_id", "surface"))
			var slot_suffix := (
				"row_%02d_of_%02d:%s" % [row_index, row_count, surface_slot_id]
				if row_count > 1
				else surface_slot_id
			)
			var normal: Vector3 = sample.get("outward_direction", Vector3.FORWARD)
			var contact_position: Vector3 = sample.get("contact_position", center)
			candidates.append({
				"slot_id": "%s:%s:%s" % [target_key, role, slot_suffix],
				"position": contact_position + normal * standoff,
				"contact_position": contact_position,
				"face_id": str(sample.get("face_id", "")),
				"outward_direction": normal,
				"role": role,
				"enemy_radius": enemy_radius,
				"standoff": standoff,
				"range_row_index": row_index,
				"range_row_count": row_count,
				"range_row_ratio": float(row_spec.get("range_ratio", -1.0))
			})
	return candidates


func _get_defense_device_attack_position_candidates(
	enemy: Dictionary,
	target: Dictionary,
	target_key: String,
	role: String,
	enemy_radius: float,
	spacing: float,
	row_specs: Array[Dictionary],
	max_positions: int
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var regions := _get_defense_device_host_proxy_regions(target)
	if regions.is_empty():
		return candidates
	var total_budget := maxi(regions.size(), max_positions)
	var base_region_budget := int(total_budget / regions.size())
	var extra_region_budget := total_budget % regions.size()
	for region_index in range(regions.size()):
		var region := regions[region_index] as Dictionary
		var proxy_position: Vector3 = region.get("position", target.get("position", Vector3.ZERO))
		var outward: Vector3 = region.get("outward_direction", Vector3.FORWARD)
		outward.y = 0.0
		if outward.length_squared() <= 0.0001:
			continue
		outward = outward.normalized()
		var tangent := Vector3(-outward.z, 0.0, outward.x)
		var hit_radius := maxf(0.1, float(region.get("hit_radius", target.get("host_proxy_hit_radius", 2.0))))
		var edge_inset := minf(hit_radius * 0.25, maxf(0.12, enemy_radius * 0.35))
		var usable_half_width := maxf(0.1, hit_radius - edge_inset)
		if role.begins_with("melee_"):
			# The guide centre aims the authored swing at one wall contact, but the
			# blade sweeps laterally around that point. Edge guides can therefore hit
			# a neighbouring gate post or leave this deployment's strict proxy radius
			# while the attacker still appears to strike the ballista. Keep melee guide
			# centres inside the proxy's model-contact-safe core; collision identity
			# remains the final authority and is not widened by this navigation rule.
			var safe_half_width_ratio := clampf(
				float(_formal_attack_position_policy.get(
					"defense_device_melee_proxy_safe_half_width_ratio",
					0.5
				)),
				0.1,
				1.0
			)
			usable_half_width = minf(usable_half_width, maxf(0.1, hit_radius * safe_half_width_ratio))
		var natural_count := maxi(1, int(floor(usable_half_width * 2.0 / maxf(0.1, spacing))) + 1)
		var region_budget := maxi(1, base_region_budget + (1 if region_index < extra_region_budget else 0))
		var count := mini(natural_count, region_budget)
		var lateral_spacing := usable_half_width * 2.0 / float(count - 1) if count > 1 else 0.0
		var contact_radius := maxf(0.0, float(region.get("contact_radius", target.get("contact_radius", 0.0))))
		var surface_center := proxy_position + outward * contact_radius
		for row_spec in row_specs:
			var row_index := int(row_spec.get("index", 0))
			var row_count := maxi(1, int(row_spec.get("count", row_specs.size())))
			var standoff := maxf(0.0, float(row_spec.get("standoff", 0.0)))
			for index in range(count):
				var lateral_offset := -usable_half_width + lateral_spacing * float(index) if count > 1 else 0.0
				var contact_position := surface_center + tangent * lateral_offset
				var candidate_standoff := maxf(0.0, standoff - contact_radius)
				var candidate_position := contact_position + outward * candidate_standoff
				var region_id := str(region.get("id", "region_%02d" % region_index))
				var slot_suffix := (
					"row_%02d_of_%02d:region_%02d:point_%02d_of_%02d" % [row_index, row_count, region_index, index, count]
					if row_count > 1
					else "region_%02d:point_%02d_of_%02d" % [region_index, index, count]
				)
				candidates.append({
					"slot_id": "%s:%s:%s" % [target_key, role, slot_suffix],
					"position": candidate_position,
					"contact_position": contact_position,
					"host_proxy_region_id": region_id,
					"host_proxy_wall_segment_id": str(region.get("wall_segment_id", "")),
					"host_proxy_building_segment_id": str(region.get("building_segment_id", "")),
					"host_proxy_outward_direction": outward,
					"role": role,
					"enemy_radius": enemy_radius,
					"standoff": standoff,
					"range_row_index": row_index,
					"range_row_count": row_count,
					"range_row_ratio": float(row_spec.get("range_ratio", -1.0))
				})
	return candidates


func _get_enemy_attack_position_candidates(enemy_id: String, enemy: Dictionary, target: Dictionary) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var target_key := _enemy_attack_target_key(target)
	if target_key.is_empty():
		return candidates
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	var target_position: Vector3 = target.get("position", enemy_position)
	target_position.y = enemy_position.y
	var role := _enemy_attack_position_role(enemy)
	var enemy_radius := _get_enemy_attack_position_radius(enemy)
	var safety_margin := maxf(0.0, float(_formal_attack_position_policy.get("safety_margin", 0.08)))
	var spacing := enemy_radius * 2.0 + safety_margin
	var target_type := str(target.get("type", ""))
	if target_type == "npc":
		# NPC targets deliberately have no authored attack-position capacity. Enemy
		# bodies pursue the live NPC position and may crowd around it naturally.
		return candidates
	var row_specs := _get_enemy_attack_position_row_specs(enemy, target)

	var outward := _get_enemy_attack_position_outward(enemy_id, target)
	var tangent := Vector3(-outward.z, 0.0, outward.x)
	var width := 0.0
	var authored_position_count := 0
	if target_type == "building":
		var outlines := _formal_attack_position_policy.get("target_outlines", {}) as Dictionary
		var outline := outlines.get(str(target.get("id", "")), {}) as Dictionary
		width = maxf(spacing, float(outline.get("width", spacing)))
		authored_position_count = maxi(0, int(outline.get("position_count", 0)))
	else:
		var proxy_radius := maxf(
			float(target.get("host_proxy_hit_radius", 0.0)),
			float(target.get("contact_radius", 0.0))
		)
		width = maxf(spacing * 2.0, proxy_radius * 2.0)
	var is_ranged := str(enemy.get("weapon_type", "")) in RANGED_WEAPON_TYPES
	var max_positions := 0
	if target_type == "building":
		max_positions = int(_formal_attack_position_policy.get(
			"ranged_building_max_positions" if is_ranged else "building_max_positions",
			32 if is_ranged else 20
		))
	else:
		max_positions = int(_formal_attack_position_policy.get(
			"ranged_defense_device_max_positions" if is_ranged else "defense_device_max_positions",
			12 if is_ranged else 8
		))
	if target_type == "building" and str(target.get("building_geometry_schema", "")) == "oriented_building_combat_geometry_v1":
		return _decorate_enemy_attack_guidance_zones(_get_oriented_building_attack_position_candidates(
			enemy,
			target,
			target_key,
			role,
			enemy_radius,
			spacing,
			row_specs,
			max_positions
		), enemy)
	if target_type == "defense_device" and not _get_defense_device_host_proxy_regions(target).is_empty():
		return _decorate_enemy_attack_guidance_zones(_get_defense_device_attack_position_candidates(
			enemy,
			target,
			target_key,
			role,
			enemy_radius,
			spacing,
			row_specs,
			max_positions
		), enemy)
	var count := clampi(
		authored_position_count if authored_position_count > 0 else int(floor(width / spacing)) + 1,
		1,
		maxi(1, max_positions)
	)
	var lateral_spacing := width / float(count - 1) if authored_position_count > 1 else spacing
	var center_index := float(count - 1) * 0.5
	var surface_offset := 0.0
	if target_type != "building":
		# host_proxy_hit_radius bounds which section of a shared wall may proxy
		# this deployment; it is not the wall's physical depth. Using it as a
		# forward offset places both the contact point and the snapped lease in
		# empty space, so authored melee sweeps visibly miss every device attack.
		surface_offset = maxf(0.0, float(target.get("contact_radius", 0.0)))
	for row_spec in row_specs:
		var row_index := int(row_spec.get("index", 0))
		var row_count := maxi(1, int(row_spec.get("count", row_specs.size())))
		var standoff := maxf(0.0, float(row_spec.get("standoff", 0.0)))
		for index in range(count):
			var lateral_offset := (float(index) - center_index) * lateral_spacing
			var contact_position := target_position + outward * surface_offset + tangent * lateral_offset
			var candidate_standoff := maxf(0.0, standoff - surface_offset)
			var candidate_position := contact_position + outward * candidate_standoff
			var slot_suffix := (
				"row_%02d_of_%02d:front_%02d_of_%02d" % [row_index, row_count, index, count]
				if row_count > 1
				else "front_%02d_of_%02d" % [index, count]
			)
			candidates.append({
				"slot_id": "%s:%s:%s" % [target_key, role, slot_suffix],
				"position": candidate_position,
				"contact_position": contact_position,
				"role": role,
				"enemy_radius": enemy_radius,
				"standoff": standoff,
				"range_row_index": row_index,
				"range_row_count": row_count,
				"range_row_ratio": float(row_spec.get("range_ratio", -1.0))
			})
	return _decorate_enemy_attack_guidance_zones(candidates, enemy)


func _decorate_enemy_attack_guidance_zones(
	candidates: Array[Dictionary],
	enemy: Dictionary
) -> Array[Dictionary]:
	if str(_formal_attack_position_policy.get("schema", "")) != "enemy_attack_guidance_zones_v2":
		return candidates
	var guidance_class := "ranged" if str(enemy.get("weapon_type", "")) in RANGED_WEAPON_TYPES else "melee"
	var zone_radius := _get_enemy_attack_position_radius(enemy)
	var zone_height := maxf(
		0.1,
		float(_formal_attack_position_policy.get("guidance_zone_height", 2.6))
	)
	var safety_margin := maxf(0.0, float(_formal_attack_position_policy.get("safety_margin", 0.08)))
	var cell_size := maxf(0.1, zone_radius * 2.0 + safety_margin)
	var decorated: Array[Dictionary] = []
	var spatial_cells: Dictionary = {}
	for raw_candidate in candidates:
		var candidate := raw_candidate.duplicate(true)
		candidate["guidance_class"] = guidance_class
		candidate["guidance_zone_radius"] = zone_radius
		candidate["guidance_zone_height"] = zone_height
		candidate["guidance_volume_shape"] = "vertical_cylinder"
		var candidate_position: Vector3 = candidate.get("position", Vector3.ZERO)
		var overlaps_existing := false
		var cell_x := floori(candidate_position.x / cell_size)
		var cell_z := floori(candidate_position.z / cell_size)
		for offset_x in range(-1, 2):
			if overlaps_existing:
				break
			for offset_z in range(-1, 2):
				var cell_key := "%d:%d" % [cell_x + offset_x, cell_z + offset_z]
				for raw_existing in spatial_cells.get(cell_key, []):
					var existing := raw_existing as Dictionary
					var existing_position: Vector3 = existing.get("position", Vector3.ZERO)
					var required_separation := (
						zone_radius
						+ maxf(0.1, float(existing.get("guidance_zone_radius", zone_radius)))
						+ safety_margin
					)
					if Vector2(candidate_position.x, candidate_position.z).distance_to(
						Vector2(existing_position.x, existing_position.z)
					) + 0.0001 < required_separation:
						overlaps_existing = true
						break
				if overlaps_existing:
					break
		if not overlaps_existing:
			decorated.append(candidate)
			var own_cell_key := "%d:%d" % [cell_x, cell_z]
			var cell_entries := spatial_cells.get(own_cell_key, []) as Array
			cell_entries.append(candidate)
			spatial_cells[own_cell_key] = cell_entries
	return decorated


func _is_enemy_attack_position_conflict(
	target_key: String,
	candidate: Dictionary,
	own_enemy_id: String,
	occupied_only: bool = false
) -> bool:
	var safety_margin := maxf(0.0, float(_formal_attack_position_policy.get("safety_margin", 0.08)))
	var candidate_position: Vector3 = candidate.get("position", Vector3.ZERO)
	var candidate_radius := maxf(0.1, float(candidate.get("enemy_radius", 0.42)))
	for raw_lease in _enemy_attack_position_leases.values():
		var lease := raw_lease as Dictionary
		if str(lease.get("enemy_id", "")) == own_enemy_id or str(lease.get("target_key", "")) != target_key:
			continue
		# Reservations prevent two enemies from being routed into the same physical
		# slot, but only an actor that has actually arrived consumes targeting
		# capacity.  Target selection uses occupied_only=true; lease allocation keeps
		# the default and therefore still treats in-transit reservations as conflicts.
		if occupied_only and str(lease.get("status", "reserved")) != "occupied":
			continue
		if str(lease.get("slot_id", "")) == str(candidate.get("slot_id", "")):
			return true
		var leased_position: Vector3 = lease.get("position", Vector3.ZERO)
		var required_distance := candidate_radius + maxf(0.1, float(lease.get("enemy_radius", 0.42))) + safety_margin
		if Vector2(candidate_position.x, candidate_position.z).distance_to(Vector2(leased_position.x, leased_position.z)) + 0.0001 < required_distance:
			return true
	return false


func _resolve_reachable_enemy_attack_position(enemy_id: String, candidate: Dictionary) -> Dictionary:
	var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	if actor == null:
		return {}
	var navigation_map := actor.get_navigation_map()
	if not navigation_map.is_valid():
		return {}
	var slot_id := str(candidate.get("slot_id", ""))
	var blocked_by_enemy := _enemy_attack_unreachable_until_frame.get(enemy_id, {}) as Dictionary
	if int(blocked_by_enemy.get(slot_id, -1)) > _formal_crowd_logic_frame:
		return {}
	var candidate_position: Vector3 = candidate.get("position", actor.global_position)
	candidate_position.y = actor.global_position.y
	var snapped := NavigationServer3D.map_get_closest_point(navigation_map, candidate_position)
	var snap_tolerance := maxf(0.05, float(_formal_attack_position_policy.get("navigation_snap_tolerance", 0.65)))
	if Vector2(candidate_position.x, candidate_position.z).distance_to(Vector2(snapped.x, snapped.z)) > snap_tolerance:
		_enemy_attack_position_metrics["unreachable_candidates_rejected"] = int(_enemy_attack_position_metrics.get("unreachable_candidates_rejected", 0)) + 1
		return {}
	var path := NavigationServer3D.map_get_path(navigation_map, actor.global_position, snapped, true)
	var arrival_tolerance := maxf(0.05, float(_formal_attack_position_policy.get("arrival_tolerance", 0.32)))
	if path.is_empty() and Vector2(actor.global_position.x, actor.global_position.z).distance_to(Vector2(snapped.x, snapped.z)) > arrival_tolerance:
		_enemy_attack_position_metrics["unreachable_candidates_rejected"] = int(_enemy_attack_position_metrics.get("unreachable_candidates_rejected", 0)) + 1
		return {}
	if not path.is_empty():
		var path_end := path[path.size() - 1]
		if Vector2(path_end.x, path_end.z).distance_to(Vector2(snapped.x, snapped.z)) > snap_tolerance:
			_enemy_attack_position_metrics["unreachable_candidates_rejected"] = int(_enemy_attack_position_metrics.get("unreachable_candidates_rejected", 0)) + 1
			return {}
	var path_distance := 0.0
	var previous := actor.global_position
	for point in path:
		path_distance += Vector2(previous.x, previous.z).distance_to(Vector2(point.x, point.z))
		previous = point
	var resolved := candidate.duplicate(true)
	resolved["authored_position"] = candidate_position
	resolved["position"] = snapped
	resolved["path_distance"] = path_distance
	return resolved


func _decorate_target_with_enemy_attack_position(target: Dictionary, lease: Dictionary) -> Dictionary:
	var decorated := target.duplicate(true)
	decorated["attack_position_status"] = str(lease.get("status", "reserved"))
	decorated["attack_position_id"] = str(lease.get("slot_id", ""))
	decorated["attack_position"] = lease.get("position", decorated.get("position", Vector3.ZERO))
	decorated["attack_contact_position"] = lease.get("contact_position", decorated.get("position", Vector3.ZERO))
	decorated["attack_position_role"] = str(lease.get("role", ""))
	decorated["attack_position_target_key"] = str(lease.get("target_key", ""))
	decorated["attack_position_range_row_index"] = int(lease.get("range_row_index", 0))
	decorated["attack_position_range_row_count"] = int(lease.get("range_row_count", 1))
	decorated["attack_position_range_row_ratio"] = float(lease.get("range_row_ratio", -1.0))
	decorated["attack_host_proxy_region_id"] = str(lease.get("host_proxy_region_id", target.get("host_proxy_id", "")))
	decorated["attack_host_proxy_wall_segment_id"] = str(lease.get("host_proxy_wall_segment_id", ""))
	decorated["attack_host_proxy_building_segment_id"] = str(lease.get("host_proxy_building_segment_id", ""))
	return decorated


func _find_enemy_attack_wait_entry(enemy_id: String, target_key: String) -> Dictionary:
	for raw_entry in _enemy_attack_wait_queues.get(target_key, []):
		var entry := raw_entry as Dictionary
		if str(entry.get("enemy_id", "")) == enemy_id:
			return entry
	return {}


func _refresh_enemy_attack_wait_entry(
	enemy_id: String,
	enemy: Dictionary,
	target: Dictionary,
	existing: Dictionary,
	wait_reason: String = ""
) -> Dictionary:
	var target_key := _enemy_attack_target_key(target)
	var queue := _enemy_attack_wait_queues.get(target_key, []) as Array
	for index in range(queue.size()):
		var entry := queue[index] as Dictionary
		if str(entry.get("enemy_id", "")) != enemy_id:
			continue
		entry["target"] = target.duplicate(true)
		entry["wait_reason"] = wait_reason
		var pressure_target := _get_enemy_attack_wait_pressure_target(
			enemy_id,
			enemy,
			target,
			maxi(0, int(entry.get("queue_slot_index", 0))),
			str(entry.get("desired_attack_position_id", ""))
		)
		entry["queue_position"] = pressure_target.get(
			"position",
			_get_enemy_attack_wait_position(enemy_id, enemy, target, maxi(0, int(entry.get("queue_slot_index", 0))))
		)
		entry["desired_attack_position_id"] = str(pressure_target.get("slot_id", ""))
		queue[index] = entry
		_enemy_attack_wait_queues[target_key] = queue
		return entry
	return existing


func _get_enemy_attack_wait_position(enemy_id: String, enemy: Dictionary, target: Dictionary, queue_index: int) -> Vector3:
	var target_position: Vector3 = target.get("position", enemy.get("position", Vector3.ZERO))
	var outward := _get_enemy_attack_position_outward(enemy_id, target)
	var tangent := Vector3(-outward.z, 0.0, outward.x)
	var radius := maxf(_get_enemy_attack_position_radius(enemy), _get_max_enemy_attack_position_radius())
	var safety := maxf(0.0, float(_formal_attack_position_policy.get("safety_margin", 0.08)))
	var spacing := radius * 2.0 + safety
	var front_depth := maxf(
		_get_enemy_attack_position_standoff(enemy, target),
		float(_formal_attack_position_policy.get("queue_base_standoff", 0.0))
	)
	var target_key := _enemy_attack_target_key(target)
	for raw_lease in _enemy_attack_position_leases.values():
		var lease := raw_lease as Dictionary
		if str(lease.get("target_key", "")) != target_key:
			continue
		var lease_position: Vector3 = lease.get("position", target_position)
		var lease_depth := (lease_position - target_position).dot(outward)
		var required_clearance := radius + maxf(0.1, float(lease.get("enemy_radius", radius))) + safety
		front_depth = maxf(front_depth, lease_depth + required_clearance)
	var column_index := queue_index % 3
	var row := queue_index / 3
	var column_offset: float = float([0.0, -1.0, 1.0][column_index])
	var wait_position: Vector3 = target_position + outward * (front_depth + spacing * float(row)) + tangent * column_offset * spacing
	var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	if actor != null:
		var navigation_map := actor.get_navigation_map()
		if navigation_map.is_valid():
			wait_position = NavigationServer3D.map_get_closest_point(navigation_map, wait_position)
	return wait_position


func _get_enemy_attack_wait_pressure_target(
	enemy_id: String,
	enemy: Dictionary,
	target: Dictionary,
	queue_index: int,
	preferred_slot_id: String = ""
) -> Dictionary:
	var candidates := _get_enemy_attack_position_candidates(enemy_id, enemy, target)
	if candidates.is_empty():
		return {}
	var reachable: Array[Dictionary] = []
	for raw_candidate in candidates:
		var candidate := raw_candidate as Dictionary
		var resolved := _resolve_reachable_enemy_attack_position(enemy_id, candidate)
		if resolved.is_empty():
			continue
		if not preferred_slot_id.is_empty() and str(resolved.get("slot_id", "")) == preferred_slot_id:
			return resolved
		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		var candidate_position: Vector3 = resolved.get("position", enemy_position)
		resolved["wait_distance"] = Vector2(enemy_position.x, enemy_position.z).distance_squared_to(
			Vector2(candidate_position.x, candidate_position.z)
		)
		reachable.append(resolved)
	if reachable.is_empty():
		return {}
	reachable.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := float(left.get("wait_distance", INF))
		var right_distance := float(right.get("wait_distance", INF))
		return str(left.get("slot_id", "")) < str(right.get("slot_id", "")) if is_equal_approx(left_distance, right_distance) else left_distance < right_distance
	)
	# A waiter owns no lease and therefore no combat permission. This stable
	# desired slot is only a pressure destination: NavigationAgent/RVO and the
	# physical capsules stop it behind the reservation owner or occupied attacker.
	# Rotating by the stable queue index keeps several waiters from all selecting
	# the same nearest slot while preserving the existing promotion order.
	var chosen := reachable[posmod(queue_index, reachable.size())].duplicate(true)
	chosen.erase("wait_distance")
	return chosen


func _configure_enemy_attack_wait_avoidance(enemy_id: String, waiting: bool) -> void:
	var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	if actor == null:
		return
	if waiting:
		_end_enemy_precise_arrival_recovery(enemy_id, "cancelled:waiting_for_lease", actor)
	var base_priority := float(_formal_attack_position_policy.get(
		"waiting_attacker_avoidance_priority" if waiting else "active_attacker_avoidance_priority",
		0.20 if waiting else 0.55
	))
	var spread := maxf(0.0, float(_formal_attack_position_policy.get("attack_avoidance_priority_spread", 0.08)))
	actor.configure_avoidance_identity(
		"enemy_attack_wait:%s" % enemy_id if waiting else "enemy:%s" % enemy_id,
		base_priority,
		spread
	)
	var precise_recovery_active := _enemy_precise_arrival_recoveries.has(enemy_id)
	actor.set_runtime_avoidance_enabled(
		not precise_recovery_active,
		"melee_precise_arrival_recovery" if precise_recovery_active else ""
	)


func _enqueue_enemy_attack_position_waiter(
	enemy_id: String,
	enemy: Dictionary,
	target: Dictionary,
	wait_reason: String = ""
) -> Dictionary:
	var target_key := _enemy_attack_target_key(target)
	var existing := _find_enemy_attack_wait_entry(enemy_id, target_key)
	if not existing.is_empty():
		return existing
	_enemy_attack_wait_sequence += 1
	var queue := _enemy_attack_wait_queues.get(target_key, []) as Array
	var used_queue_slots: Dictionary = {}
	for raw_entry in queue:
		used_queue_slots[int((raw_entry as Dictionary).get("queue_slot_index", -1))] = true
	var queue_slot_index := 0
	while used_queue_slots.has(queue_slot_index):
		queue_slot_index += 1
	var pressure_target := _get_enemy_attack_wait_pressure_target(
		enemy_id,
		enemy,
		target,
		queue_slot_index
	)
	var queue_position: Vector3 = pressure_target.get(
		"position",
		_get_enemy_attack_wait_position(enemy_id, enemy, target, queue_slot_index)
	)
	var entry := {
		"enemy_id": enemy_id,
		"target_key": target_key,
		"role": _enemy_attack_position_role(enemy),
		"target": target.duplicate(true),
		"sequence": _enemy_attack_wait_sequence,
		"queue_slot_index": queue_slot_index,
		"queue_position": queue_position,
		"desired_attack_position_id": str(pressure_target.get("slot_id", "")),
		"wait_reason": wait_reason
	}
	queue.append(entry)
	_enemy_attack_wait_queues[target_key] = queue
	_enemy_attack_position_metrics["waiters_enqueued"] = int(_enemy_attack_position_metrics.get("waiters_enqueued", 0)) + 1
	return entry


func _decorate_target_for_enemy_attack_wait(target: Dictionary, entry: Dictionary) -> Dictionary:
	var decorated := target.duplicate(true)
	decorated["attack_position_status"] = "waiting"
	decorated["attack_position_target_key"] = str(entry.get("target_key", ""))
	decorated["attack_position"] = entry.get("queue_position", decorated.get("position", Vector3.ZERO))
	decorated["attack_position_wait_target_id"] = str(entry.get("desired_attack_position_id", ""))
	decorated["attack_position_wait_movement_policy"] = "pressure_assigned_attack_position"
	decorated["attack_position_queue_sequence"] = int(entry.get("sequence", 0))
	decorated["attack_position_wait_reason"] = str(entry.get("wait_reason", ""))
	return decorated


func _remove_enemy_from_attack_wait_queues(enemy_id: String, except_target_key: String = "") -> void:
	for raw_target_key in _enemy_attack_wait_queues.keys():
		var target_key := str(raw_target_key)
		if not except_target_key.is_empty() and target_key == except_target_key:
			continue
		var filtered: Array[Dictionary] = []
		for raw_entry in _enemy_attack_wait_queues.get(target_key, []):
			var entry := raw_entry as Dictionary
			if str(entry.get("enemy_id", "")) != enemy_id:
				filtered.append(entry)
		if filtered.is_empty():
			_enemy_attack_wait_queues.erase(target_key)
		else:
			_enemy_attack_wait_queues[target_key] = filtered


func _get_enemy_guidance_body_profile(enemy: Dictionary) -> Dictionary:
	var mounted := str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"]
	var fallback_radius := 0.65 if mounted else 0.42
	var fallback_height := 2.25 if mounted else 1.8
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("get_actor_motion_profile"):
		var profile_id := "enemy_mounted" if mounted else "enemy_foot"
		var profile: Dictionary = controller.get_actor_motion_profile(profile_id)
		return {
			"radius": maxf(0.1, float(profile.get("radius", fallback_radius))),
			"height": maxf(0.1, float(profile.get("height", fallback_height)))
		}
	return {"radius": fallback_radius, "height": fallback_height}


func _get_enemy_guided_attack_handoff_range(enemy: Dictionary, target: Dictionary) -> float:
	var attack_range := maxf(0.1, float(enemy.get("attack_range", 1.5)))
	if (
		str(_formal_attack_position_policy.get("schema", "")) != "enemy_attack_guidance_zones_v2"
		or str(target.get("type", "")) not in ["building", "defense_device"]
	):
		return attack_range
	if str(enemy.get("weapon_type", "")) in MELEE_WEAPON_TYPES:
		# Logical ranges include animation/model slack. The fixed-target guide center
		# was calibrated to the authored melee sweep; hand off before the center only
		# inside that same real-reach safety band, otherwise a sword can stop while
		# its sweep still hits a neighboring post instead of the locked wall proxy.
		return maxf(
			0.1,
			attack_range * clampf(float(_formal_attack_position_policy.get("melee_reach_ratio", 0.82)), 0.2, 0.95)
		)
	return attack_range


func _get_enemy_guidance_zone_occupancy(candidate: Dictionary, excluded_enemy_id: String = "") -> Dictionary:
	return _measure_enemy_guidance_zone_occupancy(candidate, _collect_enemy_guidance_bodies(excluded_enemy_id))


func _collect_enemy_guidance_bodies(excluded_enemy_id: String) -> Array[Dictionary]:
	# A single synchronous selection does not advance physics or commit damage.
	# Read live bodies once per selection, not once per candidate. Never retain this
	# across selections: another enemy's attack can remove a body in the same tick.
	var bodies: Array[Dictionary] = []
	var profiles: Dictionary = {}
	for raw_enemy_id in _active_enemies.keys():
		var enemy_id := str(raw_enemy_id)
		if not excluded_enemy_id.is_empty() and enemy_id == excluded_enemy_id:
			continue
		var enemy: Dictionary = _active_enemies.get(enemy_id, {}) as Dictionary
		if enemy.is_empty() or int(enemy.get("hp", 0)) <= 0:
			continue
		var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		var position: Vector3 = actor.global_position if actor != null else enemy.get("position", Vector3.INF)
		if position == Vector3.INF:
			continue
		var mounted: bool = str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"]
		if not profiles.has(mounted):
			profiles[mounted] = _get_enemy_guidance_body_profile(enemy)
		var profile: Dictionary = profiles[mounted]
		bodies.append({
			"id": enemy_id, "position": position,
			"radius": maxf(0.1, float(profile.get("radius", 0.42))),
			"height": maxf(0.1, float(profile.get("height", 1.8))),
		})
	return bodies


func _measure_enemy_guidance_zone_occupancy(candidate: Dictionary, bodies: Array[Dictionary]) -> Dictionary:
	var zone_position: Vector3 = candidate.get("position", Vector3.ZERO)
	var zone_radius := maxf(0.1, float(candidate.get(
		"guidance_zone_radius",
		candidate.get("enemy_radius", 0.42)
	)))
	var zone_height := maxf(0.1, float(candidate.get(
		"guidance_zone_height",
		_formal_attack_position_policy.get("guidance_zone_height", 2.6)
	)))
	var zone_min_y := zone_position.y
	var zone_max_y := zone_min_y + zone_height
	var occupants: Array[String] = []
	for body in bodies:
		var enemy_position: Vector3 = body.position
		var body_radius: float = body.radius
		var body_height: float = body.height
		var body_min_y := enemy_position.y
		var body_max_y := body_min_y + body_height
		if body_max_y < zone_min_y or body_min_y > zone_max_y:
			continue
		if Vector2(enemy_position.x, enemy_position.z).distance_to(
			Vector2(zone_position.x, zone_position.z)
		) <= zone_radius + body_radius:
			occupants.append(str(body.id))
	occupants.sort()
	return {
		"count": occupants.size(),
		"enemy_ids": occupants,
		"zone_radius": zone_radius,
		"zone_height": zone_height
	}


func _index_enemy_guidance_bodies(bodies: Array[Dictionary]) -> Dictionary:
	var cells: Dictionary = {}
	var max_radius := 0.0
	for body in bodies:
		var position: Vector3 = body.position
		var cell := Vector2i(floori(position.x / 4.0), floori(position.z / 4.0))
		if not cells.has(cell):
			cells[cell] = []
		(cells[cell] as Array).append(body)
		max_radius = maxf(max_radius, float(body.radius))
	return {"cells": cells, "max_radius": max_radius}


func _query_enemy_guidance_bodies(candidate: Dictionary, index: Dictionary) -> Array[Dictionary]:
	var position: Vector3 = candidate.get("position", Vector3.ZERO)
	var radius := maxf(0.1, float(candidate.get("guidance_zone_radius", candidate.get("enemy_radius", 0.42))))
	var reach := radius + float(index.max_radius)
	# Broad phase only. An extra whole cell on every side deliberately overfetches
	# at boundaries; the unchanged distance/height predicate makes the final call.
	var min_x := floori((position.x - reach) / 4.0) - 1
	var max_x := floori((position.x + reach) / 4.0) + 1
	var min_z := floori((position.z - reach) / 4.0) - 1
	var max_z := floori((position.z + reach) / 4.0) + 1
	var cells: Dictionary = index.cells
	var nearby: Array[Dictionary] = []
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var cell := Vector2i(x, z)
			if cells.has(cell):
				nearby.append_array(cells[cell])
	return nearby


func _ensure_enemy_guided_attack_position(
	enemy_id: String,
	enemy: Dictionary,
	target: Dictionary
) -> Dictionary:
	var target_key := _enemy_attack_target_key(target)
	var role := _enemy_attack_position_role(enemy)
	if target_key.is_empty():
		_release_enemy_attack_position(enemy_id, "guidance_target_missing", false, false)
		return target
	_remove_enemy_from_attack_wait_queues(enemy_id)
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	var candidates := _get_enemy_attack_position_candidates(enemy_id, enemy, target)
	var excluded_stall_slots := PackedStringArray()
	if _enemy_guidance_stall_recoveries.has(enemy_id):
		excluded_stall_slots = PackedStringArray(
			(_enemy_guidance_stall_recoveries.get(enemy_id, {}) as Dictionary).get("excluded_slot_ids", [])
		)
		var remaining_candidate_count := candidates.filter(
			func(candidate: Dictionary) -> bool:
				return not excluded_stall_slots.has(str(candidate.get("slot_id", "")))
		).size()
		if remaining_candidate_count == 0:
			excluded_stall_slots.clear()
			var reset_recovery := (_enemy_guidance_stall_recoveries.get(enemy_id, {}) as Dictionary).duplicate(true)
			reset_recovery["excluded_slot_ids"] = PackedStringArray()
			_enemy_guidance_stall_recoveries[enemy_id] = reset_recovery
	var ranked: Array[Dictionary] = []
	var guidance_bodies := _collect_enemy_guidance_bodies(enemy_id)
	var guidance_index := _index_enemy_guidance_bodies(guidance_bodies)
	for raw_candidate in candidates:
		var candidate := raw_candidate.duplicate(true)
		if excluded_stall_slots.has(str(candidate.get("slot_id", ""))):
			continue
		var occupancy := _measure_enemy_guidance_zone_occupancy(candidate, _query_enemy_guidance_bodies(candidate, guidance_index))
		candidate["guidance_occupancy_count"] = int(occupancy.get("count", 0))
		candidate["guidance_occupant_enemy_ids"] = (occupancy.get("enemy_ids", []) as Array).duplicate()
		var candidate_position: Vector3 = candidate.get("position", enemy_position)
		candidate["guidance_distance_to_attacker"] = Vector2(enemy_position.x, enemy_position.z).distance_to(
			Vector2(candidate_position.x, candidate_position.z)
		)
		ranked.append(candidate)
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_count := int(left.get("guidance_occupancy_count", 0))
		var right_count := int(right.get("guidance_occupancy_count", 0))
		if left_count != right_count:
			return left_count < right_count
		var left_distance := float(left.get("guidance_distance_to_attacker", INF))
		var right_distance := float(right.get("guidance_distance_to_attacker", INF))
		return str(left.get("slot_id", "")) < str(right.get("slot_id", "")) if is_equal_approx(left_distance, right_distance) else left_distance < right_distance
	)
	var chosen: Dictionary = {}
	for candidate in ranked:
		var resolved := _resolve_reachable_enemy_attack_position(enemy_id, candidate)
		if not resolved.is_empty():
			chosen = resolved
			break
	if chosen.is_empty():
		_release_enemy_attack_position(enemy_id, "guidance_unreachable", false, false)
		var unavailable := target.duplicate(true)
		unavailable["attack_position_status"] = "guidance_unavailable"
		unavailable["attack_position_role"] = role
		unavailable["attack_position_target_key"] = target_key
		return unavailable

	var previous_slot_id := ""
	var record_key := "guidance:%s" % enemy_id
	if _enemy_attack_position_by_enemy.has(enemy_id):
		var previous_key := str(_enemy_attack_position_by_enemy[enemy_id])
		var previous := _enemy_attack_position_leases.get(previous_key, {}) as Dictionary
		if str(previous.get("target_key", "")) == target_key and str(previous.get("role", "")) == role:
			previous_slot_id = str(previous.get("slot_id", ""))
		else:
			_release_enemy_attack_position(enemy_id, "guidance_target_or_role_changed", false, false)
	chosen["enemy_id"] = enemy_id
	chosen["target_key"] = target_key
	chosen["target_type"] = str(target.get("type", ""))
	chosen["target_id"] = str(target.get("id", ""))
	chosen["target_position"] = target.get("position", Vector3.ZERO)
	chosen["status"] = "guiding"
	chosen["guidance_selected_frame"] = _formal_crowd_logic_frame
	_enemy_attack_position_leases[record_key] = chosen
	_enemy_attack_position_by_enemy[enemy_id] = record_key
	if previous_slot_id.is_empty():
		_enemy_attack_position_metrics["guidance_assignments_created"] = int(
			_enemy_attack_position_metrics.get("guidance_assignments_created", 0)
		) + 1
	elif previous_slot_id != str(chosen.get("slot_id", "")):
		_enemy_attack_position_metrics["guidance_zone_switches"] = int(
			_enemy_attack_position_metrics.get("guidance_zone_switches", 0)
		) + 1

	var decorated := _decorate_target_with_enemy_attack_position(target, chosen)
	decorated["attack_position_status"] = "guiding"
	decorated["attack_guidance_class"] = str(chosen.get("guidance_class", ""))
	decorated["attack_guidance_zone_radius"] = float(chosen.get("guidance_zone_radius", 0.0))
	decorated["attack_guidance_zone_height"] = float(chosen.get("guidance_zone_height", 0.0))
	decorated["attack_guidance_occupancy_count"] = int(chosen.get("guidance_occupancy_count", 0))
	decorated["attack_guidance_occupant_enemy_ids"] = (chosen.get("guidance_occupant_enemy_ids", []) as Array).duplicate()
	decorated["attack_guidance_selection_policy"] = "minimum_live_cylinder_overlap_then_nearest"
	decorated["attack_guidance_handoff_range"] = _get_enemy_guided_attack_handoff_range(enemy, decorated)
	var selected_zone_position: Vector3 = chosen.get("position", enemy_position)
	var selected_zone_contact: Vector3 = chosen.get("contact_position", target.get("position", enemy_position))
	decorated["attack_guidance_selected_zone_contact_distance"] = Vector2(
		selected_zone_position.x,
		selected_zone_position.z
	).distance_to(Vector2(selected_zone_contact.x, selected_zone_contact.z))

	var nearest_contact: Variant = null
	var nearest_contact_distance := INF
	for candidate in candidates:
		var contact: Vector3 = candidate.get("contact_position", target.get("position", enemy_position))
		var contact_distance := Vector2(enemy_position.x, enemy_position.z).distance_to(Vector2(contact.x, contact.z))
		if contact_distance < nearest_contact_distance:
			nearest_contact_distance = contact_distance
			nearest_contact = contact
	if nearest_contact is Vector3:
		decorated["attack_contact_position"] = nearest_contact
		decorated["attack_guidance_nearest_contact_distance"] = nearest_contact_distance
		decorated["attack_guidance_selected_zone_contact_position"] = chosen.get("contact_position", nearest_contact)
	decorated["attack_guidance_arrival_tolerance"] = _get_enemy_attack_position_arrival_tolerance(enemy_id, decorated)
	return decorated


func _ensure_enemy_attack_position(enemy_id: String, enemy: Dictionary, target: Dictionary, force_waiter_retry: bool = false) -> Dictionary:
	if not _uses_enemy_attack_position_leases(enemy_id):
		return target
	if str(target.get("type", "")) == "npc":
		_release_enemy_attack_position(enemy_id, "npc_unrestricted_contact")
		var unrestricted := target.duplicate(true)
		for field in ["attack_position_status", "attack_position_id", "attack_position", "attack_contact_position", "attack_position_role", "attack_position_target_key", "attack_position_range_row_index", "attack_position_range_row_count", "attack_position_range_row_ratio", "attack_position_queue_sequence", "attack_position_wait_reason", "attack_position_wait_target_id", "attack_position_wait_movement_policy"]:
			unrestricted.erase(field)
		return unrestricted
	if _uses_enemy_attack_guidance(enemy_id, target):
		return _ensure_enemy_guided_attack_position(enemy_id, enemy, target)
	var target_key := _enemy_attack_target_key(target)
	var role := _enemy_attack_position_role(enemy)
	if target_key.is_empty():
		_release_enemy_attack_position(enemy_id, "target_missing")
		return target
	if _enemy_attack_position_by_enemy.has(enemy_id):
		var current_slot_id := str(_enemy_attack_position_by_enemy[enemy_id])
		var current_lease := _enemy_attack_position_leases.get(current_slot_id, {}) as Dictionary
		if str(current_lease.get("target_key", "")) != target_key or str(current_lease.get("role", "")) != role:
			_release_enemy_attack_position(enemy_id, "target_or_role_changed")
		else:
			for candidate in _get_enemy_attack_position_candidates(enemy_id, enemy, target):
				if str(candidate.get("slot_id", "")) != current_slot_id:
					continue
				# The reserved position was already snapped and path-validated by
				# _resolve_reachable_enemy_attack_position(). Replacing it every AI
				# refresh with the authored, unsnapped candidate makes ActorMotionBody
				# arrive at one point while the combat handoff measures another. A
				# millimetre-scale difference at the gate was enough to leave one enemy
				# permanently pressing after its motion had reported arrived.
				current_lease["authored_position"] = candidate.get(
					"position",
					current_lease.get("authored_position", current_lease.get("position", Vector3.ZERO))
				)
				if not current_lease.get("position", null) is Vector3:
					current_lease["position"] = candidate.get("position", Vector3.ZERO)
				current_lease["contact_position"] = candidate.get("contact_position", target.get("position", Vector3.ZERO))
				current_lease["target_position"] = target.get("position", Vector3.ZERO)
				_enemy_attack_position_leases[current_slot_id] = current_lease
				break
			return _decorate_target_with_enemy_attack_position(target, current_lease)
	var existing_wait := _find_enemy_attack_wait_entry(enemy_id, target_key)
	var wait_reason := str(_preview_enemy_target_opportunity(enemy_id, enemy, target).get("reason", ""))
	if not existing_wait.is_empty() and not force_waiter_retry:
		existing_wait = _refresh_enemy_attack_wait_entry(enemy_id, enemy, target, existing_wait, wait_reason)
		return _decorate_target_for_enemy_attack_wait(target, existing_wait)
	_remove_enemy_from_attack_wait_queues(enemy_id, target_key)
	var candidates := _get_enemy_attack_position_candidates(enemy_id, enemy, target)
	var reachable: Array[Dictionary] = []
	for candidate in candidates:
		if _is_enemy_attack_position_conflict(target_key, candidate, enemy_id):
			continue
		var resolved := _resolve_reachable_enemy_attack_position(enemy_id, candidate)
		if not resolved.is_empty():
			resolved["allocation_lane_distance"] = _get_front_gate_attack_lane_distance(
				enemy_id,
				enemy,
				target,
				resolved
			)
			reachable.append(resolved)
	reachable.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_lane_distance := float(left.get("allocation_lane_distance", INF))
		var right_lane_distance := float(right.get("allocation_lane_distance", INF))
		if not is_equal_approx(left_lane_distance, right_lane_distance):
			return left_lane_distance < right_lane_distance
		var left_distance := float(left.get("path_distance", INF))
		var right_distance := float(right.get("path_distance", INF))
		return str(left.get("slot_id", "")) < str(right.get("slot_id", "")) if is_equal_approx(left_distance, right_distance) else left_distance < right_distance
	)
	if reachable.is_empty():
		var wait_entry := (
			_refresh_enemy_attack_wait_entry(enemy_id, enemy, target, existing_wait, wait_reason)
			if not existing_wait.is_empty()
			else _enqueue_enemy_attack_position_waiter(enemy_id, enemy, target, wait_reason)
		)
		return _decorate_target_for_enemy_attack_wait(target, wait_entry)
	var chosen := reachable[0].duplicate(true)
	var slot_id := str(chosen.get("slot_id", ""))
	chosen["enemy_id"] = enemy_id
	chosen["target_key"] = target_key
	chosen["target_type"] = str(target.get("type", ""))
	chosen["target_id"] = str(target.get("id", ""))
	chosen["target_position"] = target.get("position", Vector3.ZERO)
	chosen["status"] = "reserved"
	chosen["reserved_frame"] = _formal_crowd_logic_frame
	_enemy_attack_position_leases[slot_id] = chosen
	_enemy_attack_position_by_enemy[enemy_id] = slot_id
	_remove_enemy_from_attack_wait_queues(enemy_id)
	_enemy_attack_position_metrics["reservations_created"] = int(_enemy_attack_position_metrics.get("reservations_created", 0)) + 1
	if not existing_wait.is_empty():
		_enemy_attack_position_metrics["waiters_promoted"] = int(_enemy_attack_position_metrics.get("waiters_promoted", 0)) + 1
	return _decorate_target_with_enemy_attack_position(target, chosen)


func _release_enemy_attack_position(enemy_id: String, reason: String, mark_unreachable: bool = false, promote_waiters: bool = true) -> Dictionary:
	var released: Dictionary = {}
	_end_enemy_precise_arrival_recovery(enemy_id, "cancelled:%s" % reason)
	_end_enemy_guidance_stall_recovery(enemy_id, "cancelled:%s" % reason)
	if _enemy_attack_position_by_enemy.has(enemy_id):
		var slot_id := str(_enemy_attack_position_by_enemy[enemy_id])
		released = (_enemy_attack_position_leases.get(slot_id, {}) as Dictionary).duplicate(true)
		_enemy_attack_position_by_enemy.erase(enemy_id)
		_enemy_attack_position_leases.erase(slot_id)
		if mark_unreachable and not slot_id.is_empty():
			var blocked := _enemy_attack_unreachable_until_frame.get(enemy_id, {}) as Dictionary
			blocked[slot_id] = _formal_crowd_logic_frame + maxi(1, int(_formal_attack_position_policy.get("unreachable_retry_frames", 120)))
			_enemy_attack_unreachable_until_frame[enemy_id] = blocked
		if not released.is_empty():
			released["release_reason"] = reason
			_enemy_attack_position_metrics["reservations_released"] = int(_enemy_attack_position_metrics.get("reservations_released", 0)) + 1
	_remove_enemy_from_attack_wait_queues(enemy_id)
	if promote_waiters and not released.is_empty():
		_promote_enemy_attack_position_waiter(str(released.get("target_key", "")), released.get("position", Vector3.ZERO))
	return released


func _promote_enemy_attack_position_waiter(target_key: String, released_position: Vector3) -> void:
	var queue := (_enemy_attack_wait_queues.get(target_key, []) as Array).duplicate(true)
	if queue.is_empty():
		return
	queue.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_enemy_id := str(left.get("enemy_id", ""))
		var right_enemy_id := str(right.get("enemy_id", ""))
		var left_enemy := _active_enemies.get(left_enemy_id, {}) as Dictionary
		var right_enemy := _active_enemies.get(right_enemy_id, {}) as Dictionary
		var left_position: Vector3 = left_enemy.get("position", Vector3.INF)
		var right_position: Vector3 = right_enemy.get("position", Vector3.INF)
		var left_distance := Vector2(left_position.x, left_position.z).distance_to(Vector2(released_position.x, released_position.z))
		var right_distance := Vector2(right_position.x, right_position.z).distance_to(Vector2(released_position.x, released_position.z))
		return int(left.get("sequence", 0)) < int(right.get("sequence", 0)) if is_equal_approx(left_distance, right_distance) else left_distance < right_distance
	)
	for raw_entry in queue:
		var entry := raw_entry as Dictionary
		var enemy_id := str(entry.get("enemy_id", ""))
		if not _active_enemies.has(enemy_id):
			_remove_enemy_from_attack_wait_queues(enemy_id)
			continue
		var enemy := _active_enemies.get(enemy_id, {}) as Dictionary
		var target := entry.get("target", {}) as Dictionary
		var promoted_target := _ensure_enemy_attack_position(enemy_id, enemy, target, true)
		if str(promoted_target.get("attack_position_status", "")) == "reserved":
			_configure_enemy_attack_wait_avoidance(enemy_id, false)
			enemy["target"] = promoted_target
			enemy["current_action"] = "pressing_to_%s" % str(target.get("id", "target"))
			_active_enemies[enemy_id] = enemy
			_ensure_formal_dynamic_pressure_motion(enemy_id, promoted_target)
			return


func _get_enemy_attack_motion_position(target: Dictionary, fallback: Vector3) -> Vector3:
	var attack_position: Variant = target.get("attack_position", null)
	return attack_position if attack_position is Vector3 else target.get("position", fallback)


func _get_enemy_attack_contact_position(target: Dictionary, fallback: Vector3) -> Vector3:
	var contact_position: Variant = target.get("attack_contact_position", null)
	return contact_position if contact_position is Vector3 else target.get("position", fallback)


func _has_enemy_reached_attack_position(enemy_id: String, target: Dictionary) -> bool:
	if str(target.get("type", "")) == "npc":
		return true
	if not _uses_enemy_attack_position_leases(enemy_id):
		return true
	# Guidance zones are navigation hints, never an attack-permission gate. The
	# authoritative range check against attack_contact_position in the combat step
	# decides when motion yields to the existing melee/projectile timeline.
	if _uses_enemy_attack_guidance(enemy_id, target):
		return true
	if str(target.get("attack_position_status", "")) not in ["reserved", "occupied"]:
		return false
	var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	if actor == null:
		return false
	var attack_position: Vector3 = target.get("attack_position", actor.global_position)
	var tolerance := _get_enemy_attack_position_arrival_tolerance(enemy_id, target)
	var position_distance := Vector2(actor.global_position.x, actor.global_position.z).distance_to(
		Vector2(attack_position.x, attack_position.z)
	)
	if _enemy_attack_position_by_enemy.has(enemy_id):
		var existing_slot_id := str(_enemy_attack_position_by_enemy[enemy_id])
		var existing_lease := _enemy_attack_position_leases.get(existing_slot_id, {}) as Dictionary
		if str(existing_lease.get("status", "")) == "occupied":
			tolerance += maxf(0.0, float(_formal_attack_position_policy.get("engagement_position_exit_margin", 0.18)))
	var reached := position_distance <= tolerance
	if reached and _enemy_attack_position_by_enemy.has(enemy_id):
		var slot_id := str(_enemy_attack_position_by_enemy[enemy_id])
		var recovered := _enemy_precise_arrival_recoveries.has(enemy_id)
		_end_enemy_precise_arrival_recovery(enemy_id, "completed", actor, position_distance)
		var lease := _enemy_attack_position_leases.get(slot_id, {}) as Dictionary
		lease["status"] = "occupied"
		if not lease.has("occupied_frame"):
			lease["occupied_frame"] = _formal_crowd_logic_frame
		lease["arrival_mode"] = "precise_after_avoidance_recovery" if recovered else "precise"
		lease["arrival_distance"] = position_distance
		_enemy_attack_position_leases[slot_id] = lease
		return true
	_update_enemy_precise_arrival_recovery(enemy_id, target, actor, position_distance, tolerance)
	return reached


func _update_enemy_guidance_stall_recovery(
	enemy_id: String,
	target: Dictionary,
	actor: ActorMotionBody,
	contact_distance: float,
	effective_attack_range: float
) -> void:
	var eligible := (
		actor != null
		and _uses_enemy_attack_guidance(enemy_id, target)
		and str(target.get("type", "")) in ["building", "defense_device"]
		and contact_distance > effective_attack_range
	)
	if not eligible:
		_end_enemy_guidance_stall_recovery(enemy_id, "completed:no_longer_outside_attack_range", actor)
		return
	var motion := actor.debug_get_motion_snapshot()
	var required_stationary_seconds := maxf(
		0.1,
		float(_formal_attack_position_policy.get("guidance_stall_recovery_seconds", 0.75))
	)
	if _enemy_guidance_stall_recoveries.has(enemy_id):
		var active_recovery := (_enemy_guidance_stall_recoveries.get(enemy_id, {}) as Dictionary).duplicate(true)
		var stationary_elapsed := float(motion.get("stationary_elapsed_seconds", 0.0))
		if stationary_elapsed < required_stationary_seconds * 0.5:
			_end_enemy_guidance_stall_recovery(enemy_id, "completed:movement_resumed", actor)
			return
		active_recovery["target_key"] = _enemy_attack_target_key(target)
		active_recovery["contact_distance"] = contact_distance
		active_recovery["effective_attack_range"] = effective_attack_range
		active_recovery["stationary_elapsed_seconds"] = stationary_elapsed
		active_recovery["stationary_supersede_preserve_count"] = int(motion.get("stationary_supersede_preserve_count", 0))
		_enemy_guidance_stall_recoveries[enemy_id] = active_recovery
		if stationary_elapsed >= float(active_recovery.get("last_reselect_stationary_seconds", 0.0)) + required_stationary_seconds:
			_exclude_current_enemy_guidance_slot_for_stall(enemy_id, target, stationary_elapsed)
		return
	if (
		not bool(motion.get("active", false))
		or bool(motion.get("paused", false))
		or float(motion.get("stationary_elapsed_seconds", 0.0)) < required_stationary_seconds
	):
		return
	_begin_enemy_guidance_stall_recovery(
		enemy_id,
		target,
		actor,
		contact_distance,
		effective_attack_range,
		motion
	)


func _begin_enemy_guidance_stall_recovery(
	enemy_id: String,
	target: Dictionary,
	actor: ActorMotionBody,
	contact_distance: float,
	effective_attack_range: float,
	motion: Dictionary
) -> void:
	if _enemy_guidance_stall_recoveries.has(enemy_id) or _enemy_precise_arrival_recoveries.has(enemy_id):
		return
	var recovery := {
		"enemy_id": enemy_id,
		"target_key": _enemy_attack_target_key(target),
		"started_frame": _formal_crowd_logic_frame,
		"started_contact_distance": contact_distance,
		"effective_attack_range": effective_attack_range,
		"stationary_elapsed_seconds": float(motion.get("stationary_elapsed_seconds", 0.0)),
		"stationary_supersede_preserve_count": int(motion.get("stationary_supersede_preserve_count", 0)),
		"repath_count": int(motion.get("repath_count", 0)),
		"last_reselect_stationary_seconds": float(motion.get("stationary_elapsed_seconds", 0.0)),
		"excluded_slot_ids": PackedStringArray(),
		"reselection_count": 0,
		"active": true
	}
	_enemy_guidance_stall_recoveries[enemy_id] = recovery
	actor.set_runtime_actor_collision_enabled(false, "enemy_guidance_stall_recovery")
	_enemy_attack_position_metrics["guidance_stall_recoveries_started"] = int(
		_enemy_attack_position_metrics.get("guidance_stall_recoveries_started", 0)
	) + 1
	if _enemy_attack_position_by_enemy.has(enemy_id):
		var record_key := str(_enemy_attack_position_by_enemy[enemy_id])
		var lease := _enemy_attack_position_leases.get(record_key, {}) as Dictionary
		lease["guidance_stall_recovery"] = recovery.duplicate(true)
		lease["guidance_stall_recovery_active"] = true
		_enemy_attack_position_leases[record_key] = lease
	_exclude_current_enemy_guidance_slot_for_stall(
		enemy_id,
		target,
		float(motion.get("stationary_elapsed_seconds", 0.0))
	)


func _exclude_current_enemy_guidance_slot_for_stall(
	enemy_id: String,
	target: Dictionary,
	stationary_elapsed_seconds: float
) -> void:
	if not _enemy_guidance_stall_recoveries.has(enemy_id):
		return
	var slot_id := str(target.get("attack_position_id", ""))
	if slot_id.is_empty():
		return
	var recovery := (_enemy_guidance_stall_recoveries.get(enemy_id, {}) as Dictionary).duplicate(true)
	var excluded := PackedStringArray(recovery.get("excluded_slot_ids", []))
	if not excluded.has(slot_id):
		excluded.append(slot_id)
		recovery["reselection_count"] = int(recovery.get("reselection_count", 0)) + 1
		_enemy_attack_position_metrics["guidance_stall_reselections"] = int(
			_enemy_attack_position_metrics.get("guidance_stall_reselections", 0)
		) + 1
	recovery["excluded_slot_ids"] = excluded
	recovery["last_excluded_slot_id"] = slot_id
	recovery["last_reselect_stationary_seconds"] = stationary_elapsed_seconds
	_enemy_guidance_stall_recoveries[enemy_id] = recovery


func _end_enemy_guidance_stall_recovery(
	enemy_id: String,
	outcome: String,
	actor_override: ActorMotionBody = null
) -> void:
	if not _enemy_guidance_stall_recoveries.has(enemy_id):
		return
	var actor := actor_override
	if actor == null:
		actor = get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	if actor != null and not _enemy_precise_arrival_recoveries.has(enemy_id):
		actor.set_runtime_avoidance_enabled(true)
	if actor != null:
		actor.set_runtime_actor_collision_enabled(true)
	var recovery := (_enemy_guidance_stall_recoveries.get(enemy_id, {}) as Dictionary).duplicate(true)
	recovery["active"] = false
	recovery["outcome"] = outcome
	recovery["ended_frame"] = _formal_crowd_logic_frame
	_enemy_guidance_stall_recoveries.erase(enemy_id)
	var metric_key := (
		"guidance_stall_recoveries_completed"
		if outcome.begins_with("completed:")
		else "guidance_stall_recoveries_cancelled"
	)
	_enemy_attack_position_metrics[metric_key] = int(_enemy_attack_position_metrics.get(metric_key, 0)) + 1
	if _enemy_attack_position_by_enemy.has(enemy_id):
		var record_key := str(_enemy_attack_position_by_enemy[enemy_id])
		var lease := _enemy_attack_position_leases.get(record_key, {}) as Dictionary
		lease["guidance_stall_recovery"] = recovery
		lease["guidance_stall_recovery_active"] = false
		_enemy_attack_position_leases[record_key] = lease


func _update_enemy_precise_arrival_recovery(
	enemy_id: String,
	target: Dictionary,
	actor: ActorMotionBody,
	position_distance: float,
	precise_tolerance: float
) -> void:
	var recovery_radius := maxf(
		precise_tolerance,
		float(_formal_attack_position_policy.get("melee_precise_arrival_recovery_radius", 0.32))
	)
	if _enemy_precise_arrival_recoveries.has(enemy_id):
		if (
			str(target.get("attack_position_status", "")) != "reserved"
			or position_distance > recovery_radius
		):
			_end_enemy_precise_arrival_recovery(enemy_id, "cancelled:left_recovery_radius", actor, position_distance)
		return
	var enemy: Dictionary = _active_enemies.get(enemy_id, {}) if _active_enemies.get(enemy_id, {}) is Dictionary else {}
	if (
		str(target.get("attack_position_status", "")) != "reserved"
		or str(target.get("type", "")) != "defense_device"
		or str(enemy.get("weapon_type", "")) not in MELEE_WEAPON_TYPES
		or position_distance > recovery_radius
	):
		return
	var motion := actor.debug_get_motion_snapshot()
	var required_stuck_seconds := maxf(
		0.1,
		float(_formal_attack_position_policy.get("melee_precise_arrival_recovery_stuck_seconds", 0.75))
	)
	if (
		not bool(motion.get("active", false))
		or bool(motion.get("paused", false))
		or float(motion.get("stuck_elapsed_seconds", 0.0)) < required_stuck_seconds
	):
		return
	_begin_enemy_precise_arrival_recovery(enemy_id, actor, position_distance, motion)


func _begin_enemy_precise_arrival_recovery(
	enemy_id: String,
	actor: ActorMotionBody,
	position_distance: float,
	motion: Dictionary
) -> void:
	if _enemy_precise_arrival_recoveries.has(enemy_id):
		return
	var recovery := {
		"enemy_id": enemy_id,
		"started_frame": _formal_crowd_logic_frame,
		"started_distance": position_distance,
		"stuck_elapsed_seconds": float(motion.get("stuck_elapsed_seconds", 0.0)),
		"repath_count": int(motion.get("repath_count", 0))
	}
	_enemy_precise_arrival_recoveries[enemy_id] = recovery
	_enemy_attack_position_metrics["precise_arrival_recoveries_started"] = int(
		_enemy_attack_position_metrics.get("precise_arrival_recoveries_started", 0)
	) + 1
	if _enemy_attack_position_by_enemy.has(enemy_id):
		var slot_id := str(_enemy_attack_position_by_enemy[enemy_id])
		var lease := _enemy_attack_position_leases.get(slot_id, {}) as Dictionary
		lease["precise_arrival_recovery"] = recovery.duplicate(true)
		lease["precise_arrival_recovery_active"] = true
		_enemy_attack_position_leases[slot_id] = lease
	actor.set_runtime_avoidance_enabled(false, "melee_precise_arrival_recovery")


func _end_enemy_precise_arrival_recovery(
	enemy_id: String,
	outcome: String,
	actor_override: ActorMotionBody = null,
	final_distance: float = -1.0
) -> void:
	var actor := actor_override
	if actor == null:
		actor = get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	if actor != null:
		actor.set_runtime_avoidance_enabled(true)
	if not _enemy_precise_arrival_recoveries.has(enemy_id):
		return
	var recovery := (_enemy_precise_arrival_recoveries.get(enemy_id, {}) as Dictionary).duplicate(true)
	recovery["active"] = false
	recovery["outcome"] = outcome
	recovery["ended_frame"] = _formal_crowd_logic_frame
	if final_distance >= 0.0:
		recovery["final_distance"] = final_distance
	_enemy_precise_arrival_recoveries.erase(enemy_id)
	var metric_key := (
		"precise_arrival_recoveries_completed"
		if outcome == "completed"
		else "precise_arrival_recoveries_cancelled"
	)
	_enemy_attack_position_metrics[metric_key] = int(_enemy_attack_position_metrics.get(metric_key, 0)) + 1
	if _enemy_attack_position_by_enemy.has(enemy_id):
		var slot_id := str(_enemy_attack_position_by_enemy[enemy_id])
		var lease := _enemy_attack_position_leases.get(slot_id, {}) as Dictionary
		lease["precise_arrival_recovery"] = recovery
		lease["precise_arrival_recovery_active"] = false
		_enemy_attack_position_leases[slot_id] = lease


func _get_enemy_attack_position_arrival_tolerance(enemy_id: String, target: Dictionary) -> float:
	var default_tolerance := maxf(0.05, float(_formal_attack_position_policy.get("arrival_tolerance", 0.32)))
	var enemy: Dictionary = _active_enemies.get(enemy_id, {}) if _active_enemies.get(enemy_id, {}) is Dictionary else {}
	if str(enemy.get("weapon_type", "")) not in MELEE_WEAPON_TYPES:
		return default_tolerance
	if (
		str(_formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2"
		and str(target.get("type", "")) in ["building", "defense_device"]
		and target.get("attack_position", null) is Vector3
	):
		var guide_position: Vector3 = target.get("attack_position", Vector3.ZERO)
		var guide_contact: Variant = target.get(
			"attack_guidance_selected_zone_contact_position",
			target.get("attack_contact_position", null)
		)
		if guide_contact is Vector3:
			var guidance_distance := Vector2(guide_position.x, guide_position.z).distance_to(
				Vector2((guide_contact as Vector3).x, (guide_contact as Vector3).z)
			)
			var arrival_margin := maxf(
				0.0,
				float(_formal_attack_position_policy.get("attack_range_arrival_margin", 0.02))
			)
			var effective_attack_distance := maxf(
				0.1,
				_get_enemy_guided_attack_handoff_range(enemy, target) - arrival_margin
			)
			# Navigation may stop anywhere inside target_desired_distance. The only
			# safe radius is the reach left between the selected guide centre and its
			# corresponding hurtbox contact; the generic 0.32 m would let gate attackers
			# finish motion while still outside the real melee handoff band. Keep the
			# authored range-arrival margin inside that remaining slack as well.
			return clampf(
				effective_attack_distance - guidance_distance,
				0.01,
				default_tolerance
			)
	if (
		str(target.get("attack_position_status", "")) != "reserved"
		or str(target.get("type", "")) != "defense_device"
	):
		return default_tolerance
	# Legacy lease schema keeps the previously calibrated precise device arrival.
	return clampf(
		float(_formal_attack_position_policy.get("melee_attack_position_arrival_tolerance", 0.06)),
		0.01,
		default_tolerance
	)


func _clear_enemy_attack_positions() -> void:
	for raw_enemy_id in _enemy_precise_arrival_recoveries.keys():
		_end_enemy_precise_arrival_recovery(str(raw_enemy_id), "cancelled:attack_positions_cleared")
	for raw_enemy_id in _enemy_guidance_stall_recoveries.keys():
		_end_enemy_guidance_stall_recovery(str(raw_enemy_id), "cancelled:attack_positions_cleared")
	_enemy_attack_position_leases.clear()
	_enemy_attack_position_by_enemy.clear()
	_enemy_attack_wait_queues.clear()
	_enemy_attack_unreachable_until_frame.clear()
	_enemy_precise_arrival_recoveries.clear()
	_enemy_guidance_stall_recoveries.clear()
	_enemy_attack_wait_sequence = 0
	_formal_attack_position_policy.clear()
	_enemy_attack_position_metrics = {
		"reservations_created": 0,
		"reservations_released": 0,
		"guidance_assignments_created": 0,
		"guidance_zone_switches": 0,
		"guidance_in_range_handoffs": 0,
		"waiters_enqueued": 0,
		"waiters_promoted": 0,
		"unreachable_candidates_rejected": 0,
		"precise_arrival_recoveries_started": 0,
		"precise_arrival_recoveries_completed": 0,
		"precise_arrival_recoveries_cancelled": 0,
		"guidance_stall_recoveries_started": 0,
		"guidance_stall_recoveries_completed": 0,
		"guidance_stall_recoveries_cancelled": 0,
		"guidance_stall_reselections": 0
	}


func _clear_enemy_targeting_runtime() -> void:
	_formal_enemy_targeting_policy.clear()
	_enemy_retaliation_relations.clear()
	_enemy_retaliation_sequence = 0
	_enemy_high_threat_reacquire_requests.clear()
	_enemy_high_threat_reacquire_sequence = 0
	_enemy_targeting_metrics = {
		"evaluations": 0,
		"target_switches": 0,
		"higher_priority_switches": 0,
		"locked_high_target_holds": 0,
		"locked_unarmed_target_holds": 0,
		"high_threat_preemptions": 0,
		"different_attacker_damage_signals": 0,
		"different_attacker_damage_reacquisitions": 0,
		"different_attacker_damage_no_candidate_consumptions": 0,
		"fixed_target_full_skips": 0,
		"gate_full_holds": 0,
		"building_fallbacks": 0
	}
	_clear_friendly_targeting_runtime()


func _clear_friendly_targeting_runtime() -> void:
	_friendly_enemy_reacquire_requests.clear()
	_friendly_enemy_reacquire_sequence = 0
	_friendly_targeting_metrics = {
		"evaluations": 0,
		"initial_acquisitions": 0,
		"locked_target_holds": 0,
		"invalid_target_reacquisitions": 0,
		"different_attacker_damage_signals": 0,
		"different_attacker_damage_reacquisitions": 0,
		"different_attacker_damage_no_candidate_consumptions": 0,
		"target_switches": 0
	}


func debug_get_enemy_targeting_snapshot() -> Dictionary:
	_prune_enemy_retaliation_relations()
	var locks: Array[Dictionary] = []
	for enemy_id in get_active_enemy_ids():
		var enemy := _active_enemies.get(enemy_id, {}) as Dictionary
		locks.append({
			"enemy_id": enemy_id,
			"target_priority": int(enemy.get("target_priority", 0)),
			"target_selection_reason": str(enemy.get("target_selection_reason", "")),
			"target_lock_until_frame": int(enemy.get("target_lock_until_frame", 0)),
			"target_last_evaluated_frame": int(enemy.get("target_last_evaluated_frame", -1)),
			"target_switch_count": int(enemy.get("target_switch_count", 0)),
			"different_attacker_damage_reacquire_pending": _enemy_high_threat_reacquire_requests.has(enemy_id),
			"target": _serialize_target(enemy.get("target", {}) as Dictionary if enemy.get("target", {}) is Dictionary else {})
		})
	var reacquire_requests: Array[Dictionary] = []
	for raw_enemy_id in _enemy_high_threat_reacquire_requests.keys():
		var reacquire_enemy_id := str(raw_enemy_id)
		var request := (_enemy_high_threat_reacquire_requests.get(reacquire_enemy_id, {}) as Dictionary).duplicate(true)
		request["enemy_id"] = reacquire_enemy_id
		reacquire_requests.append(request)
	reacquire_requests.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("sequence", 0)) < int(right.get("sequence", 0)))
	var retaliation: Array[Dictionary] = []
	var active_retaliation: Array[Dictionary] = []
	for raw_enemy_id in _enemy_retaliation_relations.keys():
		var enemy_id := str(raw_enemy_id)
		for raw_relation in (_enemy_retaliation_relations.get(enemy_id, {}) as Dictionary).values():
			var relation := (raw_relation as Dictionary).duplicate(true)
			relation["enemy_id"] = enemy_id
			retaliation.append(relation)
	for enemy_id in get_active_enemy_ids():
		var enemy := _active_enemies.get(enemy_id, {}) as Dictionary
		var sources := _collect_enemy_retaliation_targets(enemy_id, enemy.get("position", Vector3.ZERO))
		for source_type in ["npc", "defense_device"]:
			for raw_target in sources.get(source_type, []):
				var target := _serialize_target((raw_target as Dictionary).duplicate(true))
				target["enemy_id"] = enemy_id
				active_retaliation.append(target)
	return {
		"schema": str(_formal_enemy_targeting_policy.get("schema", "")),
		"current_frame": _formal_crowd_logic_frame,
		"priorities": (_formal_enemy_targeting_policy.get("priorities", []) as Array).duplicate(),
		"policy": _formal_enemy_targeting_policy.duplicate(true),
		"combat_navigation_policy": _combat_navigation_policy.duplicate(true),
		"locks": locks,
		"different_attacker_damage_reacquire_requests": reacquire_requests,
		"retaliation_relations": retaliation,
		"active_retaliation_targets": active_retaliation,
		"metrics": _enemy_targeting_metrics.duplicate(true)
	}


func debug_get_enemy_attack_position_snapshot() -> Dictionary:
	var leases: Array[Dictionary] = []
	for raw_lease in _enemy_attack_position_leases.values():
		var record := (raw_lease as Dictionary).duplicate(true)
		if str(_formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2":
			var occupancy := _get_enemy_guidance_zone_occupancy(record, str(record.get("enemy_id", "")))
			record["guidance_occupancy_count"] = int(occupancy.get("count", 0))
			record["guidance_occupant_enemy_ids"] = (occupancy.get("enemy_ids", []) as Array).duplicate()
		leases.append(_serialize_target(record))
	leases.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("slot_id", "")) < str(right.get("slot_id", "")))
	var waiters: Array[Dictionary] = []
	for raw_queue in _enemy_attack_wait_queues.values():
		var queue := raw_queue as Array
		for raw_entry in queue:
			var entry := (raw_entry as Dictionary).duplicate(true)
			entry.erase("target")
			waiters.append(_serialize_target(entry))
	waiters.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("sequence", 0)) < int(right.get("sequence", 0)))
	return {
		"schema": str(_formal_attack_position_policy.get("schema", "")),
		"lease_count": leases.size(),
		"guidance_count": leases.size() if str(_formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2" else 0,
		"waiter_count": waiters.size(),
		"leases": leases,
		"guidance_assignments": leases if str(_formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2" else [],
		"waiters": waiters,
		"precise_arrival_recoveries": _enemy_precise_arrival_recoveries.values().duplicate(true),
		"guidance_stall_recoveries": _enemy_guidance_stall_recoveries.values().duplicate(true),
		"metrics": _enemy_attack_position_metrics.duplicate(true)
	}


func debug_release_enemy_attack_position(enemy_id: String, reason: String = "debug_release") -> Dictionary:
	return _release_enemy_attack_position(enemy_id, reason)


func _get_enemy_target_detection_range(enemy: Dictionary) -> float:
	return maxf(0.1, float(_formal_enemy_targeting_policy.get("detection_range", 37.2)))


func _get_enemy_defense_device_detection_range(enemy: Dictionary, target: Dictionary) -> float:
	return _get_enemy_target_detection_range(enemy)


func _make_npc_enemy_target(npc_id: String, origin: Vector3) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_id.is_empty()
		or npc_system == null
		or not npc_system.has_method("get_npc_world_position")
		or not npc_system.has_method("get_npc")
	):
		return {}
	if (
		_default_formal_wave_active
		and npc_system.has_method("is_npc_in_formal_combat_world")
		and not npc_system.is_npc_in_formal_combat_world(npc_id)
	):
		return {}
	if npc_system.has_method("can_npc_act") and not npc_system.can_npc_act(npc_id):
		return {}
	var raw_position: Variant = npc_system.get_npc_world_position(npc_id)
	if raw_position == null or not raw_position is Vector3:
		return {}
	var position := raw_position as Vector3
	var identity: Dictionary
	if npc_system.has_method("get_npc_combat_identity"):
		identity = npc_system.get_npc_combat_identity(npc_id)
	else:
		var npc: Dictionary = npc_system.get_npc(npc_id)
		identity = {"name": str(npc.get("name", npc_id)), "has_main_weapon": not _get_npc_main_weapon(npc).is_empty()}
	var has_main_weapon := bool(identity.get("has_main_weapon", false))
	return {
		"type": "npc",
		"id": npc_id,
		"name": str(identity.get("name", npc_id)),
		"position": position,
		"contact_radius": 0.35,
		"has_main_weapon": has_main_weapon,
		"target_class": "combat_unit" if has_main_weapon else "noncombat_unit",
		"distance": _horizontal_vector_distance(origin, position)
	}


func _make_defense_device_enemy_target(deployment_id: String, origin: Vector3) -> Dictionary:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if deployment_id.is_empty() or device_system == null or not device_system.has_method("get_active_defense_targets"):
		return {}
	for raw_target in device_system.get_active_defense_targets():
		if not raw_target is Dictionary:
			continue
		var target := raw_target as Dictionary
		if str(target.get("id", "")) != deployment_id:
			continue
		var position: Vector3 = target.get("position", origin)
		var result := target.duplicate(true)
		result["distance"] = _horizontal_vector_distance(origin, position)
		return result
	return {}


func _is_enemy_target_valid(target: Dictionary) -> bool:
	return not target.is_empty() and not _is_target_defeated(target)


func _enemy_target_priority(target: Dictionary, enemy: Dictionary) -> int:
	var target_type := str(target.get("type", ""))
	var target_id := str(target.get("id", ""))
	if target_type == "npc":
		return 1 if bool(target.get("has_main_weapon", false)) else 2
	if target_type == "defense_device":
		return 1
	match target_id:
		"front_gate":
			return 3
		"warehouse":
			return 4
		"main_hall":
			return 5
	return 6


func _preview_enemy_target_opportunity(enemy_id: String, enemy: Dictionary, target: Dictionary) -> Dictionary:
	if not _is_enemy_target_valid(target):
		return {"available": false, "reason": "invalid_target"}
	if str(target.get("type", "")) == "npc":
		return {
			"available": true,
			"reason": "npc_unrestricted_contact",
			"path_distance": float(target.get("distance", _horizontal_vector_distance(enemy.get("position", Vector3.ZERO), target.get("position", Vector3.ZERO))))
		}
	if not _uses_enemy_attack_position_leases(enemy_id):
		return {
			"available": true,
			"reason": "legacy_without_lease",
			"path_distance": _horizontal_vector_distance(enemy.get("position", Vector3.ZERO), target.get("position", Vector3.ZERO))
		}
	if _uses_enemy_attack_guidance(enemy_id, target):
		var best_path_distance := INF
		for candidate in _get_enemy_attack_position_candidates(enemy_id, enemy, target):
			var resolved := _resolve_reachable_enemy_attack_position(enemy_id, candidate)
			if not resolved.is_empty():
				best_path_distance = minf(best_path_distance, float(resolved.get("path_distance", INF)))
		return (
			{
				"available": true,
				"reason": "reachable_guidance_zone",
				"path_distance": best_path_distance
			}
			if best_path_distance < INF
			else {"available": false, "reason": "guidance_unreachable"}
		)
	var target_key := _enemy_attack_target_key(target)
	if _enemy_attack_position_by_enemy.has(enemy_id):
		var current_slot_id := str(_enemy_attack_position_by_enemy[enemy_id])
		var current_lease := _enemy_attack_position_leases.get(current_slot_id, {}) as Dictionary
		if str(current_lease.get("target_key", "")) == target_key:
			return {
				"available": true,
				"reason": "existing_lease",
				"path_distance": _horizontal_vector_distance(enemy.get("position", Vector3.ZERO), current_lease.get("position", Vector3.ZERO))
			}
	var candidate_not_occupied_seen := false
	var unreserved_candidate_seen := false
	var reserved_in_transit_conflict_seen := false
	var best_path_distance := INF
	for candidate in _get_enemy_attack_position_candidates(enemy_id, enemy, target):
		if _is_enemy_attack_position_conflict(target_key, candidate, enemy_id, true):
			continue
		candidate_not_occupied_seen = true
		if _is_enemy_attack_position_conflict(target_key, candidate, enemy_id):
			reserved_in_transit_conflict_seen = true
			continue
		unreserved_candidate_seen = true
		var resolved := _resolve_reachable_enemy_attack_position(enemy_id, candidate)
		if resolved.is_empty():
			continue
		best_path_distance = minf(best_path_distance, float(resolved.get("path_distance", INF)))
	if best_path_distance < INF:
		return {"available": true, "reason": "reachable_open_position", "path_distance": best_path_distance}
	if candidate_not_occupied_seen and reserved_in_transit_conflict_seen:
		return {
			"available": true,
			"reason": "reserved_in_transit",
			"path_distance": _horizontal_vector_distance(enemy.get("position", Vector3.ZERO), target.get("position", Vector3.ZERO))
		}
	return {
		"available": false,
		"reason": "unreachable" if unreserved_candidate_seen else "full"
	}


func _get_collision_building_id(collider: Variant) -> String:
	var node := collider as Node
	while node != null:
		if node.has_meta("building_id"):
			return str(node.get_meta("building_id", ""))
		if node.has_meta("layout_id"):
			var layout_id := str(node.get_meta("layout_id", ""))
			if not layout_id.is_empty():
				return layout_id
		node = node.get_parent()
	return ""


func _find_attackable_obstruction_target(enemy_id: String, desired_target: Dictionary) -> Dictionary:
	var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as CollisionObject3D
	if actor == null or not is_inside_tree():
		return {}
	# The formal assault route has two authoritative destructible chokepoints.
	# A direct ray to an offset target may miss the door leaf even though every
	# navigable route is still gated by it, so resolve that route fact first.
	var desired_id := str(desired_target.get("id", ""))
	var desired_type := str(desired_target.get("type", ""))
	# Wall devices expose a low, outside-facing host proxy. Its leased attack
	# positions are the reachability authority; treating the slightly inset proxy
	# centre as being behind the gate incorrectly replaces the device with the gate.
	if desired_type == "defense_device" and str(desired_target.get("building_id", "")) == "wall":
		return {}
	var ordered_blockers: Array[String] = []
	if desired_id == "warehouse":
		ordered_blockers = ["front_gate"]
	elif desired_id == "main_hall":
		ordered_blockers = ["front_gate", "warehouse"]
	elif desired_type in ["npc", "defense_device"]:
		var gate_target := _make_building_target("front_gate")
		if not gate_target.is_empty():
			var gate_position: Vector3 = gate_target.get("position", actor.global_position)
			var gate_outward := _get_enemy_attack_position_outward(enemy_id, gate_target)
			var enemy_side := (actor.global_position - gate_position).dot(gate_outward)
			var desired_side := ((desired_target.get("position", gate_position) as Vector3) - gate_position).dot(gate_outward)
			if enemy_side > 0.25 and desired_side < -0.25:
				ordered_blockers = ["front_gate"]
	for blocker_id in ordered_blockers:
		var route_blocker := _make_building_target(blocker_id)
		if route_blocker.is_empty():
			continue
		route_blocker["target_selection_reason"] = "attackable_route_obstruction"
		route_blocker["obstructed_target_type"] = desired_type
		route_blocker["obstructed_target_id"] = desired_id
		return route_blocker
	var from_position := actor.global_position
	# Obstruction probing follows the authored route approach, not the structure's
	# combat centre. A ray to the centre of a large rotated footprint can cross a
	# perfectly avoidable neighbour even though NavigationServer routes around it.
	var to_position: Vector3 = desired_target.get(
		"route_approach_position",
		desired_target.get("position", from_position)
	)
	var probe_height := maxf(0.1, float(_formal_enemy_targeting_policy.get("obstruction_probe_height", 0.9)))
	from_position.y += probe_height
	to_position.y = from_position.y
	if _horizontal_vector_distance(from_position, to_position) <= 0.05:
		return {}
	var excluded: Array[RID] = [actor.get_rid()]
	var max_hits := maxi(1, int(_formal_enemy_targeting_policy.get("obstruction_probe_max_hits", 8)))
	var space_state := get_viewport().world_3d.direct_space_state
	for _probe_index in range(max_hits):
		var query := PhysicsRayQueryParameters3D.create(from_position, to_position, 1, excluded)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider: Object = hit.get("collider", null)
		var collision_object := collider as CollisionObject3D
		if collision_object != null:
			excluded.append(collision_object.get_rid())
		var building_id := _get_collision_building_id(collider)
		if (
			building_id.is_empty()
			or not ENEMY_BUILDING_TARGET_IDS.has(building_id)
			or building_id == str(desired_target.get("id", ""))
		):
			continue
		var blocker := _make_building_target(building_id)
		if blocker.is_empty():
			continue
		blocker["target_selection_reason"] = "attackable_obstruction"
		blocker["obstructed_target_type"] = str(desired_target.get("type", ""))
		blocker["obstructed_target_id"] = str(desired_target.get("id", ""))
		return blocker
	return {}


func _record_enemy_retaliation_relation(enemy_id: String, source_type: String, source_id: String, signal_type: String) -> void:
	if not _active_enemies.has(enemy_id) or source_id.is_empty() or not source_type in ["npc", "defense_device"]:
		return
	var relations := _enemy_retaliation_relations.get(enemy_id, {}) as Dictionary
	var key := "%s:%s" % [source_type, source_id]
	var relation := relations.get(key, {}) as Dictionary
	var signals := relation.get("signals", []) as Array
	if not signals.has(signal_type):
		signals.append(signal_type)
	relation["source_type"] = source_type
	relation["source_id"] = source_id
	relation["signals"] = signals
	relation["last_frame"] = _formal_crowd_logic_frame
	_enemy_retaliation_sequence += 1
	relation["last_sequence"] = _enemy_retaliation_sequence
	relation["expires_frame"] = _formal_crowd_logic_frame + maxi(1, int(_formal_enemy_targeting_policy.get("recent_hit_memory_frames", 360)))
	relations[key] = relation
	_enemy_retaliation_relations[enemy_id] = relations


func _make_enemy_damage_source_high_threat_target(enemy: Dictionary, source_type: String, source_id: String) -> Dictionary:
	if source_id.is_empty():
		return {}
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	var source_target: Dictionary = {}
	if source_type == "npc":
		source_target = _make_npc_enemy_target(source_id, enemy_position)
	elif source_type == "defense_device":
		source_target = _make_defense_device_enemy_target(source_id, enemy_position)
	return source_target if _is_enemy_high_threat_target(source_target) else {}


func _record_enemy_high_threat_damage_reacquire_request(
	enemy_id: String,
	enemy: Dictionary,
	source_type: String,
	source_id: String
) -> void:
	if (
		enemy_id.is_empty()
		or not _active_enemies.has(enemy_id)
		or source_id.is_empty()
		or not source_type in ["npc", "defense_device"]
	):
		return
	var current: Dictionary = enemy.get("target", {}) if enemy.get("target", {}) is Dictionary else {}
	var current_refreshed := _refresh_current_enemy_target(enemy, current)
	# Actual damage from an armed NPC / defense device must also wake an enemy
	# out of a lower-priority building or unarmed-NPC lock.  The old T0197 guard
	# accepted only an already-high-threat current target, which silently dropped
	# ballista hits while the enemy was attacking the gate.
	if current_refreshed.is_empty():
		return
	var source_target := _make_enemy_damage_source_high_threat_target(enemy, source_type, source_id)
	if source_target.is_empty() or _enemy_attack_target_key(source_target) == _enemy_attack_target_key(current_refreshed):
		return
	var previous_was_high_threat := _is_enemy_high_threat_target(current_refreshed)
	_enemy_high_threat_reacquire_sequence += 1
	_enemy_high_threat_reacquire_requests[enemy_id] = {
		"schema": "enemy_high_threat_damage_reacquire_request_v2",
		"sequence": _enemy_high_threat_reacquire_sequence,
		"created_frame": _formal_crowd_logic_frame,
		"source_type": source_type,
		"source_id": source_id,
		"previous_target_type": str(current_refreshed.get("type", "")),
		"previous_target_id": str(current_refreshed.get("id", "")),
		"trigger_kind": "different_high_threat_attacker" if previous_was_high_threat else "lower_priority_target_hit_by_high_threat"
	}
	_enemy_targeting_metrics["different_attacker_damage_signals"] = int(
		_enemy_targeting_metrics.get("different_attacker_damage_signals", 0)
	) + 1


func debug_record_enemy_retaliation(enemy_id: String, source_type: String, source_id: String, signal_type: String = "recent_hit") -> void:
	_record_enemy_retaliation_relation(enemy_id, source_type, source_id, signal_type)


func _prune_enemy_retaliation_relations(enemy_id: String = "") -> void:
	var enemy_ids := [enemy_id] if not enemy_id.is_empty() else _enemy_retaliation_relations.keys()
	for raw_enemy_id in enemy_ids:
		var active_enemy_id := str(raw_enemy_id)
		if not _active_enemies.has(active_enemy_id):
			_enemy_retaliation_relations.erase(active_enemy_id)
			continue
		var relations := _enemy_retaliation_relations.get(active_enemy_id, {}) as Dictionary
		for raw_key in relations.keys():
			var relation := relations.get(raw_key, {}) as Dictionary
			var source_type := str(relation.get("source_type", ""))
			var source_id := str(relation.get("source_id", ""))
			var source_valid := (
				not _make_npc_enemy_target(source_id, Vector3.ZERO).is_empty()
				if source_type == "npc"
				else not _make_defense_device_enemy_target(source_id, Vector3.ZERO).is_empty()
			)
			if int(relation.get("expires_frame", -1)) < _formal_crowd_logic_frame or not source_valid:
				relations.erase(raw_key)
		_enemy_retaliation_relations[active_enemy_id] = relations


func _collect_enemy_retaliation_targets(enemy_id: String, enemy_position: Vector3) -> Dictionary:
	_prune_enemy_retaliation_relations(enemy_id)
	var npc_signals: Dictionary = {}
	var defense_signals: Dictionary = {}
	var relations := _enemy_retaliation_relations.get(enemy_id, {}) as Dictionary
	for raw_relation in relations.values():
		var relation := raw_relation as Dictionary
		var source_type := str(relation.get("source_type", ""))
		var source_id := str(relation.get("source_id", ""))
		var signals := relation.get("signals", []) as Array
		if source_type == "npc":
			npc_signals[source_id] = signals.duplicate()
		elif source_type == "defense_device":
			defense_signals[source_id] = signals.duplicate()

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc_ids") and npc_system.has_method("get_npc_state"):
		for raw_npc_id in npc_system.get_npc_ids():
			var npc_id := str(raw_npc_id)
			var state: Dictionary = npc_system.get_npc_state(npc_id)
			if (
				str(state.get("combat_target_enemy_id", "")) == enemy_id
				or str(state.get("combat_attack_target_enemy_id", "")) == enemy_id
			):
				var signals := npc_signals.get(npc_id, []) as Array
				if not signals.has("attack_intent"):
					signals.append("attack_intent")
				npc_signals[npc_id] = signals

	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system != null and device_system.has_method("get_deployments"):
		for raw_deployment in device_system.get_deployments():
			var deployment := raw_deployment as Dictionary
			var attack_target := deployment.get("attack_target", {}) as Dictionary
			if str(attack_target.get("id", "")) != enemy_id:
				continue
			var deployment_id := str(deployment.get("deployment_id", ""))
			var signals := defense_signals.get(deployment_id, []) as Array
			if not signals.has("attack_intent"):
				signals.append("attack_intent")
			defense_signals[deployment_id] = signals

	for raw_projectile in _active_projectiles.values():
		var projectile := raw_projectile as Dictionary
		var intended := projectile.get("target_at_release", {}) as Dictionary
		if str(intended.get("id", "")) != enemy_id:
			continue
		var source_side := str(projectile.get("source_side", ""))
		var source_id := str(projectile.get("source_id", ""))
		if source_side == "friendly":
			var signals := npc_signals.get(source_id, []) as Array
			if not signals.has("projectile_in_flight"):
				signals.append("projectile_in_flight")
			npc_signals[source_id] = signals
		elif source_side == "defense_device":
			var signals := defense_signals.get(source_id, []) as Array
			if not signals.has("projectile_in_flight"):
				signals.append("projectile_in_flight")
			defense_signals[source_id] = signals

	var result := {"npc": [] as Array[Dictionary], "defense_device": [] as Array[Dictionary]}
	for raw_npc_id in npc_signals.keys():
		var target := _make_npc_enemy_target(str(raw_npc_id), enemy_position)
		if target.is_empty():
			continue
		target["retaliation_signals"] = (npc_signals[raw_npc_id] as Array).duplicate()
		(result["npc"] as Array).append(target)
	for raw_deployment_id in defense_signals.keys():
		var target := _make_defense_device_enemy_target(str(raw_deployment_id), enemy_position)
		if target.is_empty():
			continue
		target["retaliation_signals"] = (defense_signals[raw_deployment_id] as Array).duplicate()
		(result["defense_device"] as Array).append(target)
	return result


func _has_enemy_recent_hit_relation(enemy_id: String) -> bool:
	_prune_enemy_retaliation_relations(enemy_id)
	for raw_relation in (_enemy_retaliation_relations.get(enemy_id, {}) as Dictionary).values():
		var relation := raw_relation as Dictionary
		if (relation.get("signals", []) as Array).has("recent_hit"):
			return true
	return false


func _select_enemy_recent_hit_preempt_target(enemy_id: String, enemy: Dictionary) -> Dictionary:
	_prune_enemy_retaliation_relations(enemy_id)
	var relations: Array[Dictionary] = []
	for raw_relation in (_enemy_retaliation_relations.get(enemy_id, {}) as Dictionary).values():
		var relation := raw_relation as Dictionary
		if (relation.get("signals", []) as Array).has("recent_hit"):
			relations.append(relation)
	relations.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_sequence := int(left.get("last_sequence", 0))
		var right_sequence := int(right.get("last_sequence", 0))
		if left_sequence != right_sequence:
			return left_sequence > right_sequence
		return int(left.get("last_frame", -1)) > int(right.get("last_frame", -1))
	)
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	for relation in relations:
		var source_type := str(relation.get("source_type", ""))
		var source_id := str(relation.get("source_id", ""))
		var target := (
			_make_npc_enemy_target(source_id, enemy_position)
			if source_type == "npc"
			else _make_defense_device_enemy_target(source_id, enemy_position)
		)
		if target.is_empty():
			continue
		target["retaliation_signals"] = (relation.get("signals", []) as Array).duplicate()
		target["target_priority"] = _enemy_target_priority(target, enemy)
		target["target_selection_reason"] = "recent_hit_preempt:%s:%s" % [source_type, source_id]
		var blocker := _find_attackable_obstruction_target(enemy_id, target)
		if not blocker.is_empty() and _enemy_attack_target_key(blocker) != _enemy_attack_target_key(target):
			blocker["target_priority"] = _enemy_target_priority(blocker, enemy)
			blocker["target_selection_reason"] = "recent_hit_route_obstruction_for_%s:%s" % [source_type, source_id]
			blocker["obstructed_target_type"] = source_type
			blocker["obstructed_target_id"] = source_id
			var blocker_opportunity := _preview_enemy_target_opportunity(enemy_id, enemy, blocker)
			if bool(blocker_opportunity.get("available", false)):
				blocker["target_opportunity"] = blocker_opportunity.duplicate(true)
				return blocker
			continue
		var opportunity := _preview_enemy_target_opportunity(enemy_id, enemy, target)
		if not bool(opportunity.get("available", false)):
			continue
		target["target_opportunity"] = opportunity.duplicate(true)
		target["target_path_distance"] = float(opportunity.get("path_distance", target.get("distance", INF)))
		return target
	return {}


func _collect_enemy_target_priority_groups(enemy_id: String, enemy: Dictionary) -> Dictionary:
	var measured: bool = _performance_probe != null and _performance_probe.active
	var started := Time.get_ticks_usec() if measured else 0
	var groups: Dictionary = {}
	for priority in range(1, 6):
		groups[priority] = [] as Array[Dictionary]
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	var detection_range := _get_enemy_target_detection_range(enemy)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc_ids"):
		for raw_npc_id in npc_system.get_npc_ids():
			var target := _make_npc_enemy_target(str(raw_npc_id), enemy_position)
			if target.is_empty() or float(target.get("distance", INF)) > detection_range:
				continue
			var npc_priority := 1 if bool(target.get("has_main_weapon", false)) else 2
			_merge_enemy_target_candidate(groups[npc_priority] as Array, target)
	if measured:
		_performance_probe.record("target_npc_groups_ms", Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system != null and device_system.has_method("get_active_defense_targets"):
		for raw_device_target in device_system.get_active_defense_targets():
			if not raw_device_target is Dictionary:
				continue
			var target := (raw_device_target as Dictionary).duplicate(true)
			var target_position: Vector3 = target.get("position", enemy_position)
			target["distance"] = _horizontal_vector_distance(enemy_position, target_position)
			target["enemy_detection_range"] = detection_range
			if float(target.get("distance", INF)) <= detection_range:
				_merge_enemy_target_candidate(groups[1] as Array, target)
	if measured:
		_performance_probe.record("target_device_groups_ms", Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
	for building_priority in range(3, 6):
		var building_id: String = ENEMY_BUILDING_TARGET_IDS[building_priority - 3]
		var building_target := _make_building_target(building_id)
		if not building_target.is_empty():
			building_target["distance"] = _horizontal_vector_distance(enemy_position, building_target.get("position", enemy_position))
			(groups[building_priority] as Array).append(building_target)
	if measured:
		_performance_probe.record("target_building_groups_ms", Time.get_ticks_usec() - started)
	return groups


func _is_enemy_fixed_target_present(enemy_id: String, enemy: Dictionary, target: Dictionary) -> bool:
	if not _is_enemy_target_valid(target):
		return false
	if str(target.get("type", "")) == "npc":
		return true
	# Guidance has no capacity limit: both reachable_guidance_zone and
	# guidance_unreachable previously returned true below. The actual selection
	# still path-validates ranked zones; presence does not need an all-zone preview.
	if _uses_enemy_attack_guidance(enemy_id, target):
		return true
	var opportunity := _preview_enemy_target_opportunity(enemy_id, enemy, target)
	var reason := str(opportunity.get("reason", ""))
	if reason == "full":
		# The front gate is the mandatory breach target. Capacity can make every
		# other fixed target absent for this enemy, but it must never let an enemy
		# skip the intact gate and target the warehouse behind it.
		if str(target.get("type", "")) == "building" and str(target.get("id", "")) == "front_gate":
			_enemy_targeting_metrics["gate_full_holds"] = int(_enemy_targeting_metrics.get("gate_full_holds", 0)) + 1
			return true
		_enemy_targeting_metrics["fixed_target_full_skips"] = int(_enemy_targeting_metrics.get("fixed_target_full_skips", 0)) + 1
		return false
	# Reachability belongs to the motion/path layer. Targeting only treats a fixed
	# target as absent when every compatible authored position is occupied.
	return reason != "invalid_target"


func _is_enemy_unit_target_in_unified_range(enemy: Dictionary, target: Dictionary) -> bool:
	if not _is_enemy_target_valid(target):
		return false
	return float(target.get("distance", INF)) <= _get_enemy_target_detection_range(enemy)


func _is_enemy_high_threat_target(target: Dictionary) -> bool:
	var target_type := str(target.get("type", ""))
	return target_type == "defense_device" or (target_type == "npc" and bool(target.get("has_main_weapon", false)))


func _is_enemy_unarmed_npc_target(target: Dictionary) -> bool:
	return str(target.get("type", "")) == "npc" and not bool(target.get("has_main_weapon", false))


func _choose_nearest_enemy_unit_target(targets: Array) -> Dictionary:
	if targets.is_empty():
		return {}
	var ordered: Array[Dictionary] = []
	for raw_target in targets:
		if raw_target is Dictionary:
			ordered.append((raw_target as Dictionary).duplicate(true))
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := float(left.get("distance", INF))
		var right_distance := float(right.get("distance", INF))
		return str(left.get("id", "")) < str(right.get("id", "")) if is_equal_approx(left_distance, right_distance) else left_distance < right_distance
	)
	return ordered[0] if not ordered.is_empty() else {}


func _is_enemy_locked_unit_target_present(enemy_id: String, enemy: Dictionary, target: Dictionary) -> bool:
	if not _is_enemy_unit_target_in_unified_range(enemy, target):
		return false
	return _is_enemy_fixed_target_present(enemy_id, enemy, target)


func _merge_enemy_target_candidate(targets: Array, candidate: Dictionary) -> void:
	var candidate_key := _enemy_attack_target_key(candidate)
	for index in range(targets.size()):
		var current := targets[index] as Dictionary
		if _enemy_attack_target_key(current) != candidate_key:
			continue
		var merged_signals := current.get("retaliation_signals", []) as Array
		for retaliation_signal in candidate.get("retaliation_signals", []):
			if not merged_signals.has(retaliation_signal):
				merged_signals.append(retaliation_signal)
		if not merged_signals.is_empty():
			current["retaliation_signals"] = merged_signals
		targets[index] = current
		return
	targets.append(candidate)


func _mark_enemy_target_choice(enemy: Dictionary, target: Dictionary, previous_target: Dictionary) -> Dictionary:
	var chosen := target.duplicate(true)
	var priority := int(chosen.get("target_priority", _enemy_target_priority(chosen, enemy)))
	chosen["target_priority"] = priority
	chosen["target_selected_frame"] = _formal_crowd_logic_frame
	var previous_key := _enemy_attack_target_key(previous_target)
	var chosen_key := _enemy_attack_target_key(chosen)
	var previous_priority := _enemy_target_priority(previous_target, enemy) if not previous_target.is_empty() else 0
	if previous_key != chosen_key:
		enemy["target_switch_count"] = int(enemy.get("target_switch_count", 0)) + (1 if not previous_key.is_empty() else 0)
		# T0196 locks by target presence in the unified awareness radius, not by a
		# short timer. Keep the legacy snapshot field neutral for save/debug readers.
		enemy["target_lock_until_frame"] = 0
		if not previous_key.is_empty():
			_enemy_targeting_metrics["target_switches"] = int(_enemy_targeting_metrics.get("target_switches", 0)) + 1
			if priority < previous_priority:
				_enemy_targeting_metrics["higher_priority_switches"] = int(_enemy_targeting_metrics.get("higher_priority_switches", 0)) + 1
	enemy["target_priority"] = priority
	enemy["target_selection_reason"] = str(chosen.get("target_selection_reason", "priority_%d" % priority))
	enemy["target_last_evaluated_frame"] = _formal_crowd_logic_frame
	return chosen


func _refresh_current_enemy_target(enemy: Dictionary, current: Dictionary) -> Dictionary:
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	match str(current.get("type", "")):
		"npc":
			var refreshed_npc := _make_npc_enemy_target(str(current.get("id", "")), enemy_position)
			for field in ["target_priority", "target_selection_reason", "retaliation_signals"]:
				if current.has(field):
					refreshed_npc[field] = current[field]
			return refreshed_npc
		"defense_device":
			var refreshed_device := _make_defense_device_enemy_target(str(current.get("id", "")), enemy_position)
			for field in ["target_priority", "target_selection_reason", "retaliation_signals"]:
				if current.has(field):
					refreshed_device[field] = current[field]
			return refreshed_device
		"building":
			var refreshed_building := _make_building_target(str(current.get("id", "")))
			for field in ["target_priority", "target_selection_reason", "obstructed_target_type", "obstructed_target_id"]:
				if current.has(field):
					refreshed_building[field] = current[field]
			return refreshed_building
	return {}


func _select_formal_dynamic_enemy_target(enemy_id: String, enemy: Dictionary) -> Dictionary:
	var measured: bool = _performance_probe != null and _performance_probe.active
	var started := Time.get_ticks_usec() if measured else 0
	_enemy_targeting_metrics["evaluations"] = int(_enemy_targeting_metrics.get("evaluations", 0)) + 1
	var current := enemy.get("target", {}) as Dictionary if enemy.get("target", {}) is Dictionary else {}
	var current_refreshed := _refresh_current_enemy_target(enemy, current)
	if measured:
		_performance_probe.record("target_refresh_ms", Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
	var groups := _collect_enemy_target_priority_groups(enemy_id, enemy)
	if measured:
		_performance_probe.record("target_groups_ms", Time.get_ticks_usec() - started)
	var high_candidates: Array[Dictionary] = []
	for raw_high in groups.get(1, []):
		var high_target := (raw_high as Dictionary).duplicate(true)
		if _is_enemy_fixed_target_present(enemy_id, enemy, high_target):
			high_candidates.append(high_target)
	var unarmed_candidates: Array[Dictionary] = []
	for raw_unarmed in groups.get(2, []):
		unarmed_candidates.append((raw_unarmed as Dictionary).duplicate(true))

	# T0197/T0199 provide a one-shot exception to the presence lock. Confirmed HP
	# loss from a different armed NPC / defense device creates this request both
	# for high-threat locks and for lower-priority building / unarmed-NPC targets.
	# Consume it before the normal hold branch, then restore the presence lock
	# around whichever in-range, available high threat is nearest now.
	if _enemy_high_threat_reacquire_requests.has(enemy_id):
		var damage_reacquire_request := (
			_enemy_high_threat_reacquire_requests.get(enemy_id, {}) as Dictionary
		).duplicate(true)
		_enemy_high_threat_reacquire_requests.erase(enemy_id)
		if not high_candidates.is_empty():
			var damage_reacquire_target := _choose_nearest_enemy_unit_target(high_candidates)
			damage_reacquire_target["target_priority"] = 1
			damage_reacquire_target["target_selection_reason"] = "different_attacker_damage_nearest_high_threat_reacquire"
			damage_reacquire_target["damage_reacquire_source_type"] = str(damage_reacquire_request.get("source_type", ""))
			damage_reacquire_target["damage_reacquire_source_id"] = str(damage_reacquire_request.get("source_id", ""))
			damage_reacquire_target["damage_reacquire_sequence"] = int(damage_reacquire_request.get("sequence", 0))
			_enemy_targeting_metrics["different_attacker_damage_reacquisitions"] = int(
				_enemy_targeting_metrics.get("different_attacker_damage_reacquisitions", 0)
			) + 1
			return _mark_enemy_target_choice(enemy, damage_reacquire_target, current_refreshed)
		_enemy_targeting_metrics["different_attacker_damage_no_candidate_consumptions"] = int(
			_enemy_targeting_metrics.get("different_attacker_damage_no_candidate_consumptions", 0)
		) + 1

	# A locked combat unit or defense device owns the decision until it leaves the
	# one shared awareness radius, becomes invalid, or (for fixed targets only)
	# has no compatible free attack position. New or nearer peers do not steal it.
	if _is_enemy_high_threat_target(current_refreshed) and _is_enemy_locked_unit_target_present(enemy_id, enemy, current_refreshed):
		current_refreshed["target_priority"] = 1
		current_refreshed["target_selection_reason"] = "locked_high_threat_present"
		enemy["target_last_evaluated_frame"] = _formal_crowd_logic_frame
		_enemy_targeting_metrics["locked_high_target_holds"] = int(_enemy_targeting_metrics.get("locked_high_target_holds", 0)) + 1
		return current_refreshed

	if not high_candidates.is_empty():
		var nearest_high := _choose_nearest_enemy_unit_target(high_candidates)
		nearest_high["target_priority"] = 1
		nearest_high["target_selection_reason"] = "nearest_high_threat_in_unified_range"
		if _is_enemy_unarmed_npc_target(current_refreshed) or str(current_refreshed.get("type", "")) == "building":
			_enemy_targeting_metrics["high_threat_preemptions"] = int(_enemy_targeting_metrics.get("high_threat_preemptions", 0)) + 1
		return _mark_enemy_target_choice(enemy, nearest_high, current_refreshed)

	# Noncombat NPCs are sticky only while no combat unit or defense device is
	# available. They never use fixed leases and therefore cannot become "full".
	if _is_enemy_unarmed_npc_target(current_refreshed) and _is_enemy_locked_unit_target_present(enemy_id, enemy, current_refreshed):
		current_refreshed["target_priority"] = 2
		current_refreshed["target_selection_reason"] = "locked_unarmed_npc_no_high_threat"
		enemy["target_last_evaluated_frame"] = _formal_crowd_logic_frame
		_enemy_targeting_metrics["locked_unarmed_target_holds"] = int(_enemy_targeting_metrics.get("locked_unarmed_target_holds", 0)) + 1
		return current_refreshed

	if not unarmed_candidates.is_empty():
		var nearest_unarmed := _choose_nearest_enemy_unit_target(unarmed_candidates)
		nearest_unarmed["target_priority"] = 2
		nearest_unarmed["target_selection_reason"] = "nearest_unarmed_npc_without_high_threat"
		return _mark_enemy_target_choice(enemy, nearest_unarmed, current_refreshed)

	# Buildings are the strategic fallback and are not limited by awareness range.
	# Fixed positions still apply. A full warehouse or main hall is absent for this
	# enemy, while the mandatory front gate remains selected and enters its waiter.
	for building_priority in range(3, 6):
		for raw_building in groups.get(building_priority, []):
			var building := (raw_building as Dictionary).duplicate(true)
			if not _is_enemy_fixed_target_present(enemy_id, enemy, building):
				continue
			building["target_priority"] = building_priority
			building["target_selection_reason"] = "strategic_building_sequence"
			_enemy_targeting_metrics["building_fallbacks"] = int(_enemy_targeting_metrics.get("building_fallbacks", 0)) + 1
			return _mark_enemy_target_choice(enemy, building, current_refreshed)

	return {}


func _ensure_formal_dynamic_pressure_motion(enemy_id: String, target: Dictionary) -> void:
	if not _formal_first_wave_slices.has(enemy_id):
		return
	var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	if actor == null:
		return
	var slice: Dictionary = _formal_first_wave_slices[enemy_id]
	_set_formal_enemy_tactical_motion_paused(enemy_id, false)
	var target_id := str(target.get("id", ""))
	var target_type := str(target.get("type", ""))
	var target_position: Vector3 = _get_enemy_attack_motion_position(target, actor.global_position)
	target_position.y = actor.global_position.y
	var navigation_map := actor.get_navigation_map()
	if navigation_map.is_valid():
		target_position = NavigationServer3D.map_get_closest_point(navigation_map, target_position)
	var previous_target_id := str(slice.get("combat_target_id", ""))
	var previous_target_type := str(slice.get("combat_target_type", ""))
	var previous_position: Vector3 = slice.get("motion_target_position", Vector3.INF)
	var target_changed := previous_target_id != target_id or previous_target_type != target_type
	var target_update_distance := (
		0.01
		if _uses_enemy_attack_guidance(enemy_id, target)
		else maxf(0.05, float(_combat_navigation_policy.get("target_update_distance", 0.35)))
	)
	var target_moved := previous_position == Vector3.INF or previous_position.distance_to(target_position) > target_update_distance
	var request_kind := "unit" if target_type in ["npc", "defense_device"] else "building"
	var motion_options := _get_combat_motion_options("enemy_%s_approach" % request_kind)
	motion_options["target_desired_distance"] = _get_enemy_attack_position_arrival_tolerance(enemy_id, target)
	if target_type == "npc":
		# The target position is refreshed while the NPC moves. The combat range
		# check above owns stopping; generic fixed-point braking would otherwise
		# restart on every refresh and create a saw-tooth chase speed.
		motion_options["final_target_braking_enabled"] = false
	if actor.is_motion_active() and not target_changed:
		if actor.has_method("update_motion_target"):
			var motion_updated := actor.update_motion_target(
				target_position,
				"combat_target_moved" if target_moved else "combat_target_contract_refreshed",
				motion_options
			)
			if motion_updated or target_moved:
				slice["motion_target_position"] = target_position
				slice["pressure_repath_count"] = int(slice.get("pressure_repath_count", 0)) + (1 if target_moved else 0)
				_formal_first_wave_slices[enemy_id] = slice
		return
	if actor.request_motion(
		target_position,
		"formal_wave_pressure_%s:%s:%s" % [request_kind, enemy_id, target_id],
		motion_options
	):
		slice["combat_target_id"] = target_id
		slice["combat_target_type"] = target_type
		slice["motion_target_position"] = target_position
		slice["phase"] = "pressing_to_unit" if request_kind == "unit" else "marching_to_%s" % target_id
		slice["pressure_repath_count"] = int(slice.get("pressure_repath_count", 0)) + 1
		slice["failure_reason"] = ""
		_formal_first_wave_slices[enemy_id] = slice
		_set_formal_enemy_tactical_motion_paused(enemy_id, false)


func _get_combat_motion_options(purpose: String) -> Dictionary:
	return {
		"movement_purpose": purpose,
		"persistent_repath": bool(_combat_navigation_policy.get("persistent_repath", true)),
		"target_update_distance": maxf(0.05, float(_combat_navigation_policy.get("target_update_distance", 0.35))),
		# A target-identity handoff is a combat decision, not a physical stop. Enemy
		# approaches often replace an active NPC/building/device request while the
		# next destination remains ahead on the same route. Carry the bounded planar
		# velocity into that replacement; ActorMotionBody still applies acceleration,
		# path-direction rejection, RVO, collision and final-target braking next tick.
		"preserve_velocity_on_supersede": purpose.begins_with("enemy_"),
		# Fixed-target guidance can legitimately replace the request when density or
		# target identity changes. Preserve physical immobility evidence across that
		# replacement so repeated tactical decisions cannot postpone unstick forever.
		"preserve_stationary_progress_on_supersede": purpose.begins_with("enemy_")
	}


func _get_friendly_ranged_attack_position_arrival_tolerance() -> float:
	return clampf(
		float(
			_combat_navigation_policy.get(
				"friendly_ranged_attack_position_arrival_tolerance",
				RANGED_ATTACK_POSITION_ARRIVAL_TOLERANCE_FALLBACK
			)
		),
		0.01,
		0.25
	)


func _get_friendly_strategy_stalled_reselect_seconds() -> float:
	return maxf(
		0.75,
		float(
			_combat_navigation_policy.get(
				"friendly_strategy_stalled_reselect_seconds",
				FRIENDLY_STRATEGY_STALLED_RESELECT_SECONDS_FALLBACK
			)
		)
	)


func _get_friendly_strategy_reselect_min_separation() -> float:
	return maxf(
		0.2,
		float(
			_combat_navigation_policy.get(
				"friendly_strategy_reselect_min_separation",
				FRIENDLY_STRATEGY_RESELECT_MIN_SEPARATION_FALLBACK
			)
		)
	)


func _pause_formal_dynamic_pressure_motion(enemy_id: String) -> void:
	_set_formal_enemy_tactical_motion_paused(enemy_id, true)


func _mark_formal_dynamic_contact(enemy_id: String, target: Dictionary) -> void:
	if not _formal_first_wave_slices.has(enemy_id):
		return
	var slice: Dictionary = _formal_first_wave_slices[enemy_id]
	var target_id := str(target.get("id", ""))
	var target_type := str(target.get("type", ""))
	slice["attack_unlocked"] = true
	slice["combat_target_id"] = target_id
	slice["combat_target_type"] = target_type
	slice["attack_target_building_id"] = target_id if target_type == "building" else ""
	slice["phase"] = "attacking_%s" % target_id if target_type == "building" else "engaging_unit"
	_formal_first_wave_slices[enemy_id] = slice


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
	var detection_range := maxf(DEFAULT_NEARBY_UNIT_DETECTION_RANGE, float(enemy.get("attack_range", 1.5)))
	var nearest_target := {}
	var nearest_distance := INF
	if (
		npc_system != null
		and npc_system.has_method("get_npc_ids")
		and npc_system.has_method("get_npc_world_position")
	):
		for npc_id in npc_system.get_npc_ids():
			if (
				_default_formal_wave_active
				and npc_system.has_method("is_npc_in_formal_combat_world")
				and not npc_system.is_npc_in_formal_combat_world(npc_id)
			):
				continue
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
				"contact_radius": 0.35,
				"distance": distance
			}
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system != null and device_system.has_method("get_active_defense_targets"):
		for raw_target in device_system.get_active_defense_targets():
			if not raw_target is Dictionary:
				continue
			var device_target: Dictionary = raw_target
			var device_position: Vector3 = device_target.get("position", enemy_position)
			var device_offset := device_position - enemy_position
			device_offset.y = 0.0
			var distance := device_offset.length()
			if distance > detection_range or distance >= nearest_distance:
				continue
			nearest_distance = distance
			nearest_target = device_target.duplicate(true)
			nearest_target["distance"] = distance
	return nearest_target


func _make_building_target(building_id: String) -> Dictionary:
	if not ENEMY_BUILDING_TARGET_IDS.has(building_id):
		return {}
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		return {}
	var building: Dictionary = (
		building_system.get_building_combat_snapshot(building_id)
		if building_system.has_method("get_building_combat_snapshot")
		else building_system.get_building(building_id)
	)
	if building.is_empty() or int(building.get("hp", 0)) <= 0:
		return {}
	var raw_position: Variant = null
	if building_system.has_method("get_building_entry_position"):
		raw_position = building_system.get_building_entry_position(building_id)
	if raw_position == null:
		return {}
	var result := {
		"type": "building",
		"id": building_id,
		"name": str(building.get("name", building_id)),
		"position": raw_position,
		"route_approach_position": raw_position,
		"distance": 0.0
	}
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("get_building_combat_geometry"):
		var geometry: Dictionary = controller.get_building_combat_geometry(building_id)
		if not geometry.is_empty():
			var center: Vector3 = geometry.get("center", raw_position)
			var size: Vector2 = geometry.get("size", Vector2.ZERO)
			var right_direction: Vector3 = geometry.get("right_direction", Vector3.RIGHT)
			var forward_direction: Vector3 = geometry.get("forward_direction", Vector3.FORWARD)
			result["position"] = center
			result["building_geometry_schema"] = str(geometry.get("schema", ""))
			result["building_footprint_size"] = {"x": size.x, "z": size.y}
			result["building_right_direction"] = right_direction
			result["building_forward_direction"] = forward_direction
			result["building_front_door_clear_width"] = float(geometry.get("front_door_clear_width", 0.0))
			if str(geometry.get("schema", "")) == "gate_combat_geometry_v1":
				# Gate attacks face the rotated visible/collision gatehouse itself.
				# Route approach points are staging data and may sit off its normal.
				result["facing_direction"] = forward_direction
			else:
				var outward := (raw_position as Vector3) - center
				outward.y = 0.0
				if outward.length_squared() > 0.0001:
					result["facing_direction"] = outward.normalized()
	return result


func _advance_enemy_attack(
	enemy: Dictionary,
	target: Dictionary,
	combat_delta_seconds: float,
	timeline_end_seconds: float = -1.0
) -> Dictionary:
	var remaining := maxf(0.0, combat_delta_seconds)
	var cadence_guard_enabled := timeline_end_seconds >= 0.0
	var timeline_cursor := maxf(0.0, timeline_end_seconds - remaining) if cadence_guard_enabled else 0.0
	var next_sequence_time := maxf(0.0, float(enemy.get("attack_next_sequence_time", 0.0)))
	var interval := maxf(0.1, float(enemy.get("attack_interval", 1.8)))
	var enemy_mounted := str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"]
	var timing := COMBAT_ANIMATION_TIMING.get_timing(str(enemy.get("weapon_type", "sword_shield")), interval, enemy_mounted)
	var phase := str(enemy.get("attack_cycle_phase", "idle"))
	if not phase in ["windup", "recovery"]:
		phase = "idle"
	var elapsed := maxf(0.0, float(enemy.get("attack_cycle_elapsed", 0.0)))
	var cycle_seconds := maxf(0.1, float(enemy.get("attack_cycle_duration", timing.get("cycle_seconds", interval))))
	var impact_seconds := clampf(
		float(enemy.get("attack_impact_seconds", timing.get("impact_seconds", cycle_seconds * 0.5))),
		0.0,
		cycle_seconds
	)
	var cycle_target: Dictionary = enemy.get("attack_cycle_target", {}) if enemy.get("attack_cycle_target", {}) is Dictionary else {}
	var impact_committed := bool(enemy.get("attack_impact_committed", phase == "recovery"))
	var sequence := maxi(0, int(enemy.get("attack_sequence", 0)))
	var completing_locked_actor_melee := (
		phase in ["windup", "recovery"]
		and str(enemy.get("weapon_type", "")) in MELEE_WEAPON_TYPES
		and str(cycle_target.get("type", "")) == "npc"
	)
	var completing_locked_projectile_action := (
		phase in ["windup", "recovery"]
		and _is_ranged_weapon_type(str(enemy.get("weapon_type", "")))
		and str(cycle_target.get("type", "")) == "npc"
	)
	if completing_locked_actor_melee or completing_locked_projectile_action:
		var locked_npc_target := _make_npc_enemy_target(
			str(cycle_target.get("id", "")),
			enemy.get("position", Vector3.ZERO)
		)
		if not locked_npc_target.is_empty():
			target = locked_npc_target
	var current_target_id := str(target.get("id", ""))
	if phase != "idle" and str(cycle_target.get("id", "")) != current_target_id:
		phase = "idle"
		elapsed = 0.0
		cycle_target = {}
		impact_committed = false
	var attacks: Array[Dictionary] = []
	while remaining > 0.000001 and attacks.size() < MAX_ATTACKS_PER_AI_STEP:
		if phase == "idle":
			if cadence_guard_enabled and sequence > 0 and timeline_cursor + 0.000001 < next_sequence_time:
				var cadence_wait := minf(remaining, next_sequence_time - timeline_cursor)
				remaining -= cadence_wait
				timeline_cursor += cadence_wait
				if remaining <= 0.000001 or timeline_cursor + 0.000001 < next_sequence_time:
					break
			timing = COMBAT_ANIMATION_TIMING.get_timing(str(enemy.get("weapon_type", "sword_shield")), interval, enemy_mounted)
			cycle_seconds = float(timing.get("cycle_seconds", interval))
			impact_seconds = float(timing.get("impact_seconds", cycle_seconds * 0.5))
			phase = "windup"
			elapsed = 0.0
			cycle_target = target.duplicate(true)
			impact_committed = false
			sequence += 1
			if cadence_guard_enabled:
				enemy["attack_last_sequence_time"] = timeline_cursor
				next_sequence_time = timeline_cursor + cycle_seconds
			if str(enemy.get("weapon_type", "")) in MELEE_WEAPON_TYPES:
				_begin_melee_swing(
					"enemy",
					str(enemy.get("id", "")),
					str(enemy.get("weapon_type", "")),
					target,
					sequence
				)
		var boundary := impact_seconds if phase == "windup" else cycle_seconds
		var until_boundary := maxf(0.0, boundary - elapsed)
		var phase_step := minf(remaining, until_boundary)
		elapsed += phase_step
		remaining -= phase_step
		if cadence_guard_enabled:
			timeline_cursor += phase_step
		if elapsed + 0.000001 < boundary:
			break
		if phase == "windup":
			enemy["attack_sequence"] = sequence
			var single_attack := _apply_enemy_attack(enemy, target)
			if single_attack.is_empty():
				phase = "idle"
				elapsed = 0.0
				cycle_target = {}
				impact_committed = false
				break
			single_attack["attack_sequence"] = sequence
			single_attack["impact_seconds"] = impact_seconds
			single_attack["cycle_seconds"] = cycle_seconds
			attacks.append(single_attack)
			impact_committed = true
			phase = "recovery"
			if _is_target_defeated(target):
				break
		else:
			phase = "idle"
			elapsed = 0.0
			cycle_target = {}
			impact_committed = false

	var cooldown := maxf(0.0, cycle_seconds - elapsed) if phase != "idle" else 0.0
	var windup_remaining := maxf(0.0, impact_seconds - elapsed) if phase == "windup" else 0.0
	var windup_target := cycle_target.duplicate(true) if phase == "windup" else {}
	enemy["attack_cooldown"] = cooldown
	enemy["attack_windup_remaining"] = windup_remaining
	enemy["attack_windup_target"] = windup_target
	enemy["attack_cycle_phase"] = phase
	enemy["attack_cycle_elapsed"] = elapsed
	enemy["attack_cycle_duration"] = cycle_seconds
	enemy["attack_impact_seconds"] = impact_seconds
	enemy["attack_cycle_target"] = cycle_target
	enemy["attack_impact_committed"] = impact_committed
	enemy["attack_sequence"] = sequence
	enemy["attack_next_sequence_time"] = next_sequence_time
	enemy["attack_playback_multiplier"] = float(timing.get("playback_multiplier", 1.0))
	if phase == "windup":
		enemy["current_action"] = "winding_up_%s" % current_target_id
	elif phase == "recovery":
		enemy["current_action"] = "attacking_%s" % current_target_id
	else:
		enemy["current_action"] = "combat_ready"
	var result := {
		"enemy_id": str(enemy.get("id", "")),
		"target": _serialize_target(target),
		"combat_seconds": combat_delta_seconds,
		"attack_count": attacks.size(),
		"attack_sequence": sequence,
		"attack_phase": phase,
		"attack_elapsed_seconds": elapsed,
		"attack_cycle_seconds": cycle_seconds,
		"attack_impact_seconds": impact_seconds,
		"attack_playback_multiplier": float(timing.get("playback_multiplier", 1.0)),
		"attack_next_sequence_time": next_sequence_time,
		"windup_remaining": windup_remaining,
		"windup_target": windup_target.duplicate(true),
		"attacks": attacks
	}
	enemy["last_attack_result"] = result.duplicate(true)
	return result


func _cancel_enemy_attack_timeline(enemy: Dictionary) -> void:
	var swing_key := _melee_swing_key("enemy", str(enemy.get("id", "")))
	_active_melee_swings.erase(swing_key)
	_pending_melee_damage_commits.erase(swing_key)
	enemy["attack_cooldown"] = 0.0
	enemy["attack_windup_remaining"] = 0.0
	enemy["attack_windup_target"] = {}
	enemy["attack_cycle_phase"] = "idle"
	enemy["attack_cycle_elapsed"] = 0.0
	enemy["attack_cycle_duration"] = 0.0
	enemy["attack_impact_seconds"] = 0.0
	enemy["attack_cycle_target"] = {}
	enemy["attack_impact_committed"] = false


func _interrupt_enemy_attack_from_damage(
	enemy: Dictionary,
	damage: int,
	context: Dictionary = {}
) -> Dictionary:
	if damage <= 0 or enemy.is_empty():
		return {}
	if not str(enemy.get("weapon_type", "")) in MELEE_WEAPON_TYPES + RANGED_WEAPON_TYPES:
		return {}
	var phase := str(enemy.get("attack_cycle_phase", "idle"))
	if not phase in ["windup", "recovery"]:
		return {}
	var elapsed := maxf(0.0, float(enemy.get("attack_cycle_elapsed", 0.0)))
	var impact_seconds := maxf(0.0, float(enemy.get("attack_impact_seconds", 0.0)))
	var impact_committed := bool(enemy.get("attack_impact_committed", phase == "recovery"))
	var before_impact := phase == "windup" and not impact_committed and elapsed + 0.000001 < impact_seconds
	var result := {
		"ok": true,
		"attacker_side": "enemy",
		"attacker_id": str(enemy.get("id", "")),
		"phase_before": phase,
		"elapsed_before": elapsed,
		"impact_seconds": impact_seconds,
		"impact_committed_before": impact_committed,
		"interrupted_before_impact": before_impact,
		"damage": damage,
		"source_type": str(context.get("source_type", "")),
		"source_id": str(context.get("source_id", ""))
	}
	_cancel_enemy_attack_timeline(enemy)
	enemy["current_action"] = "combat_ready"
	enemy["damage_attack_interrupt_count"] = int(enemy.get("damage_attack_interrupt_count", 0)) + 1
	if before_impact:
		enemy["damage_windup_interrupt_count"] = int(enemy.get("damage_windup_interrupt_count", 0)) + 1
	enemy["last_damage_attack_interrupt"] = result.duplicate(true)
	return result


func _interrupt_npc_attack_from_damage(
	npc_id: String,
	damage: int,
	context: Dictionary = {}
) -> Dictionary:
	if npc_id.is_empty() or damage <= 0:
		return {}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system == null
		or not npc_system.has_method("get_npc")
		or not npc_system.has_method("get_npc_state")
		or not npc_system.has_method("update_npc_state")
	):
		return {}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	var main_weapon := _get_npc_main_weapon(npc)
	if not str(main_weapon.get("id", main_weapon.get("type", ""))) in MELEE_WEAPON_TYPES + RANGED_WEAPON_TYPES:
		return {}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var phase := str(state.get("combat_attack_phase", "idle"))
	if not phase in ["windup", "recovery"]:
		return {}
	var elapsed := maxf(0.0, float(state.get("combat_attack_elapsed_seconds", 0.0)))
	var impact_seconds := maxf(0.0, float(state.get("combat_attack_impact_seconds", 0.0)))
	var impact_committed := bool(state.get("combat_attack_impact_committed", phase == "recovery"))
	var before_impact := phase == "windup" and not impact_committed and elapsed + 0.000001 < impact_seconds
	var result := {
		"ok": true,
		"attacker_side": "friendly",
		"attacker_id": npc_id,
		"phase_before": phase,
		"elapsed_before": elapsed,
		"impact_seconds": impact_seconds,
		"impact_committed_before": impact_committed,
		"interrupted_before_impact": before_impact,
		"damage": damage,
		"source_id": str(context.get("source_id", "")),
		"damage_event": context.get("damage_event", {}).duplicate(true) if context.get("damage_event", {}) is Dictionary else {}
	}
	var swing_key := _melee_swing_key("friendly", npc_id)
	_active_melee_swings.erase(swing_key)
	_pending_melee_damage_commits.erase(swing_key)
	var current_action := "unconscious" if bool(state.get("unconscious", false)) else "combat_ready"
	npc_system.update_npc_state(npc_id, {
		"combat_attack_phase": "idle",
		"combat_attack_elapsed_seconds": 0.0,
		"combat_attack_cycle_seconds": 0.0,
		"combat_attack_impact_seconds": 0.0,
		"combat_attack_target_enemy_id": "",
		"combat_attack_impact_committed": false,
		"combat_last_attack_result": {},
		"current_action": current_action,
		"last_action_result": "combat_attack_interrupted_by_damage",
		"combat_damage_attack_interrupt_count": int(state.get("combat_damage_attack_interrupt_count", 0)) + 1,
		"combat_damage_windup_interrupt_count": int(state.get("combat_damage_windup_interrupt_count", 0)) + (1 if before_impact else 0),
		"combat_last_damage_attack_interrupt": result.duplicate(true)
	})
	return result


func _apply_enemy_attack(enemy: Dictionary, target: Dictionary) -> Dictionary:
	var target_type := str(target.get("type", ""))
	var target_id := str(target.get("id", ""))
	if target_id.is_empty():
		return {}
	if _is_ranged_weapon_type(str(enemy.get("weapon_type", ""))):
		return _release_enemy_projectile(enemy, target)
	if str(enemy.get("weapon_type", "")) in MELEE_WEAPON_TYPES:
		if target_type == "npc":
			return _resolve_enemy_locked_actor_melee_impact(enemy, target)
		return _resolve_enemy_melee_contact(enemy, target)
	var raw_attack_power := maxf(1.0, float(enemy.get("attack_power", 1.0)))
	var penetration := maxf(0.0, float(enemy.get("penetration", 0.0)))
	match target_type:
		"npc":
			var target_defense := _calculate_npc_defense(target_id)
			var resolution := calculate_damage_resolution(raw_attack_power, target_defense, penetration)
			return _apply_enemy_attack_to_npc(
				enemy,
				target_id,
				int(resolution.get("damage", 1)),
				raw_attack_power,
				target_defense,
				penetration,
				float(resolution.get("effective_defense", target_defense))
			)
		"defense_device":
			var device_defense := maxf(0.0, float(target.get("defense", 0.0)))
			var resolution := calculate_damage_resolution(raw_attack_power, device_defense, penetration)
			return _apply_enemy_attack_to_defense_device(
				enemy,
				target_id,
				int(resolution.get("damage", 1)),
				resolution
			)
		"building":
			return _apply_enemy_attack_to_building(
				enemy,
				target_id,
				maxi(1, int(round(raw_attack_power))),
				{"hit_world_position": target.get("attack_contact_position", null)}
			)
		_:
			return {}


func _apply_enemy_attack_to_npc(
	enemy: Dictionary,
	npc_id: String,
	damage: int,
	raw_attack_power: float,
	target_defense: float,
	penetration: float,
	effective_defense: float
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
	var friendly_target_before_damage := ""
	if npc_system.has_method("get_npc_state"):
		friendly_target_before_damage = str(
			(npc_system.get_npc_state(npc_id) as Dictionary).get("combat_target_enemy_id", "")
		)
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	var mounted_split := {
		"split": false,
		"incoming_damage": damage,
		"npc_damage": damage,
		"horse_damage": 0,
		"share_ratio": 0.0,
		"horse_result": {}
	}
	if horse_system != null and horse_system.has_method("split_mounted_damage"):
		mounted_split = horse_system.split_mounted_damage(npc_id, damage, {
			"actor_id": enemy_id,
			"enemy_id": enemy_id,
			"enemy_name": enemy_name,
			"raw_attack_power": raw_attack_power,
			"target_defense": target_defense,
			"penetration": penetration,
			"effective_defense": effective_defense
		})
	var npc_damage := maxi(0, int(mounted_split.get("npc_damage", damage)))
	var damage_result := {}
	if npc_damage > 0:
		damage_result = npc_system.apply_damage_to_npc(
			npc_id,
			npc_damage,
			enemy_id,
			ENEMY_DAMAGE_VISIBILITY,
			{
				"summary": "%s攻击了%s，人物承受%d点伤害。" % [enemy_name, npc_name, npc_damage],
				"request_plan_reevaluation": false,
				"enemy_attack": true,
				"enemy_id": enemy_id,
				"enemy_name": enemy_name,
				"raw_attack_power": raw_attack_power,
				"target_defense": target_defense,
				"penetration": penetration,
				"effective_defense": effective_defense,
				"damage_after_defense": npc_damage,
				"combined_damage_after_defense": damage,
				"horse_damage": int(mounted_split.get("horse_damage", 0)),
				"horse_damage_share_ratio": float(mounted_split.get("share_ratio", 0.0))
			}
		)
	# NPCSystem also reports damage back on a deferred low-HP hook. Interrupt the
	# active attack synchronously here so this same combat step cannot advance a
	# pre-impact swing after its owner has already been hit. The deferred call is
	# intentionally idempotent because the phase is idle by then.
	if damage > 0:
		_interrupt_npc_attack_from_damage(npc_id, damage, {
			"source_id": enemy_id,
			"damage_event": damage_result.get("damage_event", {}).duplicate(true) if damage_result.get("damage_event", {}) is Dictionary else {}
		})
	if not damage_result.is_empty() and npc_damage > 0:
		_record_battle_npc_damage(npc_id, npc_name, enemy, damage_result)
		_record_friendly_enemy_damage_reacquire_request(
			npc_id,
			friendly_target_before_damage,
			enemy_id,
			damage_result
		)
	return {
		"target_type": "npc",
		"target_id": npc_id,
		"raw_attack_power": raw_attack_power,
		"target_defense": target_defense,
		"penetration": penetration,
		"effective_defense": effective_defense,
		"damage": damage,
		"npc_damage": npc_damage,
		"horse_damage": int(mounted_split.get("horse_damage", 0)),
		"horse_damage_share_ratio": float(mounted_split.get("share_ratio", 0.0)),
		"mounted_damage_split": mounted_split,
		"result": damage_result
	}


func _apply_enemy_attack_to_defense_device(
	enemy: Dictionary,
	deployment_id: String,
	damage: int,
	resolution: Dictionary,
	proxy_context: Dictionary = {}
) -> Dictionary:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("apply_damage_to_device"):
		return {}
	var result: Dictionary = device_system.apply_damage_to_device(
		deployment_id,
		damage,
		{
			"attacker_id": str(enemy.get("id", "")),
			"attacker_name": str(enemy.get("name", "敌人")),
			"attack_id": str(proxy_context.get("attack_id", "")),
			"host_proxy_id": str(proxy_context.get("host_proxy_id", "")),
			"collision_identity": proxy_context.get("collision_identity", {}).duplicate(true) if proxy_context.get("collision_identity", {}) is Dictionary else {},
			"hit_world_position": proxy_context.get("hit_world_position", null)
		}
	)
	if result.is_empty():
		return {}
	return {
		"target_type": "defense_device",
		"target_id": deployment_id,
		"raw_attack_power": float(resolution.get("raw_attack_power", damage)),
		"target_defense": float(resolution.get("target_defense", 0.0)),
		"penetration": float(resolution.get("penetration", 0.0)),
		"effective_defense": float(resolution.get("effective_defense", 0.0)),
		"host_proxy_id": str(proxy_context.get("host_proxy_id", "")),
		"damage": damage,
		"result": result
	}


func _apply_enemy_attack_to_building(
	enemy: Dictionary,
	building_id: String,
	damage: int,
	feedback_context: Dictionary = {}
) -> Dictionary:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("apply_damage_to_building"):
		return {}
	var enemy_id := str(enemy.get("id", ""))
	var enemy_name := str(enemy.get("name", enemy_id))
	var damage_options := feedback_context.duplicate(true)
	damage_options["attacker_name"] = enemy_name
	var damage_result: Dictionary = building_system.apply_damage_to_building(
		building_id,
		damage,
		enemy_id,
		ENEMY_DAMAGE_VISIBILITY,
		damage_options
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


func _evaluate_five_wave_victory(battle_end_result: Dictionary, trigger_reason: String) -> Dictionary:
	if not _last_victory_result.is_empty():
		return {
			"ok": true,
			"triggered": false,
			"reason": "victory_already_recorded",
			"last_victory_result": _last_victory_result.duplicate(true)
		}
	if not _last_failure_result.is_empty():
		return {"ok": true, "triggered": false, "reason": "failure_already_recorded"}
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and bool(game_state.get("game_over")):
		return {"ok": true, "triggered": false, "reason": "game_already_over"}
	if battle_end_result.is_empty() or str(battle_end_result.get("error", "")) == "no_active_battle":
		return {"ok": true, "triggered": false, "reason": "no_finished_battle", "battle_end_result": battle_end_result.duplicate(true)}
	if int(battle_end_result.get("remaining_enemy_count", 0)) > 0:
		return {"ok": true, "triggered": false, "reason": "enemies_remaining", "battle_end_result": battle_end_result.duplicate(true)}
	var final_wave_number := _get_final_wave_number()
	if final_wave_number <= 0:
		return {"ok": true, "triggered": false, "reason": "no_configured_waves"}
	if not _battle_result_includes_wave(battle_end_result, final_wave_number):
		return {
			"ok": true,
			"triggered": false,
			"reason": "final_wave_not_cleared",
			"final_wave_number": final_wave_number,
			"battle_end_result": battle_end_result.duplicate(true)
		}
	_trigger_five_wave_victory(final_wave_number, battle_end_result, trigger_reason)
	return {
		"ok": true,
		"triggered": true,
		"reason": VICTORY_REASON_FIVE_WAVES_SURVIVED,
		"victory_result": _last_victory_result.duplicate(true)
	}


func _trigger_five_wave_victory(final_wave_number: int, battle_end_result: Dictionary, trigger_reason: String) -> void:
	if not _last_victory_result.is_empty():
		return
	var settlement_snapshot := _build_victory_settlement_snapshot(final_wave_number, battle_end_result, trigger_reason)
	_last_victory_result = {
		"ok": true,
		"result": "victory",
		"reason": VICTORY_REASON_FIVE_WAVES_SURVIVED,
		"wave_number": final_wave_number,
		"trigger_reason": trigger_reason,
		"battle_end_result": battle_end_result.duplicate(true),
		"settlement_snapshot": settlement_snapshot.duplicate(true)
	}
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("set_game_over"):
		game_state.set_game_over("victory", VICTORY_REASON_FIVE_WAVES_SURVIVED, settlement_snapshot)


func _build_victory_settlement_snapshot(final_wave_number: int, battle_end_result: Dictionary, trigger_reason: String) -> Dictionary:
	var resource_snapshot := _build_resource_settlement_snapshot()
	var building_snapshot := _build_building_settlement_snapshot()
	var npc_snapshot := _build_npc_settlement_snapshot()
	var time_snapshot := _get_game_time_snapshot()
	return {
		"result": "victory",
		"reason": VICTORY_REASON_FIVE_WAVES_SURVIVED,
		"wave_number": final_wave_number,
		"trigger_reason": trigger_reason,
		"day": int(time_snapshot.get("day", 1)),
		"time": str(time_snapshot.get("time", "00:00:00")),
		"resources": resource_snapshot,
		"buildings": building_snapshot,
		"npcs": npc_snapshot,
		"station_operational": bool(building_snapshot.get("station_operational", false)),
		"battle_end_result": battle_end_result.duplicate(true)
	}


func _get_final_wave_number() -> int:
	var final_wave_number := 0
	for wave in _waves:
		final_wave_number = maxi(final_wave_number, int(wave.get("wave_number", 0)))
	return final_wave_number


func _battle_result_includes_wave(battle_end_result: Dictionary, wave_number: int) -> bool:
	if wave_number <= 0:
		return false
	if int(battle_end_result.get("wave_number", 0)) == wave_number:
		return true
	var additional_waves: Array = battle_end_result.get("additional_waves", []) if battle_end_result.get("additional_waves", []) is Array else []
	for raw_wave in additional_waves:
		var wave: Dictionary = raw_wave if raw_wave is Dictionary else {}
		if int(wave.get("wave_number", 0)) == wave_number:
			return true
	return false


func _build_resource_settlement_snapshot() -> Dictionary:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	if resource_system == null or not resource_system.has_method("get_resource_ids"):
		return {"items": [], "amounts": {}}
	var items: Array[Dictionary] = []
	var amounts := {}
	for raw_resource_id in resource_system.get_resource_ids():
		var resource_id := str(raw_resource_id)
		var amount := int(resource_system.get_resource(resource_id)) if resource_system.has_method("get_resource") else 0
		var name := resource_id
		if resource_system.has_method("get_resource_name"):
			name = str(resource_system.get_resource_name(resource_id))
		items.append({
			"id": resource_id,
			"name": name,
			"amount": amount
		})
		amounts[resource_id] = amount
	return {"items": items, "amounts": amounts}


func _build_building_settlement_snapshot() -> Dictionary:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var buildings: Array[Dictionary] = []
	var damaged: Array[Dictionary] = []
	var destroyed: Array[Dictionary] = []
	var station_operational := false
	if building_system == null or not building_system.has_method("get_building_ids") or not building_system.has_method("get_building"):
		return {
			"items": buildings,
			"damaged_buildings": damaged,
			"destroyed_buildings": destroyed,
			"station_operational": station_operational
		}
	for raw_building_id in building_system.get_building_ids():
		var building_id := str(raw_building_id)
		var building: Dictionary = building_system.get_building(building_id)
		if building.is_empty():
			continue
		var hp := int(building.get("hp", 0))
		var max_hp := int(building.get("max_hp", hp))
		var entry := {
			"id": building_id,
			"name": str(building.get("name", building_id)),
			"level": int(building.get("level", 1)),
			"hp": hp,
			"max_hp": max_hp,
			"condition": str(building.get("condition", "")),
			"destroyed": hp <= 0,
			"damaged": hp < max_hp
		}
		buildings.append(entry)
		if bool(entry["destroyed"]):
			destroyed.append(entry.duplicate(true))
		elif bool(entry["damaged"]):
			damaged.append(entry.duplicate(true))
		if building_id == MAIN_HALL_ID:
			station_operational = hp > 0
	return {
		"items": buildings,
		"damaged_buildings": damaged,
		"destroyed_buildings": destroyed,
		"station_operational": station_operational
	}


func _build_npc_settlement_snapshot() -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var items: Array[Dictionary] = []
	var active: Array[Dictionary] = []
	var unconscious: Array[Dictionary] = []
	var escaped: Array[Dictionary] = []
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("get_npc"):
		return {
			"items": items,
			"active_npcs": active,
			"unconscious_npcs": unconscious,
			"escaped_npcs": escaped
		}
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var npc: Dictionary = npc_system.get_npc(npc_id)
		var state: Dictionary = npc.get("states", {}) if npc.get("states", {}) is Dictionary else {}
		if npc_system.has_method("get_npc_state"):
			state = npc_system.get_npc_state(npc_id)
		var entry := {
			"id": npc_id,
			"name": str(npc.get("name", npc_id)),
			"recruited": bool(npc.get("recruited", false)),
			"hp": int(state.get("hp", 0)),
			"max_hp": int(state.get("max_hp", 0)),
			"unconscious": bool(state.get("unconscious", false)),
			"escaped": bool(state.get("escaped", false)),
			"behavior_mode": str(state.get("behavior_mode", BEHAVIOR_MODE_WORK)),
			"current_action": str(state.get("current_action", "")),
			"current_location": str(state.get("current_location", ""))
		}
		items.append(entry)
		if bool(entry["escaped"]):
			escaped.append(entry.duplicate(true))
		elif bool(entry["unconscious"]):
			unconscious.append(entry.duplicate(true))
		else:
			active.append(entry.duplicate(true))
	return {
		"items": items,
		"active_npcs": active,
		"unconscious_npcs": unconscious,
		"escaped_npcs": escaped
	}


func _get_combatant_availability_snapshot() -> Dictionary:
	var snapshot := {
		"active_enemy_count": get_active_enemy_count(),
		"has_active_enemies": not _active_enemies.is_empty(),
		"total_combatant_count": 0,
		"available_combatant_count": 0,
		"unavailable_combatant_count": 0,
		"available_combatants": [],
		"unavailable_combatants": []
	}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		snapshot["error"] = "npc_system_missing"
		return snapshot
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		if not _is_npc_combat_eligible(npc_id, npc_system):
			continue
		var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system.has_method("get_npc") else {}
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		var unit_snapshot := _get_npc_unit_type_snapshot(npc_id)
		var reason := _get_combatant_unavailable_reason(state)
		var entry := {
			"npc_id": npc_id,
			"npc_name": str(npc.get("name", npc_id)),
			"unit_type": str(unit_snapshot.get("unit_type", "")),
			"unit_type_label": str(unit_snapshot.get("unit_type_label", "")),
			"main_weapon_id": str(unit_snapshot.get("main_weapon_id", "")),
			"main_weapon_name": str(unit_snapshot.get("main_weapon_name", "")),
			"hp": int(state.get("hp", 0)),
			"max_hp": int(state.get("max_hp", 0)),
			"behavior_mode": _get_npc_behavior_mode(npc_system, npc_id),
			"current_action": str(state.get("current_action", "idle"))
		}
		snapshot["total_combatant_count"] = int(snapshot.get("total_combatant_count", 0)) + 1
		if reason.is_empty():
			entry["available"] = true
			(snapshot["available_combatants"] as Array).append(entry)
		else:
			entry["available"] = false
			entry["unavailable_reason"] = reason
			(snapshot["unavailable_combatants"] as Array).append(entry)
	snapshot["available_combatant_count"] = (snapshot["available_combatants"] as Array).size()
	snapshot["unavailable_combatant_count"] = (snapshot["unavailable_combatants"] as Array).size()
	return snapshot


func _get_combatant_unavailable_reason(state: Dictionary) -> String:
	if bool(state.get("unconscious", false)):
		return "unconscious"
	if bool(state.get("escaped", false)):
		return "escaped"
	var intent := _get_escape_intent_from_state(state)
	if bool(intent.get("active", false)) and [ESCAPE_STATUS_ESCAPING, ESCAPE_STATUS_PAUSED_UNCONSCIOUS].has(str(intent.get("status", ""))):
		return "escaping"
	return ""


func _is_target_defeated(target: Dictionary) -> bool:
	var target_type := str(target.get("type", ""))
	var target_id := str(target.get("id", ""))
	match target_type:
		"building":
			var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
			if building_system == null or not building_system.has_method("get_building"):
				return false
			var building: Dictionary = (
				building_system.get_building_combat_snapshot(target_id)
				if building_system.has_method("get_building_combat_snapshot")
				else building_system.get_building(target_id)
			)
			return building.is_empty() or int(building.get("hp", 0)) <= 0
		"npc":
			var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
			if npc_system == null or not npc_system.has_method("get_npc_state"):
				return false
			var state: Dictionary = npc_system.get_npc_state(target_id)
			return state.is_empty() or bool(state.get("unconscious", false)) or bool(state.get("escaped", false))
		"defense_device":
			var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
			if device_system == null or not device_system.has_method("get_deployment"):
				return false
			var deployment: Dictionary = device_system.get_deployment(target_id)
			return (
				deployment.is_empty()
				or str(deployment.get("status", "")) != "active"
				or int(deployment.get("hp", 0)) <= 0
			)
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
	normalized["trigger_day"] = maxi(1, int(raw_wave.get("trigger_day", 3 + wave_number - 1)))
	normalized["trigger_hour"] = clampi(int(raw_wave.get("trigger_hour", 18)), 0, 23)
	normalized["trigger_minute"] = clampi(int(raw_wave.get("trigger_minute", 0)), 0, 59)
	normalized["trigger_second"] = clampi(int(raw_wave.get("trigger_second", 0)), 0, 59)
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
	normalized["penetration"] = maxf(0.0, float(raw_enemy.get("penetration", 0.0)))
	normalized["move_speed"] = maxf(0.1, float(raw_enemy.get("move_speed", 2.5)))
	var configured_range := maxf(0.1, float(raw_enemy.get("attack_range", raw_enemy.get("range", 1.5))))
	var normalized_weapon_type := str(normalized["weapon_type"])
	if normalized_weapon_type in MELEE_WEAPON_TYPES:
		configured_range = _get_model_calibrated_melee_range(normalized_weapon_type, configured_range)
	normalized["attack_range"] = configured_range
	var configured_attack_speed := maxf(0.0, float(raw_enemy.get("attack_speed", 0.0)))
	var configured_attack_interval := maxf(0.1, float(raw_enemy.get("attack_interval", 1.8)))
	if configured_attack_speed <= 0.0:
		configured_attack_speed = 1.0 / configured_attack_interval
	normalized["attack_speed"] = configured_attack_speed
	normalized["attack_interval"] = 1.0 / configured_attack_speed
	var animation_timing := COMBAT_ANIMATION_TIMING.get_timing(
		str(normalized["weapon_type"]),
		float(normalized["attack_interval"]),
		str(normalized.get("unit_type", "")) in ["cavalry", "mounted_ranged"]
	)
	normalized["configured_attack_windup"] = maxf(0.0, float(raw_enemy.get("attack_windup", 0.0)))
	normalized["attack_windup"] = float(animation_timing.get("impact_seconds", 0.0))
	normalized["attack_impact_ratio"] = float(animation_timing.get("impact_ratio", 0.5))
	normalized["attack_animation_authored_cycle"] = float(animation_timing.get("authored_cycle_seconds", 1.0))
	normalized["attack_playback_multiplier"] = float(animation_timing.get("playback_multiplier", 1.0))
	normalized["attack_impact_kind"] = str(animation_timing.get("impact_kind", "melee_contact"))
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
	if str(state.get("weapon_type", "")) in MELEE_WEAPON_TYPES:
		state["attack_range"] = _get_model_calibrated_melee_range(
			str(state.get("weapon_type", "")),
			float(state.get("attack_range", 1.5))
		)
	state["current_action"] = "spawned"
	state["target"] = {}
	state["target_priority"] = 0
	state["target_selection_reason"] = ""
	state["target_lock_until_frame"] = 0
	state["target_last_evaluated_frame"] = -1
	state["target_switch_count"] = 0
	state["attack_cooldown"] = 0.0
	state["attack_windup_remaining"] = 0.0
	state["attack_windup_target"] = {}
	state["attack_cycle_phase"] = "idle"
	state["attack_cycle_elapsed"] = 0.0
	state["attack_cycle_duration"] = 0.0
	state["attack_impact_seconds"] = 0.0
	state["attack_cycle_target"] = {}
	state["attack_impact_committed"] = false
	state["attack_sequence"] = 0
	state["attack_last_sequence_time"] = -1.0
	state["attack_next_sequence_time"] = 0.0
	state["stagger_remaining"] = 0.0
	state["stagger_count"] = 0
	state["windup_interrupt_count"] = 0
	state["last_stagger_result"] = {}
	state["damage_attack_interrupt_count"] = 0
	state["damage_windup_interrupt_count"] = 0
	state["last_damage_attack_interrupt"] = {}
	state["last_attack_result"] = {}
	state["alive"] = true
	return state


func _get_formal_enemy_pilot_template() -> Dictionary:
	if _waves.is_empty():
		return {}
	var enemies := (_waves[0] as Dictionary).get("enemies", []) as Array
	if enemies.is_empty() or not enemies[0] is Dictionary:
		return {}
	return (enemies[0] as Dictionary).duplicate(true)


func _create_formal_enemy_pilot_actor(enemy: Dictionary) -> ActorMotionBody:
	return _create_formal_enemy_actor(enemy, "FormalEnemyFoot01", true)


func _create_formal_enemy_actor(
	enemy: Dictionary,
	node_name: String,
	is_navigation_pilot: bool
) -> ActorMotionBody:
	var actor := ACTOR_MOTION_SCENE.instantiate() as ActorMotionBody
	actor.name = node_name
	actor.set_meta("enemy_id", str(enemy.get("id", "")))
	actor.set_meta("formal_navigation_pilot", is_navigation_pilot)
	actor.set_meta("formal_active_enemy", not is_navigation_pilot)
	var mesh := actor.get_node_or_null("ActorMesh") as MeshInstance3D
	if mesh != null:
		mesh.material_override = _make_enemy_material(str(enemy.get("unit_type", "melee_infantry")))
	var label := actor.get_node_or_null("DebugLabel") as Label3D
	if label != null:
		label.name = "EnemyLabel"
		label.text = str(enemy.get("name", "敌军步兵"))
		label.position = Vector3(0.0, ENEMY_NAME_LABEL_HEIGHT, 0.0)
	_ensure_enemy_world_health_bar(actor, enemy, label)
	var formal_art_attached := _attach_formal_enemy_art(actor, enemy)
	if mesh != null:
		mesh.visible = not formal_art_attached
	_configure_enemy_selection(actor, str(enemy.get("id", "")))
	return actor


func _configure_enemy_selection(actor: ActorMotionBody, enemy_id: String) -> void:
	if actor == null or enemy_id.is_empty():
		return
	var interaction_area := actor.get_node_or_null("InteractionArea") as Area3D
	if interaction_area == null:
		return
	interaction_area.input_ray_pickable = true
	interaction_area.input_event.connect(_on_enemy_interaction_input.bind(enemy_id))


func _on_enemy_interaction_input(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_event_normal: Vector3,
	_shape_index: int,
	enemy_id: String
) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not _active_enemies.has(enemy_id):
		return
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("enemy_clicked"):
		event_bus.enemy_clicked.emit(enemy_id)
		get_viewport().set_input_as_handled()


func _resolve_formal_wave_spawn_formation(controller: Node, templates: Array) -> Dictionary:
	var config: Dictionary = controller.get_formal_wave_spawn_config()
	var columns := maxi(1, int(config.get("columns", 3)))
	var minimum_spacing := maxf(0.01, float(config.get("minimum_spacing", 0.95)))
	var minimum_clearance := maxf(0.0, float(config.get("minimum_capsule_clearance", 0.0)))
	var maximum_radius := 0.0
	for raw_template in templates:
		var enemy_template: Dictionary = raw_template if raw_template is Dictionary else {}
		if int(enemy_template.get("count", 0)) <= 0:
			continue
		var unit_type := str(enemy_template.get("unit_type", ""))
		var profile_id := "enemy_mounted" if unit_type in ["cavalry", "mounted_ranged"] else "enemy_foot"
		var profile: Dictionary = controller.get_actor_motion_profile(profile_id)
		var fallback_radius := 0.65 if profile_id == "enemy_mounted" else 0.42
		maximum_radius = maxf(maximum_radius, float(profile.get("radius", fallback_radius)))
	return {
		"columns": columns,
		"spacing": maxf(minimum_spacing, maximum_radius * 2.0 + minimum_clearance),
		"maximum_actor_radius": maximum_radius,
		"minimum_capsule_clearance": minimum_clearance,
		"ai_updates_per_frame": maxi(1, int(config.get("ai_updates_per_frame", 8))),
		"contact_update_interval_frames": maxi(1, int(config.get("contact_update_interval_frames", 6))),
		"avoidance_update_interval_frames": maxi(1, int(config.get("avoidance_update_interval_frames", 3))),
		"source": "physics_navigation_v1"
	}


func _get_route_formation_position(
	route: Dictionary,
	stage_index: int,
	formation_index: int,
	fallback: Vector3,
	column_count: int = 3,
	spacing: float = 0.95
) -> Vector3:
	var stages := route.get("stages", []) as Array
	if stage_index < 0 or stage_index >= stages.size():
		return fallback
	var stage := stages[stage_index] as Dictionary
	var stage_position: Vector3 = stage.get("position", fallback)
	var direction := Vector3.FORWARD
	if stage_index > 0:
		var previous_stage := stages[stage_index - 1] as Dictionary
		var previous_position: Vector3 = previous_stage.get("position", stage_position)
		direction = stage_position - previous_position
	elif stages.size() > 1:
		var next_stage := stages[1] as Dictionary
		var next_position: Vector3 = next_stage.get("position", stage_position)
		direction = next_position - stage_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	var lateral := Vector3(-direction.z, 0.0, direction.x)
	column_count = maxi(1, column_count)
	spacing = maxf(0.01, spacing)
	var column := formation_index % column_count
	var row := formation_index / column_count
	var center_column := float(column_count - 1) * 0.5
	# Slots fan out on the approach side of a stage.  No row is pushed beyond
	# the authoritative attack point into a building collider.
	return stage_position + lateral * (float(column) - center_column) * spacing - direction * float(row) * spacing


func _get_oriented_formation_position(
	front_center: Vector3,
	travel_direction: Vector3,
	formation_index: int,
	column_count: int,
	spacing: float
) -> Vector3:
	travel_direction.y = 0.0
	if travel_direction.length_squared() <= 0.0001:
		travel_direction = Vector3(0.0, 0.0, -1.0)
	else:
		travel_direction = travel_direction.normalized()
	var lateral := Vector3(-travel_direction.z, 0.0, travel_direction.x)
	column_count = maxi(1, column_count)
	spacing = maxf(0.01, spacing)
	var column := formation_index % column_count
	var row := formation_index / column_count
	var center_column := float(column_count - 1) * 0.5
	return front_center + lateral * (float(column) - center_column) * spacing - travel_direction * float(row) * spacing


func _find_route_stage_index(route: Dictionary, stage_id: String) -> int:
	var stages := route.get("stages", []) as Array
	for stage_index in range(stages.size()):
		var stage := stages[stage_index] as Dictionary
		if str(stage.get("id", "")) == stage_id:
			return stage_index
	return -1


func _get_formal_attack_slot_role(unit_type: String) -> String:
	if unit_type == "polearm_infantry":
		return "polearm_rear"
	return "melee_front"


func _is_formal_wave_role_ready_at_stage(wave_number: int, role_id: String, stage_id: String) -> bool:
	var matched := 0
	for raw_slice in _formal_first_wave_slices.values():
		var slice := raw_slice as Dictionary
		if int(slice.get("wave_number", 0)) != wave_number or str(slice.get("attack_slot_role", "")) != role_id:
			continue
		matched += 1
		if str(slice.get("current_stage_id", "")) != stage_id or not bool(slice.get("attack_unlocked", false)):
			return false
	return matched > 0


func _resolve_formal_wave_role_slots(
	legacy_slots: Dictionary,
	slot_sets: Dictionary,
	role_id: String
) -> Dictionary:
	if slot_sets.is_empty():
		return legacy_slots.duplicate(true)
	var result: Dictionary = {}
	for raw_building_id in slot_sets.keys():
		var building_id := str(raw_building_id)
		var building_sets := slot_sets.get(building_id, {}) as Dictionary
		result[building_id] = (building_sets.get(role_id, []) as Array).duplicate(true)
	return result


func _get_formal_first_wave_stage_index(enemy_id: String, stage_id: String) -> int:
	var slice: Dictionary = _formal_first_wave_slices.get(enemy_id, {})
	var route := slice.get("route", {}) as Dictionary
	return _find_route_stage_index(route, stage_id)


func _get_formal_first_wave_stage_position(enemy_id: String, stage_id: String, fallback: Vector3) -> Vector3:
	var slice: Dictionary = _formal_first_wave_slices.get(enemy_id, {})
	if str(slice.get("movement_model", "")) == "dynamic_combat_pressure":
		var dynamic_route := slice.get("route", {}) as Dictionary
		for raw_stage in dynamic_route.get("stages", []):
			var dynamic_stage := raw_stage as Dictionary
			if str(dynamic_stage.get("id", "")) == stage_id:
				return dynamic_stage.get("position", fallback)
		return fallback
	var resolved := slice.get("resolved_stage_positions", {}) as Dictionary
	if resolved.has(stage_id):
		return resolved[stage_id]
	var slots_by_building := slice.get("attack_slots_world", {}) as Dictionary
	var slots := slots_by_building.get(stage_id, []) as Array
	if not slots.is_empty():
		var slot_index := int(slice.get("formation_index", 0)) % slots.size()
		if int(slice.get("wave_number", 1)) == 2 and stage_id == "main_hall":
			var resolved_slot_indices := slice.get("resolved_slot_indices", {}) as Dictionary
			if resolved_slot_indices.has(stage_id):
				slot_index = int(resolved_slot_indices[stage_id])
			else:
				var claimed: Dictionary = {}
				var role_id := str(slice.get("attack_slot_role", ""))
				for raw_other_id in _formal_first_wave_slices.keys():
					var other_id := str(raw_other_id)
					if other_id == enemy_id:
						continue
					var other := _formal_first_wave_slices[other_id] as Dictionary
					if str(other.get("attack_slot_role", "")) != role_id:
						continue
					var other_indices := other.get("resolved_slot_indices", {}) as Dictionary
					if other_indices.has(stage_id):
						claimed[int(other_indices[stage_id])] = true
				var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
				var origin := actor.global_position if actor != null else fallback
				var best_distance := INF
				for candidate_index in range(slots.size()):
					if claimed.has(candidate_index):
						continue
					var candidate: Vector3 = slots[candidate_index]
					var distance := Vector2(origin.x, origin.z).distance_to(Vector2(candidate.x, candidate.z))
					if distance < best_distance:
						best_distance = distance
						slot_index = candidate_index
				resolved_slot_indices[stage_id] = slot_index
				slice["resolved_slot_indices"] = resolved_slot_indices
				_formal_first_wave_slices[enemy_id] = slice
		return slots[slot_index]
	var route := slice.get("route", {}) as Dictionary
	var stages := route.get("stages", []) as Array
	for stage_index in range(stages.size()):
		var stage := stages[stage_index] as Dictionary
		if str(stage.get("id", "")) == stage_id:
			return _get_route_formation_position(route, stage_index, int(slice.get("formation_index", 0)), fallback)
	return fallback


func _request_formal_first_wave_stage(enemy_id: String, stage_index: int) -> bool:
	if not _formal_first_wave_slices.has(enemy_id):
		return false
	var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	if actor == null:
		return false
	var slice: Dictionary = _formal_first_wave_slices[enemy_id]
	var route := slice.get("route", {}) as Dictionary
	var stages := route.get("stages", []) as Array
	if stage_index < 0 or stage_index >= stages.size():
		return false
	var stage := stages[stage_index] as Dictionary
	var stage_id := str(stage.get("id", ""))
	var route_phase := "marching_to_front_gate"
	if stage_id == "main_hall":
		route_phase = "marching_to_main_hall"
	elif stage_id == "warehouse":
		route_phase = "marching_to_warehouse"
	slice["target_stage_index"] = stage_index
	slice["target_stage_id"] = stage_id
	slice["phase"] = route_phase
	_formal_first_wave_slices[enemy_id] = slice
	if _active_enemies.has(enemy_id):
		var enemy: Dictionary = _active_enemies[enemy_id]
		enemy["current_action"] = "moving_to_%s" % stage_id
		enemy["formal_route_phase"] = route_phase
		_active_enemies[enemy_id] = enemy
	var target_position := _get_formal_first_wave_stage_position(enemy_id, stage_id, actor.global_position)
	slice = _formal_first_wave_slices[enemy_id]
	var is_dynamic_pressure := str(slice.get("movement_model", "")) == "dynamic_combat_pressure"
	var desired_distance := (
		maxf(0.05, float(_formal_attack_position_policy.get("arrival_tolerance", 0.32)))
		if is_dynamic_pressure
		else 0.5
	)
	if not is_dynamic_pressure and int(slice.get("wave_number", 1)) == 2:
		desired_distance = 0.85
		if str(slice.get("attack_slot_role", "")) == "polearm_rear":
			desired_distance = 1.5
		if stage_id in ["front_gate", "warehouse"] and str(slice.get("attack_slot_role", "")) == "melee_front" and int(slice.get("formation_index", 0)) >= 6:
			# The gate is only six metres wide. The second sword rank may stop up to
			# one weapon reach behind its assigned point instead of pushing through
			# an already occupied front rank.
			desired_distance = 1.35
	actor.navigation_agent.target_desired_distance = desired_distance
	var navigation_map := actor.get_navigation_map()
	if navigation_map.is_valid():
		target_position = NavigationServer3D.map_get_closest_point(navigation_map, target_position)
	var resolved := slice.get("resolved_stage_positions", {}) as Dictionary
	resolved[stage_id] = target_position
	slice["resolved_stage_positions"] = resolved
	var target_slots := [] as Array if is_dynamic_pressure else (slice.get("attack_slots_world", {}) as Dictionary).get(stage_id, []) as Array
	var assigned_slot_index := int(slice.get("formation_index", 0)) % target_slots.size() if not target_slots.is_empty() else -1
	var resolved_slot_indices := slice.get("resolved_slot_indices", {}) as Dictionary
	if resolved_slot_indices.has(stage_id):
		assigned_slot_index = int(resolved_slot_indices[stage_id])
	slice["attack_slot_index"] = assigned_slot_index
	slice["attack_slot_position"] = target_position
	slice["combat_target_id"] = stage_id
	slice["combat_target_type"] = "building"
	slice["motion_target_position"] = target_position
	_formal_first_wave_slices[enemy_id] = slice
	_set_formal_enemy_tactical_motion_paused(enemy_id, false)
	var requested := actor.request_motion(
		target_position,
		"formal_wave_pressure:%s:%s" % [enemy_id, stage_id],
		_get_combat_motion_options("enemy_stage_approach") if is_dynamic_pressure else {}
	)
	_set_formal_enemy_tactical_motion_paused(enemy_id, false)
	return requested


func _on_formal_first_wave_motion_arrived(request_id: String, _target_position: Vector3, enemy_id: String) -> void:
	if not _formal_first_wave_slices.has(enemy_id):
		return
	var slice: Dictionary = _formal_first_wave_slices[enemy_id]
	if request_id.begins_with("formal_wave_pressure_unit:") or request_id.begins_with("formal_wave_pressure_building:"):
		# ActorMotion arrival only proves that the leased slot or queue point was
		# reached. CombatSystem still owns the stricter range/lease check, and a
		# waiter must never be promoted to ready_to_attack by this callback.
		slice["phase"] = "pressure_position_reached"
		slice["completed"] = false
		_formal_first_wave_slices[enemy_id] = slice
		return
	var route := slice.get("route", {}) as Dictionary
	var stages := route.get("stages", []) as Array
	var stage_index := int(slice.get("target_stage_index", -1))
	if stage_index < 0 or stage_index >= stages.size():
		return
	var stage := stages[stage_index] as Dictionary
	var stage_id := str(stage.get("id", ""))
	var completed_ids := slice.get("completed_stage_ids", []) as Array
	if stage_id not in completed_ids:
		completed_ids.append(stage_id)
	slice["completed_stage_ids"] = completed_ids
	slice["current_stage_id"] = stage_id
	slice["target_stage_id"] = ""
	var building_id := ""
	match stage_id:
		"front_gate":
			slice["phase"] = "front_gate_reached"
			building_id = "front_gate"
		"warehouse":
			slice["phase"] = "warehouse_reached"
			building_id = "warehouse"
		"main_hall":
			slice["phase"] = "main_hall_reached"
			building_id = "main_hall"
	if not building_id.is_empty():
		slice["completed"] = true
		slice["attack_unlocked"] = true
		slice["attack_target_building_id"] = building_id
		_formal_first_wave_slices[enemy_id] = slice
		if _active_enemies.has(enemy_id):
			var enemy: Dictionary = _active_enemies[enemy_id]
			enemy["current_action"] = "ready_to_attack_%s" % building_id
			enemy["formal_route_phase"] = str(slice.get("phase", ""))
			_active_enemies[enemy_id] = enemy
		return
	_formal_first_wave_slices[enemy_id] = slice
	if not _request_formal_first_wave_stage(enemy_id, stage_index + 1):
		_on_formal_first_wave_motion_failed("", "next_stage_request_failed", enemy_id)


func _on_formal_first_wave_motion_failed(_request_id: String, reason: String, enemy_id: String) -> void:
	if not _formal_first_wave_slices.has(enemy_id):
		return
	var slice: Dictionary = _formal_first_wave_slices[enemy_id]
	if str(slice.get("movement_model", "")) == "dynamic_combat_pressure" and reason == "stuck_timeout":
		_release_enemy_attack_position(enemy_id, "path_failed:%s" % reason, true)
		slice["phase"] = "pressing_blocked"
		slice["completed"] = false
		slice["failure_reason"] = ""
		slice["blocked_count"] = int(slice.get("blocked_count", 0)) + 1
		_formal_first_wave_slices[enemy_id] = slice
		if _active_enemies.has(enemy_id):
			var blocked_enemy: Dictionary = _active_enemies[enemy_id]
			blocked_enemy["current_action"] = "pressing_for_attack_space"
			blocked_enemy["formal_route_phase"] = "pressing_blocked"
			_active_enemies[enemy_id] = blocked_enemy
		return
	slice["phase"] = "navigation_failed"
	slice["completed"] = false
	slice["failure_reason"] = reason
	_formal_first_wave_slices[enemy_id] = slice
	if _active_enemies.has(enemy_id):
		_release_enemy_attack_position(enemy_id, "path_failed:%s" % reason, true)
		var enemy: Dictionary = _active_enemies[enemy_id]
		enemy["current_action"] = "navigation_failed"
		enemy["formal_route_phase"] = "navigation_failed"
		_active_enemies[enemy_id] = enemy


func _on_formal_first_wave_motion_cancelled(_request_id: String, reason: String, enemy_id: String) -> void:
	if reason in ["formal_first_wave_stopped", "superseded"]:
		return
	_on_formal_first_wave_motion_failed("", reason, enemy_id)


func _begin_formal_first_wave_route(enemy_id: String, enemy: Dictionary, stage_id: String, route_phase: String) -> bool:
	var stage_index := _get_formal_first_wave_stage_index(enemy_id, stage_id)
	if stage_index < 0:
		return false
	_release_enemy_attack_position(enemy_id, "route_target_changed")
	enemy["target"] = {}
	_cancel_enemy_attack_timeline(enemy)
	enemy["formal_route_phase"] = route_phase
	_active_enemies[enemy_id] = enemy
	var slice: Dictionary = _formal_first_wave_slices[enemy_id]
	slice["completed"] = false
	slice["attack_unlocked"] = false
	slice["attack_target_building_id"] = ""
	slice["phase"] = route_phase
	_formal_first_wave_slices[enemy_id] = slice
	return _request_formal_first_wave_stage(enemy_id, stage_index)


func _sample_enemy_presentation_motion(runtime: Dictionary, actor: ActorMotionBody, art_view: Node3D, delta: float) -> Vector3:
	var current_position := actor.global_position
	var previous_position: Vector3 = runtime.get("presentation_previous_position", current_position)
	var raw_planar_displacement := Vector3(
		current_position.x - previous_position.x,
		0.0,
		current_position.z - previous_position.z
	)
	var safe_delta := maxf(0.000001, delta)
	var body_radius := actor.get_body_radius()
	var intended_distance := maxf(actor.velocity.length() * safe_delta, 0.0)
	var recovery_allowance := minf(0.04, body_radius * 0.1)
	var visible_limit := intended_distance + recovery_allowance
	var previous_compensation: Vector3 = runtime.get("presentation_visual_compensation", Vector3.ZERO)
	var compensation := previous_compensation
	if raw_planar_displacement.length() > visible_limit and visible_limit > 0.0:
		var intended_displacement := raw_planar_displacement.normalized() * visible_limit
		compensation -= raw_planar_displacement - intended_displacement
	else:
		var recovery_speed := minf(
			maxf(actor.get_profile_base_speed() * 0.45, 1.0),
			2.0
		)
		compensation = compensation.move_toward(Vector3.ZERO, recovery_speed * safe_delta)
	var proposed_visible_displacement := raw_planar_displacement + compensation - previous_compensation
	if proposed_visible_displacement.length() > visible_limit and visible_limit > 0.0:
		var limited_visible_displacement := proposed_visible_displacement.normalized() * visible_limit
		compensation = previous_compensation + limited_visible_displacement - raw_planar_displacement
	# A dense contact can apply several legitimate capsule recovery impulses in
	# consecutive ticks. Keep enough visual slack to absorb that short burst, then
	# blend the art root back onto the authoritative physics body.
	compensation = compensation.limit_length(maxf(body_radius * 2.5, 0.8))
	var planar_displacement := raw_planar_displacement + compensation - previous_compensation
	if art_view != null:
		var art_base_position: Vector3 = runtime.get("presentation_art_base_position", art_view.position)
		runtime["presentation_art_base_position"] = art_base_position
		art_view.position = art_base_position + actor.global_basis.inverse() * compensation
	var planar_speed := planar_displacement.length() / safe_delta
	var actor_motion_active := actor.is_motion_active()
	var was_active := bool(runtime.get("presentation_movement_active", false))
	var stationary_seconds := float(runtime.get("presentation_stationary_seconds", 0.0))
	var moving := false
	# Dense RVO queues can advance a valid navigation request far below normal
	# profile speed. Treat that measured crawl as travel, while requiring an active
	# request on initial activation so idle collision depenetration does not start a
	# walk cycle by itself.
	if actor_motion_active and planar_speed >= ENEMY_PRESENTATION_MOVE_START_SPEED:
		moving = true
		stationary_seconds = 0.0
	elif was_active and planar_speed >= ENEMY_PRESENTATION_MOVE_STOP_SPEED:
		moving = true
		stationary_seconds = 0.0
	elif was_active and actor_motion_active:
		stationary_seconds += maxf(0.0, delta)
		moving = stationary_seconds < ENEMY_PRESENTATION_MOVE_STOP_GRACE_SECONDS
	else:
		stationary_seconds = 0.0
	var cadence_speed := planar_speed
	if moving and planar_speed < ENEMY_PRESENTATION_MOVE_STOP_SPEED:
		cadence_speed = maxf(
			planar_speed,
			float(runtime.get("presentation_last_moving_speed", ENEMY_PRESENTATION_MOVE_START_SPEED))
		)
	if moving and planar_speed >= ENEMY_PRESENTATION_MOVE_STOP_SPEED:
		runtime["presentation_last_moving_speed"] = planar_speed
	elif not moving:
		cadence_speed = 0.0
	runtime["presentation_previous_position"] = current_position
	runtime["presentation_raw_planar_displacement"] = raw_planar_displacement
	runtime["presentation_planar_displacement"] = planar_displacement
	runtime["presentation_planar_speed"] = planar_speed
	runtime["presentation_visual_compensation"] = compensation
	runtime["presentation_visible_frame_displacement"] = planar_displacement.length()
	runtime["presentation_maximum_visible_frame_displacement"] = maxf(
		float(runtime.get("presentation_maximum_visible_frame_displacement", 0.0)),
		planar_displacement.length()
	)
	runtime["presentation_cadence_speed"] = cadence_speed
	runtime["presentation_movement_active"] = moving
	runtime["presentation_stationary_seconds"] = stationary_seconds
	runtime["presentation_actor_motion_active"] = actor_motion_active
	return planar_displacement


func _sync_formal_first_wave_presentation(delta: float) -> void:
	for raw_enemy_id in _formal_first_wave_slices.keys():
		var enemy_id := str(raw_enemy_id)
		if not _active_enemies.has(enemy_id):
			continue
		var actor := get_node_or_null(_formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		if actor == null:
			continue
		var slice: Dictionary = _formal_first_wave_slices[enemy_id]
		var art_view := actor.get_node_or_null("EnemyArtView") as Node3D
		var movement_direction := _sample_enemy_presentation_motion(slice, actor, art_view, delta)
		var facing_sample := movement_direction
		var facing_speed := float(slice.get("presentation_planar_speed", 0.0))
		if facing_sample.length() < 0.0001:
			facing_sample = Vector3(actor.velocity.x, 0.0, actor.velocity.z)
			facing_speed = facing_sample.length()
		var previous_facing: Vector3 = slice.get("presentation_facing_direction", Vector3.ZERO)
		if facing_speed >= 0.35 and facing_sample.length_squared() > 0.0001:
			facing_sample = facing_sample.normalized()
			var next_facing := facing_sample
			if previous_facing.length_squared() > 0.0001:
				next_facing = _turn_planar_direction_toward(previous_facing, facing_sample, delta)
				var turn_radians := acos(clampf(previous_facing.normalized().dot(next_facing), -1.0, 1.0))
				slice["presentation_total_turn_radians"] = float(slice.get("presentation_total_turn_radians", 0.0)) + turn_radians
				slice["presentation_max_turn_radians_per_frame"] = maxf(float(slice.get("presentation_max_turn_radians_per_frame", 0.0)), turn_radians)
			slice["presentation_facing_direction"] = next_facing
			movement_direction = next_facing
		elif previous_facing.length_squared() > 0.0001:
			# Collision depenetration and near-zero RVO jitter are not intentional
			# travel directions, so they must not rotate the visible character.
			movement_direction = previous_facing
		_formal_first_wave_slices[enemy_id] = slice
		var enemy: Dictionary = _active_enemies[enemy_id]
		enemy["position"] = actor.global_position
		_active_enemies[enemy_id] = enemy
		_apply_enemy_art_state(
			art_view,
			enemy,
			movement_direction,
			bool(slice.get("presentation_movement_active", false)),
			float(slice.get("presentation_cadence_speed", 0.0)),
			true
		)


func _turn_planar_direction_toward(current_direction: Vector3, target_direction: Vector3, delta: float) -> Vector3:
	var current := Vector3(current_direction.x, 0.0, current_direction.z).normalized()
	var target := Vector3(target_direction.x, 0.0, target_direction.z).normalized()
	if current.length_squared() <= 0.0001:
		return target
	if target.length_squared() <= 0.0001:
		return current
	var current_yaw := atan2(-current.x, -current.z)
	var target_yaw := atan2(-target.x, -target.z)
	var yaw_delta := wrapf(target_yaw - current_yaw, -PI, PI)
	# Avoidance may alternate left/right every physics frame in a dense crowd.
	# Visible bodies follow that intent at a bounded 360 degrees per second.
	var turn_step := clampf(yaw_delta, -TAU * delta, TAU * delta)
	var next_yaw := current_yaw + turn_step
	return Vector3(-sin(next_yaw), 0.0, -cos(next_yaw))


func _clear_formal_first_wave_nodes(_reason: String) -> void:
	for raw_path in _formal_first_wave_node_paths.values():
		var actor := get_node_or_null(raw_path) as ActorMotionBody
		if actor != null:
			if actor.is_motion_active():
				actor.cancel_motion("formal_first_wave_stopped")
			actor.queue_free()
	_formal_first_wave_slices.clear()
	_formal_first_wave_node_paths.clear()


func _request_formal_active_enemy_stage(actor: ActorMotionBody, stage_index: int) -> bool:
	if actor == null or _formal_active_enemy_slice.is_empty():
		return false
	var route := _formal_active_enemy_slice.get("route", {}) as Dictionary
	var stages := route.get("stages", []) as Array
	if stage_index < 0 or stage_index >= stages.size():
		return false
	var stage := stages[stage_index] as Dictionary
	var stage_id := str(stage.get("id", ""))
	var route_phase := "marching"
	if stage_id == "main_hall":
		route_phase = "marching_to_main_hall"
	elif stage_index >= _get_formal_enemy_stage_index("gate_turn"):
		route_phase = "marching_to_warehouse"
	var slice := _formal_active_enemy_slice
	slice["target_stage_index"] = stage_index
	slice["target_stage_id"] = stage_id
	slice["phase"] = route_phase
	_formal_active_enemy_slice = slice
	if _active_enemies.has(FORMAL_ACTIVE_ENEMY_SLICE_ID):
		var enemy: Dictionary = _active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID]
		enemy["current_action"] = "moving_to_%s" % stage_id
		enemy["formal_route_phase"] = route_phase
		_active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID] = enemy
	var requested := actor.request_motion(
		stage.get("position", actor.global_position),
		"formal_active_enemy:%s" % stage_id,
		_get_combat_motion_options("enemy_legacy_stage_approach")
	)
	actor.set_motion_paused(_is_gameplay_paused())
	return requested


func _on_formal_active_enemy_motion_arrived(request_id: String, _target_position: Vector3) -> void:
	if _formal_active_enemy_slice.is_empty() or not request_id.begins_with("formal_active_enemy:"):
		return
	var slice := _formal_active_enemy_slice
	var route := slice.get("route", {}) as Dictionary
	var stages := route.get("stages", []) as Array
	var stage_index := int(slice.get("target_stage_index", -1))
	if stage_index < 0 or stage_index >= stages.size():
		return
	var stage := stages[stage_index] as Dictionary
	var stage_id := str(stage.get("id", ""))
	var completed_ids := slice.get("completed_stage_ids", []) as Array
	if stage_id not in completed_ids:
		completed_ids.append(stage_id)
	slice["completed_stage_ids"] = completed_ids
	slice["current_stage_id"] = stage_id
	slice["target_stage_id"] = ""
	if stage_id == "front_gate":
		slice["phase"] = "front_gate_reached"
		slice["completed"] = true
		slice["attack_unlocked"] = true
		slice["attack_target_building_id"] = "front_gate"
		_formal_active_enemy_slice = slice
		if _active_enemies.has(FORMAL_ACTIVE_ENEMY_SLICE_ID):
			var enemy: Dictionary = _active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID]
			enemy["current_action"] = "ready_to_attack_front_gate"
			enemy["formal_route_phase"] = "front_gate_reached"
			_active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID] = enemy
		return
	if stage_id == "warehouse":
		slice["phase"] = "warehouse_reached"
		slice["completed"] = true
		slice["attack_unlocked"] = true
		slice["attack_target_building_id"] = "warehouse"
		_formal_active_enemy_slice = slice
		if _active_enemies.has(FORMAL_ACTIVE_ENEMY_SLICE_ID):
			var warehouse_enemy: Dictionary = _active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID]
			warehouse_enemy["current_action"] = "ready_to_attack_warehouse"
			warehouse_enemy["formal_route_phase"] = "warehouse_reached"
			_active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID] = warehouse_enemy
		return
	if stage_id == "main_hall":
		slice["phase"] = "main_hall_reached"
		slice["completed"] = true
		slice["attack_unlocked"] = true
		slice["attack_target_building_id"] = "main_hall"
		_formal_active_enemy_slice = slice
		if _active_enemies.has(FORMAL_ACTIVE_ENEMY_SLICE_ID):
			var main_hall_enemy: Dictionary = _active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID]
			main_hall_enemy["current_action"] = "ready_to_attack_main_hall"
			main_hall_enemy["formal_route_phase"] = "main_hall_reached"
			_active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID] = main_hall_enemy
		return
	_formal_active_enemy_slice = slice
	var actor := get_node_or_null(_formal_active_enemy_slice_node_path) as ActorMotionBody
	if not _request_formal_active_enemy_stage(actor, stage_index + 1):
		_on_formal_active_enemy_motion_failed(request_id, "next_stage_request_failed")


func _on_formal_active_enemy_motion_failed(_request_id: String, reason: String) -> void:
	if _formal_active_enemy_slice.is_empty():
		return
	var slice := _formal_active_enemy_slice
	slice["phase"] = "navigation_failed"
	slice["completed"] = false
	slice["failure_reason"] = reason
	_formal_active_enemy_slice = slice
	if _active_enemies.has(FORMAL_ACTIVE_ENEMY_SLICE_ID):
		var enemy: Dictionary = _active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID]
		enemy["current_action"] = "navigation_failed"
		enemy["formal_route_phase"] = "navigation_failed"
		_active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID] = enemy


func _on_formal_active_enemy_motion_cancelled(_request_id: String, reason: String) -> void:
	if _formal_active_enemy_slice.is_empty() or reason == "active_slice_stopped":
		return
	_on_formal_active_enemy_motion_failed("", reason)


func _sync_formal_active_enemy_slice_presentation(delta: float) -> void:
	if _formal_active_enemy_slice.is_empty() or not _active_enemies.has(FORMAL_ACTIVE_ENEMY_SLICE_ID):
		return
	var actor := get_node_or_null(_formal_active_enemy_slice_node_path) as ActorMotionBody
	if actor == null:
		return
	var slice := _formal_active_enemy_slice
	var art_view := actor.get_node_or_null("EnemyArtView") as Node3D
	var movement_direction := _sample_enemy_presentation_motion(slice, actor, art_view, delta)
	_formal_active_enemy_slice = slice
	var enemy: Dictionary = _active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID]
	enemy["position"] = actor.global_position
	_active_enemies[FORMAL_ACTIVE_ENEMY_SLICE_ID] = enemy
	_apply_enemy_art_state(
		art_view,
		enemy,
		movement_direction,
		bool(slice.get("presentation_movement_active", false)),
		float(slice.get("presentation_cadence_speed", 0.0)),
		true
	)


func _clear_formal_active_enemy_slice_node(_reason: String) -> void:
	var actor := get_node_or_null(_formal_active_enemy_slice_node_path) as ActorMotionBody
	if actor != null:
		if actor.is_motion_active():
			actor.cancel_motion("active_slice_stopped")
		actor.queue_free()
	_formal_active_enemy_slice.clear()
	_formal_active_enemy_slice_node_path = NodePath()


func _request_formal_enemy_pilot_stage(actor: ActorMotionBody, stage_index: int) -> bool:
	if actor == null or _formal_enemy_navigation_pilot.is_empty():
		return false
	var route := _formal_enemy_navigation_pilot.get("route", {}) as Dictionary
	var stages := route.get("stages", []) as Array
	if stage_index < 0 or stage_index >= stages.size():
		return false
	var stage := stages[stage_index] as Dictionary
	var stage_id := str(stage.get("id", ""))
	var pilot := _formal_enemy_navigation_pilot
	pilot["target_stage_index"] = stage_index
	pilot["target_stage_id"] = stage_id
	pilot["phase"] = "marching"
	var enemy := pilot.get("enemy", {}) as Dictionary
	enemy["current_action"] = "moving_to_%s" % stage_id
	pilot["enemy"] = enemy
	_formal_enemy_navigation_pilot = pilot
	var requested := actor.request_motion(
		stage.get("position", actor.global_position),
		"formal_enemy:%s" % stage_id,
		_get_combat_motion_options("enemy_legacy_stage_approach")
	)
	actor.set_motion_paused(_is_gameplay_paused())
	return requested


func _on_formal_enemy_pilot_motion_arrived(request_id: String, _target_position: Vector3) -> void:
	if _formal_enemy_navigation_pilot.is_empty() or not request_id.begins_with("formal_enemy:"):
		return
	var pilot := _formal_enemy_navigation_pilot
	var route := pilot.get("route", {}) as Dictionary
	var stages := route.get("stages", []) as Array
	var stage_index := int(pilot.get("target_stage_index", -1))
	if stage_index < 0 or stage_index >= stages.size():
		return
	var stage := stages[stage_index] as Dictionary
	var stage_id := str(stage.get("id", ""))
	var completed_ids := pilot.get("completed_stage_ids", []) as Array
	if stage_id not in completed_ids:
		completed_ids.append(stage_id)
	pilot["completed_stage_ids"] = completed_ids
	pilot["current_stage_id"] = stage_id
	pilot["target_stage_id"] = ""
	var enemy := pilot.get("enemy", {}) as Dictionary
	if stage_id == str(pilot.get("stop_stage_id", "front_gate")):
		pilot["phase"] = "front_gate_reached"
		pilot["completed"] = true
		enemy["current_action"] = "ready_to_attack_front_gate"
		pilot["enemy"] = enemy
		_formal_enemy_navigation_pilot = pilot
		return
	pilot["enemy"] = enemy
	_formal_enemy_navigation_pilot = pilot
	var actor := get_node_or_null(_formal_enemy_navigation_pilot_node_path) as ActorMotionBody
	if not _request_formal_enemy_pilot_stage(actor, stage_index + 1):
		_on_formal_enemy_pilot_motion_failed(request_id, "next_stage_request_failed")


func _on_formal_enemy_pilot_motion_failed(_request_id: String, reason: String) -> void:
	if _formal_enemy_navigation_pilot.is_empty():
		return
	var pilot := _formal_enemy_navigation_pilot
	pilot["phase"] = "navigation_failed"
	pilot["completed"] = false
	pilot["failure_reason"] = reason
	var enemy := pilot.get("enemy", {}) as Dictionary
	enemy["current_action"] = "navigation_failed"
	pilot["enemy"] = enemy
	_formal_enemy_navigation_pilot = pilot


func _on_formal_enemy_pilot_motion_cancelled(_request_id: String, reason: String) -> void:
	if _formal_enemy_navigation_pilot.is_empty() or reason == "pilot_stopped":
		return
	var pilot := _formal_enemy_navigation_pilot
	pilot["phase"] = "navigation_cancelled"
	pilot["completed"] = false
	pilot["failure_reason"] = reason
	_formal_enemy_navigation_pilot = pilot


func _sync_formal_enemy_navigation_pilot_presentation(delta: float) -> void:
	if _formal_enemy_navigation_pilot.is_empty():
		return
	var actor := get_node_or_null(_formal_enemy_navigation_pilot_node_path) as ActorMotionBody
	if actor == null:
		return
	var pilot := _formal_enemy_navigation_pilot
	var art_view := actor.get_node_or_null("EnemyArtView") as Node3D
	var movement_direction := _sample_enemy_presentation_motion(pilot, actor, art_view, delta)
	var enemy := pilot.get("enemy", {}) as Dictionary
	enemy["position"] = actor.global_position
	pilot["enemy"] = enemy
	_formal_enemy_navigation_pilot = pilot
	_apply_enemy_art_state(
		art_view,
		enemy,
		movement_direction,
		bool(pilot.get("presentation_movement_active", false)),
		float(pilot.get("presentation_cadence_speed", 0.0)),
		true
	)
	var label := actor.get_node_or_null("EnemyLabel") as Label3D
	if label != null:
		label.text = str(enemy.get("name", "敌军步兵"))
	var bar := actor.get_node_or_null("WorldHealthBar") as WorldHealthBar3D
	if bar != null:
		bar.set_health(int(enemy.get("hp", 0)), int(enemy.get("max_hp", 1)), true)


func _clear_formal_enemy_navigation_pilot(reason: String) -> void:
	var actor := get_node_or_null(_formal_enemy_navigation_pilot_node_path) as ActorMotionBody
	if actor != null:
		if actor.is_motion_active():
			actor.cancel_motion("pilot_stopped")
		actor.queue_free()
	_formal_enemy_navigation_pilot.clear()
	_formal_enemy_navigation_pilot_node_path = NodePath()
	if not reason.is_empty():
		_last_spawn_result["formal_enemy_pilot_stop_reason"] = reason


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
	label.position = Vector3(0.0, ENEMY_NAME_LABEL_HEIGHT, 0.0)
	label.text = str(enemy.get("name", "敌人"))
	enemy_node.add_child(label)
	_ensure_enemy_world_health_bar(enemy_node, enemy, label)
	var formal_art_attached := false
	if _can_attach_formal_enemy_art_sample():
		formal_art_attached = _attach_formal_enemy_art(enemy_node, enemy)
	body.visible = not formal_art_attached
	return enemy_node


func _can_attach_formal_enemy_art_sample() -> bool:
	for raw_path in _enemy_nodes.values():
		var existing_enemy := get_node_or_null(raw_path)
		if existing_enemy != null and existing_enemy.get_node_or_null("EnemyArtView") != null:
			return false
	return true


func _attach_formal_enemy_art(enemy_node: Node3D, enemy: Dictionary) -> bool:
	var unit_type := str(enemy.get("unit_type", ""))
	var weapon_type := str(enemy.get("weapon_type", ""))
	var use_mounted_chibi := unit_type in ["cavalry", "mounted_ranged"]
	var use_weapon_chibi := weapon_type in FORMAL_CHIBI_WEAPON_TYPES
	var scene_path := SWORD_SHIELD_CHIBI_ART_SCENE_PATH if use_weapon_chibi or use_mounted_chibi else LEGACY_FORMAL_ENEMY_ART_SCENE_PATH
	var art_scene := load(scene_path) as PackedScene
	if art_scene == null:
		return false
	var rider_view := art_scene.instantiate() as Node3D
	if rider_view == null:
		return false
	if use_mounted_chibi:
		# The production profile below owns the fixed weapon. The scene only owns
		# the shared character model and calibrated sockets; Main never calls the
		# NPCDevLab debug equipment API.
		rider_view.set("equipment_mode", "sword_shield" if weapon_type == "sword_shield" else "none")
		var mounted_art := ENEMY_MOUNTED_ART_SCRIPT.new() as Node3D
		mounted_art.name = "EnemyArtView"
		enemy_node.add_child(mounted_art)
		mounted_art.setup(
			rider_view,
			str(enemy.get("id", "enemy")),
			unit_type
		)
		if mounted_art.has_signal("defeat_cleanup_completed"):
			mounted_art.defeat_cleanup_completed.connect(_on_enemy_mounted_defeat_cleanup_completed)
		_apply_enemy_art_state(mounted_art, enemy, Vector3.FORWARD)
		enemy_node.set_meta("enemy_art_family", "synty_mounted_chibi")
		return true
	var art_view := rider_view
	art_view.name = "EnemyArtView"
	if use_weapon_chibi:
		art_view.set("equipment_mode", "sword_shield" if weapon_type == "sword_shield" else "none")
	else:
		art_view.set("character_rim", null)
		art_view.set("outfit_tint", Color(0.46, 0.22, 0.16, 1.0))
		art_view.set("hair_tint", Color(0.11, 0.065, 0.04, 1.0))
		art_view.set("show_smith_hammer", false)
	enemy_node.add_child(art_view)
	if not use_weapon_chibi:
		_attach_enemy_equipment(art_view)
	_apply_enemy_art_state(art_view, enemy, Vector3.FORWARD)
	enemy_node.set_meta("enemy_art_family", "synty_chibi" if use_weapon_chibi else "quaternius_legacy")
	return true


func _attach_enemy_equipment(art_view: Node3D) -> void:
	var right_hand := art_view.get_node_or_null("EquipmentSockets/RightHand") as Node3D
	var left_hand := art_view.get_node_or_null("EquipmentSockets/LeftHand") as Node3D
	var sword_scene := load(ENEMY_SWORD_SCENE_PATH) as PackedScene
	var shield_scene := load(ENEMY_SHIELD_SCENE_PATH) as PackedScene
	if right_hand != null and sword_scene != null:
		var sword := sword_scene.instantiate() as Node3D
		if sword != null:
			sword.name = "BronzeSword"
			sword.position = Vector3(0.0, 0.02, -0.04)
			sword.rotation_degrees = Vector3(0.0, 0.0, 92.0)
			sword.scale = Vector3.ONE * 0.82
			right_hand.add_child(sword)
	if left_hand != null and shield_scene != null:
		var shield := shield_scene.instantiate() as Node3D
		if shield != null:
			shield.name = "WoodenShield"
			shield.position = Vector3(0.03, 0.01, -0.08)
			shield.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			shield.scale = Vector3.ONE * 0.78
			left_hand.add_child(shield)


func _apply_enemy_art_state(
	art_view: Node3D,
	enemy: Dictionary,
	movement_direction: Vector3,
	movement_override_active: bool = false,
	movement_override_speed: float = 0.0,
	has_movement_override: bool = false
) -> void:
	if art_view == null:
		return
	var current_action := str(enemy.get("current_action", "idle"))
	var profile := {
		"id": str(enemy.get("id", "enemy")),
		"equipment": {
			"main_weapon": {
				"id": str(enemy.get("weapon_type", "")),
			}
		},
		"states": {
			"hp": int(enemy.get("hp", 1)),
			"max_hp": int(enemy.get("max_hp", 1)),
			"current_action": current_action,
			"behavior_mode": "combat",
			"unconscious": not bool(enemy.get("alive", true)),
			"escaped": false,
			"combat_mounted": bool(enemy.get("alive", true)) and str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"],
			"combat_attack_sequence": int(enemy.get("attack_sequence", 0)),
			"combat_attack_phase": str(enemy.get("attack_cycle_phase", "idle")),
			"combat_attack_elapsed_seconds": float(enemy.get("attack_cycle_elapsed", 0.0)),
			"combat_attack_cycle_seconds": float(enemy.get("attack_cycle_duration", enemy.get("attack_interval", 1.0))),
			"combat_attack_impact_seconds": float(enemy.get("attack_impact_seconds", enemy.get("attack_windup", 0.0))),
			"combat_attack_playback_multiplier": float(enemy.get("attack_playback_multiplier", 1.0)),
			"combat_attack_impact_committed": bool(enemy.get("attack_impact_committed", false)),
			"combat_projectile_authority": "combat_system" if _is_ranged_weapon_type(str(enemy.get("weapon_type", ""))) else ""
		}
	}
	if art_view.has_method("apply_profile"):
		art_view.apply_profile(profile)
	var moving := (
		current_action.begins_with("moving_to_")
		or current_action.begins_with("pressing_to_")
		or current_action == "pressing_for_attack_space"
	)
	var presentation_speed := float(enemy.get("move_speed", 2.8))
	if has_movement_override:
		moving = movement_override_active
		presentation_speed = maxf(0.0, movement_override_speed)
	# Locomotion consumes actual body travel, but authored attack and defeat states
	# remain explicit higher-priority presentation facts. Collision depenetration on
	# the attack frame must never replace the weapon clip with a run cycle.
	if _enemy_presentation_blocks_locomotion(enemy):
		moving = false
		presentation_speed = 0.0
	if art_view.has_method("set_movement_active"):
		art_view.set_movement_active(moving, presentation_speed)
	# apply_profile() already resolves attacking_/winding_up_ to the attack state.
	# Re-entering the debug force API here used to restart the clip and allocate a
	# full diagnostic snapshot for every attacker on every 0.1 s AI tick.
	_update_enemy_art_facing(art_view, enemy, movement_direction)


func _enemy_presentation_blocks_locomotion(enemy: Dictionary) -> bool:
	if not bool(enemy.get("alive", true)) or int(enemy.get("hp", 1)) <= 0:
		return true
	var current_action := str(enemy.get("current_action", "idle"))
	if current_action.begins_with("attacking_") or current_action.begins_with("winding_up_"):
		return true
	if current_action in ["staggered", "recovering_from_stagger", "unconscious"]:
		return true
	return str(enemy.get("attack_cycle_phase", "idle")) in ["windup", "recovery"]


func _update_enemy_art_facing(art_view: Node3D, enemy: Dictionary, movement_direction: Vector3) -> void:
	if art_view == null or not art_view.has_method("set_facing_direction"):
		return
	var facing_direction := movement_direction
	var current_action := str(enemy.get("current_action", "idle"))
	if current_action.begins_with("attacking_") or current_action.begins_with("winding_up_"):
		var target := enemy.get("target", {}) as Dictionary
		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		var target_position := _get_enemy_attack_contact_position(target, enemy_position)
		facing_direction = target_position - enemy_position
	facing_direction.y = 0.0
	if facing_direction.length_squared() > 0.0001:
		art_view.set_facing_direction(facing_direction)


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
	if raw_value is Vector3:
		return raw_value as Vector3
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


func _get_enemy_weapon_name(weapon_type: String) -> String:
	match weapon_type:
		"sword_shield":
			return "剑盾"
		"polearm":
			return "长杆武器"
		"bow":
			return "弓"
		"crossbow":
			return "弩"
		_:
			return weapon_type if not weapon_type.is_empty() else "无"


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
			"target_priority": int(enemy.get("target_priority", 0)),
			"target_selection_reason": str(enemy.get("target_selection_reason", "")),
			"target_lock_until_frame": int(enemy.get("target_lock_until_frame", 0)),
			"target_last_evaluated_frame": int(enemy.get("target_last_evaluated_frame", -1)),
			"target_switch_count": int(enemy.get("target_switch_count", 0)),
			"position": _vector3_to_dict(enemy.get("position", Vector3.ZERO)),
			"target": _serialize_target(target),
			"hp": int(enemy.get("hp", 0)),
			"max_hp": int(enemy.get("max_hp", 0)),
			"attack_power": float(enemy.get("attack_power", 0.0)),
			"defense": float(enemy.get("defense", 0.0)),
			"penetration": float(enemy.get("penetration", 0.0)),
			"attack_speed": float(enemy.get("attack_speed", 0.0)),
			"attack_cooldown": float(enemy.get("attack_cooldown", 0.0)),
			"configured_attack_windup": float(enemy.get("configured_attack_windup", 0.0)),
			"attack_windup": float(enemy.get("attack_windup", 0.0)),
			"attack_windup_remaining": float(enemy.get("attack_windup_remaining", 0.0)),
			"attack_windup_target": _serialize_target(
				enemy.get("attack_windup_target", {})
				if enemy.get("attack_windup_target", {}) is Dictionary
				else {}
			),
			"attack_sequence": int(enemy.get("attack_sequence", 0)),
			"attack_sequence_lock_remaining": maxf(
				0.0,
				float(enemy.get("attack_next_sequence_time", 0.0)) - _combat_timeline_seconds
			),
			"attack_cycle_phase": str(enemy.get("attack_cycle_phase", "idle")),
			"attack_cycle_elapsed": float(enemy.get("attack_cycle_elapsed", 0.0)),
			"attack_cycle_duration": float(enemy.get("attack_cycle_duration", 0.0)),
			"attack_impact_seconds": float(enemy.get("attack_impact_seconds", 0.0)),
			"attack_cycle_target": _serialize_target(
				enemy.get("attack_cycle_target", {})
				if enemy.get("attack_cycle_target", {}) is Dictionary
				else {}
			),
			"attack_impact_committed": bool(enemy.get("attack_impact_committed", false)),
			"attack_playback_multiplier": float(enemy.get("attack_playback_multiplier", 1.0)),
			"stagger_remaining": float(enemy.get("stagger_remaining", 0.0)),
			"stagger_count": int(enemy.get("stagger_count", 0)),
			"windup_interrupt_count": int(enemy.get("windup_interrupt_count", 0)),
			"last_stagger_result": enemy.get("last_stagger_result", {}).duplicate(true) if enemy.get("last_stagger_result", {}) is Dictionary else {},
			"damage_attack_interrupt_count": int(enemy.get("damage_attack_interrupt_count", 0)),
			"damage_windup_interrupt_count": int(enemy.get("damage_windup_interrupt_count", 0)),
			"last_damage_attack_interrupt": enemy.get("last_damage_attack_interrupt", {}).duplicate(true) if enemy.get("last_damage_attack_interrupt", {}) is Dictionary else {}
		})
	return result


func _serialize_target(target: Dictionary) -> Dictionary:
	if target.is_empty():
		return {}
	var result := target.duplicate(true)
	for field in ["position", "aim_position", "attack_position", "attack_contact_position", "contact_position", "queue_position", "target_position", "route_approach_position", "building_right_direction", "building_forward_direction", "facing_direction", "host_proxy_outward_direction"]:
		if result.has(field) and result[field] is Vector3:
			result[field] = _vector3_to_dict(result[field])
	return result


func _deserialize_target(target: Dictionary) -> Dictionary:
	if target.is_empty():
		return {}
	var result := target.duplicate(true)
	for field in ["position", "aim_position", "attack_position", "attack_contact_position", "contact_position", "queue_position", "target_position", "route_approach_position", "building_right_direction", "building_forward_direction", "facing_direction", "host_proxy_outward_direction"]:
		if result.has(field) and result[field] is Dictionary:
			result[field] = _vector3_from_dict(result[field], Vector3.ZERO)
	return result


func _serialize_rally(rally: Dictionary) -> Dictionary:
	if rally.is_empty():
		return {}
	var result := rally.duplicate(true)
	for field in ["position"]:
		if result.has(field) and result[field] is Vector3:
			result[field] = _vector3_to_dict(result[field])
	return result


func _serialize_avoidance(avoidance: Dictionary) -> Dictionary:
	if avoidance.is_empty():
		return {}
	var result := avoidance.duplicate(true)
	for field in ["target_position", "desired_target_position", "avoidance_direction"]:
		if result.has(field) and result[field] is Vector3:
			result[field] = _vector3_to_dict(result[field])
	var serialized_threats: Array[Dictionary] = []
	for raw_threat in result.get("threats", []):
		var threat := (raw_threat as Dictionary).duplicate(true)
		for field in ["position", "away_direction"]:
			if threat.has(field) and threat[field] is Vector3:
				threat[field] = _vector3_to_dict(threat[field])
		serialized_threats.append(threat)
	result["threats"] = serialized_threats
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
	if llm_bridge == null:
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
	var request_options := {
		"trigger": "low_hp",
		"reason": "low_hp",
		"related_event_id": str(low_hp_event.get("event_id", "")),
		"interaction_context": behavior_mode,
		"combat_context": combat_context,
		"battlefield_context": battlefield_context,
		"allowed_decisions": allowed_decisions
	}
	if llm_bridge.has_method("request_npc_battle_judgement_async"):
		return llm_bridge.request_npc_battle_judgement_async(npc_id, request_options)
	if llm_bridge.has_method("request_npc_battle_judgement"):
		return llm_bridge.request_npc_battle_judgement(npc_id, request_options)
	return {"ok": false, "error": "llm_bridge_method_missing", "message": "LLMBridge 缺少战时心理判定接口。"}


func _on_battle_judgement_async_response_received(result: Dictionary) -> void:
	var request_id := str(result.get("request_id", ""))
	if request_id.is_empty() or not _pending_low_hp_judgement_by_request.has(request_id):
		return
	var pending: Dictionary = _pending_low_hp_judgement_by_request.get(request_id, {})
	_pending_low_hp_judgement_by_request.erase(request_id)
	var npc_id := str(pending.get("npc_id", result.get("npc_id", "")))
	var apply_context: Dictionary = pending.get("context", {}) if pending.get("context", {}) is Dictionary else {}
	var expected_wave_id := str(apply_context.get("battle_wave_id", ""))
	if _active_battle.is_empty() or str(_active_battle.get("wave_id", "")) != expected_wave_id:
		_last_low_hp_judgement_result = {
			"ok": true,
			"triggered": true,
			"status": "discarded",
			"reason": "battle_ended_before_llm_response",
			"npc_id": npc_id,
			"request_id": request_id
		}
		return
	var expected_started_event_id := str(apply_context.get("battle_started_event_id", ""))
	if (
		not expected_started_event_id.is_empty()
		and str(_active_battle.get("started_event_id", "")) != expected_started_event_id
	):
		_last_low_hp_judgement_result = {
			"ok": true,
			"triggered": true,
			"status": "discarded",
			"reason": "battle_restarted_before_llm_response",
			"npc_id": npc_id,
			"request_id": request_id
		}
		return
	apply_context["llm_result"] = result.duplicate(true)
	var allowed_decisions: Array[String] = []
	for raw_decision in _normalize_string_array(apply_context.get("allowed_decisions", [])):
		if BATTLE_DECISIONS.has(raw_decision) and not allowed_decisions.has(raw_decision):
			allowed_decisions.append(raw_decision)
	var judgement: Dictionary = result.get("battle_judgement", {}) if result.get("battle_judgement", {}) is Dictionary else {}
	if not bool(result.get("ok", false)) or judgement.is_empty():
		judgement = _make_low_hp_rule_fallback_judgement(npc_id, allowed_decisions, result)
	_apply_low_hp_judgement_result(npc_id, judgement, apply_context)


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


func _get_low_hp_judgement_stale_reason(npc_id: String, context: Dictionary) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system == null
		or not npc_system.has_method("get_npc")
		or not npc_system.has_method("get_npc_state")
	):
		return "npc_system_missing"
	if (npc_system.get_npc(npc_id) as Dictionary).is_empty():
		return "npc_missing"
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var max_hp := maxi(1, int(state.get("max_hp", 100)))
	var hp := clampi(int(state.get("hp", max_hp)), 0, max_hp)
	if hp <= 0 or bool(state.get("unconscious", false)):
		return "npc_unconscious"
	if bool(state.get("escaped", false)):
		return "npc_already_escaped"
	if get_active_enemy_count() <= 0:
		return "no_active_enemies"
	if float(hp) / float(max_hp) >= LOW_HP_JUDGEMENT_RATIO:
		return "hp_recovered_above_threshold"
	if npc_system.has_method("can_npc_act") and not bool(npc_system.can_npc_act(npc_id)):
		return "npc_not_actionable"
	var expected_mode := str(context.get("behavior_mode", ""))
	var current_mode := _get_npc_behavior_mode(npc_system, npc_id)
	if not expected_mode.is_empty() and current_mode != expected_mode:
		return "behavior_mode_changed"
	var expected_combatant := bool(context.get("combatant_decisions_allowed", false))
	var current_combatant := current_mode == BEHAVIOR_MODE_COMBAT and _is_npc_combat_eligible(npc_id, npc_system)
	if current_combatant != expected_combatant:
		return "combat_eligibility_changed"
	return ""


func _apply_low_hp_judgement_result(npc_id: String, judgement: Dictionary, context: Dictionary) -> Dictionary:
	var stale_reason := _get_low_hp_judgement_stale_reason(npc_id, context)
	if not stale_reason.is_empty():
		var stale_llm_result: Dictionary = context.get("llm_result", {}) if context.get("llm_result", {}) is Dictionary else {}
		var stale_dialogue_result: Dictionary = context.get("dialogue_result", {}) if context.get("dialogue_result", {}) is Dictionary else {}
		_update_low_hp_judgement_for_active_battle(npc_id, {
			"status": "discarded",
			"discard_reason": stale_reason,
			"dialogue_result": stale_dialogue_result.duplicate(true),
			"llm_ok": bool(stale_llm_result.get("ok", false))
		})
		_last_low_hp_judgement_result = {
			"ok": true,
			"triggered": true,
			"status": "discarded",
			"reason": stale_reason,
			"npc_id": npc_id,
			"request_id": str(stale_llm_result.get("request_id", "")),
			"dialogue_result": stale_dialogue_result.duplicate(true),
			"llm_ok": bool(stale_llm_result.get("ok", false)),
			"rule_fallback": bool(judgement.get("rule_fallback", false))
		}
		return _last_low_hp_judgement_result.duplicate(true)
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
	var remaining_until_midnight := _get_game_seconds_until_midnight()
	var morale_state := {
		"active": true,
		"source_event_id": source_event_id,
		"duration_seconds": remaining_until_midnight,
		"remaining_game_seconds": remaining_until_midnight,
		"attack_bonus": MORALE_BOOST_ATTACK_BONUS,
		"move_speed_bonus": MORALE_BOOST_MOVE_SPEED_BONUS,
		"trigger": trigger,
		"started_day": int(time_snapshot.get("day", 1)),
		"started_time": str(time_snapshot.get("time", "00:00:00")),
		"expires_day": int(time_snapshot.get("day", 1)) + 1,
		"expires_time": "00:00:00"
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
	if (
		npc_system == null
		or not npc_system.has_method("get_npc_state")
		or not npc_system.has_method("update_npc_state")
	):
		return {"ok": false, "active_escape": false, "error": "npc_system_missing", "npc_id": npc_id}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var intent := _get_escape_intent_from_state(state)
	if not _is_escape_intent_resumable(intent):
		return {"ok": true, "applied": false, "active_escape": false, "reason": "no_active_escape", "npc_id": npc_id}
	if bool(state.get("escaped", false)):
		return {"ok": true, "applied": false, "active_escape": false, "reason": "already_escaped", "npc_id": npc_id}
	if bool(state.get("unconscious", false)):
		return {"ok": true, "applied": false, "active_escape": true, "reason": "still_unconscious", "npc_id": npc_id}
	if (
		not npc_system.has_method("set_npc_behavior_mode_and_move_to_world_position")
		or not npc_system.has_method("can_npc_move_to_world_position")
	):
		return _escape_failure("npc_system_missing_escape_api", "NPC 系统缺少逃离所需接口。", npc_id)
	intent["active"] = true
	intent["status"] = ESCAPE_STATUS_ESCAPING
	intent["resumed_day"] = int(_get_game_time_snapshot().get("day", 1))
	intent["resumed_time"] = str(_get_game_time_snapshot().get("time", "00:00:00"))
	var arrival_state := {
		"escape_finalize": true,
		"allow_escaping_movement": true,
		"escape_reason": "escape_completed",
		"escape_trigger": str(intent.get("trigger", "resume_after_revive")),
		"source_event_id": str(intent.get("source_event_id", "")),
		"exit_target_id": ESCAPE_TARGET_ID,
		"exit_target_name": ESCAPE_TARGET_NAME
	}
	if not bool(npc_system.can_npc_move_to_world_position(npc_id, arrival_state)):
		return _cancel_escape_resume_after_failure(
			npc_system,
			npc_id,
			intent,
			"movement_unavailable",
			"复苏 NPC 当前无法继续前往后门出口。",
			{}
		)
	var revive_exit_position := _get_escape_exit_position(npc_id, npc_system)
	intent["exit_position"] = _vector3_to_dict(revive_exit_position)
	var mode_result: Dictionary = npc_system.set_npc_behavior_mode_and_move_to_world_position(
		npc_id,
		BEHAVIOR_MODE_ESCAPED,
		"escape_resumed_after_revive",
		ESCAPE_TARGET_ID,
		ESCAPE_TARGET_NAME,
		revive_exit_position,
		arrival_state,
		{
			"interrupt": true,
			"stop_movement": true,
			"request_plan_reevaluation": false,
			"state_changes": {
				"escaped": false,
				"escape_intent": intent,
				"current_action": "escaping_station",
				"last_action_result": "escape_resumed_after_revive",
				"combat_target_enemy_id": "",
				"morale_boost": {}
			}
		}
	)
	if not bool(mode_result.get("ok", false)):
		return _cancel_escape_resume_after_failure(
			npc_system,
			npc_id,
			intent,
			"escape_transition_failed",
			"无法恢复逃离状态并继续移动。",
			{"mode_result": mode_result}
		)
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


func _cancel_escape_resume_after_failure(
	npc_system: Node,
	npc_id: String,
	intent: Dictionary,
	error_code: String,
	message: String,
	extra: Dictionary = {}
) -> Dictionary:
	var failed_intent := intent.duplicate(true)
	failed_intent["active"] = false
	failed_intent["status"] = ESCAPE_STATUS_RESUME_FAILED
	failed_intent["resume_failure_code"] = error_code
	failed_intent["resume_failure_day"] = int(_get_game_time_snapshot().get("day", 1))
	failed_intent["resume_failure_time"] = str(_get_game_time_snapshot().get("time", "00:00:00"))
	npc_system.update_npc_state(npc_id, {
		"escape_intent": failed_intent,
		"last_action_result": "escape_resume_failed"
	})
	_active_escapes.erase(npc_id)
	var failure_extra := extra.duplicate(true)
	failure_extra["active_escape"] = false
	failure_extra["escape_intent"] = failed_intent.duplicate(true)
	return _escape_failure(error_code, message, npc_id, failure_extra)


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
	snapshot["target_position"] = (
		(intent.get("exit_position", {}) as Dictionary).duplicate(true)
		if intent.get("exit_position", {}) is Dictionary
		else _vector3_to_dict(_get_escape_exit_position(npc_id, npc_system))
	)
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


func _normalize_escape_intervention_decision(intervention_result: String) -> String:
	if intervention_result == "stay":
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
			"intervention_result": str(response.get("escape_intervention_result", "")),
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
	previous_mode: String,
	escape_exit_position: Vector3
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
			"exit_position": _vector3_to_dict(escape_exit_position)
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
	var previous_position := enemy_node.global_position
	var is_formal_physical_actor := _formal_first_wave_slices.has(enemy_id) and enemy_node is ActorMotionBody
	if not is_formal_physical_actor:
		enemy_node.global_position = enemy.get("position", enemy_node.global_position)
	var movement_direction := enemy_node.global_position - previous_position
	var target: Dictionary = enemy.get("target", {}) if (enemy.get("target", {}) is Dictionary) else {}
	var presentation_signature := "%d|%s|%s|%s" % [
		int(enemy.get("hp", 0)),
		str(enemy.get("current_action", "")),
		str(target.get("type", "")),
		str(target.get("id", ""))
	]
	var art_view := enemy_node.get_node_or_null("EnemyArtView") as Node3D
	_update_enemy_art_facing(art_view, enemy, movement_direction)
	presentation_signature += "|%d|%s" % [
		int(enemy.get("attack_sequence", 0)),
		str(enemy.get("attack_cycle_phase", "idle"))
	]
	if is_formal_physical_actor and str(enemy_node.get_meta("enemy_refresh_signature", "")) == presentation_signature:
		return
	enemy_node.set_meta("enemy_refresh_signature", presentation_signature)
	var presentation_runtime: Dictionary = _formal_first_wave_slices.get(enemy_id, {})
	_apply_enemy_art_state(
		art_view,
		enemy,
		movement_direction,
		bool(presentation_runtime.get("presentation_movement_active", false)),
		float(presentation_runtime.get("presentation_cadence_speed", 0.0)),
		is_formal_physical_actor
	)
	var label := enemy_node.get_node_or_null("EnemyLabel") as Label3D
	if label != null:
		label.text = str(enemy.get("name", "敌人"))
	var bar := enemy_node.get_node_or_null("WorldHealthBar") as WorldHealthBar3D
	if bar != null:
		bar.set_health(int(enemy.get("hp", 0)), int(enemy.get("max_hp", 1)), true)


func _ensure_enemy_world_health_bar(enemy_node: Node3D, enemy: Dictionary, label: Label3D) -> void:
	if enemy_node == null:
		return
	var bar := enemy_node.get_node_or_null("WorldHealthBar") as WorldHealthBar3D
	if bar == null:
		bar = WORLD_HEALTH_BAR.new() as WorldHealthBar3D
		bar.name = "WorldHealthBar"
		enemy_node.add_child(bar)
		bar.configure_size(1.35, 0.12)
		bar.configure_fill_colors(ENEMY_WORLD_HEALTH_COLOR, ENEMY_WORLD_HEALTH_COLOR)
	bar.position = (label.position if label != null else Vector3(0.0, ENEMY_NAME_LABEL_HEIGHT, 0.0)) + Vector3(0.0, ENEMY_HEALTH_BAR_OFFSET, 0.0)
	bar.set_health(int(enemy.get("hp", 0)), int(enemy.get("max_hp", 1)), true)


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


func _advance_wave_schedule(game_delta_seconds: float) -> void:
	if game_delta_seconds <= 0.0:
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and bool(game_state.get("game_over")):
		return
	var next_wave := _get_next_pending_wave()
	if next_wave.is_empty():
		return
	var current_seconds := _get_current_absolute_seconds()
	var next_tick_seconds := current_seconds + maxf(0.0, game_delta_seconds)
	var trigger_seconds := _get_wave_trigger_absolute_seconds(next_wave)
	if next_tick_seconds < trigger_seconds:
		return
	var wave_number := int(next_wave.get("wave_number", 0))
	var result := spawn_wave(wave_number, false, "scheduled_wave")
	result["trigger_absolute_seconds"] = trigger_seconds
	result["current_absolute_seconds"] = current_seconds
	result["next_tick_absolute_seconds"] = next_tick_seconds
	if bool(result.get("ok", false)):
		_mark_wave_triggered(wave_number)
		result["triggered_wave_numbers"] = _triggered_wave_numbers.duplicate()
		result["next_wave_after"] = get_wave_schedule_snapshot().get("next_wave", {})
	_last_auto_wave_result = result.duplicate(true)


func _get_next_pending_wave() -> Dictionary:
	for wave in _waves:
		var wave_number := int(wave.get("wave_number", 0))
		if _triggered_wave_numbers.has(wave_number):
			continue
		return wave.duplicate(true)
	return {}


func _mark_wave_triggered(wave_number: int) -> void:
	if wave_number <= 0 or _triggered_wave_numbers.has(wave_number):
		return
	_triggered_wave_numbers.append(wave_number)
	_triggered_wave_numbers.sort()


func _get_wave_trigger_absolute_seconds(wave: Dictionary) -> float:
	var day := maxi(1, int(wave.get("trigger_day", 1)))
	var hour := clampi(int(wave.get("trigger_hour", 0)), 0, 23)
	var minute := clampi(int(wave.get("trigger_minute", 0)), 0, 59)
	var second := clampi(int(wave.get("trigger_second", 0)), 0, 59)
	return float((day - 1) * 86400 + hour * 3600 + minute * 60 + second)


func _get_current_absolute_seconds() -> float:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return 0.0
	return float(
		maxi(1, int(game_state.get("current_day"))) - 1
	) * 86400.0 + float(
		clampi(int(game_state.get("current_hour")), 0, 23) * 3600
		+ clampi(int(game_state.get("current_minute")), 0, 59) * 60
		+ clampi(int(game_state.get("current_second")), 0, 59)
	)


func _get_wave_enemy_count(wave: Dictionary) -> int:
	var total := 0
	var enemies: Array = wave.get("enemies", [])
	for raw_enemy in enemies:
		var enemy: Dictionary = raw_enemy if raw_enemy is Dictionary else {}
		total += maxi(0, int(enemy.get("count", 0)))
	return total


func _get_combat_action_seconds(game_delta_seconds: float) -> float:
	return maxf(0.0, game_delta_seconds)


func _sync_enemy_presence_time_slowdown(reason: String) -> Dictionary:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	var should_slow_down := not _active_enemies.is_empty()
	var active_enemy_count := get_active_enemy_count()
	var result := {
		"ok": false,
		"request_id": COMBAT_TIME_SLOWDOWN_REQUEST_ID,
		"slowdown_scale": COMBAT_TIME_SLOWDOWN_SCALE,
		"active_enemy_count": active_enemy_count,
		"slowdown_expected": should_slow_down,
		"reason": reason
	}
	if time_system == null:
		result["error"] = "time_system_missing"
		return result

	if should_slow_down:
		if time_system.has_method("request_time_slowdown"):
			time_system.request_time_slowdown(
				COMBAT_TIME_SLOWDOWN_REQUEST_ID,
				COMBAT_TIME_SLOWDOWN_SCALE,
				"combat_enemy_presence"
			)
			result["ok"] = true
			result["action"] = "slowdown_requested"
		else:
			result["error"] = "time_slowdown_api_missing"
	else:
		if time_system.has_method("release_time_slowdown"):
			time_system.release_time_slowdown(COMBAT_TIME_SLOWDOWN_REQUEST_ID)
			result["ok"] = true
			result["action"] = "slowdown_released"
		else:
			result["error"] = "time_slowdown_api_missing"
	if active_enemy_count != _last_emitted_enemy_presence_count:
		_last_emitted_enemy_presence_count = active_enemy_count
		var event_bus := get_node_or_null("/root/EventBus")
		if event_bus != null and event_bus.has_signal("combat_enemy_presence_changed"):
			event_bus.combat_enemy_presence_changed.emit(
				should_slow_down,
				active_enemy_count,
				reason
			)
	result["time_scale"] = _get_time_scale_snapshot()
	return result


func _emit_combat_audio_event(event: Dictionary) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("combat_audio_event"):
		event_bus.combat_audio_event.emit(event.duplicate(true))


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


func _get_game_seconds_until_midnight() -> float:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return MORALE_BOOST_DURATION_SECONDS
	var elapsed_today := (
		clampi(int(game_state.current_hour), 0, 23) * 3600
		+ clampi(int(game_state.current_minute), 0, 59) * 60
		+ clampi(int(game_state.current_second), 0, 59)
	)
	return maxf(1.0, MORALE_BOOST_DURATION_SECONDS - float(elapsed_today))


func _extract_enemy_ids(enemies: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for enemy in enemies:
		result.append(str(enemy.get("id", "")))
	return result


func debug_get_enemy_art_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for enemy_id in get_active_enemy_ids():
		var enemy: Dictionary = _active_enemies.get(enemy_id, {})
		var enemy_node := get_node_or_null(_enemy_nodes.get(enemy_id, NodePath())) if _enemy_nodes.has(enemy_id) else null
		var art_view := enemy_node.get_node_or_null("EnemyArtView") if enemy_node != null else null
		var art_snapshot: Dictionary = art_view.debug_get_snapshot() if art_view != null and art_view.has_method("debug_get_snapshot") else {}
		var presentation_runtime: Dictionary = _formal_first_wave_slices.get(enemy_id, {})
		snapshots.append({
			"enemy_id": enemy_id,
			"enemy_type_id": str(enemy.get("enemy_type_id", "")),
			"unit_type": str(enemy.get("unit_type", "")),
			"weapon_type": str(enemy.get("weapon_type", "")),
			"mount_type": str(enemy.get("mount_type", "")),
			"current_action": str(enemy.get("current_action", "")),
			"attack_sequence": int(enemy.get("attack_sequence", 0)),
			"attack_phase": str(enemy.get("attack_cycle_phase", "idle")),
			"attack_elapsed_seconds": float(enemy.get("attack_cycle_elapsed", 0.0)),
			"attack_cycle_seconds": float(enemy.get("attack_cycle_duration", 0.0)),
			"attack_impact_seconds": float(enemy.get("attack_impact_seconds", 0.0)),
			"attack_playback_multiplier": float(enemy.get("attack_playback_multiplier", 1.0)),
			"presentation_motion_source": "actual_planar_displacement" if not presentation_runtime.is_empty() else "action_fallback",
			"presentation_planar_speed": float(presentation_runtime.get("presentation_planar_speed", 0.0)),
			"presentation_movement_active": bool(presentation_runtime.get("presentation_movement_active", false)),
			"presentation_stationary_seconds": float(presentation_runtime.get("presentation_stationary_seconds", 0.0)),
			"actor_motion_active": bool(presentation_runtime.get("presentation_actor_motion_active", false)),
			"art_family": str(enemy_node.get_meta("enemy_art_family", "capsule")) if enemy_node != null else "missing",
			"art": art_snapshot,
		})
	return snapshots


func get_enemy_audio_motion_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for enemy_id in get_active_enemy_ids():
		var enemy: Dictionary = _active_enemies.get(enemy_id, {})
		var runtime: Dictionary = _formal_first_wave_slices.get(enemy_id, {})
		var raw_position: Variant = get_enemy_world_position(enemy_id)
		if not raw_position is Vector3:
			continue
		snapshots.append({
			"enemy_id": enemy_id,
			"mounted": str(enemy.get("unit_type", "")) in ["cavalry", "mounted_ranged"],
			"movement_active": bool(runtime.get("presentation_movement_active", false)),
			"actual_horizontal_speed": float(runtime.get("presentation_planar_speed", 0.0)),
			"world_position": raw_position,
		})
	return snapshots


func debug_get_enemy_mounted_defeat_snapshots() -> Dictionary:
	var active_presentations: Array[Dictionary] = []
	for raw_node in get_tree().get_nodes_in_group("enemy_mounted_art"):
		var mounted_art := raw_node as Node
		if mounted_art != null and mounted_art.has_method("debug_get_snapshot"):
			var snapshot: Dictionary = mounted_art.debug_get_snapshot()
			if str(snapshot.get("defeat_phase", "")) != "mounted":
				active_presentations.append(snapshot)
	return {
		"active": active_presentations,
		"last_completed": _last_enemy_mounted_defeat_cleanup_result.duplicate(true)
	}


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
