extends Node

signal tutorial_started(snapshot: Dictionary)
signal tutorial_step_changed(step_id: String, snapshot: Dictionary)
signal tutorial_finished(snapshot: Dictionary)
signal tutorial_music_cue_changed(cue: String)

const TUTORIAL_CONFIG_FILE := "tutorial_config.json"
const TUTORIAL_DAY1_PLANS_FILE := "tutorial_day1_plans.json"
const DETACHED_SIMULATION_REQUEST_ID := "tutorial_prologue_presentation"
const ADA_CAMERA_LOCK_REQUEST_ID := "tutorial_ada_rally_follow"

const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const DEFENSE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const DAILY_PLAN_SYSTEM_PATH := "/root/Main/Systems/DailyPlanSystem"
const STATION_LAYOUT_CONTROLLER_PATH := "/root/Main/Presentation/StationLayoutController"
const DEFENSE_PRESENTER_PATH := "/root/Main/UI/DefenseSlotPresenter"
const NPC_PANEL_PATH := "/root/Main/UI/NPCPanel"
const ALARM_BUTTON_PATH := "/root/Main/UI/HUD/AlarmButton"
const TUTORIAL_OVERLAY_PATH := "/root/Main/UI/TutorialOverlay"
const CAMERA_RIG_PATH := "/root/Main/CameraRig"

const STEP_INTRO := "intro"
const STEP_BATTLEFIELD_EXPLAIN := "battlefield_explain"
const STEP_SELECT_SLOT := "select_slot"
const STEP_SELECT_DEVICE := "select_device"
const STEP_CAMERA_CONTROLS := "camera_controls"
const STEP_WAIT_TOWER := "wait_tower"
const STEP_TOWER_DESTROYED := "tower_destroyed"
const STEP_SELECT_ADA := "select_ada"
const STEP_EQUIPMENT_BUTTON := "equipment_button"
const STEP_MAIN_WEAPON := "main_weapon"
const STEP_SWORD_SHIELD := "sword_shield"
const STEP_EQUIP_SHOWCASE := "equip_showcase"
const STEP_ALARM := "alarm"
const STEP_BATTLE := "battle"
const STEP_BATTLE_HEALTH := "battle_health"
const STEP_VICTORY := "victory"
const STEP_POST_BATTLE := "post_battle"
const STEP_ADA_RETURN := "ada_return"
const STEP_HANDOFF_CARD := "handoff_card"
const STEP_FINISHED := "finished"
const EQUIPMENT_GESTURE_STEPS := [
	STEP_SELECT_ADA,
	STEP_EQUIPMENT_BUTTON,
	STEP_MAIN_WEAPON,
	STEP_SWORD_SHIELD
]

var _config: Dictionary = {}
var _day1_plan_config: Dictionary = {}
var _step_id := "idle"
var _intro_index := 0
var _post_battle_index := 0
var _step_elapsed := 0.0
var _step_started_msec := 0
var _idle_elapsed := 0.0
var _battle_elapsed := 0.0
var _active := false
var _handoff_in_progress := false
var _detached_simulation_running := false
var _tower_was_deployed := false
var _health_hint_shown := false
var _normal_completion := false
var _last_target_id := ""
var _preparation_snapshot: Dictionary = {}
var _handoff_snapshot: Dictionary = {}
var _recovery_snapshot: Dictionary = {}
var _phase_metrics: Dictionary = {}
var _last_error: Dictionary = {}
var _camera_zoom_before_ada_focus := -1.0
var _ada_equipment_gesture_remaining := 0.0
var _ada_equipment_gesture_count := 0
var _ada_equipment_gesture_last_result: Dictionary = {}
var _ada_camera_follow_active := false
var _ada_camera_follow_zoom := -1.0
var _ada_camera_follow_release_reason := ""
var _tutorial_music_cue := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := get_node_or_null(TUTORIAL_OVERLAY_PATH)
	if overlay != null:
		if overlay.has_signal("continue_requested"):
			overlay.continue_requested.connect(_on_continue_requested)
		if overlay.has_signal("target_pressed"):
			overlay.target_pressed.connect(_on_target_pressed)
		if overlay.has_signal("inspection_requested"):
			overlay.inspection_requested.connect(_on_inspection_requested)
		if overlay.has_signal("skip_confirmed"):
			overlay.skip_confirmed.connect(debug_skip_tutorial)
		if overlay.has_signal("victory_acknowledged"):
			overlay.victory_acknowledged.connect(_on_victory_acknowledged)
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system != null and combat_system.has_signal("tutorial_raid_finished"):
		combat_system.tutorial_raid_finished.connect(_on_tutorial_raid_finished)
	var npc_panel := get_node_or_null(NPC_PANEL_PATH)
	if npc_panel != null:
		if npc_panel.has_signal("equipment_window_visibility_changed"):
			npc_panel.equipment_window_visibility_changed.connect(_on_equipment_window_visibility_changed)
		if npc_panel.has_signal("equipment_slot_picker_opened"):
			npc_panel.equipment_slot_picker_opened.connect(_on_equipment_slot_picker_opened)
		if npc_panel.has_signal("equipment_item_applied"):
			npc_panel.equipment_item_applied.connect(_on_equipment_item_applied)
	set_process(true)
	set_physics_process(true)


func _process(delta: float) -> void:
	if not _active or _handoff_in_progress:
		return
	_step_elapsed += delta
	_idle_elapsed += delta
	_update_ada_equipment_gesture(delta)
	_update_ada_camera_follow(delta)
	_refresh_target_focus()
	_refresh_inspection_targets()
	if _step_id in [STEP_EQUIPMENT_BUTTON, STEP_MAIN_WEAPON, STEP_SWORD_SHIELD]:
		_reconcile_equipment_progress()
	var overlay := get_node_or_null(TUTORIAL_OVERLAY_PATH)
	var hint_seconds := maxf(1.0, float(_config.get("idle_hint_seconds", 8.0)))
	if overlay != null and overlay.has_method("set_target_pulse_strength"):
		overlay.set_target_pulse_strength(2.2 if _idle_elapsed >= hint_seconds else 1.0)
	var recenter_seconds := maxf(2.0, float(_config.get("camera_recenter_seconds", 20.0)))
	if _idle_elapsed >= recenter_seconds:
		_recenter_current_target()
		_idle_elapsed = hint_seconds

	match _step_id:
		STEP_WAIT_TOWER:
			_check_tower_destroyed()
			if (
				_step_id == STEP_WAIT_TOWER
				and _step_elapsed >= maxf(5.0, float(_config.get("tower_phase_max_duration_seconds", 25.0)))
			):
				_recover_stalled_tower_phase()
		STEP_EQUIP_SHOWCASE:
			if _step_elapsed >= 1.0:
				_close_npc_panel()
				_enter_step(STEP_ALARM)
		STEP_BATTLE:
			_battle_elapsed += delta
			_check_battle_progress()
		STEP_BATTLE_HEALTH:
			_battle_elapsed += delta
			_check_battle_progress()
		STEP_ADA_RETURN:
			_check_ada_return_progress()
		STEP_HANDOFF_CARD:
			if _get_effective_step_elapsed() >= maxf(0.1, float(_config.get("handoff_card_duration_seconds", 5.0))):
				_complete_handoff(false)


func _physics_process(delta: float) -> void:
	if not _active or not _detached_simulation_running or delta <= 0.0:
		return
	var defense_system := get_node_or_null(DEFENSE_SYSTEM_PATH)
	if defense_system != null and defense_system.has_method("advance_detached_tutorial_tick"):
		defense_system.advance_detached_tutorial_tick(delta)
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system != null and combat_system.has_method("advance_detached_tutorial_tick"):
		combat_system.advance_detached_tutorial_tick(delta)


