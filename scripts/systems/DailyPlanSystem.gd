extends Node

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const PLAZA_LOCATION_ID := "plaza"
const RULE_SOURCE := "rule_default"
const MOCK_PLAN_SOURCE := "mock_plan_day"
const PLAN_FALLBACK_SOURCE := "rule_plan_fallback"
const REVISION_SOURCE := "mock_revision"
const FALLBACK_REVISION_SOURCE := "rule_revision_fallback"
const IDLE_ACTION_ID := "idle"

const SKILL_TO_WORK_ACTION := {
	"养马": "work_stable",
	"厨艺": "work_dining_hall",
	"耕种": "work_garden",
	"打铁": "work_blacksmith",
	"教练": "work_garden",
	"酿酒": "work_tavern",
	"医术": "work_clinic_doctor",
	"工程": "work_workshop"
}

var auto_execution_enabled := true
var _plans_by_npc: Dictionary = {}
var _last_completed_result_by_npc: Dictionary = {}
var _last_failure_result_by_npc: Dictionary = {}
var _plan_owned_action_by_npc: Dictionary = {}
var _last_plan_generation_result: Dictionary = {}
var _last_reevaluation_result: Dictionary = {}
var _reevaluating_npcs: Dictionary = {}


func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.day_started.connect(_on_day_started)
		event_bus.hour_started.connect(_on_hour_started)
		event_bus.npc_state_changed.connect(_on_npc_state_changed)
		event_bus.npc_plan_reevaluation_requested.connect(_on_plan_reevaluation_requested)


func set_auto_execution_enabled(enabled: bool) -> void:
	auto_execution_enabled = enabled


func generate_all_rule_plans() -> Dictionary:
	var result := {}
	var npc_system := _get_npc_system()
	if npc_system == null:
		return result
	for npc_id in npc_system.get_npc_ids():
		result[str(npc_id)] = generate_rule_plan_for_npc(str(npc_id))
	return result


func generate_rule_plan_for_npc(npc_id: String) -> Array:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return []
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return []

	var work_action_id := _choose_rule_work_action(npc)
	var plan: Array = []
	for hour in range(24):
		var action_id := _choose_rule_action_for_hour(hour, work_action_id)
		plan.append(_make_plan_item(hour, action_id, "按规则日程安排。"))

	set_npc_daily_plan(npc_id, plan, true)
	return plan.duplicate(true)


func generate_daily_plan_for_npc(npc_id: String, execute_current: bool = false) -> Dictionary:
	var npc_system := _get_npc_system()
	if npc_system == null or npc_system.get_npc(npc_id).is_empty():
		return _plan_generation_result(false, npc_id, "unknown_npc", "", true, [], {}, {})

	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge != null and llm_bridge.has_method("request_npc_daily_plan"):
		var request_result: Dictionary = llm_bridge.request_npc_daily_plan(npc_id, {
			"planning_rules": _daily_planning_rules()
		})
		if bool(request_result.get("ok", false)):
			var apply_result := _apply_daily_plan_response(npc_id, request_result.get("daily_plan", {}), execute_current)
			apply_result["request_result"] = request_result.duplicate(true)
			_record_plan_generation_result(npc_id, apply_result)
			return apply_result
		if _is_request_cancelled(request_result):
			var cancelled_result := _plan_generation_result(false, npc_id, "request_cancelled", "每日计划请求被玩家对话打断。", false, [], request_result, {})
			_record_plan_generation_result(npc_id, cancelled_result)
			return cancelled_result
		var fallback_result := _apply_rule_plan_fallback(npc_id, "每日计划请求失败：%s" % str(request_result.get("message", "后端不可用。")), execute_current, request_result)
		_record_plan_generation_result(npc_id, fallback_result)
		return fallback_result

	var missing_result := _apply_rule_plan_fallback(npc_id, "LLMBridge 不可用。", execute_current, {})
	_record_plan_generation_result(npc_id, missing_result)
	return missing_result


