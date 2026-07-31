extends SceneTree


class FakeInvitationBridge:
	extends Node

	signal dialogue_async_response_received(result: Dictionary)
	signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)

	var invitation_result := "reject"
	var formal_end_round := 1
	var requests: Array[Dictionary] = []
	var judgement_requests: Array[Dictionary] = []

	func request_npc_dialogue_async(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
		var request_id := str(options.get("request_id", "invite_contract_%d" % (requests.size() + 1)))
		var request := {
			"request_id": request_id,
			"npc_id": npc_id,
			"speaker_text": speaker_text,
			"options": options.duplicate(true)
		}
		requests.append(request)
		call_deferred("_emit_response", request)
		return {"ok": true, "pending": true, "request_id": request_id}

	func cancel_npc_llm_requests(_npc_id: String, reason: String = "cancelled") -> Dictionary:
		return {"ok": true, "cancelled": false, "reason": reason}

	func check_health() -> Dictionary:
		return _real_health()

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()

	func request_dialogue_plan_revision_judgement_async(
		npc_id: String,
		options: Dictionary = {}
	) -> Dictionary:
		var request_id := "invite_judgement_%d" % (judgement_requests.size() + 1)
		judgement_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "fake_real_provider",
					"model": "invitation-contract",
					"configured": true,
					"fallback_to_mock": false
				}
			}
		}

	func _emit_response(request: Dictionary) -> void:
		await get_tree().create_timer(0.06).timeout
		var options: Dictionary = request.get("options", {})
		var phase := str(options.get("dialogue_phase", "conversation"))
		var round_index := int(options.get("current_round", 1))
		var rejecting := phase == "invitation" and invitation_result == "reject"
		var ending_formal := phase == "conversation" and round_index >= formal_end_round
		dialogue_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"dialogue": {
				"ok": true,
				"replyer_id": str(request.get("npc_id", "")),
				"reply_text": (
					"我现在不能停下手里的活，这次先不谈。" if rejecting
					else "好，我先听你说。" if phase == "invitation"
					else "我明白了，这一轮说清楚就先结束。"
				),
				"response_kind": "reply_to_npc",
				"invitation_result": invitation_result if phase == "invitation" else "not_applicable",
				"emotion": "neutral",
				"should_end_dialogue": rejecting or ending_formal,
				"suggested_event_type": "dialogue_turn",
				"debug_reason": "invitation_contract_fake",
				"model_provider": "fake_real_provider",
				"model_name": "invitation-contract",
				"model_fallback_used": false
			}
		})


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var systems := root.get_node_or_null("Main/Systems")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var event_bus := root.get_node_or_null("EventBus")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [systems, npc_system, dialog_system, daily_plan_system, memory_system, event_bus, original_bridge].has(null):
		_fail("Invitation contract verification required nodes not found")
		return
	systems.remove_child(original_bridge)
	original_bridge.queue_free()
	await process_frame
	var fake_bridge := FakeInvitationBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)
	fake_bridge.dialogue_async_response_received.connect(Callable(dialog_system, "_on_dialogue_async_response_received"))
	if (
		not daily_plan_system.set_npc_daily_plan("doctor_01", _make_work_plan("work_clinic_doctor"), false, "verify_invitation")
		or not daily_plan_system.set_npc_daily_plan("priest_01", _make_work_plan("work_garden"), false, "verify_invitation")
	):
		_fail("Could not install deterministic plans for invitation judgement verification")
		return

	var ended_states: Array[Dictionary] = []
	var reevaluation_events: Array[Dictionary] = []
	dialog_system.dialogue_ended.connect(func(state: Dictionary) -> void:
		ended_states.append(state.duplicate(true))
	)
	event_bus.npc_plan_reevaluation_requested.connect(func(npc_id: String, reason: String) -> void:
		if npc_id in ["doctor_01", "priest_01"]:
			reevaluation_events.append({"npc_id": npc_id, "reason": reason})
	)

	_prepare_pair(npc_system, "doctor_01", "priest_01")
	npc_system.update_npc_state("priest_01", {
		"current_action": "work_garden",
		"last_action_result": "verify_invitation_target_working"
	})
	var reject_start: Dictionary = dialog_system.start_autonomous_npc_dialogue(
		"doctor_01", "priest_01", "马塞尔，我想和你谈谈眼下的安排。", "local_public", 5, false
	)
	if not bool(reject_start.get("ok", false)) or not bool(reject_start.get("pending", false)):
		_fail("Could not start rejection invitation: %s" % str(reject_start))
		return
	var pending_state: Dictionary = dialog_system.get_dialogue_state()
	var pending_guidance := str(pending_state.get("soft_round_guidance", ""))
	if (
		str(pending_state.get("session_status", "")) != "invitation_pending"
		or int(pending_state.get("current_round", -1)) != 0
		or int(pending_state.get("max_rounds", -1)) != 0
		or int(pending_state.get("soft_round_threshold", 0)) != 5
		or not pending_guidance.contains("不是最低轮数、目标轮数或继续理由")
		or not pending_guidance.contains("不得为了延长对话自行制造新话题")
	):
		_fail("Invitation must be a separate pre-round phase: %s" % str(pending_state))
		return
	var target_pending_state: Dictionary = npc_system.get_npc_state("priest_01")
	if (
		str(target_pending_state.get("current_action", "")) != "work_garden"
		or not str(target_pending_state.get("active_dialogue_id", "")).is_empty()
	):
		_fail("Invitation pending interrupted or locked the target before its decision")
		return
	if not await _wait_for_end(dialog_system, ended_states, 1, 2000):
		_fail("Rejected invitation did not end")
		return
	var rejected_state: Dictionary = ended_states.back()
	if (
		str(rejected_state.get("end_reason", "")) != "autonomous_dialogue_invitation_rejected"
		or str(rejected_state.get("invitation_result", "")) != "reject"
		or int(rejected_state.get("current_round", -1)) != 0
		or (rejected_state.get("history", []) as Array).size() != 2
	):
		_fail("Rejected invitation leaked into formal rounds: %s" % str(rejected_state))
		return
	if not await _wait_for_judgements(fake_bridge, 2, 1000):
		_fail("Rejected invitation did not launch a judgement for both NPCs")
		return
	if not _has_exact_pair_judgements(fake_bridge.judgement_requests):
		_fail("Rejected invitation must let both NPCs independently judge their plans: %s" % str(fake_bridge.judgement_requests))
		return
	if not reevaluation_events.is_empty():
		_fail("Rejected invitation still emitted the old direct reevaluation signal: %s" % str(reevaluation_events))
		return
	var target_rejected_state: Dictionary = npc_system.get_npc_state("priest_01")
	if str(target_rejected_state.get("current_action", "")) != "work_garden":
		_fail("The NPC who rejected the invitation must keep working without reevaluation")
		return

	ended_states.clear()
	reevaluation_events.clear()
	fake_bridge.requests.clear()
	fake_bridge.judgement_requests.clear()
	fake_bridge.invitation_result = "accept"
	fake_bridge.formal_end_round = 1
	_prepare_pair(npc_system, "doctor_01", "priest_01")
	var early_end_start: Dictionary = dialog_system.start_autonomous_npc_dialogue(
		"doctor_01", "priest_01", "我们只用一轮把工位安排说清。", "local_public", 5, false
	)
	if not bool(early_end_start.get("ok", false)):
		_fail("Could not start early-end invitation: %s" % str(early_end_start))
		return
	if not await _wait_for_end(dialog_system, ended_states, 1, 3000):
		_fail("Per-round should_end_dialogue did not end the accepted conversation")
		return
	var early_end_state: Dictionary = ended_states.back()
	if (
		int(early_end_state.get("current_round", 0)) != 1
		or int(early_end_state.get("max_rounds", -1)) != 0
		or (early_end_state.get("history", []) as Array).size() != 3
		or fake_bridge.requests.size() != 2
		or str(early_end_state.get("ending_npc_id", "")) != "doctor_01"
		or str(early_end_state.get("ending_reply_text", "")).is_empty()
		or str(fake_bridge.requests[0].get("options", {}).get("dialogue_phase", "")) != "invitation"
		or str(fake_bridge.requests[1].get("options", {}).get("dialogue_phase", "")) != "conversation"
	):
		_fail("Accepted conversation did not end independently on formal round one: %s" % str(early_end_state))
		return
	var early_history: Array = early_end_state.get("history", [])
	if (
		early_history.is_empty()
		or str((early_history.back() as Dictionary).get("text", "")) != str(early_end_state.get("ending_reply_text", ""))
		or not _has_recorded_end_marker(memory_system.get_all_events(), str(early_end_state.get("ending_reply_text", "")), 1)
	):
		_fail("End-marker reply was not preserved as the final history and event record")
		return
	if not await _wait_for_judgements(fake_bridge, 2, 1000) or not _has_exact_pair_judgements(fake_bridge.judgement_requests):
		_fail("Early formal end must make both participants judge their plans exactly once: %s" % str(fake_bridge.judgement_requests))
		return
	if not reevaluation_events.is_empty():
		_fail("Early formal end still emitted the old direct reevaluation signal")
		return

	ended_states.clear()
	reevaluation_events.clear()
	fake_bridge.requests.clear()
	fake_bridge.judgement_requests.clear()
	fake_bridge.formal_end_round = 7
	_prepare_pair(npc_system, "doctor_01", "priest_01")
	var beyond_soft_start: Dictionary = dialog_system.start_autonomous_npc_dialogue(
		"doctor_01", "priest_01", "有必要把复杂安排继续谈清。", "local_public", 5, false
	)
	if not bool(beyond_soft_start.get("ok", false)):
		_fail("Could not start beyond-soft-threshold conversation: %s" % str(beyond_soft_start))
		return
	if not await _wait_for_end(dialog_system, ended_states, 1, 5000):
		_fail("Conversation could not continue beyond the soft threshold")
		return
	var beyond_soft_state: Dictionary = ended_states.back()
	if (
		int(beyond_soft_state.get("current_round", 0)) != 7
		or int(beyond_soft_state.get("max_rounds", -1)) != 0
		or int(beyond_soft_state.get("soft_round_threshold", 0)) != 5
		or fake_bridge.requests.size() != 8
		or (beyond_soft_state.get("history", []) as Array).size() != 9
	):
		_fail("Soft guidance was incorrectly enforced as a hard round cap: %s" % str(beyond_soft_state))
		return
	if not await _wait_for_judgements(fake_bridge, 2, 1000) or not _has_exact_pair_judgements(fake_bridge.judgement_requests):
		_fail("A conversation ending beyond the soft threshold must make both participants judge their plans")
		return
	if not reevaluation_events.is_empty():
		_fail("Beyond-threshold dialogue still emitted the old direct reevaluation signal")
		return

	main.queue_free()
	await process_frame
	print("T0030 dialogue rejection, soft-round, and unilateral end contract verification passed.")
	quit(0)


