extends Node

signal dialogue_started(dialogue_state: Dictionary)
signal dialogue_updated(dialogue_state: Dictionary)
signal dialogue_ended(dialogue_state: Dictionary)

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const EVENT_BUS_PATH := "/root/EventBus"
const GUARD_OFFICER_ID := "guard_officer"
const GUARD_OFFICER_NAME := "守备官"
const PLAYER_DIALOGUE_MAX_ROUNDS := 999999
const NPC_DIALOGUE_NO_HARD_ROUND_LIMIT := 0
const NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD := 5
const ESCAPE_INTERVENTION_MAX_ROUNDS := 5
const SUSPENDED_DIALOGUE_MAX_SECONDS := 2.0 * 60.0 * 60.0
const ESCAPE_INTERVENTION_DIALOGUE_KIND := "escape_intervention"
const DEFAULT_ATTACK_DAMAGE := 10
const GUARD_ATTACK_EVENT_TEXT := "守备官攻击了你以示惩戒"
const GUARD_ATTACK_PROMPT := "守备官攻击了你以示惩戒，你要说些什么？"
const WARTIME_DIALOGUE_CONTEXTS: Array[String] = ["rally", "combat", "avoid_combat"]
const WARTIME_REACTIONS: Array[String] = ["none", "escape", "morale_boost"]

var _dialogue_counter := 0
var _active_dialogue: Dictionary = {}
var _player_dialogue_draft: Dictionary = {}
var _pending_forced_end_dialogue_id := ""
var _dialogue_epoch_by_npc: Dictionary = {}
var _dialogue_end_in_progress := false


func initialize() -> void:
	_active_dialogue.clear()
	_player_dialogue_draft.clear()
	_pending_forced_end_dialogue_id = ""
	_dialogue_epoch_by_npc.clear()
	_dialogue_end_in_progress = false


func _ready() -> void:
	initialize()
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge != null and llm_bridge.has_signal("dialogue_async_response_received"):
		llm_bridge.dialogue_async_response_received.connect(_on_dialogue_async_response_received)
	var event_bus := get_node_or_null(EVENT_BUS_PATH)
	if event_bus != null and event_bus.has_signal("npc_state_changed"):
		event_bus.npc_state_changed.connect(_on_npc_state_changed)
	if event_bus != null and event_bus.has_signal("logical_time_tick"):
		event_bus.logical_time_tick.connect(_on_logical_time_tick)


func start_player_dialogue(npc_id: String, visibility: String = "private") -> Dictionary:
	if not _active_dialogue.is_empty() and _is_player_controlled_dialogue(_active_dialogue):
		if bool(_active_dialogue.get("suspended", false)):
			if str(_active_dialogue.get("target_npc_id", "")) == npc_id:
				return resume_suspended_player_dialogue(npc_id)
			return _failure("dialogue_busy", "已有守备官对话正在挂起，请先完成、取消或恢复该会话。")
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return _failure("npc_system_missing", "NPCSystem 不可用。")
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _failure("npc_not_found", "找不到 NPC：%s。" % npc_id)
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	if bool(npc_state.get("unconscious", false)):
		return _failure("npc_unconscious", "昏迷中的 NPC 无法对话。")
	if _is_npc_plan_request_active(npc_id, npc_system):
		return _failure("npc_planning", "NPC正在思考，暂时无法对话。")
	if _is_active_escape_dialogue_target(npc_state):
		return start_escape_intervention_dialogue(npc_id)
	if npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(npc_id):
		return _failure("npc_deep_sleep", "NPC 正在熟睡，无法打断。")

	_dialogue_counter += 1
	var interaction_context := _get_player_dialogue_interaction_context(npc_id, npc_state, npc_system)
	var force_local_public := WARTIME_DIALOGUE_CONTEXTS.has(interaction_context)
	var clean_visibility := visibility if ["private", "local_public"].has(visibility) else "private"
	if force_local_public:
		clean_visibility = "local_public"
	var player_dialogue_state := {
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
		"ui_visible": true,
		"suspended": false,
		"suspended_remaining_seconds": 0.0,
		"session_status": "draft",
		"last_error": "",
		"recruitment_request_pending": false,
		"last_recruitment_result": "none",
		"interaction_context": interaction_context,
		"force_local_public": force_local_public,
		"wartime_dialogue": force_local_public,
		"last_wartime_reaction": "none",
		"last_wartime_result": {},
		"player_dialogue_effect_started": false,
		"player_dialogue_interrupted_action": false,
		"player_dialogue_interrupted_action_id": "",
		"interrupted_activity_context": {},
		"completed_player_llm_turns": 0,
		"attack_committed": false,
		"completed_attack_llm_turns": 0,
		"session_had_recruitment_request": false,
		"deferred_recruitment_result": "none",
		"deferred_wartime_response": {},
		"deferred_escape_response": {},
		"last_player_text": "",
		"last_reply_text": "",
		"dialogue_initiator": "guard_officer",
		"interrupted_plan_action_by_npc": {}
	}
	if not _player_dialogue_draft.is_empty():
		var replaced_draft := _decorate_dialogue_state(_player_dialogue_draft)
		replaced_draft["end_reason"] = "player_dialogue_view_replaced"
		dialogue_ended.emit(replaced_draft)
	_player_dialogue_draft = player_dialogue_state
	var draft_state := get_display_dialogue_state()
	dialogue_started.emit(draft_state)
	return {"ok": true, "dialogue_state": draft_state, "view_only_until_send": true}


func start_escape_intervention_dialogue(npc_id: String) -> Dictionary:
	if not _active_dialogue.is_empty() and _is_player_controlled_dialogue(_active_dialogue):
		if bool(_active_dialogue.get("suspended", false)):
			if str(_active_dialogue.get("target_npc_id", "")) == npc_id:
				return resume_suspended_player_dialogue(npc_id)
			return _failure("dialogue_busy", "已有守备官对话正在挂起，请先完成、取消或恢复该会话。")
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return _failure("npc_system_missing", "NPCSystem 不可用。")
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _failure("npc_not_found", "找不到 NPC：%s。" % npc_id)
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	if bool(npc_state.get("unconscious", false)):
		return _failure("npc_unconscious", "昏迷中的 NPC 无法挽留。")
	if _is_npc_plan_request_active(npc_id, npc_system):
		return _failure("npc_planning", "NPC正在思考，暂时无法对话。")
	if not _is_active_escape_dialogue_target(npc_state):
		return _failure("escape_not_active", "该 NPC 当前没有正在逃离。")
	var escape_intent: Dictionary = npc_state.get("escape_intent", {}) if npc_state.get("escape_intent", {}) is Dictionary else {}
	var rounds_used := clampi(int(escape_intent.get("intervention_rounds_used", 0)), 0, ESCAPE_INTERVENTION_MAX_ROUNDS)
	var max_rounds := clampi(int(escape_intent.get("intervention_max_rounds", ESCAPE_INTERVENTION_MAX_ROUNDS)), 1, ESCAPE_INTERVENTION_MAX_ROUNDS)
	if rounds_used >= max_rounds:
		return _failure("round_limit_reached", "逃离挽留对话已达到 5 轮上限。")
	if not _player_dialogue_draft.is_empty():
		end_displayed_dialogue(str(_player_dialogue_draft.get("dialogue_id", "")))
	if not _active_dialogue.is_empty():
		_cancel_active_dialogue_llm_requests("escape_intervention_started")
		end_dialogue()
	_dialogue_counter += 1
	var dialogue_id := "dialogue_%d_%04d" % [Time.get_ticks_msec(), _dialogue_counter]
	var pause_result := _pause_escape_for_dialogue(npc_id, dialogue_id)
	if not bool(pause_result.get("ok", false)):
		return pause_result
	_active_dialogue = {
		"dialogue_id": dialogue_id,
		"dialogue_kind": ESCAPE_INTERVENTION_DIALOGUE_KIND,
		"target_npc_id": npc_id,
		"target_npc_name": str(npc.get("name", npc_id)),
		"speaker_npc_id": "",
		"speaker_name": GUARD_OFFICER_NAME,
		"visibility": "local_public",
		"location_id": str(npc_state.get("current_location", "plaza")),
		"location_name": str(npc_state.get("current_location_name", "广场")),
		"current_round": rounds_used,
		"max_rounds": max_rounds,
		"history": [],
		"waiting": false,
		"ui_visible": true,
		"suspended": false,
		"suspended_remaining_seconds": 0.0,
		"session_status": "active",
		"last_error": "",
		"recruitment_request_pending": false,
		"last_recruitment_result": "none",
		"interaction_context": ESCAPE_INTERVENTION_DIALOGUE_KIND,
		"force_local_public": true,
		"wartime_dialogue": false,
		"escape_intervention": true,
		"escape_pause_result": pause_result.duplicate(true),
		"last_escape_intervention_result": {},
		"player_dialogue_effect_started": true,
		"completed_player_llm_turns": 0,
		"attack_committed": false,
		"completed_attack_llm_turns": 0,
		"session_had_recruitment_request": false,
		"deferred_recruitment_result": "none",
		"deferred_wartime_response": {},
		"deferred_escape_response": {},
		"last_player_text": "",
		"last_reply_text": "",
		"dialogue_initiator": "guard_officer",
		"interrupted_plan_action_by_npc": {}
	}
	_ensure_active_dialogue_epoch_for_npc(npc_id)
	_set_player_dialogue_npc_runtime_state(false)
	dialogue_started.emit(get_dialogue_state())
	return {"ok": true, "dialogue_state": get_dialogue_state()}


func start_proactive_player_dialogue(npc_id: String, opening_text: String, visibility: String = "private") -> Dictionary:
	var start_result := start_player_dialogue(npc_id, visibility)
	if not bool(start_result.get("ok", false)):
		return start_result
	var started_dialogue_state: Dictionary = (
		start_result.get("dialogue_state", {})
		if start_result.get("dialogue_state", {}) is Dictionary
		else {}
	)
	var started_dialogue_id := str(started_dialogue_state.get("dialogue_id", ""))
	var activation_result := _activate_player_dialogue_draft("proactive_dialogue_started")
	if not bool(activation_result.get("ok", false)):
		_discard_player_dialogue_draft(
			started_dialogue_id,
			"proactive_dialogue_activation_failed"
		)
		return activation_result
	var activated_dialogue_state: Dictionary = (
		activation_result.get("dialogue_state", {})
		if activation_result.get("dialogue_state", {}) is Dictionary
		else {}
	)
	if (
		not bool(activation_result.get("activated", false))
		or started_dialogue_id.is_empty()
		or str(activated_dialogue_state.get("dialogue_id", "")) != started_dialogue_id
	):
		_discard_player_dialogue_draft(
			started_dialogue_id,
			"proactive_dialogue_activation_lost"
		)
		return _failure(
			"proactive_dialogue_activation_lost",
			"主动交涉在进入对话前失效，请稍后重试。"
		)
	_ensure_active_dialogue_epoch_for_npc(npc_id)
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
	_active_dialogue["dialogue_initiator"] = "npc"
	dialogue_updated.emit(get_dialogue_state())
	return {"ok": true, "dialogue_state": get_dialogue_state()}


func _discard_player_dialogue_draft(dialogue_id: String, reason: String) -> void:
	if (
		_player_dialogue_draft.is_empty()
		or dialogue_id.is_empty()
		or str(_player_dialogue_draft.get("dialogue_id", "")) != dialogue_id
	):
		return
	var ended_draft := _decorate_dialogue_state(_player_dialogue_draft)
	ended_draft["end_reason"] = reason
	ended_draft["completion_mode"] = "cancelled"
	_player_dialogue_draft.clear()
	dialogue_ended.emit(ended_draft)


