class_name FormalTavernArtView
extends BuildingArtView


const WALL_STRAIGHT := "res://assets/3d/quaternius/buildings/wall_plaster_straight.glb"
const WALL_DOOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round.glb"
const FLOOR_DARK := "res://assets/3d/quaternius/buildings/floor_wood_dark.glb"
const BARREL := "res://assets/3d/quaternius/props/barrel.glb"
const SHELF := "res://assets/3d/quaternius/props/workshop_shelf.glb"
const CRATE := "res://assets/3d/quaternius/props/crate_wooden.glb"
const BUCKET := "res://assets/3d/quaternius/props/bucket_wooden.glb"
const ROPE := "res://assets/3d/quaternius/props/workshop_rope.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const AUTO_DOOR_SCRIPT := preload("res://scripts/presentation/buildings/BuildingAutoDoor.gd")

const BUILDING_FOOTPRINT := Vector2(12.0, 10.0)
const LOT_SIZE := Vector2(14.0, 12.0)
const MAXIMUM_LEVEL := 3
const DECORATIVE_BARREL_SCALE_MULTIPLIER := 1.25

const CELLAR_STONE := Color("#555963")
const CELLAR_STONE_LIGHT := Color("#747782")
const CELLAR_PLASTER := Color("#9b9388")
const CELLAR_TIMBER := Color("#43363a")
const CELLAR_OAK := Color("#72513b")
const CELLAR_ROOF := Color("#693f4d")
const CELLAR_ROOF_EDGE := Color("#3d303a")
const CELLAR_COPPER := Color("#9a6445")
const CELLAR_IRON := Color("#34383e")
const CELLAR_WINE := Color("#6e293e")
const CELLAR_GLASS := Color("#768b82")
const CELLAR_GRAIN := Color("#b79558")
const CELLAR_WATER := Color("#4f7780")
const CELLAR_CHALK := Color("#d3cbb8")

var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_formal_tavern()
	super._ready()


func _apply_visual_level(level: int, upgrade_in_progress: bool) -> void:
	super._apply_visual_level(mini(level, MAXIMUM_LEVEL), upgrade_in_progress)
	_apply_external_fixture_level_visibility()


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
				"assigned_npc_id": str(marker.get_meta("assigned_npc_id", "")),
				"global_position": marker.global_position
			}
	var door_snapshot: Dictionary = {}
	var auto_door := get_node_or_null("Exterior/AutoDoor")
	if auto_door != null and auto_door.has_method("debug_get_snapshot"):
		door_snapshot = auto_door.call("debug_get_snapshot")
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"maximum_level": MAXIMUM_LEVEL,
		"upgrade_in_progress": _upgrade_in_progress,
		"level_2_visible": _is_visible(NodePath("UpgradeVisuals/Level2")),
		"level_3_visible": _is_visible(NodePath("UpgradeVisuals/Level3")),
		"workstations": workstation_states,
		"brew_station_count": _count_workstation_prefix(workstation_states, "cellar_"),
		"available_brew_station_count": _count_available_prefix(workstation_states, "cellar_"),
		"active_fixture_visual_count": _active_fixture_visual_count(),
		"active_fixture_collision_count": _active_fixture_collision_count(),
		"decorative_storage_barrel_count": _visible_decorative_storage_barrel_count(),
		"barrel_density_profile": "level_1_rear_aging_stacks_level_2_shaded_maturation_stack_level_3_dispatch_stack",
		"level_visual_addition_counts": {
			"level_1": _mesh_count_at("Interior/Level1Details") + _mesh_count_at("Exterior") + _mesh_count_at("Roof"),
			"level_2": _mesh_count_at("UpgradeVisuals/Level2"),
			"level_3": _mesh_count_at("UpgradeVisuals/Level3")
		},
		"building_footprint": BUILDING_FOOTPRINT,
		"lot_size": LOT_SIZE,
		"architectural_style": "medieval_border_half_masonry_winery_cellar",
		"facade_profile": "stone_cellar_base_loading_door_barrel_hoop_and_vine_sign",
		"roof_profile": "low_wine_shingle_gable_with_level_synced_fermentation_vents",
		"gable_end_profile": "sealed_cellar_plaster_with_wine_dark_timber",
		"sealed_gable_end_count": 2,
		"functional_visual_language": "fermentation_casks_maturation_racks_copper_pipes_wash_water_and_cooper_tools",
		"level_two_upgrade_profile": "maturation_cooling_piping_and_masonry_reinforcement_without_capacity_gain",
		"level_three_upgrade_profile": "third_authoritative_fermentation_bay_with_branch_pipe_vent_and_loading_rack",
		"palette": {
			"stone": CELLAR_STONE.to_html(false),
			"plaster": CELLAR_PLASTER.to_html(false),
			"timber": CELLAR_TIMBER.to_html(false),
			"roof": CELLAR_ROOF.to_html(false),
			"wine": CELLAR_WINE.to_html(false),
			"copper": CELLAR_COPPER.to_html(false)
		},
		"auto_door": door_snapshot,
		"roof_mesh_count": _roof_meshes.size(),
		"roof_structure_additions_fade_with_roof": additional_roof_fade_paths.size() == 2,
		"exterior_upgrade_additions_fade_with_shell": additional_exterior_fade_paths.size() == 2,
		"exterior_material_count": _exterior_materials.size(),
		"interior_revealed_for_selection": is_interior_revealed_for_selection(),
		"shell_opacity": maxf(_roof_opacity, _exterior_opacity),
		"navigation_ready": _formal_navigation_ready(),
		"collision_authority": "formal_station_static_and_level_synced_fixture_collision",
		"navigation_authority": "formal_station_navigation_mesh",
		"brewing_authority": "building_action_and_resource_system_only",
		"trade_authority": "merchant_system_only",
		"authority_role": "presentation_only"
	}


