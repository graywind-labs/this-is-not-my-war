extends Node

signal reflection_completed(result: Dictionary)

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const FALLBACK_SUMMARY_LIMIT := 6
const FIRST_SLEEP_SUMMARY_DELAY_SECONDS := 3600.0
const FIRST_SLEEP_SUMMARY_MAX_CONCURRENT := 8
const LLM_REFLECTION_SOURCE := "llm_daily_reflection"
const MOCK_REFLECTION_SOURCE := "mock_daily_reflection"

var _reflected_days_by_npc: Dictionary = {}
var _pending_first_sleep_summary_by_npc: Dictionary = {}
var _pending_reflection_by_request: Dictionary = {}
var _pending_request_by_npc: Dictionary = {}
var _last_reflection_result: Dictionary = {}
var _last_reflection_result_by_npc: Dictionary = {}
var _async_reflection_started_count := 0
var _async_reflection_completed_count := 0
var _async_reflection_max_observed_concurrent := 0


func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("event_recorded") and not event_bus.event_recorded.is_connected(_on_event_recorded):
		event_bus.event_recorded.connect(_on_event_recorded)
	if event_bus != null and event_bus.has_signal("logical_time_tick") and not event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
		event_bus.logical_time_tick.connect(_on_logical_time_tick)
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if (
		llm_bridge != null
		and llm_bridge.has_signal("daily_reflection_async_response_received")
		and not llm_bridge.daily_reflection_async_response_received.is_connected(_on_daily_reflection_async_response_received)
	):
		llm_bridge.daily_reflection_async_response_received.connect(_on_daily_reflection_async_response_received)


func generate_daily_reflection_for_npc(npc_id: String, options: Dictionary = {}) -> Dictionary:
	if npc_id.is_empty():
		return _failure("empty_npc_id", "NPC ID 为空。")

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if npc_system == null or memory_system == null:
		return _failure("system_missing", "NPCSystem 或 MemorySystem 不可用。")
	if not npc_system.has_method("get_npc") or npc_system.get_npc(npc_id).is_empty():
		return _failure("unknown_npc", "NPC 不存在。")

	var day := maxi(1, int(options.get("day", _get_current_day())))
	var force := bool(options.get("force", false))
	if has_reflected_today(npc_id, day) and not force:
		var already := {
			"ok": true,
			"status": "already_reflected",
			"npc_id": npc_id,
			"day": day,
			"message": "该 NPC 今天已经生成过首次睡眠总结。"
		}
		_last_reflection_result = already.duplicate(true)
		return already
	if _pending_request_by_npc.has(npc_id):
		var pending_request_id := str(_pending_request_by_npc.get(npc_id, ""))
		var pending_existing: Dictionary = _pending_reflection_by_request.get(pending_request_id, {})
		return {
			"ok": true,
			"pending": true,
			"status": "reflection_pending",
			"npc_id": npc_id,
			"day": int(pending_existing.get("day", day)),
			"request_id": pending_request_id
		}
	if (
		bool(options.get("use_backend", true))
		and bool(options.get("async", true))
		and _pending_reflection_by_request.size() >= FIRST_SLEEP_SUMMARY_MAX_CONCURRENT
	):
		return _failure("reflection_concurrency_limit", "首次睡眠总结已达到 8 路并发上限。")

	var request_id := str(options.get("request_id", "first_sleep_summary_%s_%d_%d" % [npc_id, day, Time.get_ticks_msec()]))
	var should_lock_summary := bool(options.get("lock_summary", false))
	if should_lock_summary and npc_system.has_method("set_first_sleep_summary_lock"):
		npc_system.set_first_sleep_summary_lock(npc_id, true, request_id)
	var memory_before: Dictionary = memory_system.get_npc_short_term_memory(npc_id) if memory_system.has_method("get_npc_short_term_memory") else {}
	var request_options := options.duplicate(true)
	request_options["request_id"] = request_id
	if bool(options.get("use_backend", true)):
		var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
		if llm_bridge != null and llm_bridge.has_method("request_npc_daily_reflection_async"):
			request_options["day"] = day
			request_options["day_events"] = _build_day_events(memory_before)
			request_options["requires_time_slowdown"] = true
			var async_result: Dictionary = llm_bridge.request_npc_daily_reflection_async(npc_id, request_options)
			if bool(async_result.get("ok", false)) and bool(async_result.get("pending", false)):
				var active_request_id := str(async_result.get("request_id", request_id))
				_pending_reflection_by_request[active_request_id] = {
					"npc_id": npc_id,
					"day": day,
					"memory_before": memory_before.duplicate(true),
					"should_lock_summary": should_lock_summary
				}
				_pending_request_by_npc[npc_id] = active_request_id
				_async_reflection_started_count += 1
				_async_reflection_max_observed_concurrent = maxi(
					_async_reflection_max_observed_concurrent,
					_pending_reflection_by_request.size()
				)
				_last_reflection_result = {
					"ok": true,
					"pending": true,
					"status": "reflection_pending",
					"npc_id": npc_id,
					"day": day,
					"request_id": active_request_id
				}
				return _last_reflection_result.duplicate(true)
			var immediate_fallback := _build_fallback_reflection(npc_id, day, memory_before)
			immediate_fallback["fallback_error"] = async_result.duplicate(true)
			return _complete_daily_reflection(npc_id, day, memory_before, immediate_fallback, should_lock_summary, request_id)

	var reflection := _request_backend_reflection(npc_id, day, request_options, memory_before)
	if reflection.is_empty():
		reflection = _build_fallback_reflection(npc_id, day, memory_before)
	return _complete_daily_reflection(npc_id, day, memory_before, reflection, should_lock_summary, request_id)


