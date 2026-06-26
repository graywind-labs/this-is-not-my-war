extends Node

signal backend_status_changed(status_text: String, ok: bool)
signal dialogue_response_received(result: Dictionary)
signal dialogue_async_response_received(result: Dictionary)
signal daily_plan_response_received(result: Dictionary)
signal plan_revision_response_received(result: Dictionary)
signal battle_judgement_response_received(result: Dictionary)
signal daily_reflection_response_received(result: Dictionary)

const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const DEFAULT_BACKEND_URL := "http://127.0.0.1:5000"
const GUARD_OFFICER_ID := "guard_officer"
const GUARD_OFFICER_NAME := "守备官"
const DEFAULT_GUARD_APPEARANCE := "驿站守备官，穿着磨旧的军官外套，带着边境军令。"
const SHORT_MEMORY_EVENT_LIMIT := 8
const HTTP_POLL_DELAY_MSEC := 10
const WARTIME_DIALOGUE_CONTEXTS: Array[String] = ["rally", "combat", "avoid_combat"]

@export var backend_base_url: String = DEFAULT_BACKEND_URL
@export var request_timeout_seconds: float = 2.0
@export var dialogue_wait_scale: float = -1.0

var _last_backend_ok := false
var _last_backend_status := "后端：未检查"
var _request_counter := 0
var _pending_slowdown_request_ids: Array[String] = []
var _debug_last_slowdown_registered := false
var _last_npc_context_injection: Dictionary = {}
var _active_request_by_npc: Dictionary = {}
var _cancelled_request_ids: Dictionary = {}
var _async_request_threads: Dictionary = {}


func initialize() -> void:
	_emit_backend_status(_last_backend_status, _last_backend_ok)


func _ready() -> void:
	initialize()


func set_backend_base_url(url: String) -> void:
	var clean_url := url.strip_edges()
	if clean_url.is_empty():
		clean_url = DEFAULT_BACKEND_URL
	backend_base_url = clean_url.trim_suffix("/")


func get_backend_base_url() -> String:
	return backend_base_url.trim_suffix("/")


func get_last_backend_status() -> Dictionary:
	return {
		"ok": _last_backend_ok,
		"status_text": _last_backend_status,
		"backend_base_url": get_backend_base_url()
	}


func get_pending_slowdown_count() -> int:
	return _pending_slowdown_request_ids.size()


func debug_was_slowdown_registered() -> bool:
	return _debug_last_slowdown_registered


func get_last_npc_context_injection() -> Dictionary:
	return _last_npc_context_injection.duplicate(true)


func check_health() -> Dictionary:
	var result: Dictionary = _request_json("GET", "/health", {}, false, "")
	if bool(result.get("ok", false)):
		var body: Dictionary = result.get("body", {})
		_emit_backend_status("后端：已连接 %s" % str(body.get("service", "ok")), true)
	else:
		_emit_backend_status("后端：未连接 %s" % str(result.get("message", "请求失败")), false)
	return result


func request_npc_dialogue(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
	var payload := build_npc_dialogue_payload(npc_id, speaker_text, options)
	if payload.is_empty():
		var failed := _failure_result("payload_error", "无法构造 NPCDialogueRequest。")
		dialogue_response_received.emit(failed.duplicate(true))
		return failed

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("dialogue")))
	var result: Dictionary = _request_json("POST", "/npc/dialogue", payload, true, request_id, {
		"npc_id": npc_id,
		"kind": "dialogue",
		"label": "正在思考",
		"cancellable": true
	})
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["dialogue"] = result.get("body", {})
	dialogue_response_received.emit(response.duplicate(true))
	return response


func request_npc_dialogue_async(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
	var payload := build_npc_dialogue_payload(npc_id, speaker_text, options)
	if payload.is_empty():
		return _failure_result("payload_error", "无法构造 NPCDialogueRequest。")

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("dialogue")))
	_set_npc_llm_activity(npc_id, request_id, {
		"npc_id": npc_id,
		"kind": "dialogue",
		"label": "正在思考",
		"cancellable": true
	})
	if bool(payload.get("meta", {}).get("requires_time_slowdown", true)):
		_register_time_slowdown(request_id)

	var thread := Thread.new()
	var record := {
		"thread": thread,
		"npc_id": npc_id,
		"request_id": request_id,
		"call_type": "dialogue"
	}
	_async_request_threads[request_id] = record
	var err := thread.start(Callable(self, "_thread_request_json").bind("POST", "/npc/dialogue", payload, request_id))
	if err != OK:
		_async_request_threads.erase(request_id)
		_release_time_slowdown(request_id)
		_clear_npc_llm_activity(npc_id, request_id)
		_active_request_by_npc.erase(npc_id)
		return _failure_result("thread_start_failed", "无法启动异步对话请求。", {
			"godot_error": err,
			"request_id": request_id
		})
	return {
		"ok": true,
		"pending": true,
		"request_id": request_id
	}


func request_npc_daily_plan(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var payload := build_npc_daily_plan_payload(npc_id, options)
	if payload.is_empty():
		var failed := _failure_result("payload_error", "无法构造 DailyPlanRequest。")
		daily_plan_response_received.emit(failed.duplicate(true))
		return failed

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("plan_day")))
	var result: Dictionary = _request_json("POST", "/npc/plan_day", payload, true, request_id, {
		"npc_id": npc_id,
		"kind": "plan",
		"label": "正在计划下一步行动",
		"cancellable": true
	})
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["daily_plan"] = result.get("body", {})
	daily_plan_response_received.emit(response.duplicate(true))
	return response


func request_npc_plan_revision(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var payload := build_npc_plan_revision_payload(npc_id, options)
	if payload.is_empty():
		var failed := _failure_result("payload_error", "无法构造 PlanRevisionRequest。")
		plan_revision_response_received.emit(failed.duplicate(true))
		return failed

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("revise_plan")))
	var result: Dictionary = _request_json("POST", "/npc/revise_plan", payload, true, request_id, {
		"npc_id": npc_id,
		"kind": "plan",
		"label": "正在计划下一步行动",
		"cancellable": true
	})
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["plan_revision"] = result.get("body", {})
	plan_revision_response_received.emit(response.duplicate(true))
	return response