func get_last_plan_generation_result() -> Dictionary:
	return _last_plan_generation_result.duplicate(true)


func set_npc_daily_plan(npc_id: String, plan: Array, record_event: bool = true, source: String = RULE_SOURCE) -> bool:
	var normalized_plan := _normalize_plan(plan, source)
	if normalized_plan.size() != 24:
		push_warning("Daily plan must contain 24 hourly items for NPC: %s" % npc_id)
		return false

	var npc_system := _get_npc_system()
	if npc_system == null or not npc_system.has_method("set_npc_plan"):
		return false
	if not npc_system.set_npc_plan(npc_id, normalized_plan):
		return false

	_plans_by_npc[npc_id] = normalized_plan.duplicate(true)
	if record_event:
		_log_plan_created(npc_id, normalized_plan, source)
	return true


func get_npc_daily_plan(npc_id: String) -> Array:
	if _plans_by_npc.has(npc_id):
		return (_plans_by_npc[npc_id] as Array).duplicate(true)
	var npc_system := _get_npc_system()
	if npc_system == null or not npc_system.has_method("get_npc_plan"):
		return []
	var plan: Array = npc_system.get_npc_plan(npc_id)
	if plan.size() == 24:
		_plans_by_npc[npc_id] = plan.duplicate(true)
	return plan.duplicate(true)


func get_current_plan_item(npc_id: String) -> Dictionary:
	var plan := get_npc_daily_plan(npc_id)
	if plan.is_empty():
		return {}
	var hour := _get_current_hour()
	if hour < 0 or hour >= plan.size():
		return {}
	var item: Dictionary = plan[hour]
	return item.duplicate(true)


func get_last_reevaluation_result() -> Dictionary:
	return _last_reevaluation_result.duplicate(true)


func execute_current_plan_for_all(force_interrupt: bool = false) -> Dictionary:
	var result := {}
	var npc_system := _get_npc_system()
	if npc_system == null:
		return result
	for npc_id in npc_system.get_npc_ids():
		result[str(npc_id)] = execute_current_plan_for_npc(str(npc_id), force_interrupt)
	return result


func execute_current_plan_for_npc(npc_id: String, force_interrupt: bool = false) -> Dictionary:
	var item := get_current_plan_item(npc_id)
	if item.is_empty():
		return _result(false, npc_id, "", "no_plan_item")
	var action_id := str(item.get("action_id", ""))
	if action_id.is_empty():
		return _result(false, npc_id, "", "empty_action")

	var npc_system := _get_npc_system()
	var action_system := _get_action_system()
	if npc_system == null or action_system == null:
		return _result(false, npc_id, action_id, "missing_system")
	if not npc_system.can_npc_act(npc_id):
		return _result(false, npc_id, action_id, "npc_cannot_act")

	if _is_plan_target_unavailable(item):
		return request_plan_reevaluation(npc_id, "target_unavailable", item, "目标建筑不可用。")

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var current_action := str(state.get("current_action", ""))
	var runtime_action_id := ""
	if action_system.has_method("get_runtime_action_id"):
		runtime_action_id = str(action_system.get_runtime_action_id(npc_id))
	if runtime_action_id == action_id or current_action == action_id:
		return _result(true, npc_id, action_id, "already_running")

	var is_idle := current_action == "idle" or current_action.is_empty()
	if not is_idle and force_interrupt and action_system.has_method("interrupt_npc_action"):
		action_system.interrupt_npc_action(npc_id, "plan_hour_changed")
	elif not is_idle and not force_interrupt:
		return _result(false, npc_id, action_id, "npc_busy")

	var ok := _assign_plan_item(npc_id, item)
	if ok:
		_plan_owned_action_by_npc[npc_id] = action_id
	else:
		_plan_owned_action_by_npc.erase(npc_id)
	return _result(ok, npc_id, action_id, "started" if ok else "assign_failed")


