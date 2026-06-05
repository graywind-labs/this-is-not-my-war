extends Node

signal dialogue_started(dialogue_state: Dictionary)
signal dialogue_updated(dialogue_state: Dictionary)
signal dialogue_ended(dialogue_state: Dictionary)

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const GUARD_OFFICER_ID := "guard_officer"
const GUARD_OFFICER_NAME := "守备官"
const PLAYER_DIALOGUE_MAX_ROUNDS := 999999
const NPC_DIALOGUE_MAX_ROUNDS := 5

var _dialogue_counter := 0
var _active_dialogue: Dictionary = {}


func initialize() -> void:
	_active_dialogue.clear()


func _ready() -> void:
	initialize()


func start_player_dialogue(npc_id: String, visibility: String = "private") -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return _failure("npc_system_missing", "NPCSystem 不可用。")
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _failure("npc_not_found", "找不到 NPC：%s。" % npc_id)
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	if bool(npc_state.get("unconscious", false)):
		return _failure("npc_unconscious", "昏迷中的 NPC 无法对话。")

	if not _active_dialogue.is_empty():
		end_dialogue()
	_dialogue_counter += 1
	var clean_visibility := visibility if ["private", "local_public"].has(visibility) else "private"
	_active_dialogue = {
		"dialogue_id": "dialogue_%d_%04d" % [Time.get_ticks_msec(), _dialogue_counter],
		"dialogue_kind": "player_npc",
		"target_npc_id": npc_id,
		"target_npc_name": str(npc.get("name", npc_id)),
		"speaker_npc_id": "",
		"speaker_name": GUARD_OFFICER_NAME,
		"visibility": clean_visibility,
		"location_id": str(npc_state.get("current_location", "plaza")),
		"location_name": str(npc_state.get("current_location_name", "广场")),
		"current_round": 0,
		"max_rounds": PLAYER_DIALOGUE_MAX_ROUNDS,
		"history": [],
		"waiting": false,
		"last_error": "",
		"recruitment_request_pending": false,
		"last_recruitment_result": "none"
	}
	dialogue_started.emit(get_dialogue_state())
	return {"ok": true, "dialogue_state": get_dialogue_state()}


func start_proactive_player_dialogue(npc_id: String, opening_text: String, visibility: String = "private") -> Dictionary:
	var start_result := start_player_dialogue(npc_id, visibility)
	if not bool(start_result.get("ok", false)):
		return start_result
	var clean_text := opening_text.strip_edges()
	if clean_text.is_empty():
		clean_text = "守备官，我有件事想问你。"
	var npc_name := str(_active_dialogue.get("target_npc_name", npc_id))
	var opening_turn := _make_history_turn(npc_id, npc_name, GUARD_OFFICER_ID, GUARD_OFFICER_NAME, clean_text)
	var history: Array = _active_dialogue.get("history", [])
	history.append(opening_turn)
	_active_dialogue["history"] = history
	_active_dialogue["proactive_talk"] = true
	_active_dialogue["proactive_opening_text"] = clean_text
	_record_proactive_talk_message(clean_text)
	dialogue_updated.emit(get_dialogue_state())
	return {"ok": true, "dialogue_state": get_dialogue_state()}


