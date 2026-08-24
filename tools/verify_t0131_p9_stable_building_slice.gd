extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const STABLE_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Stable"
const EXPECTED_FIXTURE_VISUAL_COUNTS := [7, 8, 9]
const EXPECTED_FIXTURE_COLLISION_COUNTS := [23, 24, 27]
const EXPECTED_CARE_CAPACITY := [2, 2, 3]
const EXPECTED_HORSE_ANCHOR_CAPACITY := [7, 7, 8]

var _failed := false


func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _step in 4:
		await process_frame
		await physics_frame

	var stable := root.get_node_or_null(STABLE_PATH) as Node3D
	var art := stable.get_node_or_null("StableArt") if stable != null else null
	var envelope := stable.get_node_or_null("Envelope") as MeshInstance3D if stable != null else null
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if stable == null or art == null or envelope == null or building_system == null or horse_system == null or controller == null:
		_fail("T0131-P9 stable runtime hierarchy is incomplete")
		return
	if envelope.visible:
		_fail("Legacy stable Envelope must remain hidden behind StableArt")
		return
	if not bool(art.get_meta("open_air_site", false)) or not bool(art.call("is_interior_revealed_for_selection")):
		_fail("Stable must remain an open-air NPC-selection-priority site")
		return

	var level_snapshots: Array[Dictionary] = []
	for level_index in range(3):
		var level := level_index + 1
		var snapshot: Dictionary = art.call("debug_force_visual_level", level)
		await process_frame
		await physics_frame
		snapshot = art.call("get_art_slice_snapshot")
		level_snapshots.append(snapshot)
		if int(snapshot.get("active_fixture_visual_count", -1)) != EXPECTED_FIXTURE_VISUAL_COUNTS[level_index]:
			_fail("Stable fixture visual progression drifted at level %d: %s" % [level, JSON.stringify(snapshot)])
			return
		if int(snapshot.get("active_fixture_collision_count", -1)) != EXPECTED_FIXTURE_COLLISION_COUNTS[level_index]:
			_fail("Stable collision progression drifted at level %d: %s" % [level, JSON.stringify(snapshot)])
			return
		if int(snapshot.get("active_fixture_collision_part_count", -1)) != EXPECTED_FIXTURE_COLLISION_COUNTS[level_index]:
			_fail("Stable collision-part progression drifted at level %d: %s" % [level, JSON.stringify(snapshot)])
			return
		if int(snapshot.get("available_care_station_count", -1)) != EXPECTED_CARE_CAPACITY[level_index]:
			_fail("Stable authoritative care capacity drifted at level %d: %s" % [level, JSON.stringify(snapshot)])
			return
		if int(snapshot.get("available_horse_anchor_count", -1)) != EXPECTED_HORSE_ANCHOR_CAPACITY[level_index]:
			_fail("Stable horse-anchor availability drifted at level %d: %s" % [level, JSON.stringify(snapshot)])
			return
		if int(snapshot.get("horse_anchor_count", -1)) != 8:
			_fail("Stable must keep eight maximum horse anchors")
			return
		if not bool(snapshot.get("open_air_selection_priority", false)):
			_fail("Stable open-air selection priority must not depend on camera distance")
			return

	var level_one := level_snapshots[0]
	var level_two := level_snapshots[1]
	var level_three := level_snapshots[2]
	if bool(level_one.get("level_2_visible", true)) or bool(level_one.get("level_3_visible", true)):
		_fail("Level-one stable leaked upgrade dressing")
		return
	if not bool(level_two.get("level_2_visible", false)) or bool(level_two.get("level_3_visible", true)):
		_fail("Level-two stable visibility contract drifted")
		return
	if not bool(level_three.get("level_2_visible", false)) or not bool(level_three.get("level_3_visible", false)):
		_fail("Level-three stable must expose both cumulative upgrade layers")
		return
	if not _verify_workstation_level_contract(level_three.get("workstations", {}) as Dictionary):
		return
	if not _verify_live_horse_projection(horse_system, level_three):
		return
	if not _verify_gate_and_roof_contract(art, level_three):
		return
	if not _verify_stall_weather_cover(art):
		return
	if not _verify_building_authority_unchanged(building_system):
		return

	var bounds := _combined_mesh_bounds(art)
	if bounds.size == Vector3.ZERO or bounds.position.x < -7.05 or bounds.end.x > 7.05 or bounds.position.z < -7.05 or bounds.end.z > 7.05:
		_fail("Stable visible art escaped its 14x14 envelope: %s" % bounds)
		return
	var aisle_bounds := AABB(Vector3(-1.2, 0.0, -6.4), Vector3(2.4, 2.2, 12.8))
	for node_path in [
		"Interior/Level1Details/FrontWashAndGroomingCorner",
		"Interior/Level1Details/StableCleaningToolWall",
		"Interior/Level1Details/StarterTackRail",
		"UpgradeVisuals/Level2/InteriorAdditions/LevelTwoExpandedTackStorage",
		"UpgradeVisuals/Level2/InteriorAdditions/LevelTwoDryHayReserve",
		"UpgradeVisuals/Level2/InteriorAdditions/LevelTwoFarrierMaintenance",
		"UpgradeVisuals/Level2/InteriorAdditions/LevelTwoWaterAndFeedExtension",
		"UpgradeVisuals/Level3/InteriorAdditions/LevelThreeThirdCareBaySupport",
		"UpgradeVisuals/Level3/InteriorAdditions/LevelThreeFoalRecoverySupplies",
		"UpgradeVisuals/Level3/InteriorAdditions/LevelThreeStableLogistics"
	]:
		var node := art.get_node_or_null(node_path) as Node3D
		if node != null and _node_meshes_intersect_aabb(node, art, aisle_bounds):
			_fail("Stable decoration blocks the 2.4m central leading aisle: %s" % node_path)
			return

	print("T0131-P9 stable building slice verification passed: %s" % JSON.stringify({
		"fixture_visuals": EXPECTED_FIXTURE_VISUAL_COUNTS,
		"fixture_collisions": EXPECTED_FIXTURE_COLLISION_COUNTS,
		"care_capacity": EXPECTED_CARE_CAPACITY,
		"horse_anchor_capacity": EXPECTED_HORSE_ANCHOR_CAPACITY,
		"real_horses": int(level_three.get("visible_real_horse_count", 0)),
		"bounds": str(bounds)
	}))
	quit(0)


