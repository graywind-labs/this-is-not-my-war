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
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if npc_system == null or action_system == null or memory_system == null or npc_panel == null:
		push_error("Required systems not found")
		quit(1)
		return

	var target_id := "cook_01"
	var witness_id := "priest_01"
	_set_debug_move_speed(target_id, 100.0)
	if not npc_system.debug_enter_location_immediately(target_id, "dining_hall"):
		push_error("Failed to move target NPC into dining hall")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately(witness_id, "dining_hall"):
		push_error("Failed to move witness NPC into dining hall")
		quit(1)
		return

	if not action_system.debug_assign_eat(target_id):
		push_error("Failed to assign eat action")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, target_id, "eat_at_dining_hall"):
		push_error("Eat action did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(1200.0, 1.0)
	if not await _wait_until_action_result(npc_system, target_id, "completed_eat"):
		push_error("Eat action did not complete")
		quit(1)
		return

	var target_events_before: int = memory_system.get_npc_daily_events(target_id).size()
	var witness_before: int = memory_system.get_npc_witness_events(witness_id).size()
	var money_event: Dictionary = memory_system.debug_record_player_money_given(target_id, 3, "local_public")
	if money_event.is_empty():
		push_error("Failed to record money_given interaction")
		quit(1)
		return
	if not str(money_event.get("summary", "")).contains("守备官"):
		push_error("money_given summary should use in-world player title")
		quit(1)
		return
	if str(money_event.get("summary", "")).contains("玩家"):
		push_error("money_given summary should not expose player wording")
		quit(1)
		return
	if not (money_event.get("actor_ids", []) as Array).has("guard_officer"):
		push_error("money_given actor id should use guard_officer")
		quit(1)
		return
	if memory_system.get_npc_daily_events(target_id).size() <= target_events_before:
		push_error("money_given did not enter target event_log")
		quit(1)
		return
	if memory_system.get_npc_witness_events(witness_id).size() <= witness_before:
		push_error("local_public player interaction did not enter witness_log")
		quit(1)
		return

	var plaza_witness_id := "doctor_01"
	if not npc_system.debug_enter_location_immediately(plaza_witness_id, "plaza"):
		push_error("Failed to move plaza witness")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately(target_id, "plaza"):
		push_error("Failed to move target NPC into plaza")
		quit(1)
		return
	var plaza_witness_before: int = memory_system.get_npc_witness_events(plaza_witness_id).size()
	var attack_event: Dictionary = memory_system.debug_record_player_attack_npc(target_id, 5, "local_public")
	if attack_event.is_empty():
		push_error("Failed to record npc_attacked_by_player interaction")
		quit(1)
		return
	if not str(attack_event.get("summary", "")).contains("守备官"):
		push_error("Attack summary should use in-world player title")
		quit(1)
		return
	if str(attack_event.get("summary", "")).contains("玩家"):
		push_error("Attack summary should not expose player wording")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "npc_attacked_by_player"):
		push_error("Attack interaction did not enter target event_log")
		quit(1)
		return
	if memory_system.get_npc_witness_events(plaza_witness_id).size() <= plaza_witness_before:
		push_error("Plaza local_public attack did not enter plaza witness_log")
		quit(1)
		return

	var short_memory: Dictionary = memory_system.get_npc_short_term_memory(target_id)
	if not (short_memory.get("event_log", []) is Array) or not (short_memory.get("witness_log", []) is Array):
		push_error("Short-term memory container does not expose event_log and witness_log arrays")
		quit(1)
		return
	if not _has_event(short_memory.get("event_log", []), "eat_completed"):
		push_error("Short-term memory event_log missing eat_completed")
		quit(1)
		return

	npc_panel.show_npc(target_id)
	await process_frame
	var event_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCEventLogLabel") as Label
	var witness_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCWitnessLogLabel") as Label
	if event_label == null or witness_label == null:
		push_error("NPCPanel memory labels not found")
		quit(1)
		return
	if not event_label.text.begins_with("事件库：") or not witness_label.text.begins_with("见闻库："):
		push_error("NPCPanel does not distinguish event_log and witness_log")
		quit(1)
		return

	print("T0405 NPC short-term memory container verification passed.")
	quit(0)


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return true
	return false


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for frame in range(300):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("last_action_result", "")) == expected_result:
			return true
	return false


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for frame in range(300):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("current_action", "")) == expected_action:
			return true
	return false


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return

	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return