func begin_tutorial() -> Dictionary:
	if _active:
		return {
			"ok": true,
			"changed": false,
			"reason": "tutorial_already_active",
			"snapshot": get_tutorial_snapshot()
		}
	var load_result := _load_and_validate_config()
	if not bool(load_result.get("ok", false)):
		_fail_tutorial(str(load_result.get("reason", "tutorial_config_invalid")), str(load_result.get("message", "序章配置无效。")))
		return get_tutorial_snapshot()
	var overlay := get_node_or_null(TUTORIAL_OVERLAY_PATH)
	if overlay == null or not overlay.has_method("begin"):
		_fail_tutorial("tutorial_overlay_missing", "序章 UI 不可用。")
		return get_tutorial_snapshot()

	_active = true
	_handoff_in_progress = false
	_normal_completion = false
	_health_hint_shown = false
	_tower_was_deployed = false
	_camera_zoom_before_ada_focus = -1.0
	_ada_equipment_gesture_remaining = 0.0
	_ada_equipment_gesture_count = 0
	_ada_equipment_gesture_last_result.clear()
	_ada_camera_follow_active = false
	_ada_camera_follow_zoom = -1.0
	_ada_camera_follow_release_reason = ""
	_set_tutorial_music_cue("tutorial_intro")
	_recovery_snapshot.clear()
	_phase_metrics.clear()
	_preparation_snapshot = _prepare_tutorial_world()
	if not bool(_preparation_snapshot.get("ok", false)):
		_fail_tutorial(
			str(_preparation_snapshot.get("reason", "tutorial_preparation_failed")),
			str(_preparation_snapshot.get("message", "无法准备序章场景。"))
		)
		return get_tutorial_snapshot()
	if overlay.has_method("configure_copy"):
		var ui_copy: Dictionary = _config.get("ui_copy", {}) if _config.get("ui_copy", {}) is Dictionary else {}
		overlay.configure_copy(ui_copy)
	overlay.begin()
	_intro_index = 0
	_enter_step(STEP_INTRO)
	var snapshot := get_tutorial_snapshot()
	tutorial_started.emit(snapshot)
	return {"ok": true, "changed": true, "snapshot": snapshot}


func debug_skip_tutorial() -> Dictionary:
	if not _handoff_snapshot.is_empty():
		return _handoff_snapshot.duplicate(true)
	if _handoff_in_progress:
		return get_tutorial_snapshot()
	if not _active:
		var load_result := _load_and_validate_config()
		if not bool(load_result.get("ok", false)):
			return load_result
		_active = true
	return _complete_handoff(true)


func debug_restart_tutorial() -> Dictionary:
	if _active or _handoff_in_progress:
		_complete_handoff(true)
	_active = false
	_handoff_in_progress = false
	_handoff_snapshot.clear()
	_recovery_snapshot.clear()
	_phase_metrics.clear()
	_last_error.clear()
	return begin_tutorial()


func debug_press_current_target() -> Dictionary:
	if _last_target_id.is_empty():
		return {"ok": false, "reason": "tutorial_target_missing", "step_id": _step_id}
	_on_target_pressed(_last_target_id)
	return get_tutorial_snapshot()


func debug_continue() -> Dictionary:
	_on_continue_requested()
	return get_tutorial_snapshot()


func debug_finish_tutorial_battle() -> Dictionary:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("force_finish_tutorial_raid"):
		return {"ok": false, "reason": "combat_system_missing"}
	return combat_system.force_finish_tutorial_raid("tutorial_debug_finish")


func debug_acknowledge_victory() -> Dictionary:
	_on_victory_acknowledged()
	return get_tutorial_snapshot()


func debug_finish_ada_return() -> Dictionary:
	if _step_id != STEP_ADA_RETURN:
		return {"ok": false, "reason": "ada_return_not_active", "step_id": _step_id}
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var ada_npc_id := str(_config.get("ada_npc_id", "veteran_deputy_01"))
	if action_system != null and npc_system != null:
		_set_detached_simulation(false)
		_stage_npc_at_dormitory_bed(npc_system, action_system, ada_npc_id)
	_step_elapsed = 8.0
	_check_ada_return_progress()
	return get_tutorial_snapshot()


func debug_complete_handoff_card() -> Dictionary:
	if _step_id != STEP_HANDOFF_CARD:
		return {"ok": false, "reason": "handoff_card_not_active", "step_id": _step_id}
	return _complete_handoff(false)


func get_tutorial_snapshot() -> Dictionary:
	var combat_snapshot := {}
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system != null and combat_system.has_method("get_tutorial_raid_snapshot"):
		combat_snapshot = combat_system.get_tutorial_raid_snapshot()
	var overlay_snapshot := {}
	var overlay := get_node_or_null(TUTORIAL_OVERLAY_PATH)
	if overlay != null and overlay.has_method("get_debug_snapshot"):
		overlay_snapshot = overlay.get_debug_snapshot()
	return {
		"ok": _last_error.is_empty(),
		"active": _active,
		"handoff_in_progress": _handoff_in_progress,
		"step_id": _step_id,
		"intro_index": _intro_index,
		"post_battle_index": _post_battle_index,
		"tutorial_music_cue": _tutorial_music_cue,
		"step_elapsed": _step_elapsed,
		"handoff_card_duration_seconds": float(_config.get("handoff_card_duration_seconds", 5.0)),
		"battle_elapsed": _battle_elapsed,
		"detached_simulation_running": _detached_simulation_running,
		"tower_was_deployed": _tower_was_deployed,
		"health_hint_shown": _health_hint_shown,
		"normal_completion": _normal_completion,
		"ada_equipment_gesture": {
			"active": _active and _step_id in EQUIPMENT_GESTURE_STEPS,
			"remaining_seconds": _ada_equipment_gesture_remaining,
			"play_count": _ada_equipment_gesture_count,
			"last_result": _ada_equipment_gesture_last_result.duplicate(true)
		},
		"ada_camera_follow": {
			"active": _ada_camera_follow_active,
			"locked_zoom_distance": _ada_camera_follow_zoom,
			"release_reason": _ada_camera_follow_release_reason
		},
		"preparation": _preparation_snapshot.duplicate(true),
		"combat": combat_snapshot,
		"overlay": overlay_snapshot,
		"recovery": _recovery_snapshot.duplicate(true),
		"phase_metrics": _phase_metrics.duplicate(true),
		"handoff": _handoff_snapshot.duplicate(true),
		"error": _last_error.duplicate(true)
	}


func _load_and_validate_config() -> Dictionary:
	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null or not config_loader.has_method("load_data_file"):
		return {"ok": false, "reason": "config_loader_missing", "message": "ConfigLoader 不可用。"}
	var loaded_config: Variant = config_loader.load_data_file(TUTORIAL_CONFIG_FILE, {})
	var loaded_plans: Variant = config_loader.load_data_file(TUTORIAL_DAY1_PLANS_FILE, {})
	if not loaded_config is Dictionary or str((loaded_config as Dictionary).get("schema_version", "")) != "tutorial_prologue_v1":
		return {"ok": false, "reason": "tutorial_config_invalid", "message": "序章配置 Schema 无效。"}
	if not loaded_plans is Dictionary or str((loaded_plans as Dictionary).get("schema_version", "")) != "tutorial_day1_plans_v2":
		return {"ok": false, "reason": "tutorial_day1_plans_invalid", "message": "序章第一日计划 Schema 无效。"}
	_config = (loaded_config as Dictionary).duplicate(true)
	_day1_plan_config = (loaded_plans as Dictionary).duplicate(true)
	var intro_pages: Array = _config.get("intro_pages", []) if _config.get("intro_pages", []) is Array else []
	var post_pages: Array = _config.get("post_battle_pages", []) if _config.get("post_battle_pages", []) is Array else []
	if intro_pages.is_empty() or post_pages.is_empty():
		return {"ok": false, "reason": "tutorial_dialogue_missing", "message": "序章剧情页为空。"}
	var music_config: Dictionary = _config.get("tutorial_music", {}) if _config.get("tutorial_music", {}) is Dictionary else {}
	var battle_start_page_id := str(music_config.get("battle_start_intro_page_id", "intro_ada_warning"))
	if not intro_pages.any(func(page: Variant) -> bool: return page is Dictionary and str((page as Dictionary).get("id", "")) == battle_start_page_id):
		return {"ok": false, "reason": "tutorial_music_cue_page_missing", "message": "序章战斗音乐切入页不存在。"}
	var plans: Dictionary = _day1_plan_config.get("plans", {}) if _day1_plan_config.get("plans", {}) is Dictionary else {}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return {"ok": false, "reason": "npc_system_missing", "message": "NPCSystem 不可用。"}
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var actions: Array = plans.get(npc_id, []) if plans.get(npc_id, []) is Array else []
		if actions.size() != 24:
			return {"ok": false, "reason": "tutorial_plan_incomplete", "message": "%s 缺少 24 小时预设计划。" % npc_id}
		for raw_entry in actions:
			var action_id := _tutorial_plan_entry_action_id(raw_entry)
			if action_id.is_empty():
				return {"ok": false, "reason": "tutorial_plan_action_invalid", "message": "%s 存在无效的预设行动。" % npc_id}
			if action_id in ["talk_to_npc", "visit_location"] and _tutorial_plan_entry_target_id(raw_entry).is_empty():
				return {"ok": false, "reason": "tutorial_plan_target_missing", "message": "%s 的目标行动缺少目标。" % npc_id}
	return {"ok": true}


