extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const DORMITORY_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Dormitory"
const EXPECTED_ASSIGNMENTS := [
	"veteran_deputy_01", "stableman_01", "cook_01", "gardener_01",
	"blacksmith_01", "engineer_01", "priest_01", "doctor_01", "", ""
]


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

	var dormitory := root.get_node_or_null(DORMITORY_PATH) as Node3D
	var art := dormitory.get_node_or_null("DormitoryArt") as Node3D if dormitory != null else null
	var fixture_root := dormitory.get_node_or_null("FixtureLayout") if dormitory != null else null
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if [dormitory, art, fixture_root, building_system, npc_system].has(null):
		_fail("T0131-P5 dormitory runtime hierarchy is incomplete")
		return
	var envelope := dormitory.get_node_or_null("Envelope") as Node3D
	var visuals := fixture_root.get_node_or_null("Visuals")
	var collisions := fixture_root.get_node_or_null("StaticCollision")
	if envelope == null or envelope.visible or visuals == null or collisions == null:
		_fail("Legacy dormitory envelope was not replaced by the formal art slice")
		return

	var authority_before: Dictionary = building_system.get_building("dormitory")
	if int(authority_before.get("level", 0)) != 1 or int((authority_before.get("upgrade", {}) as Dictionary).get("max_level", 0)) != 2:
		_fail("Dormitory authority must remain Lv.1 with a Lv.2 maximum during art preview")
		return
	if not _verify_fixed_bed_authority(authority_before):
		return
	for level in [1, 2]:
		var snapshot: Dictionary = art.call("debug_force_visual_level", level)
		if not _verify_level(art, snapshot, visuals, collisions, level):
			return
	if art.get_node_or_null("UpgradeVisuals/Level3") != null:
		_fail("Dormitory incorrectly presents a third upgrade tier")
		return
	if int(building_system.get_building("dormitory").get("level", 0)) != 1:
		_fail("Dormitory art preview changed the authoritative building level")
		return

	var art_bounds := _subtree_bounds_in_space(art, dormitory, true)
	var fixture_bounds := _subtree_bounds_in_space(visuals, dormitory, true)
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
		_fail("Dormitory art/fixture bounds escaped the 16x14 m lot or sank below grade: %s / %s" % [art_bounds, fixture_bounds])
		return

	var personal_storage := art.get_node_or_null("Interior/Level1Details/OuterWallPersonalStorage") as Node3D
	var storage_bounds := _subtree_bounds_in_space(personal_storage, dormitory, true)
	if personal_storage == null or _direct_subtrees_intersect(personal_storage, visuals, dormitory):
		_fail("Dormitory personal storage overlaps the ten fixed bed volumes: %s / %s" % [storage_bounds, fixture_bounds])
		return
	var wash_basin := art.get_node_or_null("Interior/Level1Details/CommonWashBasin") as Node3D
	var wash_basin_bounds := _subtree_bounds_in_space(wash_basin, dormitory, true)
	if (
		wash_basin == null
		or wash_basin.position.distance_to(Vector3(-1.0, 0.0, -5.78)) > 0.01
		or not _verify_wash_basin_structure(wash_basin)
		or _direct_subtrees_intersect(wash_basin, visuals, dormitory)
	):
		_fail("Dormitory wash basin is missing, misplaced or overlaps a fixed bed: %s" % wash_basin_bounds)
		return
	var door_clearance := AABB(Vector3(-1.1, 0.0, 4.9), Vector3(2.2, 2.6, 2.0))
	var hearth_bounds := _subtree_bounds_in_space(art.get_node_or_null("UpgradeVisuals/Level2/InteriorAdditions/WarmStoneHearth"), dormitory, true)
	var repair_storage_bounds := _subtree_bounds_in_space(art.get_node_or_null("UpgradeVisuals/Level2/InteriorAdditions/ExpandedLinenAndRepairKit"), dormitory, true)
	if hearth_bounds.intersects(door_clearance) or repair_storage_bounds.intersects(door_clearance):
		_fail("Dormitory Lv.2 additions intrude into the doorway clearance")
		return
	if wash_basin_bounds.intersects(hearth_bounds):
		_fail("Dormitory wash basin overlaps the Lv.2 hearth: %s / %s" % [wash_basin_bounds, hearth_bounds])
		return

	var hearth := art.get_node_or_null("UpgradeVisuals/Level2/InteriorAdditions/WarmStoneHearth") as Node3D
	var chimney := art.get_node_or_null("UpgradeVisuals/Level2/RoofStructureAdditions/HearthChimney") as Node3D
	if hearth == null or chimney == null or Vector2(hearth.position.x, hearth.position.z).distance_to(Vector2(chimney.position.x, chimney.position.z)) > 0.01:
		_fail("Dormitory hearth and chimney are not vertically aligned")
		return

	art.call("apply_roof_camera_distance", 70.0, 1.0)
	var far_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	if float(far_snapshot.get("roof_opacity", 0.0)) < 0.99 or float(far_snapshot.get("exterior_opacity", 0.0)) < 0.99:
		_fail("Dormitory far shell is not opaque")
		return
	art.call("apply_roof_camera_distance", 58.0, 0.0)
	var near_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	var roof := art.get_node_or_null("Roof") as Node3D
	var level_two_roof := art.get_node_or_null("UpgradeVisuals/Level2/RoofStructureAdditions") as Node3D
	if (
		float(near_snapshot.get("roof_opacity", 1.0)) > 0.07
		or float(near_snapshot.get("exterior_opacity", 1.0)) > 0.07
		or not bool(near_snapshot.get("interior_revealed_for_selection", false))
		or not _subtree_alpha_at_most(roof, 0.07)
		or not _subtree_alpha_at_most(level_two_roof, 0.07)
	):
		_fail("Dormitory roof, walls or Lv.2 chimney/ties did not join the transparent chain")
		return
	var ray_hit: Dictionary = art.call(
		"get_building_interaction_ray_hit",
		art.global_position + Vector3(6.0, 20.0, 4.5),
		art.global_position + Vector3(6.0, -5.0, 4.5)
	)
	if str(ray_hit.get("building_id", "")) != "dormitory" or not bool(ray_hit.get("interior_revealed", false)):
		_fail("Transparent dormitory lost its empty-space building click fallback")
		return

	var ada := _get_npc_node(npc_system, "veteran_deputy_01") as CharacterBody3D
	if ada == null or not await _verify_actor_operated_door(art, ada):
		return
	art.call("debug_force_visual_level", 1)
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	print("T0131-P5 dormitory building slice verification passed: %s" % JSON.stringify({
		"fixed_beds": 10,
		"assigned_beds": 8,
		"levels": 2,
		"sleep_recovery_upgrade": 0.2,
		"bounds": art_bounds,
		"door": "2.08x2.35_auto_double_leaf",
		"fade_range": "70_to_58"
	}))
	main.queue_free()
	await process_frame
	quit(0)


