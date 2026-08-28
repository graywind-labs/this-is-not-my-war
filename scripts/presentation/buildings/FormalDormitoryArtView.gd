class_name FormalDormitoryArtView
extends BuildingArtView


const WALL_STRAIGHT := "res://assets/3d/quaternius/buildings/wall_plaster_straight.glb"
const WALL_DOOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round.glb"
const FLOOR_DARK := "res://assets/3d/quaternius/buildings/floor_wood_dark.glb"
const CHEST := "res://assets/3d/quaternius/props/warehouse_chest.glb"
const SHELF := "res://assets/3d/quaternius/props/workshop_shelf.glb"
const PEG_RACK := "res://assets/3d/quaternius/props/peg_rack.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const AUTO_DOOR_SCRIPT := preload("res://scripts/presentation/buildings/BuildingAutoDoor.gd")
const WASH_BASIN_BUILDER := preload("res://scripts/presentation/buildings/MedievalWashBasinBuilder.gd")

const BUILDING_FOOTPRINT := Vector2(14.0, 13.0)
const LOT_SIZE := Vector2(16.0, 14.0)
const MAXIMUM_LEVEL := 2
const BED_BAY_Z := [-4.8, -2.4, 0.0, 2.4, 4.8]

const DORM_WALL := Color("#b7aa99")
const DORM_STONE := Color("#66615d")
const DORM_TIMBER := Color("#47342f")
const DORM_OAK := Color("#72523e")
const DORM_ROOF := Color("#70434b")
const DORM_ROOF_EDGE := Color("#422f36")
const DORM_TEXTILE := Color("#677b88")
const DORM_LINEN := Color("#c7bda7")
const DORM_IRON := Color("#34383d")
const DORM_FIRE := Color("#d96732")
const DORM_AMBER := Color("#d8ad61")

var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_formal_dormitory()
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
		"bed_count": _count_workstation_prefix(workstation_states, "dormitory_bed_"),
		"available_bed_count": _count_available_prefix(workstation_states, "dormitory_bed_"),
		"assigned_bed_count": _count_assigned_workstations(workstation_states),
		"active_fixture_visual_count": _active_fixture_visual_count(),
		"active_fixture_collision_count": _active_fixture_collision_count(),
		"level_visual_addition_counts": {
			"level_1": _mesh_count_at("Interior/Level1Details") + _mesh_count_at("Exterior") + _mesh_count_at("Roof"),
			"level_2": _mesh_count_at("UpgradeVisuals/Level2")
		},
		"building_footprint": BUILDING_FOOTPRINT,
		"lot_size": LOT_SIZE,
		"architectural_style": "medieval_border_communal_bunkhouse",
		"facade_profile": "five_bed_bays_moon_pillow_sign_and_repeated_windows",
		"roof_profile": "long_low_wine_shingle_gable_with_five_ridge_vents",
		"gable_end_profile": "sealed_warm_plaster_with_bunkhouse_timber",
		"sealed_gable_end_count": 2,
		"functional_visual_language": "ten_fixed_beds_personal_chests_pegs_linen_and_night_lanterns",
		"level_two_upgrade_profile": "hearth_chimney_insulation_repairs_and_storage_without_bed_gain",
		"palette": {
			"wall": DORM_WALL.to_html(false),
			"timber": DORM_TIMBER.to_html(false),
			"roof": DORM_ROOF.to_html(false),
			"textile": DORM_TEXTILE.to_html(false),
			"linen": DORM_LINEN.to_html(false)
		},
		"auto_door": door_snapshot,
		"roof_mesh_count": _roof_meshes.size(),
		"roof_structure_additions_fade_with_roof": additional_roof_fade_paths.size() == 1,
		"exterior_material_count": _exterior_materials.size(),
		"interior_revealed_for_selection": is_interior_revealed_for_selection(),
		"shell_opacity": maxf(_roof_opacity, _exterior_opacity),
		"navigation_ready": _formal_navigation_ready(),
		"collision_authority": "formal_station_static_and_fixed_bed_fixture_collision",
		"navigation_authority": "formal_station_navigation_mesh",
		"sleep_authority": "building_action_and_npc_system_only",
		"authority_role": "presentation_only"
	}


