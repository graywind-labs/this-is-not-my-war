extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHAPEL_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Chapel"


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
	for _frame in range(4):
		await process_frame
		await physics_frame

	var chapel := root.get_node_or_null(CHAPEL_PATH) as Node3D
	var art := chapel.get_node_or_null("ChapelArt") as Node3D if chapel != null else null
	var fixture_root := chapel.get_node_or_null("FixtureLayout") if chapel != null else null
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if [chapel, art, fixture_root, building_system, npc_system].has(null):
		_fail("T0131-P2 chapel runtime hierarchy is incomplete")
		return
	var envelope := chapel.get_node_or_null("Envelope") as Node3D
	var visuals := fixture_root.get_node_or_null("Visuals")
	var collisions := fixture_root.get_node_or_null("StaticCollision")
	if envelope == null or envelope.visible or visuals == null or collisions == null:
		_fail("Legacy chapel envelope was not replaced by the formal art slice")
		return

	var building: Dictionary = building_system.get_building("chapel")
	if int(building.get("level", 0)) != 1 or int((building.get("upgrade", {}) as Dictionary).get("max_level", 0)) != 2:
		_fail("Chapel authority must remain Lv.1 with a Lv.2 maximum during art preview")
		return
	var level_one: Dictionary = art.call("debug_force_visual_level", 1)
	if not _verify_level_one(art, level_one, visuals, collisions):
		return
	var level_two: Dictionary = art.call("debug_force_visual_level", 2)
	if not _verify_level_two(art, level_two, visuals, collisions):
		return
	if int(building_system.get_building("chapel").get("level", 0)) != 1:
		_fail("Chapel art preview changed the authoritative building level")
		return

	var chapel_bounds := _subtree_bounds_in_space(art, chapel, true)
	var fixture_bounds := _subtree_bounds_in_space(visuals, chapel, true)
	if (
		not chapel_bounds.has_volume()
		or not fixture_bounds.has_volume()
		or chapel_bounds.position.x < -7.01
		or chapel_bounds.end.x > 7.01
		or chapel_bounds.position.z < -7.01
		or chapel_bounds.end.z > 7.01
		or chapel_bounds.position.y < -0.02
		or fixture_bounds.position.x < -7.01
		or fixture_bounds.end.x > 7.01
		or fixture_bounds.position.z < -7.01
		or fixture_bounds.end.z > 7.01
	):
		_fail("Chapel art/fixture bounds escaped the 14x14 m lot or shell sank below grade: %s / %s" % [chapel_bounds, fixture_bounds])
		return

	art.call("apply_roof_camera_distance", 70.0, 1.0)
	var far_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	var roof := art.get_node_or_null("Roof") as Node3D
	var roof_truss := visuals.get_node_or_null("ChapelLevelTwoRoofTruss") as Node3D
	var stained_window := visuals.get_node_or_null("ChapelLevelTwoStainedWindow") as Node3D
	var bell_rack := visuals.get_node_or_null("ChapelLevelTwoBellRack") as Node3D
	var far_roof_materials_ok := _subtree_alpha_at_least(roof, 0.99)
	var far_truss_materials_ok := _subtree_alpha_at_least(roof_truss, 0.99)
	var far_bell_materials_ok := _subtree_alpha_at_least(bell_rack, 0.99)
	if (
		float(far_snapshot.get("roof_opacity", 0.0)) < 0.99
		or float(far_snapshot.get("exterior_opacity", 0.0)) < 0.99
		or not far_roof_materials_ok
		or not far_truss_materials_ok
		or not far_bell_materials_ok
	):
		_fail("Chapel far shell or Lv.2 roof structures are not fully opaque: %s" % JSON.stringify({"snapshot": far_snapshot, "roof": far_roof_materials_ok, "truss": far_truss_materials_ok, "bell": far_bell_materials_ok}))
		return
	art.call("apply_roof_camera_distance", 58.0, 0.0)
	var near_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	var near_roof_materials_ok := _subtree_alpha_at_most(roof, 0.07)
	var near_truss_materials_ok := _subtree_alpha_at_most(roof_truss, 0.07)
	var near_window_materials_ok := _subtree_alpha_at_most(stained_window, 0.07)
	var near_bell_materials_ok := _subtree_alpha_at_most(bell_rack, 0.07)
	var near_roof_shadows_ok := _subtree_persistent_shadow_split(roof)
	var near_truss_shadows_ok := _subtree_persistent_shadow_split(roof_truss)
	var near_bell_shadows_ok := _subtree_persistent_shadow_split(bell_rack)
	if (
		float(near_snapshot.get("roof_opacity", 1.0)) > 0.07
		or float(near_snapshot.get("exterior_opacity", 1.0)) > 0.07
		or not bool(near_snapshot.get("interior_revealed_for_selection", false))
		or not near_roof_materials_ok
		or not near_truss_materials_ok
		or not near_window_materials_ok
		or not near_bell_materials_ok
		or not near_roof_shadows_ok
		or not near_truss_shadows_ok
		or not near_bell_shadows_ok
	):
		_fail("Chapel near shell, wall attachments or roof truss did not join the transparent selection chain: %s" % JSON.stringify({"snapshot": near_snapshot, "roof_alpha": near_roof_materials_ok, "truss_alpha": near_truss_materials_ok, "window_alpha": near_window_materials_ok, "bell_alpha": near_bell_materials_ok, "roof_shadow": near_roof_shadows_ok, "truss_shadow": near_truss_shadows_ok, "bell_shadow": near_bell_shadows_ok, "truss_failures": _subtree_alpha_failures(roof_truss, 0.07), "window_failures": _subtree_alpha_failures(stained_window, 0.07), "bell_failures": _subtree_alpha_failures(bell_rack, 0.07)}))
		return
	if not await _verify_transparent_click_contract(art, npc_system, building_system):
		return

	var priest := _get_npc_node(npc_system, "priest_01") as CharacterBody3D
	if priest == null or not await _verify_actor_operated_door(art, priest):
		return

	art.call("debug_force_visual_level", 1)
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	print("T0131-P2R3 medieval chapel building slice verification passed: %s" % JSON.stringify({
		"level_one_fixtures": 11,
		"level_two_fixtures": 16,
		"fixed_capacity": "altar_1+prayer_seat_10",
		"bounds": chapel_bounds,
		"fixture_bounds": fixture_bounds,
		"door": "2.08x2.35_auto_double_leaf",
		"fade_range": "70_to_58"
	}))
	main.queue_free()
	await process_frame
	quit(0)


