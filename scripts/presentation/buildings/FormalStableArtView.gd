class_name FormalStableArtView
extends BuildingArtView


const AUTO_DOOR_SCRIPT := preload("res://scripts/presentation/buildings/BuildingAutoDoor.gd")
const HORSE_WORLD_VIEW_SCRIPT := preload("res://scripts/presentation/characters/HorseWorldView.gd")
const HORSE_ASSET := "res://assets/3d/quaternius/animals/merchant_horse.glb"
const BUCKET := "res://assets/3d/quaternius/props/bucket_wooden.glb"
const BARREL := "res://assets/3d/quaternius/props/barrel.glb"
const CRATE := "res://assets/3d/quaternius/props/crate_wooden.glb"
const BAG := "res://assets/3d/quaternius/props/warehouse_bag.glb"
const ROPE := "res://assets/3d/quaternius/props/workshop_rope.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"

const LOT_SIZE := Vector2(16.0, 16.0)
const ENVELOPE_SIZE := Vector2(14.0, 14.0)
const MAXIMUM_LEVEL := 3
const EARTH := Color("#4a4035")
const WORN_EARTH := Color("#665744")
const STONE := Color("#5d625f")
const PALE_STONE := Color("#7b8078")
const DARK_WOOD := Color("#3d322a")
const OAK := Color("#6c5038")
const WEATHERED_WOOD := Color("#806344")
const IRON := Color("#444b4d")
const LEATHER := Color("#604936")
const STRAW := Color("#a28b58")
const DRY_STRAW := Color("#796846")
const WATER := Color("#426a74")
const CLOTH_RED := Color("#70424a")
const ROOF_GREEN := Color("#4c5b50")
const STALL_SHELTER_INNER_POST_X := 1.82
const STALL_SHELTER_OUTER_POST_X := 6.34
const STALL_AWNING_CENTER_X := 4.16
const STALL_AWNING_WIDTH := 5.05
const STALL_AWNING_RAFTER_WIDTH := 4.84

const HORSE_ANCHOR_ORDER_LEVEL_1 := [
	"stall_01", "stall_02", "horse_anchor_04", "horse_anchor_05",
	"horse_anchor_06", "horse_anchor_07", "horse_anchor_08"
]
const HORSE_ANCHOR_ORDER_LEVEL_3 := [
	"stall_01", "stall_02", "stall_03", "horse_anchor_04",
	"horse_anchor_05", "horse_anchor_06", "horse_anchor_07", "horse_anchor_08"
]

var _material_cache: Dictionary = {}
var _horse_visuals: Dictionary = {}
var _horse_idle_time := 0.0


func _ready() -> void:
	add_to_group("horse_world_presentation")
	_build_formal_stable()
	super._ready()
	_bind_horse_state()
	call_deferred("_sync_horse_presentation")
	set_process(true)


func _process(delta: float) -> void:
	_horse_idle_time += delta
	_sync_horse_presentation()
	var index := 0
	for raw_visual in _horse_visuals.values():
		var visual := raw_visual as Node3D
		if visual == null or not visual.visible:
			continue
		var model := visual.get_node_or_null("HorseModel") as Node3D
		if model != null:
			model.position.y = 0.025 + sin(_horse_idle_time * 1.45 + float(index) * 0.9) * 0.012
		index += 1


func is_interior_revealed_for_selection() -> bool:
	return _roof_opacity <= interior_reveal_opacity_threshold


