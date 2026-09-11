extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const DORMITORY_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Dormitory"


func _init() -> void:
	var main := MAIN_SCENE.instantiate()
	var daily_plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if daily_plan_system != null and daily_plan_system.has_method("set_auto_execution_enabled"):
		daily_plan_system.call("set_auto_execution_enabled", false)
	root.add_child(main)
	for _frame in range(6):
		await process_frame
		await physics_frame

	var dormitory := root.get_node_or_null(DORMITORY_PATH) as Node3D
	var art := dormitory.get_node_or_null("DormitoryArt") as Node3D if dormitory != null else null
	var storage := art.get_node_or_null("Interior/Level1Details/OuterWallPersonalStorage") as Node3D if art != null else null
	if dormitory == null or art == null or storage == null:
		_fail("T0239 dormitory personal-storage hierarchy is incomplete")
		return

	var wardrobes: Array[Node3D] = []
	var assigned_npc_ids: Dictionary = {}
	var workstation_ids: Dictionary = {}
	for raw_child in storage.get_children():
		if not raw_child is Node3D:
			continue
		var child := raw_child as Node3D
		if str(child.get_meta("prop_type", "")) == "assigned_personal_wardrobe":
			wardrobes.append(child)
			assigned_npc_ids[str(child.get_meta("assigned_npc_id", ""))] = true
			workstation_ids[str(child.get_meta("workstation_id", ""))] = true
	if wardrobes.size() != 8 or assigned_npc_ids.size() != 8 or workstation_ids.size() != 8:
		_fail("T0239 expected eight uniquely assigned personal wardrobes, got %d / %d / %d" % [wardrobes.size(), assigned_npc_ids.size(), workstation_ids.size()])
		return
	for index in range(8):
		var wardrobe := wardrobes[index]
		if not _verify_wardrobe(wardrobe, index + 1):
			return
	if not storage.find_children("*Chest*", "", true, false).is_empty():
		_fail("T0239 legacy low personal chests remain under OuterWallPersonalStorage")
		return
	if not storage.find_children("*FoldedBlanket*", "", true, false).is_empty():
		_fail("T0239 legacy chest-top blankets remain under OuterWallPersonalStorage")
		return
	if not storage.find_children("*PegRack*", "", true, false).is_empty():
		_fail("T0239 legacy peg racks overlap the new wardrobe row")
		return
	var snapshot: Dictionary = art.call("get_art_slice_snapshot")
	var wardrobe_snapshot := snapshot.get("personal_wardrobes", {}) as Dictionary
	if (
		int(wardrobe_snapshot.get("count", 0)) != 8
		or int(snapshot.get("bed_count", 0)) != 10
		or int(snapshot.get("assigned_bed_count", 0)) != 8
		or int(snapshot.get("active_fixture_visual_count", 0)) != 10
		or int(snapshot.get("active_fixture_collision_count", 0)) != 10
	):
		_fail("T0239 wardrobe replacement changed the fixed-bed or fixture authority contract: %s" % JSON.stringify(snapshot))
		return

	print("T0239 dormitory personal wardrobe verification passed: %s" % JSON.stringify({
		"wardrobes": wardrobes.size(),
		"unique_residents": assigned_npc_ids.size(),
		"fixed_beds": snapshot.get("bed_count", 0),
		"fixture_collisions": snapshot.get("active_fixture_collision_count", 0)
	}))
	main.queue_free()
	await process_frame
	quit(0)


func _verify_wardrobe(wardrobe: Node3D, ordinal: int) -> bool:
	if wardrobe.name != "PersonalWardrobe%02d" % ordinal:
		return _expect(false, "T0239 wardrobe ordering or identity drifted at %d" % ordinal)
	if str(wardrobe.get_meta("authority_role", "")) != "non_workstation_non_inventory_decoration":
		return _expect(false, "T0239 wardrobe %d acquired gameplay authority" % ordinal)
	if str(wardrobe.get_meta("assigned_npc_id", "")).is_empty() or str(wardrobe.get_meta("workstation_id", "")).is_empty():
		return _expect(false, "T0239 wardrobe %d lost its resident/bed mirror metadata" % ordinal)
	for part_name in ["OakCarcass", "RaisedTopCornice", "BroadPlinth", "FrontFrameStile", "FrontFrameRail", "WardrobeDoor", "RecessedDoorPanel", "IronHinge", "IronHandle", "PersonalClothMark"]:
		if wardrobe.find_child(part_name, true, false) == null:
			return _expect(false, "T0239 wardrobe %d lacks %s" % [ordinal, part_name])
	if not wardrobe.find_children("*", "CollisionObject3D", true, false).is_empty():
		return _expect(false, "T0239 wardrobe %d unexpectedly owns collision" % ordinal)
	var bounds := _subtree_bounds(wardrobe)
	return _expect(bounds.size.y >= 2.4 and bounds.size.z >= 1.6 and bounds.size.x >= 0.8, "T0239 wardrobe %d is not visibly larger than the old low chest: %s" % [ordinal, bounds])


func _subtree_bounds(root_node: Node3D) -> AABB:
	var points: Array[Vector3] = []
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local_bounds := mesh.mesh.get_aabb()
		var transform := root_node.global_transform.affine_inverse() * mesh.global_transform
		for x in [local_bounds.position.x, local_bounds.end.x]:
			for y in [local_bounds.position.y, local_bounds.end.y]:
				for z in [local_bounds.position.z, local_bounds.end.z]:
					points.append(transform * Vector3(x, y, z))
	if points.is_empty():
		return AABB()
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
	return condition


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
