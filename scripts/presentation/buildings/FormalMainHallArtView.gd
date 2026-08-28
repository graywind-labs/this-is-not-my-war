class_name FormalMainHallArtView
extends BuildingArtView


const WALL_WINDOW := "res://assets/3d/quaternius/buildings/main_hall_wall_window.glb"
const WALL_DOOR := "res://assets/3d/quaternius/buildings/main_hall_wall_door.glb"
const MAIN_ROOF := "res://assets/3d/quaternius/buildings/main_hall_roof.glb"
const COMPACT_ROOF := "res://assets/3d/quaternius/buildings/roof_round_tiles_4x4.glb"
const STAIRS := "res://assets/3d/quaternius/buildings/main_hall_stairs.glb"
const SUPPORT := "res://assets/3d/quaternius/buildings/main_hall_support.glb"
const TOWER_ROOF := "res://assets/3d/quaternius/buildings/main_hall_tower_roof.glb"
const BANNER := "res://assets/3d/quaternius/props/main_hall_banner.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const SHIELD := "res://assets/3d/quaternius/props/shield_wooden.glb"

const LOT_SIZE := Vector2(24.0, 20.0)
const ENVELOPE_SIZE := Vector2(22.0, 18.0)
const MAXIMUM_LEVEL := 6
const STONE_DARK := Color("#444a51")
const STONE := Color("#626a73")
const STONE_LIGHT := Color("#858b8c")
const PLASTER := Color("#887d6c")
const PLASTER_DARK := Color("#736a5e")
const STONE_WARM := Color("#77736b")
const WOOD_DARK := Color("#382e2b")
const WOOD := Color("#60453a")
const IRON := Color("#343b42")
const ROOF_BLUE := Color("#43556a")
const BANNER_RED := Color("#7a3036")
const EMBER := Color("#e98235")
const ROCK_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_BaseColor.png"
const ROCK_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_Normal.png"
const ROCK_ORM := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_ORM.png"
const PLASTER_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_Plaster_BaseColor.png"
const PLASTER_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_Plaster_Normal.png"
const PLASTER_ORM := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_Plaster_ORM.png"
const BRICK_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_UnevenBrick_BaseColor.png"
const BRICK_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_UnevenBrick_Normal.png"
const BRICK_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_UnevenBrick_Roughness.png"

var _material_cache: Dictionary = {}
var _damage_ratio := 1.0
var _destruction_latched := false


func _ready() -> void:
	_build_formal_main_hall()
	super._ready()


func apply_roof_camera_distance(camera_distance: float, zoom_normalized: float) -> void:
	_camera_distance = camera_distance
	_zoom_normalized = zoom_normalized
	_set_roof_opacity(1.0)
	_set_exterior_opacity(1.0)


func is_interior_revealed_for_selection() -> bool:
	return false


func _refresh_building_state() -> void:
	super._refresh_building_state()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		_apply_damage_ratio(_damage_ratio)
		return
	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty():
		_apply_damage_ratio(_damage_ratio)
		return
	var maximum_hp := maxi(1, int(building.get("max_hp", 1)))
	_apply_damage_ratio(float(building.get("hp", maximum_hp)) / float(maximum_hp))
	_apply_destruction_state(bool(building.get("destruction_latched", false)))


func _apply_visual_level(level: int, upgrade_in_progress: bool) -> void:
	super._apply_visual_level(mini(level, 3), upgrade_in_progress)
	_building_level = clampi(level, 1, MAXIMUM_LEVEL)
	_upgrade_in_progress = upgrade_in_progress
	for visual_level in range(2, MAXIMUM_LEVEL + 1):
		var level_root := get_node_or_null("UpgradeVisuals/Level%d" % visual_level) as Node3D
		if level_root != null:
			level_root.visible = _building_level >= visual_level
	var front_gatehouse_roof := get_node_or_null("Roof/FrontGatehouseRoof") as Node3D
	if front_gatehouse_roof != null:
		front_gatehouse_roof.visible = _building_level < 6
	_apply_external_fixture_level_visibility()


func debug_force_visual_level(level: int) -> Dictionary:
	_apply_visual_level(clampi(level, 1, MAXIMUM_LEVEL), false)
	return get_art_slice_snapshot()


func debug_force_damage_ratio(ratio: float) -> Dictionary:
	_apply_damage_ratio(ratio)
	return get_art_slice_snapshot()


