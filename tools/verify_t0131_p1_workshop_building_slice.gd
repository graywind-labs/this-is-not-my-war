extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const WORKSHOP_VIEW_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop/WorkshopArt"
const OWEN_ID := "engineer_01"

var _failed := false


func _init() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Main scene is unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _index in range(4):
		await process_frame
		await physics_frame
	var art_view := root.get_node_or_null(WORKSHOP_VIEW_PATH)
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if not _expect(art_view != null and building_system != null and controller != null, "Workshop slice hierarchy is incomplete"):
		return
	var layout_snapshot: Dictionary = controller.call("get_validation_snapshot")
	if not _expect(int(layout_snapshot.get("configuration_error_count", -1)) == 0, "Formal layout has configuration errors"):
		return
	var level_1: Dictionary = art_view.call("debug_force_visual_level", 1)
	if not _verify_level(art_view, level_1, 1, 3, 3):
		return
	for path in [
		"Exterior/FrontDoor",
		"Roof/RoundTileRoof",
		"Roof/MonitorBase",
		"Interior/Floor",
		"Interior/Level1Details/OrderBoard",
		"Interior/Level1Details/SharedStockDetails",
		"Interior/Level1Details/SparePartsShelf",
		"Interior/Level1Details/FastenerShelf",
		"Interior/Level1Details/BenchRopeCoilLeft",
		"Interior/Level1Details/ComponentBins"
	]:
		if not _expect(art_view.get_node_or_null(path) != null, "Workshop level-one structure is missing: %s" % path):
			return
	art_view.call("apply_roof_camera_distance", 70.0, 1.0)
	var far_roof: Dictionary = art_view.call("get_roof_visibility_snapshot")
	if not _expect(float(far_roof.get("roof_opacity", 0.0)) >= 0.98 and float(far_roof.get("exterior_opacity", 0.0)) >= 0.98, "Far camera does not restore workshop roof and walls"):
		return
	art_view.call("apply_roof_camera_distance", 58.0, 0.0)
	var near_roof: Dictionary = art_view.call("get_roof_visibility_snapshot")
	if not _expect(float(near_roof.get("roof_opacity", 1.0)) <= 0.1 and float(near_roof.get("exterior_opacity", 1.0)) <= 0.1 and bool(near_roof.get("interior_revealed_for_selection", false)), "Near camera does not reveal workshop interior"):
		return
	if not await _verify_transparent_click_contract(art_view):
		return
	if not await _set_authoritative_level(building_system, 2):
		return
	var level_2: Dictionary = art_view.call("get_art_slice_snapshot")
	if not _verify_level(art_view, level_2, 2, 6, 6):
		return
	for path in [
		"UpgradeVisuals/Level2/ExteriorAdditions/ReceivingShelf",
		"UpgradeVisuals/Level2/ExteriorAdditions/ReceivingHoistArm",
		"UpgradeVisuals/Level2/ExteriorAdditions/ReceivingPulley",
		"UpgradeVisuals/Level2/RoofStructureAdditions/OverheadTransmissionBeam",
		"../FixtureLayout/Visuals/WorkshopLevelTwoToolWall",
		"../FixtureLayout/Visuals/WorkshopLevelTwoHoist",
		"../FixtureLayout/Visuals/WorkshopLevelTwoMeasurementTable"
	]:
		if not _expect(art_view.get_node_or_null(path) != null, "Workshop level-two addition is missing: %s" % path):
			return
	if not _expect(art_view.get_node_or_null("UpgradeVisuals/Level2/ExteriorAdditions/DoorGantryBeam") == null, "Obsolete ceremonial level-two doorway frame still exists"):
		return
	if not _expect(_mesh_opacity(art_view, "UpgradeVisuals/Level2/RoofStructureAdditions/OverheadTransmissionBeam") <= 0.1, "Level-two transmission beam did not fade with the roof"):
		return
	if not _expect(not bool(((level_2.get("workstations", {}) as Dictionary).get("workbench_03", {}) as Dictionary).get("available", true)), "Level 2 exposes the third engineering workstation early"):
		return
	if not await _set_authoritative_level(building_system, 3):
		return
	var level_3: Dictionary = art_view.call("get_art_slice_snapshot")
	if not _verify_level(art_view, level_3, 3, 7, 7):
		return
	if not _expect(bool(((level_3.get("workstations", {}) as Dictionary).get("workbench_03", {}) as Dictionary).get("available", false)), "Level 3 did not expose workbench_03"):
		return
	for path in [
		"UpgradeVisuals/Level3/RoofStructureAdditions/MasterAssemblyTruss",
		"UpgradeVisuals/Level3/ExteriorAdditions/AssemblyBayRoof",
		"UpgradeVisuals/Level3/ExteriorAdditions/AssemblyBayWinch",
		"UpgradeVisuals/Level3/ExteriorAdditions/AssemblyBayPartsRack",
		"../FixtureLayout/Visuals/Workbench03EngineeringTable"
	]:
		if not _expect(art_view.get_node_or_null(path) != null, "Workshop level-three addition is missing: %s" % path):
			return
	if not _expect(art_view.get_node_or_null("UpgradeVisuals/Level3/ExteriorAdditions/SideAssemblyAwning") == null, "Obsolete clipping level-three side awning still exists"):
		return
	var main_roof_bounds := _subtree_bounds(art_view.get_node_or_null("Roof/RoundTileRoof"))
	var assembly_bay_roof_bounds := _subtree_bounds(art_view.get_node_or_null("UpgradeVisuals/Level3/ExteriorAdditions/AssemblyBayRoof"))
	if not _expect(
		main_roof_bounds.has_volume()
		and assembly_bay_roof_bounds.has_volume()
		and assembly_bay_roof_bounds.end.y <= main_roof_bounds.position.y - 0.05,
		"Level-three assembly bay roof intersects the main workshop roof: main=%s bay=%s" % [main_roof_bounds, assembly_bay_roof_bounds]
	):
		return
	var level_3_exterior_bounds := _subtree_bounds_in_space(
		art_view.get_node_or_null("UpgradeVisuals/Level3/ExteriorAdditions"),
		art_view
	)
	if not _expect(
		level_3_exterior_bounds.has_volume()
		and level_3_exterior_bounds.position.x >= -7.05
		and level_3_exterior_bounds.position.z >= -7.05
		and level_3_exterior_bounds.end.x <= 7.05
		and level_3_exterior_bounds.end.z <= 7.05,
		"Level-three exterior additions escaped the approved 14 x 14 m workshop lot: %s" % level_3_exterior_bounds
	):
		return
	if not _expect(_mesh_opacity(art_view, "UpgradeVisuals/Level3/RoofStructureAdditions/MasterAssemblyTruss") <= 0.1, "Level-three assembly truss did not fade with the roof"):
		return
	art_view.call("apply_roof_camera_distance", 70.0, 1.0)
	if not _expect(
		_mesh_opacity(art_view, "UpgradeVisuals/Level2/RoofStructureAdditions/OverheadTransmissionBeam") >= 0.98
		and _mesh_opacity(art_view, "UpgradeVisuals/Level3/RoofStructureAdditions/MasterAssemblyTruss") >= 0.98,
		"Upgrade roof structures did not return with the distant roof"
	):
		return
	var building: Dictionary = building_system.call("get_building", "workshop")
	if not _expect(_count_workstations(building, "engineering") == 3, "BuildingSystem authority is not 2 -> 2 -> 3 at level 3"):
		return
	for workstation_id in ["workbench_01", "workbench_02", "workbench_03"]:
		var route: Dictionary = controller.call("get_building_spatial_route", "workshop", workstation_id)
		if not _expect(not route.is_empty() and str(route.get("position_id", "")) == workstation_id and not str(route.get("target_fixture_id", "")).is_empty() and float(route.get("target_desired_distance", -1.0)) <= 0.081, "Workshop route is invalid: %s" % workstation_id):
			return
	print("T0131-P1 workshop building slice verification passed: %s" % JSON.stringify({
		"level_1_fixtures": 3,
		"level_2_fixtures": 6,
		"level_3_fixtures": 7,
		"roof_fades_with_walls": true,
		"transparent_npc_click": true,
		"capacity": [2, 2, 3]
	}))
	main.queue_free()
	await process_frame
	quit(0)


