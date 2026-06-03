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
	if npc_system == null or action_system == null or memory_system == null:
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

	var damage_result: Dictionary = npc_system.debug_damage_npc(target_id, 150, "local_public")
	if damage_result.is_empty() or not bool(damage_result.get("ok", false)):
		push_error("NPC damage API failed")
		quit(1)
		return

	var partial_result: Dictionary = npc_system.debug_advance_unconscious_recovery(target_id, 3600.0)
	var partial_state: Dictionary = npc_system.get_npc_state(target_id)
	if int(partial_state.get("hp", -1)) != 2:
		push_error("Unconscious NPC should recover 2 HP after one game hour")
		quit(1)
		return
	if not bool(partial_state.get("unconscious", false)):
		push_error("NPC should remain unconscious before reaching 30 percent HP")
		quit(1)
		return
	if not (partial_result.get("revived", []) as Array).is_empty():
		push_error("Partial recovery should not revive NPC")
		quit(1)
		return

	var unconscious_witness_count: int = memory_system.get_npc_witness_events(target_id).size()
	memory_system.add_event({
		"type": "work_started",
		"subject_npc_id": witness_id,
		"actor_ids": [witness_id],
		"target_ids": ["dining_hall", "eat_at_dining_hall"],
		"location_id": "dining_hall",
		"visibility": "local_public",
		"importance": 20,
		"payload": {
			"action_id": "eat_at_dining_hall",
			"workstation_id": "dining_hall"
		}
	})
	if memory_system.get_npc_witness_events(target_id).size() != unconscious_witness_count:
		push_error("Unconscious NPC should not receive witness broadcasts")
		quit(1)
		return

	var witness_count: int = memory_system.get_npc_witness_events(witness_id).size()
	var revive_result: Dictionary = npc_system.debug_advance_unconscious_recovery(target_id, 14.0 * 3600.0)
	var revived_state: Dictionary = npc_system.get_npc_state(target_id)
	if int(revived_state.get("hp", -1)) != 30:
		push_error("NPC should revive at 30 percent Max HP")
		quit(1)
		return
	if bool(revived_state.get("unconscious", true)):
		push_error("NPC should no longer be unconscious after revival")
		quit(1)
		return
	if str(revived_state.get("current_action", "")) != "idle":
		push_error("Revived NPC should return to idle action")
		quit(1)
		return
	if (revive_result.get("revived", []) as Array).is_empty():
		push_error("Recovery result should report revived NPC")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "revived"):
		push_error("Target event_log missing revived")
		quit(1)
		return
	if memory_system.get_npc_witness_events(witness_id).size() <= witness_count:
		push_error("Witness did not receive local_public revived event")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_witness_events(witness_id), "revived"):
		push_error("Witness log missing revived")
		quit(1)
		return
	unconscious_witness_count = memory_system.get_npc_witness_events(target_id).size()
	memory_system.add_event({
		"type": "work_started",
		"subject_npc_id": witness_id,
		"actor_ids": [witness_id],
		"target_ids": ["dining_hall", "eat_at_dining_hall"],
		"location_id": "dining_hall",
		"visibility": "local_public",
		"importance": 20,
		"payload": {
			"action_id": "eat_at_dining_hall",
			"workstation_id": "dining_hall"
		}
	})
	if memory_system.get_npc_witness_events(target_id).size() <= unconscious_witness_count:
		push_error("Revived NPC should receive witness broadcasts again")
		quit(1)
		return
	if not action_system.debug_assign_eat(target_id):
		push_error("Revived NPC should be assignable to actions again")
		quit(1)
		return

	print("T0502 NPC unconscious natural recovery verification passed.")
	quit(0)


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return true
	return false
