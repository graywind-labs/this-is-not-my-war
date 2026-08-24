class_name FormalGardenArtView
extends BuildingArtView


const BUCKET := "res://assets/3d/quaternius/props/bucket_wooden.glb"
const BARREL := "res://assets/3d/quaternius/props/barrel.glb"
const CRATE := "res://assets/3d/quaternius/props/crate_wooden.glb"
const HARVEST_CRATE := "res://assets/3d/quaternius/props/garden_harvest_crate.glb"
const ROPE := "res://assets/3d/quaternius/props/workshop_rope.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const AUTO_DOOR_SCRIPT := preload("res://scripts/presentation/buildings/BuildingAutoDoor.gd")

const LOT_SIZE := Vector2(14.0, 14.0)
const MAXIMUM_LEVEL := 3
const SOIL_DARK := Color("#4d3f32")
const SOIL_LIGHT := Color("#66533c")
const STONE := Color("#626761")
const STONE_LIGHT := Color("#85887c")
const OAK := Color("#76543a")
const DARK_WOOD := Color("#45382f")
const WATTLE := Color("#8a6946")
const ROOF_GREEN := Color("#4f5f52")
const MOSS := Color("#667750")
const LEAF_GREEN := Color("#557348")
const HERB_GREEN := Color("#738457")
const WATER := Color("#4c7780")
const IRON := Color("#454c4c")
const LINEN := Color("#b8a77c")

var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_formal_garden()
	super._ready()


func is_interior_revealed_for_selection() -> bool:
	return true


func _apply_visual_level(level: int, upgrade_in_progress: bool) -> void:
	super._apply_visual_level(mini(level, MAXIMUM_LEVEL), upgrade_in_progress)
	_apply_external_fixture_level_visibility()
	_apply_functional_lantern_level_visibility()


func debug_force_visual_level(level: int) -> Dictionary:
	_apply_visual_level(clampi(level, 1, MAXIMUM_LEVEL), false)
	return get_art_slice_snapshot()


func get_art_slice_snapshot() -> Dictionary:
	var workstation_states: Dictionary = {}
	var marker_root := get_node_or_null(workstation_markers_path)
	if marker_root != null:
		for raw_marker in marker_root.get_children():
			if not raw_marker is Marker3D:
				continue
			var marker := raw_marker as Marker3D
			var workstation_id := str(marker.get_meta("workstation_id", marker.name))
			workstation_states[workstation_id] = {
				"required_level": int(marker.get_meta("required_level", 1)),
				"available": int(marker.get_meta("required_level", 1)) <= _building_level,
				"global_position": marker.global_position
			}
	var gate_snapshot: Dictionary = {}
	var auto_gate := get_node_or_null("Exterior/AutoGardenGate")
	if auto_gate != null and auto_gate.has_method("debug_get_snapshot"):
		gate_snapshot = auto_gate.call("debug_get_snapshot")
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"maximum_level": MAXIMUM_LEVEL,
		"level_2_visible": _is_visible(NodePath("UpgradeVisuals/Level2")),
		"level_3_visible": _is_visible(NodePath("UpgradeVisuals/Level3")),
		"workstations": workstation_states,
		"farm_station_count": _count_workstation_prefix(workstation_states, "garden_plot_"),
		"available_farm_station_count": _count_available_prefix(workstation_states, "garden_plot_"),
		"active_fixture_visual_count": _active_fixture_visual_count(),
		"active_fixture_collision_count": _active_fixture_collision_count(),
		"active_fixture_collision_part_count": _active_fixture_collision_part_count(),
		"level_visual_addition_counts": {
			"level_1": _mesh_count_at("Interior/Level1Details") + _mesh_count_at("Exterior") + _mesh_count_at("Roof"),
			"level_2": _mesh_count_at("UpgradeVisuals/Level2"),
			"level_3": _mesh_count_at("UpgradeVisuals/Level3")
		},
		"lot_size": LOT_SIZE,
		"architectural_style": "open_air_medieval_border_kitchen_garden",
		"facade_profile": "low_stone_wattle_enclosure_wide_gate_and_tool_shelter",
		"roof_profile": "single_small_tool_shelter_roof_only",
		"functional_visual_language": "raised_beds_irrigation_compost_tools_seed_storage_and_harvest_sorting",
		"level_two_upgrade_profile": "water_header_irrigation_seed_storage_and_compost_maturity_without_capacity_gain",
		"level_three_upgrade_profile": "third_authoritative_bed_branch_irrigation_trellis_and_harvest_sorting",
		"open_air_selection_priority": is_interior_revealed_for_selection(),
		"auto_gate": gate_snapshot,
		"roof_mesh_count": _roof_meshes.size(),
		"roof_structure_additions_fade_with_roof": additional_roof_fade_paths.size() == 2,
		"navigation_ready": _formal_navigation_ready(),
		"collision_authority": "formal_station_static_and_level_synced_fixture_collision",
		"navigation_authority": "formal_station_navigation_mesh",
		"production_authority": "building_action_and_resource_system_only",
		"authority_role": "presentation_only"
	}


