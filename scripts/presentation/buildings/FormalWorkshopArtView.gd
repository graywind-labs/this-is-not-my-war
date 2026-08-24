class_name FormalWorkshopArtView
extends BuildingArtView


const WALL_STRAIGHT := "res://assets/3d/quaternius/buildings/wall_plaster_straight.glb"
const WALL_DOOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round.glb"
const FLOOR_DARK := "res://assets/3d/quaternius/buildings/floor_wood_dark.glb"
const ROOF_TILES := "res://assets/3d/quaternius/buildings/roof_round_tiles_4x4.glb"
const CRATE := "res://assets/3d/quaternius/props/crate_wooden.glb"
const BARREL := "res://assets/3d/quaternius/props/barrel.glb"
const PEG_RACK := "res://assets/3d/quaternius/props/peg_rack.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const WEAPON_STAND := "res://assets/3d/quaternius/props/weapon_stand.glb"
const WORKSHOP_SHELF := "res://assets/3d/quaternius/props/workshop_shelf.glb"
const WORKSHOP_ROPE := "res://assets/3d/quaternius/props/workshop_rope.glb"
const AUTO_DOOR_SCRIPT := preload("res://scripts/presentation/buildings/BuildingAutoDoor.gd")

const BUILDING_FOOTPRINT := Vector2(12.0, 12.0)
const INTERIOR_CLEAR_SIZE := Vector2(11.15, 11.15)

var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_formal_workshop()
	super._ready()


func _apply_visual_level(level: int, upgrade_in_progress: bool) -> void:
	super._apply_visual_level(level, upgrade_in_progress)
	_apply_external_fixture_level_visibility()


func get_art_slice_snapshot() -> Dictionary:
	var door_snapshot: Dictionary = {}
	var auto_door := get_node_or_null("Exterior/AutoDoor")
	if auto_door != null and auto_door.has_method("debug_get_snapshot"):
		door_snapshot = auto_door.call("debug_get_snapshot")
	var workstation_states := {}
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
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"upgrade_in_progress": _upgrade_in_progress,
		"level_2_visible": _is_visible(NodePath("UpgradeVisuals/Level2")),
		"level_3_visible": _is_visible(NodePath("UpgradeVisuals/Level3")),
		"workstations": workstation_states,
		"auto_door": door_snapshot,
		"active_fixture_visual_count": _active_fixture_visual_count(),
		"active_fixture_collision_count": _active_fixture_collision_count(),
		"level_visual_addition_counts": {
			"level_1": _mesh_count_at("Interior/Level1Details"),
			"level_2": _mesh_count_at("UpgradeVisuals/Level2"),
			"level_3": _mesh_count_at("UpgradeVisuals/Level3")
		},
		"building_footprint": BUILDING_FOOTPRINT,
		"interior_clear_size": INTERIOR_CLEAR_SIZE,
		"future_capacity_reserved": true,
		"roof_profile": "quaternius_low_pitch_round_tile_workshop",
		"roof_albedo_override": roof_albedo_override,
		"roof_mesh_count": _roof_meshes.size(),
		"roof_structure_addition_count": (
			_mesh_count_at("UpgradeVisuals/Level2/RoofStructureAdditions")
			+ _mesh_count_at("UpgradeVisuals/Level3/RoofStructureAdditions")
		),
		"roof_structure_additions_fade_with_roof": additional_roof_fade_paths.size() == 2,
		"exterior_material_count": _exterior_materials.size(),
		"interior_revealed_for_selection": is_interior_revealed_for_selection(),
		"shell_opacity": maxf(_roof_opacity, _exterior_opacity),
		"navigation_ready": _formal_navigation_ready(),
		"collision_authority": "formal_station_static_and_level_synced_fixture_collision",
		"navigation_authority": "formal_station_navigation_mesh",
		"authority_role": "presentation_only"
	}