func _prepare_tutorial_world() -> Dictionary:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	var defense_system := get_node_or_null(DEFENSE_SYSTEM_PATH)
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var daily_plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if (
		time_system == null or resource_system == null or npc_system == null
		or action_system == null or memory_system == null or equipment_system == null
		or defense_system == null or combat_system == null or daily_plan_system == null
	):
		return {"ok": false, "reason": "tutorial_dependencies_missing", "message": "序章依赖系统不完整。"}

	daily_plan_system.set_auto_execution_enabled(false)
	time_system.set_paused(true)
	var tutorial_clock: Dictionary = _config.get("tutorial_clock", {})
	time_system.set_current_time(
		int(tutorial_clock.get("day", 1)),
		int(tutorial_clock.get("hour", 1)),
		int(tutorial_clock.get("minute", 0)),
		0
	)
	combat_system.end_tutorial_raid("tutorial_prepare")
	resource_system.initialize()
	defense_system.initialize()
	_bind_formal_defense_slots(defense_system)
	equipment_system.initialize()
	equipment_system.set_tutorial_event_suppression(true)
	defense_system.set_tutorial_event_suppression(true)

	var ada_npc_id := str(_config.get("ada_npc_id", "veteran_deputy_01"))
	var restore_result: Dictionary = equipment_system.restore_npc_initial_equipment(ada_npc_id)
	var stage_result: Dictionary = equipment_system.stage_npc_main_weapon_for_tutorial(ada_npc_id)
	if not bool(restore_result.get("ok", false)) or not bool(stage_result.get("ok", false)):
		return {"ok": false, "reason": "tutorial_weapon_stage_failed", "message": "艾达的教程剑盾准备失败。", "restore": restore_result, "stage": stage_result}
	var inventory_results := {}
	for raw_resource_id in (_config.get("temporary_inventory", {}) as Dictionary).keys():
		var resource_id := str(raw_resource_id)
		var amount := int((_config.get("temporary_inventory", {}) as Dictionary).get(raw_resource_id, 0))
		inventory_results[resource_id] = resource_system.add_resource(resource_id, amount)
		if not bool(inventory_results[resource_id]):
			return {"ok": false, "reason": "tutorial_inventory_failed", "message": "教程临时库存准备失败：%s" % resource_id}

	var placements := {}
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		if action_system.has_method("interrupt_npc_action"):
			action_system.interrupt_npc_action(npc_id, "tutorial_prepare", true)
		var location_id := "plaza" if npc_id == ada_npc_id else "dormitory"
		var placed := false
		var sleeping := false
		var sleep_stage_result: Dictionary = {}
		if npc_id != ada_npc_id:
			sleep_stage_result = action_system.stage_npc_sleep_for_tutorial(npc_id)
			placed = bool(sleep_stage_result.get("ok", false))
			sleeping = bool(sleep_stage_result.get("sleeping", false))
		else:
			placed = bool(npc_system.debug_enter_location_immediately(npc_id, location_id))
			npc_system.update_npc_state(npc_id, {
				"current_action": "idle",
				"behavior_mode": "work",
				"combat_mode": "",
				"unconscious": false
			})
		placements[npc_id] = {
			"location_id": location_id,
			"placed": placed,
			"sleeping": sleeping,
			"sleep_stage_result": sleep_stage_result
		}
		if not placed or (npc_id != ada_npc_id and not sleeping):
			return {
				"ok": false,
				"reason": "tutorial_npc_placement_failed",
				"message": "%s 的序章初始位置准备失败。" % npc_id,
				"npc_id": npc_id,
				"placement": placements[npc_id]
			}

	# Placement is one atomic piece of tutorial staging. Clearing an NPC inside
	# the loop lets an earlier NPC witness later members leaving the plaza.
	# Reset everyone only after every bed/location transition has completed.
	var initial_memory_reset := {}
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var clear_result: Dictionary = memory_system.clear_npc_short_term_memory(npc_id)
		initial_memory_reset[npc_id] = clear_result
		if not bool(clear_result.get("ok", false)):
			return {
				"ok": false,
				"reason": "tutorial_initial_memory_reset_failed",
				"message": "%s 的序章初始记忆清理失败。" % npc_id,
				"npc_id": npc_id,
				"memory_reset": clear_result
			}

	var raid_config: Dictionary = (_config.get("tutorial_raid", {}) as Dictionary).duplicate(true)
	raid_config["ada_npc_id"] = ada_npc_id
	var raid_result: Dictionary = combat_system.start_tutorial_raid(raid_config)
	if not bool(raid_result.get("ok", false)):
		return {"ok": false, "reason": "tutorial_raid_spawn_failed", "message": "序章敌人生成失败。", "raid_result": raid_result}
	var ada_facing_direction := _get_config_vector3("ada_initial_facing_direction", Vector3(0.0, 0.0, 1.0))
	var ada_facing_applied: bool = bool(npc_system.snap_npc_facing_direction(ada_npc_id, ada_facing_direction))
	return {
		"ok": true,
		"clock": tutorial_clock.duplicate(true),
		"ada_npc_id": ada_npc_id,
		"equipment_restore": restore_result,
		"weapon_stage": stage_result,
		"temporary_inventory": inventory_results,
		"placements": placements,
		"initial_memory_reset": initial_memory_reset,
		"ada_facing_direction": ada_facing_direction,
		"ada_facing_applied": ada_facing_applied,
		"raid": raid_result
	}


func _enter_step(step_id: String) -> void:
	if step_id not in EQUIPMENT_GESTURE_STEPS:
		_ada_equipment_gesture_remaining = 0.0
	if step_id not in [STEP_BATTLE, STEP_BATTLE_HEALTH] and _ada_camera_follow_active:
		_end_ada_camera_follow("tutorial_step_changed:%s" % step_id)
	_step_id = step_id
	_step_elapsed = 0.0
	_step_started_msec = Time.get_ticks_msec()
	_idle_elapsed = 0.0
	_last_target_id = ""
	var overlay := get_node_or_null(TUTORIAL_OVERLAY_PATH)
	if overlay == null:
		return
	if overlay.has_method("set_world_mouse_input_passthrough"):
		overlay.set_world_mouse_input_passthrough(step_id == STEP_CAMERA_CONTROLS)
	if overlay.has_method("set_inspection_targets"):
		overlay.set_inspection_targets([])
	match step_id:
		STEP_INTRO:
			var pages: Array = _config.get("intro_pages", [])
			_sync_tutorial_music_for_intro_page(pages[_intro_index])
			overlay.show_page(pages[_intro_index], true)
		STEP_BATTLEFIELD_EXPLAIN:
			_set_tutorial_music_cue("tutorial_battle")
			_set_detached_simulation(true)
			_show_step_copy(overlay, step_id, "敌人正在来袭。若他们闯入驿站并摧毁主厅，防守就会失败。", "凌晨 01:00 · 北门遭遇敌袭", true)
			call_deferred("_focus_gate_for_tutorial")
		STEP_SELECT_SLOT:
			_show_step_copy(overlay, step_id, "在城墙上部署箭塔，可以拖延敌人的进攻。点击高亮的城墙器械槽。", "部署箭塔：选择城墙槽位")
			_last_target_id = "slot:%s" % str(_config.get("target_slot_id", "wall_slot_01"))
			call_deferred("_focus_gate_for_tutorial")
		STEP_SELECT_DEVICE:
			_show_step_copy(overlay, step_id, "军械库里有一座箭塔。点击箭塔，将它部署到城墙上。", "部署箭塔：选择箭塔")
			_last_target_id = "device:%s" % str(_config.get("tutorial_device_id", "wall_arrow_tower"))
		STEP_CAMERA_CONTROLS:
			_show_step_copy(overlay, step_id, "WASD 或按住鼠标中键移动镜头，滚轮缩放镜头。", "镜头操作", true)
		STEP_WAIT_TOWER:
			_show_step_copy(overlay, step_id, "箭塔会自动索敌和攻击，但箭塔也会被敌人摧毁。先观察战况。", "观察箭塔拖延敌军")
			overlay.hide_conversation()
		STEP_TOWER_DESTROYED:
			_show_step_copy(overlay, step_id, "箭塔被摧毁了，但它为守备争取了时间。接下来需要让成员亲自接敌。", "为艾达配备武器", true)
		STEP_SELECT_ADA:
			_show_step_copy(overlay, step_id, "只有配备武器的驿站成员才能参与防守。点击主厅前等待的艾达。", "为艾达配备武器")
			_last_target_id = "ada"
			call_deferred("_focus_ada_for_selection")
			call_deferred("_play_ada_equipment_gesture")
		STEP_EQUIPMENT_BUTTON:
			_show_step_copy(overlay, step_id, "打开人物面板中的“装备”。", "为艾达配备武器")
			_last_target_id = "equipment_button"
		STEP_MAIN_WEAPON:
			_show_step_copy(overlay, step_id, "选择主武器槽。", "为艾达配备武器")
			_last_target_id = "main_weapon_slot"
		STEP_SWORD_SHIELD:
			_show_step_copy(overlay, step_id, "军械库里有一套剑盾。点击剑盾，为艾达装备主武器。", "为艾达配备武器")
			_last_target_id = "sword_shield_item"
		STEP_EQUIP_SHOWCASE:
			_show_step_copy(overlay, step_id, "艾达已装备剑盾，现在可以参与防守。", "准备拉响警报")
			overlay.hide_conversation()
		STEP_ALARM:
			_restore_camera_zoom_after_ada_focus()
			_show_step_copy(overlay, step_id, "拉响警报，召集已入伍且配有武器的成员到城门集合。", "拉响警报")
			_last_target_id = "alarm"
		STEP_BATTLE:
			_begin_ada_camera_follow()
			overlay.clear_target()
			overlay.hide_conversation()
			overlay.set_top_hint(_step_top_hint(step_id, "艾达正在按正式战斗逻辑索敌、接敌与攻击"))
		STEP_BATTLE_HEALTH:
			_show_step_copy(overlay, step_id, "成员生命值降至 0 时会昏迷，但不会永久死亡；治疗可加快恢复。", "观察艾达的生命值", true)
		STEP_VICTORY:
			overlay.show_victory()
		STEP_POST_BATTLE:
			var pages: Array = _config.get("post_battle_pages", [])
			var page: Dictionary = (pages[_post_battle_index] as Dictionary).duplicate(true)
			if str(page.get("speaker", "")) == "ada":
				page["portrait_npc_id"] = str(_config.get("ada_npc_id", ""))
			overlay.show_page(page, false)
		STEP_ADA_RETURN:
			overlay.hide_conversation()
			overlay.set_top_hint(_step_top_hint(step_id, "战斗结束，艾达正在返回宿舍"))
			_begin_ada_return()
		STEP_HANDOFF_CARD:
			overlay.show_handoff_card()
		STEP_FINISHED:
			_set_tutorial_music_cue("")
			overlay.finish()
	tutorial_step_changed.emit(_step_id, get_tutorial_snapshot())


