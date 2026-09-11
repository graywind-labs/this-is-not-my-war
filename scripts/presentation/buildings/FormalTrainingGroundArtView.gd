class_name FormalTrainingGroundArtView
extends BuildingArtView


const AUTO_DOOR_SCRIPT := preload("res://scripts/presentation/buildings/BuildingAutoDoor.gd")
const BARREL := "res://assets/3d/quaternius/props/barrel.glb"
const CRATE := "res://assets/3d/quaternius/props/crate_wooden.glb"
const WEAPON_STAND := "res://assets/3d/quaternius/props/weapon_stand.glb"
const WOODEN_SHIELD := "res://assets/3d/quaternius/props/shield_wooden.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"

const LOT_SIZE := Vector2(16.0, 18.0)
const ENVELOPE_SIZE := Vector2(14.0, 16.0)
const MAXIMUM_LEVEL := 3
const PACKED_EARTH := Color("#4b4034")
const WORN_EARTH := Color("#675743")
const DARK_EARTH := Color("#382f28")
const STONE := Color("#59605e")
const PALE_STONE := Color("#777d77")
const DARK_WOOD := Color("#3e332c")
const OAK := Color("#6b5039")
const WEATHERED_WOOD := Color("#806447")
const IRON := Color("#444b4f")
const CLOTH_RED := Color("#70404a")
const CLOTH_BLUE := Color("#46566a")
const LEATHER := Color("#67503c")
const STRAW := Color("#a08a59")
const WATER := Color("#426873")

var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_formal_training_ground()
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
				"global_position": marker.global_position,
				"action_clearance_size": marker.get_meta("action_clearance_size", Vector2.ZERO)
			}
	var gate_snapshot: Dictionary = {}
	var auto_gate := get_node_or_null("Exterior/AutoTrainingGate")
	if auto_gate != null and auto_gate.has_method("debug_get_snapshot"):
		gate_snapshot = auto_gate.call("debug_get_snapshot")
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"maximum_level": MAXIMUM_LEVEL,
		"level_2_visible": _is_visible(NodePath("UpgradeVisuals/Level2")),
		"level_3_visible": _is_visible(NodePath("UpgradeVisuals/Level3")),
		"workstations": workstation_states,
		"instructor_station_count": _count_workstation_prefix(workstation_states, "training_instructor_"),
		"student_station_count": _count_workstation_prefix(workstation_states, "training_student_"),
		"available_instructor_station_count": _count_available_prefix(workstation_states, "training_instructor_"),
		"available_student_station_count": _count_available_prefix(workstation_states, "training_student_"),
		"active_fixture_visual_count": _active_fixture_visual_count(),
		"active_fixture_collision_count": _active_fixture_collision_count(),
		"active_fixture_collision_part_count": _active_fixture_collision_part_count(),
		"level_visual_addition_counts": {
			"level_1": _mesh_count_at("Interior/Level1Details") + _mesh_count_at("Exterior") + _mesh_count_at("Roof"),
			"level_2": _mesh_count_at("UpgradeVisuals/Level2"),
			"level_3": _mesh_count_at("UpgradeVisuals/Level3")
		},
		"lot_size": LOT_SIZE,
		"envelope_size": ENVELOPE_SIZE,
		"architectural_style": "open_air_medieval_border_training_yard",
		"facade_profile": "low_stone_timber_palisade_wide_gate_and_command_shelters",
		"roof_profile": "small_instructor_and_equipment_shelters_only",
		"functional_visual_language": "command_flags_dummies_weapon_racks_shield_wall_archery_lane_and_drill_marks",
		"level_two_upgrade_profile": "third_authoritative_practice_lane_and_safety_equipment_without_instructor_gain",
		"level_three_upgrade_profile": "second_authoritative_instructor_post_fourth_practice_lane_and_advanced_equipment",
		"open_air_selection_priority": is_interior_revealed_for_selection(),
		"auto_gate": gate_snapshot,
		"roof_mesh_count": _roof_meshes.size(),
		"roof_structure_additions_fade_with_roof": additional_roof_fade_paths.size() == 2,
		"navigation_ready": _formal_navigation_ready(),
		"collision_authority": "formal_station_static_and_level_synced_fixture_collision",
		"navigation_authority": "formal_station_navigation_mesh",
		"training_authority": "building_action_and_npc_system_only",
		"authority_role": "presentation_only"
	}


