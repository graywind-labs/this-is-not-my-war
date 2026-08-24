extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const DINING_HALL_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/DiningHall"


func _init() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	var daily_plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if daily_plan_system != null:
		daily_plan_system.set_auto_execution_enabled(false)
	root.add_child(main)
	for _frame in range(5):
		await process_frame
		await physics_frame

	var hall := root.get_node_or_null(DINING_HALL_PATH) as Node3D
	var art := hall.get_node_or_null("DiningHallArt") as Node3D if hall != null else null
	var fixture_root := hall.get_node_or_null("FixtureLayout") if hall != null else null
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if [hall, art, fixture_root, building_system, npc_system].has(null):
		_fail("T0131-P4 dining hall runtime hierarchy is incomplete")
		return
	var envelope := hall.get_node_or_null("Envelope") as Node3D
	var visuals := fixture_root.get_node_or_null("Visuals")
	var collisions := fixture_root.get_node_or_null("StaticCollision")
	if envelope == null or envelope.visible or visuals == null or collisions == null:
		_fail("Legacy dining hall envelope was not replaced by the formal art slice")
		return

	var authority_before: Dictionary = building_system.get_building("dining_hall")
	if int(authority_before.get("level", 0)) != 1 or int((authority_before.get("upgrade", {}) as Dictionary).get("max_level", 0)) != 3:
		_fail("Dining hall authority must remain Lv.1 with a Lv.3 maximum during art preview")
		return
	for level in [1, 2, 3]:
		var snapshot: Dictionary = art.call("debug_force_visual_level", level)
		if not _verify_level(art, snapshot, visuals, collisions, level):
			return
	if int(building_system.get_building("dining_hall").get("level", 0)) != 1:
		_fail("Dining hall art preview changed the authoritative building level")
		return

	var west_table := visuals.get_node_or_null("DiningTable01") as Node3D
	var east_table := visuals.get_node_or_null("DiningTable02") as Node3D
	if (
		west_table == null
		or east_table == null
		or west_table.get_node_or_null("ThickOakTableTop") == null
		or east_table.get_node_or_null("ThickOakTableTop") == null
		or west_table.get_node_or_null("MedicalCloth") != null
		or east_table.get_node_or_null("MedicalCloth") != null
	):
		_fail("Dining tables did not replace the old clinic examination-table proxy")
		return

	var art_bounds := _subtree_bounds_in_space(art, hall, true)
	var fixture_bounds := _subtree_bounds_in_space(visuals, hall, true)
	if (
		not art_bounds.has_volume()
		or not fixture_bounds.has_volume()
		or art_bounds.position.x < -8.01
		or art_bounds.end.x > 8.01
		or art_bounds.position.z < -7.01
		or art_bounds.end.z > 7.01
		or art_bounds.position.y < -0.02
		or fixture_bounds.position.x < -8.01
		or fixture_bounds.end.x > 8.01
		or fixture_bounds.position.z < -7.01
		or fixture_bounds.end.z > 7.01
	):
		_fail("Dining hall art/fixture bounds escaped the 16x14 m lot or sank below grade: %s / %s / %s" % [art_bounds, fixture_bounds, _extreme_mesh_report(art, hall)])
		return

	var east_crockery := art.get_node_or_null("Interior/Level1Details/EastServingCrockery") as Node3D
	var level_2_counter := art.get_node_or_null("UpgradeVisuals/Level2/InteriorAdditions/NonWorkstationPreparationCounter") as Node3D
	var west_crockery := art.get_node_or_null("Interior/Level1Details/WestServingCrockery") as Node3D
	var level_3_counter := art.get_node_or_null("UpgradeVisuals/Level3/InteriorAdditions/ExpandedServingCounter") as Node3D
	if [east_crockery, level_2_counter, west_crockery, level_3_counter].has(null):
		_fail("Dining hall upgrade counter overlap audit lacks a required cabinet")
		return
	var east_crockery_bounds := _subtree_bounds_in_space(east_crockery, hall, true)
	var level_2_counter_bounds := _subtree_bounds_in_space(level_2_counter, hall, true)
	var west_crockery_bounds := _subtree_bounds_in_space(west_crockery, hall, true)
	var level_3_counter_bounds := _subtree_bounds_in_space(level_3_counter, hall, true)
	if (
		east_crockery_bounds.grow(0.05).intersects(level_2_counter_bounds)
		or west_crockery_bounds.grow(0.05).intersects(level_3_counter_bounds)
	):
		_fail("Dining hall Lv.2/Lv.3 counters still overlap the base crockery racks: %s / %s / %s / %s" % [east_crockery_bounds, level_2_counter_bounds, west_crockery_bounds, level_3_counter_bounds])
		return
	var level_2_door_clearance := AABB(Vector3(-1.2, 0.0, 4.65), Vector3(2.4, 2.6, 1.35))
	if level_2_counter_bounds.intersects(level_2_door_clearance) or level_3_counter_bounds.intersects(level_2_door_clearance):
		_fail("Dining hall relocated counters intrude into the central doorway clearance")
		return

	art.call("apply_roof_camera_distance", 70.0, 1.0)
	var far_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	if float(far_snapshot.get("roof_opacity", 0.0)) < 0.99 or float(far_snapshot.get("exterior_opacity", 0.0)) < 0.99:
		_fail("Dining hall far shell is not opaque")
		return
	art.call("apply_roof_camera_distance", 58.0, 0.0)
	var near_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	var roof := art.get_node_or_null("Roof") as Node3D
	var level_3_roof := art.get_node_or_null("UpgradeVisuals/Level3/RoofStructureAdditions") as Node3D
	if (
		float(near_snapshot.get("roof_opacity", 1.0)) > 0.07
		or float(near_snapshot.get("exterior_opacity", 1.0)) > 0.07
		or not bool(near_snapshot.get("interior_revealed_for_selection", false))
		or not _subtree_alpha_at_most(roof, 0.07)
		or not _subtree_alpha_at_most(level_3_roof, 0.07)
	):
		_fail("Dining hall roof, walls or upgraded flues did not join the transparent chain")
		return
	var ray_hit: Dictionary = art.call(
		"get_building_interaction_ray_hit",
		art.global_position + Vector3(6.0, 20.0, 4.5),
		art.global_position + Vector3(6.0, -5.0, 4.5)
	)
	if str(ray_hit.get("building_id", "")) != "dining_hall" or not bool(ray_hit.get("interior_revealed", false)):
		_fail("Transparent dining hall lost its empty-space building click fallback")
		return

	var cook := _get_npc_node(npc_system, "cook_01") as CharacterBody3D
	if cook == null or not await _verify_actor_operated_door(art, cook):
		return
	art.call("debug_force_visual_level", 1)
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	print("T0131-P4 dining hall building slice verification passed: %s" % JSON.stringify({
		"fixture_counts": [14, 14, 15],
		"kitchen_capacity": [2, 2, 3],
		"fixed_dining_seats": 10,
		"upgrade_counter_overlap_free": true,
		"bounds": art_bounds,
		"door": "2.08x2.35_auto_double_leaf",
		"fade_range": "70_to_58"
	}))
	main.queue_free()
	await process_frame
	quit(0)


