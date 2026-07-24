extends SceneTree

var _reevaluation_signal_count := 0


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
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var order_panel := root.get_node_or_null("Main/UI/OrderPanel")
	var event_bus := root.get_node_or_null("EventBus")
	var order_button := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCAssignButton") as Button
	var text_edit := root.get_node_or_null("Main/UI/OrderPanel/PanelContainer/MarginContainer/Content/OrderTextEdit") as TextEdit
	var publish_button := root.get_node_or_null("Main/UI/OrderPanel/PanelContainer/MarginContainer/Content/ButtonRow/OrderPublishButton") as Button
	var close_button := root.get_node_or_null("Main/UI/OrderPanel/PanelContainer/MarginContainer/Content/ButtonRow/OrderCloseButton") as Button
	if npc_system == null or memory_system == null or npc_panel == null or order_panel == null or event_bus == null or order_button == null or text_edit == null or publish_button == null or close_button == null:
		push_error("T0703 verification required nodes not found")
		quit(1)
		return

	event_bus.npc_plan_reevaluation_requested.connect(_on_plan_reevaluation_requested)

	npc_system.debug_select_npc("cook_01")
	await process_frame
	if order_button.visible:
		push_error("Unrecruited NPC should not show the order button")
		quit(1)
		return
	var rejected: Dictionary = npc_system.publish_npc_order("cook_01", "去守城门。")
	if bool(rejected.get("ok", true)) or not npc_system.get_current_order("cook_01").get("text", "").is_empty():
		push_error("Unrecruited NPC order publish should be rejected")
		quit(1)
		return

	var npc_id := "veteran_deputy_01"
	npc_system.update_npc_state(npc_id, {"current_action": "idle"})
	npc_system.debug_select_npc(npc_id)
	await process_frame
	if not order_button.visible or order_button.disabled or order_button.text != "指令":
		push_error("Recruited NPC should show an enabled order button")
		quit(1)
		return

	order_button.pressed.emit()
	await process_frame
	if not order_panel.visible or not npc_panel.visible:
		push_error("Order button should open OrderPanel without hiding NPCPanel")
		quit(1)
		return
	if not text_edit.text.is_empty():
		push_error("Initial current order should be empty")
		quit(1)
		return

	var event_count_before: int = int(memory_system.get_event_count())
	text_edit.text = "守住城门，但先保证自己安全。"
	publish_button.pressed.emit()
	await process_frame

	var order: Dictionary = npc_system.get_current_order(npc_id)
	if str(order.get("text", "")) != "守住城门，但先保证自己安全。" or int(order.get("revision", 0)) != 1:
		push_error("Publishing a changed order should update current_order and revision")
		quit(1)
		return
	if str(order.get("issued_by", "")) != "guard_officer" or int(order.get("issued_day", 0)) <= 0 or str(order.get("issued_time", "")).is_empty():
		push_error("Published order metadata mismatch")
		quit(1)
		return
	if memory_system.get_event_count() <= event_count_before or _reevaluation_signal_count != 1:
		push_error("Changed order should write events and emit one reevaluation request")
		quit(1)
		return

	var events: Array = memory_system.get_npc_daily_events(npc_id)
	var order_event: Dictionary = _find_latest_event(events, "order_assigned")
	var payload: Dictionary = order_event.get("payload", {})
	if str(order_event.get("type", "")) != "order_assigned" or str(order_event.get("visibility", "")) != "private":
		push_error("order_assigned event should be private")
		quit(1)
		return
	if str(order_event.get("summary", "")) != "守备官制定了新的指令。":
		push_error("order_assigned summary mismatch")
		quit(1)
		return
	if str(payload.get("previous_order_text", "")) != "" or str(payload.get("new_order_text", "")) != str(order.get("text", "")) or int(payload.get("order_revision", 0)) != 1:
		push_error("order_assigned payload mismatch")
		quit(1)
		return
	var request: Dictionary = npc_system.get_last_plan_reevaluation_request()
	if str(request.get("npc_id", "")) != npc_id or str(request.get("reason", "")) != "order_changed":
		push_error("Plan reevaluation request snapshot mismatch")
		quit(1)
		return
	var result_status := str(request.get("result", {}).get("status", ""))
	if request.get("current_order", {}) != order or result_status != "missing_current_plan":
		push_error("Plan reevaluation request must retain the latest order and report that no current plan can be revised")
		quit(1)
		return

	var event_count_after_changed: int = int(memory_system.get_event_count())
	var unchanged_result: Dictionary = npc_system.publish_npc_order(npc_id, str(order.get("text", "")))
	if not bool(unchanged_result.get("ok", false)) or bool(unchanged_result.get("changed", true)):
		push_error("Publishing identical text should return unchanged success")
		quit(1)
		return
	if memory_system.get_event_count() != event_count_after_changed or _reevaluation_signal_count != 1:
		push_error("Publishing identical text must have no event or reevaluation side effect")
		quit(1)
		return

	close_button.pressed.emit()
	await process_frame
	order_panel.show_order(npc_id)
	await process_frame
	if text_edit.text != str(order.get("text", "")):
		push_error("Reopening OrderPanel should prefill the current order")
		quit(1)
		return
	text_edit.text = "这段未发布的编辑不应保存。"
	close_button.pressed.emit()
	await process_frame
	if str(npc_system.get_current_order(npc_id).get("text", "")) != str(order.get("text", "")):
		push_error("Closing OrderPanel must not save edits")
		quit(1)
		return

	npc_system.set_npc_recruited("cook_01", true)
	npc_system.debug_select_npc("cook_01")
	await process_frame
	if not order_button.visible or order_button.disabled:
		push_error("Newly recruited NPC should immediately gain the order button")
		quit(1)
		return

	print("T0703 NPC natural language order verification passed.")
	quit(0)


func _on_plan_reevaluation_requested(_npc_id: String, _reason: String) -> void:
	_reevaluation_signal_count += 1


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}