func request_plan_reevaluation(
	npc_id: String,
	reason: String,
	failed_item: Dictionary = {},
	failure_summary: String = ""
) -> Dictionary:
	if _reevaluating_npcs.has(npc_id):
		return _result(false, npc_id, str(failed_item.get("action_id", "")), "reevaluation_already_running")

	var npc_system := _get_npc_system()
	if npc_system == null or npc_system.get_npc(npc_id).is_empty():
		return _result(false, npc_id, "", "unknown_npc")
	var current_plan := get_npc_daily_plan(npc_id)
	if current_plan.is_empty():
		current_plan = generate_rule_plan_for_npc(npc_id)
	if failed_item.is_empty():
		failed_item = get_current_plan_item(npc_id)
	if failure_summary.is_empty():
		failure_summary = _describe_reevaluation_reason(reason, failed_item)

	var failure_type := _normalize_failure_type(reason)
	var result := {
		"ok": false,
		"npc_id": npc_id,
		"reason": reason,
		"failure_type": failure_type,
		"failure_summary": failure_summary,
		"source": "",
		"fallback_used": false,
		"status": "pending",
		"request_result": {},
		"execute_result": {}
	}
	_reevaluating_npcs[npc_id] = true
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge != null and llm_bridge.has_method("request_npc_plan_revision"):
		var request_result: Dictionary = llm_bridge.request_npc_plan_revision(npc_id, {
			"current_plan": current_plan,
			"failed_plan_item": failed_item,
			"failure_type": failure_type,
			"failure_summary": failure_summary
		})
		result["request_result"] = request_result.duplicate(true)
		if bool(request_result.get("ok", false)):
			var apply_result := _apply_revision_response(npc_id, request_result.get("plan_revision", {}), reason, current_plan)
			for key in apply_result.keys():
				result[key] = apply_result[key]
		elif _is_request_cancelled(request_result):
			result["status"] = "request_cancelled"
			result["summary"] = "计划修订请求被玩家对话打断。"
			result["fallback_used"] = false
		else:
			var fallback_result := _apply_rule_fallback_revision(npc_id, reason, current_plan, str(request_result.get("message", "计划修订请求失败。")))
			for key in fallback_result.keys():
				result[key] = fallback_result[key]
	else:
		var missing_result := _apply_rule_fallback_revision(npc_id, reason, current_plan, "LLMBridge 不可用。")
		for key in missing_result.keys():
			result[key] = missing_result[key]

	_reevaluating_npcs.erase(npc_id)
	_record_reevaluation_result(npc_id, reason, result)
	return result


func debug_generate_plan(npc_id: String = "") -> Dictionary:
	if npc_id.is_empty() or npc_id == "all":
		var result := {}
		var npc_system := _get_npc_system()
		if npc_system == null:
			return result
		for raw_npc_id in npc_system.get_npc_ids():
			result[str(raw_npc_id)] = generate_daily_plan_for_npc(str(raw_npc_id), false)
		return result
	return generate_daily_plan_for_npc(npc_id, false)


func debug_generate_rule_plan(npc_id: String = "") -> Dictionary:
	if npc_id.is_empty() or npc_id == "all":
		return generate_all_rule_plans()
	return {"npc_id": npc_id, "plan": generate_rule_plan_for_npc(npc_id)}


func debug_get_plan(npc_id: String) -> Array:
	return get_npc_daily_plan(npc_id)


func debug_execute_current_plan(npc_id: String = "", force_interrupt: bool = true) -> Dictionary:
	if npc_id.is_empty() or npc_id == "all":
		return execute_current_plan_for_all(force_interrupt)
	return execute_current_plan_for_npc(npc_id, force_interrupt)


func debug_request_reevaluation(npc_id: String, reason: String = "gm_manual") -> Dictionary:
	return request_plan_reevaluation(npc_id, reason, get_current_plan_item(npc_id), "GM 调试触发计划重评估。")


