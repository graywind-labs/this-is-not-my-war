extends Node

signal checkpoint_completed(result: Dictionary)
signal restore_completed(result: Dictionary)

const GameSaveStore = preload("res://scripts/systems/GameSaveStore.gd")
const MAIN_LAUNCH_REQUEST_META := &"main_launch_request"
const SYSTEM_ROOT := "/root/Main/Systems/"
const THUMBNAIL_SIZE := Vector2i(480, 270)
const THUMBNAIL_ASPECT := 16.0 / 9.0
const THUMBNAIL_QUALITY := 0.82

var _archive_id := ""
var _pending_cleared_waves: Array[int] = []
var _checkpoint_scheduled := false
var _pending_final_checkpoint := false
var _restoring := false
var _runtime_ahead_of_checkpoint := true
var _last_result: Dictionary = {}
var _launched_for_load := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var request := _peek_launch_request()
	_launched_for_load = int(request.get("startup_mode", -1)) == 3
	_archive_id = str(request.get("archive_id", "")) if _launched_for_load else GameSaveStore.create_archive_id()
	if _archive_id.is_empty():
		_archive_id = GameSaveStore.create_archive_id()
	GameSaveStore.set_last_active_archive(_archive_id)
	if not _launched_for_load:
		var game_state := get_node_or_null("/root/GameState")
		if game_state != null and game_state.has_method("restore_game_save_snapshot"):
			game_state.restore_game_save_snapshot({"day": 1, "hour": 6, "minute": 0, "second": 0}, false)
		var time_system := _system("TimeSystem")
		if time_system != null and time_system.has_method("restore_game_save_snapshot"):
			time_system.restore_game_save_snapshot({"day": 1, "hour": 6, "minute": 0, "second": 0})
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.combat_wave_cleared.connect(_on_combat_wave_cleared)
		event_bus.epilogue_changed.connect(_on_epilogue_changed)
		_connect_dirty_signal(event_bus, "time_changed", 4)
		_connect_dirty_signal(event_bus, "resource_changed", 2)
		_connect_dirty_signal(event_bus, "building_state_changed", 1)
		_connect_dirty_signal(event_bus, "npc_state_changed", 1)
		_connect_dirty_signal(event_bus, "event_recorded", 1)
		_connect_dirty_signal(event_bus, "horse_state_changed", 1)
		_connect_dirty_signal(event_bus, "merchant_state_changed", 2)
		_connect_dirty_signal(event_bus, "defense_device_state_changed", 1)
		_connect_dirty_signal(event_bus, "piety_changed", 4)
	var startup := get_node_or_null(SYSTEM_ROOT + "GameStartupSystem")
	if startup != null and startup.has_signal("startup_completed"):
		startup.startup_completed.connect(_on_startup_completed)


func get_archive_id() -> String:
	return _archive_id


func has_automatic_checkpoint() -> bool:
	return bool(GameSaveStore.inspect_restore_point(_archive_id, "auto").get("loadable", false))


func pin_latest_checkpoint(slot_id: String, display_name: String = "") -> Dictionary:
	var fallback_name := "快速检查点" if slot_id == "quick_0" else "第 %d 波结束" % _get_checkpoint_wave()
	var result := GameSaveStore.pin_auto_to_slot(_archive_id, slot_id, display_name if not display_name.strip_edges().is_empty() else fallback_name)
	if bool(result.get("ok", false)):
		_archive_id = str(result.get("archive_id", _archive_id))
		GameSaveStore.set_last_active_archive(_archive_id)
	_last_result = result.duplicate(true)
	return result


