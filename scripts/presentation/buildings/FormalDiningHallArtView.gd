class_name FormalDiningHallArtView
extends BuildingArtView


const WALL_STRAIGHT := "res://assets/3d/quaternius/buildings/wall_plaster_straight.glb"
const WALL_DOOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round.glb"
const FLOOR_DARK := "res://assets/3d/quaternius/buildings/floor_wood_dark.glb"
const SHELF := "res://assets/3d/quaternius/props/workshop_shelf.glb"
const CRATE := "res://assets/3d/quaternius/props/crate_wooden.glb"
const BARREL := "res://assets/3d/quaternius/props/barrel.glb"
const BAG := "res://assets/3d/quaternius/props/warehouse_bag.glb"
const BUCKET := "res://assets/3d/quaternius/props/bucket_wooden.glb"
const MUG := "res://assets/3d/quaternius/props/tavern_mug.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const AUTO_DOOR_SCRIPT := preload("res://scripts/presentation/buildings/BuildingAutoDoor.gd")
const DINING_KITCHEN_WORK_FX_SCRIPT := preload("res://scripts/presentation/buildings/DiningKitchenWorkFX.gd")

const BUILDING_FOOTPRINT := Vector2(14.0, 12.0)
const LOT_SIZE := Vector2(16.0, 14.0)
const MAXIMUM_LEVEL := 3

const HALL_WALL := Color("#b8a887")
const HALL_STONE := Color("#66645e")
const HALL_TIMBER := Color("#4b3428")
const HALL_OAK := Color("#735039")
const HALL_ROOF := Color("#8b4f3f")
const HALL_ROOF_EDGE := Color("#58362f")
const HALL_LINEN := Color("#cbb987")
const HALL_IRON := Color("#34383b")
const HALL_FIRE := Color("#e46b2d")
const HALL_GOLD := Color("#c59a4b")

var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_formal_dining_hall()
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
	var kitchen_work_fx_snapshot: Dictionary = {}
	var kitchen_work_fx := get_node_or_null("KitchenWorkFX")
	if kitchen_work_fx != null and kitchen_work_fx.has_method("debug_get_snapshot"):
		kitchen_work_fx_snapshot = kitchen_work_fx.call("debug_get_snapshot")
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"maximum_level": MAXIMUM_LEVEL,
		"upgrade_in_progress": _upgrade_in_progress,
		"level_2_visible": _is_visible(NodePath("UpgradeVisuals/Level2")),
		"level_3_visible": _is_visible(NodePath("UpgradeVisuals/Level3")),
		"workstations": workstation_states,
		"kitchen_station_count": _count_workstation_prefix(workstation_states, "dining_kitchen_station_"),
		"available_kitchen_station_count": _count_available_prefix(workstation_states, "dining_kitchen_station_"),
		"dining_seat_count": _count_workstation_prefix(workstation_states, "dining_seat_"),
		"available_dining_seat_count": _count_available_prefix(workstation_states, "dining_seat_"),
		"active_fixture_visual_count": _active_fixture_visual_count(),
		"active_fixture_collision_count": _active_fixture_collision_count(),
		"level_visual_addition_counts": {
			"level_1": _mesh_count_at("Interior/Level1Details") + _mesh_count_at("Interior/KitchenVentHoods") + _mesh_count_at("Exterior") + _mesh_count_at("Roof"),
			"level_2": _mesh_count_at("UpgradeVisuals/Level2"),
			"level_3": _mesh_count_at("UpgradeVisuals/Level3")
		},
		"building_footprint": BUILDING_FOOTPRINT,
		"lot_size": LOT_SIZE,
		"future_capacity_reserved": true,
		"architectural_style": "medieval_border_refectory_with_rear_hearth_kitchen",
		"facade_profile": "broad_ochre_plaster_oak_frame_meal_sign_and_firewood",
		"roof_profile": "wide_low_terracotta_gable_with_clustered_kitchen_chimneys",
		"gable_end_profile": "sealed_ochre_plaster_with_oak_frame",
		"sealed_gable_end_count": 2,
		"functional_visual_language": "shared_oak_tables_cauldron_hearths_pantry_and_hot_meals",
		"level_two_upgrade_profile": "pantry_preparation_and_fuel_storage_without_capacity_gain",
		"level_three_upgrade_profile": "third_authoritative_hearth_flue_and_expanded_serving_corner",
		"palette": {
			"wall": HALL_WALL.to_html(false),
			"timber": HALL_TIMBER.to_html(false),
			"roof": HALL_ROOF.to_html(false),
			"linen": HALL_LINEN.to_html(false),
			"fire": HALL_FIRE.to_html(false)
		},
		"auto_door": door_snapshot,
		"kitchen_work_fx": kitchen_work_fx_snapshot,
		"roof_mesh_count": _roof_meshes.size(),
		"roof_structure_additions_fade_with_roof": additional_roof_fade_paths.size() == 1,
		"exterior_material_count": _exterior_materials.size(),
		"interior_revealed_for_selection": is_interior_revealed_for_selection(),
		"shell_opacity": maxf(_roof_opacity, _exterior_opacity),
		"navigation_ready": _formal_navigation_ready(),
		"collision_authority": "formal_station_static_and_level_synced_fixture_collision",
		"navigation_authority": "formal_station_navigation_mesh",
		"meal_authority": "resource_and_action_system_only",
		"authority_role": "presentation_only"
	}


