extends Node

const NPCPromptProfile = preload("res://scripts/core/NPCPromptProfile.gd")

signal backend_status_changed(status_text: String, ok: bool)
signal dialogue_response_received(result: Dictionary)
signal dialogue_async_response_received(result: Dictionary)
signal dialogue_intent_revalidation_response_received(result: Dictionary)
signal dialogue_intent_revalidation_async_response_received(result: Dictionary)
signal plan_revision_judgement_response_received(result: Dictionary)
signal plan_revision_judgement_async_response_received(result: Dictionary)
signal dialogue_plan_revision_judgement_response_received(result: Dictionary)
signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)
signal daily_plan_response_received(result: Dictionary)
signal daily_plan_async_response_received(result: Dictionary)
signal plan_revision_response_received(result: Dictionary)
signal plan_revision_async_response_received(result: Dictionary)
signal battle_judgement_response_received(result: Dictionary)
signal battle_judgement_async_response_received(result: Dictionary)
signal daily_reflection_response_received(result: Dictionary)
signal daily_reflection_async_response_received(result: Dictionary)
signal game_epilogue_response_received(result: Dictionary)
signal game_epilogue_async_response_received(result: Dictionary)
signal llm_usage_response_received(result: Dictionary)

const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const CRAFTING_SYSTEM_PATH := "/root/Main/Systems/CraftingSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const DEFAULT_BACKEND_URL := "http://127.0.0.1:5000"
const GUARD_OFFICER_ID := "guard_officer"
const GUARD_OFFICER_NAME := "守备官"
const DEFAULT_GUARD_APPEARANCE := "驿站守备官，穿着磨旧的军官外套，带着边境军令。"
const HTTP_POLL_DELAY_MSEC := 10
const WARTIME_DIALOGUE_CONTEXTS: Array[String] = ["rally", "combat", "avoid_combat"]
const ESCAPE_INTERVENTION_DIALOGUE_KIND := "escape_intervention"
const NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD := 5
const STATION_CONTEXT_FILE := "station_context.json"
const SHORT_MEMORY_OMITTED_PAYLOAD_KEYS: Array[String] = [
	# Deterministic summary already carries these texts; retaining them would
	# duplicate whole transcripts, notices and plan explanations.
	"summary",
	"dialogue_text",
	"speaker_text",
	"reply_text",
	"notice",
	"current_notice",
	"reference_schedule",
	"schedule_advisory_note",
	# These are authoritative runtime/debug structures rather than memory facts
	# the model needs to choose or explain an action.
	"items",
	"location_snapshot",
	"building_snapshot",
	"building_external_states",
	"key_entities",
	"enemy_roster",
	"friendly_roster",
	"injured_npcs",
	"unconscious_npcs",
	"defeated_by_npc",
	"participant_npc_ids",
	"dialogue_id",
	"source_event_id",
	"session_completed",
	"ended_while_waiting",
	"completed_reply_count",
	"current_round",
	"max_rounds",
	"visibility",
	"player_actor_id",
	"actor_display_name",
	"order_revision"
]
const AGGREGATABLE_MEMORY_EVENT_TYPES: Array[String] = [
	"attack_made",
	"damage_taken",
	"building_damaged",
	"defense_device_triggered",
	"horse_damaged"
]
const MEMORY_AGGREGATION_DYNAMIC_DETAIL_KEYS: Array[String] = [
	"damage",
	"damage_after_defense",
	"hp_before",
	"hp_after",
	"defeated"
]
const MEMORY_AGGREGATION_SIGNATURE_FIELDS := {
	"attack_made": [
		"attacker_npc_id", "target_type", "target_enemy_id", "weapon_id", "weapon_name",
		"required_skill", "weapon_skill", "strength", "base_damage", "strength_multiplier",
		"raw_attack_power", "attack_speed_multiplier", "attack_interval", "target_defense"
	],
	"damage_taken": [
		"damage_source", "interaction_kind", "event_text", "attack_prompt",
		"raw_attack_power", "target_defense"
	],
	"building_damaged": ["building_id", "building_name", "damage_source"],
	"defense_device_triggered": [
		"deployment_id", "device_id", "device_name", "slot_id",
		"target_enemy_id", "target_enemy_name"
	],
	"horse_damaged": [
		"target_npc_id", "horse_id", "horse_name", "share_ratio", "enemy_id", "enemy_name"
	]
}
const BASIC_RESOURCE_RESERVE_IDS: Array[String] = [
	"grain",
	"meal",
	"wood",
	"stone",
	"iron"
]

@export var backend_base_url: String = DEFAULT_BACKEND_URL
@export var request_timeout_seconds: float = 2.0
@export var dialogue_wait_scale: float = -1.0

var _last_backend_ok := false
var _last_backend_status := "后端：未检查"
var _request_counter := 0
var _pending_slowdown_request_ids: Array[String] = []
var _debug_last_slowdown_registered := false
var _slowdown_audit_by_request: Dictionary = {}
var _last_slowdown_audit: Dictionary = {}
var _last_npc_context_injection: Dictionary = {}
var _station_context_template: Dictionary = {}
var _active_request_by_npc: Dictionary = {}
var _cancelled_request_ids: Dictionary = {}
var _async_request_threads: Dictionary = {}
var _transport_lifecycle_mutex := Mutex.new()
var _transport_cancelled_request_ids: Dictionary = {}
var _transport_shutdown_requested := false
var _last_async_shutdown_result: Dictionary = {}
var _cached_health_result: Dictionary = {}
var _cached_health_checked_msec := 0


func initialize() -> void:
	_station_context_template = _load_station_context_template()
	_emit_backend_status(_last_backend_status, _last_backend_ok)


func _ready() -> void:
	initialize()


func _exit_tree() -> void:
	_shutdown_async_requests("llm_bridge_exit")


func set_backend_base_url(url: String) -> void:
	var clean_url := url.strip_edges()
	if clean_url.is_empty():
		clean_url = DEFAULT_BACKEND_URL
	backend_base_url = clean_url.trim_suffix("/")
	_cached_health_result.clear()
	_cached_health_checked_msec = 0


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
	_cached_health_result = result.duplicate(true)
	_cached_health_checked_msec = Time.get_ticks_msec()
	if bool(result.get("ok", false)):
		var body: Dictionary = result.get("body", {})
		_emit_backend_status("后端：已连接 %s" % str(body.get("service", "ok")), true)
	else:
		_emit_backend_status("后端：未连接 %s" % str(result.get("message", "请求失败")), false)
	return result


func get_cached_health(max_age_msec: int = 5000) -> Dictionary:
	if (
		not _cached_health_result.is_empty()
		and Time.get_ticks_msec() - _cached_health_checked_msec <= maxi(0, max_age_msec)
	):
		return _cached_health_result.duplicate(true)
	return check_health()


func request_llm_usage() -> Dictionary:
	var result: Dictionary = _request_json("GET", "/debug/llm_usage", {}, false, "")
	llm_usage_response_received.emit(result.duplicate(true))
	return result


func request_llm_usage_async() -> Dictionary:
	if _is_transport_shutdown_requested():
		return _async_shutdown_failure()
	var request_id := _make_request_id("llm_usage")
	var thread := Thread.new()
	_async_request_threads[request_id] = {
		"thread": thread,
		"npc_id": "",
		"request_id": request_id,
		"call_type": "llm_usage"
	}
	var err := thread.start(
		Callable(self, "_thread_request_json").bind(
			"GET",
			"/debug/llm_usage",
			{},
			request_id,
			request_timeout_seconds
		)
	)
	if err != OK:
		_async_request_threads.erase(request_id)
		return _failure_result("thread_start_failed", "无法启动 LLM 用量查询线程。", {
			"request_id": request_id,
			"error": err
		})
	return {
		"ok": true,
		"pending": true,
		"request_id": request_id
	}


func request_npc_dialogue(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
	var payload := build_npc_dialogue_payload(npc_id, speaker_text, options)
	if payload.is_empty():
		var failed := _failure_result("payload_error", "无法构造 NPCDialogueRequest。")
		dialogue_response_received.emit(failed.duplicate(true))
		return failed

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("dialogue")))
	var should_slowdown := bool(payload.get("meta", {}).get("requires_time_slowdown", true))
	var result: Dictionary = _request_json("POST", "/npc/dialogue", payload, should_slowdown, request_id, {
		"npc_id": npc_id,
		"kind": "dialogue",
		"label": "正在思考",
		"cancellable": true
	}, 0.0)
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["dialogue"] = result.get("body", {})
	dialogue_response_received.emit(response.duplicate(true))
	return response


func request_npc_dialogue_async(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
	if _is_transport_shutdown_requested():
		return _async_shutdown_failure()
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
		_register_time_slowdown(request_id, "dialogue")

	var thread := Thread.new()
	var record := {
		"thread": thread,
		"npc_id": npc_id,
		"request_id": request_id,
		"call_type": "dialogue"
	}
	_async_request_threads[request_id] = record
	var err := thread.start(
		Callable(self, "_thread_request_json").bind(
			"POST",
			"/npc/dialogue",
			payload,
			request_id,
			0.0
		)
	)
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


func request_npc_dialogue_intent_revalidation(
	npc_id: String,
	plan_item: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var payload := build_dialogue_intent_revalidation_payload(npc_id, plan_item, options)
	if payload.is_empty():
		var failed := _failure_result(
			"payload_error",
			"无法构造 DialogueIntentRevalidationRequest。"
		)
		dialogue_intent_revalidation_response_received.emit(failed.duplicate(true))
		return failed
	var request_id := str(
		payload.get("meta", {}).get(
			"request_id",
			_make_request_id("dialogue_intent_revalidation")
		)
	)
	var should_slowdown := bool(
		payload.get("meta", {}).get("requires_time_slowdown", true)
	)
	var result: Dictionary = _request_json(
		"POST",
		"/npc/dialogue_intent_revalidation",
		payload,
		should_slowdown,
		request_id,
		{
			"npc_id": npc_id,
			"kind": "plan",
			"label": "正在复核对话意图",
			"cancellable": true
		},
		0.0
	)
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["dialogue_intent_revalidation"] = result.get("body", {})
	dialogue_intent_revalidation_response_received.emit(response.duplicate(true))
	return response


func request_npc_dialogue_intent_revalidation_async(
	npc_id: String,
	plan_item: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	if _is_transport_shutdown_requested():
		return _async_shutdown_failure()
	var payload := build_dialogue_intent_revalidation_payload(npc_id, plan_item, options)
	if payload.is_empty():
		return _failure_result(
			"payload_error",
			"无法构造 DialogueIntentRevalidationRequest。"
		)
	var request_id := str(
		payload.get("meta", {}).get(
			"request_id",
			_make_request_id("dialogue_intent_revalidation")
		)
	)
	_set_npc_llm_activity(npc_id, request_id, {
		"npc_id": npc_id,
		"kind": "plan",
		"label": "正在复核对话意图",
		"cancellable": true
	})
	if bool(payload.get("meta", {}).get("requires_time_slowdown", true)):
		_register_time_slowdown(request_id, "dialogue_intent_revalidation")
	var thread := Thread.new()
	_async_request_threads[request_id] = {
		"thread": thread,
		"npc_id": npc_id,
		"request_id": request_id,
		"call_type": "dialogue_intent_revalidation"
	}
	var err := thread.start(
		Callable(self, "_thread_request_json").bind(
			"POST",
			"/npc/dialogue_intent_revalidation",
			payload,
			request_id,
			0.0
		)
	)
	if err != OK:
		_async_request_threads.erase(request_id)
		_release_time_slowdown(request_id)
		_clear_npc_llm_activity(npc_id, request_id)
		_active_request_by_npc.erase(npc_id)
		return _failure_result(
			"thread_start_failed",
			"无法启动异步对话意图执行前复核请求。",
			{"godot_error": err, "request_id": request_id}
		)
	return {
		"ok": true,
		"pending": true,
		"npc_id": npc_id,
		"request_id": request_id
	}


func request_dialogue_plan_revision_judgement(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var request_options := options.duplicate(true)
	request_options["trigger_kind"] = "dialogue"
	return request_plan_revision_judgement(npc_id, request_options)


func request_plan_revision_judgement(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var payload := build_plan_revision_judgement_payload(npc_id, options)
	if payload.is_empty():
		var failed := _failure_result("payload_error", "无法构造 PlanRevisionJudgementRequest。")
		plan_revision_judgement_response_received.emit(failed.duplicate(true))
		dialogue_plan_revision_judgement_response_received.emit(failed.duplicate(true))
		return failed

	var request_id := str(payload.get("meta", {}).get(
		"request_id",
		_make_request_id("plan_revision_judgement")
	))
	var should_slowdown := bool(payload.get("meta", {}).get("requires_time_slowdown", true))
	var result: Dictionary = _request_json(
		"POST",
		"/npc/plan_revision_judgement",
		payload,
		should_slowdown,
		request_id,
		{
			"npc_id": npc_id,
			"kind": "plan",
			"label": "正在判断是否调整计划",
			"cancellable": true
		},
		0.0
	)
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["plan_revision_judgement"] = result.get("body", {})
		response["dialogue_plan_revision_judgement"] = result.get("body", {})
	plan_revision_judgement_response_received.emit(response.duplicate(true))
	dialogue_plan_revision_judgement_response_received.emit(response.duplicate(true))
	return response


func request_dialogue_plan_revision_judgement_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var request_options := options.duplicate(true)
	request_options["trigger_kind"] = "dialogue"
	return request_plan_revision_judgement_async(npc_id, request_options)


func request_plan_revision_judgement_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
	if _is_transport_shutdown_requested():
		return _async_shutdown_failure()
	var payload := build_plan_revision_judgement_payload(npc_id, options)
	if payload.is_empty():
		return _failure_result("payload_error", "无法构造 PlanRevisionJudgementRequest。")

	var request_id := str(payload.get("meta", {}).get(
		"request_id",
		_make_request_id("plan_revision_judgement")
	))
	_set_npc_llm_activity(npc_id, request_id, {
		"npc_id": npc_id,
		"kind": "plan",
		"label": "正在判断是否调整计划",
		"cancellable": true
	})
	if bool(payload.get("meta", {}).get("requires_time_slowdown", true)):
		_register_time_slowdown(request_id, "plan_revision_judgement")

	var thread := Thread.new()
	var record := {
		"thread": thread,
		"npc_id": npc_id,
		"request_id": request_id,
		"call_type": "plan_revision_judgement"
	}
	_async_request_threads[request_id] = record
	var err := thread.start(
		Callable(self, "_thread_request_json").bind(
			"POST",
			"/npc/plan_revision_judgement",
			payload,
			request_id,
			0.0
		)
	)
	if err != OK:
		_async_request_threads.erase(request_id)
		_release_time_slowdown(request_id)
		_clear_npc_llm_activity(npc_id, request_id)
		_active_request_by_npc.erase(npc_id)
		return _failure_result("thread_start_failed", "无法启动异步计划修改判别请求。", {
			"godot_error": err,
			"request_id": request_id
		})
	return {
		"ok": true,
		"pending": true,
		"npc_id": npc_id,
		"request_id": request_id
	}


func request_npc_daily_plan(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var payload := build_npc_daily_plan_payload(npc_id, options)
	if payload.is_empty():
		var failed := _failure_result("payload_error", "无法构造 DailyPlanRequest。")
		daily_plan_response_received.emit(failed.duplicate(true))
		return failed

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("plan_day")))
	var should_slowdown := bool(payload.get("meta", {}).get("requires_time_slowdown", true))
	var result: Dictionary = _request_json("POST", "/npc/plan_day", payload, should_slowdown, request_id, {
		"npc_id": npc_id,
		"kind": "plan",
		"label": "正在计划下一步行动",
		"cancellable": true
	}, 0.0)
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["daily_plan"] = result.get("body", {})
	daily_plan_response_received.emit(response.duplicate(true))
	return response


func request_npc_daily_plan_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
	if _is_transport_shutdown_requested():
		return _async_shutdown_failure()
	var payload := build_npc_daily_plan_payload(npc_id, options)
	if payload.is_empty():
		return _failure_result("payload_error", "无法构造 DailyPlanRequest。")

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("plan_day")))
	_set_npc_llm_activity(npc_id, request_id, {
		"npc_id": npc_id,
		"kind": "plan",
		"label": "正在后台制定日计划",
		"cancellable": true
	})
	if bool(payload.get("meta", {}).get("requires_time_slowdown", false)):
		_register_time_slowdown(request_id, "plan_day")

	var thread := Thread.new()
	var record := {
		"thread": thread,
		"npc_id": npc_id,
		"request_id": request_id,
		"call_type": "plan_day"
	}
	_async_request_threads[request_id] = record
	var err := thread.start(
		Callable(self, "_thread_request_json").bind(
			"POST",
			"/npc/plan_day",
			payload,
			request_id,
			0.0
		)
	)
	if err != OK:
		_async_request_threads.erase(request_id)
		_release_time_slowdown(request_id)
		_clear_npc_llm_activity(npc_id, request_id)
		_active_request_by_npc.erase(npc_id)
		return _failure_result("thread_start_failed", "无法启动异步每日计划请求。", {
			"godot_error": err,
			"request_id": request_id
		})
	return {
		"ok": true,
		"pending": true,
		"npc_id": npc_id,
		"request_id": request_id
	}


func request_npc_plan_revision(npc_id: String, options: Dictionary = {}) -> Dictionary:
	var payload := build_npc_plan_revision_payload(npc_id, options)
	if payload.is_empty():
		var failed := _failure_result("payload_error", "无法构造 PlanRevisionRequest。")
		plan_revision_response_received.emit(failed.duplicate(true))
		return failed

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("revise_plan")))
	var should_slowdown := bool(payload.get("meta", {}).get("requires_time_slowdown", true))
	var result: Dictionary = _request_json("POST", "/npc/revise_plan", payload, should_slowdown, request_id, {
		"npc_id": npc_id,
		"kind": "plan",
		"label": "正在重新制定计划",
		"cancellable": true
	}, 0.0)
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["plan_revision"] = result.get("body", {})
	plan_revision_response_received.emit(response.duplicate(true))
	return response