func request_npc_battle_judgement(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var payload := build_npc_battle_judgement_payload(npc_id, options)
	if payload.is_empty():
		var failed := _failure_result("payload_error", "无法构造 BattleJudgementRequest。")
		battle_judgement_response_received.emit(failed.duplicate(true))
		return failed

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("battle_judgement")))
	var should_slowdown := bool(payload.get("meta", {}).get("requires_time_slowdown", true))
	var result: Dictionary = _request_json("POST", "/npc/battle_judgement", payload, should_slowdown, request_id, {
		"npc_id": npc_id,
		"kind": "battle_judgement",
		"label": "正在压住恐惧",
		"cancellable": false,
		"reason": str(options.get("reason", "low_hp"))
	})
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["battle_judgement"] = result.get("body", {})
	battle_judgement_response_received.emit(response.duplicate(true))
	return response


func request_npc_daily_reflection(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var payload := build_npc_daily_reflection_payload(npc_id, options)
	if payload.is_empty():
		var failed := _failure_result("payload_error", "无法构造 DailyReflectionRequest。")
		daily_reflection_response_received.emit(failed.duplicate(true))
		return failed

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("daily_reflection")))
	var should_slowdown := bool(payload.get("meta", {}).get("requires_time_slowdown", true))
	var result: Dictionary = _request_json("POST", "/npc/daily_reflection", payload, should_slowdown, request_id, {
		"npc_id": npc_id,
		"kind": "first_sleep_summary",
		"label": "正在熟睡",
		"cancellable": false
	})
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["daily_reflection"] = result.get("body", {})
	daily_reflection_response_received.emit(response.duplicate(true))
	return response


func debug_check_health() -> Dictionary:
	return check_health()


func debug_request_dialogue(
	npc_id: String,
	speaker_text: String = "守备官需要你帮忙守住这里。",
	is_recruitment_request: bool = false,
	visibility: String = "private"
) -> Dictionary:
	return request_npc_dialogue(npc_id, speaker_text, {
		"is_recruitment_request": is_recruitment_request,
		"dialogue_state": {
			"visibility": visibility
		}
	})


func debug_request_plan_revision(npc_id: String, failure_type: String = "unknown", failure_summary: String = "GM 调试触发计划重评估。") -> Dictionary:
	return request_npc_plan_revision(npc_id, {
		"failure_type": failure_type,
		"failure_summary": failure_summary
	})


func debug_request_battle_judgement(npc_id: String) -> Dictionary:
	return request_npc_battle_judgement(npc_id, {
		"trigger": "low_hp",
		"allowed_decisions": ["continue_fighting", "escape_station", "inspired"],
		"reason": "gm_debug"
	})


func debug_request_daily_plan(npc_id: String) -> Dictionary:
	return request_npc_daily_plan(npc_id, {
		"planning_rules": _default_daily_planning_rules()
	})


func debug_request_daily_reflection(npc_id: String) -> Dictionary:
	return request_npc_daily_reflection(npc_id, {
		"requires_time_slowdown": true
	})


func cancel_npc_llm_requests(npc_id: String, reason: String = "cancelled_by_player_dialogue") -> Dictionary:
	if npc_id.is_empty():
		return _failure_result("empty_npc_id", "NPC ID 为空。")
	var active: Dictionary = _active_request_by_npc.get(npc_id, {})
	if active.is_empty():
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system != null and npc_system.has_method("get_npc_llm_activity"):
			active = npc_system.get_npc_llm_activity(npc_id)
	if active.is_empty() or not bool(active.get("active", false)):
		return {"ok": true, "cancelled": false, "reason": "no_active_request"}
	if not bool(active.get("cancellable", true)):
		return _failure_result("request_not_cancellable", "该 NPC 正在首次睡眠总结，无法打断。", {
			"npc_id": npc_id,
			"activity": active.duplicate(true)
		})
	var request_id := str(active.get("request_id", ""))
	if not request_id.is_empty():
		_cancelled_request_ids[request_id] = reason
	_release_time_slowdown(request_id)
	_clear_npc_llm_activity(npc_id, request_id)
	_active_request_by_npc.erase(npc_id)
	return {
		"ok": true,
		"cancelled": true,
		"npc_id": npc_id,
		"request_id": request_id,
		"reason": reason
	}