func _build_formal_training_ground() -> void:
	building_id = "training_ground"
	roof_near_distance = 58.0
	roof_far_distance = 70.0
	minimum_roof_opacity = 0.06
	fade_exterior_with_roof = false
	interaction_bounds_center = Vector3(0.0, 1.6, 0.0)
	interaction_bounds_size = Vector3(14.0, 4.2, 16.0)
	roof_albedo_override = CLOTH_BLUE
	preserve_roof_albedo_texture = false
	static_collision_path = NodePath("../StaticCollision")
	workstation_markers_path = NodePath("../FixtureLayout/NPCStands")
	set_meta("art_revision", "t0131_p8")
	set_meta("formal_vertical_slice", true)
	set_meta("open_air_site", true)
	set_meta("lot_size_meters", LOT_SIZE)
	set_meta("envelope_size_meters", ENVELOPE_SIZE)
	set_meta("maximum_level", MAXIMUM_LEVEL)
	_build_ground_and_training_lanes()
	_build_enclosure_and_gate()
	_build_first_command_shelter()
	_build_level_one_details()
	_build_upgrade_visuals()
	additional_roof_fade_paths = [
		NodePath("UpgradeVisuals/Level2/RoofStructureAdditions"),
		NodePath("UpgradeVisuals/Level3/RoofStructureAdditions")
	]


func _build_ground_and_training_lanes() -> void:
	var interior := Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_add_box(interior, "CompactedTrainingEarth", Vector3(0.0, 0.035, 0.0), Vector3(13.65, 0.07, 15.65), PACKED_EARTH)
	var paths := Node3D.new()
	paths.name = "WornTrainingPaths"
	interior.add_child(paths)
	_add_box(paths, "CentralEntryRun", Vector3(0.0, 0.085, 4.9), Vector3(1.75, 0.035, 5.45), WORN_EARTH)
	_add_box(paths, "RearDrillCrossing", Vector3(0.0, 0.082, -5.05), Vector3(11.8, 0.03, 0.82), DARK_EARTH)
	_add_box(paths, "MiddleDrillCrossing", Vector3(0.0, 0.083, 0.0), Vector3(11.8, 0.03, 0.72), DARK_EARTH)
	for z in [-6.8, -5.8, -4.8, -3.8, -2.8, -1.8, -0.8, 0.2, 1.2, 2.2, 3.2, 4.2, 5.2, 6.2]:
		_add_boot_mark(paths, Vector3(-0.22 if int(z * 10.0) % 2 == 0 else 0.22, 0.112, z), float(int(z * 17.0) % 24 - 12))


func _build_enclosure_and_gate() -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	var curb := Node3D.new()
	curb.name = "LowStoneCurb"
	exterior.add_child(curb)
	_add_box(curb, "RearCurb", Vector3(0.0, 0.18, -7.78), Vector3(13.55, 0.36, 0.4), STONE)
	for side in [-1.0, 1.0]:
		_add_box(curb, "SideCurb", Vector3(side * 6.78, 0.18, 0.0), Vector3(0.4, 0.36, 15.55), STONE)
		_add_box(curb, "FrontCurb", Vector3(side * 4.55, 0.18, 7.78), Vector3(4.35, 0.36, 0.4), STONE)

	var palisade := Node3D.new()
	palisade.name = "TrainingPalisade"
	exterior.add_child(palisade)
	_add_palisade_run(palisade, Vector3(0.0, 0.0, -7.7), 13.25, false)
	for side in [-1.0, 1.0]:
		_add_palisade_run(palisade, Vector3(side * 6.7, 0.0, 0.0), 15.3, true)
		_add_palisade_run(palisade, Vector3(side * 4.55, 0.0, 7.7), 4.1, false)
	for side in [-1.0, 1.0]:
		_add_box(exterior, "TrainingGateStonePost", Vector3(side * 1.22, 0.88, 7.7), Vector3(0.48, 1.76, 0.54), PALE_STONE)
		_add_box(exterior, "TrainingGateIronCap", Vector3(side * 1.22, 1.83, 7.7), Vector3(0.62, 0.14, 0.66), IRON)
	var gate := Node3D.new()
	gate.name = "AutoTrainingGate"
	gate.position = Vector3(0.0, 0.2, 7.7)
	gate.set_script(AUTO_DOOR_SCRIPT)
	gate.set("clear_width", 2.08)
	gate.set("clear_height", 2.35)
	gate.set("leaf_visual_height", 1.05)
	gate.call("configure", OAK, DARK_WOOD, IRON)
	exterior.add_child(gate)
	_add_training_sign(exterior)