func get_art_slice_snapshot() -> Dictionary:
	var level_counts: Dictionary = {}
	for visual_level in range(1, MAXIMUM_LEVEL + 1):
		var path := "BaseVisuals" if visual_level == 1 else "UpgradeVisuals/Level%d" % visual_level
		level_counts["level_%d" % visual_level] = _mesh_count_at(path)
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"maximum_level": MAXIMUM_LEVEL,
		"lot_size": LOT_SIZE,
		"envelope_size": ENVELOPE_SIZE,
		"non_enterable": true,
		"interior_revealed_for_selection": is_interior_revealed_for_selection(),
		"roof_opacity": _roof_opacity,
		"damage_ratio": _damage_ratio,
		"destruction_latched": _destruction_latched,
		"ruin_visible": _is_visible(NodePath("DestroyedRuin")),
		"mild_damage_visible": _is_visible(NodePath("DamageVisuals/Mild")),
		"heavy_damage_visible": _is_visible(NodePath("DamageVisuals/Heavy")),
		"active_fixture_visual_count": _active_fixture_visual_count(),
		"active_fixture_collision_count": _active_fixture_collision_count(),
		"level_visual_addition_counts": level_counts,
		"defense_slot_capacity_profile": [1, 1, 2, 2, 3, 4],
		"fixture_visibility_profile": [1, 2, 3, 4, 5, 7],
		"solid_textured_mass": true,
		"load_bearing_roof_deck": true,
		"defense_platform_local_centers": [Vector2(-7.0, -5.0), Vector2(7.0, -5.0), Vector2(-7.0, 5.0), Vector2(7.0, 5.0)],
		"defense_platform_clear_size": Vector2(3.6, 3.6),
		"architectural_style": "fortified_border_command_hall_with_roof_deck_and_compact_keep",
		"level_profile": "solid_command_hall_wall_bracing_second_platform_roof_signal_third_platform_front_tower",
		"collision_authority": "formal_station_static_and_level_synced_fixture_collision",
		"building_state_authority": "building_system_read_only_projection",
		"defense_authority": "defense_device_system_only",
		"authority_role": "presentation_only"
	}


func _build_formal_main_hall() -> void:
	building_id = "main_hall"
	roof_path = NodePath("Roof")
	exterior_path = NodePath("BaseVisuals/Exterior")
	static_collision_path = NodePath("../StaticCollision")
	workstation_markers_path = NodePath("../FixtureLayout/NPCStands")
	preserve_roof_albedo_texture = true
	roof_albedo_override = ROOF_BLUE
	exterior_albedo_tint = Color.WHITE
	fade_exterior_with_roof = false
	interaction_bounds_center = Vector3(0.0, 3.2, 0.0)
	interaction_bounds_size = Vector3(22.0, 7.4, 18.0)
	set_meta("art_revision", "t0132_p1r5")
	set_meta("visible_shell", "closed_textured_quaternius_composite")
	set_meta("solid_visual_mass", true)
	set_meta("load_bearing_roof_deck", true)
	set_meta("formal_vertical_slice", true)
	set_meta("non_enterable", true)
	set_meta("lot_size_meters", LOT_SIZE)
	set_meta("envelope_size_meters", ENVELOPE_SIZE)
	set_meta("maximum_level", MAXIMUM_LEVEL)
	_build_base_visuals()
	_build_upgrade_visuals()
	_build_damage_visuals()
	_build_destroyed_ruin()
	_apply_destruction_state(false)


func _build_base_visuals() -> void:
	var base := Node3D.new()
	base.name = "BaseVisuals"
	add_child(base)
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	base.add_child(exterior)
	var roof := Node3D.new()
	roof.name = "Roof"
	add_child(roof)

	_add_textured_box(exterior, "FortifiedPlinth", Vector3(0.0, 0.22, 0.0), Vector3(21.4, 0.44, 17.35), "rock", Color("#5f6265"), 0.55)
	_build_solid_command_mass(exterior)
	_build_textured_facade_modules(exterior)
	_build_defense_roof_terrace(exterior)
	_add_box(exterior, "WestTimberBand", Vector3(-6.0, 2.85, 7.58), Vector3(7.7, 0.23, 0.18), WOOD_DARK)
	_add_box(exterior, "EastTimberBand", Vector3(6.0, 2.85, 7.58), Vector3(7.7, 0.23, 0.18), WOOD_DARK)
	_add_box(exterior, "CentralLintel", Vector3(0.0, 3.05, 7.63), Vector3(4.7, 0.3, 0.2), WOOD_DARK)
	_add_box(exterior, "FrontLanding", Vector3(0.0, 0.22, 8.43), Vector3(5.2, 0.44, 0.9), STONE_DARK)
	_add_scene_prop(exterior, "FrontStairs", STAIRS, Vector3(0.0, 0.0, 8.1), Vector3(2.3, 1.0, 0.75), Vector3(0.0, 180.0, 0.0))

	for side in [-1.0, 1.0]:
		_add_scene_prop(exterior, "CommandBanner", BANNER, Vector3(side * 2.05, 3.55, 7.9), Vector3.ONE * 0.72, Vector3(0.0, 180.0, 0.0))
		_add_main_hall_entry_lantern(exterior, "GateLanternWest" if side < 0.0 else "GateLanternEast", side)
		_add_scene_prop(exterior, "CommandShield", SHIELD, Vector3(0.0, 2.48, 7.98), Vector3.ONE * 0.78, Vector3(0.0, 180.0, 0.0))
	_build_front_timber_frame(exterior)
	_build_gatehouse_stone_detail(exterior)

	_add_scene_prop(roof, "CentralKeepRoof", COMPACT_ROOF, Vector3(0.0, 4.62, 0.0), Vector3(1.42, 0.50, 1.0))
	_add_scene_prop(roof, "FrontGatehouseRoof", MAIN_ROOF, Vector3(0.0, 3.68, 6.72), Vector3(0.50, 0.22, 0.20))


