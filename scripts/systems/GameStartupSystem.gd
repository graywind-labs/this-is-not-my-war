extends Node

signal startup_completed(snapshot: Dictionary)

enum StartupMode {
	STATIC_DEBUG,
	GAMEPLAY_NO_TUTORIAL,
	GAMEPLAY_WITH_TUTORIAL
}

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const DAILY_PLAN_SYSTEM_PATH := "/root/Main/Systems/DailyPlanSystem"
const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"

@export_enum(
	"静止调试",
	"正式循环（无新手引导）",
	"正式循环（新手引导占位）"
) var startup_mode: int = StartupMode.GAMEPLAY_NO_TUTORIAL

var _startup_running := false
var _startup_applied := false
var _startup_snapshot: Dictionary = {}


func _ready() -> void:
	_reset_startup_snapshot(_normalize_startup_mode(startup_mode))
	var daily_plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if (
		daily_plan_system != null
		and daily_plan_system.has_signal("async_daily_plan_batch_completed")
		and not daily_plan_system.async_daily_plan_batch_completed.is_connected(_on_async_daily_plan_batch_completed)
	):
		daily_plan_system.async_daily_plan_batch_completed.connect(_on_async_daily_plan_batch_completed)
	if DisplayServer.get_name() == "headless":
		_startup_snapshot["status"] = "auto_start_skipped_headless"
		return
	call_deferred("_apply_configured_startup_mode")


func apply_startup_mode(
	mode: int = startup_mode,
	force: bool = false,
	prefer_llm: bool = true
) -> Dictionary:
	var normalized_mode := _normalize_startup_mode(mode)
	if _startup_running:
		return _failure("startup_in_progress", "游戏启动流程仍在进行中。")
	if _startup_applied and not force:
		return _failure("startup_already_applied", "游戏启动模式已经应用。")

	startup_mode = normalized_mode
	_reset_startup_snapshot(normalized_mode)
	if normalized_mode == StartupMode.STATIC_DEBUG:
		var daily_plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
		if daily_plan_system != null and daily_plan_system.has_method("set_auto_execution_enabled"):
			daily_plan_system.set_auto_execution_enabled(false)
		var time_system := get_node_or_null(TIME_SYSTEM_PATH)
		if time_system != null and time_system.has_method("set_paused"):
			time_system.set_paused(true)
		_startup_applied = true
		_startup_snapshot["status"] = "static_debug_ready"
		_startup_snapshot["completed"] = true
		startup_completed.emit(_startup_snapshot.duplicate(true))
		return _startup_snapshot.duplicate(true)

	_startup_running = true
	_startup_snapshot["running"] = true
	_startup_snapshot["status"] = "starting_formal_loop"
	_startup_snapshot["prefer_llm"] = prefer_llm
	_run_formal_startup(prefer_llm)
	return _startup_snapshot.duplicate(true)


func get_startup_snapshot() -> Dictionary:
	return _startup_snapshot.duplicate(true)


func get_startup_mode_label(mode: int = startup_mode) -> String:
	match _normalize_startup_mode(mode):
		StartupMode.STATIC_DEBUG:
			return "静止调试"
		StartupMode.GAMEPLAY_WITH_TUTORIAL:
			return "正式循环（新手引导占位）"
		_:
			return "正式循环（无新手引导）"


func debug_apply_startup_mode(
	mode: int,
	force: bool = true,
	prefer_llm: bool = false
) -> Dictionary:
	return apply_startup_mode(mode, force, prefer_llm)


func debug_get_startup_snapshot() -> Dictionary:
	return get_startup_snapshot()


func _apply_configured_startup_mode() -> void:
	apply_startup_mode(startup_mode, false, true)