func request_npc_plan_revision_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
	if _is_transport_shutdown_requested():
		return _async_shutdown_failure()
	var payload := build_npc_plan_revision_payload(npc_id, options)
	if payload.is_empty():
		return _failure_result("payload_error", "无法构造 PlanRevisionRequest。")

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("revise_plan")))
	_set_npc_llm_activity(npc_id, request_id, {
		"npc_id": npc_id,
		"kind": "plan",
		"label": "正在重新制定计划",
		"cancellable": true
	})
	if bool(payload.get("meta", {}).get("requires_time_slowdown", true)):
		_register_time_slowdown(request_id, "revise_plan")

	var thread := Thread.new()
	var record := {
		"thread": thread,
		"npc_id": npc_id,
		"request_id": request_id,
		"call_type": "revise_plan"
	}
	_async_request_threads[request_id] = record
	var err := thread.start(
		Callable(self, "_thread_request_json").bind(
			"POST",
			"/npc/revise_plan",
			payload,
			request_id,
			0.0
		)
	)
	if err != OK:
		_async_request_threads.erase(request_id)
		_release_time_slowdown(request_id)
		_clear_npc_llm_activity(npc_id, request_id)
		_active_request_by_npc.erase(npc_id)
		return _failure_result("thread_start_failed", "无法启动异步计划修订请求。", {
			"godot_error": err,
			"request_id": request_id
		})
	return {
		"ok": true,
		"pending": true,
		"npc_id": npc_id,
		"request_id": request_id
	}


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
	}, 0.0)
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["battle_judgement"] = result.get("body", {})
	battle_judgement_response_received.emit(response.duplicate(true))
	return response


func request_npc_battle_judgement_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
	if _is_transport_shutdown_requested():
		return _async_shutdown_failure()
	var payload := build_npc_battle_judgement_payload(npc_id, options)
	if payload.is_empty():
		return _failure_result("payload_error", "无法构造 BattleJudgementRequest。")

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("battle_judgement")))
	_set_npc_llm_activity(npc_id, request_id, {
		"npc_id": npc_id,
		"kind": "battle_judgement",
		"label": "正在压住恐惧",
		"cancellable": false,
		"reason": str(options.get("reason", "low_hp"))
	})
	if bool(payload.get("meta", {}).get("requires_time_slowdown", true)):
		_register_time_slowdown(request_id, "battle_judgement")

	var thread := Thread.new()
	_async_request_threads[request_id] = {
		"thread": thread,
		"npc_id": npc_id,
		"request_id": request_id,
		"call_type": "battle_judgement"
	}
	var err := thread.start(
		Callable(self, "_thread_request_json").bind(
			"POST",
			"/npc/battle_judgement",
			payload,
			request_id,
			0.0
		)
	)
	if err != OK:
		_async_request_threads.erase(request_id)
		_release_time_slowdown(request_id)
		_clear_npc_llm_activity(npc_id, request_id)
		_active_request_by_npc.erase(npc_id)
		return _failure_result("thread_start_failed", "无法启动异步战时心理判定请求。", {
			"godot_error": err,
			"request_id": request_id
		})
	return {
		"ok": true,
		"pending": true,
		"npc_id": npc_id,
		"request_id": request_id
	}


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
	}, 0.0)
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["daily_reflection"] = result.get("body", {})
	daily_reflection_response_received.emit(response.duplicate(true))
	return response


func request_npc_daily_reflection_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
	if _is_transport_shutdown_requested():
		return _async_shutdown_failure()
	var payload := build_npc_daily_reflection_payload(npc_id, options)
	if payload.is_empty():
		return _failure_result("payload_error", "无法构造 DailyReflectionRequest。")

	var request_id := str(payload.get("meta", {}).get("request_id", _make_request_id("daily_reflection")))
	_set_npc_llm_activity(npc_id, request_id, {
		"npc_id": npc_id,
		"kind": "first_sleep_summary",
		"label": "正在熟睡",
		"cancellable": false
	})
	if bool(payload.get("meta", {}).get("requires_time_slowdown", true)):
		_register_time_slowdown(request_id, "daily_reflection")

	var thread := Thread.new()
	_async_request_threads[request_id] = {
		"thread": thread,
		"npc_id": npc_id,
		"request_id": request_id,
		"call_type": "daily_reflection"
	}
	var err := thread.start(
		Callable(self, "_thread_request_json").bind(
			"POST",
			"/npc/daily_reflection",
			payload,
			request_id,
			0.0
		)
	)
	if err != OK:
		_async_request_threads.erase(request_id)
		_release_time_slowdown(request_id)
		_clear_npc_llm_activity(npc_id, request_id)
		_active_request_by_npc.erase(npc_id)
		return _failure_result("thread_start_failed", "无法启动异步首次睡眠总结请求。", {
			"godot_error": err,
			"request_id": request_id
		})
	return {
		"ok": true,
		"pending": true,
		"npc_id": npc_id,
		"request_id": request_id
	}


func request_game_epilogue_async(payload: Dictionary) -> Dictionary:
	if _is_transport_shutdown_requested():
		return _async_shutdown_failure()
	if payload.is_empty() or str(payload.get("settlement_id", "")).is_empty():
		return _failure_result("payload_error", "无法构造 GameEpilogueRequest。")
	var request_payload := payload.duplicate(true)
	var meta: Dictionary = request_payload.get("meta", {}) if request_payload.get("meta", {}) is Dictionary else {}
	var request_id := str(meta.get("request_id", _make_request_id("game_epilogue")))
	meta["request_id"] = request_id
	meta["call_type"] = "game_epilogue"
	meta["source"] = "godot"
	meta["requires_time_slowdown"] = false
	request_payload["meta"] = meta
	var thread := Thread.new()
	_async_request_threads[request_id] = {
		"thread": thread,
		"npc_id": "",
		"request_id": request_id,
		"call_type": "game_epilogue"
	}
	var err := thread.start(
		Callable(self, "_thread_request_json").bind(
			"POST",
			"/game/epilogue",
			request_payload,
			request_id,
			0.0
		)
	)
	if err != OK:
		_async_request_threads.erase(request_id)
		return _failure_result("thread_start_failed", "无法启动异步群像结局请求。", {
			"godot_error": err,
			"request_id": request_id
		})
	return {
		"ok": true,
		"pending": true,
		"request_id": request_id,
		"settlement_id": str(request_payload.get("settlement_id", ""))
	}


func debug_check_health() -> Dictionary:
	return check_health()


func debug_request_llm_usage() -> Dictionary:
	return request_llm_usage()


func debug_request_llm_usage_async() -> Dictionary:
	return request_llm_usage_async()


func debug_get_llm_runtime_snapshot() -> Dictionary:
	var time_snapshot: Dictionary = {}
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system != null and time_system.has_method("get_time_scale_snapshot"):
		time_snapshot = time_system.get_time_scale_snapshot()
	return {
		"backend": get_last_backend_status(),
		"pending_slowdown_count": get_pending_slowdown_count(),
		"pending_slowdown_request_ids": _pending_slowdown_request_ids.duplicate(true),
		"active_slowdown_audit": _slowdown_audit_by_request.duplicate(true),
		"last_slowdown_audit": _last_slowdown_audit.duplicate(true),
		"active_request_count": _active_request_by_npc.size(),
		"active_requests_by_npc": _active_request_by_npc.duplicate(true),
		"async_request_count": _async_request_threads.size(),
		"async_request_ids": _async_request_threads.keys(),
		"transport_shutdown_requested": _is_transport_shutdown_requested(),
		"last_async_shutdown_result": _last_async_shutdown_result.duplicate(true),
		"time_scale": time_snapshot,
		"last_time_scale_reason": str(time_snapshot.get("last_time_scale_reason", "")),
		"last_context_injection": get_last_npc_context_injection()
	}


func debug_request_dialogue(
	npc_id: String,
	speaker_text: String = "守备官需要你帮忙守住这里。",
	is_recruitment_request: bool = false,
	visibility: String = "private",
	is_morale_encouragement_request: bool = false,
	interaction_context: String = "",
	is_combat_strategy_request: bool = false,
	combat_strategy_context: Dictionary = {},
	is_work_encouragement_request: bool = false
) -> Dictionary:
	var options := {
		"is_recruitment_request": is_recruitment_request,
		"is_morale_encouragement_request": is_morale_encouragement_request,
		"is_combat_strategy_request": is_combat_strategy_request,
		"is_work_encouragement_request": is_work_encouragement_request,
		"dialogue_state": {
			"visibility": visibility
		}
	}
	if is_combat_strategy_request and not combat_strategy_context.is_empty():
		options["combat_strategy_context"] = combat_strategy_context.duplicate(true)
	if not interaction_context.is_empty():
		options["interaction_context"] = interaction_context
	return request_npc_dialogue(npc_id, speaker_text, options)


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
	return request_npc_daily_plan(npc_id)


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
		_request_transport_cancel(request_id)
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


func cancel_llm_request(request_id: String, reason: String = "cancelled") -> Dictionary:
	if request_id.is_empty():
		return _failure_result("empty_request_id", "LLM request ID 为空。")
	var record: Dictionary = _async_request_threads.get(request_id, {})
	if record.is_empty():
		return {"ok": true, "cancelled": false, "reason": "request_not_active"}
	var npc_id := str(record.get("npc_id", ""))
	_cancelled_request_ids[request_id] = reason
	_request_transport_cancel(request_id)
	_release_time_slowdown(request_id)
	if not npc_id.is_empty():
		_clear_npc_llm_activity(npc_id, request_id)
	return {
		"ok": true,
		"cancelled": true,
		"npc_id": npc_id,
		"request_id": request_id,
		"reason": reason
	}