func _build_first_command_shelter() -> void:
	var exterior := get_node("Exterior") as Node3D
	var shelter := Node3D.new()
	shelter.name = "FirstInstructorCommandShelter"
	exterior.add_child(shelter)
	for z in [-6.55, -3.55]:
		_add_box(shelter, "FenceSidePost", Vector3(-6.35, 1.5, z), Vector3(0.22, 2.65, 0.22), DARK_WOOD)
		_add_box(shelter, "InnerPost", Vector3(-4.85, 1.5, z), Vector3(0.2, 2.65, 0.2), DARK_WOOD)
		var brace := _add_box(shelter, "KneeBrace", Vector3(-5.18, 2.2, z), Vector3(0.12, 0.92, 0.12), OAK)
		brace.rotation_degrees.z = -42.0
	_add_box(shelter, "RearEquipmentRail", Vector3(-6.3, 1.45, -5.05), Vector3(0.18, 1.9, 2.8), WEATHERED_WOOD)
	_add_box(shelter, "CommandMapShelf", Vector3(-5.88, 1.02, -4.15), Vector3(0.72, 0.12, 1.15), OAK)
	_add_box(shelter, "RolledDrillMap", Vector3(-5.86, 1.15, -4.18), Vector3(0.46, 0.08, 0.82), Color("#b7a47d"))
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.set_meta("roof_fade_candidate", true)
	add_child(roof)
	var awning := _add_box(roof, "FirstCommandAwning", Vector3(-5.62, 2.82, -5.05), Vector3(2.45, 0.14, 3.55), CLOTH_BLUE)
	awning.rotation_degrees.z = -6.0
	for z in [-6.5, -5.05, -3.6]:
		var rib := _add_box(roof, "AwningRib", Vector3(-5.62, 2.87, z), Vector3(2.35, 0.055, 0.09), DARK_WOOD)
		rib.rotation_degrees.z = -6.0


