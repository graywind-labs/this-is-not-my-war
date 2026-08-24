extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const TAVERN_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Tavern"


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

	var tavern := root.get_node_or_null(TAVERN_PATH) as Node3D
	var art := tavern.get_node_or_null("TavernArt") as Node3D if tavern != null else null
	var fixture_root := tavern.get_node_or_null("FixtureLayout") if tavern != null else null
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if [tavern, art, fixture_root, building_system, npc_system].has(null):
		_fail("T0131-P6 tavern runtime hierarchy is incomplete")
		return
	var envelope := tavern.get_node_or_null("Envelope") as Node3D
	var visuals := fixture_root.get_node_or_null("Visuals")
	var collisions := fixture_root.get_node_or_null("StaticCollision")
	if envelope == null or envelope.visible or visuals == null or collisions == null:
		_fail("Legacy tavern envelope was not replaced by the formal art slice")
		return

	var authority_before: Dictionary = building_system.get_building("tavern")
	if int(authority_before.get("level", 0)) != 1 or int((authority_before.get("upgrade", {}) as Dictionary).get("max_level", 0)) != 3:
		_fail("Tavern authority must remain Lv.1 with a Lv.3 maximum during art preview")
		return
	for level in [1, 2, 3]:
		var snapshot: Dictionary = art.call("debug_force_visual_level", level)
		if not _verify_level(art, snapshot, visuals, collisions, level):
			return
	if int(building_system.get_building("tavern").get("level", 0)) != 1:
		_fail("Tavern art preview changed the authoritative building level")
		return

	var art_bounds := _subtree_bounds_in_space(art, tavern, true)
	var fixture_bounds := _subtree_bounds_in_space(visuals, tavern, true)
	if (
		not art_bounds.has_volume()
		or not fixture_bounds.has_volume()
		or art_bounds.position.x < -7.01
		or art_bounds.end.x > 7.01
		or art_bounds.position.z < -6.01
		or art_bounds.end.z > 6.01
		or art_bounds.position.y < -0.02
		or fixture_bounds.position.x < -7.01
		or fixture_bounds.end.x > 7.01
		or fixture_bounds.position.z < -6.01
		or fixture_bounds.end.z > 6.01
	):
		_fail("Tavern art/fixture bounds escaped the 14x12 m lot or sank below grade: %s / %s" % [art_bounds, fixture_bounds])
		return

	var third_fixture := visuals.get_node_or_null("Cellar03FermentationCask") as Node3D
	var third_service := art.get_node_or_null("UpgradeVisuals/Level3/InteriorAdditions/ThirdFermentationServiceBranch") as Node3D
	if third_fixture == null or third_service == null or str(third_service.get_meta("workstation_id", "")) != "cellar_03":
		_fail("Tavern Lv.3 visual addition is not explicitly paired to cellar_03")
		return
	art.call("debug_force_visual_level", 2)
	if third_fixture.is_visible_in_tree() or third_service.is_visible_in_tree():
		_fail("Tavern Lv.2 exposes a complete third brewing unit")
		return
	art.call("debug_force_visual_level", 3)
	if not third_fixture.is_visible_in_tree() or not third_service.is_visible_in_tree():
		_fail("Tavern Lv.3 did not expose the third authoritative brewing unit")
		return

	art.call("apply_roof_camera_distance", 70.0, 1.0)
	var far_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	if float(far_snapshot.get("roof_opacity", 0.0)) < 0.99 or float(far_snapshot.get("exterior_opacity", 0.0)) < 0.99:
		_fail("Tavern far shell is not opaque")
		return
	art.call("apply_roof_camera_distance", 58.0, 0.0)
	var near_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	var roof := art.get_node_or_null("Roof") as Node3D
	var level_2_roof := art.get_node_or_null("UpgradeVisuals/Level2/RoofStructureAdditions") as Node3D
	var level_3_roof := art.get_node_or_null("UpgradeVisuals/Level3/RoofStructureAdditions") as Node3D
	var level_2_exterior := art.get_node_or_null("UpgradeVisuals/Level2/ExteriorAdditions") as Node3D
	var level_3_exterior := art.get_node_or_null("UpgradeVisuals/Level3/ExteriorAdditions") as Node3D
	if (
		float(near_snapshot.get("roof_opacity", 1.0)) > 0.07
		or float(near_snapshot.get("exterior_opacity", 1.0)) > 0.07
		or not bool(near_snapshot.get("interior_revealed_for_selection", false))
		or not _subtree_alpha_at_most(roof, 0.07)
		or not _subtree_alpha_at_most(level_2_roof, 0.07)
		or not _subtree_alpha_at_most(level_3_roof, 0.07)
		or not _subtree_alpha_at_most(level_2_exterior, 0.07)
		or not _subtree_alpha_at_most(level_3_exterior, 0.07)
	):
		_fail("Tavern roof, walls or upgraded shell additions did not join the transparent chain")
		return
	var ray_hit: Dictionary = art.call(
		"get_building_interaction_ray_hit",
		art.global_position + Vector3(0.0, 20.0, 0.0),
		art.global_position + Vector3(0.0, -5.0, 0.0)
	)
	if str(ray_hit.get("building_id", "")) != "tavern" or not bool(ray_hit.get("interior_revealed", false)):
		_fail("Transparent tavern lost its empty-space building click fallback")
		return

	var marcel := _get_npc_node(npc_system, "priest_01") as CharacterBody3D
	if marcel == null or not await _verify_actor_operated_door(art, marcel):
		return
	art.call("debug_force_visual_level", 1)
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	print("T0131-P6 tavern building slice verification passed: %s" % JSON.stringify({
		"fixture_counts": [4, 5, 6],
		"brew_capacity": [2, 2, 3],
		"decorative_barrel_counts": [6, 11, 14],
		"bounds": art_bounds,
		"door": "2.08x2.35_auto_double_leaf",
		"fade_range": "70_to_58"
	}))
	main.queue_free()
	await process_frame
	quit(0)