func _verify_level_one(art: Node3D, snapshot: Dictionary, visuals: Node, collisions: Node) -> bool:
	var required_paths := [
		"Exterior/NaveWallShell/FrontDoorArch",
		"Exterior/StonePlinthAndQuoins",
		"Exterior/FrontGableMasonry",
		"Exterior/FrontPointedPortal",
		"Exterior/FrontOculus",
		"Exterior/SideLancetWindows",
		"Exterior/SanctuaryApse",
		"Exterior/FrontCrossStem",
		"Roof/WestNaveSlate",
		"Roof/EastNaveSlate",
		"Roof/SlateCourses",
		"Interior/Level1Details/WestWallBanner",
		"Interior/Level1Details/WestVotiveCandles",
		"Interior/Level1Details/OfferingChest",
		"Interior/Level1Details/HolyWaterBasin",
		"Interior/Level1Details/SacristyChalice",
		"Interior/Level1Details/SanctuaryWarmLight",
		"Exterior/AutoDoor"
	]
	for path in required_paths:
		if art.get_node_or_null(path) == null:
			return _expect(false, "Chapel Lv.1 lacks professional shell/interior element: %s" % path)
	for removed_path in [
		"Exterior/FrontStoneLintel",
		"Exterior/FrontGableFasciaLeft",
		"UpgradeVisuals/Level2/ExteriorAdditions/BellCanopyBeam"
	]:
		if art.get_node_or_null(removed_path) != null:
			return _expect(false, "Factory-like chapel element survived P2R: %s" % removed_path)
	if not _verify_transverse_roof_joints(art):
		return false
	var additions: Dictionary = snapshot.get("level_visual_addition_counts", {})
	var palette := snapshot.get("palette", {}) as Dictionary
	return _expect(
		int(snapshot.get("maximum_level", 0)) == 2
		and str(snapshot.get("architectural_style", "")) == "medieval_border_chapel"
		and str(snapshot.get("facade_profile", "")) == "front_gable_pointed_portal_and_oculus"
		and float(snapshot.get("roof_pitch_degrees", 0.0)) >= 30.0
		and str(palette.get("roof", "")) == "65717a"
		and str(palette.get("door", "")) == "552d39"
		and not bool(snapshot.get("level_2_visible", true))
		and not bool(snapshot.get("level_3_exists", true))
		and int(snapshot.get("altar_count", 0)) == 1
		and int(snapshot.get("prayer_seat_count", 0)) == 10
		and int(snapshot.get("active_fixture_visual_count", 0)) == 11
		and int(snapshot.get("active_fixture_collision_count", 0)) == 11
		and _active_visual_count(visuals) == 11
		and _active_collision_count(collisions) == 11
		and int(additions.get("level_1", 0)) >= 80,
		"Chapel Lv.1 must expose a complete shell plus fixed altar 1 + prayer seat 10"
	)


