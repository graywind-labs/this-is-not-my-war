extends Node

signal reflection_completed(result: Dictionary)

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const FALLBACK_SUMMARY_LIMIT := 6
const FIRST_SLEEP_SUMMARY_DELAY_SECONDS := 3600.0
const FIRST_SLEEP_SUMMARY_MAX_CONCURRENT := 8
const NIGHT_WINDOW_ANCHOR_HOUR := 21
const NIGHT_WINDOW_ANCHOR_SECONDS := NIGHT_WINDOW_ANCHOR_HOUR * 3600
const GAME_DAY_SECONDS := 24 * 3600
const GUARD_NOTICE_EPOCH_DAY := 1
const GUARD_NOTICE_EPOCH_TIME := "06:00:00"
const GUARD_NOTICE_BASIS := "守备官在公告牌向驿站众人传达“我们奉命守住此地”的守站告示"
const LLM_REFLECTION_SOURCE := "llm_daily_reflection"
const MOCK_REFLECTION_SOURCE := "mock_daily_reflection"

var _reflected_days_by_npc: Dictionary = {}
var _sleep_summary_window_by_npc: Dictionary = {}
var _completed_reflection_windows_by_npc: Dictionary = {}
var _pending_reflection_by_request: Dictionary = {}
var _pending_request_by_npc: Dictionary = {}
var _last_successful_reflection_end_by_npc: Dictionary = {}
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

	var trigger_clock := _resolve_trigger_clock(options)
	var day := maxi(1, int(trigger_clock.get("day", _get_current_day())))
	var window_identity := _build_summary_window_identity(
		day,
		int(trigger_clock.get("day_seconds", 0))
	)
	var force := bool(options.get("force", false))
	if int(window_identity.get("anchor_day", 0)) < GUARD_NOTICE_EPOCH_DAY and not force:
		return _failure(
			"summary_window_not_started",
			"首个正式熟睡总结窗口从守站告示传达当日 21:00 开始。"
		)
	var summary_window_key := str(options.get(
		"summary_window_key",
		window_identity.get("window_key", "")
	))
	var window_anchor_day := int(options.get(
		"window_anchor_day",
		window_identity.get("anchor_day", day)
	))
	window_anchor_day = maxi(GUARD_NOTICE_EPOCH_DAY, window_anchor_day)
	var summary_window := _build_summary_window_context(
		summary_window_key,
		window_anchor_day
	)
	if _has_completed_reflection_window(npc_id, summary_window_key) and not force:
		var already := {
			"ok": true,
			"status": "already_reflected",
			"npc_id": npc_id,
			"day": day,
			"summary_window_key": summary_window_key,
			"window_anchor_day": window_anchor_day,
			"message": "该 NPC 已经完成这个 21:00 锚定睡眠窗口的熟睡总结。"
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
			"summary_window_key": str(pending_existing.get("summary_window_key", "")),
			"request_id": pending_request_id
		}
	if (
		bool(options.get("use_backend", true))
		and bool(options.get("async", true))
		and _pending_reflection_by_request.size() >= FIRST_SLEEP_SUMMARY_MAX_CONCURRENT
	):
		return _failure("reflection_concurrency_limit", "首次睡眠总结已达到 8 路并发上限。")

	var request_id := str(options.get(
		"request_id",
		"first_sleep_summary_%s_%s_%d" % [
			npc_id,
			summary_window_key,
			Time.get_ticks_msec()
		]
	))
	var should_lock_summary := bool(options.get("lock_summary", false))
	if should_lock_summary and npc_system.has_method("set_first_sleep_summary_lock"):
		npc_system.set_first_sleep_summary_lock(npc_id, true, request_id)
	var memory_before: Dictionary = (
		memory_system.get_npc_short_term_memory_snapshot(npc_id)
		if memory_system.has_method("get_npc_short_term_memory_snapshot")
		else memory_system.get_npc_short_term_memory(npc_id)
	)
	var reflection_period := _build_reflection_period(
		npc_id,
		trigger_clock,
		memory_before
	)
	var request_options := options.duplicate(true)
	request_options["request_id"] = request_id
	request_options["day"] = day
	request_options["trigger_hour"] = int(trigger_clock.get("hour", 0))
	request_options["trigger_time"] = str(trigger_clock.get("time", "00:00:00"))
	request_options["summary_window"] = summary_window.duplicate(true)
	request_options["reflection_period"] = reflection_period.duplicate(true)
	if bool(options.get("use_backend", true)):
		var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
		if llm_bridge != null and llm_bridge.has_method("request_npc_daily_reflection_async"):
			request_options["day_events"] = _build_day_events(memory_before)
			request_options["requires_time_slowdown"] = true
			var async_result: Dictionary = llm_bridge.request_npc_daily_reflection_async(npc_id, request_options)
			if bool(async_result.get("ok", false)) and bool(async_result.get("pending", false)):
				var active_request_id := str(async_result.get("request_id", request_id))
				_pending_reflection_by_request[active_request_id] = {
					"npc_id": npc_id,
					"day": day,
					"summary_window_key": summary_window_key,
					"window_anchor_day": window_anchor_day,
					"trigger_time": str(trigger_clock.get("time", "00:00:00")),
					"summary_window": summary_window.duplicate(true),
					"reflection_period": reflection_period.duplicate(true),
					"memory_before": memory_before.duplicate(true),
					"should_lock_summary": should_lock_summary
				}
				_pending_request_by_npc[npc_id] = active_request_id
				_set_summary_window_pending(
					npc_id,
					summary_window_key,
					active_request_id,
					day,
					str(trigger_clock.get("time", "00:00:00"))
				)
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
					"summary_window_key": summary_window_key,
					"window_anchor_day": window_anchor_day,
					"request_id": active_request_id
				}
				return _last_reflection_result.duplicate(true)
			var immediate_fallback := _build_fallback_reflection(
				npc_id,
				day,
				memory_before,
				reflection_period
			)
			immediate_fallback["fallback_error"] = async_result.duplicate(true)
			return _complete_daily_reflection(
				npc_id,
				day,
				memory_before,
				immediate_fallback,
				should_lock_summary,
				request_id,
				summary_window_key,
				window_anchor_day,
				str(trigger_clock.get("time", "00:00:00")),
				reflection_period,
				summary_window
			)

	var reflection := _request_backend_reflection(npc_id, day, request_options, memory_before)
	if reflection.is_empty():
		reflection = _build_fallback_reflection(
			npc_id,
			day,
			memory_before,
			reflection_period
		)
	return _complete_daily_reflection(
		npc_id,
		day,
		memory_before,
		reflection,
		should_lock_summary,
		request_id,
		summary_window_key,
		window_anchor_day,
		str(trigger_clock.get("time", "00:00:00")),
		reflection_period,
		summary_window
	)


