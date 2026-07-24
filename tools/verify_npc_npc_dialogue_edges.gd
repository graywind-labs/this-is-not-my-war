extends SceneTree


class FakeDialogueBridge:
	extends Node

	signal dialogue_async_response_received(result: Dictionary)

	var requests: Array[Dictionary] = []
	var judgement_requests: Array[Dictionary] = []
	var cancelled_request_ids: Array[String] = []
	var reply_delay_seconds := 0.04

	func request_npc_dialogue_async(npc_id: String, speaker_text: String, options: Dictionary = {}) -> Dictionary:
		var request_index := requests.size() + 1
		var request_id := str(options.get("request_id", "fake_dialogue_%d" % request_index))
		requests.append({
			"npc_id": npc_id,
			"speaker_text": speaker_text,
			"options": options.duplicate(true),
			"request_id": request_id
		})
		call_deferred(
			"_emit_reply",
			request_id,
			request_index,
			npc_id,
			str(options.get("dialogue_phase", "conversation")),
			int(options.get("current_round", 1))
		)
		return {"ok": true, "pending": true, "request_id": request_id}

	func cancel_npc_llm_requests(_npc_id: String, reason: String = "cancelled") -> Dictionary:
		cancelled_request_ids.append(reason)
		return {"ok": true, "cancelled": false, "reason": "no_active_request"}

	func check_health() -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "fake_real_provider",
					"model": "edge-test",
					"configured": true,
					"fallback_to_mock": false,
				}
			}
		}

	func get_cached_health(_max_age_ms: int = 5000) -> Dictionary:
		return check_health()

	func request_plan_revision_judgement_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		var request_id := "fake_plan_judgement_%d" % (judgement_requests.size() + 1)
		judgement_requests.append({
			"npc_id": npc_id,
			"options": options.duplicate(true),
			"request_id": request_id,
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func _emit_reply(request_id: String, request_index: int, npc_id: String, dialogue_phase: String, current_round: int) -> void:
		await get_tree().create_timer(reply_delay_seconds).timeout
		var invitation := dialogue_phase == "invitation"
		var replies := [
			"我听见了，先把手头的活停一下。",
			"可以，我们把诊所工位协调好。",
			"那就这么办。"
		]
		dialogue_async_response_received.emit({
			"ok": true,
			"request_id": request_id,
			"dialogue": {
				"ok": true,
				"replyer_id": npc_id,
				"reply_text": "好，我先听你说。" if invitation else replies[mini(request_index - 1, replies.size() - 1)],
				"response_kind": "reply_to_npc",
				"invitation_result": "accept" if invitation else "not_applicable",
				"intent": "end_talk" if not invitation and current_round >= 3 else "continue_talk",
				"emotion": "neutral",
				"recruitment_result": "none",
				"wartime_reaction": "none",
				"should_end_dialogue": not invitation and current_round >= 3,
				"suggested_event_type": "dialogue_turn",
				"debug_reason": "edge_test_fake",
				"model_provider": "fake_real_provider",
				"model_name": "edge-test",
				"model_fallback_used": false
			}
		})


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var systems := root.get_node_or_null("Main/Systems")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var game_state := root.get_node_or_null("GameState")
	var event_bus := root.get_node_or_null("EventBus")
	if [systems, npc_system, action_system, daily_plan_system, dialog_system, original_bridge, game_state, event_bus].has(null):
		_fail("NPC-NPC dialogue edge verification requires all scene systems")
		return

	systems.remove_child(original_bridge)
	original_bridge.queue_free()
	await process_frame
	var fake_bridge := FakeDialogueBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)
	fake_bridge.dialogue_async_response_received.connect(Callable(dialog_system, "_on_dialogue_async_response_received"))

	var ended_states: Array[Dictionary] = []
	var phase_trace: Array[String] = []
	dialog_system.dialogue_started.connect(func(state: Dictionary) -> void:
		if (
			bool(state.get("autonomous", false))
			and str(state.get("speaker_npc_id", "")) == "stableman_01"
			and str(state.get("target_npc_id", "")) == "doctor_01"
		):
			phase_trace.append("dialogue_started")
	)
	dialog_system.dialogue_ended.connect(func(state: Dictionary) -> void:
		if bool(state.get("autonomous", false)):
			ended_states.append(state.duplicate(true))
	)
	event_bus.npc_state_changed.connect(func(npc_id: String) -> void:
		if (
			npc_id == "doctor_01"
			and str(npc_system.get_npc_state(npc_id).get("current_action", "")) == "work_clinic_doctor"
			and not phase_trace.has("target_work_started")
		):
			phase_trace.append("target_work_started")
	)

	# Regression setup: the initiator is deliberately earlier than its target in the
	# NPC batch order. Both begin in planning_day, which used to let the later target
	# execution immediately force-end a dialogue started by the earlier initiator.
	var npc_order: Array[String] = npc_system.get_npc_ids()
	if npc_order.find("stableman_01") < 0 or npc_order.find("doctor_01") < 0:
		_fail("Required NPCs are missing from batch order")
		return
	if npc_order.find("stableman_01") >= npc_order.find("doctor_01"):
		_fail("Edge test precondition failed: initiator must be before target in NPC order")
		return
	if not npc_system.debug_enter_location_immediately("stableman_01", "clinic"):
		_fail("Could not place dialogue initiator in clinic")
		return
	if not npc_system.debug_enter_location_immediately("doctor_01", "clinic"):
		_fail("Could not place dialogue target in clinic")
		return
	var current_hour := int(root.get_node("GameState").current_hour)
	if not daily_plan_system.set_npc_daily_plan(
		"stableman_01",
		_make_plan(current_hour, "talk_to_npc", "work_stable", {
			"target_id": "doctor_01",
			"target_npc_id": "doctor_01",
			"location_id": "clinic"
		}, "莉娜，我们谈谈诊所工位的安排。"),
		false,
		"verify_batch_dialogue"
	):
		_fail("Could not install initiator dialogue plan")
		return
	if not daily_plan_system.set_npc_daily_plan(
		"doctor_01",
		_make_plan(current_hour, "work_clinic_doctor", "work_clinic_doctor"),
		false,
		"verify_batch_target_work"
	):
		_fail("Could not install target work plan")
		return
	npc_system.update_npc_state("stableman_01", {
		"current_action": "planning_day",
		"last_action_result": "verify_planning_day"
	})
	npc_system.update_npc_state("doctor_01", {
		"current_action": "planning_day",
		"last_action_result": "verify_planning_day"
	})
	if (
		str(npc_system.get_npc_state("stableman_01").get("current_action", "")) != "planning_day"
		or str(npc_system.get_npc_state("doctor_01").get("current_action", "")) != "planning_day"
	):
		_fail("Both participants must begin the batch in planning_day")
		return

	var batch_result: Dictionary = daily_plan_system.execute_current_plan_for_all(true)
	if not bool(batch_result.get("doctor_01", {}).get("ok", false)):
		_fail("Target non-dialogue plan did not execute in the first batch phase: %s" % str(batch_result))
		return
	if not bool(batch_result.get("stableman_01", {}).get("ok", false)):
		_fail("Initiator dialogue plan did not execute in the second batch phase: %s" % str(batch_result))
		return
	if not phase_trace.has("target_work_started") or not phase_trace.has("dialogue_started"):
		_fail("Two-phase batch did not expose both target work and dialogue start: %s" % str(phase_trace))
		return
	if phase_trace.find("target_work_started") >= phase_trace.find("dialogue_started"):
		_fail("Dialogue started before the target's non-dialogue plan landed: %s" % str(phase_trace))
		return
	if not dialog_system.has_active_dialogue():
		_fail("Target's later batch slot immediately killed the newly started dialogue")
		return
	var batch_accept_deadline := Time.get_ticks_msec() + 3000
	while (
		str(dialog_system.get_dialogue_state().get("session_status", "")) != "active"
		and dialog_system.has_active_dialogue()
		and Time.get_ticks_msec() < batch_accept_deadline
	):
		await process_frame
	if (
		str(npc_system.get_npc_state("stableman_01").get("current_action", "")) != "talk_to_npc"
		or str(npc_system.get_npc_state("doctor_01").get("current_action", "")) != "talk_to_npc"
	):
		_fail("Batch dialogue does not own both participant action states")
		return

	if not await _wait_for_dialogue_end(dialog_system, 4000):
		_fail("Batch dialogue did not honor the fake model's round-three end marker")
		return
	if fake_bridge.requests.size() != 4:
		_fail("Expected one invitation plus three replies before the explicit end marker, got %d" % fake_bridge.requests.size())
		return
	for request_index in range(1, 4):
		var request: Dictionary = fake_bridge.requests[request_index]
		var speaker_text := str(request.get("speaker_text", ""))
		var history: Array = request.get("options", {}).get("conversation_history", [])
		if history.is_empty():
			_fail("Continuation request %d unexpectedly lost all earlier history" % (request_index + 1))
			return
		var last_turn: Variant = history.back()
		if last_turn is Dictionary and str((last_turn as Dictionary).get("text", "")) == speaker_text:
			_fail("Continuation request %d duplicated speaker_text as the last history turn" % (request_index + 1))
			return
	if int((fake_bridge.requests[1].get("options", {}) as Dictionary).get("conversation_history", []).size()) != 1:
		_fail("First formal reply should carry opening history only after de-duplicating the acceptance reply")
		return
	if int((fake_bridge.requests[2].get("options", {}) as Dictionary).get("conversation_history", []).size()) != 2:
		_fail("Second formal reply should carry invitation exchange without duplicating speaker_text")
		return
	if int((fake_bridge.requests[3].get("options", {}) as Dictionary).get("conversation_history", []).size()) != 3:
		_fail("Third formal reply should retain invitation history plus the prior distinct reply")
		return

	# A planned talk action may approach a target that is still waiting for its plan
	# response, but it must retain ownership and delay the invitation request until
	# the target's plan activity has fully cleared.
	fake_bridge.reply_delay_seconds = 0.20
	if not _prepare_idle_pair(npc_system, "stableman_01", "engineer_01", "plaza"):
		_fail("Could not prepare plan-wait dialogue pair")
		return
	if not npc_system.set_npc_llm_activity("engineer_01", {
		"active": true,
		"kind": "plan",
		"request_id": "verify_dialogue_target_plan_wait",
		"cancellable": true,
	}):
		_fail("Could not mark autonomous dialogue target as planning")
		return
	var requests_before_plan_wait := fake_bridge.requests.size()
	var wait_start_ok: bool = bool(action_system.assign_npc_dialogue(
		"stableman_01",
		"engineer_01",
		"米拉，等你想清楚后我们谈谈马厩器械。",
		5,
		true
	))
	if not wait_start_ok:
		_fail("Planning target should keep the NPC dialogue action pending")
		return
	var wait_snapshot: Dictionary = action_system.get_runtime_action_snapshot("stableman_01")
	if (
		str(wait_snapshot.get("phase", "")) != "pending"
		or str(wait_snapshot.get("action_id", "")) != "talk_to_npc"
		or not bool((wait_snapshot.get("options", {}) as Dictionary).get("waiting_for_target_plan", false))
	):
		_fail("Pending NPC dialogue did not expose waiting_for_target_plan: %s" % str(wait_snapshot))
		return
	if fake_bridge.requests.size() != requests_before_plan_wait or dialog_system.has_active_dialogue():
		_fail("Planning target started an invitation request before its plan completed")
		return
	if not action_system.is_npc_dialogue_reserved("stableman_01") or not action_system.is_npc_dialogue_reserved("engineer_01"):
		_fail("Plan-wait dialogue did not retain both participant reservations")
		return
	if str(npc_system.get_npc_state("stableman_01").get("last_action_result", "")).contains("failed"):
		_fail("Plan-wait dialogue incorrectly reported immediate action failure")
		return
	if not npc_system.clear_npc_llm_activity("engineer_01", "verify_dialogue_target_plan_wait"):
		_fail("Could not clear autonomous dialogue target planning activity")
		return
	var wait_resume_deadline := Time.get_ticks_msec() + 1000
	while fake_bridge.requests.size() == requests_before_plan_wait and Time.get_ticks_msec() < wait_resume_deadline:
		await process_frame
	if fake_bridge.requests.size() != requests_before_plan_wait + 1 or not dialog_system.has_active_dialogue():
		_fail("Pending NPC dialogue did not start its invitation after target planning cleared")
		return
	if action_system.has_pending_action("stableman_01") or action_system.is_npc_dialogue_reserved("engineer_01"):
		_fail("Resumed NPC dialogue did not release pending ownership after invitation start")
		return
	dialog_system.end_dialogue("verify_plan_wait_cleanup", {"suppress_plan_reevaluation": true})
	await create_timer(0.25).timeout

	# A daily-plan-owned talk that is still waiting for its target's plan must not
	# survive into an hour whose current plan item is no longer the same talk. The
	# old action becomes an authoritative failure and enters the T0050 judgement
	# chain with both the failed and replacement plan items preserved.
	if not _prepare_idle_pair(npc_system, "stableman_01", "engineer_01", "plaza"):
		_fail("Could not prepare cross-hour plan-wait dialogue pair")
		return
	if not npc_system.set_npc_llm_activity("engineer_01", {
		"active": true,
		"kind": "plan",
		"request_id": "verify_cross_hour_target_plan_wait",
		"cancellable": true,
	}):
		_fail("Could not mark cross-hour dialogue target as planning")
		return
	game_state.current_hour = current_hour
	var cross_hour_plan := _make_plan(current_hour, "talk_to_npc", "idle", {
		"target_id": "engineer_01",
		"target_npc_id": "engineer_01",
		"location_id": "plaza",
	}, "米拉，想完以后我们谈谈。")
	if not daily_plan_system.set_npc_daily_plan(
		"stableman_01",
		cross_hour_plan,
		false,
		"verify_cross_hour_plan_wait"
	):
		_fail("Could not install cross-hour dialogue plan")
		return
	var cross_hour_start: Dictionary = daily_plan_system.execute_current_plan_for_npc("stableman_01", true)
	if not bool(cross_hour_start.get("ok", false)):
		_fail("Daily dialogue did not enter cross-hour plan wait: %s" % JSON.stringify(cross_hour_start))
		return
	var cross_hour_snapshot: Dictionary = action_system.get_runtime_action_snapshot("stableman_01")
	var cross_hour_options: Dictionary = cross_hour_snapshot.get("options", {})
	if (
		str(cross_hour_options.get("plan_action_source", "")) != "daily_plan"
		or int(cross_hour_options.get("assigned_plan_hour", -1)) != current_hour
		or not bool(cross_hour_options.get("waiting_for_target_plan", false))
	):
		_fail("Daily dialogue wait lost plan ownership metadata: %s" % JSON.stringify(cross_hour_snapshot))
		return
	var judgement_count_before_expiry := fake_bridge.judgement_requests.size()
	var next_hour := (current_hour + 1) % 24
	var next_day := int(game_state.current_day) + (1 if next_hour == 0 else 0)
	game_state.current_day = next_day
	game_state.current_hour = next_hour
	var expired_npc_ids: Array[String] = action_system.expire_invalid_daily_plan_dialogues(next_day, next_hour)
	if expired_npc_ids != ["stableman_01"]:
		_fail("Cross-hour dialogue wait did not expire exactly once: %s" % JSON.stringify(expired_npc_ids))
		return
	var expired_state: Dictionary = npc_system.get_npc_state("stableman_01")
	var expiry_context: Dictionary = expired_state.get("last_action_failure_context", {})
	if (
		str(expired_state.get("last_action_result", "")) != "talk_to_npc_failed_plan_superseded"
		or str(expiry_context.get("reason", "")) != "daily_plan_item_changed_while_dialogue_pending"
		or not bool(expiry_context.get("waited_across_hour", false))
		or str((expiry_context.get("failed_plan_item", {}) as Dictionary).get("action_id", "")) != "talk_to_npc"
		or str((expiry_context.get("current_plan_item", {}) as Dictionary).get("action_id", "")) != "idle"
	):
		_fail("Cross-hour dialogue failure context is incomplete: %s" % JSON.stringify(expiry_context))
		return
	if (
		action_system.has_pending_action("stableman_01")
		or action_system.is_npc_dialogue_reserved("stableman_01")
		or action_system.is_npc_dialogue_reserved("engineer_01")
	):
		_fail("Cross-hour dialogue expiry retained pending action or participant reservation")
		return
	if fake_bridge.judgement_requests.size() != judgement_count_before_expiry + 1:
		_fail("Cross-hour dialogue expiry did not enter plan revision judgement")
		return
	var expiry_judgement_options: Dictionary = fake_bridge.judgement_requests.back().get("options", {})
	if (
		str(expiry_judgement_options.get("failure_type", "")) != "plan_item_superseded"
		or str((expiry_judgement_options.get("failed_plan_item", {}) as Dictionary).get("action_id", "")) != "talk_to_npc"
		or str((expiry_judgement_options.get("failure_context", {}) as Dictionary).get("current_plan_item", {}).get("action_id", "")) != "idle"
	):
		_fail("Plan revision judgement lost cross-hour failure facts: %s" % JSON.stringify(expiry_judgement_options))
		return
	if not npc_system.clear_npc_llm_activity("engineer_01", "verify_cross_hour_target_plan_wait"):
		_fail("Could not clear cross-hour target planning activity")
		return
	game_state.current_day = 1
	game_state.current_hour = current_hour

	# Godot must independently reject business-invalid model output instead of
	# accepting a backend/client hardcode as a successful NPC turn.
	if not _prepare_idle_pair(npc_system, "doctor_01", "priest_01", "plaza"):
		_fail("Could not prepare dialogue business-validation pair")
		return
	for invalid_case in [
		{"replyer_id": "doctor_01", "response_kind": "reply_to_npc", "expected": "invalid_npc_dialogue_replyer"},
		{"replyer_id": "priest_01", "response_kind": "reply_to_player", "expected": "invalid_npc_dialogue_response_kind"},
	]:
		var invalid_start: Dictionary = dialog_system.start_npc_dialogue(
			"doctor_01", "priest_01", "local_public", 2, {"autonomous": false}
		)
		if not bool(invalid_start.get("ok", false)):
			_fail("Could not start business-validation dialogue: %s" % str(invalid_start))
			return
		var invalid_result: Dictionary = dialog_system.call("_apply_npc_message_response", {
			"ok": true,
			"dialogue": {
				"replyer_id": str(invalid_case.get("replyer_id", "")),
				"reply_text": "这条回复不应被接纳。",
				"response_kind": str(invalid_case.get("response_kind", "")),
				"model_provider": "fake_real_provider",
				"model_fallback_used": false,
			}
		}, {
			"clean_text": "测试业务校验。",
			"next_round": 1,
			"speaker_id": "doctor_01",
			"speaker_name": "莉娜",
			"target_id": "priest_01",
			"target_name": "马塞尔",
			"speaker_text_already_recorded": false,
		})
		if bool(invalid_result.get("ok", true)) or str(invalid_result.get("error_code", "")) != str(invalid_case.get("expected", "")):
			_fail("Godot accepted invalid NPC dialogue output: %s" % str(invalid_result))
			return
		dialog_system.end_dialogue("verify_business_validation_cleanup", {"suppress_plan_reevaluation": true})

	# Opening a player conversation while autonomous NPCs are talking is view-only
	# until the player actually sends or attacks. Merely viewing/closing must neither
	# cancel the pending background LLM call nor release its two participants.
	fake_bridge.reply_delay_seconds = 0.5
	if not _prepare_idle_pair(npc_system, "gardener_01", "priest_01", "plaza"):
		_fail("Could not prepare background dialogue pair for player draft verification")
		return
	if not npc_system.debug_enter_location_immediately("cook_01", "plaza"):
		_fail("Could not prepare player draft target")
		return
	npc_system.update_npc_state("cook_01", {
		"unconscious": false,
		"escaped": false,
		"behavior_mode": "work",
		"current_action": "idle",
		"active_dialogue_id": ""
	})
	var view_background_start: Dictionary = dialog_system.start_autonomous_npc_dialogue(
		"gardener_01", "priest_01", "马塞尔，我们先谈谈菜园的安排。", "local_public", 5, true
	)
	if not bool(view_background_start.get("ok", false)) or not bool(view_background_start.get("pending", false)):
		_fail("Could not start waiting background dialogue: %s" % str(view_background_start))
		return
	var view_background_state: Dictionary = dialog_system.get_dialogue_state()
	var view_background_id := str(view_background_state.get("dialogue_id", ""))
	if (
		view_background_id.is_empty()
		or str(view_background_state.get("dialogue_kind", "")) != "npc_npc"
		or not bool(view_background_state.get("waiting", false))
	):
		_fail("Background dialogue is not an authoritative waiting NPC-NPC session")
		return
	var background_request_count := fake_bridge.requests.size()
	var background_cancel_count := fake_bridge.cancelled_request_ids.size()
	var autonomous_ends_before_draft := ended_states.size()
	var first_draft_result: Dictionary = dialog_system.start_player_dialogue("cook_01")
	if not bool(first_draft_result.get("ok", false)) or not bool(first_draft_result.get("view_only_until_send", false)):
		_fail("Player view did not open as a view-only draft: %s" % str(first_draft_result))
		return
	var first_draft_state: Dictionary = first_draft_result.get("dialogue_state", {})
	var first_draft_id := str(first_draft_state.get("dialogue_id", ""))
	if (
		first_draft_id.is_empty()
		or str(first_draft_state.get("dialogue_kind", "")) != "player_npc"
		or str(first_draft_state.get("target_npc_id", "")) != "cook_01"
	):
		_fail("View-only draft does not describe the selected cook player dialogue")
		return
	if str(dialog_system.get_dialogue_state().get("dialogue_id", "")) != view_background_id:
		_fail("Opening a player draft replaced the authoritative background dialogue")
		return
	if str(dialog_system.get_display_dialogue_state().get("dialogue_id", "")) != first_draft_id:
		_fail("Player draft was not exposed as the displayed dialogue")
		return
	if fake_bridge.requests.size() != background_request_count:
		_fail("Merely opening a player draft launched an unexpected LLM request")
		return
	if fake_bridge.cancelled_request_ids.size() != background_cancel_count:
		_fail("Merely opening a player draft cancelled the background LLM request")
		return
	if ended_states.size() != autonomous_ends_before_draft:
		_fail("Merely opening a player draft ended the autonomous dialogue")
		return
	if not _autonomous_session_ownership_is_consistent(
		dialog_system, npc_system, "gardener_01", "priest_01", view_background_id
	):
		_fail("Merely opening a player draft changed invitation/formal dialogue ownership")
		return

	var close_draft_result: Dictionary = dialog_system.end_displayed_dialogue(first_draft_id)
	if not bool(close_draft_result.get("ok", false)) or not bool(close_draft_result.get("view_only", false)):
		_fail("Could not close the view-only player draft: %s" % str(close_draft_result))
		return
	if (
		str(dialog_system.get_dialogue_state().get("dialogue_id", "")) != view_background_id
		or not dialog_system.has_active_dialogue()
	):
		_fail("Closing the player draft also closed the background dialogue")
		return
	if fake_bridge.cancelled_request_ids.size() != background_cancel_count:
		_fail("Closing the player draft cancelled the background LLM request")
		return
	if not _autonomous_session_ownership_is_consistent(
		dialog_system, npc_system, "gardener_01", "priest_01", view_background_id
	):
		_fail("Closing the player draft changed invitation/formal dialogue ownership")
		return

	# The second draft becomes authoritative only on the first real player message.
	var second_draft_result: Dictionary = dialog_system.start_player_dialogue("cook_01")
	if not bool(second_draft_result.get("ok", false)) or not bool(second_draft_result.get("view_only_until_send", false)):
		_fail("Could not reopen view-only player draft: %s" % str(second_draft_result))
		return
	var second_draft_id := str(second_draft_result.get("dialogue_state", {}).get("dialogue_id", ""))
	var send_result: Dictionary = dialog_system.send_player_message("布鲁诺，我现在正式和你谈。", false, true)
	if not bool(send_result.get("ok", false)) or not bool(send_result.get("pending", false)):
		_fail("Sending from the draft did not start an authoritative player request: %s" % str(send_result))
		return
	var promoted_state: Dictionary = dialog_system.get_dialogue_state()
	if (
		str(promoted_state.get("dialogue_id", "")) != second_draft_id
		or str(promoted_state.get("dialogue_kind", "")) != "player_npc"
		or str(promoted_state.get("target_npc_id", "")) != "cook_01"
		or not bool(promoted_state.get("waiting", false))
	):
		_fail("Sending did not promote the displayed draft to authoritative player_npc state")
		return
	if ended_states.size() != autonomous_ends_before_draft + 1:
		_fail("Sending from the draft did not end exactly one autonomous background session")
		return
	var send_ended_background: Dictionary = ended_states.back()
	if (
		str(send_ended_background.get("dialogue_id", "")) != view_background_id
		or str(send_ended_background.get("end_reason", "")) != "player_message_sent"
	):
		_fail("Background dialogue ended with wrong provenance on draft promotion: %s" % str(send_ended_background))
		return
	if (
		str(npc_system.get_npc_state("gardener_01").get("current_action", "")) != "idle"
		or str(npc_system.get_npc_state("priest_01").get("current_action", "")) != "idle"
	):
		_fail("Promoting the player draft did not release the former background participants")
		return
	if fake_bridge.cancelled_request_ids.size() <= background_cancel_count:
		_fail("Promoting the player draft did not cancel the old background request")
		return
	dialog_system.end_displayed_dialogue(second_draft_id)

	# Attack is the other authoritative promotion trigger and must obey the same
	# boundary: opening remains view-only, while committing damage ends background.
	if not _prepare_idle_pair(npc_system, "blacksmith_01", "engineer_01", "plaza"):
		_fail("Could not prepare attack-promotion background pair")
		return
	var attack_background_start: Dictionary = dialog_system.start_autonomous_npc_dialogue(
		"blacksmith_01", "engineer_01", "欧文，我们对一下器械尺寸。", "local_public", 5, true
	)
	if not bool(attack_background_start.get("ok", false)):
		_fail("Could not start background dialogue for attack promotion: %s" % str(attack_background_start))
		return
	var attack_background_id := str(dialog_system.get_dialogue_state().get("dialogue_id", ""))
	var attack_ends_before := ended_states.size()
	var attack_draft_result: Dictionary = dialog_system.start_player_dialogue("cook_01")
	if not bool(attack_draft_result.get("view_only_until_send", false)):
		_fail("Attack path did not begin as a view-only player draft")
		return
	var attack_draft_id := str(attack_draft_result.get("dialogue_state", {}).get("dialogue_id", ""))
	if str(dialog_system.get_dialogue_state().get("dialogue_id", "")) != attack_background_id:
		_fail("Opening attack draft prematurely ended the background dialogue")
		return
	var cook_hp_before := int(npc_system.get_npc_state("cook_01").get("hp", 0))
	var attack_result: Dictionary = dialog_system.attack_target_npc(1, true)
	if not bool(attack_result.get("ok", false)) or not bool(attack_result.get("pending", false)):
		_fail("Attacking from the draft did not promote and send an authoritative request: %s" % str(attack_result))
		return
	var attack_promoted_state: Dictionary = dialog_system.get_dialogue_state()
	if (
		str(attack_promoted_state.get("dialogue_id", "")) != attack_draft_id
		or str(attack_promoted_state.get("dialogue_kind", "")) != "player_npc"
		or str(attack_promoted_state.get("target_npc_id", "")) != "cook_01"
	):
		_fail("Attack did not promote the draft to authoritative player_npc state")
		return
	if ended_states.size() != attack_ends_before + 1:
		_fail("Attack promotion did not end exactly one autonomous background session")
		return
	var attack_ended_background: Dictionary = ended_states.back()
	if (
		str(attack_ended_background.get("dialogue_id", "")) != attack_background_id
		or str(attack_ended_background.get("end_reason", "")) != "player_attack"
	):
		_fail("Background dialogue ended with wrong provenance on attack promotion: %s" % str(attack_ended_background))
		return
	if int(npc_system.get_npc_state("cook_01").get("hp", 0)) != cook_hp_before - 1:
		_fail("Draft attack did not apply exactly one point of authoritative damage")
		return
	dialog_system.end_displayed_dialogue(attack_draft_id)

	# A participant becoming unconscious is authoritative. The dialogue must end on
	# the state signal, clear its session lock, and preserve the unconscious action.
	fake_bridge.reply_delay_seconds = 0.2
	if not _prepare_idle_pair(npc_system, "cook_01", "priest_01", "plaza"):
		_fail("Could not prepare unconscious interruption pair")
		return
	var ended_before := ended_states.size()
	var unconscious_start: Dictionary = dialog_system.start_autonomous_npc_dialogue(
		"cook_01", "priest_01", "马塞尔，我想和你谈谈。", "local_public", 5, true
	)
	if not bool(unconscious_start.get("ok", false)):
		_fail("Could not start unconscious interruption dialogue: %s" % str(unconscious_start))
		return
	npc_system.update_npc_state("priest_01", {
		"unconscious": true,
		"hp": 0,
		"current_action": "unconscious",
		"last_action_result": "verify_authoritative_unconscious"
	})
	if not await _wait_for_new_end(dialog_system, ended_states, ended_before, 1000):
		_fail("Autonomous dialogue did not end when target became unconscious")
		return
	var unconscious_state: Dictionary = npc_system.get_npc_state("priest_01")
	if str(unconscious_state.get("current_action", "")) != "unconscious":
		_fail("Dialogue restore overwrote authoritative unconscious action with idle")
		return
	if not str(unconscious_state.get("active_dialogue_id", "")).is_empty():
		_fail("Unconscious participant retained stale active_dialogue_id")
		return
	if str(ended_states.back().get("end_reason", "")) != "autonomous_dialogue_participant_unavailable":
		_fail("Unconscious interruption ended with the wrong reason: %s" % str(ended_states.back()))
		return

	# Moving a participant away while another system owns a non-dialogue action is
	# also authoritative; cleanup may release the session id but must not force idle.
	npc_system.update_npc_state("priest_01", {
		"unconscious": false,
		"hp": 50,
		"current_action": "idle",
		"last_action_result": "verify_recovered"
	})
	if not _prepare_idle_pair(npc_system, "cook_01", "priest_01", "plaza"):
		_fail("Could not prepare moved-participant interruption pair")
		return
	ended_before = ended_states.size()
	var moved_start: Dictionary = dialog_system.start_autonomous_npc_dialogue(
		"cook_01", "priest_01", "我们再确认一下安排。", "local_public", 5, true
	)
	if not bool(moved_start.get("ok", false)):
		_fail("Could not start moved-participant dialogue: %s" % str(moved_start))
		return
	npc_system.update_npc_state("priest_01", {
		"current_location": "garden",
		"current_location_name": "菜园",
		"current_action": "work_garden",
		"last_action_result": "verify_authoritative_reassignment"
	})
	if not await _wait_for_new_end(dialog_system, ended_states, ended_before, 1000):
		_fail("Autonomous dialogue did not end when target moved and changed action")
		return
	var moved_state: Dictionary = npc_system.get_npc_state("priest_01")
	if str(moved_state.get("current_action", "")) != "work_garden":
		_fail("Dialogue restore overwrote authoritative non-dialogue action with idle")
		return
	if str(moved_state.get("current_location", "")) != "garden":
		_fail("Dialogue cleanup overwrote the participant's authoritative location")
		return
	if not str(moved_state.get("active_dialogue_id", "")).is_empty():
		_fail("Moved participant retained stale active_dialogue_id")
		return
	if str(ended_states.back().get("end_reason", "")) != "autonomous_dialogue_participant_unavailable":
		_fail("Moved participant interruption ended with the wrong reason: %s" % str(ended_states.back()))
		return

	dialog_system.end_dialogue("verify_npc_npc_edges_cleanup", {
		"suppress_plan_reevaluation": true,
	})
	# Cancelled fake requests still own their short SceneTreeTimer until the fake
	# transport delay expires. Drain them so test shutdown is leak-free.
	await create_timer(0.60).timeout
	main.queue_free()
	await process_frame
	print("T0025 NPC-NPC dialogue edge verification passed.")
	quit(0)


func _make_plan(
	current_hour: int,
	current_action_id: String,
	default_action_id: String,
	target: Dictionary = {},
	dialogue_goal: String = ""
) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": current_action_id if hour == current_hour else default_action_id,
			"reason": "T0025 edge verification",
			"dialogue_goal": dialogue_goal if hour == current_hour else "",
			"priority": 85 if hour == current_hour else 50,
			"target": target.duplicate(true) if hour == current_hour else {}
		})
	return plan


