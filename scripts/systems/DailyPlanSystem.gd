extends Node

signal async_daily_plan_batch_completed(snapshot: Dictionary)

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const PLAZA_LOCATION_ID := "plaza"
const RULE_SOURCE := "rule_default"
const LLM_PLAN_SOURCE := "llm_plan_day"
const MOCK_PLAN_SOURCE := "mock_plan_day"
const LLM_REVISION_SOURCE := "llm_plan_revision"
const LLM_DIALOGUE_INTENT_REVALIDATION_SOURCE := "llm_dialogue_intent_revalidation"
const IDLE_ACTION_ID := "idle"
const PRAY_ACTION_ID := "pray_at_chapel"
const MASS_ACTION_ID := "lead_mass"
const COMPLETION_POLICY_REPEAT_WHILE_PLANNED := "repeat_while_planned"
const COMPLETION_POLICY_ONCE_PER_PLAN_HOUR := "once_per_plan_hour"
const FORMAL_PLAN_MAX_CONCURRENT := 8
const FORMAL_PLAN_MAX_ATTEMPTS := 3
const FORMAL_REVISION_MAX_ATTEMPTS := 3
const REVISION_SCOPE_SELECTED_HOURS := "selected_hours"

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
var _plan_version_by_npc: Dictionary = {}
var _last_completed_result_by_npc: Dictionary = {}
var _last_failure_result_by_npc: Dictionary = {}
var _plan_owned_action_by_npc: Dictionary = {}
var _plan_execution_signature_by_npc: Dictionary = {}
var _behavior_mode_interrupted_plan_by_npc: Dictionary = {}
var _one_shot_execution_keys_by_npc: Dictionary = {}
var _repeat_continuation_generation_by_npc: Dictionary = {}
var _completion_reevaluation_generation_by_npc: Dictionary = {}
var _last_plan_generation_result: Dictionary = {}
var _last_reevaluation_result: Dictionary = {}
var _last_plan_revision_judgement_result: Dictionary = {}
var _last_dialogue_plan_judgement_result: Dictionary = {}
var _reevaluating_npcs: Dictionary = {}
var _queued_reevaluation_by_npc: Dictionary = {}
var _queued_followup_reevaluation_by_npc: Dictionary = {}
var _async_plan_queue: Array[Dictionary] = []
var _async_plan_requests: Dictionary = {}
var _async_plan_batch_snapshot: Dictionary = {}
var _async_plan_max_concurrent := FORMAL_PLAN_MAX_CONCURRENT
var _async_revision_requests: Dictionary = {}
var _async_dialogue_plan_judgement_requests: Dictionary = {}
var _async_action_failure_plan_judgement_requests: Dictionary = {}
var _async_dialogue_intent_revalidation_requests: Dictionary = {}
var _dialogue_intent_revalidation_request_by_npc: Dictionary = {}
var _approved_dialogue_intent_by_npc: Dictionary = {}
var _last_dialogue_intent_revalidation_result_by_npc: Dictionary = {}
var _dialogue_plan_judgement_generation_by_npc: Dictionary = {}
var _dialogue_resume_context_by_npc: Dictionary = {}
var _deferred_current_revision_execution_by_npc: Dictionary = {}
var _deferred_hour_plan_until_mass_end_by_npc: Dictionary = {}
var _mass_end_dispatch_scheduled := false
var _revision_execution_retry_counts: Dictionary = {}
var _revision_cycle_by_npc: Dictionary = {}
var _revision_applied_marker_by_npc: Dictionary = {}


func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.day_started.connect(_on_day_started)
		event_bus.hour_started.connect(_on_hour_started)
		event_bus.npc_state_changed.connect(_on_npc_state_changed)
		event_bus.npc_plan_reevaluation_requested.connect(_on_plan_reevaluation_requested)
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if (
		llm_bridge != null
		and llm_bridge.has_signal("daily_plan_async_response_received")
		and not llm_bridge.daily_plan_async_response_received.is_connected(_on_daily_plan_async_response)
	):
		llm_bridge.daily_plan_async_response_received.connect(_on_daily_plan_async_response)
	if (
		llm_bridge != null
		and llm_bridge.has_signal("plan_revision_judgement_async_response_received")
		and not llm_bridge.plan_revision_judgement_async_response_received.is_connected(
			_on_plan_revision_judgement_async_response
		)
	):
		llm_bridge.plan_revision_judgement_async_response_received.connect(
			_on_plan_revision_judgement_async_response
		)
	if (
		llm_bridge != null
		and llm_bridge.has_signal("plan_revision_async_response_received")
		and not llm_bridge.plan_revision_async_response_received.is_connected(_on_plan_revision_async_response)
	):
		llm_bridge.plan_revision_async_response_received.connect(_on_plan_revision_async_response)
	if (
		llm_bridge != null
		and llm_bridge.has_signal(
			"dialogue_intent_revalidation_async_response_received"
		)
		and not llm_bridge.dialogue_intent_revalidation_async_response_received.is_connected(
			_on_dialogue_intent_revalidation_async_response
		)
	):
		llm_bridge.dialogue_intent_revalidation_async_response_received.connect(
			_on_dialogue_intent_revalidation_async_response
		)


func set_auto_execution_enabled(enabled: bool) -> void:
	auto_execution_enabled = enabled
	if enabled and not _deferred_hour_plan_until_mass_end_by_npc.is_empty():
		_schedule_mass_end_plan_dispatch()


func generate_all_rule_plans() -> Dictionary:
	var result := {}
	var npc_system := _get_npc_system()
	if npc_system == null:
		return result
	for npc_id in npc_system.get_npc_ids():
		result[str(npc_id)] = generate_rule_plan_for_npc(str(npc_id))
	return result


func begin_new_day_planning_for_npc(npc_id: String, reason: String = "new_day") -> Dictionary:
	var npc_system := _get_npc_system()
	if npc_system == null or npc_system.get_npc(npc_id).is_empty():
		return {
			"ok": false,
			"npc_id": npc_id,
			"status": "unknown_npc"
		}

	_cancel_plan_revision_for_new_day(npc_id)
	_plans_by_npc.erase(npc_id)
	_bump_plan_version(npc_id)
	_plan_owned_action_by_npc.erase(npc_id)
	_plan_execution_signature_by_npc.erase(npc_id)
	_one_shot_execution_keys_by_npc.erase(npc_id)
	_repeat_continuation_generation_by_npc.erase(npc_id)
	_completion_reevaluation_generation_by_npc.erase(npc_id)
	npc_system.set_npc_plan(npc_id, [])
	var enters_planning_state: bool = bool(npc_system.can_npc_act(npc_id)) and _is_npc_in_work_behavior_mode(npc_id, npc_system)
	if enters_planning_state:
		var action_system := _get_action_system()
		if action_system != null and action_system.has_method("interrupt_npc_action"):
			action_system.interrupt_npc_action(npc_id, "daily_plan_preparation")
		npc_system.update_npc_state(npc_id, {
			"current_action": "planning_day",
			"last_action_result": "daily_plan_pending"
		})
	var wake_event := _log_wake_up(npc_id, reason)
	return {
		"ok": true,
		"npc_id": npc_id,
		"status": "planning_day" if enters_planning_state else "planning_in_background",
		"wake_event": wake_event.duplicate(true),
		"day_start_reason": reason
	}


func start_new_day_for_npc(
	npc_id: String,
	reason: String = "new_day",
	execute_current: bool = true,
	prefer_llm: bool = true
) -> Dictionary:
	var npc_system := _get_npc_system()
	if npc_system == null or npc_system.get_npc(npc_id).is_empty():
		return _plan_generation_result(false, npc_id, "unknown_npc", "", false, [], {}, {}, "")

	var wake_event := _log_wake_up(npc_id, reason)
	var result: Dictionary
	if prefer_llm:
		result = generate_daily_plan_for_npc(npc_id, execute_current)
	else:
		var plan := generate_rule_plan_for_npc(npc_id)
		var execute_result := {}
		if execute_current:
			execute_result = execute_current_plan_for_npc(npc_id, true)
		result = {
			"ok": plan.size() == 24,
			"npc_id": npc_id,
			"status": "rule_plan_applied",
			"source": RULE_SOURCE,
			"fallback_used": false,
			"summary": "按规则制定了新一天计划。",
			"plan": plan.duplicate(true),
			"request_result": {},
			"execute_result": execute_result.duplicate(true)
		}
	result["wake_event"] = wake_event.duplicate(true)
	result["day_start_reason"] = reason
	return result


func start_new_day_for_all(
	reason: String = "new_day",
	execute_current: bool = true,
	prefer_llm: bool = true
) -> Dictionary:
	var result := {}
	var npc_system := _get_npc_system()
	if npc_system == null:
		return result
	for npc_id in npc_system.get_npc_ids():
		result[str(npc_id)] = start_new_day_for_npc(
			str(npc_id),
			reason,
			execute_current,
			prefer_llm
		)
	return result


func request_daily_plans_async(
	npc_ids: Array[String],
	reason: String = "new_day",
	execute_current_on_success: bool = false,
	max_concurrent: int = FORMAL_PLAN_MAX_CONCURRENT,
	require_real_provider: bool = true,
	max_attempts: int = FORMAL_PLAN_MAX_ATTEMPTS
) -> Dictionary:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("request_npc_daily_plan_async"):
		return {
			"ok": false,
			"status": "async_llm_unavailable",
			"queued_count": 0,
			"reason": reason
		}
	if require_real_provider:
		var provider_check := _require_real_llm_provider(llm_bridge)
		if not bool(provider_check.get("ok", false)):
			return provider_check

	_async_plan_queue.clear()
	_async_plan_requests.clear()
	_async_plan_max_concurrent = clampi(max_concurrent, 1, 8)
	var normalized_max_attempts := clampi(max_attempts, 1, 5)
	for npc_id in npc_ids:
		if npc_id.is_empty():
			continue
		_async_plan_queue.append({
			"npc_id": npc_id,
			"reason": reason,
			"execute_current_on_success": execute_current_on_success,
			"require_real_provider": require_real_provider,
			"attempt": 1,
			"max_attempts": normalized_max_attempts
		})
	_async_plan_batch_snapshot = {
		"ok": true,
		"status": "running" if not _async_plan_queue.is_empty() else "completed",
		"reason": reason,
		"requested_count": _async_plan_queue.size(),
		"completed_count": 0,
		"succeeded_count": 0,
		"failed_count": 0,
		"active_count": 0,
		"queued_count": _async_plan_queue.size(),
		"max_concurrent": _async_plan_max_concurrent,
		"max_observed_concurrent": 0,
		"max_attempts_per_npc": normalized_max_attempts,
		"retry_count": 0,
		"attempt_count_by_npc": {},
		"require_real_provider": require_real_provider,
		"results": {}
	}
	_pump_async_plan_queue()
	return _async_plan_batch_snapshot.duplicate(true)


func get_async_plan_batch_snapshot() -> Dictionary:
	return _async_plan_batch_snapshot.duplicate(true)


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


func generate_daily_plan_for_npc(
	npc_id: String,
	execute_current: bool = false,
	allow_mock_provider: bool = false
) -> Dictionary:
	var npc_system := _get_npc_system()
	if npc_system == null or npc_system.get_npc(npc_id).is_empty():
		return _plan_generation_result(false, npc_id, "unknown_npc", "", false, [], {}, {}, "")

	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge != null and llm_bridge.has_method("request_npc_daily_plan"):
		if not allow_mock_provider:
			var provider_check := _require_real_llm_provider(llm_bridge)
			if not bool(provider_check.get("ok", false)):
				var provider_failure := _daily_plan_failure(
					npc_id,
					str(provider_check.get("status", "real_provider_required")),
					str(provider_check.get("message", "正式每日计划需要真实 LLM provider。")),
					provider_check
				)
				_record_plan_generation_result(npc_id, provider_failure)
				return provider_failure
		var request_result: Dictionary = llm_bridge.request_npc_daily_plan(npc_id, {
			"planning_rules": _daily_planning_rules()
		})
		if bool(request_result.get("ok", false)):
			var apply_result := _apply_daily_plan_response(
				npc_id,
				request_result.get("daily_plan", {}),
				execute_current,
				not allow_mock_provider
			)
			apply_result["request_result"] = request_result.duplicate(true)
			_record_plan_generation_result(npc_id, apply_result)
			return apply_result
		if _is_request_cancelled(request_result):
			var cancelled_result := _plan_generation_result(false, npc_id, "request_cancelled", "每日计划请求被玩家对话打断。", false, [], request_result, {}, "")
			_record_plan_generation_result(npc_id, cancelled_result)
			return cancelled_result
		var failed_result := _daily_plan_failure(
			npc_id,
			"llm_request_failed",
			"每日计划真实 LLM 请求失败：%s" % str(request_result.get("message", "后端不可用。")),
			request_result
		)
		_record_plan_generation_result(npc_id, failed_result)
		return failed_result

	var missing_result := _daily_plan_failure(npc_id, "llm_bridge_unavailable", "LLMBridge 不可用。", {})
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
	var had_previous_plan := _plans_by_npc.has(npc_id)
	var previous_plan: Array = _plans_by_npc.get(npc_id, []).duplicate(true)
	# NPCSystem 会同步发出计划变化信号；先更新权威缓存，UI 才能在该信号内读到新计划。
	_plans_by_npc[npc_id] = normalized_plan.duplicate(true)
	if not npc_system.set_npc_plan(npc_id, normalized_plan):
		if had_previous_plan:
			_plans_by_npc[npc_id] = previous_plan
		else:
			_plans_by_npc.erase(npc_id)
		return false
	_bump_plan_version(npc_id)
	_plan_execution_signature_by_npc.erase(npc_id)
	_behavior_mode_interrupted_plan_by_npc.erase(npc_id)
	_approved_dialogue_intent_by_npc.erase(npc_id)
	_deferred_current_revision_execution_by_npc.erase(npc_id)
	if source != LLM_REVISION_SOURCE:
		_clear_revision_failure_cycle(npc_id)
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
		if not _plan_version_by_npc.has(npc_id):
			_plan_version_by_npc[npc_id] = 1
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


func get_plan_version(npc_id: String) -> int:
	return _get_plan_version(npc_id)


func get_last_reevaluation_result() -> Dictionary:
	return _last_reevaluation_result.duplicate(true)


func get_last_plan_revision_judgement_result() -> Dictionary:
	return _last_plan_revision_judgement_result.duplicate(true)


func get_last_dialogue_plan_judgement_result() -> Dictionary:
	return _last_dialogue_plan_judgement_result.duplicate(true)


func execute_current_plan_for_all(
	force_interrupt: bool = false,
	is_hour_boundary: bool = false
) -> Dictionary:
	var result := {}
	var npc_system := _get_npc_system()
	if npc_system == null:
		return result
	var npc_ids: Array[String] = npc_system.get_npc_ids()
	if force_interrupt:
		# 新日并发规划结束时所有 NPC 仍标记为 planning_day。先整体释放该瞬态，
		# 否则 A→B 且 B 本小时也计划对话时，A 会把仍在 planning_day 的 B 误判为不可交谈。
		for raw_npc_id in npc_ids:
			var planning_npc_id := str(raw_npc_id)
			var planning_state: Dictionary = npc_system.get_npc_state(planning_npc_id)
			if str(planning_state.get("current_action", "")) == "planning_day" and npc_system.can_npc_act(planning_npc_id):
				npc_system.update_npc_state(planning_npc_id, {
					"current_action": "idle",
					"last_action_result": "daily_plan_ready"
				})

	var dialogue_npc_ids: Array[String] = []
	var service_provider_npc_ids: Array[String] = []
	var training_instructor_npc_ids: Array[String] = []
	var service_dependent_npc_ids: Array[String] = []
	var training_student_npc_ids: Array[String] = []
	var other_npc_ids: Array[String] = []
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		var item := get_current_plan_item(npc_id)
		match str(item.get("action_id", "")):
			"talk_to_npc":
				dialogue_npc_ids.append(npc_id)
			"work_clinic_doctor", "lead_mass":
				service_provider_npc_ids.append(npc_id)
			"work_training_instructor":
				training_instructor_npc_ids.append(npc_id)
			"receive_clinic_treatment":
				service_dependent_npc_ids.append(npc_id)
			"receive_weapon_training":
				training_student_npc_ids.append(npc_id)
			_:
				other_npc_ids.append(npc_id)

	# Service dependents synchronously require their provider. Dispatch every doctor,
	# instructor and Mass leader before patients, trainees and Mass attendees.
	for npc_id in service_provider_npc_ids:
		result[npc_id] = execute_current_plan_for_npc(npc_id, force_interrupt, false, is_hour_boundary)
	for npc_id in training_instructor_npc_ids:
		result[npc_id] = execute_current_plan_for_npc(npc_id, force_interrupt, false, is_hour_boundary)
	for npc_id in other_npc_ids:
		result[npc_id] = execute_current_plan_for_npc(npc_id, force_interrupt, false, is_hour_boundary)
	for npc_id in service_dependent_npc_ids:
		result[npc_id] = execute_current_plan_for_npc(npc_id, force_interrupt, false, is_hour_boundary)
	for npc_id in training_student_npc_ids:
		result[npc_id] = execute_current_plan_for_npc(npc_id, force_interrupt, false, is_hour_boundary)

	# 非对话行动先落地，让目标离开 planning_day 并进入真实工作/地点状态；
	# 随后再让对话发起者接近并打断目标当前工作。
	for npc_id in dialogue_npc_ids:
		result[npc_id] = execute_current_plan_for_npc(npc_id, force_interrupt, true, is_hour_boundary)
	return result


func execute_current_plan_for_npc(
	npc_id: String,
	force_interrupt: bool = false,
	preserve_active_dialogue: bool = false,
	is_hour_boundary: bool = false
) -> Dictionary:
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
	if not is_hour_boundary:
		_deferred_hour_plan_until_mass_end_by_npc.erase(npc_id)
	var completion_policy := _get_action_completion_policy(action_id, action_system)
	if action_id != IDLE_ACTION_ID and completion_policy.is_empty():
		return _result(false, npc_id, action_id, "invalid_action_completion_policy")
	if not npc_system.can_npc_act(npc_id):
		return _result(false, npc_id, action_id, "npc_cannot_act")
	if not _is_npc_in_work_behavior_mode(npc_id, npc_system):
		return _result(false, npc_id, action_id, "authoritative_behavior_mode_active")
	if _is_current_plan_waiting_for_dialogue_resolution(npc_id):
		return _result(true, npc_id, action_id, "dialogue_plan_judgement_pending")
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null and dialog_system.has_method("is_npc_in_dialogue") and dialog_system.is_npc_in_dialogue(npc_id):
		var active_dialogue_state: Dictionary = (
			dialog_system.get_dialogue_state()
			if dialog_system.has_method("get_dialogue_state")
			else {}
		)
		var is_uninterrupted_invitation_target := (
			str(active_dialogue_state.get("dialogue_kind", "")) == "npc_npc"
			and str(active_dialogue_state.get("session_status", "")) == "invitation_pending"
			and str(active_dialogue_state.get("target_npc_id", "")) == npc_id
		)
		if preserve_active_dialogue:
			return _result(
				str(item.get("action_id", "")) == "talk_to_npc",
				npc_id,
				action_id,
				"already_in_npc_dialogue"
			)
		elif is_uninterrupted_invitation_target:
			pass
		elif not force_interrupt:
			return _result(false, npc_id, action_id, "npc_in_dialogue")
		elif (
			str(active_dialogue_state.get("dialogue_kind", "")) != "npc_npc"
			or not bool(active_dialogue_state.get("autonomous", false))
		):
			_defer_current_plan_until_dialogue_resolved(npc_id, {
				"npc_id": npc_id,
				"dialogue_id": str(active_dialogue_state.get("dialogue_id", "")),
				"dialogue_epoch": _get_npc_dialogue_epoch(npc_id)
			})
			return _result(false, npc_id, action_id, "priority_dialogue_active")
		else:
			if _should_preserve_active_autonomous_dialogue(active_dialogue_state):
				_defer_current_plan_until_dialogue_resolved(npc_id, {
					"npc_id": npc_id,
					"dialogue_id": str(active_dialogue_state.get("dialogue_id", "")),
					"dialogue_epoch": _get_npc_dialogue_epoch(npc_id),
					"carryover_dialogue": true
				})
				return _result(true, npc_id, action_id, "carried_dialogue_active")
			elif dialog_system.has_method("end_autonomous_dialogue_for_hour_change"):
				dialog_system.end_autonomous_dialogue_for_hour_change()
			elif dialog_system.has_method("force_end_dialogue_for_npc"):
				dialog_system.force_end_dialogue_for_npc(npc_id, "plan_hour_changed", {
					"suppress_plan_reevaluation": false,
					"suppress_dialogue_resume": true
				})

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var current_action := str(state.get("current_action", ""))
	if current_action == "planning_day" and force_interrupt:
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": "daily_plan_ready"
		})
		state = npc_system.get_npc_state(npc_id)
		current_action = str(state.get("current_action", ""))

	if (
		is_hour_boundary
		and action_system.has_method("is_npc_committed_to_active_mass")
		and bool(action_system.is_npc_committed_to_active_mass(npc_id))
	):
		if action_id != current_action:
			_defer_hour_plan_until_mass_end(npc_id, current_action)
			var deferred_result := _result(
				true,
				npc_id,
				action_id,
				"deferred_until_mass_completed"
			)
			deferred_result["protected_action_id"] = current_action
			return deferred_result
		_deferred_hour_plan_until_mass_end_by_npc.erase(npc_id)
	elif is_hour_boundary:
		_deferred_hour_plan_until_mass_end_by_npc.erase(npc_id)

	if _is_plan_target_unavailable(npc_id, item):
		var target_failure_context := _build_plan_target_unavailable_context(npc_id, item)
		return request_plan_reevaluation(
			npc_id,
			"target_unavailable",
			item,
			str(target_failure_context.get("failure_summary", "计划目标不可用。")),
			target_failure_context
		)

	var execution_signature := _make_plan_execution_signature(npc_id, item)
	if _runtime_action_matches_plan_item(npc_id, item, current_action, action_system):
		_plan_execution_signature_by_npc[npc_id] = execution_signature
		if completion_policy == COMPLETION_POLICY_ONCE_PER_PLAN_HOUR:
			_mark_one_shot_plan_item_executed(npc_id, item)
		if action_id != IDLE_ACTION_ID:
			_plan_owned_action_by_npc[npc_id] = action_id
		return _result(true, npc_id, action_id, "already_running")
	if (
		completion_policy == COMPLETION_POLICY_ONCE_PER_PLAN_HOUR
		and _was_one_shot_plan_item_executed(npc_id, item)
	):
		return _result(true, npc_id, action_id, "already_executed_once_per_plan_hour")
	if str(_plan_execution_signature_by_npc.get(npc_id, "")) == execution_signature:
		return _result(true, npc_id, action_id, "already_executed_this_plan_phase")

	var is_idle := current_action == "idle" or current_action.is_empty()
	if not is_idle and not force_interrupt:
		return _result(false, npc_id, action_id, "npc_busy")
	if _is_planned_dialogue_action(item):
		var intent_result := _ensure_dialogue_intent_revalidated(
			npc_id,
			item,
			force_interrupt,
			preserve_active_dialogue,
			is_hour_boundary
		)
		if not bool(intent_result.get("ready", false)):
			return intent_result

	if not is_idle and force_interrupt and action_system.has_method("interrupt_npc_action"):
		if not bool(action_system.interrupt_npc_action(npc_id, "plan_hour_changed")):
			return _result(false, npc_id, action_id, "active_action_interrupt_failed")

	var ok := _assign_plan_item(npc_id, item)
	if ok:
		_plan_execution_signature_by_npc[npc_id] = execution_signature
		if completion_policy == COMPLETION_POLICY_ONCE_PER_PLAN_HOUR:
			_mark_one_shot_plan_item_executed(npc_id, item)
		if action_id != IDLE_ACTION_ID:
			_plan_owned_action_by_npc[npc_id] = action_id
	else:
		_plan_owned_action_by_npc.erase(npc_id)
	return _result(ok, npc_id, action_id, "started" if ok else "assign_failed")