func _build_solid_command_mass(parent: Node3D) -> void:
	var mass := Node3D.new()
	mass.name = "SolidMainHallMass"
	mass.set_meta("closed_visual_volume", true)
	mass.set_meta("texture_authority", "quaternius_extracted_pbr_textures")
	parent.add_child(mass)
	_add_textured_box(mass, "LowerMasonryCore", Vector3(0.0, 0.82, 0.0), Vector3(20.25, 1.2, 15.65), "rock", Color("#676b6c"), 0.48)
	_add_textured_box(mass, "PlasterCommandBody", Vector3(0.0, 2.02, 0.0), Vector3(19.9, 1.85, 15.35), "plaster", Color("#a89d88"), 0.52)
	_add_textured_box(mass, "RoofBearingDeck", Vector3(0.0, 2.84, 0.0), Vector3(20.55, 0.34, 16.1), "brick", Color("#77797b"), 0.58)

	var keep := Node3D.new()
	keep.name = "CentralCommandKeep"
	keep.set_meta("closed_visual_volume", true)
	mass.add_child(keep)
	_add_textured_box(keep, "KeepMasonryCore", Vector3(0.0, 3.68, 0.0), Vector3(8.0, 1.35, 5.35), "plaster", Color("#9d927e"), 0.58)
	_add_textured_box(keep, "KeepStoneBelt", Vector3(0.0, 3.18, 0.0), Vector3(8.25, 0.28, 5.58), "rock", Color("#696d70"), 0.5)
	for index in range(4):
		var x := -3.0 + float(index) * 2.0
		_add_scene_prop(keep, "KeepFrontWall_%02d" % (index + 1), WALL_WINDOW, Vector3(x, 3.02, 2.75), Vector3(1.0, 0.44, 1.0), Vector3(0.0, 180.0, 0.0))
		_add_scene_prop(keep, "KeepRearWall_%02d" % (index + 1), WALL_WINDOW, Vector3(x, 3.02, -2.75), Vector3(1.0, 0.44, 1.0))
	for side in [-1.0, 1.0]:
		for index in range(3):
			_add_scene_prop(
				keep,
				"KeepSide_%s_%02d" % [("West" if side < 0.0 else "East"), index + 1],
				WALL_WINDOW,
				Vector3(side * 4.05, 3.02, -1.82 + float(index) * 1.82),
				Vector3(0.91, 0.44, 1.0),
				Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0)
			)


func _build_textured_facade_modules(parent: Node3D) -> void:
	var shell := Node3D.new()
	shell.name = "TexturedFacadeModules"
	shell.set_meta("shell_material_authority", "quaternius_native_textures")
	parent.add_child(shell)
	for index in range(11):
		var x := -10.0 + float(index) * 2.0
		var front_asset := WALL_DOOR if index == 5 else WALL_WINDOW
		var front_name := "FrontDoor" if index == 5 else "OuterFrontWall_%02d" % (index + 1)
		_add_scene_prop(shell, front_name, front_asset, Vector3(x, 0.0, 7.72), Vector3.ONE, Vector3(0.0, 180.0, 0.0))
		_add_scene_prop(shell, "OuterRearWall_%02d" % (index + 1), WALL_WINDOW, Vector3(x, 0.0, -7.72))
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		for index in range(7):
			var z := -6.72 + float(index) * 2.24
			_add_scene_prop(
				shell,
				"Outer%sWall_%02d" % [side_name, index + 1],
				WALL_WINDOW,
				Vector3(side * 10.15, 0.0, z),
				Vector3(1.12, 1.0, 1.0),
				Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0)
			)


