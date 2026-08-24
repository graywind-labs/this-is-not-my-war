extends SceneTree


const NPC_ID := "engineer_01"
const BUILDING_ID := "wall"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene missing")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if action_system == null or building_system == null or npc_system == null or resource_system == null or time_system == null or memory_system == null or controller == null:
		_fail("Required systems missing")
		return
	time_system.set_paused(false)
	time_system.set_time_scale(0.0)
	resource_system.add_resources({"wood": 999, "stone": 999, "iron": 999, "grain": 999})
	controller.debug_set_preview_enabled(true)
	await physics_frame
	await process_frame
	controller.force_sync_production_navigation()
	for upgrade_building_id in building_system.get_building_ids():
		var slots: Array[Dictionary] = controller.get_building_exterior_service_slots(str(upgrade_building_id), "upgrade")
		if slots.is_empty() or not slots[0].get("position") is Vector3:
			_fail("Building has no formal exterior upgrade slot: %s" % str(upgrade_building_id))
			return
	_set_debug_move_speed(npc_system, NPC_ID, 8.0)
	if not building_system.upgrade_building(BUILDING_ID):
		_fail("Could not start wall upgrade")
		return
	var event_count_before: int = int(memory_system.get_event_count())
	if not action_system.debug_assign_upgrade_assist(NPC_ID, BUILDING_ID):
		_fail("Could not assign formal upgrade assist")
		return
	var formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID)
	var session: Dictionary = formal.get("session", {}) if formal.get("session", {}) is Dictionary else {}
	if (
		not bool(formal.get("active", false))
		or str(session.get("action_id", "")) != "assist_upgrade"
		or str(session.get("building_id", "")) != BUILDING_ID
		or str(session.get("service_kind", "")) != "upgrade"
		or str(session.get("service_slot_id", "")).is_empty()
	):
		_fail("Formal exterior upgrade session or construction slot was not reserved")
		return
	var second_npc_id := "doctor_01"
	if not action_system.debug_assign_upgrade_assist(second_npc_id, BUILDING_ID):
		_fail("Second formal upgrade helper could not reserve another construction slot")
		return
	var second_formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(second_npc_id)
	var second_session: Dictionary = second_formal.get("session", {}) if second_formal.get("session", {}) is Dictionary else {}
	if (
		str(second_session.get("service_slot_id", "")).is_empty()
		or str(second_session.get("service_slot_id", "")) == str(session.get("service_slot_id", ""))
	):
		_fail("Concurrent upgrade helpers did not receive distinct construction slots")
		return
	action_system.interrupt_npc_action(second_npc_id, "test_second_upgrade_slot_released", true)
	if bool(npc_system.get_formal_workstation_action_snapshot(second_npc_id).get("active", false)):
		_fail("Stopping the second pending upgrade helper did not release its slot")
		return
	var upgrade_before: Dictionary = building_system.get_upgrade_status(BUILDING_ID)
	if int(upgrade_before.get("helper_count", 0)) != 0 or memory_system.get_event_count() != event_count_before:
		_fail("Upgrade helper or start event committed before physical arrival")
		return
	var npc_node := npc_system.get_node_or_null(npc_system._npc_nodes.get(NPC_ID, NodePath())) as Node3D
	if npc_node == null:
		_fail("Formal NPC body missing")
		return
	var pending_art: Dictionary = npc_node.debug_get_character_art_snapshot()
	if str(pending_art.get("desired_state", "")) == "work" or bool(pending_art.get("engineer_wrench_visible", false)) or str(pending_art.get("engineer_goggles_mode", "")) != "forehead":
		_fail("Upgrade presentation started before Owen reached the construction slot")
		return
	var start_position := npc_node.global_position
	time_system.set_paused(true)
	for frame in range(6):
		await physics_frame
	if npc_node.global_position.distance_to(start_position) > 0.001:
		_fail("Pending upgrade actor moved while gameplay was paused")
		return
	time_system.set_paused(false)
	# Upgrade progress emits building-state changes while the actor is travelling.
	# That broad eviction scan must not cancel a formal exterior construction route.
	building_system._on_logical_time_tick(0.1, 1.0)
	await process_frame
	if not action_system.has_pending_action(NPC_ID) or not bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", false)):
		_fail("An upgrade progress tick cancelled the exterior route")
		return
	var arrived := false
	for frame in range(2400):
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		if str(state.get("last_action_result", "")) == "assist_upgrade_started_%s" % BUILDING_ID:
			arrived = true
			break
		if int(building_system.get_upgrade_status(BUILDING_ID).get("helper_count", 0)) != 0:
			_fail("Upgrade helper committed before the started result")
			return
	if not arrived:
		_fail("Formal upgrade actor did not reach the construction slot: %s" % JSON.stringify(npc_system.get_formal_workstation_action_snapshot(NPC_ID)))
		return
	var arrived_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var active_upgrade: Dictionary = building_system.get_upgrade_status(BUILDING_ID)
	var active_art: Dictionary = npc_node.debug_get_character_art_snapshot()
	if (
		npc_node.global_position.distance_to(start_position) < 1.0
		or str(arrived_state.get("current_location", "")) != "plaza"
		or str(arrived_state.get("physical_location_phase", "")) != "building_exterior_service"
		or str(arrived_state.get("formal_exterior_building_id", "")) != BUILDING_ID
		or str(arrived_state.get("formal_exterior_service_kind", "")) != "upgrade"
		or int(active_upgrade.get("helper_count", 0)) != 1
		or float(active_upgrade.get("speed_multiplier", 1.0)) <= 1.0
		or str(active_art.get("desired_state", "")) != "work"
		or not bool(active_art.get("engineer_wrench_visible", false))
		or str(active_art.get("engineer_goggles_mode", "")) != "forehead"
	):
		_fail("Physical arrival did not atomically commit the upgrade helper")
		return
	if _count_events(memory_system.get_all_events(), "upgrade_assist_started") != 1:
		_fail("Upgrade assist start event was not emitted exactly once")
		return
	building_system._on_logical_time_tick(99999.0, 1.0)
	await process_frame
	var completed_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		str(completed_state.get("last_action_result", "")) != "completed_assist_upgrade_%s" % BUILDING_ID
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", false))
		or int(building_system.get_upgrade_status(BUILDING_ID).get("helper_count", 0)) != 0
	):
		_fail("Upgrade completion left a formal session or helper behind")
		return
	if not building_system.upgrade_building(BUILDING_ID) or not action_system.debug_assign_upgrade_assist(second_npc_id, BUILDING_ID):
		_fail("Could not prepare the in-transit upgrade-resolution boundary")
		return
	building_system._on_logical_time_tick(99999.0, 1.0)
	await process_frame
	var cancelled_state: Dictionary = npc_system.get_npc_state(second_npc_id)
	if (
		bool(npc_system.get_formal_workstation_action_snapshot(second_npc_id).get("active", false))
		or action_system.has_pending_action(second_npc_id)
		or str(cancelled_state.get("last_action_result", "")) != "assist_upgrade_failed_no_active_upgrade"
	):
		_fail("An upgrade resolved during travel left a pending action or formal session")
		return
	print("T0129C A5-P6d-2 formal upgrade assist verification passed.")
	quit(0)


func _set_debug_move_speed(npc_system: Node, npc_id: String, speed: float) -> void:
	var npc_node := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath()))
	if npc_node != null:
		npc_node.move_speed = speed


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str(raw_event.get("type", "")) == event_type:
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
