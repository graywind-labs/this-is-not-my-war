class_name FormalChapelArtView
extends BuildingArtView


const WALL_STRAIGHT := "res://assets/3d/quaternius/buildings/wall_plaster_straight.glb"
const WALL_DOOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round.glb"
const FLOOR_DARK := "res://assets/3d/quaternius/buildings/floor_wood_dark.glb"
const CANDLESTICK := "res://assets/3d/quaternius/props/chapel_candlestick_triple.glb"
const BOOK := "res://assets/3d/quaternius/props/chapel_book.glb"
const CHALICE := "res://assets/3d/quaternius/props/chapel_chalice.glb"
const BANNER := "res://assets/3d/quaternius/props/main_hall_banner.glb"
const CRATE := "res://assets/3d/quaternius/props/crate_wooden.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const AUTO_DOOR_SCRIPT := preload("res://scripts/presentation/buildings/BuildingAutoDoor.gd")

const BUILDING_FOOTPRINT := Vector2(12.0, 12.0)
const INTERIOR_CLEAR_SIZE := Vector2(11.1, 11.1)
const MAXIMUM_LEVEL := 2
const NAVE_ROOF_PITCH_DEGREES := 31.0

const WEATHERED_LIMESTONE := Color("#858077")
const PALE_LIMESTONE := Color("#a39b8d")
const CHAPEL_ROOF_SLATE := Color("#65717a")
const CHAPEL_ROOF_EDGE := Color("#46515b")
const CHAPEL_ROOF_JOINT := Color("#77838d")
const CHAPEL_WOOD := Color("#3d2c29")
const CHAPEL_BURGUNDY := Color("#552d39")
const MUTED_GOLD := Color("#aa884d")

var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_formal_chapel()
	super._ready()


func _apply_visual_level(level: int, upgrade_in_progress: bool) -> void:
	super._apply_visual_level(mini(level, MAXIMUM_LEVEL), upgrade_in_progress)
	_apply_external_fixture_level_visibility()


func debug_force_visual_level(level: int) -> Dictionary:
	_apply_visual_level(clampi(level, 1, MAXIMUM_LEVEL), false)
	return get_art_slice_snapshot()


func get_art_slice_snapshot() -> Dictionary:
	var door_snapshot: Dictionary = {}
	var auto_door := get_node_or_null("Exterior/AutoDoor")
	if auto_door != null and auto_door.has_method("debug_get_snapshot"):
		door_snapshot = auto_door.call("debug_get_snapshot")
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
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"maximum_level": MAXIMUM_LEVEL,
		"upgrade_in_progress": _upgrade_in_progress,
		"level_2_visible": _is_visible(NodePath("UpgradeVisuals/Level2")),
		"level_3_exists": get_node_or_null("UpgradeVisuals/Level3") != null,
		"workstations": workstation_states,
		"altar_count": _count_workstation_prefix(workstation_states, "chapel_altar_"),
		"prayer_seat_count": _count_workstation_prefix(workstation_states, "chapel_prayer_seat_"),
		"active_fixture_visual_count": _active_fixture_visual_count(),
		"active_fixture_collision_count": _active_fixture_collision_count(),
		"level_visual_addition_counts": {
			"level_1": _mesh_count_at("Interior/Level1Details") + _mesh_count_at("Exterior") + _mesh_count_at("Roof"),
			"level_2": _mesh_count_at("UpgradeVisuals/Level2")
		},
		"building_footprint": BUILDING_FOOTPRINT,
		"interior_clear_size": INTERIOR_CLEAR_SIZE,
		"future_capacity_reserved": true,
		"architectural_style": "medieval_border_chapel",
		"facade_profile": "front_gable_pointed_portal_and_oculus",
		"sanctuary_profile": "reinforced_rear_apse_end",
		"roof_profile": "steep_nave_slate_with_front_cross",
		"roof_pitch_degrees": NAVE_ROOF_PITCH_DEGREES,
		"level_two_upgrade_profile": "west_bell_tower_stained_glass_buttress_and_ritual_enrichment",
		"palette": {
			"wall": WEATHERED_LIMESTONE.to_html(false),
			"roof": CHAPEL_ROOF_SLATE.to_html(false),
			"wood": CHAPEL_WOOD.to_html(false),
			"door": CHAPEL_BURGUNDY.to_html(false),
			"metal": MUTED_GOLD.to_html(false)
		},
		"roof_mesh_count": _roof_meshes.size(),
		"roof_structure_additions_fade_with_roof": additional_roof_fade_paths.has(
			NodePath("../FixtureLayout/Visuals/ChapelLevelTwoRoofTruss")
		),
		"exterior_material_count": _exterior_materials.size(),
		"interior_revealed_for_selection": is_interior_revealed_for_selection(),
		"shell_opacity": maxf(_roof_opacity, _exterior_opacity),
		"navigation_ready": _formal_navigation_ready(),
		"auto_door": door_snapshot,
		"collision_authority": "formal_station_static_and_level_synced_fixture_collision",
		"navigation_authority": "formal_station_navigation_mesh",
		"authority_role": "presentation_only"
	}