func build_npc_dialogue_payload(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		push_warning("LLMBridge cannot build dialogue payload because NPCSystem is missing.")
		return {}

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}

	var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	var speaker_kind := str(options.get("speaker_kind", "guard_officer"))
	var speaker_npc_id := str(options.get("speaker_npc_id", ""))
	var speaker_name := str(options.get("speaker_name", GUARD_OFFICER_NAME if speaker_kind == "guard_officer" else _get_npc_name(speaker_npc_id)))
	if speaker_kind == "guard_officer":
		speaker_name = GUARD_OFFICER_NAME

	var current_round := maxi(1, int(options.get("current_round", 1)))
	var max_rounds := maxi(1, int(options.get("max_rounds", 1)))
	var dialogue_kind := str(options.get("dialogue_kind", "player_npc"))
	var location_id := str(npc_state.get("current_location", "plaza"))
	var location_name := str(npc_state.get("current_location_name", "广场"))
	var dialogue_state: Dictionary = options.get("dialogue_state", {})
	var visibility := str(dialogue_state.get("visibility", options.get("visibility", "private")))
	if not ["private", "local_public"].has(visibility):
		visibility = "private"
	var interaction_context := str(options.get("interaction_context", _get_interaction_context_from_state(npc_state)))
	if not WARTIME_DIALOGUE_CONTEXTS.has(interaction_context):
		interaction_context = "work"
	if WARTIME_DIALOGUE_CONTEXTS.has(interaction_context):
		visibility = "local_public"
	var participants := _normalize_string_array(dialogue_state.get("participants", [npc_id, GUARD_OFFICER_ID if speaker_kind == "guard_officer" else speaker_npc_id]))

	var request_id := str(options.get("request_id", _make_request_id("dialogue")))
	var current_order: Dictionary = npc_system.get_current_order(npc_id) if npc_system.has_method("get_current_order") else {}
	var payload := {
		"meta": {
			"request_id": request_id,
			"call_type": "dialogue",
			"source": "godot",
			"requires_time_slowdown": bool(options.get("requires_time_slowdown", true)),
			"related_event_id": options.get("related_event_id", null)
		},
		"game_time": _get_game_time_context(),
		"dialogue_kind": dialogue_kind,
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"npc_setting": _build_npc_setting(npc),
		"speaker_name": speaker_name,
		"speaker_text": speaker_text,
		"speaker_context": _build_speaker_context(speaker_kind, speaker_npc_id, speaker_name, npc_system),
		"interaction_context": interaction_context,
		"battlefield_context": _build_battlefield_context(npc_id, interaction_context),
		"is_recruitment_request": bool(options.get("is_recruitment_request", false)),
		"current_round": current_round,
		"max_rounds": max_rounds,
		"npc_state": _build_npc_state_context(npc, npc_state),
		"current_order": current_order.duplicate(true),
		"dialogue_state": {
			"visibility": visibility,
			"location_id": str(dialogue_state.get("location_id", location_id)),
			"location_name": str(dialogue_state.get("location_name", location_name)),
			"current_round": current_round,
			"max_rounds": max_rounds,
			"participants": participants
		},
		"short_memory": _build_short_memory_context(npc_id),
		"long_memory": _build_long_memory_context(npc),
		"location_context": _build_location_context(npc_state),
		"conversation_history": options.get("conversation_history", []),
		"constraints": options.get("constraints", [])
	}

	if speaker_kind == "npc" and not speaker_npc_id.is_empty():
		payload["speaker_npc"] = _build_npc_context(speaker_npc_id, npc_system)
	payload["target_npc"] = _build_npc_context(npc_id, npc_system)
	_record_npc_context_injection(npc_id, "dialogue", current_order, request_id, {
		"interaction_context": interaction_context,
		"has_battlefield_context": WARTIME_DIALOGUE_CONTEXTS.has(interaction_context)
	})
	return payload


func build_npc_daily_plan_payload(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		push_warning("LLMBridge cannot build daily plan payload because NPCSystem is missing.")
		return {}

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}

	var request_id := str(options.get("request_id", _make_request_id("plan_day")))
	var npc_context := _build_npc_context(npc_id, npc_system)
	if npc_context.is_empty():
		return {}
	var payload := {
		"meta": {
			"request_id": request_id,
			"call_type": "plan_day",
			"source": "godot",
			"requires_time_slowdown": bool(options.get("requires_time_slowdown", true)),
			"related_event_id": options.get("related_event_id", null)
		},
		"game_time": _get_game_time_context(),
		"npc": npc_context,
		"allowed_actions": _build_allowed_action_candidates(),
		"current_building_states": _build_building_state_context(),
		"current_resource_states": _build_resource_state_context(),
		"planning_rules": options.get("planning_rules", _default_daily_planning_rules())
	}
	_record_npc_context_injection(npc_id, "plan_day", npc_context.get("current_order", {}), request_id)
	return payload


func build_npc_plan_revision_payload(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		push_warning("LLMBridge cannot build plan revision payload because NPCSystem is missing.")
		return {}

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}

	var current_plan: Array = []
	if options.has("current_plan") and options["current_plan"] is Array:
		current_plan = options["current_plan"]
	elif npc_system.has_method("get_npc_plan"):
		current_plan = npc_system.get_npc_plan(npc_id)

	var game_time := _get_game_time_context()
	var request_id := str(options.get("request_id", _make_request_id("revise_plan")))
	var failed_plan_item: Dictionary = options.get("failed_plan_item", {})
	if failed_plan_item.is_empty():
		failed_plan_item = _find_plan_item_for_hour(current_plan, int(game_time.get("hour", 0)))
	if failed_plan_item.is_empty():
		failed_plan_item = _make_schema_plan_item(int(game_time.get("hour", 0)), "idle", "", "当前没有可用计划项。")

	var failure_type := _normalize_plan_failure_type(str(options.get("failure_type", "unknown")))
	var failure_summary := str(options.get("failure_summary", "计划执行异常，需要重新评估。"))
	var npc_context := _build_npc_context(npc_id, npc_system)
	if npc_context.is_empty():
		return {}

	var payload := {
		"meta": {
			"request_id": request_id,
			"call_type": "revise_plan",
			"source": "godot",
			"requires_time_slowdown": bool(options.get("requires_time_slowdown", true)),
			"related_event_id": options.get("related_event_id", null)
		},
		"game_time": game_time,
		"npc": npc_context,
		"current_plan": _plan_items_to_schema(current_plan),
		"failed_plan_item": _plan_item_to_schema(failed_plan_item),
		"failure_type": failure_type,
		"failure_summary": failure_summary,
		"allowed_actions": _build_allowed_action_candidates()
	}
	_record_npc_context_injection(npc_id, "revise_plan", npc_context.get("current_order", {}), request_id)
	return payload