func resume_current_plan_after_player_dialogue(npc_id: String, interrupted_action_id: String) -> Dictionary:
	return resume_current_plan_after_dialogue(npc_id, interrupted_action_id)


func capture_current_plan_for_behavior_mode_interruption(npc_id: String, reason: String) -> Dictionary:
	var item := get_current_plan_item(npc_id)
	if item.is_empty():
		_behavior_mode_interrupted_plan_by_npc.erase(npc_id)
		return _result(false, npc_id, "", "no_plan_item")
	var action_id := str(item.get("action_id", ""))
	var signature := _make_plan_execution_signature(npc_id, item)
	var running_plan_owned := (
		str(_plan_execution_signature_by_npc.get(npc_id, "")) == signature
		and str(_plan_owned_action_by_npc.get(npc_id, "")) == action_id
	)
	if not running_plan_owned:
		_behavior_mode_interrupted_plan_by_npc.erase(npc_id)
		return _result(true, npc_id, action_id, "current_plan_not_running")
	_behavior_mode_interrupted_plan_by_npc[npc_id] = {
		"signature": signature,
		"action_id": action_id,
		"reason": reason
	}
	return _result(true, npc_id, action_id, "captured_running_plan")


func resume_current_plan_after_behavior_mode(npc_id: String, reason: String = "behavior_mode_ended") -> Dictionary:
	var item := get_current_plan_item(npc_id)
	if item.is_empty():
		return _result(false, npc_id, "", "no_plan_item")
	var action_id := str(item.get("action_id", ""))
	var npc_system := _get_npc_system()
	if npc_system == null or not _is_npc_in_work_behavior_mode(npc_id, npc_system):
		return _result(false, npc_id, action_id, "authoritative_behavior_mode_active")
	var current_signature := _make_plan_execution_signature(npc_id, item)
	var captured: Dictionary = (
		(_behavior_mode_interrupted_plan_by_npc.get(npc_id, {}) as Dictionary).duplicate(true)
		if _behavior_mode_interrupted_plan_by_npc.get(npc_id, {}) is Dictionary
		else {}
	)
	_behavior_mode_interrupted_plan_by_npc.erase(npc_id)
	var interrupted_running_plan := (
		(
			str(captured.get("signature", "")) == current_signature
			and str(captured.get("action_id", "")) == action_id
		)
		or (
			str(_plan_execution_signature_by_npc.get(npc_id, "")) == current_signature
			and str(_plan_owned_action_by_npc.get(npc_id, "")) == action_id
		)
	)
	if interrupted_running_plan:
		# Rally/avoidance interrupted this exact phase before completion. Permit
		# the same plan item to continue once from the NPC's current world position.
		_plan_execution_signature_by_npc.erase(npc_id)
		_plan_owned_action_by_npc.erase(npc_id)
		if _get_action_completion_policy(action_id) == COMPLETION_POLICY_ONCE_PER_PLAN_HOUR:
			_erase_one_shot_plan_item_execution(npc_id, item)
	var result := execute_current_plan_for_npc(npc_id, true)
	result["resumed_after_behavior_mode"] = true
	result["behavior_mode_end_reason"] = reason
	result["interrupted_running_plan"] = interrupted_running_plan
	return result


func resume_saved_plan_after_dialogue(npc_id: String) -> Dictionary:
	return _resume_interrupted_dialogue_plan({"npc_id": npc_id})


func advance_dialogue_resume_context_epoch(
	npc_id: String,
	dialogue_epoch: int,
	dialogue_id: String
) -> bool:
	var advanced := false
	var saved: Dictionary = _dialogue_resume_context_by_npc.get(npc_id, {})
	if not saved.is_empty():
		var saved_day := int(saved.get("day", saved.get("request_day", -1)))
		var saved_hour := int(saved.get("hour", saved.get("request_hour", -1)))
		var interrupted_action_id := str(saved.get("interrupted_action_id", ""))
		if (
			saved_day != _get_current_day()
			or saved_hour != _get_current_hour()
			or int(saved.get("plan_version", -1)) != _get_plan_version(npc_id)
			or interrupted_action_id.is_empty()
			or str(get_current_plan_item(npc_id).get("action_id", "")) != interrupted_action_id
		):
			_dialogue_resume_context_by_npc.erase(npc_id)
		else:
			saved["dialogue_epoch"] = dialogue_epoch
			saved["dialogue_id"] = dialogue_id
			_dialogue_resume_context_by_npc[npc_id] = saved
			advanced = true
	var pending: Dictionary = _deferred_current_revision_execution_by_npc.get(npc_id, {})
	if (
		not pending.is_empty()
		and bool(pending.get("wait_for_dialogue_resolution", false))
		and int(pending.get("day", -1)) == _get_current_day()
		and int(pending.get("hour", -1)) == _get_current_hour()
	):
		var previous_dialogue_id := str(pending.get("dialogue_id", ""))
		pending["dialogue_epoch"] = dialogue_epoch
		pending["dialogue_id"] = dialogue_id
		pending["scheduled"] = false
		_deferred_current_revision_execution_by_npc[npc_id] = pending
		advanced = true
		if previous_dialogue_id != dialogue_id:
			call_deferred("schedule_ready_deferred_current_plans")
	return advanced


func resume_current_plan_after_dialogue(npc_id: String, interrupted_action_id: String) -> Dictionary:
	var item := get_current_plan_item(npc_id)
	if item.is_empty():
		return _result(false, npc_id, "", "no_plan_item")
	var action_id := str(item.get("action_id", ""))
	if interrupted_action_id.is_empty() or interrupted_action_id != action_id:
		return _result(false, npc_id, action_id, "interrupted_action_not_current_plan")
	var current_signature := _make_plan_execution_signature(npc_id, item)
	var cleared_execution_signature := (
		str(_plan_execution_signature_by_npc.get(npc_id, "")) == current_signature
	)
	if (
		not cleared_execution_signature
		or str(_plan_owned_action_by_npc.get(npc_id, "")) != action_id
	):
		return _result(false, npc_id, action_id, "interrupted_plan_phase_changed")
	# The action was already dispatched for this exact plan phase before the
	# player dialogue interrupted it. Only this explicit resume path may
	# consume the same phase a second time.
	_plan_execution_signature_by_npc.erase(npc_id)
	_plan_owned_action_by_npc.erase(npc_id)
	if _get_action_completion_policy(action_id) == COMPLETION_POLICY_ONCE_PER_PLAN_HOUR:
		# The explicit dialogue-resume path continues an interrupted execution;
		# it is not an automatic second execution of a completed one-shot action.
		_erase_one_shot_plan_item_execution(npc_id, item)

	var result := execute_current_plan_for_npc(npc_id, true)
	result["resumed_after_dialogue"] = true
	result["resumed_after_player_dialogue"] = true
	result["cleared_execution_signature"] = cleared_execution_signature
	return result


func _adopt_running_current_plan_action(npc_id: String) -> bool:
	var item := get_current_plan_item(npc_id)
	var npc_system := _get_npc_system()
	var action_system := _get_action_system()
	if item.is_empty() or npc_system == null or action_system == null:
		return false
	var current_action := str(npc_system.get_npc_state(npc_id).get("current_action", ""))
	if not _runtime_action_matches_plan_item(npc_id, item, current_action, action_system):
		return false
	_plan_execution_signature_by_npc[npc_id] = _make_plan_execution_signature(npc_id, item)
	var action_id := str(item.get("action_id", ""))
	if not action_id.is_empty() and action_id != IDLE_ACTION_ID:
		_plan_owned_action_by_npc[npc_id] = action_id
	return true


func _make_plan_execution_signature(npc_id: String, item: Dictionary) -> String:
	return "%d:%d:%d:%s" % [
		_get_current_day(),
		_get_current_hour(),
		_get_plan_version(npc_id),
		_make_plan_item_identity(item),
	]


func _make_plan_item_identity(item: Dictionary) -> String:
	var action_id := str(item.get("action_id", ""))
	var target: Dictionary = item.get("target", {}) if item.get("target", {}) is Dictionary else {}
	var target_id := str(target.get("target_id", ""))
	if target_id.is_empty():
		for target_key in ["target_npc_id", "location_id", "building_id"]:
			target_id = str(target.get(target_key, ""))
			if not target_id.is_empty():
				break
	return JSON.stringify([
		action_id,
		target_id,
		str(item.get("dialogue_goal", "")).strip_edges(),
	])


func _is_planned_dialogue_action(item: Dictionary) -> bool:
	return (
		["talk_to_npc", "seek_guard_officer"].has(str(item.get("action_id", "")))
		and not str(item.get("dialogue_goal", "")).strip_edges().is_empty()
	)


func _ensure_dialogue_intent_revalidated(
	npc_id: String,
	item: Dictionary,
	force_interrupt: bool,
	preserve_active_dialogue: bool,
	is_hour_boundary: bool
) -> Dictionary:
	var action_id := str(item.get("action_id", ""))
	var execution_signature := _make_plan_execution_signature(npc_id, item)
	var approval: Dictionary = _approved_dialogue_intent_by_npc.get(npc_id, {})
	if not approval.is_empty():
		if str(approval.get("execution_signature", "")) == execution_signature:
			_approved_dialogue_intent_by_npc.erase(npc_id)
			return {"ready": true}
		_approved_dialogue_intent_by_npc.erase(npc_id)

	var pending_request_id := str(
		_dialogue_intent_revalidation_request_by_npc.get(npc_id, "")
	)
	if not pending_request_id.is_empty():
		var pending: Dictionary = _async_dialogue_intent_revalidation_requests.get(
			pending_request_id,
			{}
		)
		if str(pending.get("execution_signature", "")) == execution_signature:
			var pending_result := _result(
				true,
				npc_id,
				action_id,
				"dialogue_intent_revalidation_pending"
			)
			pending_result["ready"] = false
			pending_result["request_id"] = pending_request_id
			return pending_result
		var llm_bridge_for_cancel := get_node_or_null(LLM_BRIDGE_PATH)
		if (
			llm_bridge_for_cancel != null
			and llm_bridge_for_cancel.has_method("cancel_llm_request")
		):
			llm_bridge_for_cancel.cancel_llm_request(
				pending_request_id,
				"dialogue_intent_superseded"
			)
		_async_dialogue_intent_revalidation_requests.erase(pending_request_id)
		_dialogue_intent_revalidation_request_by_npc.erase(npc_id)

	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if (
		llm_bridge == null
		or not llm_bridge.has_method(
			"request_npc_dialogue_intent_revalidation_async"
		)
	):
		var unavailable_result := _request_dialogue_intent_failure_reevaluation(
			npc_id,
			item,
			"dialogue_intent_revalidation_failed",
			"对话意图执行前复核不可用。",
			{"failure": "llm_bridge_unavailable"}
		)
		unavailable_result["ready"] = false
		return unavailable_result
	var request_result: Dictionary = (
		llm_bridge.request_npc_dialogue_intent_revalidation_async(
			npc_id,
			item,
			{
				"current_plan": get_npc_daily_plan(npc_id),
				"requires_time_slowdown": true
			}
		)
	)
	if not bool(request_result.get("ok", false)):
		var failed_result := _request_dialogue_intent_failure_reevaluation(
			npc_id,
			item,
			"dialogue_intent_revalidation_failed",
			"对话意图执行前复核请求失败。",
			{"request_result": request_result.duplicate(true)}
		)
		failed_result["ready"] = false
		return failed_result
	var request_id := str(request_result.get("request_id", ""))
	if request_id.is_empty():
		var missing_id_result := _request_dialogue_intent_failure_reevaluation(
			npc_id,
			item,
			"dialogue_intent_revalidation_failed",
			"对话意图执行前复核未返回请求编号。",
			{"request_result": request_result.duplicate(true)}
		)
		missing_id_result["ready"] = false
		return missing_id_result
	var context := {
		"npc_id": npc_id,
		"request_id": request_id,
		"request_day": _get_current_day(),
		"request_hour": _get_current_hour(),
		"plan_version": _get_plan_version(npc_id),
		"item_identity": _make_plan_item_identity(item),
		"execution_signature": execution_signature,
		"plan_item": item.duplicate(true),
		"force_interrupt": force_interrupt,
		"preserve_active_dialogue": preserve_active_dialogue,
		"is_hour_boundary": is_hour_boundary
	}
	_async_dialogue_intent_revalidation_requests[request_id] = context
	_dialogue_intent_revalidation_request_by_npc[npc_id] = request_id
	var result := _result(
		true,
		npc_id,
		action_id,
		"dialogue_intent_revalidation_pending"
	)
	result["ready"] = false
	result["request_id"] = request_id
	return result


func _on_dialogue_intent_revalidation_async_response(response: Dictionary) -> void:
	var request_id := str(response.get("request_id", ""))
	var context: Dictionary = _async_dialogue_intent_revalidation_requests.get(
		request_id,
		{}
	)
	if context.is_empty():
		return
	_async_dialogue_intent_revalidation_requests.erase(request_id)
	var npc_id := str(context.get("npc_id", response.get("npc_id", "")))
	if str(_dialogue_intent_revalidation_request_by_npc.get(npc_id, "")) == request_id:
		_dialogue_intent_revalidation_request_by_npc.erase(npc_id)
	var current_item := get_current_plan_item(npc_id)
	var stale := (
		int(context.get("request_day", -1)) != _get_current_day()
		or int(context.get("request_hour", -1)) != _get_current_hour()
		or int(context.get("plan_version", -1)) != _get_plan_version(npc_id)
		or str(context.get("item_identity", ""))
			!= _make_plan_item_identity(current_item)
	)
	if stale:
		_last_dialogue_intent_revalidation_result_by_npc[npc_id] = {
			"ok": false,
			"status": "stale_response_ignored",
			"request_id": request_id,
			"context": context.duplicate(true)
		}
		if (
			int(context.get("request_day", -1)) == _get_current_day()
			and int(context.get("request_hour", -1)) == _get_current_hour()
		):
			call_deferred(
				"_resume_dialogue_intent_after_revalidation",
				npc_id,
				context
			)
		return
	if not bool(response.get("ok", false)):
		var failure_result := _request_dialogue_intent_failure_reevaluation(
			npc_id,
			current_item,
			"dialogue_intent_revalidation_failed",
			"对话意图执行前复核失败，改为重估当前计划。",
			{"response": response.duplicate(true)}
		)
		_last_dialogue_intent_revalidation_result_by_npc[npc_id] = {
			"ok": false,
			"status": "request_failed_replanning",
			"request_id": request_id,
			"response": response.duplicate(true),
			"reevaluation_result": failure_result.duplicate(true)
		}
		return
	var body: Dictionary = (
		(response.get("dialogue_intent_revalidation", {}) as Dictionary)
		if response.get("dialogue_intent_revalidation", {}) is Dictionary
		else {}
	)
	var decision := str(body.get("decision", ""))
	var revised_goal := str(body.get("dialogue_goal", "")).strip_edges()
	if not ["continue", "modify", "cancel_and_replan"].has(decision):
		var invalid_result := _request_dialogue_intent_failure_reevaluation(
			npc_id,
			current_item,
			"dialogue_intent_revalidation_failed",
			"对话意图复核返回了无效决定，改为重估当前计划。",
			{"response": response.duplicate(true)}
		)
		_last_dialogue_intent_revalidation_result_by_npc[npc_id] = {
			"ok": false,
			"status": "invalid_decision_replanning",
			"request_id": request_id,
			"response": response.duplicate(true),
			"reevaluation_result": invalid_result.duplicate(true)
		}
		return
	if decision == "cancel_and_replan":
		var cancel_result := _request_dialogue_intent_failure_reevaluation(
			npc_id,
			current_item,
			"dialogue_intent_cancelled",
			str(body.get(
				"summary",
				"NPC 在执行前放弃了原计划中的对话意图。"
			)),
			{
				"decision": decision,
				"planned_intent": current_item.duplicate(true),
				"revalidation": body.duplicate(true)
			}
		)
		_last_dialogue_intent_revalidation_result_by_npc[npc_id] = {
			"ok": true,
			"status": "cancelled_and_replanning",
			"request_id": request_id,
			"decision": decision,
			"response": body.duplicate(true),
			"reevaluation_result": cancel_result.duplicate(true)
		}
		return
	if decision == "modify":
		if revised_goal.is_empty() or revised_goal == str(
			current_item.get("dialogue_goal", "")
		).strip_edges():
			var invalid_modify_result := _request_dialogue_intent_failure_reevaluation(
				npc_id,
				current_item,
				"dialogue_intent_revalidation_failed",
				"对话意图复核未给出有效的新开场诉求，改为重估当前计划。",
				{"response": body.duplicate(true)}
			)
			_last_dialogue_intent_revalidation_result_by_npc[npc_id] = {
				"ok": false,
				"status": "invalid_modify_replanning",
				"request_id": request_id,
				"response": body.duplicate(true),
				"reevaluation_result": invalid_modify_result.duplicate(true)
			}
			return
		var updated_plan := get_npc_daily_plan(npc_id)
		var current_hour := _get_current_hour()
		var updated_item: Dictionary = updated_plan[current_hour].duplicate(true)
		updated_item["dialogue_goal"] = revised_goal
		updated_item["intent_created_day"] = _get_current_day()
		updated_item["intent_created_time"] = _get_current_time_text()
		updated_item["intent_source"] = LLM_DIALOGUE_INTENT_REVALIDATION_SOURCE
		updated_plan[current_hour] = updated_item
		if not set_npc_daily_plan(
			npc_id,
			updated_plan,
			false,
			LLM_DIALOGUE_INTENT_REVALIDATION_SOURCE
		):
			var apply_failed_result := _request_dialogue_intent_failure_reevaluation(
				npc_id,
				current_item,
				"dialogue_intent_revalidation_failed",
				"更新后的对话开场诉求未能写回计划，改为重估当前计划。",
				{"response": body.duplicate(true)}
			)
			_last_dialogue_intent_revalidation_result_by_npc[npc_id] = {
				"ok": false,
				"status": "modify_apply_failed_replanning",
				"request_id": request_id,
				"response": body.duplicate(true),
				"reevaluation_result": apply_failed_result.duplicate(true)
			}
			return
		current_item = get_current_plan_item(npc_id)
	_approved_dialogue_intent_by_npc[npc_id] = {
		"execution_signature": _make_plan_execution_signature(
			npc_id,
			current_item
		),
		"decision": decision,
		"request_id": request_id
	}
	_last_dialogue_intent_revalidation_result_by_npc[npc_id] = {
		"ok": true,
		"status": "approved_for_execution",
		"request_id": request_id,
		"decision": decision,
		"dialogue_goal": str(current_item.get("dialogue_goal", "")),
		"response": body.duplicate(true)
	}
	call_deferred(
		"_resume_dialogue_intent_after_revalidation",
		npc_id,
		context
	)


func _resume_dialogue_intent_after_revalidation(
	npc_id: String,
	context: Dictionary
) -> void:
	execute_current_plan_for_npc(
		npc_id,
		bool(context.get("force_interrupt", false)),
		bool(context.get("preserve_active_dialogue", false)),
		bool(context.get("is_hour_boundary", false))
	)


func _request_dialogue_intent_failure_reevaluation(
	npc_id: String,
	item: Dictionary,
	reason: String,
	summary: String,
	failure_context: Dictionary
) -> Dictionary:
	return request_plan_reevaluation(
		npc_id,
		reason,
		item,
		summary,
		failure_context,
		{"revision_hours": [_get_current_hour()]}
	)


func debug_get_dialogue_intent_revalidation_snapshot(
	npc_id: String
) -> Dictionary:
	var request_id := str(
		_dialogue_intent_revalidation_request_by_npc.get(npc_id, "")
	)
	return {
		"npc_id": npc_id,
		"pending_request_id": request_id,
		"pending": (
			_async_dialogue_intent_revalidation_requests.get(
				request_id,
				{}
			) as Dictionary
		).duplicate(true),
		"approval": (
			_approved_dialogue_intent_by_npc.get(npc_id, {}) as Dictionary
		).duplicate(true),
		"last_result": (
			_last_dialogue_intent_revalidation_result_by_npc.get(
				npc_id,
				{}
			) as Dictionary
		).duplicate(true)
	}


func _make_one_shot_execution_key(item: Dictionary) -> String:
	return "%d:%d:%s" % [
		_get_current_day(),
		_get_current_hour(),
		_make_plan_item_identity(item),
	]


func _mark_one_shot_plan_item_executed(npc_id: String, item: Dictionary) -> void:
	var execution_keys: Dictionary = _one_shot_execution_keys_by_npc.get(npc_id, {})
	execution_keys[_make_one_shot_execution_key(item)] = true
	_one_shot_execution_keys_by_npc[npc_id] = execution_keys


func _was_one_shot_plan_item_executed(npc_id: String, item: Dictionary) -> bool:
	var execution_keys: Dictionary = _one_shot_execution_keys_by_npc.get(npc_id, {})
	return execution_keys.has(_make_one_shot_execution_key(item))


func _erase_one_shot_plan_item_execution(npc_id: String, item: Dictionary) -> void:
	var execution_keys: Dictionary = _one_shot_execution_keys_by_npc.get(npc_id, {})
	execution_keys.erase(_make_one_shot_execution_key(item))
	if execution_keys.is_empty():
		_one_shot_execution_keys_by_npc.erase(npc_id)
	else:
		_one_shot_execution_keys_by_npc[npc_id] = execution_keys


func _get_action_completion_policy(action_id: String, action_system: Node = null) -> String:
	if action_id == IDLE_ACTION_ID:
		return ""
	var resolved_action_system := action_system
	if resolved_action_system == null:
		resolved_action_system = _get_action_system()
	if resolved_action_system == null:
		return ""
	if resolved_action_system.has_method("get_action_completion_policy"):
		return str(resolved_action_system.get_action_completion_policy(action_id))
	if resolved_action_system.has_method("get_action"):
		var action: Dictionary = resolved_action_system.get_action(action_id)
		return str(action.get("completion_policy", ""))
	return ""


func _runtime_action_matches_plan_item(
	npc_id: String,
	item: Dictionary,
	current_action: String,
	action_system: Node
) -> bool:
	var action_id := str(item.get("action_id", ""))
	var runtime: Dictionary = {}
	if action_system.has_method("get_runtime_action_snapshot"):
		runtime = action_system.get_runtime_action_snapshot(npc_id)
	elif action_system.has_method("get_runtime_action_id"):
		runtime = {"action_id": str(action_system.get_runtime_action_id(npc_id))}
	var runtime_action_id := str(runtime.get("action_id", ""))
	if runtime_action_id.is_empty():
		return current_action == action_id
	if runtime_action_id != action_id:
		return false
	if not action_id in ["talk_to_npc", "visit_location", "assist_repair", "assist_upgrade", "assist_heal"]:
		return true

	var target: Dictionary = item.get("target", {}) if item.get("target", {}) is Dictionary else {}
	var planned_target_id := ""
	match action_id:
		"talk_to_npc", "assist_heal":
			planned_target_id = str(target.get("target_npc_id", target.get("target_id", "")))
		"visit_location":
			planned_target_id = str(target.get("location_id", target.get("target_id", "")))
		"assist_repair", "assist_upgrade":
			planned_target_id = str(target.get("building_id", target.get("target_id", "")))
	if planned_target_id != str(runtime.get("target_id", "")):
		return false
	if action_id == "talk_to_npc" and str(runtime.get("phase", "")) == "pending":
		var options: Dictionary = runtime.get("options", {}) if runtime.get("options", {}) is Dictionary else {}
		return str(options.get("opening_text", "")).strip_edges() == _build_dialogue_opening(item)
	return true


