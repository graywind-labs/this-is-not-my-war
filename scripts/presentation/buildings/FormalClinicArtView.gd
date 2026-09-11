class_name FormalClinicArtView
extends BuildingArtView


const WALL_STRAIGHT := "res://assets/3d/quaternius/buildings/wall_plaster_straight.glb"
const WALL_DOOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round.glb"
const FLOOR_DARK := "res://assets/3d/quaternius/buildings/floor_wood_dark.glb"
const WORKSHOP_SHELF := "res://assets/3d/quaternius/props/workshop_shelf.glb"
const CRATE := "res://assets/3d/quaternius/props/crate_wooden.glb"
const BARREL := "res://assets/3d/quaternius/props/barrel.glb"
const BUCKET := "res://assets/3d/quaternius/props/bucket_wooden.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const BOOK := "res://assets/3d/quaternius/props/chapel_book.glb"
const AUTO_DOOR_SCRIPT := preload("res://scripts/presentation/buildings/BuildingAutoDoor.gd")
const WASH_BASIN_BUILDER := preload("res://scripts/presentation/buildings/MedievalWashBasinBuilder.gd")

const BUILDING_FOOTPRINT := Vector2(12.0, 12.0)
const INTERIOR_CLEAR_SIZE := Vector2(11.1, 11.1)
const MAXIMUM_LEVEL := 3

const CLINIC_WALL := Color("#c8c2af")
const CLINIC_STONE := Color("#858a80")
const CLINIC_TIMBER := Color("#4b6259")
const CLINIC_TEAL := Color("#71988e")
const CLINIC_ROOF := Color("#728f87")
const CLINIC_ROOF_EDGE := Color("#48635d")
const CLINIC_LINEN := Color("#eee1c4")
const CLINIC_MEDICINE := Color("#87aa79")
const CLINIC_GLASS := Color("#91bbb1")
const CLINIC_FLOWER := Color("#d59b73")
const CLINIC_GOLD := Color("#d2b574")

var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_formal_clinic()
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
			var required_level := int(marker.get_meta("required_level", 1))
			workstation_states[workstation_id] = {
				"required_level": required_level,
				"available": required_level <= _building_level,
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
		"doctor_desk_count": _count_workstation_prefix(workstation_states, "doctor_desk_"),
		"treatment_bed_count": _count_workstation_prefix(workstation_states, "treatment_bed_"),
		"available_treatment_bed_count": _count_available_prefix(workstation_states, "treatment_bed_"),
		"active_fixture_visual_count": _active_fixture_visual_count(),
		"active_fixture_collision_count": _active_fixture_collision_count(),
		"level_visual_addition_counts": {
			"level_1": _mesh_count_at("Interior/Level1Details") + _mesh_count_at("Exterior") + _mesh_count_at("Roof"),
			"level_2": _mesh_count_at("UpgradeVisuals/Level2"),
			"level_3": _mesh_count_at("UpgradeVisuals/Level3")
		},
		"building_footprint": BUILDING_FOOTPRINT,
		"interior_clear_size": INTERIOR_CLEAR_SIZE,
		"future_capacity_reserved": true,
		"architectural_style": "medieval_border_healing_infirmary_and_herb_house",
		"facade_profile": "warm_ivory_plaster_sage_shutters_healing_canopy_and_herb_garden",
		"roof_profile": "broad_four_slope_sage_hip_roof_with_daylight_lantern",
		"healing_visual_language": "warm_linen_daylight_herbs_and_soft_sage",
		"silhouette_distinct_from_workshop": true,
		"level_two_upgrade_profile": "third_bed_privacy_bay_medicine_cabinet_and_west_roof_vent",
		"level_three_upgrade_profile": "fourth_bed_sterilization_corner_dispensing_hatch_and_east_roof_vent",
		"palette": {
			"wall": CLINIC_WALL.to_html(false),
			"timber": CLINIC_TIMBER.to_html(false),
			"roof": CLINIC_ROOF.to_html(false),
			"linen": CLINIC_LINEN.to_html(false),
			"medicine": CLINIC_MEDICINE.to_html(false)
		},
		"auto_door": door_snapshot,
		"roof_mesh_count": _roof_meshes.size(),
		"roof_structure_additions_fade_with_roof": additional_roof_fade_paths.size() == 2,
		"exterior_material_count": _exterior_materials.size(),
		"interior_revealed_for_selection": is_interior_revealed_for_selection(),
		"shell_opacity": maxf(_roof_opacity, _exterior_opacity),
		"navigation_ready": _formal_navigation_ready(),
		"collision_authority": "formal_station_static_and_level_synced_fixture_collision",
		"navigation_authority": "formal_station_navigation_mesh",
		"authority_role": "presentation_only"
	}