func _verify_level(art_view: Node, snapshot: Dictionary, level: int, expected_visuals: int, expected_collisions: int) -> bool:
	if not _expect(int(snapshot.get("building_level", 0)) == level, "Workshop visual level mismatch: %s" % snapshot):
		return false
	if not _expect(bool(snapshot.get("level_2_visible", false)) == (level >= 2) and bool(snapshot.get("level_3_visible", false)) == (level >= 3), "Workshop cumulative upgrade visibility is wrong at level %d" % level):
		return false
	if not _expect(int(snapshot.get("active_fixture_visual_count", -1)) == expected_visuals and int(snapshot.get("active_fixture_collision_count", -1)) == expected_collisions, "Workshop fixture visual/collision count is wrong at level %d: %s" % [level, snapshot]):
		return false
	if not _expect(bool(snapshot.get("navigation_ready", false)) and str(snapshot.get("navigation_authority", "")) == "formal_station_navigation_mesh", "Workshop escaped formal navigation authority"):
		return false
	if not _expect(str(snapshot.get("authority_role", "")) == "presentation_only", "Workshop art escaped presentation-only authority"):
		return false
	var footprint: Vector2 = snapshot.get("building_footprint", Vector2.ZERO)
	var clear_size: Vector2 = snapshot.get("interior_clear_size", Vector2.ZERO)
	if not _expect(footprint == Vector2(12.0, 12.0) and clear_size.x >= 11.0 and clear_size.y >= 11.0 and bool(snapshot.get("future_capacity_reserved", false)), "Workshop does not preserve the approved upgrade envelope"):
		return false
	var roof_color: Color = snapshot.get("roof_albedo_override", Color.WHITE)
	if not _expect(roof_color.b > roof_color.r and int(snapshot.get("roof_mesh_count", 0)) >= 10, "Workshop roof is not the cool low-profile engineering silhouette"):
		return false
	if not _expect(int(snapshot.get("roof_structure_addition_count", 0)) == 3 and bool(snapshot.get("roof_structure_additions_fade_with_roof", false)), "Workshop upgrade roof structures are not registered with the roof fade contract"):
		return false
	var roof_snapshot: Dictionary = art_view.call("get_roof_visibility_snapshot")
	return _expect(bool(roof_snapshot.get("static_collision_enabled", false)), "Workshop walls have no physical collision")