func _verify_level(art: Node3D, snapshot: Dictionary, visuals: Node, collisions: Node, level: int) -> bool:
	var expected_fixtures: int = [4, 5, 6][level - 1]
	var expected_brewers: int = [2, 2, 3][level - 1]
	var expected_decorative_barrels: int = [6, 11, 14][level - 1]
	var required_paths := [
		"Exterior/HalfMasonryCellarShell/RoundLoadingDoor",
		"Exterior/CoolStoneCellarCourse/FrontStonePlinth",
		"Exterior/WineDarkTimberFrame/FrontLintel",
		"Exterior/HighCellarWindows",
		"Exterior/BarrelHoopAndVineSign/WineSignBoard",
		"Exterior/AutoDoor",
		"Roof/LowWineShingleGable/FrontWineShingleSlope",
		"Roof/LowWineShingleGable/RearWineShingleSlope",
		"Roof/LevelOneFermentationVents/WestFermentationVent",
		"Roof/LevelOneFermentationVents/EastFermentationVent",
		"Interior/CentralStoneDrain",
		"Interior/Level1Details/RearWallBottlingAndGrainStorage",
		"Interior/Level1Details/RearAgingBarrelStacks",
		"Interior/Level1Details/WestWallCooperAndCleaningTools",
		"Interior/Level1Details/BrewersMeasuresAndLedger"
	]
	if level >= 2:
		required_paths.append_array([
			"UpgradeVisuals/Level2/InteriorAdditions/StoneCoolingCistern",
			"UpgradeVisuals/Level2/InteriorAdditions/LevelTwoCopperPipework",
			"UpgradeVisuals/Level2/InteriorAdditions/MaturationBatchBoard",
			"UpgradeVisuals/Level2/ExteriorAdditions/LevelTwoMasonryReinforcement",
			"UpgradeVisuals/Level2/ExteriorAdditions/ShadedMaturationBarrelRack",
			"UpgradeVisuals/Level2/RoofStructureAdditions/MaturationAirVent"
		])
	if level >= 3:
		required_paths.append_array([
			"UpgradeVisuals/Level3/InteriorAdditions/ThirdFermentationServiceBranch",
			"UpgradeVisuals/Level3/ExteriorAdditions/LevelThreeLoadingAndDispatchRack",
			"UpgradeVisuals/Level3/RoofStructureAdditions/ThirdFermentationVent"
		])
	for path in required_paths:
		if art.get_node_or_null(path) == null:
			return _expect(false, "Tavern Lv.%d lacks required art element: %s" % [level, path])
	if not _verify_decorative_barrel_contract(art, level, expected_decorative_barrels):
		return false
	var additions := snapshot.get("level_visual_addition_counts", {}) as Dictionary
	var palette := snapshot.get("palette", {}) as Dictionary
	return _expect(
		int(snapshot.get("maximum_level", 0)) == 3
		and str(snapshot.get("architectural_style", "")) == "medieval_border_half_masonry_winery_cellar"
		and str(snapshot.get("roof_profile", "")) == "low_wine_shingle_gable_with_level_synced_fermentation_vents"
		and str(snapshot.get("functional_visual_language", "")) == "fermentation_casks_maturation_racks_copper_pipes_wash_water_and_cooper_tools"
		and str(palette.get("roof", "")) == "693f4d"
		and int(snapshot.get("brew_station_count", 0)) == 3
		and int(snapshot.get("available_brew_station_count", 0)) == expected_brewers
		and int(snapshot.get("active_fixture_visual_count", 0)) == expected_fixtures
		and int(snapshot.get("active_fixture_collision_count", 0)) == expected_fixtures
		and int(snapshot.get("decorative_storage_barrel_count", 0)) == expected_decorative_barrels
		and str(snapshot.get("barrel_density_profile", "")) == "level_1_rear_aging_stacks_level_2_shaded_maturation_stack_level_3_dispatch_stack"
		and _active_visual_count(visuals) == expected_fixtures
		and _active_collision_count(collisions) == expected_fixtures
		and bool(snapshot.get("level_2_visible", false)) == (level >= 2)
		and bool(snapshot.get("level_3_visible", false)) == (level >= 3)
		and int(additions.get("level_1", 0)) >= 75
		and (level < 2 or int(additions.get("level_2", 0)) >= 25)
		and (level < 3 or int(additions.get("level_3", 0)) >= 10),
		"Tavern Lv.%d did not preserve the expected 2/2/3 brewing slice: %s" % [level, JSON.stringify(snapshot)]
	)