func _build_level_one_details() -> void:
	var details := Node3D.new()
	details.name = "Level1Details"
	(get_node("Interior") as Node3D).add_child(details)
	_add_drill_marking(details, "StudentLane01Marking", Vector3(3.8, 0.0, -5.0), CLOTH_RED, "training_student_01")
	_add_drill_marking(details, "StudentLane02Marking", Vector3(-3.8, 0.0, 0.0), CLOTH_BLUE, "training_student_02")
	_add_command_marking(details, "InstructorPost01Marking", Vector3(-3.8, 0.0, -5.0), "training_instructor_01")

	var maintenance := Node3D.new()
	maintenance.name = "WeaponMaintenanceCorner"
	details.add_child(maintenance)
	_add_box(maintenance, "MaintenanceBench", Vector3(-5.72, 0.76, 2.15), Vector3(1.45, 0.16, 1.15), OAK)
	for z in [1.72, 2.58]:
		_add_box(maintenance, "BenchLeg", Vector3(-5.72, 0.38, z), Vector3(0.18, 0.74, 0.18), DARK_WOOD)
	_add_practice_sword(maintenance, "PracticeSword", Vector3(-5.66, 0.91, 2.12), 82.0, 0.72)
	_add_box(maintenance, "OilStone", Vector3(-5.35, 0.91, 1.86), Vector3(0.32, 0.09, 0.18), STONE)
	_add_scene_prop(maintenance, "SpareWeaponStand", WEAPON_STAND, Vector3(-5.92, 0.0, 3.15), Vector3.ONE * 0.62, Vector3(0.0, 90.0, 0.0))

	var water_corner := Node3D.new()
	water_corner.name = "WaterAndFirstAidCorner"
	details.add_child(water_corner)
	_add_scene_prop(water_corner, "WaterBarrel", BARREL, Vector3(5.7, 0.25, 6.65), Vector3.ONE * 0.68)
	_add_scene_prop(water_corner, "BandageCrate", CRATE, Vector3(4.82, 0.13, 6.72), Vector3.ONE * 0.44, Vector3(0.0, 14.0, 0.0))
	_add_box(water_corner, "WaterTrough", Vector3(5.52, 0.25, 5.72), Vector3(1.45, 0.42, 0.64), OAK)
	_add_box(water_corner, "TroughWater", Vector3(5.52, 0.48, 5.72), Vector3(1.18, 0.035, 0.38), WATER)
	_add_training_lamp_post(details, "TrainingLanternWestRear", Vector3(-6.15, 0.0, -5.55), 90.0, 1)
	_add_training_lamp_post(details, "TrainingLanternEastRear", Vector3(6.15, 0.0, -5.55), -90.0, 1)
	_add_training_lamp_post(details, "TrainingLanternEastFront", Vector3(6.15, 0.0, 4.85), -90.0, 2)
	_add_training_lamp_post(details, "TrainingLanternWestFront", Vector3(-6.15, 0.0, 4.85), 90.0, 3)

	var pennants := Node3D.new()
	pennants.name = "PerimeterDrillPennants"
	details.add_child(pennants)
	for item in [
		{"position": Vector3(-6.5, 1.9, -1.8), "color": CLOTH_RED},
		{"position": Vector3(6.5, 1.9, -4.0), "color": CLOTH_BLUE},
		{"position": Vector3(6.5, 1.9, 4.0), "color": CLOTH_RED}
	]:
		_add_drill_pennant(pennants, item.position, item.color)


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
	_add_drill_marking(level_2_interior, "StudentLane03Marking", Vector3(3.8, 0.0, 0.0), CLOTH_RED, "training_student_03")
	_add_level_two_shield_wall(level_2_interior)
	_add_archery_safety_net(level_2_interior)
	_add_protective_gear_storage(level_2_interior)
	var level_2_roof := Node3D.new()
	level_2_roof.name = "RoofStructureAdditions"
	level_2.add_child(level_2_roof)
	var equipment_awning := _add_box(level_2_roof, "EquipmentWeatherAwning", Vector3(-5.68, 2.48, 1.85), Vector3(1.85, 0.13, 3.5), CLOTH_BLUE.darkened(0.08))
	equipment_awning.rotation_degrees.z = -7.0

	var level_3 := Node3D.new()
	level_3.name = "Level3"
	level_3.visible = false
	upgrades.add_child(level_3)
	var level_3_interior := Node3D.new()
	level_3_interior.name = "InteriorAdditions"
	level_3.add_child(level_3_interior)
	_add_command_marking(level_3_interior, "InstructorPost02Marking", Vector3(-3.8, 0.0, 5.0), "training_instructor_02")
	_add_drill_marking(level_3_interior, "StudentLane04Marking", Vector3(3.8, 0.0, 5.0), CLOTH_BLUE, "training_student_04")
	_add_second_command_post_support(level_3_interior)
	_add_advanced_weapon_storage(level_3_interior)
	_add_level_three_entry_honours(level_3_interior)
	var level_3_roof := Node3D.new()
	level_3_roof.name = "RoofStructureAdditions"
	level_3.add_child(level_3_roof)
	var command_awning := _add_box(level_3_roof, "SecondCommandAwning", Vector3(-5.9, 2.82, 5.0), Vector3(1.62, 0.14, 3.5), CLOTH_RED.darkened(0.08))
	command_awning.rotation_degrees.z = -7.0
	for z in [3.55, 5.0, 6.45]:
		var rib := _add_box(level_3_roof, "SecondAwningRib", Vector3(-5.9, 2.87, z), Vector3(1.52, 0.055, 0.09), DARK_WOOD)
		rib.rotation_degrees.z = -7.0