func _is_npc_in_work_behavior_mode(npc_id: String, npc_system: Node) -> bool:
	if npc_system == null:
		return false
	if not npc_system.has_method("get_npc_behavior_mode_snapshot"):
		return true
	var mode: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
	return str(mode.get("behavior_mode", "work")) == "work"


func _defer_current_plan_until_dialogue_resolved(
	npc_id: String,
	context: Dictionary
) -> void:
	if npc_id.is_empty():
		return
	var existing: Dictionary = _deferred_current_revision_execution_by_npc.get(npc_id, {})
	var dialogue_id := str(context.get("dialogue_id", existing.get("dialogue_id", "")))
	var dialogue_epoch := int(context.get(
		"dialogue_epoch",
		existing.get("dialogue_epoch", _get_npc_dialogue_epoch(npc_id))
	))
	_deferred_current_revision_execution_by_npc[npc_id] = {
		"day": _get_current_day(),
		"hour": _get_current_hour(),
		"plan_version": _get_plan_version(npc_id),
		"scheduled": false,
		"wait_for_dialogue_resolution": true,
		"dialogue_id": dialogue_id,
		"dialogue_epoch": dialogue_epoch,
		"mark_revision_applied": bool(existing.get("mark_revision_applied", false)),
		"carryover_dialogue": bool(context.get(
			"carryover_dialogue",
			existing.get("carryover_dialogue", false)
		))
	}


func _is_current_plan_waiting_for_dialogue_resolution(npc_id: String) -> bool:
	var pending: Dictionary = _deferred_current_revision_execution_by_npc.get(npc_id, {})
	if pending.is_empty() or not bool(pending.get("wait_for_dialogue_resolution", false)):
		return false
	if (
		int(pending.get("day", -1)) != _get_current_day()
		or int(pending.get("hour", -1)) != _get_current_hour()
	):
		_deferred_current_revision_execution_by_npc.erase(npc_id)
		return false
	return true


func release_deferred_current_plan_after_dialogue(
	npc_id: String,
	dialogue_id: String = "",
	dialogue_epoch: int = -1
) -> Dictionary:
	return _finish_dialogue_resolution_execution({
		"npc_id": npc_id,
		"dialogue_id": dialogue_id,
		"dialogue_epoch": dialogue_epoch,
		"request_day": _get_current_day(),
		"request_hour": _get_current_hour(),
		"execute_current_plan_when_resolved": true
	})


func prepare_dialogue_plan_resolution_group(
	npc_ids: Array,
	dialogue_id: String,
	dialogue_epochs: Dictionary
) -> void:
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		if npc_id.is_empty():
			continue
		_defer_current_plan_until_dialogue_resolved(npc_id, {
			"npc_id": npc_id,
			"dialogue_id": dialogue_id,
			"dialogue_epoch": int(dialogue_epochs.get(
				npc_id,
				_get_npc_dialogue_epoch(npc_id)
			))
		})


func _finish_dialogue_resolution_execution(
	context: Dictionary,
	mark_revision_applied: bool = false
) -> Dictionary:
	if not bool(context.get("execute_current_plan_when_resolved", false)):
		schedule_ready_deferred_current_plans()
		return {}
	var npc_id := str(context.get("npc_id", ""))
	if npc_id.is_empty():
		return {}
	var request_day := int(context.get("request_day", context.get("day", -1)))
	var request_hour := int(context.get("request_hour", context.get("hour", -1)))
	var dialogue_epoch := int(context.get("dialogue_epoch", -1))
	if (
		request_day != _get_current_day()
		or request_hour != _get_current_hour()
		or (dialogue_epoch >= 0 and dialogue_epoch != _get_npc_dialogue_epoch(npc_id))
	):
		var stale_pending: Dictionary = _deferred_current_revision_execution_by_npc.get(npc_id, {})
		if (
			not stale_pending.is_empty()
			and str(stale_pending.get("dialogue_id", "")) == str(context.get("dialogue_id", ""))
		):
			_deferred_current_revision_execution_by_npc.erase(npc_id)
		schedule_ready_deferred_current_plans()
		return _result(false, npc_id, str(get_current_plan_item(npc_id).get("action_id", "")), "stale_dialogue_resolution")
	var pending: Dictionary = _deferred_current_revision_execution_by_npc.get(npc_id, {})
	var context_dialogue_id := str(context.get("dialogue_id", ""))
	if (
		not pending.is_empty()
		and not str(pending.get("dialogue_id", "")).is_empty()
		and not context_dialogue_id.is_empty()
		and str(pending.get("dialogue_id", "")) != context_dialogue_id
	):
		return _result(false, npc_id, str(get_current_plan_item(npc_id).get("action_id", "")), "newer_dialogue_resolution_pending")
	pending = {
		"day": _get_current_day(),
		"hour": _get_current_hour(),
		"plan_version": _get_plan_version(npc_id),
		"scheduled": false,
		"wait_for_dialogue_resolution": false,
		"dialogue_id": context_dialogue_id,
		"dialogue_epoch": dialogue_epoch,
		"mark_revision_applied": (
			mark_revision_applied
			or bool(pending.get("mark_revision_applied", false))
		)
	}
	_deferred_current_revision_execution_by_npc[npc_id] = pending
	for raw_other_npc_id in _deferred_current_revision_execution_by_npc.keys():
		var other_npc_id := str(raw_other_npc_id)
		var other: Dictionary = _deferred_current_revision_execution_by_npc.get(other_npc_id, {})
		if (
			other_npc_id != npc_id
			and not context_dialogue_id.is_empty()
			and str(other.get("dialogue_id", "")) == context_dialogue_id
			and int(other.get("day", -1)) == _get_current_day()
			and int(other.get("hour", -1)) == _get_current_hour()
			and bool(other.get("wait_for_dialogue_resolution", false))
		):
			return _result(true, npc_id, str(get_current_plan_item(npc_id).get("action_id", "")), "dialogue_group_resolution_pending")
	var dispatch_result := schedule_ready_deferred_current_plans()
	dispatch_result["npc_id"] = npc_id
	return dispatch_result


func request_dialogue_plan_revision_judgement(
	npc_id: String,
	dialogue_context: Dictionary
) -> Dictionary:
	var npc_system := _get_npc_system()
	var base_result := {
		"ok": false,
		"npc_id": npc_id,
		"dialogue_id": str(dialogue_context.get("dialogue_id", "")),
		"dialogue_kind": str(dialogue_context.get("dialogue_kind", "player_npc")),
		"dialogue_end_reason": str(dialogue_context.get("dialogue_end_reason", "dialogue_completed")),
		"needs_revision": false,
		"revision_hours": [],
		"revision_requested": false,
		"status": "pending",
		"summary": "",
		"request_result": {},
		"revision_request_result": {},
		"resume_result": {}
	}
	var early_context := dialogue_context.duplicate(true)
	early_context["npc_id"] = npc_id
	early_context["request_day"] = _get_current_day()
	early_context["request_hour"] = _get_current_hour()
	early_context["execute_current_plan_when_resolved"] = (
		bool(dialogue_context.get("execute_current_plan_when_resolved", false))
		or _is_current_plan_waiting_for_dialogue_resolution(npc_id)
	)
	if npc_system == null or npc_system.get_npc(npc_id).is_empty():
		base_result["status"] = "unknown_npc"
		base_result["summary"] = "找不到需要判别计划的 NPC。"
		base_result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(early_context)
		_record_dialogue_plan_judgement_result(base_result)
		return base_result
	var dialogue_history: Array = (
		(dialogue_context.get("dialogue_history", []) as Array).duplicate(true)
		if dialogue_context.get("dialogue_history", []) is Array
		else []
	)
	if dialogue_history.is_empty():
		base_result["ok"] = true
		base_result["status"] = "no_effective_dialogue"
		base_result["summary"] = "本次没有已完成的实际对话内容，不需要判断计划。"
		base_result["resume_result"] = _resume_interrupted_dialogue_plan(early_context)
		base_result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(early_context)
		_record_dialogue_plan_judgement_result(base_result)
		return base_result
	var current_plan := get_npc_daily_plan(npc_id)
	if current_plan.size() != 24:
		base_result["status"] = "missing_current_plan"
		base_result["summary"] = "当前没有可供对话后判别的 24 小时计划。"
		base_result["resume_result"] = _resume_interrupted_dialogue_plan(early_context)
		base_result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(early_context)
		_record_dialogue_plan_judgement_result(base_result)
		return base_result
	var context := dialogue_context.duplicate(true)
	context["npc_id"] = npc_id
	context["dialogue_history"] = dialogue_history
	context["current_plan"] = current_plan.duplicate(true)
	context["request_day"] = _get_current_day()
	context["request_hour"] = _get_current_hour()
	context["plan_version"] = _get_plan_version(npc_id)
	context["dialogue_epoch"] = int(dialogue_context.get(
		"dialogue_epoch",
		_get_npc_dialogue_epoch(npc_id)
	))
	var required_revision_hours: Array[int] = []
	var current_plan_item := get_current_plan_item(npc_id)
	if (
		(
			str(context.get("dialogue_kind", "")) == "npc_npc"
			and bool(context.get("autonomous", false))
			and str(context.get("speaker_npc_id", "")) == npc_id
		)
		or (
			str(context.get("dialogue_kind", "")) == "player_npc"
			and str(context.get("dialogue_initiator", "")) == "npc"
			and bool(context.get("proactive_talk", false))
			and str(current_plan_item.get("action_id", "")) == "seek_guard_officer"
		)
	):
		required_revision_hours.append(_get_current_hour())
	context["required_revision_hours"] = required_revision_hours.duplicate()
	context["execute_current_plan_when_resolved"] = (
		bool(dialogue_context.get("execute_current_plan_when_resolved", false))
		or _is_current_plan_waiting_for_dialogue_resolution(npc_id)
	)
	if bool(context.get("execute_current_plan_when_resolved", false)):
		_defer_current_plan_until_dialogue_resolved(npc_id, context)
	var interrupted_action_id := str(context.get("interrupted_action_id", ""))
	if (
		not interrupted_action_id.is_empty()
		and int(context.get("dialogue_epoch", -1)) == _get_npc_dialogue_epoch(npc_id)
	):
		var resume_token := context.duplicate(true)
		resume_token["day"] = _get_current_day()
		resume_token["hour"] = _get_current_hour()
		resume_token["plan_version"] = _get_plan_version(npc_id)
		_dialogue_resume_context_by_npc[npc_id] = resume_token
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if (
		llm_bridge == null
		or (
			not llm_bridge.has_method("request_plan_revision_judgement_async")
			and not llm_bridge.has_method("request_dialogue_plan_revision_judgement_async")
		)
	):
		base_result["status"] = "llm_bridge_unavailable"
		base_result["summary"] = "LLMBridge 不可用，保留原计划。"
		base_result["resume_result"] = _resume_interrupted_dialogue_plan(context)
		base_result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(base_result)
		return base_result
	var provider_check := _require_real_llm_provider(llm_bridge)
	if not bool(provider_check.get("ok", false)):
		base_result["status"] = str(provider_check.get("status", "real_provider_required"))
		base_result["summary"] = str(provider_check.get("message", "对话后计划判别要求真实 LLM provider。"))
		base_result["request_result"] = provider_check.duplicate(true)
		base_result["resume_result"] = _resume_interrupted_dialogue_plan(context)
		base_result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(base_result)
		return base_result
	if str(context.get("interrupted_action_id", "")).is_empty():
		var saved_resume_context: Dictionary = _dialogue_resume_context_by_npc.get(npc_id, {})
		if _is_dialogue_resume_context_current(saved_resume_context, npc_id):
			context["interrupted_action_id"] = str(saved_resume_context.get("interrupted_action_id", ""))
	var generation := int(_dialogue_plan_judgement_generation_by_npc.get(npc_id, 0)) + 1
	_dialogue_plan_judgement_generation_by_npc[npc_id] = generation
	context["judgement_generation"] = generation
	var judgement_options := {
		"trigger_kind": "dialogue",
		"current_plan": current_plan,
		"dialogue_kind": str(context.get("dialogue_kind", "player_npc")),
		"dialogue_history": dialogue_history,
		"dialogue_end_reason": str(context.get("dialogue_end_reason", "dialogue_completed")),
		"dialogue_context": _build_dialogue_judgement_context(context),
		"required_revision_hours": required_revision_hours.duplicate(),
		"requires_time_slowdown": true
	}
	var request_result: Dictionary = (
		llm_bridge.request_plan_revision_judgement_async(npc_id, judgement_options)
		if llm_bridge.has_method("request_plan_revision_judgement_async")
		else llm_bridge.request_dialogue_plan_revision_judgement_async(npc_id, judgement_options)
	)
	base_result["request_result"] = request_result.duplicate(true)
	if not bool(request_result.get("ok", false)):
		base_result["status"] = "dialogue_plan_judgement_request_failed"
		base_result["summary"] = "对话后计划判别请求启动失败：%s" % str(request_result.get("message", "请求失败。"))
		base_result["resume_result"] = _resume_interrupted_dialogue_plan(context)
		base_result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(base_result)
		return base_result
	var request_id := str(request_result.get("request_id", ""))
	if request_id.is_empty():
		base_result["status"] = "missing_request_id"
		base_result["summary"] = "对话后计划判别请求缺少 request_id，保留原计划。"
		base_result["resume_result"] = _resume_interrupted_dialogue_plan(context)
		base_result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(base_result)
		return base_result
	_async_dialogue_plan_judgement_requests[request_id] = context
	base_result["ok"] = true
	base_result["status"] = "dialogue_plan_judgement_pending"
	base_result["summary"] = "正在判断本轮对话是否需要修改计划。"
	_record_dialogue_plan_judgement_result(base_result)
	return base_result


