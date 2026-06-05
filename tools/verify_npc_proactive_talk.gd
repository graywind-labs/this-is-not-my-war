extends SceneTree

var _proactive_signal_count := 0


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
	var event_bus := root.get_node_or_null("EventBus")
	var cook_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01")
	if npc_system == null or dialog_system == null or memory_system == null or dialog_panel == null or npc_panel == null or event_bus == null or cook_node == null:
		push_error("T0705 verification required nodes not found")
		quit(1)
		return

	event_bus.npc_proactive_talk_changed.connect(_on_proactive_talk_changed)

	var prompt := "守备官，我想知道你是不是真的有守住这里的办法。"
	var event_count_before: int = int(memory_system.get_event_count())
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
	var bubble := cook_node.get_node_or_null("ProactiveTalkBubble") as Label3D
	if bubble == null or not bubble.visible or bubble.text != "?":
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
	var message_event := _get_last_event(memory_system.get_npc_daily_events("cook_01"), "proactive_talk_message")
	if message_event.is_empty() or str(message_event.get("payload", {}).get("speaker_text", "")) != prompt:
		push_error("Proactive opening line should be recorded before player reply")
		quit(1)
		return

	dialog_system.end_dialogue()
	await process_frame
	var request_after_click: Dictionary = npc_system.get_last_plan_reevaluation_request()
	if str(request_after_click.get("npc_id", "")) != "cook_01" or str(request_after_click.get("reason", "")) != "proactive_dialogue_ended":
		push_error("Ending proactive dialogue should request plan reevaluation")
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
	if _proactive_signal_count < 4:
		push_error("Expected proactive talk changed signals for start/clear/timeout")
		quit(1)
		return

	print("T0705 NPC proactive talk verification passed.")
	quit(0)


func _on_proactive_talk_changed(_npc_id: String, _active: bool) -> void:
	_proactive_signal_count += 1


func _get_last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}