func _shutdown_async_requests(reason: String = "llm_bridge_shutdown") -> Dictionary:
	if _is_transport_shutdown_requested() and _async_request_threads.is_empty():
		return _last_async_shutdown_result.duplicate(true)

	var started_at_msec := Time.get_ticks_msec()
	var request_ids: Array = _async_request_threads.keys()
	_request_transport_shutdown()

	for raw_request_id in request_ids:
		var request_id := str(raw_request_id)
		var record: Dictionary = _async_request_threads.get(request_id, {})
		var npc_id := str(record.get("npc_id", ""))
		_cancelled_request_ids[request_id] = reason
		_request_transport_cancel(request_id)
		_release_time_slowdown(request_id)
		if not npc_id.is_empty():
			_clear_npc_llm_activity(npc_id, request_id)

	for pending_request_id in _pending_slowdown_request_ids.duplicate():
		_release_time_slowdown(str(pending_request_id))

	var joined_count := 0
	for raw_request_id in request_ids:
		var request_id := str(raw_request_id)
		var record: Dictionary = _async_request_threads.get(request_id, {})
		var thread := record.get("thread", null) as Thread
		if thread != null and thread.is_started():
			thread.wait_to_finish()
			joined_count += 1

	for raw_npc_id in _active_request_by_npc.keys():
		var npc_id := str(raw_npc_id)
		var active: Dictionary = _active_request_by_npc.get(npc_id, {})
		_clear_npc_llm_activity(npc_id, str(active.get("request_id", "")))

	_async_request_threads.clear()
	_active_request_by_npc.clear()
	_cancelled_request_ids.clear()
	_pending_slowdown_request_ids.clear()
	_slowdown_audit_by_request.clear()
	_last_async_shutdown_result = {
		"ok": true,
		"reason": reason,
		"cancelled_request_count": request_ids.size(),
		"joined_thread_count": joined_count,
		"elapsed_msec": Time.get_ticks_msec() - started_at_msec
	}
	return _last_async_shutdown_result.duplicate(true)


func _request_transport_shutdown() -> void:
	_transport_lifecycle_mutex.lock()
	_transport_shutdown_requested = true
	_transport_lifecycle_mutex.unlock()


func _is_transport_shutdown_requested() -> bool:
	_transport_lifecycle_mutex.lock()
	var requested := _transport_shutdown_requested
	_transport_lifecycle_mutex.unlock()
	return requested


func _request_transport_cancel(request_id: String) -> void:
	if request_id.is_empty():
		return
	_transport_lifecycle_mutex.lock()
	_transport_cancelled_request_ids[request_id] = true
	_transport_lifecycle_mutex.unlock()


func _clear_transport_cancel(request_id: String) -> void:
	if request_id.is_empty():
		return
	_transport_lifecycle_mutex.lock()
	_transport_cancelled_request_ids.erase(request_id)
	_transport_lifecycle_mutex.unlock()


func _should_cancel_transport(request_id: String) -> bool:
	_transport_lifecycle_mutex.lock()
	var cancelled := (
		_transport_shutdown_requested
		or (not request_id.is_empty() and _transport_cancelled_request_ids.has(request_id))
	)
	_transport_lifecycle_mutex.unlock()
	return cancelled


func _transport_cancelled_result(request_id: String) -> Dictionary:
	return _failure_result("request_cancelled", "LLM 请求已取消。", {
		"request_id": request_id,
		"cancelled": true
	})


func _async_shutdown_failure() -> Dictionary:
	return _failure_result(
		"llm_bridge_shutting_down",
		"LLMBridge 正在退出，不能启动新的异步请求。"
	)


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

	var dialogue_kind := str(options.get("dialogue_kind", "player_npc"))
	var dialogue_phase := str(options.get("dialogue_phase", "conversation"))
	if not ["conversation", "invitation"].has(dialogue_phase):
		dialogue_phase = "conversation"
	var current_round := 0 if dialogue_kind == "npc_npc" and dialogue_phase == "invitation" else maxi(1, int(options.get("current_round", 1)))
	var max_rounds := 0 if dialogue_kind == "npc_npc" else maxi(1, int(options.get("max_rounds", 1)))
	var location_id := str(npc_state.get("current_location", "plaza"))
	var location_name := str(npc_state.get("current_location_name", "广场"))
	var dialogue_state: Dictionary = options.get("dialogue_state", {})
	var soft_round_threshold := maxi(1, int(options.get(
		"soft_round_threshold",
		dialogue_state.get("soft_round_threshold", NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD)
	)))
	var soft_round_guidance := str(options.get(
		"soft_round_guidance",
		dialogue_state.get("soft_round_guidance", "")
	)).strip_edges()
	if dialogue_kind == "npc_npc" and soft_round_guidance.is_empty():
		soft_round_guidance = (
			"soft_round_threshold 只是偏晚阶段的收尾保险，不是最低轮数、目标轮数或继续理由，绝不能为了等到阈值而续聊。"
			+ "每轮若不能推进 conversation_history 中已经存在的未决紧急或必要事项，只能确认、复述或改写已有内容，必须在本轮用至多一句简短收尾并设置 should_end_dialogue=true；对方已经完整回答或双方已经达成一致时也必须结束。"
			+ "不得为了延长对话自行制造新话题、新任务、新问题、额外帮助或后续安排。"
			+ "current_round 超过 %d（即第 %d 轮起）且没有尚未说清的紧急或必要事项时必须告别结束；只有本轮确实能推进必要新内容时才可继续。"
		) % [soft_round_threshold, soft_round_threshold + 1]
	var visibility := str(dialogue_state.get("visibility", options.get("visibility", "private")))
	if not ["private", "local_public"].has(visibility):
		visibility = "private"
	var interaction_context := str(options.get("interaction_context", _get_interaction_context_from_state(npc_state)))
	if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND:
		interaction_context = ESCAPE_INTERVENTION_DIALOGUE_KIND
	elif not WARTIME_DIALOGUE_CONTEXTS.has(interaction_context):
		interaction_context = "work"
	if WARTIME_DIALOGUE_CONTEXTS.has(interaction_context):
		visibility = "local_public"
	var participants := _normalize_string_array(dialogue_state.get("participants", [npc_id, GUARD_OFFICER_ID if speaker_kind == "guard_officer" else speaker_npc_id]))

	var request_id := str(options.get("request_id", _make_request_id("dialogue")))
	var current_order: Dictionary = npc_system.get_current_order(npc_id) if npc_system.has_method("get_current_order") else {}
	var interrupted_activity_context: Dictionary = (
		options.get("interrupted_activity_context", {})
		if options.get("interrupted_activity_context", {}) is Dictionary
		else {}
	)
	var dialogue_truth: Dictionary = _build_dialogue_authoritative_truth(
		npc_id,
		npc,
		npc_state,
		interrupted_activity_context,
		npc_system
	)
	var payload := {
		"meta": {
			"request_id": request_id,
			"call_type": "dialogue",
			"source": "godot",
			"requires_time_slowdown": bool(options.get("requires_time_slowdown", true)),
			"related_event_id": options.get("related_event_id", null)
		},
		"game_time": _get_game_time_context(),
		"station_context": _build_station_context(npc_system),
		"dialogue_kind": dialogue_kind,
		"dialogue_phase": dialogue_phase,
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"npc_setting": _build_npc_setting(npc),
		"speaker_name": speaker_name,
		"speaker_text": speaker_text,
		"speaker_context": _build_speaker_context(speaker_kind, speaker_npc_id, speaker_name, npc_system),
		"interaction_context": interaction_context,
		"battlefield_context": _build_battlefield_context(npc_id, interaction_context),
		"is_recruitment_request": bool(options.get("is_recruitment_request", false)),
		"is_morale_encouragement_request": bool(options.get("is_morale_encouragement_request", false)),
		"is_combat_strategy_request": bool(options.get("is_combat_strategy_request", false)),
		"is_work_encouragement_request": bool(options.get("is_work_encouragement_request", false)),
		"current_round": current_round,
		"max_rounds": max_rounds,
		"soft_round_threshold": soft_round_threshold,
		"soft_round_guidance": soft_round_guidance,
		"npc_state": _build_npc_state_context(npc, npc_state),
		"activity_truth": dialogue_truth.get("activity_truth", {}),
		"equipment_truth": dialogue_truth.get("equipment_truth", {}),
		"training_truth": dialogue_truth.get("training_truth", {}),
		"current_order": current_order.duplicate(true),
		"dialogue_state": {
			"visibility": visibility,
			"location_id": str(dialogue_state.get("location_id", location_id)),
			"location_name": str(dialogue_state.get("location_name", location_name)),
			"current_round": current_round,
			"max_rounds": max_rounds,
			"soft_round_threshold": soft_round_threshold,
			"soft_round_guidance": soft_round_guidance,
			"participants": participants
		},
		"short_memory": _build_short_memory_context(npc_id),
		"long_memory": _build_long_memory_context(npc),
		"location_context": _build_location_context(npc_state),
		"conversation_history": options.get("conversation_history", []),
		# 对话只参考计划层的同一候选目录，不在这里维护第二份行为清单。
		"allowed_actions": _build_allowed_action_candidates(npc_id, true),
		"constraints": options.get("constraints", [])
	}
	if bool(payload.get("is_combat_strategy_request", false)):
		var combat_strategy_context: Dictionary = options.get("combat_strategy_context", {}) if options.get("combat_strategy_context", {}) is Dictionary else {}
		if not combat_strategy_context.is_empty():
			payload["combat_strategy_context"] = combat_strategy_context.duplicate(true)
	if not interrupted_activity_context.is_empty():
		payload["interrupted_activity_context"] = interrupted_activity_context.duplicate(true)
	if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND:
		payload["escape_intervention_round"] = clampi(int(options.get("escape_intervention_round", current_round)), 1, 5)

	# Dialogue has one canonical target long-memory field at payload.long_memory.
	# Keep target_npc for the shared participant shape without duplicating the
	# full seeded graph in the same provider request.
	payload["target_npc"] = _build_npc_context(npc_id, npc_system, false)
	_record_npc_context_injection(npc_id, "dialogue", current_order, request_id, {
		"interaction_context": interaction_context,
		"has_battlefield_context": WARTIME_DIALOGUE_CONTEXTS.has(interaction_context),
		"has_interrupted_activity_context": not interrupted_activity_context.is_empty()
	})
	return payload


func build_dialogue_intent_revalidation_payload(
	npc_id: String,
	plan_item: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		push_warning(
			"LLMBridge cannot build dialogue intent revalidation payload because NPCSystem is missing."
		)
		return {}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}
	var action_id := str(plan_item.get("action_id", ""))
	var dialogue_goal := str(plan_item.get("dialogue_goal", "")).strip_edges()
	if not ["talk_to_npc", "seek_guard_officer"].has(action_id) or dialogue_goal.is_empty():
		return {}
	var current_plan: Array = (
		(options.get("current_plan", []) as Array).duplicate(true)
		if options.get("current_plan", []) is Array
		else []
	)
	if current_plan.is_empty() and npc_system.has_method("get_npc_plan"):
		current_plan = npc_system.get_npc_plan(npc_id)
	var current_plan_schema := _plan_items_to_schema(current_plan)
	if current_plan_schema.size() != 24:
		return {}
	var game_time := _get_game_time_context()
	var plan_item_schema := _plan_item_to_schema(plan_item)
	if int(plan_item_schema.get("hour", -1)) != int(game_time.get("hour", -2)):
		return {}
	var npc_context := _build_npc_context(npc_id, npc_system)
	if npc_context.is_empty():
		return {}
	var request_id := str(
		options.get(
			"request_id",
			_make_request_id("dialogue_intent_revalidation")
		)
	)
	var created_day := maxi(
		1,
		int(
			plan_item.get(
				"intent_created_day",
				options.get("intent_created_day", game_time.get("day", 1))
			)
		)
	)
	var created_time := str(
		plan_item.get(
			"intent_created_time",
			options.get("intent_created_time", game_time.get("time", "00:00:00"))
		)
	)
	if created_time.is_empty():
		created_time = str(game_time.get("time", "00:00:00"))
	var created_source := str(
		plan_item.get(
			"intent_source",
			options.get("intent_source", plan_item.get("source", "unknown"))
		)
	).strip_edges()
	if created_source.is_empty():
		created_source = "unknown"
	var payload := {
		"meta": {
			"request_id": request_id,
			"call_type": "dialogue_intent_revalidation",
			"source": "godot",
			"requires_time_slowdown": bool(
				options.get("requires_time_slowdown", true)
			),
			"related_event_id": options.get("related_event_id", null)
		},
		"game_time": game_time,
		"station_context": _build_station_context(npc_system),
		"npc": npc_context,
		"planned_intent": {
			"created_day": created_day,
			"created_time": created_time,
			"source": created_source,
			"plan_item": plan_item_schema
		},
		"current_plan": current_plan_schema,
		"allowed_actions": _build_allowed_action_candidates(npc_id, false),
		"current_building_states": _build_building_state_context(),
		"current_resource_states": _build_resource_state_context()
	}
	_record_npc_context_injection(
		npc_id,
		"dialogue_intent_revalidation",
		npc_context.get("current_order", {}),
		request_id,
		{
			"intent_created_day": created_day,
			"intent_created_time": created_time,
			"intent_source": created_source,
			"planned_action_id": action_id,
			"planned_dialogue_goal": dialogue_goal
		}
	)
	return payload


func build_dialogue_plan_revision_judgement_payload(
	npc_id: String,
	options: Dictionary = {}
) -> Dictionary:
	var request_options := options.duplicate(true)
	request_options["trigger_kind"] = "dialogue"
	return build_plan_revision_judgement_payload(npc_id, request_options)


