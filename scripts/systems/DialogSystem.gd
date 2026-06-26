extends Node

signal dialogue_started(dialogue_state: Dictionary)
signal dialogue_updated(dialogue_state: Dictionary)
signal dialogue_ended(dialogue_state: Dictionary)

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const GUARD_OFFICER_ID := "guard_officer"
const GUARD_OFFICER_NAME := "守备官"
const PLAYER_DIALOGUE_MAX_ROUNDS := 999999
const NPC_DIALOGUE_MAX_ROUNDS := 5
const DEFAULT_ATTACK_DAMAGE := 10
const GUARD_ATTACK_EVENT_TEXT := "守备官攻击了你以示惩戒"
const GUARD_ATTACK_PROMPT := "守备官攻击了你以示惩戒，你要说些什么？"
const WARTIME_DIALOGUE_CONTEXTS: Array[String] = ["rally", "combat", "avoid_combat"]
const WARTIME_REACTIONS: Array[String] = ["none", "escape", "morale_boost"]

var _dialogue_counter := 0
var _active_dialogue: Dictionary = {}


func initialize() -> void:
	_active_dialogue.clear()


func _ready() -> void:
	initialize()
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge != null and llm_bridge.has_signal("dialogue_async_response_received"):
		llm_bridge.dialogue_async_response_received.connect(_on_dialogue_async_response_received)


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
	if npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(npc_id):
		return _failure("npc_deep_sleep", "NPC 正在熟睡，无法打断。")

	if not _active_dialogue.is_empty():
		end_dialogue()
	_dialogue_counter += 1
	var interaction_context := _get_player_dialogue_interaction_context(npc_id, npc_state, npc_system)
	var force_local_public := WARTIME_DIALOGUE_CONTEXTS.has(interaction_context)
	var clean_visibility := visibility if ["private", "local_public"].has(visibility) else "private"
	if force_local_public:
		clean_visibility = "local_public"
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
		"last_recruitment_result": "none",
		"interaction_context": interaction_context,
		"force_local_public": force_local_public,
		"wartime_dialogue": force_local_public,
		"last_wartime_reaction": "none",
		"last_wartime_result": {},
		"player_dialogue_effect_started": false,
		"completed_player_llm_turns": 0,
		"attack_committed": false,
		"completed_attack_llm_turns": 0,
		"reevaluation_targets_on_end": []
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
	for participant_id in [speaker_npc_id, target_npc_id]:
		if npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(str(participant_id)):
			return _failure("npc_deep_sleep", "NPC 正在熟睡，无法打断。")
	if not _active_dialogue.is_empty():
		_cancel_active_dialogue_llm_requests("npc_dialogue_replaced")
		end_dialogue()
	var interrupted_targets: Array[String] = []
	for participant_id in [speaker_npc_id, target_npc_id]:
		var cancel_result := _cancel_npc_llm_request(str(participant_id), "npc_dialogue_started")
		if not bool(cancel_result.get("ok", true)):
			return cancel_result
		if _interrupt_for_dialogue(str(participant_id)):
			interrupted_targets.append(str(participant_id))
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
		"last_error": "",
		"reevaluation_targets_on_end": interrupted_targets
	}
	dialogue_started.emit(get_dialogue_state())
	return {"ok": true, "dialogue_state": get_dialogue_state()}


func send_player_message(text: String, is_recruitment_request: bool = false, async_request: bool = false) -> Dictionary:
	var clean_text := text.strip_edges()
	if _active_dialogue.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	if clean_text.is_empty():
		return _failure("empty_message", "请输入对话内容。")
	if bool(_active_dialogue.get("waiting", false)):
		return _failure("dialogue_waiting", "正在等待 NPC 回复。")
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
	if npc_system != null and npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(target_npc_id):
		return _failure("npc_deep_sleep", "NPC 正在熟睡，无法继续对话。")

	var effect_result := _ensure_player_dialogue_effect_started("player_message_sent")
	if not bool(effect_result.get("ok", false)):
		return effect_result

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

	var request_options := {
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
		},
		"interaction_context": str(_active_dialogue.get("interaction_context", "work"))
	}
	var pending := {
		"kind": "player_message",
		"clean_text": clean_text,
		"next_round": next_round,
		"effective_recruitment_request": effective_recruitment_request
	}
	if async_request and llm_bridge.has_method("request_npc_dialogue_async"):
		var request_id := "%s_player_%d" % [str(_active_dialogue.get("dialogue_id", "dialogue")), next_round]
		request_options["request_id"] = request_id
		pending["request_id"] = request_id
		_active_dialogue["pending_llm"] = pending.duplicate(true)
		var async_result: Dictionary = llm_bridge.request_npc_dialogue_async(str(_active_dialogue.get("target_npc_id", "")), clean_text, request_options)
		if not bool(async_result.get("ok", false)):
			_active_dialogue.erase("pending_llm")
			_active_dialogue["waiting"] = false
			_active_dialogue["last_error"] = str(async_result.get("message", "后端请求失败。"))
			dialogue_updated.emit(get_dialogue_state())
			return async_result
		return {"ok": true, "pending": true, "request_id": request_id, "dialogue_state": get_dialogue_state()}

	var result: Dictionary = llm_bridge.request_npc_dialogue(str(_active_dialogue.get("target_npc_id", "")), clean_text, request_options)
	return _apply_player_message_response(result, pending)