func _verify_workstation_level_contract(states: Dictionary) -> bool:
	if states.size() != 3:
		_fail("Stable must expose exactly three configured care markers")
		return false
	for workstation_id in ["stall_01", "stall_02", "stall_03"]:
		if not states.has(workstation_id):
			_fail("Stable care marker missing: %s" % workstation_id)
			return false
	var level_three_required := int((states["stall_03"] as Dictionary).get("required_level", 0))
	if level_three_required != 3:
		_fail("Third stable care bay must remain a level-three authority position")
		return false
	return true


func _verify_live_horse_projection(horse_system: Node, snapshot: Dictionary) -> bool:
	var stable_horse_ids: Dictionary = {}
	for raw_horse in horse_system.get_horses_snapshot():
		var horse: Dictionary = raw_horse
		if str(horse.get("location", "")) == "stable":
			stable_horse_ids[str(horse.get("horse_id", ""))] = true
	var visual_states := snapshot.get("horse_visuals", {}) as Dictionary
	if int(snapshot.get("visible_real_horse_count", -1)) != stable_horse_ids.size():
		_fail("Stable horse visuals must mirror the real in-stable HorseSystem count: %s" % JSON.stringify(snapshot))
		return false
	var used_anchors: Dictionary = {}
	for horse_id in stable_horse_ids.keys():
		var visual := visual_states.get(horse_id, {}) as Dictionary
		var anchor_id := str(visual.get("anchor_id", ""))
		if not bool(visual.get("visible", false)) or str(visual.get("source_location", "")) != "stable" or anchor_id.is_empty() or used_anchors.has(anchor_id):
			_fail("Real stable horse lacks one unique visible anchor: %s / %s" % [horse_id, JSON.stringify(visual)])
			return false
		used_anchors[anchor_id] = horse_id
	return true


