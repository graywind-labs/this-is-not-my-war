extends SceneTree

const GLEN_ID := "blacksmith_01"
const OWEN_ID := "engineer_01"
const WORK_ACTION_TYPES := ["work", "clinic_doctor", "clinic_patient", "training_instructor", "training_student"]

var _failed := false


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
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if [action_system, npc_system, building_system, crafting_system, resource_system, daily_plan_system, time_system, controller].has(null):
		_fail("T1505-P6R39 runtime dependencies unavailable")
		return
	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(false)
	controller.force_sync_production_navigation()

	if not _verify_all_formal_work_actions(action_system, building_system):
		return
	if not _verify_all_workstation_routes(controller, building_system):
		return
	if not _verify_excluded_workstation_selection(building_system):
		return
	if not await _verify_glen_arrival_failure(action_system, npc_system, building_system, crafting_system, time_system):
		return
	if not await _verify_owen_first_workbench(action_system, npc_system, building_system, crafting_system, resource_system, time_system):
		return

	print("T1505-P6R39 workstation arrival contract verification passed")
	quit(0)


func _verify_all_formal_work_actions(action_system: Node, building_system: Node) -> bool:
	var checked := 0
	for raw_action_id in action_system.get_action_ids():
		var action: Dictionary = action_system.get_action(str(raw_action_id))
		if str(action.get("type", "")) not in WORK_ACTION_TYPES:
			continue
		if not bool(action.get("formal_spatial_route", false)):
			_fail("Work action lacks formal spatial authority: %s" % raw_action_id)
			return false
		var building_id := str(action.get("location_required", ""))
		var workstation_type := str(action.get("workstation_type", ""))
		var matching_station := false
		for raw_workstation in building_system.get_building(building_id).get("workstations", []):
			if raw_workstation is Dictionary and str(raw_workstation.get("type", "")) == workstation_type:
				matching_station = true
				break
		if not matching_station:
			_fail("Formal work action has no matching workstation: %s" % raw_action_id)
			return false
		checked += 1
	if checked < 10:
		_fail("Formal work action audit covered too few actions: %s" % checked)
		return false
	return true


func _verify_all_workstation_routes(controller: Node, building_system: Node) -> bool:
	var station_keys := {}
	for raw_building_id in building_system.get_building_ids():
		var building_id := str(raw_building_id)
		for raw_workstation in building_system.get_building(building_id).get("workstations", []):
			if raw_workstation is Dictionary:
				station_keys["%s::%s" % [building_id, str(raw_workstation.get("id", ""))]] = true
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_fixture_layouts.json"))
	for raw_building_id in (layout.get("buildings", {}) as Dictionary).keys():
		var building_id := str(raw_building_id)
		var fixtures: Array = ((layout.get("buildings", {}) as Dictionary).get(building_id, {}) as Dictionary).get("fixtures", [])
		for raw_fixture in fixtures:
			if raw_fixture is Dictionary and not str(raw_fixture.get("workstation_id", "")).is_empty():
				station_keys["%s::%s" % [building_id, str(raw_fixture.get("workstation_id", ""))]] = true
	var nav: RID = controller.get_production_navigation_map_rid()
	var checked := 0
	for raw_key in station_keys.keys():
		var parts := str(raw_key).split("::", false, 1)
		var route: Dictionary = controller.get_building_spatial_route(parts[0], parts[1])
		if route.is_empty():
			_fail("Formal workstation route missing: %s" % raw_key)
			return false
		var start: Vector3 = route.get("interior_position", Vector3.ZERO)
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(nav, start, target, true)
		if path.is_empty():
			_fail("Formal workstation has no NavMesh path: %s" % raw_key)
			return false
		var endpoint: Vector3 = path[path.size() - 1]
		var endpoint_miss := Vector2(endpoint.x - target.x, endpoint.z - target.z).length()
		var desired_distance := float(route.get("target_desired_distance", 0.25))
		if endpoint_miss + 0.01 > desired_distance:
			_fail("Workstation arrival tolerance is tighter than its NavMesh endpoint: %s miss=%.4f desired=%.4f" % [raw_key, endpoint_miss, desired_distance])
			return false
		checked += 1
	if checked < 50:
		_fail("Formal workstation route audit covered too few current/future positions: %s" % checked)
		return false
	return true


func _verify_excluded_workstation_selection(building_system: Node) -> bool:
	var first: Dictionary = building_system.reserve_workstation("workshop", "route_retry_audit", "engineering")
	if not bool(first.get("ok", false)):
		_fail("Could not reserve first workshop station for retry audit")
		return false
	var first_id := str(first.get("workstation_id", ""))
	building_system.release_workstation_reservation("workshop", "route_retry_audit", first_id)
	var second: Dictionary = building_system.reserve_workstation("workshop", "route_retry_audit", "engineering", [first_id])
	if not bool(second.get("ok", false)) or str(second.get("workstation_id", "")) == first_id:
		_fail("Workstation retry did not exclude the failed station: %s" % JSON.stringify(second))
		return false
	building_system.release_workstation_reservation("workshop", "route_retry_audit", str(second.get("workstation_id", "")))
	return true