func _apply_player_message_response(result: Dictionary, pending: Dictionary) -> Dictionary:
	_active_dialogue["waiting"] = false
	_active_dialogue.erase("pending_llm")
	if not bool(result.get("ok", false)):
		if bool(_active_dialogue.get("wartime_dialogue", false)):
			result = {
				"ok": true,
				"dialogue": _make_wartime_rule_fallback_response(pending, result)
			}
		else:
			_active_dialogue["last_error"] = str(result.get("message", "后端请求失败。"))
			dialogue_updated.emit(get_dialogue_state())
			return result

	var response: Dictionary = result.get("dialogue", {})
	var reply_text := str(response.get("reply_text", "")).strip_edges()
	if reply_text.is_empty():
		_active_dialogue["last_error"] = "后端没有返回 NPC 回复。"
		dialogue_updated.emit(get_dialogue_state())
		return _failure("empty_reply", str(_active_dialogue["last_error"]))

	var effective_recruitment_request := bool(pending.get("effective_recruitment_request", false))
	var recruitment_result := _apply_recruitment_result(response, effective_recruitment_request)
	_active_dialogue["last_recruitment_result"] = recruitment_result
	var npc_name := str(_active_dialogue.get("target_npc_name", "NPC"))
	var clean_text := str(pending.get("clean_text", ""))
	var player_turn := _make_history_turn(GUARD_OFFICER_ID, GUARD_OFFICER_NAME, str(_active_dialogue.get("target_npc_id", "")), npc_name, clean_text)
	var npc_turn := _make_history_turn(str(_active_dialogue.get("target_npc_id", "")), npc_name, GUARD_OFFICER_ID, GUARD_OFFICER_NAME, reply_text)
	var history: Array = _active_dialogue.get("history", [])
	history.append(player_turn)
	history.append(npc_turn)
	_active_dialogue["history"] = history
	_active_dialogue["current_round"] = int(pending.get("next_round", int(_active_dialogue.get("current_round", 0)) + 1))
	_active_dialogue["completed_player_llm_turns"] = int(_active_dialogue.get("completed_player_llm_turns", 0)) + 1
	var dialogue_event := _record_dialogue_event("dialogue_turn", {
		"speaker_name": GUARD_OFFICER_NAME,
		"listener_name": npc_name,
		"speaker_text": clean_text,
		"reply_text": reply_text,
		"dialogue_text": [player_turn, npc_turn],
		"is_recruitment_request": effective_recruitment_request,
		"recruitment_result": recruitment_result,
		"emotion": str(response.get("emotion", "neutral")),
		"interaction_context": str(_active_dialogue.get("interaction_context", "work")),
		"wartime_reaction": _normalize_wartime_reaction(str(response.get("wartime_reaction", "none")))
	})
	var wartime_result := _apply_wartime_reaction(response, dialogue_event)
	dialogue_updated.emit(get_dialogue_state())
	return {
		"ok": true,
		"reply_text": reply_text,
		"dialogue": response.duplicate(true),
		"wartime_result": wartime_result,
		"dialogue_state": get_dialogue_state()
	}