func _on_day_started(_day: int) -> void:
	var npc_ids: Array = _plans_by_npc.keys()
	for raw_npc_id in npc_ids:
		generate_daily_plan_for_npc(str(raw_npc_id), false)


func _on_hour_started(_day: int, _hour: int) -> void:
	if not auto_execution_enabled:
		return
	execute_current_plan_for_all(true)


func _on_npc_state_changed(npc_id: String) -> void:
	if not auto_execution_enabled:
		return
	if _reevaluating_npcs.has(npc_id):
		return
	var npc_system := _get_npc_system()
	if npc_system == null:
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("current_action", "")) != "idle":
		return
	var last_result := str(state.get("last_action_result", ""))
	if _is_failure_result(last_result):
		if str(_last_failure_result_by_npc.get(npc_id, "")) == last_result:
			return
		_last_failure_result_by_npc[npc_id] = last_result
		request_plan_reevaluation(npc_id, last_result, get_current_plan_item(npc_id), _describe_action_failure(npc_id, last_result))
		return
	if not last_result.begins_with("completed_"):
		return
	if not _plan_owned_action_by_npc.has(npc_id):
		return
	if str(_last_completed_result_by_npc.get(npc_id, "")) == last_result:
		return
	_last_completed_result_by_npc[npc_id] = last_result
	_plan_owned_action_by_npc.erase(npc_id)
	execute_current_plan_for_npc(npc_id, false)


func _on_plan_reevaluation_requested(npc_id: String, reason: String) -> void:
	request_plan_reevaluation(npc_id, reason, get_current_plan_item(npc_id), _describe_reevaluation_reason(reason, get_current_plan_item(npc_id)))


func _normalize_plan(plan: Array, source: String = RULE_SOURCE) -> Array:
	var normalized: Array = []
	for hour in range(24):
		var source_item: Dictionary = {}
		if hour < plan.size() and plan[hour] is Dictionary:
			source_item = plan[hour]
		var action_id := str(source_item.get("action_id", ""))
		if not _is_supported_plan_action(action_id):
			return []
		normalized.append(_make_plan_item(
			hour,
			action_id,
			str(source_item.get("reason", "")),
			str(source_item.get("source", source)),
			source_item.get("target", {})
		))
	return normalized


func _make_plan_item(
	hour: int,
	action_id: String,
	reason: String,
	source: String = RULE_SOURCE,
	target: Variant = {}
) -> Dictionary:
	return {
		"hour": clampi(hour, 0, 23),
		"action_id": action_id,
		"action_name": _get_action_name(action_id),
		"source": source,
		"target": target if target is Dictionary else {},
		"reason": reason
	}


func _choose_rule_action_for_hour(hour: int, work_action_id: String) -> String:
	if hour >= 0 and hour <= 5:
		return "sleep_in_dormitory"
	if hour == 6 or hour == 12 or hour == 18:
		return "eat_at_dining_hall"
	if (hour >= 7 and hour <= 11) or (hour >= 13 and hour <= 17):
		return work_action_id
	if hour >= 22:
		return "sleep_in_dormitory"
	return work_action_id


func _choose_revision_fallback_action(npc_id: String, reason: String, failed_action_id: String = "") -> String:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return IDLE_ACTION_ID
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if int(state.get("satiety", 100)) <= 25 and _is_supported_plan_action("eat_at_dining_hall"):
		return "eat_at_dining_hall"
	if int(state.get("fatigue", 0)) >= 80 and _is_supported_plan_action("sleep_in_dormitory"):
		return "sleep_in_dormitory"
	if failed_action_id != "work_garden" and _is_supported_plan_action("work_garden"):
		return "work_garden"
	return IDLE_ACTION_ID


