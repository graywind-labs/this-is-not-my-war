extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const GARDEN_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Garden"


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
	for _frame in range(6):
		await process_frame
		await physics_frame

	var garden := root.get_node_or_null(GARDEN_PATH) as Node3D
	var art := garden.get_node_or_null("GardenArt") as Node3D if garden != null else null
	var fixture_root := garden.get_node_or_null("FixtureLayout") if garden != null else null
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if [garden, art, fixture_root, building_system, npc_system].has(null):
		_fail("T0131-P7 garden runtime hierarchy is incomplete")
		return
	var envelope := garden.get_node_or_null("Envelope") as Node3D
	var visuals := fixture_root.get_node_or_null("Visuals")
	var collisions := fixture_root.get_node_or_null("StaticCollision")
	if envelope == null or envelope.visible or visuals == null or collisions == null:
		_fail("Legacy garden envelope was not replaced by the formal open-air slice")
		return

	var authority_before: Dictionary = building_system.get_building("garden")
	if int(authority_before.get("level", 0)) != 1 or int((authority_before.get("upgrade", {}) as Dictionary).get("max_level", 0)) != 3:
		_fail("Garden authority must remain Lv.1 with a Lv.3 maximum during art preview")
		return
	for level in [1, 2, 3]:
		var snapshot: Dictionary = art.call("debug_force_visual_level", level)
		if not _verify_level(art, snapshot, visuals, collisions, level):
			return
	if int(building_system.get_building("garden").get("level", 0)) != 1:
		_fail("Garden art preview changed the authoritative building level")
		return

	var third_fixture := visuals.get_node_or_null("GardenPlot03Bed") as Node3D
	var third_support := art.get_node_or_null("UpgradeVisuals/Level3/InteriorAdditions/ThirdPlotIrrigationAndTrellis") as Node3D
	if third_fixture == null or third_support == null or str(third_support.get_meta("workstation_id", "")) != "garden_plot_03":
		_fail("Garden Lv.3 visual addition is not explicitly paired to garden_plot_03")
		return
	art.call("debug_force_visual_level", 2)
	if third_fixture.is_visible_in_tree() or third_support.is_visible_in_tree():
		_fail("Garden Lv.2 exposes a complete third farm plot")
		return
	art.call("debug_force_visual_level", 3)
	if not third_fixture.is_visible_in_tree() or not third_support.is_visible_in_tree():
		_fail("Garden Lv.3 did not expose the third authoritative farm plot")
		return

	var art_bounds := _subtree_bounds_in_space(art, garden, true)
	var fixture_bounds := _subtree_bounds_in_space(visuals, garden, true)
	if (
		not art_bounds.has_volume()
		or not fixture_bounds.has_volume()
		or art_bounds.position.x < -7.01
		or art_bounds.end.x > 7.01
		or art_bounds.position.z < -7.01
		or art_bounds.end.z > 7.01
		or art_bounds.position.y < -0.02
		or fixture_bounds.position.x < -7.01
		or fixture_bounds.end.x > 7.01
		or fixture_bounds.position.z < -7.01
		or fixture_bounds.end.z > 7.01
	):
		_fail("Garden art/fixture bounds escaped the 14x14 m lot or sank below grade: %s / %s" % [art_bounds, fixture_bounds])
		return

	art.call("apply_roof_camera_distance", 70.0, 1.0)
	var far_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	art.call("apply_roof_camera_distance", 58.0, 0.0)
	var near_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	var roof := art.get_node_or_null("Roof") as Node3D
	var level_2_roof := art.get_node_or_null("UpgradeVisuals/Level2/RoofStructureAdditions") as Node3D
	var level_3_roof := art.get_node_or_null("UpgradeVisuals/Level3/RoofStructureAdditions") as Node3D
	if (
		float(far_snapshot.get("roof_opacity", 0.0)) < 0.99
		or float(near_snapshot.get("roof_opacity", 1.0)) > 0.07
		or not bool(near_snapshot.get("interior_revealed_for_selection", false))
		or not _subtree_alpha_at_most(roof, 0.07)
		or not _subtree_alpha_at_most(level_2_roof, 0.07)
		or not _subtree_alpha_at_most(level_3_roof, 0.07)
	):
		_fail("Garden tool-shelter roofs did not join the transparent chain")
		return
	if float(near_snapshot.get("exterior_opacity", 0.0)) < 0.99:
		_fail("Open-air garden fence should remain visible while only shelter roofs fade")
		return
	var ray_hit: Dictionary = art.call(
		"get_building_interaction_ray_hit",
		art.global_position + Vector3(0.0, 20.0, 0.0),
		art.global_position + Vector3(0.0, -5.0, 0.0)
	)
	if str(ray_hit.get("building_id", "")) != "garden" or not bool(ray_hit.get("interior_revealed", false)):
		_fail("Open-air garden lost NPC-priority / empty-space building fallback selection")
		return

	var ivo := _get_npc_node(npc_system, "gardener_01") as CharacterBody3D
	if ivo == null or not await _verify_actor_operated_gate(art, ivo):
		return
	art.call("debug_force_visual_level", 1)
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	print("T0131-P7 garden building slice verification passed: %s" % JSON.stringify({
		"fixture_counts": [6, 8, 9],
		"collision_parts": [10, 12, 15],
		"farm_capacity": [2, 2, 3],
		"bounds": art_bounds,
		"gate": "2.08x2.35_clearance_low_auto_double_leaf",
		"fade": "tool_shelter_only_70_to_58"
	}))
	main.queue_free()
	await process_frame
	quit(0)