func _verify_gate_and_roof_contract(art: Node, snapshot: Dictionary) -> bool:
	var gate := snapshot.get("auto_gate", {}) as Dictionary
	if float(gate.get("clear_width", 0.0)) < 2.4 or float(gate.get("clear_height", 0.0)) < 2.2 or bool(gate.get("blocking_collision", true)):
		_fail("Stable auto gate is not wide, tall and non-blocking enough for leading horses: %s" % JSON.stringify(gate))
		return false
	art.call("apply_roof_camera_distance", 72.0, 0.0)
	var far := art.call("get_roof_visibility_snapshot") as Dictionary
	art.call("apply_roof_camera_distance", 56.0, 1.0)
	var near := art.call("get_roof_visibility_snapshot") as Dictionary
	if float(far.get("roof_opacity", 0.0)) < 0.99 or float(near.get("roof_opacity", 1.0)) > 0.08:
		_fail("Stable awnings do not follow the 70->58m fade contract: %s / %s" % [JSON.stringify(far), JSON.stringify(near)])
		return false
	if int(snapshot.get("roof_mesh_count", 0)) <= 0 or not bool(snapshot.get("roof_structure_additions_fade_with_roof", false)):
		_fail("Stable roof additions are not registered in the fade chain")
		return false
	return true


func _verify_stall_weather_cover(art: Node3D) -> bool:
	var roof := art.get_node_or_null("Roof") as Node3D
	var anchors := art.get_node_or_null("../FixtureLayout/HorseAnchors") as Node3D
	if roof == null or anchors == null:
		_fail("Stable weather-cover hierarchy is incomplete")
		return false
	var awning_bounds: Array[AABB] = []
	for raw_child in roof.get_children():
		var mesh := raw_child as MeshInstance3D
		if mesh == null or not mesh.mesh is BoxMesh or (mesh.mesh as BoxMesh).size.z < 12.0:
			continue
		awning_bounds.append((art.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb())
	if awning_bounds.size() != 2:
		_fail("Stable must keep two continuous side weather awnings")
		return false
	for raw_anchor in anchors.get_children():
		var anchor := raw_anchor as Marker3D
		if anchor == null:
			continue
		var center := (art.global_transform.affine_inverse() * anchor.global_transform).origin
		var footprint := AABB(Vector3(center.x - 0.7, 0.0, center.z - 1.1), Vector3(1.4, 0.1, 2.2))
		var covered := false
		for bounds in awning_bounds:
			if bounds.position.x <= footprint.position.x and bounds.end.x >= footprint.end.x and bounds.position.z <= footprint.position.z and bounds.end.z >= footprint.end.z:
				covered = true
				break
		if not covered:
			_fail("Stable awnings do not cover the full horse footprint at %s: %s" % [anchor.name, footprint])
			return false
	return true


func _verify_building_authority_unchanged(building_system: Node) -> bool:
	var building: Dictionary = building_system.get_building("stable")
	if int(building.get("level", -1)) != 1:
		_fail("Stable art preview mutated BuildingSystem authority level")
		return false
	var counts: Array[int] = []
	counts.append(_count_care_positions(building))
	building_system._apply_workstation_upgrade(building, building_system.get_upgrade_level_effect("stable", 2))
	counts.append(_count_care_positions(building))
	building_system._apply_workstation_upgrade(building, building_system.get_upgrade_level_effect("stable", 3))
	counts.append(_count_care_positions(building))
	if counts != [2, 2, 3]:
		_fail("BuildingSystem stable capacity drifted: %s" % counts)
		return false
	return true


func _count_care_positions(building: Dictionary) -> int:
	var count := 0
	for raw_station in building.get("workstations", []):
		if raw_station is Dictionary and str((raw_station as Dictionary).get("type", "")) == "horse_care":
			count += 1
	return count


func _combined_mesh_bounds(node: Node3D) -> AABB:
	var has_bounds := false
	var result := AABB()
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for raw_mesh in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(raw_mesh as MeshInstance3D)
	for mesh_instance in meshes:
		if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		var transformed := (node.global_transform.affine_inverse() * mesh_instance.global_transform) * mesh_instance.get_aabb()
		result = transformed if not has_bounds else result.merge(transformed)
		has_bounds = true
	if not has_bounds:
		return AABB()
	return result


func _node_meshes_intersect_aabb(node: Node3D, ancestor: Node3D, target: AABB) -> bool:
	for raw_mesh in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		var in_ancestor := (ancestor.global_transform.affine_inverse() * mesh_instance.global_transform) * mesh_instance.get_aabb()
		if in_ancestor.intersects(target):
			return true
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