func request_action_failure_plan_revision_judgement(
	npc_id: String,
	reason: String,
	failed_item: Dictionary,
	failure_summary: String,
	failure_context: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var failure_type := _normalize_failure_type(reason)
	var base_result := {
		"ok": false,
		"npc_id": npc_id,
		"trigger_kind": "action_failure",
		"reason": reason,
		"failure_type": failure_type,
		"failure_summary": failure_summary,
		"failure_context": failure_context.duplicate(true),
		"source": "",
		"fallback_used": false,
		"needs_revision": false,
		"revision_hours": [],
		"revision_requested": false,
		"status": "pending",
		"summary": "",
		"request_result": {},
		"revision_request_result": {},
		"execute_result": {}
	}
	var npc_system := _get_npc_system()
	if npc_system == null or npc_system.get_npc(npc_id).is_empty():
		base_result["status"] = "unknown_npc"
		base_result["summary"] = "找不到需要判别计划的 NPC。"
		_record_plan_revision_judgement_result(base_result)
		_record_reevaluation_result(npc_id, reason, base_result)
		return base_result
	var current_plan := get_npc_daily_plan(npc_id)
	if current_plan.size() != 24:
		base_result["status"] = "missing_current_plan"
		base_result["summary"] = "当前没有可供行动失败判别的 24 小时计划。"
		_record_plan_revision_judgement_result(base_result)
		_record_reevaluation_result(npc_id, reason, base_result)
		return base_result
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("request_plan_revision_judgement_async"):
		base_result["status"] = "llm_bridge_unavailable"
		base_result["summary"] = "LLMBridge 不可用，保留原计划。"
		_last_failure_result_by_npc.erase(npc_id)
		_record_plan_revision_judgement_result(base_result)
		_record_reevaluation_result(npc_id, reason, base_result)
		return base_result
	var provider_check := _require_real_llm_provider(llm_bridge)
	if not bool(provider_check.get("ok", false)):
		base_result["status"] = str(provider_check.get("status", "real_provider_required"))
		base_result["summary"] = str(provider_check.get("message", "行动失败计划判别要求真实 LLM provider。"))
		base_result["request_result"] = provider_check.duplicate(true)
		_last_failure_result_by_npc.erase(npc_id)
		_record_plan_revision_judgement_result(base_result)
		_record_reevaluation_result(npc_id, reason, base_result)
		return base_result
	var context := {
		"npc_id": npc_id,
		"trigger_kind": "action_failure",
		"reason": reason,
		"failure_type": failure_type,
		"failure_summary": failure_summary,
		"failure_context": failure_context.duplicate(true),
		"failed_plan_item": failed_item.duplicate(true),
		"current_plan": current_plan.duplicate(true),
		"request_day": _get_current_day(),
		"request_hour": _get_current_hour(),
		"plan_version": _get_plan_version(npc_id),
		"options": options.duplicate(true)
	}
	_reevaluating_npcs[npc_id] = "plan_revision_judgement_launching"
	var request_result: Dictionary = llm_bridge.request_plan_revision_judgement_async(
		npc_id,
		{
			"trigger_kind": "action_failure",
			"current_plan": current_plan,
			"failed_plan_item": failed_item,
			"failure_type": failure_type,
			"failure_summary": failure_summary,
			"failure_context": failure_context,
			"requires_time_slowdown": true
		}
	)
	base_result["request_result"] = request_result.duplicate(true)
	if not bool(request_result.get("ok", false)):
		base_result["status"] = "plan_revision_judgement_request_failed"
		base_result["summary"] = "行动失败后的计划判别请求启动失败：%s" % str(request_result.get("message", "请求失败。"))
		_reevaluating_npcs.erase(npc_id)
		_last_failure_result_by_npc.erase(npc_id)
		_record_plan_revision_judgement_result(base_result)
		_record_reevaluation_result(npc_id, reason, base_result)
		_drain_queued_reevaluation(npc_id)
		return base_result
	var request_id := str(request_result.get("request_id", ""))
	if request_id.is_empty():
		base_result["status"] = "missing_request_id"
		base_result["summary"] = "行动失败后的计划判别请求缺少 request_id，保留原计划。"
		_reevaluating_npcs.erase(npc_id)
		_last_failure_result_by_npc.erase(npc_id)
		_record_plan_revision_judgement_result(base_result)
		_record_reevaluation_result(npc_id, reason, base_result)
		_drain_queued_reevaluation(npc_id)
		return base_result
	_reevaluating_npcs[npc_id] = request_id
	_async_action_failure_plan_judgement_requests[request_id] = context
	base_result["ok"] = true
	base_result["status"] = "plan_revision_judgement_pending"
	base_result["summary"] = "正在判断本次行动失败是否需要修改计划。"
	_record_plan_revision_judgement_result(base_result)
	_record_reevaluation_result(npc_id, reason, base_result)
	return base_result


func request_plan_reevaluation(
	npc_id: String,
	reason: String,
	failed_item: Dictionary = {},
	failure_summary: String = "",
	failure_context_override: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	var npc_system := _get_npc_system()
	if npc_system == null or npc_system.get_npc(npc_id).is_empty():
		return _result(false, npc_id, "", "unknown_npc")
	var current_hour := _get_current_hour()
	var revision_hours := _normalize_revision_hours(
		options.get("revision_hours", [current_hour]),
		current_hour
	)
	if revision_hours.is_empty():
		return _result(false, npc_id, str(failed_item.get("action_id", "")), "empty_revision_hours")
	if _reevaluating_npcs.has(npc_id):
		var queued_failure_context := failure_context_override.duplicate(true)
		if queued_failure_context.is_empty():
			var queued_state: Dictionary = npc_system.get_npc_state(npc_id)
			queued_failure_context = queued_state.get("last_action_failure_context", {}).duplicate(true)
		var queued_result := {
			"ok": true,
			"npc_id": npc_id,
			"reason": reason,
			"source": "",
			"fallback_used": false,
			"status": "reevaluation_queued",
			"summary": "已有计划修订在途；本次更新已排队，将在当前请求结束后执行。",
			"request_result": {},
			"execute_result": {}
		}
		var existing_queued: Dictionary = _queued_reevaluation_by_npc.get(npc_id, {})
		var existing_options: Dictionary = (
			(existing_queued.get("options", {}) as Dictionary)
			if existing_queued.get("options", {}) is Dictionary
			else {}
		)
		var existing_dialogue_context: Dictionary = (
			(existing_options.get("dialogue_resume_context", {}) as Dictionary)
			if existing_options.get("dialogue_resume_context", {}) is Dictionary
			else {}
		)
		var incoming_dialogue_context: Dictionary = (
			(options.get("dialogue_resume_context", {}) as Dictionary)
			if options.get("dialogue_resume_context", {}) is Dictionary
			else {}
		)
		var queued_item := {
			"reason": reason,
			"failed_item": failed_item.duplicate(true),
			"failure_summary": failure_summary,
			"failure_context": queued_failure_context,
			"enqueue_day": _get_current_day(),
			"enqueue_hour": _get_current_hour(),
			"enqueue_plan_version": _get_plan_version(npc_id),
			"options": options.duplicate(true)
		}
		if (
			(
				bool(existing_dialogue_context.get("execute_current_plan_when_resolved", false))
				or _active_revision_has_dialogue_execution_barrier(npc_id)
			)
			and not bool(incoming_dialogue_context.get("execute_current_plan_when_resolved", false))
		):
			queued_result["status"] = "reevaluation_deferred_behind_dialogue_revision"
			queued_result["summary"] = "已有必须落地的对话计划修订排队；本次普通重评估将在该对话链后继续。"
			queued_item["rebase_after_dialogue_revision"] = true
			_queued_followup_reevaluation_by_npc[npc_id] = queued_item
			_record_reevaluation_result(npc_id, reason, queued_result)
			return queued_result
		_queued_reevaluation_by_npc[npc_id] = queued_item
		_record_reevaluation_result(npc_id, reason, queued_result)
		return queued_result
	if not bool(options.get("preserve_execution_retry_count", false)) and not reason.begins_with("revision_execution_failed"):
		_revision_execution_retry_counts.erase(npc_id)
	if reason in [
		"order_changed",
		"dialogue_completed",
		"proactive_dialogue_ended",
		"dialogue_plan_revision"
	]:
		_clear_revision_failure_cycle(npc_id)
	elif reason in ["dialogue_interrupted", "guard_attack"]:
		_record_revision_landing_failure(npc_id)
	if _get_revision_cycle_count(npc_id) >= FORMAL_REVISION_MAX_ATTEMPTS:
		var exhausted_result := {
			"ok": false,
			"npc_id": npc_id,
			"reason": reason,
			"failure_type": _normalize_failure_type(reason),
			"failure_summary": failure_summary,
			"source": "",
			"fallback_used": false,
			"status": "revision_cycle_exhausted",
			"summary": "该 NPC 在当前时段连续 %d 次真实 LLM 修订落地后仍执行失败；已停止本时段自动重试。" % FORMAL_REVISION_MAX_ATTEMPTS,
			"request_result": {},
			"execute_result": {},
		}
		_last_failure_result_by_npc[npc_id] = reason
		_record_reevaluation_result(npc_id, reason, exhausted_result)
		return exhausted_result

	var current_plan := get_npc_daily_plan(npc_id)
	if current_plan.size() != 24:
		var missing_plan_result := {
			"ok": false,
			"npc_id": npc_id,
			"reason": reason,
			"failure_type": _normalize_failure_type(reason),
			"failure_summary": failure_summary,
			"source": "",
			"fallback_used": false,
			"status": "missing_current_plan",
			"summary": "当前没有可供真实 LLM 修订的 24 小时计划。",
			"request_result": {},
			"execute_result": {}
		}
		_record_reevaluation_result(npc_id, reason, missing_plan_result)
		return missing_plan_result
	if failed_item.is_empty():
		failed_item = get_current_plan_item(npc_id)
	if failure_summary.is_empty():
		failure_summary = _describe_reevaluation_reason(reason, failed_item)
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	var failure_context: Dictionary = failure_context_override.duplicate(true)
	if failure_context.is_empty():
		failure_context = npc_state.get("last_action_failure_context", {}) if npc_state.get("last_action_failure_context", {}) is Dictionary else {}
	if _should_use_action_failure_plan_judgement(reason, options):
		return request_action_failure_plan_revision_judgement(
			npc_id,
			reason,
			failed_item,
			failure_summary,
			failure_context,
			options
		)

	var failure_type := _normalize_failure_type(reason)
	var result := {
		"ok": false,
		"npc_id": npc_id,
		"reason": reason,
		"failure_type": failure_type,
		"failure_summary": failure_summary,
		"failure_context": failure_context.duplicate(true),
		"source": "",
		"fallback_used": false,
		"status": "pending",
		"request_result": {},
		"execute_result": {}
	}
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("request_npc_plan_revision_async"):
		result["status"] = "llm_bridge_unavailable"
		result["summary"] = "LLMBridge 不可用，计划未修订。"
		_last_failure_result_by_npc.erase(npc_id)
		_record_reevaluation_result(npc_id, reason, result)
		return result
	var provider_check := _require_real_llm_provider(llm_bridge)
	if not bool(provider_check.get("ok", false)):
		result["status"] = str(provider_check.get("status", "real_provider_required"))
		result["summary"] = str(provider_check.get("message", "正式计划重估要求真实 LLM provider。"))
		result["request_result"] = provider_check.duplicate(true)
		_last_failure_result_by_npc.erase(npc_id)
		_record_reevaluation_result(npc_id, reason, result)
		return result

	var context := {
		"npc_id": npc_id,
		"reason": reason,
		"trigger_kind": str(options.get(
			"origin_trigger_kind",
			options.get("trigger_kind", "direct")
		)),
		"failure_type": failure_type,
		"failure_summary": failure_summary,
		"failure_context": failure_context.duplicate(true),
		"failed_plan_item": failed_item.duplicate(true),
		"current_plan": current_plan.duplicate(true),
		"request_day": _get_current_day(),
		"request_hour": _get_current_hour(),
		"revision_scope": REVISION_SCOPE_SELECTED_HOURS,
		"revision_hours": revision_hours.duplicate(),
		"dialogue_resume_context": (
			(options.get("dialogue_resume_context", {}) as Dictionary).duplicate(true)
			if options.get("dialogue_resume_context", {}) is Dictionary
			else {}
		),
		"dialogue_epoch": int(options.get(
			"dialogue_epoch",
			_get_npc_dialogue_epoch(npc_id)
		)),
		"plan_version": _get_plan_version(npc_id),
		"attempt": 1,
		"max_attempts": FORMAL_REVISION_MAX_ATTEMPTS
	}
	_reevaluating_npcs[npc_id] = "launching"
	var request_result := _launch_plan_revision_attempt(context)
	while not bool(request_result.get("ok", false)) and int(context.get("attempt", 1)) < FORMAL_REVISION_MAX_ATTEMPTS:
		context["attempt"] = int(context.get("attempt", 1)) + 1
		request_result = _launch_plan_revision_attempt(context)
	result["request_result"] = request_result.duplicate(true)
	result["attempt_count"] = int(context.get("attempt", 1))
	result["max_attempts"] = FORMAL_REVISION_MAX_ATTEMPTS
	if bool(request_result.get("ok", false)):
		result["ok"] = true
		result["status"] = "pending_async"
		result["summary"] = "正在由真实 LLM 重新评估计划。"
		_record_reevaluation_result(npc_id, reason, result)
		return result

	result["status"] = "llm_revision_request_failed"
	result["summary"] = "真实 LLM 计划修订请求启动失败：%s" % str(request_result.get("message", "请求失败。"))
	_reevaluating_npcs.erase(npc_id)
	_last_failure_result_by_npc.erase(npc_id)
	_record_reevaluation_result(npc_id, reason, result)
	_drain_queued_reevaluation(npc_id)
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


func _pump_async_plan_queue() -> void:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("request_npc_daily_plan_async"):
		_finish_async_plan_batch("async_llm_unavailable")
		return
	while _async_plan_requests.size() < _async_plan_max_concurrent and not _async_plan_queue.is_empty():
		var item: Dictionary = _async_plan_queue.pop_front()
		var npc_id := str(item.get("npc_id", ""))
		var attempt := int(item.get("attempt", 1))
		var attempts: Dictionary = _async_plan_batch_snapshot.get("attempt_count_by_npc", {})
		attempts[npc_id] = attempt
		_async_plan_batch_snapshot["attempt_count_by_npc"] = attempts
		var request_result: Dictionary = llm_bridge.request_npc_daily_plan_async(npc_id, {
			"planning_rules": _daily_planning_rules(),
			"requires_time_slowdown": false
		})
		if not bool(request_result.get("ok", false)):
			_record_async_plan_result(npc_id, item, request_result)
			continue
		var request_id := str(request_result.get("request_id", ""))
		_async_plan_requests[request_id] = item.duplicate(true)
	_async_plan_batch_snapshot["active_count"] = _async_plan_requests.size()
	_async_plan_batch_snapshot["max_observed_concurrent"] = maxi(
		int(_async_plan_batch_snapshot.get("max_observed_concurrent", 0)),
		_async_plan_requests.size()
	)
	_async_plan_batch_snapshot["queued_count"] = _async_plan_queue.size()
	if _async_plan_requests.is_empty() and _async_plan_queue.is_empty():
		_finish_async_plan_batch("completed")


func _on_daily_plan_async_response(response: Dictionary) -> void:
	var request_id := str(response.get("request_id", ""))
	var item: Dictionary = _async_plan_requests.get(request_id, {})
	if item.is_empty():
		return
	_async_plan_requests.erase(request_id)
	var npc_id := str(item.get("npc_id", response.get("npc_id", "")))
	_record_async_plan_result(npc_id, item, response)
	_pump_async_plan_queue()


func _on_plan_revision_judgement_async_response(response: Dictionary) -> void:
	var request_id := str(response.get("request_id", ""))
	if _async_action_failure_plan_judgement_requests.has(request_id):
		_on_action_failure_plan_revision_judgement_async_response(response)
		return
	_on_dialogue_plan_revision_judgement_async_response(response)


func _on_action_failure_plan_revision_judgement_async_response(response: Dictionary) -> void:
	var request_id := str(response.get("request_id", ""))
	var context: Dictionary = _async_action_failure_plan_judgement_requests.get(request_id, {})
	if context.is_empty():
		return
	_async_action_failure_plan_judgement_requests.erase(request_id)
	var npc_id := str(context.get("npc_id", response.get("npc_id", "")))
	var reason := str(context.get("reason", "unknown"))
	var result := {
		"ok": false,
		"npc_id": npc_id,
		"trigger_kind": "action_failure",
		"reason": reason,
		"failure_type": str(context.get("failure_type", "unknown")),
		"failure_summary": str(context.get("failure_summary", "")),
		"failure_context": (context.get("failure_context", {}) as Dictionary).duplicate(true),
		"source": "",
		"fallback_used": false,
		"needs_revision": false,
		"revision_hours": [],
		"revision_requested": false,
		"status": "pending",
		"summary": "",
		"request_result": response.duplicate(true),
		"revision_request_result": {},
		"execute_result": {}
	}
	if not _is_action_failure_judgement_context_current(context):
		result["status"] = "stale_plan_revision_judgement_discarded"
		result["summary"] = "行动失败计划判别已跨时段或计划版本过期，未修改当前计划。"
		_finish_action_failure_plan_judgement(context, result, true)
		return
	if not bool(response.get("ok", false)):
		result["status"] = (
			"request_cancelled"
			if _is_request_cancelled(response)
			else "plan_revision_judgement_request_failed"
		)
		result["summary"] = "行动失败后的计划判别失败，保留原计划：%s" % str(response.get("message", "请求失败。"))
		_finish_action_failure_plan_judgement(context, result, true)
		return
	var raw_judgement: Variant = response.get(
		"plan_revision_judgement",
		response.get("dialogue_plan_revision_judgement", {})
	)
	if not raw_judgement is Dictionary:
		result["status"] = "invalid_plan_revision_judgement"
		result["summary"] = "行动失败计划判别响应不是 JSON 对象，保留原计划。"
		_finish_action_failure_plan_judgement(context, result, true)
		return
	var judgement: Dictionary = raw_judgement
	var model_provider := str(judgement.get("model_provider", "")).strip_edges().to_lower()
	if model_provider.is_empty() or model_provider == "mock" or bool(judgement.get("model_fallback_used", false)):
		result["status"] = "mock_provider_forbidden"
		result["summary"] = "正式行动失败计划判别只接受真实 LLM provider，保留原计划。"
		_finish_action_failure_plan_judgement(context, result, true)
		return
	if str(judgement.get("npc_id", "")) != npc_id:
		result["status"] = "invalid_plan_revision_judgement"
		result["summary"] = "行动失败计划判别返回了错误的 NPC，保留原计划。"
		_finish_action_failure_plan_judgement(context, result, true)
		return
	var hours_validation := _validate_plan_revision_judgement_hours(
		judgement.get("revision_hours", []),
		bool(judgement.get("needs_revision", false)),
		int(context.get("request_hour", _get_current_hour()))
	)
	if not bool(hours_validation.get("ok", false)):
		result["status"] = "invalid_plan_revision_judgement"
		result["summary"] = str(hours_validation.get("message", "行动失败计划判别小时集合无效。"))
		_finish_action_failure_plan_judgement(context, result, true)
		return
	var revision_hours: Array[int] = []
	for raw_hour in hours_validation.get("revision_hours", []):
		revision_hours.append(int(raw_hour))
	result["ok"] = true
	result["needs_revision"] = not revision_hours.is_empty()
	result["revision_hours"] = revision_hours.duplicate()
	result["summary"] = str(judgement.get("summary", ""))
	result["model_provider"] = model_provider
	result["model_name"] = str(judgement.get("model_name", ""))
	_record_plan_revision_judgement_result(result)
	if revision_hours.is_empty():
		result["status"] = "action_failure_plan_unchanged"
		if str(result.get("summary", "")).is_empty():
			result["summary"] = "本次行动失败不需要修改原计划。"
		_finish_action_failure_plan_judgement(context, result, false)
		return

	var revised_failure_context: Dictionary = (
		(context.get("failure_context", {}) as Dictionary).duplicate(true)
		if context.get("failure_context", {}) is Dictionary
		else {}
	)
	revised_failure_context["plan_revision_judgement"] = judgement.duplicate(true)
	var stage_two_options: Dictionary = (
		(context.get("options", {}) as Dictionary).duplicate(true)
		if context.get("options", {}) is Dictionary
		else {}
	)
	stage_two_options["skip_plan_revision_judgement"] = true
	stage_two_options["revision_hours"] = revision_hours.duplicate()
	stage_two_options["origin_trigger_kind"] = "action_failure"
	_reevaluating_npcs.erase(npc_id)
	var revision_request_result := request_plan_reevaluation(
		npc_id,
		reason,
		(context.get("failed_plan_item", {}) as Dictionary).duplicate(true),
		str(context.get("failure_summary", "")),
		revised_failure_context,
		stage_two_options
	)
	result["revision_request_result"] = revision_request_result.duplicate(true)
	result["revision_requested"] = bool(revision_request_result.get("ok", false))
	result["status"] = (
		"action_failure_plan_revision_requested"
		if bool(revision_request_result.get("ok", false))
		else "action_failure_plan_revision_request_failed"
	)
	_record_plan_revision_judgement_result(result)
	if not bool(revision_request_result.get("ok", false)):
		_record_reevaluation_result(npc_id, reason, result)
		_drain_queued_reevaluation(npc_id)


func _on_dialogue_plan_revision_judgement_async_response(response: Dictionary) -> void:
	var request_id := str(response.get("request_id", ""))
	var context: Dictionary = _async_dialogue_plan_judgement_requests.get(request_id, {})
	if context.is_empty():
		return
	_async_dialogue_plan_judgement_requests.erase(request_id)
	var npc_id := str(context.get("npc_id", response.get("npc_id", "")))
	var result := {
		"ok": false,
		"npc_id": npc_id,
		"dialogue_id": str(context.get("dialogue_id", "")),
		"dialogue_kind": str(context.get("dialogue_kind", "player_npc")),
		"dialogue_end_reason": str(context.get("dialogue_end_reason", "dialogue_completed")),
		"needs_revision": false,
		"revision_hours": [],
		"revision_requested": false,
		"status": "pending",
		"summary": "",
		"request_result": response.duplicate(true),
		"revision_request_result": {},
		"resume_result": {}
	}
	if not _is_dialogue_judgement_context_current(context):
		if _should_rebase_dialogue_judgement(context):
			var retry_context := context.duplicate(true)
			var interrupted_action_id := str(retry_context.get("interrupted_action_id", ""))
			if (
				not interrupted_action_id.is_empty()
				and str(get_current_plan_item(npc_id).get("action_id", "")) != interrupted_action_id
			):
				retry_context["interrupted_action_id"] = ""
				_dialogue_resume_context_by_npc.erase(npc_id)
			retry_context["judgement_rebase_attempt"] = int(
				context.get("judgement_rebase_attempt", 0)
			) + 1
			var retry_result := request_dialogue_plan_revision_judgement(
				npc_id,
				retry_context
			)
			result["ok"] = bool(retry_result.get("ok", false))
			result["status"] = "dialogue_plan_judgement_rebased"
			result["summary"] = "计划版本已变化，正在基于最新原计划重新判断本轮对话。"
			result["request_result"] = retry_result.duplicate(true)
			_record_dialogue_plan_judgement_result(result)
			return
		result["status"] = "stale_dialogue_plan_judgement_discarded"
		result["summary"] = "对话后计划判别已跨时段或计划版本过期，未修改当前计划。"
		result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(result)
		return
	if not bool(response.get("ok", false)):
		result["status"] = (
			"request_cancelled"
			if _is_request_cancelled(response)
			else "dialogue_plan_judgement_request_failed"
		)
		result["summary"] = "对话后计划判别失败，保留原计划：%s" % str(response.get("message", "请求失败。"))
		result["resume_result"] = _resume_interrupted_dialogue_plan(context)
		result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(result)
		return
	var raw_judgement: Variant = response.get(
		"plan_revision_judgement",
		response.get("dialogue_plan_revision_judgement", {})
	)
	if not raw_judgement is Dictionary:
		result["status"] = "invalid_dialogue_plan_judgement"
		result["summary"] = "对话后计划判别响应不是 JSON 对象，保留原计划。"
		result["resume_result"] = _resume_interrupted_dialogue_plan(context)
		result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(result)
		return
	var judgement: Dictionary = raw_judgement
	var model_provider := str(judgement.get("model_provider", "")).strip_edges().to_lower()
	if model_provider.is_empty() or model_provider == "mock" or bool(judgement.get("model_fallback_used", false)):
		result["status"] = "mock_provider_forbidden"
		result["summary"] = "正式对话后计划判别只接受真实 LLM provider，保留原计划。"
		result["resume_result"] = _resume_interrupted_dialogue_plan(context)
		result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(result)
		return
	if str(judgement.get("npc_id", "")) != npc_id:
		result["status"] = "invalid_dialogue_plan_judgement"
		result["summary"] = "对话后计划判别返回了错误的 NPC，保留原计划。"
		result["resume_result"] = _resume_interrupted_dialogue_plan(context)
		result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(result)
		return
	var hours_validation := _validate_plan_revision_judgement_hours(
		judgement.get("revision_hours", []),
		bool(judgement.get("needs_revision", false)),
		int(context.get("request_hour", _get_current_hour()))
	)
	if not bool(hours_validation.get("ok", false)):
		result["status"] = "invalid_dialogue_plan_judgement"
		result["summary"] = str(hours_validation.get("message", "对话后计划判别小时集合无效。"))
		result["resume_result"] = _resume_interrupted_dialogue_plan(context)
		result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(result)
		return
	var revision_hours: Array[int] = []
	for raw_hour in hours_validation.get("revision_hours", []):
		revision_hours.append(int(raw_hour))
	for raw_required_hour in context.get("required_revision_hours", []):
		var required_hour := int(raw_required_hour)
		if not revision_hours.has(required_hour):
			result["status"] = "invalid_dialogue_plan_judgement"
			result["summary"] = "对话后计划判别遗漏了必须修改的当前小时。"
			result["resume_result"] = _resume_interrupted_dialogue_plan(context)
			result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
			_record_dialogue_plan_judgement_result(result)
			return
	var needs_revision := not revision_hours.is_empty()
	result["ok"] = true
	result["needs_revision"] = needs_revision
	result["revision_hours"] = revision_hours.duplicate()
	result["summary"] = str(judgement.get("summary", ""))
	result["model_provider"] = model_provider
	result["model_name"] = str(judgement.get("model_name", ""))
	if not needs_revision:
		result["status"] = "dialogue_plan_unchanged"
		if str(result.get("summary", "")).is_empty():
			result["summary"] = "本轮对话不需要修改原计划。"
		result["resume_result"] = _resume_interrupted_dialogue_plan(context)
		result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
		_record_dialogue_plan_judgement_result(result)
		return

	var current_hour := _get_current_hour()
	var failure_context := _build_dialogue_revision_failure_context(context, judgement)
	var revision_request_result := request_plan_reevaluation(
		npc_id,
		"dialogue_plan_revision",
		get_current_plan_item(npc_id),
		"对话后判别需要修改第 %s 小时的计划。" % _join_ints(revision_hours),
		failure_context,
		{
			"revision_hours": revision_hours,
			"dialogue_resume_context": context.duplicate(true),
			"dialogue_epoch": int(context.get("dialogue_epoch", _get_npc_dialogue_epoch(npc_id)))
		}
	)
	result["revision_request_result"] = revision_request_result.duplicate(true)
	result["revision_requested"] = bool(revision_request_result.get("ok", false))
	result["status"] = (
		"dialogue_plan_revision_requested"
		if bool(revision_request_result.get("ok", false))
		else "dialogue_plan_revision_request_failed"
	)
	if not revision_hours.has(current_hour) or not bool(revision_request_result.get("ok", false)):
		result["resume_result"] = _resume_interrupted_dialogue_plan(context)
	if not bool(revision_request_result.get("ok", false)):
		result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(context)
	_record_dialogue_plan_judgement_result(result)


func _build_dialogue_judgement_context(context: Dictionary) -> Dictionary:
	return {
		"dialogue_id": str(context.get("dialogue_id", "")),
		"visibility": str(context.get("visibility", "private")),
		"location_id": str(context.get("location_id", "plaza")),
		"location_name": str(context.get("location_name", "广场")),
		"interaction_context": str(context.get("interaction_context", "work")),
		"participant_npc_ids": (
			(context.get("participant_npc_ids", []) as Array).duplicate(true)
			if context.get("participant_npc_ids", []) is Array
			else []
		),
		"current_round": int(context.get("current_round", 0)),
		"invitation_result": str(context.get("invitation_result", "")),
		"attack_committed": bool(context.get("attack_committed", false)),
		"dialogue_initiator": str(context.get("dialogue_initiator", "")),
		"proactive_talk": bool(context.get("proactive_talk", false)),
		"autonomous": bool(context.get("autonomous", false)),
		"speaker_npc_id": str(context.get("speaker_npc_id", "")),
		"target_npc_id": str(context.get("target_npc_id", "")),
		"plan_action_source": str(context.get("plan_action_source", "")),
		"assigned_plan_day": int(context.get("assigned_plan_day", -1)),
		"assigned_plan_hour": int(context.get("assigned_plan_hour", -1))
	}


func _build_dialogue_revision_failure_context(
	context: Dictionary,
	judgement: Dictionary
) -> Dictionary:
	return {
		"dialogue_id": str(context.get("dialogue_id", "")),
		"dialogue_kind": str(context.get("dialogue_kind", "player_npc")),
		"dialogue_end_reason": str(context.get("dialogue_end_reason", "dialogue_completed")),
		"dialogue_history": (
			(context.get("dialogue_history", []) as Array).duplicate(true)
			if context.get("dialogue_history", []) is Array
			else []
		),
		"dialogue_context": _build_dialogue_judgement_context(context),
		"dialogue_plan_judgement": {
			"needs_revision": bool(judgement.get("needs_revision", false)),
			"revision_hours": (
				(judgement.get("revision_hours", []) as Array).duplicate(true)
				if judgement.get("revision_hours", []) is Array
				else []
			),
			"summary": str(judgement.get("summary", "")),
			"debug_reason": str(judgement.get("debug_reason", ""))
		}
	}


func _validate_plan_revision_judgement_hours(
	raw_hours: Variant,
	needs_revision: bool,
	minimum_hour: int
) -> Dictionary:
	if not raw_hours is Array:
		return {"ok": false, "message": "计划修改判别缺少 revision_hours 数组。"}
	var revision_hours: Array[int] = []
	var previous_hour := -1
	for raw_hour in raw_hours:
		var hour := int(raw_hour)
		if hour < minimum_hour or hour > 23:
			return {"ok": false, "message": "计划修改判别不能修改已经过去或越界的小时。"}
		if hour <= previous_hour:
			return {"ok": false, "message": "计划修改判别的 revision_hours 必须去重并升序排列。"}
		revision_hours.append(hour)
		previous_hour = hour
	if needs_revision != not revision_hours.is_empty():
		return {"ok": false, "message": "needs_revision 必须与 revision_hours 是否为空一致。"}
	return {"ok": true, "revision_hours": revision_hours}


func _validate_dialogue_judgement_hours(
	raw_hours: Variant,
	needs_revision: bool,
	minimum_hour: int
) -> Dictionary:
	return _validate_plan_revision_judgement_hours(raw_hours, needs_revision, minimum_hour)


func _normalize_revision_hours(value: Variant, minimum_hour: int) -> Array[int]:
	var revision_hours: Array[int] = []
	if not value is Array:
		return revision_hours
	for raw_hour in value:
		var hour := int(raw_hour)
		if hour < minimum_hour or hour > 23 or revision_hours.has(hour):
			continue
		revision_hours.append(hour)
	revision_hours.sort()
	return revision_hours


func _is_dialogue_judgement_context_current(context: Dictionary) -> bool:
	var npc_id := str(context.get("npc_id", ""))
	if npc_id.is_empty():
		return false
	return (
		int(context.get("request_day", -1)) == _get_current_day()
		and int(context.get("request_hour", -1)) == _get_current_hour()
		and int(context.get("plan_version", -1)) == _get_plan_version(npc_id)
		and int(context.get("dialogue_epoch", -1)) == _get_npc_dialogue_epoch(npc_id)
		and int(context.get("judgement_generation", -1)) == int(
			_dialogue_plan_judgement_generation_by_npc.get(npc_id, 0)
		)
	)


func _should_rebase_dialogue_judgement(context: Dictionary) -> bool:
	var npc_id := str(context.get("npc_id", ""))
	if npc_id.is_empty() or int(context.get("judgement_rebase_attempt", 0)) >= 1:
		return false
	return (
		int(context.get("request_day", -1)) == _get_current_day()
		and int(context.get("request_hour", -1)) == _get_current_hour()
		and int(context.get("dialogue_epoch", -1)) == _get_npc_dialogue_epoch(npc_id)
		and int(context.get("judgement_generation", -1)) == int(
			_dialogue_plan_judgement_generation_by_npc.get(npc_id, 0)
		)
		and int(context.get("plan_version", -1)) != _get_plan_version(npc_id)
	)


func _is_action_failure_judgement_context_current(context: Dictionary) -> bool:
	var npc_id := str(context.get("npc_id", ""))
	if npc_id.is_empty():
		return false
	return (
		int(context.get("request_day", -1)) == _get_current_day()
		and int(context.get("request_hour", -1)) == _get_current_hour()
		and int(context.get("plan_version", -1)) == _get_plan_version(npc_id)
	)


func _finish_action_failure_plan_judgement(
	context: Dictionary,
	result: Dictionary,
	clear_failure_cache: bool
) -> void:
	var npc_id := str(context.get("npc_id", result.get("npc_id", "")))
	var reason := str(context.get("reason", result.get("reason", "unknown")))
	_reevaluating_npcs.erase(npc_id)
	if clear_failure_cache:
		_last_failure_result_by_npc.erase(npc_id)
	_record_plan_revision_judgement_result(result)
	_record_reevaluation_result(npc_id, reason, result)
	_drain_queued_reevaluation(npc_id)
	schedule_ready_deferred_current_plans()


func _is_dialogue_resume_context_current(context: Dictionary, npc_id: String) -> bool:
	var context_day := int(context.get("day", context.get("request_day", -1)))
	var context_hour := int(context.get("hour", context.get("request_hour", -1)))
	var context_epoch := int(context.get("dialogue_epoch", -1))
	return (
		not context.is_empty()
		and str(context.get("npc_id", npc_id)) == npc_id
		and context_day == _get_current_day()
		and context_hour == _get_current_hour()
		and int(context.get("plan_version", -1)) == _get_plan_version(npc_id)
		and (context_epoch < 0 or context_epoch == _get_npc_dialogue_epoch(npc_id))
	)


func _resume_interrupted_dialogue_plan(context: Dictionary) -> Dictionary:
	var npc_id := str(context.get("npc_id", ""))
	var effective_context := context.duplicate(true)
	if not npc_id.is_empty():
		var saved_context: Dictionary = _dialogue_resume_context_by_npc.get(npc_id, {})
		var saved_is_current := _is_dialogue_resume_context_current(saved_context, npc_id)
		if not saved_context.is_empty() and not saved_is_current:
			_dialogue_resume_context_by_npc.erase(npc_id)
		var supplied_dialogue_id := str(context.get("dialogue_id", ""))
		var supplied_epoch := int(context.get("dialogue_epoch", -1))
		var saved_matches_supplied_chain := (
			supplied_dialogue_id.is_empty()
			or str(saved_context.get("dialogue_id", "")) == supplied_dialogue_id
		)
		saved_matches_supplied_chain = saved_matches_supplied_chain and (
			supplied_epoch < 0
			or int(saved_context.get("dialogue_epoch", -1)) == supplied_epoch
		)
		if saved_is_current and saved_matches_supplied_chain:
			effective_context = saved_context.duplicate(true)
	var interrupted_action_id := str(effective_context.get("interrupted_action_id", ""))
	if not _is_dialogue_resume_context_current(effective_context, npc_id):
		return {}
	if (
		npc_id.is_empty()
		or interrupted_action_id.is_empty()
		or interrupted_action_id in ["talk_to_npc", "proactive_talk", "seek_guard_officer"]
	):
		return {}
	var npc_system := _get_npc_system()
	if (
		npc_system == null
		or not npc_system.can_npc_act(npc_id)
		or not _is_npc_in_work_behavior_mode(npc_id, npc_system)
	):
		return {}
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if (
		dialog_system != null
		and dialog_system.has_method("is_npc_in_dialogue")
		and dialog_system.is_npc_in_dialogue(npc_id)
	):
		# A newer conversation owns this NPC now. Keep its current resume token;
		# an older judgement/revision chain must never force-end the newer session.
		return {}
	var result := resume_current_plan_after_dialogue(npc_id, interrupted_action_id)
	if (
		bool(result.get("ok", false))
		and str(result.get("status", "")) != "dialogue_plan_judgement_pending"
	):
		_dialogue_resume_context_by_npc.erase(npc_id)
	return result


func _record_dialogue_plan_judgement_result(result: Dictionary) -> void:
	_last_dialogue_plan_judgement_result = result.duplicate(true)
	_record_plan_revision_judgement_result(result)


func _record_plan_revision_judgement_result(result: Dictionary) -> void:
	_last_plan_revision_judgement_result = result.duplicate(true)


func _join_ints(values: Array[int]) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return "、".join(parts)


func _on_plan_revision_async_response(response: Dictionary) -> void:
	var request_id := str(response.get("request_id", ""))
	var context: Dictionary = _async_revision_requests.get(request_id, {})
	if context.is_empty():
		return
	_async_revision_requests.erase(request_id)
	var npc_id := str(context.get("npc_id", response.get("npc_id", "")))
	# A normal failure revision can be queued behind a dialogue stage-two revision.
	# Preserve that dialogue's ready marker across set_npc_daily_plan(), which clears
	# execution markers when a revision is applied. The marker is rebased below only
	# after this blocking revision reaches a terminal response.
	var deferred_dispatch_snapshot: Dictionary = (
		(_deferred_current_revision_execution_by_npc.get(npc_id, {}) as Dictionary).duplicate(true)
		if _deferred_current_revision_execution_by_npc.get(npc_id, {}) is Dictionary
		else {}
	)
	var reason := str(context.get("reason", "unknown"))
	var current_plan: Array = context.get("current_plan", [])
	var result := {
		"ok": false,
		"npc_id": npc_id,
		"reason": reason,
		"failure_type": str(context.get("failure_type", "unknown")),
		"failure_summary": str(context.get("failure_summary", "")),
		"failure_context": context.get("failure_context", {}),
		"source": "",
		"fallback_used": false,
		"status": "pending",
		"request_result": response.duplicate(true),
		"execute_result": {},
		"attempt_count": int(context.get("attempt", 1)),
		"max_attempts": int(context.get("max_attempts", FORMAL_REVISION_MAX_ATTEMPTS))
	}
	if not _is_revision_context_current(context):
		result["status"] = "stale_revision_discarded"
		result["summary"] = "计划修订回复已跨时段或计划版本过期，已丢弃且未覆盖当前计划。"
	elif bool(response.get("ok", false)):
		var raw_revision: Variant = response.get("plan_revision", {})
		if raw_revision is Dictionary:
			var apply_result := _apply_revision_response(
				npc_id,
				raw_revision,
				reason,
				current_plan,
				context
			)
			for key in apply_result.keys():
				result[key] = apply_result[key]
		else:
			result["status"] = "invalid_revision_response"
			result["summary"] = "真实 LLM 计划修订响应不是 JSON 对象。"
	elif _is_request_cancelled(response):
		result["status"] = "request_cancelled"
		result["summary"] = "计划修订请求被玩家对话打断。"
	else:
		result["status"] = "llm_revision_request_failed"
		result["summary"] = "真实 LLM 计划修订请求失败：%s" % str(response.get("message", "请求失败。"))

	if _should_retry_plan_revision(context, result):
		var retry_context := context.duplicate(true)
		retry_context["attempt"] = int(context.get("attempt", 1)) + 1
		var launch_result := _launch_plan_revision_attempt(retry_context)
		if bool(launch_result.get("ok", false)):
			result["status"] = "pending_async"
			result["summary"] = "真实 LLM 计划修订失败，正在进行第 %d 次尝试。" % int(retry_context.get("attempt", 2))
			result["last_attempt_result"] = response.duplicate(true)
			result["request_result"] = launch_result.duplicate(true)
			result["attempt_count"] = int(retry_context.get("attempt", 2))
			_record_reevaluation_result(npc_id, reason, result)
			return
		result["status"] = "llm_revision_request_failed"
		result["summary"] = "真实 LLM 计划修订重试启动失败：%s" % str(launch_result.get("message", "请求失败。"))
		result["request_result"] = launch_result.duplicate(true)
	var dialogue_resume_context: Dictionary = (
		(context.get("dialogue_resume_context", {}) as Dictionary).duplicate(true)
		if context.get("dialogue_resume_context", {}) is Dictionary
		else {}
	)
	var selected_hours := _normalize_revision_hours(
		context.get("revision_hours", []),
		int(context.get("request_hour", _get_current_hour()))
	)
	if (
		not bool(result.get("plan_applied", false))
		and selected_hours.has(int(context.get("request_hour", _get_current_hour())))
		and not dialogue_resume_context.is_empty()
		and str(result.get("status", "")) != "stale_revision_discarded"
		and int(context.get("dialogue_epoch", _get_npc_dialogue_epoch(npc_id))) == _get_npc_dialogue_epoch(npc_id)
	):
		result["resume_result"] = _resume_interrupted_dialogue_plan(dialogue_resume_context)
	if not dialogue_resume_context.is_empty():
		result["current_plan_dispatch_result"] = _finish_dialogue_resolution_execution(
			dialogue_resume_context,
			bool(result.get("plan_applied", false))
			and bool(result.get("current_hour_revised", false))
		)
	_reevaluating_npcs.erase(npc_id)
	if dialogue_resume_context.is_empty():
		_restore_deferred_current_plan_marker_after_revision(
			npc_id,
			deferred_dispatch_snapshot
		)
	_last_failure_result_by_npc.erase(npc_id)
	if bool(result.get("plan_applied", false)):
		if bool(result.get("ok", false)):
			_revision_execution_retry_counts.erase(npc_id)
		else:
			_record_revision_landing_failure(npc_id)
			var retry_count := int(_revision_execution_retry_counts.get(npc_id, 0)) + 1
			_revision_execution_retry_counts[npc_id] = retry_count
			if retry_count < FORMAL_REVISION_MAX_ATTEMPTS:
				# A synchronous ActionSystem failure normally queues its exact authoritative
				# reason while this response still owns the revision lock. That queued trigger
				# is the only successor; launching a generic retry as well creates two racing
				# chains and can reset the bounded retry counter indefinitely.
				if not _queued_reevaluation_by_npc.has(npc_id):
					call_deferred("_request_revision_after_execution_failure", npc_id, retry_count)
			else:
				result["status"] = "revision_execution_retry_exhausted"
				result["summary"] = "%s 已达到真实 LLM 修订后即时执行的重试上限，停止自动重试。" % str(result.get("summary", "修订行动仍无法执行。"))
				_queued_reevaluation_by_npc.erase(npc_id)
	_record_reevaluation_result(npc_id, reason, result)
	_drain_queued_reevaluation(npc_id)
	# _drain_queued_reevaluation starts the successor synchronously. If one launched,
	# _has_pending_dialogue_plan_chain keeps the marker blocked; otherwise this is the
	# terminal point that releases the current plan exactly once.
	schedule_ready_deferred_current_plans()


func _launch_plan_revision_attempt(context: Dictionary) -> Dictionary:
	var npc_id := str(context.get("npc_id", ""))
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("request_npc_plan_revision_async"):
		return {
			"ok": false,
			"error_code": "llm_bridge_unavailable",
			"message": "LLMBridge 不可用。"
		}
	var request_result: Dictionary = llm_bridge.request_npc_plan_revision_async(npc_id, {
		"current_plan": context.get("current_plan", []),
		"failed_plan_item": context.get("failed_plan_item", {}),
		"failure_type": str(context.get("failure_type", "unknown")),
		"failure_summary": str(context.get("failure_summary", "")),
		"failure_context": context.get("failure_context", {}),
		"revision_scope": REVISION_SCOPE_SELECTED_HOURS,
		"revision_hours": context.get("revision_hours", [_get_current_hour()]),
		"requires_time_slowdown": true
	})
	if not bool(request_result.get("ok", false)):
		return request_result
	var request_id := str(request_result.get("request_id", ""))
	if request_id.is_empty():
		return {
			"ok": false,
			"error_code": "missing_request_id",
			"message": "异步计划修订请求缺少 request_id。"
		}
	_reevaluating_npcs[npc_id] = request_id
	_async_revision_requests[request_id] = context.duplicate(true)
	return request_result


func _should_retry_plan_revision(context: Dictionary, result: Dictionary) -> bool:
	if bool(result.get("ok", false)):
		return false
	if bool(result.get("plan_applied", false)):
		return false
	if str(result.get("status", "")) in ["mock_provider_forbidden", "request_cancelled", "stale_revision_discarded"]:
		return false
	return int(context.get("attempt", 1)) < int(context.get("max_attempts", FORMAL_REVISION_MAX_ATTEMPTS))


func _drain_queued_reevaluation(npc_id: String) -> void:
	var queued: Dictionary = _queued_reevaluation_by_npc.get(npc_id, {})
	if queued.is_empty():
		queued = _queued_followup_reevaluation_by_npc.get(npc_id, {})
		if queued.is_empty():
			return
		_queued_followup_reevaluation_by_npc.erase(npc_id)
	else:
		_queued_reevaluation_by_npc.erase(npc_id)
	var same_day_and_hour := (
		int(queued.get("enqueue_day", -1)) == _get_current_day()
		and int(queued.get("enqueue_hour", -1)) == _get_current_hour()
	)
	if (
		not same_day_and_hour
		or int(queued.get("enqueue_plan_version", -1)) != _get_plan_version(npc_id)
	):
		var stale_reason := str(queued.get("reason", "queued_reevaluation"))
		var queued_options: Dictionary = (
			(queued.get("options", {}) as Dictionary).duplicate(true)
			if queued.get("options", {}) is Dictionary
			else {}
		)
		if (
			same_day_and_hour
			and stale_reason == "dialogue_plan_revision"
			and int(queued_options.get("dialogue_epoch", -1)) == _get_npc_dialogue_epoch(npc_id)
		):
			# A preceding revision may bump the plan version while this dialogue-derived
			# request waits. Rebase its exact selected hours onto the new authoritative
			# plan instead of silently dropping the latest conversation outcome.
			queued_options = _rebase_dialogue_resume_option_to_current_plan(
				npc_id,
				queued_options
			)
			_run_queued_reevaluation(
				npc_id,
				stale_reason,
				get_current_plan_item(npc_id),
				str(queued.get("failure_summary", "")),
				(queued.get("failure_context", {}) as Dictionary).duplicate(true),
				queued_options
			)
			return
		if same_day_and_hour and bool(queued.get("rebase_after_dialogue_revision", false)):
			var current_item := get_current_plan_item(npc_id)
			var queued_failed_item: Dictionary = (
				(queued.get("failed_item", {}) as Dictionary).duplicate(true)
				if queued.get("failed_item", {}) is Dictionary
				else {}
			)
			var failed_action_id := str(queued_failed_item.get("action_id", ""))
			if failed_action_id.is_empty() or failed_action_id == str(current_item.get("action_id", "")):
				_run_queued_reevaluation(
					npc_id,
					stale_reason,
					current_item,
					str(queued.get("failure_summary", "")),
					(queued.get("failure_context", {}) as Dictionary).duplicate(true),
					queued_options
				)
				return
		if stale_reason == "order_changed":
			var current_item := get_current_plan_item(npc_id)
			_run_queued_reevaluation(
				npc_id,
				stale_reason,
				current_item,
				_describe_reevaluation_reason(stale_reason, current_item),
				{},
				{}
			)
			return
		_record_reevaluation_result(npc_id, stale_reason, {
			"ok": false,
			"npc_id": npc_id,
			"reason": stale_reason,
			"source": "",
			"fallback_used": false,
			"status": "stale_queued_reevaluation_discarded",
			"summary": "排队的计划重评估已跨时段或计划版本过期，未覆盖当前计划。",
			"request_result": {},
			"execute_result": {},
		})
		call_deferred("_drain_queued_reevaluation", npc_id)
		return
	_run_queued_reevaluation(
		npc_id,
		str(queued.get("reason", "queued_reevaluation")),
		(queued.get("failed_item", {}) as Dictionary).duplicate(true),
		str(queued.get("failure_summary", "")),
		(queued.get("failure_context", {}) as Dictionary).duplicate(true),
		(queued.get("options", {}) as Dictionary).duplicate(true)
	)


func _active_revision_has_dialogue_execution_barrier(npc_id: String) -> bool:
	var request_id := str(_reevaluating_npcs.get(npc_id, ""))
	if request_id.is_empty() or request_id == "launching":
		return false
	var active_context: Dictionary = _async_revision_requests.get(request_id, {})
	var dialogue_context: Dictionary = (
		(active_context.get("dialogue_resume_context", {}) as Dictionary)
		if active_context.get("dialogue_resume_context", {}) is Dictionary
		else {}
	)
	return bool(dialogue_context.get("execute_current_plan_when_resolved", false))


func _rebase_dialogue_resume_option_to_current_plan(
	npc_id: String,
	options: Dictionary
) -> Dictionary:
	var next_options := options.duplicate(true)
	var resume_context: Dictionary = (
		(next_options.get("dialogue_resume_context", {}) as Dictionary).duplicate(true)
		if next_options.get("dialogue_resume_context", {}) is Dictionary
		else {}
	)
	var interrupted_action_id := str(resume_context.get("interrupted_action_id", ""))
	var current_item := get_current_plan_item(npc_id)
	var current_signature := (
		_make_plan_execution_signature(npc_id, current_item)
		if not current_item.is_empty()
		else ""
	)
	if (
		resume_context.is_empty()
		or interrupted_action_id.is_empty()
		or str(current_item.get("action_id", "")) != interrupted_action_id
		or current_signature.is_empty()
		or str(_plan_execution_signature_by_npc.get(npc_id, "")) != current_signature
	):
		return next_options
	resume_context["plan_version"] = _get_plan_version(npc_id)
	resume_context["request_day"] = _get_current_day()
	resume_context["request_hour"] = _get_current_hour()
	next_options["dialogue_resume_context"] = resume_context
	var saved: Dictionary = _dialogue_resume_context_by_npc.get(npc_id, {})
	if (
		str(saved.get("dialogue_id", "")) == str(resume_context.get("dialogue_id", ""))
		and int(saved.get("dialogue_epoch", -1)) == int(resume_context.get("dialogue_epoch", -1))
	):
		resume_context["day"] = _get_current_day()
		resume_context["hour"] = _get_current_hour()
		_dialogue_resume_context_by_npc[npc_id] = resume_context.duplicate(true)
	return next_options


func _run_queued_reevaluation(
	npc_id: String,
	reason: String,
	failed_item: Dictionary,
	failure_summary: String,
	failure_context: Dictionary,
	queued_options: Dictionary
) -> void:
	var request_options := queued_options.duplicate(true)
	request_options["preserve_execution_retry_count"] = true
	var request_result := request_plan_reevaluation(
		npc_id,
		reason,
		failed_item,
		failure_summary,
		failure_context,
		request_options
	)
	if bool(request_result.get("ok", false)):
		return
	var dialogue_resume_context: Dictionary = (
		(request_options.get("dialogue_resume_context", {}) as Dictionary).duplicate(true)
		if request_options.get("dialogue_resume_context", {}) is Dictionary
		else {}
	)
	if not dialogue_resume_context.is_empty():
		_resume_interrupted_dialogue_plan(dialogue_resume_context)
		_finish_dialogue_resolution_execution(dialogue_resume_context)
	else:
		schedule_ready_deferred_current_plans()
	call_deferred("_drain_queued_reevaluation", npc_id)


func _cancel_plan_revision_for_new_day(npc_id: String) -> void:
	var request_id := str(_reevaluating_npcs.get(npc_id, ""))
	if not request_id.is_empty() and request_id != "launching":
		var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
		if llm_bridge != null and llm_bridge.has_method("cancel_npc_llm_requests"):
			llm_bridge.cancel_npc_llm_requests(npc_id, "new_day_plan_replaced_revision")
	for raw_request_id in _async_revision_requests.keys():
		var pending_request_id := str(raw_request_id)
		var context: Dictionary = _async_revision_requests.get(pending_request_id, {})
		if str(context.get("npc_id", "")) == npc_id:
			var revision_bridge := get_node_or_null(LLM_BRIDGE_PATH)
			if revision_bridge != null and revision_bridge.has_method("cancel_llm_request"):
				revision_bridge.cancel_llm_request(pending_request_id, "new_day_plan_replaced_revision")
			_async_revision_requests.erase(pending_request_id)
	for raw_request_id in _async_dialogue_plan_judgement_requests.keys():
		var judgement_request_id := str(raw_request_id)
		var judgement_context: Dictionary = _async_dialogue_plan_judgement_requests.get(judgement_request_id, {})
		if str(judgement_context.get("npc_id", "")) == npc_id:
			var judgement_bridge := get_node_or_null(LLM_BRIDGE_PATH)
			if judgement_bridge != null and judgement_bridge.has_method("cancel_llm_request"):
				judgement_bridge.cancel_llm_request(judgement_request_id, "new_day_plan_replaced_judgement")
			_async_dialogue_plan_judgement_requests.erase(judgement_request_id)
	for raw_request_id in _async_action_failure_plan_judgement_requests.keys():
		var failure_judgement_request_id := str(raw_request_id)
		var failure_judgement_context: Dictionary = _async_action_failure_plan_judgement_requests.get(failure_judgement_request_id, {})
		if str(failure_judgement_context.get("npc_id", "")) == npc_id:
			var failure_judgement_bridge := get_node_or_null(LLM_BRIDGE_PATH)
			if failure_judgement_bridge != null and failure_judgement_bridge.has_method("cancel_llm_request"):
				failure_judgement_bridge.cancel_llm_request(failure_judgement_request_id, "new_day_plan_replaced_failure_judgement")
			_async_action_failure_plan_judgement_requests.erase(failure_judgement_request_id)
	_reevaluating_npcs.erase(npc_id)
	_queued_reevaluation_by_npc.erase(npc_id)
	_queued_followup_reevaluation_by_npc.erase(npc_id)
	_revision_execution_retry_counts.erase(npc_id)
	_dialogue_plan_judgement_generation_by_npc.erase(npc_id)
	_dialogue_resume_context_by_npc.erase(npc_id)
	_deferred_current_revision_execution_by_npc.erase(npc_id)
	_clear_revision_failure_cycle(npc_id)


func _is_revision_context_current(context: Dictionary) -> bool:
	var npc_id := str(context.get("npc_id", ""))
	if npc_id.is_empty():
		return false
	return (
		int(context.get("request_day", -1)) == _get_current_day()
		and int(context.get("request_hour", -1)) == _get_current_hour()
		and int(context.get("plan_version", -1)) == _get_plan_version(npc_id)
		and int(context.get("dialogue_epoch", _get_npc_dialogue_epoch(npc_id))) == _get_npc_dialogue_epoch(npc_id)
	)


func _get_npc_dialogue_epoch(npc_id: String) -> int:
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("get_npc_dialogue_epoch"):
		return 0
	return int(dialog_system.get_npc_dialogue_epoch(npc_id))


func _get_plan_version(npc_id: String) -> int:
	if not _plan_version_by_npc.has(npc_id):
		_plan_version_by_npc[npc_id] = 1 if get_npc_daily_plan(npc_id).size() == 24 else 0
	return int(_plan_version_by_npc.get(npc_id, 0))


func _bump_plan_version(npc_id: String) -> int:
	var next_version := int(_plan_version_by_npc.get(npc_id, 0)) + 1
	_plan_version_by_npc[npc_id] = next_version
	return next_version


func _request_revision_after_execution_failure(npc_id: String, expected_retry_count: int) -> void:
	if int(_revision_execution_retry_counts.get(npc_id, 0)) != expected_retry_count:
		return
	if _reevaluating_npcs.has(npc_id):
		return
	var npc_system := _get_npc_system()
	if npc_system == null or npc_system.get_npc(npc_id).is_empty():
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var last_result := str(state.get("last_action_result", "revision_execution_failed"))
	var failed_item := get_current_plan_item(npc_id)
	request_plan_reevaluation(
		npc_id,
		"revision_execution_failed_%s" % last_result,
		failed_item,
		"真实 LLM 修订后的即时行动仍无法执行：%s。需要再次调整当前时段。" % _get_action_name(str(failed_item.get("action_id", "")))
	)


func _record_async_plan_result(npc_id: String, item: Dictionary, request_result: Dictionary) -> void:
	var result: Dictionary
	if bool(request_result.get("ok", false)):
		result = _apply_daily_plan_response(
			npc_id,
			request_result.get("daily_plan", {}),
			bool(item.get("execute_current_on_success", false)),
			bool(item.get("require_real_provider", true))
		)
		result["request_result"] = request_result.duplicate(true)
	else:
		result = _daily_plan_failure(
			npc_id,
			"llm_request_failed",
			"后台每日计划真实 LLM 请求失败：%s" % str(request_result.get("message", "请求失败。")),
			request_result
		)
	if _should_retry_async_plan(item, result):
		var retry_item := item.duplicate(true)
		retry_item["attempt"] = int(item.get("attempt", 1)) + 1
		_async_plan_queue.append(retry_item)
		_async_plan_batch_snapshot["retry_count"] = int(_async_plan_batch_snapshot.get("retry_count", 0)) + 1
		var retry_results: Dictionary = _async_plan_batch_snapshot.get("last_retry_by_npc", {})
		retry_results[npc_id] = {
			"attempt": int(retry_item.get("attempt", 1)),
			"status": str(result.get("status", "llm_request_failed")),
			"message": str(result.get("summary", "真实 LLM 请求失败，准备重试。"))
		}
		_async_plan_batch_snapshot["last_retry_by_npc"] = retry_results
		return
	_record_plan_generation_result(npc_id, result)
	var results: Dictionary = _async_plan_batch_snapshot.get("results", {})
	results[npc_id] = result.duplicate(true)
	_async_plan_batch_snapshot["results"] = results
	_async_plan_batch_snapshot["completed_count"] = int(_async_plan_batch_snapshot.get("completed_count", 0)) + 1
	if bool(result.get("ok", false)) and str(result.get("source", "")) == LLM_PLAN_SOURCE:
		_async_plan_batch_snapshot["succeeded_count"] = int(_async_plan_batch_snapshot.get("succeeded_count", 0)) + 1
	else:
		_async_plan_batch_snapshot["failed_count"] = int(_async_plan_batch_snapshot.get("failed_count", 0)) + 1


func _finish_async_plan_batch(status: String) -> void:
	if _async_plan_batch_snapshot.is_empty():
		return
	_async_plan_batch_snapshot["active_count"] = _async_plan_requests.size()
	_async_plan_batch_snapshot["queued_count"] = _async_plan_queue.size()
	var plans_ready := (
		int(_async_plan_batch_snapshot.get("succeeded_count", 0))
		== int(_async_plan_batch_snapshot.get("requested_count", 0))
		and int(_async_plan_batch_snapshot.get("failed_count", 0)) == 0
	)
	_async_plan_batch_snapshot["plans_ready"] = plans_ready
	_async_plan_batch_snapshot["ok"] = plans_ready
	_async_plan_batch_snapshot["status"] = status if plans_ready else "failed"
	if str(_async_plan_batch_snapshot.get("reason", "")) == "day_started":
		_finalize_new_day_plan_batch(plans_ready)
	async_daily_plan_batch_completed.emit(_async_plan_batch_snapshot.duplicate(true))


func _on_day_started(_day: int) -> void:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return
	set_auto_execution_enabled(false)
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(true)
	var npc_ids: Array[String] = npc_system.get_npc_ids()
	for npc_id in npc_ids:
		begin_new_day_planning_for_npc(npc_id, "day_started")
	var request_result := request_daily_plans_async(
		npc_ids,
		"day_started",
		false,
		FORMAL_PLAN_MAX_CONCURRENT,
		true,
		FORMAL_PLAN_MAX_ATTEMPTS
	)
	if not bool(request_result.get("ok", false)):
		_async_plan_batch_snapshot = request_result.duplicate(true)
		_async_plan_batch_snapshot["reason"] = "day_started"
		_async_plan_batch_snapshot["plans_ready"] = false
		_async_plan_batch_snapshot["status"] = str(request_result.get("status", "failed"))
		async_daily_plan_batch_completed.emit(_async_plan_batch_snapshot.duplicate(true))


func _finalize_new_day_plan_batch(plans_ready: bool) -> void:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if not plans_ready:
		set_auto_execution_enabled(false)
		if time_system != null and time_system.has_method("set_paused"):
			time_system.set_paused(true)
		return
	set_auto_execution_enabled(true)
	execute_current_plan_for_all(true)
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)


func get_dialogue_carryover_snapshot() -> Dictionary:
	var action_system := _get_action_system()
	var pending_dialogues: Dictionary = {}
	if (
		action_system != null
		and action_system.has_method("get_daily_plan_dialogue_carryover_snapshot")
	):
		pending_dialogues = action_system.get_daily_plan_dialogue_carryover_snapshot(
			_get_current_day(),
			_get_current_hour()
		)
	var active_dialogue: Dictionary = {}
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null and dialog_system.has_method("get_dialogue_state"):
		var dialogue_state: Dictionary = dialog_system.get_dialogue_state()
		if _is_active_daily_plan_dialogue_carryover(dialogue_state):
			active_dialogue = dialogue_state.duplicate(true)
	var deferred_npc_ids: Array[String] = []
	for raw_npc_id in _deferred_current_revision_execution_by_npc.keys():
		var npc_id := str(raw_npc_id)
		var marker: Dictionary = _deferred_current_revision_execution_by_npc.get(npc_id, {})
		if bool(marker.get("carryover_dialogue", false)):
			deferred_npc_ids.append(npc_id)
	deferred_npc_ids.sort()
	return {
		"day": _get_current_day(),
		"hour": _get_current_hour(),
		"pending_dialogues": pending_dialogues.duplicate(true),
		"active_dialogue": active_dialogue,
		"deferred_npc_ids": deferred_npc_ids
	}


func _prepare_hourly_dialogue_carryovers(
	current_day: int,
	current_hour: int,
	previous_markers: Dictionary
) -> void:
	for raw_npc_id in previous_markers.keys():
		var npc_id := str(raw_npc_id)
		var marker: Dictionary = previous_markers.get(npc_id, {})
		if (
			bool(marker.get("wait_for_dialogue_resolution", false))
			and _has_pending_dialogue_plan_chain(npc_id)
		):
			_defer_current_plan_until_dialogue_resolved(npc_id, {
				"dialogue_id": str(marker.get("dialogue_id", "")),
				"dialogue_epoch": int(marker.get("dialogue_epoch", _get_npc_dialogue_epoch(npc_id))),
				"carryover_dialogue": true
			})
	var action_system := _get_action_system()
	if (
		action_system != null
		and action_system.has_method("get_daily_plan_dialogue_carryover_snapshot")
	):
		var pending_dialogues: Dictionary = (
			action_system.get_daily_plan_dialogue_carryover_snapshot(current_day, current_hour)
		)
		for raw_npc_id in pending_dialogues.keys():
			_defer_current_plan_until_dialogue_resolved(str(raw_npc_id), {
				"carryover_dialogue": true
			})
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("get_dialogue_state"):
		return
	var dialogue_state: Dictionary = dialog_system.get_dialogue_state()
	if not _is_active_daily_plan_dialogue_carryover(dialogue_state):
		return
	var carried_npc_ids: Array[String] = []
	var speaker_npc_id := str(dialogue_state.get("speaker_npc_id", ""))
	if str(dialogue_state.get("session_status", "")) == "invitation_pending":
		if not speaker_npc_id.is_empty():
			carried_npc_ids.append(speaker_npc_id)
	else:
		for raw_npc_id in dialogue_state.get("participant_npc_ids", []):
			var npc_id := str(raw_npc_id)
			if not npc_id.is_empty() and not carried_npc_ids.has(npc_id):
				carried_npc_ids.append(npc_id)
	var dialogue_epochs: Dictionary = (
		(dialogue_state.get("dialogue_epoch_by_npc", {}) as Dictionary)
		if dialogue_state.get("dialogue_epoch_by_npc", {}) is Dictionary
		else {}
	)
	for npc_id in carried_npc_ids:
		_defer_current_plan_until_dialogue_resolved(npc_id, {
			"dialogue_id": str(dialogue_state.get("dialogue_id", "")),
			"dialogue_epoch": int(dialogue_epochs.get(npc_id, _get_npc_dialogue_epoch(npc_id))),
			"carryover_dialogue": true
		})


func _is_active_daily_plan_dialogue_carryover(dialogue_state: Dictionary) -> bool:
	return (
		not dialogue_state.is_empty()
		and str(dialogue_state.get("dialogue_kind", "")) == "npc_npc"
		and bool(dialogue_state.get("autonomous", false))
		and str(dialogue_state.get("plan_action_source", "")) == "daily_plan"
		and int(dialogue_state.get("assigned_plan_day", -1)) == _get_current_day()
		and int(dialogue_state.get("assigned_plan_hour", -1)) < _get_current_hour()
	)


func _should_preserve_active_autonomous_dialogue(dialogue_state: Dictionary) -> bool:
	var assigned_hour := int(dialogue_state.get("assigned_plan_hour", -1))
	return (
		str(dialogue_state.get("plan_action_source", "")) == "daily_plan"
		and int(dialogue_state.get("assigned_plan_day", -1)) == _get_current_day()
		and assigned_hour >= 0
		and assigned_hour <= _get_current_hour()
	)


func _on_hour_started(_day: int, _hour: int) -> void:
	var previous_deferred_markers := _deferred_current_revision_execution_by_npc.duplicate(true)
	_deferred_current_revision_execution_by_npc.clear()
	_prepare_hourly_dialogue_carryovers(_day, _hour, previous_deferred_markers)
	_one_shot_execution_keys_by_npc.clear()
	# Duplicate suppression is scoped to one plan stage. The same structured
	# failure in a later hour is a new action failure and must run judgement again.
	_last_failure_result_by_npc.clear()
	var action_system := _get_action_system()
	if action_system != null and action_system.has_method("expire_invalid_daily_plan_dialogues"):
		action_system.expire_invalid_daily_plan_dialogues(_day, _hour)
	if not auto_execution_enabled:
		return
	execute_current_plan_for_all(true, true)


func _defer_hour_plan_until_mass_end(
	npc_id: String,
	protected_action_id: String
) -> void:
	_deferred_hour_plan_until_mass_end_by_npc[npc_id] = {
		"day": _get_current_day(),
		"hour": _get_current_hour(),
		"plan_version": _get_plan_version(npc_id),
		"protected_action_id": protected_action_id,
		"ready": false,
	}


func _schedule_mass_end_plan_dispatch() -> void:
	if _mass_end_dispatch_scheduled:
		return
	_mass_end_dispatch_scheduled = true
	call_deferred("_dispatch_plans_after_mass_end")


func _mark_deferred_hour_plan_ready_after_mass(
	npc_id: String,
	action_system: Node
) -> bool:
	if not _deferred_hour_plan_until_mass_end_by_npc.has(npc_id):
		return false
	if (
		action_system != null
		and action_system.has_method("is_npc_committed_to_active_mass")
		and bool(action_system.is_npc_committed_to_active_mass(npc_id))
	):
		return false
	var marker: Dictionary = _deferred_hour_plan_until_mass_end_by_npc.get(
		npc_id,
		{}
	)
	marker["day"] = _get_current_day()
	marker["hour"] = _get_current_hour()
	marker["plan_version"] = _get_plan_version(npc_id)
	marker["ready"] = true
	_deferred_hour_plan_until_mass_end_by_npc[npc_id] = marker
	_schedule_mass_end_plan_dispatch()
	return true


func _dispatch_plans_after_mass_end() -> void:
	_mass_end_dispatch_scheduled = false
	if not auto_execution_enabled:
		return
	var npc_system := _get_npc_system()
	var action_system := _get_action_system()
	if npc_system == null or action_system == null:
		return
	var provider_npc_ids: Array[String] = []
	var instructor_npc_ids: Array[String] = []
	var other_npc_ids: Array[String] = []
	var dependent_npc_ids: Array[String] = []
	var student_npc_ids: Array[String] = []
	var dialogue_npc_ids: Array[String] = []
	for raw_npc_id in _deferred_hour_plan_until_mass_end_by_npc.keys():
		var npc_id := str(raw_npc_id)
		var marker: Dictionary = _deferred_hour_plan_until_mass_end_by_npc.get(
			npc_id,
			{}
		)
		var still_committed_to_mass := (
			action_system.has_method("is_npc_committed_to_active_mass")
			and bool(action_system.is_npc_committed_to_active_mass(npc_id))
		)
		if still_committed_to_mass:
			continue
		# A debug pause can disable auto execution while Mass finishes, so no
		# state callback marks this entry ready. Revalidate runtime truth when
		# dispatch resumes instead of leaving the current-hour plan stranded.
		if not bool(marker.get("ready", false)):
			marker["ready"] = true
			_deferred_hour_plan_until_mass_end_by_npc[npc_id] = marker
		if (
			not npc_system.can_npc_act(npc_id)
			or not _is_npc_in_work_behavior_mode(npc_id, npc_system)
		):
			continue
		var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
		if (
			dialog_system != null
			and dialog_system.has_method("is_npc_in_dialogue")
			and dialog_system.is_npc_in_dialogue(npc_id)
		):
			continue
		match str(get_current_plan_item(npc_id).get("action_id", "")):
			"talk_to_npc":
				dialogue_npc_ids.append(npc_id)
			"work_clinic_doctor", "lead_mass":
				provider_npc_ids.append(npc_id)
			"work_training_instructor":
				instructor_npc_ids.append(npc_id)
			"receive_clinic_treatment":
				dependent_npc_ids.append(npc_id)
			"receive_weapon_training":
				student_npc_ids.append(npc_id)
			_:
				other_npc_ids.append(npc_id)
	var ordered_npc_ids: Array[String] = []
	ordered_npc_ids.append_array(provider_npc_ids)
	ordered_npc_ids.append_array(instructor_npc_ids)
	ordered_npc_ids.append_array(other_npc_ids)
	ordered_npc_ids.append_array(dependent_npc_ids)
	ordered_npc_ids.append_array(student_npc_ids)
	ordered_npc_ids.append_array(dialogue_npc_ids)
	for npc_id in ordered_npc_ids:
		var marker: Dictionary = _deferred_hour_plan_until_mass_end_by_npc.get(
			npc_id,
			{}
		)
		_deferred_hour_plan_until_mass_end_by_npc.erase(npc_id)
		_plan_execution_signature_by_npc.erase(npc_id)
		_plan_owned_action_by_npc.erase(npc_id)
		var execute_result := execute_current_plan_for_npc(npc_id, true)
		if str(execute_result.get("status", "")) in [
			"npc_in_dialogue",
			"priority_dialogue_active",
			"dialogue_plan_judgement_pending",
			"carried_dialogue_active",
			"active_action_interrupt_failed",
		]:
			marker["day"] = _get_current_day()
			marker["hour"] = _get_current_hour()
			marker["plan_version"] = _get_plan_version(npc_id)
			marker["ready"] = true
			_deferred_hour_plan_until_mass_end_by_npc[npc_id] = marker


func _on_npc_state_changed(npc_id: String) -> void:
	if not auto_execution_enabled:
		return
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null and dialog_system.has_method("is_npc_in_dialogue") and dialog_system.is_npc_in_dialogue(npc_id):
		return
	var action_system := _get_action_system()
	if _mark_deferred_hour_plan_ready_after_mass(npc_id, action_system):
		return
	var npc_system := _get_npc_system()
	if npc_system == null:
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var last_result := str(state.get("last_action_result", ""))
	if _is_failure_result(last_result):
		if str(_last_failure_result_by_npc.get(npc_id, "")) == last_result:
			return
		var deferred_marker: Dictionary = _deferred_current_revision_execution_by_npc.get(npc_id, {})
		if (
			bool(deferred_marker.get("carryover_dialogue", false))
			and bool(deferred_marker.get("wait_for_dialogue_resolution", false))
		):
			# A pending approach can fail before DialogSystem owns a session. Convert
			# its carryover barrier into a ready marker, but let the authoritative
			# failure judgement register first so the old current plan cannot race it.
			deferred_marker["day"] = _get_current_day()
			deferred_marker["hour"] = _get_current_hour()
			deferred_marker["plan_version"] = _get_plan_version(npc_id)
			deferred_marker["scheduled"] = false
			deferred_marker["wait_for_dialogue_resolution"] = false
			_deferred_current_revision_execution_by_npc[npc_id] = deferred_marker
		_record_revision_landing_failure(npc_id)
		_last_failure_result_by_npc[npc_id] = last_result
		var failure_context: Dictionary = (
			(state.get("last_action_failure_context", {}) as Dictionary).duplicate(true)
			if state.get("last_action_failure_context", {}) is Dictionary
			else {}
		)
		var failed_plan_item := get_current_plan_item(npc_id)
		if failure_context.get("failed_plan_item", {}) is Dictionary:
			var contextual_failed_item: Dictionary = failure_context.get("failed_plan_item", {})
			if not contextual_failed_item.is_empty():
				failed_plan_item = contextual_failed_item.duplicate(true)
		request_plan_reevaluation(
			npc_id,
			last_result,
			failed_plan_item,
			_describe_action_failure(npc_id, last_result),
			failure_context
		)
		return
	if _schedule_deferred_current_revision_execution(npc_id, npc_system):
		return
	if str(state.get("current_action", "")) != "idle":
		_last_failure_result_by_npc.erase(npc_id)
		# A newly started cycle makes the same textual completion result valid
		# again when that cycle finishes.
		_last_completed_result_by_npc.erase(npc_id)
		return
	if _reevaluating_npcs.has(npc_id):
		return
	_last_failure_result_by_npc.erase(npc_id)
	if not _plan_owned_action_by_npc.has(npc_id):
		return
	var completed_action_id := str(_plan_owned_action_by_npc.get(npc_id, ""))
	if not _is_successful_plan_action_completion(completed_action_id, last_result):
		return
	_clear_revision_failure_cycle(npc_id)
	if str(_last_completed_result_by_npc.get(npc_id, "")) == last_result:
		return
	_last_completed_result_by_npc[npc_id] = last_result
	_plan_owned_action_by_npc.erase(npc_id)
	var item := get_current_plan_item(npc_id)
	if str(item.get("action_id", "")) != completed_action_id:
		return
	if (
		_get_action_completion_policy(completed_action_id)
		== COMPLETION_POLICY_REPEAT_WHILE_PLANNED
	):
		var continuation_generation := int(
			_repeat_continuation_generation_by_npc.get(npc_id, 0)
		) + 1
		_repeat_continuation_generation_by_npc[npc_id] = continuation_generation
		call_deferred("_continue_repeatable_plan_action_after_completion", npc_id, {
			"generation": continuation_generation,
			"completion_day": _get_current_day(),
			"completion_hour": _get_current_hour(),
			"action_id": completed_action_id,
			"plan_item_identity": _make_plan_item_identity(item),
		})
		return
	if not _should_reevaluate_current_hour_on_completion(completed_action_id):
		return
	var reevaluation_generation := int(
		_completion_reevaluation_generation_by_npc.get(npc_id, 0)
	) + 1
	_completion_reevaluation_generation_by_npc[npc_id] = reevaluation_generation
	call_deferred("_reevaluate_current_hour_after_plan_action_completion", npc_id, {
		"generation": reevaluation_generation,
		"completion_day": _get_current_day(),
		"completion_hour": _get_current_hour(),
		"action_id": completed_action_id,
		"action_name": _get_action_name(completed_action_id),
		"completion_result": last_result,
		"completed_plan_item": item.duplicate(true),
		"plan_item_identity": _make_plan_item_identity(item),
	})


func _is_successful_plan_action_completion(action_id: String, last_result: String) -> bool:
	match action_id:
		"assist_heal":
			return last_result.begins_with("assist_heal_completed_")
		"receive_clinic_treatment":
			return last_result == "clinic_treatment_completed"
		_:
			return last_result.begins_with("completed_")


func _should_reevaluate_current_hour_on_completion(
	action_id: String,
	action_system: Node = null
) -> bool:
	var resolved_action_system := action_system if action_system != null else _get_action_system()
	if (
		resolved_action_system == null
		or not resolved_action_system.has_method("get_action")
	):
		return false
	var action: Dictionary = resolved_action_system.get_action(action_id)
	return bool(action.get("reevaluate_current_hour_on_completion", false))


func _get_contiguous_completion_revision_hours(
	npc_id: String,
	start_hour: int,
	completed_item: Dictionary
) -> Array[int]:
	var result: Array[int] = []
	if start_hour < 0 or start_hour > 23 or completed_item.is_empty():
		return result
	var plan := get_npc_daily_plan(npc_id)
	if plan.size() != 24:
		return result
	var completed_identity := _make_plan_item_identity(completed_item)
	if completed_identity.is_empty():
		return result
	for hour in range(start_hour, plan.size()):
		var raw_item: Variant = plan[hour]
		if (
			not raw_item is Dictionary
			or _make_plan_item_identity(raw_item as Dictionary) != completed_identity
		):
			break
		result.append(hour)
	return result


func _reevaluate_current_hour_after_plan_action_completion(
	npc_id: String,
	context: Dictionary
) -> void:
	if (
		int(_completion_reevaluation_generation_by_npc.get(npc_id, 0))
		!= int(context.get("generation", -1))
		or not auto_execution_enabled
	):
		return
	if (
		int(context.get("completion_day", -1)) != _get_current_day()
		or int(context.get("completion_hour", -1)) != _get_current_hour()
	):
		# The authoritative hour-start dispatch owns the new hour. In particular,
		# a large logical tick may complete an action before GameState publishes
		# the crossed hour, so never revise the stale previous-hour item here.
		return
	var npc_system := _get_npc_system()
	var action_system := _get_action_system()
	if (
		npc_system == null
		or action_system == null
		or not npc_system.can_npc_act(npc_id)
		or not _is_npc_in_work_behavior_mode(npc_id, npc_system)
	):
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var current_action := str(state.get("current_action", ""))
	if current_action != "idle" and not current_action.is_empty():
		return
	var completed_action_id := str(context.get("action_id", ""))
	var item := get_current_plan_item(npc_id)
	if (
		str(item.get("action_id", "")) != completed_action_id
		or _make_plan_item_identity(item) != str(context.get("plan_item_identity", ""))
		or not _should_reevaluate_current_hour_on_completion(
			completed_action_id,
			action_system
		)
	):
		return
	var completed_plan_item: Dictionary = (
		(context.get("completed_plan_item", {}) as Dictionary).duplicate(true)
		if context.get("completed_plan_item", {}) is Dictionary
		else item.duplicate(true)
	)
	var revision_hours := _get_contiguous_completion_revision_hours(
		npc_id,
		_get_current_hour(),
		completed_plan_item
	)
	if revision_hours.is_empty():
		return
	var completion_summary := "计划行动“%s”已完成，当前小时仍需安排后续活动。" % str(
		context.get("action_name", _get_action_name(completed_action_id))
	)
	if revision_hours.size() > 1:
		completion_summary = (
			"计划行动“%s”已完成，需重新安排当前起连续的%d个相同计划阶段。"
			% [
				str(context.get("action_name", _get_action_name(completed_action_id))),
				revision_hours.size(),
			]
		)
	request_plan_reevaluation(
		npc_id,
		"plan_action_completed",
		completed_plan_item,
		completion_summary,
		{
			"condition": "successful_plan_action_completion",
			"completed_action_id": completed_action_id,
			"completed_action_name": str(
				context.get("action_name", _get_action_name(completed_action_id))
			),
			"completion_result": str(context.get("completion_result", "")),
			"completed_plan_item": completed_plan_item,
			"requires_different_current_activity": true,
			"contiguous_revision_hours": revision_hours.duplicate(),
		},
		{
			"revision_hours": revision_hours,
			"skip_plan_revision_judgement": true,
		}
	)


func _continue_repeatable_plan_action_after_completion(
	npc_id: String,
	context: Dictionary
) -> void:
	if (
		int(_repeat_continuation_generation_by_npc.get(npc_id, 0))
		!= int(context.get("generation", -1))
		or not auto_execution_enabled
	):
		return
	if (
		int(context.get("completion_day", -1)) != _get_current_day()
		or int(context.get("completion_hour", -1)) != _get_current_hour()
	):
		# Once the clock has crossed an hour, _on_hour_started owns the next
		# dispatch (including a failed dispatch) so this completion callback
		# must not create a second attempt.
		return
	var npc_system := _get_npc_system()
	var action_system := _get_action_system()
	if (
		npc_system == null
		or action_system == null
		or not npc_system.can_npc_act(npc_id)
		or not _is_npc_in_work_behavior_mode(npc_id, npc_system)
	):
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var current_action := str(state.get("current_action", ""))
	if current_action != "idle" and not current_action.is_empty():
		# Hour-start dispatch may already have continued the same action or
		# switched to the next hour's different action.
		return
	var item := get_current_plan_item(npc_id)
	var completed_action_id := str(context.get("action_id", ""))
	if (
		str(item.get("action_id", "")) != completed_action_id
		or _make_plan_item_identity(item) != str(context.get("plan_item_identity", ""))
		or (
			_get_action_completion_policy(completed_action_id, action_system)
			!= COMPLETION_POLICY_REPEAT_WHILE_PLANNED
		)
	):
		return
	# A successful cycle consumed the ordinary phase signature. Only the
	# repeatable completion policy may clear it and dispatch the next cycle.
	_plan_execution_signature_by_npc.erase(npc_id)
	_plan_owned_action_by_npc.erase(npc_id)
	execute_current_plan_for_npc(npc_id, false)


func schedule_ready_deferred_current_plans() -> Dictionary:
	var npc_system := _get_npc_system()
	if npc_system == null:
		return {"ok": false, "status": "missing_system", "scheduled_npc_ids": []}
	var service_provider_npc_ids: Array[String] = []
	var training_instructor_npc_ids: Array[String] = []
	var other_npc_ids: Array[String] = []
	var service_dependent_npc_ids: Array[String] = []
	var training_student_npc_ids: Array[String] = []
	var dialogue_npc_ids: Array[String] = []
	for raw_npc_id in _deferred_current_revision_execution_by_npc.keys():
		var npc_id := str(raw_npc_id)
		var pending: Dictionary = _deferred_current_revision_execution_by_npc.get(npc_id, {})
		if (
			pending.is_empty()
			or bool(pending.get("wait_for_dialogue_resolution", false))
			or int(pending.get("day", -1)) != _get_current_day()
			or int(pending.get("hour", -1)) != _get_current_hour()
		):
			continue
		match str(get_current_plan_item(npc_id).get("action_id", "")):
			"talk_to_npc":
				dialogue_npc_ids.append(npc_id)
			"work_clinic_doctor", "lead_mass":
				service_provider_npc_ids.append(npc_id)
			"work_training_instructor":
				training_instructor_npc_ids.append(npc_id)
			"receive_clinic_treatment":
				service_dependent_npc_ids.append(npc_id)
			"receive_weapon_training":
				training_student_npc_ids.append(npc_id)
			_:
				other_npc_ids.append(npc_id)
	var ordered_npc_ids: Array[String] = []
	ordered_npc_ids.append_array(service_provider_npc_ids)
	ordered_npc_ids.append_array(training_instructor_npc_ids)
	ordered_npc_ids.append_array(other_npc_ids)
	ordered_npc_ids.append_array(service_dependent_npc_ids)
	ordered_npc_ids.append_array(training_student_npc_ids)
	ordered_npc_ids.append_array(dialogue_npc_ids)
	var scheduled_npc_ids: Array[String] = []
	for npc_id in ordered_npc_ids:
		if _schedule_deferred_current_revision_execution(npc_id, npc_system):
			scheduled_npc_ids.append(npc_id)
	return {
		"ok": true,
		"status": "current_plan_dispatch_scheduled",
		"scheduled_npc_ids": scheduled_npc_ids
	}


func _has_pending_dialogue_plan_chain(npc_id: String) -> bool:
	for raw_context in _async_dialogue_plan_judgement_requests.values():
		if not raw_context is Dictionary:
			continue
		var judgement_context: Dictionary = raw_context
		if str(judgement_context.get("npc_id", "")) != npc_id:
			continue
		# A previous dialogue's HTTP request may still be returning after a newer
		# dialogue generation has completed. It is guaranteed to be discarded by the
		# response handler and must not hold the newer ready marker hostage.
		if (
			_is_dialogue_judgement_context_current(judgement_context)
			or _should_rebase_dialogue_judgement(judgement_context)
		):
			return true
	for raw_context in _async_action_failure_plan_judgement_requests.values():
		if not raw_context is Dictionary:
			continue
		var failure_judgement_context: Dictionary = raw_context
		if (
			str(failure_judgement_context.get("npc_id", "")) == npc_id
			and _is_action_failure_judgement_context_current(failure_judgement_context)
		):
			return true
	for raw_context in _async_revision_requests.values():
		if not raw_context is Dictionary:
			continue
		var revision_context: Dictionary = raw_context
		# Any current revision for this NPC owns the plan version that the ready marker
		# would execute. This also covers a normal failure followup after the dialogue
		# context itself has already been consumed.
		if (
			str(revision_context.get("npc_id", "")) == npc_id
			and _is_revision_context_current(revision_context)
		):
			return true
	var followup: Variant = _queued_followup_reevaluation_by_npc.get(npc_id, {})
	if followup is Dictionary and not (followup as Dictionary).is_empty():
		return true
	for queued_source in [
		_queued_reevaluation_by_npc.get(npc_id, {})
	]:
		if not queued_source is Dictionary:
			continue
		var queued: Dictionary = queued_source
		var queued_options: Variant = queued.get("options", {})
		if not queued_options is Dictionary:
			continue
		var queued_dialogue_context: Variant = (queued_options as Dictionary).get(
			"dialogue_resume_context",
			{}
		)
		if queued_dialogue_context is Dictionary and not (queued_dialogue_context as Dictionary).is_empty():
			return true
	return false


func _restore_deferred_current_plan_marker_after_revision(
	npc_id: String,
	snapshot: Dictionary
) -> void:
	if snapshot.is_empty() or _deferred_current_revision_execution_by_npc.has(npc_id):
		return
	if (
		int(snapshot.get("day", -1)) != _get_current_day()
		or int(snapshot.get("hour", -1)) != _get_current_hour()
	):
		return
	# A selected-current-hour followup may already have started the authoritative
	# replacement action while applying its response. In that case the old dialogue
	# marker has reached its purpose and must not linger until the action completes.
	if (
		not bool(snapshot.get("wait_for_dialogue_resolution", false))
		and _adopt_running_current_plan_action(npc_id)
	):
		return
	var restored := snapshot.duplicate(true)
	restored["plan_version"] = _get_plan_version(npc_id)
	restored["scheduled"] = false
	_deferred_current_revision_execution_by_npc[npc_id] = restored


func _schedule_deferred_current_revision_execution(npc_id: String, npc_system: Node) -> bool:
	var pending: Dictionary = _deferred_current_revision_execution_by_npc.get(npc_id, {})
	if pending.is_empty():
		return false
	if bool(pending.get("wait_for_dialogue_resolution", false)):
		return false
	if _has_pending_dialogue_plan_chain(npc_id):
		return false
	var pending_dialogue_id := str(pending.get("dialogue_id", ""))
	if not pending_dialogue_id.is_empty():
		for raw_other_npc_id in _deferred_current_revision_execution_by_npc.keys():
			var other_npc_id := str(raw_other_npc_id)
			if other_npc_id == npc_id:
				continue
			var other: Dictionary = _deferred_current_revision_execution_by_npc.get(other_npc_id, {})
			if (
				str(other.get("dialogue_id", "")) == pending_dialogue_id
				and int(other.get("day", -1)) == int(pending.get("day", -1))
				and int(other.get("hour", -1)) == int(pending.get("hour", -1))
				and bool(other.get("wait_for_dialogue_resolution", false))
			):
				return false
	if (
		int(pending.get("day", -1)) != _get_current_day()
		or int(pending.get("hour", -1)) != _get_current_hour()
		or int(pending.get("plan_version", -1)) != _get_plan_version(npc_id)
	):
		_deferred_current_revision_execution_by_npc.erase(npc_id)
		return false
	if (
		not npc_system.can_npc_act(npc_id)
		or not _is_npc_in_work_behavior_mode(npc_id, npc_system)
	):
		return false
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if (
		dialog_system != null
		and dialog_system.has_method("is_npc_in_dialogue")
		and dialog_system.is_npc_in_dialogue(npc_id)
	):
		return false
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		str(state.get("current_action", "")) != "idle"
		and not bool(pending.get("mark_revision_applied", false))
	):
		return false
	if bool(pending.get("scheduled", false)):
		return true
	var current_item := get_current_plan_item(npc_id)
	if str(current_item.get("action_id", "")) == "talk_to_npc":
		var current_target: Dictionary = (
			current_item.get("target", {})
			if current_item.get("target", {}) is Dictionary
			else {}
		)
		var target_npc_id := str(current_target.get(
			"target_npc_id",
			current_target.get("target_id", current_item.get("target_id", ""))
		))
		if not target_npc_id.is_empty() and _is_current_plan_waiting_for_dialogue_resolution(target_npc_id):
			return false
		var active_dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
		if (
			active_dialog_system != null
			and active_dialog_system.has_method("get_dialogue_state")
			and not (active_dialog_system.get_dialogue_state() as Dictionary).is_empty()
		):
			return false
		pending["preserve_active_dialogue"] = true
	pending["scheduled"] = true
	_deferred_current_revision_execution_by_npc[npc_id] = pending
	call_deferred("_execute_deferred_current_revision", npc_id)
	return true


