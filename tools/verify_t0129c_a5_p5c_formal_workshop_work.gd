extends SceneTree

const NPC_ID := "engineer_01"
const BUILDING_ID := "workshop"
const ACTION_ID := "work_workshop"
const FIRST_WORKBENCH_ID := "workbench_01"


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
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var station_layout_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var formal_button := gm_window.find_child("FormalWorkshopWorkButton", true, false) as Button if gm_window != null else null
	var owen := _get_npc_node(npc_system, NPC_ID) if npc_system != null else null
	var navigation_agent := owen.get_node_or_null("NavigationAgent3D") as NavigationAgent3D if owen != null else null
	if [action_system, npc_system, building_system, crafting_system, resource_system, daily_plan_system, time_system, station_layout_controller, gm_window, formal_button, owen, navigation_agent].has(null):
		_fail("A5-P5c runtime dependencies unavailable")
		return

	time_system.set_paused(false)
	time_system.set_current_time(1, 7, 2, 0)
	daily_plan_system.set_auto_execution_enabled(true)
	# Use the production movement contract: the diagonal 1.8 m doorway and the
	# close workbench approach are intentionally validated without test-only speed.
	owen.set("move_speed", 5.0)
	resource_system.add_resource("wood", 40)
	resource_system.add_resource("iron", 40)

	var action: Dictionary = action_system.get_action(ACTION_ID)
	if not bool(action.get("formal_spatial_route", false)):
		_fail("work_workshop is not configured for formal spatial authority")
		return
	crafting_system.set_target(BUILDING_ID, "", true)
	if action_system.debug_assign_work(NPC_ID, BUILDING_ID):
		_fail("Missing workshop target should fail before formal migration")
		return
	if bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", false)) or not _workstation_is_clear(building_system):
		_fail("Workshop preflight left a formal session or workstation claim")
		return

	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": ACTION_ID,
			"reason": "A5-P5c formal workshop verification",
			"source": "verify_t0129c_a5_p5c"
		})
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, plan, false, "verify_t0129c_a5_p5c"):
		_fail("Could not install Owen's repeatable workshop plan")
		return

	gm_window.visible = true
	formal_button.pressed.emit()
	await process_frame
	var project_before: Dictionary = crafting_system.get_project_snapshot(BUILDING_ID)
	var recipe_id := str(project_before.get("target_recipe_id", ""))
	var stage_cost: Dictionary = (project_before.get("current_stage_cost", {}) as Dictionary).duplicate(true)
	var resources_before := _resource_snapshot(resource_system, stage_cost)
	var pending: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	if recipe_id.is_empty() or not bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", false)):
		_fail("One-click workshop start did not select a target and create a formal session")
		return
	if gm_window.visible or not owen.visible or absf(owen.global_position.x) > 80.0 or absf(owen.global_position.z) > 100.0:
		_fail("Successful workshop dispatch did not reveal Owen in the formal world")
		return
	if str(pending.get("phase", "")) != "pending" or not _workstation_reserved_by(building_system, NPC_ID):
		_fail("Workshop travel did not remain reservation-only pending work")
		return
	var pending_art: Dictionary = owen.debug_get_character_art_snapshot()
	if str(pending_art.get("desired_state", "")) == "work" or bool(pending_art.get("engineer_wrench_visible", false)) or str(pending_art.get("engineer_goggles_mode", "")) != "forehead":
		_fail("Owen started assembly presentation before reaching the workbench")
		return
	if not _resource_snapshot_matches(resource_system, resources_before):
		_fail("Workshop travel consumed stage materials before arrival")
		return

	if not await _wait_for_active(action_system, time_system):
		_fail("Owen did not reach the engineering workbench: %s" % JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID)))
		return
	await create_timer(0.18).timeout
	var state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var art: Dictionary = owen.debug_get_character_art_snapshot()
	if (
		str(state.get("current_location", "")) != BUILDING_ID
		or str(state.get("current_workstation_id", "")) != FIRST_WORKBENCH_ID
		or not _workstation_occupied_by(building_system, NPC_ID)
	):
		_fail("Arrival did not atomically commit Owen to workbench_01")
		return
	var workbench_route: Dictionary = station_layout_controller.get_building_spatial_route(BUILDING_ID, FIRST_WORKBENCH_ID)
	var stand_position: Vector3 = workbench_route.get("interior_target_position", Vector3.ZERO)
	var bench_center_position: Vector3 = stand_position + (workbench_route.get("interior_target_facing_direction", Vector3.ZERO) as Vector3) * 1.1
	var stand_to_bench_center := stand_position.distance_to(bench_center_position)
	if (
		absf(stand_to_bench_center - 1.1) > 0.01
		or owen.global_position.distance_to(stand_position) > 0.3
		or absf(navigation_agent.target_desired_distance - 0.25) > 0.001
	):
		_fail("Owen is not using the close no-overlap engineering stand: %s" % JSON.stringify({
			"stand_to_bench_center": stand_to_bench_center,
			"arrival_delta": owen.global_position.distance_to(stand_position),
			"target_desired_distance": navigation_agent.target_desired_distance,
			"owen": owen.global_position,
			"stand": stand_position,
			"bench": bench_center_position
		}))
		return
	if (
		str(art.get("appearance_id", "")) != "owen_engineer_chibi_v1"
		or str(art.get("desired_state", "")) != "work"
		or float(art.get("work_cycle_length", 0.0)) <= 0.0
		or int(art.get("work_clip_loop_mode", 0)) == 0
		or bool(art.get("hammer_visible", true))
		or not bool(art.get("engineer_wrench_visible", false))
		or str(art.get("engineer_goggles_mode", "")) != "worn"
	):
		_fail("Owen's looping engineering presentation is not active: %s" % JSON.stringify(art))
		return

	# A direct GM dispatch is a visual acceptance action, not a replacement for
	# Owen's daily plan. Restart through the real plan executor before checking
	# repeat_while_planned session reuse.
	action_system.interrupt_npc_action(NPC_ID, "verify_restart_through_daily_plan", true)
	await process_frame
	var production_recipe_id := "craft_wall_ballista"
	var selected: Dictionary = crafting_system.set_target(BUILDING_ID, production_recipe_id, true)
	if not bool(selected.get("ok", false)):
		_fail("Could not select the multi-stage workshop project: %s" % JSON.stringify(selected))
		return
	var production_project: Dictionary = crafting_system.get_project_snapshot(BUILDING_ID)
	stage_cost = (production_project.get("current_stage_cost", {}) as Dictionary).duplicate(true)
	resources_before = _resource_snapshot(resource_system, stage_cost)
	var dispatch: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(dispatch.get("ok", false)) or not await _wait_for_active(action_system, time_system):
		_fail("Owen's planned workshop cycle did not become active: %s" % JSON.stringify(dispatch))
		return
	var first_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var first_session: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	var first_position: Vector3 = owen.global_position
	action_system._on_logical_time_tick(float(first_runtime.get("duration_seconds", 5400.0)) + 1.0, 1.0)
	for _frame in range(5):
		await process_frame
	var one_stage: Dictionary = crafting_system.get_project_snapshot(BUILDING_ID)
	if int(one_stage.get("completed_stages", -1)) != 1 or not _stage_cost_was_committed(resource_system, resources_before, stage_cost):
		_fail("One active engineering cycle did not commit exactly one authoritative stage")
		return
	if not await _wait_for_active(action_system, time_system, 120):
		_fail("Planned workshop manufacturing did not start its next cycle")
		return
	var repeated: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var repeated_session: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	if (
		str(repeated.get("phase", "")) != "active"
		or str(repeated.get("workstation_id", "")) != FIRST_WORKBENCH_ID
		or int(repeated_session.get("session_id", -1)) != int(first_session.get("session_id", -2))
		or owen.global_position.distance_to(first_position) > 0.1
		or not _workstation_occupied_by(building_system, NPC_ID)
	):
		_fail("Repeatable workshop manufacturing replayed the door route or changed workbenches: %s" % JSON.stringify({
			"runtime": repeated,
			"first_session": first_session,
			"repeated_session": repeated_session,
			"position_delta": owen.global_position.distance_to(first_position),
			"formal": npc_system.get_formal_workstation_action_snapshot(NPC_ID),
			"workstation": _first_workstation(building_system)
		}))
		return

	var next_recipe_id := _find_other_recipe(crafting_system, production_recipe_id)
	if next_recipe_id.is_empty():
		_fail("No second workshop recipe exists for cleanup verification")
		return
	var switched: Dictionary = crafting_system.set_target(BUILDING_ID, next_recipe_id, true)
	await process_frame
	if (
		not bool(switched.get("ok", false))
		or not (switched.get("interrupted_npc_ids", []) as Array).has(NPC_ID)
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or not _workstation_is_clear(building_system)
		or str(npc_system.get_npc_state(NPC_ID).get("physical_location_phase", "")) != "formal_location_interior"
	):
		_fail("Workshop target switch did not retain clean formal authority: %s" % JSON.stringify(switched))
		return
	owen.move_to_location("verify_default_tolerance_restore", owen.global_position + Vector3(1.0, 0.0, 0.0))
	if absf(navigation_agent.target_desired_distance - 0.25) > 0.001:
		_fail("Engineering final-step tolerance leaked into the next ordinary move: %s" % navigation_agent.target_desired_distance)
		return
	owen.stop_movement()

	print("T0129C A5-P5c formal workshop work verification passed")
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_active(action_system: Node, time_system: Node, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		if str(action_system.get_runtime_action_snapshot(NPC_ID).get("phase", "")) == "active":
			return true
	return false


func _find_other_recipe(crafting_system: Node, current_recipe_id: String) -> String:
	for raw_recipe_id in crafting_system.get_recipe_ids_for_building(BUILDING_ID):
		var recipe_id := str(raw_recipe_id)
		if recipe_id != current_recipe_id:
			return recipe_id
	return ""


func _resource_snapshot(resource_system: Node, costs: Dictionary) -> Dictionary:
	var result := {}
	for raw_id in costs.keys():
		var resource_id := str(raw_id)
		result[resource_id] = int(resource_system.get_resource(resource_id))
	return result


func _resource_snapshot_matches(resource_system: Node, expected: Dictionary) -> bool:
	for raw_id in expected.keys():
		var resource_id := str(raw_id)
		if int(resource_system.get_resource(resource_id)) != int(expected[resource_id]):
			return false
	return true


func _stage_cost_was_committed(resource_system: Node, before: Dictionary, cost: Dictionary) -> bool:
	for raw_id in cost.keys():
		var resource_id := str(raw_id)
		if int(resource_system.get_resource(resource_id)) != int(before.get(resource_id, 0)) - int(cost[resource_id]):
			return false
	return true


func _workstation_reserved_by(building_system: Node, npc_id: String) -> bool:
	var workstation := _first_workstation(building_system)
	var occupied_by: Variant = workstation.get("occupied_by")
	return str(workstation.get("reserved_by", "")) == npc_id and (occupied_by == null or str(occupied_by).is_empty())


func _workstation_occupied_by(building_system: Node, npc_id: String) -> bool:
	var workstation := _first_workstation(building_system)
	var reserved_by: Variant = workstation.get("reserved_by")
	return str(workstation.get("occupied_by", "")) == npc_id and (reserved_by == null or str(reserved_by).is_empty())


func _workstation_is_clear(building_system: Node) -> bool:
	var workstation := _first_workstation(building_system)
	var occupied_by: Variant = workstation.get("occupied_by")
	var reserved_by: Variant = workstation.get("reserved_by")
	return (occupied_by == null or str(occupied_by).is_empty()) and (reserved_by == null or str(reserved_by).is_empty())


func _first_workstation(building_system: Node) -> Dictionary:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		var workstation: Dictionary = raw_workstation
		if str(workstation.get("id", "")) == FIRST_WORKBENCH_ID:
			return workstation
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
