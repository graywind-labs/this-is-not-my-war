extends SceneTree

const NPC_ID := "blacksmith_01"
const BUILDING_ID := "blacksmith"
const ACTION_ID := "work_blacksmith"
const FIRST_FORGE_ID := "forge_01"
const RECIPE_ID := "craft_iron_helmet"

var _failed := false


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn unavailable")
		return
	var main := main_scene.instantiate()
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
	var glen := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Blacksmith01") as CharacterBody3D
	if [action_system, npc_system, building_system, crafting_system, resource_system, daily_plan_system, time_system, glen].has(null):
		_fail("A5-P5b runtime dependencies unavailable")
		return
	time_system.set_paused(false)
	time_system.set_current_time(1, 7, 2, 0)
	daily_plan_system.set_auto_execution_enabled(true)
	glen.set("move_speed", 40.0)

	var action: Dictionary = action_system.get_action(ACTION_ID)
	if not bool(action.get("formal_spatial_route", false)):
		_fail("work_blacksmith is not configured for formal spatial authority")
		return

	crafting_system.set_target(BUILDING_ID, "", true)
	npc_system.update_npc_state(NPC_ID, {
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_a5_p5b_preflight"
	})
	if action_system.debug_assign_work(NPC_ID, BUILDING_ID):
		_fail("Missing crafting target should fail before a formal route starts")
		return
	if (
		bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", false))
		or not _workstation_is_clear(building_system, FIRST_FORGE_ID)
		or str(npc_system.get_npc_state(NPC_ID).get("last_action_result", "")) != "work_failed_crafting_target_missing"
	):
		_fail("Crafting preflight changed spatial authority or lost the failure reason")
		return

	resource_system.add_resource("iron", 10)
	resource_system.add_resource("wood", 10)
	var selected: Dictionary = crafting_system.set_target(BUILDING_ID, RECIPE_ID, true)
	if not bool(selected.get("ok", false)):
		_fail("Could not select the iron helmet project: %s" % JSON.stringify(selected))
		return
	var project_before: Dictionary = crafting_system.get_project_snapshot(BUILDING_ID)
	var stage_cost: Dictionary = (project_before.get("current_stage_cost", {}) as Dictionary).duplicate(true)
	var resources_before := _resource_snapshot(resource_system, stage_cost)

	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": ACTION_ID,
			"reason": "A5-P5b formal blacksmith work verification",
			"source": "verify_t0129c_a5_p5b"
		})
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, plan, false, "verify_t0129c_a5_p5b"):
		_fail("Could not install Glen's repeatable blacksmith plan")
		return
	var dispatch: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(dispatch.get("ok", false)):
		_fail("Glen's formal blacksmith action did not dispatch: %s" % JSON.stringify(dispatch))
		return
	var pending_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	if str(pending_runtime.get("phase", "")) != "pending" or not _workstation_reserved_by(building_system, FIRST_FORGE_ID, NPC_ID):
		_fail("Formal blacksmith route did not begin as reservation-only pending work")
		return
	if not _resource_snapshot_matches(resource_system, resources_before):
		_fail("Pending travel consumed crafting materials before stage commit")
		return

	if not await _wait_for_active_work(action_system, time_system):
		_fail("Glen did not reach the reserved forge: %s" % JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID)))
		return
	await create_timer(0.18).timeout
	var active_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var active_spatial: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	var active_art: Dictionary = glen.debug_get_character_art_snapshot()
	if (
		str(active_state.get("current_action", "")) != ACTION_ID
		or str(active_state.get("current_location", "")) != BUILDING_ID
		or str(active_spatial.get("physical_location_phase", "")) != "workstation"
		or str(active_spatial.get("current_workstation_id", "")) != FIRST_FORGE_ID
		or not _workstation_occupied_by(building_system, FIRST_FORGE_ID, NPC_ID)
	):
		_fail("Arrival did not atomically commit the forge and logical blacksmith location")
		return
	if (
		str(active_art.get("desired_state", "")) != "work"
		or float(active_art.get("work_cycle_length", 0.0)) <= 0.0
		or int(active_art.get("work_clip_loop_mode", 0)) == 0
		or not bool(active_art.get("hammer_visible", false))
		or str(active_art.get("hammer_parent", "")) != "RightHand"
	):
		_fail("Glen's visible looping smith animation is not active: %s" % JSON.stringify(active_art))
		return

	var first_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var first_session: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	var first_position: Vector3 = glen.global_position
	action_system._on_logical_time_tick(float(first_runtime.get("duration_seconds", 5400.0)) + 1.0, 1.0)
	for _frame in range(5):
		await process_frame
	var one_stage: Dictionary = crafting_system.get_project_snapshot(BUILDING_ID)
	if int(one_stage.get("completed_stages", -1)) != 1:
		_fail("One physically active cycle did not commit exactly one crafting stage: %s" % JSON.stringify(one_stage))
		return
	if not _stage_cost_was_committed(resource_system, resources_before, stage_cost):
		_fail("The completed stage did not consume exactly its authoritative material cost")
		return
	var repeated_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var repeated_session: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	if (
		str(repeated_runtime.get("phase", "")) != "active"
		or str(repeated_runtime.get("workstation_id", "")) != FIRST_FORGE_ID
		or int(repeated_session.get("started_at_msec", -1)) != int(first_session.get("started_at_msec", -2))
		or glen.global_position.distance_to(first_position) > 0.1
		or not _workstation_occupied_by(building_system, FIRST_FORGE_ID, NPC_ID)
	):
		_fail("Repeatable crafting replayed the door route or requested another forge: %s" % JSON.stringify(repeated_runtime))
		return

	var next_recipe_id := _find_other_blacksmith_recipe(crafting_system)
	if next_recipe_id.is_empty():
		_fail("No second blacksmith recipe exists for target-switch cleanup verification")
		return
	var switched: Dictionary = crafting_system.set_target(BUILDING_ID, next_recipe_id, true)
	await process_frame
	if (
		not bool(switched.get("ok", false))
		or not (switched.get("interrupted_npc_ids", []) as Array).has(NPC_ID)
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or not _workstation_is_clear(building_system, FIRST_FORGE_ID)
		or str(npc_system.get_npc_state(NPC_ID).get("physical_location_phase", "")) != "formal_location_interior"
	):
		_fail("Target switch did not clear the forge while retaining formal authority: %s" % JSON.stringify(switched))
		return

	print("T0129C A5-P5b formal blacksmith work verification passed")
	quit(0)