func _execute_deferred_current_revision(npc_id: String) -> void:
	var pending: Dictionary = _deferred_current_revision_execution_by_npc.get(npc_id, {})
	if pending.is_empty():
		return
	pending["scheduled"] = false
	_deferred_current_revision_execution_by_npc[npc_id] = pending
	var npc_system := _get_npc_system()
	if npc_system == null or not _schedule_deferred_current_revision_execution_ready(npc_id, npc_system, pending):
		return
	_deferred_current_revision_execution_by_npc.erase(npc_id)
	if bool(pending.get("mark_revision_applied", false)):
		_mark_revision_applied(npc_id)
	var execute_result := execute_current_plan_for_npc(
		npc_id,
		true,
		bool(pending.get("preserve_active_dialogue", false))
	)
	if str(execute_result.get("status", "")) in [
		"already_in_npc_dialogue",
		"npc_in_dialogue",
		"priority_dialogue_active",
		"dialogue_plan_judgement_pending",
		"carried_dialogue_active"
	]:
		var blocked_marker: Dictionary = _deferred_current_revision_execution_by_npc.get(
			npc_id,
			pending
		)
		blocked_marker["scheduled"] = false
		blocked_marker["plan_version"] = _get_plan_version(npc_id)
		_deferred_current_revision_execution_by_npc[npc_id] = blocked_marker
		return
	var landed := (
		bool(execute_result.get("ok", false))
		and not str(execute_result.get("status", "")) in [
			"already_executed_once_per_plan_hour",
			"already_executed_this_plan_phase"
		]
	)
	if landed:
		var saved_context: Dictionary = _dialogue_resume_context_by_npc.get(npc_id, {})
		if (
			str(saved_context.get("dialogue_id", "")) == str(pending.get("dialogue_id", ""))
			and int(saved_context.get("dialogue_epoch", -1)) == int(pending.get("dialogue_epoch", -1))
		):
			_dialogue_resume_context_by_npc.erase(npc_id)
	else:
		var retry_marker: Dictionary = _deferred_current_revision_execution_by_npc.get(
			npc_id,
			pending
		)
		retry_marker["day"] = _get_current_day()
		retry_marker["hour"] = _get_current_hour()
		retry_marker["plan_version"] = _get_plan_version(npc_id)
		retry_marker["scheduled"] = false
		_deferred_current_revision_execution_by_npc[npc_id] = retry_marker