func attack_target_npc(damage: int = DEFAULT_ATTACK_DAMAGE, async_request: bool = false) -> Dictionary:
	if _active_dialogue.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	if str(_active_dialogue.get("dialogue_kind", "")) != "player_npc":
		return _failure("invalid_dialogue_kind", "只有守备官与 NPC 对话时可以攻击。")
	if bool(_active_dialogue.get("waiting", false)):
		return _failure("dialogue_waiting", "正在等待 NPC 回复。")
	if damage <= 0:
		return _failure("invalid_damage", "攻击伤害必须为正数。")

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("apply_damage_to_npc"):
		return _failure("npc_system_missing", "NPCSystem 不可用。")
	var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
	if npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(target_npc_id):
		return _failure("npc_deep_sleep", "NPC 正在熟睡，无法攻击或对话。")

	var effect_result := _ensure_player_dialogue_effect_started("player_attack")
	if not bool(effect_result.get("ok", false)):
		return effect_result

	var npc_name := str(_active_dialogue.get("target_npc_name", target_npc_id))
	var attack_summary := "守备官攻击了%s以示惩戒，造成%d点伤害。" % [npc_name, damage]
	var damage_result: Dictionary = npc_system.apply_damage_to_npc(
		target_npc_id,
		damage,
		GUARD_OFFICER_ID,
		str(_active_dialogue.get("visibility", "private")),
		{
			"request_plan_reevaluation": false,
			"summary": attack_summary,
			"interaction_kind": "guard_punishment_attack",
			"event_text": GUARD_ATTACK_EVENT_TEXT,
			"attack_prompt": GUARD_ATTACK_PROMPT
		}
	)
	if not bool(damage_result.get("ok", false)):
		return _failure("damage_failed", str(damage_result.get("message", "攻击失败。")))

	_active_dialogue["attack_committed"] = true
	_add_reevaluation_target_on_end(target_npc_id)
	var damage_event: Dictionary = damage_result.get("damage_event", {}) if (damage_result.get("damage_event", {}) is Dictionary) else {}
	var attack_event_id := str(damage_event.get("id", ""))
	var next_round := int(_active_dialogue.get("current_round", 0)) + 1
	var attack_turn := _make_history_turn(GUARD_OFFICER_ID, GUARD_OFFICER_NAME, target_npc_id, npc_name, GUARD_ATTACK_EVENT_TEXT)
	var history_before: Array = _active_dialogue.get("history", []).duplicate(true)
	history_before.append(attack_turn)

	if bool(damage_result.get("unconscious", false)):
		var history_unconscious: Array = _active_dialogue.get("history", [])
		history_unconscious.append(attack_turn)
		_active_dialogue["history"] = history_unconscious
		_active_dialogue["last_error"] = "NPC 已昏迷，无法回应。"
		dialogue_updated.emit(get_dialogue_state())
		return {"ok": true, "damage": damage_result, "dialogue_state": get_dialogue_state()}

	_active_dialogue["waiting"] = true
	_active_dialogue["last_error"] = ""
	dialogue_updated.emit(get_dialogue_state())
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null:
		_active_dialogue["waiting"] = false
		_active_dialogue["last_error"] = "LLMBridge 不可用。"
		dialogue_updated.emit(get_dialogue_state())
		return _failure("llm_bridge_missing", str(_active_dialogue["last_error"]))

	var request_options := {
		"dialogue_kind": "player_npc",
		"current_round": next_round,
		"max_rounds": int(_active_dialogue.get("max_rounds", PLAYER_DIALOGUE_MAX_ROUNDS)),
		"is_recruitment_request": false,
		"related_event_id": attack_event_id,
		"conversation_history": history_before,
		"constraints": [
			"本轮是守备官攻击 NPC 后的即时反应，不是普通闲聊。",
			"攻击者固定为守备官；NPC 只能表达感受、回应或态度，不能改变 HP、资源、建筑或行动权威结果。"
		],
		"dialogue_state": {
			"visibility": str(_active_dialogue.get("visibility", "private")),
			"location_id": str(_active_dialogue.get("location_id", "plaza")),
			"location_name": str(_active_dialogue.get("location_name", "广场")),
			"participants": [GUARD_OFFICER_ID, target_npc_id]
		},
		"interaction_context": str(_active_dialogue.get("interaction_context", "work"))
	}
	var pending := {
		"kind": "guard_attack",
		"target_npc_id": target_npc_id,
		"npc_name": npc_name,
		"attack_turn": attack_turn,
		"attack_event_id": attack_event_id,
		"next_round": next_round,
		"damage": damage_result
	}
	if async_request and llm_bridge.has_method("request_npc_dialogue_async"):
		var request_id := "%s_attack_%d" % [str(_active_dialogue.get("dialogue_id", "dialogue")), next_round]
		request_options["request_id"] = request_id
		pending["request_id"] = request_id
		_active_dialogue["pending_llm"] = pending.duplicate(true)
		var async_result: Dictionary = llm_bridge.request_npc_dialogue_async(target_npc_id, GUARD_ATTACK_PROMPT, request_options)
		if not bool(async_result.get("ok", false)):
			_active_dialogue.erase("pending_llm")
			_active_dialogue["waiting"] = false
			_active_dialogue["last_error"] = str(async_result.get("message", "后端请求失败。"))
			dialogue_updated.emit(get_dialogue_state())
			return async_result
		return {"ok": true, "pending": true, "damage": damage_result, "request_id": request_id, "dialogue_state": get_dialogue_state()}

	var result: Dictionary = llm_bridge.request_npc_dialogue(target_npc_id, GUARD_ATTACK_PROMPT, request_options)
	return _apply_attack_response(result, pending)