func _verify_level_two(art: Node3D, snapshot: Dictionary, visuals: Node, collisions: Node) -> bool:
	for path in [
		"UpgradeVisuals/Level2/ExteriorAdditions/WestBellTower",
		"UpgradeVisuals/Level2/ExteriorAdditions/ButtressCaps",
		"UpgradeVisuals/Level2/ExteriorAdditions/StoneBeltCourses",
		"UpgradeVisuals/Level2/ExteriorAdditions/SanctuaryWindowTracery",
		"UpgradeVisuals/Level2/InteriorAdditions/ReliquaryChest",
		"UpgradeVisuals/Level2/InteriorAdditions/ProcessionalBook",
		"UpgradeVisuals/Level2/InteriorAdditions/ProcessionalBannerLeft",
		"UpgradeVisuals/Level2/RoofStructureAdditions/BellTowerRoof",
		"UpgradeVisuals/Level2/RoofStructureAdditions/RoofCrest",
		"UpgradeVisuals/Level2/RoofStructureAdditions/SanctuaryCollarBeam"
	]:
		if art.get_node_or_null(path) == null:
			return _expect(false, "Chapel Lv.2 lacks upgrade presentation: %s" % path)
	for religious_marker_path in [
		"Exterior/FrontCrossStem",
		"Exterior/FrontCrossArm",
		"UpgradeVisuals/Level2/RoofStructureAdditions/BellTowerRoof/TowerCrossStem",
		"UpgradeVisuals/Level2/RoofStructureAdditions/BellTowerRoof/TowerCrossArm"
	]:
		if art.get_node_or_null(religious_marker_path) == null:
			return _expect(false, "Chapel lost a meaningful religious marker: %s" % religious_marker_path)
	var roof_crest := art.get_node_or_null("UpgradeVisuals/Level2/RoofStructureAdditions/RoofCrest") as Node3D
	var roof_crest_authored_meshes := 0
	if roof_crest != null:
		for raw_mesh in roof_crest.find_children("*", "MeshInstance3D", true, false):
			if not bool(raw_mesh.get_meta("persistent_shell_shadow_proxy", false)) and not bool(raw_mesh.get_meta("portrait_opaque_shell_proxy", false)):
				roof_crest_authored_meshes += 1
	if roof_crest == null or roof_crest_authored_meshes != 5:
		return _expect(false, "Chapel must restore exactly five short gold ridge finials")
	for fixture_name in [
		"ChapelLevelTwoBellRack",
		"ChapelLevelTwoStainedWindow",
		"ChapelLevelTwoWestButtress",
		"ChapelLevelTwoEastButtress",
		"ChapelLevelTwoRoofTruss"
	]:
		var fixture := visuals.get_node_or_null(fixture_name) as Node3D
		if fixture == null or not fixture.visible:
			return _expect(false, "Chapel Lv.2 fixture is missing or hidden: %s" % fixture_name)
	var bell_rack := visuals.get_node_or_null("ChapelLevelTwoBellRack") as Node3D
	var additions := snapshot.get("level_visual_addition_counts", {}) as Dictionary
	return _expect(
		bool(snapshot.get("level_2_visible", false))
		and str(snapshot.get("level_two_upgrade_profile", "")) == "west_bell_tower_stained_glass_buttress_and_ritual_enrichment"
		and not bool(snapshot.get("level_3_exists", true))
		and int(snapshot.get("altar_count", 0)) == 1
		and int(snapshot.get("prayer_seat_count", 0)) == 10
		and int(snapshot.get("active_fixture_visual_count", 0)) == 16
		and int(snapshot.get("active_fixture_collision_count", 0)) == 16
		and _active_visual_count(visuals) == 16
		and _active_collision_count(collisions) == 16
		and bell_rack != null
		and bell_rack.position.y >= 2.95
		and int(additions.get("level_2", 0)) >= 35
		and bool(snapshot.get("roof_structure_additions_fade_with_roof", false)),
		"Chapel Lv.2 must add church detail without inventing capacity: %s" % JSON.stringify({
			"snapshot": snapshot,
			"active_visuals": _active_visual_count(visuals),
			"active_collisions": _active_collision_count(collisions),
			"bell_position": bell_rack.position if bell_rack != null else Vector3.ZERO
		})
	)


