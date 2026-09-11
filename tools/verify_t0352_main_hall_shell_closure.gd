extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const HALL_ART_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall/MainHallArt"
const TOLERANCE := 0.002


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

	var art := root.get_node_or_null(HALL_ART_PATH) as Node3D
	if art == null:
		_fail("Formal main hall unavailable")
		return
	var outer_shell := art.get_node_or_null("BaseVisuals/Exterior/TexturedFacadeModules") as Node3D
	var keep := art.get_node_or_null("BaseVisuals/Exterior/SolidMainHallMass/CentralCommandKeep") as Node3D
	var keep_roof := art.get_node_or_null("Roof/CentralKeepRoof") as Node3D
	if outer_shell == null or keep == null or keep_roof == null:
		_fail("Main hall shell hierarchy is incomplete")
		return

	var outer_front := _named_visual_bounds(outer_shell, art, ["OuterFrontWall_", "FrontDoor"])
	var outer_rear := _named_visual_bounds(outer_shell, art, ["OuterRearWall_"])
	var outer_west := _named_visual_bounds(outer_shell, art, ["OuterWestWall_"])
	var outer_east := _named_visual_bounds(outer_shell, art, ["OuterEastWall_"])
	_assert_closed_rectangle("outer", outer_front, outer_rear, outer_west, outer_east)
	if _failed:
		return

	var keep_front := _named_visual_bounds(keep, art, ["KeepFrontWall_"])
	var keep_rear := _named_visual_bounds(keep, art, ["KeepRearWall_"])
	var keep_west := _named_visual_bounds(keep, art, ["KeepSide_West_"])
	var keep_east := _named_visual_bounds(keep, art, ["KeepSide_East_"])
	_assert_closed_rectangle("keep", keep_front, keep_rear, keep_west, keep_east)
	if _failed:
		return

	var roof_bounds := _visual_bounds_in_art(keep_roof, art)
	var keep_top := maxf(maxf(keep_front.end.y, keep_rear.end.y), maxf(keep_west.end.y, keep_east.end.y))
	_assert_near("roof bottom / keep top", roof_bounds.position.y, keep_top)
	_assert_near("roof west / keep west", roof_bounds.position.x, keep_west.position.x)
	_assert_near("roof east / keep east", roof_bounds.end.x, keep_east.end.x)
	_assert_near("roof rear / keep rear", roof_bounds.position.z, keep_rear.position.z)
	_assert_near("roof front / keep front", roof_bounds.end.z, keep_front.end.z)
	if _failed:
		return

	print("T0352 main hall shell closure verified: %s" % JSON.stringify({
		"outer_front": str(outer_front),
		"outer_west": str(outer_west),
		"keep_front": str(keep_front),
		"keep_west": str(keep_west),
		"keep_roof": str(roof_bounds)
	}))
	quit(0)


func _assert_closed_rectangle(label: String, front: AABB, rear: AABB, west: AABB, east: AABB) -> void:
	_assert_near("%s front-west outer X" % label, front.position.x, west.position.x)
	_assert_near("%s front-east outer X" % label, front.end.x, east.end.x)
	_assert_near("%s rear-west outer X" % label, rear.position.x, west.position.x)
	_assert_near("%s rear-east outer X" % label, rear.end.x, east.end.x)
	_assert_near("%s west-front tangent Z" % label, west.end.z, front.position.z)
	_assert_near("%s east-front tangent Z" % label, east.end.z, front.position.z)
	_assert_near("%s west-rear tangent Z" % label, west.position.z, rear.end.z)
	_assert_near("%s east-rear tangent Z" % label, east.position.z, rear.end.z)


func _named_visual_bounds(parent: Node3D, art: Node3D, prefixes: Array[String]) -> AABB:
	var result := AABB()
	var has_bounds := false
	for raw_child in parent.get_children():
		var child := raw_child as Node3D
		if child == null:
			continue
		var matches := false
		for prefix in prefixes:
			if str(child.name).begins_with(prefix):
				matches = true
				break
		if not matches:
			continue
		var child_bounds := _visual_bounds_in_art(child, art)
		result = child_bounds if not has_bounds else result.merge(child_bounds)
		has_bounds = true
	if not has_bounds:
		_fail("No visual modules found for prefixes: %s" % prefixes)
	return result


func _visual_bounds_in_art(node: Node3D, art: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	for raw_mesh in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative := art.global_transform.affine_inverse() * mesh_instance.global_transform
		var bounds := relative * mesh_instance.mesh.get_aabb()
		result = bounds if not has_bounds else result.merge(bounds)
		has_bounds = true
	return result


func _assert_near(label: String, actual: float, expected: float) -> void:
	if _failed:
		return
	if absf(actual - expected) > TOLERANCE:
		_fail("%s is open or intersecting: %.6f != %.6f" % [label, actual, expected])


var _failed := false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