func _verify_decorative_barrel_contract(art: Node3D, level: int, expected_count: int) -> bool:
	var visible_count := 0
	for raw_node in art.find_children("*", "Node3D", true, false):
		var barrel := raw_node as Node3D
		if barrel == null or not bool(barrel.get_meta("decorative_storage_barrel", false)):
			continue
		var required_level := int(barrel.get_meta("required_level", 0))
		if str(barrel.get_meta("authority_role", "")) != "non_workstation_non_inventory_decoration":
			return _expect(false, "Decorative tavern barrel gained an authoritative role: %s" % barrel.get_path())
		if required_level < 1 or required_level > 3:
			return _expect(false, "Decorative tavern barrel has an invalid required level: %s" % barrel.get_path())
		if barrel.is_visible_in_tree() != (required_level <= level):
			return _expect(false, "Decorative tavern barrel visibility is not level-synced: %s" % barrel.get_path())
		if barrel.is_visible_in_tree():
			visible_count += 1
	return _expect(visible_count == expected_count, "Tavern Lv.%d decorative barrel contract expected %d but found %d" % [level, expected_count, visible_count])


func _verify_actor_operated_door(art: Node3D, actor: CharacterBody3D) -> bool:
	var door := art.get_node_or_null("Exterior/AutoDoor") as Node3D
	if door == null or not door.has_method("debug_get_snapshot"):
		return _expect(false, "Tavern auto door is missing")
	var contract: Dictionary = door.call("debug_get_snapshot")
	if not _expect(
		float(contract.get("clear_width", 0.0)) >= 1.8
		and float(contract.get("clear_height", 0.0)) >= 2.2
		and bool(contract.get("centerline_clear", false))
		and not bool(contract.get("blocking_collision", true)),
		"Tavern auto door violates the shared doorway contract"
	):
		return false
	actor.set_physics_process(false)
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 1.5))
	for _frame in range(32):
		await physics_frame
	var opened: Dictionary = door.call("debug_get_snapshot")
	if not _expect(bool(opened.get("open_requested", false)) and float(opened.get("open_fraction", 0.0)) >= 0.95, "Tavern door did not open for Marcel"):
		return false
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 8.0))
	for _frame in range(78):
		await physics_frame
	var closed: Dictionary = door.call("debug_get_snapshot")
	return _expect(not bool(closed.get("open_requested", true)) and float(closed.get("open_fraction", 1.0)) <= 0.05, "Tavern door did not close after Marcel left")


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


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