func _apply_revision_response(npc_id: String, revision: Dictionary, reason: String, current_plan: Array) -> Dictionary:
	var merged_plan := _merge_revision_items(current_plan, revision)
	if merged_plan.is_empty():
		return _apply_rule_fallback_revision(npc_id, reason, current_plan, "计划修订响应没有可用行动。")
	if not set_npc_daily_plan(npc_id, merged_plan, false):
		return _apply_rule_fallback_revision(npc_id, reason, current_plan, "计划修订响应未通过本地校验。")

	var summary := str(revision.get("summary", "Mock 修订了当前计划。"))
	_log_plan_revised(npc_id, merged_plan, reason, REVISION_SOURCE, summary)
	var execute_result := execute_current_plan_for_npc(npc_id, true)
	return {
		"ok": true,
		"status": "mock_revision_applied",
		"source": REVISION_SOURCE,
		"fallback_used": false,
		"summary": summary,
		"revised_plan": merged_plan.duplicate(true),
		"execute_result": execute_result
	}


func _apply_daily_plan_response(npc_id: String, response: Dictionary, execute_current: bool) -> Dictionary:
	var raw_schema_plan: Variant = response.get("plan", [])
	var plan: Array = []
	if not raw_schema_plan is Array:
		return _apply_rule_plan_fallback(npc_id, "每日计划响应缺少 plan 数组。", execute_current, {"body": response})
	var schema_plan: Array = raw_schema_plan
	for raw_item in schema_plan:
		if not raw_item is Dictionary:
			return _apply_rule_plan_fallback(npc_id, "每日计划响应包含非法计划项。", execute_current, {"body": response})
		var item := _plan_item_from_schema(raw_item, MOCK_PLAN_SOURCE)
		if item.is_empty():
			return _apply_rule_plan_fallback(npc_id, "每日计划响应包含不可执行行动。", execute_current, {"body": response})
		plan.append(item)
	plan = _normalize_plan(plan, MOCK_PLAN_SOURCE)
	if plan.size() != 24:
		return _apply_rule_plan_fallback(npc_id, "每日计划响应不是 24 个小时项。", execute_current, {"body": response})
	if _count_work_phases(plan) < 6:
		return _apply_rule_plan_fallback(npc_id, "每日计划响应工作阶段少于 6 个。", execute_current, {"body": response})
	if not set_npc_daily_plan(npc_id, plan, true, MOCK_PLAN_SOURCE):
		return _apply_rule_plan_fallback(npc_id, "每日计划响应未通过本地校验。", execute_current, {"body": response})
	var execute_result := {}
	if execute_current:
		execute_result = execute_current_plan_for_npc(npc_id, true)
	return _plan_generation_result(
		true,
		npc_id,
		"mock_plan_applied",
		str(response.get("summary", "Mock 生成了每日计划。")),
		false,
		plan,
		response,
		execute_result
	)


func _apply_rule_plan_fallback(npc_id: String, summary: String, execute_current: bool, request_result: Dictionary) -> Dictionary:
	var plan := _build_rule_plan_for_npc(npc_id, PLAN_FALLBACK_SOURCE, "规则降级：%s" % summary)
	set_npc_daily_plan(npc_id, plan, true, PLAN_FALLBACK_SOURCE)
	var execute_result := {}
	if execute_current:
		execute_result = execute_current_plan_for_npc(npc_id, true)
	return _plan_generation_result(
		true,
		npc_id,
		"rule_plan_fallback_applied",
		summary,
		true,
		plan,
		request_result,
		execute_result
	)


func _is_request_cancelled(result: Dictionary) -> bool:
	return bool(result.get("cancelled", false)) or str(result.get("error_code", "")) == "request_cancelled"