func _build_formal_dormitory() -> void:
	building_id = "dormitory"
	roof_near_distance = 58.0
	roof_far_distance = 70.0
	minimum_roof_opacity = 0.06
	fade_exterior_with_roof = true
	minimum_exterior_opacity = 0.06
	interior_reveal_opacity_threshold = 0.72
	interaction_bounds_center = Vector3(0.0, 2.8, 0.0)
	interaction_bounds_size = Vector3(16.2, 6.8, 14.2)
	roof_albedo_override = DORM_ROOF
	preserve_roof_albedo_texture = false
	exterior_albedo_tint = DORM_WALL
	static_collision_path = NodePath("../StaticCollision")
	workstation_markers_path = NodePath("../FixtureLayout/NPCStands")
	set_meta("art_revision", "t0135_p8ar7r")
	set_meta("formal_vertical_slice", true)
	set_meta("architectural_style", "medieval_border_communal_bunkhouse")
	set_meta("footprint_meters", BUILDING_FOOTPRINT)
	set_meta("lot_size_meters", LOT_SIZE)
	set_meta("maximum_level", MAXIMUM_LEVEL)
	set_meta("fixed_bed_capacity", 10)
	_build_foundation_and_floor()
	_build_exterior()
	_build_roof()
	_build_level_one_details()
	_build_upgrade_visuals()
	additional_roof_fade_paths = [NodePath("UpgradeVisuals/Level2/RoofStructureAdditions")]
	additional_exterior_fade_paths = [NodePath("UpgradeVisuals/Level2/ExteriorAdditions")]


func _build_foundation_and_floor() -> void:
	var interior := Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_add_box(interior, "StoneFoundation", Vector3(0.0, 0.11, 0.0), Vector3(13.9, 0.22, 12.9), DORM_STONE.darkened(0.16))
	var floor := Node3D.new()
	floor.name = "Floor"
	interior.add_child(floor)
	for x in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
		for z in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
			_add_scene_prop(floor, "DarkOakFloor", FLOOR_DARK, Vector3(x, 0.14, z), Vector3(1.0, 0.2, 1.0))
	_add_box(interior, "CentralWovenRunner", Vector3(0.0, 0.19, 0.2), Vector3(1.45, 0.035, 11.7), DORM_TEXTILE.darkened(0.12))
	for z in [-4.8, -2.4, 0.0, 2.4, 4.8]:
		_add_box(interior, "RunnerCrossBand", Vector3(0.0, 0.212, z), Vector3(1.52, 0.018, 0.09), DORM_LINEN.darkened(0.12))


