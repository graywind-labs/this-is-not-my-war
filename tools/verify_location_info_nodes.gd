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

	var priest_witness_before_doctor_entry: int = memory_system.get_npc_witness_events(priest_id).size()
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
	if enter_event.get("payload", {}).has("location_snapshot"):
		push_error("location_entered should not duplicate full location state in payload")
		quit(1)
		return
	if str(enter_event.get("summary", "")).contains("workstation"):
		push_error("location_entered summary should only describe the entry action")
		quit(1)
		return

	var entry_snapshot_event := _find_location_state_event(memory_system.get_npc_witness_events(doctor_id), "location_entry_snapshot")
	if entry_snapshot_event.is_empty():
		push_error("NPC entry witness snapshot was not created")
		quit(1)
		return
	var location_snapshot: Dictionary = entry_snapshot_event.get("payload", {}).get("location_snapshot", {})
	if location_snapshot.get("people_present", []).size() != 2:
		push_error("Entry witness snapshot did not include current people_present")
		quit(1)
		return
	if location_snapshot.get("building", {}).has("hp"):
		push_error("Entry witness snapshot should not expose building HP as propagatable state")
		quit(1)
		return
	if not location_snapshot.get("building", {}).get("external_state", {}).has("level"):
		push_error("Entry witness snapshot missing building level")
		quit(1)
		return
	if location_snapshot.has("workstation_count"):
		push_error("Entry witness snapshot should not expose workstation_count")
		quit(1)
		return
	if not location_snapshot.has("workstations") or not location_snapshot.has("current_notice"):
		push_error("Entry witness snapshot missing workstation or notice fields")
		quit(1)
		return
	if location_snapshot.get("workstations", []).is_empty():
		push_error("Entry witness snapshot should include full building workstation state")
		quit(1)
		return

	var priest_entry_witnesses: Array = _events_after(memory_system.get_npc_witness_events(priest_id), priest_witness_before_doctor_entry)
	if _find_event(priest_entry_witnesses, "location_entered").is_empty():
		push_error("Existing NPC did not receive the local_public location_entered event")
		quit(1)
		return
	if not _find_location_state_event(priest_entry_witnesses, "location_entry_snapshot").is_empty():
		push_error("Existing NPC should not receive a full location snapshot when another NPC enters")
		quit(1)
		return

	var priest_witness_before: int = memory_system.get_npc_witness_events(priest_id).size()
	var doctor_witness_before: int = memory_system.get_npc_witness_events(doctor_id).size()
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
	if memory_system.get_npc_witness_events(doctor_id).size() != doctor_witness_before:
		push_error("Subject NPC should not receive its own local_public event as witness")
		quit(1)
		return

	var priest_witness_before_exit: int = memory_system.get_npc_witness_events(priest_id).size()
	if not npc_system.debug_enter_location_immediately(doctor_id, "dining_hall"):
		push_error("Failed to move doctor out of chapel")
		quit(1)
		return
	var chapel_after_exit: Dictionary = memory_system.debug_get_location_snapshot("chapel")
	if chapel_after_exit.get("people_present", []).has(doctor_id):
		push_error("Chapel people_present did not update after NPC left")
		quit(1)
		return

	var exit_event := _find_event(memory_system.debug_get_npc_events(doctor_id), "location_exited")
	if exit_event.is_empty():
		push_error("Doctor location_exited event not found")
		quit(1)
		return
	if str(exit_event.get("location_id", "")) != "chapel":
		push_error("location_exited event location_id should be the location being left")
		quit(1)
		return
	if exit_event.get("payload", {}).has("location_snapshot") or exit_event.get("payload", {}).has("people_present"):
		push_error("location_exited should not carry full location state")
		quit(1)
		return
	var priest_exit_witnesses: Array = _events_after(memory_system.get_npc_witness_events(priest_id), priest_witness_before_exit)
	if _find_event(priest_exit_witnesses, "location_exited").is_empty():
		push_error("Remaining NPC did not receive the local_public location_exited event")
		quit(1)
		return
	if not _find_location_state_event(priest_exit_witnesses, "location_entry_snapshot").is_empty():
		push_error("Remaining NPC should not receive a full location snapshot when another NPC exits")
		quit(1)
		return

	var plaza_context: Dictionary = memory_system.debug_move_npc_between_locations(doctor_id, "dining_hall", "plaza")
	if not plaza_context.get("key_entities", {}).has("wall") or not plaza_context.get("key_entities", {}).has("front_gate"):
		push_error("Plaza enter snapshot missing wall or gate key entity state")
		quit(1)
		return
	if not plaza_context.get("building_external_states", {}).has("chapel"):
		push_error("Plaza snapshot did not inherit all building external states")
		quit(1)
		return
	if plaza_context.get("key_entities", {}).get("main_hall", {}).has("workstations"):
		push_error("Plaza external building state should not expose internal workstation state")
		quit(1)
		return

	print("T0407 location info node verification passed.")
	quit(0)


func _find_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _find_location_state_event(events: Array, reason: String) -> Dictionary:
	for event in events:
		if not event is Dictionary:
			continue
		if str(event.get("type", "")) != "location_status_changed":
			continue
		if str(event.get("payload", {}).get("reason", "")) == reason:
			return event
	return {}


func _events_after(events: Array, start_index: int) -> Array:
	var result: Array = []
	for index in range(start_index, events.size()):
		result.append(events[index])
	return result