func _build_formal_garden() -> void:
	building_id = "garden"
	roof_near_distance = 58.0
	roof_far_distance = 70.0
	minimum_roof_opacity = 0.06
	fade_exterior_with_roof = false
	interaction_bounds_center = Vector3(0.0, 1.5, 0.0)
	interaction_bounds_size = Vector3(14.0, 4.0, 14.0)
	roof_albedo_override = ROOF_GREEN
	preserve_roof_albedo_texture = false
	static_collision_path = NodePath("../StaticCollision")
	workstation_markers_path = NodePath("../FixtureLayout/NPCStands")
	set_meta("art_revision", "t0131_p7")
	set_meta("formal_vertical_slice", true)
	set_meta("open_air_site", true)
	set_meta("lot_size_meters", LOT_SIZE)
	set_meta("maximum_level", MAXIMUM_LEVEL)
	_build_ground_and_paths()
	_build_enclosure_and_gate()
	_build_tool_shelter()
	_build_level_one_details()
	_build_upgrade_visuals()
	additional_roof_fade_paths = [
		NodePath("UpgradeVisuals/Level2/RoofStructureAdditions"),
		NodePath("UpgradeVisuals/Level3/RoofStructureAdditions")
	]


func _build_ground_and_paths() -> void:
	var interior := Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_add_box(interior, "DeepGardenGround", Vector3(0.0, 0.035, 0.0), Vector3(13.65, 0.07, 13.65), SOIL_DARK)
	var paths := Node3D.new()
	paths.name = "PackedEarthPaths"
	interior.add_child(paths)
	_add_box(paths, "CentralGardenWalk", Vector3(0.0, 0.085, 1.1), Vector3(1.75, 0.045, 10.7), SOIL_LIGHT)
	_add_box(paths, "RearCrossWalk", Vector3(0.0, 0.09, -4.55), Vector3(10.9, 0.04, 1.0), STONE.darkened(0.12))
	_add_box(paths, "FrontServiceWalk", Vector3(2.4, 0.09, 5.15), Vector3(7.2, 0.04, 0.9), STONE.darkened(0.1))
	for z in [-4.65, -3.15, -1.65, -0.15, 1.35, 2.85, 4.35, 5.85]:
		_add_stone(paths, Vector3(-0.28 if int(z * 10.0) % 2 == 0 else 0.28, 0.11, z), 0.32)


