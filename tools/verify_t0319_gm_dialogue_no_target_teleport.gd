extends SceneTree


class ControlledDialogueBridge:
	extends Node

	signal dialogue_async_response_received(result: Dictionary)
	signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)

	var invitation_request: Dictionary = {}

	func request_npc_dialogue_async(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
		var request_id := str(options.get("request_id", "verify_t0319_dialogue"))
		if str(options.get("dialogue_phase", "conversation")) == "invitation":
			invitation_request = {
				"request_id": request_id,
				"npc_id": npc_id,
				"speaker_text": speaker_text,
				"options": options.duplicate(true)
			}
		return {"ok": true, "pending": true, "request_id": request_id}

	func answer_invitation_accept() -> void:
		var request := invitation_request.duplicate(true)
		invitation_request.clear()
		dialogue_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"dialogue": {
				"ok": true,
				"replyer_id": str(request.get("npc_id", "")),
				"reply_text": "好，你过来吧，我们就在这里说。",
				"response_kind": "reply_to_npc",
				"invitation_result": "accept",
				"emotion": "neutral",
				"should_end_dialogue": false,
				"suggested_event_type": "dialogue_turn",
				"debug_reason": "t0319_controlled_accept",
				"model_provider": "fake_real_provider",
				"model_name": "functional-test",
				"model_fallback_used": false
			}
		})

	func cancel_npc_llm_requests(_npc_id: String, _reason: String = "cancelled") -> Dictionary:
		return {"ok": true, "cancelled": false}

	func check_health() -> Dictionary:
		return _health()

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _health()

	func request_dialogue_plan_revision_judgement_async(npc_id: String, _options: Dictionary = {}) -> Dictionary:
		return {"ok": true, "pending": true, "request_id": "t0319_judgement_%s" % npc_id}

	func _health() -> Dictionary:
		return {"ok": true, "body": {"model_adapter": {
			"provider": "fake_real_provider",
			"model": "functional-test",
			"configured": true,
			"fallback_to_mock": false
		}}}


const SPEAKER_ID := "stableman_01"
const TARGET_ID := "cook_01"


func _init() -> void:
	var main := preload("res://scenes/main/Main.tscn").instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup.set("_startup_running", true)
	root.add_child(main)
	await process_frame
	await physics_frame

	var systems := root.get_node("Main/Systems")
	var npc_system := root.get_node("Main/Systems/NPCSystem")
	var action_system := root.get_node("Main/Systems/ActionSystem")
	var dialog_system := root.get_node("Main/Systems/DialogSystem")
	var time_system := root.get_node("Main/Systems/TimeSystem")
	var gm_panel := root.get_node("Main/UI/GMPanel")
	var original_bridge := systems.get_node("LLMBridge")
	time_system.set_time_scale(0.0)
	time_system.set_paused(false)
	systems.remove_child(original_bridge)
	original_bridge.name = "PayloadLLMBridge"
	main.add_child(original_bridge)
	var fake_bridge := ControlledDialogueBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)
	fake_bridge.dialogue_async_response_received.connect(Callable(dialog_system, "_on_dialogue_async_response_received"))

	npc_system.debug_enter_location_immediately(SPEAKER_ID, "plaza")
	npc_system.debug_enter_location_immediately(TARGET_ID, "clinic")
	var target_position_before: Variant = npc_system.get_npc_world_position(TARGET_ID)
	var target_action_before := str(npc_system.get_npc_state(TARGET_ID).get("current_action", ""))
	gm_panel.call(
		"_run_npc_talk",
		SPEAKER_ID,
		TARGET_ID,
		"布鲁诺，我走过来问问你是否愿意谈谈。"
	)
	var target_position_after_start: Variant = npc_system.get_npc_world_position(TARGET_ID)
	if not _same_position(target_position_before, target_position_after_start):
		_fail("GM dialogue teleported the target when the route started")
		return

	if not await _wait_for_invitation(dialog_system, fake_bridge, 3000):
		_fail("Speaker did not reach the stationary target and request an invitation")
		return
	var target_position_at_invitation: Variant = npc_system.get_npc_world_position(TARGET_ID)
	var speaker_position: Variant = npc_system.get_npc_world_position(SPEAKER_ID)
	var distance := _horizontal_distance(speaker_position, target_position_at_invitation)
	if (
		not _same_position(target_position_before, target_position_at_invitation)
		or str(npc_system.get_npc_state(TARGET_ID).get("current_action", "")) != target_action_before
		or distance < 0.8
		or distance > 2.3
	):
		_fail("Invitation changed the target before acceptance or speaker did not approach: distance=%.3f" % distance)
		return

	fake_bridge.answer_invitation_accept()
	if not await _wait_for_status(dialog_system, "active", 180):
		_fail("Accepted invitation did not open the NPC-NPC dialogue")
		return
	if (
		str(npc_system.get_npc_state(SPEAKER_ID).get("current_action", "")) != "talk_to_npc"
		or str(npc_system.get_npc_state(TARGET_ID).get("current_action", "")) != "talk_to_npc"
	):
		_fail("Accepted invitation did not transfer both NPCs into dialogue")
		return

	print("T0319 GM dialogue no-target-teleport verification passed.")
	quit(0)


func _wait_for_invitation(dialog_system: Node, fake_bridge: Node, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await physics_frame
		if (
			str(dialog_system.get_dialogue_state().get("session_status", "")) == "invitation_pending"
			and not fake_bridge.get("invitation_request").is_empty()
		):
			return true
	return false


func _wait_for_status(dialog_system: Node, expected_status: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await process_frame
		if str(dialog_system.get_dialogue_state().get("session_status", "")) == expected_status:
			return true
	return false


func _same_position(a: Variant, b: Variant) -> bool:
	return a is Vector3 and b is Vector3 and a.distance_to(b) <= 0.01


func _horizontal_distance(a: Variant, b: Variant) -> float:
	if not a is Vector3 or not b is Vector3:
		return INF
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