func start_npc_dialogue(speaker_npc_id: String, target_npc_id: String, visibility: String = "local_public", max_rounds: int = NPC_DIALOGUE_MAX_ROUNDS) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return _failure("npc_system_missing", "NPCSystem 不可用。")
	if speaker_npc_id == target_npc_id:
		return _failure("invalid_participants", "NPC 不能与自己对话。")
	var speaker: Dictionary = npc_system.get_npc(speaker_npc_id)
	var target: Dictionary = npc_system.get_npc(target_npc_id)
	if speaker.is_empty() or target.is_empty():
		return _failure("npc_not_found", "找不到 NPC-NPC 对话参与者。")
	if bool(npc_system.get_npc_state(speaker_npc_id).get("unconscious", false)) or bool(npc_system.get_npc_state(target_npc_id).get("unconscious", false)):
		return _failure("npc_unconscious", "昏迷中的 NPC 无法对话。")
	if not _active_dialogue.is_empty():
		end_dialogue()
	_dialogue_counter += 1
	var clean_visibility := visibility if ["private", "local_public"].has(visibility) else "local_public"
	var target_state: Dictionary = npc_system.get_npc_state(target_npc_id)
	_active_dialogue = {
		"dialogue_id": "dialogue_%d_%04d" % [Time.get_ticks_msec(), _dialogue_counter],
		"dialogue_kind": "npc_npc",
		"target_npc_id": target_npc_id,
		"target_npc_name": str(target.get("name", target_npc_id)),
		"speaker_npc_id": speaker_npc_id,
		"speaker_name": str(speaker.get("name", speaker_npc_id)),
		"visibility": clean_visibility,
		"location_id": str(target_state.get("current_location", "plaza")),
		"location_name": str(target_state.get("current_location_name", "广场")),
		"current_round": 0,
		"max_rounds": maxi(1, max_rounds),
		"history": [],
		"waiting": false,
		"last_error": ""
	}
	dialogue_started.emit(get_dialogue_state())
	return {"ok": true, "dialogue_state": get_dialogue_state()}


func send_player_message(text: String, is_recruitment_request: bool = false) -> Dictionary:
	var clean_text := text.strip_edges()
	if _active_dialogue.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	if clean_text.is_empty():
		return _failure("empty_message", "请输入对话内容。")
	if bool(_active_dialogue.get("waiting", false)):
		return _failure("dialogue_waiting", "正在等待 NPC 回复。")

	_active_dialogue["waiting"] = true
	_active_dialogue["last_error"] = ""
	var effective_recruitment_request := is_recruitment_request or bool(_active_dialogue.get("recruitment_request_pending", false))
	_active_dialogue["recruitment_request_pending"] = false
	dialogue_updated.emit(get_dialogue_state())
	var next_round := int(_active_dialogue.get("current_round", 0)) + 1
	var history_before: Array = _active_dialogue.get("history", []).duplicate(true)
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null:
		_active_dialogue["waiting"] = false
		_active_dialogue["last_error"] = "LLMBridge 不可用。"
		dialogue_updated.emit(get_dialogue_state())
		return _failure("llm_bridge_missing", str(_active_dialogue["last_error"]))

	var result: Dictionary = llm_bridge.request_npc_dialogue(
		str(_active_dialogue.get("target_npc_id", "")),
		clean_text,
		{
			"dialogue_kind": "player_npc",
			"current_round": next_round,
			"max_rounds": int(_active_dialogue.get("max_rounds", PLAYER_DIALOGUE_MAX_ROUNDS)),
			"is_recruitment_request": effective_recruitment_request,
			"conversation_history": history_before,
			"dialogue_state": {
				"visibility": str(_active_dialogue.get("visibility", "private")),
				"location_id": str(_active_dialogue.get("location_id", "plaza")),
				"location_name": str(_active_dialogue.get("location_name", "广场")),
				"participants": [GUARD_OFFICER_ID, str(_active_dialogue.get("target_npc_id", ""))]
			}
		}
	)
	_active_dialogue["waiting"] = false
	if not bool(result.get("ok", false)):
		_active_dialogue["last_error"] = str(result.get("message", "后端请求失败。"))
		dialogue_updated.emit(get_dialogue_state())
		return result

	var response: Dictionary = result.get("dialogue", {})
	var reply_text := str(response.get("reply_text", "")).strip_edges()
	if reply_text.is_empty():
		_active_dialogue["last_error"] = "后端没有返回 NPC 回复。"
		dialogue_updated.emit(get_dialogue_state())
		return _failure("empty_reply", str(_active_dialogue["last_error"]))

	var recruitment_result := _apply_recruitment_result(response, effective_recruitment_request)
	_active_dialogue["last_recruitment_result"] = recruitment_result
	var npc_name := str(_active_dialogue.get("target_npc_name", "NPC"))
	var player_turn := _make_history_turn(GUARD_OFFICER_ID, GUARD_OFFICER_NAME, str(_active_dialogue.get("target_npc_id", "")), npc_name, clean_text)
	var npc_turn := _make_history_turn(str(_active_dialogue.get("target_npc_id", "")), npc_name, GUARD_OFFICER_ID, GUARD_OFFICER_NAME, reply_text)
	var history: Array = _active_dialogue.get("history", [])
	history.append(player_turn)
	history.append(npc_turn)
	_active_dialogue["history"] = history
	_active_dialogue["current_round"] = next_round
	_record_dialogue_event("dialogue_turn", {
		"speaker_name": GUARD_OFFICER_NAME,
		"listener_name": npc_name,
		"speaker_text": clean_text,
		"reply_text": reply_text,
		"dialogue_text": [player_turn, npc_turn],
		"is_recruitment_request": effective_recruitment_request,
		"recruitment_result": recruitment_result,
		"emotion": str(response.get("emotion", "neutral"))
	})
	dialogue_updated.emit(get_dialogue_state())
	return {
		"ok": true,
		"reply_text": reply_text,
		"dialogue": response.duplicate(true),
		"dialogue_state": get_dialogue_state()
	}