func _build_defense_roof_terrace(parent: Node3D) -> void:
	var terrace := Node3D.new()
	terrace.name = "LoadBearingDefenseTerrace"
	terrace.set_meta("supports_formal_defense_platforms", true)
	terrace.set_meta("platform_clearance_meters", Vector2(3.6, 3.6))
	parent.add_child(terrace)
	for side in [-1.0, 1.0]:
		_add_textured_box(terrace, "SideAccessLane", Vector3(side * 7.0, 3.025, 0.0), Vector3(3.8, 0.05, 6.2), "brick", Color("#77797b"), 0.62)
	_add_textured_box(terrace, "RearParapet", Vector3(0.0, 3.24, -7.88), Vector3(20.5, 0.46, 0.28), "rock", Color("#6e7376"), 0.5)
	_add_textured_box(terrace, "FrontParapet", Vector3(0.0, 3.24, 7.88), Vector3(20.5, 0.46, 0.28), "rock", Color("#6e7376"), 0.5)
	_add_textured_box(terrace, "WestParapet", Vector3(-10.12, 3.24, 0.0), Vector3(0.28, 0.46, 15.5), "rock", Color("#6e7376"), 0.5)
	_add_textured_box(terrace, "EastParapet", Vector3(10.12, 3.24, 0.0), Vector3(0.28, 0.46, 15.5), "rock", Color("#6e7376"), 0.5)
	for x in [-9.0, -7.0, -5.0, -3.0, -1.0, 1.0, 3.0, 5.0, 7.0, 9.0]:
		_add_textured_box(terrace, "RearMerlon", Vector3(x, 3.61, -7.84), Vector3(1.0, 0.72, 0.5), "rock", Color("#74797c"), 0.48)
		_add_textured_box(terrace, "FrontMerlon", Vector3(x, 3.61, 7.84), Vector3(1.0, 0.72, 0.5), "rock", Color("#74797c"), 0.48)
	for z in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
		_add_textured_box(terrace, "WestMerlon", Vector3(-10.08, 3.61, z), Vector3(0.5, 0.72, 1.0), "rock", Color("#74797c"), 0.48)
		_add_textured_box(terrace, "EastMerlon", Vector3(10.08, 3.61, z), Vector3(0.5, 0.72, 1.0), "rock", Color("#74797c"), 0.48)


func _build_front_timber_frame(parent: Node3D) -> void:
	var front_post_positions := [-9.55, -7.7, -5.85, -4.0, -2.62, 2.62, 4.0, 5.85, 7.7, 9.55]
	for index in range(front_post_positions.size()):
		_add_box(parent, "FrontTimberPost_%02d" % (index + 1), Vector3(front_post_positions[index], 1.92, 7.7), Vector3(0.18, 2.45, 0.18), WOOD_DARK)
	for segment_center in [-8.62, -6.77, -4.92, 4.92, 6.77, 8.62]:
		var direction := -1.0 if int(round(abs(segment_center) * 10.0)) % 2 == 0 else 1.0
		var brace := _add_box(parent, "FrontDiagonalBrace", Vector3(segment_center, 2.0, 7.79), Vector3(0.16, 1.75, 0.14), WOOD)
		brace.rotation_degrees.z = direction * 34.0
	for side in [-1.0, 1.0]:
		for z in [-5.8, -2.2, 1.4, 5.0]:
			_add_box(parent, "SideTimberPost", Vector3(side * 10.14, 1.95, z), Vector3(0.17, 2.4, 0.17), WOOD_DARK)


func _build_gatehouse_stone_detail(parent: Node3D) -> void:
	for side in [-1.0, 1.0]:
		_add_box(parent, "GatehouseCornerPier", Vector3(side * 2.62, 2.05, 7.52), Vector3(0.48, 3.0, 0.5), STONE_DARK)
		_add_box(parent, "DoorFlankStone", Vector3(side * 1.52, 1.35, 7.73), Vector3(0.42, 2.15, 0.3), STONE_LIGHT)
	_add_box(parent, "GatehouseStoneBelt", Vector3(0.0, 3.16, 7.71), Vector3(5.2, 0.34, 0.32), STONE_DARK)
	for x in [-2.1, -1.4, 1.4, 2.1]:
		_add_box(parent, "GatehouseMerlon", Vector3(x, 3.52, 7.69), Vector3(0.52, 0.42, 0.34), STONE_DARK)


