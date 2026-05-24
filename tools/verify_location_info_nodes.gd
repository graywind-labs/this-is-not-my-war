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
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	if npc_system == null or memory_system == null:
		push_error("Required systems not found")
		quit(1)
		return

	var priest_id := "priest_01"
	var doctor_id := "doctor_01"
	var initial_plaza: Dictionary = memory_system.debug_get_location_snapshot("plaza")
	if not initial_plaza.get("people_present", []).has(priest_id):
		push_error("Initial plaza people_present did not include NPC defaults")
		quit(1)
		return
	if not initial_plaza.get("key_entities", {}).has("main_hall"):
		push_error("Plaza snapshot missing main hall key entity state")
		quit(1)
		return

	if not npc_system.debug_enter_location_immediately(priest_id, "chapel"):
		push_error("Failed to move priest into chapel")
		quit(1)
		return
	var chapel_after_priest: Dictionary = memory_system.debug_get_location_snapshot("chapel")
	if chapel_after_priest.get("people_present", []).size() != 1 or not chapel_after_priest.get("people_present", []).has(priest_id):
		push_error("Chapel people_present was not updated after first entry")
		quit(1)
		return

	if not npc_system.debug_enter_location_immediately(doctor_id, "chapel"):
		push_error("Failed to move doctor into chapel")
		quit(1)
		return
	var chapel_after_doctor: Dictionary = memory_system.debug_get_location_snapshot("chapel")
	if chapel_after_doctor.get("people_present", []).size() != 2:
		push_error("Chapel people_present did not contain both NPCs")
		quit(1)
		return

	var doctor_events: Array = memory_system.debug_get_npc_events(doctor_id)
	var enter_event := _find_event(doctor_events, "location_entered")
	if enter_event.is_empty():
		push_error("Doctor location_entered event not found")
		quit(1)
		return
	var location_snapshot: Dictionary = enter_event.get("payload", {}).get("location_snapshot", {})
	if int(location_snapshot.get("people_count", 0)) != 2:
		push_error("location_entered snapshot did not include current people_count")
		quit(1)
		return
	if not location_snapshot.get("building", {}).has("hp") or not location_snapshot.get("building", {}).has("level"):
		push_error("location_entered snapshot missing building hp or level")
		quit(1)
		return
	if not location_snapshot.has("workstations") or not location_snapshot.has("current_notice"):
		push_error("location_entered snapshot missing workstation or notice fields")
		quit(1)
		return

	var priest_witness_before: int = memory_system.get_npc_witness_events(priest_id).size()
	var local_event: Dictionary = memory_system.add_event({
		"type": "combat_started",
		"subject_npc_id": doctor_id,
		"actor_ids": ["system"],
		"target_ids": ["chapel"],
		"location_id": "chapel",
		"visibility": "local_public",
		"importance": 60,
		"payload": {"wave_id": "debug_local_chapel"}
	})
	if local_event.is_empty():
		push_error("Failed to create local_public event")
		quit(1)
		return
	if memory_system.get_npc_witness_events(priest_id).size() <= priest_witness_before:
		push_error("local_public event was not broadcast to present NPC witness log")
		quit(1)
		return
	if memory_system.get_npc_witness_events(doctor_id).size() > 0:
		push_error("Subject NPC should not receive its own local_public event as witness")
		quit(1)
		return

	if not npc_system.debug_enter_location_immediately(doctor_id, "dining_hall"):
		push_error("Failed to move doctor out of chapel")
		quit(1)
		return
	var chapel_after_exit: Dictionary = memory_system.debug_get_location_snapshot("chapel")
	if chapel_after_exit.get("people_present", []).has(doctor_id):
		push_error("Chapel people_present did not update after NPC left")
		quit(1)
		return

	var plaza_context: Dictionary = memory_system.debug_move_npc_between_locations(doctor_id, "dining_hall", "plaza")
	if not plaza_context.get("key_entities", {}).has("wall") or not plaza_context.get("key_entities", {}).has("front_gate"):
		push_error("Plaza enter snapshot missing wall or gate key entity state")
		quit(1)
		return

	print("T0403 location info node verification passed.")
	quit(0)


func _find_event(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}