func _schedule_deferred_current_revision_execution_ready(
	npc_id: String,
	npc_system: Node,
	pending: Dictionary
) -> bool:
	if (
		int(pending.get("day", -1)) != _get_current_day()
		or int(pending.get("hour", -1)) != _get_current_hour()
		or int(pending.get("plan_version", -1)) != _get_plan_version(npc_id)
		or not npc_system.can_npc_act(npc_id)
		or not _is_npc_in_work_behavior_mode(npc_id, npc_system)
		or (
			str(npc_system.get_npc_state(npc_id).get("current_action", "")) != "idle"
			and not bool(pending.get("mark_revision_applied", false))
		)
	):
		if (
			int(pending.get("day", -1)) != _get_current_day()
			or int(pending.get("hour", -1)) != _get_current_hour()
			or int(pending.get("plan_version", -1)) != _get_plan_version(npc_id)
		):
			_deferred_current_revision_execution_by_npc.erase(npc_id)
		return false
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	return not (
		dialog_system != null
		and dialog_system.has_method("is_npc_in_dialogue")
		and dialog_system.is_npc_in_dialogue(npc_id)
	)


func _on_plan_reevaluation_requested(npc_id: String, reason: String) -> void:
	request_plan_reevaluation(
		npc_id,
		reason,
		get_current_plan_item(npc_id),
		_describe_reevaluation_reason(reason, get_current_plan_item(npc_id)),
		{}
	)