func _apply_visual_level(level: int, upgrade_in_progress: bool) -> void:
	super._apply_visual_level(mini(level, MAXIMUM_LEVEL), upgrade_in_progress)
	_apply_external_fixture_level_visibility()
	_apply_functional_lantern_level_visibility()
	_sync_horse_presentation()


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
	var auto_gate := get_node_or_null("Exterior/AutoStableGate")
	if auto_gate != null and auto_gate.has_method("debug_get_snapshot"):
		gate_snapshot = auto_gate.call("debug_get_snapshot")
	var horse_visual_states: Dictionary = {}
	for raw_horse_id in _horse_visuals.keys():
		var horse_id := str(raw_horse_id)
		var horse_visual := _horse_visuals[horse_id] as Node3D
		if horse_visual != null:
			var interaction_snapshot: Dictionary = horse_visual.debug_get_snapshot() if horse_visual.has_method("debug_get_snapshot") else {}
			horse_visual_states[horse_id] = {
				"visible": horse_visual.visible,
				"anchor_id": str(horse_visual.get_meta("horse_anchor_id", "")),
				"stable_slot_id": str(horse_visual.get_meta("stable_slot_id", "")),
				"source_location": str(horse_visual.get_meta("source_location", "")),
				"is_adult": bool(horse_visual.get_meta("is_adult", false)),
				"name": str(interaction_snapshot.get("name", "")),
				"name_visible": bool(interaction_snapshot.get("name_visible", false)),
				"click_enabled": bool(interaction_snapshot.get("click_enabled", false)),
				"template_id": str(interaction_snapshot.get("template_id", "")),
				"coat_color": str(interaction_snapshot.get("coat_color", "")),
				"motion_animation": str(horse_visual.get_meta("motion_animation", "")),
				"moving_animation": bool(horse_visual.get_meta("moving_animation", false))
			}
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"maximum_level": MAXIMUM_LEVEL,
		"level_2_visible": _is_visible(NodePath("UpgradeVisuals/Level2")),
		"level_3_visible": _is_visible(NodePath("UpgradeVisuals/Level3")),
		"workstations": workstation_states,
		"care_station_count": _count_workstation_prefix(workstation_states, "stall_"),
		"available_care_station_count": _count_available_prefix(workstation_states, "stall_"),
		"active_fixture_visual_count": _active_fixture_visual_count(),
		"active_fixture_collision_count": _active_fixture_collision_count(),
		"active_fixture_collision_part_count": _active_fixture_collision_part_count(),
		"horse_anchor_count": _horse_anchor_count(),
		"available_horse_anchor_count": _available_horse_anchor_count(),
		"visible_real_horse_count": _visible_real_horse_count(),
		"horse_visuals": horse_visual_states,
		"level_visual_addition_counts": {
			"level_1": _mesh_count_at("Interior/Level1Details") + _mesh_count_at("Exterior") + _mesh_count_at("Roof"),
			"level_2": _mesh_count_at("UpgradeVisuals/Level2"),
			"level_3": _mesh_count_at("UpgradeVisuals/Level3")
		},
		"lot_size": LOT_SIZE,
		"envelope_size": ENVELOPE_SIZE,
		"architectural_style": "open_air_medieval_border_stable_yard",
		"facade_profile": "paired_open_stall_rows_central_leading_aisle_and_low_timber_gate",
		"roof_profile": "two_narrow_open_sided_stall_awnings_only",
		"functional_visual_language": "real_horses_stalls_troughs_hay_tack_grooming_and_farrier_maintenance",
		"level_two_upgrade_profile": "shared_feed_tack_hay_water_and_hoof_care_without_capacity_gain",
		"level_three_upgrade_profile": "third_authoritative_care_bay_foal_recovery_and_logistics_support",
		"open_air_selection_priority": is_interior_revealed_for_selection(),
		"auto_gate": gate_snapshot,
		"roof_mesh_count": _roof_meshes.size(),
		"roof_structure_additions_fade_with_roof": additional_roof_fade_paths.size() == 2,
		"navigation_ready": _formal_navigation_ready(),
		"collision_authority": "formal_station_static_and_level_synced_fixture_collision",
		"navigation_authority": "formal_station_navigation_mesh",
		"horse_authority": "horse_system_only_read_projection",
		"care_authority": "building_action_npc_and_horse_system_only",
		"authority_role": "presentation_only"
	}


func _build_formal_stable() -> void:
	building_id = "stable"
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
	set_meta("art_revision", "t0131_p9")
	set_meta("formal_vertical_slice", true)
	set_meta("open_air_site", true)
	set_meta("lot_size_meters", LOT_SIZE)
	set_meta("envelope_size_meters", ENVELOPE_SIZE)
	set_meta("maximum_level", MAXIMUM_LEVEL)
	_build_ground_and_aisle()
	_build_enclosure_and_gate()
	_build_stall_weather_shelters()
	_build_level_one_details()
	_build_upgrade_visuals()
	_build_horse_presentation_root()
	additional_roof_fade_paths = [
		NodePath("UpgradeVisuals/Level2/RoofStructureAdditions"),
		NodePath("UpgradeVisuals/Level3/RoofStructureAdditions")
	]


func _build_ground_and_aisle() -> void:
	var interior := Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_add_box(interior, "CompactedStableEarth", Vector3(0.0, 0.035, 0.0), Vector3(13.65, 0.07, 13.65), EARTH)
	var aisle := Node3D.new()
	aisle.name = "CentralLeadingAisle"
	interior.add_child(aisle)
	_add_box(aisle, "WornAisle", Vector3(0.0, 0.082, 0.25), Vector3(2.45, 0.035, 12.95), WORN_EARTH)
	for z in [-5.7, -4.7, -3.7, -2.7, -1.7, -0.7, 0.3, 1.3, 2.3, 3.3, 4.3, 5.3]:
		_add_hoof_print(aisle, Vector3(-0.34, 0.108, z), -8.0)
		_add_hoof_print(aisle, Vector3(0.34, 0.108, z + 0.35), 8.0)
	for z in [-5.95, -3.0, -0.05, 2.9, 5.85]:
		_add_box(aisle, "DrainageCrossStrip", Vector3(0.0, 0.105, z), Vector3(2.35, 0.03, 0.12), STONE.darkened(0.08))