func build_npc_battle_judgement_payload(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		push_warning("LLMBridge cannot build battle judgement payload because NPCSystem is missing.")
		return {}

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}

	var request_id := str(options.get("request_id", _make_request_id("battle_judgement")))
	var trigger := _normalize_battle_trigger(str(options.get("trigger", "low_hp")))
	var npc_context := _build_npc_context(npc_id, npc_system)
	if npc_context.is_empty():
		return {}
	var interaction_context := str(options.get("interaction_context", _get_interaction_context_from_state(npc_system.get_npc_state(npc_id))))
	if not WARTIME_DIALOGUE_CONTEXTS.has(interaction_context):
		interaction_context = "combat"
	var battlefield_context: Dictionary = options.get("battlefield_context", {})
	if battlefield_context.is_empty():
		battlefield_context = _build_battlefield_context(npc_id, interaction_context)
	var combat_context: Dictionary = options.get("combat_context", {})
	if combat_context.is_empty():
		combat_context = battlefield_context.duplicate(true)
	else:
		combat_context = combat_context.duplicate(true)
	if not combat_context.has("battlefield_context"):
		combat_context["battlefield_context"] = battlefield_context.duplicate(true)
	var allowed_decisions := _normalize_battle_decision_array(options.get("allowed_decisions", []))
	if allowed_decisions.is_empty():
		allowed_decisions = ["avoid_battle", "escape_station"]
	var payload := {
		"meta": {
			"request_id": request_id,
			"call_type": "battle_judgement",
			"source": "godot",
			"requires_time_slowdown": bool(options.get("requires_time_slowdown", true)),
			"related_event_id": options.get("related_event_id", null)
		},
		"game_time": _get_game_time_context(),
		"trigger": trigger,
		"npc": npc_context,
		"combat_context": combat_context,
		"battlefield_context": battlefield_context,
		"allowed_decisions": allowed_decisions
	}
	_record_npc_context_injection(npc_id, "battle_judgement", npc_context.get("current_order", {}), request_id, {
		"trigger": trigger,
		"has_battlefield_context": not battlefield_context.is_empty()
	})
	return payload


func build_npc_daily_reflection_payload(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		push_warning("LLMBridge cannot build daily reflection payload because NPCSystem is missing.")
		return {}

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}

	var game_time := _get_game_time_context()
	var request_id := str(options.get("request_id", _make_request_id("daily_reflection")))
	var npc_context := _build_npc_context(npc_id, npc_system)
	if npc_context.is_empty():
		return {}
	var payload := {
		"meta": {
			"request_id": request_id,
			"call_type": "daily_reflection",
			"source": "godot",
			"requires_time_slowdown": bool(options.get("requires_time_slowdown", true)),
			"related_event_id": options.get("related_event_id", null)
		},
		"game_time": {
			"day": int(options.get("day", game_time.get("day", 1))),
			"time": str(game_time.get("time", "00:00:00")),
			"hour": int(game_time.get("hour", 0))
		},
		"npc": npc_context,
		"day_events": options.get("day_events", _build_reflection_day_events(npc_id)),
		"existing_diary_entries": _build_existing_diary_entries(npc)
	}
	_record_npc_context_injection(npc_id, "daily_reflection", npc_context.get("current_order", {}), request_id)
	return payload


func _thread_request_json(method: String, endpoint: String, payload: Dictionary, request_id: String) -> void:
	var transport_result := _send_http_request(method, endpoint, payload)
	var result := _parse_transport_json_result(transport_result)
	result["request_id"] = request_id
	call_deferred("_complete_async_dialogue_request", request_id, result)


func _complete_async_dialogue_request(request_id: String, result: Dictionary) -> void:
	var record: Dictionary = _async_request_threads.get(request_id, {})
	if record.is_empty():
		return
	var thread := record.get("thread", null) as Thread
	if thread != null:
		thread.wait_to_finish()
	_async_request_threads.erase(request_id)
	var npc_id := str(record.get("npc_id", ""))
	_release_time_slowdown(request_id)
	if _was_request_cancelled(request_id):
		if not npc_id.is_empty():
			_clear_npc_llm_activity(npc_id, request_id)
		var cancelled := _failure_result("request_cancelled", "LLM 请求已被玩家对话打断。", {
			"request_id": request_id,
			"cancelled": true
		})
		dialogue_response_received.emit(cancelled.duplicate(true))
		dialogue_async_response_received.emit(cancelled.duplicate(true))
		return
	if not npc_id.is_empty():
		_clear_npc_llm_activity(npc_id, request_id)
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["dialogue"] = result.get("body", {})
	dialogue_response_received.emit(response.duplicate(true))
	dialogue_async_response_received.emit(response.duplicate(true))


func _parse_transport_json_result(transport_result: Dictionary) -> Dictionary:
	if not bool(transport_result.get("ok", false)):
		return transport_result

	var body_text := str(transport_result.get("body_text", ""))
	var parsed: Variant = JSON.parse_string(body_text)
	if not parsed is Dictionary:
		return _failure_result("invalid_json_response", "后端响应不是 JSON 对象。", {
			"response_code": int(transport_result.get("response_code", 0)),
			"body_text": body_text
		})
	var response_body: Dictionary = parsed
	if not bool(response_body.get("ok", true)):
		return _failure_result(str(response_body.get("error_code", "backend_error")), str(response_body.get("message", "后端返回错误。")), {
			"response_code": int(transport_result.get("response_code", 0)),
			"body": response_body
		})

	return {
		"ok": true,
		"response_code": int(transport_result.get("response_code", 0)),
		"body": response_body
	}


func _request_json(
	method: String,
	endpoint: String,
	payload: Dictionary = {},
	use_slowdown: bool = false,
	request_id: String = "",
	activity_options: Dictionary = {}
) -> Dictionary:
	var activity_npc_id := str(activity_options.get("npc_id", ""))
	var activity_request_id := request_id if not request_id.is_empty() else _make_request_id("llm")
	if not activity_npc_id.is_empty():
		_set_npc_llm_activity(activity_npc_id, activity_request_id, activity_options)
	var active_slowdown_id := ""
	if use_slowdown:
		active_slowdown_id = activity_request_id
		_register_time_slowdown(active_slowdown_id)

	var transport_result := _send_http_request(method, endpoint, payload)
	_release_time_slowdown(active_slowdown_id)
	if _was_request_cancelled(activity_request_id):
		if not activity_npc_id.is_empty():
			_clear_npc_llm_activity(activity_npc_id, activity_request_id)
		return _failure_result("request_cancelled", "LLM 请求已被玩家对话打断。", {
			"request_id": activity_request_id,
			"cancelled": true
		})
	if not activity_npc_id.is_empty():
		_clear_npc_llm_activity(activity_npc_id, activity_request_id)
	if not bool(transport_result.get("ok", false)):
		return transport_result
	return _parse_transport_json_result(transport_result)