func _verify_fixed_bed_authority(building: Dictionary) -> bool:
	var workstations: Array = building.get("workstations", [])
	if workstations.size() != 10:
		return _expect(false, "Dormitory authority no longer exposes exactly ten beds")
	for index in range(10):
		var bed := workstations[index] as Dictionary
		if str(bed.get("id", "")) != "dormitory_bed_%02d" % (index + 1) or str(bed.get("type", "")) != "dormitory_bed":
			return _expect(false, "Dormitory bed identity drifted at index %d" % index)
		if str(bed.get("assigned_npc_id", "")) != EXPECTED_ASSIGNMENTS[index]:
			return _expect(false, "Dormitory fixed bed assignment drifted at index %d" % index)
	var upgrade := building.get("upgrade", {}) as Dictionary
	var level_effects := upgrade.get("level_effects", {}) as Dictionary
	var level_two := level_effects.get("2", {}) as Dictionary
	var bonuses := level_two.get("efficiency_bonuses", {}) as Dictionary
	return _expect(
		level_effects.size() == 1
		and is_equal_approx(float(bonuses.get("sleep_recovery", 0.0)), 0.2)
		and is_zero_approx(float(upgrade.get("workstation_bonus", -1.0))),
		"Dormitory Lv.2 must improve sleep recovery without adding beds"
	)


