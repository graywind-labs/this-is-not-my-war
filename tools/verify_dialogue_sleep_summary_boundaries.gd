extends SceneTree

var _reevaluation_signal_count := 0
var _last_reevaluation_reason := ""


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
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var event_bus := root.get_node_or_null("EventBus")
	if [npc_system, action_system, dialog_system, llm_bridge, memory_system, daily_plan_system, npc_panel, event_bus].has(null):
		push_error("Boundary verification required nodes not found")
		quit(1)
		return

	if llm_bridge.has_method("set_backend_base_url"):
		llm_bridge.set_backend_base_url("http://127.0.0.1:5999")
	llm_bridge.request_timeout_seconds = 0.05
	event_bus.npc_plan_reevaluation_requested.connect(_on_plan_reevaluation_requested)

	var npc_id := "cook_01"
	npc_system.debug_enter_location_immediately(npc_id, "dining_hall")
	if not action_system.debug_assign_eat(npc_id):
		push_error("Failed to start an interruptible eat action")
		quit(1)
		return
	npc_system.set_npc_llm_activity(npc_id, {
		"active": true,
		"kind": "plan",
		"request_id": "verify_cancellable_plan",
		"cancellable": true
	})
	var dialogue_result: Dictionary = dialog_system.start_player_dialogue(npc_id)
	if bool(dialogue_result.get("ok", false)) or str(dialogue_result.get("error_code", "")) != "npc_planning":
		push_error("Planning NPC should reject opening player dialogue: %s" % JSON.stringify(dialogue_result))
		quit(1)
		return
	if npc_system.get_npc_llm_activity(npc_id).is_empty():
		push_error("Rejected player dialogue should not clear the active plan request")
		quit(1)
		return
	if str(npc_system.get_npc_state(npc_id).get("current_action", "")) != "eat_at_dining_hall":
		push_error("Rejected player dialogue should not interrupt the active eat action")
		quit(1)
		return
	if not npc_system.clear_npc_llm_activity(npc_id, "verify_cancellable_plan"):
		push_error("Could not clear planning activity after the player interlock check")
		quit(1)
		return
	npc_system.set_npc_llm_activity(npc_id, {
		"active": true,
		"kind": "dialogue",
		"request_id": "verify_cancellable_dialogue",
		"cancellable": true
	})
	dialogue_result = dialog_system.start_player_dialogue(npc_id)
	if not bool(dialogue_result.get("ok", false)):
		push_error("Non-plan activity should still allow a view-only player dialogue: %s" % JSON.stringify(dialogue_result))
		quit(1)
		return
	var failed_send: Dictionary = dialog_system.send_player_message("先停一下，我有话问你。")
	if bool(failed_send.get("ok", false)):
		push_error("Dialogue request should fail against the closed verification backend")
		quit(1)
		return
	if not npc_system.get_npc_llm_activity(npc_id).is_empty():
		push_error("Sending player message should still clear cancellable non-plan LLM activity")
		quit(1)
		return
	if str(npc_system.get_npc_state(npc_id).get("current_action", "")) == "eat_at_dining_hall":
		push_error("Sending player message should interrupt the active eat action")
		quit(1)
		return
	dialog_system.cancel_displayed_dialogue()
	await process_frame

	var reevaluations_before_view_only := _reevaluation_signal_count
	dialogue_result = dialog_system.start_player_dialogue(npc_id)
	if not bool(dialogue_result.get("ok", false)):
		push_error("View-only dialogue should open: %s" % JSON.stringify(dialogue_result))
		quit(1)
		return
	dialog_system.end_dialogue()
	await process_frame
	if _reevaluation_signal_count != reevaluations_before_view_only:
		push_error("Opening and closing a dialogue without a completed LLM turn should not request plan reevaluation")
		quit(1)
		return

	var reevaluations_before_cancel := _reevaluation_signal_count
	var events_before_cancel: int = memory_system.get_npc_daily_events(npc_id).size()
	dialogue_result = dialog_system.start_player_dialogue(npc_id)
	if not bool(dialogue_result.get("ok", false)):
		push_error("Async cancellation dialogue should open: %s" % JSON.stringify(dialogue_result))
		quit(1)
		return
	var async_send: Dictionary = dialog_system.send_player_message("先别回答，我只是试一下。", false, true)
	if not bool(async_send.get("ok", false)) or not bool(async_send.get("pending", false)):
		push_error("Async player message should enter pending state: %s" % JSON.stringify(async_send))
		quit(1)
		return
	if not bool(dialog_system.get_dialogue_state().get("waiting", false)):
		push_error("Async player message should mark dialogue as waiting")
		quit(1)
		return
	dialog_system.cancel_displayed_dialogue()
	for _index in range(20):
		await process_frame
	if _reevaluation_signal_count != reevaluations_before_cancel:
		push_error("Cancelled async player message without reply should not request plan reevaluation")
		quit(1)
		return
	if memory_system.get_npc_daily_events(npc_id).size() != events_before_cancel:
		push_error("Cancelled async player message without reply should not write dialogue_turn")
		quit(1)
		return

	var reevaluations_before_completed_turn := _reevaluation_signal_count
	dialogue_result = dialog_system.start_player_dialogue(npc_id)
	if not bool(dialogue_result.get("ok", false)):
		push_error("Completed-turn verification dialogue should open: %s" % JSON.stringify(dialogue_result))
		quit(1)
		return
	if dialog_system.get_dialogue_state().has("reevaluate_plan_on_end"):
		push_error("Guard-officer dialogue still exposes the removed forced-reevaluation option")
		quit(1)
		return
	var activation_result: Dictionary = dialog_system.call("_activate_player_dialogue_draft", "verify_completed_player_turn")
	if not bool(activation_result.get("ok", false)):
		push_error("Could not activate completed-turn verification dialogue: %s" % JSON.stringify(activation_result))
		quit(1)
		return
	var completed_apply: Dictionary = dialog_system.call("_apply_player_message_response", {
		"ok": true,
		"dialogue": {
			"ok": true,
			"replyer_id": npc_id,
			"reply_text": "守备官，我听明白了，会重新安排手上的事。",
			"response_kind": "reply_to_player",
			"invitation_result": "not_applicable",
			"intent": "continue_talk",
			"emotion": "neutral",
			"recruitment_result": "none",
			"wartime_reaction": "none",
			"should_end_dialogue": false
		}
	}, {
		"kind": "player_message",
		"clean_text": "请按我们刚谈的重新安排今天。",
		"next_round": 1,
		"effective_recruitment_request": false
	})
	if not bool(completed_apply.get("ok", false)):
		push_error("Could not apply completed player-NPC LLM turn: %s" % JSON.stringify(completed_apply))
		quit(1)
		return
	var completed_end: Dictionary = dialog_system.end_dialogue("verify_completed_player_turn")
	if not bool(completed_end.get("plan_judgement_queued", false)):
		push_error("Completed player-NPC turn must queue the dialogue judgement layer")
		quit(1)
		return
	var completed_dialogue_id := str(completed_end.get("dialogue_state", {}).get("dialogue_id", ""))
	var completed_judgement: Dictionary = {}
	for _index in range(20):
		await process_frame
		completed_judgement = daily_plan_system.get_last_dialogue_plan_judgement_result()
		if str(completed_judgement.get("dialogue_id", "")) == completed_dialogue_id:
			break
	if str(completed_judgement.get("dialogue_id", "")) != completed_dialogue_id:
		push_error("Completed player-NPC turn did not reach the judgement layer")
		quit(1)
		return
	if str(completed_judgement.get("status", "")) == "no_effective_dialogue":
		push_error("Completed player-NPC turn was incorrectly treated as view-only")
		quit(1)
		return
	if _reevaluation_signal_count != reevaluations_before_completed_turn:
		push_error("Dialogue judgement must not use the old direct plan-reevaluation signal")
		quit(1)
		return

	var hp_before_attack := int(npc_system.get_npc_state(npc_id).get("hp", 0))
	var reevaluations_before_attack := _reevaluation_signal_count
	dialogue_result = dialog_system.start_player_dialogue(npc_id)
	if not bool(dialogue_result.get("ok", false)):
		push_error("Attack dialogue should open: %s" % JSON.stringify(dialogue_result))
		quit(1)
		return
	var failed_attack: Dictionary = dialog_system.attack_target_npc()
	if bool(failed_attack.get("ok", false)):
		push_error("Attack LLM request should fail against the closed verification backend")
		quit(1)
		return
	if int(npc_system.get_npc_state(npc_id).get("hp", 0)) != hp_before_attack - 10:
		push_error("Dialogue attack should commit damage even when the attack reply request fails")
		quit(1)
		return
	var attack_end: Dictionary = dialog_system.end_dialogue()
	if not bool(attack_end.get("plan_judgement_queued", false)):
		push_error("Committed dialogue attack should queue plan judgement even without an NPC reply")
		quit(1)
		return
	var attack_dialogue_id := str(attack_end.get("dialogue_state", {}).get("dialogue_id", ""))
	var attack_judgement: Dictionary = {}
	for _index in range(20):
		await process_frame
		attack_judgement = daily_plan_system.get_last_dialogue_plan_judgement_result()
		if str(attack_judgement.get("dialogue_id", "")) == attack_dialogue_id:
			break
	if str(attack_judgement.get("dialogue_id", "")) != attack_dialogue_id:
		push_error("Committed dialogue attack did not reach the judgement layer")
		quit(1)
		return
	if _reevaluation_signal_count != reevaluations_before_attack:
		push_error("Committed attack judgement must not use the old direct plan-reevaluation signal")
		quit(1)
		return

	var veteran_id := "veteran_deputy_01"
	npc_system.update_npc_state(veteran_id, {"current_action": "sleep_in_dormitory"})
	npc_system.set_first_sleep_summary_lock(veteran_id, true, "verify_summary_lock")
	var locked_dialogue: Dictionary = dialog_system.start_player_dialogue(veteran_id)
	if bool(locked_dialogue.get("ok", false)) or str(locked_dialogue.get("error_code", "")) != "npc_deep_sleep":
		push_error("First sleep summary lock should reject player dialogue: %s" % JSON.stringify(locked_dialogue))
		quit(1)
		return
	if action_system.interrupt_npc_action(veteran_id, "verify_interrupt"):
		push_error("First sleep summary lock should reject action interruption")
		quit(1)
		return
	if action_system.debug_assign_action(veteran_id, "work_garden"):
		push_error("First sleep summary lock should reject action reassignment")
		quit(1)
		return
	var reevaluations_before_order := _reevaluation_signal_count
	var order_result: Dictionary = npc_system.publish_npc_order(veteran_id, "醒来后先检查城门。")
	if not bool(order_result.get("ok", false)) or str(order_result.get("plan_reevaluation_status", {}).get("result", {}).get("status", "")) != "deferred_until_wake":
		push_error("Order during summary lock should be saved but defer reevaluation: %s" % JSON.stringify(order_result))
		quit(1)
		return
	if _reevaluation_signal_count != reevaluations_before_order:
		push_error("Deferred order should not emit immediate reevaluation")
		quit(1)
		return
	npc_system.set_first_sleep_summary_lock(veteran_id, false, "verify_summary_lock")
	npc_system.consume_deferred_plan_reevaluation_after_sleep(veteran_id)
	await process_frame
	if _reevaluation_signal_count <= reevaluations_before_order:
		push_error("Deferred order should request reevaluation after waking")
		quit(1)
		return

	npc_system.set_npc_llm_activity(npc_id, {
		"active": true,
		"kind": "plan",
		"request_id": "verify_panel_plan",
		"cancellable": true
	})
	npc_panel.show_npc(npc_id)
	await process_frame
	var status_label := npc_panel.find_child("NPCLLMStatusLabel", true, false) as Label
	var dialogue_button := npc_panel.find_child("NPCDialogueButton", true, false) as Button
	if status_label == null or status_label.text != "正在计划下一步行动":
		push_error("NPCPanel should show planning status, got %s" % (status_label.text if status_label != null else "<missing>"))
		quit(1)
		return
	if dialogue_button == null or not dialogue_button.disabled or dialogue_button.tooltip_text != "NPC正在思考":
		push_error("NPCPanel dialogue button should be disabled with planning tooltip")
		quit(1)
		return
	var marker := _find_npc_marker(npc_id)
	if marker == null or not marker.visible or marker.text != "...":
		push_error("NPC scene marker should show thinking dots")
		quit(1)
		return
	npc_system.clear_npc_llm_activity(npc_id, "verify_panel_plan")
	await process_frame
	if dialogue_button == null or dialogue_button.disabled:
		push_error("NPCPanel dialogue button should recover after planning activity clears")
		quit(1)
		return

	npc_system.set_first_sleep_summary_lock(npc_id, true, "verify_panel_summary")
	npc_panel.show_npc(npc_id)
	await process_frame
	if status_label == null or status_label.text != "正在熟睡":
		push_error("NPCPanel should show deep sleep status, got %s" % (status_label.text if status_label != null else "<missing>"))
		quit(1)
		return
	marker = _find_npc_marker(npc_id)
	if marker == null or not marker.visible or marker.text != "⊘":
		push_error("NPC scene marker should show forbidden marker during summary")
		quit(1)
		return
	npc_system.set_first_sleep_summary_lock(npc_id, false, "verify_panel_summary")
	if not await _wait_for_async_cleanup(llm_bridge):
		quit(1)
		return

	print("Dialogue and first sleep summary boundary verification passed.")
	quit(0)


func _on_plan_reevaluation_requested(_npc_id: String, reason: String) -> void:
	_reevaluation_signal_count += 1
	_last_reevaluation_reason = reason


func _find_npc_marker(npc_id: String) -> Label3D:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return null
	for child in npc_root.get_children():
		if str(child.get_meta("npc_id", "")) != npc_id:
			continue
		return child.get_node_or_null("LLMActivityMarker") as Label3D
	return null


func _wait_for_async_cleanup(llm_bridge: Node) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		var snapshot: Dictionary = llm_bridge.debug_get_llm_runtime_snapshot()
		if int(snapshot.get("async_request_count", 0)) == 0:
			return true
	push_error("Timed out waiting for LLM async cleanup")
	return false