func _apply_attack_response(result: Dictionary, pending: Dictionary) -> Dictionary:
	if _active_dialogue.is_empty():
		return result
	_active_dialogue["waiting"] = false
	_active_dialogue.erase("pending_llm")
	if not bool(result.get("ok", false)):
		if bool(_active_dialogue.get("wartime_dialogue", false)):
			result = {
				"ok": true,
				"dialogue": _make_wartime_rule_fallback_response(pending, result)
			}
		else:
			_active_dialogue["last_error"] = str(result.get("message", "后端请求失败。"))
			dialogue_updated.emit(get_dialogue_state())
			return result

	var response: Dictionary = result.get("dialogue", {})
	var reply_text := str(response.get("reply_text", "")).strip_edges()
	if reply_text.is_empty():
		_active_dialogue["last_error"] = "后端没有返回 NPC 回复。"
		dialogue_updated.emit(get_dialogue_state())
		return _failure("empty_reply", str(_active_dialogue["last_error"]))

	var target_npc_id := str(pending.get("target_npc_id", _active_dialogue.get("target_npc_id", "")))
	var npc_name := str(pending.get("npc_name", _active_dialogue.get("target_npc_name", target_npc_id)))
	var attack_turn: Dictionary = pending.get("attack_turn", {})
	if attack_turn.is_empty():
		attack_turn = _make_history_turn(GUARD_OFFICER_ID, GUARD_OFFICER_NAME, target_npc_id, npc_name, GUARD_ATTACK_EVENT_TEXT)
	var attack_event_id := str(pending.get("attack_event_id", ""))
	var npc_turn := _make_history_turn(target_npc_id, npc_name, GUARD_OFFICER_ID, GUARD_OFFICER_NAME, reply_text)
	var history: Array = _active_dialogue.get("history", [])
	history.append(attack_turn)
	history.append(npc_turn)
	_active_dialogue["history"] = history
	_active_dialogue["current_round"] = int(pending.get("next_round", int(_active_dialogue.get("current_round", 0)) + 1))
	_active_dialogue["completed_attack_llm_turns"] = int(_active_dialogue.get("completed_attack_llm_turns", 0)) + 1
	var dialogue_event := _record_dialogue_event("dialogue_turn", {
		"speaker_name": GUARD_OFFICER_NAME,
		"listener_name": npc_name,
		"speaker_text": GUARD_ATTACK_EVENT_TEXT,
		"reply_text": reply_text,
		"dialogue_text": [attack_turn, npc_turn],
		"is_recruitment_request": false,
		"recruitment_result": "none",
		"emotion": str(response.get("emotion", "neutral")),
		"interaction_kind": "guard_attack",
		"related_event_id": attack_event_id,
		"interaction_context": str(_active_dialogue.get("interaction_context", "work")),
		"wartime_reaction": _normalize_wartime_reaction(str(response.get("wartime_reaction", "none")))
	})
	var wartime_result := _apply_wartime_reaction(response, dialogue_event)
	dialogue_updated.emit(get_dialogue_state())
	return {
		"ok": true,
		"damage": pending.get("damage", {}),
		"reply_text": reply_text,
		"dialogue": response.duplicate(true),
		"wartime_result": wartime_result,
		"dialogue_state": get_dialogue_state()
	}