func _build_enclosure_and_gate() -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	var stone_course := Node3D.new()
	stone_course.name = "LowStoneBoundary"
	exterior.add_child(stone_course)
	_add_box(stone_course, "RearStoneCourse", Vector3(0.0, 0.18, -6.7), Vector3(13.45, 0.34, 0.42), STONE)
	for side in [-1.0, 1.0]:
		_add_box(stone_course, "SideStoneCourse", Vector3(side * 6.7, 0.18, 0.0), Vector3(0.42, 0.34, 13.45), STONE.darkened(0.03))
		_add_box(stone_course, "FrontStoneCourse", Vector3(side * 4.55, 0.18, 6.7), Vector3(4.35, 0.34, 0.42), STONE)

	var fence := Node3D.new()
	fence.name = "WattleAndPostFence"
	exterior.add_child(fence)
	_add_fence_run(fence, Vector3(0.0, 0.0, -6.62), 13.15, false)
	for side in [-1.0, 1.0]:
		_add_fence_run(fence, Vector3(side * 6.62, 0.0, 0.0), 13.15, true)
		_add_fence_run(fence, Vector3(side * 4.55, 0.0, 6.62), 4.15, false)
	for side in [-1.0, 1.0]:
		_add_box(exterior, "GateStonePost", Vector3(side * 1.22, 0.85, 6.62), Vector3(0.46, 1.7, 0.52), STONE_LIGHT)
		_add_box(exterior, "GateTimberCap", Vector3(side * 1.22, 1.77, 6.62), Vector3(0.62, 0.15, 0.66), DARK_WOOD)
	var gate := Node3D.new()
	gate.name = "AutoGardenGate"
	gate.position = Vector3(0.0, 0.2, 6.62)
	gate.set_script(AUTO_DOOR_SCRIPT)
	gate.set("clear_width", 2.08)
	gate.set("clear_height", 2.35)
	gate.set("leaf_visual_height", 1.02)
	gate.call("configure", WATTLE, DARK_WOOD, IRON)
	exterior.add_child(gate)

	var sign := Node3D.new()
	sign.name = "SeedlingGardenSign"
	sign.position = Vector3(-2.05, 1.62, 6.75)
	exterior.add_child(sign)
	_add_box(sign, "SignBoard", Vector3.ZERO, Vector3(1.2, 0.72, 0.13), DARK_WOOD)
	_add_cylinder(sign, "SproutStem", Vector3(0.0, -0.04, 0.11), 0.035, 0.42, HERB_GREEN)
	_add_leaf(sign, Vector3(-0.14, 0.09, 0.12), -35.0)
	_add_leaf(sign, Vector3(0.14, 0.18, 0.12), 35.0)


func _build_tool_shelter() -> void:
	var exterior := get_node("Exterior") as Node3D
	var shelter := Node3D.new()
	shelter.name = "OpenToolShelter"
	exterior.add_child(shelter)
	_add_box(shelter, "EastRearPlate", Vector3(6.25, 1.45, 2.45), Vector3(0.22, 2.45, 4.6), DARK_WOOD)
	for z in [0.35, 4.55]:
		_add_box(shelter, "ShelterPost", Vector3(6.12, 1.42, z), Vector3(0.25, 2.55, 0.25), DARK_WOOD)
		_add_box(shelter, "ShelterKneeBrace", Vector3(5.72, 2.25, z), Vector3(0.12, 1.05, 0.12), OAK).rotation_degrees.z = -42.0
	_add_box(shelter, "ShelterRearRail", Vector3(6.0, 2.6, 2.45), Vector3(0.2, 0.18, 4.75), OAK)
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.set_meta("roof_fade_candidate", true)
	add_child(roof)
	var lean_to := _add_box(roof, "MossyToolShelterRoof", Vector3(5.35, 2.78, 2.45), Vector3(2.35, 0.16, 5.15), ROOF_GREEN)
	lean_to.rotation_degrees.z = -8.0
	for z in [0.05, 1.25, 2.45, 3.65, 4.85]:
		var batten := _add_box(roof, "ShelterRoofBatten", Vector3(5.35, 2.83, z), Vector3(2.25, 0.055, 0.08), DARK_WOOD)
		batten.rotation_degrees.z = -8.0