func _add_training_sign(parent: Node3D) -> void:
	var sign := Node3D.new()
	sign.name = "CrossedWeaponsTrainingSign"
	sign.position = Vector3(-2.18, 1.68, 7.78)
	parent.add_child(sign)
	_add_box(sign, "SignBoard", Vector3.ZERO, Vector3(1.45, 0.82, 0.14), DARK_WOOD)
	for angle in [-38.0, 38.0]:
		var blade := _add_box(sign, "PracticeBlade", Vector3(0.0, 0.05, 0.1), Vector3(0.09, 0.92, 0.06), PALE_STONE)
		blade.rotation_degrees.z = angle
		var grip := _add_box(sign, "PracticeGrip", Vector3(0.0, -0.38, 0.1), Vector3(0.16, 0.28, 0.08), LEATHER)
		grip.rotation_degrees.z = angle
	var shield := _add_cylinder(sign, "TrainingShield", Vector3(0.0, 0.0, 0.14), 0.27, 0.08, CLOTH_RED, Vector3(90.0, 0.0, 0.0))
	shield.scale = Vector3(0.86, 1.0, 1.0)


func _add_drill_marking(parent: Node3D, node_name: String, center: Vector3, color: Color, workstation_id: String) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	root.set_meta("workstation_id", workstation_id)
	root.set_meta("authority_role", "authoritative_workstation_ground_marking")
	parent.add_child(root)
	for side in [-1.0, 1.0]:
		_add_box(root, "SideBoundary", Vector3(side * 1.35, 0.102, 0.0), Vector3(0.055, 0.018, 2.7), color)
		_add_box(root, "EndBoundary", Vector3(0.0, 0.102, side * 1.35), Vector3(2.7, 0.018, 0.055), color)
	_add_box(root, "FacingTick", Vector3(0.0, 0.105, -1.05), Vector3(0.48, 0.022, 0.09), color.lightened(0.12))


func _add_command_marking(parent: Node3D, node_name: String, center: Vector3, workstation_id: String) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	root.set_meta("workstation_id", workstation_id)
	root.set_meta("authority_role", "authoritative_instructor_ground_marking")
	parent.add_child(root)
	_add_box(root, "CommandStone", Vector3(0.0, 0.095, 0.0), Vector3(1.1, 0.055, 1.1), STONE)
	for angle in [0.0, 45.0]:
		var line := _add_box(root, "CommandCross", Vector3(0.0, 0.132, 0.0), Vector3(0.72, 0.022, 0.09), PALE_STONE)
		line.rotation_degrees.y = angle


func _add_level_two_shield_wall(parent: Node3D) -> void:
	var wall := Node3D.new()
	wall.name = "LevelTwoShieldWall"
	wall.position = Vector3(-5.85, 0.0, 6.72)
	wall.set_meta("authority_role", "non_workstation_training_efficiency_symbol")
	parent.add_child(wall)
	_add_box(wall, "ShieldRail", Vector3(0.0, 1.0, 0.0), Vector3(1.45, 0.16, 0.16), DARK_WOOD)
	for x in [-0.52, 0.0, 0.52]:
		_add_scene_prop(wall, "PracticeShield", WOODEN_SHIELD, Vector3(x, 0.72, -0.08), Vector3.ONE * 0.6, Vector3(0.0, 0.0, float(int((x + 0.52) * 12.0) - 6)))


