extends SceneTree


const NPC_ID := "cook_01"
const BUILDING_ID := "dining_hall"
const ACTION_ID := "eat_at_dining_hall"
const FIRST_SEAT_ID := "dining_seat_01"


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
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var run_button := gm_window.find_child("FormalDiningEatButton", true, false) as Button if gm_window != null else null
	var stop_button := gm_window.find_child("FormalDiningEatStopButton", true, false) as Button if gm_window != null else null
	var bruno := _get_npc_node(npc_system, NPC_ID) if npc_system != null else null
	if [action_system, npc_system, building_system, resource_system, memory_system, daily_plan_system, time_system, gm_window, run_button, stop_button, bruno].has(null):
		_fail("A5-P5j runtime dependencies unavailable")
		return

	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(false)
	bruno.set("move_speed", 5.0)
	_clear_resource(resource_system, "meal")
	_clear_resource(resource_system, "grain")
	npc_system.update_npc_state(NPC_ID, {
		"fatigue": 0,
		"satiety": 30,
		"current_action": "idle",
		"last_action_result": "verify_a5_p5j_ready"
	})

	var action: Dictionary = action_system.get_action(ACTION_ID)
	if not bool(action.get("formal_spatial_route", false)):
		_fail("eat_at_dining_hall is not configured for formal spatial authority")
		return
	if _count_workstations(building_system, "dining_seat") != 10:
		_fail("Dining hall does not expose the expected ten fixed dining seats")
		return

	# Missing food must fail before the formal world, route, and seat reservation
	# are revealed. The visible GM button is used rather than a private shortcut.
	var eat_started_before := _count_event(memory_system.get_npc_daily_events(NPC_ID), "eat_started")
	gm_window.visible = true
	run_button.pressed.emit()
	await process_frame
	if (
		not gm_window.visible
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", false))
		or not action_system.get_runtime_action_snapshot(NPC_ID).is_empty()
		or not _workstation_is_clear(building_system, FIRST_SEAT_ID)
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "eat_started") != eat_started_before
	):
		_fail("Missing food was not rejected before formal dining migration")
		return

	resource_system.add_resource("meal", 2)
	resource_system.add_resource("grain", 2)
	var meal_before_travel := int(resource_system.get_resource("meal"))
	var grain_before_travel := int(resource_system.get_resource("grain"))
	var satiety_before_travel := int(npc_system.get_npc_state(NPC_ID).get("satiety", -1))
	run_button.pressed.emit()
	await process_frame
	var pending: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	if (
		gm_window.visible
		or str(pending.get("phase", "")) != "pending"
		or not _workstation_reserved_by(building_system, FIRST_SEAT_ID, NPC_ID)
		or int(resource_system.get_resource("meal")) != meal_before_travel
		or int(resource_system.get_resource("grain")) != grain_before_travel
		or int(npc_system.get_npc_state(NPC_ID).get("satiety", -1)) != satiety_before_travel
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "eat_started") != eat_started_before
	):
		_fail("Dining departure was not a reservation-only, zero-consumption route")
		return

	action_system._on_logical_time_tick(3600.0, 1.0)
	if (
		int(resource_system.get_resource("meal")) != meal_before_travel
		or int(npc_system.get_npc_state(NPC_ID).get("satiety", -1)) != satiety_before_travel
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "eat_started") != eat_started_before
	):
		_fail("Logical time consumed food or restored satiety while Bruno was still travelling")
		return

	if not await _wait_for_active(action_system, time_system):
		_fail("Bruno did not reach dining_seat_01: %s" % JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID)))
		return
	await create_timer(0.18).timeout
	var active_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var attachment: Dictionary = bruno.debug_get_spatial_attachment_snapshot()
	var art: Dictionary = bruno.debug_get_character_art_snapshot()
	if (
		int(resource_system.get_resource("meal")) != meal_before_travel - 1
		or int(resource_system.get_resource("grain")) != grain_before_travel
		or int(active_state.get("satiety", -1)) < satiety_before_travel
		or int(active_state.get("satiety", -1)) >= 80
		or str(active_state.get("current_workstation_id", "")) != FIRST_SEAT_ID
		or str(active_state.get("physical_location_phase", "")) != "occupant_anchor"
		or not _workstation_occupied_by(building_system, FIRST_SEAT_ID, NPC_ID)
		or not bool(attachment.get("active", false))
		or str(attachment.get("pose", "")) != "sitting"
		or not bool(attachment.get("body_collision_disabled", false))
		or str(art.get("desired_state", "")) != "seated_eating"
		or int(art.get("seated_eating_clip_loop_mode", 0)) == 0
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "eat_started") != eat_started_before + 1
	):
		print("A5-P5j active flags: %s" % JSON.stringify({
			"meal": resource_system.get_resource("meal"),
			"grain": resource_system.get_resource("grain"),
			"satiety": active_state.get("satiety"),
			"station": _get_workstation(building_system, FIRST_SEAT_ID),
			"attachment": attachment,
			"desired_state": art.get("desired_state"),
			"loop_mode": art.get("seated_eating_clip_loop_mode"),
			"eat_started": _count_event(memory_system.get_npc_daily_events(NPC_ID), "eat_started"),
			"eat_started_before": eat_started_before
		}))
		_fail("Seat attachment did not atomically start meal consumption and seated eating: %s" % JSON.stringify({
			"state_summary": {
				"satiety": active_state.get("satiety"),
				"current_workstation_id": active_state.get("current_workstation_id"),
				"physical_location_phase": active_state.get("physical_location_phase")
			},
			"attachment": attachment,
			"art": art,
			"workstation": _get_workstation(building_system, FIRST_SEAT_ID),
			"eat_started_count": _count_event(memory_system.get_npc_daily_events(NPC_ID), "eat_started"),
			"eat_started_before": eat_started_before,
			"meal": resource_system.get_resource("meal"),
			"grain": resource_system.get_resource("grain")
		}))
		return

	var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	action_system._on_logical_time_tick(float(runtime.get("duration_seconds", 1200.0)) + 1.0, 1.0)
	await process_frame
	await physics_frame
	var completed_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var detached: Dictionary = bruno.debug_get_spatial_attachment_snapshot()
	if (
		int(completed_state.get("satiety", -1)) != 80
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or not _workstation_is_clear(building_system, FIRST_SEAT_ID)
		or str(completed_state.get("physical_location_phase", "")) != "formal_location_interior"
		or bool(detached.get("active", false))
		or bool(detached.get("body_collision_disabled", false))
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "eat_completed") < 1
	):
		_fail("Meal completion did not restore satiety, seat, collision, and legacy authority")
		return

	# Meal is preferred. When it is absent, grain is consumed only after the same
	# physical arrival; interruption clears the occupant without granting satiety.
	_clear_resource(resource_system, "meal")
	_clear_resource(resource_system, "grain")
	resource_system.add_resource("grain", 2)
	npc_system.update_npc_state(NPC_ID, {"satiety": 30, "current_action": "idle"})
	gm_window.visible = true
	run_button.pressed.emit()
	await process_frame
	var grain_before_arrival := int(resource_system.get_resource("grain"))
	if grain_before_arrival != 2 or not await _wait_for_active(action_system, time_system):
		_fail("Grain fallback did not reach a real dining seat")
		return
	if int(resource_system.get_resource("grain")) != grain_before_arrival - 1:
		_fail("Grain fallback did not consume exactly one grain after arrival")
		return
	var satiety_before_stop := int(npc_system.get_npc_state(NPC_ID).get("satiety", -1))
	stop_button.pressed.emit()
	await process_frame
	await physics_frame
	if (
		int(npc_system.get_npc_state(NPC_ID).get("satiety", -1)) != satiety_before_stop
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or not _workstation_is_clear(building_system, FIRST_SEAT_ID)
		or bool(bruno.debug_get_spatial_attachment_snapshot().get("body_collision_disabled", false))
	):
		print("A5-P5j stop flags: %s" % JSON.stringify({
			"satiety": npc_system.get_npc_state(NPC_ID).get("satiety"),
			"formal_active": npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active"),
			"seat": _get_workstation(building_system, FIRST_SEAT_ID),
			"attachment": bruno.debug_get_spatial_attachment_snapshot()
		}))
		_fail("GM interruption granted satiety or left the dining occupant/session dirty: %s" % JSON.stringify({
			"state": npc_system.get_npc_state(NPC_ID),
			"formal": npc_system.get_formal_workstation_action_snapshot(NPC_ID),
			"seat": _get_workstation(building_system, FIRST_SEAT_ID),
			"attachment": bruno.debug_get_spatial_attachment_snapshot()
		}))
		return

	print("T0129C A5-P5j formal dining eat verification passed")
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_active(action_system: Node, time_system: Node, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == ACTION_ID:
			return true
	return false


func _clear_resource(resource_system: Node, resource_id: String) -> void:
	var current := int(resource_system.get_resource(resource_id))
	if current > 0:
		resource_system.add_resource(resource_id, -current)


func _count_workstations(building_system: Node, workstation_type: String) -> int:
	var count := 0
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("type", "")) == workstation_type:
			count += 1
	return count


func _count_event(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str(raw_event.get("type", "")) == event_type:
			count += 1
	return count


func _workstation_reserved_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	var workstation := _get_workstation(building_system, workstation_id)
	var occupied_by: Variant = workstation.get("occupied_by")
	return str(workstation.get("reserved_by", "")) == npc_id and (occupied_by == null or str(occupied_by).is_empty())


func _workstation_occupied_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	var workstation := _get_workstation(building_system, workstation_id)
	var reserved_by: Variant = workstation.get("reserved_by")
	return str(workstation.get("occupied_by", "")) == npc_id and (reserved_by == null or str(reserved_by).is_empty())


func _workstation_is_clear(building_system: Node, workstation_id: String) -> bool:
	var workstation := _get_workstation(building_system, workstation_id)
	var occupied_by: Variant = workstation.get("occupied_by")
	var reserved_by: Variant = workstation.get("reserved_by")
	return (occupied_by == null or str(occupied_by).is_empty()) and (reserved_by == null or str(reserved_by).is_empty())


func _get_workstation(building_system: Node, workstation_id: String) -> Dictionary:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("id", "")) == workstation_id:
			return raw_workstation
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
