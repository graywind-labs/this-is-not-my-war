extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var dialogue_button := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCDialogueButton") as Button
	var assign_button := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCAssignButton") as Button
	var recruited_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCRecruitedLabel") as Label
	var public_toggle := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/Header/DialogHeaderToggles/DialogPublicToggle") as CheckButton
	var recruitment_toggle := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/Header/DialogHeaderToggles/DialogRecruitmentToggle") as CheckButton
	var send_button := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/InputRow/DialogSendButton") as Button
	var attack_button := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/InputRow/DialogAttackButton") as Button
	var input_edit := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/InputRow/DialogInputEdit") as LineEdit
	if npc_system == null or dialog_system == null or memory_system == null or npc_panel == null or dialog_panel == null or llm_bridge == null or dialogue_button == null or assign_button == null or recruited_label == null or public_toggle == null or recruitment_toggle == null or send_button == null or attack_button == null or input_edit == null:
		push_error("Dialogue UI verification required nodes not found")
		quit(1)
		return

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
	if not memory_system.get_npc_daily_events("cook_01").is_empty() or not memory_system.get_npc_witness_events("doctor_01").is_empty():
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
	if not _has_event(memory_system.get_npc_witness_events("doctor_01"), "dialogue_turn"):
		push_error("Local public dialogue did not reach same-location third party witness log")
		quit(1)
		return
	dialog_system.end_dialogue()
	var npc_dialogue_start: Dictionary = dialog_system.start_npc_dialogue("doctor_01", "cook_01")
	if not bool(npc_dialogue_start.get("ok", false)):
		push_error("Failed to start NPC-NPC dialogue")
		quit(1)
		return
	var npc_dialogue_result: Dictionary = dialog_system.send_npc_message("晚餐后我需要检查你的手。")
	if not bool(npc_dialogue_result.get("ok", false)):
		push_error("NPC-NPC dialogue Mock request failed: %s" % str(npc_dialogue_result))
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
	var accept_result: Dictionary = dialog_system.send_player_message("请帮忙守住驿站，一起应征。")
	if not bool(accept_result.get("ok", false)):
		push_error("Recruitment accept request failed: %s" % str(accept_result))
		quit(1)
		return
	if not bool(npc_system.get_npc("cook_01").get("recruited", false)):
		push_error("Accepted recruitment did not update NPC authoritative state")
		quit(1)
		return
	if bool(dialog_system.get_dialogue_state().get("recruitment_request_pending", true)):
		push_error("Recruitment request should be consumed after the next request")
		quit(1)
		return
	if not recruitment_toggle.disabled:
		push_error("Recruitment toggle should disable after NPC accepts")
		quit(1)
		return
	var recruitment_event := _get_last_event(memory_system.get_npc_daily_events("cook_01"), "dialogue_turn")
	var recruitment_payload: Dictionary = recruitment_event.get("payload", {})
	if not bool(recruitment_payload.get("is_recruitment_request", false)) or str(recruitment_payload.get("recruitment_result", "")) != "accept":
		push_error("Accepted recruitment was not recorded in dialogue_turn payload")
		quit(1)
		return
	dialog_system.end_dialogue()
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
	var reject_result: Dictionary = dialog_system.send_player_message("立刻拿起武器。")
	if not bool(reject_result.get("ok", false)):
		push_error("Recruitment reject request failed: %s" % str(reject_result))
		quit(1)
		return
	if bool(npc_system.get_npc("stableman_01").get("recruited", false)):
		push_error("Rejected recruitment changed NPC recruited state")
		quit(1)
		return
	var reject_event := _get_last_event(memory_system.get_npc_daily_events("stableman_01"), "dialogue_turn")
	var reject_payload: Dictionary = reject_event.get("payload", {})
	if not bool(reject_payload.get("is_recruitment_request", false)) or str(reject_payload.get("recruitment_result", "")) != "reject":
		push_error("Rejected recruitment was not recorded in dialogue_turn payload")
		quit(1)
		return
	dialog_system.end_dialogue()

	var reevaluation_counter := {"count": 0}
	var event_bus := root.get_node_or_null("EventBus")
	if event_bus != null:
		event_bus.npc_plan_reevaluation_requested.connect(func(_npc_id: String, _reason: String) -> void:
			reevaluation_counter["count"] = int(reevaluation_counter.get("count", 0)) + 1
		)
	var attack_start: Dictionary = dialog_system.start_player_dialogue("blacksmith_01")
	if not bool(attack_start.get("ok", false)):
		push_error("Failed to start attack dialogue")
		quit(1)
		return
	var hp_before_attack := int(npc_system.get_npc_state("blacksmith_01").get("hp", 0))
	attack_button.pressed.emit()
	await process_frame
	if int(npc_system.get_npc_state("blacksmith_01").get("hp", 0)) != hp_before_attack - 10:
		push_error("Dialogue attack button did not apply NPC damage")
		quit(1)
		return
	var attack_event := _get_last_event(memory_system.get_npc_daily_events("blacksmith_01"), "damage_taken")
	if attack_event.is_empty() or not str(attack_event.get("summary", "")).contains("以示惩戒"):
		push_error("Dialogue attack did not write punishment damage event")
		quit(1)
		return
	for _index in range(120):
		if not bool(dialog_system.get_dialogue_state().get("waiting", false)):
			break
		await process_frame
	if bool(dialog_system.get_dialogue_state().get("waiting", false)):
		push_error("Dialogue attack async reply did not finish")
		quit(1)
		return
	var attack_dialogue_event := _get_last_event(memory_system.get_npc_daily_events("blacksmith_01"), "dialogue_turn")
	var attack_payload: Dictionary = attack_dialogue_event.get("payload", {})
	if str(attack_payload.get("interaction_kind", "")) != "guard_attack" or not str(attack_payload.get("speaker_text", "")).contains("以示惩戒"):
		push_error("Dialogue attack reply was not recorded as guard_attack dialogue payload")
		quit(1)
		return
	dialog_system.end_dialogue()
	await process_frame
	if int(reevaluation_counter.get("count", 0)) <= 0:
		push_error("Dialogue attack should request plan reevaluation on dialogue end")
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