func _add_gable_roof(parent: Node3D, node_name: String, center: Vector3, width: float, depth: float, rise: float) -> Node3D:
	var roof_root := Node3D.new()
	roof_root.name = node_name
	parent.add_child(roof_root)
	var half_span := width * 0.5
	var slope_length := sqrt(half_span * half_span + rise * rise)
	var angle := rad_to_deg(atan2(rise, half_span))
	for side in [-1.0, 1.0]:
		var panel := _add_box(
			roof_root,
			"SlateRoofPanel",
			center + Vector3(side * half_span * 0.5, rise * 0.5, 0.0),
			Vector3(slope_length + 0.18, 0.16, depth),
			ROOF_BLUE.darkened(0.12)
		)
		panel.rotation_degrees.z = -side * angle
		_add_box(roof_root, "HeavyEaveTrim", center + Vector3(side * half_span, 0.0, 0.0), Vector3(0.2, 0.3, depth + 0.12), WOOD_DARK)
	_add_box(roof_root, "CappedRidge", center + Vector3(0.0, rise + 0.04, 0.0), Vector3(0.3, 0.28, depth + 0.16), IRON)
	for z_offset in [-depth * 0.38, -depth * 0.12, depth * 0.14, depth * 0.4]:
		for side in [-1.0, 1.0]:
			var seam := _add_box(
				roof_root,
				"SlateCourseSeam",
				center + Vector3(side * half_span * 0.5, rise * 0.5 + 0.07, z_offset),
				Vector3(slope_length, 0.035, 0.08),
				IRON.lightened(0.08)
			)
			seam.rotation_degrees.z = -side * angle
	return roof_root


func _add_stepped_gable(parent: Node3D, node_name: String, base_center: Vector3, width: float, rise: float, color: Color) -> Node3D:
	var gable := Node3D.new()
	gable.name = node_name
	parent.add_child(gable)
	var tier_count := 4
	for tier in range(tier_count):
		var tier_width := width * (1.0 - float(tier) * 0.22)
		var tier_height := rise / float(tier_count)
		_add_box(
			gable,
			"GableStoneTier",
			base_center + Vector3(0.0, tier_height * (float(tier) + 0.5), 0.0),
			Vector3(tier_width, tier_height + 0.04, 0.24),
			color.darkened(float(tier) * 0.025)
		)
	_add_box(gable, "GableVerticalTimber", base_center + Vector3(0.0, rise * 0.48, 0.14), Vector3(0.18, rise * 0.96, 0.12), WOOD_DARK)
	return gable