func _add_archery_safety_net(parent: Node3D) -> void:
	var net := Node3D.new()
	net.name = "LevelTwoArcherySafetyNet"
	net.position = Vector3(6.5, 0.0, 0.0)
	net.set_meta("authority_role", "non_workstation_safety_symbol")
	parent.add_child(net)
	for z in [-1.35, 1.35]:
		_add_box(net, "NetPost", Vector3(0.0, 1.35, z), Vector3(0.18, 2.7, 0.18), DARK_WOOD)
	for y in [0.35, 0.85, 1.35, 1.85, 2.35]:
		_add_box(net, "HorizontalCord", Vector3(-0.08, y, 0.0), Vector3(0.035, 0.025, 2.6), LEATHER)
	for z in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		_add_box(net, "VerticalCord", Vector3(-0.08, 1.35, z), Vector3(0.035, 2.2, 0.025), LEATHER)


func _add_protective_gear_storage(parent: Node3D) -> void:
	var gear := Node3D.new()
	gear.name = "LevelTwoProtectiveGearStorage"
	gear.position = Vector3(-5.72, 0.0, 0.55)
	gear.set_meta("authority_role", "non_workstation_training_efficiency_symbol")
	parent.add_child(gear)
	_add_scene_prop(gear, "ProtectiveGearCrate", CRATE, Vector3(0.0, 0.14, 0.0), Vector3.ONE * 0.46)
	for y in [0.55, 0.88, 1.21]:
		_add_box(gear, "LeatherPad", Vector3(-0.38, y, 0.0), Vector3(0.42, 0.16, 0.68), LEATHER.lightened((y - 0.55) * 0.08))


func _add_second_command_post_support(parent: Node3D) -> void:
	var support := Node3D.new()
	support.name = "SecondInstructorCommandSupport"
	support.position = Vector3(-6.25, 0.0, 5.0)
	support.set_meta("workstation_id", "training_instructor_02")
	parent.add_child(support)
	for z in [-1.45, 1.45]:
		_add_box(support, "OuterCommandPost", Vector3(0.0, 1.45, z), Vector3(0.2, 2.6, 0.2), DARK_WOOD)
	_add_box(support, "CommandRail", Vector3(0.0, 1.3, 0.0), Vector3(0.18, 1.65, 2.65), OAK)
	_add_box(support, "TacticsBoard", Vector3(0.28, 1.42, 0.0), Vector3(0.12, 1.15, 1.65), Color("#a08c68"))
	for y in [1.1, 1.42, 1.74]:
		_add_box(support, "TacticsLine", Vector3(0.355, y, 0.0), Vector3(0.025, 0.045, 1.2), CLOTH_RED)


func _add_advanced_weapon_storage(parent: Node3D) -> void:
	var storage := Node3D.new()
	storage.name = "LevelThreeAdvancedWeaponStorage"
	storage.position = Vector3(5.78, 0.0, 6.72)
	storage.set_meta("authority_role", "non_workstation_equipment_display")
	parent.add_child(storage)
	_add_scene_prop(storage, "AdvancedWeaponStand", WEAPON_STAND, Vector3(0.0, 0.0, 0.0), Vector3.ONE * 0.72, Vector3(0.0, -90.0, 0.0))
	_add_practice_sword(storage, "ReserveSword", Vector3(-0.38, 0.82, -0.12), 9.0, 0.72)
	_add_scene_prop(storage, "ReserveShield", WOODEN_SHIELD, Vector3(0.32, 0.72, -0.2), Vector3.ONE * 0.58)


func _add_level_three_entry_honours(parent: Node3D) -> void:
	var honours := Node3D.new()
	honours.name = "LevelThreeEntryHonours"
	honours.set_meta("authority_role", "non_workstation_level_identity")
	parent.add_child(honours)
	for side in [-1.0, 1.0]:
		_add_box(honours, "HonourPole", Vector3(side * 2.05, 1.65, 7.45), Vector3(0.13, 3.0, 0.13), DARK_WOOD)
		_add_box(honours, "HonourPennant", Vector3(side * 2.35, 2.65, 7.45), Vector3(0.55, 0.46, 0.055), CLOTH_RED if side < 0.0 else CLOTH_BLUE)


