extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CLINIC_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Clinic"


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

	var clinic := root.get_node_or_null(CLINIC_PATH) as Node3D
	var art := clinic.get_node_or_null("ClinicArt") as Node3D if clinic != null else null
	var fixture_root := clinic.get_node_or_null("FixtureLayout") if clinic != null else null
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var layout_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if [clinic, art, fixture_root, building_system, npc_system, layout_controller].has(null):
		_fail("T0131-P3 clinic runtime hierarchy is incomplete")
		return
	if not _verify_seated_anchor_offsets(layout_controller, fixture_root, "clinic", "doctor_desk", 2):
		return
	var envelope := clinic.get_node_or_null("Envelope") as Node3D
	var visuals := fixture_root.get_node_or_null("Visuals")
	var collisions := fixture_root.get_node_or_null("StaticCollision")
	if envelope == null or envelope.visible or visuals == null or collisions == null:
		_fail("Legacy clinic envelope was not replaced by the formal art slice")
		return

	var building: Dictionary = building_system.get_building("clinic")
	if int(building.get("level", 0)) != 1 or int((building.get("upgrade", {}) as Dictionary).get("max_level", 0)) != 3:
		_fail("Clinic authority must remain Lv.1 with a Lv.3 maximum during art preview")
		return
	for level in [1, 2, 3]:
		var snapshot: Dictionary = art.call("debug_force_visual_level", level)
		if not _verify_level(art, snapshot, visuals, collisions, level):
			return
	if int(building_system.get_building("clinic").get("level", 0)) != 1:
		_fail("Clinic art preview changed the authoritative building level")
		return

	var art_bounds := _subtree_bounds_in_space(art, clinic, true)
	var fixture_bounds := _subtree_bounds_in_space(visuals, clinic, true)
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
		_fail("Clinic art/fixture bounds escaped the 14x14 m lot or sank below grade: %s / %s" % [art_bounds, fixture_bounds])
		return
	var wash_basin := art.get_node_or_null("Interior/Level1Details/ClinicWashBasin") as Node3D
	var wash_basin_bounds := _subtree_bounds_in_space(wash_basin, clinic, true)
	if (
		wash_basin == null
		or wash_basin.position.distance_to(Vector3(0.0, 0.0, -5.42)) > 0.01
		or not _verify_wash_basin_structure(wash_basin)
		or _direct_subtrees_intersect(wash_basin, visuals, clinic)
	):
		_fail("Clinic wash basin is missing, misplaced or overlaps a desk/bed fixture: %s" % wash_basin_bounds)
		return

	art.call("apply_roof_camera_distance", 70.0, 1.0)
	var far_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	if float(far_snapshot.get("roof_opacity", 0.0)) < 0.99 or float(far_snapshot.get("exterior_opacity", 0.0)) < 0.99:
		_fail("Clinic far shell is not opaque: %s" % JSON.stringify(far_snapshot))
		return
	art.call("apply_roof_camera_distance", 58.0, 0.0)
	var near_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	var roof := art.get_node_or_null("Roof") as Node3D
	var level_2_roof := art.get_node_or_null("UpgradeVisuals/Level2/RoofStructureAdditions") as Node3D
	var level_3_roof := art.get_node_or_null("UpgradeVisuals/Level3/RoofStructureAdditions") as Node3D
	if (
		float(near_snapshot.get("roof_opacity", 1.0)) > 0.07
		or float(near_snapshot.get("exterior_opacity", 1.0)) > 0.07
		or not bool(near_snapshot.get("interior_revealed_for_selection", false))
		or not _subtree_alpha_at_most(roof, 0.07)
		or not _subtree_alpha_at_most(level_2_roof, 0.07)
		or not _subtree_alpha_at_most(level_3_roof, 0.07)
	):
		_fail("Clinic near shell or upgrade vents did not join the transparent chain: %s" % JSON.stringify(near_snapshot))
		return
	var ray_hit: Dictionary = art.call(
		"get_building_interaction_ray_hit",
		art.global_position + Vector3(4.7, 20.0, 4.7),
		art.global_position + Vector3(4.7, -5.0, 4.7)
	)
	if str(ray_hit.get("building_id", "")) != "clinic" or not bool(ray_hit.get("interior_revealed", false)):
		_fail("Transparent clinic lost its empty-space building click fallback")
		return
	if not await _verify_transparent_click_contract(art, npc_system, building_system):
		return

	var doctor := _get_npc_node(npc_system, "doctor_01") as CharacterBody3D
	if doctor == null or not await _verify_actor_operated_door(art, doctor):
		return
	art.call("debug_force_visual_level", 1)
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	print("T0131-P3R healing clinic building slice verification passed: %s" % JSON.stringify({
		"fixture_counts": [6, 7, 8],
		"bed_capacity": [2, 3, 4],
		"doctor_desks": 2,
		"bounds": art_bounds,
		"door": "2.08x2.35_auto_double_leaf",
		"fade_range": "70_to_58"
	}))
	main.queue_free()
	await process_frame
	quit(0)