func build_plan_revision_judgement_payload(
	npc_id: String,
	options: Dictionary = {}
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		push_warning("LLMBridge cannot build plan revision judgement payload because NPCSystem is missing.")
		return {}
	if npc_system.get_npc(npc_id).is_empty():
		return {}

	var trigger_kind := str(options.get("trigger_kind", "dialogue"))
	if not ["dialogue", "action_failure"].has(trigger_kind):
		return {}
	var dialogue_history: Array = (
		options.get("dialogue_history", []).duplicate(true)
		if options.get("dialogue_history", []) is Array
		else []
	)
	if trigger_kind == "dialogue" and dialogue_history.is_empty():
		return {}
	if trigger_kind == "action_failure" and not dialogue_history.is_empty():
		return {}
	var current_plan: Array = []
	if options.get("current_plan", []) is Array:
		current_plan = (options.get("current_plan", []) as Array).duplicate(true)
	elif npc_system.has_method("get_npc_plan"):
		current_plan = npc_system.get_npc_plan(npc_id)
	var current_plan_schema := _plan_items_to_schema(current_plan)
	if current_plan_schema.size() != 24:
		return {}

	var npc: Dictionary = npc_system.get_npc(npc_id)
	var npc_context := _build_npc_context(npc_id, npc_system)
	if npc_context.is_empty():
		return {}
	var game_time := _get_game_time_context()
	var current_hour := clampi(int(game_time.get("hour", 0)), 0, 23)
	var required_revision_hours := _normalize_revision_hours(
		options.get("required_revision_hours", []),
		current_hour
	)
	var failed_plan_item: Dictionary = (
		(options.get("failed_plan_item", {}) as Dictionary).duplicate(true)
		if options.get("failed_plan_item", {}) is Dictionary
		else {}
	)
	if trigger_kind == "action_failure" and failed_plan_item.is_empty():
		failed_plan_item = _find_plan_item_for_hour(current_plan, current_hour)
	var failed_plan_item_schema: Variant = null
	if not failed_plan_item.is_empty():
		failed_plan_item_schema = _plan_item_to_schema(failed_plan_item)
	if trigger_kind == "action_failure" and failed_plan_item_schema == null:
		return {}
	var failure_summary := str(options.get("failure_summary", "")).strip_edges()
	if trigger_kind == "action_failure" and failure_summary.is_empty():
		return {}
	var failure_context: Dictionary = (
		(options.get("failure_context", {}) as Dictionary).duplicate(true)
		if options.get("failure_context", {}) is Dictionary
		else {}
	)
	var current_work_phase_count := _count_schema_work_phases(current_plan_schema)
	var minimum_work_phase_count := 6
	var failed_item_was_work := (
		failed_plan_item_schema is Dictionary
		and _is_schema_work_phase(failed_plan_item_schema as Dictionary)
	)
	var request_id := str(options.get(
		"request_id",
		_make_request_id("plan_revision_judgement")
	))
	var dialogue_kind := str(options.get("dialogue_kind", "player_npc"))
	if not ["player_npc", "npc_npc", ESCAPE_INTERVENTION_DIALOGUE_KIND].has(dialogue_kind):
		dialogue_kind = "player_npc"
	var payload := {
		"meta": {
			"request_id": request_id,
			"call_type": "plan_revision_judgement",
			"source": "godot",
			"requires_time_slowdown": bool(options.get("requires_time_slowdown", true)),
			"related_event_id": options.get("related_event_id", null)
		},
		"game_time": game_time,
		"station_context": _build_station_context(npc_system),
		"npc_id": npc_id,
		"npc_name": str(npc.get("name", npc_id)),
		"npc": npc_context,
		"trigger_kind": trigger_kind,
		"dialogue_kind": dialogue_kind,
		"dialogue_history": dialogue_history,
		"dialogue_end_reason": str(options.get("dialogue_end_reason", "dialogue_completed")),
		"dialogue_context": (
			(options.get("dialogue_context", {}) as Dictionary).duplicate(true)
			if options.get("dialogue_context", {}) is Dictionary
			else {}
		),
		"failed_plan_item": failed_plan_item_schema,
		"failure_type": _normalize_plan_failure_type(str(options.get("failure_type", "unknown"))),
		"failure_summary": failure_summary,
		"failure_context": failure_context,
		"required_revision_hours": required_revision_hours,
		"allowed_actions": _build_allowed_action_candidates(npc_id, false),
		"current_building_states": _build_building_state_context(),
		"current_resource_states": _build_resource_state_context(),
		"current_work_phase_count": current_work_phase_count,
		"minimum_work_phase_count": minimum_work_phase_count,
		"replacement_work_phase_required_if_non_work": (
			failed_item_was_work and current_work_phase_count <= minimum_work_phase_count
		),
		"current_plan": current_plan_schema
	}
	_record_npc_context_injection(
		npc_id,
		"plan_revision_judgement",
		npc_context.get("current_order", {}),
		request_id,
		{
			"trigger_kind": trigger_kind,
			"dialogue_kind": dialogue_kind,
			"dialogue_turn_count": dialogue_history.size(),
			"required_revision_hours": required_revision_hours.duplicate(),
			"character_context_included": true
		}
	)
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
		"station_context": _build_station_context(npc_system),
		"npc": npc_context,
		"allowed_actions": _build_allowed_action_candidates(npc_id, true),
		"current_building_states": _build_building_state_context(),
		"current_resource_states": _build_resource_state_context()
	}
	# The system prompt already owns the default planning contract. Keep this field
	# only as an explicit extension point for a caller that adds genuinely new rules.
	if options.has("planning_rules") and options.get("planning_rules", []) is Array:
		var custom_planning_rules: Array = options.get("planning_rules", [])
		if not custom_planning_rules.is_empty():
			payload["planning_rules"] = custom_planning_rules.duplicate(true)
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
	var current_hour := clampi(int(game_time.get("hour", 0)), 0, 23)
	var revision_hours := _normalize_revision_hours(
		options.get("revision_hours", [current_hour]),
		current_hour
	)
	if revision_hours.is_empty():
		return {}
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
	var failure_context: Dictionary = options.get("failure_context", {}) if options.get("failure_context", {}) is Dictionary else {}
	if failure_context.is_empty():
		var current_state: Dictionary = npc_system.get_npc_state(npc_id)
		failure_context = current_state.get("last_action_failure_context", {}) if current_state.get("last_action_failure_context", {}) is Dictionary else {}

	var current_plan_schema := _plan_items_to_schema(current_plan)
	var failed_plan_item_schema := _plan_item_to_schema(failed_plan_item)
	var current_work_phase_count := _count_schema_work_phases(current_plan_schema)
	var failed_item_was_work := _is_schema_work_phase(failed_plan_item_schema)
	var minimum_work_phase_count := 6
	var past_work_phase_count := 0
	for raw_item in current_plan_schema:
		if (
			raw_item is Dictionary
			and int((raw_item as Dictionary).get("hour", -1)) < current_hour
			and _is_schema_work_phase(raw_item as Dictionary)
		):
			past_work_phase_count += 1
	var minimum_remaining_work_phase_count := maxi(0, minimum_work_phase_count - past_work_phase_count)
	var payload := {
		"meta": {
			"request_id": request_id,
			"call_type": "revise_plan",
			"source": "godot",
			"requires_time_slowdown": bool(options.get("requires_time_slowdown", true)),
			"related_event_id": options.get("related_event_id", null)
		},
		"game_time": game_time,
		"station_context": _build_station_context(npc_system),
		"npc": npc_context,
		"current_plan": current_plan_schema,
		"failed_plan_item": failed_plan_item_schema,
		"revision_scope": "selected_hours",
		"revision_hours": revision_hours,
		"current_work_phase_count": current_work_phase_count,
		"minimum_work_phase_count": minimum_work_phase_count,
		"past_work_phase_count": past_work_phase_count,
		"minimum_remaining_work_phase_count": minimum_remaining_work_phase_count,
		"replacement_work_phase_required_if_non_work": (
			failed_item_was_work and current_work_phase_count <= minimum_work_phase_count
		),
		"failure_type": failure_type,
		"failure_summary": failure_summary,
		"failure_context": failure_context.duplicate(true),
		# 即时修订只提供当前可执行候选；日计划才允许把仍在并行制定计划的 NPC
		# 作为稍后可接近的对话目标。
		"allowed_actions": _build_allowed_action_candidates(npc_id, false),
		"current_building_states": _build_building_state_context(),
		"current_resource_states": _build_resource_state_context()
	}
	_record_npc_context_injection(npc_id, "revise_plan", npc_context.get("current_order", {}), request_id, {
		"revision_scope": "selected_hours",
		"revision_hours": revision_hours.duplicate()
	})
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
		"station_context": _build_station_context(npc_system),
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
			"time": str(options.get("trigger_time", game_time.get("time", "00:00:00"))),
			"hour": int(options.get("trigger_hour", game_time.get("hour", 0)))
		},
		"station_context": _build_station_context(npc_system),
		"npc": npc_context,
		"day_events": _compact_reflection_day_events(
			options.get("day_events", _build_reflection_day_events(npc_id))
		),
		"summary_window": (
			options.get("summary_window", {}).duplicate(true)
			if options.get("summary_window", {}) is Dictionary
			else {}
		),
		"reflection_period": (
			options.get("reflection_period", {}).duplicate(true)
			if options.get("reflection_period", {}) is Dictionary
			else {}
		),
		"existing_diary_entries": _build_existing_diary_entries(npc)
	}
	_record_npc_context_injection(npc_id, "daily_reflection", npc_context.get("current_order", {}), request_id)
	return payload


func _thread_request_json(
	method: String,
	endpoint: String,
	payload: Dictionary,
	request_id: String,
	timeout_seconds: float = -1.0
) -> void:
	var transport_result := _send_http_request(
		method,
		endpoint,
		payload,
		timeout_seconds,
		request_id
	)
	var result := _parse_transport_json_result(transport_result)
	result["request_id"] = request_id
	if _is_transport_shutdown_requested():
		return
	call_deferred("_complete_async_request", request_id, result)


func _complete_async_request(request_id: String, result: Dictionary) -> void:
	var record: Dictionary = _async_request_threads.get(request_id, {})
	if record.is_empty():
		return
	var thread := record.get("thread", null) as Thread
	if thread != null:
		thread.wait_to_finish()
	_async_request_threads.erase(request_id)
	_clear_transport_cancel(request_id)
	var npc_id := str(record.get("npc_id", ""))
	var call_type := str(record.get("call_type", "dialogue"))
	_release_time_slowdown(request_id)
	if _was_request_cancelled(request_id):
		if not npc_id.is_empty():
			_clear_npc_llm_activity(npc_id, request_id)
		var cancelled := _failure_result("request_cancelled", "LLM 请求已被玩家对话打断。", {
			"request_id": request_id,
			"cancelled": true
		})
		cancelled["npc_id"] = npc_id
		_emit_async_response(call_type, cancelled)
		return
	if not npc_id.is_empty():
		_clear_npc_llm_activity(npc_id, request_id)
	var response := result.duplicate(true)
	response["npc_id"] = npc_id
	if call_type == "llm_usage":
		_emit_async_response(call_type, response)
		return
	if bool(result.get("ok", false)):
		match call_type:
			"dialogue_intent_revalidation":
				response["dialogue_intent_revalidation"] = result.get("body", {})
			"plan_revision_judgement":
				response["plan_revision_judgement"] = result.get("body", {})
				response["dialogue_plan_revision_judgement"] = result.get("body", {})
			"dialogue_plan_revision_judgement":
				response["dialogue_plan_revision_judgement"] = result.get("body", {})
			"plan_day":
				response["daily_plan"] = result.get("body", {})
			"revise_plan":
				response["plan_revision"] = result.get("body", {})
			"battle_judgement":
				response["battle_judgement"] = result.get("body", {})
			"daily_reflection":
				response["daily_reflection"] = result.get("body", {})
			"game_epilogue":
				response["game_epilogue"] = result.get("body", {})
			_:
				response["dialogue"] = result.get("body", {})
	_emit_async_response(call_type, response)


func _emit_async_response(call_type: String, response: Dictionary) -> void:
	if call_type == "llm_usage":
		llm_usage_response_received.emit(response.duplicate(true))
		return
	if call_type == "dialogue_intent_revalidation":
		dialogue_intent_revalidation_response_received.emit(response.duplicate(true))
		dialogue_intent_revalidation_async_response_received.emit(
			response.duplicate(true)
		)
		return
	if call_type == "plan_revision_judgement":
		plan_revision_judgement_response_received.emit(response.duplicate(true))
		plan_revision_judgement_async_response_received.emit(response.duplicate(true))
		# Compatibility signal for T0049-only observers. Runtime orchestration listens
		# to the generic signal so one response is never processed twice.
		dialogue_plan_revision_judgement_response_received.emit(response.duplicate(true))
		dialogue_plan_revision_judgement_async_response_received.emit(response.duplicate(true))
		return
	if call_type == "dialogue_plan_revision_judgement":
		dialogue_plan_revision_judgement_response_received.emit(response.duplicate(true))
		dialogue_plan_revision_judgement_async_response_received.emit(response.duplicate(true))
		return
	if call_type == "plan_day":
		daily_plan_response_received.emit(response.duplicate(true))
		daily_plan_async_response_received.emit(response.duplicate(true))
		return
	if call_type == "revise_plan":
		plan_revision_response_received.emit(response.duplicate(true))
		plan_revision_async_response_received.emit(response.duplicate(true))
		return
	if call_type == "battle_judgement":
		battle_judgement_response_received.emit(response.duplicate(true))
		battle_judgement_async_response_received.emit(response.duplicate(true))
		return
	if call_type == "daily_reflection":
		daily_reflection_response_received.emit(response.duplicate(true))
		daily_reflection_async_response_received.emit(response.duplicate(true))
		return
	if call_type == "game_epilogue":
		game_epilogue_response_received.emit(response.duplicate(true))
		game_epilogue_async_response_received.emit(response.duplicate(true))
		return
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
	activity_options: Dictionary = {},
	timeout_seconds: float = -1.0
) -> Dictionary:
	var activity_npc_id := str(activity_options.get("npc_id", ""))
	var activity_request_id := request_id if not request_id.is_empty() else _make_request_id("llm")
	if not activity_npc_id.is_empty():
		_set_npc_llm_activity(activity_npc_id, activity_request_id, activity_options)
	var active_slowdown_id := ""
	if use_slowdown:
		active_slowdown_id = activity_request_id
		var call_type := str(payload.get("meta", {}).get("call_type", "llm"))
		_register_time_slowdown(active_slowdown_id, call_type)

	var transport_result := _send_http_request(
		method,
		endpoint,
		payload,
		timeout_seconds,
		activity_request_id
	)
	_release_time_slowdown(active_slowdown_id)
	_clear_transport_cancel(activity_request_id)
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
	if (location_id == null or str(location_id).is_empty()) and target.has("location_id"):
		location_id = str(target.get("location_id", ""))
	if (location_id == null or str(location_id).is_empty()) and target.has("building_id"):
		location_id = str(target.get("building_id", ""))
	var target_id: Variant = item.get("target_id", null)
	if target_id == null:
		for key in ["target_id", "target_npc_id", "building_id", "location_id"]:
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
		"reason": str(item.get("reason", "")),
		"dialogue_goal": str(item.get("dialogue_goal", ""))
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