func start_npc_dialogue(
	speaker_npc_id: String,
	target_npc_id: String,
	visibility: String = "local_public",
	soft_round_threshold: int = NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD,
	options: Dictionary = {}
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return _failure("npc_system_missing", "NPCSystem 不可用。")
	if speaker_npc_id == target_npc_id:
		return _failure("invalid_participants", "NPC 不能与自己对话。")
	var speaker: Dictionary = npc_system.get_npc(speaker_npc_id)
	var target: Dictionary = npc_system.get_npc(target_npc_id)
	if speaker.is_empty() or target.is_empty():
		return _failure("npc_not_found", "找不到 NPC-NPC 对话参与者。")
	var speaker_state: Dictionary = npc_system.get_npc_state(speaker_npc_id)
	var target_state: Dictionary = npc_system.get_npc_state(target_npc_id)
	if bool(speaker_state.get("unconscious", false)) or bool(target_state.get("unconscious", false)):
		return _failure("npc_unconscious", "昏迷中的 NPC 无法对话。")
	if bool(speaker_state.get("escaped", false)) or bool(target_state.get("escaped", false)):
		return _failure("npc_escaped", "已逃离的 NPC 无法对话。")
	for participant_id in [speaker_npc_id, target_npc_id]:
		if npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(str(participant_id)):
			return _failure("npc_deep_sleep", "NPC 正在熟睡，无法打断。")
	var autonomous := bool(options.get("autonomous", false))
	var defer_participant_activation := autonomous and bool(options.get("defer_participant_activation", false))
	var planning_participants: Array[String] = []
	if defer_participant_activation:
		planning_participants.append(target_npc_id)
	else:
		planning_participants.append(speaker_npc_id)
		planning_participants.append(target_npc_id)
	for participant_id in planning_participants:
		if _is_npc_plan_request_active(participant_id, npc_system):
			return _failure("npc_planning", "NPC正在思考，暂时无法开始对话。")
	if autonomous:
		if str(speaker_state.get("current_location", "")) != str(target_state.get("current_location", "")):
			return _failure("npc_not_co_located", "NPC 必须抵达同一地点后才能开始自主对话。")
		for participant_id in [speaker_npc_id, target_npc_id]:
			if not _is_npc_in_work_behavior_mode(str(participant_id), npc_system):
				return _failure("npc_behavior_mode_blocked", "只有日常工作模式中的 NPC 可以发起自主闲聊。")
	if not _active_dialogue.is_empty():
		if not bool(options.get("replace_existing", not autonomous)):
			return _failure("dialogue_busy", "已有对话正在进行，自主 NPC 对话不会替换它。")
		_cancel_active_dialogue_llm_requests("npc_dialogue_replaced")
		end_dialogue("npc_dialogue_replaced")
	_dialogue_counter += 1
	var clean_visibility := visibility if ["private", "local_public"].has(visibility) else "local_public"
	var dialogue_id := "dialogue_%d_%04d" % [Time.get_ticks_msec(), _dialogue_counter]
	var clean_soft_round_threshold := maxi(1, soft_round_threshold)
	var soft_round_guidance := _build_npc_dialogue_soft_round_guidance(clean_soft_round_threshold)
	var participant_ids: Array[String] = [speaker_npc_id, target_npc_id]
	var participant_names: Dictionary = {}
	participant_names[speaker_npc_id] = str(speaker.get("name", speaker_npc_id))
	participant_names[target_npc_id] = str(target.get("name", target_npc_id))
	var plan_context: Dictionary = (
		(options.get("plan_context", {}) as Dictionary)
		if options.get("plan_context", {}) is Dictionary
		else {}
	)
	_active_dialogue = {
		"dialogue_id": dialogue_id,
		"dialogue_kind": "npc_npc",
		"target_npc_id": target_npc_id,
		"target_npc_name": str(target.get("name", target_npc_id)),
		"speaker_npc_id": speaker_npc_id,
		"speaker_name": str(speaker.get("name", speaker_npc_id)),
		"participant_npc_ids": participant_ids,
		"participant_names": participant_names,
		"visibility": clean_visibility,
		"location_id": str(target_state.get("current_location", "plaza")),
		"location_name": str(target_state.get("current_location_name", "广场")),
		"current_round": 0,
		"max_rounds": NPC_DIALOGUE_NO_HARD_ROUND_LIMIT,
		"soft_round_threshold": clean_soft_round_threshold,
		"soft_round_guidance": soft_round_guidance,
		"history": [],
		"waiting": false,
		"last_error": "",
		"autonomous": autonomous,
		"ui_visible": bool(options.get("ui_visible", not autonomous)),
		"require_real_provider": bool(options.get("require_real_provider", autonomous)),
		"dialogue_initiator": "npc" if autonomous else "",
		"plan_action_source": str(plan_context.get(
			"plan_action_source",
			options.get("plan_action_source", "")
		)),
		"assigned_plan_day": int(plan_context.get(
			"assigned_plan_day",
			options.get("assigned_plan_day", -1)
		)),
		"assigned_plan_hour": int(plan_context.get(
			"assigned_plan_hour",
			options.get("assigned_plan_hour", -1)
		)),
		"assigned_plan_version": int(plan_context.get(
			"assigned_plan_version",
			options.get("assigned_plan_version", -1)
		)),
		"assigned_plan_item": (
			(plan_context.get("assigned_plan_item", {}) as Dictionary).duplicate(true)
			if plan_context.get("assigned_plan_item", {}) is Dictionary
			else {}
		),
		"dialogue_phase": "invitation" if defer_participant_activation else "conversation",
		"session_status": "invitation_pending" if defer_participant_activation else "starting",
		"interrupted_plan_action_by_npc": {}
	}
	if defer_participant_activation:
		# The invitation occupies the speaker's planned talk action, but the target
		# has not been interrupted and has not spoken yet. Keep the target's previous
		# dialogue epoch alive until an accept/reject reply becomes an actual exchange.
		_ensure_active_dialogue_epoch_for_npc(speaker_npc_id)
	else:
		for participant_id in participant_ids:
			_ensure_active_dialogue_epoch_for_npc(str(participant_id))
	if defer_participant_activation:
		# 发起者已经完成接近行动；受邀者必须先由 LLM 接受，才允许打断其当前工作。
		# 邀请请求失败时没有实际对话，拒绝后则由双方各自判断是否需要修改计划。
		dialogue_started.emit(get_dialogue_state())
		return {"ok": true, "dialogue_state": get_dialogue_state(), "invitation_pending": true}
	var interrupted_actions: Dictionary = {}
	for participant_id in participant_ids:
		var cancel_result := _cancel_npc_llm_request(str(participant_id), "npc_dialogue_started")
		if not bool(cancel_result.get("ok", true)):
			_active_dialogue.clear()
			return cancel_result
		var interrupted_action_id := _get_runtime_action_id(str(participant_id))
		if _interrupt_for_dialogue(str(participant_id)) and not interrupted_action_id.is_empty():
			interrupted_actions[str(participant_id)] = interrupted_action_id
	_active_dialogue["interrupted_plan_action_by_npc"] = interrupted_actions
	_active_dialogue["session_status"] = "active"
	for participant_id in participant_ids:
		npc_system.update_npc_state(participant_id, {
			"current_action": "talk_to_npc",
			"active_dialogue_id": dialogue_id,
			"last_action_result": "npc_dialogue_started"
		})
	dialogue_started.emit(get_dialogue_state())
	return {"ok": true, "dialogue_state": get_dialogue_state()}


func start_autonomous_npc_dialogue(
	speaker_npc_id: String,
	target_npc_id: String,
	opening_text: String,
	visibility: String = "local_public",
	soft_round_threshold: int = NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD,
	require_real_provider: bool = true,
	plan_context: Dictionary = {}
) -> Dictionary:
	var clean_opening := opening_text.strip_edges()
	if clean_opening.is_empty():
		clean_opening = "我想和你谈谈眼下的事情。"
	var start_result := start_npc_dialogue(speaker_npc_id, target_npc_id, visibility, soft_round_threshold, {
		"autonomous": true,
		"ui_visible": false,
		"replace_existing": false,
		"require_real_provider": require_real_provider,
		"defer_participant_activation": true,
		"plan_context": plan_context.duplicate(true)
	})
	if not bool(start_result.get("ok", false)):
		return start_result
	_active_dialogue["opening_text"] = clean_opening
	_active_dialogue["dialogue_initiator"] = "npc"
	_active_dialogue["plan_action_source"] = str(plan_context.get("plan_action_source", ""))
	_active_dialogue["assigned_plan_day"] = int(plan_context.get("assigned_plan_day", -1))
	_active_dialogue["assigned_plan_hour"] = int(plan_context.get("assigned_plan_hour", -1))
	_active_dialogue["assigned_plan_version"] = int(plan_context.get("assigned_plan_version", -1))
	_active_dialogue["assigned_plan_item"] = (
		(plan_context.get("assigned_plan_item", {}) as Dictionary).duplicate(true)
		if plan_context.get("assigned_plan_item", {}) is Dictionary
		else {}
	)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system != null
		and npc_system.has_method("get_formal_dialogue_approach_snapshot")
		and npc_system.has_method("bind_formal_dialogue_session")
	):
		var formal_snapshot: Dictionary = npc_system.get_formal_dialogue_approach_snapshot(speaker_npc_id)
		if bool(formal_snapshot.get("active", false)) and str(formal_snapshot.get("role", "")) == "speaker":
			var bind_result: Dictionary = npc_system.bind_formal_dialogue_session(
				speaker_npc_id,
				str(_active_dialogue.get("dialogue_id", ""))
			)
			if not bool(bind_result.get("ok", false)):
				end_dialogue("autonomous_dialogue_spatial_bind_failed")
				return _failure(
					str(bind_result.get("reason", "formal_dialogue_spatial_bind_failed")),
					"NPC 对话邀请无法绑定正式空间会话。"
				)
	var send_result := _send_autonomous_dialogue_invitation(clean_opening, true)
	if not bool(send_result.get("ok", false)):
		var failure_message := str(send_result.get("message", "无法发起 NPC 对话邀请判定。"))
		_active_dialogue["last_error"] = failure_message
		end_dialogue("autonomous_dialogue_invitation_request_failed")
		return send_result
	# From this point onward ActionSystem has accepted the planned talk action and
	# released its pending reservation. If the asynchronous invitation later dies
	# before producing actual dialogue, DialogSystem must report that action failure.
	_active_dialogue["invitation_request_started"] = true
	return {
		"ok": true,
		"pending": bool(send_result.get("pending", false)),
		"request_id": str(send_result.get("request_id", "")),
		"dialogue_state": get_dialogue_state()
	}


func _send_autonomous_dialogue_invitation(opening_text: String, async_request: bool = true) -> Dictionary:
	if (
		_active_dialogue.is_empty()
		or str(_active_dialogue.get("dialogue_kind", "")) != "npc_npc"
		or not bool(_active_dialogue.get("autonomous", false))
		or str(_active_dialogue.get("session_status", "")) != "invitation_pending"
	):
		return _failure("npc_dialogue_invitation_not_started", "当前没有等待判定的 NPC 对话邀请。")
	if not _are_autonomous_dialogue_participants_available():
		end_dialogue("autonomous_dialogue_participant_unavailable")
		return _failure("npc_dialogue_participant_unavailable", "NPC 对话邀请参与者已不可用。")
	if bool(_active_dialogue.get("waiting", false)):
		return _failure("dialogue_waiting", "正在等待受邀 NPC 决定是否接受对话。")
	var clean_opening := opening_text.strip_edges()
	if clean_opening.is_empty():
		return _failure("empty_message", "NPC 对话邀请内容不能为空。")
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null:
		return _failure("llm_bridge_missing", "LLMBridge 不可用。")
	var speaker_id := str(_active_dialogue.get("speaker_npc_id", ""))
	var speaker_name := str(_active_dialogue.get("speaker_name", speaker_id))
	var target_id := str(_active_dialogue.get("target_npc_id", ""))
	var target_name := str(_active_dialogue.get("target_npc_name", target_id))
	var request_options := {
		"dialogue_kind": "npc_npc",
		"dialogue_phase": "invitation",
		"requires_time_slowdown": true,
		"speaker_kind": "npc",
		"speaker_npc_id": speaker_id,
		"speaker_name": speaker_name,
		"current_round": 0,
		"max_rounds": NPC_DIALOGUE_NO_HARD_ROUND_LIMIT,
		"soft_round_threshold": int(_active_dialogue.get("soft_round_threshold", NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD)),
		"soft_round_guidance": str(_active_dialogue.get("soft_round_guidance", "")),
		"conversation_history": [],
		"dialogue_state": {
			"visibility": str(_active_dialogue.get("visibility", "local_public")),
			"location_id": str(_active_dialogue.get("location_id", "plaza")),
			"location_name": str(_active_dialogue.get("location_name", "广场")),
			"participants": [speaker_id, target_id],
			"soft_round_threshold": int(_active_dialogue.get("soft_round_threshold", NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD)),
			"soft_round_guidance": str(_active_dialogue.get("soft_round_guidance", ""))
		}
	}
	var pending := {
		"kind": "npc_dialogue_invitation",
		"clean_text": clean_opening,
		"speaker_id": speaker_id,
		"speaker_name": speaker_name,
		"target_id": target_id,
		"target_name": target_name
	}
	var presentation_result := _play_formal_dialogue_gesture(speaker_id, "invitation_sent")
	if not bool(presentation_result.get("ok", false)):
		return _failure(
			str(presentation_result.get("reason", "formal_dialogue_invitation_gesture_failed")),
			"NPC 已到达交谈位置，但邀请示意动作无法播放。"
		)
	_active_dialogue["waiting"] = true
	_active_dialogue["dialogue_phase"] = "invitation"
	if async_request and llm_bridge.has_method("request_npc_dialogue_async"):
		var request_id := "%s_invitation" % str(_active_dialogue.get("dialogue_id", "dialogue"))
		request_options["request_id"] = request_id
		pending["request_id"] = request_id
		_active_dialogue["pending_llm"] = pending.duplicate(true)
		dialogue_updated.emit(get_dialogue_state())
		var async_result: Dictionary = llm_bridge.request_npc_dialogue_async(target_id, clean_opening, request_options)
		if not bool(async_result.get("ok", false)):
			_active_dialogue.erase("pending_llm")
			_active_dialogue["waiting"] = false
			_active_dialogue["last_error"] = str(async_result.get("message", "后端邀请判定请求失败。"))
			dialogue_updated.emit(get_dialogue_state())
			return async_result
		return {"ok": true, "pending": true, "request_id": request_id, "dialogue_state": get_dialogue_state()}
	var result: Dictionary = llm_bridge.request_npc_dialogue(target_id, clean_opening, request_options)
	return _apply_autonomous_dialogue_invitation_response(result, pending)