func _complete_daily_reflection(
	npc_id: String,
	day: int,
	memory_before: Dictionary,
	reflection: Dictionary,
	should_lock_summary: bool,
	request_id: String
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if npc_system == null or memory_system == null:
		return _failure("system_missing", "NPCSystem 或 MemorySystem 不可用。")
	if not reflection.has("source"):
		reflection["source"] = "first_sleep_summary"
	reflection["day"] = day

	var apply_result: Dictionary = npc_system.apply_daily_reflection(npc_id, reflection) if npc_system.has_method("apply_daily_reflection") else {}
	if not bool(apply_result.get("ok", false)):
		if should_lock_summary and npc_system.has_method("set_first_sleep_summary_lock"):
			npc_system.set_first_sleep_summary_lock(npc_id, false, request_id)
		var apply_failed := _failure("apply_failed", str(apply_result.get("message", "长期记忆写入失败。")))
		_last_reflection_result = apply_failed.duplicate(true)
		reflection_completed.emit(_last_reflection_result.duplicate(true))
		return apply_failed

	var clear_result: Dictionary = {}
	if memory_system.has_method("clear_npc_short_term_memory"):
		clear_result = memory_system.clear_npc_short_term_memory(npc_id)

	_mark_reflected(npc_id, day)
	_pending_first_sleep_summary_by_npc.erase(npc_id)
	if should_lock_summary and npc_system.has_method("set_first_sleep_summary_lock"):
		npc_system.set_first_sleep_summary_lock(npc_id, false, request_id)
	_last_reflection_result = {
		"ok": true,
		"status": "reflected",
		"npc_id": npc_id,
		"day": day,
		"source": str(reflection.get("source", "")),
		"model_provider": str(reflection.get("model_provider", "")),
		"model_name": str(reflection.get("model_name", "")),
		"model_fallback_used": bool(reflection.get("model_fallback_used", false)),
		"diary_entry": str(reflection.get("diary_entry", "")),
		"knowledge_graph_updates": reflection.get("knowledge_graph_updates", []),
		"apply_result": apply_result,
		"cleared_short_term_memory": clear_result
	}
	_last_reflection_result_by_npc[npc_id] = _last_reflection_result.duplicate(true)
	reflection_completed.emit(_last_reflection_result.duplicate(true))
	return _last_reflection_result.duplicate(true)


func _on_daily_reflection_async_response_received(result: Dictionary) -> void:
	var request_id := str(result.get("request_id", ""))
	if request_id.is_empty() or not _pending_reflection_by_request.has(request_id):
		return
	var pending: Dictionary = _pending_reflection_by_request.get(request_id, {})
	_pending_reflection_by_request.erase(request_id)
	_async_reflection_completed_count += 1
	var npc_id := str(pending.get("npc_id", result.get("npc_id", "")))
	if str(_pending_request_by_npc.get(npc_id, "")) == request_id:
		_pending_request_by_npc.erase(npc_id)
	var day := int(pending.get("day", _get_current_day()))
	var memory_before: Dictionary = pending.get("memory_before", {}) if pending.get("memory_before", {}) is Dictionary else {}
	var reflection: Dictionary = result.get("daily_reflection", {}) if result.get("daily_reflection", {}) is Dictionary else {}
	if not bool(result.get("ok", false)) or not bool(reflection.get("ok", false)):
		reflection = _build_fallback_reflection(npc_id, day, memory_before)
		reflection["fallback_error"] = result.duplicate(true)
	else:
		var tagged_result := _tag_backend_reflection_source(reflection)
		if bool(tagged_result.get("ok", false)):
			reflection = tagged_result.get("reflection", {}).duplicate(true)
		else:
			reflection = _build_fallback_reflection(npc_id, day, memory_before)
			reflection["fallback_error"] = tagged_result.duplicate(true)
	_complete_daily_reflection(
		npc_id,
		day,
		memory_before,
		reflection,
		bool(pending.get("should_lock_summary", false)),
		request_id
	)


func has_reflected_today(npc_id: String, day: int = -1) -> bool:
	var target_day := _get_current_day() if day <= 0 else day
	var reflected_days: Array = _reflected_days_by_npc.get(npc_id, [])
	return reflected_days.has(target_day)


func get_last_reflection_result() -> Dictionary:
	return _last_reflection_result.duplicate(true)


func get_async_reflection_snapshot() -> Dictionary:
	return {
		"max_concurrent": FIRST_SLEEP_SUMMARY_MAX_CONCURRENT,
		"active_count": _pending_reflection_by_request.size(),
		"max_observed_concurrent": _async_reflection_max_observed_concurrent,
		"started_count": _async_reflection_started_count,
		"completed_count": _async_reflection_completed_count,
		"pending_request_ids": _pending_reflection_by_request.keys().duplicate(),
		"pending_npc_ids": _pending_request_by_npc.keys().duplicate(),
		"results_by_npc": _last_reflection_result_by_npc.duplicate(true)
	}


func debug_generate_reflection(npc_id: String, force: bool = false) -> Dictionary:
	return generate_daily_reflection_for_npc(npc_id, {
		"force": force,
		"trigger": "gm_panel",
		"lock_summary": false
	})


func debug_get_last_reflection_result() -> Dictionary:
	return get_last_reflection_result()


func _on_event_recorded(event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	if not ["sleep_started", "sleep_ended"].has(event_type):
		return
	var npc_id := str(event.get("subject_npc_id", ""))
	if npc_id.is_empty() or npc_id == "system":
		return
	if event_type == "sleep_ended":
		_pending_first_sleep_summary_by_npc.erase(npc_id)
		return
	var day := int(event.get("day", _get_current_day()))
	if has_reflected_today(npc_id, day):
		return
	_pending_first_sleep_summary_by_npc[npc_id] = {
		"npc_id": npc_id,
		"day": day,
		"elapsed_seconds": 0.0,
		"related_event_id": event.get("event_id", null)
	}


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0 or _pending_first_sleep_summary_by_npc.is_empty():
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var pending_ids := _pending_first_sleep_summary_by_npc.keys()
	for raw_npc_id in pending_ids:
		var npc_id := str(raw_npc_id)
		if not _pending_first_sleep_summary_by_npc.has(npc_id):
			continue
		var pending: Dictionary = _pending_first_sleep_summary_by_npc.get(npc_id, {})
		var day := int(pending.get("day", _get_current_day()))
		if has_reflected_today(npc_id, day):
			_pending_first_sleep_summary_by_npc.erase(npc_id)
			continue
		var state: Dictionary = npc_system.get_npc_state(npc_id) if npc_system.has_method("get_npc_state") else {}
		if str(state.get("current_action", "")) != "sleep_in_dormitory":
			_pending_first_sleep_summary_by_npc.erase(npc_id)
			continue
		var elapsed := float(pending.get("elapsed_seconds", 0.0)) + game_delta_seconds
		pending["elapsed_seconds"] = elapsed
		_pending_first_sleep_summary_by_npc[npc_id] = pending
		if elapsed < FIRST_SLEEP_SUMMARY_DELAY_SECONDS:
			continue
		if _pending_reflection_by_request.size() >= FIRST_SLEEP_SUMMARY_MAX_CONCURRENT:
			continue
		generate_daily_reflection_for_npc(npc_id, {
			"day": day,
			"related_event_id": pending.get("related_event_id", null),
			"trigger": "first_sleep_after_one_hour",
			"lock_summary": true
		})


func _request_backend_reflection(npc_id: String, day: int, options: Dictionary, memory_before: Dictionary) -> Dictionary:
	if not bool(options.get("use_backend", true)):
		return {}
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("request_npc_daily_reflection"):
		return {}

	var request_options := {
		"day": day,
		"day_events": _build_day_events(memory_before),
		"requires_time_slowdown": true,
		"request_id": options.get("request_id", ""),
		"related_event_id": options.get("related_event_id", null)
	}
	var response: Dictionary = llm_bridge.request_npc_daily_reflection(npc_id, request_options)
	if not bool(response.get("ok", false)):
		return {}

	var reflection: Dictionary = response.get("daily_reflection", {})
	if not bool(reflection.get("ok", false)):
		return {}
	var tagged_result := _tag_backend_reflection_source(reflection)
	return tagged_result.get("reflection", {}).duplicate(true) if bool(tagged_result.get("ok", false)) else {}


func _tag_backend_reflection_source(reflection: Dictionary) -> Dictionary:
	var provider := str(reflection.get("model_provider", "")).strip_edges().to_lower()
	var fallback_used := bool(reflection.get("model_fallback_used", false))
	if provider.is_empty():
		return _failure("missing_model_provider", "首次睡眠总结成功响应缺少 model_provider，拒绝把来源猜成真实 LLM。")
	if fallback_used:
		return _failure("model_fallback_forbidden", "首次睡眠总结成功响应来自模型 fallback，拒绝写成正式 LLM 总结。")
	var tagged := reflection.duplicate(true)
	tagged["source"] = MOCK_REFLECTION_SOURCE if provider == "mock" else LLM_REFLECTION_SOURCE
	return {
		"ok": true,
		"reflection": tagged
	}


func _build_fallback_reflection(npc_id: String, day: int, memory_before: Dictionary) -> Dictionary:
	var npc_name := _get_npc_name(npc_id)
	var summaries := _collect_memory_summaries(memory_before)
	var remembered_text := "今天没有留下明确的短期记忆。"
	var diary_entry := "今天很安静，安静得让我担心明天会突然变重。睡前我只想记住：先活下来，再决定该相信什么。"
	if not summaries.is_empty():
		remembered_text = "；".join(summaries)
		diary_entry = "今天我记住了这些事：%s。夜里躺下时，我仍能感觉到驿站的压力压在身上。" % remembered_text

	return {
		"ok": true,
		"npc_id": npc_id,
		"day": day,
		"diary_entry": diary_entry,
		"knowledge_graph_updates": [
			{
				"subject": "station",
				"relation": "daily_pressure",
				"value": "%s在第%d天睡前记住：%s" % [npc_name, day, remembered_text],
				"confidence": 0.55,
				"subject_label": "驿站",
				"relation_label": "当日压力",
				"value_label": "%s在第%d天睡前记住：%s" % [npc_name, day, remembered_text]
			}
		],
		"debug_reason": "后端不可用或返回无效，使用 Godot 模板生成首次睡眠总结。",
		"source": "template_fallback"
	}


func _build_day_events(memory_before: Dictionary) -> Array:
	var result: Array = []
	for raw_event in memory_before.get("event_log", []):
		if raw_event is Dictionary:
			var event_summary := _event_to_summary(raw_event)
			event_summary["memory_kind"] = "experienced"
			result.append(event_summary)
	for raw_event in memory_before.get("witness_log", []):
		if raw_event is Dictionary:
			var witness_summary := _event_to_summary(raw_event)
			witness_summary["memory_kind"] = "witnessed"
			result.append(witness_summary)
	return result


func _event_to_summary(event: Dictionary) -> Dictionary:
	return {
		"event_id": event.get("event_id", null),
		"type": str(event.get("type", "")),
		"summary": str(event.get("summary", "")),
		"importance": clampi(int(event.get("importance", 50)), 0, 100),
		"day": event.get("day", null),
		"time": event.get("time", null),
		"payload": event.get("payload", {})
	}


func _collect_memory_summaries(memory_before: Dictionary) -> Array[String]:
	var summaries: Array[String] = []
	var day_events := _build_day_events(memory_before)
	day_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("importance", 0)) > int(b.get("importance", 0))
	)
	for event in day_events:
		var summary := str(event.get("summary", "")).strip_edges()
		if summary.is_empty():
			summary = str(event.get("type", "")).strip_edges()
		if not summary.is_empty():
			summaries.append(summary)
		if summaries.size() >= FALLBACK_SUMMARY_LIMIT:
			break
	return summaries


func _mark_reflected(npc_id: String, day: int) -> void:
	if not _reflected_days_by_npc.has(npc_id):
		_reflected_days_by_npc[npc_id] = []
	var reflected_days: Array = _reflected_days_by_npc[npc_id]
	if not reflected_days.has(day):
		reflected_days.append(day)
	_reflected_days_by_npc[npc_id] = reflected_days


func _get_current_day() -> int:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return 1
	return maxi(1, int(game_state.current_day))


func _get_npc_name(npc_id: String) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return npc_id
	var npc: Dictionary = npc_system.get_npc(npc_id) if npc_system.has_method("get_npc") else {}
	return str(npc.get("name", npc_id))


func _failure(reason: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"message": message
	}