func _sync_tutorial_music_for_intro_page(page: Dictionary) -> void:
	var music_config: Dictionary = _config.get("tutorial_music", {}) if _config.get("tutorial_music", {}) is Dictionary else {}
	var battle_start_page_id := str(music_config.get("battle_start_intro_page_id", "intro_ada_warning"))
	var page_id := str(page.get("id", ""))
	if page_id == battle_start_page_id or _tutorial_music_cue == "tutorial_battle":
		_set_tutorial_music_cue("tutorial_battle")
	else:
		_set_tutorial_music_cue("tutorial_intro")


func _set_tutorial_music_cue(cue: String) -> void:
	if cue == _tutorial_music_cue:
		return
	_tutorial_music_cue = cue
	tutorial_music_cue_changed.emit(_tutorial_music_cue)


func _show_step_copy(overlay: Node, step_id: String, fallback_text: String, fallback_top_hint: String, observation: bool = false) -> void:
	var step_copy := _step_copy(step_id)
	var text := str(step_copy.get("text", fallback_text))
	var top_hint := str(step_copy.get("top_hint", fallback_top_hint))
	if text.is_empty():
		text = fallback_text
	if observation:
		overlay.call("show_observation", text, top_hint)
	else:
		overlay.call("show_instruction", text, top_hint)


func _step_top_hint(step_id: String, fallback: String) -> String:
	var value := str(_step_copy(step_id).get("top_hint", fallback))
	return value if not value.is_empty() else fallback


func _step_copy(step_id: String) -> Dictionary:
	var all_copy: Dictionary = _config.get("step_copy", {}) if _config.get("step_copy", {}) is Dictionary else {}
	var value: Variant = all_copy.get(step_id, {})
	return (value as Dictionary) if value is Dictionary else {}


func _on_continue_requested() -> void:
	if not _active or _handoff_in_progress:
		return
	match _step_id:
		STEP_INTRO:
			var pages: Array = _config.get("intro_pages", [])
			_intro_index += 1
			if _intro_index < pages.size():
				_enter_step(STEP_INTRO)
			else:
				_enter_step(STEP_BATTLEFIELD_EXPLAIN)
		STEP_BATTLEFIELD_EXPLAIN:
			_enter_step(STEP_SELECT_SLOT)
		STEP_CAMERA_CONTROLS:
			_enter_step(STEP_WAIT_TOWER)
		STEP_TOWER_DESTROYED:
			_enter_step(STEP_SELECT_ADA)
		STEP_BATTLE_HEALTH:
			_enter_step(STEP_BATTLE)
		STEP_POST_BATTLE:
			var pages: Array = _config.get("post_battle_pages", [])
			_post_battle_index += 1
			if _post_battle_index < pages.size():
				_enter_step(STEP_POST_BATTLE)
			else:
				_enter_step(STEP_ADA_RETURN)


func _on_target_pressed(target_id: String) -> void:
	if not _active or target_id != _last_target_id:
		return
	var presenter := get_node_or_null(DEFENSE_PRESENTER_PATH)
	var panel := get_node_or_null(NPC_PANEL_PATH)
	match _step_id:
		STEP_SELECT_SLOT:
			if presenter != null and presenter.tutorial_open_slot(str(_config.get("target_slot_id", "wall_slot_01"))):
				_enter_step(STEP_SELECT_DEVICE)
		STEP_SELECT_DEVICE:
			if presenter != null:
				var deploy_result: Dictionary = presenter.tutorial_deploy_device(str(_config.get("tutorial_device_id", "wall_arrow_tower")))
				if bool(deploy_result.get("ok", false)):
					var device_system := get_node_or_null(DEFENSE_SYSTEM_PATH)
					if device_system != null and device_system.has_method("apply_tutorial_deployment_overrides"):
						device_system.apply_tutorial_deployment_overrides(
							str(deploy_result.get("deployment_id", "")),
							_config.get("tutorial_device_overrides", {})
						)
					_tower_was_deployed = true
					_set_detached_simulation(true)
					_enter_step(STEP_CAMERA_CONTROLS)
		STEP_SELECT_ADA:
			var event_bus := get_node_or_null("/root/EventBus")
			if event_bus != null:
				event_bus.npc_clicked.emit(str(_config.get("ada_npc_id", "veteran_deputy_01")))
				_enter_step(STEP_EQUIPMENT_BUTTON)
		STEP_EQUIPMENT_BUTTON:
			if panel != null:
				var previous_step := _step_id
				panel.debug_toggle_equipment_window()
				_reconcile_equipment_progress()
				if _step_id == previous_step:
					_enter_step(STEP_MAIN_WEAPON)
		STEP_MAIN_WEAPON:
			if panel != null:
				var previous_step := _step_id
				panel.debug_press_equipment_slot("main_weapon")
				_reconcile_equipment_progress()
				if _step_id == previous_step:
					_enter_step(STEP_SWORD_SHIELD)
		STEP_SWORD_SHIELD:
			if panel != null:
				panel.debug_select_equipment_item("main_weapon", str(_config.get("tutorial_weapon_id", "sword_shield")))
				_reconcile_equipment_progress()
		STEP_ALARM:
			var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
			if combat_system != null:
				var alarm_result: Dictionary = combat_system.trigger_combat_alarm("tutorial")
				if bool(alarm_result.get("ok", false)):
					_close_npc_panel()
					_battle_elapsed = 0.0
					_enter_step(STEP_BATTLE)


func _on_equipment_window_visibility_changed(npc_id: String, window_visible: bool) -> void:
	if _active and npc_id == str(_config.get("ada_npc_id", "veteran_deputy_01")) and window_visible:
		_reconcile_equipment_progress()


func _on_equipment_slot_picker_opened(npc_id: String, slot: String) -> void:
	if _active and npc_id == str(_config.get("ada_npc_id", "veteran_deputy_01")) and slot == "main_weapon":
		_reconcile_equipment_progress()


func _on_equipment_item_applied(npc_id: String, slot: String, item_id: String, result: Dictionary) -> void:
	if (
		_active
		and npc_id == str(_config.get("ada_npc_id", "veteran_deputy_01"))
		and slot == "main_weapon"
		and item_id == str(_config.get("tutorial_weapon_id", "sword_shield"))
		and bool(result.get("ok", false))
	):
		_reconcile_equipment_progress()


