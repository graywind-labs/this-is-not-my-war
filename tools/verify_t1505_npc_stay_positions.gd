extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.get_node("Systems/DailyPlanSystem").set_auto_execution_enabled(false)
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame
	var controller := root.get_node("Main/Presentation/StationLayoutController")
	var region := root.get_node("Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation") as NavigationRegion3D
	var nav := region.get_navigation_map()
	NavigationServer3D.map_force_update(nav)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npc_stay_positions.json"))
	var failed := false
	var count := 0
	var body_shape := SphereShape3D.new()
	body_shape.radius = 0.35
	var space := (root.get_node("Main/WorldRoot") as Node3D).get_world_3d().direct_space_state
	var queue_areas: Array = controller.get("_building_door_queue_areas")
	var layout: Dictionary = controller.get("_layout")
	var roster: Array = root.get_node("Main/Systems/NPCSystem").get_npc_ids()
	if config.locations.size() != 11 or controller.get_npc_stay_world_position("plaza", "missing_npc") != null:
		failed = true
	for location_id in config.locations:
		if config.locations[location_id].size() != roster.size():
			failed = true
		for npc_id in roster:
			if not config.locations[location_id].has(npc_id):
				failed = true
		var points: Array[Vector3] = []
		for npc_id in config.locations[location_id]:
			var point: Vector3 = controller.get_npc_stay_world_position(location_id, npc_id)
			var snapped := NavigationServer3D.map_get_closest_point(nav, point)
			var source: Vector3 = controller.get_public_location_world_position("plaza")
			var path := NavigationServer3D.map_get_path(nav, source, point, true)
			var error := Vector2(snapped.x - point.x, snapped.z - point.z).length()
			for position in layout.building_spatial.get(location_id, {}).get("positions", []):
				var work_route: Dictionary = controller.get_building_spatial_route(location_id, position.id)
				for key in ["interior_target_position", "occupant_anchor_position"]:
					var work_point: Variant = work_route.get(key)
					if work_point is Vector3 and Vector2(point.x-work_point.x, point.z-work_point.z).length() < 1.1:
						print("WORKSTATION_CONFLICT ", location_id, " ", npc_id, " ", position.id)
						failed = true
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = body_shape
			query.collision_mask = 1
			query.transform.origin = point + Vector3(0, 0.75, 0)
			if not space.intersect_shape(query).is_empty():
				print("STATIC_COLLISION ", location_id, " ", npc_id)
				failed = true
			for area in queue_areas:
				var local: Vector3 = area.to_local(point)
				var size: Vector3 = area.get("_range_size")
				if absf(local.x) < size.x * 0.5 + 0.45 and absf(local.z) < size.z * 0.5 + 0.45:
					print("DOOR_QUEUE_CONFLICT ", location_id, " ", npc_id)
					failed = true
			if error > 0.12 or path.is_empty() or path[-1].distance_to(snapped) > 0.2:
				print("UNREACHABLE ", location_id, " ", npc_id, " point=", point, " snap=", snapped, " error=", error)
				failed = true
			for other in points:
				if point.distance_to(other) < (4.0 if location_id == "plaza" else 1.3):
					print("OVERLAP ", location_id, " ", npc_id)
					failed = true
			points.append(point)
			count += 1
	print("T1505-P6R54 navigation points=", count, " failed=", failed)
	if "--geometry-only" in OS.get_cmdline_user_args():
		quit(1 if failed else 0)
		return
	if failed:
		quit(1)
		return
	var actions := root.get_node("Main/Systems/ActionSystem")
	var npcs := root.get_node("Main/Systems/NPCSystem")
	var clock := root.get_node("Main/Systems/TimeSystem")
	clock.set_paused(false)
	clock.set_current_time(1, 8, 2, 0)
	var start_location := ""
	var stop_location := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--start-at="):
			start_location = argument.trim_prefix("--start-at=")
		if argument.begins_with("--stop-after="):
			stop_location = argument.trim_prefix("--stop-after=")
	var started := start_location.is_empty()
	for location_id in config.locations:
		if location_id == start_location:
			started = true
		if not started:
			continue
		for npc_id in config.locations[location_id]:
			actions.interrupt_npc_action(npc_id, "stay_verify", true)
			# Isolate destination crowding from the separate bulk-exit stress case.
			if not "--cross-building" in OS.get_cmdline_user_args():
				npcs.debug_enter_location_immediately(npc_id, "plaza")
				var setup_position: Vector3 = controller.get_npc_stay_world_position("plaza", npc_id)
				if location_id == "plaza":
					setup_position += Vector3(0, 0, 3)
				npcs.restore_npc_world_position_after_system_interrupt(npc_id, setup_position)
			npcs.update_npc_state(npc_id, {"satiety":100, "fatigue":0})
			if not actions.assign_visit_location(npc_id, location_id, true):
				print("ASSIGN_FAILED ", location_id, " ", npc_id)
				quit(1)
				return
		var pending: Array = config.locations[location_id].keys()
		for frame in range(7200):
			await physics_frame
			for npc_id in pending.duplicate():
				if "failed" in str(npcs.get_npc_state(npc_id).get("last_action_result", "")):
					print("ROUTE_FAILED ", location_id, " ", npc_id, " ", npcs.get_npc_state(npc_id).get("last_action_failure_context"))
					quit(1)
					return
				var actual: Vector3 = npcs.get_npc_world_position(npc_id)
				var target: Vector3 = controller.get_npc_stay_world_position(location_id, npc_id)
				if Vector2(actual.x-target.x, actual.z-target.z).length() < 0.45 and not actions.has_pending_action(npc_id):
					pending.erase(npc_id)
			if pending.is_empty():
				break
		if not pending.is_empty():
			for npc_id in pending:
				print("ARRIVAL_FAILED ", location_id, " ", npc_id, " pos=", npcs.get_npc_world_position(npc_id), " state=", npcs.get_npc_state(npc_id).get("last_action_result"))
			quit(1)
			return
		print("GROUP_ARRIVED ", location_id)
		if location_id == stop_location:
			break
	print("T1505-P6R54 requested groups passed")
	quit(0)