func _build_level_one_details() -> void:
	var details := Node3D.new()
	details.name = "Level1Details"
	(get_node("Interior") as Node3D).add_child(details)
	var seed_corner := Node3D.new()
	seed_corner.name = "SeedAndHarvestCorner"
	details.add_child(seed_corner)
	_add_scene_prop(seed_corner, "SeedCrate", CRATE, Vector3(5.55, 0.18, 4.8), Vector3.ONE * 0.48, Vector3(0.0, 18.0, 0.0))
	_add_scene_prop(seed_corner, "WaterBucket", BUCKET, Vector3(5.45, 0.15, 3.75), Vector3.ONE * 0.52)
	_add_scene_prop(seed_corner, "CoiledTies", ROPE, Vector3(5.78, 0.18, 1.15), Vector3.ONE * 0.48, Vector3(0.0, 0.0, 90.0))
	_add_box(seed_corner, "SeedDrawerChest", Vector3(5.45, 0.68, 2.1), Vector3(1.1, 1.15, 1.3), OAK)
	for y in [0.4, 0.68, 0.96]:
		_add_box(seed_corner, "SeedDrawer", Vector3(4.88, y, 2.1), Vector3(0.06, 0.21, 1.05), WATTLE)

	var herb_border := Node3D.new()
	herb_border.name = "FrontHerbTroughs"
	details.add_child(herb_border)
	for x in [-4.9, -3.65, 3.65, 4.9]:
		_add_box(herb_border, "HerbStoneTrough", Vector3(x, 0.28, 5.9), Vector3(1.0, 0.42, 0.58), STONE_LIGHT)
		_add_box(herb_border, "HerbSoil", Vector3(x, 0.51, 5.9), Vector3(0.78, 0.05, 0.4), SOIL_DARK)
		for offset in [-0.26, 0.0, 0.26]:
			_add_herb_cluster(herb_border, Vector3(x + offset, 0.54, 5.9))

	var scarecrow := Node3D.new()
	scarecrow.name = "BorderScarecrow"
	scarecrow.position = Vector3(-5.85, 0.0, 5.0)
	details.add_child(scarecrow)
	_add_cylinder(scarecrow, "ScarecrowPole", Vector3(0.0, 1.25, 0.0), 0.075, 2.5, DARK_WOOD)
	_add_cylinder(scarecrow, "ScarecrowArms", Vector3(0.0, 1.62, 0.0), 0.065, 1.45, DARK_WOOD, Vector3(0.0, 0.0, 90.0))
	_add_box(scarecrow, "WeatheredCoat", Vector3(0.0, 1.3, 0.0), Vector3(0.72, 0.82, 0.2), MOSS.darkened(0.12))
	_add_sphere(scarecrow, "StrawHead", Vector3(0.0, 1.98, 0.0), 0.28, LINEN)
	_add_cylinder(scarecrow, "HatBrim", Vector3(0.0, 2.24, 0.0), 0.36, 0.08, DARK_WOOD)
	_add_cone(scarecrow, "HatCrown", Vector3(0.0, 2.42, 0.0), 0.24, 0.42, DARK_WOOD)
	_add_garden_lamp_post(details, "GardenLanternWestRear", Vector3(-5.72, 0.0, -4.45), 90.0, 1)
	_add_garden_lamp_post(details, "GardenLanternEastRear", Vector3(5.72, 0.0, -4.45), -90.0, 1)
	_add_garden_lamp_post(details, "GardenLanternEastFront", Vector3(5.72, 0.0, 4.15), -90.0, 2)
	_add_garden_lamp_post(details, "GardenLanternWestFront", Vector3(-5.72, 0.0, 4.15), 90.0, 3)


func _build_upgrade_visuals() -> void:
	var upgrades := Node3D.new()
	upgrades.name = "UpgradeVisuals"
	add_child(upgrades)
	var level_2 := Node3D.new()
	level_2.name = "Level2"
	level_2.visible = false
	upgrades.add_child(level_2)
	var level_2_interior := Node3D.new()
	level_2_interior.name = "InteriorAdditions"
	level_2.add_child(level_2_interior)
	_add_water_header(level_2_interior)
	_add_seedling_storage(level_2_interior)
	var level_2_roof := Node3D.new()
	level_2_roof.name = "RoofStructureAdditions"
	level_2.add_child(level_2_roof)
	var water_shade := _add_box(level_2_roof, "WaterBarrelShade", Vector3(5.72, 2.08, -0.55), Vector3(1.55, 0.12, 1.7), ROOF_GREEN.darkened(0.08))
	water_shade.rotation_degrees.z = -7.0

	var level_3 := Node3D.new()
	level_3.name = "Level3"
	level_3.visible = false
	upgrades.add_child(level_3)
	var level_3_interior := Node3D.new()
	level_3_interior.name = "InteriorAdditions"
	level_3.add_child(level_3_interior)
	_add_third_plot_support(level_3_interior)
	_add_harvest_sorting(level_3_interior)
	var level_3_roof := Node3D.new()
	level_3_roof.name = "RoofStructureAdditions"
	level_3.add_child(level_3_roof)
	var sorting_awning := _add_box(level_3_roof, "HarvestSortingAwning", Vector3(4.25, 2.3, 5.15), Vector3(3.25, 0.13, 1.25), ROOF_GREEN.lightened(0.04))
	sorting_awning.rotation_degrees.x = 7.0