func _build_enclosure_and_gate() -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	var curb := Node3D.new()
	curb.name = "LowStoneStableCurb"
	exterior.add_child(curb)
	_add_box(curb, "RearCurb", Vector3(0.0, 0.18, -6.78), Vector3(13.55, 0.36, 0.4), STONE)
	for side in [-1.0, 1.0]:
		_add_box(curb, "SideCurb", Vector3(side * 6.78, 0.18, 0.0), Vector3(0.4, 0.36, 13.55), STONE)
		_add_box(curb, "FrontCurb", Vector3(side * 4.45, 0.18, 6.78), Vector3(4.55, 0.36, 0.4), STONE)

	var fence := Node3D.new()
	fence.name = "StablePostAndRailFence"
	exterior.add_child(fence)
	_add_rail_fence_run(fence, Vector3(0.0, 0.0, -6.68), 13.25, false)
	for side in [-1.0, 1.0]:
		_add_rail_fence_run(fence, Vector3(side * 6.68, 0.0, 0.0), 13.25, true)
		_add_rail_fence_run(fence, Vector3(side * 4.55, 0.0, 6.68), 4.15, false)
	for side in [-1.0, 1.0]:
		_add_box(exterior, "StableGateStonePost", Vector3(side * 1.48, 0.9, 6.68), Vector3(0.52, 1.8, 0.58), PALE_STONE)
		_add_box(exterior, "StableGateTimberCap", Vector3(side * 1.48, 1.88, 6.68), Vector3(0.68, 0.15, 0.72), DARK_WOOD)
	var gate := Node3D.new()
	gate.name = "AutoStableGate"
	gate.position = Vector3(0.0, 0.2, 6.68)
	gate.set_script(AUTO_DOOR_SCRIPT)
	gate.set("clear_width", 2.58)
	gate.set("clear_height", 2.35)
	gate.set("leaf_visual_height", 1.22)
	gate.call("configure", WEATHERED_WOOD, DARK_WOOD, IRON)
	exterior.add_child(gate)
	_add_stable_sign(exterior)


func _build_stall_weather_shelters() -> void:
	var exterior := get_node("Exterior") as Node3D
	var supports := Node3D.new()
	supports.name = "OpenStallShelterSupports"
	exterior.add_child(supports)
	for side in [-1.0, 1.0]:
		for z in [-6.25, -3.1, 0.0, 3.1, 6.25]:
			_add_box(supports, "OuterShelterPost", Vector3(side * STALL_SHELTER_OUTER_POST_X, 1.48, z), Vector3(0.22, 2.62, 0.22), DARK_WOOD)
			_add_box(supports, "InnerShelterPost", Vector3(side * STALL_SHELTER_INNER_POST_X, 1.48, z), Vector3(0.2, 2.62, 0.2), OAK)
		_add_box(supports, "OuterShelterBeam", Vector3(side * STALL_SHELTER_OUTER_POST_X, 2.66, 0.0), Vector3(0.22, 0.22, 12.7), DARK_WOOD)
		_add_box(supports, "InnerShelterBeam", Vector3(side * STALL_SHELTER_INNER_POST_X, 2.72, 0.0), Vector3(0.2, 0.2, 12.7), OAK)
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.set_meta("roof_fade_candidate", true)
	add_child(roof)
	for side in [-1.0, 1.0]:
		var awning := _add_box(roof, "OpenStallAwning", Vector3(side * STALL_AWNING_CENTER_X, 2.82, 0.0), Vector3(STALL_AWNING_WIDTH, 0.14, 12.9), ROOF_GREEN)
		awning.rotation_degrees.z = -7.0 * side
		for z in [-5.9, -3.0, 0.0, 3.0, 5.9]:
			var rafter := _add_box(roof, "StallAwningRafter", Vector3(side * STALL_AWNING_CENTER_X, 2.87, z), Vector3(STALL_AWNING_RAFTER_WIDTH, 0.055, 0.1), DARK_WOOD)
			rafter.rotation_degrees.z = -7.0 * side


