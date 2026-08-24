extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const FIXTURE_LAYOUTS_PATH := "res://data/building_fixture_layouts.json"

var _failed := false


func _init() -> void:
	var fixture_layouts := _load_json_dictionary(FIXTURE_LAYOUTS_PATH)
	var main_scene := load(MAIN_PATH) as PackedScene
	if fixture_layouts.is_empty() or main_scene == null:
		_fail("T0129C-A3b3 inputs could not be loaded")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _step in 4:
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var dormitory := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Dormitory"
	) as Node3D
	var fixture_root := dormitory.get_node_or_null("FixtureLayout") if dormitory != null else null
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if (
		controller == null
		or building_system == null
		or npc_system == null
		or formal_root == null
		or dormitory == null
		or fixture_root == null
		or navigation_region == null
	):
		_fail("T0129C-A3b3 hierarchy is incomplete")
		return

	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	var physics_snapshot: Dictionary = controller.debug_get_physics_navigation_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Dormitory fixture configuration validation failed: %s" % snapshot)
		return
	if (
		int(snapshot.get("building_fixture_count", 0)) != 109
		or int(snapshot.get("fixture_workstation_stand_count", 0)) != 61
		or int(snapshot.get("fixture_occupant_anchor_count", 0)) != 36
		or int(physics_snapshot.get("static_body_count", 0)) != 236
	):
		_fail("Dormitory fixture aggregate counts drifted: %s / %s" % [snapshot, physics_snapshot])
		return

	var fixture_collisions := fixture_root.get_node_or_null("StaticCollision")
	var fixture_visuals := fixture_root.get_node_or_null("Visuals")
	var fixture_stands := fixture_root.get_node_or_null("NPCStands")
	var occupant_anchors := fixture_root.get_node_or_null("OccupantAnchors")
	if (
		fixture_collisions == null
		or fixture_visuals == null
		or fixture_stands == null
		or occupant_anchors == null
		or fixture_collisions.get_child_count() != 10
		or fixture_visuals.get_child_count() != 10
		or fixture_stands.get_child_count() != 10
		or occupant_anchors.get_child_count() != 10
	):
		_fail("Dormitory must expose ten visual/collision/stand/sleep-anchor quartets")
		return

	var dormitory_config: Dictionary = (
		(fixture_layouts.get("buildings", {}) as Dictionary).get("dormitory", {}) as Dictionary
	)
	var authority_positions: Dictionary = {}
	for raw_position in building_system.get_building("dormitory").get("workstations", []):
		var position: Dictionary = raw_position
		authority_positions[str(position.get("id", ""))] = position
	if authority_positions.size() != 10:
		_fail("BuildingSystem dormitory authority must keep exactly ten beds")
		return

	var direct_space_state := formal_root.get_world_3d().direct_space_state
	var mapped_workstations: Dictionary = {}
	var fixture_records: Array[Dictionary] = []
	var assigned_count := 0
	var minimum_fixture_clearance := INF
	for raw_fixture in dormitory_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		var fixture_id := str(fixture.get("id", ""))
		var workstation_id := str(fixture.get("workstation_id", ""))
		if mapped_workstations.has(workstation_id):
			_fail("Dormitory fixture workstation is duplicated: %s" % workstation_id)
			return
		mapped_workstations[workstation_id] = fixture_id
		if (
			str(fixture.get("kind", "")) != "dormitory_bed"
			or int(fixture.get("required_level", 0)) != 1
			or not authority_positions.has(workstation_id)
		):
			_fail("Dormitory bed definition drifted: %s" % workstation_id)
			return

		var authority: Dictionary = authority_positions[workstation_id]
		var assigned_npc_id := str(fixture.get("assigned_npc_id", ""))
		var authority_assigned_npc_id := str(authority.get("assigned_npc_id", ""))
		if assigned_npc_id != authority_assigned_npc_id:
			_fail("Dormitory fixed ownership mirror drifted: %s" % workstation_id)
			return
		if not assigned_npc_id.is_empty():
			assigned_count += 1

		var collision := _find_child_by_meta(fixture_collisions, "fixture_id", fixture_id) as StaticBody3D
		var visual := _find_child_by_meta(fixture_visuals, "fixture_id", fixture_id) as Node3D
		var stand := _find_child_by_meta(fixture_stands, "fixture_id", fixture_id) as Marker3D
		var anchor := _find_child_by_meta(occupant_anchors, "fixture_id", fixture_id) as Marker3D
		if collision == null or visual == null or stand == null or anchor == null:
			_fail("Dormitory bed quartet is missing: %s" % fixture_id)
			return
		if collision.collision_layer != 1 or collision.collision_mask != 2:
			_fail("Dormitory bed collision layer/mask drifted: %s" % fixture_id)
			return
		if (
			str(collision.get_meta("assigned_npc_id", "")) != assigned_npc_id
			or str(visual.get_meta("assigned_npc_id", "")) != assigned_npc_id
		):
			_fail("Dormitory visual/collision ownership audit metadata drifted: %s" % fixture_id)
			return
		var collision_shape := collision.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape == null or not collision_shape.shape is BoxShape3D:
			_fail("Dormitory bed must expose an auditable BoxShape3D: %s" % fixture_id)
			return
		if not (collision_shape.shape as BoxShape3D).size.is_equal_approx(_v3(fixture.get("collision_size", []))):
			_fail("Dormitory bed collision size drifted: %s" % fixture_id)
			return

		var stand_local := _v2((fixture.get("npc_stand", {}) as Dictionary).get("center", []))
		var stand_world := dormitory.to_global(Vector3(stand_local.x, 0.0, stand_local.y))
		var fixture_local := _v2(fixture.get("center", []))
		var fixture_world := dormitory.to_global(Vector3(fixture_local.x, 0.0, fixture_local.y))
		var anchor_config := fixture.get("occupant_anchor", {}) as Dictionary
		var anchor_local := _v2(anchor_config.get("center", []))
		var expected_anchor_world := dormitory.to_global(
			Vector3(anchor_local.x, float(anchor_config.get("y", 0.0)), anchor_local.y)
		)
		var route: Dictionary = controller.get_building_spatial_route("dormitory", workstation_id)
		if (
			str(route.get("target_fixture_id", "")) != fixture_id
			or str(route.get("arrival_mode", "")) != "mount_after_arrival"
			or str(route.get("occupant_pose", "")) != "sleeping_supine"
			or (route.get("interior_target_position", Vector3.ZERO) as Vector3).distance_to(stand_world) > 0.001
			or (route.get("occupant_anchor_position", Vector3.ZERO) as Vector3).distance_to(expected_anchor_world) > 0.001
		):
			_fail("Dormitory route/stand/sleep-anchor contract drifted: %s" % workstation_id)
			return
		if anchor.global_position.distance_to(expected_anchor_world) > 0.001:
			_fail("Dormitory sleep anchor marker drifted: %s" % workstation_id)
			return

		var stand_shape := SphereShape3D.new()
		stand_shape.radius = 0.35
		var stand_query := PhysicsShapeQueryParameters3D.new()
		stand_query.shape = stand_shape
		stand_query.transform = Transform3D(Basis.IDENTITY, stand_world + Vector3(0.0, 0.52, 0.0))
		stand_query.collision_mask = 1
		for hit in direct_space_state.intersect_shape(stand_query, 32):
			var collider := (hit as Dictionary).get("collider") as StaticBody3D
			if collider != null and str(collider.get_meta("collision_category", "")) == "building_fixture":
				_fail("Dormitory stand overlaps a bed: %s / %s" % [workstation_id, collider.name])
				return
		var ray_query := PhysicsRayQueryParameters3D.create(
			stand_world + Vector3(0.0, 0.52, 0.0),
			fixture_world + Vector3(0.0, 0.52, 0.0),
			1
		)
		var ray_hit := direct_space_state.intersect_ray(ray_query)
		var ray_collider := ray_hit.get("collider") as StaticBody3D
		if ray_collider == null or str(ray_collider.get_meta("fixture_id", "")) != fixture_id:
			_fail("Dormitory stand does not face its own physical bed: %s" % workstation_id)
			return

		for raw_other in dormitory_config.get("fixtures", []):
			var other: Dictionary = raw_other
			var other_size := _v3(other.get("collision_size", []))
			var clearance := _point_box_clearance(
				stand_local,
				_v2(other.get("center", [])),
				Vector2(other_size.x, other_size.z) * 0.5,
				0.45
			)
			minimum_fixture_clearance = minf(minimum_fixture_clearance, clearance)
			if clearance < -0.001:
				_fail("Dormitory stand enters a neighboring bed clearance envelope: %s / %s" % [workstation_id, other.get("id", "")])
				return

		fixture_records.append({
			"id": fixture_id,
			"workstation_id": workstation_id,
			"center": fixture_local,
			"half_size": Vector2(
				float((collision_shape.shape as BoxShape3D).size.x) * 0.5,
				float((collision_shape.shape as BoxShape3D).size.z) * 0.5
			),
			"stand": stand_local
		})

	if mapped_workstations.size() != 10 or assigned_count != 8:
		_fail("Dormitory must keep eight assigned beds and two future-NPC beds")
		return
	for index in range(fixture_records.size()):
		for other_index in range(index + 1, fixture_records.size()):
			var first: Dictionary = fixture_records[index]
			var second: Dictionary = fixture_records[other_index]
			if _rectangles_overlap(
				first.get("center", Vector2.ZERO), first.get("half_size", Vector2.ZERO),
				second.get("center", Vector2.ZERO), second.get("half_size", Vector2.ZERO)
			):
				_fail("Dormitory bed collisions overlap: %s / %s" % [first.get("id", ""), second.get("id", "")])
				return
			if (first.get("stand", Vector2.ZERO) as Vector2).distance_to(second.get("stand", Vector2.ZERO)) < 0.7:
				_fail("Dormitory stand pair cannot hold two NPC bodies")
				return

	for raw_fixture in dormitory_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		var workstation_id := str(fixture.get("workstation_id", ""))
		var assigned_npc_id := str(fixture.get("assigned_npc_id", ""))
		if assigned_npc_id.is_empty():
			continue
		var claim: Dictionary = building_system.claim_workstation("dormitory", assigned_npc_id, "dormitory_bed")
		if not bool(claim.get("ok", false)) or str(claim.get("workstation_id", "")) != workstation_id:
			_fail("BuildingSystem did not select the NPC's fixed bed: %s" % assigned_npc_id)
			return
		building_system.release_workstation("dormitory", assigned_npc_id, workstation_id)
	for future_id in ["future_npc_09", "future_npc_10"]:
		npc_system._profiles[future_id] = {
			"id": future_id,
			"name": future_id,
			"states": {"current_action": "idle", "current_location": "plaza"}
		}
	var future_claim_09: Dictionary = building_system.claim_workstation("dormitory", "future_npc_09", "dormitory_bed")
	var future_claim_10: Dictionary = building_system.claim_workstation("dormitory", "future_npc_10", "dormitory_bed")
	if (
		str(future_claim_09.get("workstation_id", "")) != "dormitory_bed_09"
		or str(future_claim_10.get("workstation_id", "")) != "dormitory_bed_10"
	):
		_fail("Future NPCs must only receive the two unassigned dormitory beds")
		return
	building_system.release_workstation("dormitory", "future_npc_09", "dormitory_bed_09")
	building_system.release_workstation("dormitory", "future_npc_10", "dormitory_bed_10")
	npc_system._profiles.erase("future_npc_09")
	npc_system._profiles.erase("future_npc_10")

	controller.debug_set_preview_enabled(true)
	for _preview_step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	var route_results: Dictionary = {}
	for workstation_id in mapped_workstations.keys():
		var route: Dictionary = controller.get_building_spatial_route("dormitory", str(workstation_id))
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(
			navigation_map,
			route.get("entry_outside_position", Vector3.ZERO),
			target,
			true
		)
		if path.size() < 3 or path[path.size() - 1].distance_to(target) > 0.3:
			_fail("Production navigation cannot reach dormitory bedside: %s / %s" % [workstation_id, path])
			return
		route_results[workstation_id] = {
			"fixture_id": mapped_workstations[workstation_id],
			"path_points": path.size(),
			"end_distance": path[path.size() - 1].distance_to(target)
		}
	controller.debug_set_preview_enabled(false)

	print("T0129C A3b3 dormitory fixture verification passed: %s" % JSON.stringify({
		"bed_count": fixture_collisions.get_child_count(),
		"fixed_assignment_count": assigned_count,
		"future_bed_count": 10 - assigned_count,
		"minimum_bedside_clearance": minimum_fixture_clearance,
		"production_navigation": controller.debug_get_production_navigation_snapshot(),
		"routes": route_results
	}))
	quit(0)


func _point_box_clearance(point: Vector2, center: Vector2, half_size: Vector2, radius: float) -> float:
	var delta := Vector2(absf(point.x - center.x), absf(point.y - center.y)) - half_size
	var outside := Vector2(maxf(delta.x, 0.0), maxf(delta.y, 0.0))
	return outside.length() - radius


func _rectangles_overlap(first_center: Vector2, first_half: Vector2, second_center: Vector2, second_half: Vector2) -> bool:
	return (
		absf(first_center.x - second_center.x) < first_half.x + second_half.x
		and absf(first_center.y - second_center.y) < first_half.y + second_half.y
	)


func _find_child_by_meta(parent: Node, key: String, value: String) -> Node:
	for child in parent.get_children():
		if str(child.get_meta(key, "")) == value:
			return child
	return null


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _v2(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _v3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