func _build_exterior() -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	var wall_shell := Node3D.new()
	wall_shell.name = "WarmPlasterWallShell"
	exterior.add_child(wall_shell)
	for x in [-6.0, -4.0, -2.0, 2.0, 4.0, 6.0]:
		_add_scene_prop(wall_shell, "FrontWall", WALL_STRAIGHT, Vector3(x, 0.2, 6.44), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(wall_shell, "RoundDormitoryDoor", WALL_DOOR, Vector3(0.0, 0.2, 6.44), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
	for x in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
		_add_scene_prop(wall_shell, "RearWall", WALL_STRAIGHT, Vector3(x, 0.2, -6.5), Vector3.ONE)
	for side in [-1.0, 1.0]:
		for z in [-5.5, -3.5, -1.5, 0.5, 2.5, 4.5]:
			_add_scene_prop(wall_shell, "SideWall", WALL_STRAIGHT, Vector3(side * 7.0, 0.2, z), Vector3.ONE, Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0))

	var frame := Node3D.new()
	frame.name = "FiveBayTimberFrame"
	exterior.add_child(frame)
	_add_box(frame, "FrontStoneCourse", Vector3(0.0, 0.42, 6.58), Vector3(14.15, 0.62, 0.28), DORM_STONE)
	_add_box(frame, "RearStoneCourse", Vector3(0.0, 0.42, -6.62), Vector3(14.15, 0.62, 0.32), DORM_STONE.darkened(0.04))
	for x in [-6.88, -4.6, -2.32, 2.32, 4.6, 6.88]:
		_add_box(frame, "FrontPost", Vector3(x, 1.74, 6.58), Vector3(0.24, 3.22, 0.24), DORM_TIMBER)
		_add_box(frame, "RearPost", Vector3(x, 1.74, -6.65), Vector3(0.24, 3.22, 0.26), DORM_TIMBER)
	for x in [-1.17, 1.17]:
		_add_box(frame, "DoorJamb", Vector3(x, 1.7, 6.59), Vector3(0.22, 3.14, 0.24), DORM_TIMBER)
	for side in [-1.0, 1.0]:
		for z in [-6.18, -3.6, -1.2, 1.2, 3.6, 6.18]:
			_add_box(frame, "BedBayPost", Vector3(side * 7.14, 1.74, z), Vector3(0.28, 3.22, 0.24), DORM_TIMBER)
	_add_box(frame, "FrontLintel", Vector3(0.0, 3.22, 6.59), Vector3(14.15, 0.28, 0.24), DORM_TIMBER)
	_add_box(frame, "RearLintel", Vector3(0.0, 3.22, -6.64), Vector3(14.15, 0.28, 0.28), DORM_TIMBER)
	var gable_ends := Node3D.new()
	gable_ends.name = "SealedDormitoryGableEnds"
	exterior.add_child(gable_ends)
	for side in [-1.0, 1.0]:
		var side_name := "Rear" if side < 0.0 else "Front"
		var end_z := -6.58 if side < 0.0 else 6.56
		_add_gable_wall(gable_ends, "%sWarmPlasterGableWall" % side_name, Vector3(0.0, 4.55, end_z), Vector3(14.75, 2.46, 0.3), _material(DORM_WALL))
		_add_box(gable_ends, "%sGableTie" % side_name, Vector3(0.0, 3.32, end_z), Vector3(14.75, 0.22, 0.34), DORM_TIMBER)
		_add_box(gable_ends, "%sKingPost" % side_name, Vector3(0.0, 4.54, end_z), Vector3(0.3, 2.44, 0.34), DORM_TIMBER)
		var west_rafter := _add_box(gable_ends, "%sWestRakingBeam" % side_name, Vector3(-3.6, 4.55, end_z), Vector3(7.7, 0.22, 0.34), DORM_TIMBER)
		west_rafter.rotation_degrees.z = 17.0
		var east_rafter := _add_box(gable_ends, "%sEastRakingBeam" % side_name, Vector3(3.6, 4.55, end_z), Vector3(7.7, 0.22, 0.34), DORM_TIMBER)
		east_rafter.rotation_degrees.z = -17.0

	var windows := Node3D.new()
	windows.name = "TenBedBayWindows"
	exterior.add_child(windows)
	for side in [-1.0, 1.0]:
		for z in BED_BAY_Z:
			_add_bed_bay_window(windows, Vector3(side * 7.22, 2.0, float(z)), side)
	for x in [-4.7, 4.7]:
		_add_front_window(windows, Vector3(x, 2.0, 6.66))

	var sign := Node3D.new()
	sign.name = "MoonAndPillowSign"
	sign.position = Vector3(0.0, 4.0, 6.76)
	exterior.add_child(sign)
	_add_box(sign, "OakSignBoard", Vector3.ZERO, Vector3(2.35, 0.88, 0.14), DORM_TIMBER.lightened(0.08))
	_add_cylinder(sign, "MoonDisc", Vector3(-0.48, 0.02, 0.12), 0.28, 0.08, DORM_AMBER, Vector3(90.0, 0.0, 0.0))
	_add_cylinder(sign, "MoonCutout", Vector3(-0.36, 0.11, 0.17), 0.24, 0.085, DORM_TIMBER.lightened(0.08), Vector3(90.0, 0.0, 0.0))
	_add_box(sign, "Pillow", Vector3(0.47, -0.02, 0.12), Vector3(0.7, 0.38, 0.1), DORM_LINEN)
	_add_box(sign, "PillowBand", Vector3(0.47, -0.02, 0.18), Vector3(0.08, 0.4, 0.04), DORM_TEXTILE)

	var door := Node3D.new()
	door.name = "AutoDoor"
	door.position = Vector3(0.0, 0.2, 6.63)
	door.set_script(AUTO_DOOR_SCRIPT)
	door.call("configure", DORM_OAK, DORM_TIMBER, DORM_IRON)
	exterior.add_child(door)


func _build_roof() -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.set_meta("roof_fade_candidate", true)
	add_child(roof)
	var main_roof := Node3D.new()
	main_roof.name = "LongWineShingleRoof"
	roof.add_child(main_roof)
	var west := _add_box(main_roof, "WestShingleSlope", Vector3(-3.7, 4.585, 0.0), Vector3(7.78, 0.18, 13.84), DORM_ROOF)
	west.rotation_degrees.z = 17.0
	var east := _add_box(main_roof, "EastShingleSlope", Vector3(3.7, 4.585, 0.0), Vector3(7.78, 0.18, 13.84), DORM_ROOF.darkened(0.045))
	east.rotation_degrees.z = -17.0
	_add_cylinder(main_roof, "RoundedWineRidge", Vector3(0.0, 5.74, 0.0), 0.17, 13.9, DORM_ROOF_EDGE, Vector3(90.0, 0.0, 0.0))
	for z in [-6.1, -4.8, -3.6, -2.4, -1.2, 0.0, 1.2, 2.4, 3.6, 4.8, 6.1]:
		var west_band := _add_box(main_roof, "WestShingleCourse", Vector3(-3.7, 4.675, float(z)), Vector3(7.7, 0.045, 0.07), DORM_ROOF_EDGE.lightened(0.04))
		west_band.rotation_degrees.z = 17.0
		var east_band := _add_box(main_roof, "EastShingleCourse", Vector3(3.7, 4.675, float(z)), Vector3(7.7, 0.045, 0.07), DORM_ROOF_EDGE)
		east_band.rotation_degrees.z = -17.0
	var vents := Node3D.new()
	vents.name = "FiveLowRidgeVents"
	roof.add_child(vents)
	for index in range(BED_BAY_Z.size()):
		_add_low_roof_vent(vents, "BedBayVent%02d" % (index + 1), float(BED_BAY_Z[index]))


func _build_level_one_details() -> void:
	var interior := get_node("Interior") as Node3D
	var details := Node3D.new()
	details.name = "Level1Details"
	interior.add_child(details)
	var outer_storage := Node3D.new()
	outer_storage.name = "OuterWallPersonalStorage"
	details.add_child(outer_storage)
	var textile_colors := [DORM_TEXTILE, Color("#806b66"), Color("#66765f"), Color("#746b84"), Color("#8a7657")]
	for bay_index in range(BED_BAY_Z.size()):
		var z := float(BED_BAY_Z[bay_index])
		for side in [-1.0, 1.0]:
			var side_name := "West" if side < 0.0 else "East"
			_add_scene_prop(outer_storage, "%sChest%02d" % [side_name, bay_index + 1], CHEST, Vector3(side * 5.35, 0.18, z), Vector3.ONE * 0.48, Vector3(0.0, -90.0 if side < 0.0 else 90.0, 0.0))
			_add_box(outer_storage, "%sFoldedBlanket%02d" % [side_name, bay_index + 1], Vector3(side * 5.15, 0.78, z), Vector3(0.62, 0.12, 0.72), textile_colors[bay_index])
			_add_scene_prop(outer_storage, "%sPegRack%02d" % [side_name, bay_index + 1], PEG_RACK, Vector3(side * 6.62, 1.74, z), Vector3.ONE * 0.58, Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0))

	var linen := Node3D.new()
	linen.name = "RearLinenStorage"
	details.add_child(linen)
	for side in [-1.0, 1.0]:
		_add_scene_prop(linen, "LinenShelf", SHELF, Vector3(side * 5.75, 0.18, -5.9), Vector3.ONE * 0.46, Vector3(0.0, 180.0, 0.0))
		for stack_index in range(3):
			_add_box(linen, "FoldedLinen", Vector3(side * (5.45 + float(stack_index % 2) * 0.38), 0.72 + float(stack_index) * 0.18, -5.45), Vector3(0.55, 0.1, 0.42), DORM_LINEN.lightened(float(stack_index) * 0.025))
	var wash_basin: Node3D = WASH_BASIN_BUILDER.build_wash_basin("CommonWashBasin", Vector3(-1.0, 0.0, -5.78), 0.0, {
		"timber": DORM_OAK,
		"dark_timber": DORM_TIMBER,
		"stone": DORM_STONE,
		"basin": DORM_LINEN.darkened(0.12),
		"metal": Color("#8b613e"),
		"water": Color("#527c82"),
		"linen": DORM_LINEN
	})
	details.add_child(wash_basin)
	_add_box(details, "DutyRosterBoard", Vector3(-3.0, 1.7, 6.22), Vector3(2.25, 1.0, 0.12), DORM_OAK)
	for row in range(3):
		_add_box(details, "RosterChalkLine", Vector3(-3.0, 1.94 - float(row) * 0.25, 6.3), Vector3(1.65, 0.045, 0.025), DORM_LINEN)
	var lantern_names := ["NightLanternRear", "NightLanternCenter", "NightLanternFront"]
	var lantern_positions := [-3.0, 0.0, 3.0]
	for lantern_index in lantern_positions.size():
		_add_scene_prop(details, lantern_names[lantern_index], LANTERN, Vector3(0.0, 2.55, float(lantern_positions[lantern_index])), Vector3.ONE * 0.66)