func _build_formal_clinic() -> void:
	building_id = "clinic"
	roof_near_distance = 58.0
	roof_far_distance = 70.0
	minimum_roof_opacity = 0.06
	fade_exterior_with_roof = true
	minimum_exterior_opacity = 0.06
	interior_reveal_opacity_threshold = 0.72
	interaction_bounds_center = Vector3(0.0, 2.8, 0.0)
	interaction_bounds_size = Vector3(14.5, 6.4, 14.5)
	roof_albedo_override = CLINIC_ROOF
	preserve_roof_albedo_texture = false
	exterior_albedo_tint = CLINIC_WALL
	static_collision_path = NodePath("../StaticCollision")
	workstation_markers_path = NodePath("../FixtureLayout/NPCStands")
	set_meta("art_revision", "t0135_p8ar5")
	set_meta("architectural_style", "medieval_border_healing_infirmary_and_herb_house")
	set_meta("formal_vertical_slice", true)
	set_meta("footprint_meters", BUILDING_FOOTPRINT)
	set_meta("maximum_level", MAXIMUM_LEVEL)
	set_meta("fixed_doctor_desk_capacity", 2)
	set_meta("bed_capacity_by_level", [2, 3, 4])
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
	_add_box(interior, "StoneFoundation", Vector3(0.0, 0.11, 0.0), Vector3(11.9, 0.22, 11.9), CLINIC_STONE.darkened(0.22))
	var floor := Node3D.new()
	floor.name = "Floor"
	interior.add_child(floor)
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		for z in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
			_add_scene_prop(floor, "CleanDarkWoodFloor", FLOOR_DARK, Vector3(x, 0.14, z), Vector3(1.0, 0.2, 1.0))
	_add_box(interior, "CentralCleanRunner", Vector3(0.0, 0.19, 0.8), Vector3(1.55, 0.035, 9.6), Color("#ab9d80"))


