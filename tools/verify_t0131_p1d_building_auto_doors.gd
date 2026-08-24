extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const BLACKSMITH_ART_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt"
const WORKSHOP_ART_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop/WorkshopArt"
const BLACKSMITH_ACTOR_PATH := "Main/WorldRoot/Station/NPCs/Blacksmith01"
const WORKSHOP_ACTOR_PATH := "Main/WorldRoot/Station/NPCs/Engineer01"

var _failed := false


func _init() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Failed to load Main scene")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame
	var blacksmith_art := root.get_node_or_null(BLACKSMITH_ART_PATH) as Node3D
	var workshop_art := root.get_node_or_null(WORKSHOP_ART_PATH) as Node3D
	if not _expect(blacksmith_art != null and workshop_art != null, "Formal building art views are missing"):
		return
	if not _verify_door_contract(blacksmith_art, "blacksmith"):
		return
	if not _verify_door_contract(workshop_art, "workshop"):
		return
	if not _verify_lantern_roof_clearance(blacksmith_art):
		return
	var blacksmith_actor := root.get_node_or_null(BLACKSMITH_ACTOR_PATH) as CharacterBody3D
	var workshop_actor := root.get_node_or_null(WORKSHOP_ACTOR_PATH) as CharacterBody3D
	if not _expect(blacksmith_actor != null and workshop_actor != null, "Real NPC bodies are missing"):
		return
	if not await _verify_actor_operated_door(blacksmith_art, blacksmith_actor, "blacksmith"):
		return
	if not await _verify_actor_operated_door(workshop_art, workshop_actor, "workshop"):
		return
	print("T0131-P1D building auto-door verification passed")
	main.queue_free()
	await process_frame
	quit(0)


func _verify_door_contract(art_view: Node3D, building_label: String) -> bool:
	var exterior := art_view.get_node_or_null("Exterior") as Node3D
	var door := art_view.get_node_or_null("Exterior/AutoDoor")
	if not _expect(exterior != null and door != null and door.has_method("debug_get_snapshot"), "%s auto door is missing" % building_label):
		return false
	var snapshot: Dictionary = door.call("debug_get_snapshot")
	if not _expect(float(snapshot.get("clear_width", 0.0)) >= 1.8, "%s doorway is narrower than the navigation contract" % building_label):
		return false
	if not _expect(float(snapshot.get("clear_height", 0.0)) >= 2.2, "%s doorway is lower than the navigation contract" % building_label):
		return false
	if not _expect(bool(snapshot.get("centerline_clear", false)), "%s doorway does not declare a clear centerline" % building_label):
		return false
	if not _expect(not bool(snapshot.get("blocking_collision", true)), "%s visual door duplicated collision authority" % building_label):
		return false
	if not _expect(int(snapshot.get("actor_collision_mask", 0)) == 2, "%s door does not detect physical actor bodies" % building_label):
		return false
	var jamb_x_positions: Array[float] = []
	for child in exterior.get_children():
		if child is Node3D and str(child.name).begins_with("FrontPost"):
			if absf((child as Node3D).position.x) < 1.05:
				return _expect(false, "%s still has a front post blocking the doorway" % building_label)
	for jamb_name in ["DoorJambLeft", "DoorJambRight"]:
		var jamb := exterior.get_node_or_null(jamb_name) as Node3D
		if jamb != null:
			jamb_x_positions.append(jamb.position.x)
	jamb_x_positions.sort()
	if not _expect(jamb_x_positions.size() == 2, "%s doorway does not have two side jambs" % building_label):
		return false
	var visual_clear_width := jamb_x_positions[1] - jamb_x_positions[0] - 0.22
	return _expect(visual_clear_width >= 1.8, "%s visible jambs reduce the clear opening below 1.8 m" % building_label)


func _verify_lantern_roof_clearance(blacksmith_art: Node3D) -> bool:
	var lantern := blacksmith_art.get_node_or_null("Interior/Level1CommonProps/Support_RearForgeLantern/RearForgeLantern") as Node3D
	var roof := blacksmith_art.get_node_or_null("Roof") as Node3D
	if not _expect(lantern != null and roof != null, "Smithy lantern or roof is missing"):
		return false
	var lantern_bounds := _subtree_bounds_in_space(lantern, blacksmith_art)
	var roof_bounds := _subtree_bounds_in_space(roof, blacksmith_art)
	return _expect(
		lantern_bounds.has_volume()
		and roof_bounds.has_volume()
		and lantern_bounds.end.y <= roof_bounds.position.y - 0.1,
		"Smithy lantern intersects the roof: lantern=%s roof=%s" % [lantern_bounds, roof_bounds]
	)


func _verify_actor_operated_door(art_view: Node3D, actor: CharacterBody3D, building_label: String) -> bool:
	var door := art_view.get_node("Exterior/AutoDoor") as Node3D
	if not _expect((actor.collision_layer & 2) != 0, "%s test NPC is not a physical layer-2 actor" % building_label):
		return false
	actor.set_physics_process(false)
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 1.5))
	for frame_index in range(32):
		await physics_frame
	var open_snapshot: Dictionary = door.call("debug_get_snapshot")
	if not _expect(int(open_snapshot.get("overlapping_actor_count", 0)) >= 1, "%s door sensor did not detect the nearby NPC" % building_label):
		return false
	if not _expect(bool(open_snapshot.get("open_requested", false)) and float(open_snapshot.get("open_fraction", 0.0)) >= 0.95, "%s door did not open for the nearby NPC" % building_label):
		return false
	var left_bounds := _subtree_bounds_in_space(door.get_node("LeftHinge/LeftLeaf"), door)
	var right_bounds := _subtree_bounds_in_space(door.get_node("RightHinge/RightLeaf"), door)
	if not _expect(left_bounds.end.x <= -0.75 and right_bounds.position.x >= 0.75, "%s open leaves intrude into the center passage" % building_label):
		return false
	actor.global_position = door.to_global(Vector3(0.0, 0.0, 8.0))
	for frame_index in range(78):
		await physics_frame
	var closed_snapshot: Dictionary = door.call("debug_get_snapshot")
	return _expect(
		int(closed_snapshot.get("overlapping_actor_count", -1)) == 0
		and not bool(closed_snapshot.get("open_requested", true))
		and float(closed_snapshot.get("open_fraction", 1.0)) <= 0.05,
		"%s door did not close after the NPC left" % building_label
	)


func _subtree_bounds_in_space(root_node: Node, space: Node3D) -> AABB:
	if root_node == null:
		return AABB()
	var points: Array[Vector3] = []
	var nodes: Array[Node] = [root_node]
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		for child: Node in current.get_children():
			nodes.append(child)
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var mesh_node: MeshInstance3D = current as MeshInstance3D
			var mesh_bounds: AABB = mesh_node.mesh.get_aabb()
			for x_index in range(2):
				for y_index in range(2):
					for z_index in range(2):
						var local_corner: Vector3 = mesh_bounds.position + Vector3(
							mesh_bounds.size.x * float(x_index),
							mesh_bounds.size.y * float(y_index),
							mesh_bounds.size.z * float(z_index)
						)
						points.append(space.to_local(mesh_node.to_global(local_corner)))
	if points.is_empty():
		return AABB()
	var min_point: Vector3 = points[0]
	var max_point: Vector3 = points[0]
	for point: Vector3 in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return AABB(min_point, max_point - min_point)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