func _run_formal_startup(prefer_llm: bool) -> void:
	await get_tree().process_frame

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var daily_plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if (
		npc_system == null
		or not npc_system.has_method("get_npc_ids")
		or daily_plan_system == null
		or not daily_plan_system.has_method("begin_new_day_planning_for_npc")
	):
		_finish_with_failure("missing_startup_system", "正式循环缺少 NPCSystem 或 DailyPlanSystem。")
		return

	if daily_plan_system.has_method("set_auto_execution_enabled"):
		daily_plan_system.set_auto_execution_enabled(false)
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(true)

	var npc_ids: Array[String] = npc_system.get_npc_ids()
	var results := {}
	var planning_count := 0
	for npc_id in npc_ids:
		var result: Dictionary = daily_plan_system.begin_new_day_planning_for_npc(npc_id, "game_start")
		results[npc_id] = result.duplicate(true)
		if bool(result.get("ok", false)):
			planning_count += 1
		_startup_snapshot["planning_npc_count"] = planning_count
		_startup_snapshot["npc_results"] = results.duplicate(true)
		await get_tree().process_frame

	_startup_snapshot["npc_count"] = npc_ids.size()
	_startup_snapshot["planning_npc_count"] = planning_count
	_startup_snapshot["npc_results"] = results.duplicate(true)
	if planning_count != npc_ids.size():
		_finish_with_failure("npc_planning_start_failed", "部分 NPC 无法进入每日计划制定状态。")
		return

	if prefer_llm and daily_plan_system.has_method("request_daily_plans_async"):
		var async_plan_result: Dictionary = daily_plan_system.request_daily_plans_async(
			npc_ids,
			"game_start",
			false,
			8,
			true,
			3
		)
		if not _startup_running:
			return
		_startup_snapshot["async_llm_plan_requested"] = true
		_startup_snapshot["async_llm_plan_batch"] = async_plan_result.duplicate(true)
		if bool(async_plan_result.get("ok", false)):
			_startup_snapshot["status"] = "awaiting_daily_plans"
			return
		_finish_with_failure(
			str(async_plan_result.get("status", "daily_plan_batch_start_failed")),
			str(async_plan_result.get("message", "正式开局无法启动真实 LLM 每日计划批次。"))
		)
		return
	if prefer_llm:
		_finish_with_failure(
			"async_llm_unavailable",
			"正式开局缺少真实 LLM 异步每日计划接口。"
		)
		return

	# 纯规则计划只保留给显式 debug_apply_startup_mode(..., prefer_llm=false)。
	var rule_results := {}
	for npc_id in npc_ids:
		var plan: Array = daily_plan_system.generate_rule_plan_for_npc(npc_id)
		rule_results[npc_id] = {
			"ok": plan.size() == 24,
			"npc_id": npc_id,
			"status": "rule_plan_applied",
			"source": "rule_default",
			"fallback_used": false,
			"plan": plan.duplicate(true)
		}
	_finalize_formal_startup(npc_ids, rule_results, {
		"ok": true,
		"status": "rule_only",
		"requested_count": npc_ids.size(),
		"completed_count": npc_ids.size(),
		"succeeded_count": npc_ids.size(),
		"failed_count": 0,
		"plans_ready": true,
		"results": rule_results.duplicate(true)
	}, false)


func _on_async_daily_plan_batch_completed(batch_snapshot: Dictionary) -> void:
	if not _startup_running or str(batch_snapshot.get("reason", "")) != "game_start":
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		_finish_with_failure("missing_npc_system", "每日计划完成时 NPCSystem 不可用。")
		return
	var npc_ids: Array[String] = npc_system.get_npc_ids()
	_startup_snapshot["async_llm_plan_batch"] = batch_snapshot.duplicate(true)
	if (
		not bool(batch_snapshot.get("ok", false))
		or int(batch_snapshot.get("failed_count", 0)) > 0
		or not bool(batch_snapshot.get("plans_ready", false))
	):
		_finish_with_failure(
			"daily_plan_batch_failed",
			"正式开局每日计划存在真实 LLM 失败；游戏保持暂停，未使用 Mock 或规则降级。"
		)
		return
	_finalize_formal_startup(
		npc_ids,
		batch_snapshot.get("results", {}),
		batch_snapshot,
		true
	)


