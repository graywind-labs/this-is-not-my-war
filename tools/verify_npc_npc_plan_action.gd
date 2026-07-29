extends SceneTree


class FakeDialogueBridge:
	extends Node

	signal dialogue_async_response_received(result: Dictionary)
	signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)
	signal plan_revision_async_response_received(result: Dictionary)

	var request_count := 0
	var cancelled_request_ids: Array[String] = []
	var judgement_requests: Array[Dictionary] = []
	var revision_requests: Array[Dictionary] = []

	func request_npc_dialogue_async(npc_id: String, _speaker_text: String, options: Dictionary = {}) -> Dictionary:
		request_count += 1
		var request_id := str(options.get("request_id", "fake_dialogue_%d" % request_count))
		call_deferred(
			"_emit_reply",
			request_id,
			request_count,
			npc_id,
			str(options.get("dialogue_phase", "conversation")),
			int(options.get("current_round", 1))
		)
		return {"ok": true, "pending": true, "request_id": request_id}

	func cancel_npc_llm_requests(_npc_id: String, reason: String = "cancelled") -> Dictionary:
		cancelled_request_ids.append(reason)
		return {"ok": true, "cancelled": false, "reason": "no_active_request"}

	func check_health() -> Dictionary:
		return _real_health()

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()

	func request_dialogue_plan_revision_judgement_async(
		npc_id: String,
		options: Dictionary = {}
	) -> Dictionary:
		var request_id := "npc_npc_judgement_%d" % (judgement_requests.size() + 1)
		judgement_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func answer_judgement_unchanged(request: Dictionary) -> void:
		var required_hours: Array = (
			request.get("options", {}).get("required_revision_hours", []) as Array
		)
		dialogue_plan_revision_judgement_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"dialogue_plan_revision_judgement": {
				"npc_id": str(request.get("npc_id", "")),
				"needs_revision": not required_hours.is_empty(),
				"revision_hours": required_hours.duplicate(),
				"summary": "hour-boundary plan remains valid",
				"model_provider": "fake_real_provider",
				"model_name": "functional-test",
				"model_fallback_used": false
			}
		})

	func request_npc_plan_revision_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		var request_id := "npc_npc_revision_%d" % (revision_requests.size() + 1)
		var request := {
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		}
		revision_requests.append(request)
		call_deferred("_answer_revision", request)
		return {"ok": true, "pending": true, "request_id": request_id}

	func _answer_revision(request: Dictionary) -> void:
		var options: Dictionary = request.get("options", {})
		var revised_items: Array = []
		var immediate_action: Variant = null
		var requested_hours: Array = options.get("revision_hours", [])
		var current_hour := int(options.get(
			"request_hour",
			requested_hours[0] if not requested_hours.is_empty() else -1
		))
		for raw_hour in options.get("revision_hours", []):
			var hour := int(raw_hour)
			var item := {
				"hour": hour,
				"action_kind": "visit",
				"action_id": "visit_location",
				"location_id": "plaza",
				"target_id": null,
				"priority": 60,
				"reason": "对话后去广场继续安排",
				"dialogue_goal": ""
			}
			revised_items.append(item)
			if hour == current_hour:
				immediate_action = item.duplicate(true)
		plan_revision_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision": {
				"npc_id": str(request.get("npc_id", "")),
				"revised_plan": revised_items,
				"immediate_action": immediate_action,
				"summary": "对话发起者已安排当前后续活动。",
				"model_provider": "fake_real_provider",
				"model_name": "functional-test",
				"model_fallback_used": false
			}
		})

	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "fake_real_provider",
					"model": "functional-test",
					"configured": true,
					"fallback_to_mock": false
				}
			}
		}

	func _emit_reply(request_id: String, request_index: int, npc_id: String, dialogue_phase: String, round_index: int) -> void:
		await get_tree().create_timer(0.03).timeout
		var invitation := dialogue_phase == "invitation"
		var replies := [
			"可以，我们把诊所工位协调好。",
			"我需要先完成这一轮检查。",
			"那就这么办，之后再换回来。"
		]
		dialogue_async_response_received.emit({
			"ok": true,
			"request_id": request_id,
			"dialogue": {
				"ok": true,
				"replyer_id": npc_id,
				"reply_text": "好，我接受邀请，先听你说。" if invitation else replies[mini(round_index - 1, replies.size() - 1)],
				"response_kind": "reply_to_npc",
				"invitation_result": "accept" if invitation else "not_applicable",
				"emotion": "neutral",
				"should_end_dialogue": not invitation and round_index >= 3,
				"suggested_event_type": "dialogue_turn",
				"debug_reason": "functional_fake",
				"model_provider": "fake_real_provider",
				"model_name": "functional-test",
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
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	var original_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [systems, npc_system, action_system, building_system, memory_system, daily_plan_system, dialog_system, time_system, dialog_panel, original_bridge].has(null):
		_fail("NPC-NPC plan verification requires all scene systems")
		return
	time_system.set_time_scale(0.0)

	var started_state := {}
	var ended_state := {}
	var reevaluation_counts := {"doctor_01": 0, "priest_01": 0}
	dialog_system.dialogue_started.connect(func(state: Dictionary) -> void:
		if bool(state.get("autonomous", false)):
			started_state.assign(state.duplicate(true))
	)
	dialog_system.dialogue_ended.connect(func(state: Dictionary) -> void:
		if bool(state.get("autonomous", false)):
			ended_state.assign(state.duplicate(true))
	)
	var event_bus := root.get_node_or_null("EventBus")
	event_bus.npc_plan_reevaluation_requested.connect(func(npc_id: String, reason: String) -> void:
		if reevaluation_counts.has(npc_id) and reason in ["dialogue_completed", "dialogue_interrupted"]:
			reevaluation_counts[npc_id] = int(reevaluation_counts[npc_id]) + 1
	)

	# Main starts its real-provider day-plan batch immediately. Cancel and detach it
	# before arranging deterministic workstation state, otherwise an in-flight reply
	# can replace the debug action between assignment and assertion.
	daily_plan_system.set_auto_execution_enabled(false)
	for raw_npc_id in npc_system.get_npc_ids():
		original_bridge.cancel_npc_llm_requests(str(raw_npc_id), "verify_npc_npc_isolation")
	daily_plan_system.set("_async_plan_queue", [])
	daily_plan_system.set("_async_plan_requests", {})
	systems.remove_child(original_bridge)
	original_bridge.name = "PayloadLLMBridge"
	main.add_child(original_bridge)
	var fake_bridge := FakeDialogueBridge.new()
	fake_bridge.name = "LLMBridge"
	systems.add_child(fake_bridge)
	fake_bridge.dialogue_async_response_received.connect(Callable(dialog_system, "_on_dialogue_async_response_received"))
	fake_bridge.dialogue_plan_revision_judgement_async_response_received.connect(
		Callable(daily_plan_system, "_on_dialogue_plan_revision_judgement_async_response")
	)
	fake_bridge.plan_revision_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_async_response")
	)

	if not npc_system.debug_enter_location_immediately("priest_01", "clinic"):
		_fail("Could not place workstation blocker in clinic")
		return
	if not action_system.debug_assign_action("priest_01", "work_clinic_doctor"):
		_fail("Could not make priest occupy the clinic doctor workstation")
		return
	if not _workstation_owned_by(building_system.get_building("clinic"), "priest_01"):
		_fail("Clinic workstation setup did not take effect")
		return
	if not npc_system.debug_enter_location_immediately("doctor_01", "clinic"):
		_fail("Could not place doctor in clinic for workstation failure verification")
		return
	if action_system.debug_assign_action("doctor_01", "work_clinic_doctor"):
		_fail("Doctor unexpectedly acquired Marcel's occupied clinic workstation")
		return
	var failure_context: Dictionary = npc_system.get_npc_state("doctor_01").get(
		"last_action_failure_context",
		{}
	)
	if not failure_context.get("blocked_by_npc_ids", []).has("priest_01"):
		_fail("Workstation failure did not preserve the blocking NPC id")
		return
	var blocker_names: Array[String] = []
	for raw_blocker in failure_context.get("blocked_by_npcs", []):
		if raw_blocker is Dictionary:
			blocker_names.append(str((raw_blocker as Dictionary).get("name", "")))
	if not blocker_names.has("马塞尔"):
		_fail("Workstation failure did not preserve Marcel's display name")
		return
	var revision_payload: Dictionary = original_bridge.build_npc_plan_revision_payload("doctor_01", {
		"current_plan": _make_dialogue_plan(int(root.get_node("GameState").current_hour)),
		"failed_plan_item": {
			"hour": int(root.get_node("GameState").current_hour),
			"action_id": "work_clinic_doctor",
			"reason": "在诊所工作",
			"target": {},
		},
		"failure_type": "workstation_occupied",
		"failure_summary": "诊所工位被马塞尔占用。",
		"failure_context": failure_context,
		"requires_time_slowdown": true,
	})
	if not _payload_has_targeted_action(revision_payload, "talk_to_npc", "priest_01"):
		_fail("Revision payload did not offer talking to the named workstation blocker")
		return
	var clinic_state: Dictionary = revision_payload.get("current_building_states", {}).get("clinic", {})
	if not _payload_workstation_owned_by(clinic_state, "priest_01"):
		_fail("Revision payload did not expose Marcel as the live clinic workstation occupant")
		return
	if not bool(revision_payload.get("meta", {}).get("requires_time_slowdown", false)):
		_fail("Failure-triggered plan revision payload must request time slowdown")
		return

	original_bridge.queue_free()
	await process_frame

	if not npc_system.debug_enter_location_immediately("doctor_01", "plaza"):
		_fail("Could not place doctor in plaza")
		return
	_set_debug_move_speed("doctor_01", 250.0)

	var current_hour := int(root.get_node("GameState").current_hour)
	var plan := _make_dialogue_plan(current_hour)
	if not daily_plan_system.set_npc_daily_plan("doctor_01", plan, false, "verify_plan"):
		_fail("Could not install targeted NPC dialogue plan")
		return
	if not daily_plan_system.set_npc_daily_plan("priest_01", _make_work_plan("work_garden"), false, "verify_plan"):
		_fail("Could not install target NPC plan for independent dialogue judgement")
		return
	var revision_context := {
		"npc_id": "doctor_01",
		"request_day": int(root.get_node("GameState").current_day),
		"request_hour": current_hour,
		"plan_version": int(daily_plan_system.call("_get_plan_version", "doctor_01")),
		"dialogue_epoch": int(dialog_system.get_npc_dialogue_epoch("doctor_01"))
	}
	if not bool(daily_plan_system.call("_is_revision_context_current", revision_context)):
		_fail("Fresh plan-revision context was incorrectly considered stale")
		return
	if not daily_plan_system.set_npc_daily_plan("doctor_01", plan, false, "verify_plan_version_change"):
		_fail("Could not replace plan for revision version guard verification")
		return
	if bool(daily_plan_system.call("_is_revision_context_current", revision_context)):
		_fail("A delayed revision could still overwrite a newer plan version")
		return
	revision_context["plan_version"] = int(daily_plan_system.call("_get_plan_version", "doctor_01"))
	revision_context["request_hour"] = (current_hour + 1) % 24
	if bool(daily_plan_system.call("_is_revision_context_current", revision_context)):
		_fail("A delayed revision from another hour was not considered stale")
		return
	daily_plan_system.set_auto_execution_enabled(true)
	daily_plan_system.set("_reevaluating_npcs", {"doctor_01": "verify_inflight_revision"})
	npc_system.update_npc_state("doctor_01", {
		"current_action": "idle",
		"last_action_result": "work_failed_no_resources"
	})
	await process_frame
	var queued_reevaluations: Dictionary = daily_plan_system.get("_queued_reevaluation_by_npc")
	if not queued_reevaluations.has("doctor_01"):
		_fail("A new action failure was lost while an older plan revision was in flight")
		return
	daily_plan_system.set("_reevaluating_npcs", {})
	daily_plan_system.call("_drain_queued_reevaluation", "doctor_01")
	await process_frame
	if (daily_plan_system.get("_queued_reevaluation_by_npc") as Dictionary).has("doctor_01"):
		_fail("Queued plan reevaluation was not drained after the old request ended")
		return
	var execute_result: Dictionary = daily_plan_system.execute_current_plan_for_npc("doctor_01", true)
	if not bool(execute_result.get("ok", false)):
		_fail("Dialogue plan was not accepted for execution: %s" % str(execute_result))
		return

	var start_deadline := Time.get_ticks_msec() + 3000
	while started_state.is_empty() and Time.get_ticks_msec() < start_deadline:
		await process_frame
		await physics_frame
	if started_state.is_empty():
		_fail("Doctor never reached priest and started the planned dialogue")
		return
	if str(started_state.get("speaker_npc_id", "")) != "doctor_01" or str(started_state.get("target_npc_id", "")) != "priest_01":
		_fail("Autonomous dialogue participants do not match the plan target")
		return
	if bool(started_state.get("ui_visible", true)) or dialog_panel.visible:
		_fail("Autonomous NPC dialogue must not steal focus with the player DialogPanel")
		return
	if (
		str(started_state.get("session_status", "")) != "invitation_pending"
		or int(started_state.get("max_rounds", -1)) != 0
		or int(started_state.get("soft_round_threshold", 0)) != 5
	):
		_fail("Autonomous dialogue did not begin with a separate invitation and soft-round contract")
		return
	if not _workstation_owned_by(building_system.get_building("clinic"), "priest_01"):
		_fail("Invitation pending incorrectly released the target workstation before acceptance")
		return
	if str(npc_system.get_npc_state("priest_01").get("current_action", "")) != "work_clinic_doctor":
		_fail("Invitation pending interrupted the target's current work before acceptance")
		return
	var accept_deadline := Time.get_ticks_msec() + 3000
	while (
		str(dialog_system.get_dialogue_state().get("session_status", "")) != "active"
		and dialog_system.has_active_dialogue()
		and Time.get_ticks_msec() < accept_deadline
	):
		await process_frame
	if str(dialog_system.get_dialogue_state().get("session_status", "")) != "active":
		_fail("Accepted invitation did not activate the formal NPC dialogue")
		return
	if _workstation_owned_by(building_system.get_building("clinic"), "priest_01"):
		_fail("Accepted NPC dialogue did not interrupt work and release the occupied workstation")
		return
	if str(npc_system.get_npc_state("doctor_01").get("current_action", "")) != "talk_to_npc":
		_fail("Dialogue initiator is not visibly owned by the talk_to_npc session")
		return
	if str(npc_system.get_npc_state("priest_01").get("current_action", "")) != "talk_to_npc":
		_fail("Dialogue target is not visibly owned by the talk_to_npc session")
		return

	var end_deadline := Time.get_ticks_msec() + 5000
	while ended_state.is_empty() and Time.get_ticks_msec() < end_deadline:
		await create_timer(0.01).timeout
	if ended_state.is_empty():
		_fail("Autonomous NPC dialogue did not honor the model's end marker")
		return
	if fake_bridge.request_count != 4 or int(ended_state.get("current_round", 0)) != 3:
		_fail("The fake model's round-three end marker must stop before another LLM request")
		return
	var history: Array = ended_state.get("history", [])
	if history.size() != 5:
		_fail("Invitation history must remain outside formal rounds; expected opening + decision + 3 replies, got %d" % history.size())
		return
	for index in range(1, history.size()):
		if str(history[index - 1].get("text", "")) == str(history[index].get("text", "")):
			_fail("Automatic continuation duplicated an adjacent utterance")
			return
	if str(npc_system.get_npc_state("doctor_01").get("current_action", "")) != "idle" or str(npc_system.get_npc_state("priest_01").get("current_action", "")) != "idle":
		_fail("Dialogue completion did not release both participant action states")
		return
	var judgement_deadline := Time.get_ticks_msec() + 1000
	while fake_bridge.judgement_requests.size() < 2 and Time.get_ticks_msec() < judgement_deadline:
		await create_timer(0.01).timeout
	if not _has_exact_pair_judgements(fake_bridge.judgement_requests):
		_fail("Dialogue completion must request one independent judgement for each participant: %s" % str(fake_bridge.judgement_requests))
		return
	for request in fake_bridge.judgement_requests:
		var required_hours: Array = request.get("options", {}).get("required_revision_hours", [])
		if str(request.get("npc_id", "")) == "doctor_01" and required_hours != [current_hour]:
			_fail("Autonomous dialogue initiator did not require a current-hour revision: %s" % str(request))
			return
		if str(request.get("npc_id", "")) == "priest_01" and not required_hours.is_empty():
			_fail("Dialogue target was incorrectly forced to revise the current hour: %s" % str(request))
			return
	if int(reevaluation_counts["doctor_01"]) != 0 or int(reevaluation_counts["priest_01"]) != 0:
		_fail("Dialogue completion still emitted the old direct reevaluation signal: %s" % str(reevaluation_counts))
		return
	if _count_events(memory_system.get_npc_daily_events("doctor_01"), "dialogue_turn") != 4:
		_fail("Dialogue initiator did not receive one invitation event plus three formal reply events")
		return
	if _count_events(memory_system.get_npc_daily_events("priest_01"), "dialogue_turn") != 4:
		_fail("Dialogue target did not receive one invitation event plus three formal reply events")
		return
	for request in fake_bridge.judgement_requests:
		var judgement_options: Dictionary = request.get("options", {})
		if (judgement_options.get("dialogue_history", []) as Array).size() != history.size():
			_fail("Concurrent NPC judgement lost the completed dialogue history: %s" % str(request))
			return
	# Resolve this first dialogue's pair before starting another chain. Leaving old
	# requests in flight would correctly block every later deferred dispatch for the
	# same NPCs and make the boundary-barrier case test the wrong condition.
	for request in fake_bridge.judgement_requests.duplicate(true):
		fake_bridge.answer_judgement_unchanged(request)
	for _index in range(3):
		await process_frame
	for participant_id in ["doctor_01", "priest_01"]:
		if not str(action_system.get_runtime_action_id(participant_id)).is_empty():
			action_system.interrupt_npc_action(participant_id, "verify_first_judgement_cleanup")

	# An empty autonomous session has no actual exchange, so an hour boundary must not
	# fabricate a judgement for it.
	var hour_boundary_start: Dictionary = dialog_system.start_npc_dialogue(
		"doctor_01",
		"priest_01",
		"local_public",
		2,
		{"autonomous": true, "ui_visible": false, "replace_existing": false}
	)
	if not bool(hour_boundary_start.get("ok", false)):
		_fail("Could not set up hour-boundary autonomous dialogue")
		return
	var reevaluations_before_hour_boundary := reevaluation_counts.duplicate(true)
	var judgements_before_hour_boundary := fake_bridge.judgement_requests.size()
	var hour_boundary_result: Dictionary = dialog_system.end_autonomous_dialogue_for_hour_change()
	if not bool(hour_boundary_result.get("ended", false)) or dialog_system.has_active_dialogue():
		_fail("Hour boundary did not end the previous autonomous NPC dialogue")
		return
	if reevaluation_counts != reevaluations_before_hour_boundary:
		_fail("Hour-boundary dialogue cleanup launched redundant plan revisions")
		return
	if fake_bridge.judgement_requests.size() != judgements_before_hour_boundary:
		_fail("Hour-boundary cleanup fabricated a judgement without dialogue content")
		return

	# Once two actual lines exist, an ordinary hour boundary must preserve the
	# conversation. Judgement and new-hour dispatch happen only after it naturally ends.
	var game_state := root.get_node("GameState")
	var boundary_old_hour := current_hour
	var boundary_new_hour := (boundary_old_hour + 1) % 24
	for participant_id in ["doctor_01", "priest_01"]:
		npc_system.set_npc_behavior_mode(participant_id, "work", "verify_hour_boundary_exchange", {
			"interrupt": false,
			"state_changes": {"current_action": "idle"}
		})
		if not npc_system.debug_enter_location_immediately(participant_id, "chapel"):
			_fail("Could not place %s for hour-boundary exchange" % participant_id)
			return
		if not daily_plan_system.set_npc_daily_plan(
			participant_id,
			_make_hour_boundary_plan(boundary_old_hour, boundary_new_hour),
			false,
			"verify_hour_boundary_exchange"
		):
			_fail("Could not install an interruptible hour-boundary plan for %s" % participant_id)
			return
		var prayer_start: Dictionary = daily_plan_system.execute_current_plan_for_npc(participant_id, true)
		if not bool(prayer_start.get("ok", false)):
			_fail("Could not start old-hour action for %s: %s" % [participant_id, str(prayer_start)])
			return
	var actual_boundary_start: Dictionary = dialog_system.start_npc_dialogue(
		"doctor_01",
		"priest_01",
		"local_public",
		2,
		{
			"autonomous": true,
			"ui_visible": false,
			"replace_existing": false,
			"plan_action_source": "daily_plan",
			"assigned_plan_day": int(game_state.current_day),
			"assigned_plan_hour": boundary_old_hour,
			"assigned_plan_version": int(daily_plan_system.get_plan_version("doctor_01"))
		}
	)
	if not bool(actual_boundary_start.get("ok", false)):
		_fail("Could not set up actual hour-boundary dialogue")
		return
	var actual_boundary_state: Dictionary = dialog_system.get("_active_dialogue")
	actual_boundary_state["history"] = [
		{"speaker_id": "doctor_01", "speaker_name": "莉娜", "listener_id": "priest_01", "listener_name": "马塞尔", "text": "换班前把这件事说清。"},
		{"speaker_id": "priest_01", "speaker_name": "马塞尔", "listener_id": "doctor_01", "listener_name": "莉娜", "text": "好，新时段再按结论安排。"}
	]
	actual_boundary_state["current_round"] = 1
	dialog_system.set("_active_dialogue", actual_boundary_state)
	var actual_boundary_request_start := fake_bridge.judgement_requests.size()
	time_system.set_current_time(
		int(game_state.current_day),
		boundary_new_hour,
		int(game_state.current_minute),
		int(game_state.current_second)
	)
	if (
		not dialog_system.has_active_dialogue()
		or fake_bridge.judgement_requests.size() != actual_boundary_request_start
	):
		_fail(
			"Actual hour_started boundary interrupted the exchange or launched judgement early; active=%s request_delta=%d"
			% [
				str(dialog_system.has_active_dialogue()),
				fake_bridge.judgement_requests.size() - actual_boundary_request_start
			]
		)
		return
	var carryover_snapshot: Dictionary = daily_plan_system.get_dialogue_carryover_snapshot()
	if (
		not (carryover_snapshot.get("deferred_npc_ids", []) as Array).has("doctor_01")
		or not (carryover_snapshot.get("deferred_npc_ids", []) as Array).has("priest_01")
	):
		_fail("Active cross-hour conversation did not defer both participants' new-hour plans")
		return
	dialog_system.end_dialogue("verify_cross_hour_dialogue_completed")
	var boundary_judgement_deadline := Time.get_ticks_msec() + 1000
	while (
		fake_bridge.judgement_requests.size() < actual_boundary_request_start + 2
		and Time.get_ticks_msec() < boundary_judgement_deadline
	):
		await process_frame
	if fake_bridge.judgement_requests.size() != actual_boundary_request_start + 2:
		_fail("Completed cross-hour dialogue did not launch two plan judgements")
		return
	var first_boundary_request: Dictionary = fake_bridge.judgement_requests[actual_boundary_request_start]
	var sibling_boundary_request: Dictionary = fake_bridge.judgement_requests[actual_boundary_request_start + 1]
	for boundary_request in [first_boundary_request, sibling_boundary_request]:
		var boundary_history: Array = boundary_request.get("options", {}).get("dialogue_history", [])
		if boundary_history.size() != 2:
			_fail("Hour-boundary judgement lost the completed exchange")
			return

	# Resolve only the first NPC. Its own state changes must not bypass the unresolved
	# sibling barrier and dispatch the new-hour action early.
	fake_bridge.answer_judgement_unchanged(first_boundary_request)
	await process_frame
	await process_frame
	var first_boundary_npc := str(first_boundary_request.get("npc_id", ""))
	var sibling_boundary_npc := str(sibling_boundary_request.get("npc_id", ""))
	var boundary_markers: Dictionary = daily_plan_system.get("_deferred_current_revision_execution_by_npc")
	if (
		bool(boundary_markers.get(first_boundary_npc, {}).get("wait_for_dialogue_resolution", true))
		or not bool(boundary_markers.get(sibling_boundary_npc, {}).get("wait_for_dialogue_resolution", false))
	):
		_fail("First hour-boundary judgement did not stop at the sibling barrier: %s" % str(boundary_markers))
		return
	npc_system.update_npc_state(first_boundary_npc, {
		"current_action": "idle",
		"last_action_result": "verify_sibling_barrier_state_changed"
	})
	await process_frame
	await process_frame
	if (
		not str(action_system.get_runtime_action_id(first_boundary_npc)).is_empty()
		or not str(action_system.get_runtime_action_id(sibling_boundary_npc)).is_empty()
	):
		_fail("npc_state_changed bypassed the unresolved sibling judgement barrier")
		return

	# Only the second completion may release both participants into the current-hour plan.
	fake_bridge.answer_judgement_unchanged(sibling_boundary_request)
	for _index in range(3):
		await process_frame
	var boundary_runtime_snapshot := {
		first_boundary_npc: str(action_system.get_runtime_action_id(first_boundary_npc)),
		sibling_boundary_npc: str(action_system.get_runtime_action_id(sibling_boundary_npc))
	}
	var boundary_blocker_snapshot := {}
	for participant_id in [first_boundary_npc, sibling_boundary_npc]:
		boundary_blocker_snapshot[participant_id] = {
			"pending_chain": bool(daily_plan_system.call("_has_pending_dialogue_plan_chain", participant_id)),
			"can_act": bool(npc_system.can_npc_act(participant_id)),
			"behavior": npc_system.get_npc_behavior_mode_snapshot(participant_id),
			"in_dialogue": bool(dialog_system.is_npc_in_dialogue(participant_id)),
			"current_action": str(npc_system.get_npc_state(participant_id).get("current_action", "")),
			"current_plan": daily_plan_system.get_current_plan_item(participant_id)
		}
	for participant_id in [first_boundary_npc, sibling_boundary_npc]:
		if str(action_system.get_runtime_action_id(participant_id)) != "visit_location":
			_fail(
				"Both sibling judgements completed but %s did not dispatch the new-hour plan; runtimes=%s markers=%s blockers=%s async_judgements=%s async_revisions=%s last_judgement=%s"
				% [
					participant_id,
					str(boundary_runtime_snapshot),
					str(daily_plan_system.get("_deferred_current_revision_execution_by_npc")),
					str(boundary_blocker_snapshot),
					str(daily_plan_system.get("_async_dialogue_plan_judgement_requests")),
					str(daily_plan_system.get("_async_revision_requests")),
					str(daily_plan_system.get_last_dialogue_plan_judgement_result())
				]
			)
			return
		if str(action_system.get_runtime_action_id(participant_id)) == "pray_at_chapel":
			_fail("Hour-boundary judgement resumed %s's old-hour prayer" % participant_id)
			return
		action_system.interrupt_npc_action(participant_id, "verify_hour_boundary_cleanup")
		if not npc_system.debug_enter_location_immediately(participant_id, "chapel"):
			_fail("Could not reset %s after hour-boundary dispatch" % participant_id)
			return
	current_hour = boundary_new_hour

	# A behavior-mode takeover before any completed exchange ends the session but does not
	# fabricate dialogue content just to launch a judgement.
	var behavior_interrupt_start: Dictionary = dialog_system.start_npc_dialogue(
		"doctor_01",
		"priest_01",
		"local_public",
		2,
		{"autonomous": true, "ui_visible": false, "replace_existing": false}
	)
	if not bool(behavior_interrupt_start.get("ok", false)):
		_fail(
			"Could not set up behavior-mode dialogue interruption: %s; doctor=%s; priest=%s"
			% [
				str(behavior_interrupt_start),
				str(npc_system.get_npc_state("doctor_01")),
				str(npc_system.get_npc_state("priest_01"))
			]
		)
		return
	var doctor_reevaluations_before := int(reevaluation_counts["doctor_01"])
	var priest_reevaluations_before := int(reevaluation_counts["priest_01"])
	var judgements_before_behavior_interrupt := fake_bridge.judgement_requests.size()
	var combat_mode_result: Dictionary = npc_system.set_npc_behavior_mode(
		"priest_01",
		"combat",
		"verify_dialogue_behavior_interrupt",
		{"interrupt": true}
	)
	if not bool(combat_mode_result.get("ok", false)):
		_fail("Could not switch dialogue participant into combat mode")
		return
	await process_frame
	if dialog_system.has_active_dialogue():
		_fail("Behavior-mode authority did not end the NPC dialogue")
		return
	if (
		int(reevaluation_counts["doctor_01"]) != doctor_reevaluations_before
		or int(reevaluation_counts["priest_01"]) != priest_reevaluations_before
	):
		_fail("Behavior interruption still used the old direct dialogue reevaluation path")
		return
	if fake_bridge.judgement_requests.size() != judgements_before_behavior_interrupt:
		_fail("Dialogue with no completed exchange should not launch a plan judgement")
		return
	var priest_work_plan := _make_dialogue_plan(current_hour)
	priest_work_plan[current_hour] = {
		"hour": current_hour,
		"action_id": "work_garden",
		"reason": "验证战斗模式保护",
		"dialogue_goal": "",
		"priority": 50,
		"target": {}
	}
	if not daily_plan_system.set_npc_daily_plan("priest_01", priest_work_plan, false, "verify_behavior_guard"):
		_fail("Could not install plan for behavior-mode authority verification")
		return
	var blocked_plan_result: Dictionary = daily_plan_system.execute_current_plan_for_npc("priest_01", true)
	if str(blocked_plan_result.get("status", "")) != "authoritative_behavior_mode_active":
		_fail("Daily plan could overwrite a combat/rally/avoid authoritative behavior mode: %s" % str(blocked_plan_result))
		return
	npc_system.set_npc_behavior_mode("priest_01", "work", "verify_dialogue_behavior_cleanup", {
		"interrupt": false,
		"state_changes": {"current_action": "idle"}
	})

	var player_start: Dictionary = dialog_system.start_player_dialogue("cook_01")
	if not bool(player_start.get("ok", false)):
		_fail("Could not set up high-priority player dialogue")
		return
	daily_plan_system.execute_current_plan_for_all(true)
	if str(dialog_system.get_display_dialogue_state().get("target_npc_id", "")) != "cook_01":
		_fail("Hour-boundary plan execution closed an active player dialogue")
		return
	var background_state: Dictionary = dialog_system.get_dialogue_state()
	if str(background_state.get("dialogue_kind", "")) != "npc_npc":
		var low_priority_started: bool = bool(action_system.assign_npc_dialogue(
			"doctor_01",
			"priest_01",
			"再谈一会儿。",
			2,
			false
		))
		if not low_priority_started:
			_fail("A view-only player dialogue draft must not block background NPC dialogue")
			return
		await process_frame
	if str(dialog_system.get_display_dialogue_state().get("target_npc_id", "")) != "cook_01":
		_fail("Background NPC dialogue replaced the displayed player draft")
		return
	background_state = dialog_system.get_dialogue_state()
	if (
		str(background_state.get("dialogue_kind", "")) != "npc_npc"
		or not bool(background_state.get("autonomous", false))
		or not ["doctor_01", "priest_01"].has(str(background_state.get("target_npc_id", "")))
	):
		_fail("View-only draft did not preserve the authoritative background NPC dialogue")
		return
	dialog_system.end_displayed_dialogue(str(player_start.get("dialogue_state", {}).get("dialogue_id", "")))
	dialog_system.end_dialogue("verify_npc_npc_plan_cleanup", {
		"suppress_plan_reevaluation": true,
	})
	await create_timer(0.08).timeout
	main.queue_free()
	await process_frame

	print("T0025 NPC-NPC planned dialogue verification passed.")
	quit(0)


func _has_exact_pair_judgements(requests: Array[Dictionary]) -> bool:
	var counts := {"doctor_01": 0, "priest_01": 0}
	for request in requests:
		var npc_id := str(request.get("npc_id", ""))
		if counts.has(npc_id):
			counts[npc_id] = int(counts[npc_id]) + 1
	return int(counts["doctor_01"]) == 1 and int(counts["priest_01"]) == 1


func _make_work_plan(action_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": action_id,
			"reason": "T0049 NPC-NPC judgement verification",
			"dialogue_goal": "",
			"priority": 50,
			"target": {}
		})
	return plan


func _make_hour_boundary_plan(old_hour: int, new_hour: int) -> Array:
	var plan := _make_work_plan("work_garden")
	plan[old_hour] = {
		"hour": old_hour,
		"action_id": "pray_at_chapel",
		"reason": "验证旧小时行动不可恢复",
		"dialogue_goal": "",
		"priority": 50,
		"target": {}
	}
	plan[new_hour] = {
		"hour": new_hour,
		"action_id": "visit_location",
		"reason": "验证双方判别完成后派发新小时计划",
		"dialogue_goal": "",
		"priority": 50,
		"target": {
			"target_id": "plaza",
			"location_id": "plaza"
		}
	}
	return plan


func _make_dialogue_plan(current_hour: int) -> Array:
	var plan: Array = []
	for hour in range(24):
		if hour == current_hour:
			plan.append({
				"hour": hour,
				"action_id": "talk_to_npc",
				"reason": "协调诊所工位",
				"dialogue_goal": "马塞尔，我现在需要诊所工位，我们能协调一下吗？",
				"priority": 85,
				"target": {
					"target_id": "priest_01",
					"target_npc_id": "priest_01"
				}
			})
		else:
			plan.append({
				"hour": hour,
				"action_id": "work_garden",
				"reason": "保持工作阶段",
				"dialogue_goal": "",
				"priority": 50,
				"target": {}
			})
	return plan


func _workstation_owned_by(building: Dictionary, npc_id: String) -> bool:
	for raw_workstation in building.get("workstations", []):
		if raw_workstation is Dictionary and str((raw_workstation as Dictionary).get("occupied_by", "")) == npc_id:
			return true
	return false


func _payload_has_targeted_action(payload: Dictionary, action_id: String, target_id: String) -> bool:
	for raw_candidate in payload.get("allowed_actions", []):
		if not raw_candidate is Dictionary:
			continue
		var candidate: Dictionary = raw_candidate
		if str(candidate.get("action_id", "")) == action_id and str(candidate.get("target_id", "")) == target_id:
			return true
	return false


func _payload_workstation_owned_by(building: Dictionary, npc_id: String) -> bool:
	for raw_workstation in building.get("workstations", []):
		if raw_workstation is Dictionary and str((raw_workstation as Dictionary).get("occupied_by", "")) == npc_id:
			return true
	return false


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			count += 1
	return count


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return
	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