func _count_schema_work_phases(plan: Array) -> int:
	var count := 0
	for raw_item in plan:
		if raw_item is Dictionary and _is_schema_work_phase(raw_item as Dictionary):
			count += 1
	return count


func _is_schema_work_phase(item: Dictionary) -> bool:
	var action_id := str(item.get("action_id", ""))
	if action_id == "assist_upgrade":
		return true
	var action := _get_action_definition(action_id)
	if str(action.get("type", "")) in ["work", "clinic_doctor", "training_instructor"]:
		return true
	return action.is_empty() and str(item.get("action_kind", "")) == "work"


func _build_allowed_action_candidates(
	npc_id: String = "",
	allow_transient_planning_targets: bool = true
) -> Array:
	var result: Array = []
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var building_system := get_node_or_null("/root/Main/Systems/BuildingSystem")
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("get_action_ids"):
		return result
	for action_id in action_system.get_action_ids():
		var action: Dictionary = action_system.get_action(str(action_id))
		if not bool(action.get("plan_selectable", true)):
			continue
		var action_type := str(action.get("type", ""))
		if not str(action.get("requires_target", "")).is_empty():
			continue
		if action_type == "system" and str(action_id) != "escaping_station":
			continue
		if not _is_static_plan_action_available_for_npc(
			str(action_id),
			action,
			npc_id,
			npc_system,
			action_system,
			allow_transient_planning_targets
		):
			continue
		var required_location_id := str(action.get("location_required", ""))
		if not required_location_id.is_empty() and required_location_id != "plaza":
			if building_system == null:
				continue
			var required_building: Dictionary = building_system.get_building(required_location_id)
			if required_building.is_empty() or int(required_building.get("hp", 0)) <= 0:
				continue
		var eligibility: Dictionary = {
			"eligible": true,
			"available_now": true,
			"unavailable_reason": "",
			"required_ability": str(action.get("required_ability", "")),
			"eligibility_hint": str(action.get("eligibility_hint", ""))
		}
		if action_system.has_method("get_action_eligibility") and not npc_id.is_empty():
			eligibility = action_system.get_action_eligibility(npc_id, str(action_id))
		result.append({
			"action_id": str(action_id),
			"name": str(action.get("name", action_id)),
			"action_kind": _infer_plan_action_kind(str(action_id), action),
			"location_id": null if str(action.get("location_required", "")).is_empty() else str(action.get("location_required", "")),
			"target_id": null,
			"target_kind": null,
			"target_name": null,
			"tags": [action_type],
			"context": {
				"duration_seconds": float(action.get("duration_seconds", 0.0)),
				"description": str(action.get("description", "")),
				"skill": str(action.get("skill", "")),
				"workstation_type": str(action.get("workstation_type", "")),
				"eligible": bool(eligibility.get("eligible", true)),
				"available_now": bool(eligibility.get("available_now", true)),
				"unavailable_reason": str(eligibility.get("unavailable_reason", "")),
				"required_ability": str(eligibility.get("required_ability", action.get("required_ability", ""))),
				"eligibility_hint": str(eligibility.get("eligibility_hint", action.get("eligibility_hint", ""))),
				"required_active_action_id": str(eligibility.get("required_active_action_id", action.get("required_active_action_id", ""))),
				"blocked_by_active_action_id": str(eligibility.get("blocked_by_active_action_id", action.get("blocked_by_active_action_id", ""))),
				"authority": "CombatSystem" if str(action_id) == "escaping_station" else "ActionSystem"
			}
		})

	if npc_system != null and not npc_id.is_empty():
		var can_offer_immediate_dialogue := true
		if not allow_transient_planning_targets:
			var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
			if (
				dialog_system != null
				and dialog_system.has_method("has_active_dialogue")
				and bool(dialog_system.has_active_dialogue())
			):
				can_offer_immediate_dialogue = false
			if (
				action_system.has_method("is_npc_dialogue_reserved")
				and bool(action_system.is_npc_dialogue_reserved(npc_id))
			):
				can_offer_immediate_dialogue = false
		for raw_target_id in npc_system.get_npc_ids():
			var target_npc_id := str(raw_target_id)
			if not can_offer_immediate_dialogue:
				break
			if (
				target_npc_id == npc_id
				or (
					not allow_transient_planning_targets
					and action_system.has_method("is_npc_dialogue_reserved")
					and bool(action_system.is_npc_dialogue_reserved(target_npc_id))
				)
				or not _is_available_npc_dialogue_candidate(
				target_npc_id,
				npc_system,
				allow_transient_planning_targets
				)
			):
				continue
			var target_npc: Dictionary = npc_system.get_npc(target_npc_id)
			var target_state: Dictionary = npc_system.get_npc_state(target_npc_id)
			var target_location_id := str(target_state.get("current_location", "plaza"))
			if not _is_available_plan_location(target_location_id, building_system):
				continue
			var target_name := str(target_npc.get("name", target_npc_id))
			result.append({
				"action_id": "talk_to_npc",
				"name": "找%s对话" % target_name,
				"action_kind": "chat",
				# This action chooses a person, not a destination. ActionSystem resolves
				# and tracks the target's real location only when execution starts.
				"target_id": target_npc_id,
				"target_kind": "npc",
				"target_name": target_name,
				"tags": ["npc_dialogue", "chat", "target_npc"],
				"context": {}
			})

		var heal_action: Dictionary = action_system.get_action("assist_heal")
		for raw_target_id in npc_system.get_npc_ids():
			var target_npc_id := str(raw_target_id)
			if target_npc_id == npc_id:
				continue
			var target_state: Dictionary = npc_system.get_npc_state(target_npc_id)
			if not bool(target_state.get("unconscious", false)) or bool(target_state.get("escaped", false)):
				continue
			if action_system.has_method("get_healing_helpers_for_target") and action_system.get_healing_helpers_for_target(target_npc_id).size() >= int(heal_action.get("target_limit_per_target", 2)):
				continue
			var target_npc: Dictionary = npc_system.get_npc(target_npc_id)
			var target_name := str(target_npc.get("name", target_npc_id))
			result.append({
				"action_id": "assist_heal",
				"name": "协助治疗%s" % target_name,
				"action_kind": "assist_heal",
				"location_id": str(target_state.get("current_location", "plaza")),
				"target_id": target_npc_id,
				"target_kind": "unconscious_npc",
				"target_name": target_name,
				"tags": ["targeted_heal", "assist_heal", "target_npc"],
				"context": {"hp": int(target_state.get("hp", 0)), "max_hp": int(target_state.get("max_hp", 100))}
			})

	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if building_system != null and building_system.has_method("get_building_ids"):
		result.append({
			"action_id": "visit_location",
			"name": "前往并停留在广场",
			"action_kind": "visit",
			"location_id": "plaza",
			"target_id": "plaza",
			"target_kind": "location",
			"target_name": "广场",
			"tags": ["visit", "move", "target_location"],
			"context": {}
		})
		for raw_building_id in building_system.get_building_ids():
			var building_id := str(raw_building_id)
			var building: Dictionary = building_system.get_building(building_id)
			if building.is_empty() or int(building.get("hp", 0)) <= 0:
				continue
			var building_name := str(building.get("name", building_id))
			if (
				memory_system != null
				and memory_system.has_method("is_enterable_location")
				and memory_system.is_enterable_location(building_id)
				and bool(building.get("is_enterable", true))
			):
				result.append({
					"action_id": "visit_location",
					"name": "前往并停留在%s" % building_name,
					"action_kind": "visit",
					"location_id": building_id,
					"target_id": building_id,
					"target_kind": "location",
					"target_name": building_name,
					"tags": ["visit", "move", "target_location"],
					"context": {"condition": str(building.get("condition", "normal"))}
				})
			if building_system.has_method("is_repair_in_progress") and building_system.is_repair_in_progress(building_id):
				result.append({
					"action_id": "assist_repair",
					"name": "协助修复%s" % building_name,
					"action_kind": "assist_repair",
					"location_id": "plaza",
					"target_id": building_id,
					"target_kind": "building",
					"target_name": building_name,
					"tags": ["assist_repair", "engineering"],
					"context": {"building_hp": int(building.get("hp", 0)), "building_max_hp": int(building.get("max_hp", 0))}
				})
			if building_system.has_method("is_upgrade_in_progress") and building_system.is_upgrade_in_progress(building_id):
				result.append({
					"action_id": "assist_upgrade",
					"name": "协助升级%s" % building_name,
					"action_kind": "assist_upgrade",
					"location_id": "plaza",
					"target_id": building_id,
					"target_kind": "building",
					"target_name": building_name,
					"tags": ["work", "assist_upgrade", "engineering"],
					"context": {
						"building_level": int(building.get("level", 1)),
						"eligible": true,
						"available_now": true,
						"execution_location": "plaza",
						"requires_building_entry": false,
						"counts_as_work_phase": true,
						"effect": "在建筑外协助正在进行的升级，加快工程进度"
					}
				})
	result.append({
		"action_id": "idle",
		"name": "等待",
		"action_kind": "idle",
		"location_id": null,
		"target_id": null,
		"target_kind": null,
		"target_name": null,
		"tags": ["idle"],
		"context": {}
	})
	return result


func _is_static_plan_action_available_for_npc(
	action_id: String,
	_action: Dictionary,
	npc_id: String,
	npc_system: Node,
	action_system: Node,
	allow_transient_planning_targets: bool
) -> bool:
	if npc_id.is_empty() or npc_system == null:
		return true
	if (
		action_system.has_method("is_action_environment_available")
		and not action_system.is_action_environment_available(action_id)
	):
		return false
	var npc: Dictionary = npc_system.get_npc(npc_id)
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	match action_id:
		"drink_wine":
			return int(state.get("wine", 0)) >= 1
		"receive_clinic_treatment":
			return int(state.get("hp", 0)) < maxi(1, int(state.get("max_hp", 100)))
		"work_training_instructor":
			return _npc_has_trainable_equipment(npc)
		"receive_weapon_training":
			if not _npc_has_trainable_equipment(npc):
				return false
			# A day plan may coordinate an instructor that has not started yet. A failure
			# revision's immediate action must be executable against the live state.
			if allow_transient_planning_targets:
				return _has_potential_training_instructor(npc_id, npc_system)
			return _has_active_training_instructor(npc_id, npc_system, action_system)
	return true


func _npc_has_trainable_equipment(npc: Dictionary) -> bool:
	var equipment: Dictionary = npc.get("equipment", {}) if npc.get("equipment", {}) is Dictionary else {}
	for slot_id in ["main_weapon", "mount"]:
		var item: Dictionary = equipment.get(slot_id, {}) if equipment.get(slot_id, {}) is Dictionary else {}
		if not str(item.get("required_skill", "")).strip_edges().is_empty():
			return true
	return false


func _build_dialogue_authoritative_truth(
	npc_id: String,
	npc: Dictionary,
	npc_state: Dictionary,
	interrupted_activity_context: Dictionary,
	npc_system: Node
) -> Dictionary:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var action_id := str(npc_state.get("current_action", "idle")).strip_edges()
	var action_phase := ""
	var activity_before: Dictionary = (
		interrupted_activity_context.get("activity_before_interruption", {})
		if interrupted_activity_context.get("activity_before_interruption", {}) is Dictionary
		else {}
	)
	if not activity_before.is_empty():
		action_id = str(activity_before.get("action_id", action_id)).strip_edges()
		action_phase = str(activity_before.get("phase", "")).strip_edges()
	elif action_system != null and action_system.has_method("get_runtime_action_snapshot"):
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if not runtime.is_empty():
			action_id = str(runtime.get("action_id", action_id)).strip_edges()
			action_phase = str(runtime.get("phase", "")).strip_edges()
	if action_id.is_empty():
		action_id = "idle"
	var is_training := (
		["receive_weapon_training", "work_training_instructor"].has(action_id)
		and ["active", "external_active"].has(action_phase)
	)

	var equipment: Dictionary = (
		npc.get("equipment", {})
		if npc.get("equipment", {}) is Dictionary
		else {}
	)
	var main_weapon_id: Variant = _compact_equipment_truth_id(equipment.get("main_weapon", {}))
	var mount_id: Variant = _compact_equipment_truth_id(equipment.get("mount", {}))
	var has_trainable_equipment := _npc_has_trainable_equipment(npc)

	var training_eligible := false
	var training_blocker: Variant = null
	if not has_trainable_equipment:
		training_blocker = "no_trainable_equipment"
	elif not _has_active_training_instructor(npc_id, npc_system, action_system):
		training_blocker = "no_active_instructor"
	elif action_system == null or not action_system.has_method("get_action_eligibility"):
		training_blocker = "training_unavailable"
	else:
		var eligibility: Dictionary = action_system.get_action_eligibility(
			npc_id,
			"receive_weapon_training"
		)
		training_eligible = bool(eligibility.get("available_now", false))
		if not training_eligible:
			training_blocker = "training_unavailable"

	return {
		"activity_truth": {
			"action_id": action_id,
			"is_training": is_training
		},
		"equipment_truth": {
			"main_weapon": main_weapon_id,
			"mount": mount_id,
			"has_trainable_equipment": has_trainable_equipment
		},
		"training_truth": {
			"eligible": training_eligible,
			"blocker": training_blocker
		}
	}