func _verify_transparent_click_contract(art_view: Node3D) -> bool:
	var hit: Dictionary = art_view.call(
		"get_building_interaction_ray_hit",
		art_view.global_position + Vector3(0.0, 20.0, 0.0),
		art_view.global_position + Vector3(0.0, -5.0, 0.0)
	)
	if not _expect(str(hit.get("building_id", "")) == "workshop" and bool(hit.get("interior_revealed", false)), "Transparent workshop cannot be ray selected"):
		return false
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if not _expect(npc_system != null and building_system != null and camera != null, "Workshop click dependencies are missing"):
		return false
	if not _expect(bool(npc_system.call("debug_enter_location_immediately", OWEN_ID, "workshop", false)), "Could not place Owen in workshop"):
		return false
	var npc_paths: Dictionary = npc_system.get("_npc_nodes")
	var owen := npc_system.get_node_or_null(npc_paths.get(OWEN_ID, NodePath(""))) as Node3D
	if not _expect(owen != null, "Owen world node is missing"):
		return false
	owen.global_position = art_view.to_global(Vector3(0.0, 0.0, 0.0))
	await physics_frame
	var screen_position := camera.unproject_position(owen.global_position + Vector3(0.0, 1.0, 0.0))
	if not _expect(bool(building_system.call("_try_select_interior_npc", screen_position, "workshop")), "Transparent workshop did not route click priority to Owen"):
		return false
	art_view.call("apply_roof_camera_distance", 70.0, 1.0)
	if not _expect(bool(npc_system.call("_is_npc_hidden_by_opaque_building", OWEN_ID)), "Opaque workshop did not restore building-first click priority"):
		return false
	art_view.call("apply_roof_camera_distance", 58.0, 0.0)
	return _expect(not bool(npc_system.call("_is_npc_hidden_by_opaque_building", OWEN_ID)), "Transparent workshop still hides Owen")


func _set_authoritative_level(building_system: Node, level: int) -> bool:
	var buildings: Dictionary = building_system.get("_buildings")
	var workshop: Dictionary = buildings.get("workshop", {})
	workshop["level"] = level
	if level >= 3 and _count_workstations(workshop, "engineering") < 3:
		building_system.call("_apply_workstation_upgrade", workshop, building_system.call("get_upgrade_level_effect", "workshop", 3))
	buildings["workshop"] = workshop
	building_system.set("_buildings", buildings)
	var event_bus := root.get_node_or_null("EventBus")
	if event_bus == null:
		_fail("EventBus is missing")
		return false
	event_bus.emit_signal("building_state_changed", "workshop")
	await process_frame
	return _expect(int(art_view_level()) == level, "BuildingSystem level change did not reach WorkshopArt")


func art_view_level() -> int:
	var art_view := root.get_node_or_null(WORKSHOP_VIEW_PATH)
	if art_view == null:
		return 0
	return int((art_view.call("get_art_slice_snapshot") as Dictionary).get("building_level", 0))


func _count_workstations(building: Dictionary, type_id: String) -> int:
	var count := 0
	for raw_station in building.get("workstations", []):
		if str((raw_station as Dictionary).get("type", "")) == type_id:
			count += 1
	return count


func _mesh_opacity(art_view: Node, path: String) -> float:
	var mesh_instance := art_view.get_node_or_null(path) as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return -1.0
	var material := mesh_instance.get_active_material(0) as BaseMaterial3D
	return material.albedo_color.a if material != null else -1.0


func _subtree_bounds(root_node: Node) -> AABB:
	if root_node == null:
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node as MeshInstance3D)
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(raw_mesh as MeshInstance3D)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var world_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		bounds = bounds.merge(world_bounds) if has_bounds else world_bounds
		has_bounds = true
	return bounds


func _subtree_bounds_in_space(root_node: Node, space: Node3D) -> AABB:
	if root_node == null or space == null:
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node as MeshInstance3D)
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(raw_mesh as MeshInstance3D)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform := space.global_transform.affine_inverse() * mesh_instance.global_transform
		var local_bounds := relative_transform * mesh_instance.get_aabb()
		bounds = bounds.merge(local_bounds) if has_bounds else local_bounds
		has_bounds = true
	return bounds


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