func send_npc_message(text: String) -> Dictionary:
	var clean_text := text.strip_edges()
	if _active_dialogue.is_empty() or str(_active_dialogue.get("dialogue_kind", "")) != "npc_npc":
		return _failure("npc_dialogue_not_started", "当前没有进行中的 NPC-NPC 对话。")
	if clean_text.is_empty():
		return _failure("empty_message", "NPC 对话内容不能为空。")
	var next_round := int(_active_dialogue.get("current_round", 0)) + 1
	if next_round > int(_active_dialogue.get("max_rounds", NPC_DIALOGUE_MAX_ROUNDS)):
		return _failure("round_limit_reached", "NPC-NPC 对话已达到最大轮次。")
	_active_dialogue["waiting"] = true
	dialogue_updated.emit(get_dialogue_state())
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null:
		_active_dialogue["waiting"] = false
		return _failure("llm_bridge_missing", "LLMBridge 不可用。")
	var speaker_id := str(_active_dialogue.get("speaker_npc_id", ""))
	var speaker_name := str(_active_dialogue.get("speaker_name", speaker_id))
	var target_id := str(_active_dialogue.get("target_npc_id", ""))
	var target_name := str(_active_dialogue.get("target_npc_name", target_id))
	var result: Dictionary = llm_bridge.request_npc_dialogue(target_id, clean_text, {
		"dialogue_kind": "npc_npc",
		"speaker_kind": "npc",
		"speaker_npc_id": speaker_id,
		"speaker_name": speaker_name,
		"current_round": next_round,
		"max_rounds": int(_active_dialogue.get("max_rounds", NPC_DIALOGUE_MAX_ROUNDS)),
		"conversation_history": _active_dialogue.get("history", []).duplicate(true),
		"dialogue_state": {
			"visibility": str(_active_dialogue.get("visibility", "local_public")),
			"location_id": str(_active_dialogue.get("location_id", "plaza")),
			"location_name": str(_active_dialogue.get("location_name", "广场")),
			"participants": [speaker_id, target_id]
		}
	})
	_active_dialogue["waiting"] = false
	if not bool(result.get("ok", false)):
		_active_dialogue["last_error"] = str(result.get("message", "后端请求失败。"))
		dialogue_updated.emit(get_dialogue_state())
		return result
	var response: Dictionary = result.get("dialogue", {})
	var reply_text := str(response.get("reply_text", "")).strip_edges()
	if reply_text.is_empty():
		_active_dialogue["last_error"] = "后端没有返回 NPC 回复。"
		dialogue_updated.emit(get_dialogue_state())
		return _failure("empty_reply", str(_active_dialogue["last_error"]))
	var speaker_turn := _make_history_turn(speaker_id, speaker_name, target_id, target_name, clean_text)
	var reply_turn := _make_history_turn(target_id, target_name, speaker_id, speaker_name, reply_text)
	var history: Array = _active_dialogue.get("history", [])
	history.append(speaker_turn)
	history.append(reply_turn)
	_active_dialogue["history"] = history
	_active_dialogue["current_round"] = next_round
	_record_dialogue_event("dialogue_turn", {
		"speaker_name": speaker_name,
		"listener_name": target_name,
		"speaker_text": clean_text,
		"reply_text": reply_text,
		"dialogue_text": [speaker_turn, reply_turn],
		"is_recruitment_request": false,
		"recruitment_result": "none",
		"emotion": str(response.get("emotion", "neutral"))
	})
	_active_dialogue["speaker_npc_id"] = target_id
	_active_dialogue["speaker_name"] = target_name
	_active_dialogue["target_npc_id"] = speaker_id
	_active_dialogue["target_npc_name"] = speaker_name
	dialogue_updated.emit(get_dialogue_state())
	if next_round >= int(_active_dialogue.get("max_rounds", NPC_DIALOGUE_MAX_ROUNDS)) or bool(response.get("should_end_dialogue", false)):
		end_dialogue()
	return {"ok": true, "reply_text": reply_text, "dialogue": response.duplicate(true)}


