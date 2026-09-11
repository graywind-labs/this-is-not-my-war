extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const NPC_ID := "blacksmith_01"
const BUILDING_ID := "blacksmith"
const WORKSTATION_ID := "forge_01"
const ENVELOPE := Vector2(14.0, 12.0)
const DOOR_WIDTH := 1.8


func _init() -> void:
	var main_scene := load(MAIN_PATH) as PackedScene
	if main_scene == null:
		_fail("Main.tscn unavailable")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	for _step in 5:
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var npc := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Blacksmith01") as CharacterBody3D
	var blacksmith := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith"
	) as Node3D
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if controller == null or npc_system == null or npc == null or blacksmith == null or navigation_region == null:
		_fail("T0219 runtime dependencies unavailable")
		return

	var shell := blacksmith.get_node_or_null("StaticCollision")
	if shell == null or shell.get_child_count() != 5:
		_fail("Blacksmith transparent perimeter must contain five wall bodies")
		return
	if bool(shell.get_meta("fully_open_front", true)) or not bool(shell.get_meta("transparent_perimeter", false)):
		_fail("Blacksmith perimeter metadata still describes a fully open front")
		return
	for segment_name in ["LeftWall", "RightWall", "BackWall", "FrontLeft", "FrontRight"]:
		var segment := shell.get_node_or_null(segment_name) as StaticBody3D
		if segment == null or segment.collision_layer != 1 or segment.collision_mask != 2:
			_fail("Blacksmith perimeter segment is missing or on the wrong layer: %s" % segment_name)
			return

	controller.debug_set_preview_enabled(true)
	for _step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	if not _verify_outdoor_detour(navigation_map, blacksmith):
		return

	npc.move_speed = 24.0
	var pilot_start: Dictionary = npc_system.debug_run_glen_blacksmith_navigation_pilot()
	if not bool(pilot_start.get("ok", false)) or str(pilot_start.get("workstation_id", "")) != WORKSTATION_ID:
		_fail("Could not start Glen's production navigation pilot: %s" % pilot_start)
		return

	# Put the real CharacterBody behind the smithy after the pilot has bound the
	# production map. The existing route request must now take him around the
	# closed rear/side perimeter to the sole front entrance.
	var requested_back_start := blacksmith.to_global(Vector3(0.0, 0.12, -9.5))
	var back_start := NavigationServer3D.map_get_closest_point(navigation_map, requested_back_start)
	var back_start_local := blacksmith.to_local(back_start)
	if back_start_local.z > -ENVELOPE.y * 0.5 - 0.5 or absf(back_start_local.x) > ENVELOPE.x * 0.5:
		_fail("Back-side NPC start did not resolve behind the smithy: %s" % back_start_local)
		return
	npc.global_position = Vector3(back_start.x, npc.global_position.y, back_start.z)
	var maximum_abs_x := absf(blacksmith.to_local(npc.global_position).x)
	var saw_front_exterior := false
	var saw_door_corridor := false
	var arrived := false
	for _frame in range(1200):
		await physics_frame
		var current_local := blacksmith.to_local(npc.global_position)
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		maximum_abs_x = maxf(maximum_abs_x, absf(current_local.x))
		if current_local.z >= ENVELOPE.y * 0.5 + 0.1:
			saw_front_exterior = true
		if (
			absf(current_local.x) <= DOOR_WIDTH * 0.5 + 0.35
			and current_local.z <= ENVELOPE.y * 0.5 + 0.35
			and current_local.z >= ENVELOPE.y * 0.5 - 1.35
		):
			saw_door_corridor = true
		if (
			not saw_door_corridor
			and str(state.get("current_location", "")) != BUILDING_ID
			and _entered_forbidden_smithy_interior(current_local)
		):
			_fail("NPC crossed the transparent smithy perimeter away from the front door: %s" % current_local)
			return
		if (
			str(state.get("spatial_route_phase", "")) == "workstation_arrived"
			and str(state.get("current_location", "")) == BUILDING_ID
			and str(state.get("current_workstation_id", "")) == WORKSTATION_ID
		):
			arrived = true
			break

	if not arrived:
		_fail("Back-side NPC did not reach the forge through the front entrance: %s" % JSON.stringify(
			npc_system.debug_get_glen_blacksmith_navigation_pilot_snapshot()
		))
		return
	if maximum_abs_x < ENVELOPE.x * 0.5 + 0.25:
		_fail("NPC did not physically detour around either side wall: max_abs_x=%.3f" % maximum_abs_x)
		return
	if not saw_front_exterior or not saw_door_corridor:
		_fail("NPC route did not pass the smithy's sole front entrance")
		return

	var completed_snapshot: Dictionary = npc_system.debug_get_glen_blacksmith_navigation_pilot_snapshot()
	var motion: Dictionary = completed_snapshot.get("motion", {})
	if str(motion.get("state", "")) != "arrived" or int(motion.get("avoidance_callback_count", 0)) <= 0:
		_fail("NPC route lacks physical NavigationAgent evidence: %s" % motion)
		return
	npc_system.debug_stop_glen_blacksmith_navigation_pilot("t0219_verified")

	print("T0219 blacksmith perimeter navigation verification passed: %s" % JSON.stringify({
		"shell_segments": shell.get_child_count(),
		"npc_back_start_local": back_start_local,
		"npc_maximum_abs_local_x": maximum_abs_x,
		"saw_front_exterior": saw_front_exterior,
		"saw_door_corridor": saw_door_corridor,
		"avoidance_callbacks": int(motion.get("avoidance_callback_count", 0))
	}))
	quit(0)