func _apply_rule_fallback_revision(npc_id: String, reason: String, current_plan: Array, fallback_reason: String) -> Dictionary:
	var source_plan := current_plan.duplicate(true)
	if source_plan.size() != 24:
		source_plan = _normalize_plan(source_plan)
	if source_plan.size() != 24:
		source_plan = generate_rule_plan_for_npc(npc_id)
	var hour := _get_current_hour()
	var failed_item: Dictionary = source_plan[hour] if hour >= 0 and hour < source_plan.size() and source_plan[hour] is Dictionary else {}
	var fallback_action := _choose_revision_fallback_action(npc_id, reason, str(failed_item.get("action_id", "")))
	source_plan[hour] = _make_plan_item(
		hour,
		fallback_action,
		"规则降级：%s" % fallback_reason,
		FALLBACK_REVISION_SOURCE
	)
	set_npc_daily_plan(npc_id, source_plan, false)
	_log_plan_revised(npc_id, source_plan, reason, FALLBACK_REVISION_SOURCE, fallback_reason)
	var execute_result := execute_current_plan_for_npc(npc_id, true)
	return {
		"ok": true,
		"status": "rule_fallback_applied",
		"source": FALLBACK_REVISION_SOURCE,
		"fallback_used": true,
		"summary": fallback_reason,
		"revised_plan": source_plan.duplicate(true),
		"execute_result": execute_result
	}


func _merge_revision_items(current_plan: Array, revision: Dictionary) -> Array:
	var next_plan := current_plan.duplicate(true)
	if next_plan.size() != 24:
		next_plan = _normalize_plan(next_plan)
	if next_plan.size() != 24:
		return []

	var revision_items: Array = []
	if revision.has("revised_plan") and revision["revised_plan"] is Array:
		revision_items = revision["revised_plan"]
	var immediate: Dictionary = revision.get("immediate_action", {})
	if not immediate.is_empty():
		revision_items.append(immediate)

	for raw_item in revision_items:
		if not raw_item is Dictionary:
			continue
		var item := _plan_item_from_schema(raw_item, REVISION_SOURCE)
		if item.is_empty():
			return []
		var hour := int(item.get("hour", -1))
		if hour < 0 or hour >= 24:
			return []
		next_plan[hour] = item
	return _normalize_plan(next_plan)


func _plan_item_from_schema(item: Dictionary, source: String) -> Dictionary:
	var action_id := str(item.get("action_id", ""))
	if not _is_supported_plan_action(action_id):
		return {}
	var target := {}
	var target_id := str(item.get("target_id", ""))
	var location_id := str(item.get("location_id", ""))
	if not target_id.is_empty():
		target["target_id"] = target_id
		if action_id in ["assist_repair", "assist_upgrade"]:
			target["building_id"] = target_id
		elif action_id == "assist_heal":
			target["target_npc_id"] = target_id
	if not location_id.is_empty():
		target["location_id"] = location_id
	return _make_plan_item(
		clampi(int(item.get("hour", _get_current_hour())), 0, 23),
		action_id,
		str(item.get("reason", "")),
		source,
		target
	)


func _is_supported_plan_action(action_id: String) -> bool:
	if action_id == IDLE_ACTION_ID:
		return true
	if action_id in ["assist_repair", "assist_upgrade", "assist_heal"]:
		return true
	return _get_action_ids().has(action_id)


func _is_plan_target_unavailable(item: Dictionary) -> bool:
	var action_id := str(item.get("action_id", ""))
	if action_id == IDLE_ACTION_ID:
		return false
	var action := _get_action(action_id)
	var building_id := str(action.get("location_required", ""))
	if building_id.is_empty() or building_id == PLAZA_LOCATION_ID:
		return false
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		return false
	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty():
		return true
	return int(building.get("hp", 1)) <= 0


func _is_failure_result(last_result: String) -> bool:
	return last_result.contains("failed") or last_result == "dialogue_interrupted" or last_result == "combat_alarm"


func _normalize_failure_type(reason: String) -> String:
	if reason == "target_unavailable":
		return "target_unavailable"
	if reason == "order_changed":
		return "order_changed"
	if reason == "combat_alarm":
		return "combat_alarm"
	if reason.contains("dialogue"):
		return "dialogue_interrupted"
	if reason.contains("no_workstation") or reason.contains("no_bed") or reason.contains("no_instructor"):
		return "workstation_occupied"
	if reason.contains("no_resources") or reason.contains("no_food") or reason.contains("no_money"):
		return "resource_insufficient"
	if reason == "low_satiety":
		return "low_satiety"
	if reason == "high_fatigue":
		return "high_fatigue"
	if reason == "low_hp":
		return "low_hp"
	return "unknown"