func _verify_transverse_roof_joints(art: Node3D) -> bool:
	var west_slope := art.get_node_or_null("Roof/WestNaveSlate") as MeshInstance3D
	var east_slope := art.get_node_or_null("Roof/EastNaveSlate") as MeshInstance3D
	var courses := art.get_node_or_null("Roof/SlateCourses") as Node3D
	if west_slope == null or east_slope == null or courses == null:
		return _expect(false, "Chapel roof slope or slate-course root is missing")
	var west_count := 0
	var east_count := 0
	for raw_child in courses.get_children():
		if not raw_child is MeshInstance3D:
			continue
		var seam := raw_child as MeshInstance3D
		var expected_slope: MeshInstance3D = null
		if seam.name.begins_with("WestSlateJoint"):
			west_count += 1
			expected_slope = west_slope
		elif seam.name.begins_with("EastSlateJoint"):
			east_count += 1
			expected_slope = east_slope
		else:
			continue
		var seam_mesh := seam.mesh as BoxMesh
		if seam_mesh == null or seam_mesh.size.y > 0.0201:
			return _expect(false, "Chapel transverse slate joint is too thick: %s" % seam.name)
		var alignment := seam.global_basis.x.normalized().dot(expected_slope.global_basis.x.normalized())
		if alignment < 0.999:
			return _expect(false, "Chapel transverse slate joint cuts across its roof slope: %s alignment=%.5f" % [seam.name, alignment])
	return _expect(
		west_count == 7 and east_count == 7,
		"Chapel must keep exactly seven flush transverse joints per roof slope: west=%d east=%d" % [west_count, east_count]
	)


func _verify_actor_operated_door(art: Node3D, actor: CharacterBody3D) -> bool:
	var door := art.get_node_or_null("Exterior/AutoDoor") as Node3D
	if door == null or not door.has_method("debug_get_snapshot"):
		return _expect(false, "Chapel auto door is missing")
	var contract: Dictionary = door.call("debug_get_snapshot")
	if not _expect(
		float(contract.get("clear_width", 0.0)) >= 1.8
		and float(contract.get("clear_height", 0.0)) >= 2.2
		and bool(contract.get("centerline_clear", false))
		and not bool(contract.get("blocking_collision", true))
		and int(contract.get("actor_collision_mask", 0)) == 2,
		"Chapel auto door violates the shared visible doorway contract"
	):
		return false
	if not _expect((actor.collision_layer & 2) != 0, "Marcel is not a physical layer-2 actor"):
		return false
	actor.set_physics_process(false)
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 1.5))
	for _frame in range(32):
		await physics_frame
	var opened: Dictionary = door.call("debug_get_snapshot")
	if not _expect(
		int(opened.get("overlapping_actor_count", 0)) >= 1
		and bool(opened.get("open_requested", false))
		and float(opened.get("open_fraction", 0.0)) >= 0.95,
		"Chapel door did not open for the approaching priest"
	):
		return false
	var left_bounds := _subtree_bounds_in_space(door.get_node("LeftHinge/LeftLeaf"), door, false)
	var right_bounds := _subtree_bounds_in_space(door.get_node("RightHinge/RightLeaf"), door, false)
	if not _expect(
		left_bounds.end.x <= -0.75 and right_bounds.position.x >= 0.75,
		"Chapel open door leaves intrude into the central passage"
	):
		return false
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 8.0))
	for _frame in range(78):
		await physics_frame
	var closed: Dictionary = door.call("debug_get_snapshot")
	return _expect(
		int(closed.get("overlapping_actor_count", -1)) == 0
		and not bool(closed.get("open_requested", true))
		and float(closed.get("open_fraction", 1.0)) <= 0.05,
		"Chapel door did not close after the priest left"
	)