func _verify_level(art: Node3D, snapshot: Dictionary, visuals: Node, collisions: Node, level: int) -> bool:
	var expected_fixtures: int = [14, 14, 15][level - 1]
	var expected_kitchens: int = [2, 2, 3][level - 1]
	var required_paths := [
		"Exterior/OchrePlasterWallShell/BroadDoorArch",
		"Exterior/RefectoryOakFrame",
		"Exterior/WarmRefectoryWindows",
		"Exterior/MealAndLadleSign/OakSignBoard",
		"Exterior/KitchenYardSupplies/FrontFirewoodStack",
		"Exterior/AutoDoor",
		"Roof/WideTerracottaRefectoryRoof/FrontTerracottaSlope",
		"Roof/WideTerracottaRefectoryRoof/RearTerracottaSlope",
		"Roof/LevelOneKitchenChimneys/WestKitchenChimney",
		"Roof/LevelOneKitchenChimneys/CenterKitchenChimney",
		"Interior/KitchenVentHoods/WestHearthHood",
		"Interior/KitchenVentHoods/CenterHearthHood",
		"Interior/Level1Details/WestDryGoodsShelf",
		"Interior/Level1Details/EastCrockeryShelf"
	]
	if level >= 2:
		required_paths.append_array([
			"UpgradeVisuals/Level2/InteriorAdditions/ExpandedDryPantry",
			"UpgradeVisuals/Level2/InteriorAdditions/NonWorkstationPreparationCounter",
			"UpgradeVisuals/Level2/ExteriorAdditions/LevelTwoFuelLeanTo"
		])
		for obsolete_guard_path in [
			"UpgradeVisuals/Level2/RoofStructureAdditions/WestSparkGuard",
			"UpgradeVisuals/Level2/RoofStructureAdditions/CenterSparkGuard"
		]:
			if art.get_node_or_null(obsolete_guard_path) != null:
				return _expect(false, "Dining hall Lv.2 still has an obsolete floating chimney cap: %s" % obsolete_guard_path)
	if level >= 3:
		required_paths.append_array([
			"UpgradeVisuals/Level3/InteriorAdditions/EastThirdHearthHood",
			"UpgradeVisuals/Level3/InteriorAdditions/ExpandedServingCounter",
			"UpgradeVisuals/Level3/RoofStructureAdditions/EastThirdKitchenChimney"
		])
	for path in required_paths:
		if art.get_node_or_null(path) == null:
			return _expect(false, "Dining hall Lv.%d lacks required art element: %s" % [level, path])
	var additions := snapshot.get("level_visual_addition_counts", {}) as Dictionary
	var palette := snapshot.get("palette", {}) as Dictionary
	return _expect(
		int(snapshot.get("maximum_level", 0)) == 3
		and str(snapshot.get("architectural_style", "")) == "medieval_border_refectory_with_rear_hearth_kitchen"
		and str(snapshot.get("roof_profile", "")) == "wide_low_terracotta_gable_with_clustered_kitchen_chimneys"
		and str(snapshot.get("functional_visual_language", "")) == "shared_oak_tables_cauldron_hearths_pantry_and_hot_meals"
		and str(palette.get("roof", "")) == "8b4f3f"
		and int(snapshot.get("kitchen_station_count", 0)) == 3
		and int(snapshot.get("available_kitchen_station_count", 0)) == expected_kitchens
		and int(snapshot.get("dining_seat_count", 0)) == 10
		and int(snapshot.get("available_dining_seat_count", 0)) == 10
		and int(snapshot.get("active_fixture_visual_count", 0)) == expected_fixtures
		and int(snapshot.get("active_fixture_collision_count", 0)) == expected_fixtures
		and _active_visual_count(visuals) == expected_fixtures
		and _active_collision_count(collisions) == expected_fixtures
		and bool(snapshot.get("level_2_visible", false)) == (level >= 2)
		and bool(snapshot.get("level_3_visible", false)) == (level >= 3)
		and int(additions.get("level_1", 0)) >= 90
		and (level < 2 or int(additions.get("level_2", 0)) >= 25)
		and (level < 3 or int(additions.get("level_3", 0)) >= 15),
		"Dining hall Lv.%d did not preserve fixed ten seats and expected 2/2/3 kitchen slice: %s" % [level, JSON.stringify(snapshot)]
	)