func _on_dialogue_async_response_received(result: Dictionary) -> void:
	if _active_dialogue.is_empty():
		return
	var pending: Dictionary = _active_dialogue.get("pending_llm", {}) if (_active_dialogue.get("pending_llm", {}) is Dictionary) else {}
	if pending.is_empty():
		return
	var request_id := str(result.get("request_id", ""))
	if request_id.is_empty() or request_id != str(pending.get("request_id", "")):
		return
	match str(pending.get("kind", "")):
		"player_message":
			_apply_player_message_response(result, pending)
		"guard_attack":
			_apply_attack_response(result, pending)
		_:
			_active_dialogue["waiting"] = false
			_active_dialogue.erase("pending_llm")
			_active_dialogue["last_error"] = str(result.get("message", "未知对话请求已结束。"))
			dialogue_updated.emit(get_dialogue_state())


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
	_cancel_active_dialogue_llm_requests("dialogue_ended")
	_active_dialogue.clear()
	dialogue_ended.emit(ended_state)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("request_plan_reevaluation"):
		if bool(ended_state.get("proactive_talk", false)):
			npc_system.request_plan_reevaluation(str(ended_state.get("target_npc_id", "")), "proactive_dialogue_ended")
		var should_reevaluate_interrupted := (
			int(ended_state.get("completed_player_llm_turns", 0)) > 0
			or bool(ended_state.get("attack_committed", false))
			or (
				str(ended_state.get("dialogue_kind", "")) == "npc_npc"
				and int(ended_state.get("current_round", 0)) > 0
			)
		)
		if should_reevaluate_interrupted:
			var reevaluation_targets: Array = ended_state.get("reevaluation_targets_on_end", [])
			for raw_npc_id in reevaluation_targets:
				var target_id := str(raw_npc_id)
				if target_id.is_empty():
					continue
				var reason := "guard_attack" if bool(ended_state.get("attack_committed", false)) else "dialogue_interrupted"
				npc_system.request_plan_reevaluation(target_id, reason)
	return {"ok": true, "dialogue_state": ended_state}


func force_end_dialogue_for_npc(npc_id: String, reason: String = "behavior_mode_changed") -> Dictionary:
	if _active_dialogue.is_empty():
		return {"ok": true, "ended": false, "reason": "no_active_dialogue"}
	var participant_ids: Array[String] = []
	var target_id := str(_active_dialogue.get("target_npc_id", ""))
	if not target_id.is_empty():
		participant_ids.append(target_id)
	var speaker_id := str(_active_dialogue.get("speaker_npc_id", ""))
	if not speaker_id.is_empty() and not participant_ids.has(speaker_id):
		participant_ids.append(speaker_id)
	if not participant_ids.has(npc_id):
		return {"ok": true, "ended": false, "reason": "npc_not_in_dialogue"}
	var ended_state := get_dialogue_state()
	ended_state["forced_end_reason"] = reason
	_cancel_active_dialogue_llm_requests(reason)
	_active_dialogue.clear()
	dialogue_ended.emit(ended_state)
	return {
		"ok": true,
		"ended": true,
		"npc_id": npc_id,
		"reason": reason,
		"dialogue_state": ended_state
	}


func _ensure_player_dialogue_effect_started(reason: String) -> Dictionary:
	if _active_dialogue.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	if str(_active_dialogue.get("dialogue_kind", "")) != "player_npc":
		return {"ok": true, "already_started": true}
	if bool(_active_dialogue.get("player_dialogue_effect_started", false)):
		return {"ok": true, "already_started": true}
	var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
	var cancel_result := _cancel_npc_llm_request(target_npc_id, reason)
	if not bool(cancel_result.get("ok", true)):
		return cancel_result
	if _interrupt_for_dialogue(target_npc_id):
		_add_reevaluation_target_on_end(target_npc_id)
	_active_dialogue["player_dialogue_effect_started"] = true
	return {"ok": true, "already_started": false, "cancel_result": cancel_result}


func _add_reevaluation_target_on_end(npc_id: String) -> void:
	if npc_id.is_empty() or _active_dialogue.is_empty():
		return
	var targets: Array = _active_dialogue.get("reevaluation_targets_on_end", [])
	if not targets.has(npc_id):
		targets.append(npc_id)
	_active_dialogue["reevaluation_targets_on_end"] = targets


func _interrupt_for_dialogue(npc_id: String) -> bool:
	if npc_id.is_empty():
		return false
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return false
	if npc_system.has_method("is_first_sleep_summary_locked") and npc_system.is_first_sleep_summary_locked(npc_id):
		return false
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var current_action := str(state.get("current_action", ""))
	if current_action.is_empty() or current_action == "idle":
		return false
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("interrupt_npc_action"):
		return false
	return action_system.interrupt_npc_action(npc_id, "dialogue_interrupted")


