extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const MAIN_HALL_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall"
const EXPECTED_FIXTURE_COUNTS := [1, 2, 3, 4, 5, 7]
const EXPECTED_DEVICE_CAPACITY := [1, 1, 2, 2, 3, 4]

var _failed := false


func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _step in 4:
		await process_frame
		await physics_frame

	var hall := root.get_node_or_null(MAIN_HALL_PATH) as Node3D
	var art := hall.get_node_or_null("MainHallArt") if hall != null else null
	var envelope := hall.get_node_or_null("Envelope") as MeshInstance3D if hall != null else null
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var defense_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var station_layout_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var device_presenter := root.get_node_or_null("Main/WorldRoot/Station/DefenseDevices")
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if hall == null or art == null or envelope == null or building_system == null or defense_system == null or resource_system == null or station_layout_controller == null or device_presenter == null or camera == null:
		_fail("T0132-P1 main hall runtime hierarchy is incomplete")
		return
	if envelope.visible or str(art.get_meta("art_revision", "")) != "t0132_p1r5":
		_fail("Formal main hall did not replace the legacy envelope")
		return
	if not bool(art.get_meta("solid_visual_mass", false)) or not bool(art.get_meta("load_bearing_roof_deck", false)):
		_fail("Main hall lost its closed textured mass or load-bearing roof deck contract")
		return
	for required_path in [
		"BaseVisuals/Exterior/SolidMainHallMass",
		"BaseVisuals/Exterior/SolidMainHallMass/LowerMasonryCore",
		"BaseVisuals/Exterior/SolidMainHallMass/PlasterCommandBody",
		"BaseVisuals/Exterior/SolidMainHallMass/RoofBearingDeck",
		"BaseVisuals/Exterior/SolidMainHallMass/CentralCommandKeep/KeepMasonryCore",
		"BaseVisuals/Exterior/TexturedFacadeModules/FrontDoor",
		"BaseVisuals/Exterior/LoadBearingDefenseTerrace",
		"Roof/CentralKeepRoof",
		"Roof/FrontGatehouseRoof"
	]:
		if art.get_node_or_null(required_path) == null:
			_fail("Solid textured main hall structure is incomplete: %s" % required_path)
			return
	var exterior := art.get_node("BaseVisuals/Exterior") as Node3D
	var textured_wall_module_count := _count_textured_wall_modules(exterior)
	if textured_wall_module_count < 50:
		_fail("Main hall textured facade modules are incomplete: %d modules" % textured_wall_module_count)
		return
	if _count_textured_surfaces(exterior) < textured_wall_module_count * 3 + 8:
		_fail("Main hall solid mass or facade modules lost their Quaternius textures")
		return
	for raw_mesh in exterior.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh is BoxMesh:
			var box_size := (mesh_instance.mesh as BoxMesh).size
			if box_size.x > 4.0 and box_size.z > 4.0 and not _mesh_has_albedo_texture(mesh_instance):
				_fail("Large main hall structural mass is not textured: %s / %s" % [mesh_instance.get_path(), box_size])
				return
	if art.find_children("FrontTimberPost*", "MeshInstance3D", true, false).size() < 10:
		_fail("Main facade timber segmentation is incomplete")
		return
	if not art.find_children("FrontStoneBrace*", "MeshInstance3D", true, false).is_empty():
		_fail("Rejected Lv.2 front window-blocking stone braces returned")
		return
	var level_four_fixture := hall.get_node_or_null("FixtureLayout/Visuals/MainHallLevelFourRoofBrace") as Node3D
	var level_six_fixture := hall.get_node_or_null("FixtureLayout/Visuals/MainHallLevelSixTowerReinforcement") as Node3D
	if level_four_fixture == null or level_four_fixture.get_node_or_null("GarrisonSwallowtailPennant") == null or level_four_fixture.get_node_or_null("GarrisonPennantMast") == null or str(level_four_fixture.get_meta("architectural_role", "")) != "ridge_mounted_garrison_pennant":
		_fail("Lv.4 main hall roof upgrade is not a ridge-mounted medieval garrison pennant")
		return
	if level_four_fixture.get_node_or_null("RoofCore") != null or level_four_fixture.find_children("*Brazier*", "Node3D", true, false).size() > 0 or level_four_fixture.find_children("*Flame*", "Node3D", true, false).size() > 0 or level_four_fixture.find_children("*Ember*", "Node3D", true, false).size() > 0:
		_fail("Rejected Lv.4 grey cube, fire equipment, or warning-beacon silhouette returned")
		return
	if level_four_fixture.get_node_or_null("RidgeMasonrySaddle") == null or level_four_fixture.get_node_or_null("PennantIronFoot") == null or level_four_fixture.find_children("PennantRopeTie*", "MeshInstance3D", true, false).size() != 2:
		_fail("Lv.4 garrison pennant lacks a plausible ridge saddle, iron foot, or rope ties")
		return
	if level_six_fixture == null or level_six_fixture.get_node_or_null("CommandTowerSolidCore") == null or level_six_fixture.get_node_or_null("CommandTowerRoof") == null or level_six_fixture.find_children("CommandTowerFrontWall*", "Node3D", true, false).size() < 2:
		_fail("Lv.6 gatehouse command tower lost its solid body, facade, or matching roof")
		return
	if _count_textured_surfaces(art.get_node("Roof")) < 4:
		_fail("Main hall roofs must retain imported tile textures")
		return
	for platform_center in [Vector2(-7.0, -5.0), Vector2(7.0, -5.0), Vector2(-7.0, 5.0), Vector2(7.0, 5.0)]:
		if _art_overlaps_platform_clearance(art, platform_center):
			_fail("Main hall roof or upper mass blocks a formal 3.6x3.6 defense platform: %s" % platform_center)
			return
	if not art.exterior_albedo_tint.is_equal_approx(Color.WHITE):
		_fail("Main hall exterior tint may not restore the rejected pale-blue cast")
		return
	if building_system.is_building_enterable("main_hall"):
		_fail("Main hall must remain non-enterable")
		return
	var authority_before: Dictionary = building_system.get_building("main_hall").duplicate(true)
	if not (authority_before.get("workstations", []) as Array).is_empty():
		_fail("Main hall must keep zero NPC workstations")
		return

	for level_index in range(6):
		var level := level_index + 1
		art.call("debug_force_visual_level", level)
		await process_frame
		await physics_frame
		var snapshot: Dictionary = art.call("get_art_slice_snapshot")
		if int(snapshot.get("building_level", 0)) != level:
			_fail("Main hall visual preview level drifted: %s" % JSON.stringify(snapshot))
			return
		if int(snapshot.get("active_fixture_visual_count", -1)) != EXPECTED_FIXTURE_COUNTS[level_index]:
			_fail("Main hall fixture visual progression drifted at level %d: %s" % [level, JSON.stringify(snapshot)])
			return
		if int(snapshot.get("active_fixture_collision_count", -1)) != EXPECTED_FIXTURE_COUNTS[level_index]:
			_fail("Main hall fixture collision progression drifted at level %d: %s" % [level, JSON.stringify(snapshot)])
			return
		for cumulative_level in range(2, 7):
			var level_root := art.get_node_or_null("UpgradeVisuals/Level%d" % cumulative_level) as Node3D
			if level_root == null or level_root.visible != (level >= cumulative_level):
				_fail("Main hall cumulative level layer drifted: current %d / layer %d" % [level, cumulative_level])
				return

	var device_capacity: Array[int] = []
	for level in range(1, 7):
		var count := 0
		for raw_slot in defense_system.get_slots_for_building("main_hall", true):
			if int((raw_slot as Dictionary).get("required_building_level", 99)) <= level:
				count += 1
		device_capacity.append(count)
	if device_capacity != EXPECTED_DEVICE_CAPACITY:
		_fail("Main hall authoritative defense capacity drifted: %s" % device_capacity)
		return
	var defense_snapshot: Dictionary = defense_system.get_state_snapshot()
	if str(defense_snapshot.get("slot_spatial_binding", "")) != "formal_station_fixture":
		_fail("DefenseDeviceSystem still uses legacy main-hall coordinates: %s" % JSON.stringify(defense_snapshot))
		return
	for platform_index in range(4):
		var slot_id := "main_hall_slot_%02d" % (platform_index + 1)
		var platform := hall.get_node_or_null("FixtureLayout/Visuals/MainHallSlot%02dPlatform" % (platform_index + 1)) as Node3D
		var slot: Dictionary = defense_system.get_slot(slot_id)
		var slot_position := _to_vector3(slot.get("position", {}))
		if platform == null or str(slot.get("spatial_source", "")) != "formal_station_fixture":
			_fail("Formal defense platform binding is incomplete: %s" % slot_id)
			return
		var expected_position := platform.global_position + Vector3(0.0, 0.88, 0.0)
		if slot_position.distance_to(expected_position) > 0.02:
			_fail("Defense slot does not land on its visible platform: %s / %s != %s" % [slot_id, slot_position, expected_position])
			return
	resource_system.add_resource("item_wall_arrow_tower", 1)
	var deployment_result: Dictionary = defense_system.deploy_device("wall_arrow_tower", "main_hall_slot_03")
	if not bool(deployment_result.get("ok", false)):
		_fail("Could not deploy a tower onto the Lv.1 visible platform: %s" % JSON.stringify(deployment_result))
		return
	await process_frame
	var deployment_view := device_presenter.call("get_view_for_deployment", str(deployment_result.get("deployment_id", ""))) as Node3D
	var deployed_position := _to_vector3((deployment_result.get("deployment", {}) as Dictionary).get("position", {}))
	if deployment_view == null or deployment_view.global_position.distance_to(deployed_position) > 0.02:
		_fail("Deployed tower view did not appear on the formal main-hall platform")
		return

	art.call("apply_roof_camera_distance", 10.0, 1.0)
	var near_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	art.call("apply_roof_camera_distance", 80.0, 0.0)
	var far_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	if float(near_snapshot.get("roof_opacity", 0.0)) < 0.99 or float(far_snapshot.get("roof_opacity", 0.0)) < 0.99:
		_fail("Non-enterable main hall roof must remain opaque at every camera distance")
		return
	if bool(art.call("is_interior_revealed_for_selection")):
		_fail("Non-enterable main hall must never claim interior selection priority")
		return
	var screen_point := camera.unproject_position(art.to_global(Vector3(0.0, 3.0, 0.0)))
	var art_hit: Dictionary = building_system._pick_building_art_view_at_screen_position(screen_point)
	if str(art_hit.get("building_id", "")) != "main_hall" or bool(art_hit.get("interior_revealed", true)):
		_fail("Camera-visible main hall point does not resolve to its non-interior click target: %s" % JSON.stringify(art_hit))
		return

	var mild_damage: Dictionary = art.call("debug_force_damage_ratio", 0.7)
	var heavy_damage: Dictionary = art.call("debug_force_damage_ratio", 0.3)
	var repaired: Dictionary = art.call("debug_force_damage_ratio", 1.0)
	if not bool(mild_damage.get("mild_damage_visible", false)) or bool(mild_damage.get("heavy_damage_visible", true)):
		_fail("Mild main hall damage projection drifted")
		return
	if not bool(heavy_damage.get("mild_damage_visible", false)) or not bool(heavy_damage.get("heavy_damage_visible", false)):
		_fail("Heavy main hall damage projection drifted")
		return
	if bool(repaired.get("mild_damage_visible", true)) or bool(repaired.get("heavy_damage_visible", true)):
		_fail("Repaired main hall did not clear damage dressing")
		return

	var bounds := _combined_mesh_bounds(art)
	if bounds.size == Vector3.ZERO or bounds.position.x < -11.01 or bounds.end.x > 11.01 or bounds.position.z < -9.01 or bounds.end.z > 9.01:
		_fail("Main hall visible art escaped its 22x18 envelope: %s" % bounds)
		return
	var authority_after: Dictionary = building_system.get_building("main_hall")
	if int(authority_after.get("level", -1)) != int(authority_before.get("level", -2)) or int(authority_after.get("hp", -1)) != int(authority_before.get("hp", -2)):
		_fail("Main hall art preview mutated BuildingSystem authority")
		return

	print("T0132-P1 main hall building slice verification passed: %s" % JSON.stringify({
		"fixture_counts": EXPECTED_FIXTURE_COUNTS,
		"device_capacity": EXPECTED_DEVICE_CAPACITY,
		"bounds": str(bounds),
		"damage_projection": "mild_heavy_repaired",
		"authority_level": int(authority_after.get("level", 0)),
		"slot_spatial_binding": str(defense_snapshot.get("slot_spatial_binding", "")),
		"deployed_tower_position": str(deployed_position)
	}))
	quit(0)


