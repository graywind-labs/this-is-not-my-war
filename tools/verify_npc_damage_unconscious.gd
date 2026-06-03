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
	var witness_id := "doctor_01"
	if not npc_system.debug_enter_location_immediately(target_id, "dining_hall"):
		push_error("Failed to place target in dining hall")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately(witness_id, "dining_hall"):
		push_error("Failed to place witness in dining hall")
		quit(1)
		return

	var target_event_count: int = memory_system.get_npc_daily_events(target_id).size()
	var witness_count: int = memory_system.get_npc_witness_events(witness_id).size()
	var result: Dictionary = npc_system.debug_damage_npc(target_id, 150, "local_public")
	if result.is_empty() or not bool(result.get("ok", false)):
		push_error("NPC damage API failed")
		quit(1)
		return

	var state: Dictionary = npc_system.get_npc_state(target_id)
	if int(state.get("hp", -1)) != 0:
		push_error("NPC HP should be clamped to 0 after lethal damage")
		quit(1)
		return
	if not bool(state.get("unconscious", false)):
		push_error("NPC should be unconscious after HP reaches 0")
		quit(1)
		return
	if str(state.get("current_action", "")) != "unconscious":
		push_error("Unconscious NPC current_action should be unconscious")
		quit(1)
		return
	if memory_system.get_npc_daily_events(target_id).size() <= target_event_count:
		push_error("Damage/unconscious events did not enter target event_log")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "unconscious_started"):
		push_error("Target event_log missing unconscious_started")
		quit(1)
		return
	if memory_system.get_npc_witness_events(witness_id).size() <= witness_count:
		push_error("Witness did not receive local_public unconscious event")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_witness_events(witness_id), "unconscious_started"):
		push_error("Witness log missing unconscious_started")
		quit(1)
		return
	if action_system.debug_assign_eat(target_id):
		push_error("Unconscious NPC should not be assignable to eat")
		quit(1)
		return
	if npc_system.debug_move_npc_to_building(target_id, "plaza"):
		push_error("Unconscious NPC should not be movable")
		quit(1)
		return

	npc_panel.show_npc(target_id)
	await process_frame
	var unconscious_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCUnconsciousLabel") as Label
	if unconscious_label == null or not unconscious_label.text.contains("是"):
		push_error("NPCPanel should show unconscious state")
		quit(1)
		return

	print("T0501 NPC damage and unconscious verification passed.")
	quit(0)


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return true
	return false