func _compact_equipment_truth_id(raw_item: Variant) -> Variant:
	if not raw_item is Dictionary or (raw_item as Dictionary).is_empty():
		return null
	for field in ["id", "horse_id", "name"]:
		var item_id := str((raw_item as Dictionary).get(field, "")).strip_edges()
		if not item_id.is_empty():
			return item_id
	return null


func _has_active_training_instructor(
	student_npc_id: String,
	npc_system: Node,
	action_system: Node
) -> bool:
	if npc_system == null or action_system == null:
		return false
	for raw_npc_id in npc_system.get_npc_ids():
		var candidate_id := str(raw_npc_id)
		if candidate_id == student_npc_id:
			continue
		if action_system.has_method("get_runtime_action_snapshot"):
			var runtime: Dictionary = action_system.get_runtime_action_snapshot(candidate_id)
			if (
				str(runtime.get("phase", "")) == "active"
				and str(runtime.get("action_id", "")) == "work_training_instructor"
			):
				return true
		elif action_system.has_method("get_active_action_id"):
			if str(action_system.get_active_action_id(candidate_id)) == "work_training_instructor":
				return true
	return false


func _has_potential_training_instructor(student_npc_id: String, npc_system: Node) -> bool:
	if npc_system == null:
		return false
	for raw_npc_id in npc_system.get_npc_ids():
		var candidate_id := str(raw_npc_id)
		if candidate_id == student_npc_id or not npc_system.can_npc_act(candidate_id):
			continue
		if npc_system.has_method("get_npc_behavior_mode_snapshot"):
			var mode: Dictionary = npc_system.get_npc_behavior_mode_snapshot(candidate_id)
			if str(mode.get("behavior_mode", "work")) != "work":
				continue
		if _npc_has_trainable_equipment(npc_system.get_npc(candidate_id)):
			return true
	return false


func _is_available_npc_dialogue_candidate(
	npc_id: String,
	npc_system: Node,
	allow_transient_planning_targets: bool
) -> bool:
	if npc_system == null or npc_system.get_npc(npc_id).is_empty() or not npc_system.can_npc_act(npc_id):
		return false
	if npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(npc_id):
		return false
	if npc_system.has_method("get_npc_behavior_mode_snapshot"):
		var mode: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
		if str(mode.get("behavior_mode", "work")) != "work":
			return false
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if not allow_transient_planning_targets:
		if str(state.get("current_action", "")) == "planning_day":
			return false
		if npc_system.has_method("get_npc_llm_activity"):
			var activity: Dictionary = npc_system.get_npc_llm_activity(npc_id)
			if bool(activity.get("active", false)):
				return false
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system != null and dialog_system.has_method("is_npc_in_dialogue") and dialog_system.is_npc_in_dialogue(npc_id):
		return false
	return (
		str(state.get("active_dialogue_id", "")).is_empty()
		and not ["talk_to_npc", "proactive_talk"].has(str(state.get("current_action", "")))
	)


func _is_available_plan_location(location_id: String, building_system: Node) -> bool:
	if location_id == "plaza":
		return true
	if location_id.is_empty() or building_system == null:
		return false
	var building: Dictionary = building_system.get_building(location_id)
	return not building.is_empty() and int(building.get("hp", 0)) > 0


func _build_resource_state_context() -> Dictionary:
	var result := {}
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	if resource_system == null or not resource_system.has_method("get_resource"):
		return result
	for resource_id in BASIC_RESOURCE_RESERVE_IDS:
		result[resource_id] = int(resource_system.get_resource(resource_id))
	return result


func _build_building_state_context() -> Dictionary:
	var result := {}
	var building_system := get_node_or_null("/root/Main/Systems/BuildingSystem")
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building_ids"):
		return result
	for building_id in building_system.get_building_ids():
		var building: Dictionary = building_system.get_building(str(building_id))
		var repair_status: Dictionary = building.get("repair_status", {}) if building.get("repair_status", {}) is Dictionary else {}
		var upgrade_status: Dictionary = building.get("upgrade_status", {}) if building.get("upgrade_status", {}) is Dictionary else {}
		var workstations: Array = []
		for raw_workstation in building.get("workstations", []):
			if not raw_workstation is Dictionary:
				continue
			var workstation: Dictionary = raw_workstation
			var occupied_by := str(workstation.get("occupied_by", ""))
			if occupied_by == "<null>":
				occupied_by = ""
			var occupant: Dictionary = npc_system.get_npc(occupied_by) if npc_system != null and not occupied_by.is_empty() else {}
			var occupant_state: Dictionary = npc_system.get_npc_state(occupied_by) if npc_system != null and not occupied_by.is_empty() else {}
			workstations.append({
				"workstation_id": str(workstation.get("id", "")),
				"workstation_type": str(workstation.get("type", "")),
				"status": "free" if occupied_by.is_empty() else "occupied",
				"occupied_by": null if occupied_by.is_empty() else occupied_by,
				"occupied_by_name": null if occupied_by.is_empty() else str(occupant.get("name", occupied_by)),
				"occupied_by_action": null if occupied_by.is_empty() else str(occupant_state.get("current_action", ""))
			})
		var building_context := {
			"name": str(building.get("name", building_id)),
			"level": int(building.get("level", 1)),
			"hp": int(building.get("hp", 0)),
			"max_hp": int(building.get("max_hp", 0)),
			"is_repairing": (
				bool(building_system.is_repair_in_progress(str(building_id)))
				if building_system.has_method("is_repair_in_progress")
				else false
			),
			"is_upgrading": (
				bool(building_system.is_upgrade_in_progress(str(building_id)))
				if building_system.has_method("is_upgrade_in_progress")
				else false
			),
			"repair_job": _build_readable_building_job_context(repair_status),
			"upgrade_job": _build_readable_building_job_context(upgrade_status),
			"workstations": workstations
		}
		if (
			crafting_system != null
			and crafting_system.has_method("get_project_snapshot")
		):
			var project: Dictionary = crafting_system.get_project_snapshot(
				str(building_id)
			)
			if not project.is_empty():
				building_context["crafting_project"] = {
					"target_recipe_id": str(project.get("target_recipe_id", "")),
					"target_item_id": str(project.get("target_item_id", "")),
					"target_name": str(project.get("target_name", "")),
					"project_revision": int(project.get("project_revision", 0)),
					"completed_stages": int(project.get("completed_stages", 0)),
					"total_stages": int(project.get("total_stages", 0)),
					"current_stage_index": int(
						project.get("current_stage_index", 0)
					),
					"current_stage_id": str(
						project.get("current_stage_id", "")
					),
					"current_stage_name": str(
						project.get("current_stage_name", "")
					),
					"current_stage_cost": (
						(project.get("current_stage_cost", {}) as Dictionary)
							.duplicate(true)
						if project.get("current_stage_cost", {}) is Dictionary
						else {}
					),
					"stock_amount": int(project.get("stock_amount", 0))
				}
		result[str(building_id)] = building_context
	return result


func _build_readable_building_job_context(status: Dictionary) -> Dictionary:
	if status.is_empty():
		return {}
	return {
		"active": bool(status.get("active", true)),
		"total_duration": str(status.get("duration_text", "")),
		"remaining_time": str(status.get("remaining_text", "")),
		"progress_percent": int(round(float(status.get("progress", 0.0)) * 100.0)),
		"helper_count": int(status.get("helper_count", 0))
	}


func _infer_plan_action_kind(action_id: String, action: Dictionary) -> String:
	if action_id == "idle" or action_id.is_empty():
		return "idle"
	match str(action.get("type", "")):
		"work", "clinic_doctor":
			return "work"
		"eat":
			return "eat"
		"drink":
			return "drink"
		"sleep":
			return "sleep"
		"training_instructor", "training_student":
			return "train"
		"clinic_patient", "targeted_heal":
			return "assist_heal"
		"pray":
			return "pray"
		"npc_dialogue":
			return "chat"
		"visit":
			return "visit"
		"proactive_talk":
			return "seek_guard_officer"
		"system":
			if action_id == "escaping_station":
				return "escape"
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
		"target_unavailable", "workstation_occupied", "resource_insufficient", "dialogue_interrupted", "plan_item_superseded", "action_completed", "low_hp", "low_satiety", "high_fatigue", "combat_alarm", "order_changed", "dialogue_intent_cancelled", "dialogue_intent_revalidation_failed":
			return raw_type
		"clinic_patient_failed_no_doctor", "clinic_patient_failed_doctor_left", "training_student_failed_no_instructor", "training_student_failed_instructor_left":
			return "target_unavailable"
		"work_failed_no_workstation", "clinic_doctor_failed_no_workstation", "clinic_patient_failed_no_bed", "training_student_failed_no_workstation", "training_instructor_failed_no_workstation", "lead_mass_failed_no_workstation":
			return "workstation_occupied"
		"work_failed_no_resources", "work_failed_storage_capacity", "eat_failed_no_food", "drink_wine_failed_no_wine", "assist_heal_failed_no_money", "clinic_treatment_failed_no_money":
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


func _send_http_request(
	method: String,
	endpoint: String,
	payload: Dictionary,
	timeout_seconds: float = -1.0,
	request_id: String = ""
) -> Dictionary:
	if _should_cancel_transport(request_id):
		return _transport_cancelled_result(request_id)
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

	var connect_timeout_at := Time.get_ticks_msec() + int(maxf(request_timeout_seconds, 0.1) * 1000.0)
	var connect_result := _wait_for_http_connect(client, connect_timeout_at, request_id)
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

	var response_timeout_at := _make_optional_timeout_at(timeout_seconds)
	var request_result := _wait_for_http_response(client, response_timeout_at, request_id)
	if not bool(request_result.get("ok", false)):
		client.close()
		return request_result

	var response_code := client.get_response_code()
	var response_body_result := _read_http_response_body(client, response_timeout_at, request_id)
	client.close()
	if not bool(response_body_result.get("ok", false)):
		return response_body_result

	var body_text := str(response_body_result.get("body_text", ""))
	return {
		"ok": true,
		"response_code": response_code,
		"body_text": body_text
	}


func _wait_for_http_connect(
	client: HTTPClient,
	timeout_at: int,
	request_id: String = ""
) -> Dictionary:
	while client.get_status() == HTTPClient.STATUS_RESOLVING or client.get_status() == HTTPClient.STATUS_CONNECTING:
		if _should_cancel_transport(request_id):
			return _transport_cancelled_result(request_id)
		var err := client.poll()
		if err != OK:
			return _failure_result("http_connect_failed", "连接后端时发生错误。", {
				"godot_error": err
			})
		if _has_timed_out(timeout_at):
			return _failure_result("http_timeout", "连接后端超时。")
		OS.delay_msec(HTTP_POLL_DELAY_MSEC)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return _failure_result("http_connect_failed", "无法连接后端。", {
			"http_status": client.get_status()
		})
	return {"ok": true}


func _wait_for_http_response(
	client: HTTPClient,
	timeout_at: int,
	request_id: String = ""
) -> Dictionary:
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		if _should_cancel_transport(request_id):
			return _transport_cancelled_result(request_id)
		var err := client.poll()
		if err != OK:
			return _failure_result("http_request_failed", "等待后端响应时发生错误。", {
				"godot_error": err
			})
		if _has_timed_out(timeout_at):
			return _failure_result("http_timeout", "等待后端响应超时。")
		OS.delay_msec(HTTP_POLL_DELAY_MSEC)

	if client.get_status() != HTTPClient.STATUS_BODY and client.get_status() != HTTPClient.STATUS_CONNECTED:
		return _failure_result("http_request_failed", "后端响应状态异常。", {
			"http_status": client.get_status()
		})
	if not client.has_response():
		return _failure_result("http_empty_response", "后端没有返回 HTTP 响应。")
	return {"ok": true}


func _read_http_response_body(
	client: HTTPClient,
	timeout_at: int,
	request_id: String = ""
) -> Dictionary:
	var response_body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		if _should_cancel_transport(request_id):
			return _transport_cancelled_result(request_id)
		var err := client.poll()
		if err != OK:
			return _failure_result("http_body_read_failed", "读取后端响应体时发生错误。", {
				"godot_error": err
			})
		if _has_timed_out(timeout_at):
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


func _make_optional_timeout_at(timeout_seconds: float) -> int:
	if is_zero_approx(timeout_seconds):
		return 0
	var effective_timeout := request_timeout_seconds if timeout_seconds < 0.0 else timeout_seconds
	return Time.get_ticks_msec() + int(maxf(effective_timeout, 0.1) * 1000.0)


func _has_timed_out(timeout_at: int) -> bool:
	return timeout_at > 0 and Time.get_ticks_msec() >= timeout_at


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


func _register_time_slowdown(request_id: String, call_type: String = "llm") -> void:
	if request_id.is_empty():
		return
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system == null or not time_system.has_method("request_time_slowdown"):
		return
	_debug_last_slowdown_registered = true
	var normalized_call_type := call_type.strip_edges()
	if normalized_call_type.is_empty():
		normalized_call_type = "llm"
	var reason := "llm_%s_wait" % normalized_call_type
	time_system.request_time_slowdown(request_id, dialogue_wait_scale, reason)
	if not _pending_slowdown_request_ids.has(request_id):
		_pending_slowdown_request_ids.append(request_id)
	_slowdown_audit_by_request[request_id] = {
		"request_id": request_id,
		"call_type": normalized_call_type,
		"reason": reason,
		"registered": true,
		"released": false,
		"registered_at_msec": Time.get_ticks_msec()
	}