func _build_formal_workshop() -> void:
	building_id = "workshop"
	roof_near_distance = 58.0
	roof_far_distance = 70.0
	minimum_roof_opacity = 0.06
	fade_exterior_with_roof = true
	minimum_exterior_opacity = 0.06
	interior_reveal_opacity_threshold = 0.72
	interaction_bounds_center = Vector3(0.0, 2.65, 0.0)
	interaction_bounds_size = Vector3(14.5, 6.0, 14.5)
	roof_albedo_override = Color("#596782")
	preserve_roof_albedo_texture = false
	exterior_albedo_tint = Color("#aeb9c7")
	static_collision_path = NodePath("../StaticCollision")
	workstation_markers_path = NodePath("../FixtureLayout/NPCStands")
	set_meta("art_revision", "t0131_p1d")
	set_meta("formal_vertical_slice", true)
	set_meta("footprint_meters", BUILDING_FOOTPRINT)
	set_meta("upgrade_visual_authority", "building_system_level")
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
	_add_box(interior, "StoneFoundation", Vector3(0.0, 0.11, 0.0), Vector3(11.9, 0.22, 11.9), Color("#4b4e55"))
	var floor := Node3D.new()
	floor.name = "Floor"
	interior.add_child(floor)
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		for z in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
			_add_scene_prop(floor, "DarkWoodFloor", FLOOR_DARK, Vector3(x, 0.14, z), Vector3(1.0, 0.22, 1.0))
	_add_box(interior, "CentralAssemblyLane", Vector3(0.0, 0.175, 0.4), Vector3(1.7, 0.035, 9.8), Color("#59616b"))


func _build_exterior() -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	for x in [-5.0, -3.0, 3.0, 5.0]:
		_add_scene_prop(exterior, "FrontWall", WALL_STRAIGHT, Vector3(x, 0.2, 6.0), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 180.0, 0.0))
	for x in [-1.5, 1.5]:
		_add_scene_prop(exterior, "FrontWallNarrow", WALL_STRAIGHT, Vector3(x, 0.2, 6.0), Vector3(0.5, 1.0, 1.0), Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(exterior, "FrontDoor", WALL_DOOR, Vector3(0.0, 0.2, 6.0), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 180.0, 0.0))
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		_add_scene_prop(exterior, "RearWall", WALL_STRAIGHT, Vector3(x, 0.2, -6.0), Vector3(1.0, 1.0, 1.0))
	for side in [-1.0, 1.0]:
		for z in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
			_add_scene_prop(
				exterior,
				"SideWall",
				WALL_STRAIGHT,
				Vector3(side * 6.0, 0.2, z),
				Vector3(1.0, 1.0, 1.0),
				Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0)
			)
	var dark_timber := Color("#3b3437")
	for x in [-5.85, -3.0, 3.0, 5.85]:
		_add_box(exterior, "FrontPost", Vector3(x, 1.7, 6.12), Vector3(0.24, 3.25, 0.26), dark_timber)
		_add_box(exterior, "RearPost", Vector3(x, 1.7, -6.12), Vector3(0.24, 3.25, 0.26), dark_timber)
	for x in [-1.15, 1.15]:
		var jamb_name := "DoorJambLeft" if x < 0.0 else "DoorJambRight"
		_add_box(exterior, jamb_name, Vector3(x, 1.7, 6.12), Vector3(0.22, 3.25, 0.26), dark_timber)
	for side in [-1.0, 1.0]:
		for z in [-4.5, 0.0, 4.5]:
			_add_box(exterior, "SidePost", Vector3(side * 6.12, 1.7, z), Vector3(0.26, 3.25, 0.24), dark_timber)
	_add_box(exterior, "FrontLintel", Vector3(0.0, 3.18, 6.11), Vector3(12.2, 0.28, 0.28), dark_timber)
	_add_box(exterior, "RearLintel", Vector3(0.0, 3.18, -6.11), Vector3(12.2, 0.28, 0.28), dark_timber)
	_add_box(exterior, "WorkshopSign", Vector3(0.0, 3.64, 6.23), Vector3(2.45, 0.62, 0.14), Color("#45536b"))
	_add_box(exterior, "CompassBar", Vector3(0.0, 3.66, 6.32), Vector3(1.0, 0.11, 0.12), Color("#222a34"))
	_add_box(exterior, "CompassStem", Vector3(0.0, 3.66, 6.32), Vector3(0.11, 0.72, 0.12), Color("#222a34"))
	var auto_door := Node3D.new()
	auto_door.name = "AutoDoor"
	auto_door.position = Vector3(0.0, 0.2, 6.2)
	auto_door.set_script(AUTO_DOOR_SCRIPT)
	auto_door.call("configure", Color("#52627b"), Color("#37343a"), Color("#788590"))
	exterior.add_child(auto_door)