func _set_npc_llm_activity(npc_id: String, request_id: String, options: Dictionary) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("set_npc_llm_activity"):
		return
	var activity := {
		"active": true,
		"kind": str(options.get("kind", "dialogue")),
		"label": str(options.get("label", "")),
		"request_id": request_id,
		"cancellable": bool(options.get("cancellable", true)),
		"reason": str(options.get("reason", ""))
	}
	npc_system.set_npc_llm_activity(npc_id, activity)
	_active_request_by_npc[npc_id] = activity.duplicate(true)


func _clear_npc_llm_activity(npc_id: String, request_id: String) -> void:
	var active: Dictionary = _active_request_by_npc.get(npc_id, {})
	if not active.is_empty() and str(active.get("request_id", "")) == request_id:
		_active_request_by_npc.erase(npc_id)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("clear_npc_llm_activity"):
		npc_system.clear_npc_llm_activity(npc_id, request_id)


func _was_request_cancelled(request_id: String) -> bool:
	if request_id.is_empty() or not _cancelled_request_ids.has(request_id):
		return false
	_cancelled_request_ids.erase(request_id)
	return true


func _plan_items_to_schema(plan: Array) -> Array:
	var result: Array = []
	for raw_item in plan:
		if raw_item is Dictionary:
			result.append(_plan_item_to_schema(raw_item))
	return result


func _plan_item_to_schema(item: Dictionary) -> Dictionary:
	var hour := clampi(int(item.get("hour", _get_game_time_context().get("hour", 0))), 0, 23)
	var action_id := str(item.get("action_id", "idle"))
	if action_id.is_empty():
		action_id = "idle"
	var action := _get_action_definition(action_id)
	var target: Dictionary = item.get("target", {})
	var location_id: Variant = item.get("location_id", null)
	if location_id == null or str(location_id).is_empty():
		location_id = action.get("location_required", null)
	if location_id == null and target.has("building_id"):
		location_id = str(target.get("building_id", ""))
	var target_id: Variant = item.get("target_id", null)
	if target_id == null:
		for key in ["target_npc_id", "building_id"]:
			if target.has(key):
				target_id = str(target.get(key, ""))
				break
	return {
		"hour": hour,
		"action_kind": _infer_plan_action_kind(action_id, action),
		"action_id": action_id,
		"location_id": null if location_id == null or str(location_id).is_empty() else str(location_id),
		"target_id": null if target_id == null or str(target_id).is_empty() else str(target_id),
		"priority": clampi(int(item.get("priority", 50)), 0, 100),
		"reason": str(item.get("reason", ""))
	}


func _find_plan_item_for_hour(plan: Array, hour: int) -> Dictionary:
	for raw_item in plan:
		if raw_item is Dictionary and int((raw_item as Dictionary).get("hour", -1)) == hour:
			return (raw_item as Dictionary).duplicate(true)
	return {}


func _make_schema_plan_item(hour: int, action_id: String, location_id: String, reason: String) -> Dictionary:
	return {
		"hour": clampi(hour, 0, 23),
		"action_kind": _infer_plan_action_kind(action_id, _get_action_definition(action_id)),
		"action_id": action_id,
		"location_id": null if location_id.is_empty() else location_id,
		"target_id": null,
		"priority": 50,
		"reason": reason
	}


func _build_allowed_action_candidates() -> Array:
	var result: Array = []
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("get_action_ids"):
		return result
	for action_id in action_system.get_action_ids():
		var action: Dictionary = action_system.get_action(str(action_id))
		result.append({
			"action_id": str(action_id),
			"name": str(action.get("name", action_id)),
			"location_id": null if str(action.get("location_required", "")).is_empty() else str(action.get("location_required", "")),
			"target_id": null,
			"tags": [str(action.get("type", ""))]
		})
	result.append({
		"action_id": "idle",
		"name": "等待",
		"location_id": "plaza",
		"target_id": null,
		"tags": ["idle"]
	})
	return result


func _build_resource_state_context() -> Dictionary:
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	if resource_system != null and resource_system.has_method("get_resource_snapshot"):
		return resource_system.get_resource_snapshot()
	return {}


func _build_building_state_context() -> Dictionary:
	var result := {}
	var building_system := get_node_or_null("/root/Main/Systems/BuildingSystem")
	if building_system == null or not building_system.has_method("get_building_ids"):
		return result
	for building_id in building_system.get_building_ids():
		var building: Dictionary = building_system.get_building(str(building_id))
		result[str(building_id)] = {
			"name": str(building.get("name", building_id)),
			"level": int(building.get("level", 1)),
			"hp": int(building.get("hp", 0)),
			"max_hp": int(building.get("max_hp", 0)),
			"is_repairing": bool(building.get("is_repairing", false)),
			"is_upgrading": bool(building.get("is_upgrading", false))
		}
	return result


func _default_daily_planning_rules() -> Array[String]:
	return [
		"返回 24 个小时计划项，每个 hour 0-23 恰好出现一次。",
		"计划至少包含 6 个工作阶段。",
		"只能选择 allowed_actions 中的 action_id，或选择 idle。",
		"current_order 只是守备官当前指令参考，不是强制行动。",
		"不得让模型直接结算资源、HP、建筑修复、训练成长或战斗结果。"
	]


func _infer_plan_action_kind(action_id: String, action: Dictionary) -> String:
	if action_id == "idle" or action_id.is_empty():
		return "idle"
	match str(action.get("type", "")):
		"work", "clinic_doctor":
			return "work"
		"eat":
			return "eat"
		"sleep":
			return "sleep"
		"training_instructor", "training_student":
			return "train"
		"clinic_patient", "targeted_heal":
			return "assist_heal"
	match action_id:
		"assist_repair":
			return "assist_repair"
		"assist_upgrade":
			return "assist_upgrade"
		"assist_heal":
			return "assist_heal"
		_:
			return "idle"


func _get_action_definition(action_id: String) -> Dictionary:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("get_action"):
		return {}
	if action_id == "idle" or action_id.is_empty():
		return {}
	return action_system.get_action(action_id)