func _build_upgrade_visuals() -> void:
	var upgrades := Node3D.new()
	upgrades.name = "UpgradeVisuals"
	add_child(upgrades)
	for visual_level in range(2, MAXIMUM_LEVEL + 1):
		var level_root := Node3D.new()
		level_root.name = "Level%d" % visual_level
		level_root.visible = false
		upgrades.add_child(level_root)

	var level_2 := upgrades.get_node("Level2") as Node3D
	for side in [-1.0, 1.0]:
		for z in [-5.8, -1.9, 2.0, 5.9]:
			_add_scene_prop(level_2, "StoneButtress", SUPPORT, Vector3(side * 10.28, 0.05, z), Vector3(0.85, 0.78, 0.62), Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0))
	# The front elevation remains readable at Lv.2: reinforcement belongs at the
	# side/rear load paths, never as short free-standing blocks over the windows.
	_add_box(level_2, "ReinforcedFoundationBand", Vector3(0.0, 0.51, 8.15), Vector3(19.9, 0.18, 0.28), IRON)

	var level_3 := upgrades.get_node("Level3") as Node3D
	_add_textured_box(level_3, "RoofAccessGallery", Vector3(0.0, 3.62, -3.55), Vector3(4.7, 0.34, 3.1), "rock", Color("#696e72"), 0.55)
	for side in [-1.0, 1.0]:
		_add_box(level_3, "GalleryParapet", Vector3(side * 2.18, 4.04, -3.55), Vector3(0.3, 0.75, 3.1), STONE_DARK)
		_add_box(level_3, "GalleryMerlon", Vector3(side * 1.15, 4.02, -4.95), Vector3(0.72, 0.7, 0.32), STONE_DARK)
	_add_box(level_3, "GalleryRearRail", Vector3(0.0, 4.0, -5.0), Vector3(4.5, 0.68, 0.3), STONE_DARK)

	var level_4 := upgrades.get_node("Level4") as Node3D
	for x in [-3.72, 3.72]:
		_add_box(level_4, "KeepIronCornerBand", Vector3(x, 4.1, 0.0), Vector3(0.2, 1.55, 5.2), IRON)
	for z in [-2.42, 2.42]:
		_add_box(level_4, "KeepIronEaveBand", Vector3(0.0, 4.35, z), Vector3(7.45, 0.18, 0.2), IRON)

	var level_5 := upgrades.get_node("Level5") as Node3D
	_add_textured_box(level_5, "WestPlatformUnderframe", Vector3(-7.0, 2.91, 5.0), Vector3(4.15, 0.18, 4.15), "rock", Color("#62686c"), 0.5)
	for corner in [Vector3(-8.75, 2.5, 3.25), Vector3(-5.25, 2.5, 3.25), Vector3(-8.75, 2.5, 6.75), Vector3(-5.25, 2.5, 6.75)]:
		_add_box(level_5, "WestPlatformStoneKnee", corner, Vector3(0.38, 0.95, 0.38), STONE_DARK)
	_add_box(level_5, "WestWatchMast", Vector3(-9.35, 4.15, 5.0), Vector3(0.16, 2.2, 0.16), WOOD_DARK)
	_add_scene_prop(level_5, "WestWatchBanner", BANNER, Vector3(-9.3, 4.2, 5.05), Vector3.ONE * 0.46, Vector3(0.0, 90.0, 0.0))

	var level_6 := upgrades.get_node("Level6") as Node3D
	_add_textured_box(level_6, "EastPlatformUnderframe", Vector3(7.0, 2.91, 5.0), Vector3(4.15, 0.18, 4.15), "rock", Color("#62686c"), 0.5)
	_add_textured_box(level_6, "FrontTowerFoundation", Vector3(0.0, 3.12, 7.0), Vector3(4.9, 0.48, 3.4), "rock", Color("#666b70"), 0.5)
	for side in [-1.0, 1.0]:
		_add_textured_box(level_6, "FrontTowerStoneJamb", Vector3(side * 2.18, 2.2, 7.45), Vector3(0.55, 2.4, 0.65), "rock", Color("#696765"), 0.55)


func _build_damage_visuals() -> void:
	var damage := Node3D.new()
	damage.name = "DamageVisuals"
	add_child(damage)
	var mild := Node3D.new()
	mild.name = "Mild"
	mild.visible = false
	damage.add_child(mild)
	for crack in [
		[Vector3(-7.2, 1.55, 7.88), -28.0], [Vector3(6.4, 2.1, 7.88), 22.0],
		[Vector3(10.24, 1.7, -3.7), 14.0]
	]:
		var slash := _add_box(mild, "FacadeCrack", crack[0], Vector3(0.08, 0.85, 0.07), Color("#29292b"))
		slash.rotation_degrees.z = float(crack[1])
	var torn_banner := _add_box(mild, "TornCommandCloth", Vector3(-2.05, 3.15, 7.96), Vector3(0.52, 0.7, 0.06), BANNER_RED.darkened(0.25))
	torn_banner.rotation_degrees.z = -12.0

	var heavy := Node3D.new()
	heavy.name = "Heavy"
	heavy.visible = false
	damage.add_child(heavy)
	_add_box(heavy, "BrokenFrontMasonry", Vector3(8.7, 0.9, 7.9), Vector3(1.15, 0.75, 0.58), STONE_DARK.darkened(0.25))
	for index in range(5):
		_add_box(heavy, "FallenStone", Vector3(7.3 + float(index) * 0.46, 0.19, 8.35 + float(index % 2) * 0.28), Vector3(0.38, 0.3, 0.42), STONE.darkened(0.18))
	for puff in [Vector3(7.2, 4.25, 1.5), Vector3(7.55, 4.85, 1.3), Vector3(7.05, 5.35, 1.1)]:
		_add_sphere(heavy, "DamageSmoke", puff, 0.42, Color(0.16, 0.17, 0.18, 0.46))