func _add_water_header(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "LevelTwoWaterHeader"
	root.set_meta("authority_role", "non_workstation_efficiency_symbol")
	parent.add_child(root)
	_add_box(root, "HeaderStonePad", Vector3(5.72, 0.16, -0.55), Vector3(1.45, 0.32, 1.55), STONE)
	_add_scene_prop(root, "RainBarrel", BARREL, Vector3(5.72, 0.28, -0.55), Vector3.ONE * 0.75)
	_add_cylinder(root, "IronSpigot", Vector3(5.05, 0.65, -0.55), 0.055, 0.38, IRON, Vector3(0.0, 0.0, 90.0))
	_add_box(root, "StoneFeeder", Vector3(4.5, 0.12, -0.55), Vector3(1.65, 0.16, 0.34), STONE_LIGHT)
	_add_box(root, "FeederWater", Vector3(4.5, 0.215, -0.55), Vector3(1.45, 0.035, 0.18), WATER)
	for x in [-3.5, 3.5]:
		_add_box(root, "BedFeedChannel", Vector3(x, 0.115, -0.82), Vector3(0.22, 0.09, 0.9), STONE_LIGHT.darkened(0.08))
		_add_box(root, "BedFeedWater", Vector3(x, 0.17, -0.82), Vector3(0.12, 0.025, 0.72), WATER)


func _add_seedling_storage(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "SeedlingAndCompostMaturitySet"
	root.position = Vector3(5.58, 0.0, 0.78)
	parent.add_child(root)
	for z in [-0.42, 0.0, 0.42]:
		_add_box(root, "SeedlingTray", Vector3(-0.28, 0.45 + (z + 0.42) * 0.72, z), Vector3(0.86, 0.12, 0.34), OAK)
		for x in [-0.26, 0.0, 0.26]:
			_add_herb_cluster(root, Vector3(-0.28 + x, 0.54 + (z + 0.42) * 0.72, z))
	_add_scene_prop(root, "CompostTurningBucket", BUCKET, Vector3(0.15, 0.14, 0.75), Vector3.ONE * 0.46)


func _add_third_plot_support(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ThirdPlotIrrigationAndTrellis"
	root.set_meta("workstation_id", "garden_plot_03")
	parent.add_child(root)
	_add_box(root, "ThirdFeedChannel", Vector3(-3.5, 0.115, 4.72), Vector3(0.22, 0.09, 1.05), STONE_LIGHT.darkened(0.08))
	_add_box(root, "ThirdFeedWater", Vector3(-3.5, 0.17, 4.72), Vector3(0.12, 0.025, 0.82), WATER)
	for z in [1.15, 3.85]:
		_add_box(root, "TrellisPost", Vector3(-5.18, 0.95, z), Vector3(0.13, 1.8, 0.13), DARK_WOOD)
	for y in [0.55, 1.0, 1.45]:
		_add_box(root, "TrellisRail", Vector3(-5.18, y, 2.5), Vector3(0.1, 0.1, 2.65), WATTLE)
	for z in [1.45, 2.15, 2.85, 3.55]:
		_add_leaf(root, Vector3(-5.1, 1.05, z), -25.0)


func _add_harvest_sorting(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "LevelThreeHarvestSortingExtension"
	root.position = Vector3(4.25, 0.0, 5.1)
	root.set_meta("authority_role", "non_workstation_non_inventory_decoration")
	parent.add_child(root)
	_add_box(root, "SortingTableTop", Vector3(0.0, 0.92, 0.0), Vector3(2.4, 0.16, 0.72), OAK)
	for x in [-0.95, 0.95]:
		_add_box(root, "SortingTableLeg", Vector3(x, 0.47, 0.0), Vector3(0.16, 0.86, 0.16), DARK_WOOD)
	_add_scene_prop(root, "SortedHarvestCrate", HARVEST_CRATE, Vector3(-0.65, 0.98, 0.0), Vector3.ONE * 0.55)
	_add_scene_prop(root, "DispatchCrate", CRATE, Vector3(1.05, 0.15, -0.05), Vector3.ONE * 0.42, Vector3(0.0, -12.0, 0.0))


func _add_fence_run(parent: Node3D, center: Vector3, length: float, along_z: bool) -> void:
	var post_count := maxi(2, int(ceil(length / 1.65)) + 1)
	for index in range(post_count):
		var offset := -length * 0.5 + length * float(index) / float(post_count - 1)
		var position_value := center + (Vector3(0.0, 0.72, offset) if along_z else Vector3(offset, 0.72, 0.0))
		_add_box(parent, "FencePost", position_value, Vector3(0.17, 1.35, 0.17), DARK_WOOD)
	for rail_height in [0.52, 0.9]:
		_add_box(parent, "WattleRail", center + Vector3(0.0, rail_height, 0.0), Vector3(0.12, 0.12, length) if along_z else Vector3(length, 0.12, 0.12), WATTLE)


func _add_garden_lamp_post(parent: Node3D, lantern_name: String, position_value: Vector3, inward_yaw: float, required_level: int) -> void:
	var mount := Node3D.new()
	# 支撑节点不能以灯具名开头，否则按前缀解析灯具时会被误认为第二盏灯。
	mount.name = "Support_%s" % lantern_name
	mount.position = position_value
	mount.rotation_degrees.y = inward_yaw
	mount.set_meta("functional_lantern_support", true)
	mount.set_meta("functional_lantern_required_level", required_level)
	parent.add_child(mount)
	_add_box(mount, "TimberPost", Vector3(0.0, 1.12, 0.0), Vector3(0.2, 2.24, 0.2), DARK_WOOD)
	_add_box(mount, "IronBoundCap", Vector3(0.0, 2.24, 0.0), Vector3(0.31, 0.14, 0.31), IRON)
	_add_box(mount, "LanternCrossArm", Vector3(0.0, 2.08, 0.28), Vector3(0.13, 0.13, 0.68), OAK)
	var lantern := _add_scene_prop(mount, lantern_name, LANTERN, Vector3(0.0, 1.92, 0.48), Vector3.ONE * 0.54)
	if lantern != null:
		lantern.set_meta("mounted_to_structure", true)
		lantern.set_meta("mount_surface", "garden_timber_lamp_post")
		lantern.set_meta("functional_lantern_required_level", required_level)


func _apply_functional_lantern_level_visibility() -> void:
	for raw_node in find_children("*", "Node3D", true, false):
		var node := raw_node as Node3D
		if node != null and node.has_meta("functional_lantern_required_level"):
			node.visible = int(node.get_meta("functional_lantern_required_level", 1)) <= _building_level
	if is_inside_tree():
		get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "building_functional_light_controller", "debug_force_refresh")


func _add_stone(parent: Node3D, center: Vector3, radius: float) -> void:
	var stone := _add_sphere(parent, "PathStone", center, radius, STONE_LIGHT)
	stone.scale = Vector3(1.25, 0.3, 0.85)


func _add_herb_cluster(parent: Node3D, center: Vector3) -> void:
	for index in range(3):
		var angle := float(index) * TAU / 3.0
		_add_cylinder(parent, "HerbStem", center + Vector3(cos(angle) * 0.07, 0.12, sin(angle) * 0.07), 0.018, 0.24, HERB_GREEN)
		_add_sphere(parent, "HerbLeaf", center + Vector3(cos(angle) * 0.11, 0.25, sin(angle) * 0.11), 0.09, LEAF_GREEN)


func _add_leaf(parent: Node3D, center: Vector3, rotation_z: float) -> void:
	var leaf := _add_sphere(parent, "Leaf", center, 0.12, LEAF_GREEN)
	leaf.scale = Vector3(1.45, 0.36, 0.72)
	leaf.rotation_degrees.z = rotation_z


func _apply_external_fixture_level_visibility() -> void:
	var fixture_root := get_node_or_null("../FixtureLayout")
	if fixture_root == null:
		return
	var visual_root := fixture_root.get_node_or_null("Visuals")
	if visual_root != null:
		for raw_child in visual_root.get_children():
			if raw_child is Node3D:
				(raw_child as Node3D).visible = int(raw_child.get_meta("required_level", 1)) <= _building_level
	for marker_branch_name in ["NPCStands", "OccupantAnchors", "HorseAnchors"]:
		var marker_branch := fixture_root.get_node_or_null(marker_branch_name) as Node3D
		if marker_branch != null:
			marker_branch.visible = false
	var collision_root := fixture_root.get_node_or_null("StaticCollision")
	if collision_root != null:
		for raw_body in collision_root.get_children():
			if not raw_body is StaticBody3D:
				continue
			var body := raw_body as StaticBody3D
			var enabled := int(body.get_meta("required_level", 1)) <= _building_level
			body.collision_layer = 1 if enabled else 0
			for raw_shape in body.find_children("*", "CollisionShape3D", true, false):
				(raw_shape as CollisionShape3D).disabled = not enabled


func _active_fixture_visual_count() -> int:
	var visual_root := get_node_or_null("../FixtureLayout/Visuals")
	if visual_root == null:
		return 0
	var count := 0
	for raw_child in visual_root.get_children():
		if raw_child is Node3D and (raw_child as Node3D).visible:
			count += 1
	return count


func _active_fixture_collision_count() -> int:
	var collision_root := get_node_or_null("../FixtureLayout/StaticCollision")
	if collision_root == null:
		return 0
	var count := 0
	for raw_body in collision_root.get_children():
		if raw_body is StaticBody3D and (raw_body as StaticBody3D).collision_layer != 0:
			count += 1
	return count


func _active_fixture_collision_part_count() -> int:
	var collision_root := get_node_or_null("../FixtureLayout/StaticCollision")
	if collision_root == null:
		return 0
	var count := 0
	for raw_body in collision_root.get_children():
		if not raw_body is StaticBody3D or (raw_body as StaticBody3D).collision_layer == 0:
			continue
		for raw_shape in raw_body.find_children("*", "CollisionShape3D", true, false):
			if not (raw_shape as CollisionShape3D).disabled:
				count += 1
	return count


func _count_workstation_prefix(states: Dictionary, prefix: String) -> int:
	var count := 0
	for key in states:
		if str(key).begins_with(prefix):
			count += 1
	return count


func _count_available_prefix(states: Dictionary, prefix: String) -> int:
	var count := 0
	for key in states:
		if str(key).begins_with(prefix) and bool((states[key] as Dictionary).get("available", false)):
			count += 1
	return count


func _formal_navigation_ready() -> bool:
	var controller := get_node_or_null("/root/Main/Presentation/StationLayoutController")
	if controller == null or not controller.has_method("get_validation_snapshot"):
		return false
	var snapshot: Dictionary = controller.call("get_validation_snapshot")
	var navigation := snapshot.get("production_navigation", {}) as Dictionary
	return bool(navigation.get("available", false)) and bool(navigation.get("enabled", false))


func _mesh_count_at(path: String) -> int:
	return _count_authored_meshes_at(NodePath(path))


func _add_scene_prop(parent: Node3D, node_name: String, asset_path: String, position_value: Vector3, scale_value: Vector3 = Vector3.ONE, rotation_value: Vector3 = Vector3.ZERO) -> Node3D:
	var packed := load(asset_path) as PackedScene
	if packed == null:
		return null
	var prop := packed.instantiate() as Node3D
	if prop == null:
		return null
	prop.name = node_name
	prop.position = position_value
	prop.scale = scale_value
	prop.rotation_degrees = rotation_value
	parent.add_child(prop)
	return prop


func _add_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, center: Vector3, radius: float, height: float, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.rotation_degrees = rotation_value
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_cone(parent: Node3D, node_name: String, center: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	_material_cache[key] = material
	return material