func _normalize_plan_failure_type(raw_type: String) -> String:
	match raw_type:
		"target_unavailable", "workstation_occupied", "resource_insufficient", "dialogue_interrupted", "low_hp", "low_satiety", "high_fatigue", "combat_alarm", "order_changed":
			return raw_type
		"work_failed_no_workstation", "clinic_doctor_failed_no_workstation", "clinic_patient_failed_no_bed", "training_student_failed_no_workstation", "training_instructor_failed_no_workstation":
			return "workstation_occupied"
		"work_failed_no_resources", "eat_failed_no_food", "assist_heal_failed_no_money", "clinic_treatment_failed_no_money":
			return "resource_insufficient"
		"plan_target_unavailable":
			return "target_unavailable"
		_:
			return "unknown"


func _normalize_battle_trigger(raw_trigger: String) -> String:
	match raw_trigger:
		"combat_started", "low_hp", "escape_check":
			return raw_trigger
		_:
			return "low_hp"


func _normalize_battle_decision_array(raw_decisions: Variant) -> Array[String]:
	var result: Array[String] = []
	if not raw_decisions is Array:
		return result
	for raw_decision in raw_decisions:
		var decision := str(raw_decision)
		if not [
			"join_battle",
			"avoid_battle",
			"continue_fighting",
			"escape_station",
			"inspired"
		].has(decision):
			continue
		if not result.has(decision):
			result.append(decision)
	return result


func _send_http_request(method: String, endpoint: String, payload: Dictionary) -> Dictionary:
	var parsed_url := _parse_backend_url()
	if not bool(parsed_url.get("ok", false)):
		return parsed_url

	var http_method := _to_http_method(method)
	if http_method < 0:
		return _failure_result("unsupported_http_method", "不支持的 HTTP 方法：%s。" % method)

	var client := HTTPClient.new()
	var tls_options: TLSOptions = TLSOptions.client() if bool(parsed_url.get("use_tls", false)) else null
	var err := client.connect_to_host(str(parsed_url.get("host", "")), int(parsed_url.get("port", 80)), tls_options)
	if err != OK:
		client.close()
		return _failure_result("http_connect_failed", "无法连接后端。", {
			"godot_error": err
		})

	var timeout_at := Time.get_ticks_msec() + int(maxf(request_timeout_seconds, 0.1) * 1000.0)
	var connect_result := _wait_for_http_connect(client, timeout_at)
	if not bool(connect_result.get("ok", false)):
		client.close()
		return connect_result

	var body := ""
	var headers := PackedStringArray([
		"User-Agent: ThisIsNotMyWar-Godot/0.1",
		"Accept: application/json"
	])
	if method.to_upper() != "GET":
		body = JSON.stringify(payload)
		headers.append("Content-Type: application/json; charset=utf-8")

	var request_path := _build_request_path(str(parsed_url.get("path_prefix", "")), endpoint)
	err = client.request(http_method, request_path, headers, body)
	if err != OK:
		client.close()
		return _failure_result("http_request_failed", "无法发起 HTTP 请求。", {
			"godot_error": err
		})

	var request_result := _wait_for_http_response(client, timeout_at)
	if not bool(request_result.get("ok", false)):
		client.close()
		return request_result

	var response_code := client.get_response_code()
	var response_body_result := _read_http_response_body(client, timeout_at)
	client.close()
	if not bool(response_body_result.get("ok", false)):
		return response_body_result

	var body_text := str(response_body_result.get("body_text", ""))
	return {
		"ok": true,
		"response_code": response_code,
		"body_text": body_text
	}


func _wait_for_http_connect(client: HTTPClient, timeout_at: int) -> Dictionary:
	while client.get_status() == HTTPClient.STATUS_RESOLVING or client.get_status() == HTTPClient.STATUS_CONNECTING:
		var err := client.poll()
		if err != OK:
			return _failure_result("http_connect_failed", "连接后端时发生错误。", {
				"godot_error": err
			})
		if Time.get_ticks_msec() >= timeout_at:
			return _failure_result("http_timeout", "连接后端超时。")
		OS.delay_msec(HTTP_POLL_DELAY_MSEC)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return _failure_result("http_connect_failed", "无法连接后端。", {
			"http_status": client.get_status()
		})
	return {"ok": true}


func _wait_for_http_response(client: HTTPClient, timeout_at: int) -> Dictionary:
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		var err := client.poll()
		if err != OK:
			return _failure_result("http_request_failed", "等待后端响应时发生错误。", {
				"godot_error": err
			})
		if Time.get_ticks_msec() >= timeout_at:
			return _failure_result("http_timeout", "等待后端响应超时。")
		OS.delay_msec(HTTP_POLL_DELAY_MSEC)

	if client.get_status() != HTTPClient.STATUS_BODY and client.get_status() != HTTPClient.STATUS_CONNECTED:
		return _failure_result("http_request_failed", "后端响应状态异常。", {
			"http_status": client.get_status()
		})
	if not client.has_response():
		return _failure_result("http_empty_response", "后端没有返回 HTTP 响应。")
	return {"ok": true}


func _read_http_response_body(client: HTTPClient, timeout_at: int) -> Dictionary:
	var response_body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		var err := client.poll()
		if err != OK:
			return _failure_result("http_body_read_failed", "读取后端响应体时发生错误。", {
				"godot_error": err
			})
		if Time.get_ticks_msec() >= timeout_at:
			return _failure_result("http_timeout", "读取后端响应体超时。")

		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(HTTP_POLL_DELAY_MSEC)
		else:
			response_body.append_array(chunk)
	return {
		"ok": true,
		"body_text": response_body.get_string_from_utf8()
	}


