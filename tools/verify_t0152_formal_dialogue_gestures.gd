extends SceneTree


class ControlledInvitationBridge:
	extends Node

	signal dialogue_async_response_received(result: Dictionary)
	signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)

	var invitation_request: Dictionary = {}
	var conversation_requests: Array[Dictionary] = []

	func request_npc_dialogue_async(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
		var request_id := str(options.get("request_id", "t0152_request"))
		var request := {
			"request_id": request_id,
			"npc_id": npc_id,
			"speaker_text": speaker_text,
			"options": options.duplicate(true)
		}
		if str(options.get("dialogue_phase", "conversation")) == "invitation":
			invitation_request = request
		else:
			conversation_requests.append(request)
		return {"ok": true, "pending": true, "request_id": request_id}

	func answer_invitation(decision: String) -> void:
		if invitation_request.is_empty():
			return
		var request := invitation_request.duplicate(true)
		invitation_request.clear()
		dialogue_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"dialogue": {
				"ok": true,
				"replyer_id": str(request.get("npc_id", "")),
				"reply_text": "好，我停下手里的事听你说。" if decision == "accept" else "我现在不能停下手里的事。",
				"response_kind": "reply_to_npc",
				"invitation_result": decision,
				"emotion": "neutral",
				"should_end_dialogue": decision == "reject",
				"suggested_event_type": "dialogue_turn",
				"debug_reason": "t0152_controlled_invitation",
				"model_provider": "fake_real_provider",
				"model_name": "t0152-functional-test",
				"model_fallback_used": false
			}
		})

	func cancel_npc_llm_requests(_npc_id: String, reason: String = "cancelled") -> Dictionary:
		return {"ok": true, "cancelled": false, "reason": reason}

	func check_health() -> Dictionary:
		return _real_health()

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()

	func request_dialogue_plan_revision_judgement_async(npc_id: String, _options: Dictionary = {}) -> Dictionary:
		return {"ok": true, "pending": true, "request_id": "t0152_judgement_%s" % npc_id}

	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {"model_adapter": {
				"provider": "fake_real_provider",
				"model": "t0152-functional-test",
				"configured": true,
				"fallback_to_mock": false
			}}
		}