func _build_formal_dining_hall() -> void:
	building_id = "dining_hall"
	roof_near_distance = 58.0
	roof_far_distance = 70.0
	minimum_roof_opacity = 0.06
	fade_exterior_with_roof = true
	minimum_exterior_opacity = 0.06
	interior_reveal_opacity_threshold = 0.72
	interaction_bounds_center = Vector3(0.0, 2.8, 0.0)
	interaction_bounds_size = Vector3(16.2, 6.8, 14.2)
	roof_albedo_override = HALL_ROOF
	preserve_roof_albedo_texture = false
	exterior_albedo_tint = HALL_WALL
	static_collision_path = NodePath("../StaticCollision")
	workstation_markers_path = NodePath("../FixtureLayout/NPCStands")
	set_meta("art_revision", "t0135_p8ar7")
	set_meta("formal_vertical_slice", true)
	set_meta("architectural_style", "medieval_border_refectory_with_rear_hearth_kitchen")
	set_meta("footprint_meters", BUILDING_FOOTPRINT)
	set_meta("lot_size_meters", LOT_SIZE)
	set_meta("maximum_level", MAXIMUM_LEVEL)
	set_meta("kitchen_capacity_by_level", [2, 2, 3])
	set_meta("fixed_dining_seat_capacity", 10)
	_build_foundation_and_floor()
	_build_exterior()
	_build_roof()
	_build_level_one_details()
	_build_upgrade_visuals()
	_build_kitchen_work_fx()
	additional_roof_fade_paths = [
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
	_add_box(interior, "StoneFoundation", Vector3(0.0, 0.11, 0.0), Vector3(13.9, 0.22, 11.9), HALL_STONE.darkened(0.18))
	var floor := Node3D.new()
	floor.name = "Floor"
	interior.add_child(floor)
	for x in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
		for z in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
			_add_scene_prop(floor, "DarkOakFloor", FLOOR_DARK, Vector3(x, 0.14, z), Vector3(1.0, 0.2, 1.0))
	_add_box(interior, "EntryRunner", Vector3(0.0, 0.19, 4.15), Vector3(1.7, 0.035, 3.25), Color("#7d684c"))


func _build_exterior() -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	var wall_shell := Node3D.new()
	wall_shell.name = "OchrePlasterWallShell"
	exterior.add_child(wall_shell)
	for x in [-6.0, -4.0, -2.0, 2.0, 4.0, 6.0]:
		_add_scene_prop(wall_shell, "FrontWall", WALL_STRAIGHT, Vector3(x, 0.2, 6.0), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(wall_shell, "BroadDoorArch", WALL_DOOR, Vector3(0.0, 0.2, 6.0), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
	for x in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
		_add_scene_prop(wall_shell, "RearWall", WALL_STRAIGHT, Vector3(x, 0.2, -6.0), Vector3.ONE)
	for side in [-1.0, 1.0]:
		for z in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
			_add_scene_prop(wall_shell, "SideWall", WALL_STRAIGHT, Vector3(side * 7.0, 0.2, z), Vector3.ONE, Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0))

	var timber := Node3D.new()
	timber.name = "RefectoryOakFrame"
	exterior.add_child(timber)
	_add_box(timber, "FrontStoneCourse", Vector3(0.0, 0.42, 6.12), Vector3(14.15, 0.62, 0.34), HALL_STONE)
	_add_box(timber, "RearStoneCourse", Vector3(0.0, 0.42, -6.12), Vector3(14.15, 0.62, 0.34), HALL_STONE.darkened(0.05))
	for x in [-6.88, -4.6, -2.35, 2.35, 4.6, 6.88]:
		_add_box(timber, "FrontOakPost", Vector3(x, 1.75, 6.15), Vector3(0.24, 3.25, 0.26), HALL_TIMBER)
		_add_box(timber, "RearOakPost", Vector3(x, 1.75, -6.15), Vector3(0.24, 3.25, 0.26), HALL_TIMBER)
	for x in [-1.17, 1.17]:
		_add_box(timber, "DoorJamb", Vector3(x, 1.7, 6.16), Vector3(0.22, 3.14, 0.28), HALL_TIMBER)
	for side in [-1.0, 1.0]:
		for z in [-4.7, 0.0, 4.7]:
			_add_box(timber, "SideOakPost", Vector3(side * 7.14, 1.75, z), Vector3(0.28, 3.25, 0.24), HALL_TIMBER)
	_add_box(timber, "FrontOakLintel", Vector3(0.0, 3.22, 6.14), Vector3(14.15, 0.28, 0.28), HALL_TIMBER)
	_add_box(timber, "RearOakLintel", Vector3(0.0, 3.22, -6.14), Vector3(14.15, 0.28, 0.28), HALL_TIMBER)
	var gable_ends := Node3D.new()
	gable_ends.name = "SealedOchreGableEnds"
	exterior.add_child(gable_ends)
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var end_x: float = float(side) * 7.08
		_add_gable_wall(gable_ends, "%sOchreGableWall" % side_name, Vector3(end_x, 4.32, 0.0), Vector3(12.0, 2.16, 0.3), _material(HALL_WALL), 90.0)
		_add_box(gable_ends, "%sGableTie" % side_name, Vector3(end_x, 3.28, 0.0), Vector3(0.34, 0.22, 12.0), HALL_TIMBER)
		_add_box(gable_ends, "%sKingPost" % side_name, Vector3(end_x, 4.31, 0.0), Vector3(0.34, 2.08, 0.24), HALL_TIMBER)
		var front_rafter := _add_box(gable_ends, "%sFrontRakingBeam" % side_name, Vector3(end_x, 4.32, 3.0), Vector3(0.34, 0.22, 6.32), HALL_TIMBER)
		front_rafter.rotation_degrees.x = 18.0
		var rear_rafter := _add_box(gable_ends, "%sRearRakingBeam" % side_name, Vector3(end_x, 4.32, -3.0), Vector3(0.34, 0.22, 6.32), HALL_TIMBER)
		rear_rafter.rotation_degrees.x = -18.0

	var windows := Node3D.new()
	windows.name = "WarmRefectoryWindows"
	exterior.add_child(windows)
	for x in [-5.0, -3.0, 3.0, 5.0]:
		_add_hall_window(windows, Vector3(x, 2.0, 6.2), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		for z in [-2.0, 2.0, 4.45]:
			_add_hall_window(windows, Vector3(side * 7.2, 2.0, z), Vector3(0.0, 90.0, 0.0))

	var sign := Node3D.new()
	sign.name = "MealAndLadleSign"
	sign.position = Vector3(0.0, 3.88, 6.34)
	exterior.add_child(sign)
	_add_cylinder(sign, "OakSignBoard", Vector3.ZERO, 0.72, 0.15, HALL_TIMBER.lightened(0.12), Vector3(90.0, 0.0, 0.0))
	_add_cylinder(sign, "GoldenBowl", Vector3(-0.14, -0.13, 0.13), 0.25, 0.1, HALL_GOLD, Vector3(90.0, 0.0, 0.0))
	var ladle := _add_box(sign, "GoldenLadleHandle", Vector3(0.18, 0.14, 0.15), Vector3(0.1, 0.72, 0.1), HALL_GOLD.lightened(0.08))
	ladle.rotation_degrees.z = -38.0
	_add_sphere(sign, "GoldenLadleCup", Vector3(0.4, -0.12, 0.15), 0.16, HALL_GOLD)

	var door := Node3D.new()
	door.name = "AutoDoor"
	door.position = Vector3(0.0, 0.2, 6.2)
	door.set_script(AUTO_DOOR_SCRIPT)
	door.call("configure", HALL_OAK, HALL_TIMBER, HALL_IRON)
	exterior.add_child(door)

	var supplies := Node3D.new()
	supplies.name = "KitchenYardSupplies"
	exterior.add_child(supplies)
	_add_firewood_stack(supplies, "FrontFirewoodStack", Vector3(-5.45, 0.0, 6.53))
	_add_scene_prop(supplies, "WaterBarrel", BARREL, Vector3(5.35, 0.18, 6.55), Vector3.ONE * 0.62)
	_add_scene_prop(supplies, "FoodCrate", CRATE, Vector3(4.55, 0.18, 6.58), Vector3.ONE * 0.55, Vector3(0.0, -12.0, 0.0))


func _build_roof() -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.set_meta("roof_fade_candidate", true)
	add_child(roof)
	var main_roof := Node3D.new()
	main_roof.name = "WideTerracottaRefectoryRoof"
	roof.add_child(main_roof)
	var front := _add_box(main_roof, "FrontTerracottaSlope", Vector3(0.0, 4.30, 3.22), Vector3(14.55, 0.18, 6.82), HALL_ROOF)
	front.rotation_degrees.x = 18.0
	var rear := _add_box(main_roof, "RearTerracottaSlope", Vector3(0.0, 4.30, -3.22), Vector3(14.55, 0.18, 6.82), HALL_ROOF.darkened(0.055))
	rear.rotation_degrees.x = -18.0
	_add_cylinder(main_roof, "RoundedTerracottaRidge", Vector3(0.0, 5.43, 0.0), 0.17, 14.75, HALL_ROOF_EDGE, Vector3(0.0, 0.0, 90.0))
	for z in [1.05, 2.35, 3.65, 4.95, 6.12]:
		var y: float = 5.35 - tan(deg_to_rad(18.0)) * float(z)
		var front_batten := _add_box(main_roof, "FrontTileCourse", Vector3(0.0, y + 0.09, z), Vector3(14.48, 0.045, 0.09), HALL_ROOF_EDGE.lightened(0.08))
		front_batten.rotation_degrees.x = 18.0
		var rear_batten := _add_box(main_roof, "RearTileCourse", Vector3(0.0, y + 0.09, -z), Vector3(14.48, 0.045, 0.09), HALL_ROOF_EDGE)
		rear_batten.rotation_degrees.x = -18.0
	for x in [-6.7, -4.5, -2.25, 0.0, 2.25, 4.5, 6.7]:
		_add_box(main_roof, "FrontTileSeam", Vector3(x, 4.30, 3.22), Vector3(0.055, 0.04, 6.65), HALL_ROOF_EDGE.lightened(0.04)).rotation_degrees.x = 18.0
		_add_box(main_roof, "RearTileSeam", Vector3(x, 4.30, -3.22), Vector3(0.055, 0.04, 6.65), HALL_ROOF_EDGE.darkened(0.04)).rotation_degrees.x = -18.0
	var chimney_cluster := Node3D.new()
	chimney_cluster.name = "LevelOneKitchenChimneys"
	roof.add_child(chimney_cluster)
	_add_kitchen_chimney(chimney_cluster, "WestKitchenChimney", -3.8, false)
	_add_kitchen_chimney(chimney_cluster, "CenterKitchenChimney", 0.0, false)


func _build_level_one_details() -> void:
	var interior := get_node("Interior") as Node3D
	var hoods := Node3D.new()
	hoods.name = "KitchenVentHoods"
	interior.add_child(hoods)
	_add_kitchen_hood(hoods, "WestHearthHood", -3.8, "dining_kitchen_station_01")
	_add_kitchen_hood(hoods, "CenterHearthHood", 0.0, "dining_kitchen_station_02")
	var details := Node3D.new()
	details.name = "Level1Details"
	interior.add_child(details)
	_add_scene_prop(details, "WestDryGoodsShelf", SHELF, Vector3(-5.72, 0.18, -3.2), Vector3.ONE * 0.56, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(details, "EastCrockeryShelf", SHELF, Vector3(5.72, 0.18, -3.2), Vector3.ONE * 0.56, Vector3(0.0, -90.0, 0.0))
	_add_scene_prop(details, "FlourSackOne", BAG, Vector3(-5.85, 0.18, -4.85), Vector3.ONE * 0.72, Vector3(0.0, 15.0, 0.0))
	_add_scene_prop(details, "FlourSackTwo", BAG, Vector3(-5.2, 0.18, -4.65), Vector3.ONE * 0.64, Vector3(0.0, -12.0, 0.0))
	_add_scene_prop(details, "CleanWaterBarrel", BARREL, Vector3(5.9, 0.18, -4.75), Vector3.ONE * 0.62)
	_add_scene_prop(details, "WashBucket", BUCKET, Vector3(5.15, 0.18, -4.8), Vector3.ONE * 0.72)
	_add_scene_prop(details, "FrontLanternLeft", LANTERN, Vector3(-2.0, 2.5, 5.65), Vector3.ONE * 0.72, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(details, "FrontLanternRight", LANTERN, Vector3(2.0, 2.5, 5.65), Vector3.ONE * 0.72, Vector3(0.0, 180.0, 0.0))
	_add_crockery_rack(details, "WestServingCrockery", Vector3(-6.22, 1.15, 3.9), 90.0)
	_add_crockery_rack(details, "EastServingCrockery", Vector3(6.22, 1.15, 3.9), -90.0)


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
	_add_scene_prop(level_2_interior, "ExpandedDryPantry", SHELF, Vector3(-5.72, 0.18, 1.0), Vector3.ONE * 0.56, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(level_2_interior, "ExpandedCrockeryPantry", SHELF, Vector3(5.72, 0.18, 1.0), Vector3.ONE * 0.56, Vector3(0.0, -90.0, 0.0))
	_add_preparation_counter(level_2_interior, "NonWorkstationPreparationCounter", Vector3(4.15, 0.0, 5.22), 90.0)
	for index in range(5):
		_add_cylinder(level_2_interior, "SpiceJar", Vector3(-6.05, 1.2, -0.2 + float(index) * 0.3), 0.09, 0.26, [Color("#89633f"), Color("#765044"), Color("#9a7b43")][index % 3])
	var level_2_exterior := Node3D.new()
	level_2_exterior.name = "ExteriorAdditions"
	level_2.add_child(level_2_exterior)
	_add_fuel_lean_to(level_2_exterior)
	var level_3 := Node3D.new()
	level_3.name = "Level3"
	level_3.visible = false
	upgrades.add_child(level_3)
	var level_3_interior := Node3D.new()
	level_3_interior.name = "InteriorAdditions"
	level_3.add_child(level_3_interior)
	_add_kitchen_hood(level_3_interior, "EastThirdHearthHood", 3.8, "dining_kitchen_station_03")
	_add_crockery_rack(level_3_interior, "ExpandedCookwareRack", Vector3(6.2, 1.25, -1.15), -90.0)
	var serving_counter := Node3D.new()
	serving_counter.name = "ExpandedServingCounter"
	serving_counter.position = Vector3(-4.15, 0.0, 5.22)
	serving_counter.rotation_degrees.y = 90.0
	serving_counter.set_meta("authority_role", "non_workstation_decoration")
	level_3_interior.add_child(serving_counter)
	_add_box(serving_counter, "OakServingCabinet", Vector3(0.0, 0.72, 0.0), Vector3(0.78, 1.18, 2.8), HALL_OAK)
	_add_box(serving_counter, "ServingTop", Vector3(-0.02, 1.34, 0.0), Vector3(0.92, 0.14, 2.94), HALL_LINEN.darkened(0.18))
	for index in range(4):
		_add_scene_prop(serving_counter, "ServingMug", MUG, Vector3(-0.48, 1.38, -0.72 + float(index) * 0.48), Vector3.ONE * 0.82, Vector3(0.0, float(index * 18), 0.0))
	var level_3_exterior := Node3D.new()
	level_3_exterior.name = "ExteriorAdditions"
	level_3.add_child(level_3_exterior)
	_add_box(level_3_exterior, "SeniorCookBoard", Vector3(4.5, 3.48, 6.28), Vector3(2.15, 0.5, 0.14), HALL_OAK)
	_add_cylinder(level_3_exterior, "ThirdHearthCopperBadge", Vector3(4.5, 3.48, 6.39), 0.19, 0.08, HALL_GOLD, Vector3(90.0, 0.0, 0.0))
	var level_3_roof := Node3D.new()
	level_3_roof.name = "RoofStructureAdditions"
	level_3.add_child(level_3_roof)
	_add_kitchen_chimney(level_3_roof, "EastThirdKitchenChimney", 3.8, true)


func _add_hall_window(parent: Node3D, center: Vector3, rotation_value: Vector3) -> void:
	var window := Node3D.new()
	window.name = "RefectoryWindow"
	window.position = center
	window.rotation_degrees = rotation_value
	parent.add_child(window)
	_add_box(window, "StoneSurround", Vector3.ZERO, Vector3(1.45, 1.45, 0.13), HALL_STONE)
	_add_box(window, "AmberGlass", Vector3(0.0, 0.0, 0.09), Vector3(1.05, 1.05, 0.04), Color("#c18a56"))
	_add_box(window, "OakMullion", Vector3(0.0, 0.0, 0.13), Vector3(0.09, 1.08, 0.06), HALL_TIMBER)
	_add_box(window, "OakCrossbar", Vector3(0.0, 0.0, 0.13), Vector3(1.08, 0.09, 0.06), HALL_TIMBER)
	_add_box(window, "StoneSill", Vector3(0.0, -0.82, 0.15), Vector3(1.62, 0.15, 0.22), HALL_STONE.lightened(0.1))


func _add_kitchen_hood(parent: Node3D, node_name: String, x: float, workstation_id: String) -> void:
	var hood := Node3D.new()
	hood.name = node_name
	hood.position = Vector3(x, 0.0, -4.72)
	parent.add_child(hood)
	_add_box(hood, "StoneHearthBack", Vector3(0.0, 1.0, -0.55), Vector3(1.65, 1.8, 0.32), HALL_STONE.darkened(0.08))
	_add_box(hood, "HammeredIronHood", Vector3(0.0, 1.75, -0.2), Vector3(1.45, 0.38, 1.0), HALL_IRON)
	_add_box(hood, "SmokeThroat", Vector3(0.0, 2.38, -0.42), Vector3(0.55, 0.92, 0.55), HALL_IRON.darkened(0.05))
	var fire_glow := _add_box(hood, "FireGlow", Vector3(0.0, 0.42, 0.34), Vector3(0.74, 0.22, 0.06), HALL_FIRE)
	fire_glow.visible = false
	fire_glow.set_meta("dining_work_heat", true)
	fire_glow.set_meta("workstation_id", workstation_id)


func _build_kitchen_work_fx() -> void:
	var work_fx := Node3D.new()
	work_fx.name = "KitchenWorkFX"
	work_fx.set_script(DINING_KITCHEN_WORK_FX_SCRIPT)
	for station_config in [
		{
			"node_name": "Station01",
			"workstation_id": "dining_kitchen_station_01",
			"chimney_name": "WestKitchenChimney",
			"x": -3.8,
			"required_level": 1
		},
		{
			"node_name": "Station02",
			"workstation_id": "dining_kitchen_station_02",
			"chimney_name": "CenterKitchenChimney",
			"x": 0.0,
			"required_level": 1
		},
		{
			"node_name": "Station03",
			"workstation_id": "dining_kitchen_station_03",
			"chimney_name": "EastThirdKitchenChimney",
			"x": 3.8,
			"required_level": 3
		}
	]:
		_add_kitchen_station_work_fx(work_fx, station_config)
	add_child(work_fx)


func _add_kitchen_station_work_fx(parent: Node3D, config: Dictionary) -> void:
	var station := Node3D.new()
	station.name = str(config.get("node_name", "KitchenStationFX"))
	station.position = Vector3(float(config.get("x", 0.0)), 0.0, -4.0)
	station.set_meta("workstation_id", str(config.get("workstation_id", "")))
	station.set_meta("chimney_name", str(config.get("chimney_name", "")))
	station.set_meta("required_level", int(config.get("required_level", 1)))
	station.set_meta("presentation_only", true)
	parent.add_child(station)

	var fire_visuals := Node3D.new()
	fire_visuals.name = "FireVisuals"
	station.add_child(fire_visuals)
	_add_emissive_sphere(fire_visuals, "FlameCore", Vector3(0.0, 0.47, 0.0), Vector3(0.16, 0.34, 0.16), Color("#ff7a24"), 4.5)
	_add_emissive_sphere(fire_visuals, "FlameLeft", Vector3(-0.19, 0.43, 0.05), Vector3(0.11, 0.25, 0.11), Color("#ffb02e"), 4.0)
	_add_emissive_sphere(fire_visuals, "FlameRight", Vector3(0.19, 0.42, -0.04), Vector3(0.10, 0.23, 0.10), Color("#e94f1d"), 4.2)

	var food_visuals := Node3D.new()
	food_visuals.name = "FoodVisuals"
	food_visuals.position.y = -0.18
	station.add_child(food_visuals)
	_add_cylinder(food_visuals, "StewSurface", Vector3(0.0, 1.08, 0.0), 0.37, 0.055, Color("#8f4d25"))
	_add_sphere(food_visuals, "CarrotPiece", Vector3(-0.16, 1.13, 0.08), 0.085, Color("#d8792f"))
	_add_sphere(food_visuals, "CabbagePiece", Vector3(0.11, 1.12, 0.12), 0.09, Color("#7e9a4e"))
	_add_sphere(food_visuals, "OnionPiece", Vector3(0.19, 1.13, -0.11), 0.075, Color("#d6c27c"))
	_add_sphere(food_visuals, "BeetPiece", Vector3(-0.08, 1.12, -0.18), 0.07, Color("#93434c"))
	_add_cylinder(food_visuals, "HerbSprig", Vector3(0.0, 1.15, -0.02), 0.035, 0.28, Color("#4d783d"), Vector3(0.0, 0.0, 72.0))

	var pot_steam := _add_kitchen_particles(station, "PotSteam", Vector3(0.0, 1.30, 0.0), false)
	pot_steam.set_meta("workstation_id", str(config.get("workstation_id", "")))
	var chimney_smoke := _add_kitchen_particles(station, "ChimneySmoke", Vector3(0.0, 6.55, -0.82), true)
	chimney_smoke.set_meta("workstation_id", str(config.get("workstation_id", "")))
	chimney_smoke.set_meta("chimney_name", str(config.get("chimney_name", "")))

	var fire_light := OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.position = Vector3(0.0, 0.72, 0.12)
	fire_light.light_color = Color("#ff9a54")
	fire_light.light_energy = 0.0
	fire_light.omni_range = 2.8
	fire_light.shadow_enabled = true
	fire_light.distance_fade_enabled = false
	fire_light.light_volumetric_fog_energy = 0.0
	station.add_child(fire_light)


func _add_emissive_sphere(parent: Node3D, node_name: String, center: Vector3, scale_value: Vector3, color: Color, emission_energy: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.material = _emissive_material(color, emission_energy)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.scale = scale_value
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_kitchen_particles(parent: Node3D, node_name: String, center: Vector3, chimney_smoke: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.position = center
	particles.amount = 16 if chimney_smoke else 10
	particles.lifetime = 3.4 if chimney_smoke else 1.8
	particles.randomness = 0.72
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 8.0, 4.0))
	particles.emitting = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.18 if chimney_smoke else 0.11
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 18.0 if chimney_smoke else 10.0
	process.initial_velocity_min = 0.42 if chimney_smoke else 0.24
	process.initial_velocity_max = 0.82 if chimney_smoke else 0.46
	process.gravity = Vector3(0.0, 0.08, 0.0)
	process.scale_min = 0.55
	process.scale_max = 1.35 if chimney_smoke else 0.82
	particles.process_material = process
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 0.12 if chimney_smoke else 0.075
	puff_mesh.height = 0.24 if chimney_smoke else 0.15
	puff_mesh.radial_segments = 8
	puff_mesh.rings = 4
	var puff_material := StandardMaterial3D.new()
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.albedo_color = Color(0.30, 0.29, 0.27, 0.34) if chimney_smoke else Color(0.78, 0.82, 0.80, 0.28)
	puff_material.roughness = 1.0
	puff_mesh.material = puff_material
	particles.draw_pass_1 = puff_mesh
	parent.add_child(particles)
	return particles


func _emissive_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	return material


func _add_kitchen_chimney(parent: Node3D, node_name: String, x: float, reinforced: bool) -> void:
	var chimney := Node3D.new()
	chimney.name = node_name
	chimney.position = Vector3(x, 0.0, -4.82)
	chimney.set_meta("hollow_flue", true)
	chimney.set_meta("flue_inner_width", 0.38)
	parent.add_child(chimney)
	_add_hollow_square_course(chimney, "StoneShaft", Vector3(0.0, 4.7, 0.0), 0.78, 0.38, 3.15, HALL_STONE.darkened(0.08))
	_add_hollow_square_course(chimney, "BrickCrown", Vector3(0.0, 6.15, 0.0), 1.02, 0.48, 0.25, HALL_ROOF_EDGE)
	if reinforced:
		_add_hollow_square_course(chimney, "IronFlueBand", Vector3(0.0, 5.52, 0.0), 0.88, 0.34, 0.12, HALL_IRON)


func _add_hollow_square_course(parent: Node3D, prefix: String, center: Vector3, outer_width: float, inner_width: float, height: float, color: Color) -> void:
	var wall_thickness := (outer_width - inner_width) * 0.5
	var wall_offset := inner_width * 0.5 + wall_thickness * 0.5
	_add_box(parent, "%sWestWall" % prefix, center + Vector3(-wall_offset, 0.0, 0.0), Vector3(wall_thickness, height, outer_width), color)
	_add_box(parent, "%sEastWall" % prefix, center + Vector3(wall_offset, 0.0, 0.0), Vector3(wall_thickness, height, outer_width), color)
	_add_box(parent, "%sNorthWall" % prefix, center + Vector3(0.0, 0.0, -wall_offset), Vector3(inner_width, height, wall_thickness), color)
	_add_box(parent, "%sSouthWall" % prefix, center + Vector3(0.0, 0.0, wall_offset), Vector3(inner_width, height, wall_thickness), color)


func _add_crockery_rack(parent: Node3D, node_name: String, center: Vector3, yaw: float) -> void:
	var rack := Node3D.new()
	rack.name = node_name
	rack.position = center
	rack.rotation_degrees.y = yaw
	parent.add_child(rack)
	_add_box(rack, "OakBack", Vector3.ZERO, Vector3(2.35, 1.65, 0.14), HALL_TIMBER)
	for y in [-0.58, 0.0, 0.58]:
		_add_box(rack, "OakShelf", Vector3(0.0, y, 0.16), Vector3(2.15, 0.12, 0.42), HALL_OAK)
	for row in range(3):
		for column in range(4):
			_add_cylinder(rack, "WoodenBowl", Vector3(-0.78 + float(column) * 0.52, -0.48 + float(row) * 0.58, 0.36), 0.1, 0.08, HALL_LINEN)


func _add_preparation_counter(parent: Node3D, node_name: String, center: Vector3, yaw: float = 0.0) -> void:
	var counter := Node3D.new()
	counter.name = node_name
	counter.position = center
	counter.rotation_degrees.y = yaw
	parent.add_child(counter)
	counter.set_meta("authority_role", "non_workstation_decoration")
	_add_box(counter, "OakCounter", Vector3(0.0, 0.7, 0.0), Vector3(0.78, 1.18, 2.7), HALL_OAK)
	_add_box(counter, "ButcherBlockTop", Vector3(-0.02, 1.34, 0.0), Vector3(0.92, 0.14, 2.86), HALL_LINEN.darkened(0.2))
	_add_box(counter, "BreadBoard", Vector3(-0.52, 1.44, -0.55), Vector3(0.38, 0.06, 0.9), HALL_OAK.lightened(0.12))
	for z in [-0.72, 0.0, 0.72]:
		_add_sphere(counter, "PreparedLoaf", Vector3(-0.48, 1.54, z), 0.15, Color("#a96d39"))


func _add_fuel_lean_to(parent: Node3D) -> void:
	var lean_to := Node3D.new()
	lean_to.name = "LevelTwoFuelLeanTo"
	parent.add_child(lean_to)
	var roof := _add_box(lean_to, "LowTerracottaAwning", Vector3(-7.45, 2.18, -2.35), Vector3(0.82, 0.16, 3.8), HALL_ROOF.darkened(0.08))
	roof.rotation_degrees.z = -7.0
	for z in [-3.95, -0.75]:
		_add_box(lean_to, "OuterOakPost", Vector3(-7.74, 1.12, z), Vector3(0.14, 2.1, 0.14), HALL_TIMBER)
	var fuel_stack := _add_firewood_stack(lean_to, "SeasonedFuelStack", Vector3(-7.42, 0.0, -2.35))
	fuel_stack.rotation_degrees.y = 90.0
	_add_scene_prop(lean_to, "ReserveFlourSack", BAG, Vector3(-6.82, 0.18, -0.75), Vector3.ONE * 0.4, Vector3(0.0, 14.0, 0.0))


func _add_firewood_stack(parent: Node3D, node_name: String, center: Vector3) -> Node3D:
	var woodpile := Node3D.new()
	woodpile.name = node_name
	woodpile.position = center
	parent.add_child(woodpile)
	for row in range(3):
		for column in range(4):
			var log := _add_cylinder(woodpile, "SplitLog", Vector3(-0.72 + float(column) * 0.48, 0.18 + float(row) * 0.28, 0.0), 0.11, 0.82, HALL_OAK.lightened(float((row + column) % 2) * 0.08), Vector3(90.0, 0.0, 0.0))
			log.rotation_degrees.y = float((column % 2) * 6 - 3)
	_add_box(woodpile, "StackRail", Vector3(0.0, 0.05, 0.0), Vector3(2.2, 0.1, 0.65), HALL_TIMBER)
	return woodpile


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
