extends SceneTree

var _proactive_signal_count := 0


class CapturingPlanBridge:
	extends Node

	signal dialogue_plan_revision_judgement_async_response_received(result: Dictionary)
	signal plan_revision_judgement_async_response_received(result: Dictionary)
	signal plan_revision_async_response_received(result: Dictionary)

	var judgement_requests: Array[Dictionary] = []
	var revision_requests: Array[Dictionary] = []

	func check_health() -> Dictionary:
		return _real_health()

	func get_cached_health(_ttl_msec: int = 5000) -> Dictionary:
		return _real_health()

	func request_dialogue_plan_revision_judgement_async(
		npc_id: String,
		options: Dictionary = {}
	) -> Dictionary:
		var request_id := "proactive_judgement_%d" % (judgement_requests.size() + 1)
		judgement_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func request_npc_plan_revision_async(npc_id: String, options: Dictionary = {}) -> Dictionary:
		var request_id := "proactive_revision_%d" % (revision_requests.size() + 1)
		revision_requests.append({
			"request_id": request_id,
			"npc_id": npc_id,
			"options": options.duplicate(true)
		})
		return {"ok": true, "pending": true, "request_id": request_id}

	func answer_judgement(request: Dictionary, revision_hours: Array) -> void:
		plan_revision_judgement_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"dialogue_plan_revision_judgement": {
				"npc_id": str(request.get("npc_id", "")),
				"needs_revision": not revision_hours.is_empty(),
				"revision_hours": revision_hours.duplicate(),
				"summary": "主动交涉完成后安排当前后续活动。",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})

	func answer_revision(request: Dictionary, revised_item: Dictionary) -> void:
		plan_revision_async_response_received.emit({
			"ok": true,
			"request_id": str(request.get("request_id", "")),
			"npc_id": str(request.get("npc_id", "")),
			"plan_revision": {
				"npc_id": str(request.get("npc_id", "")),
				"revised_plan": [revised_item.duplicate(true)],
				"immediate_action": revised_item.duplicate(true),
				"summary": "主动交涉结束，立即返回食堂工作。",
				"model_provider": "deepseek",
				"model_name": "capture-real-provider",
				"model_fallback_used": false
			}
		})

	func _real_health() -> Dictionary:
		return {
			"ok": true,
			"body": {
				"model_adapter": {
					"provider": "deepseek",
					"model": "capture-real-provider",
					"configured": true,
					"fallback_to_mock": false
				}
			}
		}


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var cancel_button := dialog_panel.find_child("DialogCancelButton", true, false) as Button if dialog_panel != null else null
	var event_bus := root.get_node_or_null("EventBus")
	var game_state := root.get_node_or_null("GameState")
	var cook_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var systems := root.get_node_or_null("Main/Systems")
	var original_llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if [npc_system, dialog_system, memory_system, dialog_panel, npc_panel, cancel_button, event_bus, game_state, cook_node, daily_plan_system, action_system, systems, original_llm_bridge].has(null):
		push_error("T0705 verification required nodes not found")
		quit(1)
		return

	systems.remove_child(original_llm_bridge)
	original_llm_bridge.queue_free()
	await process_frame
	var bridge := CapturingPlanBridge.new()
	bridge.name = "LLMBridge"
	systems.add_child(bridge)
	bridge.plan_revision_judgement_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_judgement_async_response")
	)
	bridge.plan_revision_async_response_received.connect(
		Callable(daily_plan_system, "_on_plan_revision_async_response")
	)
	var current_hour := int(game_state.current_hour)
	if (
		not daily_plan_system.set_npc_daily_plan("cook_01", _make_proactive_plan(current_hour), false, "verify_proactive")
		or not daily_plan_system.set_npc_daily_plan("stableman_01", _make_work_plan("work_stable"), false, "verify_proactive")
		or not daily_plan_system.set_npc_daily_plan("gardener_01", _make_proactive_plan(current_hour), false, "verify_proactive")
	):
		push_error("Could not install deterministic plans for proactive-talk verification")
		quit(1)
		return

	event_bus.npc_proactive_talk_changed.connect(_on_proactive_talk_changed)

	var prompt := "守备官，我想知道你是不是真的有守住这里的办法。"
	var event_count_before: int = int(memory_system.get_event_count())
	npc_system.call("_set_npc_state_without_signal", "cook_01", {
		"last_action_result": "work_failed_crafting_target_missing",
		"last_action_failure_context": {
			"action_id": "work_workshop",
			"failure_type": "crafting_target_missing",
			"failure_summary": "未选择制造目标。"
		}
	})
	var start_result: Dictionary = npc_system.debug_start_proactive_talk("cook_01", prompt)
	if not bool(start_result.get("ok", false)):
		push_error("Failed to start proactive talk: %s" % str(start_result))
		quit(1)
		return
	await process_frame

	var proactive: Dictionary = npc_system.get_proactive_talk("cook_01")
	if not bool(proactive.get("active", false)) or str(proactive.get("prompt_text", "")) != prompt:
		push_error("Proactive talk state was not stored")
		quit(1)
		return
	if str(npc_system.get_npc_state("cook_01").get("current_action", "")) != "proactive_talk":
		push_error("NPC should enter proactive_talk action state")
		quit(1)
		return
	var proactive_npc_state: Dictionary = npc_system.get_npc_state("cook_01")
	if (
		str(proactive_npc_state.get("last_action_result", "")) != "proactive_talk_started"
		or not (proactive_npc_state.get("last_action_failure_context", {}) as Dictionary).is_empty()
	):
		push_error("Proactive talk did not atomically replace the stale action failure")
		quit(1)
		return
	await process_frame
	if not bridge.judgement_requests.is_empty():
		push_error("Starting proactive talk re-consumed the stale action failure")
		quit(1)
		return
	var bubble := cook_node.get_node_or_null("ProactiveTalkBubble") as Label3D
	if bubble == null or not bubble.visible or bubble.text != "?" or bubble.position.y < 2.9:
		push_error("Proactive talk question bubble is not visible")
		quit(1)
		return
	var start_event := _get_last_event(memory_system.get_npc_daily_events("cook_01"), "proactive_talk_started")
	if start_event.is_empty() or str(start_event.get("visibility", "")) != "private":
		push_error("proactive_talk_started private event was not written")
		quit(1)
		return
	var start_payload: Dictionary = start_event.get("payload", {})
	if str(start_payload.get("prompt_text", "")) != prompt or float(start_payload.get("duration_seconds", 0.0)) < 3599.0:
		push_error("proactive_talk_started payload mismatch")
		quit(1)
		return
	if memory_system.get_event_count() != event_count_before + 1:
		push_error("Starting proactive talk should write exactly one event")
		quit(1)
		return

	var planning_request_id := "verify_proactive_click_during_plan"
	if not npc_system.set_npc_llm_activity("cook_01", {
		"active": true,
		"kind": "plan",
		"label": "正在规划",
		"request_id": planning_request_id
	}):
		push_error("Could not install deterministic planning activity")
		quit(1)
		return
	await process_frame
	if bubble.visible:
		push_error("Planning activity should temporarily cover the proactive question marker")
		quit(1)
		return
	if not npc_system.handle_npc_clicked("cook_01"):
		push_error("Planning-time proactive click should still be consumed by the interaction")
		quit(1)
		return
	await process_frame
	if (
		not bool(npc_system.get_proactive_talk("cook_01").get("active", false))
		or dialog_system.has_active_dialogue()
		or not dialog_system.get_display_dialogue_state().is_empty()
	):
		push_error("Rejected planning-time click silently consumed proactive state or opened dialogue")
		quit(1)
		return
	if not npc_system.clear_npc_llm_activity("cook_01", planning_request_id):
		push_error("Could not clear deterministic planning activity")
		quit(1)
		return
	await process_frame
	if not bubble.visible or bubble.text != "?":
		push_error("Proactive question marker did not return after planning completed")
		quit(1)
		return

	var activation_race_request_id := "verify_proactive_activation_race"
	var inject_planning_during_activation := func(_dialogue_state: Dictionary) -> void:
		npc_system.set_npc_llm_activity("cook_01", {
			"active": true,
			"kind": "plan",
			"label": "正在规划",
			"request_id": activation_race_request_id
		})
	dialog_system.dialogue_started.connect(
		inject_planning_during_activation,
		CONNECT_ONE_SHOT
	)
	if not npc_system.handle_npc_clicked("cook_01"):
		push_error("Activation-race proactive click should remain owned by the interaction")
		quit(1)
		return
	await process_frame
	if (
		not bool(npc_system.get_proactive_talk("cook_01").get("active", false))
		or dialog_system.has_active_dialogue()
		or not dialog_system.get_display_dialogue_state().is_empty()
	):
		push_error("Activation-race rejection left a ghost draft or consumed proactive state")
		quit(1)
		return
	if not npc_system.clear_npc_llm_activity("cook_01", activation_race_request_id):
		push_error("Could not clear activation-race planning activity")
		quit(1)
		return
	await process_frame
	if not bubble.visible or bubble.text != "?":
		push_error("Proactive marker did not recover after activation-race rejection")
		quit(1)
		return

	if not npc_system.handle_npc_clicked("cook_01"):
		push_error("Clicking an active proactive talk NPC should open dialogue")
		quit(1)
		return
	await process_frame
	if npc_panel.visible or not dialog_panel.visible:
		push_error("Proactive talk click should open DialogPanel without showing NPCPanel")
		quit(1)
		return
	if bool(npc_system.get_proactive_talk("cook_01").get("active", false)) or bubble.visible:
		push_error("Proactive talk should be cleared after click")
		quit(1)
		return
	var dialogue_state: Dictionary = dialog_system.get_dialogue_state()
	var history: Array = dialogue_state.get("history", [])
	if history.size() != 1 or str(history[0].get("speaker_id", "")) != "cook_01" or str(history[0].get("text", "")) != prompt:
		push_error("Proactive opening line should be shown as the first dialogue history turn")
		quit(1)
		return
	if dialogue_state.has("reevaluate_plan_on_end") or str(dialogue_state.get("dialogue_initiator", "")) != "npc":
		push_error("NPC-initiated player dialogue should use autonomous judgement without the removed manual toggle")
		quit(1)
		return
	if not cancel_button.disabled or cancel_button.tooltip_text != "驿站成员主动交涉不可取消对话。":
		push_error("NPC-initiated proactive dialogue did not disable cancellation with the required tooltip")
		quit(1)
		return
	var locked_cancel_result: Dictionary = dialog_system.cancel_displayed_dialogue()
	if (
		bool(locked_cancel_result.get("ok", false))
		or str(locked_cancel_result.get("error_code", "")) != "dialogue_cancel_locked_by_npc_initiator"
		or not dialog_system.has_active_dialogue()
	):
		push_error("DialogSystem did not enforce the NPC-initiated cancellation lock")
		quit(1)
		return
	var message_event := _get_last_event(memory_system.get_npc_daily_events("cook_01"), "proactive_talk_message")
	if not message_event.is_empty():
		push_error("Proactive dialogue lines must remain buffered until completion")
		quit(1)
		return

	var completed_apply: Dictionary = dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"ok": true,
			"replyer_id": "cook_01",
			"reply_text": "我听见了，谈完后会重新安排今天剩下的事情。",
			"response_kind": "reply_to_player",
			"emotion": "neutral",
			"recruitment_result": "none",
			"wartime_reaction": "none",
		}
	}, {
		"kind": "player_message",
		"clean_text": "把剩下的计划重新想一遍。",
		"next_round": 1,
		"effective_recruitment_request": false,
		"dialogue_kind": "player_npc"
	})
	if not bool(completed_apply.get("ok", false)):
		push_error("Could not apply proactive player-NPC completed turn: %s" % JSON.stringify(completed_apply))
		quit(1)
		return
	var end_result: Dictionary = dialog_system.end_dialogue()
	var session_event := _get_last_event(memory_system.get_npc_daily_events("cook_01"), "dialogue_turn")
	if session_event.is_empty() or (session_event.get("payload", {}).get("dialogue_text", []) as Array).size() < 3:
		push_error("Completed proactive dialogue should commit its full session history")
		quit(1)
		return
	if not bool(end_result.get("plan_judgement_queued", false)):
		push_error("Effective proactive dialogue should queue the mandatory plan judgement")
		quit(1)
		return
	for _index in range(5):
		await process_frame
		if bridge.judgement_requests.size() == 1:
			break
	if bridge.judgement_requests.size() != 1:
		push_error("Effective proactive dialogue should launch exactly one judgement request: %s" % JSON.stringify(
			daily_plan_system.get_last_dialogue_plan_judgement_result()
		))
		quit(1)
		return
	var request_after_click: Dictionary = bridge.judgement_requests[0]
	var judgement_options: Dictionary = request_after_click.get("options", {})
	if str(request_after_click.get("npc_id", "")) != "cook_01" or (judgement_options.get("dialogue_history", []) as Array).size() < 2:
		push_error("Proactive dialogue judgement did not receive the NPC and completed conversation")
		quit(1)
		return
	if judgement_options.get("required_revision_hours", []) != [current_hour]:
		push_error("Current seek_guard_officer dialogue did not require the ending current hour")
		quit(1)
		return
	if not bridge.revision_requests.is_empty():
		push_error("A plan revision must not start before the proactive dialogue judgement returns")
		quit(1)
		return
	bridge.answer_judgement(request_after_click, [current_hour])
	for _index in range(5):
		await process_frame
		if bridge.revision_requests.size() == 1:
			break
	if bridge.revision_requests.size() != 1:
		push_error("Required proactive current hour did not launch formal revision")
		quit(1)
		return
	var proactive_revision_request: Dictionary = bridge.revision_requests[0]
	if proactive_revision_request.get("options", {}).get("revision_hours", []) != [current_hour]:
		push_error("Formal proactive revision did not keep the exact required current hour")
		quit(1)
		return
	var revised_current_item := {
		"hour": current_hour,
		"action_id": "work_dining_hall",
		"action_kind": "work",
		"location_id": "dining_hall",
		"target_id": null,
		"priority": 60,
		"reason": "主动交涉后返回食堂继续工作",
		"dialogue_goal": ""
	}
	bridge.answer_revision(proactive_revision_request, revised_current_item)
	for _index in range(5):
		await process_frame
	if (
		str(daily_plan_system.get_current_plan_item("cook_01").get("action_id", "")) != "work_dining_hall"
		or str(action_system.get_runtime_action_id("cook_01")) != "work_dining_hall"
	):
		push_error("Proactive current-hour revision did not dispatch its new action immediately")
		quit(1)
		return

	var ordinary_start: Dictionary = dialog_system.start_player_dialogue("doctor_01")
	var ordinary_cancel: Dictionary = dialog_system.cancel_displayed_dialogue()
	if not bool(ordinary_start.get("ok", false)) or not bool(ordinary_cancel.get("ok", false)):
		push_error("Guard-initiated ordinary dialogue should remain cancellable")
		quit(1)
		return

	var suspended_event_count_before := _count_events(
		memory_system.get_npc_daily_events("gardener_01"),
		"dialogue_turn"
	)
	var suspended_start: Dictionary = npc_system.debug_start_proactive_talk(
		"gardener_01",
		"守备官，我需要稍后继续谈这件事。"
	)
	if (
		not bool(suspended_start.get("ok", false))
		or not npc_system.handle_npc_clicked("gardener_01")
	):
		push_error("Could not set up suspended NPC-initiated proactive dialogue")
		quit(1)
		return
	var suspended_result: Dictionary = dialog_system.suspend_displayed_dialogue()
	if not bool(suspended_result.get("ok", false)):
		push_error("NPC-initiated proactive dialogue should remain suspendable")
		quit(1)
		return
	event_bus.logical_time_tick.emit(7201.0, 1.0)
	for _index in range(5):
		await process_frame
	if (
		dialog_system.has_active_dialogue()
		or _count_events(
			memory_system.get_npc_daily_events("gardener_01"),
			"dialogue_turn"
		) != suspended_event_count_before + 1
	):
		push_error("Non-cancellable suspended proactive dialogue did not complete on timeout")
		quit(1)
		return

	var timeout_prompt := "守备官，我等会儿再来问。"
	var timeout_result: Dictionary = npc_system.debug_start_proactive_talk("stableman_01", timeout_prompt, 60.0)
	if not bool(timeout_result.get("ok", false)):
		push_error("Failed to start timeout proactive talk")
		quit(1)
		return
	event_bus.logical_time_tick.emit(61.0, 1.0)
	await process_frame
	if bool(npc_system.get_proactive_talk("stableman_01").get("active", false)):
		push_error("Proactive talk should expire after duration")
		quit(1)
		return
	var timeout_request: Dictionary = npc_system.get_last_plan_reevaluation_request()
	if str(timeout_request.get("npc_id", "")) != "stableman_01" or str(timeout_request.get("reason", "")) != "proactive_talk_expired":
		push_error("Expired proactive talk should request plan reevaluation")
		quit(1)
		return
	if bridge.revision_requests.size() != 2 or str(bridge.revision_requests[1].get("npc_id", "")) != "stableman_01":
		push_error("Expired proactive talk should launch one direct (non-dialogue) revision")
		quit(1)
		return
	var timeout_revision_options: Dictionary = bridge.revision_requests[1].get("options", {})
	var timeout_hours: Array = timeout_revision_options.get("revision_hours", [])
	var timeout_plan_item: Dictionary = daily_plan_system.get_current_plan_item("stableman_01")
	if timeout_hours != [int(timeout_plan_item.get("hour", -1))]:
		push_error("Expired proactive talk should revise the current hour only: %s" % JSON.stringify(timeout_revision_options))
		quit(1)
		return
	if _proactive_signal_count < 4:
		push_error("Expected proactive talk changed signals for start/clear/timeout")
		quit(1)
		return

	print("T0705 NPC proactive talk verification passed.")
	quit(0)


func _on_proactive_talk_changed(_npc_id: String, _active: bool) -> void:
	_proactive_signal_count += 1


func _make_work_plan(action_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": action_id,
			"reason": "T0049 proactive-talk verification",
			"source": "verify_proactive"
		})
	return plan


func _make_proactive_plan(current_hour: int) -> Array:
	var plan := _make_work_plan("work_dining_hall")
	plan[current_hour] = {
		"hour": current_hour,
		"action_id": "seek_guard_officer",
		"action_kind": "seek_guard_officer",
		"location_id": null,
		"target_id": null,
		"priority": 80,
		"reason": "主动找守备官确认安排",
		"dialogue_goal": "守备官，我想确认接下来的安排。"
	}
	return plan


func _get_last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			count += 1
	return count