func end_dialogue() -> Dictionary:
	if _active_dialogue.is_empty():
		return {"ok": true}
	var ended_state := get_dialogue_state()
	_active_dialogue.clear()
	dialogue_ended.emit(ended_state)
	if bool(ended_state.get("proactive_talk", false)):
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system != null and npc_system.has_method("request_plan_reevaluation"):
			npc_system.request_plan_reevaluation(str(ended_state.get("target_npc_id", "")), "proactive_dialogue_ended")
	return {"ok": true, "dialogue_state": ended_state}


func get_dialogue_state() -> Dictionary:
	var state := _active_dialogue.duplicate(true)
	if state.is_empty():
		return state
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var target_npc_id := str(state.get("target_npc_id", ""))
	state["target_recruited"] = npc_system != null and bool(npc_system.get_npc(target_npc_id).get("recruited", false))
	return state


func set_dialogue_visibility(visibility: String) -> Dictionary:
	if _active_dialogue.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	if bool(_active_dialogue.get("waiting", false)) or int(_active_dialogue.get("current_round", 0)) > 0:
		return _failure("visibility_locked", "对话开始发送后不能修改公开性。")
	if not ["private", "local_public"].has(visibility):
		return _failure("invalid_visibility", "对话公开性只能是 private 或 local_public。")
	_active_dialogue["visibility"] = visibility
	dialogue_updated.emit(get_dialogue_state())
	return {"ok": true, "dialogue_state": get_dialogue_state()}


func set_recruitment_request_pending(enabled: bool = true) -> Dictionary:
	if _active_dialogue.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	if str(_active_dialogue.get("dialogue_kind", "")) != "player_npc":
		return _failure("invalid_dialogue_kind", "只有守备官与 NPC 对话时可以提出应征。")
	if bool(_active_dialogue.get("waiting", false)):
		return _failure("dialogue_waiting", "正在等待 NPC 回复。")
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
	if npc_system == null or npc_system.get_npc(target_npc_id).is_empty():
		return _failure("npc_not_found", "找不到应征目标。")
	if bool(npc_system.get_npc(target_npc_id).get("recruited", false)):
		return _failure("npc_already_recruited", "该 NPC 已经入伍。")
	_active_dialogue["recruitment_request_pending"] = enabled
	dialogue_updated.emit(get_dialogue_state())
	return {"ok": true, "dialogue_state": get_dialogue_state()}


func is_dialogue_active() -> bool:
	return not _active_dialogue.is_empty()