func _build_upgrade_visuals() -> void:
	var upgrades := Node3D.new()
	upgrades.name = "UpgradeVisuals"
	add_child(upgrades)
	var level_2 := Node3D.new()
	level_2.name = "Level2"
	level_2.visible = false
	upgrades.add_child(level_2)

	var interior_additions := Node3D.new()
	interior_additions.name = "InteriorAdditions"
	level_2.add_child(interior_additions)
	_add_hearth(interior_additions)
	var insulation := Node3D.new()
	insulation.name = "InsulatedWainscot"
	interior_additions.add_child(insulation)
	for side in [-1.0, 1.0]:
		for z in [-3.6, -1.2, 1.2, 3.6]:
			_add_box(insulation, "OakInsulationPanel", Vector3(side * 6.73, 1.02, z), Vector3(0.12, 1.45, 2.05), DORM_OAK.darkened(0.06))
			_add_box(insulation, "WoolInset", Vector3(side * 6.64, 1.08, z), Vector3(0.05, 1.02, 1.55), DORM_TEXTILE.darkened(0.06))
	var repaired_linen := Node3D.new()
	repaired_linen.name = "ExpandedLinenAndRepairKit"
	interior_additions.add_child(repaired_linen)
	_add_scene_prop(repaired_linen, "RepairChest", CHEST, Vector3(-5.65, 0.18, 5.65), Vector3.ONE * 0.52, Vector3(0.0, -90.0, 0.0))
	for index in range(4):
		_add_box(repaired_linen, "SpareBlanket", Vector3(-5.35, 0.72 + float(index) * 0.13, 5.55), Vector3(0.72, 0.09, 0.58), DORM_LINEN.darkened(float(index) * 0.025))

	var exterior_additions := Node3D.new()
	exterior_additions.name = "ExteriorAdditions"
	level_2.add_child(exterior_additions)
	for side in [-1.0, 1.0]:
		for z in BED_BAY_Z:
			_add_window_shutters(exterior_additions, Vector3(side * 7.32, 2.0, float(z)), side)
	for x in [-5.8, -3.5, 3.5, 5.8]:
		var brace := _add_box(exterior_additions, "FrontRepairBrace", Vector3(x, 1.55, 6.72), Vector3(0.18, 2.55, 0.14), DORM_TIMBER.lightened(0.04))
		brace.rotation_degrees.z = -16.0 if x < 0.0 else 16.0
	_add_firewood_bundle(exterior_additions, Vector3(6.95, 0.0, -5.15))

	var roof_additions := Node3D.new()
	roof_additions.name = "RoofStructureAdditions"
	level_2.add_child(roof_additions)
	_add_hearth_chimney(roof_additions)
	for z in [-3.6, 0.0, 3.6]:
		_add_box(roof_additions, "CeilingRepairTie", Vector3(0.0, 3.42, z), Vector3(13.15, 0.18, 0.22), DORM_TIMBER)