func _parse_backend_url() -> Dictionary:
	var clean_url := get_backend_base_url()
	var scheme := "http"
	var remainder := clean_url
	var scheme_index := clean_url.find("://")
	if scheme_index >= 0:
		scheme = clean_url.substr(0, scheme_index).to_lower()
		remainder = clean_url.substr(scheme_index + 3)
	if scheme != "http" and scheme != "https":
		return _failure_result("invalid_backend_url", "后端地址只支持 http 或 https。", {
			"backend_base_url": clean_url
		})

	var slash_index := remainder.find("/")
	var host_port := remainder
	var path_prefix := ""
	if slash_index >= 0:
		host_port = remainder.substr(0, slash_index)
		path_prefix = remainder.substr(slash_index)
	if host_port.is_empty():
		return _failure_result("invalid_backend_url", "后端地址缺少主机名。", {
			"backend_base_url": clean_url
		})

	var host := host_port
	var port := 443 if scheme == "https" else 80
	var colon_index := host_port.rfind(":")
	if colon_index > 0:
		var port_text := host_port.substr(colon_index + 1)
		if port_text.is_valid_int():
			host = host_port.substr(0, colon_index)
			port = int(port_text)

	return {
		"ok": true,
		"scheme": scheme,
		"use_tls": scheme == "https",
		"host": host,
		"port": port,
		"path_prefix": path_prefix
	}


func _build_request_path(path_prefix: String, endpoint: String) -> String:
	var clean_prefix := path_prefix.trim_suffix("/")
	var clean_endpoint := endpoint
	if not clean_endpoint.begins_with("/"):
		clean_endpoint = "/%s" % clean_endpoint
	return "%s%s" % [clean_prefix, clean_endpoint]


func _to_http_method(method: String) -> int:
	match method.to_upper():
		"GET":
			return HTTPClient.METHOD_GET
		"POST":
			return HTTPClient.METHOD_POST
		"PUT":
			return HTTPClient.METHOD_PUT
		"DELETE":
			return HTTPClient.METHOD_DELETE
		"PATCH":
			return HTTPClient.METHOD_PATCH
		_:
			return -1


func _register_time_slowdown(request_id: String) -> void:
	if request_id.is_empty():
		return
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null or not time_system.has_method("request_time_slowdown"):
		return
	_debug_last_slowdown_registered = true
	time_system.request_time_slowdown(request_id, dialogue_wait_scale, "llm_dialogue_wait")
	if not _pending_slowdown_request_ids.has(request_id):
		_pending_slowdown_request_ids.append(request_id)


func _release_time_slowdown(request_id: String) -> void:
	if request_id.is_empty():
		return
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system != null and time_system.has_method("release_time_slowdown"):
		time_system.release_time_slowdown(request_id)
	if _pending_slowdown_request_ids.has(request_id):
		_pending_slowdown_request_ids.erase(request_id)


func _emit_backend_status(status_text: String, ok: bool) -> void:
	_last_backend_status = status_text
	_last_backend_ok = ok
	backend_status_changed.emit(status_text, ok)


