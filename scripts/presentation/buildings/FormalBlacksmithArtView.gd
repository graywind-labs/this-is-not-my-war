class_name FormalBlacksmithArtView
extends BuildingArtView


const WALL_STRAIGHT := "res://assets/3d/quaternius/buildings/wall_plaster_straight.glb"
const FLOOR_DARK := "res://assets/3d/quaternius/buildings/floor_wood_dark.glb"
const CHIMNEY := "res://assets/3d/quaternius/buildings/prop_chimney.glb"
const PEG_RACK := "res://assets/3d/quaternius/props/peg_rack.glb"
const WEAPON_STAND := "res://assets/3d/quaternius/props/weapon_stand.glb"
const BUCKET := "res://assets/3d/quaternius/props/bucket_wooden.glb"
const CRATE := "res://assets/3d/quaternius/props/crate_wooden.glb"
const BARREL := "res://assets/3d/quaternius/props/barrel.glb"
const WORKBENCH := "res://assets/3d/quaternius/props/workshop_workbench.glb"
const WORKSHOP_SHELF := "res://assets/3d/quaternius/props/workshop_shelf.glb"
const LANTERN := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const SHIELD := "res://assets/3d/quaternius/props/shield_wooden.glb"
const AMBIENT_FX_SCRIPT := preload("res://scripts/presentation/buildings/SmithyAmbientFX.gd")
const PENDING_OUTPUT_DISPLAY_SCRIPT := preload("res://scripts/presentation/buildings/CraftingPendingOutputDisplay.gd")

const BUILDING_FOOTPRINT := Vector2(14.0, 12.0)
const WALL_HEIGHT := 3.2

var _material_cache: Dictionary = {}


func _ready() -> void:
	_build_formal_smithy()
	super._ready()


func get_art_slice_snapshot() -> Dictionary:
	var ambient_snapshot: Dictionary = {}
	var ambient_fx := get_node_or_null("Interior/ForgeAmbient/AmbientFX")
	if ambient_fx != null and ambient_fx.has_method("debug_get_snapshot"):
		ambient_snapshot = ambient_fx.call("debug_get_snapshot")
	var door_snapshot: Dictionary = {}
	var auto_door := get_node_or_null("Exterior/AutoDoor")
	if auto_door != null and auto_door.has_method("debug_get_snapshot"):
		door_snapshot = auto_door.call("debug_get_snapshot")
	var workstation_states := {}
	var pending_output_display: Dictionary = {}
	var pending_display := get_node_or_null("Interior/PendingOutputDisplay")
	if pending_display != null and pending_display.has_method("debug_get_snapshot"):
		pending_output_display = pending_display.debug_get_snapshot()
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
				"visible": marker.visible,
				"global_position": marker.global_position
			}
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"upgrade_in_progress": _upgrade_in_progress,
		"level_2_visible": _is_visible(NodePath("UpgradeVisuals/Level2")),
		"level_3_visible": _is_visible(NodePath("UpgradeVisuals/Level3")),
		"workstations": workstation_states,
		"pending_output_display": pending_output_display,
		"ambient_fx": ambient_snapshot,
		"auto_door": door_snapshot,
		"navigation_ready": _formal_navigation_ready(),
		"structure_profile": "rear_masonry_forge_with_flat_roofed_fully_open_front_smithing_shed",
		"front_enclosure_profile": "fully_open_with_four_original_roof_posts",
		"front_support_post_count": _direct_child_prefix_count("Exterior", "FrontPost"),
		"roof_profile": "formal_flat_cold_slate_with_low_parapet",
		"roof_module_count": get_node("Roof").get_child_count(),
		"roof_albedo_override": roof_albedo_override,
		"exterior_material_count": _exterior_materials.size(),
		"building_footprint": BUILDING_FOOTPRINT,
		"interior_clear_size": Vector2(13.1, 11.1),
		"future_capacity_reserved": true,
		"active_workstation_visual_count": _active_fixture_visual_count(),
		"level_visual_addition_counts": {
			"level_1": _mesh_count_at("Interior/Level1CommonProps") + _mesh_count_at("ChimneyAssembly"),
			"level_2": _mesh_count_at("UpgradeVisuals/Level2"),
			"level_3": _mesh_count_at("UpgradeVisuals/Level3")
		},
		"roof_structure_addition_count": _mesh_count_at("UpgradeVisuals/Level3/RoofStructureAdditions"),
		"roof_structure_additions_fade_with_roof": additional_roof_fade_paths == [
			NodePath("UpgradeVisuals/Level3/RoofStructureAdditions")
		],
		"chimney_clearance_ready": _formal_chimney_clearance_ready(),
		"chimney_forge_aligned": _formal_chimney_forge_aligned(),
		"smoke_outlet_above_roof": _formal_smoke_outlet_ready(),
		"interior_revealed_for_selection": is_interior_revealed_for_selection(),
		"shell_opacity": maxf(_roof_opacity, _exterior_opacity),
		"collision_authority": "formal_station_static_and_fixture_collision",
		"navigation_authority": "formal_station_navigation_mesh",
		"authority_role": "presentation_only"
	}