func _build_level_one_details() -> void:
	var details := Node3D.new()
	details.name = "Level1Details"
	(get_node("Interior") as Node3D).add_child(details)
	var wash_corner := Node3D.new()
	wash_corner.name = "FrontWashAndGroomingCorner"
	details.add_child(wash_corner)
	_add_scene_prop(wash_corner, "WashBarrel", BARREL, Vector3(5.78, 0.24, 6.12), Vector3.ONE * 0.64)
	_add_scene_prop(wash_corner, "GroomingBucket", BUCKET, Vector3(4.92, 0.13, 6.22), Vector3.ONE * 0.5)
	_add_scene_prop(wash_corner, "CoiledLeadRope", ROPE, Vector3(6.22, 0.95, 5.75), Vector3.ONE * 0.5, Vector3(0.0, 90.0, 0.0))
	_add_box(wash_corner, "WashWater", Vector3(5.78, 0.7, 6.12), Vector3(0.52, 0.025, 0.52), WATER)

	var tool_wall := Node3D.new()
	tool_wall.name = "StableCleaningToolWall"
	details.add_child(tool_wall)
	_add_box(tool_wall, "ToolRail", Vector3(-6.42, 1.45, 4.25), Vector3(0.12, 0.18, 2.9), OAK)
	for index in range(4):
		var z := 3.25 + float(index) * 0.68
		_add_cylinder(tool_wall, "ToolHandle", Vector3(-6.28, 1.15, z), 0.045, 1.35, WEATHERED_WOOD, Vector3(0.0, 0.0, 7.0 if index % 2 == 0 else -7.0))
		_add_box(tool_wall, "BrushHead", Vector3(-6.17, 0.5, z), Vector3(0.3, 0.16, 0.2), DARK_WOOD)

	var starter_tack := Node3D.new()
	starter_tack.name = "StarterTackRail"
	details.add_child(starter_tack)
	_add_box(starter_tack, "TackBackboard", Vector3(6.42, 1.45, -4.55), Vector3(0.12, 1.7, 3.25), DARK_WOOD)
	for z in [-5.55, -4.55, -3.55]:
		_add_cylinder(starter_tack, "HarnessPeg", Vector3(6.24, 1.55, z), 0.045, 0.34, IRON, Vector3(0.0, 0.0, 90.0))
		_add_harness_loop(starter_tack, Vector3(6.1, 1.28, z), 0.42)
	_add_stall_lantern(details, "StableLanternWestRear", Vector3(-1.94, 2.25, -3.1), -90.0, 1)
	_add_stall_lantern(details, "StableLanternEastRear", Vector3(1.94, 2.25, -3.1), 90.0, 1)
	_add_stall_lantern(details, "StableLanternEastFront", Vector3(1.94, 2.25, 3.1), 90.0, 2)
	_add_stall_lantern(details, "StableLanternWestFront", Vector3(-1.94, 2.25, 3.1), -90.0, 3)


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
	_add_level_two_tack_storage(level_2_interior)
	_add_level_two_hay_reserve(level_2_interior)
	_add_level_two_farrier_station(level_2_interior)
	_add_level_two_water_extension(level_2_interior)
	var level_2_roof := Node3D.new()
	level_2_roof.name = "RoofStructureAdditions"
	level_2.add_child(level_2_roof)
	var feed_awning := _add_box(level_2_roof, "RearFeedRackWeatherAwning", Vector3(0.0, 2.5, -6.28), Vector3(3.45, 0.13, 1.18), ROOF_GREEN.darkened(0.06))
	feed_awning.rotation_degrees.x = -6.0
	for x in [-1.55, 1.55]:
		_add_box(level_2_roof, "FeedAwningPost", Vector3(x, 1.35, -6.45), Vector3(0.16, 2.35, 0.16), DARK_WOOD)

	var level_3 := Node3D.new()
	level_3.name = "Level3"
	level_3.visible = false
	upgrades.add_child(level_3)
	var level_3_interior := Node3D.new()
	level_3_interior.name = "InteriorAdditions"
	level_3.add_child(level_3_interior)
	_add_level_three_stall_support(level_3_interior)
	_add_level_three_foal_recovery_support(level_3_interior)
	_add_level_three_logistics(level_3_interior)
	var level_3_roof := Node3D.new()
	level_3_roof.name = "RoofStructureAdditions"
	level_3.add_child(level_3_roof)
	var recovery_awning := _add_box(level_3_roof, "RecoverySupplyAwning", Vector3(5.82, 2.55, 5.75), Vector3(1.65, 0.13, 1.65), CLOTH_RED.darkened(0.12))
	recovery_awning.rotation_degrees.z = -7.0


func _add_level_two_tack_storage(parent: Node3D) -> void:
	var tack := Node3D.new()
	tack.name = "LevelTwoExpandedTackStorage"
	tack.set_meta("authority_role", "non_workstation_efficiency_symbol")
	parent.add_child(tack)
	_add_box(tack, "SaddleRail", Vector3(-6.4, 1.45, -3.0), Vector3(0.13, 1.8, 2.65), DARK_WOOD)
	for z in [-3.85, -3.0, -2.15]:
		_add_cylinder(tack, "SaddlePeg", Vector3(-6.2, 1.52, z), 0.055, 0.38, IRON, Vector3(0.0, 0.0, 90.0))
		_add_saddle(tack, Vector3(-6.03, 1.24, z), 0.68)


func _add_level_two_hay_reserve(parent: Node3D) -> void:
	var hay := Node3D.new()
	hay.name = "LevelTwoDryHayReserve"
	hay.set_meta("authority_role", "non_inventory_efficiency_symbol")
	parent.add_child(hay)
	for item in [
		{"position": Vector3(-5.9, 0.42, -6.15), "rotation": 7.0},
		{"position": Vector3(-4.85, 0.42, -6.15), "rotation": -5.0},
		{"position": Vector3(-5.38, 1.02, -6.1), "rotation": 2.0}
	]:
		var bale := _add_box(hay, "BoundHayBale", item.position, Vector3(0.92, 0.72, 0.92), STRAW)
		bale.rotation_degrees.y = float(item.rotation)
		_add_box(bale, "BaleBinding", Vector3.ZERO, Vector3(0.08, 0.76, 0.96), LEATHER)
	_add_scene_prop(hay, "FeedMeasureBag", BAG, Vector3(-4.18, 0.03, -6.22), Vector3.ONE * 0.7)