func _release_time_slowdown(request_id: String) -> void:
	if request_id.is_empty():
		return
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system != null and time_system.has_method("release_time_slowdown"):
		time_system.release_time_slowdown(request_id)
	if _pending_slowdown_request_ids.has(request_id):
		_pending_slowdown_request_ids.erase(request_id)
	if _slowdown_audit_by_request.has(request_id):
		var audit: Dictionary = _slowdown_audit_by_request.get(request_id, {}).duplicate(true)
		audit["released"] = true
		audit["released_at_msec"] = Time.get_ticks_msec()
		_last_slowdown_audit = audit
		_slowdown_audit_by_request.erase(request_id)


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
	return NPCPromptProfile.build_setting(npc)


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
		"work_encouragement_boost": npc_state.get("work_encouragement_boost", {}),
		"escape_intent": npc_state.get("escape_intent", {}),
		"current_location": str(npc_state.get("current_location", "plaza")),
		"current_location_name": str(npc_state.get("current_location_name", "广场")),
		"recruited": bool(npc.get("recruited", npc_state.get("recruited", false))),
		"unconscious": bool(npc_state.get("unconscious", false)),
		"escaped": bool(npc_state.get("escaped", false)),
		"equipment": _build_prompt_equipment_context(npc.get("equipment", {})),
		"skills": npc.get("skills", {}),
		"stats": npc_state.get("stats", npc.get("stats", {})),
		"money": maxi(0, int(npc_state.get("money", 0))),
		"wine": maxi(0, int(npc_state.get("wine", 0)))
	}


func _build_prompt_equipment_context(raw_equipment: Variant) -> Dictionary:
	if not raw_equipment is Dictionary:
		return {}
	var result := {}
	var allowed_fields: Array[String] = [
		"id",
		"name",
		"type",
		"kind",
		"slot",
		"equipment_slot",
		"weapon_class",
		"combat_role",
		"required_skill",
		"source_resource_id",
		"horse_id",
		"tags",
		"damage",
		"range",
		"attack_interval",
		"armor_value",
		"weight",
		"speed_bonus"
	]
	for raw_slot_id in (raw_equipment as Dictionary).keys():
		var slot_id := str(raw_slot_id)
		var raw_item: Variant = (raw_equipment as Dictionary).get(raw_slot_id, {})
		if not raw_item is Dictionary or (raw_item as Dictionary).is_empty():
			continue
		var projected := {}
		for field in allowed_fields:
			if (raw_item as Dictionary).has(field):
				projected[field] = (raw_item as Dictionary).get(field)
		result[slot_id] = projected
	return result


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
		# The replying NPC may observe the other participant's appearance and health,
		# but must not receive that participant's private state, order or memory.
		"state": {}
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
		"experienced_events": _events_to_summaries(
			memory.get("event_log", [])
		),
		"witnessed_events": _events_to_summaries(
			memory.get("witness_log", [])
		)
	}