func _apply_visual_level(level: int, upgrade_in_progress: bool) -> void:
	super._apply_visual_level(level, upgrade_in_progress)
	_apply_external_fixture_level_visibility()
	_apply_functional_lantern_level_visibility()


func _build_formal_smithy() -> void:
	building_id = "blacksmith"
	roof_near_distance = 58.0
	roof_far_distance = 70.0
	minimum_roof_opacity = 0.06
	fade_exterior_with_roof = true
	minimum_exterior_opacity = 0.06
	interior_reveal_opacity_threshold = 0.72
	interaction_bounds_center = Vector3(0.0, 2.5, 0.0)
	interaction_bounds_size = Vector3(18.0, 5.8, 13.0)
	roof_albedo_override = Color("#515d78")
	preserve_roof_albedo_texture = false
	exterior_albedo_tint = Color("#aeb5c7")
	static_collision_path = NodePath("../StaticCollision")
	workstation_markers_path = NodePath("../FixtureLayout/NPCStands")
	set_meta("art_revision", "t0135_p8ar8")
	set_meta("formal_vertical_slice", true)
	set_meta("footprint_meters", BUILDING_FOOTPRINT)
	_build_foundation_and_floor()
	_build_exterior()
	_build_roof()
	_build_interior()
	_build_chimney_assembly()
	_build_upgrade_visuals()
	additional_exterior_fade_paths = [
		NodePath("UpgradeVisuals/Level2/ExteriorAdditions"),
		NodePath("UpgradeVisuals/Level3/ExteriorAdditions")
	]
	additional_roof_fade_paths = [
		NodePath("UpgradeVisuals/Level3/RoofStructureAdditions")
	]


func _build_foundation_and_floor() -> void:
	var interior := Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_add_box(interior, "StoneFoundation", Vector3(0.0, 0.12, 0.0), Vector3(13.85, 0.24, 11.85), Color("#494c55"))
	var floor := Node3D.new()
	floor.name = "Floor"
	interior.add_child(floor)
	for x in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		for z in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
			_add_scene_prop(floor, "StoneFloor", FLOOR_DARK, Vector3(x, 0.16, z), Vector3(1.0, 0.24, 1.0))
	_add_box(interior, "CentralWorkLane", Vector3(0.0, 0.205, 0.2), Vector3(2.1, 0.045, 9.8), Color("#62636b"))


func _build_exterior() -> void:
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	# Keep the rear furnace zone masonry-heavy while leaving the complete front
	# elevation open. The original four timber posts alone carry the front roof
	# line; there are no wall modules, door leaves, or dedicated door jambs.
	for x in [-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0]:
		_add_scene_prop(exterior, "RearWall", WALL_STRAIGHT, Vector3(x, 0.24, -6.0), Vector3(1.0, 1.02, 1.0))
	for side in [-1.0, 1.0]:
		for z in [-5.0, -3.0, -1.0]:
			_add_scene_prop(
				exterior,
				"SideWall",
				WALL_STRAIGHT,
				Vector3(side * 7.0, 0.24, z),
				Vector3(1.0, 1.02, 1.0),
				Vector3(0.0, 90.0 if side < 0.0 else -90.0, 0.0)
			)
	var dark_timber := Color("#35313a")
	var longitudinal_post_x := [-6.8, -3.5, 3.5, 6.8]
	for index in range(longitudinal_post_x.size()):
		var x: float = longitudinal_post_x[index]
		_add_box(exterior, "FrontPost%02d" % (index + 1), Vector3(x, 1.72, 6.13), Vector3(0.28, 3.35, 0.3), dark_timber)
		_add_box(exterior, "RearPost", Vector3(x, 1.72, -6.13), Vector3(0.28, 3.35, 0.3), dark_timber)
	for side in [-1.0, 1.0]:
		for z in [-4.5, -1.0, 2.5, 5.4]:
			_add_box(exterior, "SidePost", Vector3(side * 7.13, 1.72, z), Vector3(0.3, 3.35, 0.28), dark_timber)
		_add_box(exterior, "OpenBayLowerRail", Vector3(side * 7.13, 0.72, 2.25), Vector3(0.28, 0.18, 6.2), dark_timber)
	_add_box(exterior, "FrontLintel", Vector3(0.0, 3.25, 6.12), Vector3(14.2, 0.3, 0.32), dark_timber)
	_add_box(exterior, "RearLintel", Vector3(0.0, 3.25, -6.12), Vector3(14.2, 0.3, 0.32), dark_timber)
	_add_box(exterior, "SmithySign", Vector3(0.0, 3.72, 6.24), Vector3(2.5, 0.66, 0.16), Color("#4b5269"))
	_add_box(exterior, "AnvilEmblemTop", Vector3(0.0, 3.78, 6.34), Vector3(0.86, 0.16, 0.18), Color("#222830"))
	_add_box(exterior, "AnvilEmblemStem", Vector3(0.0, 3.57, 6.34), Vector3(0.28, 0.28, 0.18), Color("#222830"))