func _failure_result(error_code: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": false,
		"error_code": error_code,
		"message": message
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result


func _build_npc_setting(npc: Dictionary) -> Dictionary:
	return {
		"appearance": npc.get("appearance", ""),
		"background_story": npc.get("background_story", ""),
		"background_job": npc.get("background_job", ""),
		"personality": npc.get("personality", []),
		"desires": npc.get("desires", []),
		"fears": npc.get("fears", []),
		"boundaries": npc.get("boundaries", npc.get("bottom_lines", [])),
		"abilities": npc.get("abilities", {})
	}


func _build_npc_state_context(npc: Dictionary, npc_state: Dictionary) -> Dictionary:
	var max_hp := maxi(1, int(npc_state.get("max_hp", 100)))
	return {
		"hp": clampi(int(npc_state.get("hp", max_hp)), 0, max_hp),
		"max_hp": max_hp,
		"satiety": clampi(int(npc_state.get("satiety", 100)), 0, 100),
		"fatigue": clampi(int(npc_state.get("fatigue", 0)), 0, 100),
		"current_action": str(npc_state.get("current_action", "idle")),
		"behavior_mode": str(npc_state.get("behavior_mode", "work")),
		"combat_mode": str(npc_state.get("combat_mode", "")),
		"combat_strategy": npc_state.get("combat_strategy", {}),
		"morale_boost": npc_state.get("morale_boost", {}),
		"escape_intent": npc_state.get("escape_intent", {}),
		"current_location": str(npc_state.get("current_location", "plaza")),
		"current_location_name": str(npc_state.get("current_location_name", "广场")),
		"recruited": bool(npc.get("recruited", npc_state.get("recruited", false))),
		"unconscious": bool(npc_state.get("unconscious", false)),
		"escaped": bool(npc_state.get("escaped", false)),
		"equipment": npc.get("equipment", {}),
		"skills": npc.get("skills", {}),
		"stats": npc_state.get("stats", npc.get("stats", {})),
		"money": int(npc_state.get("money", 0))
	}


func _build_speaker_context(speaker_kind: String, speaker_npc_id: String, speaker_name: String, npc_system: Node) -> Dictionary:
	if speaker_kind != "npc":
		return {
			"speaker_id": GUARD_OFFICER_ID,
			"speaker_name": GUARD_OFFICER_NAME,
			"speaker_kind": "guard_officer",
			"appearance": DEFAULT_GUARD_APPEARANCE,
			"health_status": "",
			"state": {}
		}

	var speaker: Dictionary = npc_system.get_npc(speaker_npc_id)
	var state: Dictionary = npc_system.get_npc_state(speaker_npc_id)
	return {
		"speaker_id": speaker_npc_id,
		"speaker_name": speaker_name,
		"speaker_kind": "npc",
		"appearance": str(speaker.get("appearance", "")),
		"health_status": _describe_health_status(state),
		"state": _build_npc_state_context(speaker, state)
	}


func _build_short_memory_context(npc_id: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("get_npc_short_term_memory"):
		return {
			"experienced_events": [],
			"witnessed_events": []
		}

	var memory: Dictionary = memory_system.get_npc_short_term_memory(npc_id)
	return {
		"experienced_events": _events_to_summaries(memory.get("event_log", []), SHORT_MEMORY_EVENT_LIMIT),
		"witnessed_events": _events_to_summaries(memory.get("witness_log", []), SHORT_MEMORY_EVENT_LIMIT)
	}


func _build_long_memory_context(npc: Dictionary) -> Dictionary:
	return {
		"knowledge_graph": npc.get("knowledge_graph", {}),
		"diary": npc.get("diary", [])
	}


func _build_location_context(npc_state: Dictionary) -> Dictionary:
	var location_context: Dictionary = npc_state.get("location_context", {})
	if not location_context.is_empty():
		return location_context.duplicate(true)

	var location_id := str(npc_state.get("current_location", "plaza"))
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system != null and memory_system.has_method("get_location_snapshot"):
		return memory_system.get_location_snapshot(location_id)
	return {}


func _get_interaction_context_from_state(npc_state: Dictionary) -> String:
	var mode := str(npc_state.get("behavior_mode", ""))
	if WARTIME_DIALOGUE_CONTEXTS.has(mode):
		return mode
	var combat_mode := str(npc_state.get("combat_mode", ""))
	if WARTIME_DIALOGUE_CONTEXTS.has(combat_mode):
		return combat_mode
	return "work"


func _build_battlefield_context(npc_id: String, interaction_context: String) -> Dictionary:
	if not WARTIME_DIALOGUE_CONTEXTS.has(interaction_context):
		return {}
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system != null and combat_system.has_method("build_battlefield_context"):
		return combat_system.build_battlefield_context(npc_id, interaction_context)
	return {
		"target_npc_id": npc_id,
		"target_behavior_mode": interaction_context
	}


func _build_npc_context(npc_id: String, npc_system: Node) -> Dictionary:
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	return {
		"identity": {
			"npc_id": npc_id,
			"name": str(npc.get("name", npc_id)),
			"gender": npc.get("gender", null),
			"background_job": npc.get("background_job", null),
			"personality": npc.get("personality", []),
			"desires": npc.get("desires", []),
			"fears": npc.get("fears", []),
			"boundaries": npc.get("boundaries", npc.get("bottom_lines", []))
		},
		"state": _build_npc_state_context(npc, state),
		"current_order": npc_system.get_current_order(npc_id) if npc_system.has_method("get_current_order") else {},
		"short_term_memory": _build_short_memory_context(npc_id),
		"knowledge_graph": npc.get("knowledge_graph", {}),
		"location_context": _build_location_context(state),
		"plaza_context": _get_plaza_context()
	}


func _build_reflection_day_events(npc_id: String) -> Array:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("get_npc_short_term_memory"):
		return []
	var memory: Dictionary = memory_system.get_npc_short_term_memory(npc_id)
	var result: Array = []
	for raw_event in memory.get("event_log", []):
		if raw_event is Dictionary:
			var event_summary := _event_to_summary(raw_event)
			event_summary["memory_kind"] = "experienced"
			result.append(event_summary)
	for raw_event in memory.get("witness_log", []):
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


func _build_existing_diary_entries(npc: Dictionary) -> Array[String]:
	var entries: Array[String] = []
	var diary: Variant = npc.get("diary", [])
	if not diary is Array:
		return entries
	for raw_entry in diary:
		if raw_entry is Dictionary:
			var entry_text := str((raw_entry as Dictionary).get("entry", ""))
			if not entry_text.is_empty():
				entries.append(entry_text)
		else:
			var text := str(raw_entry)
			if not text.is_empty():
				entries.append(text)
	return entries


func debug_build_npc_context(npc_id: String, call_type: String = "debug") -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return {}
	var context := _build_npc_context(npc_id, npc_system)
	if not context.is_empty():
		_record_npc_context_injection(npc_id, call_type, context.get("current_order", {}), "")
	return context


func _record_npc_context_injection(npc_id: String, call_type: String, current_order: Dictionary, request_id: String, extra: Dictionary = {}) -> void:
	_last_npc_context_injection = {
		"npc_id": npc_id,
		"call_type": call_type,
		"request_id": request_id,
		"current_order": current_order.duplicate(true)
	}
	for key in extra.keys():
		_last_npc_context_injection[key] = extra[key]


func _events_to_summaries(raw_events: Variant, limit: int) -> Array:
	var summaries: Array = []
	if not raw_events is Array:
		return summaries
	var events: Array = raw_events
	var start := maxi(0, events.size() - limit)
	for index in range(start, events.size()):
		var raw_event: Variant = events[index]
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		summaries.append({
			"event_id": event.get("event_id", null),
			"type": str(event.get("type", "")),
			"summary": str(event.get("summary", "")),
			"importance": clampi(int(event.get("importance", 50)), 0, 100),
			"day": event.get("day", null),
			"time": event.get("time", null),
			"payload": event.get("payload", {})
		})
	return summaries


func _get_game_time_context() -> Dictionary:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return {
			"day": 1,
			"time": "06:00:00",
			"hour": 6
		}
	return {
		"day": maxi(1, int(game_state.current_day)),
		"time": "%02d:%02d:%02d" % [int(game_state.current_hour), int(game_state.current_minute), int(game_state.current_second)],
		"hour": clampi(int(game_state.current_hour), 0, 23)
	}


func _get_plaza_context() -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system != null and memory_system.has_method("get_location_snapshot"):
		return memory_system.get_location_snapshot("plaza")
	return {}


func _describe_health_status(state: Dictionary) -> String:
	if bool(state.get("unconscious", false)):
		return "昏迷"
	var hp := int(state.get("hp", 100))
	var max_hp := maxi(1, int(state.get("max_hp", 100)))
	if hp < max_hp:
		return "受伤"
	return "健康"


func _get_npc_name(npc_id: String) -> String:
	if npc_id.is_empty():
		return "未知 NPC"
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return npc_id
	var npc: Dictionary = npc_system.get_npc(npc_id)
	return str(npc.get("name", npc_id))


func _make_request_id(call_type: String) -> String:
	_request_counter += 1
	return "godot_%s_%d_%04d" % [call_type, Time.get_ticks_msec(), _request_counter]


func _parse_json_or_empty(text: String) -> Variant:
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return {}
	return parsed


func _normalize_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item)
			if not text.is_empty() and not result.has(text):
				result.append(text)
	elif value != null:
		var text := str(value)
		if not text.is_empty():
			result.append(text)
	return result