func _describe_reevaluation_reason(reason: String, item: Dictionary) -> String:
	match _normalize_failure_type(reason):
		"target_unavailable":
			return "计划目标不可用：%s。" % _get_action_name(str(item.get("action_id", "")))
		"workstation_occupied":
			return "计划行动没有可用工位：%s。" % _get_action_name(str(item.get("action_id", "")))
		"resource_insufficient":
			return "计划行动资源不足：%s。" % _get_action_name(str(item.get("action_id", "")))
		"dialogue_interrupted":
			return "对话打断了当前行动，需要重新安排。"
		"combat_alarm":
			return "战斗警报打断了日常安排，需要重新评估。"
		"order_changed":
			return "守备官发布了新指令，需要重新评估计划。"
		_:
			return "计划发生异常，需要重新评估。"


func _describe_action_failure(npc_id: String, last_result: String) -> String:
	return _describe_reevaluation_reason(last_result, get_current_plan_item(npc_id))


func _record_reevaluation_result(npc_id: String, reason: String, result: Dictionary) -> void:
	_last_reevaluation_result = result.duplicate(true)
	var npc_system := _get_npc_system()
	if npc_system != null and npc_system.has_method("apply_plan_reevaluation_result"):
		npc_system.apply_plan_reevaluation_result(npc_id, reason, result.duplicate(true))


func _choose_rule_work_action(npc: Dictionary) -> String:
	var skills: Dictionary = npc.get("skills", {})
	var best_skill := ""
	var best_value := -1
	for skill_name in SKILL_TO_WORK_ACTION.keys():
		var value := int(skills.get(str(skill_name), 0))
		if value > best_value:
			best_skill = str(skill_name)
			best_value = value
	var action_id := str(SKILL_TO_WORK_ACTION.get(best_skill, "work_garden"))
	if not _get_action_ids().has(action_id):
		return "work_garden"
	return action_id


func _build_rule_plan_for_npc(npc_id: String, source: String, reason: String) -> Array:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return []
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return []
	var work_action_id := _choose_rule_work_action(npc)
	var plan: Array = []
	for hour in range(24):
		var action_id := _choose_rule_action_for_hour(hour, work_action_id)
		plan.append(_make_plan_item(hour, action_id, reason, source))
	return plan


func _assign_plan_item(npc_id: String, item: Dictionary) -> bool:
	var action_system := _get_action_system()
	var npc_system := _get_npc_system()
	if npc_system == null:
		return false
	var action_id := str(item.get("action_id", ""))
	if action_id == IDLE_ACTION_ID:
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": "plan_idle"
		})
		return true
	if action_system == null:
		return false
	var target: Dictionary = item.get("target", {})
	match action_id:
		"assist_repair":
			return action_system.debug_assign_repair_assist(npc_id, str(target.get("building_id", "")))
		"assist_upgrade":
			return action_system.debug_assign_upgrade_assist(npc_id, str(target.get("building_id", "")))
		"assist_heal":
			return action_system.debug_assign_heal_assist(npc_id, str(target.get("target_npc_id", "")))
		_:
			return action_system.debug_assign_action(npc_id, action_id)


func _log_plan_created(npc_id: String, plan: Array, source: String = RULE_SOURCE) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return
	memory_system.add_event({
		"type": "plan_created",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id],
		"location_id": _get_current_info_location(npc_id),
		"visibility": "private",
		"importance": 40,
		"payload": {
			"plan_day": _get_current_day(),
			"items": plan.duplicate(true),
			"source": source,
			"work_phase_count": _count_work_phases(plan)
		}
	})


