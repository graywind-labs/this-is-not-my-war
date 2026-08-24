extends SceneTree

const NPC_ID := "cook_01"
const BUILDING_ID := "dining_hall"
const ACTION_ID := "work_dining_hall"
const FIRST_STATION_ID := "dining_kitchen_station_01"


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
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var formal_button := gm_window.find_child("FormalDiningWorkButton", true, false) as Button if gm_window != null else null
	var bruno := _get_npc_node(npc_system, NPC_ID) if npc_system != null else null
	if [action_system, npc_system, building_system, resource_system, daily_plan_system, time_system, gm_window, formal_button, bruno].has(null):
		_fail("A5-P5d runtime dependencies unavailable")
		return

	time_system.set_paused(false)
	time_system.set_current_time(1, 7, 2, 0)
	daily_plan_system.set_auto_execution_enabled(true)
	bruno.set("move_speed", 5.0)
	resource_system.add_resource("grain", -resource_system.get_resource("grain"))
	resource_system.add_resource("meal", -resource_system.get_resource("meal"))
	npc_system.update_npc_state(NPC_ID, {
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_a5_p5d_ready"
	})

	var action: Dictionary = action_system.get_action(ACTION_ID)
	if not bool(action.get("formal_spatial_route", false)):
		_fail("work_dining_hall is not configured for formal spatial authority")
		return

	# The visible GM entry must reject a missing ingredient before it reveals the
	# formal world, reserves a stove, or starts physical migration.
	gm_window.visible = true
	formal_button.pressed.emit()
	await process_frame
	if (
		not gm_window.visible
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", false))
		or not _workstation_is_clear(building_system, FIRST_STATION_ID)
		or not action_system.get_runtime_action_snapshot(NPC_ID).is_empty()
	):
		_fail("Missing grain was not rejected before formal dining-hall migration")
		return

	if not resource_system.add_resource("grain", 20):
		_fail("Could not prepare grain for formal dining-hall verification")
		return
	var travel_grain: int = int(resource_system.get_resource("grain"))
	formal_button.pressed.emit()
	await process_frame
	var pending: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	if (
		gm_window.visible
		or not bruno.visible
		or bruno.global_position.x < 900.0
		or str(pending.get("phase", "")) != "pending"
		or not _workstation_reserved_by(building_system, FIRST_STATION_ID, NPC_ID)
		or resource_system.get_resource("grain") != travel_grain
	):
		_fail("One-click dining work did not create a reservation-only visible route")
		return

	if not await _wait_for_active(action_system, time_system):
		_fail("Bruno did not reach the first kitchen station: %s" % JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID)))
		return
	await create_timer(0.18).timeout
	var state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var art: Dictionary = bruno.debug_get_character_art_snapshot()
	if (
		str(state.get("current_location", "")) != BUILDING_ID
		or str(state.get("current_workstation_id", "")) != FIRST_STATION_ID
		or str(state.get("physical_location_phase", "")) != "workstation"
		or not _workstation_occupied_by(building_system, FIRST_STATION_ID, NPC_ID)
	):
		_fail("Arrival did not atomically commit Bruno to dining_kitchen_station_01")
		return
	if (
		str(art.get("appearance_id", "")) != "bruno_cook_chibi_v1"
		or str(art.get("desired_state", "")) != "work"
		or str(art.get("current_clip", "")) != "Working_C"
		or float(art.get("work_cycle_length", 0.0)) <= 0.0
		or int(art.get("work_clip_loop_mode", 0)) == 0
		or not bool(art.get("cook_spoon_visible", false))
		or bool(art.get("hammer_visible", true))
	):
		_fail("Bruno's hammer-free looping cooking presentation is not active: %s" % JSON.stringify(art))
		return
	if resource_system.get_resource("grain") != travel_grain:
		_fail("Dining work spent grain before a complete production cycle")
		return

	# A GM click is a visible one-shot entry. Restart through the real daily plan
	# before validating repeat_while_planned and authoritative production.
	action_system.interrupt_npc_action(NPC_ID, "verify_restart_through_daily_plan", true)
	await process_frame
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": ACTION_ID,
			"reason": "A5-P5d formal dining work verification",
			"source": "verify_t0129c_a5_p5d"
		})
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, plan, false, "verify_t0129c_a5_p5d"):
		_fail("Could not install Bruno's repeatable dining-hall plan")
		return
	var dispatch: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(dispatch.get("ok", false)) or not await _wait_for_active(action_system, time_system):
		_fail("Bruno's planned dining work did not become active: %s" % JSON.stringify(dispatch))
		return

	var first_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var first_session: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	var first_position: Vector3 = bruno.global_position
	var grain_before: int = int(resource_system.get_resource("grain"))
	var meal_before: int = int(resource_system.get_resource("meal"))
	action_system._on_logical_time_tick(float(first_runtime.get("duration_seconds", 3600.0)) + 1.0, 1.0)
	for _frame in range(5):
		await process_frame
	if (
		resource_system.get_resource("grain") != grain_before - 1
		or resource_system.get_resource("meal") != meal_before + 2
	):
		_fail("One active cooking cycle did not atomically convert 1 grain into 2 meals")
		return
	if not await _wait_for_active(action_system, time_system, 120):
		_fail("Planned dining production did not start its next cycle")
		return
	var repeated: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var repeated_session: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	if (
		str(repeated.get("workstation_id", "")) != FIRST_STATION_ID
		or int(repeated_session.get("session_id", -1)) != int(first_session.get("session_id", -2))
		or bruno.global_position.distance_to(first_position) > 0.1
		or not _workstation_occupied_by(building_system, FIRST_STATION_ID, NPC_ID)
	):
		_fail("Repeatable cooking replayed the door route or changed kitchen stations")
		return

	if not action_system.interrupt_npc_action(NPC_ID, "verify_formal_dining_stop", true):
		_fail("Could not interrupt the formal dining-hall cycle")
		return
	await process_frame
	if (
		bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or not _workstation_is_clear(building_system, FIRST_STATION_ID)
		or str(npc_system.get_npc_state(NPC_ID).get("physical_location_phase", "")) != "formal_location_interior"
	):
		_fail("Dining interruption did not release the stove while retaining formal authority")
		return

	print("T0129C A5-P5d formal dining work verification passed")
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
		var workstation: Dictionary = raw_workstation
		if str(workstation.get("id", "")) == workstation_id:
			return workstation
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