func _add_level_two_farrier_station(parent: Node3D) -> void:
	var farrier := Node3D.new()
	farrier.name = "LevelTwoFarrierMaintenance"
	farrier.position = Vector3(6.36, 0.0, -0.15)
	farrier.set_meta("authority_role", "non_workstation_hoof_care_symbol")
	parent.add_child(farrier)
	_add_box(farrier, "FarrierBoard", Vector3(0.0, 1.38, 0.0), Vector3(0.13, 1.55, 2.35), DARK_WOOD)
	for y in [0.82, 1.38, 1.94]:
		for z in [-0.62, 0.0, 0.62]:
			_add_horseshoe(farrier, Vector3(-0.09, y, z), 0.2)
	_add_box(farrier, "HoofToolShelf", Vector3(-0.3, 0.72, 0.0), Vector3(0.55, 0.11, 1.45), OAK)


func _add_level_two_water_extension(parent: Node3D) -> void:
	var water := Node3D.new()
	water.name = "LevelTwoWaterAndFeedExtension"
	water.set_meta("authority_role", "non_workstation_efficiency_symbol")
	parent.add_child(water)
	_add_scene_prop(water, "ReserveWaterBarrel", BARREL, Vector3(-5.72, 0.24, 6.08), Vector3.ONE * 0.64)
	_add_scene_prop(water, "FeedCrate", CRATE, Vector3(-4.82, 0.14, 6.15), Vector3.ONE * 0.46, Vector3(0.0, -12.0, 0.0))
	_add_scene_prop(water, "FeedBucket", BUCKET, Vector3(-5.72, 0.13, 5.2), Vector3.ONE * 0.48)


func _add_level_three_stall_support(parent: Node3D) -> void:
	var support := Node3D.new()
	support.name = "LevelThreeThirdCareBaySupport"
	support.set_meta("workstation_id", "stall_03")
	support.set_meta("authority_role", "authoritative_workstation_support")
	parent.add_child(support)
	_add_box(support, "ThirdCareToolRail", Vector3(-6.38, 1.44, -1.5), Vector3(0.13, 1.45, 2.25), OAK)
	_add_cylinder(support, "ThirdCareBrushHandle", Vector3(-6.18, 1.12, -1.85), 0.045, 1.25, WEATHERED_WOOD, Vector3(0.0, 0.0, 8.0))
	_add_box(support, "ThirdCareBrushHead", Vector3(-6.04, 0.52, -1.85), Vector3(0.32, 0.17, 0.22), DARK_WOOD)
	_add_scene_prop(support, "ThirdCareBucket", BUCKET, Vector3(-6.0, 0.13, -0.72), Vector3.ONE * 0.48)


func _add_level_three_foal_recovery_support(parent: Node3D) -> void:
	var recovery := Node3D.new()
	recovery.name = "LevelThreeFoalRecoverySupplies"
	recovery.set_meta("authority_role", "non_workstation_horse_welfare_symbol")
	parent.add_child(recovery)
	_add_box(recovery, "FoldedRecoveryBlanket", Vector3(5.96, 0.78, 5.72), Vector3(1.05, 0.18, 0.72), CLOTH_RED)
	_add_box(recovery, "BlanketShelf", Vector3(5.98, 0.62, 5.72), Vector3(1.35, 0.13, 0.95), OAK)
	_add_box(recovery, "WarmStrawBundle", Vector3(5.88, 0.31, 4.92), Vector3(1.2, 0.48, 0.72), DRY_STRAW)
	_add_scene_prop(recovery, "RecoveryBucket", BUCKET, Vector3(5.2, 0.13, 5.8), Vector3.ONE * 0.48)


func _add_level_three_logistics(parent: Node3D) -> void:
	var logistics := Node3D.new()
	logistics.name = "LevelThreeStableLogistics"
	logistics.set_meta("authority_role", "non_workstation_level_identity")
	parent.add_child(logistics)
	_add_scene_prop(logistics, "VeterinaryCrate", CRATE, Vector3(4.42, 0.14, -6.15), Vector3.ONE * 0.5, Vector3(0.0, 12.0, 0.0))
	_add_scene_prop(logistics, "ReserveFeedBag", BAG, Vector3(5.18, 0.03, -6.15), Vector3.ONE * 0.7)
	for side in [-1.0, 1.0]:
		_add_box(logistics, "LevelThreeGatePennantPole", Vector3(side * 2.18, 1.6, 6.45), Vector3(0.11, 2.75, 0.11), DARK_WOOD)
		_add_box(logistics, "LevelThreeGatePennant", Vector3(side * 2.46, 2.45, 6.45), Vector3(0.52, 0.42, 0.05), CLOTH_RED if side < 0.0 else ROOF_GREEN)


func _build_horse_presentation_root() -> void:
	var root := Node3D.new()
	root.name = "HorsePresentation"
	root.set_meta("authority_role", "horse_system_read_only_projection")
	add_child(root)