func _normalize_plan(plan: Array, source: String = RULE_SOURCE) -> Array:
	var items_by_hour: Dictionary = {}
	for index in range(plan.size()):
		if not plan[index] is Dictionary:
			return []
		var raw_item: Dictionary = plan[index]
		if not raw_item.has("hour"):
			return []
		var item_hour := int(raw_item.get("hour", -1))
		if item_hour < 0 or item_hour >= 24 or items_by_hour.has(item_hour):
			return []
		items_by_hour[item_hour] = raw_item
	if items_by_hour.size() != 24:
		return []

	var normalized: Array = []
	for hour in range(24):
		if not items_by_hour.has(hour):
			return []
		var source_item: Dictionary = items_by_hour[hour]
		var action_id := str(source_item.get("action_id", ""))
		if not _is_supported_plan_action(action_id):
			return []
		var normalized_item := _make_plan_item(
			hour,
			action_id,
			str(source_item.get("reason", "")),
			str(source_item.get("source", source)),
			source_item.get("target", {}),
			int(source_item.get("priority", 50)),
			str(source_item.get("dialogue_goal", ""))
		)
		if _is_planned_dialogue_action(normalized_item):
			normalized_item["intent_created_day"] = maxi(
				1,
				int(source_item.get(
					"intent_created_day",
					_get_current_day()
				))
			)
			normalized_item["intent_created_time"] = str(
				source_item.get(
					"intent_created_time",
					_get_current_time_text()
				)
			)
			normalized_item["intent_source"] = str(
				source_item.get(
					"intent_source",
					source_item.get("source", source)
				)
			)
		normalized.append(normalized_item)
	return normalized


