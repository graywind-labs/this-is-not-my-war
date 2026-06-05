extends Node

signal backend_status_changed(status_text: String, ok: bool)
signal dialogue_response_received(result: Dictionary)

const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DEFAULT_BACKEND_URL := "http://127.0.0.1:5000"
const GUARD_OFFICER_ID := "guard_officer"
const GUARD_OFFICER_NAME := "守备官"
const DEFAULT_GUARD_APPEARANCE := "驿站守备官，穿着磨旧的军官外套，带着边境军令。"
const SHORT_MEMORY_EVENT_LIMIT := 8
const HTTP_POLL_DELAY_MSEC := 10

@export var backend_base_url: String = DEFAULT_BACKEND_URL
@export var request_timeout_seconds: float = 8.0
@export var dialogue_wait_scale: float = -1.0

var _last_backend_ok := false
var _last_backend_status := "后端：未检查"
var _request_counter := 0
var _pending_slowdown_request_ids: Array[String] = []
var _debug_last_slowdown_registered := false
var _last_npc_context_injection: Dictionary = {}


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
	var result: Dictionary = _request_json("POST", "/npc/dialogue", payload, true, request_id)
	var response := result.duplicate(true)
	if bool(result.get("ok", false)):
		response["dialogue"] = result.get("body", {})
	dialogue_response_received.emit(response.duplicate(true))
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
	_record_npc_context_injection(npc_id, "dialogue", current_order, request_id)
	return payload


func _request_json(method: String, endpoint: String, payload: Dictionary = {}, use_slowdown: bool = false, request_id: String = "") -> Dictionary:
	var active_slowdown_id := ""
	if use_slowdown:
		active_slowdown_id = request_id if not request_id.is_empty() else _make_request_id("llm")
		_register_time_slowdown(active_slowdown_id)

	var transport_result := _send_http_request(method, endpoint, payload)
	_release_time_slowdown(active_slowdown_id)
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


func debug_build_npc_context(npc_id: String, call_type: String = "debug") -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return {}
	var context := _build_npc_context(npc_id, npc_system)
	if not context.is_empty():
		_record_npc_context_injection(npc_id, call_type, context.get("current_order", {}), "")
	return context


func _record_npc_context_injection(npc_id: String, call_type: String, current_order: Dictionary, request_id: String) -> void:
	_last_npc_context_injection = {
		"npc_id": npc_id,
		"call_type": call_type,
		"request_id": request_id,
		"current_order": current_order.duplicate(true)
	}


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