func _verify_seated_anchor_offsets(controller: Node, fixture_root: Node, building_id: String, workstation_prefix: String, count: int) -> bool:
	for index in range(1, count + 1):
		var workstation_id := "%s_%02d" % [workstation_prefix, index]
		var route: Dictionary = controller.call("get_building_spatial_route", building_id, workstation_id)
		var anchor: Vector3 = route.get("occupant_anchor_position", Vector3.ZERO)
		var fixture_id := str(route.get("target_fixture_id", ""))
		var chair := fixture_root.get_node_or_null("Visuals/%s" % fixture_id.to_pascal_case()) as Node3D
		var chair_center := chair.global_position if chair != null else Vector3.ZERO
		var facing: Vector3 = route.get("occupant_anchor_facing_direction", Vector3.ZERO)
		var horizontal_delta := anchor - chair_center
		horizontal_delta.y = 0.0
		facing.y = 0.0
		if (
			route.is_empty()
			or chair == null
			or facing.length_squared() <= 0.0001
			or absf(horizontal_delta.dot(facing.normalized()) - 0.52) > 0.01
			or (horizontal_delta - facing.normalized() * 0.52).length() > 0.01
		):
			_fail("Clinic doctor seat did not preserve the approved forward sitting offset: %s / %s" % [workstation_id, JSON.stringify(route)])
			return false
	return true


func _verify_level(art: Node3D, snapshot: Dictionary, visuals: Node, collisions: Node, level: int) -> bool:
	var expected_fixtures: int = [6, 7, 8][level - 1]
	var expected_beds: int = [2, 3, 4][level - 1]
	var required_paths := [
		"Exterior/PlasterWallShell/FrontDoorArch",
		"Exterior/SageHalfTimberAndTrim",
		"Exterior/HighLightWindows",
		"Exterior/HerbalMortarSign/HealerLeafEmblem",
		"Exterior/HealingEntranceCanopy/CreamLinenCanopy",
		"Exterior/HerbalWelcomeGarden/WestHerbPlanter",
		"Exterior/HerbalWelcomeGarden/EastHerbPlanter",
		"Exterior/AutoDoor",
		"Roof/HealingHipRoof/FrontSlope",
		"Roof/HealingHipRoof/RearSlope",
		"Roof/HealingHipRoof/WestSlope",
		"Roof/HealingHipRoof/EastSlope",
		"Roof/HealingLightLantern",
		"Interior/Level1Details/WestMedicineShelf",
		"Interior/Level1Details/EastLinenShelf",
		"Interior/Level1Details/DryingHerbRack",
		"Interior/Level1Details/BedOnePrivacyScreen",
		"Interior/Level1Details/BedTwoPrivacyScreen",
		"Interior/Level1Details/ClinicWashBasin"
	]
	if level >= 2:
		required_paths.append_array([
			"UpgradeVisuals/Level2/InteriorAdditions/ThirdBedPrivacyScreen",
			"UpgradeVisuals/Level2/InteriorAdditions/ExpandedMedicineCabinet",
			"UpgradeVisuals/Level2/ExteriorAdditions/WestHerbDryingAwning",
			"UpgradeVisuals/Level2/RoofStructureAdditions/WestWardVent"
		])
	if level >= 3:
		required_paths.append_array([
			"UpgradeVisuals/Level3/InteriorAdditions/FourthBedPrivacyScreen",
			"UpgradeVisuals/Level3/InteriorAdditions/SterilizationCounter",
			"UpgradeVisuals/Level3/ExteriorAdditions/DispensingHatchFrame",
			"UpgradeVisuals/Level3/RoofStructureAdditions/EastWardVent"
		])
	for path in required_paths:
		if art.get_node_or_null(path) == null:
			return _expect(false, "Clinic Lv.%d lacks required art element: %s" % [level, path])
	if art.get_node_or_null("Roof/ClinicTileRoof") != null:
		return _expect(false, "Clinic reused the generic workshop gable roof after T0131-P3R")
	var additions := snapshot.get("level_visual_addition_counts", {}) as Dictionary
	var palette := snapshot.get("palette", {}) as Dictionary
	return _expect(
		int(snapshot.get("maximum_level", 0)) == 3
		and str(snapshot.get("architectural_style", "")) == "medieval_border_healing_infirmary_and_herb_house"
		and str(snapshot.get("roof_profile", "")) == "broad_four_slope_sage_hip_roof_with_daylight_lantern"
		and str(snapshot.get("healing_visual_language", "")) == "warm_linen_daylight_herbs_and_soft_sage"
		and bool(snapshot.get("silhouette_distinct_from_workshop", false))
		and str(palette.get("roof", "")) == "728f87"
		and int(snapshot.get("doctor_desk_count", 0)) == 2
		and int(snapshot.get("treatment_bed_count", 0)) == 4
		and int(snapshot.get("available_treatment_bed_count", 0)) == expected_beds
		and int(snapshot.get("active_fixture_visual_count", 0)) == expected_fixtures
		and int(snapshot.get("active_fixture_collision_count", 0)) == expected_fixtures
		and _active_visual_count(visuals) == expected_fixtures
		and _active_collision_count(collisions) == expected_fixtures
		and bool(snapshot.get("level_2_visible", false)) == (level >= 2)
		and bool(snapshot.get("level_3_visible", false)) == (level >= 3)
		and int(additions.get("level_1", 0)) >= 70
		and (level < 2 or int(additions.get("level_2", 0)) >= 20)
		and (level < 3 or int(additions.get("level_3", 0)) >= 18),
		"Clinic Lv.%d did not preserve 2 desks and expose the expected 2/3/4 bed slice: %s" % [level, JSON.stringify(snapshot)]
	)