func _verify_level(art: Node3D, snapshot: Dictionary, visuals: Node, collisions: Node, level: int) -> bool:
	var expected_fixtures: int = [6, 8, 9][level - 1]
	var expected_collision_parts: int = [10, 12, 15][level - 1]
	var expected_farmers: int = [2, 2, 3][level - 1]
	var required_paths := [
		"Exterior/LowStoneBoundary/RearStoneCourse",
		"Exterior/WattleAndPostFence",
		"Exterior/AutoGardenGate",
		"Exterior/SeedlingGardenSign/SignBoard",
		"Exterior/OpenToolShelter",
		"Roof/MossyToolShelterRoof",
		"Interior/DeepGardenGround",
		"Interior/PackedEarthPaths/CentralGardenWalk",
		"Interior/Level1Details/SeedAndHarvestCorner",
		"Interior/Level1Details/FrontHerbTroughs",
		"Interior/Level1Details/BorderScarecrow"
	]
	if level >= 2:
		required_paths.append_array([
			"UpgradeVisuals/Level2/InteriorAdditions/LevelTwoWaterHeader",
			"UpgradeVisuals/Level2/InteriorAdditions/SeedlingAndCompostMaturitySet",
			"UpgradeVisuals/Level2/RoofStructureAdditions/WaterBarrelShade"
		])
	if level >= 3:
		required_paths.append_array([
			"UpgradeVisuals/Level3/InteriorAdditions/ThirdPlotIrrigationAndTrellis",
			"UpgradeVisuals/Level3/InteriorAdditions/LevelThreeHarvestSortingExtension",
			"UpgradeVisuals/Level3/RoofStructureAdditions/HarvestSortingAwning"
		])
	for path in required_paths:
		if art.get_node_or_null(path) == null:
			return _expect(false, "Garden Lv.%d lacks required art element: %s" % [level, path])
	var additions := snapshot.get("level_visual_addition_counts", {}) as Dictionary
	return _expect(
		int(snapshot.get("maximum_level", 0)) == 3
		and str(snapshot.get("architectural_style", "")) == "open_air_medieval_border_kitchen_garden"
		and str(snapshot.get("roof_profile", "")) == "single_small_tool_shelter_roof_only"
		and bool(snapshot.get("open_air_selection_priority", false))
		and int(snapshot.get("farm_station_count", 0)) == 3
		and int(snapshot.get("available_farm_station_count", 0)) == expected_farmers
		and int(snapshot.get("active_fixture_visual_count", 0)) == expected_fixtures
		and int(snapshot.get("active_fixture_collision_count", 0)) == expected_collision_parts
		and int(snapshot.get("active_fixture_collision_part_count", 0)) == expected_collision_parts
		and _active_visual_count(visuals) == expected_fixtures
		and _active_collision_count(collisions) == expected_collision_parts
		and _active_collision_part_count(collisions) == expected_collision_parts
		and bool(snapshot.get("level_2_visible", false)) == (level >= 2)
		and bool(snapshot.get("level_3_visible", false)) == (level >= 3)
		and int(additions.get("level_1", 0)) >= 95
		and (level < 2 or int(additions.get("level_2", 0)) >= 20)
		and (level < 3 or int(additions.get("level_3", 0)) >= 15),
		"Garden Lv.%d did not preserve the expected 2/2/3 farm slice: %s" % [level, JSON.stringify(snapshot)]
	)


func _verify_actor_operated_gate(art: Node3D, actor: CharacterBody3D) -> bool:
	var gate := art.get_node_or_null("Exterior/AutoGardenGate") as Node3D
	if gate == null or not gate.has_method("debug_get_snapshot"):
		return _expect(false, "Garden automatic gate is missing")
	var contract: Dictionary = gate.call("debug_get_snapshot")
	if not _expect(
		float(contract.get("clear_width", 0.0)) >= 1.8
		and float(contract.get("clear_height", 0.0)) >= 2.2
		and float(contract.get("leaf_visual_height", 2.0)) <= 1.1
		and bool(contract.get("centerline_clear", false))
		and not bool(contract.get("blocking_collision", true)),
		"Garden auto gate violates the shared passage contract"
	):
		return false
	actor.set_physics_process(false)
	actor.global_position = gate.to_global(Vector3(0.0, 0.0, 1.5))
	for _frame in range(32):
		await physics_frame
	var opened: Dictionary = gate.call("debug_get_snapshot")
	if not _expect(bool(opened.get("open_requested", false)) and float(opened.get("open_fraction", 0.0)) >= 0.95, "Garden gate did not open for Ivo"):
		return false
	actor.global_position = gate.to_global(Vector3(0.0, 0.0, 8.0))
	for _frame in range(78):
		await physics_frame
	var closed: Dictionary = gate.call("debug_get_snapshot")
	return _expect(not bool(closed.get("open_requested", true)) and float(closed.get("open_fraction", 1.0)) <= 0.05, "Garden gate did not close after Ivo left")


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


func _active_collision_part_count(collisions: Node) -> int:
	var total := 0
	for child in collisions.get_children():
		if not child is StaticBody3D or (child as StaticBody3D).collision_layer == 0:
			continue
		for raw_shape in child.find_children("*", "CollisionShape3D", true, false):
			if not (raw_shape as CollisionShape3D).disabled:
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
						var corner := mesh_bounds.position + Vector3(mesh_bounds.size.x * float(x_index), mesh_bounds.size.y * float(y_index), mesh_bounds.size.z * float(z_index))
						points.append(space.to_local(mesh_node.to_global(corner)))
	if points.is_empty():
		return AABB()
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