func _prepare_idle_pair(npc_system: Node, speaker_id: String, target_id: String, location_id: String) -> bool:
	if not npc_system.debug_enter_location_immediately(speaker_id, location_id):
		return false
	if not npc_system.debug_enter_location_immediately(target_id, location_id):
		return false
	npc_system.update_npc_state(speaker_id, {
		"unconscious": false,
		"escaped": false,
		"behavior_mode": "work",
		"current_action": "idle",
		"active_dialogue_id": ""
	})
	npc_system.update_npc_state(target_id, {
		"unconscious": false,
		"escaped": false,
		"behavior_mode": "work",
		"current_action": "idle",
		"active_dialogue_id": ""
	})
	return true


func _pair_owned_by_dialogue(
	npc_system: Node,
	speaker_id: String,
	target_id: String,
	dialogue_id: String
) -> bool:
	for npc_id in [speaker_id, target_id]:
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if (
			str(state.get("current_action", "")) != "talk_to_npc"
			or str(state.get("active_dialogue_id", "")) != dialogue_id
		):
			return false
	return true


func _autonomous_session_ownership_is_consistent(
	dialog_system: Node,
	npc_system: Node,
	first_npc_id: String,
	second_npc_id: String,
	dialogue_id: String
) -> bool:
	var state: Dictionary = dialog_system.get_dialogue_state()
	if str(state.get("dialogue_id", "")) != dialogue_id:
		return false
	if str(state.get("session_status", "")) == "invitation_pending":
		for npc_id in [first_npc_id, second_npc_id]:
			if not str(npc_system.get_npc_state(npc_id).get("active_dialogue_id", "")).is_empty():
				return false
		return true
	return _pair_owned_by_dialogue(npc_system, first_npc_id, second_npc_id, dialogue_id)


func _wait_for_dialogue_end(dialog_system: Node, timeout_msec: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while dialog_system.has_active_dialogue() and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	return not dialog_system.has_active_dialogue()


func _wait_for_new_end(
	dialog_system: Node,
	ended_states: Array[Dictionary],
	previous_count: int,
	timeout_msec: int
) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while (
		(dialog_system.has_active_dialogue() or ended_states.size() <= previous_count)
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	return not dialog_system.has_active_dialogue() and ended_states.size() > previous_count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