func _log_plan_revised(npc_id: String, plan: Array, reason: String, source: String, summary: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return
	memory_system.add_event({
		"type": "plan_revised",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id],
		"location_id": _get_current_info_location(npc_id),
		"visibility": "private",
		"importance": 55,
		"payload": {
			"plan_day": _get_current_day(),
			"items": plan.duplicate(true),
			"reason": reason,
			"source": source,
			"summary": summary,
			"work_phase_count": _count_work_phases(plan)
		}
	})


func _count_work_phases(plan: Array) -> int:
	var count := 0
	for raw_item in plan:
		if not raw_item is Dictionary:
			continue
		var action_id := str((raw_item as Dictionary).get("action_id", ""))
		if action_id == IDLE_ACTION_ID:
			continue
		var action := _get_action(action_id)
		if str(action.get("type", "")) in ["work", "clinic_doctor", "training_instructor"]:
			count += 1
	return count


func _daily_planning_rules() -> Array[String]:
	return [
		"计划必须覆盖 0 到 23 点共 24 个阶段。",
		"至少 6 个阶段安排 work / clinic_doctor / training_instructor 类型的生产或训练工作。",
		"只能选择行动白名单中的 action_id，或选择 idle。",
		"守备官当前指令只能作为参考，不能越过资源、HP、地点、工位或行动合法性。"
	]


func _plan_generation_result(
	ok: bool,
	npc_id: String,
	status: String,
	summary: String,
	fallback_used: bool,
	plan: Array,
	request_result: Dictionary,
	execute_result: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		"npc_id": npc_id,
		"status": status,
		"source": PLAN_FALLBACK_SOURCE if fallback_used else MOCK_PLAN_SOURCE,
		"fallback_used": fallback_used,
		"summary": summary,
		"plan": plan.duplicate(true),
		"request_result": request_result.duplicate(true),
		"execute_result": execute_result.duplicate(true)
	}


func _record_plan_generation_result(npc_id: String, result: Dictionary) -> void:
	_last_plan_generation_result = result.duplicate(true)
	var npc_system := _get_npc_system()
	if npc_system != null and npc_system.has_method("apply_plan_reevaluation_result"):
		npc_system.apply_plan_reevaluation_result(npc_id, "plan_day", result.duplicate(true))


func _get_current_info_location(npc_id: String) -> String:
	var npc_system := _get_npc_system()
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if npc_system == null:
		return PLAZA_LOCATION_ID
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var location_id := str(state.get("current_location", PLAZA_LOCATION_ID))
	if memory_system != null and memory_system.has_method("is_enterable_location") and memory_system.is_enterable_location(location_id):
		return location_id
	return PLAZA_LOCATION_ID


func _get_current_day() -> int:
	var game_state := get_node_or_null("/root/GameState")
	return 1 if game_state == null else int(game_state.current_day)


func _get_current_hour() -> int:
	var game_state := get_node_or_null("/root/GameState")
	return 0 if game_state == null else int(game_state.current_hour)


func _get_action_ids() -> Array[String]:
	var action_system := _get_action_system()
	if action_system == null:
		return []
	return action_system.get_action_ids()


func _get_action(action_id: String) -> Dictionary:
	var action_system := _get_action_system()
	if action_system == null:
		return {}
	return action_system.get_action(action_id)


func _get_action_name(action_id: String) -> String:
	if action_id == IDLE_ACTION_ID:
		return "等待"
	var action := _get_action(action_id)
	return str(action.get("name", action_id))


func _result(ok: bool, npc_id: String, action_id: String, status: String) -> Dictionary:
	return {
		"ok": ok,
		"npc_id": npc_id,
		"action_id": action_id,
		"status": status
	}


func _get_npc_system() -> Node:
	return get_node_or_null(NPC_SYSTEM_PATH)


func _get_action_system() -> Node:
	return get_node_or_null(ACTION_SYSTEM_PATH)