func _verify_level(art: Node3D, snapshot: Dictionary, visuals: Node, collisions: Node, level: int) -> bool:
	var required_paths := [
		"Exterior/WarmPlasterWallShell/RoundDormitoryDoor",
		"Exterior/FiveBayTimberFrame/FrontLintel",
		"Exterior/TenBedBayWindows",
		"Exterior/MoonAndPillowSign/Pillow",
		"Exterior/AutoDoor",
		"Roof/LongWineShingleRoof/WestShingleSlope",
		"Roof/LongWineShingleRoof/EastShingleSlope",
		"Roof/FiveLowRidgeVents/BedBayVent01",
		"Roof/FiveLowRidgeVents/BedBayVent05",
		"Interior/Level1Details/OuterWallPersonalStorage",
		"Interior/Level1Details/RearLinenStorage",
		"Interior/Level1Details/CommonWashBasin"
	]
	if level >= 2:
		required_paths.append_array([
			"UpgradeVisuals/Level2/InteriorAdditions/WarmStoneHearth",
			"UpgradeVisuals/Level2/InteriorAdditions/InsulatedWainscot",
			"UpgradeVisuals/Level2/InteriorAdditions/ExpandedLinenAndRepairKit",
			"UpgradeVisuals/Level2/ExteriorAdditions/BedBayWindShutters",
			"UpgradeVisuals/Level2/ExteriorAdditions/DryHearthWood",
			"UpgradeVisuals/Level2/RoofStructureAdditions/HearthChimney",
			"UpgradeVisuals/Level2/RoofStructureAdditions/CeilingRepairTie"
		])
	for path in required_paths:
		if art.get_node_or_null(path) == null:
			return _expect(false, "Dormitory Lv.%d lacks required art element: %s" % [level, path])
	var additions := snapshot.get("level_visual_addition_counts", {}) as Dictionary
	var palette := snapshot.get("palette", {}) as Dictionary
	return _expect(
		int(snapshot.get("maximum_level", 0)) == 2
		and str(snapshot.get("architectural_style", "")) == "medieval_border_communal_bunkhouse"
		and str(snapshot.get("roof_profile", "")) == "long_low_wine_shingle_gable_with_five_ridge_vents"
		and str(palette.get("roof", "")) == "70434b"
		and int(snapshot.get("bed_count", 0)) == 10
		and int(snapshot.get("available_bed_count", 0)) == 10
		and int(snapshot.get("assigned_bed_count", 0)) == 8
		and int(snapshot.get("active_fixture_visual_count", 0)) == 10
		and int(snapshot.get("active_fixture_collision_count", 0)) == 10
		and _active_visual_count(visuals) == 10
		and _active_collision_count(collisions) == 10
		and bool(snapshot.get("level_2_visible", false)) == (level >= 2)
		and not bool(snapshot.get("level_3_visible", true))
		and int(additions.get("level_1", 0)) >= 100
		and (level < 2 or int(additions.get("level_2", 0)) >= 70),
		"Dormitory Lv.%d did not preserve the fixed ten-bed slice: %s" % [level, JSON.stringify(snapshot)]
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


func _verify_actor_operated_door(art: Node3D, actor: CharacterBody3D) -> bool:
	var door := art.get_node_or_null("Exterior/AutoDoor") as Node3D
	if door == null or not door.has_method("debug_get_snapshot"):
		return _expect(false, "Dormitory auto door is missing")
	var contract: Dictionary = door.call("debug_get_snapshot")
	if not _expect(
		float(contract.get("clear_width", 0.0)) >= 1.8
		and float(contract.get("clear_height", 0.0)) >= 2.2
		and bool(contract.get("centerline_clear", false))
		and not bool(contract.get("blocking_collision", true)),
		"Dormitory auto door violates the shared doorway contract"
	):
		return false
	actor.set_physics_process(false)
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 1.5))
	for _frame in range(32):
		await physics_frame
	var opened: Dictionary = door.call("debug_get_snapshot")
	if not _expect(bool(opened.get("open_requested", false)) and float(opened.get("open_fraction", 0.0)) >= 0.95, "Dormitory door did not open for Ada"):
		return false
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 8.0))
	for _frame in range(78):
		await physics_frame
	var closed: Dictionary = door.call("debug_get_snapshot")
	return _expect(not bool(closed.get("open_requested", true)) and float(closed.get("open_fraction", 1.0)) <= 0.05, "Dormitory door did not close after Ada left")


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
						var corner := mesh_bounds.position + Vector3(mesh_bounds.size.x * float(x_index), mesh_bounds.size.y * float(y_index), mesh_bounds.size.z * float(z_index))
						points.append(space.to_local(mesh_node.to_global(corner)))
	if points.is_empty():
		return AABB()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return AABB(min_point, max_point - min_point)


func _direct_subtrees_intersect(first_root: Node, second_root: Node, space: Node3D) -> bool:
	for first_child in first_root.get_children():
		var first_bounds := _subtree_bounds_in_space(first_child, space, true)
		if not first_bounds.has_volume():
			continue
		for second_child in second_root.get_children():
			var second_bounds := _subtree_bounds_in_space(second_child, space, true)
			if second_bounds.has_volume() and first_bounds.intersects(second_bounds):
				return true
	return false


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