func _direct_child_prefix_count(parent_path: String, prefix: String) -> int:
	var parent := get_node_or_null(parent_path)
	if parent == null:
		return 0
	var count := 0
	for child in parent.get_children():
		if str(child.name).begins_with(prefix):
			count += 1
	return count


func _build_roof() -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.set_meta("roof_fade_candidate", true)
	add_child(roof)
	var slate := Color("#4a5672")
	var ridge := Color("#2f374b")
	_add_box(roof, "FlatSlateDeck", Vector3(0.0, 3.52, 0.0), Vector3(14.8, 0.24, 12.8), slate)
	_add_box(roof, "NorthParapetCap", Vector3(0.0, 3.72, -6.28), Vector3(14.9, 0.28, 0.32), ridge)
	_add_box(roof, "SouthParapetCap", Vector3(0.0, 3.72, 6.28), Vector3(14.9, 0.28, 0.32), ridge)
	_add_box(roof, "WestParapetCap", Vector3(-7.28, 3.72, 0.0), Vector3(0.32, 0.28, 12.3), ridge)
	_add_box(roof, "EastParapetCap", Vector3(7.28, 3.72, 0.0), Vector3(0.32, 0.28, 12.3), ridge)
	for x in [-6.5, -4.3, -2.15, 0.0, 2.15, 4.3, 6.5]:
		_add_box(roof, "FlatSlateSeam", Vector3(x, 3.66, 0.0), Vector3(0.07, 0.04, 12.2), ridge)