func _build_formal_chapel() -> void:
	building_id = "chapel"
	roof_near_distance = 58.0
	roof_far_distance = 70.0
	minimum_roof_opacity = 0.06
	fade_exterior_with_roof = true
	minimum_exterior_opacity = 0.06
	interior_reveal_opacity_threshold = 0.72
	interaction_bounds_center = Vector3(0.0, 3.8, 0.0)
	interaction_bounds_size = Vector3(14.5, 9.2, 14.5)
	roof_albedo_override = CHAPEL_ROOF_SLATE
	preserve_roof_albedo_texture = false
	exterior_albedo_tint = Color("#aaa59c")
	static_collision_path = NodePath("../StaticCollision")
	workstation_markers_path = NodePath("../FixtureLayout/NPCStands")
	set_meta("art_revision", "t0131_p2r3")
	set_meta("architectural_style", "medieval_border_chapel")
	set_meta("roof_pitch_degrees", NAVE_ROOF_PITCH_DEGREES)
	set_meta("formal_vertical_slice", true)
	set_meta("footprint_meters", BUILDING_FOOTPRINT)
	set_meta("maximum_level", MAXIMUM_LEVEL)
	set_meta("fixed_capacity", "chapel_altar_1_prayer_seat_10")
	_build_foundation_and_floor()
	_build_exterior()
	_build_roof()
	_build_level_one_details()
	_build_upgrade_visuals()
	additional_roof_fade_paths = [
		NodePath("UpgradeVisuals/Level2/RoofStructureAdditions"),
		NodePath("../FixtureLayout/Visuals/ChapelLevelTwoRoofTruss")
	]
	additional_exterior_fade_paths = [
		NodePath("UpgradeVisuals/Level2/ExteriorAdditions"),
		NodePath("../FixtureLayout/Visuals/ChapelLevelTwoBellRack"),
		NodePath("../FixtureLayout/Visuals/ChapelLevelTwoStainedWindow"),
		NodePath("../FixtureLayout/Visuals/ChapelLevelTwoWestButtress"),
		NodePath("../FixtureLayout/Visuals/ChapelLevelTwoEastButtress")
	]


func _build_foundation_and_floor() -> void:
	var interior := Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_add_box(interior, "StoneFoundation", Vector3(0.0, 0.11, 0.0), Vector3(11.9, 0.22, 11.9), Color("#66666a"))
	var floor := Node3D.new()
	floor.name = "Floor"
	interior.add_child(floor)
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		for z in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
			_add_scene_prop(floor, "DarkNaveFloor", FLOOR_DARK, Vector3(x, 0.13, z), Vector3(1.0, 0.2, 1.0))
	_add_box(interior, "SanctuaryStoneFloor", Vector3(0.0, 0.175, -4.45), Vector3(5.6, 0.07, 2.4), Color("#77777b"))