func _verify_actor_operated_door(art: Node3D, actor: CharacterBody3D) -> bool:
	var door := art.get_node_or_null("Exterior/AutoDoor") as Node3D
	if door == null or not door.has_method("debug_get_snapshot"):
		return _expect(false, "Dining hall auto door is missing")
	var contract: Dictionary = door.call("debug_get_snapshot")
	if not _expect(
		float(contract.get("clear_width", 0.0)) >= 1.8
		and float(contract.get("clear_height", 0.0)) >= 2.2
		and bool(contract.get("centerline_clear", false))
		and not bool(contract.get("blocking_collision", true)),
		"Dining hall auto door violates the shared doorway contract"
	):
		return false
	actor.set_physics_process(false)
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 1.5))
	for _frame in range(32):
		await physics_frame
	var opened: Dictionary = door.call("debug_get_snapshot")
	if not _expect(bool(opened.get("open_requested", false)) and float(opened.get("open_fraction", 0.0)) >= 0.95, "Dining hall door did not open for Bruno"):
		return false
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 8.0))
	for _frame in range(78):
		await physics_frame
	var closed: Dictionary = door.call("debug_get_snapshot")
	return _expect(not bool(closed.get("open_requested", true)) and float(closed.get("open_fraction", 1.0)) <= 0.05, "Dining hall door did not close after Bruno left")


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _active_visual_count(visuals: Node) -> int:
	var total := 0
	for child in visuals.get_children():
		if child is Node3D and (child as Node3D).visible:
			total += 1
	return total


