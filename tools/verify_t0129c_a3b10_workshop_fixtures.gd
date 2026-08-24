extends SceneTree

const MAIN_PATH := "res://scenes/main/Main.tscn"
const FIXTURE_PATH := "res://data/building_fixture_layouts.json"

func _init() -> void:
	var config := _load_json(FIXTURE_PATH)
	var packed := load(MAIN_PATH) as PackedScene
	if config.is_empty() or packed == null: _fail("A3b10R inputs unavailable"); return
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 4: await process_frame; await physics_frame
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var workshop := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop") as Node3D
	var region := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation") as NavigationRegion3D
	var fixture_root := workshop.get_node_or_null("FixtureLayout") if workshop != null else null
	if controller == null or building_system == null or fixture_root == null or region == null: _fail("A3b10R hierarchy incomplete"); return
	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0: _fail("A3b10R config errors: %s" % snapshot); return
	var visuals := fixture_root.get_node_or_null("Visuals")
	var collisions := fixture_root.get_node_or_null("StaticCollision")
	var stands := fixture_root.get_node_or_null("NPCStands")
	if visuals == null or collisions == null or stands == null or visuals.get_child_count() != 7 or collisions.get_child_count() != 7 or stands.get_child_count() != 3: _fail("Workshop 7/7/3 hierarchy drifted"); return
	var cfg := ((config.get("buildings", {}) as Dictionary).get("workshop", {}) as Dictionary)
	var mapped: Dictionary = {}
	var shared_count := 0
	var route_sizes: Dictionary = {}
	var roles: Dictionary = {}
	controller.debug_set_preview_enabled(true)
	for _i in 3: await physics_frame
	var map := region.get_navigation_map()
	NavigationServer3D.map_force_update(map)
	for raw in cfg.get("fixtures", []):
		var fixture := raw as Dictionary
		var fixture_id := str(fixture.get("id", ""))
		var visual := _find_by_meta(visuals, "fixture_id", fixture_id) as Node3D
		var body := _find_by_meta(collisions, "fixture_id", fixture_id) as StaticBody3D
		if visual == null or body == null: _fail("Workshop fixture projection missing: %s" % fixture_id); return
		var workstation_id := str(fixture.get("workstation_id", ""))
		if workstation_id.is_empty():
			shared_count += 1
			if not _verify_shared_fixture_visual(visual, str(fixture.get("kind", ""))): _fail("Workshop shared fixture is still a primitive placeholder: %s" % fixture_id); return
			continue
		mapped[workstation_id] = int(fixture.get("required_level", 0))
		var role := str(fixture.get("workshop_role", ""))
		roles[workstation_id] = role
		if str(fixture.get("asset_path", "")) != "res://assets/3d/quaternius/props/workshop_workbench.glb": _fail("Engineering bench must use Quaternius workbench: %s" % fixture_id); return
		if str(visual.get_meta("asset_path", "")) != str(fixture.get("asset_path", "")) or visual.get_node_or_null("Vise") == null: _fail("Engineering bench unreadable: %s" % fixture_id); return
		if role == "bowyer" and (visual.get_node_or_null("BowStaveLeft") == null or visual.get_node_or_null("BowstringCoil") == null): _fail("Bowyer station details missing"); return
		if role == "mechanism" and (visual.get_node_or_null("PartsTray") == null or visual.get_node_or_null("MechanismGear01") == null): _fail("Mechanism station details missing"); return
		if role == "siege_assembly" and (visual.get_node_or_null("BallistaStock") == null or visual.get_node_or_null("BallistaWinch") == null): _fail("Siege assembly station details missing"); return
		var fixture_center_values := fixture.get("center", []) as Array
		var npc_stand := fixture.get("npc_stand", {}) as Dictionary
		var stand_center_values := npc_stand.get("center", []) as Array
		var fixture_center := Vector2(float(fixture_center_values[0]), float(fixture_center_values[1]))
		var stand_center := Vector2(float(stand_center_values[0]), float(stand_center_values[1]))
		var stand_to_bench_center := stand_center.distance_to(fixture_center)
		var table_half_depth := float((fixture.get("collision_size", []) as Array)[2]) * 0.5
		var visible_edge_gap := stand_to_bench_center - table_half_depth
		if absf(stand_to_bench_center - 1.1) > 0.01 or visible_edge_gap < 0.59 or visible_edge_gap > 0.61 or absf(float(npc_stand.get("target_desired_distance", 0.0)) - 0.08) > 0.001:
			_fail("Engineering stand is not at the close no-overlap table edge: %s / center=%s / edge_gap=%s" % [workstation_id, stand_to_bench_center, visible_edge_gap]); return
		var route: Dictionary = controller.get_building_spatial_route("workshop", workstation_id)
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(map, route.get("entry_outside_position", Vector3.ZERO), target, true)
		if str(route.get("target_fixture_id", "")) != fixture_id or path.size() < 3 or path[-1].distance_to(target) > 0.31: _fail("Workshop route failed: %s / %s" % [workstation_id,path]); return
		route_sizes[workstation_id] = path.size()
	controller.debug_set_preview_enabled(false)
	if mapped != {"workbench_01":1,"workbench_02":1,"workbench_03":3} or roles != {"workbench_01":"bowyer","workbench_02":"mechanism","workbench_03":"siege_assembly"} or shared_count != 4: _fail("Workshop level/shared contract drifted: %s / %s" % [mapped, roles]); return
	var building: Dictionary = building_system.get_building("workshop")
	var counts := [_count_type(building,"engineering")]
	building_system._apply_workstation_upgrade(building, building_system.get_upgrade_level_effect("workshop",2)); counts.append(_count_type(building,"engineering"))
	building_system._apply_workstation_upgrade(building, building_system.get_upgrade_level_effect("workshop",3)); counts.append(_count_type(building,"engineering"))
	if counts != [2,2,3]: _fail("Workshop authority must remain 2 -> 2 -> 3: %s" % counts); return
	print("T0129C A3b10R workshop verification passed: %s" % JSON.stringify({"fixtures":7,"roles":roles,"routes":route_sizes,"capacity":counts}))
	quit(0)

func _verify_shared_fixture_visual(visual: Node3D, kind: String) -> bool:
	match kind:
		"workshop_tool_wall": return visual.get_node_or_null("QuaterniusShelf01") != null and visual.get_node_or_null("HangingTool01") != null
		"workshop_hoist": return visual.get_node_or_null("QuaterniusRopeCoil") != null and visual.get_node_or_null("Pulley") != null
		"workshop_measurement_table": return str(visual.get_meta("asset_path", "")) == "res://assets/3d/quaternius/props/workshop_workbench.glb" and visual.get_node_or_null("DraftingBoard") != null and visual.get_node_or_null("PlanSheet") != null
		"workshop_material_rack": return visual.get_node_or_null("QuaterniusMaterialShelf01") != null and visual.get_node_or_null("MaterialCrateLeft") != null
	return false

func _count_type(building: Dictionary, type_id: String) -> int:
	var total := 0
	for raw in building.get("workstations", []):
		if str((raw as Dictionary).get("type", "")) == type_id: total += 1
	return total
func _find_by_meta(parent: Node, key: String, value: String) -> Node:
	for child in parent.get_children():
		if str(child.get_meta(key, "")) == value: return child
	return null
func _load_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)); return value if value is Dictionary else {}
func _fail(message: String) -> void: push_error(message); quit(1)