func _wait_for_active_work(action_system: Node, time_system: Node, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == ACTION_ID:
			return true
	return false


func _find_other_blacksmith_recipe(crafting_system: Node) -> String:
	for raw_recipe_id in crafting_system.get_recipe_ids_for_building(BUILDING_ID):
		var recipe_id := str(raw_recipe_id)
		if recipe_id != RECIPE_ID:
			return recipe_id
	return ""


func _resource_snapshot(resource_system: Node, costs: Dictionary) -> Dictionary:
	var result := {}
	for raw_resource_id in costs.keys():
		var resource_id := str(raw_resource_id)
		result[resource_id] = int(resource_system.get_resource(resource_id))
	return result


func _resource_snapshot_matches(resource_system: Node, expected: Dictionary) -> bool:
	for raw_resource_id in expected.keys():
		var resource_id := str(raw_resource_id)
		if int(resource_system.get_resource(resource_id)) != int(expected[resource_id]):
			return false
	return true


func _stage_cost_was_committed(resource_system: Node, before: Dictionary, cost: Dictionary) -> bool:
	for raw_resource_id in cost.keys():
		var resource_id := str(raw_resource_id)
		if int(resource_system.get_resource(resource_id)) != int(before.get(resource_id, 0)) - int(cost[resource_id]):
			return false
	return true


func _workstation_reserved_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		var workstation: Dictionary = raw_workstation
		if str(workstation.get("id", "")) == workstation_id:
			var occupied_by: Variant = workstation.get("occupied_by")
			return str(workstation.get("reserved_by", "")) == npc_id and (occupied_by == null or str(occupied_by).is_empty())
	return false


func _workstation_occupied_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		var workstation: Dictionary = raw_workstation
		if str(workstation.get("id", "")) == workstation_id:
			var reserved_by: Variant = workstation.get("reserved_by")
			return str(workstation.get("occupied_by", "")) == npc_id and (reserved_by == null or str(reserved_by).is_empty())
	return false


func _workstation_is_clear(building_system: Node, workstation_id: String) -> bool:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		var workstation: Dictionary = raw_workstation
		if str(workstation.get("id", "")) == workstation_id:
			var occupied_by: Variant = workstation.get("occupied_by")
			var reserved_by: Variant = workstation.get("reserved_by")
			return (occupied_by == null or str(occupied_by).is_empty()) and (reserved_by == null or str(reserved_by).is_empty())
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