func _verify_transparent_click_contract(art: Node3D, npc_system: Node, building_system: Node) -> bool:
	var ray_hit: Dictionary = art.call(
		"get_building_interaction_ray_hit",
		art.global_position + Vector3(4.7, 20.0, 4.7),
		art.global_position + Vector3(4.7, -5.0, 4.7)
	)
	if not _expect(
		str(ray_hit.get("building_id", "")) == "chapel"
		and bool(ray_hit.get("interior_revealed", false)),
		"Transparent chapel does not preserve the empty-space building fallback"
	):
		return false
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if not _expect(camera != null, "Chapel click camera is missing"):
		return false
	if not _expect(
		bool(npc_system.call("debug_enter_location_immediately", "priest_01", "chapel", false)),
		"Could not place Marcel inside the chapel for click verification"
	):
		return false
	var priest := _get_npc_node(npc_system, "priest_01") as Node3D
	if not _expect(priest != null, "Marcel world node is missing for click verification"):
		return false
	priest.global_position = art.to_global(Vector3.ZERO)
	await physics_frame
	var priest_screen := camera.unproject_position(priest.global_position + Vector3(0.0, 1.0, 0.0))
	if not _expect(
		bool(building_system.call("_try_select_interior_npc", priest_screen, "chapel")),
		"Transparent chapel did not route exact NPC clicks to Marcel"
	):
		return false
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	if not _expect(
		bool(npc_system.call("_is_npc_hidden_by_opaque_building", "priest_01")),
		"Opaque chapel did not restore building-first click priority"
	):
		return false
	art.call("apply_roof_camera_distance", 58.0, 0.0)
	if not _expect(
		not bool(npc_system.call("_is_npc_hidden_by_opaque_building", "priest_01")),
		"Transparent chapel still hides Marcel from click selection"
	):
		return false
	var empty_screen := camera.unproject_position(art.to_global(Vector3(4.7, 0.0, 4.7)))
	return _expect(
		not bool(building_system.call("_try_select_interior_npc", empty_screen, "chapel")),
		"Transparent chapel empty-space click incorrectly selected an NPC instead of the building"
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


func _subtree_alpha_at_least(root_node: Node, threshold: float) -> bool:
	return _subtree_material_alpha_matches(root_node, threshold, true)


func _subtree_alpha_at_most(root_node: Node, threshold: float) -> bool:
	return _subtree_material_alpha_matches(root_node, threshold, false)


func _subtree_material_alpha_matches(root_node: Node, threshold: float, at_least: bool) -> bool:
	if root_node == null:
		return false
	var mesh_count := 0
	var nodes: Array[Node] = [root_node]
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		for child in current.get_children(true):
			nodes.append(child)
		if not current is MeshInstance3D:
			continue
		var mesh := current as MeshInstance3D
		if mesh.mesh == null or bool(mesh.get_meta("persistent_shell_shadow_proxy", false)) or bool(mesh.get_meta("portrait_opaque_shell_proxy", false)):
			continue
		mesh_count += 1
		for surface_index in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface_index) as BaseMaterial3D
			if material == null:
				continue
			if at_least and material.albedo_color.a < threshold:
				return false
			if not at_least and material.albedo_color.a > threshold:
				return false
	return mesh_count > 0


func _subtree_alpha_failures(root_node: Node, threshold: float) -> Array:
	var failures: Array = []
	if root_node == null:
		return failures
	var nodes: Array[Node] = [root_node]
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		for child in current.get_children():
			nodes.append(child)
		if not current is MeshInstance3D:
			continue
		var mesh := current as MeshInstance3D
		if mesh.mesh == null or bool(mesh.get_meta("persistent_shell_shadow_proxy", false)) or bool(mesh.get_meta("portrait_opaque_shell_proxy", false)):
			continue
		for surface_index in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface_index) as BaseMaterial3D
			if material != null and material.albedo_color.a > threshold:
				failures.append({"path": str(root_node.get_path_to(mesh)), "surface": surface_index, "alpha": material.albedo_color.a})
	return failures


func _subtree_persistent_shadow_split(root_node: Node) -> bool:
	if root_node == null:
		return false
	var visible_mesh_count := 0
	var proxy_count := 0
	var nodes: Array[Node] = [root_node]
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		for child in current.get_children(true):
			nodes.append(child)
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var mesh := current as MeshInstance3D
			if bool(mesh.get_meta("portrait_opaque_shell_proxy", false)):
				continue
			if bool(mesh.get_meta("persistent_shell_shadow_proxy", false)):
				proxy_count += 1
				if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
					return false
			else:
				visible_mesh_count += 1
				if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					return false
	return visible_mesh_count > 0 and proxy_count > 0


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
						var local_corner := mesh_bounds.position + Vector3(
							mesh_bounds.size.x * float(x_index),
							mesh_bounds.size.y * float(y_index),
							mesh_bounds.size.z * float(z_index)
						)
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