func send_player_message(text: String, is_recruitment_request: bool = false, async_request: bool = false) -> Dictionary:
	var clean_text := text.strip_edges()
	var activation_result := _activate_player_dialogue_draft("player_message_sent")
	if not bool(activation_result.get("ok", false)):
		return activation_result
	if _active_dialogue.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	if clean_text.is_empty():
		return _failure("empty_message", "请输入对话内容。")
	if bool(_active_dialogue.get("waiting", false)):
		return _failure("dialogue_waiting", "正在等待 NPC 回复。")
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
	if npc_system != null and _is_npc_plan_request_active(target_npc_id, npc_system):
		return _failure("npc_planning", "NPC正在思考，暂时无法对话。")
	if npc_system != null and npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(target_npc_id):
		return _failure("npc_deep_sleep", "NPC 正在熟睡，无法继续对话。")

	var dialogue_kind := str(_active_dialogue.get("dialogue_kind", "player_npc"))
	var next_round := int(_active_dialogue.get("current_round", 0)) + 1
	if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND and next_round > int(_active_dialogue.get("max_rounds", ESCAPE_INTERVENTION_MAX_ROUNDS)):
		return _failure("round_limit_reached", "逃离挽留对话已达到 5 轮上限。")

	var effect_result := _ensure_player_dialogue_effect_started("player_message_sent")
	if not bool(effect_result.get("ok", false)):
		return effect_result

	var history_before: Array = _active_dialogue.get("history", []).duplicate(true)
	var npc_name := str(_active_dialogue.get("target_npc_name", target_npc_id))
	var player_turn := _make_history_turn(GUARD_OFFICER_ID, GUARD_OFFICER_NAME, target_npc_id, npc_name, clean_text)
	var history: Array = _active_dialogue.get("history", [])
	history.append(player_turn)
	_active_dialogue["history"] = history
	_active_dialogue["last_player_text"] = clean_text
	_active_dialogue["waiting"] = true
	_active_dialogue["last_error"] = ""
	var effective_recruitment_request := false if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND else is_recruitment_request or bool(_active_dialogue.get("recruitment_request_pending", false))
	if effective_recruitment_request:
		_active_dialogue["session_had_recruitment_request"] = true
		# “提出应征”是当前会话内的持续选项；玩家主动关闭前，
		# 后续消息继续携带同一意图，避免每轮都要重新勾选。
		_active_dialogue["recruitment_request_pending"] = true
	dialogue_updated.emit(get_dialogue_state())
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null:
		_active_dialogue["waiting"] = false
		_active_dialogue["last_error"] = "LLMBridge 不可用。"
		dialogue_updated.emit(get_dialogue_state())
		return _failure("llm_bridge_missing", str(_active_dialogue["last_error"]))

	var request_options := {
		"dialogue_kind": dialogue_kind,
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
		"interrupted_activity_context": (
			(_active_dialogue.get("interrupted_activity_context", {}) as Dictionary).duplicate(true)
			if _active_dialogue.get("interrupted_activity_context", {}) is Dictionary
			else {}
		),
		"interaction_context": str(_active_dialogue.get("interaction_context", "work"))
	}
	if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND:
		request_options["escape_intervention_round"] = next_round
		request_options["constraints"] = [
			"本轮是守备官试图挽留正在逃离驿站的 NPC。",
			"回复必须通过 escape_intervention_result 表达 stay 或 leave；程序只解析该结构化结果，不允许模型直接改变 HP、资源、建筑或移动结果。"
		]
	var pending := {
		"kind": "player_message",
		"clean_text": clean_text,
		"next_round": next_round,
		"effective_recruitment_request": effective_recruitment_request,
		"dialogue_kind": dialogue_kind,
		"player_turn": player_turn
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
	if _active_dialogue.is_empty():
		return _failure("dialogue_not_started", "对话已经结束，迟到的模型回复已丢弃。")
	_active_dialogue["waiting"] = false
	_active_dialogue.erase("pending_llm")
	var dialogue_kind := str(_active_dialogue.get("dialogue_kind", pending.get("dialogue_kind", "player_npc")))
	if not bool(result.get("ok", false)):
		if bool(_active_dialogue.get("wartime_dialogue", false)):
			result = {
				"ok": true,
				"dialogue": _make_wartime_rule_fallback_response(pending, result)
			}
		elif dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND:
			result = {
				"ok": true,
				"dialogue": _make_escape_intervention_rule_fallback_response(pending, result)
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

	var effective_recruitment_request := bool(pending.get("effective_recruitment_request", false)) and dialogue_kind != ESCAPE_INTERVENTION_DIALOGUE_KIND
	var recruitment_result := _apply_recruitment_result(response, effective_recruitment_request)
	_active_dialogue["last_recruitment_result"] = recruitment_result
	var npc_name := str(_active_dialogue.get("target_npc_name", "NPC"))
	var clean_text := str(pending.get("clean_text", ""))
	_ensure_pending_player_turn_in_history(pending)
	var npc_turn := _make_history_turn(str(_active_dialogue.get("target_npc_id", "")), npc_name, GUARD_OFFICER_ID, GUARD_OFFICER_NAME, reply_text)
	if ["accept", "reject"].has(recruitment_result):
		# 结果跟随产生它的具体回复，后续普通回合不会覆盖历史提示；
		# 展示文案由 UI 生成，不污染 NPC 的真实 reply_text。
		npc_turn["recruitment_result"] = recruitment_result
	if (
		bool(_active_dialogue.get("wartime_dialogue", false))
		and str(response.get("wartime_reaction", "none")) == "morale_boost"
	):
		npc_turn["wartime_reaction"] = "morale_boost"
	var history: Array = _active_dialogue.get("history", [])
	history.append(npc_turn)
	_active_dialogue["history"] = history
	_active_dialogue["last_reply_text"] = reply_text
	_active_dialogue["current_round"] = int(pending.get("next_round", int(_active_dialogue.get("current_round", 0)) + 1))
	_active_dialogue["completed_player_llm_turns"] = int(_active_dialogue.get("completed_player_llm_turns", 0)) + 1
	var recruitment_applied_immediately := false
	if recruitment_result == "accept":
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
		if npc_system != null and npc_system.has_method("set_npc_recruited"):
			recruitment_applied_immediately = bool(npc_system.set_npc_recruited(target_npc_id, true))
	if bool(_active_dialogue.get("wartime_dialogue", false)):
		_active_dialogue["deferred_wartime_response"] = response.duplicate(true)
	if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND:
		_active_dialogue["deferred_escape_response"] = response.duplicate(true)
	var escape_intervention_result := str(response.get("escape_intervention_result", ""))
	var close_escape_dialogue := (
		dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND
		and (
			escape_intervention_result == "stay"
			or int(_active_dialogue.get("current_round", 0)) >= int(_active_dialogue.get("max_rounds", ESCAPE_INTERVENTION_MAX_ROUNDS))
		)
	)
	dialogue_updated.emit(get_dialogue_state())
	var final_dialogue_state: Dictionary = get_dialogue_state()
	if close_escape_dialogue:
		var end_result := end_dialogue()
		final_dialogue_state = end_result.get("dialogue_state", {}) if end_result.get("dialogue_state", {}) is Dictionary else {}
	return {
		"ok": true,
		"reply_text": reply_text,
		"dialogue": response.duplicate(true),
		"wartime_result": {},
		"escape_intervention_result": {},
		"effects_deferred_until_completion": true,
		"recruitment_applied_immediately": recruitment_applied_immediately,
		"dialogue_state": final_dialogue_state
	}


func attack_target_npc(damage: int = DEFAULT_ATTACK_DAMAGE, async_request: bool = false) -> Dictionary:
	var activation_result := _activate_player_dialogue_draft("player_attack")
	if not bool(activation_result.get("ok", false)):
		return activation_result
	if _active_dialogue.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	var dialogue_kind := str(_active_dialogue.get("dialogue_kind", ""))
	if not ["player_npc", ESCAPE_INTERVENTION_DIALOGUE_KIND].has(dialogue_kind):
		return _failure("invalid_dialogue_kind", "只有守备官与 NPC 对话时可以攻击。")
	if bool(_active_dialogue.get("waiting", false)):
		return _failure("dialogue_waiting", "正在等待 NPC 回复。")
	if damage <= 0:
		return _failure("invalid_damage", "攻击伤害必须为正数。")
	var next_round := int(_active_dialogue.get("current_round", 0)) + 1
	if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND and next_round > int(_active_dialogue.get("max_rounds", ESCAPE_INTERVENTION_MAX_ROUNDS)):
		return _failure("round_limit_reached", "逃离挽留对话已达到 5 轮上限。")

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
	var damage_event: Dictionary = damage_result.get("damage_event", {}) if (damage_result.get("damage_event", {}) is Dictionary) else {}
	var attack_event_id := str(damage_event.get("event_id", damage_event.get("id", "")))
	_active_dialogue["last_attack_event_id"] = attack_event_id
	var attack_turn := _make_history_turn(GUARD_OFFICER_ID, GUARD_OFFICER_NAME, target_npc_id, npc_name, GUARD_ATTACK_EVENT_TEXT)
	var history_before: Array = _active_dialogue.get("history", []).duplicate(true)
	history_before.append(attack_turn)
	_active_dialogue["history"] = history_before.duplicate(true)
	_active_dialogue["last_player_text"] = GUARD_ATTACK_EVENT_TEXT
	var pending := {
		"kind": "guard_attack",
		"dialogue_kind": dialogue_kind,
		"target_npc_id": target_npc_id,
		"npc_name": npc_name,
		"attack_turn": attack_turn,
		"attack_event_id": attack_event_id,
		"next_round": next_round,
		"damage": damage_result
	}

	if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND:
		return _apply_escape_attack_without_reply(pending)

	if bool(damage_result.get("unconscious", false)):
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
		"dialogue_kind": dialogue_kind,
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
		"interrupted_activity_context": (
			(_active_dialogue.get("interrupted_activity_context", {}) as Dictionary).duplicate(true)
			if _active_dialogue.get("interrupted_activity_context", {}) is Dictionary
			else {}
		),
		"interaction_context": str(_active_dialogue.get("interaction_context", "work"))
	}
	if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND:
		request_options["escape_intervention_round"] = next_round
		request_options["constraints"].append("本轮攻击发生在逃离挽留中；攻击已由程序造成 HP 伤害，并会让逃离速度更快。若请求模型，NPC 只能通过 escape_intervention_result 表达 stay 或 leave。")
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


func _apply_escape_attack_without_reply(pending: Dictionary) -> Dictionary:
	if _active_dialogue.is_empty():
		return {
			"ok": true,
			"damage": pending.get("damage", {}),
			"dialogue_state": {}
		}
	var attack_turn: Dictionary = pending.get("attack_turn", {})
	if attack_turn.is_empty():
		var target_npc_id := str(pending.get("target_npc_id", _active_dialogue.get("target_npc_id", "")))
		var npc_name := str(pending.get("npc_name", _active_dialogue.get("target_npc_name", target_npc_id)))
		attack_turn = _make_history_turn(GUARD_OFFICER_ID, GUARD_OFFICER_NAME, target_npc_id, npc_name, GUARD_ATTACK_EVENT_TEXT)
	_active_dialogue["current_round"] = int(pending.get("next_round", int(_active_dialogue.get("current_round", 0)) + 1))
	_active_dialogue["waiting"] = false
	_active_dialogue.erase("pending_llm")
	_active_dialogue["last_error"] = ""

	var response := {
		"replyer_id": str(_active_dialogue.get("target_npc_id", "")),
		"reply_text": "",
		"emotion": "fearful",
		"attitude_delta": 0,
		"relationship_delta": 0,
		"attack_result": "continue_escape",
		"rule_fallback": true,
		"interaction_kind": "escape_guard_attack_no_reply"
	}
	var round_result := _record_escape_attack_intervention_round(
		str(_active_dialogue.get("target_npc_id", "")),
		int(_active_dialogue.get("current_round", 0)),
		str(pending.get("attack_event_id", ""))
	)
	dialogue_updated.emit(get_dialogue_state())
	var end_result := end_dialogue()
	return {
		"ok": true,
		"damage": pending.get("damage", {}),
		"reply_text": "",
		"dialogue": response,
		"escape_attack_round_result": round_result,
		"dialogue_state": end_result.get("dialogue_state", {}),
		"llm_requested": false
	}


func _apply_attack_response(result: Dictionary, pending: Dictionary) -> Dictionary:
	if _active_dialogue.is_empty():
		return result
	_active_dialogue["waiting"] = false
	_active_dialogue.erase("pending_llm")
	var dialogue_kind := str(_active_dialogue.get("dialogue_kind", pending.get("dialogue_kind", "player_npc")))
	if not bool(result.get("ok", false)):
		if bool(_active_dialogue.get("wartime_dialogue", false)):
			result = {
				"ok": true,
				"dialogue": _make_wartime_rule_fallback_response(pending, result)
			}
		elif dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND:
			result = {
				"ok": true,
				"dialogue": _make_escape_intervention_rule_fallback_response(pending, result)
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
	if (
		bool(_active_dialogue.get("wartime_dialogue", false))
		and str(response.get("wartime_reaction", "none")) == "morale_boost"
	):
		npc_turn["wartime_reaction"] = "morale_boost"
	var history: Array = _active_dialogue.get("history", [])
	history.append(npc_turn)
	_active_dialogue["history"] = history
	_active_dialogue["last_reply_text"] = reply_text
	_active_dialogue["current_round"] = int(pending.get("next_round", int(_active_dialogue.get("current_round", 0)) + 1))
	_active_dialogue["completed_attack_llm_turns"] = int(_active_dialogue.get("completed_attack_llm_turns", 0)) + 1
	if bool(_active_dialogue.get("wartime_dialogue", false)):
		_active_dialogue["deferred_wartime_response"] = response.duplicate(true)
	if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND:
		_active_dialogue["deferred_escape_response"] = response.duplicate(true)
	var escape_intervention_result := str(response.get("escape_intervention_result", ""))
	var close_escape_dialogue := (
		dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND
		and (
			escape_intervention_result == "stay"
			or int(_active_dialogue.get("current_round", 0)) >= int(_active_dialogue.get("max_rounds", ESCAPE_INTERVENTION_MAX_ROUNDS))
		)
	)
	dialogue_updated.emit(get_dialogue_state())
	var final_dialogue_state: Dictionary = get_dialogue_state()
	if close_escape_dialogue:
		var end_result := end_dialogue()
		final_dialogue_state = end_result.get("dialogue_state", {}) if end_result.get("dialogue_state", {}) is Dictionary else {}
	return {
		"ok": true,
		"damage": pending.get("damage", {}),
		"reply_text": reply_text,
		"dialogue": response.duplicate(true),
		"wartime_result": {},
		"escape_intervention_result": {},
		"effects_deferred_until_completion": true,
		"dialogue_state": final_dialogue_state
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
		"npc_message":
			_apply_npc_message_response(result, pending)
		"npc_dialogue_invitation":
			_apply_autonomous_dialogue_invitation_response(result, pending)
		_:
			_active_dialogue["waiting"] = false
			_active_dialogue.erase("pending_llm")
			_active_dialogue["last_error"] = str(result.get("message", "未知对话请求已结束。"))
			dialogue_updated.emit(get_dialogue_state())


func _apply_autonomous_dialogue_invitation_response(result: Dictionary, pending: Dictionary) -> Dictionary:
	if (
		_active_dialogue.is_empty()
		or str(_active_dialogue.get("dialogue_kind", "")) != "npc_npc"
		or not bool(_active_dialogue.get("autonomous", false))
		or str(_active_dialogue.get("session_status", "")) != "invitation_pending"
	):
		return _failure("npc_dialogue_invitation_ended", "NPC 对话邀请已经结束。")
	if not _are_autonomous_dialogue_participants_available():
		end_dialogue("autonomous_dialogue_participant_unavailable")
		return _failure("npc_dialogue_participant_unavailable", "NPC 对话邀请参与者已不可用。")
	_active_dialogue["waiting"] = false
	_active_dialogue.erase("pending_llm")
	if not bool(result.get("ok", false)):
		_active_dialogue["last_error"] = str(result.get("message", "后端邀请判定请求失败。"))
		dialogue_updated.emit(get_dialogue_state())
		end_dialogue("autonomous_dialogue_invitation_llm_failed")
		return result
	var response: Dictionary = result.get("dialogue", {})
	var expected_replyer_id := str(pending.get("target_id", _active_dialogue.get("target_npc_id", "")))
	if str(response.get("replyer_id", "")) != expected_replyer_id:
		var replyer_failure := _failure("invalid_npc_dialogue_invitation_replyer", "邀请判定的模型回复者与受邀 NPC 不一致。")
		_active_dialogue["last_error"] = str(replyer_failure.get("message", ""))
		dialogue_updated.emit(get_dialogue_state())
		end_dialogue("autonomous_dialogue_invitation_business_validation_failed")
		return replyer_failure
	if str(response.get("response_kind", "")) != "reply_to_npc":
		var kind_failure := _failure("invalid_npc_dialogue_invitation_response_kind", "NPC 对话邀请返回了错误的回复类型。")
		_active_dialogue["last_error"] = str(kind_failure.get("message", ""))
		dialogue_updated.emit(get_dialogue_state())
		end_dialogue("autonomous_dialogue_invitation_business_validation_failed")
		return kind_failure
	if bool(_active_dialogue.get("require_real_provider", false)):
		var model_provider := str(response.get("model_provider", "")).strip_edges().to_lower()
		if model_provider.is_empty() or model_provider == "mock" or bool(response.get("model_fallback_used", false)):
			var provider_failure := _failure("real_provider_required", "自主 NPC 对话邀请只接受真实 LLM 判定。")
			_active_dialogue["last_error"] = str(provider_failure.get("message", ""))
			dialogue_updated.emit(get_dialogue_state())
			end_dialogue("autonomous_dialogue_invitation_provider_invalid")
			return provider_failure
	var invitation_result := str(response.get("invitation_result", ""))
	if not ["accept", "reject"].has(invitation_result):
		var decision_failure := _failure("invalid_npc_dialogue_invitation_result", "受邀 NPC 必须先明确接受或拒绝对话。")
		_active_dialogue["last_error"] = str(decision_failure.get("message", ""))
		dialogue_updated.emit(get_dialogue_state())
		end_dialogue("autonomous_dialogue_invitation_business_validation_failed")
		return decision_failure
	if (
		(invitation_result == "accept" and bool(response.get("should_end_dialogue", false)))
		or (
			invitation_result == "reject"
			and (
				not bool(response.get("should_end_dialogue", false))
			)
		)
	):
		var end_contract_failure := _failure("invalid_npc_dialogue_invitation_end_contract", "NPC 对话邀请的接受 / 拒绝与结束标记不一致。")
		_active_dialogue["last_error"] = str(end_contract_failure.get("message", ""))
		dialogue_updated.emit(get_dialogue_state())
		end_dialogue("autonomous_dialogue_invitation_business_validation_failed")
		return end_contract_failure
	var reply_text := str(response.get("reply_text", "")).strip_edges()
	if reply_text.is_empty():
		var empty_reply_failure := _failure("empty_invitation_reply", "后端没有返回受邀 NPC 的接受 / 拒绝回复。")
		_active_dialogue["last_error"] = str(empty_reply_failure.get("message", ""))
		dialogue_updated.emit(get_dialogue_state())
		end_dialogue("autonomous_dialogue_invitation_empty_reply")
		return empty_reply_failure
	var speaker_id := str(pending.get("speaker_id", _active_dialogue.get("speaker_npc_id", "")))
	var speaker_name := str(pending.get("speaker_name", _active_dialogue.get("speaker_name", speaker_id)))
	var target_id := str(pending.get("target_id", _active_dialogue.get("target_npc_id", "")))
	var target_name := str(pending.get("target_name", _active_dialogue.get("target_npc_name", target_id)))
	var opening_text := str(pending.get("clean_text", _active_dialogue.get("opening_text", "")))
	# A valid accept/reject reply is the first actual utterance by the invited NPC.
	# From here both participants belong to this dialogue epoch, including rejection.
	_ensure_active_dialogue_epoch_for_npc(target_id)
	var opening_turn := _make_history_turn(speaker_id, speaker_name, target_id, target_name, opening_text)
	var reply_turn := _make_history_turn(target_id, target_name, speaker_id, speaker_name, reply_text)
	_active_dialogue["history"] = [opening_turn, reply_turn]
	_active_dialogue["invitation_result"] = invitation_result
	_record_dialogue_event("dialogue_turn", {
		"dialogue_phase": "invitation",
		"invitation_result": invitation_result,
		"speaker_name": speaker_name,
		"listener_name": target_name,
		"speaker_text": opening_text,
		"reply_text": reply_text,
		"dialogue_text": [opening_turn, reply_turn],
		"is_recruitment_request": false,
		"recruitment_result": "none",
		"emotion": str(response.get("emotion", "neutral")),
		"should_end_dialogue": bool(response.get("should_end_dialogue", false))
	})
	if invitation_result == "reject":
		_active_dialogue["session_status"] = "invitation_rejected"
		dialogue_updated.emit(get_dialogue_state())
		var reject_end := end_dialogue("autonomous_dialogue_invitation_rejected")
		return {
			"ok": true,
			"accepted": false,
			"reply_text": reply_text,
			"dialogue": response.duplicate(true),
			"dialogue_state": reject_end.get("dialogue_state", {})
		}
	var activation_result := _activate_autonomous_dialogue_after_invitation()
	if not bool(activation_result.get("ok", false)):
		_active_dialogue["last_error"] = str(activation_result.get("message", "无法在接受邀请后启动 NPC 对话。"))
		dialogue_updated.emit(get_dialogue_state())
		end_dialogue("autonomous_dialogue_activation_failed")
		return activation_result
	# 受邀方的接受回复成为正式会话的上一句，但不占正式轮次；下一次 LLM 回复才是第 1 轮。
	_active_dialogue["speaker_npc_id"] = target_id
	_active_dialogue["speaker_name"] = target_name
	_active_dialogue["target_npc_id"] = speaker_id
	_active_dialogue["target_npc_name"] = speaker_name
	dialogue_updated.emit(get_dialogue_state())
	var dialogue_id := str(_active_dialogue.get("dialogue_id", ""))
	call_deferred("_continue_autonomous_npc_dialogue", dialogue_id, reply_text)
	return {
		"ok": true,
		"accepted": true,
		"reply_text": reply_text,
		"dialogue": response.duplicate(true),
		"dialogue_state": get_dialogue_state()
	}


func _activate_autonomous_dialogue_after_invitation() -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return _failure("npc_system_missing", "NPCSystem 不可用。")
	var dialogue_id := str(_active_dialogue.get("dialogue_id", ""))
	var participant_ids: Array = _active_dialogue.get("participant_npc_ids", [])
	if dialogue_id.is_empty() or participant_ids.size() != 2:
		return _failure("invalid_participants", "NPC 对话邀请缺少双方参与者。")
	if npc_system.has_method("stage_formal_dialogue_acceptance"):
		var stage_result: Dictionary = npc_system.stage_formal_dialogue_acceptance(dialogue_id)
		if not bool(stage_result.get("ok", false)):
			return _failure(
				str(stage_result.get("reason", "formal_dialogue_acceptance_stage_failed")),
				"NPC 对话接受阶段无法保留受邀者的真实站位。"
			)
	var interrupted_actions: Dictionary = {}
	for raw_participant_id in participant_ids:
		var participant_id := str(raw_participant_id)
		var cancel_result := _cancel_npc_llm_request(participant_id, "npc_dialogue_invitation_accepted")
		if not bool(cancel_result.get("ok", true)):
			return cancel_result
		var interrupted_action_id := _get_runtime_action_id(participant_id)
		if _interrupt_for_dialogue(participant_id) and not interrupted_action_id.is_empty():
			interrupted_actions[participant_id] = interrupted_action_id
	_active_dialogue["interrupted_plan_action_by_npc"] = interrupted_actions
	# Acceptance is a strict authority/presentation boundary: ActionSystem stops
	# the invitee's current work first, then the spatial layer faces both actors,
	# then the invitee performs one authored gesture before conversation state is set.
	if npc_system.has_method("prepare_formal_dialogue_activation"):
		var spatial_transfer_result: Dictionary = npc_system.prepare_formal_dialogue_activation(dialogue_id)
		if not bool(spatial_transfer_result.get("ok", false)):
			return _failure(
				str(spatial_transfer_result.get("reason", "formal_dialogue_spatial_transfer_failed")),
				"NPC 对话的空间权属交接失败。"
			)
	var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
	var presentation_result := _play_formal_dialogue_gesture(target_npc_id, "invitation_accepted")
	if not bool(presentation_result.get("ok", false)):
		return _failure(
			str(presentation_result.get("reason", "formal_dialogue_acceptance_gesture_failed")),
			"受邀 NPC 已接受对话，但接受示意动作无法播放。"
		)
	_active_dialogue["dialogue_phase"] = "conversation"
	_active_dialogue["session_status"] = "active"
	for raw_participant_id in participant_ids:
		var participant_id := str(raw_participant_id)
		npc_system.update_npc_state(participant_id, {
			"current_action": "talk_to_npc",
			"active_dialogue_id": dialogue_id,
			"last_action_result": "npc_dialogue_invitation_accepted"
		})
	return {"ok": true}


func _play_formal_dialogue_gesture(npc_id: String, event_kind: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("play_formal_dialogue_presentation_event"):
		return {"ok": false, "reason": "npc_presentation_event_system_missing"}
	return npc_system.play_formal_dialogue_presentation_event(
		str(_active_dialogue.get("dialogue_id", "")),
		npc_id,
		event_kind
	)


func send_npc_message(text: String, async_request: bool = false, speaker_text_already_recorded: bool = false) -> Dictionary:
	var clean_text := text.strip_edges()
	if _active_dialogue.is_empty() or str(_active_dialogue.get("dialogue_kind", "")) != "npc_npc":
		return _failure("npc_dialogue_not_started", "当前没有进行中的 NPC-NPC 对话。")
	if bool(_active_dialogue.get("autonomous", false)) and not _are_autonomous_dialogue_participants_available():
		end_dialogue("autonomous_dialogue_participant_unavailable")
		return _failure("npc_dialogue_participant_unavailable", "NPC-NPC 对话参与者已无法继续对话。")
	if clean_text.is_empty():
		return _failure("empty_message", "NPC 对话内容不能为空。")
	if bool(_active_dialogue.get("waiting", false)):
		return _failure("dialogue_waiting", "正在等待 NPC 回复。")
	var next_round := int(_active_dialogue.get("current_round", 0)) + 1
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
	var conversation_history: Array = _active_dialogue.get("history", []).duplicate(true)
	if speaker_text_already_recorded and not conversation_history.is_empty():
		var latest_turn: Variant = conversation_history.back()
		if latest_turn is Dictionary and str((latest_turn as Dictionary).get("text", "")) == clean_text:
			# 当前 speaker_text 已经是上一轮刚写入 history 的回复；发送给模型时临时移除，
			# 避免同一句同时出现在 conversation_history 和 speaker_text 中。
			conversation_history.pop_back()
	var request_options := {
		"dialogue_kind": "npc_npc",
		"dialogue_phase": "conversation",
		"requires_time_slowdown": true,
		"speaker_kind": "npc",
		"speaker_npc_id": speaker_id,
		"speaker_name": speaker_name,
		"current_round": next_round,
		"max_rounds": NPC_DIALOGUE_NO_HARD_ROUND_LIMIT,
		"soft_round_threshold": int(_active_dialogue.get("soft_round_threshold", NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD)),
		"soft_round_guidance": str(_active_dialogue.get("soft_round_guidance", "")),
		"conversation_history": conversation_history,
		"dialogue_state": {
			"visibility": str(_active_dialogue.get("visibility", "local_public")),
			"location_id": str(_active_dialogue.get("location_id", "plaza")),
			"location_name": str(_active_dialogue.get("location_name", "广场")),
			"participants": [speaker_id, target_id],
			"soft_round_threshold": int(_active_dialogue.get("soft_round_threshold", NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD)),
			"soft_round_guidance": str(_active_dialogue.get("soft_round_guidance", ""))
		}
	}
	var pending := {
		"kind": "npc_message",
		"clean_text": clean_text,
		"next_round": next_round,
		"speaker_id": speaker_id,
		"speaker_name": speaker_name,
		"target_id": target_id,
		"target_name": target_name,
		"speaker_text_already_recorded": speaker_text_already_recorded
	}
	if async_request and llm_bridge.has_method("request_npc_dialogue_async"):
		var request_id := "%s_npc_%d" % [str(_active_dialogue.get("dialogue_id", "dialogue")), next_round]
		request_options["request_id"] = request_id
		pending["request_id"] = request_id
		_active_dialogue["pending_llm"] = pending.duplicate(true)
		# 旁听 UI 需要在模型返回前就看到本轮已经说出口的内容与等待状态；
		# 这只是会话展示快照，事件仍然只在完整回复成功后入库。
		dialogue_updated.emit(get_dialogue_state())
		var async_result: Dictionary = llm_bridge.request_npc_dialogue_async(target_id, clean_text, request_options)
		if not bool(async_result.get("ok", false)):
			_active_dialogue.erase("pending_llm")
			_active_dialogue["waiting"] = false
			_active_dialogue["last_error"] = str(async_result.get("message", "后端请求失败。"))
			dialogue_updated.emit(get_dialogue_state())
			return async_result
		return {"ok": true, "pending": true, "request_id": request_id, "dialogue_state": get_dialogue_state()}

	var result: Dictionary = llm_bridge.request_npc_dialogue(target_id, clean_text, request_options)
	return _apply_npc_message_response(result, pending)


func _apply_npc_message_response(result: Dictionary, pending: Dictionary) -> Dictionary:
	if _active_dialogue.is_empty() or str(_active_dialogue.get("dialogue_kind", "")) != "npc_npc":
		return _failure("npc_dialogue_not_started", "NPC-NPC 对话已结束。")
	if bool(_active_dialogue.get("autonomous", false)) and not _are_autonomous_dialogue_participants_available():
		end_dialogue("autonomous_dialogue_participant_unavailable")
		return _failure("npc_dialogue_participant_unavailable", "NPC-NPC 对话参与者已无法继续对话。")
	_active_dialogue["waiting"] = false
	_active_dialogue.erase("pending_llm")
	if not bool(result.get("ok", false)):
		_active_dialogue["last_error"] = str(result.get("message", "后端请求失败。"))
		dialogue_updated.emit(get_dialogue_state())
		if bool(_active_dialogue.get("autonomous", false)):
			end_dialogue("autonomous_dialogue_llm_failed")
		return result
	var response: Dictionary = result.get("dialogue", {})
	var expected_replyer_id := str(pending.get("target_id", _active_dialogue.get("target_npc_id", "")))
	if str(response.get("replyer_id", "")) != expected_replyer_id:
		var replyer_failure := _failure("invalid_npc_dialogue_replyer", "模型回复者与本轮 NPC 目标不一致。")
		_active_dialogue["last_error"] = str(replyer_failure.get("message", ""))
		dialogue_updated.emit(get_dialogue_state())
		if bool(_active_dialogue.get("autonomous", false)):
			end_dialogue("autonomous_dialogue_business_validation_failed")
		return replyer_failure
	if str(response.get("response_kind", "")) != "reply_to_npc":
		var kind_failure := _failure("invalid_npc_dialogue_response_kind", "NPC-NPC 对话模型返回了错误的回复类型。")
		_active_dialogue["last_error"] = str(kind_failure.get("message", ""))
		dialogue_updated.emit(get_dialogue_state())
		if bool(_active_dialogue.get("autonomous", false)):
			end_dialogue("autonomous_dialogue_business_validation_failed")
		return kind_failure
	if str(response.get("invitation_result", "not_applicable")) != "not_applicable":
		var invitation_failure := _failure("invalid_npc_dialogue_conversation_invitation_result", "正式 NPC-NPC 对话回复不能再次返回邀请决定。")
		_active_dialogue["last_error"] = str(invitation_failure.get("message", ""))
		dialogue_updated.emit(get_dialogue_state())
		if bool(_active_dialogue.get("autonomous", false)):
			end_dialogue("autonomous_dialogue_business_validation_failed")
		return invitation_failure
	if bool(_active_dialogue.get("require_real_provider", false)):
		var model_provider := str(response.get("model_provider", "")).strip_edges().to_lower()
		if model_provider.is_empty() or model_provider == "mock" or bool(response.get("model_fallback_used", false)):
			var provider_failure := _failure("real_provider_required", "自主 NPC 对话只接受真实 LLM 回复。")
			_active_dialogue["last_error"] = str(provider_failure.get("message", ""))
			dialogue_updated.emit(get_dialogue_state())
			end_dialogue("autonomous_dialogue_provider_invalid")
			return provider_failure
	var reply_text := str(response.get("reply_text", "")).strip_edges()
	if reply_text.is_empty():
		var empty_reply_message := "后端没有返回 NPC 回复。"
		_active_dialogue["last_error"] = empty_reply_message
		dialogue_updated.emit(get_dialogue_state())
		if bool(_active_dialogue.get("autonomous", false)):
			end_dialogue("autonomous_dialogue_empty_reply")
		return _failure("empty_reply", empty_reply_message)
	var clean_text := str(pending.get("clean_text", ""))
	var next_round := int(pending.get("next_round", int(_active_dialogue.get("current_round", 0)) + 1))
	var speaker_id := str(pending.get("speaker_id", _active_dialogue.get("speaker_npc_id", "")))
	var speaker_name := str(pending.get("speaker_name", _active_dialogue.get("speaker_name", speaker_id)))
	var target_id := str(pending.get("target_id", _active_dialogue.get("target_npc_id", "")))
	var target_name := str(pending.get("target_name", _active_dialogue.get("target_npc_name", target_id)))
	var speaker_turn := _make_history_turn(speaker_id, speaker_name, target_id, target_name, clean_text)
	var reply_turn := _make_history_turn(target_id, target_name, speaker_id, speaker_name, reply_text)
	var should_end := bool(response.get("should_end_dialogue", false))
	var history: Array = _active_dialogue.get("history", [])
	if not bool(pending.get("speaker_text_already_recorded", false)):
		history.append(speaker_turn)
	history.append(reply_turn)
	_active_dialogue["history"] = history
	_active_dialogue["current_round"] = next_round
	if bool(pending.get("speaker_text_already_recorded", false)):
		# 自动续聊的 speaker_text 已属于上一个已落库回合；本事件只记录这次新生成的
		# 回复，避免短期记忆里同一句话跨相邻事件重复。
		_record_dialogue_event("dialogue_turn", {
			"dialogue_phase": "conversation",
			"invitation_result": "not_applicable",
			"speaker_name": target_name,
			"listener_name": speaker_name,
			"speaker_text": reply_text,
			"reply_text": "",
			"dialogue_text": [reply_turn],
			"is_autonomous_continuation": true,
			"is_recruitment_request": false,
			"recruitment_result": "none",
			"emotion": str(response.get("emotion", "neutral")),
			"should_end_dialogue": should_end
		}, {
			"subject_npc_id": target_id,
			"actor_ids": [target_id]
		})
	else:
		_record_dialogue_event("dialogue_turn", {
			"dialogue_phase": "conversation",
			"invitation_result": "not_applicable",
			"speaker_name": speaker_name,
			"listener_name": target_name,
			"speaker_text": clean_text,
			"reply_text": reply_text,
			"dialogue_text": [speaker_turn, reply_turn],
			"is_recruitment_request": false,
			"recruitment_result": "none",
			"emotion": str(response.get("emotion", "neutral")),
			"should_end_dialogue": should_end
		})
	if should_end:
		# 结束标记属于本次 LLM 回复本身；该回复已经进入 history / 事件库，
		# 接下来直接结束会话，绝不再把告别语发送给另一名 NPC 等待回复。
		_active_dialogue["ending_npc_id"] = target_id
		_active_dialogue["ending_npc_name"] = target_name
		_active_dialogue["ending_reply_text"] = reply_text
		_active_dialogue["ending_round"] = next_round
	_active_dialogue["speaker_npc_id"] = target_id
	_active_dialogue["speaker_name"] = target_name
	_active_dialogue["target_npc_id"] = speaker_id
	_active_dialogue["target_npc_name"] = speaker_name
	dialogue_updated.emit(get_dialogue_state())
	if should_end:
		end_dialogue("autonomous_dialogue_completed" if bool(_active_dialogue.get("autonomous", false)) else "npc_dialogue_completed")
	elif bool(_active_dialogue.get("autonomous", false)):
		var dialogue_id := str(_active_dialogue.get("dialogue_id", ""))
		call_deferred("_continue_autonomous_npc_dialogue", dialogue_id, reply_text)
	return {"ok": true, "reply_text": reply_text, "dialogue": response.duplicate(true)}


func _continue_autonomous_npc_dialogue(dialogue_id: String, speaker_text: String) -> void:
	if _active_dialogue.is_empty() or str(_active_dialogue.get("dialogue_id", "")) != dialogue_id:
		return
	if not bool(_active_dialogue.get("autonomous", false)) or bool(_active_dialogue.get("waiting", false)):
		return
	if not _are_autonomous_dialogue_participants_available():
		end_dialogue("autonomous_dialogue_participant_unavailable")
		return
	var result := send_npc_message(speaker_text, true, true)
	if bool(result.get("ok", false)):
		return
	_active_dialogue["last_error"] = str(result.get("message", "NPC 自动续聊失败。"))
	dialogue_updated.emit(get_dialogue_state())
	end_dialogue("autonomous_dialogue_continue_failed")


func _activate_player_dialogue_draft(reason: String) -> Dictionary:
	if _player_dialogue_draft.is_empty():
		return {"ok": true, "activated": false}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var target_npc_id := str(_player_dialogue_draft.get("target_npc_id", ""))
	if npc_system == null or npc_system.get_npc(target_npc_id).is_empty():
		return _failure("npc_not_found", "找不到对话目标。")
	if not npc_system.can_npc_act(target_npc_id):
		return _failure("npc_unavailable", "该 NPC 当前无法进入对话。")
	if _is_npc_plan_request_active(target_npc_id, npc_system):
		return _failure("npc_planning", "NPC正在思考，暂时无法进入对话。")
	if npc_system.has_method("is_npc_dialogue_blocked") and npc_system.is_npc_dialogue_blocked(target_npc_id):
		return _failure("npc_deep_sleep", "NPC 正在熟睡，无法进入对话。")
	var draft := _player_dialogue_draft.duplicate(true)
	var latest_state: Dictionary = npc_system.get_npc_state(target_npc_id)
	if _is_active_escape_dialogue_target(latest_state):
		return _failure("escape_intervention_required", "NPC 已开始逃离，请重新打开对话进入挽留流程。")
	var latest_context := _get_player_dialogue_interaction_context(target_npc_id, latest_state, npc_system)
	if latest_context != str(draft.get("interaction_context", "work")):
		return _failure("dialogue_context_changed", "NPC 的行为模式已经变化，请重新打开对话。")
	draft["location_id"] = str(latest_state.get("current_location", "plaza"))
	draft["location_name"] = str(latest_state.get("current_location_name", "广场"))
	draft["interaction_context"] = latest_context
	var force_local_public := WARTIME_DIALOGUE_CONTEXTS.has(latest_context)
	draft["force_local_public"] = force_local_public
	draft["wartime_dialogue"] = force_local_public
	if force_local_public:
		draft["visibility"] = "local_public"
	if not _active_dialogue.is_empty():
		end_dialogue(reason)
	_active_dialogue = draft
	_player_dialogue_draft.clear()
	var state := get_dialogue_state()
	dialogue_updated.emit(state)
	return {"ok": true, "activated": true, "dialogue_state": state}


func complete_displayed_dialogue(dialogue_id: String = "") -> Dictionary:
	var draft_id := str(_player_dialogue_draft.get("dialogue_id", ""))
	if not draft_id.is_empty() and (dialogue_id.is_empty() or dialogue_id == draft_id):
		var ended_draft := get_display_dialogue_state()
		ended_draft["end_reason"] = "player_completed_draft"
		ended_draft["completion_mode"] = "completed"
		_player_dialogue_draft.clear()
		dialogue_ended.emit(ended_draft)
		return {"ok": true, "dialogue_state": ended_draft, "view_only": true}
	if not dialogue_id.is_empty() and dialogue_id != str(_active_dialogue.get("dialogue_id", "")):
		return _failure("dialogue_not_started", "当前显示的对话已经结束。")
	return end_dialogue("player_completed_dialogue")


func end_displayed_dialogue(dialogue_id: String = "") -> Dictionary:
	return complete_displayed_dialogue(dialogue_id)


func cancel_displayed_dialogue(dialogue_id: String = "") -> Dictionary:
	var draft_id := str(_player_dialogue_draft.get("dialogue_id", ""))
	if not draft_id.is_empty() and (dialogue_id.is_empty() or dialogue_id == draft_id):
		if _is_npc_initiated_proactive_player_dialogue(_player_dialogue_draft):
			return _failure(
				"dialogue_cancel_locked_by_npc_initiator",
				"驿站成员主动交涉不可取消对话。"
			)
		var ended_draft := get_display_dialogue_state()
		ended_draft["end_reason"] = "player_cancelled_draft"
		ended_draft["completion_mode"] = "cancelled"
		_player_dialogue_draft.clear()
		dialogue_ended.emit(ended_draft)
		return {"ok": true, "dialogue_state": ended_draft, "cancelled": true, "view_only": true}
	if _active_dialogue.is_empty() or not _is_player_controlled_dialogue(_active_dialogue):
		return _failure("dialogue_not_started", "当前没有可取消的守备官对话。")
	if not dialogue_id.is_empty() and dialogue_id != str(_active_dialogue.get("dialogue_id", "")):
		return _failure("dialogue_not_started", "当前显示的对话已经结束。")
	if _is_npc_initiated_proactive_player_dialogue(_active_dialogue):
		return _failure(
			"dialogue_cancel_locked_by_npc_initiator",
			"驿站成员主动交涉不可取消对话。"
		)
	if bool(_active_dialogue.get("attack_committed", false)):
		return _failure("dialogue_cancel_locked_by_attack", "守备官已经攻击 NPC，本次对话不能取消。")
	if bool(_active_dialogue.get("session_had_recruitment_request", false)):
		return _failure(
			"dialogue_cancel_locked_by_recruitment_request",
			"守备官已经在本次会话中提出应征，只能完成对话。"
		)
	return _cancel_active_player_dialogue("player_cancelled_dialogue")


func suspend_displayed_dialogue(dialogue_id: String = "") -> Dictionary:
	var activation_result := _activate_player_dialogue_draft("player_suspended_dialogue")
	if not bool(activation_result.get("ok", false)):
		return activation_result
	if _active_dialogue.is_empty() or not _is_player_controlled_dialogue(_active_dialogue):
		return _failure("dialogue_not_started", "当前没有可挂起的守备官对话。")
	if not dialogue_id.is_empty() and dialogue_id != str(_active_dialogue.get("dialogue_id", "")):
		return _failure("dialogue_not_started", "当前显示的对话已经结束。")
	var effect_result := _ensure_player_dialogue_effect_started("player_suspended_dialogue")
	if not bool(effect_result.get("ok", false)):
		return effect_result
	_active_dialogue["ui_visible"] = false
	_active_dialogue["suspended"] = true
	_active_dialogue["suspended_remaining_seconds"] = SUSPENDED_DIALOGUE_MAX_SECONDS
	_active_dialogue["session_status"] = "suspended"
	_set_player_dialogue_npc_runtime_state(true)
	dialogue_updated.emit(get_dialogue_state())
	return {"ok": true, "suspended": true, "dialogue_state": get_dialogue_state()}


func resume_suspended_player_dialogue(npc_id: String = "", dialogue_id: String = "") -> Dictionary:
	if _active_dialogue.is_empty() or not _is_player_controlled_dialogue(_active_dialogue) or not bool(_active_dialogue.get("suspended", false)):
		return _failure("suspended_dialogue_not_found", "没有可恢复的挂起会话。")
	if not npc_id.is_empty() and npc_id != str(_active_dialogue.get("target_npc_id", "")):
		return _failure("suspended_dialogue_not_found", "该 NPC 没有挂起会话。")
	if not dialogue_id.is_empty() and dialogue_id != str(_active_dialogue.get("dialogue_id", "")):
		return _failure("suspended_dialogue_not_found", "挂起会话已经结束。")
	_active_dialogue["ui_visible"] = true
	_active_dialogue["suspended"] = false
	_active_dialogue["suspended_remaining_seconds"] = 0.0
	_active_dialogue["session_status"] = "active"
	_set_player_dialogue_npc_runtime_state(false)
	var state := get_dialogue_state()
	dialogue_started.emit(state)
	dialogue_updated.emit(state)
	return {"ok": true, "resumed": true, "dialogue_state": state}


func get_suspended_player_dialogue_state(npc_id: String = "") -> Dictionary:
	if _active_dialogue.is_empty() or not _is_player_controlled_dialogue(_active_dialogue) or not bool(_active_dialogue.get("suspended", false)):
		return {}
	if not npc_id.is_empty() and npc_id != str(_active_dialogue.get("target_npc_id", "")):
		return {}
	return get_dialogue_state()


func is_player_dialogue_suspended_for_npc(npc_id: String) -> bool:
	return not get_suspended_player_dialogue_state(npc_id).is_empty()


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float = 1.0) -> void:
	if _active_dialogue.is_empty() or not _is_player_controlled_dialogue(_active_dialogue) or not bool(_active_dialogue.get("suspended", false)):
		return
	var remaining := maxf(0.0, float(_active_dialogue.get("suspended_remaining_seconds", SUSPENDED_DIALOGUE_MAX_SECONDS)) - maxf(0.0, game_delta_seconds))
	_active_dialogue["suspended_remaining_seconds"] = remaining
	if remaining > 0.0:
		return
	if (
		bool(_active_dialogue.get("attack_committed", false))
		or _is_npc_initiated_proactive_player_dialogue(_active_dialogue)
		or bool(_active_dialogue.get("session_had_recruitment_request", false))
	):
		var timeout_reason := "suspended_dialogue_timeout_after_recruitment_request"
		if bool(_active_dialogue.get("attack_committed", false)):
			timeout_reason = "suspended_dialogue_timeout_after_attack"
		elif _is_npc_initiated_proactive_player_dialogue(_active_dialogue):
			timeout_reason = "suspended_npc_proactive_dialogue_timeout"
		end_dialogue(timeout_reason)
	else:
		_cancel_active_player_dialogue("suspended_dialogue_timeout")


func end_dialogue(reason: String = "dialogue_ended", options: Dictionary = {}) -> Dictionary:
	if _dialogue_end_in_progress:
		return {
			"ok": true,
			"ended": false,
			"reason": "dialogue_end_in_progress"
		}
	if _active_dialogue.is_empty():
		if not _player_dialogue_draft.is_empty():
			return complete_displayed_dialogue(str(_player_dialogue_draft.get("dialogue_id", "")))
		return {"ok": true}
	_dialogue_end_in_progress = true
	var suppress_plan_reevaluation := bool(options.get("suppress_plan_reevaluation", false))
	var suppress_dialogue_resume := bool(options.get("suppress_dialogue_resume", false))
	var is_player_dialogue := _is_player_controlled_dialogue(_active_dialogue)
	var dialogue_event: Dictionary = {}
	var deferred_effect_results: Dictionary = {}
	if is_player_dialogue:
		_active_dialogue["ended_while_waiting"] = bool(_active_dialogue.get("waiting", false))
		_active_dialogue["completion_mode"] = "completed"
		_active_dialogue["session_status"] = "completed"
	_cancel_active_dialogue_llm_requests(reason)
	if is_player_dialogue:
		_active_dialogue["waiting"] = false
		_active_dialogue.erase("pending_llm")
		dialogue_event = _commit_player_dialogue_session_event()
		deferred_effect_results = _apply_deferred_player_dialogue_effects(dialogue_event)
	var ended_state := get_dialogue_state()
	ended_state["end_reason"] = reason
	ended_state["ui_visible"] = false
	_active_dialogue.clear()
	_dialogue_end_in_progress = false
	_pending_forced_end_dialogue_id = ""
	_release_player_dialogue_target(ended_state)
	_restore_npc_dialogue_participants(ended_state)
	dialogue_ended.emit(ended_state)
	var escape_resume_result := _resume_escape_dialogue_if_needed(ended_state, reason)
	var plan_judgement_queued := false
	if not suppress_plan_reevaluation:
		var judgement_state := ended_state.duplicate(true)
		if suppress_dialogue_resume:
			judgement_state["interrupted_plan_action_by_npc"] = {}
			judgement_state["player_dialogue_interrupted_action"] = false
			judgement_state["player_dialogue_interrupted_action_id"] = ""
		plan_judgement_queued = _queue_dialogue_plan_judgements(judgement_state, [])
		if not plan_judgement_queued:
			_report_failed_autonomous_dialogue_action_if_needed(ended_state, reason)
	var result := {"ok": true, "dialogue_state": ended_state}
	if not dialogue_event.is_empty():
		result["dialogue_event"] = dialogue_event
	if not deferred_effect_results.is_empty():
		result["deferred_effect_results"] = deferred_effect_results
	if not escape_resume_result.is_empty():
		result["escape_resume_result"] = escape_resume_result
	if plan_judgement_queued:
		result["plan_judgement_queued"] = true
	if not plan_judgement_queued and not suppress_dialogue_resume:
		var resume_plan_result := _resume_existing_player_plan_after_dialogue(ended_state)
		if not resume_plan_result.is_empty():
			result["resume_plan_result"] = resume_plan_result
		if not suppress_plan_reevaluation:
			var npc_resume_results := _resume_empty_npc_dialogue_plans(ended_state)
			if not npc_resume_results.is_empty():
				result["npc_resume_plan_results"] = npc_resume_results
		var deferred_dispatch_results := _release_deferred_current_plans_after_dialogue(ended_state)
		if not deferred_dispatch_results.is_empty():
			result["deferred_current_plan_results"] = deferred_dispatch_results
	return result


func _cancel_active_player_dialogue(reason: String) -> Dictionary:
	if _active_dialogue.is_empty() or not _is_player_controlled_dialogue(_active_dialogue):
		return _failure("dialogue_not_started", "当前没有可取消的守备官对话。")
	if _is_npc_initiated_proactive_player_dialogue(_active_dialogue):
		return _failure(
			"dialogue_cancel_locked_by_npc_initiator",
			"驿站成员主动交涉不可取消对话。"
		)
	var ended_state := get_dialogue_state()
	ended_state["end_reason"] = reason
	ended_state["completion_mode"] = "cancelled"
	ended_state["session_status"] = "cancelled"
	ended_state["ui_visible"] = false
	_cancel_active_dialogue_llm_requests(reason)
	_active_dialogue.clear()
	_pending_forced_end_dialogue_id = ""
	_release_player_dialogue_target(ended_state)
	dialogue_ended.emit(ended_state)
	var result := {
		"ok": true,
		"cancelled": true,
		"dialogue_state": ended_state
	}
	var escape_resume_result := _resume_escape_dialogue_if_needed(ended_state, reason)
	if not escape_resume_result.is_empty():
		result["escape_resume_result"] = escape_resume_result
	var resume_plan_result := _resume_existing_player_plan_after_dialogue(ended_state)
	if not resume_plan_result.is_empty():
		result["resume_plan_result"] = resume_plan_result
	var deferred_dispatch_results := _release_deferred_current_plans_after_dialogue(ended_state)
	if not deferred_dispatch_results.is_empty():
		result["deferred_current_plan_results"] = deferred_dispatch_results
	return result


func _is_player_controlled_dialogue(dialogue_state: Dictionary) -> bool:
	return str(dialogue_state.get("dialogue_kind", "")) in ["player_npc", ESCAPE_INTERVENTION_DIALOGUE_KIND]


func _is_npc_initiated_proactive_player_dialogue(dialogue_state: Dictionary) -> bool:
	return (
		str(dialogue_state.get("dialogue_kind", "")) == "player_npc"
		and str(dialogue_state.get("dialogue_initiator", "")) == "npc"
		and bool(dialogue_state.get("proactive_talk", false))
	)


func _set_player_dialogue_npc_runtime_state(suspended: bool) -> void:
	if _active_dialogue.is_empty() or not _is_player_controlled_dialogue(_active_dialogue):
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var npc_id := str(_active_dialogue.get("target_npc_id", ""))
	if npc_system == null or npc_id.is_empty() or npc_system.get_npc(npc_id).is_empty():
		return
	var dialogue_kind := str(_active_dialogue.get("dialogue_kind", ""))
	var current_action := "escape_intervention_dialogue" if dialogue_kind == ESCAPE_INTERVENTION_DIALOGUE_KIND else "talk_to_guard_officer"
	npc_system.update_npc_state(npc_id, {
		"current_action": current_action,
		"active_dialogue_id": str(_active_dialogue.get("dialogue_id", "")),
		"player_dialogue_suspended": suspended,
		"last_action_result": "player_dialogue_suspended" if suspended else "player_dialogue_active"
	})


func _release_player_dialogue_target(ended_state: Dictionary) -> void:
	if not _is_player_controlled_dialogue(ended_state):
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var npc_id := str(ended_state.get("target_npc_id", ""))
	if npc_system == null or npc_id.is_empty() or npc_system.get_npc(npc_id).is_empty():
		return
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(npc_state.get("active_dialogue_id", "")) != str(ended_state.get("dialogue_id", "")):
		return
	var updates := {
		"active_dialogue_id": "",
		"player_dialogue_suspended": false
	}
	if (
		str(ended_state.get("dialogue_kind", "")) == "player_npc"
		and str(npc_state.get("current_action", "")) == "talk_to_guard_officer"
		and npc_system.can_npc_act(npc_id)
	):
		updates["current_action"] = "idle"
		updates["last_action_result"] = "player_dialogue_finished"
	npc_system.update_npc_state(npc_id, updates)


func _commit_player_dialogue_session_event() -> Dictionary:
	if _active_dialogue.is_empty() or not _is_player_controlled_dialogue(_active_dialogue):
		return {}
	var history: Array = (
		(_active_dialogue.get("history", []) as Array).duplicate(true)
		if _active_dialogue.get("history", []) is Array
		else []
	)
	if history.is_empty():
		return {}
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		_active_dialogue["last_error"] = "MemorySystem 不可用，对话未能入库。"
		return {}
	var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
	var npc_name := str(_active_dialogue.get("target_npc_name", target_npc_id))
	var last_guard_text := str(_active_dialogue.get("last_player_text", ""))
	var last_reply_text := str(_active_dialogue.get("last_reply_text", ""))
	if last_guard_text.is_empty():
		for index in range(history.size() - 1, -1, -1):
			var turn: Dictionary = history[index] if history[index] is Dictionary else {}
			if str(turn.get("speaker_id", "")) == GUARD_OFFICER_ID:
				last_guard_text = str(turn.get("text", ""))
				break
	var first_turn: Dictionary = history[0] if history[0] is Dictionary else {}
	var first_speaker_id := str(first_turn.get("speaker_id", GUARD_OFFICER_ID))
	var event_speaker_name := GUARD_OFFICER_NAME
	var event_listener_name := npc_name
	var event_speaker_text := last_guard_text
	var event_reply_text := last_reply_text
	if event_speaker_text.is_empty():
		event_speaker_name = str(first_turn.get("speaker_name", npc_name))
		event_listener_name = str(first_turn.get("listener_name", GUARD_OFFICER_NAME))
		event_speaker_text = str(first_turn.get("text", ""))
		event_reply_text = ""
	var interaction_kind := "guard_attack" if bool(_active_dialogue.get("attack_committed", false)) else "guard_npc_dialogue_session"
	var event: Dictionary = memory_system.add_event({
		"type": "dialogue_turn",
		"subject_npc_id": target_npc_id,
		"actor_ids": [first_speaker_id],
		"target_ids": [target_npc_id],
		"location_id": str(_active_dialogue.get("location_id", "plaza")),
		"visibility": str(_active_dialogue.get("visibility", "private")),
		"importance": 55 if bool(_active_dialogue.get("attack_committed", false)) else 45,
		"payload": {
			"dialogue_id": str(_active_dialogue.get("dialogue_id", "")),
			"dialogue_kind": str(_active_dialogue.get("dialogue_kind", "player_npc")),
			"participant_npc_ids": [target_npc_id],
			"visibility": str(_active_dialogue.get("visibility", "private")),
			"current_round": int(_active_dialogue.get("current_round", 0)),
			"max_rounds": int(_active_dialogue.get("max_rounds", PLAYER_DIALOGUE_MAX_ROUNDS)),
			"speaker_name": event_speaker_name,
			"listener_name": event_listener_name,
			"speaker_text": event_speaker_text,
			"reply_text": event_reply_text,
			"dialogue_text": history,
			"is_recruitment_request": bool(_active_dialogue.get("session_had_recruitment_request", false)),
			"recruitment_result": str(_active_dialogue.get("deferred_recruitment_result", "none")),
			"interaction_context": str(_active_dialogue.get("interaction_context", "work")),
			"interaction_kind": interaction_kind,
			"related_event_id": str(_active_dialogue.get("last_attack_event_id", "")),
			"session_completed": true,
			"ended_while_waiting": bool(_active_dialogue.get("ended_while_waiting", false)),
			"attack_committed": bool(_active_dialogue.get("attack_committed", false)),
			"completed_player_llm_turns": int(_active_dialogue.get("completed_player_llm_turns", 0)),
			"completed_attack_llm_turns": int(_active_dialogue.get("completed_attack_llm_turns", 0))
		}
	})
	if not event.is_empty():
		_active_dialogue["session_event_id"] = str(event.get("event_id", event.get("id", "")))
	return event


func _apply_deferred_player_dialogue_effects(dialogue_event: Dictionary) -> Dictionary:
	if _active_dialogue.is_empty() or not _is_player_controlled_dialogue(_active_dialogue):
		return {}
	var results := {}
	var wartime_response: Dictionary = _active_dialogue.get("deferred_wartime_response", {}) if _active_dialogue.get("deferred_wartime_response", {}) is Dictionary else {}
	if not wartime_response.is_empty():
		results["wartime_result"] = _apply_wartime_reaction(wartime_response, dialogue_event)
	var escape_response: Dictionary = _active_dialogue.get("deferred_escape_response", {}) if _active_dialogue.get("deferred_escape_response", {}) is Dictionary else {}
	if not escape_response.is_empty():
		var event_context := dialogue_event.duplicate(true)
		event_context["interaction_kind"] = str((dialogue_event.get("payload", {}) as Dictionary).get("interaction_kind", "")) if dialogue_event.get("payload", {}) is Dictionary else ""
		results["escape_intervention_result"] = _apply_escape_intervention_response(escape_response, event_context)
	return results


func _ensure_pending_player_turn_in_history(pending: Dictionary) -> void:
	var history: Array = _active_dialogue.get("history", [])
	var pending_turn: Dictionary = pending.get("player_turn", {}) if pending.get("player_turn", {}) is Dictionary else {}
	if pending_turn.is_empty():
		var npc_id := str(_active_dialogue.get("target_npc_id", ""))
		pending_turn = _make_history_turn(GUARD_OFFICER_ID, GUARD_OFFICER_NAME, npc_id, str(_active_dialogue.get("target_npc_name", npc_id)), str(pending.get("clean_text", "")))
	if history.is_empty() or history.back() != pending_turn:
		var already_present := false
		for raw_turn in history:
			if raw_turn is Dictionary and raw_turn == pending_turn:
				already_present = true
				break
		if not already_present:
			history.append(pending_turn)
	_active_dialogue["history"] = history
	_active_dialogue["last_player_text"] = str(pending_turn.get("text", ""))


func end_autonomous_dialogue_for_hour_change() -> Dictionary:
	if _active_dialogue.is_empty():
		return {"ok": true, "ended": false, "reason": "no_active_dialogue"}
	if (
		str(_active_dialogue.get("dialogue_kind", "")) != "npc_npc"
		or not bool(_active_dialogue.get("autonomous", false))
	):
		return {"ok": true, "ended": false, "reason": "priority_dialogue_preserved"}
	var result := end_dialogue("plan_hour_changed", {
		"suppress_plan_reevaluation": false,
		"suppress_dialogue_resume": true
	})
	result["ended"] = true
	return result


func force_end_dialogue_for_npc(
	npc_id: String,
	reason: String = "behavior_mode_changed",
	options: Dictionary = {}
) -> Dictionary:
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
	if _is_player_controlled_dialogue(_active_dialogue):
		var player_end_result := end_dialogue(reason, {
			"suppress_plan_reevaluation": bool(options.get("suppress_plan_reevaluation", reason == "plan_hour_changed")),
			"suppress_dialogue_resume": bool(options.get("suppress_dialogue_resume", false))
		})
		player_end_result["ended"] = true
		player_end_result["npc_id"] = npc_id
		player_end_result["reason"] = reason
		return player_end_result
	var ended_state := get_dialogue_state()
	ended_state["forced_end_reason"] = reason
	var suppress_plan_reevaluation := bool(options.get(
		"suppress_plan_reevaluation",
		reason == "plan_hour_changed"
	))
	_cancel_active_dialogue_llm_requests(reason)
	_active_dialogue.clear()
	_pending_forced_end_dialogue_id = ""
	_restore_npc_dialogue_participants(ended_state)
	dialogue_ended.emit(ended_state)
	var escape_resume_result := _resume_escape_dialogue_if_needed(ended_state, reason)
	var result := {
		"ok": true,
		"ended": true,
		"npc_id": npc_id,
		"reason": reason,
		"dialogue_state": ended_state
	}
	if not escape_resume_result.is_empty():
		result["escape_resume_result"] = escape_resume_result
	if not suppress_plan_reevaluation:
		var plan_judgement_queued := _queue_dialogue_plan_judgements(ended_state, [])
		result["plan_judgement_queued"] = plan_judgement_queued
		if not plan_judgement_queued:
			var deferred_dispatch_results := _release_deferred_current_plans_after_dialogue(ended_state)
			if not deferred_dispatch_results.is_empty():
				result["deferred_current_plan_results"] = deferred_dispatch_results
	return result


func _queue_dialogue_plan_judgements(
	ended_state: Dictionary,
	excluded_npc_ids: Array
) -> bool:
	var dialogue_history := _build_completed_dialogue_history_for_judgement(ended_state)
	if dialogue_history.is_empty():
		return false
	var targets := _get_dialogue_plan_judgement_targets(ended_state)
	for raw_excluded_id in excluded_npc_ids:
		targets.erase(str(raw_excluded_id))
	if targets.is_empty():
		return false
	var queued_state := ended_state.duplicate(true)
	queued_state["judgement_dialogue_history"] = dialogue_history
	queued_state["judgement_target_npc_ids"] = targets
	if (
		str(ended_state.get("end_reason", "")) == "plan_hour_changed"
		or targets.size() > 1
	):
		queued_state["execute_current_plan_when_resolved"] = true
	# The async LLM call itself remains non-blocking, but its request context and
	# interrupted-action token must be registered before another dialogue can
	# replace this one and advance the participant epoch.
	_request_dialogue_plan_judgements_deferred(queued_state)
	return true


func _report_failed_autonomous_dialogue_action_if_needed(
	ended_state: Dictionary,
	reason: String
) -> void:
	if (
		str(ended_state.get("dialogue_kind", "")) != "npc_npc"
		or not bool(ended_state.get("autonomous", false))
		or not bool(ended_state.get("invitation_request_started", false))
	):
		return
	var asynchronous_failure_reasons := [
		"autonomous_dialogue_invitation_llm_failed",
		"autonomous_dialogue_invitation_business_validation_failed",
		"autonomous_dialogue_invitation_provider_invalid",
		"autonomous_dialogue_invitation_empty_reply",
		"autonomous_dialogue_participant_unavailable"
	]
	if not asynchronous_failure_reasons.has(reason):
		return
	var speaker_npc_id := str(ended_state.get("speaker_npc_id", ""))
	if speaker_npc_id.is_empty():
		return
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if (
		action_system == null
		or not action_system.has_method("report_autonomous_dialogue_action_failure")
	):
		return
	action_system.report_autonomous_dialogue_action_failure(
		speaker_npc_id,
		str(ended_state.get("target_npc_id", "")),
		"talk_to_npc_failed_async_invitation",
		str(ended_state.get("last_error", reason))
	)


func _request_dialogue_plan_judgements_deferred(ended_state: Dictionary) -> void:
	var daily_plan_system := get_node_or_null("/root/Main/Systems/DailyPlanSystem")
	if (
		daily_plan_system == null
		or not daily_plan_system.has_method("request_dialogue_plan_revision_judgement")
	):
		_resume_existing_player_plan_after_dialogue(ended_state)
		return
	var dialogue_history: Array = (
		(ended_state.get("judgement_dialogue_history", []) as Array).duplicate(true)
		if ended_state.get("judgement_dialogue_history", []) is Array
		else []
	)
	var interrupted_actions: Dictionary = (
		(ended_state.get("interrupted_plan_action_by_npc", {}) as Dictionary).duplicate(true)
		if ended_state.get("interrupted_plan_action_by_npc", {}) is Dictionary
		else {}
	)
	var dialogue_epochs: Dictionary = (
		(ended_state.get("dialogue_epoch_by_npc", {}) as Dictionary).duplicate(true)
		if ended_state.get("dialogue_epoch_by_npc", {}) is Dictionary
		else {}
	)
	if (
		bool(ended_state.get("execute_current_plan_when_resolved", false))
		and daily_plan_system.has_method("prepare_dialogue_plan_resolution_group")
	):
		daily_plan_system.prepare_dialogue_plan_resolution_group(
			ended_state.get("judgement_target_npc_ids", []),
			str(ended_state.get("dialogue_id", "")),
			dialogue_epochs
		)
	for raw_npc_id in ended_state.get("judgement_target_npc_ids", []):
		var npc_id := str(raw_npc_id)
		if npc_id.is_empty():
			continue
		daily_plan_system.request_dialogue_plan_revision_judgement(npc_id, {
			"npc_id": npc_id,
			"dialogue_id": str(ended_state.get("dialogue_id", "")),
			"dialogue_kind": str(ended_state.get("dialogue_kind", "player_npc")),
			"dialogue_end_reason": str(ended_state.get("end_reason", ended_state.get("forced_end_reason", "dialogue_completed"))),
			"dialogue_history": dialogue_history,
			"visibility": str(ended_state.get("visibility", "private")),
			"location_id": str(ended_state.get("location_id", "plaza")),
			"location_name": str(ended_state.get("location_name", "广场")),
			"interaction_context": str(ended_state.get("interaction_context", "work")),
			"participant_npc_ids": ended_state.get("participant_npc_ids", []),
			"current_round": int(ended_state.get("current_round", 0)),
			"invitation_result": str(ended_state.get("invitation_result", "")),
			"attack_committed": bool(ended_state.get("attack_committed", false)),
			"dialogue_initiator": str(ended_state.get("dialogue_initiator", "")),
			"proactive_talk": bool(ended_state.get("proactive_talk", false)),
			"autonomous": bool(ended_state.get("autonomous", false)),
			"speaker_npc_id": str(ended_state.get("speaker_npc_id", "")),
			"target_npc_id": str(ended_state.get("target_npc_id", "")),
			"plan_action_source": str(ended_state.get("plan_action_source", "")),
			"assigned_plan_day": int(ended_state.get("assigned_plan_day", -1)),
			"assigned_plan_hour": int(ended_state.get("assigned_plan_hour", -1)),
			"execute_current_plan_when_resolved": bool(ended_state.get(
				"execute_current_plan_when_resolved",
				false
			)),
			"dialogue_epoch": int(dialogue_epochs.get(npc_id, get_npc_dialogue_epoch(npc_id))),
			"interrupted_action_id": str(interrupted_actions.get(
				npc_id,
				ended_state.get("player_dialogue_interrupted_action_id", "")
			))
		})


func _release_deferred_current_plans_after_dialogue(ended_state: Dictionary) -> Dictionary:
	var daily_plan_system := get_node_or_null("/root/Main/Systems/DailyPlanSystem")
	if (
		daily_plan_system == null
		or not daily_plan_system.has_method("release_deferred_current_plan_after_dialogue")
	):
		return {}
	var result := {}
	var dialogue_epochs: Dictionary = (
		(ended_state.get("dialogue_epoch_by_npc", {}) as Dictionary).duplicate(true)
		if ended_state.get("dialogue_epoch_by_npc", {}) is Dictionary
		else {}
	)
	for npc_id in _get_dialogue_plan_judgement_targets(ended_state):
		result[npc_id] = daily_plan_system.release_deferred_current_plan_after_dialogue(
			npc_id,
			str(ended_state.get("dialogue_id", "")),
			int(dialogue_epochs.get(npc_id, get_npc_dialogue_epoch(npc_id)))
		)
	return result


func _get_dialogue_plan_judgement_targets(ended_state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var dialogue_kind := str(ended_state.get("dialogue_kind", ""))
	if dialogue_kind in ["player_npc", ESCAPE_INTERVENTION_DIALOGUE_KIND]:
		var target_id := str(ended_state.get("target_npc_id", ""))
		if not target_id.is_empty():
			result.append(target_id)
		return result
	if dialogue_kind != "npc_npc":
		return result
	var participant_ids: Array = ended_state.get("participant_npc_ids", [])
	if participant_ids.is_empty():
		participant_ids = [
			str(ended_state.get("speaker_npc_id", "")),
			str(ended_state.get("target_npc_id", ""))
		]
	for raw_npc_id in participant_ids:
		var npc_id := str(raw_npc_id)
		if not npc_id.is_empty() and not result.has(npc_id):
			result.append(npc_id)
	return result


func _build_completed_dialogue_history_for_judgement(ended_state: Dictionary) -> Array:
	var history: Array = (
		(ended_state.get("history", []) as Array).duplicate(true)
		if ended_state.get("history", []) is Array
		else []
	)
	var dialogue_kind := str(ended_state.get("dialogue_kind", ""))
	var has_completed_exchange := false
	if dialogue_kind == "npc_npc":
		has_completed_exchange = history.size() >= 2
	else:
		# 玩家显式“完成对话”时，最后一句守备官消息即使尚未收到模型回复，
		# 也属于完整会话结尾，并应触发计划重估。
		has_completed_exchange = not history.is_empty()
	if not has_completed_exchange:
		return []
	if bool(ended_state.get("attack_committed", false)) and not _history_contains_guard_attack(history):
		var pending: Dictionary = (
			ended_state.get("pending_llm", {})
			if ended_state.get("pending_llm", {}) is Dictionary
			else {}
		)
		var attack_turn: Dictionary = (
			pending.get("attack_turn", {})
			if pending.get("attack_turn", {}) is Dictionary
			else {}
		)
		if attack_turn.is_empty():
			attack_turn = {
				"speaker_id": GUARD_OFFICER_ID,
				"speaker_name": GUARD_OFFICER_NAME,
				"listener_id": str(ended_state.get("target_npc_id", "")),
				"listener_name": str(ended_state.get("target_npc_name", "NPC")),
				"text": GUARD_ATTACK_EVENT_TEXT,
				"visibility": str(ended_state.get("visibility", "private"))
			}
		history.append(attack_turn)
	return history


func _history_contains_guard_attack(history: Array) -> bool:
	for raw_turn in history:
		if (
			raw_turn is Dictionary
			and str((raw_turn as Dictionary).get("speaker_id", "")) == GUARD_OFFICER_ID
			and str((raw_turn as Dictionary).get("text", "")) == GUARD_ATTACK_EVENT_TEXT
		):
			return true
	return false


func _resume_existing_player_plan_after_dialogue(ended_state: Dictionary) -> Dictionary:
	if (
		str(ended_state.get("dialogue_kind", "")) != "player_npc"
		or not bool(ended_state.get("player_dialogue_effect_started", false))
		or bool(ended_state.get("attack_committed", false))
	):
		return {}
	var npc_id := str(ended_state.get("target_npc_id", ""))
	var interrupted_action_id := str(ended_state.get("player_dialogue_interrupted_action_id", ""))
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_id.is_empty()
		or npc_system == null
		or not npc_system.can_npc_act(npc_id)
		or not _is_npc_in_work_behavior_mode(npc_id, npc_system)
	):
		return {}
	var daily_plan_system := get_node_or_null("/root/Main/Systems/DailyPlanSystem")
	if (
		daily_plan_system == null
		or not daily_plan_system.has_method("resume_current_plan_after_player_dialogue")
	):
		return {}
	if (
		bool(ended_state.get("player_dialogue_interrupted_action", false))
		and not interrupted_action_id.is_empty()
	):
		return daily_plan_system.resume_current_plan_after_player_dialogue(npc_id, interrupted_action_id)
	if daily_plan_system.has_method("resume_saved_plan_after_dialogue"):
		return daily_plan_system.resume_saved_plan_after_dialogue(npc_id)
	return {}


func _resume_empty_npc_dialogue_plans(ended_state: Dictionary) -> Dictionary:
	if str(ended_state.get("dialogue_kind", "")) != "npc_npc":
		return {}
	var daily_plan_system := get_node_or_null("/root/Main/Systems/DailyPlanSystem")
	if daily_plan_system == null:
		return {}
	var results := {}
	var interrupted_actions: Dictionary = (
		(ended_state.get("interrupted_plan_action_by_npc", {}) as Dictionary).duplicate(true)
		if ended_state.get("interrupted_plan_action_by_npc", {}) is Dictionary
		else {}
	)
	for raw_npc_id in interrupted_actions.keys():
		var npc_id := str(raw_npc_id)
		var action_id := str(interrupted_actions.get(raw_npc_id, ""))
		if (
			not npc_id.is_empty()
			and not action_id.is_empty()
			and daily_plan_system.has_method("resume_current_plan_after_dialogue")
		):
			results[npc_id] = daily_plan_system.resume_current_plan_after_dialogue(
				npc_id,
				action_id
			)
	# During invitation_pending the target was deliberately left uninterrupted by
	# this invitation. It may nevertheless carry a valid token from an immediately
	# preceding dialogue whose judgement completed while this invitation occupied
	# the slot; consume that token once the empty invitation ends.
	if (
		str(ended_state.get("session_status", "")) == "invitation_pending"
		and daily_plan_system.has_method("resume_saved_plan_after_dialogue")
	):
		var target_npc_id := str(ended_state.get("target_npc_id", ""))
		if not target_npc_id.is_empty() and not results.has(target_npc_id):
			var saved_result: Dictionary = daily_plan_system.resume_saved_plan_after_dialogue(
				target_npc_id
			)
			if not saved_result.is_empty():
				results[target_npc_id] = saved_result
	return results


func _restore_npc_dialogue_participants(ended_state: Dictionary) -> void:
	if str(ended_state.get("dialogue_kind", "")) != "npc_npc":
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var dialogue_id := str(ended_state.get("dialogue_id", ""))
	var participant_ids: Array = ended_state.get("participant_npc_ids", [])
	if participant_ids.is_empty():
		participant_ids = [str(ended_state.get("speaker_npc_id", "")), str(ended_state.get("target_npc_id", ""))]
	for raw_npc_id in participant_ids:
		var participant_id := str(raw_npc_id)
		if participant_id.is_empty():
			continue
		var state: Dictionary = npc_system.get_npc_state(participant_id)
		if str(state.get("active_dialogue_id", "")) != dialogue_id:
			continue
		var current_action := str(state.get("current_action", ""))
		if (
			current_action != "talk_to_npc"
			or not npc_system.can_npc_act(participant_id)
			or not _is_npc_in_work_behavior_mode(participant_id, npc_system)
		):
			# 昏迷、逃离、战斗等权威状态可能在对话结束前已经落地；这里只释放会话锁，
			# 不能用 idle 覆盖这些状态。
			npc_system.update_npc_state(participant_id, {"active_dialogue_id": ""})
			continue
		npc_system.update_npc_state(participant_id, {
			"current_action": "idle",
			"active_dialogue_id": "",
			"last_action_result": "npc_dialogue_finished"
		})


func _on_npc_state_changed(npc_id: String) -> void:
	if not _player_dialogue_draft.is_empty() and str(_player_dialogue_draft.get("target_npc_id", "")) == npc_id:
		var draft_npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if (
			draft_npc_system == null
			or not draft_npc_system.can_npc_act(npc_id)
			or not _is_npc_in_work_behavior_mode(npc_id, draft_npc_system)
			or _is_npc_plan_request_active(npc_id, draft_npc_system)
			or (
				draft_npc_system.has_method("is_npc_dialogue_blocked")
				and draft_npc_system.is_npc_dialogue_blocked(npc_id)
			)
		):
			end_displayed_dialogue(str(_player_dialogue_draft.get("dialogue_id", "")))
	if _active_dialogue.is_empty() or not bool(_active_dialogue.get("autonomous", false)):
		return
	var participant_ids: Array = _active_dialogue.get("participant_npc_ids", [])
	if not participant_ids.has(npc_id) or _are_autonomous_dialogue_participants_available():
		return
	var dialogue_id := str(_active_dialogue.get("dialogue_id", ""))
	if dialogue_id.is_empty() or _pending_forced_end_dialogue_id == dialogue_id:
		return
	_pending_forced_end_dialogue_id = dialogue_id
	call_deferred("_end_unavailable_autonomous_dialogue", dialogue_id)


func _end_unavailable_autonomous_dialogue(dialogue_id: String) -> void:
	if _pending_forced_end_dialogue_id == dialogue_id:
		_pending_forced_end_dialogue_id = ""
	if (
		_active_dialogue.is_empty()
		or str(_active_dialogue.get("dialogue_id", "")) != dialogue_id
		or not bool(_active_dialogue.get("autonomous", false))
	):
		return
	if not _are_autonomous_dialogue_participants_available():
		end_dialogue("autonomous_dialogue_participant_unavailable")


func _are_autonomous_dialogue_participants_available() -> bool:
	if (
		_active_dialogue.is_empty()
		or str(_active_dialogue.get("dialogue_kind", "")) != "npc_npc"
		or not bool(_active_dialogue.get("autonomous", false))
	):
		return false
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return false
	var dialogue_id := str(_active_dialogue.get("dialogue_id", ""))
	var dialogue_location_id := str(_active_dialogue.get("location_id", ""))
	var participant_ids: Array = _active_dialogue.get("participant_npc_ids", [])
	if dialogue_id.is_empty() or dialogue_location_id.is_empty() or participant_ids.size() != 2:
		return false
	var invitation_pending := str(_active_dialogue.get("session_status", "")) == "invitation_pending"
	for raw_npc_id in participant_ids:
		var participant_id := str(raw_npc_id)
		if (
			participant_id.is_empty()
			or npc_system.get_npc(participant_id).is_empty()
			or not npc_system.can_npc_act(participant_id)
			or not _is_npc_in_work_behavior_mode(participant_id, npc_system)
		):
			return false
		var state: Dictionary = npc_system.get_npc_state(participant_id)
		if invitation_pending:
			# 邀请阶段只锁定会话槽，不得要求受邀者已经进入 talk_to_npc，
			# 也不得先打断其当前工作；但双方必须仍在原地点且没有别的正式对话锁。
			if (
				str(state.get("current_location", "")) != dialogue_location_id
				or not str(state.get("active_dialogue_id", "")).is_empty()
				or (
					npc_system.has_method("is_npc_dialogue_blocked")
					and npc_system.is_npc_dialogue_blocked(participant_id)
				)
			):
				return false
			continue
		if (
			str(state.get("active_dialogue_id", "")) != dialogue_id
			or str(state.get("current_action", "")) != "talk_to_npc"
			or str(state.get("current_location", "")) != dialogue_location_id
		):
			return false
	return true


func _ensure_player_dialogue_effect_started(reason: String) -> Dictionary:
	if _active_dialogue.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	if str(_active_dialogue.get("dialogue_kind", "")) != "player_npc":
		return {"ok": true, "already_started": true}
	if bool(_active_dialogue.get("player_dialogue_effect_started", false)):
		return {"ok": true, "already_started": true}
	var target_npc_id := str(_active_dialogue.get("target_npc_id", ""))
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and _is_npc_plan_request_active(target_npc_id, npc_system):
		return _failure("npc_planning", "NPC正在思考，暂时无法对话。")
	_ensure_active_dialogue_epoch_for_npc(target_npc_id)
	var cancel_result := _cancel_npc_llm_request(target_npc_id, reason)
	if not bool(cancel_result.get("ok", true)):
		return cancel_result
	var interrupted_action_id := ""
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system != null and action_system.has_method("get_runtime_action_id"):
		interrupted_action_id = str(action_system.get_runtime_action_id(target_npc_id))
	var interruption_context := _build_player_dialogue_interruption_context(
		target_npc_id,
		interrupted_action_id
	)
	var interrupted_action := _interrupt_for_dialogue(target_npc_id)
	_active_dialogue["player_dialogue_effect_started"] = true
	_active_dialogue["session_status"] = "active"
	_active_dialogue["player_dialogue_interrupted_action"] = interrupted_action
	_active_dialogue["player_dialogue_interrupted_action_id"] = interrupted_action_id if interrupted_action else ""
	_active_dialogue["interrupted_activity_context"] = (
		interruption_context
		if interrupted_action and not interruption_context.is_empty()
		else {}
	)
	if interrupted_action and not interrupted_action_id.is_empty():
		var interrupted_actions: Dictionary = {}
		interrupted_actions[target_npc_id] = interrupted_action_id
		_active_dialogue["interrupted_plan_action_by_npc"] = interrupted_actions
	_set_player_dialogue_npc_runtime_state(false)
	return {
		"ok": true,
		"already_started": false,
		"cancel_result": cancel_result,
		"interrupted_action": interrupted_action,
		"interrupted_action_id": interrupted_action_id if interrupted_action else ""
	}


func _is_npc_plan_request_active(npc_id: String, npc_system: Node = null) -> bool:
	var resolved_npc_system := npc_system
	if resolved_npc_system == null:
		resolved_npc_system = get_node_or_null(NPC_SYSTEM_PATH)
	if resolved_npc_system == null or npc_id.is_empty():
		return false
	if resolved_npc_system.has_method("is_npc_plan_llm_active"):
		return bool(resolved_npc_system.is_npc_plan_llm_active(npc_id))
	if not resolved_npc_system.has_method("get_npc_llm_activity"):
		return false
	var activity: Dictionary = resolved_npc_system.get_npc_llm_activity(npc_id)
	return bool(activity.get("active", false)) and str(activity.get("kind", "")) == "plan"


func _get_runtime_action_id(npc_id: String) -> String:
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("get_runtime_action_id"):
		return ""
	return str(action_system.get_runtime_action_id(npc_id))


func get_npc_dialogue_epoch(npc_id: String) -> int:
	return int(_dialogue_epoch_by_npc.get(npc_id, 0))


func _ensure_active_dialogue_epoch_for_npc(npc_id: String) -> int:
	if npc_id.is_empty() or _active_dialogue.is_empty():
		return get_npc_dialogue_epoch(npc_id)
	var epochs: Dictionary = (
		(_active_dialogue.get("dialogue_epoch_by_npc", {}) as Dictionary).duplicate(true)
		if _active_dialogue.get("dialogue_epoch_by_npc", {}) is Dictionary
		else {}
	)
	if epochs.has(npc_id):
		return int(epochs.get(npc_id, get_npc_dialogue_epoch(npc_id)))
	var next_epoch := get_npc_dialogue_epoch(npc_id) + 1
	_dialogue_epoch_by_npc[npc_id] = next_epoch
	epochs[npc_id] = next_epoch
	_active_dialogue["dialogue_epoch_by_npc"] = epochs
	var daily_plan_system := get_node_or_null("/root/Main/Systems/DailyPlanSystem")
	if (
		daily_plan_system != null
		and daily_plan_system.has_method("advance_dialogue_resume_context_epoch")
	):
		daily_plan_system.advance_dialogue_resume_context_epoch(
			npc_id,
			next_epoch,
			str(_active_dialogue.get("dialogue_id", ""))
		)
	return next_epoch


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


func _build_player_dialogue_interruption_context(
	npc_id: String,
	runtime_action_id: String
) -> Dictionary:
	if npc_id.is_empty() or runtime_action_id.is_empty():
		return {}
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if npc_system == null or action_system == null:
		return {}
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	var runtime_snapshot: Dictionary = {}
	if action_system.has_method("get_runtime_action_snapshot"):
		runtime_snapshot = action_system.get_runtime_action_snapshot(npc_id)
	var action_definition: Dictionary = {}
	if action_system.has_method("get_action"):
		action_definition = action_system.get_action(runtime_action_id)
	var activity_before := _make_dialogue_activity_context(
		runtime_action_id,
		str(action_definition.get("name", runtime_action_id)),
		str(runtime_snapshot.get("phase", "active")),
		npc_state,
		runtime_snapshot,
		{}
	)
	if activity_before.is_empty():
		return {}

	var current_plan_activity: Dictionary = {}
	var daily_plan_system := get_node_or_null("/root/Main/Systems/DailyPlanSystem")
	if (
		daily_plan_system != null
		and daily_plan_system.has_method("get_current_plan_item")
	):
		var current_plan_item: Dictionary = daily_plan_system.get_current_plan_item(npc_id)
		var planned_action_id := str(current_plan_item.get("action_id", ""))
		if not planned_action_id.is_empty():
			var planned_definition: Dictionary = {}
			if action_system.has_method("get_action"):
				planned_definition = action_system.get_action(planned_action_id)
			current_plan_activity = _make_dialogue_activity_context(
				planned_action_id,
				str(current_plan_item.get(
					"action_name",
					planned_definition.get("name", planned_action_id)
				)),
				"planned",
				npc_state,
				{},
				current_plan_item
			)

	var resume_expected := (
		not current_plan_activity.is_empty()
		and str(current_plan_activity.get("action_id", "")) == runtime_action_id
	)
	return {
		"interrupted_by_guard_officer": true,
		"private_to_target_npc": true,
		"activity_before_interruption": activity_before,
		"current_plan_activity": current_plan_activity if not current_plan_activity.is_empty() else null,
		"expected_activity_after_dialogue": current_plan_activity.duplicate(true) if resume_expected else null,
		"resume_policy": (
			"resume_interrupted_activity_if_plan_unchanged"
			if resume_expected
			else "follow_current_plan_after_dialogue_resolution"
		),
		"resume_expected_if_plan_unchanged": resume_expected
	}


func _make_dialogue_activity_context(
	action_id: String,
	action_name: String,
	phase: String,
	npc_state: Dictionary,
	runtime_snapshot: Dictionary,
	plan_item: Dictionary
) -> Dictionary:
	if action_id.is_empty():
		return {}
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	var action_definition: Dictionary = {}
	if action_system != null and action_system.has_method("get_action"):
		action_definition = action_system.get_action(action_id)
	var target: Dictionary = (
		plan_item.get("target", {})
		if plan_item.get("target", {}) is Dictionary
		else {}
	)
	var target_id := str(runtime_snapshot.get("target_id", ""))
	if target_id.is_empty():
		for key in ["target_id", "target_npc_id", "building_id", "location_id"]:
			target_id = str(target.get(key, ""))
			if not target_id.is_empty():
				break
	var location_id := str(runtime_snapshot.get("building_id", ""))
	if location_id.is_empty():
		location_id = str(target.get("location_id", ""))
	if location_id.is_empty():
		location_id = str(action_definition.get("location_required", ""))
	if location_id.is_empty():
		location_id = str(npc_state.get("current_location", ""))
	var location_name := str(npc_state.get("current_location_name", ""))
	if location_id != str(npc_state.get("current_location", "")):
		location_name = ""
	var result := {
		"action_id": action_id,
		"action_name": action_name if not action_name.is_empty() else action_id,
		"phase": phase if phase in ["pending", "active", "external_active", "planned"] else "active",
		"location_id": location_id,
		"location_name": location_name,
		"target_id": target_id,
		"workstation_id": str(runtime_snapshot.get("workstation_id", ""))
	}
	if phase == "planned":
		result["day"] = _get_current_game_day()
		result["hour"] = clampi(int(plan_item.get("hour", _get_current_game_hour())), 0, 23)
	else:
		if runtime_snapshot.has("elapsed_seconds"):
			result["elapsed_seconds"] = maxf(0.0, float(runtime_snapshot.get("elapsed_seconds", 0.0)))
		if runtime_snapshot.has("duration_seconds"):
			result["duration_seconds"] = maxf(0.0, float(runtime_snapshot.get("duration_seconds", 0.0)))
	return result


func _get_current_game_day() -> int:
	var game_state := get_node_or_null("/root/GameState")
	return maxi(1, int(game_state.current_day)) if game_state != null else 1


func _get_current_game_hour() -> int:
	var game_state := get_node_or_null("/root/GameState")
	return clampi(int(game_state.current_hour), 0, 23) if game_state != null else 0


func _cancel_npc_llm_request(npc_id: String, reason: String) -> Dictionary:
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge == null or not llm_bridge.has_method("cancel_npc_llm_requests"):
		return {"ok": true, "cancelled": false}
	return llm_bridge.cancel_npc_llm_requests(npc_id, reason)


func _cancel_active_dialogue_llm_requests(reason: String) -> void:
	if _active_dialogue.is_empty():
		return
	var participant_ids: Array[String] = []
	for raw_npc_id in _active_dialogue.get("participant_npc_ids", []):
		var participant_npc_id := str(raw_npc_id)
		if not participant_npc_id.is_empty() and not participant_ids.has(participant_npc_id):
			participant_ids.append(participant_npc_id)
	var target_id := str(_active_dialogue.get("target_npc_id", ""))
	if not target_id.is_empty():
		participant_ids.append(target_id)
	var speaker_id := str(_active_dialogue.get("speaker_npc_id", ""))
	if not speaker_id.is_empty() and not participant_ids.has(speaker_id):
		participant_ids.append(speaker_id)
	for participant_id in participant_ids:
		_cancel_npc_llm_request(participant_id, reason)


func _pause_escape_for_dialogue(npc_id: String, dialogue_id: String) -> Dictionary:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("pause_escape_for_dialogue"):
		return _failure("combat_system_missing", "CombatSystem 不支持暂停逃离挽留。")
	return combat_system.pause_escape_for_dialogue(npc_id, dialogue_id)


func _resume_escape_dialogue_if_needed(ended_state: Dictionary, reason: String) -> Dictionary:
	if str(ended_state.get("dialogue_kind", "")) != ESCAPE_INTERVENTION_DIALOGUE_KIND:
		return {}
	var npc_id := str(ended_state.get("target_npc_id", ""))
	if npc_id.is_empty():
		return {}
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("resume_escape_after_dialogue"):
		return _failure("combat_system_missing", "CombatSystem 不支持恢复逃离移动。")
	return combat_system.resume_escape_after_dialogue(npc_id, reason)


func get_dialogue_state() -> Dictionary:
	if _active_dialogue.is_empty() and not _player_dialogue_draft.is_empty():
		return _decorate_dialogue_state(_player_dialogue_draft)
	return _decorate_dialogue_state(_active_dialogue)


func get_display_dialogue_state() -> Dictionary:
	if not _player_dialogue_draft.is_empty():
		return _decorate_dialogue_state(_player_dialogue_draft)
	return get_dialogue_state()


func get_autonomous_dialogue_observer_state(npc_id: String, dialogue_id: String = "") -> Dictionary:
	if (
		_active_dialogue.is_empty()
		or str(_active_dialogue.get("dialogue_kind", "")) != "npc_npc"
		or not bool(_active_dialogue.get("autonomous", false))
	):
		return {}
	if not dialogue_id.is_empty() and dialogue_id != str(_active_dialogue.get("dialogue_id", "")):
		return {}
	var participant_ids: Array = _active_dialogue.get("participant_npc_ids", [])
	if not participant_ids.has(npc_id):
		return {}
	var state := get_dialogue_state()
	state["observer_mode"] = true
	return state


func _decorate_dialogue_state(source: Dictionary) -> Dictionary:
	var state := source.duplicate(true)
	if state.is_empty():
		return state
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var target_npc_id := str(state.get("target_npc_id", ""))
	state["target_recruited"] = npc_system != null and bool(npc_system.get_npc(target_npc_id).get("recruited", false))
	return state


func set_dialogue_visibility(visibility: String) -> Dictionary:
	var editing_draft := not _player_dialogue_draft.is_empty()
	var dialogue_state: Dictionary = _player_dialogue_draft if editing_draft else _active_dialogue
	if dialogue_state.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	if bool(dialogue_state.get("force_local_public", false)):
		dialogue_state["visibility"] = "local_public"
		if editing_draft:
			_player_dialogue_draft = dialogue_state
		else:
			_active_dialogue = dialogue_state
		dialogue_updated.emit(get_display_dialogue_state())
		var message := "逃离挽留必须保持同地点公开。" if str(dialogue_state.get("dialogue_kind", "")) == ESCAPE_INTERVENTION_DIALOGUE_KIND else "战时对话必须保持同地点公开。"
		return _failure("visibility_forced_local_public", message)
	if bool(dialogue_state.get("waiting", false)) or int(dialogue_state.get("current_round", 0)) > 0:
		return _failure("visibility_locked", "对话开始发送后不能修改公开性。")
	if not ["private", "local_public"].has(visibility):
		return _failure("invalid_visibility", "对话公开性只能是 private 或 local_public。")
	dialogue_state["visibility"] = visibility
	if editing_draft:
		_player_dialogue_draft = dialogue_state
	else:
		_active_dialogue = dialogue_state
	var display_state := get_display_dialogue_state()
	dialogue_updated.emit(display_state)
	return {"ok": true, "dialogue_state": display_state}


func set_recruitment_request_pending(enabled: bool = true) -> Dictionary:
	var editing_draft := not _player_dialogue_draft.is_empty()
	var dialogue_state: Dictionary = _player_dialogue_draft if editing_draft else _active_dialogue
	if dialogue_state.is_empty():
		return _failure("dialogue_not_started", "当前没有进行中的对话。")
	if str(dialogue_state.get("dialogue_kind", "")) != "player_npc":
		return _failure("invalid_dialogue_kind", "只有守备官与 NPC 对话时可以提出应征。")
	if bool(dialogue_state.get("waiting", false)):
		return _failure("dialogue_waiting", "正在等待 NPC 回复。")
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var target_npc_id := str(dialogue_state.get("target_npc_id", ""))
	if npc_system == null or npc_system.get_npc(target_npc_id).is_empty():
		return _failure("npc_not_found", "找不到应征目标。")
	if bool(npc_system.get_npc(target_npc_id).get("recruited", false)):
		return _failure("npc_already_recruited", "该 NPC 已经入伍。")
	dialogue_state["recruitment_request_pending"] = enabled
	if editing_draft:
		_player_dialogue_draft = dialogue_state
	else:
		_active_dialogue = dialogue_state
	var display_state := get_display_dialogue_state()
	dialogue_updated.emit(display_state)
	return {"ok": true, "dialogue_state": display_state}


func is_dialogue_active() -> bool:
	return not _active_dialogue.is_empty() or not _player_dialogue_draft.is_empty()


func has_active_dialogue() -> bool:
	return not _active_dialogue.is_empty()


func is_npc_in_dialogue(npc_id: String) -> bool:
	if npc_id.is_empty() or _active_dialogue.is_empty():
		return false
	for raw_npc_id in _active_dialogue.get("participant_npc_ids", []):
		if str(raw_npc_id) == npc_id:
			return true
	return str(_active_dialogue.get("target_npc_id", "")) == npc_id or str(_active_dialogue.get("speaker_npc_id", "")) == npc_id


func get_active_dialogue_id() -> String:
	return str(_active_dialogue.get("dialogue_id", ""))


func _apply_recruitment_result(response: Dictionary, was_recruitment_request: bool) -> String:
	if not was_recruitment_request:
		return "none"
	var recruitment_result := str(response.get("recruitment_result", "none"))
	if not ["accept", "reject"].has(recruitment_result):
		return "none"
	_active_dialogue["session_had_recruitment_request"] = true
	_active_dialogue["deferred_recruitment_result"] = recruitment_result
	return recruitment_result


func _get_player_dialogue_interaction_context(npc_id: String, npc_state: Dictionary, npc_system: Node) -> String:
	if _is_active_escape_dialogue_target(npc_state):
		return ESCAPE_INTERVENTION_DIALOGUE_KIND
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
	var interaction_context := str(_active_dialogue.get("interaction_context", "work"))
	if interaction_context != "avoid_combat":
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
		"rule_fallback": true,
		"fallback_error_code": str(error_result.get("error_code", "")),
		"fallback_message": str(error_result.get("message", "后端请求失败。"))
	}


func _make_escape_intervention_rule_fallback_response(pending: Dictionary, error_result: Dictionary) -> Dictionary:
	var clean_text := str(pending.get("clean_text", "")).strip_edges()
	if clean_text.is_empty():
		clean_text = GUARD_ATTACK_PROMPT if str(pending.get("kind", "")) == "guard_attack" else ""
	var stay := _text_contains_any(clean_text, ["留下", "别走", "不要走", "守住", "保护", "一起", "需要你", "补偿", "钱", "给你", "照顾", "帮忙"])
	if _text_contains_any(clean_text, ["滚", "走吧", "逃", "跑", "别管", "随便你"]) or str(pending.get("kind", "")) == "guard_attack":
		stay = false
	return {
		"replyer_id": str(_active_dialogue.get("target_npc_id", "")),
		"reply_text": "我听见了。那我留下，但你得记住今天说过的话。" if stay else "你现在说什么都太迟了。我还是要离开这里。",
		"emotion": "shaken" if stay else "fearful",
		"attitude_delta": 0,
		"relationship_delta": 0,
		"escape_intervention_result": "stay" if stay else "leave",
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
	if interaction_context == "avoid_combat":
		return {}
	var reaction := _normalize_wartime_reaction(str(response.get("wartime_reaction", "none")))
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


func _apply_escape_intervention_response(response: Dictionary, dialogue_event: Dictionary) -> Dictionary:
	if _active_dialogue.is_empty() or str(_active_dialogue.get("dialogue_kind", "")) != ESCAPE_INTERVENTION_DIALOGUE_KIND:
		return {}
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("apply_escape_intervention_result"):
		return {}
	var result: Dictionary = combat_system.apply_escape_intervention_result(str(_active_dialogue.get("target_npc_id", "")), response, {
		"dialogue_id": str(_active_dialogue.get("dialogue_id", "")),
		"dialogue_event_id": str(dialogue_event.get("event_id", "")),
		"current_round": int(_active_dialogue.get("current_round", 0)),
		"max_rounds": int(_active_dialogue.get("max_rounds", ESCAPE_INTERVENTION_MAX_ROUNDS)),
		"interaction_kind": str(dialogue_event.get("interaction_kind", ""))
	})
	_active_dialogue["last_escape_intervention_result"] = result.duplicate(true)
	if not bool(result.get("ok", false)):
		_active_dialogue["last_error"] = str(result.get("message", "逃离挽留结果应用失败。"))
	return result


func _record_escape_attack_intervention_round(npc_id: String, current_round: int, source_event_id: String) -> Dictionary:
	if _active_dialogue.is_empty() or str(_active_dialogue.get("dialogue_kind", "")) != ESCAPE_INTERVENTION_DIALOGUE_KIND:
		return {}
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("record_escape_attack_intervention_round"):
		return {}
	var result: Dictionary = combat_system.record_escape_attack_intervention_round(npc_id, current_round, {
		"dialogue_id": str(_active_dialogue.get("dialogue_id", "")),
		"source_event_id": source_event_id,
		"interaction_kind": "escape_guard_attack_no_reply"
	})
	_active_dialogue["last_escape_intervention_result"] = result.duplicate(true)
	if not bool(result.get("ok", false)):
		_active_dialogue["last_error"] = str(result.get("message", "逃离攻击轮次记录失败。"))
	return result


func _is_escape_intervention_state(npc_state: Dictionary) -> bool:
	if not _is_active_escape_dialogue_target(npc_state):
		return false
	var escape_intent: Dictionary = npc_state.get("escape_intent", {}) if npc_state.get("escape_intent", {}) is Dictionary else {}
	return int(escape_intent.get("intervention_rounds_used", 0)) < int(escape_intent.get("intervention_max_rounds", ESCAPE_INTERVENTION_MAX_ROUNDS))


func _is_active_escape_dialogue_target(npc_state: Dictionary) -> bool:
	if bool(npc_state.get("unconscious", false)) or bool(npc_state.get("escaped", false)):
		return false
	var escape_intent: Dictionary = npc_state.get("escape_intent", {}) if npc_state.get("escape_intent", {}) is Dictionary else {}
	if not bool(escape_intent.get("active", false)) or str(escape_intent.get("status", "")) != "escaping":
		return false
	return true


func _record_dialogue_event(
	event_type: String,
	extra_payload: Dictionary,
	event_context: Dictionary = {}
) -> Dictionary:
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
	if str(_active_dialogue.get("dialogue_kind", "")) == "npc_npc":
		payload["soft_round_threshold"] = int(_active_dialogue.get("soft_round_threshold", NPC_DIALOGUE_DEFAULT_SOFT_ROUND_THRESHOLD))
		payload["soft_round_guidance"] = str(_active_dialogue.get("soft_round_guidance", ""))
	for key in extra_payload.keys():
		payload[key] = extra_payload[key]
	var subject_npc_id := str(event_context.get("subject_npc_id", target_npc_id))
	var actor_ids: Array = event_context.get(
		"actor_ids",
		[GUARD_OFFICER_ID if ["player_npc", ESCAPE_INTERVENTION_DIALOGUE_KIND].has(str(_active_dialogue.get("dialogue_kind", "player_npc"))) else str(_active_dialogue.get("speaker_npc_id", ""))]
	)
	return memory_system.add_event({
		"type": event_type,
		"subject_npc_id": subject_npc_id,
		"actor_ids": actor_ids,
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


func _build_npc_dialogue_soft_round_guidance(soft_round_threshold: int) -> String:
	var threshold := maxi(1, soft_round_threshold)
	return (
		"soft_round_threshold 只是偏晚阶段的收尾保险，不是最低轮数、目标轮数或继续理由，绝不能为了等到阈值而续聊。"
		+ "每轮若不能推进 conversation_history 中已经存在的未决紧急或必要事项，只能确认、复述或改写已有内容，必须在本轮用至多一句简短收尾并设置 should_end_dialogue=true；对方已经完整回答或双方已经达成一致时也必须结束。"
		+ "不得为了延长对话自行制造新话题、新任务、新问题、额外帮助或后续安排。"
		+ "current_round 超过 %d（即第 %d 轮起）且没有尚未说清的紧急或必要事项时必须告别结束；只有本轮确实能推进必要新内容时才可继续。"
	) % [threshold, threshold + 1]


func _is_npc_in_work_behavior_mode(npc_id: String, npc_system: Node) -> bool:
	if npc_system == null or npc_id.is_empty():
		return false
	if npc_system.has_method("get_npc_behavior_mode_snapshot"):
		var snapshot: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
		return str(snapshot.get("behavior_mode", "work")) == "work"
	return true


func _failure(error_code: String, message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "message": message}