func _bind_horse_state() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	if event_bus.has_signal("horse_state_changed") and not event_bus.horse_state_changed.is_connected(_on_horse_state_changed):
		event_bus.horse_state_changed.connect(_on_horse_state_changed)
	if event_bus.has_signal("horse_assignment_changed") and not event_bus.horse_assignment_changed.is_connected(_on_horse_assignment_changed):
		event_bus.horse_assignment_changed.connect(_on_horse_assignment_changed)


func _on_horse_state_changed(_horse_id: String) -> void:
	_sync_horse_presentation()


func _on_horse_assignment_changed(_horse_id: String, _npc_id: String) -> void:
	_sync_horse_presentation()


func _sync_horse_presentation() -> void:
	var presentation_root := get_node_or_null("HorsePresentation") as Node3D
	var anchor_root := get_node_or_null("../FixtureLayout/HorseAnchors") as Node3D
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if presentation_root == null or anchor_root == null or horse_system == null or not horse_system.has_method("get_horses_snapshot"):
		return
	var anchors := _get_available_horse_anchors(anchor_root)
	var anchors_by_id: Dictionary = {}
	for marker in anchors:
		anchors_by_id[str(marker.get_meta("horse_anchor_id", ""))] = marker
	var stable_horses: Array[Dictionary] = []
	var moving_horses: Array[Dictionary] = []
	for raw_horse in horse_system.call("get_horses_snapshot"):
		if not raw_horse is Dictionary or not bool((raw_horse as Dictionary).get("alive", true)):
			continue
		var location := str((raw_horse as Dictionary).get("location", ""))
		if location == "stable":
			stable_horses.append((raw_horse as Dictionary).duplicate(true))
		elif location in ["approaching_rider", "returning_stable"]:
			moving_horses.append((raw_horse as Dictionary).duplicate(true))
	var active_ids: Dictionary = {}
	for horse in stable_horses:
		var horse_id := str(horse.get("horse_id", ""))
		var stable_slot_id := str(horse.get("stable_slot_id", ""))
		var marker := anchors_by_id.get(stable_slot_id) as Marker3D
		if horse_id.is_empty() or marker == null:
			continue
		active_ids[horse_id] = true
		var visual := _horse_visuals.get(horse_id) as Node3D
		if visual == null:
			visual = _create_horse_visual(horse)
			if visual == null:
				continue
			_horse_visuals[horse_id] = visual
			presentation_root.add_child(visual)
		if visual.has_method("refresh_horse"):
			visual.refresh_horse(horse)
		visual.visible = true
		_set_horse_animation(visual, false)
		visual.position = to_local(marker.global_position)
		visual.rotation_degrees.y = float(marker.get_meta("facing_degrees", 0.0)) + 180.0
		visual.set_meta("horse_anchor_id", stable_slot_id)
		visual.set_meta("stable_slot_id", stable_slot_id)
		visual.set_meta("source_location", str(horse.get("location", "")))
		visual.set_meta("is_adult", bool(horse.get("is_adult", false)))
		var growth := clampf(float(horse.get("growth", 0.6)) / 0.6, 0.58, 1.0)
		visual.scale = Vector3.ONE * growth
	for horse in moving_horses:
		var horse_id := str(horse.get("horse_id", ""))
		if horse_id.is_empty():
			continue
		active_ids[horse_id] = true
		var visual := _horse_visuals.get(horse_id) as Node3D
		if visual == null:
			visual = _create_horse_visual(horse)
			if visual == null:
				continue
			_horse_visuals[horse_id] = visual
			presentation_root.add_child(visual)
		if visual.has_method("refresh_horse"):
			visual.refresh_horse(horse)
		visual.visible = true
		var movement: Dictionary = horse.get("movement_state", {}) if horse.get("movement_state", {}) is Dictionary else {}
		var horse_stationary := bool(movement.get("horse_stationary", false))
		_set_horse_animation(visual, not horse_stationary)
		var world_position: Variant = horse.get("world_position", null)
		if world_position is Vector3:
			visual.global_position = world_position
		var movement_velocity: Variant = movement.get("velocity", null)
		var direction := Vector3.ZERO
		if movement_velocity is Vector3:
			direction = movement_velocity
		if direction.length_squared() <= 0.001:
			var target_position: Variant = movement.get("target_position", null)
			if target_position is Vector3:
				direction = target_position - visual.global_position
		if not horse_stationary and direction.length_squared() > 0.001:
			visual.look_at(visual.global_position + direction, Vector3.UP, true)
		visual.set_meta("horse_anchor_id", "")
		visual.set_meta("stable_slot_id", str(horse.get("stable_slot_id", "")))
		visual.set_meta("source_location", str(horse.get("location", "")))
		visual.set_meta("is_adult", bool(horse.get("is_adult", false)))
		var growth := clampf(float(horse.get("growth", 0.6)) / 0.6, 0.58, 1.0)
		visual.scale = Vector3.ONE * growth
	for raw_horse_id in _horse_visuals.keys():
		var horse_id := str(raw_horse_id)
		var visual := _horse_visuals[horse_id] as Node3D
		if visual != null and not active_ids.has(horse_id):
			visual.visible = false
			_set_horse_animation(visual, false, true)
			visual.set_meta("horse_anchor_id", "")


