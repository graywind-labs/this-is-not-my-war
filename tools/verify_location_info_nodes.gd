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
	npc_system.update_npc_state(priest_id, {"hp": 80})
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
	var people_statuses: Array = location_snapshot.get("building", {}).get("internal_state", {}).get("people_statuses", [])
	if people_statuses.is_empty():
		push_error("Entry witness snapshot should include present NPC statuses")
		quit(1)
	if not _has_people_status(people_statuses, priest_id, "injured", "待命"):
		push_error("Entry witness snapshot missing injured life status or action status for present NPC")
		quit(1)
	var entry_snapshot_summary := str(entry_snapshot_event.get("summary", ""))
	if not entry_snapshot_summary.contains("在场人员状态") or not entry_snapshot_summary.contains("马塞尔受伤"):
		push_error("Entry witness summary should mention present NPC life/action statuses")
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
	var doctor_events_before_indoor_route: int = memory_system.debug_get_npc_events(doctor_id).size()
	if not npc_system.debug_enter_location_immediately(doctor_id, "dining_hall"):
		push_error("Failed to move doctor out of chapel")
		quit(1)
		return
	var route_events: Array = _events_after(memory_system.debug_get_npc_events(doctor_id), doctor_events_before_indoor_route)
	if route_events.size() < 4:
		push_error("Indoor-to-indoor movement did not create the full plaza transit event chain")
		quit(1)
		return
	if not _matches_location_event(route_events[0], "location_exited", "chapel", "plaza", "chapel"):
		push_error("Indoor-to-indoor route missing chapel -> plaza exit event")
		quit(1)
		return
	if not _matches_location_event(route_events[1], "location_entered", "chapel", "plaza", "plaza"):
		push_error("Indoor-to-indoor route missing plaza enter event")
		quit(1)
		return
	if not _matches_location_event(route_events[2], "location_exited", "plaza", "dining_hall", "plaza"):
		push_error("Indoor-to-indoor route missing plaza -> dining hall exit event")
		quit(1)
		return
	if not _matches_location_event(route_events[3], "location_entered", "plaza", "dining_hall", "dining_hall"):
		push_error("Indoor-to-indoor route missing dining hall enter event")
		quit(1)
		return

	var chapel_after_exit: Dictionary = memory_system.debug_get_location_snapshot("chapel")
	if chapel_after_exit.get("people_present", []).has(doctor_id):
		push_error("Chapel people_present did not update after NPC left")
		quit(1)
		return

	var exit_event: Dictionary = route_events[0]
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

	var plaza_notice := "今晚在主厅前集合。"
	memory_system.debug_set_plaza_notice(plaza_notice)
	var doctor_witness_before_plaza_entry: int = memory_system.get_npc_witness_events(doctor_id).size()
	if not npc_system.debug_enter_location_immediately(doctor_id, "plaza"):
		push_error("Failed to move doctor into plaza")
		quit(1)
		return
	var plaza_context: Dictionary = npc_system.get_npc_state(doctor_id).get("location_context", {})
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
	if not plaza_context.get("people_present", []).has(doctor_id) or not plaza_context.get("people_present", []).has("stableman_01"):
		push_error("Plaza entry snapshot did not include current plaza people_present")
		quit(1)
		return
	var plaza_people_statuses: Array = plaza_context.get("people_statuses", [])
	if plaza_people_statuses.is_empty():
		push_error("Plaza entry snapshot should include plaza NPC statuses")
		quit(1)
		return
	if not _has_people_status(plaza_people_statuses, doctor_id, "healthy", "待命"):
		push_error("Plaza entry snapshot missing present plaza NPC life/action status")
		quit(1)
		return
	if str(plaza_context.get("current_notice", "")) != plaza_notice:
		push_error("Plaza entry snapshot did not include current notice text")
		quit(1)
		return
	var doctor_plaza_witnesses: Array = _events_after(memory_system.get_npc_witness_events(doctor_id), doctor_witness_before_plaza_entry)
	var plaza_entry_snapshot_event := _find_location_state_event(doctor_plaza_witnesses, "location_entry_snapshot")
	if plaza_entry_snapshot_event.is_empty():
		push_error("Plaza entry witness snapshot was not created")
		quit(1)
		return
	var plaza_entry_witness_snapshot: Dictionary = plaza_entry_snapshot_event.get("payload", {}).get("location_snapshot", {})
	if (
		plaza_entry_witness_snapshot.has("current_notice")
		or plaza_entry_witness_snapshot.has("reference_schedule")
		or plaza_entry_witness_snapshot.has("schedule_advisory_note")
	):
		push_error("Plaza entry witness snapshot should not repeat notice-board pages")
		quit(1)
		return
	var plaza_entry_summary := str(plaza_entry_snapshot_event.get("summary", ""))
	if (
		not plaza_entry_summary.contains("广场现在有")
		or not plaza_entry_summary.contains("在场人员状态")
		or not plaza_entry_summary.contains("莉娜健康")
		or plaza_entry_summary.contains("公告牌")
		or plaza_entry_summary.contains("参考日程")
	):
		push_error("Plaza entry summary did not keep people state while excluding notice-board pages")
		quit(1)
		return

	print("T0409 location info node verification passed.")
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


func _matches_location_event(
	event: Variant,
	event_type: String,
	from_location_id: String,
	to_location_id: String,
	event_location_id: String
) -> bool:
	if not event is Dictionary:
		return false
	var payload: Dictionary = event.get("payload", {})
	return (
		str(event.get("type", "")) == event_type
		and str(event.get("location_id", "")) == event_location_id
		and str(payload.get("from_location_id", "")) == from_location_id
		and str(payload.get("to_location_id", "")) == to_location_id
	)


func _has_people_status(statuses: Array, npc_id: String, life_status: String, action_status: String) -> bool:
	for raw_status in statuses:
		if not raw_status is Dictionary:
			continue
		var status: Dictionary = raw_status
		if (
			str(status.get("npc_id", "")) == npc_id
			and str(status.get("life_status", "")) == life_status
			and str(status.get("action_status", "")) == action_status
		):
			return true
	return false