func _build_roof() -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.set_meta("roof_fade_candidate", true)
	add_child(roof)
	_add_scene_prop(roof, "RoundTileRoof", ROOF_TILES, Vector3(0.0, 3.2, 0.0), Vector3(2.82, 0.55, 2.82))
	var ridge_color := Color("#30394d")
	_add_box(roof, "ColdRidgeCap", Vector3(0.0, 4.05, 0.0), Vector3(12.4, 0.2, 0.28), ridge_color)
	for x in [-5.7, -2.85, 0.0, 2.85, 5.7]:
		_add_box(roof, "RafterCap", Vector3(x, 3.45, 0.0), Vector3(0.09, 0.12, 12.0), ridge_color)
	# A low roof monitor makes the silhouette read as a ventilated engineering shop,
	# while remaining part of the same fade group as the roof shell.
	_add_box(roof, "MonitorBase", Vector3(0.0, 4.12, -0.2), Vector3(4.8, 0.48, 1.05), Color("#3d485d"))
	_add_box(roof, "MonitorNorthWindow", Vector3(0.0, 4.15, -0.74), Vector3(4.25, 0.25, 0.06), Color("#70869a"))
	_add_box(roof, "MonitorSouthWindow", Vector3(0.0, 4.15, 0.34), Vector3(4.25, 0.25, 0.06), Color("#70869a"))
	_add_box(roof, "MonitorCap", Vector3(0.0, 4.42, -0.2), Vector3(5.2, 0.16, 1.35), Color("#2d3648"))