func _build_formal_tavern() -> void:
	building_id = "tavern"
	roof_near_distance = 58.0
	roof_far_distance = 70.0
	minimum_roof_opacity = 0.06
	fade_exterior_with_roof = true
	minimum_exterior_opacity = 0.06
	interior_reveal_opacity_threshold = 0.72
	interaction_bounds_center = Vector3(0.0, 2.7, 0.0)
	interaction_bounds_size = Vector3(14.1, 7.0, 12.1)
	roof_albedo_override = CELLAR_ROOF
	preserve_roof_albedo_texture = false
	exterior_albedo_tint = CELLAR_PLASTER
	static_collision_path = NodePath("../StaticCollision")
	workstation_markers_path = NodePath("../FixtureLayout/NPCStands")
	set_meta("art_revision", "t0135_p8ar7")
	set_meta("formal_vertical_slice", true)
	set_meta("architectural_style", "medieval_border_half_masonry_winery_cellar")
	set_meta("footprint_meters", BUILDING_FOOTPRINT)
	set_meta("lot_size_meters", LOT_SIZE)
	set_meta("maximum_level", MAXIMUM_LEVEL)
	_build_foundation_and_floor()
	_build_exterior()
	_build_roof()
	_build_level_one_details()
	_build_upgrade_visuals()
	additional_roof_fade_paths = [
		NodePath("UpgradeVisuals/Level2/RoofStructureAdditions"),
		NodePath("UpgradeVisuals/Level3/RoofStructureAdditions")
	]
	additional_exterior_fade_paths = [
		NodePath("UpgradeVisuals/Level2/ExteriorAdditions"),
		NodePath("UpgradeVisuals/Level3/ExteriorAdditions")
	]


func _build_foundation_and_floor() -> void:
	var interior := Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_add_box(interior, "SunkenStoneFoundation", Vector3(0.0, 0.14, 0.0), Vector3(11.95, 0.28, 9.95), CELLAR_STONE.darkened(0.14))
	var floor := Node3D.new()
	floor.name = "DarkCoolCellarFloor"
	interior.add_child(floor)
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		for z in [-4.0, -2.0, 0.0, 2.0, 4.0]:
			_add_scene_prop(floor, "DarkOakFloor", FLOOR_DARK, Vector3(x, 0.16, z), Vector3(1.0, 0.2, 1.0))
	_add_box(interior, "CentralStoneDrain", Vector3(0.0, 0.205, -0.3), Vector3(0.48, 0.035, 8.5), CELLAR_STONE_LIGHT.darkened(0.13))
	for z in [-3.5, -1.75, 0.0, 1.75, 3.5]:
		_add_box(interior, "DrainGrate", Vector3(0.0, 0.232, z), Vector3(0.62, 0.035, 0.12), CELLAR_IRON)