func _verify_wash_basin_structure(wash_basin: Node3D) -> bool:
	if (
		str(wash_basin.get_meta("authority_role", "")) != "non_workstation_decoration"
		or str(wash_basin.get_meta("prop_type", "")) != "medieval_wall_wash_basin"
		or not bool(wash_basin.get_meta("has_water_surface", false))
		or bool(wash_basin.get_meta("uses_modern_plumbing", true))
		or not wash_basin.find_children("*", "CollisionObject3D", true, false).is_empty()
		or not wash_basin.find_children("*", "NavigationRegion3D", true, false).is_empty()
	):
		return false
	for part_name in ["StoneFooting", "OakLeg", "LowerStorageShelf", "BasinSupportSlab", "HammeredBasinBowl", "RaisedBasinRim", "CleanWaterSurface", "OakBackBoard", "CopperWaterCistern", "CopperSpout", "HangingLinen"]:
		if wash_basin.find_child(part_name, true, false) == null:
			return false
	return true


func _direct_subtrees_intersect(first_root: Node, second_root: Node, space: Node3D) -> bool:
	if first_root == null or second_root == null:
		return false
	for raw_first in first_root.get_children():
		var first_bounds := _subtree_bounds_in_space(raw_first, space, true)
		if not first_bounds.has_volume():
			continue
		for raw_second in second_root.get_children():
			var second_bounds := _subtree_bounds_in_space(raw_second, space, true)
			if second_bounds.has_volume() and first_bounds.intersects(second_bounds):
				return true
	return false


func _verify_actor_operated_door(art: Node3D, actor: CharacterBody3D) -> bool:
	var door := art.get_node_or_null("Exterior/AutoDoor") as Node3D
	if door == null or not door.has_method("debug_get_snapshot"):
		return _expect(false, "Clinic auto door is missing")
	var contract: Dictionary = door.call("debug_get_snapshot")
	if not _expect(
		float(contract.get("clear_width", 0.0)) >= 1.8
		and float(contract.get("clear_height", 0.0)) >= 2.2
		and bool(contract.get("centerline_clear", false))
		and not bool(contract.get("blocking_collision", true)),
		"Clinic auto door violates the shared doorway contract"
	):
		return false
	actor.set_physics_process(false)
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 1.5))
	for _frame in range(32):
		await physics_frame
	var opened: Dictionary = door.call("debug_get_snapshot")
	if not _expect(bool(opened.get("open_requested", false)) and float(opened.get("open_fraction", 0.0)) >= 0.95, "Clinic door did not open for Lina"):
		return false
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 8.0))
	for _frame in range(78):
		await physics_frame
	var closed: Dictionary = door.call("debug_get_snapshot")
	return _expect(not bool(closed.get("open_requested", true)) and float(closed.get("open_fraction", 1.0)) <= 0.05, "Clinic door did not close after Lina left")


func _verify_transparent_click_contract(art: Node3D, npc_system: Node, building_system: Node) -> bool:
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if not _expect(camera != null, "Clinic click camera is missing"):
		return false
	if not _expect(
		bool(npc_system.call("debug_enter_location_immediately", "doctor_01", "clinic", false)),
		"Could not place Lina inside the clinic for click verification"
	):
		return false
	var doctor := _get_npc_node(npc_system, "doctor_01") as Node3D
	if not _expect(doctor != null, "Lina world node is missing for click verification"):
		return false
	doctor.global_position = art.to_global(Vector3.ZERO)
	await physics_frame
	var doctor_screen := camera.unproject_position(doctor.global_position + Vector3(0.0, 1.0, 0.0))
	if not _expect(
		bool(building_system.call("_try_select_interior_npc", doctor_screen, "clinic")),
		"Transparent clinic did not route the exact NPC click to Lina"
	):
		return false
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	if not _expect(
		bool(npc_system.call("_is_npc_hidden_by_opaque_building", "doctor_01")),
		"Opaque clinic did not restore building-first click priority"
	):
		return false
	art.call("apply_roof_camera_distance", 58.0, 0.0)
	if not _expect(
		not bool(npc_system.call("_is_npc_hidden_by_opaque_building", "doctor_01")),
		"Transparent clinic still hides Lina from click selection"
	):
		return false
	var empty_screen := camera.unproject_position(art.to_global(Vector3(4.7, 0.0, 4.7)))
	return _expect(
		not bool(building_system.call("_try_select_interior_npc", empty_screen, "clinic")),
		"Transparent clinic empty-space click incorrectly selected an NPC instead of the building"
	)


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