func _add_drill_pennant(parent: Node3D, center: Vector3, color: Color) -> void:
	_add_box(parent, "PennantPole", center - Vector3(0.0, 0.65, 0.0), Vector3(0.1, 2.4, 0.1), DARK_WOOD)
	var cloth := _add_box(parent, "DrillPennant", center + Vector3(0.28, 0.18, 0.0), Vector3(0.54, 0.44, 0.055), color)
	cloth.rotation_degrees.z = -4.0


func _add_practice_sword(parent: Node3D, node_name: String, center: Vector3, rotation_z: float, length: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	root.rotation_degrees.z = rotation_z
	parent.add_child(root)
	_add_box(root, "WoodenBlade", Vector3(0.0, length * 0.18, 0.0), Vector3(0.1, length, 0.07), PALE_STONE)
	_add_box(root, "CrossGuard", Vector3(0.0, -length * 0.3, 0.0), Vector3(0.35, 0.08, 0.09), IRON)
	_add_box(root, "LeatherGrip", Vector3(0.0, -length * 0.48, 0.0), Vector3(0.11, length * 0.28, 0.09), LEATHER)


func _add_palisade_run(parent: Node3D, center: Vector3, length: float, along_z: bool) -> void:
	var post_count := maxi(2, int(ceil(length / 1.55)) + 1)
	for index in range(post_count):
		var offset := -length * 0.5 + length * float(index) / float(post_count - 1)
		var position_value := center + (Vector3(0.0, 0.82, offset) if along_z else Vector3(offset, 0.82, 0.0))
		_add_box(parent, "PalisadePost", position_value, Vector3(0.19, 1.55, 0.19), DARK_WOOD)
	for rail_height in [0.45, 0.92]:
		_add_box(parent, "PalisadeRail", center + Vector3(0.0, rail_height, 0.0), Vector3(0.14, 0.16, length) if along_z else Vector3(length, 0.16, 0.14), WEATHERED_WOOD)


func _add_training_lamp_post(parent: Node3D, lantern_name: String, position_value: Vector3, inward_yaw: float, required_level: int) -> void:
	var mount := Node3D.new()
	# 支撑节点不能以灯具名开头，否则按前缀解析灯具时会被误认为第二盏灯。
	mount.name = "Support_%s" % lantern_name
	mount.position = position_value
	mount.rotation_degrees.y = inward_yaw
	mount.set_meta("functional_lantern_support", true)
	mount.set_meta("functional_lantern_required_level", required_level)
	parent.add_child(mount)
	_add_box(mount, "ReinforcedPost", Vector3(0.0, 1.22, 0.0), Vector3(0.24, 2.44, 0.24), DARK_WOOD)
	_add_box(mount, "IronPostCap", Vector3(0.0, 2.44, 0.0), Vector3(0.34, 0.15, 0.34), IRON)
	_add_box(mount, "LanternCrossArm", Vector3(0.0, 2.22, 0.3), Vector3(0.14, 0.14, 0.74), OAK)
	var lantern := _add_scene_prop(mount, lantern_name, LANTERN, Vector3(0.0, 2.02, 0.53), Vector3.ONE * 0.58)
	if lantern != null:
		lantern.set_meta("mounted_to_structure", true)
		lantern.set_meta("mount_surface", "training_reinforced_lamp_post")
		lantern.set_meta("functional_lantern_required_level", required_level)


func _apply_functional_lantern_level_visibility() -> void:
	for raw_node in find_children("*", "Node3D", true, false):
		var node := raw_node as Node3D
		if node != null and node.has_meta("functional_lantern_required_level"):
			node.visible = int(node.get_meta("functional_lantern_required_level", 1)) <= _building_level
	if is_inside_tree():
		get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "building_functional_light_controller", "debug_force_refresh")


func _add_boot_mark(parent: Node3D, center: Vector3, angle: float) -> void:
	var mark := _add_box(parent, "BootMark", center, Vector3(0.16, 0.012, 0.36), DARK_EARTH)
	mark.rotation_degrees.y = angle


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


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	_material_cache[key] = material
	return material
