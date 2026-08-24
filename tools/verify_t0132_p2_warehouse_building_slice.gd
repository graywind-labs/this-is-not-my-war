extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const EXPECTED_FIXTURE_COUNTS := [5, 6, 7]


func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		_fail("T0132-P2 Main scene unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 5:
		await process_frame
		await physics_frame

	var art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Warehouse/WarehouseArt") as Node3D
	var warehouse := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Warehouse") as Node3D
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel") as Control
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if art == null or warehouse == null or building_system == null or resource_system == null or gm_panel == null or building_panel == null or camera == null:
		_fail("T0132-P2 runtime hierarchy incomplete")
		return
	if (
		str(art.get_meta("art_revision", "")) != "t0132_p2r2"
		or not bool(art.get_meta("non_enterable", false))
		or not bool(art.get_meta("solid_textured_mass", false))
		or str(art.get_meta("cargo_display_authority", "")) != "symbolic_categories_not_inventory_counts"
	):
		_fail("T0132-P2 warehouse authority metadata drifted")
		return
	if building_system.is_building_enterable("warehouse") or not (building_system.get_building("warehouse").get("workstations", []) as Array).is_empty():
		_fail("Warehouse must remain non-enterable with zero NPC workstations")
		return

	var mass := art.get_node_or_null("BaseVisuals/SolidWarehouseMass") as Node3D
	var facade := art.get_node_or_null("BaseVisuals/Exterior/WoodGridFacadeModules") as Node3D
	var roof := art.get_node_or_null("Roof") as Node3D
	if mass == null or facade == null or roof == null or facade.get_child_count() < 12:
		_fail("T0132-P2 closed mass, facade modules, or roof missing")
		return
	for node_path in [
		"BaseVisuals/SolidWarehouseMass/StoneLoadingPlinth",
		"BaseVisuals/SolidWarehouseMass/LowerMasonryStore",
		"BaseVisuals/SolidWarehouseMass/SealedTimberStore",
		"BaseVisuals/SolidWarehouseMass/RoofBearingCap",
		"BaseVisuals/Exterior/LoadingDoor/StoneDoorLintel",
		"BaseVisuals/Exterior/LoadingDoor/HoistPulley",
		"BaseVisuals/LoadingApron/StoneRamp",
		"Roof/ContinuousMainRoof",
		"Roof/LoadingCanopy",
		"UpgradeVisuals/Level2/EastSideStoreWall",
		"UpgradeVisuals/Level2/EastSideStoreRoof",
		"UpgradeVisuals/Level3/SecuredUpperLoft",
		"UpgradeVisuals/Level3/UpperLoftQuaterniusRoof",
		"UpgradeVisuals/Level3/RoofVent"
	]:
		if art.get_node_or_null(node_path) == null:
			_fail("T0132-P2 architectural component missing: %s" % node_path)
			return
	for raw_mesh in mass.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		if mesh == null or mesh.mesh == null or not bool(mesh.get_meta("solid_visual_volume", false)):
			_fail("T0132-P2 solid mass contains non-audited geometry")
			return
		var material := mesh.get_active_material(0) as BaseMaterial3D
		if material == null or material.albedo_texture == null:
			_fail("T0132-P2 solid mass is missing a real texture: %s" % mesh.name)
			return
	var complete_roof_modules := 0
	for raw_child in roof.get_children():
		if str(raw_child.name) == "ContinuousMainRoof":
			complete_roof_modules += 1
		if str(raw_child.name).begins_with("QuaterniusRoofBay"):
			_fail("T0132-P2R repeated complete roof bay returned: %s" % raw_child.name)
			return
	if complete_roof_modules != 1:
		_fail("T0132-P2R continuous main roof count drifted: %d" % complete_roof_modules)
		return
	var main_roof := roof.get_node("ContinuousMainRoof") as Node3D
	if str(main_roof.get_meta("roof_profile", "")) != "single_continuous_ridge" or int(main_roof.get_meta("complete_roof_module_count", 0)) != 1:
		_fail("T0132-P2R main roof continuity metadata drifted")
		return
	if str(art.get_meta("roof_palette", "")) != "desaturated_smoked_grey_brown" or not art.roof_albedo_override.is_equal_approx(Color("#8a8179")):
		_fail("T0132-P2R2 warehouse roof palette drifted")
		return
	for roof_path in ["Roof/ContinuousMainRoof", "UpgradeVisuals/Level2/EastSideStoreRoof", "UpgradeVisuals/Level3/UpperLoftQuaterniusRoof"]:
		var roof_part := art.get_node(roof_path) as Node3D
		if not _subtree_uses_muted_textured_roof(roof_part):
			_fail("T0132-P2R2 roof is vivid or lost its native texture: %s" % roof_path)
			return

	var authoritative_before: Dictionary = building_system.get_building("warehouse").duplicate(true)
	var capacity_before: Array[Dictionary] = resource_system.get_warehouse_capacity_snapshot()
	var level_counts: Array[int] = []
	for level in [1, 2, 3]:
		art.debug_force_visual_level(level)
		var snapshot: Dictionary = art.get_art_slice_snapshot()
		level_counts.append(int(snapshot.get("active_fixture_visual_count", -1)))
		if (
			int(snapshot.get("active_fixture_visual_count", -1)) != EXPECTED_FIXTURE_COUNTS[level - 1]
			or int(snapshot.get("active_fixture_collision_count", -1)) != EXPECTED_FIXTURE_COUNTS[level - 1]
			or bool(snapshot.get("interior_revealed_for_selection", true))
		):
			_fail("T0132-P2 level projection drifted at level %d: %s" % [level, snapshot])
			return
		var level_2 := art.get_node("UpgradeVisuals/Level2") as Node3D
		var level_3 := art.get_node("UpgradeVisuals/Level3") as Node3D
		if level_2.visible != (level >= 2) or level_3.visible != (level >= 3):
			_fail("T0132-P2 upgrade visibility drifted at level %d" % level)
			return
	art.apply_roof_camera_distance(8.0, 0.0)
	var close_snapshot: Dictionary = art.get_art_slice_snapshot()
	if not is_equal_approx(float(close_snapshot.get("roof_opacity", 0.0)), 1.0) or bool(close_snapshot.get("interior_revealed_for_selection", true)):
		_fail("Non-enterable warehouse became transparent at close camera")
		return
	if building_system.get_building("warehouse") != authoritative_before or resource_system.get_warehouse_capacity_snapshot() != capacity_before:
		_fail("Warehouse art preview mutated building or capacity authority")
		return

	art.debug_force_damage_ratio(0.60)
	if not bool(art.get_art_slice_snapshot().get("mild_damage_visible", false)):
		_fail("T0132-P2 mild damage projection missing")
		return
	art.debug_force_damage_ratio(0.25)
	var heavy_snapshot: Dictionary = art.get_art_slice_snapshot()
	if not bool(heavy_snapshot.get("mild_damage_visible", false)) or not bool(heavy_snapshot.get("heavy_damage_visible", false)):
		_fail("T0132-P2 heavy damage projection missing")
		return
	art.debug_force_damage_ratio(1.0)
	if bool(art.get_art_slice_snapshot().get("mild_damage_visible", true)) or bool(art.get_art_slice_snapshot().get("heavy_damage_visible", true)):
		_fail("T0132-P2 repair did not clear damage projection")
		return

	var bounds := _combined_local_bounds(art)
	if bounds.position.x < -7.10 or bounds.end.x > 7.10 or bounds.position.z < -7.10 or bounds.end.z > 7.10 or bounds.position.y < -0.05 or bounds.end.y > 7.05:
		_fail("T0132-P2 art exceeded the 14x14 warehouse envelope: %s" % bounds)
		return
	var ray_origin := warehouse.to_global(Vector3(0.0, 20.0, 0.0))
	var ray_end := warehouse.to_global(Vector3(0.0, -2.0, 0.0))
	var hit: Dictionary = art.get_building_interaction_ray_hit(ray_origin, ray_end)
	if str(hit.get("building_id", "")) != "warehouse" or bool(hit.get("interior_revealed", true)):
		_fail("T0132-P2 building click projection drifted: %s" % hit)
		return
	var screen_point := camera.unproject_position(art.to_global(Vector3(0.0, 2.8, 0.0)))
	var art_hit: Dictionary = building_system._pick_building_art_view_at_screen_position(screen_point)
	if str(art_hit.get("building_id", "")) != "warehouse" or bool(art_hit.get("interior_revealed", true)):
		_fail("Camera-visible warehouse point does not resolve to its building panel target: %s" % art_hit)
		return
	var click := InputEventMouseButton.new()
	click.position = screen_point
	click.global_position = screen_point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	building_system._unhandled_input(click)
	if not building_panel.visible or str(building_panel._current_building_id) != "warehouse":
		_fail("Production building click handler did not open the warehouse panel")
		return
	for level in [1, 2, 3]:
		if gm_panel.find_child("WarehouseArtLevel%dButton" % level, true, false) == null:
			_fail("T0132-P2 GM preview button missing for level %d" % level)
			return

	var result := {
		"bounds": str(bounds),
		"facade_modules": facade.get_child_count(),
		"fixture_counts": level_counts,
		"complete_roof_modules": complete_roof_modules,
		"workstations": 0
	}
	main.queue_free()
	await process_frame
	print("T0132-P2 warehouse building slice verification passed: %s" % JSON.stringify(result))
	quit(0)


func _combined_local_bounds(root_node: Node3D) -> AABB:
	var initialized := false
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		if mesh == null or mesh.mesh == null or bool(mesh.get_meta("persistent_shell_shadow_proxy", false)):
			continue
		var aabb := mesh.get_aabb()
		for x in [aabb.position.x, aabb.end.x]:
			for y in [aabb.position.y, aabb.end.y]:
				for z in [aabb.position.z, aabb.end.z]:
					var local_point := root_node.to_local(mesh.to_global(Vector3(float(x), float(y), float(z))))
					if not initialized:
						minimum = local_point
						maximum = local_point
						initialized = true
					else:
						minimum = minimum.min(local_point)
						maximum = maximum.max(local_point)
	return AABB(minimum, maximum - minimum)


func _subtree_uses_muted_textured_roof(root_node: Node3D) -> bool:
	var checked := 0
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		if mesh == null or mesh.mesh == null or bool(mesh.get_meta("persistent_shell_shadow_proxy", false)):
			continue
		for surface_index in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface_index) as BaseMaterial3D
			if material == null or material.albedo_texture == null:
				continue
			checked += 1
			if material.albedo_color.s > 0.22 or material.albedo_color.v > 0.62:
				return false
	return checked > 0


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
