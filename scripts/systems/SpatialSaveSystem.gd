extends Node

const CHECKPOINT_SCHEMA := "formal_spatial_save_v1"
const DEFAULT_CHECKPOINT_PATH := "user://formal_spatial_checkpoint.json"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const MERCHANT_SYSTEM_PATH := "/root/Main/Systems/MerchantSystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const STATION_LAYOUT_CONTROLLER_PATH := "/root/Main/Presentation/StationLayoutController"

var _last_result: Dictionary = {}


func save_formal_spatial_checkpoint(path: String = DEFAULT_CHECKPOINT_PATH) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if (
		npc_system == null
		or combat_system == null
		or merchant_system == null
		or not npc_system.has_method("create_formal_spatial_checkpoint")
		or not combat_system.has_method("create_formal_spatial_checkpoint")
		or not merchant_system.has_method("create_formal_spatial_checkpoint")
	):
		return _store_result({"ok": false, "operation": "save", "reason": "spatial_save_dependencies_missing"})
	var game_state := get_node_or_null("/root/GameState")
	var checkpoint := {
		"schema": CHECKPOINT_SCHEMA,
		"task": "T0129C-A5-P8",
		"saved_unix_time": int(Time.get_unix_time_from_system()),
		"game_time": {
			"day": int(game_state.current_day) if game_state != null else 1,
			"hour": int(game_state.current_hour) if game_state != null else 0,
			"minute": int(game_state.current_minute) if game_state != null else 0,
			"second": int(game_state.current_second) if game_state != null else 0
		},
		"npc_spatial": npc_system.create_formal_spatial_checkpoint(),
		"combat_spatial": combat_system.create_formal_spatial_checkpoint(),
		"merchant_spatial": merchant_system.create_formal_spatial_checkpoint(),
		"transaction_policy": "in_flight_actions_rollback_without_duplicate_events"
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _store_result({
			"ok": false,
			"operation": "save",
			"reason": "checkpoint_open_failed",
			"path": path,
			"file_error": FileAccess.get_open_error()
		})
	file.store_string(JSON.stringify(checkpoint, "\t"))
	file.close()
	return _store_result({
		"ok": true,
		"operation": "save",
		"path": path,
		"schema": CHECKPOINT_SCHEMA,
		"npc_count": int((checkpoint["npc_spatial"] as Dictionary).get("actor_count", 0)),
		"enemy_count": int((checkpoint["combat_spatial"] as Dictionary).get("enemy_count", 0)),
		"merchant_state": str((checkpoint["merchant_spatial"] as Dictionary).get("wagon_state", "absent"))
	})


func load_formal_spatial_checkpoint(path: String = DEFAULT_CHECKPOINT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _store_result({"ok": false, "operation": "load", "reason": "checkpoint_missing", "path": path})
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _store_result({"ok": false, "operation": "load", "reason": "checkpoint_open_failed", "path": path})
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return _store_result({"ok": false, "operation": "load", "reason": "checkpoint_json_invalid", "path": path})
	var checkpoint := parsed as Dictionary
	if str(checkpoint.get("schema", "")) != CHECKPOINT_SCHEMA:
		return _store_result({"ok": false, "operation": "load", "reason": "checkpoint_schema_mismatch", "path": path})

	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if controller == null or npc_system == null or combat_system == null or merchant_system == null:
		return _store_result({"ok": false, "operation": "load", "reason": "spatial_load_dependencies_missing", "path": path})
	if controller.has_method("set_runtime_formal_world_enabled"):
		controller.set_runtime_formal_world_enabled(true)
	if controller.has_method("force_sync_production_navigation"):
		controller.force_sync_production_navigation()
	var navigation_snapshot: Dictionary = controller.debug_get_production_navigation_snapshot() if controller.has_method("debug_get_production_navigation_snapshot") else {}
	if (
		not bool(navigation_snapshot.get("available", false))
		or not bool(navigation_snapshot.get("dedicated_navigation_map", false))
		or not bool(navigation_snapshot.get("enabled", false))
	):
		return _store_result({"ok": false, "operation": "load", "reason": "production_navigation_not_ready", "navigation": navigation_snapshot})

	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null and dialog_system.has_method("end_dialogue"):
		dialog_system.end_dialogue("save_restore_rollback", {"suppress_plan_resume": true})
	var npc_checkpoint: Dictionary = checkpoint.get("npc_spatial", {}) if checkpoint.get("npc_spatial", {}) is Dictionary else {}
	var npc_result: Dictionary = npc_system.restore_formal_spatial_checkpoint(npc_checkpoint)
	if not bool(npc_result.get("ok", false)):
		return _store_result({"ok": false, "operation": "load", "reason": "npc_spatial_restore_failed", "npc_result": npc_result})
	var combat_result: Dictionary = combat_system.restore_formal_spatial_checkpoint(
		checkpoint.get("combat_spatial", {}) if checkpoint.get("combat_spatial", {}) is Dictionary else {}
	)
	if not bool(combat_result.get("ok", false)):
		return _store_result({"ok": false, "operation": "load", "reason": "combat_spatial_restore_failed", "npc_result": npc_result, "combat_result": combat_result})
	var escape_result: Dictionary = combat_system.restore_formal_escape_sessions_from_npc_checkpoint(npc_checkpoint)
	if not bool(escape_result.get("ok", false)):
		return _store_result({"ok": false, "operation": "load", "reason": "escape_spatial_restore_failed", "npc_result": npc_result, "combat_result": combat_result, "escape_result": escape_result})
	var merchant_result: Dictionary = merchant_system.restore_formal_spatial_checkpoint(
		checkpoint.get("merchant_spatial", {}) if checkpoint.get("merchant_spatial", {}) is Dictionary else {}
	)
	if not bool(merchant_result.get("ok", false)):
		return _store_result({"ok": false, "operation": "load", "reason": "merchant_spatial_restore_failed", "npc_result": npc_result, "combat_result": combat_result, "escape_result": escape_result, "merchant_result": merchant_result})
	return _store_result({
		"ok": true,
		"operation": "load",
		"path": path,
		"schema": CHECKPOINT_SCHEMA,
		"navigation_ready_before_restore": true,
		"npc_result": npc_result,
		"combat_result": combat_result,
		"escape_result": escape_result,
		"merchant_result": merchant_result
	})


func debug_save_formal_spatial_checkpoint() -> Dictionary:
	return save_formal_spatial_checkpoint()


func debug_load_formal_spatial_checkpoint() -> Dictionary:
	return load_formal_spatial_checkpoint()


func debug_get_formal_spatial_checkpoint_snapshot() -> Dictionary:
	return {
		"schema": CHECKPOINT_SCHEMA,
		"default_path": DEFAULT_CHECKPOINT_PATH,
		"file_exists": FileAccess.file_exists(DEFAULT_CHECKPOINT_PATH),
		"last_result": _last_result.duplicate(true)
	}


func _store_result(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