func _add_bed_bay_window(parent: Node3D, center: Vector3, side: float) -> void:
	var root := Node3D.new()
	root.name = "BedBayWindow"
	root.position = center
	root.rotation_degrees.y = 90.0 if side < 0.0 else -90.0
	parent.add_child(root)
	_add_box(root, "OakFrame", Vector3.ZERO, Vector3(1.08, 1.2, 0.12), DORM_TIMBER)
	_add_box(root, "AmberPane", Vector3(0.0, 0.0, 0.08), Vector3(0.78, 0.88, 0.05), DORM_AMBER.darkened(0.08))
	_add_box(root, "CrossBar", Vector3(0.0, 0.0, 0.13), Vector3(0.82, 0.08, 0.05), DORM_OAK)
	_add_box(root, "Mullion", Vector3(0.0, 0.0, 0.14), Vector3(0.08, 0.92, 0.05), DORM_OAK)


func _add_front_window(parent: Node3D, center: Vector3) -> void:
	var root := Node3D.new()
	root.name = "FrontWindow"
	root.position = center
	parent.add_child(root)
	_add_box(root, "OakFrame", Vector3.ZERO, Vector3(1.12, 1.2, 0.12), DORM_TIMBER)
	_add_box(root, "AmberPane", Vector3(0.0, 0.0, 0.08), Vector3(0.82, 0.9, 0.05), DORM_AMBER.darkened(0.08))
	_add_box(root, "CrossBar", Vector3(0.0, 0.0, 0.13), Vector3(0.86, 0.08, 0.05), DORM_OAK)