func get_horse_world_position(horse_id: String) -> Variant:
	var visual := _horse_visuals.get(horse_id) as Node3D
	if visual == null or not visual.is_inside_tree():
		return null
	return visual.global_position


func get_horse_pickup_world_position(horse_id: String) -> Variant:
	var visual := _horse_visuals.get(horse_id) as Node3D
	var anchor_root := get_node_or_null("../FixtureLayout/HorseAnchors") as Node3D
	if visual == null or anchor_root == null:
		return null
	var stable_slot_id := str(visual.get_meta("stable_slot_id", ""))
	for raw_marker in anchor_root.get_children():
		if not raw_marker is Marker3D:
			continue
		var marker := raw_marker as Marker3D
		if str(marker.get_meta("horse_anchor_id", "")) != stable_slot_id:
			continue
		var pickup_center: Variant = marker.get_meta("pickup_center", null)
		if pickup_center is Vector2:
			return anchor_root.to_global(Vector3(pickup_center.x, 0.0, pickup_center.y))
	return null


func get_horse_presentation_snapshot(horse_id: String) -> Dictionary:
	var visual := _horse_visuals.get(horse_id) as Node3D
	if visual == null or not visual.is_inside_tree() or not visual.visible:
		return {}
	var snapshot: Dictionary = visual.debug_get_snapshot() if visual.has_method("debug_get_snapshot") else {}
	snapshot["horse_anchor_id"] = str(visual.get_meta("horse_anchor_id", ""))
	snapshot["source_location"] = str(visual.get_meta("source_location", ""))
	snapshot["moving_animation"] = bool(visual.get_meta("moving_animation", false))
	snapshot["motion_animation"] = str(visual.get_meta("motion_animation", ""))
	var horse_scale := maxf(0.58, visual.scale.y)
	snapshot["focus_height"] = 0.68 * horse_scale
	snapshot["camera_height"] = 0.92 * horse_scale
	if str(snapshot.get("source_location", "")) == "stable":
		var aisle_direction := global_position - visual.global_position
		aisle_direction.y = 0.0
		if aisle_direction.length_squared() > 0.0001:
			snapshot["portrait_camera_direction"] = aisle_direction.normalized()
	return snapshot


func _set_horse_animation(visual: Node3D, moving: bool, pause_when_idle: bool = false) -> void:
	var player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	var clip := _find_horse_animation_clip(player, "Walk" if moving else "Idle")
	visual.set_meta("moving_animation", moving)
	visual.set_meta("motion_animation", clip)
	if pause_when_idle:
		player.pause()
		return
	if clip.is_empty():
		if not moving:
			player.pause()
		return
	if player.current_animation != clip or not player.is_playing():
		player.play(clip)


func _find_horse_animation_clip(player: AnimationPlayer, suffix: String) -> String:
	for raw_clip in player.get_animation_list():
		var clip := str(raw_clip)
		if clip == suffix or clip.ends_with("|" + suffix) or clip.ends_with("/" + suffix):
			return clip
	return ""


func _get_available_horse_anchors(anchor_root: Node3D) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	var desired_order: Array = HORSE_ANCHOR_ORDER_LEVEL_3 if _building_level >= 3 else HORSE_ANCHOR_ORDER_LEVEL_1
	for anchor_id in desired_order:
		for raw_marker in anchor_root.get_children():
			if not raw_marker is Marker3D:
				continue
			var marker := raw_marker as Marker3D
			if str(marker.get_meta("horse_anchor_id", "")) == str(anchor_id) and int(marker.get_meta("required_level", 1)) <= _building_level:
				result.append(marker)
				break
	return result


func _create_horse_visual(horse: Dictionary) -> Node3D:
	var packed := load(HORSE_ASSET) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	var root := HORSE_WORLD_VIEW_SCRIPT.new() as Node3D
	root.name = "Horse_%s" % str(horse.get("horse_id", "unknown")).to_pascal_case()
	model.name = "HorseModel"
	model.position.y = 0.025
	model.scale = Vector3(0.46, 0.36, 0.42)
	root.setup_horse(horse, model)
	return root


func _add_stable_sign(parent: Node3D) -> void:
	var sign := Node3D.new()
	sign.name = "HorseHeadAndShoeStableSign"
	sign.position = Vector3(-2.35, 1.75, 6.52)
	parent.add_child(sign)
	_add_box(sign, "SignBoard", Vector3.ZERO, Vector3(1.55, 0.9, 0.14), DARK_WOOD)
	_add_sphere(sign, "HorseHead", Vector3(-0.1, 0.1, 0.14), 0.24, WEATHERED_WOOD)
	_add_box(sign, "HorseMuzzle", Vector3(0.04, -0.12, 0.16), Vector3(0.34, 0.22, 0.18), WEATHERED_WOOD)
	for side in [-1.0, 1.0]:
		var ear := _add_box(sign, "HorseEar", Vector3(-0.14 + side * 0.13, 0.36, 0.14), Vector3(0.1, 0.28, 0.1), OAK)
		ear.rotation_degrees.z = side * -18.0
	_add_horseshoe(sign, Vector3(0.48, 0.0, 0.16), 0.28)


