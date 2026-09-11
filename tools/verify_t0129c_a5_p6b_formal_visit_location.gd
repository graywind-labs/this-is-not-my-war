extends SceneTree


const NPC_ID := "stableman_01"
const FIRST_TARGET_ID := "chapel"
const SECOND_TARGET_ID := "dining_hall"
const PUBLIC_TARGET_ID := "plaza"
const ACTION_ID := "visit_location"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var run_button := gm_window.find_child("FormalVisitLocationButton", true, false) as Button if gm_window != null else null
	var stop_button := gm_window.find_child("FormalVisitLocationStopButton", true, false) as Button if gm_window != null else null
	var snapshot_button := gm_window.find_child("FormalVisitLocationSnapshotButton", true, false) as Button if gm_window != null else null
	var npc_node := _get_npc_node(npc_system, NPC_ID) if npc_system != null else null
	if [action_system, npc_system, building_system, memory_system, daily_plan_system, time_system, gm_panel, gm_window, run_button, stop_button, snapshot_button, npc_node].has(null):
		_fail("A5-P6b runtime dependencies unavailable")
		return

	var action: Dictionary = action_system.get_action(ACTION_ID)
	if not bool(action.get("formal_spatial_route", false)):
		_fail("visit_location is not configured for formal spatial authority")
		return
	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(false)
	npc_node.set("move_speed", 5.0)
	npc_system.debug_enter_location_immediately(NPC_ID, "plaza")
	npc_system.update_npc_state(NPC_ID, {
		"current_action": "idle",
		"last_action_result": "verify_a5_p6b_ready"
	})

	var npc_select := gm_panel.get("_formal_action_npc_select") as OptionButton
	var location_select := gm_panel.get("_formal_action_location_select") as OptionButton
	if not _select_id(npc_select, NPC_ID) or not _select_id(location_select, FIRST_TARGET_ID):
		_fail("Could not select the GM visit NPC and target")
		return

	var visit_started_before := _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_started")
	var visit_completed_before := _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_completed")
	var chapel_entered_before := _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_entered", FIRST_TARGET_ID)
	gm_window.visible = true
	run_button.pressed.emit()
	await process_frame
	var pending: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var departure_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		gm_window.visible
		or str(pending.get("phase", "")) != "pending"
		or not bool(pending.get("options", {}).get("formal_location_authority", false))
		or not bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", false))
		or str(departure_state.get("current_location", "")) != "plaza"
		or absf(npc_node.global_position.x) > 80.0
		or absf(npc_node.global_position.z) > 100.0
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_started") != visit_started_before
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_entered", FIRST_TARGET_ID) != chapel_entered_before
	):
		_fail("GM visit departure did not remain a real pending route")
		return

	# Pausing while still on the formal route must freeze the body and must not
	# let a large logical tick start or finish the visit in the background.
	for _frame in range(20):
		await physics_frame
	var paused_position: Vector3 = npc_node.global_position
	time_system.set_paused(true)
	for _frame in range(30):
		await physics_frame
	action_system._on_logical_time_tick(7200.0, 1.0)
	if (
		npc_node.global_position.distance_to(paused_position) > 0.001
		or str(action_system.get_runtime_action_snapshot(NPC_ID).get("phase", "")) != "pending"
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_started") != visit_started_before
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_completed") != visit_completed_before
	):
		_fail("Paused formal visit drifted or advanced in the background")
		return

	time_system.set_paused(false)
	if not await _wait_for_active(action_system, time_system, FIRST_TARGET_ID):
		_fail("NPC did not physically reach the chapel: %s" % JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID)))
		return
	var active_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var active_spatial: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	var formal_target_position: Vector3 = npc_node.global_position
	if (
		str(active_state.get("current_location", "")) != FIRST_TARGET_ID
		or str(active_state.get("current_workstation_id", "")) != ""
		or str(active_state.get("physical_location_phase", "")) != "interior"
		or not (active_spatial.get("reservation", {}) as Dictionary).is_empty()
		or not (active_spatial.get("occupancy", {}) as Dictionary).is_empty()
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_started") != visit_started_before + 1
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_entered", FIRST_TARGET_ID) != chapel_entered_before + 1
	):
		_fail("Physical chapel arrival did not atomically start the workstation-free visit")
		return

	var chapel_exited_before_completion := _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_exited", FIRST_TARGET_ID)
	var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	action_system._on_logical_time_tick(float(runtime.get("duration_seconds", 3600.0)) + 1.0, 1.0)
	await process_frame
	await physics_frame
	var completed_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		str(action_system.get_runtime_action_snapshot(NPC_ID).get("phase", "")) != ""
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or str(completed_state.get("current_location", "")) != FIRST_TARGET_ID
		or str(completed_state.get("physical_location_phase", "")) != "formal_location_interior"
		or npc_node.global_position.distance_to(formal_target_position) > 0.5
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_completed") != visit_completed_before + 1
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_entered", FIRST_TARGET_ID) != chapel_entered_before + 1
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_exited", FIRST_TARGET_ID) != chapel_exited_before_completion
	):
		_fail("Visit completion did not preserve the target's formal location")
		return

	# Starting a second visit from an interior location must place the body at
	# that formal interior, then physically cross its exit before entering the
	# next building. It must not reset the logical location to plaza on dispatch.
	if not _select_id(location_select, SECOND_TARGET_ID):
		_fail("Could not select the second visit target")
		return
	var chapel_exited_before_second := _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_exited", FIRST_TARGET_ID)
	var dining_entered_before := _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_entered", SECOND_TARGET_ID)
	gm_window.visible = true
	run_button.pressed.emit()
	await process_frame
	if (
		str(npc_system.get_npc_state(NPC_ID).get("current_location", "")) != FIRST_TARGET_ID
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_exited", FIRST_TARGET_ID) != chapel_exited_before_second
	):
		_fail("Indoor-to-indoor visit committed a fake plaza transition on dispatch")
		return
	if not await _wait_for_active(action_system, time_system, SECOND_TARGET_ID):
		_fail("NPC did not physically complete the chapel-to-dining-hall route")
		return
	if (
		str(npc_system.get_npc_state(NPC_ID).get("current_location", "")) != SECOND_TARGET_ID
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_exited", FIRST_TARGET_ID) != chapel_exited_before_second + 1
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_entered", SECOND_TARGET_ID) != dining_entered_before + 1
	):
		_fail("Indoor-to-indoor route did not commit one physical exit and one physical entry")
		return

	gm_window.visible = true
	stop_button.pressed.emit()
	await process_frame
	await physics_frame
	if (
		bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or str(npc_system.get_npc_state(NPC_ID).get("current_location", "")) != SECOND_TARGET_ID
		or str(npc_system.get_npc_state(NPC_ID).get("physical_location_phase", "")) != "formal_location_interior"
	):
		_fail("GM visit stop did not preserve the last physically committed location")
		return

	# Plaza is also a legal visit target. From an interior it must physically
	# cross the building exit and then reach the formal public-location marker.
	if not _select_id(location_select, PUBLIC_TARGET_ID):
		_fail("Could not select plaza as a visit target")
		return
	var dining_exited_before := _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_exited", SECOND_TARGET_ID)
	var plaza_entered_before := _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_entered", PUBLIC_TARGET_ID)
	gm_window.visible = true
	run_button.pressed.emit()
	await process_frame
	if not await _wait_for_active(action_system, time_system, PUBLIC_TARGET_ID):
		_fail("NPC did not physically reach the formal plaza visit marker")
		return
	if (
		str(npc_system.get_npc_state(NPC_ID).get("current_location", "")) != PUBLIC_TARGET_ID
		or str(npc_system.get_npc_state(NPC_ID).get("physical_location_phase", "")) != "formal_public_location"
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_exited", SECOND_TARGET_ID) != dining_exited_before + 1
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_entered", PUBLIC_TARGET_ID) != plaza_entered_before + 1
	):
		_fail("Formal plaza visit did not commit one physical building exit and public arrival")
		return
	gm_window.visible = true
	stop_button.pressed.emit()
	await process_frame
	await physics_frame
	if str(npc_system.get_npc_state(NPC_ID).get("current_location", "")) != PUBLIC_TARGET_ID:
		_fail("Stopping a plaza visit did not preserve plaza as the committed location")
		return

	# Replacing a still-pending destination must tear down the old formal route
	# before opening the new one. The superseded building must not receive any
	# logical visit/location event merely because it was the first target.
	npc_node.set("move_speed", 1.0)
	var visit_started_before_replacement := _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_started")
	var chapel_entered_before_replacement := _count_location_event(
		memory_system.get_npc_daily_events(NPC_ID),
		"location_entered",
		FIRST_TARGET_ID
	)
	if not action_system.assign_visit_location(NPC_ID, FIRST_TARGET_ID):
		_fail("Could not start the route that will be superseded")
		return
	await process_frame
	if not action_system.assign_visit_location(NPC_ID, SECOND_TARGET_ID):
		_fail("Could not replace the pending formal visit target")
		return
	await process_frame
	var replacement_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var replacement_session: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	if (
		str(replacement_runtime.get("phase", "")) != "pending"
		or str(replacement_runtime.get("target_id", "")) != SECOND_TARGET_ID
		or str(replacement_session.get("building_id", "")) != SECOND_TARGET_ID
		or str(npc_system.get_npc_state(NPC_ID).get("current_location", "")) != PUBLIC_TARGET_ID
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_started") != visit_started_before_replacement
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_entered", FIRST_TARGET_ID) != chapel_entered_before_replacement
	):
		_fail("Pending visit target replacement leaked the superseded destination")
		return
	npc_node.set("move_speed", 10.0)
	if not await _wait_for_active(action_system, time_system, SECOND_TARGET_ID):
		_fail("Replacement visit did not physically reach the new destination")
		return
	if (
		str(npc_system.get_npc_state(NPC_ID).get("current_location", "")) != SECOND_TARGET_ID
		or _count_location_event(memory_system.get_npc_daily_events(NPC_ID), "location_entered", FIRST_TARGET_ID) != chapel_entered_before_replacement
	):
		_fail("Replacement visit committed the superseded chapel route")
		return
	action_system.interrupt_npc_action(NPC_ID, "verify_replacement_complete", true)
	await process_frame
	if not action_system.assign_visit_location(NPC_ID, PUBLIC_TARGET_ID):
		_fail("Could not start the return-to-plaza route after target replacement")
		return
	if not await _wait_for_active(action_system, time_system, PUBLIC_TARGET_ID):
		_fail("NPC did not return to plaza after target replacement verification")
		return
	action_system.interrupt_npc_action(NPC_ID, "verify_returned_to_plaza", true)
	await process_frame

	# Invalidating the destination while the NPC is still travelling must fail
	# the pending action and release the formal session without a visit start.
	if not _select_id(location_select, FIRST_TARGET_ID):
		_fail("Could not restore chapel as the invalidation target")
		return
	npc_node.set("move_speed", 1.0)
	var visit_started_before_invalidation := _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_started")
	gm_window.visible = true
	run_button.pressed.emit()
	await process_frame
	var chapel_before_damage: Dictionary = building_system.get_building(FIRST_TARGET_ID)
	building_system.debug_damage_building(FIRST_TARGET_ID, int(chapel_before_damage.get("max_hp", 100)))
	await process_frame
	await physics_frame
	var invalidated_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		not str(action_system.get_runtime_action_id(NPC_ID)).is_empty()
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or str(invalidated_state.get("current_location", "")) != PUBLIC_TARGET_ID
		or not str(invalidated_state.get("last_action_result", "")).contains("visit_location_failed_building")
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "visit_started") != visit_started_before_invalidation
	):
		_fail("Destination invalidation started a fake visit or left formal authority behind")
		return
	snapshot_button.pressed.emit()

	print("T0129C A5-P6b formal visit_location verification passed")
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _select_id(select: OptionButton, expected_id: String) -> bool:
	if select == null:
		return false
	for index in range(select.item_count):
		if str(select.get_item_metadata(index)) == expected_id:
			select.select(index)
			return true
	return false


func _wait_for_active(
	action_system: Node,
	time_system: Node,
	expected_location_id: String,
	max_frames: int = 2400
) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
		if (
			str(runtime.get("phase", "")) == "active"
			and str(runtime.get("action_id", "")) == ACTION_ID
			and str(runtime.get("target_id", "")) == expected_location_id
		):
			return true
	return false


func _count_event(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str(raw_event.get("type", "")) == event_type:
			count += 1
	return count


func _count_location_event(events: Array, event_type: String, location_id: String) -> int:
	var count := 0
	for raw_event in events:
		if not raw_event is Dictionary or str(raw_event.get("type", "")) != event_type:
			continue
		var payload: Dictionary = raw_event.get("payload", {}) if raw_event.get("payload", {}) is Dictionary else {}
		var event_location_id := (
			str(payload.get("to_location_id", ""))
			if event_type == "location_entered"
			else str(payload.get("from_location_id", ""))
		)
		if event_location_id == location_id:
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