func _build_exterior() -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	var shell := Node3D.new()
	shell.name = "HalfMasonryCellarShell"
	exterior.add_child(shell)
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		if absf(x) > 1.1:
			_add_scene_prop(shell, "FrontWall", WALL_STRAIGHT, Vector3(x, 0.2, 5.0), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(shell, "RoundLoadingDoor", WALL_DOOR, Vector3(0.0, 0.2, 5.0), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		_add_scene_prop(shell, "RearWall", WALL_STRAIGHT, Vector3(x, 0.2, -5.0), Vector3.ONE)
	for side in [-1.0, 1.0]:
		for z in [-4.0, -2.0, 0.0, 2.0, 4.0]:
			_add_scene_prop(shell, "SideWall", WALL_STRAIGHT, Vector3(side * 6.0, 0.2, z), Vector3.ONE, Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0))

	var stone_base := Node3D.new()
	stone_base.name = "CoolStoneCellarCourse"
	exterior.add_child(stone_base)
	_add_box(stone_base, "FrontStonePlinth", Vector3(0.0, 0.7, 5.12), Vector3(12.15, 1.25, 0.34), CELLAR_STONE)
	_add_box(stone_base, "RearStonePlinth", Vector3(0.0, 0.7, -5.12), Vector3(12.15, 1.25, 0.34), CELLAR_STONE.darkened(0.04))
	for side in [-1.0, 1.0]:
		_add_box(stone_base, "SideStonePlinth", Vector3(side * 6.12, 0.7, 0.0), Vector3(0.34, 1.25, 10.0), CELLAR_STONE.darkened(0.02))
		for z in [-4.6, -1.55, 1.55, 4.6]:
			_add_box(stone_base, "CellarButtress", Vector3(side * 6.26, 1.08, z), Vector3(0.46, 1.8, 0.72), CELLAR_STONE_LIGHT.darkened(0.09))

	var timber := Node3D.new()
	timber.name = "WineDarkTimberFrame"
	exterior.add_child(timber)
	for x in [-5.88, -3.7, -1.28, 1.28, 3.7, 5.88]:
		_add_box(timber, "FrontPost", Vector3(x, 2.05, 5.2), Vector3(0.25, 3.1, 0.24), CELLAR_TIMBER)
		_add_box(timber, "RearPost", Vector3(x, 2.05, -5.2), Vector3(0.25, 3.1, 0.24), CELLAR_TIMBER)
	_add_box(timber, "FrontLintel", Vector3(0.0, 3.5, 5.2), Vector3(12.1, 0.26, 0.24), CELLAR_TIMBER)
	_add_box(timber, "RearLintel", Vector3(0.0, 3.5, -5.2), Vector3(12.1, 0.26, 0.24), CELLAR_TIMBER)
	for side in [-1.0, 1.0]:
		for z in [-4.75, -2.4, 0.0, 2.4, 4.75]:
			_add_box(timber, "SidePost", Vector3(side * 6.2, 2.05, z), Vector3(0.24, 3.1, 0.25), CELLAR_TIMBER)
	var gable_ends := Node3D.new()
	gable_ends.name = "SealedCellarGableEnds"
	exterior.add_child(gable_ends)
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var end_x: float = float(side) * 6.08
		_add_gable_wall(gable_ends, "%sCellarGableWall" % side_name, Vector3(end_x, 4.36, 0.0), Vector3(10.0, 1.72, 0.3), _material(CELLAR_PLASTER.darkened(0.04)), 90.0)
		_add_box(gable_ends, "%sGableTie" % side_name, Vector3(end_x, 3.54, 0.0), Vector3(0.34, 0.22, 10.0), CELLAR_TIMBER)
		_add_box(gable_ends, "%sKingPost" % side_name, Vector3(end_x, 4.35, 0.0), Vector3(0.34, 1.68, 0.24), CELLAR_TIMBER)
		var front_rafter := _add_box(gable_ends, "%sFrontRakingBeam" % side_name, Vector3(end_x, 4.37, 2.5), Vector3(0.34, 0.2, 5.3), CELLAR_TIMBER)
		front_rafter.rotation_degrees.x = 19.0
		var rear_rafter := _add_box(gable_ends, "%sRearRakingBeam" % side_name, Vector3(end_x, 4.37, -2.5), Vector3(0.34, 0.2, 5.3), CELLAR_TIMBER)
		rear_rafter.rotation_degrees.x = -19.0

	var windows := Node3D.new()
	windows.name = "HighCellarWindows"
	exterior.add_child(windows)
	for x in [-3.75, 3.75]:
		_add_cellar_window(windows, Vector3(x, 2.35, 5.3), 0.0)
		_add_cellar_window(windows, Vector3(x, 2.35, -5.3), 180.0)

	var sign := Node3D.new()
	sign.name = "BarrelHoopAndVineSign"
	sign.position = Vector3(0.0, 4.02, 5.34)
	exterior.add_child(sign)
	_add_box(sign, "WineSignBoard", Vector3.ZERO, Vector3(2.55, 0.92, 0.14), CELLAR_TIMBER.lightened(0.07))
	_add_cylinder(sign, "BarrelHoop", Vector3(-0.48, 0.0, 0.13), 0.31, 0.07, CELLAR_COPPER, Vector3(90.0, 0.0, 0.0))
	_add_cylinder(sign, "BarrelHead", Vector3(-0.48, 0.0, 0.15), 0.23, 0.075, CELLAR_OAK, Vector3(90.0, 0.0, 0.0))
	_add_vine_symbol(sign, Vector3(0.48, 0.0, 0.16))

	var door := Node3D.new()
	door.name = "AutoDoor"
	door.position = Vector3(0.0, 0.2, 5.18)
	door.set_script(AUTO_DOOR_SCRIPT)
	door.call("configure", CELLAR_OAK, CELLAR_TIMBER, CELLAR_IRON)
	exterior.add_child(door)


func _build_roof() -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.set_meta("roof_fade_candidate", true)
	add_child(roof)
	var main_roof := Node3D.new()
	main_roof.name = "LowWineShingleGable"
	roof.add_child(main_roof)
	var front := _add_box(main_roof, "FrontWineShingleSlope", Vector3(0.0, 4.32, 2.68), Vector3(12.65, 0.18, 5.75), CELLAR_ROOF)
	front.rotation_degrees.x = 19.0
	var rear := _add_box(main_roof, "RearWineShingleSlope", Vector3(0.0, 4.32, -2.68), Vector3(12.65, 0.18, 5.75), CELLAR_ROOF.darkened(0.045))
	rear.rotation_degrees.x = -19.0
	_add_cylinder(main_roof, "DarkRoundedRidge", Vector3(0.0, 5.24, 0.0), 0.16, 12.85, CELLAR_ROOF_EDGE, Vector3(0.0, 0.0, 90.0))
	for x in [-5.4, -3.6, -1.8, 0.0, 1.8, 3.6, 5.4]:
		var front_joint := _add_box(main_roof, "FrontShingleJoint", Vector3(x, 4.38, 2.68), Vector3(0.045, 0.025, 5.62), CELLAR_ROOF_EDGE)
		front_joint.rotation_degrees.x = 19.0
		var rear_joint := _add_box(main_roof, "RearShingleJoint", Vector3(x, 4.38, -2.68), Vector3(0.045, 0.025, 5.62), CELLAR_ROOF_EDGE)
		rear_joint.rotation_degrees.x = -19.0
	var vents := Node3D.new()
	vents.name = "LevelOneFermentationVents"
	roof.add_child(vents)
	_add_low_vent(vents, "WestFermentationVent", -3.5)
	_add_low_vent(vents, "EastFermentationVent", 3.5)


func _build_level_one_details() -> void:
	var details := Node3D.new()
	details.name = "Level1Details"
	(get_node("Interior") as Node3D).add_child(details)
	var rear_storage := Node3D.new()
	rear_storage.name = "RearWallBottlingAndGrainStorage"
	details.add_child(rear_storage)
	_add_scene_prop(rear_storage, "BottleShelf", SHELF, Vector3(-1.4, 0.2, -4.45), Vector3.ONE * 0.52, Vector3(0.0, 180.0, 0.0))
	for row in range(3):
		for column in range(4):
			_add_bottle(rear_storage, Vector3(-2.05 + float(column) * 0.42, 0.72 + float(row) * 0.38, -4.05), 0.08 + float((row + column) % 2) * 0.01)
	for index in range(4):
		_add_grain_sack(rear_storage, Vector3(0.8 + float(index % 2) * 0.72, 0.18 + float(index / 2) * 0.48, -4.3), float(index) * 12.0)
	_add_rear_aging_barrel_stacks(details)

	var west_service := Node3D.new()
	west_service.name = "WestWallCooperAndCleaningTools"
	details.add_child(west_service)
	_add_scene_prop(west_service, "WashBucket", BUCKET, Vector3(-5.35, 0.18, 3.75), Vector3.ONE * 0.58)
	_add_scene_prop(west_service, "SpareHoops", ROPE, Vector3(-5.45, 0.18, 2.65), Vector3.ONE * 0.62, Vector3(0.0, 0.0, 90.0))
	_add_scene_prop(west_service, "CooperCrate", CRATE, Vector3(-5.25, 0.18, 4.35), Vector3.ONE * 0.45, Vector3(0.0, 25.0, 0.0))
	for y in [0.72, 1.08, 1.44]:
		_add_box(west_service, "CooperTool", Vector3(-5.72, y, 1.55), Vector3(0.08, 0.52, 0.08), CELLAR_IRON)

	var measures := Node3D.new()
	measures.name = "BrewersMeasuresAndLedger"
	details.add_child(measures)
	_add_box(measures, "BatchLedger", Vector3(1.15, 1.72, -4.78), Vector3(1.65, 1.0, 0.1), CELLAR_OAK)
	for row in range(3):
		_add_box(measures, "ChalkBatchLine", Vector3(1.15, 1.96 - float(row) * 0.27, -4.71), Vector3(1.15, 0.045, 0.025), CELLAR_CHALK)
	_add_cylinder(measures, "CopperFunnel", Vector3(2.35, 0.52, -4.35), 0.25, 0.45, CELLAR_COPPER)
	_add_cylinder(measures, "WoodMeasure", Vector3(2.95, 0.4, -4.35), 0.24, 0.55, CELLAR_OAK)
	for x in [-4.45, 4.45]:
		_add_box(details, "CellarLanternMountWest" if x < 0.0 else "CellarLanternMountEast", Vector3(x, 2.65, -4.82), Vector3(0.58, 0.78, 0.14), CELLAR_TIMBER)
		var cellar_lantern := _add_scene_prop(details, "CellarLanternWest" if x < 0.0 else "CellarLanternEast", LANTERN, Vector3(x, 2.62, -4.64), Vector3.ONE * 0.66)
		if cellar_lantern != null:
			cellar_lantern.set_meta("mounted_to_structure", true)
			cellar_lantern.set_meta("mount_surface", "rear_interior_wall")


func _add_rear_aging_barrel_stacks(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "RearAgingBarrelStacks"
	root.set_meta("authority_role", "non_workstation_non_inventory_decoration")
	parent.add_child(root)
	for side in [-1.0, 1.0]:
		var stack := Node3D.new()
		stack.name = "WestAgingStack" if side < 0.0 else "EastAgingStack"
		stack.position = Vector3(side * 4.72, 0.0, -4.18)
		root.add_child(stack)
		_add_box(stack, "RackBase", Vector3(0.0, 0.22, 0.0), Vector3(1.62, 0.18, 1.02), CELLAR_TIMBER)
		_add_box(stack, "LowerCradle", Vector3(0.0, 0.54, -0.38), Vector3(1.78, 0.13, 0.13), CELLAR_OAK)
		_add_box(stack, "LowerCradle", Vector3(0.0, 0.54, 0.38), Vector3(1.78, 0.13, 0.13), CELLAR_OAK)
		_add_box(stack, "UpperShelf", Vector3(0.0, 1.17, 0.0), Vector3(1.05, 0.13, 0.92), CELLAR_OAK)
		_add_storage_barrel(stack, "LowerAgingBarrel", Vector3(-0.42, 0.31, 0.0), 0.52, 1)
		_add_storage_barrel(stack, "LowerAgingBarrel", Vector3(0.42, 0.31, 0.0), 0.52, 1)
		_add_storage_barrel(stack, "UpperAgingBarrel", Vector3(0.0, 1.24, 0.0), 0.52, 1)


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
	_add_cooling_cistern(level_2_interior)
	_add_level_two_pipework(level_2_interior)
	_add_batch_board(level_2_interior)
	var level_2_exterior := Node3D.new()
	level_2_exterior.name = "ExteriorAdditions"
	level_2.add_child(level_2_exterior)
	_add_level_two_masonry(level_2_exterior)
	_add_shaded_barrel_rack(level_2_exterior)
	var level_2_roof := Node3D.new()
	level_2_roof.name = "RoofStructureAdditions"
	level_2.add_child(level_2_roof)
	_add_copper_ridge_vent(level_2_roof, "MaturationAirVent", 0.0)

	var level_3 := Node3D.new()
	level_3.name = "Level3"
	level_3.visible = false
	upgrades.add_child(level_3)
	var level_3_interior := Node3D.new()
	level_3_interior.name = "InteriorAdditions"
	level_3.add_child(level_3_interior)
	_add_third_bay_service_branch(level_3_interior)
	var level_3_exterior := Node3D.new()
	level_3_exterior.name = "ExteriorAdditions"
	level_3.add_child(level_3_exterior)
	_add_loading_extension(level_3_exterior)
	var level_3_roof := Node3D.new()
	level_3_roof.name = "RoofStructureAdditions"
	level_3.add_child(level_3_roof)
	_add_copper_ridge_vent(level_3_roof, "ThirdFermentationVent", -3.5)


func _add_cooling_cistern(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "StoneCoolingCistern"
	root.position = Vector3(-5.15, 0.0, 0.0)
	root.set_meta("authority_role", "non_workstation_efficiency_symbol")
	parent.add_child(root)
	_add_box(root, "StoneTrough", Vector3(0.0, 0.45, 0.0), Vector3(1.35, 0.75, 2.15), CELLAR_STONE_LIGHT)
	_add_box(root, "CoolWater", Vector3(0.0, 0.86, 0.0), Vector3(1.05, 0.05, 1.82), CELLAR_WATER)
	_add_cylinder(root, "CopperCoil", Vector3(0.0, 1.12, 0.0), 0.34, 1.35, CELLAR_COPPER, Vector3(90.0, 0.0, 0.0))


func _add_level_two_pipework(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "LevelTwoCopperPipework"
	root.set_meta("authority_role", "non_workstation_efficiency_symbol")
	parent.add_child(root)
	_add_cylinder(root, "RearHeaderPipe", Vector3(0.0, 2.72, -4.48), 0.07, 9.7, CELLAR_COPPER, Vector3(0.0, 0.0, 90.0))
	for x in [-3.5, 3.5]:
		_add_cylinder(root, "CaskDropPipe", Vector3(x, 1.9, -3.9), 0.06, 1.65, CELLAR_COPPER)
		_add_cylinder(root, "CaskPipeElbow", Vector3(x, 2.72, -4.15), 0.06, 0.65, CELLAR_COPPER, Vector3(90.0, 0.0, 0.0))
		_add_cylinder(root, "ValveWheel", Vector3(x, 1.25, -3.9), 0.16, 0.04, CELLAR_IRON, Vector3(90.0, 0.0, 0.0))


func _add_batch_board(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "MaturationBatchBoard"
	root.position = Vector3(5.65, 1.85, -1.25)
	root.rotation_degrees.y = -90.0
	parent.add_child(root)
	_add_box(root, "OakBoard", Vector3.ZERO, Vector3(1.75, 1.22, 0.1), CELLAR_OAK)
	for row in range(4):
		_add_box(root, "ChalkLine", Vector3(0.0, 0.38 - float(row) * 0.25, 0.075), Vector3(1.2, 0.04, 0.025), CELLAR_CHALK)


func _add_level_two_masonry(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "LevelTwoMasonryReinforcement"
	parent.add_child(root)
	for side in [-1.0, 1.0]:
		for z in [-3.3, 0.0, 3.3]:
			_add_box(root, "CappedStonePier", Vector3(side * 6.36, 1.35, z), Vector3(0.48, 2.3, 0.72), CELLAR_STONE_LIGHT)
			_add_box(root, "PierCap", Vector3(side * 6.36, 2.52, z), Vector3(0.68, 0.16, 0.92), CELLAR_STONE)


func _add_shaded_barrel_rack(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ShadedMaturationBarrelRack"
	root.position = Vector3(5.78, 0.0, -3.65)
	parent.add_child(root)
	_add_box(root, "StoneRackBase", Vector3(0.0, 0.16, 0.0), Vector3(1.75, 0.32, 2.55), CELLAR_STONE)
	for z in [-0.74, 0.0, 0.74]:
		_add_storage_barrel(root, "LowerMaturationBarrel", Vector3(0.0, 0.34, z), 0.5, 2, Vector3(0.0, 90.0, 0.0))
	_add_box(root, "UpperRackShelf", Vector3(0.0, 1.03, 0.0), Vector3(1.5, 0.13, 1.72), CELLAR_OAK)
	for z in [-0.39, 0.39]:
		_add_storage_barrel(root, "UpperMaturationBarrel", Vector3(0.0, 1.08, z), 0.48, 2, Vector3(0.0, 90.0, 0.0))
	for z in [-1.1, 1.1]:
		_add_box(root, "RackPost", Vector3(0.0, 1.05, z), Vector3(0.18, 1.75, 0.18), CELLAR_TIMBER)
	var awning := _add_box(root, "LowShadeAwning", Vector3(0.0, 1.95, 0.0), Vector3(1.95, 0.14, 2.85), CELLAR_ROOF_EDGE)
	awning.rotation_degrees.x = -7.0


func _add_third_bay_service_branch(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ThirdFermentationServiceBranch"
	root.set_meta("workstation_id", "cellar_03")
	parent.add_child(root)
	_add_cylinder(root, "ThirdDropPipe", Vector3(-4.55, 1.95, 1.45), 0.065, 1.6, CELLAR_COPPER)
	_add_cylinder(root, "ThirdBranchPipe", Vector3(-4.02, 2.72, 1.45), 0.065, 1.05, CELLAR_COPPER, Vector3(0.0, 0.0, 90.0))
	_add_cylinder(root, "ThirdValveWheel", Vector3(-4.55, 1.3, 1.45), 0.17, 0.04, CELLAR_IRON, Vector3(90.0, 0.0, 0.0))
	_add_scene_prop(root, "ThirdBayWashBucket", BUCKET, Vector3(-5.15, 0.18, 2.55), Vector3.ONE * 0.55)
	_add_box(root, "ThirdBatchSlate", Vector3(-5.68, 1.75, 3.25), Vector3(0.1, 1.0, 1.45), CELLAR_OAK)


func _add_loading_extension(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "LevelThreeLoadingAndDispatchRack"
	root.position = Vector3(-4.75, 0.0, 5.45)
	parent.add_child(root)
	_add_box(root, "LoadingStonePad", Vector3(0.0, 0.14, 0.0), Vector3(3.5, 0.28, 0.95), CELLAR_STONE)
	_add_storage_barrel(root, "LowerDispatchBarrel", Vector3(-1.16, 0.28, 0.0), 0.5, 3, Vector3(0.0, 90.0, 0.0))
	_add_storage_barrel(root, "LowerDispatchBarrel", Vector3(-0.48, 0.28, 0.0), 0.5, 3, Vector3(0.0, 90.0, 0.0))
	_add_box(root, "DispatchUpperCradle", Vector3(-0.82, 1.0, 0.0), Vector3(0.82, 0.12, 0.78), CELLAR_OAK)
	_add_storage_barrel(root, "UpperDispatchBarrel", Vector3(-0.82, 1.05, 0.0), 0.48, 3, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(root, "DispatchCrate", CRATE, Vector3(0.75, 0.2, 0.0), Vector3.ONE * 0.45, Vector3(0.0, -12.0, 0.0))
	_add_box(root, "LoadingRackRail", Vector3(0.0, 0.72, -0.38), Vector3(3.25, 0.14, 0.14), CELLAR_TIMBER)


func _add_copper_ridge_vent(parent: Node3D, node_name: String, x: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = Vector3(x, 5.25, 0.0)
	parent.add_child(root)
	_add_box(root, "VentNeck", Vector3(0.0, 0.28, 0.0), Vector3(0.62, 0.55, 0.62), CELLAR_TIMBER)
	_add_box(root, "LouverFace", Vector3(0.0, 0.3, 0.33), Vector3(0.42, 0.26, 0.05), CELLAR_COPPER)
	_add_cylinder(root, "CopperCap", Vector3(0.0, 0.62, 0.0), 0.46, 0.12, CELLAR_COPPER)


func _add_low_vent(parent: Node3D, node_name: String, x: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = Vector3(x, 5.18, 0.0)
	parent.add_child(root)
	_add_box(root, "VentBody", Vector3(0.0, 0.24, 0.0), Vector3(0.72, 0.48, 0.62), CELLAR_TIMBER)
	_add_box(root, "VentCap", Vector3(0.0, 0.53, 0.0), Vector3(0.98, 0.11, 0.84), CELLAR_ROOF_EDGE)
	for x_offset in [-0.2, 0.0, 0.2]:
		_add_box(root, "VentSlat", Vector3(x_offset, 0.24, 0.34), Vector3(0.08, 0.24, 0.04), CELLAR_COPPER)


func _add_cellar_window(parent: Node3D, center: Vector3, rotation_y: float) -> void:
	var root := Node3D.new()
	root.name = "HighCellarWindow"
	root.position = center
	root.rotation_degrees.y = rotation_y
	parent.add_child(root)
	_add_box(root, "StoneFrame", Vector3.ZERO, Vector3(1.45, 0.85, 0.18), CELLAR_STONE_LIGHT)
	_add_box(root, "BottleGlassPane", Vector3(0.0, 0.0, 0.12), Vector3(1.08, 0.54, 0.06), CELLAR_GLASS)
	for x in [-0.34, 0.0, 0.34]:
		_add_box(root, "IronBar", Vector3(x, 0.0, 0.17), Vector3(0.06, 0.58, 0.05), CELLAR_IRON)


func _add_vine_symbol(parent: Node3D, center: Vector3) -> void:
	_add_cylinder(parent, "VineStem", center, 0.035, 0.72, Color("#5d7250"), Vector3(0.0, 0.0, 90.0))
	for offset in [Vector3(-0.22, 0.15, 0.0), Vector3(0.0, -0.12, 0.0), Vector3(0.22, 0.15, 0.0)]:
		_add_sphere(parent, "Grape", center + offset, 0.12, CELLAR_WINE)


func _add_bottle(parent: Node3D, center: Vector3, radius: float) -> void:
	_add_cylinder(parent, "WineBottleBody", center, radius, 0.3, CELLAR_GLASS)
	_add_cylinder(parent, "WineBottleNeck", center + Vector3(0.0, 0.19, 0.0), radius * 0.45, 0.16, CELLAR_GLASS.darkened(0.08))


func _add_grain_sack(parent: Node3D, center: Vector3, rotation_y: float) -> void:
	var sack := _add_sphere(parent, "BrewingGrainSack", center + Vector3(0.0, 0.28, 0.0), 0.38, CELLAR_GRAIN)
	sack.scale = Vector3(0.78, 1.15, 0.58)
	sack.rotation_degrees.y = rotation_y
	_add_cylinder(parent, "SackTie", center + Vector3(0.0, 0.65, 0.0), 0.09, 0.12, CELLAR_TIMBER)


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


func _add_storage_barrel(parent: Node3D, node_name: String, position_value: Vector3, uniform_scale: float, required_level: int, rotation_value: Vector3 = Vector3.ZERO) -> Node3D:
	var barrel := _add_scene_prop(
		parent,
		node_name,
		BARREL,
		position_value,
		Vector3.ONE * uniform_scale * DECORATIVE_BARREL_SCALE_MULTIPLIER,
		rotation_value
	)
	if barrel == null:
		return null
	barrel.set_meta("decorative_storage_barrel", true)
	barrel.set_meta("required_level", required_level)
	barrel.set_meta("authority_role", "non_workstation_non_inventory_decoration")
	return barrel


func _visible_decorative_storage_barrel_count() -> int:
	var total := 0
	for node in find_children("*", "Node3D", true, false):
		if bool(node.get_meta("decorative_storage_barrel", false)) and (node as Node3D).is_visible_in_tree():
			total += 1
	return total


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
	mesh.radial_segments = 12
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.rotation_degrees = rotation_value
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
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
	material.roughness = 0.9
	_material_cache[key] = material
	return material
