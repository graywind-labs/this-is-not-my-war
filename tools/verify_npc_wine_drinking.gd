extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	if [npc_system, resource_system, action_system, memory_system, llm_bridge, npc_panel, gm_panel].has(null):
		_fail("Required wine-drinking systems not found")
		return

	var npc_id := "cook_01"
	var initial_state: Dictionary = npc_system.get_npc_state(npc_id)
	if not initial_state.has("wine") or int(initial_state.get("wine", -1)) != 0:
		_fail("NPC runtime state must initialize personal wine to 0")
		return
	var drink_action: Dictionary = action_system.get_action("drink_wine")
	if (
		str(drink_action.get("type", "")) != "drink"
		or int(drink_action.get("personal_resource_cost", {}).get("wine", 0)) != 1
		or not str(drink_action.get("description", "")).contains("改善心情")
	):
		_fail("drink_wine action definition is incomplete")
		return
	var clinic_action: Dictionary = action_system.get_action("work_clinic_doctor")
	if str(clinic_action.get("name", "")) != "坐诊" or not str(clinic_action.get("description", "")).contains("研读医学著作"):
		_fail("Clinic doctor status label should be concise without losing its idle-study semantics")
		return

	var no_wine_payload: Dictionary = llm_bridge.build_npc_daily_plan_payload(npc_id)
	if _has_allowed_action(no_wine_payload.get("allowed_actions", []), "drink_wine"):
		_fail("drink_wine must not be offered when NPC owns no wine")
		return
	resource_system.add_resource("wine", 1)
	var gift_result: Dictionary = npc_system.give_wine_to_npc(npc_id, 1, "private")
	if not bool(gift_result.get("ok", false)) or int(npc_system.get_npc_state(npc_id).get("wine", 0)) != 1:
		_fail("Giving wine did not transfer one global wine into NPC-owned wine")
		return

	var with_wine_payload: Dictionary = llm_bridge.build_npc_daily_plan_payload(npc_id)
	var npc_context: Dictionary = with_wine_payload.get("npc", {})
	var npc_state: Dictionary = npc_context.get("state", {})
	if int(npc_state.get("money", -1)) < 0 or int(npc_state.get("wine", -1)) != 1:
		_fail("Plan NPC state did not include personal money and wine")
		return
	var drink_candidate := _find_allowed_action(with_wine_payload.get("allowed_actions", []), "drink_wine")
	if (
		drink_candidate.is_empty()
		or str(drink_candidate.get("action_kind", "")) != "drink"
		or not str(drink_candidate.get("context", {}).get("description", "")).contains("过去的伤痛暂时淡化")
	):
		_fail("Plan allowed_actions did not include drink_wine with its context description")
		return

	npc_system.update_npc_state(npc_id, {
		"current_location": "dining_hall",
		"current_location_name": "餐厅"
	})
	if not action_system.debug_assign_action(npc_id, "drink_wine"):
		_fail("NPC with one personal wine could not start drink_wine")
		return
	if int(npc_system.get_npc_state(npc_id).get("wine", -1)) != 0:
		_fail("Starting drink_wine must deduct exactly one personal wine")
		return
	var consumed_event := _find_event(memory_system.get_npc_daily_events(npc_id), "wine_consumed")
	if (
		consumed_event.is_empty()
		or int(consumed_event.get("payload", {}).get("npc_wine_before", -1)) != 1
		or int(consumed_event.get("payload", {}).get("npc_wine_after", -1)) != 0
		or str(consumed_event.get("location_id", "")) != "dining_hall"
		or not str(consumed_event.get("summary", "")).contains("心情有所改善")
	):
		_fail("wine_consumed event did not preserve the authoritative deduction and context effect")
		return
	if npc_system.get_npc_state(npc_id).has("emotion"):
		_fail("Drinking must not introduce a numeric emotion state")
		return

	action_system._stop_active_action(npc_id, "wine_drinking_test_stopped")
	if action_system.debug_assign_action(npc_id, "drink_wine"):
		_fail("NPC must not start a second drink_wine without another personal wine")
		return
	if str(npc_system.get_npc_state(npc_id).get("last_action_result", "")) != "drink_wine_failed_no_wine":
		_fail("No-wine execution failure was not recorded for plan reevaluation")
		return

	# Reproduce the player-facing sequence: select an NPC in the world panel, gift
	# wine there, then open GM and assign drinking. Opening GM must carry the
	# world selection into its otherwise independent tab selectors.
	var ui_npc_id := "doctor_01"
	resource_system.add_resource("wine", 1)
	if not npc_system.debug_select_npc(ui_npc_id):
		_fail("Could not select the UI wine-drinking regression NPC")
		return
	await process_frame
	var wine_spin := npc_panel.find_child("NPCGiftWineSpin", true, false) as SpinBox
	var gift_wine_button := npc_panel.find_child("NPCGiftWineButton", true, false) as Button
	var gm_button := gm_panel.find_child("GMButton", true, false) as Button
	var gm_window := gm_panel.find_child("GMWindow", true, false) as PanelContainer
	var formal_npc_select := gm_panel.find_child("FormalActionNpcSelect", true, false) as OptionButton
	var action_select := gm_panel.find_child("ActionSelect", true, false) as OptionButton
	var assign_action_button := gm_panel.find_child("AssignActionButton", true, false) as Button
	if [wine_spin, gift_wine_button, gm_button, gm_window, formal_npc_select, action_select, assign_action_button].has(null):
		_fail("Gift-wine to GM-drink regression controls are missing")
		return
	wine_spin.value = 1.0
	gift_wine_button.pressed.emit()
	await process_frame
	if int(npc_system.get_npc_state(ui_npc_id).get("wine", 0)) != 1:
		_fail("NPC panel did not gift wine to the world-selected NPC")
		return
	if not gm_window.visible:
		gm_button.pressed.emit()
	await process_frame
	if str(formal_npc_select.get_item_metadata(formal_npc_select.selected)) != ui_npc_id:
		_fail("Opening GM did not synchronize the formal-action NPC with the world-selected NPC")
		return
	if not _select_option_by_id(action_select, "drink_wine"):
		_fail("GM action selector does not expose drink_wine")
		return
	assign_action_button.pressed.emit()
	await process_frame
	if int(npc_system.get_npc_state(ui_npc_id).get("wine", -1)) != 0:
		_fail("GM drinking did not consume the wine gifted through the NPC panel")
		return
	var ui_events: Array = memory_system.get_npc_daily_events(ui_npc_id)
	if ui_events.is_empty() or str((ui_events.back() as Dictionary).get("type", "")) != "wine_consumed":
		_fail("Gift-wine to GM-drink path did not finish with a wine_consumed event")
		return

	print("T0063/T0384 NPC gift-wine, GM target sync, drink-wine and concise clinic status verification passed.")
	quit(0)


func _find_allowed_action(actions: Array, action_id: String) -> Dictionary:
	for raw_action in actions:
		if raw_action is Dictionary and str((raw_action as Dictionary).get("action_id", "")) == action_id:
			return (raw_action as Dictionary).duplicate(true)
	return {}


func _has_allowed_action(actions: Array, action_id: String) -> bool:
	return not _find_allowed_action(actions, action_id).is_empty()


func _select_option_by_id(select: OptionButton, target_id: String) -> bool:
	for index in range(select.get_item_count()):
		if str(select.get_item_metadata(index)) == target_id:
			select.select(index)
			return true
	return false


func _find_event(events: Array, event_type: String) -> Dictionary:
	for raw_event in events:
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			return (raw_event as Dictionary).duplicate(true)
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