func _reconcile_equipment_progress() -> void:
	if not _active or _step_id not in [STEP_EQUIPMENT_BUTTON, STEP_MAIN_WEAPON, STEP_SWORD_SHIELD]:
		return
	var ada_npc_id := str(_config.get("ada_npc_id", "veteran_deputy_01"))
	var expected_weapon_id := str(_config.get("tutorial_weapon_id", "sword_shield"))
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system != null and equipment_system.has_method("get_equipment_snapshot"):
		var equipment: Dictionary = equipment_system.get_equipment_snapshot(ada_npc_id)
		if str((equipment.get("main_weapon", {}) as Dictionary).get("id", "")) == expected_weapon_id:
			_enter_step(STEP_EQUIP_SHOWCASE)
			return
	var panel := get_node_or_null(NPC_PANEL_PATH)
	if panel == null or not panel.has_method("debug_get_equipment_window_snapshot"):
		return
	var snapshot: Dictionary = panel.debug_get_equipment_window_snapshot()
	if str(snapshot.get("npc_id", "")) != ada_npc_id:
		return
	if _step_id == STEP_EQUIPMENT_BUTTON and bool(snapshot.get("visible", false)):
		_enter_step(STEP_MAIN_WEAPON)
		snapshot = panel.debug_get_equipment_window_snapshot()
	if (
		_step_id == STEP_MAIN_WEAPON
		and bool(snapshot.get("picker_visible", false))
		and str(snapshot.get("picker_slot", "")) == "main_weapon"
	):
		_enter_step(STEP_SWORD_SHIELD)


func _on_inspection_requested(kind: String, entity_id: String) -> void:
	if not _active or _step_id not in [STEP_BATTLE, STEP_BATTLE_HEALTH]:
		return
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	if kind == "npc" and entity_id == str(_config.get("ada_npc_id", "veteran_deputy_01")):
		event_bus.npc_clicked.emit(entity_id)
	elif kind == "enemy":
		var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
		if combat_system != null and combat_system.get_active_enemy_ids().has(entity_id):
			event_bus.enemy_clicked.emit(entity_id)


func _refresh_target_focus() -> void:
	if _last_target_id.is_empty():
		return
	var overlay := get_node_or_null(TUTORIAL_OVERLAY_PATH)
	if overlay == null:
		return
	var rect := Rect2()
	if _last_target_id == "ada":
		rect = _get_ada_screen_rect()
	else:
		var control := _get_target_control(_last_target_id)
		if control != null and control.visible and control.is_inside_tree():
			rect = control.get_global_rect()
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		overlay.set_target_rect(_last_target_id, rect)


func _refresh_inspection_targets() -> void:
	var overlay := get_node_or_null(TUTORIAL_OVERLAY_PATH)
	if overlay == null or not overlay.has_method("set_inspection_targets"):
		return
	if _step_id not in [STEP_BATTLE, STEP_BATTLE_HEALTH]:
		return
	var camera := get_viewport().get_camera_3d()
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if camera == null or combat_system == null:
		overlay.set_inspection_targets([])
		return
	var targets: Array = []
	var ada_rect := _get_ada_screen_rect()
	if ada_rect.size.x > 0.0:
		targets.append({"kind": "npc", "entity_id": str(_config.get("ada_npc_id", "veteran_deputy_01")), "rect": ada_rect})
	for enemy_id in combat_system.get_active_enemy_ids():
		var world_position: Variant = combat_system.get_enemy_world_position(enemy_id)
		if not world_position is Vector3 or camera.is_position_behind(world_position as Vector3):
			continue
		var center := camera.unproject_position((world_position as Vector3) + Vector3(0.0, 0.8, 0.0))
		var rect := Rect2(center - Vector2(32.0, 48.0), Vector2(64.0, 96.0))
		if rect.end.x < 0.0 or rect.end.y < 0.0 or rect.position.x > get_viewport().get_visible_rect().size.x or rect.position.y > get_viewport().get_visible_rect().size.y:
			continue
		targets.append({"kind": "enemy", "entity_id": enemy_id, "rect": rect})
	overlay.set_inspection_targets(targets)


func _get_target_control(target_id: String) -> Control:
	if target_id.begins_with("slot:") or target_id.begins_with("device:"):
		var presenter := get_node_or_null(DEFENSE_PRESENTER_PATH)
		return presenter.get_tutorial_target_control(target_id) if presenter != null else null
	if target_id in ["equipment_button", "main_weapon_slot", "sword_shield_item"]:
		var panel := get_node_or_null(NPC_PANEL_PATH)
		return panel.get_tutorial_target_control(target_id) if panel != null else null
	if target_id == "alarm":
		return get_node_or_null(ALARM_BUTTON_PATH) as Control
	return null


func _get_ada_screen_rect() -> Rect2:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var camera := get_viewport().get_camera_3d()
	if npc_system == null or camera == null:
		return Rect2()
	var world_position: Variant = npc_system.get_npc_world_position(str(_config.get("ada_npc_id", "veteran_deputy_01")))
	if not world_position is Vector3 or camera.is_position_behind(world_position):
		return Rect2()
	var center := camera.unproject_position((world_position as Vector3) + Vector3(0.0, 0.85, 0.0))
	return Rect2(center - Vector2(42.0, 64.0), Vector2(84.0, 128.0))


func _check_tower_destroyed() -> void:
	if not _tower_was_deployed:
		return
	var defense_system := get_node_or_null(DEFENSE_SYSTEM_PATH)
	if defense_system == null:
		return
	var deployment: Dictionary = defense_system.get_deployment_for_slot(str(_config.get("target_slot_id", "wall_slot_01")))
	if deployment.is_empty():
		_record_tower_phase_result(false)
		_enter_step(STEP_TOWER_DESTROYED)


func _recover_stalled_tower_phase() -> void:
	var defense_system := get_node_or_null(DEFENSE_SYSTEM_PATH)
	var slot_id := str(_config.get("target_slot_id", "wall_slot_01"))
	var deployment: Dictionary = (
		defense_system.get_deployment_for_slot(slot_id)
		if defense_system != null and defense_system.has_method("get_deployment_for_slot")
		else {}
	)
	if deployment.is_empty():
		_recovery_snapshot = {
			"triggered": true,
			"reason": "tower_phase_timeout_already_cleared",
			"step_elapsed": _step_elapsed,
			"slot_id": slot_id
		}
		_record_tower_phase_result(true)
		_enter_step(STEP_TOWER_DESTROYED)
		return
	var deployment_id := str(deployment.get("deployment_id", ""))
	var damage_result: Dictionary = (
		defense_system.apply_damage_to_device(
			deployment_id,
			maxi(1, int(deployment.get("hp", 1))),
			{
				"attacker_id": "tutorial_director_safety",
				"attacker_name": "序章异常收口",
				"attack_id": "tutorial_tower_timeout:%s" % deployment_id,
				"tutorial_scope": true
			}
		)
		if defense_system != null and defense_system.has_method("apply_damage_to_device")
		else {}
	)
	_recovery_snapshot = {
		"triggered": true,
		"reason": "tower_phase_timeout",
		"step_elapsed": _step_elapsed,
		"slot_id": slot_id,
		"deployment_id": deployment_id,
		"damage_result": damage_result.duplicate(true)
	}
	if bool(damage_result.get("ok", false)) and bool(damage_result.get("destroyed", false)):
		_record_tower_phase_result(true, damage_result)
		_enter_step(STEP_TOWER_DESTROYED)
		return
	# A missing or rejected tutorial deployment must never leave a half-started
	# world behind. The shared skipped handoff restores the formal baseline and
	# keeps the diagnostic recovery snapshot available to GM / automation.
	_complete_handoff(true)


func _record_tower_phase_result(safety_used: bool, damage_result: Dictionary = {}) -> void:
	if _phase_metrics.has("tower_phase"):
		return
	var defense_system := get_node_or_null(DEFENSE_SYSTEM_PATH)
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var slot_id := str(_config.get("target_slot_id", "wall_slot_01"))
	var ruin := {}
	if defense_system != null and defense_system.has_method("get_device_ruins"):
		for raw_ruin in defense_system.get_device_ruins():
			if raw_ruin is Dictionary and str((raw_ruin as Dictionary).get("slot_id", "")) == slot_id:
				ruin = (raw_ruin as Dictionary).duplicate(true)
				break
	_phase_metrics["tower_phase"] = {
		"duration_seconds": _step_elapsed,
		"safety_used": safety_used,
		"remaining_enemy_count": combat_system.get_active_enemy_count() if combat_system != null else -1,
		"total_attacks": int(ruin.get("total_attacks", 0)),
		"total_damage": int(ruin.get("total_damage", 0)),
		"ruin": ruin,
		"safety_damage_result": damage_result.duplicate(true)
	}