func _verify_glen_arrival_failure(
	action_system: Node,
	npc_system: Node,
	building_system: Node,
	crafting_system: Node,
	time_system: Node
) -> bool:
	crafting_system.set_target("blacksmith", "", true)
	npc_system.debug_enter_location_immediately(GLEN_ID, "dining_hall")
	var glen := _get_npc_node(npc_system, GLEN_ID)
	glen.set("move_speed", 40.0)
	if not action_system.debug_assign_action(GLEN_ID, "work_blacksmith", true):
		_fail("Glen's targetless blacksmith work did not dispatch")
		return false
	var pending: Dictionary = action_system.get_runtime_action_snapshot(GLEN_ID)
	if (
		str(pending.get("phase", "")) != "pending"
		or str(npc_system.get_npc_state(GLEN_ID).get("current_location", "")) != "dining_hall"
		or not _is_reserved_by(building_system, "blacksmith", "forge_01", GLEN_ID)
	):
		_fail("Glen failed remotely in the dining hall instead of travelling to the forge")
		return false
	for _frame in range(1800):
		time_system.set_paused(false)
		await physics_frame
		if str(npc_system.get_npc_state(GLEN_ID).get("last_action_result", "")) == "work_failed_crafting_target_missing":
			var arrived := str(npc_system.get_npc_state(GLEN_ID).get("current_location", "")) == "blacksmith"
			var cleaned := not bool(npc_system.get_formal_workstation_action_snapshot(GLEN_ID).get("active", false))
			if not arrived or not cleaned:
				_fail("Glen's arrival-time failure did not preserve the real destination and clean its session")
				return false
			return true
	_fail("Glen never reached the forge before the missing-target failure")
	return false


func _verify_owen_first_workbench(
	action_system: Node,
	npc_system: Node,
	building_system: Node,
	crafting_system: Node,
	resource_system: Node,
	time_system: Node
) -> bool:
	resource_system.add_resource("wood", 40)
	resource_system.add_resource("iron", 40)
	var recipe_ids: Array = crafting_system.get_recipe_ids_for_building("workshop")
	if recipe_ids.is_empty() or not bool(crafting_system.set_target("workshop", str(recipe_ids[0]), true).get("ok", false)):
		_fail("Could not select a workshop target for Owen")
		return false
	npc_system.debug_enter_location_immediately(OWEN_ID, "dining_hall")
	var owen := _get_npc_node(npc_system, OWEN_ID)
	owen.set("move_speed", 12.0)
	if not action_system.debug_assign_action(OWEN_ID, "work_workshop", true):
		_fail("Owen's workshop work did not dispatch")
		return false
	for _frame in range(2400):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(OWEN_ID)
		if str(runtime.get("phase", "")) == "active":
			if (
				str(runtime.get("workstation_id", "")) != "workbench_01"
				or not _is_occupied_by(building_system, "workshop", "workbench_01", OWEN_ID)
			):
				_fail("Owen did not start real work at workshop station 1: %s" % JSON.stringify(runtime))
				return false
			break
		if str(npc_system.get_npc_state(OWEN_ID).get("spatial_route_phase", "")) == "navigation_failed":
			_fail("Owen's empty workshop station 1 was still reported unreachable")
			return false
	if str(action_system.get_runtime_action_snapshot(OWEN_ID).get("phase", "")) != "active":
		_fail("Owen did not reach workshop station 1")
		return false

	# Simulate a genuine route failure on station 1. ActionSystem must make the
	# authoritative switch itself, exclude station 1, and actually arrive at 2.
	action_system.interrupt_npc_action(OWEN_ID, "verify_workstation_retry", true)
	npc_system.debug_enter_location_immediately(OWEN_ID, "dining_hall")
	if not action_system.debug_assign_action(OWEN_ID, "work_workshop", true):
		_fail("Owen's retry scenario did not dispatch")
		return false
	var all_pending_options: Dictionary = action_system.get("_pending_action_options")
	var failed_options: Dictionary = (all_pending_options.get(OWEN_ID, {}) as Dictionary).duplicate(true)
	if not action_system._retry_pending_formal_workstation_route(OWEN_ID, failed_options):
		_fail("ActionSystem did not retry the alternate free workshop station")
		return false
	all_pending_options = action_system.get("_pending_action_options")
	var retry_options: Dictionary = all_pending_options.get(OWEN_ID, {})
	if (
		str(retry_options.get("reserved_workstation_id", "")) != "workbench_02"
		or not (retry_options.get("attempted_workstation_ids", []) as Array).has("workbench_01")
		or not _is_reserved_by(building_system, "workshop", "workbench_02", OWEN_ID)
	):
		_fail("Programmatic retry did not reserve station 2 with station 1 excluded: %s" % JSON.stringify(retry_options))
		return false
	for _frame in range(2400):
		time_system.set_paused(false)
		await physics_frame
		var retry_runtime: Dictionary = action_system.get_runtime_action_snapshot(OWEN_ID)
		if str(retry_runtime.get("phase", "")) == "active":
			if str(retry_runtime.get("workstation_id", "")) != "workbench_02":
				_fail("Program selected station 2 but Owen worked elsewhere: %s" % JSON.stringify(retry_runtime))
				return false
			return true
	_fail("Owen did not reach the program-selected alternate station 2")
	return false


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _is_reserved_by(building_system: Node, building_id: String, workstation_id: String, npc_id: String) -> bool:
	for raw_workstation in building_system.get_building(building_id).get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("id", "")) == workstation_id:
			return str(raw_workstation.get("reserved_by", "")) == npc_id
	return false


func _is_occupied_by(building_system: Node, building_id: String, workstation_id: String, npc_id: String) -> bool:
	for raw_workstation in building_system.get_building(building_id).get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("id", "")) == workstation_id:
			return str(raw_workstation.get("occupied_by", "")) == npc_id
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