func _build_destroyed_ruin() -> void:
	var ruin := Node3D.new()
	ruin.name = "DestroyedRuin"
	ruin.visible = false
	ruin.set_meta("ruin_kind", "collapsed_command_hall")
	ruin.set_meta("built_from_normal_material_language", true)
	add_child(ruin)
	_add_textured_box(ruin, "CommandFoundationRemains", Vector3(0.0, 0.20, 0.0), Vector3(20.9, 0.40, 16.9), "rock", Color("#55595d"), 0.56)
	_add_textured_box(ruin, "RearCommandWallRemains", Vector3(0.0, 1.05, -7.25), Vector3(15.8, 1.72, 0.72), "plaster", Color("#82796c"), 0.54)
	_add_textured_box(ruin, "WestCommandWallRemains", Vector3(-9.62, 0.86, -1.20), Vector3(0.70, 1.30, 10.8), "rock", Color("#5e6265"), 0.58)
	_add_textured_box(ruin, "EastCommandWallRemains", Vector3(9.58, 0.70, 2.10), Vector3(0.70, 1.00, 7.4), "brick", Color("#66686a"), 0.62)
	var keep_roof := _add_textured_box(ruin, "FallenCentralKeepRoof", Vector3(-0.75, 0.72, -1.35), Vector3(7.2, 0.24, 5.2), "brick", ROOF_BLUE.darkened(0.14), 0.54)
	var hall_roof_west := _add_textured_box(ruin, "FallenWestHallRoof", Vector3(-5.70, 0.58, 2.30), Vector3(8.9, 0.22, 6.7), "brick", ROOF_BLUE.darkened(0.20), 0.52)
	var hall_roof_east := _add_textured_box(ruin, "FallenEastHallRoof", Vector3(5.20, 0.50, 1.55), Vector3(8.5, 0.22, 6.3), "brick", ROOF_BLUE.darkened(0.24), 0.52)
	keep_roof.rotation_degrees = Vector3(5.0, -12.0, 13.0)
	hall_roof_west.rotation_degrees = Vector3(-4.0, 14.0, 9.0)
	hall_roof_east.rotation_degrees = Vector3(4.0, -18.0, -10.0)
	for roof_part in [keep_roof, hall_roof_west, hall_roof_east]:
		roof_part.set_meta("collapsed_normal_roof_section", true)
	for index in range(12):
		var row := index / 4
		var column := index % 4
		var side := -1.0 if index % 2 == 0 else 1.0
		var beam := _add_textured_box(
			ruin,
			"FallenCommandBeam%02d" % (index + 1),
			Vector3(-6.2 + float(column) * 4.1 + side * 0.35, 0.32 + 0.07 * float(index % 3), -4.0 + float(row) * 3.8),
			Vector3(0.30, 0.26, 4.2 - 0.18 * float(index % 3)),
			"wood", Color("#48362f"), 0.84
		)
		beam.rotation_degrees = Vector3(4.0 * float(row), -42.0 + float(index) * 8.0, side * (8.0 + float(index % 4) * 3.0))
	for index in range(14):
		var x := -8.2 + float(index % 7) * 2.62
		var z := 6.2 + float(index / 7) * 1.05 + 0.26 * float(index % 2)
		_add_textured_box(
			ruin,
			"CommandMasonryRubble%02d" % (index + 1),
			Vector3(x, 0.30, z), Vector3(0.72, 0.48, 0.78),
			"rock", Color("#626467"), 0.66
		)
	_add_scene_prop(ruin, "FallenCommandBannerWest", BANNER, Vector3(-2.55, 0.34, 6.55), Vector3.ONE * 0.82, Vector3(78.0, -18.0, -12.0))
	_add_scene_prop(ruin, "FallenCommandBannerEast", BANNER, Vector3(2.60, 0.30, 6.90), Vector3.ONE * 0.76, Vector3(84.0, 24.0, 10.0))
	_add_scene_prop(ruin, "BrokenCommandShield", SHIELD, Vector3(0.2, 0.24, 7.15), Vector3.ONE * 0.88, Vector3(76.0, -10.0, 18.0))


func _apply_destruction_state(latched: bool) -> void:
	_destruction_latched = latched
	for path in ["BaseVisuals", "Roof", "UpgradeVisuals", "DamageVisuals"]:
		var normal_root := get_node_or_null(path) as Node3D
		if normal_root != null:
			normal_root.visible = not latched
	var ruin := get_node_or_null("DestroyedRuin") as Node3D
	if ruin != null:
		ruin.visible = latched
	var fixture_visuals := get_node_or_null("../FixtureLayout/Visuals") as Node3D
	if fixture_visuals != null:
		fixture_visuals.visible = not latched
		if not latched:
			_apply_external_fixture_level_visibility()


func _apply_damage_ratio(ratio: float) -> void:
	_damage_ratio = clampf(ratio, 0.0, 1.0)
	var mild := get_node_or_null("DamageVisuals/Mild") as Node3D
	var heavy := get_node_or_null("DamageVisuals/Heavy") as Node3D
	if mild != null:
		mild.visible = _damage_ratio < 0.76
	if heavy != null:
		heavy.visible = _damage_ratio < 0.41