func _build_long_memory_context(npc: Dictionary) -> Dictionary:
	return {
		"knowledge_graph": npc.get("knowledge_graph", {}),
		# Keep each record's chronology visible while preserving the compact
		# list[String] request contract used by every NPC-centered endpoint.
		"diary": _build_existing_diary_entries(npc)
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


func _build_npc_context(
	npc_id: String,
	npc_system: Node,
	include_long_term_memory: bool = true
) -> Dictionary:
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var context := {
		"identity": {
			"npc_id": npc_id,
			"name": str(npc.get("name", npc_id)),
			"gender": npc.get("gender", null),
			"background_job": npc.get("background_job", null),
			"religion": str(npc.get("religion", "")),
			"background_story": str(npc.get("background_story", "")),
			"personality": npc.get("personality", []),
			"desires": npc.get("desires", []),
			"fears": npc.get("fears", []),
			"boundaries": npc.get("boundaries", npc.get("bottom_lines", [])),
			"speech_style": npc.get("speech_style", "")
		},
		"state": _build_npc_state_context(npc, state),
		"current_order": npc_system.get_current_order(npc_id) if npc_system.has_method("get_current_order") else {},
		"short_term_memory": _build_short_memory_context(npc_id),
		"location_context": _build_location_context(state),
		"plaza_context": _get_plaza_context()
	}
	if include_long_term_memory:
		context["long_term_memory"] = _build_long_memory_context(npc)
	return context


func _build_station_context(npc_system: Node) -> Dictionary:
	var resident_roster: Array[Dictionary] = []
	if npc_system != null and npc_system.has_method("get_npc_ids"):
		for raw_npc_id in npc_system.get_npc_ids():
			var resident_npc_id := str(raw_npc_id)
			var resident: Dictionary = npc_system.get_npc(resident_npc_id)
			var resident_state: Dictionary = npc_system.get_npc_state(resident_npc_id)
			if resident.is_empty():
				continue
			resident_roster.append({
				"npc_id": resident_npc_id,
				"name": str(resident.get("name", resident_npc_id)),
				"identity": str(resident.get("background_job", "驿站居民")),
				"recruited": bool(resident.get("recruited", resident_state.get("recruited", false))),
				"in_station": not _has_npc_left_station(resident_state)
			})

	if _station_context_template.is_empty():
		_station_context_template = _load_station_context_template()

	return {
		"setting_summary": str(_station_context_template.get("setting_summary", "")).strip_edges(),
		"resident_roster": resident_roster,
		"building_roster": _build_station_building_roster(),
		"work_mode_actions": _build_station_work_mode_actions(),
		"basic_resource_reserves": _build_station_basic_resource_reserves(),
		"station_rules": _normalize_string_array(_station_context_template.get("station_rules", []))
	}


func _load_station_context_template() -> Dictionary:
	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null or not config_loader.has_method("load_data_file"):
		push_error("LLMBridge requires ConfigLoader autoload for station context.")
		return {}
	var loaded: Variant = config_loader.load_data_file(STATION_CONTEXT_FILE, {})
	if loaded is Dictionary:
		return (loaded as Dictionary).duplicate(true)
	push_error("Station context config must be a JSON object: res://data/%s" % STATION_CONTEXT_FILE)
	return {}


func _build_station_building_roster() -> Array[Dictionary]:
	var building_roster: Array[Dictionary] = []
	var building_system := get_node_or_null("/root/Main/Systems/BuildingSystem")
	if building_system == null or not building_system.has_method("get_building_ids"):
		return building_roster
	for raw_building_id in building_system.get_building_ids():
		var building_id := str(raw_building_id)
		var building: Dictionary = building_system.get_building(building_id)
		if building.is_empty():
			continue
		building_roster.append({
			"building_id": building_id,
			"name": str(building.get("name", building_id))
		})
	return building_roster


func _build_station_work_mode_actions() -> Array[Dictionary]:
	var work_mode_actions: Array[Dictionary] = []
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("get_action_ids"):
		return work_mode_actions
	for raw_action_id in action_system.get_action_ids():
		var action_id := str(raw_action_id)
		var action: Dictionary = action_system.get_action(action_id)
		if not bool(action.get("plan_selectable", true)):
			continue
		if str(action.get("type", "")) == "system" and action_id != "escaping_station":
			continue
		work_mode_actions.append({
			"action_id": action_id,
			"name": str(action.get("name", action_id)),
			"action_kind": _infer_plan_action_kind(action_id, action),
			"description": str(action.get("description", ""))
		})
	return work_mode_actions


func _build_station_basic_resource_reserves() -> Array[Dictionary]:
	var reserves: Array[Dictionary] = []
	var resource_system := get_node_or_null("/root/Main/Systems/ResourceSystem")
	if resource_system == null or not resource_system.has_method("get_resource"):
		return reserves
	for resource_id in BASIC_RESOURCE_RESERVE_IDS:
		var resource_name := resource_id
		if resource_system.has_method("get_resource_name"):
			resource_name = str(resource_system.get_resource_name(resource_id))
		reserves.append({
			"resource_id": resource_id,
			"name": resource_name,
			"amount": int(resource_system.get_resource(resource_id))
		})
	return reserves


func debug_build_station_context() -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	return _build_station_context(npc_system)


func _has_npc_left_station(npc_state: Dictionary) -> bool:
	return (
		bool(npc_state.get("escaped", false))
		or str(npc_state.get("behavior_mode", "")) == "escaped"
		or str(npc_state.get("current_location", "")) == "outside_station"
	)


func _build_reflection_day_events(npc_id: String) -> Array:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("get_npc_short_term_memory"):
		return []
	var memory: Dictionary = memory_system.get_npc_short_term_memory(npc_id)
	var result: Array = []
	result.append_array(build_memory_event_projection(memory.get("event_log", []), "experienced"))
	result.append_array(build_memory_event_projection(memory.get("witness_log", []), "witnessed"))
	return result


func _event_to_summary(event: Dictionary) -> Dictionary:
	return build_compact_memory_event(event)


func _build_existing_diary_entries(npc: Dictionary) -> Array[String]:
	var entries: Array[String] = []
	var diary: Variant = npc.get("diary", [])
	if not diary is Array:
		return entries
	for raw_entry in diary:
		if raw_entry is Dictionary:
			var diary_record := raw_entry as Dictionary
			var entry_text := str(diary_record.get("entry", "")).strip_edges()
			if not entry_text.is_empty():
				var day := int(diary_record.get("day", 0))
				var time_label := str(diary_record.get("time", "")).strip_edges()
				var record_label := str(diary_record.get("record_label", "")).strip_edges()
				if not record_label.is_empty() and not time_label.is_empty():
					entries.append("%s %s：%s" % [record_label, time_label, entry_text])
				elif not record_label.is_empty():
					entries.append("%s：%s" % [record_label, entry_text])
				elif day > 0 and not time_label.is_empty():
					entries.append("第%d天 %s：%s" % [day, time_label, entry_text])
				elif day > 0:
					entries.append("第%d天：%s" % [day, entry_text])
				elif not time_label.is_empty():
					entries.append("%s：%s" % [time_label, entry_text])
				else:
					entries.append(entry_text)
		else:
			var text := str(raw_entry).strip_edges()
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


func debug_build_short_memory_context(npc_id: String) -> Dictionary:
	return _build_short_memory_context(npc_id)


func debug_build_short_memory_projection_report(npc_id: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("get_npc_short_term_memory"):
		return {}
	var memory: Dictionary = memory_system.get_npc_short_term_memory(npc_id)
	var event_log: Variant = memory.get("event_log", [])
	var witness_log: Variant = memory.get("witness_log", [])
	var experienced := build_memory_event_projection(event_log, "experienced")
	var witnessed := build_memory_event_projection(witness_log, "witnessed")
	return {
		"experienced": _build_memory_projection_stats(event_log, experienced),
		"witnessed": _build_memory_projection_stats(witness_log, witnessed),
		"projection": {
			"experienced_events": experienced,
			"witnessed_events": witnessed
		}
	}


func debug_build_memory_projection_report(raw_events: Variant, memory_kind: String = "") -> Dictionary:
	var projection := build_memory_event_projection(raw_events, memory_kind)
	var report := _build_memory_projection_stats(raw_events, projection)
	report["projection"] = projection
	return report


func _record_npc_context_injection(npc_id: String, call_type: String, current_order: Dictionary, request_id: String, extra: Dictionary = {}) -> void:
	_last_npc_context_injection = {
		"npc_id": npc_id,
		"call_type": call_type,
		"request_id": request_id,
		"current_order": current_order.duplicate(true)
	}
	for key in extra.keys():
		_last_npc_context_injection[key] = extra[key]


func _events_to_summaries(raw_events: Variant) -> Array:
	return build_memory_event_projection(raw_events)


func build_memory_event_projection(raw_events: Variant, memory_kind: String = "") -> Array:
	var projection: Array = []
	if not raw_events is Array:
		return projection
	# A non-whitelisted narrative event is a hard boundary. This keeps two battles,
	# an unconscious transition, dialogue, and other causally important moments
	# from being collapsed merely because their semantic keys happen to match.
	var aggregate_indices: Dictionary = {}
	for raw_event in raw_events as Array:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var event_type := str(event.get("type", ""))
		var compact := build_compact_memory_event(event)
		if ["experienced", "witnessed"].has(memory_kind):
			compact["memory_kind"] = memory_kind
		if not AGGREGATABLE_MEMORY_EVENT_TYPES.has(event_type):
			aggregate_indices.clear()
			projection.append(compact)
			continue
		var signature := _build_memory_aggregation_signature(event)
		if signature.is_empty():
			projection.append(compact)
			continue
		if not aggregate_indices.has(signature):
			aggregate_indices[signature] = projection.size()
			projection.append(compact)
			continue
		var projection_index := int(aggregate_indices[signature])
		projection[projection_index] = _merge_memory_aggregate(
			projection[projection_index],
			event
		)
	return projection


func _build_memory_aggregation_signature(event: Dictionary) -> String:
	var event_type := str(event.get("type", ""))
	if not AGGREGATABLE_MEMORY_EVENT_TYPES.has(event_type):
		return ""
	# Raw identity fields are mandatory. Already compacted events deliberately do
	# not get guessed into a group because their subject/object boundary is gone.
	for required_key in ["subject_npc_id", "actor_ids", "target_ids", "location_id", "visibility"]:
		if not event.has(required_key):
			return ""
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	var signature := {
		"type": event_type,
		"day": event.get("day", null),
		"subject_npc_id": str(event.get("subject_npc_id", "")),
		"actor_ids": _memory_string_array(event.get("actor_ids", [])),
		"target_ids": _memory_string_array(event.get("target_ids", [])),
		"location_id": str(event.get("location_id", "")),
		"visibility": str(event.get("visibility", ""))
	}
	var semantic_fields: Array = MEMORY_AGGREGATION_SIGNATURE_FIELDS.get(event_type, [])
	for raw_field in semantic_fields:
		var field := str(raw_field)
		signature[field] = payload.get(field, null)
	return JSON.stringify(signature)


func _memory_string_array(raw_value: Variant) -> Array[String]:
	var values: Array[String] = []
	if not raw_value is Array:
		return values
	for raw_item in raw_value as Array:
		values.append(str(raw_item))
	return values


func _merge_memory_aggregate(current: Dictionary, next_raw_event: Dictionary) -> Dictionary:
	var merged := current.duplicate(true)
	var details: Dictionary = merged.get("details", {}) if merged.get("details", {}) is Dictionary else {}
	var aggregation: Dictionary = (
		details.get("aggregation", {}).duplicate(true)
		if details.get("aggregation", {}) is Dictionary
		else {}
	)
	if aggregation.is_empty():
		aggregation = _new_memory_aggregation(merged, details)
	var next_payload: Dictionary = (
		next_raw_event.get("payload", {})
		if next_raw_event.get("payload", {}) is Dictionary
		else {}
	)
	aggregation["event_count"] = int(aggregation.get("event_count", 1)) + 1
	aggregation["total_damage"] = _add_memory_numbers(
		aggregation.get("total_damage", 0),
		next_payload.get("damage", 0)
	)
	aggregation["last_day"] = next_raw_event.get("day", merged.get("day", null))
	aggregation["last_time"] = next_raw_event.get("time", merged.get("time", null))
	aggregation["hp_after_last"] = next_payload.get(
		"hp_after",
		aggregation.get("hp_after_last", null)
	)
	if next_payload.has("hp_after"):
		var previous_low: Variant = aggregation.get("lowest_hp", next_payload.get("hp_after"))
		aggregation["lowest_hp"] = minf(float(previous_low), float(next_payload.get("hp_after", previous_low)))
	if next_payload.has("damage_after_defense"):
		aggregation["total_damage_after_defense"] = _add_memory_numbers(
			aggregation.get("total_damage_after_defense", 0),
			next_payload.get("damage_after_defense", 0)
		)
	aggregation["defeated_any"] = (
		bool(aggregation.get("defeated_any", false))
		or bool(next_payload.get("defeated", false))
	)
	aggregation["last_defeated"] = bool(next_payload.get("defeated", false))
	for key in MEMORY_AGGREGATION_DYNAMIC_DETAIL_KEYS:
		details.erase(key)
	details["aggregation"] = aggregation
	merged["details"] = details
	merged["importance"] = maxi(
		int(merged.get("importance", 50)),
		clampi(int(next_raw_event.get("importance", 50)), 0, 100)
	)
	merged["summary"] = _build_memory_aggregate_summary(
		str(merged.get("type", "")),
		str(current.get("summary", "")),
		details,
		aggregation
	)
	return merged


func _new_memory_aggregation(first_compact: Dictionary, first_details: Dictionary) -> Dictionary:
	var first_hp_after: Variant = first_details.get("hp_after", null)
	var aggregation := {
		"scope": "same_day_contiguous_combat_run",
		"event_count": 1,
		"first_day": first_compact.get("day", null),
		"first_time": first_compact.get("time", null),
		"last_day": first_compact.get("day", null),
		"last_time": first_compact.get("time", null),
		"total_damage": first_details.get("damage", 0),
		"hp_before_first": first_details.get("hp_before", null),
		"hp_after_last": first_hp_after,
		"lowest_hp": first_hp_after,
		"defeated_any": bool(first_details.get("defeated", false)),
		"last_defeated": bool(first_details.get("defeated", false))
	}
	if first_details.has("damage_after_defense"):
		aggregation["total_damage_after_defense"] = first_details.get("damage_after_defense", 0)
	return aggregation


func _add_memory_numbers(left: Variant, right: Variant) -> Variant:
	if left is int and right is int:
		return int(left) + int(right)
	return float(left) + float(right)


func _build_memory_aggregate_summary(
	event_type: String,
	first_summary: String,
	details: Dictionary,
	aggregation: Dictionary
) -> String:
	var count := int(aggregation.get("event_count", 1))
	var total_damage := _format_memory_number(aggregation.get("total_damage", 0))
	var hp_before := _format_memory_number(aggregation.get("hp_before_first", 0))
	var hp_after := _format_memory_number(aggregation.get("hp_after_last", 0))
	var lowest_hp := _format_memory_number(aggregation.get("lowest_hp", 0))
	var terminal_text := "，期间击退目标" if bool(aggregation.get("defeated_any", false)) else ""
	match event_type:
		"attack_made":
			return "%s使用%s攻击%s%d次，共造成%s点伤害，目标HP从%s降到%s，最低%s%s。" % [
				str(details.get("attacker_name", details.get("attacker_npc_id", "NPC"))),
				str(details.get("weapon_name", "武器")),
				str(details.get("target_enemy_name", details.get("target_enemy_id", "敌人"))),
				count, total_damage, hp_before, hp_after, lowest_hp, terminal_text
			]
		"damage_taken":
			return "%s受到%s的同类伤害%d次，共失去%s点HP，HP从%s降到%s，最低%s。" % [
				_memory_summary_prefix(first_summary, "受到", str(details.get("target_npc_id", "NPC"))),
				_memory_damage_source_label(first_summary, str(details.get("damage_source", "未知来源"))),
				count, total_damage, hp_before, hp_after, lowest_hp
			]
		"building_damaged":
			return "%s攻击%s%d次，共造成%s点建筑伤害，HP从%s降到%s，最低%s。" % [
				_memory_summary_prefix(first_summary, "攻击", str(details.get("damage_source", "敌人"))),
				str(details.get("building_name", details.get("building_id", "建筑"))),
				count, total_damage, hp_before, hp_after, lowest_hp
			]
		"defense_device_triggered":
			return "%s（部署%s）攻击%s%d次，共造成%s点伤害，目标HP从%s降到%s，最低%s%s。" % [
				str(details.get("device_name", "防御器械")),
				str(details.get("deployment_id", "未知")),
				str(details.get("target_enemy_name", details.get("target_enemy_id", "敌人"))),
				count, total_damage, hp_before, hp_after, lowest_hp, terminal_text
			]
		"horse_damaged":
			return "%s骑乘的%s承受同类伤害%d次，共失去%s点HP，HP从%s降到%s，最低%s。" % [
				_memory_summary_prefix(first_summary, "骑乘", str(details.get("target_npc_id", "NPC"))),
				str(details.get("horse_name", details.get("horse_id", "马匹"))),
				count, total_damage, hp_before, hp_after, lowest_hp
			]
	return first_summary


func _memory_summary_prefix(summary: String, separator: String, fallback: String) -> String:
	var separator_index := summary.find(separator)
	if separator_index <= 0:
		return fallback
	return summary.left(separator_index).strip_edges()


func _memory_summary_between(summary: String, start_marker: String, end_marker: String, fallback: String) -> String:
	var start_index := summary.find(start_marker)
	if start_index < 0:
		return fallback
	start_index += start_marker.length()
	var end_index := summary.find(end_marker, start_index)
	if end_index <= start_index:
		return fallback
	return summary.substr(start_index, end_index - start_index).strip_edges()


func _memory_damage_source_label(summary: String, fallback: String) -> String:
	var label := _memory_summary_between(summary, "受到", "造成的", "")
	if label.is_empty():
		label = _memory_summary_between(summary, "受到", "的同类伤害", "")
	return fallback if label.is_empty() else label


func _format_memory_number(value: Variant) -> String:
	var number := float(value) if value != null else 0.0
	if is_equal_approx(number, round(number)):
		return str(int(round(number)))
	return "%.2f" % number


func _build_memory_projection_stats(raw_events: Variant, projection: Array) -> Dictionary:
	var raw_count := 0
	var by_type: Dictionary = {}
	if raw_events is Array:
		for raw_event in raw_events as Array:
			if not raw_event is Dictionary:
				continue
			raw_count += 1
			var event_type := str((raw_event as Dictionary).get("type", ""))
			if AGGREGATABLE_MEMORY_EVENT_TYPES.has(event_type):
				var type_stats: Dictionary = by_type.get(event_type, {
					"raw_count": 0,
					"projected_count": 0,
					"aggregated_group_count": 0
				})
				type_stats["raw_count"] = int(type_stats.get("raw_count", 0)) + 1
				by_type[event_type] = type_stats
	for raw_projected in projection:
		if not raw_projected is Dictionary:
			continue
		var projected_event: Dictionary = raw_projected
		var event_type := str(projected_event.get("type", ""))
		if not AGGREGATABLE_MEMORY_EVENT_TYPES.has(event_type):
			continue
		var type_stats: Dictionary = by_type.get(event_type, {
			"raw_count": 0,
			"projected_count": 0,
			"aggregated_group_count": 0
		})
		type_stats["projected_count"] = int(type_stats.get("projected_count", 0)) + 1
		var details: Dictionary = projected_event.get("details", {}) if projected_event.get("details", {}) is Dictionary else {}
		var aggregation: Dictionary = details.get("aggregation", {}) if details.get("aggregation", {}) is Dictionary else {}
		if int(aggregation.get("event_count", 1)) > 1:
			type_stats["aggregated_group_count"] = int(type_stats.get("aggregated_group_count", 0)) + 1
		by_type[event_type] = type_stats
	return {
		"raw_count": raw_count,
		"projected_count": projection.size(),
		"saved_count": raw_count - projection.size(),
		"by_type": by_type
	}


func build_compact_memory_event(event: Dictionary) -> Dictionary:
	var event_type := str(event.get("type", ""))
	var compact := {
		"type": event_type,
		"summary": str(event.get("summary", "")).strip_edges(),
		"importance": clampi(int(event.get("importance", 50)), 0, 100),
		"day": event.get("day", null),
		"time": event.get("time", null)
	}
	var raw_payload: Variant = event.get("payload", event.get("details", {}))
	if raw_payload is Dictionary:
		var details := _build_compact_memory_details(raw_payload as Dictionary)
		if (
			["plan_created", "plan_revised"].has(event_type)
			and (raw_payload as Dictionary).get("items", []) is Array
		):
			var plan_segments := _compact_memory_plan_segments(
				(raw_payload as Dictionary).get("items", [])
			)
			if not plan_segments.is_empty():
				details["plan_segments"] = plan_segments
		if not details.is_empty():
			compact["details"] = details
	return compact


func _build_compact_memory_details(payload: Dictionary) -> Dictionary:
	var details := {}
	for raw_key in payload.keys():
		var key := str(raw_key)
		if SHORT_MEMORY_OMITTED_PAYLOAD_KEYS.has(key):
			continue
		var compact_value: Variant = _compact_memory_detail_value(payload[raw_key])
		if compact_value != null:
			details[key] = compact_value
	return details


func _compact_memory_detail_value(value: Variant) -> Variant:
	if value is String or value is StringName:
		var text_value := str(value).strip_edges()
		return null if text_value.is_empty() else text_value
	if value is bool or value is int or value is float:
		return value
	if value is Dictionary:
		var compact_dictionary := {}
		for raw_key in (value as Dictionary).keys():
			var key := str(raw_key)
			if SHORT_MEMORY_OMITTED_PAYLOAD_KEYS.has(key):
				continue
			var compact_value: Variant = _compact_memory_detail_value(
				(value as Dictionary)[raw_key]
			)
			if compact_value != null:
				compact_dictionary[key] = compact_value
		return null if compact_dictionary.is_empty() else compact_dictionary
	if value is Array:
		var compact_array: Array = []
		for raw_item in value as Array:
			var compact_item: Variant = _compact_memory_detail_value(raw_item)
			if compact_item != null:
				compact_array.append(compact_item)
		return null if compact_array.is_empty() else compact_array
	return null


func _compact_memory_plan_segments(raw_items: Variant) -> Array:
	var segments: Array = []
	if not raw_items is Array:
		return segments
	for raw_item in raw_items:
		if not raw_item is Dictionary:
			continue
		var item: Dictionary = raw_item
		var hour := clampi(int(item.get("hour", 0)), 0, 23)
		var segment := {
			"from_hour": hour,
			"to_hour": hour,
			"action_id": str(item.get("action_id", "idle"))
		}
		for optional_key in ["location_id", "target_id"]:
			var optional_value := str(item.get(optional_key, "")).strip_edges()
			if not optional_value.is_empty():
				segment[optional_key] = optional_value
		if not segments.is_empty():
			var previous: Dictionary = segments[-1]
			if (
				int(previous.get("to_hour", -1)) + 1 == hour
				and _memory_plan_segments_match(previous, segment)
			):
				previous["to_hour"] = hour
				segments[-1] = previous
				continue
		segments.append(segment)
	return segments


func _memory_plan_segments_match(left: Dictionary, right: Dictionary) -> bool:
	for key in ["action_id", "location_id", "target_id"]:
		if str(left.get(key, "")) != str(right.get(key, "")):
			return false
	return true


func _compact_reflection_day_events(raw_events: Variant) -> Array:
	var compact_events: Array = []
	if not raw_events is Array:
		return compact_events
	for raw_event in raw_events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		var compact := build_compact_memory_event(event)
		var memory_kind := str(event.get("memory_kind", "")).strip_edges()
		if ["experienced", "witnessed"].has(memory_kind):
			compact["memory_kind"] = memory_kind
		compact_events.append(compact)
	return compact_events


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


func _normalize_revision_hours(value: Variant, minimum_hour: int) -> Array[int]:
	var result: Array[int] = []
	if not value is Array:
		return result
	for raw_hour in value:
		var hour := int(raw_hour)
		if hour < minimum_hour or hour > 23 or result.has(hour):
			continue
		result.append(hour)
	result.sort()
	return result