func _build_exterior() -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	var wall_shell := Node3D.new()
	wall_shell.name = "PlasterWallShell"
	exterior.add_child(wall_shell)
	for x in [-5.0, -3.0, 3.0, 5.0]:
		_add_scene_prop(wall_shell, "FrontWall", WALL_STRAIGHT, Vector3(x, 0.2, 6.0), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
	for x in [-1.5, 1.5]:
		_add_scene_prop(wall_shell, "FrontWallNarrow", WALL_STRAIGHT, Vector3(x, 0.2, 6.0), Vector3(0.5, 1.0, 1.0), Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(wall_shell, "FrontDoorArch", WALL_DOOR, Vector3(0.0, 0.2, 6.0), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		_add_scene_prop(wall_shell, "RearWall", WALL_STRAIGHT, Vector3(x, 0.2, -6.0), Vector3.ONE)
	for side in [-1.0, 1.0]:
		for z in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
			_add_scene_prop(wall_shell, "SideWall", WALL_STRAIGHT, Vector3(side * 6.0, 0.2, z), Vector3.ONE, Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0))

	var timber := Node3D.new()
	timber.name = "SageHalfTimberAndTrim"
	exterior.add_child(timber)
	_add_box(timber, "FrontPlinth", Vector3(0.0, 0.42, 6.1), Vector3(12.2, 0.62, 0.32), CLINIC_STONE)
	_add_box(timber, "RearPlinth", Vector3(0.0, 0.42, -6.1), Vector3(12.2, 0.62, 0.32), CLINIC_STONE)
	for x in [-5.88, -3.0, 3.0, 5.88]:
		_add_box(timber, "FrontPost", Vector3(x, 1.75, 6.14), Vector3(0.24, 3.25, 0.26), CLINIC_TIMBER)
		_add_box(timber, "RearPost", Vector3(x, 1.75, -6.14), Vector3(0.24, 3.25, 0.26), CLINIC_TIMBER)
	for x in [-1.16, 1.16]:
		_add_box(timber, "DoorJamb", Vector3(x, 1.7, 6.15), Vector3(0.22, 3.15, 0.27), CLINIC_TIMBER)
	for side in [-1.0, 1.0]:
		for z in [-4.6, 0.0, 4.6]:
			_add_box(timber, "SidePost", Vector3(side * 6.14, 1.75, z), Vector3(0.27, 3.25, 0.24), CLINIC_TIMBER)
	_add_box(timber, "FrontLintel", Vector3(0.0, 3.22, 6.13), Vector3(12.2, 0.28, 0.28), CLINIC_TIMBER)
	_add_box(timber, "RearLintel", Vector3(0.0, 3.22, -6.13), Vector3(12.2, 0.28, 0.28), CLINIC_TIMBER)

	var windows := Node3D.new()
	windows.name = "HighLightWindows"
	exterior.add_child(windows)
	for x in [-4.1, 4.1]:
		_add_window(windows, Vector3(x, 2.0, 6.18), Vector3.ZERO)
		_add_window(windows, Vector3(x, 2.0, -6.18), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		for z in [-3.0, 1.0, 4.25]:
			_add_window(windows, Vector3(side * 6.18, 2.0, z), Vector3(0.0, 90.0, 0.0))

	var sign := Node3D.new()
	sign.name = "HerbalMortarSign"
	sign.position = Vector3(0.0, 3.82, 6.31)
	exterior.add_child(sign)
	_add_cylinder(sign, "HealerLeafEmblem", Vector3.ZERO, 0.68, 0.14, CLINIC_LINEN, Vector3(90.0, 0.0, 0.0))
	_add_cylinder(sign, "MortarBowl", Vector3(0.0, -0.08, 0.13), 0.27, 0.15, CLINIC_GOLD, Vector3(90.0, 0.0, 0.0))
	var pestle := _add_box(sign, "Pestle", Vector3(0.2, 0.14, 0.16), Vector3(0.1, 0.62, 0.1), CLINIC_GOLD.lightened(0.1))
	pestle.rotation_degrees.z = -38.0
	var leaf_left := _add_sphere(sign, "HealingLeafLeft", Vector3(-0.35, 0.26, 0.15), 0.18, CLINIC_MEDICINE)
	leaf_left.scale = Vector3(1.45, 0.65, 0.42)
	leaf_left.rotation_degrees.z = -28.0
	var leaf_right := _add_sphere(sign, "HealingLeafRight", Vector3(0.35, 0.26, 0.15), 0.18, CLINIC_MEDICINE.lightened(0.08))
	leaf_right.scale = Vector3(1.45, 0.65, 0.42)
	leaf_right.rotation_degrees.z = 28.0

	var canopy := Node3D.new()
	canopy.name = "HealingEntranceCanopy"
	exterior.add_child(canopy)
	var canopy_cloth := _add_box(canopy, "CreamLinenCanopy", Vector3(0.0, 3.02, 6.55), Vector3(3.8, 0.12, 0.72), CLINIC_LINEN)
	canopy_cloth.rotation_degrees.x = -6.0
	for x in [-1.72, 1.72]:
		_add_box(canopy, "SageCanopyPost", Vector3(x, 1.55, 6.72), Vector3(0.13, 2.75, 0.13), CLINIC_TIMBER)
	for x in [-1.5, -0.75, 0.0, 0.75, 1.5]:
		_add_sphere(canopy, "LinenScallop", Vector3(x, 2.91, 6.83), 0.11, CLINIC_LINEN.darkened(0.04))

	var garden := Node3D.new()
	garden.name = "HerbalWelcomeGarden"
	exterior.add_child(garden)
	_add_healing_planter(garden, "WestHerbPlanter", Vector3(-4.18, 0.48, 6.55), -1.0)
	_add_healing_planter(garden, "EastHerbPlanter", Vector3(4.18, 0.48, 6.55), 1.0)

	var auto_door := Node3D.new()
	auto_door.name = "AutoDoor"
	auto_door.position = Vector3(0.0, 0.2, 6.2)
	auto_door.set_script(AUTO_DOOR_SCRIPT)
	auto_door.call("configure", CLINIC_TEAL, CLINIC_TIMBER, Color("#899696"))
	exterior.add_child(auto_door)


func _build_roof() -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.set_meta("roof_fade_candidate", true)
	add_child(roof)
	var hip_roof := Node3D.new()
	hip_roof.name = "HealingHipRoof"
	roof.add_child(hip_roof)
	var eave_y := 3.18
	var crown_y := 4.96
	var eave := 6.76
	var ridge_half := 2.05
	_add_roof_panel(hip_roof, "FrontSlope", PackedVector3Array([
		Vector3(-eave, eave_y, eave), Vector3(eave, eave_y, eave),
		Vector3(ridge_half, crown_y, 0.0), Vector3(-ridge_half, crown_y, 0.0)
	]), CLINIC_ROOF)
	_add_roof_panel(hip_roof, "RearSlope", PackedVector3Array([
		Vector3(eave, eave_y, -eave), Vector3(-eave, eave_y, -eave),
		Vector3(-ridge_half, crown_y, 0.0), Vector3(ridge_half, crown_y, 0.0)
	]), CLINIC_ROOF.darkened(0.035))
	_add_roof_panel(hip_roof, "WestSlope", PackedVector3Array([
		Vector3(-eave, eave_y, -eave), Vector3(-eave, eave_y, eave),
		Vector3(-ridge_half, crown_y, 0.0)
	]), CLINIC_ROOF.lightened(0.025))
	_add_roof_panel(hip_roof, "EastSlope", PackedVector3Array([
		Vector3(eave, eave_y, eave), Vector3(eave, eave_y, -eave),
		Vector3(ridge_half, crown_y, 0.0)
	]), CLINIC_ROOF.darkened(0.065))
	_add_box(hip_roof, "FrontCreamFascia", Vector3(0.0, eave_y, eave), Vector3(13.6, 0.16, 0.16), CLINIC_LINEN.darkened(0.12))
	_add_box(hip_roof, "RearCreamFascia", Vector3(0.0, eave_y, -eave), Vector3(13.6, 0.16, 0.16), CLINIC_LINEN.darkened(0.16))
	_add_box(hip_roof, "WestCreamFascia", Vector3(-eave, eave_y, 0.0), Vector3(0.16, 0.16, 13.6), CLINIC_LINEN.darkened(0.12))
	_add_box(hip_roof, "EastCreamFascia", Vector3(eave, eave_y, 0.0), Vector3(0.16, 0.16, 13.6), CLINIC_LINEN.darkened(0.16))
	_add_box(hip_roof, "ShortRidgeCap", Vector3(0.0, crown_y + 0.04, 0.0), Vector3(4.35, 0.14, 0.18), CLINIC_ROOF_EDGE)

	var lantern := Node3D.new()
	lantern.name = "HealingLightLantern"
	roof.add_child(lantern)
	_add_box(lantern, "IvoryLanternBase", Vector3(0.0, 5.02, 0.0), Vector3(3.0, 0.22, 1.9), CLINIC_WALL)
	_add_box(lantern, "NorthDaylightGlass", Vector3(0.0, 5.42, -0.88), Vector3(2.55, 0.68, 0.08), CLINIC_GLASS)
	_add_box(lantern, "SouthDaylightGlass", Vector3(0.0, 5.42, 0.88), Vector3(2.55, 0.68, 0.08), CLINIC_GLASS.lightened(0.06))
	_add_box(lantern, "WestDaylightGlass", Vector3(-1.43, 5.42, 0.0), Vector3(0.08, 0.68, 1.55), CLINIC_GLASS)
	_add_box(lantern, "EastDaylightGlass", Vector3(1.43, 5.42, 0.0), Vector3(0.08, 0.68, 1.55), CLINIC_GLASS.darkened(0.04))
	for x in [-1.42, 1.42]:
		for z in [-0.87, 0.87]:
			_add_box(lantern, "SageLanternPost", Vector3(x, 5.42, z), Vector3(0.12, 0.84, 0.12), CLINIC_TIMBER)
	_add_box(lantern, "BroadLanternCap", Vector3(0.0, 5.84, 0.0), Vector3(3.42, 0.16, 2.3), CLINIC_ROOF_EDGE)
	_add_sphere(lantern, "HealingLeafFinial", Vector3(0.0, 6.02, 0.0), 0.18, CLINIC_GOLD)


func _build_level_one_details() -> void:
	var interior := get_node("Interior") as Node3D
	var details := Node3D.new()
	details.name = "Level1Details"
	interior.add_child(details)
	_add_scene_prop(details, "FrontLanternLeft", LANTERN, Vector3(-2.1, 2.45, 5.62), Vector3.ONE * 0.7, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(details, "FrontLanternRight", LANTERN, Vector3(2.1, 2.45, 5.62), Vector3.ONE * 0.7, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(details, "WestMedicineShelf", WORKSHOP_SHELF, Vector3(-5.45, 0.18, -2.8), Vector3.ONE * 0.68, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(details, "EastLinenShelf", WORKSHOP_SHELF, Vector3(5.45, 0.18, -2.8), Vector3.ONE * 0.68, Vector3(0.0, -90.0, 0.0))
	_add_scene_prop(details, "BandageCrate", CRATE, Vector3(5.05, 0.18, 4.72), Vector3.ONE * 0.55, Vector3(0.0, -12.0, 0.0))
	_add_scene_prop(details, "CleanWaterBarrel", BARREL, Vector3(-5.08, 0.18, 4.45), Vector3.ONE * 0.62)
	_add_scene_prop(details, "WashBucket", BUCKET, Vector3(-4.35, 0.18, 4.85), Vector3.ONE * 0.72)
	var wash_basin: Node3D = WASH_BASIN_BUILDER.build_wash_basin("ClinicWashBasin", Vector3(0.0, 0.0, -5.42), 0.0, {
		"timber": CLINIC_TIMBER,
		"dark_timber": CLINIC_TEAL.darkened(0.2),
		"stone": CLINIC_STONE.lightened(0.08),
		"basin": CLINIC_LINEN,
		"metal": CLINIC_GOLD.darkened(0.12),
		"water": CLINIC_GLASS.darkened(0.02),
		"linen": CLINIC_LINEN.lightened(0.05)
	})
	details.add_child(wash_basin)
	_add_scene_prop(details, "MedicalReferenceBook", BOOK, Vector3(5.05, 1.2, -4.75), Vector3.ONE * 0.7, Vector3(0.0, -20.0, 0.0))
	_add_apothecary_bottles(details, Vector3(-5.2, 1.15, -1.6), 4)
	_add_apothecary_bottles(details, Vector3(5.2, 1.15, -1.6), 3)
	_add_privacy_frame(details, "BedOnePrivacyScreen", Vector3(-5.15, 0.0, 3.2), CLINIC_LINEN)
	_add_privacy_frame(details, "BedTwoPrivacyScreen", Vector3(5.15, 0.0, 3.2), CLINIC_LINEN)
	var herb_rack := Node3D.new()
	herb_rack.name = "DryingHerbRack"
	herb_rack.position = Vector3(-5.68, 1.8, 0.45)
	herb_rack.rotation_degrees.y = 90.0
	details.add_child(herb_rack)
	_add_box(herb_rack, "RackBar", Vector3.ZERO, Vector3(2.3, 0.12, 0.1), CLINIC_TIMBER)
	for index in range(5):
		var offset := -0.85 + float(index) * 0.42
		_add_box(herb_rack, "HerbCord", Vector3(offset, -0.36, 0.0), Vector3(0.04, 0.65, 0.04), Color("#6e5c42"))
		_add_sphere(herb_rack, "HerbBundle", Vector3(offset, -0.72, 0.0), 0.16, CLINIC_MEDICINE.darkened(float(index % 2) * 0.12))


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
	_add_privacy_frame(level_2_interior, "ThirdBedPrivacyScreen", Vector3(-5.15, 0.0, -0.2), Color("#c5bda5"))
	_add_scene_prop(level_2_interior, "ExpandedMedicineCabinet", WORKSHOP_SHELF, Vector3(-5.42, 0.18, 1.55), Vector3.ONE * 0.7, Vector3(0.0, 90.0, 0.0))
	_add_apothecary_bottles(level_2_interior, Vector3(-5.15, 1.45, 1.15), 5)
	_add_scene_prop(level_2_interior, "FreshLinenChest", CRATE, Vector3(-5.0, 0.18, 5.0), Vector3.ONE * 0.52, Vector3(0.0, 15.0, 0.0))
	var level_2_exterior := Node3D.new()
	level_2_exterior.name = "ExteriorAdditions"
	level_2.add_child(level_2_exterior)
	_add_box(level_2_exterior, "WestHerbDryingAwning", Vector3(-6.45, 2.35, -1.3), Vector3(0.65, 0.15, 3.2), CLINIC_TEAL.darkened(0.1))
	_add_box(level_2_exterior, "WestAwningPostFront", Vector3(-6.65, 1.2, 0.15), Vector3(0.16, 2.2, 0.16), CLINIC_TIMBER)
	_add_box(level_2_exterior, "WestAwningPostRear", Vector3(-6.65, 1.2, -2.75), Vector3(0.16, 2.2, 0.16), CLINIC_TIMBER)
	var level_2_roof := Node3D.new()
	level_2_roof.name = "RoofStructureAdditions"
	level_2.add_child(level_2_roof)
	_add_roof_vent(level_2_roof, "WestWardVent", Vector3(-3.15, 4.35, 1.45))

	var level_3 := Node3D.new()
	level_3.name = "Level3"
	level_3.visible = false
	upgrades.add_child(level_3)
	var level_3_interior := Node3D.new()
	level_3_interior.name = "InteriorAdditions"
	level_3.add_child(level_3_interior)
	_add_privacy_frame(level_3_interior, "FourthBedPrivacyScreen", Vector3(5.15, 0.0, -0.2), Color("#c5bda5"))
	_add_box(level_3_interior, "SterilizationCounter", Vector3(5.25, 0.68, 1.45), Vector3(0.8, 1.1, 2.15), Color("#635448"))
	_add_scene_prop(level_3_interior, "SterilizationBasin", BUCKET, Vector3(5.18, 1.2, 1.45), Vector3.ONE * 0.62, Vector3(0.0, 0.0, 90.0))
	_add_box(level_3_interior, "InstrumentTray", Vector3(4.8, 1.3, 1.45), Vector3(0.52, 0.05, 1.35), Color("#899394"))
	_add_box(level_3_interior, "FoldedCleanLinen", Vector3(5.18, 1.34, 2.05), Vector3(0.42, 0.16, 0.5), CLINIC_LINEN)
	for index in range(4):
		_add_box(level_3_interior, "CleanInstrument", Vector3(4.75, 1.36, 0.95 + float(index) * 0.32), Vector3(0.05, 0.05, 0.24), Color("#b6bdbc"))
	var level_3_exterior := Node3D.new()
	level_3_exterior.name = "ExteriorAdditions"
	level_3.add_child(level_3_exterior)
	_add_box(level_3_exterior, "DispensingHatchFrame", Vector3(4.1, 2.0, 6.31), Vector3(2.0, 1.45, 0.18), CLINIC_TEAL)
	_add_box(level_3_exterior, "DispensingHatchGlass", Vector3(4.1, 2.0, 6.42), Vector3(1.55, 1.05, 0.05), CLINIC_GLASS)
	_add_box(level_3_exterior, "SeniorHealerPlaque", Vector3(3.7, 3.65, 6.29), Vector3(2.2, 0.48, 0.14), Color("#6c8065"))
	var level_3_roof := Node3D.new()
	level_3_roof.name = "RoofStructureAdditions"
	level_3.add_child(level_3_roof)
	_add_roof_vent(level_3_roof, "EastWardVent", Vector3(3.15, 4.35, 1.45))


func _add_window(parent: Node3D, center: Vector3, rotation_value: Vector3) -> void:
	var window := Node3D.new()
	window.name = "ClinicWindow"
	window.position = center
	window.rotation_degrees = rotation_value
	parent.add_child(window)
	_add_box(window, "StoneSurround", Vector3.ZERO, Vector3(1.55, 1.55, 0.13), CLINIC_STONE)
	_add_box(window, "BlueGreenGlass", Vector3(0.0, 0.0, 0.09), Vector3(1.16, 1.16, 0.04), CLINIC_GLASS)
	_add_box(window, "VerticalMullion", Vector3(0.0, 0.0, 0.13), Vector3(0.08, 1.18, 0.06), CLINIC_TIMBER)
	_add_box(window, "HorizontalMullion", Vector3(0.0, 0.0, 0.13), Vector3(1.18, 0.08, 0.06), CLINIC_TIMBER)
	var left_shutter := _add_box(window, "SageShutterLeft", Vector3(-1.0, 0.0, 0.16), Vector3(0.34, 1.42, 0.08), CLINIC_TEAL)
	left_shutter.rotation_degrees.y = -8.0
	var right_shutter := _add_box(window, "SageShutterRight", Vector3(1.0, 0.0, 0.16), Vector3(0.34, 1.42, 0.08), CLINIC_TEAL)
	right_shutter.rotation_degrees.y = 8.0
	_add_box(window, "WarmStoneSill", Vector3(0.0, -0.87, 0.18), Vector3(1.72, 0.16, 0.22), CLINIC_LINEN.darkened(0.18))


func _add_healing_planter(parent: Node3D, node_name: String, center: Vector3, direction: float) -> void:
	var planter := Node3D.new()
	planter.name = node_name
	planter.position = center
	parent.add_child(planter)
	_add_box(planter, "WarmStoneTrough", Vector3.ZERO, Vector3(2.15, 0.5, 0.58), CLINIC_STONE.lightened(0.12))
	_add_box(planter, "DarkSoil", Vector3(0.0, 0.29, 0.0), Vector3(1.86, 0.08, 0.4), Color("#4f4737"))
	for index in range(5):
		var x_offset := -0.78 + float(index) * 0.39
		var stem_height := 0.34 + float(index % 2) * 0.12
		_add_cylinder(planter, "HerbStem", Vector3(x_offset, 0.48 + stem_height * 0.5, 0.0), 0.025, stem_height, CLINIC_MEDICINE.darkened(0.2))
		var herb_color := CLINIC_MEDICINE.lightened(float(index % 3) * 0.045)
		var herb := _add_sphere(planter, "HerbCluster", Vector3(x_offset, 0.52 + stem_height, 0.0), 0.16, herb_color)
		herb.scale = Vector3(1.15, 0.78, 0.9)
		if index == 1 or index == 3:
			_add_sphere(planter, "SoftFlower", Vector3(x_offset + 0.04 * direction, 0.69 + stem_height, 0.02), 0.075, CLINIC_FLOWER.lightened(float(index - 1) * 0.035))


func _add_roof_panel(parent: Node3D, node_name: String, points: PackedVector3Array, color: Color) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.set_material(_material(color))
	_add_roof_triangle(surface_tool, points[0], points[1], points[2])
	if points.size() == 4:
		_add_roof_triangle(surface_tool, points[0], points[2], points[3])
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface_tool.commit()
	parent.add_child(instance)
	return instance


func _add_roof_triangle(surface_tool: SurfaceTool, first: Vector3, second: Vector3, third: Vector3) -> void:
	var normal := (second - first).cross(third - first).normalized()
	if normal.y < 0.0:
		var swap := second
		second = third
		third = swap
		normal = (second - first).cross(third - first).normalized()
	# Godot treats clockwise winding as the front face. Keep the lighting normal
	# pointing upward while emitting the triangle in the engine's front-face order.
	for vertex in [first, third, second]:
		surface_tool.set_normal(normal)
		surface_tool.add_vertex(vertex)


func _add_privacy_frame(parent: Node3D, node_name: String, center: Vector3, linen_color: Color) -> void:
	var frame := Node3D.new()
	frame.name = node_name
	frame.position = center
	parent.add_child(frame)
	_add_box(frame, "HeadPost", Vector3(0.0, 1.15, -1.18), Vector3(0.1, 2.2, 0.1), CLINIC_TIMBER)
	_add_box(frame, "FootPost", Vector3(0.0, 1.15, 1.18), Vector3(0.1, 2.2, 0.1), CLINIC_TIMBER)
	_add_box(frame, "CurtainRail", Vector3(0.0, 2.2, 0.0), Vector3(0.1, 0.1, 2.45), CLINIC_TIMBER)
	_add_box(frame, "PrivacyLinen", Vector3(0.0, 1.45, 0.0), Vector3(0.045, 1.35, 2.15), linen_color)


func _add_apothecary_bottles(parent: Node3D, center: Vector3, count: int) -> void:
	var rack := Node3D.new()
	rack.name = "ApothecaryBottles"
	rack.position = center
	parent.add_child(rack)
	for index in range(count):
		var color: Color = [Color("#6f8d6d"), Color("#8c6e52"), Color("#6d798f"), Color("#9b8356")][index % 4]
		_add_cylinder(rack, "MedicineBottle", Vector3(0.0, 0.0, -0.55 + float(index) * 0.3), 0.1, 0.3, color)
		_add_cylinder(rack, "BottleStopper", Vector3(0.0, 0.19, -0.55 + float(index) * 0.3), 0.055, 0.08, Color("#4d3b31"))


func _add_roof_vent(parent: Node3D, node_name: String, center: Vector3) -> void:
	var vent := Node3D.new()
	vent.name = node_name
	vent.position = center
	parent.add_child(vent)
	_add_box(vent, "VentCurb", Vector3.ZERO, Vector3(1.45, 0.65, 1.2), CLINIC_TIMBER)
	_add_box(vent, "VentSlats", Vector3(0.0, 0.05, 0.63), Vector3(1.0, 0.36, 0.05), CLINIC_GLASS.darkened(0.2))
	_add_box(vent, "VentCap", Vector3(0.0, 0.42, 0.0), Vector3(1.75, 0.14, 1.5), CLINIC_ROOF_EDGE)


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
	material.roughness = 0.88
	_material_cache[key] = material
	return material