func _finalize_formal_startup(
	npc_ids: Array[String],
	plan_results: Dictionary,
	batch_snapshot: Dictionary,
	require_real_plans: bool = true
) -> void:
	var daily_plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if daily_plan_system == null:
		_finish_with_failure("missing_daily_plan_system", "每日计划完成后 DailyPlanSystem 不可用。")
		return

	var completed_count := 0
	for npc_id in npc_ids:
		var plan: Array = daily_plan_system.get_npc_daily_plan(npc_id)
		var result: Dictionary = plan_results.get(npc_id, {})
		var all_llm_source := plan.size() == 24
		for raw_item in plan:
			if not raw_item is Dictionary or str((raw_item as Dictionary).get("source", "")) != "llm_plan_day":
				all_llm_source = false
				break
		if not require_real_plans and plan.size() == 24:
			completed_count += 1
		elif (
			require_real_plans
			and all_llm_source
			and bool(result.get("ok", false))
			and str(result.get("source", "")) == "llm_plan_day"
			and not bool(result.get("fallback_used", false))
		):
			completed_count += 1
	if completed_count != npc_ids.size():
		_finish_with_failure("daily_plans_incomplete", "并非所有 NPC 都完成了真实 LLM 24 小时计划。")
		return

	if daily_plan_system.has_method("set_auto_execution_enabled"):
		daily_plan_system.set_auto_execution_enabled(true)
	var execute_results: Dictionary = daily_plan_system.execute_current_plan_for_all(true)
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)

	_startup_running = false
	_startup_applied = true
	_startup_snapshot["running"] = false
	_startup_snapshot["completed"] = true
	_startup_snapshot["formal_loop_started"] = true
	_startup_snapshot["status"] = "formal_loop_started"
	_startup_snapshot["npc_count"] = npc_ids.size()
	_startup_snapshot["completed_npc_count"] = completed_count
	_startup_snapshot["plan_results"] = plan_results.duplicate(true)
	_startup_snapshot["execute_results"] = execute_results.duplicate(true)
	_startup_snapshot["async_llm_plan_batch"] = batch_snapshot.duplicate(true)
	startup_completed.emit(_startup_snapshot.duplicate(true))


func _finish_with_failure(error_code: String, message: String) -> void:
	var daily_plan_system := get_node_or_null(DAILY_PLAN_SYSTEM_PATH)
	if daily_plan_system != null and daily_plan_system.has_method("set_auto_execution_enabled"):
		daily_plan_system.set_auto_execution_enabled(false)
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(true)
	_startup_running = false
	_startup_applied = true
	_startup_snapshot["ok"] = false
	_startup_snapshot["running"] = false
	_startup_snapshot["completed"] = true
	_startup_snapshot["formal_loop_started"] = false
	_startup_snapshot["status"] = "failed"
	_startup_snapshot["error_code"] = error_code
	_startup_snapshot["message"] = message
	startup_completed.emit(_startup_snapshot.duplicate(true))


func _reset_startup_snapshot(mode: int) -> void:
	var tutorial_requested := mode == StartupMode.GAMEPLAY_WITH_TUTORIAL
	_startup_snapshot = {
		"ok": true,
		"mode": mode,
		"mode_label": get_startup_mode_label(mode),
		"running": false,
		"completed": false,
		"formal_loop_started": false,
		"tutorial_requested": tutorial_requested,
		"tutorial_status": "placeholder_not_implemented" if tutorial_requested else "disabled",
		"npc_count": 0,
		"planning_npc_count": 0,
		"completed_npc_count": 0,
		"npc_results": {},
		"plan_results": {},
		"execute_results": {},
		"async_llm_plan_requested": false,
		"async_llm_plan_batch": {},
		"status": "ready"
	}


func _normalize_startup_mode(mode: int) -> int:
	if mode < StartupMode.STATIC_DEBUG or mode > StartupMode.GAMEPLAY_WITH_TUTORIAL:
		return StartupMode.GAMEPLAY_NO_TUTORIAL
	return mode


func _failure(error_code: String, message: String) -> Dictionary:
	var result := _startup_snapshot.duplicate(true)
	result["ok"] = false
	result["error_code"] = error_code
	result["message"] = message
	return result