func capture_automatic_checkpoint(wave_number: int = 0, reason: String = "wave_cleared") -> Dictionary:
	if _restoring:
		return _store_result({"ok": false, "reason": "restore_in_progress"})
	var combat := _system("CombatSystem")
	if wave_number > 0 and (combat == null or int(combat.get_active_enemy_count()) != 0):
		return _store_result({"ok": false, "reason": "enemies_still_active"})
	if wave_number > 0:
		var combat_schedule: Dictionary = combat.get_wave_schedule_snapshot()
		if not (combat_schedule.get("active_battle", {}) as Dictionary).is_empty():
			return _store_result({"ok": false, "reason": "battle_cleanup_incomplete"})
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and bool(game_state.game_over) and str(game_state.game_result) == "failure":
		return _store_result({"ok": false, "reason": "failure_checkpoint_forbidden"})
	if game_state != null and bool(game_state.game_over) and not _is_epilogue_settled(game_state.settlement_snapshot):
		_pending_final_checkpoint = true
		return _store_result({"ok": true, "deferred": true, "reason": "awaiting_epilogue"})

	var time_system := _system("TimeSystem")
	var was_paused := bool(time_system.is_gameplay_paused()) if time_system != null and time_system.has_method("is_gameplay_paused") else false
	if time_system != null:
		time_system.set_paused(true)
	var state_result := _capture_state(wave_number, reason)
	if not bool(state_result.get("ok", false)):
		if time_system != null:
			time_system.set_paused(was_paused)
		return _store_result(state_result)
	var state: Dictionary = state_result["state"]
	var game: Dictionary = state.get("game_state", {})
	var meta := {
		"display_name": "第 %d 波结束" % wave_number if wave_number > 0 else "正式开局",
		"checkpoint_wave": wave_number,
		"day": int(game.get("day", 1)),
		"game_time": "%02d:%02d:%02d" % [int(game.get("hour", 0)), int(game.get("minute", 0)), int(game.get("second", 0))],
		"checkpoint_reason": reason,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "unknown")),
	}
	var thumbnail_bytes := _capture_thumbnail_webp()
	var write_result := GameSaveStore.write_checkpoint(_archive_id, "auto", state, meta, thumbnail_bytes)
	if time_system != null:
		time_system.set_paused(was_paused or bool(game.get("game_over", false)))
	if bool(write_result.get("ok", false)):
		_runtime_ahead_of_checkpoint = false
		GameSaveStore.set_last_active_archive(_archive_id)
	checkpoint_completed.emit(write_result.duplicate(true))
	return _store_result(write_result)


func restore_from_request(request: Dictionary) -> Dictionary:
	var archive_id := str(request.get("archive_id", ""))
	var point := str(request.get("restore_point", "auto"))
	var inspected := GameSaveStore.inspect_restore_point(archive_id, point)
	if not bool(inspected.get("loadable", false)):
		return _store_restore({"ok": false, "reason": str(inspected.get("reason", "checkpoint_invalid"))})
	_archive_id = archive_id
	_restoring = true
	var result := _restore_state(inspected.get("state", {}))
	_restoring = false
	if bool(result.get("ok", false)):
		_runtime_ahead_of_checkpoint = false
		GameSaveStore.set_last_active_archive(_archive_id)
	return _store_restore(result)


func debug_get_snapshot() -> Dictionary:
	return {
		"archive_id": _archive_id,
		"has_automatic_checkpoint": has_automatic_checkpoint(),
		"runtime_ahead_of_checkpoint": _runtime_ahead_of_checkpoint,
		"pending_cleared_waves": _pending_cleared_waves.duplicate(),
		"pending_final_checkpoint": _pending_final_checkpoint,
		"restoring": _restoring,
		"last_result": _last_result.duplicate(true),
	}


func debug_capture_checkpoint(wave_number: int = 0) -> Dictionary:
	return capture_automatic_checkpoint(wave_number, "debug")


func _capture_thumbnail_webp() -> PackedByteArray:
	if DisplayServer.get_name() == "headless" or get_viewport() == null:
		return PackedByteArray()
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		return PackedByteArray()
	var source := viewport_texture.get_image()
	if source == null or source.is_empty():
		return PackedByteArray()
	var source_size := source.get_size()
	if source_size.x <= 0 or source_size.y <= 0:
		return PackedByteArray()
	var crop_size := source_size
	var source_aspect := float(source_size.x) / float(source_size.y)
	if source_aspect > THUMBNAIL_ASPECT:
		crop_size.x = maxi(1, int(round(float(source_size.y) * THUMBNAIL_ASPECT)))
	elif source_aspect < THUMBNAIL_ASPECT:
		crop_size.y = maxi(1, int(round(float(source_size.x) / THUMBNAIL_ASPECT)))
	var crop_position := Vector2i(
		maxi(0, (source_size.x - crop_size.x) / 2),
		maxi(0, (source_size.y - crop_size.y) / 2)
	)
	var thumbnail := source.get_region(Rect2i(crop_position, crop_size))
	thumbnail.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return thumbnail.save_webp_to_buffer(true, THUMBNAIL_QUALITY)