func _cancel_npc_llm_request(npc_id: String, reason: String) -> Dictionary:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("cancel_npc_llm_requests"):
		return {"ok": true, "cancelled": false}
	return llm_bridge.cancel_npc_llm_requests(npc_id, reason)


func _cancel_active_dialogue_llm_requests(reason: String) -> void:
	if _active_dialogue.is_empty():
		return
	var participant_ids: Array[String] = []
	var target_id := str(_active_dialogue.get("target_npc_id", ""))
	if not target_id.is_empty():
		participant_ids.append(target_id)
	var speaker_id := str(_active_dialogue.get("speaker_npc_id", ""))
	if not speaker_id.is_empty() and not participant_ids.has(speaker_id):
		participant_ids.append(speaker_id)
	for participant_id in participant_ids:
		_cancel_npc_llm_request(participant_id, reason)


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
	if bool(_active_dialogue.get("force_local_public", false)):
		_active_dialogue["visibility"] = "local_public"
		dialogue_updated.emit(get_dialogue_state())
		return _failure("visibility_forced_local_public", "战时对话必须保持同地点公开。")
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


func _get_player_dialogue_interaction_context(npc_id: String, npc_state: Dictionary, npc_system: Node) -> String:
	var mode := str(npc_state.get("behavior_mode", ""))
	if npc_system != null and npc_system.has_method("get_npc_behavior_mode_snapshot"):
		var snapshot: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
		mode = str(snapshot.get("behavior_mode", mode))
	if mode.is_empty():
		mode = str(npc_state.get("combat_mode", ""))
	if WARTIME_DIALOGUE_CONTEXTS.has(mode):
		return mode
	return "work"


func _normalize_wartime_reaction(reaction: String) -> String:
	var clean_reaction := reaction.strip_edges()
	if WARTIME_REACTIONS.has(clean_reaction):
		return clean_reaction
	return "none"


func _make_wartime_rule_fallback_response(pending: Dictionary, error_result: Dictionary) -> Dictionary:
	var clean_text := str(pending.get("clean_text", GUARD_ATTACK_EVENT_TEXT))
	var reaction := "none"
	if _text_contains_any(clean_text, ["逃", "跑", "撤", "保命", "自己活", "别管"]):
		reaction = "escape"
	elif _text_contains_any(clean_text, ["守住", "保护", "坚持", "撑住", "拦住", "挡住", "一起", "别怕"]):
		reaction = "morale_boost"
	var recruitment_result := "none"
	if bool(pending.get("effective_recruitment_request", false)):
		recruitment_result = "accept" if _text_contains_any(clean_text, ["应征", "入伍", "守住", "保护", "帮忙", "一起", "救"]) else "reject"
	return {
		"replyer_id": str(_active_dialogue.get("target_npc_id", "")),
		"reply_text": "守备官，我听见了。现在先按你说的做。",
		"emotion": "tense",
		"attitude_delta": 0,
		"relationship_delta": 0,
		"recruitment_result": recruitment_result,
		"wartime_reaction": reaction,
		"should_end_dialogue": false,
		"rule_fallback": true,
		"fallback_error_code": str(error_result.get("error_code", "")),
		"fallback_message": str(error_result.get("message", "后端请求失败。"))
	}


func _text_contains_any(text: String, keywords: Array[String]) -> bool:
	for keyword in keywords:
		if text.find(keyword) >= 0:
			return true
	return false


func _apply_wartime_reaction(response: Dictionary, dialogue_event: Dictionary) -> Dictionary:
	if _active_dialogue.is_empty() or not bool(_active_dialogue.get("wartime_dialogue", false)):
		return {}
	var interaction_context := str(_active_dialogue.get("interaction_context", "work"))
	var reaction := _normalize_wartime_reaction(str(response.get("wartime_reaction", "none")))
	if reaction == "none" and interaction_context == "avoid_combat":
		return {}
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("apply_wartime_dialogue_reaction"):
		return {}
	var result: Dictionary = combat_system.apply_wartime_dialogue_reaction(str(_active_dialogue.get("target_npc_id", "")), reaction, {
		"source_event_id": str(dialogue_event.get("event_id", "")),
		"dialogue_id": str(_active_dialogue.get("dialogue_id", "")),
		"interaction_context": interaction_context
	})
	_active_dialogue["last_wartime_reaction"] = reaction
	_active_dialogue["last_wartime_result"] = result.duplicate(true)
	return result


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
