extends SceneTree

const MAIN_PATH := "res://scenes/main/Main.tscn"
const FIXTURE_PATH := "res://data/building_fixture_layouts.json"
const PLAN_PATH := "res://data/presentation/station_spatial_plan.json"
const REQUIRED_ASSETS := [
	"res://assets/3d/quaternius/buildings/warehouse_wall_woodgrid.glb",
	"res://assets/3d/quaternius/buildings/main_hall_roof.glb",
	"res://assets/3d/quaternius/buildings/roof_round_tiles_4x4.glb",
	"res://assets/3d/quaternius/props/warehouse_bag.glb",
	"res://assets/3d/quaternius/props/warehouse_metal_crate.glb",
	"res://assets/3d/quaternius/props/warehouse_apple_barrel.glb",
	"res://assets/3d/quaternius/props/warehouse_chest.glb",
	"res://assets/3d/quaternius/props/warehouse_shelf_arch.glb",
	"res://assets/3d/quaternius/buildings/warehouse_wagon.glb"
]


func _init() -> void:
	var config := _load_json(FIXTURE_PATH)
	var plan := _load_json(PLAN_PATH)
	var packed := load(MAIN_PATH) as PackedScene
	if config.is_empty() or plan.is_empty() or packed == null:
		_fail("A3b12R inputs unavailable")
		return
	for asset_path in REQUIRED_ASSETS:
		if not ResourceLoader.exists(asset_path):
			_fail("A3b12R imported Quaternius asset unavailable: %s" % asset_path)
			return
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 4:
		await process_frame
		await physics_frame
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var warehouse := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Warehouse") as Node3D
	var formal := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var region := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation") as NavigationRegion3D
	var fixture_root := warehouse.get_node_or_null("FixtureLayout") if warehouse != null else null
	if controller == null or building_system == null or fixture_root == null or formal == null or region == null:
		_fail("A3b12R hierarchy incomplete")
		return
	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("A3b12R config errors: %s" % snapshot)
		return
	var warehouse_art := warehouse.get_node_or_null("WarehouseArt") as Node3D
	var envelope := warehouse.get_node_or_null("Envelope") as MeshInstance3D
	if (
		warehouse_art == null
		or str(warehouse_art.get_meta("art_revision", "")) != "t0132_p2r2"
		or not bool(warehouse_art.get_meta("non_enterable", false))
		or str(warehouse_art.get_meta("cargo_display_authority", "")) != "symbolic_categories_not_inventory_counts"
		or envelope == null
		or envelope.visible
	):
		_fail("A3b12R warehouse exterior did not replace the blockout envelope")
		return
	if building_system.is_building_enterable("warehouse") or not (building_system.get_building("warehouse").get("workstations", []) as Array).is_empty():
		_fail("Warehouse must remain non-enterable with zero NPC workstations")
		return
	for node_path in [
		"BaseVisuals/SolidWarehouseMass/StoneLoadingPlinth",
		"BaseVisuals/SolidWarehouseMass/LowerMasonryStore",
		"BaseVisuals/SolidWarehouseMass/SealedTimberStore",
		"BaseVisuals/Exterior/LoadingDoor/DoorLeaf",
		"BaseVisuals/Exterior/LoadingDoor/HoistPulley",
		"BaseVisuals/LoadingApron/StoneRamp",
		"Roof/ContinuousMainRoof",
		"Roof/LoadingCanopy"
	]:
		if warehouse_art.get_node_or_null(node_path) == null:
			_fail("A3b12R warehouse architectural detail missing: %s" % node_path)
			return
	var visuals := fixture_root.get_node_or_null("Visuals")
	var collisions := fixture_root.get_node_or_null("StaticCollision")
	var stands := fixture_root.get_node_or_null("NPCStands")
	if visuals == null or collisions == null or stands == null or visuals.get_child_count() != 7 or collisions.get_child_count() != 7 or stands.get_child_count() != 0:
		_fail("Warehouse 7/7/0 hierarchy drifted")
		return
	var cfg := ((config.get("buildings", {}) as Dictionary).get("warehouse", {}) as Dictionary)
	var levels := {1: 0, 2: 0, 3: 0}
	var cargo_nodes := 0
	for raw in cfg.get("fixtures", []):
		var fixture := raw as Dictionary
		var fixture_id := str(fixture.get("id", ""))
		var required_level := int(fixture.get("required_level", 0))
		levels[required_level] = int(levels.get(required_level, 0)) + 1
		var visual := _find_by_meta(visuals, "fixture_id", fixture_id) as Node3D
		var body := _find_by_meta(collisions, "fixture_id", fixture_id) as StaticBody3D
		if (
			not str(fixture.get("workstation_id", "")).is_empty()
			or fixture.has("primitive_visual")
			or str(fixture.get("asset_path", "")).is_empty()
			or (fixture.get("cargo_categories", []) as Array).is_empty()
			or visual == null
			or body == null
		):
			_fail("Warehouse imported fixture contract drifted: %s" % fixture_id)
			return
		if bool(visual.get_meta("inventory_count_authority", true)):
			_fail("Warehouse category art must not claim inventory count authority: %s" % fixture_id)
			return
		cargo_nodes += _count_named_cargo_nodes(visual)
	if levels != {1: 5, 2: 1, 3: 1}:
		_fail("Warehouse visible upgrade increments drifted: %s" % levels)
		return
	if cargo_nodes < 12:
		_fail("A3b12R warehouse cargo category readability is too sparse: %d" % cargo_nodes)
		return
	var loading_fixture := _find_by_meta(collisions, "fixture_id", "warehouse_level_one_loading_pallet") as StaticBody3D
	var loading_shape := loading_fixture.get_node_or_null("CollisionShape3D") as CollisionShape3D if loading_fixture != null else null
	var loading_box := loading_shape.shape as BoxShape3D if loading_shape != null else null
	if loading_box == null or loading_box.size.z < 4.0 or loading_box.size.y < 1.6:
		_fail("Warehouse wagon collision does not match its visible footprint")
		return
	var aisle := BoxShape3D.new()
	aisle.size = Vector3(2.4, 1.6, 8.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = aisle
	query.transform = Transform3D(warehouse.global_basis.orthonormalized(), warehouse.to_global(Vector3(0.0, 0.8, 0.4)))
	query.collision_mask = 1
	for hit in formal.get_world_3d().direct_space_state.intersect_shape(query, 64):
		var collider := (hit as Dictionary).get("collider") as StaticBody3D
		if collider != null and str(collider.get_meta("collision_category", "")) == "building_fixture":
			_fail("Warehouse central loading aisle is blocked by %s" % str(collider.get_meta("fixture_id", "")))
			return
	controller.debug_set_preview_enabled(true)
	for _i in 3:
		await physics_frame
	var map := region.get_navigation_map()
	NavigationServer3D.map_force_update(map)
	var stages := ((plan.get("enemy_route", {}) as Dictionary).get("stages", []) as Array)
	var points: Dictionary = {}
	for raw in stages:
		points[str((raw as Dictionary).get("id", ""))] = _v2((raw as Dictionary).get("point", []))
	var offset := formal.global_position
	var path := NavigationServer3D.map_get_path(
		map,
		offset + Vector3(points["front_gate"].x, 0.0, points["front_gate"].y),
		offset + Vector3(points["warehouse"].x, 0.0, points["warehouse"].y),
		true
	)
	controller.debug_set_preview_enabled(false)
	if path.size() < 3:
		_fail("Warehouse exterior attack point is not reachable from front gate: %s" % path)
		return
	print("T0129C A3b12R warehouse verification passed: %s" % JSON.stringify({
		"fixtures": 7,
		"levels": levels,
		"cargo_detail_nodes": cargo_nodes,
		"attack_route_points": path.size(),
		"workstations": 0
	}))
	quit(0)


func _find_by_meta(parent: Node, key: String, value: String) -> Node:
	for child in parent.get_children():
		if str(child.get_meta(key, "")) == value:
			return child
	return null


func _count_named_cargo_nodes(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		var node_name := str(child.name).to_lower()
		for marker in ["cargo", "food", "sack", "crate", "reserve", "chest", "equipment", "shelf"]:
			if node_name.contains(marker):
				count += 1
				break
	return count


func _load_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _v2(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() >= 2 else Vector2.ZERO


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