func _complete_daily_reflection(
	npc_id: String,
	day: int,
	memory_before: Dictionary,
	reflection: Dictionary,
	should_lock_summary: bool,
	request_id: String,
	summary_window_key: String,
	window_anchor_day: int,
	trigger_time: String,
	reflection_period: Dictionary,
	summary_window: Dictionary
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if npc_system == null or memory_system == null:
		return _failure("system_missing", "NPCSystem 或 MemorySystem 不可用。")
	if not reflection.has("source"):
		reflection["source"] = "first_sleep_summary"
	var diary_day := maxi(GUARD_NOTICE_EPOCH_DAY, window_anchor_day)
	var diary_label := str(summary_window.get(
		"diary_label",
		"接到守备命令的第%d天" % diary_day
	))
	reflection["day"] = diary_day
	reflection["trigger_day"] = day
	reflection["trigger_time"] = trigger_time
	reflection["summary_window_key"] = summary_window_key
	reflection["window_anchor_day"] = diary_day
	reflection["record_label"] = diary_label
	reflection["reflection_period"] = reflection_period.duplicate(true)

	var apply_result: Dictionary = npc_system.apply_daily_reflection(npc_id, reflection) if npc_system.has_method("apply_daily_reflection") else {}
	if not bool(apply_result.get("ok", false)):
		if should_lock_summary and npc_system.has_method("set_first_sleep_summary_lock"):
			npc_system.set_first_sleep_summary_lock(npc_id, false, request_id)
		_set_summary_window_retryable(npc_id, summary_window_key)
		var apply_failed := _failure("apply_failed", str(apply_result.get("message", "长期记忆写入失败。")))
		_last_reflection_result = apply_failed.duplicate(true)
		reflection_completed.emit(_last_reflection_result.duplicate(true))
		return apply_failed

	var clear_result: Dictionary = {}
	if memory_system.has_method("clear_npc_short_term_memory_snapshot"):
		clear_result = memory_system.clear_npc_short_term_memory_snapshot(
			npc_id,
			memory_before
		)

	_mark_reflected(npc_id, day)
	_last_successful_reflection_end_by_npc[npc_id] = (
		reflection_period.get("end", {}).duplicate(true)
		if reflection_period.get("end", {}) is Dictionary
		else {}
	)
	_mark_reflection_window_completed(
		npc_id,
		summary_window_key,
		day,
		request_id,
		window_anchor_day
	)
	if should_lock_summary and npc_system.has_method("set_first_sleep_summary_lock"):
		npc_system.set_first_sleep_summary_lock(npc_id, false, request_id)
	_last_reflection_result = {
		"ok": true,
		"status": "reflected",
		"npc_id": npc_id,
		"day": day,
		"diary_day": diary_day,
		"record_label": diary_label,
		"summary_window_key": summary_window_key,
		"window_anchor_day": window_anchor_day,
		"source": str(reflection.get("source", "")),
		"model_provider": str(reflection.get("model_provider", "")),
		"model_name": str(reflection.get("model_name", "")),
		"model_fallback_used": bool(reflection.get("model_fallback_used", false)),
		"diary_entry": str(reflection.get("diary_entry", "")),
		"reflection_period": reflection_period.duplicate(true),
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
	var reflection_period: Dictionary = pending.get("reflection_period", {}) if pending.get("reflection_period", {}) is Dictionary else {}
	var summary_window: Dictionary = pending.get("summary_window", {}) if pending.get("summary_window", {}) is Dictionary else {}
	var reflection: Dictionary = result.get("daily_reflection", {}) if result.get("daily_reflection", {}) is Dictionary else {}
	if not bool(result.get("ok", false)) or not bool(reflection.get("ok", false)):
		reflection = _build_fallback_reflection(
			npc_id,
			day,
			memory_before,
			reflection_period
		)
		reflection["fallback_error"] = result.duplicate(true)
	else:
		var tagged_result := _tag_backend_reflection_source(reflection)
		if bool(tagged_result.get("ok", false)):
			reflection = tagged_result.get("reflection", {}).duplicate(true)
		else:
			reflection = _build_fallback_reflection(
				npc_id,
				day,
				memory_before,
				reflection_period
			)
			reflection["fallback_error"] = tagged_result.duplicate(true)
	_complete_daily_reflection(
		npc_id,
		day,
		memory_before,
		reflection,
		bool(pending.get("should_lock_summary", false)),
		request_id,
		str(pending.get("summary_window_key", "")),
		int(pending.get("window_anchor_day", day)),
		str(pending.get("trigger_time", "00:00:00")),
		reflection_period,
		summary_window
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
		"summary_window_anchor": {
			"hour": NIGHT_WINDOW_ANCHOR_HOUR,
			"time": "%02d:00:00" % NIGHT_WINDOW_ANCHOR_HOUR,
			"window_duration_seconds": GAME_DAY_SECONDS,
			"required_accumulated_sleep_seconds": FIRST_SLEEP_SUMMARY_DELAY_SECONDS
		},
		"active_count": _pending_reflection_by_request.size(),
		"max_observed_concurrent": _async_reflection_max_observed_concurrent,
		"started_count": _async_reflection_started_count,
		"completed_count": _async_reflection_completed_count,
		"pending_request_ids": _pending_reflection_by_request.keys().duplicate(),
		"pending_npc_ids": _pending_request_by_npc.keys().duplicate(),
		"sleep_window_states_by_npc": _sleep_summary_window_by_npc.duplicate(true),
		"completed_windows_by_npc": _completed_reflection_windows_by_npc.duplicate(true),
		"last_successful_period_end_by_npc": _last_successful_reflection_end_by_npc.duplicate(true),
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
	var event_clock := _resolve_event_clock(event)
	var identity := _build_summary_window_identity(
		int(event_clock.get("day", _get_current_day())),
		int(event_clock.get("day_seconds", 0))
	)
	if int(identity.get("anchor_day", 0)) < GUARD_NOTICE_EPOCH_DAY:
		return
	if event_type == "sleep_started":
		var window_state := _get_or_create_summary_window_state(npc_id, identity)
		window_state["sleep_active"] = true
		window_state["related_event_id"] = event.get(
			"event_id",
			window_state.get("related_event_id", null)
		)
		window_state["last_sleep_started_day"] = int(event_clock.get("day", 1))
		window_state["last_sleep_started_time"] = str(event_clock.get("time", "00:00:00"))
		_sleep_summary_window_by_npc[npc_id] = window_state
		return
	if not _sleep_summary_window_by_npc.has(npc_id):
		return
	var existing: Dictionary = _sleep_summary_window_by_npc.get(npc_id, {})
	if str(existing.get("window_key", "")) != str(identity.get("window_key", "")):
		return
	existing["sleep_active"] = false
	existing["last_sleep_ended_day"] = int(event_clock.get("day", 1))
	existing["last_sleep_ended_time"] = str(event_clock.get("time", "00:00:00"))
	_sleep_summary_window_by_npc[npc_id] = existing


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return
	var start_clock := _get_current_clock_context()
	var start_absolute := _clock_to_absolute_seconds(
		int(start_clock.get("day", 1)),
		int(start_clock.get("day_seconds", 0))
	)
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		if npc_id.is_empty():
			continue
		var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(npc_state.get("current_action", "")) != "sleep_in_dormitory":
			if _sleep_summary_window_by_npc.has(npc_id):
				var inactive_window: Dictionary = _sleep_summary_window_by_npc.get(npc_id, {})
				inactive_window["sleep_active"] = false
				_sleep_summary_window_by_npc[npc_id] = inactive_window
			continue
		_accumulate_sleep_across_summary_windows(
			npc_id,
			start_absolute,
			game_delta_seconds
		)


func _accumulate_sleep_across_summary_windows(
	npc_id: String,
	start_absolute: float,
	game_delta_seconds: float
) -> void:
	var cursor := start_absolute
	var remaining := game_delta_seconds
	while remaining > 0.0001:
		var clock := _clock_from_absolute_seconds(cursor)
		var identity := _build_summary_window_identity(
			int(clock.get("day", 1)),
			int(clock.get("day_seconds", 0))
		)
		var next_anchor_absolute := _next_summary_anchor_absolute_seconds(
			int(clock.get("day", 1)),
			int(clock.get("day_seconds", 0))
		)
		var segment_seconds := minf(remaining, maxf(0.0001, next_anchor_absolute - cursor))
		_accumulate_sleep_window_segment(
			npc_id,
			identity,
			segment_seconds,
			cursor
		)
		cursor += segment_seconds
		remaining -= segment_seconds


func _accumulate_sleep_window_segment(
	npc_id: String,
	identity: Dictionary,
	segment_seconds: float,
	segment_start_absolute: float
) -> void:
	if int(identity.get("anchor_day", 0)) < GUARD_NOTICE_EPOCH_DAY:
		return
	var window_state := _get_or_create_summary_window_state(npc_id, identity)
	window_state["sleep_active"] = true
	if _has_completed_reflection_window(npc_id, str(identity.get("window_key", ""))):
		window_state["summary_status"] = "completed"
		_sleep_summary_window_by_npc[npc_id] = window_state
		return
	var before := maxf(0.0, float(window_state.get("accumulated_sleep_seconds", 0.0)))
	var after := before + maxf(0.0, segment_seconds)
	window_state["accumulated_sleep_seconds"] = after
	window_state["remaining_sleep_seconds"] = maxf(
		0.0,
		FIRST_SLEEP_SUMMARY_DELAY_SECONDS - after
	)
	if after >= FIRST_SLEEP_SUMMARY_DELAY_SECONDS:
		window_state["summary_status"] = "eligible"
	_sleep_summary_window_by_npc[npc_id] = window_state
	if after < FIRST_SLEEP_SUMMARY_DELAY_SECONDS:
		return
	if _pending_request_by_npc.has(npc_id):
		var pending_request_id := str(_pending_request_by_npc.get(npc_id, ""))
		var pending: Dictionary = _pending_reflection_by_request.get(pending_request_id, {})
		if str(pending.get("summary_window_key", "")) == str(identity.get("window_key", "")):
			window_state["summary_status"] = "pending"
			window_state["request_id"] = pending_request_id
		else:
			window_state["summary_status"] = "eligible_waiting_for_previous_request"
		_sleep_summary_window_by_npc[npc_id] = window_state
		return
	if _pending_reflection_by_request.size() >= FIRST_SLEEP_SUMMARY_MAX_CONCURRENT:
		window_state["summary_status"] = "eligible_waiting_for_concurrency"
		_sleep_summary_window_by_npc[npc_id] = window_state
		return

	var seconds_until_eligible := maxf(
		0.0,
		FIRST_SLEEP_SUMMARY_DELAY_SECONDS - before
	)
	var trigger_absolute := segment_start_absolute + minf(
		segment_seconds,
		seconds_until_eligible
	)
	var trigger_clock := _clock_from_absolute_seconds(trigger_absolute)
	var result := generate_daily_reflection_for_npc(npc_id, {
		"day": int(trigger_clock.get("day", _get_current_day())),
		"trigger_hour": int(trigger_clock.get("hour", 0)),
		"trigger_time": str(trigger_clock.get("time", "00:00:00")),
		"summary_window_key": str(identity.get("window_key", "")),
		"window_anchor_day": int(identity.get("anchor_day", 0)),
		"related_event_id": window_state.get("related_event_id", null),
		"trigger": "night_window_sleep_accumulated",
		"lock_summary": true
	})
	if not bool(result.get("ok", false)):
		_set_summary_window_retryable(npc_id, str(identity.get("window_key", "")))


func _get_or_create_summary_window_state(
	npc_id: String,
	identity: Dictionary
) -> Dictionary:
	var window_key := str(identity.get("window_key", ""))
	var existing: Dictionary = (
		_sleep_summary_window_by_npc.get(npc_id, {})
		if _sleep_summary_window_by_npc.get(npc_id, {}) is Dictionary
		else {}
	)
	if str(existing.get("window_key", "")) == window_key:
		return existing.duplicate(true)
	var completed := _has_completed_reflection_window(npc_id, window_key)
	var created := {
		"npc_id": npc_id,
		"window_key": window_key,
		"anchor_day": int(identity.get("anchor_day", 0)),
		"anchor_time": "%02d:00:00" % NIGHT_WINDOW_ANCHOR_HOUR,
		"end_day": int(identity.get("end_day", 1)),
		"end_time": "%02d:00:00" % NIGHT_WINDOW_ANCHOR_HOUR,
		"accumulated_sleep_seconds": 0.0,
		"remaining_sleep_seconds": FIRST_SLEEP_SUMMARY_DELAY_SECONDS,
		"required_sleep_seconds": FIRST_SLEEP_SUMMARY_DELAY_SECONDS,
		"sleep_active": false,
		"summary_status": "completed" if completed else "accumulating",
		"request_id": "",
		"related_event_id": null
	}
	_sleep_summary_window_by_npc[npc_id] = created
	return created.duplicate(true)


func _set_summary_window_pending(
	npc_id: String,
	window_key: String,
	request_id: String,
	trigger_day: int,
	trigger_time: String
) -> void:
	if not _sleep_summary_window_by_npc.has(npc_id):
		return
	var window_state: Dictionary = _sleep_summary_window_by_npc.get(npc_id, {})
	if str(window_state.get("window_key", "")) != window_key:
		return
	window_state["summary_status"] = "pending"
	window_state["request_id"] = request_id
	window_state["trigger_day"] = trigger_day
	window_state["trigger_time"] = trigger_time
	_sleep_summary_window_by_npc[npc_id] = window_state


func _set_summary_window_retryable(npc_id: String, window_key: String) -> void:
	if not _sleep_summary_window_by_npc.has(npc_id):
		return
	var window_state: Dictionary = _sleep_summary_window_by_npc.get(npc_id, {})
	if str(window_state.get("window_key", "")) != window_key:
		return
	window_state["summary_status"] = "eligible"
	window_state["request_id"] = ""
	_sleep_summary_window_by_npc[npc_id] = window_state


func _mark_reflection_window_completed(
	npc_id: String,
	window_key: String,
	trigger_day: int,
	request_id: String,
	window_anchor_day: int
) -> void:
	if window_key.is_empty():
		return
	var completed: Dictionary = (
		_completed_reflection_windows_by_npc.get(npc_id, {})
		if _completed_reflection_windows_by_npc.get(npc_id, {}) is Dictionary
		else {}
	)
	completed[window_key] = {
		"window_key": window_key,
		"anchor_day": window_anchor_day,
		"trigger_day": trigger_day,
		"request_id": request_id
	}
	_completed_reflection_windows_by_npc[npc_id] = completed
	if not _sleep_summary_window_by_npc.has(npc_id):
		return
	var window_state: Dictionary = _sleep_summary_window_by_npc.get(npc_id, {})
	if str(window_state.get("window_key", "")) != window_key:
		return
	window_state["summary_status"] = "completed"
	window_state["request_id"] = request_id
	window_state["completed_trigger_day"] = trigger_day
	_sleep_summary_window_by_npc[npc_id] = window_state


func has_completed_summary_window(npc_id: String, window_key: String = "") -> bool:
	var resolved_key := window_key
	if resolved_key.is_empty():
		var clock := _get_current_clock_context()
		resolved_key = str(_build_summary_window_identity(
			int(clock.get("day", 1)),
			int(clock.get("day_seconds", 0))
		).get("window_key", ""))
	return _has_completed_reflection_window(npc_id, resolved_key)


func _has_completed_reflection_window(npc_id: String, window_key: String) -> bool:
	if window_key.is_empty():
		return false
	var completed: Dictionary = (
		_completed_reflection_windows_by_npc.get(npc_id, {})
		if _completed_reflection_windows_by_npc.get(npc_id, {}) is Dictionary
		else {}
	)
	return completed.has(window_key)


func _resolve_event_clock(event: Dictionary) -> Dictionary:
	var day := maxi(1, int(event.get("day", _get_current_day())))
	var time_text := str(event.get("time", "")).strip_edges()
	if time_text.is_empty():
		var current := _get_current_clock_context()
		if int(current.get("day", day)) == day:
			return current
		time_text = "00:00:00"
	var day_seconds := _parse_game_time_seconds(time_text)
	return _make_clock_context(day, day_seconds)


func _resolve_trigger_clock(options: Dictionary) -> Dictionary:
	var current := _get_current_clock_context()
	var day := maxi(1, int(options.get("day", current.get("day", 1))))
	var time_text := str(options.get(
		"trigger_time",
		options.get("time", "")
	)).strip_edges()
	var day_seconds := int(current.get("day_seconds", 0))
	if not time_text.is_empty():
		day_seconds = _parse_game_time_seconds(time_text)
	elif options.has("trigger_hour"):
		day_seconds = clampi(int(options.get("trigger_hour", 0)), 0, 23) * 3600
	return _make_clock_context(day, day_seconds)


func _get_current_clock_context() -> Dictionary:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return _make_clock_context(1, 0)
	var day_seconds := (
		clampi(int(game_state.current_hour), 0, 23) * 3600
		+ clampi(int(game_state.current_minute), 0, 59) * 60
		+ clampi(int(game_state.current_second), 0, 59)
	)
	return _make_clock_context(maxi(1, int(game_state.current_day)), day_seconds)


func _make_clock_context(day: int, day_seconds: int) -> Dictionary:
	var clean_seconds := clampi(day_seconds, 0, GAME_DAY_SECONDS - 1)
	var hour := int(clean_seconds / 3600)
	var minute := int((clean_seconds % 3600) / 60)
	var second := clean_seconds % 60
	return {
		"day": maxi(1, day),
		"day_seconds": clean_seconds,
		"hour": hour,
		"time": "%02d:%02d:%02d" % [hour, minute, second]
	}


func _parse_game_time_seconds(time_text: String) -> int:
	var parts := time_text.split(":")
	if parts.size() != 3:
		return 0
	return (
		clampi(int(parts[0]), 0, 23) * 3600
		+ clampi(int(parts[1]), 0, 59) * 60
		+ clampi(int(parts[2]), 0, 59)
	)


func _build_summary_window_identity(day: int, day_seconds: int) -> Dictionary:
	var anchor_day := day if day_seconds >= NIGHT_WINDOW_ANCHOR_SECONDS else day - 1
	return {
		"window_key": "night_%d_2100" % anchor_day,
		"anchor_day": anchor_day,
		"end_day": anchor_day + 1
	}


func _build_summary_window_context(
	window_key: String,
	window_anchor_day: int
) -> Dictionary:
	var anchor_day := maxi(GUARD_NOTICE_EPOCH_DAY, window_anchor_day)
	return {
		"window_key": window_key,
		"anchor_day": anchor_day,
		"anchor_time": "%02d:00:00" % NIGHT_WINDOW_ANCHOR_HOUR,
		"end_day": anchor_day + 1,
		"end_time": "%02d:00:00" % NIGHT_WINDOW_ANCHOR_HOUR,
		"diary_label": "接到守备命令的第%d天" % anchor_day,
		"notice_basis": GUARD_NOTICE_BASIS
	}


func _build_reflection_period(
	npc_id: String,
	end_clock: Dictionary,
	memory_snapshot: Dictionary
) -> Dictionary:
	var has_previous_summary := _last_successful_reflection_end_by_npc.has(npc_id)
	var start: Dictionary = (
		(_last_successful_reflection_end_by_npc.get(npc_id, {}) as Dictionary).duplicate(true)
		if has_previous_summary
		else {
			"day": GUARD_NOTICE_EPOCH_DAY,
			"time": GUARD_NOTICE_EPOCH_TIME
		}
	)
	var end := {
		"day": maxi(GUARD_NOTICE_EPOCH_DAY, int(end_clock.get("day", 1))),
		"time": str(end_clock.get("time", "00:00:00"))
	}
	return {
		"start": start,
		"end": end,
		"start_inclusive": not has_previous_summary,
		"start_basis": (
			"上一次成功熟睡总结的请求快照水位"
			if has_previous_summary
			else GUARD_NOTICE_BASIS
		),
		"end_basis": "本次熟睡总结请求创建时的短期记忆快照",
		"snapshot_event_count": int(memory_snapshot.get("event_count", 0)),
		"snapshot_witness_count": int(memory_snapshot.get("witness_count", 0))
	}


func _clock_to_absolute_seconds(day: int, day_seconds: int) -> float:
	return float((maxi(1, day) - 1) * GAME_DAY_SECONDS + clampi(
		day_seconds,
		0,
		GAME_DAY_SECONDS - 1
	))


func _clock_from_absolute_seconds(absolute_seconds: float) -> Dictionary:
	var clean_absolute := maxf(0.0, absolute_seconds)
	var zero_based_day := floori(clean_absolute / float(GAME_DAY_SECONDS))
	var day_seconds := floori(fmod(clean_absolute, float(GAME_DAY_SECONDS)))
	return _make_clock_context(zero_based_day + 1, day_seconds)


func _next_summary_anchor_absolute_seconds(day: int, day_seconds: int) -> float:
	var day_start := float((maxi(1, day) - 1) * GAME_DAY_SECONDS)
	if day_seconds < NIGHT_WINDOW_ANCHOR_SECONDS:
		return day_start + NIGHT_WINDOW_ANCHOR_SECONDS
	return day_start + GAME_DAY_SECONDS + NIGHT_WINDOW_ANCHOR_SECONDS


func _request_backend_reflection(npc_id: String, day: int, options: Dictionary, memory_before: Dictionary) -> Dictionary:
	if not bool(options.get("use_backend", true)):
		return {}
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("request_npc_daily_reflection"):
		return {}

	var request_options := {
		"day": day,
		"trigger_hour": int(options.get("trigger_hour", 0)),
		"trigger_time": str(options.get("trigger_time", "00:00:00")),
		"day_events": _build_day_events(memory_before),
		"requires_time_slowdown": true,
		"request_id": options.get("request_id", ""),
		"related_event_id": options.get("related_event_id", null),
		"summary_window": (
			options.get("summary_window", {}).duplicate(true)
			if options.get("summary_window", {}) is Dictionary
			else {}
		),
		"reflection_period": (
			options.get("reflection_period", {}).duplicate(true)
			if options.get("reflection_period", {}) is Dictionary
			else {}
		)
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


func _build_fallback_reflection(
	npc_id: String,
	day: int,
	memory_before: Dictionary,
	reflection_period: Dictionary = {}
) -> Dictionary:
	var npc_name := _get_npc_name(npc_id)
	var summaries := _collect_memory_summaries(memory_before)
	var period_text := _format_reflection_period(reflection_period)
	var remembered_text := "这段记录范围内没有留下明确的短期记忆。"
	var diary_entry := "这段时间很安静，安静得让我担心接下来会突然变重。睡前我只想记住：先活下来，再决定该相信什么。"
	if not summaries.is_empty():
		remembered_text = "；".join(summaries)
		diary_entry = "从上次落笔到现在，我记住了这些事：%s。夜里躺下时，我仍能感觉到驿站的压力压在身上。" % remembered_text

	return {
		"ok": true,
		"npc_id": npc_id,
		"day": day,
		"diary_entry": diary_entry,
		"knowledge_graph_updates": [
			{
				"subject": "station",
				"relation": "daily_pressure",
				"value": "%s在%s熟睡时记住：%s" % [npc_name, period_text, remembered_text],
				"confidence": 0.55,
				"subject_label": "驿站",
				"relation_label": "近期压力",
				"value_label": "%s在%s熟睡时记住：%s" % [npc_name, period_text, remembered_text]
			}
		],
		"debug_reason": "后端不可用或返回无效，使用 Godot 模板生成首次睡眠总结。",
		"source": "template_fallback"
	}


func _format_reflection_period(reflection_period: Dictionary) -> String:
	var start: Dictionary = reflection_period.get("start", {}) if reflection_period.get("start", {}) is Dictionary else {}
	var end: Dictionary = reflection_period.get("end", {}) if reflection_period.get("end", {}) is Dictionary else {}
	if start.is_empty() or end.is_empty():
		return "本次记录范围"
	return "第%d天%s至第%d天%s" % [
		int(start.get("day", GUARD_NOTICE_EPOCH_DAY)),
		str(start.get("time", GUARD_NOTICE_EPOCH_TIME)),
		int(end.get("day", GUARD_NOTICE_EPOCH_DAY)),
		str(end.get("time", "00:00:00"))
	]


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
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge != null and llm_bridge.has_method("build_compact_memory_event"):
		return llm_bridge.build_compact_memory_event(event)
	return {
		"type": str(event.get("type", "")),
		"summary": str(event.get("summary", "")),
		"importance": clampi(int(event.get("importance", 50)), 0, 100),
		"day": event.get("day", null),
		"time": event.get("time", null)
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