func _add_low_roof_vent(parent: Node3D, node_name: String, z: float) -> void:
	var vent := Node3D.new()
	vent.name = node_name
	vent.position = Vector3(0.0, 5.78, z)
	parent.add_child(vent)
	_add_box(vent, "VentBody", Vector3(0.0, 0.12, 0.0), Vector3(0.72, 0.36, 0.58), DORM_TIMBER)
	var cap := _add_box(vent, "VentCap", Vector3(0.0, 0.36, 0.0), Vector3(0.98, 0.1, 0.8), DORM_ROOF_EDGE)
	cap.rotation_degrees.z = 4.0
	for x in [-0.2, 0.0, 0.2]:
		_add_box(vent, "VentSlat", Vector3(x, 0.13, 0.3), Vector3(0.08, 0.22, 0.04), DORM_AMBER.darkened(0.28))


func _add_hearth(parent: Node3D) -> void:
	var hearth := Node3D.new()
	hearth.name = "WarmStoneHearth"
	hearth.position = Vector3(1.0, 0.0, -5.78)
	hearth.set_meta("authority_role", "non_workstation_sleep_efficiency_symbol")
	parent.add_child(hearth)
	_add_box(hearth, "StoneBase", Vector3(0.0, 0.22, 0.0), Vector3(2.2, 0.44, 0.82), DORM_STONE)
	_add_box(hearth, "StoneBack", Vector3(0.0, 1.02, -0.25), Vector3(2.0, 1.5, 0.36), DORM_STONE.lightened(0.04))
	for side in [-1.0, 1.0]:
		_add_box(hearth, "HearthJamb", Vector3(side * 0.78, 0.84, 0.02), Vector3(0.3, 1.2, 0.44), DORM_STONE.darkened(0.05))
	_add_box(hearth, "OakMantel", Vector3(0.0, 1.66, 0.0), Vector3(2.28, 0.2, 0.55), DORM_TIMBER)
	for x in [-0.34, 0.0, 0.34]:
		_add_cylinder(hearth, "HearthLog", Vector3(x, 0.42, 0.22), 0.1, 0.72, DORM_OAK, Vector3(90.0, 0.0, 0.0))
	_add_sphere(hearth, "HearthGlow", Vector3(0.0, 0.57, 0.15), 0.28, DORM_FIRE)