func _build_level_one_details() -> void:
	var interior := get_node("Interior") as Node3D
	var details := Node3D.new()
	details.name = "Level1Details"
	interior.add_child(details)
	_add_scene_prop(details, "FrontLanternLeft", LANTERN, Vector3(-2.2, 2.42, 5.65), Vector3.ONE * 0.72, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(details, "FrontLanternRight", LANTERN, Vector3(2.2, 2.42, 5.65), Vector3.ONE * 0.72, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(details, "PartsCrate", CRATE, Vector3(5.05, 0.18, 4.65), Vector3.ONE * 0.68, Vector3(0.0, 16.0, 0.0))
	_add_scene_prop(details, "OilBarrel", BARREL, Vector3(5.25, 0.18, 2.35), Vector3.ONE * 0.82)
	_add_scene_prop(details, "HandToolRack", PEG_RACK, Vector3(-5.55, 0.2, 1.9), Vector3.ONE * 0.88, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(details, "SparePartsShelf", WORKSHOP_SHELF, Vector3(-5.48, 0.18, -2.25), Vector3.ONE * 0.76, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(details, "FastenerShelf", WORKSHOP_SHELF, Vector3(5.48, 0.18, -2.25), Vector3.ONE * 0.76, Vector3(0.0, -90.0, 0.0))
	_add_scene_prop(details, "BenchRopeCoilLeft", WORKSHOP_ROPE, Vector3(-5.15, 0.2, -4.65), Vector3.ONE * 0.68, Vector3(0.0, 28.0, 0.0))
	_add_scene_prop(details, "BenchRopeCoilRight", WORKSHOP_ROPE, Vector3(5.05, 0.2, -4.55), Vector3.ONE * 0.62, Vector3(0.0, -24.0, 0.0))
	_add_scene_prop(details, "SmallPartsCrate", CRATE, Vector3(-5.0, 0.18, 3.35), Vector3.ONE * 0.52, Vector3(0.0, -18.0, 0.0))
	_add_scene_prop(details, "RivetBarrel", BARREL, Vector3(-5.15, 0.18, 4.15), Vector3.ONE * 0.58)
	var component_bins := Node3D.new()
	component_bins.name = "ComponentBins"
	component_bins.position = Vector3(5.35, 0.22, 0.15)
	component_bins.rotation_degrees.y = -90.0
	details.add_child(component_bins)
	for index in range(3):
		_add_box(component_bins, "OpenPartsBin", Vector3(-0.62 + float(index) * 0.62, 0.32, 0.0), Vector3(0.52, 0.48, 0.7), Color("#51463e"))
		_add_box(component_bins, "MetalOffcuts", Vector3(-0.62 + float(index) * 0.62, 0.6, 0.0), Vector3(0.32, 0.07, 0.45), Color("#737982"))
	var stock := Node3D.new()
	stock.name = "SharedStockDetails"
	stock.position = Vector3(-3.8, 0.0, 4.7)
	details.add_child(stock)
	for index in range(5):
		var z_offset := -0.34 + float(index) * 0.17
		_add_box(stock, "TimberBlank", Vector3(-0.1, 0.54 + float(index % 2) * 0.12, z_offset), Vector3(2.5, 0.12, 0.12), Color("#6c5039"))
	for index in range(4):
		_add_box(stock, "IronRod", Vector3(-0.1, 0.92 + float(index) * 0.08, -0.28 + float(index) * 0.18), Vector3(2.2, 0.07, 0.07), Color("#646b75"))
	var plan_board := Node3D.new()
	plan_board.name = "OrderBoard"
	plan_board.position = Vector3(5.72, 1.55, -1.8)
	plan_board.rotation_degrees.y = -90.0
	details.add_child(plan_board)
	_add_box(plan_board, "WoodBack", Vector3.ZERO, Vector3(1.55, 1.05, 0.08), Color("#584333"))
	_add_box(plan_board, "Parchment", Vector3(0.0, 0.05, 0.05), Vector3(1.2, 0.78, 0.025), Color("#c5b693"))
	for offset in [-0.35, 0.0, 0.35]:
		_add_box(plan_board, "DraftLine", Vector3(offset, 0.06, 0.075), Vector3(0.035, 0.6, 0.01), Color("#526478"))


func _build_upgrade_visuals() -> void:
	var upgrades := Node3D.new()
	upgrades.name = "UpgradeVisuals"
	add_child(upgrades)

	var level_2 := Node3D.new()
	level_2.name = "Level2"
	level_2.visible = false
	upgrades.add_child(level_2)
	var level_2_exterior := Node3D.new()
	level_2_exterior.name = "ExteriorAdditions"
	level_2.add_child(level_2_exterior)
	# Lv.2 adds a material receiving point instead of a ceremonial doorway frame.
	# It remains offset from the entrance and reads as storage plus hoisting equipment.
	_add_scene_prop(level_2_exterior, "ReceivingShelf", WORKSHOP_SHELF, Vector3(3.9, 0.18, 6.48), Vector3.ONE * 0.78, Vector3(0.0, 180.0, 0.0))
	_add_scene_prop(level_2_exterior, "ReceivingRope", WORKSHOP_ROPE, Vector3(2.75, 0.2, 6.58), Vector3.ONE * 0.66, Vector3(0.0, 12.0, 0.0))
	_add_scene_prop(level_2_exterior, "ReceivingCrate", CRATE, Vector3(5.12, 0.18, 6.68), Vector3.ONE * 0.58, Vector3(0.0, -12.0, 0.0))
	_add_box(level_2_exterior, "ReceivingHoistPost", Vector3(2.55, 1.55, 6.72), Vector3(0.22, 3.0, 0.22), Color("#3d342e"))
	_add_box(level_2_exterior, "ReceivingHoistArm", Vector3(3.45, 2.92, 6.72), Vector3(2.0, 0.2, 0.22), Color("#3d342e"))
	var receiving_brace := _add_box(level_2_exterior, "ReceivingHoistBrace", Vector3(3.0, 2.42, 6.72), Vector3(1.4, 0.16, 0.18), Color("#4d4037"))
	receiving_brace.rotation_degrees.z = -42.0
	_add_cylinder(level_2_exterior, "ReceivingPulley", Vector3(4.18, 2.72, 6.82), 0.28, 0.16, Color("#59616a"), Vector3(90.0, 0.0, 0.0))
	_add_box(level_2_exterior, "ReceivingChain", Vector3(4.18, 2.05, 6.82), Vector3(0.06, 1.2, 0.06), Color("#454b53"))
	_add_box(level_2_exterior, "ReceivingHook", Vector3(4.18, 1.43, 6.82), Vector3(0.3, 0.12, 0.14), Color("#68717b"))

	var level_2_roof_structure := Node3D.new()
	level_2_roof_structure.name = "RoofStructureAdditions"
	level_2.add_child(level_2_roof_structure)
	_add_box(level_2_roof_structure, "OverheadTransmissionBeam", Vector3(2.1, 2.86, 0.3), Vector3(6.0, 0.24, 0.28), Color("#34343a"))
	_add_box(level_2_roof_structure, "TransmissionRail", Vector3(3.8, 2.55, -0.9), Vector3(0.12, 0.12, 3.0), Color("#59616a"))

	var level_2_interior := Node3D.new()
	level_2_interior.name = "InteriorAdditions"
	level_2.add_child(level_2_interior)
	_add_box(level_2_interior, "MeasureLampBar", Vector3(3.8, 2.45, 3.5), Vector3(2.4, 0.12, 0.12), Color("#3d424b"))
	_add_scene_prop(level_2_interior, "MeasuredPartsCrate", CRATE, Vector3(5.05, 0.18, 0.65), Vector3.ONE * 0.6, Vector3(0.0, -12.0, 0.0))
	_add_scene_prop(level_2_interior, "TransmissionRope", WORKSHOP_ROPE, Vector3(2.9, 0.2, 1.95), Vector3.ONE * 0.58, Vector3(0.0, 18.0, 0.0))

	var level_3 := Node3D.new()
	level_3.name = "Level3"
	level_3.visible = false
	upgrades.add_child(level_3)
	var level_3_interior := Node3D.new()
	level_3_interior.name = "InteriorAdditions"
	level_3.add_child(level_3_interior)
	_add_box(level_3_interior, "MasterHoistChain", Vector3(-3.6, 2.15, 0.25), Vector3(0.08, 1.45, 0.08), Color("#242a31"))
	_add_box(level_3_interior, "MasterHoistHook", Vector3(-3.6, 1.42, 0.25), Vector3(0.34, 0.13, 0.18), Color("#5e6670"))
	_add_scene_prop(level_3_interior, "FinishedDeviceStand", WEAPON_STAND, Vector3(5.25, 0.18, -0.25), Vector3.ONE * 0.8, Vector3(0.0, -90.0, 0.0))
	_add_scene_prop(level_3_interior, "MasterRiggingRope", WORKSHOP_ROPE, Vector3(-5.05, 0.2, -0.2), Vector3.ONE * 0.7, Vector3(0.0, 24.0, 0.0))

	var level_3_roof_structure := Node3D.new()
	level_3_roof_structure.name = "RoofStructureAdditions"
	level_3.add_child(level_3_roof_structure)
	_add_box(level_3_roof_structure, "MasterAssemblyTruss", Vector3(-2.6, 2.9, 0.3), Vector3(5.8, 0.28, 0.3), Color("#282f38"))

	var level_3_exterior := Node3D.new()
	level_3_exterior.name = "ExteriorAdditions"
	level_3.add_child(level_3_exterior)
	# Lv.3 grows into a compact covered assembly/loading bay on the west side.
	# Its roof stays below the main eave, so it cannot pierce the workshop roof.
	_add_box(level_3_exterior, "AssemblyBayDeck", Vector3(-6.3, 0.24, 0.7), Vector3(1.35, 0.2, 3.35), Color("#574535"))
	_add_scene_prop(level_3_exterior, "AssemblyBayRoof", ROOF_TILES, Vector3(-5.7, 2.42, 0.7), Vector3(0.78, 0.1, 0.46), Vector3(0.0, 90.0, 0.0))
	for z in [-0.67, 2.07]:
		_add_box(level_3_exterior, "AssemblyBayPost", Vector3(-6.86, 1.28, z), Vector3(0.22, 2.35, 0.22), Color("#40362f"))
		var roof_brace := _add_box(level_3_exterior, "AssemblyBayBrace", Vector3(-6.82, 2.02, z + (0.33 if z < 0.7 else -0.33)), Vector3(0.16, 0.14, 0.95), Color("#514238"))
		roof_brace.rotation_degrees.x = 42.0 if z < 0.7 else -42.0
	_add_box(level_3_exterior, "AssemblyBayFrontBeam", Vector3(-6.84, 2.4, 0.7), Vector3(0.22, 0.2, 3.0), Color("#40362f"))
	_add_scene_prop(level_3_exterior, "AssemblyBayPartsRack", WEAPON_STAND, Vector3(-6.25, 0.32, -0.2), Vector3.ONE * 0.62, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(level_3_exterior, "AssemblyBayRope", WORKSHOP_ROPE, Vector3(-6.25, 0.32, 1.35), Vector3.ONE * 0.58, Vector3(0.0, 74.0, 0.0))
	_add_scene_prop(level_3_exterior, "AssemblyBayCrate", CRATE, Vector3(-5.85, 0.32, 1.98), Vector3.ONE * 0.48, Vector3(0.0, 102.0, 0.0))
	_add_cylinder(level_3_exterior, "AssemblyBayWinch", Vector3(-6.74, 2.06, 0.7), 0.3, 0.5, Color("#59616a"), Vector3(0.0, 0.0, 90.0))
	_add_box(level_3_exterior, "AssemblyBayWinchRope", Vector3(-6.74, 1.47, 0.7), Vector3(0.06, 1.05, 0.06), Color("#4d4137"))
	_add_box(level_3_exterior, "MasterEngineerEmblem", Vector3(-6.95, 2.64, 0.7), Vector3(0.1, 0.36, 1.15), Color("#34445e"))


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


func _add_cylinder(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	radius: float,
	height: float,
	color: Color,
	rotation_degrees_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.rotation_degrees = rotation_degrees_value
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
