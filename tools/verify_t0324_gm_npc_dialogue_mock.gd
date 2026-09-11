extends SceneTree


const SPEAKER_ID := "stableman_01"
const TARGET_ID := "cook_01"
const TIMEOUT_MSEC := 30000

var _dialog_system: Node
var _npc_system: Node
var _target_position_before: Variant
var _target_action_before := ""
var _max_target_drift_before_accept := 0.0
var _saw_invitation_pending := false
var _saw_active := false
var _saw_both_talking := false
var _max_round := 0
var _ended_state: Dictionary = {}
var _responses: Array[Dictionary] = []


func _init() -> void:
	var main := preload("res://scenes/main/Main.tscn").instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		# This verification exercises only the selected GM dialogue. It never
		# creates the eight-NPC startup planning batch.
		startup.set("_startup_running", true)
	root.add_child(main)
	await process_frame
	await physics_frame

	_npc_system = root.get_node("Main/Systems/NPCSystem")
	_dialog_system = root.get_node("Main/Systems/DialogSystem")
	var time_system := root.get_node("Main/Systems/TimeSystem")
	var llm_bridge := root.get_node("Main/Systems/LLMBridge")
	var gm_panel := root.get_node("Main/UI/GMPanel")
	time_system.set_time_scale(0.0)
	time_system.set_paused(false)

	var health: Dictionary = llm_bridge.check_health()
	var adapter: Dictionary = health.get("body", {}).get("model_adapter", {})
	if (
		not bool(health.get("ok", false))
		or str(adapter.get("provider", "")).strip_edges().to_lower() != "mock"
		or bool(adapter.get("fallback_to_mock", false))
	):
		_fail("T0324 requires an explicit non-fallback Mock backend: %s" % adapter)
		return

	llm_bridge.dialogue_async_response_received.connect(_on_llm_response)
	_dialog_system.dialogue_updated.connect(_on_dialogue_updated)
	_dialog_system.dialogue_ended.connect(_on_dialogue_ended)

	_npc_system.debug_enter_location_immediately(SPEAKER_ID, "plaza")
	_npc_system.debug_enter_location_immediately(TARGET_ID, "clinic")
	_target_position_before = _npc_system.get_npc_world_position(TARGET_ID)
	_target_action_before = str(_npc_system.get_npc_state(TARGET_ID).get("current_action", ""))
	gm_panel.call(
		"_run_npc_talk",
		SPEAKER_ID,
		TARGET_ID,
		"布鲁诺，我想和你谈谈今天马匹饲料与餐食怎么协调。"
	)

	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline and _ended_state.is_empty():
		await physics_frame
		_observe_runtime()

	if _ended_state.is_empty():
		_fail("T0324 Mock dialogue timed out before natural completion: %s" % _dialog_system.get_dialogue_state())
		return
	if not _saw_invitation_pending:
		_fail("T0324 Mock flow never reached invitation_pending")
		return
	if _max_target_drift_before_accept > 0.01:
		_fail("T0324 target moved before accepting the Mock invitation: %.3f" % _max_target_drift_before_accept)
		return
	if not _saw_active or not _saw_both_talking:
		_fail("T0324 accepted Mock invitation did not transfer both NPCs into active dialogue")
		return
	if _max_round < 1:
		_fail("T0324 Mock conversation never completed a formal round")
		return
	if str(_ended_state.get("invitation_result", "")) != "accept":
		_fail("T0324 Mock invitation was not accepted: %s" % _ended_state)
		return
	if str(_ended_state.get("end_reason", "")) != "autonomous_dialogue_completed":
		_fail("T0324 Mock conversation did not end through the normal model contract: %s" % _ended_state)
		return
	if (_ended_state.get("history", []) as Array).size() < 3:
		_fail("T0324 Mock conversation history did not contain invitation and conversation turns")
		return
	if _responses.size() < 2:
		_fail("T0324 expected invitation plus conversation Mock responses, got %d" % _responses.size())
		return
	for result in _responses:
		var response: Dictionary = result.get("dialogue", {})
		if (
			not bool(result.get("ok", false))
			or str(response.get("model_provider", "")).strip_edges().to_lower() != "mock"
			or bool(response.get("model_fallback_used", true))
		):
			_fail("T0324 response was not explicit non-fallback Mock: %s" % response)
			return
	for npc_id in [SPEAKER_ID, TARGET_ID]:
		var state: Dictionary = _npc_system.get_npc_state(npc_id)
		if not str(state.get("active_dialogue_id", "")).is_empty():
			_fail("T0324 participant kept an active dialogue id after completion: %s" % state)
			return
	_dialog_system._active_dialogue = {"require_real_provider": false}
	var explicit_mock_validation: Dictionary = _dialog_system._validate_autonomous_dialogue_provider({
		"model_provider": "mock",
		"model_fallback_used": false,
	})
	var fallback_validation: Dictionary = _dialog_system._validate_autonomous_dialogue_provider({
		"model_provider": "mock",
		"model_fallback_used": true,
	})
	_dialog_system._active_dialogue.clear()
	if not explicit_mock_validation.is_empty():
		_fail("T0324 explicit Mock was rejected by provider validation: %s" % explicit_mock_validation)
		return
	if str(fallback_validation.get("error_code", "")) != "model_fallback_forbidden":
		_fail("T0324 real-provider fallback was not rejected: %s" % fallback_validation)
		return

	print("T0324_GM_NPC_DIALOGUE_MOCK_OK %s" % JSON.stringify({
		"provider": adapter.get("provider", ""),
		"responses": _responses.size(),
		"max_round": _max_round,
		"history_turns": (_ended_state.get("history", []) as Array).size(),
		"end_reason": _ended_state.get("end_reason", ""),
		"target_drift_before_accept": _max_target_drift_before_accept,
	}))
	quit(0)


func _on_llm_response(result: Dictionary) -> void:
	_responses.append(result.duplicate(true))


func _on_dialogue_updated(dialogue_state: Dictionary) -> void:
	var status := str(dialogue_state.get("session_status", ""))
	_saw_invitation_pending = _saw_invitation_pending or status == "invitation_pending"
	_saw_active = _saw_active or status == "active"
	_max_round = maxi(_max_round, int(dialogue_state.get("current_round", 0)))
	if status == "active":
		_saw_both_talking = _saw_both_talking or (
			str(_npc_system.get_npc_state(SPEAKER_ID).get("current_action", "")) == "talk_to_npc"
			and str(_npc_system.get_npc_state(TARGET_ID).get("current_action", "")) == "talk_to_npc"
		)


func _on_dialogue_ended(dialogue_state: Dictionary) -> void:
	_ended_state = dialogue_state.duplicate(true)


func _observe_runtime() -> void:
	var dialogue_state: Dictionary = _dialog_system.get_dialogue_state()
	if str(dialogue_state.get("session_status", "")) != "invitation_pending":
		return
	var target_position: Variant = _npc_system.get_npc_world_position(TARGET_ID)
	if target_position is Vector3 and _target_position_before is Vector3:
		_max_target_drift_before_accept = maxf(
			_max_target_drift_before_accept,
			target_position.distance_to(_target_position_before)
		)
	if str(_npc_system.get_npc_state(TARGET_ID).get("current_action", "")) != _target_action_before:
		_fail("T0324 invitation interrupted the target before acceptance")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