func _check_battle_progress() -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if combat_system == null or npc_system == null:
		return
	var raid_snapshot: Dictionary = combat_system.get_tutorial_raid_snapshot()
	if bool(raid_snapshot.get("completed", false)) or int(raid_snapshot.get("active_enemy_count", 0)) <= 0:
		_finish_tutorial_battle()
		return
	var max_duration := maxf(10.0, float((_config.get("tutorial_raid", {}) as Dictionary).get("max_duration_seconds", 90.0)))
	if _battle_elapsed >= max_duration:
		combat_system.force_finish_tutorial_raid("tutorial_timeout_safety")
		return
	if not _health_hint_shown:
		var state: Dictionary = npc_system.get_npc_state(str(_config.get("ada_npc_id", "veteran_deputy_01")))
		var hp := int(state.get("hp", 0))
		var max_hp := maxi(1, int(state.get("max_hp", 1)))
		if hp < max_hp:
			_health_hint_shown = true
			_enter_step(STEP_BATTLE_HEALTH)


func _on_tutorial_raid_finished(_snapshot: Dictionary) -> void:
	if _active and _step_id in [STEP_BATTLE, STEP_BATTLE_HEALTH]:
		_finish_tutorial_battle()


func _finish_tutorial_battle() -> void:
	if _step_id in [STEP_VICTORY, STEP_POST_BATTLE, STEP_ADA_RETURN, STEP_HANDOFF_CARD, STEP_FINISHED]:
		return
	# Keep the isolated presentation clock running through the victory prompt and
	# Ada's post-battle conversation. The formal calendar remains paused until the
	# atomic handoff, but the visible world must not freeze while they speak.
	_set_detached_simulation(true)
	_end_ada_camera_follow("tutorial_battle_finished")
	_calibrate_ada_narrative_injury()
	_record_battle_phase_result()
	_enter_step(STEP_VICTORY)


func _record_battle_phase_result() -> void:
	if _phase_metrics.has("battle_phase"):
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var state: Dictionary = (
		npc_system.get_npc_state(str(_config.get("ada_npc_id", "veteran_deputy_01")))
		if npc_system != null and npc_system.has_method("get_npc_state")
		else {}
	)
	var max_hp := maxi(1, int(state.get("max_hp", 1)))
	_phase_metrics["battle_phase"] = {
		"duration_seconds": _battle_elapsed,
		"ada_hp": int(state.get("hp", 0)),
		"ada_max_hp": max_hp,
		"ada_hp_ratio": float(state.get("hp", 0)) / float(max_hp),
		"ada_unconscious": bool(state.get("unconscious", false)),
		"health_hint_shown": _health_hint_shown
	}


func _calibrate_ada_narrative_injury() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var ada_npc_id := str(_config.get("ada_npc_id", "veteran_deputy_01"))
	var state: Dictionary = npc_system.get_npc_state(ada_npc_id)
	var max_hp := maxi(1, int(state.get("max_hp", 1)))
	var target_ratio := clampf(float((_config.get("tutorial_raid", {}) as Dictionary).get("ada_target_hp_ratio", 0.80)), 0.35, 1.0)
	var target_hp := clampi(int(round(max_hp * target_ratio)), 1, max_hp)
	var hp := clampi(int(state.get("hp", max_hp)), 0, max_hp)
	if hp > target_hp:
		npc_system.apply_damage_to_npc(ada_npc_id, hp - target_hp, "tutorial", "private", {
			"skip_memory_event": true,
			"tutorial_scope": true,
			"skip_low_hp_judgement": true
		})


func _on_victory_acknowledged() -> void:
	if not _active or _step_id != STEP_VICTORY:
		return
	_normal_completion = true
	_post_battle_index = 0
	_enter_step(STEP_POST_BATTLE)


func _begin_ada_return() -> void:
	_close_npc_panel()
	_set_detached_simulation(true)
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var ada_npc_id := str(_config.get("ada_npc_id", "veteran_deputy_01"))
	if npc_system != null:
		npc_system.update_npc_state(ada_npc_id, {
			"behavior_mode": "work",
			"combat_mode": "",
			"combat_target_enemy_id": "",
			"movement_target": "",
			"movement_target_name": ""
		})
	if action_system != null:
		action_system.interrupt_npc_action(ada_npc_id, "tutorial_return_to_sleep", true)
		action_system.debug_assign_sleep(ada_npc_id)


func _check_ada_return_progress() -> void:
	var effective_elapsed := _get_effective_step_elapsed()
	if effective_elapsed < 3.0:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var ada_npc_id := str(_config.get("ada_npc_id", "veteran_deputy_01"))
	var state: Dictionary = npc_system.get_npc_state(ada_npc_id) if npc_system != null else {}
	var arrived := _is_npc_attached_to_dormitory_bed(npc_system, ada_npc_id, state)
	if not arrived and effective_elapsed >= 8.0 and npc_system != null:
		_set_detached_simulation(false)
		var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
		if action_system != null:
			_stage_npc_at_dormitory_bed(npc_system, action_system, ada_npc_id)
		state = npc_system.get_npc_state(ada_npc_id)
		arrived = _is_npc_attached_to_dormitory_bed(npc_system, ada_npc_id, state)
	if arrived:
		_set_detached_simulation(false)
		_enter_step(STEP_HANDOFF_CARD)


func _get_effective_step_elapsed() -> float:
	if _step_started_msec <= 0:
		return _step_elapsed
	var wall_elapsed := float(Time.get_ticks_msec() - _step_started_msec) / 1000.0
	return maxf(_step_elapsed, wall_elapsed)


func _is_npc_attached_to_dormitory_bed(
	npc_system: Node,
	npc_id: String,
	state_override: Dictionary = {}
) -> bool:
	if npc_system == null:
		return false
	var state: Dictionary = state_override if not state_override.is_empty() else npc_system.get_npc_state(npc_id)
	return (
		str(state.get("current_location", "")) == "dormitory"
		and str(state.get("current_action", "")) == "sleep_in_dormitory"
		and str(state.get("physical_location_phase", "")) == "occupant_anchor"
		and not str(state.get("current_workstation_id", "")).is_empty()
		and bool(npc_system.is_npc_sleeping(npc_id))
	)


