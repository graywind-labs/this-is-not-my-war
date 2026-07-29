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
	if [npc_system, resource_system, action_system, memory_system, llm_bridge].has(null):
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

	print("T0063 NPC gift-wine and drink-wine verification passed.")
	quit(0)


func _find_allowed_action(actions: Array, action_id: String) -> Dictionary:
	for raw_action in actions:
		if raw_action is Dictionary and str((raw_action as Dictionary).get("action_id", "")) == action_id:
			return (raw_action as Dictionary).duplicate(true)
	return {}


func _has_allowed_action(actions: Array, action_id: String) -> bool:
	return not _find_allowed_action(actions, action_id).is_empty()


func _find_event(events: Array, event_type: String) -> Dictionary:
	for raw_event in events:
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			return (raw_event as Dictionary).duplicate(true)
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