func _capture_state(wave_number: int, reason: String) -> Dictionary:
	var required := ["TimeSystem", "ResourceSystem", "BuildingSystem", "CraftingSystem", "NPCSystem", "NPCNeedsSystem", "MemorySystem", "DailyPlanSystem", "DailyReflectionSystem", "HorseSystem", "DefenseDeviceSystem", "MerchantSystem", "CombatSystem", "PietySystem"]
	for system_name in required:
		if _system(system_name) == null:
			return {"ok": false, "reason": "missing_system", "system": system_name}
	var game_state := get_node_or_null("/root/GameState")
	var npc := _system("NPCSystem")
	var combat := _system("CombatSystem")
	var merchant := _system("MerchantSystem")
	return {"ok": true, "state": {
		"checkpoint": {"wave": wave_number, "reason": reason, "captured_unix_time": int(Time.get_unix_time_from_system())},
		"game_state": game_state.create_game_save_snapshot(),
		"time": _system("TimeSystem").create_game_save_snapshot(),
		"buildings": _system("BuildingSystem").create_game_save_snapshot(),
		"resources": _system("ResourceSystem").create_game_save_snapshot(),
		"crafting": _system("CraftingSystem").create_game_save_snapshot(),
		"npcs": npc.create_game_save_snapshot(),
		"npc_needs": _system("NPCNeedsSystem").create_game_save_snapshot(),
		"horses": _system("HorseSystem").create_game_save_snapshot(),
		"defense_devices": _system("DefenseDeviceSystem").create_game_save_snapshot(),
		"piety": _system("PietySystem").create_game_save_snapshot(),
		"memory": _system("MemorySystem").create_game_save_snapshot(),
		"reflections": _system("DailyReflectionSystem").create_game_save_snapshot(),
		"combat": combat.create_game_save_snapshot(),
		"daily_plans": _system("DailyPlanSystem").create_game_save_snapshot(),
		"spatial": {
			"npc": npc.create_formal_spatial_checkpoint(),
			"combat": combat.create_formal_spatial_checkpoint(),
			"merchant": merchant.create_formal_spatial_checkpoint(),
		},
	}}


func _restore_state(raw_state: Variant) -> Dictionary:
	if not raw_state is Dictionary:
		return {"ok": false, "reason": "state_invalid"}
	var state: Dictionary = raw_state
	var time_system := _system("TimeSystem")
	var daily_plan := _system("DailyPlanSystem")
	var memory_system := _system("MemorySystem")
	if memory_system != null and memory_system.has_method("set_game_save_restore_event_suppressed"):
		memory_system.set_game_save_restore_event_suppressed(true)
	if time_system != null:
		time_system.set_paused(true)
	if daily_plan != null:
		daily_plan.set_auto_execution_enabled(false)
	var dialog := _system("DialogSystem")
	if dialog != null and dialog.has_method("end_dialogue"):
		dialog.end_dialogue("game_save_restore", {"suppress_plan_resume": true})
	var game_state := get_node_or_null("/root/GameState")
	game_state.restore_game_save_snapshot(_section(state, "game_state"), false)
	time_system.restore_game_save_snapshot(_section(state, "time"))
	_system("BuildingSystem").restore_game_save_snapshot(_section(state, "buildings"))
	_system("ResourceSystem").restore_game_save_snapshot(_section(state, "resources"))
	_system("CraftingSystem").restore_game_save_snapshot(_section(state, "crafting"))
	_system("NPCSystem").restore_game_save_snapshot(_section(state, "npcs"))
	_system("NPCNeedsSystem").restore_game_save_snapshot(_section(state, "npc_needs"))
	_system("HorseSystem").restore_game_save_snapshot(_section(state, "horses"))
	_system("DefenseDeviceSystem").restore_game_save_snapshot(_section(state, "defense_devices"))
	_system("PietySystem").restore_game_save_snapshot(_section(state, "piety"))
	_system("MemorySystem").restore_game_save_snapshot(_section(state, "memory"))
	_system("DailyReflectionSystem").restore_game_save_snapshot(_section(state, "reflections"))
	_system("CombatSystem").restore_game_save_snapshot(_section(state, "combat"))
	var spatial: Dictionary = _section(state, "spatial")
	var spatial_result := _restore_spatial(spatial)
	if not bool(spatial_result.get("ok", false)):
		if memory_system != null:
			memory_system.set_game_save_restore_event_suppressed(false)
		return spatial_result
	daily_plan.restore_game_save_snapshot(_section(state, "daily_plans"))
	var plan_replay_result: Dictionary = daily_plan.prepare_in_flight_plan_replay_after_game_save_restore(
		_section(spatial, "npc")
	)
	daily_plan.set_auto_execution_enabled(true)
	var execute_result: Dictionary = daily_plan.execute_current_plan_for_all(true)
	if memory_system != null:
		memory_system.set_game_save_restore_event_suppressed(false)
	_system("HorseSystem").call_deferred("reemit_pending_birth_after_restore")
	game_state.restore_game_save_snapshot(_section(state, "game_state"), true)
	time_system.set_paused(bool(game_state.game_over))
	return {"ok": true, "archive_id": _archive_id, "checkpoint": _section(state, "checkpoint"), "spatial": spatial_result, "plan_replay": plan_replay_result, "execute_results": execute_result}