func _add_harness_loop(parent: Node3D, center: Vector3, radius: float) -> void:
	for segment in range(10):
		var angle := TAU * float(segment) / 10.0
		_add_box(parent, "HarnessLoop", center + Vector3(0.0, cos(angle) * radius, sin(angle) * radius), Vector3(0.09, 0.16, 0.16), LEATHER)


func _add_saddle(parent: Node3D, center: Vector3, scale_value: float) -> void:
	var saddle := Node3D.new()
	saddle.name = "WorkingSaddle"
	saddle.position = center
	saddle.scale = Vector3.ONE * scale_value
	parent.add_child(saddle)
	_add_box(saddle, "SaddleSeat", Vector3(0.0, 0.0, 0.0), Vector3(0.25, 0.48, 0.78), LEATHER)
	_add_box(saddle, "SaddlePommel", Vector3(-0.02, 0.2, -0.3), Vector3(0.24, 0.18, 0.18), DARK_WOOD)
	for side in [-1.0, 1.0]:
		_add_box(saddle, "StirrupLeather", Vector3(-0.18, -0.18, side * 0.3), Vector3(0.05, 0.5, 0.05), LEATHER.darkened(0.1))
		_add_box(saddle, "StirrupIron", Vector3(-0.18, -0.45, side * 0.3), Vector3(0.12, 0.12, 0.12), IRON)


func _add_horseshoe(parent: Node3D, center: Vector3, scale_value: float) -> void:
	var shoe := Node3D.new()
	shoe.name = "Horseshoe"
	shoe.position = center
	shoe.scale = Vector3.ONE * scale_value
	parent.add_child(shoe)
	for segment in range(9):
		var angle := lerpf(deg_to_rad(-145.0), deg_to_rad(145.0), float(segment) / 8.0)
		var piece := _add_box(shoe, "ShoeSegment", Vector3(sin(angle), cos(angle), 0.0), Vector3(0.18, 0.34, 0.08), IRON)
		piece.rotation_degrees.z = -rad_to_deg(angle)


func _add_rail_fence_run(parent: Node3D, center: Vector3, length: float, along_z: bool) -> void:
	var post_count := maxi(2, int(ceil(length / 1.7)) + 1)
	for index in range(post_count):
		var offset := -length * 0.5 + length * float(index) / float(post_count - 1)
		var position_value := center + (Vector3(0.0, 0.9, offset) if along_z else Vector3(offset, 0.9, 0.0))
		_add_box(parent, "FencePost", position_value, Vector3(0.2, 1.65, 0.2), DARK_WOOD)
	for y in [0.52, 1.08]:
		_add_box(parent, "FenceRail", center + Vector3(0.0, y, 0.0), Vector3(0.15, 0.16, length) if along_z else Vector3(length, 0.16, 0.15), WEATHERED_WOOD)


func _add_stall_lantern(parent: Node3D, lantern_name: String, position_value: Vector3, yaw: float, required_level: int) -> void:
	var lantern := _add_scene_prop(parent, lantern_name, LANTERN, position_value, Vector3.ONE * 0.56, Vector3(0.0, yaw, 0.0))
	if lantern != null:
		lantern.set_meta("mounted_to_structure", true)
		lantern.set_meta("mount_surface", "inner_stall_shelter_post")
		lantern.set_meta("functional_lantern_required_level", required_level)


func _apply_functional_lantern_level_visibility() -> void:
	for raw_node in find_children("*", "Node3D", true, false):
		var node := raw_node as Node3D
		if node != null and node.has_meta("functional_lantern_required_level"):
			node.visible = int(node.get_meta("functional_lantern_required_level", 1)) <= _building_level
	if is_inside_tree():
		get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "building_functional_light_controller", "debug_force_refresh")


func _add_hoof_print(parent: Node3D, center: Vector3, angle: float) -> void:
	var print_root := Node3D.new()
	print_root.name = "HoofPrint"
	print_root.position = center
	print_root.rotation_degrees.y = angle
	parent.add_child(print_root)
	for side in [-1.0, 1.0]:
		var edge := _add_box(print_root, "HoofEdge", Vector3(side * 0.09, 0.0, 0.0), Vector3(0.07, 0.012, 0.28), EARTH.darkened(0.18))
		edge.rotation_degrees.y = side * 18.0


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


func _horse_anchor_count() -> int:
	var root := get_node_or_null("../FixtureLayout/HorseAnchors")
	return root.get_child_count() if root != null else 0


func _available_horse_anchor_count() -> int:
	var root := get_node_or_null("../FixtureLayout/HorseAnchors") as Node3D
	return _get_available_horse_anchors(root).size() if root != null else 0


func _visible_real_horse_count() -> int:
	var count := 0
	for raw_visual in _horse_visuals.values():
		var visual := raw_visual as Node3D
		if visual != null and visual.visible:
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
	material.roughness = 0.92
	_material_cache[key] = material
	return material