func _verify_outdoor_detour(navigation_map: RID, blacksmith: Node3D) -> bool:
	var requested_start := blacksmith.to_global(Vector3(-10.0, 0.12, 0.0))
	var requested_target := blacksmith.to_global(Vector3(10.0, 0.12, 0.0))
	var start := NavigationServer3D.map_get_closest_point(navigation_map, requested_start)
	var target := NavigationServer3D.map_get_closest_point(navigation_map, requested_target)
	var path := NavigationServer3D.map_get_path(navigation_map, start, target, true)
	if path.size() < 3:
		_fail("Outdoor path did not detour around the smithy: %s" % path)
		return false
	var path_length := 0.0
	for index in range(path.size() - 1):
		var from := path[index]
		var to := path[index + 1]
		path_length += from.distance_to(to)
		var sample_count := maxi(1, int(ceil(from.distance_to(to) / 0.2)))
		for sample_index in range(sample_count + 1):
			var point := from.lerp(to, float(sample_index) / float(sample_count))
			var local := blacksmith.to_local(point)
			if absf(local.x) < ENVELOPE.x * 0.5 - 0.15 and absf(local.z) < ENVELOPE.y * 0.5 - 0.15:
				_fail("Outdoor production path still cuts through the smithy: %s" % local)
				return false
	var direct_distance := start.distance_to(target)
	if path_length <= direct_distance + 1.0:
		_fail("Outdoor smithy route lacks a meaningful perimeter detour: %.3f / %.3f" % [path_length, direct_distance])
		return false
	return true


func _entered_forbidden_smithy_interior(local: Vector3) -> bool:
	var inside_horizontal_envelope := (
		absf(local.x) < ENVELOPE.x * 0.5 - 0.15
		and local.z > -ENVELOPE.y * 0.5 + 0.15
		and local.z < ENVELOPE.y * 0.5 - 0.15
	)
	if not inside_horizontal_envelope:
		return false
	var in_front_door_corridor := (
		absf(local.x) <= DOOR_WIDTH * 0.5 + 0.35
		and local.z >= ENVELOPE.y * 0.5 - 2.0
	)
	return not in_front_door_corridor


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