const SPEAKER_ID := "stableman_01"
const TARGET_ID := "doctor_01"
const TARGET_ACTION_ID := "work_clinic_doctor"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var systems := root.get_node_or_null("Main/Systems")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [systems, npc_system, action_system, dialog_system, daily_plan_system, time_system, original_bridge].has(null):
		_fail("T0152 runtime dependencies unavailable")
		return
	time_system.set_time_scale(0.0)
	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(false)
	for raw_npc_id in npc_system.get_npc_ids():
		original_bridge.cancel_npc_llm_requests(str(raw_npc_id), "verify_t0152_isolation")
	daily_plan_system.set("_async_plan_queue", [])
	daily_plan_system.set("_async_plan_requests", {})
	systems.remove_child(original_bridge)
	original_bridge.queue_free()
	await process_frame
	var fake_bridge := ControlledInvitationBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)
	fake_bridge.dialogue_async_response_received.connect(Callable(dialog_system, "_on_dialogue_async_response_received"))
	# Main schedules its initial day-plan batch deferred. Let that scheduling edge
	# drain under both dummy and Forward+ renderers, then clear its transient state
	# once more so it cannot interrupt this deterministic presentation fixture.
	for _frame in range(10):
		await process_frame
		await physics_frame
	daily_plan_system.set("_async_plan_queue", [])
	daily_plan_system.set("_async_plan_requests", {})
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) == "planning_day":
			npc_system.update_npc_state(npc_id, {
				"current_action": "idle",
				"last_action_result": "t0152_fixture_ready"
			})
	time_system.set_paused(false)

	_set_move_speed(npc_system, SPEAKER_ID, 12.0)
	_set_move_speed(npc_system, TARGET_ID, 12.0)
	npc_system.debug_enter_location_immediately(SPEAKER_ID, "plaza")
	npc_system.debug_enter_location_immediately(TARGET_ID, "clinic")
	if not action_system.debug_assign_action(TARGET_ID, TARGET_ACTION_ID):
		_fail("Could not start target clinic work")
		return
	if not await _wait_for_action_phase(action_system, TARGET_ID, TARGET_ACTION_ID, "active", 1800):
		_fail("Target did not reach clinic work before T0152 verification: %s" % JSON.stringify({
			"runtime": action_system.get_runtime_action_snapshot(TARGET_ID),
			"state": npc_system.get_npc_state(TARGET_ID),
			"spatial": npc_system.debug_get_spatial_migration_snapshot(TARGET_ID)
		}))
		return

	# Cancelling the approach before arrival must not emit any gesture event.
	if not action_system.assign_npc_dialogue(SPEAKER_ID, TARGET_ID, "先取消这次接近。", 5, false):
		_fail("Could not start cancellable formal dialogue approach")
		return
	action_system.interrupt_npc_action(SPEAKER_ID, "t0152_cancel_before_arrival")
	await process_frame
	if not (npc_system.get_temporary_presentation_event_snapshot().get("events", []) as Array).is_empty():
		_fail("Cancelled approach emitted a temporary presentation event")
		return
	if str(npc_system.get_npc_state(TARGET_ID).get("current_action", "")) != TARGET_ACTION_ID:
		_fail("Cancelled approach interrupted the invited NPC's work")
		return

	# Rejection: only the arrived initiator gestures; the invitee keeps working.
	if not action_system.assign_npc_dialogue(SPEAKER_ID, TARGET_ID, "莉娜，我想和你谈谈。", 5, false):
		_fail("Could not start rejection route")
		return
	if not await _wait_for_invitation(dialog_system, fake_bridge, 2400):
		_fail("Speaker did not arrive before rejection invitation")
		return
	var pending_events: Array = npc_system.get_temporary_presentation_event_snapshot().get("events", [])
	if pending_events.size() != 1:
		_fail("Invitation send must emit exactly one initiator gesture: %s" % str(pending_events))
		return
	var send_event: Dictionary = pending_events[0]
	var speaker_art: Dictionary = npc_system.debug_get_npc_character_art_snapshot(SPEAKER_ID)
	var target_art_before: Dictionary = npc_system.debug_get_npc_character_art_snapshot(TARGET_ID)
	if (
		str(send_event.get("event_kind", "")) != "invitation_sent"
		or str(send_event.get("npc_id", "")) != SPEAKER_ID
		or str(send_event.get("authority_action_at_emit", "")) != "idle"
		or str(npc_system.get_npc_state(TARGET_ID).get("current_action", "")) != TARGET_ACTION_ID
		or str(speaker_art.get("temporary_presentation_state", "")) != "talk"
		or int(target_art_before.get("temporary_presentation_event_count", 0)) != 0
	):
		_fail("Pending invitation gesture/work contract failed")
		return
	fake_bridge.answer_invitation("reject")
	if not await _wait_for_dialogue_end(dialog_system, 180):
		_fail("Rejected invitation did not end")
		return
	if (
		(npc_system.get_temporary_presentation_event_snapshot().get("events", []) as Array).size() != 1
		or str(npc_system.get_npc_state(TARGET_ID).get("current_action", "")) != TARGET_ACTION_ID
	):
		_fail("Rejected invitation played an invitee gesture or stopped work")
		return

	# Acceptance: ActionSystem stops work, both actors face, then invitee gestures,
	# and only after that does authoritative dialogue state become active.
	if not action_system.assign_npc_dialogue(SPEAKER_ID, TARGET_ID, "这次请停下来谈谈。", 5, false):
		_fail("Could not start acceptance route")
		return
	if not await _wait_for_invitation(dialog_system, fake_bridge, 2400):
		_fail("Speaker did not arrive before acceptance invitation")
		return
	fake_bridge.answer_invitation("accept")
	if not await _wait_for_dialogue_status(dialog_system, "active", 180):
		_fail("Accepted invitation did not activate")
		return
	var accepted_events: Array = npc_system.get_temporary_presentation_event_snapshot().get("events", [])
	if accepted_events.size() != 3:
		_fail("Accepted flow must contain send/send/accept gestures exactly once: %s" % str(accepted_events))
		return
	var accept_event: Dictionary = accepted_events[2]
	var target_art: Dictionary = npc_system.debug_get_npc_character_art_snapshot(TARGET_ID)
	var speaker_position: Vector3 = npc_system.get_npc_world_position(SPEAKER_ID)
	var target_position: Vector3 = npc_system.get_npc_world_position(TARGET_ID)
	var target_expected_facing := speaker_position - target_position
	target_expected_facing.y = 0.0
	target_expected_facing = target_expected_facing.normalized()
	var target_facing: Vector3 = target_art.get("target_facing_direction", Vector3.ZERO)
	if (
		str(accept_event.get("event_kind", "")) != "invitation_accepted"
		or str(accept_event.get("npc_id", "")) != TARGET_ID
		or str(accept_event.get("authority_action_at_emit", "")) != "idle"
		or str(npc_system.get_npc_state(TARGET_ID).get("current_action", "")) != "talk_to_npc"
		or str(target_art.get("temporary_presentation_state", "")) != "talk"
		or int(target_art.get("temporary_presentation_event_count", 0)) != 1
		or target_facing.normalized().dot(target_expected_facing) < 0.99
	):
		_fail("Accepted stop -> face -> gesture -> dialogue ordering failed: %s" % JSON.stringify({
			"accept_event": accept_event,
			"target_state": npc_system.get_npc_state(TARGET_ID),
			"target_art": target_art,
			"target_facing_dot": target_facing.normalized().dot(target_expected_facing)
		}))
		return
	var duplicate_result: Dictionary = npc_system.play_formal_dialogue_presentation_event(
		str(accept_event.get("dialogue_id", "")), TARGET_ID, "invitation_accepted"
	)
	if (
		not bool(duplicate_result.get("ok", false))
		or not bool((duplicate_result.get("event", {}) as Dictionary).get("duplicate", false))
		or (npc_system.get_temporary_presentation_event_snapshot().get("events", []) as Array).size() != 3
	):
		_fail("Temporary presentation event ID did not prevent duplicate playback")
		return

	dialog_system.end_dialogue("verify_t0152_completed")
	print("T0152 formal NPC dialogue gesture verification passed")
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


func _wait_for_dialogue_status(dialog_system: Node, expected_status: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await process_frame
		if str(dialog_system.get_dialogue_state().get("session_status", "")) == expected_status:
			return true
	return false


func _wait_for_dialogue_end(dialog_system: Node, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await process_frame
		if not dialog_system.has_active_dialogue():
			return true
	return false


func _wait_for_action_phase(action_system: Node, npc_id: String, action_id: String, phase: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await physics_frame
		var snapshot: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(snapshot.get("action_id", "")) == action_id and str(snapshot.get("phase", "")) == phase:
			return true
	return false


func _set_move_speed(npc_system: Node, npc_id: String, speed: float) -> void:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	var npc_node := npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))
	if npc_node != null and "move_speed" in npc_node:
		npc_node.move_speed = speed


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