func _add_hearth_chimney(parent: Node3D) -> void:
	var chimney := Node3D.new()
	chimney.name = "HearthChimney"
	chimney.position = Vector3(1.0, 0.0, -5.78)
	parent.add_child(chimney)
	_add_box(chimney, "StoneFlue", Vector3(0.0, 4.86, 0.0), Vector3(1.02, 3.18, 1.02), DORM_STONE.darkened(0.06))
	_add_box(chimney, "FlueCap", Vector3(0.0, 6.5, 0.0), Vector3(1.32, 0.18, 1.32), DORM_STONE)
	for side in [-1.0, 1.0]:
		_add_box(chimney, "RainGuardPost", Vector3(side * 0.34, 6.78, 0.0), Vector3(0.08, 0.48, 0.08), DORM_IRON)
	_add_box(chimney, "RainGuard", Vector3(0.0, 7.04, 0.0), Vector3(1.25, 0.1, 1.25), DORM_IRON)


func _add_window_shutters(parent: Node3D, center: Vector3, side: float) -> void:
	var shutters := Node3D.new()
	shutters.name = "BedBayWindShutters"
	shutters.position = center
	shutters.rotation_degrees.y = 90.0 if side < 0.0 else -90.0
	parent.add_child(shutters)
	for shutter_side in [-1.0, 1.0]:
		_add_box(shutters, "OakShutter", Vector3(shutter_side * 0.72, 0.0, 0.12), Vector3(0.34, 1.14, 0.1), DORM_OAK)
		for y in [-0.32, 0.0, 0.32]:
			_add_box(shutters, "ShutterSlat", Vector3(shutter_side * 0.72, y, 0.19), Vector3(0.28, 0.08, 0.04), DORM_TIMBER)


func _add_firewood_bundle(parent: Node3D, center: Vector3) -> void:
	var bundle := Node3D.new()
	bundle.name = "DryHearthWood"
	bundle.position = center
	parent.add_child(bundle)
	for row in range(3):
		for column in range(4):
			_add_cylinder(bundle, "SplitLog", Vector3(-0.48 + float(column) * 0.32, 0.17 + float(row) * 0.25, 0.0), 0.09, 0.7, DORM_OAK.lightened(float((row + column) % 2) * 0.06), Vector3(90.0, 0.0, 0.0))
	_add_box(bundle, "BundleRail", Vector3(0.0, 0.05, 0.0), Vector3(1.55, 0.1, 0.62), DORM_TIMBER)


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


func _count_assigned_workstations(states: Dictionary) -> int:
	var count := 0
	for key in states:
		if not str((states[key] as Dictionary).get("assigned_npc_id", "")).is_empty():
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