func _build_exterior() -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	var wall_shell := Node3D.new()
	wall_shell.name = "NaveWallShell"
	exterior.add_child(wall_shell)
	for x in [-5.0, -3.0, 3.0, 5.0]:
		_add_scene_prop(wall_shell, "FrontWall", WALL_STRAIGHT, Vector3(x, 0.2, 6.0), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
	for x in [-1.5, 1.5]:
		_add_scene_prop(wall_shell, "FrontWallNarrow", WALL_STRAIGHT, Vector3(x, 0.2, 6.0), Vector3(0.5, 1.0, 1.0), Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(wall_shell, "FrontDoorArch", WALL_DOOR, Vector3(0.0, 0.2, 6.0), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
	for x in [-5.0, -3.0, 3.0, 5.0]:
		_add_scene_prop(wall_shell, "RearWall", WALL_STRAIGHT, Vector3(x, 0.2, -6.0), Vector3.ONE)
	for side in [-1.0, 1.0]:
		for z in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
			_add_scene_prop(
				wall_shell,
				"SideWall",
				WALL_STRAIGHT,
				Vector3(side * 6.0, 0.2, z),
				Vector3.ONE,
				Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0)
			)
	var stone_base := Node3D.new()
	stone_base.name = "StonePlinthAndQuoins"
	exterior.add_child(stone_base)
	_add_box(stone_base, "FrontPlinth", Vector3(0.0, 0.48, 6.08), Vector3(12.25, 0.78, 0.38), WEATHERED_LIMESTONE)
	_add_box(stone_base, "RearPlinth", Vector3(0.0, 0.48, -6.08), Vector3(12.25, 0.78, 0.38), WEATHERED_LIMESTONE)
	_add_box(stone_base, "WestPlinth", Vector3(-6.08, 0.48, 0.0), Vector3(0.38, 0.78, 11.9), WEATHERED_LIMESTONE)
	_add_box(stone_base, "EastPlinth", Vector3(6.08, 0.48, 0.0), Vector3(0.38, 0.78, 11.9), WEATHERED_LIMESTONE)
	for x in [-5.88, 5.88]:
		_add_stone_quoin(stone_base, "FrontQuoin", Vector3(x, 0.0, 6.13))
		_add_stone_quoin(stone_base, "RearQuoin", Vector3(x, 0.0, -6.13))

	var front_gable := Node3D.new()
	front_gable.name = "FrontGableMasonry"
	exterior.add_child(front_gable)
	_add_stepped_gable(front_gable, 6.08, 1.0)
	var rear_gable := Node3D.new()
	rear_gable.name = "RearGableMasonry"
	exterior.add_child(rear_gable)
	_add_stepped_gable(rear_gable, -6.08, -1.0)

	var portal := Node3D.new()
	portal.name = "FrontPointedPortal"
	exterior.add_child(portal)
	_add_box(portal, "LeftPortalJamb", Vector3(-1.18, 1.68, 6.22), Vector3(0.28, 2.78, 0.34), PALE_LIMESTONE)
	_add_box(portal, "RightPortalJamb", Vector3(1.18, 1.68, 6.22), Vector3(0.28, 2.78, 0.34), PALE_LIMESTONE)
	var left_arch := _add_box(portal, "LeftPointedArch", Vector3(-0.58, 3.18, 6.22), Vector3(1.55, 0.27, 0.34), PALE_LIMESTONE)
	left_arch.rotation_degrees.z = 43.0
	var right_arch := _add_box(portal, "RightPointedArch", Vector3(0.58, 3.18, 6.22), Vector3(1.55, 0.27, 0.34), PALE_LIMESTONE)
	right_arch.rotation_degrees.z = -43.0
	_add_box(portal, "PortalKeystone", Vector3(0.0, 3.68, 6.23), Vector3(0.32, 0.42, 0.36), PALE_LIMESTONE)
	_add_oculus(exterior, "FrontOculus", Vector3(0.0, 4.86, 6.22), false)

	var lancets := Node3D.new()
	lancets.name = "SideLancetWindows"
	exterior.add_child(lancets)
	for side in [-1.0, 1.0]:
		for z in [-3.65, 0.0, 3.65]:
			_add_lancet_window(
				lancets,
				"WestLancet" if side < 0.0 else "EastLancet",
				Vector3(side * 6.19, 1.92, z),
				90.0 if side < 0.0 else -90.0,
				Color("#334b59")
			)
	for side in [-1.0, 1.0]:
		for z in [-4.15, 4.15]:
			_add_shallow_buttress(exterior, "NaveButtress", Vector3(side * 6.18, 0.0, z), side)

	var sanctuary := Node3D.new()
	sanctuary.name = "SanctuaryApse"
	exterior.add_child(sanctuary)
	_add_box(sanctuary, "ApseStoneBacking", Vector3(0.0, 1.85, -6.20), Vector3(4.2, 2.75, 0.28), WEATHERED_LIMESTONE)
	_add_lancet_window(sanctuary, "RearSanctuaryLancet", Vector3(0.0, 2.0, -6.37), 180.0, Color("#4b3041"))
	for x in [-2.05, 2.05]:
		_add_box(sanctuary, "ApsePier", Vector3(x, 1.5, -6.24), Vector3(0.32, 2.75, 0.4), PALE_LIMESTONE)

	_add_box(exterior, "FrontCrossStem", Vector3(0.0, 7.18, 6.2), Vector3(0.18, 1.24, 0.18), MUTED_GOLD)
	_add_box(exterior, "FrontCrossArm", Vector3(0.0, 7.37, 6.2), Vector3(0.84, 0.17, 0.18), MUTED_GOLD)
	var auto_door := Node3D.new()
	auto_door.name = "AutoDoor"
	auto_door.position = Vector3(0.0, 0.2, 6.2)
	auto_door.set_script(AUTO_DOOR_SCRIPT)
	auto_door.call("configure", CHAPEL_BURGUNDY, CHAPEL_WOOD, PALE_LIMESTONE)
	exterior.add_child(auto_door)


func _build_roof() -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.set_meta("roof_fade_candidate", true)
	add_child(roof)
	var left_slope := _add_box(roof, "WestNaveSlate", Vector3(-3.05, 4.89, 0.0), Vector3(7.25, 0.24, 12.9), CHAPEL_ROOF_SLATE)
	left_slope.rotation_degrees.z = NAVE_ROOF_PITCH_DEGREES
	var right_slope := _add_box(roof, "EastNaveSlate", Vector3(3.05, 4.89, 0.0), Vector3(7.25, 0.24, 12.9), CHAPEL_ROOF_SLATE)
	right_slope.rotation_degrees.z = -NAVE_ROOF_PITCH_DEGREES
	_add_box(roof, "NaveRidgeCap", Vector3(0.0, 6.78, 0.0), Vector3(0.38, 0.3, 13.1), CHAPEL_ROOF_EDGE)
	var slate_courses := Node3D.new()
	slate_courses.name = "SlateCourses"
	roof.add_child(slate_courses)
	for side in [-1.0, 1.0]:
		for course_index in range(5):
			var x: float = float(side) * (0.72 + float(course_index) * 1.23)
			var y: float = 6.72 - absf(x) * tan(deg_to_rad(NAVE_ROOF_PITCH_DEGREES))
			_add_box(slate_courses, "WestLongCourse" if side < 0.0 else "EastLongCourse", Vector3(x, y, 0.0), Vector3(0.09, 0.07, 12.96), CHAPEL_ROOF_EDGE)
	var transverse_joint_z_positions := [-5.25, -3.5, -1.75, 0.0, 1.75, 3.5, 5.25]
	for joint_index in range(transverse_joint_z_positions.size()):
		var z: float = transverse_joint_z_positions[joint_index]
		for side in [-1.0, 1.0]:
			var seam_name := "%s%02d" % ["WestSlateJoint" if side < 0.0 else "EastSlateJoint", joint_index + 1]
			var seam := _add_box(slate_courses, seam_name, Vector3(side * 3.1, 5.0, z), Vector3(6.95, 0.018, 0.035), CHAPEL_ROOF_JOINT)
			seam.rotation_degrees.z = -side * NAVE_ROOF_PITCH_DEGREES
	_add_box(roof, "WestEaveCap", Vector3(-6.2, 3.02, 0.0), Vector3(0.22, 0.24, 13.0), CHAPEL_ROOF_EDGE)
	_add_box(roof, "EastEaveCap", Vector3(6.2, 3.02, 0.0), Vector3(0.22, 0.24, 13.0), CHAPEL_ROOF_EDGE)
	var front_west_fascia := _add_box(roof, "FrontWestGableFascia", Vector3(-3.05, 4.9, 6.5), Vector3(7.3, 0.18, 0.18), CHAPEL_ROOF_EDGE)
	front_west_fascia.rotation_degrees.z = NAVE_ROOF_PITCH_DEGREES
	var front_east_fascia := _add_box(roof, "FrontEastGableFascia", Vector3(3.05, 4.9, 6.5), Vector3(7.3, 0.18, 0.18), CHAPEL_ROOF_EDGE)
	front_east_fascia.rotation_degrees.z = -NAVE_ROOF_PITCH_DEGREES


func _build_level_one_details() -> void:
	var interior := get_node("Interior") as Node3D
	var details := Node3D.new()
	details.name = "Level1Details"
	interior.add_child(details)
	# Quaternius banners use a high pivot; lift them so the cloth and tassels clear the floor.
	_add_scene_prop(details, "WestWallBanner", BANNER, Vector3(-5.7, 1.2, -2.65), Vector3.ONE * 0.72, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(details, "EastWallBanner", BANNER, Vector3(5.7, 1.2, -2.65), Vector3.ONE * 0.72, Vector3(0.0, -90.0, 0.0))
	_add_scene_prop(details, "WestVotiveCandles", CANDLESTICK, Vector3(-4.75, 0.2, -4.82), Vector3.ONE * 0.72)
	_add_scene_prop(details, "EastVotiveCandles", CANDLESTICK, Vector3(4.75, 0.2, -4.82), Vector3.ONE * 0.72)
	_add_scene_prop(details, "EntryLanternLeft", LANTERN, Vector3(-2.05, 1.65, 5.68), Vector3.ONE * 0.58, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(details, "EntryLanternRight", LANTERN, Vector3(2.05, 1.65, 5.68), Vector3.ONE * 0.58, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(details, "OfferingChest", CRATE, Vector3(5.05, 0.22, 5.0), Vector3.ONE * 0.5, Vector3(0.0, -12.0, 0.0))
	_add_box(details, "HolyWaterPedestal", Vector3(-5.08, 0.46, 5.05), Vector3(0.46, 0.82, 0.46), Color("#747279"))
	_add_cylinder(details, "HolyWaterBasin", Vector3(-5.08, 0.9, 5.05), 0.38, 0.18, Color("#949097"))
	_add_cylinder(details, "HolyWater", Vector3(-5.08, 1.0, 5.05), 0.29, 0.025, Color("#506d7b"))
	for z in [-0.95, 0.05, 1.05]:
		_add_box(details, "WallBookShelf", Vector3(5.66, 1.05, z), Vector3(0.28, 0.12, 0.78), Color("#4f382b"))
		_add_scene_prop(details, "PrayerBook", BOOK, Vector3(5.45, 1.15, z), Vector3.ONE * 0.6, Vector3(0.0, -90.0, 0.0))
	_add_scene_prop(details, "SacristyChalice", CHALICE, Vector3(-5.32, 1.12, -1.05), Vector3.ONE * 0.7)
	_add_box(details, "SacristyShelf", Vector3(-5.58, 1.02, -1.05), Vector3(0.38, 0.12, 1.0), Color("#50392d"))
	var altar_light := OmniLight3D.new()
	altar_light.name = "SanctuaryWarmLight"
	altar_light.position = Vector3(0.0, 2.25, -4.25)
	altar_light.light_color = Color("#ffd7a0")
	altar_light.light_energy = 1.45
	altar_light.omni_range = 7.0
	altar_light.shadow_enabled = true
	details.add_child(altar_light)


func _build_upgrade_visuals() -> void:
	var upgrades := Node3D.new()
	upgrades.name = "UpgradeVisuals"
	add_child(upgrades)
	var level_2 := Node3D.new()
	level_2.name = "Level2"
	level_2.visible = false
	upgrades.add_child(level_2)
	var exterior_additions := Node3D.new()
	exterior_additions.name = "ExteriorAdditions"
	level_2.add_child(exterior_additions)
	var bell_tower := Node3D.new()
	bell_tower.name = "WestBellTower"
	exterior_additions.add_child(bell_tower)
	_add_box(bell_tower, "TowerStoneBase", Vector3(-5.58, 1.55, -3.9), Vector3(1.22, 2.95, 1.48), WEATHERED_LIMESTONE)
	_add_box(bell_tower, "TowerBeltCourse", Vector3(-5.58, 3.04, -3.9), Vector3(1.42, 0.25, 1.68), PALE_LIMESTONE)
	for offset_x in [-0.5, 0.5]:
		for offset_z in [-0.6, 0.6]:
			_add_box(bell_tower, "BelfryPier", Vector3(-5.58 + offset_x, 4.35, -3.9 + offset_z), Vector3(0.24, 2.45, 0.24), PALE_LIMESTONE)
	_add_box(bell_tower, "BelfryFrontArchBeam", Vector3(-5.58, 5.48, -3.28), Vector3(1.25, 0.24, 0.25), PALE_LIMESTONE)
	_add_box(bell_tower, "BelfryRearArchBeam", Vector3(-5.58, 5.48, -4.52), Vector3(1.25, 0.24, 0.25), PALE_LIMESTONE)
	_add_box(bell_tower, "BelfryWestArchBeam", Vector3(-6.10, 5.48, -3.9), Vector3(0.25, 0.24, 1.0), PALE_LIMESTONE)
	_add_box(bell_tower, "BelfryEastArchBeam", Vector3(-5.06, 5.48, -3.9), Vector3(0.25, 0.24, 1.0), PALE_LIMESTONE)
	var buttress_caps := Node3D.new()
	buttress_caps.name = "ButtressCaps"
	exterior_additions.add_child(buttress_caps)
	for side in [-1.0, 1.0]:
		_add_box(buttress_caps, "CentralButtressCap", Vector3(side * 6.03, 1.75, 0.0), Vector3(0.52, 0.26, 3.18), PALE_LIMESTONE)
	var belt_courses := Node3D.new()
	belt_courses.name = "StoneBeltCourses"
	exterior_additions.add_child(belt_courses)
	for side in [-1.0, 1.0]:
		_add_box(belt_courses, "SideStoneBelt", Vector3(side * 6.21, 2.62, 0.0), Vector3(0.18, 0.18, 11.6), PALE_LIMESTONE)
	var sanctuary_tracery := Node3D.new()
	sanctuary_tracery.name = "SanctuaryWindowTracery"
	exterior_additions.add_child(sanctuary_tracery)
	_add_box(sanctuary_tracery, "WindowCrown", Vector3(0.0, 3.55, -6.32), Vector3(3.3, 0.22, 0.22), PALE_LIMESTONE)
	_add_box(sanctuary_tracery, "WindowMullion", Vector3(0.0, 2.2, -6.33), Vector3(0.16, 2.55, 0.2), PALE_LIMESTONE)
	var interior_additions := Node3D.new()
	interior_additions.name = "InteriorAdditions"
	level_2.add_child(interior_additions)
	_add_scene_prop(interior_additions, "ReliquaryChest", CRATE, Vector3(-4.95, 0.22, -3.45), Vector3.ONE * 0.48, Vector3(0.0, 8.0, 0.0))
	_add_scene_prop(interior_additions, "ProcessionalBook", BOOK, Vector3(4.85, 0.92, -3.65), Vector3.ONE * 0.72, Vector3(0.0, 18.0, 0.0))
	_add_scene_prop(interior_additions, "SanctuaryCandlesLeft", CANDLESTICK, Vector3(-3.75, 0.2, -5.15), Vector3.ONE * 0.62)
	_add_scene_prop(interior_additions, "SanctuaryCandlesRight", CANDLESTICK, Vector3(3.75, 0.2, -5.15), Vector3.ONE * 0.62)
	_add_box(interior_additions, "ReliquaryShelf", Vector3(-5.48, 0.82, -3.45), Vector3(0.35, 1.15, 1.15), Color("#60483a"))
	_add_scene_prop(interior_additions, "ProcessionalBannerLeft", BANNER, Vector3(-4.65, 1.25, -4.25), Vector3.ONE * 0.58, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(interior_additions, "ProcessionalBannerRight", BANNER, Vector3(4.65, 1.25, -4.25), Vector3.ONE * 0.58, Vector3(0.0, -90.0, 0.0))
	_add_box(interior_additions, "AltarStepUpper", Vector3(0.0, 0.24, -4.72), Vector3(4.4, 0.16, 1.55), Color("#8b847a"))
	var roof_structure := Node3D.new()
	roof_structure.name = "RoofStructureAdditions"
	level_2.add_child(roof_structure)
	var tower_roof := Node3D.new()
	tower_roof.name = "BellTowerRoof"
	roof_structure.add_child(tower_roof)
	var tower_west_slope := _add_box(tower_roof, "TowerWestSlate", Vector3(-5.88, 5.9, -3.9), Vector3(0.95, 0.17, 1.75), CHAPEL_ROOF_SLATE)
	tower_west_slope.rotation_degrees.z = 38.0
	var tower_east_slope := _add_box(tower_roof, "TowerEastSlate", Vector3(-5.28, 5.9, -3.9), Vector3(0.95, 0.17, 1.75), CHAPEL_ROOF_SLATE)
	tower_east_slope.rotation_degrees.z = -38.0
	_add_box(tower_roof, "TowerRidge", Vector3(-5.58, 6.2, -3.9), Vector3(0.18, 0.2, 1.82), CHAPEL_ROOF_EDGE)
	_add_box(tower_roof, "TowerCrossStem", Vector3(-5.58, 6.75, -3.9), Vector3(0.13, 0.9, 0.13), MUTED_GOLD)
	_add_box(tower_roof, "TowerCrossArm", Vector3(-5.58, 6.88, -3.9), Vector3(0.58, 0.13, 0.13), MUTED_GOLD)
	var roof_crest := Node3D.new()
	roof_crest.name = "RoofCrest"
	roof_structure.add_child(roof_crest)
	for z in [-4.8, -2.4, 0.0, 2.4, 4.8]:
		_add_cylinder(roof_crest, "RidgeFinial", Vector3(0.0, 7.02, z), 0.09, 0.48, MUTED_GOLD)
	_add_box(roof_structure, "SanctuaryCollarBeam", Vector3(0.0, 4.48, -3.8), Vector3(5.2, 0.18, 0.2), CHAPEL_WOOD)


func _add_stepped_gable(parent: Node3D, z_position: float, facing_sign: float) -> void:
	for course_index in range(7):
		var course_width := 11.35 - float(course_index) * 1.52
		_add_box(
			parent,
			"GableStoneCourse",
			Vector3(0.0, 3.34 + float(course_index) * 0.47, z_position + facing_sign * 0.02),
			Vector3(course_width, 0.5, 0.28),
			WEATHERED_LIMESTONE.lightened(0.025 * float(course_index % 2))
		)
	var west_fascia := _add_box(parent, "WestGableStoneFascia", Vector3(-3.02, 4.91, z_position + facing_sign * 0.18), Vector3(7.2, 0.2, 0.22), PALE_LIMESTONE)
	west_fascia.rotation_degrees.z = NAVE_ROOF_PITCH_DEGREES
	var east_fascia := _add_box(parent, "EastGableStoneFascia", Vector3(3.02, 4.91, z_position + facing_sign * 0.18), Vector3(7.2, 0.2, 0.22), PALE_LIMESTONE)
	east_fascia.rotation_degrees.z = -NAVE_ROOF_PITCH_DEGREES


func _add_stone_quoin(parent: Node3D, node_name: String, base_position: Vector3) -> void:
	var quoin := Node3D.new()
	quoin.name = node_name
	quoin.position = base_position
	parent.add_child(quoin)
	for course_index in range(5):
		var block_width := 0.56 if course_index % 2 == 0 else 0.42
		_add_box(
			quoin,
			"QuoinBlock",
			Vector3(0.0, 0.74 + float(course_index) * 0.56, 0.0),
			Vector3(block_width, 0.48, 0.48),
			PALE_LIMESTONE
		)


func _add_shallow_buttress(parent: Node3D, node_name: String, base_position: Vector3, side: float) -> void:
	var buttress := Node3D.new()
	buttress.name = node_name
	buttress.position = base_position
	parent.add_child(buttress)
	_add_box(buttress, "LowerStone", Vector3(side * 0.08, 0.78, 0.0), Vector3(0.48, 1.55, 0.86), WEATHERED_LIMESTONE)
	_add_box(buttress, "UpperStone", Vector3.ZERO + Vector3(side * -0.02, 1.78, 0.0), Vector3(0.34, 0.62, 0.66), PALE_LIMESTONE)
	_add_box(buttress, "WeatherCap", Vector3(side * 0.02, 2.12, 0.0), Vector3(0.46, 0.18, 0.78), PALE_LIMESTONE)


func _add_oculus(parent: Node3D, node_name: String, center: Vector3, rear_facing: bool) -> void:
	var oculus := Node3D.new()
	oculus.name = node_name
	oculus.position = center
	oculus.rotation_degrees.y = 180.0 if rear_facing else 0.0
	parent.add_child(oculus)
	var stone_disc := _add_cylinder(oculus, "OculusStoneRing", Vector3.ZERO, 0.79, 0.18, PALE_LIMESTONE)
	stone_disc.rotation_degrees.x = 90.0
	var pane := _add_cylinder(oculus, "OculusBlueGlass", Vector3(0.0, 0.0, 0.11), 0.61, 0.08, Color("#314b5d"))
	pane.rotation_degrees.x = 90.0
	_add_box(oculus, "OculusVerticalMullion", Vector3(0.0, 0.0, 0.17), Vector3(0.12, 1.18, 0.09), CHAPEL_WOOD)
	_add_box(oculus, "OculusHorizontalMullion", Vector3(0.0, 0.0, 0.17), Vector3(1.18, 0.12, 0.09), CHAPEL_WOOD)


func _add_lancet_window(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	y_rotation_degrees: float,
	pane_color: Color
) -> void:
	var lancet := Node3D.new()
	lancet.name = node_name
	lancet.position = center
	lancet.rotation_degrees.y = y_rotation_degrees
	parent.add_child(lancet)
	_add_box(lancet, "LancetLowerPane", Vector3(0.0, -0.17, 0.0), Vector3(0.68, 1.24, 0.1), pane_color)
	var crown_pane := _add_box(lancet, "LancetCrownPane", Vector3(0.0, 0.53, 0.0), Vector3(0.48, 0.48, 0.1), pane_color.darkened(0.08))
	crown_pane.rotation_degrees.z = 45.0
	_add_box(lancet, "LeftLancetJamb", Vector3(-0.43, -0.12, 0.02), Vector3(0.16, 1.52, 0.18), PALE_LIMESTONE)
	_add_box(lancet, "RightLancetJamb", Vector3(0.43, -0.12, 0.02), Vector3(0.16, 1.52, 0.18), PALE_LIMESTONE)
	var left_crown := _add_box(lancet, "LeftLancetCrown", Vector3(-0.23, 0.72, 0.02), Vector3(0.72, 0.15, 0.18), PALE_LIMESTONE)
	left_crown.rotation_degrees.z = 48.0
	var right_crown := _add_box(lancet, "RightLancetCrown", Vector3(0.23, 0.72, 0.02), Vector3(0.72, 0.15, 0.18), PALE_LIMESTONE)
	right_crown.rotation_degrees.z = -48.0
	_add_box(lancet, "LancetSill", Vector3(0.0, -0.91, 0.02), Vector3(1.02, 0.16, 0.22), WEATHERED_LIMESTONE)


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


func _formal_navigation_ready() -> bool:
	var controller := get_node_or_null("/root/Main/Presentation/StationLayoutController")
	if controller == null or not controller.has_method("get_validation_snapshot"):
		return false
	var snapshot: Dictionary = controller.call("get_validation_snapshot")
	var navigation := snapshot.get("production_navigation", {}) as Dictionary
	return bool(navigation.get("available", false)) and bool(navigation.get("enabled", false))


func _count_workstation_prefix(states: Dictionary, prefix: String) -> int:
	var count := 0
	for workstation_id in states:
		if str(workstation_id).begins_with(prefix):
			count += 1
	return count


func _mesh_count_at(path: String) -> int:
	return _count_authored_meshes_at(NodePath(path))


func _add_scene_prop(
	parent: Node3D,
	node_name: String,
	asset_path: String,
	position: Vector3,
	scale: Vector3 = Vector3.ONE,
	rotation_degrees: Vector3 = Vector3.ZERO
) -> Node3D:
	var packed := load(asset_path) as PackedScene
	if packed == null:
		return null
	var prop := packed.instantiate() as Node3D
	if prop == null:
		return null
	prop.name = node_name
	prop.position = position
	prop.scale = scale
	prop.rotation_degrees = rotation_degrees
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


func _add_cylinder(parent: Node3D, node_name: String, center: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
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