func _make_plan_item(
	hour: int,
	action_id: String,
	reason: String,
	source: String = RULE_SOURCE,
	target: Variant = {},
	priority: int = 50,
	dialogue_goal: String = ""
) -> Dictionary:
	return {
		"hour": clampi(hour, 0, 23),
		"action_id": action_id,
		"action_name": _get_action_name(action_id),
		"source": source,
		"target": target if target is Dictionary else {},
		"priority": clampi(priority, 0, 100),
		"reason": reason,
		"dialogue_goal": dialogue_goal
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


func _apply_revision_response(
	npc_id: String,
	revision: Dictionary,
	reason: String,
	current_plan: Array,
	options: Dictionary = {}
) -> Dictionary:
	var model_provider := str(revision.get("model_provider", "")).strip_edges().to_lower()
	var model_fallback_used := bool(revision.get("model_fallback_used", false))
	if model_provider.is_empty() or model_provider == "mock" or model_fallback_used:
		return _revision_failure(
			"mock_provider_forbidden",
			"正式计划重估只接受真实 LLM provider，当前 provider=%s。" % (model_provider if not model_provider.is_empty() else "missing"),
			revision
		)
	var revision_hours := _normalize_revision_hours(
		options.get("revision_hours", [_get_current_hour()]),
		_get_current_hour()
	)
	var scope_validation := _validate_revision_scope(revision, revision_hours)
	if not bool(scope_validation.get("ok", false)):
		return _revision_failure(
			"invalid_revision_scope",
			str(scope_validation.get("message", "真实 LLM 计划修订范围无效。")),
			revision
		)
	if (
		str(options.get("failure_type", "")) == "action_completed"
		and revision_hours.has(_get_current_hour())
	):
		var revised_current_item := _get_revision_item_for_hour(
			revision,
			_get_current_hour()
		)
		var completed_item: Dictionary = (
			(options.get("failed_plan_item", {}) as Dictionary)
			if options.get("failed_plan_item", {}) is Dictionary
			else {}
		)
		if _revision_item_repeats_completed_activity(
			revised_current_item,
			completed_item
		):
			return _revision_failure(
				"completed_action_repeated",
				"已完成行动的当前小时修订不能原样重复同一行动与目标。",
				revision
			)
	if (
		str(options.get("trigger_kind", "")) == "action_failure"
		and str(options.get("failure_type", "")) != "action_completed"
		and revision_hours.has(_get_current_hour())
	):
		var revised_failed_current_item := _get_revision_item_for_hour(
			revision,
			_get_current_hour()
		)
		var failed_current_item: Dictionary = (
			(options.get("failed_plan_item", {}) as Dictionary)
			if options.get("failed_plan_item", {}) is Dictionary
			else {}
		)
		if _revision_item_repeats_completed_activity(
			revised_failed_current_item,
			failed_current_item
		):
			return _revision_failure(
				"failed_action_repeated",
				"刚刚失败的当前小时行动不能原样作为即时修订再次执行。",
				revision
			)
	var previous_current_item: Dictionary = (
		current_plan[_get_current_hour()]
		if _get_current_hour() >= 0
		and _get_current_hour() < current_plan.size()
		and current_plan[_get_current_hour()] is Dictionary
		else {}
	)
	var previous_current_signature := (
		_make_plan_execution_signature(npc_id, previous_current_item)
		if not previous_current_item.is_empty()
		else ""
	)
	var current_phase_was_dispatched := (
		not previous_current_signature.is_empty()
		and str(_plan_execution_signature_by_npc.get(npc_id, "")) == previous_current_signature
	)
	var merged_plan := _merge_revision_items(npc_id, current_plan, revision)
	if merged_plan.is_empty():
		return _revision_failure("invalid_revision_response", "真实 LLM 计划修订响应没有可用行动。", revision)
	if not set_npc_daily_plan(npc_id, merged_plan, false, LLM_REVISION_SOURCE):
		return _revision_failure("invalid_revision_response", "真实 LLM 计划修订响应未通过本地校验。", revision)
	var summary := str(revision.get("summary", "真实 LLM 修订了当前计划。"))
	_log_plan_revised(npc_id, merged_plan, reason, LLM_REVISION_SOURCE, summary)
	_last_failure_result_by_npc.erase(npc_id)
	var current_hour_revised := revision_hours.has(_get_current_hour())
	var execute_result: Dictionary = {}
	var execution_ok := true
	var execution_deferred_by_behavior_mode := false
	var dialogue_resume_context: Dictionary = (
		(options.get("dialogue_resume_context", {}) as Dictionary).duplicate(true)
		if options.get("dialogue_resume_context", {}) is Dictionary
		else {}
	)
	var execution_deferred_by_dialogue_resolution := bool(
		dialogue_resume_context.get("execute_current_plan_when_resolved", false)
	)
	if current_hour_revised:
		_dialogue_resume_context_by_npc.erase(npc_id)
		if execution_deferred_by_dialogue_resolution:
			_defer_current_plan_until_dialogue_resolved(npc_id, dialogue_resume_context)
			execute_result = {
				"ok": true,
				"npc_id": npc_id,
				"action_id": str(get_current_plan_item(npc_id).get("action_id", "")),
				"status": "dialogue_group_resolution_pending"
			}
		else:
			var npc_system := _get_npc_system()
			if (
				npc_system != null
				and npc_system.can_npc_act(npc_id)
				and _is_npc_in_work_behavior_mode(npc_id, npc_system)
			):
				_deferred_current_revision_execution_by_npc[npc_id] = {
					"day": _get_current_day(),
					"hour": _get_current_hour(),
					"plan_version": _get_plan_version(npc_id),
					"scheduled": true,
					"mark_revision_applied": true
				}
				_mark_revision_applied(npc_id)
				execute_result = execute_current_plan_for_npc(npc_id, true)
				execution_ok = (
					bool(execute_result.get("ok", false))
					and not str(execute_result.get("status", "")) in [
						"already_executed_once_per_plan_hour",
						"already_executed_this_plan_phase"
					]
				)
				var pending_after_attempt: Dictionary = (
					_deferred_current_revision_execution_by_npc.get(npc_id, {})
				)
				if execution_ok and not bool(
					pending_after_attempt.get("wait_for_dialogue_resolution", false)
				):
					_deferred_current_revision_execution_by_npc.erase(npc_id)
				elif not execution_ok:
					pending_after_attempt["day"] = _get_current_day()
					pending_after_attempt["hour"] = _get_current_hour()
					pending_after_attempt["plan_version"] = _get_plan_version(npc_id)
					pending_after_attempt["scheduled"] = false
					pending_after_attempt["mark_revision_applied"] = true
					_deferred_current_revision_execution_by_npc[npc_id] = pending_after_attempt
			else:
				execution_deferred_by_behavior_mode = true
				_deferred_current_revision_execution_by_npc[npc_id] = {
					"day": _get_current_day(),
					"hour": _get_current_hour(),
					"plan_version": _get_plan_version(npc_id),
					"scheduled": false,
					"mark_revision_applied": true
				}
	else:
		var adopted_running_action := _adopt_running_current_plan_action(npc_id)
		if not adopted_running_action and current_phase_was_dispatched:
			# selected_hours did not include the current hour, so a completed phase
			# remains completed even though set_npc_daily_plan bumped plan_version and
			# cleared its old signature. This prevents replaying a finished dialogue.
			var current_item := get_current_plan_item(npc_id)
			if not current_item.is_empty():
				_plan_execution_signature_by_npc[npc_id] = _make_plan_execution_signature(
					npc_id,
					current_item
				)
	return {
		"ok": execution_ok,
		"status": (
			"llm_revision_applied_dialogue_deferred"
			if execution_deferred_by_dialogue_resolution
			else (
				"llm_revision_applied_deferred"
				if execution_deferred_by_behavior_mode
				else ("llm_revision_applied" if execution_ok else "revision_execution_failed")
			)
		),
		"plan_applied": true,
		"source": LLM_REVISION_SOURCE,
		"fallback_used": false,
		"summary": summary if execution_ok else "%s 但修订后的当前行动未能启动，将继续请求真实 LLM 调整。" % summary,
		"revised_plan": merged_plan.duplicate(true),
		"execute_result": execute_result,
		"model_provider": model_provider,
		"model_name": str(revision.get("model_name", "")),
		"revision_scope": REVISION_SCOPE_SELECTED_HOURS,
		"revision_hours": revision_hours.duplicate(),
		"current_hour_revised": current_hour_revised,
		"execution_deferred_by_behavior_mode": execution_deferred_by_behavior_mode,
		"execution_deferred_by_dialogue_resolution": execution_deferred_by_dialogue_resolution
	}


func _validate_revision_scope(revision: Dictionary, revision_hours: Array[int]) -> Dictionary:
	var revision_items: Array = revision.get("revised_plan", []) if revision.get("revised_plan", []) is Array else []
	var immediate: Dictionary = revision.get("immediate_action", {}) if revision.get("immediate_action", {}) is Dictionary else {}
	if revision_hours.is_empty():
		return {"ok": false, "message": "计划修订缺少判定或触发源指定的小时集合。"}
	if revision_items.size() != revision_hours.size():
		return {
			"ok": false,
			"message": "计划修订必须且只能返回指定的 %d 个小时项。" % revision_hours.size()
		}
	var seen_hours := {}
	for raw_item in revision_items:
		if not raw_item is Dictionary:
			return {"ok": false, "message": "计划修订包含非对象小时项。"}
		var item_hour := int((raw_item as Dictionary).get("hour", -1))
		if not revision_hours.has(item_hour) or seen_hours.has(item_hour):
			return {
				"ok": false,
				"message": "计划修订不得缺失、重复或夹带指定集合以外的小时。"
			}
		seen_hours[item_hour] = true
	var revises_current_hour := revision_hours.has(_get_current_hour())
	if revises_current_hour:
		if immediate.is_empty() or int(immediate.get("hour", -1)) != _get_current_hour():
			return {"ok": false, "message": "修改当前小时的计划必须提供对应 immediate_action。"}
		var current_item: Dictionary = {}
		for raw_item in revision_items:
			if int((raw_item as Dictionary).get("hour", -1)) == _get_current_hour():
				current_item = raw_item
				break
		if current_item.is_empty() or not _revision_actions_match(current_item, immediate):
			return {"ok": false, "message": "immediate_action 必须与 revised_plan 的当前小时项一致。"}
	elif not immediate.is_empty():
		return {"ok": false, "message": "未修改当前小时的计划时，immediate_action 必须为空。"}
	return {"ok": true}


func _revision_actions_match(first: Dictionary, second: Dictionary) -> bool:
	return (
		int(first.get("hour", -1)) == int(second.get("hour", -1))
		and str(first.get("action_id", "")) == str(second.get("action_id", ""))
		and str(first.get("action_kind", "")) == str(second.get("action_kind", ""))
		and _nullable_string(first.get("target_id", null)) == _nullable_string(second.get("target_id", null))
		and _nullable_string(first.get("location_id", null)) == _nullable_string(second.get("location_id", null))
	)


func _get_revision_item_for_hour(revision: Dictionary, hour: int) -> Dictionary:
	var revision_items: Array = (
		revision.get("revised_plan", [])
		if revision.get("revised_plan", []) is Array
		else []
	)
	for raw_item in revision_items:
		if raw_item is Dictionary and int((raw_item as Dictionary).get("hour", -1)) == hour:
			return (raw_item as Dictionary).duplicate(true)
	return {}


func _revision_item_repeats_completed_activity(
	revised_item: Dictionary,
	completed_item: Dictionary
) -> bool:
	if (
		revised_item.is_empty()
		or completed_item.is_empty()
		or str(revised_item.get("action_id", ""))
		!= str(completed_item.get("action_id", ""))
	):
		return false
	return (
		_get_plan_item_target_id(revised_item)
		== _get_plan_item_target_id(completed_item)
		and str(revised_item.get("dialogue_goal", "")).strip_edges()
		== str(completed_item.get("dialogue_goal", "")).strip_edges()
	)


func _get_plan_item_target_id(item: Dictionary) -> String:
	var target_id := _nullable_string(item.get("target_id", null))
	if not target_id.is_empty():
		return target_id
	for top_level_target_key in ["target_npc_id", "location_id", "building_id"]:
		target_id = _nullable_string(item.get(top_level_target_key, null))
		if not target_id.is_empty():
			return target_id
	var target: Dictionary = (
		item.get("target", {})
		if item.get("target", {}) is Dictionary
		else {}
	)
	target_id = _nullable_string(target.get("target_id", null))
	if not target_id.is_empty():
		return target_id
	for target_key in ["target_npc_id", "location_id", "building_id"]:
		target_id = _nullable_string(target.get(target_key, null))
		if not target_id.is_empty():
			return target_id
	return ""


func _revision_failure(status: String, summary: String, response: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"status": status,
		"source": "",
		"fallback_used": false,
		"summary": summary,
		"revised_plan": [],
		"execute_result": {},
		"response": response.duplicate(true)
	}


func _get_revision_cycle_count(npc_id: String) -> int:
	var cycle: Dictionary = _revision_cycle_by_npc.get(npc_id, {})
	if (
		int(cycle.get("day", -1)) != _get_current_day()
		or int(cycle.get("hour", -1)) != _get_current_hour()
	):
		_revision_cycle_by_npc.erase(npc_id)
		return 0
	return int(cycle.get("count", 0))


func _record_revision_landing_failure(npc_id: String) -> int:
	var marker: Dictionary = _revision_applied_marker_by_npc.get(npc_id, {})
	if marker.is_empty():
		return _get_revision_cycle_count(npc_id)
	if (
		int(marker.get("day", -1)) != _get_current_day()
		or int(marker.get("hour", -1)) != _get_current_hour()
	):
		_revision_applied_marker_by_npc.erase(npc_id)
		return _get_revision_cycle_count(npc_id)
	_revision_applied_marker_by_npc.erase(npc_id)
	var next_count := _get_revision_cycle_count(npc_id) + 1
	_revision_cycle_by_npc[npc_id] = {
		"day": _get_current_day(),
		"hour": _get_current_hour(),
		"count": next_count,
	}
	return next_count


func _mark_revision_applied(npc_id: String) -> void:
	_revision_applied_marker_by_npc[npc_id] = {
		"day": _get_current_day(),
		"hour": _get_current_hour(),
		"plan_version": _get_plan_version(npc_id),
	}


func _clear_revision_failure_cycle(npc_id: String) -> void:
	_revision_cycle_by_npc.erase(npc_id)
	_revision_applied_marker_by_npc.erase(npc_id)


func _apply_daily_plan_response(
	npc_id: String,
	response: Dictionary,
	execute_current: bool,
	require_real_provider: bool = true
) -> Dictionary:
	var model_provider := str(response.get("model_provider", "")).strip_edges().to_lower()
	var model_fallback_used := bool(response.get("model_fallback_used", false))
	if require_real_provider and (model_provider.is_empty() or model_provider == "mock" or model_fallback_used):
		return _daily_plan_failure(
			npc_id,
			"mock_provider_forbidden",
			"正式每日计划只接受真实 LLM provider，当前 provider=%s。" % (model_provider if not model_provider.is_empty() else "missing"),
			{"body": response}
		)
	var plan_source := MOCK_PLAN_SOURCE if model_provider == "mock" else LLM_PLAN_SOURCE
	var raw_schema_plan: Variant = response.get("plan", [])
	var plan: Array = []
	if not raw_schema_plan is Array:
		return _daily_plan_failure(npc_id, "invalid_plan_response", "每日计划响应缺少 plan 数组。", {"body": response})
	var schema_plan: Array = raw_schema_plan
	for raw_item in schema_plan:
		if not raw_item is Dictionary:
			return _daily_plan_failure(npc_id, "invalid_plan_response", "每日计划响应包含非法计划项。", {"body": response})
		var item := _plan_item_from_schema(raw_item, plan_source, npc_id)
		if item.is_empty():
			return _daily_plan_failure(npc_id, "invalid_plan_response", "每日计划响应包含不可执行行动。", {"body": response})
		plan.append(item)
	plan = _normalize_plan(plan, plan_source)
	if plan.size() != 24:
		return _daily_plan_failure(npc_id, "invalid_plan_response", "每日计划响应不是 24 个小时项。", {"body": response})
	if not set_npc_daily_plan(npc_id, plan, true, plan_source):
		return _daily_plan_failure(npc_id, "invalid_plan_response", "每日计划响应未通过本地校验。", {"body": response})
	var execute_result := {}
	if execute_current:
		execute_result = execute_current_plan_for_npc(npc_id, true)
	return _plan_generation_result(
		true,
		npc_id,
		"mock_plan_applied" if plan_source == MOCK_PLAN_SOURCE else "llm_plan_applied",
		str(response.get("summary", "LLM 生成了每日计划。")),
		false,
		plan,
		response,
		execute_result,
		plan_source
	)


func _daily_plan_failure(
	npc_id: String,
	status: String,
	summary: String,
	request_result: Dictionary
) -> Dictionary:
	return _plan_generation_result(
		false,
		npc_id,
		status,
		summary,
		false,
		[],
		request_result,
		{},
		""
	)


func _should_retry_async_plan(item: Dictionary, result: Dictionary) -> bool:
	if bool(result.get("ok", false)):
		return false
	if str(result.get("status", "")) in ["mock_provider_forbidden", "request_cancelled"]:
		return false
	return int(item.get("attempt", 1)) < int(item.get("max_attempts", FORMAL_PLAN_MAX_ATTEMPTS))


func _require_real_llm_provider(llm_bridge: Node) -> Dictionary:
	if llm_bridge == null or not llm_bridge.has_method("check_health"):
		return {
			"ok": false,
			"status": "llm_bridge_unavailable",
			"message": "正式 LLM 调用无法检查真实 provider。"
		}
	var health: Dictionary = (
		llm_bridge.get_cached_health(5000)
		if llm_bridge.has_method("get_cached_health")
		else llm_bridge.check_health()
	)
	if not bool(health.get("ok", false)):
		return {
			"ok": false,
			"status": "backend_health_failed",
			"message": str(health.get("message", "无法连接 LLM 后端。")),
			"health": health.duplicate(true)
		}
	var adapter: Dictionary = health.get("body", {}).get("model_adapter", {})
	var provider := str(adapter.get("provider", "")).strip_edges().to_lower()
	if provider.is_empty() or provider == "mock" or not bool(adapter.get("configured", false)):
		return {
			"ok": false,
			"status": "real_provider_required",
			"message": "正式 LLM 调用要求已配置的真实 provider，当前 provider=%s。" % (provider if not provider.is_empty() else "missing"),
			"provider": provider
		}
	if bool(adapter.get("fallback_to_mock", false)):
		return {
			"ok": false,
			"status": "mock_fallback_enabled",
			"message": "正式 LLM 调用禁止启用 LLM_FALLBACK_TO_MOCK。",
			"provider": provider
		}
	return {
		"ok": true,
		"status": "real_provider_ready",
		"provider": provider,
		"model": str(adapter.get("model", ""))
	}


func _is_request_cancelled(result: Dictionary) -> bool:
	return bool(result.get("cancelled", false)) or str(result.get("error_code", "")) == "request_cancelled"


func _merge_revision_items(npc_id: String, current_plan: Array, revision: Dictionary) -> Array:
	var next_plan := current_plan.duplicate(true)
	if next_plan.size() != 24:
		next_plan = _normalize_plan(next_plan)
	if next_plan.size() != 24:
		return []

	var revision_items: Array = []
	if revision.has("revised_plan") and revision["revised_plan"] is Array:
		revision_items = (revision["revised_plan"] as Array).duplicate(true)
	var immediate: Dictionary = (
		revision.get("immediate_action", {})
		if revision.get("immediate_action", {}) is Dictionary
		else {}
	)
	if not immediate.is_empty():
		revision_items.append(immediate)

	for raw_item in revision_items:
		if not raw_item is Dictionary:
			continue
		var item := _plan_item_from_schema(raw_item, LLM_REVISION_SOURCE, npc_id)
		if item.is_empty():
			return []
		var hour := int(item.get("hour", -1))
		if hour < 0 or hour >= 24:
			return []
		next_plan[hour] = item
	var normalized_plan := _normalize_plan(next_plan)
	if normalized_plan.size() != 24:
		return []
	return normalized_plan


func _plan_item_from_schema(item: Dictionary, source: String, npc_id: String = "") -> Dictionary:
	var action_id := str(item.get("action_id", ""))
	if not _is_supported_plan_action(action_id):
		return {}
	var target := {}
	var target_id := _nullable_string(item.get("target_id", null))
	var location_id := _nullable_string(item.get("location_id", null))
	if not target_id.is_empty():
		target["target_id"] = target_id
		if action_id in ["assist_repair", "assist_upgrade"]:
			target["building_id"] = target_id
		elif action_id in ["assist_heal", "talk_to_npc"]:
			target["target_npc_id"] = target_id
		elif action_id == "visit_location":
			target["location_id"] = target_id
	if not location_id.is_empty() and action_id != "talk_to_npc":
		target["location_id"] = location_id
	if not _is_valid_plan_target(npc_id, action_id, target):
		return {}
	return _make_plan_item(
		clampi(int(item.get("hour", _get_current_hour())), 0, 23),
		action_id,
		str(item.get("reason", "")),
		source,
		target,
		int(item.get("priority", 50)),
		str(item.get("dialogue_goal", ""))
	)


func _is_supported_plan_action(action_id: String) -> bool:
	if action_id == IDLE_ACTION_ID:
		return true
	if action_id == "escape_intervention_dialogue":
		return false
	if action_id in ["assist_repair", "assist_upgrade", "assist_heal"]:
		return true
	if not _get_action_ids().has(action_id):
		return false
	return bool(_get_action(action_id).get("plan_selectable", true))


func _is_valid_plan_target(npc_id: String, action_id: String, target: Dictionary) -> bool:
	var target_id := str(target.get("target_id", ""))
	match action_id:
		"talk_to_npc":
			var target_npc_id := str(target.get("target_npc_id", target_id))
			if target_npc_id.is_empty() or target_npc_id == npc_id:
				return false
			var npc_system := _get_npc_system()
			if npc_system == null or npc_system.get_npc(target_npc_id).is_empty() or not npc_system.can_npc_act(target_npc_id):
				return false
			return not (npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(target_npc_id))
		"visit_location":
			var location_id := str(target.get("location_id", target_id))
			var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
			if location_id.is_empty() or memory_system == null or not memory_system.has_method("is_enterable_location") or not memory_system.is_enterable_location(location_id):
				return false
			if location_id == PLAZA_LOCATION_ID:
				return true
			var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
			if building_system == null:
				return false
			var building: Dictionary = building_system.get_building(location_id)
			return not building.is_empty() and int(building.get("hp", 0)) > 0
		"assist_repair", "assist_upgrade":
			var building_id := str(target.get("building_id", target_id))
			var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
			if building_id.is_empty() or building_system == null or building_system.get_building(building_id).is_empty():
				return false
			if action_id == "assist_repair" and building_system.has_method("is_repair_in_progress"):
				return bool(building_system.is_repair_in_progress(building_id))
			if action_id == "assist_upgrade" and building_system.has_method("is_upgrade_in_progress"):
				return bool(building_system.is_upgrade_in_progress(building_id))
			return false
		"assist_heal":
			var heal_target_id := str(target.get("target_npc_id", target_id))
			if heal_target_id.is_empty() or heal_target_id == npc_id:
				return false
			var heal_npc_system := _get_npc_system()
			if heal_npc_system == null:
				return false
			var heal_state: Dictionary = heal_npc_system.get_npc_state(heal_target_id)
			return bool(heal_state.get("unconscious", false)) and not bool(heal_state.get("escaped", false))
		_:
			return target_id.is_empty()


func _is_plan_target_unavailable(npc_id: String, item: Dictionary) -> bool:
	var action_id := str(item.get("action_id", ""))
	if action_id == IDLE_ACTION_ID:
		return false
	var target: Dictionary = item.get("target", {}) if item.get("target", {}) is Dictionary else {}
	if ["talk_to_npc", "visit_location", "assist_repair", "assist_upgrade", "assist_heal"].has(action_id):
		return not _is_valid_plan_target(npc_id, action_id, target)
	var action := _get_action(action_id)
	var action_system := _get_action_system()
	if (
		action_system != null
		and action_system.has_method("is_action_environment_available")
		and not action_system.is_action_environment_available(action_id)
	):
		return true
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


func _build_plan_target_unavailable_context(npc_id: String, item: Dictionary) -> Dictionary:
	var action_id := str(item.get("action_id", ""))
	var target: Dictionary = (
		(item.get("target", {}) as Dictionary).duplicate(true)
		if item.get("target", {}) is Dictionary
		else {}
	)
	var context := {
		"action_id": action_id,
		"action_name": _get_action_name(action_id),
		"failure_reason": "plan_target_unavailable",
		"failure_summary": "计划目标当前不可用：%s。" % _get_action_name(action_id),
		"failed_plan_item": item.duplicate(true),
		"target": target.duplicate(true)
	}
	if action_id in ["assist_upgrade", "assist_repair"]:
		var building_id := str(target.get("building_id", target.get("target_id", "")))
		var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
		var building: Dictionary = (
			building_system.get_building(building_id)
			if building_system != null
			and building_system.has_method("get_building")
			and not building_id.is_empty()
			else {}
		)
		var building_name := str(building.get("name", building_id))
		context["building_id"] = building_id
		context["building_name"] = building_name
		context["condition"] = "target_resolved_or_inactive"
		if action_id == "assist_upgrade":
			context["failure_reason"] = "no_active_upgrade"
			context["failure_summary"] = "%s的升级作业已经结束或当前未在进行，协助升级目标已不可用。" % building_name
		else:
			context["failure_reason"] = "no_active_repair"
			context["failure_summary"] = "%s的修复作业已经结束或当前未在进行，协助修复目标已不可用。" % building_name
	elif action_id == "assist_heal":
		var target_npc_id := str(target.get("target_npc_id", target.get("target_id", "")))
		context["target_npc_id"] = target_npc_id
		context["condition"] = "target_resolved_or_inactive"
		context["failure_reason"] = "healing_target_unavailable"
		context["failure_summary"] = "原协助治疗目标已经复苏、离站或当前不可治疗。"
	elif action_id == "talk_to_npc":
		context["target_npc_id"] = str(target.get("target_npc_id", target.get("target_id", "")))
		context["condition"] = "target_unavailable"
		context["failure_reason"] = "dialogue_target_unavailable"
	elif action_id == "visit_location":
		context["location_id"] = str(target.get("location_id", target.get("target_id", "")))
		context["condition"] = "location_unavailable"
		context["failure_reason"] = "visit_target_unavailable"
	context["npc_id"] = npc_id
	return context


func _is_failure_result(last_result: String) -> bool:
	return (
		last_result.contains("failed")
		or last_result.contains("_left_")
		or last_result == "dialogue_interrupted"
		or last_result == "combat_alarm"
	)


func _should_use_action_failure_plan_judgement(reason: String, options: Dictionary) -> bool:
	if bool(options.get("skip_plan_revision_judgement", false)):
		return false
	if reason in [
		"order_changed",
		"dialogue_completed",
		"dialogue_plan_revision",
		"proactive_dialogue_ended",
		"combat_ended",
		"revived_return_to_work",
		"gm_manual"
	]:
		return false
	return (
		reason in ["target_unavailable", "workstation_occupied", "resource_insufficient"]
		or reason.contains("failed")
		or reason.contains("_left_")
	)


func _normalize_failure_type(reason: String) -> String:
	if reason == "plan_action_completed":
		return "action_completed"
	if reason.contains("plan_superseded"):
		return "plan_item_superseded"
	if (
		reason == "target_unavailable"
		or reason.contains("target_unavailable")
		or reason.contains("target_moved")
		or reason.contains("building_upgrading")
		or reason.contains("building_unavailable")
	):
		return "target_unavailable"
	if reason == "order_changed":
		return "order_changed"
	if reason == "combat_alarm":
		return "combat_alarm"
	if reason.contains("dialogue"):
		return "dialogue_interrupted"
	if (
		reason.contains("no_doctor")
		or reason.contains("no_instructor")
		or reason.contains("doctor_left")
		or reason.contains("instructor_left")
	):
		return "target_unavailable"
	if reason.contains("no_workstation") or reason.contains("no_bed"):
		return "workstation_occupied"
	if (
		reason.contains("no_resources")
		or reason.contains("insufficient_stage_resources")
		or reason.contains("no_food")
		or reason.contains("no_wine")
		or reason.contains("no_money")
	):
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
		"action_completed":
			return "计划行动已经完成，当前小时需要安排后续活动。"
		"plan_item_superseded":
			return "等待期间计划阶段已经变化，原对话行动未能开始。"
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
	var npc_system := _get_npc_system()
	if npc_system != null:
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var failure_context: Dictionary = state.get("last_action_failure_context", {}) if state.get("last_action_failure_context", {}) is Dictionary else {}
		var contextual_summary := str(failure_context.get("failure_summary", "")).strip_edges()
		if not contextual_summary.is_empty():
			return contextual_summary
		var blocked_by_npcs: Array = failure_context.get("blocked_by_npcs", []) if failure_context.get("blocked_by_npcs", []) is Array else []
		if not blocked_by_npcs.is_empty():
			var blocker_names: Array[String] = []
			for raw_blocker in blocked_by_npcs:
				if raw_blocker is Dictionary:
					var blocker_name := str((raw_blocker as Dictionary).get("name", (raw_blocker as Dictionary).get("npc_id", "")))
					if not blocker_name.is_empty() and not blocker_names.has(blocker_name):
						blocker_names.append(blocker_name)
			if not blocker_names.is_empty():
				return "计划行动的工位被%s占用；可以改做其他行动，或找占用者当面交涉。" % "、".join(blocker_names)
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
		"talk_to_npc":
			return action_system.assign_npc_dialogue(
				npc_id,
				str(target.get("target_npc_id", target.get("target_id", ""))),
				_build_dialogue_opening(item),
				int(_get_action(action_id).get("soft_round_threshold", 5)),
				true,
				{
					"plan_action_source": "daily_plan",
					"assigned_plan_day": _get_current_day(),
					"assigned_plan_hour": _get_current_hour(),
					"assigned_plan_version": _get_plan_version(npc_id),
					"assigned_plan_item": item.duplicate(true)
				}
			)
		"visit_location":
			return action_system.assign_visit_location(npc_id, str(target.get("location_id", target.get("target_id", ""))))
		"seek_guard_officer":
			var prompt_text := str(item.get("dialogue_goal", "")).strip_edges()
			if prompt_text.is_empty():
				prompt_text = str(item.get("reason", "")).strip_edges()
			var proactive_result: Dictionary = npc_system.start_proactive_talk(
				npc_id,
				prompt_text,
				float(_get_action(action_id).get("duration_seconds", 3600.0))
			)
			return bool(proactive_result.get("ok", false))
		"escaping_station":
			var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
			if combat_system == null or not combat_system.has_method("start_npc_escape"):
				return false
			var escape_result: Dictionary = combat_system.start_npc_escape(npc_id, "", "daily_plan", {
				"interaction_context": "work",
				"plan_reason": str(item.get("reason", "")),
				"current_order": npc_system.get_current_order(npc_id) if npc_system.has_method("get_current_order") else {}
			})
			return bool(escape_result.get("ok", false))
		_:
			return action_system.debug_assign_action(npc_id, action_id)


func _build_dialogue_opening(item: Dictionary) -> String:
	var opening_text := str(item.get("dialogue_goal", "")).strip_edges()
	if not opening_text.is_empty():
		return opening_text
	var reason := str(item.get("reason", "")).strip_edges()
	if reason.is_empty():
		return "我想和你谈谈眼下的事情。"
	if reason.ends_with("。") or reason.ends_with("？") or reason.ends_with("！"):
		return reason
	return "我想和你谈谈：%s。" % reason


func _log_wake_up(npc_id: String, reason: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "wake_up",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id],
		"location_id": _get_current_info_location(npc_id),
		"visibility": "private",
		"importance": 35,
		"payload": {
			"day": _get_current_day(),
			"hour": _get_current_hour(),
			"reason": reason
		}
	})


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
		if action_id == "assist_upgrade":
			count += 1
			continue
		var action := _get_action(action_id)
		if str(action.get("type", "")) in ["work", "clinic_doctor", "training_instructor"]:
			count += 1
	return count


func _daily_planning_rules() -> Array[String]:
	return [
		"计划必须覆盖 0 到 23 点共 24 个阶段。",
		"通常应强烈优先安排至少 6 个生产、训练或升级协助阶段；assist_upgrade 计入工作阶段，但该数量不是程序硬门槛。",
		"只能选择行动白名单中的 action_id，或选择 idle。",
		"固定地点的带目标行动必须使用白名单同一候选中的 action_id、target_id 与 location_id；talk_to_npc 只选择 target_id，不选择或返回 location_id。",
		"NPC 对话、祈祷、前往地点和主动找守备官都是正式行动；只有没有合理行动时才等待。",
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
	execute_result: Dictionary,
	source: String = LLM_PLAN_SOURCE
) -> Dictionary:
	return {
		"ok": ok,
		"npc_id": npc_id,
		"status": status,
		"source": source,
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


func _get_current_time_text() -> String:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return "%02d:00:00" % _get_current_hour()
	return "%02d:%02d:%02d" % [
		int(game_state.current_hour),
		int(game_state.current_minute),
		int(game_state.current_second)
	]


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
	if action_id.is_empty():
		return "当前行动"
	var action := _get_action(action_id)
	return str(action.get("name", action_id))


func _nullable_string(value: Variant) -> String:
	if value == null:
		return ""
	var text := str(value).strip_edges()
	return "" if text == "<null>" else text


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
