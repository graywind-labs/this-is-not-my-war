extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return
	var main := main_scene.instantiate()
	var test_backend_url := OS.get_environment("TEST_BACKEND_URL").strip_edges()
	var preconfigured_llm_bridge := main.get_node_or_null("Systems/LLMBridge")
	if not test_backend_url.is_empty() and preconfigured_llm_bridge != null:
		preconfigured_llm_bridge.set_backend_base_url(test_backend_url)
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var dialogue_button := npc_panel.find_child("NPCDialogueButton", true, false) as Button
	var assign_button := npc_panel.find_child("NPCAssignButton", true, false) as Button
	var recruited_label := npc_panel.find_child("NPCRecruitedLabel", true, false) as Label
	var public_toggle := dialog_panel.find_child("DialogPublicToggle", true, false) as CheckButton
	var recruitment_toggle := dialog_panel.find_child("DialogRecruitmentToggle", true, false) as CheckButton
	var obsolete_plan_reevaluation_toggle := dialog_panel.find_child("DialogPlanReevaluationToggle", true, false) as CheckButton
	var send_button := dialog_panel.find_child("DialogSendButton", true, false) as Button
	var attack_button := dialog_panel.find_child("DialogAttackButton", true, false) as Button
	var attack_confirmation_dialog := dialog_panel.find_child("DialogAttackConfirmationDialog", true, false) as ConfirmationDialog
	var complete_button := dialog_panel.find_child("DialogEndButton", true, false) as Button
	var cancel_button := dialog_panel.find_child("DialogCancelButton", true, false) as Button
	var suspend_button := dialog_panel.find_child("DialogSuspendButton", true, false) as Button
	var input_edit := dialog_panel.find_child("DialogInputEdit", true, false) as LineEdit
	var history_text := dialog_panel.find_child("DialogHistoryText", true, false) as RichTextLabel
	if npc_system == null or dialog_system == null or memory_system == null or npc_panel == null or dialog_panel == null or llm_bridge == null or dialogue_button == null or assign_button == null or recruited_label == null or public_toggle == null or recruitment_toggle == null or send_button == null or attack_button == null or attack_confirmation_dialog == null or complete_button == null or cancel_button == null or suspend_button == null or input_edit == null or history_text == null:
		push_error("Dialogue UI verification required nodes not found")
		quit(1)
		return
	if not test_backend_url.is_empty():
		llm_bridge.set_backend_base_url(test_backend_url)
	var cook_event_count_before_open := int(memory_system.get_npc_daily_events("cook_01").size())
	var doctor_witness_count_before_open := int(memory_system.get_npc_witness_events("doctor_01").size())

	npc_system.debug_select_npc("cook_01")
	await process_frame
	dialogue_button.pressed.emit()
	await process_frame
	if not npc_panel.visible or not dialog_panel.visible:
		push_error("NPC dialogue button should open DialogPanel without hiding NPCPanel")
		quit(1)
		return
	if dialog_panel.size.x < 600.0 or dialog_panel.size.y < 450.0:
		push_error("DialogPanel layout size is too small: %s" % str(dialog_panel.size))
		quit(1)
		return
	var state: Dictionary = dialog_system.get_dialogue_state()
	if str(state.get("target_npc_id", "")) != "cook_01" or int(state.get("max_rounds", 0)) < 1000:
		push_error("Player dialogue state target or unlimited round semantics mismatch")
		quit(1)
		return
	if public_toggle.disabled:
		push_error("Dialogue public toggle should be enabled before the first turn")
		quit(1)
		return
	if public_toggle.text != "公开":
		push_error("Dialogue public toggle should use the concise public label")
		quit(1)
		return
	if obsolete_plan_reevaluation_toggle != null and obsolete_plan_reevaluation_toggle.visible:
		push_error("Guard-officer dialogue should not expose the removed plan reevaluation toggle")
		quit(1)
		return
	var tab_event := InputEventKey.new()
	tab_event.pressed = true
	tab_event.keycode = KEY_TAB
	tab_event.physical_keycode = KEY_TAB
	dialog_panel.call("_input", tab_event)
	await process_frame
	if (
		not recruitment_toggle.button_pressed
		or not bool(dialog_system.get_dialogue_state().get("recruitment_request_pending", false))
	):
		push_error("Tab should enable the visible recruitment toggle")
		quit(1)
		return
	dialog_panel.call("_input", tab_event)
	await process_frame
	if (
		recruitment_toggle.button_pressed
		or bool(dialog_system.get_dialogue_state().get("recruitment_request_pending", false))
	):
		push_error("Tab should disable the visible recruitment toggle on the next press")
		quit(1)
		return
	var dialog_panel_source := FileAccess.get_file_as_string("res://scripts/ui/DialogPanel.gd")
	if dialog_panel_source.contains("set_plan_reevaluation_on_end") or dialog_panel_source.contains("reevaluate_plan_on_end"):
		push_error("DialogPanel should not read or write the removed manual plan reevaluation state")
		quit(1)
		return
	public_toggle.button_pressed = true
	await process_frame
	state = dialog_system.get_dialogue_state()
	if str(state.get("visibility", "")) != "local_public":
		push_error("Dialogue public toggle did not update DialogSystem visibility")
		quit(1)
		return
	public_toggle.button_pressed = false
	await process_frame
	if str(dialog_system.get_dialogue_state().get("visibility", "")) != "private":
		push_error("Dialogue public toggle did not switch back to private")
		quit(1)
		return
	if (
		memory_system.get_npc_daily_events("cook_01").size() != cook_event_count_before_open
		or memory_system.get_npc_witness_events("doctor_01").size() != doctor_witness_count_before_open
	):
		push_error("Opening dialogue or toggling visibility must not write events or witness entries")
		quit(1)
		return
	var waiting_state: Dictionary = dialog_system.get_dialogue_state()
	waiting_state["waiting"] = true
	dialog_panel.call("_refresh", waiting_state)
	await process_frame
	if not input_edit.editable or not send_button.disabled or not attack_button.disabled:
		push_error("Waiting UI should keep input editable while disabling send and attack")
		quit(1)
		return
	dialog_panel.call("_input", tab_event)
	await process_frame
	if recruitment_toggle.button_pressed or bool(dialog_system.get_dialogue_state().get("recruitment_request_pending", false)):
		push_error("Tab must not toggle recruitment while the control is disabled")
		quit(1)
		return
	dialog_panel.call("_refresh", dialog_system.get_dialogue_state())
	var private_result: Dictionary = dialog_system.send_player_message("今天的粮食还够吗？")
	if not bool(private_result.get("ok", false)):
		push_error("Private dialogue Mock request failed. Start backend/app.py before verification: %s" % str(private_result))
		quit(1)
		return
	state = dialog_system.get_dialogue_state()
	if int(state.get("current_round", 0)) != 1 or state.get("history", []).size() != 2:
		push_error("Dialogue history or round count did not update after Mock reply")
		quit(1)
		return
	if not public_toggle.disabled:
		push_error("Dialogue public toggle should lock after the first turn")
		quit(1)
		return
	if _has_event(memory_system.get_npc_witness_events("doctor_01"), "dialogue_turn"):
		push_error("Private dialogue leaked into third-party witness log")
		quit(1)
		return

	dialog_system.end_dialogue()
	await process_frame
	if dialog_panel.visible:
		push_error("Ending dialogue did not hide DialogPanel")
		quit(1)
		return
	var events: Array = memory_system.get_npc_daily_events("cook_01")
	if events.size() != 1 or not _has_event(events, "dialogue_turn"):
		push_error("Only dialogue_turn should be written for one completed player-NPC turn")
		quit(1)
		return
	var turn_event := _get_event(events, "dialogue_turn")
	var payload: Dictionary = turn_event.get("payload", {})
	for field in ["dialogue_text", "speaker_name", "listener_name", "visibility", "current_round", "max_rounds", "is_recruitment_request", "recruitment_result"]:
		if not payload.has(field):
			push_error("Dialogue turn payload missing %s" % field)
			quit(1)
			return

	var public_start: Dictionary = dialog_system.start_player_dialogue("cook_01")
	if not bool(public_start.get("ok", false)):
		push_error("Failed to start local public dialogue")
		quit(1)
		return
	await process_frame
	public_toggle.button_pressed = true
	await process_frame
	var public_result: Dictionary = dialog_system.send_player_message("大家都听着，晚餐照常。")
	if not bool(public_result.get("ok", false)):
		push_error("Local public dialogue Mock request failed: %s" % str(public_result))
		quit(1)
		return
	if _has_event(memory_system.get_npc_witness_events("doctor_01"), "dialogue_turn"):
		push_error("Local public dialogue must remain buffered until completion")
		quit(1)
		return
	dialog_system.end_dialogue()
	if not _has_event(memory_system.get_npc_witness_events("doctor_01"), "dialogue_turn"):
		push_error("Local public dialogue did not reach same-location third party witness log")
		quit(1)
		return
	var npc_dialogue_start: Dictionary = dialog_system.start_npc_dialogue("doctor_01", "cook_01")
	if not bool(npc_dialogue_start.get("ok", false)):
		push_error("Failed to start NPC-NPC dialogue")
		quit(1)
		return
	var npc_dialogue_result: Dictionary = dialog_system.send_npc_message("晚餐后我需要检查你的手。", true)
	if not bool(npc_dialogue_result.get("ok", false)) or not bool(npc_dialogue_result.get("pending", false)):
		push_error("NPC-NPC dialogue Mock request failed: %s" % str(npc_dialogue_result))
		quit(1)
		return
	# T0049 may have short plan-judgement requests from the two completed player
	# conversations in flight on the same local backend. Keep this UI test tolerant
	# of that legitimate queueing without changing the gameplay timeout contract.
	for _index in range(1000):
		if not bool(dialog_system.get_dialogue_state().get("waiting", false)):
			break
		await create_timer(0.01).timeout
	if bool(dialog_system.get_dialogue_state().get("waiting", false)):
		push_error("NPC-NPC dialogue async reply did not finish")
		quit(1)
		return
	var doctor_events: Array = memory_system.get_npc_daily_events("doctor_01")
	if not _has_event(doctor_events, "dialogue_turn"):
		push_error("NPC-NPC dialogue turn was not written to both participant event logs")
		quit(1)
		return
	var npc_dialogue_state: Dictionary = dialog_system.get_dialogue_state()
	if not npc_dialogue_state.is_empty() and int(npc_dialogue_state.get("current_round", 0)) != 1:
		push_error("NPC-NPC dialogue round did not advance after both NPCs spoke")
		quit(1)
		return
	dialog_system.end_dialogue()

	var recruitment_start: Dictionary = dialog_system.start_player_dialogue("cook_01")
	if not bool(recruitment_start.get("ok", false)):
		push_error("Failed to start recruitment dialogue")
		quit(1)
		return
	await process_frame
	recruitment_toggle.button_pressed = true
	await process_frame
	if not bool(dialog_system.get_dialogue_state().get("recruitment_request_pending", false)) or not recruitment_toggle.button_pressed:
		push_error("Recruitment toggle did not arm the next player message")
		quit(1)
		return
	var accept_activation: Dictionary = dialog_system._activate_player_dialogue_draft("verify_recruitment_accept")
	if not bool(accept_activation.get("ok", false)):
		push_error("Failed to activate recruitment dialogue draft: %s" % JSON.stringify(accept_activation))
		quit(1)
		return
	var accept_effect: Dictionary = dialog_system._ensure_player_dialogue_effect_started("verify_recruitment_accept")
	if not bool(accept_effect.get("ok", false)):
		push_error("Failed to start recruitment dialogue effect: %s" % JSON.stringify(accept_effect))
		quit(1)
		return
	var accept_result: Dictionary = dialog_system._apply_player_message_response({
		"ok": true,
		"dialogue": {
			"replyer_id": "cook_01",
			"reply_text": "好，我愿意应征，一起守住驿站。",
			"response_kind": "reply_to_player",
			"emotion": "determined",
			"recruitment_result": "accept",
			"wartime_reaction": "none",
		}
	}, {
		"clean_text": "请帮忙守住驿站，一起应征。",
		"next_round": 1,
		"effective_recruitment_request": true,
		"dialogue_kind": "player_npc"
	})
	if not bool(accept_result.get("ok", false)):
		push_error("Recruitment accept request failed: %s" % str(accept_result))
		quit(1)
		return
	await process_frame
	if (
		not bool(npc_system.get_npc("cook_01").get("recruited", false))
		or recruited_label.text != "已入伍：是"
		or not assign_button.visible
		or assign_button.disabled
		or assign_button.text != "指令"
	):
		push_error("Accepted recruitment did not immediately refresh authoritative state and NPCPanel order entry")
		quit(1)
		return
	if (
		not bool(dialog_system.get_dialogue_state().get("recruitment_request_pending", false))
		or not recruitment_toggle.button_pressed
	):
		push_error("Recruitment toggle should remain armed for the current session after sending")
		quit(1)
		return
	if not recruitment_toggle.disabled:
		push_error("Recruitment toggle should disable after NPC accepts")
		quit(1)
		return
	if not history_text.text.contains("[color=#63D471]✓ 布鲁诺接受了守备官的应征请求[/color]"):
		push_error("Accepted recruitment reply did not show its green check result line")
		quit(1)
		return
	dialog_system.end_dialogue()
	if not bool(npc_system.get_npc("cook_01").get("recruited", false)):
		push_error("Completing dialogue rolled back the already accepted recruitment")
		quit(1)
		return
	assign_button.pressed.emit()
	await process_frame
	var order_panel := root.get_node_or_null("Main/UI/OrderPanel") as Control
	var order_text_edit := root.get_node_or_null("Main/UI/OrderPanel/PanelContainer/MarginContainer/Content/OrderTextEdit") as TextEdit
	if order_panel == null or order_text_edit == null or not order_panel.visible:
		push_error("Accepted recruitment did not expose a working soft-order text entry")
		quit(1)
		return
	order_panel.visible = false
	var recruitment_event := _get_last_event(memory_system.get_npc_daily_events("cook_01"), "dialogue_turn")
	var recruitment_payload: Dictionary = recruitment_event.get("payload", {})
	if not bool(recruitment_payload.get("is_recruitment_request", false)) or str(recruitment_payload.get("recruitment_result", "")) != "accept":
		push_error("Accepted recruitment was not recorded in dialogue_turn payload")
		quit(1)
		return
	npc_system.debug_select_npc("cook_01")
	await process_frame
	if recruited_label.text != "已入伍：是" or not assign_button.visible or assign_button.disabled or assign_button.text != "指令":
		push_error("Recruited NPC did not show enabled order button")
		quit(1)
		return

	var reject_start: Dictionary = dialog_system.start_player_dialogue("stableman_01")
	if not bool(reject_start.get("ok", false)):
		push_error("Failed to start rejection dialogue")
		quit(1)
		return
	var pending_result: Dictionary = dialog_system.set_recruitment_request_pending()
	if not bool(pending_result.get("ok", false)):
		push_error("Failed to arm rejection recruitment request")
		quit(1)
		return
	var reject_activation: Dictionary = dialog_system._activate_player_dialogue_draft("verify_recruitment_reject")
	if not bool(reject_activation.get("ok", false)):
		push_error("Failed to activate rejection dialogue draft: %s" % JSON.stringify(reject_activation))
		quit(1)
		return
	var reject_effect: Dictionary = dialog_system._ensure_player_dialogue_effect_started("verify_recruitment_reject")
	if not bool(reject_effect.get("ok", false)):
		push_error("Failed to start rejection dialogue effect: %s" % JSON.stringify(reject_effect))
		quit(1)
		return
	var reject_result: Dictionary = dialog_system._apply_player_message_response({
		"ok": true,
		"dialogue": {
			"replyer_id": "stableman_01",
			"reply_text": "不，我还没有准备好参战。",
			"response_kind": "reply_to_player",
			"emotion": "fearful",
			"recruitment_result": "reject",
			"wartime_reaction": "none",
		}
	}, {
		"clean_text": "立刻拿起武器。",
		"next_round": 1,
		"effective_recruitment_request": true,
		"dialogue_kind": "player_npc"
	})
	if not bool(reject_result.get("ok", false)):
		push_error("Recruitment reject request failed: %s" % str(reject_result))
		quit(1)
		return
	if bool(npc_system.get_npc("stableman_01").get("recruited", false)):
		push_error("Rejected recruitment changed NPC recruited state")
		quit(1)
		return
	if (
		not bool(dialog_system.get_dialogue_state().get("recruitment_request_pending", false))
		or not bool(dialog_system.get_dialogue_state().get("session_had_recruitment_request", false))
		or not recruitment_toggle.button_pressed
		or not cancel_button.disabled
		or bool(dialog_system.cancel_displayed_dialogue().get("ok", false))
	):
		push_error("Rejected recruitment should keep the toggle armed and the session non-cancellable")
		quit(1)
		return
	if not history_text.text.contains("[color=#FF6B6B]× 托马拒绝了守备官的应征请求[/color]"):
		push_error("Rejected recruitment reply did not show its red cross result line")
		quit(1)
		return
	dialog_system.end_dialogue()
	var reject_event := _get_last_event(memory_system.get_npc_daily_events("stableman_01"), "dialogue_turn")
	var reject_payload: Dictionary = reject_event.get("payload", {})
	if not bool(reject_payload.get("is_recruitment_request", false)) or str(reject_payload.get("recruitment_result", "")) != "reject":
		push_error("Rejected recruitment was not recorded in dialogue_turn payload")
		quit(1)
		return

	var attack_start: Dictionary = dialog_system.start_player_dialogue("blacksmith_01")
	if not bool(attack_start.get("ok", false)):
		push_error("Failed to start attack dialogue")
		quit(1)
		return
	var hp_before_attack := int(npc_system.get_npc_state("blacksmith_01").get("hp", 0))
	attack_button.pressed.emit()
	await process_frame
	if (
		not attack_confirmation_dialog.visible
		or int(npc_system.get_npc_state("blacksmith_01").get("hp", 0)) != hp_before_attack
	):
		push_error("First attack click after opening should only show confirmation")
		quit(1)
		return
	attack_confirmation_dialog.get_cancel_button().pressed.emit()
	await process_frame
	if int(npc_system.get_npc_state("blacksmith_01").get("hp", 0)) != hp_before_attack:
		push_error("Cancelling first-attack confirmation must not apply damage")
		quit(1)
		return
	attack_button.pressed.emit()
	await process_frame
	if not attack_confirmation_dialog.visible:
		push_error("Cancelling confirmation should keep the next attack protected")
		quit(1)
		return
	attack_confirmation_dialog.get_ok_button().pressed.emit()
	await process_frame
	if int(npc_system.get_npc_state("blacksmith_01").get("hp", 0)) != hp_before_attack - 10:
		push_error("Confirming the first attack did not apply exactly one NPC damage action")
		quit(1)
		return
	var attack_event := _get_last_event(memory_system.get_npc_daily_events("blacksmith_01"), "damage_taken")
	if attack_event.is_empty() or not str(attack_event.get("summary", "")).contains("以示惩戒"):
		push_error("Dialogue attack did not write punishment damage event")
		quit(1)
		return
	# Headless process_frame can advance far faster than the backend worker thread.
	# Wait in wall-clock time so this checks the dialogue result instead of CPU speed.
	for _index in range(500):
		if not bool(dialog_system.get_dialogue_state().get("waiting", false)):
			break
		await create_timer(0.01).timeout
	if bool(dialog_system.get_dialogue_state().get("waiting", false)):
		push_error("Dialogue attack async reply did not finish")
		quit(1)
		return
	var hp_before_followup_attack := int(npc_system.get_npc_state("blacksmith_01").get("hp", 0))
	attack_button.pressed.emit()
	await process_frame
	if (
		attack_confirmation_dialog.visible
		or int(npc_system.get_npc_state("blacksmith_01").get("hp", 0)) != hp_before_followup_attack - 10
	):
		push_error("Follow-up attack in the same visible panel should bypass repeated confirmation")
		quit(1)
		return
	for _index in range(500):
		if not bool(dialog_system.get_dialogue_state().get("waiting", false)):
			break
		await create_timer(0.01).timeout
	if bool(dialog_system.get_dialogue_state().get("waiting", false)):
		push_error("Follow-up attack async reply did not finish")
		quit(1)
		return
	if not _get_last_event(memory_system.get_npc_daily_events("blacksmith_01"), "dialogue_turn").is_empty():
		push_error("Attack dialogue must remain buffered until completion")
		quit(1)
		return
	dialog_system.end_dialogue()
	var attack_dialogue_event := _get_last_event(memory_system.get_npc_daily_events("blacksmith_01"), "dialogue_turn")
	var attack_payload: Dictionary = attack_dialogue_event.get("payload", {})
	if str(attack_payload.get("interaction_kind", "")) != "guard_attack" or not str(attack_payload.get("speaker_text", "")).contains("以示惩戒"):
		push_error("Dialogue attack reply was not recorded as guard_attack dialogue payload")
		quit(1)
		return
	await process_frame
	if not await _wait_for_llm_cleanup(llm_bridge):
		quit(1)
		return
	var reopen_result: Dictionary = dialog_system.start_player_dialogue("blacksmith_01")
	if not bool(reopen_result.get("ok", false)):
		push_error("Failed to reopen attack dialogue for confirmation reset verification")
		quit(1)
		return
	await process_frame
	var hp_before_reopened_attack := int(npc_system.get_npc_state("blacksmith_01").get("hp", 0))
	attack_button.pressed.emit()
	await process_frame
	if (
		not attack_confirmation_dialog.visible
		or int(npc_system.get_npc_state("blacksmith_01").get("hp", 0)) != hp_before_reopened_attack
	):
		push_error("Reopening the dialogue panel should restore first-attack confirmation")
		quit(1)
		return
	attack_confirmation_dialog.get_cancel_button().pressed.emit()
	var cleanup_result: Dictionary = dialog_system.cancel_displayed_dialogue()
	if not bool(cleanup_result.get("ok", false)):
		push_error("Failed to clean up reopened attack-confirmation dialogue")
		quit(1)
		return

	print("T0701/T0702 dialogue UI and recruitment verification passed.")
	quit(0)


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return true
	return false


func _get_event(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _get_last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _wait_for_llm_cleanup(llm_bridge: Node) -> bool:
	for _step in range(500):
		await create_timer(0.01).timeout
		if int(llm_bridge.debug_get_llm_runtime_snapshot().get("async_request_count", 0)) == 0:
			return true
	push_error("Timed out waiting for dialogue UI LLM async cleanup")
	return false