func _prepare_pair(npc_system: Node, first_npc_id: String, second_npc_id: String) -> void:
	for npc_id in [first_npc_id, second_npc_id]:
		npc_system.debug_enter_location_immediately(npc_id, "plaza")
		npc_system.update_npc_state(npc_id, {
			"unconscious": false,
			"escaped": false,
			"behavior_mode": "work",
			"current_action": "idle",
			"active_dialogue_id": ""
		})


func _wait_for_end(dialog_system: Node, ended_states: Array[Dictionary], expected_count: int, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while (
		(dialog_system.has_active_dialogue() or ended_states.size() < expected_count)
		and Time.get_ticks_msec() < deadline
	):
		await create_timer(0.01).timeout
	return not dialog_system.has_active_dialogue() and ended_states.size() >= expected_count


func _wait_for_judgements(fake_bridge: Node, expected_count: int, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while fake_bridge.judgement_requests.size() < expected_count and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	return fake_bridge.judgement_requests.size() >= expected_count


func _has_exact_pair_judgements(requests: Array[Dictionary]) -> bool:
	var counts := {"doctor_01": 0, "priest_01": 0}
	for request in requests:
		if counts.has(str(request.get("npc_id", ""))):
			var npc_id := str(request.get("npc_id", ""))
			counts[npc_id] = int(counts[npc_id]) + 1
	return int(counts["doctor_01"]) == 1 and int(counts["priest_01"]) == 1


func _make_work_plan(action_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": action_id,
			"reason": "T0049 invitation judgement verification",
			"source": "verify_invitation"
		})
	return plan


func _has_recorded_end_marker(events: Array, ending_reply_text: String, ending_round: int) -> bool:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("type", "")) != "dialogue_turn":
			continue
		var payload: Dictionary = event.get("payload", {})
		if (
			str(payload.get("dialogue_phase", "")) == "conversation"
			and bool(payload.get("should_end_dialogue", false))
			and int(payload.get("current_round", 0)) == ending_round
		):
			var dialogue_text: Array = payload.get("dialogue_text", [])
			return not dialogue_text.is_empty() and str((dialogue_text.back() as Dictionary).get("text", "")) == ending_reply_text
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