func _apply_recruitment_result(response: Dictionary, was_recruitment_request: bool) -> String:
	if not was_recruitment_request:
		return "none"
	var recruitment_result := str(response.get("recruitment_result", "none"))
	if not ["accept", "reject"].has(recruitment_result):
		return "none"
	if recruitment_result == "accept":
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if npc_system == null or not npc_system.has_method("set_npc_recruited"):
			_active_dialogue["last_error"] = "NPCSystem 无法应用应征结果。"
			return "none"
		if not npc_system.set_npc_recruited(str(_active_dialogue.get("target_npc_id", "")), true):
			_active_dialogue["last_error"] = "应征状态更新失败。"
			return "none"
	return recruitment_result


func _record_dialogue_event(event_type: String, extra_payload: Dictionary) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or _active_dialogue.is_empty():
		return {}
	var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
	var participant_npc_ids: Array[String] = [target_npc_id]
	var speaker_npc_id := str(_active_dialogue.get("speaker_npc_id", ""))
	if not speaker_npc_id.is_empty() and not participant_npc_ids.has(speaker_npc_id):
		participant_npc_ids.append(speaker_npc_id)
	var payload := {
		"dialogue_id": str(_active_dialogue.get("dialogue_id", "")),
		"dialogue_kind": str(_active_dialogue.get("dialogue_kind", "player_npc")),
		"participant_npc_ids": participant_npc_ids,
		"visibility": str(_active_dialogue.get("visibility", "private")),
		"current_round": int(_active_dialogue.get("current_round", 0)),
		"max_rounds": int(_active_dialogue.get("max_rounds", PLAYER_DIALOGUE_MAX_ROUNDS)),
		"is_recruitment_request": false
	}
	for key in extra_payload.keys():
		payload[key] = extra_payload[key]
	return memory_system.add_event({
		"type": event_type,
		"subject_npc_id": target_npc_id,
		"actor_ids": [GUARD_OFFICER_ID if str(_active_dialogue.get("dialogue_kind", "player_npc")) == "player_npc" else str(_active_dialogue.get("speaker_npc_id", ""))],
		"target_ids": participant_npc_ids,
		"location_id": str(_active_dialogue.get("location_id", "plaza")),
		"visibility": str(_active_dialogue.get("visibility", "private")),
		"importance": 45,
		"payload": payload
	})


func _record_proactive_talk_message(opening_text: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or _active_dialogue.is_empty():
		return {}
	var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
	var npc_name := str(_active_dialogue.get("target_npc_name", target_npc_id))
	return memory_system.add_event({
		"type": "proactive_talk_message",
		"subject_npc_id": target_npc_id,
		"actor_ids": [target_npc_id],
		"target_ids": [target_npc_id, GUARD_OFFICER_ID],
		"location_id": str(_active_dialogue.get("location_id", "plaza")),
		"visibility": str(_active_dialogue.get("visibility", "private")),
		"importance": 50,
		"payload": {
			"dialogue_id": str(_active_dialogue.get("dialogue_id", "")),
			"participant_npc_ids": [target_npc_id],
			"speaker_name": npc_name,
			"listener_name": GUARD_OFFICER_NAME,
			"speaker_text": opening_text,
			"visibility": str(_active_dialogue.get("visibility", "private")),
			"current_round": int(_active_dialogue.get("current_round", 0)),
			"max_rounds": int(_active_dialogue.get("max_rounds", PLAYER_DIALOGUE_MAX_ROUNDS))
		}
	})


func _make_history_turn(speaker_id: String, speaker_name: String, listener_id: String, listener_name: String, text: String) -> Dictionary:
	return {
		"speaker_id": speaker_id,
		"speaker_name": speaker_name,
		"listener_id": listener_id,
		"listener_name": listener_name,
		"text": text,
		"visibility": str(_active_dialogue.get("visibility", "private"))
	}


func _failure(error_code: String, message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "message": message}