func _build_interior() -> void:
	var interior := get_node("Interior") as Node3D
	var stations := Node3D.new()
	stations.name = "Level1StationDecor"
	interior.add_child(stations)
	_build_station_decor(stations, "Forge01", Vector3(-4.0, 0.0, -3.65), -1.0)
	_build_station_decor(stations, "Forge02", Vector3(4.0, 0.0, -3.65), 1.0)
	_add_scene_prop(stations, "RearToolRack", PEG_RACK, Vector3(0.0, 0.18, -5.55), Vector3(1.35, 1.35, 1.35), Vector3(0.0, 0.0, 0.0))
	_add_scene_prop(stations, "WaterBarrel", BARREL, Vector3(6.0, 0.2, 2.0), Vector3(1.15, 1.15, 1.15))
	_add_scene_prop(stations, "OreCrateA", CRATE, Vector3(-5.8, 0.2, 4.4), Vector3(0.82, 0.82, 0.82), Vector3(0.0, 16.0, 0.0))
	_add_scene_prop(stations, "OreCrateB", CRATE, Vector3(-5.0, 0.2, 4.75), Vector3(0.68, 0.68, 0.68), Vector3(0.0, -12.0, 0.0))
	var common_props := Node3D.new()
	common_props.name = "Level1CommonProps"
	interior.add_child(common_props)
	_add_scene_prop(common_props, "RepairWorkbench", WORKBENCH, Vector3(-5.55, 0.2, 1.65), Vector3.ONE * 1.08, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(common_props, "MaterialShelf", WORKSHOP_SHELF, Vector3(5.75, 0.2, -1.45), Vector3.ONE * 1.05, Vector3(0.0, -90.0, 0.0))
	# The imported lantern mesh grows upward from its origin. Keep its complete
	# AABB below the lowest roof plane instead of letting it pierce the slate.
	_add_smithy_lantern(common_props, "RearForgeLantern", Vector3(2.2, 1.72, -5.55), 1, "rear_masonry_wall")
	_add_smithy_lantern(common_props, "SmithingBayLantern", Vector3(-2.2, 1.72, -5.55), 1, "rear_masonry_wall")
	_add_box(common_props, "QuenchTrough", Vector3(1.45, 0.48, 4.65), Vector3(1.75, 0.72, 0.9), Color("#46515a"))
	_add_box(common_props, "QuenchWater", Vector3(1.45, 0.86, 4.65), Vector3(1.48, 0.04, 0.66), Color("#304f62"))
	_add_box(common_props, "Forge01HeatApron", Vector3(-4.0, 0.235, -3.65), Vector3(3.0, 0.05, 2.0), Color("#34373d"))
	_add_box(common_props, "Forge02HeatApron", Vector3(4.0, 0.235, -3.65), Vector3(3.0, 0.05, 2.0), Color("#34373d"))
	_add_box(common_props, "CoalBunker", Vector3(5.72, 0.48, 4.72), Vector3(1.7, 0.72, 1.25), Color("#40372f"))
	for offset in [Vector3(-0.42, 0.42, -0.2), Vector3(0.0, 0.5, 0.1), Vector3(0.44, 0.38, -0.05), Vector3(-0.1, 0.72, -0.2)]:
		var coal := _add_box(common_props, "CoalChunk", Vector3(5.72, 0.48, 4.72) + offset, Vector3(0.34, 0.28, 0.38), Color("#17191d"))
		coal.rotation_degrees = Vector3(12.0, offset.x * 45.0, 9.0)
	for index in range(5):
		_add_box(common_props, "IronStock", Vector3(-6.05 + float(index) * 0.23, 0.43, 3.55), Vector3(0.1, 0.1, 1.65), Color("#4d535c"))
	_add_box(common_props, "StockRackLowerRail", Vector3(-5.55, 0.38, 3.55), Vector3(1.65, 0.14, 0.16), Color("#44362f"))
	_add_box(common_props, "StockRackUpperRail", Vector3(-5.55, 0.92, 3.55), Vector3(1.65, 0.14, 0.16), Color("#44362f"))
	for x in [-6.28, -4.82]:
		_add_box(common_props, "StockRackPost", Vector3(x, 0.66, 3.55), Vector3(0.14, 1.05, 0.14), Color("#44362f"))
	_add_box(common_props, "ScrapBin", Vector3(-5.65, 0.45, -0.55), Vector3(1.55, 0.68, 1.0), Color("#393d45"))
	for offset in [-0.45, -0.12, 0.24, 0.48]:
		var scrap := _add_box(common_props, "ScrapMetal", Vector3(-5.65 + offset, 0.87, -0.55 + offset * 0.35), Vector3(0.48, 0.08, 0.12), Color("#686f79"))
		scrap.rotation_degrees.y = offset * 75.0
	_build_forge_ambient(interior)
	_add_pending_output_display(interior)


func _add_pending_output_display(interior: Node3D) -> void:
	var display := Node3D.new()
	display.name = "PendingOutputDisplay"
	display.set_script(PENDING_OUTPUT_DISPLAY_SCRIPT)
	display.set("building_id", "blacksmith")
	interior.add_child(display)


func _build_chimney_assembly() -> void:
	var chimney := Node3D.new()
	chimney.name = "ChimneyAssembly"
	add_child(chimney)
	_add_scene_prop(chimney, "StoneChimney", CHIMNEY, Vector3(0.0, 1.65, -4.85), Vector3(1.12, 1.35, 1.12))
	_add_box(chimney, "InteriorSmokeHood", Vector3(0.0, 2.42, -4.85), Vector3(1.8, 0.28, 1.55), Color("#343840"))
	_add_box(chimney, "VerticalFlue", Vector3(0.0, 3.48, -4.85), Vector3(0.72, 2.0, 0.72), Color("#41454d"))
	var outlet := Marker3D.new()
	outlet.name = "SmokeOutlet"
	outlet.position = Vector3(0.0, 5.85, -4.85)
	chimney.add_child(outlet)
	var smoke := get_node_or_null("Interior/ForgeAmbient/AmbientFX/Smoke") as GPUParticles3D
	if smoke != null:
		smoke.global_position = outlet.global_position


func _build_station_decor(parent: Node3D, prefix: String, anvil_position: Vector3, side: float) -> void:
	_add_scene_prop(parent, "%sQuenchBucket" % prefix, BUCKET, anvil_position + Vector3(side * 1.12, 0.18, 0.45), Vector3.ONE * 1.12)
	_add_scene_prop(parent, "%sToolRack" % prefix, PEG_RACK, Vector3(anvil_position.x + side * 0.95, 0.18, -5.5), Vector3.ONE * 1.05)
	var rest_center := anvil_position + Vector3(-side * 0.72, 0.0, -0.3)
	_add_box(parent, "%sToolRestTop" % prefix, rest_center + Vector3(0.0, 0.47, 0.0), Vector3(0.72, 0.14, 0.38), Color("#41352e"))
	for leg_x in [-0.27, 0.27]:
		_add_box(parent, "%sToolRestLeg" % prefix, rest_center + Vector3(leg_x, 0.27, 0.0), Vector3(0.12, 0.42, 0.22), Color("#342a25"))
	_add_box(parent, "%sToolRestLowerBrace" % prefix, rest_center + Vector3(0.0, 0.17, 0.0), Vector3(0.62, 0.10, 0.16), Color("#342a25"))


func _build_forge_ambient(interior: Node3D) -> void:
	var forge_ambient := Node3D.new()
	forge_ambient.name = "ForgeAmbient"
	forge_ambient.position = Vector3(0.0, 0.0, -4.85)
	forge_ambient.set_meta("open_direction_local", Vector3(0.0, 0.0, 1.0))
	interior.add_child(forge_ambient)
	var masonry := Node3D.new()
	masonry.name = "ForgeMasonry"
	forge_ambient.add_child(masonry)
	_add_box(masonry, "FireBed", Vector3(0.0, 0.48, 0.0), Vector3(1.85, 0.9, 1.55), Color("#4a4d54"))
	_add_box(masonry, "RearFireWall", Vector3(0.0, 1.25, -0.62), Vector3(1.9, 1.55, 0.28), Color("#555860"))
	_add_box(masonry, "LeftCheek", Vector3(-0.82, 1.0, 0.05), Vector3(0.28, 1.05, 1.25), Color("#555860"))
	_add_box(masonry, "RightCheek", Vector3(0.82, 1.0, 0.05), Vector3(0.28, 1.05, 1.25), Color("#555860"))
	_add_box(masonry, "FireLip", Vector3(0.0, 0.9, 0.66), Vector3(1.9, 0.22, 0.24), Color("#353941"))
	var bellows := Node3D.new()
	bellows.name = "Bellows"
	bellows.position = Vector3(-1.65, 0.58, 0.05)
	forge_ambient.add_child(bellows)
	_add_box(bellows, "LowerBoard", Vector3.ZERO, Vector3(0.72, 0.1, 1.0), Color("#5a4434"))
	_add_box(bellows, "LeatherBody", Vector3(0.0, 0.18, 0.0), Vector3(0.62, 0.28, 0.86), Color("#63311f"))
	_add_box(bellows, "UpperBoard", Vector3(0.0, 0.34, 0.0), Vector3(0.72, 0.1, 1.0), Color("#5a4434"))
	var handle := Node3D.new()
	handle.name = "Handle"
	handle.position = Vector3(0.0, 0.36, 0.78)
	bellows.add_child(handle)
	_add_box(handle, "HandleMesh", Vector3(0.0, 0.0, 0.38), Vector3(0.12, 0.12, 0.9), Color("#4b372b"))
	var ambient := Node3D.new()
	ambient.name = "AmbientFX"
	ambient.position = Vector3(0.0, 0.7, 0.0)
	ambient.set_script(AMBIENT_FX_SCRIPT)
	var fuel_glow := _add_glowing_sphere(ambient, "GlowingFuelBed", Vector3(0.0, -0.03, 0.0), 0.34, Color("#ff4b12"))
	fuel_glow.scale = Vector3(2.0, 0.28, 0.82)
	_add_glowing_sphere(ambient, "FlameCore", Vector3(0.0, 0.24, 0.0), 0.34, Color("#ff3d08"))
	_add_glowing_sphere(ambient, "FlameTip", Vector3(0.04, 0.52, 0.0), 0.2, Color("#ffc33a"))
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.position = Vector3(0.0, 0.4, 0.15)
	light.light_color = Color("#ff6d28")
	light.light_energy = 3.6
	light.omni_range = 6.5
	light.shadow_enabled = true
	ambient.add_child(light)
	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 22
	sparks.lifetime = 1.2
	sparks.randomness = 0.8
	sparks.visibility_aabb = AABB(Vector3(-2.0, -0.5, -2.0), Vector3(4.0, 5.0, 4.0))
	ambient.add_child(sparks)
	var smoke := GPUParticles3D.new()
	smoke.name = "Smoke"
	# AmbientFX is rooted at the hearth. Emit only above the permanent flue outlet,
	# so smoke cannot visually pass through the roof plane.
	smoke.position = Vector3(0.0, 5.15, 0.0)
	smoke.amount = 16
	smoke.lifetime = 3.8
	smoke.randomness = 0.65
	smoke.visibility_aabb = AABB(Vector3(-2.0, -0.5, -2.0), Vector3(4.0, 6.5, 4.0))
	ambient.add_child(smoke)
	forge_ambient.add_child(ambient)


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
	for side_index in range(2):
		var x := -6.5 if side_index == 0 else 6.5
		var side_name := "West" if side_index == 0 else "East"
		_add_box(
			level_2_exterior,
			"ReinforcedWallBrace%s" % side_name,
			Vector3(x, 1.78, 0.0),
			Vector3(0.34, 3.2, 0.34),
			Color("#2e3038")
		)
	_add_box(level_2_exterior, "ChimneyCrown", Vector3(0.0, 5.55, -4.85), Vector3(1.1, 0.28, 1.1), Color("#343943"))
	_add_box(level_2_exterior, "ChimneyBand", Vector3(0.0, 4.75, -4.85), Vector3(0.86, 0.15, 0.86), Color("#222730"))
	var fuel_shelter := Node3D.new()
	fuel_shelter.name = "FuelShelter"
	level_2_exterior.add_child(fuel_shelter)
	_add_box(fuel_shelter, "RaisedStoneDeck", Vector3(7.3, 0.26, 3.1), Vector3(1.25, 0.2, 3.6), Color("#454952"))
	var fuel_roof := _add_box(fuel_shelter, "SlateLeanToRoof", Vector3(7.28, 2.3, 3.1), Vector3(1.25, 0.14, 3.7), Color("#465169"))
	fuel_roof.rotation_degrees.z = -8.0
	_add_box(fuel_shelter, "OuterFascia", Vector3(7.72, 2.22, 3.1), Vector3(0.16, 0.18, 3.5), Color("#34313a"))
	for z in [1.55, 4.65]:
		_add_box(fuel_shelter, "OuterPost", Vector3(7.75, 1.16, z), Vector3(0.2, 2.2, 0.2), Color("#34313a"))
		var brace := _add_box(fuel_shelter, "KneeBrace", Vector3(7.66, 1.82, z), Vector3(0.16, 0.14, 0.78), Color("#403740"))
		brace.rotation_degrees.x = 42.0 if z < 3.1 else -42.0
	_add_box(fuel_shelter, "RearStorageRail", Vector3(6.82, 1.02, 3.1), Vector3(0.16, 1.65, 3.35), Color("#413840"))
	_add_scene_prop(fuel_shelter, "FuelBarrel", BARREL, Vector3(7.2, 0.36, 3.8), Vector3.ONE * 0.86)
	_add_scene_prop(fuel_shelter, "OreCrate", CRATE, Vector3(7.2, 0.32, 2.38), Vector3.ONE * 0.68, Vector3(0.0, 12.0, 0.0))
	var level_2_interior := Node3D.new()
	level_2_interior.name = "InteriorAdditions"
	level_2.add_child(level_2_interior)
	_add_scene_prop(level_2_interior, "FinishedWeaponStand", WEAPON_STAND, Vector3(5.6, 0.2, 0.0), Vector3.ONE * 1.05, Vector3(0.0, -90.0, 0.0))
	_add_scene_prop(level_2_interior, "CharcoalShelf", WORKSHOP_SHELF, Vector3(-5.7, 0.2, -1.1), Vector3.ONE * 1.0, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(level_2_interior, "QualityShield", SHIELD, Vector3(6.68, 1.75, 2.0), Vector3.ONE * 0.85, Vector3(0.0, -90.0, 0.0))
	_add_smithy_lantern(level_2_interior, "ServiceLantern", Vector3(6.55, 1.72, -3.0), 2, "east_masonry_wall")
	_build_grindstone(level_2_interior)
	_add_box(level_2_interior, "TemperingRack", Vector3(2.9, 0.72, -4.9), Vector3(1.7, 1.25, 0.34), Color("#3f3631"))
	for x in [2.35, 2.72, 3.09, 3.46]:
		_add_box(level_2_interior, "HangingTool", Vector3(x, 1.05, -4.68), Vector3(0.08, 0.7, 0.08), Color("#555d68"))
	var level_3 := Node3D.new()
	level_3.name = "Level3"
	level_3.visible = false
	upgrades.add_child(level_3)
	var level_3_interior := Node3D.new()
	level_3_interior.name = "InteriorAdditions"
	level_3.add_child(level_3_interior)
	var level_3_roof_structure := Node3D.new()
	level_3_roof_structure.name = "RoofStructureAdditions"
	level_3.add_child(level_3_roof_structure)
	_build_station_decor(level_3_interior, "Forge03", Vector3(-4.0, 0.0, 0.35), -1.0)
	_add_smithy_lantern(level_3_interior, "Forge03Lantern", Vector3(-6.55, 1.72, -3.0), 3, "west_masonry_wall")
	_add_scene_prop(level_3_interior, "MasterToolWall", WORKSHOP_SHELF, Vector3(3.75, 0.2, -5.55), Vector3.ONE * 1.12)
	_add_scene_prop(level_3_interior, "FinishedGoodsCrate", CRATE, Vector3(5.75, 0.2, 3.0), Vector3.ONE * 0.76, Vector3(0.0, 18.0, 0.0))
	_add_box(level_3_roof_structure, "CeilingHoistBeam", Vector3(0.0, 2.8, 1.0), Vector3(5.2, 0.22, 0.28), Color("#343039"))
	# Chain and hook are one ceiling-mounted assembly. Keep them in the same roof
	# fade branch so the support cannot disappear while a lone rod remains visible.
	_add_box(level_3_roof_structure, "HoistChain", Vector3(0.0, 1.95, 1.0), Vector3(0.08, 1.55, 0.08), Color("#272c34"))
	_add_box(level_3_roof_structure, "HoistHook", Vector3(0.0, 1.18, 1.0), Vector3(0.35, 0.12, 0.18), Color("#555d68"))
	for row in range(2):
		for column in range(4):
			_add_box(level_3_interior, "Ingot", Vector3(2.5 + float(column) * 0.38, 0.38 + float(row) * 0.18, 4.75), Vector3(0.3, 0.14, 0.65), Color("#747b86"))
	var level_3_exterior := Node3D.new()
	level_3_exterior.name = "ExteriorAdditions"
	level_3.add_child(level_3_exterior)
	var finishing_bay := Node3D.new()
	finishing_bay.name = "FinishingBay"
	level_3_exterior.add_child(finishing_bay)
	_add_box(finishing_bay, "RaisedStoneDeck", Vector3(-7.3, 0.26, 0.5), Vector3(1.25, 0.2, 5.2), Color("#454952"))
	var finishing_roof := _add_box(finishing_bay, "SlateLeanToRoof", Vector3(-7.28, 2.38, 0.5), Vector3(1.25, 0.14, 5.45), Color("#49536d"))
	finishing_roof.rotation_degrees.z = 8.0
	_add_box(finishing_bay, "OuterFascia", Vector3(-7.72, 2.3, 0.5), Vector3(0.16, 0.18, 5.15), Color("#34313a"))
	for z in [-1.8, 2.8]:
		_add_box(finishing_bay, "OuterPost", Vector3(-7.75, 1.16, z), Vector3(0.2, 2.2, 0.2), Color("#34313a"))
		var brace := _add_box(finishing_bay, "KneeBrace", Vector3(-7.66, 1.82, z), Vector3(0.16, 0.14, 0.78), Color("#403740"))
		brace.rotation_degrees.x = 42.0 if z < 0.5 else -42.0
	_add_scene_prop(finishing_bay, "FinishedWeaponStand", WEAPON_STAND, Vector3(-7.12, 0.32, -0.72), Vector3.ONE * 0.8, Vector3(0.0, 90.0, 0.0))
	_add_scene_prop(finishing_bay, "QuenchBucket", BUCKET, Vector3(-7.18, 0.32, 1.35), Vector3.ONE * 0.82)
	_add_scene_prop(finishing_bay, "ShipmentCrate", CRATE, Vector3(-7.12, 0.32, 2.15), Vector3.ONE * 0.62, Vector3(0.0, -15.0, 0.0))
	_add_box(finishing_bay, "MasterSmithEmblem", Vector3(-7.86, 2.65, 2.3), Vector3(0.1, 0.44, 1.1), Color("#3f4965"))


func _build_grindstone(parent: Node3D) -> void:
	var frame := Node3D.new()
	frame.name = "PedalGrindstone"
	# Keep the primary door/central work lane completely clear. The sharpening
	# station belongs in the east service bay beside storage, not in the entrance.
	frame.position = Vector3(3.2, 0.0, 3.1)
	frame.set_meta("service_bay", "east_finishing")
	frame.set_meta("primary_entry_clear", true)
	parent.add_child(frame)
	_add_box(frame, "WoodFrame", Vector3(0.0, 0.5, 0.0), Vector3(1.4, 0.18, 0.8), Color("#4a392f"))
	_add_box(frame, "LeftLeg", Vector3(-0.52, 0.35, 0.0), Vector3(0.14, 0.7, 0.55), Color("#42342c"))
	_add_box(frame, "RightLeg", Vector3(0.52, 0.35, 0.0), Vector3(0.14, 0.7, 0.55), Color("#42342c"))
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.58
	wheel_mesh.bottom_radius = 0.58
	wheel_mesh.height = 0.28
	wheel_mesh.radial_segments = 12
	wheel_mesh.material = _material(Color("#777a80"))
	var wheel := MeshInstance3D.new()
	wheel.name = "GrindingWheel"
	wheel.position = Vector3(0.0, 1.1, 0.0)
	wheel.rotation_degrees.z = 90.0
	wheel.mesh = wheel_mesh
	frame.add_child(wheel)


func _apply_external_fixture_level_visibility() -> void:
	var fixture_root := get_node_or_null("../FixtureLayout")
	if fixture_root == null:
		return
	for branch_name in ["Visuals", "NPCStands"]:
		var branch := fixture_root.get_node_or_null(branch_name)
		if branch == null:
			continue
		for raw_child in branch.get_children():
			if raw_child is Node3D:
				(raw_child as Node3D).visible = (
					branch_name == "Visuals"
					and int(raw_child.get_meta("required_level", 1)) <= _building_level
				)


func _add_smithy_lantern(parent: Node3D, lantern_name: String, position_value: Vector3, required_level: int, mount_surface: String) -> void:
	var support := Node3D.new()
	support.name = "Support_%s" % lantern_name
	support.position = position_value
	support.set_meta("functional_lantern_support", true)
	support.set_meta("functional_lantern_required_level", required_level)
	support.set_meta("structural_mount_kind", mount_surface)
	parent.add_child(support)
	if mount_surface == "east_masonry_wall":
		support.rotation_degrees.y = -90.0
	elif mount_surface == "west_masonry_wall":
		support.rotation_degrees.y = 90.0
	match mount_surface:
		"rear_masonry_wall", "east_masonry_wall", "west_masonry_wall":
			_add_box(support, "WallBackplate", Vector3(0.0, 0.54, -0.52), Vector3(0.46, 0.72, 0.12), Color("#252a31"))
			_add_box(support, "WallArm", Vector3(0.0, 0.56, -0.27), Vector3(0.14, 0.14, 0.58), Color("#343039"))
			var rear_brace := _add_box(support, "WallKneeBrace", Vector3(0.0, 0.3, -0.3), Vector3(0.12, 0.62, 0.12), Color("#343039"))
			rear_brace.rotation_degrees.x = -38.0
	var lantern := _add_scene_prop(support, lantern_name, LANTERN, Vector3.ZERO, Vector3.ONE * 0.72)
	if lantern != null:
		lantern.set_meta("mounted_to_structure", true)
		lantern.set_meta("mount_surface", mount_surface)
		lantern.set_meta("functional_lantern_required_level", required_level)


func _apply_functional_lantern_level_visibility() -> void:
	for raw_node in find_children("*", "Node3D", true, false):
		var node := raw_node as Node3D
		if node != null and node.has_meta("functional_lantern_required_level"):
			node.visible = int(node.get_meta("functional_lantern_required_level", 1)) <= _building_level
	if is_inside_tree():
		get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "building_functional_light_controller", "debug_force_refresh")


func _active_fixture_visual_count() -> int:
	var visual_root := get_node_or_null("../FixtureLayout/Visuals")
	if visual_root == null:
		return 0
	var count := 0
	for raw_child in visual_root.get_children():
		if raw_child is Node3D and (raw_child as Node3D).visible:
			count += 1
	return count


func _formal_navigation_ready() -> bool:
	var controller := get_node_or_null("/root/Main/Presentation/StationLayoutController")
	if controller == null or not controller.has_method("get_validation_snapshot"):
		return false
	var snapshot: Dictionary = controller.call("get_validation_snapshot")
	var navigation := snapshot.get("production_navigation", {}) as Dictionary
	return bool(navigation.get("available", false)) and bool(navigation.get("enabled", false))


func _formal_chimney_clearance_ready() -> bool:
	var chimney := get_node_or_null("ChimneyAssembly/StoneChimney") as Node3D
	return chimney != null and chimney.position.y >= 1.6 and chimney.scale.y >= 1.3


func _formal_chimney_forge_aligned() -> bool:
	var chimney := get_node_or_null("ChimneyAssembly/StoneChimney") as Node3D
	if chimney == null:
		return false
	return Vector2(chimney.position.x, chimney.position.z).distance_to(Vector2(0.0, -4.85)) <= 0.1


func _formal_smoke_outlet_ready() -> bool:
	var outlet := get_node_or_null("ChimneyAssembly/SmokeOutlet") as Marker3D
	var smoke := get_node_or_null("Interior/ForgeAmbient/AmbientFX/Smoke") as GPUParticles3D
	return outlet != null and smoke != null and outlet.position.y > 4.5 and smoke.global_position.y >= outlet.global_position.y - 0.05


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
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	mesh.material = _material(color)
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_glowing_sphere(parent: Node3D, node_name: String, center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 5.0
	mesh.material = material
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