func _stage_all_npcs_at_formal_start_beds(npc_system: Node, action_system: Node) -> Dictionary:
	var items := {}
	var workstation_ids: Array[String] = []
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var stage_result: Dictionary = _stage_npc_at_dormitory_bed(npc_system, action_system, npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var workstation_id := str(state.get("current_workstation_id", ""))
		var attached := _is_npc_attached_to_dormitory_bed(npc_system, npc_id, state)
		var unique_bed := not workstation_id.is_empty() and not workstation_ids.has(workstation_id)
		items[npc_id] = {
			"ok": bool(stage_result.get("ok", false)) and attached and unique_bed,
			"workstation_id": workstation_id,
			"world_position": npc_system.get_npc_world_position(npc_id),
			"stage_result": stage_result
		}
		if not bool(stage_result.get("ok", false)) or not attached or not unique_bed:
			return {
				"ok": false,
				"reason": "tutorial_formal_start_bed_stage_failed",
				"npc_id": npc_id,
				"items": items
			}
		workstation_ids.append(workstation_id)
	return {"ok": true, "items": items, "workstation_ids": workstation_ids}


func _stage_npc_at_dormitory_bed(npc_system: Node, action_system: Node, npc_id: String) -> Dictionary:
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if _is_npc_attached_to_dormitory_bed(npc_system, npc_id, state):
		return {"ok": true, "changed": false, "reason": "already_attached"}
	var pending_arrival: Dictionary = {}
	var reserved_building_id := str(state.get("reserved_building_id", ""))
	var reserved_workstation_id := str(state.get("reserved_workstation_id", ""))
	if (
		reserved_building_id == "dormitory"
		and not reserved_workstation_id.is_empty()
		and npc_system.has_method("stage_formal_workstation_arrival_for_tutorial")
	):
		pending_arrival = npc_system.stage_formal_workstation_arrival_for_tutorial(
			npc_id,
			reserved_building_id,
			reserved_workstation_id
		)
		state = npc_system.get_npc_state(npc_id)
		if _is_npc_attached_to_dormitory_bed(npc_system, npc_id, state):
			return {
				"ok": true,
				"changed": true,
				"reason": "pending_route_completed",
				"arrival_result": pending_arrival
			}
	var stage_result: Dictionary = action_system.stage_npc_sleep_for_tutorial(npc_id)
	state = npc_system.get_npc_state(npc_id)
	return {
		"ok": bool(stage_result.get("ok", false)) and _is_npc_attached_to_dormitory_bed(npc_system, npc_id, state),
		"changed": true,
		"reason": "sleep_staged",
		"pending_arrival": pending_arrival,
		"sleep_stage_result": stage_result
	}


func _complete_handoff(skipped: bool) -> Dictionary:
	if not _handoff_snapshot.is_empty():
		return _handoff_snapshot.duplicate(true)
	if _handoff_in_progress:
		return get_tutorial_snapshot()
	_handoff_in_progress = true
	_set_detached_simulation(false)
	_end_ada_camera_follow("tutorial_handoff")
	_restore_camera_zoom_after_ada_focus()
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	var defense_system := get_node_or_null(DEFENSE_SYSTEM_PATH)
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var daily_plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if (
		time_system == null or resource_system == null or npc_system == null
		or action_system == null or building_system == null or memory_system == null or equipment_system == null
		or defense_system == null or combat_system == null or daily_plan_system == null
	):
		_handoff_in_progress = false
		return _fail_tutorial("tutorial_handoff_dependencies_missing", "序章交接依赖系统不完整。")

	time_system.set_paused(true)
	combat_system.end_tutorial_raid("tutorial_skipped" if skipped else "tutorial_handoff")
	resource_system.initialize()
	defense_system.initialize()
	_bind_formal_defense_slots(defense_system)
	equipment_system.initialize()
	equipment_system.set_tutorial_event_suppression(false)
	defense_system.set_tutorial_event_suppression(false)
	var ada_npc_id := str(_config.get("ada_npc_id", "veteran_deputy_01"))
	var equipment_restore: Dictionary = equipment_system.restore_npc_initial_equipment(ada_npc_id)
	var ada_state: Dictionary = npc_system.get_npc_state(ada_npc_id)
	var max_hp := maxi(1, int(ada_state.get("max_hp", 1)))
	var hp := clampi(int(ada_state.get("hp", max_hp)), 0, max_hp)
	var hp_restore: Dictionary = npc_system.restore_npc_hp(ada_npc_id, max_hp - hp, "tutorial_handoff") if hp < max_hp else {"ok": true, "changed": false, "hp_after": max_hp}
	npc_system.update_npc_state(ada_npc_id, {
		"hp": max_hp,
		"unconscious": false,
		"combat_mode": "",
		"combat_target_enemy_id": "",
		"combat_attack_phase": "idle",
		"movement_target": "",
		"movement_target_name": "",
		"behavior_mode": "work"
	})
	# Clear only actors that are not already attached to a bed. Interrupting a
	# valid sleeper can leave its BuildingSystem reservation alive for the same
	# frame while clearing the NPC-side workstation fields, making its own bed
	# temporarily impossible to reacquire.
	for raw_npc_id in npc_system.get_npc_ids():
		var prepare_npc_id := str(raw_npc_id)
		if not _is_npc_attached_to_dormitory_bed(npc_system, prepare_npc_id):
			action_system.interrupt_npc_action(prepare_npc_id, "tutorial_handoff_prepare", true)
			building_system.release_workstation_reservation("dormitory", prepare_npc_id)
	var formal_start_beds: Dictionary = _stage_all_npcs_at_formal_start_beds(npc_system, action_system)
	if not bool(formal_start_beds.get("ok", false)):
		_handoff_in_progress = false
		var failure := _fail_tutorial(
			"tutorial_formal_start_bed_stage_failed",
			"无法把全部驿站成员安置到各自宿舍床位。"
		)
		failure["details"] = formal_start_beds.duplicate(true)
		return failure
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		memory_system.clear_npc_short_term_memory(npc_id)
	if memory_system.has_method("broadcast_initial_notice_board_state_for_formal_loop"):
		memory_system.broadcast_initial_notice_board_state_for_formal_loop()

	var handoff_clock: Dictionary = _config.get("handoff_clock", {})
	time_system.set_current_time(
		int(handoff_clock.get("day", 1)),
		int(handoff_clock.get("hour", 6)),
		int(handoff_clock.get("minute", 0)),
		0
	)
	var plan_results := {}
	var plan_source := str(_day1_plan_config.get("source", "tutorial_day1_preset"))
	var plans: Dictionary = _day1_plan_config.get("plans", {})
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var preparation: Dictionary = daily_plan_system.begin_new_day_planning_for_npc(npc_id, "tutorial_handoff")
		var plan := _build_day_plan(npc_id, plans.get(npc_id, []), plan_source)
		var applied: bool = bool(daily_plan_system.set_npc_daily_plan(npc_id, plan, true, plan_source))
		plan_results[npc_id] = {"prepared": preparation, "applied": applied, "item_count": plan.size()}
		if not applied:
			_handoff_in_progress = false
			return _fail_tutorial("tutorial_day1_plan_apply_failed", "无法应用 %s 的第一日预设计划。" % npc_id)
	daily_plan_system.set_auto_execution_enabled(true)
	var execute_results: Dictionary = daily_plan_system.execute_current_plan_for_all(true)
	var formal_start_positions := {"ok": true, "items": {}}
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var bed_item: Dictionary = (formal_start_beds.get("items", {}) as Dictionary).get(npc_id, {})
		var placement: Dictionary = npc_system.place_npc_at_formal_workstation_exit_for_tutorial_handoff(
			npc_id,
			"dormitory",
			str(bed_item.get("workstation_id", ""))
		)
		(formal_start_positions["items"] as Dictionary)[npc_id] = placement
		if not bool(placement.get("ok", false)):
			formal_start_positions["ok"] = false
			formal_start_positions["reason"] = "tutorial_formal_start_position_failed"
			formal_start_positions["npc_id"] = npc_id
			_handoff_in_progress = false
			return _fail_tutorial(
				"tutorial_formal_start_position_failed",
				"无法从 %s 的固定床位启动第一日计划。" % npc_id
			)
	time_system.set_paused(false)

	_handoff_snapshot = {
		"ok": true,
		"skipped": skipped,
		"status": "tutorial_skipped" if skipped else "tutorial_completed",
		"clock": handoff_clock.duplicate(true),
		"resource_snapshot": resource_system.get_resource_snapshot(),
		"defense_deployments": defense_system.get_deployments(),
		"ada_hp": npc_system.get_npc_state(ada_npc_id).get("hp", 0),
		"ada_max_hp": npc_system.get_npc_state(ada_npc_id).get("max_hp", 0),
		"ada_equipment": equipment_system.get_equipment_snapshot(ada_npc_id),
		"equipment_restore": equipment_restore,
		"hp_restore": hp_restore,
		"formal_start_beds": formal_start_beds,
		"formal_start_positions": formal_start_positions,
		"plan_results": plan_results,
		"execute_results": execute_results,
		"wave_schedule": combat_system.get_wave_schedule_snapshot()
	}
	_set_tutorial_music_cue("")
	_active = false
	_handoff_in_progress = false
	_step_id = STEP_FINISHED
	var overlay := get_node_or_null(TUTORIAL_OVERLAY_PATH)
	if overlay != null:
		overlay.finish()
	var result := _handoff_snapshot.duplicate(true)
	tutorial_finished.emit(result)
	return result


func _build_day_plan(npc_id: String, raw_actions: Variant, source: String) -> Array:
	var actions: Array = raw_actions if raw_actions is Array else []
	var plan: Array = []
	for hour in range(actions.size()):
		var raw_entry: Variant = actions[hour]
		var action_id := _tutorial_plan_entry_action_id(raw_entry)
		var item := {
			"hour": hour,
			"action_id": action_id,
			"reason": "序章交接预设：第 1 日基础作息",
			"source": source,
			"npc_id": npc_id
		}
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			var target_id := _tutorial_plan_entry_target_id(entry)
			if not target_id.is_empty():
				var target := {"target_id": target_id}
				if action_id == "talk_to_npc":
					target["target_npc_id"] = target_id
				elif action_id == "visit_location":
					target["location_id"] = target_id
				item["target"] = target
			item["dialogue_goal"] = str(entry.get("dialogue_goal", ""))
			item["reason"] = str(entry.get("reason", item["reason"]))
		plan.append(item)
	return plan


func _tutorial_plan_entry_action_id(raw_entry: Variant) -> String:
	if raw_entry is String:
		return str(raw_entry).strip_edges()
	if raw_entry is Dictionary:
		return str((raw_entry as Dictionary).get("action_id", "")).strip_edges()
	return ""


func _tutorial_plan_entry_target_id(raw_entry: Variant) -> String:
	if not raw_entry is Dictionary:
		return ""
	return str((raw_entry as Dictionary).get("target_id", "")).strip_edges()


func _set_detached_simulation(enabled: bool) -> void:
	if _detached_simulation_running == enabled:
		return
	_detached_simulation_running = enabled
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null:
		return
	if enabled:
		time_system.request_detached_presentation_simulation(DETACHED_SIMULATION_REQUEST_ID, "tutorial_prologue")
	else:
		time_system.release_detached_presentation_simulation(DETACHED_SIMULATION_REQUEST_ID)


func _bind_formal_defense_slots(defense_system: Node) -> void:
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and defense_system.has_method("bind_formal_slot_positions"):
		defense_system.bind_formal_slot_positions(controller)


func _close_npc_panel() -> void:
	var panel := get_node_or_null(NPC_PANEL_PATH)
	if panel != null:
		if panel.has_method("tutorial_close_panel"):
			panel.tutorial_close_panel()
		else:
			panel.hide()


func _recenter_current_target() -> void:
	var camera_rig := get_node_or_null(CAMERA_RIG_PATH)
	if camera_rig == null or not camera_rig.has_method("focus_world_position"):
		return
	if _last_target_id.begins_with("slot:"):
		_focus_gate_for_tutorial()
	elif _last_target_id == "ada":
		_focus_ada_for_selection()


func _focus_gate_for_tutorial() -> void:
	var camera_rig := get_node_or_null(CAMERA_RIG_PATH)
	if camera_rig == null:
		return
	if camera_rig.has_method("set_zoom_distance"):
		camera_rig.set_zoom_distance(float(_config.get("gate_focus_zoom_distance", 20.0)))
	var focus_position := _get_config_position3("gate_focus_world_position", Vector3(1.5, 0.0, 54.0))
	if camera_rig.has_method("focus_world_position_at_screen_center"):
		camera_rig.focus_world_position_at_screen_center(focus_position)
	elif camera_rig.has_method("focus_world_position"):
		camera_rig.focus_world_position(focus_position)


func _focus_ada_for_selection() -> void:
	var camera_rig := get_node_or_null(CAMERA_RIG_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if camera_rig == null or npc_system == null or not camera_rig.has_method("focus_world_position_at_screen_center"):
		return
	var position: Variant = npc_system.get_npc_world_position(str(_config.get("ada_npc_id", "veteran_deputy_01")))
	if not position is Vector3:
		return
	if _camera_zoom_before_ada_focus < 0.0 and camera_rig.has_method("get_zoom_distance"):
		_camera_zoom_before_ada_focus = float(camera_rig.get_zoom_distance())
	if camera_rig.has_method("set_zoom_distance"):
		camera_rig.set_zoom_distance(float(_config.get("ada_focus_zoom_distance", 20.0)))
	var focus_height := float(_config.get("ada_focus_height", 0.85))
	camera_rig.focus_world_position_at_screen_center((position as Vector3) + Vector3.UP * focus_height)


func _restore_camera_zoom_after_ada_focus() -> void:
	if _camera_zoom_before_ada_focus < 0.0:
		return
	var camera_rig := get_node_or_null(CAMERA_RIG_PATH)
	if camera_rig != null and camera_rig.has_method("set_zoom_distance"):
		camera_rig.set_zoom_distance(_camera_zoom_before_ada_focus)
	_camera_zoom_before_ada_focus = -1.0


func _update_ada_equipment_gesture(delta: float) -> void:
	if _step_id not in EQUIPMENT_GESTURE_STEPS:
		return
	_ada_equipment_gesture_remaining -= maxf(0.0, delta)
	if _ada_equipment_gesture_remaining <= 0.0:
		_play_ada_equipment_gesture()


func _play_ada_equipment_gesture() -> void:
	if not _active or _step_id not in EQUIPMENT_GESTURE_STEPS:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("play_idle_portrait_talk_gesture"):
		return
	var ada_npc_id := str(_config.get("ada_npc_id", "veteran_deputy_01"))
	var result: Dictionary = npc_system.play_idle_portrait_talk_gesture(ada_npc_id)
	_ada_equipment_gesture_last_result = result.duplicate(true)
	var fallback_interval := maxf(0.25, float(_config.get("ada_equipment_gesture_interval_seconds", 1.5)))
	if bool(result.get("ok", false)):
		var event: Dictionary = result.get("event", {}) if result.get("event", {}) is Dictionary else {}
		_ada_equipment_gesture_count += 1
		_ada_equipment_gesture_remaining = maxf(
			fallback_interval,
			float(event.get("duration_seconds", result.get("duration_seconds", 0.0)))
		)
	else:
		_ada_equipment_gesture_remaining = fallback_interval


func _begin_ada_camera_follow() -> void:
	if _ada_camera_follow_active:
		return
	var camera_rig := get_node_or_null(CAMERA_RIG_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if camera_rig == null or npc_system == null:
		return
	_ada_camera_follow_active = true
	_ada_camera_follow_release_reason = ""
	_ada_camera_follow_zoom = (
		float(camera_rig.get_zoom_distance())
		if camera_rig.has_method("get_zoom_distance")
		else float(_config.get("ada_follow_zoom_distance", 20.0))
	)
	if camera_rig.has_method("set_zoom_distance"):
		camera_rig.set_zoom_distance(_ada_camera_follow_zoom)
	if camera_rig.has_method("request_camera_control_lock"):
		camera_rig.request_camera_control_lock(ADA_CAMERA_LOCK_REQUEST_ID)
	var position: Variant = npc_system.get_npc_world_position(str(_config.get("ada_npc_id", "veteran_deputy_01")))
	if position is Vector3 and camera_rig.has_method("focus_world_position_at_screen_center"):
		camera_rig.focus_world_position_at_screen_center(
			(position as Vector3) + Vector3.UP * float(_config.get("ada_focus_height", 0.85))
		)


func _update_ada_camera_follow(delta: float) -> void:
	if not _ada_camera_follow_active:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var camera_rig := get_node_or_null(CAMERA_RIG_PATH)
	if npc_system == null or camera_rig == null:
		_end_ada_camera_follow("follow_dependency_missing")
		return
	var ada_npc_id := str(_config.get("ada_npc_id", "veteran_deputy_01"))
	var state: Dictionary = npc_system.get_npc_state(ada_npc_id)
	var attack_phase := str(state.get("combat_attack_phase", "idle"))
	var current_action := str(state.get("current_action", ""))
	if attack_phase in ["windup", "recovery"] or current_action.begins_with("attacking_") or current_action.begins_with("winding_up_"):
		_end_ada_camera_follow("ada_attack_started")
		return
	var position: Variant = npc_system.get_npc_world_position(ada_npc_id)
	if not position is Vector3:
		return
	if camera_rig.has_method("set_zoom_distance"):
		camera_rig.set_zoom_distance(_ada_camera_follow_zoom)
	if camera_rig.has_method("smooth_focus_world_position_at_screen_center"):
		camera_rig.smooth_focus_world_position_at_screen_center(
			(position as Vector3) + Vector3.UP * float(_config.get("ada_focus_height", 0.85)),
			delta,
			float(_config.get("ada_follow_camera_responsiveness", 8.0))
		)


func _end_ada_camera_follow(reason: String) -> void:
	var camera_rig := get_node_or_null(CAMERA_RIG_PATH)
	if camera_rig != null and camera_rig.has_method("release_camera_control_lock"):
		camera_rig.release_camera_control_lock(ADA_CAMERA_LOCK_REQUEST_ID)
	if _ada_camera_follow_active or _ada_camera_follow_release_reason.is_empty():
		_ada_camera_follow_release_reason = reason
	_ada_camera_follow_active = false
	_ada_camera_follow_zoom = -1.0


func _get_config_vector3(key: String, fallback: Vector3) -> Vector3:
	var raw: Variant = _config.get(key, [])
	if raw is Array and (raw as Array).size() >= 3:
		var value := Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
		if value.length_squared() > 0.0001:
			return value.normalized()
	return fallback.normalized()


func _get_config_position3(key: String, fallback: Vector3) -> Vector3:
	var raw: Variant = _config.get(key, [])
	if raw is Array and (raw as Array).size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return fallback


func _fail_tutorial(reason: String, message: String) -> Dictionary:
	_set_detached_simulation(false)
	_end_ada_camera_follow("tutorial_failed")
	_restore_camera_zoom_after_ada_focus()
	_set_tutorial_music_cue("")
	_last_error = {"reason": reason, "message": message}
	_active = false
	_handoff_in_progress = false
	var overlay := get_node_or_null(TUTORIAL_OVERLAY_PATH)
	if overlay != null and overlay.has_method("finish"):
		overlay.finish()
	var result := {"ok": false, "status": "failed", "reason": reason, "message": message}
	tutorial_finished.emit(result.duplicate(true))
	return result