func _add_signal_brazier(parent: Node3D, center: Vector3) -> void:
	_add_cylinder(parent, "SignalBrazierStand", center - Vector3(0.0, 0.52, 0.0), 0.16, 1.0, IRON)
	_add_cylinder(parent, "SignalBrazierBowl", center, 0.58, 0.3, IRON)
	_add_sphere(parent, "SignalFlame", center + Vector3(0.0, 0.42, 0.0), 0.34, EMBER)


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
	var root := get_node_or_null("../FixtureLayout/Visuals")
	if root == null:
		return 0
	var count := 0
	for raw_child in root.get_children():
		if raw_child is Node3D and (raw_child as Node3D).visible:
			count += 1
	return count


func _active_fixture_collision_count() -> int:
	var root := get_node_or_null("../FixtureLayout/StaticCollision")
	if root == null:
		return 0
	var count := 0
	for raw_body in root.get_children():
		if raw_body is StaticBody3D and (raw_body as StaticBody3D).collision_layer != 0:
			count += 1
	return count


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


func _add_main_hall_entry_lantern(parent: Node3D, lantern_name: String, side: float) -> void:
	var mount := Node3D.new()
	mount.name = "Support_%s" % lantern_name
	# 柱脚收在 22×18 m 主厅包络内，只有横臂与灯体越过立面形成门廊照明。
	mount.position = Vector3(side * 3.45, 0.0, 7.35)
	# 主厅正门朝 +Z；灯臂朝道路伸出，避免再次缩进门楼屋檐阴影内。
	mount.rotation_degrees.y = 0.0
	mount.set_meta("functional_lantern_support", true)
	parent.add_child(mount)
	_add_box(mount, "StoneFoot", Vector3(0.0, 0.22, 0.0), Vector3(0.62, 0.44, 0.62), STONE_DARK)
	_add_box(mount, "TimberPost", Vector3(0.0, 1.38, 0.0), Vector3(0.24, 2.4, 0.24), WOOD_DARK)
	_add_box(mount, "IronCap", Vector3(0.0, 2.6, 0.0), Vector3(0.36, 0.16, 0.36), IRON)
	_add_box(mount, "LanternCrossArm", Vector3(0.0, 2.38, 0.32), Vector3(0.14, 0.14, 0.76), WOOD)
	var lantern := _add_scene_prop(mount, lantern_name, LANTERN, Vector3(0.0, 2.17, 0.57), Vector3.ONE * 0.84)
	if lantern != null:
		lantern.set_meta("mounted_to_structure", true)
		lantern.set_meta("mount_surface", "main_hall_entry_lantern_post")


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


func _add_textured_box(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	size: Vector3,
	texture_kind: String,
	tint: Color,
	texture_density: float
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _textured_material(texture_kind, tint, texture_density)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	instance.set_meta("solid_visual_volume", true)
	instance.set_meta("texture_kind", texture_kind)
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, center: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
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
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.83
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_cache[key] = material
	return material


func _textured_material(texture_kind: String, tint: Color, texture_density: float) -> StandardMaterial3D:
	var key := "textured:%s:%s:%.3f" % [texture_kind, tint.to_html(true), texture_density]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * maxf(0.05, texture_density)
	var base_color_path := ""
	var normal_path := ""
	var packed_orm_path := ""
	var roughness_path := ""
	match texture_kind:
		"rock":
			base_color_path = ROCK_BASE_COLOR
			normal_path = ROCK_NORMAL
			packed_orm_path = ROCK_ORM
		"plaster":
			base_color_path = PLASTER_BASE_COLOR
			normal_path = PLASTER_NORMAL
			packed_orm_path = PLASTER_ORM
		_:
			base_color_path = BRICK_BASE_COLOR
			normal_path = BRICK_NORMAL
			roughness_path = BRICK_ROUGHNESS
	if ResourceLoader.exists(base_color_path):
		material.albedo_texture = load(base_color_path) as Texture2D
	if ResourceLoader.exists(normal_path):
		material.normal_enabled = true
		material.normal_scale = 0.62
		material.normal_texture = load(normal_path) as Texture2D
	if not packed_orm_path.is_empty() and ResourceLoader.exists(packed_orm_path):
		material.orm_texture = load(packed_orm_path) as Texture2D
	elif not roughness_path.is_empty() and ResourceLoader.exists(roughness_path):
		material.roughness_texture = load(roughness_path) as Texture2D
	_material_cache[key] = material
	return material