func _combined_mesh_bounds(node: Node3D) -> AABB:
	var has_bounds := false
	var result := AABB()
	for raw_mesh in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		var transformed := (node.global_transform.affine_inverse() * mesh_instance.global_transform) * mesh_instance.get_aabb()
		result = transformed if not has_bounds else result.merge(transformed)
		has_bounds = true
	return result if has_bounds else AABB()


func _count_textured_wall_modules(root_node: Node) -> int:
	var count := 0
	for raw_node in root_node.find_children("*", "Node3D", true, false):
		var node_name := str(raw_node.name)
		if node_name.begins_with("OuterFrontWall_") or node_name.begins_with("OuterRearWall_") or node_name.begins_with("OuterWestWall_") or node_name.begins_with("OuterEastWall_") or node_name.begins_with("KeepFrontWall_") or node_name.begins_with("KeepRearWall_") or node_name.begins_with("KeepSide_") or node_name == "FrontDoor":
			count += 1
	return count


func _count_textured_surfaces(root_node: Node) -> int:
	var count := 0
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index)
			if material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture != null:
				count += 1
	return count


func _mesh_has_albedo_texture(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance == null or mesh_instance.mesh == null:
		return false
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var material := mesh_instance.get_active_material(surface_index)
		if material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture != null:
			return true
	return false


func _art_overlaps_platform_clearance(art: Node3D, center: Vector2) -> bool:
	var clearance := AABB(Vector3(center.x - 1.72, 3.08, center.y - 1.72), Vector3(3.44, 8.0, 3.44))
	for branch_path in ["BaseVisuals", "Roof"]:
		var branch := art.get_node_or_null(branch_path)
		if branch == null:
			continue
		for raw_mesh in branch.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := raw_mesh as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
				continue
			var local_transform := art.global_transform.affine_inverse() * mesh_instance.global_transform
			if (local_transform * mesh_instance.get_aabb()).intersects(clearance):
				return true
	return false


func _to_vector3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if not raw is Dictionary:
		return Vector3.ZERO
	return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