func _restore_spatial(spatial: Dictionary) -> Dictionary:
	var controller := get_node_or_null("/root/Main/Presentation/StationLayoutController")
	if controller == null:
		return {"ok": false, "reason": "station_layout_missing"}
	controller.set_runtime_formal_world_enabled(true)
	controller.force_sync_production_navigation()
	var npc := _system("NPCSystem")
	var combat := _system("CombatSystem")
	var merchant := _system("MerchantSystem")
	var npc_result: Dictionary = npc.restore_formal_spatial_checkpoint(_section(spatial, "npc"))
	if not bool(npc_result.get("ok", false)):
		return {"ok": false, "reason": "npc_spatial_restore_failed", "detail": npc_result}
	var combat_result: Dictionary = combat.restore_formal_spatial_checkpoint(_section(spatial, "combat"))
	if not bool(combat_result.get("ok", false)):
		return {"ok": false, "reason": "combat_spatial_restore_failed", "detail": combat_result}
	var escape_result: Dictionary = combat.restore_formal_escape_sessions_from_npc_checkpoint(_section(spatial, "npc"))
	if not bool(escape_result.get("ok", false)):
		return {"ok": false, "reason": "escape_spatial_restore_failed", "detail": escape_result}
	var merchant_result: Dictionary = merchant.restore_formal_spatial_checkpoint(_section(spatial, "merchant"))
	if not bool(merchant_result.get("ok", false)):
		return {"ok": false, "reason": "merchant_spatial_restore_failed", "detail": merchant_result}
	return {"ok": true, "npc": npc_result, "combat": combat_result, "escape": escape_result, "merchant": merchant_result}


func _on_combat_wave_cleared(wave_number: int) -> void:
	if wave_number <= 0:
		return
	if not _pending_cleared_waves.has(wave_number):
		_pending_cleared_waves.append(wave_number)
	if not _checkpoint_scheduled:
		_checkpoint_scheduled = true
		call_deferred("_commit_pending_wave_checkpoint")


func _commit_pending_wave_checkpoint() -> void:
	_checkpoint_scheduled = false
	if _pending_cleared_waves.is_empty():
		return
	_pending_cleared_waves.sort()
	var wave_number: int = int(_pending_cleared_waves.back())
	_pending_cleared_waves.clear()
	capture_automatic_checkpoint(wave_number, "wave_cleared")


func _on_startup_completed(snapshot: Dictionary) -> void:
	if _launched_for_load or not bool(snapshot.get("formal_loop_started", false)):
		return
	call_deferred("capture_automatic_checkpoint", 0, "formal_start")


func _on_epilogue_changed(snapshot: Dictionary) -> void:
	if not _pending_final_checkpoint or not _is_epilogue_settled({"epilogue": snapshot}):
		return
	_pending_final_checkpoint = false
	call_deferred("capture_automatic_checkpoint", _get_checkpoint_wave(), "final_wave_epilogue_settled")


func _is_epilogue_settled(settlement: Dictionary) -> bool:
	var epilogue: Dictionary = settlement.get("epilogue", {}) if settlement.get("epilogue", {}) is Dictionary else {}
	return ["llm", "template_fallback"].has(str(epilogue.get("status", "")))


func _get_checkpoint_wave() -> int:
	var combat := _system("CombatSystem")
	if combat == null:
		return 0
	var schedule: Dictionary = combat.get_wave_schedule_snapshot()
	var waves: Array = schedule.get("triggered_wave_numbers", [])
	var result := 0
	for raw_wave in waves:
		result = maxi(result, int(raw_wave))
	return result


func _mark_runtime_ahead() -> void:
	if not _restoring:
		_runtime_ahead_of_checkpoint = true


func _connect_dirty_signal(event_bus: Node, signal_name: String, argument_count: int) -> void:
	if event_bus.has_signal(signal_name):
		event_bus.connect(signal_name, _mark_runtime_ahead.unbind(argument_count))


func _peek_launch_request() -> Dictionary:
	var tree := get_tree()
	if tree != null and tree.has_meta(MAIN_LAUNCH_REQUEST_META):
		var request: Variant = tree.get_meta(MAIN_LAUNCH_REQUEST_META)
		if request is Dictionary:
			return (request as Dictionary).duplicate(true)
	return {}


func _system(name: String) -> Node:
	return get_node_or_null(SYSTEM_ROOT + name)


func _section(source: Dictionary, key: String) -> Dictionary:
	return (source.get(key, {}) as Dictionary).duplicate(true) if source.get(key, {}) is Dictionary else {}


func _store_result(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)


func _store_restore(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	restore_completed.emit(result.duplicate(true))
	return _last_result.duplicate(true)