func _active_collision_count(collisions: Node) -> int:
	var total := 0
	for child in collisions.get_children():
		if child is StaticBody3D and (child as StaticBody3D).collision_layer != 0:
			total += 1
	return total


func _subtree_alpha_at_most(root_node: Node, threshold: float) -> bool:
	if root_node == null:
		return false
	var mesh_count := 0
	var nodes: Array[Node] = [root_node]
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		for child in current.get_children():
			nodes.append(child)
		if not current is MeshInstance3D:
			continue
		var mesh := current as MeshInstance3D
		if mesh.mesh == null:
			continue
		mesh_count += 1
		for surface_index in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface_index) as BaseMaterial3D
			if material != null and material.albedo_color.a > threshold:
				return false
	return mesh_count > 0


func _subtree_bounds_in_space(root_node: Node, space: Node3D, visible_only: bool) -> AABB:
	if root_node == null:
		return AABB()
	var points: Array[Vector3] = []
	var nodes: Array[Node] = [root_node]
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		for child in current.get_children():
			nodes.append(child)
		if current is MeshInstance3D:
			var mesh_node := current as MeshInstance3D
			if mesh_node.mesh == null or (visible_only and not mesh_node.is_visible_in_tree()):
				continue
			var mesh_bounds := mesh_node.mesh.get_aabb()
			for x_index in range(2):
				for y_index in range(2):
					for z_index in range(2):
						var local_corner := mesh_bounds.position + Vector3(mesh_bounds.size.x * float(x_index), mesh_bounds.size.y * float(y_index), mesh_bounds.size.z * float(z_index))
						points.append(space.to_local(mesh_node.to_global(local_corner)))
	if points.is_empty():
		return AABB()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return AABB(min_point, max_point - min_point)


func _extreme_mesh_report(root_node: Node, space: Node3D) -> Dictionary:
	var result := {"minimum_x": 100000.0, "minimum_x_path": "", "maximum_x": -100000.0, "maximum_x_path": ""}
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var bounds := mesh.mesh.get_aabb()
		for x_index in range(2):
			for y_index in range(2):
				for z_index in range(2):
					var corner := bounds.position + Vector3(bounds.size.x * float(x_index), bounds.size.y * float(y_index), bounds.size.z * float(z_index))
					var local := space.to_local(mesh.to_global(corner))
					if local.x < float(result["minimum_x"]):
						result["minimum_x"] = local.x
						result["minimum_x_path"] = str(root_node.get_path_to(mesh))
					if local.x > float(result["maximum_x"]):
						result["maximum_x"] = local.x
						result["maximum_x_path"] = str(root_node.get_path_to(mesh))
	return result


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
