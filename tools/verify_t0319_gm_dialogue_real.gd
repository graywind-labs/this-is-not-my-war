extends SceneTree


const SPEAKER_ID := "stableman_01"
const TARGET_ID := "cook_01"
const REAL_TEST_ENV := "T0319_ALLOW_REAL_LLM"
const TIMEOUT_MSEC := 180000

var _dialog_system: Node
var _npc_system: Node
var _target_position_before: Variant
var _target_action_before := ""
var _max_target_drift := 0.0
var _saw_invitation_pending := false
var _invitation_distance := INF
var _ended_state: Dictionary = {}
var _llm_responses: Array[Dictionary] = []


func _init() -> void:
	if OS.get_environment(REAL_TEST_ENV) != "1":
		_fail("Real LLM verification is locked; set %s=1 explicitly" % REAL_TEST_ENV)
		return

	var main := preload("res://scenes/main/Main.tscn").instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		# Prevent normal startup from generating plans for all eight NPCs. This
		# verification is deliberately limited to invitation + first reply.
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
		or str(adapter.get("provider", "")).to_lower() != "deepseek"
		or not bool(adapter.get("configured", false))
		or bool(adapter.get("fallback_to_mock", true))
	):
		_fail("Backend is not a configured non-fallback DeepSeek provider: %s" % adapter)
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
		"布鲁诺，我走过来是想请教今天马匹饲料和餐食怎么协调，不耽误你太久，你愿意聊两句吗？"
	)
	_update_spatial_observation()
	if _max_target_drift > 0.01:
		_fail("GM dialogue teleported the target when route assignment started")
		return

	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline and _ended_state.is_empty():
		await physics_frame
		_update_spatial_observation()

	if _ended_state.is_empty():
		_fail("Timed out before invitation + first real reply completed")
		return
	if _max_target_drift > 0.01:
		_fail("Target moved during GM dialogue flow; max drift=%.3f" % _max_target_drift)
		return
	if not _saw_invitation_pending or _invitation_distance < 0.8 or _invitation_distance > 2.3:
		_fail("Speaker did not approach stationary target before invitation; distance=%.3f" % _invitation_distance)
		return
	if str(_ended_state.get("invitation_result", "")) != "accept":
		_fail("Real target did not accept invitation: %s" % str(_ended_state.get("invitation_result", "")))
		return
	if int(_ended_state.get("current_round", 0)) != 1:
		_fail("Expected exactly one conversation round, got %d" % int(_ended_state.get("current_round", 0)))
		return
	if _llm_responses.size() != 2:
		_fail("Expected exactly two provider responses, got %d" % _llm_responses.size())
		return
	for result in _llm_responses:
		var dialogue: Dictionary = result.get("dialogue", {})
		if (
			not bool(result.get("ok", false))
			or str(dialogue.get("model_provider", "")).to_lower() != "deepseek"
			or bool(dialogue.get("model_fallback_used", true))
		):
			_fail("Response did not come from real DeepSeek without fallback: %s" % dialogue)
			return
	var history: Array = _ended_state.get("history", [])
	print("T0319 real GM dialogue verification passed: invitation=accept round=1 responses=2 target_drift=%.3f distance=%.3f history_turns=%d" % [
		_max_target_drift,
		_invitation_distance,
		history.size()
	])
	quit(0)


func _on_llm_response(result: Dictionary) -> void:
	_llm_responses.append(result.duplicate(true))


func _on_dialogue_updated(dialogue_state: Dictionary) -> void:
	if (
		str(dialogue_state.get("session_status", "")) == "invitation_pending"
		and not bool(dialogue_state.get("waiting", false))
	):
		_saw_invitation_pending = true
		_invitation_distance = _current_horizontal_distance()
	# Stop immediately after the first completed conversational response. The
	# suppression is test-only and prevents both autonomous round 2 and the
	# post-dialogue plan-judgement calls from consuming extra quota.
	if (
		int(dialogue_state.get("current_round", 0)) >= 1
		and not bool(dialogue_state.get("waiting", false))
		and not _dialog_system.get_dialogue_state().is_empty()
	):
		_dialog_system.end_dialogue("t0319_real_verification_complete", {
			"suppress_plan_reevaluation": true,
			"suppress_dialogue_resume": true
		})


func _on_dialogue_ended(dialogue_state: Dictionary) -> void:
	_ended_state = dialogue_state.duplicate(true)


func _update_spatial_observation() -> void:
	var target_position: Variant = _npc_system.get_npc_world_position(TARGET_ID)
	if target_position is Vector3 and _target_position_before is Vector3:
		_max_target_drift = maxf(_max_target_drift, target_position.distance_to(_target_position_before))
	var state_action := str(_npc_system.get_npc_state(TARGET_ID).get("current_action", ""))
	var dialogue_state: Dictionary = _dialog_system.get_dialogue_state()
	if (
		str(dialogue_state.get("session_status", "")) == "invitation_pending"
		and state_action == _target_action_before
	):
		_saw_invitation_pending = true
		_invitation_distance = _current_horizontal_distance()


func _current_horizontal_distance() -> float:
	var speaker_position: Variant = _npc_system.get_npc_world_position(SPEAKER_ID)
	var target_position: Variant = _npc_system.get_npc_world_position(TARGET_ID)
	if not speaker_position is Vector3 or not target_position is Vector3:
		return INF
	return Vector2(speaker_position.x - target_position.x, speaker_position.z - target_position.z).length()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
